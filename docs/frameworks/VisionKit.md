# VisionKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (200 of 200, exact) · **Rows:** 3: 3 🟡 · **iOS:** 13.0+
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
Nothing (or not measured yet).
<!-- /generated:missing -->
