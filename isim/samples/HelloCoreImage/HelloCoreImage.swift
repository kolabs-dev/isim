// Sample: Core Image on isim. A gallery of filters, generators and kernels (HELLOCI_PAGE=filters | generators |
// kernels picks the page shown), and on the filters page a battery of checks printed as "ci ..." lines that
// tests/ui/test_coreimage.py reads: the filter registry and every built-in filter rendered, color management and
// pixel formats, CIContext outputs (CGImage, PNG / JPEG / TIFF / OpenEXR / HEIF), the CIImage API, typed builtins,
// color kernels in the Core Image Kernel Language and in Metal (inline and from default.metallib), warp, blend and
// processor kernels, the image accumulator, detectors (faces, rectangles, QR codes, text), barcode descriptors,
// XMP, CIRAWFilter on a generated DNG and the CVPixelBuffer APIs of the Swift overlay.
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import ImageIO

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GalleryViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

let context = CIContext()
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let linear = CGColorSpace(name: CGColorSpace.linearSRGB)!

func log(_ s: String) { print("ci " + s) }
/// 8-bit sRGB RGBA of one pixel (Core Image coordinates: y up)
func px(_ im: CIImage, _ x: CGFloat, _ y: CGFloat, _ c: CIContext = context) -> [Int] {
    var b = [UInt8](repeating: 0, count: 4)
    c.render(im, toBitmap: &b, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBA8, colorSpace: sRGB)
    return b.map { Int($0) }
}
/// float RGBA of one pixel in a color space (linear sRGB by default)
func pxf(_ im: CIImage, _ x: CGFloat, _ y: CGFloat, _ cs: CGColorSpace? = linear, _ c: CIContext = context) -> [Double] {
    var b = [Float](repeating: 0, count: 4)
    c.render(im, toBitmap: &b, rowBytes: 16, bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBAf, colorSpace: cs)
    return b.map { (Double($0) * 1000).rounded() / 1000 }
}
func f3(_ v: Double) -> String { String(format: "%.3f", v) }
func f1(_ v: Double) -> String { String(format: "%.1f", v) }
func ext(_ r: CGRect) -> String { r.isInfinite ? "infinite" : "\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width))x\(Int(r.height))" }

let bundle = Bundle.main
let face = CIImage(contentsOf: bundle.url(forResource: "face", withExtension: "jpg")!)!
/// a QR code generated and detected again: its descriptor (all codewords of the symbol)
let qrDescriptor: CIQRCodeDescriptor? = {
    let qr = CIFilter.qrCodeGenerator(); qr.message = Data("hello isim".utf8)
    let image = qr.outputImage!.samplingNearest().transformed(by: CGAffineTransform(scaleX: 8, y: 8)).composited(over: CIImage.white)
        .cropped(to: CGRect(x: -40, y: -40, width: 300, height: 300))
    return (CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: nil)?.features(in: image).first as? CIQRCodeFeature)?.symbolDescriptor
}()
/// a 64x64 image, left half red, right half blue
let halves: CIImage = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 32, height: 64))
    .composited(over: CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64)))

final class GalleryViewController: UIViewController {
    let page = ProcessInfo.processInfo.environment["HELLOCI_PAGE"] ?? "filters"

    func tile(_ image: CIImage?, _ name: String, _ i: Int, nearest: Bool = false) {
        let cols = 3, w: CGFloat = 116, gap: CGFloat = 12
        let x = 16 + CGFloat(i % cols) * (w + gap), y = 96 + CGFloat(i / cols) * (w + 30)
        let v = UIImageView(frame: CGRect(x: x, y: y, width: w, height: w))
        v.contentMode = .scaleAspectFit
        v.backgroundColor = UIColor(white: 0.94, alpha: 1)
        v.accessibilityIdentifier = name
        if nearest { v.layer.magnificationFilter = .nearest; v.contentMode = .center }    // barcodes: whole pixels per module
        if let image, !image.extent.isInfinite, let cg = context.createCGImage(image, from: image.extent) { v.image = UIImage(cgImage: cg) }
        view.addSubview(v)
        let l = UILabel(frame: CGRect(x: x, y: y + w + 2, width: w, height: 16))
        l.text = name; l.font = .systemFont(ofSize: 12); l.textAlignment = .center
        view.addSubview(l)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let title = UILabel(frame: CGRect(x: 16, y: 58, width: 360, height: 28))
        title.font = .boldSystemFont(ofSize: 22)
        view.addSubview(title)
        switch page {
        case "generators": title.text = "Generators"; generators()
        case "kernels": title.text = "Kernels · Detectors · RAW"; kernels()
        default: title.text = "Core Image filters"; filters()
        }
        print("ci page \(page) shown")
        if page == "filters" {
            DispatchQueue.main.async { Checks().run() }
        }
    }

    func filters() {
        let center = CIVector(x: 128, y: 128)
        let gallery: [(String, CIImage?)] = [
            ("Original", face),
            ("Sepia", face.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.9])),
            ("Comic", face.applyingFilter("CIComicEffect")),
            ("Crystallize", face.applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: 10, kCIInputCenterKey: center])),
            ("Bloom", face.applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 8, kCIInputIntensityKey: 1])),
            ("Twirl", face.applyingFilter("CITwirlDistortion", parameters: [kCIInputCenterKey: center, kCIInputRadiusKey: 120, kCIInputAngleKey: 3.14])),
            ("Bump", face.applyingFilter("CIBumpDistortion", parameters: [kCIInputCenterKey: center, kCIInputRadiusKey: 110, kCIInputScaleKey: 0.6])),
            ("Pixellate", face.applyingFilter("CIPixellate", parameters: [kCIInputCenterKey: center, kCIInputScaleKey: 12])),
            ("Edges", face.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 4])),
            ("Thermal", face.applyingFilter("CIThermal")),
            ("Kaleidoscope", face.applyingFilter("CIKaleidoscope", parameters: [kCIInputCenterKey: center, "inputCount": 6]).cropped(to: face.extent)),
            ("Vignette", face.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 1.5, kCIInputRadiusKey: 2])),
            ("Noir", face.applyingFilter("CIPhotoEffectNoir")),
            ("Hexagonal", face.applyingFilter("CIHexagonalPixellate", parameters: [kCIInputCenterKey: center, kCIInputScaleKey: 10])),
            ("Glass", face.applyingFilter("CIGlassDistortion", parameters: [kCIInputCenterKey: center, kCIInputScaleKey: 60,
                                                                          "inputTexture": CIFilter(name: "CICheckerboardGenerator", parameters: ["inputWidth": 24])!.outputImage!])),
        ]
        for (i, g) in gallery.enumerated() { tile(g.1?.cropped(to: face.extent), g.0, i) }
    }

    func generators() {
        let qr = CIFilter.qrCodeGenerator(); qr.message = Data("https://isim.dev".utf8); qr.correctionLevel = "M"
        let az = CIFilter.aztecCodeGenerator(); az.message = Data("isim aztec".utf8)
        let c128 = CIFilter.code128BarcodeGenerator(); c128.message = Data("isim".utf8); c128.barcodeHeight = 32
        let pdf = CIFilter.pdf417BarcodeGenerator(); pdf.message = Data("isim417".utf8)
        let check = CIFilter.checkerboardGenerator(); check.width = 14; check.center = CGPoint(x: 0, y: 0)
        let lin = CIFilter.linearGradient(); lin.point0 = CGPoint(x: 0, y: 0); lin.point1 = CGPoint(x: 116, y: 116)
        lin.color0 = CIColor(red: 1, green: 0.2, blue: 0.4); lin.color1 = CIColor(red: 0.2, green: 0.3, blue: 1)
        let rad = CIFilter.radialGradient(); rad.center = CGPoint(x: 58, y: 58); rad.radius0 = 8; rad.radius1 = 58
        rad.color0 = CIColor(red: 1, green: 0.9, blue: 0.2); rad.color1 = CIColor(red: 0.1, green: 0.5, blue: 0.2)
        let star = CIFilter.starShineGenerator(); star.center = CGPoint(x: 58, y: 58); star.radius = 10; star.crossScale = 12
        star.color = CIColor(red: 1, green: 0.8, blue: 0.3)
        let halo = CIFilter.lenticularHaloGenerator(); halo.center = CGPoint(x: 58, y: 58); halo.haloRadius = 36; halo.haloWidth = 18
        let sun = CIFilter.sunbeamsGenerator(); sun.center = CGPoint(x: 58, y: 58); sun.sunRadius = 14; sun.maxStriationRadius = 2
        let text = CIFilter.textImageGenerator(); text.text = "isim"; text.fontSize = 28; text.scaleFactor = 1
        let rounded = CIFilter.roundedRectangleGenerator(); rounded.extent = CGRect(x: 10, y: 20, width: 96, height: 76); rounded.radius = 18
        rounded.color = CIColor(red: 0.2, green: 0.6, blue: 1)
        let box = CGRect(x: 0, y: 0, width: 116, height: 116)
        func scaled(_ im: CIImage?) -> CIImage? {
            guard let im else { return nil }
            let s = max(1, floor(108 / max(im.extent.width, im.extent.height)))
            return im.samplingNearest().transformed(by: CGAffineTransform(scaleX: s, y: s))
        }
        let items: [(String, CIImage?, Bool)] = [
            ("QR code", scaled(qr.outputImage), true), ("Aztec", scaled(az.outputImage), true),
            ("Code 128", scaled(c128.outputImage), true), ("PDF417", scaled(pdf.outputImage), true),
            ("Checkerboard", check.outputImage?.cropped(to: box), false), ("Linear", lin.outputImage?.cropped(to: box), false),
            ("Radial", rad.outputImage?.cropped(to: box), false),
            ("Star shine", star.outputImage?.composited(over: CIImage.black).cropped(to: box), false),
            ("Halo", halo.outputImage?.composited(over: CIImage.black).cropped(to: box), false),
            ("Sunbeams", sun.outputImage?.composited(over: CIImage.black).cropped(to: box), false),
            ("Text", text.outputImage, false), ("Rounded rect", rounded.outputImage?.cropped(to: box), false),
        ]
        for (i, it) in items.enumerated() { tile(it.1, it.0, i, nearest: it.2) }
        print("ci generators qr \(ext(qr.outputImage!.extent)) aztec \(ext(az.outputImage!.extent)) code128 \(ext(c128.outputImage!.extent)) pdf417 \(pdf.outputImage.map { ext($0.extent) } ?? "nil")")
    }

    func kernels() {
        var items: [(String, CIImage?)] = []
        let kl = CIColorKernel(source: "kernel vec4 swapRB(__sample s) { return s.bgra; }")
        items.append(("CIKL color", kl?.apply(extent: face.extent, arguments: [face])))
        let lib = try? Data(contentsOf: bundle.url(forResource: "default", withExtension: "metallib")!)
        let tint = lib.flatMap { try? CIColorKernel(functionName: "magentaTint", fromMetalLibraryData: $0) }
        items.append(("Metal color", tint?.apply(extent: face.extent, arguments: [face, 0.7])))
        let ripple = lib.flatMap { try? CIWarpKernel(functionName: "ripple", fromMetalLibraryData: $0) }
        items.append(("Metal warp", ripple?.apply(extent: face.extent, roiCallback: { _, r in r.insetBy(dx: -12, dy: 0) }, image: face.clampedToExtent(), arguments: [10, 9])))
        let blend = CIBlendKernel.multiply.apply(foreground: halves.transformed(by: CGAffineTransform(scaleX: 4, y: 4)), background: face)
        items.append(("Blend kernel", blend))
        items.append(("Processor", try? InvertProcessor.apply(withExtent: face.extent, inputs: [face], arguments: nil)))
        // faces: boxes drawn over the photo
        var boxes = face
        let det = CIDetector(ofType: CIDetectorTypeFace, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        for f in det?.features(in: face) ?? [] {
            let r = f.bounds
            let frame = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: r.insetBy(dx: -2, dy: -2))
            let hole = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: r)
            boxes = face.cropped(to: r).composited(over: hole.composited(over: frame)).composited(over: boxes)
        }
        items.append(("Faces", boxes))
        items.append(("Saliency", face.applyingFilter("CISaliencyMapFilter")))
        let palette = face.applyingFilter("CIKMeans", parameters: [kCIInputExtentKey: CIVector(cgRect: face.extent), "inputCount": 6, "inputPasses": 4])
            .settingAlphaOne(in: CGRect(x: 0, y: 0, width: 6, height: 1))
        items.append(("Palettize", face.applyingFilter("CIPalettize", parameters: ["inputPaletteImage": palette, "inputPerceptual": true])))
        let hist = face.applyingFilter("CIAreaHistogram", parameters: [kCIInputExtentKey: CIVector(cgRect: face.extent), "inputCount": 64, kCIInputScaleKey: 12])
            .applyingFilter("CIHistogramDisplayFilter", parameters: ["inputHeight": 100, "inputHighLimit": 1, "inputLowLimit": 0])
        items.append(("Histogram", hist))
        let curl = CIFilter.pageCurlTransition(); curl.inputImage = face; curl.targetImage = face.applyingFilter("CIPhotoEffectNoir")
        curl.extent = face.extent; curl.time = 0.45; curl.angle = 0.9; curl.radius = 60
        items.append(("Page curl", curl.outputImage))
        if let raw = CIRAWFilter(imageURL: bundle.url(forResource: "fixture", withExtension: "dng")!) {
            items.append(("RAW (DNG)", raw.outputImage?.samplingNearest()))
        } else { items.append(("RAW (DNG)", nil)) }
        items.append(("Depth of field", face.applyingFilter("CIDepthOfField", parameters: ["inputPoint0": CIVector(x: 0, y: 150), "inputPoint1": CIVector(x: 256, y: 150),
                                                                                          "inputRadius": 8, "inputUnsharpMaskRadius": 2])))
        for (i, it) in items.enumerated() { tile(it.1?.cropped(to: CGRect(x: 0, y: 0, width: 300, height: 300)), it.0, i) }
        print("ci kernels page tiles \(items.filter { $0.1 != nil }.count)/\(items.count)")
    }
}

/// a CIImageProcessorKernel: inverts the colors of its input (premultiplied RGBA float)
final class InvertProcessor: CIImageProcessorKernel {
    override class var outputFormat: CIFormat { .RGBAf }
    override class func formatForInput(at input: Int32) -> CIFormat { .RGBAf }
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String: Any]?, output: CIImageProcessorOutput) throws {
        guard let input = inputs?.first else { return }
        let w = Int(output.region.width), h = Int(output.region.height)
        let ox = Int(output.region.minX - input.region.minX), oy = Int(input.region.maxY - output.region.maxY)
        for y in 0..<h {
            let src = (input.baseAddress + (y + oy) * input.bytesPerRow).assumingMemoryBound(to: Float.self) + ox * 4
            let dst = (output.baseAddress + y * output.bytesPerRow).assumingMemoryBound(to: Float.self)
            for x in 0..<w {
                let a = src[x * 4 + 3]
                for c in 0..<3 { dst[x * 4 + c] = a - src[x * 4 + c] }
                dst[x * 4 + 3] = a
            }
        }
    }
}

/// a CIFilter subclass made by an app, registered under a name
final class PosterGlow: CIFilter {
    @objc dynamic var inputImage: CIImage?
    @objc dynamic var inputLevels: NSNumber = 4
    override var outputImage: CIImage? {
        inputImage?.applyingFilter("CIColorPosterize", parameters: ["inputLevels": inputLevels]).applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 4])
    }
    override var attributes: [String: Any] {
        [kCIAttributeFilterDisplayName: "Poster Glow", kCIAttributeFilterCategories: [kCICategoryStylize, kCICategoryStillImage],
         "inputImage": [kCIAttributeClass: "CIImage", kCIAttributeType: kCIAttributeTypeImage],
         "inputLevels": [kCIAttributeClass: "NSNumber", kCIAttributeDefault: 4, kCIAttributeMin: 2, kCIAttributeMax: 30, kCIAttributeType: kCIAttributeTypeScalar]]
    }
}
final class PosterGlowConstructor: NSObject, CIFilterConstructor {
    func filter(withName name: String) -> CIFilter? { name == "PosterGlow" ? PosterGlow() : nil }
}

struct Checks {
    func run() {
        registry()
        allFilters()
        colorManagement()
        formats()
        outputs()
        imageAPI()
        builtins()
        kernelChecks()
        accumulator()
        detectors()
        barcodes()
        xmp()
        raw()
        pixelBuffers()
        print("ci checks done")
    }

    func registry() {
        let all = CIFilter.filterNames(inCategory: nil)
        let blur = CIFilter.filterNames(inCategory: kCICategoryBlur)
        let attrs = CIFilter(name: "CIGaussianBlur")!.attributes
        let radius = attrs[kCIInputRadiusKey] as! [String: Any]
        log("registry count \(all.count) blur \(blur.count) gaussian display \(attrs[kCIAttributeFilterDisplayName]!) radius default \(radius[kCIAttributeDefault]!) min \(radius[kCIAttributeSliderMin]!) max \(radius[kCIAttributeSliderMax]!) type \(radius[kCIAttributeType]!)")
        log("registry localized \(CIFilter.localizedName(forFilterName: "CISepiaTone") ?? "nil") keys \(CIFilter(name: "CISepiaTone")!.inputKeys) \(CIFilter(name: "CISepiaTone")!.outputKeys)")
        CIFilter.registerName("PosterGlow", constructor: PosterGlowConstructor(), classAttributes: [kCIAttributeFilterCategories: [kCICategoryStylize]])
        let pg = CIFilter(name: "PosterGlow")
        pg?.setValue(face, forKey: kCIInputImageKey)
        let out = pg?.outputImage
        log("custom filter \(pg != nil) stylize \(CIFilter.filterNames(inCategory: kCICategoryStylize).contains("PosterGlow")) output \(out.map { ext($0.extent) } ?? "nil") keys \(pg?.inputKeys ?? [])")
    }

    /// every built-in filter with inputs set: rendered (32x32 of its output), nil, or failed
    func allFilters() {
        let image = face, small = face.transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
        var rendered = 0, nilOut: [String] = []
        for name in CIFilter.filterNames(inCategory: nil) {
            guard let f = CIFilter(name: name) else { nilOut.append(name + "(create)"); continue }
            let attrs = f.attributes
            for key in f.inputKeys {
                guard let a = attrs[key] as? [String: Any], let cls = a[kCIAttributeClass] as? String else { continue }
                switch cls {
                case "CIImage": f.setValue(key == kCIInputImageKey ? image : small.applyingFilter("CIColorInvert"), forKey: key)
                case "NSData" where key == "inputMessage": f.setValue(Data("isim 123".utf8), forKey: key)
                case "NSString" where key == "inputText": f.setValue("isim", forKey: key)
                case "NSAttributedString": f.setValue(NSAttributedString(string: "isim"), forKey: key)
                case "CIBarcodeDescriptor": f.setValue(qrDescriptor, forKey: key)
                default: break
                }
            }
            guard var out = f.outputImage else { nilOut.append(name); continue }
            if out.extent.isEmpty { nilOut.append(name + "(empty)"); continue }
            let r = out.extent.isInfinite ? CGRect(x: 0, y: 0, width: 32, height: 32)
                : CGRect(x: out.extent.minX, y: out.extent.minY, width: min(32, out.extent.width), height: min(32, out.extent.height))
            out = out.cropped(to: r)
            if context.createCGImage(out, from: r) != nil { rendered += 1 } else { nilOut.append(name + "(render)") }
        }
        log("all filters rendered \(rendered) nil \(nilOut.sorted())")
    }

    func colorManagement() {
        let gray = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let raw = CIContext(options: [.workingColorSpace: NSNull()])
        let p3 = CIContext(options: [.outputColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!])
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        var p3px = [UInt8](repeating: 0, count: 4)
        p3.render(red, toBitmap: &p3px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!)
        let darker = gray.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -1])
        log("cm gray srgb \(px(gray, 1, 1)) linear \(pxf(gray, 1, 1)) unmanaged \(px(gray, 1, 1, raw)) p3 red \(p3px.map { Int($0) }) ev-1 \(px(darker, 1, 1)) ev-1 unmanaged \(px(darker, 1, 1, raw))")
        let lin = gray.matchedToWorkingSpace(from: linear)!
        log("cm matched \(px(lin, 1, 1)) working \(context.workingColorSpace.map { ($0.name ?? "" as CFString) as String } ?? "nil") format \(context.workingFormat == .RGBAh)")
    }

    func formats() {
        let c = CIImage(color: CIColor(red: 1, green: 0.5, blue: 0.25, alpha: 1)).cropped(to: CGRect(x: 0, y: 0, width: 2, height: 2))
        func bytes(_ f: CIFormat, _ n: Int) -> [Int] {
            var b = [UInt8](repeating: 0, count: n)
            context.render(c, toBitmap: &b, rowBytes: n, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: f, colorSpace: sRGB)
            return b.map { Int($0) }
        }
        var h = [UInt16](repeating: 0, count: 4)
        context.render(c, toBitmap: &h, rowBytes: 8, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA16, colorSpace: sRGB)
        log("formats rgba8 \(bytes(.RGBA8, 4)) bgra8 \(bytes(.BGRA8, 4)) argb8 \(bytes(.ARGB8, 4)) abgr8 \(bytes(.ABGR8, 4)) r8 \(bytes(.R8, 1)) l8 \(bytes(.L8, 1)) rgba16 \(h.map { Int($0) })")
        let data = Data([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255])
        let bm = CIImage(bitmapData: data, bytesPerRow: 8, size: CGSize(width: 2, height: 2), format: .RGBA8, colorSpace: sRGB)
        log("bitmap top-left \(px(bm, 0, 1)) bottom-right \(px(bm, 1, 0))")
    }

    func outputs() {
        let cg = context.createCGImage(face, from: face.extent)!
        let crop = context.createCGImage(face, from: CGRect(x: 10, y: 20, width: 100, height: 50), format: .RGBA8, colorSpace: sRGB)!
        let png = context.pngRepresentation(of: face, format: .RGBA8, colorSpace: sRGB, options: [:])
        let jpg = context.jpegRepresentation(of: face, colorSpace: sRGB, options: [:])
        let tiff = context.tiffRepresentation(of: face, format: .RGBA8, colorSpace: sRGB, options: [:])
        let exr = try? context.openEXRRepresentation(of: face, options: [:])
        let heif = context.heifRepresentation(of: face, format: .RGBA8, colorSpace: sRGB, options: [:])
        func head(_ d: Data?) -> String { d.map { $0.prefix(4).map { String(format: "%02x", $0) }.joined() } ?? "nil" }
        log("outputs cg \(cg.width)x\(cg.height) crop \(crop.width)x\(crop.height) png \(head(png)) jpeg \(head(jpg)) tiff \(head(tiff)) exr \(head(exr)) heif \(heif != nil)")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ci-roundtrip.png")
        try? context.writePNGRepresentation(of: halves, to: url, format: .RGBA8, colorSpace: sRGB, options: [:])
        let back = CIImage(contentsOf: url)
        let t = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ci-roundtrip.tiff")
        try? context.writeTIFFRepresentation(of: halves, to: t, format: .RGBA8, colorSpace: sRGB, options: [:])
        log("roundtrip png \(back.map { ext($0.extent) } ?? "nil") \(back.map { px($0, 4, 4) } ?? []) \(back.map { px($0, 60, 4) } ?? []) tiff \(CIImage(contentsOf: t).map { px($0, 60, 60) } ?? [])")
        let ui = UIImage(ciImage: halves)
        let r = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { _ in ui.draw(in: CGRect(x: 0, y: 0, width: 64, height: 64)) }
        let fromUI = CIImage(image: UIImage(cgImage: context.createCGImage(halves, from: halves.extent)!))
        let uiColor = CIColor(color: UIColor(red: 1, green: 0.5, blue: 0, alpha: 1))
        log("uikit image \(fromUI.map { ext($0.extent) } ?? "nil") \(fromUI.map { px($0, 60, 4) } ?? []) same \(CIImage(image: ui) === halves) color \(uiColor.red) \(uiColor.green) \(uiColor.blue)")
        log("uiimage ciImage \(ui.ciImage != nil) size \(Int(ui.size.width))x\(Int(ui.size.height)) drawn \(r.cgImage.map { CIImage(cgImage: $0) }.map { px($0, 2, 2) } ?? [])")
    }

    func imageAPI() {
        let c = halves
        log("image extent \(ext(c.extent)) cropped \(ext(c.cropped(to: CGRect(x: 10.5, y: 0, width: 20, height: 20)).extent)) clamped \(ext(c.clampedToExtent().extent)) clamped edge \(px(c.clampedToExtent(), -50, 10))")
        log("image transformed \(ext(c.transformed(by: CGAffineTransform(translationX: 10, y: 5).scaledBy(x: 2, y: 2)).extent)) oriented right \(ext(face.cropped(to: CGRect(x: 0, y: 0, width: 256, height: 100)).oriented(.right).extent)) color infinite \(CIImage(color: .red).extent.isInfinite) empty \(CIImage.empty().extent.isEmpty)")
        let blur = c.clampedToExtent().applyingGaussianBlur(sigma: 4).cropped(to: c.extent)
        let alpha = CIImage(color: CIColor(red: 1, green: 0, blue: 0, alpha: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        log("image blur mid \(px(blur, 32, 32)) alpha \(px(alpha, 1, 1)) alpha one \(px(alpha.settingAlphaOne(in: alpha.extent), 1, 1)) over white \(px(alpha.composited(over: CIImage.white), 1, 1))")
        let scaled = c.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        log("image sampling linear \(px(scaled, 127, 100)) nearest \(px(c.samplingNearest().transformed(by: CGAffineTransform(scaleX: 4, y: 4)), 127, 100)) intermediate \(px(c.insertingIntermediate(), 10, 10))")
        let auto = face.autoAdjustmentFilters(options: [CIImageAutoAdjustmentOption.redEye: false])
        log("image auto adjust \(auto.map { $0.name }) properties \(face.properties.count > 0) url \(face.url?.lastPathComponent ?? "nil")")
    }

    func builtins() {
        let sepia = CIFilter.sepiaTone(); sepia.inputImage = halves; sepia.intensity = 1
        let blur = CIFilter.gaussianBlur(); blur.inputImage = halves.clampedToExtent(); blur.radius = 6
        let avg = CIFilter.areaAverage(); avg.inputImage = halves; avg.extent = halves.extent
        let controls = CIFilter.colorControls(); controls.inputImage = halves; controls.saturation = 0; controls.brightness = 0.1
        let matrix = CIFilter.colorMatrix(); matrix.inputImage = halves
        matrix.rVector = CIVector(x: 0, y: 0, z: 1, w: 0); matrix.bVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        log("builtins sepia \(px(sepia.outputImage!, 4, 4)) blur edge \(px(blur.outputImage!, 32, 32)) average \(px(avg.outputImage!, 0, 0)) \(ext(avg.outputImage!.extent)) controls \(px(controls.outputImage!, 4, 4)) matrix \(px(matrix.outputImage!, 4, 4))")
        let mm = CIFilter.areaMinMaxRed(); mm.inputImage = face; mm.extent = face.extent
        let hist = CIFilter.areaHistogram(); hist.inputImage = halves; hist.extent = halves.extent; hist.count = 4; hist.scale = 1
        log("builtins minmax \(ext(mm.outputImage!.extent)) histogram \(ext(hist.outputImage!.extent)) bins \((0..<4).map { pxf(hist.outputImage!, CGFloat($0), 0, nil) })")
        let km = CIFilter.kMeans(); km.inputImage = halves; km.extent = halves.extent; km.count = 2; km.passes = 5
        let colors = (0..<2).map { px(km.outputImage!.settingAlphaOne(in: km.outputImage!.extent), CGFloat($0), 0) }.sorted { $0[0] > $1[0] }
        log("builtins kmeans \(colors)")
    }

    func kernelChecks() {
        let swap = CIColorKernel(source: "kernel vec4 swapRB(__sample s) { return s.bgra; }")!
        let mirror = CIWarpKernel(source: "kernel vec2 mirror(float w) { vec2 d = destCoord(); return vec2(w - d.x, d.y); }")!
        let general = CIKernel(source: "kernel vec4 shift(sampler s) { return sample(s, samplerTransform(s, destCoord() + vec2(16.0, 0.0))); }")!
        log("kernel cikl swap \(px(swap.apply(extent: halves.extent, arguments: [halves])!, 4, 4)) mirror \(px(mirror.apply(extent: halves.extent, roiCallback: { _, r in CGRect(x: 64 - r.maxX, y: r.minY, width: r.width, height: r.height) }, image: halves, arguments: [64])!, 4, 4)) general \(px(general.apply(extent: halves.extent, roiCallback: { _, r in r.offsetBy(dx: 16, dy: 0) }, arguments: [halves])!, 20, 4)) names \(swap.name) \(mirror.name)")
        let lib = try! Data(contentsOf: bundle.url(forResource: "default", withExtension: "metallib")!)
        let names = CIKernel.kernelNames(fromMetalLibraryData: lib)
        let tint = try? CIColorKernel(functionName: "magentaTint", fromMetalLibraryData: lib)
        let ripple = try? CIWarpKernel(functionName: "ripple", fromMetalLibraryData: lib)
        let smear = try? CIKernel(functionName: "smear", fromMetalLibraryData: lib)
        let white = CIImage.white.cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        log("kernel metallib names \(names.sorted()) tint \(tint.flatMap { $0.apply(extent: white.extent, arguments: [white, 0.5]) }.map { px($0, 2, 2) } ?? []) ripple \(ripple.flatMap { $0.apply(extent: halves.extent, roiCallback: { _, r in r.insetBy(dx: -8, dy: 0) }, image: halves, arguments: [8, 1000]) }.map { px($0, 26, 2) } ?? []) smear \(smear.flatMap { $0.apply(extent: halves.extent, roiCallback: { _, r in r.insetBy(dx: -4, dy: 0) }, arguments: [halves]) }.map { px($0, 30, 2) } ?? [])")
        let appleBinary = try? CIColorKernel(functionName: "x", fromMetalLibraryData: Data("MTLB\u{0}\u{0}\u{0}\u{0}".utf8))
        if #available(iOS 18.0, *) {
            let k = try? CIKernel.kernels(withMetalString: """
                #include <CoreImage/CoreImage.h>
                extern "C" { namespace coreimage { float4 halfGreen(sample_t s) { return float4(s.r, s.g * 0.5, s.b, s.a); } } }
                """)
            log("kernel metal string \(k?.count ?? -1) \((k?.first as? CIColorKernel).flatMap { $0.apply(extent: white.extent, arguments: [white]) }.map { px($0, 1, 1) } ?? []) apple binary \(appleBinary == nil ? "rejected" : "accepted")")
        } else {
            log("kernel metal string unavailable apple binary \(appleBinary == nil ? "rejected" : "accepted")")
        }
        let blend = CIBlendKernel.screen.apply(foreground: halves, background: CIImage(color: CIColor(red: 0, green: 0.5, blue: 0)).cropped(to: halves.extent))!
        let custom = CIBlendKernel(source: "kernel vec4 avg(__sample f, __sample b) { return (f + b) * 0.5; }")!
        log("kernel blend screen \(px(blend, 4, 4)) custom \(px(custom.apply(foreground: halves, background: CIImage.white.cropped(to: halves.extent))!, 60, 4))")
        let inv = try? InvertProcessor.apply(withExtent: halves.extent, inputs: [halves], arguments: nil)
        log("kernel processor \(inv.map { px($0, 4, 4) } ?? []) \(inv.map { px($0, 60, 60) } ?? [])")
    }

    func accumulator() {
        let acc = CIImageAccumulator(extent: CGRect(x: 0, y: 0, width: 16, height: 16), format: .RGBA8)!
        acc.setImage(CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: acc.extent))
        acc.setImage(CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 16)), dirtyRect: CGRect(x: 0, y: 0, width: 8, height: 16))
        let first = acc.image()
        acc.setImage(acc.image().applyingFilter("CIColorInvert"))
        log("accumulator \(px(first, 2, 2)) \(px(first, 12, 2)) inverted \(px(acc.image(), 2, 2)) first unchanged \(px(first, 2, 2))")
    }

    func detectors() {
        let faces = CIDetector(ofType: CIDetectorTypeFace, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let found = faces.features(in: face, options: [CIDetectorEyeBlink: true, CIDetectorSmile: true]) as! [CIFaceFeature]
        if let f = found.first {
            log("detect faces \(found.count) bounds \(ext(f.bounds.integral)) eyes \(f.hasLeftEyePosition) \(f.hasRightEyePosition) left eye on the left \(f.leftEyePosition.x < f.rightEyePosition.x) mouth \(f.hasMouthPosition) below \(f.mouthPosition.y < f.leftEyePosition.y) angle \(f.hasFaceAngle)")
        } else { log("detect faces 0") }
        // a black quadrilateral on white
        let r = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 160), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 200, height: 160))
            let p = UIBezierPath(); p.move(to: CGPoint(x: 40, y: 30)); p.addLine(to: CGPoint(x: 170, y: 40)); p.addLine(to: CGPoint(x: 160, y: 130)); p.addLine(to: CGPoint(x: 30, y: 120)); p.close()
            UIColor.black.setFill(); p.fill()
        }
        let rects = CIDetector(ofType: CIDetectorTypeRectangle, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorAspectRatio: 1.4])!
        if let q = rects.features(in: CIImage(cgImage: r.cgImage!)).first as? CIRectangleFeature {
            func pt(_ p: CGPoint) -> String { "(\(Int(p.x.rounded())),\(Int(p.y.rounded())))" }
            log("detect rectangle tl \(pt(q.topLeft)) tr \(pt(q.topRight)) br \(pt(q.bottomRight)) bl \(pt(q.bottomLeft))")
        } else { log("detect rectangle none") }
        let qr = CIFilter.qrCodeGenerator(); qr.message = Data("hello isim".utf8)
        let qrImage = qr.outputImage!.samplingNearest().transformed(by: CGAffineTransform(scaleX: 8, y: 8)).composited(over: CIImage.white).cropped(to: CGRect(x: -40, y: -40, width: 300, height: 300))
        let qrs = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: nil)!.features(in: qrImage) as! [CIQRCodeFeature]
        let d = qrs.first?.symbolDescriptor
        log("detect qr \(qrs.count) message \(qrs.first?.messageString ?? "nil") version \(d?.symbolVersion ?? 0) level \(d?.errorCorrectionLevel.rawValue ?? 0) payload \(d?.errorCorrectedPayload.count ?? 0)")
        let text = CIFilter.textImageGenerator(); text.text = "HELLO ISIM"; text.fontSize = 40; text.scaleFactor = 2
        let textImage = text.outputImage!.composited(over: CIImage.white).cropped(to: text.outputImage!.extent.insetBy(dx: -30, dy: -30))
        let texts = CIDetector(ofType: CIDetectorTypeText, context: context, options: nil)!.features(in: textImage, options: [CIDetectorReturnSubFeatures: true]) as! [CITextFeature]
        log("detect text \(texts.count) subfeatures \(texts.first?.subFeatures?.count ?? 0)")
    }

    func barcodes() {
        let qr = qrDescriptor.flatMap { CIQRCodeDescriptor(payload: $0.errorCorrectedPayload, symbolVersion: $0.symbolVersion, maskPattern: 5, errorCorrectionLevel: $0.errorCorrectionLevel) }
        let bad = CIQRCodeDescriptor(payload: Data([1, 2, 3]), symbolVersion: 1, maskPattern: 2, errorCorrectionLevel: .levelL)
        let gen = CIFilter.barcodeGenerator(); gen.barcodeDescriptor = qr!
        let az = CIAztecCodeDescriptor(payload: Data([0x12, 0x34, 0x56, 0x78, 0x9a]), isCompact: true, layerCount: 1, dataCodewordCount: 2)
        let azImage: CIImage? = az.flatMap { a in let g = CIFilter.barcodeGenerator(); g.barcodeDescriptor = a; return g.outputImage }
        let archived = try? NSKeyedArchiver.archivedData(withRootObject: qr!, requiringSecureCoding: true)
        let restored = archived.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CIQRCodeDescriptor.self, from: $0) }
        log("barcodes qr descriptor \(qr != nil) invalid \(bad == nil) generated \(gen.outputImage.map { ext($0.extent) } ?? "nil") aztec \(azImage.map { ext($0.extent) } ?? "nil") coding \(restored?.symbolVersion ?? 0) \(restored?.maskPattern ?? 0)")
        let pdf = CIFilter.pdf417BarcodeGenerator(); pdf.message = Data("isim".utf8); pdf.compactStyle = 0
        let c128 = CIFilter.code128BarcodeGenerator(); c128.message = Data("isim".utf8); c128.quietSpace = 7; c128.barcodeHeight = 20
        let azg = CIFilter.aztecCodeGenerator(); azg.message = Data("isim".utf8); azg.correctionLevel = 33
        log("barcodes code128 \(ext(c128.outputImage!.extent)) aztec \(ext(azg.outputImage!.extent)) pdf417 \(pdf.outputImage.map { ext($0.extent) } ?? "nil")")
    }

    func xmp() {
        let sepia = CIFilter(name: "CISepiaTone", parameters: [kCIInputIntensityKey: 0.7])!
        let straighten = CIFilter(name: "CIStraightenFilter", parameters: [kCIInputAngleKey: 0.1])!
        let data = CIFilter.serializedXMP(from: [sepia, straighten], inputImageExtent: face.extent)
        let back = data.map { CIFilter.filterArray(fromSerializedXMP: $0, inputImageExtent: face.extent, error: nil) } ?? []
        log("xmp bytes \(data != nil) back \(back.map { $0.name }) intensity \((back.first?.value(forKey: kCIInputIntensityKey) as? Double).map(f3) ?? "nil")")
    }

    func raw() {
        guard let url = bundle.url(forResource: "fixture", withExtension: "dng"), let f = CIRAWFilter(imageURL: url) else { log("raw unavailable"); return }
        let out = f.outputImage!
        let tiff = f.properties["{TIFF}"] as? [String: Any] ?? [:], exif = f.properties["{Exif}"] as? [String: Any] ?? [:]
        log("raw size \(Int(f.nativeSize.width))x\(Int(f.nativeSize.height)) extent \(ext(out.extent)) make \(tiff["Make"] ?? "") model \(tiff["Model"] ?? "") exposure \((exif["ExposureTime"] as? Double).map(f3) ?? "") fnumber \((exif["FNumber"] as? Double).map(f1) ?? "") decoders \(f.supportedDecoderVersions.map { $0.rawValue }) cameras \(CIRAWFilter.supportedCameraModels.count > 100)")
        let white = px(out, 6, 58), bar = px(out, 70, 56)
        log("raw temperature \(Int(f.neutralTemperature / 100) * 100) tint \(Int(f.neutralTint.rounded())) white \(white) red bar \(bar) supports nr \(f.isLuminanceNoiseReductionSupported) lens \(f.isLensCorrectionSupported)")
        f.exposure = 1
        let bright = px(f.outputImage!, 30, 30)
        f.exposure = 0
        let base = px(f.outputImage!, 30, 30)
        f.neutralTemperature = 3500
        let cool = px(f.outputImage!, 6, 58)
        f.neutralTemperature = 8000
        let warm = px(f.outputImage!, 6, 58)
        f.neutralLocation = CGPoint(x: 6, y: 58)
        log("raw exposure \(base) +1 \(bright) cool \(cool) warm \(warm) neutral location \(Int(f.neutralTemperature / 100) * 100)")
        f.scaleFactor = 0.5
        let half = f.outputImage!.extent
        f.scaleFactor = 1; f.isDraftModeEnabled = true
        let draft = f.outputImage!.extent
        f.isDraftModeEnabled = false; f.orientation = .right
        log("raw scaled \(ext(half)) draft \(ext(draft)) oriented \(ext(f.outputImage!.extent)) preview \(f.previewImage.map { ext($0.extent) } ?? "nil")")
        let old = CIFilter(imageURL: url, options: [.allowDraftMode: false, CIRAWFilterOption(rawValue: kCIInputEVKey): 0.5])
        log("raw deprecated \(old != nil) native \((old?.value(forKey: CIRAWFilterOption.outputNativeSize.rawValue) as? CIVector).map { "\(Int($0.x))x\(Int($0.y))" } ?? "nil") ev \(old?.value(forKey: kCIInputEVKey) ?? "nil") output \(old?.outputImage.map { ext($0.extent) } ?? "nil")")
    }

    func pixelBuffers() {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &pb)
        let buf = pb!
        context.render(halves, to: buf)
        let base = CVPixelBufferGetBaseAddress(buf)!.assumingMemoryBound(to: UInt8.self)
        let img = CIImage(cvPixelBuffer: buf)
        log("pixelbuffer bgra \(Array(UnsafeBufferPointer(start: base, count: 4)).map { Int($0) }) back \(px(img, 4, 4)) \(px(img, 60, 4)) same \(img.pixelBuffer === buf)")
        var yuv: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, &yuv)
        let dst = CIRenderDestination(pixelBuffer: yuv!)
        let task = try? context.startTask(toRender: halves, to: dst)
        _ = try? task?.waitUntilCompleted()
        let y = CVPixelBufferGetBaseAddressOfPlane(yuv!, 0)!.assumingMemoryBound(to: UInt8.self)
        let back = CIImage(cvPixelBuffer: yuv!)
        log("pixelbuffer 420f luma \(y[0]) \(y[63]) back \(px(back, 4, 4)) \(px(back, 60, 4))")
        var depth: CVPixelBuffer?
        CVPixelBufferCreate(nil, 8, 8, kCVPixelFormatType_DepthFloat32, nil, &depth)
        let dp = CVPixelBufferGetBaseAddress(depth!)!.assumingMemoryBound(to: Float.self)
        for i in 0..<(CVPixelBufferGetBytesPerRow(depth!) / 4 * 8) { dp[i] = 0.25 }
        log("pixelbuffer depth \(pxf(CIImage(cvPixelBuffer: depth!), 2, 2, nil))")
    }
}
