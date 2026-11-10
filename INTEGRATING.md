# Calling Bifröst

For an external system, an MCP host or AL code that wants to **call** message types. To add one, see [BUILDING.md](BUILDING.md). Full API, authentication and MCP setup: <https://docs.bifrost.origo.is/en-us/documentation/end-customers/developers/>.

## The endpoints

The endpoints, their URLs per company, authentication and the background flow are described once, on the public
site: [Where the endpoints are](https://docs.bifrost.origo.is/en-us/documentation/end-customers/developers/#where-the-endpoints-are).
In short: `tasks` (run now), `queues` (run in the background), `responses` and `requests` (read back), under
`/api/origo/bifrost/v1.0/`. This guide adds what you learn by calling them:

Neither POST returns your payload: the response `data` holds a *relative link*. Even `tasks` is two calls: POST, then GET the link from `responses`. **Never poll `tasks`**; the work is done when the POST returns.

All four pages filter to `SystemCreatedBy = UserSecurityId()`: the identity that sends a request must read its response.

## The envelope

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

- `type` is the exact message type name.
- **On the API, `data` is a JSON string** with the request object escaped inside it. Contract examples show it as an object for readability.
- `specversion`, `type` and `source` are required. `subject` is also required on `tasks` (send any non-empty value, e.g. `"try-1"`, for types that don't use it).
- Add `"lcid": 1039` to get error texts in another installed language.

```bash
curl -X POST "https://api.businesscentral.dynamics.com/v2.0/<tenant>/<environment>/api/origo/bifrost/v1.0/companies(<company id>)/tasks" \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"specversion":"1.0","type":"Reference.GLAccount.Overview.Get","source":"my-integration","subject":"2910","datacontenttype":"application/json","data":"{\"asOfDate\":\"2026-08-31\"}"}'
```

## Read the contract first

`Help.Implementation.Get` with the type name as `subject` (MCP: `get_message_type_help`) returns the type's contract as JSON chapters: overview, envelope, target, parameters, response, errors, effect, metering, related, workflow, examples, notes. Check `effect` (`read`, `write`, `irreversible`) and `preconditions` before calling a write, and follow `workflow` (for example preview before apply).

## Errors

```json
{ "status": "Error", "error": "G/L account '99999' was not found. Check the number, or search for the account with Data.Records.Get on table G/L Account.", "hint": "..." }
```

- **A response with no `status` field is a success.**
- Expected failures carry the exact text listed in the type's `errors` chapter. Match on it.
- Unexpected failures carry the Business Central error text.
- The `hint` points to `Help.Implementation.Get` for the type.

## Types to try first

| Type | `subject` / `data` | Shows |
|---|---|---|
| `MyApp.Hello.Get` | `data`: `{"name":"World"}` | The app is live, and which version answered |
| `Reference.Echo.Get` | `data`: `{"message":"hi"}` | The envelope round trip |
| `Reference.GLAccount.Overview.Get` | `subject`: `2910`, `data`: `{"asOfDate":"2026-08-31"}` | A read; send `99999` for "not found" |
| `Legacy.Stock.Get` | `subject`: `1896-S` | A read from an existing app made headless |
| `Reference.Note.Add` | `data`: `{"no":"NOTE-1","text":"hello"}` | A write; send the same `no` twice for "already exists" |

## Secrets

Never send API keys or passwords through an AI chat. People enter them in **Bifrost Setup > Apps**. Integrations that must set one use the app's own type (e.g. `Reference.ApiKey.Set`), which stores it in the secret store and redacts the request from the message log.

## Calling from AL

AL code in Business Central calls any type without HTTP through the public codeunit `"Dispatcher ori"`:

| Procedure | Use it when |
|---|---|
| `Execute(…)` | You want the result. Default language, no completion event, `OmitCommit` **true** unless you pass it (9-parameter overload). |
| `EnqueueAndProcess(…)` | You need a Task Id (raises `OnBifrostMessageCompleted` on completion), a specific `WindowsLanguageId`, or the commit behaviour of the API (`OmitCommit` defaults to **false**). Overloads return the response as `BigText` or `Temp Blob`. |

Both write a `Message ori` row and run the full pipeline; budget one insert per call. With `OmitCommit = true` nothing is committed for you and errors raised inside an isolated write are raised out of the call; types that need their own commit boundary (posting previews) need `OmitCommit = false`.

```al
var
    Dispatcher: Codeunit "Dispatcher ori";
    RequestContent: BigText;
    ResponseContent: BigText;
    ResponseContentType: Text[100];
begin
    RequestContent.AddText('{"message":"hello"}');   // the data object only, not the envelope
    Dispatcher.Execute(
        Enum::"Message Type ori"::"Reference.Echo.Get",
        Enum::"Message Version ori"::"1.0",
        '', '', 'application/json',
        RequestContent, ResponseContent, ResponseContentType);
    // ResponseContent holds the same JSON an HTTP caller would get.
end;
```

In-process calls count as usage like any other call; from an interactive session they count against the user.
