// Sample: accessibility on isim — UIKit elements (labels, values, hints, traits), a container with
// UIAccessibilityElements in its own order, a custom action, an adjustable slider, announcements, Dynamic Type
// (preferredFont + adjustsFontForContentSizeCategory, UIFontMetrics), the Settings > Accessibility values, and
// SwiftUI accessibility modifiers in a UIHostingController. Drive it with isim's VoiceOver (`voiceover on`, `next`, ...).
import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = AccessibilityViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// A drawn bar chart: its bars are UIAccessibilityElements, in the container's own order.
final class StepsChart: UIView {
    let days = [("Mon", 3), ("Tue", 5)]
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        accessibilityElements = days.enumerated().map { i, d in
            let e = UIAccessibilityElement(accessibilityContainer: self)
            e.accessibilityLabel = d.0
            e.accessibilityValue = "\(d.1) thousand steps"
            e.accessibilityFrameInContainerSpace = CGRect(x: 20 + CGFloat(i) * 70, y: 10, width: 50, height: 60)
            return e
        }.reversed()     // read Tue first: the container decides, not the geometry
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        for (i, d) in days.enumerated() {
            UIColor.systemGreen.setFill()
            UIBezierPath(rect: CGRect(x: 20 + CGFloat(i) * 70, y: 70 - CGFloat(d.1) * 10, width: 50, height: CGFloat(d.1) * 10)).fill()
        }
    }
}

struct SwiftUIPart: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var typeSize
    @Environment(\.legibilityWeight) var weight
    @State var rating = 3
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SwiftUI part").font(.headline).accessibilityAddTraits(.isHeader)
            HStack { Image(systemName: "star.fill"); Text("Favorites") }
                .accessibilityElement(children: .combine)
            Text("Rating").accessibilityValue("\(rating) stars")
                .accessibilityAdjustableAction { d in rating += d == .increment ? 1 : -1; print("rating \(rating)") }
            Text("Decoration").accessibilityHidden(true)
            Text("Body text").font(.body).accessibilityIdentifier("swiftui-body")
        }
        .onAppear { print("swiftui env reduceMotion \(reduceMotion) dynamicType \(typeSize) bold \(weight == .bold)") }
    }
}

final class AccessibilityViewController: UIViewController {
    let heading = UILabel(), play = UIButton(type: .system), wifi = UISwitch(), volume = UISlider(), body = UILabel()
    let message = UILabel(), announce = UIButton(type: .system), chart = StepsChart(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let w = view.bounds.width - 40
        heading.text = "Settings"
        heading.font = .boldSystemFont(ofSize: 28)
        heading.accessibilityTraits = .header
        heading.frame = CGRect(x: 20, y: 66, width: w, height: 36)

        play.setTitle("Play", for: .normal)
        play.accessibilityHint = "Plays the song."
        play.frame = CGRect(x: 20, y: 110, width: 80, height: 40)
        play.addAction(UIAction { _ in print("play tapped") }, for: .touchUpInside)

        wifi.accessibilityLabel = "Wi-Fi"
        wifi.isOn = true
        wifi.frame = CGRect(x: 120, y: 114, width: 51, height: 31)
        wifi.addAction(UIAction { [unowned self] _ in print("wifi \(self.wifi.isOn)") }, for: .valueChanged)

        volume.accessibilityLabel = "Volume"
        volume.value = 0.5
        volume.frame = CGRect(x: 20, y: 160, width: w, height: 30)
        volume.addAction(UIAction { [unowned self] _ in print(String(format: "volume %.1f", self.volume.value)) }, for: .valueChanged)

        message.text = "Message from Ana"
        message.frame = CGRect(x: 20, y: 200, width: w, height: 30)
        message.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Delete") { _ in print("deleted message"); return true }]

        chart.frame = CGRect(x: 20, y: 240, width: 180, height: 80)
        chart.accessibilityIdentifier = "chart"

        announce.setTitle("Announce", for: .normal)
        announce.frame = CGRect(x: 220, y: 260, width: 120, height: 40)
        announce.addAction(UIAction { _ in UIAccessibility.post(notification: .announcement, argument: "Download finished") }, for: .touchUpInside)

        body.text = "Dynamic Type body"
        body.font = .preferredFont(forTextStyle: .body)
        body.adjustsFontForContentSizeCategory = true
        body.numberOfLines = 0
        body.accessibilityIdentifier = "body"
        body.frame = CGRect(x: 20, y: 330, width: w, height: 100)
        [heading, play, wifi, volume, message, chart, announce, body].forEach(view.addSubview)

        let host = UIHostingController(rootView: SwiftUIPart())
        addChild(host)
        host.view.frame = CGRect(x: 20, y: 440, width: w, height: 260)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let bigger = UIButton(type: .system)
        bigger.setTitle("Bigger text", for: .normal)
        bigger.accessibilityIdentifier = "bigger"
        bigger.frame = CGRect(x: 20, y: 720, width: 140, height: 40)
        // what Settings > Accessibility > Display & Text Size does: write the system preference
        bigger.addAction(UIAction { _ in UserDefaults(suiteName: ".GlobalPreferences")?.set("UICTContentSizeCategoryAccessibilityXL", forKey: "ISIMContentSizeCategory") }, for: .touchUpInside)
        view.addSubview(bigger)

        report("launch")
        NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: nil) { [weak self] n in
            MainActor.assumeIsolated { self?.report("changed to \(UIApplication.shared.preferredContentSizeCategory.rawValue)") }
        }
        NotificationCenter.default.addObserver(forName: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil, queue: nil) { _ in
            print("voiceover running \(UIAccessibility.isVoiceOverRunning)")
        }
    }
    func report(_ when: String) {
        let metrics = UIFontMetrics(forTextStyle: .body).scaledValue(for: 10)
        print(String(format: "%@: category %@ accessibility %d body %.0f pt scaled10 %.1f bold %d reduceMotion %d contrast %d transparency %d",
                     when, UIApplication.shared.preferredContentSizeCategory.rawValue, UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 0,
                     body.font.pointSize, metrics, UIAccessibility.isBoldTextEnabled ? 1 : 0, UIAccessibility.isReduceMotionEnabled ? 1 : 0,
                     traitCollection.accessibilityContrast == .high ? 1 : 0, UIAccessibility.isReduceTransparencyEnabled ? 1 : 0))
    }
}
