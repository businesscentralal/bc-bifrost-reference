# Adapting an existing solution to Bifröst

`EXTENDING.md` covers building a message type from nothing. This covers the more common
case: you already have a working extension, and you want some of its existing procedures
callable through Bifröst **without rewriting them**.

The worked example is `Legacy App` + `Legacy App - Bifrost` in this repo. `Legacy App`
is written as if Bifröst didn't exist - two procedures, two different shapes on
purpose. `Legacy App - Bifrost` depends on it and wraps both. Read them in that order;
this document explains the *why* behind what you'll see.

## The two apps, and why there are two

`Legacy App - Bifrost` depends on `Legacy App`, not the other way around, and it never
modifies `Legacy App`'s objects directly. That split matters for a real retrofit: you often
don't own, can't touch, or don't want to touch the original extension's release cycle
(someone else's module, a customer's, a different team's). Keeping the adapter as a
separate, additive extension means the original app's behaviour for its existing callers -
pages, other codeunits, whatever already calls it - never changes.

**This two-app split is not the only correct structure — check which one you're in first.**

Verified against two real, shipped Origo extensions (Arionbanki: 30+ message types across
Accounts, Bills, Claims, Payments, Statement; DocEx's full message-type set) - **neither
uses a separate adapter app.** Both add a `src/MessageTypes/<Domain>/` folder *inside* the
same app: one codeunit per message type, one shared enum extension, no new app at all. That
works because Origo owns both the original solution and the Bifröst layer, so there's
no reason to keep them apart.

| You... | Structure |
|---|---|
| **Don't own or can't modify** the original app (a real third party, a customer's own module, deliberately independent release cadence) | Two apps, as in this repo's worked example |
| **Own the original app outright** (the common case for your own future work) | One app, new `src/MessageTypes/<Domain>/` folder, same pattern Arionbanki and DocEx already use |

The underlying rules - six methods, two guards, error handling, write isolation, the
Confirm()/Commit() check below - are identical either way. This choice is about *where the
adapter code lives*, not about what it has to do.

## Case 1: `Legacy.Stock.Reserve` - a thin wrapper, nothing else needed

`Legacy Stock Mgt.ReserveStock` has no dialogs and no intermediate `Commit()` - the whole
operation is one transaction, and it can't leave anything half-done. `Legacy Stock Reserve
Impl.ExecuteBifrostTask` calls it directly: parse the JSON, call the procedure, write the
JSON response. No change to `Legacy App` was needed. **This is the case people assume is the
only case** - it's why a "just wrap it" mental model survives until it hits case 2.

## Case 2: `Legacy.Stock.CancelReservation` - the one that needed a real change

The original `CancelReservation` has two problems that a thin wrapper cannot paper over:

1. **It asks a question.** `Confirm('Cancel the reservation for %1?', ...)` has no answer
   from an automated caller. Depending on BC's confirm-handling context, this either throws,
   silently defaults, or hangs - none of which is what you want from an unattended message
   type.
2. **It commits too early.** The original deleted the reservation, called `Commit()`, and
   *then* wrote the cancellation log. If that second write ever failed, the deletion had
   already stuck - there is nothing to roll back. That's invisible in interactive use
   (a user watching the screen doesn't experience "partial failure" the same way), and a
   real bug in unattended use, where nothing is watching and a retry could double-log or
   mask the fact that the first attempt half-completed.

**You cannot fix either problem from the adapter app.** Both are inside `Legacy App`'s own
procedure. The fix, in the second commit that added `Legacy App - Bifrost`, was one
targeted extraction:

- `CancelReservationSilent(ItemNo)` — the same two writes, no `Confirm()`, no `Commit()`
  between them. Added to `Legacy Stock Mgt` in `Legacy App`.
- `CancelReservation(ItemNo)` — kept, unchanged in behaviour for existing callers, now just
  the confirm dialog in front of the silent core.

`Legacy Cancel Reserve Impl` calls `CancelReservationSilent`, never the original. Existing
callers of `CancelReservation` (pages, whatever already used it) don't need to change at
all - the extraction is additive, not a rename.

## How to tell which case you're in

Before wrapping an existing procedure, check it for:

| Signal | What it means |
|---|---|
| `Confirm()`, `Message()`, or any page/dialog call | Needs a silent variant extracted first - an automated caller can't answer it |
| `Commit()` anywhere before the procedure returns | Needs a silent variant extracted first - a mid-procedure commit breaks the isolated-failure contract every message type relies on (see `EXTENDING.md` §5) |
| Plain data read/write, no UI, one transaction | Safe to wrap directly, as in case 1 |

If neither signal is present, you're almost always in case 1. If either is present, you're
in case 2, and the fix is the same shape every time: extract a silent core, keep the
original as a thin wrapper around it, point the adapter at the silent core.

## What doesn't change between building fresh and retrofitting

Everything in `EXTENDING.md` §2-§5 still applies exactly as written: six interface methods,
enum registration, the two guards, the error-handling split, the write-isolation rule. A
retrofit's impl codeunit is not a different shape - it just calls into an existing
procedure (or a newly-extracted silent one) instead of writing new logic from scratch.

## What's different

- **Object ID range**: use the *existing* solution's own registered range for the adapter's
  new objects - never register a fresh one, unlike a from-scratch extension.
- **Help text is new work regardless.** The original procedure's XML doc (if it has one)
  describes an AL signature. `GetMessageHelpAsMarkdownDocument` has to describe the JSON
  wire contract instead - that's unwritten before the retrofit, every time.
- **Tests are new work regardless.** Existing tests call the procedure directly with typed
  parameters. Nothing exercises the JSON-in/JSON-out path or its error cases until you write
  it for the adapter.
