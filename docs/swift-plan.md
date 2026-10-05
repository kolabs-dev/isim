# Swift support: findings and plan

Goal (added 2026-10-05): develop, compile, test, run and ship apps written in **both
Objective-C and Swift** with the isim toolchain on Linux.

## Verified (2026-10-05, `swift:6.2` Docker image, Swift 6.2.4-RELEASE, x86_64 Linux)

| Probe | Result |
|---|---|
| Full Swift stdlib for Darwin/iOS in the Linux toolchain | **Absent** (`/usr/lib/swift/iphonesimulator` missing). `swiftc -target x86_64-apple-ios15.0-simulator` fails: "unable to load standard library". |
| Embedded Swift stdlib modules shipped | `arm64-apple-ios`, `arm64e-apple-ios`, `*-apple-none-macho`, ELF/wasm targets. **No `x86_64-apple-ios-simulator`.** |
| Embedded Swift → `arm64-apple-ios15.0` | Rejected: module minimum deployment target is iOS 18. |
| Embedded Swift → `arm64-apple-ios18.0` (`experiments/06-swift/hello.swift`, in git history up to `bef462d`) | **Compiles** to a Mach-O object, `LC_BUILD_VERSION platform ios minos 18.0`. Undefined symbols: `___stack_chk_fail ___stack_chk_guard _bzero _free _memmove _posix_memalign _puts` (all provided by isim's libSystem). |

Reproduce: `docker run --rm -v "$PWD":/w -w /w swift:6.2 swiftc -target arm64-apple-ios18.0 -enable-experimental-feature Embedded -wmo -parse-as-library -Osize -c hello.swift -o hello.dev.o`

## Implications
- **Embedded Swift** has no Objective-C interop, no reflection/existential-heavy runtime,
  and limited class features. It cannot subclass `UIViewController`/`NSObject` or expose
  `@objc` selectors, so it cannot express a normal UIKit app. It is useful for logic
  modules and as a first proof that Swift→Mach-O works on Linux.
- A normal UIKit (and later SwiftUI) Swift app needs the **full Swift runtime and stdlib**
  (`libswiftCore`, `libswift_Concurrency`, ObjC interop) built for
  `x86_64-apple-ios-simulator` (our runtime) and `arm64-apple-ios` (device), plus Swift
  overlays/module maps for our SDK (`Foundation`, `UIKit`, `Darwin`).

## Progress
- **Stage 1 done (2026-10-05):** Embedded Swift on the isim simulator. `isim/swift/build-embedded-stdlib.py` builds
  `Swift.swiftmodule` for `x86_64-apple-ios15.0-simulator` from swift-6.2.4 sources (205 files, ~20 s) mirroring
  the CMake embedded recipe; `build-embedded-support.sh` builds the Unicode tables + SwiftDtoa float printing
  (the toolchain's device library lacks float printing). `tests/swift-embedded` passes 11/11 under isim.
  Limits of Embedded Swift observed: no existentials (`any P`), no ObjC interop, no reflection.
- **SDK groundwork for stage 2:** libc++ headers (llvmorg-22.1.8) with an isim `__config_site` and a C11 libc
  header surface (math, stdlib, stdio, string, inttypes, sched, signal) + matching host functions.

- **Stage 2 core done (2026-10-05):** full Swift on the isim simulator.
  - `build-stdlib.py --full`: the regular stdlib (228 files, library evolution, ObjC interop) for
    `x86_64-apple-ios15.0-simulator` → `swiftCore.o` (39k symbols) + `Swift.swiftmodule`/`.swiftinterface`.
  - `build-runtime.sh`: all 92 runtime/stubs/demangler/LLVMSupport/threading sources (C++ and ObjC++) compile
    against the isim SDK (pthreads threading, no Darwin malloc zones, no dlsym overrides, reflection on).
  - `build-libcxx.sh`: guest `libc++.1.dylib` from llvmorg-22.1.8 libc++/libc++abi sources (no exceptions/RTTI).
  - `build-swiftcore.sh`: `/usr/lib/swift/libswiftCore.dylib` (9 MB) linked with no undefined symbols.
  - isim runtime additions it required: Mach-O thread-local variables (TLV thunk preserving all registers),
    dyld image APIs + add-image callbacks + `getsectiondata`, `dlsym`/`dladdr`/`dlopen` over loaded images,
    `__ulock_wait/wake` on Linux futexes, Darwin `pthread_attr_t`, libmalloc size queries, compiler builtins,
    ObjC `Method` objects/`class_addMethod`/`method_setImplementation`, ivar introspection, associated objects,
    `objc_readClassPair`, Swift class-name/image hooks, lazily named classes.
  - `tests/swift-full`: 12/12 (existentials, protocol extensions, `type(of:)`, typed throws, class inheritance,
    dynamic casts, `Any`, generics, optionals, `Dictionary(grouping:)`, Unicode, `String(describing:)`).
  - Not yet: `_Concurrency` (async/await), `_StringProcessing` (Regex), `_objc_realizeClassFromSwift`
    (Swift uses its fallback path).
- **Stage 2 apps done (2026-10-05):** Swift UIKit apps.
  - SDK: Clang module maps (`Darwin`, `ObjectiveC`, `Dispatch`, framework modules), API notes for Foundation
    (`SwiftBridge` for NSString/NSArray/NSDictionary/NSSet, Swift class names) and UIKit (nested type names,
    `UIButton.Configuration`, Auto Layout `constraint(equalTo:)`, `UISceneSession.Role.windowApplication`),
    real `NS_ENUM`/`NS_OPTIONS`/`NS_TYPED_ENUM`/`NS_SWIFT_NAME` semantics.
  - isim-authored overlays: ObjectiveC, Foundation, UIKit (`swift/overlays/`); isim's own Swift resource dir
    (clang builtin headers + SwiftShims) so the Linux toolchain's corelibs module maps stay out of iOS builds.
  - libobjc hooks now start as default implementations (the Swift runtime chains to the previous hook).
  - Results: `tests/swift-foundation` 15/15; `samples/HelloCounterSwift` (Xcode Swift UIKit template) UI test 9/9.

## Plan (proposals, not yet verified)
1. Simulator Embedded Swift: build the Embedded stdlib module for
   `x86_64-apple-ios-simulator` from `swift-6.2.4-RELEASE` sources with the shipped
   compiler; run a Swift CLI test under isim-runtime.
2. Clang module maps for the isim SDK so Swift can `import Foundation`/`import UIKit`
   (C/ObjC importer) — needed by both embedded and full Swift.
3. Full Swift runtime + stdlib cross-built from Linux for `x86_64-apple-ios-simulator`
   against the isim SDK (CMake standalone stdlib build). Requires the ObjC-interop runtime
   paths to work with isim's objc runtime (swift_retain/release, ObjC class metadata,
   `_SwiftObject`, bridging NSString<->String).
4. A Swift version of the boilerplate UIKit app, tested in isim and built for device.
5. SwiftUI remains a separate, later investigation (it is a large closed framework to
   re-implement); not promised.

Distribution caveat: the App Store requires builds "with Xcode 26+ / iOS 26 SDK"
(see `docs/distribution-research.md`); a Linux-built Swift runtime does not change that.
