namespace MyCompany.MyBifrostApp;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// MyApp.Item.List - the sample CAPPED LIST. Replace it with your own list, or delete it.
///
/// Patterns shown:
///  - bounded on purpose: at most 100 rows are returned, and "more" says when there are others;
///  - "count" is the database count of every matching row, so it stays true when "more" is true;
///  - a filter from the caller is applied in a try function, so a bad filter is answered as a
///    parameter error that names the parameter instead of a raw platform error;
///  - optional whole number (maxRows, with a range) and optional true/false (includeBlocked);
///  - the contract describes an array in the response with its children.
/// The sample lists items on purpose: a template must not handle personal data.
/// </summary>
codeunit 50003 "My Item List Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        FilterErr: Label 'Parameter ''itemFilter'' is ''%1'', which is not a valid filter: %2 Send an item number or a filter such as 1000..1999 or 19*.', Comment = '%1 = filter received, %2 = platform error text, is-IS=Færibreytan ''itemFilter'' er ''%1'', sem er ekki gild sía: %2 Sendu vörunúmer eða síu eins og 1000..1999 eða 19*.';

    procedure IsEnabled(): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        // TODO: rewrite the selection card for your own type (at most 250 characters; say "Read-only" for an Outbound type).
        exit('List items, all or by number filter, with the total count (max 100 rows; more says when there are others). Read-only. Blocked items only on request. For one item''s price and inventory use MyApp.Item.Summary.Get.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        MyInput: Codeunit "My Input";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        ItemFilter: Text;
        FilterFound: Boolean;
        IncludeBlocked: Boolean;
        MaxRows: Integer;
        Returned: Integer;
        ItemCount: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Returned := 0;

        if not MyInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not MyInput.GetOptionalText(Argument, RequestJson, 'itemFilter', 250, ItemFilter, FilterFound) then
            exit;
        if not MyInput.GetOptionalInteger(Argument, RequestJson, 'maxRows', 1, 100, 100, MaxRows) then
            exit;
        if not MyInput.GetOptionalBoolean(Argument, RequestJson, 'includeBlocked', false, IncludeBlocked) then
            exit;

        if not IncludeBlocked then
            Item.SetRange(Blocked, false);
        if FilterFound then
            if not TryApplyFilter(Item, ItemFilter) then begin
                Argument.RespondWithError(StrSubstNo(FilterErr, ItemFilter, GetLastErrorText()));
                exit;
            end;

        // Count from the database, rows capped: the call costs the same for 10 rows or 10,000.
        ItemCount := Item.Count();

        Item.SetLoadFields("No.", Description, Blocked);
        if Item.FindSet() then
            repeat
                Clear(Row);
                Row.Add('itemNo', Item."No.");
                Row.Add('description', Item.Description);
                Row.Add('blocked', Item.Blocked);
                Rows.Add(Row);
                Returned += 1;
            until (Item.Next() = 0) or (Returned >= MaxRows);

        ResponseJson.Add('itemFilter', ItemFilter);
        ResponseJson.Add('includeBlocked', IncludeBlocked);
        ResponseJson.Add('count', ItemCount);
        ResponseJson.Add('returned', Returned);
        ResponseJson.Add('more', ItemCount > Returned);
        ResponseJson.Add('items', Rows);
        Argument.SetResponseJson(ResponseJson);
    end;

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'list items, show items, which items do we have, items starting with, find items by number, how many items', Comment = 'is-IS=lista vörur, sýna vörur, hvaða vörur eigum við, vörur sem byrja á, finna vörur eftir númeri, hve margar vörur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'List items by item number filter, with the total count; at most 100 rows. Not for one item''s price and inventory: use MyApp.Item.Summary.Get. To search by description or another field, use Data.Records.Get on Item.', Comment = 'is-IS=Lista vörur eftir síu á vörunúmer, með heildarfjölda; að hámarki 100 línur. Ekki fyrir verð og birgðir einnar vöru: notaðu MyApp.Item.Summary.Get. Til að leita eftir lýsingu eða öðrum reit, notaðu Data.Records.Get á Item.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------
    // TODO: rename MyApp.Item.List in every chapter below together with the enum value.

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Lists items, all or those whose number matches a filter, with the total count. At most 100 rows are returned (fewer with maxRows); more is true when there are others. ' +
            'Blocked items are left out unless you send "includeBlocked": true. Not for one item''s price and inventory (use MyApp.Item.Summary.Get), and not for a search by description (use Data.Records.Get on table Item).';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The items are chosen by itemFilter and includeBlocked in data.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemFilter', 'item number filter', 'Every item whose number matches, blocked ones only with includeBlocked. Empty or absent: all items. A filter that matches nothing is not an error: count is 0.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('itemFilter', 'string', false, 'A Business Central filter on the item number, at most 250 characters: 1896-S, 1000..1999 or 19*. Omitted: all items.'));
        Parameters.Add(ContractMgt.Parameter('maxRows', 'integer', false, 'The most rows to return, 1 to 100. Omitted: 100.'));
        Parameters.Add(ContractMgt.Parameter('includeBlocked', 'boolean', false, 'true also returns blocked items. Omitted: false.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        ItemsField: JsonObject;
        ItemChildren: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('itemFilter', 'string', 'The filter used, as sent; empty for all.'));
        Fields.Add(ContractMgt.ResponseField('includeBlocked', 'boolean', 'Whether blocked items were included.'));
        Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Every matching item, also when more is true.'));
        Fields.Add(ContractMgt.ResponseField('returned', 'integer', 'The number of rows in items.'));
        Fields.Add(ContractMgt.ResponseField('more', 'boolean', 'true when count is larger than returned. Narrow the filter to see the rest.'));
        // An array is one field with its element's fields as children.
        ItemsField := ContractMgt.ResponseField('items', 'array', 'One element per item, at most maxRows; empty when nothing matches.');
        ItemChildren.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number.'));
        ItemChildren.Add(ContractMgt.ResponseField('description', 'string', 'The item description.'));
        ItemChildren.Add(ContractMgt.ResponseField('blocked', 'boolean', 'true when the item is blocked.'));
        ItemsField.Add('children', ItemChildren);
        Fields.Add(ItemsField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Verbatim from the Labels in My Input and FilterErr above; {placeholders} stand for %1, %2.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemFilter'' is ''{filter}'', which is not a valid filter: {reason} Send an item number or a filter such as 1000..1999 or 19*.', 'The filter syntax is invalid; {reason} is Business Central''s own explanation.', 'Fix the filter.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''maxRows'' has the value ''{value}'', which is not a whole number. Send for example 12.', 'maxRows is not a whole number.', 'Send for example 20.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''maxRows'' is {value}, but it must be between 1 and 100.', 'maxRows is out of range.', 'Send 1 to 100.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''includeBlocked'' has the value ''{value}''. Send true or false, without quotes.', 'includeBlocked is not true or false, for example "yes".', 'Send true or false.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is {length} characters long; the maximum is {maximum}.', 'itemFilter is longer than 250 characters, or maxRows longer than 20.', 'Shorten it.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' must be a single value (text or number), not an object or an array.', 'A parameter is an object or an array.', 'Send a single value.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object, or no body at all.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads Item.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can read Item; without it the type is not offered.');
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
        Related.Add(ContractMgt.RelatedEntry('MyApp.Item.Summary.Get', 'You want one item''s price and inventory.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want to search items by description or another field (table Item).'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('MyApp.Item.List', 'Find the items.'));
        Steps.Add(ContractMgt.WorkflowStep('MyApp.Item.Summary.Get', 'Optional: one item''s price and inventory, with its itemNo as subject.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'List, pick an item, then its summary.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Items starting with 19, two rows at most',
            '{"type":"MyApp.Item.List","data":{"itemFilter":"19*","maxRows":2}}',
            '{"itemFilter":"19*","includeBlocked":false,"count":5,"returned":2,"more":true,"items":[{"itemNo":"1900-S","description":"PARIS Guest Chair, black","blocked":false},{"itemNo":"1906-S","description":"ATHENS Mobile Pedestal","blocked":false}]}'));
        Examples.Add(ContractMgt.Example('maxRows out of range',
            '{"type":"MyApp.Item.List","data":{"maxRows":500}}',
            '{"status":"Error","error":"Parameter ''maxRows'' is 500, but it must be between 1 and 100."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: the same call gives the same answer until items change. count always covers every matching item, even when only the first rows are returned. ' +
            'Numbers are JSON numbers. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;

    [TryFunction]
    local procedure TryApplyFilter(var Item: Record Item; ItemFilter: Text)
    begin
        // Read-only: a try function is the right tool here - it writes nothing.
        Item.SetFilter("No.", ItemFilter);
        // Touch the database once, so an invalid filter fails here and not later.
        if Item.IsEmpty() then
            exit;
    end;
}
