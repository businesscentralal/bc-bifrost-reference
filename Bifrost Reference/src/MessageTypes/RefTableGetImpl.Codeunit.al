namespace Origo.Bifrost.Reference;

using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// Reference implementation showing a real lookup with a genuine, realistic failure path.
/// Resolves a table name to its object ID — the exact pattern any AI agent or integration
/// needs before calling Data.Records.Get/Set dynamically. Unlike Reference.Echo.Set, this
/// type demonstrates the structured error-response contract via RespondWithError.
/// </summary>
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
        exit('Looks up a table''s object ID by name. Errors with a structured response if the table does not exist.');
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
        HelpText.AppendLine(GetDescription());
        HelpText.AppendLine('');
        HelpText.AppendLine('**Request:** `{ "tableName": "Customer" }`');
        HelpText.AppendLine('**Response (found):** `{ "tableName": "Customer", "tableId": 18 }`');
        HelpText.AppendLine('**Response (not found):** `{ "status": "Error", "error": "...", "hint": "..." }` via `RespondWithError`.');
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
