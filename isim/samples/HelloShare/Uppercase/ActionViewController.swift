// Uppercase: HelloShare's Action extension. It shows the shared text in capitals and returns it to the host app.
import UIKit
import UniformTypeIdentifiers

class ActionViewController: UIViewController {
    let label = UILabel()
    var text = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.numberOfLines = 0; label.font = .boldSystemFont(ofSize: 24); label.accessibilityIdentifier = "uppercased"
        let done = UIButton(type: .system, primaryAction: UIAction(title: "Done") { [weak self] _ in self?.done() })
        done.accessibilityIdentifier = "done"
        let cancel = UIButton(type: .system, primaryAction: UIAction(title: "Cancel") { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: 3072))
        })
        cancel.accessibilityIdentifier = "cancel"
        let stack = UIStackView(arrangedSubviews: [cancel, label, done])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        // the text comes as a plain-text item provider (and as the item's content text)
        let item = extensionContext?.inputItems.first as? NSExtensionItem
        let provider = item?.attachments?.first { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
        provider?.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { value, _ in
            let s = (value as? String) ?? (value as? NSString).map { $0 as String } ?? item?.attributedContentText?.string ?? ""
            DispatchQueue.main.async {
                self.text = s.uppercased()
                self.label.text = self.text
                NSLog("Uppercase: got “%@”", s)
            }
        }
    }
    func done() {
        let out = NSExtensionItem()
        out.attributedContentText = NSAttributedString(string: text)
        extensionContext?.completeRequest(returningItems: [out], completionHandler: nil)
    }
}
