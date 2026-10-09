// Saved-password sign-in (ASAuthorizationPasswordProvider): offers the app's internet passwords from isim's
// keychain (kSecClassInternetPassword items in the app's access group) and the device's Passwords store
// ($ISIM_DATA/Library/Passwords/passwords.plist, filled by UIKit's AutoFill "Save Password?") for the app's
// webcredentials domains (else its bundle identifier). There is no iCloud Keychain.
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
        var result: [_ASSavedPassword] = device()
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let items = out as? [[String: Any]] else { return result }
        for i in items {
            guard let user = i[kSecAttrAccount as String] as? String, let d = i[kSecValueData as String] as? Data,
                  let pw = String(data: d, encoding: .utf8), !result.contains(where: { $0.user == user }) else { continue }
            result.append(_ASSavedPassword(user: user, password: pw, server: i[kSecAttrServer as String] as? String ?? ""))
        }
        return result
    }
    /// the device Passwords store's entries for this app's sites (newest first)
    static func device() -> [_ASSavedPassword] {
        let env = getenv("ISIM_DATA").map { String(cString: $0) } ?? ""
        let data = env.isEmpty ? (getenv("HOME").map { String(cString: $0) } ?? "/tmp") + "/.local/share/isim" : env
        guard let d = FileManager.default.contents(atPath: data + "/Library/Passwords/passwords.plist"),
              let list = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [[String: Any]] else { return [] }
        var sites: [String] = []
        let ent = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        if let e = NSDictionary(contentsOfFile: ent), let domains = e["com.apple.developer.associated-domains"] as? [String] {
            sites = domains.filter { $0.hasPrefix("webcredentials:") }.map { String($0.dropFirst(15).split(separator: "?").first ?? "").lowercased() }
        }
        if sites.isEmpty { sites = [Bundle.main.bundleIdentifier ?? "isim.app"] }
        var seen = Set<String>()
        return list.reversed().compactMap { e in
            guard let site = e["site"] as? String, sites.contains(site), let user = e["user"] as? String, let pw = e["password"] as? String,
                  seen.insert(user).inserted else { return nil }
            return _ASSavedPassword(user: user, password: pw, server: site)
        }
    }
}
