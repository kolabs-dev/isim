import Core           // macros from the local package's macro target (CoreMacros)
import UIKit

final class ViewController: UIViewController, UITextFieldDelegate {
    private var model = Model()
    private let countLabel = UILabel()
    private let echoLabel = UILabel()
    private let field = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Toolchain"
        view.backgroundColor = .systemBackground
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startCount"), i + 1 < args.count, let n = Int(args[i + 1]) { model.count = n }
        let mode = ProcessInfo.processInfo.environment["UITEST_MODE"] ?? "normal"

        func label(_ text: String, _ id: String) -> UILabel {
            let l = UILabel(); l.text = text; l.accessibilityIdentifier = id; l.numberOfLines = 0; return l
        }
        let greeting = label(Model.greeting("isim"), "greeting")
        greeting.font = .preferredFont(forTextStyle: .title2)
        let sums = label("MathKit \(Model.mathKitSum()) · XCFramework \(Model.xcframeworkSum()) · Units \(Model.units())", "sums")
        let flavor = label("\(Model.buildFlavor) · \(Model.greetingWord) · \(Model.legacy())", "flavor")
        let modeLabel = label("mode: \(mode)", "mode")
        countLabel.accessibilityIdentifier = "count"
        echoLabel.accessibilityIdentifier = "echo"
        echoLabel.text = "echo: -"
        let button = UIButton(type: .system)
        button.setTitle("Add", for: .normal)
        button.accessibilityIdentifier = "increment"
        button.addTarget(self, action: #selector(add), for: .touchUpInside)
        field.placeholder = "Name"
        field.borderStyle = .roundedRect
        field.accessibilityIdentifier = "name"
        field.delegate = self
        let toggle = UISwitch()
        toggle.accessibilityIdentifier = "toggle"
        let stack = UIStackView(arrangedSubviews: [greeting, sums, flavor, modeLabel, countLabel, button, field, echoLabel, toggle])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        refresh()
        print("HelloToolchain: \(greeting.text!) | \(sums.text!) | \(flavor.text!)")
        let (value, code) = #stringify(Model.mathKitSum() * 2)
        print("HelloToolchain macros: \(code) = \(value), \(Flavor.caseCount) flavors")
    }

    @objc private func add() { model.increment(); refresh() }
    private func refresh() { countLabel.text = "Count: \(model.count)" }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        echoLabel.text = "echo: \(textField.text ?? "")"
        textField.resignFirstResponder()
        return true
    }
}

/// The package macros at work: @CaseCount adds `caseCount`.
@CaseCount
enum Flavor { case vanilla, chocolate, strawberry }

// Previews (Xcode's canvas; on isim they compile and type-check)
#Preview("Toolchain") { ViewController() }
#Preview(traits: .landscapeLeft) {
    let label = UILabel()
    label.text = "landscape"
    return label
}

