namespace Origo.Bifrost.Reference;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Reference.ItemPrice.ApplyAdjustment - the committing half of the pair.
///
/// It refuses to run unless the caller sends back the itemCount from the preview as
/// expectedItemCount. That one number is a cheap but effective guard: an agent cannot apply
/// a bulk change it never previewed, and a change is refused when the selection moved.
/// </summary>
codeunit 90018 "Ref Price Apply Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        SelectionChangedErr: Label 'The selection changed since the preview: expected %1 items in category ''%2'', found %3. Run Reference.ItemPrice.PreviewAdjustment again and send its itemCount as expectedItemCount.', Comment = '%1 = expected count, %2 = item category, %3 = actual count, is-IS=Valið hefur breyst frá forskoðun: búist var við %1 vörum í flokknum ''%2'' en þær eru %3. Keyrðu Reference.ItemPrice.PreviewAdjustment aftur og sendu itemCount sem expectedItemCount.';

    procedure IsEnabled(): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Change the unit prices of all items in one item category by a percentage. Commits. Run Reference.ItemPrice.PreviewAdjustment first and send its itemCount back as expectedItemCount.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref Price Help";
    begin
        Argument.SetResponseMarkdown(Help.GetApplyHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RefInput: Codeunit "Ref Input";
        PriceAdjust: Codeunit "Ref Price Adjust";
        ApplyProcess: Codeunit "Ref Price Apply Process";
        RequestJson: JsonObject;
        ItemCategoryCode: Code[20];
        Percent: Decimal;
        ExpectedItemCount: Integer;
        ActualItemCount: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not PriceAdjust.ReadAdjustment(Argument, RequestJson, ItemCategoryCode, Percent) then
            exit;
        if not RefInput.GetRequiredInteger(Argument, RequestJson, 'expectedItemCount', 0, 100000, ExpectedItemCount) then
            exit;
        ActualItemCount := PriceAdjust.CountItems(ItemCategoryCode);
        if ActualItemCount <> ExpectedItemCount then begin
            Argument.RespondWithError(StrSubstNo(SelectionChangedErr, ExpectedItemCount, ItemCategoryCode, ActualItemCount));
            exit;
        end;

        ApplyProcess.SetAdjustment(ItemCategoryCode, Percent);
        if Argument."Omit Commit" then
            ApplyProcess.Run(Argument)
        else
            if not ApplyProcess.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
