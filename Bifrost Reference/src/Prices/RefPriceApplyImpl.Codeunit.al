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
codeunit 90018 "Ref Price Apply Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'change item prices, apply the price change, raise prices for a category, lower prices for a category, update unit prices, increase prices by percent', Comment = 'is-IS=breyta vöruverði, beita verðbreytingu, hækka verð í flokki, lækka verð í flokki, uppfæra einingarverð, hækka verð um prósentu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Change the unit prices of every item in one item category by a percentage, after the user has seen the preview. Needs the preview''s itemCount. To see the effect first, use Reference.ItemPrice.PreviewAdjustment.', Comment = 'is-IS=Breyta einingarverði allra vara í einum vöruflokki um prósentu, eftir að notandinn hefur séð forskoðunina. Þarf itemCount úr forskoðuninni. Til að sjá áhrifin fyrst, notaðu Reference.ItemPrice.PreviewAdjustment.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: shared parts come from Ref Price Contract ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Changes the unit price of every item in one item category (blocked items excluded) by a percentage. All items change, or on any error none do. Run Reference.ItemPrice.PreviewAdjustment first and show the user the result.';
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
        Parts.AddParameters(Parameters, true);
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
        Parts.AddErrors(Errors, true);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Modifies Unit Price on every item in the category that is not blocked, through the Item table''s own validation. All or nothing. There is no undo type: reversing +10 % with -10 % does not give the original price, because of rounding.');
        Effect.Add('idempotent', false);
        Preconditions.Add('The caller can write Item; without it the type is not offered.');
        Preconditions.Add('A preview was made: expectedItemCount must match the number of items in the category now.');
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
        Related.Add(ContractMgt.RelatedEntry('Reference.ItemPrice.PreviewAdjustment', 'Always call it first, and show the user the result.'));
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
        Examples.Add(ContractMgt.Example('Raise chairs by 5 % after the preview',
            '{"type":"Reference.ItemPrice.ApplyAdjustment","data":{"itemCategoryCode":"STÓLL","percent":5,"expectedItemCount":4}}',
            '{"itemCategoryCode":"STÓLL","percent":5,"itemCount":4,"applied":true,"totalCurrentUnitPrice":50280,"totalNewUnitPrice":52794,"itemsTruncated":false,"items":[{"itemNo":"1900-S","description":"PARIS Guest Chair, black","currentUnitPrice":12570,"newUnitPrice":13198.5}]}'));
        Examples.Add(ContractMgt.Example('The category changed after the preview',
            '{"type":"Reference.ItemPrice.ApplyAdjustment","data":{"itemCategoryCode":"STÓLL","percent":5,"expectedItemCount":4}}',
            '{"status":"Error","error":"The selection changed since the preview: expected 4 items in category ''STÓLL'', found 5. Run Reference.ItemPrice.PreviewAdjustment again and send its itemCount as expectedItemCount."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Repeat has an effect: a second identical call changes the prices again (+5 % twice is about +10.25 %), because the item count is still the same. When unsure whether an earlier call went through, run the preview and compare currentUnitPrice with the prices seen before. The Item table''s own OnValidate and OnModify logic runs for Unit Price, exactly as when a user edits it.';
        exit(true);
    end;
}
