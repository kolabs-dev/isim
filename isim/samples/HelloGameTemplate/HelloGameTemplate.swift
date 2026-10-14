// Sample: Xcode's iOS Game template (SpriteKit + GameplayKit), on a scene file made by Xcode (issue #225). Logs "gt"
// lines: what GKScene(fileNamed:) decoded from GameScene.sks, then a GKScene built in code.
import UIKit
import SpriteKit
import GameplayKit

func log(_ s: String) { print("gt \(s)"); fflush(stdout) }

class GameScene: SKScene {
    var entities = [GKEntity]()
    var graphs = [String: GKGraph]()
    private var lastUpdateTime: TimeInterval = 0
    private var label: SKLabelNode?
    private var spinnyNode: SKShapeNode?

    override func sceneDidLoad() {
        lastUpdateTime = 0
        // the label made in the scene editor
        label = childNode(withName: "//helloLabel") as? SKLabelNode
        if let label {
            log("sceneDidLoad label=\(label.text ?? "nil") alpha=\(label.alpha)")
            label.alpha = 0.0
            label.run(SKAction.fadeIn(withDuration: 2.0))
        }
        let w = (size.width + size.height) * 0.05
        spinnyNode = SKShapeNode(rectOf: CGSize(width: w, height: w), cornerRadius: w * 0.3)
        if let spinnyNode {
            spinnyNode.lineWidth = 2.5
            spinnyNode.run(SKAction.repeatForever(SKAction.rotate(byAngle: CGFloat.pi, duration: 1)))
            spinnyNode.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.fadeOut(withDuration: 0.5), SKAction.removeFromParent()]))
        }
    }

    func touchDown(atPoint pos: CGPoint) {
        if let n = spinnyNode?.copy() as! SKShapeNode? {
            n.position = pos
            n.strokeColor = SKColor.green
            addChild(n)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        log("touch label scale=\(label?.xScale ?? 0)")
        if let label { label.run(SKAction(named: "Pulse")!, withKey: "fadeInOut") }
        for t in touches { touchDown(atPoint: t.location(in: self)) }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        for entity in entities { entity.update(deltaTime: dt) }
        lastUpdateTime = currentTime
    }
}

class GameViewController: UIViewController {
    override func loadView() { view = SKView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        // as Xcode's template: the GKScene of GameScene.sks, its root node a GameScene
        if let scene = GKScene(fileNamed: "GameScene") {
            if let sceneNode = scene.rootNode as! GameScene? {
                sceneNode.entities = scene.entities
                sceneNode.graphs = scene.graphs
                sceneNode.scaleMode = .aspectFill
                report(scene, sceneNode)
                if let view = view as! SKView? {
                    view.presentScene(sceneNode)
                    view.ignoresSiblingOrder = true
                    view.showsFPS = true
                    view.showsNodeCount = true
                }
            }
        } else {
            log("GKScene(fileNamed:) failed")
        }
        codeScene()
        if let pulse = SKAction(named: "Pulse") {
            log("pulse duration=\(pulse.duration) missing=\(SKAction(named: "Missing") == nil) "
                + "scaled=\(SKAction(named: "Pulse", duration: 1.2)?.duration ?? 0)")
        }
        log("ready")
    }

    func report(_ scene: GKScene, _ root: GameScene) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        root.backgroundColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        log("root class=\(type(of: root)) size=\(Int(root.size.width))x\(Int(root.size.height)) anchor=\(root.anchorPoint) "
            + String(format: "background=%.3f,%.3f,%.3f,%.1f", r, g, b, a) + " children=\(root.children.count)")
        if let label = root.childNode(withName: "helloLabel") as? SKLabelNode {
            var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
            label.fontColor?.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
            log("label text=\(label.text ?? "nil") font=\(label.fontName ?? "nil") size=\(Int(label.fontSize)) "
                + "color=\(Int(fr * 255)),\(Int(fg * 255)),\(Int(fb * 255)),\(Int(fa * 255)) "
                + "vertical=\(label.verticalAlignmentMode.rawValue) horizontal=\(label.horizontalAlignmentMode.rawValue) position=\(label.position)")
        }
        log("gkscene entities=\(scene.entities.count) graphs=\(scene.graphs.count) rootIsScene=\(scene.rootNode === root)")
    }

    /// a GKScene put together in code: an entity holding a sprite through GKSKNodeComponent, a graph
    func codeScene() {
        let scene = GKScene()
        let root = SKScene(size: CGSize(width: 100, height: 100))
        scene.rootNode = root
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 10))
        root.addChild(sprite)
        let entity = GKEntity()
        entity.addComponent(GKSKNodeComponent(node: sprite))
        scene.addEntity(entity)
        scene.addEntity(entity)                                   // once only
        scene.addGraph(GKGridGraph(fromGridStartingAt: vector_int2(0, 0), width: 3, height: 3, diagonalsAllowed: false), name: "grid")
        let nodeComponent = entity.component(ofType: GKSKNodeComponent.self)
        log("code entities=\(scene.entities.count) graphs=\(scene.graphs.keys.sorted()) nodeEntity=\(sprite.entity === entity) "
            + "component=\(nodeComponent?.node === sprite)")
        scene.removeGraph("grid")
        scene.removeEntity(entity)
        let copy = scene.copy() as! GKScene
        log("code after-remove entities=\(scene.entities.count) graphs=\(scene.graphs.count) copyRoot=\(copy.rootNode === root)")
    }

    override var prefersStatusBarHidden: Bool { true }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
