namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Extends Bifröst Foundation's message type enum with this reference implementation's
/// example message type. This is the required step to make a new message type callable —
/// the enum value is what a caller sends as the request's `type` field.
/// </summary>
enumextension 90000 "Ref Msg Type" extends "Message Type ori"
{
    value(90000; "Reference.Echo.Set")
    {
        Caption = 'Reference.Echo.Set', Locked = true;
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
}
