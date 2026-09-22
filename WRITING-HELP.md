# Writing help text that works as a contract

`EXTENDING.md` says `GetMessageHelpAsMarkdownDocument` is mandatory. This document says what to
put in it, and how to tell whether what you wrote is good enough.

## The test: five questions a machine must be able to answer

A help document is finished when a caller that has read **only this text** — an AI agent, an
integration developer, a script — can answer these five questions without guessing:

1. **Should I call this?** One verb on one subject. What it is for, and what it is *not* for
   (which neighbouring type to use instead).
2. **Is it safe?** What it changes in Business Central, and whether calling it twice is
   harmless or does something extra.
3. **With what?** Every request field: name, type, whether it is required, its default, and
   where a caller gets the value from.
4. **What will I get?** The response shape as real JSON, including the empty or no-op case
   (what comes back when there is nothing to return or nothing to do).
5. **What if it fails?** Every error the operation returns, with the **exact** `error` text
   the code produces, what it means, and what to do about it.

If the document cannot answer one of them, the caller will invent the answer. A message type
that does two things, or hides a side effect, cannot be documented into a good help text —
the document would have to lie. Fix the type first.

## Why this is the most important document in this repo

When a message type is exposed as a tool to an agent, the tool definition the agent sees is
generated from your enum registration alone: a generic `request` string and a `subject`
string, with a description that says little more than "executes this type". Nothing about your
actual parameters, response shape or failure modes is in that schema. **Your help markdown is
the only place any of that exists.** Thin help text does not make your operation less
discoverable; it makes it the only undocumented thing in an otherwise self-describing system.

## The skeleton

Sections in this order, headings as written. `# <Type.Name>` is exactly the enum caption.

````markdown
# Domain.Noun.Verb

## Overview
What it does, in one or two sentences. Then: when to use it, and what it is NOT for
(name the related type to use instead).

## Direction
Inbound - a write. What is inserted/modified/deleted on success; what is written on failure.
   or
Outbound - a read. Nothing is written.

## Request
| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `field` | string / number / boolean / date / object | yes / no | value or - | Where the value comes from, limits, truncation |

## Request example
```json
{ ... }
```

## Response
Prose: what the object/array is. Then a real, complete JSON example.
Then the empty or no-op case, and whether it is an error or a normal result.

## Errors
Every error has the shape {"status":"Error","error":"...","hint":"..."}.
| `error` | Meaning | `hint` |
| --- | --- | --- |
| `Exact text the code returns.` | what went wrong | what the caller should do |
One JSON example of an error response.

## Safety / repeat
Is calling it twice harmless? If not, exactly what the second call does.

## Related types
- `Other.Type.Name` - how to choose between it and this one.
````

Every section is present in every document, even when the answer is "none" — an empty Errors
table for a type that cannot fail tells the caller something; a missing section tells them
nothing.

## Direction: Inbound or Outbound

`GetMessageDirection` returns one of two values, and the help document repeats it in words:

- **Inbound** — the call writes *into* Business Central: it inserts, modifies or deletes at
  least one record on success. Say what is written, and what is written on failure (usually
  "nothing"). `Reference.Note.Add`, `Legacy.Stock.Reserve` and `Legacy.Stock.CancelReservation`
  are Inbound.
- **Outbound** — the call reads from Business Central and returns data; nothing is written.
  `Reference.Echo.Get` and `Reference.Table.Get` are Outbound.

The verb in the type name must agree with the direction: `Get` is Outbound; `Add`, `Reserve`,
`Cancel...`, `Set`, `Post` are Inbound. A `Get` that writes, or a `Set` that does not, is a
naming bug (see `EXTENDING.md` §2 for the one this repo had).

## A help document that works, and one that does not

Both describe the same operation from the Bifröst sample app. An agent reads only this text
before it decides whether to call the operation, and with what.

**This one produces guesses:**

```markdown
# Demo.Backlog.Get
Returns the backlog.
```

The agent does not know what "backlog" means here, whether it can filter, what comes back, what
an error looks like, or whether it is safe to call twice. It will invent a parameter, call the
operation, and interpret whatever it gets.

**This one produces a correct call:**

```markdown
# Demo.Backlog.Get

Returns open sales order lines that are past their promised shipment date — the order backlog
— for one customer or for all customers. Read-only; safe to call repeatedly.

## When to use
The user asks what is late, what is outstanding for a customer, or how large the backlog is.
Not for lines that are on time — use `Sales.Document.Get` for a single order.

## Request
| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `customerNo` | string | no | all customers | Customer No. as in Business Central, e.g. `10000` |
| `asOfDate` | date | no | today | Lines promised before this date count as late |
| `maxRows` | integer | no | 100 | 1–1000 |

## Response
Array of `{ documentNo, lineNo, customerNo, customerName, itemNo, description,
outstandingQuantity, promisedShipmentDate, daysLate }`, sorted by `daysLate` descending.
Empty array when nothing is late — not an error.

## Errors
| `error` starts with | Meaning | `hint` |
| --- | --- | --- |
| `Customer 10000 does not exist` | wrong `customerNo` | Look the customer up with `Data.Records.Get` on Customer first |
| `maxRows must be between 1 and 1000` | out of range | Retry with a value in range |

## Related
`Sales.Document.Get` for one order · `Sales.Document.Release` to release a held order
```

Same operation. The second document answers the five questions: what it is for and not for,
every field with type and default, the shape of the answer including the empty case, the
errors with what to do about them, whether repeating is safe. That is the difference between
an agent that helps and one that guesses.

## The rule: no implementation detail, no Origo infrastructure

The help document is a **contract with the caller**. It describes what the caller sends and
what the caller gets. It never describes how the type is built.

Do not mention:

- Procedure or codeunit names (`RespondWithError`, `RespondWithLastError`, `Codeunit.Run`,
  "isolated write codeunit", `Ref Note Add Process`, "impl codeunit").
- AL mechanics (`TryFunction`, `Commit`, `TableNo`, transactions, call stacks).
- Origo's own infrastructure or internal names (storage services, key stores, queues, CE-
  prefixed objects, "Core", "Foundation" internals).
- The history of the type ("this used to be called...", "extracted during the retrofit").
  That belongs in the XML doc comment above the codeunit, or in `EXTENDING.md` / `ADAPTING.md`.

Instead say what the caller observes: "fails with a structured error", "nothing is written",
"the same object is returned". If you find yourself needing an implementation word to explain
a behaviour, the behaviour is probably surprising — describe the surprise itself, in the
Safety / repeat section.

The help text is returned to every caller and published on the documentation site. Every
help-bearing codeunit in this repo carries this remark above its declaration as a reminder:

```al
/// <remarks>Public document: this text is returned to every caller and published on the documentation site. Contract only — see WRITING-HELP.md.</remarks>
```

## Errors: exact text, not paraphrase

The `error` column must contain the text the code actually returns, character for character,
with placeholders shown as a realistic value (`Table 'Foo' was not found.`, `A note with no.
'NOTE-1' already exists.`). A caller matches on this text. If you change a `Label`, change the
help document in the same commit. The `hint` field in the real response points the caller back
to this document; the `hint` column in the table is what you want them to read when they get
there.

## Safety / repeat: document it even when the answer is uncomfortable

If your message type writes data, say explicitly what calling it twice does. The three writes
in this repo give the three common answers:

- `Legacy.Stock.CancelReservation` — **safe**: the second call finds nothing and succeeds.
- `Reference.Note.Add` — **fails on repeat**: the second call with the same `no` gets the
  duplicate error; tell the caller how to interpret that after a timeout.
- `Legacy.Stock.Reserve` — **repeat has an effect**: the quantity is added again. This is the
  answer callers most need to see written down.

Bifröst tasks can be retried by infrastructure the caller does not control. A write that is
not safe to repeat is not wrong, but an undocumented one is.

## Related types: read comparatively

Picture the reader: an agent deciding between `Sales.Document.Post`, `.PreviewPost` and
`.Release` picks wrong unless each document says what the other two are for. A help document is
read comparatively, not in isolation. Every document lists its neighbours and says, in half a
line each, when to choose them instead.

## Where the text lives

- **Inline** in the impl codeunit (`RefEchoSetImpl.Codeunit.al`, `RefTableGetImpl.Codeunit.al`,
  the two Legacy adapters) — fine while the type is simple and one file is easier to review.
- **Separate codeunit** (`RefNoteAddHelp.Codeunit.al` next to `RefNoteAddImpl.Codeunit.al`) —
  the pattern to default to once the help grows or the impl codeunit is busy. The document is
  the same either way; only the file changes.

In both cases the text is built with `AppendLine('...')`, one Markdown line per call, single
quotes escaped as `''`. Keep lines short enough to read in a diff.

## `GetDescription` is the one-line version

`GetDescription()` (max 250 characters) is shown in lists before anyone opens the help. It
answers question 1 and, if it fits, question 2: one verb, one subject, the main constraint.
"Reserves a quantity of an item in Legacy App. Adds to any reservation that already exists for
the item; the quantity must be greater than zero." Not: "Thin wrapper over an existing
procedure." That sentence is about you, not about the caller.
