namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost;
using Origo.Bifrost.Reference.Legacy;

/// <summary>
/// The "needed a refactor" case: this calls Legacy App's new CancelReservationSilent,
/// not the original CancelReservation (which asks a Confirm() question no automated
/// caller could ever answer). Legacy App gained one small, precise extraction for this -
/// see ADAPTING.md for the full reasoning and the diff that produced it.
/// </summary>
codeunit 90101 "Legacy Cancel Reserve Impl" implements "Msg Interface ori"
{
    Access = Internal;

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Legacy Stock Reservation");
    end;

    internal procedure GetDescription(): Text[250]
    begin
        exit('Cancels a reservation in Legacy App. Calls the silent core added during retrofitting, not the original interactive procedure.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Legacy.Stock.CancelReservation');
        HelpText.AppendLine(GetDescription());
        HelpText.AppendLine('');
        HelpText.AppendLine('**Request:** `{ "itemNo": "1000" }`');
        HelpText.AppendLine('**Response:** `{ "itemNo": "1000" }` - no `status` field means success.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        LegacyStockMgt: Codeunit "Legacy Stock Mgt";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNoToken: JsonToken;
        ItemNo: Code[20];
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', ItemNoToken) then begin
            Argument.RespondWithError('Missing required field ''itemNo''.');
            exit;
        end;
        ItemNo := CopyStr(ItemNoToken.AsValue().AsText(), 1, 20);

        // Calls the silent core added for this retrofit - never the Confirm()-driven
        // original. Both writes (delete + log) now succeed or fail together.
        LegacyStockMgt.CancelReservationSilent(ItemNo);

        ResponseJson.Add('itemNo', ItemNo);
        Argument.SetResponseJson(ResponseJson);
    end;
}
