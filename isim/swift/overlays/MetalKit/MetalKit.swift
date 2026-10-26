// isim MetalKit (issue #329): MTKView, a view that draws with Metal at the display's rate (or on setNeedsDisplay) into
// its CAMetalLayer's drawables, and MTKTextureLoader, which makes textures from images. Adapted: the rendering runs on
// the CPU (isim's Metal). The Objective-C classes are these (sdk-src/Frameworks/MetalKit). Not in isim: MTKMesh and the
// Model I/O bridges.
import Foundation
import UIKit
@_exported import Metal
import QuartzCore

// MARK: - MTKView

@objc(MTKViewDelegate) public protocol MTKViewDelegate: NSObjectProtocol {
    /// the drawable's size changed (the view was resized or rotated)
    @objc(mtkView:drawableSizeWillChange:) func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    /// draw a frame into the view's current drawable
    @objc(drawInMTKView:) func draw(in view: MTKView)
}

@objc(MTKView) open class MTKView: UIView {
    open override class var layerClass: AnyClass { CAMetalLayer.self }
    var _metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    @objc(initWithFrame:device:) public init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame)
        _setUp()
        self.device = device
    }
    public override init(frame: CGRect) { super.init(frame: frame); _setUp() }
    public required init(coder: NSCoder) { super.init(coder: coder)!; _setUp() }

    @objc open weak var delegate: MTKViewDelegate?
    @objc open var device: MTLDevice? {
        get { _metalLayer.device }
        set { _metalLayer.device = newValue; _releaseTextures() }
    }
    @objc open var preferredDevice: MTLDevice? { MTLCreateSystemDefaultDevice() }
    @objc open var colorPixelFormat: MTLPixelFormat {
        get { _metalLayer.pixelFormat }
        set { _metalLayer.pixelFormat = newValue; _releaseTextures() }
    }
    @objc open var framebufferOnly: Bool {
        get { _metalLayer.framebufferOnly }
        set { _metalLayer.framebufferOnly = newValue }
    }
    @objc open var presentsWithTransaction: Bool {
        get { _metalLayer.presentsWithTransaction }
        set { _metalLayer.presentsWithTransaction = newValue }
    }
    @objc open var colorspace: CGColorSpace? {
        get { _metalLayer.colorspace }
        set { _metalLayer.colorspace = newValue }
    }
    @objc open var depthStencilPixelFormat: MTLPixelFormat = .invalid { didSet { _releaseTextures() } }
    @objc open var depthStencilAttachmentTextureUsage: MTLTextureUsage = .renderTarget
    @objc open var multisampleColorAttachmentTextureUsage: MTLTextureUsage = .renderTarget
    @objc open var depthStencilStorageMode: MTLStorageMode = .private
    /// adapted: multisampled attachments hold one sample per pixel on isim (not antialiased)
    @objc open var sampleCount: Int = 1 { didSet { _releaseTextures() } }
    @objc open var clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    @objc open var clearDepth: Double = 1
    @objc open var clearStencil: UInt32 = 0
    @objc open private(set) var depthStencilTexture: MTLTexture?
    @objc open private(set) var multisampleColorTexture: MTLTexture?
    @objc open var preferredFramesPerSecond: Int = 60 { didSet { _link?.preferredFramesPerSecond = preferredFramesPerSecond } }
    @objc open var enableSetNeedsDisplay = false
    @objc open var autoResizeDrawable = true
    @objc open var drawableSize: CGSize {
        get { _metalLayer.drawableSize }
        set {
            let old = _metalLayer.drawableSize
            _metalLayer.drawableSize = newValue
            if old != newValue { _releaseTextures(); delegate?.mtkView(self, drawableSizeWillChange: newValue) }
        }
    }
    @objc open var preferredDrawableSize: CGSize { CGSize(width: bounds.width * contentScaleFactor, height: bounds.height * contentScaleFactor) }
    @objc open var isPaused: Bool {
        get { _paused }
        set { _paused = newValue }
    }
    /// Objective-C's setter (the property is `paused`, getter isPaused)
    @objc(setPaused:) func _objc_setPaused(_ v: Bool) { _paused = v }
    var _paused = false
    var _needsDraw = false
    var _drawable: CAMetalDrawable?
    var _pass: MTLRenderPassDescriptor?
    var _link: CADisplayLink?
    let _ticker = _Ticker()

    /// the drawable to render the current frame into (nil when the view has no size or device)
    /// isim's view rendering leaves draw(_:) to the frame loop (UIView _isim_skipsDrawRect)
    @objc func _isim_skipsDrawRect() -> Bool { true }
    @objc open var currentDrawable: CAMetalDrawable? {
        if _drawable == nil { _drawable = _metalLayer.nextDrawable() }
        return _drawable
    }
    /// a render pass that clears the current drawable (and the depth / stencil and multisample textures)
    @objc open var currentRenderPassDescriptor: MTLRenderPassDescriptor? {
        if let p = _pass { return p }
        guard let drawable = currentDrawable, let device = device else { return nil }
        let tex = drawable.texture
        let p = MTLRenderPassDescriptor()
        let color = p.colorAttachments[0]!
        color.clearColor = clearColor
        color.loadAction = .clear
        if sampleCount > 1 {
            if multisampleColorTexture == nil || multisampleColorTexture!.width != tex.width || multisampleColorTexture!.height != tex.height {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorPixelFormat, width: tex.width, height: tex.height, mipmapped: false)
                d.textureType = .type2DMultisample; d.sampleCount = sampleCount; d.usage = multisampleColorAttachmentTextureUsage
                multisampleColorTexture = device.makeTexture(descriptor: d)
            }
            color.texture = multisampleColorTexture
            color.resolveTexture = tex
            color.storeAction = .multisampleResolve
        } else {
            color.texture = tex
            color.storeAction = .store
        }
        if depthStencilPixelFormat != .invalid {
            if depthStencilTexture == nil || depthStencilTexture!.width != tex.width || depthStencilTexture!.height != tex.height {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depthStencilPixelFormat, width: tex.width, height: tex.height, mipmapped: false)
                d.usage = depthStencilAttachmentTextureUsage; d.storageMode = depthStencilStorageMode
                if sampleCount > 1 { d.textureType = .type2DMultisample; d.sampleCount = sampleCount }
                depthStencilTexture = device.makeTexture(descriptor: d)
            }
            let f = depthStencilPixelFormat
            if f != .stencil8 {
                p.depthAttachment.texture = depthStencilTexture
                p.depthAttachment.clearDepth = clearDepth
                p.depthAttachment.loadAction = .clear
                p.depthAttachment.storeAction = .dontCare
            }
            if f == .stencil8 || f == .depth32Float_stencil8 || f == .x32_stencil8 {
                p.stencilAttachment.texture = depthStencilTexture
                p.stencilAttachment.clearStencil = clearStencil
                p.stencilAttachment.loadAction = .clear
                p.stencilAttachment.storeAction = .dontCare
            }
        }
        _pass = p
        return p
    }

    @objc open func releaseDrawables() { _drawable = nil; _pass = nil; _releaseTextures() }
    func _releaseTextures() { depthStencilTexture = nil; multisampleColorTexture = nil; _pass = nil }

    /// draws one frame: the delegate's draw(in:), else draw(_:) of a subclass
    @objc open func draw() {
        autoreleasepool {
            _sizeDrawable()
            if let delegate = delegate { delegate.draw(in: self) } else { draw(bounds) }
            _drawable = nil
            _pass = nil
        }
    }
    open override func setNeedsDisplay() {
        super.setNeedsDisplay()
        if enableSetNeedsDisplay { _needsDraw = true }
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        _sizeDrawable()
    }
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { _sizeDrawable(); _needsDraw = true }
    }
    func _sizeDrawable() {
        guard autoResizeDrawable else { return }
        let s = preferredDrawableSize
        if s.width > 0, s.height > 0, s != drawableSize { drawableSize = s }
    }
    func _setUp() {
        _metalLayer.drawableSize = .zero
        _ticker.view = self
        let link = CADisplayLink(_isimWeakTarget: _ticker, selector: #selector(_Ticker.tick))
        link.preferredFramesPerSecond = preferredFramesPerSecond
        link.add(to: .main, forMode: .common)
        _link = link
    }
    func _tick() {
        guard window != nil, !_paused else { return }
        if enableSetNeedsDisplay {
            guard _needsDraw else { return }
            _needsDraw = false
        }
        draw()
    }
    deinit { _link?.invalidate() }
    final class _Ticker: NSObject {
        weak var view: MTKView?
        @objc func tick() {
            if let v = view { v._tick() } else { /* the view is gone: nothing to draw */ }
        }
    }
}

// MARK: - MTKTextureLoader

public let MTKTextureLoaderErrorDomain = "MTKTextureLoaderErrorDomain"
public let MTKTextureLoaderErrorKey = "MTKTextureLoaderErrorKey"

@objc(MTKTextureLoader) open class MTKTextureLoader: NSObject {
    public struct Option: Hashable, RawRepresentable, @unchecked Sendable {
        public var rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        /// Bool: the image's data is sRGB-encoded (default: true, the images isim loads are sRGB)
        public static let SRGB = Option("MTKTextureLoaderOptionSRGB")
        /// Bool: allocate and fill the texture's mipmap levels
        public static let generateMipmaps = Option("MTKTextureLoaderOptionGenerateMipmaps")
        /// Bool: allocate the mipmap levels without filling them
        public static let allocateMipmaps = Option("MTKTextureLoaderOptionAllocateMipmaps")
        public static let textureUsage = Option("MTKTextureLoaderOptionTextureUsage")
        public static let textureCPUCacheMode = Option("MTKTextureLoaderOptionTextureCPUCacheMode")
        public static let textureStorageMode = Option("MTKTextureLoaderOptionTextureStorageMode")
        /// Origin: where the image's first row goes
        public static let origin = Option("MTKTextureLoaderOptionOrigin")
        public static let cubeLayout = Option("MTKTextureLoaderOptionCubeLayout")
        public static let loadAsArray = Option("MTKTextureLoaderOptionLoadAsArray")
        public static let lodBias = Option("MTKTextureLoaderOptionLODBias")
    }
    public struct Origin: Hashable, RawRepresentable, @unchecked Sendable {
        public var rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let topLeft = Origin(rawValue: "MTKTextureLoaderOriginTopLeft")
        public static let bottomLeft = Origin(rawValue: "MTKTextureLoaderOriginBottomLeft")
        public static let flippedVertically = Origin(rawValue: "MTKTextureLoaderOriginFlippedVertically")
    }
    public struct CubeLayout: Hashable, RawRepresentable, @unchecked Sendable {
        public var rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let vertical = CubeLayout(rawValue: "MTKTextureLoaderCubeLayoutVertical")
    }
    public typealias Callback = (MTLTexture?, Error?) -> Void
    public typealias ArrayCallback = ([MTLTexture], Error?) -> Void

    @objc public let device: MTLDevice
    @objc(initWithDevice:) public init(device: MTLDevice) { self.device = device }

    // the Swift forms
    open func newTexture(URL url: URL, options: [Option: Any]? = nil) throws -> MTLTexture {
        guard let data = try? Data(contentsOf: url) else { throw Self._error("The file \(url.lastPathComponent) could not be read") }
        return try newTexture(data: data, options: options)
    }
    open func newTexture(data: Data, options: [Option: Any]? = nil) throws -> MTLTexture {
        guard let image = UIImage(data: data)?.cgImage else { throw Self._error("The data is not an image isim can read (KTX and PVR are not supported)") }
        return try newTexture(cgImage: image, options: options)
    }
    open func newTexture(name: String, scaleFactor: CGFloat, bundle: Bundle?, options: [Option: Any]? = nil) throws -> MTLTexture {
        guard let image = UIImage(named: name, in: bundle ?? .main, with: nil)?.cgImage else {
            throw Self._error("No image named \(name) was found in the bundle")
        }
        return try newTexture(cgImage: image, options: options)
    }
    open func newTexture(name: String, scaleFactor: CGFloat, displayGamut: UIDisplayGamut, bundle: Bundle?, options: [Option: Any]? = nil) throws -> MTLTexture {
        try newTexture(name: name, scaleFactor: scaleFactor, bundle: bundle, options: options)
    }
    open func newTexture(cgImage: CGImage, options: [Option: Any]? = nil) throws -> MTLTexture {
        let o = options ?? [:]
        let srgb = (o[.SRGB] as? Bool) ?? (o[.SRGB] as? NSNumber)?.boolValue ?? true
        let mips = ((o[.generateMipmaps] as? Bool) ?? false) || ((o[.allocateMipmaps] as? Bool) ?? false)
        let fill = (o[.generateMipmaps] as? Bool) ?? false
        let origin = (o[.origin] as? Origin)?.rawValue ?? (o[.origin] as? String) ?? Origin.topLeft.rawValue
        let w = cgImage.width, h = cgImage.height
        guard w > 0, h > 0 else { throw Self._error("The image is empty") }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Self._error("The image could not be decoded") }
        if origin != Origin.topLeft.rawValue {   /* bottom-left: the first row of the texture is the image's last */
            ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: px.count, by: 4) where px[i + 3] != 0 && px[i + 3] != 255 {   /* straight alpha, as decoded */
            let a = Int(px[i + 3])
            for k in 0..<3 { px[i + k] = UInt8(min(255, (Int(px[i + k]) * 255 + a / 2) / a)) }
        }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: srgb ? .rgba8Unorm_srgb : .rgba8Unorm, width: w, height: h, mipmapped: mips)
        if let u = o[.textureUsage] as? NSNumber { d.usage = MTLTextureUsage(rawValue: u.uintValue) } else if let u = o[.textureUsage] as? UInt { d.usage = MTLTextureUsage(rawValue: u) }
        if let m = o[.textureStorageMode] as? NSNumber, let s = MTLStorageMode(rawValue: m.uintValue) { d.storageMode = s }
        guard let tex = device.makeTexture(descriptor: d) else { throw Self._error("The texture could not be made") }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: px, bytesPerRow: w * 4)
        if fill, tex.mipmapLevelCount > 1, let q = device.makeCommandQueue(), let cb = q.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: tex)
            blit.endEncoding()
            cb.commit()
            cb.waitUntilCompleted()
        }
        return tex
    }
    open func newTextures(URLs: [URL], options: [Option: Any]? = nil) throws -> [MTLTexture] {
        try URLs.map { try newTexture(URL: $0, options: options) }
    }

    // asynchronous forms
    open func newTexture(URL url: URL, options: [Option: Any]? = nil, completionHandler: @escaping Callback) {
        _async(completionHandler) { try self.newTexture(URL: url, options: options) }
    }
    open func newTexture(data: Data, options: [Option: Any]? = nil, completionHandler: @escaping Callback) {
        _async(completionHandler) { try self.newTexture(data: data, options: options) }
    }
    open func newTexture(cgImage: CGImage, options: [Option: Any]? = nil, completionHandler: @escaping Callback) {
        _async(completionHandler) { try self.newTexture(cgImage: cgImage, options: options) }
    }
    open func newTexture(name: String, scaleFactor: CGFloat, bundle: Bundle?, options: [Option: Any]? = nil, completionHandler: @escaping Callback) {
        _async(completionHandler) { try self.newTexture(name: name, scaleFactor: scaleFactor, bundle: bundle, options: options) }
    }
    open func newTexture(URL url: URL, options: [Option: Any]? = nil) async throws -> MTLTexture {
        try await withCheckedThrowingContinuation { c in newTexture(URL: url, options: options) { t, e in t.map { c.resume(returning: $0) } ?? c.resume(throwing: e!) } }
    }
    open func newTexture(cgImage: CGImage, options: [Option: Any]? = nil) async throws -> MTLTexture {
        try await withCheckedThrowingContinuation { c in newTexture(cgImage: cgImage, options: options) { t, e in t.map { c.resume(returning: $0) } ?? c.resume(throwing: e!) } }
    }
    func _async(_ done: @escaping Callback, _ work: @escaping () throws -> MTLTexture) {
        let box = _Box(work, done)
        DispatchQueue.global().async {
            do { box.done(try box.work(), nil) } catch { box.done(nil, error) }
        }
    }
    final class _Box: @unchecked Sendable {
        let work: () throws -> MTLTexture
        let done: Callback
        init(_ w: @escaping () throws -> MTLTexture, _ d: @escaping Callback) { work = w; done = d }
    }
    static func _error(_ message: String) -> NSError {
        NSError(domain: MTKTextureLoaderErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: message, MTKTextureLoaderErrorKey: message])
    }

    // the Objective-C forms (options keyed by the MTKTextureLoaderOption strings)
    static func _options(_ o: [String: Any]?) -> [Option: Any]? {
        guard let o else { return nil }
        var r: [Option: Any] = [:]
        for (k, v) in o { r[Option(k)] = k == Option.origin.rawValue ? ((v as? String).map { Origin(rawValue: $0) } ?? v) : v }
        return r
    }
    @objc(newTextureWithContentsOfURL:options:error:) open func _objc_url(_ url: URL, options: [String: Any]?) throws -> MTLTexture {
        try newTexture(URL: url, options: Self._options(options))
    }
    @objc(newTextureWithData:options:error:) open func _objc_data(_ data: Data, options: [String: Any]?) throws -> MTLTexture {
        try newTexture(data: data, options: Self._options(options))
    }
    @objc(newTextureWithCGImage:options:error:) open func _objc_cgImage(_ image: CGImage, options: [String: Any]?) throws -> MTLTexture {
        try newTexture(cgImage: image, options: Self._options(options))
    }
    @objc(newTextureWithName:scaleFactor:bundle:options:error:) open func _objc_name(_ name: String, scaleFactor: CGFloat, bundle: Bundle?, options: [String: Any]?) throws -> MTLTexture {
        try newTexture(name: name, scaleFactor: scaleFactor, bundle: bundle, options: Self._options(options))
    }
    @objc(newTextureWithContentsOfURL:options:completionHandler:) open func _objc_url(_ url: URL, options: [String: Any]?, completionHandler: @escaping Callback) {
        newTexture(URL: url, options: Self._options(options), completionHandler: completionHandler)
    }
    @objc(newTextureWithCGImage:options:completionHandler:) open func _objc_cgImage(_ image: CGImage, options: [String: Any]?, completionHandler: @escaping Callback) {
        newTexture(cgImage: image, options: Self._options(options), completionHandler: completionHandler)
    }
}
