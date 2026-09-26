namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost.Reference.Legacy;

/// <summary>
/// What a user needs to use the Legacy.Stock.* message types: Legacy App's own data
/// permissions, which the types check in IsEnabled. Assign it together with Foundation's BIFROST
/// permission sets. The adapter adds no tables of its own, so it only includes Legacy App's set -
/// it never grants more than a person using the app's pages already has.
/// </summary>
permissionset 90100 "LEGACY ADAPTER"
{
    Assignable = true;
    Caption = 'Legacy Stock via Bifrost', Comment = 'is-IS=Birgðafrátekningar um Bifröst';
    IncludedPermissionSets = "LEGACY STOCK";
}
