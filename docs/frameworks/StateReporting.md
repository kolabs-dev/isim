# StateReporting

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [StateReporting](https://developer.apple.com/documentation/statereporting) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Approach:** isim's own Swift module (`isim/swift/overlays/StateReporting`): a reporter hands each transition to
  [MetricKit](MetricKit.md), which measures the time, CPU time and logical writes spent in each state and reports them
  in `MetricReport`'s state entries for the domains a `MetricManager` enables. Transitions are logged
  (`isim state: <domain> -> <state>` on stdout, and the `com.apple.statereporting` subsystem in the log store).
- **Macros:** isim's StateReportingMacros compiler plugin (`isim/swift/macro-support/StateReportingMacros.swift`).
- **Objective-C / C interface:** Swift only (as Apple's).
- **Versus Apple's Simulator:** the states reach MetricKit's reports on isim's delivery schedule (a run's at the next
  launch, or `metrickit deliver`).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `StateReporter` (`reporter(for:stableMetadata:volatileMetadata:)`, `domain`, `reportTransition(to:stableMetadata:volatileMetadata:)`, `reportVolatileMetadataUpdate(_:)`) | ✅ | 27.0 | adapted: transitions go to MetricKit's state measurements (a nil state ends the domain's state); volatile metadata is kept but not reported. Tested: test_diagnostics::test_metric_reports_ios27 (HelloDiagnostics, `--os 27`) |
| `ReportableMetadata`, `ReportableMetadataValue` (cases, integer / floating-point / Bool / `CGFloat` / `Date` / `String` initializers) | ✅ | 27.0 | adapted: a Bool is the integer 1 or 0 (proposed). Tested: test_diagnostics::test_metric_reports_ios27 |
| `@ReportableMetadata`, `@ReportableMetadataKey`, `@ReportableMetadataIgnored` | ✅ | 27.0 | adapted: `metadataDictionary` from the stored instance properties (the key's name or the given key; nil optionals and ignored properties left out). Tested: test_diagnostics::test_metric_reports_ios27 |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
