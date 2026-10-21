// Sample: ARKit on isim, which (like Apple's Simulator) has no camera tracking. The app checks every configuration's
// isSupported, runs an ARWorldTrackingConfiguration in an ARSCNView anyway and handles the session's
// unsupportedConfiguration error, shows ARCoachingOverlayView, and exercises the value types (anchors, raycast
// queries, reference images, world map archiving) and SceneKit's scene graph and render loop under the AR view.
import UIKit
import ARKit
import SceneKit
import SpriteKit

/// Subclasses whose methods share a selector with a superclass property, as an iOS app may write: isim's overlay classes
/// mark their members @objc one by one rather than with @objcMembers, which subclasses would inherit (issue #636).
final class LabelNode: SCNNode, @unchecked Sendable {
    func childNodes() -> String { "label" }
}
final class TaggedAnchor: ARAnchor, @unchecked Sendable {
    func transform() -> String { "tagged" }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ARViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func f2(_ v: Float) -> String { let r = (v * 100).rounded() / 100; return String(format: "%.2f", r == 0 ? 0 : r) }   // no "-0.00"

final class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, ARSKViewDelegate, ARCoachingOverlayViewDelegate {
    let sceneView = ARSCNView(frame: .zero)
    let coaching = ARCoachingOverlayView(frame: .zero)
    let status = UILabel()
    let spriteView = ARSKView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    var frames = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        sceneView.frame = view.bounds
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.delegate = self
        sceneView.accessibilityIdentifier = "ar-view"
        view.addSubview(sceneView)
        coaching.frame = view.bounds
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.session = sceneView.session
        coaching.goal = .horizontalPlane
        coaching.delegate = self
        coaching.accessibilityIdentifier = "coaching"
        view.addSubview(coaching)
        status.frame = CGRect(x: 16, y: 80, width: view.bounds.width - 32, height: 60)
        status.textColor = .systemYellow; status.font = .systemFont(ofSize: 15, weight: .medium)
        status.numberOfLines = 2; status.textAlignment = .center
        status.accessibilityIdentifier = "status"
        view.addSubview(status)

        supportChecks()
        sceneGraph()
        valueTypes()
        // a scene under the AR view; the render loop calls the delegate even though nothing is drawn yet
        let box = SCNNode(); box.name = "box"; box.position = SCNVector3(0, 0, -0.5)
        sceneView.scene.rootNode.addChildNode(box)
        sceneView.rendersContinuously = true
        // run world tracking anyway: the session fails, as in the Simulator
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        sceneView.session.delegate = self
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        print("session running: configuration \(sceneView.session.configuration is ARWorldTrackingConfiguration) frame \(sceneView.session.currentFrame == nil ? "nil" : "some")")
        // SpriteKit's AR view shares the protocols
        spriteView.delegate = self
        spriteView.session.run(AROrientationTrackingConfiguration())
    }

    func supportChecks() {
        let kinds: [(String, ARConfiguration.Type)] = [("world", ARWorldTrackingConfiguration.self), ("orientation", AROrientationTrackingConfiguration.self),
                                                        ("face", ARFaceTrackingConfiguration.self), ("image", ARImageTrackingConfiguration.self),
                                                        ("body", ARBodyTrackingConfiguration.self), ("positional", ARPositionalTrackingConfiguration.self),
                                                        ("geo", ARGeoTrackingConfiguration.self), ("object scanning", ARObjectScanningConfiguration.self)]
        print("supported: " + kinds.map { "\($0.0)=\($0.1.isSupported)" }.joined(separator: " "))
        print("video formats \(ARWorldTrackingConfiguration.supportedVideoFormats.count) scene depth \(ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)) mesh \(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)) faces \(ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces)")
        ARGeoTrackingConfiguration.checkAvailability { ok, e in
            print("geo availability \(ok) error \((e as NSError?)?.code ?? 0)")
        }
    }

    func sceneGraph() {
        let root = SCNNode(), arm = SCNNode(), hand = SCNNode()
        arm.name = "arm"; hand.name = "hand"
        root.addChildNode(arm); arm.addChildNode(hand)
        arm.position = SCNVector3(1, 0, 0)
        arm.eulerAngles = SCNVector3(0, Float.pi / 2, 0)              // turn 90° around y
        hand.position = SCNVector3(0, 0, -1)
        let w = hand.worldPosition
        print("scene graph: hand world \(f2(w.x)) \(f2(w.y)) \(f2(w.z)) found \(root.childNode(withName: "hand", recursively: true) === hand) euler y \(f2(arm.eulerAngles.y))")
        let m = SCNMatrix4Mult(SCNMatrix4MakeScale(2, 2, 2), SCNMatrix4MakeTranslation(1, 2, 3))
        let back = SCNMatrix4Mult(m, SCNMatrix4Invert(m))
        print("matrices: translation \(f2(m.m41)) \(f2(m.m42)) \(f2(m.m43)) scale \(f2(m.m11)) inverse identity \(SCNMatrix4IsIdentity(back) || abs(back.m11 - 1) < 1e-5)")
        let copy = arm.clone()
        print("clone: \(copy.name ?? "-") children \(copy.childNodes.count) separate \(copy.childNodes.first !== hand)")
        hand.removeFromParentNode()
        print("removed: arm children \(arm.childNodes.count) hand parent \(hand.parent == nil ? "nil" : "some")")
        let label = LabelNode(), tagged = TaggedAnchor(name: "tag", transform: matrix_identity_float4x4)
        label.addChildNode(SCNNode())
        print("subclasses: \(label.childNodes()) \(label.childNodes.count) \(tagged.transform()) \(tagged.name ?? "-")")
    }

    func valueTypes() {
        var t = matrix_identity_float4x4; t.columns.3 = SIMD4(0, 0, -1, 1)
        let a = ARAnchor(name: "marker", transform: t)
        sceneView.session.add(anchor: a)
        let data = try? NSKeyedArchiver.archivedData(withRootObject: a, requiringSecureCoding: true)
        let back = data.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: $0) }
        print("anchor: \(a.name ?? "-") z \(f2(a.transform.columns.3.z)) archived \(back?.identifier == a.identifier && back?.name == "marker") copy \((a.copy() as? ARAnchor)?.identifier == a.identifier)")
        let q = ARRaycastQuery(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, -1), allowing: .estimatedPlane, alignment: .any)
        print("raycast: results \(sceneView.session.raycast(q).count) tracked \(sceneView.session.trackedRaycast(q) { _ in } == nil ? "nil" : "some") query from view \(sceneView.raycastQuery(from: .zero, allowing: .estimatedPlane, alignment: .horizontal) == nil ? "nil" : "some")")
        let img = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 200, height: 100)) }
        let ref = ARReferenceImage(img.cgImage!, orientation: .up, physicalWidth: 0.2)
        ref.name = "poster"
        ref.validate { e in print("reference image: \(ref.name ?? "-") physical \(String(format: "%.2f", ref.physicalSize.width))x\(String(format: "%.2f", ref.physicalSize.height)) valid \(e == nil) group \(ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) == nil ? "nil" : "some")") }
        sceneView.session.getCurrentWorldMap { map, e in print("world map: \(map == nil ? "nil" : "some") error \((e as NSError?)?.code ?? 0)") }
    }

    // MARK: session events (the session's delegate and the AR views' delegates both get them)

    func session(_ session: ARSession, didFailWithError error: Error) {
        let e = error as NSError
        let who = session === sceneView.session ? "scene view session" : "sprite view session"
        print("\(who) failed: \(e.domain) \(e.code) \(e.localizedDescription) unsupported \((error as? ARError)?.code == .unsupportedConfiguration)")
        if session === sceneView.session {
            status.text = "AR is not available on this device"
            coaching.setActive(true, animated: false)
        }
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) { print("frame?!") }

    // MARK: SceneKit render loop

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        frames += 1
        if frames == 10 { print("render loop: 10 updates, scene nodes \(renderer.scene?.rootNode.childNodes.count ?? -1)") }
    }

    // MARK: coaching

    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        print("coaching will activate goal \(coachingOverlayView.goal.rawValue)")
    }
}
