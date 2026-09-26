namespace Origo.Bifrost.Reference;

/// <summary>
/// Help for Reference.Customer.Overview.Get. This is the "use card": everything a caller
/// needs to make the first call right. Error texts are copied verbatim from the Labels in
/// Ref Input and Ref Cust Overview Impl - change them together.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90012 "Ref Cust Overview Help"
{
    Access = Internal;

    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.Customer.Overview.Get');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Returns one customer''s financial position: balance, overdue amount, credit limit and');
        Help.AppendLine('available credit, all in local currency (LCY), as of the work date.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only. Nothing is written.');
        Help.AppendLine('');
        Help.AppendLine('Use it to answer "how much does this customer owe us / can we sell more to them?".');
        Help.AppendLine('Not for listing ledger entries or documents - use `Data.Records.Get` on');
        Help.AppendLine('`Cust. Ledger Entry`. Not for changing the credit limit.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the customer');
        Help.AppendLine('Tried in this order; the first one given is used:');
        Help.AppendLine('1. `subject` as a GUID - the customer''s SystemId.');
        Help.AppendLine('2. `subject` as text - the customer number, e.g. `10000` (case-insensitive).');
        Help.AppendLine('3. `customerNo` in the body - the customer number, when `subject` is empty.');
        Help.AppendLine('');
        Help.AppendLine('If nothing is given you get "No customer was given"; if a value is given but no customer');
        Help.AppendLine('has it you get "Customer ''X'' was not found" with your value. The two never mix.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Notes |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `customerNo` | text, max 20 | only if `subject` is empty | Customer number. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.Customer.Overview.Get", "subject": "10000" }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "customerNo": "10000", "name": "Kontorsmaskiner ehf.", "currencyCode": "ISK", "asOfDate": "2026-09-26",');
        Help.AppendLine('  "balanceLcy": 1250000, "overdueLcy": 300000, "hasCreditLimit": true,');
        Help.AppendLine('  "creditLimitLcy": 2000000, "availableCreditLcy": 750000, "blocked": false, "blockedFor": "" }');
        Help.AppendLine('```');
        Help.AppendLine('| Field | JSON type | Meaning |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `balanceLcy` | number | Balance in LCY from entries posted on or before `asOfDate`. |');
        Help.AppendLine('| `overdueLcy` | number | Part of the balance with a due date on or before `asOfDate`. |');
        Help.AppendLine('| `hasCreditLimit` | boolean | false when no credit limit is set (0 in Business Central means "no limit"). |');
        Help.AppendLine('| `creditLimitLcy`, `availableCreditLcy` | number or **null** | null when `hasCreditLimit` is false - never 0. `availableCreditLcy` can be negative. |');
        Help.AppendLine('| `blocked` / `blockedFor` | boolean / text | `blockedFor` is `Ship`, `Invoice` or `All`, or empty when not blocked. |');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Every error is `{ "status": "Error", "error": "...", "hint": "..." }`.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `No customer was given. Send the customer number in subject or as "customerNo", or its SystemId in subject.` | subject empty and no `customerNo`. | Send the customer number in `subject`. |');
        Help.AppendLine('| `Customer ''X'' was not found. Check the number, or search for the customer with Data.Records.Get on table Customer.` | No customer has that number or SystemId. | Check the number; search by name with `Data.Records.Get`. |');
        Help.AppendLine('| `Parameter ''customerNo'' must be a single value (text or number), not an object or an array.` | `customerNo` sent as object or array. | Send it as text. |');
        Help.AppendLine('| `The request body must be a JSON object, for example { "customerNo": "10000" }.` | Body is an array or plain text. | Send an object, or no body at all. |');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs read permission on Customer; users without it do not see this type. No side effects;');
        Help.AppendLine('safe to call any number of times.');
        Help.AppendLine('');
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Amounts are JSON numbers with a dot as decimal separator; `asOfDate` is YYYY-MM-DD.');
        Help.AppendLine('Error texts are translatable; with a translation installed they follow the caller''s lcid.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Data.Records.Get` on `Cust. Ledger Entry` - the entries behind the balance.');
        Help.AppendLine('- `Reference.ServiceVisit.Create` - log a visit for the same customer.');
        exit(Help.ToText());
    end;
}
