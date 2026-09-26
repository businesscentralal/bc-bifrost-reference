namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Implements <c>Help.Reference.Get</c>: the app's directory. Every Bifröst app exposes one
/// <c>Help.&lt;App&gt;.Get</c> type that returns a Markdown overview of the app and lists its
/// message types, so a caller — usually an agent — can learn what this app adds without
/// walking the whole catalogue. No request body is required.
/// </summary>
/// <remarks>Public document: this text is returned to every caller. Contract only - see CONTRACT.md.</remarks>
codeunit 90007 "Ref Help Get Impl" implements "Msg Interface ori"
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

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
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
        Overview.AppendLine('# Bifrost Reference');
        Overview.AppendLine('');
        Overview.AppendLine('A sample app built on Bifrost Foundation. Each message type shows one pattern a partner app');
        Overview.AppendLine('needs: reading a record, validated writes with safe retries, a preview/apply pair for a bulk');
        Overview.AppendLine('change, an external HTTP call with a secret. The data it writes is sample data only.');
        Overview.AppendLine('');
        Overview.AppendLine('## Message types');
        Overview.AppendLine('| Type | Effect | What it does |');
        Overview.AppendLine('| --- | --- | --- |');
        Overview.AppendLine('| `Reference.Customer.Overview.Get` | Read-only | A customer''s balance, overdue amount and available credit. |');
        Overview.AppendLine('| `Reference.ServiceVisit.Create` | Commits | Logs a service visit at a customer; safe to retry with externalId. |');
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
