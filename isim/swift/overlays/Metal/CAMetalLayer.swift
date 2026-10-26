// isim QuartzCore: CAMetalLayer, its drawables and CAMetalDisplayLink (issue #329). Adapted: a drawable's texture is
// rendered on the CPU by isim's Metal; presenting it copies the pixels into the layer's contents (a CGImage), which
// isim's compositor draws like any layer. They live in the Metal overlay, which `import UIKit` + `import Metal` and
// `import QuartzCore` (which re-exports Metal, as Apple's does) both reach, because isim's Core Animation is UIKit's;
// QuartzCore.framework re-exports them for Objective-C (sdk-src/Frameworks/QuartzCore/CAMetal*.h).
import Foundation
import UIKit

/// A drawable of a CAMetalLayer: its texture, shown in the layer when presented
@objc(CAMetalDrawable) public protocol CAMetalDrawable: MTLDrawable {
    var texture: MTLTexture { get }
    var layer: CAMetalLayer { get }
}

/// A layer whose contents are rendered with Metal
@objc(CAMetalLayer) open class CAMetalLayer: CALayer {
    public override init() { super.init(); isOpaque = true }
    public override init(layer: Any) {
        super.init(layer: layer)
        if let l = layer as? CAMetalLayer {
            device = l.device; pixelFormat = l.pixelFormat; framebufferOnly = l.framebufferOnly; drawableSize = l.drawableSize
        }
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    @objc open var device: MTLDevice?
    @objc open var preferredDevice: MTLDevice? { MTLCreateSystemDefaultDevice() }
    /// bgra8Unorm (the default), its sRGB form, rgba8Unorm, rgba16Float or bgr10a2Unorm
    @objc open var pixelFormat: MTLPixelFormat = .bgra8Unorm
    @objc open var framebufferOnly = true
    /// the drawables' size in pixels; zero: the layer's bounds times its contentsScale
    @objc open var drawableSize: CGSize = .zero
    @objc open var maximumDrawableCount: Int = 3 { didSet { maximumDrawableCount = min(max(maximumDrawableCount, 2), 3) } }
    @objc open var presentsWithTransaction = false
    @objc open var colorspace: CGColorSpace?
    @objc open var allowsNextDrawableTimeout = true

    let _lock = NSCondition()
    var _inFlight = 0
    var _free: [MTLTexture] = []
    var _nextID = 0

    /// the next drawable to render into; nil when every drawable is in use for a second (allowsNextDrawableTimeout)
    @objc open func nextDrawable() -> CAMetalDrawable? {
        guard let device = device else { return nil }
        var size = drawableSize
        if size.width < 1 || size.height < 1 { size = CGSize(width: bounds.width * contentsScale, height: bounds.height * contentsScale) }
        let w = Int(size.width.rounded()), h = Int(size.height.rounded())
        guard w > 0, h > 0 else { return nil }
        _lock.lock()
        defer { _lock.unlock() }
        let limit = Date().addingTimeInterval(1)
        while _inFlight >= maximumDrawableCount {
            if !_lock.wait(until: limit) && allowsNextDrawableTimeout { return nil }
        }
        var texture: MTLTexture?
        while let t = _free.popLast() {
            if t.width == w && t.height == h && t.pixelFormat == pixelFormat { texture = t; break }
        }
        if texture == nil {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: w, height: h, mipmapped: false)
            d.usage = framebufferOnly ? .renderTarget : [.renderTarget, .shaderRead, .shaderWrite]
            d.storageMode = .shared
            texture = device.makeTexture(descriptor: d)
        }
        guard let tex = texture else { return nil }
        _inFlight += 1
        _nextID += 1
        return _CAMetalDrawable(layer: self, texture: tex, id: _nextID)
    }

    func _release(_ texture: MTLTexture) {
        _lock.lock()
        _inFlight -= 1
        if _free.count < maximumDrawableCount { _free.append(texture) }
        _lock.broadcast()
        _lock.unlock()
    }

    /// the texture's pixels as a CGImage (the formats a CAMetalLayer can have)
    func _image(_ t: MTLTexture) -> CGImage? {
        let w = t.width, h = t.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        switch t.pixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb, .rgba8Unorm, .rgba8Unorm_srgb:
            rgba.withUnsafeMutableBytes { t.getBytes($0.baseAddress!, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0) }
            if t.pixelFormat == .bgra8Unorm || t.pixelFormat == .bgra8Unorm_srgb {
                for i in stride(from: 0, to: rgba.count, by: 4) { rgba.swapAt(i, i + 2) }
            }
        case .rgba16Float:
            var half = [UInt16](repeating: 0, count: w * h * 4)
            half.withUnsafeMutableBytes { t.getBytes($0.baseAddress!, bytesPerRow: w * 8, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0) }
            for i in 0..<half.count {
                let v = Float(Float16(bitPattern: half[i]))
                rgba[i] = UInt8(max(0, min(1, v)) * 255 + 0.5)
            }
        case .bgr10a2Unorm, .rgb10a2Unorm:
            var words = [UInt32](repeating: 0, count: w * h)
            words.withUnsafeMutableBytes { t.getBytes($0.baseAddress!, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0) }
            let bgr = t.pixelFormat == .bgr10a2Unorm
            for i in 0..<words.count {
                let v = words[i]
                let a = UInt8((v >> 0 & 1023) >> 2), b = UInt8((v >> 10 & 1023) >> 2), c = UInt8((v >> 20 & 1023) >> 2)
                rgba[4 * i] = bgr ? c : a; rgba[4 * i + 1] = b; rgba[4 * i + 2] = bgr ? a : c; rgba[4 * i + 3] = UInt8((v >> 30) * 85)
            }
        default:
            return nil
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        let alpha: CGImageAlphaInfo = isOpaque ? .noneSkipLast : .premultipliedLast
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: alpha.rawValue), provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}

/// a CAMetalLayer's drawable: presenting it shows its texture in the layer, on the main thread
final class _CAMetalDrawable: NSObject, CAMetalDrawable, @unchecked Sendable {
    let _layer: CAMetalLayer
    let _texture: MTLTexture
    let _id: Int
    var _done = false
    var _presented: CFTimeInterval = 0
    var _handlers: [MTLDrawablePresentedHandler] = []
    let _lock = NSLock()
    init(layer: CAMetalLayer, texture: MTLTexture, id: Int) { _layer = layer; _texture = texture; _id = id }
    deinit { if !_done { _layer._release(_texture) } }
    var texture: MTLTexture { _texture }
    var layer: CAMetalLayer { _layer }
    var presentedTime: CFTimeInterval { _presented }
    var drawableID: Int { _id }
    func addPresentedHandler(_ block: @escaping MTLDrawablePresentedHandler) { _lock.lock(); _handlers.append(block); _lock.unlock() }
    func present() {
        _lock.lock()
        if _done { _lock.unlock(); return }
        _done = true
        _lock.unlock()
        let image = _layer._image(_texture)
        _layer._release(_texture)
        let show = {
            if let image { self._layer.contents = image }
            self._presented = CACurrentMediaTime()
            self._lock.lock(); let hs = self._handlers; self._handlers = []; self._lock.unlock()
            for h in hs { h(self) }
        }
        if Thread.isMainThread { show() } else { DispatchQueue.main.async(execute: show) }
    }
    func present(at presentationTime: CFTimeInterval) {
        let wait = presentationTime - CACurrentMediaTime()
        if wait > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + wait) { self.present() } } else { present() }
    }
    func present(afterMinimumDuration duration: CFTimeInterval) { present() }
}

/// A display link that hands out a CAMetalLayer's drawables at the display's rate (iOS 17)
@available(iOS 17.0, *)
@objc(CAMetalDisplayLink) open class CAMetalDisplayLink: NSObject {
    /// one frame to render: its drawable and when it will be shown
    @objc(CAMetalDisplayLinkUpdate) open class Update: NSObject {
        @objc open private(set) var drawable: CAMetalDrawable
        @objc open private(set) var targetTimestamp: CFTimeInterval
        @objc open private(set) var targetPresentationTimestamp: CFTimeInterval
        init(drawable: CAMetalDrawable, target: CFTimeInterval, presentation: CFTimeInterval) {
            self.drawable = drawable; targetTimestamp = target; targetPresentationTimestamp = presentation
        }
    }
    /// the display link's target (CADisplayLink retains its target)
    final class _Ticker: NSObject {
        weak var owner: CAMetalDisplayLink?
        @objc func tick(_ link: CADisplayLink) { owner?._tick(link) }
    }

    @objc open weak var delegate: CAMetalDisplayLinkDelegate?
    @objc open var preferredFrameLatency: Float = 2
    @objc open var preferredFrameRateRange: CAFrameRateRange = .default { didSet { _link.preferredFrameRateRange = preferredFrameRateRange } }
    @objc open var isPaused: Bool {
        get { _link.isPaused }
        set { _link.isPaused = newValue }
    }
    /// Objective-C's setter (the property is `paused`, getter isPaused)
    @objc(setPaused:) func _objc_setPaused(_ v: Bool) { _link.isPaused = v }
    let _layer: CAMetalLayer
    let _ticker = _Ticker()
    let _link: CADisplayLink

    @objc(initWithMetalLayer:) public init(metalLayer: CAMetalLayer) {
        _layer = metalLayer
        _link = CADisplayLink(target: _ticker, selector: #selector(_Ticker.tick(_:)))
        super.init()
        _ticker.owner = self
    }
    @objc(addToRunLoop:forMode:) open func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) { _link.add(to: runloop, forMode: mode) }
    @objc(removeFromRunLoop:forMode:) open func remove(from runloop: RunLoop, forMode mode: RunLoop.Mode) { _link.remove(from: runloop, forMode: mode) }
    @objc open func invalidate() { _link.invalidate() }

    func _tick(_ link: CADisplayLink) {
        guard let delegate, let drawable = _layer.nextDrawable() else { return }
        let target = link.targetTimestamp
        let presentation = target + Double(max(preferredFrameLatency - 1, 0)) * max(link.duration, 1.0 / 60)
        delegate.metalDisplayLink(self, needsUpdate: Update(drawable: drawable, target: target, presentation: presentation))
    }
}

@available(iOS 17.0, *)
@objc(CAMetalDisplayLinkDelegate) public protocol CAMetalDisplayLinkDelegate: AnyObject {
    func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update)
}
