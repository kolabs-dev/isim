// HelloVault's single sign-on extension (an identity provider's): without UI it answers with OAuth tokens; when the
// app asks for prompt=login it shows an approval screen and answers with an Authorization header.
import UIKit
import AuthenticationServices

func slog(_ s: String) { print("vault sso: \(s)"); fflush(stdout) }

final class SSOViewController: UIViewController, ASAuthorizationProviderExtensionAuthorizationRequestHandler {
    var request: ASAuthorizationProviderExtensionAuthorizationRequest?

    func beginAuthorization(with request: ASAuthorizationProviderExtensionAuthorizationRequest) {
        self.request = request
        let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        slog("begin \(request.url.host ?? "-") caller=\(request.callerBundleIdentifier) realm=\(request.realm) ui=\(request.isUserInterfaceEnabled)")
        if items.contains(where: { $0.name == "prompt" && $0.value == "login" }) {
            request.presentAuthorizationViewController { shown, error in slog("approval screen shown=\(shown)") }
            return
        }
        if items.contains(where: { $0.name == "prompt" && $0.value == "skip" }) { request.doNotHandle(); return }
        let body = try! JSONSerialization.data(withJSONObject: ["access_token": "at-123", "id_token": "it-456", "token_type": "Bearer"])
        let response = HTTPURLResponse(url: request.url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        request.complete(httpResponse: response, httpBody: body)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 80, width: view.bounds.width - 40, height: 60))
        label.text = "Sign in to Vault ID"; label.textAlignment = .center; label.font = .boldSystemFont(ofSize: 20)
        view.addSubview(label)
        let b = UIButton(type: .system)
        b.setTitle("Approve", for: .normal)
        b.frame = CGRect(x: 40, y: 170, width: view.bounds.width - 80, height: 44)
        b.accessibilityIdentifier = "sso-approve"
        b.addAction(UIAction { [weak self] _ in
            slog("approved")
            self?.request?.complete(httpAuthorizationHeaders: ["Authorization": "Bearer sso-1"])
        }, for: .primaryActionTriggered)
        view.addSubview(b)
    }
}
