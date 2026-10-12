namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference implementation of a message type (Reference.Echo.Get). Echoes the request payload
/// back with a server timestamp added, demonstrating request parsing and response writing
/// without depending on any external system. The type was named Reference.Echo.Set until the
/// rename; the codeunit keeps its object name so the object ID and file stay stable.
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see START-HERE.md section 4.</remarks>
codeunit 90000 "Ref Echo Set Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'test the connection, ping, echo, is Business Central reachable, check the connection, server time', Comment = 'is-IS=prófa tenginguna, ping, bergmál, næst samband við Business Central, athuga tenginguna, tími á þjóni';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Check that a call reaches Business Central: returns what you sent plus the server time, and touches no data. To read records, use Data.Records.Get; to test a write, use Reference.Note.Add.', Comment = 'is-IS=Athuga hvort kall nær til Business Central: skilar því sem þú sendir ásamt tíma þjónsins og snertir engin gögn. Til að lesa færslur, notaðu Data.Records.Get; til að prófa skrif, notaðu Reference.Note.Add.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the JSON object you sent, with one field added: `serverTime`, the date and time on the Business Central server when the call ran. ' +
            'Use it to confirm that a call reaches Business Central and that request and response travel intact, or to read the server clock. Not for reading or writing business data: it touches no table.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No named parameters: any JSON object is returned as sent.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('serverTime', 'string', 'The server''s date and time when the call ran, ISO 8601 in UTC, for example 2026-09-18T10:15:30.123Z. Every other field is your request, returned unchanged in its own JSON type; a serverTime you sent is replaced.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, for example { "accountNo": "2910" }.', 'data is an array or plain text.', 'Send a JSON object, or no body.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads and writes no table.');
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
        Related.Add(ContractMgt.RelatedEntry('Reference.Table.Get', 'You want a read that can fail with a structured error.'));
        Related.Add(ContractMgt.RelatedEntry('Reference.Note.Add', 'You want to test a write, with a duplicate-key failure path.'));
        exit(true);
    end;

    /// <summary>Standalone: call it first when a connection is new or suspect.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Echo a message',
            '{"type":"Reference.Echo.Get","data":{"message":"hello"}}',
            '{"message":"hello","serverTime":"2026-09-18T10:15:30.123Z"}'));
        Examples.Add(ContractMgt.Example('Empty request',
            '{"type":"Reference.Echo.Get","data":{}}',
            '{"serverTime":"2026-09-18T10:15:30.123Z"}'));
        Examples.Add(ContractMgt.Example('The body is not an object',
            '{"type":"Reference.Echo.Get","data":["hello"]}',
            '{"status":"Error","error":"The request body must be a JSON object, for example { \"accountNo\": \"2910\" }."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to call any number of times; each call returns a new serverTime and nothing else differs. An empty request returns only serverTime; that is not an error. ' +
            'Your values come back exactly as sent, in their own JSON types. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
