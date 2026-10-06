// isim SpriteKit physics: SKPhysicsWorld / SKPhysicsBody / SKPhysicsContact / joints / SKFieldNode on a small
// impulse-based 2D rigid body solver (circles, convex polygons, edges; SAT + clipping for polygon manifolds;
// sequential impulses with friction and restitution, speculative contacts, split position correction).
// Units follow SpriteKit: positions in points, gravity and forces in meters (150 points per meter), mass in kg
// from density x area (area in square meters).
import Foundation
import isim_host

let _ptm: CGFloat = 150

// MARK: - vector helpers

@inline(__always) func _add(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
@inline(__always) func _sub(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
@inline(__always) func _mul(_ a: CGPoint, _ k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
@inline(__always) func _dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.x + a.y * b.y }
@inline(__always) func _cross(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.y - a.y * b.x }
@inline(__always) func _crossSV(_ s: CGFloat, _ v: CGPoint) -> CGPoint { CGPoint(x: -s * v.y, y: s * v.x) }
@inline(__always) func _len(_ a: CGPoint) -> CGFloat { (a.x * a.x + a.y * a.y).squareRoot() }
@inline(__always) func _norm(_ a: CGPoint) -> CGPoint { let l = _len(a); return l > 1e-9 ? CGPoint(x: a.x / l, y: a.y / l) : CGPoint(x: 0, y: 1) }
@inline(__always) func _rot(_ p: CGPoint, _ c: CGFloat, _ s: CGFloat) -> CGPoint { CGPoint(x: c * p.x - s * p.y, y: s * p.x + c * p.y) }

/// points of a path, flattened (curves sampled)
func _pathPoints(_ path: CGPath) -> [[CGPoint]] {
    var subpaths: [[CGPoint]] = [], cur: [CGPoint] = []
    var last = CGPoint.zero
    path.applyWithBlock { e in
        let p = e.pointee.points
        switch e.pointee.type {
        case .moveToPoint:
            if cur.count > 1 { subpaths.append(cur) }
            cur = [p[0]]; last = p[0]
        case .addLineToPoint: cur.append(p[0]); last = p[0]
        case .addQuadCurveToPoint:
            let c0 = last, c1 = p[0], c2 = p[1]
            for i in 1...8 { cur.append(_quad(c0, c1, c2, CGFloat(i) / 8)) }
            last = c2
        case .addCurveToPoint:
            let c0 = last, c1 = p[0], c2 = p[1], c3 = p[2]
            for i in 1...10 { cur.append(_cubic(c0, c1, c2, c3, CGFloat(i) / 10)) }
            last = c3
        case .closeSubpath:
            if let f = cur.first, cur.count > 1 { if cur.last != f { cur.append(f) } }
        @unknown default: break
        }
    }
    if cur.count > 1 { subpaths.append(cur) }
    return subpaths
}

func _quad(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let a: CGFloat = u * u, b: CGFloat = 2 * u * t, c: CGFloat = t * t
    return _add(_add(_mul(p0, a), _mul(p1, b)), _mul(p2, c))
}
func _cubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let a: CGFloat = u * u * u, b: CGFloat = 3 * u * u * t, c: CGFloat = 3 * u * t * t, d: CGFloat = t * t * t
    return _add(_add(_mul(p0, a), _mul(p1, b)), _add(_mul(p2, c), _mul(p3, d)))
}

/// convex hull, counter-clockwise (monotone chain)
func _convexHull(_ pts: [CGPoint]) -> [CGPoint] {
    let s = pts.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
    guard s.count >= 3 else { return s }
    var lower: [CGPoint] = [], upper: [CGPoint] = []
    for q in s {
        while lower.count >= 2 && _cross(_sub(lower[lower.count - 1], lower[lower.count - 2]), _sub(q, lower[lower.count - 2])) <= 1e-9 { lower.removeLast() }
        lower.append(q)
    }
    for q in s.reversed() {
        while upper.count >= 2 && _cross(_sub(upper[upper.count - 1], upper[upper.count - 2]), _sub(q, upper[upper.count - 2])) <= 1e-9 { upper.removeLast() }
        upper.append(q)
    }
    return Array(lower.dropLast() + upper.dropLast())
}

// MARK: - Shapes

enum _PShape {
    case circle(CGPoint, CGFloat)
    case polygon([CGPoint])          // convex, counter-clockwise
    case segment(CGPoint, CGPoint)   // edges (always static)
}

/// a shape in scene coordinates for one step
struct _WShape {
    var kind: Int                   // 0 circle, 1 polygon, 2 segment
    var center = CGPoint.zero, radius: CGFloat = 0
    var verts: [CGPoint] = [], normals: [CGPoint] = []
    var minX: CGFloat = 0, minY: CGFloat = 0, maxX: CGFloat = 0, maxY: CGFloat = 0
}

// MARK: - Physics body

open class SKPhysicsBody: NSObject {
    var shapes: [_PShape]
    var isEdge = false
    var areaPoints: CGFloat = 0     // in points^2
    var localCentroid = CGPoint.zero
    var unitInertia: CGFloat = 0    // inertia about the centroid per unit mass (points^2)

    open var isDynamic = true { didSet { if isEdge { isDynamic = false } } }
    open var usesPreciseCollisionDetection = false
    open var allowsRotation = true
    open var pinned = false
    open var isResting = false
    open var friction: CGFloat = 0.2
    open var charge: CGFloat = 0
    open var restitution: CGFloat = 0.2
    open var linearDamping: CGFloat = 0.1
    open var angularDamping: CGFloat = 0.1
    open var density: CGFloat = 1 { didSet { massOverride = nil } }
    var massOverride: CGFloat?
    open var mass: CGFloat {
        get { massOverride ?? density * area }
        set { let a = area; if a > 0 { density = newValue / a }; massOverride = newValue }
    }
    /// in square meters
    open var area: CGFloat { areaPoints / (_ptm * _ptm) }
    open var affectedByGravity = true
    open var fieldBitMask: UInt32 = 0xFFFF_FFFF
    open var categoryBitMask: UInt32 = 0xFFFF_FFFF
    open var collisionBitMask: UInt32 = 0xFFFF_FFFF
    open var contactTestBitMask: UInt32 = 0
    open internal(set) weak var node: SKNode?
    open var joints: [SKPhysicsJoint] { _joints.compactMap { $0.value } }
    var _joints: [_WeakJoint] = []
    open var velocity = CGVector.zero
    open var angularVelocity: CGFloat = 0

    // simulation state (scene space)
    var com = CGPoint.zero          // center of mass
    var angle: CGFloat = 0
    var force = CGPoint.zero        // internal units (points)
    var torque: CGFloat = 0
    var invMass: CGFloat = 0, invI: CGFloat = 0
    var world: [_WShape] = []
    var lastNodePos: CGPoint?, lastNodeAngle: CGFloat?
    var restTime: CGFloat = 0
    var wasPlaced = false
    var touching: Set<ObjectIdentifier> = []

    init(shapes: [_PShape], edge: Bool) {
        self.shapes = shapes; isEdge = edge
        super.init()
        if edge { isDynamic = false }
        computeMassProperties()
    }
    public override init() { shapes = []; super.init() }

    public convenience init(circleOfRadius r: CGFloat) { self.init(circleOfRadius: r, center: .zero) }
    public convenience init(circleOfRadius r: CGFloat, center: CGPoint) { self.init(shapes: [.circle(center, max(r, 0.001))], edge: false) }
    public convenience init(rectangleOf s: CGSize) { self.init(rectangleOf: s, center: .zero) }
    public convenience init(rectangleOf s: CGSize, center c: CGPoint) {
        let w = s.width / 2, h = s.height / 2
        self.init(shapes: [.polygon([CGPoint(x: c.x - w, y: c.y - h), CGPoint(x: c.x + w, y: c.y - h), CGPoint(x: c.x + w, y: c.y + h), CGPoint(x: c.x - w, y: c.y + h)])], edge: false)
    }
    /// A convex polygon from a path (concave paths use their convex hull, as an approximation).
    public convenience init(polygonFrom path: CGPath) {
        let hull = _convexHull(_pathPoints(path).flatMap { $0 })
        if hull.count >= 3 { self.init(shapes: [.polygon(hull)], edge: false) }
        else { let b = path.boundingBox; self.init(rectangleOf: b.size, center: CGPoint(x: b.midX, y: b.midY)) }
    }
    public convenience init(edgeFrom p1: CGPoint, to p2: CGPoint) { self.init(shapes: [.segment(p1, p2)], edge: true) }
    public convenience init(edgeChainFrom path: CGPath) {
        var segs: [_PShape] = []
        for sp in _pathPoints(path) { for i in 1..<sp.count where sp[i] != sp[i - 1] { segs.append(.segment(sp[i - 1], sp[i])) } }
        self.init(shapes: segs, edge: true)
    }
    public convenience init(edgeLoopFrom path: CGPath) {
        var segs: [_PShape] = []
        for sp in _pathPoints(path) {
            for i in 1..<sp.count where sp[i] != sp[i - 1] { segs.append(.segment(sp[i - 1], sp[i])) }
            if let f = sp.first, let l = sp.last, f != l { segs.append(.segment(l, f)) }
        }
        self.init(shapes: segs, edge: true)
    }
    public convenience init(edgeLoopFrom r: CGRect) { self.init(edgeLoopFrom: CGPath(rect: r, transform: nil)) }
    /// Texture outlines are approximated by the texture's opaque bounding rectangle (isim does not trace alpha).
    public convenience init(texture: SKTexture, size: CGSize) { self.init(rectangleOf: size) }
    public convenience init(texture: SKTexture, alphaThreshold: Float, size: CGSize) { self.init(rectangleOf: size) }
    public convenience init(bodies: [SKPhysicsBody]) {
        self.init(shapes: bodies.flatMap { $0.shapes }, edge: bodies.allSatisfy { $0.isEdge } && !bodies.isEmpty)
    }

    open override func copy() -> Any {
        let b = SKPhysicsBody(shapes: shapes, edge: isEdge)
        b.isDynamic = isDynamic; b.usesPreciseCollisionDetection = usesPreciseCollisionDetection; b.allowsRotation = allowsRotation
        b.pinned = pinned; b.friction = friction; b.charge = charge; b.restitution = restitution; b.linearDamping = linearDamping
        b.angularDamping = angularDamping; b.density = density; b.massOverride = massOverride; b.affectedByGravity = affectedByGravity
        b.fieldBitMask = fieldBitMask; b.categoryBitMask = categoryBitMask; b.collisionBitMask = collisionBitMask
        b.contactTestBitMask = contactTestBitMask; b.velocity = velocity; b.angularVelocity = angularVelocity
        return b
    }

    func computeMassProperties() {
        var area: CGFloat = 0, cx: CGFloat = 0, cy: CGFloat = 0, inertia: CGFloat = 0   // inertia about the origin, per unit density
        for s in shapes {
            switch s {
            case .circle(let c, let r):
                let a = .pi * r * r
                area += a; cx += a * c.x; cy += a * c.y
                inertia += a * (r * r / 2 + _dot(c, c))
            case .polygon(let v):
                for i in 0..<v.count {
                    let p1 = v[i], p2 = v[(i + 1) % v.count]
                    let cr = _cross(p1, p2), a = cr / 2
                    area += a
                    cx += a * (p1.x + p2.x) / 3; cy += a * (p1.y + p2.y) / 3
                    inertia += cr / 12 * (_dot(p1, p1) + _dot(p1, p2) + _dot(p2, p2))
                }
            case .segment: break
            }
        }
        areaPoints = abs(area)
        if area != 0 {
            localCentroid = CGPoint(x: cx / area, y: cy / area)
            unitInertia = max(0, abs(inertia) / abs(area) - _dot(localCentroid, localCentroid))
        }
    }

    // forces (Newtons / meters, as in SpriteKit)
    open func applyForce(_ f: CGVector) { force.x += f.dx * _ptm; force.y += f.dy * _ptm }
    open func applyForce(_ f: CGVector, at p: CGPoint) {
        applyForce(f)
        torque += _cross(_sub(p, com), CGPoint(x: f.dx * _ptm, y: f.dy * _ptm))
    }
    open func applyTorque(_ t: CGFloat) { torque += t * _ptm * _ptm }
    open func applyImpulse(_ j: CGVector) {
        guard isDynamic, mass > 0 else { return }
        velocity.dx += j.dx * _ptm / mass; velocity.dy += j.dy * _ptm / mass
        isResting = false; restTime = 0
    }
    open func applyImpulse(_ j: CGVector, at p: CGPoint) {
        applyImpulse(j)
        guard isDynamic, allowsRotation else { return }
        let I = inertiaInternal
        if I > 0 { angularVelocity += _cross(_sub(p, com), CGPoint(x: j.dx * _ptm, y: j.dy * _ptm)) / I }
    }
    open func applyAngularImpulse(_ j: CGFloat) {
        guard isDynamic, allowsRotation else { return }
        let I = inertiaInternal
        if I > 0 { angularVelocity += j * _ptm * _ptm / I }
        isResting = false; restTime = 0
    }
    var inertiaInternal: CGFloat { mass * unitInertia }

    /// bodies currently touching this one
    open func allContactedBodies() -> [SKPhysicsBody] {
        guard let w = node?.scene?.physicsWorld else { return [] }
        return w.lastBodies.filter { touching.contains(ObjectIdentifier($0)) }
    }
    open override var description: String {
        var kind = "Polygon"
        if isEdge { kind = "Edge" } else if case .circle? = shapes.first { kind = "Circle" }
        return "<SKPhysicsBody> type:<\(kind)> representedObject:[\(node?.name ?? node.map { "\(type(of: $0))" } ?? "nil")]"
    }

    // MARK: per-step world geometry
    func updateWorldShapes() {
        let c = cos(angle), s = sin(angle)
        let origin = _sub(com, _rot(localCentroid, c, s))
        world.removeAll(keepingCapacity: true)
        for sh in shapes {
            var w: _WShape
            switch sh {
            case .circle(let cc, let r):
                w = _WShape(kind: 0); w.center = _add(origin, _rot(cc, c, s)); w.radius = r
                w.minX = w.center.x - r; w.maxX = w.center.x + r; w.minY = w.center.y - r; w.maxY = w.center.y + r
            case .polygon(let v):
                w = _WShape(kind: 1); w.verts = v.map { _add(origin, _rot($0, c, s)) }
                for i in 0..<w.verts.count {
                    let e = _sub(w.verts[(i + 1) % w.verts.count], w.verts[i])
                    w.normals.append(_norm(CGPoint(x: e.y, y: -e.x)))
                }
                w.minX = w.verts.map(\.x).min()!; w.maxX = w.verts.map(\.x).max()!; w.minY = w.verts.map(\.y).min()!; w.maxY = w.verts.map(\.y).max()!
                var cen = CGPoint.zero
                for q in w.verts { cen = _add(cen, q) }
                w.center = _mul(cen, 1 / CGFloat(w.verts.count))
            case .segment(let a, let b):
                w = _WShape(kind: 2); w.verts = [_add(origin, _rot(a, c, s)), _add(origin, _rot(b, c, s))]
                let e = _sub(w.verts[1], w.verts[0])
                let n = _norm(CGPoint(x: e.y, y: -e.x))
                w.normals = [n, CGPoint(x: -n.x, y: -n.y)]
                w.minX = min(w.verts[0].x, w.verts[1].x); w.maxX = max(w.verts[0].x, w.verts[1].x)
                w.minY = min(w.verts[0].y, w.verts[1].y); w.maxY = max(w.verts[0].y, w.verts[1].y)
                w.center = _mul(_add(w.verts[0], w.verts[1]), 0.5)
            }
            world.append(w)
        }
    }
    var aabb: CGRect {
        guard !world.isEmpty else { return .null }
        var r = CGRect(x: world[0].minX, y: world[0].minY, width: world[0].maxX - world[0].minX, height: world[0].maxY - world[0].minY)
        for w in world.dropFirst() { r = r.union(CGRect(x: w.minX, y: w.minY, width: w.maxX - w.minX, height: w.maxY - w.minY)) }
        return r
    }
    /// smallest extent, for choosing substeps (tunneling)
    var minExtent: CGFloat {
        var m = CGFloat.greatestFiniteMagnitude
        for w in world { m = min(m, w.kind == 0 ? 2 * w.radius : min(w.maxX - w.minX, w.maxY - w.minY)) }
        return max(m, 1)
    }
    func containsPoint(_ p: CGPoint) -> Bool {
        for w in world {
            switch w.kind {
            case 0: if _len(_sub(p, w.center)) <= w.radius { return true }
            case 1:
                var inside = true
                for i in 0..<w.verts.count where _dot(_sub(p, w.verts[i]), w.normals[i]) > 0 { inside = false; break }
                if inside { return true }
            default:
                if _len(_sub(p, _closestOnSegment(p, w.verts[0], w.verts[1]))) < 0.5 { return true }
            }
        }
        return false
    }
}

final class _WeakJoint { weak var value: SKPhysicsJoint?; init(_ j: SKPhysicsJoint) { value = j } }

func _closestOnSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
    let e = _sub(b, a), l2 = _dot(e, e)
    if l2 < 1e-12 { return a }
    let t = max(0, min(1, _dot(_sub(p, a), e) / l2))
    return _add(a, _mul(e, t))
}

// MARK: - Contact

open class SKPhysicsContact: NSObject {
    open internal(set) var bodyA: SKPhysicsBody
    open internal(set) var bodyB: SKPhysicsBody
    open internal(set) var contactPoint: CGPoint
    open internal(set) var contactNormal: CGVector
    open internal(set) var collisionImpulse: CGFloat
    init(a: SKPhysicsBody, b: SKPhysicsBody, point: CGPoint, normal: CGVector, impulse: CGFloat) {
        bodyA = a; bodyB = b; contactPoint = point; contactNormal = normal; collisionImpulse = impulse
    }
    open override var description: String { "<SKPhysicsContact> \(bodyA) <-> \(bodyB) at \(contactPoint)" }
}

public protocol SKPhysicsContactDelegate: NSObjectProtocol {
    func didBegin(_ contact: SKPhysicsContact)
    func didEnd(_ contact: SKPhysicsContact)
}
extension SKPhysicsContactDelegate {
    public func didBegin(_ contact: SKPhysicsContact) {}
    public func didEnd(_ contact: SKPhysicsContact) {}
}

// MARK: - Manifolds

struct _Contact {
    var p: CGPoint
    var sep: CGFloat               // separation (negative = penetration)
    var rA = CGPoint.zero, rB = CGPoint.zero
    var mN: CGFloat = 0, mT: CGFloat = 0
    var jn: CGFloat = 0, jt: CGFloat = 0
    var bounce: CGFloat = 0
}
struct _Manifold {
    var a: SKPhysicsBody, b: SKPhysicsBody
    var n: CGPoint                  // from a to b
    var contacts: [_Contact]
    var friction: CGFloat = 0, restitution: CGFloat = 0
    var collide = true
    // inverse mass / inertia as seen by this contact (0 for a body its collision mask does not affect)
    var ima: CGFloat = 0, iia: CGFloat = 0, imb: CGFloat = 0, iib: CGFloat = 0
    func apply(_ p: CGPoint, _ rA: CGPoint, _ rB: CGPoint) {
        a.velocity.dx -= p.x * ima; a.velocity.dy -= p.y * ima
        a.angularVelocity -= iia * _cross(rA, p)
        b.velocity.dx += p.x * imb; b.velocity.dy += p.y * imb
        b.angularVelocity += iib * _cross(rB, p)
    }
}

enum _Collide {
    /// contacts between two world shapes (normal from s1 to s2), including speculative ones within `margin`
    static func shapes(_ s1: _WShape, _ s2: _WShape, margin: CGFloat) -> (CGPoint, [(CGPoint, CGFloat)])? {
        if s1.maxX + margin < s2.minX || s2.maxX + margin < s1.minX || s1.maxY + margin < s2.minY || s2.maxY + margin < s1.minY { return nil }
        switch (s1.kind, s2.kind) {
        case (0, 0): return circles(s1, s2, margin)
        case (0, _): return flip(polyCircle(s2, s1, margin))
        case (_, 0): return polyCircle(s1, s2, margin)
        case (2, 2): return nil
        default: return polygons(s1, s2, margin)
        }
    }
    static func flip(_ r: (CGPoint, [(CGPoint, CGFloat)])?) -> (CGPoint, [(CGPoint, CGFloat)])? {
        r.map { (CGPoint(x: -$0.0.x, y: -$0.0.y), $0.1) }
    }
    static func circles(_ a: _WShape, _ b: _WShape, _ margin: CGFloat) -> (CGPoint, [(CGPoint, CGFloat)])? {
        let d = _sub(b.center, a.center), dist = _len(d)
        let sep = dist - a.radius - b.radius
        guard sep < margin else { return nil }
        let n = dist > 1e-9 ? _mul(d, 1 / dist) : CGPoint(x: 0, y: 1)
        let p = _add(a.center, _mul(n, a.radius + sep / 2))
        return (n, [(p, sep)])
    }
    /// polygon or segment (a) vs circle (b)
    static func polyCircle(_ a: _WShape, _ b: _WShape, _ margin: CGFloat) -> (CGPoint, [(CGPoint, CGFloat)])? {
        let c = b.center
        if a.kind == 2 {
            let q = _closestOnSegment(c, a.verts[0], a.verts[1])
            let d = _sub(c, q), dist = _len(d)
            let sep = dist - b.radius
            guard sep < margin else { return nil }
            var n = dist > 1e-9 ? _mul(d, 1 / dist) : a.normals[0]
            if dist <= 1e-9, _dot(_sub(c, a.center), n) < 0 { n = a.normals[1] }
            return (n, [(_add(q, _mul(n, sep / 2)), sep)])
        }
        // max separation face
        var best = -CGFloat.greatestFiniteMagnitude, bi = 0
        for i in 0..<a.verts.count {
            let s = _dot(_sub(c, a.verts[i]), a.normals[i])
            if s > best { best = s; bi = i }
        }
        if best > b.radius + margin { return nil }
        if best < 1e-6 {   // center inside the polygon
            let n = a.normals[bi]
            let sep = best - b.radius
            return (n, [(_sub(c, _mul(n, b.radius + sep / 2)), sep)])
        }
        let v1 = a.verts[bi], v2 = a.verts[(bi + 1) % a.verts.count]
        let q = _closestOnSegment(c, v1, v2)
        let d = _sub(c, q), dist = _len(d)
        let sep = dist - b.radius
        guard sep < margin else { return nil }
        let n = dist > 1e-9 ? _mul(d, 1 / dist) : a.normals[bi]
        return (n, [(_add(q, _mul(n, sep / 2)), sep)])
    }
    static func maxSeparation(_ a: _WShape, _ b: _WShape) -> (CGFloat, Int) {
        var best = -CGFloat.greatestFiniteMagnitude, bi = 0
        for i in 0..<a.normals.count {
            let n = a.normals[i], v = a.verts[i % a.verts.count]
            var m = CGFloat.greatestFiniteMagnitude
            for w in b.verts { m = min(m, _dot(_sub(w, v), n)) }
            if m > best { best = m; bi = i }
        }
        return (best, bi)
    }
    /// convex polygons / segments (segments are two-sided 2-vertex polygons)
    static func polygons(_ a: _WShape, _ b: _WShape, _ margin: CGFloat) -> (CGPoint, [(CGPoint, CGFloat)])? {
        let (sa, ia) = maxSeparation(a, b)
        if sa > margin { return nil }
        let (sb, ib) = maxSeparation(b, a)
        if sb > margin { return nil }
        let flipped = sb > sa + 0.05
        let ref = flipped ? b : a, inc = flipped ? a : b
        let ri = flipped ? ib : ia
        let n = ref.normals[ri]
        let rv1: CGPoint, rv2: CGPoint
        if ref.kind == 2 { rv1 = ri == 0 ? ref.verts[0] : ref.verts[1]; rv2 = ri == 0 ? ref.verts[1] : ref.verts[0] }
        else { rv1 = ref.verts[ri]; rv2 = ref.verts[(ri + 1) % ref.verts.count] }
        // incident edge: most anti-parallel normal
        var mi = 0, md = CGFloat.greatestFiniteMagnitude
        for i in 0..<inc.normals.count { let d = _dot(inc.normals[i], n); if d < md { md = d; mi = i } }
        var iv1: CGPoint, iv2: CGPoint
        if inc.kind == 2 { iv1 = mi == 0 ? inc.verts[0] : inc.verts[1]; iv2 = mi == 0 ? inc.verts[1] : inc.verts[0] }
        else { iv1 = inc.verts[mi]; iv2 = inc.verts[(mi + 1) % inc.verts.count] }
        // clip against the reference edge's side planes
        let t = _norm(_sub(rv2, rv1))
        func clip(_ p1: CGPoint, _ p2: CGPoint, _ nrm: CGPoint, _ off: CGFloat) -> [CGPoint] {
            let d1 = _dot(nrm, p1) - off, d2 = _dot(nrm, p2) - off
            var out: [CGPoint] = []
            if d1 <= 0 { out.append(p1) }
            if d2 <= 0 { out.append(p2) }
            if d1 * d2 < 0 { out.append(_add(p1, _mul(_sub(p2, p1), d1 / (d1 - d2)))) }
            return out
        }
        var pts = clip(iv1, iv2, CGPoint(x: -t.x, y: -t.y), -_dot(t, rv1))
        guard pts.count >= 2 else { return nil }
        pts = clip(pts[0], pts[1], t, _dot(t, rv2))
        guard pts.count >= 2 else { return nil }
        var out: [(CGPoint, CGFloat)] = []
        for p in pts.prefix(2) {
            let sep = _dot(_sub(p, rv1), n)
            if sep < margin { out.append((_sub(p, _mul(n, sep / 2)), sep)) }
        }
        if out.isEmpty { return nil }
        return (flipped ? CGPoint(x: -n.x, y: -n.y) : n, out)
    }
}

// MARK: - World

open class SKPhysicsWorld: NSObject {
    open var gravity = CGVector(dx: 0, dy: -9.8)
    open var speed: CGFloat = 1
    open weak var contactDelegate: AnyObject?
    var jointList: [SKPhysicsJoint] = []
    var lastBodies: [SKPhysicsBody] = []
    var touchingPairs: [_PairKey: (SKPhysicsBody, SKPhysicsBody)] = [:]
    weak var scene: SKScene?

    open func add(_ joint: SKPhysicsJoint) {
        guard !jointList.contains(where: { $0 === joint }) else { return }
        jointList.append(joint)
        joint.prepare()
        joint.bodyA.map { $0._joints.append(_WeakJoint(joint)) }
        joint.bodyB.map { $0._joints.append(_WeakJoint(joint)) }
    }
    open func remove(_ joint: SKPhysicsJoint) {
        jointList.removeAll { $0 === joint }
        joint.bodyA?._joints.removeAll { $0.value === joint || $0.value == nil }
        joint.bodyB?._joints.removeAll { $0.value === joint || $0.value == nil }
    }
    open func removeAllJoints() { for j in jointList { remove(j) } }

    open func body(at p: CGPoint) -> SKPhysicsBody? { lastBodies.first { $0.containsPoint(p) } }
    open func body(in r: CGRect) -> SKPhysicsBody? { lastBodies.first { $0.aabb.intersects(r) } }
    open func enumerateBodies(at p: CGPoint, using block: (SKPhysicsBody, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        for b in lastBodies where b.containsPoint(p) { block(b, &stop); if stop.boolValue { return } }
    }
    open func enumerateBodies(in r: CGRect, using block: (SKPhysicsBody, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        for b in lastBodies where b.aabb.intersects(r) { block(b, &stop); if stop.boolValue { return } }
    }
    /// ray casts: bodies whose shapes the segment crosses, nearest first
    open func enumerateBodies(alongRayStart start: CGPoint, end: CGPoint,
                              using block: (SKPhysicsBody, CGPoint, CGVector, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        for (b, p, n) in rayHits(start, end) { block(b, p, n, &stop); if stop.boolValue { return } }
    }
    open func body(alongRayStart start: CGPoint, end: CGPoint) -> SKPhysicsBody? { rayHits(start, end).first?.0 }

    func rayHits(_ s: CGPoint, _ e: CGPoint) -> [(SKPhysicsBody, CGPoint, CGVector)] {
        var hits: [(CGFloat, SKPhysicsBody, CGPoint, CGVector)] = []
        let d = _sub(e, s)
        for b in lastBodies {
            var best: (CGFloat, CGPoint)?
            for w in b.world {
                switch w.kind {
                case 0:
                    let f = _sub(s, w.center)
                    let A = _dot(d, d), B = 2 * _dot(f, d), C = _dot(f, f) - w.radius * w.radius
                    let disc = B * B - 4 * A * C
                    if A > 0, disc >= 0 {
                        let t = (-B - disc.squareRoot()) / (2 * A)
                        if t >= 0, t <= 1, best == nil || t < best!.0 { best = (t, _norm(_sub(_add(s, _mul(d, t)), w.center))) }
                    }
                default:
                    let n = w.kind == 2 ? 1 : w.verts.count
                    for i in 0..<n {
                        let p = w.verts[i], q = w.verts[(i + 1) % w.verts.count], r = _sub(q, p)
                        let den = _cross(d, r)
                        if abs(den) < 1e-12 { continue }
                        let t = _cross(_sub(p, s), r) / den, u = _cross(_sub(p, s), d) / den
                        if t >= 0, t <= 1, u >= 0, u <= 1, best == nil || t < best!.0 {
                            var nn = w.normals[i]
                            if _dot(nn, d) > 0 { nn = CGPoint(x: -nn.x, y: -nn.y) }
                            best = (t, nn)
                        }
                    }
                }
            }
            if let (t, n) = best { hits.append((t, b, _add(s, _mul(d, t)), CGVector(dx: n.x, dy: n.y))) }
        }
        return hits.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2, $0.3) }
    }

    // MARK: simulation

    func collectBodies(_ n: SKNode, _ out: inout [SKPhysicsBody], _ fields: inout [SKFieldNode]) {
        if let b = n.physicsBody, !(n is SKScene && n !== scene) { b.node = n; out.append(b) }
        if let f = n as? SKFieldNode { fields.append(f) }
        for c in n.children { collectBodies(c, &out, &fields) }
    }

    /// node -> body state (bodies follow nodes that were moved by code or actions)
    func pull(_ b: SKPhysicsBody, _ dt: CGFloat) {
        guard let n = b.node, let parent = n.parent else { return }
        let pt = parent === scene ? .identity : parent.sceneTransform
        let pos = n.position.applying(pt)
        let ang = n.zRotation + atan2(pt.b, pt.a)
        let moved = b.lastNodePos.map { _len(_sub($0, pos)) > 1e-4 } ?? true
        let turned = b.lastNodeAngle.map { abs($0 - ang) > 1e-6 } ?? true
        let newCom = _add(pos, _rot(b.localCentroid, cos(ang), sin(ang)))
        if !b.wasPlaced {
            b.com = newCom; b.angle = ang; b.wasPlaced = true
            if !b.isDynamic { b.velocity = .zero; b.angularVelocity = 0 }
        } else if moved || turned {
            if !b.isDynamic && dt > 0 {
                // a static body moved by code or actions sweeps to its new place during the frame, pushing others
                b.velocity = CGVector(dx: (newCom.x - b.com.x) / dt, dy: (newCom.y - b.com.y) / dt)
                b.angularVelocity = (ang - b.angle) / dt
            } else { b.com = newCom; b.angle = ang }
            b.isResting = false; b.restTime = 0
        } else if !b.isDynamic {
            b.velocity = .zero; b.angularVelocity = 0
        }
        if !b.isDynamic { b.lastNodePos = pos; b.lastNodeAngle = ang }
        if b.pinned { b.velocity = .zero }
    }
    /// body state -> node
    func push(_ b: SKPhysicsBody) {
        guard let n = b.node, let parent = n.parent else { return }
        let c = cos(b.angle), s = sin(b.angle)
        let origin = _sub(b.com, _rot(b.localCentroid, c, s))
        let pt = parent === scene ? CGAffineTransform.identity : parent.sceneTransform
        let local = parent === scene ? origin : origin.applying(pt.inverted())
        n.position = local
        n.zRotation = b.angle - atan2(pt.b, pt.a)
        b.lastNodePos = origin; b.lastNodeAngle = b.angle
    }

    func simulate(_ frameDt: TimeInterval) {
        guard let scene else { return }
        var bodies: [SKPhysicsBody] = [], fields: [SKFieldNode] = []
        collectBodies(scene, &bodies, &fields)
        lastBodies = bodies
        let dt = CGFloat(frameDt) * speed
        for b in bodies {
            pull(b, dt)
            let m = b.mass
            b.invMass = b.isDynamic && !b.pinned && m > 0 ? 1 / m : 0
            let I = b.inertiaInternal
            b.invI = b.isDynamic && b.allowsRotation && I > 0 ? 1 / I : 0
            b.updateWorldShapes()
        }
        jointList.removeAll { $0.bodyA?.node?.scene !== scene || $0.bodyB?.node?.scene !== scene }
        var touchedNow: [_PairKey: (SKPhysicsBody, SKPhysicsBody, CGPoint, CGPoint, CGFloat)] = [:]
        if dt > 0 {
            // substeps keep fast bodies from tunneling through thin shapes
            var n = 1
            for b in bodies where b.isDynamic {
                let v = (b.velocity.dx * b.velocity.dx + b.velocity.dy * b.velocity.dy).squareRoot()
                let k = Int((v * dt / (b.minExtent * (b.usesPreciseCollisionDetection ? 0.25 : 0.5))).rounded(.up))
                n = max(n, k)
            }
            n = max(2, min(n, 16))
            if dt > 1.0 / 30 { n = max(n, Int((dt * 120).rounded(.up))) }
            let h = dt / CGFloat(n)
            for _ in 0..<n { step(bodies, fields, h, &touchedNow) }
        } else {
            step(bodies, fields, 0, &touchedNow)
        }
        for b in bodies {
            b.force = .zero; b.torque = 0
            if b.isDynamic { push(b) }
            if b.isDynamic {
                let v2 = b.velocity.dx * b.velocity.dx + b.velocity.dy * b.velocity.dy
                if v2 < 1 && abs(b.angularVelocity) < 0.02 { b.restTime += dt } else { b.restTime = 0 }
                b.isResting = b.restTime > 0.5
            }
            b.touching = []
        }
        for (_, v) in touchedNow { v.0.touching.insert(ObjectIdentifier(v.1)); v.1.touching.insert(ObjectIdentifier(v.0)) }
        // contact delegate: begin for new touching pairs, end for pairs that separated
        let delegate = contactDelegate as? SKPhysicsContactDelegate
        var began: [SKPhysicsContact] = [], ended: [SKPhysicsContact] = []
        for (k, v) in touchedNow where touchingPairs[k] == nil {
            if _wantsContact(v.0, v.1) { began.append(SKPhysicsContact(a: v.0, b: v.1, point: v.2, normal: CGVector(dx: v.3.x, dy: v.3.y), impulse: v.4 / _ptm)) }
        }
        for (k, v) in touchingPairs where touchedNow[k] == nil {
            if _wantsContact(v.0, v.1) { ended.append(SKPhysicsContact(a: v.0, b: v.1, point: .zero, normal: .zero, impulse: 0)) }
        }
        touchingPairs = touchedNow.mapValues { ($0.0, $0.1) }
        for c in began { delegate?.didBegin(c) }
        for c in ended { delegate?.didEnd(c) }
    }

    func step(_ bodies: [SKPhysicsBody], _ fields: [SKFieldNode], _ h: CGFloat,
              _ touched: inout [_PairKey: (SKPhysicsBody, SKPhysicsBody, CGPoint, CGPoint, CGFloat)]) {
        let g = CGPoint(x: gravity.dx * _ptm, y: gravity.dy * _ptm)
        // forces -> velocities
        if h > 0 {
            for b in bodies where b.invMass > 0 || b.invI > 0 {
                var a = b.affectedByGravity ? g : .zero
                var f = b.force
                for fl in fields where fl.isEnabled && (fl.categoryBitMask & b.fieldBitMask) != 0 { f = _add(f, fl.force(on: b)) }
                if fields.contains(where: { $0.isEnabled && $0.isExclusive && ($0.categoryBitMask & b.fieldBitMask) != 0 && $0.regionContains(b.com) }) {
                    // an exclusive field suppresses the others where it applies
                    let ex = fields.filter { $0.isEnabled && $0.isExclusive && ($0.categoryBitMask & b.fieldBitMask) != 0 && $0.regionContains(b.com) }
                    f = b.force
                    for fl in ex { f = _add(f, fl.force(on: b)) }
                }
                if b.invMass > 0 { a = _add(a, _mul(f, b.invMass)) }
                b.velocity.dx += a.x * h; b.velocity.dy += a.y * h
                b.velocity.dx /= 1 + h * b.linearDamping; b.velocity.dy /= 1 + h * b.linearDamping
                if b.invI > 0 { b.angularVelocity += b.torque * b.invI * h }
                b.angularVelocity /= 1 + h * b.angularDamping
                if b.invMass == 0 { b.velocity = .zero }
                if b.invI == 0 && !(b.pinned && b.allowsRotation) { b.angularVelocity = 0 }
            }
        }
        // narrow phase
        var manifolds: [_Manifold] = []
        let margin: CGFloat = h > 0 ? 2 : 0
        let count = bodies.count
        var boxes = bodies.map { $0.aabb }
        for i in 0..<count { boxes[i] = boxes[i].insetBy(dx: -margin, dy: -margin) }
        for i in 0..<count {
            let a = bodies[i]
            if boxes[i].isNull { continue }
            for j in (i + 1)..<max(i + 1, count) {
                let b = bodies[j]
                if !a.isDynamic && !b.isDynamic { continue }      // static bodies never touch each other
                if !boxes[i].intersects(boxes[j]) { continue }
                // collision response is per body: a body is affected when its collision mask matches the other's category
                let aResponds = (a.collisionBitMask & b.categoryBitMask) != 0, bResponds = (b.collisionBitMask & a.categoryBitMask) != 0
                let collide = (aResponds && (a.invMass > 0 || a.invI > 0)) || (bResponds && (b.invMass > 0 || b.invI > 0))
                let contact = _wantsContact(a, b)
                guard collide || contact else { continue }
                var best: _Manifold?
                for s1 in a.world {
                    for s2 in b.world {
                        guard let (n, pts) = _Collide.shapes(s1, s2, margin: margin) else { continue }
                        let cs = pts.map { _Contact(p: $0.0, sep: $0.1) }
                        if best == nil { best = _Manifold(a: a, b: b, n: n, contacts: cs) }
                        else { best!.contacts += cs }
                    }
                }
                guard var m = best else { continue }
                let deepest = m.contacts.min { $0.sep < $1.sep }!
                if deepest.sep <= 0.25 {
                    let key = _PairKey(a, b)
                    if touched[key] == nil { touched[key] = (a, b, deepest.p, m.n, 0) }
                }
                m.collide = collide
                guard m.collide, h > 0 else { continue }
                if aResponds { m.ima = a.invMass; m.iia = a.invI }
                if bResponds { m.imb = b.invMass; m.iib = b.invI }
                m.friction = (a.friction * b.friction).squareRoot()
                m.restitution = max(a.restitution, b.restitution)
                if m.contacts.count > 2 { m.contacts = Array(m.contacts.sorted { $0.sep < $1.sep }.prefix(2)) }
                manifolds.append(m)
            }
        }
        guard h > 0 else { return }
        // prepare contacts
        for mi in 0..<manifolds.count {
            let m = manifolds[mi], a = m.a, b = m.b
            let t = CGPoint(x: m.n.y, y: -m.n.x)
            for ci in 0..<m.contacts.count {
                var c = m.contacts[ci]
                c.rA = _sub(c.p, a.com); c.rB = _sub(c.p, b.com)
                let rnA = _cross(c.rA, m.n), rnB = _cross(c.rB, m.n)
                let kn = m.ima + m.imb + m.iia * rnA * rnA + m.iib * rnB * rnB
                c.mN = kn > 0 ? 1 / kn : 0
                let rtA = _cross(c.rA, t), rtB = _cross(c.rB, t)
                let kt = m.ima + m.imb + m.iia * rtA * rtA + m.iib * rtB * rtB
                c.mT = kt > 0 ? 1 / kt : 0
                let vn = _dot(relVel(a, b, c.rA, c.rB), m.n)
                c.bounce = vn < -40 ? -m.restitution * vn : 0
                manifolds[mi].contacts[ci] = c
            }
        }
        for j in jointList { j.preSolve(h) }
        // velocity iterations
        for _ in 0..<10 {
            for j in jointList { j.solveVelocity(h) }
            for mi in 0..<manifolds.count {
                let m = manifolds[mi], a = m.a, b = m.b
                let t = CGPoint(x: m.n.y, y: -m.n.x)
                for ci in 0..<m.contacts.count {
                    var c = manifolds[mi].contacts[ci]
                    // friction
                    let vt = _dot(relVel(a, b, c.rA, c.rB), t)
                    var dt = -vt * c.mT
                    let maxF = m.friction * c.jn
                    let newT = max(-maxF, min(maxF, c.jt + dt)); dt = newT - c.jt; c.jt = newT
                    m.apply(_mul(t, dt), c.rA, c.rB)
                    // normal (speculative when separated: may approach until touching)
                    let vn = _dot(relVel(a, b, c.rA, c.rB), m.n)
                    let target = c.sep > 0 ? -c.sep / h : 0
                    var dn = -(vn - max(target, c.bounce)) * c.mN
                    if c.sep > 0 && vn >= target { dn = min(dn, 0) }
                    let newN = max(c.jn + dn, 0); dn = newN - c.jn; c.jn = newN
                    m.apply(_mul(m.n, dn), c.rA, c.rB)
                    manifolds[mi].contacts[ci] = c
                }
            }
        }
        for m in manifolds {
            let k = _PairKey(m.a, m.b)
            if var e = touched[k] { e.4 = max(e.4, m.contacts.reduce(0) { $0 + $1.jn }); touched[k] = e }
        }
        // integrate positions
        for b in bodies where b.invMass > 0 || b.invI > 0 || (b.pinned && b.allowsRotation && b.isDynamic) {
            b.com.x += b.velocity.dx * h; b.com.y += b.velocity.dy * h
            b.angle += b.angularVelocity * h
            b.updateWorldShapes()
        }
        // static bodies moved by actions advance with their inferred velocity during the frame's substeps
        for b in bodies where !b.isDynamic && (b.velocity.dx != 0 || b.velocity.dy != 0 || b.angularVelocity != 0) {
            b.com.x += b.velocity.dx * h; b.com.y += b.velocity.dy * h
            b.angle += b.angularVelocity * h
            b.updateWorldShapes()
        }
        // position correction (split impulses: positions only)
        for _ in 0..<3 {
            for j in jointList { j.solvePosition() }
            for m in manifolds {
                let a = m.a, b = m.b
                let tot = m.ima + m.imb
                if tot <= 0 { continue }
                var worst: CGFloat = 0, n = m.n
                for s1 in a.world { for s2 in b.world {
                    if let (nn, pts) = _Collide.shapes(s1, s2, margin: 0) {
                        for p in pts where p.1 < worst { worst = p.1; n = nn }
                    }
                } }
                let corr = max(0, -worst - 0.5) * 0.4
                if corr <= 0 { continue }
                if m.ima > 0 { a.com = _sub(a.com, _mul(n, corr * m.ima / tot)); a.updateWorldShapes() }
                if m.imb > 0 { b.com = _add(b.com, _mul(n, corr * m.imb / tot)); b.updateWorldShapes() }
            }
        }
    }
}

func _wantsContact(_ a: SKPhysicsBody, _ b: SKPhysicsBody) -> Bool {
    (a.categoryBitMask & b.contactTestBitMask) != 0 || (b.categoryBitMask & a.contactTestBitMask) != 0
}

struct _PairKey: Hashable {
    let x: ObjectIdentifier, y: ObjectIdentifier
    init(_ a: SKPhysicsBody, _ b: SKPhysicsBody) {
        let ia = ObjectIdentifier(a), ib = ObjectIdentifier(b)
        if ia < ib { x = ia; y = ib } else { x = ib; y = ia }
    }
}

@inline(__always) func relVel(_ a: SKPhysicsBody, _ b: SKPhysicsBody, _ rA: CGPoint, _ rB: CGPoint) -> CGPoint {
    let va = _add(CGPoint(x: a.velocity.dx, y: a.velocity.dy), _crossSV(a.angularVelocity, rA))
    let vb = _add(CGPoint(x: b.velocity.dx, y: b.velocity.dy), _crossSV(b.angularVelocity, rB))
    return _sub(vb, va)
}
@inline(__always) func applyImpulse(_ a: SKPhysicsBody, _ b: SKPhysicsBody, _ p: CGPoint, _ rA: CGPoint, _ rB: CGPoint) {
    a.velocity.dx -= p.x * a.invMass; a.velocity.dy -= p.y * a.invMass
    a.angularVelocity -= a.invI * _cross(rA, p)
    b.velocity.dx += p.x * b.invMass; b.velocity.dy += p.y * b.invMass
    b.angularVelocity += b.invI * _cross(rB, p)
}

// MARK: - Joints

open class SKPhysicsJoint: NSObject {
    open var bodyA: SKPhysicsBody!
    open var bodyB: SKPhysicsBody!
    open var reactionForce: CGVector { CGVector(dx: lastImpulse.x / max(lastDt, 1e-6) / _ptm, dy: lastImpulse.y / max(lastDt, 1e-6) / _ptm) }
    open var reactionTorque: CGFloat { lastAngularImpulse / max(lastDt, 1e-6) / (_ptm * _ptm) }
    var lastImpulse = CGPoint.zero, lastAngularImpulse: CGFloat = 0, lastDt: CGFloat = 0
    /// anchors in each body's local frame (relative to its center of mass, unrotated)
    var localA = CGPoint.zero, localB = CGPoint.zero
    var refAngle: CGFloat = 0

    func local(_ b: SKPhysicsBody, _ p: CGPoint) -> CGPoint {
        b.updateCOMFromNode()
        return _rot(_sub(p, b.com), cos(-b.angle), sin(-b.angle))
    }
    func world(_ b: SKPhysicsBody, _ l: CGPoint) -> CGPoint { _rot(l, cos(b.angle), sin(b.angle)) }
    func prepare() {}
    func preSolve(_ h: CGFloat) { lastDt = h; lastImpulse = .zero; lastAngularImpulse = 0 }
    func solveVelocity(_ h: CGFloat) {}
    func solvePosition() {}

    /// point-to-point velocity constraint (rA, rB world offsets)
    func solvePoint(_ a: SKPhysicsBody, _ b: SKPhysicsBody, _ rA: CGPoint, _ rB: CGPoint, _ h: CGFloat, bias: CGPoint) {
        let k11 = a.invMass + b.invMass + a.invI * rA.y * rA.y + b.invI * rB.y * rB.y
        let k12 = -a.invI * rA.x * rA.y - b.invI * rB.x * rB.y
        let k22 = a.invMass + b.invMass + a.invI * rA.x * rA.x + b.invI * rB.x * rB.x
        let det = k11 * k22 - k12 * k12
        guard abs(det) > 1e-12 else { return }
        let cdot = _add(relVel(a, b, rA, rB), bias)
        let imp = CGPoint(x: -(k22 * cdot.x - k12 * cdot.y) / det, y: -(-k12 * cdot.x + k11 * cdot.y) / det)
        applyImpulse(a, b, imp, rA, rB)
        lastImpulse = _add(lastImpulse, imp)
    }
    func solveAngle(_ a: SKPhysicsBody, _ b: SKPhysicsBody, target: CGFloat) {
        let k = a.invI + b.invI
        guard k > 0 else { return }
        let imp = -(b.angularVelocity - a.angularVelocity - target) / k
        a.angularVelocity -= a.invI * imp; b.angularVelocity += b.invI * imp
        lastAngularImpulse += imp
    }
    func correctPoint(_ a: SKPhysicsBody, _ b: SKPhysicsBody, _ la: CGPoint, _ lb: CGPoint) {
        let pa = _add(a.com, world(a, la)), pb = _add(b.com, world(b, lb))
        let err = _sub(pb, pa)
        let tot = a.invMass + b.invMass
        guard tot > 0, _len(err) > 0.05 else { return }
        let c = _mul(err, 0.5 / tot)
        a.com = _add(a.com, _mul(c, a.invMass)); b.com = _sub(b.com, _mul(c, b.invMass))
        a.updateWorldShapes(); b.updateWorldShapes()
    }
}

extension SKPhysicsBody {
    /// current node placement (before the first simulated frame)
    func updateCOMFromNode() {
        guard let n = node, let parent = n.parent else { return }
        let pt = parent is SKScene ? CGAffineTransform.identity : parent.sceneTransform
        let pos = n.position.applying(pt), ang = n.zRotation + atan2(pt.b, pt.a)
        com = _add(pos, _rot(localCentroid, cos(ang), sin(ang))); angle = ang
    }
}

open class SKPhysicsJointPin: SKPhysicsJoint {
    open var shouldEnableLimits = false
    open var lowerAngleLimit: CGFloat = 0
    open var upperAngleLimit: CGFloat = 0
    open var frictionTorque: CGFloat = 0
    open var rotationSpeed: CGFloat = 0
    var anchor = CGPoint.zero
    open class func joint(withBodyA a: SKPhysicsBody, bodyB b: SKPhysicsBody, anchor: CGPoint) -> SKPhysicsJointPin {
        let j = SKPhysicsJointPin(); j.bodyA = a; j.bodyB = b; j.anchor = anchor; return j
    }
    override func prepare() { localA = local(bodyA, anchor); localB = local(bodyB, anchor); refAngle = bodyB.angle - bodyA.angle }
    override func solveVelocity(_ h: CGFloat) {
        guard let a = bodyA, let b = bodyB else { return }
        if rotationSpeed != 0 { solveAngle(a, b, target: rotationSpeed) }
        else if frictionTorque > 0 {
            let k = a.invI + b.invI
            if k > 0 {
                let maxImp = frictionTorque * _ptm * _ptm * h
                let imp = max(-maxImp, min(maxImp, -(b.angularVelocity - a.angularVelocity) / k))
                a.angularVelocity -= a.invI * imp; b.angularVelocity += b.invI * imp
            }
        }
        if shouldEnableLimits {
            let ang = b.angle - a.angle - refAngle, rel = b.angularVelocity - a.angularVelocity
            if (ang <= lowerAngleLimit && rel < 0) || (ang >= upperAngleLimit && rel > 0) { solveAngle(a, b, target: 0) }
        }
        solvePoint(a, b, world(a, localA), world(b, localB), h, bias: .zero)
    }
    override func solvePosition() {
        guard let a = bodyA, let b = bodyB else { return }
        correctPoint(a, b, localA, localB)
        if shouldEnableLimits {
            let ang = b.angle - a.angle - refAngle
            let err = ang < lowerAngleLimit ? ang - lowerAngleLimit : ang > upperAngleLimit ? ang - upperAngleLimit : 0
            let k = a.invI + b.invI
            if err != 0, k > 0 { a.angle += err * a.invI / k * 0.5; b.angle -= err * b.invI / k * 0.5; a.updateWorldShapes(); b.updateWorldShapes() }
        }
    }
}

open class SKPhysicsJointFixed: SKPhysicsJoint {
    var anchor = CGPoint.zero
    open class func joint(withBodyA a: SKPhysicsBody, bodyB b: SKPhysicsBody, anchor: CGPoint) -> SKPhysicsJointFixed {
        let j = SKPhysicsJointFixed(); j.bodyA = a; j.bodyB = b; j.anchor = anchor; return j
    }
    override func prepare() { localA = local(bodyA, anchor); localB = local(bodyB, anchor); refAngle = bodyB.angle - bodyA.angle }
    override func solveVelocity(_ h: CGFloat) {
        guard let a = bodyA, let b = bodyB else { return }
        solveAngle(a, b, target: 0)
        solvePoint(a, b, world(a, localA), world(b, localB), h, bias: .zero)
    }
    override func solvePosition() {
        guard let a = bodyA, let b = bodyB else { return }
        let err = b.angle - a.angle - refAngle, k = a.invI + b.invI
        if abs(err) > 1e-4, k > 0 { a.angle += err * a.invI / k * 0.5; b.angle -= err * b.invI / k * 0.5 }
        correctPoint(a, b, localA, localB)
    }
}

open class SKPhysicsJointSpring: SKPhysicsJoint {
    open var damping: CGFloat = 0
    open var frequency: CGFloat = 0
    var anchorA = CGPoint.zero, anchorB = CGPoint.zero, rest: CGFloat = 0
    open class func joint(withBodyA a: SKPhysicsBody, bodyB b: SKPhysicsBody, anchorA: CGPoint, anchorB: CGPoint) -> SKPhysicsJointSpring {
        let j = SKPhysicsJointSpring(); j.bodyA = a; j.bodyB = b; j.anchorA = anchorA; j.anchorB = anchorB; return j
    }
    override func prepare() { localA = local(bodyA, anchorA); localB = local(bodyB, anchorB); rest = _len(_sub(anchorB, anchorA)) }
    override func solveVelocity(_ h: CGFloat) {
        guard let a = bodyA, let b = bodyB, frequency > 0 else { return }
        let rA = world(a, localA), rB = world(b, localB)
        let d = _sub(_add(b.com, rB), _add(a.com, rA)), len = _len(d)
        guard len > 1e-6 else { return }
        let u = _mul(d, 1 / len)
        let rnA = _cross(rA, u), rnB = _cross(rB, u)
        let k = a.invMass + b.invMass + a.invI * rnA * rnA + b.invI * rnB * rnB
        guard k > 0 else { return }
        // soft constraint (Box2D style): frequency in Hz, damping ratio
        let m = 1 / k, omega = 2 * .pi * frequency
        let c = 2 * m * damping * omega, kk = m * omega * omega
        let gamma = 1 / (h * (c + h * kk)), beta = h * kk * gamma
        let vn = _dot(relVel(a, b, rA, rB), u)
        let imp = -(vn + beta * (len - rest)) / (k + gamma) * 0.1
        applyImpulse(a, b, _mul(u, imp), rA, rB)
        lastImpulse = _add(lastImpulse, _mul(u, imp))
    }
}

open class SKPhysicsJointLimit: SKPhysicsJoint {
    open var maxLength: CGFloat = 0
    var anchorA = CGPoint.zero, anchorB = CGPoint.zero
    open class func joint(withBodyA a: SKPhysicsBody, bodyB b: SKPhysicsBody, anchorA: CGPoint, anchorB: CGPoint) -> SKPhysicsJointLimit {
        let j = SKPhysicsJointLimit(); j.bodyA = a; j.bodyB = b; j.anchorA = anchorA; j.anchorB = anchorB
        j.maxLength = _len(_sub(anchorB, anchorA)); return j
    }
    override func prepare() { localA = local(bodyA, anchorA); localB = local(bodyB, anchorB) }
    override func solveVelocity(_ h: CGFloat) {
        guard let a = bodyA, let b = bodyB else { return }
        let rA = world(a, localA), rB = world(b, localB)
        let d = _sub(_add(b.com, rB), _add(a.com, rA)), len = _len(d)
        guard len > 1e-6 else { return }
        let u = _mul(d, 1 / len)
        let rnA = _cross(rA, u), rnB = _cross(rB, u)
        let k = a.invMass + b.invMass + a.invI * rnA * rnA + b.invI * rnB * rnB
        guard k > 0 else { return }
        let C = len - maxLength
        let vn = _dot(relVel(a, b, rA, rB), u)
        var imp = -(vn + (C < 0 ? C / h : 0)) / k
        imp = min(imp, 0)   // a rope only pulls
        applyImpulse(a, b, _mul(u, imp), rA, rB)
        lastImpulse = _add(lastImpulse, _mul(u, imp))
    }
    override func solvePosition() {
        guard let a = bodyA, let b = bodyB else { return }
        let pa = _add(a.com, world(a, localA)), pb = _add(b.com, world(b, localB))
        let d = _sub(pb, pa), len = _len(d), tot = a.invMass + b.invMass
        guard len > maxLength + 0.05, tot > 0 else { return }
        let c = _mul(d, (len - maxLength) / len * 0.5 / tot)
        a.com = _add(a.com, _mul(c, a.invMass)); b.com = _sub(b.com, _mul(c, b.invMass))
        a.updateWorldShapes(); b.updateWorldShapes()
    }
}

open class SKPhysicsJointSliding: SKPhysicsJoint {
    open var shouldEnableLimits = false
    open var lowerDistanceLimit: CGFloat = 0
    open var upperDistanceLimit: CGFloat = 0
    var anchor = CGPoint.zero, axis = CGVector(dx: 1, dy: 0), localAxis = CGPoint(x: 1, y: 0)
    open class func joint(withBodyA a: SKPhysicsBody, bodyB b: SKPhysicsBody, anchor: CGPoint, axis: CGVector) -> SKPhysicsJointSliding {
        let j = SKPhysicsJointSliding(); j.bodyA = a; j.bodyB = b; j.anchor = anchor; j.axis = axis; return j
    }
    override func prepare() {
        localA = local(bodyA, anchor); localB = local(bodyB, anchor); refAngle = bodyB.angle - bodyA.angle
        localAxis = _rot(_norm(CGPoint(x: axis.dx, y: axis.dy)), cos(-bodyA.angle), sin(-bodyA.angle))
    }
    override func solveVelocity(_ h: CGFloat) {
        guard let a = bodyA, let b = bodyB else { return }
        solveAngle(a, b, target: 0)
        let rA = world(a, localA), rB = world(b, localB)
        let ax = world(a, localAxis), perp = CGPoint(x: -ax.y, y: ax.x)
        for (dir, isAxis) in [(perp, false), (ax, true)] {
            let d = _sub(_add(b.com, rB), _add(a.com, rA))
            let along = _dot(d, ax)
            if isAxis {
                guard shouldEnableLimits else { continue }
                let vn = _dot(relVel(a, b, rA, rB), dir)
                if !((along <= lowerDistanceLimit && vn < 0) || (along >= upperDistanceLimit && vn > 0)) { continue }
            }
            let rnA = _cross(rA, dir), rnB = _cross(rB, dir)
            let k = a.invMass + b.invMass + a.invI * rnA * rnA + b.invI * rnB * rnB
            guard k > 0 else { continue }
            let imp = -_dot(relVel(a, b, rA, rB), dir) / k
            applyImpulse(a, b, _mul(dir, imp), rA, rB)
        }
    }
    override func solvePosition() {
        guard let a = bodyA, let b = bodyB else { return }
        let rA = world(a, localA), rB = world(b, localB)
        let ax = world(a, localAxis), perp = CGPoint(x: -ax.y, y: ax.x)
        let d = _sub(_add(b.com, rB), _add(a.com, rA))
        var err = _mul(perp, _dot(d, perp))
        if shouldEnableLimits {
            let along = _dot(d, ax)
            if along < lowerDistanceLimit { err = _add(err, _mul(ax, along - lowerDistanceLimit)) }
            if along > upperDistanceLimit { err = _add(err, _mul(ax, along - upperDistanceLimit)) }
        }
        let tot = a.invMass + b.invMass
        guard tot > 0, _len(err) > 0.05 else { return }
        let c = _mul(err, 0.5 / tot)
        a.com = _add(a.com, _mul(c, a.invMass)); b.com = _sub(b.com, _mul(c, b.invMass))
        a.updateWorldShapes(); b.updateWorldShapes()
    }
}
