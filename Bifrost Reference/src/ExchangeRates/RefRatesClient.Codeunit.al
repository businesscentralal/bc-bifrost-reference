namespace Origo.Bifrost.Reference;

/// <summary>
/// Outbound HTTP to the exchange rate service. Patterns shown:
///  - the call is wrapped in a TryFunction, so both network failures and a sandbox that blocks
///    outbound HTTP come back as a clear, actionable error instead of a raw platform error;
///  - the optional API key is read as SecretText and added to the request header without ever
///    becoming plain Text;
///  - the service's answer is parsed defensively: status code, JSON shape and value types are
///    each checked, and each failure has its own message.
/// </summary>
codeunit 90022 "Ref Rates Client"
{
    Access = Internal;

    var
        CannotReachErr: Label 'The exchange rate service at %1 could not be reached. If outbound HTTP is blocked, enable it for Bifrost Reference in the Bifrost Setup Wizard (Bifrost Setup > Start setup wizard).', Comment = '%1 = base URL, is-IS=Ekki náðist samband við gengisþjónustuna á %1. Ef lokað er á útsendar HTTP-beiðnir skaltu leyfa þær fyrir Bifrost Reference í uppsetningarleiðsögn Bifrastar (Uppsetning Bifröst > Hefja uppsetningarleiðsögn).';
        DetailsTxt: Label ' Details: %1', Comment = '%1 = platform error, is-IS= Nánar: %1';
        HttpStatusErr: Label 'The exchange rate service answered HTTP %1 for %2 to %3. Check that both are ISO currency codes the service supports (for example EUR, USD, ISK).', Comment = '%1 = HTTP status, %2 = from currency, %3 = to currency, is-IS=Gengisþjónustan svaraði HTTP %1 fyrir %2 í %3. Athugaðu að báðir séu ISO-gjaldmiðlakóðar sem þjónustan styður (t.d. EUR, USD, ISK).';
        UnexpectedAnswerErr: Label 'The exchange rate service returned an answer without a rate for %1. Try again later, or check Rates Base URL on the Bifrost Reference Setup page.', Comment = '%1 = to currency, is-IS=Gengisþjónustan skilaði svari án gengis fyrir %1. Reyndu aftur síðar eða athugaðu grunnslóðina á uppsetningarsíðu Bifrost Reference.';
        ApiKeyHeaderTok: Label 'X-Api-Key', Locked = true;
        LatestUrlTok: Label '%1/latest?base=%2&symbols=%3', Comment = '%1 = base URL, %2 = from currency, %3 = to currency', Locked = true;

    /// <summary>
    /// Gets the latest rate: 1 FromCurrency = Rate ToCurrency. Returns false with ErrorText set on any failure.
    /// </summary>
    procedure TryGetLatestRate(FromCurrency: Code[3]; ToCurrency: Code[3]; var Rate: Decimal; var RateDate: Date; var ErrorText: Text): Boolean
    var
        RefSetup: Record "Ref Setup";
        Response: HttpResponseMessage;
        Body: Text;
        Answer: JsonObject;
        Token: JsonToken;
        Url: Text;
    begin
        RefSetup.GetOrDefault();
        Url := StrSubstNo(LatestUrlTok, RefSetup."Rates Base URL".TrimEnd('/'), FromCurrency, ToCurrency);

        if not TrySend(Url, Response) then begin
            // Only add the platform's reason when there is one - an empty "Details:" reads like a bug.
            ErrorText := StrSubstNo(CannotReachErr, RefSetup."Rates Base URL");
            if GetLastErrorText() <> '' then
                ErrorText += StrSubstNo(DetailsTxt, GetLastErrorText());
            exit(false);
        end;
        if not Response.IsSuccessStatusCode() then begin
            ErrorText := StrSubstNo(HttpStatusErr, Response.HttpStatusCode(), FromCurrency, ToCurrency);
            exit(false);
        end;

        Response.Content().ReadAs(Body);
        if not Answer.ReadFrom(Body) then begin
            ErrorText := StrSubstNo(UnexpectedAnswerErr, ToCurrency);
            exit(false);
        end;
        if not Answer.SelectToken('rates.' + ToCurrency, Token) then begin
            ErrorText := StrSubstNo(UnexpectedAnswerErr, ToCurrency);
            exit(false);
        end;
        if not Token.IsValue() then begin
            ErrorText := StrSubstNo(UnexpectedAnswerErr, ToCurrency);
            exit(false);
        end;
        // A JSON number is read as a decimal directly; the text path is a fallback for services
        // that send the rate as a string. Very small rates may arrive in exponent form (6.5E-05).
        if not TryReadDecimal(Token, Rate) then
            if not Evaluate(Rate, Token.AsValue().AsText(), 9) then begin
                ErrorText := StrSubstNo(UnexpectedAnswerErr, ToCurrency);
                exit(false);
            end;

        RateDate := 0D;
        if Answer.Get('date', Token) then
            if Token.IsValue() then
                if Evaluate(RateDate, Token.AsValue().AsText(), 9) then;
        exit(true);
    end;

    [TryFunction]
    local procedure TryReadDecimal(Token: JsonToken; var Value: Decimal)
    begin
        Value := Token.AsValue().AsDecimal();
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TrySend(Url: Text; var Response: HttpResponseMessage)
    var
        RefSecrets: Codeunit "Ref Secrets";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Headers: HttpHeaders;
        ApiKey: SecretText;
    begin
        Request.Method := 'GET';
        Request.SetRequestUri(Url);
        if RefSecrets.TryGetApiKey(ApiKey) then begin
            Request.GetHeaders(Headers);
            Headers.Add(ApiKeyHeaderTok, ApiKey);
        end;
        Client.Timeout := 15000;
        // Send returns false on network failure; raise so the TryFunction reports it as a failure
        // with the platform's own reason (blocked by policy, DNS, timeout ...).
        if not Client.Send(Request, Response) then
            Error(GetLastErrorText());
    end;
}
