// HelloTextKit, -fidelity: text drawing fidelity on isim (issue #243) — UILabel's shadowColor / shadowOffset, NSShadow on attributed text
// (labels, a text view and string drawing into an image), an NSTextAttachment image inside a label's text,
// UIButton.imageView, and UIRefreshControl.attributedTitle under the spinner. Each part logs what the test checks.
import UIKit

/// pixels of an image matching a predicate on (r, g, b)
private func count(_ image: UIImage, _ match: (Int, Int, Int) -> Bool) -> Int {
    guard let cg = image.cgImage, let data = cg.dataProvider?.data, let p = CFDataGetBytePtr(data) else { return -1 }
    var n = 0
    for y in 0..<cg.height { for x in 0..<cg.width {
        let o = y * cg.bytesPerRow + x * 4
        if p[o + 3] > 0 && match(Int(p[o]), Int(p[o + 1]), Int(p[o + 2])) { n += 1 }
    } }
    return n
}
private func isRed(_ r: Int, _ g: Int, _ b: Int) -> Bool { r > 180 && g < 90 && b < 90 }
private func isGreen(_ r: Int, _ g: Int, _ b: Int) -> Bool { g > 180 && r < 60 && b < 60 }
private func swatch(_ color: UIColor, _ size: CGSize) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { c in color.setFill(); c.fill(CGRect(origin: .zero, size: size)) }
}

final class FidelityViewController: UIViewController {
    let scroll = UIScrollView(frame: CGRect(x: 0, y: 560, width: 402, height: 260))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let bold = UIFont.systemFont(ofSize: 40, weight: .bold)

        // UILabel.shadowColor / shadowOffset: a hard shadow, offset
        let plain = UILabel(frame: CGRect(x: 20, y: 70, width: 360, height: 56))
        plain.text = "Shadow"; plain.font = bold; plain.textColor = .black
        plain.shadowColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1); plain.shadowOffset = CGSize(width: 4, height: 4)
        plain.accessibilityIdentifier = "label-shadow"
        view.addSubview(plain)
        print("label shadow color=\(plain.shadowColor != nil) offset=\(Int(plain.shadowOffset.width)),\(Int(plain.shadowOffset.height)) default=\(Int(UILabel().shadowOffset.height))")

        // NSShadow: blurred, in the shadow's colour
        let shadow = NSShadow()
        shadow.shadowColor = UIColor(red: 0, green: 0, blue: 1, alpha: 1); shadow.shadowOffset = CGSize(width: 0, height: 6); shadow.shadowBlurRadius = 6
        let blurred = UILabel(frame: CGRect(x: 20, y: 136, width: 360, height: 56))
        blurred.attributedText = NSAttributedString(string: "Blurred", attributes: [.font: bold, .foregroundColor: UIColor.black, .shadow: shadow])
        blurred.accessibilityIdentifier = "label-nsshadow"
        view.addSubview(blurred)
        print("nsshadow default offset=\(Int(NSShadow().shadowOffset.height)) equal=\(shadow == (shadow.copy() as! NSShadow))")

        // NSTextAttachment: an image inline in a label's text
        let attachment = NSTextAttachment()
        attachment.image = swatch(UIColor(red: 0, green: 1, blue: 0, alpha: 1), CGSize(width: 24, height: 24))
        let inline = NSMutableAttributedString(string: "Icon ", attributes: [.font: UIFont.systemFont(ofSize: 20)])
        inline.append(NSAttributedString(attachment: attachment))
        inline.append(NSAttributedString(string: " inline", attributes: [.font: UIFont.systemFont(ofSize: 20)]))
        let withImage = UILabel(frame: CGRect(x: 20, y: 202, width: 360, height: 40))
        withImage.attributedText = inline
        withImage.accessibilityIdentifier = "label-attachment"
        view.addSubview(withImage)
        let textOnly = NSAttributedString(string: "Icon  inline", attributes: [.font: UIFont.systemFont(ofSize: 20)]).size().width
        print("attachment label wider=\(withImage.intrinsicContentSize.width >= textOnly + 20)")

        // a text view with NSShadow
        let tv = UITextView(frame: CGRect(x: 20, y: 250, width: 360, height: 60))
        tv.isEditable = false
        let tvShadow = NSShadow(); tvShadow.shadowColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1); tvShadow.shadowOffset = CGSize(width: 3, height: 3)
        tv.attributedText = NSAttributedString(string: "Text view", attributes: [.font: UIFont.systemFont(ofSize: 30, weight: .heavy), .foregroundColor: UIColor.black, .shadow: tvShadow])
        tv.accessibilityIdentifier = "textview-shadow"
        view.addSubview(tv)

        // UIButton.imageView: the current image, at the frame the button draws it in
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 20, y: 320, width: 200, height: 44)
        button.setImage(swatch(.orange, CGSize(width: 20, height: 20)), for: .normal)
        button.setTitle("Button", for: .normal); button.setTitleColor(.black, for: .normal)
        button.accessibilityIdentifier = "button-image"
        view.addSubview(button)
        button.layoutIfNeeded()
        let iv = button.imageView
        print("button imageView image=\(iv?.image.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none") " +
              "frame=\(iv.map { "\(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "none") same=\(iv === button.imageView)")
        let hiddenImage = UIButton(type: .custom)
        hiddenImage.frame = CGRect(x: 230, y: 320, width: 150, height: 44)
        hiddenImage.setImage(swatch(UIColor(red: 0, green: 1, blue: 0, alpha: 1), CGSize(width: 20, height: 20)), for: .normal)
        hiddenImage.imageView?.isHidden = true
        hiddenImage.accessibilityIdentifier = "button-hidden-image"
        view.addSubview(hiddenImage)
        print("no image imageView=\(UIButton(type: .system).imageView?.image == nil)")

        // string drawing into an image: NSShadow and an attachment
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let sharp = NSShadow(); sharp.shadowColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1); sharp.shadowOffset = CGSize(width: 8, height: 8)
        let font = UIFont.systemFont(ofSize: 40, weight: .black)
        func render(_ s: NSAttributedString) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 140, height: 70), format: format).image { _ in
                UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 140, height: 70)); s.draw(at: CGPoint(x: 4, y: 4))
            }
        }
        let shadowed = render(NSAttributedString(string: "WW", attributes: [.font: font, .foregroundColor: UIColor.black, .shadow: sharp]))
        let unshadowed = render(NSAttributedString(string: "WW", attributes: [.font: font, .foregroundColor: UIColor.black]))
        let partial = NSMutableAttributedString(string: "W", attributes: [.font: font, .foregroundColor: UIColor.black])
        partial.append(NSAttributedString(string: "W", attributes: [.font: font, .foregroundColor: UIColor.black, .shadow: sharp]))
        let both = count(shadowed, isRed), none = count(unshadowed, isRed), half = count(render(partial), isRed)
        print("render shadow red=\(both > 50) none=\(none == 0) partial=\(half > 20 && half < both)")
        let att = NSMutableAttributedString(string: "A", attributes: [.font: font, .foregroundColor: UIColor.black])
        att.append(NSAttributedString(attachment: attachment))
        print("render attachment green=\(count(render(att), isGreen) > 300)")

        // UIRefreshControl.attributedTitle, under the spinner
        scroll.contentSize = CGSize(width: 402, height: 600)
        scroll.backgroundColor = UIColor(white: 0.95, alpha: 1)
        scroll.accessibilityIdentifier = "scroll"
        let rc = UIRefreshControl()
        rc.attributedTitle = NSAttributedString(string: "Updating", attributes: [.foregroundColor: UIColor(red: 0.6, green: 0, blue: 0.6, alpha: 1)])
        scroll.refreshControl = rc
        view.addSubview(scroll)
        rc.beginRefreshing()
        scroll.contentOffset = CGPoint(x: 0, y: -scroll.adjustedContentInset.top)
        print("refresh title=\(rc.attributedTitle?.string ?? "none") label=\(rc.accessibilityLabel ?? "none")")
    }
}
