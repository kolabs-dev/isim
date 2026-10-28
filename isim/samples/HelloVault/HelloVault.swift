// Sample: a password manager on isim (AuthenticationServices, issue #400). Vault ships three extensions:
//   - Provider (credential provider): turned on with ASSettingsHelper's request, it saves password, one-time-code and
//     passkey identities in ASCredentialIdentityStore; the QuickType bar of this app's sign-in form then offers them
//     (vault.isim.dev is its webcredentials domain), and the passkey chooser offers its passkeys; registering a
//     passkey goes to it;
//   - SSO (identity provider SSO extension) for https://idp.isim.dev (`isim sso add`), with and without its UI;
//   - Upgrade (account modification) for saved passwords of vault.isim.dev: strong password, Sign in with Apple.
// Shared web credentials (Security, issue #402) save, use and delete a vault.isim.dev password of the Passwords store.
// On iOS 26 it also creates an account with ASAuthorizationAccountCreationProvider. Every step is printed ("vault ...").
import UIKit
import AuthenticationServices
import CryptoKit
import Security

func log(_ s: String) { print("vault \(s)"); fflush(stdout) }
let rp = "vault.isim.dev"
let shared = UserDefaults(suiteName: "group.dev.isim.samples.HelloVault")!

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: VaultViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class VaultViewController: UIViewController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding,
                                 ASAccountAuthenticationModificationControllerDelegate {
    var user: UITextField!, password: UITextField!, code: UITextField!
    var modification: ASAccountAuthenticationModificationController?
    var challenge = Data()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Vault"
        view.backgroundColor = .systemBackground
        user = field("user", "User name", .username, y: 100)
        password = field("password", "Password", .password, y: 146, secure: true)
        code = field("code", "Verification code", .oneTimeCode, y: 192)
        button("turn-on", "Turn On AutoFill", x: 20, y: 240) { self.turnOn() }
        button("save", "Save Identities", x: 200, y: 240) { self.saveIdentities() }
        button("register", "New Passkey", x: 20, y: 284) { self.registerPasskey() }
        button("sign-in", "Passkey Sign In", x: 200, y: 284) { self.signInWithPasskey() }
        button("sso", "SSO", x: 20, y: 328) { self.sso(prompt: nil) }
        button("sso-login", "SSO (login)", x: 200, y: 328) { self.sso(prompt: "login") }
        button("strong", "Strong Password", x: 20, y: 372) { self.modify(strong: true) }
        button("siwa", "Use Apple Sign In", x: 200, y: 372) { self.modify(strong: false) }
        button("create", "Create Account", x: 20, y: 416) { self.createAccount() }
        button("share", "Share Password", x: 200, y: 416) { self.sharePassword() }
        button("use-shared", "Use Shared", x: 20, y: 460) { self.useShared() }
        button("unshare", "Delete Shared", x: 200, y: 460) { self.deleteShared() }
        button("share-other", "Share Elsewhere", x: 20, y: 504) { self.shareElsewhere() }
        for f in [user, password, code] { f!.addAction(UIAction { [weak f] _ in log("\(f?.accessibilityIdentifier ?? "") = \(f?.text ?? "")") }, for: .editingChanged) }
        let store = ASCredentialIdentityStore.shared
        store.getState { s in log("store enabled=\(s.isEnabled) incremental=\(s.supportsIncrementalUpdates)") }
    }

    func field(_ id: String, _ placeholder: String, _ type: UITextContentType, y: CGFloat, secure: Bool = false) -> UITextField {
        let f = UITextField(frame: CGRect(x: 20, y: y, width: view.bounds.width - 40, height: 38))
        f.borderStyle = .roundedRect; f.placeholder = placeholder; f.textContentType = type; f.isSecureTextEntry = secure
        f.autocapitalizationType = .none; f.accessibilityIdentifier = id
        view.addSubview(f)
        return f
    }
    func button(_ id: String, _ title: String, x: CGFloat, y: CGFloat, _ action: @escaping () -> Void) {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.frame = CGRect(x: x, y: y, width: 170, height: 36)
        b.accessibilityIdentifier = id
        b.addAction(UIAction { [weak self] _ in self?.view.endEditing(true); action() }, for: .primaryActionTriggered)
        view.addSubview(b)
    }

    // MARK: shared web credentials (Security)

    func sharePassword() {
        let pw = SecCreateSharedWebCredentialPassword()! as String
        log("generated \(pw.count) chars \(pw.split(separator: "-").count) groups")
        SecAddSharedWebCredential(rp as CFString, "cam" as CFString, pw as CFString) { error in
            log("shared add error=\(error.map { String(CFErrorGetCode($0)) } ?? "none")")
        }
    }
    func useShared() {
        SecRequestSharedWebCredential(nil, nil) { list, error in
            let first = (list as? [[String: Any]])?.first
            log("shared request account=\(first?[kSecAttrAccount as String] as? String ?? "-") server=\(first?[kSecAttrServer as String] as? String ?? "-") "
                + "password=\((first?[kSecSharedPassword as String] as? String)?.count ?? 0) chars error=\(error.map { String(CFErrorGetCode($0)) } ?? "none")")
        }
    }
    func deleteShared() {
        SecAddSharedWebCredential(rp as CFString, "cam" as CFString, nil) { error in
            log("shared delete error=\(error.map { String(CFErrorGetCode($0)) } ?? "none")")
        }
    }
    func shareElsewhere() {
        SecAddSharedWebCredential("other.isim.dev" as CFString, "cam" as CFString, "pw" as CFString) { error in
            log("shared elsewhere error=\(error.map { String(CFErrorGetCode($0)) } ?? "none")")
        }
    }

    // MARK: the credential provider

    func turnOn() {
        if #available(iOS 18.0, *) {
            ASSettingsHelper.requestToTurnOnCredentialProviderExtension { on in log("autofill on=\(on)") }
        } else {
            ASSettingsHelper.openCredentialProviderAppSettings { e in log("settings opened error=\(e == nil ? "none" : "?")") }
        }
    }
    func saveIdentities() {
        let service = ASCredentialServiceIdentifier(identifier: rp, type: .domain)
        let ana = ASPasswordCredentialIdentity(serviceIdentifier: service, user: "ana", recordIdentifier: "ana")
        ana.rank = 2
        let bo = ASPasswordCredentialIdentity(serviceIdentifier: ASCredentialServiceIdentifier(identifier: "https://\(rp)/login", type: .URL), user: "bo", recordIdentifier: "locked")
        var identities: [ASCredentialIdentity] = [ana, bo]
        if #available(iOS 18.0, *) { identities.append(ASOneTimeCodeCredentialIdentity(serviceIdentifier: service, label: "ana (Vault)", recordIdentifier: "otp-ana")) }
        ASCredentialIdentityStore.shared.replaceCredentialIdentities(identities) { ok, error in
            log("saved identities ok=\(ok) error=\(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "none")")
            guard ok else { return }
            Task { @MainActor in
                if #available(iOS 18.0, *) {
                    let all = await ASCredentialIdentityStore.shared.credentialIdentities()
                    let passwords = await ASCredentialIdentityStore.shared.credentialIdentities(forService: service, credentialIdentityTypes: .password)
                    log("identities: \(all.count) total, \(passwords.map(\.user)) passwords for \(rp)")
                }
            }
        }
    }

    // MARK: passkeys

    func registerPasskey() {
        challenge = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let p = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rp)
        perform([p.createCredentialRegistrationRequest(challenge: challenge, name: "ana", userID: Data("user-ana".utf8))])
    }
    func signInWithPasskey() {
        challenge = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let p = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rp)
        perform([p.createCredentialAssertionRequest(challenge: challenge)])
    }

    // MARK: single sign-on

    func sso(prompt: String?) {
        let p = ASAuthorizationSingleSignOnProvider(identityProvider: URL(string: "https://idp.isim.dev/authorize")!)
        log("sso canPerform=\(p.canPerformAuthorization)")
        let r = p.createRequest()
        r.requestedScopes = [.email]
        r.state = "s1"
        if let prompt { r.authorizationOptions = [URLQueryItem(name: "prompt", value: prompt)] }
        perform([r])
    }

    // MARK: account modification

    func modify(strong: Bool) {
        let service = ASCredentialServiceIdentifier(identifier: rp, type: .domain)
        let c = ASAccountAuthenticationModificationController()
        c.delegate = self
        modification = c
        c.perform(strong ? ASAccountAuthenticationModificationUpgradePasswordToStrongPasswordRequest(user: "ana", serviceIdentifier: service, userInfo: ["why": "weak"])
                         : ASAccountAuthenticationModificationReplacePasswordWithSignInWithAppleRequest(user: "bo", serviceIdentifier: service, userInfo: nil))
    }
    func accountAuthenticationModificationController(_ controller: ASAccountAuthenticationModificationController,
                                                     didSuccessfullyComplete request: ASAccountAuthenticationModificationRequest, userInfo: [AnyHashable: Any]?) {
        let kind = request is ASAccountAuthenticationModificationUpgradePasswordToStrongPasswordRequest ? "strong password" : "Sign in with Apple"
        log("modified (\(kind)) userInfo=\(userInfo?.count ?? 0)")
    }
    func accountAuthenticationModificationController(_ controller: ASAccountAuthenticationModificationController,
                                                     didFail request: ASAccountAuthenticationModificationRequest, error: Error) {
        log("modification failed: \((error as NSError).domain) \((error as NSError).code)")
    }

    // MARK: account creation (iOS 26)

    func createAccount() {
        guard #available(iOS 26.0, *) else { log("account creation needs iOS 26"); return }
        challenge = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let r = ASAuthorizationAccountCreationProvider().createPlatformPublicKeyCredentialRegistrationRequest(
            acceptedContactIdentifiers: [.email, .phoneNumber], shouldRequestName: true, relyingPartyIdentifier: rp, challenge: challenge, userID: Data("new-user".utf8))
        perform([r])
    }

    // MARK: ASAuthorizationController

    func perform(_ requests: [ASAuthorizationRequest]) {
        let c = ASAuthorizationController(authorizationRequests: requests)
        c.delegate = self
        c.presentationContextProvider = self
        c.performRequests()
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { view.window! }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let c as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            log("passkey registered id=\(c.credentialID.count) bytes attestation=\(c.rawAttestationObject?.count ?? 0) bytes")
        case let c as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            // the provider's public key (it shares the app group) verifies the signature over authData || SHA-256(clientData)
            let pub = (shared.object(forKey: "pub-" + c.credentialID.base64EncodedString()) as? Data).flatMap { try? P256.Signing.PublicKey(rawRepresentation: $0) }
            let sig = try? P256.Signing.ECDSASignature(derRepresentation: c.signature)
            let ok = pub.map { k in sig.map { k.isValidSignature($0, for: c.rawAuthenticatorData + Data(SHA256.hash(data: c.rawClientDataJSON))) } ?? false } ?? false
            let type = (try? JSONSerialization.jsonObject(with: c.rawClientDataJSON) as? [String: Any])?["type"] as? String ?? "?"
            log("passkey signed in user=\(String(data: c.userID, encoding: .utf8) ?? "?") verified=\(ok) clientData=\(type)")
        case let c as ASAuthorizationSingleSignOnCredential:
            let token = c.accessToken.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
            let id = c.identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
            log("sso signed in state=\(c.state ?? "-") status=\(c.authenticatedResponse?.statusCode ?? 0) token=\(token) id=\(id) " +
                "authorization=\(c.authenticatedResponse?.value(forHTTPHeaderField: "Authorization") ?? "-")")
        default:
            if #available(iOS 26.0, *), let c = authorization.credential as? ASAuthorizationAccountCreationPlatformPublicKeyCredential {
                var contact = "-"
                switch c.contactIdentifier {
                case .email(let e): contact = "email \(e.value)"
                case .phoneNumber(let p): contact = "phone \(p.value)"
                @unknown default: break
                }
                log("account created \(contact) name=\(c.name?.givenName ?? "-") \(c.name?.familyName ?? "-") passkey=\(c.credentialRegistration.credentialID.count) bytes")
                return
            }
            log("credential: \(type(of: authorization.credential))")
        }
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        log("authorization failed: \((error as NSError).code)")
    }
}
