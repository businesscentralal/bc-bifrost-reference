# Bifrost Reference Tests

Unit tests for the reference apps, and the pattern for testing your own message types.

## The rule

Test a message type **the way a caller uses it**: through Foundation's public `Dispatcher ori`, with a JSON request, reading the JSON answer. Never call an `Impl` codeunit or an internal directly. That tests the contract a customer's agent relies on, and it needs no `internalsVisibleTo`. `Ref Test Caller` wraps the dispatcher in four helpers: `Call`, `CallRaw`, `GetHelp` and `AssertErrorAnswer`. Copy it.

`Dispatcher.Execute` runs with `Omit Commit = true`. Errors come back in two ways:

| The type answers with… | You get | Test it with |
|---|---|---|
| `Argument.RespondWithError` (input checks) | `{"status":"Error","error":"…"}` | `Caller.AssertErrorAnswer(Response, 'part of the text')` |
| `Error()` inside the isolated write (business rules in the facade) | The error is raised out of the call | `asserterror Caller.Call(...)`, then `Assert.ExpectedError('part of the text')` |

## What is covered

| Codeunit | Proves |
|---|---|
| `Selection Card Lint` | Every description of the 16 types states its effect ("Read-only" for Outbound, "Commits" for Inbound) and doesn't talk about the implementation. |
| `Service Visit Tests` | The break set: local date format, not found vs. missing, a future date, out of range. Also the safe retry with `externalId`, and that the help quotes the real error. |
| `Legacy Adapter Tests` | The §7.2 audit fixes: the stock check applies without a UI, `allowOverStock` is explicit, facade errors reach the caller, no-ops say so, and `ReleaseAll` is guarded and all or nothing. Also that the help and `Help.Legacy.Get` match the real types. |

## Running them

1. In the sandbox, install the Microsoft test apps **Library Assert** and **Test Runner** (Extension Management, or let VS Code download their symbols).
2. Publish `Bifrost Reference`, `Legacy App v2 (headless)` and `Legacy App - Bifrost`, then this app.
3. Open page **AL Test Tool** (130451), choose **Get Test Codeunits → Select Test Codeunits**, pick 90151–90153 and choose **Run all**.

Test data uses the `BIFT-` prefix and is rolled back after each codeunit (Test Runner isolation).
