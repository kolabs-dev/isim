# os and OSLog (logging)

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 99.2% of Apple's iOS API (243 of 245, exact) · **Rows:** 8: 8 ✅ · **iOS:** 8.0+
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
2 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`os_trace_payload_object_t`](https://developer.apple.com/documentation/os/os_trace_payload_object_t)
- [`SignpostMetadata`](https://developer.apple.com/documentation/os/signpostmetadata)

</details>
<!-- /generated:missing -->
