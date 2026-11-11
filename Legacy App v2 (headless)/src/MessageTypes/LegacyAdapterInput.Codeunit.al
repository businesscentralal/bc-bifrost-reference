namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// A trimmed copy of "Ref Input" from the Bifrost Reference app: the shared input layer.
/// Legacy App carries its own copy of the input layer rather than depending on the reference app.
/// See Bifrost Reference/src/Common/RefInput.Codeunit.al for the full version and the reasons.
/// </summary>
codeunit 90102 "Legacy Adapter Input"
{
    Access = Internal;

    var
        NotObjectErr: Label 'The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', Comment = 'is-IS=Beiðnin verður að vera JSON-hlutur, með færibreytunum eftir heiti, til dæmis { "name": "value" }.';
        MissingErr: Label 'Parameter ''%1'' is required. Send it as %2.', Comment = '%1 = parameter name, %2 = expected type and example, is-IS=Færibreytan ''%1'' er nauðsynleg. Sendu hana sem %2.';
        EmptyErr: Label 'Parameter ''%1'' is empty. Send a value, for example %2.', Comment = '%1 = parameter name, %2 = example, is-IS=Færibreytan ''%1'' er tóm. Sendu gildi, til dæmis %2.';
        NotAValueErr: Label 'Parameter ''%1'' must be a single value (text or number), not an object or an array.', Comment = '%1 = parameter name, is-IS=Færibreytan ''%1'' verður að vera stakt gildi (texti eða tala), ekki hlutur eða fylki.';
        TooLongErr: Label 'Parameter ''%1'' is %2 characters long; the maximum is %3.', Comment = '%1 = parameter name, %2 = actual length, %3 = maximum length, is-IS=Færibreytan ''%1'' er %2 stafir; hámarkið er %3.';
        NumberFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a number. Send a number with a dot as decimal separator, for example 2.5.', Comment = '%1 = parameter name, %2 = value received, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki tala. Sendu tölu með punkti sem aukastafaskiltákn, til dæmis 2.5.';
        BooleanFormatErr: Label 'Parameter ''%1'' has the value ''%2''. Send true or false, without quotes.', Comment = '%1 = parameter name, %2 = value received, is-IS=Færibreytan ''%1'' hefur gildið ''%2''. Sendu true eða false, án gæsalappa.';
        IntegerFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a whole number. Send a whole number, for example 3.', Comment = '%1 = parameter name, %2 = value received, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki heil tala. Sendu heila tölu, til dæmis 3.';
        ItemExampleTok: Label 'text, for example "1896-S"', Locked = true;
        NumberExampleTok: Label 'a number, for example 2.5', Locked = true;
        IntegerExampleTok: Label 'a whole number, for example 3', Locked = true;

    procedure ReadRequest(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject): Boolean
    begin
        if TryGetRequestJson(Argument, RequestJson) then
            exit(true);
        Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, '', '', NotObjectErr);
        exit(false);
    end;

    /// <summary>
    /// Answers a successful call. Builds the answer with "status": "Success" as its first key,
    /// followed by every key of ResponseJson except a key named status, so a caller can never
    /// forge the outcome by sending its own status. Foundation only adds its request warnings
    /// (for example UnknownParameter) to an answer that carries status, so use this for every
    /// success answer instead of Argument.SetResponseJson.
    /// </summary>
    /// <param name="Argument">The message argument of the call.</param>
    /// <param name="ResponseJson">The answer fields, without status.</param>
    procedure SetSuccess(var Argument: Record "Message Argument ori"; ResponseJson: JsonObject)
    var
        Envelope: JsonObject;
        Token: JsonToken;
        KeyName: Text;
    begin
        Envelope.Add('status', 'Success');
        foreach KeyName in ResponseJson.Keys() do
            if KeyName <> 'status' then begin
                ResponseJson.Get(KeyName, Token);
                Envelope.Add(KeyName, Token);
            end;
        Argument.SetResponseJson(Envelope);
    end;

    /// <summary>
    /// Answers an error with a code from "Bifrost Error Code ori", the parameter it concerns
    /// and the value received, so a caller can act on the code instead of parsing the text.
    /// Message is the translated Label text, unchanged. Empty ParameterName or Received are
    /// left out of the answer.
    /// </summary>
    /// <param name="Argument">The message argument of the call.</param>
    /// <param name="ErrorCode">The error code, as listed in the type's errors chapter.</param>
    /// <param name="ParameterName">The parameter the error concerns, or '' when none.</param>
    /// <param name="Received">The value received, or '' when none.</param>
    /// <param name="Message">The error text.</param>
    procedure Reject(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ParameterName: Text; Received: Text; Message: Text)
    begin
        Argument.RespondWithError(ErrorCode, Message, ParameterName, Received, '', '');
    end;

    /// <summary>
    /// Reads the item number from subject or "itemNo": missing, empty, wrong type and too long
    /// are separate answers. Whether the item EXISTS is the facade's job - it is business logic.
    /// </summary>
    procedure GetItemNo(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var ItemNo: Code[20]): Boolean
    var
        Token: JsonToken;
        Value: Text;
    begin
        Value := DelChr(Argument.Subject, '<>', ' ');
        if Value = '' then begin
            if not RequestJson.Get('itemNo', Token) then begin
                Reject(Argument, Enum::"Bifrost Error Code ori"::MissingParameter, 'itemNo', '', StrSubstNo(MissingErr, 'itemNo', ItemExampleTok));
                exit(false);
            end;
            if not Token.IsValue() then begin
                Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, 'itemNo', '', StrSubstNo(NotAValueErr, 'itemNo'));
                exit(false);
            end;
            if not Token.AsValue().IsNull() then
                Value := DelChr(Token.AsValue().AsText(), '<>', ' ');
            if Value = '' then begin
                Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameter, 'itemNo', '', StrSubstNo(EmptyErr, 'itemNo', '"1896-S"'));
                exit(false);
            end;
        end;
        if StrLen(Value) > MaxStrLen(ItemNo) then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameter, 'itemNo', '', StrSubstNo(TooLongErr, 'itemNo', StrLen(Value), MaxStrLen(ItemNo)));
            exit(false);
        end;
        ItemNo := CopyStr(UpperCase(Value), 1, MaxStrLen(ItemNo));
        exit(true);
    end;

    procedure GetRequiredDecimal(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Decimal): Boolean
    var
        Token: JsonToken;
        NumberText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::MissingParameter, KeyName, '', StrSubstNo(MissingErr, KeyName, NumberExampleTok));
            exit(false);
        end;
        if not Token.IsValue() then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, KeyName, '', StrSubstNo(NotAValueErr, KeyName));
            exit(false);
        end;
        if not Token.AsValue().IsNull() then
            NumberText := Token.AsValue().AsText();
        if not Evaluate(Value, NumberText, 9) then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, KeyName, NumberText, StrSubstNo(NumberFormatErr, KeyName, NumberText));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads an optional true/false. Absent or null gives Default. Only JSON true/false and the
    /// texts "true"/"false" are accepted - never a guess from "yes", 1 or "Y".
    /// </summary>
    procedure GetOptionalBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Default: Boolean; var Value: Boolean): Boolean
    var
        Token: JsonToken;
        BoolText: Text;
    begin
        Value := Default;
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if not Token.IsValue() then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, KeyName, '', StrSubstNo(NotAValueErr, KeyName));
            exit(false);
        end;
        if Token.AsValue().IsNull() then
            exit(true);
        BoolText := LowerCase(Token.AsValue().AsText());
        case BoolText of
            'true':
                Value := true;
            'false':
                Value := false;
            else begin
                Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, KeyName, BoolText, StrSubstNo(BooleanFormatErr, KeyName, BoolText));
                exit(false);
            end;
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads a required whole number: missing, not a value and not a whole number are separate answers.
    /// </summary>
    procedure GetRequiredInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Integer): Boolean
    var
        Token: JsonToken;
        NumberText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::MissingParameter, KeyName, '', StrSubstNo(MissingErr, KeyName, IntegerExampleTok));
            exit(false);
        end;
        if not Token.IsValue() then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, KeyName, '', StrSubstNo(NotAValueErr, KeyName));
            exit(false);
        end;
        if not Token.AsValue().IsNull() then
            NumberText := Token.AsValue().AsText();
        if not Evaluate(Value, NumberText, 9) then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, KeyName, NumberText, StrSubstNo(IntegerFormatErr, KeyName, NumberText));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads a text parameter. Required: missing and empty are errors. Optional: absent, null or
    /// empty gives ''. Too long and not a value are always errors.
    /// </summary>
    procedure GetText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; MaxLength: Integer; ExampleValue: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        Value := '';
        if not RequestJson.Get(KeyName, Token) then begin
            if not Required then
                exit(true);
            Reject(Argument, Enum::"Bifrost Error Code ori"::MissingParameter, KeyName, '', StrSubstNo(MissingErr, KeyName, 'text, for example ' + ExampleValue));
            exit(false);
        end;
        if not Token.IsValue() then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameterFormat, KeyName, '', StrSubstNo(NotAValueErr, KeyName));
            exit(false);
        end;
        if not Token.AsValue().IsNull() then
            Value := DelChr(Token.AsValue().AsText(), '<>', ' ');
        if Value = '' then begin
            if not Required then
                exit(true);
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameter, KeyName, '', StrSubstNo(EmptyErr, KeyName, ExampleValue));
            exit(false);
        end;
        if StrLen(Value) > MaxLength then begin
            Reject(Argument, Enum::"Bifrost Error Code ori"::InvalidParameter, KeyName, '', StrSubstNo(TooLongErr, KeyName, StrLen(Value), MaxLength));
            exit(false);
        end;
        exit(true);
    end;

    [TryFunction]
    local procedure TryGetRequestJson(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject)
    begin
        RequestJson := Argument.GetRequestJson();
    end;
}
