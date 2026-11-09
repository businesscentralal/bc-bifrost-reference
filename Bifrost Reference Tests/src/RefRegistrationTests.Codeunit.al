namespace Origo.Bifrost.Reference.Tests;

using Origo.Bifrost;
using Origo.Bifrost.Reference;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Exercises Foundation's real registry event with only the licence administrator role.
/// Registration must remain visible and repeat-safe without granting sample business access.
/// </summary>
codeunit 90156 "Ref Registration Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        PermissionsMock: Codeunit "Permissions Mock";

    [Test]
    procedure Scenario_AC08_LicAdm_RegistersBothAppsOnce()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        ReferenceAppId: Guid;
        LegacyAppId: Guid;
        ReferenceCount: Integer;
        LegacyCount: Integer;
        RepeatedReferenceCount: Integer;
        RepeatedLegacyCount: Integer;
    begin
        // Story #6, AC08 | Time: independent of Today/WorkDate | Risk: other installed subscribers
        // [GIVEN] Only the Foundation licence administrator role, without All Objects or sample roles.
        Evaluate(ReferenceAppId, '3f8a1c2e-6b4d-4a9f-9e2c-7d5b8a3f1e6c');
        Evaluate(LegacyAppId, '8a3f2c1e-9d4b-4e7a-b6c3-1f5e8a2d4c9b');
        PermissionsMock.Start();
        PermissionsMock.SetExactPermissionSet('BIFROST LicAdm ori');

        // [WHEN] The real public registry entry point raises OnRegisterTempApps twice.
        AppRegistry.GetApps(TempApps);
        TempApps.SetRange("App Id", ReferenceAppId);
        ReferenceCount := TempApps.Count();
        TempApps.SetRange("App Id", LegacyAppId);
        LegacyCount := TempApps.Count();
        TempApps.Reset();
        AppRegistry.GetApps(TempApps);
        TempApps.SetRange("App Id", ReferenceAppId);
        RepeatedReferenceCount := TempApps.Count();
        TempApps.SetRange("App Id", LegacyAppId);
        RepeatedLegacyCount := TempApps.Count();
        PermissionsMock.Stop();

        // [THEN] Neither app is silently omitted or duplicated by repeated registration.
        Assert.AreEqual(1, ReferenceCount, 'The restricted user must discover Bifrost Reference.');
        Assert.AreEqual(1, LegacyCount, 'The restricted user must discover Legacy App.');
        Assert.AreEqual(1, RepeatedReferenceCount, 'Reference registration must remain repeat-safe.');
        Assert.AreEqual(1, RepeatedLegacyCount, 'Legacy registration must remain repeat-safe.');
    end;

    [Test]
    procedure Scenario_AC08_LicAdm_CannotWriteSampleSetup()
    var
        RefSetup: Record "Ref Setup";
        CanWriteSetup: Boolean;
        FailureText: Text;
    begin
        // Story #6, AC08 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] The same exact role that successfully discovers the sample app.
        PermissionsMock.Start();
        PermissionsMock.SetExactPermissionSet('BIFROST LicAdm ori');

        // [WHEN] A sample administration write is attempted without the sample role.
        CanWriteSetup := RefSetup.WritePermission();
        RefSetup.Init();
        asserterror RefSetup.Insert(true);
        FailureText := GetLastErrorText();
        PermissionsMock.Stop();

        // [THEN] Metadata Execute does not grant tabledata or administration access.
        Assert.IsFalse(CanWriteSetup, 'Registration must not grant sample setup write permission.');
        Assert.IsTrue(FailureText.ToLower().Contains('permission'), 'The setup write must fail because permission is missing.');
    end;
}
