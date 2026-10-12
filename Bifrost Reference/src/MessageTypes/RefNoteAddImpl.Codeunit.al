namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference implementation of a WRITE message type, and of how a message type describes itself.
///
/// Three interfaces on one codeunit:
/// - "Msg Interface ori" runs the call. The write happens in a separate codeunit (TableNo =
///   "Message Argument ori") invoked via Codeunit.Run(), so a failure is answered as status = Error
///   without rolling back the outer transaction.
/// - "Msg Discovery ori" helps an agent find this type: keywords people say, and a sentence that
///   separates it from its siblings.
/// - "Msg Contract ori" is the use card an agent reads before calling: Help.Implementation.Get returns
///   each chapter as its own JSON key. A fact a program checks (types, required, error codes) is JSON;
///   an explanation a reader reasons with is text. Chapter text is English.
/// Build entries with "Msg Contract Mgt ori" (Parameter, TextErrorEntry, RelatedEntry, Example ...),
/// so the shape always matches what Foundation and the agents expect.
/// </summary>
codeunit 90003 "Ref Note Add Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    // ---------- Msg Interface ori: what the type is, and running it ----------

    /// <summary>
    /// A real gate, not a formality: returning false here means this message type is not
    /// listed and cannot be chosen at all. Check the permission or setup the type needs,
    /// rather than unconditionally returning true.
    /// </summary>
    procedure IsEnabled(): Boolean
    var
        RefNote: Record "Ref Note";
    begin
        exit(RefNote.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Ref Note");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Creates one Reference Note record with the number and text given. Commits. Fails with a structured error if a note with that number already exists.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RefInput: Codeunit "Ref Input";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        // Write operations must run in an isolated sub-codeunit so a failure can be caught
        // here without rolling back the outer transaction (START-HERE.md section 3).
        // Ref Input.RunIsolated honours "Omit Commit" and answers failures as status = Error
        // with the error text only (no call stack in the response).
        RefInput.RunIsolated(Codeunit::"Ref Note Add Process", Argument);
    end;

    // ---------- Msg Discovery ori: how an agent finds it ----------

    /// <summary>Words people actually say for this. Translatable, never Locked.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'add a note, save a note, write a note, store a note, new note, jot this down', Comment = 'is-IS=bæta við athugasemd, vista athugasemd, skrifa athugasemd, geyma athugasemd, ný athugasemd, skráðu þetta';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when an agent is choosing.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Store one new short note under a number you choose; an existing number is refused, never overwritten. To check the connection, use Reference.Echo.Get; to read records, use Data.Records.Get on Ref Note.', Comment = 'is-IS=Vista eina nýja stutta athugasemd undir númeri sem þú velur; númeri sem er þegar til er hafnað, aldrei skrifað yfir. Til að prófa tenginguna, notaðu Reference.Echo.Get; til að lesa færslur, notaðu Data.Records.Get á Ref Note.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: the use card, one chapter per procedure ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates one Reference Note record, identified by the number you give in `no`, holding the text you give in `text`. ' +
            'Use it to store a short free-text note under a number you choose. Not for changing or deleting a note (there is no update or delete type), and not for reading notes back.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>No target: the new note is named by `no` in data, not by subject.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        NoParam: JsonObject;
        TextParam: JsonObject;
    begin
        NoParam := ContractMgt.Parameter('no', 'string', true, 'Your identifier for the note, at most 20 characters. Stored in upper case. Must not be empty or already exist.');
        Parameters.Add(NoParam);
        TextParam := ContractMgt.Parameter('text', 'string', false, 'The note text, at most 250 characters. Omitted: empty.');
        Parameters.Add(TextParam);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('no', 'string', 'The number the note was stored under, in upper case. There is no empty result: the call either stores one note or fails.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// This sample answers with error texts, not codes, so each entry is a TextErrorEntry.
    /// A type that answers with Argument.RespondWithError(code, ...) lists ErrorEntry(code, ...) instead.
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''no'' is required. Send it as text, for example "NOTE-1".', 'The request has no no.', 'Send no.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''no'' is empty. Send a value, for example "NOTE-1".', 'no is an empty string.', 'Send a value.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''no'' is {length} characters long; the maximum is 20.', 'no is too long.', 'Shorten it.'));
        Errors.Add(ContractMgt.TextErrorEntry('A note with no. ''{no}'' already exists. Choose a different no.; if this is a retry, the first attempt most likely succeeded.', 'A note with that no is already stored.', 'Choose a different no, or treat it as success when retrying.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''text'' is {length} characters long; the maximum is 250.', 'text is too long.', 'Shorten it.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''no'' must be a single value (text or number), not an object or an array.', 'no or text is an object or an array.', 'Send a single value.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, for example { "no": "NOTE-1" }.', 'data is an array or plain text.', 'Send a JSON object.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Inserts one Ref Note record. On any error nothing is written.');
        Effect.Add('idempotent', false);
        Preconditions.Add('The caller can write Ref Note; without it the type is not offered.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Nothing to add: Foundation reports whether the call is charged.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Reference.Echo.Get', 'You only want to check the connection: no write, no failure path.'));
        Related.Add(ContractMgt.RelatedEntry('Reference.Table.Get', 'You want a read with a structured "not found" error.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want to read the stored notes back (table Ref Note).'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Store a note',
            '{"type":"Reference.Note.Add","data":{"no":"NOTE-1","text":"hello"}}',
            '{"no":"NOTE-1"}'));
        Examples.Add(ContractMgt.Example('The number already exists',
            '{"type":"Reference.Note.Add","data":{"no":"NOTE-1","text":"again"}}',
            '{"status":"Error","error":"A note with no. ''NOTE-1'' already exists. Choose a different no.; if this is a retry, the first attempt most likely succeeded."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not safe to repeat with the same `no`: a retry after a timeout should treat "already exists" as "the first attempt went through", or use a fresh `no` per attempt. ' +
            '`no` is stored in upper case, so `note-1` and `NOTE-1` are the same note. `text` is stored as sent. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
