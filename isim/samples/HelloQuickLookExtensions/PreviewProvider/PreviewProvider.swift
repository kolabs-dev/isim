// PreviewProvider: HelloQuickLookExtensions' data-based Quick Look Preview extension (like Xcode's Quick Look Preview
// Extension template with a QLPreviewProvider): a drawing for a .palette, HTML with an image attachment for a .memo,
// a PDF document for an .invoice.
import UIKit
import QuickLook
import PDFKit
import UniformTypeIdentifiers

class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n").map(String.init)
        let name = url.deletingPathExtension().lastPathComponent
        switch url.pathExtension {
        case "palette":
            let colors = lines.compactMap(color(hex:))
            let reply = QLPreviewReply(contextSize: CGSize(width: 300, height: 200), isBitmap: true) { context, reply in
                // a bitmap context: the origin is at the bottom left
                let w = 300 / CGFloat(max(colors.count, 1))
                for (i, c) in colors.enumerated() {
                    context.setFillColor(c.cgColor)
                    context.fill(CGRect(x: CGFloat(i) * w, y: 40, width: w, height: 160))
                }
                context.setFillColor(UIColor.darkGray.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 300, height: 40))
            }
            reply.title = "\(name) palette"
            print("qlx provider palette colours \(colors.count)")
            return reply
        case "memo":
            let dot = await MainActor.run {                    // (UIGraphicsImageRenderer is main-actor isolated)
                UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).pngData { c in
                    UIColor.systemGreen.setFill(); UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 40, height: 40)).fill()
                }
            }
            let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 400, height: 600)) { reply in
                reply.attachments = ["dot.png": QLPreviewReplyAttachment(data: dot, contentType: .png)]
                let items = lines.dropFirst().map { "<li>\($0)</li>" }.joined()
                let html = "<html><body style='font-family: sans-serif'><h1><img src='cid:dot.png' width='40' height='40'> \(lines.first ?? "")</h1><ul>\(items)</ul></body></html>"
                return Data(html.utf8)
            }
            reply.title = "Memo: \(lines.first ?? name)"
            reply.stringEncoding = .utf8
            print("qlx provider memo items \(lines.count - 1) attachment \(QLPreviewReplyAttachment(data: dot, contentType: .png).contentType == .png)")
            return reply
        case "invoice":
            let image = await MainActor.run {
                UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { _ in
                    UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 300, height: 400))
                    UIColor.systemIndigo.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 300, height: 70))
                    for (i, line) in lines.enumerated() {
                        (line as NSString).draw(at: CGPoint(x: 20, y: 90 + CGFloat(i) * 34), withAttributes: [.font: UIFont.systemFont(ofSize: 22)])
                    }
                }
            }
            let reply = QLPreviewReply(forPDFWithPageSize: CGSize(width: 300, height: 400)) { reply in
                let doc = PDFDocument()
                if let page = PDFPage(image: image) { doc.insert(page, at: 0) }
                return doc
            }
            reply.title = lines.first ?? name
            print("qlx provider invoice lines \(lines.count)")
            return reply
        default:
            throw CocoaError(.fileReadUnsupportedScheme)
        }
    }

    func color(hex: String) -> UIColor? {
        guard hex.hasPrefix("#"), let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return UIColor(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}
