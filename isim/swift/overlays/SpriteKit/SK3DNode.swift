// isim SpriteKit: SK3DNode (issue #330), a SceneKit scene drawn as a sprite: an SCNRenderer renders the scene into an
// image of the node's viewport (at the view's scale) each frame the scene changes, and the node draws it.
import UIKit
import SceneKit
import simd

/// A node that shows a SceneKit scene.
@objc(SK3DNode) open class SK3DNode: SKNode {
    @objc public override init() { super.init() }
    @objc public init(viewportSize: CGSize) { super.init(); self.viewportSize = viewportSize }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
    @objc open var viewportSize: CGSize = .zero
    @objc open var scnScene: SCNScene? { didSet { _renderer.scene = scnScene } }
    @objc open var sceneTime: TimeInterval { get { _renderer.sceneTime } set { _renderer.sceneTime = newValue } }
    @objc open var isPlaying: Bool { get { _renderer.isPlaying } set { _renderer.isPlaying = newValue } }
    @objc open var loops: Bool { get { _renderer.loops } set { _renderer.loops = newValue } }
    @objc open var pointOfView: SCNNode? { get { _renderer.pointOfView } set { _renderer.pointOfView = newValue } }
    @objc open var autoenablesDefaultLighting: Bool {
        get { _renderer.autoenablesDefaultLighting }
        set { _renderer.autoenablesDefaultLighting = newValue }
    }
    let _renderer = SCNRenderer(device: nil, options: nil)
    var _scale: CGFloat = 1
    /// the scene drawn at the node's size (cached while it does not change): the renderer's matrices for picking
    @discardableResult func _render() -> UIImage? {
        guard scnScene != nil, viewportSize.width > 0, viewportSize.height > 0 else { return nil }
        _scale = UIScreen.main.scale
        let size = CGSize(width: (viewportSize.width * _scale).rounded(), height: (viewportSize.height * _scale).rounded())
        return _renderer.snapshot(atTime: ProcessInfo.processInfo.systemUptime, with: size, antialiasingMode: .none)
    }

    /// geometry under a point in the node's coordinates
    open func hitTest(_ point: CGPoint, options: [SCNHitTestOption: Any]? = nil) -> [SCNHitTestResult] {
        _render()
        // node space (y up, centred) to the viewport (y down, from the top left)
        let p = CGPoint(x: (point.x + viewportSize.width / 2) * _scale, y: (viewportSize.height / 2 - point.y) * _scale)
        return _renderer.hitTest(p, options: options)
    }
    /// a scene position to the node's coordinates (z: depth, 0 near, 1 far)
    open func projectPoint(_ point: vector_float3) -> vector_float3 {
        _render()
        let v = _renderer.projectPoint(SCNVector3(point))
        return vector_float3(Float(CGFloat(v.x) / _scale - viewportSize.width / 2), Float(viewportSize.height / 2 - CGFloat(v.y) / _scale), v.z)
    }
    open func unprojectPoint(_ point: vector_float3) -> vector_float3 {
        _render()
        let p = SCNVector3(Float((CGFloat(point.x) + viewportSize.width / 2) * _scale), Float((viewportSize.height / 2 - CGFloat(point.y)) * _scale), point.z)
        return vector_float3(_renderer.unprojectPoint(p))
    }

    override var contentRect: CGRect { CGRect(x: -viewportSize.width / 2, y: -viewportSize.height / 2, width: viewportSize.width, height: viewportSize.height) }
    override func drawContent(alpha a: CGFloat) {
        guard let cg = _render()?.cgImage else { return }
        _drawImage(cg, in: contentRect, alpha: a, blend: .alpha)
    }
}
