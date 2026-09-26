namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference.ExchangeRate.Get - a read that calls an external service.
/// Shows: input validation before any network call, the HTTP client isolated in its own
/// codeunit, an optional secret, and failures that tell the caller what to fix.
/// </summary>
codeunit 90021 "Ref Exch Rate Get Impl" implements "Msg Interface ori"
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

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref Exch Rate Help";
    begin
        Argument.SetResponseMarkdown(Help.GetExchangeRateHelp());
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
