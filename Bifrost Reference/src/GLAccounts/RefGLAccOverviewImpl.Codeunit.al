namespace Origo.Bifrost.Reference;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Origo.Bifrost;

/// <summary>
/// Reference.GLAccount.Overview.Get - the reference READ.
///
/// Patterns shown:
///  - the target comes from subject (SystemId or No.) or the body, through the shared resolver,
///    with "not given" and "not found" answered differently (Ref Input.ResolveGLAccount);
///  - SetLoadFields is set on the record BEFORE resolving, so the resolver's Get loads only
///    what this type returns;
///  - optional dates with a stated default (asOfDate = work date) and a cross-parameter rule
///    (fromDate on or before asOfDate), checked before anything is calculated;
///  - FlowFields are calculated explicitly, with the dates they used stated in the response;
///  - numbers are returned as JSON numbers, "no value" as JSON null (never 0 pretending to be a value);
///  - enum values are returned by name (Names/Ordinals), never through Format();
///  - IsEnabled reflects the permissions the type needs, so it is hidden from users who lack them.
/// </summary>
codeunit 90011 "Ref GLAcc Overview Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        FromAfterAsOfErr: Label 'Parameter ''fromDate'' is %1, which is after ''asOfDate'' %2. Send a fromDate on or before the asOfDate, or leave fromDate out to get the balance only.', Comment = '%1 = fromDate received, %2 = asOfDate used, is-IS=Færibreytan ''fromDate'' er %1, sem er eftir ''asOfDate'' %2. Sendu fromDate sem er sami dagur eða fyrr en asOfDate, eða slepptu fromDate til að fá eingöngu stöðuna.';

    procedure IsEnabled(): Boolean
    var
        GLAccount: Record "G/L Account";
        GLEntry: Record "G/L Entry";
    begin
        // The balances are FlowFields over G/L Entry, so both reads are needed.
        exit(GLAccount.ReadPermission() and GLEntry.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"G/L Account");
    end;

    procedure GetDescription(): Text[250]
    begin
        // Selection card: verb + object + what you get + effect + identification + sibling boundary.
        exit('Get a G/L account''s balance as of a date, and its net change for a period: e.g. "what is on account 2910 at the end of August". Read-only. Account by subject (No. or SystemId). For the entries themselves use Data.Records.Get on G/L Entry.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref GLAcc Overview Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        GLAccount: Record "G/L Account";
        GeneralLedgerSetup: Record "General Ledger Setup";
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        NullValue: JsonValue;
        AsOfDate: Date;
        FromDate: Date;
        HasAsOfDate: Boolean;
        HasFromDate: Boolean;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        // 1. Validate everything before calculating anything.
        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;

        GLAccount.SetLoadFields("No.", Name, "Account Type", "Income/Balance", Blocked, "Direct Posting");
        if not RefInput.ResolveGLAccount(Argument, RequestJson, GLAccount) then
            exit;

        if not RefInput.GetOptionalDate(Argument, RequestJson, 'asOfDate', AsOfDate, HasAsOfDate) then
            exit;
        if not HasAsOfDate then
            AsOfDate := WorkDate();
        if not RefInput.GetOptionalDate(Argument, RequestJson, 'fromDate', FromDate, HasFromDate) then
            exit;
        if HasFromDate and (FromDate > AsOfDate) then begin
            Argument.RespondWithError(StrSubstNo(FromAfterAsOfErr, Format(FromDate, 0, 9), Format(AsOfDate, 0, 9)));
            exit;
        end;

        // 2. Calculate. "Balance at Date" sums entries up to the UPPER limit of the Date Filter,
        // whatever its lower limit; "Net Change" sums entries inside the whole Date Filter range.
        // So one filter FromDate..AsOfDate gives both; without fromDate, 0D..AsOfDate gives the balance.
        if HasFromDate then
            GLAccount.SetRange("Date Filter", FromDate, AsOfDate)
        else
            GLAccount.SetRange("Date Filter", 0D, AsOfDate);
        GLAccount.CalcFields("Balance at Date", "Net Change");

        GeneralLedgerSetup.SetLoadFields("LCY Code");
        GeneralLedgerSetup.Get();

        // 3. Answer.
        NullValue.SetValueToNull();
        ResponseJson.Add('accountNo', GLAccount."No.");
        ResponseJson.Add('name', GLAccount.Name);
        ResponseJson.Add('accountType', AccountTypeName(GLAccount));
        ResponseJson.Add('incomeBalance', IncomeBalanceName(GLAccount));
        ResponseJson.Add('currencyCode', GeneralLedgerSetup."LCY Code");
        ResponseJson.Add('asOfDate', Format(AsOfDate, 0, 9));
        ResponseJson.Add('balanceAsOf', GLAccount."Balance at Date");
        if HasFromDate then begin
            ResponseJson.Add('fromDate', Format(FromDate, 0, 9));
            ResponseJson.Add('netChange', GLAccount."Net Change");
        end else begin
            ResponseJson.Add('fromDate', NullValue);
            ResponseJson.Add('netChange', NullValue);
        end;
        ResponseJson.Add('blocked', GLAccount.Blocked);
        ResponseJson.Add('directPosting', GLAccount."Direct Posting");
        Argument.SetResponseJson(ResponseJson);
    end;

    local procedure AccountTypeName(GLAccount: Record "G/L Account"): Text
    var
        Index: Integer;
    begin
        Index := GLAccount."Account Type".Ordinals().IndexOf(GLAccount."Account Type".AsInteger());
        exit(GLAccount."Account Type".Names().Get(Index));
    end;

    local procedure IncomeBalanceName(GLAccount: Record "G/L Account"): Text
    var
        Index: Integer;
    begin
        Index := GLAccount."Income/Balance".Ordinals().IndexOf(GLAccount."Income/Balance".AsInteger());
        exit(GLAccount."Income/Balance".Names().Get(Index));
    end;
}
