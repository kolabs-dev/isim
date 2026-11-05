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

// MARK: - tracking, registration and optical flow (issue #373)

extension VNTargetedImageRequest {
    @objc(initWithTargetedCGImage:options:) convenience init(_objcCGImage image: CGImage, options: NSDictionary?) {
        self.init(targetedCGImage: image, orientation: .up)
    }
    @objc(initWithTargetedCGImage:options:completionHandler:)
    convenience init(_objcCGImage image: CGImage, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedCGImage: image, orientation: .up, completionHandler: completionHandler)
    }
    @objc(initWithTargetedCGImage:orientation:options:) convenience init(_objcCGImage image: CGImage, orientation: UInt32, options: NSDictionary?) {
        self.init(targetedCGImage: image, orientation: _vnOrientation(orientation))
    }
    @objc(initWithTargetedCGImage:orientation:options:completionHandler:)
    convenience init(_objcCGImage image: CGImage, orientation: UInt32, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedCGImage: image, orientation: _vnOrientation(orientation), completionHandler: completionHandler)
    }
    @objc(initWithTargetedCIImage:options:) convenience init(_objcCIImage image: CIImage, options: NSDictionary?) {
        self.init(targetedCIImage: image, orientation: .up)
    }
    @objc(initWithTargetedCIImage:options:completionHandler:)
    convenience init(_objcCIImage image: CIImage, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedCIImage: image, orientation: .up, completionHandler: completionHandler)
    }
    @objc(initWithTargetedCIImage:orientation:options:) convenience init(_objcCIImage image: CIImage, orientation: UInt32, options: NSDictionary?) {
        self.init(targetedCIImage: image, orientation: _vnOrientation(orientation))
    }
    @objc(initWithTargetedCIImage:orientation:options:completionHandler:)
    convenience init(_objcCIImage image: CIImage, orientation: UInt32, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedCIImage: image, orientation: _vnOrientation(orientation), completionHandler: completionHandler)
    }
    @objc(initWithTargetedCVPixelBuffer:options:) convenience init(_objcPixelBuffer p: UnsafeMutableRawPointer, options: NSDictionary?) {
        self.init(targetedCVPixelBuffer: _buffer(p), orientation: .up)
    }
    @objc(initWithTargetedCVPixelBuffer:options:completionHandler:)
    convenience init(_objcPixelBuffer p: UnsafeMutableRawPointer, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedCVPixelBuffer: _buffer(p), orientation: .up, completionHandler: completionHandler)
    }
    @objc(initWithTargetedCVPixelBuffer:orientation:options:)
    convenience init(_objcPixelBuffer p: UnsafeMutableRawPointer, orientation: UInt32, options: NSDictionary?) {
        self.init(targetedCVPixelBuffer: _buffer(p), orientation: _vnOrientation(orientation))
    }
    @objc(initWithTargetedCVPixelBuffer:orientation:options:completionHandler:)
    convenience init(_objcPixelBuffer p: UnsafeMutableRawPointer, orientation: UInt32, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedCVPixelBuffer: _buffer(p), orientation: _vnOrientation(orientation), completionHandler: completionHandler)
    }
    @objc(initWithTargetedImageURL:options:) convenience init(_objcURL url: URL, options: NSDictionary?) {
        self.init(targetedImageURL: url, orientation: .up)
    }
    @objc(initWithTargetedImageURL:options:completionHandler:)
    convenience init(_objcURL url: URL, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedImageURL: url, orientation: .up, completionHandler: completionHandler)
    }
    @objc(initWithTargetedImageURL:orientation:options:) convenience init(_objcURL url: URL, orientation: UInt32, options: NSDictionary?) {
        self.init(targetedImageURL: url, orientation: _vnOrientation(orientation))
    }
    @objc(initWithTargetedImageURL:orientation:options:completionHandler:)
    convenience init(_objcURL url: URL, orientation: UInt32, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedImageURL: url, orientation: _vnOrientation(orientation), completionHandler: completionHandler)
    }
    @objc(initWithTargetedImageData:options:) convenience init(_objcData data: Data, options: NSDictionary?) {
        self.init(targetedImageData: data, orientation: .up)
    }
    @objc(initWithTargetedImageData:options:completionHandler:)
    convenience init(_objcData data: Data, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedImageData: data, orientation: .up, completionHandler: completionHandler)
    }
    @objc(initWithTargetedImageData:orientation:options:) convenience init(_objcData data: Data, orientation: UInt32, options: NSDictionary?) {
        self.init(targetedImageData: data, orientation: _vnOrientation(orientation))
    }
    @objc(initWithTargetedImageData:orientation:options:completionHandler:)
    convenience init(_objcData data: Data, orientation: UInt32, options: NSDictionary?, completionHandler: VNRequestCompletionHandler?) {
        self.init(targetedImageData: data, orientation: _vnOrientation(orientation), completionHandler: completionHandler)
    }
}
extension VNStatefulRequest {
    /// CMTime as numbers (value, timescale, flags, epoch): Vision.m makes the C struct and calls this
    @objc(_isim_initWithSpacing:completionHandler:) convenience init(_objcSpacing v: [NSNumber], completionHandler: VNRequestCompletionHandler?) {
        let t = v.count >= 4 ? CMTime(value: v[0].int64Value, timescale: v[1].int32Value, flags: CMTimeFlags(rawValue: v[2].uint32Value), epoch: v[3].int64Value) : .zero
        self.init(frameAnalysisSpacing: t, completionHandler: completionHandler)
    }
    @objc(_isim_frameAnalysisSpacing) var _objcSpacing: [NSNumber] {
        let t = frameAnalysisSpacing
        return [NSNumber(value: t.value), NSNumber(value: t.timescale), NSNumber(value: t.flags.rawValue), NSNumber(value: t.epoch)]
    }
}
extension VNImageHomographicAlignmentObservation {
    /// the nine numbers, column by column: Vision.m makes the matrix_float3x3
    @objc(_isim_warpTransform) var _objcWarp: [NSNumber] {
        let m = warpTransform
        return [m.columns.0, m.columns.1, m.columns.2].flatMap { [NSNumber(value: $0.x), NSNumber(value: $0.y), NSNumber(value: $0.z)] }
    }
}

// MARK: - points, pose and feature prints (issue #375): joint and group names as strings

extension VNPoint { @objc(zeroPoint) class var _objcZero: VNPoint { zero } }
extension VNVector { @objc(zeroVector) class var _objcZero: VNVector { zero } }
extension VNHumanBodyPoseObservation {
    @objc(availableJointNames) var _objcJointNames: [String] { availableKeys.map(\.rawValue) }
    @objc(availableJointsGroupNames) var _objcGroupNames: [String] { availableGroupKeys.map(\.rawValue) }
    @objc(recognizedPointForJointName:error:) func _objcJoint(_ name: String) throws -> VNRecognizedPoint { try recognizedPoint(forKey: VNRecognizedPointKey(rawValue: name)) }
    @objc(recognizedPointsForJointsGroupName:error:) func _objcGroup(_ name: String) throws -> [String: VNRecognizedPoint] { try _objcPoints(name) }
}
extension VNHumanHandPoseObservation {
    @objc(availableJointNames) var _objcJointNames: [String] { availableKeys.map(\.rawValue) }
    @objc(availableJointsGroupNames) var _objcGroupNames: [String] { availableGroupKeys.map(\.rawValue) }
    @objc(recognizedPointForJointName:error:) func _objcJoint(_ name: String) throws -> VNRecognizedPoint { try recognizedPoint(forKey: VNRecognizedPointKey(rawValue: name)) }
    @objc(recognizedPointsForJointsGroupName:error:) func _objcGroup(_ name: String) throws -> [String: VNRecognizedPoint] { try _objcPoints(name) }
}
extension VNAnimalBodyPoseObservation {
    @objc(availableJointNames) var _objcJointNames: [String] { availableKeys.map(\.rawValue) }
    @objc(availableJointGroupNames) var _objcGroupNames: [String] { availableGroupKeys.map(\.rawValue) }
    @objc(recognizedPointForJointName:error:) func _objcJoint(_ name: String) throws -> VNRecognizedPoint { try recognizedPoint(forKey: VNRecognizedPointKey(rawValue: name)) }
    @objc(recognizedPointsForJointsGroupName:error:) func _objcGroup(_ name: String) throws -> [String: VNRecognizedPoint] { try _objcPoints(name) }
}
extension VNDetectAnimalBodyPoseRequest {
    @objc(supportedJointNamesAndReturnError:) func _objcJointNames() throws -> [String] { supportedJointNames.map(\.rawValue.rawValue) }
    @objc(supportedJointsGroupNamesAndReturnError:) func _objcGroupNames() throws -> [String] { supportedJointsGroupNames.map(\.rawValue.rawValue) }
}

// MARK: - issue #852: CMTime, simd matrices, CVPixelBufferRef and joint names of the new classes (Vision.m makes the C structs)

private func _numbers(_ m: simd_float4x4) -> [NSNumber] { (0..<4).flatMap { c in (0..<4).map { NSNumber(value: m[c][$0]) } } }
private func _matrix(_ v: [NSNumber]) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    if v.count == 16 { for c in 0..<4 { for r in 0..<4 { m[c][r] = v[c * 4 + r].floatValue } } }
    return m
}
private func _time(_ v: [NSNumber]) -> CMTime {
    v.count >= 4 ? CMTime(value: v[0].int64Value, timescale: v[1].int32Value, flags: CMTimeFlags(rawValue: v[2].uint32Value), epoch: v[3].int64Value) : .zero
}
private func _numbers(_ t: CMTime) -> [NSNumber] { [NSNumber(value: t.value), NSNumber(value: t.timescale), NSNumber(value: t.flags.rawValue), NSNumber(value: t.epoch)] }

extension VNDetectTrajectoriesRequest {
    @objc(_isim_initWithSpacing:trajectoryLength:completionHandler:)
    convenience init(_objcSpacing v: [NSNumber], trajectoryLength: Int, completionHandler: VNRequestCompletionHandler?) {
        self.init(frameAnalysisSpacing: _time(v), trajectoryLength: trajectoryLength, completionHandler: completionHandler)
    }
    @objc(_isim_targetFrameTime) var _objcTarget: [NSNumber] {
        get { _numbers(targetFrameTime) }
        set { targetFrameTime = _time(newValue) }
    }
}
extension VNTrajectoryObservation {
    @objc(_isim_equationCoefficients) var _objcCoefficients: [NSNumber] { [equationCoefficients.x, equationCoefficients.y, equationCoefficients.z].map { NSNumber(value: $0) } }
}
extension VNGeometryUtils {
    @objc(boundingCircleForSIMDPoints:pointCount:error:) class func _objcCircle(_ points: UnsafeRawPointer, pointCount: Int) throws -> VNCircle {
        try boundingCircle(forSIMDPoints: points.assumingMemoryBound(to: simd_float2.self), pointCount: pointCount)
    }
}
extension VNCircle { @objc(zeroCircle) class var _objcZero: VNCircle { zero } }
extension VNPoint3D {
    @objc(_isim_position) var _objcPosition: [NSNumber] { _numbers(position) }
    @objc(_isim_initWithPosition:) convenience init?(_objcPosition v: [NSNumber]) { self.init(position: _matrix(v)) }
}
extension VNRecognizedPoint3D { @objc(identifier) var _objcIdentifier: String { identifier.rawValue } }
extension VNHumanBodyRecognizedPoint3D {
    @objc(_isim_localPosition) var _objcLocal: [NSNumber] { _numbers(localPosition) }
    @objc(parentJoint) var _objcParent: String { parentJoint.rawValue.rawValue }
}
extension VNRecognizedPoints3DObservation {
    @objc(availableKeys) var _objcKeys: [String] { availableKeys.map(\.rawValue) }
    @objc(availableGroupKeys) var _objcGroupKeys: [String] { availableGroupKeys.map(\.rawValue) }
    @objc(recognizedPointForKey:error:) func _objcPoint(_ key: String) throws -> VNRecognizedPoint3D { try recognizedPoint(forKey: VNRecognizedPointKey(rawValue: key)) }
    @objc(recognizedPointsForGroupKey:error:) func _objcPoints(_ key: String) throws -> [String: VNRecognizedPoint3D] {
        Dictionary(uniqueKeysWithValues: try recognizedPoints(forGroupKey: VNRecognizedPointGroupKey(rawValue: key)).map { ($0.key.rawValue, $0.value) })
    }
}
extension VNHumanBodyPose3DObservation {
    @objc(availableJointNames) var _objcJointNames: [String] { availableJointNames.map(\.rawValue.rawValue) }
    @objc(availableJointsGroupNames) var _objcGroupNames: [String] { availableJointsGroupNames.map(\.rawValue.rawValue) }
    @objc(recognizedPointForJointName:error:) func _objcJoint(_ name: String) throws -> VNHumanBodyRecognizedPoint3D {
        try recognizedPoint(JointName(rawValue: VNRecognizedPointKey(rawValue: name)))
    }
    @objc(recognizedPointsForJointsGroupName:error:) func _objcGroup(_ name: String) throws -> [String: VNHumanBodyRecognizedPoint3D] {
        Dictionary(uniqueKeysWithValues: try recognizedPoints(JointsGroupName(rawValue: VNRecognizedPointGroupKey(rawValue: name))).map { ($0.key.rawValue.rawValue, $0.value) })
    }
    @objc(pointInImageForJointName:error:) func _objcImagePoint(_ name: String) throws -> VNPoint { try pointInImage(JointName(rawValue: VNRecognizedPointKey(rawValue: name))) }
    @objc(parentJointNameForJointName:) func _objcParent(_ name: String) -> String? { parentJointName(JointName(rawValue: VNRecognizedPointKey(rawValue: name)))?.rawValue.rawValue }
    @objc(_isim_cameraOriginMatrix) var _objcCamera: [NSNumber] { _numbers(cameraOriginMatrix) }
    @objc(_isim_cameraRelativePositionForJointName:error:) func _objcRelative(_ name: String) throws -> [NSNumber] {
        _numbers(try cameraRelativePosition(JointName(rawValue: VNRecognizedPointKey(rawValue: name))))
    }
}
extension VNInstanceMaskObservation {
    /// buffers handed to Objective-C live as long as the observation
    @objc(instanceMask) var _objcMask: UnsafeMutableRawPointer { Unmanaged.passUnretained(instanceMask).toOpaque() }
    func _keep(_ b: CVPixelBuffer) -> UnsafeMutableRawPointer {
        objc_setAssociatedObject(self, Unmanaged.passUnretained(b).toOpaque(), b, .OBJC_ASSOCIATION_RETAIN)
        return Unmanaged.passUnretained(b).toOpaque()
    }
    func _call(_ e: NSErrorPointer, _ f: () throws -> CVPixelBuffer) -> UnsafeMutableRawPointer? {
        do { return _keep(try f()) } catch { e?.pointee = error as NSError; return nil }
    }
    @objc(generateMaskForInstances:error:) func _objcMask(_ instances: IndexSet, error: NSErrorPointer) -> UnsafeMutableRawPointer? {
        _call(error) { try generateMask(forInstances: instances) }
    }
    @objc(generateScaledMaskForImageForInstances:fromRequestHandler:error:)
    func _objcScaled(_ instances: IndexSet, _ handler: VNImageRequestHandler, error: NSErrorPointer) -> UnsafeMutableRawPointer? {
        _call(error) { try generateScaledMaskForImage(forInstances: instances, from: handler) }
    }
    @objc(generateMaskedImageOfInstances:fromRequestHandler:croppedToInstancesExtent:error:)
    func _objcMasked(_ instances: IndexSet, _ handler: VNImageRequestHandler, _ crop: Bool, error: NSErrorPointer) -> UnsafeMutableRawPointer? {
        _call(error) { try generateMaskedImage(ofInstances: instances, from: handler, croppedToInstancesExtent: crop) }
    }
}
extension VNRecognizeAnimalsRequest {
    @objc(supportedIdentifiersAndReturnError:) func _objcIdentifiers() throws -> [String] { try supportedIdentifiers().map(\.rawValue) }
}
extension VNVideoProcessor {
    /// CMTimeRange as numbers (start, then duration: value, timescale, flags, epoch)
    @objc(_isim_analyzeTimeRange:error:) func _objcAnalyze(_ v: [NSNumber]) throws {
        let start = _time(Array(v.prefix(4))), duration = _time(Array(v.dropFirst(4)))
        try analyze(CMTimeRange(start: start, duration: duration))
    }
}
