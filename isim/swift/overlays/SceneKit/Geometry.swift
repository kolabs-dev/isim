// isim SceneKit: geometry (issue #330). SCNGeometry with its sources and elements, and SceneKit's built-in shapes with
// Apple's dimensions, segment counts, texture coordinates and elements (one per face group, so a geometry's materials
// apply face by face as on iOS). Adapted: chamfers and corner radii are not rounded, and subdivision and levels of
// detail are kept but not applied.
import UIKit
import Metal
import simd

/// What has a bounding box and sphere: geometry and nodes.
public protocol SCNBoundingVolume: AnyObject {
    var boundingBox: (min: SCNVector3, max: SCNVector3) { get set }
    var boundingSphere: (center: SCNVector3, radius: Float) { get }
}

@objc public enum SCNGeometryPrimitiveType: Int, Sendable { case triangles = 0, triangleStrip = 1, line = 2, point = 3, polygon = 4 }

/// A per-vertex attribute: positions, normals, colours or texture coordinates.
@objc(SCNGeometrySource) open class SCNGeometrySource: NSObject, NSSecureCoding, @unchecked Sendable {
    public struct Semantic: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let vertex = Semantic("kGeometrySourceSemanticVertex")
        public static let normal = Semantic("kGeometrySourceSemanticNormal")
        public static let color = Semantic("kGeometrySourceSemanticColor")
        public static let texcoord = Semantic("kGeometrySourceSemanticTexcoord")
        public static let tangent = Semantic("kGeometrySourceSemanticTangent")
        public static let vertexCrease = Semantic("kGeometrySourceSemanticVertexCrease")
        public static let edgeCrease = Semantic("kGeometrySourceSemanticEdgeCrease")
        public static let boneWeights = Semantic("kGeometrySourceSemanticBoneWeights")
        public static let boneIndices = Semantic("kGeometrySourceSemanticBoneIndices")
    }
    @objc open private(set) var data: Data
    open private(set) var semantic: Semantic
    @objc open private(set) var vectorCount: Int
    @objc(floatComponents) open private(set) var usesFloatComponents: Bool
    @objc open private(set) var componentsPerVector: Int
    @objc open private(set) var bytesPerComponent: Int
    @objc open private(set) var dataOffset: Int
    @objc open private(set) var dataStride: Int

    public init(data: Data, semantic: Semantic, vectorCount: Int, usesFloatComponents floatComponents: Bool, componentsPerVector: Int,
                bytesPerComponent: Int, dataOffset offset: Int, dataStride stride: Int) {
        self.data = data; self.semantic = semantic; self.vectorCount = vectorCount; usesFloatComponents = floatComponents
        self.componentsPerVector = componentsPerVector; self.bytesPerComponent = bytesPerComponent; dataOffset = offset
        dataStride = stride == 0 ? componentsPerVector * bytesPerComponent : stride
        super.init()
    }
    /// an MTLBuffer's contents (copied: isim's buffers are in memory)
    public convenience init(buffer mtlBuffer: MTLBuffer, vertexFormat: MTLVertexFormat, semantic: Semantic, vertexCount: Int, dataOffset offset: Int, dataStride stride: Int) {
        let (n, bytes, float): (Int, Int, Bool) = switch vertexFormat {
        case .float: (1, 4, true); case .float2: (2, 4, true); case .float3: (3, 4, true); case .float4: (4, 4, true)
        case .half2: (2, 2, true); case .half3: (3, 2, true); case .half4: (4, 2, true)
        case .uchar4Normalized: (4, 1, false); case .uchar3Normalized: (3, 1, false)
        default: (3, 4, true)
        }
        let length = min(mtlBuffer.length, offset + max(0, vertexCount - 1) * stride + n * bytes)
        self.init(data: Data(bytes: mtlBuffer.contents(), count: max(0, length)), semantic: semantic, vectorCount: vertexCount,
                  usesFloatComponents: float, componentsPerVector: n, bytesPerComponent: bytes, dataOffset: offset, dataStride: stride)
    }
    public convenience init(vertices: [SCNVector3]) { self.init(floats: vertices.flatMap { [$0.x, $0.y, $0.z] }, n: 3, semantic: .vertex) }
    public convenience init(normals: [SCNVector3]) { self.init(floats: normals.flatMap { [$0.x, $0.y, $0.z] }, n: 3, semantic: .normal) }
    public convenience init(textureCoordinates: [CGPoint]) {
        self.init(floats: textureCoordinates.flatMap { [Float($0.x), Float($0.y)] }, n: 2, semantic: .texcoord)
    }
    convenience init(floats: [Float], n: Int, semantic: Semantic) {
        let data = floats.withUnsafeBytes { Data($0) }
        self.init(data: data, semantic: semantic, vectorCount: floats.count / n, usesFloatComponents: true, componentsPerVector: n,
                  bytesPerComponent: 4, dataOffset: 0, dataStride: n * 4)
    }

    /// the vectors as floats (components missing: 0; normalized integers: 0…1)
    func _vectors(_ count: Int) -> [SIMD4<Float>] {
        var out = [SIMD4<Float>](repeating: SIMD4(0, 0, 0, 1), count: count)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for i in 0..<min(count, vectorCount) {
                let base = dataOffset + i * dataStride
                var v = SIMD4<Float>(0, 0, 0, 1)
                for c in 0..<min(componentsPerVector, 4) {
                    let o = base + c * bytesPerComponent
                    guard o + bytesPerComponent <= raw.count else { break }
                    var x: Float = 0
                    if usesFloatComponents {
                        switch bytesPerComponent {
                        case 8: x = Float(raw.loadUnaligned(fromByteOffset: o, as: Double.self))
                        case 2: x = Float(Float16(bitPattern: raw.loadUnaligned(fromByteOffset: o, as: UInt16.self)))
                        default: x = raw.loadUnaligned(fromByteOffset: o, as: Float.self)
                        }
                    } else {
                        switch bytesPerComponent {
                        case 1: x = Float(raw[o]) / (semantic == .color ? 255 : 1)
                        case 2: x = Float(raw.loadUnaligned(fromByteOffset: o, as: Int16.self))
                        default: x = Float(raw.loadUnaligned(fromByteOffset: o, as: Int32.self))
                        }
                    }
                    v[c] = x
                }
                out[i] = v
            }
        }
        return out
    }

    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(data, forKey: "data"); coder.encode(semantic.rawValue, forKey: "semantic"); coder.encode(vectorCount, forKey: "count")
        coder.encode(usesFloatComponents, forKey: "float"); coder.encode(componentsPerVector, forKey: "components")
        coder.encode(bytesPerComponent, forKey: "bytes"); coder.encode(dataOffset, forKey: "offset"); coder.encode(dataStride, forKey: "stride")
    }
    @objc public required init?(coder: NSCoder) {
        guard let d = coder.decodeObject(of: NSData.self, forKey: "data") as Data?,
              let s = coder.decodeObject(of: NSString.self, forKey: "semantic") as String? else { return nil }
        data = d; semantic = Semantic(s); vectorCount = coder.decodeInteger(forKey: "count"); usesFloatComponents = coder.decodeBool(forKey: "float")
        componentsPerVector = coder.decodeInteger(forKey: "components"); bytesPerComponent = coder.decodeInteger(forKey: "bytes")
        dataOffset = coder.decodeInteger(forKey: "offset"); dataStride = coder.decodeInteger(forKey: "stride")
        super.init()
    }
}

/// How vertices are joined: an index list and its primitive type.
@objc(SCNGeometryElement) open class SCNGeometryElement: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var data: Data
    @objc open private(set) var primitiveType: SCNGeometryPrimitiveType
    @objc open private(set) var primitiveCount: Int
    @objc open private(set) var bytesPerIndex: Int
    @objc open var primitiveRange = NSRange(location: NSNotFound, length: 0) { didSet { _SCNDirty.bump() } }
    @objc open var pointSize: CGFloat = 1
    @objc open var minimumPointScreenSpaceRadius: CGFloat = 1
    @objc open var maximumPointScreenSpaceRadius: CGFloat = 1
    @objc open var hasInterleavedIndicesChannels: Bool { false }
    @objc open var indicesChannelCount: Int { 1 }

    @objc public init(data: Data?, primitiveType type: SCNGeometryPrimitiveType, primitiveCount: Int, bytesPerIndex: Int) {
        self.data = data ?? Data(); primitiveType = type; self.primitiveCount = primitiveCount; self.bytesPerIndex = bytesPerIndex
        super.init()
    }
    public convenience init<IndexType: FixedWidthInteger>(indices: [IndexType], primitiveType: SCNGeometryPrimitiveType) {
        let count: Int = switch primitiveType {
        case .triangles: indices.count / 3
        case .triangleStrip: max(0, indices.count - 2)
        case .line: indices.count / 2
        case .point: indices.count
        case .polygon: 0
        }
        self.init(data: indices.withUnsafeBytes { Data($0) }, primitiveType: primitiveType, primitiveCount: count,
                  bytesPerIndex: MemoryLayout<IndexType>.size)
    }
    public convenience init(buffer: MTLBuffer, primitiveType: SCNGeometryPrimitiveType, primitiveCount: Int, bytesPerIndex: Int) {
        self.init(data: Data(bytes: buffer.contents(), count: buffer.length), primitiveType: primitiveType, primitiveCount: primitiveCount,
                  bytesPerIndex: bytesPerIndex)
    }

    func _index(_ raw: UnsafeRawBufferPointer, _ i: Int) -> UInt32 {
        let o = i * bytesPerIndex
        guard o + bytesPerIndex <= raw.count else { return 0 }
        switch bytesPerIndex {
        case 1: return UInt32(raw[o])
        case 2: return UInt32(raw.loadUnaligned(fromByteOffset: o, as: UInt16.self))
        default: return raw.loadUnaligned(fromByteOffset: o, as: UInt32.self)
        }
    }
    /// the indices to draw, with the Metal primitive (polygons become triangle fans)
    func _indices() -> (MTLPrimitiveType, [UInt32]) {
        data.withUnsafeBytes { raw -> (MTLPrimitiveType, [UInt32]) in
            var range = 0..<primitiveCount
            if primitiveRange.location != NSNotFound {
                range = max(0, primitiveRange.location)..<min(primitiveCount, primitiveRange.location + primitiveRange.length)
            }
            switch primitiveType {
            case .triangles: return (.triangle, (range.lowerBound * 3..<range.upperBound * 3).map { _index(raw, $0) })
            case .triangleStrip: return (.triangleStrip, (range.lowerBound..<(range.upperBound + 2)).map { _index(raw, $0) })
            case .line: return (.line, (range.lowerBound * 2..<range.upperBound * 2).map { _index(raw, $0) })
            case .point: return (.point, range.map { _index(raw, $0) })
            case .polygon:
                var out: [UInt32] = [], at = primitiveCount
                var counts: [Int] = []
                for p in 0..<primitiveCount { counts.append(Int(_index(raw, p))) }
                for (p, n) in counts.enumerated() {
                    if range.contains(p) && n >= 3 {
                        for k in 1..<(n - 1) { out += [_index(raw, at), _index(raw, at + k), _index(raw, at + k + 1)] }
                    }
                    at += n
                }
                return (.triangle, out)
            }
        }
    }

    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(data, forKey: "data"); coder.encode(primitiveType.rawValue, forKey: "type")
        coder.encode(primitiveCount, forKey: "count"); coder.encode(bytesPerIndex, forKey: "bytes")
    }
    @objc public required init?(coder: NSCoder) {
        data = coder.decodeObject(of: NSData.self, forKey: "data") as Data? ?? Data()
        primitiveType = SCNGeometryPrimitiveType(rawValue: coder.decodeInteger(forKey: "type")) ?? .triangles
        primitiveCount = coder.decodeInteger(forKey: "count"); bytesPerIndex = coder.decodeInteger(forKey: "bytes")
        super.init()
    }
}

/// The renderer's form of a geometry: interleaved vertices (position, normal, uv, colour) and index lists
final class _SCNMesh {
    static let stride = 12
    var vertices: [Float] = []
    var elements: [(type: MTLPrimitiveType, indices: [UInt32], pointSize: Float)] = []
    var hasColors = false
    var bounds = (min: SIMD3<Float>(repeating: 0), max: SIMD3<Float>(repeating: 0))
    var vertexBuffer: MTLBuffer?
    var indexBuffers: [MTLBuffer?] = []
    var count: Int { vertices.count / _SCNMesh.stride }
    func position(_ i: Int) -> SIMD3<Float> { let o = i * _SCNMesh.stride; return SIMD3(vertices[o], vertices[o + 1], vertices[o + 2]) }
    func uv(_ i: Int) -> SIMD2<Float> { let o = i * _SCNMesh.stride + 6; return SIMD2(vertices[o], vertices[o + 1]) }
}

/// A shape: vertex sources, elements and materials (element i uses material i modulo the count).
@objc(SCNGeometry) open class SCNGeometry: NSObject, NSCopying, NSSecureCoding, SCNBoundingVolume, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc public convenience init(sources: [SCNGeometrySource], elements: [SCNGeometryElement]?) {
        self.init()
        _sources = sources; _elements = elements ?? []
    }
    @objc open var name: String?
    @objc open var materials: [SCNMaterial] = [SCNMaterial()] { didSet { _SCNDirty.bump() } }
    @objc open var firstMaterial: SCNMaterial? {
        get { materials.first }
        set { if let m = newValue { if materials.isEmpty { materials = [m] } else { materials[0] = m } } else if !materials.isEmpty { materials.removeFirst() } }
    }
    @objc open var subdivisionLevel = 0
    @objc open var wantsAdaptiveSubdivision = true
    @objc open var levelsOfDetail: [SCNLevelOfDetail]?
    @objc open var edgeCreasesElement: SCNGeometryElement?
    @objc open var edgeCreasesSource: SCNGeometrySource?
    var _sources: [SCNGeometrySource] = [], _elements: [SCNGeometryElement] = []
    var _built = false, _mesh: _SCNMesh?
    var _box: (min: SCNVector3, max: SCNVector3)?

    /// built-in shapes make their sources and elements here
    func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) { (_sources, _elements) }
    func _invalidate() { _built = false; _mesh = nil; _SCNDirty.bump() }
    func _ensure() {
        if !_built, Swift.type(of: self) != SCNGeometry.self { (_sources, _elements) = _make() }
        _built = true
    }
    @objc(geometrySources) open var sources: [SCNGeometrySource] { _ensure(); return _sources }
    @objc(geometryElements) open var elements: [SCNGeometryElement] { _ensure(); return _elements }
    @objc(geometryElementCount) open var elementCount: Int { elements.count }
    @objc(geometryElementAtIndex:) open func element(at elementIndex: Int) -> SCNGeometryElement { elements[elementIndex] }
    open func sources(for semantic: SCNGeometrySource.Semantic) -> [SCNGeometrySource] { sources.filter { $0.semantic == semantic } }
    @objc open func material(named name: String) -> SCNMaterial? { materials.first { $0.name == name } }
    @objc(insertMaterial:atIndex:) open func insertMaterial(_ material: SCNMaterial, at index: Int) { materials.insert(material, at: min(index, materials.count)) }
    @objc(removeMaterialAtIndex:) open func removeMaterial(at index: Int) { if index < materials.count { materials.remove(at: index) } }
    @objc(replaceMaterialAtIndex:withMaterial:) open func replaceMaterial(at index: Int, with material: SCNMaterial) { if index < materials.count { materials[index] = material } }

    /// the mesh the renderer draws, made from the sources and elements
    var _renderMesh: _SCNMesh {
        if let _mesh { return _mesh }
        _ensure()
        let m = _SCNMesh()
        let pos = _sources.first { $0.semantic == .vertex }
        let n = pos?.vectorCount ?? 0
        let p = pos?._vectors(n) ?? []
        let normals = _sources.first { $0.semantic == .normal }?._vectors(n)
        let uvs = _sources.first { $0.semantic == .texcoord }?._vectors(n)
        let colorSource = _sources.first { $0.semantic == .color }
        let colors = colorSource?._vectors(n)
        m.hasColors = colors != nil
        m.vertices.reserveCapacity(n * _SCNMesh.stride)
        var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity)
        for i in 0..<n {
            let v = SIMD3(p[i].x, p[i].y, p[i].z)
            lo = simd_min(lo, v); hi = simd_max(hi, v)
            let nn = normals?[i] ?? SIMD4(0, 0, 1, 0)
            let t = uvs?[i] ?? SIMD4(0, 0, 0, 0)
            var c = colors?[i] ?? SIMD4(1, 1, 1, 1)
            if (colorSource?.componentsPerVector ?? 4) < 4 { c.w = 1 }
            m.vertices += [v.x, v.y, v.z, nn.x, nn.y, nn.z, t.x, t.y, c.x, c.y, c.z, c.w]
        }
        if n > 0 { m.bounds = (lo, hi) }
        for e in _elements {
            let (type, idx) = e._indices()
            m.elements.append((type, idx.filter { Int($0) < n }.count == idx.count ? idx : idx.map { Int($0) < n ? $0 : 0 }, Float(e.pointSize)))
        }
        _mesh = m
        return m
    }

    open var boundingBox: (min: SCNVector3, max: SCNVector3) {
        get {
            if let _box { return _box }
            let b = _renderMesh.bounds
            return (SCNVector3(b.min), SCNVector3(b.max))
        }
        set { _box = newValue }
    }
    open var boundingSphere: (center: SCNVector3, radius: Float) {
        let b = boundingBox
        let lo = SIMD3(b.min), hi = SIMD3(b.max)
        return (SCNVector3((lo + hi) / 2), simd_length(hi - lo) / 2)
    }

    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let g = (Swift.type(of: self) as NSObject.Type).init() as! SCNGeometry
        g._copyShape(from: self)
        g.name = name; g.materials = materials; g._sources = _sources; g._elements = _elements
        g._built = Swift.type(of: self) == SCNGeometry.self ? true : false
        g.subdivisionLevel = subdivisionLevel; g._box = _box
        return g
    }
    /// built-in shapes copy their parameters
    func _copyShape(from other: SCNGeometry) {}
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name"); coder.encode(sources, forKey: "sources"); coder.encode(elements, forKey: "elements")
        coder.encode(materials, forKey: "materials")
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        _sources = coder.decodeObject(of: [NSArray.self, SCNGeometrySource.self], forKey: "sources") as? [SCNGeometrySource] ?? []
        _elements = coder.decodeObject(of: [NSArray.self, SCNGeometryElement.self], forKey: "elements") as? [SCNGeometryElement] ?? []
        materials = coder.decodeObject(of: [NSArray.self, SCNMaterial.self], forKey: "materials") as? [SCNMaterial] ?? [SCNMaterial()]
        _built = true
    }
}

/// A geometry to use from a distance. Kept, not applied.
@objc(SCNLevelOfDetail) open class SCNLevelOfDetail: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var geometry: SCNGeometry?
    @objc open private(set) var screenSpaceRadius: CGFloat = 0
    @objc open private(set) var worldSpaceDistance: CGFloat = 0
    @objc public convenience init(geometry: SCNGeometry?, screenSpaceRadius radius: CGFloat) { self.init(); self.geometry = geometry; screenSpaceRadius = radius }
    @objc public convenience init(geometry: SCNGeometry?, worldSpaceDistance distance: CGFloat) { self.init(); self.geometry = geometry; worldSpaceDistance = distance }
    @objc open func copy(with zone: NSZone? = nil) -> Any { self }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public override init() { super.init() }
    @objc public required init?(coder: NSCoder) { super.init() }
}

// MARK: - built-in shapes

/// A builder of a shape's vertices and element groups
struct _SCNShape {
    var p: [SCNVector3] = [], n: [SCNVector3] = [], t: [CGPoint] = []
    var groups: [[UInt32]] = []
    mutating func vertex(_ pos: SIMD3<Float>, _ normal: SIMD3<Float>, _ u: Float, _ v: Float) -> UInt32 {
        p.append(SCNVector3(pos)); n.append(SCNVector3(simd_length(normal) > 0 ? simd_normalize(normal) : normal)); t.append(CGPoint(x: CGFloat(u), y: CGFloat(v)))
        return UInt32(p.count - 1)
    }
    /// a grid of (cols + 1) × (rows + 1) vertices from f(u, v) -> (position, normal), as triangles in a new group
    mutating func grid(_ cols: Int, _ rows: Int, flip: Bool = false, _ f: (Float, Float) -> (SIMD3<Float>, SIMD3<Float>)) {
        let cols = max(cols, 1), rows = max(rows, 1)
        var idx: [UInt32] = []
        let base = UInt32(p.count)
        for j in 0...rows {
            for i in 0...cols {
                let u = Float(i) / Float(cols), v = Float(j) / Float(rows)
                let (pos, nor) = f(u, v)
                _ = vertex(pos, nor, u, v)
            }
        }
        let w = UInt32(cols + 1)
        for j in 0..<UInt32(rows) {
            for i in 0..<UInt32(cols) {
                let a = base + j * w + i, b = a + 1, c = a + w, d = c + 1
                idx += flip ? [a, b, c, b, d, c] : [a, c, b, b, c, d]
            }
        }
        groups.append(idx)
    }
    /// a flat disc in the y = height plane, facing up or down
    mutating func disc(radius: Float, y: Float, up: Bool, segments: Int, inner: Float = 0) {
        let s = max(segments, 3)
        var idx: [UInt32] = []
        let ny: Float = up ? 1 : -1
        let base = UInt32(p.count)
        for i in 0...s {
            let a = Float(i) / Float(s) * 2 * .pi
            let (x, z) = (sinf(a), cosf(a))
            _ = vertex(SIMD3(x * radius, y, z * radius), SIMD3(0, ny, 0), 0.5 + x * 0.5, 0.5 - z * ny * 0.5)
            _ = vertex(SIMD3(x * inner, y, z * inner), SIMD3(0, ny, 0), 0.5 + x * 0.5 * inner / max(radius, 1e-6), 0.5 - z * ny * 0.5 * inner / max(radius, 1e-6))
        }
        for i in 0..<UInt32(s) {
            let o0 = base + i * 2, i0 = o0 + 1, o1 = o0 + 2, i1 = o0 + 3
            idx += up ? [o0, o1, i0, i0, o1, i1] : [o0, i0, o1, i0, i1, o1]
        }
        groups.append(idx)
    }
    func make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        ([SCNGeometrySource(vertices: p), SCNGeometrySource(normals: n), SCNGeometrySource(textureCoordinates: t)],
         groups.map { SCNGeometryElement(indices: $0, primitiveType: .triangles) })
    }
}

/// A box centred on the origin. Its six faces are elements: front, right, back, left, top, bottom.
@objc(SCNBox) open class SCNBox: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(width: CGFloat, height: CGFloat, length: CGFloat, chamferRadius: CGFloat) {
        self.init(); self.width = width; self.height = height; self.length = length; self.chamferRadius = chamferRadius
    }
    @objc open var width: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var height: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var length: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var chamferRadius: CGFloat = 0 { didSet { _invalidate() } }
    @objc open var widthSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var heightSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var lengthSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var chamferSegmentCount = 5 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        let h = SIMD3(Float(width), Float(height), Float(length)) / 2
        var s = _SCNShape()
        // normal, u direction, v direction (down the face), segments
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, Int, Int)] = [
            (SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, -1, 0), widthSegmentCount, heightSegmentCount),
            (SIMD3(1, 0, 0), SIMD3(0, 0, -1), SIMD3(0, -1, 0), lengthSegmentCount, heightSegmentCount),
            (SIMD3(0, 0, -1), SIMD3(-1, 0, 0), SIMD3(0, -1, 0), widthSegmentCount, heightSegmentCount),
            (SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, -1, 0), lengthSegmentCount, heightSegmentCount),
            (SIMD3(0, 1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, 1), widthSegmentCount, lengthSegmentCount),
            (SIMD3(0, -1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, -1), widthSegmentCount, lengthSegmentCount),
        ]
        for (nrm, u, v, cu, cv) in faces {
            s.grid(cu, cv) { a, b in ((nrm + u * (a * 2 - 1) + v * (b * 2 - 1)) * h, nrm) }
        }
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNBox else { return }
        width = o.width; height = o.height; length = o.length; chamferRadius = o.chamferRadius
        widthSegmentCount = o.widthSegmentCount; heightSegmentCount = o.heightSegmentCount; lengthSegmentCount = o.lengthSegmentCount
    }
}

/// A sphere centred on the origin.
@objc(SCNSphere) open class SCNSphere: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(radius: CGFloat) { self.init(); self.radius = radius }
    @objc open var radius: CGFloat = 0.5 { didSet { _invalidate() } }
    @objc open var isGeodesic = false { didSet { _invalidate() } }
    @objc open var segmentCount = 48 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let r = Float(radius), seg = max(segmentCount, 3)
        s.grid(seg, max(seg / 2, 2)) { u, v in
            let theta = u * 2 * .pi, phi = v * .pi
            let n = SIMD3(-sinf(phi) * sinf(theta), cosf(phi), -sinf(phi) * cosf(theta))
            return (n * r, n)
        }
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNSphere else { return }
        radius = o.radius; isGeodesic = o.isGeodesic; segmentCount = o.segmentCount
    }
}

/// A rectangle in the xy plane, facing +z.
@objc(SCNPlane) open class SCNPlane: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(width: CGFloat, height: CGFloat) { self.init(); self.width = width; self.height = height }
    @objc open var width: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var height: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var widthSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var heightSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var cornerRadius: CGFloat = 0 { didSet { _invalidate() } }
    @objc open var cornerSegmentCount = 10 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let w = Float(width), h = Float(height)
        s.grid(widthSegmentCount, heightSegmentCount) { u, v in (SIMD3((u - 0.5) * w, (0.5 - v) * h, 0), SIMD3(0, 0, 1)) }
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNPlane else { return }
        width = o.width; height = o.height; widthSegmentCount = o.widthSegmentCount; heightSegmentCount = o.heightSegmentCount; cornerRadius = o.cornerRadius
    }
}

/// A pyramid: its base centred on the origin in the xz plane, its apex at y = height. Elements: front, right, back,
/// left, bottom.
@objc(SCNPyramid) open class SCNPyramid: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(width: CGFloat, height: CGFloat, length: CGFloat) {
        self.init(); self.width = width; self.height = height; self.length = length
    }
    @objc open var width: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var height: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var length: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var widthSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var heightSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var lengthSegmentCount = 1 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let w = Float(width) / 2, h = Float(height), l = Float(length) / 2
        let apex = SIMD3<Float>(0, h, 0)
        let base: [SIMD3<Float>] = [SIMD3(-w, 0, l), SIMD3(w, 0, l), SIMD3(w, 0, -l), SIMD3(-w, 0, -l)]
        for i in 0..<4 {
            let a = base[i], b = base[(i + 1) % 4]
            let n = simd_cross(b - a, apex - a)
            let ia = s.vertex(a, n, 0, 1), ib = s.vertex(b, n, 1, 1), ic = s.vertex(apex, n, 0.5, 0)
            s.groups.append([ia, ib, ic])
        }
        let down = SIMD3<Float>(0, -1, 0)
        let i0 = s.vertex(base[0], down, 0, 0), i1 = s.vertex(base[1], down, 1, 0), i2 = s.vertex(base[2], down, 1, 1), i3 = s.vertex(base[3], down, 0, 1)
        s.groups.append([i0, i2, i1, i0, i3, i2])
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNPyramid else { return }
        width = o.width; height = o.height; length = o.length
    }
}

/// A cylinder along the y axis, centred on the origin. Elements: side, top, bottom.
@objc(SCNCylinder) open class SCNCylinder: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(radius: CGFloat, height: CGFloat) { self.init(); self.radius = radius; self.height = height }
    @objc open var radius: CGFloat = 0.5 { didSet { _invalidate() } }
    @objc open var height: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var radialSegmentCount = 48 { didSet { _invalidate() } }
    @objc open var heightSegmentCount = 1 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let r = Float(radius), h = Float(height)
        s.grid(radialSegmentCount, heightSegmentCount) { u, v in
            let a = u * 2 * .pi
            let n = SIMD3(sinf(a), 0, cosf(a))
            return (SIMD3(n.x * r, (0.5 - v) * h, n.z * r), n)
        }
        s.disc(radius: r, y: h / 2, up: true, segments: radialSegmentCount)
        s.disc(radius: r, y: -h / 2, up: false, segments: radialSegmentCount)
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNCylinder else { return }
        radius = o.radius; height = o.height; radialSegmentCount = o.radialSegmentCount
    }
}

/// A cone (or frustum) along the y axis, centred on the origin. Elements: side, bottom, then top when it has one.
@objc(SCNCone) open class SCNCone: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(topRadius: CGFloat, bottomRadius: CGFloat, height: CGFloat) {
        self.init(); self.topRadius = topRadius; self.bottomRadius = bottomRadius; self.height = height
    }
    @objc open var topRadius: CGFloat = 0 { didSet { _invalidate() } }
    @objc open var bottomRadius: CGFloat = 0.5 { didSet { _invalidate() } }
    @objc open var height: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var radialSegmentCount = 48 { didSet { _invalidate() } }
    @objc open var heightSegmentCount = 1 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let rt = Float(topRadius), rb = Float(bottomRadius), h = Float(height)
        let slope = (rb - rt) / max(h, 1e-6)
        s.grid(radialSegmentCount, heightSegmentCount) { u, v in
            let a = u * 2 * .pi
            let r = rt + (rb - rt) * v
            return (SIMD3(sinf(a) * r, (0.5 - v) * h, cosf(a) * r), SIMD3(sinf(a), slope, cosf(a)))
        }
        s.disc(radius: rb, y: -h / 2, up: false, segments: radialSegmentCount)
        if rt > 0 { s.disc(radius: rt, y: h / 2, up: true, segments: radialSegmentCount) }
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNCone else { return }
        topRadius = o.topRadius; bottomRadius = o.bottomRadius; height = o.height; radialSegmentCount = o.radialSegmentCount
    }
}

/// A ring in the xz plane, centred on the origin.
@objc(SCNTorus) open class SCNTorus: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(ringRadius: CGFloat, pipeRadius: CGFloat) { self.init(); self.ringRadius = ringRadius; self.pipeRadius = pipeRadius }
    @objc open var ringRadius: CGFloat = 0.5 { didSet { _invalidate() } }
    @objc open var pipeRadius: CGFloat = 0.25 { didSet { _invalidate() } }
    @objc open var ringSegmentCount = 48 { didSet { _invalidate() } }
    @objc open var pipeSegmentCount = 24 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let R = Float(ringRadius), r = Float(pipeRadius)
        s.grid(ringSegmentCount, pipeSegmentCount, flip: true) { u, v in
            let a = u * 2 * .pi, b = v * 2 * .pi
            let dir = SIMD3(sinf(a), 0, cosf(a))
            let n = dir * cosf(b) + SIMD3(0, sinf(b), 0)
            return (dir * R + n * r, n)
        }
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNTorus else { return }
        ringRadius = o.ringRadius; pipeRadius = o.pipeRadius; ringSegmentCount = o.ringSegmentCount; pipeSegmentCount = o.pipeSegmentCount
    }
}

/// A tube along the y axis, centred on the origin. Elements: outside, inside, top, bottom.
@objc(SCNTube) open class SCNTube: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(innerRadius: CGFloat, outerRadius: CGFloat, height: CGFloat) {
        self.init(); self.innerRadius = innerRadius; self.outerRadius = outerRadius; self.height = height
    }
    @objc open var innerRadius: CGFloat = 0.25 { didSet { _invalidate() } }
    @objc open var outerRadius: CGFloat = 0.5 { didSet { _invalidate() } }
    @objc open var height: CGFloat = 1 { didSet { _invalidate() } }
    @objc open var radialSegmentCount = 48 { didSet { _invalidate() } }
    @objc open var heightSegmentCount = 1 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let ri = Float(innerRadius), ro = Float(outerRadius), h = Float(height)
        s.grid(radialSegmentCount, heightSegmentCount) { u, v in
            let a = u * 2 * .pi
            let n = SIMD3(sinf(a), 0, cosf(a))
            return (SIMD3(n.x * ro, (0.5 - v) * h, n.z * ro), n)
        }
        s.grid(radialSegmentCount, heightSegmentCount, flip: true) { u, v in
            let a = u * 2 * .pi
            let n = SIMD3(sinf(a), 0, cosf(a))
            return (SIMD3(n.x * ri, (0.5 - v) * h, n.z * ri), -n)
        }
        s.disc(radius: ro, y: h / 2, up: true, segments: radialSegmentCount, inner: ri)
        s.disc(radius: ro, y: -h / 2, up: false, segments: radialSegmentCount, inner: ri)
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNTube else { return }
        innerRadius = o.innerRadius; outerRadius = o.outerRadius; height = o.height; radialSegmentCount = o.radialSegmentCount
    }
}

/// A capsule along the y axis: `height` from end to end, centred on the origin.
@objc(SCNCapsule) open class SCNCapsule: SCNGeometry, @unchecked Sendable {
    @objc public convenience init(capRadius: CGFloat, height: CGFloat) { self.init(); self.capRadius = capRadius; self.height = height }
    @objc open var capRadius: CGFloat = 0.5 { didSet { _invalidate() } }
    @objc open var height: CGFloat = 2 { didSet { _invalidate() } }
    @objc open var radialSegmentCount = 48 { didSet { _invalidate() } }
    @objc open var heightSegmentCount = 1 { didSet { _invalidate() } }
    @objc open var capSegmentCount = 24 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let r = Float(capRadius), half = max(Float(height) / 2 - r, 0)
        let caps = max(capSegmentCount, 2)
        let rows = caps * 2 + 1
        s.grid(radialSegmentCount, rows) { u, v in
            let a = u * 2 * .pi
            // the rows: the top cap, one row of side, the bottom cap
            let row = v * Float(rows)
            let phi: Float, y: Float
            if row <= Float(caps) { phi = row / Float(caps) * .pi / 2; y = half } else if row >= Float(caps + 1) {
                phi = .pi / 2 + (row - Float(caps + 1)) / Float(caps) * .pi / 2; y = -half
            } else { phi = .pi / 2; y = half - (row - Float(caps)) * 2 * half }
            let n = SIMD3(sinf(phi) * sinf(a), cosf(phi), sinf(phi) * cosf(a))
            return (n * r + SIMD3(0, y, 0), n)
        }
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNCapsule else { return }
        capRadius = o.capRadius; height = o.height; radialSegmentCount = o.radialSegmentCount
    }
}

/// A floor: the y = 0 plane, facing +y (width / length 0: endless, drawn 1000 units across). Adapted: no reflection.
@objc(SCNFloor) open class SCNFloor: SCNGeometry, @unchecked Sendable {
    @objc open var reflectivity: CGFloat = 0.25
    @objc open var reflectionFalloffStart: CGFloat = 0
    @objc open var reflectionFalloffEnd: CGFloat = 0
    @objc open var reflectionCategoryBitMask = -1
    @objc open var reflectionResolutionScaleFactor: CGFloat = 0.5
    @objc open var width: CGFloat = 0 { didSet { _invalidate() } }
    @objc open var length: CGFloat = 0 { didSet { _invalidate() } }
    override func _make() -> ([SCNGeometrySource], [SCNGeometryElement]) {
        var s = _SCNShape()
        let w = Float(width > 0 ? width : 1000), l = Float(length > 0 ? length : 1000)
        let base = UInt32(0)
        _ = s.vertex(SIMD3(-w / 2, 0, -l / 2), SIMD3(0, 1, 0), 0, 0)
        _ = s.vertex(SIMD3(w / 2, 0, -l / 2), SIMD3(0, 1, 0), w, 0)
        _ = s.vertex(SIMD3(-w / 2, 0, l / 2), SIMD3(0, 1, 0), 0, l)
        _ = s.vertex(SIMD3(w / 2, 0, l / 2), SIMD3(0, 1, 0), w, l)
        s.groups.append([base, base + 2, base + 1, base + 1, base + 2, base + 3])
        return s.make()
    }
    override func _copyShape(from o: SCNGeometry) {
        guard let o = o as? SCNFloor else { return }
        reflectivity = o.reflectivity; width = o.width; length = o.length
    }
}
