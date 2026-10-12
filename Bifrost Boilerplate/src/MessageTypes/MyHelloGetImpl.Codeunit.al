namespace MyCompany.MyBifrostApp;

using Origo.Bifrost;

/// <summary>
/// Implements MyApp.Hello.Get: the Hello World of a Bifröst app, and the first call to make after
/// every publish. It reads no business data, so an answer proves the whole path works: the app is
/// published, its enum value is registered, IsEnabled lets the caller see it, the caller reaches it
/// over the API or MCP server, and the answer comes back in the caller's language. The answer also
/// names the app version that replied - the quickest way to see whether a new publish is live.
///
/// Three interfaces on one codeunit, the same for every type you add:
/// - "Msg Interface ori" runs the call;
/// - "Msg Discovery ori" helps an agent find it (keywords, and what it is NOT for);
/// - "Msg Contract ori" is the use card an agent reads before calling, one chapter per procedure.
///   Return true from a chapter you fill and false from one that does not apply.
/// </summary>
/// <remarks>Public document: the chapters are returned to every caller. Contract only - see START-HERE.md section 4.</remarks>
codeunit 50007 "My Hello Get Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        GreetingTxt: Label 'Hello, %1! My Bifrost App is working in %2.', Comment = '%1 = the name sent, or the user, %2 = company name, is-IS=Halló, %1! My Bifrost App virkar í %2.';

    // ---------- Msg Interface ori: what the type is, and running it ----------

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
        // TODO: put your app's name here.
        exit('Hello World for My Bifrost App: answers with a greeting, the user, the company and the app version. Read-only; reads no business data. Call it first after publishing to check the app is live.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        MyInput: Codeunit "My Input";
        AppInfo: ModuleInfo;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Name: Text;
        HasName: Boolean;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not MyInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not MyInput.GetOptionalText(Argument, RequestJson, 'name', 50, Name, HasName) then
            exit;
        if Name = '' then
            Name := UserId();

        NavApp.GetCurrentModuleInfo(AppInfo);
        ResponseJson.Add('message', StrSubstNo(GreetingTxt, Name, CompanyName()));
        ResponseJson.Add('user', UserId());
        ResponseJson.Add('company', CompanyName());
        ResponseJson.Add('language', GlobalLanguage());
        ResponseJson.Add('serverTime', Format(CurrentDateTime(), 0, 9));
        ResponseJson.Add('app', AppInfo.Name());
        ResponseJson.Add('appVersion', Format(AppInfo.AppVersion()));
        Argument.SetResponseJson(ResponseJson);
    end;

    // ---------- Msg Discovery ori: how an agent finds it ----------

    /// <summary>Words people actually say for this. Translatable, never Locked.</summary>
    procedure GetKeywords(): Text
    var
        // TODO: put your app's name in both texts.
        KeywordsLbl: Label 'hello, is my app working, test the connection to my app, check the app is installed, which version of my app is installed', Comment = 'is-IS=halló, virkar appið mitt, prófa tenginguna við appið mitt, athuga hvort appið sé uppsett, hvaða útgáfa af appinu mínu er uppsett';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings: what it is for, and what to use instead.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Check that My Bifrost App is installed and answering: a greeting, the user, the company and the app version. Not for business data: for what the app offers, use Help.MyApp.Get.', Comment = 'is-IS=Athuga hvort My Bifrost App sé uppsett og svari: kveðja, notandinn, fyrirtækið og útgáfa appsins. Ekki fyrir viðskiptagögn: til að sjá hvað appið býður, notaðu Help.MyApp.Get.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori: the use card, one chapter per procedure ----------
    // TODO: rename MyApp.Hello.Get and My Bifrost App in every chapter below.

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Hello World for My Bifrost App. Answers with a greeting, who you are, which company you are in, and which version of the app answered. ' +
            'Use it to check that the app is installed and reachable, for example right after a publish. Not for business data: use the app''s other types for that.';
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

    /// <summary>No target: the type reads no record.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('name', 'string', false, 'Who to greet, at most 50 characters. Omitted: the user''s name as Business Central knows it.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('message', 'string', 'The greeting, in the caller''s language when a translation is installed.'));
        Fields.Add(ContractMgt.ResponseField('user', 'string', 'The user who called.'));
        Fields.Add(ContractMgt.ResponseField('company', 'string', 'The company the call ran in.'));
        Fields.Add(ContractMgt.ResponseField('language', 'integer', 'The Windows language id the answer was made in, for example 1033 for English or 1039 for Icelandic.'));
        Fields.Add(ContractMgt.ResponseField('serverTime', 'string', 'The server time, ISO 8601 in UTC.'));
        Fields.Add(ContractMgt.ResponseField('app', 'string', 'The name of the app that answered.'));
        Fields.Add(ContractMgt.ResponseField('appVersion', 'string', 'The version of the app that answered.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// Each text is verbatim from a Label in My Input, with {placeholders} for its %1, %2.
    /// Change a Label and this list in the same commit.
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''name'' is {length} characters long; the maximum is 50.', 'name is too long.', 'Send a shorter name.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''name'' must be a single value (text or number), not an object or an array.', 'name is an object or an array.', 'Send it as text.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, with its parameters by name, for example { "name": "value" }.', 'data is an array or plain text.', 'Send a JSON object, or no body at all.'));
        exit(true);
    end;

    /// <summary>Preconditions say what IsEnabled checks: here nothing, so every user sees the type.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads no business data.');
        Effect.Add('idempotent', true);
        Preconditions.Add('None beyond calling Bifrost: every user sees this type.');
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
        Related.Add(ContractMgt.RelatedEntry('Help.MyApp.Get', 'You want to know what this app offers.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('MyApp.Hello.Get', 'Check that the app is live.'));
        Steps.Add(ContractMgt.WorkflowStep('Help.MyApp.Get', 'See what the app offers.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'The first call after a publish, then the app''s directory.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Say hello',
            '{"type":"MyApp.Hello.Get","data":{"name":"World"}}',
            '{"message":"Hello, World! My Bifrost App is working in CRONUS.","user":"ADMIN","company":"CRONUS","language":1033,"serverTime":"2026-09-27T09:15:00.000Z","app":"My Bifrost App","appVersion":"1.0.0.0"}'));
        Examples.Add(ContractMgt.Example('A name that is too long',
            '{"type":"MyApp.Hello.Get","data":{"name":"A name of sixty characters ................................."}}',
            '{"status":"Error","error":"Parameter ''name'' is 60 characters long; the maximum is 50."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Safe to repeat: only serverTime changes between calls. message is translated when a translation for the caller''s language is installed; error texts follow lcid the same way.';
        exit(true);
    end;
}
