// isim SpriteKit: custom shaders (SKShader) run on the CPU through Core Image (adapted: no GPU). A shader's GLSL
// fragment program becomes a Core Image Kernel Language kernel — the language is GLSL's, so the source is kept: its
// `void main()` becomes a kernel that returns gl_FragColor, and SpriteKit's inputs are the kernel's arguments:
// u_texture (the sprite's texture, or its color), u_time, u_sprite_size, u_path_length, v_tex_coord (0...1),
// v_color_mix, v_path_distance (strokes), SKDefaultShading(), texture2D(), the SKUniforms (float, vectors, matrices,
// textures) and the SKAttributes (values per node). isim's kernel interpreter evaluates it for every pixel at the
// sprite's texture resolution (else one pixel per point, at most 256 a side), in an unmanaged color space like
// SpriteKit's; the result is kept until an input changes (every frame for programs that read u_time).
// Shaders run on sprites, shape fills and strokes, and effect nodes; not on emitters or tile maps (logged).
import Foundation
import CoreImage
import isim_host

final class _SKShaderProgram {
    let kernel: CIKernel?
    /// the program reads u_time: it changes every frame
    let animated: Bool
    let uniforms: [(String, SKUniformType)]
    let attributes: [(String, SKAttributeType)]
    var failed = false

    /// the kernel source for a shader with these uniforms and attributes
    static func translate(_ src: String, uniforms: [(String, SKUniformType)], attributes: [(String, SKAttributeType)]) -> String? {
        var lines: [String] = []
        for l in src.components(separatedBy: "\n") {
            let t = l.trimmingCharacters(in: .whitespaces)
            // declarations SpriteKit makes itself
            if t.hasPrefix("precision ") || t.hasPrefix("uniform ") || t.hasPrefix("varying ") || t.hasPrefix("attribute ") { continue }
            lines.append(l)
        }
        var s = lines.joined(separator: "\n")
        s = s.replacingOccurrences(of: "SKDefaultShading()", with: "_skDefault(u_texture, v_tex_coord, _sk_color)")
        s = s.replacingOccurrences(of: "gl_FragCoord", with: "_sk_fragcoord")
        s = s.replacingOccurrences(of: "texture2D(", with: "_skTexture2D(")
        guard let m = s.range(of: #"void\s+main\s*\(\s*(void)?\s*\)\s*\{"#, options: .regularExpression) else { return nil }
        // the matching closing brace
        var depth = 1, i = m.upperBound
        while i < s.endIndex, depth > 0 {
            if s[i] == "{" { depth += 1 } else if s[i] == "}" { depth -= 1 }
            if depth > 0 { i = s.index(after: i) }
        }
        guard depth == 0 else { return nil }
        var body = String(s[m.upperBound..<i])
        body = body.replacingOccurrences(of: #"return\s*;"#, with: "return gl_FragColor;", options: .regularExpression)
        func glslType(_ t: SKUniformType) -> String {
            switch t {
            case .float: return "float"
            case .floatVector2: return "vec2"
            case .floatVector3: return "vec3"
            case .floatVector4: return "vec4"
            case .floatMatrix2: return "mat2"
            case .floatMatrix3: return "mat3"
            case .floatMatrix4: return "mat4"
            case .texture: return "sampler"
            case .none: return "float"
            }
        }
        func attrType(_ t: SKAttributeType) -> String {
            switch t {
            case .vectorFloat2, .vectorHalfFloat2: return "vec2"
            case .vectorFloat3, .vectorHalfFloat3: return "vec3"
            case .vectorFloat4, .vectorHalfFloat4: return "vec4"
            default: return "float"
            }
        }
        var params = ["sampler u_texture", "sampler _sk_pathdist", "float u_time", "vec2 u_sprite_size", "float u_path_length", "vec4 v_color_mix", "vec4 _sk_color", "vec2 _sk_px"]
        params += uniforms.map { "\(glslType($0.1)) \($0.0)" }
        params += attributes.map { "\(attrType($0.1)) \($0.0)" }
        let prelude = """
        vec4 _skTexture2D(sampler s, vec2 uv) { return sample(s, samplerTransform(s, uv * samplerSize(s))); }
        vec4 _skDefault(sampler s, vec2 uv, vec4 col) { vec4 c = _skTexture2D(s, uv); return vec4(mix(c.rgb, col.rgb * c.a, col.a), c.a); }

        """
        let head = String(s[s.startIndex..<m.lowerBound]), tail = String(s[s.index(after: i)...])
        return prelude + head + "kernel vec4 _skmain(" + params.joined(separator: ", ") + ") {\n" +
            "vec2 v_tex_coord = destCoord() / _sk_px; vec4 gl_FragColor = vec4(0.0); vec4 _sk_fragcoord = vec4(destCoord(), 0.0, 1.0);\n" +
            "float v_path_distance = sample(_sk_pathdist, samplerTransform(_sk_pathdist, destCoord())).r;\n" +
            body + "\nreturn gl_FragColor;\n}\n" + tail
    }

    init(_ shader: SKShader) {
        animated = shader.source?.contains("u_time") ?? false
        uniforms = shader.uniforms.map { ($0.name, $0.uniformType) }
        attributes = shader.attributes.map { ($0.name, $0.type) }
        guard let src = shader.source, let k = _SKShaderProgram.translate(src, uniforms: uniforms, attributes: attributes) else {
            NSLog("isim SpriteKit: SKShader: no void main() in the source; nodes draw without it")
            kernel = nil; return
        }
        kernel = CIKernel(source: k)
        if kernel == nil { NSLog("isim SpriteKit: SKShader: the program did not compile; nodes draw without it") }
    }
}

nonisolated(unsafe) private var _skProgramKey: UInt8 = 0
final class _SKProgramBox { var key = ""; var program: _SKShaderProgram? }
nonisolated(unsafe) let _skShaderContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
let _skShaderStart = ProcessInfo.processInfo.systemUptime
/// keeps the last frame's image (and so its host image) alive
final class _SKImageKeeper { var image: CGImage?; var signature = "" }
nonisolated(unsafe) private var _skKeeperKey: UInt8 = 0
nonisolated(unsafe) private var _skKeeper2Key: UInt8 = 0

extension SKShader {
    /// the compiled program (again when the source, uniforms or attributes change)
    var _program: _SKShaderProgram? {
        let key = (source ?? "") + "|" + uniforms.map { "\($0.name):\($0.uniformType.rawValue)" }.joined(separator: ",") + "|" + attributes.map { "\($0.name):\($0.type.rawValue)" }.joined(separator: ",")
        let box = (objc_getAssociatedObject(self, &_skProgramKey) as? _SKProgramBox) ?? {
            let b = _SKProgramBox(); objc_setAssociatedObject(self, &_skProgramKey, b, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)); return b
        }()
        if box.key != key || box.program == nil { box.key = key; box.program = _SKShaderProgram(self) }
        return box.program?.kernel == nil ? nil : box.program
    }
}

/// one pixel of transparent black, the default for missing samplers
private let _skEmpty = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

extension SKNode {
    /// runs `shader` over a w × h pixel area (input: the base texture, or a color); nil when it cannot run
    func _runShader(_ shader: SKShader, base: CIImage?, color: [Double], blendFactor: CGFloat, w: Int, h: Int, spriteSize: CGSize,
                    pathLength: CGFloat = 0, pathDistance: CIImage? = nil, second: Bool = false) -> CGImage? {
        guard let prog = shader._program, let kernel = prog.kernel, w > 0, h > 0 else { return nil }
        // the last image, when nothing it depends on changed (programs reading u_time run every frame)
        let key = second ? UnsafeRawPointer(&_skKeeper2Key) : UnsafeRawPointer(&_skKeeperKey)
        let keeper = (objc_getAssociatedObject(self, key) as? _SKImageKeeper) ?? {
            let k = _SKImageKeeper(); objc_setAssociatedObject(self, key, k, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)); return k
        }()
        var sig = ""
        if !prog.animated {
            sig = "\(ObjectIdentifier(shader).hashValue)|\(base.map { ObjectIdentifier($0).hashValue } ?? 0)|\(color)|\(blendFactor)|\(w)x\(h)|\(spriteSize)|\(pathLength)|\(pathDistance != nil)"
            for u in shader.uniforms { sig += "|\(u.name)=\(u.floatValue),\(u.vectorFloat2Value),\(u.vectorFloat3Value),\(u.vectorFloat4Value),\(u._matrixValues),\(u.textureValue.map { ObjectIdentifier($0).hashValue } ?? 0)" }
            for (name, _) in prog.attributes { let v = attributeValues[name]; sig += "|\(name)=\(v?.floatValue ?? 0),\(v?.vectorFloat2Value ?? .zero),\(v?.vectorFloat3Value ?? .zero),\(v?.vectorFloat4Value ?? .zero)" }
            if keeper.signature == sig, let img = keeper.image { return img }
        }
        let extent = CGRect(x: 0, y: 0, width: w, height: h)
        let tex = base ?? CIImage(color: CIColor(red: CGFloat(color[0]), green: CGFloat(color[1]), blue: CGFloat(color[2]), alpha: CGFloat(color[3]))).cropped(to: extent)
        let col = CIVector(x: CGFloat(color[0]), y: CGFloat(color[1]), z: CGFloat(color[2]), w: base == nil ? 0 : blendFactor)
        var args: [Any] = [tex, pathDistance ?? _skEmpty, Float(ProcessInfo.processInfo.systemUptime - _skShaderStart),
                           CIVector(x: spriteSize.width, y: spriteSize.height), Float(pathLength),
                           CIVector(x: CGFloat(color[0]), y: CGFloat(color[1]), z: CGFloat(color[2]), w: CGFloat(color[3])), col,
                           CIVector(x: CGFloat(w), y: CGFloat(h))]
        var extents: [CGRect] = [tex.extent, (pathDistance ?? _skEmpty).extent]
        for (name, type) in prog.uniforms {
            let u = shader.uniformNamed(name)
            switch type {
            case .float, .none: args.append(u?.floatValue ?? 0)
            case .floatVector2: let v = u?.vectorFloat2Value ?? .zero; args.append(CIVector(x: CGFloat(v.x), y: CGFloat(v.y)))
            case .floatVector3: let v = u?.vectorFloat3Value ?? .zero; args.append(CIVector(x: CGFloat(v.x), y: CGFloat(v.y), z: CGFloat(v.z)))
            case .floatVector4: let v = u?.vectorFloat4Value ?? .zero; args.append(CIVector(x: CGFloat(v.x), y: CGFloat(v.y), z: CGFloat(v.z), w: CGFloat(v.w)))
            case .floatMatrix2, .floatMatrix3, .floatMatrix4: args.append(CIVector(values: (u?._matrixValues ?? []).map { CGFloat($0) }, count: u?._matrixValues.count ?? 0))
            case .texture:
                let img = u?.textureValue?._cgImage().map { CIImage(cgImage: $0, options: [.colorSpace: NSNull()]) } ?? _skEmpty
                args.append(img); extents.append(img.extent)
            }
        }
        for (name, type) in prog.attributes {
            let v = attributeValues[name]
            switch type {
            case .vectorFloat2, .vectorHalfFloat2: let x = v?.vectorFloat2Value ?? .zero; args.append(CIVector(x: CGFloat(x.x), y: CGFloat(x.y)))
            case .vectorFloat3, .vectorHalfFloat3: let x = v?.vectorFloat3Value ?? .zero; args.append(CIVector(x: CGFloat(x.x), y: CGFloat(x.y), z: CGFloat(x.z)))
            case .vectorFloat4, .vectorHalfFloat4: let x = v?.vectorFloat4Value ?? .zero; args.append(CIVector(x: CGFloat(x.x), y: CGFloat(x.y), z: CGFloat(x.z), w: CGFloat(x.w)))
            default: args.append(v?.floatValue ?? 0)
            }
        }
        // samplers can read anywhere in their images
        var samplerExtents: [CGRect] = []
        var ti = 2
        samplerExtents = [extents[0], extents[1]]
        for (_, type) in prog.uniforms where type == .texture { samplerExtents.append(extents[ti]); ti += 1 }
        guard let out = kernel.apply(extent: extent, roiCallback: { i, _ in Int(i) < samplerExtents.count ? samplerExtents[Int(i)] : .zero }, arguments: args),
              let cg = _skShaderContext.createCGImage(out, from: extent) else {
            if !prog.failed { prog.failed = true; NSLog("isim SpriteKit: SKShader: the program failed to run; nodes draw without it") }
            return nil
        }
        keeper.image = cg; keeper.signature = sig
        return cg
    }
    /// draws an image filling r (node space, y up)
    func _drawImage(_ cg: CGImage, in r: CGRect, alpha a: CGFloat, blend: SKBlendMode, nearest: Bool = false) {
        var px = CGRect.zero
        let hd = isim_cg_image_handle(cg, &px)
        guard hd > 0 else { return }
        isim_gfx_save()
        if blend != .alpha { isim_gfx_set_blend(_hostBlend(blend)) }
        isim_gfx_scale(1, -1)
        isim_image_draw_part(hd, px.minX, px.minY, px.width, px.height, r.minX, -r.maxY, r.width, r.height, nearest ? 1 : 0, nil, 0, Double(a))
        isim_gfx_restore()
    }
}

/// pixel count for shading a rectangle of points at a scale, at most 256 a side
func _skShadePixels(_ size: CGSize, scale: CGFloat) -> (Int, Int) {
    let k = min(scale, 256 / max(1, max(size.width, size.height)))
    return (max(1, Int((size.width * k).rounded())), max(1, Int((size.height * k).rounded())))
}

extension SKSpriteNode {
    /// draws the sprite through its shader; false when it cannot run
    func _drawShaded(_ shader: SKShader, _ r: CGRect, alpha a: CGFloat) -> Bool {
        var base: CIImage?
        var w: Int, h: Int
        if let t = texture, t.handle > 0, let cg = t._cgImage() {
            base = CIImage(cgImage: cg, options: [.colorSpace: NSNull()])
            w = cg.width; h = cg.height
        } else {
            (w, h) = _skShadePixels(size, scale: 1)
        }
        guard let cg = _runShader(shader, base: base, color: _rgba(color), blendFactor: colorBlendFactor, w: w, h: h, spriteSize: size) else { return false }
        _drawImage(cg, in: r, alpha: a, blend: blendMode, nearest: texture?.filteringMode == .nearest)
        return true
    }
}

// MARK: - shape textures and shaders

extension SKShapeNode {
    /// the distance along the path of each pixel's nearest point (for v_path_distance), as a float image
    func _pathDistanceImage(_ box: CGRect, w: Int, h: Int) -> CIImage? {
        guard let path else { return nil }
        let subs = _pathPoints(path)
        var segs: [(CGPoint, CGPoint, CGFloat)] = []      // a, b, distance at a
        var total: CGFloat = 0
        for sp in subs { for i in 1..<sp.count { segs.append((sp[i - 1], sp[i], total)); total += _len(_sub(sp[i], sp[i - 1])) } }
        guard !segs.isEmpty else { return nil }
        var px = [Float](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                // CIImage bitmaps: the first row is the top
                let p = CGPoint(x: box.minX + (CGFloat(x) + 0.5) / CGFloat(w) * box.width, y: box.maxY - (CGFloat(y) + 0.5) / CGFloat(h) * box.height)
                var best = CGFloat.greatestFiniteMagnitude, along: CGFloat = 0
                for (a, b, d0) in segs {
                    let ab = _sub(b, a), l2 = ab.x * ab.x + ab.y * ab.y
                    let t = l2 > 0 ? min(1, max(0, ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / l2)) : 0
                    let q = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t), d = _len(_sub(p, q))
                    if d < best { best = d; along = d0 + t * l2.squareRoot() }
                }
                px[(y * w + x) * 4] = Float(along); px[(y * w + x) * 4 + 3] = 1
            }
        }
        let data = px.withUnsafeBufferPointer { Data(buffer: $0) }
        return CIImage(bitmapData: data, bytesPerRow: w * 16, size: CGSize(width: w, height: h), format: .RGBAf, colorSpace: nil)
    }

    /// fill / stroke drawn with a texture or a shader instead of a plain color; false: nothing special to draw
    func _drawFillSpecial(_ a: CGFloat) -> Bool {
        guard let path, fillTexture != nil || fillShader != nil else { return false }
        let box = path.boundingBox
        guard box.width > 0, box.height > 0 else { return false }
        var img: CGImage?
        let col = _rgba(fillColor)
        if let sh = fillShader {
            let base = fillTexture?._cgImage().map { CIImage(cgImage: $0, options: [.colorSpace: NSNull()]) }
            let (w, h) = base.map { (Int($0.extent.width), Int($0.extent.height)) } ?? _skShadePixels(box.size, scale: 1)
            img = _runShader(sh, base: base, color: col, blendFactor: base == nil ? 0 : 1, w: w, h: h, spriteSize: box.size, pathLength: lineLength)
        }
        guard let ctx = UIGraphicsGetCurrentContext() else { return false }
        isim_gfx_save()
        isim_path_begin(); ctx.addPath(path); isim_gfx_clip_path()
        if let img { _drawImage(img, in: box, alpha: a, blend: blendMode) }
        else if let t = fillTexture, t.handle > 0 {
            // the texture stretched over the path's bounds, tinted by the fill color
            isim_gfx_save()
            if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
            isim_gfx_scale(1, -1)
            var tint = col; tint[3] = 1
            let white = col[0] > 0.999 && col[1] > 0.999 && col[2] > 0.999
            tint.withUnsafeBufferPointer { b in
                isim_image_draw_part(t.handle, t.pixels.minX, t.pixels.minY, t.pixels.width, t.pixels.height, box.minX, -box.maxY, box.width, box.height,
                                     t.filteringMode == .nearest ? 1 : 0, white ? nil : b.baseAddress, white ? 0 : 0.5, Double(a) * col[3])
            }
            isim_gfx_restore()
        }
        isim_gfx_restore()
        isim_path_begin()
        return true
    }
    func _drawStrokeSpecial(_ a: CGFloat) -> Bool {
        guard let path, strokeTexture != nil || strokeShader != nil, lineWidth > 0 else { return false }
        let box = path.boundingBox.insetBy(dx: -lineWidth / 2 - glowWidth, dy: -lineWidth / 2 - glowWidth)
        guard box.width > 0, box.height > 0, let ctx = UIGraphicsGetCurrentContext() else { return false }
        let col = _rgba(strokeColor)
        // the stroke is the mask; the texture or shader output fills it
        isim_gfx_save()
        if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
        isim_gfx_push_group()
        isim_gfx_set_blend(0)
        if let sh = strokeShader {
            let (w, h) = _skShadePixels(box.size, scale: 1)
            let base = strokeTexture?._cgImage().map { CIImage(cgImage: $0, options: [.colorSpace: NSNull()]).transformed(by: CGAffineTransform(scaleX: CGFloat(w) / CGFloat($0.width), y: CGFloat(h) / CGFloat($0.height))) }
            if let img = _runShader(sh, base: base, color: col, blendFactor: base == nil ? 0 : 1, w: w, h: h, spriteSize: box.size, pathLength: lineLength,
                                    pathDistance: _pathDistanceImage(box, w: w, h: h), second: true) {
                _drawImage(img, in: box, alpha: 1, blend: .alpha)
            }
        } else if let t = strokeTexture, t.handle > 0 {
            isim_gfx_save(); isim_gfx_scale(1, -1)
            isim_image_draw_part(t.handle, t.pixels.minX, t.pixels.minY, t.pixels.width, t.pixels.height, box.minX, -box.maxY, box.width, box.height, 0, nil, 0, col[3])
            isim_gfx_restore()
        }
        isim_gfx_push_group()
        isim_path_begin(); ctx.addPath(path)
        _applyLineStyle()
        let white: [Double] = [1, 1, 1, 1]
        white.withUnsafeBufferPointer { isim_path_stroke(lineWidth, $0.baseAddress) }
        isim_path_begin()
        isim_gfx_pop_group_masked(Double(a))
        isim_gfx_restore()
        return true
    }
    /// cap, join and miter limit for the next stroke
    func _applyLineStyle() {
        isim_path_set_line_style(Int32(lineCap.rawValue), Int32(lineJoin.rawValue), Double(miterLimit), nil, 0, 0)
    }
}
