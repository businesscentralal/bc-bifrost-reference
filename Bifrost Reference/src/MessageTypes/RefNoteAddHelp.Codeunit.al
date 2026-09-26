namespace Origo.Bifrost.Reference;

/// <summary>
/// Help text for Reference.Note.Add, kept in its own codeunit - the pattern to default to once
/// help text grows past a few lines (see the use card in CONTRACT.md).
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see CONTRACT.md.</remarks>
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
        HelpText.AppendLine('| `no` | string | yes | - | Your identifier for the note, max 20 characters; longer values are refused. Stored in upper case. Must not be empty or already exist. |');
        HelpText.AppendLine('| `text` | string | no | empty | The note text, max 250 characters. Longer values are refused. |');
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
        HelpText.AppendLine('| `Parameter ''no'' is required. Send it as text, for example "NOTE-1".` | The request has no `no` field. | Send `no`. |');
        HelpText.AppendLine('| `Parameter ''no'' is empty. Send a value, for example "NOTE-1".` | `no` is an empty string. | Send a value. |');
        HelpText.AppendLine('| `Parameter ''no'' is 25 characters long; the maximum is 20.` | Too long. | Shorten it. |');
        HelpText.AppendLine('| `A note with no. ''NOTE-1'' already exists. Choose a different no.; if this is a retry, the first attempt most likely succeeded.` | A note with that `no` is already stored. | Choose a different `no`. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('Example:');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "status": "Error", "error": "A note with no. ''NOTE-1'' already exists. ...", "hint": "..." }');
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
