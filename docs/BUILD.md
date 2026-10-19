# Building isim

`isim/build.py` is the single entry point: it writes a Ninja graph (`isim/out/build.ninja`) and runs it.

```bash
isim/build.py fetch            # pinned Swift / LLVM sources into third_party/ (once)
isim/build.py                  # everything
isim/build.py runtime          # a part: runtime, sdk-c, swift-core, overlays, swift, apps
isim/build.py out/apps/HelloTable.app/HelloTable   # or any output
isim/build.py test             # the tests (docs/TESTING.md)
isim/build.py package 0.9.0    # a release tarball in isim/dist/
```

Ninja runs a step only when one of its inputs changed and runs independent steps in parallel (Swift compiles share a
pool sized by memory). A build with nothing to do takes about 0.15 s; one changed framework file recompiles that file
and relinks.

## The graph (`isim/buildlib/`)

| File | Builds |
|---|---|
| `graph.py` | host runtime (`isim-runtime`, `isim-webkit`), SDK headers, `.tbd` stubs, the Objective-C frameworks, tools |
| `swift.py` | the Swift core (stdlib, runtime, libc++, Concurrency, Observation, Synchronization, Distributed, Regex), the overlays (`OVERLAYS` table), Swift Testing |
| `apps.py` | samples, self-test apps (`tests/*`), system apps |
| `act.py` | small actions the edges run (mirror files, `.tbd` generation, keep unchanged outputs' timestamps) |
| `fetch.py`, `package.py` | third-party pins; release packaging |

Changes do not cascade needlessly: steps that rewrite an output with the same content keep its old timestamp (Ninja
`restat`), so a comment-only change in an overlay recompiles that overlay and nothing else. Apps depend on the SDK's
interface (headers, `.tbd` stubs and each Swift module's public interface: the `.swiftinterface` a library-evolution
overlay prints to `out/swift/iface`, else its binary module), not on framework or overlay implementations: an edit
to an overlay's internals rebuilds the overlay, not the 200 apps; a change to its public API rebuilds them.

## Warnings are errors

isim's own code builds without warnings, and a new warning fails the build: the host runtime, the Objective-C
frameworks, the Swift overlays, the samples and the test apps compile with `-Werror` (C, Objective-C) or
`-warnings-as-errors` (Swift). Deprecations stay warnings (`-Wno-error=deprecated-declarations`,
`-Wwarning DeprecatedDeclaration`). Upstream code (the Swift stdlib, Swift Testing) builds with `-suppress-warnings`.
A compiler newer than CI's may warn about more; `ISIM_WERROR=0 isim/build.py` builds with warnings left as warnings.

## Adding things

- **A sample**: first extend an existing one. Each app costs build time (about a second of compiler start-up and
  module loading, on every app rebuild) and a launch in the tests, so new API goes into the sample for its framework
  or area: one sample per framework is the aim (e.g. HelloStore for StoreKit, HelloMaps for MapKit; the Objective-C
  interface's sample, Hello<Name>ObjC, next to it). Add a page, a button or a launch argument the test passes rather
  than a new app (HelloCharts' pages: `-more`, `-styling`, `-axes`). Start a new sample only when one cannot hold it:
  another kind of app (an App Clip, a document app, an extension's host), Info.plist keys or entitlements that would
  change the existing sample's behaviour, or a framework with none yet. A directory in `isim/samples` with Swift files
  and an `Info.plist` builds as `<Dir>.app` with no build code. Anything else (extensions, generated resources,
  Objective-C, Xcode projects) is a function in `buildlib/apps.py` registered with `@app("samples/<Dir>", ...)`.
- **A framework** (Objective-C): sources in `isim/frameworks/<Name>`, headers in `isim/sdk-src/Frameworks/<Name>`,
  and a line in `FRAMEWORKS` (`graph.py`).
- **A Swift overlay**: `isim/swift/overlays/<Name>.swift` (or a directory) and a line in `OVERLAYS` (`swift.py`) with
  the modules and frameworks it links.
- **An Objective-C interface for a Swift overlay** (WebKit, StoreKit, AVFoundation…): give the classes Apple's names
  (`@objc(WKWebView)`) and members Apple's selectors, add the old `_TtC…` class symbols to `OBJC_NAMES` (`swift.py`),
  headers in `isim/sdk-src/Frameworks/<Name>` wrapped in `#if !defined(__swift__)`, C constants or categories in
  `isim/frameworks/<Name>`, and a line in `SWIFT_FRAMEWORKS` (`graph.py`): the framework re-exports the overlay.
  Every Swift-implemented framework needs one (AGENTS.md).
- **A host function guests call** (a new entry in a symbol table, `struct shim`): define it `ISIM_GUEST_ABI`, and use
  the platform layer for anything the operating system provides ([Portability](#portability)).
- **Its coverage page**: `docs/frameworks/<Name>.md` from `docs/frameworks/_template.md` (how isim implements it, the
  rows), with the module in its area in `isim/data/frameworks.json`. The generated parts of the page are filled in by
  `isim/tools/coverage-summary.py` at the next release.

## Portability

isim runs on Linux, but its host runtime (`isim/runtime`) is kept ready for another host: native Windows is planned in
[#491](https://github.com/kolabs-dev/isim/issues/491), which explains why each rule below matters there. New code
follows these rules, and the check enforces them.

- **The platform layer** (`runtime/platform.h`, Linux implementation `runtime/platform_posix.c`) holds the
  operating-system services the runtime needs beyond portable C and its libraries (SDL, cairo, …):

  | Call | Instead of | What for |
  |---|---|---|
  | `isim_spawn(&(struct isim_spawn){…})` | `fork` + `exec`, `posix_spawn`, `prctl(PR_SET_PDEATHSIG)` | start a program: arguments, environment changes, inherited or remapped handles, null stdio, `die_with_parent`, `new_session`; an exec failure is reported (-1, `errno`) |
  | `isim_open_on_desktop(url_or_path)` | `xdg-open` | the desktop's default handler |
  | `isim_self_path`, `isim_self_args`, `isim_restart_self` | `/proc/self/exe`, `/proc/self/cmdline`, `execv` of itself | the runtime's own executable, command line, and restart in place |
  | `isim_shm_create`, `isim_shm_map`, `isim_shm_unmap` | `memfd_create`, `mmap(MAP_SHARED)` | memory shared with another process (frame surfaces) |
  | `isim_ipc_pair(h, packets)` | `socketpair(AF_UNIX)` | a connected pair between two processes |
  | `isim_ctl_create(path)` | `mkfifo` | a control channel (`ISIM_CONTROL`, `isim send`) |

  A service it lacks is added there: a declaration in `platform.h` saying what it does (not how), and the Linux code in
  `platform_posix.c`. Another host then implements the same list in its own file.
- **The guest ABI boundary.** Guest code calls host functions with the System V x86-64 convention (Darwin's), which is
  Linux's too but not Windows'. `runtime/guest_abi.h` (included by `runtime.h`) defines:
  - `ISIM_GUEST_ABI`: at the start of the definition and of every prototype of a host function a symbol table
    (`struct shim`: libSystem, libobjc, libisim_host…) hands to guests, e.g. `ISIM_GUEST_ABI static int d_open(...)`. A
    macro that makes such functions puts it in the macro. Passthrough entries (`P(name)`: the host C library's own
    function) and the hand-written assembly entry points (`objc_msgSend`…) don't take it.
  - `ISIM_GUEST_CALLBACK`: in a function pointer type the host calls guest code through (comparators, thread start
    routines, blocks' invoke functions).

  On x86-64 both expand to `__attribute__((sysv_abi))`: no change on Linux, where it is already the convention, but
  every Linux build checks that each mark is in a valid place.
- **Linux-only by design.** libSystem code that implements a Darwin API over a Linux one (kqueue over `epoll`,
  `__ulock` over `futex`, Mach task info over `/proc`) is what a port reimplements anyway; such a line ends with
  `/* linux-only: what it implements */`. Backends that are Linux-only as a whole (`isim-webkit.c`, the WebKitGTK
  helper) are listed in the check. A new `dlopen` of a host library is marked the same way until the per-host library
  name table from #491 exists.
- **The check:** `isim/tools/portability-check.py` (the CI build runs it; `isim/tests/docs/test_portability.py` too)
  fails on a Linux-only call outside the platform layer, or a guest-facing function without `ISIM_GUEST_ABI`, beyond
  `isim/data/portability-baseline.txt`, the uses the runtime still had when the rules came in. The baseline may only
  shrink: after moving a use to the platform layer, `portability-check.py --update` rewrites it. `--list` prints
  everything left (the port's checklist), the `linux-only:` lines included.

## Coverage numbers

`isim/tools/api-coverage.py` compares isim's SDK with a snapshot of Apple's documentation
(`isim/data/apple-api/apple-api.json.gz`; [API-SWEEP.md](API-SWEEP.md)):

```bash
isim/tools/api-coverage.py snapshot              # refresh Apple's data (network; after an Apple SDK release)
isim/tools/api-coverage.py measure               # exact, from the built SDK's symbol graphs (the Swift toolchain)
isim/tools/api-coverage.py measure --names       # without a build: by name, a lower bound on what is missing
isim/tools/coverage-summary.py                   # docs/COVERAGE.md and the pages' generated parts
```

The Release workflow runs `measure` and `coverage-summary.py` and commits the results in the release pull request;
pull requests do not, so they don't conflict.

## CI

CI restores `isim/out` from a cache. A checkout gives every file a new modification time, so `build.py ci` first gives
files whose content matches the last cached build their recorded timestamps back (`out/srcstate.json`); Ninja then
rebuilds only what changed. Ninja never deletes an output that left the graph, so `build.py ci` also removes SDK binaries the graph no
longer builds (with their `.swiftmodule` or `.framework`): a cached `out/` cannot carry a removed library into a release
tarball or ABI baseline.

## Claude Code cloud environments

A [Claude Code cloud environment](https://code.claude.com/docs/en/claude-code-on-the-web) (claude.ai/code) can build
and test isim like CI. In the environment's settings (Edit environment):

- **Setup script:** paste [`isim/ci/cloud-setup.sh`](../isim/ci/cloud-setup.sh). It installs CI's packages
  (`isim/ci/Dockerfile`; keep the two in step), clang 22, SDL3 and Swift 6.2.4 from swift.org (`swiftc` on `PATH`).
- **Environment variables:**

  | Variable | Why |
  |---|---|
  | `SDL_AUDIO_DRIVER=dummy` | required: the container has no sound device (CI's image sets it too) |
  | `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1` | required for the web tests: WebKitGTK's sandbox cannot create namespaces in the container (CI's image sets it too) |
  | `ISIM_TEST_JOBS=4` | optional: test workers, as many as the container's CPUs (the default is half), like CI |
  | `ISIM_WAIT_SCALE=3` | optional, with `ISIM_TEST_JOBS`: longer test waits on a busy machine, like CI |

In a session, run `isim/build.py fetch` once before the first build. Each session builds
`isim/out` from scratch (the first `build.py` takes a while; later builds are incremental). Tests use a scratch
`ISIM_DATA`.
