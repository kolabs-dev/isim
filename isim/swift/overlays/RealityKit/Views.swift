// isim RealityKit (issue #331): the views. ARView shows a scene without AR (cameraMode .nonAR; the AR mode shows black,
// as in the Simulator, since there is no camera), and SwiftUI's RealityView shows entities with a virtual camera. Both
// draw through an SCNView (isim's SceneKit renderer, Metal on the CPU). Adapted: the image-based lighting RealityKit
// applies by default is approximated by an ambient light, plus SceneKit's default light while the scene has no lights.
import UIKit
import SwiftUI
import SceneKit
import ARKit
import simd

/// An environment map. isim cannot load any (a skybox shows as the default background).
public final class EnvironmentResource: @unchecked Sendable {
    init() {}
    public static func load(named name: String, in bundle: Bundle? = nil) throws -> EnvironmentResource {
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnsupportedSchemeError,
                      userInfo: [NSLocalizedDescriptionKey: "isim's RealityKit cannot load environment maps"])
    }
}

/// A view that shows a RealityKit scene.
@MainActor @preconcurrency open class ARView: UIView {
    public enum CameraMode: Sendable { case ar, nonAR }
    public struct Environment {
        public struct Background {
            enum Kind { case color(UIColor), cameraFeed, skybox }
            let kind: Kind
            public static func color(_ color: UIColor) -> Background { Background(kind: .color(color)) }
            public static func cameraFeed(exposureCompensation: Float = 0) -> Background { Background(kind: .cameraFeed) }
            public static func skybox(_ resource: EnvironmentResource) -> Background { Background(kind: .skybox) }
        }
        public struct ImageBasedLight {
            public var resource: EnvironmentResource?
            public var intensityExponent: Float = 0
        }
        public var background: Background
        public var lighting = ImageBasedLight()
    }
    public struct DebugOptions: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let none = DebugOptions([])
        public static let showPhysics = DebugOptions(rawValue: 1 << 0)
        public static let showStatistics = DebugOptions(rawValue: 1 << 1)
        public static let showAnchorOrigins = DebugOptions(rawValue: 1 << 2)
        public static let showAnchorGeometry = DebugOptions(rawValue: 1 << 3)
        public static let showWorldOrigin = DebugOptions(rawValue: 1 << 4)
        public static let showFeaturePoints = DebugOptions(rawValue: 1 << 5)
        public static let showSceneUnderstanding = DebugOptions(rawValue: 1 << 6)
    }
    public struct RenderOptions: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let disableMotionBlur = RenderOptions(rawValue: 1 << 0)
        public static let disableDepthOfField = RenderOptions(rawValue: 1 << 1)
        public static let disableHDR = RenderOptions(rawValue: 1 << 2)
        public static let disableFaceMesh = RenderOptions(rawValue: 1 << 3)
        public static let disableGroundingShadows = RenderOptions(rawValue: 1 << 4)
        public static let disablePersonOcclusion = RenderOptions(rawValue: 1 << 5)
        public static let disableCameraGrain = RenderOptions(rawValue: 1 << 6)
        public static let disableAREnvironmentLighting = RenderOptions(rawValue: 1 << 7)
        public static let disableAreaDownsampling = RenderOptions(rawValue: 1 << 8)
    }

    public let scene: Scene
    open var cameraMode: CameraMode { didSet { _applyBackground() } }
    open var environment: Environment { didSet { _applyBackground() } }
    open var debugOptions: DebugOptions = []
    open var renderOptions: RenderOptions = []
    open var automaticallyConfigureSession: Bool
    open var session = ARSession()
    let _scnView = SCNView(frame: .zero)
    let _ambient = SCNNode()
    let _driver = _FrameDriver()

    public required override init(frame frameRect: CGRect) {
        scene = Scene(); cameraMode = .ar; automaticallyConfigureSession = true
        environment = Environment(background: .cameraFeed())
        super.init(frame: frameRect)
        _setUp()
    }
    public init(frame frameRect: CGRect, cameraMode: CameraMode, automaticallyConfigureSession: Bool) {
        scene = Scene(); self.cameraMode = cameraMode; self.automaticallyConfigureSession = automaticallyConfigureSession
        environment = Environment(background: cameraMode == .ar ? .cameraFeed() : .color(UIColor(white: 0.85, alpha: 1)))
        super.init(frame: frameRect)
        _setUp()
    }
    public required init?(coder decoder: NSCoder) {
        scene = Scene(); cameraMode = .ar; automaticallyConfigureSession = true
        environment = Environment(background: .cameraFeed())
        super.init(coder: decoder)
        _setUp()
    }
    func _setUp() {
        _scnView.frame = bounds
        _scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _scnView.scene = scene._scn
        _scnView.isPlaying = false
        _driver.view = self
        _scnView.delegate = _driver
        addSubview(_scnView)
        // the default environment lighting, as an ambient light
        _ambient.light = SCNLight()
        _ambient.light!.type = .ambient
        _ambient.light!.intensity = 350
        scene._scn.rootNode.addChildNode(_ambient)
        _applyBackground()
    }
    func _applyBackground() {
        switch environment.background.kind {
        case .color(let c):
            scene._scn.background.contents = c
            _scnView.backgroundColor = c
        case .cameraFeed:
            // no camera: black, as in the Simulator
            scene._scn.background.contents = cameraMode == .ar ? UIColor.black : UIColor(white: 0.85, alpha: 1)
            _scnView.backgroundColor = .black
        case .skybox:
            scene._scn.background.contents = UIColor(white: 0.85, alpha: 1)
        }
    }
    /// one frame: the scene's systems and update event; SceneKit's default light while the scene has no lights
    func _frame(_ dt: TimeInterval) {
        scene._update(dt)
        var lit = false
        scene._scn.rootNode.enumerateChildNodes { n, stop in
            if n !== _ambient, n.light != nil { lit = true; stop.pointee = true }
        }
        if _scnView.autoenablesDefaultLighting == lit { _scnView.autoenablesDefaultLighting = !lit }
    }

    /// the camera's transform in the world
    open var cameraTransform: Transform {
        let n = _scnView.pointOfView
        return n.map { Transform(matrix: $0.simdWorldTransform) } ?? .identity
    }
    open func entity(at point: CGPoint) -> Entity? { entities(at: point).first }
    open func entities(at point: CGPoint) -> [Entity] { hitTest(point).map(\.entity) }
    open func hitTest(_ point: CGPoint, query: CollisionCastQueryType = .all, mask: CollisionGroup = .all) -> [CollisionCastHit] {
        guard let r = ray(through: point) else { return [] }
        return scene.raycast(origin: r.origin, direction: r.direction, length: 10_000, query: query, mask: mask)
    }
    open func ray(through screenPoint: CGPoint) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? {
        let a = SIMD3<Float>(_scnView.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 0)))
        let b = SIMD3<Float>(_scnView.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 1)))
        let d = b - a
        return simd_length(d) > 0 ? (a, simd_normalize(d)) : nil
    }
    open func project(_ point: SIMD3<Float>) -> CGPoint? {
        let p = _scnView.projectPoint(SCNVector3(point))
        return p.z >= 0 && p.z <= 1 ? CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)) : nil
    }
    open func unproject(_ point: CGPoint, ontoPlane planeTransform: float4x4) -> SIMD3<Float>? {
        guard let r = ray(through: point) else { return nil }
        let n = simd_normalize(SIMD3(planeTransform.columns.1.x, planeTransform.columns.1.y, planeTransform.columns.1.z))
        let o = SIMD3(planeTransform.columns.3.x, planeTransform.columns.3.y, planeTransform.columns.3.z)
        let d = simd_dot(r.direction, n)
        guard abs(d) > 1e-6 else { return nil }
        let t = simd_dot(o - r.origin, n) / d
        return t >= 0 ? r.origin + r.direction * t : nil
    }
    open func snapshot(saveToHDR: Bool, completion: @escaping (UIImage?) -> Void) {
        let image = _scnView.snapshot()
        DispatchQueue.main.async { completion(image) }
    }
}

/// Drives a scene's frames from the SCNView's render loop
final class _FrameDriver: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
    weak var view: ARView?
    var last: TimeInterval?
    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = min(max(time - (last ?? time), 0), 0.25)
        last = time
        MainActor.assumeIsolated { view?._frame(dt) }
    }
}

// MARK: - SwiftUI

/// The camera a RealityView shows its content through.
public struct RealityViewCamera: Equatable, Sendable {
    let kind: Int
    public static let virtual = RealityViewCamera(kind: 0)
    public static let spatialTracking = RealityViewCamera(kind: 1)
    public static let worldTracking = RealityViewCamera(kind: 2)
}

/// How a person can move a RealityView's virtual camera.
public struct CameraControls: Equatable, Sendable {
    let kind: Int
    public static let none = CameraControls(kind: 0)
    public static let orbit = CameraControls(kind: 1)
    public static let pan = CameraControls(kind: 2)
    public static let tilt = CameraControls(kind: 3)
    public static let dolly = CameraControls(kind: 4)
}

/// A RealityView's entities.
public struct RealityViewEntityCollection: Collection, Sendable {
    let root: Entity
    public var startIndex: Int { 0 }
    public var endIndex: Int { MainActor.assumeIsolated { root._children.count } }
    public func index(after i: Int) -> Int { i + 1 }
    public subscript(i: Int) -> Entity { MainActor.assumeIsolated { root._children[i] } }
    public func append(_ entity: Entity) { MainActor.assumeIsolated { root.addChild(entity) } }
    public func append<S: Sequence>(contentsOf entities: S) where S.Element: Entity { for e in entities { append(e) } }
    public func remove(_ entity: Entity) { MainActor.assumeIsolated { root.removeChild(entity) } }
    public func removeAll() { for e in Array(self) { remove(e) } }
}

/// What RealityView's closures add entities to.
@MainActor public struct RealityViewCameraContent {
    let view: ARView
    let root: AnchorEntity
    public var entities: RealityViewEntityCollection { RealityViewEntityCollection(root: root) }
    public func add(_ entity: Entity) { root.addChild(entity) }
    public func remove(_ entity: Entity) { root.removeChild(entity) }
    public var camera: RealityViewCamera {
        get { view.cameraMode == .nonAR ? .virtual : .worldTracking }
        nonmutating set { view.cameraMode = newValue == .virtual ? .nonAR : .ar; view.environment.background = newValue == .virtual ? .color(.clear) : .cameraFeed() }
    }
    public func subscribe<E: Event>(to event: E.Type, on sourceObject: (any EventSource)? = nil,
                                    _ handler: @escaping (E) -> Void) -> EventSubscription {
        view.scene.subscribe(to: event, on: sourceObject, handler) as! EventSubscription
    }
    /// a point in an entity's space to the view (points), nil when it is behind the camera
    public func project(point: SIMD3<Float>, from entity: Entity? = nil) -> CGPoint? {
        let w = (entity?._node.simdWorldTransform ?? matrix_identity_float4x4) * SIMD4(point, 1)
        return view.project(SIMD3(w.x, w.y, w.z))
    }
}

/// The placeholder a RealityView shows while its make closure runs (nothing).
public struct RealityViewDefaultPlaceholder: View {
    public var body: some View { EmptyView() }
}

/// A SwiftUI view that shows RealityKit entities.
public struct RealityView<Content: View>: View {
    let make: @MainActor @Sendable (inout RealityViewCameraContent) async -> Void
    let update: (@MainActor (inout RealityViewCameraContent) -> Void)?
    public init(make: @escaping @MainActor @Sendable (inout RealityViewCameraContent) async -> Void,
                update: (@MainActor (inout RealityViewCameraContent) -> Void)? = nil) where Content == RealityViewDefaultPlaceholder {
        self.make = make; self.update = update
    }
    public init(make: @escaping @MainActor @Sendable (inout RealityViewCameraContent) async -> Void,
                update: (@MainActor (inout RealityViewCameraContent) -> Void)? = nil, @ViewBuilder placeholder: () -> Content) {
        self.make = make; self.update = update
    }
    public var body: some View { _RealityViewHost(make: make, update: update) }
}

struct _RealityViewHost: UIViewRepresentable {
    let make: @MainActor (inout RealityViewCameraContent) async -> Void
    let update: (@MainActor (inout RealityViewCameraContent) -> Void)?
    final class Coordinator { var content: RealityViewCameraContent?; var made = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let v = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        v.environment.background = .color(.clear)
        let root = AnchorEntity()
        root.name = "RealityView content"
        v.scene.addAnchor(root)
        var content = RealityViewCameraContent(view: v, root: root)
        context.coordinator.content = content
        let c = context.coordinator, update = update, make = make
        Task { @MainActor in
            await make(&content)
            c.made = true
            if let update { var u = content; update(&u) }
        }
        return v
    }
    func updateUIView(_ v: ARView, context: Context) {
        v._scnView.allowsCameraControl = context.environment._realityViewCameraControls != .none
        if context.coordinator.made, let update, var content = context.coordinator.content { update(&content) }
    }
}

struct _RealityViewCameraControlsKey: EnvironmentKey {
    static let defaultValue = CameraControls.none
}
extension EnvironmentValues {
    var _realityViewCameraControls: CameraControls {
        get { self[_RealityViewCameraControlsKey.self] }
        set { self[_RealityViewCameraControlsKey.self] = newValue }
    }
}
extension View {
    /// lets a person move a RealityView's virtual camera (orbit, pan, tilt, dolly: isim orbits and zooms)
    public func realityViewCameraControls(_ controls: CameraControls) -> some View {
        environment(\._realityViewCameraControls, controls)
    }
}
