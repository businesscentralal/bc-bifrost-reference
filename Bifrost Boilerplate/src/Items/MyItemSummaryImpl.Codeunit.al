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
///  - IsEnabled reflects the permission the type needs, so it is hidden from users who lack it.
/// The sample reads items on purpose: a template must not handle personal data.
/// </summary>
codeunit 50001 "My Item Summary Impl" implements "Msg Interface ori"
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

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "My Item Summary Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
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
}
