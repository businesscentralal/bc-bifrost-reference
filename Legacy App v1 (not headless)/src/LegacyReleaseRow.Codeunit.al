namespace Origo.Bifrost.Reference.Legacy;

/// <summary>
/// v1 - releases one reservation and logs it. Called by Legacy Stock Mgt.ReleaseAll through
/// "if Codeunit.Run", which throws away any error raised here. Removed in 2.0: the facade
/// releases all matching rows in one transaction.
/// </summary>
codeunit 90051 "Legacy Release Row"
{
    TableNo = "Legacy Stock Reservation";

    trigger OnRun()
    var
        Reservation: Record "Legacy Stock Reservation";
        Log: Record "Legacy Cancellation Log";
    begin
        Reservation.Get(Rec."Item No.");
        Reservation.Delete(true);

        Log.Init();
        Log."Item No." := Rec."Item No.";
        Log."Cancelled At" := CurrentDateTime();
        Log.Insert(true);
    end;
}
