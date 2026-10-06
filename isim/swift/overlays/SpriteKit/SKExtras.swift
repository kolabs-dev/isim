// isim SpriteKit: SKVideoNode (AVPlayer frames), SKTransformNode (3D rotation, projected orthographically),
// SKWarpGeometryGrid (sprites drawn as a warped triangle mesh) with warp actions, SKMutableTexture and textures
// made from pixel data.
import AVFoundation
import isim_host

// MARK: - Video

/// Shows an AVPlayer's video. The node's size defaults to the video's size once the asset has loaded.
open class SKVideoNode: SKNode {
    let avPlayer: AVPlayer
    open var size: CGSize = .zero
    open var anchorPoint = CGPoint(x: 0.5, y: 0.5)

    public init(avPlayer player: AVPlayer) { avPlayer = player; super.init() }
    /// a movie file in the main bundle
    public convenience init(fileNamed videoFile: String) {
        let url = Bundle.main.url(forResource: videoFile, withExtension: nil) ?? URL(fileURLWithPath: videoFile)
        self.init(url: url)
    }
    public convenience init(url: URL) { self.init(avPlayer: AVPlayer(url: url)) }
    public required init?(coder: NSCoder) { avPlayer = AVPlayer(); super.init(coder: coder) }

    open func play() { avPlayer.play() }
    open func pause() { avPlayer.pause() }

    func resolveSize() {
        if size == .zero, let s = avPlayer.currentItem?.presentationSize, s.width > 0, s.height > 0 { size = s }
    }
    override var contentRect: CGRect {
        resolveSize()
        return CGRect(x: -anchorPoint.x * size.width, y: -anchorPoint.y * size.height, width: size.width, height: size.height)
    }
    override func drawContent(alpha a: CGFloat) {
        let r = contentRect
        let h = avPlayer._isimVideoFrame
        guard h != 0, r.width > 0, r.height > 0 else { return }
        var pw = 0.0, ph = 0.0
        isim_image_pixel_size(h, &pw, &ph)
        guard pw > 0, ph > 0 else { return }
        isim_gfx_save()
        isim_gfx_scale(1, -1)
        isim_image_draw_part(h, 0, 0, pw, ph, r.minX, -r.maxY, r.width, r.height, 0, nil, 0, Double(a))
        isim_gfx_restore()
    }
}

// MARK: - Transform node

/// A node rotated in 3D (x, y and z rotations). Its children are drawn with the rotation projected orthographically
/// onto the scene plane (a rotation around x squashes them vertically, around y horizontally).
open class SKTransformNode: SKNode {
    open var xRotation: CGFloat = 0
    open var yRotation: CGFloat = 0

    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    /// (x, y, z) rotations in radians; applied z first, then y, then x
    open func eulerAngles() -> vector_float3 { vector_float3(Float(xRotation), Float(yRotation), Float(zRotation)) }
    open func setEulerAngles(_ e: vector_float3) { xRotation = CGFloat(e.x); yRotation = CGFloat(e.y); zRotation = CGFloat(e.z) }

    /// R = Rx * Ry * Rz
    open func rotationMatrix() -> matrix_float3x3 {
        let (sx, cx) = (sinf(Float(xRotation)), cosf(Float(xRotation)))
        let (sy, cy) = (sinf(Float(yRotation)), cosf(Float(yRotation)))
        let (sz, cz) = (sinf(Float(zRotation)), cosf(Float(zRotation)))
        let rx = matrix_float3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, cx, -sx), SIMD3(0, sx, cx)])
        let ry = matrix_float3x3(rows: [SIMD3(cy, 0, sy), SIMD3(0, 1, 0), SIMD3(-sy, 0, cy)])
        let rz = matrix_float3x3(rows: [SIMD3(cz, -sz, 0), SIMD3(sz, cz, 0), SIMD3(0, 0, 1)])
        return rx * ry * rz
    }
    /// decomposes R = Rx * Ry * Rz into the three angles
    open func setRotationMatrix(_ m: matrix_float3x3) {
        // row 0 of R: (cy cz, -cy sz, sy); column 2: (sy, -sx cy, cx cy)
        let sy = max(-1, min(1, m[2, 0]))
        let y = asinf(sy)
        let x: Float, z: Float
        if abs(sy) < 0.99999 {
            x = atan2f(-m[2, 1], m[2, 2])
            z = atan2f(-m[1, 0], m[0, 0])
        } else {      // gimbal lock: put everything into x
            x = atan2f(m[1, 2], m[1, 1]); z = 0
        }
        xRotation = CGFloat(x); yRotation = CGFloat(y); zRotation = CGFloat(z)
    }
    open func quaternion() -> simd_quatf { simd_quatf(rotationMatrix()) }
    open func setQuaternion(_ q: simd_quatf) { setRotationMatrix(matrix_float3x3(q.normalized)) }

    override var localTransform: CGAffineTransform {
        let m = rotationMatrix()
        // orthographic projection: the x / y rows and columns of the rotation
        let r = CGAffineTransform(a: CGFloat(m[0, 0]), b: CGFloat(m[0, 1]), c: CGFloat(m[1, 0]), d: CGFloat(m[1, 1]), tx: 0, ty: 0)
        return CGAffineTransform(scaleX: xScale, y: yScale).concatenating(r).concatenating(CGAffineTransform(translationX: position.x, y: position.y))
    }
}

// MARK: - Warp geometry

open class SKWarpGeometry: NSObject, NSCopying {
    public override init() { super.init() }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}

/// A grid of (columns + 1) x (rows + 1) vertices, row by row from the bottom left, in unit coordinates of the
/// node: each source position (a point of the texture) is drawn at its destination position.
open class SKWarpGeometryGrid: SKWarpGeometry {
    open private(set) var numberOfColumns: Int
    open private(set) var numberOfRows: Int
    var src: [vector_float2]
    var dst: [vector_float2]
    open var vertexCount: Int { (numberOfColumns + 1) * (numberOfRows + 1) }

    static func regular(_ cols: Int, _ rows: Int) -> [vector_float2] {
        var out: [vector_float2] = []
        for r in 0...rows { for c in 0...cols { out.append(vector_float2(Float(c) / Float(cols), Float(r) / Float(rows))) } }
        return out
    }
    /// empty position arrays mean the regular grid
    public required init(columns: Int, rows: Int, sourcePositions: [vector_float2] = [], destinationPositions: [vector_float2] = []) {
        numberOfColumns = max(1, columns); numberOfRows = max(1, rows)
        let regular = SKWarpGeometryGrid.regular(numberOfColumns, numberOfRows)
        src = sourcePositions.count == regular.count ? sourcePositions : regular
        dst = destinationPositions.count == regular.count ? destinationPositions : regular
        if !sourcePositions.isEmpty && sourcePositions.count != regular.count || !destinationPositions.isEmpty && destinationPositions.count != regular.count {
            NSLog("isim SpriteKit: SKWarpGeometryGrid(%d x %d) needs %d positions", numberOfColumns, numberOfRows, regular.count)
        }
        super.init()
    }
    open class func grid() -> SKWarpGeometryGrid { SKWarpGeometryGrid(columns: 1, rows: 1) }
    open func sourcePosition(at index: Int) -> vector_float2 { src[index] }
    open func destPosition(at index: Int) -> vector_float2 { dst[index] }
    open func replacingBySourcePositions(positions: [vector_float2]) -> Self {
        Self(columns: numberOfColumns, rows: numberOfRows, sourcePositions: positions, destinationPositions: dst)
    }
    open func replacingByDestinationPositions(positions: [vector_float2]) -> Self {
        Self(columns: numberOfColumns, rows: numberOfRows, sourcePositions: src, destinationPositions: positions)
    }
    var isIdentity: Bool { src == dst }
    func sameShape(_ o: SKWarpGeometryGrid) -> Bool { o.numberOfColumns == numberOfColumns && o.numberOfRows == numberOfRows }
    /// destination positions interpolated from `self` to `to` (source positions of `to`)
    func mixed(to: SKWarpGeometryGrid, _ f: Float) -> SKWarpGeometryGrid {
        SKWarpGeometryGrid(columns: to.numberOfColumns, rows: to.numberOfRows, sourcePositions: to.src,
                           destinationPositions: zip(dst, to.dst).map { $0 + ($1 - $0) * f })
    }
    open override var description: String { "<SKWarpGeometryGrid \(numberOfColumns)x\(numberOfRows)>" }
}

public protocol SKWarpable: NSObjectProtocol {
    var warpGeometry: SKWarpGeometry? { get set }
    var subdivisionLevels: Int { get set }
}
extension SKSpriteNode: SKWarpable {}

extension SKAction {
    /// the node's current warp (or a regular grid of the same shape) to `warp`; nil if `warp` is not a grid
    public class func warp(to warp: SKWarpGeometry, duration d: TimeInterval) -> SKAction? {
        guard let target = warp as? SKWarpGeometryGrid else { return nil }
        return timed(d) { n in
            guard let w = n as? SKSpriteNode else { return { _ in } }
            let start = (w.warpGeometry as? SKWarpGeometryGrid).flatMap { $0.sameShape(target) ? $0 : nil }
                ?? SKWarpGeometryGrid(columns: target.numberOfColumns, rows: target.numberOfRows, sourcePositions: target.src, destinationPositions: target.src)
            return { f in w.warpGeometry = f >= 1 ? target : start.mixed(to: target, Float(f)) }
        }
    }
    public class func animate(withWarps warps: [SKWarpGeometry], times: [NSNumber]) -> SKAction? {
        animate(withWarps: warps, times: times, restore: false)
    }
    /// interpolates through the warps, reaching warps[i] at times[i] seconds; `restore` puts the original warp back
    public class func animate(withWarps warps: [SKWarpGeometry], times: [NSNumber], restore: Bool) -> SKAction? {
        let grids = warps.compactMap { $0 as? SKWarpGeometryGrid }
        let ts = times.map(\.doubleValue)
        guard !grids.isEmpty, grids.count == warps.count, ts.count == grids.count,
              grids.allSatisfy({ $0.sameShape(grids[0]) }), zip(ts, ts.dropFirst()).allSatisfy({ $0 <= $1 }) else { return nil }
        let d = max(0, ts.last ?? 0)
        return SKAction(duration: d) { node, action in
            let w = node as? SKSpriteNode
            let original = w?.warpGeometry
            return _TimedRunner(node: node, duration: d, action: action, setup: { _ in
                let first = grids[0]
                let start = (original as? SKWarpGeometryGrid).flatMap { $0.sameShape(first) ? $0 : nil }
                    ?? SKWarpGeometryGrid(columns: first.numberOfColumns, rows: first.numberOfRows, sourcePositions: first.src, destinationPositions: first.src)
                return { f in
                    guard let w else { return }
                    let t = f * d
                    var k = 0
                    while k < ts.count - 1 && t > ts[k] { k += 1 }
                    let from = k == 0 ? start : grids[k - 1], t0 = k == 0 ? 0 : ts[k - 1]
                    let span = ts[k] - t0
                    let frac = span > 0 ? min(1, max(0, (t - t0) / span)) : 1
                    w.warpGeometry = frac >= 1 ? grids[k] : from.mixed(to: grids[k], Float(frac))
                }
            }, finish: { if restore, let w { w.warpGeometry = original } })
        }
    }
}

extension SKSpriteNode {
    /// Draws the sprite as a triangle mesh: every grid cell is subdivided (2^subdivisionLevels per side, bilinear),
    /// each triangle of the texture is mapped affinely onto its destination triangle.
    func drawWarped(_ g: SKWarpGeometryGrid, alpha a: CGFloat) {
        let r = contentRect
        let cols = g.numberOfColumns, rows = g.numberOfRows
        var n = 1 << max(0, min(subdivisionLevels, 3))
        while n > 1 && cols * rows * n * n > 1024 { n /= 2 }
        let tex = texture.flatMap { $0.handle > 0 ? $0 : nil }
        let factor = Double(colorBlendFactor)
        let blend: [Double] = factor > 0 ? _rgba(color) : [0, 0, 0, 1]
        var fill = _rgba(color)
        isim_gfx_save()
        if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
        let group = a < 0.999
        if group { isim_gfx_push_group() } else { fill[3] *= Double(a) }
        func P(_ v: vector_float2) -> CGPoint { CGPoint(x: r.minX + CGFloat(v.x) * r.width, y: r.minY + CGFloat(v.y) * r.height) }
        func bil(_ q: (vector_float2, vector_float2, vector_float2, vector_float2), _ u: Float, _ v: Float) -> vector_float2 {
            let bottom = q.0 + (q.1 - q.0) * u, top = q.2 + (q.3 - q.2) * u
            return bottom + (top - bottom) * v
        }
        /// the triangle grown by about a point so neighbours overlap (no seams from antialiased clip edges)
        func trianglePath(_ d: [CGPoint]) {
            let cx = (d[0].x + d[1].x + d[2].x) / 3, cy = (d[0].y + d[1].y + d[2].y) / 3
            isim_path_begin()
            for (i, p) in d.enumerated() {
                let dx = p.x - cx, dy = p.y - cy, l = max(0.0001, (dx * dx + dy * dy).squareRoot())
                let q = CGPoint(x: p.x + dx / l * 1.0, y: p.y + dy / l * 1.0)
                if i == 0 { isim_path_move(q.x, q.y) } else { isim_path_line(q.x, q.y) }
            }
            isim_path_close()
        }
        func triangle(_ s: [vector_float2], _ dv: [vector_float2]) {
            let d = dv.map(P)
            guard let t = tex else {
                trianglePath(d)
                fill.withUnsafeBufferPointer { isim_path_fill($0.baseAddress) }
                return
            }
            // affine map: unit texture coordinates (y up) -> node coordinates
            let ax = Double(s[1].x - s[0].x), ay = Double(s[1].y - s[0].y), bx = Double(s[2].x - s[0].x), by = Double(s[2].y - s[0].y)
            let det = ax * by - bx * ay
            guard abs(det) > 1e-9 else { return }
            let ex = Double(d[1].x - d[0].x), ey = Double(d[1].y - d[0].y), fx = Double(d[2].x - d[0].x), fy = Double(d[2].y - d[0].y)
            let m00 = (ex * by - fx * ay) / det, m01 = (fx * ax - ex * bx) / det
            let m10 = (ey * by - fy * ay) / det, m11 = (fy * ax - ey * bx) / det
            let tx = Double(d[0].x) - (m00 * Double(s[0].x) + m01 * Double(s[0].y))
            let ty = Double(d[0].y) - (m10 * Double(s[0].x) + m11 * Double(s[0].y))
            isim_gfx_save()
            trianglePath(d)
            isim_gfx_clip_path()
            isim_gfx_concat(m00, m10, m01, m11, tx, ty)
            isim_gfx_scale(1, -1)
            blend.withUnsafeBufferPointer { b in
                isim_image_draw_part(t.handle, t.pixels.minX, t.pixels.minY, t.pixels.width, t.pixels.height, 0, -1, 1, 1,
                                     t.filteringMode == .nearest ? 1 : 0, factor > 0 ? b.baseAddress : nil, factor, group ? 1 : Double(a))
            }
            isim_gfx_restore()
        }
        func at(_ c: Int, _ row: Int) -> Int { row * (cols + 1) + c }
        for row in 0..<rows {
            for c in 0..<cols {
                let sq = (g.src[at(c, row)], g.src[at(c + 1, row)], g.src[at(c, row + 1)], g.src[at(c + 1, row + 1)])
                let dq = (g.dst[at(c, row)], g.dst[at(c + 1, row)], g.dst[at(c, row + 1)], g.dst[at(c + 1, row + 1)])
                for j in 0..<n {
                    for i in 0..<n {
                        let u0 = Float(i) / Float(n), u1 = Float(i + 1) / Float(n), v0 = Float(j) / Float(n), v1 = Float(j + 1) / Float(n)
                        let s = [bil(sq, u0, v0), bil(sq, u1, v0), bil(sq, u1, v1), bil(sq, u0, v1)]
                        let d = [bil(dq, u0, v0), bil(dq, u1, v0), bil(dq, u1, v1), bil(dq, u0, v1)]
                        triangle([s[0], s[1], s[2]], [d[0], d[1], d[2]])
                        triangle([s[0], s[2], s[3]], [d[0], d[2], d[3]])
                    }
                }
            }
        }
        isim_path_begin()
        if group { isim_gfx_pop_group(Double(a)) }
        isim_gfx_restore()
    }
}

// MARK: - Textures from pixel data

/// RGBA bytes (straight alpha) -> a host BGRA raster image (premultiplied, rows top-down).
/// `bottomUp`: the first row of `bytes` is the bottom of the image (SpriteKit's default layout).
func _skUploadRGBA(_ handle: Int32, _ bytes: UnsafeRawBufferPointer, _ w: Int, _ h: Int, rowBytes: Int, bottomUp: Bool) {
    var out = [UInt8](repeating: 0, count: w * h * 4)
    for y in 0..<h {
        let srow = (bottomUp ? h - 1 - y : y) * rowBytes
        for x in 0..<w {
            let i = srow + x * 4
            guard i + 3 < bytes.count else { continue }
            let r = UInt32(bytes[i]), g = UInt32(bytes[i + 1]), b = UInt32(bytes[i + 2]), a = UInt32(bytes[i + 3])
            let o = (y * w + x) * 4
            out[o] = UInt8((b * a + 127) / 255); out[o + 1] = UInt8((g * a + 127) / 255); out[o + 2] = UInt8((r * a + 127) / 255); out[o + 3] = UInt8(a)
        }
    }
    out.withUnsafeBufferPointer { isim_image_update_bgra(handle, $0.baseAddress, Int32(w), Int32(h)) }
}

extension SKTexture {
    /// RGBA pixels (8 bits per channel, straight alpha), the first row at the bottom
    public convenience init(data pixelData: Data, size: CGSize) { self.init(data: pixelData, size: size, flipped: false) }
    /// flipped: the first row is the top of the image
    public convenience init(data pixelData: Data, size: CGSize, flipped: Bool) {
        let w = max(1, Int(size.width)), h = max(1, Int(size.height))
        let handle = isim_image_create_bgra(Int32(w), Int32(h))
        self.init(handle: handle, pixels: CGRect(x: 0, y: 0, width: w, height: h), scale: 1, owner: nil)
        pixelData.withUnsafeBytes { _skUploadRGBA(handle, $0, w, h, rowBytes: w * 4, bottomUp: !flipped) }
    }
    /// rowLength: pixels per row in the data (0: the width); alignment: row alignment in bytes
    public convenience init(data pixelData: Data, size: CGSize, rowLength: UInt32, alignment: UInt32) {
        let w = max(1, Int(size.width)), h = max(1, Int(size.height))
        let handle = isim_image_create_bgra(Int32(w), Int32(h))
        self.init(handle: handle, pixels: CGRect(x: 0, y: 0, width: w, height: h), scale: 1, owner: nil)
        var rb = (rowLength > 0 ? Int(rowLength) : w) * 4
        let al = max(1, Int(alignment)); rb = (rb + al - 1) / al * al
        pixelData.withUnsafeBytes { _skUploadRGBA(handle, $0, w, h, rowBytes: rb, bottomUp: true) }
    }
}

/// A texture whose pixels the app changes (RGBA, 8 bits per channel, straight alpha, first row at the bottom).
open class SKMutableTexture: SKTexture {
    let width: Int, height: Int
    var rgba: [UInt8]

    public convenience init(size: CGSize) { self.init(size: size, pixelFormat: 0x5247_4241 /* 'RGBA' */) }
    public init(size: CGSize, pixelFormat format: Int32) {
        width = max(1, Int(size.width)); height = max(1, Int(size.height))
        rgba = [UInt8](repeating: 0, count: width * height * 4)
        let handle = isim_image_create_bgra(Int32(width), Int32(height))
        super.init(handle: handle, pixels: CGRect(x: 0, y: 0, width: width, height: height), scale: 1, owner: nil)
    }
    /// The block gets the pixel buffer and its length in bytes; the texture shows the new pixels afterwards.
    open func modifyPixelData(_ block: @escaping (UnsafeMutableRawPointer?, Int) -> Void) {
        rgba.withUnsafeMutableBytes { block($0.baseAddress, $0.count) }
        let (h, w, hh) = (handle, width, height)
        rgba.withUnsafeBytes { _skUploadRGBA(h, $0, w, hh, rowBytes: w * 4, bottomUp: true) }
    }
}
