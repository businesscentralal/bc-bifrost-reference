namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost;

/// <summary>
/// Help.Legacy.Get - the adapter's directory. Every Bifröst app exposes one Help.&lt;App&gt;.Get
/// type that says what the app is for and lists its message types, so an agent can learn the
/// whole app in one call instead of walking the catalogue.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90111 "Legacy Help Get Impl" implements "Msg Interface ori"
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

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Help.Legacy.Get');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Returns a Markdown overview of Legacy App''s message types. Use it first to see what the app');
        Help.AppendLine('offers. For the contract of one type, call `Help.Implementation.Get` with its name.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only. Safe to repeat.');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Help.Legacy.Get" }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "format": "markdown", "markdown": "# Legacy App\n\n..." }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('None of its own.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Help.MessageTypes.Get` (every installed app), `Help.Implementation.Get` (one type).');
        Argument.SetResponseMarkdown(Help.ToText());
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
        exit(Overview.ToText());
    end;
}
