# Playbook B: make an existing app headless

Your app works, but its logic lives in page actions, asks the user questions with `Confirm`, or commits in the middle. Nothing without a UI can call it: no API, no job queue, no other app, no agent.

The fix is a **headless facade**: one public codeunit with the app's operations, free of UI and commits. Everything calls it: your own pages, other apps, and later the Bifröst adapter from Playbook C.

**This playbook needs no Bifröst dependency.** It is good AL design on its own. Worked example: **Legacy App**, `src/LegacyStockAPI.Codeunit.al`.

## Steps

### 1. Find the operations and their UI entanglement

For each operation, list:

- **Dialogs:**
  - `Confirm`, `StrMenu`, `Message`
  - `Page.RunModal` used to pick values
  - request pages
- **Commits** in the middle of the logic. A `Commit()` before a second write that can fail leaves half-done data.
- **Implicit inputs:**
  - `WorkDate()`
  - the current record on a page
  - user setup
  - filters set by the page
- **Outcomes that aren't reported:**
  - a procedure that silently does nothing
  - a Boolean with no reason

### 2. Create the facade codeunit

Set `Access = Public`, give it a clear name ("<App> API"), and add one procedure per operation. The rules:

| Rule | Example in `Legacy Stock API` |
|---|---|
| No UI. The caller decides, and the facade executes. | `CancelReservation` has no Confirm. The page asks first. |
| No `Commit`. The caller owns the transaction. | Both writes in `CancelReservation` succeed or fail together. |
| Check preconditions up front, and fail with a translatable error that says what to do. | `Item 'X' does not exist. Check the number, or find the item …` |
| Return the outcome. | `Reserve` returns the new total. `CancelReservation` returns whether anything was cancelled. |
| Make implicit inputs explicit parameters. | Pass dates, locations and amounts instead of reading page state. |
| Offer read procedures, so callers can check state. | `GetReservedQuantity`, `HasReservation`, `IsReservable` |
| Add extension points. | `OnBeforeReserve` (with `IsHandled`), `OnAfterReserve`, `OnAfterCancelReservation` |

### 3. Keep the old entry points as thin shells

Existing callers (pages, other codeunits, other apps) must keep working:

- **UI procedures** keep their dialog, then call the facade. See `Legacy Stock Mgt.CancelReservation`.
- **Old signatures** keep their contract (e.g. "returns false instead of an error"). Check first, e.g. with `IsReservable`, then call the facade. Mark them `[Obsolete('Use …', '<version>')]`.

### 4. Update the pages

The page asks the person, then calls the facade. That is the only place a dialog lives.

### 5. Test without UI

Call each facade procedure from a test codeunit, or from a job queue entry. None of them may open a dialog. A call that would need one is a sign the decision should be a parameter.

## How callers use the facade

| Caller | How |
|---|---|
| Your own page | Asks (Confirm), then calls the facade directly |
| Another AL app | Calls the facade. To survive a failure, it wraps the call in a codeunit run with `if not Codeunit.Run(...)`. |
| A Bifröst adapter | An isolated Process codeunit calls the facade (Playbook C) |
| Job queue | A codeunit that reads its parameters from the job queue entry and calls the facade |

## When you can't change the app

If the app isn't yours, or the code can't be changed, you can only wrap the procedures that are already headless. For the rest, ask the owner for a facade, or reimplement the operation in your adapter using the same tables. Document the risk that it drifts from the original.
