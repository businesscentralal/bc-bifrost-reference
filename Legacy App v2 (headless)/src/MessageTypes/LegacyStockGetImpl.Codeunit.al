namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.Get - the read sibling. Without it an agent cannot check the state before or
/// after Reserve/CancelReservation, and would have to guess.
/// </summary>
codeunit 90105 "Legacy Stock Get Impl" implements "Msg Interface ori"
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
