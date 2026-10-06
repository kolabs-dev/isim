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
        let dt = Float(seconds)
        var steer = vector_float2.zero
        if let b = behavior {
            for (g, w) in zip(b.goals, b.weights) where w != 0 { steer += g.force(for: self, dt) * w }
        }
        let a = simd_length(steer)
        if a > maxAcceleration, a > 0 { steer *= maxAcceleration / a }
        velocity += steer / max(mass, 0.0001) * dt
        let s = simd_length(velocity)
        if s > maxSpeed, s > 0 { velocity *= maxSpeed / s }
        speed = simd_length(velocity)
        position += velocity * dt
        if speed > 1e-4 { rotation = Float(atan2(Double(velocity.y), Double(velocity.x))) }
        delegate?.agentDidUpdate?(self)
    }
}

/// A steering goal; forces are computed for 2D agents.
open class GKGoal: NSObject {
    let force: (GKAgent2D, Float) -> vector_float2
    init(_ f: @escaping (GKAgent2D, Float) -> vector_float2) { force = f }
    func force(for a: GKAgent2D, _ dt: Float) -> vector_float2 { force(a, dt) }

    static func toward(_ a: GKAgent2D, _ target: vector_float2) -> vector_float2 {
        let d = target - a.position
        let l = simd_length(d)
        guard l > 1e-5 else { return .zero }
        return d / l * a.maxSpeed - a.velocity
    }
    open class func toSeekAgent(_ agent: GKAgent) -> GKGoal {
        GKGoal { a, _ in (agent as? GKAgent2D).map { toward(a, $0.position) } ?? .zero }
    }
    open class func toFleeAgent(_ agent: GKAgent) -> GKGoal {
        GKGoal { a, _ in (agent as? GKAgent2D).map { -toward(a, $0.position) } ?? .zero }
    }
    open class func toInterceptAgent(_ target: GKAgent, maxPredictionTime: TimeInterval) -> GKGoal {
        GKGoal { a, _ in
            guard let t = target as? GKAgent2D else { return .zero }
            let dist = simd_length(t.position - a.position)
            let time = min(Float(maxPredictionTime), dist / max(a.maxSpeed, 0.0001))
            return toward(a, t.position + t.velocity * time)
        }
    }
    open class func toReachTargetSpeed(_ target: Float) -> GKGoal {
        GKGoal { a, _ in
            let s = simd_length(a.velocity)
            let dir = s > 1e-5 ? a.velocity / s : vector_float2(Float(cos(Double(a.rotation))), Float(sin(Double(a.rotation))))
            return dir * (target - s)
        }
    }
    open class func toWander(_ speed: Float) -> GKGoal {
        GKGoal { a, dt in
            a.wanderAngle += Float.random(in: -1...1) * 2 * max(dt, 0.016)
            let heading = a.rotation + a.wanderAngle * 0.3
            return vector_float2(Float(cos(Double(heading))), Float(sin(Double(heading)))) * speed - a.velocity * 0.1
        }
    }
    open class func toAvoid(_ agents: [GKAgent], maxPredictionTime: TimeInterval) -> GKGoal {
        GKGoal { a, _ in
            var f = vector_float2.zero
            for case let o as GKAgent2D in agents where o !== a {
                let future = (o.position + o.velocity * Float(maxPredictionTime)) - (a.position + a.velocity * Float(maxPredictionTime))
                let d = simd_length(future), r = a.radius + o.radius
                if d < r * 2, d > 1e-5 { f -= future / d * (r * 2 - d) / (r * 2) * a.maxAcceleration }
            }
            return f
        }
    }
    open class func toSeparate(from agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal {
        GKGoal { a, _ in
            var f = vector_float2.zero
            for case let o as GKAgent2D in agents where o !== a {
                let d = a.position - o.position, l = simd_length(d)
                if l < maxDistance, l > 1e-5 { f += d / l * (maxDistance - l) / maxDistance }
            }
            return f * a.maxAcceleration
        }
    }
    open class func toAlign(with agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal {
        GKGoal { a, _ in
            var sum = vector_float2.zero, n: Float = 0
            for case let o as GKAgent2D in agents where o !== a && simd_distance(o.position, a.position) < maxDistance { sum += o.velocity; n += 1 }
            return n > 0 ? sum / n - a.velocity : .zero
        }
    }
    open class func toCohere(with agents: [GKAgent], maxDistance: Float, maxAngle: Float) -> GKGoal {
        GKGoal { a, _ in
            var sum = vector_float2.zero, n: Float = 0
            for case let o as GKAgent2D in agents where o !== a && simd_distance(o.position, a.position) < maxDistance { sum += o.position; n += 1 }
            return n > 0 ? toward(a, sum / n) : .zero
        }
    }
    open class func toFollow(_ path: GKPath, maxPredictionTime: TimeInterval, forward: Bool) -> GKGoal {
        GKGoal { a, _ in
            guard let target = path.nextPoint(after: a.position + a.velocity * Float(maxPredictionTime), forward: forward) else { return .zero }
            return toward(a, target)
        }
    }
    open class func toStayOn(_ path: GKPath, maxPredictionTime: TimeInterval) -> GKGoal {
        GKGoal { a, _ in
            let future = a.position + a.velocity * Float(maxPredictionTime)
            guard let (closest, dist) = path.closest(to: future), dist > path.radius else { return .zero }
            return toward(a, closest)
        }
    }
}

open class GKPath: NSObject {
    open var radius: Float
    open private(set) var numPoints: Int
    open var isCyclical: Bool
    var points: [vector_float2]
    public init(points: [vector_float2], radius: Float, cyclical: Bool) {
        self.points = points; self.radius = radius; isCyclical = cyclical; numPoints = points.count
        super.init()
    }
    public convenience init(graphNodes: [GKGraphNode], radius: Float) {
        self.init(points: graphNodes.compactMap { ($0 as? GKGraphNode2D)?.position }, radius: radius, cyclical: false)
    }
    open func float2(at index: Int) -> vector_float2 { points[index] }
    var segments: [(vector_float2, vector_float2)] {
        guard points.count > 1 else { return [] }
        var s = (0..<(points.count - 1)).map { (points[$0], points[$0 + 1]) }
        if isCyclical { s.append((points[points.count - 1], points[0])) }
        return s
    }
    func closest(to p: vector_float2) -> (vector_float2, Float)? {
        var best: (vector_float2, Float)?
        for (a, b) in segments {
            let e = b - a, l2 = simd_length_squared(e)
            let t = l2 > 0 ? max(0, min(1, simd_dot(p - a, e) / l2)) : 0
            let q = a + e * t, d = simd_distance(p, q)
            if best == nil || d < best!.1 { best = (q, d) }
        }
        return best
    }
    func nextPoint(after p: vector_float2, forward: Bool) -> vector_float2? {
        guard let (q, _) = closest(to: p) else { return points.first }
        let order = forward ? points : points.reversed()
        // the next waypoint beyond the closest point
        var best: vector_float2?
        var bestD = Float.infinity
        for w in order { let d = simd_distance(w, q); if d < bestD && d > radius { bestD = d; best = w } }
        return best ?? order.last
    }
}

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
}

// MARK: - Rule systems

open class GKRule: NSObject {
    open var salience: Int = 0
    let predicate: (GKRuleSystem) -> Bool
    let action: (GKRuleSystem) -> Void
    init(predicate: @escaping (GKRuleSystem) -> Bool, action: @escaping (GKRuleSystem) -> Void) { self.predicate = predicate; self.action = action }
    public convenience init(blockPredicate predicate: @escaping (GKRuleSystem) -> Bool, action: @escaping (GKRuleSystem) -> Void) {
        self.init(predicate: predicate, action: action)
    }
    public convenience override init() { self.init(predicate: { _ in false }, action: { _ in }) }
    open func evaluatePredicate(in system: GKRuleSystem) -> Bool { predicate(system) }
    open func performAction(in system: GKRuleSystem) { action(system) }
}

open class GKRuleSystem: NSObject {
    open private(set) var state = NSMutableDictionary()
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
