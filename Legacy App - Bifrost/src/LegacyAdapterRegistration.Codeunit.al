namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost;

/// <summary>
/// Every app built on Bifröst registers once with the App Registry, so Foundation lists it in the
/// setup wizard and its aggregated notifications. The adapter has no setup page, so it passes 0.
/// </summary>
codeunit 90107 "Legacy Adapter Registration"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), 0);
    end;
}
