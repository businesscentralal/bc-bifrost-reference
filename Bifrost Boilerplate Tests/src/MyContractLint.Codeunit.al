namespace MyCompany.MyBifrostApp.Tests;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Lints the use card (contract) of every message type this app adds. The contract is what an agent
/// reads before calling (Help.Implementation.Get returns its chapters), so a type without it is a
/// type an agent can only guess at. The contract is read through "Msg Contract Mgt ori".GetContract,
/// the same function Help.Implementation.Get uses.
/// Every type must declare the chapters below; parameters, target, related, workflow and notes are
/// declared where they apply. Keep IsOurs and ExpectedTypes in step with My Selection Card Lint.
/// </summary>
codeunit 50054 "My Contract Lint"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        MissingChapterMsg: Label 'The contract of %1 has no chapter "%2". Implement "Msg Contract ori" on its codeunit and return true from the procedure for that chapter.', Comment = '%1 = message type name, %2 = chapter key', Locked = true;
        TooFewCheckedMsg: Label 'Only %1 message types were checked; expected %2.', Comment = '%1 = number checked, %2 = number expected', Locked = true;

    [Test]
    procedure EveryTypeHasItsContractChapters()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Chapters: List of [Text];
        Chapter: Text;
        Name: Text;
        Ordinal: Integer;
        Checked: Integer;
    begin
        Chapters := GetRequiredChapters();
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsOurs(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                Name := MessageType.Names().Get(MessageType.Ordinals().IndexOf(Ordinal));
                Clear(Contract);
                ContractMgt.GetContract(MessageType, Contract);
                foreach Chapter in Chapters do
                    Assert.IsTrue(Contract.Contains(Chapter), StrSubstNo(MissingChapterMsg, Name, Chapter));
                Checked += 1;
            end;

        // Guard against the lint silently checking nothing after an id change.
        Assert.IsTrue(Checked >= ExpectedTypes(), StrSubstNo(TooFewCheckedMsg, Checked, ExpectedTypes()));
    end;

    local procedure GetRequiredChapters() Chapters: List of [Text]
    begin
        Chapters.Add('overview');
        Chapters.Add('envelope');
        Chapters.Add('response');
        Chapters.Add('errors');
        Chapters.Add('effect');
        Chapters.Add('examples');
    end;

    local procedure IsOurs(Ordinal: Integer): Boolean
    begin
        // TODO: the app's own id range, the same as idRanges in the app's app.json.
        exit((Ordinal >= 50000) and (Ordinal <= 50049));
    end;

    local procedure ExpectedTypes(): Integer
    begin
        // TODO: raise this each time you add a message type.
        exit(4);
    end;
}
