# AdServices

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (18 of 18, exact) · **Rows:** 100% (1: 1 ✅) · **iOS:** 14.3+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [AdServices](https://developer.apple.com/documentation/adservices) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Stub:** `attributionToken()` throws `platformNotSupported`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| AdServices (`AAAttribution.attributionToken`) | ✅ | ≤17 | adapted: the token comes from Apple Ads for an App Store install, which isim does not have: it throws `AAAttributionError.platformNotSupported` (logged), so apps take their no-attribution path. Tested: test_ad_attribution |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
