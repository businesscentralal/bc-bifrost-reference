namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// The contract chapters the Legacy.Stock.* types share: how one item is identified, the input
/// errors every item type can answer, how a filter selects reservations, and the List/ReleaseAll
/// workflow. Each impl codeunit builds its own chapters from these, so the types always describe
/// the same input the same way.
/// Error texts are verbatim from the Labels in Legacy Adapter Input - change them together.
/// </summary>
codeunit 90112 "Legacy Stock Contract"
{
    Access = Internal;

    procedure ItemEnvelope(DataRequired: Boolean) Result: JsonObject
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'optional');
        Subject.Add('description', 'The item number. Leave it empty to send itemNo in data instead.');
        Result.Add('subject', Subject);
        Result.Add('dataRequired', DataRequired);
        Result.Add('version', '1.0');
        Result.Add('contentType', 'text/json');
    end;

    procedure ItemTarget() Result: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        // Tried in this order; the first one given is used.
        Result.Add(ContractMgt.TargetEntry('subject', 'item number', 'The item number, for example 1896-S, case-insensitive. Tried first.'));
        Result.Add(ContractMgt.TargetEntry('data.itemNo', 'item number', 'Used only when subject is empty.'));
    end;

    procedure ItemNoParameter(): JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        exit(ContractMgt.Parameter('itemNo', 'string', false, 'The item number, at most 20 characters, case-insensitive. Needed only when subject is empty.'));
    end;

    /// <summary>The input errors of every type that takes one item: subject or itemNo, and the body.</summary>
    procedure AddItemErrors(var Errors: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemNo'' is required. Send it as text, for example "1896-S".', 'subject is empty and data has no itemNo.', 'Send the item number in subject.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemNo'' is empty. Send a value, for example "1896-S".', 'subject is empty and itemNo is an empty string.', 'Send the item number.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemNo'' is {length} characters long; the maximum is 20.', 'The item number in subject or itemNo is longer than 20 characters.', 'Check the number.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''itemNo'' must be a single value (text or number), not an object or an array.', 'itemNo is an object or an array.', 'Send it as text.'));
        AddBodyError(Errors);
    end;

    procedure AddBodyError(var Errors: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object, or no body at all.'));
    end;

    procedure FilterEnvelope(DataRequired: Boolean) Result: JsonObject
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The reservations are selected by itemFilter in data.');
        Result.Add('subject', Subject);
        Result.Add('dataRequired', DataRequired);
        Result.Add('version', '1.0');
        Result.Add('contentType', 'text/json');
    end;

    procedure FilterTarget(IsRelease: Boolean) Result: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if IsRelease then
            Result.Add(ContractMgt.TargetEntry('data.itemFilter', 'item number filter', 'Every reservation whose item number matches the filter. Required: send * to release all, on purpose.'))
        else
            Result.Add(ContractMgt.TargetEntry('data.itemFilter', 'item number filter', 'Every reservation whose item number matches the filter. Empty or absent: all reservations.'));
    end;

    /// <summary>Legacy.Stock.List is the preview of Legacy.Stock.ReleaseAll: both describe the same two steps.</summary>
    procedure ReleaseWorkflow() Result: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Legacy.Stock.List', 'See which reservations the filter matches, and show the user what will be released.'));
        Steps.Add(ContractMgt.WorkflowStep('Legacy.Stock.ReleaseAll', 'When the user agrees: the same itemFilter, with the list''s count as expectedCount.'));
        Result.Add('steps', Steps);
        Result.Add('text', 'Always list first. The release needs the list''s count, so it cannot run on a selection nobody looked at. When the user already saw that count earlier in the conversation, send it directly: if anything changed since, the release is refused and nothing is released.');
    end;
}
