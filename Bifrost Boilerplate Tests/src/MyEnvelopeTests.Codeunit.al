namespace MyCompany.MyBifrostApp.Tests;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// The answer envelope of every MyApp type (core#1149): a success answer starts with
/// status Success, so Foundation can add its UnknownParameter warning, and every error carries a
/// code from "Bifrost Error Code ori". Items are created with the BIFT-BE prefix.
/// </summary>
codeunit 50055 "My Envelope Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "My Test Caller";
        ItemNoTok: Label 'BIFT-BE1', Locked = true;

    [Test]
    procedure MisspelledFilterKeyWarnsAndNamesTheRightKey()
    var
        Response: JsonObject;
        ResponseText: Text;
    begin
        // [WHEN] MyApp.Item.List is called with itemFiltr instead of itemFilter
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', '{"itemFiltr":"19*"}');
        // [THEN] the answer is a success with an UnknownParameter warning that names itemFilter
        Caller.AssertOk(Response);
        Caller.AssertWarning(Response, 'UnknownParameter', 'itemFiltr');
        Response.WriteTo(ResponseText);
        Assert.IsTrue(ResponseText.Contains('itemFilter'), 'The warning should name itemFilter: ' + ResponseText);
    end;

    [Test]
    procedure KeyWithDifferentCaseIsNotSilentlyAccepted()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', '{"ItemFilter":"19*"}');
        Caller.AssertOk(Response);
        Caller.AssertWarning(Response, 'UnknownParameter', 'ItemFilter');
    end;

    [Test]
    procedure EverySuccessAnswerStartsWithStatusSuccess()
    begin
        CreateItem(ItemNoTok);
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"MyApp.Hello.Get", '', '{"name":"Ada"}'));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"MyApp.Item.Summary.Get", ItemNoTok, ''));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', ''));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Help.MyApp.Get", '', ''));
    end;

    [Test]
    procedure EmptyDataIsASuccessWithoutWarnings()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', '{}');
        Caller.AssertOk(Response);
        Assert.IsFalse(Response.Contains('warnings') and Caller.HasWarning(Response, 'UnknownParameter', ''), 'An empty request has no unknown key.');
    end;

    [Test]
    procedure CallerCannotForgeTheStatus()
    begin
        // A status sent by the caller is not a parameter of Hello: the answer is still Success.
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"MyApp.Hello.Get", '', '{"name":"Ada","status":"Error"}'));
    end;

    [Test]
    procedure OutOfRangeIsInvalidParameter()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', '{"maxRows":500}');
        Caller.AssertErrorCode(Response, 'InvalidParameter');
        Assert.AreEqual('maxRows', Caller.GetText(Response, 'parameter'), 'parameter');
        Caller.AssertErrorAnswer(Response, 'must be between 1 and 100');
    end;

    [Test]
    procedure LocalDateFormatIsInvalidParameterFormat()
    var
        Response: JsonObject;
    begin
        CreateItem(ItemNoTok);
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Item.Summary.Get", ItemNoTok, '{"asOfDate":"26.09.2026"}');
        Caller.AssertErrorCode(Response, 'InvalidParameterFormat');
        Assert.AreEqual('asOfDate', Caller.GetText(Response, 'parameter'), 'parameter');
        Assert.AreEqual('26.09.2026', Caller.GetText(Response, 'received'), 'received');
    end;

    [Test]
    procedure UnknownItemIsRecordNotFound()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"MyApp.Item.Summary.Get", 'BIFT-BENOPE', ''), 'RecordNotFound');
    end;

    [Test]
    procedure BadFilterIsInvalidParameterOnItemFilter()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', '{"itemFilter":"1000..2000..3000"}');
        Caller.AssertErrorCode(Response, 'InvalidParameter');
        Assert.AreEqual('itemFilter', Caller.GetText(Response, 'parameter'), 'parameter');
    end;

    [Test]
    procedure NestedValueIsInvalidParameterFormat()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', '{"itemFilter":{"from":"1"}}'), 'InvalidParameterFormat');
    end;

    [Test]
    procedure EveryContractDeclaresTheEnvelope()
    begin
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"MyApp.Hello.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"MyApp.Item.Summary.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"MyApp.Item.List");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Help.MyApp.Get");
    end;

    local procedure CreateItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            exit;
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'Bifrost envelope test item';
        Item.Insert(true);
    end;
}
