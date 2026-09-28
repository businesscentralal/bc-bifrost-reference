namespace Origo.Bifrost.Reference;

using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// Reference implementation showing a real lookup with a genuine, realistic failure path.
/// Resolves a table name to its object ID — the exact pattern any AI agent or integration
/// needs before calling Data.Records.Get/Set dynamically. Unlike Reference.Echo.Get, this
/// type demonstrates the structured error-response contract for expected failures.
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see START-HERE.md section 4.</remarks>
codeunit 90001 "Ref Table Get Impl" implements "Msg Interface ori"
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
        exit('Returns the object ID of a Business Central table given its object name. Read-only; fails with a structured error if no table has that name.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Reference.Table.Get');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Returns the object ID of one Business Central table, looked up by its object name.');
        HelpText.AppendLine('');
        HelpText.AppendLine('Use it when you know a table by name (for example `Item`) and need its numeric ID');
        HelpText.AppendLine('before calling an operation that takes a table ID. Not for reading records, listing');
        HelpText.AppendLine('fields, or searching by partial name - the name must match the whole object name.');
        HelpText.AppendLine('');
        HelpText.AppendLine('**Effect:** Read-only (direction Outbound - a read). Nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Workflow');
        HelpText.AppendLine('This type -> an operation that takes a table ID (for example `Data.Records.Get` or');
        HelpText.AppendLine('`Data.Records.Set` called dynamically).');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Identifying the target');
        HelpText.AppendLine('None: subject is not used. The table is named by `tableName` in the body.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Parameters');
        HelpText.AppendLine('| Field | Type | Required | Default | Notes |');
        HelpText.AppendLine('| --- | --- | --- | --- | --- |');
        HelpText.AppendLine('| `tableName` | string | yes | - | The table''s object name as it appears in Business Central, e.g. `Item`, `G/L Account`. The whole name, not a prefix. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "tableName": "Item" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('One object: the name you sent and the table''s object ID (integer).');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "tableName": "Item", "tableId": 27 }');
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
        HelpText.AppendLine('| `Parameter ''tableName'' is required. Send it as text, for example "Item".` | The request has no `tableName` field. | Send `{ "tableName": "<name>" }`. |');
        HelpText.AppendLine('| `Parameter ''tableName'' is empty. Send a value, for example "Item".` | Empty string. | Send the name. |');
        HelpText.AppendLine('| `Table ''Foo'' was not found. Use the full object name with spaces, for example Sales Header, or list tables with Help.Tables.Get.` | No table has that object name. | Check spelling and spaces. |');
        HelpText.AppendLine('| `Parameter ''tableName'' is 40 characters long; the maximum is 30.` | Longer than any table name. | Send the object name, at most 30 characters. |');
        HelpText.AppendLine('| `Parameter ''tableName'' must be a single value (text or number), not an object or an array.` | `tableName` sent as object or array. | Send it as text. |');
        HelpText.AppendLine('| `The request body must be a JSON object, for example { "accountNo": "2910" }.` | `data` is an array or plain text. | Send `{ "tableName": "<name>" }`. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('Example:');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "status": "Error", "error": "Table ''Foo'' was not found.", "hint": "..." }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safe retries / repeat');
        HelpText.AppendLine('Read-only; safe to repeat. Safe to call repeatedly; the same name always gives the same ID.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Permissions and side effects');
        HelpText.AppendLine('Every user sees this type; it reads only the list of objects in the database. No side effects.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Formats and language');
        HelpText.AppendLine('`tableName` is the object name in English as Business Central stores it, whatever the');
        HelpText.AppendLine('caller''s language (the caption `Vara` is not found; send `Item`). `tableId` is a JSON');
        HelpText.AppendLine('integer. Error texts are translatable and follow lcid when a translation is installed.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related message types');
        HelpText.AppendLine('- `Reference.Echo.Get` - connectivity check with no lookup and no failure path.');
        HelpText.AppendLine('- `Reference.Note.Add` - a write with a duplicate-key failure path.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AllObj: Record AllObj;
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        TableName: Text;
        TableNotFoundErr: Label 'Table ''%1'' was not found. Use the full object name with spaces, for example Sales Header, or list tables with Help.Tables.Get.', Comment = '%1 = table name, is-IS=Taflan ''%1'' fannst ekki. Notaðu fullt heiti með bilum, t.d. Sales Header, eða skoðaðu töflur með Help.Tables.Get.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not RefInput.GetRequiredText(Argument, RequestJson, 'tableName', 30, '"Item"', TableName) then
            exit;

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
