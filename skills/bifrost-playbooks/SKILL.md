---
name: bifrost-playbooks
description: Build, test and run Bifrost Orchestrator playbooks in Business Central for a user, conversationally. Use whenever someone wants something in BC to happen automatically, on a schedule, in several steps, or "every morning / each month / when X then Y"; asks to create, change, run, schedule or explain a Bifröst playbook; or mentions the Orchestrator, Playbook ori, playbook steps or conditions. Also use to find out why a playbook run did or did not do something.
---

# Bifröst playbooks

A **playbook** is a saved recipe in Business Central. Each **step** calls one Bifröst message type. Later steps read earlier results from a shared JSON **workspace**, and **conditions** choose the next step or fail the run. The Bifrost Orchestrator app runs playbooks inline, once later, or on a schedule.

Your job is to turn what the user wants into a playbook that is **safe to run unattended**, prove it in a sandbox, and only then schedule it, on the user's word.

## Safety rules (always)

- **Build and test in a sandbox.** Confirm `environment_type` is sandbox before any write or run. In production, only explain and propose; the user makes the changes, or confirms each write explicitly.
- **Each step commits on its own, and nothing rolls back across steps.** Every step that changes data must be guarded by a value from an earlier read, such as `expectedCount` or `expectedItemCount`, or be safe to repeat.
- **Never enqueue or schedule without an explicit yes** from the user, after they have seen a successful inline run.
- Many Orchestrator types that change state are declared **Outbound**: Run, Enqueue, Schedule, Restart, Register, Report.Run. The MCP write gate does not ask about them, so you must.
- Change only the playbook you are building. Never touch other playbooks, Job Queue entries or setup.

## Before you start (once per session)

1. **Is the Orchestrator installed?** Invoke `Help.Orchestrator.Get` and read it fully: it is the authority for table and field names, workspace paths and operators. If the type doesn't exist, stop and say that the Bifrost Orchestrator app is needed.
2. **Can you write definitions?** The three Playbook tables sit behind Foundation's ChangeLog write guard. If the first `set_records` fails with *"must be included in the change log write guard setup"*, stop. Ask an administrator to add ChangeLog Guard Exceptions, with Field No. 0, for `Playbook ori`, `Playbook Step ori` and `Playbook Condition ori`, on page "ChangeLog Guard Exceptions" in Bifrost Setup. Take the table numbers from the error or from `Help.Tables.Get`. The alternative is the Playbook Card page in the BC UI.
3. **Will it be scheduled later?** Enqueue and Schedule need the Job Queue configured. `Orchestrator.Status.Get` says "Job Queue has not been configured" when it isn't. Tell the user early, because an administrator has to set that up.

## Workflow

1. **Understand the job.** Ask only what you need:
   - what should happen, in the user's words
   - which records it covers (a filter)
   - what counts as "nothing to do"
   - when it should run
   - who should hear about it

   Repeat it back in one sentence.
2. **Find the types**, one per step, with the user's own words (`find_message_types`), then `describe_message_type` for each. Prefer a read type to find the work, then the write type that does it. If no type fits a step, say so. Don't bend one type to do another's job.
3. **Propose the playbook** as a table and get approval before writing:

   | Step | Type | Input | Logs | Next on success / otherwise |
   |---|---|---|---|---|

   Add a line for each condition, in plain words ("only if the count is above 0", "fail the run if step 10 answered with an error").
4. **Write the records** (see Records) and read them back.
5. **Check the context** with `Orchestrator.Workspace.Preview`. It shows what `_sys` (dates) and `_who` (the user) hold, but resolves no templates. To see what a step actually receives, run inline and decode that step's `RequestSent`.
6. **Run inline** with `Orchestrator.Playbook.Run` in the sandbox, using a harmless filter first. Then run the three cases every playbook must pass:
   - **work to do:** the steps run and the change is made. Create test data in the sandbox if there is none, and remove it afterwards.
   - **nothing to do:** Completed. The write step has no log row at all.
   - **a bad input** (an invalid filter or an unknown record): **Failed**, not Completed

   **A playbook meant for a schedule gets no `initialRequest`**, so its filter is hard-coded in the template. To test bad input, change the template temporarily (for example to `19*|((`), run, restore it, and read it back.
7. **Report in plain language** (see Reading a run). Say "reservations" or "records" when the count is rows, and never mix it up with a quantity. Fix only this playbook's records and rerun until all three cases behave.
8. **Go unattended only on the user's word:**
   - `Orchestrator.Playbook.Enqueue` for once later (at least 60 s)
   - `Orchestrator.Playbook.Schedule` for recurring. It needs a **Recurring Template** (`Recurring Template ori`); if none fits, propose one, such as Mondays 07:00, and create it on approval. Take the parameter values from `describe_message_type Orchestrator.Playbook.Schedule`, not from the guide: `notificationType` `None` | `EMail` | `Telegram`, `retryPolicy` `Never` | `ThreeTimes` | `Always`, and `notificationRecipient`.

   Say what will run, when, and who is notified. If the user wants a result such as "how many were released", the schedule's own notification may not include it. An email step does (see Deliver the result), so tell the user which one they are getting.

## Records

Write with `set_records` (or `Data.Records.Set` with the table in `subject`). The `{"tableName":…,"data":[…]}` shape does not pass the MCP gateway. **Write enum fields by their AL name** (`Check`, `Action`, `Success`, `Error`, `GreaterThan`). Reads give captions such as "Greater Than", which writes reject.

- **`Playbook ori`**: key `Code` (max 20 characters), plus `Description`. Use a clear, prefixed code, for example `SALES-OVERDUE-MAIL`.
- **`Playbook Step ori`**: key `PlaybookCode` + `StepNo_`. Number steps 10, 20, 30 so steps can be inserted later.
  - `MessageType`: the type name exactly.
  - `StepType`: `Action` (does work) or `Check` (decides the branch; a false Check is not a failure).
  - `RequestTemplate`: **base64** of the template JSON (UTF-8, no whitespace). Encode carefully and decode it back to check.
  - `ResultLogPaths`: fields later steps need. **Always include `status` and `error`.** `SummaryPaths` holds the few values for the run report.
  - `NextStepNo_Success` / `NextStepNo_Failure`: 0 means end. On a Check, the failure edge with 0 ends the run as **Completed**.
  - Also available: `IterateArrayPath` (run once per array element), `Paged` / `PageSize` (inject skip/take), `SkipIfStepFailed`, `StopOnItemError`, `Disabled`.
- **`Playbook Condition ori`**: key `PlaybookCode` + `StepNo_` + `ConditionType` + `GroupNo_` + `LineNo_`, with fields `Path`, `Operator`, `Value`.
  - `Start` runs before the step, against the workspace. False cancels the step and takes the success path.
  - `Success` runs after the step, against the step's **response**, and picks the branch. The path is relative, for example `count`.
  - `Error` runs after the step, against the **workspace**, and fails the run when true. The path is a workspace path, for example `10.status`.
  - Lines in the same group are all required; any one group holding is enough.
  - Operators: `Equals`, `NotEquals`, `Contains`, `GreaterThan`, `LessThan`, `GreaterOrEqual`, `LessOrEqual`, `Exists`.
  - The guide suggests a Success condition `status Equals Success`. Use it only for types whose successful answer contains `status`, which you can check in `describe_message_type`. Many types, for example `Legacy.Stock.List`, return no `status` on success, so that condition would always be false. Test for a field only a real answer has instead (`count Exists`, `released Exists`).

**Templates** use the message type's own parameter names:

- `@_initial.x` is the run's `initialRequest`.
- `@10.count` is step 10's logged `count`. A numeric string is passed as a number.
- `@_sys.today` and similar give dates; `@_who` is the user.
- `@collect:N` gathers step N's items; `@k1,k2` gives an escaped dump.

## Patterns

**Look, then act (the default for any bulk change).**

- Step 10 is a Check with the read type. It logs `count`, the filter, `status` and `error`. A Success condition `count GreaterThan 0` sends it to step 20, otherwise it ends.
- An Error condition `10.status Equals Error` fails the run on a bad input.
- Step 20 is an Action with the write type, getting its guard from step 10 (`"expectedCount":"@10.count"`). A Success condition on a field only a real answer has (`released Exists`) fails the run on an error body.
- Worked, tested example: `Bifrost Reference Playbooks/playbooks/REF-RELEASE.json` in the partner reference repo. For a scheduled version, replace `@_initial.itemFilter` with the fixed filter.

The two patterns below come from `Help.Orchestrator.Get`. They have not been tested live yet, so the three test cases in the workflow matter even more with them.

**Per item.** A read step returns an array under one key. The next step sets `IterateArrayPath` to it and uses `@_iter.<field>` in its template. Use `StopOnItemError` when one bad item should stop the rest.

**Deliver the result.** End with a report step (`Orchestrator.Report.SaveAs`) or an email step (`Email.Draft.Set`, then `Orchestrator.Email.Send`). Keep summaries small; the data belongs in result paths.

**Nothing fits.** If no message type does a step, say so and propose `LLM.Prompt.Complete` as a glue step only for text work (summarise, classify). Never use it to change data.

## Reading a run

- Read **`playbookStatus`** (`Completed` or `Failed`), **never `stepsFailed`** alone. A run failed by an Error condition reports `stepsFailed: 0` and an empty error text. The step itself is logged Completed. The reason is only in that step's `ResponseReceived`, so decode it and quote the error to the user.
- Read `Playbook Instance ori` for the run and `Playbook Step Log ori` for each step, with `Data.Records.Get` and a **`tableView`**: `{"tableView":"WHERE(Instance ID=CONST(<instanceId>))"}`. A `filters` array is silently ignored and returns every run, including other users', so never report from an unfiltered read. `RequestSent` and `ResponseReceived` are base64. Decode them and quote what each step sent and got.
- A Check whose condition was false is logged as Completed. That is the "nothing to do" path, not an error.
- A message type that answers with `status: Error` does not raise. Without the Error condition, the run looks Completed. If you find a playbook without it, point it out and offer to add it.
- A run that outlives the caller's timeout can stay "Running". Check `Playbook Instance ori` before running again.

## Explaining playbooks to people

Use the plain terms: a **recipe** of **steps**, a shared **notebook** (the workspace) and **gates** (conditions). Say what will happen in business words ("every weekday at 07:00, release reservations for discontinued items and email Anna the count"), not in field names. Show the step table, not the records.

## Never

- Schedule or enqueue without the user's explicit yes after a successful inline run.
- Leave out the guard on a write step, or the Error condition on a Check step.
- Run a new playbook in production first.
- Copy credentials or secrets into a template. Use the app's secret store and setup.
- Change playbooks, Job Queue entries or setup the user didn't ask about.
