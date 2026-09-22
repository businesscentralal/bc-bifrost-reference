namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost;
using Origo.Bifrost.Reference.Legacy;

/// <summary>
/// The "easy" case: ReserveStock has no dialogs and no intermediate commit, so this
/// impl codeunit calls it directly. No change to Legacy App was needed for this one.
/// </summary>
/// <remarks>Public document: this text is returned to every caller and published on the documentation site. Contract only — see WRITING-HELP.md.</remarks>
codeunit 90100 "Legacy Stock Reserve Impl" implements "Msg Interface ori"
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
    /// Caller-facing description of the operation. Retrofit note: this is a thin wrapper over
    /// Legacy App's ReserveStock, which was already safe to call headlessly (no dialogs, no
    /// intermediate commit), so Legacy App itself was not changed for this type.
    /// </summary>
    internal procedure GetDescription(): Text[250]
    begin
        exit('Reserves a quantity of an item in Legacy App. Adds to any reservation that already exists for the item; the quantity must be greater than zero.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Legacy.Stock.Reserve');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Reserves a quantity of one item in Legacy App. If the item already has a reservation,');
        HelpText.AppendLine('the quantity is added to it; otherwise a new reservation is created. Legacy App keeps');
        HelpText.AppendLine('one reservation per item.');
        HelpText.AppendLine('');
        HelpText.AppendLine('Use it to increase the reserved quantity of an item. Not for reducing or removing a');
        HelpText.AppendLine('reservation (negative quantities are rejected) - use `Legacy.Stock.CancelReservation`');
        HelpText.AppendLine('to remove one. Not for reading the current reserved quantity. The item number is not');
        HelpText.AppendLine('checked against any item list.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Direction');
        HelpText.AppendLine('Inbound - a write. On success one Legacy Stock Reservation record is inserted or its');
        HelpText.AppendLine('quantity increased. On failure nothing is written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request');
        HelpText.AppendLine('| Field | Type | Required | Default | Notes |');
        HelpText.AppendLine('| --- | --- | --- | --- | --- |');
        HelpText.AppendLine('| `itemNo` | string | yes | - | Item number, max 20 characters; longer values are cut to 20. Stored as a code value (upper case). |');
        HelpText.AppendLine('| `quantity` | number | yes | - | Quantity to add to the reservation. Must be a number greater than zero; decimals allowed. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "itemNo": "1000", "quantity": 5 }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('One object echoing the item number and the quantity added **by this call** - not the');
        HelpText.AppendLine('item''s total reserved quantity. No `status` field means success.');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "itemNo": "1000", "quantity": 5 }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('There is no empty result: the call either reserves the quantity or fails.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('Every error has the shape `{"status":"Error","error":"...","hint":"..."}`; `hint`');
        HelpText.AppendLine('points back to this document. On every error listed here nothing has been written.');
        HelpText.AppendLine('');
        HelpText.AppendLine('| `error` | Meaning | `hint` |');
        HelpText.AppendLine('| --- | --- | --- |');
        HelpText.AppendLine('| `Missing required field ''itemNo''.` | The request has no `itemNo` field. | Send both `itemNo` and `quantity`. |');
        HelpText.AppendLine('| `Missing required field ''quantity''.` | The request has no `quantity` field. | Send both `itemNo` and `quantity`. |');
        HelpText.AppendLine('| `Quantity must be a number.` | `quantity` is present but cannot be read as a number (non-numeric text, `true`/`false`, `null`, an object or an array). | Send `quantity` as a JSON number, e.g. `5` or `2.5`. |');
        HelpText.AppendLine('| `Quantity must be greater than zero.` | `quantity` is a number but is zero or negative. | Send a quantity above zero. To reduce a reservation use `Legacy.Stock.CancelReservation`. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('Example:');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "status": "Error", "error": "Quantity must be greater than zero.", "hint": "..." }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safety / repeat');
        HelpText.AppendLine('**Not safe to repeat.** Every successful call adds its quantity to the reservation:');
        HelpText.AppendLine('sending `{ "itemNo": "1000", "quantity": 5 }` twice leaves 10 reserved, not 5. A caller');
        HelpText.AppendLine('that retries after a timeout may double-reserve; cancel with');
        HelpText.AppendLine('`Legacy.Stock.CancelReservation` and reserve again if the outcome is uncertain.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related types');
        HelpText.AppendLine('- `Legacy.Stock.CancelReservation` - removes the whole reservation for an item.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        LegacyStockMgt: Codeunit "Legacy Stock Mgt";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNoToken: JsonToken;
        QuantityToken: JsonToken;
        ItemNo: Code[20];
        Quantity: Decimal;
        InvalidQuantityErr: Label 'Quantity must be greater than zero.';
        QuantityNotNumericErr: Label 'Quantity must be a number.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', ItemNoToken) then begin
            Argument.RespondWithError('Missing required field ''itemNo''.');
            exit;
        end;
        if not RequestJson.Get('quantity', QuantityToken) then begin
            Argument.RespondWithError('Missing required field ''quantity''.');
            exit;
        end;

        ItemNo := CopyStr(ItemNoToken.AsValue().AsText(), 1, 20);

        // 'quantity' must be a numeric JSON value; anything else (text, null, object, array)
        // is reported as a structured error instead of failing inside AsDecimal().
        if not QuantityToken.IsValue() then begin
            Argument.RespondWithError(QuantityNotNumericErr);
            exit;
        end;
        if QuantityToken.AsValue().IsNull() then begin
            Argument.RespondWithError(QuantityNotNumericErr);
            exit;
        end;
        if not Evaluate(Quantity, QuantityToken.AsValue().AsText(), 9) then begin
            Argument.RespondWithError(QuantityNotNumericErr);
            exit;
        end;

        if not LegacyStockMgt.ReserveStock(ItemNo, Quantity) then begin
            Argument.RespondWithError(InvalidQuantityErr);
            exit;
        end;

        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('quantity', Quantity);
        Argument.SetResponseJson(ResponseJson);
    end;
}
