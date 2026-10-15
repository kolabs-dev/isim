# os and OSLog (logging)

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 84.1% of Apple's iOS API (206 of 245, exact) · **Rows:** 7: 5 ✅ 2 ❌ · **iOS:** 8.0+
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
| `os_unfair_lock`, `OSAllocatedUnfairLock` | ✅ | ≤17 | futex-backed, with owner checks |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `AnimationFormatString`, `OSLogIntExtendedFormat`, `OSSignpostAnimationBegin` (3 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `OSAllocatedUnfairLockFlags` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
39 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AnimationFormatString`](https://developer.apple.com/documentation/os/animationformatstring)
- [`AnimationFormatString.OSLogMessage`](https://developer.apple.com/documentation/os/animationformatstring/oslogmessage)
- [`init(stringLiteral: String)`](https://developer.apple.com/documentation/os/animationformatstring/oslogmessage/init(stringliteral:))
- [`static var disabled: Logger`](https://developer.apple.com/documentation/os/logger/disabled)
- [`func isEnabled(type: OSLogType) -> Bool`](https://developer.apple.com/documentation/os/logger/isenabled(type:))
- [`var maxOSLogArgumentCount: UInt8`](https://developer.apple.com/documentation/os/maxoslogargumentcount)
- [`var OS_ATOMIC_USES_CXX: Int32`](https://developer.apple.com/documentation/os/os_atomic_uses_cxx)
- [`var OS_LOG_STRING_SECTION: String`](https://developer.apple.com/documentation/os/os_log_string_section)
- [`var OS_LOG_TARGET_HAS_10_12_FEATURES: Int32`](https://developer.apple.com/documentation/os/os_log_target_has_10_12_features)
- [`var OS_LOG_TARGET_HAS_10_13_FEATURES: Int32`](https://developer.apple.com/documentation/os/os_log_target_has_10_13_features)
- [`var OS_LOG_TARGET_HAS_10_14_FEATURES: Int32`](https://developer.apple.com/documentation/os/os_log_target_has_10_14_features)
- [`var OS_LOG_TARGET_HAS_10_15_FEATURES: Int32`](https://developer.apple.com/documentation/os/os_log_target_has_10_15_features)
- [`os_trace_payload_object_t`](https://developer.apple.com/documentation/os/os_trace_payload_object_t)
- [`var OS_TRACE_TYPE_DEBUG: UInt32`](https://developer.apple.com/documentation/os/os_trace_type_debug)
- [`var OS_TRACE_TYPE_INFO: UInt32`](https://developer.apple.com/documentation/os/os_trace_type_info)
- [`var OS_TRACE_TYPE_RELEASE: UInt32`](https://developer.apple.com/documentation/os/os_trace_type_release)
- [`func withLockIfAvailableUnchecked<R>((inout State) throws -> R) rethrows -> R?`](https://developer.apple.com/documentation/os/osallocatedunfairlock/withlockifavailableunchecked(_:)-15q0y)
- [`func withLockIfAvailableUnchecked<R>(() throws -> R) rethrows -> R?`](https://developer.apple.com/documentation/os/osallocatedunfairlock/withlockifavailableunchecked(_:)-6gji7)
- [`OSAllocatedUnfairLockFlags`](https://developer.apple.com/documentation/os/osallocatedunfairlockflags)
- [`static let adaptiveSpin: OSAllocatedUnfairLockFlags`](https://developer.apple.com/documentation/os/osallocatedunfairlockflags/adaptivespin)
- [`case answer`](https://developer.apple.com/documentation/os/oslogint32extendedformat/answer)
- [`case machErrno`](https://developer.apple.com/documentation/os/oslogint32extendedformat/macherrno)
- [`case truth`](https://developer.apple.com/documentation/os/oslogint32extendedformat/truth)
- [`OSLogIntExtendedFormat`](https://developer.apple.com/documentation/os/oslogintextendedformat)
- [`case bitrate`](https://developer.apple.com/documentation/os/oslogintextendedformat/bitrate)
- [`case bitrateIEC`](https://developer.apple.com/documentation/os/oslogintextendedformat/bitrateiec)
- [`case byteCount`](https://developer.apple.com/documentation/os/oslogintextendedformat/bytecount)
- [`case byteCountIEC`](https://developer.apple.com/documentation/os/oslogintextendedformat/bytecountiec)
- [`case secondsSince1970`](https://developer.apple.com/documentation/os/oslogintextendedformat/secondssince1970)
- [`var bufferSize: Int`](https://developer.apple.com/documentation/os/oslogmessage/buffersize)
- [`let interpolation: OSLogInterpolation`](https://developer.apple.com/documentation/os/oslogmessage/interpolation)
- [`case timespec`](https://developer.apple.com/documentation/os/oslogpointerformat/timespec)
- [`case timeval`](https://developer.apple.com/documentation/os/oslogpointerformat/timeval)
- [`case uuid`](https://developer.apple.com/documentation/os/oslogpointerformat/uuid)
- [`OSSignpostAnimationBegin`](https://developer.apple.com/documentation/os/ossignpostanimationbegin)
- [`case animationBegin`](https://developer.apple.com/documentation/os/ossignpostanimationbegin/animationbegin)
- [`func encode(to: any Encoder) throws`](https://developer.apple.com/documentation/os/ossignpostintervalstate/encode(to:))
- [`init(from: any Decoder) throws`](https://developer.apple.com/documentation/os/ossignpostintervalstate/init(from:))
- [`SignpostMetadata`](https://developer.apple.com/documentation/os/signpostmetadata)

</details>
<!-- /generated:missing -->
