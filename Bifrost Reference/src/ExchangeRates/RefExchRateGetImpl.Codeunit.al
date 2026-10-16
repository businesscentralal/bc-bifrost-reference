namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference.ExchangeRate.Get - a read that calls an external service.
/// Shows: input validation before any network call, the HTTP client isolated in its own
/// codeunit, an optional secret, and failures that tell the caller what to fix.
/// </summary>
codeunit 90021 "Ref Exch Rate Get Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        CurrencyFormatErr: Label 'Parameter ''%1'' is ''%2''. Send a 3-letter ISO currency code, for example EUR or ISK.', Comment = '%1 = parameter name, %2 = value received, is-IS=Færibreytan ''%1'' er ''%2''. Sendu þriggja stafa ISO-gjaldmiðlakóða, til dæmis EUR eða ISK.';
        SameCurrencyErr: Label 'Parameters ''from'' and ''to'' are both %1. Send two different currencies.', Comment = '%1 = currency code, is-IS=Færibreyturnar ''from'' og ''to'' eru báðar %1. Sendu tvo ólíka gjaldmiðla.';
        SourceTxt: Label 'European Central Bank reference rates via the configured rates service', Locked = true;

    procedure IsEnabled(): Boolean
    var
        RefSetup: Record "Ref Setup";
    begin
        // The call reads the app's setup (base URL), so a user who cannot read it must not see the type.
        exit(RefSetup.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        // Live search ranked this 3rd for "euro to krona exchange rate": users name currencies, so the card does too.
        exit('Get today''s exchange rate between two currencies, e.g. euro to krona (EUR to ISK), from ECB data. Read-only; calls the internet. Not for BC''s Currency Exchange Rate table or Central Bank of Iceland indices.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RefInput: Codeunit "Ref Input";
        RatesClient: Codeunit "Ref Rates Client";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        FromCurrency: Code[3];
        ToCurrency: Code[3];
        Rate: Decimal;
        RateDate: Date;
        ErrorText: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not ReadCurrency(Argument, RefInput, RequestJson, 'from', FromCurrency) then
            exit;
        if not ReadCurrency(Argument, RefInput, RequestJson, 'to', ToCurrency) then
            exit;
        if FromCurrency = ToCurrency then begin
            Argument.RespondWithError(StrSubstNo(SameCurrencyErr, FromCurrency));
            exit;
        end;

        if not RatesClient.TryGetLatestRate(FromCurrency, ToCurrency, Rate, RateDate, ErrorText) then begin
            Argument.RespondWithError(ErrorText);
            exit;
        end;

        ResponseJson.Add('from', FromCurrency);
        ResponseJson.Add('to', ToCurrency);
        ResponseJson.Add('rate', Rate);
        if RateDate <> 0D then
            ResponseJson.Add('rateDate', Format(RateDate, 0, 9));
        ResponseJson.Add('source', SourceTxt);
        Argument.SetResponseJson(ResponseJson);
    end;

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'exchange rate, euro to krona, currency rate today, convert currency, how many krona for a euro, ECB rate', Comment = 'is-IS=gengi, evra í krónur, gengi gjaldmiðils í dag, umreikna gjaldmiðil, hvað kostar evran, gengi Seðlabanka Evrópu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Today''s reference rate between two currencies from an external service (European Central Bank data). Calls the internet; writes nothing. For Business Central''s own Currency Exchange Rate table, use Data.Records.Get.', Comment = 'is-IS=Viðmiðunargengi dagsins milli tveggja gjaldmiðla frá ytri þjónustu (gögn Seðlabanka Evrópu). Kallar á netið; skrifar ekkert. Fyrir töfluna Currency Exchange Rate í Business Central, notaðu Data.Records.Get.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the latest reference exchange rate between two currencies from an external service (European Central Bank data, published once per working day). Makes one outbound HTTPS call; writes nothing in Business Central. ' +
            'Not for Business Central''s own Currency Exchange Rate table (read that with Data.Records.Get), and not for historical rates.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The currencies are from and to in data.');
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
        Parameters.Add(ContractMgt.Parameter('from', 'string', true, 'A 3-letter ISO currency code, for example EUR. Case-insensitive.'));
        Parameters.Add(ContractMgt.Parameter('to', 'string', true, 'A 3-letter ISO currency code, different from from, for example ISK. Case-insensitive.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('from', 'string', 'The from currency, in upper case.'));
        Fields.Add(ContractMgt.ResponseField('to', 'string', 'The to currency, in upper case.'));
        Fields.Add(ContractMgt.ResponseField('rate', 'number', '1 from = rate to.'));
        Fields.Add(ContractMgt.ResponseField('rateDate', 'string', 'The day the rate was published, YYYY-MM-DD. Can be a few days before today around weekends and holidays. Left out when the service sends no date.'));
        Fields.Add(ContractMgt.ResponseField('source', 'string', 'Where the rate comes from.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Error texts are verbatim from the Labels in this codeunit, Ref Rates Client and Ref Input.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is required. Send it as text, for example "EUR".', 'from or to is missing.', 'Send both from and to.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is empty. Send a value, for example "EUR".', 'from or to is an empty string.', 'Send a currency code.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is {length} characters long; the maximum is 10.', 'from or to is far too long to be a currency code.', 'Send a 3-letter code.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' must be a single value (text or number), not an object or an array.', 'from or to is an object or an array.', 'Send a 3-letter code as text.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is ''{value}''. Send a 3-letter ISO currency code, for example EUR or ISK.', 'from or to is not three letters, for example EURO.', 'Use ISO currency codes.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameters ''from'' and ''to'' are both {currency}. Send two different currencies.', 'The same currency on both sides.', 'Send two different codes.'));
        Errors.Add(ContractMgt.TextErrorEntry('The exchange rate service at {baseUrl} could not be reached. If outbound HTTP is blocked, enable it for Bifrost Reference in the Bifrost Setup Wizard (Bifrost Setup > Start setup wizard).', 'No network, or outbound HTTP is blocked for this app. The platform''s reason may follow as " Details: {details}".', 'Run the Bifrost Setup Wizard and enable HTTP for Bifrost Reference.'));
        Errors.Add(ContractMgt.TextErrorEntry('The exchange rate service answered HTTP {status} for {from} to {to}. Check that both are ISO currency codes the service supports (for example EUR, USD, ISK).', 'The service does not know one of the currencies, or failed.', 'Use a currency the service supports.'));
        Errors.Add(ContractMgt.TextErrorEntry('The exchange rate service returned an answer without a rate for {to}. Try again later, or check Rates Base URL on the Bifrost Reference Setup page.', 'The service gave an unexpected answer.', 'Try again later, or check Rates Base URL.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing in Business Central. Makes one outbound HTTPS GET to the configured rates service, which gives up after 15 seconds.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can read Ref Setup (it holds the service URL); without it the type is not offered.');
        Preconditions.Add('Outbound HTTP is allowed for Bifrost Reference.');
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
        Related.Add(ContractMgt.RelatedEntry('Reference.ApiKey.Set', 'The configured service needs an API key; the default service does not.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want the rates stored in Business Central (table Currency Exchange Rate).'));
        exit(true);
    end;

    /// <summary>Standalone; Reference.ApiKey.Set first only when the service needs a key.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Euro to krona',
            '{"type":"Reference.ExchangeRate.Get","data":{"from":"EUR","to":"ISK"}}',
            '{"from":"EUR","to":"ISK","rate":136.6,"rateDate":"2026-09-25","source":"European Central Bank reference rates via the configured rates service"}'));
        Examples.Add(ContractMgt.Example('Not a currency code',
            '{"type":"Reference.ExchangeRate.Get","data":{"from":"EUR","to":"EURO"}}',
            '{"status":"Error","error":"Parameter ''to'' is ''EURO''. Send a 3-letter ISO currency code, for example EUR or ISK."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat; the rate changes only when the service publishes a new one. If an API key is stored (see Reference.ApiKey.Set), it is sent in the X-Api-Key header and never appears in the response or in error texts. ' +
            'Currency codes are returned in upper case; rate is a JSON number with a dot as decimal separator. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;

    local procedure ReadCurrency(var Argument: Record "Message Argument ori"; var RefInput: Codeunit "Ref Input"; RequestJson: JsonObject; KeyName: Text; var CurrencyCode: Code[3]): Boolean
    var
        Value: Text;
        Index: Integer;
    begin
        if not RefInput.GetRequiredText(Argument, RequestJson, KeyName, 10, '"EUR"', Value) then
            exit(false);
        Value := UpperCase(DelChr(Value, '<>', ' '));
        if StrLen(Value) <> 3 then begin
            Argument.RespondWithError(StrSubstNo(CurrencyFormatErr, KeyName, Value));
            exit(false);
        end;
        for Index := 1 to 3 do
            if not (Value[Index] in ['A' .. 'Z']) then begin
                Argument.RespondWithError(StrSubstNo(CurrencyFormatErr, KeyName, Value));
                exit(false);
            end;
        CurrencyCode := CopyStr(Value, 1, 3);
        exit(true);
    end;
}
