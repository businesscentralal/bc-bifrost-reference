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
/// The contract states both guards as a workflow and a precondition, like the ItemPrice
/// preview/apply pair in Bifrost Reference.
/// </summary>
codeunit 90109 "Legacy Release All Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'release all reservations, cancel every reservation, clear reservations, free all reserved stock, release reservations for these items, remove all reservations', Comment = 'is-IS=losa allar frátekningar, hætta við allar frátekningar, hreinsa frátekningar, losa allar fráteknar birgðir, losa frátekningar fyrir þessar vörur, fjarlægja allar frátekningar';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Release every reservation matching an item filter in Legacy App at once, after the user has seen them; needs the count from Legacy.Stock.List. Not for one item: use Legacy.Stock.CancelReservation. To see what would be released, use Legacy.Stock.List.', Comment = 'is-IS=Losa allar frátekningar sem passa við síu á vörunúmer í Legacy App í einu, eftir að notandinn hefur séð þær; þarf fjöldann úr Legacy.Stock.List. Ekki fyrir eina vöru: notaðu Legacy.Stock.CancelReservation. Til að sjá hvað yrði losað, notaðu Legacy.Stock.List.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: shared parts come from Legacy Stock Contract ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Releases (cancels) every reservation in Legacy App whose item number matches itemFilter, and writes a cancellation log entry for each, in one transaction: all of them or, on any error, none. ' +
            'Run Legacy.Stock.List with the same filter first, show the user the result and get their agreement. Not for one item (use Legacy.Stock.CancelReservation).';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Envelope := Parts.FilterEnvelope(true);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Target := Parts.FilterTarget(true);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('itemFilter', 'string', true, 'A Business Central filter on the item number, at most 250 characters: 1896-S|1900-S or 19*. Send * to release all, on purpose.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, 'The count Legacy.Stock.List returned for the same itemFilter. The call is refused when the filter now matches a different number of reservations.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('itemFilter', 'string', 'The filter used, as sent.'));
        Fields.Add(ContractMgt.ResponseField('released', 'integer', 'The number of reservations released; always equal to expectedCount. 0 only when you sent expectedCount 0 and nothing matched.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// The count mismatch comes from the Label in Legacy Release All Process; the rest from
    /// Legacy Adapter Input. An invalid filter is answered with Business Central's own text (see notes).
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('itemFilter ''{filter}'' matches {actual} reservations, not the {expected} you sent in expectedCount. Nothing was released. Check with Legacy.Stock.List and send its count.', 'Reservations were added or removed after the list, or the count was guessed.', 'Run Legacy.Stock.List again, show the user the new result, and resend with its count.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemFilter'' is required. Send it as text, for example "1896-S|1900-S" or "*" for all.', 'itemFilter is missing.', 'Send a filter; * for all.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemFilter'' is empty. Send a value, for example "1896-S|1900-S" or "*" for all.', 'itemFilter is an empty string.', 'Send a filter; * for all.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemFilter'' is {length} characters long; the maximum is 250.', 'itemFilter is too long.', 'Shorten the filter.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''expectedCount'' is required. Send it as a whole number, for example 3.', 'The list was skipped.', 'Run Legacy.Stock.List first and send its count.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''expectedCount'' has the value ''{value}'', which is not a whole number. Send a whole number, for example 3.', 'expectedCount is not a whole number.', 'Send the count from Legacy.Stock.List, for example 2.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' must be a single value (text or number), not an object or an array.', 'itemFilter or expectedCount is an object or an array.', 'Send a single value.'));
        Parts.AddBodyError(Errors);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Deletes every Legacy Stock Reservation record whose item number matches itemFilter and inserts one Legacy Cancellation Log entry for each. All or nothing. ' +
            'There is no undo type: the answer does not say which items or quantities were released, the stock is free for other callers at once, and the log entries stay.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can write Legacy Stock Reservation and Legacy Cancellation Log; without it the type is not offered.');
        Preconditions.Add('The reservations were listed: expectedCount must equal the number of reservations itemFilter matches now, as Legacy.Stock.List reports it.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.List', 'Always call it first with the same itemFilter, and show the user the result.'));
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.CancelReservation', 'You want to cancel one item''s reservation.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Workflow := Parts.ReleaseWorkflow();
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Release the two reservations the list showed',
            '{"type":"Legacy.Stock.ReleaseAll","data":{"itemFilter":"19*","expectedCount":2}}',
            '{"itemFilter":"19*","released":2}'));
        Examples.Add(ContractMgt.Example('The reservations changed after the list',
            '{"type":"Legacy.Stock.ReleaseAll","data":{"itemFilter":"19*","expectedCount":2}}',
            '{"status":"Error","error":"itemFilter ''19*'' matches 3 reservations, not the 2 you sent in expectedCount. Nothing was released. Check with Legacy.Stock.List and send its count."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: after a release the filter matches no reservations, so a second identical call is refused on expectedCount and releases nothing. ' +
            'The guard compares counts only: if exactly as many reservations were added and removed since the list, the call goes through, so list again when time has passed. ' +
            'An invalid filter is answered with Business Central''s own filter error text, which does not name the parameter; Legacy.Stock.List checks the same filter and names it. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
