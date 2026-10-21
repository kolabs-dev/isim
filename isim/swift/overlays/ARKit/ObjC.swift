// isim ARKit: the Objective-C interface (sdk-src/Frameworks/ARKit, issue #560). The classes are @objc(AR…) and
// @objcMembers; the members below are internal Objective-C entry points, under Apple's selectors, for what uses
// Swift-only types: the enums and option sets (their raw values in Objective-C), the simd values (which ARKit.framework's
// categories, frameworks/ARKit/ARKit.m, pass through the `_isim_` NSArray entry points here) and the delegate
// protocols, Swift protocols here: an Objective-C delegate is held through a box that forwards to Apple's Objective-C
// protocol of the same name (declared below as Objective-C sees it), weakly like iOS.
import UIKit
import SpriteKit
import SceneKit
import CoreMedia
import CoreImage
import ObjectiveC
import simd

// MARK: - Apple's Objective-C protocols

@objc(ARSessionDelegate) protocol _ARObjCSessionDelegate: NSObjectProtocol {
    @objc(session:didFailWithError:) optional func _didFail(_ s: ARSession, _ e: Error)
    @objc(session:cameraDidChangeTrackingState:) optional func _trackingChanged(_ s: ARSession, _ c: ARCamera)
    @objc(sessionWasInterrupted:) optional func _interrupted(_ s: ARSession)
    @objc(sessionInterruptionEnded:) optional func _interruptionEnded(_ s: ARSession)
    @objc(sessionShouldAttemptRelocalization:) optional func _relocalize(_ s: ARSession) -> Bool
    @objc(session:didUpdateFrame:) optional func _frame(_ s: ARSession, _ f: ARFrame)
    @objc(session:didAddAnchors:) optional func _added(_ s: ARSession, _ a: [ARAnchor])
    @objc(session:didUpdateAnchors:) optional func _updated(_ s: ARSession, _ a: [ARAnchor])
    @objc(session:didRemoveAnchors:) optional func _removed(_ s: ARSession, _ a: [ARAnchor])
    // ARSCNViewDelegate's and ARSKViewDelegate's own methods (one Objective-C protocol here for the boxes' targets)
    @objc(renderer:nodeForAnchor:) optional func _scnNode(_ r: AnyObject, _ a: ARAnchor) -> SCNNode?
    @objc(renderer:didAddNode:forAnchor:) optional func _scnAdded(_ r: AnyObject, _ n: SCNNode, _ a: ARAnchor)
    @objc(renderer:willUpdateNode:forAnchor:) optional func _scnWillUpdate(_ r: AnyObject, _ n: SCNNode, _ a: ARAnchor)
    @objc(renderer:didUpdateNode:forAnchor:) optional func _scnUpdated(_ r: AnyObject, _ n: SCNNode, _ a: ARAnchor)
    @objc(renderer:didRemoveNode:forAnchor:) optional func _scnRemoved(_ r: AnyObject, _ n: SCNNode, _ a: ARAnchor)
    @objc(renderer:updateAtTime:) optional func _update(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:didApplyAnimationsAtTime:) optional func _animations(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:didSimulatePhysicsAtTime:) optional func _physics(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:didApplyConstraintsAtTime:) optional func _constraints(_ r: AnyObject, _ t: TimeInterval)
    @objc(renderer:willRenderScene:atTime:) optional func _willRender(_ r: AnyObject, _ s: SCNScene, _ t: TimeInterval)
    @objc(renderer:didRenderScene:atTime:) optional func _didRender(_ r: AnyObject, _ s: SCNScene, _ t: TimeInterval)
    @objc(view:nodeForAnchor:) optional func _skNode(_ v: ARSKView, _ a: ARAnchor) -> SKNode?
    @objc(view:didAddNode:forAnchor:) optional func _skAdded(_ v: ARSKView, _ n: SKNode, _ a: ARAnchor)
    @objc(view:willUpdateNode:forAnchor:) optional func _skWillUpdate(_ v: ARSKView, _ n: SKNode, _ a: ARAnchor)
    @objc(view:didUpdateNode:forAnchor:) optional func _skUpdated(_ v: ARSKView, _ n: SKNode, _ a: ARAnchor)
    @objc(view:didRemoveNode:forAnchor:) optional func _skRemoved(_ v: ARSKView, _ n: SKNode, _ a: ARAnchor)
}
@objc(ARCoachingOverlayViewDelegate) protocol _ARObjCCoachingDelegate: NSObjectProtocol {
    @objc(coachingOverlayViewWillActivate:) optional func _willActivate(_ v: ARCoachingOverlayView)
    @objc(coachingOverlayViewDidDeactivate:) optional func _didDeactivate(_ v: ARCoachingOverlayView)
    @objc(coachingOverlayViewDidRequestSessionReset:) optional func _reset(_ v: ARCoachingOverlayView)
}

// MARK: - boxes

/// a Swift delegate standing for an Objective-C one: the session's, ARSCNView's or ARSKView's
final class _ARDelegateBox: ARSessionDelegate, ARSCNViewDelegate, ARSKViewDelegate {
    weak var t: _ARObjCSessionDelegate?
    init(_ t: _ARObjCSessionDelegate) { self.t = t }
    func session(_ s: ARSession, didFailWithError e: Error) { t?._didFail?(s, e) }
    func session(_ s: ARSession, cameraDidChangeTrackingState c: ARCamera) { t?._trackingChanged?(s, c) }
    func sessionWasInterrupted(_ s: ARSession) { t?._interrupted?(s) }
    func sessionInterruptionEnded(_ s: ARSession) { t?._interruptionEnded?(s) }
    func sessionShouldAttemptRelocalization(_ s: ARSession) -> Bool { t?._relocalize?(s) ?? false }
    func session(_ s: ARSession, didUpdate f: ARFrame) { t?._frame?(s, f) }
    func session(_ s: ARSession, didAdd a: [ARAnchor]) { t?._added?(s, a) }
    func session(_ s: ARSession, didUpdate a: [ARAnchor]) { t?._updated?(s, a) }
    func session(_ s: ARSession, didRemove a: [ARAnchor]) { t?._removed?(s, a) }
    func renderer(_ r: any SCNSceneRenderer, nodeFor a: ARAnchor) -> SCNNode? { t?._scnNode.map { $0(r, a) } ?? SCNNode() }
    func renderer(_ r: any SCNSceneRenderer, didAdd n: SCNNode, for a: ARAnchor) { t?._scnAdded?(r, n, a) }
    func renderer(_ r: any SCNSceneRenderer, willUpdate n: SCNNode, for a: ARAnchor) { t?._scnWillUpdate?(r, n, a) }
    func renderer(_ r: any SCNSceneRenderer, didUpdate n: SCNNode, for a: ARAnchor) { t?._scnUpdated?(r, n, a) }
    func renderer(_ r: any SCNSceneRenderer, didRemove n: SCNNode, for a: ARAnchor) { t?._scnRemoved?(r, n, a) }
    func renderer(_ r: any SCNSceneRenderer, updateAtTime time: TimeInterval) { t?._update?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) { t?._animations?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) { t?._physics?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) { t?._constraints?(r, time) }
    func renderer(_ r: any SCNSceneRenderer, willRenderScene s: SCNScene, atTime time: TimeInterval) { t?._willRender?(r, s, time) }
    func renderer(_ r: any SCNSceneRenderer, didRenderScene s: SCNScene, atTime time: TimeInterval) { t?._didRender?(r, s, time) }
    func view(_ v: ARSKView, nodeFor a: ARAnchor) -> SKNode? { t?._skNode.map { $0(v, a) } ?? SKNode() }
    func view(_ v: ARSKView, didAdd n: SKNode, for a: ARAnchor) { t?._skAdded?(v, n, a) }
    func view(_ v: ARSKView, willUpdate n: SKNode, for a: ARAnchor) { t?._skWillUpdate?(v, n, a) }
    func view(_ v: ARSKView, didUpdate n: SKNode, for a: ARAnchor) { t?._skUpdated?(v, n, a) }
    func view(_ v: ARSKView, didRemove n: SKNode, for a: ARAnchor) { t?._skRemoved?(v, n, a) }
}
final class _ARCoachingDelegateBox: ARCoachingOverlayViewDelegate {
    weak var t: _ARObjCCoachingDelegate?
    init(_ t: _ARObjCCoachingDelegate) { self.t = t }
    func coachingOverlayViewWillActivate(_ v: ARCoachingOverlayView) { t?._willActivate?(v) }
    func coachingOverlayViewDidDeactivate(_ v: ARCoachingOverlayView) { t?._didDeactivate?(v) }
    func coachingOverlayViewDidRequestSessionReset(_ v: ARCoachingOverlayView) { t?._reset?(v) }
}

enum _ARObjC {
    nonisolated(unsafe) static var boxKey = 0
    static func keep(_ box: AnyObject?, on owner: NSObject) {
        withUnsafePointer(to: &boxKey) { objc_setAssociatedObject(owner, $0, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    static func f3(_ v: simd_float3) -> [NSNumber] { [NSNumber(value: v.x), NSNumber(value: v.y), NSNumber(value: v.z)] }
    static func f3(_ a: [NSNumber]) -> simd_float3 { simd_float3(a[0].floatValue, a[1].floatValue, a[2].floatValue) }
    /// column by column
    static func m4(_ m: simd_float4x4) -> [NSNumber] { (0..<4).flatMap { c in (0..<4).map { r in NSNumber(value: m[c, r]) } } }
    static func m4(_ a: [NSNumber]) -> simd_float4x4 {
        var m = simd_float4x4()
        for c in 0..<4 { for r in 0..<4 { m[c, r] = a[c * 4 + r].floatValue } }
        return m
    }
    static func m3(_ m: simd_float3x3) -> [NSNumber] { (0..<3).flatMap { c in (0..<3).map { r in NSNumber(value: m[c, r]) } } }
}

// MARK: - configurations

extension ARConfiguration {
    @objc(worldAlignment) var _objcWorldAlignment: Int {
        get { worldAlignment.rawValue }
        set { worldAlignment = WorldAlignment(rawValue: newValue) ?? .gravity }
    }
    @objc(frameSemantics) var _objcFrameSemantics: UInt {
        get { frameSemantics.rawValue }
        set { frameSemantics = FrameSemantics(rawValue: newValue) }
    }
    @objc(supportsFrameSemantics:) class func _objcSupportsFrameSemantics(_ s: UInt) -> Bool { supportsFrameSemantics(FrameSemantics(rawValue: s)) }
}
extension ARWorldTrackingConfiguration {
    @objc(planeDetection) var _objcPlaneDetection: UInt {
        get { planeDetection.rawValue }
        set { planeDetection = PlaneDetection(rawValue: newValue) }
    }
    @objc(environmentTexturing) var _objcEnvironmentTexturing: Int {
        get { environmentTexturing.rawValue }
        set { environmentTexturing = EnvironmentTexturing(rawValue: newValue) ?? .none }
    }
    @objc(sceneReconstruction) var _objcSceneReconstruction: UInt {
        get { sceneReconstruction.rawValue }
        set { sceneReconstruction = ARConfiguration.SceneReconstruction(rawValue: newValue) }
    }
    @objc(supportsSceneReconstruction:) class func _objcSupportsSceneReconstruction(_ s: UInt) -> Bool {
        supportsSceneReconstruction(ARConfiguration.SceneReconstruction(rawValue: s))
    }
}

// MARK: - the session

extension ARSession {
    @objc(delegate) var _objcDelegate: _ARObjCSessionDelegate? {
        get { (delegate as? _ARDelegateBox)?.t }
        set { let b = newValue.map(_ARDelegateBox.init); _ARObjC.keep(b, on: self); delegate = b }
    }
    @objc(runWithConfiguration:) func _objcRun(_ c: ARConfiguration) { run(c) }
    @objc(runWithConfiguration:options:) func _objcRun(_ c: ARConfiguration, options: UInt) { run(c, options: RunOptions(rawValue: options)) }
    @objc(addAnchor:) func _objcAdd(_ a: ARAnchor) { add(anchor: a) }
    @objc(removeAnchor:) func _objcRemove(_ a: ARAnchor) { remove(anchor: a) }
    @objc(_isim_setWorldOrigin:) func _isimSetWorldOrigin(_ m: [NSNumber]) { setWorldOrigin(relativeTransform: _ARObjC.m4(m)) }
    @objc(_isim_createReferenceObjectWithTransform:center:extent:completionHandler:)
    func _isimCreateReferenceObject(_ m: [NSNumber], center: [NSNumber], extent: [NSNumber], completionHandler: @escaping (ARReferenceObject?, Error?) -> Void) {
        createReferenceObject(transform: _ARObjC.m4(m), center: _ARObjC.f3(center), extent: _ARObjC.f3(extent), completionHandler: completionHandler)
    }
}

// MARK: - frames, cameras, anchors

extension ARFrame {
    @objc(worldMappingStatus) var _objcWorldMappingStatus: Int { worldMappingStatus.rawValue }
    @objc(capturedImage) var _objcCapturedImage: AnyObject { capturedImage }
    @objc(displayTransformForOrientation:viewportSize:) func _objcDisplayTransform(_ o: UIInterfaceOrientation, viewportSize: CGSize) -> CGAffineTransform {
        displayTransform(for: o, viewportSize: viewportSize)
    }
    @objc(raycastQueryFromPoint:allowingTarget:alignment:) func _objcRaycastQuery(_ p: CGPoint, allowingTarget t: Int, alignment a: Int) -> ARRaycastQuery {
        raycastQuery(from: p, allowing: ARRaycastQuery.Target(rawValue: t) ?? .estimatedPlane, alignment: ARRaycastQuery.TargetAlignment(rawValue: a) ?? .any)
    }
}
extension ARCamera {
    /// ARTrackingState's raw value
    @objc(trackingState) var _objcTrackingState: Int {
        switch trackingState { case .notAvailable: return 0; case .limited: return 1; case .normal: return 2 }
    }
    /// ARTrackingStateReason's raw value
    @objc(trackingStateReason) var _objcTrackingStateReason: Int {
        guard case .limited(let r) = trackingState else { return 0 }
        switch r { case .initializing: return 1; case .excessiveMotion: return 2; case .insufficientFeatures: return 3; case .relocalizing: return 4 }
    }
    @objc(_isim_transform) var _isimTransform: [NSNumber] { _ARObjC.m4(transform) }
    @objc(_isim_eulerAngles) var _isimEulerAngles: [NSNumber] { _ARObjC.f3(eulerAngles) }
    @objc(_isim_intrinsics) var _isimIntrinsics: [NSNumber] { _ARObjC.m3(intrinsics) }
    @objc(_isim_projectionMatrix) var _isimProjectionMatrix: [NSNumber] { _ARObjC.m4(projectionMatrix) }
    @objc(_isim_projectionMatrixForOrientation:viewportSize:zNear:zFar:)
    func _isimProjectionMatrix(_ o: UIInterfaceOrientation, viewportSize: CGSize, zNear: CGFloat, zFar: CGFloat) -> [NSNumber] {
        _ARObjC.m4(projectionMatrix(for: o, viewportSize: viewportSize, zNear: zNear, zFar: zFar))
    }
    @objc(_isim_viewMatrixForOrientation:) func _isimViewMatrix(_ o: UIInterfaceOrientation) -> [NSNumber] { _ARObjC.m4(viewMatrix(for: o)) }
    @objc(_isim_projectPoint:orientation:viewportSize:) func _isimProject(_ p: [NSNumber], orientation o: UIInterfaceOrientation, viewportSize: CGSize) -> CGPoint {
        projectPoint(_ARObjC.f3(p), orientation: o, viewportSize: viewportSize)
    }
}
extension ARAnchor {
    /// -initWithTransform: / -initWithName:transform: (factories: Objective-C's initializers return what they make; an @objc
    /// convenience init crashes when Objective-C calls it on these classes, #620)
    @objc(_isim_anchorWithName:transform:) class func _isimAnchor(name: String?, transform m: [NSNumber]) -> ARAnchor {
        name.map { ARAnchor(name: $0, transform: _ARObjC.m4(m)) } ?? ARAnchor(transform: _ARObjC.m4(m))
    }
    @objc(_isim_transform) var _isimTransform: [NSNumber] { _ARObjC.m4(transform) }
}
extension ARPlaneAnchor {
    @objc(alignment) var _objcAlignment: Int { alignment.rawValue }
    @objc(_isim_center) var _isimCenter: [NSNumber] { _ARObjC.f3(center) }
    /// ARPlaneClassification's raw value (none: 0, wall … door: 1 … 7)
    @objc(classification) var _objcClassification: Int {
        if case .none = classification { return 0 }
        return 0
    }
}
extension ARFaceAnchor {
    @objc(blendShapes) var _objcBlendShapes: [String: NSNumber] { Dictionary(uniqueKeysWithValues: blendShapes.map { ($0.key.rawValue, $0.value) }) }
    @objc(_isim_leftEyeTransform) var _isimLeftEyeTransform: [NSNumber] { _ARObjC.m4(leftEyeTransform) }
    @objc(_isim_rightEyeTransform) var _isimRightEyeTransform: [NSNumber] { _ARObjC.m4(rightEyeTransform) }
    @objc(_isim_lookAtPoint) var _isimLookAtPoint: [NSNumber] { _ARObjC.f3(lookAtPoint) }
}
extension AREnvironmentProbeAnchor {
    @objc(_isim_probeWithName:transform:extent:) class func _isimProbe(name: String?, transform m: [NSNumber], extent: [NSNumber]) -> AREnvironmentProbeAnchor {
        name.map { AREnvironmentProbeAnchor(name: $0, transform: _ARObjC.m4(m), extent: _ARObjC.f3(extent)) }
            ?? AREnvironmentProbeAnchor(transform: _ARObjC.m4(m), extent: _ARObjC.f3(extent))
    }
    @objc(_isim_extent) var _isimExtent: [NSNumber] { _ARObjC.f3(extent) }
}

// MARK: - raycasts, reference images and objects, world maps

extension ARRaycastQuery {
    @objc(_isim_queryWithOrigin:direction:allowingTarget:alignment:)
    class func _isimQuery(origin o: [NSNumber], direction d: [NSNumber], allowingTarget t: Int, alignment a: Int) -> ARRaycastQuery {
        ARRaycastQuery(origin: _ARObjC.f3(o), direction: _ARObjC.f3(d), allowing: Target(rawValue: t) ?? .estimatedPlane, alignment: TargetAlignment(rawValue: a) ?? .any)
    }
    @objc(_isim_origin) var _isimOrigin: [NSNumber] { _ARObjC.f3(origin) }
    @objc(_isim_direction) var _isimDirection: [NSNumber] { _ARObjC.f3(direction) }
    @objc(target) var _objcTarget: Int { target.rawValue }
    @objc(targetAlignment) var _objcTargetAlignment: Int { targetAlignment.rawValue }
}
extension ARRaycastResult {
    @objc(_isim_worldTransform) var _isimWorldTransform: [NSNumber] { _ARObjC.m4(worldTransform) }
    @objc(target) var _objcTarget: Int { target.rawValue }
    @objc(targetAlignment) var _objcTargetAlignment: Int { targetAlignment.rawValue }
}
extension ARReferenceImage {
    @objc(initWithCGImage:orientation:physicalWidth:) convenience init(_objcCGImage image: CGImage, orientation: CGImagePropertyOrientation, physicalWidth: CGFloat) {
        self.init(image, orientation: orientation, physicalWidth: physicalWidth)
    }
}
extension ARReferenceObject {
    @objc(exportObjectToURL:previewImage:error:) func _objcExport(_ url: URL, previewImage: UIImage?) throws { try export(to: url, previewImage: previewImage) }
    @objc(referenceObjectByMergingObject:error:) func _objcMerging(_ o: ARReferenceObject) throws -> ARReferenceObject { try merging(o) }
    @objc(_isim_referenceObjectByApplyingTransform:) func _isimApplying(_ m: [NSNumber]) -> ARReferenceObject { applyingTransform(_ARObjC.m4(m)) }
    @objc(_isim_center) var _isimCenter: [NSNumber] { _ARObjC.f3(center) }
    @objc(_isim_extent) var _isimExtent: [NSNumber] { _ARObjC.f3(extent) }
    @objc(_isim_scale) var _isimScale: [NSNumber] { _ARObjC.f3(scale) }
}
extension ARWorldMap {
    @objc(_isim_center) var _isimCenter: [NSNumber] { _ARObjC.f3(center) }
    @objc(_isim_extent) var _isimExtent: [NSNumber] { _ARObjC.f3(extent) }
}

// MARK: - views

extension ARSCNView {
    @objc(anchorForNode:) func _objcAnchor(for node: SCNNode) -> ARAnchor? { anchor(for: node) }
    @objc(nodeForAnchor:) func _objcNode(for anchor: ARAnchor) -> SCNNode? { node(for: anchor) }
    @objc(raycastQueryFromPoint:allowingTarget:alignment:) func _objcRaycastQuery(_ p: CGPoint, allowingTarget t: Int, alignment a: Int) -> ARRaycastQuery? {
        raycastQuery(from: p, allowing: ARRaycastQuery.Target(rawValue: t) ?? .estimatedPlane, alignment: ARRaycastQuery.TargetAlignment(rawValue: a) ?? .any)
    }
    /// ARSCNViewDelegate: the box also takes the session's and SceneKit's callbacks
    @objc(_isim_setARDelegate:) func _isimSetARDelegate(_ d: _ARObjCSessionDelegate?) {
        let b = d.map(_ARDelegateBox.init); _ARObjC.keep(b, on: self); delegate = b
    }
    @objc(_isim_ARDelegate) var _isimARDelegate: _ARObjCSessionDelegate? { (delegate as? _ARDelegateBox)?.t }
}
extension ARSKView {
    @objc(anchorForNode:) func _objcAnchor(for node: SKNode) -> ARAnchor? { anchor(for: node) }
    @objc(nodeForAnchor:) func _objcNode(for anchor: ARAnchor) -> SKNode? { node(for: anchor) }
    @objc(_isim_setARDelegate:) func _isimSetARDelegate(_ d: _ARObjCSessionDelegate?) {
        let b = d.map(_ARDelegateBox.init); _ARObjC.keep(b, on: self); delegate = b
    }
    @objc(_isim_ARDelegate) var _isimARDelegate: _ARObjCSessionDelegate? { (delegate as? _ARDelegateBox)?.t }
}
extension ARCoachingOverlayView {
    @objc(delegate) var _objcDelegate: _ARObjCCoachingDelegate? {
        get { (delegate as? _ARCoachingDelegateBox)?.t }
        set { let b = newValue.map(_ARCoachingDelegateBox.init); _ARObjC.keep(b, on: self); delegate = b }
    }
    @objc(goal) var _objcGoal: Int {
        get { goal.rawValue }
        set { goal = Goal(rawValue: newValue) ?? .tracking }
    }
}
