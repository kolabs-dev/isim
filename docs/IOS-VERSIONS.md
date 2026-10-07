# iOS versions (`--os`)

isim emulates the API level and the look of **iOS 17, 18, 26 and 27**. The default is **iOS 18** (18.0), as before.
isim is not Apple's iOS: the version is what isim reports and how it behaves, and builds never claim an Apple SDK
or Xcode version.

```bash
isim run MyApp.app --os 26 --device iphone17
isim boot --os 17 --device iphone15
isim test -project App.xcodeproj -scheme App --os 27 --device iphone17      # or -destination 'platform=iOS Simulator,OS=27.0'
ISIM_OS_VERSION=17.5 isim run MyApp.app --device ipadpro11                   # point releases are accepted
isim devices                                                                 # devices and the versions each can run
isim version                                                                 # supported versions and the device data's version
```

Labels used below: **passthrough** (the real implementation runs unchanged), **adapted** (isim's own
re-implementation or approximation), **stub** (accepted so apps compile and run, no real effect);
**verified** (an isim test checks it) or **proposed** (implemented, not checked by a test).

## Choosing the version

| What | Behaviour | Label |
|---|---|---|
| `--os N` on `boot`, `run`, `test`; `ISIM_OS_VERSION` | `N` is `17`, `18`, `26`, `27` (= `N.0`) or a point release (`17.5`, `18.4`, …) | adapted, verified |
| Remembered per device data | an explicit `--os` / `ISIM_OS_VERSION` is saved in `$ISIM_DATA/Library/isim/os-version`; later `boot`/`run` without one use it | adapted, verified |
| Reported in | `UIDevice.systemVersion`, `ProcessInfo.operatingSystemVersion` / `operatingSystemVersionString` / `isOperatingSystemAtLeast`, Settings ▸ General ▸ About, `isim version`, `isim devices` | adapted, verified |
| Unsupported versions (e.g. `--os 19`) | rejected with the list of supported versions (exit 2) | verified |

### Device and version pairing (like Xcode)

Every device preset has the first iOS release it shipped with, like a CoreSimulator device type's minimum
runtime. Xcode does not create a simulator for a device with an older runtime (`simctl create` fails with an
incompatible runtime), and when no runtime is chosen it picks a compatible one. isim does the same:

- an **explicit** older version (`--os`, `ISIM_OS_VERSION`) is **rejected** with a clear message (exit 2);
- **without** one (the default iOS 18, or the device data's remembered version), the **nearest valid** version is
  used and logged, e.g. `isim: iPhone 17 requires iOS 26.0 or later; using iOS 26.0 instead of the default iOS 18.0`.

| Devices | First iOS | `--os` values |
|---|---|---|
| iPhone SE (3rd generation), iPhone 13 mini, iPhone 14, iPad mini (6th generation) | 15.4 / 15.0 / 16.0 / 15.0 | 17, 18, 26, 27 |
| iPhone 15, 15 Plus, 15 Pro Max | 17.0 | 17, 18, 26, 27 |
| iPad Air 11-inch (M2), iPad Pro 11-inch / 13-inch (M4) | 17.5 | 17.5, 18, 26, 27 |
| iPhone 16 Pro, 16 Pro Max | 18.0 | 18, 26, 27 |
| iPhone 17, iPhone Air, 17 Pro, 17 Pro Max | 26.0 | 26, 27 |

No preset is dropped by iOS 27 (Apple's iOS 27 compatibility list still includes iPhone SE (3rd generation) and
iPhone 13 mini), so there is no maximum version.

## `#available` and the Swift standard library

`#available` / `if #available` / `#unavailable` (Swift) and `@available` / `__builtin_available` (Objective-C)
follow the selected version (verified for iOS 18, 26 and 27 under each `--os` by `tests/ui/osversions.sh`).

- isim's libswiftCore is now built with `SWIFT_RUNTIME_OS_VERSIONING` (CMake's `SWIFT_STDLIB_OS_VERSIONING`,
  on by default for Apple platforms). Swift's availability checks inline `_stdlib_isOSVersionAtLeast_AEIC`, which
  calls `__isPlatformVersionAtLeast`; isim's libSystem answers it (and `__isOSVersionAtLeast`) from the selected
  version. Before, the stdlib was built without it and every check above the deployment target was false.
  Apps must be rebuilt against the new SDK for their own `#available` checks to change (the check is inlined).
- **Effect on the stdlib itself** (passthrough of upstream code): the stdlib's own `if #available(SwiftStdlib X, *)`
  branches now follow the selected version, exactly like Apple's back-deployment. With the old build every branch
  newer than the stdlib's iOS 15 deployment target took the older code path; now:
  - iOS 17: SwiftStdlib ≤ 5.10 paths (iOS 17.0–17.4 features) are taken, 6.0/6.1/6.2 paths are not;
  - iOS 18.0 (the default): ≤ 6.0 paths are taken (6.1 needs 18.4, 6.2 needs 26.0);
  - iOS 26/27: all paths, including SwiftStdlib 6.2.
  isim ships the whole 6.2.4 runtime on every version, so the newer paths always have their runtime support. APIs
  that are `@available(SwiftStdlib 6.x)` stay compile-time gated, like on a device: code using them (e.g.
  `Int128`) needs `if #available(iOS 18, *)`, and on `--os 17` the `else` branch runs
  (verified with `Int128`). The Swift runtime, stdlib, concurrency, libraries and Foundation self-tests pass
  unchanged under `--os 17`, `18`, `26` and `27` (`OS_MATRIX=1 ./test.sh`), and the full `test.sh` passes on the
  default iOS 18.
- The Objective-C runtime and C++ runtime parts (`Bincompat.cpp`) keep their non-Apple rules: they need
  `dyld_priv.h`, which isim does not have; app SDK-version checks are therefore not version-dependent.

## SDK annotations

- `API_AVAILABLE(ios(N))`, `API_UNAVAILABLE`, `API_DEPRECATED(…, ios(a, b))`, `NS_AVAILABLE_IOS` and friends in
  isim's `Availability.h` are now real clang availability attributes (they were empty). Objective-C gets
  `-Wunguarded-availability` warnings and Swift (through the Clang importer) `@available(iOS N, *)`.
- APIs introduced in iOS 18/26/27 that isim implements carry `API_AVAILABLE` / `@available` with the version from
  Apple's documentation (checked against developer.apple.com): `UIGlassEffect`, `UIGlassContainerEffect`,
  `UIBackgroundExtensionView`, the `UIButton.Configuration` glass styles (26.0); SwiftUI `Tab`,
  `TabRole.search`, `.sidebarAdaptable`, `.tabBarOnly`, `NavigationTransition`/`navigationTransition`/
  `matchedTransitionSource` (18.0); `Glass`, `glassEffect`, `GlassEffectContainer`, `glassEffectID`,
  `glassEffectUnion`, `.glass`/`.glassProminent`, `ToolbarSpacer`, `tabBarMinimizeBehavior`,
  `scrollEdgeEffectStyle`, `backgroundExtensionEffect`, `tabViewBottomAccessory` (26.0); `TabRole.prominent`,
  `visibilityPriority`, `ToolbarItemVisibilityPriority`, `ToolbarOverflowMenu`, `.topBarPinnedTrailing`,
  `toolbarMinimizationBehavior`, `swipeActionsContainer`, `asyncImageURLSession`, `.crossFade` (27.0).
- Deprecations keep Apple's versions where isim declares them. No SDK or Xcode metadata is changed to make a build
  look like an Apple one.

## What changes per version

| Area | iOS 17 | iOS 18 | iOS 26 / 27 | Label |
|---|---|---|---|---|
| Tab bar (iPhone) | material bar | material bar | floating Liquid Glass capsule, selected tab on a pill, search/prominent role tabs on their own glass circle (UIKit and SwiftUI) | adapted, verified (pixels) |
| Tab bar (iPad) | bottom bar | floating capsule at the top, titles only | glass capsule at the top | adapted, proposed |
| Navigation bar | material when scrolled | same | scroll-edge fade, glass back button (chevron only), glass bar items (Done items prominent) | adapted, verified (frames) |
| Toolbars | material bar | same | items on glass capsules, edge fade | adapted, proposed |
| Alerts | 270 pt card | same | 300 pt glass card, corner 34, leading text, capsule buttons, preferred action filled | adapted, verified (pixels) |
| Action sheets, menus, sheets, popovers | classic | same | glass cards / larger corners | adapted, proposed |
| Switch | 51 × 31 | same | 63 × 28, pill thumb | adapted, verified |
| Configuration buttons, SwiftUI bordered buttons | rounded rect | same | capsule | adapted, proposed |
| `UIGlassEffect`, glass button configurations, `glassEffect`, `.glass` | unavailable (compile-time) | unavailable | drawn as glass | adapted, verified |
| Home screen | translucent dock | + icon appearance (`ISIM_ICON_STYLE=dark\|tinted`) | glass dock, icon rims, + `clear` icons | adapted, verified (dock pixels) |
| Lock Screen (`lock`) | bold clock | bold clock | tall glass numerals, glass buttons | adapted, verified (pixels) |
| Control Center (`controlcenter`) | iOS 17 modules | iOS 18 redesign: edit/power buttons, page column, round toggles | glass modules | adapted, verified (pixels) |
| Permission alert wording | iOS 17 (e.g. contacts: Don't Allow / OK) | iOS 18 (limited access) | as iOS 18 | adapted, verified (existing suites) |
| UIKit tabs (`UITab`, `UITabGroup`, `UISearchTab`, iPad sidebar) | classic view-controller tabs (API unavailable) | tab bar from tabs; iPad sidebar (`.tabSidebar`) | glass sidebar, `UIBackgroundExtensionView` under it | adapted, verified (HelloTabs) |
| `UIUpdateLink`, zoom transition (`preferredTransition`), symbol effects wiggle / breathe / rotate | unavailable | per-frame actions; zoom push/present from the source view; effects animate the image | same; + draw on / off effects | adapted, verified (HelloTabs, HelloViews, HelloSymbolEffects) |
| Automatic observation tracking (`layoutSubviews`, `updateProperties`) | off | only with `UIObservationTrackingEnabled` | on | passthrough, verified (HelloTabs) |
| `UIBarButtonItem.badge`, `UIScrollEdgeEffect` | unavailable | unavailable | badges drawn; hard / soft edge effects | adapted, verified (HelloTabs) |

### Liquid Glass

isim draws Liquid Glass with its own approximation (`isim_gfx_glass` in the host): a soft shadow, a light backdrop
blur (glass bends light rather than frosting it), a translucent body (tinted when asked), a brighter top-left
specular rim and a faint inner glow. There is no refraction/lensing, no morphing between shapes in a
`GlassEffectContainer` and no motion response. Apple's design was checked against Apple's iOS 26 documentation and
the WWDC25 material; exact metrics (corner radii, insets) are isim's estimates.

### iOS 27

Verified from Apple's documentation (developer.apple.com, "SwiftUI updates" / "UIKit updates", June 2026):

- implemented (adapted or stub): `TabRole.prominent`, `ToolbarItemVisibilityPriority` + `visibilityPriority(_:)`,
  `ToolbarOverflowMenu`, `ToolbarItemPlacement.topBarPinnedTrailing`, `toolbarMinimizationBehavior(_:for:)`,
  `swipeActionsContainer()`, `asyncImageURLSession(_:)`, `NavigationTransition.crossFade`;
- not done (listed as ❌ in [COVERAGE.md](COVERAGE.md)): `ReadableDocument`/`WritableDocument`, `reorderable()`,
  `reorderContainer`, swipe actions on any view, `AsyncImage(request:)`, the `@State` macro / `ContentBuilder`
  (Xcode 27 compiler features), gesture input kinds, UIKit `NSTextTable` family, attachment view reuse,
  `allowsPointerDragBeforeLiftDelay`; iOS 27.1 (beta) iPhone Duo APIs (arrangement views, reserved regions, hinge,
  vertical bars);
- **not done: iOS 27 visuals.** Apple describes an updated Liquid Glass appearance and a tint slider without
  specifications isim could reproduce faithfully, so `--os 27` uses the iOS 26 look. iOS 27 also requires apps
  built with the iOS 27 SDK to adopt the scene-based life cycle; isim does not enforce that.

## Tests

- `tests/ui/osversions.sh` runs `samples/HelloOSVersions` (UIKit and SwiftUI) under each `--os` and checks the
  versions, `#available`/`@available`, version-gated APIs, the look by pixels, the Lock Screen and Control Center,
  Settings ▸ About, device pairing and the remembered version. It is part of `test.sh`.
- `OS_MATRIX=1 ./test.sh` also runs the version-sensitive suites under all four versions (iPhone 15 for 17,
  iPhone 16 Pro for 18, iPhone 17 for 26/27): the Swift runtime/stdlib/concurrency/Foundation self-tests, the
  Objective-C constant literals test (tests/objc-literals),
  HelloCounter, HelloSwiftUI, HelloControls, the device shell (`boot.sh`) and, on 18/26/27, forms, navigation,
  presentations, transitions and table. Those five assert frames and tap points of the 402-pt screen (or use
  iPads first sold with iOS 17.5), which no iPhone that runs iOS 17.0 has, so the iOS 17 pass leaves them out.
- The other UI suites run on iPhone 16 Pro by default (the iPhone 17 screen size, able to run the default iOS 18);
  `ISIM_TEST_DEVICE` overrides the device.

## Coverage

[COVERAGE.md](COVERAGE.md) has an **iOS** (introduced in) column and a per-version summary: a row counts toward iOS N
when it was introduced at or before N. Run `isim/tools/coverage-summary.py` after editing rows.
