// isim GameplayKit: steering agents (GKAgent2D with GKBehavior / GKGoal) and rule systems.
import Foundation

// MARK: - Agents

@objc public protocol GKAgentDelegate: NSObjectProtocol {
    @objc optional func agentWillUpdate(_ agent: GKAgent)
    @objc optional func agentDidUpdate(_ agent: GKAgent)
}

open class GKAgent: GKComponent {
    open weak var delegate: GKAgentDelegate?
    open var behavior: GKBehavior?
    open var mass: Float = 1
    open var radius: Float = 0.5
    open var speed: Float = 0
    open var maxAcceleration: Float = 1
    open var maxSpeed: Float = 1
}

open class GKAgent2D: GKAgent {
    open var position: vector_float2 = .zero
    open internal(set) var velocity: vector_float2 = .zero
    open var rotation: Float = 0
    var wanderAngle: Float = 0

    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    open override func update(deltaTime seconds: TimeInterval) {
        delegate?.agentWillUpdate?(self)
        let v = _gkIntegrate(self, Float(seconds))
        velocity = vector_float2(v.x, v.y)
        speed = simd_length(velocity)
        position += velocity * Float(seconds)
        if speed > 1e-4 { rotation = Float(atan2(Double(velocity.y), Double(velocity.x))) }
        delegate?.agentDidUpdate?(self)
    }
}

/// An agent moving in 3D: its behavior's goals steer it in space (the same goals as 2D agents, in x, y and z).
open class GKAgent3D: GKAgent {
    open var position: vector_float3 = .zero
    open internal(set) var velocity: vector_float3 = .zero
    /// the agent's orientation: its third column is its heading (its velocity's direction)
    open var rotation: matrix_float3x3 = matrix_identity_float3x3
    /// whether the rotation's basis is right-handed (default false, as in GameplayKit)
    open var rightHanded = false
    var wanderAngle: Float = 0

    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    open override func update(deltaTime seconds: TimeInterval) {
        delegate?.agentWillUpdate?(self)
        velocity = _gkIntegrate(self, Float(seconds))
        speed = simd_length(velocity)
        position += velocity * Float(seconds)
        if speed > 1e-4 {
            let forward = velocity / speed
            var up = SIMD3<Float>(0, 1, 0)
            if abs(simd_dot(forward, up)) > 0.999 { up = SIMD3(0, 0, 1) }
            var side = simd_normalize(simd_cross(up, forward))
            if !rightHanded { side = -side }
            let realUp = rightHanded ? simd_cross(forward, side) : simd_cross(side, forward)
            rotation = matrix_float3x3(columns: (side, realUp, forward))
        }
        delegate?.agentDidUpdate?(self)
    }
}

/// what goals need from an agent, in 3D (a 2D agent's z is 0)
protocol _GKSteered: AnyObject {
    var _p: SIMD3<Float> { get }
    var _v: SIMD3<Float> { get }
    var _heading: SIMD3<Float> { get }
    var _wander: Float { get set }
    var maxSpeed: Float { get }
    var maxAcceleration: Float { get }
    var radius: Float { get }
    var mass: Float { get }
    var behavior: GKBehavior? { get }
}
extension GKAgent2D: _GKSteered {
    var _p: SIMD3<Float> { SIMD3(position.x, position.y, 0) }
    var _v: SIMD3<Float> { SIMD3(velocity.x, velocity.y, 0) }
    var _heading: SIMD3<Float> { SIMD3(Float(cos(Double(rotation))), Float(sin(Double(rotation))), 0) }
    var _wander: Float { get { wanderAngle } set { wanderAngle = newValue } }
}
extension GKAgent3D: _GKSteered {
    var _p: SIMD3<Float> { position }
    var _v: SIMD3<Float> { velocity }
    var _heading: SIMD3<Float> { rotation.columns.2 }
    var _wander: Float { get { wanderAngle } set { wanderAngle = newValue } }
}
func _gkSteered(_ a: GKAgent) -> _GKSteered? { a as? _GKSteered }

/// the agent's new velocity after its behavior's steering for `dt`
func _gkIntegrate(_ a: _GKSteered, _ dt: Float) -> SIMD3<Float> {
    var steer = a.behavior?._steer(a, dt) ?? .zero
    let acc = simd_length(steer)
    if acc > a.maxAcceleration, acc > 0 { steer *= a.maxAcceleration / acc }
    var v = a._v + steer / max(a.mass, 0.0001) * dt
    let s = simd_length(v)
    if s > a.maxSpeed, s > 0 { v *= a.maxSpeed / s }
    return v
}

/// A steering goal; its force is computed in 3D (2D agents use x and y).
open class GKGoal: NSObject {
    let force: (_GKSteered, Float) -> SIMD3<Float>
    init(_ f: @escaping (_GKSteered, Float) -> SIMD3<Float>) { force = f }

    static func toward(_ a: _GKSteered, _ target: SIMD3<Float>) -> SIMD3<Float> {
        let d = target - a._p
        let l = simd_length(d)
        guard l > 1e-5 else { return .zero }
        return d / l * a.maxSpeed - a._v
    }
    // Apple's initializers (the goals are built by the static functions below)
    @available(*, deprecated, renamed: "init(toSeekAgent:)")
    open class func toSeekAgent(_ agent: GKAgent) -> GKGoal { _toSeekAgent(agent) }
    public convenience init(toSeekAgent agent: GKAgent) { self.init(GKGoal._toSeekAgent(agent).force) }
    @available(*, deprecated, renamed: "init(toFleeAgent:)")
    open class func toFleeAgent(_ agent: GKAgent) -> GKGoal { _toFleeAgent(agent) }
    public convenience init(toFleeAgent agent: GKAgent) { self.init(GKGoal._toFleeAgent(agent).force) }
    @available(*, deprecated, renamed: "init(toInterceptAgent:)")
    open class func toInterceptAgent(_ target: GKAgent, maxPredictionTime: TimeInterval) -> GKGoal { _toInterceptAgent(target, maxPredictionTime: maxPredictionTime) }
    public convenience init(toInterceptAgent target: GKAgent, maxPredictionTime: TimeInterval) { self.init(GKGoal._toInterceptAgent(target, maxPredictionTime: maxPredictionTime).force) }
    @available(*, deprecated, renamed: "init(toReachTargetSpeed:)")
    open class func toReachTargetSpeed(_ target: Float) -> GKGoal { _toReachTargetSpeed(target) }
    public convenience init(toReachTargetSpeed target: Float) { self.init(GKGoal._toReachTargetSpeed(target).force) }
    @available(*, deprecated, renamed: "init(toWander:)")
    open class func toWander(_ speed: Float) -> GKGoal { _toWander(speed) }
    public convenience init(toWander speed: Float) { self.init(GKGoal._toWander(speed).force) }
    @available(*, deprecated, renamed: "init(toAvoid:)")
    open class func toAvoid(_ agents: [GKAgent], maxPredictionTime: TimeInterval) -> GKGoal { _toAvoid(agents, maxPredictionTime: maxPredictionTime) }
    public convenience init(toAvoid agents: [GKAgent], maxPredictionTime: TimeInterval) { self.init(GKGoal._toAvoid(agents, maxPredictionTime: maxPredictionTime).force) }
    public convenience init(toAvoidAgents agents: [GKAgent], maxPredictionTime: TimeInterval) { self.init(GKGoal._toAvoid(agents, maxPredictionTime: maxPredictionTime).force) }
    @available(*, deprecated, renamed: "init(toSeparateFrom:)")
    open class func toSeparate(from agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal { _toSeparate(from: agents, maxDistance: maxDistance, maxAngle: maxAngle) }
    public convenience init(toSeparateFrom agents: [GKAgent], maxDistance: Float, maxAngle: Float) { self.init(GKGoal._toSeparate(from: agents, maxDistance: maxDistance, maxAngle: maxAngle).force) }
    public convenience init(toSeparateFromAgents agents: [GKAgent], maxDistance: Float, maxAngle: Float) { self.init(GKGoal._toSeparate(from: agents, maxDistance: maxDistance, maxAngle: maxAngle).force) }
    @available(*, deprecated, renamed: "init(toAlignWith:)")
    open class func toAlign(with agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal { _toAlign(with: agents, maxDistance: maxDistance, maxAngle: maxAngle) }
    public convenience init(toAlignWith agents: [GKAgent], maxDistance: Float, maxAngle: Float) { self.init(GKGoal._toAlign(with: agents, maxDistance: maxDistance, maxAngle: maxAngle).force) }
    public convenience init(toAlignWithAgents agents: [GKAgent], maxDistance: Float, maxAngle: Float) { self.init(GKGoal._toAlign(with: agents, maxDistance: maxDistance, maxAngle: maxAngle).force) }
    @available(*, deprecated, renamed: "init(toCohereWith:)")
    open class func toCohere(with agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal { _toCohere(with: agents, maxDistance: maxDistance, maxAngle: maxAngle) }
    public convenience init(toCohereWith agents: [GKAgent], maxDistance: Float, maxAngle: Float) { self.init(GKGoal._toCohere(with: agents, maxDistance: maxDistance, maxAngle: maxAngle).force) }
    public convenience init(toCohereWithAgents agents: [GKAgent], maxDistance: Float, maxAngle: Float) { self.init(GKGoal._toCohere(with: agents, maxDistance: maxDistance, maxAngle: maxAngle).force) }
    @available(*, deprecated, renamed: "init(toFollow:)")
    open class func toFollow(_ path: GKPath, maxPredictionTime: TimeInterval, forward: Bool) -> GKGoal { _toFollow(path, maxPredictionTime: maxPredictionTime, forward: forward) }
    public convenience init(toFollow path: GKPath, maxPredictionTime: TimeInterval, forward: Bool) { self.init(GKGoal._toFollow(path, maxPredictionTime: maxPredictionTime, forward: forward).force) }
    public convenience init(toFollowPath path: GKPath, maxPredictionTime: TimeInterval, forward: Bool) { self.init(GKGoal._toFollow(path, maxPredictionTime: maxPredictionTime, forward: forward).force) }
    @available(*, deprecated, renamed: "init(toStayOn:)")
    open class func toStayOn(_ path: GKPath, maxPredictionTime: TimeInterval) -> GKGoal { _toStayOn(path, maxPredictionTime: maxPredictionTime) }
    public convenience init(toStayOn path: GKPath, maxPredictionTime: TimeInterval) { self.init(GKGoal._toStayOn(path, maxPredictionTime: maxPredictionTime).force) }
    public convenience init(toStayOnPath path: GKPath, maxPredictionTime: TimeInterval) { self.init(GKGoal._toStayOn(path, maxPredictionTime: maxPredictionTime).force) }
    static func _toSeekAgent(_ agent: GKAgent) -> GKGoal {
        GKGoal { a, _ in _gkSteered(agent).map { toward(a, $0._p) } ?? .zero }
    }
    static func _toFleeAgent(_ agent: GKAgent) -> GKGoal {
        GKGoal { a, _ in _gkSteered(agent).map { -toward(a, $0._p) } ?? .zero }
    }
    static func _toInterceptAgent(_ target: GKAgent, maxPredictionTime: TimeInterval) -> GKGoal {
        GKGoal { a, _ in
            guard let t = _gkSteered(target) else { return .zero }
            let dist = simd_length(t._p - a._p)
            let time = min(Float(maxPredictionTime), dist / max(a.maxSpeed, 0.0001))
            return toward(a, t._p + t._v * time)
        }
    }
    static func _toReachTargetSpeed(_ target: Float) -> GKGoal {
        GKGoal { a, _ in
            let s = simd_length(a._v)
            let dir = s > 1e-5 ? a._v / s : a._heading
            return dir * (target - s)
        }
    }
    static func _toWander(_ speed: Float) -> GKGoal {
        GKGoal { a, dt in
            a._wander += Float.random(in: -1...1) * 2 * max(dt, 0.016)
            let h = a._heading, w = a._wander * 0.3
            // turn the heading about the up axis (z for 2D agents, y in 3D)
            let up: SIMD3<Float> = a is GKAgent2D ? SIMD3(0, 0, 1) : SIMD3(0, 1, 0)
            let turned = h * cos(w) + simd_cross(up, h) * sin(w) + up * simd_dot(up, h) * (1 - cos(w))
            return turned * speed - a._v * 0.1
        }
    }
    static func _toAvoid(_ agents: [GKAgent], maxPredictionTime: TimeInterval) -> GKGoal {
        GKGoal { a, _ in
            var f = SIMD3<Float>.zero
            for o in agents.compactMap(_gkSteered) where o !== a {
                let future = (o._p + o._v * Float(maxPredictionTime)) - (a._p + a._v * Float(maxPredictionTime))
                let d = simd_length(future), r = a.radius + o.radius
                if d < r * 2, d > 1e-5 { f -= future / d * (r * 2 - d) / (r * 2) * a.maxAcceleration }
            }
            return f
        }
    }
    static func _toSeparate(from agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal {
        GKGoal { a, _ in
            var f = SIMD3<Float>.zero
            for o in agents.compactMap(_gkSteered) where o !== a {
                let d = a._p - o._p, l = simd_length(d)
                if l < maxDistance, l > 1e-5 { f += d / l * (maxDistance - l) / maxDistance }
            }
            return f * a.maxAcceleration
        }
    }
    static func _toAlign(with agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal {
        GKGoal { a, _ in
            var sum = SIMD3<Float>.zero, n: Float = 0
            for o in agents.compactMap(_gkSteered) where o !== a && simd_distance(o._p, a._p) < maxDistance { sum += o._v; n += 1 }
            return n > 0 ? sum / n - a._v : .zero
        }
    }
    static func _toCohere(with agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal {
        GKGoal { a, _ in
            var sum = SIMD3<Float>.zero, n: Float = 0
            for o in agents.compactMap(_gkSteered) where o !== a && simd_distance(o._p, a._p) < maxDistance { sum += o._p; n += 1 }
            return n > 0 ? toward(a, sum / n) : .zero
        }
    }
    static func _toFollow(_ path: GKPath, maxPredictionTime: TimeInterval, forward: Bool) -> GKGoal {
        GKGoal { a, _ in
            guard let target = path.nextPoint(after: a._p + a._v * Float(maxPredictionTime), forward: forward) else { return .zero }
            return toward(a, target)
        }
    }
    static func _toStayOn(_ path: GKPath, maxPredictionTime: TimeInterval) -> GKGoal {
        GKGoal { a, _ in
            let future = a._p + a._v * Float(maxPredictionTime)
            guard let (closest, dist) = path.closest(to: future), dist > path.radius else { return .zero }
            return toward(a, closest)
        }
    }
}

/// A polyline agents follow or stay on, in 2D or 3D.
open class GKPath: NSObject {
    open var radius: Float
    open private(set) var numPoints: Int
    open var isCyclical: Bool
    var points: [SIMD3<Float>]
    public init(points: [vector_float2], radius: Float, cyclical: Bool) {
        self.points = points.map { SIMD3($0.x, $0.y, 0) }; self.radius = radius; isCyclical = cyclical; numPoints = points.count
        super.init()
    }
    public init(float3Points points: [vector_float3], radius: Float, cyclical: Bool) {
        self.points = points; self.radius = radius; isCyclical = cyclical; numPoints = points.count
        super.init()
    }
    public convenience init(graphNodes: [GKGraphNode], radius: Float) {
        if graphNodes.contains(where: { $0 is GKGraphNode3D }) {
            self.init(float3Points: graphNodes.compactMap { ($0 as? GKGraphNode3D)?.position }, radius: radius, cyclical: false)
        } else {
            self.init(points: graphNodes.compactMap { ($0 as? GKGraphNode2D)?.position }, radius: radius, cyclical: false)
        }
    }
    open func float2(at index: Int) -> vector_float2 { let p = points[index]; return vector_float2(p.x, p.y) }
    open func float3(at index: Int) -> vector_float3 { points[index] }
    var segments: [(SIMD3<Float>, SIMD3<Float>)] {
        guard points.count > 1 else { return [] }
        var s = (0..<(points.count - 1)).map { (points[$0], points[$0 + 1]) }
        if isCyclical { s.append((points[points.count - 1], points[0])) }
        return s
    }
    func closest(to p: SIMD3<Float>) -> (SIMD3<Float>, Float)? {
        var best: (SIMD3<Float>, Float)?
        for (a, b) in segments {
            let e = b - a, l2 = simd_length_squared(e)
            let t = l2 > 0 ? max(0, min(1, simd_dot(p - a, e) / l2)) : 0
            let q = a + e * t, d = simd_distance(p, q)
            if best == nil || d < best!.1 { best = (q, d) }
        }
        return best
    }
    func nextPoint(after p: SIMD3<Float>, forward: Bool) -> SIMD3<Float>? {
        guard let (q, _) = closest(to: p) else { return points.first }
        let order = forward ? points : points.reversed()
        // the next waypoint beyond the closest point
        var best: SIMD3<Float>?
        var bestD = Float.infinity
        for w in order { let d = simd_distance(w, q); if d < bestD && d > radius { bestD = d; best = w } }
        return best ?? order.last
    }
}

/// Goals and their weights; an agent steers by their weighted sum.
open class GKBehavior: NSObject {
    var goals: [GKGoal] = []
    var weights: [Float] = []
    public override init() { super.init() }
    public convenience init(goal: GKGoal, weight: Float) { self.init(); setWeight(weight, for: goal) }
    public convenience init(goals: [GKGoal]) { self.init(); for g in goals { setWeight(1, for: g) } }
    public convenience init(goals: [GKGoal], andWeights weights: [NSNumber]) {
        self.init(); for (g, w) in zip(goals, weights) { setWeight(w.floatValue, for: g) }
    }
    public convenience init(weightedGoals: [GKGoal: NSNumber]) { self.init(); for (g, w) in weightedGoals { setWeight(w.floatValue, for: g) } }
    open var goalCount: Int { goals.count }
    open func setWeight(_ weight: Float, for goal: GKGoal) {
        if let i = goals.firstIndex(where: { $0 === goal }) { weights[i] = weight } else { goals.append(goal); weights.append(weight) }
    }
    open func weight(for goal: GKGoal) -> Float { goals.firstIndex { $0 === goal }.map { weights[$0] } ?? 0 }
    open func remove(_ goal: GKGoal) { if let i = goals.firstIndex(where: { $0 === goal }) { goals.remove(at: i); weights.remove(at: i) } }
    open func removeAllGoals() { goals.removeAll(); weights.removeAll() }
    open subscript(idx: Int) -> GKGoal { goals[idx] }
    open subscript(goal: GKGoal) -> NSNumber {
        get { NSNumber(value: weight(for: goal)) }
        set { setWeight(newValue.floatValue, for: goal) }
    }
    /// the weighted sum of the goals' forces
    func _steer(_ a: _GKSteered, _ dt: Float) -> SIMD3<Float> {
        var f = SIMD3<Float>.zero
        for (g, w) in zip(goals, weights) where w != 0 { f += g.force(a, dt) * w }
        return f
    }
}

/// A behavior made of weighted behaviors (and goals of its own): the agent steers by the sum of their forces.
open class GKCompositeBehavior: GKBehavior {
    var behaviors: [GKBehavior] = []
    var behaviorWeights: [Float] = []
    public override init() { super.init() }
    public convenience init(behaviors: [GKBehavior]) { self.init(); for b in behaviors { setWeight(1, for: b) } }
    public convenience init(behaviors: [GKBehavior], andWeights weights: [NSNumber]) {
        self.init(); for (b, w) in zip(behaviors, weights) { setWeight(w.floatValue, for: b) }
    }
    open var behaviorCount: Int { behaviors.count }
    open func setWeight(_ weight: Float, for behavior: GKBehavior) {
        if let i = behaviors.firstIndex(where: { $0 === behavior }) { behaviorWeights[i] = weight }
        else { behaviors.append(behavior); behaviorWeights.append(weight) }
    }
    open func weight(for behavior: GKBehavior) -> Float { behaviors.firstIndex { $0 === behavior }.map { behaviorWeights[$0] } ?? 0 }
    open func remove(_ behavior: GKBehavior) {
        if let i = behaviors.firstIndex(where: { $0 === behavior }) { behaviors.remove(at: i); behaviorWeights.remove(at: i) }
    }
    open func removeAllBehaviors() { behaviors.removeAll(); behaviorWeights.removeAll() }
    open subscript(idx: Int) -> GKBehavior { behaviors[idx] }
    open subscript(behavior: GKBehavior) -> NSNumber {
        get { NSNumber(value: weight(for: behavior)) }
        set { setWeight(newValue.floatValue, for: behavior) }
    }
    override func _steer(_ a: _GKSteered, _ dt: Float) -> SIMD3<Float> {
        var f = super._steer(a, dt)
        for (b, w) in zip(behaviors, behaviorWeights) where w != 0 { f += b._steer(a, dt) * w }
        return f
    }
}

// MARK: - Rule systems

open class GKRule: NSObject {
    open var salience: Int = 0
    let _predicate: (GKRuleSystem) -> Bool
    let _action: (GKRuleSystem) -> Void
    init(_predicate: @escaping (GKRuleSystem) -> Bool, action: @escaping (GKRuleSystem) -> Void) { self._predicate = _predicate; self._action = action }
    public convenience init(blockPredicate predicate: @escaping (GKRuleSystem) -> Bool, action: @escaping (GKRuleSystem) -> Void) {
        self.init(_predicate: predicate, action: action)
    }
    /// asserts the fact with the grade when the predicate (evaluated with the rule system) is true
    public convenience init(predicate: NSPredicate, assertingFact fact: NSObjectProtocol, grade: Float) {
        self.init(_predicate: { predicate.evaluate(with: $0) }, action: { $0.assertFact(fact as! NSObject, grade: grade) })
    }
    /// retracts the grade from the fact when the predicate (evaluated with the rule system) is true
    public convenience init(predicate: NSPredicate, retractingFact fact: NSObjectProtocol, grade: Float) {
        self.init(_predicate: { predicate.evaluate(with: $0) }, action: { $0.retractFact(fact as! NSObject, grade: grade) })
    }
    public override init() { _predicate = { _ in false }; _action = { _ in }; super.init() }
    open func evaluatePredicate(in system: GKRuleSystem) -> Bool { _predicate(system) }
    open func performAction(in system: GKRuleSystem) { _action(system) }
}

/// A rule whose predicate is an NSPredicate evaluated with the rule system (key paths such as `state.level`);
/// subclasses override performAction(in:).
open class GKNSPredicateRule: GKRule {
    open var predicate: NSPredicate
    public init(predicate: NSPredicate) { self.predicate = predicate; super.init() }
    open override func evaluatePredicate(in system: GKRuleSystem) -> Bool { predicate.evaluate(with: system) }
}

open class GKRuleSystem: NSObject {
    @objc open private(set) var state = NSMutableDictionary()
    open private(set) var rules: [GKRule] = []
    open private(set) var agenda: [GKRule] = []
    open private(set) var executed: [GKRule] = []
    open private(set) var facts: [AnyHashable] = []
    var grades: [AnyHashable: Float] = [:]
    public override init() { super.init() }

    open func add(_ rule: GKRule) { rules.append(rule); agenda.append(rule); sortAgenda() }
    open func add(_ rules: [GKRule]) { for r in rules { add(r) } }
    open func removeAllRules() { rules.removeAll(); agenda.removeAll() }
    func sortAgenda() { agenda.sort { $0.salience > $1.salience } }
    open func reset() { agenda = rules; sortAgenda(); executed.removeAll(); facts.removeAll(); grades.removeAll() }
    /// runs rules (highest salience first) until none of the remaining ones applies
    open func evaluate() {
        var fired = true
        while fired {
            fired = false
            for (i, r) in agenda.enumerated() where r.evaluatePredicate(in: self) {
                agenda.remove(at: i); executed.append(r)
                r.performAction(in: self)
                fired = true
                break
            }
        }
    }
    open func grade(forFact fact: AnyHashable) -> Float { grades[fact] ?? 0 }
    open func minimumGrade(forFacts facts: [AnyHashable]) -> Float { facts.map { grade(forFact: $0) }.min() ?? 0 }
    open func maximumGrade(forFacts facts: [AnyHashable]) -> Float { facts.map { grade(forFact: $0) }.max() ?? 0 }
    open func assertFact(_ fact: AnyHashable) { assertFact(fact, grade: 1) }
    open func assertFact(_ fact: AnyHashable, grade: Float) {
        let g = min(1, (grades[fact] ?? 0) + grade)
        grades[fact] = g
        if !facts.contains(fact) { facts.append(fact) }
    }
    open func retractFact(_ fact: AnyHashable) { retractFact(fact, grade: 1) }
    open func retractFact(_ fact: AnyHashable, grade: Float) {
        let g = max(0, (grades[fact] ?? 0) - grade)
        grades[fact] = g
        if g <= 0 { facts.removeAll { $0 == fact }; grades[fact] = nil }
    }
}
