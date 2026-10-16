---
name: bifrost-build
description: Build, extend or retrofit a Business Central AL app so its operations are Bifröst message types that agents, integrations and Orchestrator playbooks can call. Use when someone wants to create a Bifröst app, add or change a message type, make an existing BC app headless or "callable by agents", write a message type's description, keywords or contract chapters, audit old AL code for Commit/Confirm/GuiAllowed problems, or check an app against the Bifröst definition of done.
---

# Build a Bifröst app

The method is in the Bifröst partner reference repository: `BUILDING.md` (new operations) and `ADAPTING.md` (existing apps). This skill says how to work; those files say what to build.

## 0. Get the guides

Look for `BUILDING.md` in a clone of the reference repository and read it in full before writing AL. For an existing app, read `ADAPTING.md` too. If they aren't there, ask the user for the repository. **Don't build from memory**, and read the real Foundation symbols (`.alpackages`) rather than guessing a signature. Product documentation: https://docs.bifrost.origo.is.

## 1. Pick the path

| The user has… | Start from |
|---|---|
| Nothing yet | Copy `Bifrost Boilerplate` + `Bifrost Boilerplate Tests`; publish; call `MyApp.Hello.Get`. |
| An existing app with logic in pages, dialogs or `Commit` | `ADAPTING.md`: audit, internal core, message types in the same app. |
| An app also sold without Bifröst, or someone else's app | `ADAPTING.md`, last section: a separate adapter app. |

**Principle:** message types are the app's public API. Headless inside, message types outside.

## 2. Work in this order

1. **The contract first** (`BUILDING.md` section 4), per type: name, effect, target, parameters, response, errors, preconditions, siblings, repeat safety. Show it to the user and agree it.
2. **Discovery:** `GetDescription` (≤ 250 characters, "Read-only" or "Commits", the nearest sibling), `GetKeywords` and `GetSelectionDescription` as translatable Labels with `is-IS=` comments.
3. **The code**, copying `MyHelloGetImpl.Codeunit.al` and the patterns in `BUILDING.md` section 5. Every input through the shared input layer; writes in an isolated Process codeunit.
4. **The contract chapters** with `"Msg Contract Mgt ori"` helpers. Required: overview, envelope, response, errors, effect, examples. Errors verbatim from the Labels; preconditions match `IsEnabled`; `false` for chapters that don't apply.
5. **Platform:** App Registry registration, one `Help.<Capability>.Get`, a permission set checked by `IsEnabled`, is-IS comments on every Label, Caption and ToolTip.
6. **Tests** through `Dispatcher ori`: the break set, a safe retry, the selection-card and contract lints (raise `ExpectedTypes`).

## 3. Before you say "done"

Go through the definition of done in `BUILDING.md` section 8 and report each item as done, not done, or unknown until compiled or published. Name what the user must do: download symbols, publish, run the tests, call Hello World, run the break set live.

## Always

- No personal data in examples, descriptions, contract text or test data.
- Sandbox only for live tests and writes.
- Secrets only in `Secret Store ori`; `RedactRequestData()` in any type that receives one. Never ask for a key in chat: people enter keys in Bifrost Setup > Apps.
- When the guides and the live system disagree, trust the live system and tell the user, so the guide can be fixed.
