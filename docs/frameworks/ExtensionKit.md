# ExtensionKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [ExtensionKit](https://developer.apple.com/documentation/extensionkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** partial (`isim/swift/overlays/ExtensionKit`): only `AppExtensionScene`, the protocol that frameworks'
  extension scenes refine (DeviceActivity's `DeviceActivityReportScene`). Hosting another app's extension scene in a
  view (`EXHostViewController`, `AppExtensionSceneConfiguration`, `PrimitiveAppExtensionScene`) is not in isim yet.
- **Objective-C / C interface:** none yet (`EXHostViewController` is Objective-C in Apple's SDK).
- **Versus Apple's Simulator:** —

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AppExtensionScene` | 🟡 | ≤17 | adapted: the protocol only, for DeviceActivity's report scenes; tested (HelloScreenTime, test_screen_time) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
