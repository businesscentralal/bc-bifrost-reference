# Changelog

## Unreleased

- Enum extension 50000 "My Msg Type", value 50000: renamed `MyApp.Item.Summary.Get` to `MyApp.ItemSummary.Get`. The ordinal is unchanged.
- Enum extension 90000 "Ref Msg Type", value 90004: renamed `Reference.GLAccount.Overview.Get` to `Reference.GLAccountOverview.Get`. The ordinal is unchanged.
- README and AGENTS.md state that every message type name has exactly three parts, `Domain.Entity.Action`. START-HERE rule 17 joins extra words inside one part.
- Codeunit 90150 "Ref Test Caller" and codeunit 50050 "My Test Caller": the dispatcher content-type argument is `Text[100]`, matching `Dispatcher ori`. This removes pre-existing AA0139 overflow warnings.
