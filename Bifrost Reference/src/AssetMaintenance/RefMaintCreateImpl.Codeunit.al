namespace Origo.Bifrost.Reference;

using Microsoft.FixedAssets.FixedAsset;
using Origo.Bifrost;

/// <summary>
/// Reference.AssetMaintenance.Create - the reference WRITE.
///
/// Patterns shown:
///  - validate ALL input first, with no writes, through the shared input layer: a bad date,
///    hour count or asset is answered before anything is touched;
///  - business rules give errors that say what to do next (blocked or inactive asset,
///    maintenance in the future);
///  - the write itself runs in an isolated codeunit instance ("Ref Maint Create Process"), so a
///    failure rolls back cleanly and comes back as status = Error; "Omit Commit" is honoured;
///  - safe retries: an optional externalId makes a repeated call return the first entry
///    ("created": false) instead of writing a duplicate;
///  - IsEnabled checks exactly the permissions the type needs.
/// </summary>
codeunit 90013 "Ref Maint Create Impl" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        BlockedErr: Label 'Fixed asset ''%1'' is blocked, so no maintenance can be logged. Clear Blocked on the fixed asset card in Business Central, or choose another asset.', Comment = '%1 = fixed asset no., is-IS=Eignin ''%1'' er lokuð og því er ekki hægt að skrá viðhald á hana. Taktu hakið úr Lokað á eignaspjaldinu í Business Central eða veldu aðra eign.';
        InactiveErr: Label 'Fixed asset ''%1'' is inactive, so no maintenance can be logged. Clear Inactive on the fixed asset card in Business Central, or choose another asset.', Comment = '%1 = fixed asset no., is-IS=Eignin ''%1'' er óvirk og því er ekki hægt að skrá viðhald á hana. Taktu hakið úr Óvirk á eignaspjaldinu í Business Central eða veldu aðra eign.';
        FutureDateErr: Label 'Parameter ''maintenanceDate'' is %1, which is after the work date %2. Maintenance is logged after it is done; send a date on or before %2.', Comment = '%1 = maintenance date, %2 = work date, is-IS=Færibreytan ''maintenanceDate'' er %1, sem er eftir vinnudagsetningu %2. Viðhald er skráð eftir að það hefur verið unnið; sendu dagsetningu sem er %2 eða fyrr.';

    procedure IsEnabled(): Boolean
    var
        AssetMaintenance: Record "Ref Asset Maintenance";
        FixedAsset: Record "Fixed Asset";
    begin
        exit(AssetMaintenance.WritePermission() and FixedAsset.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Ref Asset Maintenance");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Log maintenance work on a fixed asset (machine, vehicle): date, hours and a short note. Commits; safe to retry with the same externalId. Not for FA ledger entries, depreciation or posting maintenance costs.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        FixedAsset: Record "Fixed Asset";
        MaintProcess: Codeunit "Ref Maint Create Process";
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
        MaintenanceDate: Date;
        Hours: Decimal;
        Description: Text;
        ExternalId: Text;
        HasDescription: Boolean;
        HasExternalId: Boolean;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        // 1. Validate everything. No writes happen in this block.
        if not RefInput.ReadRequest(Argument, RequestJson) then
            exit;
        FixedAsset.SetLoadFields("No.", Blocked, Inactive);
        if not RefInput.ResolveFixedAsset(Argument, RequestJson, FixedAsset) then
            exit;
        if FixedAsset.Blocked then begin
            Argument.RespondWithError(StrSubstNo(BlockedErr, FixedAsset."No."));
            exit;
        end;
        if FixedAsset.Inactive then begin
            Argument.RespondWithError(StrSubstNo(InactiveErr, FixedAsset."No."));
            exit;
        end;
        if not RefInput.GetRequiredDate(Argument, RequestJson, 'maintenanceDate', MaintenanceDate) then
            exit;
        if MaintenanceDate > WorkDate() then begin
            Argument.RespondWithError(StrSubstNo(FutureDateErr, Format(MaintenanceDate, 0, 9), Format(WorkDate(), 0, 9)));
            exit;
        end;
        if not RefInput.GetRequiredDecimal(Argument, RequestJson, 'hours', 0.25, 24, Hours) then
            exit;
        if not RefInput.GetOptionalText(Argument, RequestJson, 'description', 100, Description, HasDescription) then
            exit;
        if not RefInput.GetOptionalText(Argument, RequestJson, 'externalId', 50, ExternalId, HasExternalId) then
            exit;

        // 2. Write in isolation. The process instance carries the validated values.
        MaintProcess.SetMaintenance(FixedAsset."No.", MaintenanceDate, Hours, CopyStr(Description, 1, 100), CopyStr(ExternalId, 1, 50));
        if Argument."Omit Commit" then
            MaintProcess.Run(Argument)
        else
            if not MaintProcess.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;

    // ---------- Msg Discovery ori ----------

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'log maintenance, record service on a machine, register repair work, maintenance log, hours spent on an asset, vehicle service', Comment = 'is-IS=skrá viðhald, skrá þjónustu á vél, skrá viðgerð, viðhaldsskrá, tímar á eign, þjónusta á ökutæki';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Log maintenance work done on one fixed asset: date, hours and a short note. Posts nothing and changes no amount. For FA ledger entries or maintenance costs, use FA journals; to read the log back, use Data.Records.Get on Ref Asset Maintenance.', Comment = 'is-IS=Skrá viðhaldsvinnu á einni eign: dagsetningu, tíma og stutta athugasemd. Bókar ekkert og breytir engri upphæð. Fyrir eignafærslur eða viðhaldskostnað, notaðu eignabækur; til að lesa skrána, notaðu Data.Records.Get á Ref Asset Maintenance.';
    begin
        exit(SelectionLbl);
    end;

    // ---------- Msg Contract ori ----------

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Logs maintenance work done on one fixed asset (a machine, a vehicle): the date it was done, the hours spent and a short note. ' +
            'Not for FA ledger entries, depreciation, or posting maintenance costs: those go through FA journals. This is a simple work log; it posts nothing and changes no amount.';
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'optional');
        Subject.Add('description', 'The fixed asset: its SystemId (GUID) or its number. Leave it empty to send assetNo in data instead.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        // Tried in this order; the first one given is used.
        Target.Add(ContractMgt.TargetEntry('subject', 'SystemId (GUID)', 'The fixed asset''s SystemId. Tried first.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'fixed asset number', 'The fixed asset number, for example FA000010, case-insensitive.'));
        Target.Add(ContractMgt.TargetEntry('data.assetNo', 'fixed asset number', 'Used only when subject is empty.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('assetNo', 'string', false, 'The fixed asset number, at most 20 characters. Needed only when subject is empty. The asset must exist and be neither blocked nor inactive.'));
        Parameters.Add(ContractMgt.Parameter('maintenanceDate', 'string', true, 'The date the work was done, in the format YYYY-MM-DD, on or before the work date. 26.09.2026 is refused.'));
        Parameters.Add(ContractMgt.Parameter('hours', 'number', true, 'The hours spent, from 0.25 to 24, with a dot as decimal separator.'));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'A short note on the work done, at most 100 characters. Omitted: empty.'));
        Parameters.Add(ContractMgt.Parameter('externalId', 'string', false, 'Your own id for this entry, at most 50 characters. Makes the call safe to retry. Omitted: every call creates a new entry.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry''s number in the maintenance log.'));
        Fields.Add(ContractMgt.ResponseField('created', 'boolean', 'false when the externalId already existed: the response then describes the entry the earlier call created, and nothing new is written.'));
        Fields.Add(ContractMgt.ResponseField('assetNo', 'string', 'The fixed asset number.'));
        Fields.Add(ContractMgt.ResponseField('maintenanceDate', 'string', 'The date the work was done, YYYY-MM-DD.'));
        Fields.Add(ContractMgt.ResponseField('hours', 'number', 'The hours spent.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'As sent; empty when not sent.'));
        Fields.Add(ContractMgt.ResponseField('externalId', 'string', 'As sent; empty when not sent.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Error texts are verbatim from the Labels in this codeunit and in Ref Input.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.TextErrorEntry('No fixed asset was given. Send the asset number in subject or as "assetNo", or its SystemId in subject.', 'subject is empty and data has no assetNo.', 'Send the asset number in subject.'));
        Errors.Add(ContractMgt.TextErrorEntry('Fixed asset ''{asset}'' was not found. Check the number, or search for the asset with Data.Records.Get on table Fixed Asset.', 'No fixed asset has that number or SystemId.', 'Check the number, or search with Data.Records.Get.'));
        Errors.Add(ContractMgt.TextErrorEntry('Fixed asset ''{asset}'' is blocked, so no maintenance can be logged. Clear Blocked on the fixed asset card in Business Central, or choose another asset.', 'The asset is blocked.', 'Ask the user to unblock it, or choose another asset.'));
        Errors.Add(ContractMgt.TextErrorEntry('Fixed asset ''{asset}'' is inactive, so no maintenance can be logged. Clear Inactive on the fixed asset card in Business Central, or choose another asset.', 'The asset is inactive, for example sold or scrapped.', 'Ask the user whether the asset is still in use.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''maintenanceDate'' is required. Send it as a date in the format YYYY-MM-DD, for example "2026-09-26".', 'maintenanceDate is missing.', 'Send it.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''maintenanceDate'' has the value ''{value}'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.', 'maintenanceDate is not YYYY-MM-DD, for example 26.09.2026.', 'Send the date as YYYY-MM-DD.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''maintenanceDate'' is {date}, which is after the work date {workDate}. Maintenance is logged after it is done; send a date on or before {workDate}.', 'The date is in the future.', 'Log the work after it is done.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''hours'' is required. Send it as a number, for example 2.5.', 'hours is missing.', 'Send it.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''hours'' has the value ''{value}'', which is not a number. Send a number with a dot as decimal separator, for example 2.5.', 'hours is not a number.', 'Send for example 1.5.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''hours'' is {value}, but it must be between 0.25 and 24.', 'hours is out of range.', 'Send 0.25 to 24.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' is {length} characters long; the maximum is {maximum}.', 'A text is too long: description (100), externalId (50), assetNo (20).', 'Shorten it.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter ''{parameter}'' must be a single value (text or number), not an object or an array.', 'A parameter is an object or an array.', 'Send a single value.'));
        Errors.Add(ContractMgt.TextErrorEntry('The request body must be a JSON object, for example { "accountNo": "2910" }.', 'data is an array or plain text.', 'Send a JSON object.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Inserts one Ref Asset Maintenance record, or none when the same externalId was already used. No ledger entry and no amount on the asset. On any error nothing is written. An entry can be removed only in Business Central.');
        Effect.Add('idempotent', false);
        Preconditions.Add('The caller can write Ref Asset Maintenance and read Fixed Asset; without it the type is not offered.');
        Preconditions.Add('The fixed asset exists and is neither blocked nor inactive.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want to find the asset number (table Fixed Asset), or read the log back (table Ref Asset Maintenance).'));
        Related.Add(ContractMgt.RelatedEntry('Help.Reference.Get', 'You want the other types in this app.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', 'Optional: find the asset number on table Fixed Asset.'));
        Steps.Add(ContractMgt.WorkflowStep('Reference.AssetMaintenance.Create', 'Log the work, with an externalId when a retry is possible.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Standalone when you know the asset number.');
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Log an oil change',
            '{"type":"Reference.AssetMaintenance.Create","subject":"FA000010","data":{"maintenanceDate":"2026-09-25","hours":1.5,"description":"Oil change","externalId":"WO-4711"}}',
            '{"entryNo":12,"created":true,"assetNo":"FA000010","maintenanceDate":"2026-09-25","hours":1.5,"description":"Oil change","externalId":"WO-4711"}'));
        Examples.Add(ContractMgt.Example('A retry with the same externalId',
            '{"type":"Reference.AssetMaintenance.Create","subject":"FA000010","data":{"maintenanceDate":"2026-09-25","hours":1.5,"description":"Oil change","externalId":"WO-4711"}}',
            '{"entryNo":12,"created":false,"assetNo":"FA000010","maintenanceDate":"2026-09-25","hours":1.5,"description":"Oil change","externalId":"WO-4711"}'));
        Examples.Add(ContractMgt.Example('A date in the wrong format',
            '{"type":"Reference.AssetMaintenance.Create","subject":"FA000010","data":{"maintenanceDate":"26.09.2026","hours":1.5}}',
            '{"status":"Error","error":"Parameter ''maintenanceDate'' has the value ''26.09.2026'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26."}'));
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Send an externalId when a retry is possible (timeouts, queues): a second call with the same externalId writes nothing and returns the first entry with "created": false, even when the other values differ. Without an externalId, every call creates a new entry. ' +
            '"No fixed asset was given" and "Fixed asset ''X'' was not found" never mix. Dates are YYYY-MM-DD, numbers use a dot. Error texts follow lcid when a translation is installed.';
        exit(true);
    end;
}
