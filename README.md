# Bifröst: reference implementation for partners

Business Central extensions that show how to build on
Bifröst Foundation ([documentation](https://businesscentralal.github.io/bifrost/)). They cover:

- adding message types that agents and integrations can call headless
- making an existing app headless
- adapting an existing app to Bifröst

The patterns come from live testing of message types with AI agents and follow Foundation's public API.

## Start here

| You are … | Read |
|---|---|
| **Building anything**, alone or with a coding agent | [`START-HERE.md`](START-HERE.md). The three paths (new app, make an app headless, adapt an app), the rules, the code patterns, the examples and the definition of done. |
| Designing a message type's **name, description and help** | [`CONTRACT.md`](CONTRACT.md) (selection card + use card) |
| Building and testing the examples | [`TESTING.md`](TESTING.md) |
| Calling Bifröst from outside BC, or from AL | [`INTEGRATING.md`](INTEGRATING.md) |
| Seeing what "headless" means, with screens | [`Legacy App v2 (headless)/README.md`](Legacy%20App%20v2%20(headless)/README.md) |
| A coding agent working in this repository | [`AGENTS.md`](AGENTS.md) (points to `START-HERE.md`) |

## The demo in four publishes

| # | Publish | A person sees | An AI agent can |
|---|---|---|---|
| 1 | `Legacy App v1 (not headless)` | A working app: reserve, cancel, release all | read its table, nothing more. It has no actions to call, and generic writes are blocked. Seven audit patterns hide in the code (`AUDIT 7.2`). |
| 2 | `Legacy App v2 (headless)` (same app id): **made headless** | The same app, with the same questions asked in the same places | still nothing. The logic is now callable without a UI, but Bifröst doesn't know about it yet. Each pattern is fixed (`FIXED 7.2`). |
| 3 | `Legacy App - Bifrost`: **the adapter** | – | reserve (refused over stock unless allowed), cancel, check, list and release, with the same rules a person gets |
| 4 | `Bifrost Reference`: **a new app built on Bifröst** | Setup page, service visits | everything in the table below |

Open `bifrost-reference.code-workspace`; its folders are in this order, with `Bifrost Reference Tests` fifth. Publish 1 → 2 is an upgrade (same app id). To run the demo again from the start, uninstall and unpublish `Legacy App - Bifrost` and `Legacy App` first, because BC refuses to install a lower version over a higher one. See `Legacy App v1 (not headless)/README.md` and `Legacy App v2 (headless)/README.md` for what changes at each step.

## The apps

### Bifrost Reference

A new app built on Bifröst. Each message type teaches one pattern:

| Message type | Effect | Pattern |
|---|---|---|
| `Reference.Customer.Overview.Get` | Read-only | Resolve a record from `subject`, keeping "not given" and "not found" apart. `SetLoadFields`, FlowFields "as of" a date, `null` instead of 0, enums by name. |
| `Reference.ServiceVisit.Create` | Commits | Validate every input before any write. Business rules with actionable errors. Isolated write. Safe retry with `externalId`. |
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

Two versions of one app, named `Legacy App` in `app.json` (1.1.0.0 and 2.1.0.0, same app id). v1 is the "before": it works in the UI, but seven audit patterns hide in the code. v2 is an ordinary app with no Bifröst dependency. Its logic now lives in a **headless facade** (`Legacy Stock API`): public, no UI, no Commit, no `GuiAllowed`, explicit outcomes, read procedures, and events. The old entry points are kept as thin shells, and the page asks the user before calling the facade. v1 → v2 is the worked example of the audit in `START-HERE.md` §7.2.

### Legacy App - Bifrost

An **adapter app** that depends on `Legacy App v2 (headless)` (Legacy App 2.1) and Foundation. It exposes `Legacy.Stock.Reserve`, `.CancelReservation`, `.Get`, `.List` and `.ReleaseAll` by calling the facade through isolated Process codeunits. Business rules stay in Legacy App. `List` + `ReleaseAll` form the look-then-act pair for a bulk change: `ReleaseAll` requires the `expectedCount` that `List` returned.

### Bifrost Reference Tests

Unit tests for all three apps, and the pattern to copy for your own. Every call goes through Foundation's public `Dispatcher ori`, exactly as a caller would make it. A **selection card lint** checks that every description states its effect and agrees with its direction. See `Bifrost Reference Tests/README.md`.

## Object ID ranges

These are for illustration only; **never reuse them** for a real extension.

| App | Range |
|---|---|
| `Bifrost Reference` | `90000–90049` |
| `Legacy App v1 (not headless)`, `Legacy App v2 (headless)` | `90050–90099` |
| `Legacy App - Bifrost` | `90100–90149` |
| `Bifrost Reference Tests` | `90150–90199` |

For your own app, use `50000–99999` for a per-tenant extension, or get a range from Microsoft through Partner Center for AppSource.

Never reuse the ranges of Bifrost Foundation or of any other published app.

## Building it

- **Locally:** VS Code with the AL extension. See [TESTING.md](TESTING.md) for `launch.json`, publish order and permissions.
- **Symbols:** Bifrost Foundation comes from AppSource. Install it in your sandbox, then run `AL: Download symbols`.

## Extension model, in one paragraph

Implement `interface "Msg Interface ori"` in a codeunit. The codeunit can be `Access = Internal`, but its six procedures are public. Add an enum value to `enum "Message Type ori"` pointing to that codeunit. Read the request from and write the response to `table "Message Argument ori"`. Origo's own Bifröst apps use the same model. `codeunit "Dispatcher ori"` calls any type from AL.

## What not to copy

Copy the patterns from Origo's own Bifröst apps, not their content. Those apps call real external systems (banks, registries, document exchange) under agreements that don't transfer to you. The only external call in this repo is `Reference.ExchangeRate.Get`, which uses a free public ECB rates service and needs no key.
