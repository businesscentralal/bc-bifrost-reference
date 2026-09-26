namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// Reference implementation of a WRITE message type. Demonstrates the mandatory isolation
/// pattern: the actual write happens in a separate codeunit (TableNo = "Message Argument
/// ori") invoked via Codeunit.Run(), so a failure is caught here and answered as
/// status = Error without rolling back the outer transaction. Help text lives in a
/// separate codeunit (RefNoteAddHelp) - the pattern to default to once help text grows past
/// a few lines; see the use card in CONTRACT.md.
/// </summary>
codeunit 90003 "Ref Note Add Impl" implements "Msg Interface ori"
{
    Access = Internal;

    /// <summary>
    /// A real gate, not a formality: returning false here means this message type is not
    /// listed and cannot be chosen at all. Check the permission or setup the type needs,
    /// rather than unconditionally returning true.
    /// </summary>
    procedure IsEnabled(): Boolean
    var
        RefNote: Record "Ref Note";
    begin
        exit(RefNote.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Ref Note");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Creates one Reference Note record with the number and text given. Commits. Fails with a structured error if a note with that number already exists.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        RefNoteAddHelp: Codeunit "Ref Note Add Help";
    begin
        Argument.SetResponseMarkdown(RefNoteAddHelp.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RefInput: Codeunit "Ref Input";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        // Write operations must run in an isolated sub-codeunit so a failure can be caught
        // here without rolling back the outer transaction (START-HERE.md section 3).
        // Ref Input.RunIsolated honours "Omit Commit" and answers failures as status = Error
        // with the error text only (no call stack in the response).
        RefInput.RunIsolated(Codeunit::"Ref Note Add Process", Argument);
    end;
}
