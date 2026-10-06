// isim GameplayKit, self-authored (pure Swift): state machines, entities and components, random sources and
// distributions, graphs with A* pathfinding, noise, agents with goals, and rule systems.
// Obstacle / mesh graphs (GKNavigation.swift), strategists and decision trees (GKStrategy.swift), spatial trees (GKSpatial.swift).
// Not implemented: SceneKit components.
@_exported import Foundation
@_exported import simd
import SpriteKit
import ObjectiveC

// MARK: - State machines

open class GKState: NSObject {
    open internal(set) weak var stateMachine: GKStateMachine?
    public override init() { super.init() }
    open func isValidNextState(_ stateClass: AnyClass) -> Bool { true }
    open func didEnter(from previousState: GKState?) {}
    open func update(deltaTime seconds: TimeInterval) {}
    open func willExit(to nextState: GKState) {}
}

open class GKStateMachine: NSObject {
    open private(set) var currentState: GKState?
    var states: [GKState]

    public init(states: [GKState]) {
        self.states = states
        super.init()
        for s in states { s.stateMachine = self }
    }
    open func update(deltaTime sec: TimeInterval) { currentState?.update(deltaTime: sec) }
    open func state<StateType: GKState>(forClass stateClass: StateType.Type) -> StateType? {
        states.first { type(of: $0) == stateClass } as? StateType
    }
    func find(_ cls: AnyClass) -> GKState? { states.first { ObjectIdentifier(type(of: $0)) == ObjectIdentifier(cls) } }
    open func canEnterState(_ stateClass: AnyClass) -> Bool {
        guard find(stateClass) != nil else { return false }
        return currentState?.isValidNextState(stateClass) ?? true
    }
    @discardableResult open func enter(_ stateClass: AnyClass) -> Bool {
        guard canEnterState(stateClass), let next = find(stateClass) else { return false }
        let previous = currentState
        previous?.willExit(to: next)
        currentState = next
        next.didEnter(from: previous)
        return true
    }
}

// MARK: - Entities & components

open class GKComponent: NSObject {
    open internal(set) weak var entity: GKEntity?
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init() }
    open func update(deltaTime seconds: TimeInterval) {}
    open func didAddToEntity() {}
    open func willRemoveFromEntity() {}
}

open class GKEntity: NSObject {
    open private(set) var components: [GKComponent] = []
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init() }
    open func update(deltaTime seconds: TimeInterval) { for c in components { c.update(deltaTime: seconds) } }
    /// adds a component, replacing one of the same class
    open func addComponent(_ component: GKComponent) {
        if let i = components.firstIndex(where: { type(of: $0) == type(of: component) }) {
            components[i].willRemoveFromEntity(); components[i].entity = nil
            components.remove(at: i)
        }
        component.entity = self
        components.append(component)
        component.didAddToEntity()
    }
    open func removeComponent<ComponentType: GKComponent>(ofType componentClass: ComponentType.Type) {
        guard let i = components.firstIndex(where: { type(of: $0) == componentClass }) else { return }
        let c = components.remove(at: i)
        c.willRemoveFromEntity(); c.entity = nil
    }
    open func component<ComponentType: GKComponent>(ofType componentClass: ComponentType.Type) -> ComponentType? {
        components.first { type(of: $0) == componentClass } as? ComponentType
    }
    open override func copy() -> Any { let e = GKEntity(); e.components = components; return e }
}

open class GKComponentSystem<ComponentType: GKComponent>: NSObject {
    open private(set) var componentClass: AnyClass
    open private(set) var components: [ComponentType] = []
    public init(componentClass cls: AnyClass) { componentClass = cls; super.init() }
    open subscript(idx: Int) -> ComponentType { components[idx] }
    func matches(_ c: GKComponent) -> Bool { c.isKind(of: componentClass) }
    open func addComponent(_ c: ComponentType) { if !components.contains(where: { $0 === c }) { components.append(c) } }
    open func addComponent(foundIn entity: GKEntity) {
        for c in entity.components where matches(c) { if let t = c as? ComponentType { addComponent(t) } }
    }
    open func removeComponent(_ c: ComponentType) { components.removeAll { $0 === c } }
    open func removeComponent(foundIn entity: GKEntity) { components.removeAll { $0.entity === entity } }
    open func update(deltaTime sec: TimeInterval) { for c in components { c.update(deltaTime: sec) } }
    open func classForGenericArgument(at index: Int) -> AnyClass { componentClass }
}

/// A component holding a SpriteKit node (its entity is set on the node).
open class GKSKNodeComponent: GKComponent, GKAgentDelegate {
    open var node: SKNode { didSet { node.entity = entity } }
    public init(node: SKNode) { self.node = node; super.init() }
    public required init?(coder: NSCoder) { node = SKNode(); super.init(coder: coder) }
    open override func didAddToEntity() { node.entity = entity }
    open override func willRemoveFromEntity() { node.entity = nil }
    // as an agent delegate: the agent follows the node, the node follows the agent
    open func agentWillUpdate(_ agent: GKAgent) {
        if let a = agent as? GKAgent2D { a.position = vector_float2(Float(node.position.x), Float(node.position.y)) }
    }
    open func agentDidUpdate(_ agent: GKAgent) {
        if let a = agent as? GKAgent2D { node.position = CGPoint(x: CGFloat(a.position.x), y: CGFloat(a.position.y)); node.zRotation = CGFloat(a.rotation) }
    }
}

final class _GKWeakEntity: NSObject { weak var value: GKEntity?; init(_ e: GKEntity?) { value = e } }
nonisolated(unsafe) private var _gkEntityKey: UInt8 = 0

extension SKNode {
    /// the GameplayKit entity this node belongs to (weak)
    public var entity: GKEntity? {
        get { (objc_getAssociatedObject(self, &_gkEntityKey) as? _GKWeakEntity)?.value }
        set { objc_setAssociatedObject(self, &_gkEntityKey, _GKWeakEntity(newValue), 1 /* OBJC_ASSOCIATION_RETAIN_NONATOMIC */) }
    }
}

// MARK: - Random

public protocol GKRandom {
    func nextInt() -> Int
    func nextInt(upperBound: Int) -> Int
    func nextUniform() -> Float
    func nextBool() -> Bool
}

open class GKRandomSource: NSObject, GKRandom {
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init() }
    nonisolated(unsafe) static let shared = GKRandomSource()
    open class func sharedRandom() -> GKRandomSource { shared }

    /// 32 random bits (subclasses override)
    func next32() -> UInt32 { UInt32.random(in: .min ... .max) }

    /// a value in the 32-bit signed range
    open func nextInt() -> Int { Int(Int32(bitPattern: next32())) }
    /// a value in 0 ..< upperBound
    open func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        let n = UInt64(upperBound)
        // rejection sampling: no modulo bias
        let limit = (UInt64(1) << 32) - (UInt64(1) << 32) % n
        while true {
            let v = UInt64(next32())
            if v < limit { return Int(v % n) }
        }
    }
    open func nextUniform() -> Float { Float(next32() >> 8) / Float(1 << 24) }
    open func nextBool() -> Bool { next32() & 1 == 1 }
    open func arrayByShufflingObjects(in array: [Any]) -> [Any] {
        var a = array
        if a.count > 1 { for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, nextInt(upperBound: i + 1)) } }
        return a
    }
}

/// RC4 keystream generator.
open class GKARC4RandomSource: GKRandomSource {
    var s = [UInt8](repeating: 0, count: 256)
    var i: UInt8 = 0, j: UInt8 = 0
    open var seed: Data { didSet { reseed() } }

    public override init() {
        seed = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        super.init(); reseed()
    }
    public init(seed: Data) { self.seed = seed; super.init(); reseed() }
    public required init?(coder: NSCoder) { seed = Data([0]); super.init(coder: coder); reseed() }
    func reseed() {
        let key = seed.isEmpty ? [UInt8(0)] : [UInt8](seed)
        for k in 0..<256 { s[k] = UInt8(k) }
        var jj = 0
        for k in 0..<256 { jj = (jj + Int(s[k]) + Int(key[k % key.count])) & 255; s.swapAt(k, jj) }
        i = 0; j = 0
    }
    func nextByte() -> UInt8 {
        i &+= 1; j &+= s[Int(i)]
        s.swapAt(Int(i), Int(j))
        return s[Int(s[Int(i)] &+ s[Int(j)])]
    }
    override func next32() -> UInt32 {
        UInt32(nextByte()) << 24 | UInt32(nextByte()) << 16 | UInt32(nextByte()) << 8 | UInt32(nextByte())
    }
    /// discards values from the start of the sequence (RC4's early output is weak; 768+ is customary)
    open func dropValues(_ count: Int) { for _ in 0..<max(0, count) { _ = nextByte() } }
}

/// MT19937 (32-bit Mersenne Twister) seeded from a 64-bit value.
open class GKMersenneTwisterRandomSource: GKRandomSource {
    var mt = [UInt32](repeating: 0, count: 624)
    var index = 624
    open var seed: UInt64 { didSet { reseed() } }
    public override init() { seed = UInt64.random(in: .min ... .max); super.init(); reseed() }
    public init(seed: UInt64) { self.seed = seed; super.init(); reseed() }
    public required init?(coder: NSCoder) { seed = 0; super.init(coder: coder); reseed() }
    func reseed() {
        mt[0] = UInt32(truncatingIfNeeded: seed ^ (seed >> 32))
        for k in 1..<624 { mt[k] = 1812433253 &* (mt[k - 1] ^ (mt[k - 1] >> 30)) &+ UInt32(k) }
        index = 624
    }
    override func next32() -> UInt32 {
        if index >= 624 {
            for k in 0..<624 {
                let y = (mt[k] & 0x8000_0000) | (mt[(k + 1) % 624] & 0x7fff_ffff)
                mt[k] = mt[(k + 397) % 624] ^ (y >> 1) ^ (y & 1 == 1 ? 0x9908_b0df : 0)
            }
            index = 0
        }
        var y = mt[index]; index += 1
        y ^= y >> 11; y ^= (y << 7) & 0x9d2c_5680; y ^= (y << 15) & 0xefc6_0000; y ^= y >> 18
        return y
    }
}

/// 64-bit linear congruential generator (fast, low quality), high 32 bits of each state.
open class GKLinearCongruentialRandomSource: GKRandomSource {
    var state: UInt64
    open var seed: UInt64 { didSet { state = seed } }
    public override init() { seed = UInt64.random(in: .min ... .max); state = seed; super.init() }
    public init(seed: UInt64) { self.seed = seed; state = seed; super.init() }
    public required init?(coder: NSCoder) { seed = 0; state = 0; super.init(coder: coder) }
    override func next32() -> UInt32 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt32(truncatingIfNeeded: state >> 32)
    }
}

open class GKRandomDistribution: NSObject, GKRandom {
    public let source: GKRandom
    open private(set) var lowestValue: Int
    open private(set) var highestValue: Int
    open var numberOfPossibleOutcomes: Int { highestValue - lowestValue + 1 }

    public required init(randomSource source: GKRandom, lowestValue: Int, highestValue: Int) {
        self.source = source; self.lowestValue = min(lowestValue, highestValue); self.highestValue = max(lowestValue, highestValue)
        super.init()
    }
    public convenience init(lowestValue: Int, highestValue: Int) {
        self.init(randomSource: GKARC4RandomSource(), lowestValue: lowestValue, highestValue: highestValue)
    }
    public convenience init(forDieWithSideCount sideCount: Int) { self.init(lowestValue: 1, highestValue: sideCount) }
    open class func d6() -> Self { Self(randomSource: GKARC4RandomSource(), lowestValue: 1, highestValue: 6) }
    open class func d20() -> Self { Self(randomSource: GKARC4RandomSource(), lowestValue: 1, highestValue: 20) }

    open func nextInt() -> Int { lowestValue + source.nextInt(upperBound: numberOfPossibleOutcomes) }
    open func nextInt(upperBound: Int) -> Int { min(nextInt(), lowestValue + max(0, upperBound - 1)) }
    open func nextUniform() -> Float {
        let n = numberOfPossibleOutcomes
        return n <= 1 ? 0 : Float(nextInt() - lowestValue) / Float(n - 1)
    }
    open func nextBool() -> Bool { nextUniform() >= 0.5 }
}

/// Normal distribution clamped to mean +/- 3 deviations.
open class GKGaussianDistribution: GKRandomDistribution {
    open private(set) var mean: Float
    open private(set) var deviation: Float

    public required init(randomSource source: GKRandom, lowestValue: Int, highestValue: Int) {
        mean = Float(lowestValue + highestValue) / 2
        deviation = Float(highestValue - lowestValue) / 6
        super.init(randomSource: source, lowestValue: lowestValue, highestValue: highestValue)
    }
    public init(randomSource source: GKRandom, mean: Float, deviation: Float) {
        self.mean = mean; self.deviation = deviation
        super.init(randomSource: source, lowestValue: Int((mean - 3 * deviation).rounded()), highestValue: Int((mean + 3 * deviation).rounded()))
    }
    open override func nextInt() -> Int {
        // Box-Muller
        let u1 = max(Double.leastNonzeroMagnitude, Double(source.nextUniform())), u2 = Double(source.nextUniform())
        let z = (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
        let v = Int((Double(mean) + z * Double(deviation)).rounded())
        return min(max(v, lowestValue), highestValue)
    }
}

/// Uniform, but avoids repeating values: every outcome comes once per shuffled round.
open class GKShuffledDistribution: GKRandomDistribution {
    var bag: [Int] = []
    open override func nextInt() -> Int {
        if bag.isEmpty {
            bag = Array(lowestValue...highestValue)
            if bag.count > 1 { for i in stride(from: bag.count - 1, to: 0, by: -1) { bag.swapAt(i, source.nextInt(upperBound: i + 1)) } }
        }
        return bag.removeLast()
    }
}

extension Array {
    /// GameplayKit: a shuffled copy using a random source
    public func shuffled(using source: GKRandomSource) -> [Element] {
        source.arrayByShufflingObjects(in: self).compactMap { $0 as? Element }
    }
}

// MARK: - Graphs and pathfinding

open class GKGraphNode: NSObject {
    open internal(set) var connectedNodes: [GKGraphNode] = []
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init() }
    open func addConnections(to nodes: [GKGraphNode], bidirectional: Bool) {
        for n in nodes where n !== self {
            if !connectedNodes.contains(where: { $0 === n }) { connectedNodes.append(n) }
            if bidirectional, !n.connectedNodes.contains(where: { $0 === self }) { n.connectedNodes.append(self) }
        }
    }
    open func removeConnections(to nodes: [GKGraphNode], bidirectional: Bool) {
        for n in nodes {
            connectedNodes.removeAll { $0 === n }
            if bidirectional { n.connectedNodes.removeAll { $0 === self } }
        }
    }
    open func estimatedCost(to node: GKGraphNode) -> Float { 0 }
    open func cost(to node: GKGraphNode) -> Float { 1 }
    open func findPath(to goalNode: GKGraphNode) -> [GKGraphNode] { _gkAStar(from: self, to: goalNode) }
    open func findPath(from startNode: GKGraphNode) -> [GKGraphNode] { _gkAStar(from: startNode, to: self) }
}

open class GKGraphNode2D: GKGraphNode {
    open var position: vector_float2
    public init(point: vector_float2) { position = point; super.init() }
    /// lets graphs create nodes of an app's subclass (GKObstacleGraph / GKMeshGraph nodeClass)
    public convenience override init() { self.init(point: .zero) }
    public required init?(coder: NSCoder) { position = .zero; super.init(coder: coder) }
    open override func cost(to node: GKGraphNode) -> Float {
        guard let n = node as? GKGraphNode2D else { return 1 }
        return simd_distance(position, n.position)
    }
    open override func estimatedCost(to node: GKGraphNode) -> Float { cost(to: node) }
}

open class GKGraphNode3D: GKGraphNode {
    open var position: vector_float3
    public init(point: vector_float3) { position = point; super.init() }
    public required init?(coder: NSCoder) { position = .zero; super.init(coder: coder) }
    open override func cost(to node: GKGraphNode) -> Float {
        guard let n = node as? GKGraphNode3D else { return 1 }
        return simd_distance(position, n.position)
    }
    open override func estimatedCost(to node: GKGraphNode) -> Float { cost(to: node) }
}

open class GKGridGraphNode: GKGraphNode {
    open var gridPosition: vector_int2
    public required init(gridPosition: vector_int2) { self.gridPosition = gridPosition; super.init() }
    public required init?(coder: NSCoder) { gridPosition = .zero; super.init(coder: coder) }
    /// 1 per straight step, sqrt(2) per diagonal step
    open override func cost(to node: GKGraphNode) -> Float {
        guard let n = node as? GKGridGraphNode else { return 1 }
        let dx = abs(n.gridPosition.x - gridPosition.x), dy = abs(n.gridPosition.y - gridPosition.y)
        return dx != 0 && dy != 0 ? 1.4142135 : 1
    }
    /// octile distance
    open override func estimatedCost(to node: GKGraphNode) -> Float {
        guard let n = node as? GKGridGraphNode else { return 0 }
        let dx = Float(abs(n.gridPosition.x - gridPosition.x)), dy = Float(abs(n.gridPosition.y - gridPosition.y))
        return max(dx, dy) + 0.41421356 * min(dx, dy)
    }
    open override var description: String { "GKGridGraphNode: {\(gridPosition.x), \(gridPosition.y)}" }
}

/// A* search; the path includes both ends, or is empty.
func _gkAStar(from start: GKGraphNode, to goal: GKGraphNode) -> [GKGraphNode] {
    if start === goal { return [start] }
    var g: [ObjectIdentifier: Float] = [ObjectIdentifier(start): 0]
    var came: [ObjectIdentifier: GKGraphNode] = [:]
    var closed = Set<ObjectIdentifier>()
    // binary heap of (f, tiebreak, node)
    var heap: [(Float, Int, GKGraphNode)] = [(start.estimatedCost(to: goal), 0, start)]
    var counter = 0
    func push(_ e: (Float, Int, GKGraphNode)) {
        heap.append(e)
        var i = heap.count - 1
        while i > 0 {
            let p = (i - 1) / 2
            if heap[p].0 < heap[i].0 || (heap[p].0 == heap[i].0 && heap[p].1 <= heap[i].1) { break }
            heap.swapAt(p, i); i = p
        }
    }
    func pop() -> (Float, Int, GKGraphNode) {
        let top = heap[0]
        let last = heap.removeLast()
        if !heap.isEmpty {
            heap[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = l + 1
                var m = i
                func less(_ a: Int, _ b: Int) -> Bool { heap[a].0 < heap[b].0 || (heap[a].0 == heap[b].0 && heap[a].1 < heap[b].1) }
                if l < heap.count && less(l, m) { m = l }
                if r < heap.count && less(r, m) { m = r }
                if m == i { break }
                heap.swapAt(i, m); i = m
            }
        }
        return top
    }
    while !heap.isEmpty {
        let (_, _, cur) = pop()
        let cid = ObjectIdentifier(cur)
        if closed.contains(cid) { continue }
        if cur === goal {
            var path: [GKGraphNode] = [cur]
            var k = cid
            while let p = came[k] { path.append(p); k = ObjectIdentifier(p) }
            return path.reversed()
        }
        closed.insert(cid)
        let gc = g[cid] ?? 0
        for n in cur.connectedNodes {
            let nid = ObjectIdentifier(n)
            if closed.contains(nid) { continue }
            let cand = gc + cur.cost(to: n)
            if cand < (g[nid] ?? .infinity) {
                g[nid] = cand; came[nid] = cur
                counter += 1
                push((cand + n.estimatedCost(to: goal), counter, n))
            }
        }
    }
    return []
}

open class GKGraph: NSObject {
    open internal(set) var nodes: [GKGraphNode]?
    public override init() { super.init() }
    public init(nodes: [GKGraphNode]) { self.nodes = nodes; super.init() }
    public required init?(coder: NSCoder) { super.init() }
    open func connectNode(toLowestCostNode node: GKGraphNode, bidirectional: Bool) {
        guard let best = (nodes ?? []).filter({ $0 !== node }).min(by: { node.cost(to: $0) < node.cost(to: $1) }) else { return }
        node.addConnections(to: [best], bidirectional: bidirectional)
    }
    open func remove(_ remove: [GKGraphNode]) {
        for n in remove {
            for m in nodes ?? [] { m.connectedNodes.removeAll { $0 === n } }
            n.connectedNodes.removeAll()
        }
        nodes?.removeAll { n in remove.contains { $0 === n } }
    }
    open func add(_ add: [GKGraphNode]) { nodes = (nodes ?? []) + add.filter { n in !(nodes ?? []).contains { $0 === n } } }
    open func findPath(from startNode: GKGraphNode, to endNode: GKGraphNode) -> [GKGraphNode] { _gkAStar(from: startNode, to: endNode) }
}

open class GKGridGraph<NodeType: GKGridGraphNode>: GKGraph {
    open private(set) var gridOrigin: vector_int2
    open private(set) var gridWidth: Int
    open private(set) var gridHeight: Int
    open private(set) var diagonalsAllowed: Bool
    var grid: [GKGridGraphNode?] = []
    let nodeClass: GKGridGraphNode.Type

    public convenience init(fromGridStartingAt origin: vector_int2, width: Int32, height: Int32, diagonalsAllowed: Bool) {
        self.init(fromGridStartingAt: origin, width: width, height: height, diagonalsAllowed: diagonalsAllowed, nodeClass: NodeType.self)
    }
    public init(fromGridStartingAt origin: vector_int2, width: Int32, height: Int32, diagonalsAllowed: Bool, nodeClass: AnyClass) {
        gridOrigin = origin; gridWidth = Int(max(0, width)); gridHeight = Int(max(0, height)); self.diagonalsAllowed = diagonalsAllowed
        self.nodeClass = (nodeClass as? GKGridGraphNode.Type) ?? GKGridGraphNode.self
        super.init()
        grid = Array(repeating: nil, count: gridWidth * gridHeight)
        var all: [GKGraphNode] = []
        for y in 0..<gridHeight {
            for x in 0..<gridWidth {
                let n = self.nodeClass.init(gridPosition: vector_int2(origin.x + Int32(x), origin.y + Int32(y)))
                grid[y * gridWidth + x] = n
                all.append(n)
            }
        }
        nodes = all
        for n in all { connectNode(toAdjacentNodes: n as! GKGridGraphNode) }
    }
    public required init?(coder: NSCoder) {
        gridOrigin = .zero; gridWidth = 0; gridHeight = 0; diagonalsAllowed = false; nodeClass = GKGridGraphNode.self
        super.init(coder: coder)
    }
    func index(_ p: vector_int2) -> Int? {
        let x = Int(p.x - gridOrigin.x), y = Int(p.y - gridOrigin.y)
        guard x >= 0, y >= 0, x < gridWidth, y < gridHeight else { return nil }
        return y * gridWidth + x
    }
    open func node(atGridPosition p: vector_int2) -> NodeType? { index(p).flatMap { grid[$0] } as? NodeType }
    open func connectNode(toAdjacentNodes node: GKGridGraphNode) {
        let p = node.gridPosition
        var neighbors: [GKGraphNode] = []
        for dy in Int32(-1)...1 {
            for dx in Int32(-1)...1 where !(dx == 0 && dy == 0) {
                if !diagonalsAllowed && dx != 0 && dy != 0 { continue }
                if let i = index(vector_int2(p.x + dx, p.y + dy)), let n = grid[i] { neighbors.append(n) }
            }
        }
        node.addConnections(to: neighbors, bidirectional: true)
        if let i = index(p), grid[i] == nil { grid[i] = node; if !(nodes ?? []).contains(where: { $0 === node }) { nodes = (nodes ?? []) + [node] } }
    }
    open override func remove(_ remove: [GKGraphNode]) {
        for n in remove { if let g = n as? GKGridGraphNode, let i = index(g.gridPosition), grid[i] === g { grid[i] = nil } }
        super.remove(remove)
    }
    open func classForGenericArgument(at index: Int) -> AnyClass { nodeClass }
}

// MARK: - Noise

open class GKNoiseSource: NSObject {
    public override init() { super.init() }
    func value(_ x: Double, _ y: Double, _ z: Double) -> Double { 0 }
}

/// Improved Perlin gradient noise (Ken Perlin, 2002) with a seeded permutation.
struct _Perlin {
    var perm: [Int] = []
    init(seed: Int32) {
        var p = Array(0..<256)
        let rng = GKMersenneTwisterRandomSource(seed: UInt64(UInt32(bitPattern: seed)))
        for i in stride(from: 255, to: 0, by: -1) { p.swapAt(i, rng.nextInt(upperBound: i + 1)) }
        perm = p + p
    }
    static func fade(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }
    static func lerp(_ t: Double, _ a: Double, _ b: Double) -> Double { a + t * (b - a) }
    static func grad(_ h: Int, _ x: Double, _ y: Double, _ z: Double) -> Double {
        let h = h & 15
        let u = h < 8 ? x : y, v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
    func noise(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let X = Int(floor(x)) & 255, Y = Int(floor(y)) & 255, Z = Int(floor(z)) & 255
        let x = x - floor(x), y = y - floor(y), z = z - floor(z)
        let u = _Perlin.fade(x), v = _Perlin.fade(y), w = _Perlin.fade(z)
        let A = perm[X] + Y, AA = perm[A] + Z, AB = perm[A + 1] + Z, B = perm[X + 1] + Y, BA = perm[B] + Z, BB = perm[B + 1] + Z
        let l1 = _Perlin.lerp(u, _Perlin.grad(perm[AA], x, y, z), _Perlin.grad(perm[BA], x - 1, y, z))
        let l2 = _Perlin.lerp(u, _Perlin.grad(perm[AB], x, y - 1, z), _Perlin.grad(perm[BB], x - 1, y - 1, z))
        let l3 = _Perlin.lerp(u, _Perlin.grad(perm[AA + 1], x, y, z - 1), _Perlin.grad(perm[BA + 1], x - 1, y, z - 1))
        let l4 = _Perlin.lerp(u, _Perlin.grad(perm[AB + 1], x, y - 1, z - 1), _Perlin.grad(perm[BB + 1], x - 1, y - 1, z - 1))
        return _Perlin.lerp(w, _Perlin.lerp(v, l1, l2), _Perlin.lerp(v, l3, l4))
    }
}

open class GKCoherentNoiseSource: GKNoiseSource {
    open var frequency: Double { didSet { } }
    open var octaveCount: Int
    open var lacunarity: Double
    open var seed: Int32 { didSet { perlin = _Perlin(seed: seed) } }
    var perlin: _Perlin
    init(frequency: Double, octaveCount: Int, lacunarity: Double, seed: Int32) {
        self.frequency = frequency; self.octaveCount = octaveCount; self.lacunarity = lacunarity; self.seed = seed
        perlin = _Perlin(seed: seed)
        super.init()
    }
}

open class GKPerlinNoiseSource: GKCoherentNoiseSource {
    open var persistence: Double
    public init(frequency: Double, octaveCount: Int, persistence: Double, lacunarity: Double, seed: Int32) {
        self.persistence = persistence
        super.init(frequency: frequency, octaveCount: octaveCount, lacunarity: lacunarity, seed: seed)
    }
    public convenience init() { self.init(frequency: 1, octaveCount: 6, persistence: 0.5, lacunarity: 2, seed: 0) }
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double {
        var sum = 0.0, amp = 1.0, f = frequency, norm = 0.0
        for _ in 0..<max(1, octaveCount) {
            sum += perlin.noise(x * f, y * f, z * f) * amp
            norm += amp; amp *= persistence; f *= lacunarity
        }
        return max(-1, min(1, sum / norm * 1.4))
    }
}

open class GKBillowNoiseSource: GKPerlinNoiseSource {
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double {
        var sum = 0.0, amp = 1.0, f = frequency, norm = 0.0
        for _ in 0..<max(1, octaveCount) {
            sum += (2 * abs(perlin.noise(x * f, y * f, z * f)) - 1) * amp
            norm += amp; amp *= persistence; f *= lacunarity
        }
        return max(-1, min(1, sum / norm))
    }
}

open class GKRidgedNoiseSource: GKCoherentNoiseSource {
    public override init(frequency: Double, octaveCount: Int, lacunarity: Double, seed: Int32) {
        super.init(frequency: frequency, octaveCount: octaveCount, lacunarity: lacunarity, seed: seed)
    }
    public convenience init() { self.init(frequency: 1, octaveCount: 6, lacunarity: 2, seed: 0) }
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double {
        var sum = 0.0, amp = 1.0, f = frequency, norm = 0.0
        for _ in 0..<max(1, octaveCount) {
            let r = 1 - abs(perlin.noise(x * f, y * f, z * f))
            sum += r * r * amp
            norm += amp; amp *= 0.5; f *= lacunarity
        }
        return max(-1, min(1, sum / norm * 2 - 1))
    }
}

open class GKVoronoiNoiseSource: GKNoiseSource {
    open var frequency: Double
    open var displacement: Double
    open var isDistanceEnabled: Bool
    open var seed: Int32
    public init(frequency: Double, displacement: Double, distanceEnabled: Bool, seed: Int32) {
        self.frequency = frequency; self.displacement = displacement; isDistanceEnabled = distanceEnabled; self.seed = seed
        super.init()
    }
    public convenience override init() { self.init(frequency: 1, displacement: 1, distanceEnabled: false, seed: 0) }
    func hash(_ x: Int, _ y: Int, _ k: Int) -> Double {
        var h = UInt64(bitPattern: Int64(x &* 73856093 ^ y &* 19349663 ^ k &* 83492791 ^ Int(seed) &* 2654435761))
        h ^= h >> 33; h = h &* 0xff51afd7ed558ccd; h ^= h >> 33
        return Double(h & 0xffffff) / Double(0xffffff)
    }
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let px = x * frequency, py = y * frequency
        let cx = Int(floor(px)), cy = Int(floor(py))
        var best = Double.infinity, cell = (0, 0)
        for dy in -1...1 {
            for dx in -1...1 {
                let gx = cx + dx, gy = cy + dy
                let fx = Double(gx) + hash(gx, gy, 1), fy = Double(gy) + hash(gx, gy, 2)
                let d = (fx - px) * (fx - px) + (fy - py) * (fy - py)
                if d < best { best = d; cell = (gx, gy) }
            }
        }
        var v = (hash(cell.0, cell.1, 3) * 2 - 1) * displacement
        if isDistanceEnabled { v += best.squareRoot() * 2 - 1 }
        return max(-1, min(1, v))
    }
}

open class GKConstantNoiseSource: GKNoiseSource {
    open var value: Double
    public init(value: Double) { self.value = value; super.init() }
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double { value }
}

open class GKCylindersNoiseSource: GKNoiseSource {
    open var frequency: Double
    public init(frequency: Double) { self.frequency = frequency; super.init() }
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let d = (x * x + z * z).squareRoot() * frequency
        return 1 - 4 * abs(d - d.rounded())
    }
}

open class GKSpheresNoiseSource: GKNoiseSource {
    open var frequency: Double
    public init(frequency: Double) { self.frequency = frequency; super.init() }
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let d = (x * x + y * y + z * z).squareRoot() * frequency
        return 1 - 4 * abs(d - d.rounded())
    }
}

open class GKCheckerboardNoiseSource: GKNoiseSource {
    open var squareSize: Double
    public init(squareSize: Double) { self.squareSize = squareSize; super.init() }
    override func value(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let s = max(squareSize, 1e-9)
        return (Int(floor(x / s)) + Int(floor(z / s)) + Int(floor(y / s))) & 1 == 0 ? 1 : -1
    }
}

open class GKNoise: NSObject {
    var f: (Double, Double, Double) -> Double
    open var gradientColors: [NSNumber: UIColor] = [NSNumber(value: -1): .black, NSNumber(value: 1): .white]
    public override init() { f = { _, _, _ in 0 }; super.init() }
    public init(_ source: GKNoiseSource) { f = source.value; super.init() }
    public convenience init(noiseSource: GKNoiseSource) { self.init(noiseSource) }
    public convenience init(noiseSource: GKNoiseSource, gradientColors: [NSNumber: UIColor]) { self.init(noiseSource); self.gradientColors = gradientColors }
    init(f: @escaping (Double, Double, Double) -> Double) { self.f = f; super.init() }

    /// value at a 2D position (the noise is sampled on the x-z plane, y = 0)
    open func value(atPosition p: vector_float2) -> Float { Float(max(-1, min(1, f(Double(p.x), 0, Double(p.y))))) }

    open func applyAbsoluteValue() { let g = f; f = { abs(g($0, $1, $2)) } }
    open func invert() { let g = f; f = { -g($0, $1, $2) } }
    open func raiseToPower(_ power: Double) { let g = f; f = { pow(max(0, g($0, $1, $2)), power) } }
    open func clamp(lowerBound: Double, upperBound: Double) { let g = f; f = { min(max(g($0, $1, $2), lowerBound), upperBound) } }
    open func move(by delta: vector_double3) { let g = f; f = { g($0 - delta.x, $1 - delta.y, $2 - delta.z) } }
    open func scale(by factor: vector_double3) { let g = f; f = { g($0 / factor.x, $1 / factor.y, $2 / factor.z) } }
    open func rotate(by r: vector_double3) {
        let g = f, c = cos(r.y), s = sin(r.y)   // around the vertical axis
        f = { x, y, z in g(c * x - s * z, y, s * x + c * z) }
    }
    open func add(_ noise: GKNoise) { let a = f, b = noise.f; f = { a($0, $1, $2) + b($0, $1, $2) } }
    open func multiply(_ noise: GKNoise) { let a = f, b = noise.f; f = { a($0, $1, $2) * b($0, $1, $2) } }
    open func minimum(_ noise: GKNoise) { let a = f, b = noise.f; f = { min(a($0, $1, $2), b($0, $1, $2)) } }
    open func maximum(_ noise: GKNoise) { let a = f, b = noise.f; f = { max(a($0, $1, $2), b($0, $1, $2)) } }
    open func raise(toPower noise: GKNoise) { let a = f, b = noise.f; f = { pow(max(0, a($0, $1, $2)), b($0, $1, $2)) } }
    open func displaceX(with xd: GKNoise, y yd: GKNoise, z zd: GKNoise) {
        let a = f, dx = xd.f, dy = yd.f, dz = zd.f
        f = { x, y, z in a(x + dx(x, y, z), y + dy(x, y, z), z + dz(x, y, z)) }
    }
    open func remapValues(toTerracesWithPeaks peakInputValues: [NSNumber], terracesInverted: Bool) {
        let peaks = peakInputValues.map(\.doubleValue).sorted(), g = f
        f = { x, y, z in
            let v = g(x, y, z)
            guard let hi = peaks.first(where: { $0 >= v }), let lo = peaks.last(where: { $0 <= v }), hi > lo else { return v }
            var t = (v - lo) / (hi - lo); t = terracesInverted ? 1 - (1 - t) * (1 - t) : t * t
            return lo + (hi - lo) * t
        }
    }
}

open class GKNoiseMap: NSObject {
    open private(set) var size: vector_double2
    open private(set) var origin: vector_double2
    open private(set) var sampleCount: vector_int2
    open private(set) var isSeamless: Bool
    var values: [Float]

    public override init() { size = vector_double2(1, 1); origin = .zero; sampleCount = vector_int2(1, 1); isSeamless = false; values = [0]; super.init() }
    public convenience init(_ noise: GKNoise) { self.init(noise, size: vector_double2(1, 1), origin: .zero, sampleCount: vector_int2(100, 100), seamless: false) }
    public init(_ noise: GKNoise, size: vector_double2, origin: vector_double2, sampleCount: vector_int2, seamless: Bool) {
        self.size = size; self.origin = origin; self.sampleCount = sampleCount; isSeamless = seamless
        let w = Int(max(1, sampleCount.x)), h = Int(max(1, sampleCount.y))
        values = [Float](repeating: 0, count: w * h)
        super.init()
        for j in 0..<h {
            for i in 0..<w {
                let x = origin.x + size.x * Double(i) / Double(w), y = origin.y + size.y * Double(j) / Double(h)
                var v = noise.f(x, 0, y)
                if seamless {   // blend with the wrapped copies so opposite edges match
                    let fx = Double(i) / Double(w), fy = Double(j) / Double(h)
                    let a = noise.f(x, 0, y), b = noise.f(x - size.x, 0, y), c = noise.f(x, 0, y - size.y), d = noise.f(x - size.x, 0, y - size.y)
                    v = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
                }
                values[j * w + i] = Float(max(-1, min(1, v)))
            }
        }
    }
    public convenience init(noise: GKNoise, size: vector_double2, origin: vector_double2, sampleCount: vector_int2, seamless: Bool) {
        self.init(noise, size: size, origin: origin, sampleCount: sampleCount, seamless: seamless)
    }
    open func value(at p: vector_int2) -> Float {
        let w = Int(max(1, sampleCount.x)), h = Int(max(1, sampleCount.y))
        let x = min(max(Int(p.x), 0), w - 1), y = min(max(Int(p.y), 0), h - 1)
        return values[y * w + x]
    }
    open func interpolatedValue(at p: vector_float2) -> Float {
        let x0 = Float(Double(p.x).rounded(.down)), y0 = Float(Double(p.y).rounded(.down))
        let fx: Float = p.x - x0, fy: Float = p.y - y0
        let ix = Int32(x0), iy = Int32(y0)
        let a: Float = value(at: vector_int2(ix, iy)), b: Float = value(at: vector_int2(ix + 1, iy))
        let c: Float = value(at: vector_int2(ix, iy + 1)), d: Float = value(at: vector_int2(ix + 1, iy + 1))
        let top: Float = a * (1 - fx) + b * fx, bottom: Float = c * (1 - fx) + d * fx
        return top * (1 - fy) + bottom * fy
    }
    open func setValue(_ value: Float, at p: vector_int2) {
        let w = Int(max(1, sampleCount.x)), h = Int(max(1, sampleCount.y))
        let x = Int(p.x), y = Int(p.y)
        guard x >= 0, y >= 0, x < w, y < h else { return }
        values[y * w + x] = value
    }
}
