namespace MyCompany.MyBifrostApp.Tests;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Proves the copied boilerplate registers for licence administrators without business access.
/// Uses the public registry entry point instead of calling a subscriber directly.
/// </summary>
codeunit 50054 "My Registration Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        PermissionsMock: Codeunit "Permissions Mock";

    /// <summary>Discovers the app through the real registry event twice with only the licence administrator role.</summary>
    [Test]
    procedure Scenario_AC08_LicAdm_RegistersBoilerplateOnce()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        AppId: Guid;
        FirstCount: Integer;
        RepeatedCount: Integer;
    begin
        // Story #6, AC08 | Time: independent of Today/WorkDate | Risk: other installed subscribers
        // [GIVEN] Only the Foundation licence administrator role.
        Evaluate(AppId, 'b7e4c2a9-3f18-4d6e-9a5c-1e8f2d7b6c43');
        PermissionsMock.Start();
        PermissionsMock.SetExactPermissionSet('BIFROST LicAdm ori');

        // [WHEN] Foundation raises the real registry event twice.
        AppRegistry.GetApps(TempApps);
        TempApps.SetRange("App Id", AppId);
        FirstCount := TempApps.Count();
        TempApps.Reset();
        AppRegistry.GetApps(TempApps);
        TempApps.SetRange("App Id", AppId);
        RepeatedCount := TempApps.Count();
        PermissionsMock.Stop();

        // [THEN] The boilerplate app is present exactly once on each discovery.
        Assert.AreEqual(1, FirstCount, 'The restricted user must discover the boilerplate app.');
        Assert.AreEqual(1, RepeatedCount, 'Boilerplate registration must remain repeat-safe.');
    end;

    /// <summary>Confirms metadata registration does not grant access to the Item data used by sample operations.</summary>
    [Test]
    procedure Scenario_AC08_LicAdm_CannotReadSampleBusinessData()
    var
        Item: Record Item;
        CanReadItems: Boolean;
        FailureText: Text;
    begin
        // Story #6, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] The same exact role used for metadata discovery, without the sample business role.
        PermissionsMock.Start();
        PermissionsMock.SetExactPermissionSet('BIFROST LicAdm ori');

        // [WHEN] Reading the business table used by the sample's Item message types.
        CanReadItems := Item.ReadPermission();
        asserterror CanReadItems := Item.IsEmpty();
        FailureText := GetLastErrorText();
        PermissionsMock.Stop();

        // [THEN] Registration Execute does not provide business data access.
        Assert.IsFalse(CanReadItems, 'Registration must not grant Item read permission.');
        Assert.IsTrue(FailureText.ToLower().Contains('permission'), 'The business read must fail because permission is missing.');
    end;
}
