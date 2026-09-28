namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// A stock reservation, exactly as an ordinary extension would model it. Nothing here
/// anticipates Bifröst - that's the point.
/// </summary>
table 90050 "Legacy Stock Reservation"
{
    Caption = 'Legacy Stock Reservation', Comment = 'is-IS=Frátekning birgða (eldra forrit)';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.', Comment = 'is-IS=Vörunr.';
        }
        field(2; "Quantity"; Decimal)
        {
            Caption = 'Quantity', Comment = 'is-IS=Magn';
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
