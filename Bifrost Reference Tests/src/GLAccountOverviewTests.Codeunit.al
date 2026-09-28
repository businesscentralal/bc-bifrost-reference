namespace Origo.Bifrost.Reference.Tests;

using Microsoft.Finance.GeneralLedger.Account;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Reference.GLAccount.Overview.Get - the reference read, as unit tests: the amounts match the
/// base app's own FlowFields, "not found" is not "missing", the period rule is enforced, and a
/// value that was not asked for is JSON null rather than 0.
/// The account is taken from the company's chart of accounts, never hard-coded.
/// </summary>
codeunit 90154 "GL Account Overview Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "Ref Test Caller";

    [Test]
    procedure PostingAccountAnswersTheBaseAppAmounts()
    var
        GLAccount: Record "G/L Account";
        Response: JsonObject;
        FromDate: Date;
    begin
        // [GIVEN] an existing posting account and a period ending on the work date
        FindPostingAccount(GLAccount);
        FromDate := CalcDate('<-CM>', WorkDate());

        // [WHEN] the overview is asked for that period
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.GLAccount.Overview.Get", GLAccount."No.",
            StrSubstNo('{"asOfDate":"%1","fromDate":"%2"}', Format(WorkDate(), 0, 9), Format(FromDate, 0, 9)));

        // [THEN] the answer carries the account and the same amounts the base app calculates
        Caller.AssertOk(Response);
        GLAccount.SetRange("Date Filter", FromDate, WorkDate());
        GLAccount.CalcFields("Balance at Date", "Net Change");
        Assert.AreEqual(GLAccount."No.", Caller.GetText(Response, 'accountNo'), 'The answer should name the account asked for.');
        Assert.AreEqual('Posting', Caller.GetText(Response, 'accountType'), 'The account type should be returned by enum name.');
        Assert.AreEqual(GLAccount."Balance at Date", Caller.GetDecimal(Response, 'balanceAsOf'), 'balanceAsOf should equal Balance at Date up to asOfDate.');
        Assert.AreEqual(GLAccount."Net Change", Caller.GetDecimal(Response, 'netChange'), 'netChange should equal Net Change for fromDate..asOfDate.');
    end;

    [Test]
    procedure UnknownAccountIsNotFoundRatherThanMissing()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.GLAccount.Overview.Get", 'BIFT-NOPE', ''),
            'was not found');
    end;

    [Test]
    procedure FromDateAfterAsOfDateIsRefused()
    var
        GLAccount: Record "G/L Account";
    begin
        FindPostingAccount(GLAccount);
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"Reference.GLAccount.Overview.Get", GLAccount."No.", '{"asOfDate":"2026-08-31","fromDate":"2026-09-01"}'),
            'after ''asOfDate''');
    end;

    [Test]
    procedure NetChangeIsNullWithoutFromDate()
    var
        GLAccount: Record "G/L Account";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] a posting account  [WHEN] no fromDate is sent
        FindPostingAccount(GLAccount);
        Response := Caller.Call(Enum::"Message Type ori"::"Reference.GLAccount.Overview.Get", GLAccount."No.", '');

        // [THEN] netChange is JSON null - never 0 pretending to be a value - and the balance is still given
        Caller.AssertOk(Response);
        Assert.IsTrue(Response.Get('netChange', Token), 'netChange should always be present.');
        Assert.IsTrue(Token.AsValue().IsNull(), 'netChange should be null when no fromDate was sent.');
        Assert.AreEqual(Format(WorkDate(), 0, 9), Caller.GetText(Response, 'asOfDate'), 'asOfDate should default to the work date.');
    end;

    local procedure FindPostingAccount(var GLAccount: Record "G/L Account")
    begin
        GLAccount.SetRange("Account Type", GLAccount."Account Type"::Posting);
        Assert.IsTrue(GLAccount.FindFirst(), 'The company needs at least one posting G/L account for these tests.');
        GLAccount.SetRange("Account Type");
    end;
}
