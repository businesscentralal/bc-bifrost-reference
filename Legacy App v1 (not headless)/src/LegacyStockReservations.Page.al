namespace Origo.Bifrost.Reference.Legacy;

using Microsoft.Inventory.Item;

/// <summary>
/// v1 page - deliberately NOT headless. The "Reserve stock..." action has the business logic
/// written straight into the page trigger (dialog, rules and table writes all in one place),
/// the most common reason an app can't be called without a person. Nothing outside this page
/// can reserve stock the same way. Problems are marked "AUDIT 7.2 - [pattern]".
/// </summary>
page 90052 "Legacy Stock Reservations"
{
    Caption = 'Legacy Stock Reservations';
    PageType = List;
    SourceTable = "Legacy Stock Reservation";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Reservations)
            {
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'The item the stock is reserved for.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'The reserved quantity.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ReserveStock)
            {
                Caption = 'Reserve stock...';
                ToolTip = 'Reserve a quantity of an item.';
                Image = Reserve;

                trigger OnAction()
                var
                    Item: Record Item;
                    Reservation: Record "Legacy Stock Reservation";
                    ReserveDialog: Page "Legacy Reserve Dialog";
                    ItemNo: Code[20];
                    Quantity: Decimal;
                    NewTotal: Decimal;
                    QuantityErr: Label 'Quantity must be positive.';
                    OverStockQst: Label 'Only %1 of item %2 is in stock. Reserve %3 anyway?', Comment = '%1 = inventory, %2 = item no., %3 = new total';
                begin
                    ReserveDialog.SetItemNo(Rec."Item No.");
                    if ReserveDialog.RunModal() <> Action::OK then
                        exit;
                    ReserveDialog.GetValues(ItemNo, Quantity);

                    // AUDIT 7.2 - Rules that live on the page: the rules and the writes are in
                    // this trigger, so no other caller gets them.
                    if Quantity <= 0 then
                        Error(QuantityErr);
                    Item.Get(ItemNo);
                    NewTotal := Quantity;
                    if Reservation.Get(ItemNo) then
                        NewTotal += Reservation.Quantity;
                    Item.CalcFields(Inventory);
                    if NewTotal > Item.Inventory then
                        if not Confirm(OverStockQst, false, Item.Inventory, ItemNo, NewTotal) then
                            exit;

                    if Reservation.Get(ItemNo) then begin
                        Reservation.Quantity += Quantity;
                        Reservation.Modify(true);
                    end else begin
                        Reservation.Init();
                        Reservation."Item No." := ItemNo;
                        Reservation.Quantity := Quantity;
                        Reservation.Insert(true);
                    end;
                    Message('Reserved.');
                    CurrPage.Update(false);
                end;
            }
            action(CancelReservation)
            {
                Caption = 'Cancel reservation';
                ToolTip = 'Cancel the reservation for the selected item.';
                Image = Cancel;

                trigger OnAction()
                var
                    LegacyStockMgt: Codeunit "Legacy Stock Mgt";
                begin
                    LegacyStockMgt.CancelReservation(Rec."Item No.");
                    CurrPage.Update(false);
                end;
            }
            action(ReleaseAll)
            {
                Caption = 'Release all reservations';
                ToolTip = 'Release every reservation and log each one.';
                Image = ReleaseDoc;

                trigger OnAction()
                var
                    LegacyStockMgt: Codeunit "Legacy Stock Mgt";
                begin
                    LegacyStockMgt.ReleaseAll();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(ReserveStock_Promoted; ReserveStock)
            {
            }
            actionref(CancelReservation_Promoted; CancelReservation)
            {
            }
            actionref(ReleaseAll_Promoted; ReleaseAll)
            {
            }
        }
    }
}
