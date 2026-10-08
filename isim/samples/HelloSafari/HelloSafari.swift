// Sample: web & communication on isim — SFSafariViewController (delegate: initial load, redirect, finish),
// ASWebAuthenticationSession (OAuth against a local server: consent alert, sign-in page, callback scheme;
// ephemeral session cancelled; SwiftUI's webAuthenticationSession environment action), MessageUI composers
// (canSendMail/canSendText; mail and message sheets when the device has accounts), universal links
// (associated domains in HelloSafari.entitlements -> application(_:continue:restorationHandler:)) and a custom
// URL scheme (application(_:open:options:)).
//   isim run out/apps/HelloSafari.app -server http://127.0.0.1:8765   (samples/HelloWeb/server.py)
import UIKit
import SafariServices
import AuthenticationServices
import MessageUI
import SwiftUI

func log(_ s: String) { print("HelloSafari: " + s) }

var serverURL: String {
    let args = ProcessInfo.processInfo.arguments
    if let i = args.firstIndex(of: "-server"), i + 1 < args.count { return args[i + 1] }
    return "http://127.0.0.1:8765"
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let root = HomeViewController()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: root)
        window?.makeKeyAndVisible()
        return true
    }
    // universal links (applinks:links.isim.example)
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else { return false }
        log("universal link \(url.host ?? "-") path=\(url.path)")
        root.status.text = "link: \(url.path)"
        return true
    }
    // custom scheme
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        log("open url \(url.absoluteString)")
        root.status.text = "opened \(url.host ?? "")"
        return true
    }
}

/// SwiftUI: the webAuthenticationSession environment action
struct SwiftUISignIn: View {
    @Environment(\.webAuthenticationSession) private var session
    @State private var result = "SwiftUI sign-in"
    var body: some View {
        Button(result) {
            Task {
                do {
                    let u = try await session.authenticate(using: URL(string: serverURL + "/oauth/authorize?redirect_uri=hellosafari%3A%2F%2Fswiftui&state=s1")!,
                                                           callbackURLScheme: "hellosafari", preferredBrowserSession: .ephemeral)
                    log("swiftui callback \(u.absoluteString)")
                    result = "SwiftUI: signed in"
                } catch {
                    log("swiftui error \((error as NSError).domain) \((error as NSError).code)")
                    result = "SwiftUI: cancelled"
                }
            }
        }
        .accessibilityIdentifier("signin-swiftui")
    }
}

final class HomeViewController: UIViewController, SFSafariViewControllerDelegate, ASWebAuthenticationPresentationContextProviding,
                                 MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate {
    let status = UILabel()
    var session: ASWebAuthenticationSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Safari & Mail"
        view.backgroundColor = .systemGroupedBackground
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (t, id, sel) in [("Open in SFSafariViewController", "safari", #selector(openSafari)),
                             ("Sign in (ASWebAuthenticationSession)", "signin", #selector(signIn)),
                             ("Sign in (ephemeral)", "signin-eph", #selector(signInEphemeral)),
                             ("Compose mail", "mail", #selector(composeMail)),
                             ("Compose message", "message", #selector(composeMessage))] as [(String, String, Selector)] {
            let c = UIButton.Configuration.filled(); c.title = t; c.cornerStyle = .large; c.baseBackgroundColor = .systemBlue
            let b = UIButton(configuration: c); b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            b.heightAnchor.constraint(equalToConstant: 46).isActive = true
            stack.addArrangedSubview(b)
        }
        let host = UIHostingController(rootView: SwiftUISignIn())
        addChild(host)
        host.view.heightAnchor.constraint(equalToConstant: 46).isActive = true
        host.view.backgroundColor = .clear
        stack.addArrangedSubview(host.view)
        host.didMove(toParent: self)
        status.text = "–"; status.textAlignment = .center; status.accessibilityIdentifier = "status"
        stack.addArrangedSubview(status)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        log("canSendMail=\(MFMailComposeViewController.canSendMail()) canSendText=\(MFMessageComposeViewController.canSendText())")
    }

    // MARK: SFSafariViewController
    @objc func openSafari() {
        let vc = SFSafariViewController(url: URL(string: serverURL + "/redirect")!)
        vc.delegate = self
        present(vc, animated: true)
    }
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        log("safari initial load success=\(didLoadSuccessfully)")
    }
    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) { log("safari redirected to \(URL.path)") }
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) { log("safari done"); status.text = "safari closed" }

    // MARK: ASWebAuthenticationSession
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { view.window! }
    func startSession(ephemeral: Bool) {
        let auth = URL(string: serverURL + "/oauth/authorize?redirect_uri=hellosafari%3A%2F%2Fauth&state=xyz")!
        let s = ASWebAuthenticationSession(url: auth, callbackURLScheme: "hellosafari") { [weak self] url, error in
            if let url {
                let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "code" }?.value ?? "-"
                log("auth callback \(url.absoluteString) code=\(code)")
                self?.status.text = "signed in: \(code)"
            } else if let e = error as? ASWebAuthenticationSessionError {
                log("auth error code=\(e.code.rawValue) canceled=\(e.code == .canceledLogin)")
                self?.status.text = "sign-in cancelled"
            }
        }
        s.presentationContextProvider = self
        s.prefersEphemeralWebBrowserSession = ephemeral
        log("auth start=\(s.start()) ephemeral=\(ephemeral)")
        session = s
    }
    @objc func signIn() { startSession(ephemeral: false) }
    @objc func signInEphemeral() { startSession(ephemeral: true) }

    // MARK: MessageUI
    @objc func composeMail() {
        guard MFMailComposeViewController.canSendMail() else { log("mail unavailable"); status.text = "no mail account"; return }
        let m = MFMailComposeViewController()
        m.mailComposeDelegate = self
        m.setToRecipients(["ada@example.com"])
        m.setSubject("Hello from isim")
        m.setMessageBody("Sent from the HelloSafari sample.", isHTML: false)
        m.addAttachmentData(Data("a,b\n1,2\n".utf8), mimeType: "text/csv", fileName: "data.csv")
        present(m, animated: true)
    }
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        log("mail result=\(result.rawValue)")
        status.text = ["mail cancelled", "mail saved", "mail sent", "mail failed"][result.rawValue]
        controller.dismiss(animated: true)
    }
    @objc func composeMessage() {
        guard MFMessageComposeViewController.canSendText() else { log("messages unavailable"); status.text = "cannot send texts"; return }
        let m = MFMessageComposeViewController()
        m.messageComposeDelegate = self
        m.recipients = ["+1 555 0100"]
        m.body = "On my way"
        present(m, animated: true)
    }
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        log("message result=\(result.rawValue)")
        status.text = ["message cancelled", "message sent", "message failed"][result.rawValue]
        controller.dismiss(animated: true)
    }
}
