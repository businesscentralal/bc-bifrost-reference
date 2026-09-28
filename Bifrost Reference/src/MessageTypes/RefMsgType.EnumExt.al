namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Adds this app's message types to Bifröst Foundation's enum. The enum value name is what a
/// caller sends as the request's `type`, and - next to the description - the strongest signal an
/// agent uses to find the type. Name every type Area.Entity.Verb in words a user would say.
/// </summary>
enumextension 90000 "Ref Msg Type" extends "Message Type ori"
{
    // Ordinal 90000 was "Reference.Echo.Set" until the rename; the type never wrote anything,
    // so the old verb claimed a write it did not perform. The ordinal is unchanged.
    value(90000; "Reference.Echo.Get")
    {
        Caption = 'Reference.Echo.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Echo Set Impl";
    }
    value(90001; "Reference.Table.Get")
    {
        Caption = 'Reference.Table.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Table Get Impl";
    }
    value(90002; "Reference.Note.Add")
    {
        Caption = 'Reference.Note.Add', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Note Add Impl";
    }
    // The app's directory type. Every Bifröst app has one Help.<App>.Get so a caller can learn
    // what the app adds without walking the whole catalogue.
    value(90003; "Help.Reference.Get")
    {
        Caption = 'Help.Reference.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Help Get Impl";
    }
    // Read: a record resolved from subject, optional dates, FlowFields, nulls. See src/GLAccounts.
    // Ordinals 90004 and 90005 were renamed when the samples moved off personal data (GDPR):
    // a reference app shows patterns on business data only. The ordinals are unchanged.
    value(90004; "Reference.GLAccount.Overview.Get")
    {
        Caption = 'Reference.GLAccount.Overview.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Ref GLAcc Overview Impl";
    }
    // Write: validated input, isolated write, safe retry. See src/AssetMaintenance.
    value(90005; "Reference.AssetMaintenance.Create")
    {
        Caption = 'Reference.AssetMaintenance.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Maint Create Impl";
    }
    // Preview / apply pair for an irreversible bulk change. See src/Prices.
    value(90006; "Reference.ItemPrice.PreviewAdjustment")
    {
        Caption = 'Reference.ItemPrice.PreviewAdjustment', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Price Preview Impl";
    }
    value(90007; "Reference.ItemPrice.ApplyAdjustment")
    {
        Caption = 'Reference.ItemPrice.ApplyAdjustment', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Price Apply Impl";
    }
    // External HTTP call with an optional secret, and a type that receives a secret. See src/ExchangeRates.
    value(90008; "Reference.ExchangeRate.Get")
    {
        Caption = 'Reference.ExchangeRate.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Exch Rate Get Impl";
    }
    value(90009; "Reference.ApiKey.Set")
    {
        Caption = 'Reference.ApiKey.Set', Locked = true;
        Implementation = "Msg Interface ori" = "Ref Api Key Set Impl";
    }
}
