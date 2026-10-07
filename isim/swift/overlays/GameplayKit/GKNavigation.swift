// isim GameplayKit: obstacles, GKObstacleGraph (visibility graph around buffered polygons) and GKMeshGraph
// (Delaunay triangulation of the free space as a navigation mesh).
import Foundation
import SpriteKit

// MARK: - Obstacles

open class GKObstacle: NSObject {}

open class GKCircleObstacle: GKObstacle {
    open var radius: Float
    open var position: vector_float2 = .zero
    public init(radius: Float) { self.radius = radius; super.init() }
}

open class GKSphereObstacle: GKObstacle {
    open var radius: Float
    open var position: vector_float3 = .zero
    public init(radius: Float) { self.radius = radius; super.init() }
}

/// A polygon (counter-clockwise or clockwise vertices, not closed).
open class GKPolygonObstacle: GKObstacle {
    let points: [vector_float2]
    public init(points: UnsafeMutablePointer<vector_float2>, count: Int) {
        self.points = (0..<max(0, count)).map { points[$0] }
        super.init()
    }
    public init(points: [vector_float2]) { self.points = points; super.init() }
    open var vertexCount: Int { points.count }
    open func vertex(at index: Int) -> vector_float2 { points[index] }
    /// the polygon grown by `radius` (vertices pushed out along the corner bisectors)
    func buffered(_ radius: Float) -> [vector_float2] { _gkOffsetPolygon(points, radius) }
}

extension SKNode {
    /// rectangles around the nodes' accumulated frames, in scene coordinates
    public class func obstacles(fromNodeBounds nodes: [SKNode]) -> [GKPolygonObstacle] {
        nodes.map { n in
            let r = n.calculateAccumulatedFrame()
            let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
            let pts = corners.map { p -> vector_float2 in
                let q = (n.parent.flatMap { par in n.scene.map { par === $0 ? p : par.convert(p, to: $0) } }) ?? p
                return vector_float2(Float(q.x), Float(q.y))
            }
            return GKPolygonObstacle(points: pts)
        }
    }
}

extension GKGoal {
    /// steers away from circle obstacles and polygons the agent would reach within `maxPredictionTime`
    public class func toAvoid(_ obstacles: [GKObstacle], maxPredictionTime: TimeInterval) -> GKGoal {
        GKGoal { a, _ in
            var f = vector_float2.zero
            let ahead = a.position + a.velocity * Float(maxPredictionTime)
            for o in obstacles {
                if let c = o as? GKCircleObstacle {
                    let d = ahead - c.position, l = simd_length(d), r = c.radius + a.radius
                    if l < r * 1.5, l > 1e-5 { f += d / l * (r * 1.5 - l) / (r * 1.5) * a.maxAcceleration }
                } else if let p = o as? GKPolygonObstacle, p.vertexCount > 2 {
                    let q = _gkClosestOnPolygon(ahead, p.points)
                    let d = ahead - q, l = simd_length(d)
                    let inside = _gkPointInPolygon(ahead, p.points)
                    if inside || l < a.radius * 2 {
                        let dir = l > 1e-5 ? d / l * (inside ? -1 : 1) : -simd_normalize(a.velocity)
                        f += dir * a.maxAcceleration
                    }
                }
            }
            return f
        }
    }
}

// MARK: - Geometry helpers

func _gkCross(_ a: vector_float2, _ b: vector_float2) -> Float { a.x * b.y - a.y * b.x }
func _gkSignedArea(_ p: [vector_float2]) -> Float {
    var s: Float = 0
    for i in p.indices { s += _gkCross(p[i], p[(i + 1) % p.count]) }
    return s / 2
}
func _gkOffsetPolygon(_ p: [vector_float2], _ r: Float) -> [vector_float2] {
    guard p.count > 2, r != 0 else { return p }
    let ccw = _gkSignedArea(p) > 0
    return p.indices.map { i in
        let prev = p[(i + p.count - 1) % p.count], cur = p[i], next = p[(i + 1) % p.count]
        let e1 = simd_normalize(cur - prev), e2 = simd_normalize(next - cur)
        // outward normals: right of the edge direction for counter-clockwise polygons
        var n1 = vector_float2(e1.y, -e1.x), n2 = vector_float2(e2.y, -e2.x)
        if !ccw { n1 = -n1; n2 = -n2 }
        var b = simd_normalize(n1 + n2)
        if simd_length(n1 + n2) < 1e-5 { b = n1 }
        let cosHalf = max(0.25, simd_dot(b, n1))        // limit the miter on sharp corners
        return cur + b * (r / cosHalf)
    }
}
func _gkPointInPolygon(_ q: vector_float2, _ p: [vector_float2]) -> Bool {
    var inside = false
    var j = p.count - 1
    for i in p.indices {
        let a = p[i], b = p[j]
        if (a.y > q.y) != (b.y > q.y), q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
        j = i
    }
    return inside
}
/// segments a-b and c-d cross at a point inside both (touching at endpoints does not count)
func _gkProperIntersect(_ a: vector_float2, _ b: vector_float2, _ c: vector_float2, _ d: vector_float2) -> Bool {
    let eps: Float = 1e-4
    let d1 = _gkCross(b - a, c - a), d2 = _gkCross(b - a, d - a), d3 = _gkCross(d - c, a - c), d4 = _gkCross(d - c, b - c)
    return ((d1 > eps && d2 < -eps) || (d1 < -eps && d2 > eps)) && ((d3 > eps && d4 < -eps) || (d3 < -eps && d4 > eps))
}
func _gkClosestOnSegment(_ q: vector_float2, _ a: vector_float2, _ b: vector_float2) -> vector_float2 {
    let ab = b - a, l2 = simd_length_squared(ab)
    guard l2 > 0 else { return a }
    return a + ab * max(0, min(1, simd_dot(q - a, ab) / l2))
}
func _gkClosestOnPolygon(_ q: vector_float2, _ p: [vector_float2]) -> vector_float2 {
    var best = p[0], bd = Float.infinity
    for i in p.indices {
        let c = _gkClosestOnSegment(q, p[i], p[(i + 1) % p.count]), d = simd_distance_squared(q, c)
        if d < bd { bd = d; best = c }
    }
    return best
}
/// true if the segment passes through the polygon's interior
func _gkSegmentBlocked(_ a: vector_float2, _ b: vector_float2, _ poly: [vector_float2]) -> Bool {
    guard poly.count > 2 else { return false }
    for i in poly.indices where _gkProperIntersect(a, b, poly[i], poly[(i + 1) % poly.count]) { return true }
    for t in [Float(0.5), 0.25, 0.75, 0.1, 0.9] where _gkPointInPolygon(a + (b - a) * t, poly) {
        // a point on the boundary is not inside: test slightly to both sides isn't needed for samples off the edges
        let s = a + (b - a) * t
        if simd_distance(_gkClosestOnPolygon(s, poly), s) > 1e-3 { return true }
    }
    return false
}

func _gkMakeNode(_ cls: AnyClass, _ p: vector_float2) -> GKGraphNode2D {
    // an app's subclass: created through -init (GKGraphNode2D.init() starts at the origin)
    if cls != GKGraphNode2D.self, let t = cls as? NSObject.Type, let n = t.init() as? GKGraphNode2D {
        n.position = p
        return n
    }
    return GKGraphNode2D(point: p)
}

// MARK: - Obstacle graph

/// Nodes at the corners of the obstacles grown by `bufferRadius`, connected wherever they can see each other.
open class GKObstacleGraph<NodeType: GKGraphNode2D>: GKGraph {
    open private(set) var obstacles: [GKPolygonObstacle] = []
    open private(set) var bufferRadius: Float
    let nodeClass: AnyClass
    /// obstacle -> its corner nodes (vertex index, node); corners inside other obstacles have no node
    var corners: [ObjectIdentifier: [(Int, GKGraphNode2D)]] = [:]
    var cornerOf: [ObjectIdentifier: (GKPolygonObstacle, Int)] = [:]
    var locked: Set<[ObjectIdentifier]> = []

    public convenience init(obstacles: [GKPolygonObstacle], bufferRadius: Float) {
        self.init(obstacles: obstacles, bufferRadius: bufferRadius, nodeClass: NodeType.self)
    }
    public init(obstacles: [GKPolygonObstacle], bufferRadius: Float, nodeClass: AnyClass) {
        self.bufferRadius = max(0, bufferRadius); self.nodeClass = nodeClass
        super.init(nodes: [])
        addObstacles(obstacles)
    }
    public required init?(coder: NSCoder) { bufferRadius = 0; nodeClass = NodeType.self; super.init(coder: coder) }
    open func classForGenericArgument(at index: Int) -> AnyClass { nodeClass }

    func polygon(_ o: GKPolygonObstacle, buffered: Bool = true) -> [vector_float2] { buffered ? o.buffered(bufferRadius) : o.points }

    /// whether a and b see each other past every obstacle (except those ignored)
    func visible(_ a: GKGraphNode2D, _ b: GKGraphNode2D, ignoring: [GKPolygonObstacle] = [], unbuffered: [GKPolygonObstacle] = []) -> Bool {
        let ca = cornerOf[ObjectIdentifier(a)], cb = cornerOf[ObjectIdentifier(b)]
        for o in obstacles where !ignoring.contains(where: { $0 === o }) {
            // two neighbouring corners of the same obstacle: the edge between them is free
            if let ca, let cb, ca.0 === o, cb.0 === o {
                let n = o.vertexCount, d = abs(ca.1 - cb.1)
                if d == 1 || d == n - 1 { continue }
            }
            let poly = polygon(o, buffered: !unbuffered.contains(where: { $0 === o }))
            if _gkSegmentBlocked(a.position, b.position, poly) { return false }
        }
        return true
    }
    func isLocked(_ a: GKGraphNode, _ b: GKGraphNode) -> Bool { locked.contains([ObjectIdentifier(a), ObjectIdentifier(b)]) }

    /// drops connections that now cross an obstacle (unless locked) and connects all corners that see each other
    func rebuildCorners() {
        let all = nodes ?? []
        for a in all {
            for b in a.connectedNodes where !isLocked(a, b) {
                guard let a2 = a as? GKGraphNode2D, let b2 = b as? GKGraphNode2D else { continue }
                if !visible(a2, b2) { a.removeConnections(to: [b], bidirectional: false) }
            }
        }
        let cornerNodes = corners.values.flatMap { $0.map(\.1) }
        for (i, a) in cornerNodes.enumerated() {
            for b in cornerNodes[(i + 1)...] where visible(a, b) { a.addConnections(to: [b], bidirectional: true) }
        }
    }

    open func addObstacles(_ new: [GKPolygonObstacle]) {
        let added = new.filter { o in !obstacles.contains { $0 === o } }
        obstacles += added
        // corners of earlier obstacles swallowed by the new ones go away
        for o in added {
            let poly = polygon(o)
            for (k, list) in corners {
                let gone = list.filter { _gkPointInPolygon($0.1.position, poly) }
                if !gone.isEmpty {
                    super.remove(gone.map(\.1))
                    for g in gone { cornerOf[ObjectIdentifier(g.1)] = nil }
                    corners[k] = list.filter { e in !gone.contains { $0.1 === e.1 } }
                }
            }
        }
        for o in added {
            var list: [(Int, GKGraphNode2D)] = []
            for (i, p) in polygon(o).enumerated() {
                if obstacles.contains(where: { $0 !== o && _gkPointInPolygon(p, polygon($0)) }) { continue }
                let n = _gkMakeNode(nodeClass, p)
                list.append((i, n)); cornerOf[ObjectIdentifier(n)] = (o, i)
            }
            corners[ObjectIdentifier(o)] = list
            add(list.map(\.1))
        }
        rebuildCorners()
    }
    open func removeObstacles(_ old: [GKPolygonObstacle]) {
        for o in old {
            guard let list = corners.removeValue(forKey: ObjectIdentifier(o)) else { continue }
            for (_, n) in list { cornerOf[ObjectIdentifier(n)] = nil }
            super.remove(list.map(\.1))
        }
        obstacles.removeAll { o in old.contains { $0 === o } }
        rebuildCorners()
    }
    open func removeAllObstacles() { removeObstacles(obstacles) }
    open func nodes(forObstacle obstacle: GKPolygonObstacle) -> [NodeType] {
        (corners[ObjectIdentifier(obstacle)] ?? []).compactMap { $0.1 as? NodeType }
    }

    /// adds the node and connects it to every node it can see
    open func connectUsingObstacles(node: NodeType) { connect(node, ignoring: [], unbuffered: []) }
    open func connectUsingObstacles(node: NodeType, ignoring obstaclesToIgnore: [GKPolygonObstacle]) {
        connect(node, ignoring: obstaclesToIgnore, unbuffered: [])
    }
    open func connectUsingObstacles(node: NodeType, ignoringBufferRadiusOf obstaclesBufferRadiusToIgnore: [GKPolygonObstacle]) {
        connect(node, ignoring: [], unbuffered: obstaclesBufferRadiusToIgnore)
    }
    func connect(_ node: GKGraphNode2D, ignoring: [GKPolygonObstacle], unbuffered: [GKPolygonObstacle]) {
        if !(nodes ?? []).contains(where: { $0 === node }) { add([node]) }
        for case let other as GKGraphNode2D in nodes ?? [] where other !== node {
            if visible(node, other, ignoring: ignoring, unbuffered: unbuffered) { node.addConnections(to: [other], bidirectional: true) }
        }
    }
    open override func remove(_ remove: [GKGraphNode]) {
        for n in remove {
            if let (o, _) = cornerOf.removeValue(forKey: ObjectIdentifier(n)) {
                corners[ObjectIdentifier(o)]?.removeAll { $0.1 === n }
            }
            locked = locked.filter { !$0.contains(ObjectIdentifier(n)) }
        }
        super.remove(remove)
    }
    /// a locked connection survives obstacle changes
    open func lockConnection(from startNode: NodeType, to endNode: NodeType) { locked.insert([ObjectIdentifier(startNode), ObjectIdentifier(endNode)]) }
    open func unlockConnection(from startNode: NodeType, to endNode: NodeType) { locked.remove([ObjectIdentifier(startNode), ObjectIdentifier(endNode)]) }
    open func isConnectionLocked(from startNode: NodeType, to endNode: NodeType) -> Bool { isLocked(startNode, endNode) }
}

// MARK: - Mesh graph

public struct GKMeshGraphTriangulationMode: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let vertices = GKMeshGraphTriangulationMode(rawValue: 1 << 0)
    public static let centers = GKMeshGraphTriangulationMode(rawValue: 1 << 1)
    public static let edgeMidpoints = GKMeshGraphTriangulationMode(rawValue: 1 << 2)
}

public struct GKTriangle {
    public var points: (vector_float3, vector_float3, vector_float3)
    public init() { points = (.zero, .zero, .zero) }
    public init(points: (vector_float3, vector_float3, vector_float3)) { self.points = points }
}

/// Bowyer-Watson Delaunay triangulation of `pts`; triangles as index triples (counter-clockwise)
func _gkDelaunay(_ pts: [vector_float2]) -> [(Int, Int, Int)] {
    guard pts.count >= 3 else { return [] }
    var lo = pts[0], hi = pts[0]
    for p in pts { lo = simd_min(lo, p); hi = simd_max(hi, p) }
    let span = max(hi.x - lo.x, hi.y - lo.y, 1) * 20, mid = (lo + hi) / 2
    let P = pts + [mid + vector_float2(-span, -span), mid + vector_float2(span, -span), mid + vector_float2(0, span)]
    let s0 = pts.count
    struct T { var a: Int, b: Int, c: Int; var cc: vector_float2; var r2: Float }
    func make(_ a: Int, _ b: Int, _ c: Int) -> T {
        var (a, b, c) = (a, b, c)
        if _gkCross(P[b] - P[a], P[c] - P[a]) < 0 { swap(&b, &c) }
        let A = P[a], B = P[b], C = P[c]
        let d = 2 * (A.x * (B.y - C.y) + B.x * (C.y - A.y) + C.x * (A.y - B.y))
        if abs(d) < 1e-12 { return T(a: a, b: b, c: c, cc: (A + B + C) / 3, r2: .infinity) }
        let a2 = simd_length_squared(A), b2 = simd_length_squared(B), c2 = simd_length_squared(C)
        let cc = vector_float2((a2 * (B.y - C.y) + b2 * (C.y - A.y) + c2 * (A.y - B.y)) / d,
                               (a2 * (C.x - B.x) + b2 * (A.x - C.x) + c2 * (B.x - A.x)) / d)
        return T(a: a, b: b, c: c, cc: cc, r2: simd_distance_squared(cc, A))
    }
    var tris = [make(s0, s0 + 1, s0 + 2)]
    for i in 0..<s0 {
        let p = P[i]
        var bad: [T] = [], keep: [T] = []
        for t in tris { if simd_distance_squared(t.cc, p) <= t.r2 * (1 + 1e-6) { bad.append(t) } else { keep.append(t) } }
        // boundary of the cavity: edges of bad triangles not shared by two of them
        var count: [[Int]: Int] = [:]
        for t in bad { for e in [[t.a, t.b], [t.b, t.c], [t.c, t.a]] { count[e.sorted(), default: 0] += 1 } }
        var newTris = keep
        for t in bad {
            for e in [(t.a, t.b), (t.b, t.c), (t.c, t.a)] where count[[e.0, e.1].sorted()] == 1 { newTris.append(make(e.0, e.1, i)) }
        }
        tris = newTris
    }
    return tris.filter { $0.a < s0 && $0.b < s0 && $0.c < s0 }.map { ($0.a, $0.b, $0.c) }
}

/// A navigation mesh: the area between min / max coordinates minus the buffered obstacles, triangulated.
/// Call triangulate() after adding or removing obstacles.
open class GKMeshGraph<NodeType: GKGraphNode2D>: GKGraph {
    open private(set) var obstacles: [GKPolygonObstacle] = []
    open private(set) var bufferRadius: Float
    open var triangulationMode: GKMeshGraphTriangulationMode = .vertices
    let minCoord: vector_float2, maxCoord: vector_float2
    let nodeClass: AnyClass
    var pts: [vector_float2] = []
    var tris: [(Int, Int, Int)] = []
    var meshNodes: [GKGraphNode2D] = []
    var triNodes: [[GKGraphNode2D]] = []
    var userNodes: [GKGraphNode2D] = []

    public convenience init(bufferRadius: Float, minCoordinate min: vector_float2, maxCoordinate max: vector_float2) {
        self.init(bufferRadius: bufferRadius, minCoordinate: min, maxCoordinate: max, nodeClass: NodeType.self)
    }
    public init(bufferRadius: Float, minCoordinate min: vector_float2, maxCoordinate max: vector_float2, nodeClass: AnyClass) {
        self.bufferRadius = Swift.max(0, bufferRadius); minCoord = min; maxCoord = max; self.nodeClass = nodeClass
        super.init(nodes: [])
        triangulate()
    }
    public required init?(coder: NSCoder) { bufferRadius = 0; minCoord = .zero; maxCoord = .zero; nodeClass = NodeType.self; super.init(coder: coder) }
    open func classForGenericArgument(at index: Int) -> AnyClass { nodeClass }

    open var triangleCount: Int { tris.count }
    open func triangle(at index: Int) -> GKTriangle {
        let t = tris[index]
        func v3(_ i: Int) -> vector_float3 { vector_float3(pts[i].x, pts[i].y, 0) }
        return GKTriangle(points: (v3(t.0), v3(t.1), v3(t.2)))
    }
    open func addObstacles(_ new: [GKPolygonObstacle]) { obstacles += new.filter { o in !obstacles.contains { $0 === o } } }
    open func removeObstacles(_ old: [GKPolygonObstacle]) { obstacles.removeAll { o in old.contains { $0 === o } } }

    func inside(_ p: vector_float2, _ polys: [[vector_float2]]) -> Bool { polys.contains { _gkPointInPolygon(p, $0) } }

    /// rebuilds the mesh and its nodes; nodes added with connectUsingObstacles are reconnected
    open func triangulate() {
        super.remove(meshNodes)
        meshNodes = []; triNodes = []
        let polys = obstacles.map { $0.buffered(bufferRadius).map { simd_clamp($0, minCoord, maxCoord) } }
        var p: [vector_float2] = [minCoord, vector_float2(maxCoord.x, minCoord.y), maxCoord, vector_float2(minCoord.x, maxCoord.y)]
        // obstacle outlines, with extra points along long edges so the Delaunay mesh follows them
        let size = simd_length(maxCoord - minCoord)
        for poly in polys {
            for i in poly.indices {
                let a = poly[i], b = poly[(i + 1) % poly.count]
                let steps = Swift.max(1, Int((simd_distance(a, b) / Swift.max(size / 16, Float(1e-3))).rounded(.up)))
                for k in 0..<steps { p.append(a + (b - a) * (Float(k) / Float(steps))) }
            }
        }
        // the outer boundary too
        let corners = Array(p[0..<4])
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            let steps = Swift.max(1, Int((simd_distance(a, b) / Swift.max(size / 8, Float(1e-3))).rounded(.up)))
            for k in 1..<Swift.max(2, steps) where k < steps { p.append(a + (b - a) * (Float(k) / Float(steps))) }
        }
        // drop duplicates
        var unique: [vector_float2] = []
        for q in p where !unique.contains(where: { simd_distance_squared($0, q) < 1e-6 }) { unique.append(q) }
        pts = unique
        // keep the triangles in free space
        tris = _gkDelaunay(pts).filter { t in
            let a: vector_float2 = pts[t.0], b: vector_float2 = pts[t.1], c: vector_float2 = pts[t.2]
            let center: vector_float2 = (a + b + c) / 3
            let nearAB: vector_float2 = (a + b) * Float(0.45) + c * Float(0.1)
            let nearBC: vector_float2 = (b + c) * Float(0.45) + a * Float(0.1)
            let nearCA: vector_float2 = (c + a) * Float(0.45) + b * Float(0.1)
            let probes: [vector_float2] = [center, nearAB, nearBC, nearCA]
            return !probes.contains { inside($0, polys) }
        }
        // nodes
        var vertexNode: [Int: GKGraphNode2D] = [:]
        var midNode: [[Int]: GKGraphNode2D] = [:]
        var centerNode: [GKGraphNode2D?] = []
        for t in tris {
            var list: [GKGraphNode2D] = []
            if triangulationMode.contains(.vertices) {
                for i in [t.0, t.1, t.2] {
                    let n = vertexNode[i] ?? { let n = _gkMakeNode(nodeClass, pts[i]); vertexNode[i] = n; meshNodes.append(n); return n }()
                    list.append(n)
                }
            }
            if triangulationMode.contains(.edgeMidpoints) {
                for e in [[t.0, t.1], [t.1, t.2], [t.2, t.0]] {
                    let k = e.sorted()
                    let n = midNode[k] ?? { let n = _gkMakeNode(nodeClass, (pts[k[0]] + pts[k[1]]) / 2); midNode[k] = n; meshNodes.append(n); return n }()
                    list.append(n)
                }
            }
            if triangulationMode.contains(.centers) {
                let n = _gkMakeNode(nodeClass, (pts[t.0] + pts[t.1] + pts[t.2]) / 3)
                meshNodes.append(n); list.append(n); centerNode.append(n)
            } else { centerNode.append(nil) }
            triNodes.append(list)
        }
        add(meshNodes)
        // nodes of one triangle connect to each other; centers also to the centers of neighbouring triangles
        for list in triNodes { for a in list { a.addConnections(to: list.filter { $0 !== a }, bidirectional: true) } }
        if triangulationMode.contains(.centers) {
            var byEdge: [[Int]: [Int]] = [:]
            for (k, t) in tris.enumerated() { for e in [[t.0, t.1], [t.1, t.2], [t.2, t.0]] { byEdge[e.sorted(), default: []].append(k) } }
            for (_, ts) in byEdge where ts.count == 2 {
                if let a = centerNode[ts[0]], let b = centerNode[ts[1]] { a.addConnections(to: [b], bidirectional: true) }
            }
        }
        for n in userNodes { attach(n) }
    }

    func triangleIndex(containing q: vector_float2) -> Int? {
        tris.firstIndex { t in
            let a = pts[t.0], b = pts[t.1], c = pts[t.2]
            let d1 = _gkCross(b - a, q - a), d2 = _gkCross(c - b, q - b), d3 = _gkCross(a - c, q - c)
            return (d1 >= -1e-4 && d2 >= -1e-4 && d3 >= -1e-4) || (d1 <= 1e-4 && d2 <= 1e-4 && d3 <= 1e-4)
        }
    }
    func attach(_ node: GKGraphNode2D) {
        if !(nodes ?? []).contains(where: { $0 === node }) { add([node]) }
        if let k = triangleIndex(containing: node.position), !triNodes[k].isEmpty {
            node.addConnections(to: triNodes[k], bidirectional: true)
        } else if let nearest = meshNodes.min(by: { simd_distance_squared($0.position, node.position) < simd_distance_squared($1.position, node.position) }) {
            node.addConnections(to: [nearest], bidirectional: true)
        }
    }
    /// adds the node and connects it to the nodes of the triangle it is in
    open func connectUsingObstacles(node: NodeType) {
        if !userNodes.contains(where: { $0 === node }) { userNodes.append(node) }
        attach(node)
    }
    open override func remove(_ remove: [GKGraphNode]) {
        userNodes.removeAll { n in remove.contains { $0 === n } }
        super.remove(remove)
    }
}
