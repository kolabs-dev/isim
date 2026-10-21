# ExternalAccessory

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [ExternalAccessory](https://developer.apple.com/documentation/externalaccessory) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator: no MFi accessories (`isim/frameworks/ExternalAccessory`).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/ExternalAccessory` (the framework is
  Objective-C).
- **Versus Apple's Simulator:** the same.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `EAAccessoryManager` (`shared()`, `connectedAccessories`, `showBluetoothAccessoryPicker(withNameFilter:completion:)`, `registerForLocalNotifications()`), `EAAccessory`, `EAAccessoryDelegate`, `EASession`, the connect / disconnect notifications and keys, `EABluetoothAccessoryPickerError` | 🧩 | ≤17 | stub: no accessory is connected, `EASession` returns nil, and the picker completes with `resultNotFound`. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
