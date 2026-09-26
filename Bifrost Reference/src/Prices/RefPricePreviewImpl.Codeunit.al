namespace Origo.Bifrost.Reference;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Reference.ItemPrice.PreviewAdjustment - the read-only half of a preview/apply pair.
/// Returns exactly what Reference.ItemPrice.ApplyAdjustment would do, without writing.
/// </summary>
codeunit 90017 "Ref Price Preview Impl" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Preview a percentage change to the unit prices of all items in one item category: current and new price per item. Read-only; nothing changes. To apply it use Reference.ItemPrice.ApplyAdjustment.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref Price Help";
    begin
        Argument.SetResponseMarkdown(Help.GetPreviewHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RefInput: Codeunit "Ref Input";
        PriceAdjust: Codeunit "Ref Price Adjust";
        RequestJson: JsonObject;
        ItemCategoryCode: Code[20];
        Percent: Decimal;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not PriceAdjust.ReadAdjustment(Argument, RequestJson, ItemCategoryCode, Percent) then
            exit;
        Argument.SetResponseJson(PriceAdjust.BuildAndOptionallyApply(ItemCategoryCode, Percent, false));
    end;
}
