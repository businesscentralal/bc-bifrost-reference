namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.Get - the read sibling. Without it an agent cannot check the state before or
/// after Reserve/CancelReservation, and would have to guess.
/// </summary>
codeunit 90105 "Legacy Stock Get Impl" implements "Msg Interface ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        exit(Reservation.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Legacy Stock Reservation");
    end;

    procedure GetDescription(): Text[250]
    begin
        // Selection card phrased the way users ask ("how much is reserved for item X"): the live
        // search missed the first wording, which only said "Get the reserved quantity".
        exit('How much stock is reserved for an item in Legacy App, and how much can still be reserved. Read-only. For all items use Legacy.Stock.List; to change it use Legacy.Stock.Reserve or Legacy.Stock.CancelReservation.');
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
        Help: Codeunit "Legacy Adapter Help";
    begin
        Overview := Help.GetGetHelp();
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Legacy Adapter Help";
    begin
        Argument.SetResponseMarkdown(Help.GetGetHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AdapterInput: Codeunit "Legacy Adapter Input";
        LegacyStockAPI: Codeunit "Legacy Stock API";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNo: Code[20];
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not AdapterInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not AdapterInput.GetItemNo(Argument, RequestJson, ItemNo) then
            exit;

        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('hasReservation', LegacyStockAPI.HasReservation(ItemNo));
        ResponseJson.Add('reservedQuantity', LegacyStockAPI.GetReservedQuantity(ItemNo));
        ResponseJson.Add('availableToReserve', LegacyStockAPI.GetAvailableToReserve(ItemNo));
        Argument.SetResponseJson(ResponseJson);
    end;
}
