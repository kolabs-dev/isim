// Sample: ImageIO, Core Image and UIImage extras on isim — CGImageSource (types, frames, GIF delays, EXIF orientation,
// thumbnails), CGImageDestination (PNG/JPEG/animated GIF), Core Image filters rendered by CIContext (sepia, blur,
// color controls, invert, photo effects, compositing, QR code), animated images in UIImageView, resizable
// (nine-slice) images, flipped and rotated image orientations.
import UIKit
import ImageIO
import CoreImage
import CoreImage.CIFilterBuiltins

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ImagingViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// A JPEG (8x4, left half blue, right half red) whose EXIF orientation is 6 (rotate 90° clockwise to show).
let orientedJPEG = Data(base64Encoded: "/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABgAAAAAAAAD/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAAEAAgDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACP/EABgQAAIDAAAAAAAAAAAAAAAAAAAHRYPC/8QAFQEBAQAAAAAAAAAAAAAAAAAABwj/xAAYEQACAwAAAAAAAAAAAAAAAAAACEWDw//aAAwDAQACEQMRAD8AGyplatjgzcPfiUavErTqf//Z")!

/// A solid-color CGImage drawn with Core Graphics.
func solid(_ color: UIColor, _ w: Int = 40, _ h: Int = 40) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(color.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}
/// RGBA of a CGImage pixel (x, y from the top left), read through a bitmap context.
func rgba(_ image: CGImage, _ x: Int, _ y: Int) -> [Int] {
    let w = image.width, h = image.height
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self).advanced(by: y * w * 4 + x * 4)
    return [Int(p[0]), Int(p[1]), Int(p[2]), Int(p[3])]
}

final class ImagingViewController: UIViewController {
    let ci = CIContext()
    func tile(_ image: UIImage?, _ id: String, _ frame: CGRect, nearest: Bool = false) -> UIImageView {
        let v = UIImageView(image: image)
        v.frame = frame
        v.accessibilityIdentifier = id
        if nearest { v.layer.magnificationFilter = .nearest }
        view.addSubview(v)
        return v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let title = UILabel(frame: CGRect(x: 16, y: 54, width: 360, height: 14))
        title.text = "ImageIO · Core Image · UIImage"; title.font = .systemFont(ofSize: 12)
        view.addSubview(title)
        imageIO()
        coreImage()
        uiImage()
    }

    // MARK: ImageIO
    func imageIO() {
        // an animated GIF: red, green, blue at 0.25 s, looping forever
        let gif = NSMutableData()
        let dst = CGImageDestinationCreateWithData(gif as CFMutableData, "com.compuserve.gif" as CFString, 3, nil)!
        CGImageDestinationSetProperties(dst, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for c in [UIColor.red, UIColor.green, UIColor.blue] {
            CGImageDestinationAddImage(dst, solid(c), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.25]] as CFDictionary)
        }
        print("gif finalize \(CGImageDestinationFinalize(dst)) \(String(decoding: (gif as Data).prefix(6), as: UTF8.self))")
        let src = CGImageSourceCreateWithData(gif as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 1, nil) as! [CFString: Any]
        let gifProps = props[kCGImagePropertyGIFDictionary] as! [CFString: Any]
        let loop = ((CGImageSourceCopyProperties(src, nil) as! [CFString: Any])[kCGImagePropertyGIFDictionary] as! [CFString: Any])[kCGImagePropertyGIFLoopCount] as! Int
        var frames: [UIImage] = []
        for i in 0..<CGImageSourceGetCount(src) { frames.append(UIImage(cgImage: CGImageSourceCreateImageAtIndex(src, i, nil)!)) }
        print("gif type \(CGImageSourceGetType(src)! as String) count \(CGImageSourceGetCount(src)) size \(props[kCGImagePropertyPixelWidth]!)x\(props[kCGImagePropertyPixelHeight]!) delay \(gifProps[kCGImagePropertyGIFDelayTime]!) loop \(loop)")
        print("gif frame colors \(frames.map { rgba($0.cgImage!, 20, 20) })")
        let anim = UIImage.animatedImage(with: frames, duration: 0.75)!
        let animView = tile(anim, "gif", CGRect(x: 16, y: 74, width: 50, height: 50))
        print("animated image frames \(anim.images!.count) duration \(anim.duration) playing \(animView.isAnimating)")

        // PNG / JPEG round trips with properties and thumbnails
        let png = NSMutableData()
        let pd = CGImageDestinationCreateWithData(png as CFMutableData, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(pd, solid(.orange, 64, 32), nil)
        _ = CGImageDestinationFinalize(pd)
        let ps = CGImageSourceCreateWithData(png as CFData, nil)!
        let pp = CGImageSourceCopyPropertiesAtIndex(ps, 0, nil) as! [CFString: Any]
        let thumb = CGImageSourceCreateThumbnailAtIndex(ps, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 16] as CFDictionary)!
        print("png type \(CGImageSourceGetType(ps)! as String) \(pp[kCGImagePropertyPixelWidth]!)x\(pp[kCGImagePropertyPixelHeight]!) alpha \(pp[kCGImagePropertyHasAlpha]!) thumb \(thumb.width)x\(thumb.height)")
        let jpg = NSMutableData()
        let jd = CGImageDestinationCreateWithData(jpg as CFMutableData, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(jd, solid(.purple), [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        _ = CGImageDestinationFinalize(jd)
        let jimg = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(jpg as CFData, nil)!, 0, nil)!
        print("jpeg \(jpg.length > 100) type \(CGImageSourceGetType(CGImageSourceCreateWithData(jpg as CFData, nil)!)! as String) pixel \(rgba(jimg, 20, 20))")

        // EXIF orientation: stored 8x4, shown 4x8 once the thumbnail applies the transform
        let os = CGImageSourceCreateWithData(orientedJPEG as CFData, nil)!
        let op = CGImageSourceCopyPropertiesAtIndex(os, 0, nil) as! [CFString: Any]
        let raw = CGImageSourceCreateImageAtIndex(os, 0, nil)!
        let upright = CGImageSourceCreateThumbnailAtIndex(os, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary)!
        print("exif orientation \(op[kCGImagePropertyOrientation]!) raw \(raw.width)x\(raw.height) upright \(upright.width)x\(upright.height) top \(rgba(upright, 2, 1)) bottom \(rgba(upright, 2, 6))")
        _ = tile(UIImage(cgImage: upright), "exif", CGRect(x: 76, y: 74, width: 25, height: 50), nearest: true)

        // unsupported data
        let junk = CGImageSourceCreateWithData(Data([1, 2, 3, 4]) as CFData, nil)!
        print("junk count \(CGImageSourceGetCount(junk)) status \(CGImageSourceGetStatus(junk).rawValue)")
    }

    // MARK: Core Image
    func coreImage() {
        // a 60x60 source: orange top half, teal bottom half
        let ctx = CGContext(data: nil, width: 60, height: 60, bitsPerComponent: 8, bytesPerRow: 240, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(UIColor(red: 0, green: 0.6, blue: 0.6, alpha: 1).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 30))
        ctx.setFillColor(UIColor(red: 1, green: 0.5, blue: 0, alpha: 1).cgColor); ctx.fill(CGRect(x: 0, y: 30, width: 60, height: 30))
        let input = CIImage(cgImage: ctx.makeImage()!)
        print("ciimage extent \(input.extent)")

        let sepia = CIFilter.sepiaTone(); sepia.inputImage = input; sepia.intensity = 1
        let mono = CIFilter.colorControls(); mono.inputImage = input; mono.saturation = 0
        let invert = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: input])!
        let blur = CIFilter.gaussianBlur(); blur.inputImage = input; blur.radius = 6
        let noir = CIFilter.photoEffectNoir(); noir.inputImage = input
        let outs: [(String, CIImage)] = [("sepia", sepia.outputImage!), ("mono", mono.outputImage!), ("invert", invert.outputImage!),
                                         ("blur", blur.outputImage!.cropped(to: input.extent)), ("noir", noir.outputImage!)]
        var x: CGFloat = 16
        for (name, out) in outs {
            let cg = ci.createCGImage(out, from: input.extent)!
            print("ci \(name) top \(rgba(cg, 30, 5)) bottom \(rgba(cg, 30, 55)) edge \(rgba(cg, 30, 29))")
            _ = tile(UIImage(cgImage: cg), "ci-\(name)", CGRect(x: x, y: 134, width: 60, height: 60))
            x += 66
        }
        // generators and compositing: a checkerboard behind a translucent red square
        let checker = CIFilter.checkerboardGenerator()
        checker.center = .zero; checker.width = 10; checker.color0 = CIColor(red: 1, green: 1, blue: 1); checker.color1 = CIColor(red: 0.2, green: 0.2, blue: 0.2)
        let square = CIImage(color: CIColor(red: 1, green: 0, blue: 0, alpha: 0.5)).cropped(to: CGRect(x: 10, y: 10, width: 40, height: 40))
        let comp = square.composited(over: checker.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 60, height: 60)))
        let compCG = ci.createCGImage(comp, from: comp.extent)!
        print("ci composite \(compCG.width)x\(compCG.height) corner \(rgba(compCG, 5, 5)) center \(rgba(compCG, 25, 25))")
        _ = tile(UIImage(ciImage: comp), "ci-composite", CGRect(x: 16, y: 200, width: 60, height: 60))
        // a transform and a QR code
        let moved = input.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        print("ci transformed extent \(moved.extent) names \(CIFilter.filterNames(inCategory: kCICategoryBuiltIn).count) has blur \(CIFilter.filterNames(inCategory: nil).contains("CIGaussianBlur"))")
        let qr = CIFilter.qrCodeGenerator()
        qr.message = Data("https://isim.dev".utf8); qr.correctionLevel = "M"
        let code = qr.outputImage!
        print("qr extent \(code.extent)")
        let big = code.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        _ = tile(UIImage(cgImage: ci.createCGImage(code, from: code.extent)!), "qr", CGRect(x: 82, y: 200, width: code.extent.width * 4, height: code.extent.height * 4), nearest: true)
        print("qr scaled extent \(big.extent)")
    }

    // MARK: UIImage extras
    func uiImage() {
        // nine-slice: a 30x30 image with 10pt red corners, green edges and a blue center
        let r = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let nine = r.image { c in
            UIColor.green.setFill(); c.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
            UIColor.blue.setFill(); c.fill(CGRect(x: 10, y: 10, width: 10, height: 10))
            UIColor.red.setFill()
            for p in [CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 0), CGPoint(x: 0, y: 20), CGPoint(x: 20, y: 20)] { c.fill(CGRect(origin: p, size: CGSize(width: 10, height: 10))) }
        }
        let resizable = nine.resizableImage(withCapInsets: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10), resizingMode: .stretch)
        print("resizable caps \(resizable.capInsets.left) mode \(resizable.resizingMode.rawValue)")
        _ = tile(resizable, "nineslice", CGRect(x: 16, y: 340, width: 150, height: 60))

        // orientation: a 40x20 image, left half red / right half blue
        let lr = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { c in
            UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
            UIColor.blue.setFill(); c.fill(CGRect(x: 20, y: 0, width: 20, height: 20))
        }
        let flipped = lr.withHorizontallyFlippedOrientation()
        print("flipped orientation \(flipped.imageOrientation.rawValue) size \(flipped.size)")
        _ = tile(lr, "unflipped", CGRect(x: 180, y: 340, width: 40, height: 20))
        _ = tile(flipped, "flipped", CGRect(x: 180, y: 370, width: 40, height: 20))
        let rotated = UIImage(cgImage: lr.cgImage!, scale: 1, orientation: .right)
        print("rotated orientation \(rotated.imageOrientation.rawValue) size \(rotated.size)")
        _ = tile(rotated, "rotated", CGRect(x: 230, y: 340, width: 20, height: 40))

        // UIImageView.animationImages: three frames over 0.6 s, repeated twice
        let av = tile(nil, "frames", CGRect(x: 270, y: 340, width: 40, height: 40))
        av.animationImages = [UIImage(cgImage: solid(.systemYellow)), UIImage(cgImage: solid(.systemPurple)), UIImage(cgImage: solid(.systemTeal))]
        av.animationDuration = 0.6
        av.animationRepeatCount = 0
        av.startAnimating()
        print("animationImages \(av.animationImages!.count) animating \(av.isAnimating)")
    }
}
