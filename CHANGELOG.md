# Changelog

## Unreleased

- Fix core#1149 AC03 in `Ref Echo Set Impl` (90000): declare the ignored caller `status` input so `Reference.Echo.Get` returns `status: Success` without an unknown-key warning for that key. Other unknown keys still warn. Strengthen `Reference Envelope Tests` (90156) to reject every warning in this scenario. No Label or public signature changes.

- Give every MyApp, Reference and Legacy v2 answer Foundation's envelope (core#1149): each success answer starts with `"status":"Success"` through the new `SetSuccess` in `My Input` (50000), `Ref Input` (90010) and `Legacy Adapter Input` (90102), so Foundation's `UnknownParameter` warning reaches the caller; every input error carries a `code` and `parameter` through `Reject`; caught write/core errors answer `RespondWithLastError()` (`BusinessCentralError`). Contracts declare `status` first in the response chapter, use `ErrorEntry` with a code for every error, and start every success example with `status`. `Reference.Echo.Get` declares `message`. Label texts are unchanged, so no XLF change. `AssertOk` in both test callers now requires `status` = `Success` as the first key; new `AssertErrorCode`, `AssertWarning`, `AssertEnvelopeContract`; new test codeunits 50055, 90156, 90157. Write types still warn on an unknown key; they refuse once core#1148 is deployed.

#### Changed AL objects (core#1149)

| App | Change | Object | ID | Name |
| --- | --- | --- | --- | --- |
| Bifrost Boilerplate Tests | Added | codeunit | 50055 | My Envelope Tests |
| Bifrost Boilerplate Tests | Changed | codeunit | 50050 | My Test Caller |
| Bifrost Boilerplate | Changed | codeunit | 50000 | My Input |
| Bifrost Boilerplate | Changed | codeunit | 50001 | My Item Summary Impl |
| Bifrost Boilerplate | Changed | codeunit | 50003 | My Item List Impl |
| Bifrost Boilerplate | Changed | codeunit | 50005 | My Help Get Impl |
| Bifrost Boilerplate | Changed | codeunit | 50007 | My Hello Get Impl |
| Bifrost Reference Tests | Added | codeunit | 90156 | Reference Envelope Tests |
| Bifrost Reference Tests | Added | codeunit | 90157 | Legacy Envelope Tests |
| Bifrost Reference Tests | Changed | codeunit | 90150 | Ref Test Caller |
| Bifrost Reference | Changed | codeunit | 90000 | Ref Echo Set Impl |
| Bifrost Reference | Changed | codeunit | 90001 | Ref Table Get Impl |
| Bifrost Reference | Changed | codeunit | 90003 | Ref Note Add Impl |
| Bifrost Reference | Changed | codeunit | 90004 | Ref Note Add Process |
| Bifrost Reference | Changed | codeunit | 90007 | Ref Help Get Impl |
| Bifrost Reference | Changed | codeunit | 90010 | Ref Input |
| Bifrost Reference | Changed | codeunit | 90011 | Ref GLAcc Overview Impl |
| Bifrost Reference | Changed | codeunit | 90013 | Ref Maint Create Impl |
| Bifrost Reference | Changed | codeunit | 90014 | Ref Maint Create Process |
| Bifrost Reference | Changed | codeunit | 90016 | Ref Price Adjust |
| Bifrost Reference | Changed | codeunit | 90017 | Ref Price Preview Impl |
| Bifrost Reference | Changed | codeunit | 90018 | Ref Price Apply Impl |
| Bifrost Reference | Changed | codeunit | 90019 | Ref Price Apply Process |
| Bifrost Reference | Changed | codeunit | 90020 | Ref Price Contract |
| Bifrost Reference | Changed | codeunit | 90021 | Ref Exch Rate Get Impl |
| Bifrost Reference | Changed | codeunit | 90023 | Ref Api Key Set Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90100 | Legacy Stock Reserve Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90101 | Legacy Cancel Reserve Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90102 | Legacy Adapter Input |
| Legacy App v2 (headless) | Changed | codeunit | 90103 | Legacy Reserve Process |
| Legacy App v2 (headless) | Changed | codeunit | 90104 | Legacy Cancel Process |
| Legacy App v2 (headless) | Changed | codeunit | 90105 | Legacy Stock Get Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90108 | Legacy Stock List Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90109 | Legacy Release All Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90110 | Legacy Release All Process |
| Legacy App v2 (headless) | Changed | codeunit | 90111 | Legacy Help Get Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90112 | Legacy Stock Contract |

- Keep codeunit 90109 confirmation and bulk release in Foundation's isolated message transaction, preserving rollback and structured HTTP errors after the confirmation locks.

- Replace help markdown codeunits with structured contract chapters for the Boilerplate, Reference and Legacy v2 message types. Keep discovery labels translated in en-US/is-IS and validate the chapters through the dispatcher tests.
- Document the public Foundation API, setup order, permissions and headless adaptation patterns.
- Build all three sample apps and both test apps in CI, install the executable Foundation release before publishing the samples, and fail on analyzer warnings.

- Count the locked, filtered reservation selection through Foundation's `Msg Confirm ori` for `Legacy.Stock.ReleaseAll` (codeunit 90109, enumextension 90100); require Foundation 28.0.11.669. Tests in codeunit 90153 cover mismatch without writes, two matching records with an unrelated record preserved, and zero-record no-op.

### Changed AL objects

Object IDs are scoped to each sample app. Removed help codeunits are listed from the base revision.

| App | Change | Object | ID | Name |
| --- | --- | --- | --- | --- |
| Bifrost Boilerplate Tests | Added | codeunit | 50054 | My Contract Lint |
| Bifrost Boilerplate Tests | Changed | codeunit | 50052 | My Item Tests |
| Bifrost Boilerplate Tests | Changed | codeunit | 50051 | My Selection Card Lint |
| Bifrost Boilerplate Tests | Changed | codeunit | 50050 | My Test Caller |
| Bifrost Boilerplate | Changed | codeunit | 50000 | My Input |
| Bifrost Boilerplate | Removed | codeunit | 50004 | My Item List Help |
| Bifrost Boilerplate | Changed | codeunit | 50003 | My Item List Impl |
| Bifrost Boilerplate | Removed | codeunit | 50002 | My Item Summary Help |
| Bifrost Boilerplate | Changed | codeunit | 50001 | My Item Summary Impl |
| Bifrost Boilerplate | Changed | codeunit | 50007 | My Hello Get Impl |
| Bifrost Boilerplate | Changed | codeunit | 50005 | My Help Get Impl |
| Bifrost Boilerplate | Changed | enumextension | 50000 | My Msg Type |
| Bifrost Reference Tests | Changed | codeunit | 90152 | Asset Maintenance Tests |
| Bifrost Reference Tests | Changed | codeunit | 90155 | Help Sections Lint |
| Bifrost Reference Tests | Changed | codeunit | 90153 | Legacy Adapter Tests |
| Bifrost Reference Tests | Changed | codeunit | 90150 | Ref Test Caller |
| Bifrost Reference Tests | Changed | codeunit | 90151 | Selection Card Lint |
| Bifrost Reference | Removed | codeunit | 90015 | Ref Maint Create Help |
| Bifrost Reference | Changed | codeunit | 90013 | Ref Maint Create Impl |
| Bifrost Reference | Changed | codeunit | 90010 | Ref Input |
| Bifrost Reference | Changed | codeunit | 90023 | Ref Api Key Set Impl |
| Bifrost Reference | Changed | codeunit | 90021 | Ref Exch Rate Get Impl |
| Bifrost Reference | Removed | codeunit | 90027 | Ref Exch Rate Help |
| Bifrost Reference | Removed | codeunit | 90012 | Ref GLAcc Overview Help |
| Bifrost Reference | Changed | codeunit | 90011 | Ref GLAcc Overview Impl |
| Bifrost Reference | Changed | codeunit | 90000 | Ref Echo Set Impl |
| Bifrost Reference | Changed | codeunit | 90007 | Ref Help Get Impl |
| Bifrost Reference | Changed | enumextension | 90000 | Ref Msg Type |
| Bifrost Reference | Removed | codeunit | 90005 | Ref Note Add Help |
| Bifrost Reference | Changed | codeunit | 90003 | Ref Note Add Impl |
| Bifrost Reference | Changed | codeunit | 90001 | Ref Table Get Impl |
| Bifrost Reference | Changed | codeunit | 90018 | Ref Price Apply Impl |
| Bifrost Reference | Added | codeunit | 90020 | Ref Price Contract |
| Bifrost Reference | Removed | codeunit | 90020 | Ref Price Help |
| Bifrost Reference | Changed | codeunit | 90017 | Ref Price Preview Impl |
| Legacy App v1 (not headless) | Changed | codeunit | 90050 | Legacy Stock Mgt |
| Legacy App v2 (headless) | Changed | table | 90051 | Legacy Cancellation Log |
| Legacy App v2 (headless) | Changed | codeunit | 90052 | Legacy Stock API |
| Legacy App v2 (headless) | Removed | codeunit | 90106 | Legacy Adapter Help |
| Legacy App v2 (headless) | Changed | codeunit | 90102 | Legacy Adapter Input |
| Legacy App v2 (headless) | Changed | enumextension | 90100 | Legacy Adapter Msg Type |
| Legacy App v2 (headless) | Changed | codeunit | 90101 | Legacy Cancel Reserve Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90111 | Legacy Help Get Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90109 | Legacy Release All Impl |
| Legacy App v2 (headless) | Added | codeunit | 90112 | Legacy Stock Contract |
| Legacy App v2 (headless) | Changed | codeunit | 90105 | Legacy Stock Get Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90108 | Legacy Stock List Impl |
| Legacy App v2 (headless) | Changed | codeunit | 90100 | Legacy Stock Reserve Impl |
