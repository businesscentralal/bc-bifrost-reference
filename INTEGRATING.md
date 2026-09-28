# Calling Bifröst

For an external system, an MCP host, or AL code that wants to **call** message types, not add them. To add a message type, see [`START-HERE.md`](START-HERE.md).

## The four endpoints

All requests go through one table (`Message ori`), exposed as four OData API pages:

| Page | Entity set | Method | Use it for |
|---|---|---|---|
| `Queue API ori` | `queues` | POST: enqueue only | Volume, long-running work, fire-and-forget |
| `Task API ori` | `tasks` | POST: enqueue **and** process | Interactive calls where you wait for the result |
| `Request Data API ori` | `requests` | GET, read-only | Reading back what you sent |
| `Response Data API ori` | `responses` | GET, read-only | Reading the result |

```
/api/origo/bifrost/v1.0/{queues|tasks|requests|responses}
```

**Never poll `tasks`.** The work is done by the time the POST returns.

## Neither POST returns your payload directly

Both `queues` and `tasks` put a *relative link* in the response `data` field, not the payload. Even the synchronous `tasks` path is two calls: POST to `tasks`, then GET the link from `responses`.

## The envelope is CloudEvents-shaped

```json
{
  "specversion": "1.0",
  "type": "Reference.GLAccount.Overview.Get",
  "source": "my-integration",
  "subject": "2910",
  "datacontenttype": "application/json",
  "data": "{\"asOfDate\":\"2026-08-31\"}"
}
```

- `type` is the exact dotted name of the message type, e.g. `Reference.GLAccount.Overview.Get` or `Legacy.Stock.Get`.
- **On the API, `data` is a JSON *string*,** with the request object escaped inside it: `"data": "{\"asOfDate\":\"2026-08-31\",\"fromDate\":\"2026-08-01\"}"`. The help documents show the request as an object for readability; over OData you send it as a string.
- `specversion`, `type` and `source` are required on both endpoints. `subject` is also required on `tasks` and optional on `queues`.

### A runnable call

```bash
curl -X POST "https://api.businesscentral.dynamics.com/v2.0/<tenant>/<environment>/api/origo/bifrost/v1.0/companies(<company id>)/tasks" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "specversion": "1.0",
    "type": "Reference.GLAccount.Overview.Get",
    "source": "my-integration",
    "subject": "2910",
    "datacontenttype": "application/json",
    "data": "{\"asOfDate\":\"2026-08-31\"}"
  }'
```

The response's `data` is a link. GET it (from `responses`) with the same token to read the account overview (`balanceAsOf` on 2026-08-31; `netChange` is `null` because no `fromDate` was sent).

## Every call is scoped to who made it

All four pages filter to `SystemCreatedBy = UserSecurityId()`. The identity that sends a request must be the identity that reads its response. There is no shared inbox across callers.

## The error contract

Failures are JSON with a `hint` field:

```json
{ "status": "Error", "error": "G/L account '99999' was not found. Check the number, or search for the account with Data.Records.Get on table G/L Account.", "hint": "..." }
```

- **Expected failures** (bad input, not found, business rule) carry the exact `error` text listed in that message type's help. Match on it.
- **Unexpected failures** carry the underlying Business Central error text. Types that answer with Foundation's `RespondWithLastError()` also add a `callstack` field. The reference types answer with `RespondWithError(GetLastErrorText())`, so they send no call stack.
- **A response with no `status` field is a success.** That is the contract, not an omission.

The `hint` tells the caller to call `Help.Implementation.Get` with the message type's name as subject (MCP tool: `get_message_type_help`). Every type in this repository writes its own help, so you can read the contract at runtime.

## Types to try first

| Type | `subject` / `data` | What it teaches |
|---|---|---|
| `Reference.Echo.Get` | `data`: `{"message":"hi"}` | The envelope round trip, nothing else |
| `Reference.GLAccount.Overview.Get` | `subject`: `2910`, `data`: `{"asOfDate":"2026-08-31"}` | A read; send `99999` for the "not found" error, and no `fromDate` to see `netChange: null` |
| `Legacy.Stock.Get` | `subject`: `1896-S` | A read from an existing app made headless, with its message types in the same app (Legacy App v2) |
| `Reference.Note.Add` | `data`: `{"no":"NOTE-1","text":"hello"}` | A write; send the same `no` twice for the "already exists" error |

`Reference.Echo.Get` and `Reference.Note.Add` don't read `subject`. On `tasks` it is still required, so send any non-empty value, for example `"try-1"`.

## Calling from AL

AL code already running in Business Central can call any message type without HTTP, through the public codeunit `"Dispatcher ori"`.

| Procedure | What it does | Use it when |
|---|---|---|
| `Execute(...)` | Calls `EnqueueAndProcess` for you with an empty Task Id (no completion event), the default language from Bifrost Setup, and `OmitCommit` **true** unless you pass it. | You want the result and don't need to choose those. Typical for another extension or a test. |
| `EnqueueAndProcess(...)` | The same pipeline with everything in your hands: a Task Id (a non-null one raises `OnBifrostMessageCompleted` when the message completes), the language, and `OmitCommit`, which defaults to **false**. | You need the completion event, a particular language, or the commit behaviour of the HTTP API. |

**Both write a `Message ori` row and run the orchestrator.** `Execute` is not a shortcut past the queue table. Budget for one insert per call in a loop.

**Overloads:**

- `Execute`: 8 parameters (message type, version, subject, source, content type, request `BigText`, response `BigText`, response content type), always `OmitCommit = true`; 9 parameters with `OmitCommit`.
- `EnqueueAndProcess`: adds `TaskId`, `WindowsLanguageId`, `MessageId` and `ResponseTime` (12 parameters, `OmitCommit = false`; 13 with the flag). Two more overloads return the response in a `Temp Blob` instead of a `BigText`.

**`OmitCommit`:**

- `false`: the orchestrator commits after processing. The normal case.
- `true`: nothing is committed for you, so you can chain calls and roll them back together.
- **Types that rely on `TryFunction` isolation (for example a posting preview) don't work with `OmitCommit = true`.** Use the 9-parameter `Execute` or `EnqueueAndProcess` with `OmitCommit = false` for them.

```al
var
    Dispatcher: Codeunit "Dispatcher ori";
    RequestContent: BigText;
    ResponseContent: BigText;
    ResponseContentType: Text[50];
begin
    RequestContent.AddText('{"message":"hello"}');
    Dispatcher.Execute(
        Enum::"Message Type ori"::"Reference.Echo.Get",
        Enum::"Message Version ori"::"1.0",
        '', '', 'application/json',
        RequestContent, ResponseContent, ResponseContentType);
    // ResponseContent holds the same JSON an HTTP caller would get.
end;
```

**Usage.** In-process calls count as usage like any other call. From an interactive session (a user clicking a page action), they count against the **User** pool, not the App Registration pool that service-principal callers use. Whether your own pages call your message types this way is your choice; see `START-HERE.md` §7.3.

A type that raises an `Error()` (rather than answering with `RespondWithError`) raises it out of the dispatcher too. Catch it in your own code if the caller must survive.
