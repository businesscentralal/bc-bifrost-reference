namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Help.Legacy.Get - Legacy App's directory of its message types. Every Bifröst app exposes one Help.&lt;App&gt;.Get
/// type that says what the app is for and lists its message types, so an agent can learn the
/// whole app in one call instead of walking the catalogue. Keep the table in BuildOverview in step
/// with the enum extension.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90111 "Legacy Help Get Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Overview of Legacy App stock reservations in Bifrost: what the app does and its message types to reserve, cancel, check, list and release stock. Read-only. No request body.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ResponseJson: JsonObject;
    begin
        Argument.AssertVersion1();
        ResponseJson.Add('format', 'markdown');
        ResponseJson.Add('markdown', BuildOverview());
        Argument.SetResponseJson(ResponseJson);
    end;

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'what can the legacy app do, list legacy message types, legacy app overview, help for stock reservations, which operations does the legacy app add', Comment = 'is-IS=hvað getur eldra appið gert, lista skilaboðategundir eldra appsins, yfirlit eldra appsins, hjálp fyrir birgðafrátekningar, hvaða aðgerðir bætir eldra appið við';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'An overview of Legacy App and the stock reservation message types it adds, one line each. For the contract of one type, use Help.Implementation.Get; for every installed app, use Help.MessageTypes.Get.', Comment = 'is-IS=Yfirlit yfir Legacy App og skilaboðategundirnar fyrir birgðafrátekningar sem það bætir við, ein lína fyrir hverja. Fyrir samning einnar tegundar, notaðu Help.Implementation.Get; fyrir öll uppsett öpp, notaðu Help.MessageTypes.Get.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns a Markdown overview of Legacy App: what it is for and the stock reservation message types it adds, each with its effect and a one-line description. ' +
            'Use it first when you want to know what this app offers before calling anything in it. Not for the contract of one operation: ask Help.Implementation.Get for that.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No fields: anything sent is ignored.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('format', 'string', 'Always markdown.'));
        Fields.Add(ContractMgt.ResponseField('markdown', 'string', 'The overview document as Markdown text with \n line breaks: a short introduction and a table of the app''s message types (type, effect, what it does). Never empty.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>The operation has no error conditions of its own, so the list is empty.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads no table.');
        Effect.Add('idempotent', true);
        Preconditions.Add('None beyond calling Bifrost: every user sees this type.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Help.MessageTypes.Get', 'You want the whole catalogue across all installed apps.'));
        Related.Add(ContractMgt.RelatedEntry('Help.Implementation.Get', 'You want the full contract of one message type.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Help.Legacy.Get', 'See which message types the app adds.'));
        Steps.Add(ContractMgt.WorkflowStep('Help.Implementation.Get', 'Read the contract of the type you want to call, with its name as subject.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'This type first, then the contract of the chosen type, then that type.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Get the app overview',
            '{"type":"Help.Legacy.Get"}',
            '{"format":"markdown","markdown":"# Legacy App\n\nStock reservations per item, with a cancellation log. ...\n\n| Type | Effect | What it does |\n..."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to call any number of times; the answer changes only when the app is upgraded. The overview lists every type of the app, including ones your permissions hide from you. ' +
            'The overview is in English in every language; it is not translated.';
        exit(true);
    end;

    local procedure BuildOverview(): Text
    var
        Overview: TextBuilder;
    begin
        Overview.AppendLine('# Legacy App');
        Overview.AppendLine('');
        Overview.AppendLine('Stock reservations per item, with a cancellation log. The same rules apply as in the');
        Overview.AppendLine('app''s own pages; questions a person answers there are explicit parameters here.');
        Overview.AppendLine('');
        Overview.AppendLine('| Type | Effect | What it does |');
        Overview.AppendLine('| --- | --- | --- |');
        Overview.AppendLine('| `Legacy.Stock.Get` | Read-only | Reserved and still-available quantity of one item. |');
        Overview.AppendLine('| `Legacy.Stock.List` | Read-only | All reservations or those matching an item filter, with count. |');
        Overview.AppendLine('| `Legacy.Stock.Reserve` | Commits | Adds to an item''s reservation; refuses over stock unless `allowOverStock`. Not safe to repeat. |');
        Overview.AppendLine('| `Legacy.Stock.CancelReservation` | Commits | Cancels one item''s reservation. Safe to repeat. |');
        Overview.AppendLine('| `Legacy.Stock.ReleaseAll` | Commits, irreversible | Releases every reservation matching a filter; needs `expectedCount` from List. |');
        Overview.AppendLine('| `Help.Legacy.Get` | Read-only | This overview. |');
        Overview.AppendLine('');
        Overview.AppendLine('For the contract of any one type, call `Help.Implementation.Get` with its name.');
        exit(Overview.ToText());
    end;
}
