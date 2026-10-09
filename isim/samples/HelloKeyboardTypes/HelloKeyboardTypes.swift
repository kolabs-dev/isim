// Sample: keyboard types on isim — a text field per UIKeyboardType: number, decimal and phone pads, email, URL,
// Twitter, web search, numbers and punctuation. Each field prints its text as it changes.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = KeyboardTypesViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class KeyboardTypesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let fields: [(String, UIKeyboardType)] = [("number", .numberPad), ("decimal", .decimalPad), ("phone", .phonePad), ("email", .emailAddress),
                                                  ("url", .URL), ("twitter", .twitter), ("websearch", .webSearch), ("numpunct", .numbersAndPunctuation)]
        for (name, type) in fields {
            let f = UITextField()
            f.borderStyle = .roundedRect; f.placeholder = name; f.keyboardType = type
            f.autocapitalizationType = .none; f.autocorrectionType = .no
            f.accessibilityIdentifier = "f-\(name)"
            f.addAction(UIAction { _ in print("text \(name)=\(f.text ?? "")") }, for: .editingChanged)
            stack.addArrangedSubview(f)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
}
