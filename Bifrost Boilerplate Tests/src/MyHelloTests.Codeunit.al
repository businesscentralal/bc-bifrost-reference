namespace MyCompany.MyBifrostApp.Tests;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// MyApp.Hello.Get - the Hello World. If these two tests pass, the app is published, its type is
/// registered and callable through Foundation's Dispatcher, and input errors come back as answers.
/// </summary>
codeunit 50053 "My Hello Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "My Test Caller";

    [Test]
    procedure HelloGreetsByNameAndNamesTheApp()
    var
        Response: JsonObject;
    begin
        // [WHEN] Hello is called with a name
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Hello.Get", '', '{"name":"Anna"}');

        // [THEN] it greets that name and says which app answered
        Caller.AssertOk(Response);
        Assert.IsTrue(Caller.GetText(Response, 'message').Contains('Anna'), 'The greeting should use the name sent.');
        Assert.AreEqual(CompanyName(), Caller.GetText(Response, 'company'), 'company');
        Assert.AreNotEqual('', Caller.GetText(Response, 'appVersion'), 'The answer should name the app version.');
    end;

    [Test]
    procedure HelloRefusesATooLongName()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"MyApp.Hello.Get", '', '{"name":"' + PadStr('', 60, 'x') + '"}'),
            'the maximum is 50');
    end;
}
