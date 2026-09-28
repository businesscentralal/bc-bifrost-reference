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
        PriceAdjust: Codeunit "Ref Price Adjust";
    begin
        Rec.SetResponseJson(PriceAdjust.BuildAndOptionallyApply(ItemCategoryCode, Percent, true));
    end;

    procedure SetAdjustment(NewItemCategoryCode: Code[20]; NewPercent: Decimal)
    begin
        ItemCategoryCode := NewItemCategoryCode;
        Percent := NewPercent;
    end;
}
