# Changelog

## [Unreleased]

### Fixed

- Restore Icelandic discovery translations for the four Boilerplate, ten Reference and six Legacy v2 message types, and synchronize the shared input error text with its labels.
- Format codeunit 50007 `My Hello Get Impl` with separate statement lines so the Hello sample compiles without AA0018 warnings.
- Correct the public Foundation API table and document EULA approval before trial activation in `BUILDING.md`; clarify the template’s per-tenant analyzer setup.
- Configure `.AL-Go/settings.json` to obtain the executable Foundation app from its main build instead of deploying an AppSource symbol-only package. Include Boilerplate and its tests alongside Reference and Legacy v2 in the build, and enforce CodeCop/UICop warnings for products and tests.
