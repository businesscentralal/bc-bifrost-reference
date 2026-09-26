namespace Origo.Bifrost.Reference;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>
/// Reference.Customer.Overview.Get - the reference READ.
///
/// Patterns shown:
///  - the target comes from subject (SystemId or No.) or the body, through the shared resolver,
///    with "not given" and "not found" answered differently (Ref Input.ResolveCustomer);
///  - SetLoadFields is set on the record BEFORE resolving, so the resolver's Get loads only
///    what this type returns;
///  - FlowFields are calculated explicitly, with the date filter stated in the response;
///  - numbers are returned as JSON numbers, "no value" as JSON null (never 0 pretending to be a value);
///  - enum values are returned by name (Names/Ordinals), never through Format();
///  - IsEnabled reflects the permission the type needs, so it is hidden from users who lack it.
/// </summary>
codeunit 90011 "Ref Cust Overview Impl" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Customer: Record Customer;
    begin
        exit(Customer.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Customer);
    end;

    procedure GetDescription(): Text[250]
    begin
        // Selection card: verb + object + what you get + effect + identification + sibling boundary.
        exit('Get what a customer owes: balance, overdue amount, credit limit and available credit in one call. Read-only. Customer by subject (No. or SystemId). For ledger entries use Data.Records.Get; for a credit check only, Customer.CreditLimit.Get.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref Cust Overview Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Customer: Record Customer;
        GeneralLedgerSetup: Record "General Ledger Setup";
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        NullValue: JsonValue;
        AsOfDate: Date;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;

        Customer.SetLoadFields("No.", Name, Blocked, "Credit Limit (LCY)");
        if not RefInput.ResolveCustomer(Argument, RequestJson, Customer) then
            exit;

        // "Balance (LCY)" ignores the Date Filter; "Net Change (LCY)" over 0D..AsOfDate is the
        // balance as of that date, and "Balance Due (LCY)" uses the filter's upper limit as due date.
        AsOfDate := WorkDate();
        Customer.SetRange("Date Filter", 0D, AsOfDate);
        Customer.CalcFields("Net Change (LCY)", "Balance Due (LCY)");

        GeneralLedgerSetup.SetLoadFields("LCY Code");
        GeneralLedgerSetup.Get();

        ResponseJson.Add('customerNo', Customer."No.");
        ResponseJson.Add('name', Customer.Name);
        ResponseJson.Add('currencyCode', GeneralLedgerSetup."LCY Code");
        ResponseJson.Add('asOfDate', Format(AsOfDate, 0, 9));
        ResponseJson.Add('balanceLcy', Customer."Net Change (LCY)");
        ResponseJson.Add('overdueLcy', Customer."Balance Due (LCY)");
        ResponseJson.Add('hasCreditLimit', Customer."Credit Limit (LCY)" <> 0);
        NullValue.SetValueToNull();
        if Customer."Credit Limit (LCY)" <> 0 then begin
            ResponseJson.Add('creditLimitLcy', Customer."Credit Limit (LCY)");
            ResponseJson.Add('availableCreditLcy', Customer."Credit Limit (LCY)" - Customer."Net Change (LCY)");
        end else begin
            ResponseJson.Add('creditLimitLcy', NullValue);
            ResponseJson.Add('availableCreditLcy', NullValue);
        end;
        ResponseJson.Add('blocked', Customer.Blocked <> Customer.Blocked::" ");
        ResponseJson.Add('blockedFor', BlockedName(Customer));
        Argument.SetResponseJson(ResponseJson);
    end;

    local procedure BlockedName(Customer: Record Customer): Text
    var
        Index: Integer;
    begin
        if Customer.Blocked = Customer.Blocked::" " then
            exit('');
        Index := Customer.Blocked.Ordinals().IndexOf(Customer.Blocked.AsInteger());
        exit(Customer.Blocked.Names().Get(Index));
    end;
}
