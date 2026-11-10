# Bifröst: reference implementation for partners

**Message types are your app's public API: headless inside, message types outside.**

Business Central extensions that show how to build on Bifröst Foundation 28.0.2. Each operation is a *message type*: an enum value plus one codeunit that runs the call, helps an agent find it, and describes how to call it. Integrations, MCP hosts, AI agents and Orchestrator playbooks call it the same way. Product documentation: <https://docs.bifrost.origo.is>.

## Learn it in four steps

| # | Read | What it teaches |
|---|---|---|
| 1 | `MyApp.Hello.Get` in `Bifrost Boilerplate/src/MessageTypes/MyHelloGetImpl.Codeunit.al` | **Copy this to start.** The whole shape of one message type: the three interfaces, the contract chapters, and the first call to make after every publish. |
| 2 | `Reference.Note.Add` in `Bifrost Reference/src/MessageTypes/RefNoteAddImpl.Codeunit.al` + `RefNoteAddProcess.Codeunit.al` | **A write.** The write runs in an isolated sub-codeunit (`TableNo = "Message Argument ori"`) through `Ref Input.RunIsolated`, so a failure comes back as `status = Error` instead of breaking the call. |
| 3 | `Reference.ItemPrice.PreviewAdjustment` / `Reference.ItemPrice.ApplyAdjustment` in `Bifrost Reference/src/Prices/` | **The safety pattern.** A read-only preview, then an apply that requires the preview's `itemCount` back as `expectedItemCount` and refuses if the selection changed. Apply declares `"effect": "irreversible"`. Both share `Ref Price Adjust`, so they can never disagree. |
| 4 | `Legacy App v1 (not headless)` → `Legacy App v2 (headless)` | **Retrofitting an existing app.** v1 works in the UI but hides seven problems (`AUDIT -` in the code). v2, an upgrade with the same app id, moves the logic into an internal headless core and adds `Legacy.Stock.*` message types (`FIXED -`). See [ADAPTING.md](ADAPTING.md). |

Then build your own with [BUILDING.md](BUILDING.md).

### Extras

| Type | Pattern it shows |
|---|---|
| `Reference.Echo.Get` | The smallest possible type: returns the request with `serverTime` added. |
| `Reference.Table.Get` | A read whose "not found" is a `RespondWithError` answer. |
| `Reference.GLAccount.Overview.Get` | Resolving a record from `subject` ("not given" vs "not found"), FlowFields as of a date, `null` instead of 0, enums by name. |
| `Reference.AssetMaintenance.Create` | Validate every input before any write; business-rule errors that say what to do; safe retry with `externalId`. |
| `Reference.ExchangeRate.Get` + `Reference.ApiKey.Set` | Outbound HTTP in a TryFunction with an optional key; receiving a secret as `SecretText` into `Secret Store ori` with `RedactRequestData()`. |
| `Help.MyApp.Get`, `Help.Reference.Get`, `Help.Legacy.Get` | The app's directory: one per capability, listing its types. |
| `Legacy.Stock.List` + `Legacy.Stock.ReleaseAll` | Look, then act: a capped list whose `count` is the `expectedCount` guard of an all-or-nothing bulk release. |

## The apps

| Folder | App (version) | Role |
|---|---|---|
| `Bifrost Boilerplate` + `Bifrost Boilerplate Tests` | My Bifrost App 1.0.0.0 | The template: Hello World, one read, one capped list, the directory type, registration, permission set, tests. Rename steps in `Bifrost Boilerplate/README.md`. |
| `Bifrost Reference` | Bifrost Reference 1.2.0.0 | A new app built on Bifröst: the ten `Reference.*` / `Help.Reference.Get` types, setup page, install codeunit. |
| `Legacy App v1 (not headless)` | Legacy App 2.1.0.0 | The "before". No Bifröst dependency. |
| `Legacy App v2 (headless)` | Legacy App 2.2.0.0 (same app id) | The "after": internal core, six `Legacy.Stock.*` / `Help.Legacy.Get` types. |
| `Bifrost Reference Tests` | Bifrost Reference Tests 1.0.0.0 | Tests for Bifrost Reference and Legacy App v2, through `Dispatcher ori` only, plus the selection-card and contract lints. |
| `Bifrost Reference Playbooks` | (no app) | `REF-RELEASE`, a Bifrost Orchestrator playbook chaining `Legacy.Stock.List` into `Legacy.Stock.ReleaseAll`. Needs Bifrost Orchestrator. |

Agent skills: `skills/bifrost-build/SKILL.md` (build or retrofit an app) and `skills/bifrost-playbooks/SKILL.md` (build and test playbooks by conversation).

## Object ID ranges

From each `app.json`. Illustration only: **never reuse them** for a real extension.

| App | Range |
|---|---|
| `Bifrost Boilerplate` / `Bifrost Boilerplate Tests` | 50000–50049 / 50050–50099 (placeholders you replace) |
| `Bifrost Reference` | 90000–90049 |
| `Legacy App` v1 | 90050–90099 |
| `Legacy App` v2 | 90050–90099 (core) and 90100–90149 (message types) |
| `Bifrost Reference Tests` | 90150–90199 |

For your own app use 50000–99999 (per-tenant extension) or your AppSource range from Partner Center. Never reuse the ranges of Bifrost Foundation or any other published app.

## Build and test

**You need:** a Business Central **sandbox** with Bifrost Foundation from AppSource (trial activated), VS Code with the AL extension, Microsoft's **Library Assert** and **Test Runner** for the tests, and the **BIFROST API ori** permission set plus each app's own set (**MY BIFROST APP**, **BIFROST REFERENCE**, **LEGACY STOCK**).

1. Open `bifrost-reference.code-workspace`. Its folders are in publish order.
2. In each app folder, add a `.vscode/launch.json` for your sandbox (git-ignored) and run **AL: Download symbols**.
3. Publish with `Ctrl+F5`:
   - Template only: `Bifrost Boilerplate`, then `Bifrost Boilerplate Tests`.
   - Demo: `Legacy App v1` (optional, only to see the "before"), `Legacy App v2` (an upgrade of v1), `Bifrost Reference`, `Bifrost Reference Tests`.
   - To replay the demo, uninstall and unpublish `Bifrost Reference Tests` and `Legacy App` first: BC won't install a lower version over a higher one.
4. For `Reference.ExchangeRate.Get` only: allow outbound HTTP for Bifrost Reference in the Bifrost Setup wizard.
5. Run the tests from page **AL Test Tool** (130451): codeunits 50051–50054 (Boilerplate) or 90151–90155 (Reference). See `Bifrost Reference Tests/README.md`.
6. Call `MyApp.Hello.Get` over the Bifröst API or MCP server. If `appVersion` is the one you just published, the app is live.

**CI:** the workflows in `.github/` build `Bifrost Reference`, `Legacy App v2 (headless)` and `Bifrost Reference Tests` (see `.AL-Go/settings.json`). Foundation's symbols come from repository settings, so a fork won't find them; build in your sandbox, or give AL-Go your own source for Foundation's `.app`.

## How an agent picks and uses your operation

1. **Find.** The agent searches by words. It matches the type name, `GetDescription()` (the selection card, at most 250 characters, saying "Read-only" or "Commits") and `GetKeywords()` (the words people say, as a translatable Label). `GetSelectionDescription()` tells it what the type is *not* for and which sibling to use instead.
2. **Read.** Before calling, it reads the contract. `Help.Implementation.Get` (MCP: `get_message_type_help`) returns the chapters as JSON: overview, envelope, target, parameters, response, errors, effect, metering, related, workflow, examples, notes. Errors quote the real Label texts.
3. **Decide.** The `effect` chapter says `read`, `write` or `irreversible`, whether a repeat is safe, and the preconditions. Preconditions describe what `IsEnabled()` checks. `IsEnabled()` hides a type from users who can't use it; it doesn't block a direct call, so the type's own code and table permissions still decide what a call may do.
4. **Chain.** `workflow` and `related` say what comes before and after, for example the preview before an apply.
5. **Secrets never travel through an AI chat.** People enter API keys in **Bifrost Setup > Apps**. A type that receives a secret, such as `Reference.ApiKey.Set`, is for integrations and redacts the request from the log.

## Guides

| File | For |
|---|---|
| [BUILDING.md](BUILDING.md) | Adding a new operation: rules, contract chapters, code patterns, Foundation API, tests, definition of done. |
| [ADAPTING.md](ADAPTING.md) | Making an existing app callable: the audit, the internal core, the adapter-app exception. |
| [INTEGRATING.md](INTEGRATING.md) | Calling message types from outside BC or from AL. |
| [AGENTS.md](AGENTS.md) | Instructions for coding agents in this repository. |

## Licence and trademarks

The code and documentation are licensed under the [MIT License](LICENSE). Copy the samples into your own apps, commercial ones included. The licence does not cover Bifrost Foundation or any other Origo app (never commit their symbols; `.gitignore` excludes `.alpackages/` and `*.app`), nor the names and logos "Bifröst" and "Origo", which are trademarks of Origo ehf. You may say your app works with Bifröst, but not suggest it is made or endorsed by Origo.

The only external call in this repository is `Reference.ExchangeRate.Get`, which uses a free public ECB rates service.
