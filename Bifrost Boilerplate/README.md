# Bifrost Boilerplate

The smallest app that is a complete Bifröst app. Copy this folder and `Bifrost Boilerplate Tests`, rename
them, and replace the samples with your own message types. Every pattern in it is copied from the compiled
and tested apps in this repository (`Bifrost Reference`, `Legacy App v2 (headless)`, `Bifrost Reference Tests`).

## Hello World first

Publish the app as it is, then make one call:

```json
{ "type": "MyApp.Hello.Get", "data": { "name": "Anna" } }
```

The answer looks like this:

```json
{ "message": "Hello, Anna! My Bifrost App is working in CRONUS.", "user": "…", "company": "CRONUS",
  "language": 1033, "serverTime": "…", "app": "My Bifrost App", "appVersion": "1.0.0.0" }
```

That one answer proves the whole path:

- the app is published
- its type is registered and visible to the caller
- the API or MCP server reaches it
- the answer comes back in the caller's language (try lcid 1039)
- the version is the one you just published

Call it again after every publish. If `appVersion` is old, the new publish isn't live yet.

## What is in it

| Folder / file | What it is |
| --- | --- |
| `src/MessageTypes/MyHelloGetImpl.Codeunit.al` | `MyApp.Hello.Get`, the Hello World. It reads no business data. Keep it. |
| `src/Common/MyInput.Codeunit.al` | The shared input layer: required and optional text, strict YYYY-MM-DD dates, decimal and whole number with a range, optional true/false, the item resolver (subject SystemId, subject No., body `itemNo`) and `RunIsolated` for your first write. Read every parameter through it. |
| `src/Items/MyItemSummary*.al` | `MyApp.Item.Summary.Get` - a read of one record: description, unit price, inventory as of a date, null where there is no value. Impl plus help with all eleven sections of the contract (`START-HERE.md` §4). |
| `src/Items/MyItemList*.al` | `MyApp.Item.List` - a capped list: optional filter, at most 100 rows, `count` / `returned` / `more`. |
| `src/MessageTypes/MyHelpGetImpl.Codeunit.al` | `Help.MyApp.Get` - the app's directory. Every Bifröst app has exactly one. |
| `src/MessageTypes/MyMsgType.EnumExt.al` | The enum values: the names callers send as `type`. |
| `src/Lifecycle/MyRegistration.Codeunit.al` | The one App Registry subscriber that makes the app known to the Bifrost Setup Wizard and notifications. |
| `src/Lifecycle/MYBIFROSTAPP.PermissionSet.al` | The app's assignable permission set. |

Search for `TODO:` - those are the only places where you must rename or decide.

The samples use items on purpose: a template gets copied everywhere, so it must not handle personal data. When your app handles people's data (vendors, contacts, employees and the like), apply your data-protection rules (DataClassification, minimal fields, no personal data in logs or telemetry).

## Rename and go

1. **Folders.** Copy `Bifrost Boilerplate` and `Bifrost Boilerplate Tests` into your own repository and rename both
   folders to your app's name (for example `Fleet Bifrost` and `Fleet Bifrost Tests`). In an AL-Go repository
   add them to `appFolders` and `testFolders` in `.AL-Go/settings.json`. (In this repository they are left
   out of AL-Go on purpose; they are a template, not a product.)
2. **app.json - identity.** Set `name`, `publisher`, `brief`, `description`, `url`, `EULA`,
   `privacyStatement` and `help`. Generate a **new** `id` (a new GUID) for the app and another for the test
   app - never keep the ones in the template. Put the app's new `id`, `name` and `publisher` into the test
   app's dependency on it.
3. **app.json - object id range.** `50000-50049` (app) and `50050-50099` (tests) are **placeholders only**.
   Use the range you own: your AppSource range from Microsoft Partner Center for an AppSource app, or a
   range in 50000-99999 agreed for the tenant for a per-tenant extension. Two apps installed in the same
   environment must never overlap, and two boilerplates copied without a change will. Then renumber every
   object and every enum value, and change `IsOurs` in `MySelectionCardLint.Codeunit.al` to the same range.
4. **app.json - resource exposure.** The boilerplate ships with `allowDebugging`, `allowDownloadingSource` and
   `includeSourceInSymbolFile` set to `false`. The sample apps in this repository set them to `true` only
   because they are samples meant to be read; decide for your own app deliberately instead of copying them.
5. **Namespace.** Replace `MyCompany.MyBifrostApp` (and `MyCompany.MyBifrostApp.Tests`) in every `.al` file
   with your own, for example `Contoso.Fleet`. Keep the `using` lines sorted: `Microsoft.*`, then your
   namespace and `Origo.*` alphabetically, then `System.*`.
6. **Object names and affix.** Replace the `My` prefix in object names (`My Input`, `My Item Summary Impl`,
   ...) with your AppSource affix, or with the affix your organisation uses. Object names are at most 30
   characters.
7. **Message type names.** Rename `MyApp` in `MyApp.Item.Summary.Get`, `MyApp.Item.List` and
   `Help.MyApp.Get` to your own area, in the enum extension (name **and** caption), in both help codeunits,
   in the directory table in `MyHelpGetImpl`, in the descriptions that name a sibling, and in the tests.
   Names are `Area.Entity.Verb` in words a user would say.
8. **Captions and Icelandic.** Rewrite each `GetDescription` (the selection card, at most 250 characters,
   with `Read-only` or `Commits`) and each help document (the use card, the eleven sections of
   the contract in `START-HERE.md` §4). Every `Label`, `Caption` and `ToolTip` carries its Icelandic text in `Comment`
   (`'%1 = ..., is-IS=...'`); technical tokens stay `Locked = true`. When you change a Label, change the
   Errors table of the help in the same commit.
9. **Permission set.** Rename `MY BIFROST APP` (at most 20 characters) and its caption including the is-IS
   text. Add `tabledata ... = RIMD` and `table ... = X` for every table you add; keep `IsEnabled` of each
   type checking the permission that type needs.
10. **Build, publish, test.** Download symbols (Bifrost Foundation 28.0.0.0 and the base app), build the app
    with CodeCop, UICop and AppSourceCop, publish it, then build and publish the test app and run it. All six
    tests and the selection-card lint must pass before you replace the samples - they prove the copy works.
    Then call your renamed `MyApp.Hello.Get` first, then `Help.MyApp.Get` and each type once through the Bifrost API or MCP server: one
    happy path and one error each.

## What to delete when you do not need it

- **The item samples.** Once your own first read and list exist, delete `src/Items/*` and
  `MyItemTests.Codeunit.al`, remove the two enum values, the two rows in the directory table in
  `MyHelpGetImpl` and the Item line in the permission set, and lower `ExpectedTypes` in the lint.
- **`ResolveItem`** in `MyInput` when no type of yours takes an item (then also the
  `Microsoft.Inventory.Item` using line and the two item Labels).
- **`RunIsolated`** when the app has no write types. Keep it for your first write: every write runs through
  it (`Reference.Note.Add` in `Bifrost Reference/src/MessageTypes` does; `Bifrost Reference/src/AssetMaintenance` shows the same
  isolation with a Process instance that carries validated values).
- **Unused `Get` procedures** in `MyInput` (for example `GetRequiredDecimal`), with their Labels, so that the
  Labels left all appear in a help document. Never delete `ReadRequest`.
- **Never delete** `MyApp.Hello.Get`, `Help.MyApp.Get`, `MyRegistration`, the permission set, the test caller or the lint.

## When the app grows

- A setup page: pass it to `AppRegistry.AddApp` in `MyRegistration` and add **one** action to the Bifrost
  Setup page - copy `Bifrost Reference/src/Lifecycle/RefSetupAction.PageExt.al`. No setup notifications of
  your own.
- A secret (API key, password): store it with Foundation's `Secret Store ori`, and call
  `Argument.RedactRequestData()` in any type that receives one - see `Bifrost Reference/src/ExchangeRates`.
- A write: validated input, isolated write, safe retry - see `Bifrost Reference/src/AssetMaintenance`.
- Error texts in tests are asserted in English. When you add an is-IS translation file, run the tests in a
  company whose Bifrost default language is English, or assert on parts that do not change (a parameter
  name, `YYYY-MM-DD`).
