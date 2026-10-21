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
