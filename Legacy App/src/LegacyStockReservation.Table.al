namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// A stock reservation, exactly as an ordinary extension would model it. Nothing here
/// anticipates Bifröst - that's the point.
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
