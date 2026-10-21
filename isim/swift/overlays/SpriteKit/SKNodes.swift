// isim SpriteKit: more node types (camera, crop, effect, field, tile map, reference, light), shaders and uniforms
// (run by SKShading.swift), constraints and ranges.
import Foundation
import CoreImage
import isim_host

// MARK: - Camera

@objc(SKCameraNode) open class SKCameraNode: SKNode {
    @objc public override init() { super.init() }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
    /// the scene rectangle the camera shows (in the camera's parent coordinates)
    func viewRect() -> CGRect? {
        guard let s = scene, let v = s.view else { return nil }
        let inv = v.sceneToView.inverted()
        let corners = [CGPoint.zero, CGPoint(x: v.bounds.width, y: 0), CGPoint(x: 0, y: v.bounds.height), CGPoint(x: v.bounds.width, y: v.bounds.height)].map { $0.applying(inv) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
    @objc(containsNode:) open func contains(_ node: SKNode) -> Bool {
        guard let r = viewRect(), let s = scene else { return false }
        let f = node.calculateAccumulatedFrame()
        let sf = node.parent.map { p in p === s ? f : f.applying(p.sceneTransform) } ?? f
        return r.intersects(sf)
    }
    @objc open func containedNodeSet() -> Set<SKNode> {
        guard let s = scene else { return [] }
        return Set(s.descendants().filter { !($0 is SKCameraNode) && contains($0) })
    }
}

// MARK: - Effect & crop nodes

@objc(SKEffectNode) open class SKEffectNode: SKNode {
    @objc open var shouldEnableEffects = false
    @objc open var shouldRasterize = false
    @objc open var shouldCenterFilter = true
    open var blendMode: SKBlendMode = .alpha
    @objc open var shader: SKShader?
    /// a Core Image filter applied to the children (with shouldEnableEffects; SKEffects.swift)
    @objc open var filter: CIFilter?
    @objc public override init() { super.init() }
    @objc public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let c = coder as? _SKCoder { shouldEnableEffects = c.bool("shouldEnableEffects") ?? false; shouldRasterize = c.bool("shouldRasterize") ?? false }
    }
}

@objc(SKCropNode) open class SKCropNode: SKNode {
    /// children are drawn only where the mask node's content is opaque
    @objc open var maskNode: SKNode?
    @objc public override init() { super.init() }
    @objc public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let c = coder as? _SKCoder, let u = c.coder(forKey: "maskNode")?.uid { maskNode = c.node(uid: u) }
    }
}

// MARK: - Shaders and lights (stored; isim has no GPU shading or lighting)

public enum SKUniformType: Int, Sendable { case none, float, floatVector2, floatVector3, floatVector4, floatMatrix2, floatMatrix3, floatMatrix4, texture }
public enum SKAttributeType: Int, Sendable { case none, float, vectorFloat2, vectorFloat3, vectorFloat4, halfFloat, vectorHalfFloat2, vectorHalfFloat3, vectorHalfFloat4 }

@objc(SKUniform) open class SKUniform: NSObject {
    @objc open var name: String
    open var uniformType: SKUniformType = .none
    @objc open var textureValue: SKTexture?
    @objc open var floatValue: Float = 0
    open var vectorFloat2Value: vector_float2 = .zero
    open var vectorFloat3Value: vector_float3 = .zero
    open var vectorFloat4Value: vector_float4 = .zero
    open var matrixFloat2x2Value = matrix_float2x2(1)
    open var matrixFloat3x3Value = matrix_float3x3(1)
    open var matrixFloat4x4Value = matrix_float4x4(1)
    /// column-major values of the matrix uniform (for the shader)
    var _matrixValues: [Float] {
        switch uniformType {
        case .floatMatrix2: let m = matrixFloat2x2Value; return [m[0][0], m[0][1], m[1][0], m[1][1]]
        case .floatMatrix3: let m = matrixFloat3x3Value; return (0..<3).flatMap { c in (0..<3).map { m[c][$0] } }
        case .floatMatrix4: let m = matrixFloat4x4Value; return (0..<4).flatMap { c in (0..<4).map { m[c][$0] } }
        default: return []
        }
    }
    @objc public init(name: String) { self.name = name }
    public convenience init(name: String, matrixFloat2x2 v: matrix_float2x2) { self.init(name: name); matrixFloat2x2Value = v; uniformType = .floatMatrix2 }
    public convenience init(name: String, matrixFloat3x3 v: matrix_float3x3) { self.init(name: name); matrixFloat3x3Value = v; uniformType = .floatMatrix3 }
    public convenience init(name: String, matrixFloat4x4 v: matrix_float4x4) { self.init(name: name); matrixFloat4x4Value = v; uniformType = .floatMatrix4 }
    @objc public convenience init(name: String, float value: Float) { self.init(name: name); floatValue = value; uniformType = .float }
    @objc public convenience init(name: String, texture: SKTexture?) { self.init(name: name); textureValue = texture; uniformType = .texture }
    public convenience init(name: String, vectorFloat2 v: vector_float2) { self.init(name: name); vectorFloat2Value = v; uniformType = .floatVector2 }
    public convenience init(name: String, vectorFloat3 v: vector_float3) { self.init(name: name); vectorFloat3Value = v; uniformType = .floatVector3 }
    public convenience init(name: String, vectorFloat4 v: vector_float4) { self.init(name: name); vectorFloat4Value = v; uniformType = .floatVector4 }
}

@objc(SKAttribute) open class SKAttribute: NSObject {
    @objc open var name: String
    open var type: SKAttributeType
    public init(name: String, type: SKAttributeType) { self.name = name; self.type = type }
}

@objc(SKAttributeValue) open class SKAttributeValue: NSObject {
    @objc open var floatValue: Float = 0
    open var vectorFloat2Value: vector_float2 = .zero
    open var vectorFloat3Value: vector_float3 = .zero
    open var vectorFloat4Value: vector_float4 = .zero
    @objc public override init() { super.init() }
    @objc public convenience init(float v: Float) { self.init(); floatValue = v }
    public convenience init(vectorFloat2 v: vector_float2) { self.init(); vectorFloat2Value = v }
    public convenience init(vectorFloat3 v: vector_float3) { self.init(); vectorFloat3Value = v }
    public convenience init(vectorFloat4 v: vector_float4) { self.init(); vectorFloat4Value = v }
}

/// Custom fragment shaders, run on the CPU through Core Image's kernel interpreter (SKShading.swift).
@objc(SKShader) open class SKShader: NSObject {
    @objc open var source: String?
    @objc open var uniforms: [SKUniform] = []
    @objc open var attributes: [SKAttribute] = []
    @objc public override init() { super.init() }
    @objc public convenience init(source: String) { self.init(); self.source = source }
    @objc public convenience init(source: String, uniforms: [SKUniform]) { self.init(source: source); self.uniforms = uniforms }
    @objc public convenience init(fileNamed name: String) {
        self.init()
        let n = name as NSString
        if let p = Bundle.main.path(forResource: n.deletingPathExtension, ofType: n.pathExtension.isEmpty ? "fsh" : n.pathExtension) {
            source = try? String(contentsOfFile: p, encoding: .utf8)
        }
    }
    @objc public convenience init(source: String, uniforms: [SKUniform], attributes: [SKAttribute]) { self.init(source: source, uniforms: uniforms); self.attributes = attributes }
    @objc open func addUniform(_ u: SKUniform) { uniforms.append(u) }
    @objc open func uniformNamed(_ name: String) -> SKUniform? { uniforms.first { $0.name == name } }
    @objc open func removeUniformNamed(_ name: String) { uniforms.removeAll { $0.name == name } }
    @objc open override func copy() -> Any { let s = SKShader(); s.source = source; s.uniforms = uniforms; s.attributes = attributes; return s }
}

/// Lights are stored but do not light or shadow sprites on isim.
@objc(SKLightNode) open class SKLightNode: SKNode {
    @objc open var isEnabled = true
    @objc open var lightColor: UIColor = .white
    @objc open var ambientColor: UIColor = .black
    @objc open var shadowColor: UIColor = .clear
    @objc open var falloff: CGFloat = 1
    @objc open var categoryBitMask: UInt32 = 1
    @objc public override init() { super.init() }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
}

// MARK: - Fields

public typealias SKFieldForceEvaluator = (vector_float3, vector_float3, Float, Float, TimeInterval) -> vector_float3

@objc(SKRegion) open class SKRegion: NSObject {
    let test: (CGPoint) -> Bool
    @objc open private(set) var path: CGPath?
    init(test: @escaping (CGPoint) -> Bool, path: CGPath?) { self.test = test; self.path = path }
    @objc public convenience init(radius: Float) {
        let r = CGFloat(radius)
        self.init(test: { _len($0) <= r }, path: CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil))
    }
    @objc public convenience init(size: CGSize) {
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        self.init(test: { rect.contains($0) }, path: CGPath(rect: rect, transform: nil))
    }
    @objc public convenience init(path: CGPath) {
        let polys = _pathPoints(path)
        self.init(test: { p in polys.contains { _pointInPolygon(p, $0) } }, path: path)
    }
    @objc(infiniteRegion) open class func infinite() -> SKRegion { SKRegion(test: { _ in true }, path: nil) }
    @objc(inverseRegion) open func inverse() -> SKRegion { let t = test; return SKRegion(test: { !t($0) }, path: nil) }
    @objc(regionByUnionWithRegion:) open func byUnion(with r: SKRegion) -> SKRegion { let a = test, b = r.test; return SKRegion(test: { a($0) || b($0) }, path: nil) }
    @objc(regionByDifferenceFromRegion:) open func byDifference(from r: SKRegion) -> SKRegion { let a = test, b = r.test; return SKRegion(test: { a($0) && !b($0) }, path: nil) }
    @objc(regionByIntersectionWithRegion:) open func byIntersection(with r: SKRegion) -> SKRegion { let a = test, b = r.test; return SKRegion(test: { a($0) && b($0) }, path: nil) }
    @objc(containsPoint:) open func contains(_ p: CGPoint) -> Bool { test(p) }
    @objc open override func copy() -> Any { self }
}

func _pointInPolygon(_ p: CGPoint, _ poly: [CGPoint]) -> Bool {
    var inside = false
    var j = poly.count - 1
    for i in 0..<poly.count {
        let a = poly[i], b = poly[j]
        if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
        j = i
    }
    return inside
}

@objc(SKFieldNode) open class SKFieldNode: SKNode {
    enum Kind { case linearGravity, radialGravity, spring, drag, vortex, velocity, noise, turbulence, electric, magnetic, custom }
    var kind: Kind = .radialGravity
    var evaluator: SKFieldForceEvaluator?
    @objc open var region: SKRegion?
    @objc open var minimumRadius: Float = 0
    @objc open var isEnabled = true
    @objc open var isExclusive = false
    @objc open var strength: Float = 1
    @objc open var falloff: Float = 0
    @objc open var animationSpeed: Float = 1
    @objc open var smoothness: Float = 0
    open var direction: vector_float3 = vector_float3(0, 0, 0)
    @objc open var texture: SKTexture?
    @objc open var categoryBitMask: UInt32 = 0xFFFF_FFFF

    @objc public override init() { super.init() }
    @objc public required init?(coder: NSCoder) { super.init(coder: coder) }
    convenience init(kind: Kind) { self.init(); self.kind = kind }

    @objc open class func dragField() -> SKFieldNode { SKFieldNode(kind: .drag) }
    @objc open class func vortexField() -> SKFieldNode { SKFieldNode(kind: .vortex) }
    @objc open class func radialGravityField() -> SKFieldNode { SKFieldNode(kind: .radialGravity) }
    open class func linearGravityField(withVector v: vector_float3) -> SKFieldNode { let f = SKFieldNode(kind: .linearGravity); f.direction = v; return f }
    open class func velocityField(withVector v: vector_float3) -> SKFieldNode { let f = SKFieldNode(kind: .velocity); f.direction = v; return f }
    @objc(velocityFieldWithTexture:) open class func velocityField(with texture: SKTexture) -> SKFieldNode { let f = SKFieldNode(kind: .velocity); f.texture = texture; return f }
    @objc open class func noiseField(withSmoothness s: CGFloat, animationSpeed a: CGFloat) -> SKFieldNode {
        let f = SKFieldNode(kind: .noise); f.smoothness = Float(s); f.animationSpeed = Float(a); return f
    }
    @objc open class func turbulenceField(withSmoothness s: CGFloat, animationSpeed a: CGFloat) -> SKFieldNode {
        let f = SKFieldNode(kind: .turbulence); f.smoothness = Float(s); f.animationSpeed = Float(a); return f
    }
    @objc open class func springField() -> SKFieldNode { SKFieldNode(kind: .spring) }
    @objc open class func electricField() -> SKFieldNode { SKFieldNode(kind: .electric) }
    @objc open class func magneticField() -> SKFieldNode { SKFieldNode(kind: .magnetic) }
    open class func customField(evaluationBlock block: @escaping SKFieldForceEvaluator) -> SKFieldNode {
        let f = SKFieldNode(kind: .custom); f.evaluator = block; return f
    }

    /// a drag field's coefficient at a point (newtons per meter per second), 0 outside its region
    func _dragCoefficient(at p: CGPoint) -> CGFloat {
        guard kind == .drag, regionContains(p) else { return 0 }
        let rm = max(_len(_sub(p, placement.0)) / _ptm, CGFloat(minimumRadius) / _ptm, 0.01)
        return CGFloat(strength) * (falloff != 0 ? 1 / pow(rm, CGFloat(falloff)) : 1)
    }
    /// a magnetic field's turning rate times mass (kg rad/s) on a charge at a point, 0 outside its region: the force
    /// s q (v.y, -v.x) turns the velocity clockwise at s q / m
    func _magneticRate(at p: CGPoint, charge: CGFloat) -> CGFloat {
        guard kind == .magnetic, regionContains(p) else { return 0 }
        let rm = max(_len(_sub(p, placement.0)) / _ptm, CGFloat(minimumRadius) / _ptm, 0.01)
        return CGFloat(strength) * charge * (falloff != 0 ? 1 / pow(rm, CGFloat(falloff)) : 1)
    }
    /// field origin and rotation in scene space
    var placement: (CGPoint, CGFloat) {
        guard let p = parent else { return (position, zRotation) }
        let t = p is SKScene ? CGAffineTransform.identity : p.sceneTransform
        return (position.applying(t), zRotation + atan2(t.b, t.a))
    }
    func regionContains(_ scenePoint: CGPoint) -> Bool {
        guard let region else { return true }
        let (o, a) = placement
        return region.contains(_rot(_sub(scenePoint, o), cos(-a), sin(-a)))
    }
    /// force on a body, internal units (kg * points / s^2)
    func force(on b: SKPhysicsBody) -> CGPoint {
        guard regionContains(b.com) else { return .zero }
        return _force(at: b.com, velocity: CGPoint(x: b.velocity.dx, y: b.velocity.dy), mass: b.mass, charge: b.charge)
    }
    /// the field's force at a scene point on a mass with a charge moving at a velocity (points/s); internal units
    func _force(at p: CGPoint, velocity vel: CGPoint, mass m: CGFloat, charge: CGFloat) -> CGPoint {
        let (o, a) = placement
        let d = _sub(p, o)                                       // points
        let rm = max(_len(d) / _ptm, CGFloat(minimumRadius) / _ptm, 0.01)   // meters
        let fall = falloff != 0 ? 1 / pow(rm, CGFloat(falloff)) : 1
        let s = CGFloat(strength), u = _norm(d)
        let v = CGPoint(x: vel.x / _ptm, y: vel.y / _ptm)       // m/s
        var accel = CGPoint.zero, force = CGPoint.zero           // m/s^2, N
        switch kind {
        case .linearGravity:
            accel = _rot(CGPoint(x: CGFloat(direction.x), y: CGFloat(direction.y)), cos(a), sin(a))
            accel = _mul(accel, s * fall)
        case .radialGravity: accel = _mul(u, -9.8 * s * fall)
        case .spring: force = _mul(d, -s / _ptm)
        case .drag: force = _mul(v, -s * fall)
        case .vortex: force = _mul(CGPoint(x: -u.y, y: u.x), s * fall)
        case .velocity:
            var dir = CGPoint(x: CGFloat(direction.x), y: CGFloat(direction.y))
            if let tex = texture, let px = tex._pixels() {
                // the texture's pixels are directions (rgb: 0.5 + 0.5 x / y), one point per pixel around the field
                let local = _rot(d, cos(-a), sin(-a))
                let sz = tex.size()
                let c = px.sample(Float(local.x / sz.width + 0.5), Float(local.y / sz.height + 0.5))
                dir = CGPoint(x: CGFloat(c.x * 2 - 1), y: CGFloat(c.y * 2 - 1))
            }
            let target = _mul(_rot(dir, cos(a), sin(a)), s)
            accel = _mul(_sub(target, v), 10)
        case .noise, .turbulence:
            let t = CGFloat(ProcessInfo.processInfo.systemUptime) * CGFloat(animationSpeed)
            let k = 1 / max(0.05, CGFloat(1 - smoothness)) * 0.02
            let n = CGPoint(x: sin(p.y * k + t * 1.3) + sin(p.x * k * 0.7 - t), y: cos(p.x * k + t * 0.9) + cos(p.y * k * 1.3 + t))
            force = _mul(n, s * fall * (kind == .turbulence ? _len(v) : 1))
        case .electric: force = _mul(u, s * charge * fall)
        case .magnetic: force = _mul(CGPoint(x: v.y, y: -v.x), s * charge * fall)
        case .custom:
            guard let e = evaluator else { return .zero }
            let r = e(vector_float3(Float(d.x), Float(d.y), 0), vector_float3(Float(vel.x), Float(vel.y), 0), Float(m), Float(charge), 1.0 / 60)
            force = CGPoint(x: CGFloat(r.x), y: CGFloat(r.y))
        }
        return _mul(_add(_mul(accel, m), force), _ptm)
    }
}

// MARK: - Ranges & constraints

@objc(SKRange) open class SKRange: NSObject {
    @objc open var lowerLimit: CGFloat
    @objc open var upperLimit: CGFloat
    @objc public init(lowerLimit lower: CGFloat, upperLimit upper: CGFloat) { lowerLimit = lower; upperLimit = upper }
    @objc public convenience init(lowerLimit lower: CGFloat) { self.init(lowerLimit: lower, upperLimit: .greatestFiniteMagnitude) }
    @objc public convenience init(upperLimit upper: CGFloat) { self.init(lowerLimit: -.greatestFiniteMagnitude, upperLimit: upper) }
    @objc public convenience init(constantValue v: CGFloat) { self.init(lowerLimit: v, upperLimit: v) }
    @objc public convenience init(value v: CGFloat, variance: CGFloat) { self.init(lowerLimit: v - variance, upperLimit: v + variance) }
    @objc(rangeWithNoLimits) open class func withNoLimits() -> SKRange { SKRange(lowerLimit: -.greatestFiniteMagnitude, upperLimit: .greatestFiniteMagnitude) }
    @objc open override func copy() -> Any { SKRange(lowerLimit: lowerLimit, upperLimit: upperLimit) }
    func clamp(_ v: CGFloat) -> CGFloat { min(max(v, lowerLimit), upperLimit) }
}

@objc(SKConstraint) open class SKConstraint: NSObject {
    @objc open var enabled = true
    @objc open var referenceNode: SKNode?
    let apply: (SKConstraint, SKNode) -> Void
    init(_ apply: @escaping (SKConstraint, SKNode) -> Void) { self.apply = apply }
    @objc open override func copy() -> Any { let c = SKConstraint(apply); c.enabled = enabled; c.referenceNode = referenceNode; return c }

    /// a point in `node`'s parent coordinates from `ref` space (nil = scene/parent space)
    static func toParent(_ p: CGPoint, of node: SKNode, from ref: SKNode?) -> CGPoint {
        guard let ref, let parent = node.parent else { return p }
        return parent.convert(p, from: ref)
    }
    static func fromParent(_ p: CGPoint, of node: SKNode, to ref: SKNode?) -> CGPoint {
        guard let ref, let parent = node.parent else { return p }
        return parent.convert(p, to: ref)
    }

    @objc open class func positionX(_ range: SKRange) -> SKConstraint { positionX(range, y: SKRange.withNoLimits()) }
    @objc open class func positionY(_ range: SKRange) -> SKConstraint { positionX(SKRange.withNoLimits(), y: range) }
    @objc(positionX:Y:) open class func positionX(_ xr: SKRange, y yr: SKRange) -> SKConstraint {
        SKConstraint { c, n in
            var p = fromParent(n.position, of: n, to: c.referenceNode)
            p.x = xr.clamp(p.x); p.y = yr.clamp(p.y)
            n.position = toParent(p, of: n, from: c.referenceNode)
        }
    }
    @objc open class func zRotation(_ range: SKRange) -> SKConstraint { SKConstraint { _, n in n.zRotation = range.clamp(n.zRotation) } }
    @objc open class func scaleX(_ range: SKRange) -> SKConstraint { SKConstraint { _, n in n.xScale = range.clamp(n.xScale) } }
    @objc open class func scaleY(_ range: SKRange) -> SKConstraint { SKConstraint { _, n in n.yScale = range.clamp(n.yScale) } }
    @objc(scaleX:scaleY:) open class func scaleX(_ xr: SKRange, y yr: SKRange) -> SKConstraint { SKConstraint { _, n in n.xScale = xr.clamp(n.xScale); n.yScale = yr.clamp(n.yScale) } }

    @objc(distance:toNode:) open class func distance(_ range: SKRange, to node: SKNode) -> SKConstraint { distance(range, to: .zero, in: node) }
    @objc(distance:toPoint:) open class func distance(_ range: SKRange, to point: CGPoint) -> SKConstraint {
        SKConstraint { c, n in clampDistance(n, target: toParent(point, of: n, from: c.referenceNode), range) }
    }
    @objc(distance:toPoint:inNode:) open class func distance(_ range: SKRange, to point: CGPoint, in node: SKNode) -> SKConstraint {
        SKConstraint { _, n in
            guard let parent = n.parent, node.scene != nil else { return }
            clampDistance(n, target: parent.convert(point, from: node), range)
        }
    }
    static func clampDistance(_ n: SKNode, target: CGPoint, _ range: SKRange) {
        let d = _sub(n.position, target), l = _len(d)
        let c = range.clamp(l)
        if abs(c - l) < 1e-9 { return }
        n.position = _add(target, _mul(l > 1e-9 ? _mul(d, 1 / l) : CGPoint(x: 1, y: 0), c))
    }

    @objc(orientToNode:offset:) open class func orient(to node: SKNode, offset: SKRange) -> SKConstraint { orient(to: .zero, in: node, offset: offset) }
    @objc(orientToPoint:offset:) open class func orient(to point: CGPoint, offset: SKRange) -> SKConstraint {
        SKConstraint { c, n in orient(n, toward: toParent(point, of: n, from: c.referenceNode), offset) }
    }
    @objc(orientToPoint:inNode:offset:) open class func orient(to point: CGPoint, in node: SKNode, offset: SKRange) -> SKConstraint {
        SKConstraint { _, n in
            guard let parent = n.parent, node.scene != nil else { return }
            orient(n, toward: parent.convert(point, from: node), offset)
        }
    }
    static func orient(_ n: SKNode, toward t: CGPoint, _ offset: SKRange) {
        let d = _sub(t, n.position)
        guard _len(d) > 1e-9 else { return }
        let base = atan2(d.y, d.x)
        // keep the node's rotation within the offset range around the direction (constant 0 points the +x axis at it)
        var rel = atan2(sin(n.zRotation - base), cos(n.zRotation - base))
        rel = offset.clamp(rel)
        n.zRotation = base + rel
    }
}

/// The angle limits of a joint for reach actions (SKInverseKinematics.swift).
@objc(SKReachConstraints) open class SKReachConstraints: NSObject {
    @objc open var lowerAngleLimit: CGFloat
    @objc open var upperAngleLimit: CGFloat
    @objc public init(lowerAngleLimit: CGFloat, upperAngleLimit: CGFloat) { self.lowerAngleLimit = lowerAngleLimit; self.upperAngleLimit = upperAngleLimit }
}

// MARK: - Reference node

@objc(SKReferenceNode) open class SKReferenceNode: SKNode {
    var fileName: String?
    var fileURL: URL?
    @objc public init(fileNamed name: String?) { fileName = name; super.init(); resolve() }
    @objc(initWithURL:) public init(url: URL?) { fileURL = url; super.init(); resolve() }
    @objc public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let c = coder as? _SKCoder, let n = c.string("fileName") ?? c.string("referenceFileName") { fileName = n; resolve() }
    }
    @objc(didLoadReferenceNode:) open func didLoad(_ node: SKNode?) {}
    @objc(resolveReferenceNode) open func resolve() {
        var loaded: SKNode?
        if let fileName { loaded = SKNode(fileNamed: fileName) }
        else if let fileURL {
            if let a = _SKArchive.load(url: fileURL), let root = a.rootUID { loaded = SKNode(coder: _SKCoder(archive: a, uid: root)) }
            else { NSLog("isim SpriteKit: SKReferenceNode: could not load %@", fileURL.path) }
        }
        if let loaded {
            removeAllChildren()
            for c in loaded.children { c.removeFromParent(); addChild(c) }
        }
        didLoad(loaded)
    }
}

// MARK: - Tile maps

public enum SKTileSetType: UInt, Sendable { case grid = 0, isometric, hexagonalFlat, hexagonalPointy }
/// which neighbours of a tile have the same tile group (automapping rules match it)
public struct SKTileAdjacencyMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let adjacencyUp = SKTileAdjacencyMask(rawValue: 1 << 0)
    public static let adjacencyUpperRight = SKTileAdjacencyMask(rawValue: 1 << 1)
    public static let adjacencyRight = SKTileAdjacencyMask(rawValue: 1 << 2)
    public static let adjacencyLowerRight = SKTileAdjacencyMask(rawValue: 1 << 3)
    public static let adjacencyDown = SKTileAdjacencyMask(rawValue: 1 << 4)
    public static let adjacencyLowerLeft = SKTileAdjacencyMask(rawValue: 1 << 5)
    public static let adjacencyLeft = SKTileAdjacencyMask(rawValue: 1 << 6)
    public static let adjacencyUpperLeft = SKTileAdjacencyMask(rawValue: 1 << 7)
    public static let adjacencyAll = SKTileAdjacencyMask(rawValue: 255)
    public static let adjacencyUpEdge = SKTileAdjacencyMask(rawValue: 124)
    public static let adjacencyUpperRightEdge = SKTileAdjacencyMask(rawValue: 112)
    public static let adjacencyRightEdge = SKTileAdjacencyMask(rawValue: 241)
    public static let adjacencyLowerRightEdge = SKTileAdjacencyMask(rawValue: 193)
    public static let adjacencyDownEdge = SKTileAdjacencyMask(rawValue: 199)
    public static let adjacencyLowerLeftEdge = SKTileAdjacencyMask(rawValue: 7)
    public static let adjacencyLeftEdge = SKTileAdjacencyMask(rawValue: 31)
    public static let adjacencyUpperLeftEdge = SKTileAdjacencyMask(rawValue: 28)
    public static let adjacencyUpperRightCorner = SKTileAdjacencyMask(rawValue: 223)
    public static let adjacencyLowerRightCorner = SKTileAdjacencyMask(rawValue: 127)
    public static let adjacencyLowerLeftCorner = SKTileAdjacencyMask(rawValue: 253)
    public static let adjacencyUpperLeftCorner = SKTileAdjacencyMask(rawValue: 247)
    public static let hexFlatAdjacencyUp = SKTileAdjacencyMask(rawValue: 1 << 0)
    public static let hexFlatAdjacencyUpperRight = SKTileAdjacencyMask(rawValue: 1 << 1)
    public static let hexFlatAdjacencyLowerRight = SKTileAdjacencyMask(rawValue: 1 << 2)
    public static let hexFlatAdjacencyDown = SKTileAdjacencyMask(rawValue: 1 << 3)
    public static let hexFlatAdjacencyLowerLeft = SKTileAdjacencyMask(rawValue: 1 << 4)
    public static let hexFlatAdjacencyUpperLeft = SKTileAdjacencyMask(rawValue: 1 << 5)
    public static let hexFlatAdjacencyAll = SKTileAdjacencyMask(rawValue: 63)
    public static let hexPointyAdjacencyUpperLeft = SKTileAdjacencyMask(rawValue: 1 << 0)
    public static let hexPointyAdjacencyUpperRight = SKTileAdjacencyMask(rawValue: 1 << 1)
    public static let hexPointyAdjacencyRight = SKTileAdjacencyMask(rawValue: 1 << 2)
    public static let hexPointyAdjacencyLowerRight = SKTileAdjacencyMask(rawValue: 1 << 3)
    public static let hexPointyAdjacencyLowerLeft = SKTileAdjacencyMask(rawValue: 1 << 4)
    public static let hexPointyAdjacencyLeft = SKTileAdjacencyMask(rawValue: 1 << 5)
    public static let hexPointyAdjacencyAdd = SKTileAdjacencyMask(rawValue: 63)
}
public enum SKTileDefinitionRotation: UInt, Sendable { case rotation0 = 0, rotation90, rotation180, rotation270 }

@objc(SKTileDefinition) open class SKTileDefinition: NSObject {
    @objc open var textures: [SKTexture]
    @objc open var normalTextures: [SKTexture] = []
    @objc open var userData: NSMutableDictionary?
    @objc open var name: String?
    @objc open var size: CGSize
    @objc open var timePerFrame: CGFloat = 0
    @objc open var placementWeight: Int = 1
    open var rotation: SKTileDefinitionRotation = .rotation0
    @objc open var flipVertically = false
    @objc open var flipHorizontally = false
    @objc public init(texture: SKTexture) { textures = [texture]; size = texture.size() }
    @objc public init(texture: SKTexture, size: CGSize) { textures = [texture]; self.size = size }
    @objc public init(texture: SKTexture, normalTexture: SKTexture, size: CGSize) { textures = [texture]; normalTextures = [normalTexture]; self.size = size }
    @objc public init(textures: [SKTexture], size: CGSize, timePerFrame: CGFloat) { self.textures = textures; self.size = size; self.timePerFrame = timePerFrame }
    @objc public init(textures: [SKTexture], normalTextures: [SKTexture], size: CGSize, timePerFrame: CGFloat) {
        self.textures = textures; self.normalTextures = normalTextures; self.size = size; self.timePerFrame = timePerFrame
    }
    @objc open override func copy() -> Any { self }
}

@objc(SKTileGroupRule) open class SKTileGroupRule: NSObject {
    open var adjacency: SKTileAdjacencyMask
    @objc open var tileDefinitions: [SKTileDefinition]
    @objc open var name: String?
    public init(adjacency: SKTileAdjacencyMask, tileDefinitions: [SKTileDefinition]) { self.adjacency = adjacency; self.tileDefinitions = tileDefinitions }
}

@objc(SKTileGroup) open class SKTileGroup: NSObject {
    @objc open var rules: [SKTileGroupRule]
    @objc open var name: String?
    @objc public init(tileDefinition: SKTileDefinition) { rules = [SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [tileDefinition])] }
    @objc public init(rules: [SKTileGroupRule]) { self.rules = rules }
    @objc(emptyTileGroup) open class func empty() -> SKTileGroup { SKTileGroup(rules: []) }
    /// the rule for a cell whose neighbours of the same group are `mask`: an exact match, else the one asking for
    /// the fewest more neighbours, else the first
    func rule(for mask: SKTileAdjacencyMask) -> SKTileGroupRule? {
        if let r = rules.first(where: { $0.adjacency == mask }) { return r }
        let supersets = rules.filter { $0.adjacency.isSuperset(of: mask) }
        return supersets.min { $0.adjacency.rawValue.nonzeroBitCount < $1.adjacency.rawValue.nonzeroBitCount } ?? rules.first
    }
    /// the definition drawn for a cell: weighted pick, stable per cell (from a rule: automapping)
    func definition(forCell i: Int, rule: SKTileGroupRule? = nil) -> SKTileDefinition? {
        let defs = (rule ?? rules.first)?.tileDefinitions ?? []
        guard !defs.isEmpty else { return nil }
        if defs.count == 1 { return defs[0] }
        let total = defs.reduce(0) { $0 + max(1, $1.placementWeight) }
        var k = (i &* 2654435761) % max(1, total)
        for d in defs { k -= max(1, d.placementWeight); if k < 0 { return d } }
        return defs[0]
    }
}

@objc(SKTileSet) open class SKTileSet: NSObject {
    @objc open var tileGroups: [SKTileGroup]
    @objc open var name: String?
    open var type: SKTileSetType = .grid
    @objc open var defaultTileGroup: SKTileGroup?
    @objc open var defaultTileSize: CGSize = CGSize(width: 32, height: 32)
    @objc public init(tileGroups: [SKTileGroup]) { self.tileGroups = tileGroups }
    public init(tileGroups: [SKTileGroup], tileSetType: SKTileSetType) { self.tileGroups = tileGroups; type = tileSetType }
    @objc public convenience init?(named name: String) { NSLog("isim SpriteKit: SKTileSet(named: %@): tile sets from .sks files are not supported", name); return nil }
}

@objc(SKTileMapNode) open class SKTileMapNode: SKNode {
    @objc open var numberOfColumns: Int { didSet { resize() } }
    @objc open var numberOfRows: Int { didSet { resize() } }
    @objc open var tileSize: CGSize
    @objc open var mapSize: CGSize {
        let C = CGFloat(numberOfColumns), R = CGFloat(numberOfRows), w = tileSize.width, h = tileSize.height
        switch tileSet.type {
        case .grid: return CGSize(width: C * w, height: R * h)
        case .isometric: return CGSize(width: (C + R) * w / 2, height: (C + R) * h / 2)
        case .hexagonalPointy: return CGSize(width: (C + 0.5) * w, height: (R * 0.75 + 0.25) * h)
        case .hexagonalFlat: return CGSize(width: (C * 0.75 + 0.25) * w, height: (R + 0.5) * h)
        }
    }
    @objc open var tileSet: SKTileSet
    @objc open var colorBlendFactor: CGFloat = 0
    @objc open var color: UIColor = .white
    open var blendMode: SKBlendMode = .alpha
    @objc open var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    @objc open var shader: SKShader?
    @objc open var lightingBitMask: UInt32 = 0
    @objc open var enableAutomapping = false
    var cells: [SKTileGroup?] = []
    /// the rule automapping chose for each cell
    var cellRules: [SKTileGroupRule?] = []
    var elapsed: CGFloat = 0

    @objc public init(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize) {
        self.tileSet = tileSet; numberOfColumns = columns; numberOfRows = rows; self.tileSize = tileSize
        super.init(); resize()
    }
    @objc(initWithTileSet:columns:rows:tileSize:fillWithTileGroup:) public convenience init(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize, fillWith g: SKTileGroup) {
        self.init(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize); fill(with: g)
    }
    @objc public convenience init(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize, tileGroupLayout: [SKTileGroup]) {
        self.init(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize)
        for (i, g) in tileGroupLayout.prefix(cells.count).enumerated() { cells[i] = g }
    }
    @objc public required init?(coder: NSCoder) {
        tileSet = SKTileSet(tileGroups: []); numberOfColumns = 0; numberOfRows = 0; tileSize = CGSize(width: 32, height: 32)
        super.init(coder: coder)
    }
    func resize() {
        let n = max(0, numberOfColumns * numberOfRows)
        if cells.count != n { cells = Array(cells.prefix(n)) + Array(repeating: nil, count: max(0, n - cells.count)) }
        if cellRules.count != n { cellRules = Array(repeating: nil, count: n) }
    }
    @objc(fillWithTileGroup:) open func fill(with g: SKTileGroup?) { for i in cells.indices { cells[i] = g }; if enableAutomapping { automapAll() } }
    @objc open func setTileGroup(_ g: SKTileGroup?, forColumn c: Int, row r: Int) {
        guard c >= 0, r >= 0, c < numberOfColumns, r < numberOfRows else { return }
        cells[r * numberOfColumns + c] = g
        if enableAutomapping { for dr in -1...1 { for dc in -1...1 { automap(c + dc, r + dr) } } }
    }
    /// neighbour offsets in the order of the adjacency bits (up, upper right, right, lower right, down, lower left, left, upper left)
    static let _neighbours = [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)]
    /// a cell's neighbours in the order of the adjacency bits of the map's layout: grid and isometric as above;
    /// hexagonal flat (odd columns half a tile up): up, upper right, lower right, down, lower left, upper left;
    /// hexagonal pointy (odd rows half a tile right): upper left, upper right, right, lower right, lower left, left
    func _neighbourOffsets(_ c: Int, _ r: Int) -> [(Int, Int)] {
        switch tileSet.type {
        case .grid, .isometric: return SKTileMapNode._neighbours
        case .hexagonalFlat:
            return c % 2 == 0 ? [(0, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0)]
                              : [(0, 1), (1, 1), (1, 0), (0, -1), (-1, 0), (-1, 1)]
        case .hexagonalPointy:
            return r % 2 == 0 ? [(-1, 1), (0, 1), (1, 0), (0, -1), (-1, -1), (-1, 0)]
                              : [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, 0)]
        }
    }
    /// automapping: the rule of a cell from which neighbours have the same group
    func automap(_ c: Int, _ r: Int) {
        guard c >= 0, r >= 0, c < numberOfColumns, r < numberOfRows, let g = cells[r * numberOfColumns + c] else {
            if c >= 0, r >= 0, c < numberOfColumns, r < numberOfRows { cellRules[r * numberOfColumns + c] = nil }
            return
        }
        var mask: UInt = 0
        for (bit, (dc, dr)) in _neighbourOffsets(c, r).enumerated() where tileGroup(atColumn: c + dc, row: r + dr) === g { mask |= 1 << UInt(bit) }
        cellRules[r * numberOfColumns + c] = g.rule(for: SKTileAdjacencyMask(rawValue: mask))
    }
    func automapAll() { for r in 0..<numberOfRows { for c in 0..<numberOfColumns { automap(c, r) } } }
    @objc open func setTileGroup(_ g: SKTileGroup, andTileDefinition d: SKTileDefinition, forColumn c: Int, row r: Int) { setTileGroup(g, forColumn: c, row: r) }
    @objc open func tileGroup(atColumn c: Int, row r: Int) -> SKTileGroup? {
        guard c >= 0, r >= 0, c < numberOfColumns, r < numberOfRows else { return nil }
        return cells[r * numberOfColumns + c]
    }
    @objc open func tileDefinition(atColumn c: Int, row r: Int) -> SKTileDefinition? {
        let i = r * numberOfColumns + c
        return tileGroup(atColumn: c, row: r)?.definition(forCell: i, rule: enableAutomapping && i < cellRules.count ? cellRules[i] : nil)
    }
    var origin: CGPoint { CGPoint(x: -anchorPoint.x * mapSize.width, y: -anchorPoint.y * mapSize.height) }
    /// a tile's center from the map's bottom-left corner, by layout: grid, isometric (a diamond: column up-right, row
    /// up-left), hexagonal flat (columns of hexagons, odd ones half a tile up) or pointy (rows, odd ones half a tile right)
    func _center(_ c: Int, _ r: Int) -> CGPoint {
        let w = tileSize.width, h = tileSize.height, C = CGFloat(c), R = CGFloat(r)
        switch tileSet.type {
        case .grid: return CGPoint(x: (C + 0.5) * w, y: (R + 0.5) * h)
        case .isometric: return CGPoint(x: (C - R) * w / 2 + CGFloat(numberOfRows) * w / 2, y: (C + R) * h / 2 + h / 2)
        case .hexagonalPointy: return CGPoint(x: (C + 0.5 + (r % 2 == 1 ? 0.5 : 0)) * w, y: (R * 0.75 + 0.5) * h)
        case .hexagonalFlat: return CGPoint(x: (C * 0.75 + 0.5) * w, y: (R + 0.5 + (c % 2 == 1 ? 0.5 : 0)) * h)
        }
    }
    /// the cell whose center is nearest a map point (from the bottom-left corner)
    func _cell(at q: CGPoint) -> (Int, Int) {
        let w = tileSize.width, h = tileSize.height
        var c0: Int, r0: Int
        switch tileSet.type {
        case .grid: return (Int(floor(q.x / w)), Int(floor(q.y / h)))
        case .isometric:
            let u = (q.x - CGFloat(numberOfRows) * w / 2) / (w / 2), v = (q.y - h / 2) / (h / 2)
            c0 = Int(((u + v) / 2).rounded()); r0 = Int(((v - u) / 2).rounded())
        case .hexagonalPointy: r0 = Int(((q.y / h - 0.5) / 0.75).rounded()); c0 = Int((q.x / w - 0.5).rounded())
        case .hexagonalFlat: c0 = Int(((q.x / w - 0.5) / 0.75).rounded()); r0 = Int((q.y / h - 0.5).rounded())
        }
        var best = (c0, r0), bd = CGFloat.greatestFiniteMagnitude
        for dr in -1...1 { for dc in -1...1 {
            let p = _center(c0 + dc, r0 + dr), d = _len(_sub(p, q))
            if d < bd { bd = d; best = (c0 + dc, r0 + dr) }
        } }
        return best
    }
    @objc open func tileColumnIndex(fromPosition p: CGPoint) -> Int { _cell(at: _sub(p, origin)).0 }
    @objc open func tileRowIndex(fromPosition p: CGPoint) -> Int { _cell(at: _sub(p, origin)).1 }
    @objc open func centerOfTile(atColumn c: Int, row r: Int) -> CGPoint { _add(origin, _center(c, r)) }
    override var contentRect: CGRect { CGRect(origin: origin, size: mapSize) }

    override func drawContent(alpha a: CGFloat) {
        let o = origin
        var tint = _rgba(color)
        let factor = Double(colorBlendFactor)
        isim_gfx_save()
        isim_gfx_set_blend(_hostBlend(blendMode))
        // back to front: on an isometric map the tiles further up (larger column + row) are behind
        var order: [(Int, Int)] = []
        for r in 0..<numberOfRows { for c in 0..<numberOfColumns { order.append((c, r)) } }
        if tileSet.type == .isometric { order.sort { ($0.0 + $0.1) > ($1.0 + $1.1) } }
        for (c, r) in order {
            do {
                guard let d = tileDefinition(atColumn: c, row: r), !d.textures.isEmpty else { continue }
                let frame = d.timePerFrame > 0 ? Int(elapsed / d.timePerFrame) % d.textures.count : 0
                let t = d.textures[frame]
                guard t.handle > 0 else { continue }
                let ctr = _add(o, _center(c, r)), cx = ctr.x, cy = ctr.y
                let w = d.size.width, h = d.size.height
                isim_gfx_save()
                isim_gfx_translate(cx, cy)
                if d.rotation != .rotation0 { isim_gfx_rotate(CGFloat(d.rotation.rawValue) * .pi / 2) }
                isim_gfx_scale(d.flipHorizontally ? -1 : 1, d.flipVertically ? 1 : -1)
                tint.withUnsafeMutableBufferPointer { b in
                    isim_image_draw_part(t.handle, t.pixels.minX, t.pixels.minY, t.pixels.width, t.pixels.height, -w / 2, -h / 2, w, h,
                                         t.filteringMode == .nearest ? 1 : 0, factor > 0 ? b.baseAddress : nil, factor, Double(a))
                }
                isim_gfx_restore()
            }
        }
        isim_gfx_restore()
    }
}
