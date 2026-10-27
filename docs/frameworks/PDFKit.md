# PDFKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 44.9% of Apple's iOS API (279 of 621, exact) · **Rows:** 17: 10 ✅ 5 🟡 2 ❌ · **iOS:** 11.0+
<!-- /generated:header -->

**Area:** [Graphics & text](../COVERAGE.md#graphics) · **Apple:** [PDFKit](https://developer.apple.com/documentation/pdfkit) · **Issues:** [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

## How isim implements it

- **Approach:** adapted. isim's own Objective-C implementation (`isim/frameworks/PDFKit`) is built on Core Graphics' PDF
  object model ([CoreGraphics](CoreGraphics.md): isim's parser reads the pages, boxes, outline, labels, info and
  encryption). poppler-glib renders the pages through `CGContextDrawPDFPage` and extracts their text. A document is an
  array of pages; each page draws from the document it came from, from an image, or nothing (a blank page).
- **Selections and find (issue #358):** a `PDFSelection` is a set of character indexes per page, over each page's
  text and character rectangles (poppler's); lines are the text between line breaks, words runs of letters and digits.
  Finding searches each page's string (`NSString` compare options); `beginFindString` searches one page per turn of the
  main queue, posting the find notifications and calling the delegate.
- **Annotations (issue #358):** read from each page's `/Annots` when first needed (widgets inherit their field's
  attributes), with their dictionary's values as properties (`annotationKeyValues`); made, changed and removed. Like
  Apple's, `CGContextDrawPDFPage` draws pages without their annotations; PDFKit draws them from their properties
  (highlights, underlines and strike-outs over their quadrilaterals, ink, squares, circles, lines with their endings,
  notes, free text, stamps, form fields with their values), not from their appearance streams. Writing adds each
  annotation's dictionary to the written page (Core Graphics rewrites cairo's file with them), or draws them into the
  pages with `PDFDocumentBurnInAnnotationsOption`.
- **Writing:** every page is redrawn into a `CGPDFContext` (cairo's PDF surface), so vector content stays vector. A rotated
  page is written turned, with rotation 0, and its crop box becomes the media box. The outline (with page destinations)
  and the title, author, subject, creator and keywords are written too, and every annotation (links included).
- **Views:** `PDFView` is a `UIScrollView` of page views that isim lays out at the scale factor; every page view redraws
  at its size, so pages stay sharp at every zoom. The behaviour follows iOS: continuous single pages, fitted to the width
  with `autoScales`, white pages with shadows on a gray background, pinch to zoom, a double tap to zoom in or back to
  fit, a tap on an annotation that performs its action (a link followed, a check box or radio button toggled,
  `.PDFViewAnnotationHit` posted) and a long press that selects a word. The current selection is drawn in blue and the
  highlighted selections in yellow (or their color); the find interaction searches the document. `PDFThumbnailView` is a strip of page thumbnails that outlines the current
  page and goes to a page when its thumbnail is tapped. Every interaction is a script command: `tap`, `tapid
  pdfthumbnail-N`, `pinch` and `drag` (docs/SCRIPTING.md); page views have the ids `pdfpage-N`.
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/PDFKit`; Swift imports them.
- **Versus Apple's Simulator:** documents read, edit and write the same way. Differences: the written file is a new
  PDF rather than an incremental save of the original, and it is never encrypted; annotations are drawn from their
  properties rather than their appearance streams, and their appearance streams are not written; text fields are not
  edited in place.

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
| `PDFOutline` (`init()`, `document`, `parent`, `numberOfChildren`, `index`, `child(at:)`, `insertChild(_:at:)`, `removeFromParent()`, `label`, `isOpen`, `destination`, `action`) | 🟡 | ≤17 | adapted: read from `/Outlines` (destinations explicit, named in `/Dests` or the `/Names` tree, or behind a GoTo action), edited, written back; the action read from `/A` (issue #358); tested (PDFKitTest, HelloPDF). Missing: written items keep only their destination's page (not their action) |
| `PDFDestination` (`init(page:at:)`, `page`, `point`, `zoom`, `compare(_:)`, `kPDFDestinationUnspecifiedValue`) | ✅ | ≤17 | adapted: XYZ, Fit, FitH/V/B and FitR destinations; unspecified coordinates and zoom are `kPDFDestinationUnspecifiedValue`; `compare` orders by page, then top to bottom, then left to right; tested (PDFKitTest) |
| `PDFSelection` (`init(document:)`, `pages`, `string`, `attributedString`, `color`, `bounds(for:)`, `numberOfTextRanges(on:)`, `range(at:on:)`, `selectionsByLine()`, `add(_:)`, `extend(atEnd:)`, `extend(atStart:)`, `extendForLineBoundaries()`, `draw(for:active:)`, `draw(for:with:active:)`), `PDFSelectionGranularity` | ✅ | ≤17 | adapted: character indexes per page over the page's text (poppler); disjoint ranges and pages joined by line breaks in `string`; `attributedString` is plain; drawing fills the characters' rectangles (the active selection in blue). Tested (PDFKitTest: test_pdfkit) |
| `PDFPage` selections and annotations (`selection(for:)` a range or a rect, `selection(from:to:)`, `selectionForWord(at:)`, `selectionForLine(at:)`, `annotations`, `addAnnotation(_:)`, `removeAnnotation(_:)`, `annotation(at:)`) | ✅ | ≤17 | adapted: a point selects the character under it, else the nearest one; a rect selects the characters whose centers it holds; annotations read from `/Annots` when first needed (the delegate's `classForAnnotationType(_:)`); drawing draws them after the content when `displaysAnnotations` is set. Tested (PDFKitTest, HelloPDF) |
| `PDFDocument` find and selections (`findString(_:withOptions:)`, `findString(_:fromSelection:withOptions:)`, `beginFindString(_:withOptions:)`, `beginFindStrings(_:withOptions:)`, `cancelFindString()`, `isFinding`, the find notifications and `PDFDocumentFoundSelectionKey` / `PDFDocumentPageIndexKey`, the delegate's find methods and `didMatchString(_:)`, `selectionForEntireDocument`, `selection(from:at:to:at:)` (with `PDFSelectionGranularity`, iOS 18), `selection(from:atCharacterIndex:to:atCharacterIndex:)`, `outlineItem(for:)`) | ✅ | ≤17 | adapted: each page's string searched with `NSString`'s compare options; asynchronous finds run one page per turn of the main queue; `findString(_:fromSelection:)` does not wrap around; `outlineItem(for:)` is the last item whose destination is at or before the selection. Tested (PDFKitTest) |
| `PDFAnnotation` (`init(bounds:forType:withProperties:)`, `page`, `type`, `bounds`, `shouldDisplay`, `shouldPrint`, `userName`, `modificationDate`, `color`, `contents`, `popup`, `border`, `action`, `hasAppearanceStream`, `isHighlighted`, `draw(with:in:)`, `setValue(_:forAnnotationKey:)`, `setBoolean`, `setRect`, `annotationKeyValues`, `value(forAnnotationKey:)`, `removeValue(forAnnotationKey:)`, NSCoding), `PDFAnnotationKey`, `PDFAnnotationSubtype` | ✅ | ≤17 | adapted: the properties are the dictionary's values (colors as `UIColor`, the border as `PDFBorder`, actions as `PDFAction`); drawn from its properties, not its appearance stream; written as a dictionary of its properties (no appearance stream). NSCoding keeps the type, bounds, contents and labels. Tested (PDFKitTest, HelloPDF) |
| `PDFAnnotation` utilities (`font`, `fontColor`, `interiorColor`, `alignment`, `startPoint` / `endPoint`, `startLineStyle` / `endLineStyle`, `lineStyle(fromName:)`, `name(for:)`, `iconType`, `quadrilateralPoints`, `markupType`, `paths`, `add(_:)`, `remove(_:)`, `isOpen`, `destination`, `url`, `stampName`, `caption`, `backgroundColor`), `PDFLineStyle`, `PDFTextAnnotationIconType`, `PDFMarkupType`, `PDFAnnotationLineEndingStyle`, `PDFAnnotationTextIconType`, `PDFAnnotationHighlightingMode` | ✅ | ≤17 | adapted: the font and its color from `/DA`; points, quadrilaterals and paths relative to the bounds origin; markup drawn over the quadrilaterals (a highlight multiplied, an underline, a strike-out), ink with round caps, notes as a note icon, stamps as a framed name. Tested (PDFKitTest, HelloPDF) |
| Form fields (`widgetFieldType`, `widgetControlType`, `isMultiline`, `isPasswordField`, `hasComb`, `maximumLength`, `widgetStringValue`, `widgetDefaultStringValue`, `allowsToggleToOff`, `radiosInUnison`, `isReadOnly`, `isListChoice`, `choices`, `values`, `buttonWidgetState`, `buttonWidgetStateString`, `fieldName`, `isActivatableTextField`), `PDFAnnotationWidgetSubtype`, `PDFWidgetControlType`, `PDFWidgetCellState`, `PDFAppearanceCharacteristics`, `PDFAppearanceCharacteristicsKey` | 🟡 | ≤17 | adapted: a widget inherits `/FT`, `/T` (the full name), `/V`, `/Ff`, `/Opt`, `/DA` from its parent fields; drawn with its background, border and value (a check mark, a radio dot, a caption, the text); a tap in a PDFView toggles check boxes and radio buttons. Missing: text fields are not edited in place, choice fields have no picker. Tested (PDFKitTest) |
| `PDFBorder` (`style`, `lineWidth`, `dashPattern`, `borderKeyValues`, `draw(in:)`, NSCoding), `PDFBorderStyle`, `PDFBorderKey` | ✅ | ≤17 | adapted: read from `/BS` or `/Border`; written as both. Tested (PDFKitTest) |
| `PDFAction` (`type`), `PDFActionGoTo`, `PDFActionURL`, `PDFActionNamed` (`PDFActionNamedName`), `PDFActionRemoteGoTo`, `PDFActionResetForm` | ✅ | ≤17 | adapted: read from link annotations and outline items (`/A`: GoTo, URI, Named, GoToR, ResetForm), written with link annotations; `PDFView.perform(_:)` goes to destinations, opens URLs (the delegate first), performs the named actions, hands remote go-tos to `pdfViewOpenPDF(_:forRemoteGoToAction:)` and resets form fields. Tested (PDFKitTest) |
| Writing annotations (`dataRepresentation()`, `write(to:)`, `PDFDocumentBurnInAnnotationsOption`) | ✅ | 16.0 | adapted: each annotation's dictionary added to its written page (Core Graphics rewrites the file cairo made, adding the objects to the pages' `/Annots`); with the burn-in option they are drawn into the pages instead. Tested (PDFKitTest: written and read back, burnt in) |
| `PDFView` (`document`, `currentPage`, `currentDestination`, `visiblePages`, `go(to:)` a page / a destination, `go(to:on:)`, `goToFirstPage(_:)` / `goToLastPage(_:)` / `goToNextPage(_:)` / `goToPreviousPage(_:)`, `goBack(_:)` / `goForward(_:)` and their `canGo…`, `documentView`, `layoutDocumentView()`, `annotationsChanged(on:)`, `rowSize(for:)`) | ✅ | ≤17 | adapted: history of the places gone to; the current page is the most visible one; tested (PDFKitTest, HelloPDF) |
| `PDFView` display (`displayMode`, `displayDirection`, `displaysPageBreaks`, `pageBreakMargins`, `displayBox`, `displaysAsBook`, `displaysRTL`, `backgroundColor`, `pageShadowsEnabled`, `interpolationQuality`, `shouldAntiAlias`, `usePageViewController(_:withViewOptions:)`, `isUsingPageViewController`, `pageOverlayViewProvider`, `isInMarkupMode`) | ✅ | ≤17 | adapted: single page or continuous, one or two up, vertical or horizontal; a page view controller is a horizontally paged scroll view (no page curl); overlay views sit over their page views; markup mode turns off PDFView's own gestures; tested (PDFKitTest, HelloPDF) |
| `PDFView` scale (`scaleFactor`, `minScaleFactor`, `maxScaleFactor`, `autoScales`, `scaleFactorForSizeToFit`, `zoomIn(_:)`, `zoomOut(_:)`, `canZoomIn`, `canZoomOut`, pinch, double tap) | ✅ | ≤17 | adapted: zooming keeps the point under the fingers (or the center) in place; zoom steps are √2; tested (PDFKitTest, HelloPDF pinch and double tap) |
| `PDFView` points and links (`page(for:nearest:)`, `convert(_:to:)`, `convert(_:from:)` for points and rects, `areaOfInterest(for:)`, `areaOfInterest(forMouse:)`, `draw(_:to:)`, `drawPagePost(_:to:)`, `PDFViewDelegate`: `pdfViewWillClick(onLink:with:)`, `pdfViewWillChangeScaleFactor(_:toScale:)`, `pdfViewOpenPDF(_:forRemoteGoToAction:)`) | 🟡 | ≤17 | adapted: a tap on an annotation performs its action or goes to its destination (a URL through the delegate or `UIApplication.open`); areas of interest are page, text, annotation, link, control, text field, icon and popup; tested (PDFKitTest, HelloPDF). Missing: `enableDataDetectors`, `greekingThreshold`, `allowsDragging` and `acceptsDraggedFiles` are only stored; `setCursorFor(_:)` does nothing (no pointer cursors) |
| `PDFView` notifications (`.PDFViewDocumentChanged`, `.PDFViewChangedHistory`, `.PDFViewPageChanged`, `.PDFViewScaleChanged`, `.PDFViewDisplayModeChanged`, `.PDFViewDisplayBoxChanged`, `.PDFViewVisiblePagesChanged`, `.PDFViewSelectionChanged`, `.PDFViewAnnotationHit`, `.PDFViewAnnotationWillHit`, `.PDFViewCopyPermission`) | ✅ | ≤17 | posted, and `.PDFViewSelectionChanged`, `.PDFViewAnnotationWillHit` / `.PDFViewAnnotationHit` (`"PDFAnnotationHit"` in the user info) and `.PDFViewCopyPermission` (issue #358); the print permission notification is defined, never posted; tested (PDFKitTest, HelloPDF) |
| `PDFThumbnailView` (`pdfView`, `thumbnailSize`, `layoutMode`, `contentInset`, `backgroundColor`, `selectedPages`, `PDFThumbnailLayoutMode`) | 🟡 | ≤17 | adapted: thumbnails of the PDFView's document; the current page outlined; a tap goes to the page; tested (HelloPDF). Missing: `allowsDragging`, `allowsMultipleSelection` and `maximumNumberOfColumns` are only stored (one page selected, one row or column) |
| `PDFView` selection and find (`currentSelection`, `setCurrentSelection(_:animate:)`, `clearSelection()`, `selectAll(_:)`, `scrollSelectionToVisible(_:)`, `go(to:)` a selection, `highlightedSelections`, `isFindInteractionEnabled`, `findInteraction`, `perform(_:)`, `copy(_:)`) | ✅ | ≤17 | adapted: the current selection drawn in blue, highlighted selections in yellow (or their color); a long press selects a word; the find interaction's session searches the document (Match Case and the word options), highlights every match and steps through them. Tested (PDFKitTest, HelloPDF: Find) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
342 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`PDFAction`](https://developer.apple.com/documentation/pdfkit/pdfaction)
- [`var type: String`](https://developer.apple.com/documentation/pdfkit/pdfaction/type)
- [`PDFActionGoTo`](https://developer.apple.com/documentation/pdfkit/pdfactiongoto)
- [`var destination: PDFDestination`](https://developer.apple.com/documentation/pdfkit/pdfactiongoto/destination)
- [`init(destination: PDFDestination)`](https://developer.apple.com/documentation/pdfkit/pdfactiongoto/init(destination:))
- [`PDFActionNamed`](https://developer.apple.com/documentation/pdfkit/pdfactionnamed)
- [`init(name: PDFActionNamedName)`](https://developer.apple.com/documentation/pdfkit/pdfactionnamed/init(name:))
- [`var name: PDFActionNamedName`](https://developer.apple.com/documentation/pdfkit/pdfactionnamed/name)
- [`PDFActionNamedName`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname)
- [`case find`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/find)
- [`case firstPage`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/firstpage)
- [`case goBack`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/goback)
- [`case goForward`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/goforward)
- [`case goToPage`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/gotopage)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/init(rawvalue:))
- [`case lastPage`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/lastpage)
- [`case nextPage`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/nextpage)
- [`case none`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/none)
- [`case previousPage`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/previouspage)
- [`case print`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/print)
- [`case zoomIn`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/zoomin)
- [`case zoomOut`](https://developer.apple.com/documentation/pdfkit/pdfactionnamedname/zoomout)
- [`PDFActionRemoteGoTo`](https://developer.apple.com/documentation/pdfkit/pdfactionremotegoto)
- [`init(pageIndex: Int, at: CGPoint, fileURL: URL)`](https://developer.apple.com/documentation/pdfkit/pdfactionremotegoto/init(pageindex:at:fileurl:))
- [`init(pageIndex: Int, atPoint: CGPoint, fileURL: URL)`](https://developer.apple.com/documentation/pdfkit/pdfactionremotegoto/init(pageindex:atpoint:fileurl:))
- [`var pageIndex: Int`](https://developer.apple.com/documentation/pdfkit/pdfactionremotegoto/pageindex)
- [`var point: CGPoint`](https://developer.apple.com/documentation/pdfkit/pdfactionremotegoto/point)
- [`var url: URL`](https://developer.apple.com/documentation/pdfkit/pdfactionremotegoto/url)
- [`PDFActionResetForm`](https://developer.apple.com/documentation/pdfkit/pdfactionresetform)
- [`var fields: [String]?`](https://developer.apple.com/documentation/pdfkit/pdfactionresetform/fields)
- [`var fieldsIncludedAreCleared: Bool`](https://developer.apple.com/documentation/pdfkit/pdfactionresetform/fieldsincludedarecleared)
- [`init()`](https://developer.apple.com/documentation/pdfkit/pdfactionresetform/init())
- [`PDFActionURL`](https://developer.apple.com/documentation/pdfkit/pdfactionurl)
- [`init(URL: URL)`](https://developer.apple.com/documentation/pdfkit/pdfactionurl/init(url:)-1e0qw)
- [`init(url: URL)`](https://developer.apple.com/documentation/pdfkit/pdfactionurl/init(url:)-5wtb3)
- [`var url: URL?`](https://developer.apple.com/documentation/pdfkit/pdfactionurl/url)
- [`PDFAnnotation`](https://developer.apple.com/documentation/pdfkit/pdfannotation)
- [`var action: PDFAction?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/action)
- [`func add(UIBezierPath)`](https://developer.apple.com/documentation/pdfkit/pdfannotation/add(_:))
- [`var alignment: NSTextAlignment`](https://developer.apple.com/documentation/pdfkit/pdfannotation/alignment)
- [`var allowsToggleToOff: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/allowstoggletooff)
- [`var annotationKeyValues: [AnyHashable : Any]`](https://developer.apple.com/documentation/pdfkit/pdfannotation/annotationkeyvalues)
- [`var backgroundColor: UIColor?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/backgroundcolor)
- [`var border: PDFBorder?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/border)
- [`var bounds: CGRect`](https://developer.apple.com/documentation/pdfkit/pdfannotation/bounds)
- [`var buttonWidgetState: PDFWidgetCellState`](https://developer.apple.com/documentation/pdfkit/pdfannotation/buttonwidgetstate)
- [`var buttonWidgetStateString: String`](https://developer.apple.com/documentation/pdfkit/pdfannotation/buttonwidgetstatestring)
- [`var caption: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/caption)
- [`var choices: [String]?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/choices)
- [`var color: UIColor`](https://developer.apple.com/documentation/pdfkit/pdfannotation/color)
- [`var contents: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/contents)
- [`var destination: PDFDestination?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/destination)
- [`func draw(with: PDFDisplayBox, in: CGContext)`](https://developer.apple.com/documentation/pdfkit/pdfannotation/draw(with:in:))
- [`var endLineStyle: PDFLineStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotation/endlinestyle)
- [`var endPoint: CGPoint`](https://developer.apple.com/documentation/pdfkit/pdfannotation/endpoint)
- [`var fieldName: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/fieldname)
- [`var font: UIFont?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/font)
- [`var fontColor: UIColor?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/fontcolor)
- [`var hasAppearanceStream: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/hasappearancestream)
- [`var hasComb: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/hascomb)
- [`var iconType: PDFTextAnnotationIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotation/icontype)
- [`init(bounds: CGRect, forType: PDFAnnotationSubtype, withProperties: [AnyHashable : Any]?)`](https://developer.apple.com/documentation/pdfkit/pdfannotation/init(bounds:fortype:withproperties:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/pdfkit/pdfannotation/init(coder:))
- [`var interiorColor: UIColor?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/interiorcolor)
- [`var isActivatableTextField: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/isactivatabletextfield)
- [`var isHighlighted: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/ishighlighted)
- [`var isListChoice: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/islistchoice)
- [`var isMultiline: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/ismultiline)
- [`var isOpen: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/isopen)
- [`var isPasswordField: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/ispasswordfield)
- [`var isReadOnly: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/isreadonly)
- [`class func lineStyle(fromName: String) -> PDFLineStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotation/linestyle(fromname:))
- [`var markupType: PDFMarkupType`](https://developer.apple.com/documentation/pdfkit/pdfannotation/markuptype)
- [`var maximumLength: Int`](https://developer.apple.com/documentation/pdfkit/pdfannotation/maximumlength)
- [`var modificationDate: Date?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/modificationdate)
- [`class func name(for: PDFLineStyle) -> String`](https://developer.apple.com/documentation/pdfkit/pdfannotation/name(for:))
- [`var page: PDFPage?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/page)
- [`var paths: [UIBezierPath]?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/paths)
- [`var popup: PDFAnnotation?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/popup)
- [`var quadrilateralPoints: [NSValue]?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/quadrilateralpoints)
- [`var radiosInUnison: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/radiosinunison)
- [`func remove(UIBezierPath)`](https://developer.apple.com/documentation/pdfkit/pdfannotation/remove(_:))
- [`func removeValue(forAnnotationKey: PDFAnnotationKey)`](https://developer.apple.com/documentation/pdfkit/pdfannotation/removevalue(forannotationkey:))
- [`func setBoolean(Bool, forAnnotationKey: PDFAnnotationKey) -> Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/setboolean(_:forannotationkey:))
- [`func setRect(CGRect, forAnnotationKey: PDFAnnotationKey) -> Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/setrect(_:forannotationkey:))
- [`func setValue(Any, forAnnotationKey: PDFAnnotationKey) -> Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/setvalue(_:forannotationkey:))
- [`var shouldDisplay: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/shoulddisplay)
- [`var shouldPrint: Bool`](https://developer.apple.com/documentation/pdfkit/pdfannotation/shouldprint)
- [`var stampName: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/stampname)
- [`var startLineStyle: PDFLineStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotation/startlinestyle)
- [`var startPoint: CGPoint`](https://developer.apple.com/documentation/pdfkit/pdfannotation/startpoint)
- [`var type: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/type)
- [`var url: URL?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/url)
- [`var userName: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/username)
- [`func value(forAnnotationKey: PDFAnnotationKey) -> Any?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/value(forannotationkey:))
- [`var values: [String]?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/values)
- [`var widgetControlType: PDFWidgetControlType`](https://developer.apple.com/documentation/pdfkit/pdfannotation/widgetcontroltype)
- [`var widgetDefaultStringValue: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/widgetdefaultstringvalue)
- [`var widgetFieldType: PDFAnnotationWidgetSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotation/widgetfieldtype)
- [`var widgetStringValue: String?`](https://developer.apple.com/documentation/pdfkit/pdfannotation/widgetstringvalue)
- [`PDFAnnotationHighlightingMode`](https://developer.apple.com/documentation/pdfkit/pdfannotationhighlightingmode)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfannotationhighlightingmode/init(rawvalue:))
- [`static let invert: PDFAnnotationHighlightingMode`](https://developer.apple.com/documentation/pdfkit/pdfannotationhighlightingmode/invert)
- [`static let none: PDFAnnotationHighlightingMode`](https://developer.apple.com/documentation/pdfkit/pdfannotationhighlightingmode/none)
- [`static let outline: PDFAnnotationHighlightingMode`](https://developer.apple.com/documentation/pdfkit/pdfannotationhighlightingmode/outline)
- [`static let push: PDFAnnotationHighlightingMode`](https://developer.apple.com/documentation/pdfkit/pdfannotationhighlightingmode/push)
- [`PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey)
- [`static let action: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/action)
- [`static let additionalActions: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/additionalactions)
- [`static let appearanceDictionary: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/appearancedictionary)
- [`static let appearanceState: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/appearancestate)
- [`static let border: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/border)
- [`static let borderStyle: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/borderstyle)
- [`static let color: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/color)
- [`static let contents: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/contents)
- [`static let date: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/date)
- [`static let defaultAppearance: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/defaultappearance)
- [`static let destination: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/destination)
- [`static let flags: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/flags)
- [`static let highlightingMode: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/highlightingmode)
- [`static let iconName: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/iconname)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/init(rawvalue:))
- [`static let inklist: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/inklist)
- [`static let interiorColor: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/interiorcolor)
- [`static let lineEndingStyles: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/lineendingstyles)
- [`static let linePoints: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/linepoints)
- [`static let name: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/name)
- [`static let open: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/open)
- [`static let page: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/page)
- [`static let parent: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/parent)
- [`static let popup: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/popup)
- [`static let quadding: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/quadding)
- [`static let quadPoints: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/quadpoints)
- [`static let rect: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/rect)
- [`static let subtype: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/subtype)
- [`static let textLabel: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/textlabel)
- [`static let widgetAppearanceDictionary: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetappearancedictionary)
- [`static let widgetBackgroundColor: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetbackgroundcolor)
- [`static let widgetBorderColor: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetbordercolor)
- [`static let widgetCaption: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetcaption)
- [`static let widgetDefaultValue: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetdefaultvalue)
- [`static let widgetDownCaption: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetdowncaption)
- [`static let widgetFieldFlags: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetfieldflags)
- [`static let widgetFieldType: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetfieldtype)
- [`static let widgetMaxLen: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetmaxlen)
- [`static let widgetOptions: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetoptions)
- [`static let widgetRolloverCaption: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetrollovercaption)
- [`static let widgetRotation: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetrotation)
- [`static let widgetTextLabelUI: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgettextlabelui)
- [`static let widgetValue: PDFAnnotationKey`](https://developer.apple.com/documentation/pdfkit/pdfannotationkey/widgetvalue)
- [`PDFAnnotationLineEndingStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle)
- [`static let circle: PDFAnnotationLineEndingStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle/circle)
- [`static let closedArrow: PDFAnnotationLineEndingStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle/closedarrow)
- [`static let diamond: PDFAnnotationLineEndingStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle/diamond)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle/init(rawvalue:))
- [`static let none: PDFAnnotationLineEndingStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle/none)
- [`static let openArrow: PDFAnnotationLineEndingStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle/openarrow)
- [`static let square: PDFAnnotationLineEndingStyle`](https://developer.apple.com/documentation/pdfkit/pdfannotationlineendingstyle/square)
- [`PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype)
- [`static let circle: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/circle)
- [`static let freeText: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/freetext)
- [`static let highlight: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/highlight)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/init(rawvalue:))
- [`static let ink: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/ink)
- [`static let line: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/line)
- [`static let link: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/link)
- [`static let popup: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/popup)
- [`static let square: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/square)
- [`static let stamp: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/stamp)
- [`static let strikeOut: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/strikeout)
- [`static let text: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/text)
- [`static let underline: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/underline)
- [`static let widget: PDFAnnotationSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/widget)
- [`PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype)
- [`static let comment: PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/comment)
- [`static let help: PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/help)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/init(rawvalue:))
- [`static let insert: PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/insert)
- [`static let key: PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/key)
- [`static let newParagraph: PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/newparagraph)
- [`static let note: PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/note)
- [`static let paragraph: PDFAnnotationTextIconType`](https://developer.apple.com/documentation/pdfkit/pdfannotationtexticontype/paragraph)
- [`PDFAnnotationWidgetSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype)
- [`static let button: PDFAnnotationWidgetSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype/button)
- [`static let choice: PDFAnnotationWidgetSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype/choice)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype/init(rawvalue:))
- [`static let signature: PDFAnnotationWidgetSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype/signature)
- [`static let text: PDFAnnotationWidgetSubtype`](https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype/text)
- [`PDFAppearanceCharacteristics`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics)
- [`var appearanceCharacteristicsKeyValues: [AnyHashable : Any]`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/appearancecharacteristicskeyvalues)
- [`var backgroundColor: UIColor?`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/backgroundcolor)
- [`var borderColor: UIColor?`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/bordercolor)
- [`var caption: String?`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/caption)
- [`var controlType: PDFWidgetControlType`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/controltype)
- [`var downCaption: String?`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/downcaption)
- [`var rolloverCaption: String?`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/rollovercaption)
- [`var rotation: Int`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristics/rotation)
- [`PDFAppearanceCharacteristicsKey`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey)
- [`static let backgroundColor: PDFAppearanceCharacteristicsKey`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey/backgroundcolor)
- [`static let borderColor: PDFAppearanceCharacteristicsKey`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey/bordercolor)
- [`static let caption: PDFAppearanceCharacteristicsKey`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey/caption)
- [`static let downCaption: PDFAppearanceCharacteristicsKey`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey/downcaption)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey/init(rawvalue:))
- [`static let rolloverCaption: PDFAppearanceCharacteristicsKey`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey/rollovercaption)
- [`static let rotation: PDFAppearanceCharacteristicsKey`](https://developer.apple.com/documentation/pdfkit/pdfappearancecharacteristicskey/rotation)
- [`PDFBorder`](https://developer.apple.com/documentation/pdfkit/pdfborder)
- [`var borderKeyValues: [AnyHashable : Any]`](https://developer.apple.com/documentation/pdfkit/pdfborder/borderkeyvalues)
- [`var dashPattern: [Any]?`](https://developer.apple.com/documentation/pdfkit/pdfborder/dashpattern)
- [`func draw(in: CGRect)`](https://developer.apple.com/documentation/pdfkit/pdfborder/draw(in:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/pdfkit/pdfborder/init(coder:))
- [`var lineWidth: CGFloat`](https://developer.apple.com/documentation/pdfkit/pdfborder/linewidth)
- [`var style: PDFBorderStyle`](https://developer.apple.com/documentation/pdfkit/pdfborder/style)
- [`PDFBorderKey`](https://developer.apple.com/documentation/pdfkit/pdfborderkey)
- [`static let dashPattern: PDFBorderKey`](https://developer.apple.com/documentation/pdfkit/pdfborderkey/dashpattern)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/pdfkit/pdfborderkey/init(rawvalue:))
- [`static let lineWidth: PDFBorderKey`](https://developer.apple.com/documentation/pdfkit/pdfborderkey/linewidth)
- [`static let style: PDFBorderKey`](https://developer.apple.com/documentation/pdfkit/pdfborderkey/style)
- [`PDFBorderStyle`](https://developer.apple.com/documentation/pdfkit/pdfborderstyle)
- [`case beveled`](https://developer.apple.com/documentation/pdfkit/pdfborderstyle/beveled)
- [`case dashed`](https://developer.apple.com/documentation/pdfkit/pdfborderstyle/dashed)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/pdfkit/pdfborderstyle/init(rawvalue:))
- [`case inset`](https://developer.apple.com/documentation/pdfkit/pdfborderstyle/inset)
- [`case solid`](https://developer.apple.com/documentation/pdfkit/pdfborderstyle/solid)
- [`case underline`](https://developer.apple.com/documentation/pdfkit/pdfborderstyle/underline)
- [`func beginFindString(String, withOptions: NSString.CompareOptions)`](https://developer.apple.com/documentation/pdfkit/pdfdocument/beginfindstring(_:withoptions:))
- [`func beginFindStrings([String], withOptions: NSString.CompareOptions)`](https://developer.apple.com/documentation/pdfkit/pdfdocument/beginfindstrings(_:withoptions:))
- [`func cancelFindString()`](https://developer.apple.com/documentation/pdfkit/pdfdocument/cancelfindstring())
- [`func findString(String, fromSelection: PDFSelection?, withOptions: NSString.CompareOptions) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfdocument/findstring(_:fromselection:withoptions:))
- [`func findString(String, withOptions: NSString.CompareOptions) -> [PDFSelection]`](https://developer.apple.com/documentation/pdfkit/pdfdocument/findstring(_:withoptions:))
- [`var isFinding: Bool`](https://developer.apple.com/documentation/pdfkit/pdfdocument/isfinding)
- [`func outlineItem(for: PDFSelection) -> PDFOutline?`](https://developer.apple.com/documentation/pdfkit/pdfdocument/outlineitem(for:))
- [`func selection(from: PDFPage, at: CGPoint, to: PDFPage, at: CGPoint) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfdocument/selection(from:at:to:at:))
- [`func selection(from: PDFPage, at: CGPoint, to: PDFPage, at: CGPoint, with: PDFSelectionGranularity) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfdocument/selection(from:at:to:at:with:))
- [`func selection(from: PDFPage, atCharacterIndex: Int, to: PDFPage, atCharacterIndex: Int) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfdocument/selection(from:atcharacterindex:to:atcharacterindex:))
- [`var selectionForEntireDocument: PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfdocument/selectionforentiredocument)
- [`func didMatchString(PDFSelection)`](https://developer.apple.com/documentation/pdfkit/pdfdocumentdelegate/didmatchstring(_:))
- [`let PDFDocumentFoundSelectionKey: String`](https://developer.apple.com/documentation/pdfkit/pdfdocumentfoundselectionkey)
- [`let PDFDocumentPageIndexKey: String`](https://developer.apple.com/documentation/pdfkit/pdfdocumentpageindexkey)
- [`PDFLineStyle`](https://developer.apple.com/documentation/pdfkit/pdflinestyle)
- [`PDFLineStyle`](https://developer.apple.com/documentation/pdfkit/pdflinestyle)
- [`case circle`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/circle)
- [`case circle`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/circle)
- [`case closedArrow`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/closedarrow)
- [`case closedArrow`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/closedarrow)
- [`case diamond`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/diamond)
- [`case diamond`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/diamond)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/init(rawvalue:))
- [`case none`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/none)
- [`case none`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/none)
- [`case openArrow`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/openarrow)
- [`case openArrow`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/openarrow)
- [`case square`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/square)
- [`case square`](https://developer.apple.com/documentation/pdfkit/pdflinestyle/square)
- [`PDFMarkupType`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype)
- [`PDFMarkupType`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype)
- [`case highlight`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/highlight)
- [`case highlight`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/highlight)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/init(rawvalue:))
- [`case redact`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/redact)
- [`case redact`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/redact)
- [`case strikeOut`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/strikeout)
- [`case strikeOut`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/strikeout)
- [`case underline`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/underline)
- [`case underline`](https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/underline)
- [`var action: PDFAction?`](https://developer.apple.com/documentation/pdfkit/pdfoutline/action)
- [`func addAnnotation(PDFAnnotation)`](https://developer.apple.com/documentation/pdfkit/pdfpage/addannotation(_:))
- [`func annotation(at: CGPoint) -> PDFAnnotation?`](https://developer.apple.com/documentation/pdfkit/pdfpage/annotation(at:))
- [`var annotations: [PDFAnnotation]`](https://developer.apple.com/documentation/pdfkit/pdfpage/annotations)
- [`func removeAnnotation(PDFAnnotation)`](https://developer.apple.com/documentation/pdfkit/pdfpage/removeannotation(_:))
- [`func selection(for: NSRange) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfpage/selection(for:)-20y9d)
- [`func selection(for: CGRect) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfpage/selection(for:)-2ckpi)
- [`func selection(from: CGPoint, to: CGPoint) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfpage/selection(from:to:))
- [`func selectionForLine(at: CGPoint) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfpage/selectionforline(at:))
- [`func selectionForWord(at: CGPoint) -> PDFSelection?`](https://developer.apple.com/documentation/pdfkit/pdfpage/selectionforword(at:))
- [`PDFSelection`](https://developer.apple.com/documentation/pdfkit/pdfselection)
- [`func add([PDFSelection])`](https://developer.apple.com/documentation/pdfkit/pdfselection/add(_:)-3fyld)
- [`func add(PDFSelection)`](https://developer.apple.com/documentation/pdfkit/pdfselection/add(_:)-8c2r)
- [`var attributedString: NSAttributedString?`](https://developer.apple.com/documentation/pdfkit/pdfselection/attributedstring)
- [`func bounds(for: PDFPage) -> CGRect`](https://developer.apple.com/documentation/pdfkit/pdfselection/bounds(for:))
- [`var color: UIColor?`](https://developer.apple.com/documentation/pdfkit/pdfselection/color)
- [`var color: UIColor?`](https://developer.apple.com/documentation/pdfkit/pdfselection/color)
- [`func draw(for: PDFPage, active: Bool)`](https://developer.apple.com/documentation/pdfkit/pdfselection/draw(for:active:))
- [`func draw(for: PDFPage, with: PDFDisplayBox, active: Bool)`](https://developer.apple.com/documentation/pdfkit/pdfselection/draw(for:with:active:))
- [`func extend(atEnd: Int)`](https://developer.apple.com/documentation/pdfkit/pdfselection/extend(atend:))
- [`func extend(atStart: Int)`](https://developer.apple.com/documentation/pdfkit/pdfselection/extend(atstart:))
- [`func extendForLineBoundaries()`](https://developer.apple.com/documentation/pdfkit/pdfselection/extendforlineboundaries())
- [`init(document: PDFDocument)`](https://developer.apple.com/documentation/pdfkit/pdfselection/init(document:))
- [`func numberOfTextRanges(on: PDFPage) -> Int`](https://developer.apple.com/documentation/pdfkit/pdfselection/numberoftextranges(on:))
- [`var pages: [PDFPage]`](https://developer.apple.com/documentation/pdfkit/pdfselection/pages)
- [`func range(at: Int, on: PDFPage) -> NSRange`](https://developer.apple.com/documentation/pdfkit/pdfselection/range(at:on:))
- [`func selectionsByLine() -> [PDFSelection]`](https://developer.apple.com/documentation/pdfkit/pdfselection/selectionsbyline())
- [`var string: String?`](https://developer.apple.com/documentation/pdfkit/pdfselection/string)
- [`PDFSelectionGranularity`](https://developer.apple.com/documentation/pdfkit/pdfselectiongranularity)
- [`case character`](https://developer.apple.com/documentation/pdfkit/pdfselectiongranularity/character)
- [`init?(rawValue: UInt)`](https://developer.apple.com/documentation/pdfkit/pdfselectiongranularity/init(rawvalue:))
- [`case line`](https://developer.apple.com/documentation/pdfkit/pdfselectiongranularity/line)
- [`case word`](https://developer.apple.com/documentation/pdfkit/pdfselectiongranularity/word)
- [`PDFTextAnnotationIconType`](https://developer.apple.com/documentation/pdfkit/pdftextannotationicontype)
- … and 42 more (`isim/data/api-coverage.json.gz`)

</details>
<!-- /generated:missing -->
