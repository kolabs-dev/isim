// GameplayKit checks printed as log lines: navigation graphs, strategists, decision trees, spatial trees.
import Foundation
import SpriteKit
import GameplayKit

final class PathNode: GKGraphNode2D {}

enum GameplayChecks {
    static func run() {
        obstacleGraph()
        meshGraph()
        strategists()
        decisionTrees()
        spatialTrees()
        log("gameplay checks done")
    }

    static func p(_ n: GKGraphNode) -> String {
        guard let n = n as? GKGraphNode2D else { return "?" }
        return "(\(Int(n.position.x.rounded())),\(Int(n.position.y.rounded())))"
    }
    static func length(_ path: [GKGraphNode]) -> Float {
        zip(path, path.dropFirst()).reduce(0) { $0 + simd_distance(($1.0 as! GKGraphNode2D).position, ($1.1 as! GKGraphNode2D).position) }
    }
    /// does any segment of the path pass through the square (strictly inside)?
    static func crosses(_ path: [GKGraphNode], _ lo: vector_float2, _ hi: vector_float2) -> Bool {
        for (a, b) in zip(path, path.dropFirst()) {
            let pa = (a as! GKGraphNode2D).position, pb = (b as! GKGraphNode2D).position
            for k in 1..<100 {
                let q = pa + (pb - pa) * (Float(k) / 100)
                if q.x > lo.x + 0.5 && q.x < hi.x - 0.5 && q.y > lo.y + 0.5 && q.y < hi.y - 0.5 { return true }
            }
        }
        return false
    }
    static func square(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float) -> GKPolygonObstacle {
        GKPolygonObstacle(points: [vector_float2(x0, y0), vector_float2(x1, y0), vector_float2(x1, y1), vector_float2(x0, y1)])
    }

    // MARK: navigation

    static func obstacleGraph() {
        let box = square(100, 100, 200, 200)
        let graph = GKObstacleGraph(obstacles: [box], bufferRadius: 10, nodeClass: PathNode.self)
        let corners = graph.nodes(forObstacle: box)
        let start = PathNode(point: vector_float2(50, 150)), end = PathNode(point: vector_float2(250, 150))
        graph.connectUsingObstacles(node: start)
        graph.connectUsingObstacles(node: end)
        let path = graph.findPath(from: start, to: end)
        log("obstacle graph: corners \(corners.count) \(corners.map { p($0) }.joined(separator: " ")) custom class \(corners.allSatisfy { $0 is PathNode }) nodes \(graph.nodes?.count ?? 0)")
        log("obstacle path: \(path.count) nodes \(path.map { p($0) }.joined(separator: " ")) length \(Int(length(path).rounded())) clear \(!crosses(path, vector_float2(100, 100), vector_float2(200, 200)))")
        let direct = start.connectedNodes.contains { $0 === end }
        log("obstacle graph: start sees end directly \(direct), start links \(start.connectedNodes.count)")
        // a locked connection survives a new obstacle that blocks it; the unlocked reverse direction does not
        guard let a = corners.first(where: { abs($0.position.x - 90) < 1 && abs($0.position.y - 90) < 1 }),
              let b = corners.first(where: { abs($0.position.x - 210) < 1 && abs($0.position.y - 90) < 1 }) else { log("obstacle lock: corners missing"); return }
        graph.lockConnection(from: a, to: b)
        graph.addObstacles([square(140, 70, 160, 110)])
        log("obstacle lock: locked \(graph.isConnectionLocked(from: a, to: b)) a->b kept \(a.connectedNodes.contains { $0 === b }) b->a kept \(b.connectedNodes.contains { $0 === a }) obstacles \(graph.obstacles.count)")
        let path2 = graph.findPath(from: end, to: start)
        log("obstacle path after second obstacle: \(path2.count) nodes clear \(!crosses(path2, vector_float2(100, 100), vector_float2(200, 200)) && !crosses(path2, vector_float2(140, 70), vector_float2(160, 110)))")
        graph.removeObstacles([box])
        let path3 = graph.findPath(from: start, to: end)
        log("obstacle graph after removing the box: path \(path3.count) nodes")
        let node = SKSpriteNode(color: .red, size: CGSize(width: 40, height: 20))
        node.position = CGPoint(x: 100, y: 100)
        let scene = SKScene(size: CGSize(width: 300, height: 300)); scene.addChild(node)
        let obs = SKNode.obstacles(fromNodeBounds: [node])
        log("obstacles from node bounds: \(obs.count) vertices \(obs[0].vertexCount) first (\(Int(obs[0].vertex(at: 0).x)),\(Int(obs[0].vertex(at: 0).y)))")
    }

    static func meshGraph() {
        let mesh = GKMeshGraph<GKGraphNode2D>(bufferRadius: 5, minCoordinate: vector_float2(0, 0), maxCoordinate: vector_float2(300, 300))
        mesh.addObstacles([square(100, 100, 200, 200)])
        mesh.triangulate()
        var inside = 0
        for i in 0..<mesh.triangleCount {
            let t = mesh.triangle(at: i)
            let c = (t.points.0 + t.points.1 + t.points.2) / 3
            if c.x > 100 && c.x < 200 && c.y > 100 && c.y < 200 { inside += 1 }
        }
        let start = GKGraphNode2D(point: vector_float2(20, 150)), end = GKGraphNode2D(point: vector_float2(280, 150))
        mesh.connectUsingObstacles(node: start)
        mesh.connectUsingObstacles(node: end)
        let path = mesh.findPath(from: start, to: end)
        let len = length(path)
        log("mesh graph: triangles \(mesh.triangleCount) inside obstacle \(inside) nodes \(mesh.nodes?.count ?? 0) path \(path.count) nodes clear \(!crosses(path, vector_float2(100, 100), vector_float2(200, 200))) length ok \(len > 260 && len < 420)")
        mesh.triangulationMode = [.centers, .edgeMidpoints]
        mesh.triangulate()
        let path2 = mesh.findPath(from: start, to: end)
        log("mesh graph centers+midpoints: path \(path2.isEmpty ? "none" : "found") clear \(!crosses(path2, vector_float2(100, 100), vector_float2(200, 200)))")
    }

    // MARK: strategists

    static func strategists() {
        // X to move: X has 0, 1 (wins at 2); O has 3, 4
        let b = Board(cells: "XX.OO....", turn: .x)
        let mm = GKMinmaxStrategist(); mm.gameModel = b; mm.maxLookAheadDepth = 3
        let winMove = mm.bestMoveForActivePlayer() as? Move
        let win = winMove?.cell ?? -1
        // X to move must block O at 5: X has 0, 8; O has 3, 4
        let b2 = Board(cells: "X..OO...X", turn: .x)
        mm.gameModel = b2
        let block = (mm.bestMove(for: b2.players![0]) as? Move)?.cell ?? -1
        log("minmax: win move \(win) value \(winMove?.value ?? 0) block move \(block)")
        // perfect play from the empty board ends in a draw
        let game = Board(cells: ".........", turn: .x)
        mm.maxLookAheadDepth = 9
        mm.randomSource = GKMersenneTwisterRandomSource(seed: 7)
        var moves: [Int] = []
        while game.winner == nil && game.cells.contains(".") {
            mm.gameModel = game
            guard let m = mm.bestMoveForActivePlayer() as? Move else { break }
            game.apply(m); moves.append(m.cell)
        }
        log("minmax self-play: \(game.winner.map { "\($0) wins" } ?? "draw") after \(moves.count) moves")
        mm.gameModel = Board(cells: "XX.OO....", turn: .x)
        let r1 = (mm.randomMove(for: (mm.gameModel as! Board).players![0], fromNumberOfBestMoves: 1) as? Move)?.cell ?? -1
        log("minmax randomMove(best 1): \(r1)")

        let mc = GKMonteCarloStrategist()
        mc.gameModel = Board(cells: "XX.OO....", turn: .x)
        mc.budget = 3000; mc.explorationParameter = 1
        mc.randomSource = GKMersenneTwisterRandomSource(seed: 42)
        let mcWin = (mc.bestMoveForActivePlayer() as? Move)?.cell ?? -1
        mc.gameModel = Board(cells: "X..OO...X", turn: .x)
        let mcBlock = (mc.bestMoveForActivePlayer() as? Move)?.cell ?? -1
        log("montecarlo: win move \(mcWin) block move \(mcBlock)")
    }

    // MARK: decision trees

    static func decisionTrees() {
        let tree = GKDecisionTree(attribute: "hungry" as NSString)
        let root = tree.rootNode!
        root.createBranch(value: true as NSNumber, attribute: "eat" as NSString)
        let notHungry = root.createBranch(value: false as NSNumber, attribute: "energy" as NSString)
        notHungry.createBranch(predicate: NSPredicate(format: "SELF < 3"), attribute: "sleep" as NSString)
        notHungry.createBranch(predicate: NSPredicate(format: "SELF >= 3"), attribute: "play" as NSString)
        let a1 = tree.findAction(forAnswers: ["hungry": true as NSNumber])
        let a2 = tree.findAction(forAnswers: ["hungry": false as NSNumber, "energy": 1 as NSNumber])
        let a3 = tree.findAction(forAnswers: ["hungry": false as NSNumber, "energy": 7 as NSNumber])
        log("decision tree: hungry -> \(a1.map { "\($0)" } ?? "nil"), tired -> \(a2.map { "\($0)" } ?? "nil"), rested -> \(a3.map { "\($0)" } ?? "nil")")

        let random = GKDecisionTree(attribute: "coin" as NSString)
        random.randomSource = GKMersenneTwisterRandomSource(seed: 3)
        random.rootNode!.createBranch(weight: 3, attribute: "heads" as NSString)
        random.rootNode!.createBranch(weight: 1, attribute: "tails" as NSString)
        var heads = 0
        for _ in 0..<400 where "\(random.findAction(forAnswers: [:])!)" == "heads" { heads += 1 }
        log("decision tree weights 3:1 -> heads \(heads)/400 in range \(heads > 260 && heads < 340)")

        // the classic "play tennis" data (Quinlan): outlook, temperature, humidity, wind -> play
        let rows: [(String, String, String, String, String)] = [
            ("sunny", "hot", "high", "weak", "no"), ("sunny", "hot", "high", "strong", "no"), ("overcast", "hot", "high", "weak", "yes"),
            ("rain", "mild", "high", "weak", "yes"), ("rain", "cool", "normal", "weak", "yes"), ("rain", "cool", "normal", "strong", "no"),
            ("overcast", "cool", "normal", "strong", "yes"), ("sunny", "mild", "high", "weak", "no"), ("sunny", "cool", "normal", "weak", "yes"),
            ("rain", "mild", "normal", "weak", "yes"), ("sunny", "mild", "normal", "strong", "yes"), ("overcast", "mild", "high", "strong", "yes"),
            ("overcast", "hot", "normal", "weak", "yes"), ("rain", "mild", "high", "strong", "no")]
        let attrs: [NSObjectProtocol] = ["outlook" as NSString, "temperature" as NSString, "humidity" as NSString, "wind" as NSString]
        let examples: [[NSObjectProtocol]] = rows.map { [$0.0 as NSString, $0.1 as NSString, $0.2 as NSString, $0.3 as NSString] }
        let learned = GKDecisionTree(examples: examples, actions: rows.map { $0.4 as NSString }, attributes: attrs)
        var correct = 0
        for r in rows {
            let answer = learned.findAction(forAnswers: ["outlook": r.0 as NSString, "temperature": r.1 as NSString, "humidity": r.2 as NSString, "wind": r.3 as NSString])
            if let answer, "\(answer)" == r.4 { correct += 1 }
        }
        let q1 = learned.findAction(forAnswers: ["outlook": "sunny" as NSString, "humidity": "high" as NSString])
        let q2 = learned.findAction(forAnswers: ["outlook": "overcast" as NSString])
        let q3 = learned.findAction(forAnswers: ["outlook": "rain" as NSString, "wind": "strong" as NSString])
        log("id3: root \(learned.description.split(separator: "\n").first.map(String.init) ?? "") accuracy \(correct)/\(rows.count) sunny+high -> \(q1.map { "\($0)" } ?? "nil") overcast -> \(q2.map { "\($0)" } ?? "nil") rain+strong -> \(q3.map { "\($0)" } ?? "nil")")
        log("id3 tree:\n\(learned.description)")

        // numeric attribute: learned threshold
        let temps: [[NSObjectProtocol]] = [5, 8, 12, 15, 18, 21, 24, 27, 30, 33].map { [$0 as NSNumber] }
        let labels: [NSObjectProtocol] = ["cold", "cold", "cold", "cold", "warm", "warm", "warm", "warm", "warm", "warm"].map { $0 as NSString }
        let numeric = GKDecisionTree(examples: temps, actions: labels, attributes: ["temp" as NSString])
        let t10 = numeric.findAction(forAnswers: ["temp": 10 as NSNumber]).map { "\($0)" } ?? "nil"
        let t26 = numeric.findAction(forAnswers: ["temp": 26 as NSNumber]).map { "\($0)" } ?? "nil"
        log("id3 numeric: 10 -> \(t10) 26 -> \(t26)")
    }

    // MARK: spatial trees

    static func spatialTrees() {
        let quad = GKQuadtree<NSString>(boundingQuad: GKQuad(quadMin: vector_float2(0, 0), quadMax: vector_float2(100, 100)), minimumCellSize: 1)
        var nodes: [String: GKQuadtreeNode] = [:]
        for i in 0..<10 { for j in 0..<10 {
            let name = "p\(i)\(j)"
            nodes[name] = quad.add(name as NSString, at: vector_float2(5 + 10 * Float(i), 5 + 10 * Float(j)))
        } }
        let q = quad.elements(in: GKQuad(quadMin: vector_float2(0, 0), quadMax: vector_float2(30, 30)))
        let removed = quad.remove("p00" as NSString)
        let q2 = quad.elements(in: GKQuad(quadMin: vector_float2(0, 0), quadMax: vector_float2(30, 30)))
        let atPoint = quad.elements(at: vector_float2(55, 55)).contains { $0 == "p55" }
        let viaNode = quad.remove("p11" as NSString, using: nodes["p11"]!)
        let cell = nodes["p55"]!.quad
        log("quadtree: in (0,0)-(30,30) \(q.count) remove \(removed) after \(q2.count) at point \(atPoint) remove via node \(viaNode) cell size \(f2(cell.quadMax.x - cell.quadMin.x))")
        let big = NSString(string: "area")
        quad.add(big, in: GKQuad(quadMin: vector_float2(40, 40), quadMax: vector_float2(60, 60)))
        log("quadtree: area element found \(quad.elements(in: GKQuad(quadMin: vector_float2(58, 58), quadMax: vector_float2(70, 70))).contains { $0 === big })")

        let oct = GKOctree<NSNumber>(boundingBox: GKBox(boxMin: vector_float3(0, 0, 0), boxMax: vector_float3(50, 50, 50)), minimumCellSize: 1)
        var n = 0
        for x in 0..<5 { for y in 0..<5 { for z in 0..<5 {
            oct.add(n as NSNumber, at: vector_float3(5 + 10 * Float(x), 5 + 10 * Float(y), 5 + 10 * Float(z))); n += 1
        } } }
        let inBox = oct.elements(in: GKBox(boxMin: vector_float3(0, 0, 0), boxMax: vector_float3(40, 40, 40)))
        log("octree: \(n) points, in (0..40)^3 \(inBox.count), remove \(oct.remove(0 as NSNumber)) then \(oct.elements(in: GKBox(boxMin: vector_float3(0, 0, 0), boxMax: vector_float3(40, 40, 40))).count)")

        final class Item { let id: Int; let lo: vector_float2; let hi: vector_float2; init(_ i: Int, _ l: vector_float2, _ h: vector_float2) { id = i; lo = l; hi = h } }
        for (name, strategy) in [("half", GKRTreeSplitStrategy.halfSplit), ("linear", .linearSplit), ("quadratic", .quadraticSplit), ("reduceOverlap", .reduceOverlap)] {
            let rng = GKMersenneTwisterRandomSource(seed: 11)
            func r(_ k: Float) -> Float { rng.nextUniform() * k }
            let tree = GKRTree<Item>(maxNumberOfChildren: 4)
            var items: [Item] = []
            for i in 0..<300 {
                let lo = vector_float2(r(1000), r(1000)), it = Item(i, lo, lo + vector_float2(r(40), r(40)))
                items.append(it)
                tree.addElement(it, boundingRectMin: it.lo, boundingRectMax: it.hi, splitStrategy: strategy)
            }
            func check() -> (Bool, Int) {
                var ok = true, total = 0
                for _ in 0..<25 {
                    let a = vector_float2(r(1000), r(1000)), b = a + vector_float2(r(200), r(200))
                    let got = Set(tree.elements(inBoundingRectMin: a, rectMax: b).map(\.id))
                    let want = Set(items.filter { !($0.hi.x < a.x || $0.lo.x > b.x || $0.hi.y < a.y || $0.lo.y > b.y) }.map(\.id))
                    if got != want { ok = false }
                    total += got.count
                }
                return (ok, total)
            }
            let (ok1, t1) = check()
            for it in items.prefix(120) { tree.removeElement(it, boundingRectMin: it.lo, boundingRectMax: it.hi) }
            items.removeFirst(120)
            let (ok2, t2) = check()
            log("rtree \(name): queries match brute force \(ok1 && ok2) (\(t1) + \(t2) hits)")
        }
    }
}

// MARK: - Tic-tac-toe model

final class Player: NSObject, GKGameModelPlayer {
    enum Mark: String { case x = "X", o = "O" }
    let mark: Mark
    var playerId: Int { mark == .x ? 0 : 1 }
    init(_ m: Mark) { mark = m }
    static let x = Player(.x), o = Player(.o)
    static let all = [x, o]
}

final class Move: NSObject, GKGameModelUpdate {
    var value = 0
    let cell: Int
    init(_ c: Int) { cell = c }
}

final class Board: NSObject, GKGameModel {
    var cells: [Character]
    var turn: Player.Mark
    init(cells: String, turn: Player.Mark) { self.cells = Array(cells); self.turn = turn }

    var players: [GKGameModelPlayer]? { Player.all }
    var activePlayer: GKGameModelPlayer? { turn == .x ? Player.x : Player.o }
    func copy(with zone: NSZone? = nil) -> Any {
        let b = Board(cells: String(cells), turn: turn)
        b.setGameModel(self)
        return b
    }
    func setGameModel(_ gameModel: GKGameModel) {
        guard let b = gameModel as? Board else { return }
        cells = b.cells; turn = b.turn
    }
    func gameModelUpdates(for player: GKGameModelPlayer) -> [GKGameModelUpdate]? {
        guard winner == nil else { return nil }
        let free = cells.indices.filter { cells[$0] == "." }
        return free.isEmpty ? nil : free.map { Move($0) }
    }
    func apply(_ gameModelUpdate: GKGameModelUpdate) {
        guard let m = gameModelUpdate as? Move else { return }
        cells[m.cell] = Character(turn.rawValue)
        turn = turn == .x ? .o : .x
    }
    static let lines = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
    var winner: String? {
        for l in Board.lines where cells[l[0]] != "." && cells[l[0]] == cells[l[1]] && cells[l[1]] == cells[l[2]] { return String(cells[l[0]]) }
        return nil
    }
    func isWin(for player: GKGameModelPlayer) -> Bool { winner == (player.playerId == 0 ? "X" : "O") }
    func isLoss(for player: GKGameModelPlayer) -> Bool { winner != nil && !isWin(for: player) }
    func score(for player: GKGameModelPlayer) -> Int { isWin(for: player) ? 1000 : isLoss(for: player) ? -1000 : 0 }
}
