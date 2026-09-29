# Building on Bifröst: the complete guide for you and your coding agent

**Message types are your app's public API: headless inside, message types outside.**

**This one file is all you need.** Give it to your coding agent (Claude Code, GitHub Copilot, Cursor …) and say which of the paths in §2 you are on. Everything a new app needs is printed here: both `app.json` files, a complete minimal app with its test app (§5.8), the input layer (§5.1), a write (§5.3), the Foundation API and its exact runtime behaviour (§5.7), and translations (§5.9). The only other inputs are your own BC sandbox with Bifrost Foundation installed from AppSource, and the symbols you download from it. The folders in this repository show the same patterns at full size; mentions of them are pointers for further reading, never a required step.

---

## 1. What Bifröst is, and why message types

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

**Agent: read the real Foundation symbols (`.alpackages`) before writing code. Never guess a procedure name or signature.** Every Foundation API used in this file exists in Foundation 28.0 or later. The public signatures you need are listed in §5.7, the Foundation API cheat sheet.

**Environment:** partners use their own BC sandbox with Bifrost Foundation installed from AppSource. Download symbols from it and test in it.

### Why message types

Message types are your app's public API. A procedure call reaches only AL code that compiles against your app. A message type gives you more:

- **Reach.** Agents, MCP hosts, integrations over the API and Orchestrator playbooks find it and call it. No extra code per caller.
- **Audit.** Every call is a row in the Bifröst message log: who called, what they sent, what came back, and when.
- **Operations.** Queueing, retries, completion webhooks, versions and the caller's language come with the platform.
- **One permission gate.** Your permission set decides who can call the type, and `IsEnabled` hides it from users who can't. The same for every caller.
- **A listing customers can find.** The type's name and description are searchable, and its help is the documentation.
- **Usage.** Usage is counted per message. Customers buy it directly from Origo or through you, the partner.

**The principle: headless inside, message types outside.** Inside the app, the business logic is a headless, internal core that your own pages call. Outside the app, callers use your message types, not your procedures.

---

## 2. Pick your path

| Path | You have … | Do |
|---|---|---|
| **A. New app** | nothing yet | Build the minimal app and its test app in §5.8, publish, and see `MyApp.Hello.Get` answer. Then §3 → §4 → §5 → §8. (`Bifrost Boilerplate/` and `Bifrost Boilerplate Tests/` in this repository are the same thing, ready to copy.) |
| **B. Existing app** | an app you own, whose operations should be callable | Audit it (§7.1). Make it headless with an **internal** core, and add the message types **in the same app** (§7.2). Then §8. The worked example is `Legacy App v1` → `Legacy App v2`. |
| **C. Exception: separate adapter app** | an app sold to some customers **without** Bifröst, or someone else's app you can't change | A public facade in the app and a separate adapter app with the message types (§7.4). Only when B is not possible. |

### Typical partner situations and which path fits

| Situation | What is usually not headless | Path | Where the message types live |
|---|---|---|---|
| **Your own app, built for the UI**: logic in page actions, dialogs, `Commit`s | Page triggers holding the rules; `Confirm`/`StrMenu`; request pages | **B** | In the app itself. A separate adapter app (**C**) only if some customers run it without Bifröst. |
| **Your own app that already has codeunit APIs or web services** | Usually little. Watch for `Commit`, `GuiAllowed` branches and silent `exit(false)`. | **B** (the audit finds the gaps) | In the app itself |
| **Someone else's app** (an AppSource ISV app) | Unknown; you can't change it | **C**, using only its public procedures and events | Always a separate adapter app |
| **Customisations on the base app** (your PTE extends sales, purchasing, inventory …) | The base app's own dialogs: posting, releasing, reports | **A**, wrapping base-app codeunits headless (`SetHideValidationDialog`, `…HideDialog`, preview posting, reports via `SaveAs`) | Your PTE, or a companion app. Check first that Foundation doesn't already have the operation. |
| **An integration app** (web shop, WMS, bank or e-invoice connector) | Setup wizards, credentials in tables, jobs started from pages | **A** or **B**, with secrets in `Secret Store ori` and one Setup action | The connector app |
| **Batch jobs and job queue processes** | Request pages and progress dialogs; long runtimes | **B** (parameters instead of request pages), with a queued type plus a status type | The app itself |
| **Approvals and decisions** ("are you sure?", manager sign-off) | The decision is a dialog | **B**: the decision becomes a parameter, or goes through Foundation's `Document.Approval.*` | The app itself |
| **An app built on the older Origo Cloud Events platform** | Usually fine, but on the retired platform | Change the dependency to Foundation: the app id changes (`a629b897-…` → `7505e808-6e52-4b96-a328-82573391297a`), not just the name. Rename the Cloud Events objects to their Bifröst names (`ExecuteCloudEventTask` → `ExecuteBifrostTask`, `CE Message Argument ori` → `Message Argument ori`, …). | The app itself |

**Rule of thumb:** the business logic lives headless in the app that owns it, behind an internal core. The message types, their input checks and their help live in the same app. Never copy business rules into a message type.

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
   - *missing*: "No fixed asset was given …"
   - *not found*: "Fixed asset 'X' was not found …", echoing the value
   - *wrong type*: "must be a single value …"
   - *wrong format*: "not a date in the format YYYY-MM-DD …"
7. **Formats:**
   - Dates are ISO `YYYY-MM-DD` only. `26.09.2026` is refused with the expected format, never guessed.
   - Numbers use a dot as decimal separator.
   - In responses: numbers as JSON numbers, "no value" as `null` (never `0`), enums by name (never `Format()`).
8. **Error texts are translatable Labels** (`Comment = 'is-IS=…'`), never literals. The comment alone translates nothing: see §5.9.
9. **All input goes through one shared input layer** (§5.1).

### Honesty and safety

10. **No silent success.** Report what happened (`"created": false`, `"cancelled": false`).
11. **`IsEnabled()` checks the exact permissions** the type needs. Users without them don't see the type.
12. **Direction:** `Outbound` for reads, `Inbound` for anything that writes.
13. **The verb is a promise.** Read verbs write nothing; write verbs write (the list is in rule 17). A `Get` that writes, or a `Set` that doesn't, is a naming bug.
14. **A read never inserts setup.** When the setup record doesn't exist yet, use defaults in memory (`GetOrDefault` in `Bifrost Reference/src/ExchangeRates/RefSetup.Table.al`).
15. **Irreversible bulk changes come as a pair:** a read-only Preview plus an Apply that requires a value from the preview (§5.6).
16. **Secrets:** hold them as `SecretText` and store them only via `Secret Store ori`. A type that *receives* a secret calls `Argument.RedactRequestData()` on every path, **after** its isolated write.

### Platform

17. **Name types `Area.Entity.Verb`,** in words a user would say. The name is the strongest search signal, and callers in every language send it as it is.
    - **Area** is your app's product area, one word (`Calibration`, `Fleet`, `Warranty`). Every type of the app uses the same Area, and it must be **yours alone**: never an area another app already uses (`Sales`, `Purchase`, `Data`, `Help`, `Document`, `Reference`, `Legacy` …). Two extensions can't add the same value name to `Message Type ori`, so check `Help.MessageTypes.Get` in your sandbox before you choose.
    - **Entity** is the business object, singular (`Item.List`, not `Items.List`). A qualifier may follow it (`Item.Summary.Get`, `GLAccount.Overview.Get`). A filter such as "overdue" is a parameter, not part of the name.
    - **Verb** is the last segment. It may name what it acts on (`CancelReservation`, `ReleaseAll`, `PreviewAdjustment`).
    - **The directory type** is `Help.<Area>.Get` (rule 21).

    | Verb | Effect | Meaning |
    |---|---|---|
    | `Get` | Read-only | One record or one answer. |
    | `List` | Read-only | Many records, capped (§5.8, "Lists"). |
    | `Preview…` | Read-only | Computes a change without making it (§5.6). |
    | `Create` | Commits | A new record. Make it safe to retry with `externalId`. |
    | `Add` | Commits | A line, a note or an amount added to something that exists. |
    | `Set` | Commits | Overwrites a value or a setting (`ApiKey.Set`). |
    | `Reserve` / `Release` | Commits | Holds / frees a quantity or a resource. |
    | `Cancel` | Commits | Undoes an earlier action. Safe to repeat: the second call answers "nothing cancelled". |
    | `Apply…` | Commits | Carries out what a `Preview…` showed (§5.6). |
    | `Post` | Irreversible | Posts to ledgers. |

    **The examples in this file use three example areas:** `Reference` (the types of this repository's `Bifrost Reference` app), `Legacy` (the `Legacy App` of §7) and `Contoso` (the §5.1–§5.4 code: the same `AssetMaintenance.Create` type as it would look in a partner's app). `MyApp` in §5.8 is the placeholder you replace with your own Area.

18. **Register the app with `App Registry ori`,** even when it has no setup page and no secrets (pass 0 as the page). Foundation's setup wizard can only switch on outbound HTTP for apps it knows.
19. **At most one action on Foundation's `Setup ori` page.** Your settings live on your own page.
20. **Never show your own HTTP, credentials or setup notification.** Foundation aggregates them on Bifrost Setup for every registered app.
21. **One `Help.<Area>.Get` directory type per app** (§5.8). Throughout this file, `Help.<App>.Get` means the same thing.

### A note on personal data

The examples use items, G/L accounts and fixed assets on purpose, so the repository holds no personal data. When your app handles customers, vendors, contacts or employees, follow your organisation's data-protection practice and Business Central's data classification. Two points are specific to Bifröst:

- **Descriptions, help and error texts are shown to every caller and agent.** Keep personal data out of them. An error may echo the identifier the caller sent.
- **Request bodies are kept in Bifröst's message log**, where administrators can see them. Send and store only what the type needs.

---

## 4. The contract: write it first, one per message type

Write the contract **before** the code, and review it with the user. Everything the caller sees comes from it: the name, the description (the **selection card**), the help (the **use card**), the input checks and error texts, and the break tests.

### Two moments, two cards

| Moment | The agent sees | What it needs | Card | Where it lives |
|---|---|---|---|---|
| **Selection:** "which of about 270 types do I call?" | name + one-line description | what it does, what it touches, how it differs from its siblings, the user's own words | **Selection card** | `GetDescription()` (≤ 250 characters) |
| **First call:** "how do I call it right?" | the help document | how the target is identified, parameters and formats, preconditions, errors and fixes | **Use card** | `GetMessageHelpAsMarkdownDocument()` |

Don't put everything in the description. Longer descriptions made agents hesitate, and facts that belong in the help drift out of date.

### Contract template

```
Name:            Area.Entity.Verb           (the user's words; the strongest search signal)
Effect:          Read-only | Commits | Rolled back | Irreversible
User words:      how users say it, incl. synonyms (undo, fix, receive, totals …)
Siblings:        similar types and how to tell them apart
Ask the user when: situations where the agent should ask instead of guessing
Target:          subject GUID → subject No. → body key; answers for "not given" and "not found"
Parameters:      key | type | required | default | format / range
Preconditions:   status, setup, permission set, flags
Response:        fields + JSON types; what "nothing happened" looks like
Errors:          exact Label text | cause | fix
Repeat safety:   what a second identical call does
```

### Selection card: the description

```
[Verb] [business object] [variants / what you get]. [Effect]. [Identified by …, only if it separates siblings]. [Not for X – use Sibling.]
```

- Start with the outcome verb a user would say.
- Name the effect with one of the four fixed words.
- Say how the target is identified only if that separates it from a sibling.
- Always give the boundary with the closest sibling.
- Never include codeunit or report numbers, internal jargon, or the dotted name repeated.

### Use card: the help

**The help is the only schema the caller gets.** When a message type is offered to an agent as a tool, the tool schema is generic: a `type`, a `subject` and a request string. Nothing about your parameters, response or errors is in it.

- **Contract only.** Describe what the caller sends and gets. No implementation detail (codeunit or procedure names, `Codeunit.Run`, `TryFunction`, `Commit`), no infrastructure, no history. Those belong in the XML doc comment.
- **Every section, every time,** even when the answer is "none". An empty Errors table tells the caller something; a missing section tells it nothing.
- **Change a Label and the help in the same commit.** Callers match on the exact error text.
- **Answer the repeat question in words.** There are three common answers:

  | Answer | Example | What the help says |
  |---|---|---|
  | Safe | `Legacy.Stock.CancelReservation` | A second call finds nothing, writes nothing and answers `"cancelled": false`. |
  | Fails on repeat | `Reference.Note.Add` | A second call with the same `no` gets the "already exists" error; after a timeout, treat that as "the first call went through". |
  | Repeat has an effect | `Legacy.Stock.Reserve` | Two identical calls reserve twice. Check with `Legacy.Stock.Get` when unsure. |

**The eleven sections, in this order** (the one skeleton for every help document):

1. **Overview**, including an **Effect:** line and when *not* to use the type.
2. **Workflow**: which types come before and after.
3. **Identifying the target**: keys in order, and the answers for "not given" and "not found".
4. **Parameters**: a table with key, type, required, rules.
5. **Request example**: minimal and runnable.
6. **Response**: an example plus a field table with JSON types.
7. **Errors**: exact text copied from the Labels, cause, fix.
8. **Safe retries / repeat**: one of the three answers above ("Read-only; safe to repeat" for a read).
9. **Permissions and side effects.**
10. **Formats and language.**
11. **Related message types**: only ones that exist.

**Bad and good help for the same type.** Bad:

```markdown
# Legacy.Stock.Reserve
Reserves stock.
```

The agent doesn't know how to name the item, what the quantity rules are, what happens over stock, or whether a retry is harmless. It will guess. Good (shortened; the real document has all eleven sections):

```markdown
# Legacy.Stock.Reserve

## Overview
Reserves a quantity of one item in Legacy App. An existing reservation for the item is
increased; otherwise one is created. Returns the new total.

**Effect:** Commits. Not safe to repeat (see Safe retries).

## Parameters
| Key | Type | Required | Rules |
| --- | --- | --- | --- |
| `itemNo` | text, max 20 | only if `subject` is empty | An existing, unblocked item. |
| `quantity` | number | yes | Greater than zero. |
| `allowOverStock` | true/false | no, default false | Send `true` only when the user agreed to reserve more than is in stock. |

## Errors
| `error` | Cause | Fix |
| --- | --- | --- |
| `Item 'X' does not exist. Check the number, or find the item with Data.Records.Get on table Item.` | Unknown item. | Check the number. |
| … every other Label, verbatim … | | |

## Safe retries / repeat
**Not safe to repeat:** two identical calls reserve twice. Check with `Legacy.Stock.Get` when unsure whether an earlier call went through.
```

The full version is `GetReserveHelp` in the Legacy help codeunit in `Legacy App v2 (headless)/src/MessageTypes/`.

### Worked example: `Reference.AssetMaintenance.Create`

```
Name:            Reference.AssetMaintenance.Create
Effect:          Commits
User words:      log maintenance, record a service on a machine, register repair time on a vehicle
Siblings:        FA ledger entries, depreciation, maintenance cost posting (FA journals) – this is a simple work log
Ask the user when: the date is unclear ("last week"), or which asset is meant is ambiguous
Target:          fixed asset – subject GUID → subject No. → body "assetNo"
                 not given → "No fixed asset was given. Send the asset number in subject or as "assetNo", or its SystemId in subject."
                 not found → "Fixed asset 'X' was not found. Check the number, or search for the asset with Data.Records.Get on table Fixed Asset."
Parameters:      assetNo         | text ≤20        | only if subject is empty | – |
                 maintenanceDate | date YYYY-MM-DD | yes | – | on or before work date
                 hours           | number          | yes | – | 0.25–24
                 description     | text ≤100       | no  | '' | a short note on the work done
                 externalId      | text ≤50        | no  | '' | makes retries safe
Preconditions:   fixed asset neither blocked nor inactive; write permission on Ref Asset Maintenance,
                 read permission on Fixed Asset
Response:        { entryNo, created, assetNo, maintenanceDate, hours, description, externalId }
                 created = false when externalId already existed (nothing written)
Errors:          copied from the Labels (see the help codeunit in Bifrost Reference/src/AssetMaintenance/)
Repeat safety:   with externalId: safe. Without: each call creates a new entry.
```

**The reasoning.** The name uses the user's words ("maintenance", "create"), not the base app's ("FA journal"). The effect is stated because an agent must know it writes. The siblings line exists because "maintenance" also matches FA posting, and the description must say it is not that. `externalId` exists because a caller that times out will retry.

The resulting selection card:

> Log maintenance work on a fixed asset (machine, vehicle): date, hours and a short note. Commits; safe to retry with the same externalId. Not for FA ledger entries, depreciation or posting maintenance costs.

The resulting use card is the help codeunit in `Bifrost Reference/src/AssetMaintenance/` (the same shape as §5.4). The read sibling, `Reference.GLAccount.Overview.Get`, has this selection card:

> Get a G/L account's balance as of a date, and its net change for a period: e.g. "what is on account 2910 at the end of August". Read-only. Account by subject (No. or SystemId). For the entries themselves use Data.Records.Get on G/L Entry.

### Checking a contract

- **Selection:** write three ways a user would ask for this, one with a synonym. Does `find_message_types` rank the type first? If you can't deploy yet, give a fresh agent the description and its three closest siblings and ask it to choose.
- **First call:** give a fresh agent only the help and a request in plain words. Does it produce the exact working call?
- **Drift:** does every error in the help exist as a Label in the code, and every Label appear in the help?

Descriptions and help written this way were picked and called correctly by both large and small models in blind tests on a catalogue of about 270 types.

---

## 5. Code patterns (copy these)

### 5.0 app.json

**Folder names first.** In a multi-root workspace, don't let one app's folder name be the beginning of another's, as in `My App` and `My App Tests`. The AL extension can then compile a newly created file as part of the wrong app. The signs are "object identifier … must be within the allowed ranges" of the other app, and missing symbols. Use names such as `My App` and `Tests - My App`, where neither name begins with the other. If it happens anyway, run *Developer: Reload Window* before anything else.

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
- **Choose `resourceExposurePolicy` deliberately.** §5.8 sets all three flags to `false`, which fits a product app. The reference samples in this repo allow debugging and source download only because they are meant to be read.
- The complete `app.json` of an app and of its test app are in §5.8.
- Download symbols from your own BC sandbox with Bifrost Foundation installed from AppSource.

### 5.1 The shared input layer

Create one codeunit, e.g. `"<App> Input"`, and read **every** parameter through it. Each `Get…` answers the caller itself and returns false, so callers write `if not … then exit;`.

```al
codeunit 50100 "Contoso Input"
{
    Access = Internal;

    var
        NotObjectErr: Label 'The request body must be a JSON object, for example { "accountNo": "2910" }.', Comment = 'is-IS=Beiðnin verður að vera JSON-hlutur, til dæmis { "accountNo": "2910" }.';
        MissingErr: Label 'Parameter ''%1'' is required. Send it as %2.', Comment = '%1 = parameter, %2 = type and example, is-IS=Færibreytan ''%1'' er nauðsynleg. Sendu hana sem %2.';
        EmptyErr: Label 'Parameter ''%1'' is empty. Send a value, for example %2.', Comment = '%1 = parameter, %2 = example, is-IS=Færibreytan ''%1'' er tóm. Sendu gildi, til dæmis %2.';
        NotAValueErr: Label 'Parameter ''%1'' must be a single value (text or number), not an object or an array.', Comment = '%1 = parameter, is-IS=Færibreytan ''%1'' verður að vera stakt gildi, ekki hlutur eða fylki.';
        TooLongErr: Label 'Parameter ''%1'' is %2 characters long; the maximum is %3.', Comment = '%1 = parameter, %2 = length, %3 = max, is-IS=Færibreytan ''%1'' er %2 stafir; hámarkið er %3.';
        DateFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.', Comment = '%1 = parameter, %2 = value, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki dagsetning á sniðinu ÁÁÁÁ-MM-DD. Sendu t.d. 2026-09-26.';
        NumberFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a number. Send a number with a dot as decimal separator, for example 2.5.', Comment = '%1 = parameter, %2 = value, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki tala. Sendu t.d. 2.5.';
        IntegerFormatErr: Label 'Parameter ''%1'' has the value ''%2'', which is not a whole number. Send for example 12.', Comment = '%1 = parameter, %2 = value, is-IS=Færibreytan ''%1'' hefur gildið ''%2'', sem er ekki heiltala. Sendu til dæmis 12.';
        RangeErr: Label 'Parameter ''%1'' is %2, but it must be between %3 and %4.', Comment = '%1 = parameter, %2 = value, %3 = min, %4 = max, is-IS=Færibreytan ''%1'' er %2 en verður að vera á bilinu %3 til %4.';
        AssetMissingErr: Label 'No fixed asset was given. Send the asset number in subject or as "assetNo", or its SystemId in subject.', Comment = 'is-IS=Engin eign var tilgreind. Sendu númer eignarinnar í subject eða sem "assetNo", eða SystemId hennar í subject.';
        AssetNotFoundErr: Label 'Fixed asset ''%1'' was not found. Check the number, or search for the asset with Data.Records.Get on table Fixed Asset.', Comment = '%1 = asset no. or SystemId received, is-IS=Eignin ''%1'' fannst ekki. Athugaðu númerið eða leitaðu að henni með Data.Records.Get á töflunni Fixed Asset.';
        TextExampleTok: Label 'text, for example %1', Comment = '%1 = example value', Locked = true;
        DateExampleTok: Label 'a date in the format YYYY-MM-DD, for example "2026-09-26"', Locked = true;
        NumberExampleTok: Label 'a number, for example 2.5', Locked = true;
        // These three are Locked, so an Icelandic error carries them in English. In new code prefer
        // language-neutral examples (§5.9).

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
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, StrSubstNo(TextExampleTok, ExampleValue)));
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

    // Absent or JSON null gives Found = false and Value = ''. Wrong type or too long is still an error.
    procedure GetOptionalText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer; var Value: Text; var Found: Boolean): Boolean
    var
        Token: JsonToken;
    begin
        Value := '';
        Found := false;
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit(true);
        if not ReadTextToken(Argument, Token, KeyName, MaxLength, Value) then
            exit(false);
        Found := Value <> '';
        exit(true);
    end;

    procedure GetRequiredDate(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Date): Boolean
    var
        Token: JsonToken;
        DateText: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, DateExampleTok));
            exit(false);
        end;
        if not ReadTextToken(Argument, Token, KeyName, 30, DateText) then
            exit(false);
        if not TryParseIsoDate(DateText, Value) then begin
            Argument.RespondWithError(StrSubstNo(DateFormatErr, KeyName, DateText));
            exit(false);
        end;
        exit(true);
    end;

    // Absent, null or empty gives Found = false and Value = 0D: the caller applies its own default.
    // Any other format is refused exactly as in GetRequiredDate, never ignored.
    procedure GetOptionalDate(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Date; var Found: Boolean): Boolean
    var
        DateText: Text;
    begin
        Value := 0D;
        if not GetOptionalText(Argument, RequestJson, KeyName, 30, DateText, Found) then
            exit(false);
        if not Found then
            exit(true);
        if not TryParseIsoDate(DateText, Value) then begin
            Argument.RespondWithError(StrSubstNo(DateFormatErr, KeyName, DateText));
            exit(false);
        end;
        exit(true);
    end;

    // Absent or null gives DefaultValue. Use it for maxRows, skip and take (never EvaluateSkipTake).
    procedure GetOptionalInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MinValue: Integer; MaxValue: Integer; DefaultValue: Integer; var Value: Integer): Boolean
    var
        Token: JsonToken;
        NumberText: Text;
    begin
        Value := DefaultValue;
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit(true);
        if not ReadTextToken(Argument, Token, KeyName, 20, NumberText) then
            exit(false);
        if not Evaluate(Value, NumberText, 9) then begin
            Argument.RespondWithError(StrSubstNo(IntegerFormatErr, KeyName, NumberText));
            exit(false);
        end;
        if (Value < MinValue) or (Value > MaxValue) then begin
            Argument.RespondWithError(StrSubstNo(RangeErr, KeyName, Format(Value, 0, 9), Format(MinValue, 0, 9), Format(MaxValue, 0, 9)));
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
            Argument.RespondWithError(StrSubstNo(MissingErr, KeyName, NumberExampleTok));
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
    // "Not given" and "not found" get different messages. Set SetLoadFields on FixedAsset before calling.
    procedure ResolveFixedAsset(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var FixedAsset: Record "Fixed Asset"): Boolean
    var
        AssetNoText: Text;
        Found: Boolean;
    begin
        if Argument.SubjectIsGuid() then begin
            if FixedAsset.GetBySystemId(Argument.Subject) then
                exit(true);
            Argument.RespondWithError(StrSubstNo(AssetNotFoundErr, Argument.Subject));
            exit(false);
        end;
        AssetNoText := DelChr(Argument.Subject, '<>', ' ');
        if AssetNoText = '' then begin
            if not GetOptionalText(Argument, RequestJson, 'assetNo', MaxStrLen(FixedAsset."No."), AssetNoText, Found) then
                exit(false);
            if not Found then begin
                Argument.RespondWithError(AssetMissingErr);
                exit(false);
            end;
        end;
        if StrLen(AssetNoText) > MaxStrLen(FixedAsset."No.") then begin
            Argument.RespondWithError(StrSubstNo(AssetNotFoundErr, AssetNoText));
            exit(false);
        end;
        if FixedAsset.Get(UpperCase(AssetNoText)) then
            exit(true);
        Argument.RespondWithError(StrSubstNo(AssetNotFoundErr, AssetNoText));
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

    // Runs a write codeunit (TableNo = "Message Argument ori") in isolation. Omit Commit = true: the
    // caller owns an open transaction, so the error is left to reach it. Otherwise it is answered.
    procedure RunIsolated(CodeunitId: Integer; var Argument: Record "Message Argument ori")
    begin
        if Argument."Omit Commit" then begin
            Codeunit.Run(CodeunitId, Argument);
            exit;
        end;
        if not Codeunit.Run(CodeunitId, Argument) then
            Argument.RespondWithError(GetLastErrorText());
    end;

    // Strictly YYYY-MM-DD, and a real date: 2026-02-30 and 26.09.2026 are both refused.
    local procedure TryParseIsoDate(DateText: Text; var Value: Date): Boolean
    var
        Year: Integer;
        Month: Integer;
        Day: Integer;
    begin
        if StrLen(DateText) <> 10 then
            exit(false);
        if (CopyStr(DateText, 5, 1) <> '-') or (CopyStr(DateText, 8, 1) <> '-') then
            exit(false);
        if not Evaluate(Year, CopyStr(DateText, 1, 4)) then
            exit(false);
        if not Evaluate(Month, CopyStr(DateText, 6, 2)) then
            exit(false);
        if not Evaluate(Day, CopyStr(DateText, 9, 2)) then
            exit(false);
        exit(TryDMY2Date(Day, Month, Year, Value));
    end;

    [TryFunction]
    local procedure TryDMY2Date(Day: Integer; Month: Integer; Year: Integer; var Value: Date)
    begin
        Value := DMY2Date(Day, Month, Year);
    end;

    [TryFunction]
    local procedure TryGetRequestJson(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject)
    begin
        RequestJson := Argument.GetRequestJson();
    end;
}
```

This is the input layer of the compiled, tested apps in this repository (`RefInput`, `My Input`), cut to what the examples use. Notes:

- `GetBySystemId(Argument.Subject)` compiles as printed: AL converts the `Text` to a `Guid`. Call it only after `SubjectIsGuid()`.
- An impossible date such as `2026-02-30` gives the same "not a date in the format YYYY-MM-DD" answer as `26.09.2026`.
- A true/false parameter: accept only JSON `true`/`false` or the texts `"true"`/`"false"`, never `yes`, `1` or `Y`, with its own error (`Send true or false, without quotes.`).
- Delete the procedures and Labels you don't use, so that every Label left appears in some help document.

### 5.2 Registering the type (enum extension)

```al
enumextension 50100 "Contoso Msg Type" extends "Message Type ori"
{
    value(50100; "Contoso.AssetMaintenance.Create")
    {
        Caption = 'Contoso.AssetMaintenance.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Contoso Maint Create Impl";
    }
}
```

The caption is `Locked = true` because callers in every locale send the same string. Never translate it. Value ids come from your own id range, like object ids; never renumber a published value. (`Contoso` is the example area of §5.1–§5.4, rule 17; use your own.)

### 5.3 The implementation: a write with validation and an isolated process

```al
codeunit 50101 "Contoso Maint Create Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        BlockedErr: Label 'Fixed asset ''%1'' is blocked, so no maintenance can be logged. Clear Blocked on the fixed asset card in Business Central, or choose another asset.', Comment = '%1 = fixed asset no., is-IS=Eignin ''%1'' er lokuð og því er ekki hægt að skrá viðhald á hana. Taktu hakið úr Lokað á eignaspjaldinu í Business Central eða veldu aðra eign.';
        InactiveErr: Label 'Fixed asset ''%1'' is inactive, so no maintenance can be logged. Clear Inactive on the fixed asset card in Business Central, or choose another asset.', Comment = '%1 = fixed asset no., is-IS=Eignin ''%1'' er óvirk og því er ekki hægt að skrá viðhald á hana. Taktu hakið úr Óvirk á eignaspjaldinu í Business Central eða veldu aðra eign.';
        FutureDateErr: Label 'Parameter ''maintenanceDate'' is %1, which is after the work date %2. Maintenance is logged after it is done; send a date on or before %2.', Comment = '%1 = maintenance date, %2 = work date, is-IS=Færibreytan ''maintenanceDate'' er %1, sem er eftir vinnudagsetningu %2. Viðhald er skráð eftir að það hefur verið unnið; sendu dagsetningu sem er %2 eða fyrr.';

    procedure IsEnabled(): Boolean
    var
        Maintenance: Record "Contoso Asset Maintenance";
        FixedAsset: Record "Fixed Asset";
    begin
        exit(Maintenance.WritePermission() and FixedAsset.ReadPermission());   // exact permissions
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Contoso Asset Maintenance");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Log maintenance work on a fixed asset (machine, vehicle): date, hours and a short note. Commits; safe to retry with the same externalId. Not for FA ledger entries, depreciation or posting maintenance costs.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);                     // writes are Inbound
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        Help: Codeunit "Contoso Maint Create Help";
    begin
        Argument.SetResponseMarkdown(Help.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        FixedAsset: Record "Fixed Asset";
        Input: Codeunit "Contoso Input";
        Process: Codeunit "Contoso Maint Create Process";
        RequestJson: JsonObject;
        MaintenanceDate: Date;
        Hours: Decimal;
        Description: Text;
        ExternalId: Text;
        HasDescription: Boolean;
        HasExternalId: Boolean;
    begin
        Argument.AssertVersion1();        // first, before reading the payload
        Argument.AssertIsLicensed();

        // 1. Validate everything - reads only, no writes.
        if not Input.ReadRequest(Argument, RequestJson) then
            exit;
        FixedAsset.SetLoadFields("No.", Blocked, Inactive);
        if not Input.ResolveFixedAsset(Argument, RequestJson, FixedAsset) then
            exit;
        if FixedAsset.Blocked then begin                                   // business rules say what to do next
            Argument.RespondWithError(StrSubstNo(BlockedErr, FixedAsset."No."));
            exit;
        end;
        if FixedAsset.Inactive then begin
            Argument.RespondWithError(StrSubstNo(InactiveErr, FixedAsset."No."));
            exit;
        end;
        if not Input.GetRequiredDate(Argument, RequestJson, 'maintenanceDate', MaintenanceDate) then
            exit;
        if MaintenanceDate > WorkDate() then begin
            Argument.RespondWithError(StrSubstNo(FutureDateErr, Format(MaintenanceDate, 0, 9), Format(WorkDate(), 0, 9)));
            exit;
        end;
        if not Input.GetRequiredDecimal(Argument, RequestJson, 'hours', 0.25, 24, Hours) then
            exit;
        if not Input.GetOptionalText(Argument, RequestJson, 'description', 100, Description, HasDescription) then
            exit;
        if not Input.GetOptionalText(Argument, RequestJson, 'externalId', 50, ExternalId, HasExternalId) then
            exit;

        // 2. Write in isolation. Honour "Omit Commit" (the caller owns the transaction).
        Process.SetMaintenance(FixedAsset."No.", MaintenanceDate, Hours, CopyStr(Description, 1, 100), CopyStr(ExternalId, 1, 50));
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}

codeunit 50102 "Contoso Maint Create Process"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        AssetNo: Code[20];
        MaintenanceDate: Date;
        Hours: Decimal;
        Description: Text[100];
        ExternalId: Text[50];

    trigger OnRun()
    var
        Maintenance: Record "Contoso Asset Maintenance";
    begin
        // Safe retry: the same externalId returns the entry the first call created.
        if ExternalId <> '' then begin
            Maintenance.LockTable();                       // two concurrent retries cannot both insert
            Maintenance.SetCurrentKey("External Id");
            Maintenance.SetRange("External Id", ExternalId);
            if Maintenance.FindFirst() then begin
                Rec.SetResponseJson(BuildResponse(Maintenance, false));
                exit;
            end;
        end;

        Maintenance.Init();
        Maintenance."FA No." := AssetNo;
        Maintenance."Maintenance Date" := MaintenanceDate;
        Maintenance.Hours := Hours;
        Maintenance.Description := Description;
        Maintenance."External Id" := ExternalId;
        Maintenance.Insert(true);

        Rec.SetResponseJson(BuildResponse(Maintenance, true));
    end;

    procedure SetMaintenance(NewAssetNo: Code[20]; NewMaintenanceDate: Date; NewHours: Decimal; NewDescription: Text[100]; NewExternalId: Text[50])
    begin
        AssetNo := NewAssetNo;
        MaintenanceDate := NewMaintenanceDate;
        Hours := NewHours;
        Description := NewDescription;
        ExternalId := NewExternalId;
    end;

    local procedure BuildResponse(Maintenance: Record "Contoso Asset Maintenance"; Created: Boolean) Response: JsonObject
    begin
        Response.Add('entryNo', Maintenance."Entry No.");
        Response.Add('created', Created);                                               // no silent success
        Response.Add('assetNo', Maintenance."FA No.");
        Response.Add('maintenanceDate', Format(Maintenance."Maintenance Date", 0, 9));   // ISO in responses
        Response.Add('hours', Maintenance.Hours);                                         // JSON number
        Response.Add('description', Maintenance.Description);
        Response.Add('externalId', Maintenance."External Id");
    end;
}
```

The table behind it (a secondary key on `External Id` for the lookup, an AutoIncrement entry number):

```al
table 50104 "Contoso Asset Maintenance"
{
    Caption = 'Asset Maintenance', Comment = 'is-IS=Viðhald eignar';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.', Comment = 'is-IS=Færslunr.'; AutoIncrement = true; }
        field(2; "FA No."; Code[20]) { Caption = 'FA No.', Comment = 'is-IS=Eignanr.'; TableRelation = "Fixed Asset"; }
        field(3; "Maintenance Date"; Date) { Caption = 'Maintenance Date', Comment = 'is-IS=Dagsetning viðhalds'; }
        field(4; Hours; Decimal) { Caption = 'Hours', Comment = 'is-IS=Klukkustundir'; DecimalPlaces = 0 : 2; }
        field(5; Description; Text[100]) { Caption = 'Description', Comment = 'is-IS=Lýsing'; }
        field(6; "External Id"; Text[50]) { Caption = 'External Id', Comment = 'is-IS=Ytra auðkenni'; }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ExternalId; "External Id") { }
    }
}
```

Every `Caption` and `ToolTip` carries its Icelandic text the same way: tables, fields, pages, actions, enum values and permission sets.

**Safe retries:** the optional `externalId` is looked up first, under `LockTable()`. If it already exists, the Process returns that record with `"created": false` and writes nothing. When the customer asks for "safe to resend", make `externalId` required.

#### Where business rules live

| Layer | Owns | How it fails |
|---|---|---|
| **The core** (internal codeunit, §7.2) | The business rules: blocked, status, stock, dates against the work date. Also the write. | `Error()` with a translatable Label that says what to do. |
| **The Impl** | The shape of the input: missing, empty, type, length, format, range; and resolving the target (not given / not found). | `RespondWithError` + `exit`. |
| **The Process codeunit** | Runs the core's write in isolation (`RunIsolated`, or `Process.Run` as above). | Passes the core's error on. |

What the caller sees for a core error:

- **API and MCP** (`Omit Commit` = false): the error is caught and answered as `status = Error` with the core's text.
- **`Dispatcher ori.Execute`** (`Omit Commit` = true): the error is raised out of `Execute`. Tests use `asserterror` and `Assert.ExpectedError(<part of the text>)`.

That is intended: one rule, one text, two transports. The help lists the text once. **Don't copy a core rule into the Impl.** The Blocked, Inactive and date checks sit in the Impl above only because this example has no core: it writes one table of its own. In an app with a core, they move into the core.

A type may call a core procedure directly, without a Process, only when that procedure raises no error the caller must see (§7.2).

**A read** follows the same shape with direction `Outbound`, `IsEnabled` returning `ReadPermission()`, no Process codeunit, and `SetLoadFields` before resolving. For FlowFields "as of" a date, set `"Date Filter"` and use the fields that honour it: on a G/L account, `"Balance at Date"` (filter `..asOfDate`) and `"Net Change"` (filter `fromDate..asOfDate`). `Balance` ignores the date filter. `Reference.GLAccount.Overview.Get` does exactly this and answers `netChange: null` when no `fromDate` was sent.

### 5.4 The help codeunit (the use card)

```al
codeunit 50103 "Contoso Maint Create Help"
{
    Access = Internal;

    procedure GetHelpText(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Contoso.AssetMaintenance.Create');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Logs maintenance work done on one fixed asset: the date, the hours and a short note.');
        Help.AppendLine('**Effect:** Commits. Not for FA ledger entries, depreciation, or posting maintenance costs.');
        Help.AppendLine('');
        Help.AppendLine('## Identifying the asset');
        Help.AppendLine('1. `subject` as GUID (SystemId)  2. `subject` as the fixed asset number  3. `assetNo` in the body.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `assetNo` | text, max 20 | only if `subject` is empty | Must exist and be neither blocked nor inactive. |');
        Help.AppendLine('| `maintenanceDate` | date **YYYY-MM-DD** | yes | On or before the work date. `26.09.2026` is refused. |');
        Help.AppendLine('| `hours` | number | yes | 0.25 to 24. Dot as decimal separator. |');
        Help.AppendLine('| `description` | text, max 100 | no | A short note on the work done. |');
        Help.AppendLine('| `externalId` | text, max 50 | no | Your own id for this entry. Makes the call safe to retry. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Contoso.AssetMaintenance.Create", "subject": "FA000010",');
        Help.AppendLine('  "data": { "maintenanceDate": "2026-09-25", "hours": 1.5, "description": "Oil change", "externalId": "WO-4711" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "entryNo": 12, "created": true, "assetNo": "FA000010", "maintenanceDate": "2026-09-25",');
        Help.AppendLine('  "hours": 1.5, "description": "Oil change", "externalId": "WO-4711" }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `No fixed asset was given. Send the asset number in subject or as "assetNo", or its SystemId in subject.` | No asset in subject or body. | Send the asset number in `subject`. |');
        Help.AppendLine('| `Fixed asset ''X'' was not found. Check the number, or search for the asset with Data.Records.Get on table Fixed Asset.` | Unknown asset. | Check the number. |');
        Help.AppendLine('| `Parameter ''maintenanceDate'' has the value ''26.09.2026'', which is not a date in the format YYYY-MM-DD. Send for example 2026-09-26.` | Wrong date format. | Send `2026-09-26`. |');
        Help.AppendLine('| `Parameter ''maintenanceDate'' is 2026-10-01, which is after the work date 2026-09-26. Maintenance is logged after it is done; send a date on or before 2026-09-26.` | Date in the future. | Log work after it is done. |');
        // ... every Label the type can return, copied verbatim ...
        exit(Help.ToText());
    end;
}
```

**Where the help text lives.** Either inline in the Impl codeunit (fine for a small type, e.g. `RefEchoSetImpl.Codeunit.al`) or in its own Help codeunit, as above (the default once the help grows, e.g. the Legacy help codeunit in `Legacy App v2 (headless)/src/MessageTypes/`). Either way, one `AppendLine` per Markdown line, and `''` for a single quote.

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

**Also** (all three are printed in §5.8):

- a **permission set** covering your tables: `tabledata <table> = RIMD` and `table <table> = X` for each one. Don't put `BIFROST API ori` in it; assign that next to yours (§5.7).
- a **`Help.<Area>.Get`** type returning a Markdown table of your types with their effect. Keep that table in step with the enum; a test that looks for every type name in its answer is the cheapest guard.
- the registration above.

### 5.6 Preview / apply pair (irreversible or bulk changes)

- **`…Preview…`** (Outbound, read-only) computes the change and returns it, including a count or a hash of the selection.
- **`…Apply…`** (Inbound) requires that value back (e.g. `expectedItemCount`). It refuses with "the selection changed since the preview … run the preview again" when it differs.
- **Both use one shared codeunit** for selection and calculation, so preview and apply can never disagree.
- **Each description points to the other.**

### 5.7 Foundation API cheat sheet

Verified against Bifrost Foundation 28.0 and against the apps in this repo. Only public objects and members are listed. Anything else in the symbols is either internal or not meant for partners. Names are exact: copy them.

#### Interface `"Msg Interface ori"`

| Procedure | What Foundation does with it |
|---|---|
| `IsEnabled(): Boolean` | Filters the type out of listings (MCP type search, `Help.MessageTypes.Get` with `onlyEnabled`). It does **not** block a direct call, so the type must still check what it needs. |
| `GetFilterTableNo(): Integer` | Listed as `filterTableNo` in `Help.MessageTypes.Get`. Return 0 when no table applies. |
| `GetDescription(): Text[250]` | The selection card. Shown and searched in listings. |
| `GetMessageDirection(): Enum "Msg Direction ori"` | Listed as `messageDirection`. |
| `GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")` | Called by `Help.Implementation.Get`. Set the help with `Argument.SetResponseMarkdown(...)`. |
| `ExecuteBifrostTask(var Argument: Record "Message Argument ori")` | Runs the call. No return value: the answer is whatever you set on `Argument`. |

#### Interface `"Msg Metering ori"` (advanced, optional)

| Procedure | What Foundation does with it |
|---|---|
| `OnMessageCompleted(var Argument: Record "Message Argument ori")` | Called once after every successful call of the type. (Foundation skips metering for its own discovery types; your app's types, including your own `Help.*` type, are metered.) The argument carries the type, subject, request and response. It runs in its own transaction scope after the response is written, so it may write (a meter entry, a counter). An error in it is logged and rolls back only its own writes; the caller still gets the response. Never change the response here. |

Foundation's `Default Metering ori` does nothing and is the default for every value. To meter your own types, write a codeunit that implements the interface and name it on your enum value: `Implementation = "Msg Interface ori" = "<your Impl>", "Msg Metering ori" = "<your Metering>";`. The hook does not change how Bifröst counts usage.

#### Enums

| Enum | Values |
|---|---|
| `"Message Type ori"` (extensible) | Extend it: `value(<id>; "Area.Entity.Verb") { Caption = 'Area.Entity.Verb', Locked = true; Implementation = "Msg Interface ori" = "<your Impl codeunit>"; }` (§5.2). Metering needs no declaration: every value falls back to Foundation's default. |
| `"Msg Direction ori"` | `Outbound` (0), `Inbound` (1), `Both` (2) |
| `"Message Version ori"` | `"1.0"` (0), the only value |
| `"Secret Scope ori"` (not extensible) | `Company` (0), `"Company And User"` (1) |

#### Table `"Message Argument ori"` (temporary)

Fields a type reads:

| Field | Type | Meaning |
|---|---|---|
| `Subject` | `Text[250]` | The request's `subject`. A GUID, a number or a name. |
| `"Omit Commit"` | `Boolean` | True when the caller owns the transaction (for example `Dispatcher ori` with OmitCommit = true). Then don't catch errors from your isolated write (§5.3). False on the API path. |
| `Version` | `Enum "Message Version ori"` | Checked by `AssertVersion1()`. |
| `Type` | `Enum "Message Type ori"` | The type being run. |
| `Source` | `Text[250]` | The caller's source identifier. |
| `ID` | `Guid` | The message id. |

Procedures:

| Use | Signature | Notes |
|---|---|---|
| Read the body | `GetRequestJson(): JsonObject` | Empty object when there is no body. A body that is not a JSON object raises an error, so wrap it in a `[TryFunction]` (§5.1). |
| | `GetRequestText(): Text` | The raw body. |
| | `GetRequestDataArray(var RecordsArray: JsonArray): Boolean` | Accepts a top-level array or `{ "data": [ … ] }`. |
| | `TokenAsText(Token: JsonToken): Text` | `''` for null or a non-value. |
| | `TokenAsInteger(Token: JsonToken): Integer` | 0 for null, a non-value or a non-number. |
| | `TryGetGuidFromJson(JObject: JsonObject; PropertyName: Text; var GuidValue: Guid): Boolean` | False when missing, not a GUID or the empty GUID. |
| | `EvaluateSkipTake(RequestJson: JsonObject; var Skip: Integer; var Take: Integer)` | `take` defaults to 100, capped at 1000. A negative value raises a raw error (rule 5), so read `skip`/`take` with `GetOptionalInteger` (§5.1) instead. |
| Subject | `SubjectIsGuid(): Boolean` | True when `Subject` is a GUID. |
| Answer | `SetResponseJson(ResponseJson: JsonObject)` | Content type `text/json`. |
| | `SetResponseMarkdown(MarkdownText: Text)` | Content type `text/markdown`. Use it for help. |
| | `SetResponseText(ResponseText: Text)` and `SetResponseText(var ResponseTextBuilder: TextBuilder)` | Does not set a content type. Prefer the two above. |
| | `SetResponsePdf(var TempBlob: Codeunit "Temp Blob")` | Content type `application/pdf`. |
| Errors | `RespondWithError(ErrorMessage: Text)` | Answers `{"status":"Error","error":"<ErrorMessage>","hint":"…"}`. |
| | `RespondWithLastError()` | Answers `{"status":"Error","code":"BusinessCentralError","error":"<GetLastErrorText()>","hint":"…"}`. The call stack never reaches the caller; Foundation sends it to its own telemetry. This repo uses `RespondWithError(GetLastErrorText())`, which gives the same answer shape. |
| Guards | `AssertVersion1()` | Raises an error unless the version is `1.0`. Call it first. |
| | `AssertIsLicensed()` | Raises an error unless the call is marked licensed. Foundation checks the licence and quota before it calls `ExecuteBifrostTask` and marks every call it runs, so this only fails when the Impl is called outside Foundation. Foundation's own `Help.*` types don't call it, and neither do this repo's `Help.<App>.Get` types. Every other type calls it. |
| | `IsLicensed(): Boolean` | The same flag, without the error. |
| Secrets | `RedactRequestData()` | Replaces the stored request body with `{"redacted":true}` and clears it on the argument. Does nothing when there is no stored message (an Impl called directly in a test). |

The `hint` points the caller to `Help.Implementation.Get` for your type. It is left out for `Help.*` types. Don't call the `AssertLicense` overloads: they are deprecated no-ops.

#### Codeunit `"Dispatcher ori"`

Parameter names are as in the symbols. Every overload writes a `Message ori` row and runs the full Foundation pipeline, `Execute` included.

| Procedure | OmitCommit | Notes |
|---|---|---|
| `Execute(MessageType: Enum "Message Type ori"; MessageVersion: Enum "Message Version ori"; Subject: Text[250]; Source: Text[250]; ContentType: Text[50]; var RequestContent: BigText; var ResponseContent: BigText; var ResponseContentType: Text[50])` | `true` | The one tests use. Runs in the default language (below). Fires no webhook. |
| `Execute(…same 8…; OmitCommit: Boolean)` | you choose | |
| `EnqueueAndProcess(MessageType; MessageVersion; Subject; Source; ContentType; var RequestContent: BigText; TaskId: Guid; WindowsLanguageId: Integer; var MessageId: Guid; var ResponseContent: BigText; var ResponseContentType: Text[50]; var ResponseTime: Duration)` | `false` | A non-null `TaskId` fires the completion event. `WindowsLanguageId` is the language the call runs in; 0 = the default language, as `Execute`. |
| `EnqueueAndProcess(…same 12…; OmitCommit: Boolean)` | you choose | |
| `EnqueueAndProcess(…; var MessageId: Guid; var ResponseTempBlob: Codeunit "Temp Blob"; var ResponseContentType: Text[50]; var ResponseTime: Duration)` | `false` | Response in a `Temp Blob`, for binary output such as PDF. |
| `EnqueueAndProcess(…Temp Blob variant…; OmitCommit: Boolean)` | you choose | |

#### The Dispatcher round trip, exactly

Verified against Foundation 28.0. The test caller in §5.8 does exactly this.

**In:**

| Parameter | What to pass |
|---|---|
| `RequestContent` | The `data` part only, as JSON text: `{"name":"Anna"}`. Not the `{type, subject, data}` envelope. An empty `BigText` for "no body". `GetRequestJson()` in your type returns this object as it is. |
| `Subject` | What the envelope's `subject` would hold, or `''`. |
| `Source`, `ContentType` | `''` works; the repo's tests pass `''` for both. `ContentType` is only stored with the message. A user whose Session Source Approval is Manual is refused with an empty `Source`. |

**Out:**

| Outcome | `ResponseContent` | `ResponseContentType` |
|---|---|---|
| Success, `SetResponseJson(Obj)` | Exactly `Obj`, unwrapped: no `status`, no `result` wrapper. One exception: outside a sandbox, when the quota runs low, Foundation adds a `warnings` array to it. Ignore keys you don't know. | `text/json` |
| Success, `SetResponseMarkdown(Text)` (help) | The Markdown text. | `text/markdown` |
| `RespondWithError(Text)` | `{"status":"Error","error":"<Text>","hint":"…"}` | `text/json` |
| `Error()` raised in the type (a core rule inside the Process, `AssertVersion1`) | Nothing: with `OmitCommit` = true it is raised out of `Execute`. Test it with `asserterror` + `Assert.ExpectedError()`. | – |
| Refused by Foundation before your type runs | `{"status":"Error","error":"…",…}` (below). | `text/json` |

**Licence and quota.** Foundation's own `Help.*` types are never refused. Every other type, including your app's own `Help.*` type, needs the **Bifröst trial activated once in the environment**. Until it is, every call answers `{"status":"Error","error":"Bifrost trial has not been started. Send a Help.License.Sync message …","activationMethod":"Help.License.Sync",…}`, and every success assertion in a test fails with that text. Activate it by calling `Help.License.Sync` once, or on the Bifrost Setup page. In a SaaS **sandbox**, quotas are not enforced and the outbound-HTTP check is skipped, so after activation nothing else refuses a call. In production, a call can also be refused because outbound HTTP is off for Bifrost Foundation or because a monthly or prepaid quota is used up, each with its own `status = Error` answer. A successful call counts as one message in sandboxes too.

**The message row and the transaction.** Every call, `Execute` included, writes a row to the Bifröst message log before your type runs.

- **API, MCP, `EnqueueAndProcess`** (`Omit Commit` = false): Foundation commits that row before it calls `ExecuteBifrostTask`, and commits the response afterwards. Your type starts with no open write transaction, so `if not Process.Run(Argument)` is legal (rule 4).
- **`Execute`** (`Omit Commit` = true): the row is written in your transaction and not committed. The type then runs inside an open write transaction. That is why it must not catch its isolated write (§5.3). A test's rollback removes the row. Types that need their own commit boundary, such as posting previews, don't work with `OmitCommit` = true.

**Session, work date, language.**

- The type runs synchronously in the caller's session. `WorkDate()`, `UserId()` and `CompanyName()` are the caller's, so a `WorkDate()` set in a test reaches the type. Over the API, `WorkDate()` is the API session's work date, normally today. Document it as the default of any "as of" parameter.
- **Language:** `Execute` runs the call in the **default language**, restoring yours afterwards. The default is Bifrost Setup's Default Language Code, then Company Information's Default Language Code, then 1033 (English). A `GlobalLanguage()` you set before `Execute` is overridden. To choose the language, call `EnqueueAndProcess` with `WindowsLanguageId` (§5.9). Over the API and MCP, the caller sends `lcid`.

#### Codeunit `"App Registry ori"`

| Member | Signature |
|---|---|
| Event | `[IntegrationEvent(false, false)] OnRegisterApps(var Apps: Record "Registered App ori" temporary)` |
| Subscriber | `[EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]` |
| `AddApp` | `AddApp(var Apps: Record "Registered App ori" temporary; AppId: Guid; AppName: Text[250]; SetupPageId: Integer)`: pass 0 when there is no setup page. It is idempotent, and an empty GUID is ignored. |

#### Codeunit `"Secret Store ori"`

`SecretCode` is always `Code[50]`, and `AppId` is your module id. An empty `AppId` or `SecretCode` raises an error.

| Procedure | Notes |
|---|---|
| `Register(AppId: Guid; SecretCode: Code[50]; Description: Text[100]; Scope: Enum "Secret Scope ori")` | Idempotent. Changing the scope clears the stored value. |
| `Register(AppId: Guid; SecretCode: Code[50]; Description: Text[100]; Scope: Enum "Secret Scope ori"; AppName: Text[250])` | Preferred in an install codeunit (the app name may not be resolvable yet). |
| `Set(AppId: Guid; SecretCode: Code[50]; Value: SecretText)` | Raises an error if the secret isn't registered or the value is empty. |
| `TryGet(AppId: Guid; SecretCode: Code[50]; var Value: SecretText): Boolean` | Side-effect free. |
| `IsSet(AppId: Guid; SecretCode: Code[50]): Boolean` | Doesn't read the value. |
| `MarkUsed(AppId: Guid; SecretCode: Code[50])` | Stamps "last used" at most once a day. Only from a context that may write. |
| `Clear(AppId: Guid; SecretCode: Code[50])` / `ClearAll(AppId: Guid)` | Removes the value(s) but keeps the registration ("Not set"). |
| `Unregister(AppId: Guid; SecretCode: Code[50])` / `UnregisterAll(AppId: Guid)` | Removes the value(s) and the registration. |
| `SetFromDialog(AppId: Guid; SecretCode: Code[50]): Boolean` | The shared masked dialog. UI only, never from a message type. |
| `SetFromDialog(AppId: Guid; SecretCode: Code[50]; RequireConfirmation: Boolean; MultiLine: Boolean): Boolean` | Commits before it opens the dialog. |
| `RefreshAppNames()` | Retries app-name lookup for registrations without one. |
| `GetStorageKey(AppId: Guid; SecretCode: Code[50]): Text` | For tests of key layout. Never exposes the value. |

#### Foundation's discovery types

| Type | Call with | Returns |
|---|---|---|
| `Help.Implementation.Get` | `subject` = the type name, e.g. `Contoso.AssetMaintenance.Create` | The type's help document (`text/markdown`), from its `GetMessageHelpAsMarkdownDocument`. An empty or unknown subject raises an error, not a `status = Error` answer. |
| `Help.MessageTypes.Get` | optional `subject` = one type name. Optional body `{ "onlyEnabled": true }` | `{"status":"Success","usage":"…","result":[{"name","isEnabled","filterTableNo","description","messageDirection"}]}`. This is the metadata, not the help. |
| `Data.Records.Get` | body `{ "tableName": "<table object name>" }` or `{ "tableNumber": 50104 }` | Records of any normal table, your own extension tables included (Foundation blocks only its own internal tables and security tables). The caller needs read permission on the table. |

In a "not found" error, point the caller to your own `Get` or `List` type when you have one; otherwise to `Data.Records.Get on table <object name>`.

#### Foundation permission sets to assign next to your own

| Set | Assign to |
|---|---|
| `BIFROST API ori` (caption "API Access") | Every user or app registration that calls message types over the API or MCP. It includes `LOGIN`. Your own set covers your tables. |
| `BIFROST Read ori` (caption "Read-Only") | Users who only look at Bifröst messages, setup and logs. |
| `BIFROST Full ori` (caption "Full Access") | Administrators who run Bifrost Setup, the wizard and App Secrets. |

The posting-gate sets (`BIFROST GL Post ori`, `BIFROST ItemPost ori` …) matter only when your users also call Foundation's own posting types. Separately from permissions, a user whose Session Source Approval is set to Manual is blocked from sources they haven't approved. *Unverified:* that `BIFROST API ori` plus your own set is the complete minimum for every caller. It has not been tested live with a user who holds nothing else.

### 5.8 A minimal new app, complete

This section is enough on its own to start path A. It is `Bifrost Boilerplate/` and `Bifrost Boilerplate Tests/` from this repository cut down to the Hello World and the directory type; those folders are the same thing ready to copy, with two more sample types (`MyApp.Item.Summary.Get`, a read; `MyApp.Item.List`, a capped list).

**Replace before the first publish:** both `id` GUIDs (generate new ones), `name`, `publisher`, the id ranges (`50000–50049` and `50050–50099` are placeholders), the namespace `MyCompany.MyBifrostApp`, the object-name prefix `My`, and `MyApp` in every type name (your Area, rule 17).

```text
MyApp/
  app.json
  Translations/My Bifrost App.g.xlf        generated on every compile (never edit)
  Translations/My Bifrost App.is-IS.xlf    yours (§5.9)
  src/Common/MyInput.Codeunit.al           the §5.1 input layer, renamed "My Input"
  src/MessageTypes/MyMsgType.EnumExt.al
  src/MessageTypes/MyHelloGetImpl.Codeunit.al
  src/MessageTypes/MyHelpGetImpl.Codeunit.al
  src/Lifecycle/MyRegistration.Codeunit.al the §5.5 registration, with 0 as the page
  src/Lifecycle/MYBIFROSTAPP.PermissionSet.al
Tests - MyApp/
  app.json
  src/MyTestCaller.Codeunit.al
  src/MyHelloTests.Codeunit.al
  src/MySelectionCardLint.Codeunit.al
```

**`MyApp/app.json`**

```json
{
  "id": "<new GUID>",
  "name": "My Bifrost App",
  "publisher": "My Company",
  "version": "1.0.0.0",
  "brief": "Adds message types to Bifröst Foundation",
  "description": "…",
  "url": "https://www.example.com/",
  "EULA": "https://www.example.com/eula",
  "privacyStatement": "https://www.example.com/privacy",
  "help": "https://www.example.com/help",
  "target": "Cloud",
  "dependencies": [
    { "id": "7505e808-6e52-4b96-a328-82573391297a", "name": "Bifrost Foundation", "publisher": "Origo", "version": "28.0.0.0" }
  ],
  "idRanges": [ { "from": 50000, "to": 50049 } ],
  "resourceExposurePolicy": { "allowDebugging": false, "allowDownloadingSource": false, "includeSourceInSymbolFile": false },
  "supportedLocales": [ "en-US", "is-IS" ],
  "platform": "28.0.0.0",
  "application": "28.0.0.0",
  "runtime": "17.0",
  "features": [ "TranslationFile" ],
  "propagateDependencies": false
}
```

**`Tests - MyApp/app.json`**: no `internalsVisibleTo` is needed; the tests reach everything through `Dispatcher ori`, help included.

```json
{
  "id": "<another new GUID>",
  "name": "My Bifrost App Tests",
  "publisher": "My Company",
  "version": "1.0.0.0",
  "brief": "Unit tests for My Bifrost App",
  "description": "…",
  "target": "Cloud",
  "dependencies": [
    { "id": "7505e808-6e52-4b96-a328-82573391297a", "name": "Bifrost Foundation", "publisher": "Origo", "version": "28.0.0.0" },
    { "id": "<the app's id>", "name": "My Bifrost App", "publisher": "My Company", "version": "1.0.0.0" },
    { "id": "dd0be2ea-f733-4d65-bb34-a28f4624fb14", "name": "Library Assert", "publisher": "Microsoft", "version": "28.0.0.0" },
    { "id": "23de40a6-dfe8-4f80-80db-d70f83ce8caf", "name": "Test Runner", "publisher": "Microsoft", "version": "28.0.0.0" }
  ],
  "idRanges": [ { "from": 50050, "to": 50099 } ],
  "resourceExposurePolicy": { "allowDebugging": false, "allowDownloadingSource": false, "includeSourceInSymbolFile": false },
  "suppressWarnings": [ "AA0217" ],
  "supportedLocales": [ "en-US" ],
  "platform": "28.0.0.0",
  "application": "28.0.0.0",
  "runtime": "17.0",
  "propagateDependencies": false
}
```

**The enum values and the permission set** (two files; every file starts with the same `namespace` and `using` lines, and test files with `namespace MyCompany.MyBifrostApp.Tests;`, `using Origo.Bifrost;` and `using System.TestLibraries.Utilities;`, as the test caller below shows)

```al
namespace MyCompany.MyBifrostApp;

using Origo.Bifrost;

enumextension 50000 "My Msg Type" extends "Message Type ori"
{
    value(50000; "MyApp.Hello.Get")
    {
        Caption = 'MyApp.Hello.Get', Locked = true;
        Implementation = "Msg Interface ori" = "My Hello Get Impl";
    }
    value(50001; "Help.MyApp.Get")
    {
        Caption = 'Help.MyApp.Get', Locked = true;
        Implementation = "Msg Interface ori" = "My Help Get Impl";
    }
}

// ---- src/Lifecycle/MYBIFROSTAPP.PermissionSet.al ----
namespace MyCompany.MyBifrostApp;

using Microsoft.Inventory.Item;

permissionset 50000 "MY BIFROST APP"          // at most 20 characters
{
    Assignable = true;
    Caption = 'My Bifrost App', Comment = 'is-IS=Bifröst-appið mitt';
    // Add tabledata <table> = RIMD and table <table> = X for every table you add.
    // Assign Foundation's BIFROST API ori next to this set; don't include it here.
    Permissions = tabledata Item = R;
}
```

**The Hello World** (`MyApp.Hello.Get`). It reads no business data, so an answer proves the whole path: the app is published, the type is registered and visible, the caller reaches it, and the answer names the app version, so you see whether a new publish is live.

```al
namespace MyCompany.MyBifrostApp;

using Origo.Bifrost;

codeunit 50001 "My Hello Get Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        GreetingTxt: Label 'Hello, %1! My Bifrost App is working in %2.', Comment = '%1 = the name sent, or the user, %2 = company name, is-IS=Halló, %1! My Bifrost App virkar í %2.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);                                   // reads no data, so every user may see it
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Hello World for My Bifrost App: answers with a greeting, the user, the company and the app version. Read-only; reads no business data. Call it first after publishing to check the app is live.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# MyApp.Hello.Get');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Overview');
        HelpText.AppendLine('Hello World for My Bifrost App: a greeting, who you are, the company and the app version.');
        HelpText.AppendLine('Use it to check that the app is installed and reachable. Not for business data.');
        HelpText.AppendLine('**Effect:** Read-only.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Workflow');
        HelpText.AppendLine('This type first, then `Help.MyApp.Get` to see what the app offers.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Identifying the target');
        HelpText.AppendLine('None: `subject` is not used.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Parameters');
        HelpText.AppendLine('| Key | Type | Required | Rules |');
        HelpText.AppendLine('| --- | --- | --- | --- |');
        HelpText.AppendLine('| `name` | text, max 50 | no | Who to greet. Default: the user. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Request example');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "type": "MyApp.Hello.Get", "data": { "name": "Anna" } }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Response');
        HelpText.AppendLine('```json');
        HelpText.AppendLine('{ "message": "Hello, Anna! My Bifrost App is working in CRONUS.", "user": "ANNA", "company": "CRONUS",');
        HelpText.AppendLine('  "language": 1033, "serverTime": "2026-09-27T09:15:00.000Z", "app": "My Bifrost App", "appVersion": "1.0.0.0" }');
        HelpText.AppendLine('```');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Errors');
        HelpText.AppendLine('| `error` | Cause | Fix |');
        HelpText.AppendLine('| --- | --- | --- |');
        HelpText.AppendLine('| `Parameter ''name'' is 60 characters long; the maximum is 50.` | Name too long. | Send a shorter name. |');
        HelpText.AppendLine('| `Parameter ''name'' must be a single value (text or number), not an object or an array.` | Wrong JSON type. | Send text. |');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Safe retries / repeat');
        HelpText.AppendLine('Read-only; safe to repeat.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Permissions and side effects');
        HelpText.AppendLine('Visible to every user of the app. No side effects.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Formats and language');
        HelpText.AppendLine('`serverTime` is ISO 8601 in UTC. `message` and error texts follow the caller''s `lcid`; this document is English.');
        HelpText.AppendLine('');
        HelpText.AppendLine('## Related message types');
        HelpText.AppendLine('- `Help.MyApp.Get` - what this app offers.');
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        MyInput: Codeunit "My Input";
        AppInfo: ModuleInfo;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Name: Text;
        HasName: Boolean;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not MyInput.ReadRequest(Argument, RequestJson) then
            exit;
        if not MyInput.GetOptionalText(Argument, RequestJson, 'name', 50, Name, HasName) then
            exit;
        if Name = '' then
            Name := UserId();

        NavApp.GetCurrentModuleInfo(AppInfo);
        ResponseJson.Add('message', StrSubstNo(GreetingTxt, Name, CompanyName()));
        ResponseJson.Add('user', UserId());
        ResponseJson.Add('company', CompanyName());
        ResponseJson.Add('language', GlobalLanguage());
        ResponseJson.Add('serverTime', Format(CurrentDateTime(), 0, 9));
        ResponseJson.Add('app', AppInfo.Name());
        ResponseJson.Add('appVersion', Format(AppInfo.AppVersion()));
        Argument.SetResponseJson(ResponseJson);
    end;
}
```

`My Input` needs only `ReadRequest`, `GetOptionalText`, `ReadTextToken`, `TryGetRequestJson` and their Labels from §5.1 for this. Keep the Hello type in production: it is the first call after every publish.

**The directory** (`Help.MyApp.Get`). Every app has exactly one. It answers `{ "format": "markdown", "markdown": "…" }`, calls no `AssertIsLicensed`, and its own help has the eleven sections like any other.

```al
codeunit 50002 "My Help Get Impl" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns a Markdown overview of My Bifrost App and lists its message types. Read-only. No request body is required.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpText: TextBuilder;
    begin
        HelpText.AppendLine('# Help.MyApp.Get');
        // … the eleven sections, as in the Hello type. Parameters: none. Errors: none of its own.
        // Response: { "format": "markdown", "markdown": "# My Bifrost App ..." }.
        Argument.SetResponseMarkdown(HelpText.ToText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ResponseJson: JsonObject;
        Overview: TextBuilder;
    begin
        Argument.AssertVersion1();
        Overview.AppendLine('# My Bifrost App');
        Overview.AppendLine('');
        Overview.AppendLine('| Type | Effect | What it does |');
        Overview.AppendLine('| --- | --- | --- |');
        Overview.AppendLine('| `MyApp.Hello.Get` | Read-only | Hello World: greeting, user, company and app version. Call it first. |');
        Overview.AppendLine('| `Help.MyApp.Get` | Read-only | This overview. |');
        Overview.AppendLine('');
        Overview.AppendLine('For the contract of any one type, call `Help.Implementation.Get` with its name.');
        ResponseJson.Add('format', 'markdown');
        ResponseJson.Add('markdown', Overview.ToText());
        Argument.SetResponseJson(ResponseJson);
    end;
}
```

**The test caller.** Every test goes through it: Foundation's public `Dispatcher ori`, never an Impl.

```al
namespace MyCompany.MyBifrostApp.Tests;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

codeunit 50050 "My Test Caller"
{
    var
        Assert: Codeunit "Library Assert";
        Dispatcher: Codeunit "Dispatcher ori";

    /// <summary>Runs a message type and returns its JSON answer.</summary>
    procedure Call(MessageType: Enum "Message Type ori"; Subject: Text; RequestText: Text) Response: JsonObject
    begin
        Response.ReadFrom(CallRaw(MessageType, Subject, RequestText));
    end;

    /// <summary>Runs a message type and returns its answer as text (JSON or Markdown).</summary>
    procedure CallRaw(MessageType: Enum "Message Type ori"; Subject: Text; RequestText: Text) ResponseText: Text
    var
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[50];
    begin
        if RequestText <> '' then
            RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250), '', '', RequestContent, ResponseContent, ResponseContentType);
        if ResponseContent.Length() > 0 then
            ResponseContent.GetSubText(ResponseText, 1);
    end;

    /// <summary>The help document of a type, exactly as callers receive it.</summary>
    procedure GetHelp(MessageTypeName: Text): Text
    begin
        exit(CallRaw(Enum::"Message Type ori"::"Help.Implementation.Get", MessageTypeName, ''));
    end;

    /// <summary>Asserts status = Error and that the error text contains ExpectedPart. (AssertError is a reserved word.)</summary>
    procedure AssertErrorAnswer(Response: JsonObject; ExpectedPart: Text)
    var
        ErrorText: Text;
    begin
        Assert.AreEqual('Error', GetText(Response, 'status'), 'Expected status Error. Answer: ' + AsJsonText(Response));
        ErrorText := GetText(Response, 'error');
        Assert.IsTrue(ErrorText.Contains(ExpectedPart), StrSubstNo('Error text "%1" should contain "%2".', ErrorText, ExpectedPart));
    end;

    /// <summary>Asserts that the answer is not an error.</summary>
    procedure AssertOk(Response: JsonObject)
    begin
        Assert.AreNotEqual('Error', GetText(Response, 'status'), 'Expected success. Answer: ' + AsJsonText(Response));
    end;

    /// <summary>A value of the answer as text; '' when absent, null or not a value.</summary>
    procedure GetText(Response: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Response.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    /// <summary>A number of the answer.</summary>
    procedure GetDecimal(Response: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        Response.Get(KeyName, Token);
        exit(Token.AsValue().AsDecimal());
    end;

    /// <summary>A true/false of the answer.</summary>
    procedure GetBoolean(Response: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        Response.Get(KeyName, Token);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>True when the key is present and its value is JSON null.</summary>
    procedure IsNullValue(Response: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Response.Get(KeyName, Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().IsNull());
    end;

    local procedure AsJsonText(Response: JsonObject) AsText: Text
    begin
        Response.WriteTo(AsText);
    end;
}
```

**The tests.** A raised error (a core rule inside a Process) is tested with `asserterror Caller.Call(…); Assert.ExpectedError('<part of the text>');`.

```al
codeunit 50051 "My Hello Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Caller: Codeunit "My Test Caller";

    [Test]
    procedure HelloGreetsByNameAndNamesTheApp()
    var
        Response: JsonObject;
    begin
        // [WHEN] Hello is called with a name
        Response := Caller.Call(Enum::"Message Type ori"::"MyApp.Hello.Get", '', '{"name":"Anna"}');
        // [THEN] it greets that name and says which app answered
        Caller.AssertOk(Response);
        Assert.IsTrue(Caller.GetText(Response, 'message').Contains('Anna'), 'The greeting should use the name sent.');
        Assert.AreEqual(CompanyName(), Caller.GetText(Response, 'company'), 'company');
        Assert.AreNotEqual('', Caller.GetText(Response, 'appVersion'), 'The answer should name the app version.');
    end;

    [Test]
    procedure HelloRefusesATooLongName()
    begin
        Caller.AssertErrorAnswer(
            Caller.Call(Enum::"Message Type ori"::"MyApp.Hello.Get", '', '{"name":"' + PadStr('', 60, 'x') + '"}'),
            'the maximum is 50');
    end;

    [Test]
    procedure DirectoryListsEveryType()
    var
        Directory: Text;
    begin
        Directory := Caller.CallRaw(Enum::"Message Type ori"::"Help.MyApp.Get", '', '');
        Assert.IsTrue(Directory.Contains('MyApp.Hello.Get'), 'MyApp.Hello.Get is missing from Help.MyApp.Get.');
        // … one line per type in the enum extension.
    end;

    [Test]
    procedure HelpHasAllElevenSections()
    var
        HelpText: Text;
    begin
        HelpText := Caller.GetHelp('MyApp.Hello.Get');
        Assert.IsTrue(HelpText.Contains('## Errors'), 'The help has no Errors section.');
        // … one line per section heading of §4.
    end;
}
```

**The selection-card lint.** An agent chooses from the card alone, so the card rules are tested like code: not empty; an `Outbound` type says `Read-only`, an `Inbound` type says `Commits` (those exact words); no `Impl`, `codeunit` or `TODO`.

```al
codeunit 50052 "My Selection Card Lint"
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
            if (Ordinal >= 50000) and (Ordinal <= 50049) then begin     // the app's own id range
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
        Assert.IsTrue(Checked >= 2, StrSubstNo('Only %1 message types were checked.', Checked));   // raise with every new type
    end;
}
```

**Build and run.**

1. Download symbols from your sandbox (Bifrost Foundation, the base app, and for the test app also Library Assert and Test Runner). Compile with CodeCop, UICop and PerTenantExtensionCop or AppSourceCop.
2. Publish the app, then the test app. Library Assert and Test Runner must be installed in the sandbox.
3. Activate the Bifröst trial once in the environment (§5.7, "Licence and quota"). Until then, every call of your app's types (including `Help.MyApp.Get`) answers "Bifrost trial has not been started", and `HelloGreetsByNameAndNamesTheApp` fails with that text.
4. Run the tests (VS Code AL test runner, or the AL Test Tool page). The tests assert English texts: run them where the default language is English, or see §5.9.
5. Call `MyApp.Hello.Get` over the API or MCP server. If `appVersion` is old, the new publish isn't live yet. Then `Help.MyApp.Get`.

**Lists.** A `List` type returns at most 100 rows. It takes an optional `maxRows` (1–100, default 100, via `GetOptionalInteger`), and answers `count` (every matching row, from `Count()`), `returned` (rows in this answer), `more` (`count > returned`) and the rows under one stable plural key (`items`, `reservations`). "Nothing found" is success with `count: 0` and an empty array. Paged reads take `skip`/`take` through the input layer the same way.

### 5.9 Language

| Step | What to do |
|---|---|
| Write | Every `Label`, `Caption` and `ToolTip` carries its Icelandic text in `Comment = '…, is-IS=…'`. The comment is a note to the translator; on its own it translates nothing. Technical tokens (type names, JSON keys, storage keys) are `Locked = true`. |
| Generate | `"features": [ "TranslationFile" ]` makes every compile write `Translations/<app name>.g.xlf`: all translatable texts in English. Never edit it. |
| Translate | Create `Translations/<app name>.is-IS.xlf`: the same units with `target-language="is-IS"` and a `<target>` for each, taken from the `is-IS=` comment. XLIFF sync tools for VS Code create and update it from the `.g.xlf`; some fill the targets from the comments. Re-sync after every change, and drop units whose source no longer exists. List the languages in `supportedLocales`. The next compile packs the translation into the `.app`. |

One unit of the `.is-IS.xlf`:

```xml
<trans-unit id="Codeunit 2581445924 - NamedType 3899500243" size-unit="char" translate="yes" xml:space="preserve">
  <source>Hello, %1! My Bifrost App is working in %2.</source>
  <target state="translated">Halló, %1! My Bifrost App virkar í %2.</target>
  <note from="Developer" annotates="general" priority="2">%1 = the name sent, or the user, %2 = company name, is-IS=Halló, %1! My Bifrost App virkar í %2.</note>
  <note from="Xliff Generator" annotates="general" priority="3">Codeunit My Hello Get Impl - NamedType GreetingTxt</note>
</trans-unit>
```

**At run time:**

- **A caller chooses the language with `lcid`:** in the API envelope (`{ "type": …, "subject": …, "lcid": 1039, "data": … }`) and as the `lcid` argument of the MCP tools. Without it, the call runs in the default language (§5.7). From AL, pass it as `WindowsLanguageId` to `EnqueueAndProcess`.
- **A text with no translation in that language comes back in English,** the Label's source text.
- **Locked pieces stay English inside a translated error.** A `Locked` example inserted with `StrSubstNo` (the three `…ExampleTok` Labels in §5.1) gives an Icelandic sentence with an English fragment. In new code, insert only language-neutral examples (`"2026-09-26"`, `2.5`, `"1896-S"`), or make the example a translatable Label of its own.
- **Help is English; errors follow `lcid`.** The use card is an English literal (never Labels), and its Errors table quotes the English texts. So the drift check of §8 (help errors against returned errors) is done with `lcid` 1033. The `lcid` 1039 break test checks that the error comes back in Icelandic, with the same parameter name and echoed value. Every help's "Formats and language" section says: error texts follow the caller's `lcid`; this document is English.

**Deterministic tests.** `Execute` runs in the tenant's default language, so an English assertion fails where Bifrost Setup or Company Information defaults to Icelandic. The repo's tests assert English fragments and run in companies whose default is English. Either do the same, assert only on language-neutral parts (the parameter name, `YYYY-MM-DD`, the echoed value), or pin English in `CallRaw` with the call `Execute` itself makes, with the language fixed. This variant is not used in the repo's tests:

```al
    var
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    …
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250), '', '', RequestContent,
            EmptyTaskId, 1033, MessageId, ResponseContent, ResponseContentType, ResponseTime, true);   // true = OmitCommit, as Execute
```

---

## 6. Where the patterns are in this repository

**Starting a new app?** §5.8 has everything. If you have this repository, `Bifrost Boilerplate/` and `Bifrost Boilerplate Tests/` are the same app ready to copy (with two more sample types, and rename steps in `Bifrost Boilerplate/README.md`). Publish, call `MyApp.Hello.Get`, then add your own types by the patterns below.

### Classify each operation, then copy the matching pattern

| The operation … | Effect | Copy |
|---|---|---|
| reads one record | Read-only | `Reference.GLAccount.Overview.Get`, `Legacy.Stock.Get` |
| reads many records | Read-only, capped with a documented maximum | `Legacy.Stock.List` (at most 100 rows, says when there are more) |
| writes one record, safe to retry | Commits | `Reference.AssetMaintenance.Create` (`externalId`) |
| changes many records, or can't be undone | Commits, guarded | `Reference.ItemPrice.PreviewAdjustment` + `ApplyAdjustment` (preview + apply), or `Legacy.Stock.List` + `Legacy.Stock.ReleaseAll` (list + release with `expectedCount`) |
| calls an external service | Read-only (internet) | `Reference.ExchangeRate.Get` |
| receives a secret | Commits | `Reference.ApiKey.Set` |

**For each write, also offer a read sibling.** An agent that can't check the state before and after a write has to guess.

### The patterns by folder

| Pattern | Message type | Folder |
|---|---|---|
| Read with resolver, FlowFields "as of" a date, nulls | `Reference.GLAccount.Overview.Get` | `Bifrost Reference/src/GLAccounts/` |
| Write, validation, isolation, safe retry | `Reference.AssetMaintenance.Create` | `Bifrost Reference/src/AssetMaintenance/` |
| Preview / apply pair | `Reference.ItemPrice.*` | `Bifrost Reference/src/Prices/` |
| HTTP, secret, setup page, install | `Reference.ExchangeRate.Get`, `Reference.ApiKey.Set` | `Bifrost Reference/src/ExchangeRates/`, `src/Lifecycle/` |
| Shared input layer (full) | – | `Bifrost Reference/src/Common/RefInput.Codeunit.al` |
| Internal headless core of an existing app | – | `Legacy App v2 (headless)/src/Logic/LegacyStockAPI.Codeunit.al` (`Legacy Stock API`, `Access = Internal`) |
| Message types in the same app, over the internal core | `Legacy.Stock.*`, `Help.Legacy.Get` | `Legacy App v2 (headless)/src/MessageTypes/` |
| Before the audit (not headless) | – | `Legacy App v1 (not headless)/src/` |
| Unit tests through `Dispatcher ori`, the selection card lint and the help sections lint | – | `Bifrost Reference Tests/` |

---

## 7. Existing apps

The worked example is `Legacy App`. Version 1 (`Legacy App v1 (not headless)`) works in the UI but hides seven audit patterns. Version 2 (`Legacy App v2 (headless)`, same app id, an upgrade) is headless inside and has message types outside: an internal core that its pages call, and `Legacy.Stock.*` message types for everyone else. See `Legacy App v2 (headless)/README.md` for the steps with screens.

### 7.1 Audit the old code first

Before any procedure becomes a core operation or a message type, go through every code path it reaches, including the subscribers of other apps, and look for the patterns below. Code that works well in the UI can still do the wrong thing when no person is there, and many of these patterns fail **silently**.

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
| **Rules that live on the page** | `OnValidate`/`OnAction` on page fields and actions, `CurrPage.SetSelectionFilter`, `CurrFieldNo` | Code never goes through the page, so these rules are skipped, and "the selected rows" does not exist. | Move the rules to the table or the core. The selection becomes an explicit list or filter parameter. |
| **Hidden context** | `WorkDate()`, `UserId()`, global variables that the page sets, `SingleInstance` codeunits | A value the page used to supply is missing, or state is left over from an earlier call in the same session. | Make it a parameter with a documented default. Don't keep state between calls. |
| **Skipped validation** | direct field assignment, `Modify(false)`, `Insert(false)` | The table's rules never run, so rows can be written that the UI would have refused. | Use `Validate` unless you have a documented reason not to. |
| **Side effects that can't be undone** | email, HTTP, file writes in the middle of a write | A rollback can't take back an email that was already sent. | Do these after the data is safe, or queue them. Make them safe to repeat. |
| **Asynchronous work** | `StartSession`, `TaskScheduler`, job queue entries | The call returns before the work is done, so "success" means only that the work was queued. | Return a clear `queued` result and add a read type that reports the status. |
| **Files and downloads** | `Download`, `UploadIntoStream`, `File.`, report `SaveAs` to a path | There is no file dialog, and nobody receives the file. | Take and return Base64 or structured JSON. |
| **Duplicates on retry** | number series in a write, `Insert` without an existence check | A caller that retries after a timeout creates a second row. | Accept an `externalId` and look it up first (see `Reference.AssetMaintenance.Create`). |
| **Unbounded work** | loops without filters, `FindSet` over whole tables, no `SetLoadFields` | Without a UI the call times out, or it locks tables for everyone else. | Filter, use `SetLoadFields`, and cap the result with a documented `maxRows` (§5.8, "Lists"). |
| **Formats that depend on the user's language** | `Format(date)`, `Evaluate` without `9` | The same call gives different results depending on the user's language settings. | Use `Format(x, 0, 9)` / `Evaluate(x, t, 9)`, and send dates as YYYY-MM-DD. |
| **UI subscribers in other apps** | *(this can't be found by searching)* | Another extension's `OnAfter…` subscriber opens a `Confirm`. | Test the type with the tenant's other apps installed. Prefer base-app entry points that support hiding dialogs. |

**Keeping `GuiAllowed`.** You don't have to remove it. Many procedures are called from both pages and code, and wrapping a message or a progress window in `if GuiAllowed() then` is a sensible way to keep one procedure for both. The test for each branch is: **with the UI switched off, would a caller get the same rules, the same writes and the same outcome?**

| Fine: only what is shown changes | Not fine: the rules change |
|---|---|
| `if GuiAllowed() then Window.Open(ProgressTxt);` | `if GuiAllowed() then if Qty > Inventory then if not Confirm(...) then exit(false);`: without a UI the check disappears, and the call over-reserves. |
| `if GuiAllowed() then Message(DoneMsg, Count);` when the count is also returned | `if not GuiAllowed() then exit;`: code callers silently get nothing. |
| `if GuiAllowed() then Notification.Send();` | `if GuiAllowed() then Validate(...) else Field := Value;`: the rules run for people only. |

When a `Confirm` guards a decision, the non-UI branch must neither skip the check nor quietly answer "yes". Make the answer a parameter with a safe default, as `AllowOverStock` does, or fail with an error that names the parameter. The core in `Legacy App` v2 has no `GuiAllowed` at all. Its UI entry points, such as `Legacy Stock Mgt.CancelReservation`, keep an unconditional `Confirm`, so they are plainly for people. Every other caller uses the message types. Don't wrap a guarding question in `if GuiAllowed() then`. Without a UI, the branch then answers "yes" for the person.

Also, `GuiAllowed` is not a reliable "is this Bifröst?" test. It is false for web services, the job queue and background sessions, and true in test pages. Never use it to switch behaviour for a particular caller.

**See it in code.** `Legacy App v1` contains seven of these patterns, each marked `AUDIT - <pattern>` in the code. `Legacy App` v2 fixes each one at a line marked `FIXED - <pattern>`, and its message types expose the result. Search v1 for `AUDIT -` and v2 for `FIXED -` to read them side by side.

| Pattern | v1 (before) | v2 core (after) | Message type (the proof) |
|---|---|---|---|
| Dialogs | `Confirm` in `CancelReservation` and the stock check; progress window and `Message` in `ReleaseAll` | The page asks; the core never does | `Legacy.Stock.CancelReservation`, `Legacy.Stock.ReleaseAll` |
| `GuiAllowed` branch | The stock check runs only when there is a UI | The check runs for every caller; the person's decision becomes the `AllowOverStock` parameter | `Legacy.Stock.Reserve` refuses over stock unless `allowOverStock: true` |
| `Commit` | Between delete and log; after every row in `ReleaseAll` | None: one transaction | A failed release leaves nothing half done |
| Swallowed errors | `if Codeunit.Run … else ClearLastError()` counts failures as "skipped" | Errors reach the caller | The error text comes back as `status = Error` |
| Silent failure | `exit(false)`, `Error('')` | Returned outcomes: new total, `cancelled`, `released` | `cancelled: false`, `released: 0` |
| Rules on the page | The reserve rules live in the page trigger | The rules live in the core | Pages and every type get the same rules |
| Unbounded work | `ReleaseAll` touches every row | `ReleaseReservations(ItemFilter)`, and the list is capped at 100 rows | `Legacy.Stock.List` (capped), `ReleaseAll` needs a filter and `expectedCount` |
| Duplicates on retry | – | – (the core adds to the reservation) | Documented as "not safe to repeat", with a read to check |

**The developer owns the audit.** Bifröst can't see inside your code. It can only run what you expose, so the audit is your part of the contract. For every message type, record the audit next to its contract (§4) and in the pull request:

```text
Audit (§7.1)   <message type>
Call path:     <core procedure> -> <what it calls, including base-app entry points>
Findings:      <pattern>: fixed | not present | accepted - <reason and what the help says about it>
Tested:        <break-set calls that prove the fixes>
```

"Accepted" is allowed, for example "not safe to repeat", but only when the help says so in words an agent will act on. A pattern you didn't look for is not "not present".

### 7.2 Make it headless: an internal core, message types in the same app (path B)

**The idea.** Every page action does two things:

1. **It talks to a person:** a dialog for input, "are you sure?", a message, the selected row.
2. **It does the work:** it checks the rules and writes the data.

An API, a job queue, another app or an AI agent needs only the work, and it can't click OK. When both are mixed in one procedure, nothing without a UI can use the app. *Headless* means the work lives in procedures that never talk to a person.

**Inside: an internal core.** Add one codeunit (`"<App> API"` or `"<App> Core"`, **`Access = Internal`**) with one procedure per operation. `Legacy Stock API` in `Legacy App v2 (headless)/src/Logic/LegacyStockAPI.Codeunit.al` is the example. It follows these rules:

- **No UI and no `Commit`.** The caller decides and owns the transaction; the core executes.
- **Check preconditions first,** and fail with translatable errors that say what to do ("Item 'X' does not exist. Check the number …"). These texts reach callers, so write them for callers.
- **Return outcomes:** the new total, or `true`/`false` for "was anything cancelled".
- **Make implicit inputs parameters:** dates, locations, the "current record".
- **Offer read procedures** (`Get…`, `Has…`, `Is…`), so callers can check state.

**Why internal.** The message types are the one public surface. A public core would be a second contract to keep stable, and callers could skip the permission gate, the message log and usage.

**Keep old callers working.** Old public procedures (in the example, `Legacy Stock Mgt`) stay as thin shells that call the core, marked `[Obsolete('Use the <App>.* message types', '<ver>')]`. They keep their contract (check first, e.g. `IsReservable`, then call). UI procedures keep their `Confirm`, then call the core. Pages ask the user, then call the core.

**Outside: message types in the same app.** Add the Foundation dependency (§5.0) and a `src/MessageTypes/` folder:

- **One message type per core operation, plus the reads.**
- **The message type checks the shape** of the input: missing, empty, type, length, format. **The core checks the business rules.** Don't duplicate them (§5.3, "Where business rules live").
- **Call writes through an isolated Process codeunit** (§5.3). The core's error texts then become the caller's errors.
- **When a type may call the core directly:** only when the procedure raises no `Error()` that the caller must see, and returns a result you can test (a Boolean, a count, a value). `Legacy.Stock.Get` reads `HasReservation` and `GetReservedQuantity` directly. `Legacy.Stock.Reserve` can't: the core raises actionable errors (unknown item, blocked item, over stock), so it runs behind `Legacy Reserve Process`. When a procedure you call directly gains an `Error()`, move it behind a Process codeunit.
- **A trimmed input layer** is enough: a cut-down copy of §5.1 with only the `Get…` procedures the types use.
- **Pass outcomes through** (`"cancelled": false`), and never answer a no-op like a real change.
- **`IsEnabled`** checks the permissions on the app's own tables. The app's permission set covers the tables and the message types.
- **Register the app** with the App Registry (§5.5), passing 0 when it has no setup page, and add one `Help.<App>.Get` directory type.
- **Help text and tests are new work.** XML docs describe an AL signature, not the JSON contract, and existing tests don't touch the JSON path.

**Ship it as an upgrade.** Same app id, a higher version (the example goes from 1.1 to 2.0). The app now requires Bifrost Foundation in every tenant that installs it. If some customers run it without Bifröst, see §7.4.

**How callers reach it:**

| Caller | How |
|---|---|
| Your own page | Asks the person (`Confirm`), then calls the internal core. Or calls its own message type (§7.3). |
| Another AL app | Calls the message type through `Dispatcher ori` (§5.7). |
| API, MCP, AI agents, Orchestrator playbooks | Call the message type. |
| A job queue | A codeunit in the app reads its parameters from the job queue entry and calls the core. From another app, it calls the message type. |

**Test without a UI.** Test every message type through `Dispatcher ori`, as a caller would. None may open a dialog. A call that would need one means the decision should be a parameter. `Legacy Adapter Tests` in `Bifrost Reference Tests/` does this for `Legacy App` v2, using message types only.

### 7.3 The UI through message types (your choice)

A page action may call the app's own message type through `Dispatcher ori.Execute`, instead of calling the core. The click then counts as usage, and it appears in the message log like any other call.

| You get | It costs |
|---|---|
| One code path for people and machines | One `Message ori` row per click |
| Every click in the message log (who, what, when) | The page needs Bifröst installed and licensed to work |
| Clicks count as usage | The caller must handle a quota or licence error |

If you do it, handle failure on the page. Catch the error or read `status = Error` from the response, and show the user a clear message ("This action is not available: <reason>. Contact your administrator."). The page must not break. The person still answers the `Confirm` first; the message type receives the decision as a parameter.

**This is the partner's decision.** Calling the internal core from the page is equally correct. The example app's pages call the core.

### 7.4 Exception: a separate adapter app (path C)

Use this only when path B is not possible:

- the same app is sold to some customers **without** Bifröst, so it can't depend on Foundation, or
- the app belongs to someone else and you can't change it.

**How.** In the app, the core becomes a **public facade** (`Access = Public`) with the rules of §7.2, plus `OnBefore…` (with `IsHandled`) and `OnAfter…` events. It has no Bifröst dependency. A **separate adapter app** depends on the app and on Foundation, and holds the message types, built exactly as in §7.2: shape checks, Process codeunits, its own trimmed input layer, `IsEnabled`, registration and `Help.<App>.Get`. Give it its own id range and a namespace such as `<Vendor>.<App>.Bifrost`. Its permission set includes the app's.

**The drawback.** The public facade is a second contract you must keep stable, and callers can use it without the message types.

**If you can't change the app,** wrap only what is already headless. For the rest, ask its owner for a facade, or implement the operation against its tables and document the risk. Record the owner app in every test run, so a problem in the underlying app reaches the team that owns it.

This repository has no adapter app. `Legacy App` v2 shows the same message types inside the app.

---

## 8. Test, and definition of done

Test in **your own BC sandbox with Bifrost Foundation installed from AppSource**, through the MCP server or the API, serially, and record the verbatim response for each call.

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
  - lcid `1039`: the error comes back in Icelandic (from your `.is-IS.xlf`, §5.9), with the same parameter name and echoed value
- a selection check: three realistic user phrasings, one with a synonym, and whether `find_message_types` finds the type or a fresh agent picks it over its siblings
- that `get_message_type_help` returns error texts matching what the calls returned, with the calls made in English (`lcid` 1033): the help is English

Before the first run, activate the Bifröst trial in the sandbox (§5.7, "Licence and quota").

**Done when:**

- [ ] The contract is filled in. The description is ≤ 250 characters and names the effect and the sibling boundary.
- [ ] For an existing app: the §7.1 audit was run on the whole call path, and every finding is fixed or documented.
- [ ] The type is headless: no UI, no `Commit`, isolated writes, `Omit Commit` honoured, nothing written before the isolated run.
- [ ] All input goes through the input layer, and the four error kinds are distinct.
- [ ] The help has all 11 sections, and its errors are copied from the Labels.
- [ ] `IsEnabled` checks permissions, the direction is correct, secrets are redacted, and there is no silent success.
- [ ] It compiles with 0 errors (CodeCop, UICop, PerTenantExtensionCop or AppSourceCop).
- [ ] The break set passes live.
- [ ] `Help.<App>.Get` lists the type.

## 9. How the agent should work

1. Ask which path (A/B/C, §2) and which operations to expose. For path B, run the audit (§7.1) first and report the findings.
2. Draft the contract (§4) for each type and get the user's approval.
3. Implement by copying §5. Don't invent other patterns.
4. Compile, fix, and ask the user to publish to their own BC sandbox (Bifrost Foundation installed from AppSource).
5. Run §8 and report each result with the verbatim response.

## 10. Next patterns

### Chaining types into workflows (Bifrost Orchestrator)

If the tenant has **Bifrost Orchestrator**, a type that follows this contract can be a step in a playbook as it is:

- report "nothing to do" as success with a count
- keep arrays under one stable key
- guard every bulk write with a value from an earlier read

See `Bifrost Reference Playbooks/`, which builds on the Orchestrator and on the apps in this repo.

### Metering your own types (advanced)

Foundation calls the public `Msg Metering ori` hook after every successful call. By default it does nothing. To record calls of your own types, implement the hook and name it on your enum values. See the cheat sheet (§5.7) for the signature and the rules. Most apps never need it.

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
| **Metering your own types** (advanced) | Count or record calls of your own types, for example for your own reporting | Implement the public `Msg Metering ori` hook for your own types only. See the cheat sheet (§5.7). | Changing the response in the hook, or metering types that aren't yours. |
| **Take-over from an older app** | Move data from your pre-Bifröst app | Probe first, then copy. Idempotent and re-runnable. No `Commit` in install. Log each step. | A one-shot install that can't be repaired. |
