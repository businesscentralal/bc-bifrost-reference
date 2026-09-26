namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// The app's UI. Every action follows the same split:
///   1. the PAGE talks to the person (a dialog to collect input, a Confirm, a Message);
///   2. the page then calls the HEADLESS FACADE ("Legacy Stock API"), which does the work.
/// An API, another app or a Bifröst message type calls step 2 directly and skips step 1.
/// </summary>
page 90052 "Legacy Stock Reservations"
{
    Caption = 'Legacy Stock Reservations', Comment = 'is-IS=Frátekningar birgða (eldra forrit)';
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
                    ToolTip = 'The item the stock is reserved for.', Comment = 'is-IS=Varan sem birgðir eru teknar frá fyrir.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'The reserved quantity.', Comment = 'is-IS=Frátekið magn.';
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
                Caption = 'Reserve stock...', Comment = 'is-IS=Taka frá birgðir...';
                ToolTip = 'Reserve a quantity of an item. You enter the item and the quantity in a dialog.', Comment = 'is-IS=Taka frá magn af vöru. Þú slærð inn vöru og magn í glugga.';
                Image = Reserve;

                trigger OnAction()
                var
                    LegacyStockAPI: Codeunit "Legacy Stock API";
                    ReserveDialog: Page "Legacy Reserve Dialog";
                    ItemNo: Code[20];
                    Quantity: Decimal;
                    NewTotal: Decimal;
                    AllowOverStock: Boolean;
                    ReservedMsg: Label 'Reserved %1 of item %2. Total reserved: %3.', Comment = '%1 = quantity, %2 = item no., %3 = new total, is-IS=Tekið frá %1 af vöru %2. Samtals frátekið: %3.';
                    OverStockQst: Label 'Only %1 of item %2 is available to reserve. Reserve %3 anyway?', Comment = '%1 = available, %2 = item no., %3 = quantity, is-IS=Aðeins %1 af vöru %2 er hægt að taka frá. Taka samt frá %3?';
                begin
                    // 1. UI: ask the person.
                    ReserveDialog.SetItemNo(Rec."Item No.");
                    if ReserveDialog.RunModal() <> Action::OK then
                        exit;
                    ReserveDialog.GetValues(ItemNo, Quantity);

                    // FIXED 7.2 - GuiAllowed branch: the page asks the person by calling a read
                    // on the facade, then passes the answer on as a parameter. Code callers make
                    // the same decision explicitly - there is no second, quieter path.
                    if (Quantity > 0) and LegacyStockAPI.IsReservable(ItemNo) then
                        if LegacyStockAPI.WouldExceedInventory(ItemNo, Quantity) then begin
                            if not Confirm(OverStockQst, false, LegacyStockAPI.GetAvailableToReserve(ItemNo), ItemNo, Quantity) then
                                exit;
                            AllowOverStock := true;
                        end;

                    // 2. Work: the headless facade. It raises clear errors itself
                    //    (unknown item, blocked item, quantity not above zero, over stock).
                    NewTotal := LegacyStockAPI.Reserve(ItemNo, Quantity, AllowOverStock);

                    // 3. UI again: tell the person.
                    Message(ReservedMsg, Quantity, ItemNo, NewTotal);
                    CurrPage.Update(false);
                end;
            }
            action(CancelReservation)
            {
                Caption = 'Cancel reservation', Comment = 'is-IS=Hætta við frátekningu';
                ToolTip = 'Cancel the reservation for the selected item. You are asked to confirm.', Comment = 'is-IS=Hætta við frátekningu valinnar vöru. Þú ert beðin(n) um staðfestingu.';
                Image = Cancel;

                trigger OnAction()
                var
                    LegacyStockMgt: Codeunit "Legacy Stock Mgt";
                begin
                    // Confirm (UI) and then the facade - see Legacy Stock Mgt.CancelReservation.
                    LegacyStockMgt.CancelReservation(Rec."Item No.");
                    CurrPage.Update(false);
                end;
            }
            action(ReleaseAll)
            {
                Caption = 'Release all reservations', Comment = 'is-IS=Losa allar frátekningar';
                ToolTip = 'Release every reservation and log each one, in one step. You are asked to confirm.', Comment = 'is-IS=Losa allar frátekningar og skrá hverja og eina, í einu skrefi. Þú ert beðin(n) um staðfestingu.';
                Image = ReleaseDoc;

                trigger OnAction()
                var
                    LegacyStockMgt: Codeunit "Legacy Stock Mgt";
                begin
                    // Count, Confirm and Message (UI) and then the facade - see Legacy Stock Mgt.ReleaseAll.
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
