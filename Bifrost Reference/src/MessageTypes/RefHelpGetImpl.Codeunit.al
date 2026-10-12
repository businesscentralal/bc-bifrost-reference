namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Implements <c>Help.Reference.Get</c>: the app's directory. Every Bifröst app exposes one
/// <c>Help.&lt;App&gt;.Get</c> type that returns a Markdown overview of the app and lists its
/// message types, so a caller — usually an agent — can learn what this app adds without
/// walking the whole catalogue. No request body is required.
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see START-HERE.md section 4.</remarks>
codeunit 90007 "Ref Help Get Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Returns a Markdown overview of the Bifrost Reference app and lists its message types. Read-only. No request body is required.');
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
        KeywordsLbl: Label 'what can the reference app do, list reference message types, reference app overview, help for the reference app, which operations does this app add', Comment = 'is-IS=hvað getur sýnisappið gert, lista skilaboðategundir sýnisappsins, yfirlit sýnisappsins, hjálp fyrir sýnisappið, hvaða aðgerðir bætir þetta app við';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'An overview of the Bifrost Reference app and the message types it adds, one line each. For the contract of one type, use Help.Implementation.Get; for every installed app, use Help.MessageTypes.Get.', Comment = 'is-IS=Yfirlit yfir Bifrost Reference appið og skilaboðategundirnar sem það bætir við, ein lína fyrir hverja. Fyrir samning einnar tegundar, notaðu Help.Implementation.Get; fyrir öll uppsett öpp, notaðu Help.MessageTypes.Get.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns a Markdown overview of the Bifrost Reference app: what it is for and the message types it adds, each with its effect and a one-line description. ' +
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
        Steps.Add(ContractMgt.WorkflowStep('Help.Reference.Get', 'See which message types the app adds.'));
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
            '{"type":"Help.Reference.Get","data":{}}',
            '{"format":"markdown","markdown":"# Bifrost Reference\n\nA sample app built on Bifrost Foundation. ...\n\n## Message types\n| Type | Effect | What it does |\n..."}'));
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
        Overview.AppendLine('# Bifrost Reference');
        Overview.AppendLine('');
        Overview.AppendLine('A sample app built on Bifrost Foundation. Each message type shows one pattern a partner app');
        Overview.AppendLine('needs: reading a record, validated writes with safe retries, a preview/apply pair for a bulk');
        Overview.AppendLine('change, an external HTTP call with a secret. The data it writes is sample data only.');
        Overview.AppendLine('');
        Overview.AppendLine('## Message types');
        Overview.AppendLine('| Type | Effect | What it does |');
        Overview.AppendLine('| --- | --- | --- |');
        Overview.AppendLine('| `Reference.GLAccount.Overview.Get` | Read-only | A G/L account''s balance as of a date and its net change for a period. |');
        Overview.AppendLine('| `Reference.AssetMaintenance.Create` | Commits | Logs maintenance work on a fixed asset; safe to retry with externalId. |');
        Overview.AppendLine('| `Reference.ItemPrice.PreviewAdjustment` | Read-only | Shows a % unit price change for an item category. |');
        Overview.AppendLine('| `Reference.ItemPrice.ApplyAdjustment` | Commits | Applies that change; needs the preview''s itemCount. |');
        Overview.AppendLine('| `Reference.ExchangeRate.Get` | Read-only (internet) | Latest ECB rate between two currencies. |');
        Overview.AppendLine('| `Reference.ApiKey.Set` | Commits | Stores the rates API key as a secret. |');
        Overview.AppendLine('| `Reference.Echo.Get` | Read-only | Returns what you sent plus the server time. A connectivity check. |');
        Overview.AppendLine('| `Reference.Table.Get` | Read-only | Returns a table''s object ID from its name. |');
        Overview.AppendLine('| `Reference.Note.Add` | Commits | Stores one note under a number you choose. |');
        Overview.AppendLine('| `Help.Reference.Get` | Read-only | This overview. |');
        Overview.AppendLine('');
        Overview.AppendLine('For the contract of any one type, call `Help.Implementation.Get` with its name.');
        exit(Overview.ToText());
    end;
}
