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
codeunit 90013 "Ref Maint Create Impl" implements "Msg Interface ori"
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

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref Maint Create Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
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
}
