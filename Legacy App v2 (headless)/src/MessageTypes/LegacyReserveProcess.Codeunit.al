namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Isolated call into Legacy App's facade for Legacy.Stock.Reserve. Any Error() the facade
/// raises (unknown item, blocked item, bad quantity, over stock) rolls back here and is answered
/// by the Impl as status = Error with the facade's own - already actionable - text.
/// </summary>
codeunit 90103 "Legacy Reserve Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        ItemNo: Code[20];
        Quantity: Decimal;
        AllowOverStock: Boolean;

    trigger OnRun()
    var
        LegacyStockAPI: Codeunit "Legacy Stock API";
        ResponseJson: JsonObject;
        NewTotal: Decimal;
    begin
        NewTotal := LegacyStockAPI.Reserve(ItemNo, Quantity, AllowOverStock);
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('quantityAdded', Quantity);
        ResponseJson.Add('totalReserved', NewTotal);
        ResponseJson.Add('availableToReserve', LegacyStockAPI.GetAvailableToReserve(ItemNo));
        Rec.SetResponseJson(ResponseJson);
    end;

    procedure SetReservation(NewItemNo: Code[20]; NewQuantity: Decimal; NewAllowOverStock: Boolean)
    begin
        ItemNo := NewItemNo;
        Quantity := NewQuantity;
        AllowOverStock := NewAllowOverStock;
    end;
}
