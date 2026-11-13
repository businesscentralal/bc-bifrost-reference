namespace MyCompany.MyBifrostApp.Tests;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// MyApp.ItemSummary.Get and MyApp.Item.List - the happy path and the break set, as unit
/// tests. Each test is one answer an agent relies on, so a change that breaks it fails the build
/// instead of a user's first call. Items are created with the BIFT-BP prefix.
/// </summary>
codeunit 50052 "My Item Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "My Test Caller";
        ItemNoTok: Label 'BIFT-BP1', Locked = true;
        SecondItemNoTok: Label 'BIFT-BP2', Locked = true;

    [Test]
    procedure SummaryReturnsTheItemWithNullForNoBaseUnit()
    var
        Response: JsonObject;
        ExpectedNo: Text;
    begin
        // [GIVEN] an item with no entries and no base unit of measure
        CreateItem(ItemNoTok);
        ExpectedNo := ItemNoTok;

        // [WHEN] the summary is asked for by item number in subject
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.ItemSummary.Get", ItemNoTok, '');

        // [THEN] the item is found, the inventory is 0 as of the work date and "no unit" is null, not ''
        Caller.AssertOk(Response);
        Assert.AreEqual(ExpectedNo, Caller.GetText(Response, 'itemNo'), 'itemNo');
        Assert.AreEqual(Format(WorkDate(), 0, 9), Caller.GetText(Response, 'asOfDate'), 'asOfDate should default to the work date.');
        Assert.AreEqual(0, Caller.GetDecimal(Response, 'inventory'), 'An item without entries has no inventory.');
        Assert.IsTrue(Caller.IsNullValue(Response, 'baseUnitOfMeasure'), 'baseUnitOfMeasure should be null when no base unit is set.');
    end;

    [Test]
    procedure UnknownItemIsNotFoundRatherThanMissing()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"MyApp.ItemSummary.Get", 'BIFT-NOPE', ''),
            'was not found');
    end;

    [Test]
    procedure LocalDateFormatIsRefusedWithTheIsoFormat()
    begin
        // [GIVEN] an item  [WHEN] the date is sent as 26.09.2026
        CreateItem(ItemNoTok);
        // [THEN] the answer names the parameter, echoes the value and gives the format to send
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"MyApp.ItemSummary.Get", ItemNoTok, '{"asOfDate":"26.09.2026"}'),
            'YYYY-MM-DD');
    end;

    [Test]
    procedure ContractQuotesTheErrorTheTypeReallyReturns()
    begin
        // The contract is the agent's only guide: its errors chapter must quote the real error text
        // from My Input, not an old one. Change the Label and the chapter together.
        Assert.IsTrue(
            Caller.GetContractChapter(Enum::"Message Type ori"::"MyApp.ItemSummary.Get", 'errors').Contains('which is not a date in the format YYYY-MM-DD'),
            'The errors chapter should document the date format error.');
    end;

    [Test]
    procedure ListIsCappedAndSaysThereIsMore()
    var
        Response: JsonObject;
    begin
        // [GIVEN] two items matching the filter
        CreateItem(ItemNoTok);
        CreateItem(SecondItemNoTok);

        // [WHEN] the list is asked for with room for one row
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Item.List", '', '{"itemFilter":"BIFT-BP*","maxRows":1}');

        // [THEN] one row is returned, the count covers both and "more" says there are others
        Caller.AssertOk(Response);
        Assert.AreEqual(2, Caller.GetDecimal(Response, 'count'), 'count should cover every matching item.');
        Assert.AreEqual(1, Caller.GetDecimal(Response, 'returned'), 'returned should respect maxRows.');
        Assert.IsTrue(Caller.GetBoolean(Response, 'more'), 'more should be true when rows were left out.');
    end;

    [Test]
    procedure Scenario_AC01_ItemSummaryKeepsItsOrdinalAndThreePartName()
    var
        MessageType: Enum "Message Type ori";
        Examples: Text;
    begin
        // [SCENARIO] AC01: renaming the public type preserves its ordinal and contract calls.
        // [GIVEN] the renamed product message type
        MessageType := Enum::"Message Type ori"::"MyApp.ItemSummary.Get";
        // [WHEN] its public enum name and examples chapter are read through the public contract manager
        Examples := Caller.GetContractChapter(MessageType, 'examples');
        // [THEN] existing ordinal routing and copied contract calls use the same three-part name
        Assert.AreEqual(50000, MessageType.AsInteger(), 'Renaming must preserve the enum ordinal.');
        Assert.AreEqual('MyApp.ItemSummary.Get', MessageType.Names().Get(MessageType.Ordinals().IndexOf(50000)), 'Public message type name.');
        Assert.IsTrue(Examples.Contains('MyApp.ItemSummary.Get'), 'Contract examples must call the renamed type.');
    end;

    local procedure CreateItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            exit;
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'Bifrost boilerplate test item';
        Item.Insert(true);
    end;
}
