// isim VisionKit (self-authored, iOS API names) — stub: DataScannerViewController and VNDocumentCameraViewController
// report isSupported = false (like the iOS Simulator, which has no camera and no Live Text models), and
// ImageAnalyzer reports isSupported = false. The types exist so apps compile, check support and fall back
// (e.g. to AVCaptureMetadataOutput or VNDetectBarcodesRequest, which isim does run).
import UIKit
import Vision

@MainActor
open class DataScannerViewController: UIViewController {
    public enum RecognizedDataType: Hashable, Sendable {
        case barcode(symbologies: [VNBarcodeSymbology])
        case text(languages: [String] = [], textContentType: TextContentType? = nil)
        public static func barcode() -> RecognizedDataType { .barcode(symbologies: []) }
    }
    public enum TextContentType: Hashable, Sendable { case dateTimeDuration, emailAddress, flightNumber, fullStreetAddress, shipmentTrackingNumber, telephoneNumber, URL, currency }
    public enum QualityLevel: Sendable { case balanced, fast, accurate }
    public enum ScanningUnavailable: Error, Sendable { case unsupported, cameraRestricted }
    public enum RecognizedItem: Identifiable, Sendable {
        case text(Text), barcode(Barcode)
        public var id: UUID { switch self { case .text(let t): return t.id; case .barcode(let b): return b.id } }
        public struct Text: Sendable { public let id = UUID(); public let transcript: String; public let bounds: Bounds }
        public struct Barcode: Sendable { public let id = UUID(); public let payloadStringValue: String?; public let bounds: Bounds }
        public struct Bounds: Sendable { public var topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint }
    }

    /// isim: false — no Live Text scanner (stub)
    public static var isSupported: Bool { false }
    public static var isAvailable: Bool { false }
    public static var supportedTextRecognitionLanguages: [String] { [] }

    public let recognizedDataTypes: Set<RecognizedDataType>
    public let qualityLevel: QualityLevel
    public let recognizesMultipleItems: Bool
    public let isHighFrameRateTrackingEnabled: Bool
    public let isPinchToZoomEnabled: Bool
    public let isGuidanceEnabled: Bool
    public let isHighlightingEnabled: Bool
    open weak var delegate: DataScannerViewControllerDelegate?
    open var regionOfInterest: CGRect?
    open private(set) var isScanning = false
    open var zoomFactor: Double = 1
    open var overlayContainerView: UIView { view }
    open var recognizedItems: AsyncStream<[RecognizedItem]> { AsyncStream { $0.finish() } }

    public init(recognizedDataTypes: Set<RecognizedDataType>, qualityLevel: QualityLevel = .balanced, recognizesMultipleItems: Bool = false,
                isHighFrameRateTrackingEnabled: Bool = true, isPinchToZoomEnabled: Bool = true, isGuidanceEnabled: Bool = true, isHighlightingEnabled: Bool = false) {
        self.recognizedDataTypes = recognizedDataTypes; self.qualityLevel = qualityLevel; self.recognizesMultipleItems = recognizesMultipleItems
        self.isHighFrameRateTrackingEnabled = isHighFrameRateTrackingEnabled; self.isPinchToZoomEnabled = isPinchToZoomEnabled
        self.isGuidanceEnabled = isGuidanceEnabled; self.isHighlightingEnabled = isHighlightingEnabled
        super.init(nibName: nil, bundle: nil)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    /// throws ScanningUnavailable.unsupported on isim
    open func startScanning() throws {
        NSLog("isim VisionKit: DataScannerViewController is not supported on isim (isSupported is false)")
        throw ScanningUnavailable.unsupported
    }
    open func stopScanning() { isScanning = false }
    open func capturePhoto() async throws -> UIImage { throw ScanningUnavailable.unsupported }
}
@MainActor
public protocol DataScannerViewControllerDelegate: AnyObject {
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: DataScannerViewController.RecognizedItem)
    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable)
}
extension DataScannerViewControllerDelegate {
    public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: DataScannerViewController.RecognizedItem) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {}
}

/// Document camera (stub): isSupported is false.
open class VNDocumentCameraViewController: UIViewController {
    open class var isSupported: Bool { false }
    open weak var delegate: VNDocumentCameraViewControllerDelegate?
    public init() { super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate?.documentCameraViewController(self, didFailWithError: NSError(domain: "com.apple.VisionKit", code: 1,
                                               userInfo: [NSLocalizedDescriptionKey: "the document camera is not supported on isim"]))
    }
}
public protocol VNDocumentCameraViewControllerDelegate: NSObjectProtocol {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan)
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController)
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error)
}
extension VNDocumentCameraViewControllerDelegate {
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {}
    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {}
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {}
}
open class VNDocumentCameraScan: NSObject {
    open var pageCount: Int { 0 }
    open var title: String { "" }
    open func imageOfPage(at index: Int) -> UIImage { UIImage() }
}

/// Live Text image analysis (stub): isSupported is false; analyze throws.
public final class ImageAnalyzer: @unchecked Sendable {
    public struct AnalysisTypes: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let text = AnalysisTypes(rawValue: 1), machineReadableCode = AnalysisTypes(rawValue: 2), visualLookUp = AnalysisTypes(rawValue: 4)
    }
    public struct Configuration: Sendable { public var analysisTypes: AnalysisTypes; public var locales: [String] = []; public init(_ types: AnalysisTypes) { analysisTypes = types } }
    public static var isSupported: Bool { false }
    public static var supportedTextRecognitionLanguages: [String] { get async { [] } }
    public init() {}
    public func analyze(_ image: UIImage, configuration: Configuration) async throws -> AnyObject {
        throw NSError(domain: "com.apple.VisionKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live Text analysis is not supported on isim"])
    }
}
