namespace MyCompany.MyBifrostApp;

using Microsoft.Inventory.Item;

/// <summary>
/// Everything a user needs to use this app's message types. Assign it together with
/// Foundation's own BIFROST permission sets. Message types check these permissions in IsEnabled,
/// so a user without them simply does not see the types.
/// The sample types only read Item; add your own tables here
/// (tabledata = RIMD and table = X) as you add them.
/// </summary>
permissionset 50000 "MY BIFROST APP"
{
    // TODO: rename the object (at most 20 characters) and the caption, including the is-IS text.
    Assignable = true;
    Caption = 'My Bifrost App', Comment = 'is-IS=Bifröst-appið mitt';

    Permissions =
        tabledata Item = R;
}
