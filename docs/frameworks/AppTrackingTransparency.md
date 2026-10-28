# AppTrackingTransparency

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (19 of 19, exact) · **Rows:** 2: 2 ✅ · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [AppTrackingTransparency](https://developer.apple.com/documentation/apptrackingtransparency) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** an iOS-style prompt; the answer is remembered per app.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ATTrackingManager.requestTrackingAuthorization`, `trackingAuthorizationStatus` | ✅ | ≤17 | iOS-style prompt; choice persists per app; missing usage string is logged. Tested: HelloSignIn, test_privacy |
| `requestTrackingAuthorization(preferExpandedInterface:additionalInformationAction:completionHandler:)` (and its async form) | ✅ | 27.2 | adapted: isim's rendition of the expanded interface, a sheet with the purpose string, Allow / Ask App Not to Track and, when the app gives an action, Learn More (runs it; the sheet stays); `false` shows the alert. Swift only for now (the Objective-C selector is not published yet). Tested (HelloAgeRange, test_agerange) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
