# SafariServices

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 34.8% of Apple's iOS API (39 of 112, exact) · **Rows:** 100% (1: 1 ✅) · **iOS:** 7.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [SafariServices](https://developer.apple.com/documentation/safariservices) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Adapted:** Safari-style chrome drawn on isim's `WKWebView`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| SafariServices (`SFSafariViewController`) | ✅ | ≤17 | iOS 17-style chrome (Done/Close/Cancel, domain + lock, “aA” button (cosmetic), back/forward/share/Open in Safari toolbar) on isim's WKWebView; delegate initial load / redirect / finish; tint colors; `DataStore.clearWebsiteData`. Adapted: its own in-memory website data (not Safari's), Reader and bar collapsing not real, Open in Safari logged. Tested (HelloSafari) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `SFAddToHomeScreenActivityItem`, `SFContentBlockerManager`, `SFContentBlockerState`, `SFError`, `SFError.Code`, `SSReadingListError`, `SSReadingListError.Code` (7 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `SFSafariExtensionManager`, `SFSafariExtensionState`, `SFSafariSettings` (3 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
73 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`SFAddToHomeScreenActivityItem`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem)
- [`func getHomeScreenWebAppInfo(completionHandler: (SFAddToHomeScreenInfo?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem/gethomescreenwebappinfo(completionhandler:))
- [`func getWebAppManifest(completionHandler: (BEWebAppManifest?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem/getwebappmanifest(completionhandler:))
- [`var iconItemProvider: NSItemProvider?`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem/iconitemprovider)
- [`var title: String`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem/title)
- [`var url: URL`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreenactivityitem/url)
- [`SFAddToHomeScreenInfo`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo)
- [`init(manifest: BEWebAppManifest)`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo/init(manifest:))
- [`var manifest: BEWebAppManifest`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo/manifest)
- [`var websiteCookies: [HTTPCookie]`](https://developer.apple.com/documentation/safariservices/sfaddtohomescreeninfo/websitecookies)
- [`SFAuthenticationSession.CompletionHandler`](https://developer.apple.com/documentation/safariservices/sfauthenticationsession/completionhandler)
- [`SFAuthenticationSession.CompletionHandler`](https://developer.apple.com/documentation/safariservices/sfauthenticationsession/completionhandler)
- [`SFContentBlockerManager`](https://developer.apple.com/documentation/safariservices/sfcontentblockermanager)
- [`class func getStateOfContentBlocker(withIdentifier: String, completionHandler: (SFContentBlockerState?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfcontentblockermanager/getstateofcontentblocker(withidentifier:completionhandler:))
- [`class func reloadContentBlocker(withIdentifier: String, completionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/safariservices/sfcontentblockermanager/reloadcontentblocker(withidentifier:completionhandler:))
- [`SFContentBlockerState`](https://developer.apple.com/documentation/safariservices/sfcontentblockerstate)
- [`var isEnabled: Bool`](https://developer.apple.com/documentation/safariservices/sfcontentblockerstate/isenabled)
- [`SFError`](https://developer.apple.com/documentation/safariservices/sferror)
- [`SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/code)
- [`SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/code)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/safariservices/sferror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/safariservices/sferror/code/init(rawvalue:))
- [`case internalError`](https://developer.apple.com/documentation/safariservices/sferror/code/internalerror)
- [`case internalError`](https://developer.apple.com/documentation/safariservices/sferror/code/internalerror)
- [`case loadingInterrupted`](https://developer.apple.com/documentation/safariservices/sferror/code/loadinginterrupted)
- [`case loadingInterrupted`](https://developer.apple.com/documentation/safariservices/sferror/code/loadinginterrupted)
- [`case maximumAttemptsExceeded`](https://developer.apple.com/documentation/safariservices/sferror/code/maximumattemptsexceeded)
- [`case maximumAttemptsExceeded`](https://developer.apple.com/documentation/safariservices/sferror/code/maximumattemptsexceeded)
- [`case missingEntitlement`](https://developer.apple.com/documentation/safariservices/sferror/code/missingentitlement)
- [`case missingEntitlement`](https://developer.apple.com/documentation/safariservices/sferror/code/missingentitlement)
- [`case noAttachmentFound`](https://developer.apple.com/documentation/safariservices/sferror/code/noattachmentfound)
- [`case noAttachmentFound`](https://developer.apple.com/documentation/safariservices/sferror/code/noattachmentfound)
- [`case noExtensionFound`](https://developer.apple.com/documentation/safariservices/sferror/code/noextensionfound)
- [`case noExtensionFound`](https://developer.apple.com/documentation/safariservices/sferror/code/noextensionfound)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/safariservices/sferror/errordomain)
- [`static var internalError: SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/internalerror)
- [`static var loadingInterrupted: SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/loadinginterrupted)
- [`static var maximumAttemptsExceeded: SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/maximumattemptsexceeded)
- [`static var missingEntitlement: SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/missingentitlement)
- [`static var noAttachmentFound: SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/noattachmentfound)
- [`static var noExtensionFound: SFError.Code`](https://developer.apple.com/documentation/safariservices/sferror/noextensionfound)
- [`let SFErrorDomain: String`](https://developer.apple.com/documentation/safariservices/sferrordomain)
- [`let SFErrorDomain: String`](https://developer.apple.com/documentation/safariservices/sferrordomain)
- [`let SFExtensionMessageKey: String`](https://developer.apple.com/documentation/safariservices/sfextensionmessagekey)
- [`let SFExtensionProfileKey: String`](https://developer.apple.com/documentation/safariservices/sfextensionprofilekey)
- [`let SFExtensionProfileKey: String`](https://developer.apple.com/documentation/safariservices/sfextensionprofilekey)
- [`SFSafariExtensionManager`](https://developer.apple.com/documentation/safariservices/sfsafariextensionmanager)
- [`SFSafariExtensionManager`](https://developer.apple.com/documentation/safariservices/sfsafariextensionmanager)
- [`class func getStateOfExtension(withIdentifier: String, completionHandler: (SFSafariExtensionState?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfsafariextensionmanager/getstateofextension(withidentifier:completionhandler:))
- [`class func getStateOfExtension(withIdentifier: String, completionHandler: (SFSafariExtensionState?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/safariservices/sfsafariextensionmanager/getstateofextension(withidentifier:completionhandler:))
- [`SFSafariExtensionState`](https://developer.apple.com/documentation/safariservices/sfsafariextensionstate)
- [`SFSafariExtensionState`](https://developer.apple.com/documentation/safariservices/sfsafariextensionstate)
- [`var isEnabled: Bool`](https://developer.apple.com/documentation/safariservices/sfsafariextensionstate/isenabled)
- [`var isEnabled: Bool`](https://developer.apple.com/documentation/safariservices/sfsafariextensionstate/isenabled)
- [`SFSafariSettings`](https://developer.apple.com/documentation/safariservices/sfsafarisettings)
- [`class func openExportBrowsingDataSettings(completionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/safariservices/sfsafarisettings/openexportbrowsingdatasettings(completionhandler:))
- [`class func openExtensionsSettings(forIdentifiers: [String], completionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/safariservices/sfsafarisettings/openextensionssettings(foridentifiers:completionhandler:))
- [`SFSafariViewController.ActivityButton`](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/activitybutton)
- [`var extensionIdentifier: String?`](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/activitybutton/extensionidentifier)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/activitybutton/init(coder:))
- [`init(templateImage: UIImage, extensionIdentifier: String)`](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/activitybutton/init(templateimage:extensionidentifier:))
- [`var templateImage: UIImage?`](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/activitybutton/templateimage)
- [`SSReadingListError`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror)
- [`SSReadingListError.Code`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code)
- [`SSReadingListError.Code`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code/init(rawvalue:))
- [`case urlSchemeNotAllowed`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code/urlschemenotallowed)
- [`case urlSchemeNotAllowed`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/code/urlschemenotallowed)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/errordomain)
- [`static var urlSchemeNotAllowed: SSReadingListError.Code`](https://developer.apple.com/documentation/safariservices/ssreadinglisterror/urlschemenotallowed)
- [`let SSReadingListErrorDomain: String`](https://developer.apple.com/documentation/safariservices/ssreadinglisterrordomain)
- [`let SSReadingListErrorDomain: String`](https://developer.apple.com/documentation/safariservices/ssreadinglisterrordomain)

</details>
<!-- /generated:missing -->
