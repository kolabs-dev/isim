// Saved-password sign-in (ASAuthorizationPasswordProvider): offers the app's internet passwords from isim's
// keychain (kSecClassInternetPassword items in the app's access group). There is no iCloud Keychain or
// Passwords app on isim, so apps see only passwords they (or their app group) saved themselves.
import Foundation
import Security

open class ASAuthorizationPasswordProvider: NSObject, ASAuthorizationProvider {
    public override init() { super.init() }
    open func createRequest() -> ASAuthorizationPasswordRequest { ASAuthorizationPasswordRequest(provider: self) }
}
open class ASAuthorizationPasswordRequest: ASAuthorizationRequest {}

open class ASPasswordCredential: NSObject, ASAuthorizationCredential {
    public let user: String
    public let password: String
    public init(user: String, password: String) { self.user = user; self.password = password }
}

struct _ASSavedPassword { var user: String, password: String, server: String }

enum _ASPasswords {
    static func saved() -> [_ASSavedPassword] {
        let q: [String: Any] = [kSecClass as String: kSecClassInternetPassword, kSecMatchLimit as String: kSecMatchLimitAll,
                                kSecReturnAttributes as String: true, kSecReturnData as String: true]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let items = out as? [[String: Any]] else { return [] }
        return items.compactMap { i in
            guard let user = i[kSecAttrAccount as String] as? String, let d = i[kSecValueData as String] as? Data,
                  let pw = String(data: d, encoding: .utf8) else { return nil }
            return _ASSavedPassword(user: user, password: pw, server: i[kSecAttrServer as String] as? String ?? "")
        }
    }
}
