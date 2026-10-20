// isim Vision: the CPU image helpers its detectors share (adapted, isim's own code): grey levels, downscaling,
// Otsu's threshold, connected components, convex hulls and Douglas–Peucker simplification.
import CoreGraphics

/// A grey image, top row first, values 0 (black) ... 1 (white), the source composited over white.
struct _VNGray {
    let width: Int, height: Int
    var v: [Float]
    subscript(x: Int, y: Int) -> Float { v[y * width + x] }

    init(width: Int, height: Int, v: [Float]) { self.width = width; self.height = height; self.v = v }
    /// the image's luminance, downscaled (area average) so that its longer side is at most `maxSide` (0: full size)
    init(_ img: _VNImage, maxSide: Int = 0) {
        let s = maxSide > 0 ? min(1, Double(maxSide) / Double(max(img.width, img.height))) : 1
        let W = max(1, Int((Double(img.width) * s).rounded())), H = max(1, Int((Double(img.height) * s).rounded()))
        var out = [Float](repeating: 0, count: W * H)
        img.bgra.withUnsafeBufferPointer { p in
            for y in 0..<H {
                let y0 = y * img.height / H, y1 = max(y0 + 1, (y + 1) * img.height / H)
                for x in 0..<W {
                    let x0 = x * img.width / W, x1 = max(x0 + 1, (x + 1) * img.width / W)
                    var sum: Float = 0
                    for sy in y0..<y1 {
                        for sx in x0..<x1 {
                            let i = (sy * img.width + sx) * 4
                            let a = 255 - Float(p[i + 3])                     // premultiplied: over white adds (255 - alpha)
                            sum += 0.114 * (Float(p[i]) + a) + 0.587 * (Float(p[i + 1]) + a) + 0.299 * (Float(p[i + 2]) + a)
                        }
                    }
                    out[y * W + x] = sum / Float((y1 - y0) * (x1 - x0)) / 255
                }
            }
        }
        width = W; height = H; v = out
    }
    /// Otsu's threshold over a 256-bin histogram
    func otsu() -> Float {
        var hist = [Double](repeating: 0, count: 256)
        for g in v { hist[min(255, max(0, Int(g * 255)))] += 1 }
        let total = Double(v.count)
        var sumAll = 0.0
        for i in 0..<256 { sumAll += Double(i) * hist[i] }
        var wB = 0.0, sumB = 0.0, best = 0.0, t = 127
        for i in 0..<256 {
            wB += hist[i]
            if wB == 0 { continue }
            let wF = total - wB
            if wF == 0 { break }
            sumB += Double(i) * hist[i]
            let mB = sumB / wB, mF = (sumAll - sumB) / wF, between = wB * wF * (mB - mF) * (mB - mF)
            if between > best { best = between; t = i }
        }
        return (Float(t) + 0.5) / 255
    }
}

/// A connected component of a binary mask: its pixels' count, bounding box (pixels, top-left origin) and, per row,
/// its leftmost and rightmost pixel (enough for a convex hull).
struct _VNComponent {
    var count = 0
    var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
    var rows: [Int: (Int, Int)] = [:]
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var box: CGRect { CGRect(x: minX, y: minY, width: width, height: height) }
    mutating func add(_ x: Int, _ y: Int) {
        count += 1
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        if let r = rows[y] { rows[y] = (min(r.0, x), max(r.1, x)) } else { rows[y] = (x, x) }
    }
    mutating func merge(_ o: _VNComponent) {
        count += o.count
        minX = min(minX, o.minX); maxX = max(maxX, o.maxX); minY = min(minY, o.minY); maxY = max(maxY, o.maxY)
        for (y, r) in o.rows { if let s = rows[y] { rows[y] = (min(s.0, r.0), max(s.1, r.1)) } else { rows[y] = r } }
    }
    /// how many of the image's four edges the component touches
    func borders(_ w: Int, _ h: Int) -> Int { (minX == 0 ? 1 : 0) + (minY == 0 ? 1 : 0) + (maxX == w - 1 ? 1 : 0) + (maxY == h - 1 ? 1 : 0) }
    /// the convex hull of the pixels' squares (corners at pixel edges), counterclockwise on screen
    func hull() -> [CGPoint] {
        var pts: [CGPoint] = []
        for (y, r) in rows {
            pts.append(CGPoint(x: r.0, y: y)); pts.append(CGPoint(x: r.0, y: y + 1))
            pts.append(CGPoint(x: r.1 + 1, y: y)); pts.append(CGPoint(x: r.1 + 1, y: y + 1))
        }
        return _vnConvexHull(pts)
    }
}

/// 8-connected components of `mask` (true pixels), in scan order
func _vnComponents(_ mask: [Bool], _ w: Int, _ h: Int) -> [_VNComponent] {
    var label = [Int32](repeating: -1, count: w * h)
    var out: [_VNComponent] = []
    var stack: [Int] = []
    for start in 0..<(w * h) where mask[start] && label[start] < 0 {
        let id = Int32(out.count)
        var c = _VNComponent()
        label[start] = id; stack.append(start)
        while let i = stack.popLast() {
            let x = i % w, y = i / w
            c.add(x, y)
            for dy in -1...1 {
                let ny = y + dy
                if ny < 0 || ny >= h { continue }
                for dx in -1...1 {
                    let nx = x + dx
                    if nx < 0 || nx >= w || (dx == 0 && dy == 0) { continue }
                    let j = ny * w + nx
                    if mask[j] && label[j] < 0 { label[j] = id; stack.append(j) }
                }
            }
        }
        out.append(c)
    }
    return out
}

/// Andrew's monotone chain
func _vnConvexHull(_ points: [CGPoint]) -> [CGPoint] {
    let p = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
    if p.count < 3 { return p }
    func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
    var lower: [CGPoint] = [], upper: [CGPoint] = []
    for q in p { while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], q) <= 0 { lower.removeLast() }; lower.append(q) }
    for q in p.reversed() { while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], q) <= 0 { upper.removeLast() }; upper.append(q) }
    return Array(lower.dropLast() + upper.dropLast())
}

func _vnPolygonArea(_ p: [CGPoint]) -> CGFloat {
    var a: CGFloat = 0
    for i in 0..<p.count { let q = p[(i + 1) % p.count]; a += p[i].x * q.y - q.x * p[i].y }
    return abs(a) / 2
}

/// Douglas–Peucker over a closed polygon (keeps the two points farthest apart as anchors)
func _vnSimplifyClosed(_ pts: [SIMD2<Float>], epsilon: Float) -> [SIMD2<Float>] {
    guard pts.count > 3, epsilon > 0 else { return pts }
    var far = 0, best: Float = -1
    for (i, q) in pts.enumerated() { let d = simd_len2(q - pts[0]); if d > best { best = d; far = i } }
    func dp(_ a: [SIMD2<Float>]) -> [SIMD2<Float>] {
        guard a.count > 2, let s = a.first, let e = a.last else { return a }
        var idx = 0, dmax: Float = 0
        let d = e - s, len = (d.x * d.x + d.y * d.y).squareRoot()
        for i in 1..<(a.count - 1) {
            let v = a[i] - s
            let dist = len > 0 ? abs(d.x * v.y - d.y * v.x) / len : (v.x * v.x + v.y * v.y).squareRoot()
            if dist > dmax { dmax = dist; idx = i }
        }
        if dmax <= epsilon { return [s, e] }
        return Array(dp(Array(a[...idx])).dropLast()) + dp(Array(a[idx...]))
    }
    let first = dp(Array(pts[...far])), second = dp(Array(pts[far...]) + [pts[0]])
    return Array(first.dropLast()) + Array(second.dropLast())
}
@inline(__always) func simd_len2(_ v: SIMD2<Float>) -> Float { v.x * v.x + v.y * v.y }
