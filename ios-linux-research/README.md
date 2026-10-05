# iOS development on Linux — feasibility starter

Date: 2026-09-29. Target host: CachyOS, Intel x86-64, NVIDIA GPU.

## Goal
Develop, compile, test in a local compatible simulator, build for iPhone/iPad,
sign, package, and upload to App Store Connect entirely on Linux. No local,
remote, virtualized, or CI-hosted macOS dependency is acceptable as the final solution.

## Current evidence
No working iOS runtime or distribution pipeline has been demonstrated.
The supplied probe tests compiler object generation only. This workspace lacks
Clang and ld64.lld, so compilation was not executed here. Shell syntax and the
missing-compiler error path were checked. No Apple SDK or proprietary files are included.

## Run the first probe when convenient
With Clang and Python 3 available, run `bash probe.sh`.
Alternatively set `CLANG=/absolute/path/to/clang` for that command.
It creates a build directory, records compiler version, compiles the same C
function for x86-64 iOS Simulator and ARM64 iOS, and verifies Mach-O headers,
CPU types, object-file types, and platform load commands. It downloads nothing,
uses no credentials, and changes no system settings.

The experimental iOS 15 deployment target avoids coupling this initial probe
to a current SDK. It is NOT the final release SDK, an installed runtime, or
proof that App Store requirements are met. Both outputs are relocatable objects,
not executable applications. Passing does not demonstrate iOS compatibility.

## Decisions and next gates
1. Use CLI-first experiments, C/Objective-C first, and software graphics first.
   Swift, SwiftUI, React Native, Metal, extensions, and complex resource pipelines
   remain future compatibility work, not promised support.
2. After object generation, pin the actual compiler/linker versions and build
   a minimal executable with explicitly documented startup/runtime requirements.
3. Evaluate Darling at a pinned commit. Record whether it accepts the simulator
   platform and what fails in loading, linking, and startup. Do not silently change
   the target to macOS to claim iOS success. Compare extending Darling with a small
   dedicated loader only after collecting failures. Runtime architecture is undecided.
4. Exercise allocation, threads, Objective-C dispatch, then a UIKit counter app.
   Record implemented APIs and unsupported behavior. Dummy return values must not
   be presented as faithful compatibility.
5. Independently research the device build route: SDK provenance and permitted
   use, current Apple SDK requirements, compiler compatibility, resource tools,
   dynamic libraries, app metadata, entitlements, distribution signing and profiles.
   Never falsify SDK/Xcode metadata to hide an incompatible build.
6. Produce a minimal device .app and distribution .ipa on Linux. Validate bundle
   structure and signing before an authorized upload. Archive organization can be
   added for reproducibility; an .xcarchive alone is not a distribution success.
7. Investigate Apple's Build Upload API, including file transfers, completion,
   authentication, errors and processing status. Endpoint existence is not evidence
   of a completed Linux upload or Apple's acceptance of our toolchain.
8. End-to-end gate: same sample source tested in our Linux runtime, built for device
   on Linux, signed and uploaded on Linux, processed by Apple and installed through
   TestFlight on a physical iPhone. App Review is a separate external decision.

## When user-specific information becomes necessary
- RAM and disk: before choosing full Darling/toolchain build parallelism and storage.
- Kernel and security settings: before runtime integration on CachyOS.
- NVIDIA driver and Wayland/X11: before interactive rendering and input.
- Apple developer team and signing materials: only at signing/upload integration.
  Keep private keys and API credentials local; never paste them into chat or commit them.
- A physical iPhone: device/TestFlight verification; simulator behavior alone is insufficient.

## Initial research references
- LLVM Mach-O linker: https://lld.llvm.org/MachO/index.html
- Darling: https://github.com/darlinghq/darling
- touchHLE (older iPhone OS scope): https://github.com/touchHLE/touchHLE
- Apple simulator architecture: https://developer.apple.com/videos/play/wwdc2019/418/
- Build upload API: https://developer.apple.com/documentation/appstoreconnectapi/post-v1-builduploads
- Apple upload workflow: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds

## Immediate next task
Run the object probe in a Linux environment with LLVM installed. Capture actual
versions and results, then test executable linking/loading. Hardware inventory
does not block source preparation, API research, or these compiler experiments.
