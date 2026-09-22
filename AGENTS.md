# AGENTS.md — context for a coding agent adding Bifröst support

This file is written to be pasted into a coding agent's context before it writes any AL
code against Bifröst. It is deliberately dense and structured, not narrative -
the human-readable versions of everything here are `QUICKSTART.md`, `EXTENDING.md`,
`ADAPTING.md`, `INTEGRATING.md`, and `CALLING-FROM-AL.md`, in that reading order. This file
exists so you don't have to read all five before writing the first line of code.

## Step 0: which situation are you in?

| Situation | Go to |
|---|---|
| No existing procedure does this yet - writing new logic | §1 Build from scratch |
| An existing procedure already does this - you're wrapping it | §2 Retrofit |

Do not skip this decision. The two situations produce different code, and treating a
retrofit as if it were greenfield is the most common mistake (see §2.3).

---

## §1. Build from scratch

### 1.1 The mandatory contract

Every message type is exactly these three pieces. No fewer, no substitutes.

| Piece | Requirement |
|---|---|
| A codeunit implementing `Msg Interface ori` | All six methods below, all mandatory |
| An enum extension on `Message Type ori` | One `value()` per message type, `Caption = '...', Locked = true` |
| `GetMessageHelpAsMarkdownDocument` inside that codeunit | Not optional - this is how the type gets discovered/used later |

Six interface methods, all required:

```al
procedure IsEnabled(): Boolean
procedure GetFilterTableNo(): Integer
procedure GetDescription(): Text[250]
procedure GetMessageDirection(): Enum "Msg Direction ori"
procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
```

Naming convention for the enum value (the wire `type` string): `Domain.Noun.Verb`, e.g.
`Reference.Table.Get`, `Sales.Document.Post`. `Locked = true` on the caption - it must never
be translated, callers in every locale send the same string.

**`IsEnabled` must be a real gate, not `exit(true)`.** Returning `false` means the type is
not listed and cannot be chosen at all - a real access-control mechanism (e.g. gate on
`WritePermission()` for a write, or a setup flag), not a formality.

**Help text is the contract, not a nicety - read `WRITING-HELP.md` before writing it.** Most
message types exposed as agent tools get a generic, parameter-less schema; the help markdown
is the only place your actual request/response shape and failure modes are described
anywhere. Use the skeleton in `WRITING-HELP.md` (`# Type.Name`, Overview, Direction, Request
table, Request example, Response incl. empty case, Errors table with exact error text,
Safety / repeat, Related types) and pass its five-question test. Never name implementation
(procedure or codeunit names, AL mechanics, Origo infrastructure) in help text - it is a
contract for the caller. Inline in the impl codeunit or in its own codeunit
(`RefNoteAddHelp.Codeunit.al`) - either is fine.

### 1.2 Every `ExecuteBifrostTask` starts with both guards, in this order

```al
Argument.AssertVersion1();
Argument.AssertIsLicensed();
```

`AssertVersion1` is a real check. `AssertIsLicensed` cannot fail on the path your code runs
on (licensing is enforced one layer up, before your implementation is ever called) - call it
anyway, it costs nothing and future-proofs other entry points.

### 1.3 Error handling — two shapes, pick correctly

| Failure kind | Mechanism | Example |
|---|---|---|
| Expected (bad input, not found, business rule) | `Argument.RespondWithError(msg)` | missing field, record not found |
| Unexpected (anything that could still throw) | Isolate in a sub-codeunit, catch via `Codeunit.Run()`, then `Argument.RespondWithLastError()` | see §1.4 |

Both produce `{ status: "Error", error, hint }`. **A response with no `status` field at all
counts as success** - do not add a `status: "Success"` field, its absence is the contract.

Never let a message type have *only* the success path. One that can never fail is
incomplete, not simple.

### 1.4 Writes must be isolated

```al
// Main impl codeunit:
if not Codeunit.Run(Codeunit::"Your Write Process", Argument) then
    Argument.RespondWithLastError();
```

```al
// Your Write Process — TableNo = "Message Argument ori", this exact TableNo required
trigger OnRun()
begin
    // Error() here is caught by the caller's Codeunit.Run() and reported through
    // RespondWithLastError() — the outer transaction is not rolled back on failure
    // unless you structure it this way.
end;
```

Skipping this means a failed write can leave state the caller never asked you to touch.

### 1.5 Object IDs

Register your own range before writing anything real. Never reuse `90000-90049` (this
repo's illustrative range) or Origo's real range (`10075485-10075984`) - both are meaningless
outside their own repos.

### 1.6 Worked examples in this repo

| File | Demonstrates |
|---|---|
| `Bifrost Reference/src/MessageTypes/RefEchoSetImpl.Codeunit.al` | Minimum viable type, no failure path |
| `Bifrost Reference/src/MessageTypes/RefTableGetImpl.Codeunit.al` | Read + `RespondWithError` |
| `Bifrost Reference/src/MessageTypes/RefNoteAddImpl.Codeunit.al` + `RefNoteAddProcess.Codeunit.al` | Write + isolation + `RespondWithLastError` |

---

## §2. Retrofit an existing solution

### 2.1 The one fact that changes everything

An `interface` can only be implemented by a `codeunit`, never a page. If the logic you're
wrapping already lives in a codeunit procedure, you write a **new** codeunit that calls it -
the original procedure and its callers (pages, other code) do not change. If the logic lives
inline in a page trigger, it has to move to a codeunit procedure first - not a Bifröst
requirement specifically, just a precondition of AL's interface model.

### 2.2 Before wrapping anything, check the existing procedure for these two signals

| Signal in the existing procedure | What it means |
|---|---|
| `Confirm()`, `Message()`, or any page/dialog call | **Cannot wrap directly.** No automated caller can answer a dialog. Extract a silent variant first (see 2.3). |
| `Commit()` anywhere before the procedure returns | **Cannot wrap directly.** A mid-procedure commit breaks the isolated-failure contract every message type relies on - a later failure can't roll back what already committed. Extract a silent variant first. |
| Neither present, one transaction, plain read/write | Safe to wrap directly - call it from `ExecuteBifrostTask` as-is. |

If you find either signal and wrap the procedure anyway without extracting a silent variant,
you have built something that will misbehave under real automated/retry traffic. This is not
a style preference.

### 2.3 The extraction pattern, when signals are present

- Add a new procedure with no `Confirm()`/`Message()` and no interim `Commit()` — same writes,
  one transaction, e.g. `CancelReservationSilent` next to the original `CancelReservation`.
- Keep the original procedure as-is for existing callers — it becomes a thin wrapper around
  the new silent procedure (confirm dialog, then call the silent version).
- Your Bifröst impl codeunit calls the silent procedure, never the original.

Worked example: `Legacy App/src/LegacyStockMgt.Codeunit.al` — `ReserveStock` needed no
change (2.2's "safe" case); `CancelReservation`/`CancelReservationSilent` is the extraction
(2.2's "cannot wrap directly" case). `git log` on that file shows the two states as separate
commits — read the diff, not just the current file.

### 2.4 Idempotency — check this before shipping any retrofitted write

Bifröst tasks can be retried. If the operation you're wrapping isn't safe to run twice
(decrements a quantity, submits a payment, creates a duplicate record on a second call),
either make it safe (check-before-act on a natural key) or make this an explicit, documented
limitation. This matters most for financial/regulatory operations - check before you assume.

### 2.5 One app or two?

| You... | Structure |
|---|---|
| Don't own/can't modify the original app, or want independent release cycles | Two apps: the original untouched, a new app depending on it that adds the message types. Worked example: `Legacy App` + `Legacy App - Bifrost` in this repo. |
| Own the original app outright | One app: add `src/MessageTypes/<Domain>/` inside the existing app - one codeunit per type, one shared enum extension, no new app. This is what Origo's own shipped extensions (Arionbanki, DocEx) actually do. |

Everything else in this file applies identically either way - this choice is only about
where the code lives.

### 2.6 Object IDs for a retrofit

Use the existing solution's own registered range. Do not register a fresh range for the
adapter - that's a from-scratch-only step (§1.5).

---

## §3. Calling it (either situation)

### 3.1 From outside Business Central

Four OData pages under `/api/origo/cloudEvent/v1.0/`: `queues` (enqueue only), `tasks`
(enqueue + process, synchronous), `requests`/`responses` (read-only). Neither POST returns
your payload directly - both put a relative link in `data`; GET `responses` for the actual
result. `data` is an escaped JSON **string**, not a nested object. Full contract:
`INTEGRATING.md`.

### 3.2 From AL code already inside Business Central — no HTTP, no external caller

```al
Dispatcher: Codeunit "Dispatcher ori";
Dispatcher.Execute(Enum::"Message Type ori"::"Your.Type.Name",
    Enum::"Message Version ori"::"1.0", '', '', 'application/json',
    RequestContent, ResponseContent, ResponseContentType);
```

`Execute` bypasses the queue table entirely (fastest, nothing persisted). The single-argument
overload always runs with `OmitCommit=true`, and **it is `OmitCommit=true` — not `Execute` itself —
that is incompatible with `TryFunction`-isolated message types** (Core's own dispatcher XML docs say
so explicitly, `Dispatcher.Codeunit.al`). Call the eight-argument `Execute` overload with
`OmitCommit=false` if you need queue-free dispatch of a `TryFunction`-isolated type.
`EnqueueAndProcess` runs the full orchestrator (auditable, supports webhook completion). Both take an
`OmitCommit` parameter for chaining calls that must roll back together. Full contract:
`CALLING-FROM-AL.md`.

---

## §4. Done means

- Compiles.
- Registered in the enum, `GetMessageHelpAsMarkdownDocument` describes it accurately.
- Both a success path and at least one failure path have been exercised and match the help
  text.
- If retrofitting: the existing procedure was checked against §2.2's table, not assumed safe.
- If the operation writes and could be retried: idempotency was actually considered (§2.4),
  not skipped.
