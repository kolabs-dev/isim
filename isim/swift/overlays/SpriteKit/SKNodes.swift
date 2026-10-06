// isim SpriteKit: more node types (camera, crop, effect, field, tile map, reference, light), shaders (stored, not
// run: isim renders without Metal), constraints and ranges.
import Foundation
import isim_host

// MARK: - Camera

open class SKCameraNode: SKNode {
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    /// the scene rectangle the camera shows (in the camera's parent coordinates)
    func viewRect() -> CGRect? {
        guard let s = scene, let v = s.view else { return nil }
        let inv = v.sceneToView.inverted()
        let corners = [CGPoint.zero, CGPoint(x: v.bounds.width, y: 0), CGPoint(x: 0, y: v.bounds.height), CGPoint(x: v.bounds.width, y: v.bounds.height)].map { $0.applying(inv) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
    open func contains(_ node: SKNode) -> Bool {
        guard let r = viewRect(), let s = scene else { return false }
        let f = node.calculateAccumulatedFrame()
        let sf = node.parent.map { p in p === s ? f : f.applying(p.sceneTransform) } ?? f
        return r.intersects(sf)
    }
    open func containedNodeSet() -> Set<SKNode> {
        guard let s = scene else { return [] }
        return Set(s.descendants().filter { !($0 is SKCameraNode) && contains($0) })
    }
}

// MARK: - Effect & crop nodes

open class SKEffectNode: SKNode {
    open var shouldEnableEffects = false
    open var shouldRasterize = false
    open var shouldCenterFilter = true
    open var blendMode: SKBlendMode = .alpha
    open var shader: SKShader?
    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let c = coder as? _SKCoder { shouldEnableEffects = c.bool("shouldEnableEffects") ?? false; shouldRasterize = c.bool("shouldRasterize") ?? false }
    }
}

open class SKCropNode: SKNode {
    /// children are drawn only where the mask node's content is opaque
    open var maskNode: SKNode?
    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let c = coder as? _SKCoder, let u = c.coder(forKey: "maskNode")?.uid { maskNode = c.node(uid: u) }
    }
}

// MARK: - Shaders and lights (stored; isim has no GPU shading or lighting)

public enum SKUniformType: Int, Sendable { case none, float, floatVector2, floatVector3, floatVector4, floatMatrix2, floatMatrix3, floatMatrix4, texture }
public enum SKAttributeType: Int, Sendable { case none, float, vectorFloat2, vectorFloat3, vectorFloat4, halfFloat, vectorHalfFloat2, vectorHalfFloat3, vectorHalfFloat4 }

open class SKUniform: NSObject {
    open var name: String
    open var uniformType: SKUniformType = .none
    open var textureValue: SKTexture?
    open var floatValue: Float = 0
    open var vectorFloat2Value: vector_float2 = .zero
    open var vectorFloat3Value: vector_float3 = .zero
    open var vectorFloat4Value: vector_float4 = .zero
    public init(name: String) { self.name = name }
    public convenience init(name: String, float value: Float) { self.init(name: name); floatValue = value; uniformType = .float }
    public convenience init(name: String, texture: SKTexture?) { self.init(name: name); textureValue = texture; uniformType = .texture }
    public convenience init(name: String, vectorFloat2 v: vector_float2) { self.init(name: name); vectorFloat2Value = v; uniformType = .floatVector2 }
    public convenience init(name: String, vectorFloat3 v: vector_float3) { self.init(name: name); vectorFloat3Value = v; uniformType = .floatVector3 }
    public convenience init(name: String, vectorFloat4 v: vector_float4) { self.init(name: name); vectorFloat4Value = v; uniformType = .floatVector4 }
}

open class SKAttribute: NSObject {
    open var name: String
    open var type: SKAttributeType
    public init(name: String, type: SKAttributeType) { self.name = name; self.type = type }
}

open class SKAttributeValue: NSObject {
    open var floatValue: Float = 0
    open var vectorFloat2Value: vector_float2 = .zero
    open var vectorFloat3Value: vector_float3 = .zero
    open var vectorFloat4Value: vector_float4 = .zero
    public override init() { super.init() }
    public convenience init(float v: Float) { self.init(); floatValue = v }
    public convenience init(vectorFloat2 v: vector_float2) { self.init(); vectorFloat2Value = v }
    public convenience init(vectorFloat3 v: vector_float3) { self.init(); vectorFloat3Value = v }
    public convenience init(vectorFloat4 v: vector_float4) { self.init(); vectorFloat4Value = v }
}

/// Custom fragment shaders are accepted and stored but not executed: isim draws SpriteKit with cairo, not Metal.
open class SKShader: NSObject {
    open var source: String?
    open var uniforms: [SKUniform] = []
    open var attributes: [SKAttribute] = []
    public override init() { super.init() }
    public convenience init(source: String) { self.init(); self.source = source; Self.note() }
    public convenience init(source: String, uniforms: [SKUniform]) { self.init(source: source); self.uniforms = uniforms }
    public convenience init(fileNamed name: String) {
        self.init()
        let n = name as NSString
        if let p = Bundle.main.path(forResource: n.deletingPathExtension, ofType: n.pathExtension.isEmpty ? "fsh" : n.pathExtension) {
            source = try? String(contentsOfFile: p, encoding: .utf8)
        }
        Self.note()
    }
    static var noted = false
    static func note() { if !noted { noted = true; NSLog("isim SpriteKit: SKShader programs are not run on isim (no GPU rendering); nodes draw without them") } }
    open func addUniform(_ u: SKUniform) { uniforms.append(u) }
    open func uniformNamed(_ name: String) -> SKUniform? { uniforms.first { $0.name == name } }
    open func removeUniformNamed(_ name: String) { uniforms.removeAll { $0.name == name } }
    open override func copy() -> Any { let s = SKShader(); s.source = source; s.uniforms = uniforms; s.attributes = attributes; return s }
}

/// Lights are stored but do not light or shadow sprites on isim.
open class SKLightNode: SKNode {
    open var isEnabled = true
    open var lightColor: UIColor = .white
    open var ambientColor: UIColor = .black
    open var shadowColor: UIColor = .clear
    open var falloff: CGFloat = 1
    open var categoryBitMask: UInt32 = 1
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
}

// MARK: - Fields

public typealias SKFieldForceEvaluator = (vector_float3, vector_float3, Float, Float, TimeInterval) -> vector_float3

open class SKRegion: NSObject {
    let test: (CGPoint) -> Bool
    open private(set) var path: CGPath?
    init(test: @escaping (CGPoint) -> Bool, path: CGPath?) { self.test = test; self.path = path }
    public convenience init(radius: Float) {
        let r = CGFloat(radius)
        self.init(test: { _len($0) <= r }, path: CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil))
    }
    public convenience init(size: CGSize) {
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        self.init(test: { rect.contains($0) }, path: CGPath(rect: rect, transform: nil))
    }
    public convenience init(path: CGPath) {
        let polys = _pathPoints(path)
        self.init(test: { p in polys.contains { _pointInPolygon(p, $0) } }, path: path)
    }
    open class func infinite() -> SKRegion { SKRegion(test: { _ in true }, path: nil) }
    open func inverse() -> SKRegion { let t = test; return SKRegion(test: { !t($0) }, path: nil) }
    open func byUnion(with r: SKRegion) -> SKRegion { let a = test, b = r.test; return SKRegion(test: { a($0) || b($0) }, path: nil) }
    open func byDifference(from r: SKRegion) -> SKRegion { let a = test, b = r.test; return SKRegion(test: { a($0) && !b($0) }, path: nil) }
    open func byIntersection(with r: SKRegion) -> SKRegion { let a = test, b = r.test; return SKRegion(test: { a($0) && b($0) }, path: nil) }
    open func contains(_ p: CGPoint) -> Bool { test(p) }
    open override func copy() -> Any { self }
}

func _pointInPolygon(_ p: CGPoint, _ poly: [CGPoint]) -> Bool {
    var inside = false
    var j = poly.count - 1
    for i in 0..<poly.count {
        let a = poly[i], b = poly[j]
        if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
        j = i
    }
    return inside
}

open class SKFieldNode: SKNode {
    enum Kind { case linearGravity, radialGravity, spring, drag, vortex, velocity, noise, turbulence, electric, magnetic, custom }
    var kind: Kind = .radialGravity
    var evaluator: SKFieldForceEvaluator?
    open var region: SKRegion?
    open var minimumRadius: Float = 0
    open var isEnabled = true
    open var isExclusive = false
    open var strength: Float = 1
    open var falloff: Float = 0
    open var animationSpeed: Float = 1
    open var smoothness: Float = 0
    open var direction: vector_float3 = vector_float3(0, 0, 0)
    open var texture: SKTexture?
    open var categoryBitMask: UInt32 = 0xFFFF_FFFF

    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    convenience init(kind: Kind) { self.init(); self.kind = kind }

    open class func dragField() -> SKFieldNode { SKFieldNode(kind: .drag) }
    open class func vortexField() -> SKFieldNode { SKFieldNode(kind: .vortex) }
    open class func radialGravityField() -> SKFieldNode { SKFieldNode(kind: .radialGravity) }
    open class func linearGravityField(withVector v: vector_float3) -> SKFieldNode { let f = SKFieldNode(kind: .linearGravity); f.direction = v; return f }
    open class func velocityField(withVector v: vector_float3) -> SKFieldNode { let f = SKFieldNode(kind: .velocity); f.direction = v; return f }
    open class func velocityField(with texture: SKTexture) -> SKFieldNode { let f = SKFieldNode(kind: .velocity); f.texture = texture; return f }
    open class func noiseField(withSmoothness s: CGFloat, animationSpeed a: CGFloat) -> SKFieldNode {
        let f = SKFieldNode(kind: .noise); f.smoothness = Float(s); f.animationSpeed = Float(a); return f
    }
    open class func turbulenceField(withSmoothness s: CGFloat, animationSpeed a: CGFloat) -> SKFieldNode {
        let f = SKFieldNode(kind: .turbulence); f.smoothness = Float(s); f.animationSpeed = Float(a); return f
    }
    open class func springField() -> SKFieldNode { SKFieldNode(kind: .spring) }
    open class func electricField() -> SKFieldNode { SKFieldNode(kind: .electric) }
    open class func magneticField() -> SKFieldNode { SKFieldNode(kind: .magnetic) }
    open class func customField(evaluationBlock block: @escaping SKFieldForceEvaluator) -> SKFieldNode {
        let f = SKFieldNode(kind: .custom); f.evaluator = block; return f
    }

    /// field origin and rotation in scene space
    var placement: (CGPoint, CGFloat) {
        guard let p = parent else { return (position, zRotation) }
        let t = p is SKScene ? CGAffineTransform.identity : p.sceneTransform
        return (position.applying(t), zRotation + atan2(t.b, t.a))
    }
    func regionContains(_ scenePoint: CGPoint) -> Bool {
        guard let region else { return true }
        let (o, a) = placement
        return region.contains(_rot(_sub(scenePoint, o), cos(-a), sin(-a)))
    }
    /// force on a body, internal units (kg * points / s^2)
    func force(on b: SKPhysicsBody) -> CGPoint {
        guard regionContains(b.com) else { return .zero }
        let (o, a) = placement
        let d = _sub(b.com, o)                                   // points
        let rm = max(_len(d) / _ptm, CGFloat(minimumRadius) / _ptm, 0.01)   // meters
        let fall = falloff != 0 ? 1 / pow(rm, CGFloat(falloff)) : 1
        let s = CGFloat(strength), m = b.mass, u = _norm(d)
        let v = CGPoint(x: b.velocity.dx / _ptm, y: b.velocity.dy / _ptm)   // m/s
        var accel = CGPoint.zero, force = CGPoint.zero                    // m/s^2, N
        switch kind {
        case .linearGravity:
            accel = _rot(CGPoint(x: CGFloat(direction.x), y: CGFloat(direction.y)), cos(a), sin(a))
            accel = _mul(accel, s * fall)
        case .radialGravity: accel = _mul(u, -9.8 * s * fall)
        case .spring: force = _mul(d, -s / _ptm)
        case .drag: force = _mul(v, -s * fall)
        case .vortex: force = _mul(CGPoint(x: -u.y, y: u.x), s * fall)
        case .velocity:
            let target = _mul(_rot(CGPoint(x: CGFloat(direction.x), y: CGFloat(direction.y)), cos(a), sin(a)), s)
            accel = _mul(_sub(target, v), 10)
        case .noise, .turbulence:
            let t = CGFloat(ProcessInfo.processInfo.systemUptime) * CGFloat(animationSpeed)
            let k = 1 / max(0.05, CGFloat(1 - smoothness)) * 0.02
            let n = CGPoint(x: sin(b.com.y * k + t * 1.3) + sin(b.com.x * k * 0.7 - t), y: cos(b.com.x * k + t * 0.9) + cos(b.com.y * k * 1.3 + t))
            force = _mul(n, s * fall * (kind == .turbulence ? _len(v) : 1))
        case .electric: force = _mul(u, s * b.charge * fall)
        case .magnetic: force = _mul(CGPoint(x: v.y, y: -v.x), s * b.charge * fall)
        case .custom:
            guard let e = evaluator else { return .zero }
            let r = e(vector_float3(Float(d.x), Float(d.y), 0), vector_float3(Float(b.velocity.dx), Float(b.velocity.dy), 0),
                      Float(m), Float(b.charge), 1.0 / 60)
            force = CGPoint(x: CGFloat(r.x), y: CGFloat(r.y))
        }
        return _mul(_add(_mul(accel, m), force), _ptm)
    }
}

// MARK: - Ranges & constraints

open class SKRange: NSObject {
    open var lowerLimit: CGFloat
    open var upperLimit: CGFloat
    public init(lowerLimit lower: CGFloat, upperLimit upper: CGFloat) { lowerLimit = lower; upperLimit = upper }
    public convenience init(lowerLimit lower: CGFloat) { self.init(lowerLimit: lower, upperLimit: .greatestFiniteMagnitude) }
    public convenience init(upperLimit upper: CGFloat) { self.init(lowerLimit: -.greatestFiniteMagnitude, upperLimit: upper) }
    public convenience init(constantValue v: CGFloat) { self.init(lowerLimit: v, upperLimit: v) }
    public convenience init(value v: CGFloat, variance: CGFloat) { self.init(lowerLimit: v - variance, upperLimit: v + variance) }
    open class func withNoLimits() -> SKRange { SKRange(lowerLimit: -.greatestFiniteMagnitude, upperLimit: .greatestFiniteMagnitude) }
    open override func copy() -> Any { SKRange(lowerLimit: lowerLimit, upperLimit: upperLimit) }
    func clamp(_ v: CGFloat) -> CGFloat { min(max(v, lowerLimit), upperLimit) }
}

open class SKConstraint: NSObject {
    open var enabled = true
    open var referenceNode: SKNode?
    let apply: (SKConstraint, SKNode) -> Void
    init(_ apply: @escaping (SKConstraint, SKNode) -> Void) { self.apply = apply }
    open override func copy() -> Any { let c = SKConstraint(apply); c.enabled = enabled; c.referenceNode = referenceNode; return c }

    /// a point in `node`'s parent coordinates from `ref` space (nil = scene/parent space)
    static func toParent(_ p: CGPoint, of node: SKNode, from ref: SKNode?) -> CGPoint {
        guard let ref, let parent = node.parent else { return p }
        return parent.convert(p, from: ref)
    }
    static func fromParent(_ p: CGPoint, of node: SKNode, to ref: SKNode?) -> CGPoint {
        guard let ref, let parent = node.parent else { return p }
        return parent.convert(p, to: ref)
    }

    open class func positionX(_ range: SKRange) -> SKConstraint { positionX(range, y: SKRange.withNoLimits()) }
    open class func positionY(_ range: SKRange) -> SKConstraint { positionX(SKRange.withNoLimits(), y: range) }
    open class func positionX(_ xr: SKRange, y yr: SKRange) -> SKConstraint {
        SKConstraint { c, n in
            var p = fromParent(n.position, of: n, to: c.referenceNode)
            p.x = xr.clamp(p.x); p.y = yr.clamp(p.y)
            n.position = toParent(p, of: n, from: c.referenceNode)
        }
    }
    open class func zRotation(_ range: SKRange) -> SKConstraint { SKConstraint { _, n in n.zRotation = range.clamp(n.zRotation) } }
    open class func scaleX(_ range: SKRange) -> SKConstraint { SKConstraint { _, n in n.xScale = range.clamp(n.xScale) } }
    open class func scaleY(_ range: SKRange) -> SKConstraint { SKConstraint { _, n in n.yScale = range.clamp(n.yScale) } }
    open class func scaleX(_ xr: SKRange, y yr: SKRange) -> SKConstraint { SKConstraint { _, n in n.xScale = xr.clamp(n.xScale); n.yScale = yr.clamp(n.yScale) } }

    open class func distance(_ range: SKRange, to node: SKNode) -> SKConstraint { distance(range, to: .zero, in: node) }
    open class func distance(_ range: SKRange, to point: CGPoint) -> SKConstraint {
        SKConstraint { c, n in clampDistance(n, target: toParent(point, of: n, from: c.referenceNode), range) }
    }
    open class func distance(_ range: SKRange, to point: CGPoint, in node: SKNode) -> SKConstraint {
        SKConstraint { _, n in
            guard let parent = n.parent, node.scene != nil else { return }
            clampDistance(n, target: parent.convert(point, from: node), range)
        }
    }
    static func clampDistance(_ n: SKNode, target: CGPoint, _ range: SKRange) {
        let d = _sub(n.position, target), l = _len(d)
        let c = range.clamp(l)
        if abs(c - l) < 1e-9 { return }
        n.position = _add(target, _mul(l > 1e-9 ? _mul(d, 1 / l) : CGPoint(x: 1, y: 0), c))
    }

    open class func orient(to node: SKNode, offset: SKRange) -> SKConstraint { orient(to: .zero, in: node, offset: offset) }
    open class func orient(to point: CGPoint, offset: SKRange) -> SKConstraint {
        SKConstraint { c, n in orient(n, toward: toParent(point, of: n, from: c.referenceNode), offset) }
    }
    open class func orient(to point: CGPoint, in node: SKNode, offset: SKRange) -> SKConstraint {
        SKConstraint { _, n in
            guard let parent = n.parent, node.scene != nil else { return }
            orient(n, toward: parent.convert(point, from: node), offset)
        }
    }
    static func orient(_ n: SKNode, toward t: CGPoint, _ offset: SKRange) {
        let d = _sub(t, n.position)
        guard _len(d) > 1e-9 else { return }
        let base = atan2(d.y, d.x)
        // keep the node's rotation within the offset range around the direction (constant 0 points the +x axis at it)
        var rel = atan2(sin(n.zRotation - base), cos(n.zRotation - base))
        rel = offset.clamp(rel)
        n.zRotation = base + rel
    }
}

/// Inverse-kinematics limits are stored; isim does not solve reach actions.
open class SKReachConstraints: NSObject {
    open var lowerAngleLimit: CGFloat
    open var upperAngleLimit: CGFloat
    public init(lowerAngleLimit: CGFloat, upperAngleLimit: CGFloat) { self.lowerAngleLimit = lowerAngleLimit; self.upperAngleLimit = upperAngleLimit }
}

// MARK: - Reference node

open class SKReferenceNode: SKNode {
    var fileName: String?
    var fileURL: URL?
    public init(fileNamed name: String?) { fileName = name; super.init(); resolve() }
    public init(url: URL?) { fileURL = url; super.init(); resolve() }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let c = coder as? _SKCoder, let n = c.string("fileName") ?? c.string("referenceFileName") { fileName = n; resolve() }
    }
    open func didLoad(_ node: SKNode?) {}
    open func resolve() {
        var loaded: SKNode?
        if let fileName { loaded = SKNode(fileNamed: fileName) }
        else if let fileURL { loaded = SKNode(fileNamed: fileURL.deletingPathExtension().lastPathComponent) }
        if let loaded {
            removeAllChildren()
            for c in loaded.children { c.removeFromParent(); addChild(c) }
        }
        didLoad(loaded)
    }
}

// MARK: - Tile maps

public enum SKTileSetType: UInt, Sendable { case grid = 0, isometric, hexagonalFlat, hexagonalPointy }
public enum SKTileAdjacencyMask: UInt, Sendable { case adjacencyAll = 255 }
public enum SKTileDefinitionRotation: UInt, Sendable { case rotation0 = 0, rotation90, rotation180, rotation270 }

open class SKTileDefinition: NSObject {
    open var textures: [SKTexture]
    open var normalTextures: [SKTexture] = []
    open var userData: NSMutableDictionary?
    open var name: String?
    open var size: CGSize
    open var timePerFrame: CGFloat = 0
    open var placementWeight: Int = 1
    open var rotation: SKTileDefinitionRotation = .rotation0
    open var flipVertically = false
    open var flipHorizontally = false
    public init(texture: SKTexture) { textures = [texture]; size = texture.size() }
    public init(texture: SKTexture, size: CGSize) { textures = [texture]; self.size = size }
    public init(texture: SKTexture, normalTexture: SKTexture, size: CGSize) { textures = [texture]; normalTextures = [normalTexture]; self.size = size }
    public init(textures: [SKTexture], size: CGSize, timePerFrame: CGFloat) { self.textures = textures; self.size = size; self.timePerFrame = timePerFrame }
    public init(textures: [SKTexture], normalTextures: [SKTexture], size: CGSize, timePerFrame: CGFloat) {
        self.textures = textures; self.normalTextures = normalTextures; self.size = size; self.timePerFrame = timePerFrame
    }
    open override func copy() -> Any { self }
}

open class SKTileGroupRule: NSObject {
    open var adjacency: SKTileAdjacencyMask
    open var tileDefinitions: [SKTileDefinition]
    open var name: String?
    public init(adjacency: SKTileAdjacencyMask, tileDefinitions: [SKTileDefinition]) { self.adjacency = adjacency; self.tileDefinitions = tileDefinitions }
}

open class SKTileGroup: NSObject {
    open var rules: [SKTileGroupRule]
    open var name: String?
    public init(tileDefinition: SKTileDefinition) { rules = [SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [tileDefinition])] }
    public init(rules: [SKTileGroupRule]) { self.rules = rules }
    open class func empty() -> SKTileGroup { SKTileGroup(rules: []) }
    /// the definition drawn for a cell: weighted pick, stable per cell
    func definition(forCell i: Int) -> SKTileDefinition? {
        let defs = rules.first?.tileDefinitions ?? []
        guard !defs.isEmpty else { return nil }
        if defs.count == 1 { return defs[0] }
        let total = defs.reduce(0) { $0 + max(1, $1.placementWeight) }
        var k = (i &* 2654435761) % max(1, total)
        for d in defs { k -= max(1, d.placementWeight); if k < 0 { return d } }
        return defs[0]
    }
}

open class SKTileSet: NSObject {
    open var tileGroups: [SKTileGroup]
    open var name: String?
    open var type: SKTileSetType = .grid
    open var defaultTileGroup: SKTileGroup?
    open var defaultTileSize: CGSize = CGSize(width: 32, height: 32)
    public init(tileGroups: [SKTileGroup]) { self.tileGroups = tileGroups }
    public init(tileGroups: [SKTileGroup], tileSetType: SKTileSetType) { self.tileGroups = tileGroups; type = tileSetType }
    public convenience init?(named name: String) { NSLog("isim SpriteKit: SKTileSet(named: %@): tile sets from .sks files are not supported", name); return nil }
}

open class SKTileMapNode: SKNode {
    open var numberOfColumns: Int { didSet { resize() } }
    open var numberOfRows: Int { didSet { resize() } }
    open var tileSize: CGSize
    open var mapSize: CGSize { CGSize(width: CGFloat(numberOfColumns) * tileSize.width, height: CGFloat(numberOfRows) * tileSize.height) }
    open var tileSet: SKTileSet
    open var colorBlendFactor: CGFloat = 0
    open var color: UIColor = .white
    open var blendMode: SKBlendMode = .alpha
    open var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    open var shader: SKShader?
    open var lightingBitMask: UInt32 = 0
    open var enableAutomapping = false
    var cells: [SKTileGroup?] = []
    var elapsed: CGFloat = 0

    public init(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize) {
        self.tileSet = tileSet; numberOfColumns = columns; numberOfRows = rows; self.tileSize = tileSize
        super.init(); resize()
    }
    public convenience init(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize, fillWith g: SKTileGroup) {
        self.init(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize); fill(with: g)
    }
    public convenience init(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize, tileGroupLayout: [SKTileGroup]) {
        self.init(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize)
        for (i, g) in tileGroupLayout.prefix(cells.count).enumerated() { cells[i] = g }
    }
    public required init?(coder: NSCoder) {
        tileSet = SKTileSet(tileGroups: []); numberOfColumns = 0; numberOfRows = 0; tileSize = CGSize(width: 32, height: 32)
        super.init(coder: coder)
    }
    func resize() {
        let n = max(0, numberOfColumns * numberOfRows)
        if cells.count != n { cells = Array(cells.prefix(n)) + Array(repeating: nil, count: max(0, n - cells.count)) }
    }
    open func fill(with g: SKTileGroup?) { for i in cells.indices { cells[i] = g } }
    open func setTileGroup(_ g: SKTileGroup?, forColumn c: Int, row r: Int) {
        guard c >= 0, r >= 0, c < numberOfColumns, r < numberOfRows else { return }
        cells[r * numberOfColumns + c] = g
    }
    open func setTileGroup(_ g: SKTileGroup, andTileDefinition d: SKTileDefinition, forColumn c: Int, row r: Int) { setTileGroup(g, forColumn: c, row: r) }
    open func tileGroup(atColumn c: Int, row r: Int) -> SKTileGroup? {
        guard c >= 0, r >= 0, c < numberOfColumns, r < numberOfRows else { return nil }
        return cells[r * numberOfColumns + c]
    }
    open func tileDefinition(atColumn c: Int, row r: Int) -> SKTileDefinition? {
        tileGroup(atColumn: c, row: r)?.definition(forCell: r * numberOfColumns + c)
    }
    var origin: CGPoint { CGPoint(x: -anchorPoint.x * mapSize.width, y: -anchorPoint.y * mapSize.height) }
    open func tileColumnIndex(fromPosition p: CGPoint) -> Int { Int(floor((p.x - origin.x) / tileSize.width)) }
    open func tileRowIndex(fromPosition p: CGPoint) -> Int { Int(floor((p.y - origin.y) / tileSize.height)) }
    open func centerOfTile(atColumn c: Int, row r: Int) -> CGPoint {
        CGPoint(x: origin.x + (CGFloat(c) + 0.5) * tileSize.width, y: origin.y + (CGFloat(r) + 0.5) * tileSize.height)
    }
    override var contentRect: CGRect { CGRect(origin: origin, size: mapSize) }

    override func drawContent(alpha a: CGFloat) {
        let o = origin
        var tint = _rgba(color)
        let factor = Double(colorBlendFactor)
        isim_gfx_save()
        isim_gfx_set_blend(_hostBlend(blendMode))
        for r in 0..<numberOfRows {
            for c in 0..<numberOfColumns {
                guard let d = cells[r * numberOfColumns + c]?.definition(forCell: r * numberOfColumns + c), !d.textures.isEmpty else { continue }
                let frame = d.timePerFrame > 0 ? Int(elapsed / d.timePerFrame) % d.textures.count : 0
                let t = d.textures[frame]
                guard t.handle > 0 else { continue }
                let cx = o.x + (CGFloat(c) + 0.5) * tileSize.width, cy = o.y + (CGFloat(r) + 0.5) * tileSize.height
                let w = d.size.width, h = d.size.height
                isim_gfx_save()
                isim_gfx_translate(cx, cy)
                if d.rotation != .rotation0 { isim_gfx_rotate(CGFloat(d.rotation.rawValue) * .pi / 2) }
                isim_gfx_scale(d.flipHorizontally ? -1 : 1, d.flipVertically ? 1 : -1)
                tint.withUnsafeMutableBufferPointer { b in
                    isim_image_draw_part(t.handle, t.pixels.minX, t.pixels.minY, t.pixels.width, t.pixels.height, -w / 2, -h / 2, w, h,
                                         t.filteringMode == .nearest ? 1 : 0, factor > 0 ? b.baseAddress : nil, factor, Double(a))
                }
                isim_gfx_restore()
            }
        }
        isim_gfx_restore()
    }
}
