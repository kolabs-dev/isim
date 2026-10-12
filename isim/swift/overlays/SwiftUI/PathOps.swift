// isim SwiftUI (iOS 17): Path geometry — `strokedPath(_:)`, `normalized(eoFill:)`, the boolean operations (`union`,
// `intersection`, `subtracting`, `symmetricDifference`), `lineIntersection` / `lineSubtraction`, and the same on
// shapes (`Shape.union(_:eoFill:)`, ...).
// Adapted: curves are flattened (0.2 pt tolerance) and the results are polygons. Regions are combined with a
// vertical-slab sweep: between consecutive x coordinates of vertices and crossings no edges cross, so each slab is cut
// into trapezoids whose inside-ness (by each operand's fill rule) decides what is kept; the kept trapezoids' outer
// edges are chained into closed outlines (holes run the other way), with collinear points removed.
import UIKit

// MARK: - Flattening

extension Path {
    /// Each subpath as a polyline (curves subdivided to `tolerance`) and whether it was closed.
    func _flattened(tolerance: CGFloat = 0.2) -> [([CGPoint], Bool)] {
        var out: [([CGPoint], Bool)] = []
        var cur: [CGPoint] = []
        var start = CGPoint.zero, last = CGPoint.zero
        func flush(_ closed: Bool) { if cur.count > 0 { out.append((cur, closed)) }; cur = [] }
        func steps(_ ctrl: [CGPoint]) -> Int {
            var len: CGFloat = 0
            for i in 1..<ctrl.count { len += hypot(ctrl[i].x - ctrl[i - 1].x, ctrl[i].y - ctrl[i - 1].y) }
            return max(1, min(96, Int((len / max(tolerance, 0.01)).squareRoot().rounded(.up))))
        }
        for e in elements {
            switch e {
            case .move(let a): flush(false); cur = [a]; start = a; last = a
            case .line(let a): if cur.isEmpty { cur = [last] }; cur.append(a); last = a
            case .quadCurve(let a, let c):
                if cur.isEmpty { cur = [last] }
                let n = steps([last, c, a])
                for i in 1...n { cur.append(_quad(last, c, a, CGFloat(i) / CGFloat(n))) }
                last = a
            case .curve(let a, let c1, let c2):
                if cur.isEmpty { cur = [last] }
                let n = steps([last, c1, c2, a])
                for i in 1...n { cur.append(_cubic(last, c1, c2, a, CGFloat(i) / CGFloat(n))) }
                last = a
            case .closeSubpath: flush(true); last = start
            }
        }
        flush(false)
        // drop repeated points
        return out.map { pts, closed in
            var q: [CGPoint] = []
            for p in pts where q.last.map({ abs($0.x - p.x) > 1e-9 || abs($0.y - p.y) > 1e-9 }) ?? true { q.append(p) }
            if closed, q.count > 1, let f = q.first, let l = q.last, abs(f.x - l.x) < 1e-9, abs(f.y - l.y) < 1e-9 { q.removeLast() }
            return (q, closed)
        }
    }
    /// A path of closed polygons.
    static func _polygons(_ polys: [[CGPoint]]) -> Path {
        var p = Path()
        for poly in polys where poly.count >= 3 {
            p.elements.append(.move(to: poly[0]))
            for q in poly.dropFirst() { p.elements.append(.line(to: q)) }
            p.elements.append(.closeSubpath)
        }
        return p
    }
}

// MARK: - Boolean operations on polygon sets

enum _PathOp { case union, intersection, subtract, xor, normalize }

/// Combines two polygon sets (each with its fill rule) into the outlines of the result.
func _combine(_ a: [[CGPoint]], eoA: Bool, _ b: [[CGPoint]], eoB: Bool, _ op: _PathOp) -> [[CGPoint]] {
    struct Edge { let p: CGPoint, q: CGPoint, set: Int, dir: Int }     // p.x < q.x; dir: +1 if drawn left to right
    var edges: [Edge] = []
    for (set, polys) in [(0, a), (1, b)] {
        for poly in polys where poly.count >= 2 {
            for i in 0..<poly.count {
                let p = poly[i], q = poly[(i + 1) % poly.count]
                if abs(p.x - q.x) < 1e-12 { continue }                 // vertical edges bound no slab
                edges.append(p.x < q.x ? Edge(p: p, q: q, set: set, dir: 1) : Edge(p: q, q: p, set: set, dir: -1))
            }
        }
    }
    guard !edges.isEmpty else { return [] }
    // slab boundaries: vertex x's and crossing x's
    var xs: [CGFloat] = []
    for e in edges { xs.append(e.p.x); xs.append(e.q.x) }
    let order = edges.indices.sorted { edges[$0].p.x < edges[$1].p.x }
    for (k, i) in order.enumerated() {
        let e = edges[i]
        for j in order[(k + 1)...] {
            let f = edges[j]
            if f.p.x >= e.q.x { break }
            // segment intersection (proper crossings inside both)
            let r = CGPoint(x: e.q.x - e.p.x, y: e.q.y - e.p.y), s = CGPoint(x: f.q.x - f.p.x, y: f.q.y - f.p.y)
            let den = r.x * s.y - r.y * s.x
            if abs(den) < 1e-12 { continue }
            let w = CGPoint(x: f.p.x - e.p.x, y: f.p.y - e.p.y)
            let t = (w.x * s.y - w.y * s.x) / den, u = (w.x * r.y - w.y * r.x) / den
            if t > 1e-12 && t < 1 - 1e-12 && u > 1e-12 && u < 1 - 1e-12 { xs.append(e.p.x + t * r.x) }
        }
    }
    xs.sort()
    var bx: [CGFloat] = []
    for x in xs where bx.last.map({ x - $0 > 1e-9 }) ?? true { bx.append(x) }
    guard bx.count >= 2 else { return [] }
    // y of an edge at a slab boundary, computed once (so neighbouring slabs share exact points)
    // (end points within the boundary's tolerance give their own y; values a rounding error apart, like two edges
    // at their crossing, are snapped to one)
    var yCache: [Int: CGFloat] = [:]
    var snapped: [[CGFloat]] = Array(repeating: [], count: bx.count)
    func y(_ ei: Int, _ k: Int) -> CGFloat {
        let key = ei * bx.count + k
        if let v = yCache[key] { return v }
        let e = edges[ei], x = bx[k]
        var v: CGFloat = x <= e.p.x + 1e-9 ? e.p.y : x >= e.q.x - 1e-9 ? e.q.y : e.p.y + (e.q.y - e.p.y) * (x - e.p.x) / (e.q.x - e.p.x)
        if let c = snapped[k].first(where: { abs($0 - v) < 1e-7 }) { v = c } else { snapped[k].append(v) }
        yCache[key] = v
        return v
    }
    func inside(_ w: Int, _ eo: Bool) -> Bool { eo ? w & 1 != 0 : w != 0 }
    func keep(_ ia: Bool, _ ib: Bool) -> Bool {
        switch op {
        case .union: return ia || ib
        case .intersection: return ia && ib
        case .subtract: return ia && !ib
        case .xor: return ia != ib
        case .normalize: return ia
        }
    }
    // kept runs per slab: (top edge, bottom edge)
    var runs: [[(Int, Int)]] = Array(repeating: [], count: bx.count - 1)
    let byStart = edges.indices.sorted { edges[$0].p.x < edges[$1].p.x }
    var active: [Int] = [], next = 0
    for k in 0..<(bx.count - 1) {
        let x0 = bx[k], x1 = bx[k + 1]      // (no edges cross between them)
        while next < byStart.count, edges[byStart[next]].p.x <= x0 + 1e-9 { active.append(byStart[next]); next += 1 }
        active.removeAll { edges[$0].q.x <= x0 + 1e-9 }
        let span = active.filter { edges[$0].p.x <= x0 + 1e-9 && edges[$0].q.x >= x1 - 1e-9 }
        let sorted = span.sorted { (y($0, k) + y($0, k + 1)) < (y($1, k) + y($1, k + 1)) }
        var wa = 0, wb = 0, open: Int? = nil
        for (i, ei) in sorted.enumerated() {
            if edges[ei].set == 0 { wa += edges[ei].dir } else { wb += edges[ei].dir }
            let kept = i + 1 < sorted.count && keep(inside(wa, eoA), inside(wb, eoB))
            if kept && open == nil { open = ei }
            if !kept, let top = open { runs[k].append((top, ei)); open = nil }
        }
    }
    // boundary segments: tops run right to left, bottoms left to right, slab sides where the kept intervals of the
    // two slabs differ (left slab only: upwards; right slab only: downwards)
    struct Seg { let a: CGPoint, b: CGPoint }
    var segs: [Seg] = []
    for k in 0..<runs.count {
        for (t, bt) in runs[k] {
            segs.append(Seg(a: CGPoint(x: bx[k + 1], y: y(t, k + 1)), b: CGPoint(x: bx[k], y: y(t, k))))
            segs.append(Seg(a: CGPoint(x: bx[k], y: y(bt, k)), b: CGPoint(x: bx[k + 1], y: y(bt, k + 1))))
        }
    }
    for k in 0..<bx.count {
        let left: [(CGFloat, CGFloat)] = k > 0 ? runs[k - 1].map { (y($0.0, k), y($0.1, k)) } : []
        let right: [(CGFloat, CGFloat)] = k < runs.count ? runs[k].map { (y($0.0, k), y($0.1, k)) } : []
        // symmetric difference of the two interval sets
        var cuts = Set<CGFloat>()
        for (lo, hi) in left + right { cuts.insert(lo); cuts.insert(hi) }
        let ys = cuts.sorted()
        guard ys.count >= 2 else { continue }
        func covered(_ set: [(CGFloat, CGFloat)], _ m: CGFloat) -> Bool { set.contains { m > $0.0 && m < $0.1 } }
        for i in 0..<(ys.count - 1) where ys[i + 1] - ys[i] > 1e-9 {
            let m = (ys[i] + ys[i + 1]) / 2
            let l = covered(left, m), r = covered(right, m)
            if l && !r { segs.append(Seg(a: CGPoint(x: bx[k], y: ys[i + 1]), b: CGPoint(x: bx[k], y: ys[i]))) }
            if r && !l { segs.append(Seg(a: CGPoint(x: bx[k], y: ys[i]), b: CGPoint(x: bx[k], y: ys[i + 1]))) }
        }
    }
    // drop degenerate segments; chain the rest into loops
    struct Key: Hashable { let x: UInt64, y: UInt64; init(_ p: CGPoint) { x = Double(p.x).bitPattern; y = Double(p.y).bitPattern } }
    segs.removeAll { abs($0.a.x - $0.b.x) < 1e-12 && abs($0.a.y - $0.b.y) < 1e-12 }
    var from: [Key: [Int]] = [:]
    for (i, s) in segs.enumerated() { from[Key(s.a), default: []].append(i) }
    var used = [Bool](repeating: false, count: segs.count)
    var loops: [[CGPoint]] = []
    for i in segs.indices where !used[i] {
        var loop: [CGPoint] = [], cur = i
        while !used[cur] {
            used[cur] = true
            loop.append(segs[cur].a)
            guard let nexts = from[Key(segs[cur].b)], let n = nexts.first(where: { !used[$0] }) else { break }
            cur = n
        }
        // remove collinear points (pieces of one edge split at slab boundaries)
        var changed = true
        while changed && loop.count > 3 {
            changed = false
            var j = 0
            while j < loop.count && loop.count > 3 {
                let p = loop[(j + loop.count - 1) % loop.count], c = loop[j], n = loop[(j + 1) % loop.count]
                let cross = (c.x - p.x) * (n.y - c.y) - (c.y - p.y) * (n.x - c.x)
                let scale = max(1e-9, hypot(c.x - p.x, c.y - p.y) * hypot(n.x - c.x, n.y - c.y))
                if abs(cross) / scale < 1e-9 { loop.remove(at: j); changed = true } else { j += 1 }
            }
        }
        if loop.count >= 3 { loops.append(loop) }
    }
    return loops
}

// MARK: - Stroking

/// The outline of a stroke: segment rectangles, joins and caps as positively oriented polygons (filled with the
/// non-zero rule they cover the stroke); `_combine(.normalize)` merges them into clean outlines.
func _strokePolygons(_ lines: [([CGPoint], Bool)], _ s: StrokeStyle) -> [[CGPoint]] {
    let hw = max(0, s.lineWidth / 2)
    guard hw > 0 else { return [] }
    var out: [[CGPoint]] = []
    func oriented(_ poly: [CGPoint]) -> [CGPoint] {
        var area: CGFloat = 0
        for i in 0..<poly.count { let a = poly[i], b = poly[(i + 1) % poly.count]; area += a.x * b.y - b.x * a.y }
        return area < 0 ? poly.reversed() : poly
    }
    func circle(_ c: CGPoint) -> [CGPoint] {
        let n = max(8, min(48, Int((2 * .pi * hw / 1.5).rounded(.up))))
        return (0..<n).map { i in let a = 2 * Double.pi * Double(i) / Double(n); return CGPoint(x: c.x + hw * cos(a), y: c.y + hw * sin(a)) }
    }
    // dashes: split the polylines into the "on" pieces
    var pieces: [([CGPoint], Bool)] = lines
    let dashes = s.dash.filter { $0 >= 0 }
    if !dashes.isEmpty, dashes.reduce(0, +) > 0 {
        pieces = []
        for (pts, closed) in lines {
            var path = pts
            if closed, let f = pts.first { path.append(f) }
            var di = 0, left = dashes[0], on = true
            var phase = s.dashPhase.truncatingRemainder(dividingBy: dashes.reduce(0, +))
            while phase > 0 { let d = min(phase, left); left -= d; phase -= d; if left <= 0 { di = (di + 1) % dashes.count; left = dashes[di]; on.toggle() } }
            var cur: [CGPoint] = on ? [path[0]] : []
            for i in 1..<max(1, path.count) {
                var a = path[i - 1]
                let b = path[i]
                var segLen = hypot(b.x - a.x, b.y - a.y)
                while segLen > 0 {
                    let d = min(segLen, left)
                    let t = d / segLen
                    let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                    if on { cur.append(p) }
                    segLen -= d; left -= d; a = p
                    if left <= 1e-9 {
                        if on, cur.count >= 1 { pieces.append((cur, false)) }
                        di = (di + 1) % dashes.count; left = dashes[di]; on.toggle()
                        cur = on ? [p] : []
                    }
                }
            }
            if on, cur.count >= 2 { pieces.append((cur, false)) }
        }
    }
    for (raw, closed) in pieces {
        let pts = raw
        if pts.count == 1 || (pts.count == 2 && hypot(pts[1].x - pts[0].x, pts[1].y - pts[0].y) < 1e-9) {
            // a zero-length line: round caps draw a dot, square caps a square
            if s.lineCap == .round { out.append(oriented(circle(pts[0]))) }
            else if s.lineCap == .square { let p = pts[0]; out.append(oriented([CGPoint(x: p.x - hw, y: p.y - hw), CGPoint(x: p.x + hw, y: p.y - hw), CGPoint(x: p.x + hw, y: p.y + hw), CGPoint(x: p.x - hw, y: p.y + hw)])) }
            continue
        }
        let n = pts.count
        let segCount = closed ? n : n - 1
        func normal(_ i: Int) -> CGPoint {
            let a = pts[i], b = pts[(i + 1) % n]
            let l = max(1e-12, hypot(b.x - a.x, b.y - a.y))
            return CGPoint(x: -(b.y - a.y) / l * hw, y: (b.x - a.x) / l * hw)
        }
        for i in 0..<segCount {
            let a = pts[i], b = pts[(i + 1) % n], m = normal(i)
            out.append(oriented([CGPoint(x: a.x + m.x, y: a.y + m.y), CGPoint(x: b.x + m.x, y: b.y + m.y), CGPoint(x: b.x - m.x, y: b.y - m.y), CGPoint(x: a.x - m.x, y: a.y - m.y)]))
        }
        // joins at interior vertices (all of them for closed lines)
        let joins = closed ? Array(0..<n) : Array(1..<(n - 1))
        for v in joins {
            let i0 = (v - 1 + n) % n, i1 = v
            let c = pts[v], m0 = normal(i0), m1 = normal(i1)
            let cross = m0.x * m1.y - m0.y * m1.x
            if abs(cross) < 1e-12 && m0.x * m1.x + m0.y * m1.y > 0 { continue }       // straight on
            let sgn: CGFloat = cross > 0 ? -1 : 1                                       // the outer side of the turn
            let o0 = CGPoint(x: c.x + sgn * m0.x, y: c.y + sgn * m0.y), o1 = CGPoint(x: c.x + sgn * m1.x, y: c.y + sgn * m1.y)
            switch s.lineJoin {
            case .round: out.append(oriented(circle(c)))
            case .miter:
                // the miter point: where the two outer offset lines meet
                let d0 = CGPoint(x: pts[v].x - pts[i0].x, y: pts[v].y - pts[i0].y), d1 = CGPoint(x: pts[(v + 1) % n].x - pts[v].x, y: pts[(v + 1) % n].y - pts[v].y)
                let den = d0.x * d1.y - d0.y * d1.x
                var miter: CGPoint?
                if abs(den) > 1e-12 {
                    let w = CGPoint(x: o1.x - o0.x, y: o1.y - o0.y)
                    let t = (w.x * d1.y - w.y * d1.x) / den
                    miter = CGPoint(x: o0.x + d0.x * t, y: o0.y + d0.y * t)
                }
                if let mp = miter, hypot(mp.x - c.x, mp.y - c.y) / hw <= s.miterLimit { out.append(oriented([c, o0, mp, o1])) }
                else { out.append(oriented([c, o0, o1])) }
            default: out.append(oriented([c, o0, o1]))                                 // bevel
            }
        }
        if !closed {
            for (end, inward) in [(pts[0], CGPoint(x: pts[1].x - pts[0].x, y: pts[1].y - pts[0].y)), (pts[n - 1], CGPoint(x: pts[n - 2].x - pts[n - 1].x, y: pts[n - 2].y - pts[n - 1].y))] {
                switch s.lineCap {
                case .round: out.append(oriented(circle(end)))
                case .square:
                    let l = max(1e-12, hypot(inward.x, inward.y)), d = CGPoint(x: -inward.x / l * hw, y: -inward.y / l * hw), m = CGPoint(x: -d.y, y: d.x)
                    out.append(oriented([CGPoint(x: end.x + m.x, y: end.y + m.y), CGPoint(x: end.x + m.x + d.x, y: end.y + m.y + d.y),
                                         CGPoint(x: end.x - m.x + d.x, y: end.y - m.y + d.y), CGPoint(x: end.x - m.x, y: end.y - m.y)]))
                default: break
                }
            }
        }
    }
    return out
}

// MARK: - Line operations

/// The parts of `lines` inside (or outside) the region `region` (fill rule `eo`), as open polylines.
func _clipLines(_ lines: [([CGPoint], Bool)], region: [[CGPoint]], eo: Bool, keepInside: Bool) -> [[CGPoint]] {
    let regionPath = Path._polygons(region)
    var out: [[CGPoint]] = []
    for (pts, closed) in lines where pts.count >= 2 {
        var path = pts
        if closed, let f = pts.first { path.append(f) }
        var cur: [CGPoint] = []
        for i in 1..<path.count {
            let a = path[i - 1], b = path[i]
            // the parameters where the segment crosses the region's edges
            var ts: [CGFloat] = [0, 1]
            for poly in region where poly.count >= 2 {
                for j in 0..<poly.count {
                    let p = poly[j], q = poly[(j + 1) % poly.count]
                    let r = CGPoint(x: b.x - a.x, y: b.y - a.y), s = CGPoint(x: q.x - p.x, y: q.y - p.y)
                    let den = r.x * s.y - r.y * s.x
                    if abs(den) < 1e-12 { continue }
                    let w = CGPoint(x: p.x - a.x, y: p.y - a.y)
                    let t = (w.x * s.y - w.y * s.x) / den, u = (w.x * r.y - w.y * r.x) / den
                    if t > 0 && t < 1 && u >= 0 && u <= 1 { ts.append(t) }
                }
            }
            ts.sort()
            for k in 0..<(ts.count - 1) where ts[k + 1] - ts[k] > 1e-9 {
                let p0 = CGPoint(x: a.x + (b.x - a.x) * ts[k], y: a.y + (b.y - a.y) * ts[k])
                let p1 = CGPoint(x: a.x + (b.x - a.x) * ts[k + 1], y: a.y + (b.y - a.y) * ts[k + 1])
                let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
                if regionPath.contains(mid, eoFill: eo) == keepInside {
                    if cur.isEmpty { cur = [p0] }
                    cur.append(p1)
                } else if !cur.isEmpty { out.append(cur); cur = [] }
            }
        }
        if cur.count >= 2 { out.append(cur) }
    }
    return out
}

extension Path {
    func _regions() -> [[CGPoint]] { _flattened().map(\.0).filter { $0.count >= 3 } }
    func _boolean(_ other: Path, eoA: Bool, eoB: Bool, _ op: _PathOp) -> Path {
        Path._polygons(_combine(_regions(), eoA: eoA, other._regions(), eoB: eoB, op))
    }
    /// The outline of this path stroked with `style` (filled, it draws the stroke).
    public func strokedPath(_ style: StrokeStyle) -> Path {
        Path._polygons(_combine(_strokePolygons(_flattened(), style), eoA: false, [], eoB: false, .normalize))
    }
    /// The same region as non-overlapping outlines (holes reversed).
    public func normalized(eoFill: Bool = true) -> Path { _boolean(Path(), eoA: eoFill, eoB: false, .normalize) }
    public func union(_ other: Path, eoFill: Bool = false) -> Path { _boolean(other, eoA: eoFill, eoB: eoFill, .union) }
    public func intersection(_ other: Path, eoFill: Bool = false) -> Path { _boolean(other, eoA: eoFill, eoB: eoFill, .intersection) }
    public func subtracting(_ other: Path, eoFill: Bool = false) -> Path { _boolean(other, eoA: eoFill, eoB: eoFill, .subtract) }
    public func symmetricDifference(_ other: Path, eoFill: Bool = false) -> Path { _boolean(other, eoA: eoFill, eoB: eoFill, .xor) }
    /// The lines of this path that are inside `other`'s region.
    public func lineIntersection(_ other: Path, eoFill: Bool = false) -> Path {
        var p = Path()
        for l in _clipLines(_flattened(), region: other._regions(), eo: eoFill, keepInside: true) { p.addLines(l) }
        return p
    }
    /// The lines of this path that are outside `other`'s region.
    public func lineSubtraction(_ other: Path, eoFill: Bool = false) -> Path {
        var p = Path()
        for l in _clipLines(_flattened(), region: other._regions(), eo: eoFill, keepInside: false) { p.addLines(l) }
        return p
    }
}

// MARK: - Shapes

/// Two shapes combined by a boolean operation (in the same rect).
public struct _BooleanShape<A: Shape, B: Shape>: Shape {
    var a: A, b: B
    let op: Int, eo: Bool
    public func path(in rect: CGRect) -> Path {
        let pa = a.path(in: rect), pb = b.path(in: rect)
        switch op {
        case 0: return pa.union(pb, eoFill: eo)
        case 1: return pa.intersection(pb, eoFill: eo)
        case 2: return pa.subtracting(pb, eoFill: eo)
        case 3: return pa.symmetricDifference(pb, eoFill: eo)
        case 4: return pa.lineIntersection(pb, eoFill: eo)
        default: return pa.lineSubtraction(pb, eoFill: eo)
        }
    }
    public var animatableData: AnimatablePair<A.AnimatableData, B.AnimatableData> {
        get { AnimatablePair(a.animatableData, b.animatableData) }
        set { a.animatableData = newValue.first; b.animatableData = newValue.second }
    }
}
extension Shape {
    public func union<T: Shape>(_ other: T, eoFill: Bool = false) -> _BooleanShape<Self, T> { _BooleanShape(a: self, b: other, op: 0, eo: eoFill) }
    public func intersection<T: Shape>(_ other: T, eoFill: Bool = false) -> _BooleanShape<Self, T> { _BooleanShape(a: self, b: other, op: 1, eo: eoFill) }
    public func subtracting<T: Shape>(_ other: T, eoFill: Bool = false) -> _BooleanShape<Self, T> { _BooleanShape(a: self, b: other, op: 2, eo: eoFill) }
    public func symmetricDifference<T: Shape>(_ other: T, eoFill: Bool = false) -> _BooleanShape<Self, T> { _BooleanShape(a: self, b: other, op: 3, eo: eoFill) }
    public func lineIntersection<T: Shape>(_ other: T, eoFill: Bool = false) -> _BooleanShape<Self, T> { _BooleanShape(a: self, b: other, op: 4, eo: eoFill) }
    public func lineSubtraction<T: Shape>(_ other: T, eoFill: Bool = false) -> _BooleanShape<Self, T> { _BooleanShape(a: self, b: other, op: 5, eo: eoFill) }
}
