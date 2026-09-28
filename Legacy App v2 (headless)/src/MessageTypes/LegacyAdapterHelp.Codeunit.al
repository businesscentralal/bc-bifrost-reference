namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// Help ("use cards") for the Legacy.Stock.* types. Error texts are verbatim from the Labels in
/// Legacy Adapter Input and the app's internal core "Legacy Stock API" - keep them in step.
/// Every document has the eleven sections of START-HERE.md section 4, in that order.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90106 "Legacy Adapter Help"
{
    Access = Internal;

    procedure GetReserveHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Legacy.Stock.Reserve');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Reserves a quantity of one item in Legacy App. An existing reservation for the item is');
        Help.AppendLine('increased; otherwise one is created. Returns the new total.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Commits. Not safe to repeat (see Safe retries).');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('`Legacy.Stock.Get` (optional) -> this type -> `Legacy.Stock.CancelReservation` to undo.');
        Help.AppendLine('');
        AppendItemIdentification(Help);
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemNo` | text, max 20 | only if `subject` is empty | An existing, unblocked item. |');
        Help.AppendLine('| `quantity` | number | yes | Greater than zero; dot as decimal separator. |');
        Help.AppendLine('| `allowOverStock` | true/false | no, default false | By default the total reserved may not exceed the inventory. Send `true` only when the user has explicitly agreed to reserve more than is in stock. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Legacy.Stock.Reserve", "subject": "1896-S", "data": { "quantity": 2 } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "itemNo": "1896-S", "quantityAdded": 2, "totalReserved": 5, "availableToReserve": 12 }');
        Help.AppendLine('```');
        Help.AppendLine('`availableToReserve` is inventory minus the total reserved; negative after an over-reservation.');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Nothing is written when any of these is returned.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        AppendItemErrors(Help);
        Help.AppendLine('| `Item ''X'' does not exist. Check the number, or find the item with Data.Records.Get on table Item.` | Unknown item. | Check the number. |');
        Help.AppendLine('| `Item ''X'' is blocked, so stock cannot be reserved for it. Unblock the item or choose another.` | Blocked item. | Unblock it or choose another. |');
        Help.AppendLine('| `Parameter ''quantity'' is required. Send it as a number, for example 2.5.` | Missing. | Send `quantity`. |');
        Help.AppendLine('| `Parameter ''quantity'' has the value ''two'', which is not a number. ...` | Not a number. | Send e.g. `2`. |');
        Help.AppendLine('| `The quantity to reserve is -1. Send a quantity greater than zero; to remove a reservation, cancel it instead.` | Zero or negative. | Send a positive quantity. |');
        Help.AppendLine('| `Item ''X'' has 10 in inventory and 8 already reserved, so reserving 5 more would reserve more than is in stock. Reserve at most 2, or explicitly allow over-reservation.` | Over stock. | Reserve at most the number given, or ask the user and resend with `"allowOverStock": true`. |');
        Help.AppendLine('| `Parameter ''allowOverStock'' has the value ''yes''. Send true or false, without quotes.` | Not true/false. | Send `true` or `false`. |');
        Help.AppendLine('');
        AppendCommon(Help,
            '**Not safe to repeat:** two identical calls reserve twice. Check with `Legacy.Stock.Get` when unsure whether an earlier call went through.',
            'write permission on Legacy Stock Reservation');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Legacy.Stock.Get`, `Legacy.Stock.CancelReservation`.');
        exit(Help.ToText());
    end;

    procedure GetCancelHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Legacy.Stock.CancelReservation');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Removes the whole reservation for one item and writes a cancellation log entry, both in');
        Help.AppendLine('one transaction. It cannot reduce a reservation partly.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Commits. Safe to repeat (see Safe retries).');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('`Legacy.Stock.Get` (optional, to see what is reserved) -> this type. It undoes `Legacy.Stock.Reserve`;');
        Help.AppendLine('for several items at once use `Legacy.Stock.ReleaseAll`.');
        Help.AppendLine('');
        AppendItemIdentification(Help);
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemNo` | text, max 20 | only if `subject` is empty | |');
        Help.AppendLine('');
        Help.AppendLine('No other parameters.');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Legacy.Stock.CancelReservation", "subject": "1896-S" }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "itemNo": "1896-S", "cancelled": true }');
        Help.AppendLine('```');
        Help.AppendLine('`cancelled` is false when there was no reservation - the item number is not checked against');
        Help.AppendLine('the item list, because an unknown item simply has nothing to cancel.');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        AppendItemErrors(Help);
        Help.AppendLine('');
        AppendCommon(Help,
            '**Safe to repeat:** when the item has no reservation nothing is written and the answer is `"cancelled": false`.',
            'write permission on Legacy Stock Reservation and Legacy Cancellation Log');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Legacy.Stock.Get`, `Legacy.Stock.Reserve`.');
        exit(Help.ToText());
    end;

    procedure GetGetHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Legacy.Stock.Get');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Returns the reserved quantity of one item in Legacy App.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('Standalone. Call it before `Legacy.Stock.Reserve` to see how much can still be reserved, or');
        Help.AppendLine('after a Reserve call whose outcome is unknown to see whether it went through.');
        Help.AppendLine('');
        AppendItemIdentification(Help);
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemNo` | text, max 20 | only if `subject` is empty | The item number. |');
        Help.AppendLine('');
        Help.AppendLine('No other parameters.');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Legacy.Stock.Get", "subject": "1896-S" }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "itemNo": "1896-S", "hasReservation": true, "reservedQuantity": 5, "availableToReserve": 12 }');
        Help.AppendLine('```');
        Help.AppendLine('An item without a reservation gives `hasReservation: false` and `reservedQuantity: 0`.');
        Help.AppendLine('`availableToReserve` is inventory minus reserved (0 for an unknown item) - the most');
        Help.AppendLine('`Legacy.Stock.Reserve` accepts without `allowOverStock`.');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        AppendItemErrors(Help);
        Help.AppendLine('');
        AppendCommon(Help, 'Read-only; safe to repeat.', 'read permission on Legacy Stock Reservation');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Legacy.Stock.Reserve`, `Legacy.Stock.CancelReservation`.');
        exit(Help.ToText());
    end;

    procedure GetListHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Legacy.Stock.List');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Lists stock reservations in Legacy App, all or those matching an item filter, with the');
        Help.AppendLine('count and total quantity. At most 100 rows are returned; `more` is true when there are others.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('This type -> show the user what will be released -> `Legacy.Stock.ReleaseAll` with the same');
        Help.AppendLine('`itemFilter` and `count` as `expectedCount`.');
        Help.AppendLine('');
        AppendFilterIdentification(Help);
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemFilter` | text, max 250 | no | A BC filter on the item number: `1896-S`, `1896-S|1900-S`, `19*`. Empty or absent = all. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Legacy.Stock.List", "data": { "itemFilter": "19*" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "itemFilter": "19*", "count": 2, "totalQuantity": 7, "returned": 2, "more": false,');
        Help.AppendLine('  "reservations": [ { "itemNo": "1896-S", "quantity": 5 }, { "itemNo": "1900-S", "quantity": 2 } ] }');
        Help.AppendLine('```');
        Help.AppendLine('`count` and `totalQuantity` cover every matching row, also when `more` is true.');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `Parameter ''itemFilter'' is ''X'', which is not a valid filter: ... Send an item number or a filter such as 1896-S|1900-S or 19*.` | Invalid filter syntax. | Fix the filter. |');
        Help.AppendLine('| `Parameter ''itemFilter'' is 300 characters long; the maximum is 250.` | Too long. | Shorten the filter. |');
        Help.AppendLine('| `The request body must be a JSON object, ...` | Body is not an object. | Send an object or no body. |');
        Help.AppendLine('');
        AppendCommon(Help, 'Read-only; safe to repeat.', 'read permission on Legacy Stock Reservation');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Legacy.Stock.Get` (one item), `Legacy.Stock.ReleaseAll`.');
        exit(Help.ToText());
    end;

    procedure GetReleaseAllHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Legacy.Stock.ReleaseAll');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Releases (cancels) every reservation whose item number matches `itemFilter` and writes a');
        Help.AppendLine('cancellation log entry for each, in one transaction: all of them or, on any error, none.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Commits. **Irreversible.** Show the user the result of `Legacy.Stock.List` and');
        Help.AppendLine('get their agreement first. Safe to repeat (see Safe retries).');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('`Legacy.Stock.List` (same `itemFilter`) -> user agrees -> this type with `expectedCount` = the');
        Help.AppendLine('`count` from the list. When the user already saw that count earlier in the conversation, send');
        Help.AppendLine('it directly - there is no need to list again: if anything changed since, the call is refused');
        Help.AppendLine('and nothing is released.');
        Help.AppendLine('');
        AppendFilterIdentification(Help);
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemFilter` | text, max 250 | yes | A BC filter on the item number. Send `*` to release all - on purpose. |');
        Help.AppendLine('| `expectedCount` | whole number | yes | Must equal the number of reservations the filter matches now. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Legacy.Stock.ReleaseAll", "data": { "itemFilter": "19*", "expectedCount": 2 } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "itemFilter": "19*", "released": 2 }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Nothing is written when any of these is returned.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `itemFilter ''19*'' matches 3 reservations, not the 2 you sent in expectedCount. Nothing was released. Check with Legacy.Stock.List and send its count.` | Count changed or was guessed. | List again, confirm with the user, resend. |');
        Help.AppendLine('| `Parameter ''itemFilter'' is required. Send it as text, for example "1896-S|1900-S" or "*" for all.` | Missing. | Send a filter; `*` for all. |');
        Help.AppendLine('| `Parameter ''itemFilter'' is empty. Send a value, for example "1896-S|1900-S" or "*" for all.` | Empty. | Same. |');
        Help.AppendLine('| `Parameter ''expectedCount'' is required. Send it as a whole number, for example 3.` | Missing. | Send the count from `Legacy.Stock.List`. |');
        Help.AppendLine('| `Parameter ''expectedCount'' has the value ''2.5'', which is not a whole number. ...` | Not a whole number. | Send e.g. `2`. |');
        Help.AppendLine('| A BC filter error | Invalid filter syntax. | Check the filter with `Legacy.Stock.List` first. |');
        Help.AppendLine('');
        AppendCommon(Help,
            '**Safe to repeat:** a second identical call fails on `expectedCount` and releases nothing.',
            'write permission on Legacy Stock Reservation and Legacy Cancellation Log');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Legacy.Stock.List`, `Legacy.Stock.CancelReservation` (one item).');
        exit(Help.ToText());
    end;

    local procedure AppendItemIdentification(var Help: TextBuilder)
    begin
        Help.AppendLine('## Identifying the item');
        Help.AppendLine('`subject` = the item number (case-insensitive). When `subject` is empty, `itemNo` in the body.');
        Help.AppendLine('');
    end;

    local procedure AppendFilterIdentification(var Help: TextBuilder)
    begin
        Help.AppendLine('## Identifying the target');
        Help.AppendLine('`subject` is not used. The reservations are selected by `itemFilter` in the body.');
        Help.AppendLine('');
    end;

    local procedure AppendItemErrors(var Help: TextBuilder)
    begin
        Help.AppendLine('| `Parameter ''itemNo'' is required. Send it as text, for example "1896-S".` | No item in subject or body. | Send the item number in `subject`. |');
        Help.AppendLine('| `Parameter ''itemNo'' is empty. Send a value, for example "1896-S".` | Empty value. | Send the number. |');
        Help.AppendLine('| `Parameter ''itemNo'' is 25 characters long; the maximum is 20.` | Too long. | Check the number. |');
        Help.AppendLine('| `The request body must be a JSON object, ...` | Body is not an object. | Send an object or no body. |');
    end;

    local procedure AppendCommon(var Help: TextBuilder; RepeatText: Text; PermissionText: Text)
    begin
        Help.AppendLine('## Safe retries / repeat');
        Help.AppendLine(RepeatText);
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs ' + PermissionText + '; users without it do not see this type.');
        Help.AppendLine('');
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Numbers with a dot as decimal separator. Error texts are translatable and follow lcid when a');
        Help.AppendLine('translation is installed.');
        Help.AppendLine('');
    end;
}
