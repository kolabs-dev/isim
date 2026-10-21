# NearbyInteraction

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [NearbyInteraction](https://developer.apple.com/documentation/nearbyinteraction) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator: no Ultra Wideband (`isim/swift/overlays/NearbyInteraction`).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/NearbyInteraction` over the overlay's classes;
  `NINearbyObject.direction` (a simd vector) is Swift-only.
- **Versus Apple's Simulator:** the same.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NISession` (`deviceCapabilities`, `isSupported`, `delegate`, `delegateQueue`, `discoveryToken`, `configuration`, `run(_:)`, `pause()`, `invalidate()`), `NIDeviceCapability`, `NISessionDelegate`, `NIConfiguration`, `NINearbyPeerConfiguration`, `NINearbyAccessoryConfiguration`, `NIDiscoveryToken`, `NINearbyObject`, `NIError` | 🧩 | ≤17 | stub: no capabilities and no discovery token; running a configuration invalidates the session with `unsupportedPlatform`. Not yet: `setARSession(_:)`, `worldTransform(for:)`, algorithm convergence, DL-TDOA. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
