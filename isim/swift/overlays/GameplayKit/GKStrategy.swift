// isim GameplayKit: game models with strategists (minimax with alpha-beta pruning, Monte Carlo tree search) and
// decision trees (built by hand, or learned from examples with ID3).
import Foundation

// MARK: - Game model

public let GKGameModelMaxScore = 1 << 24
public let GKGameModelMinScore = -(1 << 24)

@objc public protocol GKGameModelPlayer: NSObjectProtocol {
    var playerId: Int { get }
}
@objc public protocol GKGameModelUpdate: NSObjectProtocol {
    var value: Int { get set }
}
/// The strategists work on copies (copy(with:), which should call setGameModel) and apply moves to them.
@objc public protocol GKGameModel: NSObjectProtocol, NSCopying {
    var players: [GKGameModelPlayer]? { get }
    var activePlayer: GKGameModelPlayer? { get }
    func setGameModel(_ gameModel: GKGameModel)
    func gameModelUpdates(for player: GKGameModelPlayer) -> [GKGameModelUpdate]?
    func apply(_ gameModelUpdate: GKGameModelUpdate)
    @objc optional func score(for player: GKGameModelPlayer) -> Int
    @objc optional func isWin(for player: GKGameModelPlayer) -> Bool
    @objc optional func isLoss(for player: GKGameModelPlayer) -> Bool
    @objc optional func unapplyGameModelUpdate(_ gameModelUpdate: GKGameModelUpdate)
}

public protocol GKStrategist: NSObjectProtocol {
    var gameModel: GKGameModel? { get set }
    var randomSource: GKRandom? { get set }
    func bestMoveForActivePlayer() -> GKGameModelUpdate?
}

func _gkCopy(_ m: GKGameModel) -> GKGameModel {
    if let c = m.copy(with: nil) as? GKGameModel { return c }
    fatalError("GameplayKit: copy(with:) of a GKGameModel must return a GKGameModel")
}
func _gkSame(_ a: GKGameModelPlayer?, _ b: GKGameModelPlayer?) -> Bool {
    guard let a, let b else { return false }
    return a === b || a.playerId == b.playerId
}

// MARK: - Minimax

/// Looks `maxLookAheadDepth` moves ahead; the player maximizes, every other player minimizes its score.
/// Wins score GKGameModelMaxScore (sooner wins higher), losses GKGameModelMinScore; other positions score(for:).
/// Ties between equally good moves are broken with `randomSource` when set, else the first one wins.
open class GKMinmaxStrategist: NSObject, GKStrategist {
    open var gameModel: GKGameModel?
    open var randomSource: GKRandom?
    open var maxLookAheadDepth = 1

    public override init() { super.init() }

    open func bestMoveForActivePlayer() -> GKGameModelUpdate? {
        guard let p = gameModel?.activePlayer else { return nil }
        return bestMove(for: p)
    }
    open func bestMove(for player: GKGameModelPlayer) -> GKGameModelUpdate? {
        let ranked = rank(player)
        guard let top = ranked.first else { return nil }
        let best = ranked.filter { $0.value == top.value }
        if best.count > 1, let r = randomSource { return best[r.nextInt(upperBound: best.count)] }
        return best[0]
    }
    /// one of the `numMovesToConsider` best moves, chosen with randomSource
    open func randomMove(for player: GKGameModelPlayer, fromNumberOfBestMoves numMovesToConsider: Int) -> GKGameModelUpdate? {
        let ranked = Array(rank(player).prefix(max(1, numMovesToConsider)))
        guard !ranked.isEmpty else { return nil }
        let r = randomSource ?? GKRandomSource.sharedRandom()
        return ranked[r.nextInt(upperBound: ranked.count)]
    }

    /// the player's moves with `value` set, best first (stable)
    func rank(_ player: GKGameModelPlayer) -> [GKGameModelUpdate] {
        guard let model = gameModel, let moves = model.gameModelUpdates(for: player), !moves.isEmpty else { return [] }
        for u in moves {
            let child = _gkCopy(model)
            child.apply(u)
            u.value = search(child, depth: max(0, maxLookAheadDepth - 1), ply: 1, me: player, alpha: Int.min, beta: Int.max)
        }
        return moves.enumerated().sorted { $0.element.value != $1.element.value ? $0.element.value > $1.element.value : $0.offset < $1.offset }.map(\.element)
    }

    func terminal(_ m: GKGameModel, _ me: GKGameModelPlayer, _ ply: Int) -> Int? {
        if m.isWin?(for: me) == true { return GKGameModelMaxScore - ply }
        if m.isLoss?(for: me) == true { return GKGameModelMinScore + ply }
        for p in m.players ?? [] where !_gkSame(p, me) && m.isWin?(for: p) == true { return GKGameModelMinScore + ply }
        return nil
    }
    func search(_ m: GKGameModel, depth: Int, ply: Int, me: GKGameModelPlayer, alpha a0: Int, beta b0: Int) -> Int {
        if let t = terminal(m, me, ply) { return t }
        let mover = m.activePlayer
        guard depth > 0, let mover, let moves = m.gameModelUpdates(for: mover), !moves.isEmpty else { return m.score?(for: me) ?? 0 }
        var alpha = a0, beta = b0
        let maximizing = _gkSame(mover, me)
        var best = maximizing ? Int.min : Int.max
        for u in moves {
            let child = _gkCopy(m)
            child.apply(u)
            let v = search(child, depth: depth - 1, ply: ply + 1, me: me, alpha: alpha, beta: beta)
            if maximizing { best = max(best, v); alpha = max(alpha, v) } else { best = min(best, v); beta = min(beta, v) }
            if beta <= alpha { break }
        }
        return best
    }
}

// MARK: - Monte Carlo tree search

/// UCT: `budget` playouts; each selects down the tree by the upper confidence bound (explorationParameter weighs
/// exploration), expands one new move, plays random moves to the end and counts wins. The most visited move wins.
open class GKMonteCarloStrategist: NSObject, GKStrategist {
    open var gameModel: GKGameModel?
    open var randomSource: GKRandom?
    open var budget = 500
    open var explorationParameter = 1

    public override init() { super.init() }

    final class Node {
        let move: GKGameModelUpdate?
        let mover: GKGameModelPlayer?
        weak var parent: Node?
        var children: [Node] = []
        var untried: [GKGameModelUpdate]
        var visits = 0.0, wins = 0.0
        init(move: GKGameModelUpdate?, mover: GKGameModelPlayer?, parent: Node?, untried: [GKGameModelUpdate]) {
            self.move = move; self.mover = mover; self.parent = parent; self.untried = untried
        }
    }

    open func bestMoveForActivePlayer() -> GKGameModelUpdate? {
        guard let p = gameModel?.activePlayer else { return nil }
        return bestMove(for: p)
    }
    func winner(_ m: GKGameModel) -> GKGameModelPlayer?? {
        for p in m.players ?? [] {
            if m.isWin?(for: p) == true { return .some(p) }
        }
        for p in m.players ?? [] where m.isLoss?(for: p) == true {
            return .some((m.players ?? []).first { !_gkSame($0, p) })
        }
        return nil      // not over
    }
    open func bestMove(for player: GKGameModelPlayer) -> GKGameModelUpdate? {
        guard let model = gameModel, let moves = model.gameModelUpdates(for: player), !moves.isEmpty else { return nil }
        if moves.count == 1 { return moves[0] }
        let rng = randomSource ?? GKRandomSource.sharedRandom()
        let root = Node(move: nil, mover: nil, parent: nil, untried: moves)
        let c = Double(explorationParameter) * 1.41421356
        for _ in 0..<max(1, budget) {
            var node = root
            let state = _gkCopy(model)
            // selection
            while node.untried.isEmpty && !node.children.isEmpty {
                let lnN = log(max(1, node.visits))
                node = node.children.max { a, b in
                    a.wins / a.visits + c * (lnN / a.visits).squareRoot() < b.wins / b.visits + c * (lnN / b.visits).squareRoot()
                }!
                state.apply(node.move!)
            }
            // expansion
            if !node.untried.isEmpty, winner(state) == nil, let mover = state.activePlayer {
                let i = rng.nextInt(upperBound: node.untried.count)
                let mv = node.untried.remove(at: i)
                state.apply(mv)
                let child = Node(move: mv, mover: mover, parent: node, untried: winner(state) == nil ? (state.activePlayer.flatMap { state.gameModelUpdates(for: $0) } ?? []) : [])
                node.children.append(child)
                node = child
            }
            // random playout
            var steps = 0
            var result = winner(state)
            while result == nil, steps < 500, let p = state.activePlayer, let ms = state.gameModelUpdates(for: p), !ms.isEmpty {
                state.apply(ms[rng.nextInt(upperBound: ms.count)])
                steps += 1
                result = winner(state)
            }
            // backpropagation: a node's wins count for the player who moved into it (draws count half)
            var n: Node? = node
            while let x = n {
                x.visits += 1
                if let r = result, let w = r { if _gkSame(w, x.mover) { x.wins += 1 } } else { x.wins += 0.5 }
                n = x.parent
            }
        }
        let best = root.children.max { $0.visits != $1.visits ? $0.visits < $1.visits : $0.wins < $1.wins }
        if let b = best, let m = b.move { m.value = Int((b.wins / max(1, b.visits)) * 100) }
        return best?.move
    }
}

// MARK: - Decision trees

func _gkEqual(_ a: Any, _ b: Any) -> Bool {
    if let x = a as? String ?? (a as? NSString).map({ String(describing: $0) }), let y = b as? String ?? (b as? NSString).map({ String(describing: $0) }) { return x == y }
    if let x = _gkNumber(a), let y = _gkNumber(b) { return x == y }
    if let x = a as? NSObject, let y = b as? NSObject { return x.isEqual(y) }
    return false
}
func _gkNumber(_ a: Any) -> Double? {
    switch a {
    case let n as NSNumber: return n.doubleValue
    case let i as Int: return Double(i)
    case let d as Double: return d
    case let f as Float: return Double(f)
    case let b as Bool: return b ? 1 : 0
    default: return nil
    }
}
func _gkText(_ a: Any) -> String { String(describing: a) }

open class GKDecisionNode: NSObject {
    enum Test { case value(NSObjectProtocol), predicate(NSPredicate), weight(Int), atMost(Double), above(Double) }
    let attribute: NSObjectProtocol
    var branches: [(Test, GKDecisionNode)] = []
    /// learned trees: the most common action below this node (for answers no branch matches)
    var fallback: NSObjectProtocol?
    weak var tree: GKDecisionTree?

    init(attribute: NSObjectProtocol, tree: GKDecisionTree?) { self.attribute = attribute; self.tree = tree; super.init() }

    func branch(_ t: Test, _ attribute: NSObjectProtocol) -> GKDecisionNode {
        let n = GKDecisionNode(attribute: attribute, tree: tree)
        branches.append((t, n))
        return n
    }
    /// a child taken when the answer for this node's attribute equals `value`
    @discardableResult open func createBranch(value: NSNumber, attribute: NSObjectProtocol) -> GKDecisionNode { branch(.value(value), attribute) }
    /// a child taken when the predicate is true for the answer
    @discardableResult open func createBranch(predicate: NSPredicate, attribute: NSObjectProtocol) -> GKDecisionNode { branch(.predicate(predicate), attribute) }
    /// a child chosen at random, in proportion to its weight
    @discardableResult open func createBranch(weight: Int, attribute: NSObjectProtocol) -> GKDecisionNode { branch(.weight(max(0, weight)), attribute) }

    func describe(_ indent: String, _ label: String, into out: inout String) {
        out += indent + label + _gkText(attribute) + "\n"
        for (t, n) in branches {
            let l: String
            switch t {
            case .value(let v): l = "= \(_gkText(v)): "
            case .predicate(let p): l = "\(p.predicateFormat): "
            case .weight(let w): l = "weight \(w): "
            case .atMost(let x): l = "<= \(x): "
            case .above(let x): l = "> \(x): "
            }
            n.describe(indent + "  ", l, into: &out)
        }
    }
}

/// Answers walk the tree from the root: each node asks for its attribute, the matching branch leads on, a node
/// without branches is the action.
open class GKDecisionTree: NSObject {
    open private(set) var rootNode: GKDecisionNode?
    open var randomSource: GKRandomSource = GKRandomSource()

    public init(attribute: NSObjectProtocol) {
        super.init()
        rootNode = GKDecisionNode(attribute: attribute, tree: self)
    }

    /// ID3: each node splits on the attribute with the highest information gain. Numeric attributes with more than
    /// four distinct values split at the best threshold (<= / >); others branch on each value.
    public init(examples: [[NSObjectProtocol]], actions: [NSObjectProtocol], attributes: [NSObjectProtocol]) {
        super.init()
        let rows = Array(zip(examples, actions).filter { $0.0.count >= attributes.count })
        rootNode = build(rows, Array(attributes.indices), attributes)
    }

    func entropy(_ actions: [NSObjectProtocol]) -> Double {
        var counts: [String: Int] = [:]
        for a in actions { counts[_gkText(a), default: 0] += 1 }
        let n = Double(actions.count)
        return counts.values.reduce(0) { e, c in let p = Double(c) / n; return e - p * log2(p) }
    }
    func majority(_ actions: [NSObjectProtocol]) -> NSObjectProtocol? {
        var counts: [String: (Int, NSObjectProtocol)] = [:]
        for a in actions { let k = _gkText(a); counts[k] = ((counts[k]?.0 ?? 0) + 1, a) }
        return counts.max { $0.value.0 != $1.value.0 ? $0.value.0 < $1.value.0 : $0.key > $1.key }?.value.1
    }
    enum Split { case categorical([NSObjectProtocol]), threshold(Double) }
    func build(_ rows: [([NSObjectProtocol], NSObjectProtocol)], _ attrs: [Int], _ names: [NSObjectProtocol]) -> GKDecisionNode? {
        let actions = rows.map(\.1)
        guard let maj = majority(actions) else { return nil }
        if entropy(actions) == 0 || attrs.isEmpty {
            return GKDecisionNode(attribute: maj, tree: self)
        }
        let base = entropy(actions)
        var best: (gain: Double, attr: Int, split: Split)?
        for a in attrs {
            let values = rows.map { $0.0[a] }
            let numbers = values.compactMap { _gkNumber($0) }
            var distinct: [NSObjectProtocol] = []
            for v in values where !distinct.contains(where: { _gkEqual($0, v) }) { distinct.append(v) }
            if numbers.count == values.count && distinct.count > 4 {
                let sorted = Array(Set(numbers)).sorted()
                for i in 0..<(sorted.count - 1) {
                    let t = (sorted[i] + sorted[i + 1]) / 2
                    let lo = rows.filter { _gkNumber($0.0[a])! <= t }.map(\.1), hi = rows.filter { _gkNumber($0.0[a])! > t }.map(\.1)
                    let rem = (Double(lo.count) * entropy(lo) + Double(hi.count) * entropy(hi)) / Double(rows.count)
                    if base - rem > (best?.gain ?? 1e-9) { best = (base - rem, a, .threshold(t)) }
                }
            } else {
                var rem = 0.0
                for v in distinct {
                    let sub = rows.filter { _gkEqual($0.0[a], v) }.map(\.1)
                    rem += Double(sub.count) / Double(rows.count) * entropy(sub)
                }
                if base - rem > (best?.gain ?? 1e-9) { best = (base - rem, a, .categorical(distinct)) }
            }
        }
        guard let best else { return GKDecisionNode(attribute: maj, tree: self) }
        let node = GKDecisionNode(attribute: names[best.attr], tree: self)
        node.fallback = maj
        switch best.split {
        case .categorical(let values):
            let rest = attrs.filter { $0 != best.attr }
            for v in values {
                let sub = rows.filter { _gkEqual($0.0[best.attr], v) }
                if let child = build(sub, rest, names) { child.tree = self; node.branches.append((.value(v), child)) }
            }
        case .threshold(let t):
            let lo = rows.filter { _gkNumber($0.0[best.attr])! <= t }, hi = rows.filter { _gkNumber($0.0[best.attr])! > t }
            if let c = build(lo, attrs, names) { node.branches.append((.atMost(t), c)) }
            if let c = build(hi, attrs, names) { node.branches.append((.above(t), c)) }
        }
        return node
    }

    /// The action for the answers (keyed by attribute); nil if an answer matches no branch.
    open func findAction(forAnswers answers: [AnyHashable: NSObjectProtocol]) -> NSObjectProtocol? {
        var node = rootNode
        var guardSteps = 0
        while let n = node, guardSteps < 10_000 {
            guardSteps += 1
            if n.branches.isEmpty { return n.attribute }
            let weights = n.branches.compactMap { b -> Int? in if case .weight(let w) = b.0 { return w } else { return nil } }
            if weights.count == n.branches.count {
                let total = weights.reduce(0, +)
                guard total > 0 else { return nil }
                var pick = randomSource.nextInt(upperBound: total)
                node = nil
                for (b, w) in zip(n.branches, weights) { if pick < w { node = b.1; break }; pick -= w }
                continue
            }
            guard let answer = answers.first(where: { _gkEqual($0.key.base, n.attribute) })?.value else { return n.fallback }
            node = n.branches.first { b in
                switch b.0 {
                case .value(let v): return _gkEqual(answer, v)
                case .predicate(let p): return p.evaluate(with: answer)
                case .weight: return false
                case .atMost(let t): return (_gkNumber(answer) ?? .nan) <= t
                case .above(let t): return (_gkNumber(answer) ?? .nan) > t
                }
            }?.1
            if node == nil { return n.fallback }
        }
        return nil
    }

    open override var description: String {
        var out = ""
        rootNode?.describe("", "", into: &out)
        return out
    }
}
