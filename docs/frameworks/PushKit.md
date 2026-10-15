# PushKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 93.3% of Apple's iOS API (28 of 30, exact) · **Rows:** 50% (2: 1 ✅ 1 ❌) · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [PushKit](https://developer.apple.com/documentation/pushkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** fake 32-byte tokens; VoIP payloads come from `isim push`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| VoIP pushes (PushKit) | ✅ | ≤17 | adapted: `PKPushRegistry` with `desiredPushTypes` `.voIP` gets a 32-byte token (`pushRegistry(_:didUpdate:for:)`, `pushToken(for:)`, kept in the app's container; `didInvalidatePushTokenFor` when it no longer wants them); VoIP pushes are `isim push` payloads with a top-level `"apns-push-type": "voip"` (no `aps` needed), delivered to apps with UIBackgroundModes `voip` (launched in the background when not running) as `pushRegistry(_:didReceiveIncomingPushWith:for:completion:)` (or the older method). Like iOS 13+, an app that reports no incoming call to CallKit for a VoIP push is terminated. File provider pushes are never delivered. `PKPushType` is a Swift struct (not an `NSString`), so `PKPushRegistryDelegate` is a Swift protocol with default implementations of its optional methods (Swift only). Tested (HelloCalls: test_calls, OS matrix) |
| Objective-C interface (`PushKit.framework`): `PKPushRegistry` (`initWithQueue:`, `desiredPushTypes`, `pushTokenForType:`), `PKPushRegistryDelegate`, `PKPushCredentials`, `PKPushPayload`, `PKPushType` constants | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names; `PKPushType` is an `NSString`); an Objective-C delegate is called on the registry's queue, and one that only implements the older incoming-push method gets it. Tested (HelloServicesObjC, tests/ui/test_services_objc.py) |
| Types not yet in isim (iOS 26) | ❌ | 26.4 | not implemented, found by the 2026-10 sweep: `PKVoIPPushMetadata` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
2 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`PKVoIPPushMetadata`](https://developer.apple.com/documentation/pushkit/pkvoippushmetadata)
- [`var mustReport: Bool`](https://developer.apple.com/documentation/pushkit/pkvoippushmetadata/mustreport)

</details>
<!-- /generated:missing -->
