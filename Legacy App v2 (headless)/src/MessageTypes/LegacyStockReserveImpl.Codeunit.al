namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.Reserve - scenario "make an existing app headless" (path B).
/// Legacy App's message types own only the Bifröst contract: read and check the input, call the
/// app's internal headless core in isolation, answer. All business rules stay in that core.
/// </summary>
codeunit 90100 "Legacy Stock Reserve Impl" implements "Msg Interface ori", "Msg Contract ori"
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


    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Clear(Parameters);
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        exit(false);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Help: Codeunit "Legacy Adapter Help";
    begin
        Overview := Help.GetReserveHelp();
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
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
