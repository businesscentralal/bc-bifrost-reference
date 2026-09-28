# Building and testing the examples

## Build and publish

1. **Prepare a sandbox.** Install **Bifrost Foundation** in a Business Central sandbox, not production.
2. **Open the workspace.** Open `bifrost-reference.code-workspace` in VS Code with the AL Language extension. It lists the four folders in publish order.
3. **Add a launch configuration** to each app folder (`.vscode/launch.json`, which is git-ignored) that points at your sandbox:

   ```json
   {
     "version": "0.2.0",
     "configurations": [
       {
         "name": "My sandbox",
         "type": "al",
         "request": "launch",
         "environmentType": "Sandbox",
         "environmentName": "<your sandbox name>",
         "tenant": "<your tenant id>",
         "schemaUpdateMode": "ForceSync"
       }
     ]
   }
   ```

4. **Download symbols** in each app folder with `AL: Download symbols`.
5. **Publish each app** with `Ctrl+F5`, in this order:

   | # | Folder | App (version) | Depends on |
   |---|---|---|---|
   | 1 | `Legacy App v1 (not headless)` | `Legacy App` 1.1.0.0 | nothing (base app only) |
   | 2 | `Legacy App v2 (headless)` | `Legacy App` 2.0.0.0, an **upgrade** of 1 (same app id): headless inside, `Legacy.Stock.*` message types outside | Bifrost Foundation |
   | 3 | `Bifrost Reference` | `Bifrost Reference` 1.1.0.0 | Bifrost Foundation |
   | 4 | `Bifrost Reference Tests` | `Bifrost Reference Tests` | Legacy App v2, Bifrost Reference, Bifrost Foundation, plus Microsoft's Library Assert and Test Runner |

   Step 1 is only for the demo: skip it if you just want the headless app. To start the demo again, uninstall and unpublish `Bifrost Reference Tests` and `Legacy App` first, because BC refuses to install a lower version over a higher one.

6. **Assign permission sets.** Give the test user Foundation's BIFROST permission sets, plus **BIFROST REFERENCE** and **LEGACY STOCK** (Legacy App's set, which covers its tables and message types).
7. **Allow outbound HTTP.** In Bifrost Setup, start the setup wizard and allow outbound HTTP for *Bifrost Reference*. Only `Reference.ExchangeRate.Get` needs it.

A sandbox is shared by every company in it, so everyone who uses the sandbox sees the published message types.

## Start your own app from an example

1. **Compile the unmodified example first.** Before you change anything, prove the baseline compiles in your environment. Fixing a problem you introduced is easier than debugging one you inherited.
2. **Copy the folder** closest to what you build (`Bifrost Boilerplate` or `Bifrost Reference` for a new app; `Legacy App v2 (headless)/src/MessageTypes` for message types added to an existing app) and rename it.
3. **In `app.json`,** give it a new `id` (a new GUID), a new `name` and `publisher`, and **your own id range**. Never keep the sample ranges.
4. **Rename the objects and the namespace,** then compile again before you add anything.

## Run the unit tests

Publish `Bifrost Reference Tests` last and run codeunits 90151–90155 from the **AL Test Tool** page. The Legacy tests depend on Legacy App v2 and call its message types only. The steps and what each codeunit proves are in [`Bifrost Reference Tests/README.md`](Bifrost%20Reference%20Tests/README.md).

## Test every message type

Call each type through the MCP server or the Bifröst API, one call at a time. Keep the verbatim response of each call.

**1. Happy path:** one realistic call.

**2. Break set:** each of these must return `status = Error` with a message that says what to do. A raw platform error, or a misleading message, is a failure.

| Case | Example |
|---|---|
| Target missing | no `subject`, no key |
| Target not found | subject `99999` |
| Wrong JSON type | `{"assetNo": {"a": 1}}` |
| Local date format | `"maintenanceDate": "26.09.2026"` |
| Out of range | `"hours": 30` |
| Text too long | a 150-character `description` (maximum 100) |
| Repeat call | the same write twice. Is the result what the help says? |
| Language | `lcid` 1039. Error texts follow lcid only when a translation is installed. |

**3. Help:**

- `get_message_type_help` returns the use card.
- Its error texts match what the calls returned.

**4. Selection:** search with `find_message_types` using three phrasings a user would say, one of them with a synonym, for example:

- "balance of G/L account 2910 on 31 August"
- "log a repair on the forklift"
- "raise chair prices by 5 percent"

Record the rank of the right type.

### Things to check per example

| Type | Also check |
|---|---|
| `Reference.GLAccount.Overview.Get` | `netChange` is `null` (not 0) without `fromDate`; `balanceAsOf` follows `asOfDate`; the SystemId as subject works. |
| `Reference.AssetMaintenance.Create` | The same `externalId` twice gives `created: false` and writes nothing. |
| `Reference.ItemPrice.ApplyAdjustment` | It refuses without, or with a wrong, `expectedItemCount`. Apply changes real prices, so test in a copy company. |
| `Reference.ApiKey.Set` | The request body is redacted in the Bifrost message log, on success and on failure. |
| `Reference.ExchangeRate.Get` | With outbound HTTP blocked, the error says how to enable it. |
| `Legacy.Stock.CancelReservation` | A second call gives `cancelled: false`. |
