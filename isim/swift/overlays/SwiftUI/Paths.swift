// isim SwiftUI: Path — an outline of lines and Bézier curves (arcs, ellipses and rounded rects become cubic
// curves, like Core Graphics). Paths draw as shapes, build CGPaths, trim, transform, hit-test and print
// in SwiftUI's "x y m x y l … h" string form.
import UIKit

public struct Path: Equatable, LosslessStringConvertible, @unchecked Sendable {
    public enum Element: Equatable, Sendable {
        case move(to: CGPoint)
        case line(to: CGPoint)
        case quadCurve(to: CGPoint, control: CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case closeSubpath
    }
    var elements: [Element] = []

    public init() {}
    public init(_ callback: (inout Path) -> ()) { var p = Path(); callback(&p); self = p }
    public init(_ rect: CGRect) { addRect(rect) }
    public init(roundedRect rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {
        addRoundedRect(in: rect, cornerSize: cornerSize, style: style)
    }
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {
        addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: style)
    }
    public init(roundedRect rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) {
        addRoundedRect(in: rect, cornerRadii: cornerRadii, style: style)
    }
    public init(ellipseIn rect: CGRect) { addEllipse(in: rect) }
    public init(_ path: CGPath) {
        var els: [Element] = []
        path.applyWithBlock { e in
            let p = e.pointee.points
            switch e.pointee.type {
            case .moveToPoint: els.append(.move(to: p[0]))
            case .addLineToPoint: els.append(.line(to: p[0]))
            case .addQuadCurveToPoint: els.append(.quadCurve(to: p[1], control: p[0]))
            case .addCurveToPoint: els.append(.curve(to: p[2], control1: p[0], control2: p[1]))
            case .closeSubpath: els.append(.closeSubpath)
            @unknown default: break
            }
        }
        elements = els
    }
    public init(_ path: CGMutablePath) { self.init(path as CGPath) }

    /// Parses SwiftUI's path string form ("x y m", "x y l", "cx cy x y q", "c1x c1y c2x c2y x y c", "h").
    public init?(_ string: String) {
        var nums: [CGFloat] = []
        for tok in string.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
            if let v = Double(tok) { nums.append(v); continue }
            func pt(_ i: Int) -> CGPoint { CGPoint(x: nums[i], y: nums[i + 1]) }
            switch tok {
            case "m": guard nums.count == 2 else { return nil }; elements.append(.move(to: pt(0)))
            case "l": guard nums.count == 2 else { return nil }; elements.append(.line(to: pt(0)))
            case "q": guard nums.count == 4 else { return nil }; elements.append(.quadCurve(to: pt(2), control: pt(0)))
            case "c": guard nums.count == 6 else { return nil }; elements.append(.curve(to: pt(4), control1: pt(0), control2: pt(2)))
            case "h": guard nums.isEmpty else { return nil }; elements.append(.closeSubpath)
            default: return nil
            }
            nums = []
        }
        if !nums.isEmpty { return nil }
    }
    public var description: String {
        func f(_ v: CGFloat) -> String { v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : String(describing: v) }
        func p(_ q: CGPoint) -> String { f(q.x) + " " + f(q.y) }
        return elements.map { e -> String in
            switch e {
            case .move(let a): return p(a) + " m"
            case .line(let a): return p(a) + " l"
            case .quadCurve(let a, let c): return p(c) + " " + p(a) + " q"
            case .curve(let a, let c1, let c2): return p(c1) + " " + p(c2) + " " + p(a) + " c"
            case .closeSubpath: return "h"
            }
        }.joined(separator: " ")
    }

    // MARK: building

    public var isEmpty: Bool { elements.isEmpty }
    public var currentPoint: CGPoint? {
        var start: CGPoint?, cur: CGPoint?
        for e in elements {
            switch e {
            case .move(let p): start = p; cur = p
            case .line(let p), .quadCurve(let p, _), .curve(let p, _, _): cur = p
            case .closeSubpath: cur = start
            }
        }
        return cur
    }
    public mutating func move(to p: CGPoint) { elements.append(.move(to: p)) }
    public mutating func addLine(to p: CGPoint) {
        if currentPoint == nil { elements.append(.move(to: p)) } else { elements.append(.line(to: p)) }
    }
    public mutating func addQuadCurve(to p: CGPoint, control: CGPoint) {
        if currentPoint == nil { elements.append(.move(to: p)) } else { elements.append(.quadCurve(to: p, control: control)) }
    }
    public mutating func addCurve(to p: CGPoint, control1: CGPoint, control2: CGPoint) {
        if currentPoint == nil { elements.append(.move(to: p)) } else { elements.append(.curve(to: p, control1: control1, control2: control2)) }
    }
    public mutating func closeSubpath() { if !elements.isEmpty { elements.append(.closeSubpath) } }
    public mutating func addLines(_ points: [CGPoint]) {
        for (i, p) in points.enumerated() { if i == 0 { move(to: p) } else { elements.append(.line(to: p)) } }
    }
    public mutating func addRect(_ r: CGRect, transform: CGAffineTransform = .identity) {
        let r = r.standardized
        var p = Path()
        p.elements = [.move(to: CGPoint(x: r.minX, y: r.minY)), .line(to: CGPoint(x: r.maxX, y: r.minY)),
                      .line(to: CGPoint(x: r.maxX, y: r.maxY)), .line(to: CGPoint(x: r.minX, y: r.maxY)), .closeSubpath]
        addPath(p, transform: transform)
    }
    public mutating func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) { for r in rects { addRect(r, transform: transform) } }
    public mutating func addEllipse(in r: CGRect, transform: CGAffineTransform = .identity) {
        let r = r.standardized
        let k: CGFloat = 0.5522847498, cx = r.midX, cy = r.midY, rx = r.width / 2, ry = r.height / 2
        var p = Path()
        // starts at 3 o'clock and runs clockwise on screen (y down), like Core Graphics
        p.elements = [
            .move(to: CGPoint(x: cx + rx, y: cy)),
            .curve(to: CGPoint(x: cx, y: cy + ry), control1: CGPoint(x: cx + rx, y: cy + ry * k), control2: CGPoint(x: cx + rx * k, y: cy + ry)),
            .curve(to: CGPoint(x: cx - rx, y: cy), control1: CGPoint(x: cx - rx * k, y: cy + ry), control2: CGPoint(x: cx - rx, y: cy + ry * k)),
            .curve(to: CGPoint(x: cx, y: cy - ry), control1: CGPoint(x: cx - rx, y: cy - ry * k), control2: CGPoint(x: cx - rx * k, y: cy - ry)),
            .curve(to: CGPoint(x: cx + rx, y: cy), control1: CGPoint(x: cx + rx * k, y: cy - ry), control2: CGPoint(x: cx + rx, y: cy - ry * k)),
            .closeSubpath]
        addPath(p, transform: transform)
    }
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {
        let r = rect.standardized
        let rx = min(max(0, cornerSize.width), r.width / 2), ry = min(max(0, cornerSize.height), r.height / 2)
        let c = CGSize(width: rx, height: ry)
        _addRoundedRect(r, tl: c, tr: c, br: c, bl: c, transform: transform)
    }
    public mutating func addRoundedRect(in rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {
        let r = rect.standardized
        // radii larger than the rect scale down together (like SwiftUI)
        let top = cornerRadii.topLeading + cornerRadii.topTrailing, bottom = cornerRadii.bottomLeading + cornerRadii.bottomTrailing
        let left = cornerRadii.topLeading + cornerRadii.bottomLeading, right = cornerRadii.topTrailing + cornerRadii.bottomTrailing
        var f: CGFloat = 1
        for (sum, len) in [(top, r.width), (bottom, r.width), (left, r.height), (right, r.height)] where sum > len && sum > 0 { f = min(f, len / sum) }
        func s(_ v: CGFloat) -> CGSize { CGSize(width: max(0, v * f), height: max(0, v * f)) }
        _addRoundedRect(r, tl: s(cornerRadii.topLeading), tr: s(cornerRadii.topTrailing), br: s(cornerRadii.bottomTrailing), bl: s(cornerRadii.bottomLeading), transform: transform)
    }
    mutating func _addRoundedRect(_ r: CGRect, tl: CGSize, tr: CGSize, br: CGSize, bl: CGSize, transform: CGAffineTransform) {
        let k: CGFloat = 0.5522847498
        var p = Path()
        p.elements.append(.move(to: CGPoint(x: r.minX + tl.width, y: r.minY)))
        p.elements.append(.line(to: CGPoint(x: r.maxX - tr.width, y: r.minY)))
        if tr.width > 0 || tr.height > 0 {
            p.elements.append(.curve(to: CGPoint(x: r.maxX, y: r.minY + tr.height), control1: CGPoint(x: r.maxX - tr.width + tr.width * k, y: r.minY),
                                     control2: CGPoint(x: r.maxX, y: r.minY + tr.height - tr.height * k)))
        }
        p.elements.append(.line(to: CGPoint(x: r.maxX, y: r.maxY - br.height)))
        if br.width > 0 || br.height > 0 {
            p.elements.append(.curve(to: CGPoint(x: r.maxX - br.width, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.maxY - br.height + br.height * k),
                                     control2: CGPoint(x: r.maxX - br.width + br.width * k, y: r.maxY)))
        }
        p.elements.append(.line(to: CGPoint(x: r.minX + bl.width, y: r.maxY)))
        if bl.width > 0 || bl.height > 0 {
            p.elements.append(.curve(to: CGPoint(x: r.minX, y: r.maxY - bl.height), control1: CGPoint(x: r.minX + bl.width - bl.width * k, y: r.maxY),
                                     control2: CGPoint(x: r.minX, y: r.maxY - bl.height + bl.height * k)))
        }
        p.elements.append(.line(to: CGPoint(x: r.minX, y: r.minY + tl.height)))
        if tl.width > 0 || tl.height > 0 {
            p.elements.append(.curve(to: CGPoint(x: r.minX + tl.width, y: r.minY), control1: CGPoint(x: r.minX, y: r.minY + tl.height - tl.height * k),
                                     control2: CGPoint(x: r.minX + tl.width - tl.width * k, y: r.minY)))
        }
        p.elements.append(.closeSubpath)
        addPath(p, transform: transform)
    }
    /// Core Graphics semantics: `clockwise` is in a y-up space, so on screen (y down) `clockwise: true` turns counterclockwise.
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool, transform: CGAffineTransform = .identity) {
        var d = endAngle.radians - startAngle.radians
        let twoPi = 2 * Double.pi
        if clockwise { while d > 0 { d -= twoPi }; d = max(d, -twoPi) } else { while d < 0 { d += twoPi }; d = min(d, twoPi) }
        _addArc(center: center, radius: radius, start: startAngle.radians, delta: d, transform: transform)
    }
    public mutating func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: Angle, delta: Angle, transform: CGAffineTransform = .identity) {
        _addArc(center: center, radius: radius, start: startAngle.radians, delta: delta.radians, transform: transform)
    }
    mutating func _addArc(center c: CGPoint, radius: CGFloat, start: Double, delta: Double, transform: CGAffineTransform) {
        func pt(_ a: Double) -> CGPoint { CGPoint(x: c.x + radius * Foundation.cos(a), y: c.y + radius * Foundation.sin(a)).applying(transform) }
        let p0 = pt(start)
        if currentPoint == nil { elements.append(.move(to: p0)) } else { elements.append(.line(to: p0)) }
        let n = max(1, Int((abs(delta) / (Double.pi / 2)).rounded(.up)))
        let step = delta / Double(n), k = 4.0 / 3.0 * Foundation.tan(step / 4)
        var a = start
        for _ in 0..<n {
            let b = a + step
            let p1 = CGPoint(x: c.x + radius * (Foundation.cos(a) - k * Foundation.sin(a)), y: c.y + radius * (Foundation.sin(a) + k * Foundation.cos(a))).applying(transform)
            let p2 = CGPoint(x: c.x + radius * (Foundation.cos(b) + k * Foundation.sin(b)), y: c.y + radius * (Foundation.sin(b) - k * Foundation.cos(b))).applying(transform)
            elements.append(.curve(to: pt(b), control1: p1, control2: p2))
            a = b
        }
    }
    /// An arc tangent to the lines (current point → tangent1End) and (tangent1End → tangent2End).
    public mutating func addArc(tangent1End p1: CGPoint, tangent2End p2: CGPoint, radius: CGFloat, transform: CGAffineTransform = .identity) {
        guard let p0t = currentPoint else { move(to: p1.applying(transform)); return }
        let inv = transform.inverted()
        let p0 = p0t.applying(inv)
        let v1 = CGPoint(x: p0.x - p1.x, y: p0.y - p1.y), v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let l1 = (v1.x * v1.x + v1.y * v1.y).squareRoot(), l2 = (v2.x * v2.x + v2.y * v2.y).squareRoot()
        guard l1 > 0, l2 > 0, radius > 0 else { addLine(to: p1.applying(transform)); return }
        let u1 = CGPoint(x: v1.x / l1, y: v1.y / l1), u2 = CGPoint(x: v2.x / l2, y: v2.y / l2)
        let cosA = max(-1, min(1, u1.x * u2.x + u1.y * u2.y)), angle = Foundation.acos(cosA)
        guard angle > 1e-6, angle < Double.pi - 1e-6 else { addLine(to: p1.applying(transform)); return }
        let dist = radius / Foundation.tan(angle / 2)
        let t1 = CGPoint(x: p1.x + u1.x * dist, y: p1.y + u1.y * dist), t2 = CGPoint(x: p1.x + u2.x * dist, y: p1.y + u2.y * dist)
        let bis = CGPoint(x: u1.x + u2.x, y: u1.y + u2.y), bl = (bis.x * bis.x + bis.y * bis.y).squareRoot()
        let cd = radius / Foundation.sin(angle / 2)
        let center = CGPoint(x: p1.x + bis.x / bl * cd, y: p1.y + bis.y / bl * cd)
        let a0 = Foundation.atan2(t1.y - center.y, t1.x - center.x), a1 = Foundation.atan2(t2.y - center.y, t2.x - center.x)
        var d = a1 - a0
        while d > Double.pi { d -= 2 * Double.pi }
        while d < -Double.pi { d += 2 * Double.pi }
        _addArc(center: center, radius: radius, start: a0, delta: d, transform: transform)
    }
    public mutating func addPath(_ path: Path, transform: CGAffineTransform = .identity) {
        if transform.isIdentity { elements += path.elements; return }
        elements += path.applying(transform).elements
    }

    // MARK: queries & transforms

    public func forEach(_ body: (Element) -> Void) { for e in elements { body(e) } }
    public func applying(_ t: CGAffineTransform) -> Path {
        var p = Path()
        p.elements = elements.map { e in
            switch e {
            case .move(let a): return .move(to: a.applying(t))
            case .line(let a): return .line(to: a.applying(t))
            case .quadCurve(let a, let c): return .quadCurve(to: a.applying(t), control: c.applying(t))
            case .curve(let a, let c1, let c2): return .curve(to: a.applying(t), control1: c1.applying(t), control2: c2.applying(t))
            case .closeSubpath: return .closeSubpath
            }
        }
        return p
    }
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> Path { applying(CGAffineTransform(translationX: dx, y: dy)) }
    public var cgPath: CGPath {
        let m = CGMutablePath()
        for e in elements {
            switch e {
            case .move(let a): m.move(to: a)
            case .line(let a): m.addLine(to: a)
            case .quadCurve(let a, let c): m.addQuadCurve(to: a, control: c)
            case .curve(let a, let c1, let c2): m.addCurve(to: a, control1: c1, control2: c2)
            case .closeSubpath: m.closeSubpath()
            }
        }
        return m
    }
    /// Polylines approximating each subpath (curves sampled), and whether each is closed.
    func _polylines(samples: Int = 16) -> [([CGPoint], Bool)] {
        var out: [([CGPoint], Bool)] = []
        var cur: [CGPoint] = []
        func flush(_ closed: Bool) { if !cur.isEmpty { out.append((cur, closed)) }; cur = [] }
        var last = CGPoint.zero
        for e in elements {
            switch e {
            case .move(let a): flush(false); cur = [a]; last = a
            case .line(let a): if cur.isEmpty { cur = [last] }; cur.append(a); last = a
            case .quadCurve(let a, let c):
                if cur.isEmpty { cur = [last] }
                for i in 1...samples { cur.append(_quad(last, c, a, CGFloat(i) / CGFloat(samples))) }
                last = a
            case .curve(let a, let c1, let c2):
                if cur.isEmpty { cur = [last] }
                for i in 1...samples { cur.append(_cubic(last, c1, c2, a, CGFloat(i) / CGFloat(samples))) }
                last = a
            case .closeSubpath:
                let start = cur.first ?? last
                flush(true); last = start
            }
        }
        flush(false)
        return out
    }
    public var boundingRect: CGRect {
        var minX = CGFloat.infinity, minY = CGFloat.infinity, maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for (pts, _) in _polylines() { for p in pts { minX = min(minX, p.x); minY = min(minY, p.y); maxX = max(maxX, p.x); maxY = max(maxY, p.y) } }
        if minX > maxX { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    public func contains(_ p: CGPoint, eoFill: Bool = false) -> Bool {
        var winding = 0, crossings = 0
        for (pts, _) in _polylines() where pts.count > 1 {
            for i in 0..<pts.count {
                let a = pts[i], b = pts[(i + 1) % pts.count]          // every subpath is implicitly closed for filling
                if (a.y <= p.y) != (b.y <= p.y) {
                    let x = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
                    if x > p.x { crossings += 1; winding += b.y > a.y ? 1 : -1 }
                }
            }
        }
        return eoFill ? crossings % 2 == 1 : winding != 0
    }

    /// The part of the outline between two fractions of its length (curves split exactly).
    public func trimmedPath(from: CGFloat, to: CGFloat) -> Path {
        let from = max(0, min(1, from)), to = max(0, min(1, to))
        if from <= 0 && to >= 1 { return self }
        guard to > from else { return Path() }
        // segments as cubics (lines and quads promoted)
        struct Seg { var p0, c1, c2, p1: CGPoint; var isLine: Bool; var closes: Bool; var newSub: Bool; var len: CGFloat; var table: [CGFloat] }
        var segs: [Seg] = []
        var start = CGPoint.zero, last = CGPoint.zero, newSub = true
        func add(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, line: Bool, closes: Bool = false) {
            var table: [CGFloat] = [0], acc: CGFloat = 0, prev = p0
            let n = line ? 1 : 24
            for i in 1...n {
                let q = line ? p1 : _cubic(p0, c1, c2, p1, CGFloat(i) / CGFloat(n))
                acc += ((q.x - prev.x) * (q.x - prev.x) + (q.y - prev.y) * (q.y - prev.y)).squareRoot(); table.append(acc); prev = q
            }
            segs.append(Seg(p0: p0, c1: c1, c2: c2, p1: p1, isLine: line, closes: closes, newSub: newSub, len: acc, table: table))
            newSub = false
        }
        for e in elements {
            switch e {
            case .move(let a): start = a; last = a; newSub = true
            case .line(let a): add(last, last, a, a, line: true); last = a
            case .quadCurve(let a, let c):
                add(last, CGPoint(x: last.x + 2 / 3 * (c.x - last.x), y: last.y + 2 / 3 * (c.y - last.y)),
                    CGPoint(x: a.x + 2 / 3 * (c.x - a.x), y: a.y + 2 / 3 * (c.y - a.y)), a, line: false); last = a
            case .curve(let a, let c1, let c2): add(last, c1, c2, a, line: false); last = a
            case .closeSubpath: add(last, last, start, start, line: true, closes: true); last = start; newSub = true
            }
        }
        let total = segs.reduce(0) { $0 + $1.len }
        guard total > 0 else { return Path() }
        let a = from * total, b = to * total
        var out = Path(), pos: CGFloat = 0, penDown = false
        func param(_ s: Seg, _ d: CGFloat) -> CGFloat {         // arc length -> curve parameter
            if s.isLine || s.len <= 0 { return s.len > 0 ? d / s.len : 0 }
            let n = s.table.count - 1
            for i in 1...n where s.table[i] >= d {
                let span = s.table[i] - s.table[i - 1]
                return (CGFloat(i - 1) + (span > 0 ? (d - s.table[i - 1]) / span : 0)) / CGFloat(n)
            }
            return 1
        }
        for s in segs {
            defer { pos += s.len }
            if s.newSub { penDown = false }
            let s0 = pos, s1 = pos + s.len
            if s1 <= a || s0 >= b || s.len <= 0 { if s0 >= b { break }; continue }
            let t0 = a > s0 ? param(s, a - s0) : 0, t1 = b < s1 ? param(s, b - s0) : 1
            let piece = _subcubic(s.p0, s.c1, s.c2, s.p1, t0, t1)
            if !penDown || t0 > 0 { out.elements.append(.move(to: piece.0)) }
            if s.isLine { out.elements.append(.line(to: piece.3)) }
            else { out.elements.append(.curve(to: piece.3, control1: piece.1, control2: piece.2)) }
            penDown = true
        }
        return out
    }
}

/// A path is a shape that draws itself (filled with the foreground style unless filled/stroked otherwise).
extension Path: Shape {
    public func path(in rect: CGRect) -> Path { self }
}

func _quad(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    return CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x, y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
}
func _cubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
    return CGPoint(x: a * p0.x + b * c1.x + c * c2.x + d * p1.x, y: a * p0.y + b * c1.y + c * c2.y + d * p1.y)
}
/// The part of a cubic between parameters t0 and t1 (de Casteljau).
func _subcubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, _ t0: CGFloat, _ t1: CGFloat) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
    func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
    func split(_ q: (CGPoint, CGPoint, CGPoint, CGPoint), _ t: CGFloat) -> ((CGPoint, CGPoint, CGPoint, CGPoint), (CGPoint, CGPoint, CGPoint, CGPoint)) {
        let ab = lerp(q.0, q.1, t), bc = lerp(q.1, q.2, t), cd = lerp(q.2, q.3, t)
        let abc = lerp(ab, bc, t), bcd = lerp(bc, cd, t), m = lerp(abc, bcd, t)
        return ((q.0, ab, abc, m), (m, bcd, cd, q.3))
    }
    var q = (p0, c1, c2, p1)
    if t1 < 1 { q = split(q, t1).0 }
    if t0 > 0 { q = split(q, t1 > 0 ? t0 / t1 : 0).1 }
    return q
}

/// Corner radii of an UnevenRoundedRectangle / Path(roundedRect:cornerRadii:).
public struct RectangleCornerRadii: Equatable, Animatable, Sendable {
    public var topLeading: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat, topTrailing: CGFloat
    public init(topLeading: CGFloat = 0, bottomLeading: CGFloat = 0, bottomTrailing: CGFloat = 0, topTrailing: CGFloat = 0) {
        self.topLeading = topLeading; self.bottomLeading = bottomLeading; self.bottomTrailing = bottomTrailing; self.topTrailing = topTrailing
    }
    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(topLeading, bottomLeading), AnimatablePair(bottomTrailing, topTrailing)) }
        set { topLeading = newValue.first.first; bottomLeading = newValue.first.second; bottomTrailing = newValue.second.first; topTrailing = newValue.second.second }
    }
}
