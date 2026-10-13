// isim SpriteKit physics, continued: concave polygons (split into convex pieces: ear-clipping triangulation, then
// Hertel–Mehlhorn merging), bodies traced from a texture's alpha (marching squares on the alpha mask, simplified
// with Douglas–Peucker, then split into convex pieces), continuous collision detection for
// `usesPreciseCollisionDetection` (adapted: the body's motion in a step is swept in increments smaller than a quarter
// of its size and the first overlap is refined by bisection, so it stops at the time of impact instead of passing
// through), `SKPhysicsWorld.sampleFields(at:)`, and fields acting on particles (`SKEmitterNode.fieldBitMask`).
import Foundation
import isim_host

// MARK: - convex decomposition

private func _area2(_ p: [CGPoint]) -> CGFloat {
    var a: CGFloat = 0
    for i in 0..<p.count { a += _cross(p[i], p[(i + 1) % p.count]) }
    return a
}
private func _isConvex(_ p: [CGPoint]) -> Bool {
    guard p.count >= 3 else { return false }
    for i in 0..<p.count where _cross(_sub(p[(i + 1) % p.count], p[i]), _sub(p[(i + 2) % p.count], p[(i + 1) % p.count])) < -1e-9 { return false }
    return true
}
/// a simple polygon split into convex counter-clockwise pieces
func _convexDecompose(_ input: [CGPoint]) -> [[CGPoint]] {
    var poly: [CGPoint] = []
    for q in input where poly.last.map({ _len(_sub($0, q)) > 1e-6 }) ?? true { poly.append(q) }
    if let f = poly.first, let l = poly.last, poly.count > 1, _len(_sub(f, l)) < 1e-6 { poly.removeLast() }
    guard poly.count >= 3 else { return [] }
    if _area2(poly) < 0 { poly.reverse() }
    if _isConvex(poly) { return [poly] }
    // ear clipping
    var idx = Array(poly.indices), tris: [[Int]] = []
    func inside(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
        _cross(_sub(b, a), _sub(p, a)) >= 0 && _cross(_sub(c, b), _sub(p, b)) >= 0 && _cross(_sub(a, c), _sub(p, c)) >= 0
    }
    var guardCount = 0
    while idx.count > 3 && guardCount < 10_000 {
        guardCount += 1
        var clipped = false
        for k in 0..<idx.count {
            let i0 = idx[(k + idx.count - 1) % idx.count], i1 = idx[k], i2 = idx[(k + 1) % idx.count]
            let a = poly[i0], b = poly[i1], c = poly[i2]
            if _cross(_sub(b, a), _sub(c, b)) <= 1e-9 { continue }          // reflex
            if idx.contains(where: { $0 != i0 && $0 != i1 && $0 != i2 && inside(poly[$0], a, b, c) }) { continue }
            tris.append([i0, i1, i2]); idx.remove(at: k); clipped = true; break
        }
        if !clipped { break }
    }
    if idx.count == 3 { tris.append(idx) }
    // merge neighbouring pieces while the union stays convex
    var pieces = tris
    var merged = true
    while merged {
        merged = false
        outer: for i in 0..<pieces.count {
            for j in (i + 1)..<pieces.count {
                let a = pieces[i], b = pieces[j]
                // a shared edge: a has u -> v, b has v -> u
                for x in 0..<a.count {
                    let u = a[x], v = a[(x + 1) % a.count]
                    guard let y = b.firstIndex(of: v), b[(y + 1) % b.count] == u else { continue }
                    // a's vertices from v around to u, then b's from u around to v (excluding shared ends)
                    var union: [Int] = []
                    for t in 0..<a.count { union.append(a[(x + 1 + t) % a.count]) }       // v ... u
                    for t in 2..<b.count { union.append(b[(y + t) % b.count]) }            // after u, before v
                    if _isConvex(union.map { poly[$0] }) {
                        pieces[i] = union; pieces.remove(at: j); merged = true
                        break outer
                    }
                }
            }
        }
    }
    return pieces.map { $0.map { poly[$0] } }.filter { abs(_area2($0)) > 1e-6 }
}

// MARK: - texture outlines

/// the outline of the largest opaque region of a texture, in the coordinates of a body of `size` centered on its node
func _alphaOutline(_ t: SKTexture, threshold: Float, size: CGSize) -> [CGPoint]? {
    guard let px = t._pixels(), px.w > 1, px.h > 1 else { return nil }
    // a mask of at most 96 cells a side (alpha above the threshold)
    let n = max(1, max(px.w, px.h) / 96 + (max(px.w, px.h) % 96 > 0 ? 1 : 0))
    let gw = (px.w + n - 1) / n, gh = (px.h + n - 1) / n
    var mask = [Bool](repeating: false, count: (gw + 2) * (gh + 2))      // padded by one empty cell
    let th = UInt8(max(0, min(254, Int(threshold * 255))))
    for gy in 0..<gh { for gx in 0..<gw {
        var on = false
        for y in (gy * n)..<min(px.h, gy * n + n) { for x in (gx * n)..<min(px.w, gx * n + n) where px.px[(y * px.w + x) * 4 + 3] > th { on = true } }
        mask[(gy + 1) * (gw + 2) + gx + 1] = on
    } }
    let W = gw + 2, H = gh + 2
    func at(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < W && y < H && mask[y * W + x] }
    // trace the boundary of the first region found (square tracing on cell corners)
    guard let start = (0..<(W * H)).first(where: { mask[$0] }) else { return nil }
    let sx = start % W, sy = start / W
    // walk the outline clockwise along cell edges (Moore neighbourhood on the corner grid)
    var pts: [CGPoint] = []
    var x = sx, y = sy, dir = 0     // 0 right, 1 down, 2 left, 3 up (along the top-left corner grid)
    let dx = [1, 0, -1, 0], dy = [0, 1, 0, -1]
    var steps = 0
    repeat {
        pts.append(CGPoint(x: x, y: y))
        // cells around the corner (x, y): tl, tr, bl, br
        for turn in [3, 0, 1, 2] {           // prefer turning left, then straight, right, back
            let d = (dir + turn) % 4
            let nx = x + dx[d], ny = y + dy[d]
            // the edge from (x,y) to (nx,ny) is a boundary when the cells on its two sides differ, with the solid one on the right
            let solidRight: Bool, emptyLeft: Bool
            switch d {
            case 0: solidRight = at(x, y); emptyLeft = !at(x, y - 1)
            case 1: solidRight = at(x - 1, y); emptyLeft = !at(x, y)
            case 2: solidRight = at(x - 1, y - 1); emptyLeft = !at(x - 1, y)
            default: solidRight = at(x, y - 1); emptyLeft = !at(x - 1, y - 1)
            }
            if solidRight && emptyLeft { x = nx; y = ny; dir = d; break }
        }
        steps += 1
    } while (x != sx || y != sy) && steps < 4 * W * H
    guard pts.count >= 3 else { return nil }
    // Douglas–Peucker, tolerance one cell
    func simplify(_ p: [CGPoint], _ eps: CGFloat) -> [CGPoint] {
        guard p.count > 2 else { return p }
        let a = p.first!, b = p.last!
        var best: CGFloat = 0, bi = 0
        for i in 1..<(p.count - 1) {
            let d = _len(_sub(p[i], _closestOnSegment(p[i], a, b)))
            if d > best { best = d; bi = i }
        }
        if best <= eps { return [a, b] }
        return Array(simplify(Array(p[0...bi]), eps).dropLast()) + simplify(Array(p[bi...]), eps)
    }
    let half = pts.count / 2
    var simple = Array(simplify(Array(pts[0...half]), 1.0).dropLast()) + Array(simplify(Array(pts[half...]) + [pts[0]], 1.0).dropLast())
    if simple.count < 3 { simple = pts }
    // corner grid -> body coordinates (cell (1,1) is the image's top-left; y up)
    let sxk = size.width / CGFloat(gw), syk = size.height / CGFloat(gh)
    return simple.map { CGPoint(x: (CGFloat($0.x - 1)) * sxk - size.width / 2, y: size.height / 2 - CGFloat($0.y - 1) * syk) }
}

extension SKPhysicsBody {
    /// convex pieces of a polygon outline; the bounding rectangle when it cannot be split
    static func _pieces(_ outline: [CGPoint], fallback: CGRect) -> [_PShape] {
        let parts = _convexDecompose(outline).filter { $0.count >= 3 }
        if !parts.isEmpty { return parts.map { .polygon($0) } }
        let r = fallback
        return [.polygon([CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)])]
    }
}

// MARK: - continuous collision detection

extension SKPhysicsWorld {
    /// moves a fast body with usesPreciseCollisionDetection by `delta` (points) but no further than its first
    /// contact with a body it collides with; returns the fraction of the motion made
    func _sweep(_ b: SKPhysicsBody, _ delta: CGPoint, _ angle: CGFloat, _ bodies: [SKPhysicsBody]) -> CGFloat {
        let dist = _len(delta)
        let stepLen = max(0.5, b.minExtent * 0.25)
        let start = b.com, a0 = b.angle
        // candidates: bodies it collides with near the whole motion
        let box0 = b.aabb, ext = max(box0.width, box0.height)
        let swept = box0.union(box0.offsetBy(dx: delta.x, dy: delta.y)).insetBy(dx: -ext, dy: -ext)
        let near = bodies.filter { $0 !== b && (b.collisionBitMask & $0.categoryBitMask) != 0 && !$0.world.isEmpty && $0.aabb.intersects(swept) }
        func overlaps(at t: CGFloat) -> Bool {
            b.com = _add(start, _mul(delta, t)); b.angle = a0 + angle * t
            b.updateWorldShapes()
            let box = b.aabb
            for o in near where o.aabb.intersects(box) {
                for s1 in b.world { for s2 in o.world {
                    if let (_, pts) = _Collide.shapes(s1, s2, margin: 0), pts.contains(where: { $0.1 < -0.25 }) { return true }
                } }
            }
            return false
        }
        guard dist > stepLen, !near.isEmpty else { b.com = _add(start, delta); b.angle = a0 + angle; b.updateWorldShapes(); return 1 }
        if overlaps(at: 0) { b.com = _add(start, delta); b.angle = a0 + angle; b.updateWorldShapes(); return 1 }   // already touching: the solver handles it
        let n = min(512, Int((dist / stepLen).rounded(.up)))       // very long moves: coarser samples
        var free: CGFloat = 0
        for i in 1...n {
            let t = CGFloat(i) / CGFloat(n)
            if overlaps(at: t) {
                // bisection between the last free sample and the first overlapping one
                var lo = free, hi = t
                for _ in 0..<10 { let mid = (lo + hi) / 2; if overlaps(at: mid) { hi = mid } else { lo = mid } }
                _ = overlaps(at: lo)
                return lo
            }
            free = t
        }
        b.com = _add(start, delta); b.angle = a0 + angle; b.updateWorldShapes()
        return 1
    }

    /// the fields' combined force (newtons) on a 1 kg body with a charge of 1 at rest at a point
    public func sampleFields(at position: vector_float3) -> vector_float3 {
        guard let scene else { return .zero }
        var bodies: [SKPhysicsBody] = [], fields: [SKFieldNode] = []
        collectBodies(scene, &bodies, &fields)
        let p = CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
        var f = CGPoint.zero
        let applying = fields.filter { $0.isEnabled && $0.regionContains(p) }
        let exclusive = applying.filter { $0.isExclusive }
        for fl in (exclusive.isEmpty ? applying : exclusive) { f = _add(f, fl._force(at: p, velocity: .zero, mass: 1, charge: 1)) }
        return vector_float3(Float(f.x / _ptm), Float(f.y / _ptm), 0)
    }
}

// MARK: - fields on particles

extension SKEmitterNode {
    /// the acceleration (points/s^2, in the particles' space) the scene's fields give a particle at a position
    func _fieldAcceleration(_ particleSpace: CGAffineTransform, _ fields: [SKFieldNode], _ p: CGPoint, _ v: CGPoint) -> CGPoint {
        let sp = p.applying(particleSpace)
        let rot = atan2(particleSpace.b, particleSpace.a)
        let sv = _rot(v, cos(rot), sin(rot))
        var a = CGPoint.zero
        for f in fields where f.isEnabled && (f.categoryBitMask & fieldBitMask) != 0 && f.regionContains(sp) {
            a = _add(a, f._force(at: sp, velocity: sv, mass: 1, charge: 1))
        }
        return _rot(a, cos(-rot), sin(-rot))
    }
    /// the scene's fields (when the emitter takes field forces)
    func _sceneFields() -> [SKFieldNode] {
        guard fieldBitMask != 0, let s = scene else { return [] }
        var out: [SKFieldNode] = []
        func walk(_ n: SKNode) { for c in n.children { if let f = c as? SKFieldNode { out.append(f) }; walk(c) } }
        walk(s)
        return out
    }
}

// MARK: - showsFields

extension SKView {
    /// SKView.showsFields: each field's origin, and the combined field force on a grid (arrows), like SpriteKit's overlay
    func drawFields(_ s: SKScene) {
        var bodies: [SKPhysicsBody] = [], fields: [SKFieldNode] = []
        s.physicsWorld.collectBodies(s, &bodies, &fields)
        let live = fields.filter { $0.isEnabled }
        guard !live.isEmpty else { return }
        let t = sceneToView(for: s)
        let color: [Double] = [1, 0.6, 0.2, 0.85]
        isim_gfx_save()
        for f in live {
            let p = f.placement.0.applying(t)
            color.withUnsafeBufferPointer { isim_gfx_stroke_rounded(p.x - 6, p.y - 6, 12, 12, 6, 1.5, $0.baseAddress) }
        }
        let inv = t.inverted()
        for vx in stride(from: CGFloat(20), to: bounds.width, by: 40) {
            for vy in stride(from: CGFloat(20), to: bounds.height, by: 40) {
                let sp = CGPoint(x: vx, y: vy).applying(inv)
                var force = CGPoint.zero
                for f in live where f.regionContains(sp) { force = _add(force, f._force(at: sp, velocity: .zero, mass: 1, charge: 1)) }
                let len = _len(force)
                guard len > 1e-3 else { continue }
                // direction in view space; length grows with the force (at most 16 points)
                let dv = _norm(CGPoint(x: force.x * t.a + force.y * t.c, y: force.x * t.b + force.y * t.d))
                let l = min(16, 4 + log2(1 + len / _ptm) * 4)
                let e = CGPoint(x: vx + dv.x * l, y: vy + dv.y * l)
                isim_path_begin(); isim_path_move(vx, vy); isim_path_line(e.x, e.y)
                isim_path_line(e.x - dv.x * 4 - dv.y * 3, e.y - dv.y * 4 + dv.x * 3); isim_path_move(e.x, e.y)
                isim_path_line(e.x - dv.x * 4 + dv.y * 3, e.y - dv.y * 4 - dv.x * 3)
                color.withUnsafeBufferPointer { isim_path_stroke(1, $0.baseAddress) }
            }
        }
        isim_path_begin()
        isim_gfx_restore()
    }
}
