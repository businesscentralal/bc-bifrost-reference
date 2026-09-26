namespace Origo.Bifrost.Reference;

/// <summary>
/// Everything a user needs to use the reference message types. Assign it together with
/// Foundation's own BIFROST permission sets. Message types check these permissions in IsEnabled,
/// so a user without them simply does not see the types.
/// </summary>
permissionset 90000 "BIFROST REFERENCE"
{
    Assignable = true;
    Caption = 'Bifrost Reference', Comment = 'is-IS=Bifrost sýnidæmi';

    Permissions =
        tabledata "Ref Note" = RIMD,
        tabledata "Ref Service Visit" = RIMD,
        tabledata "Ref Setup" = RIMD,
        table "Ref Note" = X,
        table "Ref Service Visit" = X,
        table "Ref Setup" = X,
        page "Ref Service Visits" = X,
        page "Ref Setup" = X;
}
