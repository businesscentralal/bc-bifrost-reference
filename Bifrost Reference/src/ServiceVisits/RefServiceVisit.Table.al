namespace Origo.Bifrost.Reference;

using Microsoft.Sales.Customer;

/// <summary>
/// A logged service visit at a customer. The kind of small vertical table a partner app owns.
/// "External Id" lets a caller make Reference.ServiceVisit.Create safe to retry.
/// </summary>
table 90010 "Ref Service Visit"
{
    Caption = 'Service Visit', Comment = 'is-IS=Þjónustuheimsókn';
    DataClassification = CustomerContent;
    LookupPageId = "Ref Service Visits";
    DrillDownPageId = "Ref Service Visits";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.', Comment = 'is-IS=Færslunr.';
            AutoIncrement = true;
        }
        field(2; "Customer No."; Code[20])
        {
            Caption = 'Customer No.', Comment = 'is-IS=Nr. viðskiptamanns';
            TableRelation = Customer;
        }
        field(3; "Visit Date"; Date)
        {
            Caption = 'Visit Date', Comment = 'is-IS=Dagsetning heimsóknar';
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
        key(CustomerDate; "Customer No.", "Visit Date")
        {
        }
    }
}
