namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.Reserve - scenario "make an existing app headless" (path B).
/// Legacy App's message types own only the Bifröst contract: read and check the input, call the
/// app's internal headless core in isolation, answer. All business rules stay in that core.
/// </summary>
codeunit 90100 "Legacy Stock Reserve Impl" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        exit(Reservation.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Legacy Stock Reservation");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Reserve a quantity of an item in Legacy App; adds to any existing reservation and returns the new total. Refuses more than is in stock unless allowOverStock. Commits; not safe to repeat. To remove use Legacy.Stock.CancelReservation.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Legacy Adapter Help";
    begin
        Argument.SetResponseMarkdown(Help.GetReserveHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AdapterInput: Codeunit "Legacy Adapter Input";
        ReserveProcess: Codeunit "Legacy Reserve Process";
        RequestJson: JsonObject;
        ItemNo: Code[20];
        Quantity: Decimal;
        AllowOverStock: Boolean;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not AdapterInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not AdapterInput.GetItemNo(Argument, RequestJson, ItemNo) then
            exit;
        if not AdapterInput.GetRequiredDecimal(Argument, RequestJson, 'quantity', Quantity) then
            exit;
        // The decision a person made in v1's dialog is an explicit parameter with a safe default.
        if not AdapterInput.GetOptionalBoolean(Argument, RequestJson, 'allowOverStock', false, AllowOverStock) then
            exit;

        ReserveProcess.SetReservation(ItemNo, Quantity, AllowOverStock);
        if Argument."Omit Commit" then
            ReserveProcess.Run(Argument)
        else
            if not ReserveProcess.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
