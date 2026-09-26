# Legacy App v1: the "before" state (not headless)

This is Legacy App as many real apps look before anyone thinks about APIs or agents. It has the **same app id** as `Legacy App` (v2), with version 1.1.0.0, so publishing v2 over it is a real upgrade. It is not part of the CI build.

Everything here works for a person clicking through the UI. That is the point: none of these problems shows up until something without a person calls the code.

## What's wrong with it for anything without a person

Every problem is marked in the code as `AUDIT 7.2 - <pattern>`, after the audit table in [`START-HERE.md`](../START-HERE.md) §7.2. Search the folder for `AUDIT 7.2` to find them all.

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
2. **Publish `Legacy App` (v2) over it.** For a person, the app asks the same questions in the same places. Underneath, the work has moved into the headless facade `Legacy Stock API`, and the page only talks to the person. The app still knows nothing about Bifröst, so for an agent there is still nothing to call.
3. **Publish `Legacy App - Bifrost`,** a separate app that depends on Legacy App v2 and Bifröst Foundation. Now `Legacy.Stock.Reserve`, `.CancelReservation`, `.Get`, `.List` and `.ReleaseAll` exist, and an agent can do everything a person can, with the same rules. The questions a person answered in dialogs have become explicit parameters (`allowOverStock`, `expectedCount`).

Search both `src/` folders for `7.2 -` to see each problem next to its fix.

**Starting again:** BC won't install 1.1 over 2.x. Uninstall and unpublish `Legacy App - Bifrost` and then `Legacy App` before you publish v1 again.
