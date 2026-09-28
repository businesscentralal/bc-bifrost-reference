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
///  - optional whole number (maxRows, with a range) and optional true/false (includeBlocked).
/// The sample lists items on purpose: a template must not handle personal data.
/// </summary>
codeunit 50003 "My Item List Impl" implements "Msg Interface ori"
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

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "My Item List Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
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
