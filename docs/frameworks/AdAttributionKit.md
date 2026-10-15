# AdAttributionKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (51 of 51, exact) · **Rows:** 1: 1 ✅ · **iOS:** 17.4+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [AdAttributionKit](https://developer.apple.com/documentation/adattributionkit) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** a shared local recorder (`_AdAttribution`). `isim adattribution transmit` posts development postbacks.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| AdAttributionKit (`AppImpression` click-through and view-through, `Postback.updateConversionValue`, `PostbackUpdate`, conversion tags, development postbacks) | ✅ | 17.4 | adapted: `AppImpression(compactJWS:)` checks the ad network's JWS (ES256 header, the payload fields Apple documents; the signature only for its shape: isim cannot check it against the network's key registered with Apple); `handleTap()` needs a tap on a `UIEventAttributionView` in the last second (`missingAttributionView` otherwise), records the impression and opens the App Store page URL (no App Store on isim: logged); `beginView` / `endView` record view-throughs of at least two seconds. Conversion values as for SKAdNetwork. Development postbacks (Settings › Developer › Development Postbacks on a device) with `isim adattribution add / list / transmit / clear`: the app's updates fill them and `transmit` POSTs Apple's JSON stanza (fine value in the first postback only), with an unsigned JWS (`alg` none: isim cannot sign as Apple). Tested: test_ad_attribution |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
