// isim SpriteKit: Core Image in SpriteKit (adapted, on the CPU): SKEffectNode's `filter` (and `shader`) applied to
// its children rendered offscreen at the screen's resolution, `shouldCenterFilter` (the filter's inputCenter at the
// middle of the children), `shouldRasterize` (the filtered image is kept until the children change), and
// `SKTransition(ciFilter:duration:)` (the filter gets both scenes rendered offscreen and inputTime 0...1).
import Foundation
import CoreImage
import isim_host

nonisolated(unsafe) let _skFilterContext = CIContext()

/// a host image rendered offscreen as a CGImage (the CGImage owns it)
func _skCGImage(fromHostImage hd: Int32) -> CGImage? { isim_cg_image_with_handle(hd) }

final class _SKRasterCache { var signature = ""; var image: CGImage?; var origin = CGPoint.zero; var scale: CGFloat = 1 }
nonisolated(unsafe) private var _skRasterKey: UInt8 = 0

extension SKEffectNode {
    var _hasEffect: Bool { shouldEnableEffects && (filter != nil || shader != nil) }
    /// what the children look like: changes when any of them moves, turns, scales, fades or changes texture
    func _signature(_ t: CGAffineTransform) -> String {
        var s = "\(t.a),\(t.b),\(t.c),\(t.d),\(t.tx),\(t.ty)"
        func walk(_ n: SKNode) {
            for c in n.children {
                s += "|\(ObjectIdentifier(c).hashValue):\(c.position.x),\(c.position.y),\(c.zRotation),\(c.xScale),\(c.yScale),\(c.alpha),\(c.isHidden),\(c.zPosition)"
                if let sp = c as? SKSpriteNode { s += ",\(sp.texture.map { ObjectIdentifier($0).hashValue } ?? 0),\(sp.size.width),\(sp.size.height),\(sp.color.hash),\(sp.colorBlendFactor)" }
                if let sh = c as? SKShapeNode { s += ",\(String(describing: sh.path?.boundingBox)),\(sh.fillColor.hash),\(sh.strokeColor.hash),\(sh.lineWidth)" }
                if let l = c as? SKLabelNode { s += ",\(l.text ?? ""),\(l.fontColor?.hash ?? 0)" }
                walk(c)
            }
        }
        walk(self)
        return s
    }

    /// draws the children filtered; t: this node's space -> the current (view) space
    func _drawFiltered(_ view: SKView, _ t: CGAffineTransform, alpha: CGFloat) {
        // the children's bounds in view space
        var box = CGRect.null
        for c in children where !c.isHidden { box = box.union(c.calculateAccumulatedFrame()) }
        guard !box.isNull, box.width > 0, box.height > 0 else { return }
        let vb = box.applying(t).integral
        let scale = max(1, view.window?.screen.scale ?? UIScreen.main.scale)
        let cache = (objc_getAssociatedObject(self, &_skRasterKey) as? _SKRasterCache) ?? {
            let c = _SKRasterCache(); objc_setAssociatedObject(self, &_skRasterKey, c, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)); return c
        }()
        let sig = shouldRasterize ? _signature(t) : ""
        if !shouldRasterize || cache.signature != sig || cache.image == nil {
            guard vb.width >= 1, vb.height >= 1, isim_gfx_offscreen_begin(vb.width, vb.height, scale, 0) != 0 else { return }
            view.renderTree(self, t.concatenating(CGAffineTransform(translationX: -vb.minX, y: -vb.minY)), 1)
            let hd = isim_gfx_offscreen_snapshot()
            isim_gfx_offscreen_end()
            guard hd > 0, let cg = _skCGImage(fromHostImage: hd) else { return }
            var out: CGImage? = cg
            var origin = vb.origin
            if let f = filter {
                let input = CIImage(cgImage: cg)
                f.setValue(input, forKey: kCIInputImageKey)
                if shouldCenterFilter, f.inputKeys.contains(kCIInputCenterKey) {
                    f.setValue(CIVector(x: input.extent.midX, y: input.extent.midY), forKey: kCIInputCenterKey)
                }
                if let result = f.outputImage {
                    // what the filter adds around the image (a blur's spread), within a margin
                    let margin = max(input.extent.width, input.extent.height) / 2
                    let ext = result.extent.isInfinite ? input.extent : result.extent.intersection(input.extent.insetBy(dx: -margin, dy: -margin)).integral
                    if ext.width >= 1, ext.height >= 1, let r = _skFilterContext.createCGImage(result, from: ext) {
                        out = r
                        // CI pixels are y-up from the bottom-left of the input image
                        origin = CGPoint(x: vb.minX + ext.minX / scale, y: vb.minY + (input.extent.height - ext.maxY) / scale)
                    }
                }
                f.setValue(nil, forKey: kCIInputImageKey)
            }
            if let sh = shader, let img = out {
                let base = CIImage(cgImage: img, options: [.colorSpace: NSNull()])
                if let r = _runShader(sh, base: base, color: [1, 1, 1, 1], blendFactor: 0, w: img.width, h: img.height,
                                      spriteSize: CGSize(width: CGFloat(img.width) / scale, height: CGFloat(img.height) / scale)) { out = r }
            }
            cache.image = out; cache.origin = origin; cache.scale = scale; cache.signature = sig
        }
        guard let img = cache.image else { return }
        var px = CGRect.zero
        let hd = isim_cg_image_handle(img, &px)
        isim_gfx_save()
        isim_gfx_set_blend(_hostBlend(blendMode))
        isim_image_draw_part(hd, px.minX, px.minY, px.width, px.height, cache.origin.x, cache.origin.y,
                             px.width / cache.scale, px.height / cache.scale, 0, nil, 0, Double(alpha))
        isim_gfx_restore()
    }
}

extension SKView {
    /// a scene rendered offscreen (for a Core Image transition)
    func _sceneImage(_ s: SKScene) -> CGImage? {
        let scale = max(1, window?.screen.scale ?? UIScreen.main.scale)
        guard bounds.width >= 1, bounds.height >= 1, isim_gfx_offscreen_begin(bounds.width, bounds.height, scale, 1) != 0 else { return nil }
        drawScene(s)
        let hd = isim_gfx_offscreen_snapshot()
        isim_gfx_offscreen_end()
        return hd > 0 ? _skCGImage(fromHostImage: hd) : nil
    }
    /// one frame of a Core Image transition at progress f
    func _drawCITransition(_ filter: CIFilter, from old: SKScene, to new: SKScene, progress f: CGFloat) {
        guard let a = _sceneImage(old), let b = _sceneImage(new) else { drawScene(new); return }
        let ia = CIImage(cgImage: a), ib = CIImage(cgImage: b)
        filter.setValue(ia, forKey: kCIInputImageKey)
        if filter.inputKeys.contains(kCIInputTargetImageKey) { filter.setValue(ib, forKey: kCIInputTargetImageKey) }
        if filter.inputKeys.contains(kCIInputTimeKey) { filter.setValue(f, forKey: kCIInputTimeKey) }
        if filter.inputKeys.contains(kCIInputCenterKey) { filter.setValue(CIVector(x: ia.extent.midX, y: ia.extent.midY), forKey: kCIInputCenterKey) }
        if let out = filter.outputImage, let cg = _skFilterContext.createCGImage(out, from: ia.extent) {
            var px = CGRect.zero
            let hd = isim_cg_image_handle(cg, &px)
            isim_image_draw_part(hd, px.minX, px.minY, px.width, px.height, 0, 0, bounds.width, bounds.height, 0, nil, 0, 1)
        } else {
            drawScene(f < 0.5 ? old : new)
        }
        filter.setValue(nil, forKey: kCIInputImageKey)
        if filter.inputKeys.contains(kCIInputTargetImageKey) { filter.setValue(nil, forKey: kCIInputTargetImageKey) }
    }
}
