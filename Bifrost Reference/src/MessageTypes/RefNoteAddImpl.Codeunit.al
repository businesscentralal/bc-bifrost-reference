namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference implementation of a WRITE message type. Demonstrates the mandatory isolation
/// pattern: the actual write happens in a separate codeunit (TableNo = "Message Argument
/// ori") invoked via Codeunit.Run(), so a failure is caught here and reported through
/// RespondWithLastError() without rolling back the outer transaction. Help text lives in a
/// separate codeunit (RefNoteAddHelp) - the pattern to default to once help text grows past
/// a few lines; see WRITING-HELP.md.
/// </summary>
codeunit 90003 "Ref Note Add Impl" implements "Msg Interface ori"
{
    Access = Internal;

    /// <summary>
    /// A real gate, not a formality: returning false here means this message type is not
    /// listed and cannot be chosen at all - matching how Core's own IsEnabled implementations
    /// check WritePermission() or a setup flag, rather than unconditionally returning true.
    /// </summary>
    internal procedure IsEnabled(): Boolean
    var
        RefNote: Record "Ref Note";
    begin
        exit(RefNote.WritePermission());
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Ref Note");
    end;

    internal procedure GetDescription(): Text[250]
    begin
        exit('Creates one Reference Note record with the number and text given. Fails with a structured error if a note with that number already exists.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        RefNoteAddHelp: Codeunit "Ref Note Add Help";
    begin
        Argument.SetResponseMarkdown(RefNoteAddHelp.GetHelpText());
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        // Write operations must run in an isolated sub-codeunit so a failure can be caught
        // here without rolling back the outer transaction (see AGENTS.md rule).
        if not Codeunit.Run(Codeunit::"Ref Note Add Process", Argument) then
            Argument.RespondWithLastError();
    end;
}
