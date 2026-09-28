---
name: bifrost-build
description: Build, extend or retrofit a Business Central AL app so its operations are Bifröst message types that agents, integrations and Orchestrator playbooks can call. Use when someone wants to create a Bifröst app, add or change a message type, make an existing BC app headless or "callable by agents", write a message type's description or help, audit old AL code for Commit/Confirm/GuiAllowed problems, or check an app against the Bifröst definition of done.
---

# Build a Bifröst app

**The whole method is in `START-HERE.md`** in the Bifröst partner reference repository. This skill tells you how to work with it; the guide tells you what to build.

## 0. Get the guide

1. Look for `START-HERE.md` in the connected folders, in a clone of the reference repository. Read it **in full** before writing any AL.
2. If it isn't there, ask the user for the repository or the file. **Don't build from memory.** The guide holds the exact Foundation signatures (§5.7), the Dispatcher round trip, and rules that come from real failures.

## 1. Pick the path (START-HERE §2)

| The user has… | Path | Start from |
|---|---|---|
| Nothing yet: a new app | **A** | §5.8, the minimal complete app |
| An existing app whose logic is in pages, dialogs or `Commit` | **B** | §7.1 the audit, then §7.2: an internal core with message types in the same app |
| An app sold also to customers without Bifröst, or someone else's app | **C** | §7.4, a separate adapter (the exception) |

**The principle:** message types are the app's public API. Headless inside, message types outside. The app's own pages may call the internal core. Everything outside the app calls message types.

## 2. Work in this order

1. **The contract first** (§4), one per message type. Show the table to the user and get agreement: intent, effect, target, parameters, errors, siblings, when to ask.
2. **The selection card:** the description, at most 250 characters, in the user's words, with the effect ("Read-only" or "Commits") and the nearest sibling.
3. **The code** from the §5 patterns. Read every input through the shared input layer (§5.1). Writes run in an isolated Process codeunit and honour `Omit Commit`. Never guess a signature: use §5.7 or the symbols.
4. **The use card:** help with all 11 sections. Errors are copied word for word from the Labels.
5. **Platform:**
   - registration with the App Registry
   - one `Help.<Area>.Get` directory type, and a Hello World type
   - a permission set, with `IsEnabled` checking it
   - Icelandic comments on every Label, Caption and ToolTip (§5.9)
6. **Tests** through `Dispatcher ori` (§5.8, §8):
   - the break set
   - a safe retry
   - that the help quotes the real errors
   - the selection-card lint

## 3. Before you say "done"

Go through the definition of done in §8, item by item, and report each one as done, not done, or can't be known without compiling or publishing. Name what the user must do:
- download symbols
- publish
- run the tests
- call Hello World
- run the break set live

## Always

- **Folder names:** no app folder name may be the beginning of another's (§5.0).
- **No personal data** in examples, descriptions, help or test data (§3 note).
- **Sandbox only** for live tests and writes.
- Credentials go in the Secret Store. Call `RedactRequestData()` in any type that receives a secret.
- When the guide and the live system disagree, trust the live system. Tell the user, so the guide can be fixed.
