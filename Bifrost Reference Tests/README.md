# Bifrost Reference Tests

Unit tests for the reference apps, and the pattern for testing your own message types.

## The rule

Test a message type **the way a caller uses it**: through Foundation's public `Dispatcher ori`, with a JSON request, reading the JSON answer. Never call an `Impl` codeunit or an internal directly. That tests the contract a caller's agent relies on, and it needs no `internalsVisibleTo`. `Ref Test Caller` (90150) wraps the dispatcher in `Call`, `CallRaw` and `GetHelp`, with the assertion and reading helpers `AssertErrorAnswer`, `AssertOk`, `GetText`, `GetDecimal` and `GetBoolean`. Copy it.

`Dispatcher.Execute` runs with `Omit Commit = true`. Errors come back in two ways:

| The type answers with… | You get | Test it with |
|---|---|---|
| `Argument.RespondWithError` (input checks) | `{"status":"Error","error":"…"}` | `Caller.AssertErrorAnswer(Response, 'part of the text')` |
| `Error()` inside the isolated write (business rules in the app's core) | The error is raised out of the call | `asserterror Caller.Call(...)`, then `Assert.ExpectedError('part of the text')` |

## What is covered

| Codeunit | Proves |
|---|---|
| `Selection Card Lint` (90151) | Every description of the 16 types states its effect ("Read-only" for Outbound, "Commits" for Inbound) and doesn't talk about the implementation. |
| `Asset Maintenance Tests` (90152) | The break set: local date format, not found vs. missing, a future date, out of range. Also the safe retry with `externalId` (`created: false` on repeat), and that the help quotes the real error. |
| `GL Account Overview Tests` (90154) | The read: for a posting account taken from the chart of accounts, `balanceAsOf` and `netChange` equal the base app's `Balance at Date` and `Net Change` for `fromDate`..`asOfDate`, and `accountType` comes back by enum name. Also an unknown account is "not found", a `fromDate` after `asOfDate` is refused, and without `fromDate` `netChange` is `null` and `asOfDate` defaults to the work date. |
| `Legacy Adapter Tests` (90153) | The audit fixes (`START-HERE.md` §7.1) in Legacy App v2, through its message types only: the stock check applies without a UI, `allowOverStock` is explicit, the core's errors reach the caller, no-ops say so, and `ReleaseAll` is guarded and all or nothing. Also that the help and `Help.Legacy.Get` match the real types. (The codeunit keeps its old name.) |
| `Help Sections Lint` (90155) | Every help document of the 16 types, read through `Help.Implementation.Get` as callers get it, has all eleven use-card sections of `START-HERE.md` §4 (`## Overview` … `## Related message types`; section 3 is checked by its start, `## Identifying the`). The failure names the type and the missing section. |

## Running them

1. In the sandbox, install the Microsoft test apps **Library Assert** and **Test Runner** (Extension Management, or let VS Code download their symbols).
2. Publish `Legacy App v2 (headless)` (Legacy App v2) and `Bifrost Reference`, then this app.
3. Open page **AL Test Tool** (130451), choose **Get Test Codeunits → Select Test Codeunits**, pick 90151–90155 and choose **Run all**.

Test data uses the `BIFT-` prefix and is rolled back after each codeunit (Test Runner isolation).
