# os and OSLog (logging)

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 87.3% of Apple's iOS API (214 of 245, exact) · **Rows:** 8: 8 ✅ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [os](https://developer.apple.com/documentation/os) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Adapted:** an in-process log store and signposts (`isim/runtime/host_os.c`), under the `os` and `OSLog` Swift overlays.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `os.Logger`, `os_log`, `OSLog` (Swift) | ✅ | ≤17 | levels, `OSLogMessage` interpolation with privacy (strings/objects `<private>` unless `.public`; `.private(mask: .hash)`), number/bool formatting, printf-style `os_log` with `%{public}`; stderr in `log stream` compact style. `ISIM_LOG_PRIVATE=1` shows private values, `ISIM_LOG_LEVEL` filters |
| `os_log` C macros (Objective-C), `os_log_create` | ✅ | ≤17 | clang's `__builtin_os_log_format` buffers decoded by isim's libSystem; same output and privacy rules as Swift |
| Signposts (`OSSignposter`, `os_signpost`, C `os_signpost_*` macros, `os_signpost_id_generate`) | ✅ | ≤17 | adapted: recorded in the process's log store (events, interval begin / end with ids and messages; `OSLogEntrySignpost`); `ISIM_LOG_SIGNPOSTS=1` prints them; the `signposts` script command summarizes intervals (count, total / average / longest duration) like Instruments' Points of Interest. Tested: test_diagnostics |
| `OSLogStore` (reading logs back: `OSLogEntryLog`, `OSLogEntrySignpost`, positions, `getEntries(with:at:matching:)`, components) | ✅ | ≤17 | adapted: `.currentProcessIdentifier` reads this process's messages and signposts (Swift and C `os_log`, `Logger`, `NSLog`; the last 50,000, as shown: private values redacted); NSPredicate over entry properties (`subsystem`, `category`, `composedMessage`, `messageType`, `date`, …), reverse order, positions by date / interval; `formatString` uses `%@` for every interpolated value; the system scope and `local()` throw as on iOS. Tested: test_diagnostics |
| `os_unfair_lock`, `OSAllocatedUnfairLock` (`withLockIfAvailableUnchecked` too), `OSAllocatedUnfairLockFlags` | ✅ | ≤17 | futex-backed, with owner checks; `adaptiveSpin` is accepted as a hint. Tested (SecurityTest) |
| Activities (`os_activity_create`, `os_activity_scope_enter` / `leave`, `os_activity_scope`, `os_activity_apply`, `os_activity_initiate`, `os_activity_get_identifier`, `os_activity_label_useraction`) | ✅ | ≤17 | adapted: activities and their parents are kept in isim's runtime (host_os.c), with identifiers; messages logged in a scope are recorded as usual (isim's log store has no activity column). Tested (SecurityTest: OSLogC.m, issue #353) |
| `os_proc_available_memory` | ✅ | ≤17 | adapted: the simulated device's memory limit minus the app's resident size. Tested (SecurityTest) |
| `Logger.disabled`, `Logger.isEnabled(type:)`, `OSLogMessage.bufferSize` / `interpolation`, `maxOSLogArgumentCount`, extended formats (`OSLogIntExtendedFormat`, Int32 `truth` / `answer` / `machErrno`, pointer `timespec` / `timeval` / `uuid`), `OSSignpostIntervalState` Codable, `OSSignposter.SignpostMetadata`, `OSSignpostAnimationBegin`, `AnimationFormatString`, `OS_LOG_TARGET_HAS_*`, `OS_TRACE_TYPE_*` | ✅ | ≤17 | adapted: extended formats render as `log` shows them ("1.5 MB", "[2: No such file or directory]", a timespec as seconds); `bufferSize` counts 2 header bytes plus 10 per argument. `os_trace_payload_object_t` is not in isim (an XPC object; #357). Tested (SecurityTest, test_security.py) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
31 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`os_trace_payload_object_t`](https://developer.apple.com/documentation/os/os_trace_payload_object_t)
- [`func lock(flags: OSAllocatedUnfairLockFlags)`](https://developer.apple.com/documentation/os/osallocatedunfairlock/lock(flags:))
- [`func withLock<R>(flags: OSAllocatedUnfairLockFlags, (inout State) throws -> R) rethrows -> R`](https://developer.apple.com/documentation/os/osallocatedunfairlock/withlock(flags:_:)-1ub4c)
- [`func withLock<R>(flags: OSAllocatedUnfairLockFlags, () throws -> R) rethrows -> R`](https://developer.apple.com/documentation/os/osallocatedunfairlock/withlock(flags:_:)-u2xj)
- [`func withLockUnchecked<R>(flags: OSAllocatedUnfairLockFlags, (inout State) throws -> R) rethrows -> R`](https://developer.apple.com/documentation/os/osallocatedunfairlock/withlockunchecked(flags:_:)-8cv64)
- [`func withLockUnchecked<R>(flags: OSAllocatedUnfairLockFlags, () throws -> R) rethrows -> R`](https://developer.apple.com/documentation/os/osallocatedunfairlock/withlockunchecked(flags:_:)-9iq8s)
- [`static func exponential(explicitPositiveSign: Bool, uppercase: Bool) -> OSLogFloatFormatting`](https://developer.apple.com/documentation/os/oslogfloatformatting/exponential(explicitpositivesign:uppercase:))
- [`static func hex(explicitPositiveSign: Bool, uppercase: Bool) -> OSLogFloatFormatting`](https://developer.apple.com/documentation/os/oslogfloatformatting/hex(explicitpositivesign:uppercase:))
- [`static func hybrid(explicitPositiveSign: Bool, uppercase: Bool) -> OSLogFloatFormatting`](https://developer.apple.com/documentation/os/oslogfloatformatting/hybrid(explicitpositivesign:uppercase:))
- [`static func hybrid(precision: @autoclosure () -> Int, explicitPositiveSign: Bool, uppercase: Bool) -> OSLogFloatFormatting`](https://developer.apple.com/documentation/os/oslogfloatformatting/hybrid(precision:explicitpositivesign:uppercase:))
- [`static func decimal(explicitPositiveSign: Bool) -> OSLogIntegerFormatting`](https://developer.apple.com/documentation/os/oslogintegerformatting/decimal(explicitpositivesign:))
- [`static func hex(explicitPositiveSign: Bool, includePrefix: Bool, uppercase: Bool) -> OSLogIntegerFormatting`](https://developer.apple.com/documentation/os/oslogintegerformatting/hex(explicitpositivesign:includeprefix:uppercase:))
- [`static func octal(explicitPositiveSign: Bool, includePrefix: Bool, uppercase: Bool) -> OSLogIntegerFormatting`](https://developer.apple.com/documentation/os/oslogintegerformatting/octal(explicitpositivesign:includeprefix:uppercase:))
- [`func appendInterpolation(@autoclosure () -> String, align: OSLogStringAlignment, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:align:privacy:attributes:)-7g68v)
- [`func appendInterpolation(@autoclosure () -> any Any.Type, align: OSLogStringAlignment, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:align:privacy:attributes:)-9hehv)
- [`func appendInterpolation<T>(@autoclosure () -> T, align: OSLogStringAlignment, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:align:privacy:attributes:)-xyum)
- [`func appendInterpolation(@autoclosure () -> UnsafeRawPointer, bytes: @autoclosure () -> Int, format: OSLogPointerFormat, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:bytes:format:privacy:attributes:))
- [`func appendInterpolation(@autoclosure () -> Float, format: OSLogFloatFormatting, align: OSLogStringAlignment, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:format:align:privacy:attributes:)-78sek)
- [`func appendInterpolation<T>(@autoclosure () -> T, format: OSLogIntegerFormatting, align: OSLogStringAlignment, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:format:align:privacy:attributes:)-8107a)
- [`func appendInterpolation(@autoclosure () -> Double, format: OSLogFloatFormatting, align: OSLogStringAlignment, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:format:align:privacy:attributes:)-8bi90)
- [`func appendInterpolation(@autoclosure () -> Int32, format: OSLogInt32ExtendedFormat, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:format:privacy:attributes:)-4i2ir)
- [`func appendInterpolation(@autoclosure () -> Int, format: OSLogIntExtendedFormat, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:format:privacy:attributes:)-6le5w)
- [`func appendInterpolation(@autoclosure () -> UnsafeRawBufferPointer, format: OSLogPointerFormat, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:format:privacy:attributes:)-93lbs)
- [`func appendInterpolation(@autoclosure () -> NSObject, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:privacy:attributes:)-3czd2)
- [`func appendInterpolation(@autoclosure () -> any Error, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:privacy:attributes:)-4o74h)
- [`func appendInterpolation(@autoclosure () -> (any Error)?, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:privacy:attributes:)-6vtcc)
- [`func appendInterpolation(@autoclosure () -> NSObject?, privacy: OSLogPrivacy, attributes: String)`](https://developer.apple.com/documentation/os/osloginterpolation/appendinterpolation(_:privacy:attributes:)-9eafm)
- [`func beginAnimationInterval(StaticString, id: OSSignpostID) -> OSSignpostIntervalState`](https://developer.apple.com/documentation/os/ossignposter/beginanimationinterval(_:id:))
- [`init(UInt8)`](https://developer.apple.com/documentation/os/ossignposttype/init(_:))
- [`init(UInt8)`](https://developer.apple.com/documentation/os/ossignposttype/init(_:))
- [`SignpostMetadata`](https://developer.apple.com/documentation/os/signpostmetadata)

</details>
<!-- /generated:missing -->
