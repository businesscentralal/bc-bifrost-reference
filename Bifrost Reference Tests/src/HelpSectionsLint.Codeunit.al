namespace Origo.Bifrost.Reference.Tests;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Lints the use card of every message type these apps add. The use card is the contract an agent
/// reads before calling (Help.Implementation.Get returns its chapters), so a type without it is a
/// type an agent can only guess at. The contract is read through "Msg Contract Mgt ori".GetContract,
/// the same function Help.Implementation.Get uses.
/// Every type must declare the chapters below; parameters, target, related, workflow and notes are
/// declared where they apply. Adjust IsOurs to your own enum value range.
/// </summary>
codeunit 90155 "Help Sections Lint"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        MissingChapterMsg: Label 'The contract of %1 has no chapter "%2". Implement "Msg Contract ori" on its codeunit (see Ref Note Add Impl) and return true from Get%2.', Comment = '%1 = message type name, %2 = chapter key', Locked = true;
        TooFewCheckedMsg: Label 'Only %1 message types were checked; expected the 16 of the reference apps.', Comment = '%1 = number of message types checked', Locked = true;

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
        Assert.IsTrue(Checked >= 16, StrSubstNo(TooFewCheckedMsg, Checked));
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
        // Bifrost Reference 90000-90049, Legacy App (v2 message types) 90100-90149.
        exit(((Ordinal >= 90000) and (Ordinal <= 90049)) or ((Ordinal >= 90100) and (Ordinal <= 90149)));
    end;
}
