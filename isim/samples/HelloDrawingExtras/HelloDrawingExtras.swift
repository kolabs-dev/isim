// Sample: the drawing APIs of #9 part 10, each logged with "dx".
// - UIImage: alignment insets, baselines, thumbnails and preparing for display, the standard images, HDR members,
//   renderer formats, pattern drawing, symbol configuration variants, UIImageReader, NSDataAsset (a data set)
// - UIColor: pattern colours (a view's background tiles the image), hue / saturation / brightness, Core Image colours,
//   accessibility names, prominence, the iOS 26 HDR members, UIColorEffect; UIFont's extra large titles
// - Printing: UIPrintError codes, rendering quality, formatters, printer destinations, PDF destinations
import UIKit
import CoreImage

func log(_ s: String) { print("dx \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: DrawingViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

/// an 8x8 checkerboard of 4x4 squares: a at the top left, b at the top right
func checker(_ a: UIColor, _ b: UIColor) -> UIImage {
    let f = UIGraphicsImageRendererFormat(); f.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: f).image { c in
        a.setFill(); c.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        b.setFill(); c.fill(CGRect(x: 4, y: 0, width: 4, height: 4)); c.fill(CGRect(x: 0, y: 4, width: 4, height: 4))
    }
}
/// the RGBA bytes of one pixel
func pixel(_ image: UIImage, _ x: Int, _ y: Int) -> String {
    guard let cg = image.cgImage, let data = cg.dataProvider?.data, let p = CFDataGetBytePtr(data) else { return "none" }
    let o = y * cg.bytesPerRow + x * 4
    return "\(p[o]),\(p[o + 1]),\(p[o + 2])"
}

final class DrawingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Drawing"
        view.backgroundColor = .systemBackground
        let pattern = UIView(frame: CGRect(x: 16, y: 110, width: 160, height: 80)); pattern.accessibilityIdentifier = "pattern"
        let tile = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { c in
            UIColor.systemYellow.setFill(); c.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
            UIColor.systemBlue.setFill(); c.fill(CGRect(x: 0, y: 0, width: 10, height: 10)); c.fill(CGRect(x: 10, y: 10, width: 10, height: 10))
        }
        pattern.backgroundColor = UIColor(patternImage: tile)
        pattern.layer.cornerRadius = 12; pattern.clipsToBounds = true
        view.addSubview(pattern)
        if #available(iOS 26.1, *) {
            let effect = UIVisualEffectView(effect: UIColorEffect(color: .systemMint)); effect.accessibilityIdentifier = "effect"
            effect.frame = CGRect(x: 196, y: 110, width: 160, height: 80); effect.layer.cornerRadius = 12
            view.addSubview(effect)
        }
        let title = UILabel(frame: CGRect(x: 16, y: 210, width: 360, height: 60)); title.text = "Extra Large"
        title.font = .preferredFont(forTextStyle: .extraLargeTitle)
        view.addSubview(title)
        images()
        colors()
        printing()
    }

    func images() {
        let star = UIImage(systemName: "star")!
        let inset = star.withAlignmentRectInsets(UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
        let kept = inset.withRenderingMode(.alwaysTemplate)
        let plain = checker(.red, .blue)
        log("insets \(Int(inset.alignmentRectInsets.left)) \(Int(inset.alignmentRectInsets.right)) kept \(Int(kept.alignmentRectInsets.bottom)) plain \(Int(plain.alignmentRectInsets.top))")
        log("baseline symbol \(star.baselineOffsetFromBottom != nil) plain \(plain.baselineOffsetFromBottom == nil) set \(Int(plain.withBaselineOffset(fromBottom: 3).baselineOffsetFromBottom ?? -1)) none \(star.imageWithoutBaseline().baselineOffsetFromBottom == nil)")
        let wide = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 200, height: 100)) }
        let thumb = wide.preparingThumbnail(of: CGSize(width: 50, height: 50))
        log("thumbnail \(Int(thumb?.size.width ?? 0))x\(Int(thumb?.size.height ?? 0)) prepared \(wide.preparingForDisplay() != nil)")
        log("standard add \(UIImage.add.isSymbolImage) remove \(UIImage.remove.isSymbolImage) actions \(UIImage.actions.isSymbolImage) check \(UIImage.checkmark.isSymbolImage) \(UIImage.strokedCheckmark.isSymbolImage)")
        if #available(iOS 17.0, *) {
            log("hdr \(wide.isHighDynamicRange) restricted \(wide.imageRestrictedToStandardDynamicRange().size == wide.size) heic \(wide.heicData() == nil)")
            var config = UIImageReader.Configuration(); config.pixelsPerInch = 144
            let png = checker(.green, .black).pngData()!
            let read = UIImageReader(configuration: config).image(data: png)
            log("reader scale \(Int(read?.scale ?? 0)) size \(read?.size.width ?? 0) default \(UIImageReader.default.image(data: png)?.scale ?? 0)")
            let locale = UIImage.Configuration(locale: Locale(identifier: "ar")).withLocale(Locale(identifier: "he"))
            log("locale \(locale.locale?.identifier ?? "none")")
        }
        log("renderer format scale \(Int(wide.imageRendererFormat.scale))")
        let one = { () -> UIGraphicsImageRendererFormat in let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()
        let tiled = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: one).image { _ in
            plain.drawAsPattern(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        log("pattern drawn \(pixel(tiled, 2, 2)) \(pixel(tiled, 6, 2)) \(pixel(tiled, 10, 10)) \(pixel(tiled, 14, 10))")
        let filled = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: one).image { c in
            UIColor(patternImage: plain).setFill(); c.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        log("pattern fill \(pixel(filled, 2, 2)) \(pixel(filled, 6, 2)) \(pixel(filled, 10, 10)) \(pixel(filled, 14, 10))")
        let bold = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold, scale: .large)
        log("symbol config without weight \(bold.configurationWithoutWeight().isEqual(to: UIImage.SymbolConfiguration(pointSize: 20, weight: .unspecified, scale: .large))) without scale \(bold.configurationWithoutScale().isEqual(to: bold)) same \(bold.isEqual(to: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold, scale: .large)))")
        if #available(iOS 26.0, *) {
            _ = UIImage.SymbolConfiguration(colorRenderingMode: .gradient).applying(UIImage.SymbolConfiguration(variableValueMode: .draw))
        }
        if let asset = NSDataAsset(name: "Greeting") {
            let json = (try? JSONSerialization.jsonObject(with: asset.data)) as? [String: String]
            log("data asset \(asset.name) \(asset.typeIdentifier) \(json?["greeting"] ?? "")")
        } else { log("data asset missing") }
        log("missing asset \(NSDataAsset(name: "Nope") == nil)")
        Task {
            let p = await wide.byPreparingForDisplay()
            let t = await wide.byPreparingThumbnail(ofSize: CGSize(width: 20, height: 20))
            log("async prepared \(p != nil) thumbnail \(Int(t?.size.width ?? 0))x\(Int(t?.size.height ?? 0))")
        }
    }

    func colors() {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        _ = UIColor(red: 0, green: 0.5, blue: 1, alpha: 1).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        log(String(format: "hue %.3f %.2f %.2f %.1f", h, s, b, a))
        let ci = CIColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
        let fromCI = UIColor(ciColor: ci)
        var r: CGFloat = 0; fromCI.getRed(&r, green: nil, blue: nil, alpha: nil)
        log("ci \(r) back \(fromCI.ciColor.blue)")
        log("names \(UIColor.black.accessibilityName), \(UIColor.white.accessibilityName), \(UIColor(red: 0.1, green: 0.1, blue: 0.5, alpha: 1).accessibilityName), \(UIColor.red.accessibilityName), \(UIColor.lightGray.accessibilityName)")
        log("pattern components \(UIColor(patternImage: checker(.red, .blue)).getRed(&r, green: nil, blue: nil, alpha: nil))")
        log("p3 \(UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1) == UIColor(red: 1, green: 0, blue: 0, alpha: 1))")
        if #available(iOS 18.0, *) {
            let secondary = UIColor.systemBlue.withProminence(.secondary)
            secondary.getRed(nil, green: nil, blue: nil, alpha: &a)
            log(String(format: "prominence %d alpha %.1f primary %d", secondary.prominence.rawValue, a, UIColor.systemBlue.prominence.rawValue))
        }
        if #available(iOS 26.0, *) {
            let bright = UIColor(red: 1, green: 0.5, blue: 0, alpha: 1, linearExposure: 2)
            var rr: CGFloat = 0, gg: CGFloat = 0
            bright.standardDynamicRange.getRed(&rr, green: &gg, blue: nil, alpha: nil)
            log(String(format: "exposure %.1f sdr %.2f %.2f headroom %.1f", bright.linearExposure, rr, gg, UIColor.red.applyingContentHeadroom(3).linearExposure))
        }
        log("extra large \(Int(UIFont.preferredFont(forTextStyle: .extraLargeTitle).pointSize)) \(Int(UIFont.preferredFont(forTextStyle: .extraLargeTitle2).pointSize))")
    }

    func printing() {
        let error = NSError(domain: UIPrintErrorDomain, code: UIPrintError.Code.noContent.rawValue)
        log("print error \(UIPrintError.Code.notAvailable.rawValue) \(UIPrintError.Code.jobFailed.rawValue) matches \((error as? UIPrintError)?.code == .noContent)")
        let renderer = UIPrintPageRenderer()
        if #available(iOS 14.5, *) {
            log("quality \(renderer.currentRenderingQuality(forRequested: .responsive) == .responsive)")
            let destination = UIPrinterDestination(url: URL(string: "ipp://printer.local/ipp/print")!)
            destination.displayName = "Office"
            let data = try! NSKeyedArchiver.archivedData(withRootObject: destination, requiringSecureCoding: true)
            let back = try! NSKeyedUnarchiver.unarchivedObject(ofClass: UIPrinterDestination.self, from: data)
            log("destination \(back?.displayName ?? "") \(back?.url.host ?? "") extension \(UIPrintServiceExtension().printerDestinations(for: UIPrintInfo.printInfo()).count)")
        }
        let paper = UIPrintPaper.bestPaper(forPageSize: CGSize(width: 612, height: 792), withPapersFrom: [])
        log("paper rect same \(paper.printRect() == paper.printableRect) formatters \(UISimpleTextPrintFormatter(text: "x").requiresMainThread) \(UIMarkupTextPrintFormatter(markupText: "<b>x</b>").requiresMainThread)")
        log("cutter \(UIPrinter.CutterBehavior.cutAfterEachJob.rawValue)")
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200)).pdfData { c in
            c.beginPage()
            UIGraphicsAddPDFContextDestinationAtPoint("top", CGPoint(x: 0, y: 0))
            UIGraphicsSetPDFContextDestinationForRect("top", CGRect(x: 0, y: 100, width: 50, height: 20))
        }
        log("pdf \(pdf.count > 0)")
        log("ready")
    }
}
