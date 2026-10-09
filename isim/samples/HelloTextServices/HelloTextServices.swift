// Sample: text services on isim (UIKit) — Password AutoFill (QuickType suggestions, "Save Password?", strong
// passwords, one-time codes from Messages), dictation (the keyboard's mic; insertDictationResult), Scribble (direct,
// declined by a UIScribbleInteraction delegate, and an indirect element that becomes a search field), inline
// predictions, and a read-only text view whose data detectors make links, phone numbers, addresses and dates tappable.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ServicesViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

func field(_ id: String, _ placeholder: String, _ type: UITextContentType?, y: CGFloat, in view: UIView, secure: Bool = false) -> UITextField {
    let f = UITextField(frame: CGRect(x: 20, y: y, width: view.bounds.width - 40, height: 38))
    f.borderStyle = .roundedRect
    f.placeholder = placeholder
    f.textContentType = type
    f.isSecureTextEntry = secure
    f.autocapitalizationType = .none
    f.accessibilityIdentifier = id
    f.addAction(UIAction { _ in print("\(id) changed: \(f.text ?? "")") }, for: .editingChanged)
    view.addSubview(f)
    return f
}
func button(_ id: String, _ title: String, x: CGFloat, y: CGFloat, in view: UIView, _ action: @escaping () -> Void) {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.frame = CGRect(x: x, y: y, width: 110, height: 36)
    b.accessibilityIdentifier = id
    b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
    view.addSubview(b)
}

/// a field that takes dictation results itself (UITextInput's optional dictation methods)
final class DictationField: UITextField {
    override func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {
        let text = dictationResult.map(\.text).joined()
        print("dictation result: \(text)")
        insertText(text)
    }
    override func dictationRecordingDidEnd() { print("dictation recording did end") }
    override func dictationRecognitionFailed() { print("dictation recognition failed") }
}

final class ServicesViewController: UIViewController, UITextViewDelegate, UIScribbleInteractionDelegate, UIIndirectScribbleInteractionDelegate {
    var user: UITextField!, password: UITextField!
    let searchTarget = UILabel(), search = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Text Services"
        view.backgroundColor = .systemBackground
        let w = view.bounds.width
        user = field("user", "Email or user name", .username, y: 100, in: view)
        user.keyboardType = .emailAddress
        password = field("password", "Password", .password, y: 145, in: view, secure: true)
        button("signIn", "Sign In", x: 20, y: 188, in: view) { [unowned self] in
            print("signed in as \(user.text ?? "")")
            navigationController?.pushViewController(WelcomeViewController(name: user.text ?? ""), animated: true)
        }
        button("signUp", "Sign Up", x: 140, y: 188, in: view) { [unowned self] in navigationController?.pushViewController(SignUpViewController(), animated: true) }
        button("verify", "Verify", x: 260, y: 188, in: view) { [unowned self] in navigationController?.pushViewController(CodeViewController(), animated: true) }

        let dictation = DictationField(frame: CGRect(x: 20, y: 232, width: w - 40, height: 38))
        dictation.borderStyle = .roundedRect
        dictation.placeholder = "Dictate here"
        dictation.accessibilityIdentifier = "dictation"
        view.addSubview(dictation)

        let notes = UITextView(frame: CGRect(x: 20, y: 278, width: w - 40, height: 70))
        notes.font = .systemFont(ofSize: 17)
        notes.layer.borderColor = UIColor.separator.cgColor; notes.layer.borderWidth = 1; notes.layer.cornerRadius = 6
        notes.accessibilityIdentifier = "notes"
        view.addSubview(notes)

        let locked = field("locked", "No handwriting here", nil, y: 356, in: view)
        locked.addInteraction(UIScribbleInteraction(delegate: self))           // declines Scribble

        searchTarget.frame = CGRect(x: 20, y: 400, width: w - 40, height: 38)
        searchTarget.text = "  🔍 Search the shop"
        searchTarget.textColor = .secondaryLabel
        searchTarget.backgroundColor = .secondarySystemBackground
        searchTarget.layer.cornerRadius = 8; searchTarget.clipsToBounds = true
        searchTarget.isUserInteractionEnabled = true
        searchTarget.accessibilityIdentifier = "searchTarget"
        searchTarget.addInteraction(UIIndirectScribbleInteraction(delegate: self))   // writing here opens the search field
        view.addSubview(searchTarget)
        search.frame = searchTarget.frame
        search.borderStyle = .roundedRect
        search.placeholder = "Search"
        search.isHidden = true
        search.accessibilityIdentifier = "search"
        search.addAction(UIAction { [unowned self] _ in print("search: \(search.text ?? "")") }, for: .editingChanged)
        view.addSubview(search)

        let info = UITextView(frame: CGRect(x: 20, y: 448, width: w - 40, height: 150))
        info.isEditable = false
        info.font = .systemFont(ofSize: 16)
        info.dataDetectorTypes = .all
        info.delegate = self
        info.text = "Visit shop.isim.dev\nCall +1 (555) 010-2030\nStore: 1 Infinite Loop, Cupertino, CA 95014\nSale ends December 24, 2026\nOur buyer lands on UA 123"
        info.accessibilityIdentifier = "info"
        view.addSubview(info)
        print("UIScribbleInteraction.isPencilInputExpected: \(UIScribbleInteraction.isPencilInputExpected)")
    }

    // detected items (iOS 17 delegate)
    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content else { return defaultAction }
        print("primary action for \((textView.text as NSString).substring(with: textItem.range)) -> \(url.absoluteString)")
        if url.scheme == "tel" { return UIAction(title: "Call") { _ in print("calling \(url.absoluteString)") } }
        return defaultAction
    }
    func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
        print("menu for \((textView.text as NSString).substring(with: textItem.range)): \(defaultMenu.children.map(\.title))")
        let share = UIAction(title: "Share Store") { _ in print("share store") }
        return UITextItem.MenuConfiguration(menu: UIMenu(children: defaultMenu.children + [share]))
    }

    // Scribble: the locked field declines
    func scribbleInteraction(_ interaction: UIScribbleInteraction, shouldBeginAt location: CGPoint) -> Bool {
        print("scribble asked at \(Int(location.x)),\(Int(location.y)): declined")
        return false
    }

    // indirect Scribble: the search label is one element; writing on it shows the real field
    func indirectScribbleInteraction(_ interaction: UIInteraction, requestElementsIn rect: CGRect, completion: @escaping ([String]) -> Void) {
        completion(["search"])
    }
    func indirectScribbleInteraction(_ interaction: UIInteraction, isElementFocused elementIdentifier: String) -> Bool {
        search.isFirstResponder
    }
    func indirectScribbleInteraction(_ interaction: UIInteraction, frameForElement elementIdentifier: String) -> CGRect {
        searchTarget.bounds
    }
    func indirectScribbleInteraction(_ interaction: UIInteraction, focusElementIfNeeded elementIdentifier: String,
                                     referencePoint focusReferencePoint: CGPoint, completion: @escaping ((UIResponder & UITextInput)?) -> Void) {
        print("focus element \(elementIdentifier)")
        search.isHidden = false
        searchTarget.isHidden = true
        search.becomeFirstResponder()
        completion(search)
    }
    func indirectScribbleInteraction(_ interaction: UIInteraction, willBeginWritingInElement elementIdentifier: String) {
        print("will begin writing in \(elementIdentifier)")
    }
    func indirectScribbleInteraction(_ interaction: UIInteraction, didFinishWritingInElement elementIdentifier: String) {
        print("did finish writing in \(elementIdentifier)")
    }
}

final class WelcomeViewController: UIViewController {
    let name: String
    init(name: String) { self.name = name; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Welcome"
        let l = UILabel(frame: CGRect(x: 20, y: 120, width: view.bounds.width - 40, height: 40))
        l.text = "Welcome, \(name)"
        l.accessibilityIdentifier = "welcome"
        view.addSubview(l)
    }
}

final class SignUpViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Sign Up"
        let u = field("newUser", "Email", .username, y: 110, in: view)
        let p = field("newPassword", "New password", .newPassword, y: 160, in: view, secure: true)
        p.passwordRules = UITextInputPasswordRules(descriptor: "required: lower; required: upper; required: digit; minlength: 20;")
        let c = field("confirmPassword", "Confirm password", .newPassword, y: 210, in: view, secure: true)
        button("create", "Create", x: 20, y: 256, in: view) { [unowned self] in
            print("account created for \(u.text ?? "") (password \(p.text?.count ?? 0) characters, confirmed \(p.text == c.text))")
            navigationController?.pushViewController(WelcomeViewController(name: u.text ?? ""), animated: true)
        }
    }
}

final class CodeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Verify"
        let f = field("code", "Code", .oneTimeCode, y: 110, in: view)
        f.keyboardType = .numberPad
    }
}
