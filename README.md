# Bifröst: reference implementation for partners

**Message types are your app's public API: headless inside, message types outside.**

Business Central extensions that show how to build on
Bifröst Foundation ([documentation](https://businesscentralal.github.io/bifrost/)). They cover:

- a new app whose operations are message types that agents and integrations can call
- an existing app made headless inside, with message types outside, in the same app

The patterns come from live testing of message types with AI agents and follow Foundation's public API.

## What you need

- A Business Central **sandbox** with **Bifrost Foundation** installed from AppSource, and its licence or trial activated
- **VS Code** with the AL extension
- For the unit tests, Microsoft's **Library Assert** and **Test Runner** in the same sandbox
- Your user needs the **`BIFROST API ori`** permission set, plus each app's own set

## Quick start: your first Bifröst app in 15 minutes

1. Clone the repository and open `bifrost-reference.code-workspace` in VS Code.
2. In `Bifrost Boilerplate`, set `launch.json` to your sandbox, run **AL: Download symbols**, and publish.
3. Call `MyApp.Hello.Get` over the Bifröst API or MCP server. An answer such as "Hello, … My Bifrost App is working in …" proves the whole path works.
4. Copy `Bifrost Boilerplate` and `Bifrost Boilerplate Tests` into your own repository and follow the rename checklist in `Bifrost Boilerplate/README.md`.
5. Add your own message types with [`START-HERE.md`](START-HERE.md), or hand it to your coding agent together with the skill `skills/bifrost-build`.

## Start here

| You are … | Read |
|---|---|
| **Building anything**, alone or with a coding agent | [`START-HERE.md`](START-HERE.md), the one file to read. Why message types, the paths (new app, existing app, the adapter exception), the rules, the contract, the code patterns and the definition of done. |
| Building and testing the examples | [`TESTING.md`](TESTING.md) |
| Calling Bifröst from outside BC, or from AL | [`INTEGRATING.md`](INTEGRATING.md) |
| A coding agent working in this repository | [`AGENTS.md`](AGENTS.md) (points to `START-HERE.md`) |

To see what "headless" means, with screens, read [`Legacy App v2 (headless)/README.md`](Legacy%20App%20v2%20(headless)/README.md).

## The demo in three publishes, plus tests

| # | Publish | A person sees | An AI agent can |
|---|---|---|---|
| 1 | `Legacy App v1 (not headless)`: **before** | A working app: reserve, cancel, release all | read its table, nothing more. It has no actions to call, and generic writes are blocked. Seven audit patterns hide in the code (`AUDIT -`). |
| 2 | `Legacy App v2 (headless)` (same app id, an upgrade): **headless inside, message types outside** | The same app, with the same questions asked in the same places | reserve (refused over stock unless allowed), cancel, check, list and release through `Legacy.Stock.*`, with the same rules a person gets. Each pattern is fixed (`FIXED -`). |
| 3 | `Bifrost Reference`: **a new app built on Bifröst** | Setup page, asset maintenance log | everything in the table below |
| + | `Bifrost Reference Tests` | – | – (unit tests for 2 and 3, through message types only) |

Open `bifrost-reference.code-workspace`; its folders are in publish order, with `Bifrost Reference Tests` fourth. Publish 1 → 2 is an upgrade (same app id). To run the demo again from the start, uninstall and unpublish `Bifrost Reference Tests` and `Legacy App` first, because BC refuses to install a lower version over a higher one. See `Legacy App v1 (not headless)/README.md` and `Legacy App v2 (headless)/README.md` for what changes at each step.

## The apps

### Bifrost Reference

A new app built on Bifröst. Each message type teaches one pattern:

| Message type | Effect | Pattern |
|---|---|---|
| `Reference.GLAccount.Overview.Get` | Read-only | Resolve a record from `subject`, keeping "not given" and "not found" apart. `SetLoadFields`, FlowFields "as of" a date (balance at a date, net change for a period), `null` instead of 0, enums by name. |
| `Reference.AssetMaintenance.Create` | Commits | Validate every input before any write. Business rules with actionable errors. Isolated write. Safe retry with `externalId`. |
| `Reference.ItemPrice.PreviewAdjustment` / `ApplyAdjustment` | Read-only / Commits | A preview/apply pair for an irreversible bulk change. Apply is guarded by the preview's `itemCount`. |
| `Reference.ExchangeRate.Get` | Read-only (internet) | Outbound HTTP in a TryFunction, an optional secret in the header, defensive parsing. |
| `Reference.ApiKey.Set` | Commits | Receiving a secret: `SecretText`, `Secret Store ori`, `RedactRequestData()` on every path. |
| `Help.Reference.Get` | Read-only | The app's directory. |

It also has three minimal types to start from (`Reference.Echo.Get`, `.Table.Get`, `.Note.Add`); see `START-HERE.md` §10.

The app also contains:

- the **shared input layer** (`src/Common/RefInput.Codeunit.al`), which every partner app should copy
- App Registry registration
- its own setup page, reached from the single action on Bifrost Setup
- an install codeunit
- a permission set

### Legacy App v1 (not headless) and Legacy App v2 (headless)

Two versions of one app, named `Legacy App` in `app.json` (1.1.0.0 and 2.0.0.0, same app id). v1 is the "before": it works in the UI, but seven audit patterns hide in the code. v2 is **headless inside, message types outside**, and depends on Bifrost Foundation:

- **Inside:** the logic lives in an **internal core** (`Legacy Stock API`, `Access = Internal`): no UI, no Commit, no `GuiAllowed`, explicit outcomes and read procedures. The pages ask the user, then call the core.
- **Outside:** `Legacy.Stock.Reserve`, `.CancelReservation`, `.Get`, `.List`, `.ReleaseAll` and `Help.Legacy.Get` in `src/MessageTypes/`. Writes run through isolated Process codeunits. `List` + `ReleaseAll` form the look-then-act pair for a bulk change: `ReleaseAll` requires the `expectedCount` that `List` returned.
- **Compatibility:** the old public `Legacy Stock Mgt` procedures stay as obsolete shells, so existing callers keep compiling.

v1 → v2 is the worked example of `START-HERE.md` §7: the audit (§7.1) and the headless core with message types in the same app (§7.2).

### Bifrost Reference Tests

Unit tests for `Legacy App` v2 and `Bifrost Reference`, and the pattern to copy for your own. Every call goes through Foundation's public `Dispatcher ori`, exactly as a caller would make it. Two lints guard the contract: a **selection card lint** checks that every description states its effect and agrees with its direction, and a **help sections lint** checks that every help document has all eleven sections. See `Bifrost Reference Tests/README.md`.

### Bifrost Reference Playbooks (builds on Bifrost Orchestrator)

Not a standalone app. It needs **Bifrost Orchestrator** installed, plus the reference apps above. It shows how message types written to the contract become steps in an Orchestrator playbook, with no extra code. The first playbook, `REF-RELEASE`, chains `Legacy.Stock.List` into `Legacy.Stock.ReleaseAll`, and the count from the list guards the release. The folder also lists the rules a message type should follow to work well as a playbook step. See `Bifrost Reference Playbooks/README.md`. It has been built and tested in a sandbox.

### Bifrost Boilerplate (copy this to begin)

This is the smallest app that follows every rule in START-HERE:

- a **Hello World** type, `MyApp.Hello.Get`, as the first call after every publish
- the full shared input layer
- one read type and one capped list type
- the app's directory type
- registration and a permission set
- a test app with the caller, the card lint and six tests

Copy both folders, then follow the 10-step rename checklist in `Bifrost Boilerplate/README.md`. Its ids (50000–50099) are placeholders.

### Skill: bifrost-build

`skills/bifrost-build/SKILL.md` is an agent skill for building with START-HERE. It picks the path, writes the contract first, builds from the §5 patterns and checks the definition of done. It always reads `START-HERE.md` first and never builds from memory.

### Skill: bifrost-playbooks

`skills/bifrost-playbooks/SKILL.md` is an agent skill for building playbooks by conversation. The agent asks what should happen, finds the message types, proposes the steps, writes the records, and runs them in a sandbox against three cases: work to do, nothing to do, and a bad input. It schedules only when the user says so. Install it in Claude, or give it to your coding agent.

## Object ID ranges

These are for illustration only; **never reuse them** for a real extension.

| App | Range |
|---|---|
| `Bifrost Reference` | `90000–90049` |
| `Legacy App v1 (not headless)` | `90050–90099` |
| `Legacy App v2 (headless)` | `90050–90099` (core) and `90100–90149` (message types) |
| `Bifrost Reference Tests` | `90150–90199` |
| `Bifrost Boilerplate` / `Bifrost Boilerplate Tests` | `50000–50049` / `50050–50099`, placeholders you replace |

For your own app, use `50000–99999` for a per-tenant extension, or get a range from Microsoft through Partner Center for AppSource.

Never reuse the ranges of Bifrost Foundation or of any other published app.

## Building it

- **Locally:** VS Code with the AL extension. See [TESTING.md](TESTING.md) for `launch.json`, publish order and permissions.
- **Symbols:** Bifrost Foundation comes from AppSource. Install it in your sandbox, then run `AL: Download symbols`.
- **CI:** the GitHub workflows in `.github/` build the apps in Origo's own GitHub, where they have access to Foundation's symbols. In a fork or copy they won't find those symbols and will fail. Build and test in your own sandbox as described above, or point AL-Go at your own copy of Foundation's `.app`.

## Extension model, in one paragraph

Implement `interface "Msg Interface ori"` in a codeunit. The codeunit can be `Access = Internal`, but its six procedures are public. Add an enum value to `enum "Message Type ori"` pointing to that codeunit. Read the request from and write the response to `table "Message Argument ori"`. Origo's own Bifröst apps use the same model. `codeunit "Dispatcher ori"` calls any type from AL.

## Licence and trademarks

The code and documentation in this repository are licensed under the [MIT License](LICENSE). Copy the samples into your own apps, commercial ones included.

The licence covers this repository only. It does not cover:
- **Bifrost Foundation** or any other Origo app. They are licensed under their own terms, and their compiled symbols must never be committed to a repository (`.gitignore` excludes `.alpackages/` and `*.app`).
- **The names and logos "Bifröst" and "Origo".** They are trademarks of Origo ehf. You may name them to say your app works with Bifröst, but not in a way that suggests your app is made or endorsed by Origo.

Contributions to this repository are accepted under the same MIT License.

## What not to copy

Copy the patterns from Origo's own Bifröst apps, not their content. Those apps call real external systems (banks, registries, document exchange) under agreements that don't transfer to you. The only external call in this repo is `Reference.ExchangeRate.Get`, which uses a free public ECB rates service and needs no key.
