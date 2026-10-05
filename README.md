# isim — iOS development on Linux

Write code → compile → run in a local iOS-compatible simulator → build for iPhone/iPad →
sign → package → upload to App Store Connect, **entirely on Linux** (no macOS machine, VM,
remote Mac or Mac CI). Apps in **Objective-C and Swift**.

**Acceptance test:** the same sample app runs in our Linux simulator, is built and signed on
Linux, uploaded from Linux, and installs on an iPhone through TestFlight. (App Review is a
separate outcome.)

---

## Progress

_Last updated: 2026-10-05._ Legend: ✅ done and verified · 🟡 in progress / partial · ⬜ not started · ⛔ blocked

### Overall

| Stage | Status | Evidence / notes |
|---|---|---|
| 1. Compile for iOS targets on Linux | ✅ | clang/lld 22.1.8 produce iOS-simulator (x86_64) and iOS (arm64) Mach-O objects and executables — `results/01-probe.txt`, `experiments/02-link` |
| 2. Run iOS-simulator binaries on Linux | ✅ | own loader + runtime (`isim/runtime`); C, threads, ObjC, Foundation self-test 32/32 |
| 3. Simulator UI: boilerplate UIKit app in a window | ✅ | Xcode-template ObjC app (`isim/samples/HelloCounter`) runs in a Wayland window on this machine; UI test 9/9 |
| 4. Swift support | 🟡 | Embedded Swift → arm64 iOS Mach-O works on Linux; full Swift runtime for simulator not started — `docs/swift-plan.md` |
| 5. Device build (arm64 .app) | 🟡 | arm64 executables link; code signature, resources, bundle not done |
| 6. Signing + .ipa | ⬜ | candidate tools identified (rcodesign, zsign) — `docs/distribution-research.md` |
| 7. Upload from Linux | ⬜ | Build Upload API flow documented; untested; needs your Apple account later |
| 8. TestFlight install on iPhone | ⛔ | blocked by the policy items below |

### Simulator compatibility (what runs today)

| Area | Status | Notes |
|---|---|---|
| Mach-O loading (exec + dylibs, chained fixups, legacy binds, export tries, rpaths) | ✅ | refuses non-iOS-simulator binaries |
| libSystem subset (libc, pthreads with Darwin layouts, time, errno) | ✅ | passthrough vs adapted vs stub labelled per symbol |
| Objective-C runtime (dispatch, categories, ivar sliding, +initialize, ARC, weak, blocks) | ✅ | no exceptions, no forwarding, no tagged pointers |
| Foundation subset (strings, collections, numbers, bundle/Info.plist, timers, run loop, dispatch subset, notifications) | ✅ | in-memory NSUserDefaults; XML plists only |
| CoreGraphics subset (geometry, colors, simple context drawing) | ✅ | |
| UIKit: app/scene lifecycle, views, labels, buttons, switches, stack views, Auto Layout subset, touches, light/dark | ✅ | subset — see `docs/compatibility-matrix.md` |
| Rendering + input (SDL3 window on Wayland, cairo/pango software rendering, device chrome) | ✅ | mouse = single touch; headless scripted mode for tests |
| Images, text input/keyboard, scrolling, tables, navigation/tab controllers, real animations, storyboards | ⬜ | next UIKit milestones |
| SwiftUI, WebKit, Metal | ⬜ | later investigations, not promised |

### Distribution blockers (from `docs/distribution-research.md`)

1. ⛔ **Apple SDK license:** the Xcode/SDK agreement allows use only on Apple-branded hardware, so isim uses a **self-authored SDK** (headers + stubs) instead of Apple's.
2. ⛔ **"Built with Xcode 26+ / iOS 26 SDK" upload rule:** a non-Xcode build can't honestly claim this, and we will not fake SDK/Xcode metadata. The only legitimate path found is written permission from Apple.
3. 🟡 Unproven: whether Apple accepts Linux-produced `Assets.car`, signatures, and the `AppStoreInfo.plist` asset description.

![HelloCounter running in isim on Linux (light and dark appearance)](docs/images/hellocounter.png)

_HelloCounter — the Xcode Objective-C App template plus a small counter UI — rendered by isim on Linux (left: after three taps; right: dark appearance)._

### Next steps

1. Swift: build Embedded Swift for the simulator target, then the full Swift runtime/stdlib cross-build, and a Swift version of HelloCounter.
2. UIKit breadth: UIScrollView, UITableView, UINavigationController, UITextField + keyboard, UIImage decoding, real animations.
3. Device: ad-hoc code signature + `.app` bundle for arm64; then distribution signing experiments.
4. Storyboard support (a Linux storyboard compiler) so the unmodified Xcode template works.

---

## Repository layout

| Path | What |
|---|---|
| `isim/` | the simulator: `runtime/` (Linux host: loader, libSystem, ObjC runtime, window/rendering), `sdk-src/` (self-authored iOS SDK headers), `frameworks/` (Foundation, CoreGraphics, UIKit implementations compiled as iOS-simulator Mach-O), `tests/`, `samples/`, `build.sh` |
| `experiments/` | numbered research experiments with their scripts (02 link, 03 loader, 04 Darling, 05 ObjC, 06 Swift) |
| `docs/` | compatibility matrix, research reports (Darling evaluation, distribution research, Swift plan) |
| `results/` | captured outputs of experiments |
| `probe.sh`, `probe.c` | the original object-generation probe |

## Build and run

Requirements (Arch/CachyOS): `clang`, `lld`, `llvm`, `sdl3`, `cairo`, `pango`, `python`, `rsync`.

```bash
isim/build.sh
```

```bash
isim/out/bin/isim run isim/out/apps/HelloCounter.app
```

Options: `--device iphone15|iphonese|ipad`, `--zoom 0.8`, `--dark`. Click = touch, F12 = screenshot.

```bash
isim/test.sh
```

Compile your own app against the isim SDK: `isim/out/bin/isim cc main.m AppDelegate.m ... -framework UIKit -o MyApp.app/MyApp`.

## Environment (verified 2026-10-05)

CachyOS, kernel 7.2.7-1-cachyos, Intel Core Ultra 9 275HX (24 cores, x86-64), 30 GiB RAM,
NVIDIA RTX 5070 Laptop (driver 615.71.09), GNOME on Wayland, clang/lld 22.1.8, Python 3.14.7.
~11 GB free on `/`.

## Decisions

- **Runtime:** dedicated compatibility layer (own loader + ObjC runtime + framework subset), not Darling.
  Darling (pinned `60ba801`) runs our simulator binaries only after relabelling its macOS libraries,
  has no UIKit, and needs a privileged GPL-3.0 multi-GB stack. It remains a reference — `docs/darling-evaluation.md`.
- **No Apple SDK or Apple binaries** are used or redistributed. `LC_BUILD_VERSION` records `sdk n/a`.
- **Honesty rules:** never retarget a binary to macOS/Linux and call it iOS compatibility; never fake
  SDK/Xcode metadata; label every runtime symbol as passthrough / adapted / isim / stub.
- CLI first, C/ObjC first, software rendering first. Swift is a first-class goal; SwiftUI/WebKit/Metal are later.
- Signing keys and API credentials stay local and out of the repo (`.gitignore` blocks common key/profile files).

## References

- LLVM Mach-O linker: https://lld.llvm.org/MachO/index.html
- Darling: https://github.com/darlinghq/darling
- touchHLE: https://github.com/touchHLE/touchHLE
- Apple simulator architecture (WWDC19 418): https://developer.apple.com/videos/play/wwdc2019/418/
- Build Upload API: https://developer.apple.com/documentation/appstoreconnectapi/post-v1-builduploads
- Upload workflow: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
