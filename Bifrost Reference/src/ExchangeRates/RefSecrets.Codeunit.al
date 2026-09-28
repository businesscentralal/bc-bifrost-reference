namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// The one place this app touches its secret. Every read and write goes through Foundation's
/// Secret Store ori with this app's id and one secret code; values are SecretText end to end.
/// </summary>
codeunit 90025 "Ref Secrets"
{
    Access = Internal;

    var
        ApiKeyCodeTok: Label 'RATES-API-KEY', Locked = true;
        ApiKeyDescriptionTxt: Label 'Exchange rates API key (optional)', Comment = 'is-IS=API-lykill gengisþjónustu (valkvæður)';

    /// <summary>Registers the secret. Idempotent; called at install and before every write.</summary>
    procedure Register()
    var
        SecretStore: Codeunit "Secret Store ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        SecretStore.Register(AppInfo.Id(), ApiKeyCodeTok, ApiKeyDescriptionTxt, Enum::"Secret Scope ori"::Company, CopyStr(AppInfo.Name(), 1, 250));
    end;

    procedure SetApiKey(ApiKey: SecretText)
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        Register();
        SecretStore.Set(AppId(), ApiKeyCodeTok, ApiKey);
    end;

    procedure SetApiKeyFromDialog()
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        Register();
        SecretStore.SetFromDialog(AppId(), ApiKeyCodeTok);
    end;

    procedure ClearApiKey()
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        SecretStore.Clear(AppId(), ApiKeyCodeTok);
    end;

    procedure IsApiKeySet(): Boolean
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        exit(SecretStore.IsSet(AppId(), ApiKeyCodeTok));
    end;

    [NonDebuggable]
    procedure TryGetApiKey(var ApiKey: SecretText): Boolean
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        exit(SecretStore.TryGet(AppId(), ApiKeyCodeTok, ApiKey));
    end;

    local procedure AppId(): Guid
    var
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        exit(AppInfo.Id());
    end;
}
