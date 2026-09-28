namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// Access to Legacy App's data and UI. Same object id and name as in v2, so the upgrade keeps
/// user assignments.
/// </summary>
permissionset 90050 "LEGACY STOCK"
{
    Assignable = true;
    Caption = 'Legacy Stock';

    Permissions =
        tabledata "Legacy Stock Reservation" = RIMD,
        tabledata "Legacy Cancellation Log" = RIMD,
        table "Legacy Stock Reservation" = X,
        table "Legacy Cancellation Log" = X,
        codeunit "Legacy Stock Mgt" = X,
        codeunit "Legacy Release Row" = X,
        page "Legacy Stock Reservations" = X,
        page "Legacy Reserve Dialog" = X;
}
