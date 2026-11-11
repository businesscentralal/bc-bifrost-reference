namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Isolated write for Reference.ItemPrice.ApplyAdjustment. Either every item in the selection
/// gets its new price, or - on any error - none does.
/// </summary>
codeunit 90019 "Ref Price Apply Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        ItemCategoryCode: Code[20];
        Percent: Decimal;

    trigger OnRun()
    var
        RefInput: Codeunit "Ref Input";
        PriceAdjust: Codeunit "Ref Price Adjust";
    begin
        RefInput.SetSuccess(Rec, PriceAdjust.BuildAndOptionallyApply(ItemCategoryCode, Percent, true));
    end;

    procedure SetAdjustment(NewItemCategoryCode: Code[20]; NewPercent: Decimal)
    begin
        ItemCategoryCode := NewItemCategoryCode;
        Percent := NewPercent;
    end;
}
