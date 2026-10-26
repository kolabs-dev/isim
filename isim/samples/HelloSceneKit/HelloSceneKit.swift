// Sample: SceneKit on isim (issue #330), drawn by isim's Metal on the CPU. An SCNView shows SceneKit's built-in shapes
// lit by ambient, directional, omni and spot lights: a textured box spinning (SCNAction), a physically based sphere, a
// crystal loaded from a Wavefront OBJ file, a ball that falls onto the floor (SCNPhysicsBody, contact delegate), a
// camera aimed by a look-at constraint, fog, hit tests and projection. Below it, SwiftUI's SceneView and SpriteKit's
// SK3DNode show a second scene. Progress goes to the log as "scenekit ..." lines, which tests/ui/test_scenekit.py reads.
import UIKit
import SceneKit
import SpriteKit
import SwiftUI

func log(_ s: String) { print("scenekit " + s) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = SceneViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// the second scene: a torus turning, lit by SceneKit's default light
func ringScene() -> SCNScene {
    let scene = SCNScene()
    scene.background.contents = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
    let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.8, pipeRadius: 0.3))
    ring.name = "ring"
    ring.geometry?.firstMaterial?.diffuse.contents = UIColor.systemOrange
    ring.geometry?.firstMaterial?.specular.contents = UIColor.white
    ring.geometry?.firstMaterial?.shininess = 30
    ring.eulerAngles.x = .pi / 3
    ring.runAction(.repeatForever(.rotateBy(x: 0, y: .pi, z: 0, duration: 4)))
    scene.rootNode.addChildNode(ring)
    return scene
}

final class SceneViewController: UIViewController, SCNPhysicsContactDelegate, SCNSceneRendererDelegate, CAAnimationDelegate {
    let scnView = SCNView()
    var frames = 0
    var checked = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "SceneKit on the CPU"
        title.font = .preferredFont(forTextStyle: .headline)
        title.translatesAutoresizingMaskIntoConstraints = false
        scnView.translatesAutoresizingMaskIntoConstraints = false
        scnView.accessibilityIdentifier = "scene"
        scnView.scene = makeScene()
        scnView.delegate = self
        scnView.preferredFramesPerSecond = 30
        scnView.allowsCameraControl = true
        scnView.scene?.physicsWorld.contactDelegate = self

        // SwiftUI's SceneView and SpriteKit's SK3DNode, side by side
        let ui = UIHostingController(rootView: SceneView(scene: ringScene(), options: [.autoenablesDefaultLighting]))
        addChild(ui)
        ui.view.translatesAutoresizingMaskIntoConstraints = false
        ui.view.accessibilityIdentifier = "sceneview"
        let skView = SKView()
        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.accessibilityIdentifier = "sk3d"
        let sk = SKScene(size: CGSize(width: 160, height: 160))
        sk.backgroundColor = UIColor(red: 0.1, green: 0.25, blue: 0.2, alpha: 1)
        let node3d = SK3DNode(viewportSize: CGSize(width: 140, height: 140))
        node3d.position = CGPoint(x: 80, y: 80)
        node3d.scnScene = ringScene()
        node3d.autoenablesDefaultLighting = true
        sk.addChild(node3d)
        skView.presentScene(sk)
        for v in [title, scnView, ui.view!, skView] { view.addSubview(v) }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scnView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            scnView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scnView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scnView.heightAnchor.constraint(equalToConstant: 320),
            ui.view.topAnchor.constraint(equalTo: scnView.bottomAnchor, constant: 16),
            ui.view.leadingAnchor.constraint(equalTo: scnView.leadingAnchor),
            ui.view.widthAnchor.constraint(equalToConstant: 160),
            ui.view.heightAnchor.constraint(equalToConstant: 160),
            skView.topAnchor.constraint(equalTo: ui.view.topAnchor),
            skView.trailingAnchor.constraint(equalTo: scnView.trailingAnchor),
            skView.widthAnchor.constraint(equalToConstant: 160),
            skView.heightAnchor.constraint(equalToConstant: 160),
        ])
        ui.didMove(toParent: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // a point on the ring, projected into the node and picked back
            guard let ring = node3d.scnScene?.rootNode.childNode(withName: "ring", recursively: false) else { return }
            let p = node3d.projectPoint(ring.simdConvertPosition(SIMD3(0.8, 0, 0), to: nil))
            let hits = node3d.hitTest(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
            log("sk3d hit \(hits.first?.node.name ?? "none")")
        }
    }

    func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.55, green: 0.7, blue: 0.9, alpha: 1)
        scene.fogStartDistance = 12
        scene.fogEndDistance = 30
        scene.fogColor = UIColor(red: 0.55, green: 0.7, blue: 0.9, alpha: 1)
        let root = scene.rootNode

        // the floor: static, grey
        let floor = SCNNode(geometry: SCNFloor())
        floor.name = "floor"
        floor.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.75, alpha: 1)
        floor.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: SCNBox(width: 100, height: 0.02, length: 100, chamferRadius: 0)))
        root.addChildNode(floor)

        // a box with a checkerboard texture, spinning
        let box = SCNNode(geometry: SCNBox(width: 1.2, height: 1.2, length: 1.2, chamferRadius: 0))
        box.name = "box"
        box.position = SCNVector3(0, 0.6, 0)
        let m = box.geometry!.firstMaterial!
        m.diffuse.contents = checkerboard()
        m.specular.contents = UIColor(white: 0.6, alpha: 1)
        m.shininess = 25
        box.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 8)), forKey: "spin")
        root.addChildNode(box)

        // a physically based sphere and the other shapes in a ring
        let sphere = SCNNode(geometry: SCNSphere(radius: 0.55))
        sphere.name = "sphere"
        sphere.position = SCNVector3(-2, 0.55, 0.4)
        let pm = sphere.geometry!.firstMaterial!
        pm.lightingModel = .physicallyBased
        pm.diffuse.contents = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
        pm.metalness.contents = 0.3
        pm.roughness.contents = 0.35
        root.addChildNode(sphere)
        let shapes: [(String, SCNGeometry, UIColor, SCNVector3)] = [
            ("cylinder", SCNCylinder(radius: 0.4, height: 1), .systemGreen, SCNVector3(2, 0.5, 0.4)),
            ("cone", SCNCone(topRadius: 0, bottomRadius: 0.45, height: 1), .systemYellow, SCNVector3(-1.2, 0.5, -1.8)),
            ("pyramid", SCNPyramid(width: 0.9, height: 1, length: 0.9), .systemPurple, SCNVector3(1.2, 0, -1.8)),
            ("capsule", SCNCapsule(capRadius: 0.25, height: 1.1), .systemTeal, SCNVector3(-3.2, 0.55, -1.2)),
            ("tube", SCNTube(innerRadius: 0.2, outerRadius: 0.4, height: 0.8), .systemPink, SCNVector3(3.2, 0.4, -1.2)),
        ]
        for (name, g, color, p) in shapes {
            g.firstMaterial?.diffuse.contents = color
            let n = SCNNode(geometry: g)
            n.name = name
            n.position = p
            root.addChildNode(n)
        }

        // the crystal: a Wavefront OBJ file in the bundle, floating and bobbing
        if let url = Bundle.main.url(forResource: "crystal", withExtension: "obj"), let crystal = try? SCNScene(url: url) {
            let holder = SCNNode()
            holder.name = "crystalHolder"
            for c in crystal.rootNode.childNodes { holder.addChildNode(c) }
            holder.position = SCNVector3(0, 2.2, -0.5)
            holder.scale = SCNVector3(0.6, 0.6, 0.6)
            let mats = holder.childNodes.compactMap { $0.geometry?.materials.compactMap(\.name).joined(separator: ",") }.joined(separator: ";")
            log("obj nodes \(holder.childNodes.count) materials \(mats)")
            let bob = CABasicAnimation(keyPath: "position.y")
            bob.fromValue = 2.0
            bob.toValue = 2.4
            bob.duration = 1.5
            bob.autoreverses = true
            bob.repeatCount = 2
            bob.delegate = self
            holder.addAnimation(bob, forKey: "bob")
            root.addChildNode(holder)
        } else {
            log("obj failed")
        }

        // a ball that falls onto the floor
        let ball = SCNNode(geometry: SCNSphere(radius: 0.3))
        ball.name = "ball"
        ball.position = SCNVector3(1.4, 3, 1.4)
        ball.geometry?.firstMaterial?.diffuse.contents = UIColor.systemBlue
        ball.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        ball.physicsBody?.restitution = 0.4
        ball.physicsBody?.contactTestBitMask = Int(SCNPhysicsCollisionCategory.static.rawValue)
        root.addChildNode(ball)

        // lights: ambient, a directional sun, a warm omni light and a spot light
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light!.type = .ambient; ambient.light!.intensity = 250
        let sun = SCNNode(); sun.light = SCNLight(); sun.light!.type = .directional; sun.light!.intensity = 800
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        let omni = SCNNode(); omni.light = SCNLight(); omni.light!.type = .omni; omni.light!.color = UIColor(red: 1, green: 0.85, blue: 0.7, alpha: 1)
        omni.light!.intensity = 500; omni.light!.attenuationStartDistance = 2; omni.light!.attenuationEndDistance = 12
        omni.position = SCNVector3(-3, 3, 3)
        let spot = SCNNode(); spot.light = SCNLight(); spot.light!.type = .spot; spot.light!.spotInnerAngle = 20; spot.light!.spotOuterAngle = 50
        spot.light!.intensity = 600
        spot.position = SCNVector3(0, 5, 2)
        spot.look(at: SCNVector3(0, 0, 0))
        for l in [ambient, sun, omni, spot] { root.addChildNode(l) }

        // the camera, aimed at the box by a look-at constraint
        let camera = SCNNode()
        camera.name = "camera"
        camera.camera = SCNCamera()
        camera.camera!.fieldOfView = 55
        camera.position = SCNVector3(0, 3.2, 7)
        let aim = SCNLookAtConstraint(target: box)
        aim.isGimbalLockEnabled = true
        camera.constraints = [aim]
        root.addChildNode(camera)
        scnView.pointOfView = camera

        // an action sequence with a completion handler
        sphere.runAction(.sequence([.moveBy(x: 0, y: 0.6, z: 0, duration: 0.4), .moveBy(x: 0, y: -0.6, z: 0, duration: 0.4)])) {
            log("action done")
        }
        return scene
    }

    func checkerboard() -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: f).image { ctx in
            for y in 0..<8 {
                for x in 0..<8 {
                    ((x + y) % 2 == 0 ? UIColor.white : UIColor(red: 0.95, green: 0.45, blue: 0.1, alpha: 1)).setFill()
                    ctx.fill(CGRect(x: x * 8, y: y * 8, width: 8, height: 8))
                }
            }
        }
    }

    // SCNSceneRendererDelegate: after a few frames, check picking, projection and a snapshot
    nonisolated func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        MainActor.assumeIsolated {
            frames += 1
            guard frames == 6, !checked else { return }
            checked = true
            DispatchQueue.main.async { self.check() }
        }
    }

    func check() {
        let v = scnView
        guard let box = v.scene?.rootNode.childNode(withName: "box", recursively: false) else { return }
        let p = v.projectPoint(box.worldPosition)
        log(String(format: "project box %.0f,%.0f in %.0fx%.0f", p.x, p.y, v.bounds.width, v.bounds.height))
        let hits = v.hitTest(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)), options: nil)
        log("hit \(hits.first?.node.name ?? "none")")
        let back = v.unprojectPoint(p)
        log(String(format: "unproject %.2f %.2f %.2f", back.x, back.y, back.z))
        let image = v.snapshot()
        log("snapshot \(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))")
        log("frustum \(v.isNode(box, insideFrustumOf: v.pointOfView!) ? "box in" : "box out")")
        let renderer = SCNRenderer(device: v.device, options: nil)
        renderer.scene = v.scene
        renderer.pointOfView = v.pointOfView
        let offscreen = renderer.snapshot(atTime: 0, with: CGSize(width: 64, height: 48), antialiasingMode: .none)
        log("renderer \(Int(offscreen.size.width))x\(Int(offscreen.size.height))")
    }

    // SCNPhysicsContactDelegate
    nonisolated func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let names = [contact.nodeA.name ?? "?", contact.nodeB.name ?? "?"].sorted().joined(separator: " ")
        log("contact \(names)")
    }

    // CAAnimationDelegate: the crystal's bob
    nonisolated func animationDidStop(_ anim: CAAnimation, finished flag: Bool) { log("animation stop \(flag)") }
}
