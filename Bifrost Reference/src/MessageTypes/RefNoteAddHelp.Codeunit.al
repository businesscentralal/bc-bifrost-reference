namespace Origo.Bifrost.Reference;

/// <summary>
/// Help text for Reference.Note.Add, kept in its own codeunit - the pattern to default to once
/// help text grows past a few lines (see WRITING-HELP.md). Follows the full skeleton: Overview,
/// Direction, Request, Request example, Response, Errors, Safety / repeat, Related types.
/// </summary>
/// <remarks>Public document: this text is returned to every caller and published on the documentation site. Contract only — see WRITING-HELP.md.</remarks>
codeunit 90005 "Ref Note Add Help"
{
    Access = Internal;

    internal procedure GetHelpText(): Text
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Reference.Note.Add');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Creates one Reference Note record, identified by the number you give in `no`, holding the');
        HelpText.AppendLine('text you give in `text`.');
        HelpText.AppendLine('');
        HelpText.AppendLine('Use it to store a short free-text note under a number you choose. Not for changing or');
        HelpText.AppendLine('deleting an existing note - there is no update or delete type, and a `no` that already');
        HelpText.AppendLine('exists is rejected, not overwritten. Not for reading notes back.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Direction');
        HelpText.AppendLine('Inbound - a write. On success one record is inserted into the Reference Note table.');
        HelpText.AppendLine('On failure nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request');
        HelpText.AppendLine('| Field | Type | Required | Default | Notes |');
        HelpText.AppendLine('| --- | --- | --- | --- | --- |');
        HelpText.AppendLine('| `no` | string | yes | - | Your identifier for the note, max 20 characters; longer values are cut to 20. Stored as a code value (upper case). Must not already exist. |');
        HelpText.AppendLine('| `text` | string | yes | - | The note text, max 250 characters; longer values are cut to 250. May be empty. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "no": "NOTE-1", "text": "hello" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('One object with the number under which the note was stored. No `status` field means success.');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "no": "NOTE-1" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('There is no empty result: the call either inserts one note and returns its `no`, or fails.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('Every error has the shape `{"status":"Error","error":"...","hint":"..."}`; `hint`');
        HelpText.AppendLine('points back to this document. On every error listed here nothing has been written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('| `error` | Meaning | `hint` |');
        HelpText.AppendLine('| --- | --- | --- |');
        HelpText.AppendLine('| `Missing required field ''no''.` | The request has no `no` field. | Send both `no` and `text`. |');
        HelpText.AppendLine('| `Missing required field ''text''.` | The request has no `text` field. | Send both `no` and `text`; an empty string is accepted. |');
        HelpText.AppendLine('| `A note with no. ''NOTE-1'' already exists.` | A note with that `no` is already stored (`NOTE-1` is the value you sent). | Choose a different `no`. If this is a retry, the first attempt most likely succeeded. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('Example:');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "status": "Error", "error": "A note with no. ''NOTE-1'' already exists.", "hint": "..." }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safety / repeat');
        HelpText.AppendLine('**Not safe to repeat with the same `no`.** The first call inserts the note; a second call');
        HelpText.AppendLine('with the same `no` fails with the "already exists" error above and changes nothing. A');
        HelpText.AppendLine('caller that retries after a timeout should therefore treat "already exists" as');
        HelpText.AppendLine('"the first attempt went through", or use a fresh `no` per attempt.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related types');
        HelpText.AppendLine('- `Reference.Echo.Get` - connectivity check; no write, no failure path.');
        HelpText.AppendLine('- `Reference.Table.Get` - a read with a structured "not found" error.');
        exit(HelpText.ToText());
    end;
}
