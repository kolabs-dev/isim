// isim Vision: the rest of the iOS 18 Swift API's requests (issue #852), generated from a table: value-type requests
// (and final classes for the stateful ones, which keep their VN request and so its state between frames) over the VN
// classes' engines (adapted, the same as theirs). Each runs synchronously on the caller's task; compute devices are kept
// per stage and not used (isim runs every request on the CPU). Also: the iOS 26 DetectLensSmudgeRequest (isim: a
// sharpness heuristic), StatefulRequest, TargetedRequest and TargetedImageRequestHandler (no targeted requests in
// Apple's SDK yet), CoreMLModelContainer.
import UIKit
import CoreImage
import CoreML

public struct CalculateImageAestheticsScoresRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = ImageAestheticsScoresObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var cropAndScaleAction: ImageCropAndScaleAction = .centerCrop
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .calculateImageAestheticsScoresRequest(revision) }
    public var description: String { "CalculateImageAestheticsScoresRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        /* isim: the cropping action is accepted; the score looks at the whole region */
        let r = VNCalculateImageAestheticsScoresRequest()
        guard let o = try _vn(r, regionOfInterest, handler).first as? VNImageAestheticsScoresObservation else { throw VisionError.internalError("no aesthetics score") }
        return ImageAestheticsScoresObservation(o, descriptor: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? ImageAestheticsScoresObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .calculateImageAestheticsScores(self, v)
    }
}

public struct ClassifyImageRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision2 }
    public typealias Result = [ClassificationObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var cropAndScaleAction: ImageCropAndScaleAction = .centerCrop
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision2 }
    /// the host classifier's labels (ISIM_CLASSIFY_LABELS; empty without one)
    public var supportedIdentifiers: [String] { (try? VNClassifyImageRequest().supportedIdentifiers()) ?? [] }
    public var descriptor: RequestDescriptor { .classifyImageRequest(revision) }
    public var description: String { "ClassifyImageRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        /* isim: the cropping action is accepted; the classifier scales the region to its input */
        let r = VNClassifyImageRequest()
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNClassificationObservation).map { ClassificationObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .classifyImage(self, value as? [ClassificationObservation] ?? [])
    }
}

public struct CoreMLRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [any VisionObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public let modelContainer: CoreMLModelContainer
    public var cropAndScaleAction: ImageCropAndScaleAction = .centerCrop
    var _devices = _VNDevices()
    public init(model: CoreMLModelContainer, _ revision: Revision? = nil) { modelContainer = model; self.revision = revision ?? .revision1 }
    /// the model's class labels, for classifiers (nil otherwise)
    public var supportedIdentifiers: [String]? { modelContainer.model.modelDescription.classLabels?.map { "\($0)" } }
    public static func == (a: CoreMLRequest, b: CoreMLRequest) -> Bool { a.revision == b.revision && a.modelContainer.model === b.modelContainer.model && a.regionOfInterest == b.regionOfInterest }
    public func hash(into h: inout Hasher) { h.combine(revision); h.combine(ObjectIdentifier(modelContainer.model)) }
    public var descriptor: RequestDescriptor { .coreMLRequest(revision) }
    public var description: String { "CoreMLRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNCoreMLRequest(model: try VNCoreMLModel(for: modelContainer.model)); r.imageCropAndScaleOption = VNCoreMLRequest.ImageCropAndScaleOption(rawValue: cropAndScaleAction._vn.rawValue) ?? .centerCrop
        return try _vn(r, regionOfInterest, handler).compactMap { o -> (any VisionObservation)? in
            if let c = o as? VNClassificationObservation { return ClassificationObservation(c, descriptor: descriptor) }
            if let f = o as? VNCoreMLFeatureValueObservation { return CoreMLFeatureValueObservation(f) }
            if let p = o as? VNPixelBufferObservation { return PixelBufferObservation(p, descriptor: descriptor) }
            return nil
        }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .coreML(self, value as? [any VisionObservation] ?? [])
    }
}

public struct DetectAnimalBodyPoseRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [AnimalBodyPoseObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    public var supportedJointNames: [AnimalBodyPoseObservation.JointName] { AnimalBodyPoseObservation.JointName.allCases }
    public var supportedJointsGroupNames: [AnimalBodyPoseObservation.JointsGroupName] { AnimalBodyPoseObservation.JointsGroupName.allCases }
    public var descriptor: RequestDescriptor { .detectAnimalBodyPoseRequest(revision) }
    public var description: String { "DetectAnimalBodyPoseRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        return try _vn(VNDetectAnimalBodyPoseRequest(), regionOfInterest, handler).compactMap { ($0 as? VNAnimalBodyPoseObservation).map { AnimalBodyPoseObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectAnimalBodyPose(self, value as? [AnimalBodyPoseObservation] ?? [])
    }
}

public struct DetectContoursRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = ContoursObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var contrastAdjustment: Float = 2
    public var contrastPivot: Float? = 0.5
    public var detectsDarkOnLight = true
    public var maximumImageDimension = 512
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .detectContoursRequest(revision) }
    public var description: String { "DetectContoursRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectContoursRequest()
        r.contrastAdjustment = contrastAdjustment; r.contrastPivot = contrastPivot.map { NSNumber(value: $0) }
        r.detectsDarkOnLight = detectsDarkOnLight; r.maximumImageDimension = maximumImageDimension
        guard let o = try _vn(r, regionOfInterest, handler).first as? VNContoursObservation else { throw VisionError.internalError("no contours observation") }
        return ContoursObservation(o, descriptor: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? ContoursObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .detectContours(self, v)
    }
}

public struct DetectDocumentSegmentationRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = DetectedDocumentObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .detectDocumentSegmentationRequest(revision) }
    public var description: String { "DetectDocumentSegmentationRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        return (try _vn(VNDetectDocumentSegmentationRequest(), regionOfInterest, handler).first as? VNRectangleObservation).map { DetectedDocumentObservation($0, descriptor: descriptor) } as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectDocumentSegmentation(self, value as? DetectedDocumentObservation? ?? nil)
    }
}

public struct DetectFaceCaptureQualityRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision3 }
    public typealias Result = [FaceObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision3]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var inputFaceObservations: [FaceObservation]?
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision3 }
    
    public var descriptor: RequestDescriptor { .detectFaceCaptureQualityRequest(revision) }
    public var description: String { "DetectFaceCaptureQualityRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectFaceCaptureQualityRequest(); r.inputFaceObservations = inputFaceObservations?.map(\._vn)
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNFaceObservation).map { FaceObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectFaceCaptureQuality(self, value as? [FaceObservation] ?? [])
    }
}

public struct DetectFaceLandmarksRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision3, revision4 }
    public typealias Result = [FaceObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision3, .revision4]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var inputFaceObservations: [FaceObservation]?
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision3 }
    
    public var descriptor: RequestDescriptor { .detectFaceLandmarksRequest(revision) }
    public var description: String { "DetectFaceLandmarksRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectFaceLandmarksRequest(); r.inputFaceObservations = inputFaceObservations?.map(\._vn)
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNFaceObservation).map { FaceObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectFaceLandmarks(self, value as? [FaceObservation] ?? [])
    }
}

public struct DetectHorizonRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = HorizonObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .detectHorizonRequest(revision) }
    public var description: String { "DetectHorizonRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        return (try _vn(VNDetectHorizonRequest(), regionOfInterest, handler).first as? VNHorizonObservation).map { HorizonObservation($0, descriptor: descriptor) } as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectHorizon(self, value as? HorizonObservation? ?? nil)
    }
}

public struct DetectHumanBodyPoseRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision2 }
    public typealias Result = [HumanBodyPoseObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2]
    public var regionOfInterest: NormalizedRect = .fullImage
    /// isim: accepted; no hands are found with the body
    public var detectsHands = false
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision2 }
    public var supportedJointNames: [HumanBodyPoseObservation.JointName] { HumanBodyPoseObservation.JointName.allCases }
    public var supportedJointsGroupNames: [HumanBodyPoseObservation.JointsGroupName] { HumanBodyPoseObservation.JointsGroupName.allCases }
    public var descriptor: RequestDescriptor { .detectHumanBodyPoseRequest(revision) }
    public var description: String { "DetectHumanBodyPoseRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        return try _vn(VNDetectHumanBodyPoseRequest(), regionOfInterest, handler).compactMap { ($0 as? VNHumanBodyPoseObservation).map { HumanBodyPoseObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectHumanBodyPose(self, value as? [HumanBodyPoseObservation] ?? [])
    }
}

public struct DetectHumanHandPoseRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [HumanHandPoseObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var maximumHandCount = 2
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    public var supportedJointNames: [HumanHandPoseObservation.JointName] { HumanHandPoseObservation.JointName.allCases }
    public var supportedJointsGroupNames: [HumanHandPoseObservation.JointsGroupName] { get throws { HumanHandPoseObservation.JointsGroupName.allCases } }
    public var descriptor: RequestDescriptor { .detectHumanHandPoseRequest(revision) }
    public var description: String { "DetectHumanHandPoseRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectHumanHandPoseRequest(); r.maximumHandCount = maximumHandCount
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNHumanHandPoseObservation).map { HumanHandPoseObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectHumanHandPose(self, value as? [HumanHandPoseObservation] ?? [])
    }
}

public struct DetectHumanRectanglesRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision2, revision3 }
    public typealias Result = [HumanObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2, .revision3]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var upperBodyOnly = true
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision2 }
    
    public var descriptor: RequestDescriptor { .detectHumanRectanglesRequest(revision) }
    public var description: String { "DetectHumanRectanglesRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectHumanRectanglesRequest(); r.upperBodyOnly = upperBodyOnly
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNHumanObservation).map { HumanObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectHumanRectangles(self, value as? [HumanObservation] ?? [])
    }
}

public struct DetectLensSmudgeRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = SmudgeObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var cropAndScaleAction: ImageCropAndScaleAction = .centerCrop
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .detectLensSmudgeRequest(revision) }
    public var description: String { "DetectLensSmudgeRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let img = try handler._image(regionOfInterest.cgRect)
        return SmudgeObservation(confidence: _vnSmudge(img), descriptor: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? SmudgeObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .detectLensSmudge(self, v)
    }
}

public struct DetectRectanglesRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [RectangleObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var minimumAspectRatio: Float = 0.5
    public var maximumAspectRatio: Float = 1
    public var quadratureToleranceDegrees: Float = 30
    public var minimumSize: Float = 0.2
    public var minimumConfidence: Float = 0
    public var maximumObservations = 1
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .detectRectanglesRequest(revision) }
    public var description: String { "DetectRectanglesRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectRectanglesRequest()
        r.minimumAspectRatio = minimumAspectRatio; r.maximumAspectRatio = maximumAspectRatio; r.quadratureTolerance = quadratureToleranceDegrees
        r.minimumSize = minimumSize; r.minimumConfidence = minimumConfidence; r.maximumObservations = maximumObservations
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNRectangleObservation).map { RectangleObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectRectangles(self, value as? [RectangleObservation] ?? [])
    }
}

public struct DetectTextRectanglesRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [TextObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var reportCharacterBoxes = false
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .detectTextRectanglesRequest(revision) }
    public var description: String { "DetectTextRectanglesRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNDetectTextRectanglesRequest(); r.reportCharacterBoxes = reportCharacterBoxes
        return try _vn(r, regionOfInterest, handler).compactMap { ($0 as? VNTextObservation).map { TextObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectTextRectangles(self, value as? [TextObservation] ?? [])
    }
}

public struct GenerateAttentionBasedSaliencyImageRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision2 }
    public typealias Result = SaliencyImageObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision2 }
    
    public var descriptor: RequestDescriptor { .generateAttentionBasedSaliencyImageRequest(revision) }
    public var description: String { "GenerateAttentionBasedSaliencyImageRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        guard let o = try _vn(VNGenerateAttentionBasedSaliencyImageRequest(), regionOfInterest, handler).first as? VNSaliencyImageObservation else { throw VisionError.internalError("no saliency map") }
        return SaliencyImageObservation(o, descriptor: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? SaliencyImageObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .generateAttentionBasedSaliencyImage(self, v)
    }
}

public struct GenerateObjectnessBasedSaliencyImageRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision2 }
    public typealias Result = SaliencyImageObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision2 }
    
    public var descriptor: RequestDescriptor { .generateObjectnessBasedSaliencyImageRequest(revision) }
    public var description: String { "GenerateObjectnessBasedSaliencyImageRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        guard let o = try _vn(VNGenerateObjectnessBasedSaliencyImageRequest(), regionOfInterest, handler).first as? VNSaliencyImageObservation else { throw VisionError.internalError("no saliency map") }
        return SaliencyImageObservation(o, descriptor: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? SaliencyImageObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .generateObjectnessBasedSaliencyImage(self, v)
    }
}

public struct GenerateForegroundInstanceMaskRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = InstanceMaskObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .generateForegroundInstanceMaskRequest(revision) }
    public var description: String { "GenerateForegroundInstanceMaskRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        return (try _vn(VNGenerateForegroundInstanceMaskRequest(), regionOfInterest, handler).first as? VNInstanceMaskObservation).map { InstanceMaskObservation($0, descriptor: descriptor) } as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .generateForegroundInstanceMask(self, value as? InstanceMaskObservation? ?? nil)
    }
}

public struct GeneratePersonInstanceMaskRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = InstanceMaskObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision1 }
    
    public var descriptor: RequestDescriptor { .generatePersonInstanceMaskRequest(revision) }
    public var description: String { "GeneratePersonInstanceMaskRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        return (try _vn(VNGeneratePersonInstanceMaskRequest(), regionOfInterest, handler).first as? VNInstanceMaskObservation).map { InstanceMaskObservation($0, descriptor: descriptor) } as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .generatePersonInstanceMask(self, value as? InstanceMaskObservation? ?? nil)
    }
}

public struct GenerateImageFeaturePrintRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision2 }
    public typealias Result = FeaturePrintObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var cropAndScaleAction: ImageCropAndScaleAction = .scaleToFill
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision2 }
    
    public var descriptor: RequestDescriptor { .generateImageFeaturePrintRequest(revision) }
    public var description: String { "GenerateImageFeaturePrintRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        let r = VNGenerateImageFeaturePrintRequest(); r.imageCropAndScaleOption = cropAndScaleAction._vn
        guard let o = try _vn(r, regionOfInterest, handler).first as? VNFeaturePrintObservation else { throw VisionError.internalError("no feature print") }
        return FeaturePrintObservation(o, descriptor: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? FeaturePrintObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .generateImageFeaturePrint(self, v)
    }
}

public struct RecognizeAnimalsRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices {
    public enum Revision: Hashable, Sendable, Comparable { case revision2, revision3 }
    public typealias Result = [RecognizedObjectObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2, .revision3]
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    public init(_ revision: Revision? = nil) { self.revision = revision ?? .revision2 }
    public enum Animal: String, Hashable, Sendable, CaseIterable { case cat = "Cat", dog = "Dog" }
    public enum Identifier: String, Hashable, Sendable, CaseIterable { case cat = "Cat", dog = "Dog", catHead = "CatHead", dogHead = "DogHead" }
    public var supportedAnimals: [Animal] { Animal.allCases }
    /// isim recognizes whole animals only (no heads)
    public var supportedIdentifiers: [Identifier] { [.cat, .dog] }
    public var descriptor: RequestDescriptor { .recognizeAnimalsRequest(revision) }
    public var description: String { "RecognizeAnimalsRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        return try _vn(VNRecognizeAnimalsRequest(), regionOfInterest, handler).compactMap { ($0 as? VNRecognizedObjectObservation).map { RecognizedObjectObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .recognizeAnimals(self, value as? [RecognizedObjectObservation] ?? [])
    }
}

public final class DetectHumanBodyPose3DRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [HumanBodyPose3DObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNDetectHumanBodyPose3DRequest
    let _lock = NSLock()
    public init(_ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        self.revision = revision ?? .revision1; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNDetectHumanBodyPose3DRequest(frameAnalysisSpacing: frameAnalysisSpacing ?? .zero, completionHandler: nil)
    }
    public var supportedJointNames: [HumanBodyPose3DObservation.JointName] { HumanBodyPose3DObservation.JointName.allCases }
    public var supportedJointsGroupNames: [HumanBodyPose3DObservation.JointsGroupName] { HumanBodyPose3DObservation.JointsGroupName.allCases }
    public var minimumLatencyFrameCount: Int { _r.minimumLatencyFrameCount }
    public var descriptor: RequestDescriptor { .detectHumanBodyPose3DRequest(revision) }
    public var description: String { "DetectHumanBodyPose3DRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        return try _vn(_r, regionOfInterest, handler).compactMap { ($0 as? VNHumanBodyPose3DObservation).map { HumanBodyPose3DObservation($0, descriptor: descriptor) } }
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectHumanBodyPose3D(self, value as? [HumanBodyPose3DObservation] ?? [])
    }
}

public final class DetectTrajectoriesRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = [TrajectoryObservation]
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    public let trajectoryLength: Int
    public var objectMinimumNormalizedRadius: Float = 0
    public var objectMaximumNormalizedRadius: Float = 1
    /// the frame time the results are for
    public var targetFrameTime: CMTime = .zero
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNDetectTrajectoriesRequest
    let _lock = NSLock()
    public init(trajectoryLength: Int, _ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        self.trajectoryLength = trajectoryLength
        self.revision = revision ?? .revision1; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNDetectTrajectoriesRequest(frameAnalysisSpacing: frameAnalysisSpacing ?? .zero, trajectoryLength: trajectoryLength)
    }
    
    public var minimumLatencyFrameCount: Int { _r.minimumLatencyFrameCount }
    public var descriptor: RequestDescriptor { .detectTrajectoriesRequest(revision) }
    public var description: String { "DetectTrajectoriesRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        _r.objectMinimumNormalizedRadius = objectMinimumNormalizedRadius; _r.objectMaximumNormalizedRadius = objectMaximumNormalizedRadius
        let out = try _vn(_r, regionOfInterest, handler).compactMap { ($0 as? VNTrajectoryObservation).map { TrajectoryObservation($0, descriptor: descriptor) } }
        targetFrameTime = _r.targetFrameTime
        return out
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .detectTrajectories(self, value as? [TrajectoryObservation] ?? [])
    }
}

public final class GeneratePersonSegmentationRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = PixelBufferObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    public enum QualityLevel: Hashable, Sendable { case accurate, balanced, fast }
    public var qualityLevel: QualityLevel = .accurate
    public var outputPixelFormatType: OSType = kCVPixelFormatType_OneComponent8
    public var supportedOutputPixelFormats: [OSType] { [kCVPixelFormatType_OneComponent8, kCVPixelFormatType_OneComponent16Half, kCVPixelFormatType_OneComponent32Float] }
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNGeneratePersonSegmentationRequest
    let _lock = NSLock()
    public init(_ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        self.revision = revision ?? .revision1; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNGeneratePersonSegmentationRequest()
    }
    
    public var minimumLatencyFrameCount: Int { 1 }
    public var descriptor: RequestDescriptor { .generatePersonSegmentationRequest(revision) }
    public var description: String { "GeneratePersonSegmentationRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        switch qualityLevel { case .accurate: _r.qualityLevel = .accurate; case .balanced: _r.qualityLevel = .balanced; case .fast: _r.qualityLevel = .fast }
        _r.outputPixelFormat = outputPixelFormatType
        guard let o = try _vn(_r, regionOfInterest, handler).first as? VNPixelBufferObservation else { throw VisionError.internalError("no mask") }
        return PixelBufferObservation(o, descriptor: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? PixelBufferObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .generatePersonSegmentation(self, v)
    }
}

public final class TrackObjectRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision2 }
    public typealias Result = DetectedObjectObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision2]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    public let inputObservation: any BoundingBoxProviding & VisionObservation
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNTrackObjectRequest
    let _lock = NSLock()
    public init(detectedObject: any BoundingBoxProviding & VisionObservation, _ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        inputObservation = detectedObject
        self.revision = revision ?? .revision2; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNTrackObjectRequest(detectedObjectObservation: _vnObject(detectedObject))
    }
    
    public var minimumLatencyFrameCount: Int { 1 }
    public var descriptor: RequestDescriptor { .trackObjectRequest(revision) }
    public var description: String { "TrackObjectRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        return (try _vn(_r, regionOfInterest, handler).first as? VNDetectedObjectObservation).map { DetectedObjectObservation($0, descriptor: descriptor) } as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .trackObject(self, value as? DetectedObjectObservation? ?? nil)
    }
}

public final class TrackRectangleRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = RectangleObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    public enum TrackingLevel: Hashable, Sendable { case accurate, fast }
    public let inputObservation: any QuadrilateralProviding & VisionObservation
    public var trackingLevel: TrackingLevel = .accurate
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNTrackRectangleRequest
    let _lock = NSLock()
    public init(detectedRectangle: any QuadrilateralProviding & VisionObservation, _ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        inputObservation = detectedRectangle
        self.revision = revision ?? .revision1; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNTrackRectangleRequest(rectangleObservation: _vnQuad(detectedRectangle), completionHandler: nil)
    }
    
    public var minimumLatencyFrameCount: Int { 1 }
    public var descriptor: RequestDescriptor { .trackRectangleRequest(revision) }
    public var description: String { "TrackRectangleRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        _r.trackingLevel = trackingLevel == .fast ? .fast : .accurate
        return (try _vn(_r, regionOfInterest, handler).first as? VNRectangleObservation).map { RectangleObservation($0, descriptor: descriptor) } as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .trackRectangle(self, value as? RectangleObservation? ?? nil)
    }
}

public final class TrackOpticalFlowRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = OpticalFlowObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    public enum ComputationAccuracy: Hashable, Sendable { case low, medium, high, veryHigh }
    public var computationAccuracy: ComputationAccuracy = .medium
    public var outputPixelFormatType: OSType = kCVPixelFormatType_TwoComponent32Float
    public var supportedOutputPixelFormatTypes: [OSType] { [kCVPixelFormatType_TwoComponent32Float, kCVPixelFormatType_TwoComponent16Half] }
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNTrackOpticalFlowRequest
    let _lock = NSLock()
    public init(_ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        self.revision = revision ?? .revision1; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNTrackOpticalFlowRequest(frameAnalysisSpacing: frameAnalysisSpacing ?? .zero, completionHandler: nil)
    }
    
    public var minimumLatencyFrameCount: Int { _r.minimumLatencyFrameCount }
    public var descriptor: RequestDescriptor { .trackOpticalFlowRequest(revision) }
    public var description: String { "TrackOpticalFlowRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        switch computationAccuracy { case .low: _r.computationAccuracy = .low; case .medium: _r.computationAccuracy = .medium; case .high: _r.computationAccuracy = .high; case .veryHigh: _r.computationAccuracy = .veryHigh }
        _r.outputPixelFormat = outputPixelFormatType
        return (try _vn(_r, regionOfInterest, handler).first as? VNPixelBufferObservation).flatMap { OpticalFlowObservation($0, descriptor: descriptor) } as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .trackOpticalFlow(self, value as? OpticalFlowObservation? ?? nil)
    }
}

public final class TrackTranslationalImageRegistrationRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = ImageTranslationAlignmentObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNTrackTranslationalImageRegistrationRequest
    let _lock = NSLock()
    public init(_ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        self.revision = revision ?? .revision1; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNTrackTranslationalImageRegistrationRequest(frameAnalysisSpacing: frameAnalysisSpacing ?? .zero, completionHandler: nil)
    }
    
    public var minimumLatencyFrameCount: Int { _r.minimumLatencyFrameCount }
    public var descriptor: RequestDescriptor { .trackTranslationalImageRegistrationRequest(revision) }
    public var description: String { "TrackTranslationalImageRegistrationRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        /* the first frame has nothing to align with: the identity */
        return (try _vn(_r, regionOfInterest, handler).first as? VNImageTranslationAlignmentObservation).map { ImageTranslationAlignmentObservation($0, descriptor: descriptor) }
            ?? ImageTranslationAlignmentObservation(identity: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? ImageTranslationAlignmentObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .trackTranslationalImageRegistration(self, v)
    }
}

public final class TrackHomographicImageRegistrationRequest: StatefulRequest, ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public typealias Result = ImageHomographicAlignmentObservation
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public let frameAnalysisSpacing: CMTime
    public var regionOfInterest: NormalizedRect = .fullImage
    
    var _devices = _VNDevices()
    /// the VN request, which keeps the previous frames
    let _r: VNTrackHomographicImageRegistrationRequest
    let _lock = NSLock()
    public init(_ revision: Revision? = nil, frameAnalysisSpacing: CMTime? = nil) {
        self.revision = revision ?? .revision1; self.frameAnalysisSpacing = frameAnalysisSpacing ?? .zero
        _r = VNTrackHomographicImageRegistrationRequest(frameAnalysisSpacing: frameAnalysisSpacing ?? .zero, completionHandler: nil)
    }
    
    public var minimumLatencyFrameCount: Int { _r.minimumLatencyFrameCount }
    public var descriptor: RequestDescriptor { .trackHomographicImageRegistrationRequest(revision) }
    public var description: String { "TrackHomographicImageRegistrationRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); defer { _lock.unlock() }
        return (try _vn(_r, regionOfInterest, handler).first as? VNImageHomographicAlignmentObservation).map { ImageHomographicAlignmentObservation($0, descriptor: descriptor) }
            ?? ImageHomographicAlignmentObservation(identity: descriptor)
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        guard let v = value as? ImageHomographicAlignmentObservation else { return .error(self, VisionError.internalError("\(self): no result")) }
        return .trackHomographicImageRegistration(self, v)
    }
}
