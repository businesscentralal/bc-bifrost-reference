namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// The isolated write for Reference.AssetMaintenance.Create. Runs through Codeunit.Run on an
/// instance, so SetMaintenance can hand over the values the Impl has already validated, and any
/// Error() here rolls back only this codeunit's writes.
/// </summary>
codeunit 90014 "Ref Maint Create Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        AssetNo: Code[20];
        MaintenanceDate: Date;
        Hours: Decimal;
        Description: Text[100];
        ExternalId: Text[50];

    trigger OnRun()
    var
        AssetMaintenance: Record "Ref Asset Maintenance";
        Created: Boolean;
    begin
        // Safe retry: the same externalId returns the entry the first call created.
        if ExternalId <> '' then begin
            // Lock so two concurrent retries with the same externalId cannot both insert.
            AssetMaintenance.LockTable();
            AssetMaintenance.SetCurrentKey("External Id");
            AssetMaintenance.SetRange("External Id", ExternalId);
            if AssetMaintenance.FindFirst() then begin
                Rec.SetResponseJson(BuildResponse(AssetMaintenance, false));
                exit;
            end;
        end;

        AssetMaintenance.Init();
        AssetMaintenance."FA No." := AssetNo;
        AssetMaintenance."Maintenance Date" := MaintenanceDate;
        AssetMaintenance.Hours := Hours;
        AssetMaintenance.Description := Description;
        AssetMaintenance."External Id" := ExternalId;
        AssetMaintenance.Insert(true);
        Created := true;

        Rec.SetResponseJson(BuildResponse(AssetMaintenance, Created));
    end;

    /// <summary>
    /// Hands over the values the Impl has validated. Call it before Run.
    /// </summary>
    procedure SetMaintenance(NewAssetNo: Code[20]; NewMaintenanceDate: Date; NewHours: Decimal; NewDescription: Text[100]; NewExternalId: Text[50])
    begin
        AssetNo := NewAssetNo;
        MaintenanceDate := NewMaintenanceDate;
        Hours := NewHours;
        Description := NewDescription;
        ExternalId := NewExternalId;
    end;

    local procedure BuildResponse(AssetMaintenance: Record "Ref Asset Maintenance"; Created: Boolean) Response: JsonObject
    begin
        Response.Add('entryNo', AssetMaintenance."Entry No.");
        Response.Add('created', Created);
        Response.Add('assetNo', AssetMaintenance."FA No.");
        Response.Add('maintenanceDate', Format(AssetMaintenance."Maintenance Date", 0, 9));
        Response.Add('hours', AssetMaintenance.Hours);
        Response.Add('description', AssetMaintenance.Description);
        Response.Add('externalId', AssetMaintenance."External Id");
    end;
}
