namespace Origo.Bifrost.Reference;

/// <summary>
/// Help ("use cards") for the ItemPrice preview/apply pair. The two documents point at each
/// other so an agent always sees the sibling. Error texts are verbatim from the Labels.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90020 "Ref Price Help"
{
    Access = Internal;

    procedure GetPreviewHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.ItemPrice.PreviewAdjustment');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Shows what a percentage change to the unit price would do to every item in one item');
        Help.AppendLine('category (blocked items excluded): current price, new price and totals.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only. Nothing is changed.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('1. This type - show the user the result.');
        Help.AppendLine('2. When the user agrees: `Reference.ItemPrice.ApplyAdjustment` with the same');
        Help.AppendLine('   `itemCategoryCode` and `percent`, and this response''s `itemCount` as `expectedItemCount`.');
        Help.AppendLine('');
        AppendParameters(Help, false);
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.ItemPrice.PreviewAdjustment", "data": { "itemCategoryCode": "STÓLL", "percent": 5 } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        AppendResponse(Help, false);
        AppendErrors(Help, false);
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs read permission on Item. No side effects.');
        Help.AppendLine('');
        AppendFormats(Help);
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Reference.ItemPrice.ApplyAdjustment` - makes the change shown here.');
        exit(Help.ToText());
    end;

    procedure GetApplyHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.ItemPrice.ApplyAdjustment');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Changes the unit price of every item in one item category (blocked items excluded) by a');
        Help.AppendLine('percentage.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Commits. All items change, or - on any error - none do. There is no undo type:');
        Help.AppendLine('reversing +10 % with -10 % does not give the original price because of rounding.');
        Help.AppendLine('');
        Help.AppendLine('## Workflow');
        Help.AppendLine('1. `Reference.ItemPrice.PreviewAdjustment` first, and show the user the result.');
        Help.AppendLine('2. This type, with the same `itemCategoryCode` and `percent`, and the preview''s');
        Help.AppendLine('   `itemCount` as `expectedItemCount`. If the selection changed, the call is refused.');
        Help.AppendLine('');
        AppendParameters(Help, true);
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.ItemPrice.ApplyAdjustment",');
        Help.AppendLine('  "data": { "itemCategoryCode": "STÓLL", "percent": 5, "expectedItemCount": 4 } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        AppendResponse(Help, true);
        AppendErrors(Help, true);
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs write permission on Item. The Item''s own OnValidate/OnModify logic runs for');
        Help.AppendLine('`Unit Price`, exactly as when a user edits it.');
        Help.AppendLine('');
        AppendFormats(Help);
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Reference.ItemPrice.PreviewAdjustment` - always call it first.');
        exit(Help.ToText());
    end;

    local procedure AppendParameters(var Help: TextBuilder; IsApply: Boolean)
    begin
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `itemCategoryCode` | text, max 20 | yes | An existing item category code (case-insensitive). |');
        Help.AppendLine('| `percent` | number | yes | -50 to 100, not 0. 5 means +5 %, -10 means -10 %. |');
        if IsApply then
            Help.AppendLine('| `expectedItemCount` | whole number | yes | The `itemCount` from the preview. |');
        Help.AppendLine('');
    end;

    local procedure AppendResponse(var Help: TextBuilder; IsApply: Boolean)
    begin
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        if IsApply then
            Help.AppendLine('{ "itemCategoryCode": "STÓLL", "percent": 5, "itemCount": 4, "applied": true,')
        else
            Help.AppendLine('{ "itemCategoryCode": "STÓLL", "percent": 5, "itemCount": 4, "applied": false,');
        Help.AppendLine('  "totalCurrentUnitPrice": 50280, "totalNewUnitPrice": 52794, "itemsTruncated": false,');
        Help.AppendLine('  "items": [ { "itemNo": "1900-S", "description": "PARIS Guest Chair, black", "currentUnitPrice": 12570, "newUnitPrice": 13198.5 } ] }');
        Help.AppendLine('```');
        Help.AppendLine('Amounts are JSON numbers, rounded with the unit-amount rounding precision from General');
        Help.AppendLine('Ledger Setup. `items` lists at most 1000 items; `itemsTruncated` is true beyond that, but');
        Help.AppendLine('`itemCount` and the totals always cover every item.');
        Help.AppendLine('');
    end;

    local procedure AppendErrors(var Help: TextBuilder; IsApply: Boolean)
    begin
        Help.AppendLine('## Errors');
        if IsApply then
            Help.AppendLine('Nothing is changed when any of these is returned.');
        Help.AppendLine('');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `Parameter ''itemCategoryCode'' is required. Send it as text, for example "STÓLL".` | Missing. | Send the category code. |');
        Help.AppendLine('| `Item category ''X'' was not found. Check the code, or list categories with Data.Records.Get on table Item Category.` | Unknown category. | Check the code. |');
        Help.AppendLine('| `Parameter ''percent'' has the value ''abc'', which is not a number. ...` | Not a number. | Send e.g. `5` or `-2.5`. |');
        Help.AppendLine('| `Parameter ''percent'' is 150, but it must be between -50 and 100.` | Out of range. | Stay within -50 to 100. |');
        Help.AppendLine('| `Parameter ''percent'' is 0, which would change nothing. ...` | Zero. | Send a non-zero percent. |');
        if IsApply then begin
            Help.AppendLine('| `Parameter ''expectedItemCount'' is required. Send it as a whole number, for example 12.` | Preview skipped. | Run the preview first and send its `itemCount`. |');
            Help.AppendLine('| `The selection changed since the preview: expected 4 items in category ''STÓLL'', found 5. ...` | Items were added, removed or blocked after the preview. | Run the preview again. |');
        end;
        Help.AppendLine('');
    end;

    local procedure AppendFormats(var Help: TextBuilder)
    begin
        Help.AppendLine('## Formats and language');
        Help.AppendLine('Numbers with a dot as decimal separator. Error texts are translatable and follow lcid when a');
        Help.AppendLine('translation is installed.');
        Help.AppendLine('');
    end;
}
