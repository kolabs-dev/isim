// Sample: NSAttributedString's document formats on isim (issue #238) — HTML imported with
// NSAttributedString(data:options:documentAttributes:) (headings, styles, CSS rules and inline styles, colours, links,
// lists, a table, superscript, preformatted text, an image from a file next to the page), the document attributes,
// RTF and plain text through the same API, NSAttributedString(url:) and NSMutableAttributedString.read(from:), shown
// in a text view. Each probe logs the attributes at a word for the test.
import UIKit

let page = """
<!doctype html><html><head><meta charset="utf-8"><title>Ignored</title>
<style>.note { color: #008000; font-style: italic } #big { font-size: 24px } p.center { text-align: center }</style></head>
<body><h1>Heading</h1>
<p>Plain, <b>bold</b>, <i>italic</i>, <u>under</u>, <s>strike</s>, <span style="color: rgb(255, 0, 0); background-color: yellow">red</span>,
<a href="https://example.com/x">link</a>, <code>mono</code>, x<sup>sup</sup> and caf&eacute; &amp; &lt;tags&gt;.</p>
<p class="note">Styled by a class rule.</p><p id="big">Big by id</p><p class="center">Centered</p>
<ul><li>first</li><li>second<ol><li>nested</li></ol></li></ul>
<table><tr><th>Name</th><td>Value</td></tr></table>
<pre>  keep   spaces</pre>line<br>break <font color="blue" size="5">font tag</font> <img src="dot.png" width="16" height="16">
</body></html>
"""

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        let tv = UITextView(frame: .zero)
        tv.isEditable = false
        tv.accessibilityIdentifier = "html"
        tv.translatesAutoresizingMaskIntoConstraints = false
        vc.view.backgroundColor = .white
        vc.view.addSubview(tv)
        NSLayoutConstraint.activate([tv.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
                                     tv.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
                                     tv.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                                     tv.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)])
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        tv.attributedText = importAll()
        return true
    }

    func hex(_ c: UIColor?) -> String {
        guard let c else { return "none" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int(r * 255 + 0.5), Int(g * 255 + 0.5), Int(b * 255 + 0.5))
    }
    func escaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\t", with: "\\t")
    }
    func probe(_ s: NSAttributedString, _ word: String) {
        let r = (s.string as NSString).range(of: word)
        guard r.location != NSNotFound else { print("probe \(word) missing"); return }
        let a = s.attributes(at: r.location, effectiveRange: nil)
        let f = a[.font] as? UIFont
        let traits = f?.fontDescriptor.symbolicTraits ?? []
        let ps = a[.paragraphStyle] as? NSParagraphStyle
        print("probe \(word) family=\(f?.familyName ?? "?") size=\(Int((f?.pointSize ?? 0).rounded())) bold=\(traits.contains(.traitBold)) " +
              "italic=\(traits.contains(.traitItalic)) color=\(hex(a[.foregroundColor] as? UIColor)) bg=\(hex(a[.backgroundColor] as? UIColor)) " +
              "underline=\(a[.underlineStyle] as? Int ?? 0) strike=\(a[.strikethroughStyle] as? Int ?? 0) " +
              "link=\((a[.link] as? URL)?.absoluteString ?? "none") baseline=\(Int(((a[.baselineOffset] as? CGFloat) ?? 0).rounded())) " +
              "align=\(ps?.alignment.rawValue ?? -1) lists=\(ps?.textLists.count ?? 0)")
    }

    func importAll() -> NSAttributedString {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dot = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { c in
            UIColor.systemOrange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        try? dot.write(to: docs.appendingPathComponent("dot.png"))
        let file = docs.appendingPathComponent("page.html")
        try? Data(page.utf8).write(to: file)

        // HTML from data
        var attrs: NSDictionary?
        let html = try! NSAttributedString(data: Data(page.utf8), options: [.documentType: NSAttributedString.DocumentType.html,
                                                                           .characterEncoding: String.Encoding.utf8.rawValue],
                                           documentAttributes: &attrs)
        print("html string=\(escaped(html.string))")
        print("doc type=\((attrs?[NSAttributedString.DocumentAttributeKey.documentType] as? NSAttributedString.DocumentType)?.rawValue ?? "?") " +
              "encoding=\(attrs?[NSAttributedString.DocumentAttributeKey.characterEncoding] as? UInt ?? 0)")
        for w in ["Heading", "Plain", "bold", "italic", "under", "strike", "red", "link", "mono", "sup", "Styled", "Big", "Centered", "first", "nested", "font tag"] {
            probe(html, w)
        }
        // list markers in the text (TextKit 1's format): always with the option, by default before iOS 18
        if #available(iOS 18.0, *) {
            let tk1 = try! NSAttributedString(data: Data("<ul><li>one</li></ul><ol><li>two</li></ol>".utf8),
                                              options: [.documentType: NSAttributedString.DocumentType.html,
                                                        .textKit1ListMarkerFormatDocumentOption: true], documentAttributes: nil)
            print("tk1 string=\(escaped(tk1.string))")
        }
        // from a file URL: the image next to it becomes an attachment
        let fromURL = try! NSAttributedString(url: file, options: [:], documentAttributes: nil)
        var attachments = 0
        fromURL.enumerateAttribute(.attachment, in: NSRange(location: 0, length: fromURL.length)) { v, _, _ in if v != nil { attachments += 1 } }
        print("url attachments=\(attachments)")

        // RTF and plain text through the same API; the type sniffed when not given
        let rtf = try! NSAttributedString(data: Data(#"{\rtf1\ansi{\fonttbl{\f0 Helvetica;}}\f0\fs28 RTF {\b strong} text\par}"#.utf8), options: [:],
                                          documentAttributes: &attrs)
        print("rtf string=\(escaped(rtf.string)) type=\((attrs?[NSAttributedString.DocumentAttributeKey.documentType] as? NSAttributedString.DocumentType)?.rawValue ?? "?")")
        probe(rtf, "strong")
        let plain = try! NSAttributedString(data: Data("Plain text file".utf8), options: [.documentType: NSAttributedString.DocumentType.plain],
                                            documentAttributes: nil)
        probe(plain, "text")
        let mutable = NSMutableAttributedString(string: "replaced")
        try! mutable.read(from: Data("<p>read <em>into</em> a mutable string</p>".utf8), options: [:], documentAttributes: nil)
        print("mutable string=\(escaped(mutable.string))")
        do {
            _ = try NSAttributedString(url: URL(string: "https://example.com/page.html")!, options: [:], documentAttributes: nil)
        } catch {
            print("remote error=\((error as NSError).domain) \((error as NSError).code)")
        }
        return html
    }
}
