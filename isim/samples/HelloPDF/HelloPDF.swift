// Sample: PDFKit on isim (issue #269). Builds a document from pages (one drawn with UIGraphicsPDFRenderer, one from an
// image, a blank page turned 90°), gives it attributes and an outline, reorders its pages, writes it to the app's
// Documents and reads it back: page labels, text, boxes, rotation, the outline's destinations. Thumbnails of the
// pages read back sit at the top; below, a PDFView shows the document built (issue #270) with a PDFThumbnailView
// strip and Previous / Next / Back buttons; the text page's second line is a link (the delegate logs it).
// Issue #358: the text page gets annotations (a highlight over "Hello" found by its text, a note, a stamp), written and
// read back; Find highlights the document's matches in the PDFView; a tap on the note posts .PDFViewAnnotationHit.
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
        "isim reads and writes PDFs".draw(at: CGPoint(x: 20, y: 160), withAttributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.systemBlue])
        ctx.setURL(URL(string: "https://example.com/isim")!, for: CGRect(x: 20, y: 160, width: 220, height: 22))
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

final class PDFViewController: UIViewController, PDFViewDelegate {
    let pdfView = PDFView()
    let pageLabel = UILabel()

    func pdfViewWillClick(onLink sender: PDFView, with url: URL) { print("pdfview link \(url.absoluteString)") }

    @objc func pageChanged(_ n: Notification) {
        guard let doc = pdfView.document, let page = pdfView.currentPage else { return }
        pageLabel.text = "Page \(doc.index(for: page) + 1) of \(doc.pageCount)"
        print("pdfview page \(doc.index(for: page)) back \(pdfView.canGoBack) visible \(pdfView.visiblePages.count)")
    }
    @objc func showPrevious() { pdfView.goToPreviousPage(nil) }
    @objc func showNext() { pdfView.goToNextPage(nil) }
    @objc func showBack() { pdfView.goBack(nil) }
    @objc func findPDF() {
        let found = pdfView.document?.findString("pdf", withOptions: .caseInsensitive) ?? []
        pdfView.highlightedSelections = found
        pdfView.currentSelection = found.first
        if let first = found.first { pdfView.go(to: first) }
        print("pdfview find \(found.count) first \(found.first?.string ?? "-")")
    }

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

        // annotations: a highlight over the title's first word (found by its text), a note and a stamp
        if let hello = doc.findString("Hello", withOptions: []).first {
            let highlight = PDFAnnotation(bounds: hello.bounds(for: text).insetBy(dx: -2, dy: -2), forType: .highlight, withProperties: nil)
            highlight.color = .systemYellow
            text.addAnnotation(highlight)
        }
        let note = PDFAnnotation(bounds: CGRect(x: 250, y: 360, width: 20, height: 20), forType: .text, withProperties: nil)
        note.contents = "A note"
        note.iconType = .comment
        note.color = .systemYellow
        text.addAnnotation(note)
        let stamp = PDFAnnotation(bounds: CGRect(x: 150, y: 20, width: 130, height: 40), forType: .stamp, withProperties: nil)
        stamp.stampName = "Approved"
        text.addAnnotation(stamp)
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
        let annotations = back.page(at: 1)?.annotations.compactMap { $0.type }.sorted().joined(separator: ",") ?? "-"
        let matches = back.findString("PDF", withOptions: .caseInsensitive)
        print("pdfkit annotations \(annotations) note \(back.page(at: 1)?.annotations.first { $0.type == "Text" }?.contents ?? "-")")
        print("pdfkit find \(matches.count) on pages \(matches.compactMap { $0.pages.first.map { back.index(for: $0) } })")
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

        // the document built, in a PDFView (continuous, fitted to the width) with a thumbnail strip and buttons
        pdfView.frame = CGRect(x: 16, y: 295, width: view.bounds.width - 32, height: 400)
        pdfView.autoScales = true
        pdfView.delegate = self
        pdfView.accessibilityIdentifier = "pdfview"
        view.addSubview(pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(pageChanged(_:)), name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: pdfView, queue: nil) { [weak self] _ in
            guard let v = self?.pdfView else { return }
            print("pdfview scale changed \(String(format: "%.2f", v.scaleFactor / v.scaleFactorForSizeToFit)) auto \(v.autoScales)")
        }
        NotificationCenter.default.addObserver(forName: .PDFViewAnnotationHit, object: pdfView, queue: nil) { n in
            let hit = n.userInfo?["PDFAnnotationHit"] as? PDFAnnotation
            print("pdfview annotation \(hit?.type ?? "-") \(hit?.contents ?? "")")
        }
        pdfView.isFindInteractionEnabled = true
        pdfView.document = doc
        let strip = PDFThumbnailView(frame: CGRect(x: 16, y: 700, width: view.bounds.width - 32, height: 60))
        strip.pdfView = pdfView
        strip.layoutMode = .horizontal
        strip.thumbnailSize = CGSize(width: 36, height: 48)
        view.addSubview(strip)
        pageLabel.frame = CGRect(x: 16, y: 770, width: 104, height: 30)
        view.addSubview(pageLabel)
        for (i, (title, action)) in [("Previous", #selector(showPrevious)), ("Next", #selector(showNext)), ("Back", #selector(showBack)),
                                                ("Find", #selector(findPDF))].enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.frame = CGRect(x: 120 + CGFloat(i) * 66, y: 770, width: 64, height: 30)
            b.accessibilityIdentifier = title.lowercased()
            b.addTarget(self, action: action, for: .touchUpInside)
            view.addSubview(b)
        }
        pdfView.layoutIfNeeded()
        print("pdfview scale \(String(format: "%.3f", pdfView.scaleFactor)) fit \(String(format: "%.3f", pdfView.scaleFactorForSizeToFit)) mode \(pdfView.displayMode == .singlePageContinuous) pages \(pdfView.document?.pageCount ?? 0)")
    }
}
