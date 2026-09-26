namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// The isolated write for Reference.ServiceVisit.Create. Runs through Codeunit.Run on an
/// instance, so SetVisit can hand over the values the Impl has already validated, and any
/// Error() here rolls back only this codeunit's writes.
/// </summary>
codeunit 90014 "Ref Visit Create Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        CustomerNo: Code[20];
        VisitDate: Date;
        Hours: Decimal;
        Description: Text[100];
        ExternalId: Text[50];

    trigger OnRun()
    var
        ServiceVisit: Record "Ref Service Visit";
        Created: Boolean;
    begin
        // Safe retry: the same externalId returns the visit the first call created.
        if ExternalId <> '' then begin
            // Lock so two concurrent retries with the same externalId cannot both insert.
            ServiceVisit.LockTable();
            ServiceVisit.SetCurrentKey("External Id");
            ServiceVisit.SetRange("External Id", ExternalId);
            if ServiceVisit.FindFirst() then begin
                Rec.SetResponseJson(BuildResponse(ServiceVisit, false));
                exit;
            end;
        end;

        ServiceVisit.Init();
        ServiceVisit."Customer No." := CustomerNo;
        ServiceVisit."Visit Date" := VisitDate;
        ServiceVisit.Hours := Hours;
        ServiceVisit.Description := Description;
        ServiceVisit."External Id" := ExternalId;
        ServiceVisit.Insert(true);
        Created := true;

        Rec.SetResponseJson(BuildResponse(ServiceVisit, Created));
    end;

    procedure SetVisit(NewCustomerNo: Code[20]; NewVisitDate: Date; NewHours: Decimal; NewDescription: Text[100]; NewExternalId: Text[50])
    begin
        CustomerNo := NewCustomerNo;
        VisitDate := NewVisitDate;
        Hours := NewHours;
        Description := NewDescription;
        ExternalId := NewExternalId;
    end;

    local procedure BuildResponse(ServiceVisit: Record "Ref Service Visit"; Created: Boolean) Response: JsonObject
    begin
        Response.Add('entryNo', ServiceVisit."Entry No.");
        Response.Add('created', Created);
        Response.Add('customerNo', ServiceVisit."Customer No.");
        Response.Add('visitDate', Format(ServiceVisit."Visit Date", 0, 9));
        Response.Add('hours', ServiceVisit.Hours);
        Response.Add('description', ServiceVisit.Description);
        Response.Add('externalId', ServiceVisit."External Id");
    end;
}
