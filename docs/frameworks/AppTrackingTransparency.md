# AppTrackingTransparency

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (19 of 19, exact) · **Rows:** 1: 1 ✅ · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [AppTrackingTransparency](https://developer.apple.com/documentation/apptrackingtransparency) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** an iOS-style prompt; the answer is remembered per app.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ATTrackingManager.requestTrackingAuthorization`, `trackingAuthorizationStatus` | ✅ | ≤17 | iOS-style prompt; choice persists per app; missing usage string is logged. Tested: HelloSignIn, test_privacy |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
