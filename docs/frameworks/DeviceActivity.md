# DeviceActivity

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [DeviceActivity](https://developer.apple.com/documentation/deviceactivity) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/DeviceActivity`):
  - `DeviceActivityCenter.startMonitoring` validates the schedule as iOS does (authorization, date components, an
    interval of 15 minutes to a week, at most 20 activities) and keeps the app's activities in
    `<isim data>/Library/isim/ScreenTime/Monitoring/<bundle id>.json`;
  - the home screen (`isim/system/SpringBoard/SBScreenTime.m`) follows them on Screen Time's clock and runs the app's
    Device Activity Monitor extension (`com.apple.deviceactivity.monitor-extension`) as a helper process: at an
    interval's start and end, the schedule's warning time before them, and when an event's usage reaches its threshold
    (or its warning);
  - isim does not measure app usage: `isim screentime usage APP MINUTES` records it, and `isim screentime clock
    +MINUTES` moves Screen Time's clock (to reach an interval's end without waiting; SCRIPTING.md);
  - `DeviceActivityReport` runs the app's Device Activity Report extension (`com.apple.deviceactivityui.report-extension`)
    in the app's process and shows its scene's view for the filter, with data from the recorded usage.
- **Objective-C / C interface:** Swift only (as in Apple's SDK).
- **Versus Apple's Simulator:** Apple's Simulator does not call monitor extensions; isim does, on a clock scripts move.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `DeviceActivityCenter` (`startMonitoring(_:during:events:)`, `stopMonitoring(_:)`, `activities`, `schedule(for:)`, `events(for:)`, `MonitoringError`) | ✅ | ≤17 | adapted: iOS's validation, kept on the device; tested (HelloScreenTime, test_screen_time) |
| `DeviceActivityName`, `DeviceActivitySchedule` (`nextInterval`), `DeviceActivityEvent` (`includesPastActivity`) | ✅ | ≤17 | adapted: daily intervals; tested (HelloScreenTime, test_screen_time) |
| `DeviceActivityMonitor` (`intervalDidStart`, `intervalDidEnd`, `intervalWillStartWarning`, `intervalWillEndWarning`, `eventDidReachThreshold`, `eventWillReachThresholdWarning`) | ✅ | ≤17 | adapted: the monitor extension runs as a helper on Screen Time's clock; tested (HelloScreenTime, test_screen_time) |
| `DeviceActivityReport`, `DeviceActivityReportScene`, `DeviceActivityReportExtension`, `DeviceActivityFilter`, `DeviceActivityResults`, `DeviceActivityData` | ✅ | ≤17 | adapted: the report extension's scene in the app, data from recorded usage; tested (HelloScreenTime, test_screen_time) |
| `DeviceActivityAuthorization`, `DeviceActivityAuthorizing` | 🟡 | 17.0 | adapted: Screen Time's answers on the device; proposed |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
