namespace Origo.Bifrost.Reference;

/// <summary>
/// The app's own setup. Settings live here - never on Foundation's Setup ori, which a
/// dependent app may only extend with one action (see RefSetupAction.PageExt.al).
/// Secrets are NOT stored here; they go to Foundation's Secret Store ori.
/// </summary>
table 90011 "Ref Setup"
{
    Caption = 'Bifrost Reference Setup', Comment = 'is-IS=Uppsetning Bifrost sýnidæmis';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
        }
        field(2; "Rates Base URL"; Text[250])
        {
            Caption = 'Rates Base URL', Comment = 'is-IS=Grunnslóð gengisþjónustu';
            InitValue = 'https://api.frankfurter.dev/v1';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Returns the setup, or the defaults when no record exists yet. Never inserts: a
    /// read-only message type must not write as a side effect.
    /// </summary>
    procedure GetOrDefault()
    begin
        if not Get() then
            Init();
    end;
}
