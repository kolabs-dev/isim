// isim Security: certificates, policies, trust evaluation, PKCS#12 import and identities (self-authored, iOS names).
// X.509 parsing, chain building and verification run in the host's OpenSSL (host_pki.c). The system anchors are the
// host's CA store (Apple's trust store and its policies — CT, key-size rules, revocation — are not reproduced).
// SecTrust is Foundation's class (URLSession hands out trusts in challenges); this file adds its certificate state.
import Foundation
import isim_host

// MARK: - SecCertificate

public final class SecCertificate: CustomStringConvertible, Hashable {
    let der: [UInt8]
    let info: [String: Any]
    init?(der: [UInt8]) {
        guard isim_pki_available() == 1, !der.isEmpty else { return nil }
        var buf = [CChar](repeating: 0, count: 65536)
        let ok = der.withUnsafeBufferPointer { d in buf.withUnsafeMutableBufferPointer { isim_pki_cert_parse(d.baseAddress!, d.count, $0.baseAddress!, $0.count) } }
        guard ok == 1, let json = try? JSONSerialization.jsonObject(with: Data(String(cString: buf).utf8)) as? [String: Any] else { return nil }
        self.der = der; info = json
    }
    /// [[shortName, oid, value]]
    func name(_ which: String) -> [[String]] { (info[which] as? [[String]]) ?? [] }
    func first(_ which: String, _ short: String) -> String? { name(which).first { $0.first == short }?[2] }
    var subjectSummary: String? { first("subject", "CN") ?? first("subject", "emailAddress") ?? first("subject", "O") ?? name("subject").first?[2] }
    var serial: [UInt8] { _unhex(info["serial"] as? String ?? "") }
    var issuerDER: [UInt8] { _unhex(info["issuerDER"] as? String ?? "") }
    var subjectDER: [UInt8] { _unhex(info["subjectDER"] as? String ?? "") }
    var notBefore: Date { Date(timeIntervalSince1970: info["notBefore"] as? Double ?? 0) }
    var notAfter: Date { Date(timeIntervalSince1970: info["notAfter"] as? Double ?? 0) }
    var publicKeyRaw: [UInt8]? { (info["publicKey"] as? String).map(_unhex) }
    var keyType: Int32? { switch info["keyType"] as? String { case "RSA": return 0; case "EC": return 1; default: return nil } }
    var publicKey: SecKey? { keyType.flatMap { t in publicKeyRaw.flatMap { SecKey.load(type: t, isPrivate: false, raw: $0) } } }
    public var description: String { "<cert(\(Unmanaged.passUnretained(self).toOpaque()))> s: \(subjectSummary ?? "") i: \(first("issuer", "CN") ?? "")" }
    public static func == (a: SecCertificate, b: SecCertificate) -> Bool { a.der == b.der }
    public func hash(into h: inout Hasher) { h.combine(der) }
}

func _unhex(_ s: String) -> [UInt8] {
    var out: [UInt8] = []; out.reserveCapacity(s.count / 2)
    var it = s.utf8.makeIterator()
    func v(_ c: UInt8) -> UInt8 { c >= 97 ? c - 87 : c >= 65 ? c - 55 : c - 48 }
    while let a = it.next(), let b = it.next() { out.append(v(a) << 4 | v(b)) }
    return out
}
func _cfArray(_ items: [AnyObject]) -> CFArray { items as NSArray as CFArray }
func _array(_ x: CFTypeRef?) -> [AnyObject] {
    guard let x else { return [] }
    if let a = x as? [AnyObject] { return a }
    if let a = x as? NSArray { return (0..<a.count).map { a.object(at: $0) as AnyObject } }
    return [x as AnyObject]
}

public func SecCertificateGetTypeID() -> CFTypeID { 0x5ec0 }
public func SecCertificateCreateWithData(_ allocator: CFAllocator?, _ data: CFData) -> SecCertificate? { SecCertificate(der: Array(data as Data)) }
public func SecCertificateCopyData(_ certificate: SecCertificate) -> CFData { Data(certificate.der) as CFData }
public func SecCertificateCopySubjectSummary(_ certificate: SecCertificate) -> CFString? { certificate.subjectSummary.map { $0 as CFString } }
public func SecCertificateCopyCommonName(_ certificate: SecCertificate, _ commonName: UnsafeMutablePointer<CFString?>) -> OSStatus {
    commonName.pointee = certificate.first("subject", "CN").map { $0 as CFString }
    return errSecSuccess
}
public func SecCertificateCopyEmailAddresses(_ certificate: SecCertificate, _ emailAddresses: UnsafeMutablePointer<CFArray?>) -> OSStatus {
    let emails = (certificate.info["emails"] as? [String]) ?? []
    emailAddresses.pointee = emails as NSArray as CFArray
    return errSecSuccess
}
public func SecCertificateCopyKey(_ certificate: SecCertificate) -> SecKey? { certificate.publicKey }
@available(iOS, deprecated: 14.0, renamed: "SecCertificateCopyKey")
public func SecCertificateCopyPublicKey(_ certificate: SecCertificate) -> SecKey? { certificate.publicKey }
public func SecCertificateCopySerialNumberData(_ certificate: SecCertificate, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    Data(certificate.serial) as CFData
}
public func SecCertificateCopyNormalizedIssuerSequence(_ certificate: SecCertificate) -> CFData? { Data(certificate.issuerDER) as CFData }
public func SecCertificateCopyNormalizedSubjectSequence(_ certificate: SecCertificate) -> CFData? { Data(certificate.subjectDER) as CFData }
/// isim extensions used by tests and tools (not Apple API): validity dates
public func _isimCertificateValidity(_ certificate: SecCertificate) -> (notBefore: Date, notAfter: Date) { (certificate.notBefore, certificate.notAfter) }

// MARK: - SecPolicy

public final class SecPolicy: CustomStringConvertible {
    let ssl: Bool, server: Bool, hostname: String?
    init(ssl: Bool, server: Bool, hostname: String?) { self.ssl = ssl; self.server = server; self.hostname = hostname }
    public var description: String { ssl ? "<SecPolicy SSL \(server ? "server" : "client") \(hostname ?? "")>" : "<SecPolicy basic X.509>" }
}
public let kSecPolicyAppleX509Basic: CFString = "1.2.840.113635.100.1.2" as CFString
public let kSecPolicyAppleSSL: CFString = "1.2.840.113635.100.1.3" as CFString
public let kSecPolicyOid: CFString = "SecPolicyOid" as CFString
public let kSecPolicyName: CFString = "SecPolicyName" as CFString
public let kSecPolicyClient: CFString = "SecPolicyClient" as CFString
public func SecPolicyCreateBasicX509() -> SecPolicy { SecPolicy(ssl: false, server: false, hostname: nil) }
public func SecPolicyCreateSSL(_ server: Bool, _ hostname: CFString?) -> SecPolicy { SecPolicy(ssl: true, server: server, hostname: hostname.map { $0 as String }) }
public func SecPolicyCopyProperties(_ policyRef: SecPolicy) -> CFDictionary? {
    var d: [String: Any] = ["SecPolicyOid": policyRef.ssl ? "1.2.840.113635.100.1.3" : "1.2.840.113635.100.1.2"]
    if let h = policyRef.hostname { d["SecPolicyName"] = h }
    if policyRef.ssl && !policyRef.server { d["SecPolicyClient"] = true }
    return d as NSDictionary as CFDictionary
}

// MARK: - SecTrust (Foundation's class)

public enum SecTrustResultType: UInt32, Sendable {
    case invalid = 0, proceed = 1, deny = 3, unspecified = 4, recoverableTrustFailure = 5, fatalTrustFailure = 6, otherError = 7
    @available(*, deprecated) public static let confirm = SecTrustResultType.invalid
}
public let errSecCertificateExpired: OSStatus = -67818
public let errSecCertificateNotValidYet: OSStatus = -67819
public let errSecNotTrusted: OSStatus = -67843
public let errSecHostNameMismatch: OSStatus = -67602
public let errSecVerifyFailed: OSStatus = -67808
public let errSecInvalidCertificateRef: OSStatus = -67723
public let errSecPkcs12VerifyFailure: OSStatus = -25264
public let errSecPassphraseRequired: OSStatus = -25260

final class _TrustState {
    var certificates: [SecCertificate]
    var policies: [SecPolicy]
    var anchors: [SecCertificate] = []
    var anchorsOnly = false
    var verifyDate: Date?
    var exceptions: [UInt8]?
    var result: SecTrustResultType = .invalid
    var chain: [SecCertificate] = []
    var failure: (OSStatus, String)?
    init(certificates: [SecCertificate], policies: [SecPolicy]) { self.certificates = certificates; self.policies = policies }
}
extension SecTrust {
    /// the certificate state; an HTTPS challenge's trust gets the server's certificates (when URLSession could read
    /// them) with an SSL policy for the host
    var state: _TrustState {
        if let s = _isimState as? _TrustState { return s }
        let s = _TrustState(certificates: _isimChain.compactMap { SecCertificate(der: $0) }, policies: [SecPolicyCreateSSL(true, _host as CFString)])
        _isimState = s
        return s
    }
}

public func SecTrustGetTypeID() -> CFTypeID { 0x5ec1 }
public func SecTrustCreateWithCertificates(_ certificates: CFTypeRef, _ policies: CFTypeRef?, _ trust: UnsafeMutablePointer<SecTrust?>) -> OSStatus {
    let certs = _array(certificates).compactMap { $0 as? SecCertificate }
    guard !certs.isEmpty else { trust.pointee = nil; return errSecParam }
    let pols = _array(policies).compactMap { $0 as? SecPolicy }
    let host = pols.first { $0.ssl }?.hostname ?? ""
    trust.pointee = SecTrust(_isimHost: host, state: _TrustState(certificates: certs, policies: pols.isEmpty ? [SecPolicyCreateBasicX509()] : pols))
    return errSecSuccess
}
public func SecTrustSetPolicies(_ trust: SecTrust, _ policies: CFTypeRef) -> OSStatus {
    trust.state.policies = _array(policies).compactMap { $0 as? SecPolicy }; trust.state.result = .invalid; return errSecSuccess
}
public func SecTrustCopyPolicies(_ trust: SecTrust, _ policies: UnsafeMutablePointer<CFArray?>) -> OSStatus {
    policies.pointee = _cfArray(trust.state.policies); return errSecSuccess
}
public func SecTrustSetAnchorCertificates(_ trust: SecTrust, _ anchorCertificates: CFArray?) -> OSStatus {
    trust.state.anchors = _array(anchorCertificates).compactMap { $0 as? SecCertificate }
    trust.state.anchorsOnly = !trust.state.anchors.isEmpty     // like Apple: custom anchors replace the system ones
    trust.state.result = .invalid
    return errSecSuccess
}
public func SecTrustSetAnchorCertificatesOnly(_ trust: SecTrust, _ anchorCertificatesOnly: Bool) -> OSStatus {
    trust.state.anchorsOnly = anchorCertificatesOnly; trust.state.result = .invalid; return errSecSuccess
}
public func SecTrustCopyCustomAnchorCertificates(_ trust: SecTrust, _ anchors: UnsafeMutablePointer<CFArray?>) -> OSStatus {
    anchors.pointee = trust.state.anchors.isEmpty ? nil : _cfArray(trust.state.anchors); return errSecSuccess
}
/// CFDate is toll-free bridged to NSDate (isim's CoreFoundation subset has no CFDate type of its own)
public typealias CFDate = NSDate
public typealias CFAbsoluteTime = Double
public func SecTrustSetVerifyDate(_ trust: SecTrust, _ verifyDate: CFDate) -> OSStatus {
    trust.state.verifyDate = verifyDate as Date; trust.state.result = .invalid; return errSecSuccess
}
public func SecTrustGetVerifyTime(_ trust: SecTrust) -> CFAbsoluteTime { (trust.state.verifyDate ?? Date()).timeIntervalSinceReferenceDate }
public func SecTrustSetNetworkFetchAllowed(_ trust: SecTrust, _ allowFetch: Bool) -> OSStatus { errSecSuccess }
public func SecTrustGetNetworkFetchAllowed(_ trust: SecTrust, _ allowFetch: UnsafeMutablePointer<Bool>) -> OSStatus { allowFetch.pointee = false; return errSecSuccess }

func _evaluate(_ trust: SecTrust) -> Bool {
    let st = trust.state
    if st.certificates.isEmpty {
        // an HTTPS challenge's trust: isim's URL loading (libcurl) checks the server's chain against the host's CA store
        // when the request proceeds; nothing more is known here
        st.result = .unspecified; st.chain = []; st.failure = nil
        return true
    }
    let ssl = st.policies.first { $0.ssl }
    var certBytes: [UInt8] = [], lens: [Int] = []
    for c in st.certificates { certBytes += c.der; lens.append(c.der.count) }
    var anchorBytes: [UInt8] = [], alens: [Int] = []
    for c in st.anchors { anchorBytes += c.der; alens.append(c.der.count) }
    var err = [CChar](repeating: 0, count: 256), chainLen: Int32 = 0
    let when = st.verifyDate?.timeIntervalSince1970 ?? 0
    let useSystem: Int32 = st.anchors.isEmpty || !st.anchorsOnly ? 1 : 0
    let ok = certBytes.withUnsafeBufferPointer { cb in lens.withUnsafeBufferPointer { lb in anchorBytes.withUnsafeBufferPointer { ab in alens.withUnsafeBufferPointer { alb in
        err.withUnsafeMutableBufferPointer { eb in
            (ssl?.hostname ?? "").withCString { host in
                isim_pki_trust(cb.baseAddress!, lb.baseAddress!, Int32(lens.count), ab.baseAddress, alb.baseAddress, Int32(alens.count), useSystem,
                               ssl?.server == true ? 1 : 0, ssl?.hostname == nil ? nil : host, when, eb.baseAddress!, eb.count, &chainLen)
            } } } } } }
    let reason = String(cString: err)
    // the verified chain: leaf, then the matching certificates/anchors in issuer order
    var chain = [st.certificates[0]]
    let pool = st.certificates.dropFirst() + st.anchors
    while chain.count < max(1, Int(chainLen)), let last = chain.last, let next = pool.first(where: { $0.subjectDER == last.issuerDER && !chain.contains($0) }) {
        chain.append(next)
    }
    st.chain = chain
    if ok == 1 {
        st.result = .unspecified; st.failure = nil
        return true
    }
    if let e = st.exceptions, e == _sha1(st.certificates[0].der) {   // SecTrustSetExceptions accepted this leaf
        st.result = .proceed; st.failure = nil
        return true
    }
    let status: OSStatus
    if reason.contains("expired") { status = errSecCertificateExpired }
    else if reason.contains("not yet valid") { status = errSecCertificateNotValidYet }
    else if reason.contains("hostname") || reason.contains("Hostname") { status = errSecHostNameMismatch }
    else { status = errSecNotTrusted }
    st.failure = (status, reason)
    st.result = .recoverableTrustFailure
    return false
}

public func SecTrustEvaluateWithError(_ trust: SecTrust, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
    if _evaluate(trust) { return true }
    let (status, reason) = trust.state.failure ?? (errSecNotTrusted, "not trusted")
    let summary = trust.state.certificates.first?.subjectSummary ?? trust._host
    let _: Bool? = _secFail(error, status, "“\(summary)” certificate is not trusted (\(reason))")
    return false
}
public func SecTrustEvaluateAsyncWithError(_ trust: SecTrust, _ queue: DispatchQueue,
                                           _ result: @escaping (SecTrust, Bool, CFError?) -> Void) -> OSStatus {
    queue.async {
        var e: Unmanaged<CFError>?
        let ok = SecTrustEvaluateWithError(trust, &e)
        result(trust, ok, e?.takeRetainedValue())
    }
    return errSecSuccess
}
@available(iOS, deprecated: 13.0, renamed: "SecTrustEvaluateWithError")
public func SecTrustEvaluate(_ trust: SecTrust, _ result: UnsafeMutablePointer<SecTrustResultType>) -> OSStatus {
    _ = _evaluate(trust); result.pointee = trust.state.result; return errSecSuccess
}
public func SecTrustGetTrustResult(_ trust: SecTrust, _ result: UnsafeMutablePointer<SecTrustResultType>) -> OSStatus {
    result.pointee = trust.state.result; return errSecSuccess
}
public func SecTrustGetCertificateCount(_ trust: SecTrust) -> CFIndex {
    let st = trust.state
    return st.chain.isEmpty ? st.certificates.count : st.chain.count
}
public func SecTrustCopyCertificateChain(_ trust: SecTrust) -> CFArray? {
    let st = trust.state
    if st.chain.isEmpty && st.result == .invalid && !st.certificates.isEmpty { _ = _evaluate(trust) }
    let list = st.chain.isEmpty ? st.certificates : st.chain
    return list.isEmpty ? nil : _cfArray(list)
}
@available(iOS, deprecated: 15.0, renamed: "SecTrustCopyCertificateChain")
public func SecTrustGetCertificateAtIndex(_ trust: SecTrust, _ ix: CFIndex) -> SecCertificate? {
    let st = trust.state
    let list = st.chain.isEmpty ? st.certificates : st.chain
    return ix >= 0 && ix < list.count ? list[ix] : nil
}
public func SecTrustCopyKey(_ trust: SecTrust) -> SecKey? { trust.state.certificates.first?.publicKey }
@available(iOS, deprecated: 14.0, renamed: "SecTrustCopyKey")
public func SecTrustCopyPublicKey(_ trust: SecTrust) -> SecKey? { SecTrustCopyKey(trust) }
public func SecTrustCopyExceptions(_ trust: SecTrust) -> CFData? {
    trust.state.certificates.first.map { Data(_sha1($0.der)) as CFData }
}
/// Accepts the current leaf certificate (whatever failed) when the exceptions come from SecTrustCopyExceptions for it.
public func SecTrustSetExceptions(_ trust: SecTrust, _ exceptions: CFData?) -> Bool {
    guard let e = exceptions.map({ Array($0 as Data) }), let leaf = trust.state.certificates.first, e == _sha1(leaf.der) else {
        trust.state.exceptions = nil; return false
    }
    trust.state.exceptions = e
    return true
}
public func SecTrustCopyResult(_ trust: SecTrust) -> CFDictionary? {
    var d: [String: Any] = ["TrustResultValue": Int(trust.state.result.rawValue)]
    if let f = trust.state.failure { d["TrustResultDetails"] = f.1 }
    return d as NSDictionary as CFDictionary
}

// MARK: - identities and PKCS#12

public final class SecIdentity: CustomStringConvertible, Hashable {
    let certificate: SecCertificate
    let key: SecKey
    init(certificate: SecCertificate, key: SecKey) { self.certificate = certificate; self.key = key }
    public var description: String { "<SecIdentityRef: \(certificate.subjectSummary ?? "")>" }
    public static func == (a: SecIdentity, b: SecIdentity) -> Bool { a.certificate == b.certificate && a.key == b.key }
    public func hash(into h: inout Hasher) { h.combine(certificate) }
}
public func SecIdentityGetTypeID() -> CFTypeID { 0x5ec2 }
public func SecIdentityCopyCertificate(_ identityRef: SecIdentity, _ certificateRef: UnsafeMutablePointer<SecCertificate?>) -> OSStatus {
    certificateRef.pointee = identityRef.certificate; return errSecSuccess
}
public func SecIdentityCopyPrivateKey(_ identity: SecIdentity, _ privateKeyRef: UnsafeMutablePointer<SecKey?>) -> OSStatus {
    privateKeyRef.pointee = identity.key; return errSecSuccess
}

/// A client-certificate credential for URLSession: the identity's certificate and `certificates` (intermediates) with
/// its private key, as the PEM that libcurl presents to the server.
extension URLCredential {
    public convenience init(identity: SecIdentity, certificates: [Any]?, persistence: URLCredential.Persistence) {
        func pem(_ label: String, _ der: [UInt8]) -> String {
            "-----BEGIN \(label)-----\n" + Data(der).base64EncodedString(options: .lineLength64Characters) + "\n-----END \(label)-----\n"
        }
        var text = pem("CERTIFICATE", identity.certificate.der)
        for c in certificates ?? [] { if let c = c as? SecCertificate, c != identity.certificate { text += pem("CERTIFICATE", c.der) } }
        var key = [UInt8](repeating: 0, count: 8192), n = key.count
        let k = identity.key
        if k.raw.withUnsafeBufferPointer({ r in key.withUnsafeMutableBufferPointer { isim_pki_key_der(k.type, r.baseAddress!, r.count, $0.baseAddress, &n) } }) == 1 {
            text += pem(k.type == 1 ? "EC PRIVATE KEY" : "RSA PRIVATE KEY", Array(key[0..<n]))
        }
        self.init(_isimIdentity: identity, certificates: certificates, pem: Array(text.utf8), persistence: persistence)
    }
}

public let kSecImportExportPassphrase: CFString = "passphrase" as CFString
public let kSecImportItemLabel: CFString = "label" as CFString
public let kSecImportItemKeyID: CFString = "keyid" as CFString
public let kSecImportItemTrust: CFString = "trust" as CFString
public let kSecImportItemCertChain: CFString = "chain" as CFString
public let kSecImportItemIdentity: CFString = "identity" as CFString

public func SecPKCS12Import(_ pkcs12_data: CFData, _ options: CFDictionary, _ items: UnsafeMutablePointer<CFArray?>) -> OSStatus {
    items.pointee = nil
    guard isim_pki_available() == 1 else { return errSecNotAvailable }
    let data = Array(pkcs12_data as Data)
    let opts = (options as NSDictionary as? [String: Any]) ?? [:]
    let pass = opts["passphrase"] as? String
    var key = [UInt8](repeating: 0, count: 8192), keyLen = key.count, keyType: Int32 = 0
    var certs = [UInt8](repeating: 0, count: 65536), certLens = [Int](repeating: 0, count: 16), n: Int32 = 0
    let ok = data.withUnsafeBufferPointer { d in key.withUnsafeMutableBufferPointer { k in certs.withUnsafeMutableBufferPointer { c in certLens.withUnsafeMutableBufferPointer { l in
        isim_pki_pkcs12(d.baseAddress!, d.count, pass, k.baseAddress!, &keyLen, &keyType, c.baseAddress!, c.count, l.baseAddress!, &n) } } } }
    guard ok == 1 else {
        if n < 0 { return errSecDecode }
        return pass == nil ? errSecPassphraseRequired : errSecAuthFailed
    }
    var list: [SecCertificate] = [], at = 0
    for i in 0..<Int(n) { if let c = SecCertificate(der: Array(certs[at..<(at + certLens[i])])) { list.append(c) }; at += certLens[i] }
    guard let leaf = list.first, let priv = SecKey.load(type: keyType, isPrivate: true, raw: Array(key[0..<keyLen])) else { return errSecDecode }
    let identity = SecIdentity(certificate: leaf, key: priv)
    var trust: SecTrust?
    _ = SecTrustCreateWithCertificates(_cfArray(list), SecPolicyCreateBasicX509(), &trust)
    var item: [String: Any] = ["identity": identity, "chain": _cfArray(list), "keyid": Data(priv.applicationLabel)]
    if let trust { item["trust"] = trust }
    if let label = leaf.subjectSummary { item["label"] = label }
    items.pointee = [item] as NSArray as CFArray
    return errSecSuccess
}

// MARK: - certificates and identities in the keychain

/// keychain attributes and stored bytes for a certificate or identity (kSecValueRef)
func _certificateRefAttributes(_ ref: Any, cls: String) -> (data: [UInt8], attrs: [String: _KCValue])? {
    let cert: SecCertificate, identity: SecIdentity?
    if let c = ref as? SecCertificate, cls == "cert" { cert = c; identity = nil }
    else if let i = ref as? SecIdentity, cls == "idnt" { cert = i.certificate; identity = i }
    else { return nil }
    var a: [String: _KCValue] = [
        "ctyp": .int(1), "cenc": .int(3), "issr": .data(cert.issuerDER), "subj": .data(cert.subjectDER), "slnr": .data(cert.serial),
        "pkhh": .data(cert.publicKeyRaw.map(_sha1) ?? []),
    ]
    if let s = cert.subjectSummary { a["labl"] = .string(s) }
    if let e = (cert.info["emails"] as? [String])?.first { a["alis"] = .string(e) }
    if let identity {
        a["_key"] = .data(identity.key.raw)
        a["_ktyp"] = .int(Int(identity.key.type))
        a["klbl"] = .data(identity.key.applicationLabel)
    }
    return (cert.der, a)
}
func _makeCertificateRef(_ item: _KCItem) -> AnyObject? {
    guard let der = item.data, let cert = SecCertificate(der: der) else { return nil }
    if item.cls == "cert" { return cert }
    guard item.cls == "idnt", case .data(let k) = item.attrs["_key"] ?? .data([]), case .int(let t) = item.attrs["_ktyp"] ?? .int(0),
          let key = SecKey.load(type: Int32(t), isPrivate: true, raw: k) else { return nil }
    return SecIdentity(certificate: cert, key: key)
}

public let kSecAttrCertificateType: CFString = "ctyp" as CFString
public let kSecAttrCertificateEncoding: CFString = "cenc" as CFString
public let kSecAttrSubject: CFString = "subj" as CFString
public let kSecAttrIssuer: CFString = "issr" as CFString
public let kSecAttrSerialNumber: CFString = "slnr" as CFString
public let kSecAttrSubjectKeyID: CFString = "skid" as CFString
public let kSecAttrPublicKeyHash: CFString = "pkhh" as CFString
