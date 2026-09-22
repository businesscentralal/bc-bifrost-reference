# Calling a message type from inside Business Central - no HTTP, no agent

`INTEGRATING.md` covers calling Bifröst from outside BC, over the OData API. This
covers a different, real question: **can AL code already running inside Business Central
call a message type directly, without an external caller at all?**

Yes. Verified against Core's own source (`app/src/Task/Dispatcher.Codeunit.al`,
codeunit `"Dispatcher ori"`) - a public, documented entry point that any
extension can call. It is not an internal implementation detail — Bifröst Language Models
uses this same codeunit to run its MCP tool calls without going through HTTP at all. (The MCP
tool server lived in the kernel under Cloud Events; in Bifröst it moved out. Foundation's
`RequestLogType.Enum.al` still carries the ordinal, with a comment saying why.)

## The two ways to call it

```al
Dispatcher: Codeunit "Dispatcher ori";
```

| Procedure | What it does | Use it when |
|---|---|---|
| `Execute(...)` | A convenience wrapper over `EnqueueAndProcess`. It **does** insert a `Message ori` row and **does** run the orchestrator. What it decides for you: an empty `TaskId`, so no webhook fires; the default language from `GetDefaultLanguageId()`; and `OmitCommit` = **`true`**. | You want the result without choosing those three - typically from another extension, or from a test. |
| `EnqueueAndProcess(...)` | The same pipeline with all three in your hands: pass a non-null `TaskId` and the webhook completion event fires, choose the language, and `OmitCommit` defaults to **`false`**. | You need the webhook event, a particular language, or the commit behaviour the HTTP API has. |

Both take the same shape: message type, version, subject, source, content type, request
payload as `BigText`, and give you back the response payload plus its content type.

:::caution `Execute` is not a "direct call"

It is easy to read `Execute` as a shortcut that skips the machinery. It does not. Every
overload delegates to `EnqueueAndProcess`, whose terminal overload does
`BifrostMessage.Insert(true)` and then `ProcessIncomingMessage(...)`; the codeunit declares
`Permissions = tabledata "Message ori" = rim` for exactly that reason. **A queue row is
written and the orchestrator runs.** The only part of the pipeline it skips is the webhook,
and only because the `TaskId` it passes is empty.

If you are calling it in a tight loop, budget for a table insert per call.

:::

## The one thing that will bite you: `OmitCommit`

Both procedures take an `OmitCommit` parameter, **and they do not default it the same way** -
`Execute` passes `true`, `EnqueueAndProcess` called without the flag uses `false`.

- **`OmitCommit = false`** (default): the orchestrator commits after processing. Normal case.
- **`OmitCommit = true`**: no commit - lets you chain multiple dispatch calls and roll all of
  them back together as one unit if something later fails.

**Message types that rely on `TryFunction` isolation (for example, a posting-preview style
operation) are incompatible with `OmitCommit = true`.** `TryFunction` needs a real commit
boundary to roll back to; skipping the commit removes that boundary. This is stated directly
in Core's own XML doc comments on the dispatcher - not a guess.

## Example: calling `Reference.Echo.Get` from another extension

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
    // ResponseContent now holds the JSON response - same shape as an HTTP caller would get.
end;
```

No API page, no OAuth, no network call - this runs entirely in-process, in the caller's own
transaction (unless `OmitCommit` is used to isolate it).

## Which license pool this consumes

Calling either procedure still consumes a license pool - it's just not the pool you might
assume. Foundation resolves the pool internally in `License.Codeunit.al`. `ResolvePool()` is
declared `internal`, so you cannot call it or override it from your own extension — this
section describes what Foundation will do to you, not an API you can drive. The rule: if the
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
