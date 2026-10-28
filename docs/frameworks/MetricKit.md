# MetricKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 91.2% of Apple's iOS API (618 of 678, exact) · **Rows:** 4: 3 ✅ 1 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [MetricKit](https://developer.apple.com/documentation/metrickit) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Adapted:** measured from the app's own process (`isim/runtime/host_diag.c`). Payloads arrive at the next launch, or on demand with `metrickit deliver`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| MetricKit (`MXMetricManager`, subscribers, `MXMetricPayload`/`MXDiagnosticPayload`, metrics, diagnostics, `mxSignpost`, `MXSignpostRecord`, extended launch, `jsonRepresentation`) | ✅ | ≤17 | adapted: measured from the app's process once it uses `MXMetricManager.shared`: CPU time, peak and suspended memory, logical writes, time to first draw, resume time, extended launch, hangs (main thread away from its event loop ≥ 250 ms), foreground / background (audio, location) time, network bytes (as Wi-Fi), location time by accuracy, frame hitches (per foreground second, all animations), average pixel luminance, exits (from crash reports), `mxSignpost` intervals; GPU time 0 (CPU drawing), instructions not counted, no cellular metrics. Metric payloads: each run's, at the next launch (iOS: daily); `metrickit deliver` / `isim metrickit deliver` now. Diagnostics as they happen: hangs (sampled stack), slow launch (≥ 2 s), CPU (80 % over 3 min), disk writes (1 GiB); crashes at the next launch. `metrickit` alone: Xcode's fixed sample payloads. `pastPayloads` since `shared` was first used. Tested: test_diagnostics, HelloCloudKit |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `MXError`, `MXError.Code`, `MXLaunchTaskID` (3 types; with their members under "Not yet in isim") |
| `MXDiskSpaceUsageMetric`, `MXMetricPayload.diskSpaceUsageMetrics` | ✅ | 26.0 | adapted: measured when the payload is made: the app bundle's files (binary), the data container's files and its Library/Caches, the file system's capacity and use; clone size 0 (isim's file systems do not clone). Tested: test_diagnostics |
| `MetricManager` (`metricReports`, `diagnosticReports`, `enabledStateReportingDomains`, `logHandle(category:)`, `trackLaunchTask` sync / async, `LaunchTaskError`, `ReportedState`), `MetricReport` (environment, interval and state entries, `EncodingFormat`, Codable), `MetricResult` and its metric types, `MetricGroup`, `Histogram`, `AverageStatistics`, `SignalBars` / `HitchTimeRatio` / `AveragePixelLuminance`, `DiagnosticReport` / `DiagnosticResult` and the diagnostics, `CallStackTree` / `CallStackThread` / `CallStackFrame`, `OSVersion`, `SignpostRecord`, `StateReportingDomain`, `LaunchTaskID`, `Array.byStateReportingDomain`, `mxSignpostAnimationIntervalBegin(dso:log:name:signpostID:_:_:)` | ✅ | 27.0 | adapted: the same measurements and delivery as `MXMetricManager`, as async sequences: a `MetricReport` per metric payload (its values in one interval entry over the report's time range, with the states of the enabled domains; a state entry per state with the CPU time and logical writes measured in it, from [StateReporting](StateReporting.md)), a `DiagnosticReport` per diagnostic (a diagnostic made in this process carries the domains' current states); `trackLaunchTask` counts toward the extended launch (errors after the first frame: `pastDeadline`). Not measured: Metal frame rates (no `metalFrameRate` values), memory exceptions (isim does not limit memory). Members Apple does not document (`StateReportingDomain`'s initializer, `TerminationReason`'s content) are isim's (proposed). Tested: test_diagnostics::test_metric_reports_ios27 (HelloDiagnostics, `--os 27`) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
60 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var hitchTimeRatio: Measurement<Unit>`](https://developer.apple.com/documentation/metrickit/mxanimationmetric/hitchtimeratio)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxaverage/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxbackgroundexitdata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxcallstacktree/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxcrashdiagnosticobjectivecexceptionreason/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxdiagnostic/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxdiagnosticpayload/init(coder:))
- [`MXError`](https://developer.apple.com/documentation/metrickit/mxerror)
- [`MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/code)
- [`MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/code)
- [`MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/code)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metrickit/mxerror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metrickit/mxerror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metrickit/mxerror/code/init(rawvalue:))
- [`case launchTaskDuplicated`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskduplicated)
- [`case launchTaskDuplicated`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskduplicated)
- [`case launchTaskDuplicated`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskduplicated)
- [`case launchTaskInternalFailure`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskinternalfailure)
- [`case launchTaskInternalFailure`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskinternalfailure)
- [`case launchTaskInternalFailure`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskinternalfailure)
- [`case launchTaskInvalidID`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskinvalidid)
- [`case launchTaskInvalidID`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskinvalidid)
- [`case launchTaskInvalidID`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskinvalidid)
- [`case launchTaskMaxCount`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskmaxcount)
- [`case launchTaskMaxCount`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskmaxcount)
- [`case launchTaskMaxCount`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskmaxcount)
- [`case launchTaskPastDeadline`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskpastdeadline)
- [`case launchTaskPastDeadline`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskpastdeadline)
- [`case launchTaskPastDeadline`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskpastdeadline)
- [`case launchTaskUnknown`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskunknown)
- [`case launchTaskUnknown`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskunknown)
- [`case launchTaskUnknown`](https://developer.apple.com/documentation/metrickit/mxerror/code/launchtaskunknown)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/metrickit/mxerror/errordomain)
- [`static var launchTaskDuplicated: MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/launchtaskduplicated)
- [`static var launchTaskInternalFailure: MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/launchtaskinternalfailure)
- [`static var launchTaskInvalidID: MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/launchtaskinvalidid)
- [`static var launchTaskMaxCount: MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/launchtaskmaxcount)
- [`static var launchTaskPastDeadline: MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/launchtaskpastdeadline)
- [`static var launchTaskUnknown: MXError.Code`](https://developer.apple.com/documentation/metrickit/mxerror/launchtaskunknown)
- [`let MXErrorDomain: String`](https://developer.apple.com/documentation/metrickit/mxerrordomain)
- [`let MXErrorDomain: String`](https://developer.apple.com/documentation/metrickit/mxerrordomain)
- [`let MXErrorDomain: String`](https://developer.apple.com/documentation/metrickit/mxerrordomain)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxforegroundexitdata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxhistogram/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxhistogrambucket/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxhistogrambucket/init(coder:))
- [`MXLaunchTaskID`](https://developer.apple.com/documentation/metrickit/mxlaunchtaskid)
- [`MXLaunchTaskID`](https://developer.apple.com/documentation/metrickit/mxlaunchtaskid)
- [`init(String)`](https://developer.apple.com/documentation/metrickit/mxlaunchtaskid/init(_:))
- [`init(String)`](https://developer.apple.com/documentation/metrickit/mxlaunchtaskid/init(_:))
- [`init(rawValue: String)`](https://developer.apple.com/documentation/metrickit/mxlaunchtaskid/init(rawvalue:))
- [`init(rawValue: String)`](https://developer.apple.com/documentation/metrickit/mxlaunchtaskid/init(rawvalue:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxmetadata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxmetric/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxmetricpayload/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxsignpostintervaldata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxsignpostintervaldata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/metrickit/mxsignpostrecord/init(coder:))

</details>
<!-- /generated:missing -->
