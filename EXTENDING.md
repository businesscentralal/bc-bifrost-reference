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
| Enum extension on `Message Type ori` | Registers your codeunit against a dotted type name (e.g. `Reference.Echo.Set`) — this is what a caller sends as `type` in the request envelope | `RefMsgType.EnumExt.al` |
| `GetMessageHelpAsMarkdownDocument` | Self-documenting help, surfaced by `Help.MessageTypes.Get` and the "hint" field of every error response | present in every impl codeunit here |

Object IDs in this repo (`90000–90049`) are illustrative only. Register your own range
before building anything real — see this repo's `README.md`.

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

A message type that can never fail (like `Reference.Echo.Set`) is incomplete. Real message
types need both paths:

- **Expected failures** (bad input, not found, business rule) → `Argument.RespondWithError(msg)`. See `RefTableGetImpl.Codeunit.al`: missing field, table not found — both return a structured `{ status: "Error", error, hint }` response instead of a generic BC error.
- **Unexpected failures** (anything that could still throw) → isolate the risky code and let `Codeunit.Run()` catch it, then call `Argument.RespondWithLastError()`. This also adds the AL call stack to the response. See below.

Both response shapes include a `hint` pointing the caller back to `Help.Implementation.Get`
for that message type — this is deliberate: callers (including AI agents) can self-correct
without you writing custom guidance per error.

## 5. Writes must be isolated

Any message type that inserts/modifies data must put that logic in a **separate** codeunit
with `TableNo = "Message Argument ori"`, invoked via `Codeunit.Run()`:

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
never asked you to touch. See `RefNoteAddImpl.Codeunit.al` + `RefNoteAddProcess.Codeunit.al`
for the full pattern, including the realistic failure case (duplicate key).

## 6. What NOT to copy from Origo's own extensions

If you've looked at Origo's own Bifröst extensions (Storage, Iceland, etc.) for
inspiration: copy the *pattern*, not the *content*. Real extensions call real external
systems (banking APIs, government registries, document exchange vendors) under commercial
agreements that don't transfer to you. This repo's examples are deliberately synthetic —
zero external dependency — so there's nothing to accidentally misuse.
