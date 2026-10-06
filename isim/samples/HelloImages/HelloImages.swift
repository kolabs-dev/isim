// Sample: drawing on isim — UIGraphicsImageRenderer (shapes, text, images), PNG/JPEG export and UIImage(data:)
// round trips, UIGraphicsBeginImageContext, NSString/NSAttributedString drawing in draw(_:), and UILabel.attributedText.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ImagesViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// Draws strings with attributes in draw(_:).
final class CaptionView: UIView {
    override func draw(_ rect: CGRect) {
        let title = "Drawn with attributes"
        title.draw(at: CGPoint(x: 12, y: 8), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.systemPurple])
        let body = NSAttributedString(string: "A centred paragraph drawn in a rect, wrapping onto a second line.", attributes: [
            .font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }()])
        body.draw(in: CGRect(x: 12, y: 40, width: bounds.width - 24, height: 60))
    }
}

final class ImagesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // 1. an image drawn offscreen
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        let badge = renderer.image { ctx in
            UIColor.systemRed.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 120, height: 120))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 30, y: 54, width: 60, height: 12))
            "OK".draw(at: CGPoint(x: 44, y: 76), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.white])
        }
        print("badge size \(Int(badge.size.width))x\(Int(badge.size.height)) scale \(Int(badge.scale))")
        let badgeView = UIImageView(image: badge)
        badgeView.frame = CGRect(x: 20, y: 80, width: 120, height: 120)
        badgeView.accessibilityIdentifier = "badge"
        view.addSubview(badgeView)

        // 2. PNG / JPEG round trips
        if let png = badge.pngData(), let back = UIImage(data: png, scale: badge.scale) {
            let sig = png.prefix(4).map { String(format: "%02x", $0) }.joined()
            print("png \(png.count) bytes sig \(sig), decoded \(Int(back.size.width))x\(Int(back.size.height))")
            let copy = UIImageView(image: back)
            copy.frame = CGRect(x: 160, y: 80, width: 120, height: 120)
            copy.accessibilityIdentifier = "decoded"
            view.addSubview(copy)
        }
        if let jpg = badge.jpegData(compressionQuality: 0.8) {
            print("jpeg \(jpg.count) bytes sig \(jpg.prefix(2).map { String(format: "%02x", $0) }.joined())")
        }
        let pngData = renderer.pngData { ctx in UIColor.systemBlue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120)) }
        print("renderer png decodes: \(UIImage(data: pngData) != nil)")

        // 3. the old-style context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 40, height: 40), false, 2)
        UIColor.systemGreen.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 40, height: 40))
        let square = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        print("context image \(Int(square?.size.width ?? 0))x\(Int(square?.size.height ?? 0)) scale \(Int(square?.scale ?? 0))")
        let squareView = UIImageView(image: square)
        squareView.frame = CGRect(x: 300, y: 120, width: 40, height: 40)
        squareView.accessibilityIdentifier = "square"
        view.addSubview(squareView)

        // 4. attributed label
        let label = UILabel(frame: CGRect(x: 20, y: 230, width: 362, height: 80))
        label.numberOfLines = 0
        let text = NSMutableAttributedString(string: "Bold ", attributes: [.font: UIFont.boldSystemFont(ofSize: 24)])
        text.append(NSAttributedString(string: "red ", attributes: [.foregroundColor: UIColor.systemRed, .font: UIFont.systemFont(ofSize: 24)]))
        text.append(NSAttributedString(string: "underlined ", attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue, .font: UIFont.systemFont(ofSize: 24)]))
        text.append(NSAttributedString(string: "struck", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue, .font: UIFont.systemFont(ofSize: 24),
                                                                       .backgroundColor: UIColor.systemYellow]))
        label.attributedText = text
        label.accessibilityIdentifier = "attributed"
        view.addSubview(label)
        label.sizeToFit()
        print("attributed label \(label.attributedText?.length ?? 0) chars, fits \(Int(label.bounds.width))x\(Int(label.bounds.height))")

        let size = ("Measure me" as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 30)])
        let wrapped = ("Measure me in a narrow box please" as NSString).boundingRect(with: CGSize(width: 100, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin, attributes: [.font: UIFont.systemFont(ofSize: 17)], context: nil)
        print("measured \(Int(size.width))x\(Int(size.height)), wrapped height \(Int(wrapped.height))")

        let caption = CaptionView(frame: CGRect(x: 0, y: 330, width: 402, height: 110))
        caption.backgroundColor = .secondarySystemBackground
        caption.accessibilityIdentifier = "caption"
        view.addSubview(caption)
    }
}
