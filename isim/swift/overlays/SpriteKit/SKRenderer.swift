// isim SpriteKit: SKRenderer, a scene drawn into an app's Metal render pass. isim's 2D renderer draws the frame
// offscreen (a hidden SKView), and a step queued on the command buffer, in order with the pass's own clear and draws,
// blends it over the color attachment (bgra8 / rgba8 textures, source-over).
import Foundation
import Metal
import isim_host

@objc(SKRenderer) open class SKRenderer: NSObject {
    let _view = SKView(frame: .zero)
    var _last: TimeInterval?
    @objc open var scene: SKScene? {
        didSet {
            guard scene !== oldValue else { return }
            _view.presentScene(scene)
            _last = nil
        }
    }
    @objc open var ignoresSiblingOrder: Bool { get { _view.ignoresSiblingOrder } set { _view.ignoresSiblingOrder = newValue } }
    @objc open var shouldCullNonVisibleNodes: Bool { get { _view.shouldCullNonVisibleNodes } set { _view.shouldCullNonVisibleNodes = newValue } }
    @objc open var showsDrawCount: Bool { get { _view.showsDrawCount } set { _view.showsDrawCount = newValue } }
    @objc open var showsNodeCount: Bool { get { _view.showsNodeCount } set { _view.showsNodeCount = newValue } }
    @objc open var showsQuadCount: Bool { get { _view.showsQuadCount } set { _view.showsQuadCount = newValue } }
    @objc open var showsPhysics: Bool { get { _view.showsPhysics } set { _view.showsPhysics = newValue } }
    @objc open var showsFields: Bool { get { _view.showsFields } set { _view.showsFields = newValue } }

    @objc public init(device: any MTLDevice) {
        super.init()
        _view.allowsTransparency = true
    }

    @objc(rendererWithDevice:) class func _objcRenderer(device: any MTLDevice) -> SKRenderer { SKRenderer(device: device) }

    /// runs the scene's frame cycle (actions, physics, constraints, its update callbacks) for this time
    @objc(updateAtTime:) open func update(atTime currentTime: TimeInterval) {
        guard let s = scene else { return }
        if _view.isPaused || s.isPaused { _last = nil; return }
        let dt = _last.map { min(max(currentTime - $0, 0), 0.25) } ?? 0
        _last = currentTime
        s.runFrame(currentTime, dt)
    }

    /// starts a render pass on the command buffer (its load actions apply), then blends the scene over its first color
    /// attachment within the viewport
    @objc(renderWithViewport:commandBuffer:renderPassDescriptor:)
    open func render(withViewport viewport: CGRect, commandBuffer: any MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        enc.endEncoding()
        guard let target = renderPassDescriptor.colorAttachments[0].texture, let step = _composite(viewport, target) else { return }
        _ = (commandBuffer as AnyObject).perform(NSSelectorFromString("addCommand:"), with: step)
    }

    /// blends the scene into the pass the app is encoding (after the draws it encoded so far)
    @objc(renderWithViewport:renderCommandEncoder:renderPassDescriptor:commandQueue:)
    open func render(withViewport viewport: CGRect, renderCommandEncoder: any MTLRenderCommandEncoder,
                     renderPassDescriptor: MTLRenderPassDescriptor, commandQueue: any MTLCommandQueue) {
        guard let target = renderPassDescriptor.colorAttachments[0].texture, let step = _composite(viewport, target) else { return }
        let sel = NSSelectorFromString("_isim_addCommand:")
        if (renderCommandEncoder as AnyObject).responds(to: sel) { _ = (renderCommandEncoder as AnyObject).perform(sel, with: step) }
    }

    /// draws the scene now (isim's renderer runs on the main thread) and returns the step that blends it into `target`
    func _composite(_ viewport: CGRect, _ target: any MTLTexture) -> (@convention(block) () -> Void)? {
        guard let s = scene else { return nil }
        let rgba: Bool
        switch target.pixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb: rgba = false
        case .rgba8Unorm, .rgba8Unorm_srgb: rgba = true
        default:
            NSLog("isim SpriteKit: SKRenderer draws into bgra8 or rgba8 color attachments, not pixel format %d", Int32(target.pixelFormat.rawValue))
            return nil
        }
        let vp = viewport.width > 0 && viewport.height > 0 ? viewport : CGRect(x: 0, y: 0, width: target.width, height: target.height)
        let x0 = max(0, Int(vp.minX.rounded())), y0 = max(0, Int(vp.minY.rounded()))
        let w = min(Int(vp.width.rounded()), target.width - x0), h = min(Int(vp.height.rounded()), target.height - y0)
        guard w > 0, h > 0 else { return nil }
        // the viewport is in pixels: draw at scale 1 into a view of that size
        let size = CGSize(width: w, height: h)
        if _view.bounds.size != size {
            _view.frame = CGRect(origin: .zero, size: size)
            if s.scaleMode == .resizeFill { s.size = size }
        }
        guard isim_gfx_offscreen_begin(Double(w), Double(h), 1, 0) != 0 else { return nil }
        _view.drawnNodes = 0; _view.drawCount = 0; _view.quadCount = 0
        _view.drawScene(s)
        let hd = isim_gfx_offscreen_snapshot()
        isim_gfx_offscreen_end()
        guard hd > 0 else { return nil }
        var src = [UInt8](repeating: 0, count: w * h * 4)
        let ok = src.withUnsafeMutableBufferPointer { isim_image_read_bgra(hd, 0, 0, Int32(w), Int32(h), $0.baseAddress) }
        isim_image_free(hd)
        guard ok != 0 else { return nil }
        let region = MTLRegionMake2D(x0, y0, w, h)
        return {
            var dst = [UInt8](repeating: 0, count: w * h * 4)
            target.getBytes(&dst, bytesPerRow: w * 4, from: region, mipmapLevel: 0)
            for i in stride(from: 0, to: dst.count, by: 4) {
                // premultiplied source over the destination; rgba targets swap red and blue
                let a = Int(src[i + 3])
                if a == 0 { continue }
                let b = Int(src[i]), g = Int(src[i + 1]), r = Int(src[i + 2])
                let c0 = rgba ? r : b, c2 = rgba ? b : r
                dst[i] = UInt8(min(255, c0 + Int(dst[i]) * (255 - a) / 255))
                dst[i + 1] = UInt8(min(255, g + Int(dst[i + 1]) * (255 - a) / 255))
                dst[i + 2] = UInt8(min(255, c2 + Int(dst[i + 2]) * (255 - a) / 255))
                dst[i + 3] = UInt8(min(255, a + Int(dst[i + 3]) * (255 - a) / 255))
            }
            target.replace(region: region, mipmapLevel: 0, withBytes: dst, bytesPerRow: w * 4)
        }
    }
}

// Apple's SpriteKitBase.h macros. SK_VERSION is isim's own value (1), not the build number of Apple's framework.
public var SK_VERSION: Int32 { 1 }
public var SKVIEW_AVAILABLE: Int32 { 1 }
public var PHYSICSKIT_MINUS_GL_IMPORTS: Int32 { 1 }

// Playground quick looks (deprecated since Swift 4.2, as in Apple's overlay): the node or texture as an image
extension SKShapeNode {
    @available(swift, deprecated: 4.2, message: "use CustomPlaygroundDisplayConvertible")
    public var customPlaygroundQuickLook: _PlaygroundQuickLook { _skQuickLook(self) }
}
extension SKSpriteNode {
    @available(swift, deprecated: 4.2, message: "use CustomPlaygroundDisplayConvertible")
    public var customPlaygroundQuickLook: _PlaygroundQuickLook { _skQuickLook(self) }
}
extension SKTexture {
    @available(swift, deprecated: 4.2, message: "use CustomPlaygroundDisplayConvertible")
    public var customPlaygroundQuickLook: _PlaygroundQuickLook {
        cgImage().map { .sprite(UIImage(cgImage: $0)) } ?? .text(description)
    }
}
extension SKTextureAtlas {
    @available(swift, deprecated: 4.2, message: "use CustomPlaygroundDisplayConvertible")
    public var customPlaygroundQuickLook: _PlaygroundQuickLook { .text(textureNames.sorted().joined(separator: "\n")) }
}
func _skQuickLook(_ n: SKNode) -> _PlaygroundQuickLook {
    let v = SKView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    return v.texture(from: n)?.cgImage().map { .sprite(UIImage(cgImage: $0)) } ?? .text(n.description)
}
