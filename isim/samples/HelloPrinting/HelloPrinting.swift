// Sample: printing on isim — UIPrintInteractionController with a simple text formatter (several pages, orientation),
// markup, a view, a custom UIPrintPageRenderer (header, footer, content), printing items (an image, a PDF), the
// printer picker and printing straight to the chosen printer. isim's simulated printer writes each job as a PDF to
// $ISIM_DATA/Printer.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = PrintingViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// three pages with a header, a footer and a coloured block per page
final class ReportRenderer: UIPrintPageRenderer {
    override init() { super.init(); headerHeight = 30; footerHeight = 30 }
    override var numberOfPages: Int { 3 }
    override func drawHeaderForPage(at pageIndex: Int, in headerRect: CGRect) {
        ("Quarterly report" as NSString).draw(at: headerRect.origin, withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
    }
    override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
        ("Page \(pageIndex + 1) of \(numberOfPages)" as NSString).draw(at: CGPoint(x: footerRect.minX, y: footerRect.minY + 8), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
    }
    override func drawContentForPage(at pageIndex: Int, in contentRect: CGRect) {
        [UIColor.systemRed, .systemGreen, .systemBlue][pageIndex].setFill()
        UIRectFill(CGRect(x: contentRect.minX, y: contentRect.minY + 20, width: contentRect.width, height: 120))
    }
}

final class PrintingViewController: UIViewController, UIPrintInteractionControllerDelegate {
    var printer: UIPrinter?
    let chart = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        print("printing available=\(UIPrintInteractionController.isPrintingAvailable) utis=\(UIPrintInteractionController.printableUTIs.contains("com.adobe.pdf"))")
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 6; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let actions: [(String, String, () -> Void)] = [
            ("Print text", "print-text", { [unowned self] in
                let text = (1...150).map { "Line \($0): the quick brown fox jumps over the lazy dog." }.joined(separator: "\n")
                let f = UISimpleTextPrintFormatter(text: text); f.font = .systemFont(ofSize: 12)
                start("Long Text") { $0.printFormatter = f; $0.showsPaperOrientation = true }
            }),
            ("Print markup", "print-markup", { [unowned self] in
                start("Markup") { $0.printFormatter = UIMarkupTextPrintFormatter(markupText: "<h1>Hello</h1><p>From <b>isim</b> &amp; friends</p><ul><li>one</li><li>two</li></ul>") }
            }),
            ("Print a view", "print-view", { [unowned self] in start("Chart") { $0.printFormatter = chart.viewPrintFormatter() } }),
            ("Print report", "print-report", { [unowned self] in start("Report") { $0.printPageRenderer = ReportRenderer() } }),
            ("Print image", "print-image", { [unowned self] in
                let img = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { c in UIColor.systemOrange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 300)) }
                start("Photo") { $0.printingItem = img }
            }),
            ("Print PDF", "print-pdf", { [unowned self] in
                let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400)).pdfData { c in c.beginPage(); c.beginPage() }
                print("can print pdf data=\(UIPrintInteractionController.canPrint(pdf))")
                start("Two Pages") { $0.printingItem = pdf }
            }),
            ("Choose printer", "pick-printer", { [unowned self] in
                let p = UIPrinterPickerController(initiallySelectedPrinter: nil)
                p.present(animated: true) { picker, selected, _ in
                    self.printer = picker.selectedPrinter
                    print("picked printer selected=\(selected) name=\(picker.selectedPrinter?.displayName ?? "none") color=\(picker.selectedPrinter?.supportsColor ?? false)")
                }
            }),
            ("Print to printer", "print-direct", { [unowned self] in
                guard let printer else { print("no printer"); return }
                let c = UIPrintInteractionController.shared
                c.printInfo = info("Direct"); c.printFormatter = UISimpleTextPrintFormatter(text: "Sent straight to the printer.")
                c.print(to: printer) { _, done, error in print("direct print completed=\(done) error=\(error.map { "\($0)" } ?? "none")") }
            }),
        ]
        for (title, id, run) in actions {
            let b = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in run() })
            b.accessibilityIdentifier = id
            stack.addArrangedSubview(b)
        }
        chart.backgroundColor = .systemTeal
        chart.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chart)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            chart.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
            chart.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            chart.widthAnchor.constraint(equalToConstant: 200), chart.heightAnchor.constraint(equalToConstant: 120),
        ])
    }
    func info(_ name: String) -> UIPrintInfo { let i = UIPrintInfo.printInfo(); i.jobName = name; i.outputType = .general; return i }
    func start(_ job: String, _ configure: (UIPrintInteractionController) -> Void) {
        let c = UIPrintInteractionController.shared
        c.printInfo = info(job); c.delegate = self; c.showsPaperOrientation = false
        configure(c)
        c.present(animated: true) { _, completed, error in print("print \(job) completed=\(completed) error=\(error.map { "\($0)" } ?? "none")") }
    }
    func printInteractionControllerDidFinishJob(_ printInteractionController: UIPrintInteractionController) {
        print("job finished \(printInteractionController.printInfo?.jobName ?? "")")
    }
}
