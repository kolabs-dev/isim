// isim SceneKit: the scene graph (SCNNode, SCNScene) and SceneKit's vector and matrix types. Self-authored, iOS API
// names. The renderer (Renderer.swift) draws scenes with isim's Metal, on the CPU (issue #330); SCNView (View.swift)
// shows them. Geometry, materials, lights and cameras: Geometry.swift, Material.swift, LightCamera.swift; actions,
// animations and constraints: Actions.swift; physics: Physics.swift; scene files: SceneLoading.swift.
import UIKit
import simd

// MARK: - vectors and matrices (SCNFloat is Float on iOS)

public struct SCNVector3: Sendable, Equatable {
    public var x: Float, y: Float, z: Float
    public init() { x = 0; y = 0; z = 0 }
    public init(x: Float, y: Float, z: Float) { self.x = x; self.y = y; self.z = z }
    public init(_ x: Float, _ y: Float, _ z: Float) { self.x = x; self.y = y; self.z = z }
    public init(_ x: Double, _ y: Double, _ z: Double) { self.init(Float(x), Float(y), Float(z)) }
    public init(_ x: Int, _ y: Int, _ z: Int) { self.init(Float(x), Float(y), Float(z)) }
    public init(_ v: SIMD3<Float>) { self.init(v.x, v.y, v.z) }
    public init(_ v: SIMD3<Double>) { self.init(Float(v.x), Float(v.y), Float(v.z)) }
}
public struct SCNVector4: Sendable, Equatable {
    public var x: Float, y: Float, z: Float, w: Float
    public init() { x = 0; y = 0; z = 0; w = 0 }
    public init(x: Float, y: Float, z: Float, w: Float) { self.x = x; self.y = y; self.z = z; self.w = w }
    public init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) { self.x = x; self.y = y; self.z = z; self.w = w }
    public init(_ x: Double, _ y: Double, _ z: Double, _ w: Double) { self.init(Float(x), Float(y), Float(z), Float(w)) }
    public init(_ v: SIMD4<Float>) { self.init(v.x, v.y, v.z, v.w) }
}
public typealias SCNQuaternion = SCNVector4

/// A 4x4 matrix, row-vector convention (m41, m42, m43 hold the translation), as in Core Animation.
public struct SCNMatrix4: Sendable, Equatable {
    public var m11: Float, m12: Float, m13: Float, m14: Float
    public var m21: Float, m22: Float, m23: Float, m24: Float
    public var m31: Float, m32: Float, m33: Float, m34: Float
    public var m41: Float, m42: Float, m43: Float, m44: Float
    public init() {
        m11 = 0; m12 = 0; m13 = 0; m14 = 0; m21 = 0; m22 = 0; m23 = 0; m24 = 0
        m31 = 0; m32 = 0; m33 = 0; m34 = 0; m41 = 0; m42 = 0; m43 = 0; m44 = 0
    }
    public init(m11: Float, m12: Float, m13: Float, m14: Float, m21: Float, m22: Float, m23: Float, m24: Float,
                m31: Float, m32: Float, m33: Float, m34: Float, m41: Float, m42: Float, m43: Float, m44: Float) {
        self.m11 = m11; self.m12 = m12; self.m13 = m13; self.m14 = m14; self.m21 = m21; self.m22 = m22; self.m23 = m23; self.m24 = m24
        self.m31 = m31; self.m32 = m32; self.m33 = m33; self.m34 = m34; self.m41 = m41; self.m42 = m42; self.m43 = m43; self.m44 = m44
    }
    /// the simd matrix's columns are SceneKit's rows
    public init(_ m: simd_float4x4) {
        let c = m.columns
        self.init(m11: c.0.x, m12: c.0.y, m13: c.0.z, m14: c.0.w, m21: c.1.x, m22: c.1.y, m23: c.1.z, m24: c.1.w,
                  m31: c.2.x, m32: c.2.y, m33: c.2.z, m34: c.2.w, m41: c.3.x, m42: c.3.y, m43: c.3.z, m44: c.3.w)
    }
}
extension simd_float4x4 {
    public init(_ m: SCNMatrix4) {
        self.init(SIMD4(m.m11, m.m12, m.m13, m.m14), SIMD4(m.m21, m.m22, m.m23, m.m24),
                  SIMD4(m.m31, m.m32, m.m33, m.m34), SIMD4(m.m41, m.m42, m.m43, m.m44))
    }
}
extension SIMD3 where Scalar == Float { public init(_ v: SCNVector3) { self.init(v.x, v.y, v.z) } }
extension SIMD4 where Scalar == Float { public init(_ v: SCNVector4) { self.init(v.x, v.y, v.z, v.w) } }

public let SCNVector3Zero = SCNVector3()
public let SCNVector4Zero = SCNVector4()
public let SCNMatrix4Identity = SCNMatrix4(matrix_identity_float4x4)
public func SCNVector3Make(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 { SCNVector3(x, y, z) }
public func SCNVector4Make(_ x: Float, _ y: Float, _ z: Float, _ w: Float) -> SCNVector4 { SCNVector4(x, y, z, w) }
public func SCNVector3EqualToVector3(_ a: SCNVector3, _ b: SCNVector3) -> Bool { a == b }
public func SCNVector4EqualToVector4(_ a: SCNVector4, _ b: SCNVector4) -> Bool { a == b }
public func SCNMatrix4EqualToMatrix4(_ a: SCNMatrix4, _ b: SCNMatrix4) -> Bool { a == b }
public func SCNMatrix4IsIdentity(_ m: SCNMatrix4) -> Bool { m == SCNMatrix4Identity }
public func SCNMatrix4ToMat4(_ m: SCNMatrix4) -> simd_float4x4 { simd_float4x4(m) }
public func SCNMatrix4FromMat4(_ m: simd_float4x4) -> SCNMatrix4 { SCNMatrix4(m) }
public func SCNVector3ToFloat3(_ v: SCNVector3) -> SIMD3<Float> { SIMD3(v) }
public func SCNVector3FromFloat3(_ v: SIMD3<Float>) -> SCNVector3 { SCNVector3(v) }
public func SCNVector4ToFloat4(_ v: SCNVector4) -> SIMD4<Float> { SIMD4(v) }
public func SCNVector4FromFloat4(_ v: SIMD4<Float>) -> SCNVector4 { SCNVector4(v) }
/// a * b: a's transform, then b's
public func SCNMatrix4Mult(_ a: SCNMatrix4, _ b: SCNMatrix4) -> SCNMatrix4 { SCNMatrix4(simd_float4x4(b) * simd_float4x4(a)) }
public func SCNMatrix4MakeTranslation(_ tx: Float, _ ty: Float, _ tz: Float) -> SCNMatrix4 {
    var m = SCNMatrix4Identity; m.m41 = tx; m.m42 = ty; m.m43 = tz; return m
}
public func SCNMatrix4MakeScale(_ sx: Float, _ sy: Float, _ sz: Float) -> SCNMatrix4 {
    var m = SCNMatrix4Identity; m.m11 = sx; m.m22 = sy; m.m33 = sz; return m
}
/// a rotation by `angle` radians around (x, y, z)
public func SCNMatrix4MakeRotation(_ angle: Float, _ x: Float, _ y: Float, _ z: Float) -> SCNMatrix4 {
    SCNMatrix4(_SCN.matrix(simd_quatf(angle: angle, axis: SIMD3(x, y, z))))
}
public func SCNMatrix4Translate(_ m: SCNMatrix4, _ tx: Float, _ ty: Float, _ tz: Float) -> SCNMatrix4 { SCNMatrix4Mult(m, SCNMatrix4MakeTranslation(tx, ty, tz)) }
public func SCNMatrix4Scale(_ m: SCNMatrix4, _ sx: Float, _ sy: Float, _ sz: Float) -> SCNMatrix4 { SCNMatrix4Mult(SCNMatrix4MakeScale(sx, sy, sz), m) }
public func SCNMatrix4Rotate(_ m: SCNMatrix4, _ angle: Float, _ x: Float, _ y: Float, _ z: Float) -> SCNMatrix4 { SCNMatrix4Mult(SCNMatrix4MakeRotation(angle, x, y, z), m) }
public func SCNMatrix4Invert(_ m: SCNMatrix4) -> SCNMatrix4 { SCNMatrix4(_SCN.inverse(simd_float4x4(m))) }

enum _SCN {
    static func matrix(_ q: simd_quatf) -> simd_float4x4 {
        let r = simd_float3x3(q)
        return simd_float4x4(SIMD4(r.columns.0, 0), SIMD4(r.columns.1, 0), SIMD4(r.columns.2, 0), SIMD4(0, 0, 0, 1))
    }
    /// translation · rotation · scale
    static func compose(_ t: SIMD3<Float>, _ q: simd_quatf, _ s: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix(q)
        m.columns.0 *= s.x; m.columns.1 *= s.y; m.columns.2 *= s.z
        m.columns.3 = SIMD4(t, 1)
        return m
    }
    static func decompose(_ m: simd_float4x4) -> (SIMD3<Float>, simd_quatf, SIMD3<Float>) {
        let c0 = SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z), c1 = SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z)
        let c2 = SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        let s = SIMD3(simd_length(c0), simd_length(c1), simd_length(c2))
        let r = simd_float3x3(columns: (s.x > 0 ? c0 / s.x : c0, s.y > 0 ? c1 / s.y : c1, s.z > 0 ? c2 / s.z : c2))
        return (SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z), simd_quatf(r), s)
    }
    /// a general 4x4 inverse (cofactors)
    static func inverse(_ m: simd_float4x4) -> simd_float4x4 {
        var a = [Float](repeating: 0, count: 16)
        for c in 0..<4 { for r in 0..<4 { a[c * 4 + r] = m[c, r] } }
        var inv = [Float](repeating: 0, count: 16)
        inv[0] = a[5]*a[10]*a[15] - a[5]*a[11]*a[14] - a[9]*a[6]*a[15] + a[9]*a[7]*a[14] + a[13]*a[6]*a[11] - a[13]*a[7]*a[10]
        inv[4] = -a[4]*a[10]*a[15] + a[4]*a[11]*a[14] + a[8]*a[6]*a[15] - a[8]*a[7]*a[14] - a[12]*a[6]*a[11] + a[12]*a[7]*a[10]
        inv[8] = a[4]*a[9]*a[15] - a[4]*a[11]*a[13] - a[8]*a[5]*a[15] + a[8]*a[7]*a[13] + a[12]*a[5]*a[11] - a[12]*a[7]*a[9]
        inv[12] = -a[4]*a[9]*a[14] + a[4]*a[10]*a[13] + a[8]*a[5]*a[14] - a[8]*a[6]*a[13] - a[12]*a[5]*a[10] + a[12]*a[6]*a[9]
        inv[1] = -a[1]*a[10]*a[15] + a[1]*a[11]*a[14] + a[9]*a[2]*a[15] - a[9]*a[3]*a[14] - a[13]*a[2]*a[11] + a[13]*a[3]*a[10]
        inv[5] = a[0]*a[10]*a[15] - a[0]*a[11]*a[14] - a[8]*a[2]*a[15] + a[8]*a[3]*a[14] + a[12]*a[2]*a[11] - a[12]*a[3]*a[10]
        inv[9] = -a[0]*a[9]*a[15] + a[0]*a[11]*a[13] + a[8]*a[1]*a[15] - a[8]*a[3]*a[13] - a[12]*a[1]*a[11] + a[12]*a[3]*a[9]
        inv[13] = a[0]*a[9]*a[14] - a[0]*a[10]*a[13] - a[8]*a[1]*a[14] + a[8]*a[2]*a[13] + a[12]*a[1]*a[10] - a[12]*a[2]*a[9]
        inv[2] = a[1]*a[6]*a[15] - a[1]*a[7]*a[14] - a[5]*a[2]*a[15] + a[5]*a[3]*a[14] + a[13]*a[2]*a[7] - a[13]*a[3]*a[6]
        inv[6] = -a[0]*a[6]*a[15] + a[0]*a[7]*a[14] + a[4]*a[2]*a[15] - a[4]*a[3]*a[14] - a[12]*a[2]*a[7] + a[12]*a[3]*a[6]
        inv[10] = a[0]*a[5]*a[15] - a[0]*a[7]*a[13] - a[4]*a[1]*a[15] + a[4]*a[3]*a[13] + a[12]*a[1]*a[7] - a[12]*a[3]*a[5]
        inv[14] = -a[0]*a[5]*a[14] + a[0]*a[6]*a[13] + a[4]*a[1]*a[14] - a[4]*a[2]*a[13] - a[12]*a[1]*a[6] + a[12]*a[2]*a[5]
        inv[3] = -a[1]*a[6]*a[11] + a[1]*a[7]*a[10] + a[5]*a[2]*a[11] - a[5]*a[3]*a[10] - a[9]*a[2]*a[7] + a[9]*a[3]*a[6]
        inv[7] = a[0]*a[6]*a[11] - a[0]*a[7]*a[10] - a[4]*a[2]*a[11] + a[4]*a[3]*a[10] + a[8]*a[2]*a[7] - a[8]*a[3]*a[6]
        inv[11] = -a[0]*a[5]*a[11] + a[0]*a[7]*a[9] + a[4]*a[1]*a[11] - a[4]*a[3]*a[9] - a[8]*a[1]*a[7] + a[8]*a[3]*a[5]
        inv[15] = a[0]*a[5]*a[10] - a[0]*a[6]*a[9] - a[4]*a[1]*a[10] + a[4]*a[2]*a[9] + a[8]*a[1]*a[6] - a[8]*a[2]*a[5]
        let det = a[0] * inv[0] + a[1] * inv[4] + a[2] * inv[8] + a[3] * inv[12]
        guard det != 0 else { return m }
        var out = simd_float4x4()
        for c in 0..<4 { for r in 0..<4 { out[c, r] = inv[c * 4 + r] / det } }
        return out
    }
    /// SceneKit's Euler angles: roll (z) first, then yaw (y), then pitch (x)
    static func quat(euler e: SIMD3<Float>) -> simd_quatf {
        simd_quatf(angle: e.x, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: e.y, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: e.z, axis: SIMD3(0, 0, 1))
    }
    static func euler(_ q: simd_quatf) -> SIMD3<Float> {
        let m = simd_float3x3(q)                           // R = Rx · Ry · Rz
        let sy = max(-1, min(1, m[2, 0]))
        let y = asinf(sy)
        if abs(sy) < 0.99999 { return SIMD3(atan2f(-m[2, 1], m[2, 2]), y, atan2f(-m[1, 0], m[0, 0])) }
        return SIMD3(atan2f(m[1, 2], m[1, 1]), y, 0)
    }
}

// MARK: - nodes and scenes

public enum SCNMovabilityHint: Int, Sendable { case fixed = 0, movable = 1 }
public enum SCNNodeFocusBehavior: Int, Sendable { case none = 0, occluding = 1, focusable = 2 }

/// A node of the scene graph: a transform (position, orientation, scale), children, and what it shows (geometry,
/// light, camera).
@objc(SCNNode) open class SCNNode: NSObject, NSCopying, NSSecureCoding, SCNBoundingVolume, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc public convenience init(geometry: SCNGeometry?) { self.init(); self.geometry = geometry }
    @objc open var name: String?
    @objc open internal(set) weak var parent: SCNNode?
    @objc open private(set) var childNodes: [SCNNode] = [] { didSet { _SCNDirty.bump() } }
    @objc open var isHidden = false { didSet { _SCNDirty.bump() } }
    @objc open var opacity: CGFloat = 1 { didSet { _SCNDirty.bump() } }
    @objc open var renderingOrder = 0 { didSet { _SCNDirty.bump() } }
    @objc open var castsShadow = true
    @objc open var categoryBitMask = 1 { didSet { _SCNDirty.bump() } }
    @objc open var geometry: SCNGeometry? { didSet { _SCNDirty.bump() } }
    @objc open var light: SCNLight? { didSet { _SCNDirty.bump() } }
    @objc open var camera: SCNCamera? { didSet { _SCNDirty.bump() } }
    @objc open var physicsBody: SCNPhysicsBody? {
        didSet { oldValue?._node = nil; physicsBody?._node = self; physicsBody?._reset() }
    }
    @objc open var constraints: [SCNConstraint]? { didSet { _SCNDirty.bump() } }
    @objc open var isPaused = false
    open var movabilityHint: SCNMovabilityHint = .fixed
    open var focusBehavior: SCNNodeFocusBehavior = .none
    var _t = SIMD3<Float>(repeating: 0) { didSet { _SCNDirty.bump() } }
    var _q = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) { didSet { _SCNDirty.bump() } }
    var _s = SIMD3<Float>(repeating: 1) { didSet { _SCNDirty.bump() } }
    var _pivot: simd_float4x4? { didSet { _SCNDirty.bump() } }
    /// the world transform the renderer last drew, with constraints applied (the presentation)
    var _presented: simd_float4x4?
    // actions and animations (Actions.swift)
    var _actions: [_SCNRunningAction] = []
    var _animations: [(key: String, player: SCNAnimationPlayer)] = []

    // transform
    open var simdPosition: SIMD3<Float> { get { _t } set { _t = newValue } }
    open var simdOrientation: simd_quatf { get { _q } set { _q = newValue } }
    open var simdScale: SIMD3<Float> { get { _s } set { _s = newValue } }
    open var simdEulerAngles: SIMD3<Float> { get { _SCN.euler(_q) } set { _q = _SCN.quat(euler: newValue) } }
    open var simdRotation: SIMD4<Float> {
        get { let a = _q.angle == 0 ? SIMD3<Float>(0, 1, 0) : _q.axis; return SIMD4(a, _q.angle) }
        set { _q = simd_quatf(angle: newValue.w, axis: simd_length(SIMD3(newValue.x, newValue.y, newValue.z)) > 0 ? SIMD3(newValue.x, newValue.y, newValue.z) : SIMD3(0, 1, 0)) }
    }
    open var simdTransform: simd_float4x4 {
        get { _SCN.compose(_t, _q, _s) }
        set { (_t, _q, _s) = _SCN.decompose(newValue) }
    }
    open var simdPivot: simd_float4x4 { get { _pivot ?? matrix_identity_float4x4 } set { _pivot = newValue == matrix_identity_float4x4 ? nil : newValue } }
    open var pivot: SCNMatrix4 { get { SCNMatrix4(simdPivot) } set { simdPivot = simd_float4x4(newValue) } }
    /// the transform with the pivot: what the node's content and children are placed by
    var _local: simd_float4x4 { _pivot.map { simdTransform * _SCN.inverse($0) } ?? simdTransform }
    open var simdWorldTransform: simd_float4x4 {
        get { (parent?.simdWorldTransform ?? matrix_identity_float4x4) * _local }
        set {
            let local = parent.map { _SCN.inverse($0.simdWorldTransform) * newValue } ?? newValue
            simdTransform = _pivot.map { local * $0 } ?? local
        }
    }
    open var simdWorldPosition: SIMD3<Float> {
        get { let c = simdWorldTransform.columns.3; return SIMD3(c.x, c.y, c.z) }
        set {
            let p = parent.map { _SCN.inverse($0.simdWorldTransform) * SIMD4(newValue, 1) } ?? SIMD4(newValue, 1)
            _t = SIMD3(p.x, p.y, p.z)
        }
    }
    open var simdWorldOrientation: simd_quatf {
        get { _SCN.decompose(simdWorldTransform).1 }
        set { _q = (parent.map { _SCN.decompose($0.simdWorldTransform).1.inverse } ?? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)) * newValue }
    }
    open var position: SCNVector3 { get { SCNVector3(_t) } set { _t = SIMD3(newValue) } }
    open var scale: SCNVector3 { get { SCNVector3(_s) } set { _s = SIMD3(newValue) } }
    open var eulerAngles: SCNVector3 { get { SCNVector3(simdEulerAngles) } set { simdEulerAngles = SIMD3(newValue) } }
    open var orientation: SCNQuaternion { get { SCNVector4(_q.vector) } set { _q = simd_quatf(vector: SIMD4(newValue)) } }
    /// axis (x, y, z) and angle (w)
    open var rotation: SCNVector4 { get { SCNVector4(simdRotation) } set { simdRotation = SIMD4(newValue) } }
    open var transform: SCNMatrix4 { get { SCNMatrix4(simdTransform) } set { simdTransform = simd_float4x4(newValue) } }
    open var worldTransform: SCNMatrix4 { SCNMatrix4(simdWorldTransform) }
    open var worldPosition: SCNVector3 { get { SCNVector3(simdWorldPosition) } set { simdWorldPosition = SIMD3(newValue) } }
    open var worldOrientation: SCNQuaternion { get { SCNVector4(simdWorldOrientation.vector) } set { simdWorldOrientation = simd_quatf(vector: SIMD4(newValue)) } }
    open func setWorldTransform(_ worldTransform: SCNMatrix4) { simdWorldTransform = simd_float4x4(worldTransform) }

    // directions
    public static var simdLocalUp: SIMD3<Float> { SIMD3(0, 1, 0) }
    public static var simdLocalRight: SIMD3<Float> { SIMD3(1, 0, 0) }
    public static var simdLocalFront: SIMD3<Float> { SIMD3(0, 0, -1) }
    public static var localUp: SCNVector3 { SCNVector3(simdLocalUp) }
    public static var localRight: SCNVector3 { SCNVector3(simdLocalRight) }
    public static var localFront: SCNVector3 { SCNVector3(simdLocalFront) }
    open var simdWorldUp: SIMD3<Float> { simd_normalize(simdConvertVector(SCNNode.simdLocalUp, to: nil)) }
    open var simdWorldRight: SIMD3<Float> { simd_normalize(simdConvertVector(SCNNode.simdLocalRight, to: nil)) }
    open var simdWorldFront: SIMD3<Float> { simd_normalize(simdConvertVector(SCNNode.simdLocalFront, to: nil)) }
    open var worldUp: SCNVector3 { SCNVector3(simdWorldUp) }
    open var worldRight: SCNVector3 { SCNVector3(simdWorldRight) }
    open var worldFront: SCNVector3 { SCNVector3(simdWorldFront) }

    /// turns the node so that its front (-z) faces a world position
    open func simdLook(at worldTarget: SIMD3<Float>) { simdLook(at: worldTarget, up: SIMD3(0, 1, 0), localFront: SCNNode.simdLocalFront) }
    open func simdLook(at worldTarget: SIMD3<Float>, up worldUp: SIMD3<Float>, localFront: SIMD3<Float>) {
        let from = simdWorldPosition
        guard simd_length(worldTarget - from) > 1e-6 else { return }
        let q = _SCN.look(from: from, to: worldTarget, up: worldUp)
        // the rotation that takes localFront to -z, then -z to the target
        let fix = simd_quatf(from: simd_normalize(localFront), to: SIMD3(0, 0, -1))
        simdWorldOrientation = q * fix
    }
    open func look(at worldTarget: SCNVector3) { simdLook(at: SIMD3(worldTarget)) }
    open func look(at worldTarget: SCNVector3, up worldUp: SCNVector3, localFront: SCNVector3) {
        simdLook(at: SIMD3(worldTarget), up: SIMD3(worldUp), localFront: SIMD3(localFront))
    }
    open func simdLocalTranslate(by translation: SIMD3<Float>) { _t += _q.act(translation) }
    open func localTranslate(by translation: SCNVector3) { simdLocalTranslate(by: SIMD3(translation)) }
    open func simdLocalRotate(by rotation: simd_quatf) { _q = _q * rotation }
    open func localRotate(by rotation: SCNQuaternion) { simdLocalRotate(by: simd_quatf(vector: SIMD4(rotation))) }
    open func simdRotate(by worldRotation: simd_quatf, aroundTarget worldTarget: SIMD3<Float>) {
        let p = simdWorldPosition
        simdWorldOrientation = worldRotation * simdWorldOrientation
        simdWorldPosition = worldTarget + worldRotation.act(p - worldTarget)
    }
    open func rotate(by worldRotation: SCNQuaternion, aroundTarget worldTarget: SCNVector3) {
        simdRotate(by: simd_quatf(vector: SIMD4(worldRotation)), aroundTarget: SIMD3(worldTarget))
    }

    /// the node as it is drawn (with constraints applied); isim keeps one copy, so this is the node itself
    @objc open var presentation: SCNNode { self }

    // conversions
    open func simdConvertPosition(_ position: SIMD3<Float>, to node: SCNNode?) -> SIMD3<Float> {
        let w = simdWorldTransform * SIMD4(position, 1)
        let l = node.map { _SCN.inverse($0.simdWorldTransform) * w } ?? w
        return SIMD3(l.x, l.y, l.z)
    }
    open func simdConvertPosition(_ position: SIMD3<Float>, from node: SCNNode?) -> SIMD3<Float> {
        let w = (node?.simdWorldTransform ?? matrix_identity_float4x4) * SIMD4(position, 1)
        let l = _SCN.inverse(simdWorldTransform) * w
        return SIMD3(l.x, l.y, l.z)
    }
    open func simdConvertVector(_ vector: SIMD3<Float>, to node: SCNNode?) -> SIMD3<Float> {
        let w = simdWorldTransform * SIMD4(vector, 0)
        let l = node.map { _SCN.inverse($0.simdWorldTransform) * w } ?? w
        return SIMD3(l.x, l.y, l.z)
    }
    open func simdConvertVector(_ vector: SIMD3<Float>, from node: SCNNode?) -> SIMD3<Float> {
        let w = (node?.simdWorldTransform ?? matrix_identity_float4x4) * SIMD4(vector, 0)
        let l = _SCN.inverse(simdWorldTransform) * w
        return SIMD3(l.x, l.y, l.z)
    }
    open func simdConvertTransform(_ transform: simd_float4x4, to node: SCNNode?) -> simd_float4x4 {
        let w = simdWorldTransform * transform
        return node.map { _SCN.inverse($0.simdWorldTransform) * w } ?? w
    }
    open func simdConvertTransform(_ transform: simd_float4x4, from node: SCNNode?) -> simd_float4x4 {
        _SCN.inverse(simdWorldTransform) * (node?.simdWorldTransform ?? matrix_identity_float4x4) * transform
    }
    open func convertPosition(_ position: SCNVector3, to node: SCNNode?) -> SCNVector3 { SCNVector3(simdConvertPosition(SIMD3(position), to: node)) }
    open func convertPosition(_ position: SCNVector3, from node: SCNNode?) -> SCNVector3 { SCNVector3(simdConvertPosition(SIMD3(position), from: node)) }
    open func convertVector(_ vector: SCNVector3, to node: SCNNode?) -> SCNVector3 { SCNVector3(simdConvertVector(SIMD3(vector), to: node)) }
    open func convertVector(_ vector: SCNVector3, from node: SCNNode?) -> SCNVector3 { SCNVector3(simdConvertVector(SIMD3(vector), from: node)) }
    open func convertTransform(_ transform: SCNMatrix4, to node: SCNNode?) -> SCNMatrix4 { SCNMatrix4(simdConvertTransform(simd_float4x4(transform), to: node)) }
    open func convertTransform(_ transform: SCNMatrix4, from node: SCNNode?) -> SCNMatrix4 { SCNMatrix4(simdConvertTransform(simd_float4x4(transform), from: node)) }

    // bounds: the geometry's and the children's, in the node's space
    var _box: (min: SCNVector3, max: SCNVector3)?
    open var boundingBox: (min: SCNVector3, max: SCNVector3) {
        get {
            if let _box { return _box }
            guard let b = _SCN.bounds(of: self, in: matrix_identity_float4x4) else { return (SCNVector3Zero, SCNVector3Zero) }
            return (SCNVector3(b.0), SCNVector3(b.1))
        }
        set { _box = newValue }
    }
    open var boundingSphere: (center: SCNVector3, radius: Float) {
        let b = boundingBox
        let lo = SIMD3(b.min), hi = SIMD3(b.max)
        return (SCNVector3((lo + hi) / 2), simd_length(hi - lo) / 2)
    }

    // hierarchy
    @objc open func addChildNode(_ child: SCNNode) { insertChildNode(child, at: childNodes.count) }
    @objc open func insertChildNode(_ child: SCNNode, at index: Int) {
        child.removeFromParentNode()
        childNodes.insert(child, at: min(index, childNodes.count))
        child.parent = self
    }
    @objc open func removeFromParentNode() {
        parent?.childNodes.removeAll { $0 === self }
        parent = nil
    }
    @objc open func replaceChildNode(_ oldChild: SCNNode, with newChild: SCNNode) {
        guard let i = childNodes.firstIndex(where: { $0 === oldChild }) else { return }
        oldChild.removeFromParentNode()
        insertChildNode(newChild, at: i)
    }
    @objc open func childNode(withName name: String, recursively: Bool) -> SCNNode? {
        for c in childNodes {
            if c.name == name { return c }
            if recursively, let f = c.childNode(withName: name, recursively: true) { return f }
        }
        return nil
    }
    @objc open func childNodes(passingTest predicate: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Bool) -> [SCNNode] {
        var out: [SCNNode] = [], stop = ObjCBool(false)
        func walk(_ n: SCNNode) {
            for c in n.childNodes where !stop.boolValue {
                if predicate(c, &stop) { out.append(c) }
                walk(c)
            }
        }
        walk(self)
        return out
    }
    @objc open func enumerateChildNodes(_ block: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        _ = childNodes { n, stop in block(n, stop); return false }
    }
    @objc open func enumerateHierarchy(_ block: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(false)
        block(self, &stop)
        if !stop.boolValue { enumerateChildNodes(block) }
    }

    /// geometry hit by the segment between two points (in the node's space)
    open func hitTestWithSegment(from pointA: SCNVector3, to pointB: SCNVector3, options: [String: Any]? = nil) -> [SCNHitTestResult] {
        let w = simdWorldTransform
        let a = w * SIMD4(SIMD3(pointA), 1), b = w * SIMD4(SIMD3(pointB), 1)
        return _SCNHitTest.segment(root: self, from: SIMD3(a.x, a.y, a.z), to: SIMD3(b.x, b.y, b.z), options: options ?? [:], segment: true)
    }

    /// a copy sharing geometry, lights and cameras, with copies of the children
    @objc open func clone() -> Self {
        let n = copy() as! SCNNode
        for c in childNodes { n.addChildNode(c.clone()) }
        return n as! Self
    }
    @objc open func flattenedClone() -> Self { clone() }
    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let n = (Swift.type(of: self) as NSObject.Type).init() as! SCNNode
        n.name = name; n._t = _t; n._q = _q; n._s = _s; n._pivot = _pivot; n.isHidden = isHidden; n.opacity = opacity
        n.renderingOrder = renderingOrder; n.castsShadow = castsShadow; n.categoryBitMask = categoryBitMask
        n.geometry = geometry; n.light = light; n.camera = camera; n.constraints = constraints
        n.physicsBody = physicsBody?.copy() as? SCNPhysicsBody; n.movabilityHint = movabilityHint
        for (key, player) in _animations { n._animations.append((key, SCNAnimationPlayer(animation: player.animation))) }
        return n
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode([_t.x, _t.y, _t.z, _q.vector.x, _q.vector.y, _q.vector.z, _q.vector.w, _s.x, _s.y, _s.z].map(NSNumber.init(value:)), forKey: "trs")
        coder.encode(childNodes, forKey: "children")
        coder.encode(isHidden, forKey: "hidden")
        coder.encode(geometry, forKey: "geometry"); coder.encode(light, forKey: "light"); coder.encode(camera, forKey: "camera")
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        if let v = (coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "trs") as? [NSNumber])?.map({ $0.floatValue }), v.count == 10 {
            _t = SIMD3(v[0], v[1], v[2]); _q = simd_quatf(vector: SIMD4(v[3], v[4], v[5], v[6])); _s = SIMD3(v[7], v[8], v[9])
        }
        for c in coder.decodeObject(of: [NSArray.self, SCNNode.self], forKey: "children") as? [SCNNode] ?? [] { addChildNode(c) }
        isHidden = coder.decodeBool(forKey: "hidden")
        geometry = coder.decodeObject(of: [SCNGeometry.self, SCNBox.self, SCNSphere.self, SCNPlane.self, SCNPyramid.self, SCNCylinder.self,
                                           SCNCone.self, SCNTorus.self, SCNTube.self, SCNCapsule.self, SCNFloor.self, SCNMaterial.self,
                                           SCNMaterialProperty.self, SCNGeometrySource.self, SCNGeometryElement.self, NSArray.self], forKey: "geometry") as? SCNGeometry
        light = coder.decodeObject(of: SCNLight.self, forKey: "light")
        camera = coder.decodeObject(of: SCNCamera.self, forKey: "camera")
    }
}

extension _SCN {
    /// the rotation that turns -z toward `to` from `from`, with y toward `up`
    static func look(from: SIMD3<Float>, to: SIMD3<Float>, up: SIMD3<Float>) -> simd_quatf {
        let f = simd_normalize(to - from)
        var r = simd_cross(f, up)
        if simd_length(r) < 1e-5 { r = simd_cross(f, abs(f.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)) }
        r = simd_normalize(r)
        let u = simd_cross(r, f)
        return simd_quatf(simd_float3x3(columns: (r, u, -f)))
    }
    /// the box around a node's geometry and its children's, in a space `m` maps the node into
    static func bounds(of node: SCNNode, in m: simd_float4x4) -> (SIMD3<Float>, SIMD3<Float>)? {
        var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity), any = false
        if let g = node.geometry {
            let b = g.boundingBox
            let a = SIMD3(b.min), c = SIMD3(b.max)
            if a != c || g._renderMesh.count > 0 {
                for i in 0..<8 {
                    let p = SIMD3(i & 1 == 0 ? a.x : c.x, i & 2 == 0 ? a.y : c.y, i & 4 == 0 ? a.z : c.z)
                    let q = m * SIMD4(p, 1)
                    lo = simd_min(lo, SIMD3(q.x, q.y, q.z)); hi = simd_max(hi, SIMD3(q.x, q.y, q.z)); any = true
                }
            }
        }
        for c in node.childNodes where !c.isHidden {
            if let b = bounds(of: c, in: m * c._local) { lo = simd_min(lo, b.0); hi = simd_max(hi, b.1); any = true }
        }
        return any ? (lo, hi) : nil
    }
}

/// A scene: a root node, a background, fog and a physics world.
@objc(SCNScene) open class SCNScene: NSObject, NSSecureCoding, @unchecked Sendable {
    public struct Attribute: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let startTime = Attribute(rawValue: "kSceneStartTimeAttributeKey")
        public static let endTime = Attribute(rawValue: "kSceneEndTimeAttributeKey")
        public static let frameRate = Attribute(rawValue: "kSceneFrameRateAttributeKey")
        public static let upAxis = Attribute(rawValue: "kSceneUpAxisAttributeKey")
    }
    @objc public override init() { super.init(); _physics._scene = self }
    @objc open private(set) var rootNode = SCNNode()
    @objc open var isPaused = false
    /// a colour or an image behind the scene
    @objc open private(set) var background = SCNMaterialProperty(nil)
    /// kept, not used for lighting
    @objc open private(set) var lightingEnvironment = SCNMaterialProperty(nil)
    @objc open var fogStartDistance: CGFloat = 0 { didSet { _SCNDirty.bump() } }
    @objc open var fogEndDistance: CGFloat = 0 { didSet { _SCNDirty.bump() } }
    @objc open var fogDensityExponent: CGFloat = 1 { didSet { _SCNDirty.bump() } }
    @objc open var fogColor: Any = UIColor.white { didSet { _SCNDirty.bump() } }
    @objc open var wantsScreenSpaceReflection = false
    @objc open var screenSpaceReflectionSampleCount = 64
    @objc open var screenSpaceReflectionMaximumDistance: CGFloat = 1000
    @objc open var screenSpaceReflectionStride: CGFloat = 8
    var _physics = SCNPhysicsWorld()
    @objc open var physicsWorld: SCNPhysicsWorld { _physics }
    @objc var _attributes: [String: Any] = [:]

    /// a scene file in the main bundle: Wavefront .obj (with its .mtl), or a scene isim archived (.scn written by
    /// write(to:)); nil for other formats (SceneLoading.swift)
    @objc public convenience init?(named name: String) { self.init(named: name, inDirectory: nil, options: nil) }
    @objc public convenience init?(named name: String, inDirectory directory: String?, options: [String: Any]? = nil) {
        guard let url = _SCNSceneFile.find(name, directory: directory), let s = try? _SCNSceneFile.load(url) else { return nil }
        self.init(root: s)
    }
    public convenience init(url: URL, options: [SCNSceneSource.LoadingOption: Any]? = nil) throws {
        self.init(root: try _SCNSceneFile.load(url))
    }
    @objc public convenience init(mdlAsset: AnyObject) { self.init() }
    convenience init(root: SCNNode) {
        self.init()
        rootNode = root
    }
    open func attribute(forKey key: String) -> Any? { _attributes[key] }
    open func setAttribute(_ attribute: Any?, forKey key: String) { _attributes[key] = attribute }
    /// writes the scene as isim's archive (a keyed archive of the scene graph); other formats fail
    open func write(to url: URL, options: [String: Any]? = nil, delegate: (any SCNSceneExportDelegate)?,
                    progressHandler: SCNSceneExportProgressHandler? = nil) -> Bool {
        guard url.pathExtension.lowercased() == "scn",
              let data = try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true) else {
            var stop = ObjCBool(false); progressHandler?(1, NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError), &stop)
            return false
        }
        do { try data.write(to: url) } catch { return false }
        var stop = ObjCBool(false); progressHandler?(1, nil, &stop)
        return true
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(rootNode, forKey: "root")
        if let c = background.contents as? UIColor { coder.encode(c, forKey: "background") }
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        _physics._scene = self
        if let r = coder.decodeObject(of: SCNNode.self, forKey: "root") { rootNode = r }
        if let c = coder.decodeObject(of: UIColor.self, forKey: "background") { background.contents = c }
    }
}

public protocol SCNSceneExportDelegate: NSObjectProtocol {}
public typealias SCNSceneExportProgressHandler = (Float, (any Error)?, UnsafeMutablePointer<ObjCBool>) -> Void
