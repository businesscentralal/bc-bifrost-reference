# Calling a message type from inside Business Central - no HTTP, no agent

`INTEGRATING.md` covers calling Bifröst from outside BC, over the OData API. This
covers a different, real question: **can AL code already running inside Business Central
call a message type directly, without an external caller at all?**

Yes. Verified against Core's own source (`app/src/Task/Dispatcher.Codeunit.al`,
codeunit `"Dispatcher ori"`) - a public, documented entry point that any
extension can call. It is not an internal implementation detail: Core's own new in-process
MCP Tool Server (`CE MCP Tool Executor`) uses this exact codeunit to run tool calls without
going through HTTP at all.

## The two ways to call it

```al
Dispatcher: Codeunit "Dispatcher ori";
```

| Procedure | What it does | Use it when |
|---|---|---|
| `Execute(...)` | Calls the interface implementation directly. Nothing is persisted - no queue row, no orchestration (no language switching, response-time tracking, retention, webhook). Fastest. | You want the business logic result and nothing else - typically from another extension, or from a test. |
| `EnqueueAndProcess(...)` | Inserts a real `Message ori` row and runs the same orchestrator the HTTP API uses, synchronously. Full pipeline: language switching, response time, retention, and - if you pass a non-null `TaskId` - the webhook completion event. | You want the call to be auditable the same way an external call would be, or you need the webhook event to fire. |

Both take the same shape: message type, version, subject, source, content type, request
payload as `BigText`, and give you back the response payload plus its content type.

## The one thing that will bite you: `OmitCommit`

Both procedures have an `OmitCommit` parameter (default `false`).

- **`OmitCommit = false`** (default): the orchestrator commits after processing. Normal case.
- **`OmitCommit = true`**: no commit - lets you chain multiple dispatch calls and roll all of
  them back together as one unit if something later fails.

**Message types that rely on `TryFunction` isolation (for example, a posting-preview style
operation) are incompatible with `OmitCommit = true`.** `TryFunction` needs a real commit
boundary to roll back to; skipping the commit removes that boundary. This is stated directly
in Core's own XML doc comments on the dispatcher - not a guess.

## Example: calling `Reference.Echo.Set` from another extension

```al
var
    Dispatcher: Codeunit "Dispatcher ori";
    RequestContent: BigText;
    ResponseContent: BigText;
    ResponseContentType: Text[50];
begin
    RequestContent.AddText('{"message":"hello"}');
    Dispatcher.Execute(
        Enum::"Message Type ori"::"Reference.Echo.Set",
        Enum::"CE Message Version ori"::"1.0",
        '', '', 'application/json',
        RequestContent, ResponseContent, ResponseContentType);
    // ResponseContent now holds the JSON response - same shape as an HTTP caller would get.
end;
```

No API page, no OAuth, no network call - this runs entirely in-process, in the caller's own
transaction (unless `OmitCommit` is used to isolate it).

## Which license pool this consumes

Calling either procedure still consumes a license pool - it's just not the pool you might
assume. Core resolves the pool with `ResolvePool()` (`License.Codeunit.al`): if the
current session is a Microsoft Entra application (service principal), it charges the **App
Registration** pool; otherwise it charges the **User** pool. A normal interactive BC session -
which is what's running when a button click in a page triggers this call - is not an AAD
application, so it resolves to `User` every time. In other words: calling a message type from
AL inside BC meters against the same **User** pool as an interactive person using the UI, not
against the App Registration pool that external, service-principal-authenticated callers use.
If you were expecting your in-process calls to be "free" or counted separately, they aren't -
plan license capacity accordingly.

## Why this matters for both guides in this repo

- If you're **extending** (`EXTENDING.md`): your message type is callable this way for free,
  the moment it's registered in the enum - you never write anything for the in-process path.
- If you're **adapting** an existing solution (`ADAPTING.md`): this is a second reason a
  retrofit is worth doing even if you have no external callers yet - other extensions inside
  the same Business Central instance gain a stable, documented way to call your logic
  without a direct app dependency on it.
