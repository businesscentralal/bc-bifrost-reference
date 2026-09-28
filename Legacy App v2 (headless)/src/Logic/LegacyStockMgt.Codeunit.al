namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// The app's ORIGINAL business logic entry points, kept so existing callers keep working.
/// See README.md in this app's folder for the "talk to a person vs. do the work" split.
///
/// Before the retrofit this codeunit held the logic itself and mixed dialogs, a GuiAllowed branch,
/// Commits and swallowed errors with the writes - which made it impossible to call from an API,
/// a job queue or another app. The retrofit moved the logic to the headless facade
/// "Legacy Stock API" and left these procedures as thin shells over it:
///  - ReserveStock keeps its old Boolean contract for old callers;
///  - CancelReservation and ReleaseAll keep their dialogs (they are UI entry points), but the
///    work is the facade's;
///  - CancelReservationSilent is kept for callers written against the first retrofit.
/// New code inside the app - its pages and message types - calls the internal "Legacy Stock API";
/// new callers outside the app use the Legacy.Stock.* message types.
/// </summary>
codeunit 90050 "Legacy Stock Mgt"
{
    /// <summary>
    /// Old contract: returns false instead of raising an error. New callers use the
    /// Legacy.Stock.Reserve message type, which says why a reservation was refused.
    /// </summary>
    [Obsolete('Use codeunit "Legacy Stock API".Reserve, which returns the new total and explains failures. New callers outside Legacy App use the Legacy.Stock.Reserve message type.', '2.0')]
    procedure ReserveStock(ItemNo: Code[20]; Quantity: Decimal): Boolean
    var
        LegacyStockAPI: Codeunit "Legacy Stock API";
    begin
        // Keep the old "false instead of an error" contract: check first, then reserve.
        // FIXED -GuiAllowed branch: the stock check now applies to this path too. In v1 only
        // a person was stopped; code callers over-reserved silently.
        if Quantity <= 0 then
            exit(false);
        if not LegacyStockAPI.IsReservable(ItemNo) then
            exit(false);
        if LegacyStockAPI.WouldExceedInventory(ItemNo, Quantity) then
            exit(false);
        LegacyStockAPI.Reserve(ItemNo, Quantity);
        exit(true);
    end;

    /// <summary>
    /// The UI entry point: asks the user, then lets the headless facade do the work.
    /// The dialog lives here, in the UI layer - never inside the facade.
    /// </summary>
    procedure CancelReservation(ItemNo: Code[20])
    var
        LegacyStockAPI: Codeunit "Legacy Stock API";
        ConfirmQst: Label 'Cancel the reservation for %1?', Comment = '%1 = item no., is-IS=Hætta við frátekningu fyrir %1?';
        NothingToCancelMsg: Label 'Item %1 has no reservation.', Comment = '%1 = item no., is-IS=Varan %1 er ekki með frátekningu.';
    begin
        if not Confirm(ConfirmQst, false, ItemNo) then
            exit;
        if not LegacyStockAPI.CancelReservation(ItemNo) then
            Message(NothingToCancelMsg, ItemNo);
    end;

    /// <summary>
    /// The UI entry point for releasing every reservation: it counts, asks, lets the facade do
    /// the work in one transaction, and reports the outcome to the person.
    /// </summary>
    procedure ReleaseAll()
    var
        LegacyStockAPI: Codeunit "Legacy Stock API";
        NothingMsg: Label 'There are no reservations to release.', Comment = 'is-IS=Engar frátekningar eru til að losa.';
        ConfirmQst: Label 'Release all %1 reservations?', Comment = '%1 = number of reservations, is-IS=Losa allar %1 frátekningar?';
        DoneMsg: Label '%1 reservations released.', Comment = '%1 = number released, is-IS=%1 frátekningar losaðar.';
        ReservationCount: Integer;
    begin
        // FIXED -Silent failure: "nothing to do" is said, not Error('').
        ReservationCount := LegacyStockAPI.CountReservations('');
        if ReservationCount = 0 then begin
            Message(NothingMsg);
            exit;
        end;
        if not Confirm(ConfirmQst, false, ReservationCount) then
            exit;
        Message(DoneMsg, LegacyStockAPI.ReleaseReservations(''));
    end;

    /// <summary>
    /// Kept for callers written against the first retrofit. Delegates to the facade.
    /// </summary>
    [Obsolete('Use codeunit "Legacy Stock API".CancelReservation, which returns whether anything was cancelled. New callers outside Legacy App use the Legacy.Stock.CancelReservation message type.', '2.0')]
    procedure CancelReservationSilent(ItemNo: Code[20])
    var
        LegacyStockAPI: Codeunit "Legacy Stock API";
    begin
        LegacyStockAPI.CancelReservation(ItemNo);
    end;
}
