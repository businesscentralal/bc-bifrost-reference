namespace Origo.Bifrost.Reference.Tests;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Reference.Legacy;
using System.TestLibraries.Utilities;

/// <summary>
/// Legacy.Stock.* - proves the fixes of the §7.1 audit stay fixed:
///  - the stock check applies without a UI (the v1 GuiAllowed branch), and the person's decision
///    is the explicit allowOverStock parameter;
///  - errors raised by the facade inside the isolated write reach the caller (no swallowed errors);
///  - a bulk release is all or nothing and guarded by expectedCount;
///  - outcomes are returned, including "nothing happened".
/// Items are created with no inventory, so every reservation is "over stock".
/// </summary>
codeunit 90153 "Legacy Adapter Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "Ref Test Caller";
        OverStockPartTxt: Label 'explicitly allow over-reservation', Locked = true;

    [Test]
    procedure ReserveOverStockWithoutTheFlagIsRefused()
    begin
        // [GIVEN] an item with nothing in stock
        CreateItem('BIFT-L1');
        // [WHEN] a caller without a UI reserves it  [THEN] the facade's rule applies, as it does for a person
        asserterror Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", 'BIFT-L1', '{"quantity":1}');
        Assert.ExpectedError(OverStockPartTxt);
    end;

    [Test]
    procedure ReserveOverStockWithTheFlagIsAllowedAndSaysSo()
    var
        Response: JsonObject;
    begin
        CreateItem('BIFT-L2');
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", 'BIFT-L2', '{"quantity":2,"allowOverStock":true}');
        Caller.AssertOk(Response);
        Assert.AreEqual(2, Caller.GetDecimal(Response, 'totalReserved'), 'totalReserved');
        Assert.AreEqual(-2, Caller.GetDecimal(Response, 'availableToReserve'), 'availableToReserve should show the over-reservation.');
    end;

    [Test]
    procedure AllowOverStockMustBeTrueOrFalse()
    begin
        CreateItem('BIFT-L3');
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", 'BIFT-L3', '{"quantity":1,"allowOverStock":"yes"}'),
            'Send true or false');
    end;

    [Test]
    procedure CancelWithNothingToCancelSaysSo()
    var
        Response: JsonObject;
    begin
        CreateItem('BIFT-L4');
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'BIFT-L4', '');
        Caller.AssertOk(Response);
        Assert.IsFalse(Caller.GetBoolean(Response, 'cancelled'), 'A no-op must not be answered as a change.');
    end;

    [Test]
    procedure ReleaseAllWithTheWrongCountIsRefused()
    begin
        // [GIVEN] two reservations matching the filter
        ReserveOverStock('BIFT-R1', 1);
        ReserveOverStock('BIFT-R2', 1);
        // [WHEN] the caller guesses the count  [THEN] it is refused
        asserterror Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.ReleaseAll", '', '{"itemFilter":"BIFT-R*","expectedCount":5}');
        Assert.ExpectedError('Nothing was released');
    end;

    [Test]
    procedure ReleaseAllWithoutAFilterIsRefused()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.ReleaseAll", '', '{"expectedCount":1}'),
            'is required');
    end;

    [Test]
    procedure ReleaseAllWithTheListedCountReleasesAndLogs()
    var
        Log: Record "Legacy Cancellation Log";
        Listed: JsonObject;
        Released: JsonObject;
    begin
        // [GIVEN] two reservations, and the count as Legacy.Stock.List reports it
        ReserveOverStock('BIFT-S1', 1);
        ReserveOverStock('BIFT-S2', 3);
        Listed := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.List", '', '{"itemFilter":"BIFT-S*"}');
        Assert.AreEqual(2, Caller.GetDecimal(Listed, 'count'), 'List count');
        Assert.AreEqual(4, Caller.GetDecimal(Listed, 'totalQuantity'), 'List totalQuantity');

        // [WHEN] the caller releases with that count
        Released := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.ReleaseAll", '',
            StrSubstNo('{"itemFilter":"BIFT-S*","expectedCount":%1}', Caller.GetText(Listed, 'count')));

        // [THEN] both are released, and each is logged
        Caller.AssertOk(Released);
        Assert.AreEqual(2, Caller.GetDecimal(Released, 'released'), 'released');
        Assert.IsFalse(HasReservation('BIFT-S1'), 'BIFT-S1 should be released.');
        Assert.IsFalse(HasReservation('BIFT-S2'), 'BIFT-S2 should be released.');
        Log.SetFilter("Item No.", 'BIFT-S*');
        Assert.RecordCount(Log, 2);
    end;

    [Test]
    procedure HelpQuotesTheFacadesOverStockError()
    begin
        // The core's Label and the message type's help live in two codeunits; this keeps them in step.
        Assert.IsTrue(Caller.GetHelp('Legacy.Stock.Reserve').Contains(OverStockPartTxt), 'The Reserve help should quote the over-stock error.');
    end;

    [Test]
    procedure DirectoryListsEveryLegacyType()
    var
        Directory: Text;
    begin
        Directory := Caller.CallRaw(Enum::"Message Type ori"::"Help.Legacy.Get", '', '');
        Assert.IsTrue(Directory.Contains('Legacy.Stock.Reserve'), 'Reserve is missing from Help.Legacy.Get.');
        Assert.IsTrue(Directory.Contains('Legacy.Stock.CancelReservation'), 'CancelReservation is missing from Help.Legacy.Get.');
        Assert.IsTrue(Directory.Contains('Legacy.Stock.Get'), 'Get is missing from Help.Legacy.Get.');
        Assert.IsTrue(Directory.Contains('Legacy.Stock.List'), 'List is missing from Help.Legacy.Get.');
        Assert.IsTrue(Directory.Contains('Legacy.Stock.ReleaseAll'), 'ReleaseAll is missing from Help.Legacy.Get.');
    end;

    local procedure ReserveOverStock(ItemNo: Code[20]; Quantity: Decimal)
    begin
        // Through the public API, like every caller outside Legacy App: the core is internal.
        CreateItem(ItemNo);
        Caller.AssertOk(
            Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", ItemNo,
                StrSubstNo('{"quantity":%1,"allowOverStock":true}', Format(Quantity, 0, 9))));
    end;

    local procedure HasReservation(ItemNo: Code[20]): Boolean
    begin
        exit(Caller.GetBoolean(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Get", ItemNo, ''), 'hasReservation'));
    end;

    local procedure CreateItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            exit;
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'Bifrost test item';
        Item.Insert(true);
    end;
}
