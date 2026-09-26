namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost;
using Origo.Bifrost.Reference.Legacy;

/// <summary>
/// Isolated call into Legacy App's facade for Legacy.Stock.CancelReservation. The facade's
/// Boolean result is passed on as "cancelled", so "nothing to cancel" is never a silent success.
/// </summary>
codeunit 90104 "Legacy Cancel Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        ItemNo: Code[20];

    trigger OnRun()
    var
        LegacyStockAPI: Codeunit "Legacy Stock API";
        ResponseJson: JsonObject;
    begin
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('cancelled', LegacyStockAPI.CancelReservation(ItemNo));
        Rec.SetResponseJson(ResponseJson);
    end;

    procedure SetItem(NewItemNo: Code[20])
    begin
        ItemNo := NewItemNo;
    end;
}
