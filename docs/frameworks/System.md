# System

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Foundation & CoreFoundation](../COVERAGE.md#foundation) · **Apple:** [System](https://developer.apple.com/documentation/system) · **Issues:** [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

## How isim implements it

- **Passthrough:** upstream [swift-system](https://github.com/apple/swift-system) (1.8.1, `third_party/swift-system`,
  fetched by `isim/build.py fetch`) built as Apple's `System` module (`libswiftSystem.dylib`; `system()` in
  `isim/buildlib/swift.py`). Each `System x.y` version has the availability Apple's SDK gives it (swift-system's
  Package.swift), so `@available` checks behave as on iOS: the `Stat` / `FileMode` / `FileFlags` API of System 1.7 is iOS 27.
- **Underneath:** isim's libSystem (Darwin headers and the calls translated to Linux: `openat`, `unlinkat`, `fstatat`,
  `fdopendir`, `confstr`, `umask`, Darwin's `O_*` / `AT_*` flags) and its in-process Mach ports.
- **Objective-C / C interface:** Swift only (as Apple's).
- **Versus Apple's Simulator:** paths are the app's container on the Linux file system; `chflags` flags are reported
  clear; Mach port rights stay within the process.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `FilePath` (components, root, stem, extension, lexical normalization and relative paths, appending / removing, `FilePath.Component`, `FilePath.Root`, string conversions) | ✅ | 14.0 | passthrough (swift-system). Tested (SwiftExtrasTest: test_swift_extras). Its internal temporary paths are under the app container's `tmp/` (libSystem's `confstr(_CS_DARWIN_USER_TEMP_DIR)`, which Foundation's container settles; tested) |
| `FileDescriptor` (`open` with access modes, options and permissions, `read` / `write` at the position or an absolute offset, `writeAll`, `seek`, `duplicate`, `pipe()`, `resize`, `close`, `closeAfter`), `FileDescriptor.AccessMode` / `OpenOptions` / `SeekOrigin` | ✅ | 14.0 | passthrough over isim's libSystem: Darwin's open flags translated (`O_SHLOCK` / `O_EXLOCK` take a `flock`, `O_SYMLINK` opens the link itself, `O_EVTONLY` is an ordinary descriptor). Tested (test_swift_extras) |
| `Errno` (every Darwin error code, thrown by the `FileDescriptor` calls) | ✅ | 14.0 | passthrough: Darwin's errno values (isim's libSystem gives the Darwin numbers). Tested (test_swift_extras) |
| `FilePermissions` | ✅ | 14.0 | passthrough. Tested (test_swift_extras) |
| `Mach` (`Mach.Port` with receive, send and send-once rights, `makeSendRight`, `copySendRight`, `withBorrowedName`, contexts and guards, `Mach.PortRight`) | 🟡 | 17.4 | passthrough over isim's in-process Mach ports (`mach_port_extract_right`, `mach_port_guard` / `unguard`, `mach_port_set_mscount` added): rights within the process only, guards kept but not enforced. Tested (test_swift_extras: a receive right and a send right) |
| `Stat`, `FileMode`, `FileType`, `FileFlags`, `DeviceID`, `GroupID`, `UserID`, `Inode`, `CInterop` | ✅ | 27.0 | passthrough (System 1.7, iOS 27): `stat` / `lstat` / `fstat` / `fstatat` through isim's Darwin `struct stat`; `st_flags` (`FileFlags`) is always empty |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
