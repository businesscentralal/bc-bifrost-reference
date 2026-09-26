# More things partners build on Bifröst

The examples in this repo cover the patterns almost every app needs:

- a read
- a validated write
- a preview/apply pair
- an external call with a secret
- a headless facade with an adapter

These are further patterns partners are likely to need. Each has the pattern it should follow and the trap to avoid. They are candidates for the next examples.

| Idea | Typical use | Pattern | Trap to avoid |
|---|---|---|---|
| **Document with lines** | Create a sales quote or service order with lines in one call | Validate header and every line first. Run one isolated Process for header plus lines. Return the numbers. | Partial documents when line 3 fails. The ChangeLog write guard blocks generic `Data.Records.Set` on line tables, so write lines in your own Process codeunit. |
| **Post a document** | Post an invoice your app created | Pair a Check or PreviewPost with Post. Irreversible. Name the permission set. | Posting flags left unset. Base-app dialogs appear unless you use `SetHideValidationDialog`. |
| **Long-running job** | Recalculate or import thousands of records | Queue it (`queues` endpoint), return a job id, add a `…Status.Get` type | Timeouts on the synchronous `tasks` path |
| **Inbound webhook** | A payment provider calls BC | Subscribe to Foundation's webhook events; verify the signature with a secret. Must be idempotent. | Processing the same event twice |
| **Outbound notification** | Tell an external system when something changes | Business event or subscription, with a delivery log | Blocking the user's transaction on an HTTP call |
| **PDF or report output** | A statement or label for an agent to send | `InitializeRequest` + `SaveAs(…Pdf…)`, then `SetResponsePdf` | Request pages, and reports that `Commit` |
| **File intake** | A vendor invoice PDF into BC | Incoming Document + attach. Return the entry number for the next step. | Base64 size limits. A read type that also returns huge content by default. |
| **Delta sync** | An external system mirrors your table | Read with `SystemModifiedAt` from/to, return ids and changes. Page with skip/take. | Unbounded reads |
| **Approval step** | Send, approve or reject within your app's own flow | Build on Foundation's `Document.Approval.*` where possible | A second approval engine next to BC's |
| **Record-first discovery** | "What can I do with this record?" | A read type that takes a table and a record and returns the message types that act on it (via `GetFilterTableNo`) plus its status | Hard-coding lists that drift from the enum |
| **Metering / pricing** | Charge per call of your type | Implement `Msg Metering ori` for your types only | Pricing inside Foundation. It stays neutral by design. |
| **Take-over from an older app** | Move data from your pre-Bifröst app | Probe first, then copy. Idempotent and re-runnable. No Commit in install. Log each step. | A one-shot install that can't be repaired |

When you build one of these, fill in [CONTRACT.md](CONTRACT.md) first and add it here with a link.
