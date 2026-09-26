namespace Origo.Bifrost.Reference;

/// <summary>
/// The app's setup page, opened from Bifrost Setup > Apps. The API key is entered through
/// Foundation's shared secret dialog, so the value never touches this app's tables.
/// UI lives here; message types never open pages.
/// </summary>
page 90011 "Ref Setup"
{
    Caption = 'Bifrost Reference Setup', Comment = 'is-IS=Uppsetning Bifrost sýnidæmis';
    PageType = Card;
    SourceTable = "Ref Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Rates)
            {
                Caption = 'Exchange rates service', Comment = 'is-IS=Gengisþjónusta';

                field("Rates Base URL"; Rec."Rates Base URL")
                {
                    ToolTip = 'Base address of the exchange rate service used by Reference.ExchangeRate.Get.', Comment = 'is-IS=Grunnslóð gengisþjónustunnar sem Reference.ExchangeRate.Get notar.';
                }
                field(ApiKeyStatus; ApiKeyStatusText)
                {
                    Caption = 'API key', Comment = 'is-IS=API-lykill';
                    ToolTip = 'Whether an API key is stored in the Bifrost secret store. The value itself is never shown.', Comment = 'is-IS=Hvort API-lykill er vistaður í leyndarmálageymslu Bifrastar. Gildið sjálft er aldrei sýnt.';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SetApiKey)
            {
                Caption = 'Set API key', Comment = 'is-IS=Setja API-lykil';
                ToolTip = 'Enter the API key in a masked dialog. It is stored in the Bifrost secret store.', Comment = 'is-IS=Sláðu inn API-lykilinn í huldum glugga. Hann er vistaður í leyndarmálageymslu Bifrastar.';
                Image = EncryptionKeys;

                trigger OnAction()
                var
                    RefSecrets: Codeunit "Ref Secrets";
                begin
                    RefSecrets.SetApiKeyFromDialog();
                    UpdateStatus();
                end;
            }
            action(ClearApiKey)
            {
                Caption = 'Clear API key', Comment = 'is-IS=Hreinsa API-lykil';
                ToolTip = 'Remove the stored API key.', Comment = 'is-IS=Fjarlægja vistaðan API-lykil.';
                Image = Delete;

                trigger OnAction()
                var
                    RefSecrets: Codeunit "Ref Secrets";
                begin
                    RefSecrets.ClearApiKey();
                    UpdateStatus();
                end;
            }
        }
    }

    var
        ApiKeyStatusText: Text;
        KeySetTxt: Label 'Set', Comment = 'is-IS=Skráður';
        KeyNotSetTxt: Label 'Not set (the default service works without a key)', Comment = 'is-IS=Ekki skráður (sjálfgefna þjónustan virkar án lykils)';

    trigger OnOpenPage()
    begin
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
        UpdateStatus();
    end;

    local procedure UpdateStatus()
    var
        RefSecrets: Codeunit "Ref Secrets";
    begin
        if RefSecrets.IsApiKeySet() then
            ApiKeyStatusText := KeySetTxt
        else
            ApiKeyStatusText := KeyNotSetTxt;
    end;
}
