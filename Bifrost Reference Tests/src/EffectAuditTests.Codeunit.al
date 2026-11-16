namespace Origo.Bifrost.Reference.Tests;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Reference.Legacy;
using System.TestLibraries.Utilities;

/// <summary>Issue 17: real effects, confirmation counts and discoverable count units through the public dispatcher.</summary>
codeunit 90157 "Effect Audit Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "Ref Test Caller";

    /// <summary>Cancellation preview preserves the reservation and cancellation log.</summary>
    [Test]
    procedure Scenario_AC01_CancelPreview_PreservesReservation()
    var
        Log: Record "Legacy Cancellation Log";
        Response: JsonObject;
    begin
        // Story #17, AC01 | Time: independent of Today/WorkDate | Risk: shared confirmation gate.
        SetConfirmationRequired(true);
        ReserveItem();
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'E17-CANCEL', '');
        Assert.AreEqual('ConfirmationRequired', Caller.GetText(Response, 'code'), 'Cancellation must preview before deletion.');
        Assert.AreEqual(1, Caller.GetDecimal(Response, 'expected'), 'One named item is confirmed.');
        AssertReservation(true);
        Log.SetRange("Item No.", 'E17-CANCEL');
        Assert.RecordCount(Log, 0);
    end;

    /// <summary>A wrong cancellation count cannot remove or log a reservation.</summary>
    [Test]
    procedure Scenario_AC01_CancelWrongCount_PreservesReservation()
    var
        Response: JsonObject;
    begin
        // Story #17, AC01 | Time: none | Risk: shared confirmation gate.
        SetConfirmationRequired(true);
        ReserveItem();
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'E17-CANCEL', '{"expectedCount":2}');
        Assert.AreEqual('ConfirmationMismatch', Caller.GetText(Response, 'code'), 'Refuse the wrong count.');
        AssertReservation(true);
    end;

    /// <summary>Confirmed cancellation deletes once and a retry reports no change.</summary>
    [Test]
    procedure Scenario_AC01_CancelConfirmed_RetryIsNoOp()
    var
        Log: Record "Legacy Cancellation Log";
        Response: JsonObject;
    begin
        // Story #17, AC01 | Time: none | Risk: repeat safety and log cardinality.
        SetConfirmationRequired(true);
        ReserveItem();
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'E17-CANCEL', '{"expectedCount":1}');
        Caller.AssertOk(Response);
        Assert.IsTrue(Caller.GetBoolean(Response, 'cancelled'), 'The reservation must be cancelled.');
        AssertReservation(false);
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'E17-CANCEL', '{"expectedCount":1}');
        Caller.AssertOk(Response);
        Assert.IsFalse(Caller.GetBoolean(Response, 'cancelled'), 'Retry must be a no-op.');
        Log.SetRange("Item No.", 'E17-CANCEL');
        Assert.RecordCount(Log, 1);
    end;

    /// <summary>Ordinary reservation writes do not acquire an irreversible confirmation requirement.</summary>
    [Test]
    procedure Scenario_AC01_ReserveWrite_DoesNotRequireConfirmation()
    begin
        // Story #17, AC01 | Time: none | Risk: accidental effect weakening or strengthening.
        SetConfirmationRequired(true);
        ReserveItem();
        AssertReservation(true);
        Assert.IsTrue(Caller.GetContractChapter(Enum::"Message Type ori"::"Legacy.Stock.Reserve", 'effect').Contains('"write"'), 'Reserve remains a write.');
    end;

    /// <summary>Price confirmation counts two selected items, excludes blocked items and performs no writes.</summary>
    [Test]
    procedure Scenario_AC02_PricePreview_CountsNonblockedItems()
    var
        Response: JsonObject;
    begin
        // Story #17, AC02 | Time: none | Risk: count must match the real selection.
        SetConfirmationRequired(true);
        CreatePriceItems();
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", '', '{"itemCategoryCode":"E17-CATEGORY","percent":10,"expectedItemCount":2}');
        Assert.AreEqual('ConfirmationRequired', Caller.GetText(Response, 'code'), 'Preview before applying.');
        Assert.AreEqual(2, Caller.GetDecimal(Response, 'expected'), 'Count both nonblocked items, not a default one subject.');
        AssertPrice('E17-PRICE1', 100);
        AssertPrice('E17-PRICE2', 100);
        AssertPrice('E17-BLOCKED', 100);
    end;

    /// <summary>Both confirmation guards protect prices and a valid count applies the change.</summary>
    [Test]
    procedure Scenario_AC02_PriceCounts_RejectMismatchThenApply()
    var
        Response: JsonObject;
    begin
        // Story #17, AC02 | Time: none | Risk: existing expectedItemCount contract must remain enforced.
        SetConfirmationRequired(true);
        CreatePriceItems();
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", '', '{"itemCategoryCode":"E17-CATEGORY","percent":10,"expectedItemCount":2,"expectedCount":1}');
        Assert.AreEqual('ConfirmationMismatch', Caller.GetText(Response, 'code'), 'Foundation must use the item count.');
        AssertPrice('E17-PRICE1', 100);
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", '', '{"itemCategoryCode":"E17-CATEGORY","percent":10,"expectedItemCount":1,"expectedCount":2}');
        Caller.AssertErrorAnswer(Response, 'selection changed');
        AssertPrice('E17-PRICE1', 100);
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", '', '{"itemCategoryCode":"E17-CATEGORY","percent":10,"expectedItemCount":2,"expectedCount":2}');
        Caller.AssertOk(Response);
        Assert.AreEqual(2, Caller.GetDecimal(Response, 'itemCount'), 'Exactly the confirmed items changed.');
        AssertPrice('E17-PRICE1', 110);
        AssertPrice('E17-PRICE2', 110);
        AssertPrice('E17-BLOCKED', 100);
    end;

    /// <summary>An empty category previews and confirms zero without changing any item.</summary>
    [Test]
    procedure Scenario_AC02_EmptyCategory_ConfirmsZero()
    var
        Response: JsonObject;
    begin
        // Story #17, AC02 | Time: none | Risk: zero must not become the default one.
        SetConfirmationRequired(true);
        CreateCategory();
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", '', '{"itemCategoryCode":"E17-CATEGORY","percent":10,"expectedItemCount":0}');
        Assert.AreEqual('ConfirmationRequired', Caller.GetText(Response, 'code'), 'Even an empty selection previews first.');
        Assert.AreEqual(0, Caller.GetDecimal(Response, 'expected'), 'Empty category count.');
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", '', '{"itemCategoryCode":"E17-CATEGORY","percent":10,"expectedItemCount":0,"expectedCount":0}');
        Caller.AssertOk(Response);
        Assert.AreEqual(0, Caller.GetDecimal(Response, 'itemCount'), 'Zero confirmed items.');
    end;

    /// <summary>Invalid confirmation input never reaches price writes.</summary>
    [Test]
    procedure Scenario_AC02_InvalidCount_LeavesPricesUnchanged()
    var
        Response: JsonObject;
    begin
        // Story #17, AC02 | Time: none | Risk: invalid input before any write.
        SetConfirmationRequired(true);
        CreatePriceItems();
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", '', '{"itemCategoryCode":"E17-CATEGORY","percent":10,"expectedItemCount":2,"expectedCount":-1}');
        Caller.AssertErrorAnswer(Response, 'whole number');
        AssertPrice('E17-PRICE1', 100);
    end;

    /// <summary>Contract help names the count and a side-effect-free preview in both supported caller languages.</summary>
    [Test]
    procedure Scenario_AC03_Help_DeclaresUnitsAndPreviewInBothLanguages()
    var
        OriginalLanguage: Integer;
        EffectText: Text;
        ParametersText: Text;
        LanguageId: Integer;
        Languages: List of [Integer];
    begin
        // Story #17, AC03 | Time: none | Risk: Foundation renders contract chapters in English in every locale.
        OriginalLanguage := GlobalLanguage();
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do begin
            GlobalLanguage(LanguageId);
            EffectText := Caller.GetContractChapter(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'effect');
            ParametersText := Caller.GetContractChapter(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'parameters');
            GlobalLanguage(OriginalLanguage);
            Assert.IsTrue(EffectText.Contains('"irreversible"'), 'Cancellation must declare irreversible.');
            Assert.IsTrue(EffectText.Contains('expectedCount counts the one named item (1)'), 'Cancellation effect names its unit.');
            Assert.IsTrue(ParametersText.Contains('read expected without changing data'), 'Cancellation parameter explains preview.');
            GlobalLanguage(LanguageId);
            EffectText := Caller.GetContractChapter(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", 'effect');
            ParametersText := Caller.GetContractChapter(Enum::"Message Type ori"::"Reference.ItemPrice.ApplyAdjustment", 'parameters');
            GlobalLanguage(OriginalLanguage);
            Assert.IsTrue(EffectText.Contains('expectedCount counts nonblocked Item records'), 'Price effect names its unit.');
            Assert.IsTrue(ParametersText.Contains('read expected without changing prices'), 'Price parameter explains preview.');
            Assert.IsTrue(ParametersText.Contains('expectedItemCount and expectedCount'), 'Both guards are explained.');
        end;
    end;

    /// <summary>Administrator opt-out preserves ordinary execution; supplied counts remain checked.</summary>
    [Test]
    procedure Scenario_AC01_ConfirmationDisabled_StillChecksSuppliedCounts()
    var
        Response: JsonObject;
    begin
        // Story #17, AC01 | Time: none | Risk: preserve Foundation's per-company confirmation setting.
        SetConfirmationRequired(false);
        ReserveItem();
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'E17-CANCEL', '{"expectedCount":2}');
        Assert.AreEqual('ConfirmationMismatch', Caller.GetText(Response, 'code'), 'Opt-out does not bypass a supplied count.');
        AssertReservation(true);
        Response := Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.CancelReservation", 'E17-CANCEL', '');
        Caller.AssertOk(Response);
        Assert.IsTrue(Caller.GetBoolean(Response, 'cancelled'), 'Opt-out permits execution without a count.');
    end;

    local procedure SetConfirmationRequired(Required: Boolean)
    var
        SetupPage: TestPage "Setup ori";
    begin
        // Exercise the public setup page; the underlying field is intentionally internal.
        SetupPage.OpenEdit();
        SetupPage."Require Irreversible Confirm".SetValue(Required);
        SetupPage.Close();
    end;

    local procedure ReserveItem()
    begin
        CreateItem('E17-CANCEL', '', false);
        Caller.AssertOk(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Reserve", 'E17-CANCEL', '{"quantity":2,"allowOverStock":true}'));
    end;

    local procedure AssertReservation(Expected: Boolean)
    begin
        Assert.AreEqual(Expected, Caller.GetBoolean(Caller.Call(Enum::"Message Type ori"::"Legacy.Stock.Get", 'E17-CANCEL', ''), 'hasReservation'), 'Reservation state.');
    end;

    local procedure CreateCategory()
    var
        ItemCategory: Record "Item Category";
    begin
        ItemCategory.Init();
        ItemCategory.Code := 'E17-CATEGORY';
        ItemCategory.Insert(true);
    end;

    local procedure CreatePriceItems()
    begin
        CreateCategory();
        CreateItem('E17-PRICE1', 'E17-CATEGORY', false);
        CreateItem('E17-PRICE2', 'E17-CATEGORY', false);
        CreateItem('E17-BLOCKED', 'E17-CATEGORY', true);
    end;

    local procedure CreateItem(ItemNo: Code[20]; Category: Code[20]; Blocked: Boolean)
    var
        Item: Record Item;
    begin
        Item.Init();
        Item."No." := ItemNo;
        Item."Item Category Code" := Category;
        Item."Unit Price" := 100;
        Item.Blocked := Blocked;
        Item.Insert(true);
    end;

    local procedure AssertPrice(ItemNo: Code[20]; Expected: Decimal)
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        Assert.AreEqual(Expected, Item."Unit Price", 'Unit price on ' + ItemNo);
    end;
}
