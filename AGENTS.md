# AGENTS.md

Instructions for coding agents in this repository. Read [BUILDING.md](BUILDING.md) before writing AL; for an existing app also [ADAPTING.md](ADAPTING.md).

- **Start from `MyApp.Hello.Get`** (`Bifrost Boilerplate/src/MessageTypes/MyHelloGetImpl.Codeunit.al`). One enum value + one `Access = Internal` codeunit implementing `"Msg Interface ori"`, `"Msg Discovery ori"` and `"Msg Contract ori"`.
- **Contract first.** Fill the chapter procedures with `"Msg Contract Mgt ori"` helpers (`Parameter`, `ResponseField`, `TextErrorEntry`, `ErrorEntry`, `TargetEntry`, `RelatedEntry`, `WorkflowStep`, `Example`). Required: overview, envelope, response, errors, effect, examples. Return `false` from a chapter that doesn't apply. Chapter text is English; errors are verbatim from the Labels; `effect.preconditions` match what `IsEnabled` checks.
- **Discovery:** `GetKeywords` and `GetSelectionDescription` return Labels with `Comment = 'is-IS=…'`, never `Locked`. `GetDescription` is ≤ 250 characters and says "Read-only" (Outbound) or "Commits" (Inbound).
- **Headless:** no UI and no `Commit` in the execution path; validate everything before the first write; writes run in an isolated Process codeunit (`RunIsolated`); every failure is `status = Error` with a message that says what to do; no silent success.
- **Platform:** read the real Foundation 28.0.2 symbols, never guess a signature; register with `App Registry ori`; one action on Bifrost Setup; one `Help.<Capability>.Get` per capability; secrets only in `Secret Store ori`, with `RedactRequestData()`.
- **Tests** through `Dispatcher ori` only. Keep the selection-card and contract lints passing and raise `ExpectedTypes` when you add a type.
- **Every Label, Caption and ToolTip** carries its is-IS text in `Comment`. Keep `Access = Internal` on Impl codeunits and the existing procedure signatures.

Use only the public Foundation API and this repository. Product documentation: <https://docs.bifrost.origo.is>.
