# Calling Bifröst without extending it

For an external system, host builder, or MCP server that wants to **call** Bifröst —
not add a message type in AL. If you're extending, see `EXTENDING.md` instead; the two are
different contracts with different audiences.

## The four endpoints

All requests go through one table (`Message ori`), exposed as four OData pages:

| Page | Entity set | Direction | Use it for |
|---|---|---|---|
| `Bifröst Queue API` | `queues` | POST — enqueue only | Volume, long-running work, fire-and-forget |
| `Bifröst Task API` | `tasks` | POST — enqueue **and** process | Interactive calls where you're waiting on the result |
| `CE Request Data API` | `requests` | GET — read-only | Reading back what you sent |
| `CE Response Data API` | `responses` | GET — read-only | Reading the result |

```
/api/origo/cloudEvent/v1.0/{queues|tasks|requests|responses}
```

**Never poll `tasks`** — it already did the work by the time it returns.

## Neither POST returns your payload directly

Both `queues` and `tasks` put a *relative link* in the response `data` field, not the payload
itself. Even the synchronous `tasks` path is really **two calls**: POST to `tasks`, then GET
the link it returns from `responses`. Budget for that round trip.

## The envelope is CloudEvents-shaped

```json
{
  "specversion": "1.0",
  "type": "Reference.Table.Get",
  "source": "my-integration",
  "subject": "CUST-001",
  "datacontenttype": "application/json",
  "data": "{\"tableName\":\"Customer\"}"
}
```

- `type` is the exact dotted enum name registered by whatever extension implements it — this
  repo's three examples are `Reference.Echo.Get`, `Reference.Table.Get`, `Reference.Note.Add`.
- **`data` is an escaped JSON *string*, not a nested object.** Sending `"data": { ... }` instead
  of `"data": "{...}"` is the single most common first-call mistake.
- `subject` is optional on `queues` but **required** on `tasks`. A payload that works against
  one can fail against the other.

## Every call is scoped to who made it

All four pages filter to `SystemCreatedBy = UserSecurityId()`. The identity that enqueues a
request must be the identity that reads its response back — there's no shared inbox across
callers.

## The error contract

Two failure shapes, both JSON, both carrying a `hint` field:

```json
{ "status": "Error", "error": "Table 'Foo' was not found.", "hint": "..." }
```

- **Expected failures** (bad input, not found, business rule) carry the exact `error` text
  listed in that message type's help document — match on it.
- **Unexpected failures** carry the underlying Business Central error text, and also include
  a call stack for the implementer.

**A response with no `status` field at all counts as success.** Don't treat a missing
`status` as a failure — that's the actual contract, not an omission.

The `hint` field routes you back to that message type's own help (`Help.MessageTypes.Get` /
`Help.Implementation.Get`) — every implementation in this repo writes its own via
`GetMessageHelpAsMarkdownDocument`, so the three examples here double as live documentation
you can query at runtime, not just read in source.

## Try it against this repo's three examples

| Type | Request | What it teaches |
|---|---|---|
| `Reference.Echo.Get` | `{ "message": "hi" }` | The envelope round trip, nothing else |
| `Reference.Table.Get` | `{ "tableName": "Customer" }` | A real lookup, with an expected-failure path (send a table name that doesn't exist) |
| `Reference.Note.Add` | `{ "no": "NOTE-1", "text": "hello" }` | A write, with a failure path raised by the write itself (send the same `no` twice) |
