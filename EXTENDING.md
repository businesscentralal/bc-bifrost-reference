# Extending Bifröst with a New Message Type

This walks through adding a message type to Bifröst, using the three examples
in `src/MessageTypes` as worked references. Read `INTEGRATING.md` first if you need the
wire contract (what a caller actually sends/receives) — this guide covers the AL side only.

## 1. Depend on Bifröst Foundation, never its source

```json
"dependencies": [
  {
    "id": "a629b897-7541-4562-bebb-c6122f15801c",
    "name": "Bifrost Foundation",
    "publisher": "Origo",
    "version": "28.1.0.0"
  }
]
```

**Pin the minimum you compile against, not the build you happen to have.** The version above is a
floor, not the current release — AL treats it as "this or newer", so an exact build number here
means every Core release makes this snippet wrong, and whoever copied it gets a resolution error
they did not cause. Check the installed version in Extension Management if you need to know it.

You get compiled symbols only — `resourceExposurePolicy` on the core app blocks
debugging/source download regardless of who installs it. Set the same policy on your own
app (see this repo's `app.json`).

## 2. Every message type is: interface impl + enum value + help

| Piece | What it does | Worked example |
|---|---|---|
| Codeunit implementing `Msg Interface ori` | The **six** required methods (`IsEnabled`, `GetFilterTableNo`, `GetDescription`, `GetMessageDirection`, `GetMessageHelpAsMarkdownDocument`, `ExecuteBifrostTask`) | `RefEchoSetImpl.Codeunit.al` |
| Enum extension on `Message Type ori` | Registers your codeunit against a dotted type name (e.g. `Reference.Echo.Get`) — this is what a caller sends as `type` in the request envelope | `RefMsgType.EnumExt.al` |
| `GetMessageHelpAsMarkdownDocument` | Self-documenting help, surfaced by `Help.MessageTypes.Get` and the "hint" field of every error response | present in every impl codeunit here |

Object IDs in this repo (`90000–90049`) are illustrative only. Register your own range
before building anything real — see this repo's `README.md`.

**The verb in the name is a promise.** `Get` means the type reads and writes nothing; `Add`,
`Reserve`, `Cancel...`, `Set`, `Post` mean it writes. The echo example was called
`Reference.Echo.Set` until it was renamed `Reference.Echo.Get`: it never wrote anything, so
the old name claimed a write it did not perform and a caller reading only the name would have
treated a harmless connectivity check as a side effect. The enum ordinal (90000) did not change;
only the value name and caption did. Name your own types by what they do to data, not by what
they return.

**Direction must match the verb.** `GetMessageDirection` returns `Outbound` for a type that
only reads Business Central data and returns it, and `Inbound` for a type that writes into
Business Central. Of the five types in this repo: `Reference.Echo.Get` and
`Reference.Table.Get` are **Outbound** — one reads the server clock, the other reads object
metadata; neither touches a table. `Reference.Note.Add`, `Legacy.Stock.Reserve` and
`Legacy.Stock.CancelReservation` are **Inbound** — they insert a note, insert or increase a
reservation, and delete a reservation plus insert a log entry respectively. The help document's
`## Direction` section repeats this in words so a caller can see it without reading AL.

**Read `WRITING-HELP.md` before writing your help text.** For most message types it is not
documentation on the side - it's the only schema an agent calling your type will ever see.

## 3. Every implementation must call two guards, always

```al
Argument.AssertVersion1();
Argument.AssertIsLicensed();
```

`AssertVersion1` rejects unsupported CloudEvents spec versions, and it is a real check: call it
first, before touching the request payload.

`AssertIsLicensed` needs an honest description. **On the path your code runs on, it cannot fail.**
Core's task codeunit sets the licensed flag unconditionally *before* any licence evaluation, and the
real enforcement is a branch in that codeunit which skips `ExecuteBifrostTask` entirely when the
pool is invalid — so by the time your implementation executes, the answer is always yes. Keep the
call: it costs nothing and it guards against future entry points that do not go through the task
codeunit. But do not think of it as the thing protecting the licence, and do not present it to
anyone as a security obligation. The licence is enforced above you, not by you.

## 4. Design for failure, not just success

A message type that can never fail (like `Reference.Echo.Get`) is incomplete. Real message
types need both paths:

- **Expected failures** (bad input, not found, business rule) → `Argument.RespondWithError(msg)`. See `RefTableGetImpl.Codeunit.al`: missing field, table not found — both return a structured `{ status: "Error", error, hint }` response instead of a generic BC error.
- **Unexpected failures** (anything that could still throw) → isolate the risky code and let `Codeunit.Run()` catch it, then call `Argument.RespondWithLastError()`. This also adds the AL call stack to the response. See below.

Both response shapes include a `hint` pointing the caller back to `Help.Implementation.Get`
for that message type — this is deliberate: callers (including AI agents) can self-correct
without you writing custom guidance per error.

## 5. When a write must be isolated

Isolation is required when a message type inserts or modifies data **and** a failure inside
that write must reach the caller as a structured `{ status: "Error", error, hint }` response
rather than as a raw AL error that rolls the whole message back. That is the case whenever the
write itself can raise — a duplicate key, a table trigger, a validation in `Insert(true)` /
`Modify(true)` — and you want the caller to learn *why*. Put that logic in a **separate**
codeunit with `TableNo = "Message Argument ori"`, invoked via `Codeunit.Run()`:

```al
// In your main impl codeunit's ExecuteBifrostTask:
if not Codeunit.Run(Codeunit::"Ref Note Add Process", Argument) then
    Argument.RespondWithLastError();
```

```al
// Ref Note Add Process — TableNo = "Message Argument ori"
trigger OnRun()
begin
    // ... Error() here is caught by the caller's Codeunit.Run(), not by BC's default
    // error handling — the outer transaction isn't rolled back on failure.
end;
```

This is not optional decoration — without it, a failed write can roll back state the caller
never asked you to touch, and the caller gets no structured error. See
`RefNoteAddImpl.Codeunit.al` + `RefNoteAddProcess.Codeunit.al` for the full pattern, including
the realistic failure case (duplicate key).

**When a thin adapter may call directly.** If your `ExecuteBifrostTask` is a thin adapter over
an existing procedure that already validates its own input and returns a result you can test
(a `Boolean`, a count, an empty record) instead of raising, and that procedure has no dialogs
and no intermediate `Commit()`, you may call it directly and turn its result into
`RespondWithError` yourself. That is what the two Legacy adapters do: `Legacy.Stock.Reserve`
calls `ReserveStock`, which returns `false` for a non-positive quantity and otherwise performs
a single insert-or-modify; `Legacy.Stock.CancelReservation` calls `CancelReservationSilent`,
which exits quietly when nothing exists and otherwise performs a delete and an insert in one
transaction. Neither has an expected failure that only surfaces as an AL error, so there is
nothing for `Codeunit.Run()` to catch. The moment such a procedure gains an `Error()` you want
reported to the caller, move the call behind the isolation pattern above.

## 6. Make your app known to Foundation — one subscriber, one directory type

Two things every Bifröst app ships that are not message-type implementations.

**Register with the app registry.** Foundation's Setup Wizard, its "HTTP client requests are
not enabled for: …" notification on the Bifrost Setup page, and the app names on Bifrost App
Secrets are all built from one list: the **App Registry**. Your app puts itself on that list
with a single event subscriber — `Bifrost Reference\src\Lifecycle\RefRegistration.Codeunit.al`
is the whole thing, twenty lines. Pass your setup page's object id, or `0` while you have none.

*When*: always. Even an app with no setup and no secrets registers, because the wizard's HTTP
step has to know the app exists to switch HTTP on for it.

*What the administrator then sees*: your app's name in the wizard's app list and HTTP step;
your app in the aggregated HTTP notification when it is not yet enabled; your secrets (if any)
under your app's name. You never show an HTTP or credentials notification of your own —
Foundation aggregates them. Your own first-run guidance belongs in your own assisted setup,
and, if something must be switched on before you work, in a notification on Bifrost Setup that
opens your page.

*Yours and Foundation's*: the wizard, the notifications and Foundation's tabs are Foundation's
and are not extension points. The one action in the *Apps* group, your setup page, your
secrets' descriptions and everything behind your page are yours, under your app's name and
publisher.

**Ship a `Help.<App>.Get` directory type.** An agent that wants to know what *your* app adds
should not have to walk the whole catalogue. `Help.Reference.Get`
(`RefHelpGetImpl.Codeunit.al`) returns a Markdown overview of the app and a table of its types
with one line each. Keep the table in step with the enum — a test that compares the two is the
cheapest way (see the test app).

## 7. What NOT to copy from Origo's own extensions

If you've looked at Origo's own Bifröst extensions (Storage, Iceland, etc.) for
inspiration: copy the *pattern*, not the *content*. Real extensions call real external
systems (banking APIs, government registries, document exchange vendors) under commercial
agreements that don't transfer to you. This repo's examples are deliberately synthetic —
zero external dependency — so there's nothing to accidentally misuse.
