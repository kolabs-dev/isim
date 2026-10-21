// HelloSpriteKit3's nodes page (HELLOSK3_PAGE=nodes): logs "sk3 nodes …" lines, then "sk3 nodes done":
// inverse kinematics (reach actions, joint limits, a moving target), constraints, tile maps (automapping on a grid
// and on hexagons, isometric and hexagonal layouts), SKReferenceNode (by name and by URL) and the view's statistics
// overlay (showsNodeCount, showsDrawCount, showsQuadCount, showsFPS).
import UIKit
import SpriteKit

/// a solid square texture for tiles
func tileTexture(_ c: UIColor) -> SKTexture {
    drawnTexture(CGSize(width: 32, height: 32)) { g in
        g.setFillColor(c.cgColor); g.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
    }
}
func tileGroup(_ rules: [(SKTileAdjacencyMask, String, UIColor)]) -> SKTileGroup {
    SKTileGroup(rules: rules.map { (mask, name, color) in
        let d = SKTileDefinition(texture: tileTexture(color), size: CGSize(width: 32, height: 32)); d.name = name
        return SKTileGroupRule(adjacency: mask, tileDefinitions: [d])
    })
}

// A subclass of an SDK class from another module reaches Objective-C as a class stub: the @objc members of its
// extensions (put in __objc_catlist2) must still be attached, and its own Swift methods (constraints() below, a getter
// of SKNode in Objective-C) must stay Swift, as on iOS.
extension NodesScene {
    @objc func objcPing() {}
}

final class NodesScene: SKScene {
    /// runs f after t seconds of scene time (the simulation's clock, which lags the wall clock when frames are slow)
    func later(_ t: TimeInterval, _ f: @escaping () -> Void) { run(.sequence([.wait(forDuration: t), .run(f)])) }
    var pending = 0
    func finished() { pending -= 1; if pending == 0 { log("sk3 nodes done") } }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.1, alpha: 1)
        title("IK, constraints & tile maps")
        view.showsNodeCount = true; view.showsDrawCount = true; view.showsQuadCount = true; view.showsFPS = true
        pending = 4
        inverseKinematics(); constraints(); tileMaps(view); referenceNodes()
        log("sk3 nodes objc extension \(responds(to: #selector(objcPing))) \(NodesScene.instancesRespond(to: #selector(objcPing)))")
    }

    /// a two-segment arm: shoulder (root) -> upper -> lower -> hand, each segment `len` long along +x
    func arm(at p: CGPoint, _ len: CGFloat, color: UIColor) -> (SKNode, SKNode, SKNode, SKNode) {
        let shoulder = SKNode(); shoulder.position = p; addChild(shoulder)
        func segment() -> SKSpriteNode {
            let s = SKSpriteNode(color: color, size: CGSize(width: len, height: 8)); s.anchorPoint = CGPoint(x: 0, y: 0.5); return s
        }
        let upper = segment(); shoulder.addChild(upper)
        let lower = segment(); lower.position = CGPoint(x: len, y: 0); upper.addChild(lower)
        let hand = SKShapeNode(circleOfRadius: 6); hand.fillColor = .white; hand.strokeColor = .clear
        hand.position = CGPoint(x: len, y: 0); lower.addChild(hand)
        return (shoulder, upper, lower, hand)
    }
    func mark(_ p: CGPoint, _ c: UIColor) -> SKShapeNode {
        let m = SKShapeNode(circleOfRadius: 5); m.strokeColor = c; m.lineWidth = 2; m.position = p; addChild(m); return m
    }
    func scenePos(_ n: SKNode) -> CGPoint { convert(.zero, from: n) }
    func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    func inverseKinematics() {
        // a free arm reaching a point in 0.4 s
        let (_, upper, _, hand) = arm(at: at(40, 220), 60, color: .systemTeal)
        let goal = at(130, 160); _ = mark(goal, .yellow)
        hand.run(.reach(to: goal, rootNode: upper, duration: 0.4))
        // an elbow that only bends 0...0.5 rad: the hand stops short of a point it could otherwise reach
        let (_, upper2, lower2, hand2) = arm(at: at(160, 220), 60, color: .systemOrange)
        lower2.reachConstraints = SKReachConstraints(lowerAngleLimit: 0, upperAngleLimit: 0.5)
        let goal2 = at(180, 240); _ = mark(goal2, .yellow)
        hand2.run(.reach(to: goal2, rootNode: upper2, duration: 0.4))
        // following a moving node at 300 pt/s
        let (_, upper3, _, hand3) = arm(at: at(280, 220), 50, color: .systemPink)
        let dot = mark(at(350, 170), .green)
        dot.run(.moveBy(x: -20, y: 20, duration: 0.1))
        hand3.run(.reach(to: dot, rootNode: upper3, velocity: 300))
        later(1.0) {
            let reached = self.dist(self.scenePos(hand), goal) < 3
            let limited = lower2.zRotation >= -0.001 && lower2.zRotation <= 0.501
            let short = self.dist(self.scenePos(hand2), goal2) > 3
            let followed = self.dist(self.scenePos(hand3), self.scenePos(dot)) < 4
            log("sk3 nodes ik reached \(reached) limited \(limited) short \(short) followed \(followed)")
            self.finished()
        }
    }

    func constraints() {
        // distance: kept 40...60 from the anchor; orient: points +x at the anchor; position: x clamped in the
        // reference node's space
        let anchor = SKShapeNode(circleOfRadius: 6); anchor.fillColor = .red; anchor.strokeColor = .clear
        anchor.position = at(80, 330); addChild(anchor)
        let leash = SKSpriteNode(color: .systemGreen, size: CGSize(width: 24, height: 10)); leash.position = at(250, 330)
        leash.constraints = [.distance(SKRange(lowerLimit: 40, upperLimit: 60), to: anchor),
                             .orient(to: anchor, offset: SKRange(constantValue: 0))]
        addChild(leash)
        let box = SKNode(); box.position = at(250, 360); addChild(box)
        let slider = SKSpriteNode(color: .systemPurple, size: CGSize(width: 16, height: 16)); slider.position = at(380, 360)
        let clamp = SKConstraint.positionX(SKRange(lowerLimit: -30, upperLimit: 30)); clamp.referenceNode = box
        slider.constraints = [clamp]
        addChild(slider)
        later(0.3) {
            let d = self.dist(leash.position, anchor.position)
            let a = atan2(anchor.position.y - leash.position.y, anchor.position.x - leash.position.x)
            let oriented = abs(atan2(sin(leash.zRotation - a), cos(leash.zRotation - a))) < 0.01
            let x = self.convert(slider.position, to: box).x
            log("sk3 nodes constraints distance \(d <= 60.5 && d >= 39.5) oriented \(oriented) positionX \(abs(x - 30) < 0.5)")
            self.finished()
        }
    }

    func tileMaps(_ view: SKView) {
        // grid automapping: inner tiles green, the top edge blue, the lower-left corner red
        let grass = tileGroup([(.adjacencyAll, "center", .systemGreen), (.adjacencyUpEdge, "top", .systemBlue),
                               (.adjacencyLowerLeftEdge, "corner", .systemRed)])
        let set = SKTileSet(tileGroups: [grass])
        let grid = SKTileMapNode(tileSet: set, columns: 6, rows: 4, tileSize: CGSize(width: 24, height: 24))
        grid.enableAutomapping = true
        grid.fill(with: grass)
        grid.position = at(90, 470); addChild(grid)
        let name = { (c: Int, r: Int) in grid.tileDefinition(atColumn: c, row: r)?.name ?? "-" }
        let before = "\(name(2, 1)) \(name(2, 3)) \(name(0, 0))"
        grid.setTileGroup(nil, forColumn: 2, row: 2)      // a hole: its neighbours are mapped again
        let after = "\(name(2, 1)) \(name(2, 2))"
        // drawn with the automapped definitions
        var drawn = false
        if let t = view.texture(from: grid) {
            let u = { (c: Int) in (CGFloat(c) + 0.5) / 6 }, v = { (r: Int) in (CGFloat(r) + 0.5) / 4 }
            let center = texel(t, u(3), v(1)), top = texel(t, u(3), v(3)), corner = texel(t, u(0), v(0)), hole = texel(t, u(2), v(2))
            drawn = center[1] > 150 && center[2] < 120 && top[2] > 150 && top[0] < 100 && corner[0] > 200 && corner[1] < 100 && hole[3] == 0
        }
        log("sk3 nodes tiles grid \(before) after \(after) drawn \(drawn)")

        // layouts: every cell's center maps back to that cell
        func roundTrip(_ m: SKTileMapNode) -> Bool {
            for r in 0..<m.numberOfRows { for c in 0..<m.numberOfColumns {
                let p = m.centerOfTile(atColumn: c, row: r)
                if m.tileColumnIndex(fromPosition: p) != c || m.tileRowIndex(fromPosition: p) != r { return false }
            } }
            return true
        }
        let plain = tileGroup([(.adjacencyAll, "iso", .systemYellow)])
        let iso = SKTileMapNode(tileSet: SKTileSet(tileGroups: [plain], tileSetType: .isometric), columns: 4, rows: 4,
                                tileSize: CGSize(width: 40, height: 20), fillWith: plain)
        iso.position = at(300, 470); addChild(iso)
        // hexagons: the inner cell has all six neighbours; a corner (pointy: right and upper right; flat: down and
        // lower left) fewer
        let hex = tileGroup([(.hexPointyAdjacencyAdd, "inner", .systemTeal), (SKTileAdjacencyMask(rawValue: 6), "edge", .systemGray)])
        let pointy = SKTileMapNode(tileSet: SKTileSet(tileGroups: [hex], tileSetType: .hexagonalPointy), columns: 4, rows: 4,
                                   tileSize: CGSize(width: 28, height: 32))
        pointy.enableAutomapping = true; pointy.fill(with: hex)
        pointy.position = at(90, 620); addChild(pointy)
        let hexFlat = tileGroup([(.hexFlatAdjacencyAll, "inner", .systemIndigo), (SKTileAdjacencyMask(rawValue: 24), "edge", .systemGray)])
        let flat = SKTileMapNode(tileSet: SKTileSet(tileGroups: [hexFlat], tileSetType: .hexagonalFlat), columns: 4, rows: 4,
                                 tileSize: CGSize(width: 32, height: 28))
        flat.enableAutomapping = true; flat.fill(with: hexFlat)
        flat.position = at(300, 620); addChild(flat)
        let hexNames = "\(pointy.tileDefinition(atColumn: 1, row: 1)?.name ?? "-") \(pointy.tileDefinition(atColumn: 0, row: 0)?.name ?? "-") " +
                       "\(flat.tileDefinition(atColumn: 1, row: 1)?.name ?? "-") \(flat.tileDefinition(atColumn: 3, row: 3)?.name ?? "-")"
        log("sk3 nodes tiles iso \(roundTrip(iso)) size \(Int(iso.mapSize.width))x\(Int(iso.mapSize.height)) " +
            "pointy \(roundTrip(pointy)) flat \(roundTrip(flat)) hex \(hexNames)")
        finished()
    }

    func referenceNodes() {
        let byName = SKReferenceNode(fileNamed: "Badge")
        byName.position = at(120, 760); addChild(byName)
        let url = Bundle.main.url(forResource: "Badge", withExtension: "sks")
        let byURL = SKReferenceNode(url: url)
        byURL.position = at(270, 760); addChild(byURL)
        let badge = byName.childNode(withName: "badge") as? SKSpriteNode
        let caption = byURL.childNode(withName: "caption") as? SKLabelNode
        log("sk3 nodes reference name \(badge?.size == CGSize(width: 60, height: 60)) url \(caption?.text ?? "-") children \(byURL.children.count)")
        finished()
    }
}
