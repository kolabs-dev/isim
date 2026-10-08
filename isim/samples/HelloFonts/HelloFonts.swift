// Sample: UIFont and UIFontDescriptor on isim — symbolic traits (bold, italic, monospaced), weights through the
// traits attribute, the system designs (serif, rounded, monospaced), monospaced digits (font and feature settings),
// text styles (Dynamic Type), sizes, and secure coding. The screen lists the faces; the checks print PASS / FAIL.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = FontsViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

var checks = 0, failures = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if !ok { failures += 1 }
    print("\(ok ? "PASS" : "FAIL")  \(what)")
}
func width(_ s: String, _ f: UIFont) -> CGFloat { (s as NSString).size(withAttributes: [.font: f]).width }
/// the RGBA bytes of a string drawn in black on a w x h bitmap
func pixels(_ s: String, _ f: UIFont, _ w: Int = 120, _ h: Int = 30) -> [UInt8] {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { _ in
        (s as NSString).draw(at: .zero, withAttributes: [.font: f, .foregroundColor: UIColor.black])
    }
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    bytes.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return bytes
}

func runChecks() {
    let body = UIFont.systemFont(ofSize: 17)
    let bold = UIFont(descriptor: body.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
    check(bold.fontDescriptor.symbolicTraits.contains(.traitBold) && bold.pointSize == 17 && width("Hello", bold) > width("Hello", body),
          "withSymbolicTraits(.traitBold): a bold system font (\(bold.fontName))")
    let italic = UIFont.italicSystemFont(ofSize: 17)
    check(italic.fontDescriptor.symbolicTraits.contains(.traitItalic) && pixels("Hello", italic) != pixels("Hello", body),
          "italicSystemFont is drawn italic")
    let both = UIFont(descriptor: body.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])!, size: 20)
    check(both.fontDescriptor.symbolicTraits.isSuperset(of: [.traitBold, .traitItalic]) && both.pointSize == 20, "bold + italic, size 20")
    let plain = UIFont(descriptor: UIFont.boldSystemFont(ofSize: 17).fontDescriptor.withSymbolicTraits([])!, size: 0)
    check(!plain.fontDescriptor.symbolicTraits.contains(.traitBold), "withSymbolicTraits([]) drops bold")
    let mono = UIFont(descriptor: body.fontDescriptor.withSymbolicTraits(.traitMonoSpace)!, size: 0)
    check(abs(width("iiii", mono) - width("MMMM", mono)) < 1 && abs(width("iiii", body) - width("MMMM", body)) > 5,
          "withSymbolicTraits(.traitMonoSpace): monospaced (\(width("iiii", mono)) vs \(width("MMMM", mono)))")
    let digits = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
    check(abs(width("1111", digits) - width("0000", digits)) < 0.5,
          "monospacedDigitSystemFont: digits have one width (\(width("1111", digits)) / \(width("0000", digits)); proportional \(width("1111", body)) / \(width("0000", body)))")
    let featured = UIFont(descriptor: body.fontDescriptor.addingAttributes([.featureSettings: [[UIFontDescriptor.FeatureKey.type: 6, .selector: 0]]]), size: 0)
    check(abs(width("1111", featured) - width("0000", featured)) < 0.5, "featureSettings (number spacing: monospaced) gives tabular digits")
    let heavy = UIFont(descriptor: body.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.heavy]]), size: 0)
    check(heavy.fontDescriptor.symbolicTraits.contains(.traitBold) && width("Hello", heavy) > width("Hello", body), "traits weight .heavy")
    let serif = body.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 0) }
    let rounded = body.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 0) }
    let monoDesign = body.fontDescriptor.withDesign(.monospaced).map { UIFont(descriptor: $0, size: 0) }
    check(serif?.familyName == ".New York" && rounded != nil && monoDesign?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true,
          "withDesign: serif / rounded / monospaced (\(serif?.familyName ?? "nil"))")
    check(UIFontDescriptor(name: "Menlo", size: 12).withDesign(.serif) == nil, "withDesign is nil for a named (non-system) font")
    let headline = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
    let headlineFont = UIFont(descriptor: headline, size: 0)
    check(headline.pointSize == UIFont.preferredFont(forTextStyle: .headline).pointSize &&
          headline.object(forKey: .textStyle) as? String == UIFont.TextStyle.headline.rawValue && headlineFont.pointSize == headline.pointSize,
          "preferredFontDescriptor(withTextStyle: .headline) (\(headline.pointSize) pt)")
    check(headline.withSize(30).pointSize == 30 && UIFont(descriptor: headline.withSize(30), size: 0).pointSize == 30, "withSize(_:)")
    let menlo = UIFont(descriptor: UIFontDescriptor(name: "Menlo", size: 12), size: 0)
    check(menlo.fontName == "Menlo" && menlo.pointSize == 12 && UIFontDescriptor(name: "Menlo", size: 12).postscriptName == "Menlo",
          "init(name:size:) descriptors resolve named fonts")
    let data = try? NSKeyedArchiver.archivedData(withRootObject: both.fontDescriptor, requiringSecureCoding: true)
    let back = data.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIFontDescriptor.self, from: $0) }
    check(back == both.fontDescriptor && back.map { UIFont(descriptor: $0, size: 0) } == both, "NSSecureCoding round trip")
    print("font checks: \(checks - failures)/\(checks) passed")
}

final class FontsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let body = UIFont.systemFont(ofSize: 20)
        func face(_ d: UIFontDescriptor?) -> UIFont { d.map { UIFont(descriptor: $0, size: 0) } ?? body }
        let rows: [(String, UIFont)] = [
            ("System 20", body),
            ("Bold (symbolic traits)", face(body.fontDescriptor.withSymbolicTraits(.traitBold))),
            ("Italic", UIFont.italicSystemFont(ofSize: 20)),
            ("Bold Italic", face(body.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]))),
            ("Heavy (traits weight)", face(body.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.heavy]]))),
            ("Serif design", face(body.fontDescriptor.withDesign(.serif))),
            ("Monospaced design", face(body.fontDescriptor.withDesign(.monospaced))),
            ("Headline text style", UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .headline), size: 0)),
        ]
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        for (i, (text, font)) in rows.enumerated() {
            let l = UILabel(); l.text = text; l.font = font; l.accessibilityIdentifier = "row\(i)"
            stack.addArrangedSubview(l)
        }
        // digits: proportional vs monospaced, right-aligned so the columns show the difference
        for (i, f) in [UIFont.systemFont(ofSize: 20), UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .regular)].enumerated() {
            let l = UILabel(); l.numberOfLines = 0; l.textAlignment = .right; l.font = f
            l.text = (i == 0 ? "proportional\n" : "monospaced digits\n") + "111.11\n888.88"
            l.accessibilityIdentifier = i == 0 ? "proportional" : "tabular"
            stack.addArrangedSubview(l)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        runChecks()
    }
}
