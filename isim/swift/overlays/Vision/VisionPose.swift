// isim Vision: pose, segmentation, classification and feature prints (issue #375). Apple's models are not on Linux,
// so these requests run models the host provides (adapted), through ONNX Runtime (runtime/host_onnx.c):
//   - VNDetectHumanBodyPoseRequest: ISIM_BODY_POSE_MODEL, a MoveNet single-pose export (17 COCO keypoints; neck and
//     root are the shoulders' and hips' midpoints);
//   - VNDetectHumanHandPoseRequest: ISIM_HAND_POSE_MODEL, MediaPipe's hand landmark model (21 points, handedness), run on
//     the whole image (one hand);
//   - VNGeneratePersonSegmentationRequest: ISIM_PERSON_SEGMENTATION_MODEL, MediaPipe's selfie segmentation (or any model
//     giving a person probability per pixel);
//   - VNClassifyImageRequest: ISIM_CLASSIFY_MODEL with its labels, one per line, in ISIM_CLASSIFY_LABELS (an ImageNet
//     classifier such as MobileNet; the scores become probabilities);
//   - VNGenerateImageFeaturePrintRequest: ISIM_FEATUREPRINT_MODEL's output vector, or without one isim's own print (a
//     16 x 16 grid of the image's colours and edges, 1,024 floats, unit length), so distances compare images;
//   - VNDetectAnimalBodyPoseRequest: no host model format is defined; it fails with VNError.unsupportedRequest.
// Without the model (or ONNX Runtime) a request fails with VNError.unsupportedRequest and a message naming what to set.
import UIKit
import CoreML
import isim_host

// MARK: - points and vectors

@objc(VNPoint) open class VNPoint: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let x: Double
    @objc public let y: Double
    @objc(initWithX:y:) public init(x: Double, y: Double) { self.x = x; self.y = y; super.init() }
    @objc(initWithLocation:) public convenience init(location: CGPoint) { self.init(x: location.x, y: location.y) }
    @objc open class var zero: VNPoint { VNPoint(x: 0, y: 0) }
    @objc open var location: CGPoint { CGPoint(x: x, y: y) }
    @objc(distanceToPoint:) open func distance(_ point: VNPoint) -> Double { ((x - point.x) * (x - point.x) + (y - point.y) * (y - point.y)).squareRoot() }
    @objc(distanceBetweenPoint:point:) open class func distance(_ a: VNPoint, _ b: VNPoint) -> Double { a.distance(b) }
    @objc(pointByApplyingVector:toPoint:) open class func apply(_ vector: VNVector, to point: VNPoint) -> VNPoint { VNPoint(x: point.x + vector.x, y: point.y + vector.y) }
    @objc public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) { coder.encode(x, forKey: "x"); coder.encode(y, forKey: "y") }
    @objc public required init?(coder: NSCoder) { x = coder.decodeDouble(forKey: "x"); y = coder.decodeDouble(forKey: "y"); super.init() }
    @objc open override func isEqual(_ object: Any?) -> Bool { (object as? VNPoint).map { $0.x == x && $0.y == y } ?? false }
    @objc open override var hash: Int { x.hashValue ^ (y.hashValue &* 31) }
    @objc open override var description: String { "[\(x); \(y)]" }
}
@objc(VNDetectedPoint) open class VNDetectedPoint: VNPoint, @unchecked Sendable {
    @objc public let confidence: VNConfidence
    init(x: Double, y: Double, confidence: VNConfidence) { self.confidence = confidence; super.init(x: x, y: y) }
    @objc public required init?(coder: NSCoder) { confidence = coder.decodeFloat(forKey: "confidence"); super.init(coder: coder) }
    @objc public override func encode(with coder: NSCoder) { super.encode(with: coder); coder.encode(confidence, forKey: "confidence") }
}
@objc(VNRecognizedPoint) open class VNRecognizedPoint: VNDetectedPoint, @unchecked Sendable {
    public let identifier: VNRecognizedPointKey
    init(identifier: VNRecognizedPointKey, x: Double, y: Double, confidence: VNConfidence) {
        self.identifier = identifier; super.init(x: x, y: y, confidence: confidence)
    }
    @objc public required init?(coder: NSCoder) {
        identifier = VNRecognizedPointKey(rawValue: coder.decodeObject(of: NSString.self, forKey: "identifier") as String? ?? "")
        super.init(coder: coder)
    }
    @objc public override func encode(with coder: NSCoder) { super.encode(with: coder); coder.encode(identifier.rawValue as NSString, forKey: "identifier") }
    @objc(identifier) var _objcIdentifier: String { identifier.rawValue }
}

@objc(VNVector) open class VNVector: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let x: Double
    @objc public let y: Double
    @objc(initWithXComponent:yComponent:) public init(xComponent x: Double, yComponent y: Double) { self.x = x; self.y = y; super.init() }
    @nonobjc public convenience init(XComponent x: Double, yComponent y: Double) { self.init(xComponent: x, yComponent: y) }
    @objc(initWithR:theta:) public convenience init(r: Double, theta: Double) { self.init(xComponent: r * cos(theta), yComponent: r * sin(theta)) }
    @objc(initWithVectorHead:tail:) public convenience init(vectorHead head: VNPoint, tail: VNPoint) { self.init(xComponent: head.x - tail.x, yComponent: head.y - tail.y) }
    @nonobjc public convenience init(byAdding v1: VNVector, to v2: VNVector) { self.init(xComponent: v1.x + v2.x, yComponent: v1.y + v2.y) }
    @nonobjc public convenience init(byAddingVector v1: VNVector, toVector v2: VNVector) { self.init(byAdding: v1, to: v2) }
    @nonobjc public convenience init(bySubtracting v1: VNVector, from v2: VNVector) { self.init(xComponent: v2.x - v1.x, yComponent: v2.y - v1.y) }
    @nonobjc public convenience init(bySubtractingVector v1: VNVector, fromVector v2: VNVector) { self.init(bySubtracting: v1, from: v2) }
    @nonobjc public convenience init(byMultiplying v: VNVector, byScalar s: Double) { self.init(xComponent: v.x * s, yComponent: v.y * s) }
    @nonobjc public convenience init(byMultiplyingVector v: VNVector, byScalar s: Double) { self.init(byMultiplying: v, byScalar: s) }
    @objc open class var zero: VNVector { VNVector(xComponent: 0, yComponent: 0) }
    @objc open var r: Double { length }
    @objc open var theta: Double { atan2(y, x) }
    @objc open var length: Double { squaredLength.squareRoot() }
    @objc open var squaredLength: Double { x * x + y * y }
    @objc(dotProductOfVector:vector:) open class func dotProduct(of v: VNVector, vector w: VNVector) -> Double { v.x * w.x + v.y * w.y }
    @objc(unitVectorForVector:) open class func unitVector(for v: VNVector) -> VNVector {
        let l = v.length
        return l > 0 ? VNVector(xComponent: v.x / l, yComponent: v.y / l) : VNVector.zero
    }
    @objc(vectorByAddingVector:toVector:) class func _objcAdd(_ a: VNVector, _ b: VNVector) -> VNVector { VNVector(byAdding: a, to: b) }
    @objc(vectorBySubtractingVector:fromVector:) class func _objcSubtract(_ a: VNVector, _ b: VNVector) -> VNVector { VNVector(bySubtracting: a, from: b) }
    @objc(vectorByMultiplyingVector:byScalar:) class func _objcMultiply(_ a: VNVector, _ s: Double) -> VNVector { VNVector(byMultiplying: a, byScalar: s) }
    @objc public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) { coder.encode(x, forKey: "x"); coder.encode(y, forKey: "y") }
    @objc public required init?(coder: NSCoder) { x = coder.decodeDouble(forKey: "x"); y = coder.decodeDouble(forKey: "y"); super.init() }
    @objc open override func isEqual(_ object: Any?) -> Bool { (object as? VNVector).map { $0.x == x && $0.y == y } ?? false }
    @objc open override var hash: Int { x.hashValue ^ (y.hashValue &* 31) }
}

public struct VNRecognizedPointKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}
public struct VNRecognizedPointGroupKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let all = VNRecognizedPointGroupKey(rawValue: "VNIPOAll")
}

@objc public enum VNChirality: Int, Sendable { case unknown = 0, left = -1, right = 1 }
@objc public enum VNImageCropAndScaleOption: UInt, Sendable {
    case centerCrop = 0, scaleFit = 1, scaleFill = 2, scaleFitRotate90CCW = 0x101, scaleFillRotate90CCW = 0x102
}
@objc public enum VNElementType: UInt, Sendable { case unknown = 0, float = 1, double = 2 }

// MARK: - points observations

@objc(VNRecognizedPointsObservation) open class VNRecognizedPointsObservation: VNObservation, @unchecked Sendable {
    let _points: [VNRecognizedPointKey: VNRecognizedPoint]
    let _order: [VNRecognizedPointKey]
    let _groups: [VNRecognizedPointGroupKey: [VNRecognizedPointKey]]
    init(points: [VNRecognizedPoint], groups: [VNRecognizedPointGroupKey: [VNRecognizedPointKey]]) {
        _order = points.map(\.identifier)
        _points = Dictionary(points.map { ($0.identifier, $0) }, uniquingKeysWith: { a, _ in a })
        var g = groups
        g[.all] = _order
        _groups = g
        super.init()
        confidence = points.isEmpty ? 0 : points.map(\.confidence).reduce(0, +) / Float(points.count)
    }
    public var availableKeys: [VNRecognizedPointKey] { _order }
    public var availableGroupKeys: [VNRecognizedPointGroupKey] { Array(_groups.keys).sorted { $0.rawValue < $1.rawValue } }
    public func recognizedPoint(forKey pointKey: VNRecognizedPointKey) throws -> VNRecognizedPoint {
        guard let p = _points[pointKey] else { throw _vnError(.invalidArgument, "no point \(pointKey.rawValue) in this observation") }
        return p
    }
    public func recognizedPoints(forGroupKey groupKey: VNRecognizedPointGroupKey) throws -> [VNRecognizedPointKey: VNRecognizedPoint] {
        guard let keys = _groups[groupKey] else { throw _vnError(.invalidArgument, "no group \(groupKey.rawValue) in this observation") }
        var out: [VNRecognizedPointKey: VNRecognizedPoint] = [:]
        for k in keys { if let p = _points[k] { out[k] = p } }
        return out
    }
    /// the points as a 3 x N array: x, y (normalized, lower-left origin) and confidence, in `availableKeys` order
    @objc(keypointsMultiArrayAndReturnError:) open func keypointsMultiArray() throws -> MLMultiArray {
        let a = try MLMultiArray(shape: [3, NSNumber(value: _order.count)], dataType: .float32)
        let p = a.dataPointer.assumingMemoryBound(to: Float.self)
        for (i, k) in _order.enumerated() {
            let pt = _points[k]!
            p[i] = Float(pt.x); p[_order.count + i] = Float(pt.y); p[2 * _order.count + i] = pt.confidence
        }
        return a
    }
    @objc(availableKeys) var _objcAvailableKeys: [String] { _order.map(\.rawValue) }
    @objc(availableGroupKeys) var _objcAvailableGroupKeys: [String] { availableGroupKeys.map(\.rawValue) }
    @objc(recognizedPointForKey:error:) func _objcPoint(_ key: String) throws -> VNRecognizedPoint { try recognizedPoint(forKey: VNRecognizedPointKey(rawValue: key)) }
    @objc(recognizedPointsForGroupKey:error:) func _objcPoints(_ key: String) throws -> [String: VNRecognizedPoint] {
        Dictionary(uniqueKeysWithValues: try recognizedPoints(forGroupKey: VNRecognizedPointGroupKey(rawValue: key)).map { ($0.key.rawValue, $0.value) })
    }
}

@objc(VNHumanBodyPoseObservation) open class VNHumanBodyPoseObservation: VNRecognizedPointsObservation, @unchecked Sendable {
    public struct JointName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointKey
        public init(rawValue: VNRecognizedPointKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointKey(rawValue: s) }
        public static let nose = JointName("head_joint"), leftEye = JointName("left_eye_joint"), rightEye = JointName("right_eye_joint")
        public static let leftEar = JointName("left_ear_joint"), rightEar = JointName("right_ear_joint"), neck = JointName("neck_1_joint")
        public static let leftShoulder = JointName("left_shoulder_1_joint"), rightShoulder = JointName("right_shoulder_1_joint")
        public static let leftElbow = JointName("left_forearm_joint"), rightElbow = JointName("right_forearm_joint")
        public static let leftWrist = JointName("left_hand_joint"), rightWrist = JointName("right_hand_joint"), root = JointName("root")
        public static let leftHip = JointName("left_upLeg_joint"), rightHip = JointName("right_upLeg_joint")
        public static let leftKnee = JointName("left_leg_joint"), rightKnee = JointName("right_leg_joint")
        public static let leftAnkle = JointName("left_foot_joint"), rightAnkle = JointName("right_foot_joint")
        static let ordered: [JointName] = [.nose, .leftEye, .rightEye, .leftEar, .rightEar, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
                                           .leftWrist, .rightWrist, .root, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
    }
    public struct JointsGroupName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointGroupKey
        public init(rawValue: VNRecognizedPointGroupKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointGroupKey(rawValue: s) }
        public static let face = JointsGroupName("VNBLKFACE"), torso = JointsGroupName("VNBLKTORSO")
        public static let leftArm = JointsGroupName("VNBLKLARM"), rightArm = JointsGroupName("VNBLKRARM")
        public static let leftLeg = JointsGroupName("VNBLKLLEG"), rightLeg = JointsGroupName("VNBLKRLEG"), all = JointsGroupName(rawValue: .all)
        static let members: [JointsGroupName: [JointName]] = [
            .face: [.nose, .leftEye, .rightEye, .leftEar, .rightEar], .torso: [.neck, .leftShoulder, .rightShoulder, .root, .leftHip, .rightHip],
            .leftArm: [.leftShoulder, .leftElbow, .leftWrist], .rightArm: [.rightShoulder, .rightElbow, .rightWrist],
            .leftLeg: [.leftHip, .leftKnee, .leftAnkle], .rightLeg: [.rightHip, .rightKnee, .rightAnkle]]
    }
    init(points: [VNRecognizedPoint]) {
        super.init(points: points, groups: Dictionary(uniqueKeysWithValues: JointsGroupName.members.map { ($0.key.rawValue, $0.value.map(\.rawValue)) }))
    }
    public var availableJointNames: [JointName] { availableKeys.map(JointName.init(rawValue:)) }
    public var availableJointsGroupNames: [JointsGroupName] { availableGroupKeys.map(JointsGroupName.init(rawValue:)) }
    public func recognizedPoint(_ jointName: JointName) throws -> VNRecognizedPoint { try recognizedPoint(forKey: jointName.rawValue) }
    public func recognizedPoints(_ jointsGroupName: JointsGroupName) throws -> [JointName: VNRecognizedPoint] {
        Dictionary(uniqueKeysWithValues: try recognizedPoints(forGroupKey: jointsGroupName.rawValue).map { (JointName(rawValue: $0.key), $0.value) })
    }
}

@objc(VNHumanHandPoseObservation) open class VNHumanHandPoseObservation: VNRecognizedPointsObservation, @unchecked Sendable {
    public struct JointName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointKey
        public init(rawValue: VNRecognizedPointKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointKey(rawValue: s) }
        public static let wrist = JointName("VNHLKWRI")
        public static let thumbCMC = JointName("VNHLKTCMC"), thumbMP = JointName("VNHLKTMP"), thumbIP = JointName("VNHLKTIP"), thumbTip = JointName("VNHLKTTIP")
        public static let indexMCP = JointName("VNHLKIMCP"), indexPIP = JointName("VNHLKIPIP"), indexDIP = JointName("VNHLKIDIP"), indexTip = JointName("VNHLKITIP")
        public static let middleMCP = JointName("VNHLKMMCP"), middlePIP = JointName("VNHLKMPIP"), middleDIP = JointName("VNHLKMDIP"), middleTip = JointName("VNHLKMTIP")
        public static let ringMCP = JointName("VNHLKRMCP"), ringPIP = JointName("VNHLKRPIP"), ringDIP = JointName("VNHLKRDIP"), ringTip = JointName("VNHLKRTIP")
        public static let littleMCP = JointName("VNHLKPMCP"), littlePIP = JointName("VNHLKPPIP"), littleDIP = JointName("VNHLKPDIP"), littleTip = JointName("VNHLKPTIP")
        /// MediaPipe's landmark order
        static let ordered: [JointName] = [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip, .indexMCP, .indexPIP, .indexDIP, .indexTip,
                                           .middleMCP, .middlePIP, .middleDIP, .middleTip, .ringMCP, .ringPIP, .ringDIP, .ringTip,
                                           .littleMCP, .littlePIP, .littleDIP, .littleTip]
    }
    public struct JointsGroupName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointGroupKey
        public init(rawValue: VNRecognizedPointGroupKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointGroupKey(rawValue: s) }
        public static let thumb = JointsGroupName("VNHLRKT"), indexFinger = JointsGroupName("VNHLRKI"), middleFinger = JointsGroupName("VNHLRKM")
        public static let ringFinger = JointsGroupName("VNHLRKR"), littleFinger = JointsGroupName("VNHLRKP"), all = JointsGroupName(rawValue: .all)
        static let members: [JointsGroupName: [JointName]] = [
            .thumb: [.thumbCMC, .thumbMP, .thumbIP, .thumbTip], .indexFinger: [.indexMCP, .indexPIP, .indexDIP, .indexTip],
            .middleFinger: [.middleMCP, .middlePIP, .middleDIP, .middleTip], .ringFinger: [.ringMCP, .ringPIP, .ringDIP, .ringTip],
            .littleFinger: [.littleMCP, .littlePIP, .littleDIP, .littleTip]]
    }
    @objc public let chirality: VNChirality
    init(points: [VNRecognizedPoint], chirality: VNChirality) {
        self.chirality = chirality
        super.init(points: points, groups: Dictionary(uniqueKeysWithValues: JointsGroupName.members.map { ($0.key.rawValue, $0.value.map(\.rawValue)) }))
    }
    public var availableJointNames: [JointName] { availableKeys.map(JointName.init(rawValue:)) }
    public var availableJointsGroupNames: [JointsGroupName] { availableGroupKeys.map(JointsGroupName.init(rawValue:)) }
    public func recognizedPoint(_ jointName: JointName) throws -> VNRecognizedPoint { try recognizedPoint(forKey: jointName.rawValue) }
    public func recognizedPoints(_ jointsGroupName: JointsGroupName) throws -> [JointName: VNRecognizedPoint] {
        Dictionary(uniqueKeysWithValues: try recognizedPoints(forGroupKey: jointsGroupName.rawValue).map { (JointName(rawValue: $0.key), $0.value) })
    }
}

@objc(VNAnimalBodyPoseObservation) open class VNAnimalBodyPoseObservation: VNRecognizedPointsObservation, @unchecked Sendable {
    public struct JointName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointKey
        public init(rawValue: VNRecognizedPointKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointKey(rawValue: s) }
        public static let leftEarTop = JointName("animal_joint_left_ear_top"), leftEarMiddle = JointName("animal_joint_left_ear_middle")
        public static let leftEarBottom = JointName("animal_joint_left_ear_bottom"), rightEarTop = JointName("animal_joint_right_ear_top")
        public static let rightEarMiddle = JointName("animal_joint_right_ear_middle"), rightEarBottom = JointName("animal_joint_right_ear_bottom")
        public static let leftEye = JointName("animal_joint_left_eye"), rightEye = JointName("animal_joint_right_eye")
        public static let nose = JointName("animal_joint_nose"), neck = JointName("animal_joint_neck")
        public static let leftFrontElbow = JointName("animal_joint_left_front_elbow"), rightFrontElbow = JointName("animal_joint_right_front_elbow")
        public static let leftFrontKnee = JointName("animal_joint_left_front_knee"), rightFrontKnee = JointName("animal_joint_right_front_knee")
        public static let leftFrontPaw = JointName("animal_joint_left_front_paw"), rightFrontPaw = JointName("animal_joint_right_front_paw")
        public static let leftBackElbow = JointName("animal_joint_left_back_elbow"), rightBackElbow = JointName("animal_joint_right_back_elbow")
        public static let leftBackKnee = JointName("animal_joint_left_back_knee"), rightBackKnee = JointName("animal_joint_right_back_knee")
        public static let leftBackPaw = JointName("animal_joint_left_back_paw"), rightBackPaw = JointName("animal_joint_right_back_paw")
        public static let tailTop = JointName("animal_joint_tail_top"), tailMiddle = JointName("animal_joint_tail_middle"), tailBottom = JointName("animal_joint_tail_bottom")
        static let all: [JointName] = [.leftEarTop, .leftEarMiddle, .leftEarBottom, .rightEarTop, .rightEarMiddle, .rightEarBottom, .leftEye, .rightEye,
                                       .nose, .neck, .leftFrontElbow, .rightFrontElbow, .leftFrontKnee, .rightFrontKnee, .leftFrontPaw, .rightFrontPaw,
                                       .leftBackElbow, .rightBackElbow, .leftBackKnee, .rightBackKnee, .leftBackPaw, .rightBackPaw,
                                       .tailTop, .tailMiddle, .tailBottom]
    }
    public struct JointsGroupName: RawRepresentable, Hashable, Sendable {
        public let rawValue: VNRecognizedPointGroupKey
        public init(rawValue: VNRecognizedPointGroupKey) { self.rawValue = rawValue }
        init(_ s: String) { rawValue = VNRecognizedPointGroupKey(rawValue: s) }
        public static let head = JointsGroupName("animal_group_head"), trunk = JointsGroupName("animal_group_trunk")
        public static let forelegs = JointsGroupName("animal_group_forelegs"), hindlegs = JointsGroupName("animal_group_hindlegs")
        public static let tail = JointsGroupName("animal_group_tail"), all = JointsGroupName(rawValue: .all)
    }
    public var availableJointNames: [JointName] { availableKeys.map(JointName.init(rawValue:)) }
    public var availableJointGroupNames: [JointsGroupName] { availableGroupKeys.map(JointsGroupName.init(rawValue:)) }
    public func recognizedPoint(_ jointName: JointName) throws -> VNRecognizedPoint { try recognizedPoint(forKey: jointName.rawValue) }
    public func recognizedPoints(_ jointsGroupName: JointsGroupName) throws -> [JointName: VNRecognizedPoint] {
        Dictionary(uniqueKeysWithValues: try recognizedPoints(forGroupKey: jointsGroupName.rawValue).map { (JointName(rawValue: $0.key), $0.value) })
    }
}

@objc(VNFeaturePrintObservation) open class VNFeaturePrintObservation: VNObservation, NSSecureCoding, @unchecked Sendable {
    @objc public let data: Data
    @objc open var elementType: VNElementType { .float }
    @objc open var elementCount: Int { data.count / 4 }
    init(values: [Float]) { data = values.withUnsafeBytes { Data($0) }; super.init() }
    var _values: [Float] { data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) } }
    /// the Euclidean distance between the two prints
    @objc(computeDistance:toFeaturePrintObservation:error:)
    open func computeDistance(_ outDistance: UnsafeMutablePointer<Float>, to featurePrint: VNFeaturePrintObservation) throws {
        let a = _values, b = featurePrint._values
        guard a.count == b.count else { throw _vnError(.invalidArgument, "the feature prints have different sizes (\(a.count) and \(b.count))") }
        var s: Float = 0
        for i in a.indices { let d = a[i] - b[i]; s += d * d }
        outDistance.pointee = s.squareRoot()
    }
    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) { coder.encode(data as NSData, forKey: "data") }
    @objc public required init?(coder: NSCoder) {
        guard let d = coder.decodeObject(of: NSData.self, forKey: "data") else { return nil }
        data = d as Data; super.init()
    }
}

// MARK: - host models

/// A host ONNX model named by an environment variable.
struct _VNHostModel {
    let handle: Int32
    let dims: [Int64]
    let type: Int32
    static var _cache: [String: Int32] = [:]
    static let _lock = NSLock()
    /// the model of `variable`, or a VNError.unsupportedRequest saying what `what` needs
    static func open(_ variable: String, _ what: String, example: String) throws -> _VNHostModel {
        guard let path = ProcessInfo.processInfo.environment[variable], !path.isEmpty else {
            throw _vnError(.unsupportedRequest, "\(what) on isim needs a host model: \(variable)=\(example) (Apple's models are not available)")
        }
        _lock.lock(); defer { _lock.unlock() }
        let h = isim_onnx_open(path)
        guard h > 0 else { throw _vnError(.unsupportedRequest, "\(what): \(String(cString: isim_onnx_error()))") }
        var d = [Int64](repeating: 0, count: 8), t: Int32 = 0
        let rank = Int(isim_onnx_input(h, &d, &t))
        return _VNHostModel(handle: h, dims: Array(d.prefix(max(0, rank))), type: t)
    }
    /// The model's input from an image: resized (stretched) to the model's size (`fallback` for dynamic sizes), its
    /// RGB values mapped by `map` (0...255 in), NHWC unless the channels come first.
    func input(_ img: _VNImage, fallback: Int, map: (Float, Int) -> Float) -> ([Float], [Int64]) {
        let nchw = dims.count == 4 && dims[1] == 3
        let h = Int(dims.count == 4 ? (nchw ? dims[2] : dims[1]) : -1), w = Int(dims.count == 4 ? (nchw ? dims[3] : dims[2]) : -1)
        let H = h > 0 ? h : fallback, W = w > 0 ? w : fallback
        var out = [Float](repeating: 0, count: 3 * W * H)
        img.bgra.withUnsafeBufferPointer { p in
            for y in 0..<H {
                let sy = min(img.height - 1, y * img.height / H)
                for x in 0..<W {
                    let sx = min(img.width - 1, x * img.width / W), i = (sy * img.width + sx) * 4
                    let a = 255 - Float(p[i + 3])                    // premultiplied: over white
                    let rgb = [Float(p[i + 2]) + a, Float(p[i + 1]) + a, Float(p[i]) + a]
                    for c in 0..<3 {
                        let v = map(min(255, rgb[c]), c)
                        if nchw { out[c * W * H + y * W + x] = v } else { out[(y * W + x) * 3 + c] = v }
                    }
                }
            }
        }
        return (out, nchw ? [1, 3, Int64(H), Int64(W)] : [1, Int64(H), Int64(W), 3])
    }
    /// runs the model: its outputs, each as floats
    func run(_ input: [Float], _ shape: [Int64], _ what: String, capacity: Int = 1 << 22) throws -> [[Float]] {
        var out = [Float](repeating: 0, count: capacity), counts = [Int](repeating: 0, count: 8)
        let n = input.withUnsafeBufferPointer { i in shape.withUnsafeBufferPointer { s in
            out.withUnsafeMutableBufferPointer { o in counts.withUnsafeMutableBufferPointer { c in
                isim_onnx_run(handle, i.baseAddress!, s.baseAddress!, Int32(shape.count), o.baseAddress!, capacity, c.baseAddress!)
            } }
        } }
        guard n > 0 else { throw _vnError(.operationFailed, "\(what): \(String(cString: isim_onnx_error()))") }
        var res: [[Float]] = [], at = 0
        for k in 0..<Int(n) { let c = min(counts[k], capacity - at); res.append(Array(out[at..<(at + c)])); at += c }
        return res
    }
}

// MARK: - requests

@objc(VNDetectHumanBodyPoseRequest) open class VNDetectHumanBodyPoseRequest: VNImageBasedRequest, @unchecked Sendable {
    public typealias JointName = VNHumanBodyPoseObservation.JointName
    public typealias JointsGroupName = VNHumanBodyPoseObservation.JointsGroupName
    public var supportedJointNames: [JointName] { JointName.ordered }
    public var supportedJointsGroupNames: [JointsGroupName] { [.face, .torso, .leftArm, .rightArm, .leftLeg, .rightLeg, .all] }
    public class func supportedJointNames(forRevision revision: Int) throws -> [JointName] { JointName.ordered }
    public class func supportedJointsGroupNames(forRevision revision: Int) throws -> [JointsGroupName] { [.face, .torso, .leftArm, .rightArm, .leftLeg, .rightLeg, .all] }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let m = try _VNHostModel.open("ISIM_BODY_POSE_MODEL", "human body pose detection", example: "movenet-singlepose.onnx")
        let (input, shape) = m.input(img, fallback: 192) { v, _ in v }
        guard let k = try m.run(input, shape, "human body pose detection").first(where: { $0.count >= 51 }) else {
            throw _vnError(.operationFailed, "the body pose model's output is not MoveNet's 17 x (y, x, score)")
        }
        /* MoveNet: COCO keypoints, (y, x, score) normalized with a top-left origin */
        let coco: [JointName] = [.nose, .leftEye, .rightEye, .leftEar, .rightEar, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
                                 .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
        var pts: [JointName: (Double, Double, Float)] = [:]
        for (i, j) in coco.enumerated() { pts[j] = (Double(k[i * 3 + 1]), 1 - Double(k[i * 3]), k[i * 3 + 2]) }
        func mid(_ a: JointName, _ b: JointName) -> (Double, Double, Float) {
            let p = pts[a]!, q = pts[b]!
            return ((p.0 + q.0) / 2, (p.1 + q.1) / 2, min(p.2, q.2))
        }
        pts[.neck] = mid(.leftShoulder, .rightShoulder); pts[.root] = mid(.leftHip, .rightHip)
        let points = JointName.ordered.map { j in VNRecognizedPoint(identifier: j.rawValue, x: pts[j]!.0, y: pts[j]!.1, confidence: pts[j]!.2) }
        guard points.contains(where: { $0.confidence > 0.1 }) else { return [] }
        return [VNHumanBodyPoseObservation(points: points)]
    }
    @objc(supportedJointNamesAndReturnError:) func _objcJointNames() throws -> [String] { supportedJointNames.map(\.rawValue.rawValue) }
    @objc(supportedJointsGroupNamesAndReturnError:) func _objcGroupNames() throws -> [String] { supportedJointsGroupNames.map(\.rawValue.rawValue) }
}

@objc(VNDetectHumanHandPoseRequest) open class VNDetectHumanHandPoseRequest: VNImageBasedRequest, @unchecked Sendable {
    public typealias JointName = VNHumanHandPoseObservation.JointName
    public typealias JointsGroupName = VNHumanHandPoseObservation.JointsGroupName
    /// isim: the model sees the whole image and finds one hand
    @objc open var maximumHandCount = 2
    public var supportedJointNames: [JointName] { JointName.ordered }
    public var supportedJointsGroupNames: [JointsGroupName] { [.thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger, .all] }
    public class func supportedJointNames(forRevision revision: Int) throws -> [JointName] { JointName.ordered }
    public class func supportedJointsGroupNames(forRevision revision: Int) throws -> [JointsGroupName] { [.thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger, .all] }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        guard maximumHandCount > 0 else { return [] }
        let m = try _VNHostModel.open("ISIM_HAND_POSE_MODEL", "hand pose detection", example: "hand_landmark.onnx")
        let (input, shape) = m.input(img, fallback: 224) { v, _ in v / 255 }
        let outs = try m.run(input, shape, "hand pose detection")
        guard let marks = outs.first(where: { $0.count == 63 }) else { throw _vnError(.operationFailed, "the hand model's output is not MediaPipe's 21 x (x, y, z)") }
        let singles = outs.filter { $0.count == 1 }.map { $0[0] }
        let presence = singles.first ?? 1, handedness = singles.count > 1 ? singles[1] : 0.5
        guard presence > 0.5 else { return [] }
        let size = Double(shape.count == 4 ? (shape[1] == 3 ? shape[3] : shape[2]) : 224)
        let points = JointName.ordered.enumerated().map { i, j in
            VNRecognizedPoint(identifier: j.rawValue, x: Double(marks[i * 3]) / size, y: 1 - Double(marks[i * 3 + 1]) / size, confidence: presence)
        }
        return [VNHumanHandPoseObservation(points: points, chirality: handedness > 0.5 ? .right : .left)]
    }
    @objc(supportedJointNamesAndReturnError:) func _objcJointNames() throws -> [String] { supportedJointNames.map(\.rawValue.rawValue) }
    @objc(supportedJointsGroupNamesAndReturnError:) func _objcGroupNames() throws -> [String] { supportedJointsGroupNames.map(\.rawValue.rawValue) }
}

@objc(VNDetectAnimalBodyPoseRequest) open class VNDetectAnimalBodyPoseRequest: VNImageBasedRequest, @unchecked Sendable {
    public var supportedJointNames: [VNAnimalBodyPoseObservation.JointName] { VNAnimalBodyPoseObservation.JointName.all }
    public var supportedJointsGroupNames: [VNAnimalBodyPoseObservation.JointsGroupName] { [.head, .trunk, .forelegs, .hindlegs, .tail, .all] }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        throw _vnError(.unsupportedRequest, "animal body pose detection is not available on isim (it needs Apple's model; no host model is supported)")
    }
}

@objc(VNGeneratePersonSegmentationRequest) open class VNGeneratePersonSegmentationRequest: VNImageBasedRequest, _VNWholeFrame, @unchecked Sendable {
    @objc(VNGeneratePersonSegmentationRequestQualityLevel) public enum QualityLevel: UInt, Sendable { case accurate = 0, balanced = 1, fast = 2 }
    /// the mask's size: the model's (fast), twice it (balanced) or the image's, at most 1,024 pixels (accurate)
    @objc open var qualityLevel: QualityLevel = .accurate
    /// kCVPixelFormatType_OneComponent8 (the default), OneComponent16Half or OneComponent32Float
    @objc open var outputPixelFormat: OSType = kCVPixelFormatType_OneComponent8
    @objc public override init() { super.init() }
    @objc public override init(completionHandler: VNRequestCompletionHandler?) { super.init(completionHandler: completionHandler) }
    @objc(supportedOutputPixelFormatsAndReturnError:) open func supportedOutputPixelFormats() throws -> [NSNumber] {
        [kCVPixelFormatType_OneComponent8, kCVPixelFormatType_OneComponent16Half, kCVPixelFormatType_OneComponent32Float].map { NSNumber(value: $0) }
    }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        guard [kCVPixelFormatType_OneComponent8, kCVPixelFormatType_OneComponent16Half, kCVPixelFormatType_OneComponent32Float].contains(outputPixelFormat) else {
            throw _vnError(.invalidOption, "the person mask's pixel format must be OneComponent8, OneComponent16Half or OneComponent32Float")
        }
        let m = try _VNHostModel.open("ISIM_PERSON_SEGMENTATION_MODEL", "person segmentation", example: "selfie_segmentation.onnx")
        let (input, shape) = m.input(img, fallback: 256) { v, _ in v / 255 }
        let mh = Int(shape[1] == 3 ? shape[2] : shape[1]), mw = Int(shape[1] == 3 ? shape[3] : shape[2])
        guard let probs = try m.run(input, shape, "person segmentation").first(where: { $0.count == mw * mh || $0.count == 2 * mw * mh }) else {
            throw _vnError(.operationFailed, "the segmentation model's output is not a mask of its input's size")
        }
        let two = probs.count == 2 * mw * mh          // two channels (background, person), interleaved: the person's
        func p(_ x: Int, _ y: Int) -> Float { two ? probs[(y * mw + x) * 2 + 1] : probs[y * mw + x] }
        let s = qualityLevel == .fast ? 1.0 : qualityLevel == .balanced ? 2.0 : min(1024.0 / Double(max(img.width, img.height)), 1) * Double(img.width) / Double(mw)
        let W = max(1, Int(Double(mw) * s)), H = max(1, Int(Double(mh) * s * (qualityLevel == .accurate ? Double(img.height) / Double(img.width) * Double(mw) / Double(mh) : 1)))
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, W, H, outputPixelFormat, nil, &pb)
        guard let buffer = pb else { throw _vnError(.outOfMemory, "the person mask could not be allocated") }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let bpr = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<H { for x in 0..<W {
                /* bilinear from the model's mask */
                let fx = (Float(x) + 0.5) * Float(mw) / Float(W) - 0.5, fy = (Float(y) + 0.5) * Float(mh) / Float(H) - 0.5
                let x0 = max(0, min(mw - 1, Int(fx))), y0 = max(0, min(mh - 1, Int(fy))), x1 = min(mw - 1, x0 + 1), y1 = min(mh - 1, y0 + 1)
                let ax = max(0, min(1, fx - Float(x0))), ay = max(0, min(1, fy - Float(y0)))
                let v = max(0, min(1, (p(x0, y0) * (1 - ax) + p(x1, y0) * ax) * (1 - ay) + (p(x0, y1) * (1 - ax) + p(x1, y1) * ax) * ay))
                let row = base.advanced(by: y * bpr)
                switch outputPixelFormat {
                case kCVPixelFormatType_OneComponent8: row.storeBytes(of: UInt8(v * 255 + 0.5), toByteOffset: x, as: UInt8.self)
                case kCVPixelFormatType_OneComponent16Half: row.storeBytes(of: _isimHalf(v), toByteOffset: x * 2, as: UInt16.self)
                default: row.storeBytes(of: v, toByteOffset: x * 4, as: Float.self)
                }
            } }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return [VNPixelBufferObservation(pixelBuffer: buffer, featureName: nil)]
    }
}

@objc(VNClassifyImageRequest) open class VNClassifyImageRequest: VNImageBasedRequest, @unchecked Sendable {
    static func labels() throws -> [String] {
        guard let path = ProcessInfo.processInfo.environment["ISIM_CLASSIFY_LABELS"], !path.isEmpty,
              let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw _vnError(.unsupportedRequest, "image classification on isim needs a host model and its labels: ISIM_CLASSIFY_MODEL=mobilenet.onnx ISIM_CLASSIFY_LABELS=labels.txt (Apple's taxonomy is not available)")
        }
        return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    /// the labels of the host's classifier
    @objc(supportedIdentifiersAndReturnError:) open func supportedIdentifiers() throws -> [String] { try Self.labels() }
    @objc(knownClassificationsForRevision:error:) open class func knownClassifications(forRevision requestRevision: Int) throws -> [VNClassificationObservation] {
        try labels().map { VNClassificationObservation(identifier: $0, confidence: 0) }
    }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let labels = try Self.labels()
        let m = try _VNHostModel.open("ISIM_CLASSIFY_MODEL", "image classification", example: "mobilenet.onnx")
        let mean: [Float] = [0.485, 0.456, 0.406], std: [Float] = [0.229, 0.224, 0.225]   // ImageNet's
        let (input, shape) = m.input(img, fallback: 224) { v, c in (v / 255 - mean[c]) / std[c] }
        guard var scores = try m.run(input, shape, "image classification").first(where: { $0.count >= labels.count }) else {
            throw _vnError(.operationFailed, "the classifier gives fewer scores than ISIM_CLASSIFY_LABELS has labels")
        }
        scores = Array(scores.suffix(labels.count))   // a 1,001-class model's background class first
        /* probabilities: softmax unless they already are */
        if scores.contains(where: { $0 < 0 || $0 > 1 }) || abs(scores.reduce(0, +) - 1) > 0.01 {
            let top = scores.max() ?? 0
            let e = scores.map { Foundation.exp(Double($0 - top)) }, sum = e.reduce(0, +)
            scores = e.map { Float($0 / sum) }
        }
        return zip(labels, scores).sorted { $0.1 > $1.1 }.map { VNClassificationObservation(identifier: $0.0, confidence: $0.1) }
    }
}

@objc(VNGenerateImageFeaturePrintRequest) open class VNGenerateImageFeaturePrintRequest: VNImageBasedRequest, @unchecked Sendable {
    @objc open var imageCropAndScaleOption: VNImageCropAndScaleOption = .scaleFill
    @objc open override class var supportedRevisions: IndexSet { IndexSet([1, 2]) }
    @objc open override class var defaultRevision: Int { 2 }
    @objc open override class var currentRevision: Int { 2 }
    /// the image as the crop and scale option shapes it, square
    func _shaped(_ img: _VNImage) -> _VNImage {
        guard imageCropAndScaleOption == .centerCrop, img.width != img.height else { return img }
        let s = min(img.width, img.height), x0 = (img.width - s) / 2, y0 = (img.height - s) / 2
        var out = [UInt8](repeating: 0, count: s * s * 4)
        for y in 0..<s { for x in 0..<s { for k in 0..<4 { out[(y * s + x) * 4 + k] = img.bgra[((y + y0) * img.width + x + x0) * 4 + k] } } }
        return _VNImage(width: s, height: s, bgra: out)
    }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let shaped = _shaped(img)
        if let path = ProcessInfo.processInfo.environment["ISIM_FEATUREPRINT_MODEL"], !path.isEmpty {
            let m = try _VNHostModel.open("ISIM_FEATUREPRINT_MODEL", "image feature prints", example: "mobilenet-features.onnx")
            let mean: [Float] = [0.485, 0.456, 0.406], std: [Float] = [0.229, 0.224, 0.225]
            let (input, shape) = m.input(shaped, fallback: 224) { v, c in (v / 255 - mean[c]) / std[c] }
            guard let v = try m.run(input, shape, "image feature prints").first else { throw _vnError(.operationFailed, "the feature model gave no output") }
            return [VNFeaturePrintObservation(values: v)]
        }
        return [VNFeaturePrintObservation(values: _vnOwnFeaturePrint(shaped))]
    }
}

/// isim's own feature print: on a 16 x 16 grid, each cell's mean red, green, blue and edge strength, the vector
/// scaled to unit length (1,024 floats). Similar images are close; it knows nothing of what they show.
func _vnOwnFeaturePrint(_ img: _VNImage) -> [Float] {
    let N = 16
    var v = [Float](repeating: 0, count: N * N * 4)
    let g = _VNGray(img, maxSide: 128)
    img.bgra.withUnsafeBufferPointer { p in
        for cy in 0..<N { for cx in 0..<N {
            let x0 = cx * img.width / N, x1 = max(x0 + 1, (cx + 1) * img.width / N)
            let y0 = cy * img.height / N, y1 = max(y0 + 1, (cy + 1) * img.height / N)
            var r: Float = 0, gg: Float = 0, b: Float = 0
            for y in y0..<y1 { for x in x0..<x1 {
                let i = (y * img.width + x) * 4, a = 255 - Float(p[i + 3])
                r += Float(p[i + 2]) + a; gg += Float(p[i + 1]) + a; b += Float(p[i]) + a
            } }
            let n = Float((x1 - x0) * (y1 - y0)) * 255
            let k = (cy * N + cx) * 4
            v[k] = r / n; v[k + 1] = gg / n; v[k + 2] = b / n
            /* edges: mean gradient magnitude of the grey image in the cell */
            let gx0 = cx * g.width / N, gx1 = max(gx0 + 1, (cx + 1) * g.width / N), gy0 = cy * g.height / N, gy1 = max(gy0 + 1, (cy + 1) * g.height / N)
            var e: Float = 0, m = 0
            for y in gy0..<gy1 { for x in gx0..<gx1 where x + 1 < g.width && y + 1 < g.height {
                e += abs(g[x + 1, y] - g[x, y]) + abs(g[x, y + 1] - g[x, y]); m += 1
            } }
            v[k + 3] = m > 0 ? 4 * e / Float(m) : 0
        } }
    }
    let len = v.reduce(0) { $0 + $1 * $1 }.squareRoot()
    return len > 0 ? v.map { $0 / len } : v
}
