# core#1149 / bc-bifrost-reference PR10: developer evidence at 65ae5a5c39d82d170d88672d2d7ac5cebe133acd
Nár (worker-26), local BC 29 tenant w129-36 (CRONUS International Ltd.), Foundation 28.0.13.0 Dev, 2026-11-11.
- compile/: alc 30.0 logs for the 5 projects (0 errors, 0 warnings, CodeCop+UICop), artifact sha256.
- tests/: bc_dev_run_tests local results: 50050..50099 20/0/0, 90150..90199 44/0/0; clean-before/after = private cleanup helper 50990 (not in the PR).
- mcp/: self-seeded MCP scenarios, 24 passed / 0 failed in lcid 1033 and 1039 (item BIFT-MCP1149 created via REST, deleted afterwards, 204).
- ui/: Web Client Bifrost Messages page 10077907 in en-US and is-IS, plus the English restore check.
