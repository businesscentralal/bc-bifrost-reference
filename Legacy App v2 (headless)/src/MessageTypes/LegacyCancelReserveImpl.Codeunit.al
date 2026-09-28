namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.CancelReservation. Before the retrofit the app's only cancel procedure asked
/// the user with Confirm() - impossible to call headless. The facade now holds the logic; the
/// dialog stayed in the app's UI layer. This message type calls the facade and reports "cancelled"
/// true or false, so a caller always knows whether anything happened.
/// </summary>
codeunit 90101 "Legacy Cancel Reserve Impl" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Reservation: Record "Legacy Stock Reservation";
        Log: Record "Legacy Cancellation Log";
    begin
        exit(Reservation.WritePermission() and Log.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Legacy Stock Reservation");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Cancel the whole stock reservation for one item in Legacy App and log it. Commits; safe to repeat - answers cancelled: false when there was nothing to cancel. To add stock use Legacy.Stock.Reserve.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Legacy Adapter Help";
    begin
        Argument.SetResponseMarkdown(Help.GetCancelHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AdapterInput: Codeunit "Legacy Adapter Input";
        CancelProcess: Codeunit "Legacy Cancel Process";
        RequestJson: JsonObject;
        ItemNo: Code[20];
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not AdapterInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not AdapterInput.GetItemNo(Argument, RequestJson, ItemNo) then
            exit;

        CancelProcess.SetItem(ItemNo);
        if Argument."Omit Commit" then
            CancelProcess.Run(Argument)
        else
            if not CancelProcess.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
