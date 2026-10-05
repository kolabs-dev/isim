# Darling evaluation: loading x86_64 iOS Simulator Mach-O executables on Linux

Date: 2026-10-05. Host: CachyOS, kernel 7.2.7-1-cachyos, Intel Core Ultra 9 275HX, Docker 29.8.1.
Scripts, logs and inputs: `experiments/04-darling/`. Labels: **VERIFIED** means I ran it or read it at
the pinned SHA. **INFERRED** means it is reasoning or documentation that I did not exercise.

## TL;DR

* Pinned Darling master `60ba801decee7a00782f74f6be4c8ffb013f79ff` (2026-09-06). I installed the
  **official CI-built .debs for that exact commit** (GitHub Actions run 34051607000) in an
  `ubuntu:24.04` container with `--privileged`. Darling runs: `uname -a` reports Darwin 20.6.0, and
  `sw_vers` reports macOS 11.7.4. **VERIFIED**
* Unmodified `hello.sim` / `hello.sim.chained` are **rejected by Darling's dyld**:
  `dyld: attempt to run simulator program outside simulator (DYLD_ROOT_PATH not set)`. **VERIFIED**
* When `DYLD_ROOT_PATH` is set and no `dyld_sim` exists, dyld falls through. It then rejects Darling's
  macOS libSystem with `mach-o, but not built for platform iOS-sim`. **VERIFIED**
* With **no dyld change and no change to the test binaries**, both binaries run to completion and exit
  **42**. This includes puts/printf/malloc/strlen, 4 pthreads with a mutex, and chained fixups. Two
  conditions apply. `DYLD_ROOT_PATH` points at a copy of Darling's own `/usr/lib`. In that copy,
  the platform field of `LC_BUILD_VERSION` has been relabelled from macOS(1) to iOS-simulator(7).
  **VERIFIED.**
  This proves that Darling's loader and kernel layer can run these binaries. It does **not** show
  iOS API compatibility, because the libraries are still Darling's macOS implementations under a
  different label.
* `hello.dev` (arm64) fails in Darling's ELF loader `mldr`: `No supported architecture found in fat binary.`
  This is expected. There is no arm64 support on x86_64. **VERIFIED**
* Darling has **no UIKit** (it has only a stub `UIFoundation` private framework). Its AppKit is based
  on Cocotron, and its CoreGraphics is Cocotron's Onyx2D. GUI support is described upstream as
  "in active development". **VERIFIED** (package contents and source tree)

## 1. Pinned commit and release facts (VERIFIED)

| Item | Value |
|---|---|
| `git ls-remote` HEAD = master | `60ba801decee7a00782f74f6be4c8ffb013f79ff` (queried 2026-10-05 12:51 UTC) |
| Commit date / message | 2026-09-06T18:24:20Z, "Merge pull request #1779 … fix-hitoolbox-build" |
| Latest release | `v0.1.20260608` (published 2026-06-09), tag → `e947f0d5a3c6…`, 16 commits behind the pin |
| Release assets | `darling-source.tar.xz` (506 MB), `debs_20260608.zip` (118 MB). Older releases ship single `.deb`s (jammy/focal) |
| Release → pin diff | Only framework stubs and headers (HIToolbox, CoreServices, AVFoundation, …). **No submodule pin changed** (I checked dyld, xnu, libsystem and objc4 at the tag) |
| CI artifacts at the pin | run 34051607000 "Darling CI" success. `debs` (118 MB), `source` (502 MB), `deb-source` (1.34 GB). They expire 2026-12-17 |
| Shallow clone, no submodules | `git clone --depth 1 --no-recurse-submodules`: **144 MB** (134 MB working tree) |

Submodule pins at the pinned commit (`git ls-tree`). The full list of 149 entries is in
`experiments/04-darling/submodules-pinned.txt`:

| Submodule | Repo | Pinned SHA | Notes |
|---|---|---|---|
| `src/external/dyld` | darling-dyld | `63f667cf06d7ed59553adebb0c8d70a117135ac9` | README: upstream `dyld-852.2` (macOS 11). `version.c` still says `dyld-733.6` |
| `src/external/xnu` | darling-xnu | `fa29287aa2f0115271e091f1031f53c9e024005d` | |
| `src/external/libsystem` | darling-Libsystem | `08df454b6eb0df9400aa4c39839a7efd6efd2c3c` | |
| `src/external/libpthread` | darling-libpthread | `f07f265bfbcf071c1adfc808de971e053ea5edc5` | |
| `src/external/libc` | darling-libc | `5a38c8dabf9e76b39407c24bc13134e33e5594e6` | |
| `src/external/darlingserver` | darlingserver | `89751e64bc6c2082f7725061824ee0e33395b0de` | userspace "kernel" |
| `src/external/objc4` | darling-objc4 | `1a12df76d12bfc9fdfffadb290f7742763568765` | |
| `src/external/corefoundation` | darling-corefoundation | `a3640a77410cf1825f7855172b1551ae7917c461` | |
| `src/external/foundation` | darling-foundation | `55a4341b470c2a56fea667c1d2167fb074226f04` | |
| `src/external/cocotron` | darling-cocotron | `c8d38d16a9f613d300157bebbab2b9501bc0c274` | AppKit / Onyx2D |
| `src/external/metal` | darling-metal | `ae20248dc144beab899e38752f5a530f28a0ea56` | Vulkan-backed Metal (initial) |
| iOS-related | — | — | **No iOS-related submodule exists**: no UIKit, no dyld_sim, no iOS runtime root |

## 2. Getting a runnable Darling (VERIFIED)

* Source: CI artifact `debs` from run 34051607000 (`head_sha` = pinned SHA). Downloaded with
  `gh run download 34051607000 -R darlinghq/darling -n debs`. The package version is
  `0.1.20260918~noble`. The date suffix is the artifact build date; the run is for the pinned commit.
* Image: `experiments/04-darling/Dockerfile` (ubuntu:24.04, matching the `~noble` debs). It installs only
  `darling-core darling-system darling-cli darling-cli-gui-common darling-cli-python2-common` plus
  `file binutils`. The install raised no errors. Log: `logs/docker-build.log`.
* Not installed: `darling-gui` (AppKit, CoreGraphics, QuartzCore, OpenGL), because it pulls X11 and
  ffmpeg/mesa dependencies. Also not installed: perl/python/ruby/jsc.
* Runtime: `docker run --privileged --tmpfs /root:exec,size=2g …`. `--privileged` is needed because
  `darling` is a setuid-root launcher that unshares mount/UTS/IPC namespaces and mounts an overlayfs
  prefix (`src/startup/darling.c:64,73,776,792`). The privilege need is **INFERRED** from source;
  I did not try running without `--privileged`.
* **No kernel module** was loaded on the host (`lsmod | grep -iE 'darling|mach'` returned nothing).
  darlingserver provides Mach IPC and the syscall layer in userspace. **VERIFIED**
* No source build was attempted. Darling's docs require up to 16 GB for the build, 5 GB for the
  source tree, 1 GB for the install, at least 4 GB RAM, Clang ≥ 11 and Linux ≥ 5.0. That exceeds
  the 5 GB budget, and the prebuilt CI debs made a source build unnecessary.

### `darling shell` basics (`run-tests.sh` → `logs/run-tests.log`)

```
$ darling shell uname -a
Setting up a new Darling prefix at /root/.darling
Darwin localhost 20.6.0 Darwin Kernel Version 20.6.0 x86_64          rc=0
$ darling shell sw_vers
ProductName:    macOS
ProductVersion: 11.7.4
BuildVersion:   Darling                                               rc=0
$ darling shell /bin/echo hello-from-darling
hello-from-darling                                                    rc=0
```

## 3. Running the test binaries

Inputs were copied byte-for-byte from `experiments/02-link/out/` (sha256 in
`experiments/04-darling/inputs/SHA256SUMS`) and mounted read-only at `/inputs`. Inside Darling they
appear at `/Volumes/SystemRoot/inputs`.

### 3a. As-is (VERIFIED, `logs/run-tests.log`)

```
$ darling shell /Volumes/SystemRoot/inputs/hello.sim
dyld: attempt to run simulator program outside simulator (DYLD_ROOT_PATH not set)
abort_with_payload: reason: attempt to run simulator program outside simulator (DYLD_ROOT_PATH not set); code: 9
rc=1
$ darling shell /Volumes/SystemRoot/inputs/hello.sim.chained
(identical message)                                                    rc=1
$ darling shell /Volumes/SystemRoot/inputs/hello.dev
No supported architecture found in fat binary.                         rc=1
```

The `hello.dev` message comes from `mldr`, not dyld. `mldr` loads the executable's `LC_LOAD_DYLINKER`
and forces the executable's CPU type, arm64 (`src/startup/mldr/loader.c:311`). Darling's `/usr/lib/dyld`
is a fat x86_64+i386 file, so no slice matches (`src/startup/mldr/mldr.c:396-423`). On an x86_64 host
there is no arm64 path at all (`mldr.c:405-406`: `#error TODO: arm`).

`DYLD_FORCE_PLATFORM=2` does not help: dyld only reaches that check after the simulator gate, and
the gate fires first (`exp-dyld-root-path.sh`):
`dyld: attempt to run simulator program outside simulator (DYLD_ROOT_PATH not set)`.

### 3b. `DYLD_ROOT_PATH` set, no dyld_sim (VERIFIED, `logs/exp-dyld-root-path.log`)

```
$ darling shell env DYLD_ROOT_PATH=/nonexistent-simroot DYLD_PRINT_LIBRARIES=1 /Volumes/SystemRoot/inputs/hello.sim
dyld: loaded: <4C4C440E-…> /Volumes/SystemRoot/inputs/hello.sim
dyld: Library not loaded: /usr/lib/libSystem.B.dylib
  Referenced from: /Volumes/SystemRoot/inputs/hello.sim
  Reason: no suitable image found.  Did find:
	/usr/lib/libSystem.B.dylib: mach-o, but not built for platform iOS-sim
	… (repeated)
abort_with_payload: reason: dyld: No shared cache present …          rc=1
```

The same happens for `hello.sim.chained` and for `DYLD_ROOT_PATH=/`. The executable itself was
accepted and mapped. The failure is the per-dylib platform check, because Darling's libSystem is
`LC_BUILD_VERSION platform 1` (macOS 11.0), as `otool -l` inside Darling confirmed.

### 3c. Diagnostic experiments (VERIFIED, `exp-control-and-simroot.sh`, `logs/exp-control-and-simroot.log`)

These experiments locate the failure. **They are not an iOS success.** `machoplat.py` rewrites
only the `LC_BUILD_VERSION.platform` / `LC_VERSION_MIN_*` cmd of x86_64 slices, and always writes
to copies.

**C (control): copies of hello.sim relabelled to macOS.** This tests whether the rest of the
binary works in Darling.

```
== CONTROL (relabelled macOS, not iOS): hello.sim.MACOS-CONTROL
hello from an iOS-simulator Mach-O
argc=1 argv[0]=/Volumes/SystemRoot/opt/eval/ctl/hello.sim.MACOS-CONTROL
malloc ok, strlen=63
threads ok, counter=400000 (expect 400000)
rc=42
(same for hello.sim.chained.MACOS-CONTROL, rc=42)
```

**D (sim root): ORIGINAL, unmodified hello.sim / hello.sim.chained.** In this run,
`DYLD_ROOT_PATH` points at a copy of Darling's `/usr/lib`. The copy has 102 Mach-O files with
x86_64 slices relabelled to platform 7 (iOS-simulator).

```
$ darling shell env DYLD_ROOT_PATH=/Volumes/SystemRoot/opt/eval/simroot /Volumes/SystemRoot/inputs/hello.sim
hello from an iOS-simulator Mach-O
argc=1 argv[0]=/Volumes/SystemRoot/inputs/hello.sim
malloc ok, strlen=63
threads ok, counter=400000 (expect 400000)
rc=42
(hello.sim.chained: identical, rc=42)
```

With `DYLD_PRINT_LIBRARIES=1`, all 38 loaded libraries resolved from `/…/simroot/usr/lib/...`
(`logs/exp-simroot-print-libraries.log`). So the process ran with dyld's process platform set to
iOS-simulator, against relabelled macOS libraries. `hello.dev` under the same root still fails in
`mldr` (rc=1).

What D shows: Darling's dyld-852 can load an iossimulator MH_EXECUTE with either `LC_DYLD_INFO_ONLY`
or `LC_DYLD_CHAINED_FIXUPS`. darlingserver/mldr can then run libc, malloc and pthreads for it. The
**only** blocker for this C test was dyld's platform policy. Supplying "iOS-sim-labelled" system
libraries satisfies that policy without touching dyld.

What D does not show: anything about iOS-specific behaviour. That covers Objective-C or Foundation
behaviour that branches on `dyld_get_active_platform()` / SDK version checks, UIKit, or app
lifecycle. Relabelling macOS dylibs is a diagnostic hack, not a compatibility layer. **INFERRED**:
real iOS apps link `UIKit`, `Foundation` and `CoreGraphics` by framework path, and none of those
exist here as iOS frameworks.

## 4. Source analysis at the pinned SHA

Paths are relative to the darling-dyld submodule at `63f667cf` unless noted. All references were
**VERIFIED** by reading the files.

### How dyld decides platform compatibility

1. **Process platform comes from the main executable.** `src/dyld2.cpp:6560-6578` walks
   `forEachSupportedPlatform` and sets `gProcessInfo->platform`. For our binaries that is
   `iOS_simulator` (7).
2. **`DYLD_FORCE_PLATFORM`** (`dyld2.cpp:6580-6596`) accepts only 2 (iOS) or 6 (Catalyst). It also
   requires `allowsAlternatePlatform()`. It is irrelevant for the simulator.
3. **Simulator gate** (`dyld2.cpp:6598-6618`, inside `#if TARGET_OS_OSX`):
   * If `DYLD_ROOT_PATH` is set, dyld opens `$DYLD_ROOT_PATH/usr/lib/dyld_sim`. If that succeeds, it
     calls `useSimulatorDyld()` (`dyld2.cpp:5550`). That function requires a code-signed dyld_sim
     (`:5667`) and `fcntl(F_ADDFILESIGS_FOR_DYLD_SIM)` (`:5680`). It maps dyld_sim and hands off
     to its entry point (`:5726`), together with the host's `SyscallHelpers` table (`:5470ff`).
   * **If dyld_sim is missing, dyld silently falls through** and continues as the host dyld, with the
     process platform still set to iOS-sim. This is the hole that experiment D used.
   * If `DYLD_ROOT_PATH` is unset and any platform is a simulator platform, dyld calls `halt("attempt to
     run simulator program outside simulator (DYLD_ROOT_PATH not set)")` (`:6612-6617`).
4. **`DYLD_ROOT_PATH` handling**: parsed at `dyld2.cpp:2122-2133`. The value `/` is ignored, and it
   must be absolute. Absolute load paths get the root prefixed before falling back to the raw path
   (`dyld2.cpp:4075-4090`). `SUPPORT_ROOT_PATH` is 1 for macOS builds (`src/ImageLoader.h:99`).
5. **Per-image platform check**: `dyld2.cpp:3445-3446` raises
   `throwf("mach-o, but not built for platform %s", …)` when
   `!MachOFile::loadableIntoProcess(gProcessInfo->platform, path)`. The shared-cache equivalent is at
   `:3641-3642`, but Darling has no shared cache.
6. **`MachOFile::loadableIntoProcess`** (`dyld3/MachOFile.cpp:514-553`): an image loads if it is built for the
   process platform. For simulator processes it also accepts macOS images, but only from a hard-coded
   whitelist (`:520-532`): `libsystem_kernel`, `libsystem_platform`, `libsystem_pthread` (and their
   `_debug` variants) and `host/liblaunch_sim`. That is the dyld_sim design: the simulator runtime
   provides everything else. `isSimulatorPlatform` is at `:631`.
7. **Darling-specific changes in dyld2.cpp**: only 9 `DARLING` ifdefs, all about kdebug, AMFI and
   commpage (`:89,103,1471,5320,5460,6781-6803,6805,6891`). None touches platform policy. **Darling
   does not build `dyld_sim`**: there is no target in `CMakeLists.txt`, and only Apple's
   `dyld_sim-entitlements.plist` is present.

**Can an iOS-simulator binary be loaded into Darling's macOS process?** Not as shipped (3a). It can
in two ways, each needing a small and well-defined change:

* **(a) Patch the policy.** Remove the halt at `dyld2.cpp:6612-6617`, and extend `loadableIntoProcess`
  to accept macOS images in sim processes, or treat iOS-sim as macOS. This means a few lines in one
  submodule. It is **INFERRED** to work, based on experiment D, which reaches the same effective
  state.
* **(b) Provide a simulator runtime root (the Apple design).** This is a directory with iOS-sim-
  platform libSystem, libobjc, Foundation, UIKit and so on, passed via `DYLD_ROOT_PATH`. Darling's dyld
  already falls through when there is no `dyld_sim`, so it would act as the sim dyld itself. A real
  `dyld_sim` would also be possible, but Darling would have to build dyld with
  `TARGET_OS_SIMULATOR` and satisfy the code-signature/`F_ADDFILESIGS_FOR_DYLD_SIM` checks or patch
  them out. Experiment D is a crude version of (b).

### Other subsystems (status at the pin)

| Area | Status | Basis |
|---|---|---|
| UIKit / iOS frameworks | **None.** No UIKit, UIKitCore, MobileCoreServices or iOS SDK root. Only `UIFoundation` (private framework, stub functions such as `UINibArchiveIndexFromNumber` that print `STUB:`), `libMobileGestalt`, `MobileKeyBag`, and `CoreTelephony` stubs | VERIFIED: source tree + .deb listings |
| Objective-C runtime | Apple `objc4` (darling-objc4 `1a12df7`) → `/usr/lib/libobjc.A.dylib` (shipped in darling-system). Compiled for macOS (`TARGET_OS_OSX`) | VERIFIED file present. ObjC dispatch **not exercised** here |
| CoreFoundation | darling-corefoundation (Apple CF-based, APSL/MPL-2.0) in `darling-cli-gui-common` | VERIFIED present, not exercised |
| Foundation | darling-foundation (LGPL-2.1; Apportable/GNUstep-derived lineage, **INFERRED**) | VERIFIED present, not exercised |
| AppKit / CoreGraphics / QuartzCore / OpenGL | `darling-gui` package: AppKit, Cocoa, CoreGraphics, CoreText, Onyx2D, QuartzCore, OpenGL (Cocotron-based, X11). README: "GUI application support is in active development". Metal is "initial … Vulkan translation" | VERIFIED package listing. GUI **not installed or tested** |
| Threads / pthreads | Apple libpthread over darlingserver: 4 threads + mutex OK (400000/400000) in experiments C and D | VERIFIED |
| Chained fixups | dyld-852 handles `LC_DYLD_CHAINED_FIXUPS` (hello.sim.chained, rc=42 in D) | VERIFIED |
| Kernel / syscall emulation | **darlingserver**: userspace server built from stripped XNU code plus "duct-tape" glue (`darlingserver/duct-tape/README.md`), implementing Mach IPC and BSD syscalls. The ELF loader `mldr` maps dyld and the Mach-O. Setuid `darling` sets up namespaces and the overlayfs DPREFIX. No LKM | VERIFIED (no module loaded; source) |
| Architecture | x86_64 (+ i386 via `mldr32`) only. arm64 is `#error TODO` | VERIFIED `mldr.c:405-406` |

## 5. Conclusions

### Concrete failures (VERIFIED, exact text)

1. iossimulator executables, no env:
   `dyld: attempt to run simulator program outside simulator (DYLD_ROOT_PATH not set)` (rc=1).
2. iossimulator executables with `DYLD_ROOT_PATH` and no sim libraries:
   `/usr/lib/libSystem.B.dylib: mach-o, but not built for platform iOS-sim` → `Library not loaded` (rc=1).
3. arm64 iOS device executable: `No supported architecture found in fat binary.` (mldr, rc=1).
4. `DYLD_FORCE_PLATFORM=2` does not bypass (1).

### Missing dependencies for a real iOS-simulator target

* An iOS-sim-platform system root, at minimum libSystem, libobjc, CF and Foundation, built or
  labelled as `PLATFORM_IOSSIMULATOR`. It needs whatever iOS-only symbols differ from macOS 11.
* **UIKit (and UIKitCore, QuartzCore/CoreAnimation, CoreGraphics semantics matching iOS), plus an
  app lifecycle:** `UIApplicationMain`, run loop, scene/window, event input and rendering. None exists.
  Cocotron AppKit is not a substitute.
* Some way to handle the `dyld_sim`/`DYLD_ROOT_PATH` contract, either policy patches or a built
  sim root (§4).
* iOS app container conventions (bundle layout, `Info.plist`, `NSHomeDirectory` sandbox paths) and
  device-family behaviours. **INFERRED**

### Effort to make iossimulator binaries load (INFERRED estimates)

| Step | Effort | Notes |
|---|---|---|
| Accept iossim in dyld (patch `dyld2.cpp:6612-6617` + `MachOFile.cpp:514-553`), or generate an iOS-sim-labelled sim root at install time | **Days** | Experiment D shows this is enough for C/libSystem programs. Policy patches must live in a fork of darling-dyld, and rebuilding Darling exceeds this host's disk budget (16 GB build) |
| Make the platform consistent (`dyld_get_active_platform`, `dyld_program_sdk_at_least`, CF/objc behaviour switches, `TARGET_OS_*`-compiled differences) | **Weeks** | Darling's libraries are compiled for macOS. Behaviour that is gated at compile time cannot be fixed by relabelling |
| ObjC/Foundation for iOS-sim binaries | Weeks, assuming the macOS libobjc and Foundation are acceptable | Not tested yet. The next experiment should be an ObjC message send plus an NSString/NSArray smoke test under the D setup |
| UIKit counter app | **Months+** | A new UIKit implementation is needed, for example UIKit-on-Cocotron/Onyx2D, or something written from scratch. This is the dominant cost in either approach |

### Licensing (VERIFIED from repo license files; legal reading INFERRED)

* Darling top level: **GPL-3.0** (`LICENSE`). darlingserver source headers: GPL-3.0-or-later.
* Apple-derived submodules (dyld, xnu, Libsystem, objc4, libpthread, …): **APSL 2.0** (`APPLE_LICENSE`).
  darling-corefoundation: APSL where files say so, otherwise **MPL-2.0**. darling-foundation:
  **LGPL-2.1**. cocotron: **MIT**.
* Implication (**INFERRED**, not legal advice): extending Darling's core, launcher or darlingserver
  means GPL-3.0 obligations for distributed derivatives. Patching dyld means APSL-2.0 obligations
  (publish modifications). A separate compatibility layer could reuse APSL/MIT pieces such as dyld
  and objc4 under their own terms while avoiding GPL code.

### Extend Darling vs. dedicated compatibility layer

| | Extend Darling | Dedicated compatibility layer |
|---|---|---|
| Time to first C program running | **Already there** (experiment D: exit 42 with relabelled root). Policy patch is days | Needs own Mach-O loader + libSystem shim (exp 03 in progress) |
| Syscall / Mach IPC / pthreads | Mature: darlingserver (XNU-derived) plus Apple libpthread/libc work today | Must be written or shimmed. Mach IPC is a large surface if real Apple libs are used |
| dyld fidelity | Real Apple dyld-852 (chained fixups, two-level namespace, ObjC image notifications) | Custom loader. Simpler, but must re-implement fixups, binding, TLV, initializers and ObjC registration |
| ObjC runtime / CF / Foundation | Present (objc4, CF, Foundation), compiled for macOS | Must port objc4/GNUstep/CF or similar |
| UIKit | **Absent** | **Absent** (same dominant cost) |
| Platform semantics | Built as macOS 11. iOS-sim needs relabelling or rebuilding with iOS conditionals, which fights the project's design | Can be designed iOS-first |
| Footprint / deployment | Setuid launcher, namespaces, overlayfs prefix, `--privileged` in Docker, ~0.45 GB image, 16 GB source build | Can be an unprivileged single process |
| Build / maintenance | Huge tree (149 submodules), heavy rebuild, upstream focused on macOS apps. iOS patches unlikely to be upstreamed (**INFERRED**) | Small and owned, but every subsystem is your responsibility |
| Licensing | GPL-3.0 core + APSL + LGPL + MPL + MIT mix | Free to choose. Can still reuse APSL/MIT parts |
| Architecture | x86_64 only (arm64 `#error TODO`) | Same constraint unless an emulator is added |

**Assessment.** Darling is the fastest proven path to *executing* x86_64 iossimulator Mach-O code
on Linux. With an iOS-sim-labelled runtime root, or about two small dyld policy patches, a
libSystem-level program already runs, including threads and chained fixups. This is not iOS
compatibility. Darling ships nothing iOS-specific: no UIKit, a macOS-compiled ObjC/Foundation stack,
and a GPL-3.0, privileged, multi-gigabyte build. A reasonable hybrid is to use Darling (unchanged
debs plus a generated sim root) as a **test harness and reference** for loader and libSystem
behaviour, and to decide the long-term runtime only after the ObjC/Foundation experiment under
setup D. UIKit has to be built in either case.

## 6. Reproduction and resource accounting

```
experiments/04-darling/
  Dockerfile, build-image.sh        # ubuntu:24.04 + pinned-commit CI debs -> darling-eval:60ba801
  run-tests.sh                      # basics + as-is runs (own --rm container)
  start-container.sh                # long-lived privileged container used by exp-*.sh
  exp-dyld-root-path.sh             # 3b
  exp-control-and-simroot.sh        # 3c (C control + D sim root), uses machoplat.py
  machoplat.py                      # diagnostic platform relabeller (writes copies only)
  inputs/ (copies + SHA256SUMS), logs/, ls-remote.txt, pinned-commit.json, releases.json,
  submodules-pinned.txt, dl/debs/ (CI debs), src/{darling,dyld,darlingserver} (shallow)
```

Order: `build-image.sh` → `run-tests.sh` → `start-container.sh` → `exp-dyld-root-path.sh` →
`exp-control-and-simroot.sh` → `docker rm -f darling-eval-run`.

Disk:

* `df -h /` before: 11G available (91% used). After: 14G available (89%). The host's free space
  changed for reasons unrelated to this work, so the difference is not attributable.
* Measured footprint:
  * `experiments/04-darling/` is 331 MB: darling clone 144 MB, dyld 34 MB, darlingserver 40 MB,
    debs 114 MB.
  * Docker image `darling-eval:60ba801` is **451 MB**, including its `ubuntu:24.04` base of 78.2 MB,
    which is also left as a tag.
  * A transient 82 MB scratch sim root was deleted.
  * Total ≈ **0.8 GB**, well under the 5 GB budget.
* Containers: all removed (`darling-eval-run` deleted). Images left behind: `darling-eval:60ba801`
  (451 MB) and `ubuntu:24.04` (78.2 MB). Remove them with
  `docker rmi darling-eval:60ba801 ubuntu:24.04`.
* No host packages, kernel modules or sysctls were changed.
