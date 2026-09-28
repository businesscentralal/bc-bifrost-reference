namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Isolated write codeunit for Reference.Note.Add. TableNo = "Message Argument ori" is
/// required so Codeunit.Run() can catch any Error() raised here and report it in the calling impl.
/// Input is read through Ref Input, so an empty or wrongly typed value is answered clearly
/// instead of inserting a note with a blank key.
/// </summary>
codeunit 90004 "Ref Note Add Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        RefNote: Record "Ref Note";
        RefInput: Codeunit "Ref Input";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        NoText: Text;
        NoteText: Text;
        HasText: Boolean;
        DuplicateNoErr: Label 'A note with no. ''%1'' already exists. Choose a different no.; if this is a retry, the first attempt most likely succeeded.', Comment = '%1 = note no., is-IS=Athugasemd með nr. ''%1'' er þegar til. Veldu annað nr.; ef þetta er endurtekning tókst fyrsta tilraunin líklega.';
    begin
        if not RefInput.ReadRequest(Rec, RequestJson) then
            exit;
        if not RefInput.GetRequiredText(Rec, RequestJson, 'no', MaxStrLen(RefNote."No."), '"NOTE-1"', NoText) then
            exit;
        if not RefInput.GetOptionalText(Rec, RequestJson, 'text', MaxStrLen(RefNote."Text"), NoteText, HasText) then
            exit;

        if RefNote.Get(CopyStr(UpperCase(NoText), 1, MaxStrLen(RefNote."No."))) then
            Error(DuplicateNoErr, RefNote."No.");

        RefNote.Init();
        RefNote."No." := CopyStr(UpperCase(NoText), 1, MaxStrLen(RefNote."No."));
        RefNote."Text" := CopyStr(NoteText, 1, MaxStrLen(RefNote."Text"));
        RefNote.Insert(true);

        ResponseJson.Add('no', RefNote."No.");
        Rec.SetResponseJson(ResponseJson);
    end;
}
