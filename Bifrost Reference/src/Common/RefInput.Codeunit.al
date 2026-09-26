namespace Origo.Bifrost.Reference;

using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>
/// The shared input layer for every message type in this app. Copy it into your own app.
///
/// Why it exists: when an agent's first call fails, the cause is rarely specific to one
/// message type. It is input handling that every type repeats: "not found" reported as
/// "missing", dates such as 26.09.2026 giving raw runtime errors, wrong JSON types reaching
/// AsValue(), and English-only error text. Reading every parameter through one place gets
/// those right once, for every type in the app.
///
/// Rules this codeunit enforces, for every parameter:
///  - missing, empty, wrong type, wrong format and out of range are five DIFFERENT errors;
///  - every error names the parameter, echoes the value received and says what to send;
///  - dates are ISO 8601 (YYYY-MM-DD) and numbers use a dot, nothing else is guessed;
///  - every text is a translatable Label (is-IS comment), never a hard-coded literal.
///
/// Every Get* procedure returns false after it has already answered the caller with
/// Argument.RespondWithError, so the calling code just does: if not ... then exit;
/// </summary>
codeunit 90010 "Ref Input"
{
    Access = Internal;

    var
        NotObjectErr: Label 'The request body must be a JSON object, for example { "customerNo": "10000" }.', Comment = 'is-IS=Beiðnin verður að vera JSON-hlutur, til dæmis { "customerNo": "10000" }.';
        MissingErr: Label 'Parameter ''%1'' is required. Send it as %2.', Comment = '%1 = parameter name, %2 = expected type and example, is-IS=Færibreytan ''%1'' er nauðsynleg. Sendu hana sem %2.';
        EmptyErr: Label 'Parameter ''%1'' is empty. Send a value, for example %2.', Comment = '%1 = parameter name, %2 = example, is-IS=Færibreytan ''%1'' er tóm. Sendu gildi, til dæmis %2.';
        NotAValueErr: Label 'Parameter ''%1'' must be a single value (text or number), not an object or an array.', Comment = '%1 = parameter name, is-IS=Færibreytan ''%1'' verður að vera stakt gildi (texti eða tala), ekki hlutur eða fylki.';
        TooLongErr: Label 'Parameter ''%1'' is %2 characters long; the maximum is %3.', Comment = '%1 = parameter name, %2 = actual length, %3 = maximum length, is-IS=Færibreytan ''%1'' er %2 stafir; hámarkið er %3.';
        DateFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.', Comment = '%1 = parameter name, %2 = value received, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki dagsetning á sniðinu ÁÁÁÁ-MM-DD. Sendu til dæmis 2026-09-26.';
        NumberFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a number. Send a number with a dot as decimal separator, for example 2.5.', Comment = '%1 = parameter name, %2 = value received, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki tala. Sendu tölu með punkti sem aukastafaskiltákn, til dæmis 2.5.';
        RangeErr: Label 'Parameter ''%1'' is %2, but it must be between %3 and %4.', Comment = '%1 = parameter name, %2 = value received, %3 = minimum, %4 = maximum, is-IS=Færibreytan ''%1'' er %2 en verður að vera á bilinu %3 til %4.';
        CustomerMissingErr: Label 'No customer was given. Send the customer number in subject or as "customerNo", or its SystemId in subject.', Comment = 'is-IS=Enginn viðskiptamaður var tilgreindur. Sendu númer viðskiptamanns í subject eða sem "customerNo", eða SystemId hans í subject.';
        CustomerNotFoundErr: Label 'Customer ''%1'' was not found. Check the number, or search for the customer with Data.Records.Get on table Customer.', Comment = '%1 = customer no. or SystemId received, is-IS=Viðskiptamaðurinn ''%1'' fannst ekki. Athugaðu númerið eða leitaðu að honum með Data.Records.Get á töflunni Customer.';
        TextExampleTok: Label 'text, for example %1', Comment = '%1 = example value', Locked = true;
        DateExampleTok: Label 'a date in the format YYYY-MM-DD, for example "2026-09-26"', Locked = true;
        NumberExampleTok: Label 'a number, for example 2.5', Locked = true;
        IntegerFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a whole number. Send for example 12.', Comment = '%1 = parameter name, %2 = value received, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki heiltala. Sendu til dæmis 12.';
        IntegerExampleTok: Label 'a whole number, for example 12', Locked = true;

    /// <summary>
    /// Reads the request body as a JSON object. An empty body gives an empty object.
    /// A body that is not an object (an array, plain text) is answered with a clear error
    /// instead of the raw platform error GetRequestJson() would raise.
    /// </summary>
    procedure ReadRequest(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject): Boolean
    begin
        if TryGetRequestJson(Argument, RequestJson) then
            exit(true);
        Argument.RespondWithError(NotObjectErr);
        exit(false);
    end;

    /// <summary>
    /// Reads a required text parameter. Distinguishes missing, not a value, empty and too long.
    /// ExampleValue is shown in the error so the caller sees what a good value looks like,
    /// e.g. '"STÓLL"' for an item category.
    /// </summary>
    procedure GetRequiredText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer; ExampleValue: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, StrSubstNo(TextExampleTok, ExampleValue)));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, MaxLength, Value) then
            exit(false);
        if DelChr(Value, '<>', ' ') = '' then begin
            Argument.RespondWithError(StrSubstNo(EmptyErr, KeyName, ExampleValue));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads an optional text parameter. Absent or JSON null gives Found = false and Value = ''.
    /// Present but wrong type or too long is still an error.
    /// </summary>
    procedure GetOptionalText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer; var Value: Text; var Found: Boolean): Boolean
    var
        Token: JsonToken;
    begin
        Value := '';
        Found := false;
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit(true);
        if not ReadTextToken(Argument, Token, KeyName, MaxLength, Value) then
            exit(false);
        Found := Value <> '';
        exit(true);
    end;

    /// <summary>
    /// Reads a required date in ISO format (YYYY-MM-DD). Anything else, including
    /// 26.09.2026 or 09/26/2026, is refused with the expected format. Never guesses.
    /// </summary>
    procedure GetRequiredDate(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Date): Boolean
    var
        Token: JsonToken;
        DateText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, DateExampleTok));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, 30, DateText) then
            exit(false);
        if not TryParseIsoDate(DateText, Value) then begin
            Argument.RespondWithError(StrSubstNo(DateFormatErr, KeyName, DateText));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads a required decimal and checks it against an inclusive range. Accepts a JSON
    /// number (2.5) or a numeric string ("2.5"); always with a dot as decimal separator.
    /// </summary>
    procedure GetRequiredDecimal(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MinValue: Decimal; MaxValue: Decimal; var Value: Decimal): Boolean
    var
        Token: JsonToken;
        NumberText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, NumberExampleTok));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, 50, NumberText) then
            exit(false);
        if not Evaluate(Value, NumberText, 9) then begin
            Argument.RespondWithError(StrSubstNo(NumberFormatErr, KeyName, NumberText));
            exit(false);
        end;
        if (Value < MinValue) or (Value > MaxValue) then begin
            Argument.RespondWithError(StrSubstNo(RangeErr, KeyName, Format(Value, 0, 9), Format(MinValue, 0, 9), Format(MaxValue, 0, 9)));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads a required whole number and checks it against an inclusive range.
    /// </summary>
    procedure GetRequiredInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MinValue: Integer; MaxValue: Integer; var Value: Integer): Boolean
    var
        Token: JsonToken;
        NumberText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, IntegerExampleTok));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, 20, NumberText) then
            exit(false);
        if not Evaluate(Value, NumberText, 9) then begin
            Argument.RespondWithError(StrSubstNo(IntegerFormatErr, KeyName, NumberText));
            exit(false);
        end;
        if (Value < MinValue) or (Value > MaxValue) then begin
            Argument.RespondWithError(StrSubstNo(RangeErr, KeyName, Format(Value, 0, 9), Format(MinValue, 0, 9), Format(MaxValue, 0, 9)));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Resolves the customer the caller means. Order: subject as SystemId (GUID), subject as
    /// customer number, then "customerNo" in the body. Three outcomes, three different answers:
    /// nothing given -> "no customer was given"; given but unknown -> "customer 'X' was not
    /// found" (echoing X); found -> true. Mixing up the first two is the most frequent cause
    /// of failed first calls: the caller fixes the wrong thing.
    /// </summary>
    procedure ResolveCustomer(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Customer: Record Customer): Boolean
    var
        CustomerNoText: Text;
        Found: Boolean;
    begin
        if Argument.SubjectIsGuid() then begin
            if Customer.GetBySystemId(Argument.Subject) then
                exit(true);
            Argument.RespondWithError(StrSubstNo(CustomerNotFoundErr, Argument.Subject));
            exit(false);
        end;

        CustomerNoText := DelChr(Argument.Subject, '<>', ' ');
        if CustomerNoText = '' then begin
            if not GetOptionalText(Argument, RequestJson, 'customerNo', MaxStrLen(Customer."No."), CustomerNoText, Found) then
                exit(false);
            if not Found then begin
                Argument.RespondWithError(CustomerMissingErr);
                exit(false);
            end;
        end;

        if StrLen(CustomerNoText) > MaxStrLen(Customer."No.") then begin
            Argument.RespondWithError(StrSubstNo(CustomerNotFoundErr, CustomerNoText));
            exit(false);
        end;
        if Customer.Get(UpperCase(CustomerNoText)) then
            exit(true);
        Argument.RespondWithError(StrSubstNo(CustomerNotFoundErr, CustomerNoText));
        exit(false);
    end;

    /// <summary>
    /// Runs a write codeunit (TableNo = "Message Argument ori") in isolation, so any Error()
    /// inside it rolls back that codeunit's writes and is answered as status = Error.
    ///
    /// Why two paths: Foundation sets "Omit Commit" when the call is part of a caller's own
    /// transaction (for example Dispatcher ori called from AL with OmitCommit = true). Inside an
    /// open write transaction, Codeunit.Run may not be used with a return value, so the error
    /// is left to propagate to the caller, who owns the transaction. This is exactly the pattern
    /// Foundation's own implementations use.
    /// </summary>
    procedure RunIsolated(CodeunitId: Integer; var Argument: Record "Message Argument ori")
    begin
        if Argument."Omit Commit" then begin
            Codeunit.Run(CodeunitId, Argument);
            exit;
        end;
        if not Codeunit.Run(CodeunitId, Argument) then
            Argument.RespondWithError(GetLastErrorText());
    end;

    local procedure ReadTextToken(var Argument: Record "Message Argument ori"; Token: JsonToken; KeyName: Text; MaxLength: Integer; var Value: Text): Boolean
    begin
        if not Token.IsValue() then begin
            Argument.RespondWithError(StrSubstNo(NotAValueErr, KeyName));
            exit(false);
        end;
        if Token.AsValue().IsNull() then
            Value := ''
        else
            Value := Token.AsValue().AsText();
        if StrLen(Value) > MaxLength then begin
            Argument.RespondWithError(StrSubstNo(TooLongErr, KeyName, StrLen(Value), MaxLength));
            exit(false);
        end;
        exit(true);
    end;

    local procedure TryParseIsoDate(DateText: Text; var Value: Date): Boolean
    var
        Year: Integer;
        Month: Integer;
        Day: Integer;
    begin
        // Strictly YYYY-MM-DD: exactly 10 characters, dashes at positions 5 and 8.
        if StrLen(DateText) <> 10 then
            exit(false);
        if (CopyStr(DateText, 5, 1) <> '-') or (CopyStr(DateText, 8, 1) <> '-') then
            exit(false);
        if not Evaluate(Year, CopyStr(DateText, 1, 4)) then
            exit(false);
        if not Evaluate(Month, CopyStr(DateText, 6, 2)) then
            exit(false);
        if not Evaluate(Day, CopyStr(DateText, 9, 2)) then
            exit(false);
        exit(TryDMY2Date(Day, Month, Year, Value));
    end;

    [TryFunction]
    local procedure TryDMY2Date(Day: Integer; Month: Integer; Year: Integer; var Value: Date)
    begin
        Value := DMY2Date(Day, Month, Year);
    end;

    [TryFunction]
    local procedure TryGetRequestJson(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject)
    begin
        RequestJson := Argument.GetRequestJson();
    end;
}
