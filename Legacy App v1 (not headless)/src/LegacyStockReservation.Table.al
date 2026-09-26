namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// A stock reservation per item. Identical in v1 and v2 - the retrofit changes code, not data.
/// </summary>
table 90050 "Legacy Stock Reservation"
{
    Caption = 'Legacy Stock Reservation';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(2; "Quantity"; Decimal)
        {
            Caption = 'Quantity';
        }
    }

    keys
    {
        key(PK; "Item No.")
        {
            Clustered = true;
        }
    }
}
