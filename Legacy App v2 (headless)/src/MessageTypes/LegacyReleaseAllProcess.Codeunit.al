namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Isolated run for Legacy.Stock.ReleaseAll: checks the count and releases in one transaction.
/// An invalid filter, a count mismatch or any error inside the facade rolls everything back.
/// </summary>
codeunit 90110 "Legacy Release All Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        ItemFilter: Text;
        ExpectedCount: Integer;
        CountMismatchErr: Label 'itemFilter ''%1'' matches %2 reservations, not the %3 you sent in expectedCount. Nothing was released. Check with Legacy.Stock.List and send its count.', Comment = '%1 = filter, %2 = actual count, %3 = expected count, is-IS=itemFilter ''%1'' passar við %2 frátekningar, ekki %3 eins og þú sendir í expectedCount. Ekkert var losað. Athugaðu með Legacy.Stock.List og sendu fjöldann þaðan.';

    trigger OnRun()
    var
        Reservation: Record "Legacy Stock Reservation";
        LegacyStockAPI: Codeunit "Legacy Stock API";
        ResponseJson: JsonObject;
        ActualCount: Integer;
        Released: Integer;
    begin
        // Lock first, so the count and the release see the same rows.
        Reservation.LockTable();
        ActualCount := LegacyStockAPI.CountReservations(ItemFilter);
        if ActualCount <> ExpectedCount then
            Error(CountMismatchErr, ItemFilter, ActualCount, ExpectedCount);

        Released := LegacyStockAPI.ReleaseReservations(ItemFilter);

        ResponseJson.Add('itemFilter', ItemFilter);
        ResponseJson.Add('released', Released);
        Rec.SetResponseJson(ResponseJson);
    end;

    procedure SetRelease(NewItemFilter: Text; NewExpectedCount: Integer)
    begin
        ItemFilter := NewItemFilter;
        ExpectedCount := NewExpectedCount;
    end;
}
