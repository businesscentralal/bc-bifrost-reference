namespace Nar.Ref1149.Helper;

using Origo.Bifrost.Reference;
using Origo.Bifrost.Reference.Legacy;

codeunit 50990 "Nar Ref1149 Cleanup"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;
    Permissions = tabledata "Legacy Stock Reservation" = RD, tabledata "Legacy Cancellation Log" = RD, tabledata "Ref Asset Maintenance" = RD, tabledata "Ref Note" = RD;

    [Test]
    procedure CleanBiftFixtures()
    var
        Reservation: Record "Legacy Stock Reservation";
        Log: Record "Legacy Cancellation Log";
        Maint: Record "Ref Asset Maintenance";
        Note: Record "Ref Note";
    begin
        Reservation.SetFilter("Item No.", 'BIFT*');
        Reservation.DeleteAll();
        Log.SetFilter("Item No.", 'BIFT*');
        Log.DeleteAll();
        Maint.SetFilter("External Id", 'BIFT*');
        Maint.DeleteAll();
        Maint.Reset();
        Maint.SetFilter("FA No.", 'BIFT*');
        Maint.DeleteAll();
        Note.SetFilter("No.", 'BIFT*');
        Note.DeleteAll();
        Commit();
        if not (Reservation.IsEmpty() and Log.IsEmpty() and Maint.IsEmpty() and Note.IsEmpty()) then
            Error('BIFT fixtures remain');
    end;
}
