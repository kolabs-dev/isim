// isim IdentityDocumentServices (iOS 26; adapted): an identity document provider app registers the mobile documents
// (ISO 18013-5 mdocs, e.g. org.iso.18013.5.1.mDL) it can present. The registrations are kept per app in the device data
// ($ISIM_DATA/Library/isim/IdentityDocuments/<bundle ID>.json; `isim identity-documents list` prints them). The app
// needs the com.apple.developer.identity-document-services.document-provider.mobile-document-types entitlement, listing
// the document types: without it the store's status is notAuthorized and registering throws notAuthorized; a type it
// does not list is invalidRequest. A registration past its invalidationDate is no longer listed.
// The presentment request and response types are Apple's value types; IdentityDocumentWebPresentmentRawRequestValidator
// decodes an ISO 18013-5 DeviceRequest (CBOR; also inside an ISO 18013-7 Annex C {"deviceRequest": …} map): its
// documents, namespaces and elements with their intent to retain, and the reader authentication's certificate chain
// (x5chain; its signature is not verified: that needs the session transcript of the presentment, proposed).
// Same API as Apple's; there is no Objective-C interface (Apple's is Swift only).
import Foundation
import Security

// MARK: - registrations

@available(iOS 26.0, *)
public protocol IdentityDocumentRegistration: Sendable {
    var documentIdentifier: String { get }
}

@available(iOS 26.0, *)
public struct MobileDocumentRegistration: IdentityDocumentRegistration, Hashable, Sendable {
    public var mobileDocumentType: String
    public var supportedIssuerKeyIdentifiers: [Data]
    public var supportedAuthorityKeyIdentifiers: [Data]
    public var documentIdentifier: String
    public var invalidationDate: Date?
    public init(mobileDocumentType: String, supportedAuthorityKeyIdentifiers: [Data], documentIdentifier: String, invalidationDate: Date?) {
        self.init(mobileDocumentType: mobileDocumentType, supportedIssuerKeyIdentifiers: [], supportedAuthorityKeyIdentifiers: supportedAuthorityKeyIdentifiers,
                  documentIdentifier: documentIdentifier, invalidationDate: invalidationDate)
    }
    public init(mobileDocumentType: String, supportedIssuerKeyIdentifiers: [Data], supportedAuthorityKeyIdentifiers: [Data],
                documentIdentifier: String, invalidationDate: Date?) {
        self.mobileDocumentType = mobileDocumentType
        self.supportedIssuerKeyIdentifiers = supportedIssuerKeyIdentifiers
        self.supportedAuthorityKeyIdentifiers = supportedAuthorityKeyIdentifiers
        self.documentIdentifier = documentIdentifier
        self.invalidationDate = invalidationDate
    }
}

@available(iOS 26.0, *)
public final class IdentityDocumentProviderRegistrationStore: @unchecked Sendable {
    public enum Status: Hashable, Sendable { case notDetermined, notAuthorized, authorized, notSupported }
    public enum RegistrationError: Error, Hashable, Sendable { case notSupported, notAuthorized, invalidRequest, unknown }

    public init() {}

    static var entitledTypes: [String]? {
        let path = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        return NSDictionary(contentsOfFile: path)?["com.apple.developer.identity-document-services.document-provider.mobile-document-types"] as? [String]
    }
    static var file: String {
        let env = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
        let dir = env.isEmpty ? NSHomeDirectory() + "/.local/share/isim" : env
        return dir + "/Library/isim/IdentityDocuments/\(Bundle.main.bundleIdentifier ?? "app").json"
    }
    static let lock = NSLock()
    static func load() -> [[String: Any]] {
        guard let d = FileManager.default.contents(atPath: file), let list = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] else { return [] }
        return list
    }
    static func save(_ list: [[String: Any]]) throws {
        try FileManager.default.createDirectory(atPath: (file as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let d = try JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted, .sortedKeys])
        guard FileManager.default.createFile(atPath: file, contents: d) else { throw RegistrationError.unknown }
    }
    static func decode(_ e: [String: Any]) -> MobileDocumentRegistration? {
        guard let type = e["mobileDocumentType"] as? String, let id = e["documentIdentifier"] as? String else { return nil }
        func keys(_ k: String) -> [Data] { (e[k] as? [String] ?? []).compactMap { Data(base64Encoded: $0) } }
        return MobileDocumentRegistration(mobileDocumentType: type, supportedIssuerKeyIdentifiers: keys("supportedIssuerKeyIdentifiers"),
                                          supportedAuthorityKeyIdentifiers: keys("supportedAuthorityKeyIdentifiers"), documentIdentifier: id,
                                          invalidationDate: (e["invalidationDate"] as? Double).map { Date(timeIntervalSince1970: $0) })
    }

    /// authorized when the app has the document provider entitlement
    public var status: Status { (Self.entitledTypes?.isEmpty == false) ? .authorized : .notAuthorized }

    /// the app's registrations that are still valid
    public var registrations: [any IdentityDocumentRegistration] {
        Self.lock.lock(); defer { Self.lock.unlock() }
        let now = Date()
        return Self.load().compactMap(Self.decode).filter { ($0.invalidationDate ?? .distantFuture) > now }
    }

    /// adds or replaces (same documentIdentifier) a registration
    public func addRegistration(_ registration: some IdentityDocumentRegistration) async throws {
        guard let types = Self.entitledTypes, !types.isEmpty else { throw RegistrationError.notAuthorized }
        guard let r = registration as? MobileDocumentRegistration, !r.documentIdentifier.isEmpty, types.contains(r.mobileDocumentType) else {
            throw RegistrationError.invalidRequest
        }
        Self.lock.lock(); defer { Self.lock.unlock() }
        var list = Self.load().filter { $0["documentIdentifier"] as? String != r.documentIdentifier }
        var e: [String: Any] = ["mobileDocumentType": r.mobileDocumentType, "documentIdentifier": r.documentIdentifier,
                                "supportedIssuerKeyIdentifiers": r.supportedIssuerKeyIdentifiers.map { $0.base64EncodedString() },
                                "supportedAuthorityKeyIdentifiers": r.supportedAuthorityKeyIdentifiers.map { $0.base64EncodedString() }]
        if let d = r.invalidationDate { e["invalidationDate"] = d.timeIntervalSince1970 }
        list.append(e)
        try Self.save(list)
    }

    public func removeRegistration(forDocumentIdentifier documentIdentifier: String) async throws {
        guard status == .authorized else { throw RegistrationError.notAuthorized }
        Self.lock.lock(); defer { Self.lock.unlock() }
        let list = Self.load()
        let kept = list.filter { $0["documentIdentifier"] as? String != documentIdentifier }
        guard kept.count < list.count else { throw RegistrationError.invalidRequest }
        try Self.save(kept)
    }
}

// MARK: - presentment requests and responses

@available(iOS 26.0, *)
public protocol IdentityDocumentWebPresentmentRequest: Sendable {}
@available(iOS 26.0, *)
public protocol IdentityDocumentWebPresentmentResponse: Sendable {}

@available(iOS 26.0, *)
public struct ISO18013MobileDocumentRequest: IdentityDocumentWebPresentmentRequest, Sendable {
    public struct ElementInfo: Hashable, Sendable {
        public var isRetaining: Bool
        public init(isRetaining: Bool) { self.isRetaining = isRetaining }
    }
    public struct DocumentRequest: Hashable, Sendable {
        public var documentType: String
        public var namespaces: [String: [String: ElementInfo]]
        public var issuerKeyIdentifiers: [Data]
        public init(documentType: String, namespaces: [String: [String: ElementInfo]]) {
            self.init(documentType: documentType, namespaces: namespaces, issuerKeyIdentifiers: [])
        }
        public init(documentType: String, namespaces: [String: [String: ElementInfo]], issuerKeyIdentifiers: [Data]) {
            self.documentType = documentType; self.namespaces = namespaces; self.issuerKeyIdentifiers = issuerKeyIdentifiers
        }
    }
    public struct DocumentRequestSet: Hashable, Sendable {
        public var requests: [DocumentRequest]
        public init(requests: [DocumentRequest]) { self.requests = requests }
    }
    public struct PresentmentRequest: Hashable, Sendable {
        public var documentRequestSets: [DocumentRequestSet]
        public var isMandatory: Bool
        public init(documentRequestSets: [DocumentRequestSet], isMandatory: Bool) { self.documentRequestSets = documentRequestSets; self.isMandatory = isMandatory }
    }
    public struct RequestAuthentication: @unchecked Sendable {
        public var authenticationCertificateChain: [SecCertificate]
        public init(authenticationCertificateChain: [SecCertificate]) { self.authenticationCertificateChain = authenticationCertificateChain }
    }
    public var presentmentRequests: [PresentmentRequest]
    public var requestAuthentications: [RequestAuthentication]
    public init(presentmentRequests: [PresentmentRequest], requestAuthentications: [RequestAuthentication]) {
        self.presentmentRequests = presentmentRequests; self.requestAuthentications = requestAuthentications
    }
}

@available(iOS 26.0, *)
public struct ISO18013MobileDocumentResponse: IdentityDocumentWebPresentmentResponse, Hashable, Sendable {
    public let responseData: Data
    public init(responseData: Data) { self.responseData = responseData }
}

@available(iOS 26.0, *)
public struct IdentityDocumentWebPresentmentRawRequest: Hashable, Sendable {
    public enum RequestType: Hashable, Sendable { case iso18013MobileDocument }
    public var requestType: RequestType
    public var requestData: Data
    public init(requestType: RequestType, requestData: Data) { self.requestType = requestType; self.requestData = requestData }
}

@available(iOS 26.0, *)
public struct IdentityDocumentPresentmentError: Error, CustomDebugStringConvertible, Hashable, Sendable {
    public enum Code: Hashable, Sendable {
        case unknown, cancelled, invalidRequest, notEntitled, requestInProgress
        public static func ~= (code: Code, error: any Error) -> Bool { (error as? IdentityDocumentPresentmentError)?.code == code }
    }
    public let code: Code
    public let debugDescription: String
    public init(code: Code, debugDescription: String = "") { self.code = code; self.debugDescription = debugDescription }
    public static let unknown = Code.unknown
    public static let cancelled = Code.cancelled
    public static let invalidRequest = Code.invalidRequest
    public static let notEntitled = Code.notEntitled
    public static let requestInProgress = Code.requestInProgress
}

@available(iOS 26.0, *)
public struct IdentityDocumentWebPresentmentRawRequestValidator: Sendable {
    public init() {}
    /// decodes the DeviceRequest of an ISO 18013-7 web request from `origin` (https)
    public func validateISO18013MobileDocumentRequest(_ requestData: Data, origin: URL) throws -> ISO18013MobileDocumentRequest {
        func invalid(_ why: String) -> IdentityDocumentPresentmentError { IdentityDocumentPresentmentError(code: .invalidRequest, debugDescription: why) }
        guard origin.scheme?.lowercased() == "https", origin.host != nil else { throw invalid("the origin is not an https URL") }
        guard var top = _CBOR.decode([UInt8](requestData)) else { throw invalid("the request is not CBOR") }
        if case .map(let m) = top, let inner = m[.text("deviceRequest")], case .bytes(let b) = inner {   // ISO 18013-7 Annex C
            guard let d = _CBOR.decode(b) else { throw invalid("the deviceRequest is not CBOR") }
            top = d
        }
        guard case .map(let req) = top, case .array(let docs)? = req[.text("docRequests")], !docs.isEmpty else {
            throw invalid("the request is not a DeviceRequest with docRequests")
        }
        if let v = req[.text("version")], v != .text("1.0") && v != .text("1.1") { throw invalid("unsupported DeviceRequest version") }
        var presentments: [ISO18013MobileDocumentRequest.PresentmentRequest] = [], auths: [ISO18013MobileDocumentRequest.RequestAuthentication] = []
        for doc in docs {
            guard case .map(let d) = doc, case .tagged(24, .bytes(let itemsBytes))? = d[.text("itemsRequest")],
                  case .map(let items)? = _CBOR.decode(itemsBytes), case .text(let docType)? = items[.text("docType")],
                  case .map(let nss)? = items[.text("nameSpaces")] else { throw invalid("a docRequest has no valid itemsRequest") }
            var namespaces: [String: [String: ISO18013MobileDocumentRequest.ElementInfo]] = [:]
            for (k, v) in nss {
                guard case .text(let ns) = k, case .map(let elements) = v else { throw invalid("a namespace is not a map") }
                var out: [String: ISO18013MobileDocumentRequest.ElementInfo] = [:]
                for (ek, ev) in elements {
                    guard case .text(let name) = ek, case .bool(let retain) = ev else { throw invalid("an element is not name: intentToRetain") }
                    out[name] = .init(isRetaining: retain)
                }
                namespaces[ns] = out
            }
            presentments.append(.init(documentRequestSets: [.init(requests: [.init(documentType: docType, namespaces: namespaces)])], isMandatory: true))
            // readerAuth: COSE_Sign1 [protected, unprotected {33: x5chain}, payload, signature]
            if case .array(let sign1)? = d[.text("readerAuth")], sign1.count == 4 {
                var chain: [SecCertificate] = []
                var headers: [_CBOR] = []
                if case .map(let u) = sign1[1] { headers.append(.map(u)) }
                if case .bytes(let p) = sign1[0], let ph = _CBOR.decode(p) { headers.append(ph) }
                for case .map(let h) in headers {
                    switch h[.int(33)] {
                    case .bytes(let one)?: if let c = SecCertificateCreateWithData(nil, Data(one) as CFData) { chain.append(c) }
                    case .array(let many)?: for case .bytes(let b) in many { if let c = SecCertificateCreateWithData(nil, Data(b) as CFData) { chain.append(c) } }
                    default: break
                    }
                }
                guard !chain.isEmpty else { throw invalid("the reader authentication has no certificate chain") }
                auths.append(.init(authenticationCertificateChain: chain))
            }
        }
        return ISO18013MobileDocumentRequest(presentmentRequests: presentments, requestAuthentications: auths)
    }
}

// MARK: - CBOR (RFC 8949), what DeviceRequest uses

indirect enum _CBOR: Hashable {
    case int(Int), bytes([UInt8]), text(String), array([_CBOR]), map([_CBOR: _CBOR]), tagged(UInt64, _CBOR), bool(Bool), null, undefined, double(Double)

    static func decode(_ b: [UInt8]) -> _CBOR? {
        var i = 0
        guard let v = item(b, &i), i == b.count else { return nil }
        return v
    }
    private static func head(_ b: [UInt8], _ i: inout Int) -> (UInt8, UInt64)? {
        guard i < b.count else { return nil }
        let ib = b[i]; i += 1
        let major = ib >> 5, info = ib & 0x1F
        var n: UInt64
        switch info {
        case 0..<24: n = UInt64(info)
        case 24...27:
            let len = 1 << Int(info - 24)
            guard i + len <= b.count else { return nil }
            n = 0
            for _ in 0..<len { n = n << 8 | UInt64(b[i]); i += 1 }
        default: return nil                                            // indefinite lengths: not in mdoc requests
        }
        return (major, n)
    }
    private static func item(_ b: [UInt8], _ i: inout Int, depth: Int = 0) -> _CBOR? {
        guard depth < 32, let (major, n) = head(b, &i) else { return nil }
        switch major {
        case 0: return n <= UInt64(Int.max) ? .int(Int(n)) : nil
        case 1: return n < UInt64(Int.max) ? .int(-1 - Int(n)) : nil
        case 2, 3:
            guard n <= UInt64(b.count - i) else { return nil }
            let s = Array(b[i..<(i + Int(n))]); i += Int(n)
            if major == 2 { return .bytes(s) }
            guard let t = String(bytes: s, encoding: .utf8) else { return nil }
            return .text(t)
        case 4:
            guard n <= UInt64(b.count) else { return nil }
            var a: [_CBOR] = []
            for _ in 0..<n { guard let v = item(b, &i, depth: depth + 1) else { return nil }; a.append(v) }
            return .array(a)
        case 5:
            guard n <= UInt64(b.count) else { return nil }
            var m: [_CBOR: _CBOR] = [:]
            for _ in 0..<n {
                guard let k = item(b, &i, depth: depth + 1), let v = item(b, &i, depth: depth + 1) else { return nil }
                m[k] = v
            }
            return .map(m)
        case 6:
            guard let v = item(b, &i, depth: depth + 1) else { return nil }
            return .tagged(n, v)
        default:
            switch n {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22: return .null
            case 23: return .undefined
            default: return .double(Double(bitPattern: n))
            }
        }
    }
}
