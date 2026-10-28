# PencilKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 95.7% of Apple's iOS API (334 of 349, exact) · **Rows:** 13: 11 ✅ 2 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Graphics & text](../COVERAGE.md#graphics) · **Apple:** [PencilKit](https://developer.apple.com/documentation/pencilkit) · **Issues:** [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

## How isim implements it

- **Approach:** isim's own engine (`isim/frameworks/PencilKit`), drawn with Core Graphics:
  - `PKModel.m`: points, paths, inks, strokes, drawings and tools. A path is a Catmull-Rom curve through its control
    points: parametric value *i* is control point *i*; the location between them follows the curve, the other values
    are linear. Distances come from an arc-length table.
  - `PKRender.m`: draws each ink. The looks are isim's approximations of Apple's inks:
    - pen and monoline: solid;
    - marker: wide, flat-capped and half opaque;
    - pencil and crayon: translucent, with a grain;
    - watercolor: soft-edged;
    - fountain pen and reed: a flat nib, whose width follows the direction of travel.
  - `PKCanvasView.m`: the canvas. It draws with touches from the simulated Apple Pencil (the `pencil` script command)
    or a finger, under the drawing policy. It erases whole strokes (vector) or parts of them (bitmap), and selects with
    the lasso.
  - `PKToolPicker.m`: the tool palette, docked at the bottom of the window. Accessibility identifiers:
    `PKToolPicker.<item identifier>` for the items and `PKToolPicker.color` for the color.
- **Drawing data:** `PKDrawing.dataRepresentation()` is **isim's own format**, a binary property list of the strokes.
  It is not compatible with the data of an Apple device: isim reads only drawings it wrote, and refuses other data with
  an error.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/PencilKit`.
  - The model classes are `PKDrawingReference`, `PKStrokeReference` and so on. They bridge to the Swift value types
    in `isim/swift/overlays/PencilKit`.
  - `PKTool`, `PKFloatRange`, `PKInkType` and `PKEraserType` are refined for Swift, as in Apple's SDK.
- **Versus Apple's Simulator:**
  - The tool picker is a plain palette at the bottom of the window. There is no floating or compact palette, no
    width or opacity popovers, and no color wheel; its color button cycles through five colors.
  - The ruler toggles `isRulerActive`, but isim draws no ruler.
  - Strokes are drawn as isim's approximations of the inks, not Apple's textures.
  - There is no handwriting recognition (`PKStrokeRecognizer`).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `PKCanvasView` (`drawing`, `tool`, `delegate`, `drawingPolicy`, `allowsFingerDrawing`, `isRulerActive`, `drawingGestureRecognizer`, `isDrawingEnabled`, `maximumSupportedContentVersion`, `selection`) | ✅ | ≤17 | adapted (`isDrawingEnabled` iOS 18, `selection` iOS 26): draws with the Pencil and fingers (two fingers scroll); inking adds strokes, the vector eraser removes strokes, the bitmap eraser cuts them, the lasso selects; `PKCanvasViewDelegate` (drawing changed, began / ended using a tool, selection); tested (HelloPencilKit, test_pencilkit) |
| `PKDrawing` (`init(strokes:)`, `init(data:)`, `dataRepresentation()`, `strokes`, `bounds`, `image(from:scale:)`, `transform(using:)` / `transformed(using:)`, `append(_:)` / `appending(_:)`, `requiredContentVersion`, `erasePath` / `erasingPath`, `draw(in:frame:from:darkUserInterfaceStyle:)`) | ✅ | ≤17 | adapted (erasing and `draw(in:…)` iOS 26): isim's own data format (see above); `PKDrawingReference` with `NSSecureCoding` from Objective-C; tested (PencilKitTest, HelloPencilKit; test_pencilkit) |
| `PKStroke` (`ink`, `path`, `transform`, `mask`, `renderBounds`, `maskedPathRanges`, `randomSeed`, `requiredContentVersion`, `id`, `renderGroupID`, `renderState`, `substroke(range:)`), `PKStroke.RenderState` | ✅ | ≤17 | adapted (`id`, render groups and states, substrokes iOS 26); tested (PencilKitTest, test_pencilkit) |
| `PKStrokePath` (a collection of `PKStrokePoint`, `interpolatedPoints(in:by:)`, `interpolatedLocation(at:)`, `interpolatedPoint(at:)`, `parametricValue(_:offsetBy:)`, `subscript(ClosedRange)`, `init(bezierPath:creationDate:pointProvider:)`, `bezierRepresentation`, `id`), `PKStrokePath.ConvertedBezierPoint` | ✅ | ≤17 | adapted (Bézier forms and `id` iOS 26): a Catmull-Rom curve through the control points; tested (PencilKitTest, HelloPencilKit; test_pencilkit) |
| `PKStrokePoint` (location, time, size, opacity, force, azimuth, altitude, `secondaryScale`, `threshold`, `lateralJitter`) | ✅ | ≤17 | adapted (`threshold` iOS 18, `lateralJitter` iOS 26); tested (PencilKitTest) |
| `PKInk`, `PKInkingTool` (`InkType`: pen, pencil, marker, monoline, fountain pen, watercolor, crayon, reed; widths, `azimuth`, `convertColor(_:from:to:)`) | ✅ | ≤17 | adapted (the reed iOS 26): the inks are isim's approximations (see above); widths are clamped to each ink's range; tested (PencilKitTest, HelloPencilKit; test_pencilkit) |
| `PKEraserTool` (vector, bitmap, fixed-width bitmap; widths), `PKLassoTool`, `PKTool` | ✅ | ≤17 | adapted; tested (PencilKitTest, test_pencilkit) |
| `PKContentVersion` | ✅ | ≤17 | adapted: what each ink and render state needs |
| `PKToolPicker` (`init()`, `init(toolItems:)`, observers, `setVisible(_:forFirstResponder:)`, `isVisible`, `frameObscured(in:)`, `selectedTool`, `selectedToolItem`, `selectedToolItemIdentifier`, `isRulerActive`, `colorUserInterfaceStyle`, `overrideUserInterfaceStyle`, `showsDrawingPolicyControls`, `stateAutosaveName`, `accessoryItem`, `maximumSupportedContentVersion`, `defaultToolItems`, `shared(for:)`) | ✅ | ≤17 | adapted (items iOS 18, `defaultToolItems` iOS 26): a palette at the bottom of the window while its first responder is first responder (see above); `PKToolPickerObserver`; tested (HelloPencilKit, test_pencilkit) |
| `PKToolPickerItem` and its inking, eraser, lasso, ruler, Scribble and custom items (`PKToolPickerCustomItem.Configuration`) | ✅ | 18.0 | adapted: buttons on the palette; custom items show their image provider's image; tested (PencilKitTest, test_pencilkit) |
| `PKAppleDrawingTypeIdentifier` | ✅ | ≤17 | adapted: `com.apple.drawing` (the data is still isim's format) |
| `PKStrokeRecognizer` | ❌ | 26.0 | not yet: handwriting recognition |
| `PKToolPicker.Delegate` / `delegate` | ❌ | 26.0 | not yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
15 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`PKStrokeRecognizer`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer)
- [`var drawing: PKDrawing`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/drawing)
- [`var indexableContent: String?`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/indexablecontent)
- [`init(preferredLanguages: [Locale.Language]?)`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/init(preferredlanguages:))
- [`var languages: [Locale.Language]`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/languages)
- [`static var recognitionVersion: Int`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/recognitionversion)
- [`func recognizedText(strokeIDs: Set<UUID>?) async -> String?`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/recognizedtext(strokeids:))
- [`func search(String, fullWordsOnly: Bool, caseMatchingOnly: Bool) async -> [PKStrokeRecognizer.SearchResult]`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/search(_:fullwordsonly:casematchingonly:))
- [`PKStrokeRecognizer.SearchResult`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/searchresult)
- [`let bounds: CGRect`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/searchresult/bounds)
- [`let strokes: Set<UUID>`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/searchresult/strokes)
- [`static var supportedLanguages: Set<Locale.Language>`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/supportedlanguages)
- [`func updateDrawing(PKDrawing) async`](https://developer.apple.com/documentation/pencilkit/pkstrokerecognizer/updatedrawing(_:))
- [`convenience init(PKStroke.RenderState)`](https://developer.apple.com/documentation/pencilkit/pkstrokerenderstatereference/init(_:))
- [`var delegate: (any PKToolPicker.Delegate)?`](https://developer.apple.com/documentation/pencilkit/pktoolpicker/delegate-swift.property)

</details>
<!-- /generated:missing -->
