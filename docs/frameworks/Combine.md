# Combine

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 99.6% of Apple's iOS API (1199 of 1204, exact) · **Rows:** 15: 15 ✅ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [Combine](https://developer.apple.com/documentation/combine) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Adapted:** isim's own implementation (`isim/swift/overlays/Combine`). Upstream demand is always unlimited.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Publisher`, `Subscriber`, `Subscription`, demand | ✅ | ≤17 | isim's own implementation |
| `PassthroughSubject`, `CurrentValueSubject` | ✅ | ≤17 | |
| `@Published`, `ObservableObject`, `objectWillChange` | ✅ | ≤17 | |
| `Just`, `Future`, `Deferred`, `Empty`, `Fail`, `Publishers.Sequence` | ✅ | ≤17 | |
| `sink`, `assign(to:on:)`, `assign(to:)`, `AnyCancellable`, `store(in:)` | ✅ | ≤17 | |
| `map`, `tryMap`, `compactMap`, `filter`, `flatMap`, `removeDuplicates`, `first`, `prefix`, `dropFirst` | ✅ | ≤17 | |
| `merge`, `combineLatest`, `debounce`, `receive(on:)`, `share`, `handleEvents`, `eraseToAnyPublisher`, `setFailureType` | ✅ | ≤17 | |
| `autoconnect`, `ConnectablePublisher` | ✅ | ≤17 | |
| `zip`, `scan`, `reduce`, `collect` (all / count / time), `delay`, `throttle`, `timeout`, `buffer`, `count`, `min`/`max`, `contains`, `allSatisfy`, `first(where:)`, `last`, `output(at:/in:)`, `prefix`/`drop(while:)`, `drop`/`prefix(untilOutputFrom:)`, `append`/`prepend`, `measureInterval`, `subscribe(on:)`, `multicast`/`makeConnectable`, `Record`, `MergeMany`, `CombineLatest3/4`, `Zip3/4`, `try*` variants | ✅ | ≤17 | operators take unlimited demand upstream and queue for the subscriber (Apple propagates demand); `Publishers.Sequence` is lazy and demand-driven. Tested: SwiftExtrasTest |
| `catch`, `tryCatch`, `retry`, `replaceError`, `replaceEmpty`, `mapError`, `assertNoFailure`, `switchToLatest`, `flatMap(maxPublishers:)`, `decode`/`encode` (JSON/property-list coders are `TopLevelDecoder`/`Encoder`) | ✅ | ≤17 | Tested: SwiftExtrasTest |
| `flatMap(maxPublishers:)` backpressure, `Publishers.Merge3`…`Merge8` (and `merge(with:…)` on `Merge`…`Merge7`), `MapKeyPath` / `MapKeyPath2` / `MapKeyPath3`, `First`, `Contains`, the conditional `Equatable` conformances (`Just`, `Fail`, `Empty`, `Output`, `Drop`, `Merge…`, `Zip…`, `CombineLatest`, `Concatenate`, `Retry`, …), Apple's public initializers (`Filter`, `CompactMap`, `TryMap`, `FlatMap`, `HandleEvents`, `ReceiveOn` / `Debounce` with `options`, …), `Subscribers.Demand` Codable, `Future.value`, `Subscribers.Assign` description / mirror, `Record.Recording.encode(into:)` | ✅ | ≤17 | adapted: `flatMap(maxPublishers:)` requests `maxPublishers` values from upstream and one more each time an inner publisher finishes, as Apple's (other operators still request unlimited and queue for their downstream, see above); the merges are `MergeMany` over their publishers; scheduler `options` are passed to the scheduler. Tested: SwiftLibrariesTest (test_swift_libraries) |
| `.values` (`AsyncPublisher` / `AsyncThrowingPublisher`), `print`, `breakpoint`, `handleEvents` (all hooks) | ✅ | ≤17 | `.values` buffers (Apple requests one value per `next()`, so a fast PassthroughSubject loses values there, not on isim). Tested: SwiftExtrasTest |
| Foundation publishers: `Timer.publish`, `NotificationCenter.publisher`; RunLoop/DispatchQueue schedulers | ✅ | ≤17 | |
| `URLSession.dataTaskPublisher` | ✅ | ≤17 | tested |
| KVO publisher (`publisher(for: \.keyPath)`) | ✅ | ≤17 | Foundation KVO; tested with `AVPlayer.timeControlStatus` (HelloVideo) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
5 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func storeWhileEntityActive(Entity)`](https://developer.apple.com/documentation/combine/cancellable/storewhileentityactive(_:))
- [`func combineLatest<P, Q, R, T>(P, Q, R, (Self.Output, P.Output, Q.Output, R.Output) -> T) -> Publishers.Map<Publishers.CombineLatest4<Self, P, Q, R>, T>`](https://developer.apple.com/documentation/combine/publisher/combinelatest(_:_:_:_:))
- [`func zip<P, Q, R, T>(P, Q, R, (Self.Output, P.Output, Q.Output, R.Output) -> T) -> Publishers.Map<Publishers.Zip4<Self, P, Q, R>, T>`](https://developer.apple.com/documentation/combine/publisher/zip(_:_:_:_:))
- [`func schedule(after: Self.SchedulerTimeType, interval: Self.SchedulerTimeType.Stride, tolerance: Self.SchedulerTimeType.Stride, () -> Void) -> any Cancellable`](https://developer.apple.com/documentation/combine/scheduler/schedule(after:interval:tolerance:_:))
- [`func receive() -> Subscribers.Demand`](https://developer.apple.com/documentation/combine/subscriber/receive())

</details>
<!-- /generated:missing -->
