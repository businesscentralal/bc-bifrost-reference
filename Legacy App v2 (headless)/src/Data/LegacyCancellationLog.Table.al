namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// Records that a reservation was cancelled. Kept deliberately separate from the
/// reservation table so CancelReservation has a second, independent write to make -
/// that second write is what makes the premature Commit() in CancelReservation a real
/// problem rather than a stylistic one. See START-HERE.md section 7.1.
/// </summary>
table 90051 "Legacy Cancellation Log"
{
    Caption = 'Legacy Cancellation Log', Comment = 'is-IS=Skrá yfir niðurfelldar frátekningar (eldra forrit)';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.', Comment = 'is-IS=Færslunr.';
            AutoIncrement = true;
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.', Comment = 'is-IS=Vörunr.';
        }
        field(3; "Cancelled At"; DateTime)
        {
            Caption = 'Cancelled At', Comment = 'is-IS=Fellt niður þann';
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
