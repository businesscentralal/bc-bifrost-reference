namespace Origo.Bifrost.Reference;

using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// Reference implementation showing a real lookup with a genuine, realistic failure path.
/// Resolves a table name to its object ID — the exact pattern any AI agent or integration
/// needs before calling Data.Records.Get/Set dynamically. Unlike Reference.Echo.Get, this
/// type demonstrates the structured error-response contract for expected failures.
/// </summary>
/// <remarks>Public: the contract chapters are returned to every caller. See BUILDING.md section 4.</remarks>
codeunit 90001 "Ref Table Get Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'table id, table number, object id of a table, find a table by name, which number is this table', Comment = 'is-IS=auðkenni töflu, númer töflu, hlutanúmer töflu, finna töflu eftir heiti, hvaða númer er þessi tafla';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Turn a table''s exact object name, such as Item or G/L Account, into its object ID. Not for reading records or fields: use Data.Records.Get for records.', Comment = 'is-IS=Breyta nákvæmu hlutaheiti töflu, t.d. Item eða G/L Account, í hlutanúmer hennar. Ekki til að lesa færslur eða reiti: notaðu Data.Records.Get fyrir færslur.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the object ID of one Business Central table, looked up by its object name. ' +
            'Use it when you know a table by name (for example `Item`) and need its numeric ID before calling an operation that takes a table ID. ' +
            'Not for reading records, listing fields, or searching by partial name: the name must match the whole object name.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The table is named by tableName in data.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.tableName', 'table object name', 'The whole object name in English as Business Central stores it, for example Item or G/L Account. Captions in another language are not found.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('tableName', 'string', true, 'The table''s object name, at most 30 characters, for example Item or G/L Account. The whole name, not a prefix.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('tableName', 'string', 'The name you sent.'));
        Fields.Add(ContractMgt.ResponseField('tableId', 'integer', 'The table''s object ID. There is no empty result: a name that matches no table is an error.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''tableName'' is required. Send it as text, for example "Item".', 'The request has no tableName.', 'Send tableName.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''tableName'' is empty. Send a value, for example "Item".', 'tableName is an empty string.', 'Send the name.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''tableName'' is {length} characters long; the maximum is 30.', 'tableName is longer than any table name.', 'Send the object name, at most 30 characters.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''tableName'' must be a single value (text or number), not an object or an array.', 'tableName is an object or an array.', 'Send it as text.'));
        Errors.Add(ContractMgt.TextErrorEntry('Table ''{tableName}'' was not found. Use the full object name with spaces, for example Sales Header, or list tables with Help.Tables.Get.', 'No table has that object name.', 'Check spelling and spaces, and use the English object name.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object with tableName.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads only the list of objects in the database.');
        Effect.Add('idempotent', true);
        Preconditions.Add('None beyond calling Bifrost: every user sees this type.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Help.Tables.Get', 'You do not know the exact name and want to list the tables.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want the records of the table, not its ID.'));
        Related.Add(ContractMgt.RelatedEntry('Reference.Echo.Get', 'You only want to check the connection: no lookup and no failure path.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Reference.Table.Get', 'Turn the table name into its object ID.'));
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', 'Call an operation that takes a table ID, with the tableId from the first step.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Use it before an operation that takes a table ID when you know the table only by name.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Look up the Item table',
            '{"type":"Reference.Table.Get","data":{"tableName":"Item"}}',
            '{"tableName":"Item","tableId":27}'));
        Examples.Add(ContractMgt.Example('No table has that name',
            '{"type":"Reference.Table.Get","data":{"tableName":"Vara"}}',
            '{"status":"Error","error":"Table ''Vara'' was not found. Use the full object name with spaces, for example Sales Header, or list tables with Help.Tables.Get."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat; the same name always gives the same ID. tableName is the object name in English as Business Central stores it, whatever the caller''s language: the caption Vara is not found, send Item. ' +
            'tableId is a JSON integer. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
