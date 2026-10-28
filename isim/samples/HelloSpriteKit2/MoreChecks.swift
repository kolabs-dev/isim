// More GameplayKit and SpriteKit checks printed as log lines (issue #395): 3D agents, composite behaviors, predicate
// rules, noise sources and tile maps from noise, graph helpers, decision trees saved to a file, the SceneKit node
// component; SKRenderer into a Metal texture, SKViewDelegate pacing, node intersection, filtered textures.
import Foundation
import SpriteKit
import GameplayKit
import SceneKit
import Metal
import CoreImage

enum MoreChecks {
    static func run(view: SKView) {
        agents3D()
        rules()
        noise()
        graphs()
        decisionTreeFile()
        sceneKitComponent()
        renderer()
        nodes()
        pacing(view)
    }

    static func f2(_ x: Float) -> String { String(format: "%.2f", x) }

    static func agents3D() {
        let target = GKAgent3D(); target.position = SIMD3(100, 0, 50)
        let a = GKAgent3D(); a.maxSpeed = 50; a.maxAcceleration = 100; a.radius = 1
        a.behavior = GKBehavior(goal: GKGoal(toSeekAgent: target), weight: 1)
        let start = simd_distance(a.position, target.position)
        for _ in 0..<60 { a.update(deltaTime: 1.0 / 30) }
        let end = simd_distance(a.position, target.position)
        let heading = simd_normalize(a.rotation.columns.2), dir = simd_normalize(a.velocity)
        log("agent3d: closer \(end < start - 20) heading follows velocity \(simd_dot(heading, dir) > 0.99) z moved \(a.position.z > 5)")
        // a 3D path: points as SIMD3, float3(at:)
        let pts = [SIMD3<Float>(0, 0, 0), SIMD3<Float>(10, 0, 0), SIMD3<Float>(10, 10, 5)]
        let path = GKPath(float3Points: pts, radius: 2, cyclical: false)
        log("path3d: \(path.numPoints) points third (\(Int(path.float3(at: 2).x)),\(Int(path.float3(at: 2).y)),\(Int(path.float3(at: 2).z)))")
        // composite behaviors
        let seek = GKBehavior(goal: GKGoal(toSeekAgent: target), weight: 1)
        let wander = GKBehavior(goal: GKGoal(toWander: 1), weight: 1)
        let c = GKCompositeBehavior(behaviors: [seek, wander], andWeights: [2, 0.5])
        c.setWeight(3, for: seek)
        let w = c.weight(for: seek), byIndex = (c[1] as GKBehavior) === wander, byBehavior = (c[wander] as NSNumber).floatValue
        c.remove(wander)
        log("composite: count \(c.behaviorCount) seek weight \(f2(w)) index 1 wander \(byIndex) wander weight \(f2(byBehavior))")
        c.removeAllBehaviors()
        log("composite after removeAll: \(c.behaviorCount)")
    }

    static func rules() {
        let system = GKRuleSystem()
        system.state["hungry" as NSString] = true
        let rule = GKNSPredicateRule(predicate: NSPredicate(format: "state.hungry == YES"))
        system.add(rule)
        let eat = GKRule(predicate: NSPredicate(format: "state.hungry == YES"), assertingFact: "eat" as NSString, grade: 1)
        system.add(eat)
        system.evaluate()
        log("predicate rule: true when hungry \(rule.evaluatePredicate(in: system)) fact eat \(system.grade(forFact: "eat" as NSString) == 1)")
        system.state["hungry" as NSString] = false
        log("predicate rule: false when fed \(!rule.evaluatePredicate(in: system))")
    }

    static func noise() {
        let checker = GKCheckerboardNoiseSource.checkerboardNoise(withSquareSize: 1)
        let constant = GKConstantNoiseSource.constantNoise(withValue: 0.25)
        let spheres = GKSpheresNoiseSource.spheresNoise(withFrequency: 1)
        let cylinders = GKCylindersNoiseSource.cylindersNoise(withFrequency: 1)
        let voronoi = GKVoronoiNoiseSource.voronoiNoise(withFrequency: 2, displacement: 1, distanceEnabled: false, seed: 7)
        let n = GKNoise(constant)
        log("noise factories: checker \(type(of: checker) == GKCheckerboardNoiseSource.self) constant \(f2(n.value(atPosition: vector_float2(3, 4)))) spheres \(spheres.frequency) cylinders \(cylinders.frequency) voronoi \(voronoi.seed)")
        // turbulence moves the samples: a checkerboard changes somewhere along a row
        let plain = GKNoise(checker), turbulent = GKNoise(checker)
        turbulent.applyTurbulence(frequency: 2, power: 0.6, roughness: 3, seed: 1)
        var differ = 0
        for i in 0..<64 { let p = vector_float2(Float(i) * 0.13 + 0.05, 0.37); if plain.value(atPosition: p) != turbulent.value(atPosition: p) { differ += 1 } }
        log("turbulence: changed samples \(differ > 4)")
        // constant displacement noises shift the field
        let shifted = GKNoise(checker)
        shifted.displaceWithNoises(x: GKNoise(GKConstantNoiseSource(value: 1)), y: GKNoise(GKConstantNoiseSource(value: 0)), z: GKNoise(GKConstantNoiseSource(value: 0)))
        log("displace: shifted by one square \(shifted.value(atPosition: vector_float2(0.5, 0.5)) == -plain.value(atPosition: vector_float2(0.5, 0.5)))")
        // tile maps from a noise map: one map per group, every cell in exactly one of them
        let map = GKNoiseMap(GKNoise(checker), size: vector_double2(4, 4), origin: .zero, sampleCount: vector_int2(4, 4), seamless: false)
        let dark = SKTileGroup(tileDefinition: SKTileDefinition(texture: SKTexture(image: UIImage()), size: CGSize(width: 8, height: 8)))
        let light = SKTileGroup(tileDefinition: SKTileDefinition(texture: SKTexture(image: UIImage()), size: CGSize(width: 8, height: 8)))
        let maps = SKTileMapNode.tileMapNodes(tileSet: SKTileSet(tileGroups: [dark, light]), columns: 4, rows: 4,
                                              tileSize: CGSize(width: 8, height: 8), from: map, tileTypeNoiseMapThresholds: [0])
        var counts = [0, 0], overlap = false
        for r in 0..<4 { for c in 0..<4 {
            let hits = maps.indices.filter { maps[$0].tileGroup(atColumn: c, row: r) != nil }
            if hits.count != 1 { overlap = true } else { counts[hits[0]] += 1 }
        } }
        log("tile maps from noise: \(maps.count) maps tiles \(counts[0])+\(counts[1]) one each \(!overlap)")
    }

    static func graphs() {
        let a = GKGraphNode2D.node(withPoint: vector_float2(0, 0)), b = PathNode.node(withPoint: vector_float2(5, 0))
        let c = GKGraphNode2D(point: vector_float2(20, 0))
        let g = GKGraph(nodes: [a, b, c])
        g.connectToLowestCostNode(node: a, bidirectional: false)
        log("graph: node(withPoint:) keeps class \(type(of: b) == PathNode.self) lowest cost link \(a.connectedNodes.count == 1 && a.connectedNodes[0] === b)")
        let grid = GKGridGraph(fromGridStartingAt: vector_int2(0, 0), width: 3, height: 3, diagonalsAllowed: false)
        if let mid = grid.node(atGridPosition: vector_int2(1, 1)) {
            grid.remove([mid])
            let back = GKGridGraphNode(gridPosition: vector_int2(1, 1))
            grid.connectToAdjacentNodes(node: back)
            log("grid graph: re-added node links \(back.connectedNodes.count)")
        }
        let p = GKGraphNode3D.node(withPoint: vector_float3(1, 2, 3))
        log("graph3d: node(withPoint:) z \(Int(p.position.z))")
    }

    static func decisionTreeFile() {
        let tree = GKDecisionTree(attribute: "hungry" as NSString)
        let root = tree.rootNode!
        root.createBranch(value: true as NSNumber, attribute: "eat" as NSString)
        root.createBranch(value: false as NSNumber, attribute: "play" as NSString)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tree.plist")
        let saved = tree.export(to: url, error: nil)
        let loaded = GKDecisionTree(url: url, error: nil)
        let x = loaded.findAction(forAnswers: ["hungry" as NSString: true as NSNumber]).map { "\($0)" } ?? "nil"
        let y = loaded.findAction(forAnswers: ["hungry" as NSString: false as NSNumber]).map { "\($0)" } ?? "nil"
        log("decision tree file: saved \(saved) hungry -> \(x) fed -> \(y)")
    }

    static func sceneKitComponent() {
        let node = SCNNode(); node.simdPosition = SIMD3(1, 2, 3)
        let entity = GKEntity()
        let comp = GKSCNNodeComponent(node: node)
        entity.addComponent(comp)
        let agent = GKAgent3D(); agent.delegate = comp
        agent.maxSpeed = 10; agent.maxAcceleration = 50
        let target = GKAgent3D(); target.position = SIMD3(1, 2, 30)
        agent.behavior = GKBehavior(goal: GKGoal(toSeekAgent: target), weight: 1)
        agent.update(deltaTime: 0.1)
        let startedAtNode = abs(agent.position.x - 1) < 0.5 && abs(agent.position.y - 2) < 0.5
        agent.update(deltaTime: 0.5)
        log("scn component: entity set \(node.entity === entity) agent starts at node \(startedAtNode) node follows \(node.simdPosition.z > 3)")
    }

    static func renderer() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { log("renderer: no device"); return }
        let scene = SKScene(size: CGSize(width: 64, height: 64))
        scene.backgroundColor = .clear
        scene.anchorPoint = .zero
        let box = SKSpriteNode(color: .red, size: CGSize(width: 32, height: 64))   // the left half
        box.anchorPoint = .zero
        scene.addChild(box)
        var updates = 0
        box.run(.repeatForever(.customAction(withDuration: 1) { _, _ in updates += 1 }))
        let r = SKRenderer(device: device)
        r.scene = scene
        r.update(atTime: 1); r.update(atTime: 1.1)
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 64, mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        guard let tex = device.makeTexture(descriptor: td), let cb = queue.makeCommandBuffer() else { log("renderer: no texture"); return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = tex
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 1, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        r.render(withViewport: CGRect(x: 0, y: 0, width: 64, height: 64), commandBuffer: cb, renderPassDescriptor: pass)
        cb.commit(); cb.waitUntilCompleted()
        var px = [UInt8](repeating: 0, count: 64 * 64 * 4)
        tex.getBytes(&px, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
        func bgra(_ x: Int, _ y: Int) -> String { let i = (y * 64 + x) * 4; return "\(px[i]),\(px[i + 1]),\(px[i + 2])" }
        log("renderer: left \(bgra(10, 32)) right \(bgra(50, 32)) updates \(updates > 0)")
    }

    static func nodes() {
        let a = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 10)), b = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 10))
        let parent = SKNode(); parent.position = CGPoint(x: 100, y: 0)
        let scene = SKScene(size: CGSize(width: 200, height: 200))
        scene.addChild(a); scene.addChild(parent); parent.addChild(b)
        b.position = CGPoint(x: -95, y: 0)
        let near = a.intersects(b)
        b.position = CGPoint(x: 0, y: 0)
        log("intersects: overlapping \(near) apart \(!a.intersects(b))")
        let normal = SKTexture(image: UIImage()), sp = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 4))
        sp.run(.setNormalTexture(normal))
        sp.focusBehavior = .focusable
        let copy = sp.copy() as! SKSpriteNode
        log("focus behavior: \(sp.focusBehavior == .focusable) copied \(copy.focusBehavior == .focusable)")
        // a filtered texture: Core Image inverts a white texture to black
        let white = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4)) })
        let inverted = white.applying(CIFilter(name: "CIColorInvert")!)
        var rgba = [UInt8](repeating: 0, count: 4)
        if let cg = inverted.cgImage(), let c = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            c.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        log("texture applying filter: \(rgba[0]),\(rgba[1]),\(rgba[2]) size \(Int(inverted.size().width)) constants \(SK_VERSION > 0 && SKVIEW_AVAILABLE == 1 && GK_VERSION > 0)")
    }

    /// a delegate that holds the view's frames back: the scene's update stops until it lets them through
    final class Pacer: NSObject, SKViewDelegate {
        var asked = 0, hold = true
        func view(_ view: SKView, shouldRenderAtTime time: TimeInterval) -> Bool { asked += 1; return !hold }
    }
    nonisolated(unsafe) static var pacer: Pacer?
    static func pacing(_ view: SKView) {
        guard let scene = view.scene as? LabScene else { return }
        let p = Pacer(); pacer = p
        view.delegate = p
        let before = scene.updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let held = scene.updates - before
            p.hold = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                log("view delegate: asked \(p.asked > 5) held updates \(held) then running \(scene.updates - before > held)")
                view.delegate = nil
                log("more checks done")
            }
        }
    }
}
