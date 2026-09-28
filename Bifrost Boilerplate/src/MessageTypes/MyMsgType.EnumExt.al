namespace MyCompany.MyBifrostApp;

using Origo.Bifrost;

/// <summary>
/// Adds this app's message types to Bifröst Foundation's enum. The enum value name is what a
/// caller sends as the request's type, and - next to the description - the strongest signal an
/// agent uses to find the type. Name every type Area.Entity.Verb in words a user would say.
/// Value ids come from the app's own id range; never renumber a value once it is published.
/// </summary>
enumextension 50000 "My Msg Type" extends "Message Type ori"
{
    // TODO: rename MyApp to your own area (for example Fleet or Warranty) in all four names and
    // captions, and in the help codeunits and in the tests. Keep the Help type named after the app.

    // Hello World: the first call after every publish. Proves the app is live. Keep it.
    value(50003; "MyApp.Hello.Get")
    {
        Caption = 'MyApp.Hello.Get', Locked = true;
        Implementation = "Msg Interface ori" = "My Hello Get Impl";
    }
    // Read: a record resolved from subject, an optional date, FlowFields, nulls. See src/Items.
    value(50000; "MyApp.Item.Summary.Get")
    {
        Caption = 'MyApp.Item.Summary.Get', Locked = true;
        Implementation = "Msg Interface ori" = "My Item Summary Impl";
    }
    // Capped list: optional filter, count, returned, more. See src/Items.
    value(50001; "MyApp.Item.List")
    {
        Caption = 'MyApp.Item.List', Locked = true;
        Implementation = "Msg Interface ori" = "My Item List Impl";
    }
    // The app's directory type. Every Bifröst app has exactly one.
    value(50002; "Help.MyApp.Get")
    {
        Caption = 'Help.MyApp.Get', Locked = true;
        Implementation = "Msg Interface ori" = "My Help Get Impl";
    }
}
