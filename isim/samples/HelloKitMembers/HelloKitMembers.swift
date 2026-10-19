// Sample: small UIKit members on isim (issue #240) — UIView.contentScaleFactor (the screen's scale, then set),
// UIButton.isHeld (a touch held on the button; its configuration update handler sees it), UINavigationItem's
// additionalOverflowItems (a deferred element in the bar's overflow menu), UIWindowScene.isFullScreen and, on
// iOS 26, UIView.Invalidating(.properties) running updateProperties. Part 2 (issue #241): UIApplication.isDefault(_:)
// (Objective-C: -defaultStatusForCategory:error:), NSItemProvider.preferredPresentationStyle, UITextInput's
// supportsAdaptiveImageGlyph, UIPointerLockState.DidChangeMessage and a paste into a UISearchTextField that its paste
// delegate turns into a search token (UISearchTextFieldPasteItem).
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: MembersViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

@available(iOS 26.0, *)
final class CounterView: UIView {
    @UIView.Invalidating(.properties) var count = 0
    override func updateProperties() {
        super.updateProperties()
        print("updateProperties count=\(count)")
    }
}

/// pasted text becomes a search token
final class TokenPaster: NSObject, UITextPasteDelegate {
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, transform item: UITextPasteItem) {
        if let search = item as? UISearchTextFieldPasteItem {
            search.setSearchTokenResult(UISearchToken(icon: UIImage(systemName: "tag"), text: "pasted"))
        } else {
            item.setDefaultResult()
        }
    }
}

final class MembersViewController: UIViewController {
    let paster = TokenPaster()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Members"
        view.backgroundColor = .systemBackground
        navigationItem.additionalOverflowItems = UIDeferredMenuElement.uncached { completion in
            completion([UIAction(title: "Extra action") { _ in print("extra action") }])
        }
        let box = UIView(frame: CGRect(x: 20, y: 140, width: 60, height: 60))
        box.backgroundColor = .systemTeal
        print("contentScaleFactor default=\(box.contentScaleFactor == UIScreen.main.scale)")
        box.contentScaleFactor = 1
        print("contentScaleFactor set=\(box.contentScaleFactor) layer=\(box.layer.contentsScale)")
        view.addSubview(box)

        let button = UIButton(configuration: .filled())
        button.configuration?.title = "Hold me"
        button.accessibilityIdentifier = "hold"
        button.frame = CGRect(x: 20, y: 220, width: 200, height: 50)
        var lastHeld = false
        button.configurationUpdateHandler = { b in
            if b.isHeld != lastHeld { lastHeld = b.isHeld; print("held \(b.isHeld)") }
            b.configuration?.title = b.isHeld ? "Held" : "Hold me"
        }
        view.addSubview(button)

        if #available(iOS 26.0, *) {
            let counter = CounterView(frame: CGRect(x: 20, y: 290, width: 60, height: 30))
            view.addSubview(counter)
            DispatchQueue.main.async {
                counter.count = 1
            }
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("isFullScreen=\(view.window?.windowScene?.isFullScreen ?? false)")
        partTwo()
    }
    func partTwo() {
        if #available(iOS 18.2, *) {
            do { print("isDefault browser=\(try UIApplication.shared.isDefault(.webBrowser))") } catch { print("isDefault error \(error)") }
        }
        let provider = NSItemProvider(object: "attached" as NSString)
        provider.preferredPresentationStyle = .attachment
        print("presentationStyle=\(provider.preferredPresentationStyle == .attachment ? "attachment" : "other")")
        let tv = UITextView()
        if #available(iOS 18.0, *) {
            tv.supportsAdaptiveImageGlyph = true
            let input: UITextInput = tv
            print("supportsAdaptiveImageGlyph=\(input.supportsAdaptiveImageGlyph == true)")
        }
        if #available(iOS 26.0, *) {
            print("pointerLockMessage name=\(UIPointerLockState.DidChangeMessage.name == UIPointerLockState.didChangeNotification)")
        }
        let field = UISearchTextField(frame: CGRect(x: 20, y: 340, width: 300, height: 36))
        field.accessibilityIdentifier = "search"
        field.pasteDelegate = paster
        view.addSubview(field)
        UIPasteboard.general.string = "Token text"
        field.becomeFirstResponder()
        field.paste(nil)
        print("tokens=\(field.tokens.count) text=\(field.text ?? "")")
    }
}
