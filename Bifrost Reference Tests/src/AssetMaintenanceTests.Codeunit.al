namespace Origo.Bifrost.Reference.Tests;

using Microsoft.FixedAssets.FixedAsset;
using Origo.Bifrost;
using Origo.Bifrost.Reference;
using System.TestLibraries.Utilities;

/// <summary>
/// Reference.AssetMaintenance.Create - the break set and the safe retry, as unit tests. Each test
/// is one line of the live test plan (TESTING.md), so a change that breaks an answer an agent
/// relies on fails the build instead of a user's first call.
/// </summary>
codeunit 90152 "Asset Maintenance Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "Ref Test Caller";
        AssetNoTok: Label 'BIFT-FA1', Locked = true;

    [Test]
    procedure LocalDateFormatIsRefusedWithTheIsoFormat()
    begin
        // [GIVEN] a fixed asset  [WHEN] the date is sent as 26.09.2026
        CreateFixedAsset();
        // [THEN] the answer names the parameter, echoes the value and gives the format to send
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", AssetNoTok, '{"maintenanceDate":"26.09.2026","hours":1}'),
            'YYYY-MM-DD');
    end;

    [Test]
    procedure UnknownAssetIsNotFoundRatherThanMissing()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", 'BIFT-NOPE', '{"maintenanceDate":"2026-01-02","hours":1}'),
            'was not found');
    end;

    [Test]
    procedure NoAssetAtAllIsMissingRatherThanNotFound()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", '', '{"maintenanceDate":"2026-01-02","hours":1}'),
            'No fixed asset was given');
    end;

    [Test]
    procedure MaintenanceInTheFutureIsRefused()
    begin
        CreateFixedAsset();
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", AssetNoTok,
                StrSubstNo('{"maintenanceDate":"%1","hours":1}', Format(CalcDate('<+1D>', WorkDate()), 0, 9))),
            'after the work date');
    end;

    [Test]
    procedure HoursOutOfRangeIsRefused()
    begin
        CreateFixedAsset();
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", AssetNoTok, '{"maintenanceDate":"2026-01-02","hours":30}'),
            'must be between');
    end;

    [Test]
    procedure SameExternalIdTwiceWritesOneEntry()
    var
        AssetMaintenance: Record "Ref Asset Maintenance";
        Request: Text;
        First: JsonObject;
        Second: JsonObject;
    begin
        // [GIVEN] a fixed asset and a request carrying an externalId
        CreateFixedAsset();
        Request := '{"maintenanceDate":"2026-01-02","hours":1.5,"description":"Oil change","externalId":"BIFT-WO-1"}';

        // [WHEN] the same request is sent twice, as a client retrying after a timeout would
        First := Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", AssetNoTok, Request);
        Second := Caller.Call(Enum::"Message Type ori"::"Reference.AssetMaintenance.Create", AssetNoTok, Request);

        // [THEN] the first call created the entry, the second returned it, and there is one row
        Caller.AssertOk(First);
        Assert.IsTrue(Caller.GetBoolean(First, 'created'), 'The first call should create the entry.');
        Assert.IsFalse(Caller.GetBoolean(Second, 'created'), 'The retry should return the existing entry.');
        Assert.AreEqual(Caller.GetText(First, 'entryNo'), Caller.GetText(Second, 'entryNo'), 'Both calls should answer with the same entry.');
        AssetMaintenance.SetRange("External Id", 'BIFT-WO-1');
        Assert.RecordCount(AssetMaintenance, 1);
    end;

    [Test]
    procedure HelpListsTheErrorTheTypeReallyReturns()
    begin
        // The help is the agent's only guide: it must quote the real error text, not an old one.
        Assert.IsTrue(Caller.GetHelp('Reference.AssetMaintenance.Create').Contains('YYYY-MM-DD'), 'The help should document the date format error.');
    end;

    local procedure CreateFixedAsset()
    var
        FixedAsset: Record "Fixed Asset";
    begin
        if FixedAsset.Get(AssetNoTok) then
            exit;
        FixedAsset.Init();
        FixedAsset."No." := AssetNoTok;
        FixedAsset.Description := 'Bifrost test machine';
        FixedAsset.Insert(true);
    end;
}
