namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost;
using Origo.Bifrost.Reference.Legacy;

/// <summary>
/// The "needed a refactor" case: this calls Legacy App's new CancelReservationSilent,
/// not the original CancelReservation (which asks a Confirm() question no automated
/// caller could ever answer). Legacy App gained one small, precise extraction for this -
/// see ADAPTING.md for the full reasoning and the diff that produced it.
/// </summary>
/// <remarks>Public document: this text is returned to every caller and published on the documentation site. Contract only — see WRITING-HELP.md.</remarks>
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

    /// <summary>
    /// Caller-facing description of the operation. Retrofit note: this type calls the silent
    /// CancelReservationSilent that was extracted from Legacy App during retrofitting - never
    /// the original CancelReservation, which asks a Confirm() question and committed between
    /// its two writes. See ADAPTING.md.
    /// </summary>
    internal procedure GetDescription(): Text[250]
    begin
        exit('Cancels the stock reservation for one item in Legacy App and records the cancellation in the cancellation log. Succeeds without effect if the item has no reservation.');
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
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Cancels the stock reservation for one item in Legacy App: the item''s reservation record');
        HelpText.AppendLine('is deleted, whatever its quantity, and one entry is written to the Legacy Cancellation');
        HelpText.AppendLine('Log with the item number and the time of cancellation.');
        HelpText.AppendLine('');
        HelpText.AppendLine('Use it to release everything reserved for an item. Not for reducing a reservation by a');
        HelpText.AppendLine('partial quantity - there is no partial cancel; the whole reservation goes. Not for');
        HelpText.AppendLine('checking whether a reservation exists: the response is the same either way.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Direction');
        HelpText.AppendLine('Inbound - a write. When a reservation exists, one record is deleted and one log entry');
        HelpText.AppendLine('inserted, together. When none exists, nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request');
        HelpText.AppendLine('| Field | Type | Required | Default | Notes |');
        HelpText.AppendLine('| --- | --- | --- | --- | --- |');
        HelpText.AppendLine('| `itemNo` | string | yes | - | Item number whose reservation to cancel, max 20 characters; longer values are cut to 20. Matched as a code value (upper case). |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "itemNo": "1000" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('One object echoing the item number. No `status` field means success.');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "itemNo": "1000" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('The no-op case looks identical: if the item had no reservation, nothing is deleted or');
        HelpText.AppendLine('logged and the same `{ "itemNo": "1000" }` is returned - not an error.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('Every error has the shape `{"status":"Error","error":"...","hint":"..."}`; `hint`');
        HelpText.AppendLine('points back to this document.');
        HelpText.AppendLine('');
        HelpText.AppendLine('| `error` | Meaning | `hint` |');
        HelpText.AppendLine('| --- | --- | --- |');
        HelpText.AppendLine('| `Missing required field ''itemNo''.` | The request has no `itemNo` field. | Send `{ "itemNo": "<item number>" }`. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('Example:');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "status": "Error", "error": "Missing required field ''itemNo''.", "hint": "..." }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safety / repeat');
        HelpText.AppendLine('Safe to repeat. The first call removes the reservation and logs it; a second call for');
        HelpText.AppendLine('the same item finds nothing, writes nothing, and still succeeds. Retrying after a');
        HelpText.AppendLine('timeout is harmless.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related types');
        HelpText.AppendLine('- `Legacy.Stock.Reserve` - adds quantity to an item''s reservation.');
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
