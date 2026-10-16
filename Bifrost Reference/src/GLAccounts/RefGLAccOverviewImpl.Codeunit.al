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
codeunit 90011 "Ref GLAcc Overview Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'account balance, balance of a G/L account, net change on an account, how much is on account, movement in a period, ledger account balance at month end', Comment = 'is-IS=staða lykils, staða fjárhagslykils, hreyfing á lykli, hvað er á lyklinum, hreyfing á tímabili, staða fjárhagslykils í lok mánaðar';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'One G/L account''s balance as of a date and, optionally, its net change for a period, in local currency. For the entries behind the amount, use Data.Records.Get on G/L Entry; to find an account by name, use Data.Records.Get on G/L Account.', Comment = 'is-IS=Staða eins fjárhagslykils á tilteknum degi og, ef óskað er, hreyfing hans á tímabili, í staðbundinni mynt. Fyrir færslurnar á bak við upphæðina, notaðu Data.Records.Get á G/L Entry; til að finna lykil eftir heiti, notaðu Data.Records.Get á G/L Account.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns one G/L account''s balance as of a date and, when you send a start date, its net change for the period from that date. All amounts are in local currency (LCY). ' +
            'Use it to answer "what is on account 2910 at the end of August?" or "how much moved on this account in September?". ' +
            'Not for listing the entries behind the amount (use Data.Records.Get on G/L Entry), and not for budgets, dimensions or changing the account.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'optional');
        Subject.Add('description', 'The account: its SystemId (GUID) or its number. Leave it empty to send accountNo in data instead.');
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
        Target.Add(ContractMgt.TargetEntry('subject', 'SystemId (GUID)', 'The account''s SystemId. Tried first.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'account number', 'The account number, for example 2910, case-insensitive.'));
        Target.Add(ContractMgt.TargetEntry('data.accountNo', 'account number', 'Used only when subject is empty.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('accountNo', 'string', false, 'The G/L account number, at most 20 characters. Needed only when subject is empty.'));
        Parameters.Add(ContractMgt.Parameter('asOfDate', 'string', false, 'A date in the format YYYY-MM-DD. The balance includes entries posted on or before it. Omitted: the work date. 31.08.2026 is refused.'));
        Parameters.Add(ContractMgt.Parameter('fromDate', 'string', false, 'A date in the format YYYY-MM-DD, on or before asOfDate: the start of the net-change period. Omitted: balance only, netChange is null.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('accountNo', 'string', 'The account number.'));
        Fields.Add(ContractMgt.ResponseField('name', 'string', 'The account name.'));
        Fields.Add(ContractMgt.ResponseField('accountType', 'string', 'Posting, Heading, Total, Begin-Total or End-Total. Only Posting accounts carry postings of their own; the others answer totals over their Totaling range (a Heading has none, so 0).'));
        Fields.Add(ContractMgt.ResponseField('incomeBalance', 'string', 'Income Statement or Balance Sheet.'));
        Fields.Add(ContractMgt.ResponseField('currencyCode', 'string', 'The local currency the amounts are in.'));
        Fields.Add(ContractMgt.ResponseField('asOfDate', 'string', 'The date used, YYYY-MM-DD: yours, or the work date when you sent none.'));
        Fields.Add(ContractMgt.ResponseField('balanceAsOf', 'number', 'The sum of all entries posted on or before asOfDate. Debit positive, credit negative.'));
        Fields.Add(ContractMgt.ResponseField('fromDate', 'string', 'The start of the period, YYYY-MM-DD, or null when you sent no fromDate.'));
        Fields.Add(ContractMgt.ResponseField('netChange', 'number', 'The sum of entries from fromDate to asOfDate, both included. null when no fromDate was sent, never 0.'));
        Fields.Add(ContractMgt.ResponseField('blocked', 'boolean', 'true when the account is blocked for posting.'));
        Fields.Add(ContractMgt.ResponseField('directPosting', 'boolean', 'true when journals may post to the account directly.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('No G/L account was given. Send the account number in subject or as "accountNo", or its SystemId in subject.', 'subject is empty and data has no accountNo.', 'Send the account number in subject.'));
        Errors.Add(ContractMgt.TextErrorEntry('G/L account ''{account}'' was not found. Check the number, or search for the account with Data.Records.Get on table G/L Account.', 'No account has that number or SystemId.', 'Check the number, or search by name with Data.Records.Get.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' has the value ''{value}'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.', 'asOfDate or fromDate is not YYYY-MM-DD, for example 31.08.2026.', 'Send the date as YYYY-MM-DD, for example 2026-08-31.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''fromDate'' is {fromDate}, which is after ''asOfDate'' {asOfDate}. Send a fromDate on or before the asOfDate, or leave fromDate out to get the balance only.', 'The period ends before it starts.', 'Swap the dates, or leave fromDate out.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' must be a single value (text or number), not an object or an array.', 'accountNo, asOfDate or fromDate is an object or an array.', 'Send it as text.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is {length} characters long; the maximum is {maximum}.', 'accountNo is longer than 20 characters, or a date longer than 30.', 'Send the account number, or the date as YYYY-MM-DD.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object, or no body at all.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads G/L Account and calculates its balance FlowFields over G/L Entry.');
        Effect.Add('idempotent', true);
        Preconditions.Add('The caller can read G/L Account and G/L Entry; without it the type is not offered.');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want the entries behind the amounts (table G/L Entry), or need to find an account by name (table G/L Account).'));
        Related.Add(ContractMgt.RelatedEntry('Help.Reference.Get', 'You want the other types in this app.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', 'Optional: find the account number on table G/L Account when you know the account by name only.'));
        Steps.Add(ContractMgt.WorkflowStep('Reference.GLAccount.Overview.Get', 'Get the balance and, with fromDate, the net change.'));
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', 'Optional: list the entries behind the amount on table G/L Entry.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Standalone when you know the account number; the other steps are only needed to find the account or explain the amount.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Balance at the end of August and the net change for August',
            '{"type":"Reference.GLAccount.Overview.Get","subject":"2910","data":{"asOfDate":"2026-08-31","fromDate":"2026-08-01"}}',
            '{"accountNo":"2910","name":"Bank, Checking","accountType":"Posting","incomeBalance":"Balance Sheet","currencyCode":"ISK","asOfDate":"2026-08-31","balanceAsOf":1250000,"fromDate":"2026-08-01","netChange":-300000,"blocked":false,"directPosting":true}'));
        Examples.Add(ContractMgt.Example('Balance only, as of the work date',
            '{"type":"Reference.GLAccount.Overview.Get","data":{"accountNo":"2910"}}',
            '{"accountNo":"2910","name":"Bank, Checking","accountType":"Posting","incomeBalance":"Balance Sheet","currencyCode":"ISK","asOfDate":"2026-09-26","balanceAsOf":1180000,"fromDate":null,"netChange":null,"blocked":false,"directPosting":true}'));
        Examples.Add(ContractMgt.Example('A date in the wrong format',
            '{"type":"Reference.GLAccount.Overview.Get","subject":"2910","data":{"asOfDate":"31.08.2026"}}',
            '{"status":"Error","error":"Parameter ''asOfDate'' has the value ''31.08.2026'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: the same call gives the same amounts until something is posted. ' +
            '"No G/L account was given" and "G/L account ''X'' was not found" never mix: the first means nothing identified the account, the second echoes the value that matched no account. ' +
            'Check accountType before treating an amount as a posting balance: Heading, Total, Begin-Total and End-Total accounts answer totals over their Totaling range. ' +
            'Amounts are JSON numbers with a dot as decimal separator; dates are YYYY-MM-DD. Enum values (accountType, incomeBalance) are English names in every language. Error texts follow lcid when a translation is installed.';
        exit(true);
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
