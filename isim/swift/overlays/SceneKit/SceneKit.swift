// isim SceneKit: the scene graph (SCNNode, SCNScene), SceneKit's vector and matrix types and SCNView with its render
// loop, enough for apps (and ARKit's ARSCNView) to build and run. Self-authored, iOS API names. Stub: nothing is drawn
// (the view shows its background colour) and scene files do not load; the 3D renderer is #330. Adapted: the render
// loop runs at the view's frame rate and calls the renderer delegate as SceneKit does.
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

/// A node of the scene graph: a transform (position, orientation, scale) and children.
open class SCNNode: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public override init() { super.init() }
    open var name: String?
    open internal(set) weak var parent: SCNNode?
    open private(set) var childNodes: [SCNNode] = []
    open var isHidden = false
    open var opacity: CGFloat = 1
    open var renderingOrder = 0
    open var castsShadow = true
    open var categoryBitMask = 1
    var _t = SIMD3<Float>(repeating: 0), _q = simd_quatf(), _s = SIMD3<Float>(repeating: 1)

    // transform
    open var simdPosition: SIMD3<Float> { get { _t } set { _t = newValue } }
    open var simdOrientation: simd_quatf { get { _q } set { _q = newValue } }
    open var simdScale: SIMD3<Float> { get { _s } set { _s = newValue } }
    open var simdEulerAngles: SIMD3<Float> { get { _SCN.euler(_q) } set { _q = _SCN.quat(euler: newValue) } }
    open var simdTransform: simd_float4x4 {
        get { _SCN.compose(_t, _q, _s) }
        set { (_t, _q, _s) = _SCN.decompose(newValue) }
    }
    open var simdWorldTransform: simd_float4x4 {
        get { (parent?.simdWorldTransform ?? matrix_identity_float4x4) * simdTransform }
        set { simdTransform = parent.map { _SCN.inverse($0.simdWorldTransform) * newValue } ?? newValue }
    }
    open var simdWorldPosition: SIMD3<Float> {
        get { let c = simdWorldTransform.columns.3; return SIMD3(c.x, c.y, c.z) }
        set { var w = simdWorldTransform; w.columns.3 = SIMD4(newValue, 1); simdWorldTransform = w }
    }
    open var position: SCNVector3 { get { SCNVector3(_t) } set { _t = SIMD3(newValue) } }
    open var scale: SCNVector3 { get { SCNVector3(_s) } set { _s = SIMD3(newValue) } }
    open var eulerAngles: SCNVector3 { get { SCNVector3(simdEulerAngles) } set { simdEulerAngles = SIMD3(newValue) } }
    open var orientation: SCNQuaternion { get { SCNVector4(_q.vector) } set { _q = simd_quatf(vector: SIMD4(newValue)) } }
    /// axis (x, y, z) and angle (w)
    open var rotation: SCNVector4 {
        get { let a = _q.axis; return SCNVector4(a.x, a.y, a.z, _q.angle) }
        set { _q = simd_quatf(angle: newValue.w, axis: SIMD3(newValue.x, newValue.y, newValue.z)) }
    }
    open var transform: SCNMatrix4 { get { SCNMatrix4(simdTransform) } set { simdTransform = simd_float4x4(newValue) } }
    open var worldTransform: SCNMatrix4 { SCNMatrix4(simdWorldTransform) }
    open var worldPosition: SCNVector3 { get { SCNVector3(simdWorldPosition) } set { simdWorldPosition = SIMD3(newValue) } }
    open func setWorldTransform(_ worldTransform: SCNMatrix4) { simdWorldTransform = simd_float4x4(worldTransform) }
    open var presentation: SCNNode { self }
    open func convertPosition(_ position: SCNVector3, to node: SCNNode?) -> SCNVector3 {
        let w = simdWorldTransform * SIMD4(SIMD3(position), 1)
        let l = node.map { _SCN.inverse($0.simdWorldTransform) * w } ?? w
        return SCNVector3(l.x, l.y, l.z)
    }
    open func convertPosition(_ position: SCNVector3, from node: SCNNode?) -> SCNVector3 {
        let w = (node?.simdWorldTransform ?? matrix_identity_float4x4) * SIMD4(SIMD3(position), 1)
        let l = _SCN.inverse(simdWorldTransform) * w
        return SCNVector3(l.x, l.y, l.z)
    }

    // hierarchy
    open func addChildNode(_ child: SCNNode) { insertChildNode(child, at: childNodes.count) }
    open func insertChildNode(_ child: SCNNode, at index: Int) {
        child.removeFromParentNode()
        childNodes.insert(child, at: min(index, childNodes.count))
        child.parent = self
    }
    open func removeFromParentNode() {
        parent?.childNodes.removeAll { $0 === self }
        parent = nil
    }
    open func replaceChildNode(_ oldChild: SCNNode, with newChild: SCNNode) {
        guard let i = childNodes.firstIndex(where: { $0 === oldChild }) else { return }
        oldChild.removeFromParentNode()
        insertChildNode(newChild, at: i)
    }
    open func childNode(withName name: String, recursively: Bool) -> SCNNode? {
        for c in childNodes {
            if c.name == name { return c }
            if recursively, let f = c.childNode(withName: name, recursively: true) { return f }
        }
        return nil
    }
    open func childNodes(passingTest predicate: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Bool) -> [SCNNode] {
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
    open func enumerateChildNodes(_ block: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        _ = childNodes { n, stop in block(n, stop); return false }
    }
    open func enumerateHierarchy(_ block: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(false)
        block(self, &stop)
        if !stop.boolValue { enumerateChildNodes(block) }
    }

    open func clone() -> Self {
        let n = copy() as! SCNNode
        for c in childNodes { n.addChildNode(c.clone()) }
        return n as! Self
    }
    open func flattenedClone() -> Self { clone() }
    open func copy(with zone: NSZone? = nil) -> Any {
        let n = (Swift.type(of: self) as NSObject.Type).init() as! SCNNode
        n.name = name; n._t = _t; n._q = _q; n._s = _s; n.isHidden = isHidden; n.opacity = opacity
        n.renderingOrder = renderingOrder; n.castsShadow = castsShadow; n.categoryBitMask = categoryBitMask
        return n
    }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode([_t.x, _t.y, _t.z, _q.vector.x, _q.vector.y, _q.vector.z, _q.vector.w, _s.x, _s.y, _s.z].map(NSNumber.init(value:)), forKey: "trs")
        coder.encode(childNodes, forKey: "children")
        coder.encode(isHidden, forKey: "hidden")
    }
    public required init?(coder: NSCoder) {
        super.init()
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        if let v = (coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "trs") as? [NSNumber])?.map({ $0.floatValue }), v.count == 10 {
            _t = SIMD3(v[0], v[1], v[2]); _q = simd_quatf(vector: SIMD4(v[3], v[4], v[5], v[6])); _s = SIMD3(v[7], v[8], v[9])
        }
        for c in coder.decodeObject(of: [NSArray.self, SCNNode.self], forKey: "children") as? [SCNNode] ?? [] { addChildNode(c) }
        isHidden = coder.decodeBool(forKey: "hidden")
    }
}

/// A scene: a root node. Scene files do not load yet (#330).
open class SCNScene: NSObject, NSSecureCoding, @unchecked Sendable {
    public override init() { super.init() }
    open private(set) var rootNode = SCNNode()
    open var isPaused = false
    open var fogStartDistance: CGFloat = 0
    open var fogEndDistance: CGFloat = 0
    open var fogDensityExponent: CGFloat = 1
    var _attributes: [String: Any] = [:]
    /// nil: isim cannot read .scn / .dae / .usdz files yet
    public convenience init?(named name: String) { return nil }
    public convenience init?(named name: String, inDirectory directory: String?, options: [String: Any]? = nil) { return nil }
    public convenience init(url: URL, options: [String: Any]? = nil) throws {
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                      userInfo: [NSLocalizedDescriptionKey: "isim's SceneKit cannot read scene files yet", NSURLErrorKey: url])
    }
    open func attribute(forKey key: String) -> Any? { _attributes[key] }
    open func setAttribute(_ attribute: Any?, forKey key: String) { _attributes[key] = attribute }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(rootNode, forKey: "root") }
    public required init?(coder: NSCoder) {
        super.init()
        if let r = coder.decodeObject(of: SCNNode.self, forKey: "root") { rootNode = r }
    }
}

// MARK: - renderers and views

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

public protocol SCNSceneRenderer: AnyObject {
    var scene: SCNScene! { get set }
    var sceneTime: TimeInterval { get set }
    var delegate: (any SCNSceneRendererDelegate)? { get set }
    var isPlaying: Bool { get set }
    var loops: Bool { get set }
    var pointOfView: SCNNode? { get set }
    var autoenablesDefaultLighting: Bool { get set }
    var isJitteringEnabled: Bool { get set }
    var showsStatistics: Bool { get set }
    func isNode(_ node: SCNNode, insideFrustumOf pointOfView: SCNNode) -> Bool
    func nodesInsideFrustum(of pointOfView: SCNNode) -> [SCNNode]
    func projectPoint(_ point: SCNVector3) -> SCNVector3
    func unprojectPoint(_ point: SCNVector3) -> SCNVector3
}

/// A view that shows a scene. Stub: it draws its background colour only (no 3D renderer yet, #330); the render loop
/// still runs at `preferredFramesPerSecond` while playing (or `rendersContinuously`) and calls the delegate.
@MainActor open class SCNView: UIView, @preconcurrency SCNSceneRenderer {
    public override init(frame: CGRect) { super.init(frame: frame) }
    public init(frame: CGRect, options: [String: Any]? = nil) { super.init(frame: frame) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    /// SCNScene! (iOS: optional on SCNView, non-optional on ARSCNView; Swift cannot narrow an inherited property)
    open var scene: SCNScene! { didSet { _restart() } }
    open var sceneTime: TimeInterval = 0
    open weak var delegate: (any SCNSceneRendererDelegate)?
    open var isPlaying = false { didSet { _restart() } }
    open var loops = true
    open var pointOfView: SCNNode?
    open var autoenablesDefaultLighting = false
    open var isJitteringEnabled = false
    open var showsStatistics = false
    open var allowsCameraControl = false
    open var rendersContinuously = false { didSet { _restart() } }
    open var preferredFramesPerSecond = 60 { didSet { _restart() } }
    open var antialiasingMode: SCNAntialiasingMode = .multisampling4X
    open func play(_ sender: Any?) { isPlaying = true }
    open func pause(_ sender: Any?) { isPlaying = false }
    open func stop(_ sender: Any?) { isPlaying = false; sceneTime = 0 }
    open func snapshot() -> UIImage {
        UIGraphicsImageRenderer(bounds: bounds).image { _ in drawHierarchy(in: bounds, afterScreenUpdates: false) }
    }
    open func isNode(_ node: SCNNode, insideFrustumOf pointOfView: SCNNode) -> Bool { false }
    open func nodesInsideFrustum(of pointOfView: SCNNode) -> [SCNNode] { [] }
    /// no camera projection without a renderer: points pass through
    open func projectPoint(_ point: SCNVector3) -> SCNVector3 { point }
    open func unprojectPoint(_ point: SCNVector3) -> SCNVector3 { point }

    var _timer: Timer?
    var _start: TimeInterval?
    open override func didMoveToWindow() { super.didMoveToWindow(); _restart() }
    func _restart() {
        _timer?.invalidate(); _timer = nil
        guard window != nil, scene != nil, isPlaying || rendersContinuously else { return }
        let fps = max(1, preferredFramesPerSecond)
        _timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(fps), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?._frame() }
        }
    }
    /// one turn of SceneKit's render loop, without the drawing
    func _frame() {
        guard let scene, !scene.isPaused else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if _start == nil { _start = now - sceneTime }
        if isPlaying { sceneTime = now - (_start ?? now) }
        let d = delegate
        d?.renderer(self, updateAtTime: now)
        d?.renderer(self, didApplyAnimationsAtTime: now)
        d?.renderer(self, didSimulatePhysicsAtTime: now)
        d?.renderer(self, didApplyConstraintsAtTime: now)
        d?.renderer(self, willRenderScene: scene, atTime: now)
        _renderFrame(now)
        d?.renderer(self, didRenderScene: scene, atTime: now)
    }
    /// subclasses' per-frame work (ARSCNView updates its anchors' nodes)
    func _renderFrame(_ time: TimeInterval) {}
}
