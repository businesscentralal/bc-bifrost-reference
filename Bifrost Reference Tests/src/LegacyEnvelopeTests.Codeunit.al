namespace Origo.Bifrost.Reference.Tests;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// The answer envelope of every Legacy type (core#1149): a success answer starts with
/// status Success, and every error carries a code from "Bifrost Error Code ori".
/// Items are created with the BIFT-LE prefix and no inventory.
/// </summary>
codeunit 90157 "Legacy Envelope Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "Ref Test Caller";
        ItemNoTok: Label 'BIFT-LE1', Locked = true;

    [Test]
    procedure EverySuccessAnswerStartsWithStatusSuccess()
    begin
        CreateItem(ItemNoTok);
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", ItemNoTok, '{"quantity":1,"allowOverStock":true}'));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Get", ItemNoTok, ''));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.List", '', '{"itemFilter":"BIFT-LE*"}'));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", ItemNoTok, ''));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.ReleaseAll", '', '{"itemFilter":"BIFT-LE*","expectedCount":0}'));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Help.Legacy.Get", '', ''));
    end;

    [Test]
    procedure TextQuantityIsInvalidParameterFormat()
    var
        Response: JsonObject;
    begin
        CreateItem(ItemNoTok);
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", ItemNoTok, '{"quantity":"abc"}');
        Caller.AssertErrorCode(Response, 'InvalidParameterFormat');
        Assert.AreEqual('quantity', Caller.GetText(Response, 'parameter'), 'parameter');
        Assert.AreEqual('abc', Caller.GetText(Response, 'received'), 'received');
    end;

    [Test]
    procedure MissingQuantityIsMissingParameter()
    begin
        CreateItem(ItemNoTok);
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", ItemNoTok, '{}'), 'MissingParameter');
    end;

    [Test]
    procedure BadBooleanIsInvalidParameterFormat()
    begin
        CreateItem(ItemNoTok);
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", ItemNoTok, '{"quantity":1,"allowOverStock":"yes"}'), 'InvalidParameterFormat');
    end;

    [Test]
    procedure BadFilterIsInvalidParameterOnItemFilter()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.List", '', '{"itemFilter":"1000..2000..3000"}');
        Caller.AssertErrorCode(Response, 'InvalidParameter');
        Assert.AreEqual('itemFilter', Caller.GetText(Response, 'parameter'), 'parameter');
    end;

    [Test]
    procedure MisspelledQuantityOnReserveIsNeverASilentSuccess()
    var
        Response: JsonObject;
    begin
        CreateItem(ItemNoTok);
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", ItemNoTok, '{"quantiy":1}');
        Assert.AreEqual('Error', Caller.GetText(Response, 'status'), 'A misspelled key on a write is never a success.');
        if Caller.GetText(Response, 'code') <> 'UnknownParameter' then
            Caller.AssertWarning(Response, 'UnknownParameter', 'quantiy');
    end;

    [Test]
    procedure EveryContractDeclaresTheEnvelope()
    begin
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Legacy.Stock.Reserve");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Legacy.Stock.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Legacy.Stock.List");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Legacy.Stock.ReleaseAll");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Help.Legacy.Get");
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
