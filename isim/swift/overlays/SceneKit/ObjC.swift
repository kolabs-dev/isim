// isim SceneKit: the Objective-C interface (sdk-src/Frameworks/SceneKit, issue #560). SCNNode, SCNScene and SCNView are
// @objc(SCN…) and @objcMembers; the members below are internal Objective-C entry points for what uses Swift-only types:
// SceneKit's vector and matrix structs (C structs in Objective-C, which SceneKit.framework's categories,
// frameworks/SceneKit/SceneKit.m, pass through these `_isim_` NSArray entry points), the simd types, the antialiasing
// enum and the renderer delegate, a Swift protocol here: an Objective-C delegate is held through a forwarding box.
import UIKit
import simd

/// Apple's SCNSceneRendererDelegate as Objective-C sees it
@objc(SCNSceneRendererDelegate) protocol _SCNObjCRendererDelegate: NSObjectProtocol {
    @objc(renderer:updateAtTime:) optional func _update(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:didApplyAnimationsAtTime:) optional func _animations(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:didSimulatePhysicsAtTime:) optional func _physics(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:didApplyConstraintsAtTime:) optional func _constraints(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:willRenderScene:atTime:) optional func _willRender(_ r: AnyObject, _ s: SCNScene, _ t: TimeInterval)
    @objc(renderer:didRenderScene:atTime:) optional func _didRender(_ r: AnyObject, _ s: SCNScene, _ t: TimeInterval)
}
final class _SCNRendererDelegateBox: SCNSceneRendererDelegate {
    weak var t: _SCNObjCRendererDelegate?
    init(_ t: _SCNObjCRendererDelegate) { self.t = t }
    func renderer(_ r: any SCNSceneRenderer, updateAtTime time: TimeInterval) { t?._update?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) { t?._animations?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) { t?._physics?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) { t?._constraints?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) { t?._willRender?(r, scene, time) }
    func renderer(_ r: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) { t?._didRender?(r, scene, time) }
}

enum _SCNObjC {
    nonisolated(unsafe) static var boxKey = 0
    static func v3(_ v: SCNVector3) -> [NSNumber] { [NSNumber(value: v.x), NSNumber(value: v.y), NSNumber(value: v.z)] }
    static func v3(_ a: [NSNumber]) -> SCNVector3 { SCNVector3(a[0].floatValue, a[1].floatValue, a[2].floatValue) }
    static func v4(_ v: SCNVector4) -> [NSNumber] { [NSNumber(value: v.x), NSNumber(value: v.y), NSNumber(value: v.z), NSNumber(value: v.w)] }
    static func v4(_ a: [NSNumber]) -> SCNVector4 { SCNVector4(a[0].floatValue, a[1].floatValue, a[2].floatValue, a[3].floatValue) }
    /// m11 … m44 (column by column, as simd_float4x4's columns)
    static func m4(_ m: simd_float4x4) -> [NSNumber] { (0..<4).flatMap { c in (0..<4).map { r in NSNumber(value: m[c, r]) } } }
    static func m4(_ a: [NSNumber]) -> simd_float4x4 {
        var m = simd_float4x4()
        for c in 0..<4 { for r in 0..<4 { m[c, r] = a[c * 4 + r].floatValue } }
        return m
    }
    static func f3(_ v: SIMD3<Float>) -> [NSNumber] { [NSNumber(value: v.x), NSNumber(value: v.y), NSNumber(value: v.z)] }
    static func f3(_ a: [NSNumber]) -> SIMD3<Float> { SIMD3(a[0].floatValue, a[1].floatValue, a[2].floatValue) }
}

extension SCNNode {
    @objc(parentNode) var _objcParentNode: SCNNode? { parent }
    @objc(presentationNode) var _objcPresentationNode: SCNNode { presentation }
    @objc(enumerateChildNodesUsingBlock:) func _objcEnumerateChildNodes(_ block: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Void) { enumerateChildNodes(block) }
    @objc(enumerateHierarchyUsingBlock:) func _objcEnumerateHierarchy(_ block: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Void) { enumerateHierarchy(block) }
    @objc(insertChildNode:atIndex:) func _objcInsert(_ child: SCNNode, atIndex index: Int) { insertChildNode(child, at: index) }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _SCNObjC.v3(position) } set { position = _SCNObjC.v3(newValue) } }
    @objc(_isim_scale) var _isimScale: [NSNumber] { get { _SCNObjC.v3(scale) } set { scale = _SCNObjC.v3(newValue) } }
    @objc(_isim_eulerAngles) var _isimEulerAngles: [NSNumber] { get { _SCNObjC.v3(eulerAngles) } set { eulerAngles = _SCNObjC.v3(newValue) } }
    @objc(_isim_worldPosition) var _isimWorldPosition: [NSNumber] { get { _SCNObjC.v3(worldPosition) } set { worldPosition = _SCNObjC.v3(newValue) } }
    @objc(_isim_orientation) var _isimOrientation: [NSNumber] { get { _SCNObjC.v4(orientation) } set { orientation = _SCNObjC.v4(newValue) } }
    @objc(_isim_rotation) var _isimRotation: [NSNumber] { get { _SCNObjC.v4(rotation) } set { rotation = _SCNObjC.v4(newValue) } }
    @objc(_isim_transform) var _isimTransform: [NSNumber] { get { _SCNObjC.m4(simdTransform) } set { simdTransform = _SCNObjC.m4(newValue) } }
    @objc(_isim_worldTransform) var _isimWorldTransform: [NSNumber] {
        get { _SCNObjC.m4(simdWorldTransform) }
        set { simdWorldTransform = _SCNObjC.m4(newValue) }
    }
    @objc(_isim_simdPosition) var _isimSimdPosition: [NSNumber] { get { _SCNObjC.f3(simdPosition) } set { simdPosition = _SCNObjC.f3(newValue) } }
    @objc(_isim_simdScale) var _isimSimdScale: [NSNumber] { get { _SCNObjC.f3(simdScale) } set { simdScale = _SCNObjC.f3(newValue) } }
    @objc(_isim_simdEulerAngles) var _isimSimdEulerAngles: [NSNumber] { get { _SCNObjC.f3(simdEulerAngles) } set { simdEulerAngles = _SCNObjC.f3(newValue) } }
    @objc(_isim_simdWorldPosition) var _isimSimdWorldPosition: [NSNumber] {
        get { _SCNObjC.f3(simdWorldPosition) }
        set { simdWorldPosition = _SCNObjC.f3(newValue) }
    }
    @objc(_isim_convertPosition:toNode:) func _isimConvert(_ p: [NSNumber], toNode node: SCNNode?) -> [NSNumber] {
        _SCNObjC.v3(convertPosition(_SCNObjC.v3(p), to: node))
    }
    @objc(_isim_convertPosition:fromNode:) func _isimConvert(_ p: [NSNumber], fromNode node: SCNNode?) -> [NSNumber] {
        _SCNObjC.v3(convertPosition(_SCNObjC.v3(p), from: node))
    }
}

extension SCNView {
    @objc(delegate) var _objcDelegate: _SCNObjCRendererDelegate? {
        get { (delegate as? _SCNRendererDelegateBox)?.t }
        set {
            let b = newValue.map(_SCNRendererDelegateBox.init)
            withUnsafePointer(to: &_SCNObjC.boxKey) { objc_setAssociatedObject(self, $0, b, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            delegate = b
        }
    }
    @objc(antialiasingMode) var _objcAntialiasingMode: UInt {
        get { antialiasingMode.rawValue }
        set { antialiasingMode = SCNAntialiasingMode(rawValue: newValue) ?? .multisampling4X }
    }
    @objc(isNodeInsideFrustum:withPointOfView:) func _objcIsNode(_ node: SCNNode, withPointOfView pov: SCNNode) -> Bool { isNode(node, insideFrustumOf: pov) }
    @objc(nodesInsideFrustumWithPointOfView:) func _objcNodesInside(_ pov: SCNNode) -> [SCNNode] { nodesInsideFrustum(of: pov) }
    @objc(_isim_projectPoint:) func _isimProject(_ p: [NSNumber]) -> [NSNumber] { _SCNObjC.v3(projectPoint(_SCNObjC.v3(p))) }
    @objc(_isim_unprojectPoint:) func _isimUnproject(_ p: [NSNumber]) -> [NSNumber] { _SCNObjC.v3(unprojectPoint(_SCNObjC.v3(p))) }
}

// MARK: - the renderer, geometry, materials, lights, actions and physics (issue #330)

extension _SCNObjC {
    static func box(_ b: (min: SCNVector3, max: SCNVector3)) -> [NSNumber] { v3(b.min) + v3(b.max) }
    static func options(_ o: [String: Any]?) -> [SCNHitTestOption: Any]? {
        o.map { Dictionary(uniqueKeysWithValues: $0.map { (SCNHitTestOption(rawValue: $0.key), $0.value) }) }
    }
}

extension SCNNode {
    @objc(_isim_lookAt:) func _isimLookAt(_ p: [NSNumber]) { look(at: _SCNObjC.v3(p)) }
    @objc(_isim_boundingBox) var _isimBoundingBox: [NSNumber] { _SCNObjC.box(boundingBox) }
    @objc(_isim_setBoundingBox:) func _isimSetBoundingBox(_ a: [NSNumber]) { boundingBox = (_SCNObjC.v3(Array(a[0..<3])), _SCNObjC.v3(Array(a[3..<6]))) }
    @objc(_isim_pivot) var _isimPivot: [NSNumber] { get { _SCNObjC.m4(simdPivot) } set { simdPivot = _SCNObjC.m4(newValue) } }
    @objc(_isim_hitTestFrom:to:options:) func _isimHitTest(_ a: [NSNumber], to b: [NSNumber], options: [String: Any]?) -> [SCNHitTestResult] {
        hitTestWithSegment(from: _SCNObjC.v3(a), to: _SCNObjC.v3(b), options: options)
    }
}

extension SCNView {
    @objc(hitTest:options:) func _objcHitTest(_ point: CGPoint, options: [String: Any]?) -> [SCNHitTestResult] {
        hitTest(point, options: _SCNObjC.options(options))
    }
    @objc(debugOptions) var _objcDebugOptions: UInt { get { debugOptions.rawValue } set { debugOptions = SCNDebugOptions(rawValue: newValue) } }
}

extension SCNRenderer {
    @objc(delegate) var _objcDelegate: _SCNObjCRendererDelegate? {
        get { (delegate as? _SCNRendererDelegateBox)?.t }
        set {
            let b = newValue.map(_SCNRendererDelegateBox.init)
            withUnsafePointer(to: &_SCNObjC.boxKey) { objc_setAssociatedObject(self, $0, b, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            delegate = b
        }
    }
    @objc(hitTest:options:) func _objcHitTest(_ point: CGPoint, options: [String: Any]?) -> [SCNHitTestResult] {
        hitTest(point, options: _SCNObjC.options(options))
    }
    @objc(snapshotAtTime:withSize:antialiasingMode:) func _objcSnapshot(_ time: CFTimeInterval, size: CGSize, mode: UInt) -> UIImage {
        snapshot(atTime: time, with: size, antialiasingMode: SCNAntialiasingMode(rawValue: mode) ?? .none)
    }
    @objc(_isim_projectPoint:) func _isimProject(_ p: [NSNumber]) -> [NSNumber] { _SCNObjC.v3(projectPoint(_SCNObjC.v3(p))) }
    @objc(_isim_unprojectPoint:) func _isimUnproject(_ p: [NSNumber]) -> [NSNumber] { _SCNObjC.v3(unprojectPoint(_SCNObjC.v3(p))) }
    @objc(isNodeInsideFrustum:withPointOfView:) func _objcIsNode(_ node: SCNNode, withPointOfView pov: SCNNode) -> Bool { isNode(node, insideFrustumOf: pov) }
    @objc(nodesInsideFrustumWithPointOfView:) func _objcNodesInside(_ pov: SCNNode) -> [SCNNode] { nodesInsideFrustum(of: pov) }
}

extension SCNGeometry {
    @objc(geometrySourcesForSemantic:) func _objcSources(_ semantic: String) -> [SCNGeometrySource] { sources(for: .init(semantic)) }
    @objc(_isim_boundingBox) var _isimBoundingBox: [NSNumber] { _SCNObjC.box(boundingBox) }
}

extension SCNGeometrySource {
    @objc(semantic) var _objcSemantic: String { semantic.rawValue }
    /// layout: vector count, float components (0 / 1), components per vector, bytes per component, offset, stride
    @objc(_isim_initWithData:semantic:layout:) convenience init(_isim data: Data, semantic: String, layout l: [NSNumber]) {
        self.init(data: data, semantic: .init(semantic), vectorCount: Int(l[0].intValue), usesFloatComponents: l[1].boolValue,
                  componentsPerVector: Int(l[2].intValue), bytesPerComponent: Int(l[3].intValue), dataOffset: Int(l[4].intValue), dataStride: Int(l[5].intValue))
    }
}

extension SCNMaterialProperty {
    @objc(_isim_contentsTransform) var _isimContentsTransform: [NSNumber] {
        get { _SCNObjC.m4(simd_float4x4(contentsTransform)) }
        set { contentsTransform = SCNMatrix4(_SCNObjC.m4(newValue)) }
    }
}

extension SCNMaterial {
    @objc(lightingModelName) var _objcLightingModel: String { get { lightingModel.rawValue } set { lightingModel = .init(newValue) } }
}

extension SCNLight {
    @objc(type) var _objcType: String { get { type.rawValue } set { type = .init(newValue) } }
}

extension SCNCamera {
    @objc(_isim_projectionTransform) var _isimProjection: [NSNumber] {
        get { _SCNObjC.m4(simd_float4x4(projectionTransform)) }
        set { projectionTransform = SCNMatrix4(_SCNObjC.m4(newValue)) }
    }
}

extension SCNAction {
    @objc(_isim_moveBy:duration:) class func _isimMoveBy(_ d: [NSNumber], duration: TimeInterval) -> SCNAction { move(by: _SCNObjC.v3(d), duration: duration) }
    @objc(_isim_moveTo:duration:) class func _isimMoveTo(_ p: [NSNumber], duration: TimeInterval) -> SCNAction { move(to: _SCNObjC.v3(p), duration: duration) }
    @objc(_isim_rotateByAngle:aroundAxis:duration:) class func _isimRotate(_ angle: CGFloat, aroundAxis axis: [NSNumber], duration: TimeInterval) -> SCNAction {
        rotate(by: angle, around: _SCNObjC.v3(axis), duration: duration)
    }
    @objc(_isim_rotateToAxisAngle:duration:) class func _isimRotateTo(_ a: [NSNumber], duration: TimeInterval) -> SCNAction {
        rotate(toAxisAngle: _SCNObjC.v4(a), duration: duration)
    }
}

extension SCNBillboardConstraint {
    @objc(freeAxes) var _objcFreeAxes: UInt { get { freeAxes.rawValue } set { freeAxes = SCNBillboardAxis(rawValue: newValue) } }
}

/// Apple's SCNPhysicsContactDelegate as Objective-C sees it
@objc(SCNPhysicsContactDelegate) protocol _SCNObjCContactDelegate: NSObjectProtocol {
    @objc(physicsWorld:didBeginContact:) optional func _begin(_ w: SCNPhysicsWorld, _ c: SCNPhysicsContact)
    @objc(physicsWorld:didUpdateContact:) optional func _update(_ w: SCNPhysicsWorld, _ c: SCNPhysicsContact)
    @objc(physicsWorld:didEndContact:) optional func _end(_ w: SCNPhysicsWorld, _ c: SCNPhysicsContact)
}
final class _SCNContactDelegateBox: NSObject, SCNPhysicsContactDelegate {
    weak var t: _SCNObjCContactDelegate?
    init(_ t: _SCNObjCContactDelegate) { self.t = t }
    func physicsWorld(_ w: SCNPhysicsWorld, didBegin c: SCNPhysicsContact) { t?._begin?(w, c) }
    func physicsWorld(_ w: SCNPhysicsWorld, didUpdate c: SCNPhysicsContact) { t?._update?(w, c) }
    func physicsWorld(_ w: SCNPhysicsWorld, didEnd c: SCNPhysicsContact) { t?._end?(w, c) }
}

extension SCNPhysicsWorld {
    @objc(contactDelegate) var _objcContactDelegate: _SCNObjCContactDelegate? {
        get { (contactDelegate as? _SCNContactDelegateBox)?.t }
        set {
            let b = newValue.map(_SCNContactDelegateBox.init)
            withUnsafePointer(to: &_SCNObjC.boxKey) { objc_setAssociatedObject(self, $0, b, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            contactDelegate = b
        }
    }
    @objc(_isim_gravity) var _isimGravity: [NSNumber] { get { _SCNObjC.v3(gravity) } set { gravity = _SCNObjC.v3(newValue) } }
}

extension SCNPhysicsShape {
    @objc(_isim_initWithGeometry:options:) convenience init(_isim geometry: SCNGeometry, options: [String: Any]?) {
        self.init(geometry: geometry, options: options.map { Dictionary(uniqueKeysWithValues: $0.map { (Option(rawValue: $0.key), $0.value) }) })
    }
    @objc(_isim_initWithNode:options:) convenience init(_isim node: SCNNode, options: [String: Any]?) {
        self.init(node: node, options: options.map { Dictionary(uniqueKeysWithValues: $0.map { (Option(rawValue: $0.key), $0.value) }) })
    }
}

extension SCNPhysicsBody {
    @objc(_isim_velocity) var _isimVelocity: [NSNumber] { get { _SCNObjC.v3(velocity) } set { velocity = _SCNObjC.v3(newValue) } }
    @objc(_isim_angularVelocity) var _isimAngularVelocity: [NSNumber] { get { _SCNObjC.v4(angularVelocity) } set { angularVelocity = _SCNObjC.v4(newValue) } }
    @objc(_isim_velocityFactor) var _isimVelocityFactor: [NSNumber] { get { _SCNObjC.v3(velocityFactor) } set { velocityFactor = _SCNObjC.v3(newValue) } }
    @objc(_isim_applyForce:impulse:) func _isimApply(_ f: [NSNumber], impulse: Bool) { applyForce(_SCNObjC.v3(f), asImpulse: impulse) }
    @objc(_isim_applyForce:atPosition:impulse:) func _isimApply(_ f: [NSNumber], atPosition p: [NSNumber], impulse: Bool) {
        applyForce(_SCNObjC.v3(f), at: _SCNObjC.v3(p), asImpulse: impulse)
    }
    @objc(_isim_applyTorque:impulse:) func _isimTorque(_ t: [NSNumber], impulse: Bool) { applyTorque(_SCNObjC.v4(t), asImpulse: impulse) }
}

extension SCNPhysicsContact {
    @objc(_isim_contactPoint) var _isimPoint: [NSNumber] { _SCNObjC.v3(contactPoint) }
    @objc(_isim_contactNormal) var _isimNormal: [NSNumber] { _SCNObjC.v3(contactNormal) }
}

extension SCNHitTestResult {
    @objc(_isim_localCoordinates) var _isimLocal: [NSNumber] { _SCNObjC.v3(localCoordinates) }
    @objc(_isim_worldCoordinates) var _isimWorld: [NSNumber] { _SCNObjC.v3(worldCoordinates) }
    @objc(_isim_localNormal) var _isimLocalNormal: [NSNumber] { _SCNObjC.v3(localNormal) }
    @objc(_isim_worldNormal) var _isimWorldNormal: [NSNumber] { _SCNObjC.v3(worldNormal) }
    @objc(_isim_modelTransform) var _isimModel: [NSNumber] { _SCNObjC.m4(simdModelTransform) }
}
