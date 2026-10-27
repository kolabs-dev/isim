// isim Vision: the iOS 18 Swift API (issue #374): ImageRequestHandler, value-type requests and observations over the
// engines of the VN classes (adapted, the same as theirs): RecognizeTextRequest (the host's tesseract),
// DetectBarcodesRequest (libzbar / zxing-cpp), DetectFaceRectanglesRequest (Core Image's Haar cascades) and
// RecognizeDocumentsRequest (text lines grouped into paragraphs, with the barcodes). Without an engine a request
// throws VisionError.unsupportedRequest with a message saying what is missing.
// Not in isim: compute devices (MLComputeDevice), the other requests and their VisionResult cases, NormalizedRegion
// (iOS 26) and document lists, tables and data detection (always empty).
import UIKit
import CoreImage

// MARK: - geometry

public enum CoordinateOrigin: Hashable, Sendable { case upperLeft, lowerLeft }

/// A point in normalized coordinates: 0...1 across the image, origin at the lower left.
public struct NormalizedPoint: Hashable, Sendable, Codable, CustomStringConvertible {
    public var x: CGFloat
    public var y: CGFloat
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }
    public init(normalizedPoint: CGPoint) { x = normalizedPoint.x; y = normalizedPoint.y }
    public init(imagePoint: CGPoint, in imageSize: CGSize) {
        x = imageSize.width > 0 ? imagePoint.x / imageSize.width : 0
        y = imageSize.height > 0 ? imagePoint.y / imageSize.height : 0
    }
    /// a point of the image, normalized to a region of it
    public init(imagePoint: CGPoint, in imageSize: CGSize, normalizedTo region: NormalizedRect) {
        let p = NormalizedPoint(imagePoint: imagePoint, in: imageSize)
        x = region.width > 0 ? (p.x - region.origin.x) / region.width : 0
        y = region.height > 0 ? (p.y - region.origin.y) / region.height : 0
    }
    public static var zero: NormalizedPoint { NormalizedPoint(x: 0, y: 0) }
    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    public func toImageCoordinates(_ imageSize: CGSize, origin: CoordinateOrigin = .lowerLeft) -> CGPoint {
        CGPoint(x: x * imageSize.width, y: (origin == .lowerLeft ? y : 1 - y) * imageSize.height)
    }
    /// the point, normalized to `region`, in the image's coordinates
    public func toImageCoordinates(from region: NormalizedRect, imageSize: CGSize, origin: CoordinateOrigin = .lowerLeft) -> CGPoint {
        NormalizedPoint(x: region.origin.x + x * region.width, y: region.origin.y + y * region.height).toImageCoordinates(imageSize, origin: origin)
    }
    public func verticallyFlipped() -> NormalizedPoint { NormalizedPoint(x: x, y: 1 - y) }
    public var description: String { "(\(x), \(y))" }
}

/// A rectangle in normalized coordinates: 0...1 across the image, origin at the lower left.
public struct NormalizedRect: Hashable, Sendable, Codable, CustomStringConvertible {
    public var origin: CGPoint
    public var width: CGFloat
    public var height: CGFloat
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) { origin = CGPoint(x: x, y: y); self.width = width; self.height = height }
    public init(normalizedRect: CGRect) { self.init(x: normalizedRect.minX, y: normalizedRect.minY, width: normalizedRect.width, height: normalizedRect.height) }
    public init(imageRect: CGRect, in imageSize: CGSize) {
        self.init(normalizedRect: VNNormalizedRectForImageRect(imageRect, Int(imageSize.width), Int(imageSize.height)))
    }
    public init(imageRect: CGRect, in imageSize: CGSize, normalizedTo region: NormalizedRect) {
        let r = NormalizedRect(imageRect: imageRect, in: imageSize)
        self.init(x: region.width > 0 ? (r.origin.x - region.origin.x) / region.width : 0, y: region.height > 0 ? (r.origin.y - region.origin.y) / region.height : 0,
                  width: region.width > 0 ? r.width / region.width : 0, height: region.height > 0 ? r.height / region.height : 0)
    }
    public static var fullImage: NormalizedRect { NormalizedRect(x: 0, y: 0, width: 1, height: 1) }
    public var cgRect: CGRect { CGRect(origin: origin, size: CGSize(width: width, height: height)) }
    public func toImageCoordinates(_ imageSize: CGSize, origin: CoordinateOrigin = .lowerLeft) -> CGRect {
        let y = origin == .lowerLeft ? self.origin.y : 1 - self.origin.y - height
        return CGRect(x: self.origin.x * imageSize.width, y: y * imageSize.height, width: width * imageSize.width, height: height * imageSize.height)
    }
    public func toImageCoordinates(from region: NormalizedRect, imageSize: CGSize, origin: CoordinateOrigin = .lowerLeft) -> CGRect {
        NormalizedRect(x: region.origin.x + self.origin.x * region.width, y: region.origin.y + self.origin.y * region.height,
                       width: width * region.width, height: height * region.height).toImageCoordinates(imageSize, origin: origin)
    }
    public func verticallyFlipped() -> NormalizedRect { NormalizedRect(x: origin.x, y: 1 - origin.y - height, width: width, height: height) }
    public var description: String { "(\(origin.x), \(origin.y), \(width), \(height))" }
    enum CodingKeys: String, CodingKey { case x, y, width, height }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(CGFloat.self, forKey: .x), y: try c.decode(CGFloat.self, forKey: .y),
                  width: try c.decode(CGFloat.self, forKey: .width), height: try c.decode(CGFloat.self, forKey: .height))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(origin.x, forKey: .x); try c.encode(origin.y, forKey: .y); try c.encode(width, forKey: .width); try c.encode(height, forKey: .height)
    }
}

public protocol BoundingBoxProviding {
    var boundingBox: NormalizedRect { get }
}
public protocol QuadrilateralProviding: BoundingBoxProviding {
    var topLeft: NormalizedPoint { get }
    var topRight: NormalizedPoint { get }
    var bottomRight: NormalizedPoint { get }
    var bottomLeft: NormalizedPoint { get }
}
extension QuadrilateralProviding {
    public var boundingBox: NormalizedRect {
        let xs = [topLeft.x, topRight.x, bottomRight.x, bottomLeft.x], ys = [topLeft.y, topRight.y, bottomRight.y, bottomLeft.y]
        return NormalizedRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}

// MARK: - errors, stages, descriptors

public enum VisionError: Error, CustomStringConvertible, Sendable {
    case internalError(String), ioError(String), operationFailed(String), outOfBoundsError(String), outOfMemory(String)
    case pixelBufferCreationFailed(CVReturn), requestCancelled(String), timeStampNotFound(String), timeout(String)
    case invalidArgument(String), invalidFormat(String), invalidImage(String), invalidModel(String), invalidOperation(String)
    case dataUnavailable(String), unsupportedComputeDevice(String), unsupportedComputeStage(String), unsupportedRequest(String)
    case unsupportedRevision(String)
    public var description: String {
        switch self {
        case .pixelBufferCreationFailed(let r): return "pixelBufferCreationFailed(\(r))"
        case .internalError(let m), .ioError(let m), .operationFailed(let m), .outOfBoundsError(let m), .outOfMemory(let m),
             .requestCancelled(let m), .timeStampNotFound(let m), .timeout(let m), .invalidArgument(let m), .invalidFormat(let m),
             .invalidImage(let m), .invalidModel(let m), .invalidOperation(let m), .dataUnavailable(let m), .unsupportedComputeDevice(let m),
             .unsupportedComputeStage(let m), .unsupportedRequest(let m), .unsupportedRevision(let m): return m
        }
    }
    /// the Swift error for one of the VN classes' errors
    static func _from(_ e: Error) -> VisionError {
        let n = e as NSError
        let m = (n.userInfo[NSLocalizedDescriptionKey] as? String) ?? "\(e)"
        guard n.domain == VNErrorDomain, let code = VNErrorCode(rawValue: n.code) else { return .operationFailed(m) }
        switch code {
        case .requestCancelled: return .requestCancelled(m)
        case .invalidFormat: return .invalidFormat(m)
        case .outOfBoundsError: return .outOfBoundsError(m)
        case .ioError: return .ioError(m)
        case .internalError: return .internalError(m)
        case .outOfMemory: return .outOfMemory(m)
        case .invalidOperation: return .invalidOperation(m)
        case .invalidImage: return .invalidImage(m)
        case .invalidArgument, .invalidOption, .missingOption: return .invalidArgument(m)
        case .invalidModel: return .invalidModel(m)
        case .unsupportedRevision: return .unsupportedRevision(m)
        case .dataUnavailable: return .dataUnavailable(m)
        case .timeStampNotFound: return .timeStampNotFound(m)
        case .timeout: return .timeout(m)
        case .unsupportedRequest, .notImplemented: return .unsupportedRequest(m)
        case .unsupportedComputeStage: return .unsupportedComputeStage(m)
        case .unsupportedComputeDevice: return .unsupportedComputeDevice(m)
        default: return .operationFailed(m)
        }
    }
}

public enum ComputeStage: Hashable, Sendable { case main, postProcessing }

/// Which request (and revision) made an observation.
public enum RequestDescriptor: Hashable, Sendable, CustomStringConvertible {
    case recognizeTextRequest(RecognizeTextRequest.Revision)
    case detectBarcodesRequest(DetectBarcodesRequest.Revision)
    case detectFaceRectanglesRequest(DetectFaceRectanglesRequest.Revision)
    case recognizeDocumentsRequest(RecognizeDocumentsRequest.Revision)
    public var description: String {
        switch self {
        case .recognizeTextRequest(let r): return "RecognizeTextRequest(\(r))"
        case .detectBarcodesRequest(let r): return "DetectBarcodesRequest(\(r))"
        case .detectFaceRectanglesRequest(let r): return "DetectFaceRectanglesRequest(\(r))"
        case .recognizeDocumentsRequest(let r): return "RecognizeDocumentsRequest(\(r))"
        }
    }
}

// MARK: - requests and observations

public protocol VisionObservation: Hashable, Sendable, CustomStringConvertible {
    var uuid: UUID { get }
    var confidence: Float { get }
    var timeRange: CMTimeRange? { get }
    var originatingRequestDescriptor: RequestDescriptor? { get }
}

public protocol VisionRequest: Hashable, Sendable, CustomStringConvertible {
    associatedtype Result
    var descriptor: RequestDescriptor { get }
}

/// Requests that analyse one image; `perform(on:)` makes the handler.
public protocol ImageProcessingRequest: VisionRequest {
    var regionOfInterest: NormalizedRect { get set }
}
extension ImageProcessingRequest {
    public func perform(on image: CGImage, orientation: CGImagePropertyOrientation? = nil) async throws -> Result {
        try await ImageRequestHandler(image, orientation: orientation).perform(self)
    }
    public func perform(on image: CIImage, orientation: CGImagePropertyOrientation? = nil) async throws -> Result {
        try await ImageRequestHandler(image, orientation: orientation).perform(self)
    }
    public func perform(on pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation? = nil) async throws -> Result {
        try await ImageRequestHandler(pixelBuffer, orientation: orientation).perform(self)
    }
    public func perform(on sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation? = nil) async throws -> Result {
        try await ImageRequestHandler(sampleBuffer, orientation: orientation).perform(self)
    }
    public func perform(on url: URL, orientation: CGImagePropertyOrientation? = nil) async throws -> Result {
        try await ImageRequestHandler(url, orientation: orientation).perform(self)
    }
    public func perform(on data: Data, orientation: CGImagePropertyOrientation? = nil) async throws -> Result {
        try await ImageRequestHandler(data, orientation: orientation).perform(self)
    }
}

/// What the Swift requests do on a handler's image (internal).
protocol _VNSwiftRequest {
    func _run(_ handler: VNImageRequestHandler) throws -> Any
    func _result(_ value: Any?, _ error: Error?) -> VisionResult
}
extension _VNSwiftRequest {
    /// runs a VN request (cropped to the region of interest) and returns its observations
    func _vn<R: VNImageBasedRequest>(_ r: R, _ roi: NormalizedRect, _ handler: VNImageRequestHandler) throws -> [VNObservation] {
        r.regionOfInterest = roi.cgRect
        do { try handler.perform([r]) } catch { throw VisionError._from(error) }
        return r.results ?? []
    }
}

/// A request's result, from ImageRequestHandler.performAll.
public enum VisionResult: Sendable {
    case recognizeText(RecognizeTextRequest, [RecognizedTextObservation])
    case detectBarcodes(DetectBarcodesRequest, [BarcodeObservation])
    case detectFaceRectangles(DetectFaceRectanglesRequest, [FaceObservation])
    case recognizeDocuments(RecognizeDocumentsRequest, [DocumentObservation])
    case error(any VisionRequest, any Error)
}

public struct RectangleObservation: VisionObservation, QuadrilateralProviding {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let topLeft: NormalizedPoint, topRight: NormalizedPoint, bottomRight: NormalizedPoint, bottomLeft: NormalizedPoint
    public init(topLeft: NormalizedPoint, topRight: NormalizedPoint, bottomRight: NormalizedPoint, bottomLeft: NormalizedPoint) {
        uuid = UUID(); confidence = 1; timeRange = nil; originatingRequestDescriptor = nil
        self.topLeft = topLeft; self.topRight = topRight; self.bottomRight = bottomRight; self.bottomLeft = bottomLeft
    }
    public init(_ o: VNRectangleObservation) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = nil
        topLeft = NormalizedPoint(normalizedPoint: o.topLeft); topRight = NormalizedPoint(normalizedPoint: o.topRight)
        bottomRight = NormalizedPoint(normalizedPoint: o.bottomRight); bottomLeft = NormalizedPoint(normalizedPoint: o.bottomLeft)
    }
    public var description: String { "RectangleObservation(\(boundingBox))" }
}

// MARK: text

public struct RecognizedText: Hashable, Sendable {
    public var string: String
    public var confidence: Float
    let _ranges: [_Range]
    struct _Range: Hashable, Sendable { let lower: Int, upper: Int, box: CGRect }
    init(_ t: VNRecognizedText) {
        string = t.string; confidence = t.confidence
        _ranges = t._ranges.map { _Range(lower: $0.0.lowerBound.utf16Offset(in: t.string), upper: $0.0.upperBound.utf16Offset(in: t.string), box: $0.1) }
    }
    /// the box of the words overlapping `range`
    public func boundingBox(for range: Range<String.Index>) -> RectangleObservation? {
        let lo = range.lowerBound.utf16Offset(in: string), hi = range.upperBound.utf16Offset(in: string)
        let boxes = _ranges.filter { $0.lower < hi && lo < $0.upper }.map(\.box)
        guard let first = boxes.first else { return nil }
        return RectangleObservation(VNRectangleObservation(boundingBox: boxes.dropFirst().reduce(first) { $0.union($1) }))
    }
}

public struct RecognizedTextObservation: VisionObservation, QuadrilateralProviding {
    public enum Direction: Hashable, Sendable { case leftToRight, rightToLeft, topToBottom }
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let topLeft: NormalizedPoint, topRight: NormalizedPoint, bottomRight: NormalizedPoint, bottomLeft: NormalizedPoint
    /// isim: no title detection (false)
    public let isTitle: Bool
    public let recognitionLanguages: [Locale.Language]
    public let shouldWrapToNextLine: Bool?
    public let textDirection: Direction?
    let _candidates: [RecognizedText]
    public init(_ o: VNRecognizedTextObservation) { self.init(o, descriptor: nil, languages: []) }
    init(_ o: VNRecognizedTextObservation, descriptor: RequestDescriptor?, languages: [Locale.Language]) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        topLeft = NormalizedPoint(normalizedPoint: o.topLeft); topRight = NormalizedPoint(normalizedPoint: o.topRight)
        bottomRight = NormalizedPoint(normalizedPoint: o.bottomRight); bottomLeft = NormalizedPoint(normalizedPoint: o.bottomLeft)
        isTitle = false; recognitionLanguages = languages; shouldWrapToNextLine = nil; textDirection = .leftToRight
        _candidates = o.topCandidates(10).map(RecognizedText.init)
    }
    /// the best candidate's string
    public var transcript: String { _candidates.first?.string ?? "" }
    public func topCandidates(_ maxCandidateCount: Int) -> [RecognizedText] { Array(_candidates.prefix(max(0, maxCandidateCount))) }
    public var description: String { "RecognizedTextObservation(\"\(transcript)\" \(boundingBox))" }
}

public struct RecognizeTextRequest: ImageProcessingRequest, _VNSwiftRequest {
    public enum Revision: Hashable, Sendable, Comparable { case revision3 }
    public enum RecognitionLevel: Hashable, Sendable { case accurate, fast }
    public typealias Result = [RecognizedTextObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision3]
    public var recognitionLevel: RecognitionLevel = .accurate
    public var recognitionLanguages: [Locale.Language] = [Locale.Language(identifier: "en-US")]
    public var usesLanguageCorrection = true
    public var automaticallyDetectsLanguage = false
    public var customWords: [String] = []
    /// the smallest text, as a fraction of the image's height (isim passes it on; tesseract finds what it finds)
    public var minimumTextHeightFraction: Float = 1.0 / 32
    public var regionOfInterest: NormalizedRect = .fullImage
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision3 }
    /// the languages of the host's tesseract data (empty without tesseract)
    public var supportedRecognitionLanguages: [Locale.Language] {
        ((try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? []).map { Locale.Language(identifier: $0) }
    }
    public var descriptor: RequestDescriptor { .recognizeTextRequest(revision) }
    public var description: String { "RecognizeTextRequest(\(revision))" }
    func _vnRequest() -> VNRecognizeTextRequest {
        let r = VNRecognizeTextRequest()
        r.recognitionLevel = recognitionLevel == .fast ? .fast : .accurate
        r.recognitionLanguages = recognitionLanguages.map(\.minimalIdentifier)
        r.usesLanguageCorrection = usesLanguageCorrection
        r.automaticallyDetectsLanguage = automaticallyDetectsLanguage
        r.customWords = customWords
        r.minimumTextHeight = minimumTextHeightFraction
        return r
    }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        try _vn(_vnRequest(), regionOfInterest, handler).compactMap { ($0 as? VNRecognizedTextObservation).map { RecognizedTextObservation($0, descriptor: descriptor, languages: recognitionLanguages) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .recognizeText(self, value as? [RecognizedTextObservation] ?? [])
    }
}

// MARK: barcodes

public enum BarcodeSymbology: Hashable, Sendable, CaseIterable {
    case aztec, codabar, code128, code39, code39Checksum, code39FullASCII, code39FullASCIIChecksum, code93, code93i, dataMatrix
    case ean13, ean8, gs1DataBar, gs1DataBarExpanded, gs1DataBarLimited, i2of5, i2of5Checksum, itf14, microPDF417, microQR
    case msiPlessey, pdf417, qr, upce
    /// the VN symbology (VNBarcodeSymbology + Apple's capitalized name)
    var _vn: VNBarcodeSymbology {
        let names: [BarcodeSymbology: String] = [
            .aztec: "Aztec", .codabar: "Codabar", .code128: "Code128", .code39: "Code39", .code39Checksum: "Code39Checksum",
            .code39FullASCII: "Code39FullASCII", .code39FullASCIIChecksum: "Code39FullASCIIChecksum", .code93: "Code93", .code93i: "Code93i",
            .dataMatrix: "DataMatrix", .ean13: "EAN13", .ean8: "EAN8", .gs1DataBar: "GS1DataBar", .gs1DataBarExpanded: "GS1DataBarExpanded",
            .gs1DataBarLimited: "GS1DataBarLimited", .i2of5: "I2of5", .i2of5Checksum: "I2of5Checksum", .itf14: "ITF14",
            .microPDF417: "MicroPDF417", .microQR: "MicroQR", .msiPlessey: "MSIPlessey", .pdf417: "PDF417", .qr: "QR", .upce: "UPCE"]
        return VNBarcodeSymbology(rawValue: "VNBarcodeSymbology" + names[self]!)
    }
    init?(_ vn: VNBarcodeSymbology) {
        guard let s = BarcodeSymbology.allCases.first(where: { $0._vn == vn }) else { return nil }
        self = s
    }
}

public struct BarcodeObservation: VisionObservation, QuadrilateralProviding {
    public enum CompositeType: Hashable, Sendable { case gs1TypeA, gs1TypeB, gs1TypeC, linked }
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let topLeft: NormalizedPoint, topRight: NormalizedPoint, bottomRight: NormalizedPoint, bottomLeft: NormalizedPoint
    public let symbology: BarcodeSymbology
    public let payloadString: String?
    public let payloadData: Data?
    public let isColorInverted: Bool
    public let isGS1DataCarrier: Bool
    public let supplementalPayloadString: String?
    public let supplementalPayloadData: Data?
    public let supplementalCompositeType: CompositeType?
    public init(_ o: VNBarcodeObservation) { self.init(o, descriptor: nil) }
    init(_ o: VNBarcodeObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        topLeft = NormalizedPoint(normalizedPoint: o.topLeft); topRight = NormalizedPoint(normalizedPoint: o.topRight)
        bottomRight = NormalizedPoint(normalizedPoint: o.bottomRight); bottomLeft = NormalizedPoint(normalizedPoint: o.bottomLeft)
        symbology = BarcodeSymbology(o.symbology) ?? .qr
        payloadString = o.payloadStringValue; payloadData = o.payloadData
        isColorInverted = o.isColorInverted; isGS1DataCarrier = o.isGS1DataCarrier
        supplementalPayloadString = o.supplementalPayloadString; supplementalPayloadData = nil; supplementalCompositeType = nil
    }
    public var description: String { "BarcodeObservation(\(symbology) \"\(payloadString ?? "")\" \(boundingBox))" }
}

public struct DetectBarcodesRequest: ImageProcessingRequest, _VNSwiftRequest {
    public enum Revision: Hashable, Sendable, Comparable { case revision4 }
    public typealias Result = [BarcodeObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision4]
    /// what to look for (all the host's readers can read by default)
    public var symbologies: [BarcodeSymbology] = BarcodeSymbology.allCases.filter { VNBarcodeSymbology.hostSupported.contains($0._vn) }
    public var coalescesCompositeSymbologies = false
    public var regionOfInterest: NormalizedRect = .fullImage
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision4 }
    /// the symbologies the host's zbar / zxing-cpp can read (empty without them)
    public var supportedSymbologies: [BarcodeSymbology] {
        VNBarcodeSymbology.available ? BarcodeSymbology.allCases.filter { VNBarcodeSymbology.hostSupported.contains($0._vn) } : []
    }
    public var descriptor: RequestDescriptor { .detectBarcodesRequest(revision) }
    public var description: String { "DetectBarcodesRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectBarcodesRequest()
        r.symbologies = symbologies.map(\._vn)
        r.coalesceCompositeSymbologies = coalescesCompositeSymbologies
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNBarcodeObservation).map { BarcodeObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectBarcodes(self, value as? [BarcodeObservation] ?? [])
    }
}

// MARK: faces

public struct FaceObservation: VisionObservation, BoundingBoxProviding {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let boundingBox: NormalizedRect
    /// from the eye line; isim measures no yaw or pitch (zero)
    public let roll: Measurement<UnitAngle>
    public let yaw: Measurement<UnitAngle>
    public let pitch: Measurement<UnitAngle>
    public init(boundingBox: NormalizedRect, revision: DetectFaceRectanglesRequest.Revision? = nil) {
        uuid = UUID(); confidence = 1; timeRange = nil
        originatingRequestDescriptor = .detectFaceRectanglesRequest(revision ?? .revision3)
        self.boundingBox = boundingBox
        roll = Measurement(value: 0, unit: .radians); yaw = roll; pitch = roll
    }
    public init(_ o: VNFaceObservation) { self.init(o, descriptor: nil) }
    init(_ o: VNFaceObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        boundingBox = NormalizedRect(normalizedRect: o.boundingBox)
        roll = Measurement(value: o.roll?.doubleValue ?? 0, unit: .radians)
        yaw = Measurement(value: o.yaw?.doubleValue ?? 0, unit: .radians)
        pitch = Measurement(value: o.pitch?.doubleValue ?? 0, unit: .radians)
    }
    public var description: String { "FaceObservation(\(boundingBox))" }
}

public struct DetectFaceRectanglesRequest: ImageProcessingRequest, _VNSwiftRequest {
    public enum Revision: Hashable, Sendable, Comparable { case revision3, revision4 }
    public typealias Result = [FaceObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision3, .revision4]
    public var regionOfInterest: NormalizedRect = .fullImage
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision3 }
    public var descriptor: RequestDescriptor { .detectFaceRectanglesRequest(revision) }
    public var description: String { "DetectFaceRectanglesRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        try _vn(VNDetectFaceRectanglesRequest(), regionOfInterest, handler).compactMap { ($0 as? VNFaceObservation).map { FaceObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectFaceRectangles(self, value as? [FaceObservation] ?? [])
    }
}

// MARK: documents

public struct DocumentObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let document: Container
    public var description: String { "DocumentObservation(\(document.paragraphs.count) paragraphs)" }

    /// A region of the document and what it holds.
    public struct Container: Hashable, Sendable {
        /// all the text, in reading order
        public var text: Text
        /// isim: the first paragraph when its lines are clearly taller than the rest
        public var title: Text?
        public var paragraphs: [Text]
        /// isim: no list detection (empty)
        public var lists: [List]
        /// isim: no table detection (empty)
        public var tables: [Table]
        public var barcodes: [BarcodeObservation]

        public struct Text: Hashable, Sendable {
            public enum Alignment: Hashable, Sendable { case leading, center, trailing }
            public var lines: [RecognizedTextObservation]
            /// isim: lines only (nil)
            public var words: [RecognizedTextObservation]?
            public var transcript: String
            public var textAlignment: Alignment?
            /// the box of the lines overlapping `range` of the transcript (as a rectangle)
            public func boundingRegion(for range: Range<String.Index>) -> RectangleObservation? {
                var offset = 0, boxes: [NormalizedRect] = []
                let lo = range.lowerBound.utf16Offset(in: transcript), hi = range.upperBound.utf16Offset(in: transcript)
                for l in lines {
                    let n = l.transcript.utf16.count
                    if offset < hi && lo < offset + n { boxes.append(l.boundingBox) }
                    offset += n + 1
                }
                guard let f = boxes.first else { return nil }
                let u = boxes.dropFirst().reduce(f.cgRect) { $0.union($1.cgRect) }
                return RectangleObservation(topLeft: NormalizedPoint(x: u.minX, y: u.maxY), topRight: NormalizedPoint(x: u.maxX, y: u.maxY),
                                            bottomRight: NormalizedPoint(x: u.maxX, y: u.minY), bottomLeft: NormalizedPoint(x: u.minX, y: u.minY))
            }
            init(_ lines: [RecognizedTextObservation]) {
                self.lines = lines; words = nil
                transcript = lines.map(\.transcript).joined(separator: "\n")
                textAlignment = nil
            }
        }
        public struct List: Hashable, Sendable {
            public enum Marker: Hashable, Sendable { case bullet, compositeDecimal, decimal, decorativeDecimal, hyphen, lowercaseLatin, uppercaseLatin }
            public struct Item: Hashable, Sendable {
                public var content: Container
                public var itemString: String
                public var markerString: String
                public var markerType: Marker?
            }
            public var items: [Item]
        }
        public struct Table: Hashable, Sendable {
            public struct Cell: Hashable, Sendable {
                public var content: Container
                public var rowRange: ClosedRange<Int>
                public var columnRange: ClosedRange<Int>
            }
            public var rows: [[Cell]]
            public var columns: [[Cell]]
            public func cell(row: Int, col: Int) -> Cell? {
                rows.joined().first { $0.rowRange.contains(row) && $0.columnRange.contains(col) }
            }
        }
    }
}

public struct RecognizeDocumentsRequest: ImageProcessingRequest, _VNSwiftRequest {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [DocumentObservation]
    public struct TextRecognitionOptions: Hashable, Sendable {
        public var recognitionLanguages: [Locale.Language] = [Locale.Language(identifier: "en-US")]
        public var automaticallyDetectLanguage = false
        public var useLanguageCorrection = true
        public var customWords: [String] = []
        public var minimumTextHeightFraction: Float = 1.0 / 32
        public var maximumCandidateCount = 1
    }
    public struct BarcodeDetectionOptions: Hashable, Sendable {
        public var enabled = true
        public var symbologies: [BarcodeSymbology] = DetectBarcodesRequest().symbologies
        public var coalesceCompositeSymbologies = false
    }
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var textRecognitionOptions = TextRecognitionOptions()
    public var barcodeDetectionOptions = BarcodeDetectionOptions()
    public var regionOfInterest: NormalizedRect = .fullImage
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    public var supportedRecognitionLanguages: [Locale.Language] { RecognizeTextRequest().supportedRecognitionLanguages }
    public var supportedBarcodeSymbologies: [BarcodeSymbology] { DetectBarcodesRequest().supportedSymbologies }
    public var descriptor: RequestDescriptor { .recognizeDocumentsRequest(revision) }
    public var description: String { "RecognizeDocumentsRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        var text = RecognizeTextRequest()
        text.recognitionLanguages = textRecognitionOptions.recognitionLanguages
        text.automaticallyDetectsLanguage = textRecognitionOptions.automaticallyDetectLanguage
        text.usesLanguageCorrection = textRecognitionOptions.useLanguageCorrection
        text.customWords = textRecognitionOptions.customWords
        text.minimumTextHeightFraction = textRecognitionOptions.minimumTextHeightFraction
        text.regionOfInterest = regionOfInterest
        let lines = (try text._run(handler) as? [RecognizedTextObservation] ?? [])
            .sorted { $0.boundingBox.origin.y + $0.boundingBox.height > $1.boundingBox.origin.y + $1.boundingBox.height }
        var barcodes: [BarcodeObservation] = []
        if barcodeDetectionOptions.enabled && VNBarcodeSymbology.available {
            var b = DetectBarcodesRequest()
            b.symbologies = barcodeDetectionOptions.symbologies
            b.coalescesCompositeSymbologies = barcodeDetectionOptions.coalesceCompositeSymbologies
            b.regionOfInterest = regionOfInterest
            barcodes = try b._run(handler) as? [BarcodeObservation] ?? []
        }
        /* paragraphs: lines (top to bottom) apart by less than their height */
        var paragraphs: [[RecognizedTextObservation]] = []
        for l in lines {
            if let last = paragraphs.last?.last, last.boundingBox.origin.y - (l.boundingBox.origin.y + l.boundingBox.height) < max(last.boundingBox.height, l.boundingBox.height) {
                paragraphs[paragraphs.count - 1].append(l)
            } else { paragraphs.append([l]) }
        }
        let heights = lines.map(\.boundingBox.height).sorted()
        let median = heights.isEmpty ? 0 : heights[heights.count / 2]
        let title = paragraphs.count > 1 && (paragraphs[0].map(\.boundingBox.height).min() ?? 0) > median * 1.3 ? Container.Text(paragraphs[0]) : nil
        typealias Container = DocumentObservation.Container
        let container = Container(text: Container.Text(lines), title: title, paragraphs: paragraphs.map(Container.Text.init),
                                  lists: [], tables: [], barcodes: barcodes)
        guard !lines.isEmpty || !barcodes.isEmpty else { return [DocumentObservation]() }
        let confidence = lines.isEmpty ? 1 : lines.map(\.confidence).reduce(0, +) / Float(lines.count)
        return [DocumentObservation(uuid: UUID(), confidence: confidence, timeRange: nil, originatingRequestDescriptor: descriptor, document: container)]
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .recognizeDocuments(self, value as? [DocumentObservation] ?? [])
    }
}

// MARK: - the handler

/// Performs Swift requests on one image (adapted: synchronously, on the caller's task).
public final class ImageRequestHandler: @unchecked Sendable {
    let _make: () -> VNImageRequestHandler
    init(_ make: @escaping () -> VNImageRequestHandler) { _make = make }
    public convenience init(_ image: CGImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init { VNImageRequestHandler(cgImage: image, orientation: orientation ?? .up) }
    }
    public convenience init(_ image: CIImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init { VNImageRequestHandler(ciImage: image, orientation: orientation ?? .up) }
    }
    public convenience init(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation? = nil) {
        self.init { VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation ?? .up) }
    }
    public convenience init(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation? = nil) {
        self.init { VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: orientation ?? .up) }
    }
    public convenience init(_ url: URL, orientation: CGImagePropertyOrientation? = nil) {
        self.init { VNImageRequestHandler(url: url, orientation: orientation ?? .up) }
    }
    public convenience init(_ data: Data, orientation: CGImagePropertyOrientation? = nil) {
        self.init { VNImageRequestHandler(data: data, orientation: orientation ?? .up) }
    }
    /// the image's handler, made (and read) once per call
    func _handler() -> VNImageRequestHandler { _make() }
    func _run<T: VisionRequest>(_ request: T, _ h: VNImageRequestHandler) throws -> T.Result {
        guard let r = request as? _VNSwiftRequest else { throw VisionError.unsupportedRequest("\(request) is not supported on isim") }
        guard let v = try r._run(h) as? T.Result else { throw VisionError.internalError("\(request): unexpected result") }
        return v
    }
    public func perform<T: VisionRequest>(_ request: T) async throws -> T.Result {
        try _run(request, _handler())
    }
    public func perform<each T: VisionRequest>(_ request: repeat each T) async throws -> (repeat (each T).Result) {
        let h = _handler()
        return (repeat try _run(each request, h))
    }
    /// each request's result as it finishes (here: in order)
    @available(iOS 18.0, *)
    public func performAll(_ requests: some Collection<any VisionRequest>) -> some AsyncSequence<VisionResult, Never> {
        let h = _handler()
        let results: [VisionResult] = requests.map { request in
            guard let r = request as? _VNSwiftRequest else { return .error(request, VisionError.unsupportedRequest("\(request) is not supported on isim")) }
            do { return r._result(try r._run(h), nil) } catch { return r._result(nil, error) }
        }
        return AsyncStream<VisionResult> { c in
            for r in results { c.yield(r) }
            c.finish()
        }
    }
}
