// Sample: PDFKit on isim (issue #269). Builds a document from pages (one drawn with UIGraphicsPDFRenderer, one from an
// image, a blank page turned 90°), gives it attributes and an outline, reorders its pages, writes it to the app's
// Documents and reads it back: page labels, text, boxes, rotation, the outline's destinations. Thumbnails of the
// pages read back fill the screen. PDFView (issue #270) will show the document here too.
import PDFKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = PDFViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// A page drawn by UIGraphicsPDFRenderer (y-down, like UIKit): a title, a line of text and an orange band.
func textPage() -> PDFPage {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
    let data = renderer.pdfData { ctx in
        ctx.beginPage()
        UIColor.systemOrange.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 300, height: 80))
        "Hello PDFKit".draw(at: CGPoint(x: 20, y: 110), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 28), .foregroundColor: UIColor.black])
        "isim reads and writes PDFs".draw(at: CGPoint(x: 20, y: 160), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
    }
    return PDFDocument(data: data)!.page(at: 0)!
}

/// A page from an image: a blue square with a green circle.
func imagePage() -> PDFPage {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { ctx in
        UIColor.systemBlue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        UIColor.systemGreen.setFill(); UIBezierPath(ovalIn: CGRect(x: 50, y: 50, width: 100, height: 100)).fill()
    }
    return PDFPage(image: image)!
}

final class PDFViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray5
        let title = UILabel(frame: CGRect(x: 16, y: 60, width: 360, height: 30))
        title.text = "PDFKit · documents and pages"; title.font = .boldSystemFont(ofSize: 18)
        view.addSubview(title)

        // build: text page, image page, blank page turned 90°; then the image page moved first
        let doc = PDFDocument()
        let text = textPage(), image = imagePage(), blank = PDFPage()
        let square = PDFPage(image: UIImage(cgImage: image.thumbnail(of: CGSize(width: 50, height: 50), for: .mediaBox).cgImage!),
                             options: [.mediaBox: NSValue(cgRect: CGRect(x: 0, y: 0, width: 100, height: 100)), .rotation: 180])
        print("pdfkit image options box \(Int(square?.bounds(for: .mediaBox).width ?? 0)) rotation \(square?.rotation ?? -1)")
        blank.rotation = 90
        blank.setBounds(CGRect(x: 0, y: 0, width: 300, height: 200), for: .mediaBox)
        doc.insert(text, at: 0)
        doc.insert(blank, at: 1)
        doc.insert(image, at: 2)
        doc.exchangePage(at: 0, withPageAt: 2)                // image, blank, text
        doc.removePage(at: 1)                                 // image, text
        doc.insert(blank, at: 2)                              // image, text, blank
        doc.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Hello PDFKit", PDFDocumentAttribute.authorAttribute: "isim",
                                  PDFDocumentAttribute.keywordsAttribute: ["pdf", "kit"]]
        let root = PDFOutline()
        for (i, (label, page)) in [("Image", image), ("Text", text), ("Blank", blank)].enumerated() {
            let item = PDFOutline()
            item.label = label
            item.destination = PDFDestination(page: page, at: CGPoint(x: 0, y: page.bounds(for: .mediaBox).maxY))
            root.insertChild(item, at: i)
        }
        doc.outlineRoot = root
        print("pdfkit built pages \(doc.pageCount) order \(doc.index(for: image)),\(doc.index(for: text)),\(doc.index(for: blank)) permissions \(doc.permissionsStatus == .owner ? "owner" : "?")")

        // write and read back
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("hello.pdf")
        let wrote = doc.write(to: url)
        guard let back = PDFDocument(url: url) else { print("pdfkit read back failed"); return }
        let labels = (0..<back.pageCount).compactMap { back.page(at: $0)?.label }.joined(separator: ",")
        let sizes = (0..<back.pageCount).compactMap { back.page(at: $0) }.map { p -> String in
            let b = p.bounds(for: .mediaBox); return "\(Int(b.width))x\(Int(b.height))"
        }.joined(separator: ",")
        let outline = (0..<(back.outlineRoot?.numberOfChildren ?? 0)).compactMap { back.outlineRoot?.child(at: $0) }
        let targets = outline.map { o in "\(o.label ?? "")@\(o.destination?.page.map { back.index(for: $0) } ?? -1)" }.joined(separator: ",")
        let words = back.page(at: 1)?.string?.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty } ?? []
        let attrs = back.documentAttributes ?? [:]
        print("pdfkit wrote \(wrote) read pages \(back.pageCount) labels \(labels) sizes \(sizes) version \(back.majorVersion).\(back.minorVersion)")
        print("pdfkit outline \(targets) title \(attrs[PDFDocumentAttribute.titleAttribute] ?? "-") keywords \((attrs[PDFDocumentAttribute.keywordsAttribute] as? [String])?.joined(separator: "+") ?? "-")")
        print("pdfkit text \(words.prefix(2).joined(separator: " ")) characters \(back.page(at: 1)?.numberOfCharacters ?? 0) first char x \(Int(back.page(at: 1)?.characterBounds(at: 0).minX ?? -1))")

        // thumbnails of the pages read back
        var x: CGFloat = 16
        for i in 0..<back.pageCount {
            guard let page = back.page(at: i) else { continue }
            let thumb = page.thumbnail(of: CGSize(width: 110, height: 150), for: .mediaBox)
            let iv = UIImageView(image: thumb)
            iv.frame = CGRect(x: x, y: 110, width: thumb.size.width, height: thumb.size.height)
            iv.layer.borderColor = UIColor.darkGray.cgColor; iv.layer.borderWidth = 1
            iv.accessibilityIdentifier = "page\(i)"
            view.addSubview(iv)
            let label = UILabel(frame: CGRect(x: x, y: 265, width: 110, height: 20))
            label.text = "Page \(page.label ?? "?")"; label.font = .systemFont(ofSize: 13)
            view.addSubview(label)
            x += thumb.size.width + 12
        }
        print("pdfkit thumbnails \(back.pageCount)")
    }
}
