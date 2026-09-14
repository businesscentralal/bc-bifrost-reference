namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference implementation of a message type. Echoes the request payload back with a
/// server timestamp added, demonstrating request parsing and response writing without
/// depending on any external system.
/// </summary>
codeunit 90000 "Ref Echo Set Impl" implements "Msg Interface ori"
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
        exit('Echoes the request payload back with a server timestamp added.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Reference.Echo.Set');
        HelpText.AppendLine(GetDescription());
        HelpText.AppendLine('');
        HelpText.AppendLine('**Request:** any JSON object, e.g. `{ "message": "hello" }`');
        HelpText.AppendLine('**Response:** the same object with a `serverTime` field added.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Replace('serverTime', CurrentDateTime()) then
            RequestJson.Add('serverTime', CurrentDateTime());
        Argument.SetResponseJson(RequestJson);
    end;
}
