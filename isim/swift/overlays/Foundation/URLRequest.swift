// isim Foundation: URLRequest, URLResponse / HTTPURLResponse and URLError (self-authored, Swift API).

// MARK: - URLError
public let NSURLErrorDomain = "NSURLErrorDomain"
public let NSURLErrorFailingURLErrorKey = "NSErrorFailingURLKey"
public let NSURLErrorFailingURLStringErrorKey = "NSErrorFailingURLStringKey"
public let NSURLErrorUnknown = -1
public let NSURLErrorCancelled = -999
public let NSURLErrorBadURL = -1000
public let NSURLErrorTimedOut = -1001
public let NSURLErrorUnsupportedURL = -1002
public let NSURLErrorCannotFindHost = -1003
public let NSURLErrorCannotConnectToHost = -1004
public let NSURLErrorNetworkConnectionLost = -1005
public let NSURLErrorDNSLookupFailed = -1006
public let NSURLErrorHTTPTooManyRedirects = -1007
public let NSURLErrorResourceUnavailable = -1008
public let NSURLErrorNotConnectedToInternet = -1009
public let NSURLErrorBadServerResponse = -1011
public let NSURLErrorUserCancelledAuthentication = -1012
public let NSURLErrorZeroByteResource = -1014
public let NSURLErrorCannotDecodeContentData = -1016
public let NSURLErrorCannotParseResponse = -1017
public let NSURLErrorFileDoesNotExist = -1100
public let NSURLErrorFileIsDirectory = -1101
public let NSURLErrorSecureConnectionFailed = -1200
public let NSURLErrorServerCertificateUntrusted = -1202
public let NSURLErrorServerCertificateHasBadDate = -1201
public let NSURLErrorServerCertificateHasUnknownRoot = -1203
public let NSURLErrorServerCertificateNotYetValid = -1204
public let NSURLErrorClientCertificateRejected = -1205
public let NSURLErrorClientCertificateRequired = -1206
public let NSURLErrorCannotWriteToFile = -3003

public struct URLError: Error, CustomNSError, LocalizedError, Hashable, @unchecked Sendable {
    public struct Code: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let unknown = Code(rawValue: -1)
        public static let cancelled = Code(rawValue: -999)
        public static let badURL = Code(rawValue: -1000)
        public static let timedOut = Code(rawValue: -1001)
        public static let unsupportedURL = Code(rawValue: -1002)
        public static let cannotFindHost = Code(rawValue: -1003)
        public static let cannotConnectToHost = Code(rawValue: -1004)
        public static let networkConnectionLost = Code(rawValue: -1005)
        public static let dnsLookupFailed = Code(rawValue: -1006)
        public static let httpTooManyRedirects = Code(rawValue: -1007)
        public static let resourceUnavailable = Code(rawValue: -1008)
        public static let notConnectedToInternet = Code(rawValue: -1009)
        public static let redirectToNonExistentLocation = Code(rawValue: -1010)
        public static let badServerResponse = Code(rawValue: -1011)
        public static let userCancelledAuthentication = Code(rawValue: -1012)
        public static let userAuthenticationRequired = Code(rawValue: -1013)
        public static let zeroByteResource = Code(rawValue: -1014)
        public static let cannotDecodeRawData = Code(rawValue: -1015)
        public static let cannotDecodeContentData = Code(rawValue: -1016)
        public static let cannotParseResponse = Code(rawValue: -1017)
        public static let internationalRoamingOff = Code(rawValue: -1018)
        public static let callIsActive = Code(rawValue: -1019)
        public static let dataNotAllowed = Code(rawValue: -1020)
        public static let requestBodyStreamExhausted = Code(rawValue: -1021)
        public static let appTransportSecurityRequiresSecureConnection = Code(rawValue: -1022)
        public static let fileDoesNotExist = Code(rawValue: -1100)
        public static let fileIsDirectory = Code(rawValue: -1101)
        public static let noPermissionsToReadFile = Code(rawValue: -1102)
        public static let dataLengthExceedsMaximum = Code(rawValue: -1103)
        public static let secureConnectionFailed = Code(rawValue: -1200)
        public static let serverCertificateHasBadDate = Code(rawValue: -1201)
        public static let serverCertificateUntrusted = Code(rawValue: -1202)
        public static let serverCertificateHasUnknownRoot = Code(rawValue: -1203)
        public static let serverCertificateNotYetValid = Code(rawValue: -1204)
        public static let clientCertificateRejected = Code(rawValue: -1205)
        public static let clientCertificateRequired = Code(rawValue: -1206)
        public static let cannotLoadFromNetwork = Code(rawValue: -2000)
        public static let cannotCreateFile = Code(rawValue: -3000)
        public static let cannotOpenFile = Code(rawValue: -3001)
        public static let cannotCloseFile = Code(rawValue: -3002)
        public static let cannotWriteToFile = Code(rawValue: -3003)
        public static let cannotRemoveFile = Code(rawValue: -3004)
        public static let cannotMoveFile = Code(rawValue: -3005)
        public static let downloadDecodingFailedMidStream = Code(rawValue: -3006)
        public static let downloadDecodingFailedToComplete = Code(rawValue: -3007)
        public static let backgroundSessionRequiresSharedContainer = Code(rawValue: -995)
        public static let backgroundSessionInUseByAnotherProcess = Code(rawValue: -996)
        public static let backgroundSessionWasDisconnected = Code(rawValue: -997)
    }
    public let code: Code
    public let errorUserInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) {
        self.code = code
        var info = userInfo
        if info[NSLocalizedDescriptionKey] == nil { info[NSLocalizedDescriptionKey] = URLError._message(code) }
        errorUserInfo = info
    }
    public static var errorDomain: String { NSURLErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var userInfo: [String: Any] { errorUserInfo }
    public var failingURL: URL? { errorUserInfo[NSURLErrorFailingURLErrorKey] as? URL }
    public var failureURLString: String? { errorUserInfo[NSURLErrorFailingURLStringErrorKey] as? String }
    public var errorDescription: String? { errorUserInfo[NSLocalizedDescriptionKey] as? String }
    public var downloadTaskResumeData: Data? { nil }
    /// what the Swift runtime's bridged NSError reports as userInfo (description, failing URL)
    public var _userInfo: AnyObject? { errorUserInfo as NSDictionary }
    public static func == (a: URLError, b: URLError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }

    static func _message(_ c: Code) -> String {
        switch c {
        case .cancelled: return "cancelled"
        case .badURL: return "bad URL"
        case .timedOut: return "The request timed out."
        case .unsupportedURL: return "unsupported URL"
        case .cannotFindHost: return "A server with the specified hostname could not be found."
        case .cannotConnectToHost: return "Could not connect to the server."
        case .networkConnectionLost: return "The network connection was lost."
        case .httpTooManyRedirects: return "too many HTTP redirects"
        case .resourceUnavailable: return "The requested resource is unavailable."
        case .notConnectedToInternet: return "The Internet connection appears to be offline."
        case .badServerResponse: return "The server returned a bad response."
        case .zeroByteResource: return "zero byte resource"
        case .cannotDecodeContentData: return "cannot decode content data"
        case .fileDoesNotExist: return "The requested URL was not found on this server."
        case .secureConnectionFailed: return "An SSL error has occurred and a secure connection to the server cannot be made."
        case .serverCertificateUntrusted: return "The certificate for this server is invalid."
        case .clientCertificateRequired: return "The server requires a client certificate."
        case .cannotWriteToFile: return "cannot write to file"
        default: return "The operation couldn’t be completed. (NSURLErrorDomain error \(c.rawValue).)"
        }
    }
    static func _make(_ raw: Int, url: URL?, detail: String? = nil) -> URLError {
        var info: [String: Any] = [:]
        if let url { info[NSURLErrorFailingURLErrorKey] = url; info[NSURLErrorFailingURLStringErrorKey] = url.absoluteString }
        if let detail, !detail.isEmpty { info["NSDebugDescription"] = detail }
        return URLError(Code(rawValue: raw), userInfo: info)
    }
}
extension URLError {
    public static var unknown: Code { .unknown }
    public static var cancelled: Code { .cancelled }
    public static var badURL: Code { .badURL }
    public static var timedOut: Code { .timedOut }
    public static var unsupportedURL: Code { .unsupportedURL }
    public static var cannotFindHost: Code { .cannotFindHost }
    public static var cannotConnectToHost: Code { .cannotConnectToHost }
    public static var networkConnectionLost: Code { .networkConnectionLost }
    public static var dnsLookupFailed: Code { .dnsLookupFailed }
    public static var httpTooManyRedirects: Code { .httpTooManyRedirects }
    public static var resourceUnavailable: Code { .resourceUnavailable }
    public static var notConnectedToInternet: Code { .notConnectedToInternet }
    public static var badServerResponse: Code { .badServerResponse }
    public static var userAuthenticationRequired: Code { .userAuthenticationRequired }
    public static var zeroByteResource: Code { .zeroByteResource }
    public static var cannotDecodeContentData: Code { .cannotDecodeContentData }
    public static var cannotParseResponse: Code { .cannotParseResponse }
    public static var dataNotAllowed: Code { .dataNotAllowed }
    public static var fileDoesNotExist: Code { .fileDoesNotExist }
    public static var secureConnectionFailed: Code { .secureConnectionFailed }
    public static var serverCertificateUntrusted: Code { .serverCertificateUntrusted }
    public static var cannotWriteToFile: Code { .cannotWriteToFile }
}
/// `catch URLError.timedOut { }` / `case URLError.cancelled:` patterns
public func ~= (code: URLError.Code, error: Error) -> Bool { (error as? URLError)?.code == code }

// MARK: - URLRequest
public struct URLRequest: Hashable, @unchecked Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public enum CachePolicy: UInt, Sendable {
        case useProtocolCachePolicy = 0
        case reloadIgnoringLocalCacheData = 1
        case returnCacheDataElseLoad = 2
        case returnCacheDataDontLoad = 3
        case reloadIgnoringLocalAndRemoteCacheData = 4
        case reloadRevalidatingCacheData = 5
        public static var reloadIgnoringCacheData: CachePolicy { .reloadIgnoringLocalCacheData }
    }
    public enum NetworkServiceType: UInt, Sendable {
        case `default` = 0, voip = 1, video = 2, background = 3, voice = 4, responsiveData = 6, avStreaming = 8, responsiveAV = 9, callSignaling = 11
    }
    public enum Attribution: UInt, Sendable { case developer = 0, user = 1 }

    public var url: URL?
    public var cachePolicy: CachePolicy
    public var timeoutInterval: TimeInterval
    public var mainDocumentURL: URL?
    public var httpBody: Data?
    public var httpShouldHandleCookies = true
    public var httpShouldUsePipelining = false
    public var allowsCellularAccess = true
    public var allowsExpensiveNetworkAccess = true
    public var allowsConstrainedNetworkAccess = true
    public var assumesHTTP3Capable = false
    public var requiresDNSSECValidation = false
    public var allowsPersistentDNS = false
    public var networkServiceType: NetworkServiceType = .default
    public var attribution: Attribution = .developer
    var _method: String?
    var _headers: [(String, String)] = []

    public init(url: URL, cachePolicy: CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 60.0) {
        self.url = url; self.cachePolicy = cachePolicy; self.timeoutInterval = timeoutInterval
    }

    /// "GET" unless set; setting nil restores "GET"
    public var httpMethod: String? {
        get { _method ?? "GET" }
        set { _method = newValue.map { $0.isEmpty ? "GET" : $0 } }
    }
    public var allHTTPHeaderFields: [String: String]? {
        get { _headers.isEmpty ? nil : Dictionary(_headers, uniquingKeysWith: { _, b in b }) }
        set { _headers = (newValue ?? [:]).sorted { $0.key < $1.key }.map { ($0.key, $0.value) } }
    }
    /// header names are case-insensitive
    public func value(forHTTPHeaderField field: String) -> String? {
        _headers.first { $0.0.caseInsensitiveCompare(field) == .orderedSame }?.1
    }
    public mutating func setValue(_ value: String?, forHTTPHeaderField field: String) {
        let i = _headers.firstIndex { $0.0.caseInsensitiveCompare(field) == .orderedSame }
        switch (value, i) {
        case let (v?, i?): _headers[i].1 = v
        case let (v?, nil): _headers.append((field, v))
        case let (nil, i?): _headers.remove(at: i)
        default: break
        }
    }
    /// appends to an existing value with a comma, as HTTP allows
    public mutating func addValue(_ value: String, forHTTPHeaderField field: String) {
        if let old = self.value(forHTTPHeaderField: field) { setValue(old + "," + value, forHTTPHeaderField: field) }
        else { setValue(value, forHTTPHeaderField: field) }
    }

    public var description: String { url?.absoluteString ?? "url: nil" }
    public var debugDescription: String { description }
    public static func == (a: URLRequest, b: URLRequest) -> Bool {
        a.url == b.url && a.httpMethod == b.httpMethod && a.httpBody == b.httpBody && a.allHTTPHeaderFields == b.allHTTPHeaderFields &&
            a.cachePolicy == b.cachePolicy && a.timeoutInterval == b.timeoutInterval
    }
    public func hash(into h: inout Hasher) { h.combine(url); h.combine(httpMethod) }
}

// MARK: - URLResponse / HTTPURLResponse
public let NSURLResponseUnknownLength: Int64 = -1

@objc(NSURLResponse) open class URLResponse: NSObject, @unchecked Sendable {
    public let url: URL?
    public let mimeType: String?
    public let expectedContentLength: Int64
    public let textEncodingName: String?
    public init(url: URL, mimeType: String?, expectedContentLength length: Int, textEncodingName name: String?) {
        self.url = url; self.mimeType = mimeType; expectedContentLength = Int64(length); textEncodingName = name
        super.init()
    }
    /// Content-Disposition's filename, else the URL's last path component, else "Unknown" (+ an extension for the MIME type)
    open var suggestedFilename: String? {
        if let h = self as? HTTPURLResponse, let cd = h.value(forHTTPHeaderField: "Content-Disposition"),
           let r = _urlFind(cd, "filename=") {
            var name = String(cd[r...].prefix { $0 != ";" }).trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 { name = String(name.dropFirst().dropLast()) }
            if !name.isEmpty { return name }
        }
        let last = url?.lastPathComponent ?? ""
        if !last.isEmpty && last != "/" { return last }
        switch mimeType {
        case "text/html": return "Unknown.html"
        case "application/json": return "Unknown.json"
        case "text/plain": return "Unknown.txt"
        default: return "Unknown"
        }
    }
    open override var description: String { "<\(type(of: self)): \(url?.absoluteString ?? "")>" }
}

@objc(NSHTTPURLResponse) open class HTTPURLResponse: URLResponse, @unchecked Sendable {
    public let statusCode: Int
    let _headers: [(String, String)]
    let _httpVersion: String?
    public convenience init?(url: URL, statusCode: Int, httpVersion: String?, headerFields: [String: String]?) {
        self.init(_url: url, statusCode: statusCode, httpVersion: httpVersion, headers: (headerFields ?? [:]).sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
    }
    /// headers in received order, duplicates kept (Set-Cookie)
    init(_url url: URL, statusCode: Int, httpVersion: String?, headers: [(String, String)]) {
        self.statusCode = statusCode
        _headers = headers
        _httpVersion = httpVersion
        let ct = _headers.first { $0.0.lowercased() == "content-type" }?.1
        let len = _headers.first { $0.0.lowercased() == "content-length" }.flatMap { Int($0.1.trimmingCharacters(in: .whitespaces)) } ?? -1
        super.init(url: url, mimeType: HTTPURLResponse._mime(ct), expectedContentLength: len, textEncodingName: HTTPURLResponse._charset(ct))
    }
    /// header fields as received (duplicates joined with ", "); keys keep the server's spelling
    public var allHeaderFields: [AnyHashable: Any] {
        var d: [AnyHashable: Any] = [:]
        for (k, v) in _merged { d[k] = v }
        return d
    }
    var _merged: [(String, String)] {
        var out: [(String, String)] = []
        for (k, v) in _headers {
            if let i = out.firstIndex(where: { $0.0.caseInsensitiveCompare(k) == .orderedSame }) { out[i].1 += ", " + v } else { out.append((k, v)) }
        }
        return out
    }
    /// case-insensitive
    public func value(forHTTPHeaderField field: String) -> String? {
        _merged.first { $0.0.caseInsensitiveCompare(field) == .orderedSame }?.1
    }
    static func _mime(_ ct: String?) -> String? {
        guard let ct, let t = ct.split(separator: ";").first else { return nil }
        let m = t.trimmingCharacters(in: .whitespaces).lowercased()
        return m.isEmpty ? nil : m
    }
    static func _charset(_ ct: String?) -> String? {
        guard let ct else { return nil }
        for p in ct.split(separator: ";").dropFirst() {
            let kv = p.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2, kv[0].lowercased() == "charset" { return kv[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")).lowercased() }
        }
        return nil
    }
    public static func localizedString(forStatusCode code: Int) -> String {
        switch code {
        case 100: return "continue"
        case 101: return "switching protocols"
        case 200: return "no error"
        case 201: return "created"
        case 202: return "accepted"
        case 203: return "non-authoritative information"
        case 204: return "no content"
        case 205: return "reset content"
        case 206: return "partial content"
        case 300: return "multiple choices"
        case 301: return "moved permanently"
        case 302: return "found"
        case 303: return "see other"
        case 304: return "not modified"
        case 305: return "needs proxy"
        case 307: return "temporarily redirected"
        case 308: return "permanent redirect"
        case 400: return "bad request"
        case 401: return "unauthorized"
        case 402: return "payment required"
        case 403: return "forbidden"
        case 404: return "not found"
        case 405: return "method not allowed"
        case 406: return "unacceptable"
        case 407: return "proxy authentication required"
        case 408: return "request timed out"
        case 409: return "conflict"
        case 410: return "no longer exists"
        case 411: return "length required"
        case 412: return "precondition failed"
        case 413: return "request too large"
        case 414: return "requested URL too long"
        case 415: return "unsupported media type"
        case 416: return "requested range not satisfiable"
        case 417: return "expectation failed"
        case 422: return "unprocessable entity"
        case 429: return "too many requests"
        case 500: return "internal server error"
        case 501: return "unimplemented"
        case 502: return "bad gateway"
        case 503: return "service unavailable"
        case 504: return "gateway timed out"
        case 505: return "unsupported version"
        default:
            switch code {
            case 100..<200: return "informational"
            case 200..<300: return "success"
            case 300..<400: return "redirected"
            case 400..<500: return "client error"
            case 500..<600: return "server error"
            default: return "server error"
            }
        }
    }
}

/// index just after the first occurrence of `needle` in `s` (internal: isim's String has no range(of:))
func _urlFind(_ s: String, _ needle: String) -> String.Index? {
    let n = Array(needle.utf8)
    guard !n.isEmpty else { return s.startIndex }
    let u = s.utf8
    var i = u.startIndex
    while i != u.endIndex {
        var j = i, k = 0
        while j != u.endIndex, k < n.count, u[j] == n[k] { j = u.index(after: j); k += 1 }
        if k == n.count { return j }
        i = u.index(after: i)
    }
    return nil
}
func _urlContains(_ s: String, _ needle: String) -> Bool { _urlFind(s, needle) != nil }
