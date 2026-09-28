namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Isolated write for Reference.ApiKey.Set: registers the secret (idempotent) and stores the value.
/// </summary>
codeunit 90026 "Ref Api Key Set Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        ApiKey: SecretText;

    trigger OnRun()
    begin
        StoreKey();
    end;

    [NonDebuggable]
    procedure SetApiKey(NewApiKey: SecretText)
    begin
        ApiKey := NewApiKey;
    end;

    [NonDebuggable]
    local procedure StoreKey()
    var
        RefSecrets: Codeunit "Ref Secrets";
    begin
        RefSecrets.SetApiKey(ApiKey);
    end;
}
