# Darwin (C library, POSIX, Mach)

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Rows:** 92% (13: 11 ✅ 2 🟡)
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Passthrough:** the host's glibc, through a libSystem shim that translates errno values, signals and structures (`isim/runtime/libsystem.c`, `darwin_extras.inc`).
- **Adapted:**
  - the SDK headers are isim's own subset (`isim/sdk-src/usr/include`);
  - Mach is in-process (`isim/runtime/mach.inc`);
  - `sysctl` / `uname` give fixed answers, like Apple's Simulator on an Intel Mac.
- **Passthrough:** SQLite, zlib and libc++ are the host's (libc++ 22 is built for isim).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| libc / POSIX (stdio, malloc, string, pthreads, time, files) | 🟡 | ≤17 | host glibc with Darwin layouts. Binaries get the host functions, but the SDK headers are a subset: no `sys/mman.h`, `sys/sysctl.h`, `sys/utsname.h`, `sys/event.h`, `execinfo.h`, `wchar.h`, `regex.h`, `notify.h`, `syslog.h`, `pwd.h`, `termios.h` |
| Darwin locales (`newlocale`, `uselocale`, `localeconv`, `<xlocale.h>` `_l` functions), `<ctype.h>` rune tables | ✅ | ≤17 | adapted: the host's glibc locale objects (NULL = the C locale); `setlocale` records the app's choice without changing the host process's locale. Tested: test_system_objc |
| libc++ iostreams, locales, `<regex>`, `std::shared_mutex`, `<memory_resource>` | ✅ | ≤17 | libc++ 22 built with localization (char only; no wide characters, `<filesystem>`, `random_device` or `to_chars` for floating point). Tested: test_system_objc |
| zlib (`libz`), libcompression (`compression_encode_buffer`/`decode`) | 🟡 | ≤17 | passthrough: the host's zlib; libcompression supports `COMPRESSION_ZLIB` only (LZFSE, LZ4, LZMA fail). Tested: test_system_objc |
| `pipe`, `pread`/`pwrite`, `dup`/`dup2`, `kill`, `signal`/`raise` with Darwin signal numbers (`SIGUSR1` = 30, ...); Swift `open`/`fcntl`/`ioctl` and `SIG_IGN`/`SIG_DFL` | ✅ | ≤17 | numbers translated to the host's and back for handlers. Tested: SwiftExtrasTest (pipe sources, `raise(SIGUSR1)`) |
| `flock` (`<sys/file.h>`: `LOCK_SH`/`LOCK_EX`/`LOCK_NB`/`LOCK_UN`), `<sys/stat.h>` mode bits (`S_IRWXU` … `S_ISVTX`, `S_IF*`) | ✅ | ≤17 | `flock` passthrough (lock values match Linux); the mode bits are `mode_t` as in Apple's Darwin overlay, so Swift's `open(path, flags, S_IRUSR \| S_IWUSR)` takes the non-variadic form. Tested: SwiftExtrasTest (POSIX) |
| `errno` from Swift | ✅ | ≤17 | the Darwin overlay (`import Darwin`, also through Foundation) reads and sets the thread's `errno`, translated to Darwin values; the Foundation overlay's old copy stays for ABI. Tested (swift-extras POSIXTests) |
| `dlopen` of app-bundled dylibs/frameworks, `dlsym`, `dladdr`, `dlopen_preflight`, `NSBundle` code loading | ✅ | ≤17 | adapted: isim's loader maps dylibs, `MH_BUNDLE`s and frameworks (Objective-C and Swift) with their own dependencies, TLV, initializers, `+load`, categories; paths with `@rpath` / `@executable_path` / `@loader_path` (from the calling image), `RTLD_NOLOAD`, `RTLD_FIRST`; `dlsym` on a handle searches its dependencies, `RTLD_DEFAULT` / `RTLD_MAIN_ONLY` / `RTLD_NEXT` / `RTLD_SELF`; an image or dependency that cannot load fails with a dyld-style `dlerror` (the app keeps running). `NSBundle` `load`, `loadAndReturnError:`, `preflightAndReturnError:`, `isLoaded`, `principalClass` (`NSPrincipalClass`, else the first class), `classNamed:`, `allFrameworks`, `allBundles`. Images are never unloaded (`dlclose` / `unload`, as on iOS for Objective-C and Swift code). Embedded frameworks linked at build time: HelloToolchain. Tested: tests/dlopen |
| Mach APIs (`<mach/mach.h>`, `<mach/mach_time.h>`): time, `task_info`, `task_threads` / `thread_info`, `host_info` / `host_statistics(64)` / `host_processor_info`, `vm_allocate` & co., ports and `mach_msg`, semaphores, clocks | ✅ | ≤17 | adapted on Linux, the calling task only (other task ports are invalid destinations). `mach_absolute_time` (CLOCK_UPTIME_RAW, timebase 1/1), `mach_continuous_time`, `mach_wait_until`; `task_info` `MACH_TASK_BASIC_INFO`, `TASK_BASIC_INFO`, `TASK_THREAD_TIMES_INFO`, `TASK_EVENTS_INFO`, `TASK_VM_INFO` (`phys_footprint` = dirty anonymous memory; revisions by count) from /proc; `thread_info` basic / identifier / extended (`cpu_usage` averaged over about a second), `pthread_mach_thread_np` / `pthread_from_mach_thread_np` / `pthread_threadid_np` agree with thread ports (Linux tids); `host_info` reports the simulated device's memory (as `ProcessInfo.physicalMemory`) and the host's CPUs, VM page counts scaled to that memory; `vm_read_overwrite` reads without faulting; ports are in-process queues: simple messages (no port or memory descriptors), queue limits, send / receive timeouts, `MACH_RCV_LARGE`, reply and send-once rights, dead names; no port sets, exception ports or `thread_get_state` / `thread_suspend`. `thread_policy_set` is accepted, not applied (stub). Tested: tests/mach (Objective-C and Swift) |
| SQLite (`sqlite3` C API, `import SQLite3`) | ✅ | ≤17 | `/usr/lib/libsqlite3.dylib` forwards to the host's `libsqlite3.so.0` (loaded on first use; a function the host's SQLite lacks stops the app with a message). Tested: SecurityTest, HelloSecurity |
| BSD sockets (`socket`, `bind`/`listen`/`accept`, `connect`, `send`/`recv`, `getaddrinfo`, `inet_pton`, `poll`/`select`, `getifaddrs`) | ✅ | ≤17 | Darwin structs, constants and errno translated to the host's; tested (TCP server + client, socketpair, poll, select, getifaddrs, `SO_RCVTIMEO`); `read`/`write` errno translated too; UDP unverified |
| `POSIXErrorCode`, `MachErrorCode` | ✅ | ≤17 | passthrough: Apple's Darwin overlay enums (Swift's `stdlib/public/Platform`), Darwin's values; `POSIXErrorCode(rawValue: errno)`. Before 0.22 isim had a partial `POSIXErrorCode` in Network. Tested: HelloBytes (test_bytes) |
| `fcntl`, `ioctl`, `open`/`openat` from Swift | ✅ | ≤17 | the Darwin Swift overlay wraps the variadic C functions like Apple's: `fcntl` with no argument, an `Int32` or a pointer (`F_GETFL`/`F_SETFL` `O_NONBLOCK`, `F_GETFD`/`F_SETFD`, `F_DUPFD`), `ioctl` (`FIONREAD`, `FIONBIO`, `FIOCLEX`), `open`/`openat` with a mode (`AT_FDCWD`, `O_DIRECTORY`, `O_NOFOLLOW`); Darwin flags translated to the host's. Tested (swift-extras POSIXTests) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
