// isim Vision: the Objective-C interface (sdk-src/Frameworks/Vision, issue #537). The classes are @objc(VN…) and
// @objcMembers, so what Objective-C can represent is exported under Apple's names; the members below are internal
// Objective-C entry points, under Apple's selectors, for what uses Swift-only types (option dictionaries, symbology
// structs, CVPixelBufferRef, NSRange, C point arrays). CMTimeRange and the class factories are in
// frameworks/Vision/Vision.m. No CMSampleBufferRef: isim's CoreMedia has no C sample buffers.
import UIKit
import CoreImage

private func _vnOrientation(_ raw: UInt32) -> CGImagePropertyOrientation { CGImagePropertyOrientation(rawValue: raw) ?? .up }
private func _buffer(_ p: UnsafeMutableRawPointer) -> CVPixelBuffer { Unmanaged<CVBuffer>.fromOpaque(p).takeUnretainedValue() }

extension VNImageRequestHandler {
    @objc(initWithCGImage:options:) convenience init(_objcCGImage image: CGImage, options: NSDictionary?) {
        self.init(cgImage: image, orientation: .up)
    }
    @objc(initWithCGImage:orientation:options:) convenience init(_objcCGImage image: CGImage, orientation: UInt32, options: NSDictionary?) {
        self.init(cgImage: image, orientation: _vnOrientation(orientation))
    }
    @objc(initWithCVPixelBuffer:options:) convenience init(_objcPixelBuffer p: UnsafeMutableRawPointer, options: NSDictionary?) {
        self.init(cvPixelBuffer: _buffer(p), orientation: .up)
    }
    @objc(initWithCVPixelBuffer:orientation:options:) convenience init(_objcPixelBuffer p: UnsafeMutableRawPointer, orientation: UInt32, options: NSDictionary?) {
        self.init(cvPixelBuffer: _buffer(p), orientation: _vnOrientation(orientation))
    }
    @objc(initWithURL:options:) convenience init(_objcURL url: URL, options: NSDictionary?) { self.init(url: url, orientation: .up) }
    @objc(initWithURL:orientation:options:) convenience init(_objcURL url: URL, orientation: UInt32, options: NSDictionary?) {
        self.init(url: url, orientation: _vnOrientation(orientation))
    }
    @objc(initWithData:options:) convenience init(_objcData data: Data, options: NSDictionary?) { self.init(data: data, orientation: .up) }
    @objc(initWithData:orientation:options:) convenience init(_objcData data: Data, orientation: UInt32, options: NSDictionary?) {
        self.init(data: data, orientation: _vnOrientation(orientation))
    }
    @objc(initWithCIImage:options:) convenience init(_objcCIImage image: CIImage, options: NSDictionary?) { self.init(ciImage: image, orientation: .up) }
    @objc(initWithCIImage:orientation:options:) convenience init(_objcCIImage image: CIImage, orientation: UInt32, options: NSDictionary?) {
        self.init(ciImage: image, orientation: _vnOrientation(orientation))
    }
}

extension VNSequenceRequestHandler {
    @objc(performRequests:onCGImage:error:) func _objcPerform(_ requests: [VNRequest], onCGImage image: CGImage) throws {
        try perform(requests, on: image, orientation: .up)
    }
    @objc(performRequests:onCGImage:orientation:error:) func _objcPerform(_ requests: [VNRequest], onCGImage image: CGImage, orientation: UInt32) throws {
        try perform(requests, on: image, orientation: _vnOrientation(orientation))
    }
    @objc(performRequests:onCVPixelBuffer:error:) func _objcPerform(_ requests: [VNRequest], onCVPixelBuffer p: UnsafeMutableRawPointer) throws {
        try perform(requests, on: _buffer(p), orientation: .up)
    }
    @objc(performRequests:onCVPixelBuffer:orientation:error:)
    func _objcPerform(_ requests: [VNRequest], onCVPixelBuffer p: UnsafeMutableRawPointer, orientation: UInt32) throws {
        try perform(requests, on: _buffer(p), orientation: _vnOrientation(orientation))
    }
    @objc(performRequests:onCIImage:error:) func _objcPerform(_ requests: [VNRequest], onCIImage image: CIImage) throws {
        try VNImageRequestHandler(ciImage: image).perform(requests)
    }
    @objc(performRequests:onCIImage:orientation:error:) func _objcPerform(_ requests: [VNRequest], onCIImage image: CIImage, orientation: UInt32) throws {
        try VNImageRequestHandler(ciImage: image, orientation: _vnOrientation(orientation)).perform(requests)
    }
    @objc(performRequests:onImageURL:error:) func _objcPerform(_ requests: [VNRequest], onImageURL url: URL) throws {
        try VNImageRequestHandler(url: url).perform(requests)
    }
    @objc(performRequests:onImageURL:orientation:error:) func _objcPerform(_ requests: [VNRequest], onImageURL url: URL, orientation: UInt32) throws {
        try VNImageRequestHandler(url: url, orientation: _vnOrientation(orientation)).perform(requests)
    }
    @objc(performRequests:onImageData:error:) func _objcPerform(_ requests: [VNRequest], onImageData data: Data) throws {
        try VNImageRequestHandler(data: data).perform(requests)
    }
    @objc(performRequests:onImageData:orientation:error:) func _objcPerform(_ requests: [VNRequest], onImageData data: Data, orientation: UInt32) throws {
        try VNImageRequestHandler(data: data, orientation: _vnOrientation(orientation)).perform(requests)
    }
}

extension VNDetectBarcodesRequest {
    @objc(symbologies) var _objcSymbologies: [String] {
        get { symbologies.map(\.rawValue) }
        set { symbologies = newValue.map(VNBarcodeSymbology.init(rawValue:)) }
    }
    @objc(supportedSymbologies) class var _objcSupportedSymbologies: [String] { supportedSymbologies.map(\.rawValue) }
    @objc(supportedSymbologiesAndReturnError:) func _objcSupportedSymbologyNames() throws -> [String] { try supportedSymbologies().map(\.rawValue) }
}
extension VNRecognizeTextRequest {
    @objc(recognitionLevel) var _objcRecognitionLevel: Int {
        get { recognitionLevel.rawValue }
        set { recognitionLevel = VNRequestTextRecognitionLevel(rawValue: newValue) ?? .accurate }
    }
    @objc(supportedRecognitionLanguagesForTextRecognitionLevel:revision:error:)
    class func _objcSupportedRecognitionLanguages(level: Int, revision: Int) throws -> [String] {
        try supportedRecognitionLanguages(for: VNRequestTextRecognitionLevel(rawValue: level) ?? .accurate, revision: revision)
    }
}
extension VNBarcodeObservation {
    @objc(symbology) var _objcSymbology: String { symbology.rawValue }
}
extension VNRecognizedText {
    /// Objective-C ranges are UTF-16 offsets in `string`
    @objc(boundingBoxForRange:error:) func _objcBoundingBox(for range: NSRange) throws -> VNRectangleObservation {
        guard let r = Range(range, in: string) else { throw _vnError(.invalidArgument, "the range \(range) is outside the text") }
        guard let box = try boundingBox(for: r) else { throw _vnError(.dataUnavailable, "no box for the range \(range)") }
        return box
    }
}
extension VNObservation {
    /// CMTimeRange as numbers (start value, timescale, flags, epoch, then the duration's): Vision.m makes the C struct
    @objc(_isim_timeRange) var _objcTimeRange: [NSNumber] {
        let s = timeRange.start, d = timeRange.duration
        return [NSNumber(value: s.value), NSNumber(value: s.timescale), NSNumber(value: s.flags.rawValue), NSNumber(value: s.epoch),
                NSNumber(value: d.value), NSNumber(value: d.timescale), NSNumber(value: d.flags.rawValue), NSNumber(value: d.epoch)]
    }
}
extension VNPixelBufferObservation {
    @objc(pixelBuffer) var _objcPixelBuffer: UnsafeMutableRawPointer { Unmanaged.passUnretained(pixelBuffer).toOpaque() }
}
extension VNFaceLandmarkRegion2D {
    /// `const CGPoint *`, valid as long as the region
    @objc(normalizedPoints) var _objcNormalizedPoints: UnsafeRawPointer { UnsafeRawPointer(_cPoints(0, normalizedPoints)) }
    /// `const CGPoint *`, valid until the next call or the region goes away
    @objc(pointsInImageOfSize:) func _objcPointsInImage(ofSize imageSize: CGSize) -> UnsafeRawPointer {
        UnsafeRawPointer(_cPoints(1, pointsInImage(imageSize: imageSize)))
    }
}
extension VNContour {
    /// `const simd_float2 *`, valid as long as the contour
    @objc(normalizedPoints) var _objcNormalizedPoints: UnsafeRawPointer {
        _lock.lock(); defer { _lock.unlock() }
        if let p = _cPoints { return UnsafeRawPointer(p) }
        let p = UnsafeMutablePointer<SIMD2<Float>>.allocate(capacity: max(1, normalizedPoints.count))
        p.initialize(from: normalizedPoints, count: normalizedPoints.count)
        _cPoints = p
        return UnsafeRawPointer(p)
    }
}
extension VNCoreMLModel {
    @objc(modelForMLModel:error:) class func _objcModel(for model: MLModel) throws -> VNCoreMLModel { try VNCoreMLModel(for: model) }
}
