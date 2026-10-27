// Sample: Quick Look Preview extensions on isim (issue #333). The app declares four file types (Info.plist
// UTExportedTypeDeclarations), writes one file of each to Documents and previews them with QLPreviewController; its two
// Quick Look Preview extensions draw them:
// - RecipePreview (view-based): a view controller conforming to QLPreviewingController shows a .recipe (JSON);
// - PreviewProvider (data-based): a QLPreviewProvider answers with a QLPreviewReply: a drawing for a .palette, HTML with
//   an image attachment for a .memo, a PDF document (PDFKit) for an .invoice.
// Launch argument -index N opens the preview at item N. Progress goes to the log as "qlx ..." lines
// (tests/ui/test_quicklook_extensions.py).
// Issue #359: with -thumbnails the app shows QuickLookThumbnailing's thumbnails instead: its RecipeThumbnail extension
// (a QLThumbnailProvider) draws the .recipe's, isim makes those of a PNG, a PDF and a text file, and the .palette (no
// thumbnail extension) gets its icon; the best representations are shown in a grid, and one is saved as a JPEG.
import UIKit
import QuickLook
import QuickLookThumbnailing
import UniformTypeIdentifiers

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = HostViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class HostViewController: UIViewController, QLPreviewControllerDataSource {
    var files: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let contents: [(String, String)] = [
            ("Pancakes.recipe", #"{"title": "Pancakes", "serves": 4, "ingredients": ["2 eggs", "250 g flour", "500 ml milk", "a pinch of salt"]}"#),
            ("Sunset.palette", "#FF5E3A\n#FF9500\n#FFCC00\n#AF52DE\n#5856D6\n"),
            ("Standup.memo", "Standup\nShip the Quick Look extensions\nReview the TextKit flow"),
            ("March.invoice", "Invoice 42\nDesign work: 1200\nHosting: 80"),
        ]
        for (name, text) in contents {
            let url = docs.appendingPathComponent(name)
            try? text.write(to: url, atomically: true, encoding: .utf8)
            files.append(url)
        }
        print("qlx types recipe \(QLPreviewController.canPreview(files[0] as QLPreviewItem))")
        if ProcessInfo.processInfo.arguments.contains("-thumbnails") { showThumbnails(docs) }
    }

    /// QuickLookThumbnailing: the best representation of each file, in a grid of 120x120 cells
    func showThumbnails(_ docs: URL) {
        let png = docs.appendingPathComponent("Photo.png")
        try? UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).pngData { c in
            UIColor.systemBlue.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
            UIColor.systemYellow.setFill(); UIBezierPath(ovalIn: CGRect(x: 110, y: 60, width: 80, height: 80)).fill()
        }.write(to: png)
        let pdf = docs.appendingPathComponent("Page.pdf")
        try? UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 260)).pdfData { c in
            c.beginPage()
            UIColor.systemGreen.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 200, height: 80))
        }.write(to: pdf)
        let text = docs.appendingPathComponent("Notes.txt")
        try? "Shopping\n- eggs\n- flour\n- milk".write(to: text, atomically: true, encoding: .utf8)
        let items = [files[0], png, pdf, text, files[1]]
        let generator = QLThumbnailGenerator.shared
        for (i, url) in items.enumerated() {
            let cell = UIImageView(frame: CGRect(x: 16 + CGFloat(i % 3) * 124, y: 120 + CGFloat(i / 3) * 150, width: 120, height: 120))
            cell.contentMode = .center
            cell.backgroundColor = .secondarySystemBackground
            cell.accessibilityIdentifier = "thumb-\(url.lastPathComponent)"
            view.addSubview(cell)
            let label = UILabel(frame: CGRect(x: cell.frame.minX, y: cell.frame.maxY + 2, width: 120, height: 18))
            label.text = url.lastPathComponent; label.font = .systemFont(ofSize: 12); label.textAlignment = .center
            view.addSubview(label)
            let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 110, height: 110), scale: UIScreen.main.scale,
                                                       representationTypes: .all)
            generator.generateBestRepresentation(for: request) { rep, error in
                DispatchQueue.main.async {
                    guard let rep else { print("qlx thumbnail \(url.lastPathComponent) failed \(error.map { "\($0)" } ?? "-")"); return }
                    cell.image = rep.uiImage
                    let kind = rep.type == .thumbnail ? "thumbnail" : rep.type == .icon ? "icon" : "low"
                    print("qlx thumbnail \(url.lastPathComponent) \(kind) \(Int(rep.uiImage.size.width))x\(Int(rep.uiImage.size.height)) type \(request.contentType.identifier)")
                }
            }
        }
        let updates = QLThumbnailGenerator.Request(fileAt: png, size: CGSize(width: 60, height: 60), scale: 2, representationTypes: .all)
        var kinds: [Int] = []
        generator.generateRepresentations(for: updates) { rep, type, _ in
            DispatchQueue.main.async {
                kinds.append(type.rawValue)
                if kinds.count == 3 { print("qlx thumbnail updates \(kinds.map(String.init).joined(separator: ","))") }
            }
        }
        let saved = docs.appendingPathComponent("Photo-thumb.jpg")
        generator.saveBestRepresentation(for: QLThumbnailGenerator.Request(fileAt: png, size: CGSize(width: 64, height: 64), scale: 1, representationTypes: .thumbnail),
                                         to: saved, as: .jpeg) { error in
            let size = UIImage(contentsOfFile: saved.path)?.size ?? .zero
            print("qlx thumbnail saved \(error == nil) \(Int(size.width))x\(Int(size.height))")
        }
        let missing = QLThumbnailGenerator.Request(fileAt: docs.appendingPathComponent("Missing.png"), size: CGSize(width: 40, height: 40),
                                                   scale: 1, representationTypes: .thumbnail)
        generator.generateBestRepresentation(for: missing) { rep, error in
            let code = (error as? QLThumbnailError)?.code
            print("qlx thumbnail missing \(rep == nil) \(code == .generationFailed)")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard presentedViewController == nil, !ProcessInfo.processInfo.arguments.contains("-thumbnails") else { return }
        let args = ProcessInfo.processInfo.arguments
        var index = 0
        if let i = args.firstIndex(of: "-index"), i + 1 < args.count { index = Int(args[i + 1]) ?? 0 }
        let ql = QLPreviewController()
        ql.dataSource = self
        ql.currentPreviewItemIndex = index
        ql.modalPresentationStyle = .fullScreen
        present(ql, animated: false)
    }
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { files.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { files[index] as QLPreviewItem }
}
