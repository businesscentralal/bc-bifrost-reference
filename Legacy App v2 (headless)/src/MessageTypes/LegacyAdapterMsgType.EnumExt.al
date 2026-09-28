namespace Origo.Bifrost.Reference.Legacy;

using Origo.Bifrost;

/// <summary>
/// Registers Legacy App's message types. The enum extension is the same whether the app is new
/// or retrofitted; what differs in a retrofit is the implementation side (calling the app's own
/// internal headless core), not this.
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
    value(90102; "Legacy.Stock.Get")
    {
        Caption = 'Legacy.Stock.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Legacy Stock Get Impl";
    }
    value(90103; "Legacy.Stock.List")
    {
        Caption = 'Legacy.Stock.List', Locked = true;
        Implementation = "Msg Interface ori" = "Legacy Stock List Impl";
    }
    value(90104; "Legacy.Stock.ReleaseAll")
    {
        Caption = 'Legacy.Stock.ReleaseAll', Locked = true;
        Implementation = "Msg Interface ori" = "Legacy Release All Impl";
    }
    value(90105; "Help.Legacy.Get")
    {
        Caption = 'Help.Legacy.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Legacy Help Get Impl";
    }
}
