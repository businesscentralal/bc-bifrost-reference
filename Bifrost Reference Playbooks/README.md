# Bifrost Reference Playbooks

> **Builds on two things you must already have.** This is not a standalone app.
>
> 1. **Bifrost Orchestrator**, Origo's app on top of Bifrost Foundation that runs *playbooks*: sequential, branching workflows whose steps are message types. Install it in the sandbox first.
> 2. **The reference apps in this repo**: `Legacy App v2` (folder `Legacy App v2 (headless)`) and `Bifrost Reference`. The playbooks call their message types as steps.

## What it shows

Once a message type follows the contract in `START-HERE.md`, the Orchestrator can chain it with others, with no extra code. This folder holds reference playbooks that do exactly that, plus the rules a message type should follow to work well as a playbook step.

| Playbook | Steps | Pattern |
|---|---|---|
| `REF-RELEASE` | `Legacy.Stock.List` → (count > 0) → `Legacy.Stock.ReleaseAll` | Look, then act. The count from step 1 becomes `expectedCount` in step 2, so an unattended run can never release more than it saw. |

More playbooks follow once `REF-RELEASE` runs end to end.

## How a playbook is made

The Orchestrator has no AL events or interfaces to extend. Its extension point is data:

- **A playbook is records:** `Playbook ori`, `Playbook Step ori` and `Playbook Condition ori`, written with `Data.Records.Set`. A step's request template is a BLOB, passed as base64 JSON.
- **Any registered message type can be a step.** A step's `Message Type` field is Foundation's `Message Type ori` enum, so your app's enum values are available as steps without depending on the Orchestrator.
- **Steps use the message type's own parameter names**, and can read earlier results from the workspace with `@path`.
- **A run** is inline (`Orchestrator.Playbook.Run`), queued once (`Orchestrator.Playbook.Enqueue`) or recurring (`Orchestrator.Playbook.Schedule`).
- **Each step commits on its own.** There is no rollback across steps. That is why step 2 carries the count guard itself.

The definitions are in `playbooks/` as JSON, one file per playbook, readable by a person and by an agent. `playbooks/README.md` explains how to create them with `Data.Records.Set`.

## Making a message type a good playbook step

These rules add to the contract in `START-HERE.md` §4. The reference types already follow them.

1. **Answer "nothing to do" as success, with a count.** A condition can branch on `count = 0`. `Legacy.Stock.List` returns `count` and `totalQuantity`, including 0. **Keep errors apart from "nothing".** A type that answers with `RespondWithError` does not raise, so a Check step reads the missing count as "nothing to do" and the run ends Completed. Log `status` on the step and add an Error condition `status Equals Error`, as `REF-RELEASE` does. The run then ends Failed.
2. **Put arrays under one stable key**, so a later step can iterate over them. `Legacy.Stock.List` uses `reservations`.
3. **Keep a small summary next to the data.** The run report reads the summary paths, and later steps read the result paths.
4. **Guard every bulk change with a value from an earlier read.** No rollback across steps means the write step must refuse if the world changed (`expectedCount`, `expectedItemCount`).
5. **Report errors with `RespondWithError`**, so they land in the step log with their text.
6. **Be safe to re-run.** A scheduled playbook runs again tomorrow. Make repeats harmless (`externalId`, the count guard) or say in the help that they aren't.

## Status

`REF-RELEASE` is built and tested in a sandbox. See `playbooks/README.md` for how to create, run and test it; its section "Test it: the three runs" lists the results you should see.

| Run | Result |
|---|---|
| Filter `1896-S`, 1 reservation | Completed, 2 steps. Step 20 received `expectedCount: 1` from step 10 and released 1. The release is logged. |
| The same again | Completed, 1 step. Count 0, so step 20 was skipped. |
| Invalid filter `((` | Failed, through the Error condition on step 10. Without that condition the run ended Completed. |

Callers should read `playbookStatus`, not `stepsFailed`: a run failed by an Error condition reports 0 failed steps.

**Known hurdle:** the Playbook tables are behind Foundation's ChangeLog write guard. In a default setup, `Data.Records.Set` refuses to create a playbook with *"Field "1" … must be included in the change log write guard setup to be updated via Bifrost"*. Before playbooks can be created over the API, an administrator must allow it in Bifrost Setup: add the three Playbook tables to the change log / guard exceptions (check the page **ChangeLog Guard Exceptions** first, so they are not added twice), or set the guard to "Via force". The alternative is to create them on the Playbook Card page. Use `set_records` (or `Data.Records.Set` with the table in `subject`), not the `tableName` shape.
