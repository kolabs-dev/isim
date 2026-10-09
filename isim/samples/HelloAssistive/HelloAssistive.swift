// Sample: assistive technologies on isim (UIKit) — the VoiceOver rotor (a custom rotor, headings, actions, adjust
// value), Switch Control (item scanning), Voice Control (tap by name / user input labels / numbers, scrolling), the
// Large Content Viewer at accessibility text sizes, and feedback generators (shown as rings, no haptic hardware).
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = AssistiveViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class AssistiveViewController: UIViewController, UILargeContentViewerInteractionDelegate {
    let scroll = UIScrollView()
    var buttons: [String: UIButton] = [:]
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        scroll.frame = view.bounds
        scroll.contentSize = CGSize(width: view.bounds.width, height: 1600)
        scroll.accessibilityIdentifier = "scroll"
        view.addSubview(scroll)
        var y: CGFloat = 70
        func heading(_ t: String) {
            let l = UILabel(frame: CGRect(x: 20, y: y, width: 300, height: 30)); l.text = t; l.font = .boldSystemFont(ofSize: 22)
            l.accessibilityTraits = .header
            scroll.addSubview(l); y += 40
        }
        func button(_ t: String, _ action: @escaping () -> Void) -> UIButton {
            let b = UIButton(type: .system); b.setTitle(t, for: .normal); b.frame = CGRect(x: 20, y: y, width: 200, height: 36)
            b.accessibilityIdentifier = t.lowercased()
            b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
            scroll.addSubview(b); y += 44; buttons[t] = b
            return b
        }
        heading("Fruits")
        _ = button("Apple") { print("tapped Apple") }
        _ = button("Banana") { print("tapped Banana") }
        heading("Vegetables")
        _ = button("Carrot") { print("tapped Carrot") }
        let mail = button("Mail") { print("tapped Mail") }
        mail.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Archive") { _ in print("action Archive"); return true },
            UIAccessibilityCustomAction(name: "Flag") { _ in print("action Flag"); return true },
        ]
        let send = button("➤") { print("tapped Send") }
        send.accessibilityLabel = "Send message"
        send.accessibilityUserInputLabels = ["Send", "Submit"]               // Voice Control names
        let slider = UISlider(frame: CGRect(x: 20, y: y, width: 250, height: 30))
        slider.value = 0.5; slider.accessibilityLabel = "Volume"; slider.accessibilityIdentifier = "volume"
        slider.addAction(UIAction { _ in print(String(format: "volume %.1f", slider.value)) }, for: .valueChanged)
        scroll.addSubview(slider); y += 50
        // the favourites rotor: Banana and Carrot
        let favourites = UIAccessibilityCustomRotor(name: "Favorites") { [unowned self] predicate in
            let items = [buttons["Banana"]!, buttons["Carrot"]!]
            let current = predicate.currentItem.targetElement as? UIButton
            let i = current.flatMap { items.firstIndex(of: $0) }
            let next: Int? = predicate.searchDirection == .next ? (i.map { $0 + 1 } ?? 0) : (i.map { $0 - 1 } ?? items.count - 1)
            guard let n = next, n >= 0, n < items.count else { return nil }
            return UIAccessibilityCustomRotorItemResult(targetElement: items[n], targetRange: nil)
        }
        view.accessibilityCustomRotors = [favourites]
        // large content viewer: a toolbar of symbol buttons
        let bar = UIView(frame: CGRect(x: 0, y: y, width: view.bounds.width, height: 60))
        bar.backgroundColor = .secondarySystemBackground
        bar.accessibilityIdentifier = "bar"
        for (i, sym) in ["house", "star", "gear"].enumerated() {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: sym), for: .normal)
            b.frame = CGRect(x: 40 + CGFloat(i) * 120, y: 10, width: 44, height: 40)
            b.showsLargeContentViewer = true
            b.largeContentTitle = sym.capitalized
            b.accessibilityLabel = sym.capitalized
            bar.addSubview(b)
        }
        bar.addInteraction(UILargeContentViewerInteraction(delegate: self))
        scroll.addSubview(bar); y += 80
        // feedback generators
        _ = button("Impact") { [unowned self] in
            if #available(iOS 17.5, *) { UIImpactFeedbackGenerator(style: .heavy, view: view).impactOccurred(intensity: 1, at: CGPoint(x: 300, y: 120)) }
            else { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
        }
        _ = button("Success") { [unowned self] in
            if #available(iOS 17.5, *) { UINotificationFeedbackGenerator(view: view).notificationOccurred(.success, at: CGPoint(x: 300, y: 220)) }
            else { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        _ = button("Select") { UISelectionFeedbackGenerator().selectionChanged() }
        _ = button("Far") { print("tapped Far") }
        buttons["Far"]!.frame.origin.y = 1400                                   // below the first screen
        NotificationCenter.default.addObserver(forName: UIAccessibility.switchControlStatusDidChangeNotification, object: nil, queue: .main) { _ in
            print("switch control running \(UIAccessibility.isSwitchControlRunning)")
        }
    }
    func largeContentViewerInteraction(_ interaction: UILargeContentViewerInteraction, didEndOn item: UILargeContentViewerItem?, at point: CGPoint) {
        print("large content ended on \(item?.largeContentTitle ?? "nil")")
    }
}
