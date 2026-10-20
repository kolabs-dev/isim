# XCUIAutomation

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Developer tools](../COVERAGE.md#devtools) · **Apple:** [XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation) · **Issues:** [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

## How isim implements it

- **Approach:** adapted, in isim's XCTest framework (`isim/frameworks/XCTest/XCUI.m`), which is where Apple's SDK had
  these APIs before Xcode 26 moved them to XCUIAutomation (`import XCTest` still brings them). The app under test runs
  as its own isim process; queries read its accessibility snapshot (script command `dump`) and actions are script
  commands ([SCRIPTING.md](../SCRIPTING.md): `tap`, `drag`, `pinch`, `rotate2`, `twofinger`, `appearance`,
  `actionbutton`, `privacy`). The rest of XCUITest (applications, queries, elements, system alerts, screenshots) is on
  the [XCTest page](XCTest.md).
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/XCTest` (`XCUIElement.h`,
  `XCUIApplication.h`, `XCUIDevice.h`).
- **Versus Apple's Simulator:** scripted touch has two fingers (more touches are an issue); the accessibility audit
  checks descriptions and hit regions only; a reset privacy answer is cleared when the app next launches.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Multi-touch gestures (`pinch(withScale:velocity:)`, `rotate(_:withVelocity:)`, `twoFingerTap()`, `tap(withNumberOfTaps:numberOfTouches:)`) | ✅ | ≤17 | adapted: two fingers around the element's centre (script commands `pinch`, `rotate2`, `twofinger`), the duration the change over the velocity; more than two touches records an issue and taps with two. Tested (HelloToolchain `AppMultitouchUITests testPinchRotateAndTaps`: test_toolchain.py::test_scheme) |
| Gesture velocities (`XCUIGestureVelocity` `.slow` / `.default` / `.fast`, `swipeUp/Down/Left/Right(velocity:)`, `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)` on elements and coordinates) | ✅ | ≤17 | adapted: points per second (slow 400, default 1000, fast 2500); a swipe or drag lasts its distance over the velocity, and a drag can hold before lifting. Tested (`testSwipeVelocities`, `testDragToElement`) |
| `press(forDuration:thenDragTo:)` from one element to another | ✅ | ≤17 | adapted: centre to centre, a held press then the drag. Tested (`testDragToElement`) |
| `XCUIElementSnapshot` (`snapshot()`, `children`, `dictionaryRepresentation`, `XCUIElementAttributeName`) | ✅ | ≤17 | adapted: the element's attributes and descendants from one accessibility snapshot; `snapshot()` throws when the element does not exist. Tested (`testSnapshot`) |
| `performAccessibilityAudit(for:_:)` (`XCUIAccessibilityAuditType`, `XCUIAccessibilityAuditIssue`) | 🟡 | 17.0 | adapted: controls without an accessibility label (`.sufficientElementDescription`) and smaller than 44 × 44 points (`.hitRegion`); issues the handler does not handle fail the test. Not checked: contrast, element detection, Dynamic Type, clipped text, traits. Tested (`testAccessibilityAudit`) |
| `resetAuthorizationStatus(for:)` (`XCUIProtectedResource`) | ✅ | ≤17 | adapted: the app is terminated (as on iOS) and its stored answers for the resource are cleared when it next launches, so it asks again; the `privacy reset SERVICE` script command does the same in a running app. Bluetooth, HomeKit and keyboard network keep no answer in isim. Tested (`testResetAuthorizationStatus`) |
| `XCUIDevice.appearance` (`XCUIDevice.Appearance`), `press(.action)`, `press(.camera)` | ✅ | ≤17 | adapted: the device's light / dark setting (script command `appearance`), applied to the running app; `.action` presses the Action button (`actionbutton`); `.camera` is ignored (isim has no Camera Control). Tested (`testAppearance`) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
