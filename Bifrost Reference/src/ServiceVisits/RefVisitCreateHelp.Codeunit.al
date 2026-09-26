namespace Origo.Bifrost.Reference;

/// <summary>
/// Help ("use card") for Reference.ServiceVisit.Create. Error texts are verbatim copies of the
/// Labels in Ref Input and Ref Visit Create Impl.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90015 "Ref Visit Create Help"
{
    Access = Internal;

    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.ServiceVisit.Create');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Logs one service visit at a customer: the date it happened, the hours spent and a short');
        Help.AppendLine('description.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Commits. One `Ref Service Visit` record is inserted - or none, when the same');
        Help.AppendLine('`externalId` was already used (see Safe retries).');
        Help.AppendLine('');
        Help.AppendLine('Not for time sheets, project journal lines or resource usage - those are other apps.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('Optional: `Reference.Customer.Overview.Get` to check the customer first -> this type.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the customer');
        Help.AppendLine('1. `subject` as a GUID - the customer''s SystemId.');
        Help.AppendLine('2. `subject` as text - the customer number.');
        Help.AppendLine('3. `customerNo` in the body, when `subject` is empty.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `customerNo` | text, max 20 | only if `subject` is empty | Must exist and not be blocked for All. |');
        Help.AppendLine('| `visitDate` | date **YYYY-MM-DD** | yes | On or before the work date. `26.09.2026` is refused. |');
        Help.AppendLine('| `hours` | number | yes | 0.25 to 24. Dot as decimal separator. |');
        Help.AppendLine('| `description` | text, max 100 | no | |');
        Help.AppendLine('| `externalId` | text, max 50 | no | Your own id for this visit. Makes the call safe to retry. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.ServiceVisit.Create", "subject": "10000",');
        Help.AppendLine('  "data": { "visitDate": "2026-09-25", "hours": 1.5, "description": "Annual check", "externalId": "CRM-4711" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "entryNo": 12, "created": true, "customerNo": "10000", "visitDate": "2026-09-25",');
        Help.AppendLine('  "hours": 1.5, "description": "Annual check", "externalId": "CRM-4711" }');
        Help.AppendLine('```');
        Help.AppendLine('`created` is false when the `externalId` already existed; the response then describes the');
        Help.AppendLine('visit that was created by the earlier call, and nothing new is written.');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Nothing is written when any of these is returned.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `No customer was given. Send the customer number in subject or as "customerNo", or its SystemId in subject.` | No customer in subject or body. | Send the customer number in `subject`. |');
        Help.AppendLine('| `Customer ''X'' was not found. Check the number, or search for the customer with Data.Records.Get on table Customer.` | Unknown customer. | Check the number. |');
        Help.AppendLine('| `Customer ''X'' is blocked for all transactions, so no visit can be logged. ...` | Customer blocked for All. | Unblock the customer or choose another. |');
        Help.AppendLine('| `Parameter ''visitDate'' is required. Send it as a date in the format YYYY-MM-DD, for example "2026-09-26".` | `visitDate` missing. | Send it. |');
        Help.AppendLine('| `Parameter ''visitDate'' has the value ''26.09.2026'', which is not a date in the format YYYY-MM-DD. ...` | Wrong date format. | Send `2026-09-26`. |');
        Help.AppendLine('| `Parameter ''visitDate'' is 2026-10-01, which is after the work date 2026-09-26. ...` | Visit in the future. | Log visits after they happen. |');
        Help.AppendLine('| `Parameter ''hours'' has the value ''abc'', which is not a number. ...` | Not a number. | Send e.g. `1.5`. |');
        Help.AppendLine('| `Parameter ''hours'' is 30, but it must be between 0.25 and 24.` | Out of range. | Send 0.25 to 24. |');
        Help.AppendLine('| `Parameter ''description'' is 140 characters long; the maximum is 100.` | Too long. | Shorten it. |');
        Help.AppendLine('');
        Help.AppendLine('## Safe retries');
        Help.AppendLine('Send an `externalId` when a retry is possible (timeouts, queues). A second call with the same');
        Help.AppendLine('`externalId` writes nothing and returns the first visit with `"created": false`. Without an');
        Help.AppendLine('`externalId`, every call creates a new visit.');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs write permission on `Ref Service Visit` and read permission on Customer; users');
        Help.AppendLine('without them do not see this type. The visit can be removed only in Business Central.');
        Help.AppendLine('');
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Dates YYYY-MM-DD, numbers with a dot. Error texts are translatable and follow lcid when a');
        Help.AppendLine('translation is installed.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Reference.Customer.Overview.Get` - the customer''s balance and credit.');
        exit(Help.ToText());
    end;
}
