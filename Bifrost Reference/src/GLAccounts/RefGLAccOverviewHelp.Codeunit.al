namespace Origo.Bifrost.Reference;

/// <summary>
/// Help for Reference.GLAccount.Overview.Get. This is the "use card": everything a caller
/// needs to make the first call right. Error texts are copied verbatim from the Labels in
/// Ref Input and Ref GLAcc Overview Impl - change them together.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90012 "Ref GLAcc Overview Help"
{
    Access = Internal;

    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.GLAccount.Overview.Get');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Returns one G/L account''s balance as of a date and, when you send a start date, its net');
        Help.AppendLine('change for the period from that date. All amounts are in local currency (LCY).');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only. Nothing is written.');
        Help.AppendLine('');
        Help.AppendLine('Use it to answer "what is on account 2910 at the end of August?" or "how much moved on');
        Help.AppendLine('this account in September?". Not for listing the entries behind the amount - use');
        Help.AppendLine('`Data.Records.Get` on `G/L Entry`. Not for budgets, dimensions or changing the account.');
        Help.AppendLine('');
        Help.AppendLine('Heading, Total, Begin-Total and End-Total accounts are answered too, but their amounts are');
        Help.AppendLine('totals over the accounts in their Totaling range (a Heading has none, so 0), not');
        Help.AppendLine('postings on the account itself. Check `accountType` before treating an amount as a posting balance.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('Standalone. When you know the account by name only, find its number first with');
        Help.AppendLine('`Data.Records.Get` on `G/L Account`; afterwards, `Data.Records.Get` on `G/L Entry` lists the');
        Help.AppendLine('entries behind the amount.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the account');
        Help.AppendLine('Tried in this order; the first one given is used:');
        Help.AppendLine('1. `subject` as a GUID - the account''s SystemId.');
        Help.AppendLine('2. `subject` as text - the account number, e.g. `2910` (case-insensitive).');
        Help.AppendLine('3. `accountNo` in the body - the account number, when `subject` is empty.');
        Help.AppendLine('');
        Help.AppendLine('If nothing is given you get "No G/L account was given"; if a value is given but no account');
        Help.AppendLine('has it you get "G/L account ''X'' was not found" with your value. The two never mix.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `accountNo` | text, max 20 | only if `subject` is empty | G/L account number. |');
        Help.AppendLine('| `asOfDate` | date **YYYY-MM-DD** | no, default the work date | The balance includes entries posted on or before this date. `31.08.2026` is refused. |');
        Help.AppendLine('| `fromDate` | date **YYYY-MM-DD** | no | Start of the net-change period. On or before `asOfDate`. Leave it out for the balance only. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.GLAccount.Overview.Get", "subject": "2910",');
        Help.AppendLine('  "data": { "asOfDate": "2026-08-31", "fromDate": "2026-08-01" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "accountNo": "2910", "name": "Bank, Checking", "accountType": "Posting",');
        Help.AppendLine('  "incomeBalance": "Balance Sheet", "currencyCode": "ISK", "asOfDate": "2026-08-31",');
        Help.AppendLine('  "balanceAsOf": 1250000, "fromDate": "2026-08-01", "netChange": -300000,');
        Help.AppendLine('  "blocked": false, "directPosting": true }');
        Help.AppendLine('```');
        Help.AppendLine('| Field | JSON type | Meaning |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `accountNo`, `name` | text | The account. |');
        Help.AppendLine('| `accountType` | text | `Posting`, `Heading`, `Total`, `Begin-Total` or `End-Total`. Only `Posting` accounts carry postings of their own. |');
        Help.AppendLine('| `incomeBalance` | text | `Income Statement` or `Balance Sheet`. |');
        Help.AppendLine('| `currencyCode` | text | The local currency the amounts are in. |');
        Help.AppendLine('| `asOfDate` | text, YYYY-MM-DD | The date used: yours, or the work date when you sent none. |');
        Help.AppendLine('| `balanceAsOf` | number | Sum of all entries posted on or before `asOfDate`. |');
        Help.AppendLine('| `fromDate` | text, YYYY-MM-DD, or **null** | null when you sent no `fromDate`. |');
        Help.AppendLine('| `netChange` | number or **null** | Sum of entries from `fromDate` to `asOfDate`, both included. null when no `fromDate` was sent - never 0. |');
        Help.AppendLine('| `blocked` | boolean | true when the account is blocked for posting. |');
        Help.AppendLine('| `directPosting` | boolean | true when journals may post to the account directly. |');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Every error is `{ "status": "Error", "error": "...", "hint": "..." }`.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `No G/L account was given. Send the account number in subject or as "accountNo", or its SystemId in subject.` | subject empty and no `accountNo`. | Send the account number in `subject`. |');
        Help.AppendLine('| `G/L account ''X'' was not found. Check the number, or search for the account with Data.Records.Get on table G/L Account.` | No account has that number or SystemId. | Check the number; search by name with `Data.Records.Get`. |');
        Help.AppendLine('| `Parameter ''asOfDate'' has the value ''31.08.2026'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.` | Wrong date format (same text for `fromDate`). | Send `2026-08-31`. |');
        Help.AppendLine('| `Parameter ''fromDate'' is 2026-09-01, which is after ''asOfDate'' 2026-08-31. Send a fromDate on or before the asOfDate, or leave fromDate out to get the balance only.` | The period ends before it starts. | Swap the dates, or leave `fromDate` out. |');
        Help.AppendLine('| `Parameter ''accountNo'' must be a single value (text or number), not an object or an array.` | `accountNo` (or a date) sent as object or array. | Send it as text. |');
        Help.AppendLine('| `Parameter ''asOfDate'' is 40 characters long; the maximum is 30.` | A date parameter far too long to be a date. | Send YYYY-MM-DD. |');
        Help.AppendLine('| `The request body must be a JSON object, for example { "accountNo": "2910" }.` | Body is an array or plain text. | Send an object, or no body at all. |');
        Help.AppendLine('');
        Help.AppendLine('## Safe retries / repeat');
        Help.AppendLine('Read-only; safe to repeat. The same call gives the same amounts until something is posted.');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs read permission on G/L Account and G/L Entry; users without them do not see this type.');
        Help.AppendLine('No side effects.');
        Help.AppendLine('');
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Amounts are JSON numbers with a dot as decimal separator, debit positive and credit negative;');
        Help.AppendLine('dates are YYYY-MM-DD. Enum values (`accountType`, `incomeBalance`) are English names in every');
        Help.AppendLine('language. Error texts are translatable; with a translation installed they follow the caller''s lcid.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Data.Records.Get` on `G/L Entry` - the entries behind the amounts.');
        Help.AppendLine('- `Data.Records.Get` on `G/L Account` - find an account by name.');
        Help.AppendLine('- `Help.Reference.Get` - the other types in this app.');
        exit(Help.ToText());
    end;
}
