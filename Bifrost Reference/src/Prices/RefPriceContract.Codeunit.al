namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// The contract chapters both halves of the ItemPrice preview/apply pair share: the target, the
/// parameters, the response and the errors. Each impl codeunit builds its own chapters from these,
/// so preview and apply always describe the same request and the same answer.
/// Error texts are verbatim from the Labels in Ref Price Adjust, Ref Price Apply Impl and Ref Input.
/// </summary>
codeunit 90020 "Ref Price Contract"
{
    Access = Internal;

    procedure Envelope() Result: JsonObject
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The item category is itemCategoryCode in data.');
        Result.Add('subject', Subject);
        Result.Add('dataRequired', true);
        Result.Add('version', '1.0');
        Result.Add('contentType', 'text/json');
    end;

    procedure Target() Result: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Result.Add(ContractMgt.TargetEntry('data.itemCategoryCode', 'item category code', 'An existing item category (case-insensitive). The items are every item in it that is not blocked.'));
    end;

    procedure AddParameters(var Parameters: JsonArray; IsApply: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Percent: JsonObject;
    begin
        Parameters.Add(ContractMgt.Parameter('itemCategoryCode', 'string', true, 'An existing item category code, at most 20 characters, case-insensitive.'));
        Percent := ContractMgt.Parameter('percent', 'number', true, 'The change in percent, from -50 to 100, not 0. 5 means +5 %, -10 means -10 %.');
        Parameters.Add(Percent);
        if IsApply then
            Parameters.Add(ContractMgt.Parameter('expectedItemCount', 'integer', true, 'The itemCount the preview returned. The call is refused when the category now holds a different number of items, or when no preview was made.'));
    end;

    procedure Response() Result: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        ItemField: JsonObject;
        ItemChildren: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('itemCategoryCode', 'string', 'The category, in upper case.'));
        Fields.Add(ContractMgt.ResponseField('percent', 'number', 'The percent applied or previewed.'));
        Fields.Add(ContractMgt.ResponseField('itemCount', 'integer', 'How many items the change covers: every item in the category that is not blocked. Send it to the apply call as expectedItemCount.'));
        Fields.Add(ContractMgt.ResponseField('applied', 'boolean', 'false for the preview, true when the prices were changed.'));
        Fields.Add(ContractMgt.ResponseField('totalCurrentUnitPrice', 'number', 'The sum of the current unit prices.'));
        Fields.Add(ContractMgt.ResponseField('totalNewUnitPrice', 'number', 'The sum of the new unit prices.'));
        Fields.Add(ContractMgt.ResponseField('itemsTruncated', 'boolean', 'true when more than 1000 items are covered: items then lists the first 1000, but itemCount and the totals still cover every item.'));
        ItemField := ContractMgt.ResponseField('items', 'array', 'One element per item, at most 1000.');
        ItemChildren.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item No.'));
        ItemChildren.Add(ContractMgt.ResponseField('description', 'string', 'The item description.'));
        ItemChildren.Add(ContractMgt.ResponseField('currentUnitPrice', 'number', 'The unit price before the change.'));
        ItemChildren.Add(ContractMgt.ResponseField('newUnitPrice', 'number', 'The unit price after the change, rounded with the unit-amount rounding precision of General Ledger Setup.'));
        ItemField.Add('children', ItemChildren);
        Fields.Add(ItemField);
        Result.Add('contentType', 'text/json');
        Result.Add('fields', Fields);
    end;

    procedure AddErrors(var Errors: JsonArray; IsApply: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemCategoryCode'' is required. Send it as text, for example "STÓLL".', 'itemCategoryCode is missing.', 'Send the category code.'));
        Errors.Add(ContractMgt.TextErrorEntry('Item category ''{code}'' was not found. Check the code, or list categories with Data.Records.Get on table Item Category.', 'No item category has that code.', 'Check the code, or list the categories.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''percent'' has the value ''{value}'', which is not a number.', 'percent is not a number.', 'Send a number, for example 5 or -2.5.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''percent'' is {value}, but it must be between -50 and 100.', 'percent is out of range.', 'Stay within -50 to 100.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''percent'' is 0, which would change nothing. Send the change in percent, for example 5 for +5 % or -10 for -10 %.', 'percent is 0.', 'Send a non-zero percent.'));
        if IsApply then begin
            Errors.Add(ContractMgt.TextErrorEntry('Parameter ''expectedItemCount'' is required. Send it as a whole number, for example 12.', 'The preview was skipped.', 'Run Reference.ItemPrice.PreviewAdjustment first and send its itemCount.'));
            Errors.Add(ContractMgt.TextErrorEntry('The selection changed since the preview: expected {expected} items in category ''{code}'', found {actual}. Run Reference.ItemPrice.PreviewAdjustment again and send its itemCount as expectedItemCount.', 'Items were added, removed or blocked after the preview.', 'Run the preview again and show the user the new result.'));
        end;
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, for example { "accountNo": "2910" }.', 'data is an array or plain text.', 'Send a JSON object.'));
    end;

    procedure Workflow() Result: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Reference.ItemPrice.PreviewAdjustment', 'See what the change would do, and show the user the current and new prices.'));
        Steps.Add(ContractMgt.WorkflowStep('Reference.ItemPrice.ApplyAdjustment', 'When the user agrees: the same itemCategoryCode and percent, with the preview''s itemCount as expectedItemCount.'));
        Result.Add('steps', Steps);
        Result.Add('text', 'Always preview first. The apply call needs the preview''s itemCount, so it cannot run on a selection nobody looked at.');
    end;
}
