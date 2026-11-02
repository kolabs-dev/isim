// isim Security: the keys and certificates of CryptoTokenKit tokens (issue #743). CryptoTokenKit's token host
// (_TKSecTokenBackend) lists the keychain contents of the inserted tokens; they appear in SecItemCopyMatching in the
// access group com.apple.token (the app needs it in keychain-access-groups, as on iOS) with kSecAttrTokenID. A token's
// SecKey is a private key that stays on the token: SecKeyCreateSignature, SecKeyCreateDecryptedData and
// SecKeyCopyKeyExchangeResult go to the token's session (TKTokenSessionDelegate); its public key comes from the token.
// Security loads CryptoTokenKit when the device has virtual card readers (readers.json).
import Foundation

/// what CryptoTokenKit's token host gives Security
public protocol _SecTokenBackend: AnyObject {
    /// the inserted tokens' items: class ("keys" / "cert"), token ID, the item's index in the token's keychain contents,
    /// attributes (Security's keys: labl, atag, klbl, type, bsiz, sign, decr, drve) and data (a key's public key in
    /// Apple's external representation, a certificate's DER)
    func _tokenItems() -> [(cls: String, tokenID: String, index: Int, attributes: [String: Any], data: Data)]
    /// op 2 sign, 3 decrypt, 4 key exchange (publicKey: the other party's); returns the result and, for a key exchange,
    /// whether the token did a plain ECDH, so the algorithm's KDF is still to apply
    func _tokenOperation(_ op: Int, tokenID: String, index: Int, algorithm: String, input: Data, publicKey: Data?,
                         parameters: [String: Any]) throws -> (Data, Bool)
}
nonisolated(unsafe) public var _secTokenBackend: _SecTokenBackend?
private let _secTokenLock = NSLock()
nonisolated(unsafe) private var _secTokenTried = false

/// the token host, loading CryptoTokenKit once the device has card readers
func _secTokens() -> _SecTokenBackend? {
    if let b = _secTokenBackend { return b }
    _secTokenLock.lock(); defer { _secTokenLock.unlock() }
    if let b = _secTokenBackend { return b }
    guard !_secTokenTried else { return nil }
    let env = getenv("ISIM_DATA").map { String(cString: $0) } ?? ""
    let data = env.isEmpty ? (getenv("HOME").map { String(cString: $0) } ?? "/tmp") + "/.local/share/isim" : env
    guard FileManager.default.fileExists(atPath: data + "/Library/isim/SmartCards/readers.json") else { return nil }
    _secTokenTried = true
    if NSClassFromString("_TKSecTokenBackend") == nil {
        _ = dlopen("/System/Library/Frameworks/CryptoTokenKit.framework/CryptoTokenKit", RTLD_NOW | RTLD_GLOBAL)
    }
    _ = (NSClassFromString("_TKSecTokenBackend") as? NSObject.Type)?.init()     // its init sets _secTokenBackend
    return _secTokenBackend
}

extension _Keychain {
    /// the tokens' items of a class, as keychain items of the access group com.apple.token
    func tokenItems(_ cls: String) -> [_KCItem] {
        guard ["keys", "cert", "idnt"].contains(cls), entitledGroups.contains("com.apple.token"), let backend = _secTokens() else { return [] }
        let all = backend._tokenItems()
        func item(_ x: (cls: String, tokenID: String, index: Int, attributes: [String: Any], data: Data), as c: String) -> _KCItem {
            var attrs: [String: _KCValue] = ["agrp": .string("com.apple.token"), "tkid": .string(x.tokenID), "_tkix": .int(x.index),
                                             "sync": .bool(false), "pdmn": .string("ak"), "perm": .bool(true)]
            if x.cls == "cert", let cert = SecCertificate(der: Array(x.data)), let (_, a) = _certificateRefAttributes(cert, cls: "cert") {
                for (k, v) in a { attrs[k] = v }
            }
            for (k, v) in x.attributes { if let val = _KCValue(v, key: k) { attrs[k] = val } }
            if x.cls == "keys" { attrs["kcls"] = .string("1") }
            return _KCItem(id: "token:\(x.tokenID):\(x.index)", cls: c, attrs: attrs, data: Array(x.data))
        }
        switch cls {
        case "keys", "cert": return all.filter { $0.cls == cls }.map { item($0, as: cls) }
        default:                                            // identities: a certificate and the token's key for its public key
            var out: [_KCItem] = []
            for c in all where c.cls == "cert" {
                guard let cert = SecCertificate(der: Array(c.data)), let pub = SecCertificateCopyKey(cert), let raw = pub.publicRaw,
                      let k = all.first(where: { $0.cls == "keys" && $0.tokenID == c.tokenID && Array($0.data) == raw }) else { continue }
                var i = item(c, as: "idnt")
                i.attrs["_tkkey"] = .int(k.index)
                i.attrs["klbl"] = .data(_sha1(raw))
                out.append(i)
            }
            return out
        }
    }
    /// the SecKey of a token key item (or of an identity's key)
    static func tokenKey(_ item: _KCItem, ofIdentity: Bool = false) -> SecKey? {
        guard case .string(let tokenID)? = item.attrs["tkid"], case .int(let ix)? = item.attrs[ofIdentity ? "_tkkey" : "_tkix"] else { return nil }
        let pub: [UInt8]
        if item.cls == "keys" { pub = item.data ?? [] }
        else { guard let cert = SecCertificate(der: item.data ?? []), let k = SecCertificateCopyKey(cert), let r = k.publicRaw else { return nil }; pub = r }
        let type: Int32 = pub.first == 0x04 ? 1 : 0
        guard let bits = SecKey.load(type: type, isPrivate: false, raw: pub)?.bits else { return nil }
        let key = SecKey(type: type, isPrivate: true, raw: pub, bits: bits)
        key.token = (tokenID, ix)
        key.attributes["tkid"] = tokenID; key.attributes["perm"] = true
        if case .string(let l)? = item.attrs["labl"] { key.attributes["labl"] = l }
        if case .data(let t)? = item.attrs["atag"] { key.attributes["atag"] = Data(t) }
        for k in ["sign", "decr", "drve"] { if case .bool(let b)? = item.attrs[k] { key.attributes[k] = b } }
        return key
    }
}

/// a token key's operation through its token session
func _tokenOperation(_ key: SecKey, _ op: Int, _ algorithm: SecKeyAlgorithm, _ input: Data, publicKey: Data? = nil, parameters: [String: Any] = [:],
                     _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> (Data, Bool)? {
    guard let (tokenID, index) = key.token else { return nil }
    guard let backend = _secTokens() else { return _secFail(error, errSecItemNotFound, "the token \(tokenID) is not available") }
    do {
        return try backend._tokenOperation(op, tokenID: tokenID, index: index, algorithm: algorithm.rawValue as String, input: input,
                                           publicKey: publicKey, parameters: parameters)
    } catch let e as NSError {
        error?.pointee = Unmanaged.passRetained(unsafeBitCast(e, to: CFError.self))
        return nil
    }
}
