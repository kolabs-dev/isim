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

/// Path operations (issue #273), filled in UIKit's context: two circles unioned with the rectangle between them, a hole
/// subtracted (orange), and a dashed copy of the outline stroked into a filled outline (purple).
final class PathsView: UIView {
    static func shape() -> CGPath {
        let left = CGPath(ellipseIn: CGRect(x: 4, y: 10, width: 40, height: 40), transform: nil)
        let right = CGPath(ellipseIn: CGRect(x: 54, y: 10, width: 40, height: 40), transform: nil)
        let bar = CGPath(rect: CGRect(x: 24, y: 22, width: 50, height: 16), transform: nil)
        let hole = CGPath(rect: CGRect(x: 14, y: 26, width: 20, height: 8), transform: nil)
        return left.union(right).union(bar).subtracting(hole)
    }
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let shape = Self.shape()
        ctx.addPath(shape)
        ctx.setFillColor(UIColor.systemOrange.cgColor)
        ctx.fillPath()
        let outline = shape.copy(dashingWithPhase: 0, lengths: [6, 4])
            .copy(strokingWithWidth: 2, lineCap: .butt, lineJoin: .miter, miterLimit: 10)
        ctx.addPath(outline.copy(using: [CGAffineTransform(translationX: 100, y: 0)])!)   // Apple's copy(using: UnsafePointer?)
        ctx.setFillColor(UIColor.systemPurple.cgColor)
        ctx.fillPath()
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
        contextAndFontChecks()
        pathChecks()
    }

    // MARK: path operations (issue #273)
    func pathChecks() {
        let paths = PathsView(frame: CGRect(x: 196, y: y, width: 200, height: 60))
        paths.backgroundColor = .white
        paths.accessibilityIdentifier = "paths"
        view.addSubview(paths)
        let shape = PathsView.shape()
        let line = CGMutablePath()
        line.move(to: .zero)
        line.addLine(to: CGPoint(x: 100, y: 0))
        let stroked = line.copy(strokingWithWidth: 10, lineCap: .square, lineJoin: .miter, miterLimit: 10).boundingBoxOfPath
        var dashes = 0
        line.copy(dashingWithPhase: 0, lengths: [10, 10]).applyWithBlock { if $0.pointee.type == .moveToPoint { dashes += 1 } }
        var r = CGRect.zero
        let moved = CGPath(rect: CGRect(x: 0, y: 0, width: 4, height: 3), transform: nil).copy(using: [CGAffineTransform(translationX: 1, y: 2)])!
        let corner = CGMutablePath()
        corner.move(to: .zero)
        corner.addArc(tangent1End: CGPoint(x: 10, y: 0), tangent2End: CGPoint(x: 10, y: 10), radius: 5)
        let a = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil)
        let b = CGPath(rect: CGRect(x: 5, y: 0, width: 10, height: 10), transform: nil)
        print("cgpath shape hole \(shape.contains(CGPoint(x: 20, y: 30))) bar \(shape.contains(CGPoint(x: 49, y: 30))) " +
              "stroked \(Int(stroked.minX)),\(Int(stroked.width))x\(Int(stroked.height)) dashes \(dashes) " +
              "isRect \(moved.isRect(&r)) \(Int(r.minX)),\(Int(r.minY)) arc end \(Int(corner.currentPoint.x)),\(Int(corner.currentPoint.y)) " +
              "union \(Int(a.union(b).boundingBoxOfPath.width)) intersection \(Int(a.intersection(b).boundingBoxOfPath.width)) " +
              "subtracting \(Int(a.subtracting(b).boundingBoxOfPath.width)) parts \(a.union(CGPath(rect: CGRect(x: 30, y: 0, width: 2, height: 2), transform: nil)).componentsSeparated().count) " +
              "intersects \(a.intersects(b))")
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

        // Uncolored pattern in a CMYK base space, used for both fill and stroke. The callback supplies geometry;
        // the caller's components supply the color (cyan here).
        var monoCB = CGPatternCallbacks(version: 0, drawPattern: { _, c in
            c.fill(CGRect(x: 0, y: 0, width: 4, height: 8))
        }, releaseInfo: nil)
        let mono = CGPattern(info: nil, bounds: CGRect(x: 0, y: 0, width: 8, height: 8), matrix: .identity,
                             xStep: 8, yStep: 8, tiling: .constantSpacing, isColored: false, callbacks: &monoCB)!
        let monoSpace = CGColorSpace(patternBaseSpace: CGColorSpace(name: CGColorSpace.genericCMYK)!)!
        let monoCtx = rgbaContext(32, 32)
        monoCtx.setFillColorSpace(monoSpace)
        var cyan: [CGFloat] = [1, 0, 0, 0, 1]
        monoCtx.setFillPattern(mono, colorComponents: &cyan)
        monoCtx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        monoCtx.setStrokeColorSpace(monoSpace)
        monoCtx.setStrokePattern(mono, colorComponents: &cyan)
        monoCtx.setLineWidth(4)
        monoCtx.stroke(CGRect(x: 2, y: 2, width: 28, height: 28))
        print("pattern uncolored fill \(pixel(monoCtx.data!, monoCtx.bytesPerRow, 2, 23)) gap \(pixel(monoCtx.data!, monoCtx.bytesPerRow, 6, 23)) stroke \(pixel(monoCtx.data!, monoCtx.bytesPerRow, 3, 16)) base \(monoSpace.baseColorSpace!.name! as String)")

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
        pc.setShadow(offset: CGSize(width: 8, height: 0), blur: 8, color: UIColor.black.cgColor)
        pc.setFillColor(UIColor.blue.cgColor)
        pc.fill(CGRect(x: 5, y: 5, width: 20, height: 20))
        pc.endPDFPage()
        pc.closePDF()
        print("cgpdfcontext \(out.length > 200) bytes, %PDF \(String(decoding: (out as Data).prefix(4), as: UTF8.self))")
        if let doc = CGPDFDocument(CGDataProvider(data: out as CFData)!), let page = doc.page(at: 1) {
            let c = rgbaContext(50, 50)
            c.drawPDFPage(page)
            let transform = page.getDrawingTransform(.mediaBox, rect: CGRect(x: 0, y: 0, width: 25, height: 25), rotate: 0, preserveAspectRatio: true)
            print("cgpdf roundtrip fill \(pixel(c.data!, 200, 15, 35)) shadow \(pixel(c.data!, 200, 31, 35)) fade \(pixel(c.data!, 200, 39, 35)) clear \(pixel(c.data!, 200, 48, 35)) page \(page.pageNumber) rotation \(page.rotationAngle) transform \(transform.a)")
            tile(c.makeImage(), "cgpdf", x: 286)
        }
        // the PDF object model: document info, a link, a named destination and an outline written by a CGPDFContext,
        // read back through CGPDFDictionary and the outline; the content stream through a CGPDFScanner
        let linked = NSMutableData()
        var lbox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let lc = CGContext(consumer: CGDataConsumer(data: linked as CFMutableData)!, mediaBox: &lbox,
                           [kCGPDFContextTitle: "Quartz objects", kCGPDFContextAuthor: "HelloQuartz"] as CFDictionary)!
        lc.beginPDFPage(nil)
        lc.setFillColor(UIColor.red.cgColor)
        lc.fill(CGRect(x: 10, y: 10, width: 30, height: 30))
        lc.setURL(URL(string: "https://example.com")! as CFURL, for: CGRect(x: 10, y: 10, width: 30, height: 30))
        lc.addDestination("top" as CFString, at: CGPoint(x: 0, y: 100))
        lc.endPDFPage()
        CGPDFContextSetOutline(lc, [kCGPDFOutlineChildren: [[kCGPDFOutlineTitle: "Top", kCGPDFOutlineDestination: 1] as CFDictionary]] as CFDictionary)
        lc.closePDF()
        if let doc = CGPDFDocument(CGDataProvider(data: linked as CFData)!), let page = doc.page(at: 1), let info = doc.info {
            var title: CGPDFStringRef?
            let name = CGPDFDictionaryGetString(info, "Title", &title) ? (CGPDFStringCopyTextString(title!) as String? ?? "") : "?"
            var annots: CGPDFArrayRef?
            let links = page.dictionary.flatMap { CGPDFDictionaryGetArray($0, "Annots", &annots) ? CGPDFArrayGetCount(annots!) : 0 } ?? 0
            let outline = (doc.outline as? [String: Any])?[kCGPDFOutlineChildren as String] as? [[String: Any]] ?? []
            var ops = 0
            let table = CGPDFOperatorTableCreate()!
            CGPDFOperatorTableSetCallback(table, "re") { scanner, info in
                var h: CGPDFReal = 0
                if CGPDFScannerPopNumber(scanner, &h) { info!.assumingMemoryBound(to: Int.self).pointee += 1 }
            }
            let stream = CGPDFContentStreamCreateWithPage(page)
            withUnsafeMutablePointer(to: &ops) { p in
                let scanner = CGPDFScannerCreate(stream, table, p)
                CGPDFScannerScan(scanner)
                CGPDFScannerRelease(scanner)
            }
            CGPDFContentStreamRelease(stream)
            CGPDFOperatorTableRelease(table)
            print("cgpdf objects title \(name) links \(links) outline \(outline.first?[kCGPDFOutlineTitle as String] ?? "-") rects \(ops) version \(doc.isEncrypted ? "encrypted" : "plain")")
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

    // MARK: context queries and CGFont
    func contextAndFontChecks() {
        let q = rgbaContext(80, 80)
        q.translateBy(x: 10, y: 12)
        q.scaleBy(x: 2, y: 3)
        let device = q.convertToDeviceSpace(CGPoint(x: 4, y: 5))
        let user = q.convertToUserSpace(device)
        q.clip(to: CGRect(x: 1, y: 2, width: 20, height: 10))
        let clip = q.boundingBoxOfClipPath
        q.beginPath(); q.move(to: CGPoint(x: 5, y: 10)); q.addLine(to: CGPoint(x: 35, y: 10))
        let before = q.path!.boundingBox
        q.setLineWidth(10); q.replacePathWithStrokedPath()
        let stroked = q.path!.boundingBox
        let contains = q.pathContains(CGPoint(x: 20, y: 13), mode: .fill)
        q.setFillColor(UIColor.red.cgColor); q.fillPath()
        print("context ctm \(Int(q.ctm.a)),\(Int(q.ctm.d)) device \(Int(device.x)),\(Int(device.y)) user \(Int(user.x)),\(Int(user.y)) clip \(Int(clip.width.rounded()))x\(Int(clip.height.rounded())) path \(Int(before.width.rounded())) stroked \(Int(stroked.height.rounded())) contains \(contains) empty \(q.isPathEmpty)")

        let named = CGFont("Helvetica" as CFString)!
        let url = Bundle.main.url(forResource: "AdwaitaSans-Regular", withExtension: "ttf")!
        let data = try! Data(contentsOf: url)
        let fromData = CGFont(CGDataProvider(data: data as CFData)!)!
        print("cgfont named \(named.postScriptName! as String) units \(named.unitsPerEm) provider \(fromData.postScriptName! as String) full \(fromData.fullName! as String) units \(fromData.unitsPerEm)")

        let names: [CFString] = [CGColorSpace.sRGB, CGColorSpace.displayP3, CGColorSpace.linearSRGB,
                                CGColorSpace.extendedSRGB, CGColorSpace.extendedLinearSRGB, CGColorSpace.genericRGBLinear,
                                CGColorSpace.genericGrayGamma2_2, CGColorSpace.linearGray, CGColorSpace.extendedGray,
                                CGColorSpace.genericCMYK, CGColorSpace.itur_709]
        let spaces = names.map { CGColorSpace(name: $0)! }
        print("color spaces \(spaces.map { $0.name! as String }.joined(separator: ",")) models \(spaces.map { $0.model.rawValue }) extended \(spaces.filter { CGColorSpaceUsesExtendedRange($0) }.count) p3wide \(spaces[1].isWideGamutRGB)")
        let linear = CGColor(colorSpace: spaces[2], components: [0.25, 0.25, 0.25, 1])!.converted(to: spaces[0], intent: .defaultIntent, options: nil)!
        let cmyk = CGColor(colorSpace: spaces[9], components: [1, 0, 0, 0, 1])!.converted(to: spaces[0], intent: .defaultIntent, options: nil)!
        print("color conversions linear \(linear.components!.map { Int(($0 * 255).rounded()) }) cmyk \(cmyk.components!.map { Int(($0 * 255).rounded()) })")
        // issue #363: CGFont tables, Lab and indexed spaces, linearized spaces, layers, conic gradients
        let head = fromData.table(for: 0x6865_6164) as Data?       // 'head'
        let tags = fromData.tableTags.map { CFArrayGetCount($0) } ?? 0
        let lab = CGColorSpace(labWhitePoint: [0.95047, 1, 1.08883], blackPoint: nil, range: [-128, 127, -128, 127])!
        let indexed = CGColorSpace(indexedBaseSpace: CGColorSpaceCreateDeviceRGB(), last: 1, colorTable: [255, 0, 0, 0, 0, 255])!
        let labRed = CGColor(colorSpace: lab, components: [53.24, 80.09, 67.2, 1])!.converted(to: spaces[0], intent: .defaultIntent, options: nil)!
        let host = rgbaContext(40, 40)
        let layer = CGLayer(host, size: CGSize(width: 20, height: 20), auxiliaryInfo: nil)!
        layer.context!.setFillColor(UIColor.blue.cgColor)
        layer.context!.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        host.draw(layer, at: CGPoint(x: 10, y: 10))
        let conic = rgbaContext(40, 40)
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.red.cgColor, UIColor.blue.cgColor] as CFArray, locations: [0, 1])!
        conic.drawConicGradient(gradient, center: CGPoint(x: 20, y: 20), angle: 0)
        print("cg extras head \(head?.count ?? 0) tags \(tags > 5) lab red \(labRed.components!.map { Int(($0 * 255).rounded()) }) indexed \(indexed.colorTable!) " +
              "linearized \(CGColorSpaceCreateLinearized(spaces[0])!.name! as String) layer \(pixel(host.data!, host.bytesPerRow, 20, 20)) " +
              "outside \(pixel(host.data!, host.bytesPerRow, 5, 5)) conic start \(pixel(conic.data!, conic.bytesPerRow, 36, 17)) end \(pixel(conic.data!, conic.bytesPerRow, 36, 22))")
    }
}
