# isim — iOS development on Linux

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

**Updating:** `isim update` installs the newest release and makes it active (`isim update 0.6.0` for a given one);
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

**Compiling** needs clang/lld 17+. Swift needs Docker with the `swift:6.2` image.

## Documentation

- [Scripting and automation](docs/SCRIPTING.md): script commands, `--control` FIFO, interactive shortcuts
- [System prompts, simulated hardware and logs](docs/SYSTEM-PROMPTS.md): environment variables for permissions, biometrics, location, network, logs
- [iOS versions](docs/IOS-VERSIONS.md): `--os 17|18|26|27`, device pairing, `#available`, what changes per version (Liquid Glass)
- [API coverage](docs/COVERAGE.md): what is implemented, per framework and per iOS version
- [Core Data](docs/COREDATA.md) · [Game Center](docs/GAMECENTER.md)

## Build from source

Requirements (Arch/CachyOS): `clang`, `lld`, `llvm`, `sdl3`, `cairo`, `pango`, `librsvg`, `python`, `rsync`, `imagemagick`, Docker.
Optional at run time: `webkitgtk-6.0` + `gtk4` (`gtk4-broadwayd`) for WKWebView / SFSafariViewController / ASWebAuthenticationSession (real WebKit, rendered off screen), `openssl` 3 (`libssl.so.3`) for TLS NWConnections, `libcurl` for URLSession.

```bash
isim/build.sh
```

```bash
isim/test.sh
```

Tools are installed in `isim/out/bin`. To package a release into `isim/dist/` (the build runs in an Ubuntu 22.04 container):

```bash
isim/release/package.sh 0.5.0
```

## Status

Per-API progress (UIKit, SwiftUI, Foundation, StoreKit, Game Center, ...): [docs/COVERAGE.md](docs/COVERAGE.md) — after editing its rows, run `isim/tools/coverage-summary.py` to refresh the summary.

Coverage per iOS version (rows introduced at or before that version; see [docs/COVERAGE.md](docs/COVERAGE.md)):

| | iOS 17 | iOS 18 | iOS 26 | iOS 27 |
|---|---:|---:|---:|---:|
| All areas | 76% (914 rows) | 75% (926) | 74% (943) | 74% (957) |

✅ done · 🟡 partial · ⬜ not started · ⛔ blocked

| Area | Status | Notes |
|---|---|---|
| Compile for iOS on Linux | ✅ | clang/lld produce iOS-simulator (x86_64) and device (arm64) Mach-O |
| Build and test Xcode projects | ✅ | `isim build` (workspaces, schemes, frameworks, static libraries, packages, xcconfig) and `isim test` (XCTest, Swift Testing, XCUITest). Remote packages are never downloaded; arm64-only binary SDKs cannot run |
| Run simulator binaries | ✅ | own Mach-O loader, libSystem subset, Objective-C runtime, Foundation |
| UIKit | 🟡 | views, controls (sliders, steppers, segmented, menus…), Auto Layout, scroll views, text fields, keyboards, alerts, page sheets, view animations, blur, navigation and tab bar controllers, table and collection views (flow, compositional and list layouts, diffable data sources). Not yet: storyboards |
| Swift | ✅ | full runtime, Swift Concurrency, Regex / RegexBuilder, Foundation bridging |
| SwiftUI | 🟡 | isim's own implementation (SwiftUI is closed source): views, state, `@Observable`, `@AppStorage`, Form/List, NavigationStack, TabView, pickers, sheets/alerts, animations and transitions, materials. Not yet: Grid, gradients/paths, searchable |
| Home screen | ✅ | apps run as separate processes; home gesture; background/resume; delete apps. Not yet: App Library, app switcher |
| Settings app | 🟡 | General (About, Date & Time, Keyboard, Language & Region), Display & Brightness, per-app pages |
| Devices | 🟡 | 12 iPhones (SE to 17 Pro Max) and 4 iPads. rotation (Ctrl+Left/Right). Not yet: iPad multitasking |
| Multiple iOS versions | 🟡 | `--os 17\|18\|26\|27`: reported version, `#available`, availability annotations and the look (iOS 26 Liquid Glass, iOS 18 Control Center and icon styles, Lock Screen); iOS 27 uses the iOS 26 look ([details](docs/IOS-VERSIONS.md)) |
| Xcode-like project view | ⬜ | planned; the CLI covers it today |
| Linux releases | ✅ | self-contained tarballs on GitHub Releases |
| Device build (arm64 .app) | 🟡 | executables link; bundle and signature not done |
| Signing + .ipa | ⬜ | candidates: rcodesign, zsign |
| Upload + TestFlight | ⛔ | see below |

API coverage details are in [docs/compatibility-matrix.md](docs/compatibility-matrix.md).

## Rules and limits

- **No Apple SDK or binaries.** isim ships a self-authored SDK, because the Xcode/SDK license restricts its use to Apple hardware.
- **No faked metadata.** Builds never claim Xcode or Apple SDK versions. Binaries are never retargeted to macOS or Linux and reported as iOS compatibility.
- **Upload is blocked.** The App Store requires builds made with a current Xcode/iOS SDK, which a Linux build cannot honestly claim. See [docs/distribution-research.md](docs/distribution-research.md).
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
| `docs/` | research notes |

## License

Apache-2.0, see [LICENSE](LICENSE). Release packages include third-party licenses in `licenses/` ([isim/release/licenses](isim/release/licenses)).

## Trademarks

isim is an independent project. It is not affiliated with, endorsed by, or sponsored by Apple Inc.
Apple, iPhone, iPad, iOS, Xcode, Swift, UIKit, SwiftUI, TestFlight and App Store are trademarks of Apple Inc.,
used here only to describe compatibility.
