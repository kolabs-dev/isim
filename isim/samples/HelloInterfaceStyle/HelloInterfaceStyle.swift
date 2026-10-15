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
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                                     // isim's hosting view has no intrinsic size yet (#463): give the card its size
                                     card.view.widthAnchor.constraint(equalToConstant: 220),
                                     card.view.heightAnchor.constraint(equalToConstant: 64)])
        card.view.backgroundColor = .clear
        card.didMove(toParent: self)
        report()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
