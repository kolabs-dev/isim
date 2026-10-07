// isim Foundation: URL loading authentication — URLCredential, URLProtectionSpace, URLAuthenticationChallenge,
// URLCredentialStorage, SecTrust (the server-trust object of a challenge) — and URLSessionTaskMetrics.
//
// URLSession answers HTTP 401/407 Basic and Digest (MD5, qop=auth) challenges through the delegate (or the
// credential storage's default credential), and offers a server-trust challenge before each HTTPS request when a
// delegate is set. Adapted: the TLS handshake happens in the host's libcurl after that challenge, so
// `serverTrust` describes the host only (no certificate chain); `.useCredential` with URLCredential(trust:)
// accepts the server's certificate without checking it. Client certificates are not supported.
import Foundation

/// Security's trust object (the one SecTrust type: defined here because URLProtectionSpace hands it out, extended by
/// the Security module with certificates, policies and evaluation). An HTTPS challenge's trust names the host only;
/// certificates are not exposed for it.
public final class SecTrust: @unchecked Sendable, CustomStringConvertible {
    public let _host: String
    init(host: String) { _host = host }
    public var description: String { "<SecTrust \(_host)>" }
    /// Security's state for trusts made with SecTrustCreateWithCertificates (certificates, policies, anchors, result)
    public var _isimState: AnyObject?
    public init(_isimHost host: String, state: AnyObject?) { _host = host; _isimState = state }
}

public let NSURLAuthenticationMethodDefault = "NSURLAuthenticationMethodDefault"
public let NSURLAuthenticationMethodHTTPBasic = "NSURLAuthenticationMethodHTTPBasic"
public let NSURLAuthenticationMethodHTTPDigest = "NSURLAuthenticationMethodHTTPDigest"
public let NSURLAuthenticationMethodHTMLForm = "NSURLAuthenticationMethodHTMLForm"
public let NSURLAuthenticationMethodNTLM = "NSURLAuthenticationMethodNTLM"
public let NSURLAuthenticationMethodNegotiate = "NSURLAuthenticationMethodNegotiate"
public let NSURLAuthenticationMethodClientCertificate = "NSURLAuthenticationMethodClientCertificate"
public let NSURLAuthenticationMethodServerTrust = "NSURLAuthenticationMethodServerTrust"
public let NSURLProtectionSpaceHTTP = "http"
public let NSURLProtectionSpaceHTTPS = "https"
public let NSURLProtectionSpaceFTP = "ftp"
public let NSURLProtectionSpaceHTTPProxy = "http"
public let NSURLProtectionSpaceHTTPSProxy = "https"

open class URLCredential: NSObject, @unchecked Sendable {
    public enum Persistence: UInt, Sendable { case none = 0, forSession, permanent, synchronizable }
    open private(set) var user: String?
    open private(set) var password: String?
    open var hasPassword: Bool { password != nil }
    open private(set) var persistence: Persistence = .none
    let _trust: SecTrust?
    public init(user: String, password: String, persistence: Persistence) {
        self.user = user; self.password = password; self.persistence = persistence; _trust = nil
        super.init()
    }
    public init(trust: SecTrust) { _trust = trust; super.init(); persistence = .forSession }
    open var identity: AnyObject? { nil }
    open var certificates: [Any] { [] }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? URLCredential else { return false }
        return o.user == user && o.password == password && o._trust === _trust
    }
    open override var hash: Int { (user ?? "").hashValue }
}

open class URLProtectionSpace: NSObject, @unchecked Sendable {
    open private(set) var host: String
    open private(set) var port: Int
    open private(set) var `protocol`: String?
    open private(set) var realm: String?
    open private(set) var authenticationMethod: String
    open private(set) var isProxy = false
    open var proxyType: String? { isProxy ? `protocol` : nil }
    open var receivesCredentialSecurely: Bool { `protocol` == NSURLProtectionSpaceHTTPS || authenticationMethod == NSURLAuthenticationMethodHTTPDigest }
    open var serverTrust: SecTrust? { authenticationMethod == NSURLAuthenticationMethodServerTrust ? SecTrust(host: host) : nil }
    open var distinguishedNames: [Data]? { nil }
    public init(host: String, port: Int, protocol: String?, realm: String?, authenticationMethod: String?) {
        self.host = host; self.port = port; self.protocol = `protocol`; self.realm = realm
        self.authenticationMethod = authenticationMethod ?? NSURLAuthenticationMethodDefault
        super.init()
    }
    public init(proxyHost host: String, port: Int, type: String?, realm: String?, authenticationMethod: String?) {
        self.host = host; self.port = port; self.protocol = type; self.realm = realm
        self.authenticationMethod = authenticationMethod ?? NSURLAuthenticationMethodDefault
        isProxy = true
        super.init()
    }
    var _key: String { "\(`protocol` ?? "")://\(host.lowercased()):\(port)/\(realm ?? "")#\(authenticationMethod)" }
    open override func isEqual(_ object: Any?) -> Bool { (object as? URLProtectionSpace)?._key == _key }
    open override var hash: Int { _key.hashValue }
    open override var description: String { "<URLProtectionSpace \(_key)>" }
}

open class URLAuthenticationChallenge: NSObject, @unchecked Sendable {
    open private(set) var protectionSpace: URLProtectionSpace
    open private(set) var proposedCredential: URLCredential?
    open private(set) var previousFailureCount: Int
    open private(set) var failureResponse: URLResponse?
    open private(set) var error: Error?
    open var sender: AnyObject? { nil }
    public init(protectionSpace space: URLProtectionSpace, proposedCredential credential: URLCredential?, previousFailureCount: Int,
                failureResponse response: URLResponse?, error: Error?, sender: AnyObject?) {
        protectionSpace = space; proposedCredential = credential; self.previousFailureCount = previousFailureCount
        failureResponse = response; self.error = error
        super.init()
    }
}

extension URLSession {
    public enum AuthChallengeDisposition: Int, Sendable { case useCredential = 0, performDefaultHandling, cancelAuthenticationChallenge, rejectProtectionSpace }
}

/// Credentials by protection space. `.permanent` credentials of the shared storage are kept for this run only
/// (isim has no keychain-backed credential store).
open class URLCredentialStorage: NSObject, @unchecked Sendable {
    nonisolated(unsafe) static let _shared = URLCredentialStorage()
    open class var shared: URLCredentialStorage { _shared }
    let lock = NSLock()
    var store: [String: (space: URLProtectionSpace, creds: [String: URLCredential], def: String?)] = [:]
    public override init() { super.init() }
    open var allCredentials: [URLProtectionSpace: [String: URLCredential]] {
        lock.lock(); defer { lock.unlock() }
        var out: [URLProtectionSpace: [String: URLCredential]] = [:]
        for v in store.values { out[v.space] = v.creds }
        return out
    }
    open func credentials(for space: URLProtectionSpace) -> [String: URLCredential]? {
        lock.lock(); defer { lock.unlock() }; return store[space._key]?.creds
    }
    open func set(_ credential: URLCredential, for space: URLProtectionSpace) {
        guard credential.persistence != .none, let u = credential.user else { return }
        lock.lock()
        var e = store[space._key] ?? (space, [:], nil)
        e.creds[u] = credential
        store[space._key] = e
        lock.unlock()
        NotificationCenter.default.post(name: .NSURLCredentialStorageChanged, object: self)
    }
    open func remove(_ credential: URLCredential, for space: URLProtectionSpace) { remove(credential, for: space, options: nil) }
    open func remove(_ credential: URLCredential, for space: URLProtectionSpace, options: [String: Any]?) {
        lock.lock()
        if var e = store[space._key], let u = credential.user { e.creds[u] = nil; if e.def == u { e.def = nil }; store[space._key] = e }
        lock.unlock()
        NotificationCenter.default.post(name: .NSURLCredentialStorageChanged, object: self)
    }
    open func defaultCredential(for space: URLProtectionSpace) -> URLCredential? {
        lock.lock(); defer { lock.unlock() }
        guard let e = store[space._key] else { return nil }
        if let d = e.def { return e.creds[d] }
        return e.creds.count == 1 ? e.creds.values.first : nil
    }
    open func setDefaultCredential(_ credential: URLCredential, for space: URLProtectionSpace) {
        set(credential, for: space)
        lock.lock()
        if let u = credential.user, var e = store[space._key] { e.def = u; store[space._key] = e }
        lock.unlock()
    }
    open func getCredentials(for space: URLProtectionSpace, task: URLSessionTask, completionHandler: @escaping @Sendable ([String: URLCredential]?) -> Void) {
        completionHandler(credentials(for: space))
    }
    open func getDefaultCredential(for space: URLProtectionSpace, task: URLSessionTask, completionHandler: @escaping @Sendable (URLCredential?) -> Void) {
        completionHandler(defaultCredential(for: space))
    }
}
extension Notification.Name {
    public static let NSURLCredentialStorageChanged = Notification.Name("NSURLCredentialStorageChangedNotification")
}

// MARK: - metrics

open class URLSessionTaskTransactionMetrics: NSObject, @unchecked Sendable {
    public enum ResourceFetchType: Int, Sendable { case unknown = 0, networkLoad, serverPush, localCache }
    public enum DomainResolutionProtocol: Int, Sendable { case unknown = 0, udp, tcp, tls, https }
    open internal(set) var request: URLRequest
    open internal(set) var response: URLResponse?
    open internal(set) var fetchStartDate: Date?
    open internal(set) var domainLookupStartDate: Date?
    open internal(set) var domainLookupEndDate: Date?
    open internal(set) var connectStartDate: Date?
    open internal(set) var secureConnectionStartDate: Date?
    open internal(set) var secureConnectionEndDate: Date?
    open internal(set) var connectEndDate: Date?
    open internal(set) var requestStartDate: Date?
    open internal(set) var requestEndDate: Date?
    open internal(set) var responseStartDate: Date?
    open internal(set) var responseEndDate: Date?
    open internal(set) var networkProtocolName: String?
    open internal(set) var isProxyConnection = false
    open internal(set) var isReusedConnection = false
    open internal(set) var resourceFetchType: ResourceFetchType = .unknown
    open internal(set) var countOfRequestHeaderBytesSent: Int64 = 0
    open internal(set) var countOfRequestBodyBytesSent: Int64 = 0
    open internal(set) var countOfRequestBodyBytesBeforeEncoding: Int64 = 0
    open internal(set) var countOfResponseHeaderBytesReceived: Int64 = 0
    open internal(set) var countOfResponseBodyBytesReceived: Int64 = 0
    open internal(set) var countOfResponseBodyBytesAfterDecoding: Int64 = 0
    open internal(set) var localAddress: String?
    open internal(set) var localPort: Int?
    open internal(set) var remoteAddress: String?
    open internal(set) var remotePort: Int?
    open internal(set) var negotiatedTLSProtocolVersion: UInt16?
    open internal(set) var isCellular = false
    open internal(set) var isExpensive = false
    open internal(set) var isConstrained = false
    open internal(set) var isMultipath = false
    open internal(set) var domainResolutionProtocol: DomainResolutionProtocol = .unknown
    init(request: URLRequest) { self.request = request }
}

open class URLSessionTaskMetrics: NSObject, @unchecked Sendable {
    open internal(set) var transactionMetrics: [URLSessionTaskTransactionMetrics] = []
    open internal(set) var taskInterval = DateInterval()
    open internal(set) var redirectCount = 0
}

// MARK: - MD5 (HTTP Digest authentication)

enum _URLMD5 {
    static func hex(_ s: String) -> String { digest(Array(s.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func digest(_ message: [UInt8]) -> [UInt8] {
        let s: [UInt32] = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
                           4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21]
        let k: [UInt32] = (0..<64).map { UInt32(truncatingIfNeeded: Int64(abs(sin(Double($0 + 1))) * 4294967296.0)) }
        var a0: UInt32 = 0x67452301, b0: UInt32 = 0xefcdab89, c0: UInt32 = 0x98badcfe, d0: UInt32 = 0x10325476
        var m = message
        let bitLen = UInt64(message.count) * 8
        m.append(0x80)
        while m.count % 64 != 56 { m.append(0) }
        for i in 0..<8 { m.append(UInt8(truncatingIfNeeded: bitLen >> (8 * UInt64(i)))) }
        for chunk in stride(from: 0, to: m.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 16)
            for i in 0..<16 { w[i] = UInt32(m[chunk + 4 * i]) | UInt32(m[chunk + 4 * i + 1]) << 8 | UInt32(m[chunk + 4 * i + 2]) << 16 | UInt32(m[chunk + 4 * i + 3]) << 24 }
            var a = a0, b = b0, c = c0, d = d0
            for i in 0..<64 {
                var f: UInt32, g: Int
                switch i {
                case 0..<16: f = (b & c) | (~b & d); g = i
                case 16..<32: f = (d & b) | (~d & c); g = (5 * i + 1) % 16
                case 32..<48: f = b ^ c ^ d; g = (3 * i + 5) % 16
                default: f = c ^ (b | ~d); g = (7 * i) % 16
                }
                f = f &+ a &+ k[i] &+ w[g]
                a = d; d = c; c = b
                b = b &+ ((f << s[i]) | (f >> (32 - s[i])))
            }
            a0 = a0 &+ a; b0 = b0 &+ b; c0 = c0 &+ c; d0 = d0 &+ d
        }
        var out: [UInt8] = []
        for v in [a0, b0, c0, d0] { for i in 0..<4 { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(i)))) } }
        return out
    }
}

/// a parsed WWW-Authenticate / Proxy-Authenticate challenge
struct _URLAuthChallengeHeader {
    let scheme: String
    var params: [String: String] = [:]
    static func parse(_ header: String) -> _URLAuthChallengeHeader? {
        let t = header.trimmingCharacters(in: .whitespaces)
        guard let sp = t.firstIndex(of: " ") else { return t.isEmpty ? nil : _URLAuthChallengeHeader(scheme: t.lowercased()) }
        var c = _URLAuthChallengeHeader(scheme: String(t[..<sp]).lowercased())
        var rest = Substring(t[t.index(after: sp)...])
        while !rest.isEmpty {
            rest = rest.drop { $0 == " " || $0 == "," }
            guard let eq = rest.firstIndex(of: "=") else { break }
            let key = rest[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            rest = rest[rest.index(after: eq)...]
            var value = ""
            if rest.first == "\"" {
                rest = rest.dropFirst()
                if let q = rest.firstIndex(of: "\"") { value = String(rest[..<q]); rest = rest[rest.index(after: q)...] } else { value = String(rest); rest = "" }
            } else {
                let end = rest.firstIndex(of: ",") ?? rest.endIndex
                value = rest[..<end].trimmingCharacters(in: .whitespaces); rest = rest[end...]
            }
            c.params[key] = value
        }
        return c
    }
    var method: String? {
        switch scheme { case "basic": return NSURLAuthenticationMethodHTTPBasic; case "digest": return NSURLAuthenticationMethodHTTPDigest; default: return nil }
    }
    /// the Authorization header value for a credential
    func authorization(_ cred: URLCredential, method httpMethod: String, url: URL, nc: Int) -> String? {
        guard let user = cred.user, let pass = cred.password else { return nil }
        if scheme == "basic" { return "Basic " + Data("\(user):\(pass)".utf8).base64EncodedString() }
        guard scheme == "digest", let realm = params["realm"], let nonce = params["nonce"] else { return nil }
        var uri = url.path.isEmpty ? "/" : url.path
        if let q = url.query { uri += "?" + q }
        let ha1 = _URLMD5.hex("\(user):\(realm):\(pass)"), ha2 = _URLMD5.hex("\(httpMethod):\(uri)")
        let qop = params["qop"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.first { $0 == "auth" }
        var h = "Digest username=\"\(user)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\""
        if let qop {
            let ncs = String(format: "%08x", nc), cnonce = String(UInt64.random(in: 1...UInt64.max), radix: 16)
            let resp = _URLMD5.hex("\(ha1):\(nonce):\(ncs):\(cnonce):\(qop):\(ha2)")
            h += ", qop=\(qop), nc=\(ncs), cnonce=\"\(cnonce)\", response=\"\(resp)\""
        } else {
            h += ", response=\"\(_URLMD5.hex("\(ha1):\(nonce):\(ha2)"))\""
        }
        if let o = params["opaque"] { h += ", opaque=\"\(o)\"" }
        h += ", algorithm=MD5"
        return h
    }
}
