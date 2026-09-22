namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Implements <c>Help.Reference.Get</c>: the app's directory. Every Bifröst app exposes one
/// <c>Help.&lt;App&gt;.Get</c> type that returns a Markdown overview of the app and lists its
/// message types, so a caller — usually an agent — can learn what this app adds without
/// walking the whole catalogue. No request body is required.
/// </summary>
/// <remarks>Public document: this text is returned to every caller and published on the documentation site. Contract only — see WRITING-HELP.md.</remarks>
codeunit 90007 "Ref Help Get Impl" implements "Msg Interface ori"
{
    Access = Internal;

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    internal procedure GetDescription(): Text[250]
    begin
        exit('Returns a Markdown overview of the Bifrost Reference app and lists its message types. No request body is required.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Help.Reference.Get');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Returns a Markdown overview of the Bifrost Reference app: what it is for and the list of');
        HelpText.AppendLine('message types it adds, each with a one-line description. Use it first when you want to know');
        HelpText.AppendLine('what this app offers before calling anything in it. Not for the contract of one operation -');
        HelpText.AppendLine('ask `Help.Implementation.Get` for that.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Direction');
        HelpText.AppendLine('Outbound - a read. Nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request');
        HelpText.AppendLine('No fields. Send an empty object.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{}');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('One object: `format` is always `markdown`; `markdown` is the overview document as text.');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "format": "markdown", "markdown": "# Bifrost Reference\n\n..." }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('There is no empty result; the overview always has content.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('The operation has no error conditions of its own.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safety / repeat');
        HelpText.AppendLine('Safe to call any number of times; the answer changes only when the app is upgraded.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related types');
        HelpText.AppendLine('- `Help.MessageTypes.Get` - the whole catalogue across all installed apps.');
        HelpText.AppendLine('- `Help.Implementation.Get` - the full contract of one message type.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
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
        Overview.AppendLine('# Bifrost Reference');
        Overview.AppendLine('');
        Overview.AppendLine('A sample app built on Bifrost Foundation. It exists to show, in the smallest honest form,');
        Overview.AppendLine('what a dependent app does: register message types, implement them, document them, register');
        Overview.AppendLine('with the app registry. It stores nothing a business would use.');
        Overview.AppendLine('');
        Overview.AppendLine('## Message types');
        Overview.AppendLine('| Type | Direction | What it does |');
        Overview.AppendLine('| --- | --- | --- |');
        Overview.AppendLine('| `Reference.Echo.Get` | Outbound | Returns what you sent plus the server time. A connectivity check. |');
        Overview.AppendLine('| `Reference.Table.Get` | Outbound | Returns a table''s object ID from its name. A read that can fail. |');
        Overview.AppendLine('| `Reference.Note.Add` | Inbound | Stores one note under a number you choose. A write that rejects duplicates. |');
        Overview.AppendLine('| `Help.Reference.Get` | Outbound | This overview. |');
        Overview.AppendLine('');
        Overview.AppendLine('For the contract of any one type, call `Help.Implementation.Get` with its name.');
        exit(Overview.ToText());
    end;
}
