namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.Reserve - scenario "make an existing app headless" (path B).
/// Legacy App's message types own only the Bifröst contract: read and check the input, call the
/// app's internal headless core in isolation, answer. All business rules stay in that core, so
/// the errors chapter quotes the core's Labels (Legacy Stock API) next to the input layer's.
/// </summary>
codeunit 90100 "Legacy Stock Reserve Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reserve stock, set stock aside, hold items for an order, book stock for an item, put items on hold, reserve more of an item', Comment = 'is-IS=taka frá birgðir, leggja birgðir til hliðar, halda vörum fyrir pöntun, bóka birgðir fyrir vöru, setja vörur í bið, taka meira frá af vöru';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Reserve a quantity of one item in Legacy App, added to what is already reserved; more than is in stock only when the user agrees. Not for removing a reservation: use Legacy.Stock.CancelReservation. To see what is reserved, use Legacy.Stock.Get.', Comment = 'is-IS=Taka frá magn af einni vöru í Legacy App, bætt við það sem þegar er frátekið; meira en er til á lager aðeins ef notandinn samþykkir. Ekki til að fjarlægja frátekningu: notaðu Legacy.Stock.CancelReservation. Til að sjá hvað er frátekið, notaðu Legacy.Stock.Get.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: shared parts come from Legacy Stock Contract ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reserves a quantity of one item in Legacy App. An existing reservation for the item is increased; otherwise one is created. Returns the new total and what can still be reserved. ' +
            'By default the total reserved may not exceed the inventory. Not for reducing or removing a reservation (use Legacy.Stock.CancelReservation), and not for reading it (use Legacy.Stock.Get).';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Envelope := Parts.ItemEnvelope(true);
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
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Parameters.Add(Parts.ItemNoParameter());
        Parameters.Add(ContractMgt.Parameter('quantity', 'number', true, 'The quantity to add to the reservation, greater than zero, with a dot as decimal separator.'));
        Parameters.Add(ContractMgt.Parameter('allowOverStock', 'boolean', false, 'true allows the total reserved to exceed the inventory. Send true only when the user has explicitly agreed to reserve more than is in stock. Omitted: false.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number, in upper case.'));
        Fields.Add(ContractMgt.ResponseField('quantityAdded', 'number', 'The quantity this call added.'));
        Fields.Add(ContractMgt.ResponseField('totalReserved', 'number', 'The item''s total reserved quantity after this call.'));
        Fields.Add(ContractMgt.ResponseField('availableToReserve', 'number', 'Inventory minus the total reserved. Negative after an over-reservation.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// Input errors come from Legacy Adapter Input; the business rules (unknown, blocked, quantity,
    /// over stock) from the Labels in Legacy Stock API. The texts are verbatim.
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Parts.AddItemErrors(Errors);
        Errors.Add(ContractMgt.TextErrorEntry('Item ''{itemNo}'' does not exist. Check the number, or find the item with Data.Records.Get on table Item.', 'No item has that number.', 'Check the number.'));
        Errors.Add(ContractMgt.TextErrorEntry('Item ''{itemNo}'' is blocked, so stock cannot be reserved for it. Unblock the item or choose another.', 'The item is blocked.', 'Unblock it or choose another item.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''quantity'' is required. Send it as a number, for example 2.5.', 'quantity is missing.', 'Send quantity.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''quantity'' has the value ''{value}'', which is not a number. Send a number with a dot as decimal separator, for example 2.5.', 'quantity is not a number.', 'Send a number, for example 2.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' must be a single value (text or number), not an object or an array.', 'quantity or allowOverStock is an object or an array.', 'Send a single value.'));
        Errors.Add(ContractMgt.TextErrorEntry('The quantity to reserve is {quantity}. Send a quantity greater than zero; to remove a reservation, cancel it instead.', 'quantity is zero or negative.', 'Send a positive quantity.'));
        Errors.Add(ContractMgt.TextErrorEntry('Item ''{itemNo}'' has {inventory} in inventory and {reserved} already reserved, so reserving {quantity} more would reserve more than is in stock. Reserve at most {available}, or explicitly allow over-reservation.', 'The new total would exceed the inventory.', 'Reserve at most the number given, or ask the user and resend with "allowOverStock": true.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''allowOverStock'' has the value ''{value}''. Send true or false, without quotes.', 'allowOverStock is not true or false, for example "yes".', 'Send true or false.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Inserts or increases the item''s Legacy Stock Reservation record. On any error nothing is written. Legacy.Stock.CancelReservation removes the reservation again.');
        Effect.Add('idempotent', false);
        Preconditions.Add('The caller can write Legacy Stock Reservation; without it the type is not offered.');
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
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.Get', 'You want to see how much is reserved and how much can still be reserved, or whether an earlier call went through.'));
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.CancelReservation', 'You want to remove the item''s reservation.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Legacy.Stock.Get', 'Optional: see how much can still be reserved without allowOverStock.'));
        Steps.Add(ContractMgt.WorkflowStep('Legacy.Stock.Reserve', 'Reserve the quantity.'));
        Steps.Add(ContractMgt.WorkflowStep('Legacy.Stock.CancelReservation', 'Optional: remove the reservation again.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Standalone; check with Legacy.Stock.Get first when the stock may be short.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Reserve 2 of an item',
            '{"type":"Legacy.Stock.Reserve","subject":"1896-S","data":{"quantity":2}}',
            '{"itemNo":"1896-S","quantityAdded":2,"totalReserved":5,"availableToReserve":12}'));
        Examples.Add(ContractMgt.Example('More than is in stock',
            '{"type":"Legacy.Stock.Reserve","subject":"1896-S","data":{"quantity":5}}',
            '{"status":"Error","error":"Item ''1896-S'' has 10 in inventory and 8 already reserved, so reserving 5 more would reserve more than is in stock. Reserve at most 2, or explicitly allow over-reservation."}'));
        Examples.Add(ContractMgt.Example('The user agreed to reserve more than is in stock',
            '{"type":"Legacy.Stock.Reserve","subject":"1896-S","data":{"quantity":5,"allowOverStock":true}}',
            '{"itemNo":"1896-S","quantityAdded":5,"totalReserved":13,"availableToReserve":-3}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not safe to repeat: two identical calls reserve twice. When unsure whether an earlier call went through, check totalReserved with Legacy.Stock.Get before calling again. ' +
            'Never send allowOverStock: true on your own: ask the user first. Numbers use a dot as decimal separator. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
