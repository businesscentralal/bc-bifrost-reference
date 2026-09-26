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
    /// Runs a message type and returns its answer as text (JSON or Markdown).
    /// </summary>
    procedure CallRaw(MessageType: Enum "Message Type ori"; Subject: Text; RequestText: Text) ResponseText: Text
    var
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[50];
    begin
        if RequestText <> '' then
            RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250), '', '', RequestContent, ResponseContent, ResponseContentType);
        if ResponseContent.Length() > 0 then
            ResponseContent.GetSubText(ResponseText, 1);
    end;

    /// <summary>
    /// The help document of a message type, exactly as callers receive it.
    /// </summary>
    procedure GetHelp(MessageTypeName: Text): Text
    begin
        exit(CallRaw(Enum::"Message Type ori"::"Help.Implementation.Get", MessageTypeName, ''));
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
    /// Asserts that the answer is not an error.
    /// </summary>
    procedure AssertOk(Response: JsonObject)
    begin
        Assert.AreNotEqual('Error', GetText(Response, 'status'), 'Expected success. Answer: ' + AsJsonText(Response));
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
