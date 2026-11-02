// Sample: a smart card's keys in the keychain through a persistent token extension (issue #743). HelloToken contains a
// token driver (Driver/TokenDriver.swift) for PIV cards. When a PIV card with an ECC key is in a reader
// (`isim smartcard insert CARD.json`), the token watcher reports its token and the keychain lists the token's identity,
// certificate and key (access group com.apple.token, kSecAttrTokenID). "Sign" signs with the card's key through the
// token (the card asks for its PIN: isim's PIN sheet) and verifies the signature with the certificate's public key;
// "Agree" agrees on a secret with a software key, both ways and with the X9.63 KDF. Every step is printed ("tk ...").
import UIKit
import CryptoTokenKit
import Security

func log(_ s: String) { print("tk \(s)"); fflush(stdout) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: TokenViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class TokenViewController: UIViewController {
    nonisolated(unsafe) static weak var shown: TokenViewController?
    let watcher = TKTokenWatcher()
    let status = UILabel()
    var tokenID: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Token"
        view.backgroundColor = .systemBackground
        status.frame = CGRect(x: 20, y: 110, width: view.bounds.width - 40, height: 80)
        status.numberOfLines = 0; status.accessibilityIdentifier = "status"; status.text = "No token"
        view.addSubview(status)
        button("sign", "Sign", y: 210) { self.sign() }
        button("agree", "Agree", y: 260) { self.agree() }
        button("register", "Register", y: 310) { self.register() }
        log("drivers \(TKTokenDriver.Configuration.driverConfigurations.keys.sorted())")
        TokenViewController.shown = self
        let watcher = self.watcher
        watcher.setInsertionHandler { id in
            log("token inserted \(id) driver=\(watcher.tokenInfo(forTokenID: id)?.driverName ?? "-")")
            DispatchQueue.main.async { TokenViewController.shown?.inserted(id) }
            watcher.addRemovalHandler({ id in
                log("token removed \(id)")
                DispatchQueue.main.async { TokenViewController.shown?.removed() }
            }, forTokenID: id)
        }
    }
    func button(_ id: String, _ title: String, y: CGFloat, _ action: @escaping () -> Void) {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.frame = CGRect(x: 20, y: y, width: 200, height: 40)
        b.accessibilityIdentifier = id
        b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        view.addSubview(b)
    }

    func inserted(_ id: String) {
        tokenID = id
        var out: CFTypeRef?
        let q: [String: Any] = [kSecClass as String: kSecClassIdentity, kSecAttrTokenID as String: id,
                                kSecReturnRef as String: true, kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll]
        let st = SecItemCopyMatching(q as CFDictionary, &out)
        let found = out as? [[String: Any]] ?? []
        var subject = "-"
        if let first = found.first, let ref = first[kSecValueRef as String] {
            let identity = ref as! SecIdentity
            var cert: SecCertificate?
            _ = SecIdentityCopyCertificate(identity, &cert)
            subject = cert.flatMap { SecCertificateCopySubjectSummary($0) as String? } ?? "-"
        }
        log("identities status=\(st) count=\(found.count) subject=\(subject) group=\(found.first?[kSecAttrAccessGroup as String] as? String ?? "-")")
        if let k = key() {
            let a = SecKeyCopyAttributes(k) as? [String: Any] ?? [:]
            log("key type=\(a[kSecAttrKeyType as String] as? String ?? "-") bits=\(a[kSecAttrKeySizeInBits as String] as? Int ?? 0) "
                + "sign=\(a[kSecAttrCanSign as String] as? Bool ?? false) derive=\(a[kSecAttrCanDerive as String] as? Bool ?? false) "
                + "exportable=\(SecKeyCopyExternalRepresentation(k, nil) != nil)")
        }
        status.text = "Token \(id) (\(subject))"
    }
    func removed() {
        tokenID = nil
        var out: CFTypeRef?
        let st = SecItemCopyMatching([kSecClass as String: kSecClassKey, kSecAttrAccessGroup as String: "com.apple.token",
                                      kSecReturnRef as String: true] as CFDictionary, &out)
        log("after removal keys status=\(st)")
        status.text = "No token"
    }
    /// the token's private key, from the keychain
    func key() -> SecKey? {
        guard let id = tokenID else { return nil }
        var out: CFTypeRef?
        let q: [String: Any] = [kSecClass as String: kSecClassKey, kSecAttrTokenID as String: id, kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                                kSecReturnRef as String: true]
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let out else { return nil }
        return (out as! SecKey)
    }

    func sign() {
        guard let k = key(), let pub = SecKeyCopyPublicKey(k) else { log("sign no key"); return }
        let message = Data("hello token".utf8)
        var error: Unmanaged<CFError>?
        guard let sig = SecKeyCreateSignature(k, .ecdsaSignatureMessageX962SHA256, message as CFData, &error) as Data? else {
            log("sign failed error=\((error?.takeRetainedValue() as Error?).map { ($0 as NSError).code } ?? 0)"); return
        }
        let ok = SecKeyVerifySignature(pub, .ecdsaSignatureMessageX962SHA256, message as CFData, sig as CFData, nil)
        log("sign bytes=\(sig.count) der=\(sig.first == 0x30) verified=\(ok)")
        status.text = "Signed and verified: \(ok)"
    }
    func agree() {
        guard let k = key(), let tokenPub = SecKeyCopyPublicKey(k),
              let mine = SecKeyCreateRandomKey([kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits as String: 256] as CFDictionary, nil),
              let myPub = SecKeyCopyPublicKey(mine) else { log("agree no key"); return }
        var error: Unmanaged<CFError>?
        let a = SecKeyCopyKeyExchangeResult(k, .ecdhKeyExchangeStandard, myPub, [:] as CFDictionary, &error) as Data?
        let b = SecKeyCopyKeyExchangeResult(mine, .ecdhKeyExchangeStandard, tokenPub, [:] as CFDictionary, nil) as Data?
        let params: [String: Any] = [kSecKeyKeyExchangeParameterRequestedSize as String: 32,
                                     kSecKeyKeyExchangeParameterSharedInfo as String: Data("isim".utf8)]
        let c = SecKeyCopyKeyExchangeResult(k, .ecdhKeyExchangeStandardX963SHA256, myPub, params as CFDictionary, nil) as Data?
        let d = SecKeyCopyKeyExchangeResult(mine, .ecdhKeyExchangeStandardX963SHA256, tokenPub, params as CFDictionary, nil) as Data?
        log("agree bytes=\(a?.count ?? 0) equal=\(a != nil && a == b) kdf=\(c?.count ?? 0) kdfEqual=\(c != nil && c == d) "
            + "error=\((error?.takeRetainedValue() as Error?).map { ($0 as NSError).code } ?? 0)")
        status.text = "Agreed: \(a != nil && a == b)"
    }
    func register() {
        guard let id = tokenID else { return }
        if #available(iOS 26.0, *) {
            let m = TKSmartCardTokenRegistrationManager.default
            do {
                try m.registerSmartCard(tokenID: id, promptMessage: "Sign in with your PIV card")
                log("registered \(m.registeredSmartCardTokens.contains(id))")
                try m.unregisterSmartCard(tokenID: id)
                log("unregistered \(!m.registeredSmartCardTokens.contains(id))")
            } catch { log("register error \((error as NSError).code)") }
        } else {
            log("registration needs iOS 26")
        }
    }
}
