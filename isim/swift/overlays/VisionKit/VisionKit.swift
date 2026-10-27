// isim VisionKit (self-authored, iOS API names; issue #379): DataScannerViewController, ImageAnalyzer / ImageAnalysis /
// ImageAnalysisInteraction (Live Text), VNDocumentCameraViewController.
// Adapted, on the simulated camera (ISIM_CAMERA) and isim's Vision:
// - recognition is Vision's: VNDetectBarcodesRequest (the host's zbar / zxing-cpp) and VNRecognizeTextRequest (the host's
//   tesseract). Text content types (URLs, phone numbers, …) are found by isim's own patterns in the recognized lines.
// - the scanner shows the camera (AVCaptureVideoPreviewLayer, aspect fill) and analyzes a frame every 0.3 s (fast) /
//   0.5 s (balanced) / 0.8 s (accurate). Items keep their identity across frames: added, updated (moved), and removed
//   after two analyses without them. Bounds are in the scanner view's coordinates. Highlighting draws a rounded outline
//   around each item, and a tap on an item reports it. Pinch zooms the camera. No guidance labels.
// - Live Text: ImageAnalyzer reads text and codes in an image. ImageAnalysisInteraction shows the Live Text button and
//   highlights the items. A tap on a highlighted line (or a long press) selects it. Subject lifting is not available
//   (subjects is empty).
// - the document camera finds the page with VNDetectRectanglesRequest on the live frames (a blue overlay), and the shutter
//   adds the page, perspective-corrected. Capture is manual (no auto-capture).
// Without a camera (ISIM_CAMERA unset), the scanner and the document camera are not supported, like the iOS Simulator.
import UIKit
import Vision
import AVFoundation
import CoreImage

// MARK: - recognition (shared by the scanner and Live Text)

enum _VKText {
    /// isim's patterns for DataScannerViewController.TextContentType
    static let patterns: [DataScannerViewController.TextContentType: String] = [
        .URL: #"(?i)\b(?:https?://|www\.)[^\s]+|\b[a-z0-9-]+\.(?:com|org|net|io|dev|app|edu|gov)\b[^\s]*"#,
        .emailAddress: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
        .telephoneNumber: #"\+?\(?\d[\d\s().-]{6,}\d"#,
        .flightNumber: #"\b[A-Z][A-Z0-9]\s?\d{1,4}\b"#,
        .shipmentTrackingNumber: #"\b1Z[0-9A-Z]{16}\b|\b\d{12,22}\b"#,
        .currency: #"[$€£¥]\s?\d[\d,]*(?:\.\d{2})?|\b\d[\d,]*(?:\.\d{2})?\s?(?:USD|EUR|GBP|JPY)\b"#,
        .dateTimeDuration: #"(?i)\b\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?\b|\b\d{1,2}:\d{2}(?:\s?[ap]m)?\b|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s\d{1,2}\b|\b\d+\s?(?:min|minutes|hours|hrs|days)\b"#,
        .fullStreetAddress: #"(?i)\b\d{1,5}\s+(?:[A-Za-z]+\s){1,4}(?:street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|way|court|ct)\b\.?"#,
    ]
    static func matches(_ type: DataScannerViewController.TextContentType, in s: String) -> [Range<String.Index>] {
        guard let p = patterns[type], let re = try? NSRegularExpression(pattern: p) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { Range($0.range, in: s) }
    }
    static func anyDataDetector(in s: String) -> Bool {
        patterns.keys.contains { !matches($0, in: s).isEmpty }
    }
}

/// what one analysis found, in Vision's normalized image coordinates (origin bottom left)
struct _VKFound {
    var key: String
    var transcript: String          // text, or a code's payload
    var isText: Bool
    var quad: [CGPoint]             // topLeft, topRight, bottomRight, bottomLeft
    var text: VNRecognizedTextObservation?
    var code: VNBarcodeObservation?
}

enum _VKRecognizer {
    static var textAvailable: Bool { _textOK }
    static let _textOK: Bool = {
        ProcessInfo.processInfo.environment["PATH", default: "/usr/bin:/bin"].split(separator: ":").contains {
            FileManager.default.isExecutableFile(atPath: "\($0)/tesseract")
        }
    }()
    static var textLanguages: [String] { textAvailable ? ((try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? ["en-US"]) : [] }

    static func run(_ handler: VNImageRequestHandler, codes: [VNBarcodeSymbology]?, text: (languages: [String], type: DataScannerViewController.TextContentType?)?,
                    accurate: Bool) -> [_VKFound] {
        var out: [_VKFound] = []
        if let codes {
            let r = VNDetectBarcodesRequest()
            if !codes.isEmpty { r.symbologies = codes }
            if (try? handler.perform([r])) != nil {
                for case let o as VNBarcodeObservation in r.results ?? [] {
                    guard let p = o.payloadStringValue else { continue }
                    out.append(_VKFound(key: "b:" + p, transcript: p, isText: false, quad: [o.topLeft, o.topRight, o.bottomRight, o.bottomLeft], code: o))
                }
            }
        }
        if let text, textAvailable {
            let r = VNRecognizeTextRequest()
            r.recognitionLevel = accurate ? .accurate : .fast
            if !text.languages.isEmpty { r.recognitionLanguages = text.languages }
            if (try? handler.perform([r])) != nil {
                for case let o as VNRecognizedTextObservation in r.results ?? [] {
                    guard let cand = o.topCandidates(1).first else { continue }
                    let s = cand.string.trimmingCharacters(in: .whitespaces)
                    guard !s.isEmpty else { continue }
                    if let type = text.type {
                        for m in _VKText.matches(type, in: cand.string) {
                            let piece = String(cand.string[m])
                            let box = (try? cand.boundingBox(for: m))??.boundingBox ?? o.boundingBox
                            out.append(_VKFound(key: "t:" + piece, transcript: piece, isText: true, quad: _quad(box), text: o))
                        }
                    } else {
                        out.append(_VKFound(key: "t:" + s, transcript: s, isText: true, quad: [o.topLeft, o.topRight, o.bottomRight, o.bottomLeft], text: o))
                    }
                }
            }
        }
        return out
    }
    static func _quad(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.minY)]
    }
    static func cgImage(_ pb: CVPixelBuffer) -> CGImage? {
        let ci = CIImage(cvPixelBuffer: pb)
        return CIContext().createCGImage(ci, from: ci.extent)
    }
}

// MARK: - RecognizedItem

@frozen public enum RecognizedItem: Identifiable, Sendable {
    case text(RecognizedItem.Text)
    case barcode(RecognizedItem.Barcode)

    public struct Bounds: Sendable {
        public var topLeft: CGPoint
        public var topRight: CGPoint
        public var bottomRight: CGPoint
        public var bottomLeft: CGPoint
    }
    public struct Text: Identifiable, @unchecked Sendable {
        public var id: UUID
        public var transcript: String
        public var bounds: RecognizedItem.Bounds
        public var observation: VNRecognizedTextObservation
    }
    public struct Barcode: Identifiable, @unchecked Sendable {
        public var id: UUID
        public var payloadStringValue: String?
        public var bounds: RecognizedItem.Bounds
        public var observation: VNBarcodeObservation
    }
    public var id: UUID {
        switch self { case .text(let t): return t.id; case .barcode(let b): return b.id }
    }
    public var bounds: RecognizedItem.Bounds {
        switch self { case .text(let t): return t.bounds; case .barcode(let b): return b.bounds }
    }
}

extension RecognizedItem.Bounds {
    var _points: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }
    var _center: CGPoint { CGPoint(x: _points.map(\.x).reduce(0, +) / 4, y: _points.map(\.y).reduce(0, +) / 4) }
    func _contains(_ p: CGPoint) -> Bool {
        let path = UIBezierPath(); path.move(to: topLeft); path.addLine(to: topRight); path.addLine(to: bottomRight); path.addLine(to: bottomLeft); path.close()
        return path.contains(p)
    }
}

// MARK: - DataScannerViewController

@MainActor
open class DataScannerViewController: UIViewController {
    public struct RecognizedDataType: Hashable, Sendable {
        enum _Kind: Hashable, Sendable { case barcode([VNBarcodeSymbology]), text([String], TextContentType?) }
        let _kind: _Kind
        public static func barcode(symbologies: [VNBarcodeSymbology] = []) -> RecognizedDataType { RecognizedDataType(_kind: .barcode(symbologies)) }
        public static func text(languages: [String] = [], textContentType: TextContentType? = nil) -> RecognizedDataType {
            RecognizedDataType(_kind: .text(languages, textContentType))
        }
    }
    public enum TextContentType: Hashable, Sendable { case dateTimeDuration, emailAddress, flightNumber, fullStreetAddress, shipmentTrackingNumber, telephoneNumber, URL, currency }
    public enum QualityLevel: Hashable, Sendable { case balanced, fast, accurate }
    public enum ScanningUnavailable: Error, Hashable, Sendable { case unsupported, cameraRestricted }

    /// isim: true when the device has a camera (ISIM_CAMERA); false without one, like the Simulator
    public class var isSupported: Bool { AVCaptureDevice.default(for: .video) != nil }
    /// isim: supported, and camera access is not denied or restricted
    public class var isAvailable: Bool {
        let s = AVCaptureDevice.authorizationStatus(for: .video)
        return isSupported && s != .denied && s != .restricted
    }
    /// isim: tesseract's languages (empty without tesseract on the host)
    public class var supportedTextRecognitionLanguages: [String] { _VKRecognizer.textLanguages }

    public let recognizedDataTypes: Set<RecognizedDataType>
    public let qualityLevel: QualityLevel
    public let recognizesMultipleItems: Bool
    public let isHighFrameRateTrackingEnabled: Bool
    public let isPinchToZoomEnabled: Bool
    public let isGuidanceEnabled: Bool
    public let isHighlightingEnabled: Bool
    open weak var delegate: DataScannerViewControllerDelegate?
    /// the region items must be in (view coordinates); nil: the whole view
    open var regionOfInterest: CGRect?
    open private(set) var isScanning = false
    open var zoomFactor: Double = 1 {
        didSet {
            let z = Swift.max(minZoomFactor, Swift.min(maxZoomFactor, zoomFactor))
            if z != zoomFactor { zoomFactor = z; return }
            if let d = _device, (try? d.lockForConfiguration()) != nil { d.videoZoomFactor = CGFloat(z); d.unlockForConfiguration() }
            delegate?.dataScannerDidZoom(self)
        }
    }
    open var minZoomFactor: Double { Double(_device?.minAvailableVideoZoomFactor ?? 1) }
    open var maxZoomFactor: Double { Double(Swift.min(_device?.maxAvailableVideoZoomFactor ?? 1, 10)) }
    public let overlayContainerView = UIView()
    /// all the items after each change
    open var recognizedItems: AsyncStream<[RecognizedItem]> {
        let (stream, cont) = AsyncStream<[RecognizedItem]>.makeStream()
        let id = UUID()
        _streams[id] = cont
        cont.onTermination = { [weak self] _ in Task { @MainActor in self?._streams[id] = nil } }
        cont.yield(_items.map(\.item))
        return stream
    }

    var _device: AVCaptureDevice?
    var _session: AVCaptureSession?
    let _previewView = UIView()
    let _highlightView = _VKHighlightView()
    var _preview: AVCaptureVideoPreviewLayer?
    let _sink = _VKFrameSink()
    var _items: [(item: RecognizedItem, key: String, missed: Int)] = []
    var _streams: [UUID: AsyncStream<[RecognizedItem]>.Continuation] = [:]

    public init(recognizedDataTypes: Set<RecognizedDataType>, qualityLevel: QualityLevel = .balanced, recognizesMultipleItems: Bool = false,
                isHighFrameRateTrackingEnabled: Bool = true, isPinchToZoomEnabled: Bool = true, isGuidanceEnabled: Bool = true, isHighlightingEnabled: Bool = false) {
        self.recognizedDataTypes = recognizedDataTypes; self.qualityLevel = qualityLevel; self.recognizesMultipleItems = recognizesMultipleItems
        self.isHighFrameRateTrackingEnabled = isHighFrameRateTrackingEnabled; self.isPinchToZoomEnabled = isPinchToZoomEnabled
        self.isGuidanceEnabled = isGuidanceEnabled; self.isHighlightingEnabled = isHighlightingEnabled
        super.init(nibName: nil, bundle: nil)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    open override func loadView() {
        let v = UIView()
        v.backgroundColor = .black
        _previewView.backgroundColor = .black
        _highlightView.isUserInteractionEnabled = false
        _highlightView.backgroundColor = .clear
        overlayContainerView.backgroundColor = .clear
        v.addSubview(_previewView); v.addSubview(_highlightView); v.addSubview(overlayContainerView)
        v.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(_tapped(_:))))
        if isPinchToZoomEnabled { v.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(_pinched(_:)))) }
        view = v
    }
    open override func viewDidLoad() { super.viewDidLoad() }
    open override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    open override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated) }
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for v in [_previewView, _highlightView, overlayContainerView] { v.frame = view.bounds }
        _preview?.frame = _previewView.bounds
        _drawHighlights()
    }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopScanning()
        let s = _session
        DispatchQueue.global().async { s?.stopRunning() }
    }
    open override func removeFromParent() { stopScanning(); super.removeFromParent() }

    open func startScanning() throws {
        guard DataScannerViewController.isSupported else {
            NSLog("isim VisionKit: DataScannerViewController is not supported: the device has no camera (set ISIM_CAMERA)")
            throw ScanningUnavailable.unsupported
        }
        guard DataScannerViewController.isAvailable else { throw ScanningUnavailable.cameraRestricted }
        guard !isScanning else { return }
        isScanning = true
        _setUpSession()
        _sink.interval = qualityLevel == .fast ? 0.3 : qualityLevel == .accurate ? 0.8 : 0.5
        _sink.analyze = _analyzer()
        let s = _session
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { ok in
                Task { @MainActor [weak self] in
                    if ok { DispatchQueue.global().async { s?.startRunning() } }
                    else if let self { self.isScanning = false; self.delegate?.dataScanner(self, becameUnavailableWithError: .cameraRestricted) }
                }
            }
        } else if s?.isRunning != true {
            DispatchQueue.global().async { s?.startRunning() }
        }
    }
    open func stopScanning() {
        isScanning = false
        _sink.analyze = nil
    }
    /// the current frame as a photo
    open func capturePhoto() async throws -> UIImage {
        guard isScanning, let cg = _sink.lastFrame() else { throw ScanningUnavailable.unsupported }
        return UIImage(cgImage: cg)
    }

    func _setUpSession() {
        guard _session == nil, let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }
        let s = AVCaptureSession()
        s.beginConfiguration()
        if s.canAddInput(input) { s.addInput(input) }
        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.setSampleBufferDelegate(_sink, queue: _sink.queue)
        if s.canAddOutput(out) { s.addOutput(out) }
        s.commitConfiguration()
        let layer = AVCaptureVideoPreviewLayer(session: s)
        layer.videoGravity = .resizeAspectFill
        layer.frame = _previewView.bounds
        _previewView.layer.addSublayer(layer)
        _device = device; _session = s; _preview = layer
    }
    /// the analysis of one frame (on the sink's queue), whose results come back to the main actor
    func _analyzer() -> (CVPixelBuffer) -> Void {
        var codes: [VNBarcodeSymbology]?, text: (languages: [String], type: TextContentType?)?
        for t in recognizedDataTypes {
            switch t._kind {
            case .barcode(let s): codes = (codes ?? []) + s
            case .text(let l, let c): text = (l, c)
            }
        }
        let accurate = qualityLevel == .accurate
        return { [weak self] pb in
            let found = _VKRecognizer.run(VNImageRequestHandler(cvPixelBuffer: pb), codes: codes, text: text, accurate: accurate)
            DispatchQueue.main.async { MainActor.assumeIsolated { self?._apply(found) } }
        }
    }
    func _viewBounds(_ quad: [CGPoint]) -> RecognizedItem.Bounds {
        let p = quad.map { q -> CGPoint in
            let lp = _preview?.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: q.x, y: 1 - q.y)) ?? .zero
            return _previewView.convert(lp, to: view)
        }
        return RecognizedItem.Bounds(topLeft: p[0], topRight: p[1], bottomRight: p[2], bottomLeft: p[3])
    }
    func _apply(_ found: [_VKFound]) {
        guard isScanning, isViewLoaded else { return }
        var found = found.map { ($0, _viewBounds($0.quad)) }
        if let roi = regionOfInterest { found = found.filter { roi.contains($0.1._center) } }
        if !recognizesMultipleItems, !found.isEmpty {
            let c = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            func d(_ b: RecognizedItem.Bounds) -> CGFloat { hypot(b._center.x - c.x, b._center.y - c.y) }
            found = [found.min { d($0.1) < d($1.1) }!]
        }
        var added: [RecognizedItem] = [], updated: [RecognizedItem] = [], removed: [RecognizedItem] = []
        var next: [(item: RecognizedItem, key: String, missed: Int)] = []
        var seen = Set<String>()
        for (f, b) in found where !seen.contains(f.key) {
            seen.insert(f.key)
            let old = _items.first { $0.key == f.key }
            let id = old.map { $0.item.id } ?? UUID()
            let item: RecognizedItem = f.isText
                ? .text(RecognizedItem.Text(id: id, transcript: f.transcript, bounds: b, observation: f.text!))
                : .barcode(RecognizedItem.Barcode(id: id, payloadStringValue: f.transcript, bounds: b, observation: f.code!))
            next.append((item, f.key, 0))
            if let old {
                let moved = zip(old.item.bounds._points, b._points).contains { hypot($0.x - $1.x, $0.y - $1.y) > 2 }
                if moved { updated.append(item) }
            } else { added.append(item) }
        }
        for old in _items where !seen.contains(old.key) {
            if old.missed + 1 >= 2 { removed.append(old.item) } else { next.append((old.item, old.key, old.missed + 1)) }
        }
        _items = next
        let all = _items.map(\.item)
        if !added.isEmpty { delegate?.dataScanner(self, didAdd: added, allItems: all) }
        if !updated.isEmpty { delegate?.dataScanner(self, didUpdate: updated, allItems: all) }
        if !removed.isEmpty { delegate?.dataScanner(self, didRemove: removed, allItems: all) }
        if !added.isEmpty || !updated.isEmpty || !removed.isEmpty {
            for c in _streams.values { c.yield(all) }
            _drawHighlights()
        }
    }
    func _drawHighlights() {
        _highlightView.quads = isHighlightingEnabled ? _items.map(\.item.bounds._points) : []
        _highlightView.setNeedsDisplay()
    }
    @objc func _tapped(_ g: UITapGestureRecognizer) {
        let p = g.location(in: view)
        if let hit = _items.first(where: { $0.item.bounds._contains(p) }) { delegate?.dataScanner(self, didTapOn: hit.item) }
    }
    var _pinchStart = 1.0
    @objc func _pinched(_ g: UIPinchGestureRecognizer) {
        if g.state == .began { _pinchStart = zoomFactor }
        zoomFactor = _pinchStart * Double(g.scale)
    }
}

/// the scanner's highlights: a rounded outline around each item, lightly filled
final class _VKHighlightView: UIView {
    var quads: [[CGPoint]] = []
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        for q in quads {
            let path = UIBezierPath()
            path.move(to: q[0]); for p in q.dropFirst() { path.addLine(to: p) }; path.close()
            path.lineJoinStyle = .round
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor); ctx.addPath(path.cgPath); ctx.fillPath()
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 6, color: UIColor.black.withAlphaComponent(0.6).cgColor)   // visible on light pages too
            ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(3); ctx.setLineJoin(.round); ctx.addPath(path.cgPath); ctx.strokePath()
            ctx.restoreGState()
        }
    }
}

/// receives camera frames and analyzes one at a time, at most one per interval
final class _VKFrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "isim.visionkit.frames")
    let lock = NSLock()
    var _analyze: ((CVPixelBuffer) -> Void)?
    var interval = 0.5
    var _last = 0.0
    var _frame: CVPixelBuffer?
    var analyze: ((CVPixelBuffer) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _analyze }
        set { lock.lock(); _analyze = newValue; _last = 0; lock.unlock() }
    }
    var onFrame: ((CVPixelBuffer) -> Void)?
    func lastFrame() -> CGImage? {
        lock.lock(); let f = _frame; lock.unlock()
        return f.flatMap(_VKRecognizer.cgImage)
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = sampleBuffer.imageBuffer else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        _frame = pb
        let a = _analyze, due = now - _last >= interval
        if due { _last = now }
        let f = onFrame
        lock.unlock()
        f?(pb)
        if due, let a { a(pb) }       // on this serial queue: frames wait while one is analyzed
    }
}

@MainActor
public protocol DataScannerViewControllerDelegate: AnyObject {
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem])
    func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem])
    func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem])
    func dataScannerDidZoom(_ dataScanner: DataScannerViewController)
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem)
    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable)
}
extension DataScannerViewControllerDelegate {
    public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
    public func dataScannerDidZoom(_ dataScanner: DataScannerViewController) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {}
}

// MARK: - Live Text: ImageAnalyzer, ImageAnalysis

public final class ImageAnalyzer: @unchecked Sendable {
    public struct AnalysisTypes: OptionSet, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let text = AnalysisTypes(rawValue: 1), machineReadableCode = AnalysisTypes(rawValue: 2), visualLookUp = AnalysisTypes(rawValue: 4)
    }
    public struct Configuration: Sendable {
        public let analysisTypes: AnalysisTypes
        public var locales: [String] = []
        public init(_ analysisTypes: AnalysisTypes) { self.analysisTypes = analysisTypes }
    }
    /// isim: true (text needs the host's tesseract, codes zbar or zxing-cpp)
    public class var isSupported: Bool { true }
    public class var supportedTextRecognitionLanguages: [String] { _VKRecognizer.textLanguages }
    public init() {}

    public func analyze(_ image: UIImage, configuration: Configuration) async throws -> ImageAnalysis {
        try await analyze(image, orientation: image.imageOrientation, configuration: configuration)
    }
    public func analyze(_ image: UIImage, orientation: UIImage.Orientation, configuration: Configuration) async throws -> ImageAnalysis {
        guard let cg = image.cgImage else { throw ImageAnalyzer._error("the image has no bitmap to analyze") }
        return try await analyze(cg, orientation: CGImagePropertyOrientation(orientation), configuration: configuration)
    }
    public func analyze(_ image: CGImage, orientation: CGImagePropertyOrientation, configuration: Configuration) async throws -> ImageAnalysis {
        let size = CGSize(width: image.width, height: image.height)
        return await _run(VNImageRequestHandler(cgImage: image, orientation: orientation), size, configuration)
    }
    public func analyze(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, configuration: Configuration) async throws -> ImageAnalysis {
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        return await _run(VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation), size, configuration)
    }
    public func analyze(_ image: CIImage, orientation: CGImagePropertyOrientation, configuration: Configuration) async throws -> ImageAnalysis {
        guard let cg = CIContext().createCGImage(image, from: image.extent) else { throw ImageAnalyzer._error("the CIImage could not be rendered") }
        return try await analyze(cg, orientation: orientation, configuration: configuration)
    }
    public func analyze(imageAt url: URL, orientation: CGImagePropertyOrientation, configuration: Configuration) async throws -> ImageAnalysis {
        guard let img = UIImage(contentsOfFile: url.path), let cg = img.cgImage else { throw ImageAnalyzer._error("isim could not read the image at \(url.path)") }
        return try await analyze(cg, orientation: orientation, configuration: configuration)
    }
    func _run(_ handler: VNImageRequestHandler, _ size: CGSize, _ c: Configuration) async -> ImageAnalysis {
        let wantText = c.analysisTypes.contains(.text), wantCodes = c.analysisTypes.contains(.machineReadableCode)
        if wantText && !_VKRecognizer.textAvailable { NSLog("isim VisionKit: Live Text needs the host's tesseract command; the analysis has no text") }
        let box = _VKBox(handler)
        let found = await withCheckedContinuation { (k: CheckedContinuation<[_VKFound], Never>) in
            DispatchQueue.global().async {
                k.resume(returning: _VKRecognizer.run(box.value, codes: wantCodes ? [] : nil, text: wantText ? (c.locales, nil) : nil, accurate: true))
            }
        }
        return ImageAnalysis(found: found, imageSize: size)
    }
    static func _error(_ m: String) -> NSError { NSError(domain: "com.apple.VisionKit", code: 1, userInfo: [NSLocalizedDescriptionKey: m]) }
}
struct _VKBox<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up; case .down: self = .down; case .left: self = .left; case .right: self = .right
        case .upMirrored: self = .upMirrored; case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored; case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// what Live Text found in an image: lines of text (top to bottom) and machine-readable codes
public final class ImageAnalysis: @unchecked Sendable {
    struct _Line { var text: String; var box: CGRect; var isCode: Bool }   // box: normalized, origin top left
    let _lines: [_Line]
    let imageSize: CGSize
    init(found: [_VKFound], imageSize: CGSize) {
        self.imageSize = imageSize
        _lines = found.map { f in
            let xs = f.quad.map(\.x), ys = f.quad.map { 1 - $0.y }
            return _Line(text: f.transcript, box: CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!), isCode: !f.isText)
        }.sorted { ($0.isCode ? 1 : 0, $0.box.minY, $0.box.minX) < ($1.isCode ? 1 : 0, $1.box.minY, $1.box.minX) }
    }
    /// the recognized text, a line per line
    public var transcript: String { _lines.filter { !$0.isCode }.map(\.text).joined(separator: "\n") }
    public func hasResults(for types: ImageAnalyzer.AnalysisTypes) -> Bool {
        (types.contains(.text) && _lines.contains { !$0.isCode }) || (types.contains(.machineReadableCode) && _lines.contains(where: \.isCode))
    }
}

// MARK: - ImageAnalysisInteraction

@MainActor
public final class ImageAnalysisInteraction: NSObject, UIInteraction {
    public struct InteractionTypes: OptionSet, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let textSelection = InteractionTypes(rawValue: 1 << 0)
        public static let dataDetectors = InteractionTypes(rawValue: 1 << 1)
        public static let imageSubject = InteractionTypes(rawValue: 1 << 2)
        public static let visualLookUp = InteractionTypes(rawValue: 1 << 3)
        public static let automatic = InteractionTypes(rawValue: 1 << 4)
        public static let automaticTextOnly = InteractionTypes(rawValue: 1 << 5)
    }
    public struct Subject: Hashable, @unchecked Sendable {
        let _id = UUID()
        public var image: UIImage
        public var bounds: CGRect
        public static func == (a: Subject, b: Subject) -> Bool { a._id == b._id }
        public func hash(into h: inout Hasher) { h.combine(_id) }
    }
    public enum SubjectUnavailable: Error, Sendable { case imageUnavailable }

    public weak var delegate: ImageAnalysisInteractionDelegate?
    public private(set) weak var view: UIView?
    public var analysis: ImageAnalysis? { didSet { _selected = nil; _refresh() } }
    public var preferredInteractionTypes: InteractionTypes = .automatic { didSet { _refresh() } }
    public var activeInteractionTypes: InteractionTypes {
        guard analysis != nil else { return [] }
        var t = preferredInteractionTypes
        if t.contains(.automatic) { t.formUnion([.textSelection, .dataDetectors]) }       // no subjects or visual look up on isim
        if t.contains(.automaticTextOnly) { t.formUnion([.textSelection, .dataDetectors]) }
        t.subtract([.automatic, .automaticTextOnly, .imageSubject, .visualLookUp])
        return t
    }
    public var selectableItemsHighlighted = false {
        didSet {
            guard oldValue != selectableItemsHighlighted else { return }
            _refresh(); delegate?.interaction(self, highlightSelectedItemsDidChange: selectableItemsHighlighted)
        }
    }
    public var allowLongPressForDataDetectorsInTextMode = true
    public var isSupplementaryInterfaceHidden = false { didSet { _refresh() } }
    public var supplementaryInterfaceContentInsets: UIEdgeInsets = .zero { didSet { _refresh() } }
    public var supplementaryInterfaceFont: UIFont?
    /// isim: subject lifting is not available, so there are no subjects
    public var subjects: Set<Subject> { [] }
    public var highlightedSubjects: Set<Subject> = []

    let _overlay = _VKOverlayView()
    let _button = UIButton(type: .system)
    var _selected: Int?
    var _wasButtonVisible = false

    public override init() {
        super.init()
        _overlay.isUserInteractionEnabled = true
        _overlay.backgroundColor = .clear
        _overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(_tap(_:))))
        _overlay.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(_longPress(_:))))
        _button.setImage(UIImage(systemName: "text.viewfinder"), for: .normal)
        _button.tintColor = .label
        _button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        _button.layer.cornerRadius = 8
        _button.accessibilityIdentifier = "imageanalysis-livetext"
        _button.accessibilityLabel = "Live Text"
        _button.addTarget(self, action: #selector(_toggle), for: .touchUpInside)
        _overlay.addSubview(_button)
    }
    public convenience init(_ delegate: ImageAnalysisInteractionDelegate) { self.init(); self.delegate = delegate }

    public func willMove(to view: UIView?) { _overlay.removeFromSuperview() }
    public func didMove(to view: UIView?) {
        self.view = view
        if let view { view.isUserInteractionEnabled = true; view.addSubview(_overlay) }
        _refresh()
    }

    // MARK: geometry
    /// the image's rectangle in the view, in unit coordinates of the view's bounds
    public var contentsRect: CGRect {
        guard let v = view else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        if let r = delegate?.contentsRect(for: self) { return r }
        let b = v.bounds
        guard let iv = v as? UIImageView, let img = iv.image, b.width > 0, b.height > 0, img.size.width > 0, img.size.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let s: CGFloat
        switch iv.contentMode {
        case .scaleAspectFit: s = Swift.min(b.width / img.size.width, b.height / img.size.height)
        case .scaleAspectFill: s = Swift.max(b.width / img.size.width, b.height / img.size.height)
        default: return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let w = img.size.width * s, h = img.size.height * s
        return CGRect(x: (b.width - w) / 2 / b.width, y: (b.height - h) / 2 / b.height, width: w / b.width, height: h / b.height)
    }
    public func setContentsRectNeedsUpdate() { _refresh() }
    func _viewRect(_ box: CGRect) -> CGRect {
        guard let v = view else { return .zero }
        let c = contentsRect, b = v.bounds
        return CGRect(x: (c.minX + box.minX * c.width) * b.width, y: (c.minY + box.minY * c.height) * b.height,
                      width: box.width * c.width * b.width, height: box.height * c.height * b.height)
    }
    func _line(at p: CGPoint, codes: Bool = false) -> Int? {
        analysis?._lines.indices.first { i in
            let l = analysis!._lines[i]
            return (codes || !l.isCode) && _viewRect(l.box).insetBy(dx: -4, dy: -4).contains(p)
        }
    }

    // MARK: text
    public var text: String { analysis?.transcript ?? "" }
    public var hasActiveTextSelection: Bool { _selected != nil }
    public var selectedText: String { _selected.flatMap { analysis?._lines[$0].text } ?? "" }
    public var selectedAttributedText: AttributedString { AttributedString(selectedText) }
    public var selectedRanges: [Range<String.Index>] {
        guard let i = _selected, let a = analysis else { return [] }
        let t = text, lines = a._lines.filter { !$0.isCode }
        guard let k = lines.firstIndex(where: { $0.text == a._lines[i].text && $0.box == a._lines[i].box }) else { return [] }
        let start = lines[..<k].reduce(0) { $0 + $1.text.count + 1 }
        let lo = t.index(t.startIndex, offsetBy: start), hi = t.index(lo, offsetBy: lines[k].text.count)
        return [lo..<hi]
    }
    public func resetTextSelection() { guard _selected != nil else { return }; _selected = nil; _refresh(); delegate?.textSelectionDidChange(self) }
    public func hasText(at point: CGPoint) -> Bool { activeInteractionTypes.contains(.textSelection) && analysisHasText(at: point) }
    public func analysisHasText(at point: CGPoint) -> Bool { _line(at: point) != nil }
    public func hasDataDetector(at point: CGPoint) -> Bool {
        guard activeInteractionTypes.contains(.dataDetectors), let a = analysis else { return false }
        if let i = _line(at: point, codes: true) { return a._lines[i].isCode || _VKText.anyDataDetector(in: a._lines[i].text) }
        return false
    }
    public func hasInteractiveItem(at point: CGPoint) -> Bool { hasText(at: point) || hasDataDetector(at: point) }
    public func hasSupplementaryInterface(at point: CGPoint) -> Bool {
        guard liveTextButtonVisible, let v = view else { return false }
        return _button.convert(_button.bounds, to: v).contains(point)
    }

    // MARK: subjects (not available on isim)
    public func subject(at point: CGPoint) async -> Subject? { nil }
    public func image(for subjects: Set<Subject>) async throws -> UIImage { throw SubjectUnavailable.imageUnavailable }

    // MARK: supplementary interface
    public var liveTextButtonVisible: Bool {
        !isSupplementaryInterfaceHidden && view != nil && activeInteractionTypes.contains(.textSelection) && analysis?._lines.isEmpty == false
    }
    public func setSupplementaryInterfaceHidden(_ hidden: Bool, animated: Bool) { isSupplementaryInterfaceHidden = hidden }

    func _refresh() {
        guard let v = view else { return }
        _overlay.frame = v.bounds
        v.bringSubviewToFront(_overlay)
        let c = _viewRect(CGRect(x: 0, y: 0, width: 1, height: 1)), ins = supplementaryInterfaceContentInsets
        _button.frame = CGRect(x: c.maxX - 44 - 8 - ins.right, y: c.maxY - 36 - 8 - ins.bottom, width: 44, height: 36)
        let visible = liveTextButtonVisible
        _button.isHidden = !visible
        _button.tintColor = selectableItemsHighlighted ? .white : .label
        _button.backgroundColor = selectableItemsHighlighted ? .systemBlue : UIColor.systemBackground.withAlphaComponent(0.85)
        if visible != _wasButtonVisible { _wasButtonVisible = visible; delegate?.interaction(self, liveTextButtonDidChangeToVisible: visible) }
        _overlay.shapes = (analysis?._lines.indices.map { i in (_viewRect(analysis!._lines[i].box), i == _selected) } ?? [])
            .filter { selectableItemsHighlighted || $0.1 }
        _overlay.dims = selectableItemsHighlighted
        _overlay.dimRect = c
        _overlay.setNeedsDisplay()
    }
    @objc func _toggle() { selectableItemsHighlighted.toggle() }
    func _select(_ p: CGPoint) -> Bool {
        guard activeInteractionTypes.contains(.textSelection), let i = _line(at: p) else { return false }
        if delegate?.interaction(self, shouldBeginAt: p, for: .textSelection) == false { return false }
        _selected = i; _refresh(); delegate?.textSelectionDidChange(self)
        return true
    }
    @objc func _tap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: view)
        if selectableItemsHighlighted, _select(p) { return }
        resetTextSelection()
    }
    @objc func _longPress(_ g: UILongPressGestureRecognizer) {
        if g.state == .began { _ = _select(g.location(in: view)) }
    }
}

/// Live Text's highlights: the image dimmed, the items outlined, the selection filled
final class _VKOverlayView: UIView {
    var shapes: [(CGRect, Bool)] = []
    var dims = false
    var dimRect = CGRect.zero
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        if dims { ctx.setFillColor(UIColor.black.withAlphaComponent(0.25).cgColor); ctx.fill(dimRect) }
        for (r, selected) in shapes {
            let path = UIBezierPath(roundedRect: r.insetBy(dx: -3, dy: -3), cornerRadius: 4)
            ctx.setFillColor((selected ? UIColor.systemBlue.withAlphaComponent(0.35) : UIColor.white.withAlphaComponent(0.25)).cgColor)
            ctx.addPath(path.cgPath); ctx.fillPath()
            if !selected {
                ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(1.5)
                ctx.addPath(path.cgPath); ctx.strokePath()
            }
        }
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { bounds.contains(point) }
}

@MainActor
public protocol ImageAnalysisInteractionDelegate: AnyObject {
    func contentView(for interaction: ImageAnalysisInteraction) -> UIView?
    func contentsRect(for interaction: ImageAnalysisInteraction) -> CGRect
    func presentingViewController(for interaction: ImageAnalysisInteraction) -> UIViewController?
    func interaction(_ interaction: ImageAnalysisInteraction, shouldBeginAt point: CGPoint, for interactionType: ImageAnalysisInteraction.InteractionTypes) -> Bool
    func interaction(_ interaction: ImageAnalysisInteraction, liveTextButtonDidChangeToVisible visible: Bool)
    func interaction(_ interaction: ImageAnalysisInteraction, highlightSelectedItemsDidChange highlightSelectedItems: Bool)
    func textSelectionDidChange(_ interaction: ImageAnalysisInteraction)
}
extension ImageAnalysisInteractionDelegate {
    public func contentView(for interaction: ImageAnalysisInteraction) -> UIView? { nil }
    public func contentsRect(for interaction: ImageAnalysisInteraction) -> CGRect { interaction._defaultContentsRect }
    public func presentingViewController(for interaction: ImageAnalysisInteraction) -> UIViewController? { nil }
    public func interaction(_ interaction: ImageAnalysisInteraction, shouldBeginAt point: CGPoint, for interactionType: ImageAnalysisInteraction.InteractionTypes) -> Bool { true }
    public func interaction(_ interaction: ImageAnalysisInteraction, liveTextButtonDidChangeToVisible visible: Bool) {}
    public func interaction(_ interaction: ImageAnalysisInteraction, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {}
    public func textSelectionDidChange(_ interaction: ImageAnalysisInteraction) {}
}

// MARK: - VNDocumentCameraViewController

@objc(VNDocumentCameraScan)
open class VNDocumentCameraScan: NSObject {
    let _pages: [UIImage]
    init(pages: [UIImage]) { _pages = pages }
    @objc open var pageCount: Int { _pages.count }
    @objc open var title: String { "Scanned Document" }
    @objc(imageOfPageAtIndex:) open func imageOfPage(at index: Int) -> UIImage {
        guard _pages.indices.contains(index) else { NSLog("isim VisionKit: page %d is out of range (%d pages)", index, _pages.count); return UIImage() }
        return _pages[index]
    }
}

@objc(VNDocumentCameraViewControllerDelegate)
public protocol VNDocumentCameraViewControllerDelegate: NSObjectProtocol {
    @objc(documentCameraViewController:didFinishWithScan:) optional func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan)
    @objc optional func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController)
    @objc optional func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error)
}

/// The document camera: the page is found on the live frames (a blue overlay); the shutter adds it, perspective-corrected.
@objc(VNDocumentCameraViewController)
open class VNDocumentCameraViewController: UIViewController {
    /// isim: true when the device has a camera (ISIM_CAMERA)
    @objc open class var isSupported: Bool { AVCaptureDevice.default(for: .video) != nil }
    @objc open weak var delegate: VNDocumentCameraViewControllerDelegate?

    let _sink = _VKFrameSink()
    var _session: AVCaptureSession?
    var _preview: AVCaptureVideoPreviewLayer?
    let _previewView = UIView()
    let _quad = CAShapeLayer()
    let _hint = UILabel()
    let _cancel = UIButton(type: .system)
    let _shutter = UIButton(type: .custom)
    let _save = UIButton(type: .system)
    let _thumb = UIImageView()
    let _flash = UIView()
    var _pages: [UIImage] = []
    var _lastQuad: [CGPoint]?        // normalized, Vision's coordinates

    @objc public init() { super.init(nibName: nil, bundle: nil); modalPresentationStyle = .fullScreen }
    open override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(_previewView)
        _quad.fillColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        _quad.strokeColor = UIColor.systemBlue.cgColor
        _quad.lineWidth = 2
        _previewView.layer.addSublayer(_quad)
        _hint.text = "Position the document in view."
        _hint.textColor = .white; _hint.font = .systemFont(ofSize: 15, weight: .medium); _hint.textAlignment = .center
        _hint.backgroundColor = UIColor.black.withAlphaComponent(0.55); _hint.layer.cornerRadius = 8; _hint.clipsToBounds = true
        _hint.accessibilityIdentifier = "documentcamera-hint"
        _cancel.setTitle("Cancel", for: .normal); _cancel.setTitleColor(.white, for: .normal); _cancel.titleLabel?.font = .systemFont(ofSize: 17)
        _cancel.accessibilityIdentifier = "documentcamera-cancel"
        _cancel.addTarget(self, action: #selector(_cancelTapped), for: .touchUpInside)
        _shutter.backgroundColor = .white; _shutter.layer.cornerRadius = 32
        _shutter.layer.borderColor = UIColor.black.cgColor; _shutter.layer.borderWidth = 3
        _shutter.accessibilityIdentifier = "documentcamera-shutter"; _shutter.accessibilityLabel = "Take Picture"
        _shutter.addTarget(self, action: #selector(_shutterTapped), for: .touchUpInside)
        _save.setTitle("Save", for: .normal); _save.setTitleColor(.white, for: .normal); _save.setTitleColor(.gray, for: .disabled)
        _save.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        _save.accessibilityIdentifier = "documentcamera-save"; _save.isEnabled = false
        _save.addTarget(self, action: #selector(_saveTapped), for: .touchUpInside)
        _thumb.contentMode = .scaleAspectFit; _thumb.layer.borderColor = UIColor.white.cgColor; _thumb.layer.borderWidth = 1; _thumb.isHidden = true
        _flash.backgroundColor = .white; _flash.alpha = 0; _flash.isUserInteractionEnabled = false
        for v in [_hint, _cancel, _shutter, _save, _thumb, _flash] { view.addSubview(v) }
    }
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds, top = view.safeAreaInsets.top, bottom = view.safeAreaInsets.bottom
        let barTop = top + 44, barBottom: CGFloat = 120 + bottom
        _previewView.frame = CGRect(x: 0, y: barTop, width: b.width, height: b.height - barTop - barBottom)
        _preview?.frame = _previewView.bounds
        _quad.frame = _previewView.bounds
        _cancel.frame = CGRect(x: 16, y: top, width: 80, height: 44)
        let hw = Swift.min(b.width - 64, 300)
        _hint.frame = CGRect(x: (b.width - hw) / 2, y: barTop + 16, width: hw, height: 32)
        let sy = b.height - bottom - 120 + 28
        _shutter.frame = CGRect(x: b.midX - 32, y: sy, width: 64, height: 64)
        _save.frame = CGRect(x: b.width - 116, y: sy + 10, width: 100, height: 44)
        _thumb.frame = CGRect(x: 20, y: sy, width: 48, height: 64)
        _flash.frame = _previewView.frame
    }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard VNDocumentCameraViewController.isSupported, let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            NSLog("isim VisionKit: the document camera is not supported: the device has no camera (set ISIM_CAMERA)")
            delegate?.documentCameraViewController?(self, didFailWithError: NSError(domain: "com.apple.VisionKit", code: 1,
                                                    userInfo: [NSLocalizedDescriptionKey: "the document camera is not supported: the device has no camera"]))
            return
        }
        guard _session == nil else { return }
        let s = AVCaptureSession()
        s.beginConfiguration()
        if s.canAddInput(input) { s.addInput(input) }
        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.setSampleBufferDelegate(_sink, queue: _sink.queue)
        if s.canAddOutput(out) { s.addOutput(out) }
        s.commitConfiguration()
        let layer = AVCaptureVideoPreviewLayer(session: s)
        layer.videoGravity = .resizeAspect
        layer.frame = _previewView.bounds
        _previewView.layer.insertSublayer(layer, at: 0)
        _session = s; _preview = layer
        _sink.interval = 0.4
        _sink.analyze = { [weak self] pb in
            let r = VNDetectRectanglesRequest()
            r.maximumObservations = 1; r.minimumSize = 0.2; r.minimumAspectRatio = 0.3; r.quadratureTolerance = 30; r.minimumConfidence = 0.5
            try? VNImageRequestHandler(cvPixelBuffer: pb).perform([r])
            let q = (r.results?.first as? VNRectangleObservation).map { [$0.topLeft, $0.topRight, $0.bottomRight, $0.bottomLeft] }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?._showQuad(q) } }
        }
        DispatchQueue.global().async { s.startRunning() }
    }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        _sink.analyze = nil
        let s = _session
        DispatchQueue.global().async { s?.stopRunning() }
    }
    func _showQuad(_ q: [CGPoint]?) {
        _lastQuad = q
        guard let q, let p = _preview else { _quad.path = nil; return }
        let pts = q.map { p.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: $0.x, y: 1 - $0.y)) }
        let path = UIBezierPath(); path.move(to: pts[0]); for x in pts.dropFirst() { path.addLine(to: x) }; path.close()
        _quad.path = path.cgPath
        if _pages.isEmpty { _hint.text = "Ready to scan." }
    }
    @objc func _cancelTapped() { delegate?.documentCameraViewControllerDidCancel?(self) }
    @objc func _saveTapped() {
        guard !_pages.isEmpty else { return }
        delegate?.documentCameraViewController?(self, didFinishWith: VNDocumentCameraScan(pages: _pages))
    }
    @objc func _shutterTapped() {
        guard let frame = _sink.lastFrame() else { return }
        let page = _lastQuad.flatMap { _VKWarp.page(frame, quad: $0) } ?? frame
        _pages.append(UIImage(cgImage: page))
        _thumb.image = _pages.last; _thumb.isHidden = false
        _save.isEnabled = true
        _save.setTitle("Save (\(_pages.count))", for: .normal)
        _hint.text = "Ready for next scan."
        _flash.alpha = 0.8
        UIView.animate(withDuration: 0.3) { self._flash.alpha = 0 }
        NSLog("isim VisionKit: scanned page %d (%dx%d)", _pages.count, page.width, page.height)
    }
}

/// the page inside a quad, perspective-corrected (a homography, bilinear samples)
enum _VKWarp {
    static func page(_ image: CGImage, quad: [CGPoint]) -> CGImage? {
        let W = image.width, H = image.height
        // Vision's normalized corners (origin bottom left) to pixels (origin top left)
        let q = quad.map { CGPoint(x: $0.x * CGFloat(W), y: (1 - $0.y) * CGFloat(H)) }
        func d(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        let ow = Int(Swift.max(d(q[0], q[1]), d(q[3], q[2])).rounded()), oh = Int(Swift.max(d(q[0], q[3]), d(q[1], q[2])).rounded())
        guard ow > 8, oh > 8, let src = rgba(image), let h = homography(from: [CGPoint(x: 0, y: 0), CGPoint(x: ow, y: 0), CGPoint(x: ow, y: oh), CGPoint(x: 0, y: oh)], to: q) else { return nil }
        var out = [UInt8](repeating: 255, count: ow * oh * 4)
        for y in 0..<oh {
            for x in 0..<ow {
                let X = Double(x) + 0.5, Y = Double(y) + 0.5
                let w = h[6] * X + h[7] * Y + 1
                let sx = (h[0] * X + h[1] * Y + h[2]) / w - 0.5, sy = (h[3] * X + h[4] * Y + h[5]) / w - 0.5
                let x0 = Int(sx.rounded(.down)), y0 = Int(sy.rounded(.down)), fx = sx - Double(x0), fy = sy - Double(y0)
                for c in 0..<4 {
                    func px(_ a: Int, _ b: Int) -> Double { Double(src[(Swift.min(Swift.max(b, 0), H - 1) * W + Swift.min(Swift.max(a, 0), W - 1)) * 4 + c]) }
                    let v = px(x0, y0) * (1 - fx) * (1 - fy) + px(x0 + 1, y0) * fx * (1 - fy) + px(x0, y0 + 1) * (1 - fx) * fy + px(x0 + 1, y0 + 1) * fx * fy
                    out[(y * ow + x) * 4 + c] = UInt8(Swift.max(0, Swift.min(255, v.rounded())))
                }
            }
        }
        let data = Data(out) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: ow, height: oh, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: ow * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }
    static func rgba(_ image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ok = buf.withUnsafeMutableBytes { p -> Bool in
            guard let ctx = CGContext(data: p.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? buf : nil
    }
    /// the 3x3 projective map (h33 = 1) taking the four `from` points to the `to` points
    static func homography(from s: [CGPoint], to t: [CGPoint]) -> [Double]? {
        var a = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for i in 0..<4 {
            let x = Double(s[i].x), y = Double(s[i].y), X = Double(t[i].x), Y = Double(t[i].y)
            a[2 * i] = [x, y, 1, 0, 0, 0, -X * x, -X * y, X]
            a[2 * i + 1] = [0, 0, 0, x, y, 1, -Y * x, -Y * y, Y]
        }
        for col in 0..<8 {      // Gaussian elimination with partial pivoting
            guard let piv = (col..<8).max(by: { abs(a[$0][col]) < abs(a[$1][col]) }), abs(a[piv][col]) > 1e-12 else { return nil }
            a.swapAt(col, piv)
            for r in 0..<8 where r != col {
                let f = a[r][col] / a[col][col]
                if f != 0 { for k in col..<9 { a[r][k] -= f * a[col][k] } }
            }
        }
        return (0..<8).map { a[$0][8] / a[$0][$0] }
    }
}

extension ImageAnalysisInteraction {
    /// the contents rectangle isim computes for the view (used when the delegate does not give one)
    var _defaultContentsRect: CGRect {
        let d = delegate; delegate = nil
        defer { delegate = d }
        return contentsRect
    }
}
