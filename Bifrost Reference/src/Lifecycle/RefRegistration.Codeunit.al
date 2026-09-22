namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Registers this app with Bifröst Foundation's application registry.
///
/// This one subscriber is what makes the app visible to Foundation's shared administration:
/// the row in the Bifrost Setup Wizard's app list and its "enable HTTP" step, the aggregated
/// "HTTP client requests are not enabled for: …" notification on the Bifrost Setup page, and
/// the app's name on Bifrost App Secrets. A dependent app never shows a notification of its own
/// for HTTP or credentials; it registers here and Foundation aggregates.
///
/// Every Bifröst app has exactly one of these. Pass 0 as the setup page id while the app has no
/// setup page of its own (this sample has none yet); pass the page's object id once it does.
/// </summary>
codeunit 90006 "Ref Registration"
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
