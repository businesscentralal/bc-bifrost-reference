namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference implementation of a message type (Reference.Echo.Get). Echoes the request payload
/// back with a server timestamp added, demonstrating request parsing and response writing
/// without depending on any external system. The type was named Reference.Echo.Set until the
/// rename; the codeunit keeps its object name so the object ID and file stay stable.
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see CONTRACT.md.</remarks>
codeunit 90000 "Ref Echo Set Impl" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns the request object unchanged with a serverTime field added. Read-only connectivity check; reads no data.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Reference.Echo.Get');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Returns the JSON object you sent, with one field added: `serverTime`, the date and time');
        HelpText.AppendLine('on the Business Central server at the moment the call ran.');
        HelpText.AppendLine('');
        HelpText.AppendLine('Use it to confirm that a call reaches Business Central and that the request and');
        HelpText.AppendLine('response travel intact - a connectivity and envelope check, or a way to read the');
        HelpText.AppendLine('server clock. Not for reading or writing business data: it touches no table.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Direction');
        HelpText.AppendLine('Outbound - a read. Nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request');
        HelpText.AppendLine('Any JSON object. There are no named fields; everything you send is returned as sent.');
        HelpText.AppendLine('');
        HelpText.AppendLine('| Field | Type | Required | Default | Notes |');
        HelpText.AppendLine('| --- | --- | --- | --- | --- |');
        HelpText.AppendLine('| *(any)* | any | no | - | Returned unchanged. A field named `serverTime` in the request is replaced. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "message": "hello" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('The request object plus `serverTime` (string, ISO 8601 date-time in UTC).');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "message": "hello", "serverTime": "2026-09-18T10:15:30.123Z" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('An empty request `{}` returns `{ "serverTime": "2026-09-18T10:15:30.123Z" }` - not an error.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('| `error` | Meaning | Fix |');
        HelpText.AppendLine('| --- | --- | --- |');
        HelpText.AppendLine('| `The request body must be a JSON object, for example { "customerNo": "10000" }.` | `data` is an array or plain text. | Send a JSON object, or no body. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safety / repeat');
        HelpText.AppendLine('Safe to call any number of times. Each call returns a new `serverTime`; nothing else');
        HelpText.AppendLine('differs between calls.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related types');
        HelpText.AppendLine('- `Reference.Table.Get` - a read that can fail, returning a structured error.');
        HelpText.AppendLine('- `Reference.Note.Add` - a write with a duplicate-key failure path.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not RequestJson.Replace('serverTime', CurrentDateTime()) then
            RequestJson.Add('serverTime', CurrentDateTime());
        Argument.SetResponseJson(RequestJson);
    end;
}
