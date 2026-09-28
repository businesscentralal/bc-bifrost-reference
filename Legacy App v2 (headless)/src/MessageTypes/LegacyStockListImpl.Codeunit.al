namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.List - the read that goes with Legacy.Stock.ReleaseAll, the way a preview goes
/// with an apply. It returns the count that ReleaseAll requires as expectedCount, so a caller
/// always sees what a bulk change will touch before making it.
/// Bounded on purpose: at most 100 rows are returned, and "more" says when there are others.
/// </summary>
codeunit 90108 "Legacy Stock List Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        FilterErr: Label 'Parameter ''itemFilter'' is ''%1'', which is not a valid filter: %2 Send an item number or a filter such as 1896-S|1900-S or 19*.', Comment = '%1 = filter received, %2 = platform error text, is-IS=Færibreytan ''itemFilter'' er ''%1'', sem er ekki gild sía: %2 Sendu vörunúmer eða síu eins og 1896-S|1900-S eða 19*.';
        MaxRows: Integer;

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
        exit('List stock reservations in Legacy App, all or by item filter, with count and total quantity (max 100 rows). Read-only. Gives the expectedCount for Legacy.Stock.ReleaseAll. For one item use Legacy.Stock.Get.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Legacy Adapter Help";
    begin
        Argument.SetResponseMarkdown(Help.GetListHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Reservation: Record "Legacy Stock Reservation";
        AdapterInput: Codeunit "Legacy Adapter Input";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        ItemFilter: Text;
        TotalQuantity: Decimal;
        Returned: Integer;
        ReservationCount: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        MaxRows := 100;
        Returned := 0;

        if not AdapterInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not AdapterInput.GetText(Argument, RequestJson, 'itemFilter', false, 250, '"1896-S|1900-S"', ItemFilter) then
            exit;
        if not TryApplyFilter(Reservation, ItemFilter) then begin
            Argument.RespondWithError(StrSubstNo(FilterErr, ItemFilter, GetLastErrorText()));
            exit;
        end;

        // Totals from the database, rows capped: the call costs the same for 10 rows or 10,000.
        ReservationCount := Reservation.Count();
        Reservation.CalcSums(Quantity);
        TotalQuantity := Reservation.Quantity;

        Reservation.SetLoadFields("Item No.", Quantity);
        if Reservation.FindSet() then
            repeat
                Clear(Row);
                Row.Add('itemNo', Reservation."Item No.");
                Row.Add('quantity', Reservation.Quantity);
                Rows.Add(Row);
                Returned += 1;
            until (Reservation.Next() = 0) or (Returned >= MaxRows);

        ResponseJson.Add('itemFilter', ItemFilter);
        ResponseJson.Add('count', ReservationCount);
        ResponseJson.Add('totalQuantity', TotalQuantity);
        ResponseJson.Add('returned', Returned);
        ResponseJson.Add('more', ReservationCount > Returned);
        ResponseJson.Add('reservations', Rows);
        Argument.SetResponseJson(ResponseJson);
    end;

    [TryFunction]
    local procedure TryApplyFilter(var Reservation: Record "Legacy Stock Reservation"; ItemFilter: Text)
    begin
        // Read-only: a try function is the right tool here - it writes nothing.
        Reservation.SetFilter("Item No.", ItemFilter);
        // Touch the database once, so an invalid filter fails here and not later.
        if Reservation.IsEmpty() then
            exit;
    end;
}
