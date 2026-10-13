// isim SpriteKit: inverse kinematics (adapted: isim's solver, cyclic coordinate descent). A reach action turns the
// nodes from the running node's parent up to the root node (each about its own position) so that the running node
// — the end effector — gets to a point in the scene, or follows a node. Each joint's zRotation stays within its
// reachConstraints (SKReachConstraints lower / upper angle limits). With a duration, the joints turn from where they
// were to the solution over that time (re-solved every frame for a moving target node); with a velocity, the
// duration is the effector's distance to the target divided by it.
import Foundation

enum _ReachTarget { case point(CGPoint); case node(SKNode) }

extension SKNode {
    /// the joints from the effector's parent up to (and including) root, nearest first; nil if root is not an ancestor
    func _ikChain(_ root: SKNode) -> [SKNode]? {
        var chain: [SKNode] = []
        var n = parent
        while let j = n {
            chain.append(j)
            if j === root { return chain }
            n = j.parent
        }
        return nil
    }
    /// joint rotations (same order as the chain) that bring this node closest to a scene point
    func _ikSolve(_ chain: [SKNode], target: CGPoint, iterations: Int = 24) -> [CGFloat] {
        guard let scene else { return chain.map(\.zRotation) }
        let saved = chain.map(\.zRotation)
        for _ in 0..<iterations {
            for j in chain {
                let jp = scene.convert(.zero, from: j)
                let ep = scene.convert(.zero, from: self)
                let a1 = atan2(ep.y - jp.y, ep.x - jp.x), a2 = atan2(target.y - jp.y, target.x - jp.x)
                var turn = a2 - a1
                turn = atan2(sin(turn), cos(turn))
                var r = j.zRotation + turn
                if let c = j.reachConstraints { r = min(max(r, c.lowerAngleLimit), c.upperAngleLimit) }
                j.zRotation = r
            }
            if _len(_sub(scene.convert(.zero, from: self), target)) < 0.25 { break }
        }
        let out = chain.map(\.zRotation)
        for (j, r) in zip(chain, saved) { j.zRotation = r }
        return out
    }
}

extension SKAction {
    static func _reach(_ target: _ReachTarget, _ root: SKNode, duration: TimeInterval?, velocity: CGFloat?) -> SKAction {
        SKAction(duration: duration ?? 0) { node, action in
            func goal() -> CGPoint? {
                switch target {
                case .point(let p): return p
                case .node(let t): return t.scene.map { $0.convert(.zero, from: t) }
                }
            }
            var d = duration ?? 0
            if let v = velocity, v > 0, let s = node.scene, let g = goal() { d = Double(_len(_sub(s.convert(.zero, from: node), g)) / v) }
            return _TimedRunner(node: node, duration: d, action: action, setup: { n in
                guard let chain = n._ikChain(root) else {
                    NSLog("isim SpriteKit: reach: the root node is not an ancestor of the node"); return { _ in }
                }
                let start = chain.map(\.zRotation)
                var solution = goal().map { n._ikSolve(chain, target: $0) } ?? start
                let moving: Bool = { if case .node = target { return true }; return false }()
                return { f in
                    if moving, let g = goal() {
                        // a moving target: solve again from where the joints are now
                        solution = n._ikSolve(chain, target: g)
                    }
                    for (k, j) in chain.enumerated() {
                        var delta = solution[k] - start[k]
                        delta = atan2(sin(delta), cos(delta))            // the short way round
                        if j.reachConstraints != nil { delta = solution[k] - start[k] }   // limits: no wrapping past them
                        j.zRotation = start[k] + delta * CGFloat(f)
                    }
                }
            })
        }
    }
}
