namespace Origo.Bifrost.Reference.Tests;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Lints every selection card (name + description) of the message types these apps add. An agent
/// chooses a type from its card alone, so the card rules in START-HERE.md section 4 are checked like code:
///  - the description is not empty (it can never exceed 250 characters - the interface is Text[250]);
///  - it states its effect: an Outbound type says "Read-only", an Inbound type says "Commits",
///    so the words and the direction can never disagree;
///  - it is written for the caller, not for the developer (no "Impl", "codeunit", "TODO").
/// Adjust FirstOrdinal/LastOrdinal to your own enum value range.
/// </summary>
codeunit 90151 "Selection Card Lint"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure EveryCardStatesItsEffectAndMatchesItsDirection()
    var
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
        Ordinal: Integer;
        Description: Text;
        Name: Text;
        Checked: Integer;
    begin
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsOurs(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MsgInterface := MessageType;
                Name := MessageType.Names().Get(MessageType.Ordinals().IndexOf(Ordinal));
                Description := MsgInterface.GetDescription();

                Assert.AreNotEqual('', Description, Name + ': the description is empty.');
                case MsgInterface.GetMessageDirection() of
                    Enum::"Msg Direction ori"::Outbound:
                        Assert.IsTrue(Description.Contains('Read-only'), Name + ' is Outbound, so its description must say "Read-only": ' + Description);
                    Enum::"Msg Direction ori"::Inbound:
                        Assert.IsTrue(Description.Contains('Commits'), Name + ' is Inbound, so its description must say "Commits": ' + Description);
                end;
                Assert.IsFalse(Description.Contains('Impl'), Name + ': the description talks about the implementation.');
                Assert.IsFalse(Description.ToLower().Contains('codeunit'), Name + ': the description talks about the implementation.');
                Assert.IsFalse(Description.Contains('TODO'), Name + ': the description is unfinished.');
                Checked += 1;
            end;

        // Guard against the lint silently checking nothing after an id change.
        Assert.IsTrue(Checked >= 16, StrSubstNo('Only %1 message types were checked; expected the 16 of the reference apps.', Checked));
    end;

    local procedure IsOurs(Ordinal: Integer): Boolean
    begin
        // Bifrost Reference 90000-90049, Legacy App (v2 message types) 90100-90149.
        exit(((Ordinal >= 90000) and (Ordinal <= 90049)) or ((Ordinal >= 90100) and (Ordinal <= 90149)));
    end;
}
