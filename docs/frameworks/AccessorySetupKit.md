# AccessorySetupKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator: no Bluetooth or Wi-Fi accessories nearby
  (`isim/frameworks/AccessorySetupKit`); the overlay (`isim/swift/overlays/AccessorySetupKit`) types
  `bluetoothServiceUUID` with CoreBluetooth's `CBUUID`.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/AccessorySetupKit` (the framework is
  Objective-C; `CBUUID` from Objective-C waits for CoreBluetooth's Objective-C interface, #315).
- **Versus Apple's Simulator:** the picker shows no sheet on isim; it completes at once.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ASAccessorySession` (`activate(on:eventHandler:)`, `invalidate()`, `accessories`, `showPicker(for:completionHandler:)`, `removeAccessory`, `renameAccessory`), `ASAccessoryEvent`, `ASAccessoryEventType`, `ASPickerDisplayItem`, `ASDiscoveryDescriptor`, `ASAccessory`, `ASError` | 🧩 | 18.0 | stub: activating sends `.activated`; there are no accessories; the picker completes with `discoveryTimeout`; removing or renaming fails with `invalidRequest`. Not yet: migration items, `finishAuthorization` / `failAuthorization`, the iOS 26 additions. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
