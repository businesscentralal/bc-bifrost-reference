namespace Origo.Bifrost.Reference;

using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// Reference implementation showing a real lookup with a genuine, realistic failure path.
/// Resolves a table name to its object ID — the exact pattern any AI agent or integration
/// needs before calling Data.Records.Get/Set dynamically. Unlike Reference.Echo.Get, this
/// type demonstrates the structured error-response contract for expected failures.
/// </summary>
/// <remarks>Public document: this text is returned to every caller and published on the documentation site. Contract only — see WRITING-HELP.md.</remarks>
codeunit 90001 "Ref Table Get Impl" implements "Msg Interface ori"
{
    Access = Internal;

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    internal procedure GetDescription(): Text[250]
    begin
        exit('Returns the object ID of a Business Central table given its object name. Read-only; fails with a structured error if no table has that name.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Reference.Table.Get');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Returns the object ID of one Business Central table, looked up by its object name.');
        HelpText.AppendLine('');
        HelpText.AppendLine('Use it when you know a table by name (for example `Customer`) and need its numeric ID');
        HelpText.AppendLine('before calling an operation that takes a table ID. Not for reading records, listing');
        HelpText.AppendLine('fields, or searching by partial name - the name must match the whole object name.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Direction');
        HelpText.AppendLine('Outbound - a read. Nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request');
        HelpText.AppendLine('| Field | Type | Required | Default | Notes |');
        HelpText.AppendLine('| --- | --- | --- | --- | --- |');
        HelpText.AppendLine('| `tableName` | string | yes | - | The table''s object name as it appears in Business Central, e.g. `Customer`, `Sales Header`. The whole name, not a prefix. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "tableName": "Customer" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('One object: the name you sent and the table''s object ID (integer).');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "tableName": "Customer", "tableId": 18 }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('There is no empty result: a name that matches no table is an error (below), not an');
        HelpText.AppendLine('empty response.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('Every error has the shape `{"status":"Error","error":"...","hint":"..."}`; `hint`');
        HelpText.AppendLine('points back to this document.');
        HelpText.AppendLine('');
        HelpText.AppendLine('| `error` | Meaning | `hint` |');
        HelpText.AppendLine('| --- | --- | --- |');
        HelpText.AppendLine('| `Missing required field ''tableName''.` | The request has no `tableName` field. | Send `{ "tableName": "<name>" }`. |');
        HelpText.AppendLine('| `Table ''Foo'' was not found.` | No table has the object name given (`Foo` is the name you sent). | Check spelling and spaces; use the full object name, e.g. `Sales Header`, not `SalesHeader`. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('Example:');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "status": "Error", "error": "Table ''Foo'' was not found.", "hint": "..." }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safety / repeat');
        HelpText.AppendLine('Read-only. Safe to call repeatedly; the same name always gives the same ID.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related types');
        HelpText.AppendLine('- `Reference.Echo.Get` - connectivity check with no lookup and no failure path.');
        HelpText.AppendLine('- `Reference.Note.Add` - a write with a duplicate-key failure path.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AllObj: Record AllObj;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        NameToken: JsonToken;
        TableName: Text;
        TableNotFoundErr: Label 'Table ''%1'' was not found.', Comment = '%1 = table name';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('tableName', NameToken) then begin
            Argument.RespondWithError('Missing required field ''tableName''.');
            exit;
        end;
        TableName := NameToken.AsValue().AsText();

        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
        AllObj.SetRange("Object Name", TableName);
        if not AllObj.FindFirst() then begin
            Argument.RespondWithError(StrSubstNo(TableNotFoundErr, TableName));
            exit;
        end;

        ResponseJson.Add('tableName', TableName);
        ResponseJson.Add('tableId', AllObj."Object ID");
        Argument.SetResponseJson(ResponseJson);
    end;
}
