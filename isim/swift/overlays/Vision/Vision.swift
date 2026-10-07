// isim Vision (self-authored, iOS API names): VNImageRequestHandler / VNSequenceRequestHandler, the request and
// observation class hierarchy, and the requests isim can run with host tools:
//   - VNDetectBarcodesRequest: QR codes and 1D/2D barcodes through the host's libzbar (loaded only when used).
//     Adapted: zbar has no Aztec / Data Matrix / Micro QR readers; without zbar the request fails with a clear error.
//   - VNRecognizeTextRequest: the host's `tesseract` command (only when installed); line observations with their words'
//     confidence. Adapted: tesseract's language data, not Apple's models; .fast and .accurate run the same engine.
//   - VNDetectFaceRectanglesRequest, VNDetectFaceLandmarksRequest, VNCoreMLRequest, VNClassifyImageRequest,
//     VNGenerateImageFeaturePrintRequest, VNDetectHumanRectanglesRequest: no host backend; they fail with
//     VNError.unsupportedRequest and a message saying so (stub).
// Coordinates follow Vision: normalized to the image, origin at the lower left.
import UIKit
import CoreImage
@_exported import CoreML
@_exported import CoreMedia
@_exported import CoreVideo
import isim_host

public let VNErrorDomain = "com.apple.Vision"
@objc public enum VNErrorCode: Int, Sendable {
    case tuplesOutOfRange = 0, requestCancelled = 1, invalidFormat = 2, operationFailed = 3, outOfBoundsError = 4, invalidOption = 5,
         ioError = 6, missingOption = 7, notImplemented = 8, internalError = 9, outOfMemory = 10, unknownError = 11, invalidOperation = 12,
         invalidImage = 13, invalidArgument = 14, invalidModel = 15, unsupportedRevision = 16, dataUnavailable = 17, timeStampNotFound = 18,
         unsupportedRequest = 19, timeout = 20, unsupportedComputeStage = 21, unsupportedComputeDevice = 22
}
/// Vision errors are NSErrors in VNErrorDomain with a VNErrorCode and a message saying what isim cannot do.
func _vnError(_ code: VNErrorCode, _ message: String) -> NSError {
    NSError(domain: VNErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
}

public struct VNImageOption: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let properties = VNImageOption(rawValue: "VNImageOptionProperties")
    public static let cameraIntrinsics = VNImageOption(rawValue: "VNImageOptionCameraIntrinsics")
    public static let ciContext = VNImageOption(rawValue: "VNImageOptionCIContext")
}

/// Pixels of the handler's image, top row first, premultiplied BGRA.
struct _VNImage {
    let width: Int, height: Int
    let bgra: [UInt8]
    static func from(cgImage: CGImage) -> _VNImage? {
        var r = CGRect.zero
        let h = isim_cg_image_handle(cgImage, &r)
        let w = Int(r.width), ht = Int(r.height)
        guard h > 0, w > 0, ht > 0 else { return nil }
        var px = [UInt8](repeating: 0, count: w * ht * 4)
        guard px.withUnsafeMutableBufferPointer({ isim_image_read_bgra(h, Int32(r.minX), Int32(r.minY), Int32(w), Int32(ht), $0.baseAddress!) }) != 0 else { return nil }
        return _VNImage(width: w, height: ht, bgra: px)
    }
    static func from(data: Data) -> _VNImage? {
        var w = 0.0, h = 0.0
        let hd = data.withUnsafeBytes { isim_image_load_data($0.baseAddress, UInt($0.count), &w, &h) }
        guard hd > 0 else { return nil }
        defer { isim_image_free(hd) }
        var px = [UInt8](repeating: 0, count: Int(w) * Int(h) * 4)
        guard px.withUnsafeMutableBufferPointer({ isim_image_read_bgra(hd, 0, 0, Int32(w), Int32(h), $0.baseAddress!) }) != 0 else { return nil }
        return _VNImage(width: Int(w), height: Int(h), bgra: px)
    }
    /// rotates/mirrors so that the image is upright (EXIF orientation of the source)
    func oriented(_ o: CGImagePropertyOrientation) -> _VNImage {
        if o == .up { return self }
        let swap = [CGImagePropertyOrientation.left, .leftMirrored, .right, .rightMirrored].contains(o)
        let W = swap ? height : width, H = swap ? width : height
        var out = [UInt8](repeating: 0, count: W * H * 4)
        for y in 0..<H {
            for x in 0..<W {
                var sx = x, sy = y
                switch o {
                case .upMirrored: sx = width - 1 - x
                case .down: sx = width - 1 - x; sy = height - 1 - y
                case .downMirrored: sy = height - 1 - y
                case .leftMirrored: sx = y; sy = x
                case .right: sx = y; sy = height - 1 - x
                case .rightMirrored: sx = width - 1 - y; sy = height - 1 - x
                case .left: sx = width - 1 - y; sy = x
                default: break
                }
                let s = (sy * width + sx) * 4, d = (y * W + x) * 4
                out[d] = bgra[s]; out[d + 1] = bgra[s + 1]; out[d + 2] = bgra[s + 2]; out[d + 3] = bgra[s + 3]
            }
        }
        return _VNImage(width: W, height: H, bgra: out)
    }
    /// crop to a normalized (lower-left origin) region of interest
    func cropped(_ roi: CGRect) -> (_VNImage, CGRect) {
        let full = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard roi != full, roi.width > 0, roi.height > 0 else { return (self, full) }
        let x0 = max(0, Int(roi.minX * Double(width))), x1 = min(width, Int((roi.maxX * Double(width)).rounded(.up)))
        let y0 = max(0, Int((1 - roi.maxY) * Double(height))), y1 = min(height, Int(((1 - roi.minY) * Double(height)).rounded(.up)))
        guard x1 > x0, y1 > y0 else { return (self, full) }
        var out = [UInt8](repeating: 0, count: (x1 - x0) * (y1 - y0) * 4)
        for y in y0..<y1 { for x in x0..<x1 { for k in 0..<4 { out[((y - y0) * (x1 - x0) + (x - x0)) * 4 + k] = bgra[(y * width + x) * 4 + k] } } }
        return (_VNImage(width: x1 - x0, height: y1 - y0, bgra: out), roi)
    }
}

// MARK: - requests

public typealias VNRequestCompletionHandler = (VNRequest, Error?) -> Void

open class VNRequest: NSObject, @unchecked Sendable {
    public let completionHandler: VNRequestCompletionHandler?
    open var results: [VNObservation]? { _results }
    var _results: [VNObservation]?
    open var preferBackgroundProcessing = false
    open var usesCPUOnly = false
    open var revision: Int = 1
    open class var supportedRevisions: IndexSet { IndexSet(integer: 1) }
    open class var defaultRevision: Int { 1 }
    open class var currentRevision: Int { 1 }
    var _cancelled = false
    public override init() { completionHandler = nil; super.init() }
    public init(completionHandler: VNRequestCompletionHandler?) { self.completionHandler = completionHandler; super.init() }
    open func cancel() { _cancelled = true }
    /// subclasses: runs on the (cropped, upright) image and returns observations in ROI-relative coordinates
    func _run(_ img: _VNImage) throws -> [VNObservation] { throw _vnError(.unsupportedRequest, "\(type(of: self)) is not supported on isim") }
}
open class VNImageBasedRequest: VNRequest, @unchecked Sendable {
    /// normalized, lower-left origin; results are relative to it (like iOS)
    open var regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
}

public struct VNBarcodeSymbology: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let aztec = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyAztec")
    public static let code39 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCode39")
    public static let code39Checksum = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCode39Checksum")
    public static let code39FullASCII = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCode39FullASCII")
    public static let code93 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCode93")
    public static let code128 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCode128")
    public static let dataMatrix = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyDataMatrix")
    public static let ean8 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyEAN8")
    public static let ean13 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyEAN13")
    public static let i2of5 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyI2of5")
    public static let i2of5Checksum = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyI2of5Checksum")
    public static let itf14 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyITF14")
    public static let pdf417 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyPDF417")
    public static let qr = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyQR")
    public static let upce = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyUPCE")
    public static let codabar = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCodabar")
    public static let gs1DataBar = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyGS1DataBar")
    public static let gs1DataBarExpanded = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyGS1DataBarExpanded")
    public static let gs1DataBarLimited = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyGS1DataBarLimited")
    public static let microPDF417 = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyMicroPDF417")
    public static let microQR = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyMicroQR")
    public static let msiPlessey = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyMSIPlessey")
    /// zbar symbology name -> Vision
    static let zbar: [String: VNBarcodeSymbology] = ["QR-Code": .qr, "EAN-13": .ean13, "EAN-8": .ean8, "UPC-E": .upce, "UPC-A": .ean13,
        "ISBN-13": .ean13, "ISBN-10": .ean13, "CODE-128": .code128, "CODE-39": .code39, "CODE-93": .code93, "I2/5": .i2of5,
        "Codabar": .codabar, "DataBar": .gs1DataBar, "DataBar-Exp": .gs1DataBarExpanded, "PDF417": .pdf417]
    static let hostSupported: [VNBarcodeSymbology] = [.qr, .ean13, .ean8, .upce, .code128, .code39, .code39Checksum, .code39FullASCII, .code93,
        .i2of5, .i2of5Checksum, .itf14, .codabar, .gs1DataBar, .gs1DataBarExpanded, .pdf417]
}

open class VNDetectBarcodesRequest: VNImageBasedRequest, @unchecked Sendable {
    open var symbologies: [VNBarcodeSymbology] = VNBarcodeSymbology.hostSupported
    open var coalesceCompositeSymbologies = false
    open class var supportedSymbologies: [VNBarcodeSymbology] { isim_vision_available(1) != 0 ? VNBarcodeSymbology.hostSupported : [] }
    open func supportedSymbologies() throws -> [VNBarcodeSymbology] {
        guard isim_vision_available(1) != 0 else { throw _vnError(.unsupportedRequest, "barcode detection on isim needs the host's zbar library (libzbar.so.0)") }
        return VNBarcodeSymbology.hostSupported
    }
    open override class var supportedRevisions: IndexSet { IndexSet(1...4) }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        guard isim_vision_available(1) != 0 else { throw _vnError(.unsupportedRequest, "barcode detection on isim needs the host's zbar library (libzbar.so.0)") }
        let gray = img.bgra
        guard let raw = gray.withUnsafeBufferPointer({ isim_vision_barcodes($0.baseAddress!, Int32(img.width), Int32(img.height), Int32(img.width * 4)) }) else { return [] }
        defer { isim_media_free(raw) }
        var out: [VNObservation] = []
        let w = Double(img.width), h = Double(img.height)
        for line in String(cString: raw).split(separator: "\n") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard f.count >= 4, let sym = VNBarcodeSymbology.zbar[String(f[0])] else { continue }
            let wanted = symbologies.contains(sym) || (sym == .ean13 && symbologies.contains(.upce))
            guard wanted else { continue }
            let pts = f[2].split(separator: ";").compactMap { p -> CGPoint? in
                let xy = p.split(separator: ",").compactMap { Double($0) }
                return xy.count == 2 ? CGPoint(x: xy[0] / w, y: 1 - xy[1] / h) : nil
            }
            guard !pts.isEmpty else { continue }
            var bytes: [UInt8] = []
            let hex = Array(f[3].utf8)
            var i = 0
            while i + 1 < hex.count { func v(_ c: UInt8) -> UInt8 { c >= 97 ? c - 87 : c - 48 }; bytes.append(v(hex[i]) << 4 | v(hex[i + 1])); i += 2 }
            let xs = pts.map(\.x), ys = pts.map(\.y)
            let box = CGRect(x: xs.min()!, y: ys.min()!, width: max(1 / w, xs.max()! - xs.min()!), height: max(1 / h, ys.max()! - ys.min()!))
            let o = VNBarcodeObservation(symbology: sym, payload: Data(bytes), boundingBox: box)
            if pts.count == 4 {        // zbar QR corners: top-left, bottom-left, bottom-right, top-right (image space)
                o._topLeft = pts[0]; o._bottomLeft = pts[1]; o._bottomRight = pts[2]; o._topRight = pts[3]
            }
            out.append(o)
        }
        return out
    }
}

public enum VNRequestTextRecognitionLevel: Int, Sendable { case accurate = 0, fast = 1 }
open class VNRecognizeTextRequest: VNImageBasedRequest, @unchecked Sendable {
    open var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    open var recognitionLanguages: [String] = ["en-US"]
    open var usesLanguageCorrection = true
    open var automaticallyDetectsLanguage = false
    open var minimumTextHeight: Float = 0
    open var customWords: [String] = []
    open override class var supportedRevisions: IndexSet { IndexSet(1...3) }
    /// ISO language codes -> tesseract traineddata names
    static let tess: [String: String] = ["en": "eng", "fr": "fra", "de": "deu", "es": "spa", "it": "ita", "pt": "por", "nl": "nld",
        "zh-Hans": "chi_sim", "zh-Hant": "chi_tra", "ja": "jpn", "ko": "kor", "ru": "rus", "uk": "ukr", "ar": "ara", "tr": "tur", "pl": "pol",
        "sv": "swe", "da": "dan", "nb": "nor", "fi": "fin", "cs": "ces", "el": "ell", "he": "heb", "hi": "hin", "th": "tha", "vi": "vie"]
    static func code(_ lang: String) -> String? {
        if let t = tess[lang] { return t }
        if lang.hasPrefix("zh") { return lang.contains("Hant") || lang.contains("TW") || lang.contains("HK") ? "chi_tra" : "chi_sim" }
        return tess[String(lang.prefix(2))]
    }
    open func supportedRecognitionLanguages() throws -> [String] {
        guard let raw = isim_vision_text_languages() else { throw _vnError(.unsupportedRequest, "text recognition on isim needs the host's tesseract command") }
        defer { isim_media_free(raw) }
        let installed = Set(String(cString: raw).split(separator: "\n").map(String.init))
        let names: [(String, String)] = [("en-US", "eng"), ("fr-FR", "fra"), ("de-DE", "deu"), ("es-ES", "spa"), ("it-IT", "ita"), ("pt-BR", "por"),
            ("nl-NL", "nld"), ("zh-Hans", "chi_sim"), ("zh-Hant", "chi_tra"), ("ja-JP", "jpn"), ("ko-KR", "kor"), ("ru-RU", "rus"), ("uk-UA", "ukr"),
            ("ar-SA", "ara"), ("tr-TR", "tur"), ("pl-PL", "pol"), ("sv-SE", "swe"), ("da-DK", "dan"), ("nb-NO", "nor"), ("vi-VT", "vie"), ("th-TH", "tha")]
        return names.filter { installed.contains($0.1) }.map(\.0)
    }
    open class func supportedRecognitionLanguages(for level: VNRequestTextRecognitionLevel, revision: Int) throws -> [String] {
        try VNRecognizeTextRequest().supportedRecognitionLanguages()
    }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        guard isim_vision_available(2) != 0 else { throw _vnError(.unsupportedRequest, "text recognition on isim needs the host's tesseract command (not installed)") }
        let langs = recognitionLanguages.compactMap(VNRecognizeTextRequest.code)
        let l = (langs.isEmpty ? ["eng"] : langs).joined(separator: "+")
        guard let raw = img.bgra.withUnsafeBufferPointer({ isim_vision_text($0.baseAddress!, Int32(img.width), Int32(img.height), Int32(img.width * 4), l) }) else {
            throw _vnError(.operationFailed, "tesseract failed (is the language data for \(l) installed?)")
        }
        defer { isim_media_free(raw) }
        // TSV: level page block par line word left top width height conf text; group words (level 5) by line
        struct Word { let text: String; let conf: Double; let rect: CGRect }
        var lines: [String: [Word]] = [:], order: [String] = []
        for row in String(cString: raw).split(separator: "\n").dropFirst() {
            let c = row.split(separator: "\t", omittingEmptySubsequences: false)
            guard c.count >= 12, c[0] == "5", let conf = Double(c[10]), conf >= 0 else { continue }
            let text = c[11...].joined(separator: "\t").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, let x = Double(c[6]), let y = Double(c[7]), let w = Double(c[8]), let h = Double(c[9]) else { continue }
            if minimumTextHeight > 0 && h / Double(img.height) < Double(minimumTextHeight) { continue }
            let key = "\(c[2]).\(c[3]).\(c[4])"
            if lines[key] == nil { order.append(key) }
            lines[key, default: []].append(Word(text: text, conf: conf / 100, rect: CGRect(x: x, y: y, width: w, height: h)))
        }
        let W = Double(img.width), H = Double(img.height)
        func norm(_ r: CGRect) -> CGRect { CGRect(x: r.minX / W, y: 1 - r.maxY / H, width: r.width / W, height: r.height / H) }
        return order.compactMap { k in
            guard let words = lines[k], !words.isEmpty else { return nil }
            let rect = words.dropFirst().reduce(words[0].rect) { $0.union($1.rect) }
            let s = words.map(\.text).joined(separator: " ")
            let conf = words.map(\.conf).reduce(0, +) / Double(words.count)
            var ranges: [(Range<String.Index>, CGRect)] = []
            var idx = s.startIndex
            for w in words {
                if let r = s.range(of: w.text, range: idx..<s.endIndex) { ranges.append((r, norm(w.rect))); idx = r.upperBound }
            }
            return VNRecognizedTextObservation(text: VNRecognizedText(string: s, confidence: VNConfidence(conf), ranges: ranges), boundingBox: norm(rect))
        }
    }
}

/// Requests with no host backend on isim: they fail with VNError.unsupportedRequest.
open class VNDetectFaceRectanglesRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        throw _vnError(.unsupportedRequest, "face detection is not available on isim (no host face detector); \(type(of: self)) cannot run")
    }
}
open class VNDetectFaceLandmarksRequest: VNDetectFaceRectanglesRequest, @unchecked Sendable {
    open var inputFaceObservations: [VNFaceObservation]?
}
open class VNDetectFaceCaptureQualityRequest: VNDetectFaceRectanglesRequest, @unchecked Sendable {}
open class VNDetectHumanRectanglesRequest: VNImageBasedRequest, @unchecked Sendable {
    open var upperBodyOnly = true
    override func _run(_ img: _VNImage) throws -> [VNObservation] { throw _vnError(.unsupportedRequest, "human detection is not available on isim (no host detector)") }
}
open class VNClassifyImageRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] { throw _vnError(.unsupportedRequest, "image classification is not available on isim (it needs Apple's models)") }
}
open class VNGenerateImageFeaturePrintRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] { throw _vnError(.unsupportedRequest, "image feature prints are not available on isim (they need Apple's models)") }
}
open class VNDetectRectanglesRequest: VNImageBasedRequest, @unchecked Sendable {
    open var minimumAspectRatio: Float = 0.5
    open var maximumAspectRatio: Float = 1
    open var minimumSize: Float = 0.2
    open var maximumObservations = 1
    open var minimumConfidence: Float = 0
    override func _run(_ img: _VNImage) throws -> [VNObservation] { throw _vnError(.unsupportedRequest, "rectangle detection is not available on isim") }
}
open class VNCoreMLModel: NSObject, @unchecked Sendable {
    let _model: MLModel
    open var inputImageFeatureName: String
    open var featureProvider: MLFeatureProvider?
    /// isim: wraps the model; VNCoreMLRequest cannot run it (image models need Apple's runtime).
    public init(for model: MLModel) throws {
        _model = model
        inputImageFeatureName = model.modelDescription.inputDescriptionsByName.values.first { $0.type == .image }?.name ?? ""
        super.init()
    }
}
open class VNCoreMLFeatureValueObservation: VNObservation, @unchecked Sendable {
    public let featureValue: MLFeatureValue
    public let featureName: String
    init(featureValue: MLFeatureValue, featureName: String) { self.featureValue = featureValue; self.featureName = featureName; super.init() }
}
open class VNCoreMLRequest: VNImageBasedRequest, @unchecked Sendable {
    public let model: VNCoreMLModel
    @objc public enum ImageCropAndScaleOption: UInt, Sendable { case centerCrop = 0, scaleFit = 1, scaleFill = 2, scaleFitRotate90CCW = 0x101, scaleFillRotate90CCW = 0x102 }
    open var imageCropAndScaleOption: ImageCropAndScaleOption = .centerCrop
    public init(model: VNCoreMLModel) { self.model = model; super.init() }
    public init(model: VNCoreMLModel, completionHandler: VNRequestCompletionHandler?) { self.model = model; super.init(completionHandler: completionHandler) }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        throw _vnError(.unsupportedRequest, "VNCoreMLRequest cannot run on isim: image models need Apple's Core ML runtime")
    }
}

// MARK: - observations

public typealias VNConfidence = Float
open class VNObservation: NSObject, @unchecked Sendable {
    public let uuid = UUID()
    open var confidence: VNConfidence = 1
    open var timeRange: CMTimeRange = .zero
    open var requestRevision: Int { 1 }
}
open class VNDetectedObjectObservation: VNObservation, @unchecked Sendable {
    open var boundingBox: CGRect
    public init(boundingBox: CGRect) { self.boundingBox = boundingBox; super.init() }
    public override convenience init() { self.init(boundingBox: .zero) }
}
open class VNRectangleObservation: VNDetectedObjectObservation, @unchecked Sendable {
    var _topLeft: CGPoint?, _topRight: CGPoint?, _bottomLeft: CGPoint?, _bottomRight: CGPoint?
    open var topLeft: CGPoint { _topLeft ?? CGPoint(x: boundingBox.minX, y: boundingBox.maxY) }
    open var topRight: CGPoint { _topRight ?? CGPoint(x: boundingBox.maxX, y: boundingBox.maxY) }
    open var bottomLeft: CGPoint { _bottomLeft ?? CGPoint(x: boundingBox.minX, y: boundingBox.minY) }
    open var bottomRight: CGPoint { _bottomRight ?? CGPoint(x: boundingBox.maxX, y: boundingBox.minY) }
}
open class VNBarcodeObservation: VNRectangleObservation, @unchecked Sendable {
    public let symbology: VNBarcodeSymbology
    let _payload: Data
    init(symbology: VNBarcodeSymbology, payload: Data, boundingBox: CGRect) { self.symbology = symbology; _payload = payload; super.init(boundingBox: boundingBox) }
    open var payloadStringValue: String? { String(data: _payload, encoding: .utf8) ?? String(data: _payload, encoding: .isoLatin1) }
    open var payloadData: Data? { _payload }
    open var isGS1DataCarrier: Bool { false }
    open var isColorInverted: Bool { false }
    open var supplementalPayloadString: String? { nil }
}
open class VNTextObservation: VNRectangleObservation, @unchecked Sendable {
    open var characterBoxes: [VNRectangleObservation]? { nil }
}
open class VNRecognizedText: NSObject, @unchecked Sendable {
    public let string: String
    public let confidence: VNConfidence
    let _ranges: [(Range<String.Index>, CGRect)]
    init(string: String, confidence: VNConfidence, ranges: [(Range<String.Index>, CGRect)]) { self.string = string; self.confidence = confidence; _ranges = ranges }
    /// the box of the words overlapping `range`
    open func boundingBox(for range: Range<String.Index>) throws -> VNRectangleObservation? {
        let boxes = _ranges.filter { $0.0.overlaps(range) }.map(\.1)
        guard let first = boxes.first else { return nil }
        return VNRectangleObservation(boundingBox: boxes.dropFirst().reduce(first) { $0.union($1) })
    }
}
open class VNRecognizedTextObservation: VNTextObservation, @unchecked Sendable {
    let _text: VNRecognizedText
    init(text: VNRecognizedText, boundingBox: CGRect) { _text = text; super.init(boundingBox: boundingBox); confidence = text.confidence }
    /// isim: one candidate per line
    open func topCandidates(_ maxCandidateCount: Int) -> [VNRecognizedText] { maxCandidateCount > 0 ? [_text] : [] }
}
open class VNFaceObservation: VNDetectedObjectObservation, @unchecked Sendable {
    open var roll: NSNumber? { nil }
    open var yaw: NSNumber? { nil }
    open var pitch: NSNumber? { nil }
    open var faceCaptureQuality: NSNumber? { nil }
}
open class VNClassificationObservation: VNObservation, @unchecked Sendable {
    public let identifier: String
    public init(identifier: String, confidence: VNConfidence) { self.identifier = identifier; super.init(); self.confidence = confidence }
}
open class VNHumanObservation: VNDetectedObjectObservation, @unchecked Sendable {}

// MARK: - handlers

open class VNImageRequestHandler: NSObject, @unchecked Sendable {
    let _load: () -> _VNImage?
    let _orientation: CGImagePropertyOrientation
    public init(cgImage image: CGImage, orientation: CGImagePropertyOrientation = .up, options: [VNImageOption: Any] = [:]) {
        _load = { _VNImage.from(cgImage: image) }; _orientation = orientation
    }
    public convenience init(cgImage image: CGImage, options: [VNImageOption: Any] = [:]) { self.init(cgImage: image, orientation: .up, options: options) }
    public init(cvPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up, options: [VNImageOption: Any] = [:]) {
        _load = { _VNImage(width: pixelBuffer._width, height: pixelBuffer._height, bgra: pixelBuffer._bgra()) }; _orientation = orientation
    }
    public convenience init(cvPixelBuffer pixelBuffer: CVPixelBuffer, options: [VNImageOption: Any] = [:]) { self.init(cvPixelBuffer: pixelBuffer, orientation: .up, options: options) }
    public init(cmSampleBuffer sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation = .up, options: [VNImageOption: Any] = [:]) {
        _load = { sampleBuffer.imageBuffer.map { _VNImage(width: $0._width, height: $0._height, bgra: $0._bgra()) } }; _orientation = orientation
    }
    public init(url imageURL: URL, orientation: CGImagePropertyOrientation = .up, options: [VNImageOption: Any] = [:]) {
        _load = { (try? Data(contentsOf: imageURL)).flatMap(_VNImage.from(data:)) }; _orientation = orientation
    }
    public convenience init(url imageURL: URL, options: [VNImageOption: Any] = [:]) { self.init(url: imageURL, orientation: .up, options: options) }
    public init(data imageData: Data, orientation: CGImagePropertyOrientation = .up, options: [VNImageOption: Any] = [:]) {
        _load = { _VNImage.from(data: imageData) }; _orientation = orientation
    }
    public convenience init(data imageData: Data, options: [VNImageOption: Any] = [:]) { self.init(data: imageData, orientation: .up, options: options) }
    public init(ciImage image: CIImage, orientation: CGImagePropertyOrientation = .up, options: [VNImageOption: Any] = [:]) {
        _load = { CIContext().createCGImage(image, from: image.extent).flatMap(_VNImage.from(cgImage:)) }; _orientation = orientation
    }
    public convenience init(ciImage image: CIImage, options: [VNImageOption: Any] = [:]) { self.init(ciImage: image, orientation: .up, options: options) }

    /// Runs the requests in order (synchronously, like iOS), filling each request's results and calling its completion handler.
    /// Throws the first request's error.
    open func perform(_ requests: [VNRequest]) throws {
        guard let img0 = _load() else {
            let e = _vnError(.invalidImage, "the image could not be read")
            for r in requests { r._results = nil; r.completionHandler?(r, e) }
            throw e
        }
        let img = img0.oriented(_orientation)
        var first: Error?
        for r in requests {
            if r._cancelled { let e = _vnError(.requestCancelled, "the request was cancelled"); r.completionHandler?(r, e); first = first ?? e; continue }
            let roi = (r as? VNImageBasedRequest)?.regionOfInterest ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            do {
                let (crop, _) = img.cropped(roi)
                r._results = try r._run(crop)
                r.completionHandler?(r, nil)
            } catch {
                r._results = nil
                NSLog("isim Vision: %@", ((error as NSError).userInfo[NSLocalizedDescriptionKey] as? String) ?? "\(error)")
                r.completionHandler?(r, error)
                first = first ?? error
            }
        }
        if let first { throw first }
    }
}
open class VNSequenceRequestHandler: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open func perform(_ requests: [VNRequest], on image: CGImage, orientation: CGImagePropertyOrientation = .up) throws {
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform(requests)
    }
    open func perform(_ requests: [VNRequest], on pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) throws {
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation).perform(requests)
    }
    open func perform(_ requests: [VNRequest], on sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation = .up) throws {
        try VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: orientation).perform(requests)
    }
}

// MARK: - geometry helpers
public func VNImageRectForNormalizedRect(_ normalizedRect: CGRect, _ imageWidth: Int, _ imageHeight: Int) -> CGRect {
    CGRect(x: normalizedRect.minX * Double(imageWidth), y: normalizedRect.minY * Double(imageHeight),
           width: normalizedRect.width * Double(imageWidth), height: normalizedRect.height * Double(imageHeight))
}
public func VNNormalizedRectForImageRect(_ imageRect: CGRect, _ imageWidth: Int, _ imageHeight: Int) -> CGRect {
    CGRect(x: imageRect.minX / Double(imageWidth), y: imageRect.minY / Double(imageHeight),
           width: imageRect.width / Double(imageWidth), height: imageRect.height / Double(imageHeight))
}
public func VNImagePointForNormalizedPoint(_ normalizedPoint: CGPoint, _ imageWidth: Int, _ imageHeight: Int) -> CGPoint {
    CGPoint(x: normalizedPoint.x * Double(imageWidth), y: normalizedPoint.y * Double(imageHeight))
}
public func VNNormalizedPointForImagePoint(_ imagePoint: CGPoint, _ imageWidth: Int, _ imageHeight: Int) -> CGPoint {
    CGPoint(x: imagePoint.x / Double(imageWidth), y: imagePoint.y / Double(imageHeight))
}
public let VNNormalizedIdentityRect = CGRect(x: 0, y: 0, width: 1, height: 1)
public func VNNormalizedRectIsIdentityRect(_ r: CGRect) -> Bool { r == VNNormalizedIdentityRect }
