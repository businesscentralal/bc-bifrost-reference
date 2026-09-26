namespace Origo.Bifrost.Reference.Tests;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Reference;
using System.TestLibraries.Utilities;

/// <summary>
/// Reference.ServiceVisit.Create - the break set and the safe retry, as unit tests. Each test is
/// one line of the live test plan (TESTING.md), so a change that breaks an answer an agent relies
/// on fails the build instead of a customer's first call.
/// </summary>
codeunit 90152 "Service Visit Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "Ref Test Caller";
        CustomerNoTok: Label 'BIFT-T1', Locked = true;

    [Test]
    procedure LocalDateFormatIsRefusedWithTheIsoFormat()
    begin
        // [GIVEN] a customer  [WHEN] the date is sent as 26.09.2026
        CreateCustomer();
        // [THEN] the answer names the parameter, echoes the value and gives the format to send
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.ServiceVisit.Create", CustomerNoTok, '{"visitDate":"26.09.2026","hours":1}'),
            'YYYY-MM-DD');
    end;

    [Test]
    procedure UnknownCustomerIsNotFoundRatherThanMissing()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.ServiceVisit.Create", 'BIFT-NOPE', '{"visitDate":"2026-01-02","hours":1}'),
            'was not found');
    end;

    [Test]
    procedure NoCustomerAtAllIsMissingRatherThanNotFound()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.ServiceVisit.Create", '', '{"visitDate":"2026-01-02","hours":1}'),
            'No customer was given');
    end;

    [Test]
    procedure VisitInTheFutureIsRefused()
    begin
        CreateCustomer();
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.ServiceVisit.Create", CustomerNoTok,
                StrSubstNo('{"visitDate":"%1","hours":1}', Format(CalcDate('<+1D>', WorkDate()), 0, 9))),
            'after the work date');
    end;

    [Test]
    procedure HoursOutOfRangeIsRefused()
    begin
        CreateCustomer();
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.ServiceVisit.Create", CustomerNoTok, '{"visitDate":"2026-01-02","hours":30}'),
            'must be between');
    end;

    [Test]
    procedure SameExternalIdTwiceWritesOneVisit()
    var
        ServiceVisit: Record "Ref Service Visit";
        Request: Text;
        First: JsonObject;
        Second: JsonObject;
    begin
        // [GIVEN] a customer and a request carrying an externalId
        CreateCustomer();
        Request := '{"visitDate":"2026-01-02","hours":1.5,"description":"Annual check","externalId":"BIFT-CRM-1"}';

        // [WHEN] the same request is sent twice, as a client retrying after a timeout would
        First := Caller.Call(Enum::"Message Type ori"::"Reference.ServiceVisit.Create", CustomerNoTok, Request);
        Second := Caller.Call(Enum::"Message Type ori"::"Reference.ServiceVisit.Create", CustomerNoTok, Request);

        // [THEN] the first call created the visit, the second returned it, and there is one row
        Caller.AssertOk(First);
        Assert.IsTrue(Caller.GetBoolean(First, 'created'), 'The first call should create the visit.');
        Assert.IsFalse(Caller.GetBoolean(Second, 'created'), 'The retry should return the existing visit.');
        Assert.AreEqual(Caller.GetText(First, 'entryNo'), Caller.GetText(Second, 'entryNo'), 'Both calls should answer with the same visit.');
        ServiceVisit.SetRange("External Id", 'BIFT-CRM-1');
        Assert.RecordCount(ServiceVisit, 1);
    end;

    [Test]
    procedure HelpListsTheErrorTheTypeReallyReturns()
    begin
        // The help is the agent's only guide: it must quote the real error text, not an old one.
        Assert.IsTrue(Caller.GetHelp('Reference.ServiceVisit.Create').Contains('YYYY-MM-DD'), 'The help should document the date format error.');
    end;

    local procedure CreateCustomer()
    var
        Customer: Record Customer;
    begin
        if Customer.Get(CustomerNoTok) then
            exit;
        Customer.Init();
        Customer."No." := CustomerNoTok;
        Customer.Name := 'Bifrost test customer';
        Customer.Insert(true);
    end;
}
