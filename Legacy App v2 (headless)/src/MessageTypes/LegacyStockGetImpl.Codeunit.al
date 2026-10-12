namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.Get - the read sibling. Without it an agent cannot check the state before or
/// after Reserve/CancelReservation, and would have to guess.
/// </summary>
codeunit 90105 "Legacy Stock Get Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Reservation: Record "Legacy Stock Reservation";
    begin
        exit(Reservation.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Legacy Stock Reservation");
    end;

    procedure GetDescription(): Text[250]
    begin
        // Selection card phrased the way users ask ("how much is reserved for item X"): the live
        // search missed the first wording, which only said "Get the reserved quantity".
        exit('How much stock is reserved for an item in Legacy App, and how much can still be reserved. Read-only. For all items use Legacy.Stock.List; to change it use Legacy.Stock.Reserve or Legacy.Stock.CancelReservation.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AdapterInput: Codeunit "Legacy Adapter Input";
        LegacyStockAPI: Codeunit "Legacy Stock API";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNo: Code[20];
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not AdapterInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not AdapterInput.GetItemNo(Argument, RequestJson, ItemNo) then
            exit;

        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('hasReservation', LegacyStockAPI.HasReservation(ItemNo));
        ResponseJson.Add('reservedQuantity', LegacyStockAPI.GetReservedQuantity(ItemNo));
        ResponseJson.Add('availableToReserve', LegacyStockAPI.GetAvailableToReserve(ItemNo));
        Argument.SetResponseJson(ResponseJson);
    end;

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'how much is reserved for an item, reserved quantity, available to reserve, check a reservation, is this item reserved, how much can still be reserved', Comment = 'is-IS=hve mikið er frátekið af vöru, frátekið magn, laust til frátekningar, athuga frátekningu, er þessi vara frátekin, hve mikið má enn taka frá';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'How much of one item is reserved in Legacy App, and how much can still be reserved. Changes nothing. For all reservations or a filter, use Legacy.Stock.List; to change a reservation, use Legacy.Stock.Reserve or Legacy.Stock.CancelReservation.', Comment = 'is-IS=Hve mikið af einni vöru er frátekið í Legacy App, og hve mikið má enn taka frá. Breytir engu. Fyrir allar frátekningar eða síu, notaðu Legacy.Stock.List; til að breyta frátekningu, notaðu Legacy.Stock.Reserve eða Legacy.Stock.CancelReservation.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: shared parts come from Legacy Stock Contract ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the reserved quantity of one item in Legacy App, and how much can still be reserved without allowOverStock. ' +
            'Use it before Legacy.Stock.Reserve to see what fits, or after a call whose outcome is unknown to see whether it went through. Not for many items (use Legacy.Stock.List).';
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
        Fields.Add(ContractMgt.ResponseField('hasReservation', 'boolean', 'true when the item has a reservation.'));
        Fields.Add(ContractMgt.ResponseField('reservedQuantity', 'number', 'The total reserved quantity; 0 when the item has no reservation.'));
        Fields.Add(ContractMgt.ResponseField('availableToReserve', 'number', 'Inventory minus the reserved quantity: the most Legacy.Stock.Reserve accepts without allowOverStock. Negative after an over-reservation; 0 for an unknown item.'));
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
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads Legacy Stock Reservation and the item''s inventory.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can read Legacy Stock Reservation; without it the type is not offered.');
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
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.List', 'You want every reservation, or those matching an item filter.'));
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.Reserve', 'You want to reserve stock.'));
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.CancelReservation', 'You want to remove the reservation.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('How much is reserved for an item',
            '{"type":"Legacy.Stock.Get","subject":"1896-S"}',
            '{"itemNo":"1896-S","hasReservation":true,"reservedQuantity":5,"availableToReserve":12}'));
        Examples.Add(ContractMgt.Example('No item given',
            '{"type":"Legacy.Stock.Get","data":{}}',
            '{"status":"Error","error":"Parameter ''itemNo'' is required. Send it as text, for example \"1896-S\"."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: the same call gives the same answer until a reservation or the inventory changes. ' +
            'The item number is not checked against the item list: an unknown item answers hasReservation false and 0. Numbers use a dot as decimal separator. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
