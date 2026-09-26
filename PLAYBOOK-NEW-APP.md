# Playbook A: a new app built on Bifröst

You're starting from nothing. Every operation you want an integration or an agent to perform becomes a message type. Worked example: the **Bifrost Reference** app.

## Steps

### 1. Create the app

- `app.json`:
  - depend on Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, publisher Origo, 28.0.0.0)
  - platform/application `28.0.0.0`, runtime `17.0`
  - your own id range
  - `"features": ["TranslationFile"]`
- Download symbols from a sandbox where Foundation is installed.
- Pick a namespace, e.g. `Contoso.Bifrost.FieldService`, with `using Origo.Bifrost;` in every file that touches Foundation.

### 2. Copy the shared input layer

Copy `Bifrost Reference/src/Common/RefInput.Codeunit.al`, rename the object, and adjust the example values. Every message type reads its input through it:

- `ReadRequest`
- `GetRequiredText` / `GetOptionalText`
- `GetRequiredDate`
- `GetRequiredDecimal` / `GetRequiredInteger`
- a `Resolve<Entity>` per record type you look up

Add resolvers following `ResolveCustomer`: subject GUID, then subject number, then body key. "Not given" and "not found" get different messages.

### 3. List the operations and classify each one

| Operation | Effect | Pattern to copy |
|---|---|---|
| Show something | Read-only | `Reference.Customer.Overview.Get` |
| Create or change one record | Commits | `Reference.ServiceVisit.Create` |
| Change many records, or something that can't be undone | Commits + preview | `Reference.ItemPrice.PreviewAdjustment` / `ApplyAdjustment` |
| Call an external service | Read-only / Commits | `Reference.ExchangeRate.Get` |
| Receive a credential | Commits | `Reference.ApiKey.Set` |

For each write, also consider a **read sibling**. An agent that can't check state has to guess.

### 4. Write the contract for each type

Fill in [CONTRACT.md](CONTRACT.md) and review it with the user before writing code.

### 5. Implement each type

Per type:

1. **An enum value** in your `enumextension … extends "Message Type ori"`.
2. **An Impl codeunit** (`Access = Internal`, `implements "Msg Interface ori"`, public procedures), with each interface member doing this:

   | Member | What it does |
   |---|---|
   | `IsEnabled` | Checks the exact permissions. |
   | `GetFilterTableNo` | Returns the main table, or 0. |
   | `GetDescription` | Returns the selection card. |
   | `GetMessageDirection` | Returns `Outbound` for reads, `Inbound` for writes. |
   | `GetMessageHelpAsMarkdownDocument` | Calls `Argument.SetResponseMarkdown(<Help>.GetHelpText())`. |
   | `ExecuteBifrostTask` | Runs these steps in order: `AssertVersion1`, then `AssertIsLicensed`, then validate every input with no writes, then run the isolated write, then build the response. |

3. **A Process codeunit** for writes (`TableNo = "Message Argument ori"`). Pass it the validated values through a `Set…` procedure on the codeunit instance.
4. **A Help codeunit** with the use card. Copy the error texts from your Labels.

### 6. Integrate with the platform

Copy from `Bifrost Reference/src/Lifecycle/`:

- `…Registration` subscribing to `App Registry ori.OnRegisterApps`, which calls `AddApp(Apps, AppId, Name, Page::"<your setup page>")`
- your own setup table and page, if you have settings
- a `pageextension` on `Setup ori` adding **one** action in `Apps` and its `actionref` in `Category_Apps`
- an install codeunit that registers secrets (`Secret Store ori.Register`)
- a permission set covering your tables and pages
- a `Help.<App>.Get` directory type listing all your types with their effect

### 7. Test

Follow [TESTING.md](TESTING.md): run the happy path and the break set for every type, through the MCP server, in a sandbox.

## Pitfalls seen in practice

- **Writing before `Process.Run`.** Even `RedactRequestData()` or an error response is a write, and it makes `if not Process.Run(...)` fail at runtime. Validate first, then run the isolated write, and do everything else after it.
- **Returning `0` for "no value".** An agent will treat it as a real zero. Use `null`, and say so in the help.
- **`Balance (LCY)` "as of" a date.** It ignores the Date Filter. Use `Net Change (LCY)` over `0D..date`.
- **Read-only types reading a setup record that doesn't exist yet.** Use defaults in memory (`GetOrDefault`); never insert from a read.
- **Outbound HTTP blocked in a sandbox.** Catch it with a TryFunction and tell the user to enable HTTP for your app in the Bifrost Setup Wizard. This works because your app is registered with App Registry.
