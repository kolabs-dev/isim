// Sample: Info.plist UIUserInterfaceStyle (issue #234). The app forces Light: it stays light when the device is in Dark
// Mode (`--dark`, the `appearance dark` script command), with its system colours, alerts and SwiftUI content. The test
// also runs copies with Dark and Automatic. Each change of the app's style prints "st style N" (1 light, 2 dark).
import SwiftUI
import UIKit

func say(_ s: String) { print("st " + s); fflush(stdout) }

struct Card: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        Text("SwiftUI \(scheme == .dark ? "dark" : "light")")
            .font(.title3)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .onAppear { say("swiftui \(scheme == .dark ? "dark" : "light")") }
    }
}

final class ViewController: UIViewController {
    let label = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.font = .preferredFont(forTextStyle: .title1)
        label.textColor = .label
        let card = UIHostingController(rootView: Card())
        addChild(card)
        let stack = UIStackView(arrangedSubviews: [label, card.view])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        // the hosting view sizes to its content (its intrinsicContentSize, issue #463): no constraints of its own
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        card.view.backgroundColor = .clear
        card.didMove(toParent: self)
        self.card = card
        report()
    }
    var card: UIHostingController<Card>?
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let card {
            view.layoutIfNeeded()
            let f = card.view.frame, i = card.view.intrinsicContentSize
            say("card \(Int(f.width))x\(Int(f.height)) intrinsic \(Int(i.width))x\(Int(i.height))")
        }
        // flexible content has no intrinsic size along the axes it fills; sizingOptions keeps preferredContentSize
        let flexible = UIHostingController(rootView: Color.orange.frame(height: 30)).view.intrinsicContentSize
        say("flexible width \(flexible.width == UIView.noIntrinsicMetric ? "none" : "\(flexible.width)") height \(Int(flexible.height))")
        let sized = UIHostingController(rootView: Text("Sized").padding())
        sized.sizingOptions = .preferredContentSize
        sized.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        sized.view.layoutIfNeeded()
        say("preferred \(sized.preferredContentSize.width > 40 && sized.preferredContentSize.height > 30)")
        say("screen \(UIScreen.main.traitCollection.userInterfaceStyle.rawValue) plist \(Bundle.main.object(forInfoDictionaryKey: "UIUserInterfaceStyle") as? String ?? "-")")
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle { report() }
    }
    func report() {
        let s = traitCollection.userInterfaceStyle
        label.text = s == .dark ? "Dark" : "Light"
        say("style \(s.rawValue)")
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
