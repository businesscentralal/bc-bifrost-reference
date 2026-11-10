namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.CancelReservation. Before the retrofit the app's only cancel procedure asked
/// the user with Confirm() - impossible to call headless. The facade now holds the logic; the
/// dialog stayed in the app's UI layer. This message type calls the facade and reports "cancelled"
/// true or false, so a caller always knows whether anything happened.
/// </summary>
codeunit 90101 "Legacy Cancel Reserve Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'cancel a reservation, remove the reservation, unreserve an item, release the stock for one item, free up reserved stock, undo a reservation', Comment = 'is-IS=hætta við frátekningu, fjarlægja frátekningu, taka frátekningu af vöru, losa birgðir einnar vöru, losa frátekið magn, afturkalla frátekningu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Cancel the whole reservation of one item in Legacy App and log it; answers cancelled: false when there was nothing to cancel. It cannot reduce a reservation partly. For many items at once, use Legacy.Stock.ReleaseAll; to reserve, use Legacy.Stock.Reserve.', Comment = 'is-IS=Hætta við alla frátekningu einnar vöru í Legacy App og skrá það; svarar cancelled: false ef ekkert var til að hætta við. Getur ekki minnkað frátekningu að hluta. Fyrir margar vörur í einu, notaðu Legacy.Stock.ReleaseAll; til að taka frá, notaðu Legacy.Stock.Reserve.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: shared parts come from Legacy Stock Contract ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Removes the whole reservation for one item in Legacy App and writes a cancellation log entry, both in one transaction. Answers whether anything was cancelled. ' +
            'Not for reducing a reservation partly (there is no type for that), and not for many items at once (use Legacy.Stock.ReleaseAll).';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Envelope := Parts.ItemEnvelope(false);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Target := Parts.ItemTarget();
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Parameters.Add(Parts.ItemNoParameter());
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number, in upper case.'));
        Fields.Add(ContractMgt.ResponseField('cancelled', 'boolean', 'true when a reservation was removed; false when the item had none, and then nothing was written. An unknown item number is not an error: it has nothing to cancel.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Parts.AddItemErrors(Errors);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Deletes the item''s Legacy Stock Reservation record and inserts one Legacy Cancellation Log entry, in one transaction. Nothing is written when the item has no reservation. ' +
            'The answer does not say how much was reserved: read it with Legacy.Stock.Get first if it may need to be reserved again with Legacy.Stock.Reserve. The log entry stays.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can write Legacy Stock Reservation and Legacy Cancellation Log; without it the type is not offered.');
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
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.Get', 'You want to see what is reserved before cancelling.'));
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.ReleaseAll', 'You want to release the reservations of many items at once.'));
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.Reserve', 'You want to reserve stock instead.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Legacy.Stock.Get', 'Optional: see what is reserved for the item.'));
        Steps.Add(ContractMgt.WorkflowStep('Legacy.Stock.CancelReservation', 'Remove the reservation.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Standalone. It undoes Legacy.Stock.Reserve for one item; for several items at once use Legacy.Stock.ReleaseAll.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Cancel an item''s reservation',
            '{"type":"Legacy.Stock.CancelReservation","subject":"1896-S"}',
            '{"itemNo":"1896-S","cancelled":true}'));
        Examples.Add(ContractMgt.Example('Nothing to cancel',
            '{"type":"Legacy.Stock.CancelReservation","subject":"1900-S"}',
            '{"itemNo":"1900-S","cancelled":false}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: when the item has no reservation, nothing is written and the answer is "cancelled": false, so a retry after a timeout cannot cancel twice. ' +
            'Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
