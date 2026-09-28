namespace Origo.Bifrost.Reference.Legacy;

using Microsoft.Inventory.Item;

/// <summary>
/// v1 dialog that asks for item and quantity. Same object in v2.
/// </summary>
page 90053 "Legacy Reserve Dialog"
{
    Caption = 'Reserve Stock';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            field(ItemNo; ItemNo)
            {
                Caption = 'Item No.';
                ToolTip = 'The item to reserve stock for.';
                TableRelation = Item;
            }
            field(Quantity; Quantity)
            {
                Caption = 'Quantity';
                ToolTip = 'The quantity to add to the reservation.';
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
