namespace MyCompany.MyBifrostApp;

using Origo.Bifrost;

/// <summary>
/// Implements MyApp.Hello.Get: the Hello World of a Bifröst app, and the first call to make after
/// every publish. It reads no business data, so an answer proves the whole path works: the app is
/// published, its enum value is registered, IsEnabled lets the caller see it, the caller reaches it
/// over the API or MCP server, and the answer comes back in the caller's language. The answer also
/// names the app version that replied - the quickest way to see whether a new publish is live.
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see START-HERE.md section 4.</remarks>
codeunit 50007 "My Hello Get Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        GreetingTxt: Label 'Hello, %1! My Bifrost App is working in %2.', Comment = '%1 = the name sent, or the user, %2 = company name, is-IS=Halló, %1! My Bifrost App virkar í %2.';

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

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        // TODO: rename MyApp.Hello.Get and My Bifrost App in every line below.
        HelpText.AppendLine('# MyApp.Hello.Get');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Hello World for My Bifrost App. Answers with a greeting, who you are, which company you are in,');
        HelpText.AppendLine('and which version of the app answered. Use it to check that the app is installed and reachable,');
        HelpText.AppendLine('for example right after a publish. Not for business data - use the app''s other types for that.');
        HelpText.AppendLine('');
        HelpText.AppendLine('**Effect:** Read-only. Nothing is written and no business data is read.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Workflow');
        HelpText.AppendLine('This type first -> `Help.MyApp.Get` to see what the app offers.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Identifying the target');
        HelpText.AppendLine('None: `subject` is not used.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Parameters');
        HelpText.AppendLine('| Key | Type | Required | Rules |');
        HelpText.AppendLine('| --- | --- | --- | --- |');
        HelpText.AppendLine('| `name` | text, max 50 | no | Who to greet. Default: the user''s name as BC knows it. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "type": "MyApp.Hello.Get", "data": { "name": "Anna" } }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "message": "Hello, Anna! My Bifrost App is working in CRONUS.", "user": "ANNA", "company": "CRONUS",');
        HelpText.AppendLine('  "language": 1033, "serverTime": "2026-09-27T09:15:00.000Z", "app": "My Bifrost App", "appVersion": "1.0.0.0" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('`language` is the Windows language id the answer was made in; `message` follows it (1039 = Icelandic).');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('| `error` | Cause | Fix |');
        HelpText.AppendLine('| --- | --- | --- |');
        HelpText.AppendLine('| `Parameter ''name'' is 60 characters long; the maximum is 50.` | Name too long. | Send a shorter name. |');
        HelpText.AppendLine('| `Parameter ''name'' must be a single value (text or number), not an object or an array.` | Wrong JSON type. | Send text. |');
        HelpText.AppendLine('| `The request body must be a JSON object, ...` | Body is not an object. | Send an object or no body. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safe retries / repeat');
        HelpText.AppendLine('Read-only; safe to repeat. Only `serverTime` changes between calls.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Permissions and side effects');
        HelpText.AppendLine('Visible to every user of the app. No side effects.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Formats and language');
        HelpText.AppendLine('`serverTime` is ISO 8601 in UTC. `message` is translated when a translation for the caller''s language is installed.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related message types');
        HelpText.AppendLine('- `Help.MyApp.Get` - what this app offers.');
        Argument.SetResponseMarkdown(HelpText.ToText());
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
}
