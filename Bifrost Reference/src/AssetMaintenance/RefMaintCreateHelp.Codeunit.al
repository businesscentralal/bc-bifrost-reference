namespace Origo.Bifrost.Reference;

/// <summary>
/// Help ("use card") for Reference.AssetMaintenance.Create. Error texts are verbatim copies of
/// the Labels in Ref Input and Ref Maint Create Impl - change them together.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90015 "Ref Maint Create Help"
{
    Access = Internal;

    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.AssetMaintenance.Create');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Logs maintenance work done on one fixed asset (a machine, a vehicle): the date it was done,');
        Help.AppendLine('the hours spent and a short note.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Commits. One `Ref Asset Maintenance` record is inserted - or none, when the same');
        Help.AppendLine('`externalId` was already used (see Safe retries).');
        Help.AppendLine('');
        Help.AppendLine('Not for FA ledger entries, depreciation, or posting maintenance costs - those go through FA');
        Help.AppendLine('journals. This is a simple work log; it posts nothing and changes no amount.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('Optional: find the asset number first with `Data.Records.Get` on `Fixed Asset` -> this type.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the asset');
        Help.AppendLine('Tried in this order; the first one given is used:');
        Help.AppendLine('1. `subject` as a GUID - the fixed asset''s SystemId.');
        Help.AppendLine('2. `subject` as text - the fixed asset number, e.g. `FA000010` (case-insensitive).');
        Help.AppendLine('3. `assetNo` in the body, when `subject` is empty.');
        Help.AppendLine('');
        Help.AppendLine('If nothing is given you get "No fixed asset was given"; if a value is given but no asset has');
        Help.AppendLine('it you get "Fixed asset ''X'' was not found" with your value. The two never mix.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `assetNo` | text, max 20 | only if `subject` is empty | Must exist and be neither blocked nor inactive. |');
        Help.AppendLine('| `maintenanceDate` | date **YYYY-MM-DD** | yes | On or before the work date. `26.09.2026` is refused. |');
        Help.AppendLine('| `hours` | number | yes | 0.25 to 24. Dot as decimal separator. |');
        Help.AppendLine('| `description` | text, max 100 | no | A short note on the work done. |');
        Help.AppendLine('| `externalId` | text, max 50 | no | Your own id for this entry. Makes the call safe to retry. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.AssetMaintenance.Create", "subject": "FA000010",');
        Help.AppendLine('  "data": { "maintenanceDate": "2026-09-25", "hours": 1.5, "description": "Oil change", "externalId": "WO-4711" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "entryNo": 12, "created": true, "assetNo": "FA000010", "maintenanceDate": "2026-09-25",');
        Help.AppendLine('  "hours": 1.5, "description": "Oil change", "externalId": "WO-4711" }');
        Help.AppendLine('```');
        Help.AppendLine('| Field | JSON type | Meaning |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `entryNo` | number | The entry''s number in the maintenance log. |');
        Help.AppendLine('| `created` | boolean | false when the `externalId` already existed; the response then describes the entry the earlier call created, and nothing new is written. |');
        Help.AppendLine('| `assetNo` | text | The fixed asset number. |');
        Help.AppendLine('| `maintenanceDate` | text, YYYY-MM-DD | The date the work was done. |');
        Help.AppendLine('| `hours` | number | Hours spent. |');
        Help.AppendLine('| `description`, `externalId` | text | As sent; empty when not sent. |');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Every error is `{ "status": "Error", "error": "...", "hint": "..." }`. Nothing is written when any');
        Help.AppendLine('of these is returned.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `No fixed asset was given. Send the asset number in subject or as "assetNo", or its SystemId in subject.` | No asset in subject or body. | Send the asset number in `subject`. |');
        Help.AppendLine('| `Fixed asset ''X'' was not found. Check the number, or search for the asset with Data.Records.Get on table Fixed Asset.` | Unknown asset. | Check the number. |');
        Help.AppendLine('| `Fixed asset ''X'' is blocked, so no maintenance can be logged. Clear Blocked on the fixed asset card in Business Central, or choose another asset.` | Asset blocked. | Ask the user to unblock it, or choose another asset. |');
        Help.AppendLine('| `Fixed asset ''X'' is inactive, so no maintenance can be logged. Clear Inactive on the fixed asset card in Business Central, or choose another asset.` | Asset inactive (e.g. sold or scrapped). | Ask the user whether the asset is still in use. |');
        Help.AppendLine('| `Parameter ''maintenanceDate'' is required. Send it as a date in the format YYYY-MM-DD, for example "2026-09-26".` | `maintenanceDate` missing. | Send it. |');
        Help.AppendLine('| `Parameter ''maintenanceDate'' has the value ''26.09.2026'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.` | Wrong date format. | Send `2026-09-26`. |');
        Help.AppendLine('| `Parameter ''maintenanceDate'' is 2026-10-01, which is after the work date 2026-09-26. Maintenance is logged after it is done; send a date on or before 2026-09-26.` | Date in the future. | Log work after it is done. |');
        Help.AppendLine('| `Parameter ''hours'' is required. Send it as a number, for example 2.5.` | `hours` missing. | Send it. |');
        Help.AppendLine('| `Parameter ''hours'' has the value ''abc'', which is not a number. Send a number with a dot as decimal separator, for example 2.5.` | Not a number. | Send e.g. `1.5`. |');
        Help.AppendLine('| `Parameter ''hours'' is 30, but it must be between 0.25 and 24.` | Out of range. | Send 0.25 to 24. |');
        Help.AppendLine('| `Parameter ''description'' is 140 characters long; the maximum is 100.` | Too long (same text for `externalId`, maximum 50). | Shorten it. |');
        Help.AppendLine('| `Parameter ''assetNo'' must be a single value (text or number), not an object or an array.` | A parameter sent as object or array. | Send a single value. |');
        Help.AppendLine('| `The request body must be a JSON object, for example { "accountNo": "2910" }.` | Body is an array or plain text. | Send a JSON object. |');
        Help.AppendLine('');
        Help.AppendLine('## Safe retries / repeat');
        Help.AppendLine('Send an `externalId` when a retry is possible (timeouts, queues). A second call with the same');
        Help.AppendLine('`externalId` writes nothing and returns the first entry with `"created": false`. Without an');
        Help.AppendLine('`externalId`, every call creates a new entry.');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs write permission on `Ref Asset Maintenance` and read permission on Fixed Asset; users');
        Help.AppendLine('without them do not see this type. Nothing else changes: no ledger entry, no amount on the');
        Help.AppendLine('asset. An entry can be removed only in Business Central.');
        Help.AppendLine('');
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Dates YYYY-MM-DD, numbers with a dot. Error texts are translatable and follow lcid when a');
        Help.AppendLine('translation is installed.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Data.Records.Get` on `Fixed Asset` - find the asset number.');
        Help.AppendLine('- `Data.Records.Get` on `Ref Asset Maintenance` - read back the log.');
        Help.AppendLine('- `Help.Reference.Get` - the other types in this app.');
        exit(Help.ToText());
    end;
}
