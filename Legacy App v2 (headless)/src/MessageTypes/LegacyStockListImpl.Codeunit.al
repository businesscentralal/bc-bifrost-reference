namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Legacy.Stock.List - the read that goes with Legacy.Stock.ReleaseAll, the way a preview goes
/// with an apply. It returns the count that ReleaseAll requires as expectedCount, so a caller
/// always sees what a bulk change will touch before making it.
/// Bounded on purpose: at most 100 rows are returned, and "more" says when there are others.
/// </summary>
codeunit 90108 "Legacy Stock List Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        FilterErr: Label 'Parameter ''itemFilter'' is ''%1'', which is not a valid filter: %2 Send an item number or a filter such as 1896-S|1900-S or 19*.', Comment = '%1 = filter received, %2 = platform error text, is-IS=Færibreytan ''itemFilter'' er ''%1'', sem er ekki gild sía: %2 Sendu vörunúmer eða síu eins og 1896-S|1900-S eða 19*.';
        MaxRows: Integer;

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
        exit('List stock reservations in Legacy App, all or by item filter, with count and total quantity (max 100 rows). Read-only. Gives the expectedCount for Legacy.Stock.ReleaseAll. For one item use Legacy.Stock.Get.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Reservation: Record "Legacy Stock Reservation";
        AdapterInput: Codeunit "Legacy Adapter Input";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        ItemFilter: Text;
        TotalQuantity: Decimal;
        Returned: Integer;
        ReservationCount: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        MaxRows := 100;
        Returned := 0;

        if not AdapterInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not AdapterInput.GetText(Argument, RequestJson, 'itemFilter', false, 250, '"1896-S|1900-S"', ItemFilter) then
            exit;
        if not TryApplyFilter(Reservation, ItemFilter) then begin
            Argument.RespondWithError(StrSubstNo(FilterErr, ItemFilter, GetLastErrorText()));
            exit;
        end;

        // Totals from the database, rows capped: the call costs the same for 10 rows or 10,000.
        ReservationCount := Reservation.Count();
        Reservation.CalcSums(Quantity);
        TotalQuantity := Reservation.Quantity;

        Reservation.SetLoadFields("Item No.", Quantity);
        if Reservation.FindSet() then
            repeat
                Clear(Row);
                Row.Add('itemNo', Reservation."Item No.");
                Row.Add('quantity', Reservation.Quantity);
                Rows.Add(Row);
                Returned += 1;
            until (Reservation.Next() = 0) or (Returned >= MaxRows);

        ResponseJson.Add('itemFilter', ItemFilter);
        ResponseJson.Add('count', ReservationCount);
        ResponseJson.Add('totalQuantity', TotalQuantity);
        ResponseJson.Add('returned', Returned);
        ResponseJson.Add('more', ReservationCount > Returned);
        ResponseJson.Add('reservations', Rows);
        Argument.SetResponseJson(ResponseJson);
    end;

    [TryFunction]
    local procedure TryApplyFilter(var Reservation: Record "Legacy Stock Reservation"; ItemFilter: Text)
    begin
        Reservation.SetFilter("Item No.", ItemFilter);
    end;

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'list reservations, show all reservations, which items are reserved, reservations for these items, how many reservations, total reserved quantity', Comment = 'is-IS=lista frátekningar, sýna allar frátekningar, hvaða vörur eru fráteknar, frátekningar fyrir þessar vörur, hve margar frátekningar, samtals frátekið magn';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'See the stock reservations in Legacy App, all or by item number filter, with their count and total quantity; at most 100 rows. Gives the count Legacy.Stock.ReleaseAll needs. For one item, use Legacy.Stock.Get; to release them, use Legacy.Stock.ReleaseAll.', Comment = 'is-IS=Sjá birgðafrátekningar í Legacy App, allar eða eftir síu á vörunúmer, með fjölda og heildarmagni; að hámarki 100 línur. Gefur fjöldann sem Legacy.Stock.ReleaseAll þarf. Fyrir eina vöru, notaðu Legacy.Stock.Get; til að losa þær, notaðu Legacy.Stock.ReleaseAll.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: shared parts come from Legacy Stock Contract ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Lists stock reservations in Legacy App, all or those whose item number matches a filter, with the count and the total quantity. At most 100 rows are returned; more is true when there are others. ' +
            'Read-only. Show the user the result before Legacy.Stock.ReleaseAll, which needs its count. Not for one item (use Legacy.Stock.Get).';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Envelope := Parts.FilterEnvelope(false);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Target := Parts.FilterTarget(false);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('itemFilter', 'string', false, 'A Business Central filter on the item number, at most 250 characters: 1896-S, 1896-S|1900-S or 19*. Empty or omitted: all reservations.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        RowsField: JsonObject;
        RowChildren: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('itemFilter', 'string', 'The filter used, as sent; empty for all.'));
        Fields.Add(ContractMgt.ResponseField('count', 'integer', 'The number of matching reservations, also when more is true. Send it to Legacy.Stock.ReleaseAll as expectedCount.'));
        Fields.Add(ContractMgt.ResponseField('totalQuantity', 'number', 'The sum of the quantities of every matching reservation, also when more is true.'));
        Fields.Add(ContractMgt.ResponseField('returned', 'integer', 'The number of rows in reservations, at most 100.'));
        Fields.Add(ContractMgt.ResponseField('more', 'boolean', 'true when count is larger than returned. Narrow the filter to see the rest.'));
        RowsField := ContractMgt.ResponseField('reservations', 'array', 'One element per reservation, at most 100; empty when nothing matches.');
        RowChildren.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number.'));
        RowChildren.Add(ContractMgt.ResponseField('quantity', 'number', 'The reserved quantity.'));
        RowsField.Add('children', RowChildren);
        Fields.Add(RowsField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parts: Codeunit "Legacy Stock Contract";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemFilter'' is ''{filter}'', which is not a valid filter: {reason} Send an item number or a filter such as 1896-S|1900-S or 19*.', 'The filter syntax is invalid; {reason} is Business Central''s own explanation.', 'Fix the filter.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemFilter'' is {length} characters long; the maximum is 250.', 'itemFilter is too long.', 'Shorten the filter.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemFilter'' must be a single value (text or number), not an object or an array.', 'itemFilter is an object or an array.', 'Send it as text.'));
        Parts.AddBodyError(Errors);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads Legacy Stock Reservation.');
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
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.ReleaseAll', 'The user agrees: release the reservations shown here.'));
        Related.Add(ContractMgt.RelatedEntry('Legacy.Stock.Get', 'You want one item only.'));
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
        Examples.Add(ContractMgt.Example('Reservations for items starting with 19',
            '{"type":"Legacy.Stock.List","data":{"itemFilter":"19*"}}',
            '{"itemFilter":"19*","count":2,"totalQuantity":7,"returned":2,"more":false,"reservations":[{"itemNo":"1896-S","quantity":5},{"itemNo":"1900-S","quantity":2}]}'));
        Examples.Add(ContractMgt.Example('Every reservation',
            '{"type":"Legacy.Stock.List"}',
            '{"itemFilter":"","count":3,"totalQuantity":9,"returned":3,"more":false,"reservations":[{"itemNo":"1896-S","quantity":5},{"itemNo":"1900-S","quantity":2},{"itemNo":"1906-S","quantity":2}]}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: the same call gives the same answer until a reservation changes. count and totalQuantity always cover every matching reservation, even when only the first 100 rows are returned. ' +
            'Numbers use a dot as decimal separator. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
