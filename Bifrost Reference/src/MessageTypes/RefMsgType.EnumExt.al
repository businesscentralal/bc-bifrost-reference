namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Extends Bifröst Foundation's message type enum with this reference implementation's
/// example message type. This is the required step to make a new message type callable —
/// the enum value is what a caller sends as the request's `type` field.
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
}
