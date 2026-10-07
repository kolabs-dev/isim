// isim Security: SecKey — RSA (1024-8192 bits) and NIST EC (P-256/P-384/P-521) keys, created, imported, exported,
// used for signatures, RSA encryption and ECDH key exchange through the host's OpenSSL (host_pki.c).
// Self-authored with iOS names and constants. Keys use Apple's external representations (PKCS#1 for RSA, X9.63 for
// EC), so data exchanged with real devices or servers round-trips. There is no Secure Enclave on isim
// (kSecAttrTokenIDSecureEnclave fails with errSecUnimplemented, like a Mac without one).
import Foundation
internal import CommonCrypto
import isim_host

// MARK: - Attribute keys and values

public let kSecAttrKeyType: CFString = "type" as CFString
public let kSecAttrKeyTypeRSA: CFString = "42" as CFString
public let kSecAttrKeyTypeEC: CFString = "73" as CFString
public let kSecAttrKeyTypeECSECPrimeRandom: CFString = "73" as CFString
public let kSecAttrKeySizeInBits: CFString = "bsiz" as CFString
public let kSecAttrEffectiveKeySize: CFString = "esiz" as CFString
public let kSecAttrKeyClass: CFString = "kcls" as CFString
public let kSecAttrKeyClassPublic: CFString = "0" as CFString
public let kSecAttrKeyClassPrivate: CFString = "1" as CFString
public let kSecAttrKeyClassSymmetric: CFString = "2" as CFString
public let kSecAttrApplicationTag: CFString = "atag" as CFString
public let kSecAttrApplicationLabel: CFString = "klbl" as CFString
public let kSecAttrIsPermanent: CFString = "perm" as CFString
public let kSecAttrIsSensitive: CFString = "sens" as CFString
public let kSecAttrIsExtractable: CFString = "extr" as CFString
public let kSecAttrCanEncrypt: CFString = "encr" as CFString
public let kSecAttrCanDecrypt: CFString = "decr" as CFString
public let kSecAttrCanDerive: CFString = "drve" as CFString
public let kSecAttrCanSign: CFString = "sign" as CFString
public let kSecAttrCanVerify: CFString = "vrfy" as CFString
public let kSecAttrCanWrap: CFString = "wrap" as CFString
public let kSecAttrCanUnwrap: CFString = "unwp" as CFString
public let kSecAttrTokenID: CFString = "tkid" as CFString
public let kSecAttrTokenIDSecureEnclave: CFString = "com.apple.setoken" as CFString
public let kSecPrivateKeyAttrs: CFString = "private" as CFString
public let kSecPublicKeyAttrs: CFString = "public" as CFString
public let kSecKeyKeyExchangeParameterRequestedSize: CFString = "requestedSize" as CFString
public let kSecKeyKeyExchangeParameterSharedInfo: CFString = "sharedInfo" as CFString

// MARK: - Algorithms

public struct SecKeyAlgorithm: RawRepresentable, Hashable, @unchecked Sendable {
    public let rawValue: CFString
    public init(rawValue: CFString) { self.rawValue = rawValue }
    init(_ s: String) { rawValue = s as CFString }
    public static func == (a: SecKeyAlgorithm, b: SecKeyAlgorithm) -> Bool { (a.rawValue as String) == (b.rawValue as String) }
    public func hash(into h: inout Hasher) { h.combine(rawValue as String) }

    public static let rsaSignatureRaw = SecKeyAlgorithm("algid:sign:RSA:raw")
    public static let rsaSignatureDigestPKCS1v15Raw = SecKeyAlgorithm("algid:sign:RSA:digest-PKCS1v15")
    public static let rsaSignatureDigestPKCS1v15SHA1 = SecKeyAlgorithm("algid:sign:RSA:digest-PKCS1v15:SHA1")
    public static let rsaSignatureDigestPKCS1v15SHA224 = SecKeyAlgorithm("algid:sign:RSA:digest-PKCS1v15:SHA224")
    public static let rsaSignatureDigestPKCS1v15SHA256 = SecKeyAlgorithm("algid:sign:RSA:digest-PKCS1v15:SHA256")
    public static let rsaSignatureDigestPKCS1v15SHA384 = SecKeyAlgorithm("algid:sign:RSA:digest-PKCS1v15:SHA384")
    public static let rsaSignatureDigestPKCS1v15SHA512 = SecKeyAlgorithm("algid:sign:RSA:digest-PKCS1v15:SHA512")
    public static let rsaSignatureMessagePKCS1v15SHA1 = SecKeyAlgorithm("algid:sign:RSA:message-PKCS1v15:SHA1")
    public static let rsaSignatureMessagePKCS1v15SHA224 = SecKeyAlgorithm("algid:sign:RSA:message-PKCS1v15:SHA224")
    public static let rsaSignatureMessagePKCS1v15SHA256 = SecKeyAlgorithm("algid:sign:RSA:message-PKCS1v15:SHA256")
    public static let rsaSignatureMessagePKCS1v15SHA384 = SecKeyAlgorithm("algid:sign:RSA:message-PKCS1v15:SHA384")
    public static let rsaSignatureMessagePKCS1v15SHA512 = SecKeyAlgorithm("algid:sign:RSA:message-PKCS1v15:SHA512")
    public static let rsaSignatureDigestPSSSHA1 = SecKeyAlgorithm("algid:sign:RSA:digest-PSS:SHA1:SHA1:20")
    public static let rsaSignatureDigestPSSSHA224 = SecKeyAlgorithm("algid:sign:RSA:digest-PSS:SHA224:SHA224:28")
    public static let rsaSignatureDigestPSSSHA256 = SecKeyAlgorithm("algid:sign:RSA:digest-PSS:SHA256:SHA256:32")
    public static let rsaSignatureDigestPSSSHA384 = SecKeyAlgorithm("algid:sign:RSA:digest-PSS:SHA384:SHA384:48")
    public static let rsaSignatureDigestPSSSHA512 = SecKeyAlgorithm("algid:sign:RSA:digest-PSS:SHA512:SHA512:64")
    public static let rsaSignatureMessagePSSSHA1 = SecKeyAlgorithm("algid:sign:RSA:message-PSS:SHA1:SHA1:20")
    public static let rsaSignatureMessagePSSSHA224 = SecKeyAlgorithm("algid:sign:RSA:message-PSS:SHA224:SHA224:28")
    public static let rsaSignatureMessagePSSSHA256 = SecKeyAlgorithm("algid:sign:RSA:message-PSS:SHA256:SHA256:32")
    public static let rsaSignatureMessagePSSSHA384 = SecKeyAlgorithm("algid:sign:RSA:message-PSS:SHA384:SHA384:48")
    public static let rsaSignatureMessagePSSSHA512 = SecKeyAlgorithm("algid:sign:RSA:message-PSS:SHA512:SHA512:64")
    public static let ecdsaSignatureRFC4754 = SecKeyAlgorithm("algid:sign:ECDSA:RFC4754")
    public static let ecdsaSignatureDigestX962 = SecKeyAlgorithm("algid:sign:ECDSA:digest-X962")
    public static let ecdsaSignatureDigestX962SHA1 = SecKeyAlgorithm("algid:sign:ECDSA:digest-X962:SHA1")
    public static let ecdsaSignatureDigestX962SHA224 = SecKeyAlgorithm("algid:sign:ECDSA:digest-X962:SHA224")
    public static let ecdsaSignatureDigestX962SHA256 = SecKeyAlgorithm("algid:sign:ECDSA:digest-X962:SHA256")
    public static let ecdsaSignatureDigestX962SHA384 = SecKeyAlgorithm("algid:sign:ECDSA:digest-X962:SHA384")
    public static let ecdsaSignatureDigestX962SHA512 = SecKeyAlgorithm("algid:sign:ECDSA:digest-X962:SHA512")
    public static let ecdsaSignatureMessageX962SHA1 = SecKeyAlgorithm("algid:sign:ECDSA:message-X962:SHA1")
    public static let ecdsaSignatureMessageX962SHA224 = SecKeyAlgorithm("algid:sign:ECDSA:message-X962:SHA224")
    public static let ecdsaSignatureMessageX962SHA256 = SecKeyAlgorithm("algid:sign:ECDSA:message-X962:SHA256")
    public static let ecdsaSignatureMessageX962SHA384 = SecKeyAlgorithm("algid:sign:ECDSA:message-X962:SHA384")
    public static let ecdsaSignatureMessageX962SHA512 = SecKeyAlgorithm("algid:sign:ECDSA:message-X962:SHA512")
    public static let ecdsaSignatureDigestRFC4754 = SecKeyAlgorithm("algid:sign:ECDSA:digest-RFC4754")
    public static let ecdsaSignatureDigestRFC4754SHA1 = SecKeyAlgorithm("algid:sign:ECDSA:digest-RFC4754:SHA1")
    public static let ecdsaSignatureDigestRFC4754SHA224 = SecKeyAlgorithm("algid:sign:ECDSA:digest-RFC4754:SHA224")
    public static let ecdsaSignatureDigestRFC4754SHA256 = SecKeyAlgorithm("algid:sign:ECDSA:digest-RFC4754:SHA256")
    public static let ecdsaSignatureDigestRFC4754SHA384 = SecKeyAlgorithm("algid:sign:ECDSA:digest-RFC4754:SHA384")
    public static let ecdsaSignatureDigestRFC4754SHA512 = SecKeyAlgorithm("algid:sign:ECDSA:digest-RFC4754:SHA512")
    public static let ecdsaSignatureMessageRFC4754SHA1 = SecKeyAlgorithm("algid:sign:ECDSA:message-RFC4754:SHA1")
    public static let ecdsaSignatureMessageRFC4754SHA224 = SecKeyAlgorithm("algid:sign:ECDSA:message-RFC4754:SHA224")
    public static let ecdsaSignatureMessageRFC4754SHA256 = SecKeyAlgorithm("algid:sign:ECDSA:message-RFC4754:SHA256")
    public static let ecdsaSignatureMessageRFC4754SHA384 = SecKeyAlgorithm("algid:sign:ECDSA:message-RFC4754:SHA384")
    public static let ecdsaSignatureMessageRFC4754SHA512 = SecKeyAlgorithm("algid:sign:ECDSA:message-RFC4754:SHA512")
    public static let rsaEncryptionRaw = SecKeyAlgorithm("algid:encrypt:RSA:raw")
    public static let rsaEncryptionPKCS1 = SecKeyAlgorithm("algid:encrypt:RSA:PKCS1")
    public static let rsaEncryptionOAEPSHA1 = SecKeyAlgorithm("algid:encrypt:RSA:OAEP:SHA1")
    public static let rsaEncryptionOAEPSHA224 = SecKeyAlgorithm("algid:encrypt:RSA:OAEP:SHA224")
    public static let rsaEncryptionOAEPSHA256 = SecKeyAlgorithm("algid:encrypt:RSA:OAEP:SHA256")
    public static let rsaEncryptionOAEPSHA384 = SecKeyAlgorithm("algid:encrypt:RSA:OAEP:SHA384")
    public static let rsaEncryptionOAEPSHA512 = SecKeyAlgorithm("algid:encrypt:RSA:OAEP:SHA512")
    public static let ecdhKeyExchangeStandard = SecKeyAlgorithm("algid:keyexchange:ECDH")
    public static let ecdhKeyExchangeStandardX963SHA1 = SecKeyAlgorithm("algid:keyexchange:ECDH:KDFX963:SHA1")
    public static let ecdhKeyExchangeStandardX963SHA224 = SecKeyAlgorithm("algid:keyexchange:ECDH:KDFX963:SHA224")
    public static let ecdhKeyExchangeStandardX963SHA256 = SecKeyAlgorithm("algid:keyexchange:ECDH:KDFX963:SHA256")
    public static let ecdhKeyExchangeStandardX963SHA384 = SecKeyAlgorithm("algid:keyexchange:ECDH:KDFX963:SHA384")
    public static let ecdhKeyExchangeStandardX963SHA512 = SecKeyAlgorithm("algid:keyexchange:ECDH:KDFX963:SHA512")
    public static let ecdhKeyExchangeCofactor = SecKeyAlgorithm("algid:keyexchange:ECDHC")
    public static let ecdhKeyExchangeCofactorX963SHA256 = SecKeyAlgorithm("algid:keyexchange:ECDHC:KDFX963:SHA256")
    // ECIES and RSA+AES-GCM hybrid encryption: names exist so code compiles; isim reports them unsupported
    public static let eciesEncryptionStandardX963SHA256AESGCM = SecKeyAlgorithm("algid:encrypt:ECIES:ECDH:KDFX963:SHA256:AESGCM")
    public static let eciesEncryptionCofactorVariableIVX963SHA256AESGCM = SecKeyAlgorithm("algid:encrypt:ECIES:ECDHC:KDFX963:SHA256:AESGCM-KDFIV")
    public static let eciesEncryptionStandardVariableIVX963SHA256AESGCM = SecKeyAlgorithm("algid:encrypt:ECIES:ECDH:KDFX963:SHA256:AESGCM-KDFIV")
    public static let rsaEncryptionOAEPSHA256AESGCM = SecKeyAlgorithm("algid:encrypt:RSA:OAEP:KeySize:SHA256:AESGCM")

    /// (kind, host alg code, key type): kind 0 sign, 1 encrypt, 2 key exchange
    var plan: (kind: Int, code: Int32, type: Int32, kdf: Int)? {
        let s = rawValue as String
        let parts = s.split(separator: ":").map(String.init)
        func digest(_ name: String?) -> Int32 {
            switch name { case "SHA1": return 1; case "SHA224": return 2; case "SHA256": return 3; case "SHA384": return 4; case "SHA512": return 5; default: return 0 }
        }
        guard parts.count >= 3, parts[0] == "algid" else { return nil }
        switch (parts[1], parts[2]) {
        case ("sign", "RSA"):
            guard parts.count >= 4 else { return nil }
            if parts[3] == "raw" { return (0, 4 << 8, 0, 0) }
            let message: Int32 = parts[3].hasPrefix("message") ? 16 : 0
            let scheme: Int32 = parts[3].hasSuffix("PSS") ? 1 : 0
            let d = digest(parts.count > 4 ? parts[4] : nil)
            if scheme == 0 && d == 0 && message == 0 { return (0, 0, 0, 0) }    // digest-PKCS1v15 raw (DigestInfo already applied)
            return (0, scheme << 8 | message | d, 0, 0)
        case ("sign", "ECDSA"):
            guard parts.count >= 4 else { return nil }
            if parts[3] == "RFC4754" { return (0, 3 << 8, 1, 0) }
            let message: Int32 = parts[3].hasPrefix("message") ? 16 : 0
            let scheme: Int32 = parts[3].hasSuffix("RFC4754") ? 3 : 2
            let d = digest(parts.count > 4 ? parts[4] : nil)
            if message != 0 && d == 0 { return nil }
            return (0, scheme << 8 | message | d, 1, 0)
        case ("encrypt", "RSA"):
            guard parts.count >= 4 else { return nil }
            if parts[3] == "raw" { return (1, 1, 0, 0) }
            if parts[3] == "PKCS1" { return (1, 0, 0, 0) }
            if parts[3] == "OAEP", parts.count == 5 { let d = digest(parts[4]); return d == 0 ? nil : (1, 1 + d, 0, 0) }
            return nil
        case ("keyexchange", "ECDH"), ("keyexchange", "ECDHC"):
            if parts.count == 3 { return (2, 0, 1, 0) }
            if parts.count == 5, parts[3] == "KDFX963" { let d = digest(parts[4]); return d == 0 ? nil : (2, d, 1, 1) }
            return nil
        default: return nil
        }
    }
}

public enum SecKeyOperationType: Int, Sendable {
    case sign = 0, verify = 1, encrypt = 2, decrypt = 3, keyExchange = 4
}

// MARK: - SecKey

public final class SecKey: CustomStringConvertible, Hashable {
    /// 0 RSA, 1 EC
    let type: Int32
    let isPrivate: Bool
    /// Apple's external representation
    let raw: [UInt8]
    let bits: Int
    var attributes: [String: Any]
    init(type: Int32, isPrivate: Bool, raw: [UInt8], bits: Int, attributes: [String: Any] = [:]) {
        self.type = type; self.isPrivate = isPrivate; self.raw = raw; self.bits = bits; self.attributes = attributes
    }
    static func load(type: Int32, isPrivate: Bool, raw: [UInt8]) -> SecKey? {
        let bits = raw.withUnsafeBufferPointer { isim_pki_key_bits(type, $0.baseAddress!, $0.count, isPrivate ? 1 : 0) }
        return bits > 0 ? SecKey(type: type, isPrivate: isPrivate, raw: raw, bits: Int(bits)) : nil
    }
    var typeString: String { type == 0 ? "42" : "73" }
    var publicRaw: [UInt8]? {
        if !isPrivate { return raw }
        var out = [UInt8](repeating: 0, count: 2048), n = out.count
        let ok = raw.withUnsafeBufferPointer { r in out.withUnsafeMutableBufferPointer { isim_pki_public(type, r.baseAddress!, r.count, $0.baseAddress, &n) } }
        return ok == 1 ? Array(out[0..<n]) : nil
    }
    /// kSecAttrApplicationLabel: SHA-1 of the public key (Apple: of the X9.63 point for EC, of the PKCS#1 key for RSA)
    var applicationLabel: [UInt8] { _sha1(publicRaw ?? raw) }
    public var description: String {
        "<SecKeyRef algorithm id: \(type == 0 ? 1 : 3), key type: \(type == 0 ? "RSA" : "ECSECPrimeRandom")\(isPrivate ? "PrivateKey" : "PublicKey"), version: 4, block size: \(bits) bits, addr: \(Unmanaged.passUnretained(self).toOpaque())>"
    }
    public static func == (a: SecKey, b: SecKey) -> Bool { a.type == b.type && a.isPrivate == b.isPrivate && a.raw == b.raw }
    public func hash(into h: inout Hasher) { h.combine(raw) }
}

func _sha1(_ d: [UInt8]) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: 20)
    d.withUnsafeBufferPointer { b in out.withUnsafeMutableBufferPointer { _ = CC_SHA1(b.baseAddress, CC_LONG(b.count), $0.baseAddress) } }
    return out
}
func _digest(_ d: Int32, _ data: [UInt8]) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: 64)
    let n: Int
    data.withUnsafeBufferPointer { b in
        out.withUnsafeMutableBufferPointer { o in
            switch d {
            case 1: _ = CC_SHA1(b.baseAddress, CC_LONG(b.count), o.baseAddress)
            case 2: _ = CC_SHA224(b.baseAddress, CC_LONG(b.count), o.baseAddress)
            case 4: _ = CC_SHA384(b.baseAddress, CC_LONG(b.count), o.baseAddress)
            case 5: _ = CC_SHA512(b.baseAddress, CC_LONG(b.count), o.baseAddress)
            default: _ = CC_SHA256(b.baseAddress, CC_LONG(b.count), o.baseAddress)
            }
        }
    }
    switch d { case 1: n = 20; case 2: n = 28; case 4: n = 48; case 5: n = 64; default: n = 32 }
    return Array(out[0..<n])
}

/// Sets `error` to an NSError in NSOSStatusErrorDomain (what Security returns) and returns nil.
func _secFail<T>(_ error: UnsafeMutablePointer<Unmanaged<CFError>?>?, _ status: OSStatus, _ message: String) -> T? {
    let e = NSError(domain: "NSOSStatusErrorDomain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
    error?.pointee = Unmanaged.passRetained(unsafeBitCast(e, to: CFError.self))
    return nil
}
func _hostError() -> String { String(cString: isim_pki_error()) }
func _attr(_ a: [String: Any], _ k: CFString) -> Any? { a[k as String] }
func _intAttr(_ v: Any?) -> Int? {
    if let i = v as? Int { return i }
    if let s = v as? String { return Int(s) }
    if let n = v as? NSNumber { return Int(n.intValue) }
    return nil
}
func _boolAttr(_ v: Any?) -> Bool { (v as? Bool) ?? (v as? NSNumber)?.boolValue ?? false }

public func SecKeyCreateRandomKey(_ parameters: CFDictionary, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> SecKey? {
    let p = (parameters as NSDictionary as? [String: Any]) ?? [:]
    if (_attr(p, kSecAttrTokenID) as? String) == "com.apple.setoken" {
        return _secFail(error, errSecUnimplemented, "The Secure Enclave is not available on isim (like the Simulator).")
    }
    let typeStr = (_attr(p, kSecAttrKeyType) as? String) ?? ""
    guard typeStr == "42" || typeStr == "73" else { return _secFail(error, errSecParam, "Unsupported key type \(typeStr) (isim supports RSA and EC keys)") }
    let type: Int32 = typeStr == "42" ? 0 : 1
    let bits = _intAttr(_attr(p, kSecAttrKeySizeInBits)) ?? (type == 0 ? 2048 : 256)
    guard isim_pki_available() == 1 else { return _secFail(error, errSecNotAvailable, _hostError()) }
    var out = [UInt8](repeating: 0, count: 8192), n = out.count
    guard out.withUnsafeMutableBufferPointer({ isim_pki_generate(type, Int32(bits), $0.baseAddress, &n) }) == 1 else {
        return _secFail(error, errSecParam, _hostError())
    }
    let key = SecKey(type: type, isPrivate: true, raw: Array(out[0..<n]), bits: bits)
    let privAttrs = (_attr(p, kSecPrivateKeyAttrs) as? [String: Any]) ?? [:]
    var merged = p; merged.removeValue(forKey: "private"); merged.removeValue(forKey: "public")
    for (k, v) in privAttrs { merged[k] = v }
    key.attributes = merged.filter { ["atag", "labl", "perm", "agrp", "sync", "pdmn"].contains($0.key) }
    if _boolAttr(merged["perm"]) {
        var item: [String: Any] = merged.filter { ["atag", "labl", "agrp", "sync", "pdmn", "accc"].contains($0.key) }
        item["class"] = "keys"; item["v_Ref"] = key
        let st = _Keychain.shared.add(item, nil)
        if st != errSecSuccess { return _secFail(error, st, "The key could not be stored in the keychain (\(st))") }
    }
    return key
}
public func SecKeyCopyPublicKey(_ key: SecKey) -> SecKey? {
    guard let pub = key.publicRaw else { return nil }
    return SecKey(type: key.type, isPrivate: false, raw: pub, bits: key.bits)
}
public func SecKeyCopyExternalRepresentation(_ key: SecKey, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    Data(key.raw) as CFData
}
public func SecKeyCreateWithData(_ keyData: CFData, _ attributes: CFDictionary, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> SecKey? {
    let a = (attributes as NSDictionary as? [String: Any]) ?? [:]
    let typeStr = (_attr(a, kSecAttrKeyType) as? String) ?? ""
    guard typeStr == "42" || typeStr == "73" else { return _secFail(error, errSecParam, "Unsupported key type \(typeStr)") }
    let cls = (_attr(a, kSecAttrKeyClass) as? String) ?? ""
    guard cls == "0" || cls == "1" else { return _secFail(error, errSecParam, "kSecAttrKeyClass must be public or private") }
    guard isim_pki_available() == 1 else { return _secFail(error, errSecNotAvailable, _hostError()) }
    guard let key = SecKey.load(type: typeStr == "42" ? 0 : 1, isPrivate: cls == "1", raw: Array(keyData as Data)) else {
        return _secFail(error, errSecDecode, "The key data could not be decoded: \(_hostError())")
    }
    return key
}
public func SecKeyCopyAttributes(_ key: SecKey) -> CFDictionary? {
    var d: [String: Any] = key.attributes
    d["type"] = key.typeString
    d["kcls"] = key.isPrivate ? "1" : "0"
    d["bsiz"] = key.bits; d["esiz"] = key.bits
    d["klbl"] = Data(key.applicationLabel)
    d["v_Data"] = Data(key.raw)
    d["sign"] = key.isPrivate; d["vrfy"] = !key.isPrivate
    d["decr"] = key.isPrivate && key.type == 0; d["encr"] = !key.isPrivate && key.type == 0
    d["drve"] = key.isPrivate && key.type == 1
    d["perm"] = _boolAttr(key.attributes["perm"])
    return d as NSDictionary as CFDictionary
}
public func SecKeyGetBlockSize(_ key: SecKey) -> Int { key.type == 0 ? key.bits / 8 : (key.bits + 7) / 8 * 2 + 8 }

public func SecKeyIsAlgorithmSupported(_ key: SecKey, _ operation: SecKeyOperationType, _ algorithm: SecKeyAlgorithm) -> Bool {
    guard let plan = algorithm.plan, plan.type == key.type else { return false }
    switch operation {
    case .sign: return plan.kind == 0 && key.isPrivate
    case .verify: return plan.kind == 0 && !key.isPrivate
    case .encrypt: return plan.kind == 1 && !key.isPrivate
    case .decrypt: return plan.kind == 1 && key.isPrivate
    case .keyExchange: return plan.kind == 2 && key.isPrivate
    }
}

public func SecKeyCreateSignature(_ key: SecKey, _ algorithm: SecKeyAlgorithm, _ dataToSign: CFData,
                                  _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    guard SecKeyIsAlgorithmSupported(key, .sign, algorithm), let plan = algorithm.plan else {
        return _secFail(error, errSecParam, "\(algorithm.rawValue) is not supported for this key")
    }
    let data = Array(dataToSign as Data)
    var sig = [UInt8](repeating: 0, count: 1200), n = sig.count
    let ok = key.raw.withUnsafeBufferPointer { k in data.withUnsafeBufferPointer { d in sig.withUnsafeMutableBufferPointer { s in
        isim_pki_sign(key.type, k.baseAddress!, k.count, plan.code, d.baseAddress, d.count, s.baseAddress!, &n) } } }
    guard ok == 1 else { return _secFail(error, errSecParam, _hostError()) }
    return Data(sig[0..<n]) as CFData
}
public func SecKeyVerifySignature(_ key: SecKey, _ algorithm: SecKeyAlgorithm, _ signedData: CFData, _ signature: CFData,
                                  _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
    guard SecKeyIsAlgorithmSupported(key, .verify, algorithm), let plan = algorithm.plan else {
        let _: Bool? = _secFail(error, errSecParam, "\(algorithm.rawValue) is not supported for this key"); return false
    }
    let data = Array(signedData as Data), sig = Array(signature as Data)
    let ok = key.raw.withUnsafeBufferPointer { k in data.withUnsafeBufferPointer { d in sig.withUnsafeBufferPointer { s in
        isim_pki_verify(key.type, k.baseAddress!, k.count, plan.code, d.baseAddress, d.count, s.baseAddress ?? UnsafePointer(bitPattern: 1)!, s.count) } } }
    if ok != 1 { let _: Bool? = _secFail(error, -67808 /* errSecVerifyFailed */, "EC signature verification failed, signature does not match"); return false }
    return true
}
public func SecKeyCreateEncryptedData(_ key: SecKey, _ algorithm: SecKeyAlgorithm, _ plaintext: CFData,
                                      _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    guard SecKeyIsAlgorithmSupported(key, .encrypt, algorithm), let plan = algorithm.plan else {
        return _secFail(error, errSecParam, "\(algorithm.rawValue) is not supported for this key on isim")
    }
    let input = Array(plaintext as Data)
    var out = [UInt8](repeating: 0, count: key.bits / 8 + 16), n = out.count
    let ok = key.raw.withUnsafeBufferPointer { k in input.withUnsafeBufferPointer { i in out.withUnsafeMutableBufferPointer { o in
        isim_pki_encrypt(k.baseAddress!, k.count, plan.code, i.baseAddress, i.count, o.baseAddress!, &n) } } }
    guard ok == 1 else { return _secFail(error, errSecParam, _hostError()) }
    return Data(out[0..<n]) as CFData
}
public func SecKeyCreateDecryptedData(_ key: SecKey, _ algorithm: SecKeyAlgorithm, _ ciphertext: CFData,
                                      _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm), let plan = algorithm.plan else {
        return _secFail(error, errSecParam, "\(algorithm.rawValue) is not supported for this key on isim")
    }
    let input = Array(ciphertext as Data)
    guard !input.isEmpty else { return _secFail(error, errSecParam, "empty ciphertext") }
    var out = [UInt8](repeating: 0, count: key.bits / 8 + 16), n = out.count
    let ok = key.raw.withUnsafeBufferPointer { k in input.withUnsafeBufferPointer { i in out.withUnsafeMutableBufferPointer { o in
        isim_pki_decrypt(k.baseAddress!, k.count, plan.code, i.baseAddress!, i.count, o.baseAddress!, &n) } } }
    guard ok == 1 else { return _secFail(error, errSecDecode, _hostError()) }
    return Data(out[0..<n]) as CFData
}
public func SecKeyCopyKeyExchangeResult(_ privateKey: SecKey, _ algorithm: SecKeyAlgorithm, _ publicKey: SecKey, _ parameters: CFDictionary,
                                        _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    guard SecKeyIsAlgorithmSupported(privateKey, .keyExchange, algorithm), let plan = algorithm.plan, publicKey.type == 1 else {
        return _secFail(error, errSecParam, "\(algorithm.rawValue) is not supported for these keys")
    }
    let pub = publicKey.publicRaw ?? publicKey.raw
    var out = [UInt8](repeating: 0, count: 80), n = out.count
    let ok = privateKey.raw.withUnsafeBufferPointer { k in pub.withUnsafeBufferPointer { p in out.withUnsafeMutableBufferPointer { o in
        isim_pki_ecdh(k.baseAddress!, k.count, p.baseAddress!, p.count, o.baseAddress!, &n) } } }
    guard ok == 1 else { return _secFail(error, errSecParam, _hostError()) }
    let shared = Array(out[0..<n])
    guard plan.kdf == 1 else { return Data(shared) as CFData }
    // ANSI X9.63 KDF: Hash(Z || counter32 || SharedInfo) blocks
    let p = (parameters as NSDictionary as? [String: Any]) ?? [:]
    guard let size = _intAttr(p["requestedSize"]), size > 0 else { return _secFail(error, errSecParam, "kSecKeyKeyExchangeParameterRequestedSize is required") }
    let info = (p["sharedInfo"] as? Data).map(Array.init) ?? []
    var derived: [UInt8] = [], counter: UInt32 = 1
    while derived.count < size {
        let c = [UInt8(counter >> 24), UInt8(counter >> 16 & 0xff), UInt8(counter >> 8 & 0xff), UInt8(counter & 0xff)]
        derived += _digest(plan.code, shared + c + info)
        counter += 1
    }
    return Data(derived.prefix(size)) as CFData
}
