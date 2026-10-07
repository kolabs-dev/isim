// ShareNote: HelloShare's Share extension, the standard compose sheet (like Xcode's Share Extension template).
import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = "Add a comment"
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let types = items.flatMap { $0.attachments ?? [] }.flatMap { $0.registeredTypeIdentifiers }
        NSLog("ShareNote: %ld input item(s), attachments %@", items.count, types.joined(separator: ","))
    }
    override func isContentValid() -> Bool {
        let n = contentText?.count ?? 0
        charactersRemaining = NSNumber(value: 140 - n)
        return n > 0 && n <= 140
    }
    override func didSelectPost() {
        let providers = (extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []
        let text = contentText ?? ""
        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            p.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    NSLog("ShareNote: posted “%@” with %@", text, (item as? URL)?.absoluteString ?? "no URL")
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            }
        } else {
            NSLog("ShareNote: posted “%@”", text)
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    override func configurationItems() -> [Any]! {
        let folder = SLComposeSheetConfigurationItem()
        folder?.title = "Folder"
        folder?.value = "Inbox"
        folder?.tapHandler = { NSLog("ShareNote: folder tapped") }
        return [folder as Any]
    }
}
