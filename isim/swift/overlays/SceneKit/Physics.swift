// isim SceneKit: physics (issue #330). A simple rigid-body simulation in the scene's SCNPhysicsWorld: gravity, forces,
// impulses, damping, sphere and box shapes (other shapes use their bounding box), collisions with restitution and
// friction, category / collision / contact masks and the contact delegate. Adapted: isim's own solver (SceneKit uses
// Bullet): boxes collide as boxes aligned with the world axes, contacts do not make bodies spin, and joints
// (behaviors), fields, vehicles and ray / convex sweep tests over physics shapes are not provided (rayTestWithSegment
// uses the bodies' bounding volumes).
import UIKit
import simd

/// The simulation of a scene's physics bodies.
@objc(SCNPhysicsWorld) open class SCNPhysicsWorld: NSObject, NSSecureCoding, @unchecked Sendable {
    public struct TestOption: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let collisionBitMask = TestOption(rawValue: "collisionBitMask")
        public static let searchMode = TestOption(rawValue: "results")
        public static let backfaceCulling = TestOption(rawValue: "backfaceCulling")
    }
    public struct TestSearchMode: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let any = TestSearchMode(rawValue: "any")
        public static let closest = TestSearchMode(rawValue: "closest")
        public static let all = TestSearchMode(rawValue: "all")
    }
    @objc public override init() { super.init() }
    open var gravity = SCNVector3(0, -9.8, 0)
    @objc open var speed: CGFloat = 1
    @objc open var timeStep: TimeInterval = 1.0 / 60
    open weak var contactDelegate: (any SCNPhysicsContactDelegate)?
    weak var _scene: SCNScene?
    var _contacts: Set<String> = []
    var _accum: TimeInterval = 0

    @objc open func addBehavior(_ behavior: SCNPhysicsBehavior) {}
    @objc open func removeBehavior(_ behavior: SCNPhysicsBehavior) {}
    @objc open func removeAllBehaviors() {}
    @objc open var allBehaviors: [SCNPhysicsBehavior] { [] }
    @objc open func updateCollisionPairs() {}

    /// bodies whose bounding volumes the segment crosses (world space), nearest first
    open func rayTestWithSegment(from origin: SCNVector3, to dest: SCNVector3, options: [TestOption: Any]? = nil) -> [SCNPhysicsContact] {
        let a = SIMD3(origin), d = SIMD3(dest) - a
        let mask = (options?[.collisionBitMask] as? NSNumber).map { Int($0.intValue) } ?? -1
        var out: [(Float, SCNPhysicsContact)] = []
        for b in _bodies() where b.categoryBitMask & mask != 0 {
            let (lo, hi) = b._aabb()
            guard let t = _SCNHitTest.box(a, d, lo, hi), t <= 1, let n = b._node else { continue }
            let c = SCNPhysicsContact()
            c.nodeA = n; c.nodeB = n
            c.contactPoint = SCNVector3(a + d * t)
            c.penetrationDistance = 0
            out.append((t, c))
        }
        out.sort { $0.0 < $1.0 }
        let mode = (options?[.searchMode] as? String).map(TestSearchMode.init(rawValue:)) ?? .any
        return mode == .all ? out.map(\.1) : Array(out.prefix(1).map(\.1))
    }
    /// pairs of bodies touching a body now
    open func contactTest(with body: SCNPhysicsBody, options: [TestOption: Any]? = nil) -> [SCNPhysicsContact] {
        _bodies().filter { $0 !== body }.compactMap { _collide(body, $0) }
    }
    open func contactTestBetween(_ bodyA: SCNPhysicsBody, _ bodyB: SCNPhysicsBody, options: [TestOption: Any]? = nil) -> [SCNPhysicsContact] {
        _collide(bodyA, bodyB).map { [$0] } ?? []
    }

    func _bodies() -> [SCNPhysicsBody] {
        guard let root = _scene?.rootNode else { return [] }
        var out: [SCNPhysicsBody] = []
        func walk(_ n: SCNNode) {
            if let b = n.physicsBody { out.append(b) }
            for c in n.childNodes { walk(c) }
        }
        walk(root)
        return out
    }

    /// advances the simulation in fixed steps
    func _step(_ dt: TimeInterval) {
        guard speed > 0, dt > 0 else { return }
        let bodies = _bodies()
        guard !bodies.isEmpty else { return }
        _accum += dt * Double(speed)
        let step = max(timeStep, 1.0 / 240)
        var n = 0
        while _accum >= step && n < 8 {
            _accum -= step; n += 1
            _integrate(bodies, Float(step))
        }
    }
    func _integrate(_ bodies: [SCNPhysicsBody], _ h: Float) {
        let g = SIMD3(gravity)
        for b in bodies where b.type == .dynamic && b._node != nil {
            if simd_length(b._force) > 0 { b.isResting = false }
            if b.isResting { continue }
            let m = max(Float(b.mass), 1e-6)
            var a = b._force / m
            if b.isAffectedByGravity { a += g }
            b._v += a * h
            b._v *= powf(max(0, 1 - Float(b.damping)), h)
            b._w *= powf(max(0, 1 - Float(b.angularDamping)), h)
            b._v *= SIMD3(b.velocityFactor); b._w *= SIMD3(b.angularVelocityFactor)
            b._force = .zero; b._torque = .zero
            if let node = b._node {
                node.simdWorldPosition += b._v * h
                if simd_length(b._w) > 1e-6 {
                    let q = simd_quatf(angle: simd_length(b._w) * h, axis: simd_normalize(b._w))
                    node.simdWorldOrientation = simd_normalize(q * node.simdWorldOrientation)
                }
            }
        }
        for b in bodies where b.type == .kinematic { b._kinematicVelocity(h) }
        // collisions
        var touching: Set<String> = []
        var began: [SCNPhysicsContact] = [], updated: [SCNPhysicsContact] = []
        for i in bodies.indices {
            for j in (i + 1)..<bodies.count {
                let a = bodies[i], b = bodies[j]
                guard a.type == .dynamic || b.type == .dynamic, let c = _collide(a, b) else { continue }
                let key = "\(ObjectIdentifier(a).hashValue):\(ObjectIdentifier(b).hashValue)"
                let collides = (a.collisionBitMask & b.categoryBitMask) != 0 || (b.collisionBitMask & a.categoryBitMask) != 0
                if collides { _resolve(a, b, c) }
                let reports = (a.contactTestBitMask & b.categoryBitMask) != 0 || (b.contactTestBitMask & a.categoryBitMask) != 0
                if reports {
                    touching.insert(key)
                    if _contacts.contains(key) { updated.append(c) } else { began.append(c) }
                }
            }
        }
        let ended = _contacts.subtracting(touching)
        _contacts = touching
        guard let d = contactDelegate else { return }
        for c in began { d.physicsWorld(self, didBegin: c) }
        for c in updated { d.physicsWorld(self, didUpdate: c) }
        if !ended.isEmpty {
            // the bodies are no longer touching: report them with the bodies found by key
            for key in ended {
                let ids = key.split(separator: ":").compactMap { Int($0) }
                let pair = bodies.filter { ids.contains(ObjectIdentifier($0).hashValue) }
                guard pair.count == 2, let na = pair[0]._node, let nb = pair[1]._node else { continue }
                let c = SCNPhysicsContact(); c.nodeA = na; c.nodeB = nb
                d.physicsWorld(self, didEnd: c)
            }
        }
    }

    /// the contact between two bodies' shapes, if they overlap
    func _collide(_ a: SCNPhysicsBody, _ b: SCNPhysicsBody) -> SCNPhysicsContact? {
        guard let na = a._node, let nb = b._node else { return nil }
        let sa = a._shape(), sb = b._shape()
        var normal = SIMD3<Float>(0, 1, 0), depth: Float = 0, point = SIMD3<Float>(0, 0, 0)
        switch (sa, sb) {
        case let (.sphere(ca, ra), .sphere(cb, rb)):
            let d = cb - ca, len = simd_length(d)
            guard len < ra + rb else { return nil }
            normal = len > 1e-6 ? d / len : SIMD3(0, 1, 0); depth = ra + rb - len; point = ca + normal * ra
        case let (.sphere(c, r), .box(lo, hi)), let (.box(lo, hi), .sphere(c, r)):
            let q = simd_clamp(c, lo, hi), d = c - q, len = simd_length(d)
            if len > 1e-6 {
                guard len < r else { return nil }
                normal = d / len; depth = r - len
            } else {
                // the centre is inside the box: push out along the nearest face
                let dl = c - lo, dh = hi - c
                let m = [dl.x, dl.y, dl.z, dh.x, dh.y, dh.z]
                let i = m.indices.min { m[$0] < m[$1] }!
                var n = SIMD3<Float>(0, 0, 0); n[i % 3] = i < 3 ? -1 : 1
                normal = n; depth = m[i] + r
            }
            point = q
            // the normal points from A to B
            if case .sphere = sa { normal = -normal }
        case let (.box(la, ha), .box(lb, hb)):
            let o = simd_min(ha, hb) - simd_max(la, lb)
            guard o.x > 0, o.y > 0, o.z > 0 else { return nil }
            let ca = (la + ha) / 2, cb = (lb + hb) / 2
            if o.x <= o.y && o.x <= o.z { normal = SIMD3(cb.x >= ca.x ? 1 : -1, 0, 0); depth = o.x } else if o.y <= o.z {
                normal = SIMD3(0, cb.y >= ca.y ? 1 : -1, 0); depth = o.y
            } else { normal = SIMD3(0, 0, cb.z >= ca.z ? 1 : -1); depth = o.z }
            point = (simd_max(la, lb) + simd_min(ha, hb)) / 2
        }
        let c = SCNPhysicsContact()
        c.nodeA = na; c.nodeB = nb
        c.contactPoint = SCNVector3(point)
        c.contactNormal = SCNVector3(normal)
        c.penetrationDistance = CGFloat(depth)
        c.collisionImpulse = CGFloat(simd_length(b._v - a._v) * Float(max(a.mass, b.mass)))
        return c
    }
    /// separates two bodies and exchanges an impulse along the contact normal (restitution, friction)
    func _resolve(_ a: SCNPhysicsBody, _ b: SCNPhysicsBody, _ c: SCNPhysicsContact) {
        let n = SIMD3(c.contactNormal), depth = Float(c.penetrationDistance)
        let ia: Float = a.type == .dynamic ? 1 / max(Float(a.mass), 1e-6) : 0
        let ib: Float = b.type == .dynamic ? 1 / max(Float(b.mass), 1e-6) : 0
        guard ia + ib > 0 else { return }
        // positional correction
        let corr = n * (max(depth - 0.001, 0) / (ia + ib))
        if ia > 0, let na = a._node { na.simdWorldPosition -= corr * ia }
        if ib > 0, let nb = b._node { nb.simdWorldPosition += corr * ib }
        let rv = b._v - a._v
        let vn = simd_dot(rv, n)
        guard vn < 0 else { return }
        let e = Float(min(a.restitution, b.restitution))
        let j = -(1 + e) * vn / (ia + ib)
        a._v -= n * j * ia; b._v += n * j * ib
        // friction along the tangent
        let rv2 = b._v - a._v
        var t = rv2 - n * simd_dot(rv2, n)
        if simd_length(t) > 1e-6 {
            t = simd_normalize(t)
            let mu = Float(sqrt(a.friction * b.friction))
            let jt = max(-j * mu, min(j * mu, -simd_dot(rv2, t) / (ia + ib)))
            a._v -= t * jt * ia; b._v += t * jt * ib
            // rolling bodies slow their spin with friction
            a._w *= 1 - Float(a.rollingFriction); b._w *= 1 - Float(b.rollingFriction)
        }
        for body in [a, b] where body.type == .dynamic {
            // a slow body supported against gravity comes to rest (and stops moving until a force or a hit wakes it)
            if body.allowsResting && simd_length(body._v) < 0.05 && abs(simd_dot(SIMD3(gravity), n)) > 0 {
                body._v = .zero; body.isResting = true
            } else if simd_length(body._v) >= 0.05 { body.isResting = false }
        }
    }

    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public required init?(coder: NSCoder) { super.init() }
}

public protocol SCNPhysicsContactDelegate: NSObjectProtocol {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact)
    func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact)
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact)
}
extension SCNPhysicsContactDelegate {
    public func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {}
    public func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact) {}
    public func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {}
}

/// Two bodies touching.
@objc(SCNPhysicsContact) open class SCNPhysicsContact: NSObject, @unchecked Sendable {
    @objc open internal(set) var nodeA = SCNNode()
    @objc open internal(set) var nodeB = SCNNode()
    open internal(set) var contactPoint = SCNVector3Zero
    open internal(set) var contactNormal = SCNVector3Zero
    @objc open internal(set) var collisionImpulse: CGFloat = 0
    @objc open internal(set) var penetrationDistance: CGFloat = 0
    @objc open internal(set) var sweepTestFraction: CGFloat = 0
}

/// A joint or other behavior between bodies. Not simulated.
@objc(SCNPhysicsBehavior) open class SCNPhysicsBehavior: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public override init() { super.init() }
    @objc public required init?(coder: NSCoder) { super.init() }
}

/// A body's collision shape: a geometry (its bounding sphere for spheres, otherwise its bounding box), scaled.
@objc(SCNPhysicsShape) open class SCNPhysicsShape: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public struct Option: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let type = Option(rawValue: "SCNPhysicsShapeTypeKey")
        public static let keepAsCompound = Option(rawValue: "SCNPhysicsShapeKeepAsCompoundKey")
        public static let scale = Option(rawValue: "SCNPhysicsShapeScaleKey")
        public static let collisionMargin = Option(rawValue: "SCNPhysicsShapeCollisionMarginKey")
    }
    public struct ShapeType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let boundingBox = ShapeType(rawValue: "boundingBox")
        public static let convexHull = ShapeType(rawValue: "convexHull")
        public static let concavePolyhedron = ShapeType(rawValue: "concavePolyhedron")
    }
    @objc open private(set) var sourceObject: Any = NSNull()
    @objc open private(set) var options: [String: Any]?
    @objc open private(set) var transforms: [NSValue]?
    var _geometry: SCNGeometry?, _scale = SIMD3<Float>(1, 1, 1)
    @objc public override init() { super.init() }
    public convenience init(geometry: SCNGeometry, options: [Option: Any]? = nil) {
        self.init()
        sourceObject = geometry; _geometry = geometry
        if let v = options?[.scale] as? NSValue, let f = _SCNAnimations.floats(v), f.count >= 3 { _scale = SIMD3(f[0], f[1], f[2]) }
        self.options = options.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.key.rawValue, $0.value) }) }
    }
    public convenience init(node: SCNNode, options: [Option: Any]? = nil) {
        self.init()
        sourceObject = node
        _geometry = node.geometry
        self.options = options.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.key.rawValue, $0.value) }) }
    }
    @objc public convenience init(shapes: [SCNPhysicsShape], transforms: [NSValue]?) {
        self.init()
        sourceObject = shapes; _geometry = shapes.first?._geometry; self.transforms = transforms
    }
    @objc open func copy(with zone: NSZone? = nil) -> Any { self }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public required init?(coder: NSCoder) { super.init() }
}

@objc public enum SCNPhysicsBodyType: Int, Sendable { case `static` = 0, dynamic = 1, kinematic = 2 }
public struct SCNPhysicsCollisionCategory: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let `default` = SCNPhysicsCollisionCategory(rawValue: 1)
    public static let `static` = SCNPhysicsCollisionCategory(rawValue: 2)
    public static let all = SCNPhysicsCollisionCategory(rawValue: .max)
}

/// A node's physical properties: how it moves and collides.
@objc(SCNPhysicsBody) open class SCNPhysicsBody: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc public convenience init(type: SCNPhysicsBodyType, shape: SCNPhysicsShape?) {
        self.init(); self.type = type; physicsShape = shape
        mass = type == .dynamic ? 1 : 0
        if type == .static { categoryBitMask = Int(SCNPhysicsCollisionCategory.static.rawValue) }
    }
    @objc(staticBody) open class func `static`() -> SCNPhysicsBody { SCNPhysicsBody(type: .static, shape: nil) }
    @objc(dynamicBody) open class func dynamic() -> SCNPhysicsBody { SCNPhysicsBody(type: .dynamic, shape: nil) }
    @objc(kinematicBody) open class func kinematic() -> SCNPhysicsBody { SCNPhysicsBody(type: .kinematic, shape: nil) }
    @objc open var type: SCNPhysicsBodyType = .dynamic
    @objc open var physicsShape: SCNPhysicsShape?
    @objc open var mass: CGFloat = 1
    open var momentOfInertia = SCNVector3(1, 1, 1)
    @objc open var usesDefaultMomentOfInertia = true
    @objc open var charge: CGFloat = 0
    @objc open var friction: CGFloat = 0.5
    @objc open var rollingFriction: CGFloat = 0
    @objc open var restitution: CGFloat = 0.5
    @objc open var damping: CGFloat = 0.1
    @objc open var angularDamping: CGFloat = 0.1
    @objc open var isAffectedByGravity = true
    @objc open var allowsResting = true
    @objc open var isResting = false
    @objc open var continuousCollisionDetectionThreshold: CGFloat = 0
    open var centerOfMassOffset = SCNVector3Zero
    @objc open var linearRestingThreshold: CGFloat = 0.1
    @objc open var angularRestingThreshold: CGFloat = 0.1
    @objc open var categoryBitMask = Int(SCNPhysicsCollisionCategory.default.rawValue)
    @objc open var collisionBitMask = Int(bitPattern: SCNPhysicsCollisionCategory.all.rawValue)
    @objc open var contactTestBitMask = 0
    open var velocity: SCNVector3 { get { SCNVector3(_v) } set { _v = SIMD3(newValue); isResting = false } }
    open var angularVelocity: SCNVector4 {
        get { let l = simd_length(_w); return l > 0 ? SCNVector4(x: _w.x / l, y: _w.y / l, z: _w.z / l, w: l) : SCNVector4(x: 0, y: 1, z: 0, w: 0) }
        set { _w = SIMD3(newValue.x, newValue.y, newValue.z) * newValue.w; isResting = false }
    }
    open var velocityFactor = SCNVector3(1, 1, 1)
    open var angularVelocityFactor = SCNVector3(1, 1, 1)
    weak var _node: SCNNode?
    var _v = SIMD3<Float>(0, 0, 0), _w = SIMD3<Float>(0, 0, 0), _force = SIMD3<Float>(0, 0, 0), _torque = SIMD3<Float>(0, 0, 0)
    var _lastKinematic: SIMD3<Float>?

    open func applyForce(_ direction: SCNVector3, asImpulse impulse: Bool) {
        if impulse { _v += SIMD3(direction) / max(Float(mass), 1e-6) } else { _force += SIMD3(direction) }
        isResting = false
    }
    open func applyForce(_ direction: SCNVector3, at position: SCNVector3, asImpulse impulse: Bool) {
        applyForce(direction, asImpulse: impulse)
        let r = SIMD3(position) - SIMD3(centerOfMassOffset)
        applyTorque(SCNVector4(simd_cross(r, SIMD3(direction)).x, simd_cross(r, SIMD3(direction)).y, simd_cross(r, SIMD3(direction)).z, 1), asImpulse: impulse)
    }
    /// torque: an axis (x, y, z) and a magnitude (w)
    open func applyTorque(_ torque: SCNVector4, asImpulse impulse: Bool) {
        let t = SIMD3(torque.x, torque.y, torque.z) * torque.w
        if impulse { _w += t / max(Float(mass), 1e-6) } else { _torque += t; _w += t / max(Float(mass), 1e-6) / 60 }
        isResting = false
    }
    @objc open func clearAllForces() { _force = .zero; _torque = .zero }
    @objc open func resetTransform() { _SCNDirty.bump() }
    open func setResting(_ resting: Bool) { isResting = resting; if resting { _v = .zero; _w = .zero } }
    func _reset() { _v = .zero; _w = .zero; _lastKinematic = nil }
    func _kinematicVelocity(_ h: Float) {
        guard let n = _node else { return }
        let p = n.simdWorldPosition
        if let last = _lastKinematic, h > 0 { _v = (p - last) / h }
        _lastKinematic = p
    }

    enum Shape { case sphere(SIMD3<Float>, Float), box(SIMD3<Float>, SIMD3<Float>) }
    /// the body's shape in world space
    func _shape() -> Shape {
        guard let n = _node else { return .sphere(.zero, 0) }
        let w = n.simdWorldTransform
        let g = physicsShape?._geometry ?? n.geometry
        let s = (physicsShape?._scale ?? SIMD3(1, 1, 1)) * SIMD3(simd_length(SIMD3(w.columns.0.x, w.columns.0.y, w.columns.0.z)),
                                                             simd_length(SIMD3(w.columns.1.x, w.columns.1.y, w.columns.1.z)),
                                                             simd_length(SIMD3(w.columns.2.x, w.columns.2.y, w.columns.2.z)))
        let center = SIMD3(w.columns.3.x, w.columns.3.y, w.columns.3.z)
        if let sphere = g as? SCNSphere { return .sphere(center, Float(sphere.radius) * s.max()) }
        guard let g else { return .sphere(center, 0.01) }
        let b = g.boundingBox
        let lo = SIMD3(b.min), hi = SIMD3(b.max)
        // the box's corners in world space (rotated boxes: their world-aligned bounds)
        var wl = SIMD3<Float>(repeating: .infinity), wh = SIMD3<Float>(repeating: -.infinity)
        let m = w * simd_float4x4(diagonal: SIMD4((physicsShape?._scale ?? SIMD3(1, 1, 1)), 1))
        for i in 0..<8 {
            let p = SIMD3(i & 1 == 0 ? lo.x : hi.x, i & 2 == 0 ? lo.y : hi.y, i & 4 == 0 ? lo.z : hi.z)
            let q = m * SIMD4(p, 1)
            wl = simd_min(wl, SIMD3(q.x, q.y, q.z)); wh = simd_max(wh, SIMD3(q.x, q.y, q.z))
        }
        return .box(wl, wh)
    }
    func _aabb() -> (SIMD3<Float>, SIMD3<Float>) {
        switch _shape() {
        case let .sphere(c, r): return (c - r, c + r)
        case let .box(lo, hi): return (lo, hi)
        }
    }

    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let b = SCNPhysicsBody(type: type, shape: physicsShape)
        b.mass = mass; b.friction = friction; b.rollingFriction = rollingFriction; b.restitution = restitution; b.damping = damping
        b.angularDamping = angularDamping; b.isAffectedByGravity = isAffectedByGravity; b.allowsResting = allowsResting
        b.categoryBitMask = categoryBitMask; b.collisionBitMask = collisionBitMask; b.contactTestBitMask = contactTestBitMask
        b.velocityFactor = velocityFactor; b.angularVelocityFactor = angularVelocityFactor; b.charge = charge
        return b
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(type.rawValue, forKey: "type"); coder.encode(Double(mass), forKey: "mass") }
    @objc public required init?(coder: NSCoder) {
        super.init()
        type = SCNPhysicsBodyType(rawValue: coder.decodeInteger(forKey: "type")) ?? .dynamic
        mass = CGFloat(coder.decodeDouble(forKey: "mass"))
    }
}
