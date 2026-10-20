# DarwinNotify

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 44, approximate, by name) · **Rows:** 5: 3 ✅ 1 🟡 1 ❌ · **iOS:** 9.3+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [Darwin Notify](https://developer.apple.com/documentation/darwinnotify) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Approach:** adapted, isim's own (`isim/frameworks/Foundation/Notify.m`, `CFNotificationCenter.m`). Within a
  process, a post reaches the clients directly. Across processes (the app, its extensions, other apps of the device),
  each post is appended to `$ISIM_DATA/Library/isim/notify.log`, and every process with clients watches that log
  (a vnode dispatch source) and delivers the other processes' posts. The log starts again past 4 MB.
- **Objective-C / C interface:** `notify.h`, `notify_keys.h` (`isim/sdk-src/usr/include`); CoreFoundation's
  `CFNotificationCenter.h`.
- **Versus Apple's Simulator:** the same: posts reach other processes of the device; the state of a name
  (`notify_set_state`) stays in its process, Mach port registrations fail, and isim's system does not post the
  `kNotify…` system names.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `notify_post`, `notify_register_check` / `dispatch` / `signal` / `file_descriptor`, `notify_check`, `notify_cancel`, `notify_suspend` / `resume`, `notify_is_valid_token` | ✅ | ≤17 | adapted: delivered to the clients of every process of the device (the post log above). Tested (NotifyTest, two processes: test_notify; LibcTest: test_libc) |
| `notify_set_state` / `notify_get_state` | 🟡 | ≤17 | adapted: the state is kept in the process that set it. Tested (test_libc) |
| `notify_register_mach_port` | ❌ | ≤17 | stub: isim has no Mach ports; it returns `NOTIFY_STATUS_FAILED`. Tested (test_notify) |
| `NOTIFY_STATUS_*`, `NOTIFY_REUSE`, `NOTIFY_TOKEN_INVALID`, `kNotify…` names (`notify_keys.h`) | ✅ | ≤17 | Apple's values; isim's system does not post the `kNotify…` names yet. Tested (test_notify) |
| `CFNotificationCenterGetDarwinNotifyCenter` (add / remove observers, post) | ✅ | ≤17 | adapted: over notify(3), so across processes; callbacks on the main queue, without object or userInfo (as on iOS). Tested (test_notify) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
