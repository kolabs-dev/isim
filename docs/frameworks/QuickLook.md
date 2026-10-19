# QuickLook

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 54.2% of Apple's iOS API (32 of 59, exact) · **Rows:** 4: 3 ✅ 1 ❌ · **iOS:** 4.0+
<!-- /generated:header -->

**Area:** [UIKit](../COVERAGE.md#uikit) · **Apple:** [Quick Look](https://developer.apple.com/documentation/quicklook) · **Issues:** [`area:uikit`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Auikit)

## How isim implements it

- **Adapted:** `QLPreviewController` (`isim/frameworks/QuickLook/QuickLook.m`) is a paging controller over UIKit: images, PDFs (poppler), HTML (WebKit), RTF, text, audio and video (ffmpeg); SwiftUI's `quickLookPreview` comes from isim's QuickLook Swift overlay (`isim/swift/overlays/QuickLook`). Preview extensions are not hosted yet. Rows: [UIKit](UIKit.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| SwiftUI `quickLookPreview(_:)`, `quickLookPreview(_:in:)` | ✅ | ≤17 | adapted: isim's QuickLook Swift overlay presents a `QLPreviewController` over the URL, or over the collection from the selected URL (swipes between them); Done clears the binding, setting it to nil dismisses the preview. Tested (HelloQuickLookSwiftUI, OS matrix) |
| `QLPreviewSceneActivationConfiguration`, `QLPreviewSceneOptions` | ✅ | ≤17 | `init(itemsAt:options:)` (Objective-C `initWithItemsAtURLs:options:`), `initialPreviewIndex`, `editingMode` (stored: no Markup). Activated by `UIWindowScene.ActivationAction` / `ActivationInteraction`, the preview opens at the initial index. Adapted: full screen over the app's window, not a window scene of its own. Tested (HelloQuickLookSwiftUI) |
| HTML and RTF previews | ✅ | ≤17 | adapted: HTML in a `WKWebView` (WebKit is loaded when one is previewed; the files next to it are readable); RTF as rich text (UIKit's RTF reader). Without the WebKit helper, HTML shows its source. Tested (HelloQuickLookSwiftUI) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `ARQuickLookPreviewItem`, `QLFilePreviewRequest`, `QLPreviewingController`, `QLPreviewProvider`, `QLPreviewReply`, `QLPreviewReplyAttachment` (6 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
27 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`ARQuickLookPreviewItem`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem)
- [`var allowsContentScaling: Bool`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/allowscontentscaling)
- [`var canonicalWebPageURL: URL?`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/canonicalwebpageurl)
- [`init(fileAt: URL)`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/init(fileat:))
- [`init(fileAtURL: URL)`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/init(fileaturl:))
- [`QLFilePreviewRequest`](https://developer.apple.com/documentation/quicklook/qlfilepreviewrequest)
- [`var fileURL: URL`](https://developer.apple.com/documentation/quicklook/qlfilepreviewrequest/fileurl)
- [`QLPreviewingController`](https://developer.apple.com/documentation/quicklook/qlpreviewingcontroller)
- [`func preparePreviewOfFile(at: URL, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/quicklook/qlpreviewingcontroller/preparepreviewoffile(at:completionhandler:))
- [`func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/quicklook/qlpreviewingcontroller/preparepreviewofsearchableitem(identifier:querystring:completionhandler:))
- [`func providePreview(for: QLFilePreviewRequest, completionHandler: (QLPreviewReply?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/quicklook/qlpreviewingcontroller/providepreview(for:completionhandler:))
- [`QLPreviewProvider`](https://developer.apple.com/documentation/quicklook/qlpreviewprovider)
- [`QLPreviewReply`](https://developer.apple.com/documentation/quicklook/qlpreviewreply)
- [`var attachments: [String : QLPreviewReplyAttachment]`](https://developer.apple.com/documentation/quicklook/qlpreviewreply/attachments)
- [`convenience init(contextSize: CGSize, isBitmap: Bool, drawUsing: (CGContext, QLPreviewReply) throws -> Void)`](https://developer.apple.com/documentation/quicklook/qlpreviewreply/init(contextsize:isbitmap:drawusing:))
- [`convenience init(dataOfContentType: UTType, contentSize: CGSize, createDataUsing: (QLPreviewReply) throws -> Data)`](https://developer.apple.com/documentation/quicklook/qlpreviewreply/init(dataofcontenttype:contentsize:createdatausing:))
- [`init(fileURL: URL)`](https://developer.apple.com/documentation/quicklook/qlpreviewreply/init(fileurl:))
- [`convenience init(forPDFWithPageSize: CGSize, createDocumentUsing: (QLPreviewReply) throws -> PDFDocument)`](https://developer.apple.com/documentation/quicklook/qlpreviewreply/init(forpdfwithpagesize:createdocumentusing:))
- [`var stringEncoding: String.Encoding`](https://developer.apple.com/documentation/quicklook/qlpreviewreply/stringencoding-8rrio)
- [`var title: String`](https://developer.apple.com/documentation/quicklook/qlpreviewreply/title)
- [`QLPreviewReplyAttachment`](https://developer.apple.com/documentation/quicklook/qlpreviewreplyattachment)
- [`var contentType: UTType`](https://developer.apple.com/documentation/quicklook/qlpreviewreplyattachment/contenttype)
- [`var data: Data`](https://developer.apple.com/documentation/quicklook/qlpreviewreplyattachment/data)
- [`init(data: Data, contentType: UTType)`](https://developer.apple.com/documentation/quicklook/qlpreviewreplyattachment/init(data:contenttype:))
- [`QLPreviewSceneActivationConfiguration.Options`](https://developer.apple.com/documentation/quicklook/qlpreviewsceneactivationconfiguration/options)
- [`var initialPreviewIndex: Int`](https://developer.apple.com/documentation/quicklook/qlpreviewsceneactivationconfiguration/options/initialpreviewindex)
- [`var initialPreviewIndex: Int`](https://developer.apple.com/documentation/quicklook/qlpreviewsceneactivationconfiguration/options/initialpreviewindex)

</details>
<!-- /generated:missing -->
