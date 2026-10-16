namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference.ApiKey.Set - a message type that RECEIVES A SECRET.
///
/// The rule for every such type: call Argument.RedactRequestData() immediately after reading
/// the value. Foundation keeps every request body in its message log; without this call the
/// key would sit there in plain text indefinitely. The value is held as SecretText from the
/// moment it is read and is stored only through Secret Store ori.
/// </summary>
codeunit 90023 "Ref Api Key Set Impl" implements "Msg Interface ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        RefSetup: Record "Ref Setup";
    begin
        // Only users who may change this app's setup may set its key.
        exit(RefSetup.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Store the API key for the reference app''s exchange rates service. Commits; the key goes to the Bifrost secret store and is removed from the request log. People can also use Bifrost Setup > Apps.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;


    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Clear(Parameters);
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        exit(false);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Help: Codeunit "Ref Exch Rate Help";
    begin
        Overview := Help.GetApiKeyHelp();
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref Exch Rate Help";
    begin
        Argument.SetResponseMarkdown(Help.GetApiKeyHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        KeyProcess: Codeunit "Ref Api Key Set Process";
        ResponseJson: JsonObject;
        ApiKey: SecretText;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        // Order matters. RedactRequestData() modifies the logged message row, which opens a write
        // transaction - and inside an open write transaction Codeunit.Run may not be used with a
        // return value. So: read the key (no write), run the isolated store, THEN redact - on
        // every path, including invalid input, because the body may hold a key either way.
        if not ReadKey(Argument, ApiKey) then begin
            Argument.RedactRequestData();
            exit;
        end;

        KeyProcess.SetApiKey(ApiKey);
        if Argument."Omit Commit" then
            KeyProcess.Run(Argument)
        else
            if not KeyProcess.Run(Argument) then begin
                Argument.RespondWithError(GetLastErrorText());
                Argument.RedactRequestData();
                exit;
            end;
        Argument.RedactRequestData();

        ResponseJson.Add('stored', true);
        Argument.SetResponseJson(ResponseJson);
    end;

    /// <summary>
    /// Reads apiKey into SecretText; the plain-text copy is cleared immediately.
    /// </summary>
    [NonDebuggable]
    local procedure ReadKey(var Argument: Record "Message Argument ori"; var ApiKey: SecretText): Boolean
    var
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
        KeyText: Text;
        ReadOk: Boolean;
    begin
        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit(false);
        ReadOk := RefInput.GetRequiredText(Argument, RequestJson, 'apiKey', 500, '"your-key"', KeyText);
        ApiKey := KeyText;
        Clear(KeyText);
        Clear(RequestJson);
        exit(ReadOk);
    end;
}
