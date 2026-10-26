// isim SceneKit + SwiftUI (issue #330): SceneView shows a scene in a SwiftUI hierarchy (an SCNView underneath), and
// NSValue's SceneKit additions for Swift.
import SwiftUI

public struct SceneView: UIViewRepresentable {
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let allowsCameraControl = Options(rawValue: 1 << 0)
        public static let autoenablesDefaultLighting = Options(rawValue: 1 << 1)
        public static let jitteringEnabled = Options(rawValue: 1 << 2)
        public static let rendersContinuously = Options(rawValue: 1 << 3)
        public static let temporalAntialiasingEnabled = Options(rawValue: 1 << 4)
    }
    let scene: SCNScene?, pointOfView: SCNNode?, options: Options, fps: Int, antialiasingMode: SCNAntialiasingMode
    weak var delegate: (any SCNSceneRendererDelegate)?
    let technique: SCNTechnique?
    public init(scene: SCNScene? = nil, pointOfView: SCNNode? = nil, options: SceneView.Options = [], preferredFramesPerSecond: Int = 60,
                antialiasingMode: SCNAntialiasingMode = .multisampling4X, delegate: (any SCNSceneRendererDelegate)? = nil, technique: SCNTechnique? = nil) {
        self.scene = scene; self.pointOfView = pointOfView; self.options = options; fps = preferredFramesPerSecond
        self.antialiasingMode = antialiasingMode; self.delegate = delegate; self.technique = technique
    }
    public func makeUIView(context: Context) -> SCNView { SCNView(frame: .zero) }
    public func updateUIView(_ v: SCNView, context: Context) {
        if v.scene !== scene { v.scene = scene }
        if let pointOfView, v.pointOfView !== pointOfView { v.pointOfView = pointOfView }
        v.allowsCameraControl = options.contains(.allowsCameraControl)
        v.autoenablesDefaultLighting = options.contains(.autoenablesDefaultLighting)
        v.isJitteringEnabled = options.contains(.jitteringEnabled)
        v.rendersContinuously = options.contains(.rendersContinuously)
        v.isTemporalAntialiasingEnabled = options.contains(.temporalAntialiasingEnabled)
        if v.preferredFramesPerSecond != fps { v.preferredFramesPerSecond = fps }
        v.antialiasingMode = antialiasingMode
        v.delegate = delegate
        v.technique = technique
    }
}

/// A post-processing technique. Kept, not run (isim draws no post effects).
@objc(SCNTechnique) open class SCNTechnique: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var dictionaryRepresentation: [String: Any] = [:]
    @objc public convenience init?(dictionary: [String: Any]) { self.init(); dictionaryRepresentation = dictionary }
    @objc public convenience init?(bySequencingTechniques techniques: [SCNTechnique]) { self.init() }
    @objc public override init() { super.init() }
    @objc open func copy(with zone: NSZone? = nil) -> Any { self }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public required init?(coder: NSCoder) { super.init() }
}

extension SCNView {
    /// SCNTechniqueSupport: kept, not run
    @objc open var technique: SCNTechnique? {
        get { withUnsafePointer(to: &_SCNTechniqueKey.key) { objc_getAssociatedObject(self, $0) as? SCNTechnique } }
        set { withUnsafePointer(to: &_SCNTechniqueKey.key) { objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) } }
    }
}
enum _SCNTechniqueKey { nonisolated(unsafe) static var key = 0 }

extension NSValue {
    /// SceneKit's structs in a value (as SceneKit's Objective-C categories store them)
    public convenience init(scnVector3 v: SCNVector3) { var v = v; self.init(bytes: &v, objCType: "{SCNVector3=fff}") }
    public convenience init(scnVector4 v: SCNVector4) { var v = v; self.init(bytes: &v, objCType: "{SCNVector4=ffff}") }
    public convenience init(scnMatrix4 v: SCNMatrix4) { var v = v; self.init(bytes: &v, objCType: "{SCNMatrix4=ffffffffffffffff}") }
    public var scnVector3Value: SCNVector3 { var v = SCNVector3(); getValue(&v, size: MemoryLayout<SCNVector3>.size); return v }
    public var scnVector4Value: SCNVector4 { var v = SCNVector4(); getValue(&v, size: MemoryLayout<SCNVector4>.size); return v }
    public var scnMatrix4Value: SCNMatrix4 { var v = SCNMatrix4(); getValue(&v, size: MemoryLayout<SCNMatrix4>.size); return v }
}
