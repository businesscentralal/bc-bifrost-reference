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
codeunit 90023 "Ref Api Key Set Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'set the API key, store the API key, change the API key, exchange rate service key, save the rates key', Comment = 'is-IS=setja API-lykil, vista API-lykil, breyta API-lykli, lykill gengisþjónustu, vista lykil gengisþjónustu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Store the API key the exchange rate service uses, in the Bifrost secret store. The key is never returned. For integrations, not chats: a person enters the key in Bifrost Setup > Apps. To get a rate, use Reference.ExchangeRate.Get.', Comment = 'is-IS=Vista API-lykilinn sem gengisþjónustan notar í leyndarmálageymslu Bifrastar. Lyklinum er aldrei skilað. Fyrir samþættingar, ekki spjall: fólk slær lykilinn inn í Bifrost Setup > Apps. Til að fá gengi, notaðu Reference.ExchangeRate.Get.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Stores the API key the exchange rate service uses, in the Bifrost secret store. The key replaces any stored key for this company. ' +
            'People can do the same from Bifrost Setup > Apps > Bifrost Reference > Set API key. The default service needs no key.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'There is one key per company.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('apiKey', 'string', true, 'The API key, at most 500 characters, not empty. Stored exactly as sent.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('stored', 'boolean', 'Always true: the key was stored. The key itself is never returned.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Error texts are verbatim from the Labels in Ref Input. None of them contains the key.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''apiKey'' is required. Send it as text, for example "your-key".', 'apiKey is missing.', 'Send apiKey.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''apiKey'' is empty. Send a value, for example "your-key".', 'apiKey is an empty string.', 'Send the key.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''apiKey'' is {length} characters long; the maximum is 500.', 'apiKey is too long.', 'Check that you send the key only.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''apiKey'' must be a single value (text or number), not an object or an array.', 'apiKey is an object or an array.', 'Send it as text.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Stores the key in the Bifrost secret store for the current company, replacing any stored key, and replaces the request body with a placeholder in the Bifrost message log. Nothing is stored when an error is returned.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can write Ref Setup; without it the type is not offered.');
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
        Related.Add(ContractMgt.RelatedEntry('Reference.ExchangeRate.Get', 'You want a rate; it sends the stored key with every call.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Reference.ApiKey.Set', 'Store the key, once.'));
        Steps.Add(ContractMgt.WorkflowStep('Reference.ExchangeRate.Get', 'Get rates; the stored key is sent with every call.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Needed only when the configured rates service requires a key.');
        exit(true);
    end;

    /// <summary>The examples show a placeholder, never anything that looks like a real key.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Store the key',
            '{"type":"Reference.ApiKey.Set","data":{"apiKey":"<your-api-key>"}}',
            '{"stored":true}'));
        Examples.Add(ContractMgt.Example('The key is missing',
            '{"type":"Reference.ApiKey.Set","data":{}}',
            '{"status":"Error","error":"Parameter ''apiKey'' is required. Send it as text, for example \"your-key\"."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'For an integration or a setup script, not for a chat. An AI assistant must not ask a person to type or paste a key into the conversation: the conversation goes to the assistant''s provider. Send the person to Bifrost Setup > Apps instead, where they enter the key themselves. ' +
            'The key is stored in the Bifrost secret store (Foundation''s Secret Store ori), never in a table of this app, and is never returned by any message type: not in this response, not in errors, not in the setup page. ' +
            'The request body is redacted in the Bifrost message log on every path, errors included, so the key is not kept there in plain text. ' +
            'Safe to repeat: the same key is stored again and the answer is "stored": true; a different key replaces the first. The key is stored for the current company only.';
        exit(true);
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
