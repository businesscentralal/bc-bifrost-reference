namespace Origo.Bifrost.Reference.LegacyAdapter;

using Origo.Bifrost;

/// <summary>
/// Registers this adapter's two message types. Same mechanism as the greenfield
/// example - the enum extension is identical either way. What differs in a retrofit
/// is entirely on the implementation side (calling into an existing app), not here.
/// </summary>
enumextension 90100 "Legacy Adapter Msg Type" extends "Message Type ori"
{
    value(90100; "Legacy.Stock.Reserve")
    {
        Caption = 'Legacy.Stock.Reserve', Locked = true;
        Implementation = "Msg Interface ori" = "Legacy Stock Reserve Impl";
    }
    value(90101; "Legacy.Stock.CancelReservation")
    {
        Caption = 'Legacy.Stock.CancelReservation', Locked = true;
        Implementation = "Msg Interface ori" = "Legacy Cancel Reserve Impl";
    }
}
