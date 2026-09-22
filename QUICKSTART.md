# Quickstart: your first message type, start to finish

The other documents here explain the rules. This is the sequence - what to actually do, in
order, ending with a real call and a real response.

## 1. Clone and rename

```bash
git clone https://github.com/businesscentralal/bifrost-reference
cd bifrost-reference/"Bifrost Reference"
```

Pick a name for your extension and your object prefix. Rename the folder, `app.json`'s
`name`/`id`, and give yourself a real object ID range (`EXTENDING.md` §2) instead of this
repo's illustrative `90000-90049`.

## 2. Compile the unmodified example first

Before changing anything, prove the baseline compiles - this repo's own CI does exactly
this on every push (`.github/workflows/CICD.yaml`). If you have AL-Go / `bc-container-helper`
set up locally, or just VS Code with the AL extension and symbols downloaded for Cloud
Events Core, compile now. Fixing a problem you introduced is much easier than debugging one
you inherited.

## 3. Write your `ExecuteBifrostTask`, using the closest existing example

- Read-only, no failure path needed beyond "not found"? Start from `RefTableGetImpl`.
- A write? Start from `RefNoteAddImpl` + `RefNoteAddProcess` - copy the isolation pattern,
  don't skip it.
- Retrofitting an existing procedure instead of writing new logic? Read `ADAPTING.md` before
  this step - it changes which case you're in.

## 4. Register it and write the help text

Add your enum value (`RefMsgType.EnumExt.al` is the template) and write
`GetMessageHelpAsMarkdownDocument` for real - not a placeholder. This is what makes the type
discoverable later; skipping it is the single most common way a working message type never
gets used.

## 5. Compile again, then call it two ways

**From outside Business Central** (see `INTEGRATING.md` for the full contract):

```bash
curl -X POST "https://<env>/api/origo/cloudEvent/v1.0/tasks" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "specversion": "1.0",
    "type": "Reference.Echo.Get",
    "source": "quickstart",
    "subject": "quickstart-1",
    "datacontenttype": "application/json",
    "data": "{\"message\":\"hello\"}"
  }'
```

`subject` is required here - `tasks` declares it `NotBlank`, unlike `queues` where it's
optional (see `INTEGRATING.md`'s "Required fields differ per endpoint" table). Leaving it out
is the first thing that goes wrong if you copy this without reading that table.

The response's `data` field is a **link**, not the payload - GET it from `CE Response Data
API` (`/api/origo/cloudEvent/v1.0/responses`) to read the actual result. This two-call shape
is real, not a simplification - see `INTEGRATING.md`'s "Neither POST returns your payload
directly" section.

**From inside Business Central**, no HTTP at all (see `CALLING-FROM-AL.md` for the full
contract):

```al
Dispatcher.Execute(Enum::"Message Type ori"::"Reference.Echo.Get",
    Enum::"Message Version ori"::"1.0", '', '', 'application/json',
    RequestContent, ResponseContent, ResponseContentType);
```

Both calls reach the same implementation. Which one you use depends on where your caller
lives, not on the message type itself.

## 6. What "done" looks like

- It compiles.
- `Help.MessageTypes.Get` (or your own quick call) returns a description someone unfamiliar
  with your code could act on.
- You've triggered both the success path and at least one failure path (`RespondWithError`
  or `RespondWithLastError`) and checked the response shape matches what your help text says.
- If you're retrofitting: you've checked the existing procedure for `Confirm()`/`Message()`
  and `Commit()` per `ADAPTING.md`'s table, not just wrapped it and hoped.
