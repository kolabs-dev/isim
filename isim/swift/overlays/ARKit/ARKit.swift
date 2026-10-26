// isim ARKit: Apple's ARKit API, answering like Apple's Simulator, which has no camera tracking either: every
// configuration's isSupported is false, a session that runs one fails with ARError.unsupportedConfiguration (its
// delegate's and its views' session(_:didFailWithError:)), and no frames arrive. Self-authored, iOS API names. Stub
// for tracking; the value types (anchors, cameras, raycast queries, reference images, world maps) hold their data.
// ARSCNView is SceneKit's SCNView (its scene drawn over black: there is no camera feed); ARSKView is SpriteKit's SKView.
import UIKit
import SpriteKit
import SceneKit
import CoreVideo
import CoreMedia
import CoreImage
import simd

// MARK: - errors

public let ARErrorDomain = "com.apple.arkit.error"

public struct ARError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case unsupportedConfiguration = 100, sensorUnavailable = 101, sensorFailed = 102, cameraUnauthorized = 103
        case microphoneUnauthorized = 104, locationUnauthorized = 105
        case highResolutionFrameCaptureInProgress = 106, highResolutionFrameCaptureFailed = 107
        case worldTrackingFailed = 200, geoTrackingNotAvailableAtLocation = 201, geoTrackingFailed = 202
        case invalidReferenceImage = 300, invalidReferenceObject = 301, invalidWorldMap = 302, invalidConfiguration = 303
        case invalidCollaborationData = 304, insufficientFeatures = 400, objectMergeFailed = 401, fileIOFailed = 500, requestFailed = 501
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { ARErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] {
        switch code {
        case .unsupportedConfiguration:
            return [NSLocalizedDescriptionKey: "Unsupported configuration.",
                    NSLocalizedFailureReasonErrorKey: "The provided configuration is not supported on this device."]
        case .sensorUnavailable:
            return [NSLocalizedDescriptionKey: "Required sensor unavailable.", NSLocalizedFailureReasonErrorKey: "A required sensor is not available on this device."]
        default:
            return [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (\(ARErrorDomain) error \(code.rawValue).)"]
        }
    }
    public static var unsupportedConfiguration: Code { .unsupportedConfiguration }
    public static var sensorUnavailable: Code { .sensorUnavailable }
    public static var sensorFailed: Code { .sensorFailed }
    public static var cameraUnauthorized: Code { .cameraUnauthorized }
    public static var worldTrackingFailed: Code { .worldTrackingFailed }
    public static var invalidReferenceImage: Code { .invalidReferenceImage }
    public static var invalidWorldMap: Code { .invalidWorldMap }
    public static var invalidConfiguration: Code { .invalidConfiguration }
    public static var insufficientFeatures: Code { .insufficientFeatures }
    public static var highResolutionFrameCaptureFailed: Code { .highResolutionFrameCaptureFailed }
}

// MARK: - configurations

/// What a session tracks. isim, like Apple's Simulator, supports none: `isSupported` is false for every kind.
@objc(ARConfiguration) open class ARConfiguration: NSObject, NSCopying, @unchecked Sendable {
    public enum WorldAlignment: Int, Sendable { case gravity = 0, gravityAndHeading = 1, camera = 2 }
    public struct FrameSemantics: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let personSegmentation = FrameSemantics(rawValue: 1 << 0)
        public static let personSegmentationWithDepth = FrameSemantics(rawValue: (1 << 0) | (1 << 1))
        public static let bodyDetection = FrameSemantics(rawValue: 1 << 2)
        public static let sceneDepth = FrameSemantics(rawValue: 1 << 3)
        public static let smoothedSceneDepth = FrameSemantics(rawValue: 1 << 4)
    }
    public struct SceneReconstruction: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mesh = SceneReconstruction(rawValue: 1 << 0)
        public static let meshWithClassification = SceneReconstruction(rawValue: (1 << 0) | (1 << 1))
    }
    /// A camera mode a configuration can capture in.
    @objc(ARVideoFormat) open class VideoFormat: NSObject, NSCopying, @unchecked Sendable {
        @objc public let imageResolution: CGSize
        @objc public let framesPerSecond: Int
        @objc init(resolution: CGSize, fps: Int) { imageResolution = resolution; framesPerSecond = fps }
        @objc open var isVideoHDRSupported: Bool { false }
        @objc open var isRecommendedForHighResolutionFrameCapturing: Bool { false }
        @objc open func copy(with zone: NSZone? = nil) -> Any { self }
    }
    @objc public override init() { super.init() }
    /// false: no camera tracking on isim (as in Apple's Simulator)
    @objc open class var isSupported: Bool { false }
    @objc open class var supportedVideoFormats: [VideoFormat] { [] }
    open class func supportsFrameSemantics(_ frameSemantics: FrameSemantics) -> Bool { false }
    @objc open class var recommendedVideoFormatFor4KResolution: VideoFormat? { nil }
    @objc open class var recommendedVideoFormatForHighResolutionFrameCapturing: VideoFormat? { nil }
    @objc open class var configurableCaptureDeviceForPrimaryCamera: AnyObject? { nil }
    @objc open var videoFormat = VideoFormat(resolution: CGSize(width: 1920, height: 1440), fps: 60)
    open var worldAlignment: WorldAlignment = .gravity
    @objc open var isLightEstimationEnabled = true
    @objc open var providesAudioData = false
    open var frameSemantics: FrameSemantics = []
    @objc open var videoHDRAllowed = false
    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let c = (Swift.type(of: self) as NSObject.Type).init() as! ARConfiguration
        c.videoFormat = videoFormat; c.worldAlignment = worldAlignment; c.isLightEstimationEnabled = isLightEstimationEnabled
        c.providesAudioData = providesAudioData; c.frameSemantics = frameSemantics; c.videoHDRAllowed = videoHDRAllowed
        return c
    }
    @objc var _kind: String { "\(Swift.type(of: self))" }
}

@objc(ARWorldTrackingConfiguration) open class ARWorldTrackingConfiguration: ARConfiguration, @unchecked Sendable {
    public struct PlaneDetection: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let horizontal = PlaneDetection(rawValue: 1 << 0)
        public static let vertical = PlaneDetection(rawValue: 1 << 1)
    }
    public enum EnvironmentTexturing: Int, Sendable { case none = 0, manual = 1, automatic = 2 }
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    open class func supportsSceneReconstruction(_ sceneReconstruction: ARConfiguration.SceneReconstruction) -> Bool { false }
    @objc open class var supportsUserFaceTracking: Bool { false }
    @objc open class var supportsAppClipCodeTracking: Bool { false }
    open var planeDetection: PlaneDetection = []
    @objc open var detectionImages: Set<ARReferenceImage>! = []
    @objc open var detectionObjects: Set<ARReferenceObject> = []
    @objc open var maximumNumberOfTrackedImages = 0
    @objc open var automaticImageScaleEstimationEnabled = false
    open var environmentTexturing: EnvironmentTexturing = .none
    @objc open var wantsHDREnvironmentTextures = true
    open var sceneReconstruction: ARConfiguration.SceneReconstruction = []
    @objc open var isAutoFocusEnabled = true
    @objc open var isCollaborationEnabled = false
    @objc open var userFaceTrackingEnabled = false
    @objc open var appClipCodeTrackingEnabled = false
    @objc open var initialWorldMap: ARWorldMap?
}

@objc(AROrientationTrackingConfiguration) open class AROrientationTrackingConfiguration: ARConfiguration, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    @objc open var isAutoFocusEnabled = true
}

@objc(ARFaceTrackingConfiguration) open class ARFaceTrackingConfiguration: ARConfiguration, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    @objc open class var supportedNumberOfTrackedFaces: Int { 0 }
    @objc open class var supportsWorldTracking: Bool { false }
    @objc open var maximumNumberOfTrackedFaces = 1
    @objc open var isWorldTrackingEnabled = false
}

@objc(ARImageTrackingConfiguration) open class ARImageTrackingConfiguration: ARConfiguration, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    @objc open var trackingImages: Set<ARReferenceImage> = []
    @objc open var maximumNumberOfTrackedImages = 1
    @objc open var isAutoFocusEnabled = true
}

@objc(ARObjectScanningConfiguration) open class ARObjectScanningConfiguration: ARConfiguration, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    open var planeDetection: ARWorldTrackingConfiguration.PlaneDetection = []
    @objc open var isAutoFocusEnabled = true
}

@objc(ARBodyTrackingConfiguration) open class ARBodyTrackingConfiguration: ARConfiguration, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    open var planeDetection: ARWorldTrackingConfiguration.PlaneDetection = []
    @objc open var detectionImages: Set<ARReferenceImage>! = []
    @objc open var maximumNumberOfTrackedImages = 0
    @objc open var automaticSkeletonScaleEstimationEnabled = false
    @objc open var isAutoFocusEnabled = true
    @objc open var initialWorldMap: ARWorldMap?
}

@objc(ARPositionalTrackingConfiguration) open class ARPositionalTrackingConfiguration: ARConfiguration, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    open var planeDetection: ARWorldTrackingConfiguration.PlaneDetection = []
    @objc open var initialWorldMap: ARWorldMap?
}

@objc(ARGeoTrackingConfiguration) open class ARGeoTrackingConfiguration: ARConfiguration, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open override class var isSupported: Bool { false }
    /// never available on isim
    @objc open class func checkAvailability(completionHandler: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(false, ARError(.unsupportedConfiguration)) }
    }
    open var planeDetection: ARWorldTrackingConfiguration.PlaneDetection = []
    @objc open var maximumNumberOfTrackedImages = 0
}

// MARK: - the session

public protocol ARSessionObserver: AnyObject {
    func session(_ session: ARSession, didFailWithError error: Error)
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera)
    func sessionWasInterrupted(_ session: ARSession)
    func sessionInterruptionEnded(_ session: ARSession)
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool
    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer)
}
extension ARSessionObserver {
    public func session(_ session: ARSession, didFailWithError error: Error) {}
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {}
    public func sessionWasInterrupted(_ session: ARSession) {}
    public func sessionInterruptionEnded(_ session: ARSession) {}
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool { false }
    public func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {}
}

public protocol ARSessionDelegate: ARSessionObserver {
    func session(_ session: ARSession, didUpdate frame: ARFrame)
    func session(_ session: ARSession, didAdd anchors: [ARAnchor])
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor])
    func session(_ session: ARSession, didRemove anchors: [ARAnchor])
}
extension ARSessionDelegate {
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {}
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {}
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {}
    public func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {}
}

/// Runs a configuration. On isim (as in Apple's Simulator) no configuration is supported, so running one fails:
/// the delegate and the session's views get `session(_:didFailWithError:)` with `ARError.unsupportedConfiguration`.
@objc(ARSession) open class ARSession: NSObject, @unchecked Sendable {
    public struct RunOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let resetTracking = RunOptions(rawValue: 1 << 0)
        public static let removeExistingAnchors = RunOptions(rawValue: 1 << 1)
        public static let stopTrackedRaycasts = RunOptions(rawValue: 1 << 2)
        public static let resetSceneReconstruction = RunOptions(rawValue: 1 << 3)
    }
    @objc public override init() { super.init() }
    @objc public let identifier = UUID()
    open weak var delegate: (any ARSessionDelegate)?
    open var delegateQueue: DispatchQueue?
    @objc open private(set) var configuration: ARConfiguration?
    /// always nil: no frames without camera tracking
    @objc open var currentFrame: ARFrame? { nil }
    @objc var _anchors: [ARAnchor] = []
    /// ARSCNView / ARSKView / ARCoachingOverlayView observing this session
    @objc var _views = NSHashTable<AnyObject>.weakObjects()

    open func run(_ configuration: ARConfiguration, options: RunOptions = []) {
        self.configuration = configuration.copy() as? ARConfiguration
        if options.contains(.removeExistingAnchors) { _anchors = [] }
        NSLog("isim ARKit: %@ is not supported on this device (no camera tracking, as in the Simulator)", configuration._kind)
        _tell { $0.session(self, didFailWithError: ARError(.unsupportedConfiguration)) }
    }
    @objc open func pause() {}
    @objc open func add(anchor: ARAnchor) { _anchors.append(anchor) }
    @objc open func remove(anchor: ARAnchor) { _anchors.removeAll { $0.identifier == anchor.identifier } }
    open func setWorldOrigin(relativeTransform: simd_float4x4) {}
    @objc open func getCurrentWorldMap(completionHandler: @escaping (ARWorldMap?, Error?) -> Void) {
        _on { completionHandler(nil, ARError(.invalidWorldMap)) }
    }
    open func createReferenceObject(transform: simd_float4x4, center: simd_float3, extent: simd_float3,
                                    completionHandler: @escaping (ARReferenceObject?, Error?) -> Void) {
        _on { completionHandler(nil, ARError(.insufficientFeatures)) }
    }
    @objc open func captureHighResolutionFrame(completion: @escaping (ARFrame?, Error?) -> Void) {
        _on { completion(nil, ARError(.highResolutionFrameCaptureFailed)) }
    }
    /// no tracked world: nothing to hit
    @objc open func raycast(_ query: ARRaycastQuery) -> [ARRaycastResult] { [] }
    @objc open func trackedRaycast(_ query: ARRaycastQuery, updateHandler: @escaping ([ARRaycastResult]) -> Void) -> ARTrackedRaycast? { nil }

    @objc func _on(_ f: @escaping () -> Void) { (delegateQueue ?? .main).async(execute: f) }
    /// the delegate (on its queue), then the views' delegates on the main queue (ARSCNView and ARSKView forward
    /// session events to theirs)
    func _tell(_ f: @escaping (any ARSessionObserver) -> Void) {
        _on { [weak self] in
            guard let self else { return }
            if let d = self.delegate { f(d) }
            DispatchQueue.main.async { [weak self] in
                for v in self?._views.allObjects ?? [] { (v as? _ARSessionViewing)?._sessionObserver.map(f) }
            }
        }
    }
}

protocol _ARSessionViewing: AnyObject { var _sessionObserver: (any ARSessionObserver)? { get } }

// MARK: - frames and cameras

/// A captured video frame with its tracking state. isim's sessions produce none (no camera tracking).
@objc(ARFrame) open class ARFrame: NSObject, NSCopying, @unchecked Sendable {
    public enum WorldMappingStatus: Int, Sendable { case notAvailable = 0, limited = 1, extending = 2, mapped = 3 }
    public enum SegmentationClass: UInt8, Sendable { case none = 0, person = 255 }
    @objc public let timestamp: TimeInterval
    public let capturedImage: CVPixelBuffer
    @objc public let camera: ARCamera
    @objc public let anchors: [ARAnchor]
    init(timestamp: TimeInterval, image: CVPixelBuffer, camera: ARCamera, anchors: [ARAnchor]) {
        self.timestamp = timestamp; capturedImage = image; self.camera = camera; self.anchors = anchors
    }
    @objc open var lightEstimate: ARLightEstimate? { nil }
    @objc open var rawFeaturePoints: ARPointCloud? { nil }
    open var worldMappingStatus: WorldMappingStatus { .notAvailable }
    @objc open var capturedDepthData: AnyObject? { nil }
    @objc open var capturedDepthDataTimestamp: TimeInterval { 0 }
    open var segmentationBuffer: CVPixelBuffer? { nil }
    open var estimatedDepthData: CVPixelBuffer? { nil }
    @objc open var cameraGrainIntensity: Float { 0 }
    @objc open var exifData: [String: Any] { [:] }
    /// maps normalized image coordinates to the viewport (the image is landscape-right, as the camera captures it)
    @objc open func displayTransform(for orientation: UIInterfaceOrientation, viewportSize: CGSize) -> CGAffineTransform {
        let img = camera.imageResolution
        let portrait = orientation == .portrait || orientation == .portraitUpsideDown
        let w = portrait ? img.height : img.width, h = portrait ? img.width : img.height
        let s = max(viewportSize.width / max(w, 1), viewportSize.height / max(h, 1))
        let sx = viewportSize.width / (w * s), sy = viewportSize.height / (h * s)
        var t = CGAffineTransform.identity
        if portrait { t = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 1) }
        return t.concatenating(CGAffineTransform(a: 1 / sx, b: 0, c: 0, d: 1 / sy, tx: (1 - 1 / sx) / 2, ty: (1 - 1 / sy) / 2))
    }
    open func raycastQuery(from point: CGPoint, allowing target: ARRaycastQuery.Target, alignment: ARRaycastQuery.TargetAlignment) -> ARRaycastQuery {
        let d = camera._ray(point)
        return ARRaycastQuery(origin: d.0, direction: d.1, allowing: target, alignment: alignment)
    }
    @objc open func copy(with zone: NSZone? = nil) -> Any { self }
}

/// The camera's pose and optics for a frame.
@objc(ARCamera) open class ARCamera: NSObject, NSCopying, @unchecked Sendable {
    public enum TrackingState: Equatable, Sendable {
        public enum Reason: Equatable, Sendable { case initializing, excessiveMotion, insufficientFeatures, relocalizing }
        case notAvailable
        case limited(Reason)
        case normal
    }
    public let transform: simd_float4x4
    public let intrinsics: simd_float3x3
    @objc public let imageResolution: CGSize
    public let trackingState: TrackingState
    init(transform: simd_float4x4 = matrix_identity_float4x4, imageResolution: CGSize = CGSize(width: 1920, height: 1440),
         focalLength: Float = 1500, trackingState: TrackingState = .notAvailable) {
        self.transform = transform; self.imageResolution = imageResolution; self.trackingState = trackingState
        intrinsics = simd_float3x3(columns: (SIMD3(focalLength, 0, 0), SIMD3(0, focalLength, 0),
                                             SIMD3(Float(imageResolution.width) / 2, Float(imageResolution.height) / 2, 1)))
    }
    /// pitch, yaw, roll of the camera
    open var eulerAngles: simd_float3 {
        let m = transform
        return simd_float3(asinf(-m[2, 1]), atan2f(m[2, 0], m[2, 2]), atan2f(m[0, 1], m[1, 1]))
    }
    @objc open var exposureDuration: TimeInterval { 1.0 / 60 }
    @objc open var exposureOffset: Float { 0 }
    open var projectionMatrix: simd_float4x4 {
        projectionMatrix(for: .landscapeRight, viewportSize: imageResolution, zNear: 0.001, zFar: 1000)
    }
    open func projectionMatrix(for orientation: UIInterfaceOrientation, viewportSize: CGSize, zNear: CGFloat, zFar: CGFloat) -> simd_float4x4 {
        let fx = intrinsics[0, 0], fy = intrinsics[1, 1]
        let w = Float(imageResolution.width), h = Float(imageResolution.height)
        let n = Float(zNear), f = Float(zFar)
        var p = simd_float4x4()
        p[0, 0] = 2 * fx / w; p[1, 1] = 2 * fy / h
        p[2, 2] = f / (n - f); p[2, 3] = -1; p[3, 2] = f * n / (n - f)
        return p
    }
    open func viewMatrix(for orientation: UIInterfaceOrientation) -> simd_float4x4 { _ARMath.inverse(transform) }
    /// a world point on the viewport (nil-free: points behind the camera land off screen)
    open func projectPoint(_ point: simd_float3, orientation: UIInterfaceOrientation, viewportSize: CGSize) -> CGPoint {
        let c = viewMatrix(for: orientation) * SIMD4(point, 1)
        guard c.z < 0 else { return CGPoint(x: -1, y: -1) }
        let fx = intrinsics[0, 0], cx = intrinsics[2, 0], cy = intrinsics[2, 1]
        let u = cx + fx * (c.x / -c.z), v = cy - fx * (c.y / -c.z)
        let sx = viewportSize.width / imageResolution.width, sy = viewportSize.height / imageResolution.height
        return CGPoint(x: CGFloat(u) * sx, y: CGFloat(v) * sy)
    }
    open func unprojectPoint(_ point: CGPoint, ontoPlane planeTransform: simd_float4x4, orientation: UIInterfaceOrientation, viewportSize: CGSize) -> simd_float3? {
        let (o, d) = _ray(CGPoint(x: point.x / viewportSize.width * imageResolution.width, y: point.y / viewportSize.height * imageResolution.height))
        let n = SIMD3(planeTransform.columns.1.x, planeTransform.columns.1.y, planeTransform.columns.1.z)
        let p0 = SIMD3(planeTransform.columns.3.x, planeTransform.columns.3.y, planeTransform.columns.3.z)
        let den = simd_dot(n, d)
        guard abs(den) > 1e-6 else { return nil }
        let t = simd_dot(p0 - o, n) / den
        return t >= 0 ? o + d * t : nil
    }
    /// the world ray through an image point
    func _ray(_ p: CGPoint) -> (simd_float3, simd_float3) {
        let fx = intrinsics[0, 0], cx = intrinsics[2, 0], cy = intrinsics[2, 1]
        let local = simd_normalize(SIMD3((Float(p.x) - cx) / fx, -(Float(p.y) - cy) / fx, -1))
        let w = transform * SIMD4(local, 0)
        return (SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z), simd_normalize(SIMD3(w.x, w.y, w.z)))
    }
    @objc open func copy(with zone: NSZone? = nil) -> Any { self }
}

enum _ARMath {
    static func inverse(_ m: simd_float4x4) -> simd_float4x4 { SCNMatrix4ToMat4(SCNMatrix4Invert(SCNMatrix4FromMat4(m))) }
}

@objc(ARLightEstimate) open class ARLightEstimate: NSObject, @unchecked Sendable {
    /// lumens; 1000 is neutral
    @objc open internal(set) var ambientIntensity: CGFloat = 1000
    /// kelvin; 6500 is pure white
    @objc open internal(set) var ambientColorTemperature: CGFloat = 6500
}

/// Feature points the session found (isim's sessions find none).
@objc(ARPointCloud) open class ARPointCloud: NSObject, NSSecureCoding, @unchecked Sendable {
    public let points: [simd_float3]
    @objc public let identifiers: [UInt64]
    init(points: [simd_float3], identifiers: [UInt64]) { self.points = points; self.identifiers = identifiers }
    @objc open var count: Int { points.count }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(points.flatMap { [$0.x, $0.y, $0.z] }.map(NSNumber.init(value:)), forKey: "points")
        coder.encode(identifiers.map(NSNumber.init(value:)), forKey: "ids")
    }
    @objc public required init?(coder: NSCoder) {
        let p = (coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "points") as? [NSNumber] ?? []).map { $0.floatValue }
        points = stride(from: 0, to: p.count - 2, by: 3).map { simd_float3(p[$0], p[$0 + 1], p[$0 + 2]) }
        identifiers = (coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "ids") as? [NSNumber] ?? []).map { $0.uint64Value }
    }
}

// MARK: - anchors

/// A position and orientation in the world, added by the app or found by the session.
@objc(ARAnchor) open class ARAnchor: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let identifier: UUID
    @objc public let name: String?
    public let transform: simd_float4x4
    @objc open internal(set) var sessionIdentifier: UUID?
    public init(transform: simd_float4x4) { identifier = UUID(); name = nil; self.transform = transform; super.init() }
    public init(name: String, transform: simd_float4x4) { identifier = UUID(); self.name = name; self.transform = transform; super.init() }
    /// a copy for an updated frame (subclasses call it from their copies)
    @objc public required init(anchor: ARAnchor) {
        identifier = anchor.identifier; name = anchor.name; transform = anchor.transform; sessionIdentifier = anchor.sessionIdentifier
        super.init()
    }
    @objc open func copy(with zone: NSZone? = nil) -> Any { Swift.type(of: self).init(anchor: self) }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(identifier.uuidString, forKey: "id")
        coder.encode(name, forKey: "name")
        let c = transform.columns
        coder.encode([c.0, c.1, c.2, c.3].flatMap { [$0.x, $0.y, $0.z, $0.w] }.map(NSNumber.init(value:)), forKey: "transform")
    }
    @objc public required init?(coder: NSCoder) {
        identifier = (coder.decodeObject(of: NSString.self, forKey: "id") as String?).flatMap(UUID.init(uuidString:)) ?? UUID()
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        let v = (coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "transform") as? [NSNumber] ?? []).map { $0.floatValue }
        transform = v.count == 16 ? simd_float4x4(SIMD4(v[0], v[1], v[2], v[3]), SIMD4(v[4], v[5], v[6], v[7]),
                                                   SIMD4(v[8], v[9], v[10], v[11]), SIMD4(v[12], v[13], v[14], v[15])) : matrix_identity_float4x4
        super.init()
    }
    @objc open override var description: String { "<\(Swift.type(of: self)) identifier=\"\(identifier.uuidString)\"\(name.map { " name=\"\($0)\"" } ?? "")>" }
}

/// An anchor that the session tracks (images, faces, bodies).
public protocol ARTrackable: AnyObject {
    var isTracked: Bool { get }
}

/// A detected flat surface.
@objc(ARPlaneAnchor) open class ARPlaneAnchor: ARAnchor, @unchecked Sendable {
    public enum Alignment: Int, Sendable { case horizontal = 0, vertical = 1 }
    public enum Classification: Equatable, Sendable {
        public enum Status: Int, Sendable { case notAvailable = 0, undetermined = 1, unknown = 2 }
        case none(Status), wall, floor, ceiling, table, seat, window, door
    }
    @objc open class var isClassificationSupported: Bool { false }
    open internal(set) var alignment: Alignment = .horizontal
    open internal(set) var center = simd_float3()
    @objc open internal(set) var planeExtent = ARPlaneExtent()
    @objc open internal(set) var geometry = ARPlaneGeometry()
    open internal(set) var classification: Classification = .none(.notAvailable)
    @objc public required init(anchor: ARAnchor) {
        super.init(anchor: anchor)
        if let p = anchor as? ARPlaneAnchor { alignment = p.alignment; center = p.center; planeExtent = p.planeExtent; classification = p.classification }
    }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
}

@objc(ARPlaneExtent) open class ARPlaneExtent: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc open internal(set) var width: Float = 0
    @objc open internal(set) var height: Float = 0
    @objc open internal(set) var rotationOnYAxis: Float = 0
    @objc override init() { super.init() }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(width, forKey: "w"); coder.encode(height, forKey: "h"); coder.encode(rotationOnYAxis, forKey: "r") }
    @objc public required init?(coder: NSCoder) { width = coder.decodeFloat(forKey: "w"); height = coder.decodeFloat(forKey: "h"); rotationOnYAxis = coder.decodeFloat(forKey: "r") }
}

@objc(ARPlaneGeometry) open class ARPlaneGeometry: NSObject, NSSecureCoding, @unchecked Sendable {
    open internal(set) var vertices: [simd_float3] = []
    open internal(set) var textureCoordinates: [simd_float2] = []
    open internal(set) var triangleIndices: [Int16] = []
    open internal(set) var boundaryVertices: [simd_float3] = []
    @objc open var vertexCount: Int { vertices.count }
    @objc open var triangleCount: Int { triangleIndices.count / 3 }
    @objc override init() { super.init() }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public required init?(coder: NSCoder) {}
}

/// A detected reference image.
@objc(ARImageAnchor) open class ARImageAnchor: ARAnchor, ARTrackable, @unchecked Sendable {
    @objc open internal(set) var referenceImage = ARReferenceImage._empty
    @objc open internal(set) var estimatedScaleFactor: CGFloat = 1
    @objc open internal(set) var isTracked = false
    @objc public required init(anchor: ARAnchor) {
        super.init(anchor: anchor)
        if let a = anchor as? ARImageAnchor { referenceImage = a.referenceImage; estimatedScaleFactor = a.estimatedScaleFactor; isTracked = a.isTracked }
    }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// A detected reference object.
@objc(ARObjectAnchor) open class ARObjectAnchor: ARAnchor, @unchecked Sendable {
    @objc open internal(set) var referenceObject = ARReferenceObject()
    @objc public required init(anchor: ARAnchor) {
        super.init(anchor: anchor)
        if let a = anchor as? ARObjectAnchor { referenceObject = a.referenceObject }
    }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// A tracked face, with its expression.
@objc(ARFaceAnchor) open class ARFaceAnchor: ARAnchor, ARTrackable, @unchecked Sendable {
    public struct BlendShapeLocation: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let eyeBlinkLeft = BlendShapeLocation(rawValue: "eyeBlink_L")
        public static let eyeBlinkRight = BlendShapeLocation(rawValue: "eyeBlink_R")
        public static let jawOpen = BlendShapeLocation(rawValue: "jawOpen")
        public static let mouthSmileLeft = BlendShapeLocation(rawValue: "mouthSmile_L")
        public static let mouthSmileRight = BlendShapeLocation(rawValue: "mouthSmile_R")
        public static let browInnerUp = BlendShapeLocation(rawValue: "browInnerUp")
        public static let cheekPuff = BlendShapeLocation(rawValue: "cheekPuff")
        public static let tongueOut = BlendShapeLocation(rawValue: "tongueOut")
    }
    open internal(set) var blendShapes: [BlendShapeLocation: NSNumber] = [:]
    open internal(set) var leftEyeTransform = matrix_identity_float4x4
    open internal(set) var rightEyeTransform = matrix_identity_float4x4
    open internal(set) var lookAtPoint = simd_float3()
    @objc open internal(set) var isTracked = false
    @objc public required init(anchor: ARAnchor) {
        super.init(anchor: anchor)
        if let a = anchor as? ARFaceAnchor { blendShapes = a.blendShapes; isTracked = a.isTracked; lookAtPoint = a.lookAtPoint }
    }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// An environment probe for reflections.
@objc(AREnvironmentProbeAnchor) open class AREnvironmentProbeAnchor: ARAnchor, @unchecked Sendable {
    public init(transform: simd_float4x4, extent: simd_float3) { self.extent = extent; super.init(transform: transform) }
    public init(name: String, transform: simd_float4x4, extent: simd_float3) { self.extent = extent; super.init(name: name, transform: transform) }
    public let extent: simd_float3
    @objc open var environmentTexture: AnyObject? { nil }
    @objc public required init(anchor: ARAnchor) { extent = (anchor as? AREnvironmentProbeAnchor)?.extent ?? simd_float3(); super.init(anchor: anchor) }
    @objc public required init?(coder: NSCoder) { extent = simd_float3(); super.init(coder: coder) }
}

// MARK: - raycasting

@objc(ARRaycastQuery) open class ARRaycastQuery: NSObject, @unchecked Sendable {
    public enum Target: Int, Sendable { case existingPlaneGeometry = 0, existingPlaneInfinite = 1, estimatedPlane = 2 }
    public enum TargetAlignment: Int, Sendable { case horizontal = 0, vertical = 1, any = 2 }
    public let origin: simd_float3
    public let direction: simd_float3
    public let target: Target
    public let targetAlignment: TargetAlignment
    public init(origin: simd_float3, direction: simd_float3, allowing target: Target, alignment: TargetAlignment) {
        self.origin = origin; self.direction = direction; self.target = target; targetAlignment = alignment
    }
}

@objc(ARRaycastResult) open class ARRaycastResult: NSObject, @unchecked Sendable {
    public let worldTransform: simd_float4x4
    public let target: ARRaycastQuery.Target
    public let targetAlignment: ARRaycastQuery.TargetAlignment
    @objc public let anchor: ARAnchor?
    init(worldTransform: simd_float4x4, target: ARRaycastQuery.Target, alignment: ARRaycastQuery.TargetAlignment, anchor: ARAnchor?) {
        self.worldTransform = worldTransform; self.target = target; targetAlignment = alignment; self.anchor = anchor
    }
}

@objc(ARTrackedRaycast) open class ARTrackedRaycast: NSObject, @unchecked Sendable {
    @objc open func stopTracking() {}
}

// MARK: - reference images, objects and world maps

/// An image for the session to detect.
@objc(ARReferenceImage) open class ARReferenceImage: NSObject, @unchecked Sendable {
    @objc open var name: String?
    @objc public let physicalSize: CGSize
    @objc open internal(set) var resourceGroupName: String?
    @objc let _pixels: CGSize
    @objc static let _empty = ARReferenceImage(size: .zero, physicalWidth: 0)
    @objc init(size: CGSize, physicalWidth: CGFloat) {
        _pixels = size
        physicalSize = CGSize(width: physicalWidth, height: size.width > 0 ? physicalWidth * size.height / size.width : 0)
        super.init()
    }
    @objc public convenience init(_ image: CGImage, orientation: CGImagePropertyOrientation, physicalWidth: CGFloat) {
        let rotated = orientation.rawValue >= 5                // left / right orientations swap width and height
        self.init(size: rotated ? CGSize(width: image.height, height: image.width) : CGSize(width: image.width, height: image.height), physicalWidth: physicalWidth)
    }
    public convenience init(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, physicalWidth: CGFloat) {
        let w = CVPixelBufferGetWidth(pixelBuffer), h = CVPixelBufferGetHeight(pixelBuffer)
        let rotated = orientation.rawValue >= 5
        self.init(size: rotated ? CGSize(width: h, height: w) : CGSize(width: w, height: h), physicalWidth: physicalWidth)
    }
    /// The AR resource group's images from the asset catalog. isim's asset catalogs carry no AR groups: nil.
    @objc open class func referenceImages(inGroupNamed name: String, bundle: Bundle?) -> Set<ARReferenceImage>? { nil }
    /// checks the image is usable for detection (isim: big enough, a positive physical size)
    @objc open func validate(completionHandler: @escaping (Error?) -> Void) {
        let ok = _pixels.width >= 64 && _pixels.height >= 64 && physicalSize.width > 0
        DispatchQueue.main.async { completionHandler(ok ? nil : ARError(.invalidReferenceImage)) }
    }
}

/// A scanned 3D object for the session to detect.
@objc(ARReferenceObject) open class ARReferenceObject: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc open var name: String?
    open internal(set) var center = simd_float3()
    open internal(set) var extent = simd_float3()
    open internal(set) var scale = simd_float3(1, 1, 1)
    @objc open internal(set) var rawFeaturePoints = ARPointCloud(points: [], identifiers: [])
    @objc open internal(set) var resourceGroupName: String?
    @objc override init() { super.init() }
    @objc public static let archiveExtension = "arobject"
    @objc public convenience init(archiveURL url: URL) throws {
        guard let d = try? Data(contentsOf: url), let o = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARReferenceObject.self, from: d) else {
            throw ARError(.invalidReferenceObject)
        }
        self.init(); name = o.name; center = o.center; extent = o.extent
    }
    @objc open class func referenceObjects(inGroupNamed name: String, bundle: Bundle?) -> Set<ARReferenceObject>? { nil }
    @objc open func export(to url: URL, previewImage: UIImage?) throws {
        let d = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
        do { try d.write(to: url) } catch { throw ARError(.fileIOFailed) }
    }
    open func applyingTransform(_ transform: simd_float4x4) -> ARReferenceObject {
        let o = ARReferenceObject(); o.name = name
        let c = transform * SIMD4(center, 1); o.center = SIMD3(c.x, c.y, c.z); o.extent = extent
        return o
    }
    @objc open func merging(_ object: ARReferenceObject) throws -> ARReferenceObject { throw ARError(.objectMergeFailed) }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode([center.x, center.y, center.z, extent.x, extent.y, extent.z].map(NSNumber.init(value:)), forKey: "box")
    }
    @objc public required init?(coder: NSCoder) {
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        let v = (coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "box") as? [NSNumber] ?? []).map { $0.floatValue }
        if v.count == 6 { center = SIMD3(v[0], v[1], v[2]); extent = SIMD3(v[3], v[4], v[5]) }
        super.init()
    }
}

/// A saved world: anchors and feature points (isim's sessions never produce one; archived maps decode).
@objc(ARWorldMap) open class ARWorldMap: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open var anchors: [ARAnchor] = []
    open internal(set) var center = simd_float3()
    open internal(set) var extent = simd_float3()
    @objc open internal(set) var rawFeaturePoints = ARPointCloud(points: [], identifiers: [])
    @objc override init() { super.init() }
    @objc open func copy(with zone: NSZone? = nil) -> Any { let m = ARWorldMap(); m.anchors = anchors; m.center = center; m.extent = extent; return m }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(anchors, forKey: "anchors") }
    @objc public required init?(coder: NSCoder) {
        anchors = coder.decodeObject(of: [NSArray.self, ARAnchor.self], forKey: "anchors") as? [ARAnchor] ?? []
        super.init()
    }
}

// MARK: - views

public protocol ARSCNViewDelegate: SCNSceneRendererDelegate, ARSessionObserver {
    func renderer(_ renderer: any SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode?
    func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)
    func renderer(_ renderer: any SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor)
    func renderer(_ renderer: any SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor)
    func renderer(_ renderer: any SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor)
}
extension ARSCNViewDelegate {
    public func renderer(_ renderer: any SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? { SCNNode() }
    public func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {}
    public func renderer(_ renderer: any SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {}
    public func renderer(_ renderer: any SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {}
    public func renderer(_ renderer: any SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {}
}

/// SceneKit content over the camera feed. On isim there is no camera feed (the session fails, as in the
/// Simulator): the view draws its scene over black. Its delegate gets the session's events.
/// Adapted: `delegate` keeps SCNView's type (any SCNSceneRendererDelegate), since Swift cannot narrow it.
@MainActor @objc(ARSCNView) open class ARSCNView: SCNView, _ARSessionViewing {
    @objc public override init(frame: CGRect) { super.init(frame: frame); _setUp() }
    @objc public override init(frame: CGRect, options: [String: Any]? = nil) { super.init(frame: frame, options: options); _setUp() }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder); _setUp() }
    @objc func _setUp() { backgroundColor = .black; scene = SCNScene(); session._views.add(self) }
    @objc open var session = ARSession() {
        didSet { oldValue._views.remove(self); session._views.add(self) }
    }
    @objc open var automaticallyUpdatesLighting = true
    @objc open var rendersCameraGrain = true
    @objc open var rendersMotionBlur = false
    nonisolated var _sessionObserver: (any ARSessionObserver)? { MainActor.assumeIsolated { delegate as? any ARSessionObserver } }
    @objc var _nodes: [UUID: SCNNode] = [:]
    @objc open func anchor(for node: SCNNode) -> ARAnchor? {
        guard let id = _nodes.first(where: { $0.value === node })?.key else { return nil }
        return session._anchors.first { $0.identifier == id }
    }
    @objc open func node(for anchor: ARAnchor) -> SCNNode? { _nodes[anchor.identifier] }
    open func raycastQuery(from point: CGPoint, allowing target: ARRaycastQuery.Target, alignment: ARRaycastQuery.TargetAlignment) -> ARRaycastQuery? {
        session.currentFrame?.raycastQuery(from: point, allowing: target, alignment: alignment)
    }
    open func unprojectPoint(_ point: CGPoint, ontoPlane planeTransform: simd_float4x4) -> simd_float3? {
        session.currentFrame?.camera.unprojectPoint(point, ontoPlane: planeTransform, orientation: .portrait, viewportSize: bounds.size)
    }
}

public protocol ARSKViewDelegate: ARSessionObserver {
    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode?
    func view(_ view: ARSKView, didAdd node: SKNode, for anchor: ARAnchor)
    func view(_ view: ARSKView, willUpdate node: SKNode, for anchor: ARAnchor)
    func view(_ view: ARSKView, didUpdate node: SKNode, for anchor: ARAnchor)
    func view(_ view: ARSKView, didRemove node: SKNode, for anchor: ARAnchor)
}
extension ARSKViewDelegate {
    public func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? { SKNode() }
    public func view(_ view: ARSKView, didAdd node: SKNode, for anchor: ARAnchor) {}
    public func view(_ view: ARSKView, willUpdate node: SKNode, for anchor: ARAnchor) {}
    public func view(_ view: ARSKView, didUpdate node: SKNode, for anchor: ARAnchor) {}
    public func view(_ view: ARSKView, didRemove node: SKNode, for anchor: ARAnchor) {}
}

/// SpriteKit content over the camera feed (no camera feed on isim: the scene draws over black).
@MainActor @objc(ARSKView) open class ARSKView: SKView, _ARSessionViewing {
    @objc public override init(frame: CGRect) { super.init(frame: frame); _setUp() }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder); _setUp() }
    @objc func _setUp() { backgroundColor = .black; session._views.add(self) }
    @objc open var session = ARSession() {
        didSet { oldValue._views.remove(self); session._views.add(self) }
    }
    nonisolated var _sessionObserver: (any ARSessionObserver)? { MainActor.assumeIsolated { delegate as? any ARSessionObserver } }
    @objc open func anchor(for node: SKNode) -> ARAnchor? { nil }
    @objc open func node(for anchor: ARAnchor) -> SKNode? { nil }
}

public protocol ARCoachingOverlayViewDelegate: AnyObject {
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView)
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView)
    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView)
}
extension ARCoachingOverlayViewDelegate {
    public func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {}
    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {}
    public func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {}
}

/// The "move your device" coaching overlay. Adapted: with no tracking it never activates on its own; `setActive`
/// shows it (a translucent panel with the goal's instruction).
@MainActor @objc(ARCoachingOverlayView) open class ARCoachingOverlayView: UIView {
    public enum Goal: Int, Sendable { case tracking = 0, horizontalPlane = 1, verticalPlane = 2, anyPlane = 3, geoTracking = 4 }
    @objc public override init(frame: CGRect) { super.init(frame: frame); _setUp() }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder); _setUp() }
    open weak var delegate: (any ARCoachingOverlayViewDelegate)?
    @objc open var session: ARSession?
    open weak var sessionProvider: (any ARSessionProviding)?
    open var goal: Goal = .tracking { didSet { _label.text = _text } }
    @objc open var activatesAutomatically = true
    @objc open private(set) var isActive = false
    @objc let _label = UILabel()
    @objc func _setUp() {
        isHidden = true
        backgroundColor = UIColor(white: 0, alpha: 0.55)
        _label.textColor = .white; _label.font = .systemFont(ofSize: 17, weight: .semibold)
        _label.textAlignment = .center; _label.numberOfLines = 0; _label.text = _text
        addSubview(_label)
    }
    @objc var _text: String {
        switch goal {
        case .horizontalPlane: return "Move iPhone to start\nFind a flat surface"
        case .verticalPlane: return "Move iPhone to start\nFind a wall"
        case .anyPlane: return "Move iPhone to start\nFind a surface"
        case .geoTracking: return "Look at nearby buildings"
        default: return "Move iPhone to start"
        }
    }
    @objc open override func layoutSubviews() { super.layoutSubviews(); _label.frame = bounds.insetBy(dx: 24, dy: 0) }
    @objc open func setActive(_ active: Bool, animated: Bool) {
        guard active != isActive else { return }
        if active { delegate?.coachingOverlayViewWillActivate(self) }
        isActive = active; isHidden = !active
        if !active { delegate?.coachingOverlayViewDidDeactivate(self) }
    }
}

public protocol ARSessionProviding: AnyObject {
    var session: ARSession { get }
}
