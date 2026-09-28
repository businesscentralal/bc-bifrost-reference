# Playbook definitions

One JSON file per playbook. Each file lists the records to create in `Playbook ori`, `Playbook Step ori` and `Playbook Condition ori`. Request templates are shown as plain JSON (`requestTemplate`) next to the base64 value that is actually stored (`requestTemplateBase64`).

| File | Playbook | Verified |
|---|---|---|
| `REF-RELEASE.json` | Release stock reservations matching a filter, guarded by the listed count | 26.09.2026, sandbox |

## Prerequisites

1. A **sandbox** with these apps installed:
   - Bifrost Foundation and **Bifrost Orchestrator**
   - **Legacy App v2** (folder `Legacy App v2 (headless)` in this repo). It supplies every message type this guide calls: `Legacy.Stock.List`, `Legacy.Stock.ReleaseAll`, `Legacy.Stock.Reserve` and `Legacy.Stock.Get`.
2. **ChangeLog guard exceptions (all fields)** for the three Playbook tables. Without them, `Data.Records.Set` refuses with *"Field "1" in table … must be included in the change log write guard setup"*. An administrator adds them in Bifrost Setup. The table numbers depend on the Orchestrator version, so look them up (for example `Help.Tables.Get`, or the number in that error message). In the verified sandbox they were:

   | Table | Number |
   |---|---|
   | `Playbook ori` | 10035539 |
   | `Playbook Step ori` | 10035540 |
   | `Playbook Condition ori` | 10035599 |

   **Check first, so you do not add them twice.** In Bifrost Setup, open the page **ChangeLog Guard Exceptions** and look for the three table numbers. If all three are listed, skip this step.

## Create REF-RELEASE

Use the MCP tool `set_records` (or `Data.Records.Set` with the table name in `subject`). The `{"tableName":…,"data":[…]}` shape shown in `Help.Orchestrator.Get` is refused by the MCP gateway.

The blocks below are shorthand. `set_records  table "Playbook ori"` followed by an array means: call the MCP tool `set_records` with parameter `table` = the table name and parameter `records` = the array shown.

**The code `REF-RELEASE` appears in all six primary keys**: 1 in the playbook, 2 in the steps, 3 in the conditions. To make your own copy, change it in all six. If `REF-RELEASE` already exists, running the calls unchanged overwrites it without asking.

Write enum fields by their AL name (`Check`, `GreaterThan`, `Success`, `Error`). A read gives back captions (`Greater Than`), which a write rejects.

**1. Playbook**

```json
set_records  table "Playbook ori"
[{"primary_key":{"Code":"REF-RELEASE"},
  "fields":{"Description":"Reference: release stock reservations matching a filter, guarded by the listed count"}}]
```

**2. Steps**

`RequestTemplate` is a BLOB. You pass the base64 of the template JSON (UTF-8, no whitespace):

| Step | Template | Base64 |
|---|---|---|
| 10 | `{"itemFilter":"@_initial.itemFilter"}` | `eyJpdGVtRmlsdGVyIjoiQF9pbml0aWFsLml0ZW1GaWx0ZXIifQ==` |
| 20 | `{"itemFilter":"@10.itemFilter","expectedCount":"@10.count"}` | `eyJpdGVtRmlsdGVyIjoiQDEwLml0ZW1GaWx0ZXIiLCJleHBlY3RlZENvdW50IjoiQDEwLmNvdW50In0=` |

To produce your own: PowerShell `[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('<json>'))`, or `printf '%s' '<json>' | base64 -w0`.

```json
set_records  table "Playbook Step ori"
[{"primary_key":{"PlaybookCode":"REF-RELEASE","StepNo_":10},
  "fields":{"Description":"List reservations matching the filter",
    "MessageType":"Legacy.Stock.List","StepType":"Check",
    "RequestTemplate":"eyJpdGVtRmlsdGVyIjoiQF9pbml0aWFsLml0ZW1GaWx0ZXIifQ==",
    "ResultLogPaths":"count,itemFilter,status,error",
    "SummaryPaths":"count,totalQuantity",
    "NextStepNo_Success":20,"NextStepNo_Failure":0}},
 {"primary_key":{"PlaybookCode":"REF-RELEASE","StepNo_":20},
  "fields":{"Description":"Release them, guarded by the listed count",
    "MessageType":"Legacy.Stock.ReleaseAll","StepType":"Action",
    "RequestTemplate":"eyJpdGVtRmlsdGVyIjoiQDEwLml0ZW1GaWx0ZXIiLCJleHBlY3RlZENvdW50IjoiQDEwLmNvdW50In0=",
    "SummaryPaths":"released",
    "NextStepNo_Success":0,"NextStepNo_Failure":0}}]
```

**3. Conditions**

```json
set_records  table "Playbook Condition ori"
[{"primary_key":{"PlaybookCode":"REF-RELEASE","StepNo_":10,"ConditionType":"Success","GroupNo_":1,"LineNo_":10000},
  "fields":{"Path":"count","Operator":"GreaterThan","Value":"0"}},
 {"primary_key":{"PlaybookCode":"REF-RELEASE","StepNo_":10,"ConditionType":"Error","GroupNo_":1,"LineNo_":10000},
  "fields":{"Path":"10.status","Operator":"Equals","Value":"Error"}},
 {"primary_key":{"PlaybookCode":"REF-RELEASE","StepNo_":20,"ConditionType":"Success","GroupNo_":1,"LineNo_":10000},
  "fields":{"Path":"released","Operator":"Exists","Value":""}}]
```

What each part does:

- **Step 10 is a `Check`.** If `count` is 0, the step routes down the failure edge (`0` = end) and the run ends **Completed**, not Failed. Nothing to release is a normal answer.
- **Step 10's `Error` condition** fails the run when `Legacy.Stock.List` answers with an error body. See "Finding" below for why it is needed.
- **Step 20 gets `expectedCount` from step 10** (`@10.count`, injected as a number). If the reservations changed between the two steps, `Legacy.Stock.ReleaseAll` refuses and writes nothing.
- **Step 20's `released Exists`** fails the run on any error body, which has no `released`.
- No `status Equals Success` condition: the Legacy types return no `status` on success, so that condition would always be false.

## Prepare test data

The playbook needs a reservation to release. This call creates one of quantity 1 on item 1896-S:

```json
invoke_message_type  Legacy.Stock.Reserve
{"itemNo":"1896-S","quantity":1}
```

Make the call when the test below says so (before run b), not before run a.

## Run it inline

```json
invoke_message_type  Orchestrator.Playbook.Run
{"playbookCode":"REF-RELEASE","initialRequest":{"itemFilter":"1896-S"}}
```

`initialRequest` is available to the steps as `@_initial.*`. The response carries the `instanceId` of the run; keep it for reading the step log.

## Test it: the three runs

Run these in order. This is what you should see.

| Run | Before | `initialRequest` | Expected response | Step log |
|---|---|---|---|---|
| a | No reservation on 1896-S | `{"itemFilter":"1896-S"}` | `playbookStatus: Completed`, `stepsExecuted: 1` | Step 10 got `count: 0`. Step 20 did not run. |
| b | Call `Legacy.Stock.Reserve` (above) | `{"itemFilter":"1896-S"}` | `playbookStatus: Completed`, `stepsExecuted: 2` | Step 20 sent `{"itemFilter":"1896-S","expectedCount":1}` and got `released: 1`. |
| c | - | `{"itemFilter":"(("}` | `playbookStatus: Failed`, `stepsExecuted: 1`, `stepsFailed: 0` | Step 10 got `status: Error`. The Error condition failed the run. |

Run c reports `stepsFailed: 0` although the run failed. Always check `playbookStatus`.

**End check:**

```json
invoke_message_type  Legacy.Stock.Get
{"itemNo":"1896-S"}
```

Expected: `reservedQuantity: 0`.

## Reading a run

Read the step log of one run with `Data.Records.Get`, filtered on the `instanceId` from the Run response:

```json
invoke_message_type  Data.Records.Get
subject "Playbook Step Log ori"
{"tableView":"WHERE(Instance ID=CONST(<instanceId from the Run response>))"}
```

The runs of a playbook, the same way:

```json
invoke_message_type  Data.Records.Get
subject "Playbook Instance ori"
{"tableView":"WHERE(Playbook Code=CONST(REF-RELEASE))"}
```

**Use `tableView`, not a `filters` array.** A `filters` array is silently ignored, and the call returns every run, including other users' runs.

`RequestSent` and `ResponseReceived` in the step log are base64. To decode one in PowerShell:

```powershell
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('<base64>'))
```

## Build history: what the runs returned (26.09.2026)

This is the log from building the playbook, not what you see when you follow this guide. Run 3 was made before step 10 had its Error condition, so it ended Completed. With the definition above, an invalid filter always ends Failed (run c).

Start state: item 1896-S had one reservation of 1005.

| # | Request | Playbook.Run response | Step log |
|---|---|---|---|
| 1 | `1896-S` | `playbookStatus: Completed`, `stepsExecuted: 2`, `stepsFailed: 0` | 10 sent `{"itemFilter":"1896-S"}`, got `count: 1, totalQuantity: 1005`. 20 sent `{"itemFilter":"1896-S","expectedCount":1}`, got `{"itemFilter":"1896-S","released":1}`. The release shows in `Legacy Cancellation Log`. |
| 2 | `1896-S` again | `Completed`, `stepsExecuted: 1`, `stepsFailed: 0` | 10 got `count: 0`. Step 20 did not run. |
| 3 | `((` (invalid), before the Error condition was added | `Completed`, `stepsExecuted: 1`, `stepsFailed: 0` | 10 got `{"status":"Error","error":"Parameter 'itemFilter' is '((', which is not a valid filter: …"}`. Step log `Status: Completed`, `ErrorText` empty. |
| 4 | `((`, with the Error condition | `playbookStatus: Failed`, `stepsExecuted: 1`, `stepsFailed: 0` | Same response. The instance is Failed. |
| 5 | `1896-S`, with the Error condition | `Completed`, `stepsExecuted: 1`, `stepsFailed: 0` | `count: 0`. The Error condition does not trigger on a normal answer. |

`Legacy.Stock.List` afterwards: `count: 0` for 1896-S.

## Finding: a Check step treats an error body as "nothing to do"

A message type that answers with `RespondWithError` does not raise, so the engine sees a normal response. In run 3, `Legacy.Stock.List` returned `status: Error`. There was no `count`, so the `count GreaterThan 0` condition was false. Being a `Check` step, it took the failure edge and the run ended **Completed**, reporting nothing. The step log also said `Completed` with an empty `ErrorText`. The error text is visible only by decoding `ResponseReceived`.

**Fix used here:** log `status` (and `error`) from step 10 with `Result Log Paths`, and add an `Error` condition `10.status Equals Error`. The run then ends **Failed** (run 4). Note that `stepsFailed` stays 0 in that case, so check `playbookStatus`, not `stepsFailed`.

Apply the same pattern to any `Check` step whose message type reports errors in the response body.
