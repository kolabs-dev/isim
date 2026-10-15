# AdSupport

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (4 of 4, exact) · **Rows:** 1: 1 ✅ · **iOS:** 6.0+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [AdSupport](https://developer.apple.com/documentation/adsupport) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** the IDFA is a per-device UUID, given after Allow.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ASIdentifierManager` (IDFA, `isAdvertisingTrackingEnabled`) | ✅ | ≤17 | all zeros unless the app's ATT answer is Allow; then a random per-device UUID kept in the device data (stable across apps and launches, new after `isim reset`). Nothing is sent. Tested: HelloSignIn, test_privacy |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
