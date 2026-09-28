namespace Origo.Bifrost.Reference.Legacy;

using Microsoft.Inventory.Item;

/// <summary>
/// The UI half of "reserve stock": a dialog that asks a person for the item and the quantity.
/// It does no work itself. The page action that opens it passes the answers to the headless
/// facade ("Legacy Stock API".Reserve), exactly as an API, another app or a Bifröst message type
/// would. The dialog is the only part an agent can't use, and the only part it doesn't need.
/// </summary>
page 90053 "Legacy Reserve Dialog"
{
    Caption = 'Reserve Stock', Comment = 'is-IS=Taka frá birgðir';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            field(ItemNo; ItemNo)
            {
                Caption = 'Item No.', Comment = 'is-IS=Vörunr.';
                ToolTip = 'The item to reserve stock for.', Comment = 'is-IS=Varan sem á að taka frá birgðir fyrir.';
                TableRelation = Item;
            }
            field(Quantity; Quantity)
            {
                Caption = 'Quantity', Comment = 'is-IS=Magn';
                ToolTip = 'The quantity to add to the reservation.', Comment = 'is-IS=Magnið sem bætist við frátekninguna.';
                DecimalPlaces = 0 : 5;
            }
        }
    }

    var
        ItemNo: Code[20];
        Quantity: Decimal;

    procedure SetItemNo(NewItemNo: Code[20])
    begin
        ItemNo := NewItemNo;
    end;

    procedure GetValues(var SelectedItemNo: Code[20]; var SelectedQuantity: Decimal)
    begin
        SelectedItemNo := ItemNo;
        SelectedQuantity := Quantity;
    end;
}
