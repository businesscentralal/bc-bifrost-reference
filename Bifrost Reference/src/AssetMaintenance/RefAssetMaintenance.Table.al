namespace Origo.Bifrost.Reference;

using Microsoft.FixedAssets.FixedAsset;

/// <summary>
/// Logged maintenance work on a fixed asset (a machine, a vehicle). The kind of small vertical
/// table a partner app owns. It holds no personal data: an asset, a date, hours and a note.
/// "External Id" lets a caller make Reference.AssetMaintenance.Create safe to retry.
/// </summary>
table 90010 "Ref Asset Maintenance"
{
    Caption = 'Asset Maintenance', Comment = 'is-IS=Viðhald eignar';
    DataClassification = CustomerContent;
    LookupPageId = "Ref Asset Maintenance";
    DrillDownPageId = "Ref Asset Maintenance";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.', Comment = 'is-IS=Færslunr.';
            AutoIncrement = true;
        }
        field(2; "FA No."; Code[20])
        {
            Caption = 'FA No.', Comment = 'is-IS=Eignanr.';
            TableRelation = "Fixed Asset";
        }
        field(3; "Maintenance Date"; Date)
        {
            Caption = 'Maintenance Date', Comment = 'is-IS=Dagsetning viðhalds';
        }
        field(4; Hours; Decimal)
        {
            Caption = 'Hours', Comment = 'is-IS=Klukkustundir';
            DecimalPlaces = 0 : 2;
        }
        field(5; Description; Text[100])
        {
            Caption = 'Description', Comment = 'is-IS=Lýsing';
        }
        field(6; "External Id"; Text[50])
        {
            Caption = 'External Id', Comment = 'is-IS=Ytra auðkenni';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ExternalId; "External Id")
        {
        }
        key(AssetDate; "FA No.", "Maintenance Date")
        {
        }
    }
}
