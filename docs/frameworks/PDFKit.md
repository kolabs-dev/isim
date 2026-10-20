# PDFKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Graphics & text](../COVERAGE.md#graphics) · **Apple:** [PDFKit](https://developer.apple.com/documentation/pdfkit) · **Issues:** [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

## How isim implements it

- **Approach:** adapted. isim's own Objective-C implementation (`isim/frameworks/PDFKit`) is built on Core Graphics' PDF
  object model ([CoreGraphics](CoreGraphics.md): isim's parser reads the pages, boxes, outline, labels, info and
  encryption). poppler-glib renders the pages through `CGContextDrawPDFPage` and extracts their text. A document is an
  array of pages; each page draws from the document it came from, from an image, or nothing (a blank page).
- **Writing:** every page is redrawn into a `CGPDFContext` (cairo's PDF surface), so vector content stays vector. A rotated
  page is written turned, with rotation 0, and its crop box becomes the media box. The outline (with page destinations)
  and the title, author, subject, creator and keywords are written too; the pages' link annotations are not.
- **Views:** `PDFView` is a `UIScrollView` of page views that isim lays out at the scale factor; every page view redraws
  at its size, so pages stay sharp at every zoom. The behaviour follows iOS: continuous single pages, fitted to the width
  with `autoScales`, white pages with shadows on a gray background, pinch to zoom, a double tap to zoom in or back to
  fit, and a tap on a link that follows it. `PDFThumbnailView` is a strip of page thumbnails that outlines the current
  page and goes to a page when its thumbnail is tapped. Every interaction is a script command: `tap`, `tapid
  pdfthumbnail-N`, `pinch` and `drag` (docs/SCRIPTING.md); page views have the ids `pdfpage-N`.
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/PDFKit`; Swift imports them.
- **Versus Apple's Simulator:** documents read, edit and write the same way. Two differences: the written file is a new
  PDF rather than an incremental save of the original, and it is never encrypted.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `PDFDocument` (`init()`, `init(url:)`, `init(data:)`, `documentURL`, `documentRef`, `majorVersion` / `minorVersion`, `pageCount`, `page(at:)`, `index(for:)`, `insert(_:at:)`, `removePage(at:)`, `exchangePage(at:withPageAt:)`, `pageClass`, `string`, `delegate` with `classForPage`) | ✅ | ≤17 | adapted: pages made when first needed, with the delegate's page class; `string` joins the pages' text with newlines; tested (PDFKitTest, HelloPDF) |
| `PDFDocument` encryption (`isEncrypted`, `isLocked`, `unlock(withPassword:)`, `permissionsStatus`, `accessPermissions`, `allowsPrinting`, `allowsCopying`, `allowsDocumentChanges`, `allowsDocumentAssembly`, `allowsContentAccessibility`, `allowsCommenting`, `allowsFormFieldEntry`, `.PDFDocumentDidUnlock`, `documentDidUnlock(_:)`) | ✅ | ≤17 | adapted: RC4, AES-128 and AES-256 with user and owner passwords, from Core Graphics' standard security handler; an empty user password unlocks by itself; tested (PDFKitTest) |
| `PDFDocument.documentAttributes` (`PDFDocumentAttribute`) | ✅ | ≤17 | adapted: title, author, subject, creator, producer and keywords (an array) as strings; creation and modification dates as `Date`; tested (PDFKitTest, HelloPDF) |
| `PDFDocument` writing (`dataRepresentation()`, `dataRepresentation(options:)`, `write(to:)`, `write(to:withOptions:)`, `write(toFile:)`, `write(toFile:withOptions:)`, `.PDFDocumentDidBeginWrite` / `.PDFDocumentDidEndWrite`) | 🟡 | ≤17 | adapted: the pages redrawn into a new PDF with the outline and the attributes; tested (PDFKitTest, HelloPDF). Missing: the `PDFDocumentWriteOption` keys (passwords, access permissions, burn-in, OCR text, JPEG images) are accepted but ignored, so the file is written unencrypted; producer and dates are cairo's own; link annotations are not written |
| `PDFPage` (`init()`, `init(image:)`, `init(image:options:)`, `document`, `pageRef`, `label`, `bounds(for:)`, `setBounds(_:for:)`, `rotation`, `displaysAnnotations`, `dataRepresentation`, `PDFDisplayBox`, `PDFPageImageInitializationOption`) | ✅ | ≤17 | adapted: a blank page is US Letter; an image page is aspect-fitted into its media box (upscaled only with the option; compression quality ignored); bleed, trim and art boxes default to the crop box; labels from `/PageLabels` (decimal, roman, letters, prefixes, starts), otherwise the page number; tested (PDFKitTest, HelloPDF) |
| `PDFPage` drawing (`draw(with:to:)`, `transform(_:for:)`, `transform(for:)`, `thumbnail(of:for:)`) | ✅ | ≤17 | adapted: the box's origin moved to 0 and turned by the rotation; thumbnails on white, fitted to the size; tested (PDFKitTest pixels, HelloPDF) |
| `PDFPage` text (`string`, `attributedString`, `numberOfCharacters`, `characterBounds(at:)`, `characterIndex(at:)`) | 🟡 | ≤17 | adapted: poppler's text and per-character rectangles, mapped to page space on rotated pages; tested (PDFKitTest, HelloPDF). Missing: `attributedString` carries no fonts or colours |
| `PDFOutline` (`init()`, `document`, `parent`, `numberOfChildren`, `index`, `child(at:)`, `insertChild(_:at:)`, `removeFromParent()`, `label`, `isOpen`, `destination`) | 🟡 | ≤17 | adapted: read from `/Outlines` (destinations explicit, named in `/Dests` or the `/Names` tree, or behind a GoTo action), edited, written back; tested (PDFKitTest, HelloPDF). Missing: `action` (PDFAction, issue #358); written items keep only their destination's page |
| `PDFDestination` (`init(page:at:)`, `page`, `point`, `zoom`, `compare(_:)`, `kPDFDestinationUnspecifiedValue`) | ✅ | ≤17 | adapted: XYZ, Fit, FitH/V/B and FitR destinations; unspecified coordinates and zoom are `kPDFDestinationUnspecifiedValue`; `compare` orders by page, then top to bottom, then left to right; tested (PDFKitTest) |
| `PDFAction`, `PDFAnnotation`, `PDFSelection`, find (`findString`, the find notifications), `PDFPage.annotations` | ❌ | ≤17 | not implemented: issue #358 |
| `PDFView` (`document`, `currentPage`, `currentDestination`, `visiblePages`, `go(to:)` a page / a destination, `go(to:on:)`, `goToFirstPage(_:)` / `goToLastPage(_:)` / `goToNextPage(_:)` / `goToPreviousPage(_:)`, `goBack(_:)` / `goForward(_:)` and their `canGo…`, `documentView`, `layoutDocumentView()`, `annotationsChanged(on:)`, `rowSize(for:)`) | ✅ | ≤17 | adapted: history of the places gone to; the current page is the most visible one; tested (PDFKitTest, HelloPDF) |
| `PDFView` display (`displayMode`, `displayDirection`, `displaysPageBreaks`, `pageBreakMargins`, `displayBox`, `displaysAsBook`, `displaysRTL`, `backgroundColor`, `pageShadowsEnabled`, `interpolationQuality`, `shouldAntiAlias`, `usePageViewController(_:withViewOptions:)`, `isUsingPageViewController`, `pageOverlayViewProvider`, `isInMarkupMode`) | ✅ | ≤17 | adapted: single page or continuous, one or two up, vertical or horizontal; a page view controller is a horizontally paged scroll view (no page curl); overlay views sit over their page views; markup mode turns off PDFView's own gestures; tested (PDFKitTest, HelloPDF) |
| `PDFView` scale (`scaleFactor`, `minScaleFactor`, `maxScaleFactor`, `autoScales`, `scaleFactorForSizeToFit`, `zoomIn(_:)`, `zoomOut(_:)`, `canZoomIn`, `canZoomOut`, pinch, double tap) | ✅ | ≤17 | adapted: zooming keeps the point under the fingers (or the center) in place; zoom steps are √2; tested (PDFKitTest, HelloPDF pinch and double tap) |
| `PDFView` points and links (`page(for:nearest:)`, `convert(_:to:)`, `convert(_:from:)` for points and rects, `areaOfInterest(for:)`, `areaOfInterest(forMouse:)`, `draw(_:to:)`, `drawPagePost(_:to:)`, `PDFViewDelegate`: `pdfViewWillClick(onLink:with:)`, `pdfViewWillChangeScaleFactor(_:toScale:)`) | 🟡 | ≤17 | adapted: link annotations (URI actions, GoTo actions and destinations) are followed on a tap, a URL through the delegate or `UIApplication.open`; areas of interest are page, text and link; tested (PDFKitTest, HelloPDF). Missing: `enableDataDetectors`, `greekingThreshold`, `allowsDragging` and `acceptsDraggedFiles` are only stored; `setCursorFor(_:)` does nothing (no pointer cursors) |
| `PDFView` notifications (`.PDFViewDocumentChanged`, `.PDFViewChangedHistory`, `.PDFViewPageChanged`, `.PDFViewScaleChanged`, `.PDFViewDisplayModeChanged`, `.PDFViewDisplayBoxChanged`, `.PDFViewVisiblePagesChanged`) | ✅ | ≤17 | posted; the annotation, selection and permission notifications are defined, never posted (issue #358); tested (PDFKitTest, HelloPDF) |
| `PDFThumbnailView` (`pdfView`, `thumbnailSize`, `layoutMode`, `contentInset`, `backgroundColor`, `selectedPages`, `PDFThumbnailLayoutMode`) | 🟡 | ≤17 | adapted: thumbnails of the PDFView's document; the current page outlined; a tap goes to the page; tested (HelloPDF). Missing: `allowsDragging`, `allowsMultipleSelection` and `maximumNumberOfColumns` are only stored (one page selected, one row or column) |
| `PDFView` selection and find (`currentSelection`, `go(to:)` a selection, `highlightedSelections`, `isFindInteractionEnabled`, `findInteraction`, `perform(_:)`) | ❌ | ≤17 | not implemented: issue #358 |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
