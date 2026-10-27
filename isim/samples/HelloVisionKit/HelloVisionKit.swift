// Sample: VisionKit on isim (issue #379): DataScannerViewController on the simulated camera (ISIM_CAMERA), Live Text
// (ImageAnalyzer and ImageAnalysisInteraction on a picture), and the document camera (VNDocumentCameraViewController).
// scene.png (made by the build) is a page with "HELLO ISIM" and a QR code on a dark desk; test_visionkit.py shows it
// through ISIM_CAMERA. Without a camera the scanner and the document camera are not supported, like the Simulator.
import UIKit
import VisionKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: MenuViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloVisionKit: %@", s) }
func pt(_ p: CGPoint) -> String { "\(Int(p.x.rounded())),\(Int(p.y.rounded()))" }
func describe(_ item: RecognizedItem) -> String {
    switch item {
    case .barcode(let b): return "barcode:\(b.payloadStringValue ?? "")"
    case .text(let t): return "text:\(t.transcript)"
    }
}

final class MenuViewController: UIViewController, DataScannerViewControllerDelegate, VNDocumentCameraViewControllerDelegate {
    let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "VisionKit"
        view.backgroundColor = .systemBackground
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 16
        stack.frame = CGRect(x: 24, y: 140, width: view.bounds.width - 48, height: 300)
        for (t, id, sel) in [("Scan Text and Codes", "scan", #selector(scan)), ("Live Text", "livetext", #selector(liveText)),
                             ("Scan Document", "document", #selector(document))] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal); b.titleLabel?.font = .systemFont(ofSize: 20); b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        status.accessibilityIdentifier = "status"; status.numberOfLines = 0; status.textAlignment = .center
        stack.addArrangedSubview(status)
        view.addSubview(stack)
        log("scanner supported=\(DataScannerViewController.isSupported) available=\(DataScannerViewController.isAvailable) " +
            "documentCamera=\(VNDocumentCameraViewController.isSupported) analyzer=\(ImageAnalyzer.isSupported)")
    }

    // MARK: data scanner
    @objc func scan() {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr]), .text()], qualityLevel: .fast,
                                                recognizesMultipleItems: true, isHighlightingEnabled: true)
        scanner.delegate = self
        let close = UIButton(type: .system)
        close.setTitle("Done", for: .normal); close.setTitleColor(.white, for: .normal); close.accessibilityIdentifier = "done"
        close.frame = CGRect(x: 20, y: 60, width: 80, height: 44)
        close.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        let photo = UIButton(type: .system)
        photo.setTitle("Photo", for: .normal); photo.setTitleColor(.white, for: .normal); photo.accessibilityIdentifier = "photo"
        photo.frame = CGRect(x: view.bounds.width - 100, y: 60, width: 80, height: 44)
        photo.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
        scanner.overlayContainerView.addSubview(close)
        scanner.overlayContainerView.addSubview(photo)
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: false) {
            do {
                try scanner.startScanning()
                log("scanning=\(scanner.isScanning) zoom=\(scanner.minZoomFactor)...\(scanner.maxZoomFactor)")
            } catch { log("startScanning throws \(error)") }
            Task {
                for await items in scanner.recognizedItems where !items.isEmpty {
                    log("stream items=\(items.count)")
                    break
                }
            }
        }
    }
    @objc func closeScanner() {
        guard let s = presentedViewController as? DataScannerViewController else { return }
        s.stopScanning()
        log("stopped scanning=\(s.isScanning)")
        dismiss(animated: false)
    }
    @objc func takePhoto() {
        guard let s = presentedViewController as? DataScannerViewController else { return }
        Task {
            do { let p = try await s.capturePhoto(); log("photo \(Int(p.size.width))x\(Int(p.size.height))") }
            catch { log("photo error \(error)") }
        }
    }
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        for i in addedItems { log("added \(describe(i)) center=\(pt(i.bounds._center))") }
    }
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        log("tapped \(describe(item))")
        status.text = describe(item)
    }

    // MARK: Live Text
    @objc func liveText() { navigationController?.pushViewController(LiveTextViewController(), animated: false) }

    // MARK: document camera
    @objc func document() {
        guard VNDocumentCameraViewController.isSupported else { log("document camera unsupported"); return }
        let camera = VNDocumentCameraViewController()
        camera.delegate = self
        present(camera, animated: false)
    }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        let page = scan.imageOfPage(at: 0)
        log("document pages=\(scan.pageCount) title=\(scan.title) page=\(Int(page.size.width))x\(Int(page.size.height))")
        dismiss(animated: false)
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        log("document cancelled")
        dismiss(animated: false)
    }
}

extension RecognizedItem.Bounds {
    var _center: CGPoint { CGPoint(x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4, y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4) }
}

final class LiveTextViewController: UIViewController, ImageAnalysisInteractionDelegate {
    let imageView = UIImageView()
    let interaction = ImageAnalysisInteraction()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Live Text"
        view.backgroundColor = .systemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 0, y: 120, width: view.bounds.width, height: view.bounds.width * 0.75)
        imageView.image = UIImage(contentsOfFile: Bundle.main.path(forResource: "scene", ofType: "png") ?? "")
        imageView.accessibilityIdentifier = "picture"
        view.addSubview(imageView)
        interaction.delegate = self
        interaction.preferredInteractionTypes = .automatic
        imageView.addInteraction(interaction)
        guard let image = imageView.image else { log("livetext no picture"); return }
        Task {
            do {
                let analysis = try await ImageAnalyzer().analyze(image, configuration: ImageAnalyzer.Configuration([.text, .machineReadableCode]))
                interaction.analysis = analysis
                log("analysis transcript=\(analysis.transcript.replacingOccurrences(of: "\n", with: "|")) text=\(analysis.hasResults(for: .text)) " +
                    "codes=\(analysis.hasResults(for: .machineReadableCode)) button=\(interaction.liveTextButtonVisible)")
                if let r = textRect() {
                    let c = imageView.convert(CGPoint(x: r.midX, y: r.midY), to: view)
                    log("text center=\(pt(c)) hasText=\(interaction.hasText(at: CGPoint(x: r.midX, y: r.midY))) corner=\(interaction.hasText(at: .zero))")
                }
            } catch { log("analysis error \(error)") }
        }
    }
    /// where the analysis found "HELLO" (the interaction's text hit test, sampled on a grid)
    func textRect() -> CGRect? {
        let b = imageView.bounds
        var hits: [CGPoint] = []
        for y in stride(from: 0, to: b.height, by: 4) { for x in stride(from: 0, to: b.width, by: 4) where interaction.analysisHasText(at: CGPoint(x: x, y: y)) { hits.append(CGPoint(x: x, y: y)) } }
        guard let x0 = hits.map(\.x).min(), let x1 = hits.map(\.x).max(), let y0 = hits.map(\.y).min(), let y1 = hits.map(\.y).max() else { return nil }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
    func interaction(_ interaction: ImageAnalysisInteraction, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
        log("highlighted=\(highlightSelectedItems)")
    }
    func textSelectionDidChange(_ interaction: ImageAnalysisInteraction) {
        log("selected=\(interaction.selectedText) ranges=\(interaction.selectedRanges.count)")
    }
}
