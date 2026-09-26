namespace Origo.Bifrost.Reference;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Shared logic for the Reference.ItemPrice.PreviewAdjustment / ApplyAdjustment pair.
///
/// The pair shows how to make an irreversible bulk change safe for an agent:
///  - one codeunit computes the change, so preview and apply can never disagree;
///  - preview is read-only and returns exactly what apply would do;
///  - apply requires the preview's itemCount back (expectedItemCount), so it refuses to run
///    when the selection changed in between - or when the caller skipped the preview.
/// </summary>
codeunit 90016 "Ref Price Adjust"
{
    Access = Internal;

    var
        CategoryNotFoundErr: Label 'Item category ''%1'' was not found. Check the code, or list categories with Data.Records.Get on table Item Category.', Comment = '%1 = item category code, is-IS=Vöruflokkurinn ''%1'' fannst ekki. Athugaðu kóðann eða skoðaðu flokka með Data.Records.Get á töflunni Item Category.';
        ZeroPercentErr: Label 'Parameter ''percent'' is 0, which would change nothing. Send the change in percent, for example 5 for +5 % or -10 for -10 %.', Comment = 'is-IS=Færibreytan ''percent'' er 0, sem breytir engu. Sendu breytinguna í prósentum, t.d. 5 fyrir +5 % eða -10 fyrir -10 %.';
        MaxItems: Integer;

    /// <summary>
    /// Reads and validates itemCategoryCode and percent. Answers the caller and returns false on any problem.
    /// </summary>
    procedure ReadAdjustment(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var ItemCategoryCode: Code[20]; var Percent: Decimal): Boolean
    var
        ItemCategory: Record "Item Category";
        RefInput: Codeunit "Ref Input";
        CategoryText: Text;
    begin
        if not RefInput.GetRequiredText(Argument, RequestJson, 'itemCategoryCode', MaxStrLen(ItemCategory.Code), '"STÓLL"', CategoryText) then
            exit(false);
        ItemCategoryCode := CopyStr(UpperCase(CategoryText), 1, MaxStrLen(ItemCategoryCode));
        ItemCategory.SetLoadFields(Code);
        if not ItemCategory.Get(ItemCategoryCode) then begin
            Argument.RespondWithError(StrSubstNo(CategoryNotFoundErr, CategoryText));
            exit(false);
        end;
        if not RefInput.GetRequiredDecimal(Argument, RequestJson, 'percent', -50, 100, Percent) then
            exit(false);
        if Percent = 0 then begin
            Argument.RespondWithError(ZeroPercentErr);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Selects the items the adjustment applies to: every item in the category that is not blocked.
    /// </summary>
    procedure SelectItems(var Item: Record Item; ItemCategoryCode: Code[20])
    begin
        Item.SetRange("Item Category Code", ItemCategoryCode);
        Item.SetRange(Blocked, false);
    end;

    /// <summary>
    /// The new unit price, rounded with the unit-amount rounding precision from General Ledger Setup.
    /// </summary>
    procedure NewUnitPrice(CurrentPrice: Decimal; Percent: Decimal; Precision: Decimal): Decimal
    begin
        exit(Round(CurrentPrice * (100 + Percent) / 100, Precision));
    end;

    local procedure GetRoundingPrecision(): Decimal
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
    begin
        GeneralLedgerSetup.SetLoadFields("Unit-Amount Rounding Precision");
        if GeneralLedgerSetup.Get() then
            if GeneralLedgerSetup."Unit-Amount Rounding Precision" <> 0 then
                exit(GeneralLedgerSetup."Unit-Amount Rounding Precision");
        exit(0.01);
    end;

    /// <summary>
    /// Builds the response both types return: the selection and, per item, current and new price.
    /// When Apply is true the new prices are also written (only called from the apply process).
    /// </summary>
    procedure BuildAndOptionallyApply(ItemCategoryCode: Code[20]; Percent: Decimal; Apply: Boolean) Response: JsonObject
    var
        Item: Record Item;
        Items: JsonArray;
        Line: JsonObject;
        NewPrice: Decimal;
        TotalCurrent: Decimal;
        TotalNew: Decimal;
        Precision: Decimal;
        ItemCount: Integer;
    begin
        MaxItems := 1000;
        Precision := GetRoundingPrecision();
        // Load only what the preview returns. Apply validates "Unit Price", which reads other
        // fields in its trigger, so it loads the full record.
        if not Apply then
            Item.SetLoadFields("No.", Description, "Unit Price");
        SelectItems(Item, ItemCategoryCode);
        if Item.FindSet(Apply) then
            repeat
                ItemCount += 1;
                NewPrice := NewUnitPrice(Item."Unit Price", Percent, Precision);
                TotalCurrent += Item."Unit Price";
                TotalNew += NewPrice;
                if ItemCount <= MaxItems then begin
                    Clear(Line);
                    Line.Add('itemNo', Item."No.");
                    Line.Add('description', Item.Description);
                    Line.Add('currentUnitPrice', Item."Unit Price");
                    Line.Add('newUnitPrice', NewPrice);
                    Items.Add(Line);
                end;
                if Apply then begin
                    Item.Validate("Unit Price", NewPrice);
                    Item.Modify(true);
                end;
            until Item.Next() = 0;

        Response.Add('itemCategoryCode', ItemCategoryCode);
        Response.Add('percent', Percent);
        Response.Add('itemCount', ItemCount);
        Response.Add('applied', Apply);
        Response.Add('totalCurrentUnitPrice', TotalCurrent);
        Response.Add('totalNewUnitPrice', TotalNew);
        Response.Add('itemsTruncated', ItemCount > MaxItems);
        Response.Add('items', Items);
    end;

    /// <summary>
    /// Counts the items the adjustment would touch right now.
    /// </summary>
    procedure CountItems(ItemCategoryCode: Code[20]): Integer
    var
        Item: Record Item;
    begin
        SelectItems(Item, ItemCategoryCode);
        exit(Item.Count());
    end;
}
