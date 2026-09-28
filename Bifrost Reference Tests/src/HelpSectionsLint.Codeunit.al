namespace Origo.Bifrost.Reference.Tests;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Lints every use card (the help document) of the message types these apps add. The help is the
/// only schema a caller gets, so START-HERE.md section 4 asks for all eleven sections in every help
/// document, even when the answer is "none": a missing section tells the caller nothing. The help is
/// read through Help.Implementation.Get, exactly as callers receive it.
/// Adjust IsOurs to your own enum value range.
/// </summary>
codeunit 90155 "Help Sections Lint"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        MissingSectionMsg: Label 'The help of %1 has no section "## %2". Every help document needs all eleven sections of START-HERE.md section 4.', Comment = '%1 = message type name, %2 = section heading', Locked = true;
        TooFewCheckedMsg: Label 'Only %1 message types were checked; expected the 16 of the reference apps.', Comment = '%1 = number of message types checked', Locked = true;

    [Test]
    procedure EveryHelpHasAllElevenSections()
    var
        Caller: Codeunit "Ref Test Caller";
        MessageType: Enum "Message Type ori";
        Headings: List of [Text];
        Heading: Text;
        HelpText: Text;
        Name: Text;
        Ordinal: Integer;
        Checked: Integer;
    begin
        Headings := GetSectionHeadings();
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsOurs(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                Name := MessageType.Names().Get(MessageType.Ordinals().IndexOf(Ordinal));
                HelpText := Caller.GetHelp(Name);
                foreach Heading in Headings do
                    Assert.IsTrue(HelpText.Contains('## ' + Heading), StrSubstNo(MissingSectionMsg, Name, Heading));
                Checked += 1;
            end;

        // Guard against the lint silently checking nothing after an id change.
        Assert.IsTrue(Checked >= 16, StrSubstNo(TooFewCheckedMsg, Checked));
    end;

    local procedure GetSectionHeadings() Headings: List of [Text]
    begin
        // The eleven sections of START-HERE.md section 4, in their order. Section 3 names its target
        // ("Identifying the item", "Identifying the account", "Identifying the target"), so only its
        // common start is checked.
        Headings.Add('Overview');
        Headings.Add('Workflow');
        Headings.Add('Identifying the');
        Headings.Add('Parameters');
        Headings.Add('Request example');
        Headings.Add('Response');
        Headings.Add('Errors');
        Headings.Add('Safe retries / repeat');
        Headings.Add('Permissions and side effects');
        Headings.Add('Formats and language');
        Headings.Add('Related message types');
    end;

    local procedure IsOurs(Ordinal: Integer): Boolean
    begin
        // Bifrost Reference 90000-90049, Legacy App (v2 message types) 90100-90149.
        exit(((Ordinal >= 90000) and (Ordinal <= 90049)) or ((Ordinal >= 90100) and (Ordinal <= 90149)));
    end;
}
