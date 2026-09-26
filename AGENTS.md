# AGENTS.md

The instructions for coding agents in this repository are in [`START-HERE.md`](START-HERE.md). Read it in full before you write any AL code.

- **Headless:** no UI and no `Commit` in the execution path; writes run in an isolated Process codeunit; validate everything before the first write.
- **Honest contract:** every failure is `status = Error` with a message that says what to do; no silent success; the description and help follow `CONTRACT.md` and quote the real error Labels.
- **Platform:** read the real Foundation symbols, never guess a signature; register with `App Registry ori`; one action on Bifrost Setup; one `Help.<App>.Get` per app.

Use only the public Foundation API and the material in this repository. Don't rely on internal Origo material.
