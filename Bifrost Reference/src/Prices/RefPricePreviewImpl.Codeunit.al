namespace Origo.Bifrost.Reference;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Reference.ItemPrice.PreviewAdjustment - the read-only half of a preview/apply pair.
/// Returns exactly what Reference.ItemPrice.ApplyAdjustment would do, without writing.
/// </summary>
codeunit 90017 "Ref Price Preview Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'preview price change, what if prices go up, simulate price increase, price adjustment preview, show new prices for a category', Comment = 'is-IS=forskoða verðbreytingu, hvað ef verð hækkar, herma eftir verðhækkun, forskoðun verðbreytingar, sýna nýtt verð í flokki';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'See what a percentage change would do to the unit prices of every item in one item category, without changing anything. To make the change, use Reference.ItemPrice.ApplyAdjustment with this answer''s itemCount.', Comment = 'is-IS=Sjá hvað prósentubreyting myndi gera við einingarverð allra vara í einum vöruflokki, án þess að breyta neinu. Til að gera breytinguna, notaðu Reference.ItemPrice.ApplyAdjustment með itemCount úr þessu svari.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: shared parts come from Ref Price Contract ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Shows what a percentage change to the unit price would do to every item in one item category (blocked items excluded): current price, new price and totals. Read-only. Show the user the result before Reference.ItemPrice.ApplyAdjustment.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Ref Price Contract";
    begin
        Envelope := Parts.Envelope();
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Ref Price Contract";
    begin
        Target := Parts.Target();
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Ref Price Contract";
    begin
        Parts.AddParameters(Parameters, false);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Ref Price Contract";
    begin
        Response := Parts.Response();
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Ref Price Contract";
    begin
        Parts.AddErrors(Errors, false);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can read Item.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Reference.ItemPrice.ApplyAdjustment', 'The user agrees: make the change shown here.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Ref Price Contract";
    begin
        Workflow := Parts.Workflow();
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('What would +5 % do to chairs',
            '{"type":"Reference.ItemPrice.PreviewAdjustment","data":{"itemCategoryCode":"STÓLL","percent":5}}',
            '{"itemCategoryCode":"STÓLL","percent":5,"itemCount":4,"applied":false,"totalCurrentUnitPrice":50280,"totalNewUnitPrice":52794,"itemsTruncated":false,"items":[{"itemNo":"1900-S","description":"PARIS Guest Chair, black","currentUnitPrice":12570,"newUnitPrice":13198.5}]}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: the same call gives the same result until prices or the items in the category change. The numbers are exactly what the apply call would write, because both use the same calculation.';
        exit(true);
    end;
}
