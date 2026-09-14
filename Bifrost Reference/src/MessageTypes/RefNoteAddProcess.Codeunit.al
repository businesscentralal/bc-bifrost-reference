namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Isolated write codeunit for Reference.Note.Add. TableNo = "Message Argument ori" is
/// required so Codeunit.Run() can catch any Error() raised here and report it through
/// Argument.RespondWithLastError() in the calling impl codeunit.
/// </summary>
codeunit 90004 "Ref Note Add Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        RefNote: Record "Ref Note";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        NoToken: JsonToken;
        TextToken: JsonToken;
        MissingNoErr: Label 'Missing required field ''no''.';
        MissingTextErr: Label 'Missing required field ''text''.';
        DuplicateNoErr: Label 'A note with no. ''%1'' already exists.', Comment = '%1 = note no.';
    begin
        RequestJson := Rec.GetRequestJson();

        if not RequestJson.Get('no', NoToken) then
            Error(MissingNoErr);
        if not RequestJson.Get('text', TextToken) then
            Error(MissingTextErr);

        RefNote."No." := CopyStr(NoToken.AsValue().AsText(), 1, MaxStrLen(RefNote."No."));
        if RefNote.Get(RefNote."No.") then
            Error(DuplicateNoErr, RefNote."No.");

        RefNote."Text" := CopyStr(TextToken.AsValue().AsText(), 1, MaxStrLen(RefNote."Text"));
        RefNote.Insert(true);

        ResponseJson.Add('no', RefNote."No.");
        Rec.SetResponseJson(ResponseJson);
    end;
}
