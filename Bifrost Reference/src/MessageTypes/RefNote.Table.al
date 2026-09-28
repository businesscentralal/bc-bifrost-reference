namespace Origo.Bifrost.Reference;

/// <summary>
/// Minimal demo table used only by Reference.Note.Add, to keep the write-pattern example
/// self-contained (no dependency on any real BC business table).
/// </summary>
table 90002 "Ref Note"
{
    Caption = 'Reference Note', Comment = 'is-IS=Athugasemd (sýnidæmi)';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.', Comment = 'is-IS=Nr.';
        }
        field(2; "Text"; Text[250])
        {
            Caption = 'Text', Comment = 'is-IS=Texti';
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
    }
}
