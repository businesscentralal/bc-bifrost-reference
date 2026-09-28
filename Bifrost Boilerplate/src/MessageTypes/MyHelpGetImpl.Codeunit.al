namespace MyCompany.MyBifrostApp;

using Origo.Bifrost;

/// <summary>
/// Implements Help.MyApp.Get: the app's directory. Every Bifröst app exposes one Help type named
/// after the app that returns a Markdown overview of the app and lists its message types, so a
/// caller - usually an agent - can learn what this app adds without walking the whole catalogue.
/// No request body is required. Keep the table in BuildOverview in step with the enum extension.
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see START-HERE.md section 4.</remarks>
codeunit 50005 "My Help Get Impl" implements "Msg Interface ori"
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
        // TODO: put your app's name here.
        exit('Returns a Markdown overview of My Bifrost App and lists its message types. Read-only. No request body is required.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        // TODO: rename Help.MyApp.Get and My Bifrost App in every line below.
        HelpText.AppendLine('# Help.MyApp.Get');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Returns a Markdown overview of My Bifrost App: what it is for and the list of message types');
        HelpText.AppendLine('it adds, each with a one-line description. Use it first when you want to know what this app');
        HelpText.AppendLine('offers before calling anything in it. Not for the contract of one operation - ask');
        HelpText.AppendLine('`Help.Implementation.Get` for that.');
        HelpText.AppendLine('');
        HelpText.AppendLine('**Effect:** Read-only. Nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Workflow');
        HelpText.AppendLine('This type -> `Help.Implementation.Get` for the type you want -> that type.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Identifying the target');
        HelpText.AppendLine('None: `subject` is not used.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Parameters');
        HelpText.AppendLine('None. Send an empty object or no body.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "type": "Help.MyApp.Get" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('One object: `format` is always `markdown`; `markdown` is the overview document as text.');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "format": "markdown", "markdown": "# My Bifrost App\n\n..." }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('There is no empty result; the overview always has content.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('The operation has no error conditions of its own.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safe retries / repeat');
        HelpText.AppendLine('Read-only; safe to repeat. The answer changes only when the app is upgraded.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Permissions and side effects');
        HelpText.AppendLine('Visible to every user. No side effects.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Formats and language');
        HelpText.AppendLine('The overview is Markdown text, in English.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related message types');
        HelpText.AppendLine('- `Help.MessageTypes.Get` - the whole catalogue across all installed apps.');
        HelpText.AppendLine('- `Help.Implementation.Get` - the full contract of one message type.');
        Argument.SetResponseMarkdown(HelpText.ToText());
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

    local procedure BuildOverview(): Text
    var
        Overview: TextBuilder;
    begin
        // TODO: describe your app and list every message type it adds, one row each.
        Overview.AppendLine('# My Bifrost App');
        Overview.AppendLine('');
        Overview.AppendLine('An app built on Bifrost Foundation. It reads items: one item''s price and inventory, or a');
        Overview.AppendLine('capped list of items.');
        Overview.AppendLine('');
        Overview.AppendLine('## Message types');
        Overview.AppendLine('| Type | Effect | What it does |');
        Overview.AppendLine('| --- | --- | --- |');
        Overview.AppendLine('| `MyApp.Hello.Get` | Read-only | Hello World: greeting, user, company and app version. Call it first. |');
        Overview.AppendLine('| `MyApp.Item.Summary.Get` | Read-only | One item''s description, base unit, unit price and inventory as of a date. |');
        Overview.AppendLine('| `MyApp.Item.List` | Read-only | Items by number filter, at most 100 rows, with the total count. |');
        Overview.AppendLine('| `Help.MyApp.Get` | Read-only | This overview. |');
        Overview.AppendLine('');
        Overview.AppendLine('For the contract of any one type, call `Help.Implementation.Get` with its name.');
        exit(Overview.ToText());
    end;
}
