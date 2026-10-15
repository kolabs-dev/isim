// isim Security for C and Objective-C (sdk-src/Frameworks/Security): the SecKey and SecRandom functions under their C
// names, forwarding to this overlay's implementations (RSA and EC through the host's OpenSSL). A SecKeyRef is the
// overlay's SecKey object (CFRetain / CFRelease work on it); the C constants (kSecAttrKeyType...) are defined with the
// same values in frameworks/Security/Security.m.
import Foundation

private func key(_ p: UnsafeRawPointer) -> SecKey { Unmanaged<SecKey>.fromOpaque(p).takeUnretainedValue() }
private func retained(_ k: SecKey?) -> UnsafeMutableRawPointer? { k.map { Unmanaged.passRetained($0).toOpaque() } }
private func retained(_ d: CFData?) -> CFData? { d.map { Unmanaged.passRetained($0).takeUnretainedValue() } }

@_cdecl("SecKeyCreateRandomKey")
public func _c_SecKeyCreateRandomKey(_ params: CFDictionary, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> UnsafeMutableRawPointer? {
    retained(SecKeyCreateRandomKey(params, error))
}
@_cdecl("SecKeyCreateWithData")
public func _c_SecKeyCreateWithData(_ data: CFData, _ attrs: CFDictionary, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> UnsafeMutableRawPointer? {
    retained(SecKeyCreateWithData(data, attrs, error))
}
@_cdecl("SecKeyCopyPublicKey")
public func _c_SecKeyCopyPublicKey(_ k: UnsafeRawPointer) -> UnsafeMutableRawPointer? { retained(SecKeyCopyPublicKey(key(k))) }
@_cdecl("SecKeyCopyExternalRepresentation")
public func _c_SecKeyCopyExternalRepresentation(_ k: UnsafeRawPointer, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCopyExternalRepresentation(key(k), error))
}
@_cdecl("SecKeyCopyAttributes")
public func _c_SecKeyCopyAttributes(_ k: UnsafeRawPointer) -> CFDictionary? {
    SecKeyCopyAttributes(key(k)).map { Unmanaged.passRetained($0).takeUnretainedValue() }
}
@_cdecl("SecKeyGetBlockSize")
public func _c_SecKeyGetBlockSize(_ k: UnsafeRawPointer) -> Int { SecKeyGetBlockSize(key(k)) }
@_cdecl("SecKeyIsAlgorithmSupported")
public func _c_SecKeyIsAlgorithmSupported(_ k: UnsafeRawPointer, _ op: Int, _ alg: CFString) -> Bool {
    guard let o = SecKeyOperationType(rawValue: op) else { return false }
    return SecKeyIsAlgorithmSupported(key(k), o, SecKeyAlgorithm(rawValue: alg))
}
@_cdecl("SecKeyCreateSignature")
public func _c_SecKeyCreateSignature(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCreateSignature(key(k), SecKeyAlgorithm(rawValue: alg), data, error))
}
@_cdecl("SecKeyVerifySignature")
public func _c_SecKeyVerifySignature(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ sig: CFData,
                              _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
    SecKeyVerifySignature(key(k), SecKeyAlgorithm(rawValue: alg), data, sig, error)
}
@_cdecl("SecKeyCreateEncryptedData")
public func _c_SecKeyCreateEncryptedData(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCreateEncryptedData(key(k), SecKeyAlgorithm(rawValue: alg), data, error))
}
@_cdecl("SecKeyCreateDecryptedData")
public func _c_SecKeyCreateDecryptedData(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCreateDecryptedData(key(k), SecKeyAlgorithm(rawValue: alg), data, error))
}
@_cdecl("SecRandomCopyBytes")
public func _c_SecRandomCopyBytes(_ rnd: OpaquePointer?, _ count: Int, _ bytes: UnsafeMutableRawPointer) -> Int32 { SecRandomCopyBytes(rnd, count, bytes) }

// MARK: - the keychain (SecItem*) and SecAccessControl for C: the same items as Swift's; results are +1 (CF "Copy")

private func store(_ r: CFTypeRef?, _ out: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) {
    out?.pointee = r.map { Unmanaged.passRetained($0 as AnyObject).toOpaque() }
}
@_cdecl("SecItemAdd")
public func _c_SecItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> OSStatus {
    guard let result else { return SecItemAdd(attributes, nil) }
    var r: CFTypeRef?
    let s = SecItemAdd(attributes, &r)
    store(r, result)
    return s
}
@_cdecl("SecItemCopyMatching")
public func _c_SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> OSStatus {
    guard let result else { return SecItemCopyMatching(query, nil) }
    var r: CFTypeRef?
    let s = SecItemCopyMatching(query, &r)
    store(r, result)
    return s
}
@_cdecl("SecItemUpdate")
public func _c_SecItemUpdate(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus { SecItemUpdate(query, attributes) }
@_cdecl("SecItemDelete")
public func _c_SecItemDelete(_ query: CFDictionary) -> OSStatus { SecItemDelete(query) }
@_cdecl("SecCopyErrorMessageString")
public func _c_SecCopyErrorMessageString(_ status: OSStatus, _ reserved: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    SecCopyErrorMessageString(status, reserved).map { Unmanaged.passRetained($0 as AnyObject).toOpaque() }
}
@_cdecl("SecAccessControlCreateWithFlags")
public func _c_SecAccessControlCreateWithFlags(_ allocator: UnsafeRawPointer?, _ protection: UnsafeRawPointer, _ flags: UInt,
                                               _ error: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> UnsafeMutableRawPointer? {
    let p = Unmanaged<AnyObject>.fromOpaque(protection).takeUnretainedValue()
    return SecAccessControlCreateWithFlags(nil, p, SecAccessControlCreateFlags(rawValue: flags), nil).map { Unmanaged.passRetained($0).toOpaque() }
}
@_cdecl("SecAccessControlGetTypeID") public func _c_SecAccessControlGetTypeID() -> UInt { SecAccessControlGetTypeID() }

// MARK: - certificates, policies, trust and identities for C (the overlay's objects; trust is Foundation's SecTrust)

private func cert(_ p: UnsafeRawPointer) -> SecCertificate { Unmanaged<SecCertificate>.fromOpaque(p).takeUnretainedValue() }
private func trust(_ p: UnsafeRawPointer) -> SecTrust { Unmanaged<SecTrust>.fromOpaque(p).takeUnretainedValue() }
private func plus1(_ o: AnyObject?) -> UnsafeMutableRawPointer? { o.map { Unmanaged.passRetained($0).toOpaque() } }
private func object(_ p: UnsafeRawPointer?) -> CFTypeRef? { p.map { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() } }

@_cdecl("SecCertificateGetTypeID") public func _c_SecCertificateGetTypeID() -> UInt { SecCertificateGetTypeID() }
@_cdecl("SecCertificateCreateWithData")
public func _c_SecCertificateCreateWithData(_ allocator: UnsafeRawPointer?, _ data: CFData) -> UnsafeMutableRawPointer? {
    plus1(SecCertificateCreateWithData(nil, data))
}
@_cdecl("SecCertificateCopyData")
public func _c_SecCertificateCopyData(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? { plus1(SecCertificateCopyData(cert(c)) as NSData) }
@_cdecl("SecCertificateCopySubjectSummary")
public func _c_SecCertificateCopySubjectSummary(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    plus1(SecCertificateCopySubjectSummary(cert(c)).map { $0 as NSString })
}
@_cdecl("SecCertificateCopyCommonName")
public func _c_SecCertificateCopyCommonName(_ c: UnsafeRawPointer, _ out: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> OSStatus {
    var name: CFString?
    let s = SecCertificateCopyCommonName(cert(c), &name)
    out.pointee = plus1(name.map { $0 as NSString })
    return s
}
@_cdecl("SecCertificateCopyKey")
public func _c_SecCertificateCopyKey(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? { plus1(SecCertificateCopyKey(cert(c))) }
@_cdecl("SecCertificateCopySerialNumberData")
public func _c_SecCertificateCopySerialNumberData(_ c: UnsafeRawPointer, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> UnsafeMutableRawPointer? {
    plus1(SecCertificateCopySerialNumberData(cert(c), error).map { $0 as NSData })
}

@_cdecl("SecPolicyGetTypeID") public func _c_SecPolicyGetTypeID() -> UInt { SecPolicyGetTypeID() }
@_cdecl("SecPolicyCreateSSL")
public func _c_SecPolicyCreateSSL(_ server: Bool, _ hostname: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    plus1(SecPolicyCreateSSL(server, object(hostname).map { $0 as! CFString }))
}
@_cdecl("SecPolicyCreateBasicX509") public func _c_SecPolicyCreateBasicX509() -> UnsafeMutableRawPointer? { plus1(SecPolicyCreateBasicX509()) }

@_cdecl("SecTrustGetTypeID") public func _c_SecTrustGetTypeID() -> UInt { SecTrustGetTypeID() }
@_cdecl("SecTrustCreateWithCertificates")
public func _c_SecTrustCreateWithCertificates(_ certificates: UnsafeRawPointer, _ policies: UnsafeRawPointer?,
                                              _ out: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> OSStatus {
    var t: SecTrust?
    let s = SecTrustCreateWithCertificates(object(certificates)!, object(policies), &t)
    out.pointee = plus1(t)
    return s
}
@_cdecl("SecTrustSetPolicies")
public func _c_SecTrustSetPolicies(_ t: UnsafeRawPointer, _ policies: UnsafeRawPointer) -> OSStatus { SecTrustSetPolicies(trust(t), object(policies)!) }
@_cdecl("SecTrustSetAnchorCertificates")
public func _c_SecTrustSetAnchorCertificates(_ t: UnsafeRawPointer, _ anchors: CFArray?) -> OSStatus { SecTrustSetAnchorCertificates(trust(t), anchors) }
@_cdecl("SecTrustSetAnchorCertificatesOnly")
public func _c_SecTrustSetAnchorCertificatesOnly(_ t: UnsafeRawPointer, _ only: Bool) -> OSStatus { SecTrustSetAnchorCertificatesOnly(trust(t), only) }
@_cdecl("SecTrustSetVerifyDate")
public func _c_SecTrustSetVerifyDate(_ t: UnsafeRawPointer, _ date: UnsafeRawPointer) -> OSStatus {
    SecTrustSetVerifyDate(trust(t), Unmanaged<NSDate>.fromOpaque(date).takeUnretainedValue())
}
@_cdecl("SecTrustSetNetworkFetchAllowed")
public func _c_SecTrustSetNetworkFetchAllowed(_ t: UnsafeRawPointer, _ allow: Bool) -> OSStatus { SecTrustSetNetworkFetchAllowed(trust(t), allow) }
@_cdecl("SecTrustEvaluateWithError")
public func _c_SecTrustEvaluateWithError(_ t: UnsafeRawPointer, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
    SecTrustEvaluateWithError(trust(t), error)
}
@_cdecl("SecTrustEvaluate")
public func _c_SecTrustEvaluate(_ t: UnsafeRawPointer, _ result: UnsafeMutablePointer<UInt32>) -> OSStatus {
    _ = SecTrustEvaluateWithError(trust(t), nil)           // the deprecated form: evaluate, then report the result
    var r = SecTrustResultType.invalid
    let s = SecTrustGetTrustResult(trust(t), &r)
    result.pointee = r.rawValue
    return s
}
@_cdecl("SecTrustGetTrustResult")
public func _c_SecTrustGetTrustResult(_ t: UnsafeRawPointer, _ result: UnsafeMutablePointer<UInt32>) -> OSStatus {
    var r = SecTrustResultType.invalid
    let s = SecTrustGetTrustResult(trust(t), &r)
    result.pointee = r.rawValue
    return s
}
@_cdecl("SecTrustGetCertificateCount") public func _c_SecTrustGetCertificateCount(_ t: UnsafeRawPointer) -> Int { SecTrustGetCertificateCount(trust(t)) }
@_cdecl("SecTrustCopyCertificateChain")
public func _c_SecTrustCopyCertificateChain(_ t: UnsafeRawPointer) -> UnsafeMutableRawPointer? { plus1(SecTrustCopyCertificateChain(trust(t))) }
@_cdecl("SecTrustCopyKey") public func _c_SecTrustCopyKey(_ t: UnsafeRawPointer) -> UnsafeMutableRawPointer? { plus1(SecTrustCopyKey(trust(t))) }
@_cdecl("SecTrustCopyExceptions")
public func _c_SecTrustCopyExceptions(_ t: UnsafeRawPointer) -> UnsafeMutableRawPointer? { plus1(SecTrustCopyExceptions(trust(t)).map { $0 as NSData }) }
@_cdecl("SecTrustSetExceptions")
public func _c_SecTrustSetExceptions(_ t: UnsafeRawPointer, _ exceptions: CFData?) -> Bool { SecTrustSetExceptions(trust(t), exceptions) }

@_cdecl("SecIdentityGetTypeID") public func _c_SecIdentityGetTypeID() -> UInt { SecIdentityGetTypeID() }
@_cdecl("SecIdentityCopyCertificate")
public func _c_SecIdentityCopyCertificate(_ i: UnsafeRawPointer, _ out: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> OSStatus {
    var c: SecCertificate?
    let s = SecIdentityCopyCertificate(Unmanaged<SecIdentity>.fromOpaque(i).takeUnretainedValue(), &c)
    out.pointee = plus1(c)
    return s
}
@_cdecl("SecIdentityCopyPrivateKey")
public func _c_SecIdentityCopyPrivateKey(_ i: UnsafeRawPointer, _ out: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> OSStatus {
    var k: SecKey?
    let s = SecIdentityCopyPrivateKey(Unmanaged<SecIdentity>.fromOpaque(i).takeUnretainedValue(), &k)
    out.pointee = plus1(k)
    return s
}
@_cdecl("SecPKCS12Import")
public func _c_SecPKCS12Import(_ data: CFData, _ options: CFDictionary, _ out: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> OSStatus {
    var items: CFArray?
    let s = SecPKCS12Import(data, options, &items)
    out.pointee = plus1(items)
    return s
}
@_cdecl("SecKeyGetTypeID") public func _c_SecKeyGetTypeID() -> UInt { SecKeyGetTypeID() }
