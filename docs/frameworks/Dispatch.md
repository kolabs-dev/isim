# Dispatch

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 90.8% of Apple's iOS API (397 of 437, exact) · **Rows:** 14: 13 ✅ 1 🟡 · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [Dispatch](https://developer.apple.com/documentation/dispatch) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Adapted:** isim's own libdispatch (`isim/frameworks/Foundation/Dispatch.mrc.m`, `DispatchIO.mrc.m`) with a Swift overlay.
- Sources run on `poll`, inotify and pidfd (`isim/runtime/posix_extras.inc`).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Main, global and custom serial/concurrent queues, `async`/`sync`/`asyncAfter` | ✅ | ≤17 | |
| Barriers, `DispatchWorkItem`, `dispatchPrecondition`, queue-specific values | ✅ | ≤17 | |
| `dispatch_once` / `dispatch_once_f` (and `pthread_once`) | ✅ | ≤17 | adapted: per predicate: the first caller runs the block with no lock held, so it may run other once-blocks or wait for threads that do; other callers with the same predicate wait for it (before 0.28 one global lock serialized every once-block and nested ones could deadlock, #609: Google Mobile Ads 12). Tested (DispatchTest, test_dispatch) |
| Target queues (`setTarget(queue:)`, `dispatch_set_target_queue`, `target:` / `dispatch_queue_create_with_target`) | ✅ | ≤17 | adapted: a queue's work runs through its target, so queues targeting a serial queue or the main queue are serialized with it, and `getSpecific`, `dispatchPrecondition` / `dispatch_assert_queue` and labels follow the hierarchy. Targets of the main and global queues cannot change, and cycles are refused. A source's target is the queue its handlers run on. Tested (DispatchTest: test_dispatch; SwiftConcurrencyTest: test_swift_concurrency) |
| Initially inactive queues (`.initiallyInactive`, `DISPATCH_QUEUE_SERIAL_INACTIVE` / `_CONCURRENT_INACTIVE`, `dispatch_queue_attr_make_initially_inactive`, `activate()`) | ✅ | ≤17 | Work submitted before `activate()` waits for it. Tested (test_dispatch, test_swift_concurrency) |
| `asyncAndWait` (closure, work item, value-returning, `flags:`), `dispatch_async_and_wait` / `_f`, `dispatch_barrier_async_and_wait` / `_f` | ✅ | ≤17 | The work runs on the queue (its thread, through its target), not inline, unless the caller is already on it. Barriers act like plain items, as for `sync`. Tested (test_dispatch, test_swift_concurrency) |
| `DispatchSerialQueue` (`Attributes`, `init(label:qos:attributes:autoreleaseFrequency:target:)`, `SerialExecutor`: `enqueue`, `asUnownedSerialExecutor`, `checkIsolated`), `DispatchConcurrentQueue` (`Attributes`, init), `dispatch_queue_serial_executor_t` | ✅ | 17 | An actor whose `unownedExecutor` is a `DispatchSerialQueue` runs its jobs on that queue. `assumeIsolated` works on it through `checkIsolated`. Tested (test_swift_concurrency; HelloNetwork's request log: test_network) |
| `DispatchWorkloop` (`Attributes`, `init(label:attributes:autoreleaseFrequency:)`), `dispatch_workloop_create` / `_inactive`, `dispatch_workloop_set_autorelease_frequency` | 🟡 | ≤17 | adapted: a serial queue. isim has no QoS, so items run in submission order rather than by priority. Not yet: the `osWorkgroup` parameter (isim has no `os_workgroup`). Tested (test_dispatch, test_swift_concurrency) |
| `dispatchMain()` / `dispatch_main`, `dispatch_queue_attr_make_with_autorelease_frequency`, `DISPATCH_CURRENT_QUEUE_LABEL`, `MSEC_PER_SEC` | ✅ | ≤17 | `dispatchMain()` runs the main queue's work forever. Every work item runs in its own autorelease pool, whatever the frequency. |
| Dispatch objects as Objective-C objects (`OS_OBJECT_USE_OBJC`): `dispatch_queue_t` and the other C types are `NSObject<OS_dispatch_*> *` in Objective-C (the `dispatch_queue_global_t` / `_serial_t` / `_main_t` / `_concurrent_t` hierarchy as protocols), so ARC retains them and `strong` properties, collections and blocks hold them; creation functions return retained objects, `dispatch_retain` / `dispatch_release` are unavailable under ARC; C, C++ and Swift see C pointers, and `-DOS_OBJECT_USE_OBJC=0` gives them to Objective-C too; `os_log_t` likewise | ✅ | ≤17 | as on Apple's SDK; the objects are `OS_dispatch_*` / `OS_os_log` instances whose `-retain` / `-release` are `dispatch_retain` / `dispatch_release`. Tested: tests/dispatch (objects.m under ARC, main.m with `OS_OBJECT_USE_OBJC=0`), HelloServicesObjC (`strong` queue property) |
| `DispatchGroup`, `DispatchSemaphore`, `concurrentPerform` / `dispatch_apply` | ✅ | ≤17 | |
| Timer sources (`DispatchSource.makeTimerSource`) | ✅ | ≤17 | |
| User-data (add/or/replace), read/write, signal, process, file-system-object, memory-pressure and Mach send/receive sources; registration handlers | ✅ | ≤17 | adapted from kqueue onto Linux, one monitor thread in `poll()`: read sources report readable bytes (a listening socket: pending connections), write sources the pipe's / socket's free space (files and terminals: 1); file-system-object sources wake on inotify and compare `fstat` (write, extend, attrib, link, rename, delete, revoke); process exit on a pidfd (zombies included), fork / exec checked every 50 ms (`/proc` children, executable); Mach receive sources fire while messages are queued on isim's in-process ports, send sources report `.dead`; memory pressure comes from the Simulator's memory warning (`memorywarning [warn\|critical\|normal]`). Not reported: process `.signal`, `.funlock`, Mach `.possible`. Typed `data`/`mask`/`handle` requirements like Apple's overlay. Tested: tests/dispatch, SwiftExtrasTest, HelloAppearance (test_appearance) |
| `DispatchData`, `DispatchIO` (stream / random, `read`/`write`, high/low water, interval, `close`, `barrier`, class `read`/`write`); C `dispatch_data_t` / `dispatch_io_t` (`dispatch_data_create` with each destructor, concat, subrange, map, apply, copy_region; `dispatch_io_create*`, read/write/barrier/close, `dispatch_read`/`dispatch_write`, `_f` variants) | ✅ | ≤17 | isim's own implementation (Foundation, DispatchIO.mrc.m) with the Swift API on top (no copies between them): each channel's operations run in order on its queue; random-access offsets are relative to the descriptor's position at creation; Apple's default water marks (low 512 KiB, high unlimited), strict and non-strict intervals; path channels need an absolute path, open errors go to the handlers and the cleanup handler. `dispatch_data_t` is not toll-free bridged to `NSData` (adapted). Tested: tests/dispatch, SwiftExtrasTest |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
40 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func dispatch_allow_send_signals(Int32) -> Int32`](https://developer.apple.com/documentation/dispatch/dispatch_allow_send_signals(_:))
- [`var DISPATCH_API_VERSION: Int32`](https://developer.apple.com/documentation/dispatch/dispatch_api_version)
- [`var DISPATCH_APPLY_AUTO_AVAILABLE: Int32`](https://developer.apple.com/documentation/dispatch/dispatch_apply_auto_available)
- [`var DISPATCH_ONCE_INLINE_FASTPATH: Int32`](https://developer.apple.com/documentation/dispatch/dispatch_once_inline_fastpath)
- [`dispatch_source_mach_recv_flags_t`](https://developer.apple.com/documentation/dispatch/dispatch_source_mach_recv_flags_t)
- [`var DISPATCH_SWIFT3_OVERLAY: Int32`](https://developer.apple.com/documentation/dispatch/dispatch_swift3_overlay)
- [`init?(rawValue: qos_class_t)`](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass-swift.enum/init(rawvalue:))
- [`init?(rawValue: qos_class_t)`](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass-swift.enum/init(rawvalue:))
- [`var rawValue: qos_class_t`](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass-swift.enum/rawvalue)
- [`var rawValue: qos_class_t`](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass-swift.enum/rawvalue)
- [`func asyncAfterUnsafe(deadline: DispatchTime, qos: DispatchQoS, flags: DispatchWorkItemFlags, execute: () -> Void)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/asyncafterunsafe(deadline:qos:flags:execute:))
- [`func asyncAfterUnsafe(wallDeadline: DispatchWallTime, qos: DispatchQoS, flags: DispatchWorkItemFlags, execute: () -> Void)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/asyncafterunsafe(walldeadline:qos:flags:execute:))
- [`func asyncUnsafe(group: DispatchGroup?, qos: DispatchQoS, flags: DispatchWorkItemFlags, execute: () -> Void)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/asyncunsafe(group:qos:flags:execute:))
- [`var qos: DispatchQoS`](https://developer.apple.com/documentation/dispatch/dispatchqueue/qos)
- [`var flags: DispatchWorkItemFlags`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/flags)
- [`var flags: DispatchWorkItemFlags`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/flags)
- [`var group: DispatchGroup?`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/group)
- [`var group: DispatchGroup?`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/group)
- [`init(qos: DispatchQoS, flags: DispatchWorkItemFlags, group: DispatchGroup?)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/init(qos:flags:group:))
- [`init(qos: DispatchQoS, flags: DispatchWorkItemFlags, group: DispatchGroup?)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/init(qos:flags:group:))
- [`var qos: DispatchQoS`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/qos)
- [`var qos: DispatchQoS`](https://developer.apple.com/documentation/dispatch/dispatchqueue/scheduleroptions/qos)
- [`func advanced(by: DispatchQueue.SchedulerTimeType.Stride) -> DispatchQueue.SchedulerTimeType`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/advanced(by:))
- [`func advanced(by: DispatchQueue.SchedulerTimeType.Stride) -> DispatchQueue.SchedulerTimeType`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/advanced(by:))
- [`var dispatchTime: DispatchTime`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/dispatchtime)
- [`var dispatchTime: DispatchTime`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/dispatchtime)
- [`func distance(to: DispatchQueue.SchedulerTimeType) -> DispatchQueue.SchedulerTimeType.Stride`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/distance(to:))
- [`func distance(to: DispatchQueue.SchedulerTimeType) -> DispatchQueue.SchedulerTimeType.Stride`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/distance(to:))
- [`init(DispatchTime)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/init(_:))
- [`init(DispatchTime)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/schedulertimetype/init(_:))
- [`DispatchSourceProtocol.DispatchSourceHandler`](https://developer.apple.com/documentation/dispatch/dispatchsourceprotocol/dispatchsourcehandler)
- [`DispatchSourceProtocol.DispatchSourceHandler`](https://developer.apple.com/documentation/dispatch/dispatchsourceprotocol/dispatchsourcehandler)
- [`func scheduleOneshot(deadline: DispatchTime, leeway: DispatchTimeInterval)`](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/scheduleoneshot(deadline:leeway:))
- [`func scheduleOneshot(wallDeadline: DispatchWallTime, leeway: DispatchTimeInterval)`](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/scheduleoneshot(walldeadline:leeway:))
- [`func scheduleRepeating(deadline: DispatchTime, interval: DispatchTimeInterval, leeway: DispatchTimeInterval)`](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/schedulerepeating(deadline:interval:leeway:)-3k199)
- [`func scheduleRepeating(deadline: DispatchTime, interval: Double, leeway: DispatchTimeInterval)`](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/schedulerepeating(deadline:interval:leeway:)-4wtot)
- [`func scheduleRepeating(wallDeadline: DispatchWallTime, interval: Double, leeway: DispatchTimeInterval)`](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/schedulerepeating(walldeadline:interval:leeway:)-6fiox)
- [`func scheduleRepeating(wallDeadline: DispatchWallTime, interval: DispatchTimeInterval, leeway: DispatchTimeInterval)`](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/schedulerepeating(walldeadline:interval:leeway:)-942p7)
- [`OS_dispatch_queue_global`](https://developer.apple.com/documentation/dispatch/os_dispatch_queue_global-swift.class)
- [`OS_dispatch_queue_main`](https://developer.apple.com/documentation/dispatch/os_dispatch_queue_main-swift.class)

</details>
<!-- /generated:missing -->
