// The sample's FileProviderUI extension: the Share action shows a sheet (Done completes the request, Cancel cancels
// it); after a sync failed with notAuthenticated it is the sign-in sheet (Done signs in). Printed: "fpui ...".
import UIKit
import FileProvider
import FileProviderUI

final class ActionViewController: FPUIActionExtensionViewController {
    let label = UILabel()
    var signingIn = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.frame = CGRect(x: 20, y: 80, width: 320, height: 60)
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .headline)
        view.addSubview(label)
        for (i, (id, title)) in [("fpui-done", "Done"), ("fpui-cancel", "Cancel")].enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.frame = CGRect(x: 20, y: 160 + CGFloat(i) * 50, width: 200, height: 40)
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.finish(id == "fpui-done") }, for: .primaryActionTriggered)
            view.addSubview(b)
        }
    }

    override func prepare(forAction actionIdentifier: String, itemIdentifiers: [NSFileProviderItemIdentifier]) {
        let names = itemIdentifiers.map(\.rawValue).joined(separator: ", ")
        print("fpui prepare \(actionIdentifier) \(names) domain=\(extensionContext.domainIdentifier?.rawValue ?? "-")"); fflush(stdout)
        label.text = "Share \(names) with your team"
    }

    override func prepare(forError error: any Error) {
        print("fpui error \((error as NSError).code)"); fflush(stdout)
        signingIn = true
        label.text = "Sign in to Cloud Notes"
    }

    func finish(_ done: Bool) {
        print("fpui \(done ? "done" : "cancel")"); fflush(stdout)
        if done && signingIn {
            try? FileManager.default.removeItem(at: Server.signedOutURL)
            print("fpui signed in"); fflush(stdout)
        }
        if done { extensionContext.completeRequest() }
        else { extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue))) }
    }
}
