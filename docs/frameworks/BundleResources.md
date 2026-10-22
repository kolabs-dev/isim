# Info.plist keys (Bundle Resources)

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 3, approximate, by name) · **Rows:** 16: 10 ✅ 1 🟡 5 ❌ · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Accessibility & Info.plist](../COVERAGE.md#a11y) · **Apple:** [Bundle Resources](https://developer.apple.com/documentation/bundleresources) · **Issues:** [`area:a11y`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aa11y)

## How isim implements it

- **Who reads Info.plist:**
  - `Bundle` (`isim/frameworks/Foundation/Runtime.m`);
  - UIKit;
  - the home screen (`isim/system/SpringBoard`);
  - each framework's privacy checks (`isim/swift/overlays/_Privacy`).
- **Who writes it:** `isim build` (`isim/tools/isim-build.py`), from the project's `INFOPLIST_FILE` and
  `INFOPLIST_KEY_*` settings; with `GENERATE_INFOPLIST_FILE = YES` also `CFBundleShortVersionString` and
  `CFBundleVersion` from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` when the file doesn't set them, like Xcode
  (issue #640; tested by `test_new_project.py`).
- **A key nobody reads** is accepted silently. An app can then pass on isim and fail on a device, so ignored keys are
  ❌ rows here.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Bundle identity (`CFBundleIdentifier`, `CFBundleName`, `CFBundleDisplayName`, versions, `CFBundleExecutable`, icons, `CFBundleURLTypes`, `CFBundleDocumentTypes`, localizations, `CFBundleDevelopmentRegion`), `UIDeviceFamily`, `MinimumOSVersion` (build only) | ✅ | ≤17 | read by `Bundle`, the home screen and `isim build` |
| Launch and UI keys (`UILaunchScreen` / `UILaunchStoryboardName`, `UIMainStoryboardFile`, `UIApplicationSceneManifest`, `UIApplicationSupportsMultipleScenes`, `UISupportedInterfaceOrientations(~ipad)`, `UIStatusBarHidden`, `UIViewControllerBasedStatusBarAppearance`, `UIAppFonts`, `UIApplicationShortcutItems`) | ✅ | ≤17 | see the UIKit page |
| Background, files and extensions (`UIBackgroundModes`, `BGTaskSchedulerPermittedIdentifiers`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, `NSExtension*`, `UNNotificationExtension*`, `NSSupportsLiveActivities`, `NSAppClip*`, `NSUserActivityTypes`, `INIntentsSupported`) | ✅ | ≤17 | |
| Privacy usage descriptions: camera, microphone, photos (and add-only), location, contacts, calendars, reminders, Health, Siri, speech, Apple Music, tracking, Face ID, Focus status, Game Center friends | ✅ | ≤17 | a missing description stops the app like iOS |
| Privacy usage descriptions: `NSBluetoothAlwaysUsageDescription`, `NSMotionUsageDescription`, `NFCReaderUsageDescription` | ✅ | ≤17 | adapted: without the key, iOS terminates the app; isim logs iOS's message and denies the access (Core Bluetooth `.unauthorized` / `.denied`, Core Motion's pedometer, activity and altimeter `.denied` with `motionActivityNotAuthorized`, a Core NFC session invalidated with `readerErrorSecurityViolation`). Tested (HelloInfoPlist, tests/ui/test_info_plist.py) |
| `NSBonjourServices`, `NSLocalNetworkUsageDescription` | 🟡 | ≤17 | adapted: browsing or advertising a Bonjour type the app does not declare fails with NoAuth (-65555), like iOS 14+ (Network's `NWBrowser` / `NWListener`, and MultipeerConnectivity, which needs `_<type>._tcp` and `_<type>._udp`); a missing usage description is logged. Not yet: the local network permission prompt (isim allows local network access). Tested (HelloInfoPlist, tests/ui/test_info_plist.py) |
| HomeKit usage description | ❌ | ≤17 | not checked |
| `UIUserInterfaceStyle` (force Light or Dark) | ✅ | ≤17 | adapted: `Light` or `Dark` is the app's base style (its trait collections, UIKit and SwiftUI content, alerts and the keyboard), whatever the device's Dark Mode setting, at launch and when it changes; `Automatic` or no key follows the device. Tested (HelloInterfaceStyle, tests/ui/test_interface_style.py) |
| `LSApplicationQueriesSchemes` | ✅ | ≤17 | adapted: `canOpenURL` answers only for the declared schemes (the first 50, iOS 15+), the app's own and the system's (`http(s)`, `mailto`, `tel`, `sms`, `facetime`, Settings); for the others it returns `false` and logs iOS's "not allowed to query for scheme" message. `open(_:)` is not limited. Tested (HelloInfoPlist, tests/ui/test_info_plist.py) |
| `NSAppTransportSecurity` (App Transport Security): `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsInWebContent`, `NSAllowsLocalNetworking`, `NSExceptionDomains` (`NSIncludesSubdomains`, `NSExceptionAllowsInsecureHTTPLoads`, `NSExceptionMinimumTLSVersion`, `NSExceptionRequiresForwardSecrecy`, and the `NSThirdParty…` forms) | ✅ | ≤17 | adapted (`isim/swift/overlays/Foundation/AppTransportSecurity.swift`), iOS 10+'s rules: URLSession refuses cleartext `http://` and `ws://` loads (every redirect hop) with `NSURLErrorAppTransportSecurityRequiresSecureConnection` (-1022) and logs iOS's console message; WKWebView fails such a navigation provisionally with the same error. IP-address literals are exempt; unqualified names and `.local` need `NSAllowsLocalNetworking`; any of the InWebContent / ForMedia / LocalNetworking keys makes `NSAllowsArbitraryLoads` ignored; the most specific exception domain wins. HTTPS needs TLS 1.2+ with forward-secrecy (ECDHE) suites (libcurl's minimum version and cipher list); a refused handshake is `secureConnectionFailed` (-1200). Custom `URLProtocol`s and Network framework are not subject to it, as on iOS. Not yet: subresources inside a web page, AVFoundation's media loads (`NSAllowsArbitraryLoadsForMedia` is parsed only), `NSRequiresCertificateTransparency` (parsed, not checked). Tested (HelloTransportSecurity, tests/ui/test_transport_security.py) |
| `UIDesignRequiresCompatibility` (opt out of Liquid Glass) | ❌ | 26.0 | ignored: the app still gets the iOS 26 design |
| `UIRequiresFullScreen` | ✅ | ≤17 | adapted: on iPad before iPadOS 26 the app opts out of multitasking (`supportsMultipleScenes` is false: one full-screen scene, no split view); iPadOS 26 ignores it (deprecated). Tested (HelloInfoPlist, tests/ui/test_info_plist.py, os_matrix) |
| `UIRequiredDeviceCapabilities` | ✅ | ≤17 | adapted: `isim install` and `isim run` refuse an app the simulated device cannot run (a list, or a dictionary with `false` for what the device must not have), against the hardware of the device it stands for (iPads: no telephony, SMS, GPS or NFC; the gaming tier from A17 Pro / M1; DriverKit on M-series iPads); an unknown capability is a warning. Tested (tests/ui/test_info_plist.py) |
| `UTExportedTypeDeclarations` / `UTImportedTypeDeclarations` | ❌ | ≤17 | ignored by `UTType` (see UniformTypeIdentifiers) |
| `CADisableMinimumFrameDurationOnPhone` | ❌ | ≤17 | ignored |
| iOS 26/27 keys (`LSSupportsGameMode`, `GCSupportedGameControllers`, BackgroundAssets `BA*`, `MusicHapticsSupported`, …) | ❌ | 26.0 | ignored |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
