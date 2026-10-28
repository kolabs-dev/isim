// HelloAR, -world: world tracking on isim's simulated device (ISIM_AR_SCENE=room, issue #391). An ARSCNView runs an
// ARWorldTrackingConfiguration with horizontal and vertical plane detection and shows each found plane as a tinted
// rectangle. A tap raycasts into the scene and places a box on what it hits; a tracked raycast follows the view's
// centre. Once the room is mapped the app saves an ARWorldMap, archives it, and runs a new session from it, which
// relocalizes and brings the anchors back. The `ar` script command moves the device (pose, move, turn). Each step logs
// a "HelloARWorld:" line.
import UIKit
import ARKit
import SceneKit
import CoreVideo

private func log(_ s: String) { NSLog("HelloARWorld: %@", s) }

private func describe(_ c: ARPlaneAnchor.Classification) -> String {
    switch c {
    case .wall: return "wall"
    case .floor: return "floor"
    case .ceiling: return "ceiling"
    case .table: return "table"
    case .seat: return "seat"
    case .window: return "window"
    case .door: return "door"
    case .none: return "none"
    @unknown default: return "unknown"
    }
}
private func describe(_ t: ARCamera.TrackingState) -> String {
    switch t {
    case .normal: return "normal"
    case .notAvailable: return "notAvailable"
    case .limited(let r): return "limited(\(r))"
    @unknown default: return "unknown"
    }
}
private func describe(_ m: ARFrame.WorldMappingStatus) -> String {
    switch m {
    case .notAvailable: return "notAvailable"
    case .limited: return "limited"
    case .extending: return "extending"
    case .mapped: return "mapped"
    @unknown default: return "unknown"
    }
}

final class WorldViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    let sceneView = ARSCNView(frame: .zero)
    let status = UILabel()
    var loggedFrame = false
    var lastMapping = ""
    var tracked: ARTrackedRaycast?
    var trackedHits = 0
    var savedMap = false
    var relocalizing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        sceneView.frame = view.bounds
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.accessibilityIdentifier = "ar-world"
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
        view.addSubview(sceneView)
        status.frame = CGRect(x: 16, y: 60, width: view.bounds.width - 32, height: 44)
        status.textColor = .white; status.font = .boldSystemFont(ofSize: 17); status.textAlignment = .center
        status.backgroundColor = UIColor(white: 0, alpha: 0.4); status.layer.cornerRadius = 10; status.clipsToBounds = true
        view.addSubview(status)

        let formats = ARWorldTrackingConfiguration.supportedVideoFormats.map { "\(Int($0.imageResolution.width))x\(Int($0.imageResolution.height))@\($0.framesPerSecond)" }
        log("supported world \(ARWorldTrackingConfiguration.isSupported) positional \(ARPositionalTrackingConfiguration.isSupported) "
            + "face \(ARFaceTrackingConfiguration.isSupported) formats \(formats.joined(separator: ",")) classification \(ARPlaneAnchor.isClassificationSupported)")
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(config)
        status.text = "Looking for surfaces"
    }

    // MARK: session

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        log("tracking \(describe(camera.trackingState))")
        if relocalizing && camera.trackingState == .normal { relocalizing = false }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard frame.camera.trackingState == .normal else { return }
        if !loggedFrame {
            loggedFrame = true
            let img = frame.capturedImage
            let biplanar = CVPixelBufferGetPixelFormatType(img) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            let p = frame.camera.transform.columns.3
            log("frame image \(CVPixelBufferGetWidth(img))x\(CVPixelBufferGetHeight(img)) 420f \(biplanar) points \(frame.rawFeaturePoints?.count ?? 0) "
                + "light \(Int(frame.lightEstimate?.ambientIntensity ?? 0)) camera \(f2(p.x)) \(f2(p.y)) \(f2(p.z)) width-axis-up \(frame.camera.transform.columns.0.y > 0.9)")
        }
        let m = describe(frame.worldMappingStatus)
        if m != lastMapping {
            lastMapping = m
            log("mapping \(m)")
            if frame.worldMappingStatus == .mapped && !savedMap { saveAndRestore() }
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for a in anchors {
            if let p = a as? ARPlaneAnchor {
                let c = a.transform.columns.3
                log("plane added \(describe(p.classification)) \(p.alignment == .horizontal ? "horizontal" : "vertical") at \(f2(c.x)) \(f2(c.y)) \(f2(c.z)) "
                    + "extent \(f2(p.planeExtent.width))x\(f2(p.planeExtent.height)) vertices \(p.geometry.vertexCount)")
                if p.classification == .table {
                    let pt = sceneView.session.currentFrame?.camera.projectPoint(SIMD3(c.x, c.y, c.z), orientation: .portrait, viewportSize: sceneView.bounds.size)
                    log("table on screen at \(Int(pt?.x ?? -1)) \(Int(pt?.y ?? -1))")
                }
            } else {
                log("anchor added \(a.name ?? "-")\(savedMap ? " (from the world map)" : "")")
            }
        }
        DispatchQueue.main.async {
            let planes = session.currentFrame?.anchors.filter { $0 is ARPlaneAnchor }.count ?? 0
            self.status.text = "\(planes) surface\(planes == 1 ? "" : "s") found"
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for case let p as ARPlaneAnchor in anchors where p.classification == .floor {
            log("floor grew to \(f2(p.planeExtent.width))x\(f2(p.planeExtent.height))")
        }
    }

    // MARK: SceneKit nodes for anchors

    func renderer(_ renderer: any SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        if let p = anchor as? ARPlaneAnchor {
            let plane = SCNPlane(width: CGFloat(p.planeExtent.width), height: CGFloat(p.planeExtent.height))
            let colors: [String: UIColor] = ["floor": .systemBlue, "table": .systemGreen, "wall": .systemYellow]
            plane.firstMaterial?.diffuse.contents = (colors[describe(p.classification)] ?? .systemPink).withAlphaComponent(0.35)
            plane.firstMaterial?.isDoubleSided = true
            let child = SCNNode(geometry: plane)
            child.eulerAngles.x = -.pi / 2            // SCNPlane stands in x-y; the anchor's plane is x-z
            child.name = "plane"
            node.addChildNode(child)
        } else if anchor.name == "box" {
            let box = SCNBox(width: 0.15, height: 0.15, length: 0.15, chamferRadius: 0.01)
            box.firstMaterial?.diffuse.contents = UIColor.systemOrange
            let child = SCNNode(geometry: box)
            child.position.y = 0.075
            node.addChildNode(child)
        }
        return node
    }

    func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor.name == "box" else { return }
        let p = node.worldPosition
        log("box node at \(f2(Float(p.x))) \(f2(Float(p.y))) \(f2(Float(p.z))) in the scene \(node.parent != nil) children \(node.childNodes.count)")
    }

    func renderer(_ renderer: any SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let p = anchor as? ARPlaneAnchor, let plane = node.childNode(withName: "plane", recursively: false)?.geometry as? SCNPlane else { return }
        plane.width = CGFloat(p.planeExtent.width); plane.height = CGFloat(p.planeExtent.height)
    }

    func session(_ session: ARSession, didFailWithError error: Error) { log("failed \((error as NSError).code)") }

    // MARK: raycasts

    @objc func tap(_ g: UITapGestureRecognizer) {
        let point = g.location(in: sceneView)
        guard let q = sceneView.raycastQuery(from: point, allowing: .existingPlaneGeometry, alignment: .any) else { log("tap no query"); return }
        let results = sceneView.session.raycast(q)
        guard let hit = results.first else { log("tap hit nothing"); return }
        let c = hit.worldTransform.columns.3
        let kind = (hit.anchor as? ARPlaneAnchor).map { describe($0.classification) } ?? "-"
        log("tap hit \(kind) at \(f2(c.x)) \(f2(c.y)) \(f2(c.z)) results \(results.count)")
        sceneView.session.add(anchor: ARAnchor(name: "box", transform: hit.worldTransform))
        // the estimated plane under the view's centre, followed while the device moves
        let centre = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        if tracked == nil, let cq = sceneView.raycastQuery(from: centre, allowing: .estimatedPlane, alignment: .any) {
            tracked = sceneView.session.trackedRaycast(cq) { [weak self] results in
                guard let self, let r = results.first else { return }
                self.trackedHits += 1
                if self.trackedHits <= 2 {
                    let p = r.worldTransform.columns.3
                    log("tracked raycast \(self.trackedHits) at \(f2(p.x)) \(f2(p.y)) \(f2(p.z)) estimated \(r.target == .estimatedPlane)")
                }
            }
        }
    }

    // MARK: world maps

    func saveAndRestore() {
        savedMap = true
        tracked?.stopTracking()
        sceneView.session.getCurrentWorldMap { map, error in
            guard let map else { log("world map error \((error as NSError?)?.code ?? 0)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true),
                  let restored = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else { log("world map archive failed"); return }
            let planes = restored.anchors.compactMap { $0 as? ARPlaneAnchor }
            log("world map anchors \(restored.anchors.count) planes \(planes.count) box \(restored.anchors.contains { $0.name == "box" }) "
                + "extent \(f2(restored.extent.x))x\(f2(restored.extent.y))x\(f2(restored.extent.z)) points \(restored.rawFeaturePoints.count) "
                + "classes \(Set(planes.map { describe($0.classification) }).sorted().joined(separator: ","))")
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal, .vertical]
            config.initialWorldMap = restored
            self.relocalizing = true
            self.sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            self.status.text = "Relocalizing"
        }
    }
}
