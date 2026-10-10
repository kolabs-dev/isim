// isim SwiftUI: MeshGradient (iOS 18) — a grid of points with a colour each, filled with smooth patches — as a view
// and a shape style; `Color.mix(with:by:in:)` (iOS 18) and `Color.Resolved` / `resolve(in:)` (iOS 17).
// Adapted: the mesh is rasterized by isim (each patch subdivided into small triangles with interpolated colours):
// positions and colours follow Catmull-Rom splines through the grid (bezier points use their control points),
// `smoothsColors: false` interpolates colours bilinearly; `.perceptual` mixes in Oklab, `.device` in sRGB.
import UIKit

// MARK: - Color.Resolved, mix

extension Color {
    /// A colour's sRGB components (iOS 17).
    public struct Resolved: Hashable, Sendable {
        public var red: Float, green: Float, blue: Float, opacity: Float
        public init(colorSpace: RGBColorSpace = .sRGB, red: Float, green: Float, blue: Float, opacity: Float = 1) {
            if colorSpace == .sRGBLinear {
                func enc(_ v: Float) -> Float { v <= 0.0031308 ? v * 12.92 : Float(1.055 * Foundation.pow(Double(v), 1 / 2.4) - 0.055) }
                self.red = enc(red); self.green = enc(green); self.blue = enc(blue)
            } else { self.red = red; self.green = green; self.blue = blue }
            self.opacity = opacity
        }
        func lin(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : Float(Foundation.pow(Double((v + 0.055) / 1.055), 2.4)) }
        public var linearRed: Float { get { lin(red) } set { red = Resolved(colorSpace: .sRGBLinear, red: newValue, green: 0, blue: 0).red } }
        public var linearGreen: Float { get { lin(green) } set { green = Resolved(colorSpace: .sRGBLinear, red: newValue, green: 0, blue: 0).red } }
        public var linearBlue: Float { get { lin(blue) } set { blue = Resolved(colorSpace: .sRGBLinear, red: newValue, green: 0, blue: 0).red } }
        public var cgColor: CGColor { UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(opacity)).cgColor }
    }
    public init(_ resolved: Resolved) { self.init(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue), opacity: Double(resolved.opacity)) }
    /// The colour in an environment (its appearance).
    public func resolve(in environment: EnvironmentValues) -> Resolved {
        let style: UIUserInterfaceStyle = environment.colorScheme == .dark ? .dark : .light
        let c = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Resolved(red: Float(r), green: Float(g), blue: Float(b), opacity: Float(a))
    }
    /// A colour `fraction` of the way from this one to `rhs` (iOS 18).
    @available(iOS 18.0, *)
    public func mix(with rhs: Color, by fraction: Double, in colorSpace: Gradient.ColorSpace = .perceptual) -> Color {
        let a = self, b = rhs, t = max(0, min(1, fraction))
        return Color("mix(\(provider.name),\(rhs.provider.name),\(t),\(colorSpace))") {
            let ca = _rgbaOf(a.uiColor), cb = _rgbaOf(b.uiColor)
            let m = _mixRGBA(ca, cb, t, perceptual: colorSpace == .perceptual)
            return UIColor(red: m[0], green: m[1], blue: m[2], alpha: m[3])
        }
    }
}

/// sRGB <-> Oklab (Björn Ottosson's), for perceptual mixing.
func _oklab(_ c: [Double]) -> [Double] {
    func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    let r = lin(c[0]), g = lin(c[1]), b = lin(c[2])
    let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s, c[3]]
}
func _fromOklab(_ o: [Double]) -> [Double] {
    let l = pow(o[0] + 0.3963377774 * o[1] + 0.2158037573 * o[2], 3)
    let m = pow(o[0] - 0.1055613458 * o[1] - 0.0638541728 * o[2], 3)
    let s = pow(o[0] - 0.0894841775 * o[1] - 1.2914855480 * o[2], 3)
    func enc(_ v: Double) -> Double { let x = max(0, min(1, v)); return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055 }
    return [enc(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s), enc(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            enc(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s), o[3]]
}
func _mixRGBA(_ a: [Double], _ b: [Double], _ t: Double, perceptual: Bool) -> [Double] {
    if !perceptual { return (0..<4).map { a[$0] + (b[$0] - a[$0]) * t } }
    let oa = _oklab(a), ob = _oklab(b)
    return _fromOklab((0..<4).map { oa[$0] + (ob[$0] - oa[$0]) * t })
}

// MARK: - MeshGradient

@available(iOS 18.0, *)
public struct MeshGradient: ShapeStyle, Equatable, Sendable, View, _PrimitiveView {
    public struct BezierPoint: Equatable, Sendable {
        public var position: SIMD2<Float>
        public var leadingControlPoint: SIMD2<Float>, topControlPoint: SIMD2<Float>, trailingControlPoint: SIMD2<Float>, bottomControlPoint: SIMD2<Float>
        public init(position: SIMD2<Float>, leadingControlPoint: SIMD2<Float>, topControlPoint: SIMD2<Float>, trailingControlPoint: SIMD2<Float>, bottomControlPoint: SIMD2<Float>) {
            self.position = position; self.leadingControlPoint = leadingControlPoint; self.topControlPoint = topControlPoint
            self.trailingControlPoint = trailingControlPoint; self.bottomControlPoint = bottomControlPoint
        }
    }
    public enum Locations: Equatable, Sendable { case points([SIMD2<Float>]), bezierPoints([BezierPoint]) }
    public enum Colors: Equatable, Sendable { case colors([Color]), resolvedColors([Color.Resolved]) }
    public var width: Int, height: Int
    public var locations: Locations
    public var colors: Colors
    public var background: Color
    public var smoothsColors: Bool
    public var colorSpace: Gradient.ColorSpace
    public init(width: Int, height: Int, locations: Locations, colors: Colors, background: Color = .clear, smoothsColors: Bool = true, colorSpace: Gradient.ColorSpace = .device) {
        self.width = width; self.height = height; self.locations = locations; self.colors = colors
        self.background = background; self.smoothsColors = smoothsColors; self.colorSpace = colorSpace
    }
    public init(width: Int, height: Int, points: [SIMD2<Float>], colors: [Color], background: Color = .clear, smoothsColors: Bool = true, colorSpace: Gradient.ColorSpace = .device) {
        self.init(width: width, height: height, locations: .points(points), colors: .colors(colors), background: background, smoothsColors: smoothsColors, colorSpace: colorSpace)
    }
    public init(width: Int, height: Int, points: [SIMD2<Float>], resolvedColors: [Color.Resolved], background: Color = .clear, smoothsColors: Bool = true, colorSpace: Gradient.ColorSpace = .device) {
        self.init(width: width, height: height, locations: .points(points), colors: .resolvedColors(resolvedColors), background: background, smoothsColors: smoothsColors, colorSpace: colorSpace)
    }
    public init(width: Int, height: Int, bezierPoints: [BezierPoint], colors: [Color], background: Color = .clear, smoothsColors: Bool = true, colorSpace: Gradient.ColorSpace = .device) {
        self.init(width: width, height: height, locations: .bezierPoints(bezierPoints), colors: .colors(colors), background: background, smoothsColors: smoothsColors, colorSpace: colorSpace)
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let me = self, env = ctx.environment
        return _PathNode(path: ctx.path, ops: { r in [_DrawOp(path: Path(r), paint: me._paint(in: r, env), stroke: nil)] })
    }
}
@available(iOS 18.0, *)
extension MeshGradient: _PaintStyle, _ColorFallback {
    func _fallbackColor(_ env: EnvironmentValues) -> Color {
        if case .colors(let c) = colors, let f = c.first { return f }
        if case .resolvedColors(let c) = colors, let f = c.first { return Color(f) }
        return background
    }
    @MainActor func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint {
        let scale = UIScreen.main.scale
        let img = _meshImage(self, size: rect.size, scale: scale, env)
        return .image(img, origin: rect.origin, source: CGRect(x: 0, y: 0, width: 1, height: 1), scale: 1)
    }
}

/// Rasterizes a mesh gradient at `size` (points) into an image.
@available(iOS 18.0, *)
@MainActor func _meshImage(_ m: MeshGradient, size: CGSize, scale: CGFloat, _ env: EnvironmentValues) -> UIImage {
    let W = max(1, Int((size.width * scale).rounded())), H = max(1, Int((size.height * scale).rounded()))
    var buf = [UInt8](repeating: 0, count: W * H * 4)
    let cols = max(2, m.width), rows = max(2, m.height), n = cols * rows
    // grid colours (premultiplied later), in the interpolation space
    var rgba: [[Double]] = []
    switch m.colors {
    case .colors(let c): rgba = c.map { _rgbaOf($0.uiColor) }
    case .resolvedColors(let c): rgba = c.map { [Double($0.red), Double($0.green), Double($0.blue), Double($0.opacity)] }
    }
    while rgba.count < n { rgba.append(rgba.last ?? [0, 0, 0, 0]) }
    let perceptual = m.colorSpace == .perceptual
    let space = perceptual ? rgba.map(_oklab) : rgba
    var pts: [CGPoint] = [], bez: [MeshGradient.BezierPoint]? = nil
    switch m.locations {
    case .points(let p): pts = p.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
    case .bezierPoints(let b): bez = b; pts = b.map { CGPoint(x: CGFloat($0.position.x), y: CGFloat($0.position.y)) }
    }
    while pts.count < n { pts.append(CGPoint(x: CGFloat(pts.count % cols) / CGFloat(cols - 1), y: CGFloat(pts.count / cols) / CGFloat(rows - 1))) }
    func idx(_ c: Int, _ r: Int) -> Int { max(0, min(rows - 1, r)) * cols + max(0, min(cols - 1, c)) }
    // Catmull-Rom (Hermite) interpolation through 4 values
    func cr(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double, _ t: Double) -> Double {
        let t2 = t * t, t3 = t2 * t
        return 0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    }
    func bez1(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ t: Double) -> Double {
        let u = 1 - t
        return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
    }
    /// position at patch (pc, pr), parameters (u, v)
    func pos(_ pc: Int, _ pr: Int, _ u: Double, _ v: Double) -> (Double, Double) {
        if let bz = bez {
            // tensor of the bezier boundary curves: the patch's rows through control points
            func ctl(_ c: Int, _ r: Int) -> MeshGradient.BezierPoint { bz[idx(c, r)] }
            func rowAt(_ r: Int, _ t: Double, _ k: Int) -> Double {
                let a = ctl(pc, r), b = ctl(pc + 1, r)
                return bez1(Double(a.position[k]), Double(a.trailingControlPoint[k]), Double(b.leadingControlPoint[k]), Double(b.position[k]), t)
            }
            func colAt(_ c: Int, _ t: Double, _ k: Int) -> Double {
                let a = ctl(c, pr), b = ctl(c, pr + 1)
                return bez1(Double(a.position[k]), Double(a.bottomControlPoint[k]), Double(b.topControlPoint[k]), Double(b.position[k]), t)
            }
            // a Coons patch from the four boundary curves
            var out = [0.0, 0.0]
            for k in 0..<2 {
                let c0 = rowAt(pr, u, k), c1 = rowAt(pr + 1, u, k), d0 = colAt(pc, v, k), d1 = colAt(pc + 1, v, k)
                let p00 = Double(ctl(pc, pr).position[k]), p10 = Double(ctl(pc + 1, pr).position[k])
                let p01 = Double(ctl(pc, pr + 1).position[k]), p11 = Double(ctl(pc + 1, pr + 1).position[k])
                out[k] = (1 - v) * c0 + v * c1 + (1 - u) * d0 + u * d1 - ((1 - u) * (1 - v) * p00 + u * (1 - v) * p10 + (1 - u) * v * p01 + u * v * p11)
            }
            return (out[0], out[1])
        }
        var out = [0.0, 0.0]
        for k in 0..<2 {
            func at(_ c: Int, _ r: Int) -> Double {
                // outside the grid: continue the edge linearly (so border lines stay straight)
                let cc = max(0, min(cols - 1, c)), rr = max(0, min(rows - 1, r))
                var v = k == 0 ? Double(pts[idx(cc, rr)].x) : Double(pts[idx(cc, rr)].y)
                if c < 0 || c >= cols { let d = c < 0 ? 1 : -1; let inner = k == 0 ? Double(pts[idx(cc + d, rr)].x) : Double(pts[idx(cc + d, rr)].y); v = 2 * v - inner }
                if r < 0 || r >= rows { let d = r < 0 ? 1 : -1; let inner = k == 0 ? Double(pts[idx(cc, rr + d)].x) : Double(pts[idx(cc, rr + d)].y); v = 2 * v - inner }
                return v
            }
            var row = [Double](repeating: 0, count: 4)
            for j in 0..<4 { row[j] = cr(at(pc - 1, pr - 1 + j), at(pc, pr - 1 + j), at(pc + 1, pr - 1 + j), at(pc + 2, pr - 1 + j), u) }
            out[k] = cr(row[0], row[1], row[2], row[3], v)
        }
        return (out[0], out[1])
    }
    func color(_ pc: Int, _ pr: Int, _ u: Double, _ v: Double) -> [Double] {
        (0..<4).map { k -> Double in
            if !m.smoothsColors {
                let a = space[idx(pc, pr)][k], b = space[idx(pc + 1, pr)][k], c = space[idx(pc, pr + 1)][k], d = space[idx(pc + 1, pr + 1)][k]
                return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v
            }
            var row = [Double](repeating: 0, count: 4)
            for j in 0..<4 { row[j] = cr(space[idx(pc - 1, pr - 1 + j)][k], space[idx(pc, pr - 1 + j)][k], space[idx(pc + 1, pr - 1 + j)][k], space[idx(pc + 2, pr - 1 + j)][k], u) }
            return cr(row[0], row[1], row[2], row[3], v)
        }
    }
    let bg = _rgbaOf(m.background.uiColor)
    if bg[3] > 0 {
        let px = [UInt8(bg[0] * bg[3] * 255), UInt8(bg[1] * bg[3] * 255), UInt8(bg[2] * bg[3] * 255), UInt8(bg[3] * 255)]
        for i in 0..<(W * H) { buf[i * 4] = px[0]; buf[i * 4 + 1] = px[1]; buf[i * 4 + 2] = px[2]; buf[i * 4 + 3] = px[3] }
    }
    // each patch: a grid of small triangles with interpolated colours
    let sub = 20
    func fill(_ a: (Double, Double, [Double]), _ b: (Double, Double, [Double]), _ c: (Double, Double, [Double])) {
        let minY = max(0, Int(floor(min(a.1, b.1, c.1)))), maxY = min(H - 1, Int(ceil(max(a.1, b.1, c.1))))
        let minX = max(0, Int(floor(min(a.0, b.0, c.0)))), maxX = min(W - 1, Int(ceil(max(a.0, b.0, c.0))))
        guard minY <= maxY, minX <= maxX else { return }
        let den = (b.1 - c.1) * (a.0 - c.0) + (c.0 - b.0) * (a.1 - c.1)
        if abs(den) < 1e-12 { return }
        for y in minY...maxY {
            let py = Double(y) + 0.5
            for x in minX...maxX {
                let px = Double(x) + 0.5
                let w0 = ((b.1 - c.1) * (px - c.0) + (c.0 - b.0) * (py - c.1)) / den
                let w1 = ((c.1 - a.1) * (px - c.0) + (a.0 - c.0) * (py - c.1)) / den
                let w2 = 1 - w0 - w1
                if w0 < -1e-6 || w1 < -1e-6 || w2 < -1e-6 { continue }
                var col = (0..<4).map { a.2[$0] * w0 + b.2[$0] * w1 + c.2[$0] * w2 }
                if perceptual { col = _fromOklab(col) }
                let al = max(0, min(1, col[3])), o = (y * W + x) * 4
                // over the background
                let inv = 1 - al
                buf[o] = UInt8(max(0, min(255, (max(0, min(1, col[0])) * al * 255 + Double(buf[o]) * inv).rounded())))
                buf[o + 1] = UInt8(max(0, min(255, (max(0, min(1, col[1])) * al * 255 + Double(buf[o + 1]) * inv).rounded())))
                buf[o + 2] = UInt8(max(0, min(255, (max(0, min(1, col[2])) * al * 255 + Double(buf[o + 2]) * inv).rounded())))
                buf[o + 3] = UInt8(max(0, min(255, (al * 255 + Double(buf[o + 3]) * inv).rounded())))
            }
        }
    }
    for pr in 0..<(rows - 1) {
        for pc in 0..<(cols - 1) {
            var grid: [[(Double, Double, [Double])]] = []
            for j in 0...sub {
                var line: [(Double, Double, [Double])] = []
                for i in 0...sub {
                    let u = Double(i) / Double(sub), v = Double(j) / Double(sub)
                    let p = pos(pc, pr, u, v)
                    line.append((p.0 * Double(W), p.1 * Double(H), color(pc, pr, u, v)))
                }
                grid.append(line)
            }
            for j in 0..<sub { for i in 0..<sub { fill(grid[j][i], grid[j][i + 1], grid[j + 1][i]); fill(grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]) } }
        }
    }
    let data = Data(buf) as CFData
    let provider = CGDataProvider(data: data)!
    let cg = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceRGB(),
                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    return UIImage(cgImage: cg, scale: scale, orientation: .up)
}
