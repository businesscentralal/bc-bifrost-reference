# Building on Bifröst: the complete guide for you and your coding agent

**This one file is all you need.** Give it to your coding agent (Claude Code, GitHub Copilot, Cursor …) and say which of the three paths in §2 you are on. The worked examples in this repository show the same patterns in full, but the agent can build from this file alone.

---

## 1. What Bifröst is and how an agent uses it

**Bifröst Foundation** (app id `7505e808-6e52-4b96-a328-82573391297a`, publisher Origo, BC 28, runtime 17, namespace `Origo.Bifrost`) turns Business Central operations into **message types**. Integrations and AI agents call them over one API (`/api/origo/bifrost/v1.0/`) or through an MCP server. A message type consists of:

- one value in the enum `Message Type ori`
- a codeunit implementing the interface `Msg Interface ori`
- a help text

An agent that uses your message type goes through four steps:

1. It **searches** about 270 types by words, matched against the name and the one-line description.
2. It **chooses** from the shortlist, using the name and description.
3. It **reads** the help of the chosen type.
4. It **calls** it, with no UI and no human in the loop. If the call fails, the error text is its only guidance.

Everything below exists to make those four steps work first time.

**Agent: read the real Foundation symbols (`.alpackages`) before writing code. Never guess a procedure name or signature.** Every Foundation API used in this file exists in Foundation 28.0 or later.

---

## 2. Pick your path

| Path | You have … | Do |
|---|---|---|
| **A. New app** | nothing yet | §3 → §4 → §5 → §6 → §8 |
| **B. Make an app headless** | an app whose logic is tangled with pages, `Confirm` or `Commit`, and you want other apps (and later Bifröst) to call it | §7.1. It needs no Bifröst dependency. |
| **C. Adapt an existing app** | an app whose operations you want as Bifröst message types | the audit in §7.2, B if it finds anything, then §7.3, using §3–§6 for each type |

### Typical partner situations and which path fits

| Situation | What is usually not headless | Path | Where the message types live |
|---|---|---|---|
| **Your own app, built for the UI**: logic in page actions, dialogs, `Commit`s | Page triggers holding the rules; `Confirm`/`StrMenu`; request pages | **B**, then **C** | A separate adapter app if some customers don't have Bifröst. In the app itself if every customer has it. |
| **Your own app that already has codeunit APIs or web services** | Usually little. Watch for `Commit`, `GuiAllowed` branches and silent `exit(false)`. | **C** (B only for the gaps) | An adapter app, or the app itself |
| **Someone else's app** (an AppSource ISV app) | Unknown; you can't change it | **C**, using only its public procedures and events | Always a separate adapter app |
| **Customisations on the base app** (your PTE extends sales, purchasing, inventory …) | The base app's own dialogs: posting, releasing, reports | **A**, wrapping base-app codeunits headless (`SetHideValidationDialog`, `…HideDialog`, preview posting, reports via `SaveAs`) | Your PTE, or a companion app. Check first that Foundation doesn't already have the operation. |
| **An integration app** (web shop, WMS, bank or e-invoice connector) | Setup wizards, credentials in tables, jobs started from pages | **A/C**, with secrets in `Secret Store ori` and one Setup action | The connector app |
| **Batch jobs and job queue processes** | Request pages and progress dialogs; long runtimes | **B** (parameters instead of request pages), then a queued type plus a status type | The app or an adapter |
| **Approvals and decisions** ("are you sure?", manager sign-off) | The decision is a dialog | **B**: the decision becomes a parameter, or goes through Foundation's `Document.Approval.*` | The app or an adapter |
| **An app built on the older Origo Cloud Events platform** | Usually fine, but on the retired platform | Change the dependency to Foundation: the app id changes (`a629b897-…` → `7505e808-6e52-4b96-a328-82573391297a`), not just the name. Rename the Cloud Events objects to their Bifröst names (`ExecuteCloudEventTask` → `ExecuteBifrostTask`, `CE Message Argument ori` → `Message Argument ori`, …). | The app itself |

**Rule of thumb:** make the business logic headless in the app that owns it. Put the Bifröst contract (message types, input checking, help) in the app that depends on Bifröst. Never copy business rules into the adapter.

---

## 3. The rules (each one comes from a real failure in live agent testing)

### Headless

1. **No UI in the execution path.** No `Confirm`, `Message`, `StrMenu`, `Page.Run`/`RunModal`, or report request pages. Use the base app's `SetHideValidationDialog(true)` or `…HideDialog` variants. A decision a user would make becomes a request parameter with a documented default.
2. **No `Commit`.** Foundation owns the transaction.
3. **Writes run isolated** in a codeunit with `TableNo = "Message Argument ori"` (§5.3).
4. **Write nothing before the isolated run.** Inside an open write transaction, `Codeunit.Run` can't return a value. Validate first (reads only), run the write, then do everything else.

### Input and errors

5. **Every failure is `status = Error`,** with a message that says **what to do next**. No raw platform error ever reaches the caller.
6. **Four different answers:**
   - *missing*: "No customer was given …"
   - *not found*: "Customer 'X' was not found …", echoing the value
   - *wrong type*: "must be a single value …"
   - *wrong format*: "not a date in the format YYYY-MM-DD …"
7. **Formats:**
   - Dates are ISO `YYYY-MM-DD` only. `26.09.2026` is refused with the expected format, never guessed.
   - Numbers use a dot as decimal separator.
   - In responses: numbers as JSON numbers, "no value" as `null` (never `0`), enums by name (never `Format()`).
8. **Error texts are translatable Labels** (`Comment = 'is-IS=…'`), never literals.
9. **All input goes through one shared input layer** (§5.1).

### Honesty and safety

10. **No silent success.** Report what happened (`"created": false`, `"cancelled": false`).
11. **`IsEnabled()` checks the exact permissions** the type needs. Users without them don't see the type.
12. **Direction:** `Outbound` for reads, `Inbound` for anything that writes.
13. **The verb is a promise.** `Get` and `List` write nothing. `Add`, `Create`, `Reserve`, `Cancel`, `Set` and `Apply` write. A `Get` that writes, or a `Set` that doesn't, is a naming bug.
14. **A read never inserts setup.** When the setup record doesn't exist yet, use defaults in memory (`GetOrDefault` in `Bifrost Reference/src/ExchangeRates/RefSetup.Table.al`).
15. **Irreversible bulk changes come as a pair:** a read-only Preview plus an Apply that requires a value from the preview (§5.6).
16. **Secrets:** hold them as `SecretText` and store them only via `Secret Store ori`. A type that *receives* a secret calls `Argument.RedactRequestData()` on every path, **after** its isolated write.

### Platform

17. **Name types `Area.Entity.Verb`** in words a user would say. The name is the strongest search signal.
18. **Register the app with `App Registry ori`,** even when it has no setup page and no secrets (pass 0 as the page). Foundation's setup wizard can only switch on outbound HTTP for apps it knows.
19. **At most one action on Foundation's `Setup ori` page.** Your settings live on your own page.
20. **Never show your own HTTP, credentials or setup notification.** Foundation aggregates them on Bifrost Setup for every registered app.
21. **One `Help.<App>.Get` directory type per app.**

---

## 4. Write the contract first, one per message type

An agent needs different things at two moments, so each type has two "cards":

| Moment | The agent sees | Card | Where it lives |
|---|---|---|---|
| Choosing among about 270 types | name + one-line description | **Selection card** | `GetDescription()` (≤ 250 characters) |
| Making the first call | the help document | **Use card** | `GetMessageHelpAsMarkdownDocument()` |

Don't put everything in the description. Longer descriptions made agents hesitate, and facts that belong in the help drift out of date.

### Contract template

Fill this in before you write the code, and review it with the user.

```
Name:            Area.Entity.Verb
Effect:          Read-only | Commits | Rolled back | Irreversible
User words:      how users say it, incl. synonyms (undo, fix, receive, totals …)
Siblings:        similar types and how to tell them apart
Ask the user when: situations where the agent should ask instead of guessing
Target:          subject GUID → subject No. → body key; answers for "not given" and "not found"
Parameters:      key | type | required | default | format / range
Preconditions:   status, setup, permissions
Response:        fields + JSON types; what "nothing happened" looks like
Errors:          exact Label text | cause | fix
Repeat safety:   what a second identical call does
```

### Selection card formula

```
[Verb] [business object] [variants / what you get]. [Effect]. [Identified by …, only if it separates siblings]. [Not for X – use Sibling.]
```

Example:

> Log a service visit at a customer: date, hours and a short description. Commits; safe to retry with the same externalId. Not for time sheets or project journal lines.

Never include:

- codeunit or report numbers
- internal jargon
- the dotted name repeated

### Use card: the help sections, in this order

1. **Overview**, including an **Effect:** line and when *not* to use the type.
2. **Workflow**: which types come before and after.
3. **Identifying the target**: keys in order, and the answers for "not given" and "not found".
4. **Parameters**: a table with key, type, required, rules.
5. **Request example**: minimal and runnable.
6. **Response**: an example plus a field table with JSON types.
7. **Errors**: exact text copied from the Labels, cause, fix.
8. **Safe retries / repeat.**
9. **Permissions and side effects.**
10. **Formats and language.**
11. **Related message types**: only ones that exist.

Descriptions and help written this way were picked and called correctly by both large and small models in blind tests on a catalogue of about 270 types.

---

## 5. Code patterns (copy these)

### 5.0 app.json

```json
"dependencies": [
  {
    "id": "7505e808-6e52-4b96-a328-82573391297a",
    "name": "Bifrost Foundation",
    "publisher": "Origo",
    "version": "28.0.0.0"
  }
],
"platform": "28.0.0.0",
"application": "28.0.0.0",
"runtime": "17.0",
"features": [ "TranslationFile" ]
```

- **Pin the minimum you compile against.** AL treats the version as "this or newer", so don't pin the build you happen to have installed.
- Use your own id range: `50000–99999` for a per-tenant extension, or a range from Microsoft through Partner Center for AppSource. Never reuse the ranges of this repo, of Foundation or of any other published app.
- Use your own namespace, e.g. `Contoso.FieldService`. Put `using Origo.Bifrost;` in every file that touches Foundation.
- **Choose `resourceExposurePolicy` deliberately.** The samples in this repo allow debugging and source download because they are samples. Don't copy that setting without deciding.
- Download symbols from a sandbox where Foundation is installed.

### 5.1 The shared input layer

Create one codeunit, e.g. `"<App> Input"`, and read **every** parameter through it. Each `Get…` answers the caller itself and returns false, so callers write `if not … then exit;`.

```al
codeunit 50100 "Contoso Input"
{
    Access = Internal;

    var
        NotObjectErr: Label 'The request body must be a JSON object, for example { "customerNo": "10000" }.', Comment = 'is-IS=Beiðnin verður að vera JSON-hlutur, til dæmis { "customerNo": "10000" }.';
        MissingErr: Label 'Parameter ''%1'' is required. Send it as %2.', Comment = '%1 = parameter, %2 = type and example, is-IS=Færibreytan ''%1'' er nauðsynleg. Sendu hana sem %2.';
        EmptyErr: Label 'Parameter ''%1'' is empty. Send a value, for example %2.', Comment = '%1 = parameter, %2 = example, is-IS=Færibreytan ''%1'' er tóm. Sendu gildi, til dæmis %2.';
        NotAValueErr: Label 'Parameter ''%1'' must be a single value (text or number), not an object or an array.', Comment = '%1 = parameter, is-IS=Færibreytan ''%1'' verður að vera stakt gildi, ekki hlutur eða fylki.';
        TooLongErr: Label 'Parameter ''%1'' is %2 characters long; the maximum is %3.', Comment = '%1 = parameter, %2 = length, %3 = max, is-IS=Færibreytan ''%1'' er %2 stafir; hámarkið er %3.';
        DateFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.', Comment = '%1 = parameter, %2 = value, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki dagsetning á sniðinu ÁÁÁÁ-MM-DD. Sendu t.d. 2026-09-26.';
        NumberFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a number. Send a number with a dot as decimal separator, for example 2.5.', Comment = '%1 = parameter, %2 = value, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki tala. Sendu t.d. 2.5.';
        RangeErr: Label 'Parameter ''%1'' is %2, but it must be between %3 and %4.', Comment = '%1 = parameter, %2 = value, %3 = min, %4 = max, is-IS=Færibreytan ''%1'' er %2 en verður að vera á bilinu %3 til %4.';
        CustomerMissingErr: Label 'No customer was given. Send the customer number in subject or as "customerNo", or its SystemId in subject.', Comment = 'is-IS=Enginn viðskiptamaður var tilgreindur. Sendu númer hans í subject eða sem "customerNo".';
        CustomerNotFoundErr: Label 'Customer ''%1'' was not found. Check the number, or search for the customer with Data.Records.Get on table Customer.', Comment = '%1 = value, is-IS=Viðskiptamaðurinn ''%1'' fannst ekki. Athugaðu númerið.';

    procedure ReadRequest(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject): Boolean
    begin
        if TryGetRequestJson(Argument, RequestJson) then
            exit(true);
        Argument.RespondWithError(NotObjectErr);
        exit(false);
    end;

    procedure GetRequiredText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer; ExampleValue: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, 'text, for example ' + ExampleValue));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, MaxLength, Value) then
            exit(false);
        if DelChr(Value, '<>', ' ') = '' then begin
            Argument.RespondWithError(StrSubstNo(EmptyErr, KeyName, ExampleValue));
            exit(false);
        end;
        exit(true);
    end;

    procedure GetRequiredDate(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Date): Boolean
    var
        Token: JsonToken;
        DateText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, 'a date in the format YYYY-MM-DD'));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, 30, DateText) then
            exit(false);
        // Strict ISO: exactly YYYY-MM-DD. Evaluate(..., 9) alone must not be trusted to reject local formats.
        if (StrLen(DateText) <> 10) or (CopyStr(DateText, 5, 1) <> '-') or (CopyStr(DateText, 8, 1) <> '-') or
           not Evaluate(Value, DateText, 9)
        then begin
            Argument.RespondWithError(StrSubstNo(DateFormatErr, KeyName, DateText));
            exit(false);
        end;
        exit(true);
    end;

    procedure GetRequiredDecimal(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MinValue: Decimal; MaxValue: Decimal; var Value: Decimal): Boolean
    var
        Token: JsonToken;
        NumberText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, 'a number, for example 2.5'));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, 50, NumberText) then
            exit(false);
        if not Evaluate(Value, NumberText, 9) then begin
            Argument.RespondWithError(StrSubstNo(NumberFormatErr, KeyName, NumberText));
            exit(false);
        end;
        if (Value < MinValue) or (Value > MaxValue) then begin
            Argument.RespondWithError(StrSubstNo(RangeErr, KeyName, Format(Value, 0, 9), Format(MinValue, 0, 9), Format(MaxValue, 0, 9)));
            exit(false);
        end;
        exit(true);
    end;

    // One resolver per record type: subject GUID -> subject No. -> body key.
    // "Not given" and "not found" get different messages. Set SetLoadFields on Customer before calling.
    procedure ResolveCustomer(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Customer: Record Customer): Boolean
    var
        Token: JsonToken;
        NoText: Text;
    begin
        if Argument.SubjectIsGuid() then begin
            if Customer.GetBySystemId(Argument.Subject) then
                exit(true);
            Argument.RespondWithError(StrSubstNo(CustomerNotFoundErr, Argument.Subject));
            exit(false);
        end;
        NoText := DelChr(Argument.Subject, '<>', ' ');
        if NoText = '' then
            if RequestJson.Get('customerNo', Token) then
                if not ReadTextToken(Argument, Token, 'customerNo', MaxStrLen(Customer."No."), NoText) then
                    exit(false);
        if NoText = '' then begin
            Argument.RespondWithError(CustomerMissingErr);
            exit(false);
        end;
        if (StrLen(NoText) <= MaxStrLen(Customer."No.")) then
            if Customer.Get(UpperCase(NoText)) then
                exit(true);
        Argument.RespondWithError(StrSubstNo(CustomerNotFoundErr, NoText));
        exit(false);
    end;

    local procedure ReadTextToken(var Argument: Record "Message Argument ori"; Token: JsonToken; KeyName: Text; MaxLength: Integer; var Value: Text): Boolean
    begin
        if not Token.IsValue() then begin
            Argument.RespondWithError(StrSubstNo(NotAValueErr, KeyName));
            exit(false);
        end;
        Value := '';
        if not Token.AsValue().IsNull() then
            Value := Token.AsValue().AsText();
        if StrLen(Value) > MaxLength then begin
            Argument.RespondWithError(StrSubstNo(TooLongErr, KeyName, StrLen(Value), MaxLength));
            exit(false);
        end;
        exit(true);
    end;

    [TryFunction]
    local procedure TryGetRequestJson(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject)
    begin
        RequestJson := Argument.GetRequestJson();
    end;
}
```

The repo's full version (`Bifrost Reference/src/Common/RefInput.Codeunit.al`) adds three more things:

- optional text
- whole numbers
- a date parser that also rejects impossible dates such as `2026-02-30`

### 5.2 Registering the type (enum extension)

```al
enumextension 50100 "Contoso Msg Type" extends "Message Type ori"
{
    value(50100; "Contoso.ServiceVisit.Create")
    {
        Caption = 'Contoso.ServiceVisit.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Contoso Visit Create Impl";
    }
}
```

The caption is `Locked = true` because callers in every locale send the same string. Never translate it.

### 5.3 The implementation: a write with validation and an isolated process

```al
codeunit 50101 "Contoso Visit Create Impl" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Visit: Record "Contoso Service Visit";
        Customer: Record Customer;
    begin
        exit(Visit.WritePermission() and Customer.ReadPermission());   // exact permissions
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Contoso Service Visit");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Log a service visit at a customer: date, hours and a short description. Commits; safe to retry with the same externalId. Not for time sheets or project journal lines.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);                     // writes are Inbound
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Contoso Visit Create Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Customer: Record Customer;
        Input: Codeunit "Contoso Input";
        Process: Codeunit "Contoso Visit Create Process";
        RequestJson: JsonObject;
        VisitDate: Date;
        Hours: Decimal;
    begin
        Argument.AssertVersion1();        // first, before reading the payload
        Argument.AssertIsLicensed();

        // 1. Validate everything - reads only, no writes.
        if not Input.ReadRequest(Argument, RequestJson) then
            exit;
        Customer.SetLoadFields("No.", Blocked);
        if not Input.ResolveCustomer(Argument, RequestJson, Customer) then
            exit;
        if not Input.GetRequiredDate(Argument, RequestJson, 'visitDate', VisitDate) then
            exit;
        if not Input.GetRequiredDecimal(Argument, RequestJson, 'hours', 0.25, 24, Hours) then
            exit;

        // 2. Write in isolation. Honour "Omit Commit" (the caller owns the transaction).
        Process.SetVisit(Customer."No.", VisitDate, Hours);
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}

codeunit 50102 "Contoso Visit Create Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        CustomerNo: Code[20];
        VisitDate: Date;
        Hours: Decimal;

    trigger OnRun()
    var
        Visit: Record "Contoso Service Visit";
        Response: JsonObject;
    begin
        Visit.Init();
        Visit."Customer No." := CustomerNo;
        Visit."Visit Date" := VisitDate;
        Visit.Hours := Hours;
        Visit.Insert(true);

        Response.Add('entryNo', Visit."Entry No.");
        Response.Add('created', true);
        Response.Add('visitDate', Format(Visit."Visit Date", 0, 9));   // ISO in responses
        Response.Add('hours', Visit.Hours);                             // JSON number
        Rec.SetResponseJson(Response);
    end;

    procedure SetVisit(NewCustomerNo: Code[20]; NewVisitDate: Date; NewHours: Decimal)
    begin
        CustomerNo := NewCustomerNo;
        VisitDate := NewVisitDate;
        Hours := NewHours;
    end;
}
```

**Safe retries:** accept an optional `externalId`. In the Process, `LockTable()` and look it up first. If it already exists, return that record with `"created": false` and write nothing.

**A read** follows the same shape with direction `Outbound`, `IsEnabled` returning `ReadPermission()`, no Process codeunit, and `SetLoadFields` before resolving. For FlowFields "as of" a date, set `"Date Filter"` and use e.g. `"Net Change (LCY)"`: `"Balance (LCY)"` ignores the date filter.

### 5.4 The help codeunit (the use card)

```al
codeunit 50103 "Contoso Visit Create Help"
{
    Access = Internal;

    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Contoso.ServiceVisit.Create');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Logs one service visit at a customer. **Effect:** Commits. Not for time sheets.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the customer');
        Help.AppendLine('1. `subject` as GUID (SystemId)  2. `subject` as customer number  3. `customerNo` in the body.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `visitDate` | date YYYY-MM-DD | yes | `26.09.2026` is refused. |');
        Help.AppendLine('| `hours` | number | yes | 0.25 to 24. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Contoso.ServiceVisit.Create", "subject": "10000", "data": { "visitDate": "2026-09-25", "hours": 1.5 } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `Customer ''X'' was not found. ...` | Unknown customer. | Check the number. |');
        Help.AppendLine('| `Parameter ''visitDate'' has the value ''26.09.2026'', which is not a date in the format YYYY-MM-DD. ...` | Wrong format. | Send `2026-09-26`. |');
        // ... every Label the type can return, copied verbatim ...
        exit(Help.ToText());
    end;
}
```

**Where the help text lives.** Either inline in the Impl codeunit (fine for a small type, e.g. `RefEchoSetImpl.Codeunit.al`) or in its own Help codeunit, as above (the default once the help grows, e.g. `LegacyAdapterHelp.Codeunit.al`). Either way, one `AppendLine` per Markdown line, and `''` for a single quote.

### 5.5 Platform integration

```al
// Register once, so Foundation lists the app in its setup wizard, notifications and App Secrets.
codeunit 50110 "Contoso Registration"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), Page::"Contoso Setup"); // 0 if no setup page
    end;
}

// The ONE thing you add to Foundation's Bifrost Setup page.
pageextension 50111 "Contoso Setup Action" extends "Setup ori"
{
    actions
    {
        addlast(Apps)
        {
            action(ContosoSetup)
            {
                ApplicationArea = All;
                Caption = 'Contoso Field Service';
                ToolTip = 'Open the setup of Contoso Field Service.';
                Image = Setup;
                RunObject = page "Contoso Setup";
            }
        }
        addlast(Category_Apps)
        {
            actionref(ContosoSetup_Promoted; ContosoSetup) { }
        }
    }
}
```

**Secrets:** register in an install codeunit, then read with `TryGet` inside a `[NonDebuggable]` procedure:

- register: `SecretStore.Register(AppId, 'API-KEY', 'Description', Enum::"Secret Scope ori"::Company, AppName)`
- read: `SecretStore.TryGet(AppId, 'API-KEY', SecretValue)`
- in HTTP: `Headers.Add('X-Api-Key', SecretValue)`

A type that receives a secret reads it into `SecretText`, runs its isolated store, and then calls `Argument.RedactRequestData()` on every path.

**Outbound HTTP:** wrap `HttpClient.Send` in a `[TryFunction]`. On failure, tell the user to enable HTTP for your app in the Bifrost Setup Wizard (this works because the app is registered). Check the status code and the JSON shape, each with its own message.

**Also:**

- a **permission set** covering your tables and pages
- a **`Help.<App>.Get`** type returning a markdown list of your types with their effect. Keep that list in step with the enum. A test that compares the two is the cheapest guard: `DirectoryListsEveryLegacyType` in `Bifrost Reference Tests/src/LegacyAdapterTests.Codeunit.al` does it for `Help.Legacy.Get`.

### 5.6 Preview / apply pair (irreversible or bulk changes)

- **`…Preview…`** (Outbound, read-only) computes the change and returns it, including a count or a hash of the selection.
- **`…Apply…`** (Inbound) requires that value back (e.g. `expectedItemCount`). It refuses with "the selection changed since the preview … run the preview again" when it differs.
- **Both use one shared codeunit** for selection and calculation, so preview and apply can never disagree.
- **Each description points to the other.**

---

## 6. Where the patterns are in this repository

### Classify each operation, then copy the matching pattern

| The operation … | Effect | Copy |
|---|---|---|
| reads one record | Read-only | `Reference.Customer.Overview.Get`, `Legacy.Stock.Get` |
| reads many records | Read-only, capped with a documented maximum | `Legacy.Stock.List` (at most 100 rows, says when there are more) |
| writes one record, safe to retry | Commits | `Reference.ServiceVisit.Create` (`externalId`) |
| changes many records, or can't be undone | Commits, guarded | `Reference.ItemPrice.PreviewAdjustment` + `ApplyAdjustment` (preview + apply), or `Legacy.Stock.List` + `Legacy.Stock.ReleaseAll` (list + release with `expectedCount`) |
| calls an external service | Read-only (internet) | `Reference.ExchangeRate.Get` |
| receives a secret | Commits | `Reference.ApiKey.Set` |

**For each write, also offer a read sibling.** An agent that can't check the state before and after a write has to guess.

### The patterns by folder

| Pattern | Message type | Folder |
|---|---|---|
| Read with resolver, FlowFields, nulls | `Reference.Customer.Overview.Get` | `Bifrost Reference/src/Customers/` |
| Write, validation, isolation, safe retry | `Reference.ServiceVisit.Create` | `Bifrost Reference/src/ServiceVisits/` |
| Preview / apply pair | `Reference.ItemPrice.*` | `Bifrost Reference/src/Prices/` |
| HTTP, secret, setup page, install | `Reference.ExchangeRate.Get`, `Reference.ApiKey.Set` | `Bifrost Reference/src/ExchangeRates/`, `src/Lifecycle/` |
| Shared input layer (full) | – | `Bifrost Reference/src/Common/RefInput.Codeunit.al` |
| Headless facade (no Bifröst dependency) | – | `Legacy App v2 (headless)/src/LegacyStockAPI.Codeunit.al` |
| Adapter app over the facade | `Legacy.Stock.*`, `Help.Legacy.Get` | `Legacy App - Bifrost/src/` |
| Unit tests through `Dispatcher ori`, and the selection card lint | – | `Bifrost Reference Tests/` |

---

## 7. Existing apps

### 7.1 Make it headless (path B)

**The idea.** Every page action does two things:

1. **It talks to a person:** a dialog for input, "are you sure?", a message, the selected row.
2. **It does the work:** it checks the rules and writes the data.

An API, a job queue, another app or an AI agent needs only the work, and it can't click OK. When both are mixed in one procedure, nothing without a UI can use the app. *Headless* means the work lives in procedures that never talk to a person. Pages call them after asking, and everything else calls them directly. See `Legacy App v2 (headless)/README.md` for a worked example with screens.

Add a public facade codeunit (`"<App> API"`, `Access = Public`) with one procedure per operation. It needs no Bifröst dependency. It follows these rules:

- **No UI and no `Commit`.** The caller decides and owns the transaction; the facade executes.
- **Check preconditions first,** and fail with translatable errors that say what to do ("Item 'X' does not exist. Check the number …").
- **Return outcomes:** the new total, or `true`/`false` for "was anything cancelled".
- **Make implicit inputs parameters:** dates, locations, the "current record".
- **Offer read procedures** (`Get…`, `Has…`, `Is…`), so callers can check state.
- **Add events:** `OnBefore…` (with `IsHandled`) and `OnAfter…`.

Keep the old entry points as thin shells so existing callers keep working. UI procedures keep their `Confirm`, then call the facade. Old signatures keep their contract (check first, e.g. `IsReservable`, then call) and get `[Obsolete('Use …', '<ver>')]`. Pages ask the user, then call the facade.

**How callers use the facade:**

| Caller | How |
|---|---|
| Your own page | Asks the person (`Confirm`), then calls the facade. |
| Another AL app | Calls the facade from its own small wrapper codeunit, run with `if not Codeunit.Run(...)` so it survives a failure and reads `GetLastErrorText()`. |
| The Bifröst adapter | Calls the facade from an isolated Process codeunit (§7.3). |
| A job queue | A codeunit that reads its parameters from the job queue entry and calls the facade. |

**Test the facade without a UI.** Call every facade procedure from a test codeunit or a job queue entry. None may open a dialog. A call that would need one means the decision should be a parameter.

### 7.2 Audit the old code first

Before any procedure becomes a facade operation or a message type, go through every code path it reaches, including the subscribers of other apps, and look for the patterns below. Code that works well in the UI can still do the wrong thing when no person is there, and many of these patterns fail **silently**.

**Errors are fine** — but only when all four of these hold:

- nothing was committed earlier in the call
- nothing catches the error and carries on
- the text tells the caller what to fix
- the text is not empty

An `Error` then rolls the whole call back, and Bifröst returns the text.

| Pattern | Search for | Why it breaks without a UI | Fix |
|---|---|---|---|
| **Dialogs** | `Confirm`, `StrMenu`, `Message`, `Page.Run`, `RunModal`, `Report.Run` with a request page, `Dialog.Open`, `Hyperlink` | Without a UI, some calls are skipped and some fail the whole call. Either way the decision a person would make never gets made. | Turn the decision into a parameter with a documented default. Remove progress windows. Use the `SetHideValidationDialog` / `HideDialog` variants of the base app. |
| **`GuiAllowed` branches** | `GuiAllowed` | The API takes a different path from the one you tested in the UI. Often that path skips a check or quietly picks a default. | `GuiAllowed` may change what is **shown**, never what is **checked or done**. Read the section below. |
| **`Commit`** | `Commit()` | Everything before it stays written even if a later step fails, so the call leaves half-finished data behind. It also breaks `Omit Commit` for callers that own the transaction. | Remove it from the work path, and let the caller own the transaction. A `Commit` that exists only to allow a later `RunModal` goes away with the dialog. |
| **Writes in a `[TryFunction]`** | `[TryFunction]` | Database changes inside a try function are not rolled back when it fails, and the server may block them outright. | Use try functions only for reads, parsing and HTTP. Isolate writes with `Codeunit.Run` (the Process codeunit pattern, §5). |
| **Swallowed errors** | `if not Codeunit.Run`, `ClearLastError`, `asserterror` outside tests | The error disappears and the code carries on as if nothing happened. `if Codeunit.Run(...)` inside an open write transaction is itself a runtime error. | Pass `GetLastErrorText()` on to the caller. Write nothing before the isolated run. |
| **Silent failure** | `exit(false)` without a reason, `Error('')` | The caller learns *that* something failed but not *why*. An empty `Error('')` rolls back and returns no text at all. | Return or raise a reason the caller can act on. Never answer a no-op as if it were a change. |
| **Rules that live on the page** | `OnValidate`/`OnAction` on page fields and actions, `CurrPage.SetSelectionFilter`, `CurrFieldNo` | Code never goes through the page, so these rules are skipped, and "the selected rows" does not exist. | Move the rules to the table or the facade. The selection becomes an explicit list or filter parameter. |
| **Hidden context** | `WorkDate()`, `UserId()`, global variables that the page sets, `SingleInstance` codeunits | A value the page used to supply is missing, or state is left over from an earlier call in the same session. | Make it a parameter with a documented default. Don't keep state between calls. |
| **Skipped validation** | direct field assignment, `Modify(false)`, `Insert(false)` | The table's rules never run, so rows can be written that the UI would have refused. | Use `Validate` unless you have a documented reason not to. |
| **Side effects that can't be undone** | email, HTTP, file writes in the middle of a write | A rollback can't take back an email that was already sent. | Do these after the data is safe, or queue them. Make them safe to repeat. |
| **Asynchronous work** | `StartSession`, `TaskScheduler`, job queue entries | The call returns before the work is done, so "success" means only that the work was queued. | Return a clear `queued` result and add a read type that reports the status. |
| **Files and downloads** | `Download`, `UploadIntoStream`, `File.`, report `SaveAs` to a path | There is no file dialog, and nobody receives the file. | Take and return Base64 or structured JSON. |
| **Duplicates on retry** | number series in a write, `Insert` without an existence check | A caller that retries after a timeout creates a second row. | Accept an `externalId` and look it up first (see `Reference.ServiceVisit.Create`). |
| **Unbounded work** | loops without filters, `FindSet` over whole tables, no `SetLoadFields` | Without a UI the call times out, or it locks tables for everyone else. | Filter, use `SetLoadFields`, and cap the result with a documented `top`. |
| **Formats that depend on the user's language** | `Format(date)`, `Evaluate` without `9` | The same call gives different results depending on the user's language settings. | Use `Format(x, 0, 9)` / `Evaluate(x, t, 9)`, and send dates as YYYY-MM-DD. |
| **UI subscribers in other apps** | *(this can't be found by searching)* | Another extension's `OnAfter…` subscriber opens a `Confirm`. | Test the type with the customer's other apps installed. Prefer base-app entry points that support hiding dialogs. |

**Keeping `GuiAllowed`.** You don't have to remove it. Many procedures are called from both pages and code, and wrapping a message or a progress window in `if GuiAllowed() then` is a sensible way to keep one procedure for both. The test for each branch is: **with the UI switched off, would a caller get the same rules, the same writes and the same outcome?**

| Fine: only what is shown changes | Not fine: the rules change |
|---|---|
| `if GuiAllowed() then Window.Open(ProgressTxt);` | `if GuiAllowed() then if Qty > Inventory then if not Confirm(...) then exit(false);`: without a UI the check disappears, and the call over-reserves. |
| `if GuiAllowed() then Message(DoneMsg, Count);` when the count is also returned | `if not GuiAllowed() then exit;`: code callers silently get nothing. |
| `if GuiAllowed() then Notification.Send();` | `if GuiAllowed() then Validate(...) else Field := Value;`: the rules run for people only. |

When a `Confirm` guards a decision, the non-UI branch must neither skip the check nor quietly answer "yes". Make the answer a parameter with a safe default, as `AllowOverStock` does, or fail with an error that names the parameter. The facade in `Legacy App` 2.1 has no `GuiAllowed` at all. Its UI entry points, such as `Legacy Stock Mgt.CancelReservation`, keep an unconditional `Confirm`, so they are plainly for people. Code callers use the facade. Don't wrap a guarding question in `if GuiAllowed() then`. Without a UI, the branch then answers "yes" for the person.

Also, `GuiAllowed` is not a reliable "is this Bifröst?" test. It is false for web services, the job queue and background sessions, and true in test pages. Never use it to switch behaviour for a particular caller.

**See it in code.** `Legacy App v1` contains seven of these patterns, each marked `AUDIT 7.2 - <pattern>`. `Legacy App` 2.1 fixes each one at a line marked `FIXED 7.2 - <pattern>`, and `Legacy App - Bifrost` exposes the result. Search both folders for `7.2 -` to read them side by side.

| Pattern | v1 (before) | v2 facade (after) | Message type (the proof) |
|---|---|---|---|
| Dialogs | `Confirm` in `CancelReservation` and the stock check; progress window and `Message` in `ReleaseAll` | The page asks; the facade never does | `Legacy.Stock.CancelReservation`, `Legacy.Stock.ReleaseAll` |
| `GuiAllowed` branch | The stock check runs only when there is a UI | The check runs for every caller; the person's decision becomes the `AllowOverStock` parameter | `Legacy.Stock.Reserve` refuses over stock unless `allowOverStock: true` |
| `Commit` | Between delete and log; after every row in `ReleaseAll` | None: one transaction | A failed release leaves nothing half done |
| Swallowed errors | `if Codeunit.Run … else ClearLastError()` counts failures as "skipped" | Errors reach the caller | The error text comes back as `status = Error` |
| Silent failure | `exit(false)`, `Error('')` | Returned outcomes: new total, `cancelled`, `released` | `cancelled: false`, `released: 0` |
| Rules on the page | The reserve rules live in the page trigger | The rules live in the facade | Every type gets the same rules |
| Unbounded work | `ReleaseAll` touches every row | `ReleaseReservations(ItemFilter)`, and the list is capped at 100 rows | `Legacy.Stock.List` (capped), `ReleaseAll` needs a filter and `expectedCount` |
| Duplicates on retry | – | – (the facade adds to the reservation) | Documented as "not safe to repeat", with a read to check |

**The developer owns the audit.** Bifröst can't see inside your code. It can only run what you expose, so the audit is your part of the contract. For every message type, record the audit next to its contract (§4) and in the pull request:

```text
Audit (§7.2)   <message type>
Call path:     <facade procedure> -> <what it calls, including base-app entry points>
Findings:      <pattern>: fixed | not present | accepted - <reason and what the help says about it>
Tested:        <break-set calls that prove the fixes>
```

"Accepted" is allowed, for example "not safe to repeat", but only when the help says so in words an agent will act on. A pattern you didn't look for is not "not present".

### 7.3 Adapt it to Bifröst (path C)

Build a **separate adapter app** that depends on the existing app (at the version with the facade) and on Foundation:

- **One message type per facade operation, plus the reads.**
- **The adapter checks the shape** of the input: missing, empty, type, length, format. **The facade checks the business rules.** Don't duplicate them.
- **Call writes through an isolated Process codeunit.** The facade's error texts then become the caller's errors, so write them for callers.
- **When the adapter may call the facade directly:** only when the procedure raises no `Error()` that the caller must see, and returns a result you can test (a Boolean, a count, a value). `Legacy.Stock.Get` reads `HasReservation` and `GetReservedQuantity` directly. `Legacy.Stock.Reserve` can't: the facade raises actionable errors (unknown item, blocked item, over stock), so it runs behind `Legacy Reserve Process`. When a procedure you call directly gains an `Error()`, move it behind a Process codeunit.
- **The adapter carries its own trimmed input layer** (`Legacy App - Bifrost/src/LegacyAdapterInput.Codeunit.al`, a cut-down copy of §5.1).
- **Pass outcomes through** (`"cancelled": false`), and never answer a no-op like a real change.
- **`IsEnabled`** checks the permissions on the existing app's tables. The existing app should ship a permission set, and the adapter's own set includes it (`LEGACY ADAPTER` includes `LEGACY STOCK`).
- **Register the adapter** with the App Registry, passing 0 when it has no setup page.
- **Give it its own id range and a namespace** such as `<Vendor>.<App>.Bifrost`.
- **Help text and tests are new work regardless.** The facade's XML docs describe an AL signature, not the JSON contract, and existing tests don't touch the JSON path.
- **If you can't change the app,** wrap only what is already headless. For the rest, ask its owner for a facade, or implement the operation against its tables and document the risk.
- **Record the owner app in every test run,** so a problem in the underlying app reaches the team that owns it.

---

## 8. Test, and definition of done

Test in a **sandbox** through the MCP server or the API, serially, and record the verbatim response for each call.

**For every message type:**

- one happy path
- the break set:
  - target missing
  - target not found
  - wrong JSON type (an object where text is expected)
  - date `26.09.2026`
  - a number out of range
  - text too long
  - a repeat call
  - lcid `1039`
- a selection check: three realistic user phrasings, one with a synonym, and whether `find_message_types` finds the type or a fresh agent picks it over its siblings
- that `get_message_type_help` returns error texts matching what the calls returned

**Done when:**

- [ ] The contract is filled in. The description is ≤ 250 characters and names the effect and the sibling boundary.
- [ ] The §7.2 audit was run on the whole call path, and every finding is fixed or documented.
- [ ] The type is headless: no UI, no `Commit`, isolated writes, `Omit Commit` honoured, nothing written before the isolated run.
- [ ] All input goes through the input layer, and the four error kinds are distinct.
- [ ] The help has all 11 sections, and its errors are copied from the Labels.
- [ ] `IsEnabled` checks permissions, the direction is correct, secrets are redacted, and there is no silent success.
- [ ] It compiles with 0 errors (CodeCop, UICop, PerTenantExtensionCop or AppSourceCop).
- [ ] The break set passes live.
- [ ] `Help.<App>.Get` lists the type.

## 9. How the agent should work

1. Ask which path (A/B/C) and which operations to expose.
2. Draft the contract (§4) for each type and get the user's approval.
3. Implement by copying §5. Don't invent other patterns.
4. Compile, fix, and ask the user to publish to a sandbox.
5. Run §8 and report each result with the verbatim response.

## 10. Next patterns

### Minimal types to start from

`Bifrost Reference` also has three minimal types. They show the bare shape, not the full patterns above.

| Type | Shows | File |
|---|---|---|
| `Reference.Echo.Get` | The smallest possible type, help inline | `Bifrost Reference/src/MessageTypes/RefEchoSetImpl.Codeunit.al` |
| `Reference.Table.Get` | A read with "not found" answered by `RespondWithError` | `RefTableGetImpl.Codeunit.al` |
| `Reference.Note.Add` | A write through `Ref Input.RunIsolated`, failing on a duplicate key | `RefNoteAddImpl.Codeunit.al`, `RefNoteAddProcess.Codeunit.al` |

### Ideas not yet in this repository

Each idea has the pattern it should follow and the trap to avoid. Fill in the contract (§4) before you build one.

| Idea | Typical use | Pattern | Trap to avoid |
|---|---|---|---|
| **Document with lines** | Create a sales quote or service order with lines in one call | Validate the header and every line first. One isolated Process for header plus lines. Return the numbers. | A partial document when line 3 fails. Generic `Data.Records.Set` is blocked on line tables, so write lines in your own Process codeunit. |
| **Post a document** | Post an invoice your app created | A Check or PreviewPost type paired with Post. Irreversible. Name the permission set. | Base-app dialogs, unless you use `SetHideValidationDialog`. Posting flags left unset. |
| **Long-running job** | Recalculate or import thousands of records | Queue it (`queues` endpoint), return a job id, add a `…Status.Get` type. | Timeouts on the synchronous `tasks` path. |
| **Inbound webhook** | A payment provider or WMS calls BC | Inbound webhooks arrive through Foundation's `Webhook.Inbound.Receive` type, which raises `OnWebhookReceived` on `Webhook Inbound Events ori`. Subscribe, filter on source and event type, and set `Handled`. | Processing the same event twice. Make the handler idempotent. |
| **Outbound notification** | Tell an external system when a call has finished | Foundation raises the external business event `OnBifrostMessageCompleted` (`Message Events ori`) when a message with a Task Id completes. Subscribe to it through BC's business event subscriptions. | Blocking the user's transaction on an HTTP call. |
| **PDF or report output** | A statement or label for an agent to send | `SaveAs` to PDF without a request page, returned as Base64. | Request pages, and reports that `Commit`. |
| **File intake** | A vendor invoice PDF into BC | Incoming Document plus attachment. Return the entry number for the next step. | Base64 size limits. A read that returns huge content by default. |
| **Delta sync** | An external system mirrors your table | A read with `SystemModifiedAt` from/to, returning ids and changes, paged with skip/take. | Unbounded reads. |
| **Approval step** | Send, approve or reject in your app's own flow | Build on Foundation's `Document.Approval.*` types where possible. | A second approval engine next to BC's. |
| **Record-first discovery** | "What can I do with this record?" | A read that takes a table and a record and returns the types that act on it (via `GetFilterTableNo`) plus its status. | Hard-coded lists that drift from the enum. |
| **Metering** | Charge per call of your type | Implement `Msg Metering ori` for your own types only. | Pricing inside Foundation. It stays neutral by design. |
| **Take-over from an older app** | Move data from your pre-Bifröst app | Probe first, then copy. Idempotent and re-runnable. No `Commit` in install. Log each step. | A one-shot install that can't be repaired. |
