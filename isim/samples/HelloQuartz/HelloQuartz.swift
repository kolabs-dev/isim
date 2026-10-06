// Sample: Core Graphics below UIKit on isim — bitmap contexts over app memory (pixel read/write, makeImage), CGImage
// from raw bytes (data providers, cropping, masks), color spaces (Display P3, gray), gradients and shadings, shadows,
// blend modes, transparency layers, clip masks, patterns, Core Text lines/frames drawn into CGContexts, and PDF
// (UIGraphicsPDFRenderer + CGPDFContext writing, CGPDFDocument reading).
import UIKit
import CoreText

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = QuartzViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// RGBA bytes at (x, y) of a bitmap (row 0 is the top of the image).
func pixel(_ data: UnsafeMutableRawPointer, _ bpr: Int, _ x: Int, _ y: Int) -> [UInt8] {
    let p = data.advanced(by: y * bpr + x * 4).assumingMemoryBound(to: UInt8.self)
    return [p[0], p[1], p[2], p[3]]
}
func rgbaContext(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// Tiles drawn straight into UIKit's context in draw(_:): gradients, shading, shadow, blend mode, transparency layer.
final class EffectsView: UIView {
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        // 1. linear gradient red -> blue, left to right (0...100)
        let space = CGColorSpaceCreateDeviceRGB()
        let lin = CGGradient(colorsSpace: space, colors: [UIColor.red.cgColor, UIColor.blue.cgColor] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: 100, height: 60))
        ctx.drawLinearGradient(lin, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 0), options: [])
        ctx.restoreGState()
        // 2. radial gradient white center -> green edge, painted past the end
        let rad = CGGradient(colorSpace: space, colorComponents: [1, 1, 1, 1, 0, 0.6, 0, 1], locations: [0, 1], count: 2)!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 110, y: 0, width: 100, height: 60))
        ctx.drawRadialGradient(rad, startCenter: CGPoint(x: 160, y: 30), startRadius: 0, endCenter: CGPoint(x: 160, y: 30), endRadius: 25, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
        // 3. axial shading from a CGFunction (black -> yellow)
        var callbacks = CGFunctionCallbacks(version: 0, evaluate: { _, input, output in
            let t = input[0]; output[0] = t; output[1] = t; output[2] = 0; output[3] = 1
        }, releaseInfo: nil)
        let fn = CGFunction(info: nil, domainDimension: 1, domain: [0, 1], rangeDimension: 4, range: [0, 1, 0, 1, 0, 1, 0, 1], callbacks: &callbacks)!
        let shading = CGShading(axialSpace: space, start: CGPoint(x: 220, y: 0), end: CGPoint(x: 320, y: 0), function: fn, extendStart: false, extendEnd: false)!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 220, y: 0, width: 100, height: 60))
        ctx.drawShading(shading)
        ctx.restoreGState()
        // 4. shadow: blue square with a black shadow 8pt right/down, blur 4
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 8, height: 8), blur: 4, color: UIColor.black.cgColor)
        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.fill(CGRect(x: 0, y: 75, width: 50, height: 50))
        ctx.restoreGState()
        // 5. multiply blend: yellow over cyan = green
        ctx.setFillColor(UIColor.cyan.cgColor)
        ctx.fill(CGRect(x: 110, y: 75, width: 60, height: 50))
        ctx.saveGState()
        ctx.setBlendMode(.multiply)
        ctx.setFillColor(UIColor.yellow.cgColor)
        ctx.fill(CGRect(x: 140, y: 75, width: 60, height: 50))
        ctx.restoreGState()
        // 6. transparency layer at 50%: overlapping red squares composite once (overlap is not darker)
        ctx.saveGState()
        ctx.setAlpha(0.5)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(UIColor.red.cgColor)
        ctx.fill(CGRect(x: 220, y: 75, width: 60, height: 50))
        ctx.fill(CGRect(x: 250, y: 75, width: 60, height: 50))
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
}

final class QuartzViewController: UIViewController {
    var y: CGFloat = 70
    var frameImage: CGImage?
    func tile(_ image: CGImage?, _ id: String, x: CGFloat, size: CGFloat = 60, nearest: Bool = false) {
        guard let image else { print("\(id): no image"); return }
        let v = UIImageView(image: UIImage(cgImage: image))
        v.frame = CGRect(x: x, y: y, width: size * CGFloat(image.width) / CGFloat(image.height), height: size)
        v.accessibilityIdentifier = id
        if nearest { v.layer.magnificationFilter = .nearest }
        view.addSubview(v)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let title = UILabel(frame: CGRect(x: 16, y: 54, width: 360, height: 14))
        title.text = "Core Graphics · Core Text · PDF"; title.font = .systemFont(ofSize: 12)
        view.addSubview(title)

        bitmapTiles()
        y += 70
        imageTiles()
        y += 70
        let effects = EffectsView(frame: CGRect(x: 16, y: y, width: 330, height: 130))
        effects.backgroundColor = .white
        effects.accessibilityIdentifier = "effects"
        view.addSubview(effects)
        y += 140
        colorChecks()
    }

    // MARK: bitmap contexts
    func bitmapTiles() {
        // RGBA, premultiplied last: the bitmap is y-up, so a rect at y 0...32 is the bottom half of the memory
        let ctx = rgbaContext(64, 64)
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
        let data = ctx.data!
        print("bitmap rgba \(ctx.width)x\(ctx.height) bpr \(ctx.bytesPerRow) bottom \(pixel(data, ctx.bytesPerRow, 5, 60)) top \(pixel(data, ctx.bytesPerRow, 5, 5))")
        // the app writes pixels: a green band in rows 0..7 (top), then draws a half-transparent blue square over it
        for row in 0..<8 { for col in 0..<64 { let p = data.advanced(by: row * ctx.bytesPerRow + col * 4).assumingMemoryBound(to: UInt8.self); p[0] = 0; p[1] = 255; p[2] = 0; p[3] = 255 } }
        ctx.setFillColor(red: 0, green: 0, blue: 1, alpha: 0.5)
        ctx.fill(CGRect(x: 32, y: 48, width: 32, height: 16))     // top-right quarter of the top band area
        print("bitmap app write kept \(pixel(data, ctx.bytesPerRow, 5, 3)) blended \(pixel(data, ctx.bytesPerRow, 40, 3))")
        let img = ctx.makeImage()
        print("makeImage \(img!.width)x\(img!.height) alpha \(img!.alphaInfo.rawValue) bpc \(img!.bitsPerComponent) bpp \(img!.bitsPerPixel)")
        tile(img, "bitmap", x: 16)

        // BGRA (premultiplied first, 32-bit little endian): cairo's own layout, drawn in place
        let bgra = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        bgra.setFillColor(UIColor(red: 1, green: 0.5, blue: 0, alpha: 1).cgColor)
        bgra.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        print("bitmap bgra \(pixel(bgra.data!, 32, 1, 1))")

        // 8-bit gray
        let gray = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceGray(),
                             bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        gray.setFillColor(gray: 0.5, alpha: 1)
        gray.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        print("bitmap gray \(gray.data!.assumingMemoryBound(to: UInt8.self)[5]) ctm \(gray.ctm.a),\(gray.ctm.d)")
        print("bitmap unsupported 16bpc: \(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 16, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) == nil)")

        // UIGraphicsPushContext: UIKit drawing (UIBezierPath) into the bitmap context
        let pushed = rgbaContext(60, 60)
        UIGraphicsPushContext(pushed)
        UIColor.systemOrange.setFill()
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 60)).fill()
        UIGraphicsPopContext()
        tile(pushed.makeImage(), "pushed", x: 86)

        // pattern: 10x10 cells with a 5x5 purple square
        var cb = CGPatternCallbacks(version: 0, drawPattern: { _, c in
            c.setFillColor(UIColor.purple.cgColor); c.fill(CGRect(x: 0, y: 0, width: 5, height: 5))
        }, releaseInfo: nil)
        let pattern = CGPattern(info: nil, bounds: CGRect(x: 0, y: 0, width: 10, height: 10), matrix: .identity, xStep: 10, yStep: 10,
                                tiling: .constantSpacing, isColored: true, callbacks: &cb)!
        let pctx = rgbaContext(60, 60)
        let pspace = CGColorSpace(patternBaseSpace: nil)!
        pctx.setFillColorSpace(pspace)
        var alpha: CGFloat = 1
        pctx.setFillPattern(pattern, colorComponents: &alpha)
        pctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        print("pattern cell \(pixel(pctx.data!, pctx.bytesPerRow, 2, 57)) gap \(pixel(pctx.data!, pctx.bytesPerRow, 7, 57))")
        tile(pctx.makeImage(), "pattern", x: 156)

        // clip to a mask: a gray mask image (white circle on black) lets the fill through where it is white
        let maskCtx = CGContext(data: nil, width: 60, height: 60, bitsPerComponent: 8, bytesPerRow: 60, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        maskCtx.setFillColor(gray: 1, alpha: 1)
        maskCtx.fillEllipse(in: CGRect(x: 10, y: 10, width: 40, height: 40))
        let masked = rgbaContext(60, 60)
        masked.clip(to: CGRect(x: 0, y: 0, width: 60, height: 60), mask: maskCtx.makeImage()!)
        masked.setFillColor(UIColor.systemGreen.cgColor)
        masked.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        print("clip mask center \(pixel(masked.data!, 240, 30, 30)) corner \(pixel(masked.data!, 240, 2, 2))")
        tile(masked.makeImage(), "clipmask", x: 226)

        // Core Text: a line drawn into a bitmap context (y-up text space)
        let text = rgbaContext(120, 60)
        text.setFillColor(UIColor.white.cgColor); text.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        let attr = NSAttributedString(string: "Quartz", attributes: [.font: CTFontCreateWithName("Helvetica-Bold" as CFString, 28, nil),
                                                                       .foregroundColor: UIColor.systemRed.cgColor])
        let line = CTLineCreateWithAttributedString(attr)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        text.textPosition = CGPoint(x: 6, y: 18)
        CTLineDraw(line, text)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        print("ctline width \(Int(width)) ascent \(Int(ascent)) descent \(Int(descent)) glyphs \(CTLineGetGlyphCount(line)) runs \(runs.count) run0 glyphs \(CTRunGetGlyphCount(runs[0]))")
        print("ctline index at x=width: \(CTLineGetStringIndexForPosition(line, CGPoint(x: width + 5, y: 0))) offset of 3: \(Int(CTLineGetOffsetForStringIndex(line, 3, nil)))")
        tile(text.makeImage(), "ctline", x: 296, size: 40)
    }

    // MARK: CGImage from bytes, cropping, masking, PDF
    func imageTiles() {
        // a 2x2 RGBA image from raw bytes: red, green / blue, white
        let bytes: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let img = CGImage(width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                          decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let back = img.dataProvider!.data! as Data
        print("cgimage from bytes \(img.width)x\(img.height) bpr \(img.bytesPerRow) provider \(back.count) bytes \(Array(back.prefix(4)))")
        tile(img, "rawimage", x: 16, nearest: true)
        // cropping: the bottom-right pixel (white)
        let crop = img.cropping(to: CGRect(x: 1, y: 1, width: 1, height: 1))!
        print("cropped \(crop.width)x\(crop.height) bytes \(Array((crop.dataProvider!.data! as Data).prefix(4)))")
        // an image mask (0 = paint): only the left column of a 2x2 mask paints
        let maskBytes: [UInt8] = [0, 255, 0, 255]
        let mask = CGImage(maskWidth: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 2,
                           provider: CGDataProvider(data: Data(maskBytes) as CFData)!, decode: nil, shouldInterpolate: false)!
        let maskedImg = img.masking(mask)!
        let mctx = rgbaContext(2, 2)
        mctx.draw(maskedImg, in: CGRect(x: 0, y: 0, width: 2, height: 2))
        print("masking left \(pixel(mctx.data!, 8, 0, 0)) right \(pixel(mctx.data!, 8, 1, 0)) isMask \(mask.isMask)")
        tile(maskedImg, "maskedimage", x: 86, nearest: true)

        // PDF: UIGraphicsPDFRenderer writes a page; CGPDFDocument reads it back and draws it into a bitmap
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 100))
        let pdf = renderer.pdfData { ctx in
            ctx.beginPage()
            UIColor.systemTeal.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
            "PDF".draw(at: CGPoint(x: 120, y: 30), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 30), .foregroundColor: UIColor.black])
            ctx.beginPage()
            UIColor.systemPink.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }
        print("pdf \(pdf.count) bytes header \(String(decoding: pdf.prefix(5), as: UTF8.self))")
        if let doc = CGPDFDocument(CGDataProvider(data: pdf as CFData)!), let page = doc.page(at: 1) {
            let box = page.getBoxRect(.mediaBox)
            let pctx = rgbaContext(120, 60)
            pctx.scaleBy(x: 0.6, y: 0.6)
            pctx.drawPDFPage(page)
            print("pdf read pages \(doc.numberOfPages) box \(Int(box.width))x\(Int(box.height)) left \(pixel(pctx.data!, 480, 10, 30))")
            tile(pctx.makeImage(), "pdfpage", x: 156, size: 60)
        } else {
            print("pdf read: CGPDFDocument unavailable")
        }
        // CGPDFContext (y-up) writing into a CFMutableData
        let out = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 50, height: 50)
        let pc = CGContext(consumer: CGDataConsumer(data: out as CFMutableData)!, mediaBox: &box, nil)!
        pc.beginPDFPage(nil)
        pc.setFillColor(UIColor.blue.cgColor)
        pc.fill(CGRect(x: 0, y: 0, width: 50, height: 25))
        pc.endPDFPage()
        pc.closePDF()
        print("cgpdfcontext \(out.length > 200) bytes, %PDF \(String(decoding: (out as Data).prefix(4), as: UTF8.self))")
        if let doc = CGPDFDocument(CGDataProvider(data: out as CFData)!), let page = doc.page(at: 1) {
            let c = rgbaContext(50, 50)
            c.drawPDFPage(page)
            print("cgpdf roundtrip bottom \(pixel(c.data!, 200, 25, 45)) top \(pixel(c.data!, 200, 25, 5))")
            tile(c.makeImage(), "cgpdf", x: 286)
        }
        // Core Text frame: wrapped paragraph in a 120x60 rect
        let fctx = rgbaContext(120, 60)
        fctx.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor); fctx.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        let para = NSAttributedString(string: "Core Text frames wrap lines inside a path.", attributes: [.font: UIFont.systemFont(ofSize: 13)])
        let setter = CTFramesetterCreateWithAttributedString(para)
        let fit = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil, CGSize(width: 120, height: 1000), nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: CGRect(x: 0, y: 0, width: 120, height: 60), transform: nil), nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        CTFrameDraw(frame, fctx)
        print("ctframe lines \(lines.count) first origin y \(Int(origins.first?.y ?? -1)) visible \(CTFrameGetVisibleStringRange(frame).length) fit \(Int(fit.width))x\(Int(fit.height))")
        frameImage = fctx.makeImage()
    }

    // MARK: color spaces
    func colorChecks() {
        let p3 = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, components: [1, 0, 0, 1])!
        let srgb = p3.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)!
        let g = CGColor(gray: 0.25, alpha: 1)
        print("p3 red space \(p3.colorSpace!.name! as String) comps \(p3.numberOfComponents) srgb \(srgb.components!.map { Int(($0 * 255).rounded()) })")
        print("gray comps \(g.components!) model \(g.colorSpace!.model.rawValue) wide \(CGColorSpace(name: CGColorSpace.displayP3)!.isWideGamutRGB)")
        let sw = UIView(frame: CGRect(x: 16, y: y, width: 40, height: 40))
        sw.layer.backgroundColor = g
        sw.accessibilityIdentifier = "grayswatch"
        view.addSubview(sw)
        tile(frameImage, "ctframe", x: 70)
    }
}
