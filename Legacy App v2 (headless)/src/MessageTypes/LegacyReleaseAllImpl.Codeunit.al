namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.ReleaseAll - a bulk, irreversible change, adapted from v1's "Release all" batch
/// job. v1 showed a progress window, committed every row and counted failed rows as "skipped".
/// The facade now releases the matching rows in one transaction, and this type adds the two
/// guards a caller without eyes on the screen needs:
///  - itemFilter is required: "all" has to be said on purpose ("*");
///  - expectedCount is required and must match what the filter matches right now, so the caller
///    has looked (Legacy.Stock.List) and nothing changed in between.
/// </summary>
codeunit 90109 "Legacy Release All Impl" implements "Msg Interface ori", "Msg Contract ori"
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
        exit('Release (cancel) every stock reservation matching an item filter in Legacy App, all or nothing, and log each. Commits; irreversible. Needs expectedCount from Legacy.Stock.List. For one item use Legacy.Stock.CancelReservation.');
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
        Overview := Help.GetReleaseAllHelp();
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
        Argument.SetResponseMarkdown(Help.GetReleaseAllHelp());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AdapterInput: Codeunit "Legacy Adapter Input";
        ReleaseProcess: Codeunit "Legacy Release All Process";
        RequestJson: JsonObject;
        ItemFilter: Text;
        ExpectedCount: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        ExpectedCount := 0;

        if not AdapterInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not AdapterInput.GetText(Argument, RequestJson, 'itemFilter', true, 250, '"1896-S|1900-S" or "*" for all', ItemFilter) then
            exit;
        if not AdapterInput.GetRequiredInteger(Argument, RequestJson, 'expectedCount', ExpectedCount) then
            exit;

        // Everything is checked and written inside the isolated run: the count check and the
        // release are one transaction, so nothing can change between them.
        ReleaseProcess.SetRelease(ItemFilter, ExpectedCount);
        if Argument."Omit Commit" then
            ReleaseProcess.Run(Argument)
        else
            if not ReleaseProcess.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
