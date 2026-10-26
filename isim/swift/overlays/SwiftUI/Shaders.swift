// isim SwiftUI: Metal shaders (issue #327): ShaderLibrary, Shader and the colorEffect / layerEffect / distortionEffect
// modifiers. Adapted: the [[stitchable]] Metal functions are compiled for the CPU by isim's Metal compiler
// (tools/mslc.py; isim build puts them in default.metallib.dylib) and run per pixel over the view's rendered content
// (UIView _isim_setPixelShader:, isim_gfx_pop_group_shaded), not on a GPU.
import Foundation
import UIKit
import Darwin
import isim_host

// MARK: - libraries and functions

/// A Metal library of [[stitchable]] functions, looked up by name with dynamic member lookup (`ShaderLibrary.wave`).
@available(iOS 17.0, *)
@dynamicMemberLookup
public struct ShaderLibrary: Equatable, @unchecked Sendable {
    enum Source: Equatable { case bundle(Bundle), url(URL), data(Data) }
    let source: Source
    /// the main bundle's default.metallib
    public static let `default` = ShaderLibrary(source: .bundle(.main))
    public static func bundle(_ bundle: Bundle) -> ShaderLibrary { ShaderLibrary(source: .bundle(bundle)) }
    public init(data: Data) { source = .data(data) }
    public init(url: URL) { source = .url(url) }
    init(source: Source) { self.source = source }
    public static subscript(dynamicMember name: String) -> ShaderFunction { ShaderFunction(library: .default, name: name) }
    public subscript(dynamicMember name: String) -> ShaderFunction { ShaderFunction(library: self, name: name) }
}

/// A function of a shader library; calling it with arguments makes a Shader.
@available(iOS 17.0, *)
@dynamicCallable
public struct ShaderFunction: Equatable, Sendable {
    public var library: ShaderLibrary
    public var name: String
    public init(library: ShaderLibrary, name: String) { self.library = library; self.name = name }
    public func dynamicallyCall(withArguments args: [Shader.Argument]) -> Shader { Shader(function: self, arguments: args) }
}

/// A shader function with the values of its arguments after the position (and the color or layer).
@available(iOS 17.0, *)
public struct Shader: Equatable, @unchecked Sendable {
    public struct Argument: Equatable, @unchecked Sendable {
        enum Value {
            case floats([Float]), floatArray([Float]), color(Color), colorArray([Color]), image(Image), data(Data), boundingRect
        }
        let value: Value
        public static func float<T: BinaryFloatingPoint>(_ x: T) -> Argument { Argument(value: .floats([Float(x)])) }
        public static func float2<T: BinaryFloatingPoint>(_ x: T, _ y: T) -> Argument { Argument(value: .floats([Float(x), Float(y)])) }
        public static func float2(_ point: CGPoint) -> Argument { float2(point.x, point.y) }
        public static func float2(_ size: CGSize) -> Argument { float2(size.width, size.height) }
        public static func float2(_ vector: CGVector) -> Argument { float2(vector.dx, vector.dy) }
        public static func float3<T: BinaryFloatingPoint>(_ x: T, _ y: T, _ z: T) -> Argument { Argument(value: .floats([Float(x), Float(y), Float(z)])) }
        public static func float4<T: BinaryFloatingPoint>(_ x: T, _ y: T, _ z: T, _ w: T) -> Argument {
            Argument(value: .floats([Float(x), Float(y), Float(z), Float(w)]))
        }
        public static func floatArray(_ array: [Float]) -> Argument { Argument(value: .floatArray(array)) }
        public static func color(_ color: Color) -> Argument { Argument(value: .color(color)) }
        public static func colorArray(_ array: [Color]) -> Argument { Argument(value: .colorArray(array)) }
        public static func image(_ image: Image) -> Argument { Argument(value: .image(image)) }
        public static func data(_ data: Data) -> Argument { Argument(value: .data(data)) }
        /// the view's bounds as float4(x, y, width, height)
        public static var boundingRect: Argument { Argument(value: .boundingRect) }
        public static func == (a: Argument, b: Argument) -> Bool {
            switch (a.value, b.value) {
            case let (.floats(x), .floats(y)), let (.floatArray(x), .floatArray(y)): return x == y
            case let (.color(x), .color(y)): return x == y
            case let (.colorArray(x), .colorArray(y)): return x == y
            case let (.data(x), .data(y)): return x == y
            case (.boundingRect, .boundingRect): return true
            default: return false
            }
        }
    }
    public var function: ShaderFunction
    public var arguments: [Argument]
    /// adapted: colors are written as computed (8 bits per component), without dithering
    public var dithersColor = false
    public init(function: ShaderFunction, arguments: [Argument]) { self.function = function; self.arguments = arguments }
    public static func == (a: Shader, b: Shader) -> Bool {
        a.function == b.function && a.arguments == b.arguments && a.dithersColor == b.dithersColor
    }
}

/// Loaded libraries (dlopen handles), by source
@MainActor enum _ShaderLibraries {
    static var handles: [String: UnsafeMutableRawPointer] = [:]
    static var failed: Set<String> = []

    static func key(_ s: ShaderLibrary.Source) -> String {
        switch s {
        case .bundle(let b): return "bundle:" + b.bundlePath
        case .url(let u): return "url:" + u.path
        case .data(let d): return "data:\(d.hashValue):\(d.count)"
        }
    }
    /// the stitchable entry of a function, nil (logged once) if the library or the function is missing
    static func entry(_ f: ShaderFunction) -> (@convention(c) (UnsafeMutablePointer<__isim_mtl_stitch>?) -> Void)? {
        guard let h = handle(f.library.source),
              let table = dlsym(h, "__isim_mtl_functions")?.assumingMemoryBound(to: __isim_mtl_function.self) else { return nil }
        var p = table
        while let name = p.pointee.name {
            if String(cString: name) == f.name {
                if p.pointee.stitch == nil { warn("\(f.name) is not a [[stitchable]] function") }
                return p.pointee.stitch
            }
            p += 1
        }
        warn("no shader function named \(f.name)")
        return nil
    }
    static var warned: Set<String> = []
    static func warn(_ s: String) { if warned.insert(s).inserted { NSLog("isim SwiftUI: shader: %@", s) } }

    static func handle(_ s: ShaderLibrary.Source) -> UnsafeMutableRawPointer? {
        let k = key(s)
        if let h = handles[k] { return h }
        if failed.contains(k) { return nil }
        var path: String?
        switch s {
        case .bundle(let b):
            if let lib = b.path(forResource: "default", ofType: "metallib") { path = dylib(at: lib) } else { warn("the bundle has no default.metallib") }
        case .url(let u): path = dylib(at: u.path)
        case .data(let d): path = compile(d)
        }
        guard let p = path, let h = dlopen(p, RTLD_NOW | RTLD_LOCAL) else {
            if path != nil { warn("cannot load \(path!): \(String(cString: dlerror()))") }
            failed.insert(k)
            return nil
        }
        handles[k] = h
        return h
    }
    /// isim build's compiled library next to a metallib, else the metallib's sources compiled now
    static func dylib(at metallib: String) -> String? {
        if FileManager.default.fileExists(atPath: metallib + ".dylib") { return metallib + ".dylib" }
        guard let d = FileManager.default.contents(atPath: metallib) else { warn("cannot read \(metallib)"); return nil }
        return compile(d)
    }
    /// isim's metallib ("ISIMMETALLIB 1" + Metal sources) compiled with isim's Metal compiler into Caches
    static func compile(_ data: Data) -> String? {
        guard data.starts(with: Array("ISIMMETALLIB".utf8)), var text = String(data: data, encoding: .utf8) else {
            warn("not a metallib built by isim (Apple GPU code cannot run on isim)")
            return nil
        }
        if let nl = text.firstIndex(of: "\n") { text = String(text[text.index(after: nl)...]) }
        var h: UInt64 = 0xcbf29ce484222325
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        let caches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        let dir = (caches as NSString).appendingPathComponent("isim-metal")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let base = (dir as NSString).appendingPathComponent(String(format: "%016llx", h))
        if FileManager.default.fileExists(atPath: base + ".dylib") { return base + ".dylib" }
        try? text.write(toFile: base + ".metal", atomically: true, encoding: .utf8)
        var err = [CChar](repeating: 0, count: 8192)
        let tmp = base + ".\(getpid()).dylib"
        guard isim_metal_compile(base + ".metal", tmp, nil, 0, &err, err.count) == 0 else {
            warn("the Metal library did not compile: \(String(cString: err))")
            return nil
        }
        rename(tmp, base + ".dylib")
        return base + ".dylib"
    }
}

// MARK: - running a shader over pixels

/// One effect's shader with its resolved arguments; the context of the view's pixel shader (isim_gfx_pop_group_shaded).
final class _ShaderRun {
    let effect: UInt32
    let entry: @convention(c) (UnsafeMutablePointer<__isim_mtl_stitch>?) -> Void
    var size: CGSize = .zero
    var args: [__isim_mtl_shader_arg] = []
    /// storage the arguments point into (arrays, data, image pixels and their texture descriptions)
    var storage: [AnyObject] = []
    var boundingRectIndexes: [Int] = []

    final class Bytes { var p: UnsafeMutableRawPointer; init(_ n: Int) { p = .allocate(byteCount: max(n, 1), alignment: 16) }; deinit { p.deallocate() } }
    final class Texture { var desc = __isim_mtl_texture(); var pixels: Bytes; init(_ n: Int) { pixels = Bytes(n) } }

    init(effect: UInt32, entry: @escaping @convention(c) (UnsafeMutablePointer<__isim_mtl_stitch>?) -> Void, arguments: [Shader.Argument],
         env: EnvironmentValues) {
        self.effect = effect
        self.entry = entry
        for (i, a) in arguments.enumerated() {
            var arg = __isim_mtl_shader_arg()
            switch a.value {
            case .floats(let f):
                arg.kind = 0; arg.count = UInt32(f.count)
                withUnsafeMutableBytes(of: &arg.v) { b in for (k, x) in f.prefix(4).enumerated() { b.storeBytes(of: x, toByteOffset: 4 * k, as: Float.self) } }
            case .boundingRect:
                arg.kind = 0; arg.count = 4; boundingRectIndexes.append(i)
            case .color(let c):
                let p = Self.premultiplied(c, env)
                arg.kind = 0; arg.count = 4; arg.v = (p[0], p[1], p[2], p[3])
            case .floatArray(let f):
                let b = Bytes(4 * f.count)
                f.withUnsafeBytes { b.p.copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
                storage.append(b); arg.kind = 1; arg.count = UInt32(f.count); arg.ptr = UnsafeRawPointer(b.p)
            case .colorArray(let cs):
                let b = Bytes(8 * cs.count)
                for (k, c) in cs.enumerated() {
                    let p = Self.premultiplied(c, env)
                    for j in 0..<4 { b.p.storeBytes(of: Float16(p[j]), toByteOffset: 8 * k + 2 * j, as: Float16.self) }
                }
                storage.append(b); arg.kind = 1; arg.count = UInt32(cs.count); arg.ptr = UnsafeRawPointer(b.p)
            case .data(let d):
                let b = Bytes(d.count)
                d.withUnsafeBytes { if let base = $0.baseAddress { b.p.copyMemory(from: base, byteCount: d.count) } }
                storage.append(b); arg.kind = 1; arg.count = UInt32(d.count); arg.ptr = UnsafeRawPointer(b.p)
            case .image(let image):
                arg.kind = 2
                if let t = MainActor.assumeIsolated({ Self.texture(image, env) }) {
                    storage.append(t)
                    arg.tex = withUnsafePointer(to: &t.desc) { $0 }
                }
            }
            args.append(arg)
        }
    }

    static func premultiplied(_ c: Color, _ env: EnvironmentValues) -> [Float] {
        let v = MainActor.assumeIsolated { _rgba(c, env) }
        return [Float(v[0] * v[3]), Float(v[1] * v[3]), Float(v[2] * v[3]), Float(v[3])]
    }

    /// an Image's pixels as an RGBA8Unorm texture (texture2d<half> in the shader)
    @MainActor static func texture(_ image: Image, _ env: EnvironmentValues) -> Texture? {
        guard let cg = _uiImage(image, env)?.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let t = Texture(w * h * 4)
        guard let ctx = CGContext(data: t.pixels.p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        t.desc.type = 2; t.desc.format = 70
        t.desc.width = UInt32(w); t.desc.height = UInt32(h); t.desc.depth = 1; t.desc.array_length = 1; t.desc.mip_levels = 1
        t.desc.levels.0 = t.pixels.p.assumingMemoryBound(to: UInt8.self)
        t.desc.level_bpr.0 = UInt32(w * 4); t.desc.level_bpi.0 = UInt32(w * h * 4)
        return t
    }

    /// premultiplied ARGB -> RGBA in 0...1
    @inline(__always) static func unpack(_ v: UInt32) -> (Float, Float, Float, Float) {
        (Float((v >> 16) & 255) / 255, Float((v >> 8) & 255) / 255, Float(v & 255) / 255, Float(v >> 24) / 255)
    }
    @inline(__always) static func pack(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> UInt32 {
        func c(_ x: Float, _ hi: Float) -> UInt32 { UInt32((min(max(x.isNaN ? 0 : x, 0), hi) * 255).rounded()) }
        let A = min(max(a.isNaN ? 0 : a, 0), 1)
        return c(A, 1) << 24 | c(r, A) << 16 | c(g, A) << 8 | c(b, A)
    }
    /// bilinear sample of a copy of the pixels at a position in the view's coordinates
    @inline(__always) static func sample(_ src: UnsafePointer<UInt32>, _ w: Int, _ h: Int, _ stride: Int, _ x: Float, _ y: Float) -> UInt32 {
        let fx = x - 0.5, fy = y - 0.5
        let x0 = Int(fx.rounded(.down)), y0 = Int(fy.rounded(.down))
        let tx = fx - Float(x0), ty = fy - Float(y0)
        func at(_ xx: Int, _ yy: Int) -> (Float, Float, Float, Float) {
            xx < 0 || yy < 0 || xx >= w || yy >= h ? (0, 0, 0, 0) : unpack(src[yy * stride + xx])
        }
        let a = at(x0, y0), b = at(x0 + 1, y0), c = at(x0, y0 + 1), d = at(x0 + 1, y0 + 1)
        func mix(_ p: Float, _ q: Float, _ r: Float, _ s: Float) -> Float { (p * (1 - tx) + q * tx) * (1 - ty) + (r * (1 - tx) + s * tx) * ty }
        return pack(mix(a.0, b.0, c.0, d.0), mix(a.1, b.1, c.1, d.1), mix(a.2, b.2, c.2, d.2), mix(a.3, b.3, c.3, d.3))
    }

    /// runs the shader over the pixels of the view's bounds (the region given extends margin points beyond them)
    func shade(_ px: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ stride: Int, _ x0: Double, _ y0: Double, _ scale: Double) {
        for i in boundingRectIndexes { args[i].v = (0, 0, Float(size.width), Float(size.height)) }
        let s = Float(scale)
        // the view's bounds in region pixels
        let bx0 = max(0, Int(((0 - x0) * scale).rounded(.down))), by0 = max(0, Int(((0 - y0) * scale).rounded(.down)))
        let bx1 = min(w, Int(((Double(size.width) - x0) * scale).rounded(.up))), by1 = min(h, Int(((Double(size.height) - y0) * scale).rounded(.up)))
        guard bx1 > bx0, by1 > by0 else { return }
        var copy: UnsafeMutablePointer<UInt32>?
        if effect != UInt32(ISIM_MTL_EFFECT_COLOR) {
            copy = .allocate(capacity: stride * h)
            copy!.update(from: px, count: stride * h)
        }
        defer { copy?.deallocate() }
        var layer = __isim_mtl_layer(px: copy.map { UnsafePointer($0) }, width: Int32(w), height: Int32(h), stride: Int32(stride),
                                     x0: Float(x0), y0: Float(y0), scale: s)
        args.withUnsafeBufferPointer { argp in
            withUnsafePointer(to: &layer) { lp in
                var st = __isim_mtl_stitch()
                st.effect = effect
                st.layer = lp
                st.args = argp.baseAddress
                st.nargs = UInt32(argp.count)
                for y in by0..<by1 {
                    let row = px + y * stride
                    st.position.1 = Float(y0) + (Float(y) + 0.5) / s
                    for x in bx0..<bx1 {
                        st.position.0 = Float(x0) + (Float(x) + 0.5) / s
                        if effect == UInt32(ISIM_MTL_EFFECT_COLOR) {
                            let c = Self.unpack(row[x])
                            st.color = (c.0, c.1, c.2, c.3)
                        }
                        entry(&st)
                        let r = st.result
                        if effect == UInt32(ISIM_MTL_EFFECT_DISTORTION) {
                            row[x] = Self.sample(UnsafePointer(copy!), w, h, stride, (r.0 - Float(x0)) * s, (r.1 - Float(y0)) * s)
                        } else {
                            row[x] = Self.pack(r.0, r.1, r.2, r.3)
                        }
                    }
                }
            }
        }
    }
}

/// the view's pixel shader: the context is the effect's _ShaderRun
private let _shadePixels: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt32>, Int32, Int32, Int32, Double, Double, Double) -> Void = {
    ctx, px, w, h, stride, x0, y0, scale in
    guard let ctx else { return }
    Unmanaged<_ShaderRun>.fromOpaque(ctx).takeUnretainedValue().shade(px, Int(w), Int(h), Int(stride), x0, y0, scale)
}

// MARK: - the modifiers

struct _ShaderEffectView<Content: View>: View, _PrimitiveView {
    let effect: UInt32
    let shader: Shader
    let maxSampleOffset: CGSize
    let isEnabled: Bool
    let content: Content
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _ShaderEffectNode(path: ctx.path, effect: effect, shader: shader, margin: max(maxSampleOffset.width, maxSampleOffset.height),
                          enabled: isEnabled, env: ctx.environment, child: _resolve(content, ctx.child("shader")))
    }
}
final class _ShaderEffectNode: _WrapperNode {
    let run: _ShaderRun?
    let margin: CGFloat
    init(path: String, effect: UInt32, shader: Shader, margin: CGFloat, enabled: Bool, env: EnvironmentValues, child: _Node) {
        self.margin = margin
        if #available(iOS 17.0, *), enabled, let e = MainActor.assumeIsolated({ _ShaderLibraries.entry(shader.function) }) {
            run = _ShaderRun(effect: effect, entry: e, arguments: shader.arguments, env: env)
        } else {
            run = nil
        }
        super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; run?.size = rect.size; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        if let run { v._isim_setPixelShader(_shadePixels, context: run, margin: margin) } else { v._isim_setPixelShader(nil, context: nil, margin: 0) }
        return v
    }
}

@available(iOS 17.0, *)
extension View {
    /// Runs a [[stitchable]] function `half4 name(float2 position, half4 color, args...)` on every pixel of the view.
    public func colorEffect(_ shader: Shader, isEnabled: Bool = true) -> some View {
        _ShaderEffectView(effect: UInt32(ISIM_MTL_EFFECT_COLOR), shader: shader, maxSampleOffset: .zero, isEnabled: isEnabled, content: self)
    }
    /// Runs `half4 name(float2 position, SwiftUI::Layer layer, args...)`, which samples the view's rendered layer.
    public func layerEffect(_ shader: Shader, maxSampleOffset: CGSize, isEnabled: Bool = true) -> some View {
        _ShaderEffectView(effect: UInt32(ISIM_MTL_EFFECT_LAYER), shader: shader, maxSampleOffset: maxSampleOffset, isEnabled: isEnabled, content: self)
    }
    /// Runs `float2 name(float2 position, args...)`: each pixel shows the view at the position the function returns.
    public func distortionEffect(_ shader: Shader, maxSampleOffset: CGSize, isEnabled: Bool = true) -> some View {
        _ShaderEffectView(effect: UInt32(ISIM_MTL_EFFECT_DISTORTION), shader: shader, maxSampleOffset: maxSampleOffset, isEnabled: isEnabled, content: self)
    }
}
