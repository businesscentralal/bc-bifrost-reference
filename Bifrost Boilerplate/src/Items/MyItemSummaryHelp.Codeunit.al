namespace MyCompany.MyBifrostApp;

/// <summary>
/// Help for MyApp.Item.Summary.Get. This is the "use card": everything a caller needs to
/// make the first call right, in the eleven sections of START-HERE.md section 4, in that order. Error texts
/// are copied verbatim from the Labels in My Input - change them together.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 50002 "My Item Summary Help"
{
    Access = Internal;

    /// <summary>
    /// Returns the help document of MyApp.Item.Summary.Get as Markdown.
    /// </summary>
    /// <returns>The Markdown document.</returns>
    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        // TODO: rename the type in every line below together with the enum value.
        Help.AppendLine('# MyApp.Item.Summary.Get');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Returns one item''s description, base unit of measure, unit price and inventory (quantity on');
        Help.AppendLine('hand) as of a date - the work date unless you send `asOfDate`.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only. Nothing is written.');
        Help.AppendLine('');
        Help.AppendLine('Use it to answer "how many of this item do we have, and what does it cost?". Not for many');
        Help.AppendLine('items at once - use `MyApp.Item.List`. Not for the entries behind the inventory - use');
        Help.AppendLine('`Data.Records.Get` on `Item Ledger Entry`.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('`MyApp.Item.List` (optional, to find the number) -> this type.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the item');
        Help.AppendLine('Tried in this order; the first one given is used:');
        Help.AppendLine('1. `subject` as a GUID - the item''s SystemId.');
        Help.AppendLine('2. `subject` as text - the item number, e.g. `1896-S` (case-insensitive).');
        Help.AppendLine('3. `itemNo` in the body - the item number, when `subject` is empty.');
        Help.AppendLine('');
        Help.AppendLine('If nothing is given you get "No item was given"; if a value is given but no item has it');
        Help.AppendLine('you get "Item ''X'' was not found" with your value. The two never mix.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemNo` | text, max 20 | only if `subject` is empty | Item number. |');
        Help.AppendLine('| `asOfDate` | date, YYYY-MM-DD | no, default the work date | Only this format; 26.09.2026 is refused. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "MyApp.Item.Summary.Get", "subject": "1896-S", "data": { "asOfDate": "2026-09-26" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "itemNo": "1896-S", "description": "ATHENS Desk", "baseUnitOfMeasure": "PCS", "unitPrice": 1000.8,');
        Help.AppendLine('  "asOfDate": "2026-09-26", "inventory": 12, "blocked": false }');
        Help.AppendLine('```');
        Help.AppendLine('| Field | JSON type | Meaning |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `itemNo`, `description` | text | The item found. |');
        Help.AppendLine('| `baseUnitOfMeasure` | text or **null** | The base unit of measure; null when none is set up - never "". |');
        Help.AppendLine('| `unitPrice` | number | The unit price on the item card, in local currency (LCY); 0 when none is set. |');
        Help.AppendLine('| `asOfDate` | text, YYYY-MM-DD | The date the inventory is for: yours, or the work date. |');
        Help.AppendLine('| `inventory` | number | Quantity on hand, in the base unit, from entries posted on or before `asOfDate`; 0 when there are none. |');
        Help.AppendLine('| `blocked` | boolean | true when the item is blocked. |');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Every error is `{ "status": "Error", "error": "...", "hint": "..." }`.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `No item was given. Send the item number in subject or as "itemNo", or its SystemId in subject.` | subject empty and no `itemNo`. | Send the item number in `subject`. |');
        Help.AppendLine('| `Item ''X'' was not found. Check the number, or search for the item with Data.Records.Get on table Item.` | No item has that number or SystemId. | Check the number; search by description with `Data.Records.Get`. |');
        Help.AppendLine('| `Parameter ''asOfDate'' has the value ''26.09.2026'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.` | Date in another format. | Send YYYY-MM-DD. |');
        Help.AppendLine('| `Parameter ''asOfDate'' is 31 characters long; the maximum is 30.` | Far too long to be a date. | Send YYYY-MM-DD. |');
        Help.AppendLine('| `Parameter ''itemNo'' must be a single value (text or number), not an object or an array.` | `itemNo` or `asOfDate` sent as object or array. | Send it as text. |');
        Help.AppendLine('| `The request body must be a JSON object, for example { "itemNo": "1896-S" }.` | Body is an array or plain text. | Send an object, or no body at all. |');
        Help.AppendLine('');
        Help.AppendLine('## Safe retries / repeat');
        Help.AppendLine('Read-only; safe to repeat. Two identical calls give the same answer unless entries were posted');
        Help.AppendLine('or the item card was changed in between.');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs read permission on Item; users without it do not see this type. No side effects.');
        Help.AppendLine('');
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Prices and quantities are JSON numbers with a dot as decimal separator; dates are YYYY-MM-DD in');
        Help.AppendLine('and out. Error texts are translatable; with a translation installed they follow the caller''s lcid.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `MyApp.Item.List` - find items by number filter.');
        Help.AppendLine('- `Data.Records.Get` on `Item Ledger Entry` - the entries behind the inventory.');
        exit(Help.ToText());
    end;
}
