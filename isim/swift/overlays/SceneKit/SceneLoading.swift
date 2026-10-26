// isim SceneKit: scene files (issue #330). Wavefront OBJ files (with their MTL materials and textures) load into a
// node per object, and scenes isim wrote with SCNScene.write(to:) (.scn: a keyed archive of the scene graph) load back.
// Not provided: Apple's .scn and .dae as Xcode compiles them, USD / USDZ, and Model I/O.
import UIKit
import simd

/// A scene file and what it holds.
@objc(SCNSceneSource) open class SCNSceneSource: NSObject, @unchecked Sendable {
    public struct LoadingOption: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let animationImportPolicy = LoadingOption(rawValue: "kSceneSourceAnimationLoadingMode")
        public static let assetDirectoryURLs = LoadingOption(rawValue: "kSceneSourceAssetDirectoryURLs")
        public static let checkConsistency = LoadingOption(rawValue: "kSceneSourceCheckConsistency")
        public static let convertToYUp = LoadingOption(rawValue: "kSceneSourceConvertToYUpIfNeeded")
        public static let convertUnitsToMeters = LoadingOption(rawValue: "kSceneSourceConvertUnitsToMeters")
        public static let createNormalsIfAbsent = LoadingOption(rawValue: "kSceneSourceCreateNormalsIfAbsent")
        public static let flattenScene = LoadingOption(rawValue: "kSceneSourceFlattenScene")
        public static let overrideAssetURLs = LoadingOption(rawValue: "kSceneSourceOverrideAssetURLs")
        public static let preserveOriginalTopology = LoadingOption(rawValue: "kSceneSourcePreserveOriginalTopology")
        public static let strictConformance = LoadingOption(rawValue: "kSceneSourceStrictConformanceKey")
        public static let useSafeMode = LoadingOption(rawValue: "kSceneSourceUseSafeMode")
    }
    @objc open private(set) var url: URL?
    @objc open private(set) var data: Data?
    @objc public init?(url: URL, options: [String: Any]? = nil) { self.url = url; super.init() }
    @objc public init?(data: Data, options: [String: Any]? = nil) { self.data = data; super.init() }
    public func scene(options: [LoadingOption: Any]? = nil) throws -> SCNScene { try _load() }
    func _load() throws -> SCNScene {
        if let url { return try SCNScene(url: url) }
        guard let data, let s = try NSKeyedUnarchiver.unarchivedObject(ofClass: SCNScene.self, from: data) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
        }
        return s
    }
    public func scene(options: [LoadingOption: Any]? = nil, statusHandler: ((Float, SCNSceneSourceStatus, (any Error)?, UnsafeMutablePointer<ObjCBool>) -> Void)? = nil) -> SCNScene? {
        var stop = ObjCBool(false)
        do {
            let s = try _load()
            statusHandler?(1, .complete, nil, &stop)
            return s
        } catch {
            statusHandler?(1, .error, error, &stop)
            return nil
        }
    }
    /// the nodes, geometry, materials, lights or cameras of a class in the file, by name
    open func entryWithIdentifier<T>(_ uid: String, withClass entryClass: T.Type) -> T? where T: AnyObject {
        guard let s = try? _load() else { return nil }
        var found: T?
        s.rootNode.enumerateHierarchy { n, stop in
            for o in [n, n.geometry, n.light, n.camera] as [AnyObject?] {
                if let o = o as? T, (o as? SCNNode)?.name == uid || (o as? SCNGeometry)?.name == uid || (o as? SCNLight)?.name == uid
                    || (o as? SCNCamera)?.name == uid { found = o; stop.pointee = true; return }
            }
        }
        return found
    }
    open func identifiersOfEntries<T>(withClass entryClass: T.Type) -> [String] where T: AnyObject {
        guard let s = try? _load() else { return [] }
        var out: [String] = []
        s.rootNode.enumerateHierarchy { n, _ in
            if T.self == SCNNode.self, let name = n.name { out.append(name) }
            if T.self == SCNGeometry.self, let name = n.geometry?.name { out.append(name) }
        }
        return out
    }
}
public enum SCNSceneSourceStatus: Int, Sendable { case error = -1, parsing = 4, validating = 8, processing = 12, complete = 16 }

enum _SCNSceneFile {
    /// a scene file in the main bundle, by name (with or without its extension) and directory
    static func find(_ name: String, directory: String?) -> URL? {
        let b = Bundle.main
        let ext = (name as NSString).pathExtension, base = (name as NSString).deletingPathExtension
        for dir in [directory, nil] {
            if !ext.isEmpty, let u = b.url(forResource: base, withExtension: ext, subdirectory: dir) { return u }
            for e in ["scn", "obj"] { if let u = b.url(forResource: name, withExtension: e, subdirectory: dir) { return u } }
        }
        if FileManager.default.fileExists(atPath: name) { return URL(fileURLWithPath: name) }
        return nil
    }
    static func failure(_ url: URL, _ why: String) -> NSError {
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError,
                userInfo: [NSLocalizedDescriptionKey: "\(url.lastPathComponent): \(why)", NSURLErrorKey: url])
    }
    static func load(_ url: URL) throws -> SCNNode {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSURLErrorKey: url])
        }
        switch url.pathExtension.lowercased() {
        case "obj": return try obj(String(decoding: data, as: UTF8.self), base: url.deletingLastPathComponent())
        case "scn":
            if let s = try? NSKeyedUnarchiver.unarchivedObject(ofClass: SCNScene.self, from: data) { return s.rootNode }
            throw failure(url, "isim reads the .scn files isim writes (SCNScene.write(to:)), not Xcode's")
        default:
            throw failure(url, "isim's SceneKit cannot read .\(url.pathExtension) files (it reads .obj and its own .scn)")
        }
    }

    // MARK: Wavefront OBJ

    static func obj(_ text: String, base: URL) throws -> SCNNode {
        var v: [SIMD3<Float>] = [], vn: [SIMD3<Float>] = [], vt: [SIMD2<Float>] = [], vc: [SIMD3<Float>?] = []
        var materials: [String: SCNMaterial] = [:]
        struct Group { var name: String; var faces: [(material: String?, corners: [(Int, Int?, Int?)])] = [] }
        var groups: [Group] = [Group(name: "")]
        var material: String?
        func index(_ s: Substring, _ count: Int) -> Int? {
            guard let i = Int(s) else { return nil }
            return i < 0 ? count + i : i - 1
        }
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            let p = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let head = p.first else { continue }
            let f = p.dropFirst().compactMap { Float($0) }
            switch head {
            case "v" where f.count >= 3:
                v.append(SIMD3(f[0], f[1], f[2]))
                vc.append(f.count >= 6 ? SIMD3(f[3], f[4], f[5]) : nil)
            case "vn" where f.count >= 3: vn.append(SIMD3(f[0], f[1], f[2]))
            case "vt" where f.count >= 2: vt.append(SIMD2(f[0], f[1]))
            case "vt" where f.count == 1: vt.append(SIMD2(f[0], 0))
            case "f":
                let corners = p.dropFirst().compactMap { c -> (Int, Int?, Int?)? in
                    let parts = c.split(separator: "/", omittingEmptySubsequences: false)
                    guard let pi = index(parts[0], v.count) else { return nil }
                    let ti = parts.count > 1 ? index(parts[1], vt.count) : nil
                    let ni = parts.count > 2 ? index(parts[2], vn.count) : nil
                    return (pi, ti, ni)
                }
                if corners.count >= 3 { groups[groups.count - 1].faces.append((material, corners)) }
            case "o", "g":
                let name = p.dropFirst().joined(separator: " ")
                if groups[groups.count - 1].faces.isEmpty { groups[groups.count - 1].name = name } else { groups.append(Group(name: name)) }
            case "usemtl": material = p.dropFirst().joined(separator: " ")
            case "mtllib":
                for file in p.dropFirst() {
                    if let s = try? String(contentsOf: base.appendingPathComponent(String(file)), encoding: .utf8) {
                        materials.merge(mtl(s, base: base)) { a, _ in a }
                    }
                }
            default: break
            }
        }
        let root = SCNNode()
        let hasColors = vc.contains { $0 != nil }
        for g in groups where !g.faces.isEmpty {
            // smooth normals for vertices without one
            var smooth = [SIMD3<Float>](repeating: .zero, count: v.count)
            if g.faces.contains(where: { $0.corners.contains { $0.2 == nil } }) {
                for face in g.faces {
                    let a = v[face.corners[0].0]
                    for k in 1..<(face.corners.count - 1) {
                        let n = simd_cross(v[face.corners[k].0] - a, v[face.corners[k + 1].0] - a)
                        for c in [face.corners[0], face.corners[k], face.corners[k + 1]] where c.0 < smooth.count { smooth[c.0] += n }
                    }
                }
            }
            var pos: [SCNVector3] = [], nor: [SCNVector3] = [], tex: [CGPoint] = [], col: [Float] = []
            var seen: [String: UInt32] = [:]
            var elements: [(String?, [UInt32])] = []
            for face in g.faces {
                var idx: [UInt32] = []
                for c in face.corners {
                    guard c.0 >= 0 && c.0 < v.count else { idx.append(0); continue }
                    let key = "\(c.0)/\(c.1 ?? -1)/\(c.2 ?? -1)"
                    if let i = seen[key] { idx.append(i); continue }
                    let i = UInt32(pos.count)
                    seen[key] = i
                    pos.append(SCNVector3(v[c.0]))
                    let n = c.2.flatMap { $0 >= 0 && $0 < vn.count ? vn[$0] : nil } ?? smooth[c.0]
                    nor.append(SCNVector3(simd_length(n) > 0 ? simd_normalize(n) : SIMD3(0, 1, 0)))
                    let t = c.1.flatMap { $0 >= 0 && $0 < vt.count ? vt[$0] : nil } ?? .zero
                    tex.append(CGPoint(x: CGFloat(t.x), y: CGFloat(1 - t.y)))
                    if hasColors { let k = vc[c.0] ?? SIMD3(1, 1, 1); col += [k.x, k.y, k.z] }
                    idx.append(i)
                }
                var tris: [UInt32] = []
                for k in 1..<(idx.count - 1) { tris += [idx[0], idx[k], idx[k + 1]] }
                if let last = elements.last, last.0 == face.material { elements[elements.count - 1].1 += tris } else { elements.append((face.material, tris)) }
            }
            var sources = [SCNGeometrySource(vertices: pos), SCNGeometrySource(normals: nor), SCNGeometrySource(textureCoordinates: tex)]
            if hasColors { sources.append(SCNGeometrySource(floats: col, n: 3, semantic: .color)) }
            let geometry = SCNGeometry(sources: sources, elements: elements.map { SCNGeometryElement(indices: $0.1, primitiveType: .triangles) })
            geometry.materials = elements.map { e in
                e.0.flatMap { materials[$0] } ?? { let m = SCNMaterial(); m.name = e.0; return m }()
            }
            geometry.name = g.name.isEmpty ? nil : g.name
            let node = SCNNode(geometry: geometry)
            node.name = g.name.isEmpty ? nil : g.name
            root.addChildNode(node)
        }
        return root
    }

    /// MTL materials: colours, shininess, opacity and texture maps
    static func mtl(_ text: String, base: URL) -> [String: SCNMaterial] {
        var out: [String: SCNMaterial] = [:]
        var m: SCNMaterial?
        func color(_ f: [Float]) -> UIColor { UIColor(red: CGFloat(f[0]), green: CGFloat(f[1]), blue: CGFloat(f[2]), alpha: 1) }
        func image(_ p: [Substring]) -> UIImage? {
            // the file is the last argument (options come first)
            guard let file = p.last else { return nil }
            return UIImage(contentsOfFile: base.appendingPathComponent(String(file)).path)
        }
        for raw in text.split(whereSeparator: \.isNewline) {
            let p = raw.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let head = p.first else { continue }
            let f = p.dropFirst().compactMap { Float($0) }
            if head == "newmtl" {
                let mat = SCNMaterial()
                mat.name = p.dropFirst().joined(separator: " ")
                mat.locksAmbientWithDiffuse = true
                out[mat.name ?? ""] = mat
                m = mat
                continue
            }
            guard let m else { continue }
            switch head {
            case "Kd" where f.count >= 3: m.diffuse.contents = color(f)
            case "Ks" where f.count >= 3: m.specular.contents = color(f)
            case "Ke" where f.count >= 3: m.emission.contents = color(f)
            case "Ka" where f.count >= 3: m.ambient.contents = color(f)
            case "Ns" where !f.isEmpty: m.shininess = CGFloat(f[0])
            case "d" where !f.isEmpty: m.transparency = CGFloat(f[0])
            case "Tr" where !f.isEmpty: m.transparency = CGFloat(1 - f[0])
            case "map_Kd": if let i = image(Array(p.dropFirst())) { m.diffuse.contents = i; m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat }
            case "map_Ks": if let i = image(Array(p.dropFirst())) { m.specular.contents = i }
            case "map_Ke": if let i = image(Array(p.dropFirst())) { m.emission.contents = i }
            case "map_d": if let i = image(Array(p.dropFirst())) { m.transparent.contents = i }
            case "map_Bump", "bump", "norm": if let i = image(Array(p.dropFirst())) { m.normal.contents = i }
            case "illum" where !f.isEmpty: m.lightingModel = f[0] <= 0 ? .constant : f[0] == 1 ? .lambert : .blinn
            default: break
            }
        }
        return out
    }
}
