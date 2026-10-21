// isim SpriteKit: what needs a texture's pixels (adapted, on the CPU): `cgImage()`, noise textures, normal maps,
// rendering nodes into textures (`SKView.texture(from:)`), 9-slice sprites (`centerRect`) and 2D lighting
// (`SKLightNode` with `lightingBitMask`, `normalTexture`, shadows).
//
// Lighting model (adapted: isim's own, SpriteKit's shading is not documented): for each pixel of a lit sprite, at its
// scene position P, every light whose categoryBitMask meets the sprite's lightingBitMask adds
//   lightColor × diffuse × attenuation,   attenuation = (1 + distance / 100)^-falloff
// where diffuse is N·L with the normal map's normal (rotated with the sprite) and L the direction to the light
// raised 60 points above the scene, or 1 without a normal map; plus the lights' ambientColor. The sprite's color is
// multiplied by that sum. Where the segment from P to the light crosses a sprite whose shadowCastBitMask meets the
// light's category (its rectangle), sprites with that light in their shadowedBitMask get no light from it, and the
// light's shadowColor is laid over them.
import Foundation
import isim_host

/// premultiplied BGRA pixels, rows from the top (the host's layout)
struct _SKPixels {
    var px: [UInt8]
    let w: Int, h: Int
    init(w: Int, h: Int) { self.w = w; self.h = h; px = [UInt8](repeating: 0, count: w * h * 4) }
    /// straight-alpha RGBA in 0...1 at (x, y) from the top, clamped
    func rgba(_ x: Int, _ y: Int) -> SIMD4<Float> {
        let xx = min(max(x, 0), w - 1), yy = min(max(y, 0), h - 1), o = (yy * w + xx) * 4
        let a = Float(px[o + 3]) / 255
        guard a > 0 else { return .zero }
        return SIMD4(Float(px[o + 2]) / 255 / a, Float(px[o + 1]) / 255 / a, Float(px[o]) / 255 / a, a)
    }
    /// bilinear sample at unit coordinates (u right, v up)
    func sample(_ u: Float, _ v: Float) -> SIMD4<Float> {
        let fx = u * Float(w) - 0.5, fy = (1 - v) * Float(h) - 0.5
        let x0 = Int(fx.rounded(.down)), y0 = Int(fy.rounded(.down)), tx = fx - Float(x0), ty = fy - Float(y0)
        let a = rgba(x0, y0), b = rgba(x0 + 1, y0), c = rgba(x0, y0 + 1), d = rgba(x0 + 1, y0 + 1)
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    }
    mutating func set(_ x: Int, _ y: Int, _ c: SIMD4<Float>) {
        let o = (y * w + x) * 4, a = min(max(c.w, 0), 1)
        px[o + 3] = UInt8(a * 255 + 0.5)
        px[o + 2] = UInt8(min(max(c.x, 0), 1) * a * 255 + 0.5)
        px[o + 1] = UInt8(min(max(c.y, 0), 1) * a * 255 + 0.5)
        px[o] = UInt8(min(max(c.z, 0), 1) * a * 255 + 0.5)
    }
}

/// a host image owned by a node or texture: freed with it
final class _SKHandleBox {
    var handle: Int32 = 0
    var w = 0, h = 0
    deinit { if handle > 0 { isim_image_free(handle) } }
    /// the box's image with these pixels (made again when the size changes)
    func update(_ p: _SKPixels) -> Int32 {
        if handle == 0 || w != p.w || h != p.h {
            if handle > 0 { isim_image_free(handle) }
            handle = isim_image_create_bgra(Int32(p.w), Int32(p.h)); w = p.w; h = p.h
        }
        p.px.withUnsafeBufferPointer { isim_image_update_bgra(handle, $0.baseAddress, Int32(p.w), Int32(p.h)) }
        return handle
    }
}
nonisolated(unsafe) private var _skBoxKey: UInt8 = 0
nonisolated(unsafe) private var _skBox2Key: UInt8 = 0
extension NSObject {
    /// a host image kept with this object (second: another one)
    func _skBox(_ second: Bool = false) -> _SKHandleBox {
        let key = second ? UnsafeRawPointer(&_skBox2Key) : UnsafeRawPointer(&_skBoxKey)
        if let b = objc_getAssociatedObject(self, key) as? _SKHandleBox { return b }
        let b = _SKHandleBox()
        objc_setAssociatedObject(self, key, b, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return b
    }
}

// MARK: - texture pixels

nonisolated(unsafe) private var _skPixelCacheKey: UInt8 = 0
final class _SKPixelCache { var pixels: _SKPixels? }

extension SKTexture {
    /// the texture's pixels (cached: textures do not change, except mutable ones)
    func _pixels() -> _SKPixels? {
        guard handle > 0 else { return nil }
        let w = Int(pixels.width.rounded()), h = Int(pixels.height.rounded())
        guard w > 0, h > 0 else { return nil }
        let mutable = self is SKMutableTexture
        let cache = (objc_getAssociatedObject(self, &_skPixelCacheKey) as? _SKPixelCache) ?? {
            let c = _SKPixelCache(); objc_setAssociatedObject(self, &_skPixelCacheKey, c, .OBJC_ASSOCIATION_RETAIN_NONATOMIC); return c
        }()
        if !mutable, let p = cache.pixels { return p }
        var p = _SKPixels(w: w, h: h)
        let ok = p.px.withUnsafeMutableBufferPointer { isim_image_read_bgra(handle, Int32(pixels.minX.rounded()), Int32(pixels.minY.rounded()), Int32(w), Int32(h), $0.baseAddress) }
        guard ok != 0 else { return nil }
        if !mutable { cache.pixels = p }
        return p
    }
    /// a texture holding these pixels
    static func _make(_ p: _SKPixels, scale: CGFloat) -> SKTexture {
        let hd = isim_image_create_bgra(Int32(p.w), Int32(p.h))
        p.px.withUnsafeBufferPointer { isim_image_update_bgra(hd, $0.baseAddress, Int32(p.w), Int32(p.h)) }
        return SKTexture(handle: hd, pixels: CGRect(x: 0, y: 0, width: p.w, height: p.h), scale: scale, owner: nil)
    }
    func _cgImage() -> CGImage? {
        guard handle > 0, pixels.width >= 1, pixels.height >= 1 else { return nil }
        return isim_cg_image_create(handle, pixels, Unmanaged.passUnretained(self).toOpaque())
    }

    // MARK: noise

    /// value noise: a random lattice (one cell per pixel at smoothness 0, a few cells at 1) interpolated smoothly
    static func _noise(_ smoothness: CGFloat, _ size: CGSize, channels: Int, vectors: Bool) -> _SKPixels {
        let w = max(1, Int(size.width)), h = max(1, Int(size.height))
        let s = Double(min(max(smoothness, 0), 1))
        let cell = max(1, 1 + s * s * Double(max(w, h)) / 2)
        let gw = Int(Double(w) / cell) + 2, gh = Int(Double(h) / cell) + 2
        var lattice = [SIMD3<Float>](repeating: .zero, count: gw * gh)
        for i in lattice.indices {
            if vectors {        // random directions in the upper hemisphere
                var v = SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: 0.05...1))
                v /= max(0.0001, (v * v).sum().squareRoot()); lattice[i] = v
            } else {
                let g = Float.random(in: 0...1)
                lattice[i] = channels == 1 ? SIMD3(g, g, g) : SIMD3(g, Float.random(in: 0...1), Float.random(in: 0...1))
            }
        }
        var out = _SKPixels(w: w, h: h)
        func smooth(_ t: Float) -> Float { t * t * (3 - 2 * t) }
        for y in 0..<h {
            let fy = Float(Double(y) / cell), y0 = Int(fy), ty = smooth(fy - Float(y0))
            for x in 0..<w {
                let fx = Float(Double(x) / cell), x0 = Int(fx), tx = smooth(fx - Float(x0))
                let a = lattice[y0 * gw + x0], b = lattice[y0 * gw + x0 + 1], c = lattice[(y0 + 1) * gw + x0], d = lattice[(y0 + 1) * gw + x0 + 1]
                var v = (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
                if vectors { v /= max(0.0001, (v * v).sum().squareRoot()); v = (v + 1) / 2 }
                out.set(x, y, SIMD4(v.x, v.y, v.z, 1))
            }
        }
        return out
    }
    /// a normal map from the image's brightness (alpha-weighted) as a height field
    func _normalMap(smoothness: CGFloat, contrast: CGFloat) -> _SKPixels? {
        guard let p = _pixels() else { return nil }
        var height = [Float](repeating: 0, count: p.w * p.h)
        for y in 0..<p.h { for x in 0..<p.w { let c = p.rgba(x, y); height[y * p.w + x] = (0.299 * c.x + 0.587 * c.y + 0.114 * c.z) * c.w } }
        // smoothness: a box blur, up to 1/8 of the size
        let radius = Int((Double(min(max(smoothness, 0), 1)) * Double(max(p.w, p.h)) / 8).rounded())
        if radius > 0 {
            for pass in 0..<2 {
                var tmp = height
                for y in 0..<p.h { for x in 0..<p.w {
                    var sum: Float = 0, n: Float = 0
                    for k in -radius...radius {
                        let xx = pass == 0 ? min(max(x + k, 0), p.w - 1) : x, yy = pass == 1 ? min(max(y + k, 0), p.h - 1) : y
                        sum += height[yy * p.w + xx]; n += 1
                    }
                    tmp[y * p.w + x] = sum / n
                } }
                height = tmp
            }
        }
        var out = _SKPixels(w: p.w, h: p.h)
        let k = Float(contrast) * 4
        func hh(_ x: Int, _ y: Int) -> Float { height[min(max(y, 0), p.h - 1) * p.w + min(max(x, 0), p.w - 1)] }
        for y in 0..<p.h { for x in 0..<p.w {
            // Sobel; y grows downwards in the pixels, upwards in the normal
            let dx = (hh(x + 1, y - 1) + 2 * hh(x + 1, y) + hh(x + 1, y + 1)) - (hh(x - 1, y - 1) + 2 * hh(x - 1, y) + hh(x - 1, y + 1))
            let dyDown = (hh(x - 1, y + 1) + 2 * hh(x, y + 1) + hh(x + 1, y + 1)) - (hh(x - 1, y - 1) + 2 * hh(x, y - 1) + hh(x + 1, y - 1))
            var n = SIMD3<Float>(-dx * k, dyDown * k, 1)
            n /= (n * n).sum().squareRoot()
            out.set(x, y, SIMD4((n.x + 1) / 2, (n.y + 1) / 2, (n.z + 1) / 2, 1))
        } }
        return out
    }
}

extension SKTexture {
    /// random colors (or gray levels), smoother as smoothness goes from 0 to 1
    @objc public convenience init(noiseWithSmoothness smoothness: CGFloat, size: CGSize, grayscale: Bool) {
        let p = SKTexture._noise(smoothness, size, channels: grayscale ? 1 : 3, vectors: false)
        let hd = isim_image_create_bgra(Int32(p.w), Int32(p.h))
        p.px.withUnsafeBufferPointer { isim_image_update_bgra(hd, $0.baseAddress, Int32(p.w), Int32(p.h)) }
        self.init(handle: hd, pixels: CGRect(x: 0, y: 0, width: p.w, height: p.h), scale: 1, owner: nil)
    }
    /// random unit vectors (a normal map), smoother as smoothness goes from 0 to 1
    @objc public convenience init(vectorNoiseWithSmoothness smoothness: CGFloat, size: CGSize) {
        let p = SKTexture._noise(smoothness, size, channels: 3, vectors: true)
        let hd = isim_image_create_bgra(Int32(p.w), Int32(p.h))
        p.px.withUnsafeBufferPointer { isim_image_update_bgra(hd, $0.baseAddress, Int32(p.w), Int32(p.h)) }
        self.init(handle: hd, pixels: CGRect(x: 0, y: 0, width: p.w, height: p.h), scale: 1, owner: nil)
    }
    /// a normal map treating the texture's brightness as height
    @objc(textureByGeneratingNormalMap) public func generatingNormalMap() -> Self { generatingNormalMap(withSmoothness: 0, contrast: 1) }
    @objc(textureByGeneratingNormalMapWithSmoothness:contrast:) public func generatingNormalMap(withSmoothness smoothness: CGFloat, contrast: CGFloat) -> Self {
        guard let p = _normalMap(smoothness: smoothness, contrast: contrast) else { return self }
        let hd = isim_image_create_bgra(Int32(p.w), Int32(p.h))
        p.px.withUnsafeBufferPointer { isim_image_update_bgra(hd, $0.baseAddress, Int32(p.w), Int32(p.h)) }
        return (SKTexture(handle: hd, pixels: CGRect(x: 0, y: 0, width: p.w, height: p.h), scale: pointScale, owner: nil) as? Self) ?? self
    }
}

// MARK: - rendering nodes into textures

extension SKView {
    /// node (its own coordinates; a scene: its frame with its background) → texture at the screen scale
    func _texture(from node: SKNode, crop: CGRect?) -> SKTexture? {
        let rect: CGRect
        if let crop { rect = crop }
        else if let s = node as? SKScene { rect = s.frame }
        else {
            var r = node.contentRect
            for c in node.children where !c.isHidden { r = r.union(c.calculateAccumulatedFrame()) }
            rect = r
        }
        guard rect.width >= 1, rect.height >= 1, !rect.isInfinite else { return nil }
        let scale = max(1, window?.screen.scale ?? UIScreen.main.scale)
        guard isim_gfx_offscreen_begin(rect.width, rect.height, scale, 0) != 0 else { return nil }
        if let s = node as? SKScene {
            let bg = _rgba(s.backgroundColor)
            bg.withUnsafeBufferPointer { isim_gfx_fill_rounded(0, 0, rect.width, rect.height, 0, $0.baseAddress) }
        }
        let t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: -rect.minX, ty: rect.maxY)
        renderTree(node, t, 1, includeRoot: !(node is SKScene))
        let hd = isim_gfx_offscreen_snapshot()
        isim_gfx_offscreen_end()
        guard hd > 0 else { return nil }
        var pw = 0.0, ph = 0.0
        isim_image_pixel_size(hd, &pw, &ph)
        return SKTexture(handle: hd, pixels: CGRect(x: 0, y: 0, width: pw, height: ph), scale: scale, owner: nil)
    }
}

// MARK: - 9-slice sprites

extension SKSpriteNode {
    var _isNineSlice: Bool { centerRect != CGRect(x: 0, y: 0, width: 1, height: 1) && centerRect.width > 0 && centerRect.height > 0 }
    /// The corners keep their size on screen (they are not stretched by size or xScale / yScale); the edges stretch
    /// along one axis and the center along both.
    func _drawNineSlice(_ t: SKTexture, _ r: CGRect, alpha a: CGFloat, blend: [Double]?, factor: Double) {
        let ts = t.size(), c = centerRect
        let sx = max(0.0001, abs(xScale)), sy = max(0.0001, abs(yScale))
        // corner sizes in node points (so that they are their texture size in the parent)
        var l = c.minX * ts.width / sx, rt = (1 - c.maxX) * ts.width / sx
        var b = c.minY * ts.height / sy, tp = (1 - c.maxY) * ts.height / sy
        if l + rt > r.width { let k = r.width / max(0.0001, l + rt); l *= k; rt *= k }
        if b + tp > r.height { let k = r.height / max(0.0001, b + tp); b *= k; tp *= k }
        let xs = [r.minX, r.minX + l, r.maxX - rt, r.maxX], ys = [r.minY, r.minY + b, r.maxY - tp, r.maxY]
        let p = t.pixels
        // source columns / rows in host pixels (rows from the top)
        let us: [CGFloat] = [0, c.minX, c.maxX, 1], vs: [CGFloat] = [0, c.minY, c.maxY, 1]
        isim_gfx_save()
        isim_gfx_scale(1, -1)
        for i in 0..<3 {
            for j in 0..<3 {
                let dw = xs[i + 1] - xs[i], dh = ys[j + 1] - ys[j]
                guard dw > 0.001, dh > 0.001 else { continue }
                let sxp = p.minX + us[i] * p.width, swp = (us[i + 1] - us[i]) * p.width
                let syp = p.minY + (1 - vs[j + 1]) * p.height, shp = (vs[j + 1] - vs[j]) * p.height
                guard swp > 0, shp > 0 else { continue }
                if let blend {
                    blend.withUnsafeBufferPointer { bp in
                        isim_image_draw_part(t.handle, sxp, syp, swp, shp, xs[i], -ys[j + 1], dw, dh, t.filteringMode == .nearest ? 1 : 0, bp.baseAddress, factor, Double(a))
                    }
                } else {
                    isim_image_draw_part(t.handle, sxp, syp, swp, shp, xs[i], -ys[j + 1], dw, dh, t.filteringMode == .nearest ? 1 : 0, nil, 0, Double(a))
                }
            }
        }
        isim_gfx_restore()
    }
}

// MARK: - lighting

nonisolated(unsafe) var _skFrame = 0
/// inside SKView.draw (the tree cannot change): per-frame caches hold
nonisolated(unsafe) var _skDrawing = false
nonisolated(unsafe) private var _skLightCache: [ObjectIdentifier: (frame: Int, lights: [SKLightNode], casters: [SKNode])] = [:]

extension SKScene {
    /// enabled lights and shadow casters (rebuilt once per frame)
    func _lighting() -> (lights: [SKLightNode], casters: [SKNode]) {
        let id = ObjectIdentifier(self)
        if _skDrawing, let c = _skLightCache[id], c.frame == _skFrame { return (c.lights, c.casters) }
        var lights: [SKLightNode] = [], casters: [SKNode] = []
        func walk(_ n: SKNode) {
            for c in n.children where !c.isHidden {
                if let l = c as? SKLightNode, l.isEnabled { lights.append(l) }
                if let s = c as? SKSpriteNode, s.shadowCastBitMask != 0 { casters.append(s) }
                walk(c)
            }
        }
        walk(self)
        if _skLightCache.count > 32 { _skLightCache.removeAll() }
        _skLightCache[id] = (_skFrame, lights, casters)
        return (lights, casters)
    }
}

/// does segment a-b cross the convex polygon (or start inside it)?
private func _segmentHits(_ a: CGPoint, _ b: CGPoint, _ poly: [CGPoint]) -> Bool {
    func cross(_ o: CGPoint, _ p: CGPoint, _ q: CGPoint) -> CGFloat { (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x) }
    for i in 0..<poly.count {
        let c = poly[i], d = poly[(i + 1) % poly.count]
        let d1 = cross(c, d, a), d2 = cross(c, d, b), d3 = cross(a, b, c), d4 = cross(a, b, d)
        if ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0)) { return true }
    }
    return false
}

extension SKSpriteNode {
    var _isLit: Bool { lightingBitMask != 0 || shadowedBitMask != 0 }
    /// draws the sprite lit by the scene's lights; false when no light reaches it (then it draws as usual)
    func _drawLit(_ r: CGRect, alpha a: CGFloat) -> Bool {
        guard let scene else { return false }
        let (all, casters) = scene._lighting()
        let lights = all.filter { ($0.categoryBitMask & (lightingBitMask | shadowedBitMask)) != 0 }
        guard !lights.isEmpty else { return false }
        // the base color: the texture (blended with the color) or the color
        var base: _SKPixels
        var scale: CGFloat = 1
        if let t = texture, let p = t._pixels() {
            base = p; scale = t.pointScale
            if colorBlendFactor > 0 {
                let col = _rgba(color), f = Float(colorBlendFactor)
                for y in 0..<base.h { for x in 0..<base.w {
                    var c = base.rgba(x, y)
                    c.x = c.x * (1 - f) + Float(col[0]) * f; c.y = c.y * (1 - f) + Float(col[1]) * f; c.z = c.z * (1 - f) + Float(col[2]) * f
                    base.set(x, y, c)
                } }
            }
        } else {
            let w = max(1, Int(size.width.rounded())), h = max(1, Int(size.height.rounded()))
            base = _SKPixels(w: w, h: h)
            let col = _rgba(color), c = SIMD4(Float(col[0]), Float(col[1]), Float(col[2]), Float(col[3]))
            for y in 0..<h { for x in 0..<w { base.set(x, y, c) } }
        }
        let normals = normalTexture?._pixels()
        let st = sceneTransform
        let rot = atan2(Double(st.b), Double(st.a))
        let cr = Float(cos(rot)), sr = Float(sin(rot))
        struct L { let pos: CGPoint; let color: SIMD3<Float>; let ambient: SIMD3<Float>; let shadow: SIMD4<Float>; let falloff: Float; let lights: Bool; let shadows: Bool; let occluders: [[CGPoint]] }
        let ls: [L] = lights.map { l in
            let c = _rgba(l.lightColor), am = _rgba(l.ambientColor), sh = _rgba(l.shadowColor)
            let shadows = (l.categoryBitMask & shadowedBitMask) != 0
            let occ: [[CGPoint]] = shadows ? casters.filter { $0 !== self && (($0 as? SKSpriteNode)?.shadowCastBitMask ?? 0) & l.categoryBitMask != 0 }.map { n in
                let cr = n.contentRect, t = n.sceneTransform
                return [CGPoint(x: cr.minX, y: cr.minY), CGPoint(x: cr.maxX, y: cr.minY), CGPoint(x: cr.maxX, y: cr.maxY), CGPoint(x: cr.minX, y: cr.maxY)].map { $0.applying(t) }
            } : []
            return L(pos: l.convert(.zero, to: scene), color: SIMD3(Float(c[0]), Float(c[1]), Float(c[2])) * Float(c[3]),
                     ambient: SIMD3(Float(am[0]), Float(am[1]), Float(am[2])) * Float(am[3]), shadow: SIMD4(Float(sh[0]), Float(sh[1]), Float(sh[2]), Float(sh[3])),
                     falloff: Float(max(0, l.falloff)), lights: (l.categoryBitMask & lightingBitMask) != 0, shadows: shadows, occluders: occ)
        }
        var out = _SKPixels(w: base.w, h: base.h)
        let ambient = ls.reduce(SIMD3<Float>.zero) { $0 + $1.ambient }
        for y in 0..<base.h {
            for x in 0..<base.w {
                var c = base.rgba(x, y)
                guard c.w > 0 else { continue }
                let u = (CGFloat(x) + 0.5) / CGFloat(base.w), v = 1 - (CGFloat(y) + 0.5) / CGFloat(base.h)
                let P = CGPoint(x: r.minX + u * r.width, y: r.minY + v * r.height).applying(st)
                var n = SIMD3<Float>(0, 0, 1)
                if let nm = normals {
                    let s = nm.sample(Float(u), Float(v))
                    let tn = SIMD3(s.x * 2 - 1, s.y * 2 - 1, s.z * 2 - 1)
                    n = SIMD3(tn.x * cr - tn.y * sr, tn.x * sr + tn.y * cr, tn.z)
                    n /= max(0.0001, (n * n).sum().squareRoot())
                }
                var light = ambient
                var shade = SIMD4<Float>.zero
                for l in ls {
                    let dx = Float(l.pos.x - P.x), dy = Float(l.pos.y - P.y), d = (dx * dx + dy * dy).squareRoot()
                    if l.shadows && l.occluders.contains(where: { _segmentHits(P, l.pos, $0) }) {
                        if l.shadow.w > shade.w { shade = l.shadow }
                        continue
                    }
                    guard l.lights else { continue }
                    var diffuse: Float = 1
                    if normals != nil {
                        var L3 = SIMD3<Float>(dx, dy, 60); L3 /= (L3 * L3).sum().squareRoot()
                        diffuse = max(0, (n * L3).sum())
                    }
                    light += l.color * (diffuse * Float(pow(Double(1 + d / 100), Double(-l.falloff))))
                }
                c.x *= light.x; c.y *= light.y; c.z *= light.z
                if shade.w > 0 { c.x = c.x * (1 - shade.w) + shade.x * shade.w; c.y = c.y * (1 - shade.w) + shade.y * shade.w; c.z = c.z * (1 - shade.w) + shade.z * shade.w }
                out.set(x, y, c)
            }
        }
        let hd = _skBox().update(out)
        isim_gfx_save()
        if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
        isim_gfx_scale(1, -1)
        isim_image_draw_part(hd, 0, 0, Double(out.w), Double(out.h), r.minX, -r.maxY, r.width, r.height, texture?.filteringMode == .nearest ? 1 : 0, nil, 0, Double(a))
        isim_gfx_restore()
        _ = scale
        return true
    }
}
