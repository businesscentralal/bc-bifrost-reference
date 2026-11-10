namespace MyCompany.MyBifrostApp;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// MyApp.Item.Summary.Get - the sample READ. Replace it with your own first read, or delete it.
///
/// Patterns shown:
///  - the target comes from subject (SystemId or No.) or the body, through the shared resolver,
///    with "not given" and "not found" answered differently (My Input.ResolveItem);
///  - SetLoadFields is set on the record BEFORE resolving, so the resolver's Get loads only
///    what this type returns;
///  - the optional date is strict YYYY-MM-DD, defaults to the work date and is echoed back;
///  - FlowFields are calculated explicitly, with the date filter stated in the response;
///  - numbers are JSON numbers, "no value" is JSON null (never an empty text pretending to be a value);
///  - IsEnabled reflects the permission the type needs, so it is hidden from users who lack it;
///  - the contract says subject is 'optional' and lists the target forms in the order they are tried.
/// The sample reads items on purpose: a template must not handle personal data.
/// </summary>
codeunit 50001 "My Item Summary Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

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
        // TODO: rewrite the selection card for your own type (verb + object + what you get + effect + identification + sibling boundary; at most 250 characters).
        exit('Get one item''s description, base unit, unit price and inventory as of a date (default: the work date). Read-only. Item by subject (No. or SystemId). For many items use MyApp.Item.List; for ledger entries, Data.Records.Get.');
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
        NullValue: JsonValue;
        AsOfDate: Date;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not MyInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not MyInput.GetOptionalDate(Argument, RequestJson, 'asOfDate', WorkDate(), AsOfDate) then
            exit;

        Item.SetLoadFields("No.", Description, "Base Unit of Measure", "Unit Price", Blocked);
        if not MyInput.ResolveItem(Argument, RequestJson, Item) then
            exit;

        // "Inventory" ignores the Date Filter; "Net Change" over 0D..AsOfDate is the quantity on
        // hand as of that date (the sum of item ledger entries posted on or before it).
        Item.SetRange("Date Filter", 0D, AsOfDate);
        Item.CalcFields("Net Change");

        NullValue.SetValueToNull();
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('description', Item.Description);
        // An empty code means "not set up", so it is returned as null, never as "".
        if Item."Base Unit of Measure" <> '' then
            ResponseJson.Add('baseUnitOfMeasure', Item."Base Unit of Measure")
        else
            ResponseJson.Add('baseUnitOfMeasure', NullValue);
        ResponseJson.Add('unitPrice', Item."Unit Price");
        ResponseJson.Add('asOfDate', Format(AsOfDate, 0, 9));
        ResponseJson.Add('inventory', Item."Net Change");
        ResponseJson.Add('blocked', Item.Blocked);
        Argument.SetResponseJson(ResponseJson);
    end;

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item price and stock, how many do we have, what does this item cost, inventory of an item, quantity on hand, item summary', Comment = 'is-IS=verð og birgðir vöru, hve mörg eigum við, hvað kostar þessi vara, birgðir vöru, magn á lager, yfirlit vöru';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'One item''s description, base unit, unit price and quantity on hand as of a date. For many items, use MyApp.Item.List; for the entries behind the inventory, use Data.Records.Get on Item Ledger Entry.', Comment = 'is-IS=Lýsing, grunneining, einingarverð og magn á lager einnar vöru á tilteknum degi. Fyrir margar vörur, notaðu MyApp.Item.List; fyrir færslurnar á bak við birgðirnar, notaðu Data.Records.Get á Item Ledger Entry.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------
    // TODO: rename MyApp.Item.Summary.Get in every chapter below together with the enum value.

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns one item''s description, base unit of measure, unit price and inventory (quantity on hand) as of a date: the work date unless you send asOfDate. ' +
            'Use it to answer "how many of this item do we have, and what does it cost?". Not for many items at once (use MyApp.Item.List), and not for the entries behind the inventory (use Data.Records.Get on Item Ledger Entry).';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'optional');
        Subject.Add('description', 'The item: its SystemId (GUID) or its number. Leave it empty to send itemNo in data instead.');
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
        // Tried in this order; the first one given is used.
        Target.Add(ContractMgt.TargetEntry('subject', 'SystemId (GUID)', 'The item''s SystemId. Tried first.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'item number', 'The item number, for example 1896-S, case-insensitive.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item number', 'Used only when subject is empty.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'The item number, at most 20 characters. Needed only when subject is empty.'));
        Parameters.Add(ContractMgt.Parameter('asOfDate', 'string', false, 'A date in the format YYYY-MM-DD. The inventory counts entries posted on or before it. Omitted: the work date. 26.09.2026 is refused.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'The item description.'));
        Fields.Add(ContractMgt.ResponseField('baseUnitOfMeasure', 'string', 'The base unit of measure, or null when none is set up; never "".'));
        Fields.Add(ContractMgt.ResponseField('unitPrice', 'number', 'The unit price on the item card, in local currency (LCY); 0 when none is set.'));
        Fields.Add(ContractMgt.ResponseField('asOfDate', 'string', 'The date the inventory is for, YYYY-MM-DD: yours, or the work date.'));
        Fields.Add(ContractMgt.ResponseField('inventory', 'number', 'Quantity on hand in the base unit, from entries posted on or before asOfDate; 0 when there are none.'));
        Fields.Add(ContractMgt.ResponseField('blocked', 'boolean', 'true when the item is blocked.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Verbatim from the Labels in My Input; {placeholders} stand for its %1, %2.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('No item was given. Send the item number in subject or as "itemNo", or its SystemId in subject.', 'subject is empty and data has no itemNo.', 'Send the item number in subject.'));
        Errors.Add(ContractMgt.TextErrorEntry('Item ''{item}'' was not found. Check the number, or search for the item with Data.Records.Get on table Item.', 'No item has that number or SystemId.', 'Check the number, or search by description with Data.Records.Get.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''asOfDate'' has the value ''{value}'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.', 'asOfDate is not YYYY-MM-DD, for example 26.09.2026.', 'Send the date as YYYY-MM-DD.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is {length} characters long; the maximum is {maximum}.', 'itemNo is longer than 20 characters, or asOfDate longer than 30.', 'Send the item number, or the date as YYYY-MM-DD.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' must be a single value (text or number), not an object or an array.', 'itemNo or asOfDate is an object or an array.', 'Send it as text.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object, or no body at all.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads Item and calculates its Net Change FlowField over Item Ledger Entry.');
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
        Related.Add(ContractMgt.RelatedEntry('MyApp.Item.List', 'You want many items, or need to find the item number.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want the entries behind the inventory (table Item Ledger Entry), or to search items by description (table Item).'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('MyApp.Item.List', 'Optional: find the item number.'));
        Steps.Add(ContractMgt.WorkflowStep('MyApp.Item.Summary.Get', 'Get the item''s price and inventory.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Standalone when you know the item number.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Price and inventory of an item on a date',
            '{"type":"MyApp.Item.Summary.Get","subject":"1896-S","data":{"asOfDate":"2026-09-26"}}',
            '{"itemNo":"1896-S","description":"ATHENS Desk","baseUnitOfMeasure":"PCS","unitPrice":1000.8,"asOfDate":"2026-09-26","inventory":12,"blocked":false}'));
        Examples.Add(ContractMgt.Example('A date in the wrong format',
            '{"type":"MyApp.Item.Summary.Get","subject":"1896-S","data":{"asOfDate":"26.09.2026"}}',
            '{"status":"Error","error":"Parameter ''asOfDate'' has the value ''26.09.2026'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: two identical calls give the same answer unless entries were posted or the item card changed in between. ' +
            '"No item was given" and "Item ''X'' was not found" never mix: the first means nothing identified the item, the second echoes the value that matched no item. ' +
            'Prices and quantities are JSON numbers with a dot as decimal separator; dates are YYYY-MM-DD in and out. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
