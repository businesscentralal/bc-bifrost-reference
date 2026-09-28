namespace MyCompany.MyBifrostApp;

/// <summary>
/// Help for MyApp.Item.List, in the eleven sections of START-HERE.md section 4. Error texts are copied
/// verbatim from the Labels in My Input and My Item List Impl - change them together.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 50004 "My Item List Help"
{
    Access = Internal;

    /// <summary>
    /// Returns the help document of MyApp.Item.List as Markdown.
    /// </summary>
    /// <returns>The Markdown document.</returns>
    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        // TODO: rename the type in every line below together with the enum value.
        Help.AppendLine('# MyApp.Item.List');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Lists items, all or those whose number matches a filter, with the total count. At most');
        Help.AppendLine('100 rows are returned (fewer with `maxRows`); `more` is true when there are others.');
        Help.AppendLine('Blocked items are left out unless you send `"includeBlocked": true`.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only. Nothing is written.');
        Help.AppendLine('');
        Help.AppendLine('Not for one item''s price and inventory - use `MyApp.Item.Summary.Get`. Not for a search by');
        Help.AppendLine('description - use `Data.Records.Get` on table Item.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('This type -> pick an item -> `MyApp.Item.Summary.Get` with its `itemNo` as `subject`.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the target');
        Help.AppendLine('No single record: `subject` is not used. The rows are chosen by `itemFilter` and');
        Help.AppendLine('`includeBlocked`. A filter that matches nothing is not an error: `count` is 0.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemFilter` | text, max 250 | no | A BC filter on the item number: `1896-S`, `1000..1999`, `19*`. Empty or absent = all. |');
        Help.AppendLine('| `maxRows` | whole number | no, default 100 | 1 to 100. |');
        Help.AppendLine('| `includeBlocked` | true/false | no, default false | `true` also returns blocked items. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "MyApp.Item.List", "data": { "itemFilter": "19*", "maxRows": 2 } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "itemFilter": "19*", "includeBlocked": false, "count": 5, "returned": 2, "more": true,');
        Help.AppendLine('  "items": [ { "itemNo": "1900-S", "description": "PARIS Guest Chair, black", "blocked": false },');
        Help.AppendLine('             { "itemNo": "1906-S", "description": "ATHENS Mobile Pedestal", "blocked": false } ] }');
        Help.AppendLine('```');
        Help.AppendLine('| Field | JSON type | Meaning |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `count` | number | Every matching item, also when `more` is true. |');
        Help.AppendLine('| `returned` | number | The rows in `items`. |');
        Help.AppendLine('| `more` | boolean | true when `count` is larger than `returned`. Narrow the filter to see the rest. |');
        Help.AppendLine('| `items` | array | `itemNo` (text), `description` (text), `blocked` (boolean); empty when nothing matches. |');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('Every error is `{ "status": "Error", "error": "...", "hint": "..." }`.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `Parameter ''itemFilter'' is ''X'', which is not a valid filter: ... Send an item number or a filter such as 1000..1999 or 19*.` | Invalid filter syntax. | Fix the filter. |');
        Help.AppendLine('| `Parameter ''itemFilter'' is 300 characters long; the maximum is 250.` | Too long. | Shorten the filter. |');
        Help.AppendLine('| `Parameter ''maxRows'' has the value ''ten'', which is not a whole number. Send for example 12.` | Not a whole number. | Send e.g. `20`. |');
        Help.AppendLine('| `Parameter ''maxRows'' is 500, but it must be between 1 and 100.` | Out of range. | Send 1 to 100. |');
        Help.AppendLine('| `Parameter ''includeBlocked'' has the value ''yes''. Send true or false, without quotes.` | Not true/false. | Send `true` or `false`. |');
        Help.AppendLine('| `Parameter ''itemFilter'' must be a single value (text or number), not an object or an array.` | A parameter sent as object or array. | Send a single value. |');
        Help.AppendLine('| `The request body must be a JSON object, for example { "itemNo": "1896-S" }.` | Body is an array or plain text. | Send an object, or no body at all. |');
        Help.AppendLine('');
        Help.AppendLine('## Safe retries / repeat');
        Help.AppendLine('Read-only; safe to repeat.');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs read permission on Item; users without it do not see this type. No side effects.');
        Help.AppendLine('');
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Numbers are JSON numbers. Error texts are translatable; with a translation installed they');
        Help.AppendLine('follow the caller''s lcid.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `MyApp.Item.Summary.Get` - one item''s price and inventory.');
        Help.AppendLine('- `Data.Records.Get` on table Item - search by any field.');
        exit(Help.ToText());
    end;
}
