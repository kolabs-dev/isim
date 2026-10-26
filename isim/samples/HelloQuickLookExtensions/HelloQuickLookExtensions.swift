// Sample: Quick Look Preview extensions on isim (issue #333). The app declares four file types (Info.plist
// UTExportedTypeDeclarations), writes one file of each to Documents and previews them with QLPreviewController; its two
// Quick Look Preview extensions draw them:
// - RecipePreview (view-based): a view controller conforming to QLPreviewingController shows a .recipe (JSON);
// - PreviewProvider (data-based): a QLPreviewProvider answers with a QLPreviewReply: a drawing for a .palette, HTML with
//   an image attachment for a .memo, a PDF document (PDFKit) for an .invoice.
// Launch argument -index N opens the preview at item N. Progress goes to the log as "qlx ..." lines
// (tests/ui/test_quicklook_extensions.py).
import UIKit
import QuickLook

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
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard presentedViewController == nil else { return }
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
