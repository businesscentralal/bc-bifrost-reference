namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// Records that a reservation was cancelled. Identical in v1 and v2.
/// </summary>
table 90051 "Legacy Cancellation Log"
{
    Caption = 'Legacy Cancellation Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(3; "Cancelled At"; DateTime)
        {
            Caption = 'Cancelled At';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
