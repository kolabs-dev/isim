// isim ARKit: the simulated device (issue #391). Adapted, opt-in: with ISIM_AR_SCENE set, isim behaves like a device
// with world tracking in a synthetic scene instead of like Apple's Simulator:
// - the scene: `room` (a floor, three walls and a table) or a JSON file of planes;
// - the device's pose moves with the `ar` script command (pose, move, turn) and starts at the scene's camera;
// - a session runs at its video format's rate: frames with the camera's pose (ARKit's landscape-right camera axes),
//   tracking states (initializing, then normal; relocalizing with a world map), the scene drawn from the camera as the
//   captured image (its planes projected and filled, YCbCr 4:2:0 like a device's camera), feature points on the planes
//   in view, a light estimate;
// - planes become ARPlaneAnchors when they come into view (half their size first, then all of it), filtered by the
//   configuration's planeDetection; raycasts hit them (or any scene plane, for estimated planes); world maps save the
//   anchors and restore them.
import UIKit
import SceneKit
import CoreVideo
import simd

// MARK: - the scene

struct _ARScenePlane {
    var name: String
    var alignment: ARPlaneAnchor.Alignment
    var classification: ARPlaneAnchor.Classification
    /// the plane's frame: y is its normal, the extent lies along x (width) and z (length)
    var transform: simd_float4x4
    var width: Float, length: Float
    var color: (CGFloat, CGFloat, CGFloat)
    var grid: Bool
    var center: SIMD3<Float> { SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z) }
    var normal: SIMD3<Float> { SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z) }
    var axisX: SIMD3<Float> { SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z) }
    var axisZ: SIMD3<Float> { SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z) }
    func corner(_ sx: Float, _ sz: Float) -> SIMD3<Float> { center + axisX * (sx * width / 2) + axisZ * (sz * length / 2) }
    var corners: [SIMD3<Float>] { [corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1)] }

    /// a plane from its center and normal; `rotation` turns its extent around the normal (degrees)
    static func make(_ name: String, _ alignment: ARPlaneAnchor.Alignment, _ classification: ARPlaneAnchor.Classification,
                     center: SIMD3<Float>, normal: SIMD3<Float>, width: Float, length: Float, rotation: Float = 0,
                     color: (CGFloat, CGFloat, CGFloat), grid: Bool = false) -> _ARScenePlane {
        let y = simd_normalize(normal)
        // x: horizontal for walls, world x for floors and tables (before the rotation)
        var x = abs(y.y) > 0.9 ? SIMD3<Float>(1, 0, 0) : simd_normalize(simd_cross(SIMD3(0, 1, 0), y))
        if rotation != 0 { x = simd_act(simd_quatf(angle: rotation * .pi / 180, axis: y), x) }
        let z = simd_normalize(simd_cross(x, y))
        let t = simd_float4x4(SIMD4(x, 0), SIMD4(y, 0), SIMD4(z, 0), SIMD4(center, 1))
        return _ARScenePlane(name: name, alignment: alignment, classification: classification, transform: t, width: width, length: length,
                             color: color, grid: grid)
    }
}

struct _ARScene {
    var planes: [_ARScenePlane] = []
    var start = SIMD3<Float>(0, 0, 0), startYaw: Float = 0, startPitch: Float = 0
    var background: (CGFloat, CGFloat, CGFloat) = (0.16, 0.16, 0.18)

    /// a room seen from where the device starts (the world origin, 1.4 m above the floor, looking along -z): a floor,
    /// a table 1.5 m ahead, a ceiling, and walls behind the table and on both sides
    static var room: _ARScene {
        var s = _ARScene()
        s.planes = [
            .make("floor", .horizontal, .floor, center: SIMD3(0, -1.4, -1), normal: SIMD3(0, 1, 0), width: 4, length: 5,
                  color: (0.55, 0.45, 0.35), grid: true),
            .make("table", .horizontal, .table, center: SIMD3(0, -0.65, -1.5), normal: SIMD3(0, 1, 0), width: 1.2, length: 0.8,
                  color: (0.45, 0.30, 0.18), grid: true),
            .make("ceiling", .horizontal, .ceiling, center: SIMD3(0, 1.2, -1), normal: SIMD3(0, -1, 0), width: 4, length: 5,
                  color: (0.90, 0.90, 0.88)),
            .make("back wall", .vertical, .wall, center: SIMD3(0, -0.1, -3.5), normal: SIMD3(0, 0, 1), width: 4, length: 2.6,
                  color: (0.80, 0.80, 0.76)),
            .make("left wall", .vertical, .wall, center: SIMD3(-2, -0.1, -1), normal: SIMD3(1, 0, 0), width: 5, length: 2.6,
                  color: (0.72, 0.74, 0.78)),
            .make("right wall", .vertical, .wall, center: SIMD3(2, -0.1, -1), normal: SIMD3(-1, 0, 0), width: 5, length: 2.6,
                  color: (0.74, 0.72, 0.70)),
        ]
        return s
    }

    /// ISIM_AR_SCENE: `room`, or a JSON file:
    /// {"planes": [{"name", "alignment": "horizontal"|"vertical", "classification", "center": [x, y, z],
    ///              "normal": [x, y, z], "width", "length", "rotation", "color": "#rrggbb"}],
    ///  "camera": {"position": [x, y, z], "yaw", "pitch"}}
    static func load(_ spec: String) -> _ARScene? {
        if spec == "room" || spec == "1" { return room }
        guard let d = FileManager.default.contents(atPath: spec), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            NSLog("isim ARKit: ISIM_AR_SCENE %@ is neither `room` nor a readable JSON scene", spec)
            return nil
        }
        func v3(_ a: Any?, _ def: SIMD3<Float>) -> SIMD3<Float> {
            guard let a = a as? [NSNumber], a.count == 3 else { return def }
            return SIMD3(a[0].floatValue, a[1].floatValue, a[2].floatValue)
        }
        func color(_ s: Any?) -> (CGFloat, CGFloat, CGFloat) {
            guard let s = s as? String, s.hasPrefix("#"), s.count == 7, let v = Int(s.dropFirst(), radix: 16) else { return (0.7, 0.7, 0.7) }
            return (CGFloat(v >> 16 & 0xFF) / 255, CGFloat(v >> 8 & 0xFF) / 255, CGFloat(v & 0xFF) / 255)
        }
        var s = _ARScene()
        for (i, p) in (j["planes"] as? [[String: Any]] ?? []).enumerated() {
            let vertical = (p["alignment"] as? String) == "vertical"
            let classes: [String: ARPlaneAnchor.Classification] = ["wall": .wall, "floor": .floor, "ceiling": .ceiling, "table": .table,
                                                                   "seat": .seat, "window": .window, "door": .door]
            let cls = classes[(p["classification"] as? String ?? "").lowercased()] ?? .none(.unknown)
            s.planes.append(.make(p["name"] as? String ?? "plane \(i + 1)", vertical ? .vertical : .horizontal, cls,
                                  center: v3(p["center"], SIMD3(0, -1.4, -1)), normal: v3(p["normal"], vertical ? SIMD3(0, 0, 1) : SIMD3(0, 1, 0)),
                                  width: (p["width"] as? NSNumber)?.floatValue ?? 1, length: (p["length"] as? NSNumber)?.floatValue ?? 1,
                                  rotation: (p["rotation"] as? NSNumber)?.floatValue ?? 0, color: color(p["color"]), grid: !vertical))
        }
        if let c = j["camera"] as? [String: Any] {
            s.start = v3(c["position"], SIMD3(0, 0, 0))
            s.startYaw = ((c["yaw"] as? NSNumber)?.floatValue ?? 0) * .pi / 180
            s.startPitch = ((c["pitch"] as? NSNumber)?.floatValue ?? 0) * .pi / 180
        }
        return s
    }
}

// MARK: - the device

/// The simulated device: its scene and pose, moved by the `ar` script command.
final class _ARDevice: @unchecked Sendable {
    static let shared = _ARDevice()
    let scene: _ARScene?
    let lock = NSLock()
    var position = SIMD3<Float>(0, 0, 0)
    var yaw: Float = 0, pitch: Float = 0                       // radians: yaw around world y (left is positive), pitch up
    /// `ar tracking`: a state the sessions report instead of their own
    var forcedTracking: ARCamera.TrackingState?
    var sessions = NSHashTable<ARSession>.weakObjects()

    var simulated: Bool { scene != nil }

    private init() {
        let spec = ProcessInfo.processInfo.environment["ISIM_AR_SCENE"] ?? ""
        scene = spec.isEmpty || spec == "0" ? nil : _ARScene.load(spec)
        if let s = scene {
            position = s.start; yaw = s.startYaw; pitch = s.startPitch
            NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: .main) { n in
                guard let t = n.object as? String, t == "ar" || t.hasPrefix("ar ") else { return }
                _ARDevice.shared.command(t)
            }
            NSLog("isim ARKit: simulated device in the scene %@ (%d planes)", ProcessInfo.processInfo.environment["ISIM_AR_SCENE"] ?? "", s.planes.count)
        }
    }

    /// the device's pose in portrait (x right, y up, looking along -z)
    var devicePose: simd_float4x4 {
        lock.lock(); defer { lock.unlock() }
        let q = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
        var m = simd_float4x4(q)
        m.columns.3 = SIMD4(position, 1)
        return m
    }
    /// ARKit's camera axes: x along the image's width (the device's top in portrait), y its height, -z ahead
    static let portraitToCamera = simd_float4x4(simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1)))
    static let cameraToPortrait = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: SIMD3(0, 0, 1)))

    func command(_ text: String) {
        let parts = text.split(separator: " ").map(String.init)
        let args = Array(parts.dropFirst())
        let nums = args.dropFirst().compactMap(Float.init)
        func deg(_ r: Float) -> String { String(format: "%.0f", r * 180 / .pi) }
        lock.lock()
        var reply = ""
        switch args.first ?? "status" {
        case "pose":
            if nums.count >= 3 { position = SIMD3(nums[0], nums[1], nums[2]) }
            if nums.count >= 4 { yaw = nums[3] * .pi / 180 }
            if nums.count >= 5 { pitch = nums[4] * .pi / 180 }
        case "move":
            // metres along the device's heading: x right, y up, z back
            if nums.count >= 3 {
                let q = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
                position += simd_act(q, SIMD3(nums[0], nums[1], nums[2]))
            }
        case "turn":
            if let y = nums.first { yaw += y * .pi / 180 }
            if nums.count >= 2 { pitch = max(-.pi / 2, min(.pi / 2, pitch + nums[1] * .pi / 180)) }
        case "tracking":
            switch args.count > 1 ? args[1] : "auto" {
            case "normal": forcedTracking = .normal
            case "limited": forcedTracking = .limited(.excessiveMotion)
            case "features": forcedTracking = .limited(.insufficientFeatures)
            case "notavailable", "lost": forcedTracking = .notAvailable
            default: forcedTracking = nil
            }
        case "interrupt", "resume":
            let begin = args.first == "interrupt"
            let all = sessions.allObjects
            lock.unlock()
            for s in all { s._sim?.interrupt(begin) }
            lock.lock()
            reply = begin ? "interrupted" : "resumed"
        case "status": break
        default:
            reply = "unknown ar command \(args.first ?? "")"
        }
        let p = position
        let status = String(format: "camera at %.2f %.2f %.2f yaw %@ pitch %@", p.x, p.y, p.z, deg(yaw), deg(pitch))
        lock.unlock()
        let planes = sessions.allObjects.map { $0._anchors.filter { $0 is ARPlaneAnchor }.count }.max() ?? 0
        NSLog("isim ARKit: %@%@ (planes %d)", reply.isEmpty ? "" : reply + "; ", status, planes)
    }
}

// MARK: - a running session

final class _ARSimulation: @unchecked Sendable {
    unowned let session: ARSession
    let configuration: ARConfiguration
    let scene: _ARScene
    var timer: DispatchSourceTimer?
    var start = Date()
    var lastTracking: ARCamera.TrackingState?
    /// scene plane index -> its anchor, and the time it was found
    var found: [Int: (anchor: ARPlaneAnchor, at: TimeInterval, grown: Bool)] = [:]
    var relocalizeUntil: TimeInterval = 0
    var mapAnchors: [ARAnchor] = []
    var interrupted = false
    var tracked: [ARTrackedRaycast] = []
    let width = 640, height = 480
    let focal: Float = 500

    init(session: ARSession, configuration: ARConfiguration, scene: _ARScene) {
        self.session = session; self.configuration = configuration; self.scene = scene
    }

    var planeDetection: ARWorldTrackingConfiguration.PlaneDetection {
        (configuration as? ARWorldTrackingConfiguration)?.planeDetection ?? (configuration as? ARPositionalTrackingConfiguration)?.planeDetection ?? []
    }
    var orientationOnly: Bool { configuration is AROrientationTrackingConfiguration }

    func begin(map: ARWorldMap?) {
        start = Date()
        if let map {
            relocalizeUntil = 0.8
            mapAnchors = map.anchors
        }
        let fps = max(1, min(60, configuration.videoFormat.framesPerSecond))
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 1.0 / Double(fps))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }
    func stop() { timer?.cancel(); timer = nil }
    func interrupt(_ begin: Bool) {
        guard begin != interrupted else { return }
        interrupted = begin
        if begin { session._tell { $0.sessionWasInterrupted(self.session) } } else { session._tell { $0.sessionInterruptionEnded(self.session) } }
    }

    var elapsed: TimeInterval { Date().timeIntervalSince(start) }

    func tracking(_ t: TimeInterval) -> ARCamera.TrackingState {
        _ARDevice.shared.lock.lock()
        let forced = _ARDevice.shared.forcedTracking
        _ARDevice.shared.lock.unlock()
        if let forced { return forced }
        if t < 0.3 { return .limited(.initializing) }
        if t < relocalizeUntil { return .limited(.relocalizing) }
        return .normal
    }

    /// the camera's transform: the device's pose (its rotation only for orientation tracking) in ARKit's camera axes
    var cameraTransform: simd_float4x4 {
        var pose = _ARDevice.shared.devicePose
        if orientationOnly { pose.columns.3 = SIMD4(0, 0, 0, 1) }
        return pose * _ARDevice.portraitToCamera
    }

    func tick() {
        guard !interrupted else { return }
        let t = elapsed
        let state = tracking(t)
        let camT = cameraTransform
        let camera = ARCamera(transform: camT, imageResolution: CGSize(width: width, height: height), focalLength: focal, trackingState: state)
        if state != lastTracking {
            lastTracking = state
            session._tell { $0.session(self.session, cameraDidChangeTrackingState: camera) }
        }
        var added: [ARAnchor] = [], updated: [ARAnchor] = []
        if state == .normal {
            // a world map's anchors come back once relocalized
            if !mapAnchors.isEmpty {
                for a in mapAnchors {
                    a.sessionIdentifier = session.identifier
                    session._anchors.append(a)
                    added.append(a)
                    if let p = a as? ARPlaneAnchor, let i = scene.planes.firstIndex(where: { simd_distance($0.center, p._worldCenter) < 0.2 }) {
                        found[i] = (p, t, p.planeExtent.width >= scene.planes[i].width - 0.01)
                    }
                }
                mapAnchors = []
            }
            if !orientationOnly && !planeDetection.isEmpty {
                for (i, plane) in scene.planes.enumerated() {
                    if var f = found[i] {
                        if !f.grown && t - f.at > 0.5 {
                            f.anchor._setExtent(plane.width, plane.length)
                            f.grown = true
                            found[i] = f
                            updated.append(f.anchor)
                        }
                        continue
                    }
                    let wanted = plane.alignment == .horizontal ? planeDetection.contains(.horizontal) : planeDetection.contains(.vertical)
                    guard wanted, inView(plane, camera) else { continue }
                    let a = ARPlaneAnchor(_plane: plane)
                    a.sessionIdentifier = session.identifier
                    found[i] = (a, t, false)
                    session._anchors.append(a)
                    added.append(a)
                }
            }
        }
        let image = state == .notAvailable ? render(camera, blank: true) : render(camera, blank: false)
        let frame = ARFrame(timestamp: ProcessInfo.processInfo.systemUptime, image: image.buffer, camera: camera, anchors: session._anchors)
        frame._light = configuration.isLightEstimationEnabled ? ARLightEstimate() : nil
        frame._points = featurePoints(camera)
        frame._mapping = mappingStatus(state)
        frame._preview = image.portrait
        session._frame = frame
        let s = session
        if !added.isEmpty { s._tellDelegate { $0.session(s, didAdd: added) }; s._tellViews { $0._session(s, didAdd: added) } }
        if !updated.isEmpty { s._tellDelegate { $0.session(s, didUpdate: updated) }; s._tellViews { $0._session(s, didUpdate: updated) } }
        s._tellDelegate { $0.session(s, didUpdate: frame) }
        s._tellViews { $0._session(s, didUpdate: frame) }
        for r in tracked where r._active {
            let results = raycast(r._query)
            if let first = results.first, r._last.map({ simd_distance($0, first._position) > 0.001 }) ?? true {
                r._last = first._position
                s._on { r._handler(results) }
            }
        }
    }

    func mappingStatus(_ state: ARCamera.TrackingState) -> ARFrame.WorldMappingStatus {
        guard state == .normal, !orientationOnly else { return state == .notAvailable ? .notAvailable : .limited }
        if found.count >= scene.planes.count, !scene.planes.isEmpty { return .mapped }
        return found.isEmpty ? .limited : .extending
    }

    /// the plane's center in front of the camera, in the image and within 8 m
    func inView(_ p: _ARScenePlane, _ camera: ARCamera) -> Bool {
        let c = _ARMath.inverse(camera.transform) * SIMD4(p.center, 1)
        guard c.z < -0.1, -c.z < 8 else { return false }
        let u = Float(width) / 2 + focal * c.x / -c.z, v = Float(height) / 2 - focal * c.y / -c.z
        return u >= 0 && u < Float(width) && v >= 0 && v < Float(height)
    }

    /// feature points: a grid on the found planes, the ones in front of the camera
    func featurePoints(_ camera: ARCamera) -> ARPointCloud? {
        guard lastTracking == .normal else { return nil }
        let view = _ARMath.inverse(camera.transform)
        var points: [simd_float3] = [], ids: [UInt64] = []
        for (i, f) in found.sorted(by: { $0.key < $1.key }) {
            let p = scene.planes[i]
            let w = f.grown ? p.width : p.width / 2, l = f.grown ? p.length : p.length / 2
            for a in 0..<5 {
                for b in 0..<5 {
                    let q = p.center + p.axisX * ((Float(a) / 4 - 0.5) * w) + p.axisZ * ((Float(b) / 4 - 0.5) * l)
                    let c = view * SIMD4(q, 1)
                    if c.z < -0.1 { points.append(q); ids.append(UInt64(i * 100 + a * 5 + b + 1)) }
                }
            }
        }
        return ARPointCloud(points: points, identifiers: ids)
    }

    // MARK: raycasts

    func raycast(_ q: ARRaycastQuery) -> [ARRaycastResult] {
        var hits: [(Float, ARRaycastResult)] = []
        let d = simd_normalize(q.direction)
        for (i, plane) in scene.planes.enumerated() {
            let wantsAlignment = q.targetAlignment == .any || (q.targetAlignment == .horizontal) == (plane.alignment == .horizontal)
            guard wantsAlignment else { continue }
            let f = found[i]
            switch q.target {
            case .existingPlaneGeometry, .existingPlaneInfinite: if f == nil { continue }
            case .estimatedPlane: break
            }
            let den = simd_dot(plane.normal, d)
            guard abs(den) > 1e-5 else { continue }
            let t = simd_dot(plane.center - q.origin, plane.normal) / den
            guard t > 0 else { continue }
            let hit = q.origin + d * t
            if q.target != .existingPlaneInfinite {
                let local = hit - plane.center
                let w = (f?.grown ?? true) ? plane.width : plane.width / 2, l = (f?.grown ?? true) ? plane.length : plane.length / 2
                if abs(simd_dot(local, plane.axisX)) > w / 2 || abs(simd_dot(local, plane.axisZ)) > l / 2 { continue }
            }
            var m = plane.transform
            m.columns.3 = SIMD4(hit, 1)
            let anchor: ARAnchor? = q.target == .estimatedPlane ? nil : f?.anchor
            hits.append((t, ARRaycastResult(worldTransform: m, target: q.target, alignment: plane.alignment == .horizontal ? .horizontal : .vertical,
                                            anchor: anchor)))
        }
        return hits.sorted { $0.0 < $1.0 }.map(\.1)
    }

    // MARK: world maps

    func worldMap() -> ARWorldMap? {
        guard lastTracking == .normal, !found.isEmpty, !orientationOnly else { return nil }
        let m = ARWorldMap()
        m.anchors = session._anchors.map { $0.copy() as! ARAnchor }
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        for i in found.keys { for c in scene.planes[i].corners { lo = simd_min(lo, c); hi = simd_max(hi, c) } }
        m.center = (lo + hi) / 2; m.extent = hi - lo
        m.rawFeaturePoints = featurePointsAll()
        return m
    }
    func featurePointsAll() -> ARPointCloud {
        var points: [simd_float3] = [], ids: [UInt64] = []
        for (i, _) in found.sorted(by: { $0.key < $1.key }) {
            let p = scene.planes[i]
            for a in 0..<5 { for b in 0..<5 {
                points.append(p.center + p.axisX * ((Float(a) / 4 - 0.5) * p.width) + p.axisZ * ((Float(b) / 4 - 0.5) * p.length))
                ids.append(UInt64(i * 100 + a * 5 + b + 1))
            } }
        }
        return ARPointCloud(points: points, identifiers: ids)
    }

    // MARK: the captured image

    /// the scene drawn from the camera: a 4:2:0 full-range YCbCr pixel buffer (as a device's camera delivers), and the
    /// image turned upright for a portrait view
    func render(_ camera: ARCamera, blank: Bool) -> (buffer: CVPixelBuffer, portrait: Data) {
        let w = width, h = height
        var bgra = [UInt8](repeating: 0, count: w * h * 4)
        bgra.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return }
            // image coordinates: origin top-left, v down
            ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
            let bg = blank ? (0.0, 0.0, 0.0) : scene.background
            ctx.setFillColor(red: bg.0, green: bg.1, blue: bg.2, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            guard !blank else { return }
            let view = _ARMath.inverse(camera.transform)
            let eye = SIMD3(camera.transform.columns.3.x, camera.transform.columns.3.y, camera.transform.columns.3.z)
            func toCam(_ p: SIMD3<Float>) -> SIMD3<Float> { let c = view * SIMD4(p, 1); return SIMD3(c.x, c.y, c.z) }
            func project(_ c: SIMD3<Float>) -> CGPoint {
                CGPoint(x: CGFloat(Float(w) / 2 + focal * c.x / -c.z), y: CGFloat(Float(h) / 2 - focal * c.y / -c.z))
            }
            /// clips a camera-space polygon to z < -near
            func clip(_ poly: [SIMD3<Float>]) -> [SIMD3<Float>] {
                let near: Float = -0.05
                var out: [SIMD3<Float>] = []
                for k in 0..<poly.count {
                    let a = poly[k], b = poly[(k + 1) % poly.count]
                    let ina = a.z < near, inb = b.z < near
                    if ina { out.append(a) }
                    if ina != inb { let t = (near - a.z) / (b.z - a.z); out.append(a + (b - a) * t) }
                }
                return out
            }
            // far planes first
            let order = scene.planes.indices.sorted { simd_distance(scene.planes[$0].center, eye) > simd_distance(scene.planes[$1].center, eye) }
            for i in order {
                let p = scene.planes[i]
                // planes seen from behind are not drawn (walls face into the room)
                if p.alignment == .vertical && simd_dot(eye - p.center, p.normal) < 0 { continue }
                let poly = clip(p.corners.map(toCam))
                guard poly.count >= 3 else { continue }
                // shade by the angle to the light (from above, slightly ahead)
                let light = simd_normalize(SIMD3<Float>(0.3, 1, 0.5))
                let shade = CGFloat(0.75 + 0.25 * max(0, simd_dot(p.normal, light)))
                ctx.setFillColor(red: p.color.0 * shade, green: p.color.1 * shade, blue: p.color.2 * shade, alpha: 1)
                ctx.beginPath()
                ctx.addLines(between: poly.map(project))
                ctx.closePath()
                ctx.fillPath()
                if p.grid {
                    ctx.setStrokeColor(red: p.color.0 * shade * 0.75, green: p.color.1 * shade * 0.75, blue: p.color.2 * shade * 0.75, alpha: 1)
                    ctx.setLineWidth(1.5)
                    let step: Float = p.classification == .table ? 0.2 : 0.5
                    var lines: [(SIMD3<Float>, SIMD3<Float>)] = []
                    var x = -p.width / 2 + step
                    while x < p.width / 2 { lines.append((p.center + p.axisX * x - p.axisZ * (p.length / 2), p.center + p.axisX * x + p.axisZ * (p.length / 2))); x += step }
                    var z = -p.length / 2 + step
                    while z < p.length / 2 { lines.append((p.center + p.axisZ * z - p.axisX * (p.width / 2), p.center + p.axisZ * z + p.axisX * (p.width / 2))); z += step }
                    for (a, b) in lines {
                        var ca = toCam(a), cb = toCam(b)
                        if ca.z >= -0.05 && cb.z >= -0.05 { continue }
                        if ca.z >= -0.05 { ca = cb + (ca - cb) * ((-0.05 - cb.z) / (ca.z - cb.z)) }
                        if cb.z >= -0.05 { cb = ca + (cb - ca) * ((-0.05 - ca.z) / (cb.z - ca.z)) }
                        ctx.move(to: project(ca)); ctx.addLine(to: project(cb))
                    }
                    ctx.strokePath()
                }
            }
        }
        // YCbCr 4:2:0, full range (BT.601)
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, &pb)
        let buffer = pb!
        CVPixelBufferLockBaseAddress(buffer, [])
        if let yBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 0), let cBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) {
            let yRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0), cRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            let yp = yBase.assumingMemoryBound(to: UInt8.self), cp = cBase.assumingMemoryBound(to: UInt8.self)
            for v in 0..<h {
                for u in 0..<w {
                    let o = (v * w + u) * 4
                    let b = Float(bgra[o]), g = Float(bgra[o + 1]), r = Float(bgra[o + 2])
                    yp[v * yRow + u] = UInt8(max(0, min(255, 0.299 * r + 0.587 * g + 0.114 * b)))
                    if v & 1 == 0 && u & 1 == 0 {
                        cp[(v / 2) * cRow + u] = UInt8(max(0, min(255, 128 - 0.168736 * r - 0.331264 * g + 0.5 * b)))
                        cp[(v / 2) * cRow + u + 1] = UInt8(max(0, min(255, 128 + 0.5 * r - 0.418688 * g - 0.081312 * b)))
                    }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        // upright for portrait (the image's width runs up the screen), RGBA for ARSCNView's background texture
        var up = [UInt8](repeating: 255, count: w * h * 4)
        for v in 0..<h {
            for u in 0..<w {
                let src = (v * w + u) * 4, dst = ((w - 1 - u) * h + v) * 4
                up[dst] = bgra[src + 2]; up[dst + 1] = bgra[src + 1]; up[dst + 2] = bgra[src]
            }
        }
        return (buffer, Data(up))
    }
}

// MARK: - plane anchors from the scene

extension ARPlaneAnchor {
    convenience init(_plane p: _ARScenePlane) {
        self.init(_transform: p.transform)
        alignment = p.alignment
        classification = p.classification
        _setExtent(p.width / 2, p.length / 2)
    }
    /// the extent and geometry: a rectangle around the anchor's origin in its x-z plane
    func _setExtent(_ w: Float, _ l: Float) {
        let e = ARPlaneExtent()
        e.width = w; e.height = l
        planeExtent = e
        let g = ARPlaneGeometry()
        let corners = [SIMD3<Float>(-w / 2, 0, -l / 2), SIMD3(w / 2, 0, -l / 2), SIMD3(w / 2, 0, l / 2), SIMD3(-w / 2, 0, l / 2)]
        g.vertices = corners
        g.boundaryVertices = corners
        g.textureCoordinates = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]
        g.triangleIndices = [0, 1, 2, 0, 2, 3]
        geometry = g
    }
    var _worldCenter: SIMD3<Float> { let c = transform * SIMD4(center, 1); return SIMD3(c.x, c.y, c.z) }
}
