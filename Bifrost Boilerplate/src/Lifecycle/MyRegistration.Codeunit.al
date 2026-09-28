namespace MyCompany.MyBifrostApp;

using Origo.Bifrost;

/// <summary>
/// Registers this app with Bifröst Foundation's application registry.
///
/// This one subscriber is what makes the app visible to Foundation's shared administration:
/// the row in the Bifrost Setup Wizard's app list and its "enable HTTP" step, the aggregated
/// notifications on the Bifrost Setup page, and the app's name on Bifrost App Secrets. A
/// dependent app never shows a setup notification of its own; it registers here and
/// Foundation aggregates.
///
/// Every Bifröst app has exactly one of these. The last argument is the app's own setup page,
/// or 0 when the app has none (as here).
/// </summary>
codeunit 50006 "My Registration"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        // TODO: when your app gets a setup page, pass Page::"Your Setup Page" instead of 0, and add
        // ONE action to the Bifrost Setup page (see Bifrost Reference/src/Lifecycle/RefSetupAction.PageExt.al).
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), 0);
    end;
}
