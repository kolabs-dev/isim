// Sample: the further accessibility APIs (#9), each logged with "ax" so the test can check it.
// - Settings > Accessibility values and their notifications (script `accessibility SETTING on|off`)
// - Guided Access: the app delegate's restrictions (script `guidedaccess on|off|restrict ID allow|deny`), feature configuration
// - VoiceOver: attributed labels (heading level, spell out), expanded status, iOS 17 block-based properties, a data
//   table, a picker's accessibility delegate, reading content, scroll status (script `voiceover scroll up`), the
//   focused element, announcement priority
// - custom actions and rotors (attributed names, images, categories, system types), location descriptors, screen
//   coordinate conversions, accessibilityHitTest, image views that grow at the accessibility text sizes
import UIKit

func log(_ s: String) { print("ax \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UIGuidedAccessRestrictionDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = AccessibilityViewController()
        window?.makeKeyAndVisible()
        return true
    }
    // Guided Access: the restriction the person can switch in the Guided Access options
    var guidedAccessRestrictionIdentifiers: [String]? { ["com.example.purchases"] }
    func textForGuidedAccessRestriction(withIdentifier restrictionIdentifier: String) -> String? { "Purchases" }
    func detailTextForGuidedAccessRestriction(withIdentifier restrictionIdentifier: String) -> String? { "Buying in the app" }
    func guidedAccessRestriction(withIdentifier restrictionIdentifier: String, didChange newRestrictionState: UIAccessibility.GuidedAccessRestrictionState) {
        let now = UIAccessibility.guidedAccessRestrictionState(forIdentifier: restrictionIdentifier)
        log("restriction \(restrictionIdentifier) \(newRestrictionState == .deny ? "deny" : "allow") state \(now == .deny ? "deny" : "allow")")
    }
}

// a 2 x 2 data table: VoiceOver says each cell's row and column
final class Cell: UIAccessibilityElement, UIAccessibilityContainerDataTableCell {
    let row: Int, column: Int
    init(container: Any, row: Int, column: Int) {
        self.row = row; self.column = column
        super.init(accessibilityContainer: container)
        accessibilityLabel = "\(["A", "B"][column])\(row + 1)"
        accessibilityFrameInContainerSpace = CGRect(x: CGFloat(column) * 100, y: CGFloat(row) * 35, width: 100, height: 35)
    }
    func accessibilityRowRange() -> NSRange { NSRange(location: row, length: 1) }
    func accessibilityColumnRange() -> NSRange { NSRange(location: column, length: 1) }
}
final class Grid: UIView, UIAccessibilityContainerDataTable {
    lazy var cells: [Cell] = (0..<2).flatMap { r in (0..<2).map { c in Cell(container: self, row: r, column: c) } }
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .systemGray6 }
    required init?(coder: NSCoder) { fatalError() }
    override var accessibilityElements: [Any]? { get { cells } set {} }
    func accessibilityDataTableCellElement(forRow row: Int, column: Int) -> UIAccessibilityContainerDataTableCell? { cells[row * 2 + column] }
    func accessibilityRowCount() -> Int { 2 }
    func accessibilityColumnCount() -> Int { 2 }
}

// a page of text read as a whole by VoiceOver's "read"
final class Page: UILabel, UIAccessibilityReadingContent {
    func accessibilityLineNumber(for point: CGPoint) -> Int { 0 }
    func accessibilityContent(forLineNumber lineNumber: Int) -> String? { lineNumber == 0 ? "Once upon a time." : nil }
    func accessibilityFrame(forLineNumber lineNumber: Int) -> CGRect { accessibilityFrame }
    func accessibilityPageContent() -> String? { "Once upon a time. The end." }
}

final class AccessibilityViewController: UIViewController, UIPickerViewDataSource, UIPickerViewAccessibilityDelegate, UIScrollViewAccessibilityDelegate {
    let sizes = ["Small", "Medium", "Large"]
    var count = 3
    let details = UIButton(type: .system)
    let scroller = UIScrollView()
    var observers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let w = view.bounds.width

        // a heading with a level, from its attributed label
        let chapter = UILabel(frame: CGRect(x: 20, y: 60, width: w - 40, height: 30))
        chapter.text = "Chapter"
        chapter.accessibilityAttributedLabel = NSAttributedString(string: "Chapter", attributes: [.accessibilityTextHeadingLevel: 2])
        chapter.accessibilityTraits = .header
        view.addSubview(chapter)

        // a code read letter by letter
        let code = UILabel(frame: CGRect(x: 20, y: 100, width: w - 40, height: 30))
        code.text = "Code ABC"
        let spelled = NSMutableAttributedString(string: "Code ABC")
        spelled.addAttribute(.accessibilitySpeechSpellOut, value: true, range: NSRange(location: 5, length: 3))
        code.accessibilityAttributedLabel = spelled
        view.addSubview(code)

        // a disclosure button: expanded / collapsed (iOS 18)
        details.setTitle("Details", for: .normal)
        details.frame = CGRect(x: 20, y: 140, width: 120, height: 32)
        if #available(iOS 18.0, *) { details.accessibilityExpandedStatus = .collapsed }
        details.addAction(UIAction { [unowned self] _ in
            if #available(iOS 18.0, *) {
                details.accessibilityExpandedStatus = details.accessibilityExpandedStatus == .collapsed ? .expanded : .collapsed
                log("details \(details.accessibilityExpandedStatus == .expanded ? "expanded" : "collapsed")")
            } else { log("details tapped") }
        }, for: .touchUpInside)
        view.addSubview(details)

        // iOS 17 block-based properties: VoiceOver asks the blocks each time
        let counter = UIView(frame: CGRect(x: 20, y: 180, width: 200, height: 40))
        counter.backgroundColor = .systemGray5
        counter.isAccessibilityElementBlock = { true }
        counter.accessibilityLabelBlock = { "Counter" }
        counter.accessibilityValueBlock = { [unowned self] in "\(count)" }
        counter.accessibilityTraitsBlock = { .adjustable }
        counter.accessibilityIncrementBlock = { [unowned self] in count += 1; log("counter \(count)") }
        counter.accessibilityDecrementBlock = { [unowned self] in count -= 1; log("counter \(count)") }
        view.addSubview(counter)

        view.addSubview(Grid(frame: CGRect(x: 20, y: 230, width: 200, height: 70)))

        // a picker whose wheel has an accessibility label and hint
        let picker = UIPickerView(frame: CGRect(x: 20, y: 310, width: w - 40, height: 216))
        picker.dataSource = self; picker.delegate = self
        picker.selectRow(1, inComponent: 0, animated: false)
        view.addSubview(picker)

        let page = Page(frame: CGRect(x: 20, y: 540, width: w - 40, height: 30))
        page.text = "Once upon a time."
        view.addSubview(page)

        // a paging scroll view with a scroll status
        scroller.frame = CGRect(x: 20, y: 590, width: 300, height: 100)
        scroller.contentSize = CGSize(width: 900, height: 100)
        scroller.isPagingEnabled = true
        scroller.delegate = self
        for i in 0..<3 {
            let l = UILabel(frame: CGRect(x: CGFloat(i) * 300 + 10, y: 30, width: 200, height: 40))
            l.text = ["Photo one", "Photo two", "Photo three"][i]
            scroller.addSubview(l)
        }
        view.addSubview(scroller)

        observe()
        report()
    }

    // ---- picker ----
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { sizes.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { sizes[row] }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) { log("picker selected \(sizes[row])") }
    func pickerView(_ pickerView: UIPickerView, accessibilityLabelForComponent component: Int) -> String? { "Size" }
    func pickerView(_ pickerView: UIPickerView, accessibilityHintForComponent component: Int) -> String? { "Pick a size." }

    // ---- scroll status ----
    func accessibilityScrollStatus(for scrollView: UIScrollView) -> String? {
        "Photo \(Int(scrollView.contentOffset.x / scrollView.bounds.width) + 1) of 3"
    }

    func observe() {
        let nc = NotificationCenter.default
        let notes: [(NSNotification.Name, String, () -> Bool)] = [
            (UIAccessibility.monoAudioStatusDidChangeNotification, "monoAudio", { UIAccessibility.isMonoAudioEnabled }),
            (UIAccessibility.speakScreenStatusDidChangeNotification, "speakScreen", { UIAccessibility.isSpeakScreenEnabled }),
            (UIAccessibility.shakeToUndoDidChangeNotification, "shakeToUndo", { UIAccessibility.isShakeToUndoEnabled }),
            (UIAccessibility.differentiateWithoutColorDidChangeNotification, "differentiate", { UIAccessibility.shouldDifferentiateWithoutColor }),
            (NSNotification.Name("UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification"), "shouldDifferentiate", { UIAccessibility.shouldDifferentiateWithoutColor }),
            (UIAccessibility.guidedAccessStatusDidChangeNotification, "guidedAccess", { UIAccessibility.isGuidedAccessEnabled }),
        ]
        for (name, what, value) in notes {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    log("note \(what) \(value())")
                    if what == "guidedAccess" && value() {
                        UIAccessibility.configureForGuidedAccess(features: [.zoom, .voiceOver], enabled: true) { ok, error in
                            log("configure \(ok) error \(error == nil ? "none" : "\(error!)")")
                        }
                    }
                }
            })
        }
        observers.append(nc.addObserver(forName: UIAccessibility.elementFocusedNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                let f = UIAccessibility.focusedElement(using: .notificationVoiceOver) as? NSObject
                let ids = f?.accessibilityAssistiveTechnologyFocusedIdentifiers()?.map { $0.rawValue }.sorted() ?? []
                log("focused \(f?.accessibilityLabel ?? "-") by \(ids.joined(separator: ","))")
            }
        })
    }

    func report() {
        log("settings guided \(UIAccessibility.isGuidedAccessEnabled) mono \(UIAccessibility.isMonoAudioEnabled) speakScreen \(UIAccessibility.isSpeakScreenEnabled) "
            + "speakSelection \(UIAccessibility.isSpeakSelectionEnabled) assistiveTouch \(UIAccessibility.isAssistiveTouchRunning) "
            + "shakeToUndo \(UIAccessibility.isShakeToUndoEnabled) ear \(UIAccessibility.hearingDevicePairedEar.rawValue)")

        // attributed and plain labels are one value
        let l = UILabel()
        l.accessibilityAttributedLabel = NSAttributedString(string: "Hello", attributes: [.accessibilitySpeechPitch: 1.2])
        let pitch = l.accessibilityAttributedLabel?.attribute(.accessibilitySpeechPitch, at: 0, effectiveRange: nil) as? Double
        l.accessibilityLabel = "Bye"
        log("attributed label \(l.accessibilityLabel ?? "") pitch \(pitch ?? 0) now \(l.accessibilityAttributedLabel?.string ?? "")")
        l.accessibilityLabelBlock = { "From block" }
        log("label block \(l.accessibilityLabel ?? "")")
        l.textualContextBlockCheck()

        // custom actions and rotors
        let a = UIAccessibilityCustomAction(attributedName: NSAttributedString(string: "Copy"), image: UIImage(systemName: "doc.on.doc")) { _ in true }
        if #available(iOS 18.0, *) { a.category = UIAccessibilityCustomAction.editCategory }
        log("action \(a.name) image \(a.image != nil) attributed \(a.attributedName.string)")
        let r = UIAccessibilityCustomRotor(systemType: .heading) { _ in nil }
        log("rotor \(r.name) type \(r.systemRotorType == .heading)")

        // location descriptors, coordinates, hit testing
        let d = UIAccessibilityLocationDescriptor(name: "Drop here", view: view)
        log("descriptor \(d.name) point \(Int(d.point.x)),\(Int(d.point.y))")
        let inner = UIView(frame: CGRect(x: 10, y: 20, width: 30, height: 40))
        view.addSubview(inner)
        let s = UIAccessibility.convertToScreenCoordinates(CGRect(x: 1, y: 2, width: 3, height: 4), in: inner)
        log("screen rect \(Int(s.minX)),\(Int(s.minY)) \(Int(s.width))x\(Int(s.height))")
        let p = UIAccessibility.convertToScreenCoordinates(UIBezierPath(rect: CGRect(x: 0, y: 0, width: 5, height: 5)), in: inner)
        log("screen path \(Int(p.bounds.minX)),\(Int(p.bounds.minY))")
        inner.removeFromSuperview()
        DispatchQueue.main.async { [self] in
            if #available(iOS 18.0, *) {
                let hit = view.accessibilityHitTest(CGPoint(x: 70, y: 150), with: nil) as? UIButton
                log("hit test \(hit?.currentTitle ?? "-")")
            }
            // images that grow at the accessibility text sizes
            let iv = UIImageView(image: UIGraphicsImageRenderer(size: CGSize(width: 17, height: 17)).image { _ in })
            iv.adjustsImageSizeForAccessibilityContentSizeCategory = true
            log("image size \(Int(iv.intrinsicContentSize.width)) category \(UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory)")

            // an announcement with a priority, queued
            let note = NSAttributedString(string: "Saved", attributes: [.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.high,
                                                                         .accessibilitySpeechQueueAnnouncement: true])
            UIAccessibility.post(notification: .announcement, argument: note)
            UIAccessibility.registerGestureConflictWithZoom()
            log("ready")
        }
    }
}

extension UILabel {
    // the textual context: stored, or from its block
    func textualContextBlockCheck() {
        accessibilityTextualContext = .sourceCode
        let stored = accessibilityTextualContext == .sourceCode
        accessibilityTextualContextBlock = { .console }
        log("textual context stored \(stored) block \(accessibilityTextualContext == .console)")
    }
}
