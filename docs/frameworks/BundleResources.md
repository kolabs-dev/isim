# Info.plist keys (Bundle Resources)

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 3, approximate, by name) · **Rows:** 31% (13: 4 ✅ 9 ❌) · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Accessibility & Info.plist](../COVERAGE.md#a11y) · **Apple:** [Bundle Resources](https://developer.apple.com/documentation/bundleresources) · **Issues:** [`area:a11y`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aa11y)

## How isim implements it

- **Who reads Info.plist:**
  - `Bundle` (`isim/frameworks/Foundation/Runtime.m`);
  - UIKit;
  - the home screen (`isim/system/SpringBoard`);
  - each framework's privacy checks (`isim/swift/overlays/_Privacy`).
- **Who writes it:** `isim build` (`isim/tools/isim-build.py`), from the project's `INFOPLIST_FILE` and
  `INFOPLIST_KEY_*` settings.
- **A key nobody reads** is accepted silently. An app can then pass on isim and fail on a device, so ignored keys are
  ❌ rows here.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Bundle identity (`CFBundleIdentifier`, `CFBundleName`, `CFBundleDisplayName`, versions, `CFBundleExecutable`, icons, `CFBundleURLTypes`, `CFBundleDocumentTypes`, localizations, `CFBundleDevelopmentRegion`), `UIDeviceFamily`, `MinimumOSVersion` (build only) | ✅ | ≤17 | read by `Bundle`, the home screen and `isim build` |
| Launch and UI keys (`UILaunchScreen` / `UILaunchStoryboardName`, `UIMainStoryboardFile`, `UIApplicationSceneManifest`, `UIApplicationSupportsMultipleScenes`, `UISupportedInterfaceOrientations(~ipad)`, `UIStatusBarHidden`, `UIViewControllerBasedStatusBarAppearance`, `UIAppFonts`, `UIApplicationShortcutItems`) | ✅ | ≤17 | see the UIKit page |
| Background, files and extensions (`UIBackgroundModes`, `BGTaskSchedulerPermittedIdentifiers`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, `NSExtension*`, `UNNotificationExtension*`, `NSSupportsLiveActivities`, `NSAppClip*`, `NSUserActivityTypes`, `INIntentsSupported`) | ✅ | ≤17 | |
| Privacy usage descriptions: camera, microphone, photos (and add-only), location, contacts, calendars, reminders, Health, Siri, speech, Apple Music, tracking, Face ID, Focus status, Game Center friends | ✅ | ≤17 | a missing description stops the app like iOS |
| Privacy usage descriptions: `NSBluetoothAlwaysUsageDescription`, `NSMotionUsageDescription`, `NSLocalNetworkUsageDescription` / `NSBonjourServices`, `NFCReaderUsageDescription`, HomeKit | ❌ | ≤17 | not checked |
| `UIUserInterfaceStyle` (force Light or Dark) | ❌ | ≤17 | ignored: apps that force Light render dark under `--dark` |
| `LSApplicationQueriesSchemes` | ❌ | ≤17 | ignored: `canOpenURL` answers for any scheme |
| `NSAppTransportSecurity` (App Transport Security) | ❌ | ≤17 | not enforced: cleartext HTTP loads |
| `UIDesignRequiresCompatibility` (opt out of Liquid Glass) | ❌ | 26.0 | ignored: the app still gets the iOS 26 design |
| `UIRequiresFullScreen`, `UIRequiredDeviceCapabilities` | ❌ | ≤17 | ignored |
| `UTExportedTypeDeclarations` / `UTImportedTypeDeclarations` | ❌ | ≤17 | ignored by `UTType` (see UniformTypeIdentifiers) |
| `CADisableMinimumFrameDurationOnPhone` | ❌ | ≤17 | ignored |
| iOS 26/27 keys (`LSSupportsGameMode`, `GCSupportedGameControllers`, BackgroundAssets `BA*`, `MusicHapticsSupported`, …) | ❌ | 26.0 | ignored |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
