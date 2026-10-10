// Sign in with Apple (local simulation, no Apple servers): see Core.swift.
import Foundation
import UIKit
import CryptoKit

open class ASAuthorizationOpenIDRequest: ASAuthorizationRequest {
    open var requestedScopes: [ASAuthorization.Scope]?
    open var state: String?
    open var nonce: String?
    open var requestedOperation: ASAuthorization.OpenIDOperation = .operationImplicit
}

open class ASAuthorizationAppleIDRequest: ASAuthorizationOpenIDRequest {
    open var user: String?
}

open class ASAuthorizationAppleIDProvider: NSObject, ASAuthorizationProvider {
    public enum CredentialState: Int, Sendable { case revoked = 0, authorized = 1, notFound = 2, transferred = 3 }

    public override init() { super.init(); _ASAppleID.watchRevocation() }
    open func createRequest() -> ASAuthorizationAppleIDRequest { ASAuthorizationAppleIDRequest(provider: self) }

    open func getCredentialState(forUserID userID: String, completion: @escaping @Sendable (CredentialState, Error?) -> Void) {
        let s = _ASAppleID.state(forUserID: userID)
        DispatchQueue.global().async { completion(s, nil) }
    }
    open func credentialState(forUserID userID: String) async throws -> CredentialState { _ASAppleID.state(forUserID: userID) }

    /// posted when the user stops using Sign in with Apple for this app (`isim appleid <app> revoke`)
    public static var credentialRevokedNotification: NSNotification.Name {
        _ASAppleID.watchRevocation()
        return NSNotification.Name("ASAuthorizationAppleIDProviderCredentialRevokedNotification")
    }
}

open class ASAuthorizationAppleIDCredential: NSObject, ASAuthorizationCredential {
    public let user: String
    public let state: String?
    public let authorizedScopes: [ASAuthorization.Scope]
    public let authorizationCode: Data?
    public let identityToken: Data?
    public let email: String?
    public let fullName: PersonNameComponents?
    public let realUserStatus: ASUserDetectionStatus
    init(user: String, state: String?, scopes: [ASAuthorization.Scope], code: Data?, token: Data?, email: String?, fullName: PersonNameComponents?) {
        self.user = user; self.state = state; authorizedScopes = scopes; authorizationCode = code; identityToken = token
        self.email = email; self.fullName = fullName; realUserStatus = .likelyReal
    }
}

/// the fake Apple Account and the per-app Sign in with Apple records
enum _ASAppleID {
    struct Account { var first: String, last: String, email: String, signedIn: Bool }
    static var accountPath: String { (_ASData.dir("") as NSString).appendingPathComponent("account.json") }
    static var appsPath: String { (_ASData.dir("") as NSString).appendingPathComponent("SignInWithApple.json") }

    static func account() -> Account {
        if let d = _ASData.readJSON(accountPath) as? [String: Any] {
            return Account(first: d["firstName"] as? String ?? "Taylor", last: d["lastName"] as? String ?? "Appleseed",
                           email: d["email"] as? String ?? "taylor@example.com", signedIn: d["signedIn"] as? Bool ?? true)
        }
        let a = Account(first: "Taylor", last: "Appleseed", email: "taylor@example.com", signedIn: true)
        _ASData.writeJSON(["firstName": a.first, "lastName": a.last, "email": a.email, "signedIn": true,
                           "note": "isim local simulation: a fake Apple Account for Sign in with Apple; no Apple servers"], accountPath)
        return a
    }
    /// bundle id -> {user, state ("authorized"/"revoked"), email, privateEmail, firstName, lastName, created}
    static func apps() -> [String: [String: Any]] { _ASData.readJSON(appsPath) as? [String: [String: Any]] ?? [:] }
    static func entry() -> [String: Any]? { apps()[_ASData.bundleID] }
    static func save(_ e: [String: Any]) {
        var all = apps(); all[_ASData.bundleID] = e
        _ASData.writeJSON(all, appsPath)
    }

    /// stable per account and app, Apple's format (team-scoped on iOS; isim scopes it to the bundle id)
    static func userID(_ acct: Account) -> String {
        let h = Array(SHA256.hash(data: Data((acct.email.lowercased() + "|" + _ASData.bundleID).utf8)))
        let n1 = (Int(h[0]) << 8 | Int(h[1])) % 1_000_000, n2 = (Int(h[2]) << 8 | Int(h[3])) % 10_000
        return String(format: "%06d.", n1) + _ASData.hex(Array(h[4..<20])) + String(format: ".%04d", n2)
    }

    static func state(forUserID id: String) -> ASAuthorizationAppleIDProvider.CredentialState {
        guard account().signedIn, let e = entry(), e["user"] as? String == id else { return .notFound }
        return e["state"] as? String == "authorized" ? .authorized : .revoked
    }

    /// an unsigned JWT (alg "none"): readable claims, no Apple signature
    static func identityToken(user: String, email: String?, isPrivate: Bool, nonce: String?) -> Data {
        let now = Int(Date().timeIntervalSince1970)
        let header: [String: Any] = ["alg": "none", "typ": "JWT", "kid": "isim-local"]
        var claims: [String: Any] = ["iss": "isim-local-simulation", "aud": _ASData.bundleID, "sub": user, "iat": now, "exp": now + 600,
                                     "auth_time": now, "nonce_supported": true, "real_user_status": 2,
                                     "isim_note": "local simulation: unsigned token, not issued by Apple"]
        if let email { claims["email"] = email; claims["email_verified"] = true; claims["is_private_email"] = isPrivate }
        if let nonce { claims["nonce"] = nonce }
        func part(_ o: [String: Any]) -> String {
            _ASData.base64url((try? JSONSerialization.data(withJSONObject: o, options: [.sortedKeys])) ?? Data())
        }
        return Data((part(header) + "." + part(claims) + ".").utf8)
    }

    /// builds the credential after the sheet; first sign-in (or after revocation) shares name/email as chosen
    static func credential(for request: ASAuthorizationAppleIDRequest, shareName: Bool, hideEmail: Bool, editedName: String?) -> ASAuthorizationAppleIDCredential {
        let acct = account()
        let user = userID(acct)
        let previous = entry()
        let returning = previous?["state"] as? String == "authorized" && previous?["user"] as? String == user
        let scopes = request.requestedScopes ?? []
        var email: String?, name: PersonNameComponents?
        var record = previous ?? [:]
        if !returning {
            if scopes.contains(.email) {
                if hideEmail {
                    let relay = (previous?["privateEmail"] as? String) ?? (_ASData.hex(_ASData.random(5)) + "@privaterelay.isim.invalid")
                    record["privateEmail"] = relay; email = relay
                } else { email = acct.email }
            }
            if scopes.contains(.fullName), shareName {
                var n = PersonNameComponents()
                let parts = (editedName ?? "\(acct.first) \(acct.last)").split(separator: " ", maxSplits: 1).map(String.init)
                n.givenName = parts.first; n.familyName = parts.count > 1 ? parts[1] : nil
                name = n
            }
            record["created"] = Date().timeIntervalSince1970
            record["email"] = email ?? ""
        }
        record["user"] = user; record["state"] = "authorized"
        save(record)
        let tokenEmail = email ?? (record["email"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let token = identityToken(user: user, email: tokenEmail, isPrivate: record["privateEmail"] != nil && tokenEmail == record["privateEmail"] as? String, nonce: request.nonce)
        let code = Data(("isim-local-code." + _ASData.hex(_ASData.random(16))).utf8)
        NSLog("isim AuthenticationServices: Sign in with Apple (local simulation, no Apple servers): user %@ %@", user, returning ? "(returning)" : "(new)")
        return ASAuthorizationAppleIDCredential(user: user, state: request.state, scopes: returning ? [] : scopes.filter { $0 != .fullName || shareName },
                                                code: code, token: token, email: email, fullName: name)
    }

    // MARK: revocation
    nonisolated(unsafe) static var watching = false
    nonisolated(unsafe) static var lastState: String?
    static func watchRevocation() {
        guard !watching else { return }
        watching = true
        lastState = entry()?["state"] as? String
        DispatchQueue.main.async {
            Timer._isimScheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                let s = entry()?["state"] as? String
                if s != lastState {
                    if lastState == "authorized" && s != "authorized" {
                        NSLog("isim AuthenticationServices: Sign in with Apple credential revoked for %@", _ASData.bundleID)
                        NotificationCenter.default.post(name: NSNotification.Name("ASAuthorizationAppleIDProviderCredentialRevokedNotification"), object: nil)
                    }
                    lastState = s
                }
            }
        }
    }
}
