# SafariServices

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 79.8% of Apple's iOS API (79 of 99, exact) · **Rows:** 9: 6 ✅ 3 ❌ · **iOS:** 7.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [SafariServices](https://developer.apple.com/documentation/safariservices) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Adapted:** Safari-style chrome drawn on isim's `WKWebView`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| SafariServices (`SFSafariViewController`) | ✅ | ≤17 | iOS 17-style chrome (Done/Close/Cancel, domain + lock, “aA” button (cosmetic), back/forward/share/Open in Safari toolbar) on isim's WKWebView; delegate initial load / redirect / finish; tint colors; `DataStore.clearWebsiteData`. Adapted: its own in-memory website data (not Safari's), Reader and bar collapsing not real, Open in Safari logged. Tested (HelloSafari) |
| Objective-C interface (`SafariServices.framework`): `SFSafariViewController` (`initWithURL:configuration:`, delegate, tint colours, `dismissButtonStyle`), `SFSafariViewControllerConfiguration`, `SFSafariViewControllerDelegate`, `SSReadingList`, `SSReadingListErrorDomain`, `SFContentBlockerManager`, `SFContentBlockerState`, `SFErrorDomain` / `SFErrorCode` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names); the delegate's `safariViewController:initialLoadDidRedirectToURL:` (Apple's selector) is called too. Not from Objective-C: the activity-item delegate methods, `prewarmConnections`. Tested (HelloServicesObjC, tests/ui/test_services_objc.py) |
| Content blockers: `SFContentBlockerManager` (`reloadContentBlocker(withIdentifier:completionHandler:)`, `getStateOfContentBlocker(withIdentifier:completionHandler:)`, async forms), `SFContentBlockerState`, `SFError` / `SFError.Code`, `SFErrorDomain` | ✅ | ≤17 | adapted: a reload loads the app's `com.apple.Safari.content-blocker` extension into the app's process (like isim's share extensions), calls its `NSExtensionRequestHandling` principal and compiles the returned `blockerList.json` with WebKit into Safari's store on the device (`ISIM_DATA/Library/Safari/ContentBlockers`); isim's `SFSafariViewController` applies the enabled blockers. Settings > Apps > Safari > Extensions lists the installed blockers, but cannot switch them yet: a blocker is off by default, as on iOS, and `ISIM_CONTENTBLOCKER_PERMISSION=allow` turns them on; an unknown identifier fails with `SFError.noExtensionFound`. `SFError.Code` 1–3 have Apple's values; `internalError`, `maximumAttemptsExceeded` and `missingEntitlement` are 4–6 (proposed: Apple doesn't document them, and isim doesn't return them). Tested (HelloSafari Blocker extension, tests/ui/test_safari.py::test_safari_content_blocker; Objective-C in HelloServicesObjC) |
| `SFSafariViewController.ActivityButton` (`init(templateImage:extensionIdentifier:)`, `templateImage`, `extensionIdentifier`, `NSSecureCoding`), `SFSafariViewController.Configuration.activityButton` | ✅ | ≤17 | adapted: kept in the configuration; isim's Safari has no Safari extensions, so its share sheet shows no extension button. Objective-C: `SFSafariViewControllerActivityButton`. Tested (HelloSafari, HelloServicesObjC) |
| `SFAddToHomeScreenActivityItem` (`url`, `title`, `iconItemProvider`) | ✅ | 17.4 | adapted: an activity item conforming to it makes `UIActivityViewController` offer Add to Home Screen (`UIActivity.ActivityType.addToHomeScreen`): iOS's sheet with the icon (the item's `iconItemProvider` image, else a letter tile), an editable name and the URL; Add saves a web clip in the device data (`Library/WebClips/<UUID>.webclip`: `Info.plist` and `icon.png`), the home screen shows it, and tapping it opens the URL. Not yet: `getWebAppManifest` / `getHomeScreenWebAppInfo` and `SFAddToHomeScreenInfo` (they need BrowserEngineKit's `BEWebAppManifest`), a clip opening as a standalone web app. Tested (HelloSafari, tests/ui/test_safari_home.py::test_add_to_home_screen) |
| `SFSafariSettings` (`openExportBrowsingDataSettings(completionHandler:)`, `openExtensionsSettings(forIdentifiers:completionHandler:)` (26.2), `checkAutoFillUserNamesAndPasswordsEnabled(completionHandler:)`), `SFSafariSettingsError`, `SFSafariSettingsErrorDomain` | ✅ | 26.0 | adapted: opens isim's Settings at Apps > Safari > Export Browsing Data (what to export, Save to Files: logged, nothing written) or Extensions (the content blockers and web extensions of installed apps; requested identifiers no app has are listed as not installed); the AutoFill check reads Settings' Safari switch. `checkAutoFill…`'s iOS version is proposed (Apple's documentation gives none). Tested (HelloSafari, tests/ui/test_safari_home.py::test_safari_settings_and_social; Objective-C in HelloServicesObjC) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `SSReadingListError`, `SSReadingListError.Code` (2 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.2 | `SFAddToHomeScreenInfo` (needs BrowserEngineKit's `BEWebAppManifest`) |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `SFSafariExtensionManager`, `SFSafariExtensionState` (2 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
20 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func getHomeScreenWebAppInfo(completionHandler: (SFAddToHomeScreenInfo?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem/gethomescreenwebappinfo(completionhandler:))
- [`func getWebAppManifest(completionHandler: (BEWebAppManifest?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem/getwebappmanifest(completionhandler:))
- [`SFAddToHomeScreenInfo`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo)
- [`init(manifest: BEWebAppManifest)`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo/init(manifest:))
- [`var manifest: BEWebAppManifest`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo/manifest)
- [`var websiteCookies: [HTTPCookie]`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo/websitecookies)
- [`SFAuthenticationSession.CompletionHandler`](https://developer.apple.com/documentation/safariservices/sfauthenticationsession/completionhandler)
- [`let SFExtensionMessageKey: String`](https://developer.apple.com/documentation/safariservices/sfextensionmessagekey)
- [`let SFExtensionProfileKey: String`](https://developer.apple.com/documentation/safariservices/sfextensionprofilekey)
- [`SFSafariExtensionManager`](https://developer.apple.com/documentation/safariservices/sfsafariextensionmanager)
- [`class func getStateOfExtension(withIdentifier: String, completionHandler: (SFSafariExtensionState?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfsafariextensionmanager/getstateofextension(withidentifier:completionhandler:))
- [`SFSafariExtensionState`](https://developer.apple.com/documentation/safariservices/sfsafariextensionstate)
- [`var isEnabled: Bool`](https://developer.apple.com/documentation/safariservices/sfsafariextensionstate/isenabled)
- [`SSReadingListError`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror)
- [`SSReadingListError.Code`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code/init(rawvalue:))
- [`case urlSchemeNotAllowed`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code/urlschemenotallowed)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/errordomain)
- [`static var urlSchemeNotAllowed: SSReadingListError.Code`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/urlschemenotallowed)
- [`let SSReadingListErrorDomain: String`](https://developer.apple.com/documentation/safariservices/ssreadinglisterrordomain)

</details>
<!-- /generated:missing -->
