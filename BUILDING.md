# Building a new operation

How to add a message type to a new or existing app. Start by copying `MyApp.Hello.Get` (`Bifrost Boilerplate/src/MessageTypes/MyHelloGetImpl.Codeunit.al`). For an existing app with logic in pages and dialogs, read [ADAPTING.md](ADAPTING.md) first.

## What a good operation is

Before the mechanics: an operation is a promise to someone you will never meet, an AI agent acting for a person who asked in their own words. A good one keeps that promise without anyone explaining it:

1. **One intent.** It does one thing a person would ask for, in their words: "what would +5 % do to chairs", not "update item fields". If two people would describe it differently, it may be two operations.
2. **Found for the right question, and only for it.** Its name, keywords and selection text match how people ask, and say which sibling to use instead.
3. **Understood without the code.** Its use card says what to send, what comes back and what can go wrong, with real examples. The agent has nothing else.
4. **Honest about consequences.** It says whether it reads, writes or can't be undone, and whether a repeat is safe, so the agent knows when to ask the person first.
5. **Safe by construction.** Anything irreversible comes in two steps, and the second needs proof that the first was seen. It runs headless, inside Business Central's own logic and permissions.
6. **Recoverable.** Every refusal says what was wrong and what to do next, so the agent can correct itself instead of guessing or giving up.
7. **Predictable.** The same input gives the same shape of answer, in every language, with no silent success.

The rest of this guide is how to build each of these. The test of all seven is the same: ask a fresh agent in plain words, and watch whether it picks your operation, uses it correctly the first time, and asks before anything it can't undo.

**Read the real Foundation symbols before you write code. Never guess a signature.** Everything here is checked against Bifrost Foundation 28.0.2 and the apps in this repository.

## 1. One type = one enum value + one codeunit

```al
enumextension 50000 "My Msg Type" extends "Message Type ori"
{
    value(50003; "MyApp.Hello.Get")
    {
        Caption = 'MyApp.Hello.Get', Locked = true;
        Implementation = "Msg Interface ori" = "My Hello Get Impl", "Msg Discovery ori" = "My Hello Get Impl", "Msg Contract ori" = "My Hello Get Impl";
    }
}
```

The caption is `Locked`: callers in every language send the same string. Value ids come from your own range; never renumber a published value. The codeunit is `Access = Internal` and implements:

| Interface | Procedures | Purpose |
|---|---|---|
| `Msg Interface ori` | `IsEnabled`, `GetFilterTableNo`, `GetDescription`, `GetMessageDirection`, `ExecuteBifrostTask` | Runs the call. `IsEnabled` controls visibility only (see rule 10). |
| `Msg Discovery ori` | `GetKeywords`, `GetSelectionDescription` | Helps an agent find it. Both return translatable Labels (`Comment = 'is-IS=…'`), never `Locked`. |
| `Msg Contract ori` | 12 chapter procedures (section 4) | The use card an agent reads before calling. |

## 2. Name and effect

Name types `Capability.Entity.Verb` in words a user would say. The name is the strongest search signal.

- **Capability:** your app's product area, one word, **yours alone**. Never add types to someone else's (`Sales`, `Data`, `Help`, `Document`, `Reference`, `Legacy` …). Two extensions can't add the same enum value name; check `Help.MessageTypes.Get` in your sandbox first.
- **Entity:** the business object, singular. Keep names to three parts, `Capability.Entity.Verb`; put any qualifier in the entity word or a parameter. A filter is a parameter, not part of the name. (Two sample types still have four parts; see issue #4.)
- **Verb:** the promise. A `Get` that writes is a bug.

| Verb | Direction | `effect` | Meaning |
|---|---|---|---|
| `Get`, `List`, `Preview…` | Outbound | `read` | One answer / many rows, capped / a change computed but not made. |
| `Create`, `Add`, `Set`, `Reserve`, `Release`, `Cancel` | Inbound | `write` | A new record (make it safe to retry with `externalId`), a line or note, an overwrite, a hold, an undo (safe to repeat). |
| `Apply…`, `ReleaseAll`, `Post` | Inbound | `irreversible` | Carries out a preview; bulk changes; posting. |

The directory type is `Help.<Capability>.Get`, one per capability you own (`Help.MyApp.Get`).

## 3. The rules

Each comes from a failure in live agent testing.

**Headless**
1. No UI in the execution path: no `Confirm`, `Message`, `StrMenu`, `Page.Run`, request pages. A decision a person would make becomes a parameter with a documented default.
2. No `Commit`. Foundation owns the transaction.
3. Writes run isolated, in a codeunit with `TableNo = "Message Argument ori"` (section 5).
4. Write nothing before the isolated run: inside an open write transaction `Codeunit.Run` can't return a value.

**Input and errors**

5. Every failure is `status = Error` with a message that says what to do next. No raw platform error reaches the caller.
6. Keep four answers apart: *missing*, *not found* (echo the value), *wrong type*, *wrong format*.
7. Dates are ISO `YYYY-MM-DD` only (`26.09.2026` is refused, never guessed). Numbers use a dot. In responses: JSON numbers, `null` for "no value" (never `0`), enums by name.
8. Error texts are translatable Labels. Read every parameter through one shared input layer (`My Input`, `Ref Input`).

**Honesty and safety**

9. No silent success: report what happened (`"created": false`, `"cancelled": false`).
10. `IsEnabled()` checks the exact permissions the type needs, and **controls visibility only**: a type it hides is not listed, but a direct call still runs, and Business Central table permissions still apply. Enforce any further rule inside `ExecuteBifrostTask`. Direction is `Outbound` for reads, `Inbound` for anything that writes.
11. A read never inserts setup; use defaults in memory (`GetOrDefault` in `Bifrost Reference/src/ExchangeRates/RefSetup.Table.al`).
12. Irreversible or bulk changes come as a pair: a read-only preview, and an apply that requires a value from it.
13. Secrets are `SecretText` and live only in `Secret Store ori`. A type that receives one calls `Argument.RedactRequestData()` on every path, after its isolated write. People enter keys in **Bifrost Setup > Apps**, never through an AI chat.

**Platform**

14. Register the app with `App Registry ori`, even without a setup page (pass 0), so the Bifrost Setup wizard can switch on outbound HTTP for it.
15. At most one action on Foundation's `Setup ori` page; your settings live on your own page. No HTTP, credential or setup notifications of your own.
16. Descriptions, contract text and errors are shown to every caller: keep personal data out. Request bodies are kept in the message log: send and store only what the type needs.

**Permissions and data**

17. An agent can do everything the user it runs as can do. Design every type for the narrowest access that does the job: read only what the answer needs, write only what the task changes.
18. Ship your own permission set for your tables and objects, as narrow as possible, and never include Foundation's sets in it. Customers combine it with `BIFROST API ori`.
19. Be careful with `InherentPermissions` and indirect permissions on your objects: they let a call do more than the user could, and an agent will use that. Use them only where the task requires it, and say so in the `effect` chapter.
20. Bifrost Field Access applies to Foundation's generic readers (Data, CSV, Deleted, ChangeLog). A response your code builds itself is not filtered: return only the fields the task needs, and leave personal data (names of people, contact details, identity and bank numbers) out unless the task is about them.
21. Your app's tables are not in Foundation's default protections. Tell customers which of your tables and fields hold personal or sensitive data, so they can classify them and set Field Access for agent users.

## 4. The contract

Write it **before** the code. An agent uses it at two moments:

- **Choosing** among hundreds of types, it sees the name, `GetDescription()` and the discovery texts. The description is at most 250 characters: `[Verb] [object] [what you get]. [Read-only | Commits]. [Not for X – use Sibling.]`. No codeunit names, no jargon.
- **Calling**, it reads the contract chapters through `Help.Implementation.Get`. The tool schema an agent gets is generic (`type`, `subject`, a request string), so the contract is the only schema it has.

Each chapter is one procedure. Return `true` when you fill it, `false` when it doesn't apply ("chapter not declared"). Chapter text is English. Build entries with `"Msg Contract Mgt ori"` so the shape always matches.

| Chapter | Procedure | Content | Helper |
|---|---|---|---|
| overview* | `GetOverview(var Text)` | What it does, when to use it, when not. | |
| envelope* | `GetEnvelope(var JsonObject)` | `subject.use` (`required` / `optional` / `notUsed`), `dataRequired`, `version`, `contentType`. | |
| target | `GetTarget(var JsonArray)` | How the record is found, in resolution order (subject SystemId, subject No., body key). | `TargetEntry` |
| parameters | `GetParameters(var JsonArray)` | Name, JSON type, required, description (format, range, default). | `Parameter` |
| response* | `GetResponse(var JsonObject)` | `contentType` and `fields`; what "nothing happened" looks like. | `ResponseField` |
| errors* | `GetErrors(var JsonArray)` | Every error, verbatim from its Label with `{placeholders}` for `%1`; when; fix. | `TextErrorEntry`, `ErrorEntry` |
| effect* | `GetEffect(var JsonObject)` | `read` / `write` / `irreversible`, `changes`, `idempotent`, `preconditions` (= what `IsEnabled` checks, plus status and setup). | |
| metering | `GetMetering(var JsonObject)` | Your own meters only. Foundation always adds whether the call is charged. | |
| related | `GetRelated(var JsonArray)` | Siblings and when to use them instead. Names must exist. | `RelatedEntry` |
| workflow | `GetWorkflow(var JsonObject)` | Steps before and after (`preview` → `apply`). Names must exist. | `WorkflowStep` |
| examples* | `GetExamples(var JsonArray)` | Runnable requests with real responses, including one error. | `Example` |
| notes | `GetNotes(var Text)` | Repeat safety, language, edge cases. | |

\* Required: the contract lints (`My Contract Lint`, `Help Sections Lint`) fail without them.

**Answer the repeat question.** Safe (`Legacy.Stock.CancelReservation` answers `cancelled: false`), fails on repeat (`Reference.Note.Add` refuses an existing `no`; after a timeout treat that as "the first call went through"), or repeat has an effect (`Legacy.Stock.Reserve` reserves twice; check with `Legacy.Stock.Get`).

**Change a Label and its `errors` entry in the same commit.** Callers match on the text.

**Check it:** write three ways a user would ask, one with a synonym, and see whether `find_message_types` ranks the type first. Give a fresh agent only the contract and a plain request: does it produce the working call?

### Writing a use card the agent gets right

The agent never sees your code. It sees the name, the selection texts and the contract, and it decides from them which operation to call, what to send, and whether to ask the user first. A good card is what makes an agent use your operation correctly and safely without anyone writing a prompt for it. A vague card makes it pick the wrong operation, or call the right one wrongly.

| Part | Write it so the agent can… | Weak | Strong (from this repo) |
|---|---|---|---|
| Keywords | match the user's own words | `item price adjustment` | "what if prices go up, simulate price increase, show new prices for a category", and the same in each language you ship |
| Selection description | tell this type from its siblings | "Adjusts prices." | "See what a percentage change would do … without changing anything. To make the change, use `Reference.ItemPrice.ApplyAdjustment` with this answer's itemCount." |
| Overview | decide in one reading | a list of fields | what it does, when to use it, **when not to** |
| Effect | decide whether to ask before calling | `write` on everything | `read` for the preview, `irreversible` for the apply, with `changes` saying exactly what is modified |
| Preconditions | predict a refusal | missing | the same permissions `IsEnabled` checks, plus required status and setup |
| Workflow | call in the right order | missing | preview → apply, and what to carry from one to the other |
| Errors | correct itself without asking you | "Invalid input." | the exact text it will receive, when it happens, and the fix |
| Examples | copy a working call | an invented request | a real request and the response it actually returned, plus one error |
| Notes | handle repeats and edge cases | missing | repeat safety, language, limits, and anything an agent must never do (for example: never ask a person to paste a key into a chat) |

Three habits that matter most:

1. **Say what it is not for.** Most wrong picks happen between siblings. Name the sibling and when to use it instead, in both the selection description and `related`.
2. **Be honest about the effect.** An agent asks before an `irreversible` call and usually doesn't before a `read`. Calling a write `read` removes that pause.
3. **Copy errors from the Labels, never paraphrase.** The agent matches the text it receives against the card. When they differ, it guesses.

Test the card the way it is used: ask a fresh agent in plain words, with no type names, and watch whether it picks the type, reads the card, and calls it correctly the first time. If it doesn't, change the card before the code.

## 5. Code patterns

| Need | Copy |
|---|---|
| Shared input layer: required/optional text, ISO dates, numbers with ranges, booleans, record resolvers, `RunIsolated` | `Bifrost Boilerplate/src/Common/MyInput.Codeunit.al` (or the fuller `Bifrost Reference/src/Common/RefInput.Codeunit.al`) |
| A read of one record | `MyApp.Item.Summary.Get`, `Reference.GLAccount.Overview.Get` |
| A capped list (`count`, `returned`, `more`) | `MyApp.Item.List`, `Legacy.Stock.List` |
| A write in an isolated sub-codeunit | `Reference.Note.Add` (`RefNoteAddProcess.Codeunit.al`) |
| Validation before write, safe retry with `externalId` | `Reference.AssetMaintenance.Create` (`Bifrost Reference/src/AssetMaintenance/`) |
| Preview / apply | `Reference.ItemPrice.*` (`Bifrost Reference/src/Prices/`) |
| Outbound HTTP, secret, setup page, install | `Reference.ExchangeRate.Get`, `Reference.ApiKey.Set`, `Bifrost Reference/src/Lifecycle/` |
| Registration and the one Bifrost Setup action | `MyRegistration.Codeunit.al`, `RefSetupAction.PageExt.al` |

**Every `ExecuteBifrostTask`** starts with `Argument.AssertVersion1(); Argument.AssertIsLicensed();` (directory `Help.*` types skip the licence check), reads input with `if not MyInput.Get…(…) then exit;` (the input layer has already answered the error), and ends with `Argument.SetResponseJson(…)`.

**Where business rules live.** The *core* (an internal codeunit) owns business rules and the write, and fails with `Error()` and a translatable Label. The *Impl* owns the shape of the input and resolving the target, and answers with `RespondWithError` + `exit`. The *Process* codeunit runs the core's write isolated. Don't copy a core rule into the Impl. Over the API a core error comes back as `status = Error`; through `Dispatcher ori.Execute` (`Omit Commit` = true) it is raised out of the call.

**Reads:** `SetLoadFields` before resolving. For FlowFields as of a date, set `"Date Filter"` and use fields that honour it (`"Balance at Date"`, `"Net Change"`; `Balance` ignores it).

**Preview / apply:** the preview returns a count (or hash) of the selection; the apply requires it back and refuses with "the selection changed … run the preview again". Both use one shared codeunit for selection and calculation. Each description names the other.

**Outbound HTTP:** wrap `HttpClient.Send` in a `[TryFunction]`. On failure, say how to enable HTTP for the app in the Bifrost Setup wizard. Check the status code and the JSON shape, each with its own message.

## 6. Foundation API essentials

**`Message Argument ori`** (temporary record): `Subject`, `"Omit Commit"`, `Type`, `Source`, `ID`.

| Use | Procedure |
|---|---|
| Read | `GetRequestJson()` (wrap in a `[TryFunction]`: a non-object body raises), `SubjectIsGuid()` |
| Answer | `SetResponseJson(JsonObject)`, `SetResponseMarkdown(Text)`, `SetResponsePdf(var Temp Blob)` |
| Errors | `RespondWithError(Text)` → `{"status":"Error","error":…,"hint":…}`. The hint points the caller to `Help.Implementation.Get`. |
| Guards | `AssertVersion1()`, `AssertIsLicensed()` |
| Secrets | `RedactRequestData()` replaces the stored request with `{"redacted":true}` |

A success answer has no `status` field. Read `skip`/`take` with your input layer.

**`Dispatcher ori`:** `Execute(…)` (8 parameters, `OmitCommit` = true; 9 with the flag) and `EnqueueAndProcess(…)` (adds Task Id, language, message id, response time; `OmitCommit` = false). Every overload writes a `Message ori` row and runs the full pipeline. Pass only the `data` object as `RequestContent`. `Execute` runs in the default language (Bifrost Setup, then Company Information, then 1033); pass `WindowsLanguageId` to `EnqueueAndProcess` to choose. See [INTEGRATING.md](INTEGRATING.md).

**Before the first call:** someone must approve the Terms of Use in the Bifrost Setup wizard. Until then every call answers `"code": "EULA_REQUIRED"` ("EULA approval is required before Bifrost calls can be processed."). Then the trial must be started in Bifrost Setup; until it is, calls to your types answer "Bifrost trial has not been started", and tests fail with that text.

**`App Registry ori`:** subscribe to `OnRegisterApps` and call `AddApp(Apps, AppInfo.Id(), AppName, SetupPageId)`.

**`Secret Store ori`:** `Register` (in the install codeunit), `Set`, `TryGet` (in a `[NonDebuggable]` procedure), `IsSet`, `Clear`, `Unregister`. `SecretCode` is `Code[50]`, `AppId` is your module id.

**`Msg Metering ori`** (optional): `OnMessageCompleted` runs after each successful call of your type, for your own meters. It never changes the response.

**Permission sets:** assign `BIFROST API ori` (callers) next to your own set; `BIFROST Full ori` for administrators. Don't include Foundation's sets in yours.

## 7. Language

Every `Label`, `Caption` and `ToolTip` carries `Comment = '…, is-IS=…'`; technical tokens (type names, JSON keys) are `Locked = true`. The comment translates nothing on its own: `"features": ["TranslationFile"]` generates `Translations/<app>.g.xlf`, and you maintain `Translations/<app>.is-IS.xlf` from it (XLIFF sync tools fill targets from the comments). Callers choose the language with `lcid`; untranslated texts come back in English. Contract chapters are English; errors follow `lcid`.

Tests assert English fragments, so run them in a company whose default language is English, or assert on language-neutral parts (parameter name, `YYYY-MM-DD`, the echoed value).

## 8. Test, and definition of done

**Unit tests** go through `Dispatcher ori`, never an Impl: copy `My Test Caller` / `Ref Test Caller` (`Call`, `AssertOk`, `AssertErrorAnswer`, `GetText` …). Input errors come back as `status = Error`; core errors inside the isolated write are raised (`asserterror` + `Assert.ExpectedError`). Keep the two lints (selection card, contract chapters) and raise their `ExpectedTypes` with each new type.

**Live test** each type in your sandbox through the MCP server or API, one call at a time, keeping the verbatim response:

- one happy path;
- the break set: target missing, target not found, wrong JSON type (`{"a":1}` where text is expected), date `26.09.2026`, number out of range, text too long, a repeat call, `lcid` 1039;
- the contract: `get_message_type_help` errors match what the calls returned (with `lcid` 1033);
- selection: three user phrasings in `find_message_types`; note the rank.

**Done when:**

- [ ] Description ≤ 250 characters, states the effect and the sibling boundary; keywords and selection description are translatable Labels.
- [ ] Required chapters filled; errors verbatim from the Labels; preconditions match `IsEnabled`.
- [ ] Headless: no UI, no `Commit`, isolated writes, nothing written before the isolated run.
- [ ] All input through the input layer; the four error kinds are distinct; no silent success.
- [ ] Direction correct, secrets redacted, app registered, `Help.<Capability>.Get` lists the type.
- [ ] Narrow permission set shipped; no inherent or indirect permission the task doesn't need; responses carry no personal data the task doesn't need; your sensitive tables and fields are listed for customers.
- [ ] Compiles with 0 errors and 0 warnings under CodeCop, UICop and PerTenantExtensionCop. For AppSource, first set your own ID range, logo and help URL in `app.json`; the samples use per-tenant ranges and fail AppSourceCop as shipped.
- [ ] Unit tests and lints pass; the break set passes live.

## 9. Shipping your app

- **It is a normal Business Central app** that depends on Bifrost Foundation. Publish it the way you publish your other apps (AppSource or per-tenant). Foundation itself comes from AppSource.
- **Object IDs:** use your own registered range. The ranges in this repository are illustrative only and must never be reused.
- **Customers install and set up Foundation first**, then your app. Its operations join the same catalogue the day it is installed, and every connected assistant and integration can use them. Your app needs no setup step of its own in Bifröst beyond registering it (rule 14).
- **Permissions:** ship your own permission set for your tables and objects; customers combine it with `BIFROST API ori`. Your `IsEnabled` decides who sees each type; table permissions and checks in your code decide what a call may do.
- **Usage:** a successful call of your type is counted as a message, like any other operation. Use `Msg Metering ori` only for meters of your own.
- **Customer-facing documentation** for your app (what it adds, setup, permissions) is yours to write. Keep operation details in the contract, where agents read them.

## 10. Further patterns

- **Playbooks:** a type that reports "nothing to do" as success with a count, keeps arrays under one stable key, and guards bulk writes with a value from an earlier read works as a Bifrost Orchestrator step as it is. See `Bifrost Reference Playbooks/`.
- **Document with lines:** validate header and every line first; one isolated Process for all; return the numbers. Don't write lines through `Data.Records.Set`.
- **Long-running work:** enqueue, return an id, add a `…Status.Get` type.
- **Posting:** a preview or check type paired with `Post` (`irreversible`), with base-app dialogs hidden.
- **Delta sync:** a read filtered on `SystemModifiedAt`, paged with skip/take.
