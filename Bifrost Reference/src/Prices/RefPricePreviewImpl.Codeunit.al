namespace Origo.Bifrost.Reference;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Reference.ItemPrice.PreviewAdjustment - the read-only half of a preview/apply pair.
/// Returns exactly what Reference.ItemPrice.ApplyAdjustment would do, without writing.
/// </summary>
codeunit 90017 "Ref Price Preview Impl" implements "Msg Interface ori", "Msg Contract ori"
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


    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Clear(Parameters);
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        exit(false);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Help: Codeunit "Ref Price Help";
    begin
        Overview := Help.GetPreviewHelp();
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
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
