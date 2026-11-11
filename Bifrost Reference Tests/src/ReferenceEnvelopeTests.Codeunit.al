namespace Origo.Bifrost.Reference.Tests;

using Origo.Bifrost;
using Origo.Bifrost.Reference;
using System.TestLibraries.Utilities;

/// <summary>
/// The answer envelope of every Reference type (core#1149): a success answer starts with
/// status Success, so Foundation can add its UnknownParameter warning, and every error carries a
/// code from "Bifrost Error Code ori". Fixtures use the BIFT- prefix.
/// </summary>
codeunit 90156 "Reference Envelope Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "Ref Test Caller";

    [Test]
    procedure EchoDeclaredMessageIsReturnedAndStatusCannotBeForged()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.Echo.Get", '', '{"message":"hi","status":"Error"}');
        Caller.AssertOk(Response);
        Assert.AreEqual('hi', Caller.GetText(Response, 'message'), 'message');
        Assert.IsFalse(Response.Contains('warnings'), 'The declared message and ignored caller status must not produce warnings.');
    end;

    [Test]
    procedure EchoUndeclaredKeyIsReturnedWithAWarning()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.Echo.Get", '', '{"other":1}');
        Caller.AssertOk(Response);
        Assert.AreEqual('1', Caller.GetText(Response, 'other'), 'other is returned.');
        Caller.AssertWarning(Response, 'UnknownParameter', 'other');
    end;

    [Test]
    procedure ReadAnswersStartWithStatusSuccess()
    begin
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Reference.Echo.Get", '', ''));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Reference.Table.Get", '', '{"tableName":"Item"}'));
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Help.Reference.Get", '', ''));
    end;

    [Test]
    procedure NotObjectBodyIsInvalidParameterFormat()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.Echo.Get", '', '["hello"]'), 'InvalidParameterFormat');
    end;

    [Test]
    procedure MissingParameterIsMissingParameter()
    var
        Response: JsonObject;
    begin
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.Table.Get", '', '{}');
        Caller.AssertErrorCode(Response, 'MissingParameter');
        Assert.AreEqual('tableName', Caller.GetText(Response, 'parameter'), 'parameter');
    end;

    [Test]
    procedure EmptyParameterIsInvalidParameter()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.Table.Get", '', '{"tableName":"  "}'), 'InvalidParameter');
    end;

    [Test]
    procedure UnknownTableIsRecordNotFound()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.Table.Get", '', '{"tableName":"BIFT No Such Table"}'), 'RecordNotFound');
    end;

    [Test]
    procedure UnknownAccountIsRecordNotFoundAndNoAccountIsMissing()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.GLAccount.Overview.Get", 'BIFT-NOPE', ''), 'RecordNotFound');
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.GLAccount.Overview.Get", '', '{}'), 'MissingParameter');
    end;

    [Test]
    procedure SameCurrencyIsPreconditionFailed()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.ExchangeRate.Get", '', '{"from":"EUR","to":"EUR"}'), 'PreconditionFailed');
    end;

    [Test]
    procedure BadCurrencyIsInvalidParameterFormat()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.ExchangeRate.Get", '', '{"from":"E1","to":"EUR"}'), 'InvalidParameterFormat');
    end;

    [Test]
    procedure UnknownCategoryIsRecordNotFound()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.PreviewAdjustment", '', '{"itemCategoryCode":"BIFT-NOPE","percent":5}'), 'RecordNotFound');
    end;

    [Test]
    procedure NoAssetIsMissingParameter()
    begin
        Caller.AssertErrorCode(Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", '', '{}'), 'MissingParameter');
    end;

    [Test]
    procedure MisspelledKeyOnNoteAddIsNeverASilentSuccess()
    var
        RefNote: Record "Ref Note";
        Response: JsonObject;
    begin
        // [WHEN] Reference.Note.Add is sent txt instead of text
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.Note.Add", '', '{"no":"BIFT-N1149","txt":"hello"}');
        // [THEN] refused with UnknownParameter (core#1148 strict mode) or a success with the warning
        if Caller.GetText(Response, 'status') = 'Error' then
            Caller.AssertErrorCode(Response, 'UnknownParameter')
        else begin
            Caller.AssertOk(Response);
            Caller.AssertWarning(Response, 'UnknownParameter', 'txt');
        end;
        if RefNote.Get('BIFT-N1149') then
            RefNote.Delete();
    end;

    [Test]
    procedure EveryContractDeclaresTheEnvelope()
    begin
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.Echo.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.Table.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.Note.Add");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Help.Reference.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.GLAccount.Overview.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.ItemPrice.PreviewAdjustment");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.ExchangeRate.Get");
        Caller.AssertEnvelopeContract(Enum::"Message Type ori"::"Reference.ApiKey.Set");
    end;
}
