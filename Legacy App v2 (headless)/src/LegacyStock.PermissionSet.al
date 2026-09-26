namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// Access to Legacy App's data and UI. The Bifröst adapter's message types check these
/// permissions in IsEnabled, so a user needs this set to see them.
/// </summary>
permissionset 90050 "LEGACY STOCK"
{
    Assignable = true;
    Caption = 'Legacy Stock', Comment = 'is-IS=Birgðafrátekningar (eldra forrit)';

    Permissions =
        tabledata "Legacy Stock Reservation" = RIMD,
        tabledata "Legacy Cancellation Log" = RIMD,
        table "Legacy Stock Reservation" = X,
        table "Legacy Cancellation Log" = X,
        codeunit "Legacy Stock API" = X,
        codeunit "Legacy Stock Mgt" = X,
        page "Legacy Stock Reservations" = X,
        page "Legacy Reserve Dialog" = X;
}
