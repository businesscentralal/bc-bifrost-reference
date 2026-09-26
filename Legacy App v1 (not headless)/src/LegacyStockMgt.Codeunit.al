namespace Origo.Bifrost.Reference.Legacy;

using Microsoft.Inventory.Item;

/// <summary>
/// v1 - deliberately NOT headless. This is what a lot of real apps look like, and every
/// procedure works fine for a person clicking through the UI.
///
/// Each problem is marked "AUDIT 7.2 - [pattern]", after the audit table in START-HERE.md §7.2,
/// so you can find it by searching. "Legacy App" 2.0 fixes every marked line; its fixes are marked
/// "FIXED 7.2 - [pattern]".
/// </summary>
codeunit 90050 "Legacy Stock Mgt"
{
    procedure ReserveStock(ItemNo: Code[20]; Quantity: Decimal): Boolean
    var
        Item: Record Item;
        Reservation: Record "Legacy Stock Reservation";
        OverStockQst: Label 'Only %1 of item %2 is in stock. Reserve %3 anyway?', Comment = '%1 = inventory, %2 = item no., %3 = new total';
        NewTotal: Decimal;
    begin
        // AUDIT 7.2 - Silent failure: false, with no reason given.
        if Quantity <= 0 then
            exit(false);
        if not Item.Get(ItemNo) then
            exit(false);

        NewTotal := Quantity;
        if Reservation.Get(ItemNo) then
            NewTotal += Reservation.Quantity;

        // AUDIT 7.2 - GuiAllowed branch: a person is warned before reserving more than is in
        // stock. An API caller, a job queue or an agent takes the other path, and the check
        // silently disappears - the "no UI" path over-reserves without a word.
        Item.CalcFields(Inventory);
        if GuiAllowed() then
            if NewTotal > Item.Inventory then
                // AUDIT 7.2 - Dialogs: a question inside the business procedure.
                if not Confirm(OverStockQst, false, Item.Inventory, ItemNo, NewTotal) then
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

    procedure CancelReservation(ItemNo: Code[20])
    var
        Reservation: Record "Legacy Stock Reservation";
        Log: Record "Legacy Cancellation Log";
        ConfirmQst: Label 'Cancel the reservation for %1?', Comment = '%1 = item no.';
    begin
        // AUDIT 7.2 - Dialogs: a question only a person can answer, inside the business procedure.
        if not Confirm(ConfirmQst, false, ItemNo) then
            exit;

        // AUDIT 7.2 - Silent failure: nothing to cancel looks the same as "cancelled".
        if not Reservation.Get(ItemNo) then
            exit;
        Reservation.Delete(true);

        // AUDIT 7.2 - Commit: the delete is committed before the log is written. If the log
        // insert fails, the reservation is gone and there is no record of it.
        Commit();

        Log.Init();
        Log."Item No." := ItemNo;
        Log."Cancelled At" := CurrentDateTime();
        Log.Insert(true);
    end;

    /// <summary>
    /// Releases every reservation. A classic end-of-period batch job, written for the UI.
    /// </summary>
    procedure ReleaseAll()
    var
        Reservation: Record "Legacy Stock Reservation";
        Window: Dialog;
        ProgressTxt: Label 'Releasing reservations...\Item #1##########', Comment = '#1 = item no.';
        DoneMsg: Label '%1 reservations released, %2 skipped.', Comment = '%1 = released, %2 = skipped';
        Released: Integer;
        Skipped: Integer;
    begin
        // AUDIT 7.2 - Unbounded work: no filter, every row, no way to limit it.
        // AUDIT 7.2 - Silent failure: Error('') rolls back and says nothing at all.
        if Reservation.IsEmpty() then
            Error('');

        // AUDIT 7.2 - Dialogs: a progress window.
        Window.Open(ProgressTxt);
        if Reservation.FindSet() then
            repeat
                Window.Update(1, Reservation."Item No.");

                // AUDIT 7.2 - Commit: needed here only because "if Codeunit.Run" is not allowed
                // inside an open write transaction. Each row is committed on its own, so a
                // failure half-way leaves some items released and some not.
                Commit();

                // AUDIT 7.2 - Swallowed errors: a row that fails is counted as "skipped", and
                // its error text is thrown away. Nobody learns why.
                if Codeunit.Run(Codeunit::"Legacy Release Row", Reservation) then
                    Released += 1
                else begin
                    ClearLastError();
                    Skipped += 1;
                end;
            until Reservation.Next() = 0;
        Window.Close();

        // AUDIT 7.2 - Dialogs: the only outcome is a message for a person.
        Message(DoneMsg, Released, Skipped);
    end;
}
