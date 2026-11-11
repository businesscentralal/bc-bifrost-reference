# core#1149 / reference PR10 — Litr verification

Candidate: `83c54892304762826cf1f36e76c29c4f92f3d7e4` on `fix/1149-template-envelope`.
This branch contains sanitized verification evidence; it is not a product candidate.

Worker: Litr (`worker-9`). Environment: own BC29 tenant `w129-19`, BC290, CRONUS International Ltd. Foundation dependency built locally at `a047046eacfc25a771488b38decf712ffba37bc9` (28.0.13.0). All published packages were compiled by this worker and published at tenant scope.

## Results

- Three product projects and two test projects: CodeCop/UICop **0 errors, 0 warnings**. AppSourceCop is **FAILED**, not green: Boilerplate **4 errors, 1 warning** (AS0051 logo/help, AS0084 PTE range, AS0054 affix, AS0092 telemetry). The analyzer output has one standalone error line; counting only colon-prefixed errors undercounts it.
- Full configured reference/boilerplate suite: **64 executed, 64 passed, 0 failed, 0 skipped** (20 + 44).
- Additional private runtime-example verifier: **42 methods executed, 38 passed, 4 failed, 0 skipped**. All **40 examples x 2 locales = 80 requests** ran through Foundation. **80/80** had no UnknownParameter warning/refusal. **76** outcomes matched the documented response; the **4** price ApplyAdjustment outcomes instead returned ConfirmationRequired. The two second examples were run separately after the first-example assertion stopped their original methods.
- MCP: **62 scenario checks, 60 passed, 2 failed, 0 skipped**, covering all **20 touched types** in **LCIDs1033/1039**. Main run58/56/2; additional no-record proof4/4/0. Eight before/after readbacks and fixture helper calls are setup/evidence, not extra scenario passes. The main price error probe used a four-item fixture; independent private second-example tests used the documented five-item changed selection and reproduced ConfirmationRequired instead of PreconditionFailed.
- No live provider calls. ExchangeRate success examples used a private native HttpClientHandler with outbound requests blocked; MCP exercises its local rejection path. This is not provider verification. API-key example used only the public placeholder and cleared it; final metadata shows isSet=false. No licence gate was bypassed.
- UI: **4 checks passed** across **English1033 and Icelandic1039**: Echo caller status cannot forge outcome and causes no warning; unrelated key still gives a localized UnknownParameter warning. Bifrost Messages request/response factboxes and screenshots retained. User language restored to English.
- Owned fixture cleanup: **zero records** matching X1149-* or BIFT-* across all nine affected tables, independently read back. No sample/customer fixture was used as a success-test dependency. AC01 intentionally misspells the filter, asserts only its warning, and returned demo rows are omitted from this public bundle.

- Tenant reset completed: all eight worker-published task/dependency apps uninstalled with extension data deletion and unpublished; Automation API readback shows no owned apps remain. Global Microsoft apps were preserved.

## Pending

This is not a green review handoff. Claude Code/Architect must resolve AC10 AppSourceCop applicability to PTE templates, and route the wider price-example/default-confirmation mismatch. Reference#11 retains the missing paired Test CI repair. New-head Claude verification and Grok clearance are absent; earlier65ae5a5 receipts do not verify this candidate. Architect merge/deployment and Tester UAT remain separate pending stages.

Private full evidence and retained-owner checkpoint: `/workspace/private/core1149-20261111T2241/`. No suppressions, assertion weakening, production changes or provider calls were used.
