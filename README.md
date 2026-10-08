# isim — iOS development on Linux

[![CI](https://github.com/kolabs-dev/isim/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/kolabs-dev/isim/actions/workflows/ci.yml?query=branch%3Amain+event%3Apush)

An iOS-compatible simulator and toolchain that runs on Linux, with no macOS, VM or remote Mac.
It builds Objective-C and Swift apps (UIKit and SwiftUI) from their Xcode projects and runs them
on a simulated iPhone or iPad with a home screen and a Settings app.

Goal: write → build → run in the simulator → device build → sign → upload → TestFlight, all on Linux.

![isim: home screen, Settings, and a SwiftUI app](docs/images/isim-overview.png)

## Quick start (no build needed)

Install the latest release (Linux x86_64, glibc 2.35+, with `python3`, `curl`, fontconfig and `adwaita-icon-theme`):

```bash
curl -fsSL https://raw.githubusercontent.com/kolabs-dev/isim/main/install.sh | bash
```

This unpacks the release into `~/.local/lib/isim/<version>` and puts `isim` in `~/.local/bin` (add it to your `PATH`
if the installer says so). Then:

```bash
isim boot
```

This opens the device on its home screen, with Settings in the dock. To add the demo apps:

```bash
isim install ~/.local/lib/isim/current/apps/*.app
```

**Updating:** `isim update` installs the newest release and makes it active (`isim update 0.11.0` for a given one);
`isim versions` lists the installed releases and `isim use VERSION` switches between them. Device data
(`~/.local/share/isim`) is shared by all versions. You can also download a tarball from
[Releases](https://github.com/kolabs-dev/isim/releases) and run `bin/isim` from it directly.

## Usage

| Command | What |
|---|---|
| `isim boot` | start the device on its home screen |
| `isim install App.app…` · `isim uninstall NAME` · `isim apps` | manage installed apps |
| `isim run App.app [args…]` | install, boot and open the app over the home screen (headless or `ISIM_STANDALONE=1`: the app alone) |
| `isim reset` | erase installed apps, app data and settings |
| `isim build (-project App.xcodeproj \| -workspace App.xcworkspace) [-scheme S \| -target T] [-configuration Release] [-o DIR]` | build an Xcode project or workspace: apps, extensions, frameworks, static libraries, local Swift packages, `.xcframework`s (x86_64 simulator slice), `.xcconfig` files |
| `isim test -project App.xcodeproj -scheme S [-only-testing:Target/Class/test] [-resultBundlePath DIR]` | build and run the scheme's test targets like `xcodebuild test`: XCTest (hosted in the app or standalone), Swift Testing and XCUITest; exits 65 on failures |
| `isim cc …` · `isim swiftc …` | compile files for the isim SDK |
| `isim info App.app` | show Mach-O platform and dependencies |
| `isim push [BUNDLE_ID] payload.apns\|-` | send a remote notification to the running device, like `xcrun simctl push` (or drop a `.apns` file on it) |
| `isim devices` · `isim version` | device presets with the iOS versions each can run; the isim version and supported iOS versions |

**Options** for `boot`, `run` (and `--os`/`--device` for `test`):
- `--os 17|18|26|27` (or a point release such as `17.5`; env `ISIM_OS_VERSION`): the iOS version the device runs, default 18.
  It sets the reported version, what `#available` answers and the look (Liquid Glass from 26). The device data
  remembers it. Like Xcode, a device needs at least the iOS it shipped with (iPhone 17 models: 26): an explicit older
  version is rejected, otherwise the nearest valid one is used. See [docs/IOS-VERSIONS.md](docs/IOS-VERSIONS.md).
- `--device iphonese|iphone13mini|iphone14|iphone15|iphone15plus|iphone15promax|iphone16pro|iphone16promax|iphone17|iphoneair|iphone17pro|iphone17promax|ipadmini|ipadair11|ipadpro11|ipadpro13`
- `--zoom 0.8`
- `--dark`
- `--headless --script "…"`

**On the device:**
- Click to touch, drag to swipe.
- Swipe up from the bottom edge (or press Ctrl+Shift+H) to go home.
- Press and hold an icon to delete the app.
- F12 takes a screenshot.
- Device data lives in `~/.local/share/isim` (override with `ISIM_DATA`).

**Automation:** `--headless --script "wait 2; tapid login; shot s.png; quit"` drives the device from tests and CI;
see [docs/SCRIPTING.md](docs/SCRIPTING.md) for every command. Permission prompts, Face ID, location, microphone
and logs can be answered or configured with environment variables: see [docs/SYSTEM-PROMPTS.md](docs/SYSTEM-PROMPTS.md).

**Compiling** needs clang/lld 21 or newer (isim's SDK ships libc++ 22; on Ubuntu/Debian get it from [apt.llvm.org](https://apt.llvm.org)). Constant Objective-C literals (clang 23) are supported. Swift needs Docker with the `swift:6.2` image.

## Documentation

- [Scripting and automation](docs/SCRIPTING.md): script commands, `--control` FIFO, interactive shortcuts
- [System prompts, simulated hardware and logs](docs/SYSTEM-PROMPTS.md): environment variables for permissions, biometrics, location, network, logs
- [iOS versions](docs/IOS-VERSIONS.md): `--os 17|18|26|27`, device pairing, `#available`, what changes per version (Liquid Glass)
- [API coverage](docs/COVERAGE.md): what is implemented, per framework and per iOS version
- [Core Data](docs/COREDATA.md) · [Game Center](docs/GAMECENTER.md): isim's model and configuration formats
- [App Store distribution](docs/DISTRIBUTION.md): why upload from Linux is blocked
- [Building](docs/BUILD.md) · [Testing](docs/TESTING.md): build.py, the Ninja graph, adding samples/frameworks/overlays; pytest and CI

## Build from source

Requirements: clang/lld/llvm 21 or newer, `python3` (with `venv`), `pkg-config`, SDL3, cairo, pango, librsvg,
gdk-pixbuf, fontconfig, ImageMagick and Docker (Swift compiles in the `swift:6.2` image). Package names for Ubuntu are
in [isim/ci/Dockerfile](isim/ci/Dockerfile), which CI builds on; on Arch/CachyOS: `clang lld llvm sdl3 cairo pango
librsvg python imagemagick docker`.
Optional at run time: `webkitgtk-6.0` + `gtk4` (`gtk4-broadwayd`) for WKWebView / SFSafariViewController / ASWebAuthenticationSession (real WebKit, rendered off screen), `openssl` 3 (`libssl.so.3`) for TLS NWConnections, `libcurl` for URLSession.
Media and ML (each used only when an app needs it): `ffmpeg` (video, export, asset reader/writer, the simulated camera `ISIM_CAMERA`), `zbar` (QR/barcodes in capture and Vision), `tesseract` (Vision text recognition), whisper.cpp or Vosk (Speech recognition). Tests that need a missing tool skip it.

```bash
isim/build.py fetch
```

```bash
isim/build.py
```

```bash
isim/build.py test
```

`fetch` clones the pinned Swift and LLVM sources into `third_party/` (once). `build.py` builds everything with Ninja
(from `PATH`, or installed into `isim/out/pyenv`): only steps whose inputs changed run, independent steps run in
parallel, and a build with nothing to do takes well under a second. `build.py test` runs the pytest suites in
`isim/tests` (arguments go to pytest: `isim/build.py test -k navigation`); see [docs/BUILD.md](docs/BUILD.md) and [docs/TESTING.md](docs/TESTING.md).

Tools are installed in `isim/out/bin`. To package a release into `isim/dist/` (the host runtime is built in an Ubuntu
22.04 container):

```bash
isim/build.py package 0.11.0
```

## Status

API coverage is tracked per framework and per iOS version in [docs/COVERAGE.md](docs/COVERAGE.md) (about 80% of its
rows). ✅ done · 🟡 partial · ⬜ not started · ⛔ blocked

| Area | Status | Notes |
|---|---|---|
| Build for iOS on Linux | ✅ | clang/lld and Swift 6.2 produce iOS-simulator (x86_64) and device (arm64) Mach-O; `isim build` / `isim test` handle Xcode projects, workspaces, packages and XCTest / Swift Testing / XCUITest |
| Run simulator binaries | ✅ | own Mach-O loader, libSystem, Objective-C and Swift runtimes, Foundation; apps keep running across isim updates (ABI checked); Swift apps built before 0.12 need one rebuild (the base Swift overlays became resilient) |
| UIKit · SwiftUI | 🟡 | broad coverage, including storyboards and SwiftUI navigation, presentation and effects; SwiftUI is isim's own implementation |
| Device | ✅ | home screen (pages, folders, App Library, Spotlight, widgets), lock screen, Notification Center, Control Center, app switcher, Settings; 12 iPhones and 4 iPads; iOS 17, 18, 26 and 27 |
| Linux releases | ✅ | `install.sh`, `isim update` |
| Device build, signing, .ipa | 🟡 | arm64 executables link; bundling and signing not done |
| Upload + TestFlight | ⛔ | see below |

## Rules and limits

- **No Apple SDK or binaries.** isim ships a self-authored SDK, because the Xcode/SDK license restricts its use to Apple hardware.
- **No faked metadata.** Builds never claim Xcode or Apple SDK versions. Binaries are never retargeted to macOS or Linux and reported as iOS compatibility.
- **Upload is blocked.** The App Store requires builds made with a current Xcode/iOS SDK, which a Linux build cannot honestly claim. See [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).
- **Keys stay local.** Signing keys and API credentials stay on the machine, out of the repo.

## Repository layout

| Path | What |
|---|---|
| `isim/runtime` | Linux host: loader, libSystem, ObjC runtime, window, rendering, device shell |
| `isim/sdk-src`, `isim/frameworks`, `isim/swift` | SDK headers; Foundation, UIKit, …; Swift runtime and overlays (including SwiftUI) |
| `isim/system` | home screen (SpringBoard) and Settings apps |
| `isim/tools` | `isim` CLI and Xcode project builder |
| `isim/samples`, `isim/tests` | demo apps and test suites |
| `isim/release` | release packaging |
| `docs/` | documentation |

## License

Apache-2.0, see [LICENSE](LICENSE). Release packages include third-party licenses in `licenses/` ([isim/release/licenses](isim/release/licenses)).

## Trademarks

isim is an independent project. It is not affiliated with, endorsed by, or sponsored by Apple Inc.
Apple, iPhone, iPad, iOS, Xcode, Swift, UIKit, SwiftUI, TestFlight and App Store are trademarks of Apple Inc.,
used here only to describe compatibility.
