# CoreLocationUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [CoreLocationUI](https://developer.apple.com/documentation/corelocationui) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** adapted. `CLLocationButton` is isim's control (`isim/frameworks/CoreLocationUI`), drawn like iOS's (the
  arrow and label in white on the tint colour, rounded). SwiftUI's `LocationButton` is in the overlay
  (`isim/swift/overlays/CoreLocationUI`). A tap grants when-in-use location authorization for the rest of the run,
  through Core Location, before the app's action runs.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/CoreLocationUI` (the framework is Objective-C).
- **Versus Apple's Simulator:** the same temporary authorization; iOS shows a one-time prompt the first time an app's
  button is tapped, isim grants it without one.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CLLocationButton` (`icon`: `CLLocationButtonIcon`; `label`: `CLLocationButtonLabel`; `fontSize`; `cornerRadius`) | ✅ | 15.0 | adapted: a UIControl; touch-up-inside grants temporary when-in-use authorization (not remembered after the run), then sends the app's actions. Tested (HelloAccessories: test_location_button, per iOS version) |
| `LocationButton` (`init(action:)`, `init(_:action:)`, `LocationButton.Title`) | ✅ | 15.0 | adapted: a SwiftUI button with the location arrow and the title; same authorization as CLLocationButton. Tested (HelloAccessories: test_location_button, per iOS version) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
