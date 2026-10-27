# VisionKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 52.5% of Apple's iOS API (105 of 200, exact) · **Rows:** 2: 1 🧩 1 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [VisionKit](https://developer.apple.com/documentation/visionkit) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Adapted,** on the simulated camera (`ISIM_CAMERA`) and isim's Vision (zbar / zxing-cpp for codes, tesseract for text):
  the data scanner, Live Text and the document camera. Without a camera the scanner and the document camera are not
  supported, like the Simulator.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `DataScannerViewController` (`RecognizedDataType`, `TextContentType`, quality levels, `recognizedItems`, delegate, zoom, region of interest, `capturePhoto`), `RecognizedItem` | 🟡 | ≤17 | adapted: on the simulated camera (`ISIM_CAMERA`); a frame every 0.3 / 0.5 / 0.8 s (fast / balanced / accurate) through Vision's barcode (zbar / zxing-cpp) and text (tesseract) requests; text content types by isim's own patterns; items keep their identity across frames (added, updated when they move, removed after two analyses without them), bounds in the view's coordinates, one item near the center unless `recognizesMultipleItems`; highlighting draws a rounded white outline; a tap reports the item; pinch zooms the camera. No guidance labels. Without a camera `isSupported` is false and `startScanning` throws `.unsupported`, like the Simulator. Tested (HelloVisionKit: test_visionkit_camera, test_visionkit_without_camera) |
| `ImageAnalyzer`, `ImageAnalysis`, `ImageAnalysisInteraction` (Live Text) | 🟡 | ≤17 | adapted: the analyzer reads text (tesseract) and machine-readable codes in a `UIImage`, `CGImage`, `CVPixelBuffer`, `CIImage` or file; the interaction shows the Live Text button on the image's content rectangle, highlights the items (the image dimmed), and a tap on a highlighted line (or a long press) selects it (`selectedText`, `selectedRanges`, `textSelectionDidChange`); hit tests (`hasText(at:)`, `hasDataDetector(at:)`, …) follow the image view's content mode or the delegate's `contentsRect`. Not available: subject lifting (`subjects` is empty, `image(for:)` throws), Visual Look Up, the text edit menu. Tested (HelloVisionKit) |
| `VNDocumentCameraViewController`, `VNDocumentCameraScan` (Swift and Objective-C) | 🟡 | ≤17 | adapted: the camera preview with the page found by `VNDetectRectanglesRequest` on the live frames (a blue overlay), a shutter that adds the page perspective-corrected, Save (with the page count) and Cancel; manual capture only (no auto-capture, flash or filters). Objective-C: `<VisionKit/VisionKit.h>`, `-framework VisionKit`. Without a camera `isSupported` is false and the delegate gets an error when the controller appears. Tested (HelloVisionKit; HelloVisionObjC from Objective-C) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
95 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var maxZoomFactor: Double`](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/maxzoomfactor)
- [`var minZoomFactor: Double`](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/minzoomfactor)
- [`func dataScannerDidZoom(DataScannerViewController)`](https://developer.apple.com/documentation/visionkit/datascannerviewcontrollerdelegate/datascannerdidzoom(_:))
- [`func dataScannerDidZoom(DataScannerViewController)`](https://developer.apple.com/documentation/visionkit/datascannerviewcontrollerdelegate/datascannerdidzoom(_:)-5lq2p)
- [`ImageAnalysis`](https://developer.apple.com/documentation/visionkit/imageanalysis)
- [`func hasResults(for: ImageAnalyzer.AnalysisTypes) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysis/hasresults(for:))
- [`var transcript: String`](https://developer.apple.com/documentation/visionkit/imageanalysis/transcript)
- [`ImageAnalysisInteraction`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction)
- [`var activeInteractionTypes: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/activeinteractiontypes)
- [`var allowLongPressForDataDetectorsInTextMode: Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/allowlongpressfordatadetectorsintextmode)
- [`var analysis: ImageAnalysis?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/analysis)
- [`func analysisHasText(at: CGPoint) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/analysishastext(at:))
- [`var contentsRect: CGRect`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/contentsrect)
- [`var delegate: (any ImageAnalysisInteractionDelegate)?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/delegate)
- [`func didMove(to: UIView?)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/didmove(to:))
- [`var hasActiveTextSelection: Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/hasactivetextselection)
- [`func hasDataDetector(at: CGPoint) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/hasdatadetector(at:))
- [`func hasInteractiveItem(at: CGPoint) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/hasinteractiveitem(at:))
- [`func hasSupplementaryInterface(at: CGPoint) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/hassupplementaryinterface(at:))
- [`func hasText(at: CGPoint) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/hastext(at:))
- [`var highlightedSubjects: Set<ImageAnalysisInteraction.Subject>`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/highlightedsubjects)
- [`func image(for: Set<ImageAnalysisInteraction.Subject>) async throws -> UIImage`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/image(for:))
- [`init()`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/init())
- [`convenience init(any ImageAnalysisInteractionDelegate)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/init(_:))
- [`ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes)
- [`static let automatic: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/automatic)
- [`static let automaticTextOnly: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/automatictextonly)
- [`static let dataDetectors: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/datadetectors)
- [`static let imageSubject: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/imagesubject)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/init(rawvalue:))
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/init(rawvalue:))
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/init(rawvalue:))
- [`var rawValue: UInt`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/rawvalue)
- [`var rawValue: UInt`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/rawvalue)
- [`var rawValue: UInt`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/rawvalue)
- [`static let textSelection: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/textselection)
- [`static let visualLookUp: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/interactiontypes/visuallookup)
- [`var isSupplementaryInterfaceHidden: Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/issupplementaryinterfacehidden)
- [`var liveTextButtonVisible: Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/livetextbuttonvisible)
- [`var preferredInteractionTypes: ImageAnalysisInteraction.InteractionTypes`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/preferredinteractiontypes)
- [`func resetTextSelection()`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/resettextselection())
- [`var selectableItemsHighlighted: Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/selectableitemshighlighted)
- [`var selectedAttributedText: AttributedString`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/selectedattributedtext)
- [`var selectedRanges: [Range<String.Index>]`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/selectedranges)
- [`var selectedText: String`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/selectedtext)
- [`func setContentsRectNeedsUpdate()`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/setcontentsrectneedsupdate())
- [`func setSupplementaryInterfaceHidden(Bool, animated: Bool)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/setsupplementaryinterfacehidden(_:animated:))
- [`ImageAnalysisInteraction.Subject`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject)
- [`func subject(at: CGPoint) async -> ImageAnalysisInteraction.Subject?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject(at:))
- [`var bounds: CGRect`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject/bounds)
- [`func hash(into: inout Hasher)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject/hash(into:))
- [`var image: UIImage`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject/image)
- [`var subjects: Set<ImageAnalysisInteraction.Subject>`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subjects)
- [`ImageAnalysisInteraction.SubjectUnavailable`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subjectunavailable)
- [`case imageUnavailable`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subjectunavailable/imageunavailable)
- [`var supplementaryInterfaceContentInsets: UIEdgeInsets`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/supplementaryinterfacecontentinsets)
- [`var supplementaryInterfaceFont: UIFont?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/supplementaryinterfacefont)
- [`var text: String`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/text)
- [`var view: UIView?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/view)
- [`func willMove(to: UIView?)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/willmove(to:))
- [`ImageAnalysisInteractionDelegate`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate)
- [`func contentsRect(for: ImageAnalysisInteraction) -> CGRect`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/contentsrect(for:))
- [`func contentsRect(for: ImageAnalysisInteraction) -> CGRect`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/contentsrect(for:)-90dek)
- [`func contentView(for: ImageAnalysisInteraction) -> UIView?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/contentview(for:))
- [`func contentView(for: ImageAnalysisInteraction) -> UIView?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/contentview(for:)-28l6r)
- [`func interaction(ImageAnalysisInteraction, highlightSelectedItemsDidChange: Bool)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/interaction(_:highlightselecteditemsdidchange:))
- [`func interaction(ImageAnalysisInteraction, highlightSelectedItemsDidChange: Bool)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/interaction(_:highlightselecteditemsdidchange:)-qsjs)
- [`func interaction(ImageAnalysisInteraction, liveTextButtonDidChangeToVisible: Bool)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/interaction(_:livetextbuttondidchangetovisible:))
- [`func interaction(ImageAnalysisInteraction, liveTextButtonDidChangeToVisible: Bool)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/interaction(_:livetextbuttondidchangetovisible:)-51zmv)
- [`func interaction(ImageAnalysisInteraction, shouldBeginAt: CGPoint, for: ImageAnalysisInteraction.InteractionTypes) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/interaction(_:shouldbeginat:for:))
- [`func interaction(ImageAnalysisInteraction, shouldBeginAt: CGPoint, for: ImageAnalysisInteraction.InteractionTypes) -> Bool`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/interaction(_:shouldbeginat:for:)-9n9q4)
- [`func presentingViewController(for: ImageAnalysisInteraction) -> UIViewController?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/presentingviewcontroller(for:))
- [`func presentingViewController(for: ImageAnalysisInteraction) -> UIViewController?`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/presentingviewcontroller(for:)-3gzbq)
- [`func textSelectionDidChange(ImageAnalysisInteraction)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/textselectiondidchange(_:))
- [`func textSelectionDidChange(ImageAnalysisInteraction)`](https://developer.apple.com/documentation/visionkit/imageanalysisinteractiondelegate/textselectiondidchange(_:)-4xwp)
- [`RecognizedItem`](https://developer.apple.com/documentation/visionkit/recognizeditem)
- [`RecognizedItem.Barcode`](https://developer.apple.com/documentation/visionkit/recognizeditem/barcode)
- [`case barcode(RecognizedItem.Barcode)`](https://developer.apple.com/documentation/visionkit/recognizeditem/barcode(_:))
- [`var bounds: RecognizedItem.Bounds`](https://developer.apple.com/documentation/visionkit/recognizeditem/barcode/bounds)
- [`var id: UUID`](https://developer.apple.com/documentation/visionkit/recognizeditem/barcode/id)
- [`var observation: VNBarcodeObservation`](https://developer.apple.com/documentation/visionkit/recognizeditem/barcode/observation)
- [`var payloadStringValue: String?`](https://developer.apple.com/documentation/visionkit/recognizeditem/barcode/payloadstringvalue)
- [`var bounds: RecognizedItem.Bounds`](https://developer.apple.com/documentation/visionkit/recognizeditem/bounds-swift.property)
- [`RecognizedItem.Bounds`](https://developer.apple.com/documentation/visionkit/recognizeditem/bounds-swift.struct)
- [`var bottomLeft: CGPoint`](https://developer.apple.com/documentation/visionkit/recognizeditem/bounds-swift.struct/bottomleft)
- [`var bottomRight: CGPoint`](https://developer.apple.com/documentation/visionkit/recognizeditem/bounds-swift.struct/bottomright)
- [`var topLeft: CGPoint`](https://developer.apple.com/documentation/visionkit/recognizeditem/bounds-swift.struct/topleft)
- [`var topRight: CGPoint`](https://developer.apple.com/documentation/visionkit/recognizeditem/bounds-swift.struct/topright)
- [`var id: UUID`](https://developer.apple.com/documentation/visionkit/recognizeditem/id)
- [`RecognizedItem.Text`](https://developer.apple.com/documentation/visionkit/recognizeditem/text)
- [`case text(RecognizedItem.Text)`](https://developer.apple.com/documentation/visionkit/recognizeditem/text(_:))
- [`var bounds: RecognizedItem.Bounds`](https://developer.apple.com/documentation/visionkit/recognizeditem/text/bounds)
- [`var id: UUID`](https://developer.apple.com/documentation/visionkit/recognizeditem/text/id)
- [`var observation: VNRecognizedTextObservation`](https://developer.apple.com/documentation/visionkit/recognizeditem/text/observation)
- [`var transcript: String`](https://developer.apple.com/documentation/visionkit/recognizeditem/text/transcript)

</details>
<!-- /generated:missing -->
