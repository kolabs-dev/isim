// isim Vision (issue #852): the rest of the classic VN API. Adapted, over isim's own detectors and the host models the
// pose and segmentation requests already use (VisionPose.swift):
//   - VNDetectHumanBodyPose3DRequest: the 2D body pose (ISIM_BODY_POSE_MODEL) lifted onto a plane facing the camera,
//     scaled to a reference body height of 1.8 m (heightEstimation .reference); depth is that plane's;
//   - VNDetectTrajectoriesRequest: moving blobs found by frame differencing between a sequence handler's frames (where
//     the object is now), their centres followed and fitted with a parabola (y = a x^2 + b x + c, normalized coordinates) once trajectoryLength
//     points are seen;
//   - VNRecognizeAnimalsRequest: the image classifier (ISIM_CLASSIFY_MODEL with its labels) whose labels name a cat or
//     a dog breed (ImageNet's); one observation for the whole region;
//   - VNGenerateObjectnessBasedSaliencyImageRequest: the frequency-tuned saliency map of the attention request;
//   - VNGenerateForegroundInstanceMaskRequest: that map's salient regions as instances;
//     VNGeneratePersonInstanceMaskRequest: the person mask's separate regions (ISIM_PERSON_SEGMENTATION_MODEL);
//   - VNDetectDocumentSegmentationRequest: the largest rectangle (VNDetectRectanglesRequest);
//   - VNCalculateImageAestheticsScoresRequest: a score from sharpness, exposure and colour; "utility" images (documents,
//     screenshots) are mostly flat, light and grey;
//   - VNVideoProcessor: the video's frames (AVAssetImageGenerator) at the request's cadence, through a sequence handler.
import UIKit
import CoreML
import AVFoundation
import CoreImage
import ImageIO
import simd

// MARK: - revisions and version

public let VNRequestRevisionUnspecified: Int = 0
public var VNVisionVersionNumber: Double = 8.0
public let VNClassifyImageRequestRevision1: Int = 1, VNClassifyImageRequestRevision2: Int = 2
public let VNCoreMLRequestRevision1: Int = 1
public let VNDetectAnimalBodyPoseRequestRevision1: Int = 1
public let VNDetectBarcodesRequestRevision2: Int = 2, VNDetectBarcodesRequestRevision3: Int = 3, VNDetectBarcodesRequestRevision4: Int = 4
public let VNDetectContourRequestRevision1: Int = 1
public let VNDetectDocumentSegmentationRequestRevision1: Int = 1
public let VNDetectFaceCaptureQualityRequestRevision1: Int = 1, VNDetectFaceCaptureQualityRequestRevision2: Int = 2, VNDetectFaceCaptureQualityRequestRevision3: Int = 3
public let VNDetectFaceLandmarksRequestRevision2: Int = 2, VNDetectFaceLandmarksRequestRevision3: Int = 3
public let VNDetectFaceRectanglesRequestRevision2: Int = 2, VNDetectFaceRectanglesRequestRevision3: Int = 3
public let VNDetectHorizonRequestRevision1: Int = 1
public let VNDetectHumanBodyPose3DRequestRevision1: Int = 1
public let VNDetectHumanBodyPoseRequestRevision1: Int = 1
public let VNDetectHumanHandPoseRequestRevision1: Int = 1
public let VNDetectHumanRectanglesRequestRevision1: Int = 1, VNDetectHumanRectanglesRequestRevision2: Int = 2
public let VNDetectRectanglesRequestRevision1: Int = 1
public let VNDetectTextRectanglesRequestRevision1: Int = 1
public let VNDetectTrajectoriesRequestRevision1: Int = 1
public let VNGenerateAttentionBasedSaliencyImageRequestRevision1: Int = 1, VNGenerateAttentionBasedSaliencyImageRequestRevision2: Int = 2
public let VNGenerateForegroundInstanceMaskRequestRevision1: Int = 1
public let VNGenerateImageFeaturePrintRequestRevision1: Int = 1, VNGenerateImageFeaturePrintRequestRevision2: Int = 2
public let VNGenerateObjectnessBasedSaliencyImageRequestRevision1: Int = 1, VNGenerateObjectnessBasedSaliencyImageRequestRevision2: Int = 2
public let VNGenerateOpticalFlowRequestRevision1: Int = 1, VNGenerateOpticalFlowRequestRevision2: Int = 2
public let VNGeneratePersonInstanceMaskRequestRevision1: Int = 1
public let VNGeneratePersonSegmentationRequestRevision1: Int = 1
public let VNHomographicImageRegistrationRequestRevision1: Int = 1
public let VNRecognizeAnimalsRequestRevision1: Int = 1, VNRecognizeAnimalsRequestRevision2: Int = 2
public let VNRecognizeTextRequestRevision1: Int = 1, VNRecognizeTextRequestRevision2: Int = 2, VNRecognizeTextRequestRevision3: Int = 3
public let VNTrackHomographicImageRegistrationRequestRevision1: Int = 1
public let VNTrackObjectRequestRevision1: Int = 1, VNTrackObjectRequestRevision2: Int = 2
public let VNTrackOpticalFlowRequestRevision1: Int = 1
public let VNTrackRectangleRequestRevision1: Int = 1
public let VNTrackTranslationalImageRegistrationRequestRevision1: Int = 1
public let VNTranslationalImageRegistrationRequestRevision1: Int = 1
public let VNCalculateImageAestheticsScoresRequestRevision1: Int = 1

/// bytes of one element of a VNElementType
public func VNElementTypeSize(_ elementType: VNElementType) -> Int {
    switch elementType { case .float: return 4; case .double: return 8; default: return 0 }
}

// MARK: - protocols, compute stages, small additions

/// requests that report their progress
@objc public protocol VNRequestProgressProviding: NSObjectProtocol {
    var progressHandler: VNRequestProgressHandler { get set }
    var indeterminate: Bool { get }
}
public typealias VNRequestProgressHandler = (VNRequest, Double, Error?) -> Void
/// objects that know the revision of the request that made them
public protocol VNRequestRevisionProviding { var requestRevision: Int { get } }
/// requests that take face observations to work on
@objc public protocol VNFaceObservationAccepting: NSObjectProtocol {
    var inputFaceObservations: [VNFaceObservation]? { get set }
}
extension VNDetectFaceLandmarksRequest: VNFaceObservationAccepting {}
extension VNDetectFaceCaptureQualityRequest: VNFaceObservationAccepting {}
extension VNObservation: VNRequestRevisionProviding {}

/// a stage of a request's work, for choosing its compute device
public struct VNComputeStage: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let main = VNComputeStage(rawValue: "VNComputeStageMain")
    public static let postProcessing = VNComputeStage(rawValue: "VNComputeStagePostProcessing")
}
extension VNRequest {
    /// isim runs every request on the CPU
    @nonobjc public var supportedComputeStageDevices: [VNComputeStage: [MLComputeDevice]] { get throws { [.main: [.cpu(MLCPUComputeDevice())]] } }
    @nonobjc public func computeDevice(for computeStage: VNComputeStage) -> MLComputeDevice? { _computeDevices[computeStage.rawValue] }
    @nonobjc public func setComputeDevice(_ computeDevice: MLComputeDevice?, for computeStage: VNComputeStage) { _computeDevices[computeStage.rawValue] = computeDevice }
}

public struct VNAnimalIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let cat = VNAnimalIdentifier(rawValue: "Cat")
    public static let dog = VNAnimalIdentifier(rawValue: "Dog")
}

/// the second symbol of a barcode with a composite part (GS1)
@objc public enum VNBarcodeCompositeType: Int, Sendable { case none = 0, linked = 1, gs1TypeA = 2, gs1TypeB = 3, gs1TypeC = 4 }
extension VNBarcodeObservation {
    /// isim reads no composite parts
    @objc public var supplementalCompositeType: VNBarcodeCompositeType { .none }
    @objc public var supplementalPayloadData: Data? { nil }
    /// the barcode as a Core Image descriptor (QR codes only: the payload is kept, not the raw codewords)
    public var barcodeDescriptor: CIBarcodeDescriptor? { nil }
}
extension VNBarcodeSymbology {
    public static let code39FullASCIIChecksum = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCode39FullASCIIChecksum")
    public static let code93i = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyCode93i")
}
extension VNRecognizedPointGroupKey {
    public static let point3DGroupKeyAll = VNRecognizedPointGroupKey(rawValue: "VNIPOAll3D")
}
extension VNDetectedObjectObservation {
    @objc public convenience init(requestRevision: Int, boundingBox: CGRect) { self.init(boundingBox: boundingBox) }
    /// a mask of the object over the whole image (isim makes none)
    @objc public var globalSegmentationMask: VNPixelBufferObservation? { nil }
}
extension VNRectangleObservation {
    @objc public convenience init(requestRevision: Int, topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        let xs = [topLeft.x, topRight.x, bottomRight.x, bottomLeft.x], ys = [topLeft.y, topRight.y, bottomRight.y, bottomLeft.y]
        self.init(boundingBox: CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!))
        _topLeft = topLeft; _topRight = topRight; _bottomRight = bottomRight; _bottomLeft = bottomLeft
    }
}
extension VNHumanObservation {
    /// whether the box is of the upper body only (isim's human rectangles are upper-body boxes)
    @objc public var upperBodyOnly: Bool { true }
}
extension VNCoreMLModel {
    @objc public convenience init(forMLModel model: MLModel) throws { try self.init(for: model) }
}
extension VNRecognizedText {
    /// unarchiving is not supported on isim
    @objc public convenience init?(coder: NSCoder) { return nil }
}
extension VNSequenceRequestHandler {
    public func perform(_ requests: [VNRequest], on image: CGImage) throws { try perform(requests, on: image, orientation: .up) }
    public func perform(_ requests: [VNRequest], on pixelBuffer: CVPixelBuffer) throws { try perform(requests, on: pixelBuffer, orientation: .up) }
    public func perform(_ requests: [VNRequest], on sampleBuffer: CMSampleBuffer) throws { try perform(requests, on: sampleBuffer, orientation: .up) }
    public func perform(_ requests: [VNRequest], on image: CIImage) throws { try perform(requests, on: image, orientation: .up) }
    public func perform(_ requests: [VNRequest], onImageURL imageURL: URL) throws { try perform(requests, onImageURL: imageURL, orientation: .up) }
    public func perform(_ requests: [VNRequest], onImageData imageData: Data) throws { try perform(requests, onImageData: imageData, orientation: .up) }
}
extension VNImageRequestHandler {
    public convenience init(cmSampleBuffer sampleBuffer: CMSampleBuffer, options: [VNImageOption: Any] = [:]) {
        self.init(cmSampleBuffer: sampleBuffer, orientation: .up, options: options)
    }
    @available(*, deprecated, renamed: "init(cmSampleBuffer:options:)")
    public convenience init(CMSampleBuffer sampleBuffer: CMSampleBuffer, options: [VNImageOption: Any] = [:]) {
        self.init(cmSampleBuffer: sampleBuffer, orientation: .up, options: options)
    }
    /// the depth data is not used (isim's requests see the image only)
    public convenience init(cmSampleBuffer sampleBuffer: CMSampleBuffer, depthData: AVDepthData, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:]) {
        self.init(cmSampleBuffer: sampleBuffer, orientation: orientation, options: options)
    }
    @available(*, deprecated, renamed: "init(cmSampleBuffer:depthData:orientation:options:)")
    public convenience init(CMSampleBuffer sampleBuffer: CMSampleBuffer, depthData: AVDepthData, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:]) {
        self.init(cmSampleBuffer: sampleBuffer, orientation: orientation, options: options)
    }
    public convenience init(cvPixelBuffer pixelBuffer: CVPixelBuffer, depthData: AVDepthData, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:]) {
        self.init(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
    }
    @available(*, deprecated, renamed: "init(cvPixelBuffer:depthData:orientation:options:)")
    public convenience init(CVPixelBuffer pixelBuffer: CVPixelBuffer, depthData: AVDepthData, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:]) {
        self.init(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
    }
    /// the handler's image, upright (for instance masks)
    func _image() -> _VNImage? { _load()?.oriented(_orientation) }
}

// MARK: - geometry functions

public func VNImagePointForNormalizedPointUsingRegionOfInterest(_ normalizedPoint: CGPoint, _ imageWidth: Int, _ imageHeight: Int, _ roi: CGRect) -> CGPoint {
    CGPoint(x: (roi.minX + normalizedPoint.x * roi.width) * Double(imageWidth), y: (roi.minY + normalizedPoint.y * roi.height) * Double(imageHeight))
}
public func VNNormalizedPointForImagePointUsingRegionOfInterest(_ imagePoint: CGPoint, _ imageWidth: Int, _ imageHeight: Int, _ roi: CGRect) -> CGPoint {
    CGPoint(x: (imagePoint.x / Double(imageWidth) - roi.minX) / roi.width, y: (imagePoint.y / Double(imageHeight) - roi.minY) / roi.height)
}
public func VNImageRectForNormalizedRectUsingRegionOfInterest(_ normalizedRect: CGRect, _ imageWidth: Int, _ imageHeight: Int, _ roi: CGRect) -> CGRect {
    let o = VNImagePointForNormalizedPointUsingRegionOfInterest(normalizedRect.origin, imageWidth, imageHeight, roi)
    return CGRect(x: o.x, y: o.y, width: normalizedRect.width * roi.width * Double(imageWidth), height: normalizedRect.height * roi.height * Double(imageHeight))
}
public func VNNormalizedRectForImageRectUsingRegionOfInterest(_ imageRect: CGRect, _ imageWidth: Int, _ imageHeight: Int, _ roi: CGRect) -> CGRect {
    let o = VNNormalizedPointForImagePointUsingRegionOfInterest(imageRect.origin, imageWidth, imageHeight, roi)
    return CGRect(x: o.x, y: o.y, width: imageRect.width / (roi.width * Double(imageWidth)), height: imageRect.height / (roi.height * Double(imageHeight)))
}
/// a face landmark point (normalized to the face's box) in image pixels
public func VNImagePointForFaceLandmarkPoint(_ faceLandmarkPoint: vector_float2, _ faceBoundingBox: CGRect, _ imageWidth: Int, _ imageHeight: Int) -> CGPoint {
    VNImagePointForNormalizedPoint(VNNormalizedFaceBoundingBoxPointForLandmarkPoint(faceLandmarkPoint, faceBoundingBox, imageWidth, imageHeight), imageWidth, imageHeight)
}
/// a face landmark point (normalized to the face's box) normalized to the image
public func VNNormalizedFaceBoundingBoxPointForLandmarkPoint(_ faceLandmarkPoint: vector_float2, _ faceBoundingBox: CGRect, _ imageWidth: Int, _ imageHeight: Int) -> CGPoint {
    CGPoint(x: faceBoundingBox.minX + Double(faceLandmarkPoint.x) * faceBoundingBox.width, y: faceBoundingBox.minY + Double(faceLandmarkPoint.y) * faceBoundingBox.height)
}

// MARK: - circles and geometry utilities

@objc(VNCircle) open class VNCircle: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let center: VNPoint
    @objc public let radius: Double
    @objc open var diameter: Double { radius * 2 }
    @objc(initWithCenter:radius:) public init(center: VNPoint, radius: Double) { self.center = center; self.radius = radius; super.init() }
    @objc(initWithCenter:diameter:) public convenience init(center: VNPoint, diameter: Double) { self.init(center: center, radius: diameter / 2) }
    @objc open class var zero: VNCircle { VNCircle(center: .zero, radius: 0) }
    @objc(containsPoint:) open func contains(_ point: VNPoint) -> Bool { center.distance(point) <= radius }
    /// whether the point lies in the ring of that width around the circumference (half inside, half outside)
    @objc(containsPoint:inCircumferentialRingOfWidth:) open func contains(_ point: VNPoint, inCircumferentialRingOfWidth ringWidth: Double) -> Bool {
        abs(center.distance(point) - radius) <= ringWidth / 2
    }
    @objc public func copy(with zone: NSZone? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) { center.encode(with: coder); coder.encode(radius, forKey: "radius") }
    @objc public required init?(coder: NSCoder) {
        center = VNPoint(x: coder.decodeDouble(forKey: "x"), y: coder.decodeDouble(forKey: "y")); radius = coder.decodeDouble(forKey: "radius"); super.init()
    }
    @objc open override func isEqual(_ object: Any?) -> Bool { (object as? VNCircle).map { $0.center == center && $0.radius == radius } ?? false }
    @objc open override var hash: Int { center.hash ^ radius.hashValue }
    @objc open override var description: String { "VNCircle(center: \(center), radius: \(radius))" }
}

@objc(VNGeometryUtils) open class VNGeometryUtils: NSObject, @unchecked Sendable {
    /// the smallest circle around the points (Welzl's algorithm)
    static func _circle(_ pts: [SIMD2<Double>]) -> VNCircle {
        guard !pts.isEmpty else { return .zero }
        func two(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> (SIMD2<Double>, Double) { ((a + b) / 2, simd_length(a - b) / 2) }
        func three(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>) -> (SIMD2<Double>, Double) {
            let d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
            if abs(d) < 1e-12 {               /* collinear: the widest pair */
                let cands = [two(a, b), two(a, c), two(b, c)]
                return cands.max { $0.1 < $1.1 }!
            }
            let a2 = simd_length_squared(a), b2 = simd_length_squared(b), c2 = simd_length_squared(c)
            let ux = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d
            let uy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d
            let u = SIMD2(ux, uy)
            return (u, simd_length(u - a))
        }
        func inside(_ c: (SIMD2<Double>, Double), _ p: SIMD2<Double>) -> Bool { simd_length(p - c.0) <= c.1 * (1 + 1e-9) + 1e-12 }
        var c = (pts[0], 0.0)
        for i in 1..<pts.count where !inside(c, pts[i]) {
            c = (pts[i], 0)
            for j in 0..<i where !inside(c, pts[j]) {
                c = two(pts[i], pts[j])
                for k in 0..<j where !inside(c, pts[k]) { c = three(pts[i], pts[j], pts[k]) }
            }
        }
        return VNCircle(center: VNPoint(x: c.0.x, y: c.0.y), radius: c.1)
    }
    @objc(boundingCircleForContour:error:) open class func boundingCircle(for contour: VNContour) throws -> VNCircle {
        _circle(contour.normalizedPoints.map { SIMD2(Double($0.x), Double($0.y)) })
    }
    @objc(boundingCircleForPoints:error:) open class func boundingCircle(for points: [VNPoint]) throws -> VNCircle {
        _circle(points.map { SIMD2($0.x, $0.y) })
    }
    open class func boundingCircle(forSIMDPoints points: UnsafePointer<simd_float2>, pointCount: Int) throws -> VNCircle {
        _circle((0..<pointCount).map { SIMD2(Double(points[$0].x), Double(points[$0].y)) })
    }
    /// the contour's area (shoelace formula, normalized coordinates); oriented: positive when counterclockwise
    @objc(calculateArea:forContour:orientedArea:error:) open class func calculateArea(_ area: UnsafeMutablePointer<Double>, for contour: VNContour, orientedArea: Bool) throws {
        let p = contour.normalizedPoints
        var s = 0.0
        for i in p.indices { let a = p[i], b = p[(i + 1) % p.count]; s += Double(a.x) * Double(b.y) - Double(b.x) * Double(a.y) }
        area.pointee = orientedArea ? s / 2 : abs(s) / 2
    }
    @objc(calculatePerimeter:forContour:error:) open class func calculatePerimeter(_ perimeter: UnsafeMutablePointer<Double>, for contour: VNContour) throws {
        let p = contour.normalizedPoints
        var s = 0.0
        for i in p.indices { s += Double(simd_distance(p[i], p[(i + 1) % p.count])) }
        perimeter.pointee = p.count > 1 ? s : 0
    }
}

// MARK: - 3D points and the 3D body pose

@objc(VNPoint3D) open class VNPoint3D: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    /// a transform whose translation is the point (meters)
    public let position: simd_float4x4
    public init?(position: simd_float4x4) { self.position = position; super.init() }
    @objc public func copy(with zone: NSZone? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) {
        for c in 0..<4 { for r in 0..<4 { coder.encode(position[c][r], forKey: "p\(c)\(r)") } }
    }
    @objc public required init?(coder: NSCoder) {
        var m = matrix_identity_float4x4
        for c in 0..<4 { for r in 0..<4 { m[c][r] = coder.decodeFloat(forKey: "p\(c)\(r)") } }
        position = m; super.init()
    }
}
@objc(VNRecognizedPoint3D) open class VNRecognizedPoint3D: VNPoint3D, @unchecked Sendable {
    public let identifier: VNRecognizedPointKey
    init(identifier: VNRecognizedPointKey, position: simd_float4x4) { self.identifier = identifier; super.init(position: position)! }
    @objc public required init?(coder: NSCoder) { identifier = VNRecognizedPointKey(rawValue: coder.decodeObject(forKey: "id") as? String ?? ""); super.init(coder: coder) }
}
@objc(VNHumanBodyRecognizedPoint3D) open class VNHumanBodyRecognizedPoint3D: VNRecognizedPoint3D, @unchecked Sendable {
    /// the transform relative to the parent joint
    public let localPosition: simd_float4x4
    public let parentJoint: VNHumanBodyPose3DObservation.JointName
    init(joint: VNHumanBodyPose3DObservation.JointName, position: simd_float4x4, localPosition: simd_float4x4, parent: VNHumanBodyPose3DObservation.JointName) {
        self.localPosition = localPosition; parentJoint = parent
        super.init(identifier: joint.rawValue, position: position)
    }
    @objc public required init?(coder: NSCoder) {
        localPosition = matrix_identity_float4x4; parentJoint = .root; super.init(coder: coder)
    }
}
@objc(VNRecognizedPoints3DObservation) open class VNRecognizedPoints3DObservation: VNObservation, @unchecked Sendable {
    let _points: [VNRecognizedPointKey: VNRecognizedPoint3D]
    let _order: [VNRecognizedPointKey]
    let _groups: [VNRecognizedPointGroupKey: [VNRecognizedPointKey]]
    init(points: [VNRecognizedPoint3D], groups: [VNRecognizedPointGroupKey: [VNRecognizedPointKey]]) {
        _order = points.map(\.identifier)
        _points = Dictionary(points.map { ($0.identifier, $0) }, uniquingKeysWith: { a, _ in a })
        var g = groups
        g[.point3DGroupKeyAll] = _order
        _groups = g
        super.init()
    }
    public var availableKeys: [VNRecognizedPointKey] { _order }
    public var availableGroupKeys: [VNRecognizedPointGroupKey] { Array(_groups.keys).sorted { $0.rawValue < $1.rawValue } }
    public func recognizedPoint(forKey pointKey: VNRecognizedPointKey) throws -> VNRecognizedPoint3D {
        guard let p = _points[pointKey] else { throw _vnError(.invalidArgument, "no point \(pointKey.rawValue) in this observation") }
        return p
    }
    public func recognizedPoints(forGroupKey groupKey: VNRecognizedPointGroupKey) throws -> [VNRecognizedPointKey: VNRecognizedPoint3D] {
        guard let keys = _groups[groupKey] else { throw _vnError(.invalidArgument, "no group \(groupKey.rawValue) in this observation") }
        var out: [VNRecognizedPointKey: VNRecognizedPoint3D] = [:]
        for k in keys { if let p = _points[k] { out[k] = p } }
        return out
    }
}

@objc(VNHumanBodyPose3DObservation) open class VNHumanBodyPose3DObservation: VNRecognizedPoints3DObservation, @unchecked Sendable {
    public struct JointName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointKey
        public init(rawValue: VNRecognizedPointKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointKey(rawValue: s) }
        public static let root = JointName("human_root_3D"), spine = JointName("human_spine_3D")
        public static let centerShoulder = JointName("human_center_shoulder_3D"), centerHead = JointName("human_center_head_3D")
        public static let topHead = JointName("human_top_head_3D")
        public static let leftShoulder = JointName("human_left_shoulder_3D"), rightShoulder = JointName("human_right_shoulder_3D")
        public static let leftElbow = JointName("human_left_elbow_3D"), rightElbow = JointName("human_right_elbow_3D")
        public static let leftWrist = JointName("human_left_wrist_3D"), rightWrist = JointName("human_right_wrist_3D")
        public static let leftHip = JointName("human_left_hip_3D"), rightHip = JointName("human_right_hip_3D")
        public static let leftKnee = JointName("human_left_knee_3D"), rightKnee = JointName("human_right_knee_3D")
        public static let leftAnkle = JointName("human_left_ankle_3D"), rightAnkle = JointName("human_right_ankle_3D")
        static let ordered: [JointName] = [.root, .rightHip, .rightKnee, .rightAnkle, .leftHip, .leftKnee, .leftAnkle, .spine, .centerShoulder,
                                           .centerHead, .topHead, .leftShoulder, .leftElbow, .leftWrist, .rightShoulder, .rightElbow, .rightWrist]
        static let parents: [JointName: JointName] = [
            .spine: .root, .centerShoulder: .spine, .centerHead: .centerShoulder, .topHead: .centerHead,
            .leftShoulder: .centerShoulder, .leftElbow: .leftShoulder, .leftWrist: .leftElbow,
            .rightShoulder: .centerShoulder, .rightElbow: .rightShoulder, .rightWrist: .rightElbow,
            .leftHip: .root, .leftKnee: .leftHip, .leftAnkle: .leftKnee, .rightHip: .root, .rightKnee: .rightHip, .rightAnkle: .rightKnee]
    }
    public struct JointsGroupName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointGroupKey
        public init(rawValue: VNRecognizedPointGroupKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointGroupKey(rawValue: s) }
        public static let head = JointsGroupName("human_head_3D"), torso = JointsGroupName("human_torso_3D")
        public static let leftArm = JointsGroupName("human_left_arm_3D"), rightArm = JointsGroupName("human_right_arm_3D")
        public static let leftLeg = JointsGroupName("human_left_leg_3D"), rightLeg = JointsGroupName("human_right_leg_3D")
        public static let all = JointsGroupName(rawValue: .point3DGroupKeyAll)
        static let members: [JointsGroupName: [JointName]] = [
            .head: [.centerHead, .topHead], .torso: [.root, .spine, .centerShoulder, .leftShoulder, .rightShoulder, .leftHip, .rightHip],
            .leftArm: [.leftShoulder, .leftElbow, .leftWrist], .rightArm: [.rightShoulder, .rightElbow, .rightWrist],
            .leftLeg: [.leftHip, .leftKnee, .leftAnkle], .rightLeg: [.rightHip, .rightKnee, .rightAnkle]]
    }
    /// whether the body height was measured (with depth) or is the reference height
    @objc(VNHumanBodyPose3DObservationHeightEstimation) public enum HeightEstimation: Int, Sendable { case reference = 0, measured = 1 }
    @objc public let heightEstimation: HeightEstimation
    /// meters (isim: the reference height, 1.8 m)
    @objc public let bodyHeight: Float
    /// the camera's position and orientation relative to the root joint
    public let cameraOriginMatrix: simd_float4x4
    let _image: [JointName: CGPoint]
    init(points: [VNHumanBodyRecognizedPoint3D], image: [JointName: CGPoint], camera: simd_float4x4, height: Float) {
        _image = image; cameraOriginMatrix = camera; bodyHeight = height; heightEstimation = .reference
        super.init(points: points, groups: Dictionary(uniqueKeysWithValues: JointsGroupName.members.map { ($0.key.rawValue, $0.value.map(\.rawValue)) }))
    }
    public var availableJointNames: [JointName] { availableKeys.map { JointName(rawValue: $0) } }
    public var availableJointsGroupNames: [JointsGroupName] { availableGroupKeys.map { JointsGroupName(rawValue: $0) } }
    public func recognizedPoint(_ jointName: JointName) throws -> VNHumanBodyRecognizedPoint3D {
        guard let p = try recognizedPoint(forKey: jointName.rawValue) as? VNHumanBodyRecognizedPoint3D else { throw _vnError(.invalidArgument, "no joint \(jointName.rawValue.rawValue)") }
        return p
    }
    public func recognizedPoints(_ jointsGroupName: JointsGroupName) throws -> [JointName: VNHumanBodyRecognizedPoint3D] {
        var out: [JointName: VNHumanBodyRecognizedPoint3D] = [:]
        for (k, v) in try recognizedPoints(forGroupKey: jointsGroupName.rawValue) { if let p = v as? VNHumanBodyRecognizedPoint3D { out[JointName(rawValue: k)] = p } }
        return out
    }
    /// where the joint is in the image (normalized, lower-left origin)
    public func pointInImage(_ jointName: JointName) throws -> VNPoint {
        guard let p = _image[jointName] else { throw _vnError(.invalidArgument, "no joint \(jointName.rawValue.rawValue)") }
        return VNPoint(location: p)
    }
    public func parentJointName(_ jointName: JointName) -> JointName? { JointName.parents[jointName] }
    /// the joint relative to the camera
    @nonobjc public func cameraRelativePosition(_ jointName: JointName) throws -> simd_float4x4 {
        cameraOriginMatrix.inverse * (try recognizedPoint(jointName)).position
    }
}

@objc(VNDetectHumanBodyPose3DRequest) open class VNDetectHumanBodyPose3DRequest: VNStatefulRequest, @unchecked Sendable {
    public override init(frameAnalysisSpacing: CMTime, completionHandler: VNRequestCompletionHandler?) {
        super.init(frameAnalysisSpacing: frameAnalysisSpacing, completionHandler: completionHandler)
    }
    @nonobjc public var supportedJointNames: [VNHumanBodyPose3DObservation.JointName] { get throws { VNHumanBodyPose3DObservation.JointName.ordered } }
    @nonobjc public var supportedJointsGroupNames: [VNHumanBodyPose3DObservation.JointsGroupName] {
        get throws { [.head, .torso, .leftArm, .rightArm, .leftLeg, .rightLeg, .all] }
    }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let body = VNDetectHumanBodyPoseRequest()
        guard let pose = try body._run(img).first as? VNHumanBodyPoseObservation else { return [] }
        typealias J2 = VNHumanBodyPoseObservation.JointName
        typealias J3 = VNHumanBodyPose3DObservation.JointName
        func p(_ j: J2) -> CGPoint? { (try? pose.recognizedPoint(j)).flatMap { $0.confidence > 0.1 ? $0.location : nil } }
        func mid(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? { guard let a, let b else { return a ?? b }; return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var img2: [J3: CGPoint] = [:]
        img2[.root] = mid(p(.leftHip), p(.rightHip)); img2[.centerShoulder] = mid(p(.leftShoulder), p(.rightShoulder))
        img2[.spine] = mid(img2[.root], img2[.centerShoulder])
        img2[.centerHead] = p(.nose)
        if let h = img2[.centerHead], let s = img2[.centerShoulder] { img2[.topHead] = CGPoint(x: h.x + (h.x - s.x) * 0.6, y: h.y + (h.y - s.y) * 0.6) }
        let pairs: [(J3, J2)] = [(.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder), (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
                                 (.leftWrist, .leftWrist), (.rightWrist, .rightWrist), (.leftHip, .leftHip), (.rightHip, .rightHip),
                                 (.leftKnee, .leftKnee), (.rightKnee, .rightKnee), (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle)]
        for (a, b) in pairs { img2[a] = p(b) }
        guard let root = img2[.root] else { return [] }
        /* the body's height in the image (top of the head to the lowest ankle) is the reference 1.8 m; the points lie on
           the plane through the root that faces the camera; y up, x to the image's right (aspect-corrected) */
        let aspect = Double(img.width) / Double(max(1, img.height))
        let top = img2[.topHead]?.y ?? img2[.centerHead]?.y ?? root.y, bottom = min(img2[.leftAnkle]?.y ?? root.y, img2[.rightAnkle]?.y ?? root.y)
        let span = max(0.05, top - bottom), height: Float = 1.8
        let scale = Double(height) / span
        func pos(_ q: CGPoint) -> SIMD3<Float> { SIMD3(Float((q.x - root.x) * aspect * scale), Float((q.y - root.y) * scale), 0) }
        func translation(_ t: SIMD3<Float>) -> simd_float4x4 { var m = matrix_identity_float4x4; m.columns.3 = SIMD4(t, 1); return m }
        /* a 60-degree vertical field of view puts the camera this far in front of the plane */
        let distance = Float(1 / (2 * tan(Double.pi / 6)) * (1 / span) * Double(height) * span)
        let camera = translation(SIMD3(Float((0.5 - root.x) * aspect * scale), Float((0.5 - root.y) * scale), distance))
        var points: [VNHumanBodyRecognizedPoint3D] = []
        for j in J3.ordered {
            guard let q = img2[j] else { continue }
            let parent = J3.parents[j] ?? .root
            let local = pos(q) - (img2[parent].map(pos) ?? .zero)
            points.append(VNHumanBodyRecognizedPoint3D(joint: j, position: translation(pos(q)), localPosition: translation(local), parent: parent))
        }
        let o = VNHumanBodyPose3DObservation(points: points, image: img2, camera: camera, height: height)
        o.confidence = pose.confidence
        return [o]
    }
}

// MARK: - trajectories

@objc(VNTrajectoryObservation) open class VNTrajectoryObservation: VNObservation, @unchecked Sendable {
    /// the centres the request saw (normalized, lower-left origin)
    @objc public let detectedPoints: [VNPoint]
    /// the points on the fitted parabola at the same x
    @objc public let projectedPoints: [VNPoint]
    /// y = a x^2 + b x + c, as (a, b, c)
    public let equationCoefficients: simd_float3
    @objc public let movingAverageRadius: CGFloat
    init(detected: [VNPoint], projected: [VNPoint], coefficients: simd_float3, radius: CGFloat) {
        detectedPoints = detected; projectedPoints = projected; equationCoefficients = coefficients; movingAverageRadius = radius; super.init()
    }
}

@objc(VNDetectTrajectoriesRequest) open class VNDetectTrajectoriesRequest: VNStatefulRequest, @unchecked Sendable {
    @objc public let trajectoryLength: Int
    @objc open var objectMinimumNormalizedRadius: Float = 0
    @objc open var objectMaximumNormalizedRadius: Float = 1
    /// the frame time the results are for (isim: the frame it was given)
    open var targetFrameTime: CMTime = .zero
    var _gray: [Float]?, _gw = 0, _gh = 0
    var _track: [(SIMD2<Double>, Double)] = []
    public init(frameAnalysisSpacing: CMTime, trajectoryLength: Int, completionHandler: VNRequestCompletionHandler? = nil) {
        self.trajectoryLength = max(5, trajectoryLength)
        super.init(frameAnalysisSpacing: frameAnalysisSpacing, completionHandler: completionHandler)
    }
    @objc open override var minimumLatencyFrameCount: Int { trajectoryLength }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        /* luma at most 160 pixels across */
        let s = max(1, max(img.width, img.height) / 160), W = img.width / s, H = img.height / s
        var g = [Float](repeating: 0, count: W * H)
        for y in 0..<H { for x in 0..<W {
            let i = ((y * s) * img.width + x * s) * 4
            g[y * W + x] = (0.114 * Float(img.bgra[i]) + 0.587 * Float(img.bgra[i + 1]) + 0.299 * Float(img.bgra[i + 2])) / 255
        } }
        defer { _gray = g; _gw = W; _gh = H }
        guard let prev = _gray, _gw == W, _gh == H else { return [] }
        /* the largest moving blob of an allowed size */
        /* the pixels that changed and now hold the object (further from the frame's background, its mean, than before) */
        let mean = g.reduce(0, +) / Float(g.count)
        let moving = g.indices.map { i in abs(g[i] - prev[i]) > 0.12 && abs(g[i] - mean) > abs(prev[i] - mean) }
        let blobs = _vnComponents(moving, W, H).filter { c in
            let r = Float(max(c.width, c.height)) / 2 / Float(max(W, H))
            return c.count >= 3 && r >= objectMinimumNormalizedRadius && r <= objectMaximumNormalizedRadius
        }
        guard let b = blobs.max(by: { $0.count < $1.count }) else { _track.removeAll(); return [] }
        let center = SIMD2((Double(b.minX) + Double(b.width) / 2) / Double(W), 1 - (Double(b.minY) + Double(b.height) / 2) / Double(H))
        let radius = Double(max(b.width, b.height)) / 2 / Double(max(W, H))
        if let last = _track.last, simd_distance(last.0, center) > 0.4 { _track.removeAll() }
        _track.append((center, radius))
        if _track.count > trajectoryLength { _track.removeFirst(_track.count - trajectoryLength) }
        guard _track.count == trajectoryLength else { return [] }
        /* least squares parabola through the centres */
        var A = simd_double3x3(0), r = SIMD3<Double>.zero
        for (c, _) in _track {
            let v = SIMD3(c.x * c.x, c.x, 1)
            A = A + simd_double3x3(rows: [v * v.x, v * v.y, v * v.z]); r += v * c.y
        }
        let coef = A.determinant.magnitude > 1e-12 ? A.inverse * r : SIMD3(0, 0, _track.map(\.0.y).reduce(0, +) / Double(_track.count))
        let detected = _track.map { VNPoint(x: $0.0.x, y: $0.0.y) }
        let projected = _track.map { VNPoint(x: $0.0.x, y: coef.x * $0.0.x * $0.0.x + coef.y * $0.0.x + coef.z) }
        let o = VNTrajectoryObservation(detected: detected, projected: projected, coefficients: simd_float3(Float(coef.x), Float(coef.y), Float(coef.z)),
                                        radius: CGFloat(_track.map(\.1).reduce(0, +) / Double(_track.count)))
        let err = zip(detected, projected).map { abs($0.y - $1.y) }.reduce(0, +) / Double(detected.count)
        o.confidence = Float(max(0, 1 - err * 20))
        return [o]
    }
}

// MARK: - animals

@objc(VNRecognizedObjectObservation) open class VNRecognizedObjectObservation: VNDetectedObjectObservation, @unchecked Sendable {
    @objc public let labels: [VNClassificationObservation]
    init(boundingBox: CGRect, labels: [VNClassificationObservation]) { self.labels = labels; super.init(boundingBox: boundingBox) }
}

@objc(VNRecognizeAnimalsRequest) open class VNRecognizeAnimalsRequest: VNImageBasedRequest, @unchecked Sendable {
    @objc open override class var supportedRevisions: IndexSet { IndexSet([1, 2]) }
    @objc open override class var defaultRevision: Int { 2 }
    @objc open override class var currentRevision: Int { 2 }
    public func supportedIdentifiers() throws -> [VNAnimalIdentifier] { [.cat, .dog] }
    public class func knownAnimalIdentifiers(forRevision requestRevision: Int) throws -> [VNAnimalIdentifier] { [.cat, .dog] }
    static let catWords = ["tabby", "tiger cat", "persian cat", "siamese", "egyptian cat", "kitten", "house cat"]
    static let dogWords = ["dog", "terrier", "retriever", "hound", "spaniel", "poodle", "shepherd", "collie", "setter", "pointer", "mastiff",
                           "schnauzer", "bulldog", "pug", "chihuahua", "corgi", "husky", "malamute", "beagle", "dachshund", "boxer", "pinscher",
                           "sheepdog", "greyhound", "whippet", "basset", "bloodhound", "pomeranian", "maltese", "shih-tzu", "papillon",
                           "newfoundland", "dalmatian", "labrador", "samoyed", "chow", "akita", "rottweiler", "great dane", "saint bernard",
                           "weimaraner", "vizsla", "puppy", "pekinese", "lhasa", "borzoi", "saluki", "keeshond", "spitz", "leonberg"]
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let classes = try VNClassifyImageRequest()._run(img).compactMap { $0 as? VNClassificationObservation }
        var cat: Float = 0, dog: Float = 0
        for c in classes {
            let l = c.identifier.lowercased()
            if Self.catWords.contains(where: { l.contains($0) }) { cat += c.confidence }
            else if Self.dogWords.contains(where: { l.contains($0) }) { dog += c.confidence }
        }
        var labels: [VNClassificationObservation] = []
        if cat >= 0.1 { labels.append(VNClassificationObservation(identifier: VNAnimalIdentifier.cat.rawValue, confidence: min(1, cat))) }
        if dog >= 0.1 { labels.append(VNClassificationObservation(identifier: VNAnimalIdentifier.dog.rawValue, confidence: min(1, dog))) }
        guard !labels.isEmpty else { return [] }
        labels.sort { $0.confidence > $1.confidence }
        let o = VNRecognizedObjectObservation(boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), labels: labels)
        o.confidence = labels[0].confidence
        return [o]
    }
}

// MARK: - saliency, instance masks, documents

@objc(VNGenerateObjectnessBasedSaliencyImageRequest) open class VNGenerateObjectnessBasedSaliencyImageRequest: VNImageBasedRequest, @unchecked Sendable {
    @objc open override class var supportedRevisions: IndexSet { IndexSet([1, 2]) }
    @objc open override class var defaultRevision: Int { 2 }
    @objc open override class var currentRevision: Int { 2 }
    override func _run(_ img: _VNImage) throws -> [VNObservation] { try VNGenerateAttentionBasedSaliencyImageRequest()._run(img) }
}

/// objects or people in an image, each an instance with its own label in the mask
@objc(VNInstanceMaskObservation) open class VNInstanceMaskObservation: VNObservation, @unchecked Sendable {
    /// OneComponent8: 0 is the background, n is instance n
    public let instanceMask: CVPixelBuffer
    @objc public let allInstances: IndexSet
    let _labels: [UInt8], _w: Int, _h: Int
    init(labels: [UInt8], width: Int, height: Int, count: Int) {
        _labels = labels; _w = width; _h = height
        allInstances = count > 0 ? IndexSet(integersIn: 1...count) : IndexSet()
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_OneComponent8, nil, &pb)
        instanceMask = pb!
        CVPixelBufferLockBaseAddress(pb!, [])
        if let base = CVPixelBufferGetBaseAddress(pb!) {
            let bpr = CVPixelBufferGetBytesPerRow(pb!)
            for y in 0..<height { for x in 0..<width { base.storeBytes(of: labels[y * width + x], toByteOffset: y * bpr + x, as: UInt8.self) } }
        }
        CVPixelBufferUnlockBaseAddress(pb!, [])
        super.init()
    }
    /// a OneComponent32Float mask of those instances, mask-sized (1 inside, 0 outside)
    open func generateMask(forInstances instances: IndexSet) throws -> CVPixelBuffer {
        try _mask(instances, _w, _h)
    }
    /// the mask scaled to the handler's image
    open func generateScaledMaskForImage(forInstances instances: IndexSet, from requestHandler: VNImageRequestHandler) throws -> CVPixelBuffer {
        guard let img = requestHandler._image() else { throw _vnError(.invalidImage, "the handler's image could not be read") }
        return try _mask(instances, img.width, img.height)
    }
    /// the handler's image with everything but those instances transparent (BGRA), optionally cropped to their extent
    open func generateMaskedImage(ofInstances instances: IndexSet, from requestHandler: VNImageRequestHandler, croppedToInstancesExtent cropResult: Bool) throws -> CVPixelBuffer {
        guard let img = requestHandler._image() else { throw _vnError(.invalidImage, "the handler's image could not be read") }
        func inside(_ x: Int, _ y: Int) -> Bool { instances.contains(Int(_labels[min(_h - 1, y * _h / img.height) * _w + min(_w - 1, x * _w / img.width)])) }
        var x0 = 0, y0 = 0, x1 = img.width, y1 = img.height
        if cropResult {
            x0 = img.width; y0 = img.height; x1 = 0; y1 = 0
            for y in 0..<img.height { for x in 0..<img.width where inside(x, y) { x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x + 1); y1 = max(y1, y + 1) } }
            if x1 <= x0 { x0 = 0; y0 = 0; x1 = 1; y1 = 1 }
        }
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, x1 - x0, y1 - y0, kCVPixelFormatType_32BGRA, nil, &pb)
        guard let out = pb else { throw _vnError(.outOfMemory, "the masked image could not be allocated") }
        CVPixelBufferLockBaseAddress(out, [])
        if let base = CVPixelBufferGetBaseAddress(out) {
            let bpr = CVPixelBufferGetBytesPerRow(out)
            for y in y0..<y1 { for x in x0..<x1 {
                let s = (y * img.width + x) * 4, keep = inside(x, y)
                for k in 0..<4 { base.storeBytes(of: keep ? img.bgra[s + k] : 0, toByteOffset: (y - y0) * bpr + (x - x0) * 4 + k, as: UInt8.self) }
            } }
        }
        CVPixelBufferUnlockBaseAddress(out, [])
        return out
    }
    func _mask(_ instances: IndexSet, _ W: Int, _ H: Int) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, W, H, kCVPixelFormatType_OneComponent32Float, nil, &pb)
        guard let out = pb else { throw _vnError(.outOfMemory, "the mask could not be allocated") }
        CVPixelBufferLockBaseAddress(out, [])
        if let base = CVPixelBufferGetBaseAddress(out) {
            let bpr = CVPixelBufferGetBytesPerRow(out)
            for y in 0..<H { for x in 0..<W {
                let l = _labels[min(_h - 1, y * _h / H) * _w + min(_w - 1, x * _w / W)]
                base.storeBytes(of: instances.contains(Int(l)) ? Float(1) : 0, toByteOffset: y * bpr + x * 4, as: Float.self)
            } }
        }
        CVPixelBufferUnlockBaseAddress(out, [])
        return out
    }
    /// labels the mask's regions, largest first (at most `limit`), as instances
    static func _from(_ mask: [Bool], _ w: Int, _ h: Int, minimum: Int, limit: Int) -> VNInstanceMaskObservation {
        let comps = _vnComponents(mask, w, h).filter { $0.count >= minimum }.sorted { $0.count > $1.count }.prefix(limit)
        var labels = [UInt8](repeating: 0, count: w * h)
        for (n, c) in comps.enumerated() {
            for (y, r) in c.rows { for x in r.0...r.1 where mask[y * w + x] { labels[y * w + x] = UInt8(n + 1) } }
        }
        return VNInstanceMaskObservation(labels: labels, width: w, height: h, count: comps.count)
    }
}

@objc(VNGenerateForegroundInstanceMaskRequest) open class VNGenerateForegroundInstanceMaskRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        guard let s = try VNGenerateAttentionBasedSaliencyImageRequest()._run(img).first as? VNSaliencyImageObservation else { return [] }
        let pb = s.pixelBuffer, W = CVPixelBufferGetWidth(pb), H = CVPixelBufferGetHeight(pb)
        var mask = [Bool](repeating: false, count: W * H)
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        if let base = CVPixelBufferGetBaseAddress(pb) {
            let bpr = CVPixelBufferGetBytesPerRow(pb)
            for y in 0..<H { for x in 0..<W { mask[y * W + x] = base.load(fromByteOffset: y * bpr + x * 4, as: Float.self) >= 0.5 } }
        }
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        let o = VNInstanceMaskObservation._from(mask, W, H, minimum: 4, limit: 4)
        return o.allInstances.isEmpty ? [] : [o]
    }
}

@objc(VNGeneratePersonInstanceMaskRequest) open class VNGeneratePersonInstanceMaskRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let seg = VNGeneratePersonSegmentationRequest()
        seg.qualityLevel = .balanced
        guard let m = try seg._run(img).first as? VNPixelBufferObservation else { return [] }
        let pb = m.pixelBuffer, W = CVPixelBufferGetWidth(pb), H = CVPixelBufferGetHeight(pb)
        var mask = [Bool](repeating: false, count: W * H)
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        if let base = CVPixelBufferGetBaseAddress(pb) {
            let bpr = CVPixelBufferGetBytesPerRow(pb)
            for y in 0..<H { for x in 0..<W { mask[y * W + x] = base.load(fromByteOffset: y * bpr + x, as: UInt8.self) >= 128 } }
        }
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        let o = VNInstanceMaskObservation._from(mask, W, H, minimum: max(16, W * H / 400), limit: 4)
        return o.allInstances.isEmpty ? [] : [o]
    }
}

@objc(VNDetectDocumentSegmentationRequest) open class VNDetectDocumentSegmentationRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let r = VNDetectRectanglesRequest()
        r.minimumSize = 0.25; r.maximumObservations = 1; r.minimumAspectRatio = 0.3; r.maximumAspectRatio = 1; r.quadratureTolerance = 30
        return try r._run(img)
    }
}

// MARK: - aesthetics

@objc(VNImageAestheticsScoresObservation) open class VNImageAestheticsScoresObservation: VNObservation, @unchecked Sendable {
    /// -1 (poor) to 1 (good)
    @objc public let overallScore: Float
    /// documents, screenshots and receipts, rather than photos to keep
    @objc public let isUtility: Bool
    init(score: Float, utility: Bool) { overallScore = score; isUtility = utility; super.init() }
}

@objc(VNCalculateImageAestheticsScoresRequest) open class VNCalculateImageAestheticsScoresRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let s = max(1, max(img.width, img.height) / 256), W = max(3, img.width / s), H = max(3, img.height / s)
        var luma = [Float](repeating: 0, count: W * H)
        var sat: Float = 0, light = 0, flat = 0
        for y in 0..<H { for x in 0..<W {
            let i = (min(img.height - 1, y * s) * img.width + min(img.width - 1, x * s)) * 4
            let b = Float(img.bgra[i]) / 255, g = Float(img.bgra[i + 1]) / 255, r = Float(img.bgra[i + 2]) / 255
            let l = 0.299 * r + 0.587 * g + 0.114 * b
            luma[y * W + x] = l
            let mx = max(r, g, b), mn = min(r, g, b)
            sat += mx > 0 ? (mx - mn) / mx : 0
            if l > 0.85 { light += 1 }
        } }
        var lap: Float = 0, lapSq: Float = 0
        for y in 1..<(H - 1) { for x in 1..<(W - 1) {
            let c = luma[y * W + x]
            let v = 4 * c - luma[y * W + x - 1] - luma[y * W + x + 1] - luma[(y - 1) * W + x] - luma[(y + 1) * W + x]
            lap += v; lapSq += v * v
            if abs(v) < 0.01 { flat += 1 }
        } }
        let n = Float(W * H), inner = Float((W - 2) * (H - 2))
        let sharp = min(1, (lapSq / inner - (lap / inner) * (lap / inner)) * 200)
        let mean = luma.reduce(0, +) / n
        let exposure = 1 - min(1, abs(mean - 0.5) * 2)
        let colour = min(1, sat / n * 2)
        let utility = Float(flat) / inner > 0.6 && Float(light) / n > 0.5 && colour < 0.25
        let score = max(-1, min(1, (sharp * 0.4 + exposure * 0.35 + colour * 0.25) * 2 - 1 - (utility ? 0.4 : 0)))
        return [VNImageAestheticsScoresObservation(score: score, utility: utility)]
    }
}

// MARK: - video

/// runs requests over a video's frames
@objc(VNVideoProcessor) open class VNVideoProcessor: NSObject, @unchecked Sendable {
    /// how often a request sees a frame
    @objc(VNVideoProcessorCadence) open class Cadence: NSObject, NSCopying, @unchecked Sendable {
        @objc public func copy(with zone: NSZone? = nil) -> Any { self }
        func _interval(_ fps: Double) -> Double { 1 / max(1, fps) }
    }
    @objc(VNVideoProcessorFrameRateCadence) open class FrameRateCadence: Cadence, @unchecked Sendable {
        @objc public let frameRate: Int
        @objc(initWithFrameRate:) public init(frameRate: Int) { self.frameRate = frameRate }
        public convenience init(_ frameRate: Int) { self.init(frameRate: frameRate) }
        override func _interval(_ fps: Double) -> Double { 1 / Double(max(1, frameRate)) }
    }
    @objc(VNVideoProcessorTimeIntervalCadence) open class TimeIntervalCadence: Cadence, @unchecked Sendable {
        @objc public let timeInterval: CFTimeInterval
        @objc(initWithTimeInterval:) public init(timeInterval: CFTimeInterval) { self.timeInterval = timeInterval }
        public convenience init(_ timeInterval: CFTimeInterval) { self.init(timeInterval: timeInterval) }
        override func _interval(_ fps: Double) -> Double { max(0.001, timeInterval) }
    }
    @objc(VNVideoProcessorRequestProcessingOptions) open class RequestProcessingOptions: NSObject, NSCopying, @unchecked Sendable {
        @NSCopying @objc open var cadence: Cadence?
        @objc public func copy(with zone: NSZone? = nil) -> Any { let o = RequestProcessingOptions(); o.cadence = cadence; return o }
    }
    let url: URL
    var requests: [(VNRequest, RequestProcessingOptions)] = []
    var cancelled = false
    @objc(initWithURL:) public init(url videoURL: URL) { url = videoURL }
    @available(*, deprecated, renamed: "init(url:)")
    public convenience init(URL videoURL: URL) { self.init(url: videoURL) }
    @objc(addRequest:processingOptions:error:) open func addRequest(_ request: VNRequest, processingOptions: RequestProcessingOptions) throws {
        guard !requests.contains(where: { $0.0 === request }) else { throw _vnError(.invalidOperation, "the request is already added") }
        requests.append((request, processingOptions))
    }
    @objc(removeRequest:error:) open func removeRequest(_ request: VNRequest) throws {
        guard let i = requests.firstIndex(where: { $0.0 === request }) else { throw _vnError(.invalidOperation, "the request was not added") }
        requests.remove(at: i)
    }
    @objc open func cancel() { cancelled = true }
    /// performs the requests on the frames of that time range, in order, each at its cadence (blocks until done)
    open func analyze(_ timeRange: CMTimeRange) throws {
        cancelled = false
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { throw _vnError(.invalidImage, "the video has no video track") }
        let fps = Double(track.nominalFrameRate > 0 ? track.nominalFrameRate : 30)
        let start = timeRange.start.isNumeric ? timeRange.start.seconds : 0
        let end = timeRange.duration.isNumeric && timeRange.duration.seconds > 0 ? start + timeRange.duration.seconds : asset.duration.seconds
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let handler = VNSequenceRequestHandler()
        var next = requests.map { _ in start }
        var t = start
        while t < end, !cancelled {
            let due = requests.indices.filter { next[$0] <= t + 1e-6 }
            if !due.isEmpty {
                guard let frame = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) else { break }
                for i in due {
                    try handler.perform([requests[i].0], on: frame)
                    next[i] = t + (requests[i].1.cadence ?? FrameRateCadence(frameRate: Int(fps.rounded())))._interval(fps)
                }
            }
            t = next.min() ?? end
        }
        if cancelled { throw _vnError(.requestCancelled, "the analysis was cancelled") }
    }
}
