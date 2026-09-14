# Writing help text that works as a contract, not documentation

`EXTENDING.md` says `GetMessageHelpAsMarkdownDocument` is mandatory. It doesn't say what to
put in it. This does — grounded in how Core's own 143 message types actually use it, not
just what would be nice to have.

## Why this is the most important document in this repo

When a message type is exposed as an MCP tool, the tool definition an agent sees is
**generated from your enum registration alone** unless it's one of a small number of
hand-curated tools with real, specific input schemas. Every other message type gets a
generic shape:

```
inputSchema : { "request": {"type":"string"}, "subject": {"type":"string"} }
description : "Executes the Your.Type.Name message type. Provide its JSON request payload
               in 'request'."
```

Nothing about your actual parameters, response shape, or failure modes is in that schema.
**Your help markdown is the only place any of that exists.** An agent choosing whether to
call your message type, and how to call it correctly, has nothing else to read. Writing thin
help text doesn't just make your operation less discoverable - it makes it the *only*
undocumented thing in an otherwise self-describing system.

## The standard, from real usage, not invention

Sampled 46 of Core's 143 shipped help documents across every domain. Section frequency:

| Section | Used by |
|---|---|
| `## Related Message Types` | **46 / 46** |
| `## Overview` | 45 / 46 |
| `## Request Parameters` | 42 / 46 |
| `## Errors` | 40 / 46 |
| `## Response Shape` | 36 / 46 |
| `## Idempotency / Safety` | 23 / 46 |
| `## Examples (from unit tests)` | 13 / 46 |

46/46 include a fenced JSON example somewhere in the document; 45/46 include at least one
table. Median length is around 3.0 KB - substantial, not a one-liner.

**`Related Message Types` is the only universal section, and that's not an accident.** Picture
the reader: an agent deciding between `Sales.Document.Post`, `.PreviewPost`, and `.Release`
picks wrong unless each document says what the other two are for. A message type's help text
is read comparatively, not in isolation.

### The skeleton to follow

```markdown
# Domain.Noun.Verb

One-paragraph overview - what this does and when to use it instead of a related type.

## Request Parameters
| Field | Type | Required | Notes |
|---|---|---|---|

## Response Shape
`{ ... }` - a real, complete example, not a description of one.

## Errors
What fails, and what the structured error looks like for each case.

## Idempotency / Safety
Is it safe to call this twice? What happens on a retry?

## Related Message Types
What else exists nearby, and how to choose between them.

## Examples
A worked call, ideally lifted from an actual test.
```

Not every document needs every section (see the real frequencies above) - but `Overview`,
`Request Parameters`, `Errors`, and `Related Message Types` are the four that carry the most
weight, in that order of how often real documents actually include them.

### The document to copy the shape of

Core's `SalesDocumentPostHelp` is the strongest example in the app: it names a failure mode
**that returns success** - posting flags default to false on API-created orders, so the call
succeeds and posts nothing - and gives the two-step fix as runnable JSON, not prose. That's
the standard: not "this can fail," but "here is the specific way it silently doesn't do what
you asked, and here is exactly how to avoid it."

## Three things this repo currently teaches differently than Core actually works

### 1. Help belongs in its own codeunit — usually

143/143 of Core's message types keep help text in a **separate** codeunit from the
implementation. This repo's examples keep it inline. Both are shown here now, deliberately:

- **Inline** (`RefEchoSetImpl.Codeunit.al`) - fine when the help text is genuinely short (four
  lines) and the type is simple enough that splitting it out would be pure ceremony.
- **Separate codeunit** (`RefNoteAddHelp.Codeunit.al` next to `RefNoteAddImpl.Codeunit.al`) -
  the pattern to default to once help text grows past a few lines, matching what Core
  actually does everywhere.

### 2. `IsEnabled` is a real gate, not a formality

Core's checks things like `WritePermission()` on the relevant table, or a posting-related
setup flag - a message type that returns `false` here **is not listed and cannot be chosen**,
which is a real access-control mechanism, not decoration. All three of this repo's original
examples returned `exit(true)` unconditionally. `RefNoteAddImpl` now gates on
`WritePermission()` against `Ref Note` - see the code, not just this description, for what an
honest gate looks like.

### 3. Idempotency/Safety - document it even though Core often doesn't

**Fewer than half of Core's own 46 sampled documents (23/46) cover retry safety.** That's a
real gap in the app this repo is modelled on - not a green light to skip it here too. If your
message type writes data, say explicitly whether calling it twice is safe. This is the one
place this repo is meant to be *better* than its own model, not a mirror of it.

## Two bugs this analysis also caught, both now fixed

- `resourceExposurePolicy` was backwards in this repo's three apps - `false` in
  `businesscentralal` (should be `true`; there's no source to protect in a public teaching
  repo) - now corrected.
- `QUICKSTART.md`'s curl example POSTed to `tasks` with no `subject`, which `tasks` declares
  `NotBlank` (unlike `queues`, where it's optional) - the example would have failed for
  anyone who ran it verbatim. Fixed.
