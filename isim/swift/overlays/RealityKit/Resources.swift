// isim RealityKit (issue #331): meshes, textures and materials. Adapted: a MeshResource holds SceneKit geometry and a
// material becomes a SceneKit material (physically based, or constant for unlit ones), drawn by isim's SceneKit renderer.
import UIKit
import SceneKit
import simd

/// Geometry for models.
@MainActor @preconcurrency public final class MeshResource: Sendable {
    /// the geometry, its elements in the order of the material indices (`_materialIndex`)
    let _geometry: SCNGeometry
    let _materialIndex: [Int]
    nonisolated init(_ g: SCNGeometry, materialIndex: [Int]? = nil) {
        _geometry = g
        _materialIndex = materialIndex ?? Array(0..<max(g.elementCount, 1)).map { _ in 0 }
    }
    nonisolated public var bounds: BoundingBox {
        let b = _geometry.boundingBox
        return BoundingBox(min: SIMD3(b.min), max: SIMD3(b.max))
    }
    nonisolated public var expectedMaterialCount: Int { (_materialIndex.max() ?? 0) + 1 }

    /// a box centred on the origin
    public static func generateBox(size: Float, cornerRadius: Float = 0) -> MeshResource {
        generateBox(width: size, height: size, depth: size, cornerRadius: cornerRadius)
    }
    public static func generateBox(size: SIMD3<Float>, cornerRadius: Float = 0) -> MeshResource {
        generateBox(width: size.x, height: size.y, depth: size.z, cornerRadius: cornerRadius)
    }
    public static func generateBox(size: SIMD3<Float>, majorCornerRadius: Float, minorCornerRadius: Float) -> MeshResource {
        generateBox(width: size.x, height: size.y, depth: size.z, cornerRadius: majorCornerRadius)
    }
    /// with `splitFaces`, the six faces take materials 0…5 (front, top, back, bottom, right, left)
    public static func generateBox(width: Float, height: Float, depth: Float, cornerRadius: Float = 0, splitFaces: Bool = false) -> MeshResource {
        let g = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: CGFloat(cornerRadius))
        // SceneKit's faces: front, right, back, left, top, bottom
        return MeshResource(g, materialIndex: splitFaces ? [0, 4, 2, 5, 1, 3] : [0, 0, 0, 0, 0, 0])
    }
    public static func generateSphere(radius: Float) -> MeshResource { MeshResource(SCNSphere(radius: CGFloat(radius)), materialIndex: [0]) }
    /// a rectangle in the xy plane, facing +z
    public static func generatePlane(width: Float, height: Float, cornerRadius: Float = 0) -> MeshResource {
        MeshResource(SCNPlane(width: CGFloat(width), height: CGFloat(height)), materialIndex: [0])
    }
    /// a rectangle in the xz plane, facing +y
    public static func generatePlane(width: Float, depth: Float, cornerRadius: Float = 0) -> MeshResource {
        var d = MeshDescriptor(name: "plane")
        let w = width / 2, l = depth / 2
        d.positions = MeshBuffers.Positions([SIMD3(-w, 0, -l), SIMD3(-w, 0, l), SIMD3(w, 0, l), SIMD3(w, 0, -l)])
        d.normals = MeshBuffers.Normals(Array(repeating: SIMD3<Float>(0, 1, 0), count: 4))
        d.textureCoordinates = MeshBuffers.TextureCoordinates([SIMD2(0, 1), SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)])
        d.primitives = .triangles([0, 1, 2, 0, 2, 3])
        return try! generate(from: [d])
    }
    public static func generateCylinder(height: Float, radius: Float) -> MeshResource {
        let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        return MeshResource(g, materialIndex: [0, 0, 0])
    }
    public static func generateCone(height: Float, radius: Float) -> MeshResource {
        MeshResource(SCNCone(topRadius: 0, bottomRadius: CGFloat(radius), height: CGFloat(height)), materialIndex: [0, 0])
    }
    /// meshes from descriptors (positions, normals, texture coordinates, triangles / quads / polygons, per-face materials)
    public static func generate(from descriptors: [MeshDescriptor]) throws -> MeshResource {
        var pos: [SCNVector3] = [], nor: [SCNVector3] = [], tex: [CGPoint] = []
        var byMaterial: [Int: [UInt32]] = [:]
        for d in descriptors {
            guard let p = d.positions?.elements, !p.isEmpty else { continue }
            let base = UInt32(pos.count)
            let n = d.normals?.elements
            let t = d.textureCoordinates?.elements
            // triangles from the primitives
            var tris: [UInt32] = []
            switch d.primitives {
            case .triangles(let i)?: tris = i
            case .trianglesAndQuads(let t3, let q)?:
                tris = t3
                for k in stride(from: 0, to: q.count - 3, by: 4) { tris += [q[k], q[k + 1], q[k + 2], q[k], q[k + 2], q[k + 3]] }
            case .polygons(let counts, let idx)?:
                var at = 0
                for c in counts {
                    let c = Int(c)
                    if c >= 3 { for k in 1..<(c - 1) { tris += [idx[at], idx[at + k], idx[at + k + 1]] } }
                    at += c
                }
            case nil: tris = (0..<UInt32(p.count)).map { $0 }
            }
            // smooth normals when the descriptor has none
            var normals = n ?? []
            if n == nil {
                normals = Array(repeating: .zero, count: p.count)
                for k in stride(from: 0, to: tris.count - 2, by: 3) {
                    let a = Int(tris[k]), b = Int(tris[k + 1]), c = Int(tris[k + 2])
                    let fn = simd_cross(p[b] - p[a], p[c] - p[a])
                    normals[a] += fn; normals[b] += fn; normals[c] += fn
                }
                normals = normals.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
            }
            for i in p.indices {
                pos.append(SCNVector3(p[i])); nor.append(SCNVector3(normals[i]))
                let uv = t.flatMap { i < $0.count ? $0[i] : nil } ?? .zero
                tex.append(CGPoint(x: CGFloat(uv.x), y: CGFloat(1 - uv.y)))   // RealityKit's v points up
            }
            for f in 0..<(tris.count / 3) {
                let m: Int
                switch d.materials {
                case .allFaces(let k): m = Int(k)
                case .perFace(let list): m = f < list.count ? Int(list[f]) : 0
                }
                byMaterial[m, default: []] += tris[(f * 3)..<(f * 3 + 3)].map { $0 + base }
            }
        }
        guard !pos.isEmpty else {
            throw NSError(domain: "RealityKit.MeshResource", code: 1, userInfo: [NSLocalizedDescriptionKey: "The mesh descriptors have no positions"])
        }
        let order = byMaterial.keys.sorted()
        let g = SCNGeometry(sources: [SCNGeometrySource(vertices: pos), SCNGeometrySource(normals: nor), SCNGeometrySource(textureCoordinates: tex)],
                            elements: order.map { SCNGeometryElement(indices: byMaterial[$0]!, primitiveType: .triangles) })
        return MeshResource(g, materialIndex: order)
    }
    public convenience init(from descriptors: [MeshDescriptor]) async throws {
        let m = try MeshResource.generate(from: descriptors)
        self.init(m._geometry, materialIndex: m._materialIndex)
    }

    /// the model's SceneKit geometry: a copy of the mesh with the materials, element by element
    func _geometry(materials: [any Material]) -> SCNGeometry {
        let g = _geometry.copy() as! SCNGeometry
        let scn = materials.map(_Materials.scn)
        g.materials = _materialIndex.map { i in scn.isEmpty ? _Materials.missing : scn[min(i, scn.count - 1)] }
        return g
    }
}

/// A typed buffer of mesh data.
public struct MeshBuffer<Element>: Sendable {
    nonisolated(unsafe) public let elements: [Element]
    public init(_ elements: [Element]) { self.elements = elements }
    public var count: Int { elements.count }
}
public enum MeshBuffers {
    public typealias Positions = MeshBuffer<SIMD3<Float>>
    public typealias Normals = MeshBuffer<SIMD3<Float>>
    public typealias Tangents = MeshBuffer<SIMD3<Float>>
    public typealias TextureCoordinates = MeshBuffer<SIMD2<Float>>
}

/// A mesh's vertex data and faces.
public struct MeshDescriptor: Sendable {
    public enum Primitives: Sendable {
        case triangles([UInt32])
        case trianglesAndQuads(triangles: [UInt32], quads: [UInt32])
        case polygons([UInt8], [UInt32])
    }
    public enum Materials: Sendable {
        case allFaces(UInt32)
        case perFace([UInt32])
    }
    public var name: String
    public var positions: MeshBuffers.Positions?
    public var normals: MeshBuffers.Normals?
    public var tangents: MeshBuffers.Tangents?
    public var textureCoordinates: MeshBuffers.TextureCoordinates?
    public var primitives: Primitives?
    public var materials: Materials = .allFaces(0)
    public init(name: String = "") { self.name = name }
}

/// An image for materials.
@MainActor @preconcurrency public final class TextureResource: Sendable {
    public struct CreateOptions: Sendable {
        public enum Semantic: Sendable { case color, raw, normal, hdrColor, scalar }
        public var semantic: Semantic?
        public var mipmapsMode: MipmapsMode = .allocateAndGenerateAll
        public init(semantic: Semantic?) { self.semantic = semantic }
        public init(semantic: Semantic?, mipmapsMode: MipmapsMode) { self.semantic = semantic; self.mipmapsMode = mipmapsMode }
    }
    public enum MipmapsMode: Sendable { case none, allocateAll, allocateAndGenerateAll }
    nonisolated(unsafe) let _image: CGImage
    nonisolated init(_ image: CGImage) { _image = image }
    nonisolated public var width: Int { _image.width }
    nonisolated public var height: Int { _image.height }
    public static func generate(from cgImage: CGImage, options: CreateOptions) throws -> TextureResource { TextureResource(cgImage) }
    public convenience init(image: CGImage, options: CreateOptions) async throws { self.init(image) }
    /// an image in a bundle (an asset catalog image or a file)
    public static func load(named name: String, in bundle: Bundle? = nil) throws -> TextureResource {
        guard let img = UIImage(named: name, in: bundle, with: nil)?.cgImage
                ?? (bundle ?? .main).path(forResource: name, ofType: nil).flatMap(UIImage.init(contentsOfFile:))?.cgImage else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSLocalizedDescriptionKey: "No texture named \(name)"])
        }
        return TextureResource(img)
    }
    public static func load(contentsOf url: URL, withName resourceName: String? = nil) throws -> TextureResource {
        guard let img = UIImage(contentsOfFile: url.path)?.cgImage else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSURLErrorKey: url])
        }
        return TextureResource(img)
    }
    public convenience init(named name: String, in bundle: Bundle? = nil) async throws { self.init(try TextureResource.load(named: name, in: bundle)._image) }
}

/// A surface's appearance.
public protocol Material: Sendable {}

public enum MaterialParameters {
    /// A texture with how it is sampled.
    public struct Texture: Sendable {
        public var resource: TextureResource
        public init(_ resource: TextureResource) { self.resource = resource }
    }
    public enum FaceCulling: Sendable { case none, front, back }
}
/// A number, or a texture, for a material parameter.
public enum MaterialScalarParameter: ExpressibleByFloatLiteral, Sendable {
    case float(Float)
    case texture(TextureResource)
    public init(floatLiteral value: Float) { self = .float(value) }
}
/// A colour, or a texture, for a material parameter.
public enum MaterialColorParameter: ExpressibleByArrayLiteral, @unchecked Sendable {
    case color(UIColor)
    case texture(TextureResource)
    public init(arrayLiteral elements: Float...) {
        let c = elements + [1, 1, 1, 1]
        self = .color(UIColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: CGFloat(elements.count >= 4 ? c[3] : 1)))
    }
}

/// A simple lit material: a colour, roughness and metal or not.
public struct SimpleMaterial: Material {
    public typealias Color = UIColor
    public struct BaseColor: @unchecked Sendable {
        public var tint: UIColor
        public var texture: MaterialParameters.Texture?
        public init(tint: UIColor = .white, texture: MaterialParameters.Texture? = nil) { self.tint = tint; self.texture = texture }
    }
    public var color: BaseColor
    public var roughness: MaterialScalarParameter
    public var metallic: MaterialScalarParameter
    public var faceCulling: MaterialParameters.FaceCulling = .back
    public init() { color = BaseColor(); roughness = 0.0; metallic = 0.0 }
    public init(color: SimpleMaterial.Color, roughness: MaterialScalarParameter = 0.0, isMetallic: Bool) {
        self.color = BaseColor(tint: color); self.roughness = roughness; metallic = .float(isMetallic ? 1 : 0)
    }
    public var baseColor: MaterialColorParameter {
        get { color.texture.map { .texture($0.resource) } ?? .color(color.tint) }
        set { switch newValue { case .color(let c): color = BaseColor(tint: c); case .texture(let t): color = BaseColor(texture: .init(t)) } }
    }
    public var tintColor: UIColor { get { color.tint } set { color.tint = newValue } }
}

/// A material that ignores lights: its colour as is.
public struct UnlitMaterial: Material {
    public struct BaseColor: @unchecked Sendable {
        public var tint: UIColor
        public var texture: MaterialParameters.Texture?
        public init(tint: UIColor = .white, texture: MaterialParameters.Texture? = nil) { self.tint = tint; self.texture = texture }
    }
    public var color: BaseColor
    public var blending: PhysicallyBasedMaterial.Blending = .opaque
    public var opacityThreshold: Float?
    public var faceCulling: MaterialParameters.FaceCulling = .back
    public init() { color = BaseColor() }
    public init(applyPostProcessToneMap: Bool) { color = BaseColor() }
    public init(color: UIColor) { self.color = BaseColor(tint: color) }
    public init(texture: TextureResource) { color = BaseColor(texture: .init(texture)) }
}

/// Invisible geometry that hides what is behind it (it writes depth only).
public struct OcclusionMaterial: Material {
    public var receivesDynamicLighting = false
    public init() {}
    public init(receivesDynamicLighting: Bool) { self.receivesDynamicLighting = receivesDynamicLighting }
}

/// A physically based material: base colour, metallic and roughness, emission, blending.
public struct PhysicallyBasedMaterial: Material {
    public struct BaseColor: @unchecked Sendable {
        public var tint: UIColor
        public var texture: MaterialParameters.Texture?
        public init(tint: UIColor = .white, texture: MaterialParameters.Texture? = nil) { self.tint = tint; self.texture = texture }
    }
    public struct Metallic: ExpressibleByFloatLiteral, Sendable {
        public var scale: Float
        public var texture: MaterialParameters.Texture?
        public init(floatLiteral value: Float) { scale = value }
        public init(scale: Float = 1, texture: MaterialParameters.Texture? = nil) { self.scale = scale; self.texture = texture }
    }
    public typealias Roughness = Metallic
    public struct EmissiveColor: @unchecked Sendable {
        public var color: UIColor
        public var texture: MaterialParameters.Texture?
        public init(color: UIColor = .black, texture: MaterialParameters.Texture? = nil) { self.color = color; self.texture = texture }
    }
    public struct Opacity: ExpressibleByFloatLiteral, Sendable {
        public var scale: Float
        public var texture: MaterialParameters.Texture?
        public init(floatLiteral value: Float) { scale = value }
        public init(scale: Float = 1, texture: MaterialParameters.Texture? = nil) { self.scale = scale; self.texture = texture }
    }
    public enum Blending: Sendable {
        case opaque
        case transparent(opacity: Opacity)
    }
    public struct Normal: Sendable {
        public var texture: MaterialParameters.Texture?
        public init(texture: MaterialParameters.Texture? = nil) { self.texture = texture }
    }
    public struct AmbientOcclusion: Sendable {
        public var texture: MaterialParameters.Texture?
        public init(texture: MaterialParameters.Texture? = nil) { self.texture = texture }
    }
    public struct Specular: ExpressibleByFloatLiteral, Sendable {
        public var scale: Float
        public init(floatLiteral value: Float) { scale = value }
        public init(scale: Float = 1) { self.scale = scale }
    }
    public struct Clearcoat: ExpressibleByFloatLiteral, Sendable {
        public var scale: Float
        public init(floatLiteral value: Float) { scale = value }
        public init(scale: Float = 1) { self.scale = scale }
    }
    public var baseColor = BaseColor()
    public var metallic: Metallic = 0.0
    public var roughness: Roughness = 0.5
    public var emissiveColor = EmissiveColor()
    public var emissiveIntensity: Float = 1
    public var blending: Blending = .opaque
    public var opacityThreshold: Float?
    public var faceCulling: MaterialParameters.FaceCulling = .back
    /// kept, not drawn
    public var normal = Normal()
    public var ambientOcclusion = AmbientOcclusion()
    public var specular: Specular = 0.0
    public var clearcoat: Clearcoat = 0.0
    public init() {}
}

/// A material from a scene file (its SceneKit material as loaded)
struct _LoadedMaterial: Material {
    let material: SCNMaterial
}

enum _Materials {
    static let missing: SCNMaterial = {
        // RealityKit draws a model without materials in a pink "missing material"
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        return m
    }()
    static func image(_ t: MaterialParameters.Texture?) -> CGImage? { t?.resource._image }
    static func cull(_ m: SCNMaterial, _ c: MaterialParameters.FaceCulling) {
        switch c { case .none: m.isDoubleSided = true; case .front: m.cullMode = .front; case .back: m.cullMode = .back }
    }
    /// a RealityKit material as a SceneKit one
    static func scn(_ material: any Material) -> SCNMaterial {
        let m = SCNMaterial()
        switch material {
        case let s as SimpleMaterial:
            m.lightingModel = .physicallyBased
            m.diffuse.contents = image(s.color.texture) ?? s.color.tint
            if s.color.texture != nil { m.multiply.contents = s.color.tint }
            switch s.metallic { case .float(let f): m.metalness.contents = NSNumber(value: f); case .texture(let t): m.metalness.contents = t._image }
            switch s.roughness { case .float(let f): m.roughness.contents = NSNumber(value: f); case .texture(let t): m.roughness.contents = t._image }
            cull(m, s.faceCulling)
        case let u as UnlitMaterial:
            m.lightingModel = .constant
            m.diffuse.contents = image(u.color.texture) ?? u.color.tint
            if u.color.texture != nil { m.multiply.contents = u.color.tint }
            if case .transparent(let o) = u.blending { m.transparency = CGFloat(o.scale) }
            cull(m, u.faceCulling)
        case let p as PhysicallyBasedMaterial:
            m.lightingModel = .physicallyBased
            m.diffuse.contents = image(p.baseColor.texture) ?? p.baseColor.tint
            if p.baseColor.texture != nil { m.multiply.contents = p.baseColor.tint }
            m.metalness.contents = image(p.metallic.texture) ?? NSNumber(value: p.metallic.scale)
            if p.metallic.texture != nil { m.metalness.intensity = CGFloat(p.metallic.scale) }
            m.roughness.contents = image(p.roughness.texture) ?? NSNumber(value: p.roughness.scale)
            if p.roughness.texture != nil { m.roughness.intensity = CGFloat(p.roughness.scale) }
            m.emission.contents = image(p.emissiveColor.texture) ?? p.emissiveColor.color
            m.emission.intensity = CGFloat(p.emissiveIntensity)
            if case .transparent(let o) = p.blending {
                m.transparency = CGFloat(o.scale)
                if let t = image(o.texture) { m.transparent.contents = t }
            }
            m.ambientOcclusion.contents = image(p.ambientOcclusion.texture) ?? UIColor.white
            m.normal.contents = image(p.normal.texture)
            cull(m, p.faceCulling)
        case let o as OcclusionMaterial:
            _ = o
            m.lightingModel = .constant
            m.colorBufferWriteMask = []
            m.writesToDepthBuffer = true
        case let l as _LoadedMaterial:
            return l.material
        default:
            return missing
        }
        return m
    }
}
