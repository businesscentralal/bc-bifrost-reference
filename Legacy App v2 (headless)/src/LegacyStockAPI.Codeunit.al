namespace Origo.Bifrost.Reference.Legacy;

using Microsoft.Inventory.Item;

/// <summary>
/// The HEADLESS FACADE of Legacy App - scenario "make my app callable by other apps".
///
/// This codeunit knows nothing about Bifröst. It is the public, UI-free API of the app's
/// business logic, and every caller uses it: the app's own pages (after they have asked the
/// user), other extensions, and the Bifröst adapter app. Rules it follows:
///  - no UI: no Confirm, Message, StrMenu, Page.Run, progress windows - deciding is the caller's job;
///  - no Commit: the caller owns the transaction, so every operation is all or nothing;
///  - no GuiAllowed: every caller gets the same rules, and a decision a person used to make is a
///    parameter (AllowOverStock);
///  - every precondition is checked up front and fails with a translatable error that says
///    what is wrong AND what to do - callers may show it to a person or return it to an agent;
///  - outcomes are returned, not hidden: the new total, whether anything was cancelled, how many
///    rows were released;
///  - read procedures let callers (and pages) check before they act;
///  - OnBefore/OnAfter events let other apps extend it without changing it.
/// Each fix of a v1 problem is marked "FIXED 7.2 - [pattern]" (START-HERE.md §7.2).
/// </summary>
codeunit 90052 "Legacy Stock API"
{
    Access = Public;

    var
        ItemNoMissingErr: Label 'An item number is required. Send the number of an existing item, for example 1896-S.', Comment = 'is-IS=Vörunúmer vantar. Sendu númer vöru sem er til, til dæmis 1896-S.';
        ItemNotFoundErr: Label 'Item ''%1'' does not exist. Check the number, or find the item with Data.Records.Get on table Item.', Comment = '%1 = item no., is-IS=Varan ''%1'' er ekki til. Athugaðu númerið eða finndu vöruna með Data.Records.Get á töflunni Item.';
        ItemBlockedErr: Label 'Item ''%1'' is blocked, so stock cannot be reserved for it. Unblock the item or choose another.', Comment = '%1 = item no., is-IS=Varan ''%1'' er lokuð og því er ekki hægt að taka frá birgðir fyrir hana. Opnaðu vöruna eða veldu aðra.';
        QuantityErr: Label 'The quantity to reserve is %1. Send a quantity greater than zero; to remove a reservation, cancel it instead.', Comment = '%1 = quantity, is-IS=Magnið sem á að taka frá er %1. Sendu magn sem er stærra en núll; til að fjarlægja frátekningu skaltu hætta við hana.';
        OverStockErr: Label 'Item ''%1'' has %2 in inventory and %3 already reserved, so reserving %4 more would reserve more than is in stock. Reserve at most %5, or explicitly allow over-reservation.', Comment = '%1 = item no., %2 = inventory, %3 = already reserved, %4 = quantity asked, %5 = available, is-IS=Varan ''%1'' á %2 á lager og %3 eru þegar frátekin, svo ef %4 væru tekin frá til viðbótar væri tekið frá meira en er til. Taktu frá að hámarki %5 eða leyfðu umframfrátekningu sérstaklega.';

    /// <summary>
    /// Reserves Quantity of ItemNo, adding to an existing reservation. Refuses to reserve more than
    /// the inventory - the same rule for every caller.
    /// </summary>
    /// <returns>The item's total reserved quantity after this call.</returns>
    procedure Reserve(ItemNo: Code[20]; Quantity: Decimal) NewTotal: Decimal
    begin
        exit(Reserve(ItemNo, Quantity, false));
    end;

    /// <summary>
    /// Reserves Quantity of ItemNo, adding to an existing reservation.
    /// </summary>
    /// <param name="AllowOverStock">True to allow a total above the inventory. In v1 a person made
    /// this decision in a dialog; here it is the caller's explicit choice.</param>
    /// <returns>The item's total reserved quantity after this call.</returns>
    procedure Reserve(ItemNo: Code[20]; Quantity: Decimal; AllowOverStock: Boolean) NewTotal: Decimal
    var
        Reservation: Record "Legacy Stock Reservation";
        IsHandled: Boolean;
    begin
        CheckItem(ItemNo);
        if Quantity <= 0 then
            Error(QuantityErr, Format(Quantity, 0, 9));

        // Lock before the stock check, so two callers at once cannot both pass it.
        Reservation.LockTable();

        // FIXED 7.2 - GuiAllowed branch: the stock check runs for every caller. The decision a
        // person used to make in a Confirm is the AllowOverStock parameter.
        if not AllowOverStock then
            CheckInventory(ItemNo, Quantity);

        OnBeforeReserve(ItemNo, Quantity, IsHandled);
        if IsHandled then
            exit(GetReservedQuantity(ItemNo));

        if Reservation.Get(ItemNo) then begin
            Reservation.Quantity += Quantity;
            Reservation.Modify(true);
        end else begin
            Reservation.Init();
            Reservation."Item No." := ItemNo;
            Reservation.Quantity := Quantity;
            Reservation.Insert(true);
        end;
        NewTotal := Reservation.Quantity;

        OnAfterReserve(ItemNo, Quantity, NewTotal);
    end;

    /// <summary>
    /// Cancels the whole reservation for ItemNo and logs the cancellation - both writes in one
    /// transaction, no Commit in between.
    /// </summary>
    /// <returns>True when a reservation was cancelled; false when the item had none (nothing written).</returns>
    procedure CancelReservation(ItemNo: Code[20]) Cancelled: Boolean
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        if ItemNo = '' then
            Error(ItemNoMissingErr);
        // FIXED 7.2 - Silent failure: "nothing to cancel" is returned as false, not hidden.
        if not Reservation.Get(ItemNo) then
            exit(false);
        // FIXED 7.2 - Commit: the delete and the log are one transaction.
        ReleaseOne(Reservation);

        OnAfterCancelReservation(ItemNo);
        exit(true);
    end;

    /// <summary>
    /// Releases every reservation whose item number matches ItemFilter and logs each one, all in
    /// one transaction: either every matching row is released or, on any error, none is.
    /// </summary>
    /// <param name="ItemFilter">A filter on Item No., for example '1896-S|1900-S' or '19*'.
    /// An empty filter matches every reservation.</param>
    /// <returns>The number of reservations released; 0 when nothing matched (nothing written).</returns>
    procedure ReleaseReservations(ItemFilter: Text) Released: Integer
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        // FIXED 7.2 - Unbounded work: the caller says which rows; a caller that means all sends
        // an empty filter on purpose.
        // FIXED 7.2 - Dialogs: no progress window; the page may show one around this call.
        // FIXED 7.2 - Commit and swallowed errors: no Commit per row and no "if Codeunit.Run" -
        // an error in any row rolls back every row, and its text reaches the caller.
        Reservation.LockTable();
        Reservation.SetFilter("Item No.", ItemFilter);
        if Reservation.FindSet() then
            repeat
                ReleaseOne(Reservation);
                Released += 1;
            until Reservation.Next() = 0;

        // FIXED 7.2 - Silent failure: the count is the outcome, 0 included.
        OnAfterReleaseReservations(ItemFilter, Released);
    end;

    /// <summary>
    /// The number of reservations matching ItemFilter (empty = all). Lets a caller see what
    /// ReleaseReservations would touch before calling it.
    /// </summary>
    procedure CountReservations(ItemFilter: Text): Integer
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        Reservation.SetFilter("Item No.", ItemFilter);
        exit(Reservation.Count());
    end;

    /// <summary>
    /// The item's reserved quantity; 0 when it has no reservation.
    /// </summary>
    procedure GetReservedQuantity(ItemNo: Code[20]): Decimal
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        Reservation.SetLoadFields(Quantity);
        if Reservation.Get(ItemNo) then
            exit(Reservation.Quantity);
        exit(0);
    end;

    /// <summary>
    /// The item's inventory minus what is already reserved. Can be negative when an earlier
    /// reservation was allowed over stock. 0 for an unknown item.
    /// </summary>
    procedure GetAvailableToReserve(ItemNo: Code[20]): Decimal
    var
        Item: Record Item;
    begin
        Item.SetLoadFields("No.");
        if not Item.Get(ItemNo) then
            exit(0);
        Item.CalcFields(Inventory);
        exit(Item.Inventory - GetReservedQuantity(ItemNo));
    end;

    /// <summary>
    /// Whether reserving Quantity more of ItemNo would take the total above the inventory.
    /// Pages call it to decide whether to ask the person; the facade itself never asks.
    /// </summary>
    procedure WouldExceedInventory(ItemNo: Code[20]; Quantity: Decimal): Boolean
    begin
        exit(Quantity > GetAvailableToReserve(ItemNo));
    end;

    /// <summary>
    /// Whether Reserve would accept this item (it exists and is not blocked). Lets callers that
    /// want a Boolean contract check first instead of catching an error.
    /// </summary>
    procedure IsReservable(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
    begin
        if ItemNo = '' then
            exit(false);
        Item.SetLoadFields("No.", Blocked);
        if not Item.Get(ItemNo) then
            exit(false);
        exit(not Item.Blocked);
    end;

    /// <summary>
    /// Whether the item has a reservation.
    /// </summary>
    procedure HasReservation(ItemNo: Code[20]): Boolean
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        Reservation.SetLoadFields("Item No.");
        exit(Reservation.Get(ItemNo));
    end;

    local procedure ReleaseOne(var Reservation: Record "Legacy Stock Reservation")
    var
        Log: Record "Legacy Cancellation Log";
        ItemNo: Code[20];
    begin
        ItemNo := Reservation."Item No.";
        Reservation.Delete(true);

        Log.Init();
        Log."Item No." := ItemNo;
        Log."Cancelled At" := CurrentDateTime();
        Log.Insert(true);
    end;

    local procedure CheckItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if ItemNo = '' then
            Error(ItemNoMissingErr);
        Item.SetLoadFields("No.", Blocked);
        if not Item.Get(ItemNo) then
            Error(ItemNotFoundErr, ItemNo);
        if Item.Blocked then
            Error(ItemBlockedErr, ItemNo);
    end;

    local procedure CheckInventory(ItemNo: Code[20]; Quantity: Decimal)
    var
        Item: Record Item;
        Reserved: Decimal;
        Available: Decimal;
    begin
        Item.SetLoadFields("No.");
        Item.Get(ItemNo);
        Item.CalcFields(Inventory);
        Reserved := GetReservedQuantity(ItemNo);
        Available := Item.Inventory - Reserved;
        if Quantity > Available then begin
            if Available < 0 then
                Available := 0;
            Error(OverStockErr, ItemNo, Format(Item.Inventory, 0, 9), Format(Reserved, 0, 9), Format(Quantity, 0, 9), Format(Available, 0, 9));
        end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeReserve(ItemNo: Code[20]; Quantity: Decimal; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterReserve(ItemNo: Code[20]; Quantity: Decimal; NewTotal: Decimal)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCancelReservation(ItemNo: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterReleaseReservations(ItemFilter: Text; Released: Integer)
    begin
    end;
}
