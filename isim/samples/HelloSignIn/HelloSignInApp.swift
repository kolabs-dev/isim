// Sample: isim's local AuthenticationServices — Sign in with Apple (SwiftUI SignInWithAppleButton and the UIKit
// ASAuthorizationAppleIDButton), credential state + revocation, passkey registration and sign-in (the app plays
// the relying-party server too: it parses the attestation object, keeps the COSE public key and verifies the
// assertion signature with CryptoKit), saved-password sign-in from the keychain, and AppTrackingTransparency +
// the advertising identifier (AdSupport). Results are printed for tests/ui/test_signin.py.
import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit
import Security
import AppTrackingTransparency
import AdSupport

@main
struct HelloSignInApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

/// The app's "server": what a relying party keeps (the passkey public key) and checks.
enum Server {
    static let rp = "login.example.com"
    static var challenge = Data()
    static func newChallenge() -> Data { challenge = Data((0..<32).map { _ in UInt8.random(in: 0...255) }); return challenge }
    static var publicKey: Data? {
        get { UserDefaults.standard.object(forKey: "passkeyPublicKey") as? Data }
        set { UserDefaults.standard.set(newValue, forKey: "passkeyPublicKey") }
    }
    static func b64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func clientDataOK(_ json: Data, type: String) -> Bool {
        guard let o = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return false }
        return o["type"] as? String == type && o["challenge"] as? String == b64url(challenge) && o["origin"] as? String == "https://\(rp)"
    }
    /// attestationObject (CBOR) -> fmt, authData; authData -> rpIdHash, flags, AAGUID, credential id, COSE x/y
    static func register(_ r: ASAuthorizationPlatformPublicKeyCredentialRegistration) {
        guard let att = r.rawAttestationObject, let fmtAt = find(att, Array("fmt".utf8)), let adAt = find(att, Array("authData".utf8)) else { print("passkey: bad attestation object"); return }
        let fmt = String(decoding: att[(fmtAt + 4)..<(fmtAt + 8)], as: UTF8.self)
        let b = Array(att[(adAt + 8)...])         // 0x58/0x59 length header follows the key
        let (len, off) = b[0] == 0x59 ? (Int(b[1]) << 8 | Int(b[2]), 3) : (Int(b[1]), 2)
        let ad = Array(b[off..<(off + len)])
        let rpOK = Data(ad[0..<32]) == Data(SHA256.hash(data: Data(rp.utf8)))
        let flags = ad[32], aaguid = ad[37..<53].allSatisfy { $0 == 0 }
        let idLen = Int(ad[53]) << 8 | Int(ad[54])
        let credID = Data(ad[55..<(55 + idLen)])
        let cose = Array(ad[(55 + idLen)...])
        guard let xi = find(Data(cose), [0x21, 0x58, 0x20]), let yi = find(Data(cose), [0x22, 0x58, 0x20]) else { print("passkey: no COSE key"); return }
        let xy = Data(cose[(xi + 3)..<(xi + 35)] + cose[(yi + 3)..<(yi + 35)])
        let key = try? P256.Signing.PublicKey(rawRepresentation: xy)
        publicKey = key?.rawRepresentation
        print("passkey registered: fmt=\(fmt) rpIdHash=\(rpOK) flags=0x\(String(flags, radix: 16)) aaguidZero=\(aaguid) credentialID=\(credID == r.credentialID) cose=\(key != nil) clientData=\(clientDataOK(r.rawClientDataJSON, type: "webauthn.create"))")
    }
    static func verify(_ a: ASAuthorizationPlatformPublicKeyCredentialAssertion) {
        guard let pk = publicKey, let key = try? P256.Signing.PublicKey(rawRepresentation: pk),
              let sig = try? P256.Signing.ECDSASignature(derRepresentation: a.signature) else { print("passkey assertion: no key"); return }
        var signed = a.rawAuthenticatorData; signed.append(Data(SHA256.hash(data: a.rawClientDataJSON)))
        let ok = key.isValidSignature(sig, for: signed)
        var tampered = signed; tampered[tampered.count - 1] ^= 1
        print("passkey assertion verified: \(ok) tampered rejected: \(!key.isValidSignature(sig, for: tampered)) clientData=\(clientDataOK(a.rawClientDataJSON, type: "webauthn.get")) user=\(String(decoding: a.userID, as: UTF8.self))")
    }
    static func find(_ d: Data, _ pat: [UInt8]) -> Int? {
        let a = Array(d)
        guard a.count >= pat.count else { return nil }
        for i in 0...(a.count - pat.count) where Array(a[i..<(i + pat.count)]) == pat { return i }
        return nil
    }
}

final class Auth: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = Auth()
    @Published var status = "Signed out"
    var userID: String? {
        get { UserDefaults.standard.string(forKey: "appleUserID") }
        set { UserDefaults.standard.set(newValue, forKey: "appleUserID") }
    }
    func run(_ requests: [ASAuthorizationRequest], options: ASAuthorizationController.RequestOptions = []) {
        let c = ASAuthorizationController(authorizationRequests: requests)
        c.delegate = self
        c.presentationContextProvider = self
        c.performRequests(options: options)
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows[0]
    }
    func appleIDRequest() -> ASAuthorizationAppleIDRequest {
        let r = ASAuthorizationAppleIDProvider().createRequest()
        r.requestedScopes = [.fullName, .email]
        r.nonce = "sample-nonce"
        r.state = "sample-state"
        return r
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handle(authorization)
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let code = (error as NSError).code
        print("authorization failed: \((error as NSError).domain) \(code)\(code == ASAuthorizationError.canceled.rawValue ? " (canceled)" : "")")
    }
    func handle(_ authorization: ASAuthorization) {
        switch authorization.credential {
        case let c as ASAuthorizationAppleIDCredential:
            userID = c.user
            let name = c.fullName.map { [$0.givenName, $0.familyName].compactMap { $0 }.joined(separator: " ") } ?? "-"
            print("apple id credential: user=\(c.user) name=\(name.isEmpty ? "-" : name) email=\(c.email ?? "-") state=\(c.state ?? "-") realUser=\(c.realUserStatus == .likelyReal) code=\(c.authorizationCode != nil)")
            if let t = c.identityToken.map({ String(decoding: $0, as: UTF8.self) }) {
                let parts = t.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
                func json(_ s: String) -> [String: Any] {
                    var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                    while b.count % 4 != 0 { b += "=" }
                    return Data(base64Encoded: b).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
                }
                let h = json(parts[0]), p = json(parts.count > 1 ? parts[1] : "")
                print("identity token: alg=\(h["alg"] as? String ?? "?") signature=\(parts.count > 2 && !parts[2].isEmpty ? "present" : "none") iss=\(p["iss"] as? String ?? "?") sub=\(p["sub"] as? String == c.user) aud=\(p["aud"] as? String ?? "?") nonce=\(p["nonce"] as? String ?? "-") email=\(p["email"] as? String ?? "-")")
            }
            status = "Signed in"
        case let c as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            Server.register(c)
        case let c as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            Server.verify(c)
        case let c as ASPasswordCredential:
            print("password credential: \(c.user) / \(String(repeating: "•", count: c.password.count)) matches=\(c.password == "correct horse")")
        default:
            print("unexpected credential \(authorization.credential)")
        }
    }

    func checkState() {
        guard let id = userID else { print("credential state: no user"); return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { state, _ in
            let s = [0: "revoked", 1: "authorized", 2: "notFound", 3: "transferred"][state.rawValue] ?? "?"
            print("credential state: \(s)")
        }
    }
}

/// the UIKit button, in a SwiftUI layout
struct UIKitAppleIDButton: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let b = ASAuthorizationAppleIDButton(authorizationButtonType: .continue, authorizationButtonStyle: .whiteOutline)
        b.cornerRadius = 10
        b.accessibilityIdentifier = "uikit-siwa"
        b.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return b
    }
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject {
        @objc func tapped() { print("uikit button tapped"); Auth.shared.run([Auth.shared.appleIDRequest()]) }
    }
}

struct RootView: View {
    @ObservedObject var auth = Auth.shared
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(verbatim: auth.status).font(.headline).accessibilityIdentifier("status")
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = "sample-nonce"
                        print("swiftui button: request scopes=\(request.requestedScopes?.map { $0.rawValue }.joined(separator: ",") ?? "")")
                    } onCompletion: { result in
                        switch result {
                        case .success(let a): Auth.shared.handle(a)
                        case .failure(let e): print("authorization failed: \((e as NSError).domain) \((e as NSError).code)")
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .accessibilityIdentifier("swiftui-siwa")
                    UIKitAppleIDButton().frame(height: 50)
                    SignInWithAppleButton(.continue, onRequest: { _ in }, onCompletion: { _ in })
                        .signInWithAppleButtonStyle(.white).frame(height: 44)
                    row("Credential state", "state") { auth.checkState() }
                    row("Create passkey", "passkey-register") {
                        let p = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Server.rp)
                        auth.run([p.createCredentialRegistrationRequest(challenge: Server.newChallenge(), name: "taylor", userID: Data("user-42".utf8))])
                    }
                    row("Sign in with passkey", "passkey-signin") {
                        let p = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Server.rp)
                        auth.run([p.createCredentialAssertionRequest(challenge: Server.newChallenge())])
                    }
                    row("Save a password", "save-password") {
                        let q: [String: Any] = [kSecClass as String: kSecClassInternetPassword, kSecAttrServer as String: Server.rp,
                                                kSecAttrAccount as String: "pat@example.com", kSecValueData as String: Data("correct horse".utf8)]
                        SecItemDelete(q as CFDictionary)
                        print("password saved: \(SecItemAdd(q as CFDictionary, nil) == errSecSuccess)")
                    }
                    row("Sign in with password", "password-signin") { auth.run([ASAuthorizationPasswordProvider().createRequest()]) }
                    row("Quick sign-in (no UI if none)", "quick-signin") {
                        let p = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "nobody.example.org")
                        auth.run([p.createCredentialAssertionRequest(challenge: Server.newChallenge())], options: .preferImmediatelyAvailableCredentials)
                    }
                    row("Advertising identifier", "idfa") { printIDFA() }
                    row("Ask to track", "att") {
                        ATTrackingManager.requestTrackingAuthorization { s in
                            print("tracking: \(s == .authorized ? "authorized" : s == .denied ? "denied" : "other")")
                            printIDFA()
                        }
                    }
                }.padding(20)
            }
            .navigationTitle("Sign In")
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil, queue: .main) { _ in
                print("credential revoked notification")
                Auth.shared.status = "Signed out"
            }
            print("launched; stored user: \(Auth.shared.userID != nil)")
        }
    }
    func row(_ title: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).frame(maxWidth: .infinity).frame(height: 40)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }.accessibilityIdentifier(id)
    }
}

func printIDFA() {
    let m = ASIdentifierManager.shared()
    print("idfa: \(m.advertisingIdentifier.uuidString) zero=\(m.advertisingIdentifier.uuidString == "00000000-0000-0000-0000-000000000000") enabled=\(m.isAdvertisingTrackingEnabled)")
}
