// Sample: Quick Look and the dictionary on isim — QLPreviewController over the files in the app's Documents
// (an image, a PDF, text and JSON written here; a video and an unknown file the test adds), presented on its own and
// pushed in a navigation controller, swiping between items; UIReferenceLibraryViewController for a term.
import UIKit
import QuickLook

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        writeFiles()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: QuickLookViewController())
        window?.makeKeyAndVisible()
        return true
    }
    func writeFiles() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).pngData { c in
            UIColor.systemOrange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
            UIColor.systemBlue.setFill(); c.fill(CGRect(x: 100, y: 50, width: 100, height: 100))
        }
        try? photo.write(to: docs.appendingPathComponent("1-photo.png"))
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400)).pdfData { c in
            for (i, color) in [UIColor.systemGreen, UIColor.systemPurple].enumerated() {
                c.beginPage()
                color.setFill(); UIRectFill(CGRect(x: 30, y: 30, width: 240, height: 120))
                ("Page \(i + 1)" as NSString).draw(at: CGPoint(x: 30, y: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 28)])
            }
        }
        try? pdf.write(to: docs.appendingPathComponent("2-report.pdf"))
        try? "Quick Look shows text files.\nSecond line.".write(to: docs.appendingPathComponent("3-notes.txt"), atomically: true, encoding: .utf8)
        try? Data("{\"items\": [1, 2, 3]}".utf8).write(to: docs.appendingPathComponent("4-data.json"))
    }
}

final class QuickLookViewController: UIViewController, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    var files: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Quick Look"
        view.backgroundColor = .systemBackground
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        files = ((try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        print("files \(files.map(\.lastPathComponent)) previewable=\(files.filter { QLPreviewController.canPreview($0 as QLPreviewItem) }.count)")
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 8; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        for (title, id, action) in [("Preview all", "preview", #selector(present1)), ("Push the PDF", "push", #selector(push)),
                                    ("Define “apple”", "define", #selector(define))] {
            let b = UIButton(type: .system); b.setTitle(title, for: .normal); b.accessibilityIdentifier = id
            b.addTarget(self, action: action, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
                                     stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor)])
    }
    @objc func present1() {
        let q = QLPreviewController()
        q.dataSource = self; q.delegate = self
        present(q, animated: true)
    }
    @objc func push() {
        let q = QLPreviewController()
        q.dataSource = self
        q.currentPreviewItemIndex = files.firstIndex { $0.pathExtension == "pdf" } ?? 0
        navigationController?.pushViewController(q, animated: true)
    }
    @objc func define() {
        print("dictionary has apple=\(UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: "apple"))")
        present(UIReferenceLibraryViewController(term: "apple"), animated: true)
    }
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { files.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { files[index] as QLPreviewItem }
    func previewControllerWillDismiss(_ controller: QLPreviewController) { print("quick look will dismiss at \(controller.currentPreviewItemIndex)") }
    func previewControllerDidDismiss(_ controller: QLPreviewController) { print("quick look did dismiss") }
}
