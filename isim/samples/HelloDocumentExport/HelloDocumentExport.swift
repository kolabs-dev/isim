// Sample: writing NSAttributedString documents on isim (issue #239) — data(from:documentAttributes:) as RTF, HTML,
// plain text (UTF-16) and RTFD, fileWrapper(from:documentAttributes:) as an RTFD package with an image attachment
// written to Documents, and each read back with NSAttributedString(data:) / NSAttributedString(url:); the
// FileWrapper's serialized form. Each probe logs the attributes at a word for the test.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        let tv = UITextView(frame: .zero)
        tv.isEditable = false
        tv.accessibilityIdentifier = "doc"
        tv.translatesAutoresizingMaskIntoConstraints = false
        vc.view.backgroundColor = .white
        vc.view.addSubview(tv)
        NSLayoutConstraint.activate([tv.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
                                     tv.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
                                     tv.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                                     tv.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)])
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        tv.attributedText = run()
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
    func probe(_ tag: String, _ s: NSAttributedString, _ word: String) {
        let r = (s.string as NSString).range(of: word)
        guard r.location != NSNotFound else { print("probe \(tag) \(word) missing"); return }
        let a = s.attributes(at: r.location, effectiveRange: nil)
        let f = a[.font] as? UIFont
        let traits = f?.fontDescriptor.symbolicTraits ?? []
        let ps = a[.paragraphStyle] as? NSParagraphStyle
        let link = (a[.link] as? URL)?.absoluteString ?? (a[.link] as? String) ?? "none"
        print("probe \(tag) \(word) family=\(f?.familyName ?? "?") size=\(Int((f?.pointSize ?? 0).rounded())) bold=\(traits.contains(.traitBold)) " +
              "italic=\(traits.contains(.traitItalic)) color=\(hex(a[.foregroundColor] as? UIColor)) bg=\(hex(a[.backgroundColor] as? UIColor)) " +
              "underline=\(a[.underlineStyle] as? Int ?? 0) strike=\(a[.strikethroughStyle] as? Int ?? 0) link=\(link) " +
              "baseline=\(Int(((a[.baselineOffset] as? CGFloat) ?? 0).rounded())) align=\(ps?.alignment.rawValue ?? -1) indent=\(Int(ps?.headIndent ?? 0))")
    }
    func attachments(_ s: NSAttributedString) -> [NSTextAttachment] {
        var out: [NSTextAttachment] = []
        s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { v, _, _ in if let a = v as? NSTextAttachment { out.append(a) } }
        return out
    }

    func document() -> NSAttributedString {
        let s = NSMutableAttributedString()
        let centered = NSMutableParagraphStyle(); centered.alignment = .center
        let indented = NSMutableParagraphStyle(); indented.headIndent = 36; indented.firstLineHeadIndent = 36
        s.append(NSAttributedString(string: "Title\n", attributes: [.font: UIFont(name: "Helvetica-Bold", size: 24)!, .paragraphStyle: centered]))
        let body: [NSAttributedString.Key: Any] = [.font: UIFont(name: "Helvetica", size: 14)!]
        s.append(NSAttributedString(string: "Plain, ", attributes: body))
        s.append(NSAttributedString(string: "italic", attributes: [.font: UIFont(name: "Helvetica-Oblique", size: 14)!]))
        s.append(NSAttributedString(string: ", ", attributes: body))
        s.append(NSAttributedString(string: "red", attributes: body.merging([.foregroundColor: UIColor(red: 1, green: 0, blue: 0, alpha: 1),
                                                                             .backgroundColor: UIColor(red: 1, green: 1, blue: 0, alpha: 1)]) { $1 }))
        s.append(NSAttributedString(string: ", ", attributes: body))
        s.append(NSAttributedString(string: "under", attributes: body.merging([.underlineStyle: NSUnderlineStyle.single.rawValue]) { $1 }))
        s.append(NSAttributedString(string: ", ", attributes: body))
        s.append(NSAttributedString(string: "link", attributes: body.merging([.link: URL(string: "https://example.com/doc")!]) { $1 }))
        s.append(NSAttributedString(string: ", x", attributes: body))
        s.append(NSAttributedString(string: "up", attributes: body.merging([.baselineOffset: 4]) { $1 }))
        s.append(NSAttributedString(string: " and caf\u{e9} \u{2014} \u{65e5}\u{672c}.\n", attributes: body))
        s.append(NSAttributedString(string: "Indented paragraph\n", attributes: body.merging([.paragraphStyle: indented]) { $1 }))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20)).image { c in
            UIColor.systemBlue.setFill(); c.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        }
        let att = NSTextAttachment()
        att.fileWrapper = FileWrapper(regularFileWithContents: image.pngData()!)
        att.fileWrapper?.preferredFilename = "box.png"
        att.bounds = CGRect(x: 0, y: 0, width: 40, height: 20)
        s.append(NSAttributedString(attachment: att))
        s.append(NSAttributedString(string: " end", attributes: body))
        return s
    }

    func run() -> NSAttributedString {
        let doc = document()
        let all = NSRange(location: 0, length: doc.length)
        let probes = ["Title", "Plain", "italic", "red", "under", "link", "up", "Indented"]

        // RTF: attachments are dropped, everything else round-trips
        let rtf = try! doc.data(from: all, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf,
                                                                  .paperSize: CGSize(width: 595, height: 842)])
        let rtfText = String(decoding: rtf, as: UTF8.self)
        print("rtf head=\(rtfText.prefix(25)) link=\(rtfText.contains("HYPERLINK \"https://example.com/doc\"")) unicode=\(rtfText.contains("\\u26085"))")
        var attrs: NSDictionary?
        let fromRTF = try! NSAttributedString(data: rtf, options: [:], documentAttributes: &attrs)
        print("rtf string=\(escaped(fromRTF.string)) paper=\((attrs?[NSAttributedString.DocumentAttributeKey.paperSize] as? CGSize).map { "\(Int($0.width))x\(Int($0.height))" } ?? "?")")
        for w in probes { probe("rtf", fromRTF, w) }

        // RTFD as a package in Documents, read back from its URL
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let package = docs.appendingPathComponent("Note.rtfd")
        let wrapper = try! doc.fileWrapper(from: all, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        try! wrapper.write(to: package, options: .atomic, originalContentsURL: nil)
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: package.path)) ?? []).sorted()
        print("rtfd files=\(names.joined(separator: ","))")
        let fromRTFD = try! NSAttributedString(url: package, options: [:], documentAttributes: &attrs)
        let found = attachments(fromRTFD)
        print("rtfd type=\((attrs?[NSAttributedString.DocumentAttributeKey.documentType] as? NSAttributedString.DocumentType)?.rawValue ?? "?") " +
              "attachments=\(found.count) file=\(found.first?.fileWrapper?.preferredFilename ?? "none") " +
              "bounds=\(Int(found.first?.bounds.width ?? 0))x\(Int(found.first?.bounds.height ?? 0)) image=\(found.first?.image.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none")")
        probe("rtfd", fromRTFD, "red")
        print("rtfd tail=\(escaped(String(fromRTFD.string.suffix(6))).unicodeScalars.map { $0.value == 0xFFFC ? "[obj]" : String($0) }.joined())")

        // RTFD as data: the file wrapper's serialized form
        let rtfdData = try! doc.data(from: all, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        let fromRTFDData = try! NSAttributedString(data: rtfdData, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
        print("rtfd data attachments=\(attachments(fromRTFDData).count) same=\(fromRTFDData.string == fromRTFD.string)")
        let restored = FileWrapper(serializedRepresentation: wrapper.serializedRepresentation!)
        print("serialized files=\((restored?.fileWrappers?.keys.sorted() ?? []).joined(separator: ","))")

        // HTML: Cocoa's writer's shape; fonts written in px read back at 3/4 of the size, as on iOS
        let html = try! doc.data(from: all, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
        let htmlText = String(decoding: html, as: UTF8.self)
        print("html generator=\(htmlText.contains("Cocoa HTML Writer")) link=\(htmlText.contains("<a href=\"https://example.com/doc\">link</a>")) spans=\(htmlText.contains("<span class=\"s1\">"))")
        let fromHTML = try! NSAttributedString(data: html, options: [.documentType: NSAttributedString.DocumentType.html,
                                                                      .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
        print("html string=\(escaped(fromHTML.string))")
        for w in ["Title", "italic", "red", "link"] { probe("html", fromHTML, w) }

        // plain text in UTF-16
        let plain = try! doc.data(from: all, documentAttributes: [.documentType: NSAttributedString.DocumentType.plain,
                                                                    .characterEncoding: String.Encoding.utf16.rawValue])
        let fromPlain = try! NSAttributedString(data: plain, options: [.documentType: NSAttributedString.DocumentType.plain,
                                                                        .characterEncoding: String.Encoding.utf16.rawValue], documentAttributes: nil)
        print("plain bytes=\(plain.count) string=\(escaped(fromPlain.string))")
        return fromRTFD
    }
}
