namespace Origo.Bifrost.Reference;

using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>
/// Reference.ServiceVisit.Create - the reference WRITE.
///
/// Patterns shown:
///  - validate ALL input first, with no writes, through the shared input layer: a bad date,
///    hour count or customer is answered before anything is touched;
///  - business rules give errors that say what to do next (blocked customer, visit in the future);
///  - the write itself runs in an isolated codeunit instance ("Ref Visit Create Process"), so a
///    failure rolls back cleanly and comes back as status = Error; "Omit Commit" is honoured;
///  - safe retries: an optional externalId makes a repeated call return the first visit
///    ("created": false) instead of writing a duplicate;
///  - IsEnabled checks exactly the permissions the type needs.
/// </summary>
codeunit 90013 "Ref Visit Create Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        BlockedErr: Label 'Customer ''%1'' is blocked for all transactions, so no visit can be logged. Unblock the customer in Business Central or choose another customer.', Comment = '%1 = customer no., is-IS=Viðskiptamaðurinn ''%1'' er lokaður fyrir öllum færslum og því er ekki hægt að skrá heimsókn. Opnaðu viðskiptamanninn í Business Central eða veldu annan.';
        FutureDateErr: Label 'Parameter ''visitDate'' is %1, which is after the work date %2. Visits are logged after they happen; send a date on or before %2.', Comment = '%1 = visit date, %2 = work date, is-IS=Færibreytan ''visitDate'' er %1, sem er eftir vinnudagsetningu %2. Heimsóknir eru skráðar eftir á; sendu dagsetningu sem er %2 eða fyrr.';

    procedure IsEnabled(): Boolean
    var
        ServiceVisit: Record "Ref Service Visit";
        Customer: Record Customer;
    begin
        exit(ServiceVisit.WritePermission() and Customer.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Ref Service Visit");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Log a service visit at a customer: date, hours and a short description. Commits; safe to retry with the same externalId. Not for time sheets or project journal lines.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Ref Visit Create Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Customer: Record Customer;
        VisitProcess: Codeunit "Ref Visit Create Process";
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
        VisitDate: Date;
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
        Customer.SetLoadFields("No.", Blocked);
        if not RefInput.ResolveCustomer(Argument, RequestJson, Customer) then
            exit;
        if Customer.Blocked = Customer.Blocked::All then begin
            Argument.RespondWithError(StrSubstNo(BlockedErr, Customer."No."));
            exit;
        end;
        if not RefInput.GetRequiredDate(Argument, RequestJson, 'visitDate', VisitDate) then
            exit;
        if VisitDate > WorkDate() then begin
            Argument.RespondWithError(StrSubstNo(FutureDateErr, Format(VisitDate, 0, 9), Format(WorkDate(), 0, 9)));
            exit;
        end;
        if not RefInput.GetRequiredDecimal(Argument, RequestJson, 'hours', 0.25, 24, Hours) then
            exit;
        if not RefInput.GetOptionalText(Argument, RequestJson, 'description', 100, Description, HasDescription) then
            exit;
        if not RefInput.GetOptionalText(Argument, RequestJson, 'externalId', 50, ExternalId, HasExternalId) then
            exit;

        // 2. Write in isolation. The process instance carries the validated values.
        VisitProcess.SetVisit(Customer."No.", VisitDate, Hours, CopyStr(Description, 1, 100), CopyStr(ExternalId, 1, 50));
        if Argument."Omit Commit" then
            VisitProcess.Run(Argument)
        else
            if not VisitProcess.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
