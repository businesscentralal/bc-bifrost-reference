namespace Origo.Bifrost.Reference.Tests;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Calls message types the way every test should: through Foundation's public "Dispatcher ori",
/// never through an Impl codeunit or an internal. Execute runs with Omit Commit = true, so:
///  - input errors answered with RespondWithError come back as {"status":"Error","error":...};
///  - errors raised inside an isolated write (the facade's business rules) are raised out of the
///    call - test them with asserterror + Assert.ExpectedError().
/// (The helper is called AssertErrorAnswer because "AssertError" is a reserved word in AL.)
/// Copy this codeunit into your own test app.
/// </summary>
codeunit 90150 "Ref Test Caller"
{
    var
        Assert: Codeunit "Library Assert";
        Dispatcher: Codeunit "Dispatcher ori";

    /// <summary>
    /// Runs a message type and returns its JSON answer.
    /// </summary>
    procedure Call(MessageType: Enum "Message Type ori"; Subject: Text; RequestText: Text) Response: JsonObject
    begin
        Response.ReadFrom(CallRaw(MessageType, Subject, RequestText));
    end;

    /// <summary>
    /// Runs a message type and returns its answer as text.
    /// </summary>
    procedure CallRaw(MessageType: Enum "Message Type ori"; Subject: Text; RequestText: Text) ResponseText: Text
    var
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
    begin
        if RequestText <> '' then
            RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250), '', '', RequestContent, ResponseContent, ResponseContentType);
        if ResponseContent.Length() > 0 then
            ResponseContent.GetSubText(ResponseText, 1);
    end;

    /// <summary>
    /// One chapter of a message type's contract (for example 'errors'), as JSON text; '' when the
    /// type does not declare it. Read through "Msg Contract Mgt ori".GetContract, the same function
    /// Help.Implementation.Get uses, so a test sees exactly what callers see.
    /// </summary>
    procedure GetContractChapter(MessageType: Enum "Message Type ori"; Chapter: Text) Result: Text
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Token: JsonToken;
    begin
        ContractMgt.GetContract(MessageType, Contract);
        if Contract.Get(Chapter, Token) then
            Token.WriteTo(Result);
    end;

    /// <summary>
    /// Asserts that the answer is status = Error and that its text contains ExpectedPart.
    /// </summary>
    procedure AssertErrorAnswer(Response: JsonObject; ExpectedPart: Text)
    var
        ErrorText: Text;
    begin
        Assert.AreEqual('Error', GetText(Response, 'status'), 'Expected status Error. Answer: ' + AsJsonText(Response));
        ErrorText := GetText(Response, 'error');
        Assert.IsTrue(ErrorText.Contains(ExpectedPart), StrSubstNo('Error text "%1" should contain "%2".', ErrorText, ExpectedPart));
    end;

    /// <summary>
    /// Asserts that the answer is a success: status = Success, and status is the first key.
    /// </summary>
    procedure AssertOk(Response: JsonObject)
    begin
        Assert.AreEqual('Success', GetText(Response, 'status'), 'Expected status Success. Answer: ' + AsJsonText(Response));
        Assert.AreEqual('status', Response.Keys().Get(1), 'status should be the first key. Answer: ' + AsJsonText(Response));
    end;

    /// <summary>
    /// Asserts that the answer is status = Error with the given code from "Bifrost Error Code ori".
    /// </summary>
    procedure AssertErrorCode(Response: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual('Error', GetText(Response, 'status'), 'Expected status Error. Answer: ' + AsJsonText(Response));
        Assert.AreEqual(ExpectedCode, GetText(Response, 'code'), 'Expected error code. Answer: ' + AsJsonText(Response));
    end;

    /// <summary>
    /// Asserts that the answer carries a warning with the given code for the given parameter.
    /// </summary>
    procedure AssertWarning(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text)
    begin
        Assert.IsTrue(HasWarning(Response, ExpectedCode, ExpectedParameter), StrSubstNo('Expected a %1 warning for %2. Answer: %3', ExpectedCode, ExpectedParameter, AsJsonText(Response)));
    end;

    /// <summary>
    /// True when the answer carries a warning with the given code for the given parameter.
    /// </summary>
    procedure HasWarning(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text): Boolean
    var
        WarningsToken: JsonToken;
        Warning: JsonToken;
    begin
        if not Response.Get('warnings', WarningsToken) then
            exit(false);
        if not WarningsToken.IsArray() then
            exit(false);
        foreach Warning in WarningsToken.AsArray() do
            if Warning.IsObject() then
                if (GetText(Warning.AsObject(), 'code') = ExpectedCode) and (GetText(Warning.AsObject(), 'parameter') = ExpectedParameter) then
                    exit(true);
        exit(false);
    end;

    /// <summary>
    /// Asserts the envelope in a type's contract: the response chapter declares status first,
    /// every errors entry has a code, every success example answer starts with status Success,
    /// every error example has a code, and every example request sends only declared parameters.
    /// </summary>
    procedure AssertEnvelopeContract(MessageType: Enum "Message Type ori")
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        FieldToken: JsonToken;
        Declared: List of [Text];
        DataKey: Text;
        TypeName: Text;
    begin
        TypeName := Format(MessageType);
        ContractMgt.GetContract(MessageType, Contract);
        Assert.IsTrue(Contract.Get('response', Token), TypeName + ': response chapter');
        Token.AsObject().Get('fields', Token);
        Token.AsArray().Get(0, Entry);
        Assert.AreEqual('status', GetText(Entry.AsObject(), 'name'), TypeName + ': the first response field should be status.');

        Assert.IsTrue(Contract.Get('errors', Token), TypeName + ': errors chapter');
        foreach Entry in Token.AsArray() do
            Assert.AreNotEqual('', GetText(Entry.AsObject(), 'code'), TypeName + ': every errors entry needs a code: ' + GetText(Entry.AsObject(), 'error'));

        if Contract.Get('parameters', Token) then
            if Token.IsArray() then
                foreach Entry in Token.AsArray() do
                    Declared.Add(GetText(Entry.AsObject(), 'name'));

        Assert.IsTrue(Contract.Get('examples', Token), TypeName + ': examples chapter');
        foreach Entry in Token.AsArray() do begin
            Entry.AsObject().Get('response', FieldToken);
            if GetText(FieldToken.AsObject(), 'status') = 'Error' then
                Assert.AreNotEqual('', GetText(FieldToken.AsObject(), 'code'), TypeName + ': every error example needs a code.')
            else begin
                Assert.AreEqual('Success', GetText(FieldToken.AsObject(), 'status'), TypeName + ': a success example should have status Success.');
                Assert.AreEqual('status', FieldToken.AsObject().Keys().Get(1), TypeName + ': status should be the first key of a success example.');
                Entry.AsObject().Get('request', FieldToken);
                if FieldToken.AsObject().Get('data', FieldToken) then
                    if FieldToken.IsObject() then
                        foreach DataKey in FieldToken.AsObject().Keys() do
                            Assert.IsTrue(Declared.Contains(DataKey), StrSubstNo('%1: example data key %2 is not a declared parameter.', TypeName, DataKey));
            end;
        end;
    end;

    procedure GetText(Response: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Response.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    procedure GetDecimal(Response: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        Response.Get(KeyName, Token);
        exit(Token.AsValue().AsDecimal());
    end;

    procedure GetBoolean(Response: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        Response.Get(KeyName, Token);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure AsJsonText(Response: JsonObject) AsText: Text
    begin
        Response.WriteTo(AsText);
    end;
}
