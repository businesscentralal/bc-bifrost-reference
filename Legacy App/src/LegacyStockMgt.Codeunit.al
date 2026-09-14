namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// Ordinary business logic, written with no awareness of Bifröst. Two procedures,
/// two different shapes on purpose:
///  - ReserveStock: a plain function. No UI, no Commit(). Trivially wrappable.
///  - CancelReservation: interactive (Confirm) and transactionally unsafe (an early
///    Commit() before a second write that can still fail). NOT wrappable as-is -
///    see ADAPTING.md for why, and what has to change here before it can be.
/// </summary>
codeunit 90050 "Legacy Stock Mgt"
{
    /// <summary>
    /// Reserves quantity against an item. No dialogs, no intermediate commit - the whole
    /// operation is one transaction. This is the "easy" case for a Bifröst wrapper.
    /// </summary>
    procedure ReserveStock(ItemNo: Code[20]; Quantity: Decimal): Boolean
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        if Quantity <= 0 then
            exit(false);

        if Reservation.Get(ItemNo) then begin
            Reservation.Quantity += Quantity;
            Reservation.Modify(true);
        end else begin
            Reservation.Init();
            Reservation."Item No." := ItemNo;
            Reservation.Quantity := Quantity;
            Reservation.Insert(true);
        end;
        exit(true);
    end;

    /// <summary>
    /// Cancels a reservation. The original, UI-facing entry point - unchanged in
    /// behaviour for existing callers (pages, other codeunits already calling this).
    /// Now just a confirm dialog in front of the silent core below. Kept instead of
    /// deleted so this retrofit does not require touching every existing caller.
    /// </summary>
    procedure CancelReservation(ItemNo: Code[20])
    var
        ConfirmQst: Label 'Cancel the reservation for %1?', Comment = '%1 = item no.';
    begin
        if not Confirm(ConfirmQst, false, ItemNo) then
            exit;
        CancelReservationSilent(ItemNo);
    end;

    /// <summary>
    /// The retrofit: the same two writes as before (delete the reservation, log the
    /// cancellation), but as one procedure with no Confirm() and no Commit() in between -
    /// both writes now succeed or fail together. This is what "Legacy App - Bifrost"
    /// calls; CancelReservation above still exists for existing UI callers. See
    /// ADAPTING.md for why this extraction was necessary rather than optional.
    /// </summary>
    procedure CancelReservationSilent(ItemNo: Code[20])
    var
        Reservation: Record "Legacy Stock Reservation";
        Log: Record "Legacy Cancellation Log";
    begin
        if not Reservation.Get(ItemNo) then
            exit;
        Reservation.Delete(true);

        Log.Init();
        Log."Item No." := ItemNo;
        Log."Cancelled At" := CurrentDateTime();
        Log.Insert(true);
    end;
}

