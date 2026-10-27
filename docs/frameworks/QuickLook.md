# QuickLook

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 86.4% of Apple's iOS API (51 of 59, exact) · **Rows:** 8: 6 ✅ 1 ❌ 1 ⛔ · **iOS:** 4.0+
<!-- /generated:header -->

**Area:** [UIKit](../COVERAGE.md#uikit) · **Apple:** [Quick Look](https://developer.apple.com/documentation/quicklook) · **Issues:** [`area:uikit`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Auikit)

## How isim implements it

- **Adapted:** `QLPreviewController` (`isim/frameworks/QuickLook/QuickLook.m`) is a paging controller over UIKit: images, PDFs (poppler), HTML (WebKit), RTF, text, audio and video (ffmpeg); SwiftUI's `quickLookPreview` comes from isim's QuickLook Swift overlay (`isim/swift/overlays/QuickLook`). Quick Look Preview extensions (`isim/frameworks/QuickLook/QLPreviewExtensions.m`) are loaded into the previewing app (iOS runs them in a process of their own) and preview the types they declare. Rows: [UIKit](UIKit.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| SwiftUI `quickLookPreview(_:)`, `quickLookPreview(_:in:)` | ✅ | ≤17 | adapted: isim's QuickLook Swift overlay presents a `QLPreviewController` over the URL, or over the collection from the selected URL (swipes between them); Done clears the binding, setting it to nil dismisses the preview. Tested (HelloQuickLookSwiftUI, OS matrix) |
| `QLPreviewSceneActivationConfiguration`, `QLPreviewSceneOptions` | ✅ | ≤17 | `init(itemsAt:options:)` (Objective-C `initWithItemsAtURLs:options:`), `initialPreviewIndex`, `editingMode` (stored: no Markup). Activated by `UIWindowScene.ActivationAction` / `ActivationInteraction`, the preview opens at the initial index. Adapted: full screen over the app's window, not a window scene of its own. Tested (HelloQuickLookSwiftUI) |
| HTML and RTF previews | ✅ | ≤17 | adapted: HTML in a `WKWebView` (WebKit is loaded when one is previewed; the files next to it are readable); RTF as rich text (UIKit's RTF reader). Without the WebKit helper, HTML shows its source. Tested (HelloQuickLookSwiftUI) |
| Office documents: Word (`doc`, `docx`), Excel (`xls`, `xlsx`), PowerPoint (`ppt`, `pptx`), OpenDocument (`odt`, `ods`, `odp`) | ✅ | ≤17 | passthrough: the host's LibreOffice converts the document to PDF (`soffice --headless --convert-to pdf`, a private profile, off the main thread with a spinner; `host_office.c`), and its pages are shown like a PDF's. Without LibreOffice on the host, the file's generic page (name, kind, size). Tested (HelloQuickLook -office: test_quicklook_office; skipped without LibreOffice) |
| iWork documents (Pages, Numbers, Keynote) | ⛔ | ≤17 | blocked: Apple's iWork format is undocumented and LibreOffice imports it only partly; isim shows the file's generic page |
| Quick Look Preview extensions: `QLPreviewingController` (`preparePreviewOfFile(at:completionHandler:)`, `preparePreviewOfSearchableItem(identifier:queryString:completionHandler:)`, `providePreview(for:completionHandler:)` and its async form), `QLPreviewProvider`, `QLFilePreviewRequest` | ✅ | ≤17 | adapted: `QLPreviewController` finds the `com.apple.quicklook.preview` extensions of the app (`PlugIns`) and, under the shell, of the installed apps, and uses the first whose `QLSupportedContentTypes` the file's type conforms to (the `UTType` class, else the apps' `UTExportedTypeDeclarations` / `UTImportedTypeDeclarations` by filename extension). The extension is loaded into the previewing app, like Share extensions (iOS: a process of its own). A view-based extension's view controller (`NSExtensionPrincipalClass` or `NSExtensionMainStoryboard`) is a child of the preview and fills the page once `preparePreviewOfFile(at:completionHandler:)` calls back (a spinner until then; an error shows the generic page); a `QLPreviewProvider`'s reply is shown by isim's previewers (below). Searchable items (Spotlight) are not previewed: isim has no Spotlight index. Objective-C headers: `QLPreviewingController.h`, `QLPreviewProvider.h`, `QLFilePreviewRequest.h`. Tested (HelloQuickLookExtensions: test_quicklook_extensions; QuickLookObjCTest) |
| `QLPreviewReply`, `QLPreviewReplyAttachment` | ✅ | ≤17 | adapted: the reply becomes a file that `QLPreviewController` shows: `init(dataOfContentType:contentSize:createDataUsing:)` writes the data with its type's filename extension (text converted to UTF-8 from `stringEncoding`; for HTML the `attachments` are written next to it and `cid:KEY` references rewritten to them), `init(forPDFWithPageSize:createDocumentUsing:)` the `PDFDocument`'s data, `init(contextSize:isBitmap:drawUsing:)` a PNG drawn in a bitmap context at the screen's scale (origin at the bottom left; vector contexts are drawn as bitmaps too), `init(fileURL:)` that file. `title` names the item (unless the data source's item has its own title); `contentSize` is not used (the page fits the content). Objective-C: the `UTType` initializers; Swift: the overlay's `UTType`, `PDFDocument` and `String.Encoding` forms. Tested (test_quicklook_extensions, QuickLookObjCTest) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `ARQuickLookPreviewItem` (with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
8 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`ARQuickLookPreviewItem`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem)
- [`var allowsContentScaling: Bool`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/allowscontentscaling)
- [`var canonicalWebPageURL: URL?`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/canonicalwebpageurl)
- [`init(fileAt: URL)`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/init(fileat:))
- [`init(fileAtURL: URL)`](https://developer.apple.com/documentation/quicklook/arquicklookpreviewitem/init(fileaturl:))
- [`QLPreviewSceneActivationConfiguration.Options`](https://developer.apple.com/documentation/quicklook/qlpreviewsceneactivationconfiguration/options)
- [`var initialPreviewIndex: Int`](https://developer.apple.com/documentation/quicklook/qlpreviewsceneactivationconfiguration/options/initialpreviewindex)
- [`var initialPreviewIndex: Int`](https://developer.apple.com/documentation/quicklook/qlpreviewsceneactivationconfiguration/options/initialpreviewindex)

</details>
<!-- /generated:missing -->
