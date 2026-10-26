// isim SceneKit: the renderers (issue #330). SCNView draws its scene into its CAMetalLayer with isim's Metal on the
// CPU; SCNRenderer draws into an app's own Metal render pass or an image. The render loop runs at the view's frame rate:
// it runs actions, animations and physics, calls the delegate as SceneKit does, and redraws when the scene changed (or
// while playing / rendering continuously). Adapted: one sample per pixel (antialiasingMode is kept), and
// allowsCameraControl orbits and zooms the camera with pan and pinch gestures (the camera controller's other
// interaction modes are not provided).
import UIKit
import Metal
import simd

public protocol SCNSceneRendererDelegate: AnyObject {
    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval)
    func renderer(_ renderer: any SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval)
    func renderer(_ renderer: any SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval)
    func renderer(_ renderer: any SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval)
    func renderer(_ renderer: any SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval)
    func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval)
}
extension SCNSceneRendererDelegate {
    public func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {}
    public func renderer(_ renderer: any SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {}
    public func renderer(_ renderer: any SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {}
    public func renderer(_ renderer: any SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) {}
    public func renderer(_ renderer: any SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {}
    public func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {}
}

public enum SCNAntialiasingMode: UInt, Sendable { case none = 0, multisampling2X = 1, multisampling4X = 2 }
public enum SCNRenderingAPI: UInt, Sendable { case metal = 0 }
public struct SCNDebugOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let showPhysicsShapes = SCNDebugOptions(rawValue: 1 << 0)
    public static let showBoundingBoxes = SCNDebugOptions(rawValue: 1 << 1)
    public static let showLightInfluences = SCNDebugOptions(rawValue: 1 << 2)
    public static let showLightExtents = SCNDebugOptions(rawValue: 1 << 3)
    public static let showPhysicsFields = SCNDebugOptions(rawValue: 1 << 4)
    public static let showWireframe = SCNDebugOptions(rawValue: 1 << 5)
    public static let renderAsWireframe = SCNDebugOptions(rawValue: 1 << 6)
    public static let showSkeletons = SCNDebugOptions(rawValue: 1 << 7)
    public static let showCreases = SCNDebugOptions(rawValue: 1 << 8)
    public static let showConstraints = SCNDebugOptions(rawValue: 1 << 9)
    public static let showCameras = SCNDebugOptions(rawValue: 1 << 10)
}

public protocol SCNSceneRenderer: AnyObject {
    var scene: SCNScene! { get set }
    var sceneTime: TimeInterval { get set }
    var delegate: (any SCNSceneRendererDelegate)? { get set }
    var isPlaying: Bool { get set }
    var loops: Bool { get set }
    var pointOfView: SCNNode? { get set }
    var autoenablesDefaultLighting: Bool { get set }
    var isJitteringEnabled: Bool { get set }
    var isTemporalAntialiasingEnabled: Bool { get set }
    var showsStatistics: Bool { get set }
    var debugOptions: SCNDebugOptions { get set }
    var renderingAPI: SCNRenderingAPI { get }
    var device: MTLDevice? { get }
    var commandQueue: MTLCommandQueue? { get }
    var colorPixelFormat: MTLPixelFormat { get }
    var depthPixelFormat: MTLPixelFormat { get }
    var stencilPixelFormat: MTLPixelFormat { get }
    var currentRenderCommandEncoder: MTLRenderCommandEncoder? { get }
    var currentRenderPassDescriptor: MTLRenderPassDescriptor { get }
    var currentViewport: CGRect { get }
    var currentTime: TimeInterval { get set }
    var usesReverseZ: Bool { get set }
    var workingColorSpace: CGColorSpace { get }
    func hitTest(_ point: CGPoint, options: [SCNHitTestOption: Any]?) -> [SCNHitTestResult]
    func isNode(_ node: SCNNode, insideFrustumOf pointOfView: SCNNode) -> Bool
    func nodesInsideFrustum(of pointOfView: SCNNode) -> [SCNNode]
    func projectPoint(_ point: SCNVector3) -> SCNVector3
    func unprojectPoint(_ point: SCNVector3) -> SCNVector3
    func prepare(_ object: Any, shouldAbortBlock block: (() -> Bool)?) -> Bool
    func prepare(_ objects: [Any], completionHandler: ((Bool) -> Void)?)
}

/// What every renderer runs each frame: actions, animations, physics and the delegate's callbacks
enum _SCNLoop {
    static func update(_ r: any SCNSceneRenderer, _ scene: SCNScene, time: TimeInterval, dt: TimeInterval, callDelegate: Bool) {
        let d = callDelegate ? r.delegate : nil
        d?.renderer(r, updateAtTime: time)
        if !scene.isPaused {
            _SCNActions.run(scene.rootNode, dt: dt)
            _SCNAnimations.run(scene.rootNode, time: time)
        }
        d?.renderer(r, didApplyAnimationsAtTime: time)
        if !scene.isPaused { scene._physics._step(dt) }
        d?.renderer(r, didSimulatePhysicsAtTime: time)
        d?.renderer(r, didApplyConstraintsAtTime: time)
    }
}

/// A view that shows a scene.
@MainActor @objc(SCNView) open class SCNView: UIView, @preconcurrency SCNSceneRenderer {
    public struct Option: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let preferredRenderingAPI = Option(rawValue: "SCNPreferredRenderingAPIKey")
        public static let preferredDevice = Option(rawValue: "SCNPreferredDeviceKey")
        public static let preferLowPowerDevice = Option(rawValue: "SCNPreferLowPowerDeviceKey")
    }
    @objc public override init(frame: CGRect) { super.init(frame: frame); _setUpView() }
    @objc public init(frame: CGRect, options: [String: Any]? = nil) { super.init(frame: frame); _setUpView() }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder); _setUpView() }
    open override class var layerClass: AnyClass { CAMetalLayer.self }
    var _metalLayer: CAMetalLayer { layer as! CAMetalLayer }
    func _setUpView() {
        _metalLayer.device = _SCNEngine.shared?.device
        _metalLayer.pixelFormat = .bgra8Unorm_srgb
        _metalLayer.isOpaque = false
        if backgroundColor == nil { backgroundColor = .white }
    }
    /// SCNScene! (iOS: optional on SCNView, non-optional on ARSCNView; Swift cannot narrow an inherited property)
    @objc open var scene: SCNScene! { didSet { _core.defaultCamera = nil; _needsDraw = true; _restart() } }
    @objc open var sceneTime: TimeInterval = 0
    open weak var delegate: (any SCNSceneRendererDelegate)?
    @objc open var isPlaying = false { didSet { _restart() } }
    @objc open var loops = true
    @objc open var pointOfView: SCNNode? {
        get { _pointOfView ?? _core.defaultCamera }
        set { _pointOfView = newValue; _needsDraw = true }
    }
    var _pointOfView: SCNNode?
    @objc open var autoenablesDefaultLighting = false { didSet { _needsDraw = true } }
    @objc open var isJitteringEnabled = false
    @objc open var isTemporalAntialiasingEnabled = false
    @objc open var showsStatistics = false
    open var debugOptions: SCNDebugOptions = []
    @objc open var allowsCameraControl = false { didSet { _updateGestures() } }
    @objc open var rendersContinuously = false { didSet { _restart() } }
    @objc open var preferredFramesPerSecond = 60 { didSet { _restart() } }
    open var antialiasingMode: SCNAntialiasingMode = .multisampling4X
    @objc open var usesReverseZ = true
    @objc open var currentTime: TimeInterval = 0
    open var renderingAPI: SCNRenderingAPI { .metal }
    @objc open var device: MTLDevice? { _SCNEngine.shared?.device }
    @objc open var commandQueue: MTLCommandQueue? { _SCNEngine.shared?.queue }
    open var colorPixelFormat: MTLPixelFormat { _metalLayer.pixelFormat }
    open var depthPixelFormat: MTLPixelFormat { .depth32Float }
    open var stencilPixelFormat: MTLPixelFormat { .invalid }
    @objc open var currentRenderCommandEncoder: MTLRenderCommandEncoder? { _encoder }
    @objc open var currentRenderPassDescriptor: MTLRenderPassDescriptor { _pass ?? MTLRenderPassDescriptor() }
    @objc open var currentViewport: CGRect { CGRect(origin: .zero, size: _metalLayer.drawableSize) }
    open var workingColorSpace: CGColorSpace { CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB() }
    @objc open func play(_ sender: Any?) { isPlaying = true }
    @objc open func pause(_ sender: Any?) { isPlaying = false }
    @objc open func stop(_ sender: Any?) { isPlaying = false; sceneTime = 0 }
    /// the scene drawn now, as an image
    @objc open func snapshot() -> UIImage {
        guard let scene else { return UIGraphicsImageRenderer(bounds: bounds).image { _ in drawHierarchy(in: bounds, afterScreenUpdates: false) } }
        let scale = window?.screen.scale ?? UIScreen.main.scale
        return _core.image(scene, pov: _pointOfView, size: bounds.size, scale: scale, clear: _clearColor, defaultLighting: autoenablesDefaultLighting)
            ?? UIImage()
    }
    @objc open func prepare(_ object: Any, shouldAbortBlock block: (() -> Bool)?) -> Bool { true }
    open func prepare(_ objects: [Any], completionHandler: ((Bool) -> Void)?) { DispatchQueue.main.async { completionHandler?(true) } }

    // projection and picking
    @objc open func isNode(_ node: SCNNode, insideFrustumOf pointOfView: SCNNode) -> Bool { _prepareCore(); return _core.inside(node, pov: pointOfView) }
    @objc open func nodesInsideFrustum(of pointOfView: SCNNode) -> [SCNNode] {
        guard let scene else { return [] }
        _prepareCore()
        return scene.rootNode.childNodes { n, _ in n.geometry != nil && _core.inside(n, pov: pointOfView) }
    }
    open func projectPoint(_ point: SCNVector3) -> SCNVector3 { _prepareCore(); return SCNVector3(_core.project(SIMD3(point))) }
    open func unprojectPoint(_ point: SCNVector3) -> SCNVector3 { _prepareCore(); return SCNVector3(_core.unproject(SIMD3(point))) }
    open func hitTest(_ point: CGPoint, options: [SCNHitTestOption: Any]? = nil) -> [SCNHitTestResult] {
        guard let scene else { return [] }
        _prepareCore()
        let a = _core.unproject(SIMD3(Float(point.x), Float(point.y), 0)), b = _core.unproject(SIMD3(Float(point.x), Float(point.y), 1))
        var o: [String: Any] = [:]
        for (k, v) in options ?? [:] { o[k.rawValue] = v }
        return _SCNHitTest.segment(root: scene.rootNode, from: a, to: b, options: o, segment: false)
    }

    // the render loop
    let _core = _SCNRenderCore()
    @objc var _timer: Timer?
    var _start: TimeInterval?, _last: TimeInterval?
    var _drawnGeneration = -1, _drawnSize = CGSize.zero, _needsDraw = true, _inFlight = false
    var _depth: MTLTexture?
    var _encoder: MTLRenderCommandEncoder?, _pass: MTLRenderPassDescriptor?
    @objc open override func didMoveToWindow() { super.didMoveToWindow(); _restart() }
    @objc open override func layoutSubviews() { super.layoutSubviews(); _needsDraw = true; if window != nil { _frame() } }
    open override var backgroundColor: UIColor? { didSet { _needsDraw = true } }
    @objc func _restart() {
        _timer?.invalidate(); _timer = nil
        guard window != nil, scene != nil else { return }
        let fps = max(1, preferredFramesPerSecond)
        _timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(fps), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?._frame() }
        }
    }
    /// matrices for projection and hit tests before the first frame: compute them without drawing
    func _prepareCore() {
        guard let scene, _drawnGeneration < 0 || _core.viewport != bounds.size else { return }
        let frame = _SCNFrame.collect(scene.rootNode)
        let eye = _core.pointOfView(_pointOfView, scene, frame)
        let (t, q, _) = _SCN.decompose(eye._presented ?? eye.simdWorldTransform)
        _core.view = _SCN.inverse(_SCN.compose(t, q, SIMD3(1, 1, 1)))
        _core.projection = _core.projection(eye.camera ?? SCNCamera(), bounds.size, view: _core.view, frame: frame, root: scene.rootNode)
        _core.viewport = bounds.size
    }
    var _clearColor: SIMD4<Float> {
        if let c = scene?.background.contents as? UIColor { return _SCNColor.linear(c) }
        return _SCNColor.linear(backgroundColor ?? .white)
    }
    /// one turn of SceneKit's render loop
    @objc func _frame() {
        guard let scene else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if _start == nil { _start = now - sceneTime }
        if isPlaying { sceneTime = now - (_start ?? now) }
        let dt = min(max(now - (_last ?? now), 0), 0.25)
        _last = now
        currentTime = now
        _SCNLoop.update(self, scene, time: now, dt: dt, callDelegate: true)
        _renderFrame(now)
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        let changed = _needsDraw || _drawnGeneration != _SCNDirty.generation || _drawnSize != size || isPlaying || rendersContinuously
        guard changed, !_inFlight, size.width >= 1, size.height >= 1, let e = _SCNEngine.shared else { return }
        delegate?.renderer(self, willRenderScene: scene, atTime: now)
        _draw(scene, e, size: size, scale: scale)
        delegate?.renderer(self, didRenderScene: scene, atTime: now)
    }
    func _draw(_ scene: SCNScene, _ e: _SCNEngine, size: CGSize, scale: CGFloat) {
        _metalLayer.contentsScale = scale
        _metalLayer.drawableSize = size
        guard let drawable = _metalLayer.nextDrawable(), let cb = e.queue.makeCommandBuffer() else { return }
        _drawnGeneration = _SCNDirty.generation; _drawnSize = size; _needsDraw = false
        if _depth?.width != Int(size.width) || _depth?.height != Int(size.height) {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(size.width), height: Int(size.height), mipmapped: false)
            d.usage = .renderTarget; d.storageMode = .private
            _depth = e.device.makeTexture(descriptor: d)
        }
        let pass = MTLRenderPassDescriptor()
        let c = _clearColor
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(c.x * c.w), green: Double(c.y * c.w), blue: Double(c.z * c.w), alpha: Double(c.w))
        pass.depthAttachment.texture = _depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        guard let enc = cb.makeRenderCommandEncoder(descriptor: pass) else { return }
        _encoder = enc; _pass = pass
        _core.encode(scene, pov: _pointOfView, encoder: enc, pixels: size, points: bounds.size, color: _metalLayer.pixelFormat, depth: .depth32Float,
                     defaultLighting: autoenablesDefaultLighting)
        enc.endEncoding()
        _encoder = nil
        _inFlight = true
        cb.addCompletedHandler { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?._inFlight = false } }
        }
        cb.present(drawable)
        cb.commit()
    }
    /// subclasses' per-frame work (ARSCNView updates its anchors' nodes)
    @objc func _renderFrame(_ time: TimeInterval) {}

    // camera control: one finger orbits the camera around the scene's centre, a pinch moves it closer
    var _gestures: [UIGestureRecognizer] = []
    var _orbitTarget = SIMD3<Float>(0, 0, 0)
    func _updateGestures() {
        _gestures.forEach(removeGestureRecognizer)
        _gestures = []
        guard allowsCameraControl else { return }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(_isimPan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(_isimPinch(_:)))
        _gestures = [pan, pinch]
        _gestures.forEach(addGestureRecognizer)
    }
    /// the camera that camera control moves: the point of view, or a free camera copied from it
    func _controlledCamera() -> SCNNode? {
        guard let scene else { return nil }
        let frame = _SCNFrame.collect(scene.rootNode)
        let eye = _core.pointOfView(_pointOfView, scene, frame)
        if eye === _core.defaultCamera { return eye }
        // SceneKit moves a copy of the camera, not the scene's own node
        let free = SCNNode()
        free.name = "kSCNFreeViewCameraName"
        free.camera = eye.camera?.copy() as? SCNCamera
        free.simdTransform = eye._presented ?? eye.simdWorldTransform
        _core.defaultCamera = free
        _pointOfView = free
        return free
    }
    @objc func _isimPan(_ g: UIPanGestureRecognizer) {
        guard let cam = _controlledCamera() else { return }
        if g.state == .began, let scene, let b = _SCN.bounds(of: scene.rootNode, in: matrix_identity_float4x4) { _orbitTarget = (b.0 + b.1) / 2 }
        let d = g.translation(in: self)
        g.setTranslation(.zero, in: self)
        let yaw = simd_quatf(angle: -Float(d.x) * .pi / Float(max(bounds.width, 1)), axis: SIMD3(0, 1, 0))
        let pitch = simd_quatf(angle: -Float(d.y) * .pi / Float(max(bounds.height, 1)), axis: cam.simdWorldRight)
        cam.simdRotate(by: yaw * pitch, aroundTarget: _orbitTarget)
    }
    @objc func _isimPinch(_ g: UIPinchGestureRecognizer) {
        guard let cam = _controlledCamera(), g.scale > 0 else { return }
        let offset = cam.simdWorldPosition - _orbitTarget
        cam.simdWorldPosition = _orbitTarget + offset / Float(g.scale)
        g.scale = 1
    }
}

/// A renderer that draws a scene into an app's Metal render pass, or into an image.
@objc(SCNRenderer) open class SCNRenderer: NSObject, SCNSceneRenderer, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc public convenience init(device: MTLDevice?, options: [AnyHashable: Any]? = nil) { self.init() }
    @objc open var scene: SCNScene! { didSet { _core.defaultCamera = nil } }
    @objc open var sceneTime: TimeInterval = 0
    open weak var delegate: (any SCNSceneRendererDelegate)?
    @objc open var isPlaying = false
    @objc open var loops = true
    @objc open var pointOfView: SCNNode? {
        get { _pointOfView ?? _core.defaultCamera }
        set { _pointOfView = newValue }
    }
    var _pointOfView: SCNNode?
    @objc open var autoenablesDefaultLighting = false
    @objc open var isJitteringEnabled = false
    @objc open var isTemporalAntialiasingEnabled = false
    @objc open var showsStatistics = false
    open var debugOptions: SCNDebugOptions = []
    @objc open var usesReverseZ = true
    @objc open var currentTime: TimeInterval = 0
    /// the time to render the next frame at
    @objc open var nextFrameTime: CFTimeInterval { currentTime + 1.0 / 60 }
    open var renderingAPI: SCNRenderingAPI { .metal }
    @objc open var device: MTLDevice? { _SCNEngine.shared?.device }
    @objc open var commandQueue: MTLCommandQueue? { _SCNEngine.shared?.queue }
    open var colorPixelFormat: MTLPixelFormat { _color }
    open var depthPixelFormat: MTLPixelFormat { _depthFormat }
    open var stencilPixelFormat: MTLPixelFormat { .invalid }
    @objc open var currentRenderCommandEncoder: MTLRenderCommandEncoder? { _encoder }
    @objc open var currentRenderPassDescriptor: MTLRenderPassDescriptor { _pass ?? MTLRenderPassDescriptor() }
    @objc open var currentViewport: CGRect { _viewport }
    open var workingColorSpace: CGColorSpace { CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB() }
    let _core = _SCNRenderCore()
    var _encoder: MTLRenderCommandEncoder?, _pass: MTLRenderPassDescriptor?, _viewport = CGRect.zero
    var _color: MTLPixelFormat = .bgra8Unorm, _depthFormat: MTLPixelFormat = .invalid
    var _last: TimeInterval?
    var _cache: (generation: Int, size: CGSize, scene: SCNScene, image: UIImage)?

    /// runs actions, animations and physics up to a time (render(atTime:…) calls it)
    @objc(updateAtTime:) open func update(atTime time: CFTimeInterval) {
        guard let scene else { return }
        let dt = min(max(time - (_last ?? time), 0), 0.25)
        _last = time
        currentTime = time
        _SCNLoop.update(self, scene, time: time, dt: dt, callDelegate: true)
    }
    @objc(renderAtTime:viewport:commandBuffer:passDescriptor:)
    open func render(atTime time: CFTimeInterval, viewport: CGRect, commandBuffer: MTLCommandBuffer, passDescriptor renderPassDescriptor: MTLRenderPassDescriptor) {
        update(atTime: time)
        render(withViewport: viewport, commandBuffer: commandBuffer, passDescriptor: renderPassDescriptor)
    }
    @objc(renderWithViewport:commandBuffer:passDescriptor:)
    open func render(withViewport viewport: CGRect, commandBuffer: MTLCommandBuffer, passDescriptor renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let scene, let target = renderPassDescriptor.colorAttachments[0].texture,
              let enc = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        _viewport = viewport; _pass = renderPassDescriptor; _encoder = enc
        _color = target.pixelFormat
        _depthFormat = renderPassDescriptor.depthAttachment.texture?.pixelFormat ?? .invalid
        let size = viewport.size == .zero ? CGSize(width: target.width, height: target.height) : viewport.size
        delegate?.renderer(self, willRenderScene: scene, atTime: currentTime)
        _core.encode(scene, pov: _pointOfView, encoder: enc, pixels: size, points: size, color: _color, depth: _depthFormat,
                     defaultLighting: autoenablesDefaultLighting)
        delegate?.renderer(self, didRenderScene: scene, atTime: currentTime)
        enc.endEncoding()
        _encoder = nil
    }
    /// the scene at a time, drawn into an image of a size (points, at the screen's scale)
    open func snapshot(atTime time: CFTimeInterval, with size: CGSize, antialiasingMode: SCNAntialiasingMode) -> UIImage {
        guard let scene else { return UIImage() }
        update(atTime: time)
        let c: SIMD4<Float> = (scene.background.contents as? UIColor).map(_SCNColor.linear) ?? SIMD4(0, 0, 0, 0)
        _viewport = CGRect(origin: .zero, size: size)
        // the same scene, unchanged, at the same size: the last image
        if let cache = _cache, cache.generation == _SCNDirty.generation, cache.size == size, cache.scene === scene, !isPlaying { return cache.image }
        let image = _core.image(scene, pov: _pointOfView, size: size, scale: 1, clear: c, defaultLighting: autoenablesDefaultLighting) ?? UIImage()
        _cache = (_SCNDirty.generation, size, scene, image)
        return image
    }
    @objc open func isNode(_ node: SCNNode, insideFrustumOf pointOfView: SCNNode) -> Bool { _core.inside(node, pov: pointOfView) }
    @objc open func nodesInsideFrustum(of pointOfView: SCNNode) -> [SCNNode] {
        scene?.rootNode.childNodes { n, _ in n.geometry != nil && _core.inside(n, pov: pointOfView) } ?? []
    }
    open func projectPoint(_ point: SCNVector3) -> SCNVector3 { SCNVector3(_core.project(SIMD3(point))) }
    open func unprojectPoint(_ point: SCNVector3) -> SCNVector3 { SCNVector3(_core.unproject(SIMD3(point))) }
    open func hitTest(_ point: CGPoint, options: [SCNHitTestOption: Any]? = nil) -> [SCNHitTestResult] {
        guard let scene else { return [] }
        let a = _core.unproject(SIMD3(Float(point.x), Float(point.y), 0)), b = _core.unproject(SIMD3(Float(point.x), Float(point.y), 1))
        var o: [String: Any] = [:]
        for (k, v) in options ?? [:] { o[k.rawValue] = v }
        return _SCNHitTest.segment(root: scene.rootNode, from: a, to: b, options: o, segment: false)
    }
    @objc open func prepare(_ object: Any, shouldAbortBlock block: (() -> Bool)?) -> Bool { true }
    open func prepare(_ objects: [Any], completionHandler: ((Bool) -> Void)?) { DispatchQueue.main.async { completionHandler?(true) } }
}
