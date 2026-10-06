// HelloSpriteKit: a small SpriteKit game on isim. A menu loaded from Menu.sks, a doorway transition into a physics
// level (ramp, ball, boxes, coins, goal sensor, contacts), particles from Spark.sks and from code, a texture atlas
// (Hero.atlas), sounds, a GKStateMachine, GKGridGraph pathfinding, seeded GameplayKit random sources, constraints,
// a crop node, a camera with a HUD, the hardware keyboard (GCKeyboard) and an on-screen GCVirtualController.
import SwiftUI
import SpriteKit
import GameplayKit
import GameController

@main
struct HelloSpriteKitApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var scene: SKScene = {
        let s: SKScene = MenuScene(fileNamed: "Menu") ?? MenuScene(size: CGSize(width: 390, height: 844))
        s.scaleMode = .resizeFill
        return s
    }()
    var body: some View {
        SpriteView(scene: scene, debugOptions: [.showsNodeCount])
            .ignoresSafeArea()
    }
}

// MARK: - Menu

final class MenuScene: SKScene {
    override func sceneDidLoad() {
        let title = childNode(withName: "title") as? SKLabelNode
        print("menu loaded from sks: title=\(title?.text ?? "nil") logo=\(childNode(withName: "logo") != nil)")
    }

    override func didMove(to view: SKView) {
        print("menu size \(Int(size.width))x\(Int(size.height)) anchor \(anchorPoint.x),\(anchorPoint.y)")
        let play = SKShapeNode(rectOf: CGSize(width: 180, height: 56), cornerRadius: 14)
        play.name = "play"
        play.fillColor = UIColor(red: 0.2, green: 0.6, blue: 1, alpha: 1)
        play.strokeColor = .white
        play.lineWidth = 2
        play.glowWidth = 4
        play.position = CGPoint(x: 0, y: -40)
        let label = SKLabelNode(text: "Play")
        label.fontName = "Helvetica-Bold"; label.fontSize = 26
        label.verticalAlignmentMode = .center
        label.name = "play"
        play.addChild(label)
        addChild(play)
        play.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.5), .scale(to: 1, duration: 0.5)])))

        // falling snow: an emitter made in code, its particles left behind in the scene
        let snow = SKEmitterNode()
        snow.particleTexture = SKTexture(imageNamed: "spark")
        snow.particleBirthRate = 30
        snow.particleLifetime = 8
        snow.particlePositionRange = CGVector(dx: size.width, dy: 0)
        snow.position = CGPoint(x: 0, y: size.height / 2 + 10)
        snow.emissionAngle = -.pi / 2
        snow.particleSpeed = 60; snow.particleSpeedRange = 30
        snow.particleScale = 0.35; snow.particleScaleRange = 0.2
        snow.particleAlpha = 0.8
        snow.targetNode = self
        snow.advanceSimulationTime(4)
        addChild(snow)
        print("snow emitter advanced 4s")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if nodes(at: t.location(in: self)).contains(where: { $0.name == "play" }) {
            print("menu: play tapped -> doorway transition")
            let game = GameScene(size: size)
            game.scaleMode = .resizeFill
            view?.presentScene(game, transition: .doorway(withDuration: 0.6))
        }
    }
}

// MARK: - Game states

final class ReadyState: GKState {
    override func didEnter(from previousState: GKState?) { print("state ready") }
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { stateClass == PlayingState.self }
}
final class PlayingState: GKState {
    override func didEnter(from previousState: GKState?) { print("state playing (from \(previousState.map { "\(type(of: $0))" } ?? "none"))") }
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { stateClass == WonState.self }
}
final class WonState: GKState {
    weak var scene: GameScene?
    override func didEnter(from previousState: GKState?) {
        print("state won")
        scene?.run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.scene?.showWin() }]))
    }
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { false }
}

// MARK: - Game

enum Category {
    static let ball: UInt32 = 1 << 0
    static let box: UInt32 = 1 << 1
    static let goal: UInt32 = 1 << 2
    static let wall: UInt32 = 1 << 3
    static let coin: UInt32 = 1 << 4
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    let won = WonState()
    lazy var machine = GKStateMachine(states: [ReadyState(), PlayingState(), won])
    let ball = SKShapeNode(circleOfRadius: 14)
    let hud = SKLabelNode(text: "coins 0")
    var coins = 0
    var lastTime: TimeInterval = 0
    var elapsed: TimeInterval = 0
    var reported = Set<String>()
    var lastPop: TimeInterval = 0
    var virtualController: GCVirtualController?

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1)
        won.scene = self
        machine.enter(ReadyState.self)
        let W = size.width, H = size.height
        print("game size \(Int(W))x\(Int(H))")

        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        physicsBody?.categoryBitMask = Category.wall

        // camera at the center, with a HUD that stays on screen
        let cam = SKCameraNode()
        cam.position = CGPoint(x: W / 2, y: H / 2)
        addChild(cam)
        camera = cam
        hud.fontName = "Helvetica-Bold"; hud.fontSize = 20
        hud.horizontalAlignmentMode = .left
        hud.position = CGPoint(x: -W / 2 + 20, y: H / 2 - 110)
        cam.addChild(hud)

        // ramp (static polygon) from the upper left down to the right
        let rampPath = CGMutablePath()
        rampPath.move(to: CGPoint(x: 0, y: H * 0.62))
        rampPath.addLine(to: CGPoint(x: W - 70, y: H * 0.42))
        rampPath.addLine(to: CGPoint(x: W - 70, y: H * 0.42 - 12))
        rampPath.addLine(to: CGPoint(x: 0, y: H * 0.62 - 12))
        rampPath.closeSubpath()
        let ramp = SKShapeNode(path: rampPath)
        ramp.fillColor = UIColor(white: 0.55, alpha: 1); ramp.strokeColor = .clear
        ramp.physicsBody = SKPhysicsBody(polygonFrom: rampPath)
        ramp.physicsBody?.isDynamic = false
        ramp.physicsBody?.categoryBitMask = Category.wall
        ramp.name = "ramp"
        addChild(ramp)

        // ball
        ball.fillColor = UIColor(red: 1, green: 0.35, blue: 0.3, alpha: 1); ball.strokeColor = .white; ball.lineWidth = 2
        ball.position = CGPoint(x: 40, y: H * 0.62 + 40)
        ball.name = "ball"
        let body = SKPhysicsBody(circleOfRadius: 14)
        body.restitution = 0.3; body.friction = 0.3
        body.categoryBitMask = Category.ball
        body.collisionBitMask = Category.wall | Category.box          // passes through coins and the goal sensor
        body.contactTestBitMask = Category.box | Category.goal | Category.coin
        ball.physicsBody = body
        addChild(ball)

        // a box on the ramp in the ball's way, and a stack on the ground
        let rampY = { (x: CGFloat) in H * 0.62 + (H * 0.42 - H * 0.62) * x / (W - 70) }
        let blocker = addBox(at: CGPoint(x: W - 120, y: rampY(W - 120) + 16), size: 26)
        blocker.zRotation = atan2(H * 0.42 - H * 0.62, W - 70)
        blocker.physicsBody?.friction = 1
        ramp.physicsBody?.friction = 1
        for i in 0..<3 { addBox(at: CGPoint(x: 70, y: 20 + CGFloat(i) * 41), size: 40) }

        // coins along the ramp (sensors: contact, no collision); colors from a seeded random source
        let random = GKMersenneTwisterRandomSource(seed: 7)
        let hue = GKRandomDistribution(randomSource: random, lowestValue: 0, highestValue: 9)
        for k in 1...3 {
            let x = W * CGFloat(k) * 0.2
            let coin = SKShapeNode(circleOfRadius: 8)
            coin.fillColor = { let h = CGFloat(hue.nextInt()) / 9; return UIColor(red: 1 - h * 0.6, green: 0.6 + h * 0.4, blue: 0.2 + h * 0.8, alpha: 1) }()
            coin.strokeColor = .clear
            coin.position = CGPoint(x: x, y: rampY(x) + 16)
            coin.name = "coin"
            let cb = SKPhysicsBody(circleOfRadius: 8)
            cb.isDynamic = false
            cb.categoryBitMask = Category.coin
            cb.collisionBitMask = 0
            coin.physicsBody = cb
            addChild(coin)
        }

        // goal sensor in the lower right corner
        let goal = SKSpriteNode(color: UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 0.35), size: CGSize(width: 110, height: 90))
        goal.position = CGPoint(x: W - 55, y: 45)
        goal.name = "goal"
        goal.physicsBody = SKPhysicsBody(rectangleOf: goal.size)
        goal.physicsBody?.isDynamic = false
        goal.physicsBody?.categoryBitMask = Category.goal
        goal.physicsBody?.collisionBitMask = 0
        goal.physicsBody?.contactTestBitMask = Category.ball
        addChild(goal)

        addHero()
        addTurretAndCrop()
        addLab()
        setUpControllers()
        checkRandomSources()
    }

    @discardableResult func addBox(at p: CGPoint, size s: CGFloat) -> SKSpriteNode {
        let box = SKSpriteNode(color: UIColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1), size: CGSize(width: s, height: s))
        box.position = p
        box.name = "box"
        box.physicsBody = SKPhysicsBody(rectangleOf: box.size)
        box.physicsBody?.categoryBitMask = Category.box
        box.physicsBody?.friction = 0.6
        box.physicsBody?.collisionBitMask = Category.wall | Category.box | Category.ball
        addChild(box)
        return box
    }

    /// a walking hero (texture atlas animation) that follows a GKGridGraph path around obstacles
    func addHero() {
        let atlas = SKTextureAtlas(named: "Hero")
        let names = atlas.textureNames.sorted()
        print("atlas Hero: \(names.count) textures \(names.joined(separator: ","))")
        let frames = (1...4).map { atlas.textureNamed("hero_\($0)") }
        let hero = SKSpriteNode(texture: frames[0])
        print("hero texture size \(Int(hero.size.width))x\(Int(hero.size.height))")
        hero.name = "hero"
        hero.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))

        let cell: CGFloat = 34, cols: Int32 = 10, rows: Int32 = 4
        let origin = CGPoint(x: (size.width - CGFloat(cols) * cell) / 2 + cell / 2, y: size.height * 0.70)
        let graph = GKGridGraph<GKGridGraphNode>(fromGridStartingAt: vector_int2(0, 0), width: cols, height: rows, diagonalsAllowed: false)
        // a wall with a gap at the top: the path must go around it
        let walls = (0..<3).compactMap { graph.node(atGridPosition: vector_int2(5, Int32($0))) }
        graph.remove(walls)
        for w in walls {
            let block = SKSpriteNode(color: UIColor(white: 0.35, alpha: 1), size: CGSize(width: cell - 2, height: cell - 2))
            block.position = CGPoint(x: origin.x + CGFloat(w.gridPosition.x) * cell, y: origin.y + CGFloat(w.gridPosition.y) * cell)
            addChild(block)
        }
        guard let start = graph.node(atGridPosition: vector_int2(0, 0)), let end = graph.node(atGridPosition: vector_int2(9, 0)) else { return }
        let path = graph.findPath(from: start, to: end).compactMap { $0 as? GKGridGraphNode }
        print("path \(path.count) nodes: \(path.map { "(\($0.gridPosition.x),\($0.gridPosition.y))" }.joined(separator: " "))")
        hero.position = CGPoint(x: origin.x, y: origin.y)
        hero.zPosition = 5
        addChild(hero)
        let moves = path.dropFirst().map { n in
            SKAction.move(to: CGPoint(x: origin.x + CGFloat(n.gridPosition.x) * cell, y: origin.y + CGFloat(n.gridPosition.y) * cell), duration: 0.12)
        }
        hero.run(.sequence(moves + [.run { print("hero reached the end of the path") }]))
    }

    /// a turret that keeps aiming at the ball (SKConstraint), and a radar drawn through a circular crop mask
    func addTurretAndCrop() {
        let turret = SKSpriteNode(color: .cyan, size: CGSize(width: 34, height: 8))
        turret.anchorPoint = CGPoint(x: 0, y: 0.5)
        turret.position = CGPoint(x: size.width - 40, y: size.height * 0.62)
        turret.name = "turret"
        turret.constraints = [SKConstraint.orient(to: ball, offset: SKRange(constantValue: 0))]
        addChild(turret)

        let crop = SKCropNode()
        crop.position = CGPoint(x: size.width - 60, y: size.height - 170)
        let mask = SKShapeNode(circleOfRadius: 30)
        mask.fillColor = .white
        crop.maskNode = mask
        for i in 0..<6 {
            let stripe = SKSpriteNode(color: i % 2 == 0 ? UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1) : .black, size: CGSize(width: 120, height: 10))
            stripe.position = CGPoint(x: 0, y: CGFloat(i) * 10 - 25)
            crop.addChild(stripe)
        }
        crop.run(.repeatForever(.rotate(byAngle: .pi, duration: 2)))
        crop.name = "radar"
        addChild(crop)
    }

    /// joints and fields, up in the top-left corner: a pendulum (pin joint), a rope (limit joint), a spring,
    /// and a speck pulled by a radial gravity field
    var lab: [String: SKNode] = [:]
    func addLab() {
        func dot(_ p: CGPoint, _ r: CGFloat, dynamic: Bool, _ color: UIColor) -> SKShapeNode {
            let n = SKShapeNode(circleOfRadius: r)
            n.fillColor = color; n.strokeColor = .clear
            n.position = p
            let b = SKPhysicsBody(circleOfRadius: r)
            b.isDynamic = dynamic
            b.categoryBitMask = 1 << 5
            b.collisionBitMask = 0
            n.physicsBody = b
            addChild(n)
            return n
        }
        let top = size.height - 150
        let pivot = dot(CGPoint(x: 40, y: top), 3, dynamic: false, .white)
        let bob = dot(CGPoint(x: 100, y: top), 7, dynamic: true, .orange)
        physicsWorld.add(SKPhysicsJointPin.joint(withBodyA: pivot.physicsBody!, bodyB: bob.physicsBody!, anchor: pivot.position))
        let hook = dot(CGPoint(x: 130, y: top), 3, dynamic: false, .white)
        let weight = dot(CGPoint(x: 160, y: top - 10), 6, dynamic: true, .yellow)
        physicsWorld.add(SKPhysicsJointLimit.joint(withBodyA: hook.physicsBody!, bodyB: weight.physicsBody!, anchorA: hook.position, anchorB: weight.position))
        let springTop = dot(CGPoint(x: 40, y: top - 90), 3, dynamic: false, .white)
        let springBob = dot(CGPoint(x: 40, y: top - 120), 6, dynamic: true, .magenta)
        let spring = SKPhysicsJointSpring.joint(withBodyA: springTop.physicsBody!, bodyB: springBob.physicsBody!, anchorA: springTop.position, anchorB: springBob.position)
        spring.frequency = 2; spring.damping = 0.1
        physicsWorld.add(spring)
        let field = SKFieldNode.radialGravityField()
        field.position = CGPoint(x: 190, y: top - 90)
        field.region = SKRegion(radius: 90)
        field.strength = 4
        field.categoryBitMask = 1 << 1
        addChild(field)
        let speck = dot(CGPoint(x: 250, y: top - 90), 4, dynamic: true, .cyan)
        speck.physicsBody?.affectedByGravity = false
        speck.physicsBody?.fieldBitMask = 1 << 1
        speck.physicsBody?.linearDamping = 2
        lab = ["pivot": pivot, "bob": bob, "hook": hook, "weight": weight, "springTop": springTop, "springBob": springBob, "field": field, "speck": speck]
    }
    func reportLab() {
        func d(_ a: String, _ b: String) -> CGFloat { hypot(lab[a]!.position.x - lab[b]!.position.x, lab[a]!.position.y - lab[b]!.position.y) }
        let pendulum = d("pivot", "bob"), rope = d("hook", "weight"), spring = d("springTop", "springBob"), speck = d("field", "speck")
        print(String(format: "lab: pendulum %.0f (60) swung=%@ rope %.0f (<=32) spring %.0f speck %.0f (<60)",
                     pendulum, lab["bob"]!.position.y < size.height - 160 ? "yes" : "no", rope, spring, speck))
    }

    func setUpControllers() {
        NotificationCenter.default.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { _ in print("keyboard connected") }
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { n in
            print("controller connected: \((n.object as? GCController)?.vendorName ?? "?") extended=\((n.object as? GCController)?.extendedGamepad != nil)")
        }
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { [weak self] _, _, code, pressed in
            guard let self, let b = self.ball.physicsBody else { return }
            let name = code == .rightArrow ? "right" : code == .leftArrow ? "left" : code == .spacebar ? "space" : "\(code.rawValue)"
            print("key \(name) \(pressed ? "down" : "up")")
            guard pressed else { return }
            // the ball weighs about 0.03 kg (density 1 x area in square meters): small impulses
            if code == .rightArrow { b.applyImpulse(CGVector(dx: 0.01, dy: 0)) }
            if code == .leftArrow { b.applyImpulse(CGVector(dx: -0.01, dy: 0)) }
            if code == .spacebar { b.applyImpulse(CGVector(dx: 0, dy: 0.03)) }
        }
        let config = GCVirtualController.Configuration()
        config.elements = [GCInputLeftThumbstick, GCInputButtonA, GCInputButtonB]
        let vc = GCVirtualController(configuration: config)
        vc.connect()
        virtualController = vc
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let pad = vc.controller?.extendedGamepad else { return }
            pad.buttonA.pressedChangedHandler = { _, _, pressed in
                print("virtual A \(pressed ? "pressed" : "released")")
                if pressed { self?.ball.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 0.03)) }
            }
            pad.leftThumbstick.valueChangedHandler = { _, x, y in if abs(x) > 0.5 || abs(y) > 0.5 { print("virtual stick \(x > 0 ? "right" : x < 0 ? "left" : "center")") } }
        }
    }

    func checkRandomSources() {
        let mt = GKMersenneTwisterRandomSource(seed: 5489)
        print("mt19937 first \(UInt32(bitPattern: Int32(truncatingIfNeeded: mt.nextInt())))")
        let d6 = GKShuffledDistribution.d6()
        let roll = Set((0..<6).map { _ in d6.nextInt() })
        print("shuffled d6 covers 1...6: \(roll == Set(1...6))")
        let a = GKARC4RandomSource(seed: Data("isim".utf8)), b = GKARC4RandomSource(seed: Data("isim".utf8))
        a.dropValues(768); b.dropValues(768)
        print("arc4 reproducible: \(a.nextInt() == b.nextInt())")
        let shuffled = GKLinearCongruentialRandomSource(seed: 1).arrayByShufflingObjects(in: [1, 2, 3, 4, 5]) as? [Int] ?? []
        print("shuffle keeps elements: \(shuffled.sorted() == [1, 2, 3, 4, 5])")
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let names = [contact.bodyA.node?.name ?? "?", contact.bodyB.node?.name ?? "?"].sorted()
        let key = names.joined(separator: "-")
        if !reported.contains(key) { reported.insert(key); print("contact \(key)") }
        if names.contains("goal"), names.contains("ball"), machine.currentState is PlayingState { machine.enter(WonState.self) }
        if names.contains("coin"), let coin = [contact.bodyA.node, contact.bodyB.node].first(where: { $0?.name == "coin" }) ?? nil {
            coin.removeFromParent()
            coins += 1
            hud.text = "coins \(coins)"
            print("coin collected (\(coins))")
        }
        if names.contains("box"), elapsed - lastPop > 0.3 {
            lastPop = elapsed
            run(.playSoundFileNamed("pop.wav", waitForCompletion: false))
            if let spark = SKEmitterNode(fileNamed: "Spark") {
                spark.position = contact.contactPoint
                spark.zPosition = 10
                addChild(spark)
                spark.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
                if !reported.contains("spark") {
                    reported.insert("spark")
                    print("spark emitter from sks: birthRate=\(Int(spark.particleBirthRate)) toEmit=\(spark.numParticlesToEmit) texture=\(spark.particleTexture != nil) colorSequence=\(spark.particleColorSequence?.count() ?? 0)")
                }
            }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime > 0 ? currentTime - lastTime : 0
        lastTime = currentTime
        elapsed += dt
        machine.update(deltaTime: dt)
        if machine.currentState is ReadyState && elapsed > 0.2 { machine.enter(PlayingState.self) }
    }

    override func didSimulatePhysics() {
        if elapsed > 1, !reported.contains("fell") {
            reported.insert("fell")
            print("ball after 1s: y=\(Int(ball.position.y)) (start \(Int(size.height * 0.62 + 40))) moving=\(!(ball.physicsBody?.isResting ?? true))")
        }
        if elapsed > 1.5, !reported.contains("lab") { reported.insert("lab"); reportLab() }
    }

    func showWin() {
        let win = WinScene(size: size)
        win.scaleMode = .resizeFill
        win.coins = coins
        virtualController?.disconnect()
        print("presenting win scene (push)")
        view?.presentScene(win, transition: .push(with: .left, duration: 0.5))
    }
}

// MARK: - Win

final class WinScene: SKScene {
    var coins = 0
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.05, green: 0.25, blue: 0.15, alpha: 1)
        let label = SKLabelNode(text: "You win!")
        label.fontName = "Helvetica-Bold"; label.fontSize = 44
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(label)
        let sub = SKLabelNode(text: "coins: \(coins)")
        sub.fontSize = 22
        sub.position = CGPoint(x: size.width / 2, y: size.height / 2 - 44)
        addChild(sub)
        if let fireworks = SKEmitterNode(fileNamed: "Spark") {
            fireworks.numParticlesToEmit = 0
            fireworks.particleBirthRate = 120
            fireworks.position = CGPoint(x: size.width / 2, y: size.height / 2 + 120)
            addChild(fireworks)
        }
        run(.playSoundFileNamed("pop", waitForCompletion: false))
        print("win scene shown, coins \(coins)")
    }
}
