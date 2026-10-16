# Changelog

## Unreleased

- Enum extension 50000 "My Msg Type", value 50000: renamed `MyApp.Item.Summary.Get` to `MyApp.ItemSummary.Get`. The ordinal is unchanged.
- Enum extension 90000 "Ref Msg Type", value 90004: renamed `Reference.GLAccount.Overview.Get` to `Reference.GLAccountOverview.Get`. The ordinal is unchanged.
- README and AGENTS.md state that every message type name has exactly three parts, `Domain.Entity.Action`. START-HERE rule 17 joins extra words inside one part.
- Codeunit 90150 "Ref Test Caller" and codeunit 50050 "My Test Caller": the dispatcher content-type argument is `Text[100]`, matching `Dispatcher ori`. This removes pre-existing AA0139 overflow warnings.
- The example message types now implement `Msg Contract ori` and return their existing markdown use card as the `overview` chapter. Foundation 28.0.4 answers `Help.Implementation.Get` from that contract. Enum extensions 50000, 90000 and 90100 name the same implementation codeunit for the contract. No new object IDs.
- Adopted the Foundation three-part name guard `tools/Test-MessageTypeNames.ps1` from core #1037 (merged in core pull 1079, commit bce1effcea42d59674b9a0a4d7774da4e04d6b29). The guard checks `Bifrost Boilerplate`, `Bifrost Reference` and `Legacy App v2 (headless)`. Test apps stay exempt. Legacy App v1 declares no message types, so it is not scanned. No new object IDs. The GitHub Actions job that runs this guard is not in this commit: the app token cannot update `.github/workflows/` without the workflows permission.
