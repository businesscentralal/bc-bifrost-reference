namespace Origo.Bifrost.Reference;

/// <summary>
/// Install: registers the app's secret so it shows on Bifrost App Secrets straight away.
/// No Commit, no TryFunction, no UI in install code.
/// </summary>
codeunit 90024 "Ref Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    var
        RefSecrets: Codeunit "Ref Secrets";
    begin
        RefSecrets.Register();
    end;
}
