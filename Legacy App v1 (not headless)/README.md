# Legacy App v1: the "before" state (not headless)

This is Legacy App as many real apps look before anyone thinks about APIs or agents. It has the **same app id** as `Legacy App` (v2), with version 1.1.0.0, so publishing v2 over it is a real upgrade. It is not part of the CI build.

Everything here works for a person clicking through the UI. That is the point: none of these problems shows up until something without a person calls the code.

## What's wrong with it for anything without a person

Every problem is marked in the code as `AUDIT - <pattern>`, after the audit table in [`START-HERE.md`](../START-HERE.md) §7.1. Search the folder for `AUDIT -` to find them all.

| Where | Pattern | Why an API, job queue, other app or AI agent can't use it |
|---|---|---|
| Page action **Reserve stock...** | Rules that live on the page | The rules and table writes are inside the page trigger, so no other caller gets them. |
| `ReserveStock` | `GuiAllowed` branch | A person is warned before reserving more than is in stock. Code callers take the other path, and the check silently disappears. |
| `ReserveStock` | Silent failure | It returns `false` without a reason. |
| `CancelReservation` | Dialogs | A `Confirm()` inside the business procedure: nobody is there to answer. |
| `CancelReservation` | `Commit` | Between the delete and the log write. If the log fails, the reservation is gone with no record of it. |
| `ReleaseAll` | Dialogs | A progress window and a final `Message` are the only outcome. |
| `ReleaseAll` | Unbounded work | No filter: every row, every time. |
| `ReleaseAll` | `Commit` + swallowed errors | It commits every row so that `if Codeunit.Run` is allowed, then counts failed rows as "skipped" and throws their error text away. A failure half-way leaves some rows released and some not. |
| `ReleaseAll` | Silent failure | `Error('')` when there is nothing to release: the call fails and says nothing. |
| Anywhere | No reads | No way to ask "how much is reserved?" or "what would release all touch?" |

## The demo, step by step

1. **Publish this app (v1).** Use the app in BC: reserve more than is in stock (you are warned), cancel (you are asked), release all (a progress window, then "n released, m skipped"). For an agent there is nothing to call. It can read the table through Bifröst's generic data access, but generic writes are blocked.
2. **Legacy App v2: headless inside, message types outside.** Publish `Legacy App` v2 (folder `Legacy App v2 (headless)`, depends on Bifröst Foundation) over it. For a person, the app asks the same questions in the same places. Underneath, the work has moved into the internal headless core `Legacy Stock API`, and the page only talks to the person. Outside, the app's public API is its message types: `Legacy.Stock.Reserve`, `.CancelReservation`, `.Get`, `.List` and `.ReleaseAll`, so an agent can do everything a person can, with the same rules. The questions a person answered in dialogs have become explicit parameters (`allowOverStock`, `expectedCount`).

Search `Legacy App v1 (not headless)/src/` for `AUDIT -` and `Legacy App v2 (headless)/src/` for `FIXED -` to see each problem next to its fix.

## Comparing v1 and v2

Both apps use the same folders, so a folder-by-folder comparison shows exactly what the retrofit changed:

| Folder | v1 (before) | v2 (after) |
|---|---|---|
| `src/Data/` | Reservation and cancellation log tables | The same tables, unchanged |
| `src/Logic/` | `LegacyStockMgt` with dialogs, `Commit` and `GuiAllowed`; `LegacyReleaseRow` | `LegacyStockAPI`, the internal headless core; `LegacyStockMgt`, old entry points kept for compatibility |
| `src/UI/` | The list page with the business logic inside it; the reserve dialog | The list page, which only talks to the person; the same dialog |
| `src/Permissions/` | `LEGACY STOCK` | The same |
| `src/MessageTypes/` | – | **New:** the app's public API, with the five `Legacy.Stock.*` types, their help, the input layer and registration |

In VS Code, select both `src` folders in the Explorer and choose **Compare Selected**, or compare the matching files one by one.

**Starting again:** BC won't install 1.1 over 2.0. Uninstall and unpublish `Legacy App` (2.0) before you publish v1 again.
