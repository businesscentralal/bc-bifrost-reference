# Adapting an existing app

How to make an app you already have callable by integrations and agents: **headless inside, message types outside, in the same app.** The worked example is `Legacy App v1 (not headless)` (2.1.0.0) → `Legacy App v2 (headless)` (2.2.0.0, same app id, an upgrade). Search v1 for `AUDIT -` and v2 for `FIXED -` to read each problem next to its fix. Build the message types themselves with [BUILDING.md](BUILDING.md).

## Pick the path

| You have | Do |
|---|---|
| Your own app built for the UI, or with codeunit APIs | Audit it, add an internal core, add message types **in the same app**. |
| An app also sold to customers **without** Bifröst, or someone else's app | The exception: a public facade plus a separate adapter app (last section). |
| Customisations on the base app | A new app (or your PTE) that wraps base-app codeunits headless (`SetHideValidationDialog`, `…HideDialog`). Check first that Foundation doesn't already have the operation. |
| Batch jobs | Request-page options become parameters; long work is queued with a status type. |
| An app built on Origo BC Cloud Events (the earlier platform) | Change the dependency to Bifrost Foundation (app id `7505e808-6e52-4b96-a328-82573391297a`) and rename to the Bifröst names (`ExecuteBifrostTask`, `Message Argument ori`). |

## 1. Audit the old code first

Go through every path a procedure reaches, including other apps' subscribers. Code that works in the UI can do the wrong thing, often silently, when nobody is there. An `Error` is fine when nothing was committed earlier, nothing catches it, and its text says what to fix.

| Pattern | Search for | Fix |
|---|---|---|
| Dialogs | `Confirm`, `StrMenu`, `Message`, `Page.Run`, `RunModal`, request pages, `Dialog.Open` | The decision becomes a parameter with a safe default. Remove progress windows. |
| `GuiAllowed` branches | `GuiAllowed` | It may change what is **shown**, never what is **checked or done**. |
| `Commit` | `Commit()` | Remove it; the caller owns the transaction. |
| Writes in a `[TryFunction]` | `[TryFunction]` | Try functions only for reads, parsing and HTTP. Isolate writes with `Codeunit.Run`. |
| Swallowed errors | `if not Codeunit.Run`, `ClearLastError` | Pass `GetLastErrorText()` to the caller. |
| Silent failure | `exit(false)` without a reason, `Error('')` | Return or raise a reason the caller can act on. |
| Rules on the page | page `OnValidate` / `OnAction`, `SetSelectionFilter`, `CurrFieldNo` | Move rules to the table or core; the selection becomes a filter parameter. |
| Hidden context | `WorkDate()`, page-set globals, `SingleInstance` | A parameter with a documented default; no state between calls. |
| Skipped validation | direct assignment, `Modify(false)` | `Validate`, unless documented. |
| Side effects that can't be undone | email, HTTP, files mid-write | Do them after the data is safe, or queue them. |
| Asynchronous work | `StartSession`, `TaskScheduler`, job queue | Return `queued` and add a status type. |
| Files | `Download`, `UploadIntoStream` | Base64 or structured JSON. |
| Duplicates on retry | `Insert` without an existence check | Accept `externalId` and look it up first. |
| Unbounded work | `FindSet` over whole tables | Filter, `SetLoadFields`, cap the result. |
| Locale formats | `Format(date)`, `Evaluate` without `9` | `Format(x, 0, 9)`, `Evaluate(x, t, 9)`, ISO dates. |

`GuiAllowed` is false for web services, the job queue and background sessions, so never use it to detect Bifröst. Don't wrap a guarding question in `if GuiAllowed() then`: without a UI the branch silently answers "yes".

**In Legacy App:**

| Pattern | v1 (before) | v2 (after) | Proof |
|---|---|---|---|
| Dialogs | `Confirm` in `CancelReservation`; progress window and `Message` in `ReleaseAll` | The page asks; the core never does | `Legacy.Stock.CancelReservation`, `Legacy.Stock.ReleaseAll` |
| `GuiAllowed` | Stock check only with a UI | Check for every caller; the decision is `AllowOverStock` | `Legacy.Stock.Reserve` refuses over stock unless `allowOverStock: true` |
| `Commit` | Between delete and log; after every row | One transaction | A failed release leaves nothing half done |
| Swallowed errors | Failures counted as "skipped" | Errors reach the caller | `status = Error` with the core's text |
| Silent failure | `exit(false)`, `Error('')` | Returned outcomes | `cancelled: false`, `released: 0` |
| Rules on the page | Reserve rules in the page trigger | Rules in the core | Pages and types get the same rules |
| Unbounded work | `ReleaseAll` touches every row | Filter required, list capped at 100 | `ReleaseAll` needs a filter and `expectedCount` |

Record the audit per type in the pull request: call path, findings (fixed / not present / accepted with what the contract says), and the break-set calls that prove the fixes.

## 2. Inside: an internal core

Every page action both **talks to a person** (dialog, "are you sure?", selected row) and **does the work** (rules, writes). Headless means the work lives in procedures that never talk to a person.

Add one codeunit with one procedure per operation, **`Access = Internal`** (`Legacy Stock API` in `Legacy App v2 (headless)/src/Logic/LegacyStockAPI.Codeunit.al`):

- no UI, no `Commit`; preconditions first, with translatable errors written for callers;
- return outcomes (the new total, `true`/`false`);
- implicit inputs become parameters;
- read procedures so callers can check state (`HasReservation`, `GetReservedQuantity`, `CountReservations`, `WouldExceedInventory`).

Internal, because the message types are the one public surface: a public core would be a second contract, and callers could skip the permission gate, the message log and usage. Old public procedures (`Legacy Stock Mgt`) stay as thin shells that call the core, marked `[Obsolete]` where a core procedure replaces them, so existing callers keep compiling. Pages ask the person, then call the core.

## 3. Outside: message types in the same app

Add the Foundation dependency and a `src/MessageTypes/` folder:

- one type per core operation, plus the reads;
- the type checks the **shape** of the input; the core checks the **business rules**; never both;
- writes go through an isolated Process codeunit (`Legacy Reserve Process`), so the core's errors become the caller's errors. A type may call the core directly only when the procedure raises no error the caller must see (`Legacy.Stock.Get`);
- a trimmed input layer (`LegacyAdapterInput.Codeunit.al`);
- pass outcomes through, never answer a no-op as a change;
- `IsEnabled` checks permissions on the app's tables; register the app; add `Help.<Capability>.Get`;
- the contract chapters and the tests are new work: XML docs describe AL signatures, not the JSON contract.

Ship it as an upgrade: same app id, higher version. Every tenant then needs Bifrost Foundation.

| Caller | How |
|---|---|
| Your own page | Asks the person, then calls the core (or its own message type, below). |
| Another AL app | The message type through `Dispatcher ori`. |
| API, MCP, agents, playbooks | The message type. |

Test every type through `Dispatcher ori`, as `Legacy Adapter Tests` in `Bifrost Reference Tests/` does. None may open a dialog.

**Pages through message types (optional).** A page action may call its own type through `Dispatcher ori.Execute` instead of the core: one code path and every click in the message log, at the cost of one message row and usage per click, and the page needs Bifröst licensed. Handle a refusal on the page. Calling the core is equally correct; Legacy App's pages do that.

## 4. Exception: a separate adapter app

Only when the app must also run without Bifröst, or isn't yours. The app gets a **public facade** (`Access = Public`) with the core's rules plus `OnBefore…`/`OnAfter…` events and no Bifröst dependency. A separate adapter app depends on it and on Foundation and holds the message types, built as in section 3, with its own id range and permission set. The facade is a second contract you must keep stable. If you can't change the app, wrap only what is already headless and document the risk. This repository has no adapter app.
