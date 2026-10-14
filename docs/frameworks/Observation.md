# Observation

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 52.8% of Apple's iOS API (19 of 36, exact) · **iOS:** 17.0+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [Observation](https://developer.apple.com/documentation/observation) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- Swift's own Observation sources, built for isim. Rows: [Swift](Swift.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `ObservationTracking` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
17 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`ObservationTracking`](https://developer.apple.com/documentation/observation/observationtracking)
- [`ObservationTracking.Event`](https://developer.apple.com/documentation/observation/observationtracking/event)
- [`func cancel()`](https://developer.apple.com/documentation/observation/observationtracking/event/cancel())
- [`var kind: ObservationTracking.Event.Kind`](https://developer.apple.com/documentation/observation/observationtracking/event/kind-swift.property)
- [`ObservationTracking.Event.Kind`](https://developer.apple.com/documentation/observation/observationtracking/event/kind-swift.struct)
- [`static var `deinit`: ObservationTracking.Event.Kind`](https://developer.apple.com/documentation/observation/observationtracking/event/kind-swift.struct/deinit)
- [`static var didSet: ObservationTracking.Event.Kind`](https://developer.apple.com/documentation/observation/observationtracking/event/kind-swift.struct/didset)
- [`static var initial: ObservationTracking.Event.Kind`](https://developer.apple.com/documentation/observation/observationtracking/event/kind-swift.struct/initial)
- [`static var willSet: ObservationTracking.Event.Kind`](https://developer.apple.com/documentation/observation/observationtracking/event/kind-swift.struct/willset)
- [`func matches(PartialKeyPath<some Observable>) -> Bool`](https://developer.apple.com/documentation/observation/observationtracking/event/matches(_:))
- [`ObservationTracking.Options`](https://developer.apple.com/documentation/observation/observationtracking/options)
- [`static var `deinit`: ObservationTracking.Options`](https://developer.apple.com/documentation/observation/observationtracking/options/deinit)
- [`static var didSet: ObservationTracking.Options`](https://developer.apple.com/documentation/observation/observationtracking/options/didset)
- [`static var willSet: ObservationTracking.Options`](https://developer.apple.com/documentation/observation/observationtracking/options/willset)
- [`ObservationTracking.Token`](https://developer.apple.com/documentation/observation/observationtracking/token)
- [`func cancel()`](https://developer.apple.com/documentation/observation/observationtracking/token/cancel())
- [`func withContinuousObservation(options: ObservationTracking.Options, apply: (borrowing ObservationTracking.Event) -> Void) -> ObservationTracking.Token`](https://developer.apple.com/documentation/observation/withcontinuousobservation(options:apply:))

</details>
<!-- /generated:missing -->
