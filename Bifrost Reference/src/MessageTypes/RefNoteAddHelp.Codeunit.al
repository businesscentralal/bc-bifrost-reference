namespace Origo.Bifrost.Reference;

/// <summary>
/// Help text for Reference.Note.Add, kept in its own codeunit - the pattern Core uses for
/// all 143 of its message types once help text grows past a few lines (see WRITING-HELP.md).
/// Follows the full skeleton: Overview, Request Parameters, Response Shape, Errors,
/// Idempotency/Safety, Related Message Types, Examples - the four Core uses most often are
/// Overview, Request Parameters, Errors, and Related Message Types, in that order.
/// </summary>
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
        HelpText.AppendLine('Creates a note record identified by ''no.''. Demonstrates the mandatory write-isolation pattern - the actual insert happens in a separate codeunit invoked via Codeunit.Run(), so a failure is caught and reported without rolling back the caller''s transaction.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request Parameters');
        HelpText.AppendLine('| Field | Type | Required | Notes |');
        HelpText.AppendLine('|---|---|---|---|');
        HelpText.AppendLine('| `no` | string | Yes | Max 20 characters. Must not already exist. |');
        HelpText.AppendLine('| `text` | string | Yes | Max 250 characters. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response Shape');
        HelpText.AppendLine('`{ "no": "NOTE-1" }` - no `status` field means success.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('- Missing `no` or `text` -> `RespondWithError`, "Missing required field ''...''."');
        HelpText.AppendLine('- `no` already exists -> `RespondWithLastError`, raised from the isolated write codeunit, e.g. "A note with no. ''NOTE-1'' already exists."');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Idempotency / Safety');
        HelpText.AppendLine('**Not safe to retry with the same `no`.** A retry after a transient failure (network timeout, caller giving up before reading the response) will get a duplicate-key error even though the first attempt may have already succeeded. Callers that retry should generate a new `no` per attempt, or check whether the note already exists before retrying.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related Message Types');
        HelpText.AppendLine('- `Reference.Echo.Set` - no write, no failure path; start there if you only need the envelope round trip.');
        HelpText.AppendLine('- `Reference.Table.Get` - a read with a structured error path, no write isolation needed.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Examples');
        HelpText.AppendLine('Request: `{ "no": "NOTE-1", "text": "hello" }`');
        HelpText.AppendLine('Success: `{ "no": "NOTE-1" }`');
        HelpText.AppendLine('Duplicate: `{ "status": "Error", "error": "A note with no. ''NOTE-1'' already exists.", "hint": "..." }`');
        exit(HelpText.ToText());
    end;
}
