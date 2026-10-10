// isim Foundation: the URL loading system for Objective-C. Apple's NSURLSession, NSURLRequest, NSURLComponents,
// NSHTTPCookie... are Objective-C classes that Swift sees as URLSession, URLRequest (a struct), URLComponents...; isim
// writes them in Swift, so here the Swift classes get their Objective-C names (@objc(NS...) on the classes) and
// methods (internal @objc members with Apple's selectors, so Swift's API is unchanged), and the value types get
// Objective-C classes that wrap them and bridge (NSURLRequest / NSMutableURLRequest, NSURLComponents, NSURLQueryItem).
// The SDK headers declare these classes objc_runtime_visible and hide them from Swift (__swift__): Objective-C code
// reaches them through the runtime (Foundation loads this library on first use, SwiftClasses.m), so Objective-C code
// cannot subclass them or add categories to them. An Objective-C session delegate is wrapped in a Swift delegate that
// forwards each callback it implements (_ObjCURLSessionDelegate).
// Not exposed to Objective-C: WebSocket tasks, task metrics, stream tasks, server trusts / client identities in
// credentials (SecTrust and SecIdentity are Swift classes here), HTTPBodyStream.

// MARK: - NSURLQueryItem, NSURLComponents

@objc(NSURLQueryItem)
public final class NSURLQueryItem: NSObject, NSCopying {
    @objc public let name: String
    @objc public let value: String?
    @objc public init(name: String, value: String?) { self.name = name; self.value = value; super.init() }
    @objc(queryItemWithName:value:) public class func queryItem(name: String, value: String?) -> NSURLQueryItem { NSURLQueryItem(name: name, value: value) }
    convenience init(_ q: URLQueryItem) { self.init(name: q.name, value: q.value) }
    var _item: URLQueryItem { URLQueryItem(name: name, value: value) }
    public func copy(with zone: NSZone? = nil) -> Any { self }
    public override func isEqual(_ object: Any?) -> Bool { (object as? NSURLQueryItem).map { $0.name == name && $0.value == value } ?? false }
    public override var hash: Int { name.hashValue }
    public override var description: String { "<NSURLQueryItem \(_item.description)>" }
}
extension URLQueryItem: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSURLQueryItem { NSURLQueryItem(self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSURLQueryItem, result: inout URLQueryItem?) { result = x._item }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSURLQueryItem, result: inout URLQueryItem?) -> Bool { result = x._item; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ x: NSURLQueryItem?) -> URLQueryItem { x?._item ?? URLQueryItem(name: "", value: nil) }
}

@objc(NSURLComponents)
public final class NSURLComponents: NSObject, NSCopying {
    var _c: URLComponents
    @objc public override init() { _c = URLComponents(); super.init() }
    @objc public init?(string: String) { guard let c = URLComponents(string: string) else { return nil }; _c = c; super.init() }
    @objc(initWithURL:resolvingAgainstBaseURL:) public init?(url: URL, resolvingAgainstBaseURL resolve: Bool) {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: resolve) else { return nil }
        _c = c; super.init()
    }
    @objc(componentsWithString:) public class func components(string: String) -> NSURLComponents? { NSURLComponents(string: string) }
    @objc(componentsWithURL:resolvingAgainstBaseURL:) public class func components(url: URL, resolvingAgainstBaseURL resolve: Bool) -> NSURLComponents? {
        NSURLComponents(url: url, resolvingAgainstBaseURL: resolve)
    }
    init(_ c: URLComponents) { _c = c; super.init() }
    @objc(URL) public var url: URL? { _c.url }
    @objc(URLRelativeToURL:) public func url(relativeTo base: URL?) -> URL? { _c.url(relativeTo: base) }
    @objc public var string: String? { _c.string }
    @objc public var scheme: String? { get { _c.scheme } set { _c.scheme = newValue } }
    @objc public var user: String? { get { _c.user } set { _c.user = newValue } }
    @objc public var password: String? { get { _c.password } set { _c.password = newValue } }
    @objc public var host: String? { get { _c.host } set { _c.host = newValue } }
    @objc public var port: NSNumber? { get { _c.port.map { NSNumber(value: $0) } } set { _c.port = newValue.map { Int($0.int64Value) } } }
    @objc public var path: String? { get { _c.path } set { _c.path = newValue ?? "" } }
    @objc public var query: String? { get { _c.query } set { _c.query = newValue } }
    @objc public var fragment: String? { get { _c.fragment } set { _c.fragment = newValue } }
    @objc public var percentEncodedUser: String? { get { _c.percentEncodedUser } set { _c.percentEncodedUser = newValue } }
    @objc public var percentEncodedPassword: String? { get { _c.percentEncodedPassword } set { _c.percentEncodedPassword = newValue } }
    @objc public var percentEncodedHost: String? { get { _c.percentEncodedHost } set { _c.percentEncodedHost = newValue } }
    @objc public var percentEncodedPath: String? { get { _c.percentEncodedPath } set { _c.percentEncodedPath = newValue ?? "" } }
    @objc public var percentEncodedQuery: String? { get { _c.percentEncodedQuery } set { _c.percentEncodedQuery = newValue } }
    @objc public var percentEncodedFragment: String? { get { _c.percentEncodedFragment } set { _c.percentEncodedFragment = newValue } }
    @objc public var queryItems: [NSURLQueryItem]? {
        get { _c.queryItems?.map(NSURLQueryItem.init) }
        set { _c.queryItems = newValue?.map(\._item) }
    }
    @objc public var percentEncodedQueryItems: [NSURLQueryItem]? {
        get { _c.percentEncodedQueryItems?.map(NSURLQueryItem.init) }
        set { _c.percentEncodedQueryItems = newValue?.map(\._item) }
    }
    public func copy(with zone: NSZone? = nil) -> Any { NSURLComponents(_c) }
    public override func isEqual(_ object: Any?) -> Bool { (object as? NSURLComponents)?._c == _c }
    public override var hash: Int { _c.hashValue }
    public override var description: String { "<NSURLComponents \(_c.description)>" }
}
extension URLComponents: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSURLComponents { NSURLComponents(self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSURLComponents, result: inout URLComponents?) { result = x._c }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSURLComponents, result: inout URLComponents?) -> Bool { result = x._c; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ x: NSURLComponents?) -> URLComponents { x?._c ?? URLComponents() }
}

// MARK: - NSURLRequest, NSMutableURLRequest

@objc(NSURLRequest)
open class NSURLRequest: NSObject, NSCopying, NSMutableCopying, @unchecked Sendable {
    var _r: URLRequest
    init(_ r: URLRequest) { _r = r; super.init() }
    @objc(initWithURL:cachePolicy:timeoutInterval:)
    public required init(url: URL, cachePolicy: UInt, timeoutInterval: TimeInterval) {
        _r = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy(rawValue: cachePolicy) ?? .useProtocolCachePolicy, timeoutInterval: timeoutInterval)
        super.init()
    }
    @objc(initWithURL:) public convenience init(url: URL) { self.init(url: url, cachePolicy: 0, timeoutInterval: 60) }
    @objc(requestWithURL:) open class func request(url: URL) -> Self { self.init(url: url, cachePolicy: 0, timeoutInterval: 60) }
    @objc(requestWithURL:cachePolicy:timeoutInterval:) open class func request(url: URL, cachePolicy: UInt, timeoutInterval: TimeInterval) -> Self {
        self.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
    }
    @objc(supportsSecureCoding) open class var supportsSecureCoding: Bool { true }
    @objc(URL) open var url: URL? { _r.url }
    @objc open var cachePolicy: UInt { _r.cachePolicy.rawValue }
    @objc open var timeoutInterval: TimeInterval { _r.timeoutInterval }
    @objc open var mainDocumentURL: URL? { _r.mainDocumentURL }
    @objc open var networkServiceType: UInt { _r.networkServiceType.rawValue }
    @objc open var allowsCellularAccess: Bool { _r.allowsCellularAccess }
    @objc open var allowsExpensiveNetworkAccess: Bool { _r.allowsExpensiveNetworkAccess }
    @objc open var allowsConstrainedNetworkAccess: Bool { _r.allowsConstrainedNetworkAccess }
    @objc open var assumesHTTP3Capable: Bool { _r.assumesHTTP3Capable }
    @objc(HTTPMethod) open var httpMethod: String? { _r.httpMethod }
    @objc(allHTTPHeaderFields) open var allHTTPHeaderFields: [String: String]? { _r.allHTTPHeaderFields }
    @objc(valueForHTTPHeaderField:) open func value(forHTTPHeaderField field: String) -> String? { _r.value(forHTTPHeaderField: field) }
    @objc(HTTPBody) open var httpBody: Data? { _r.httpBody }
    @objc(HTTPShouldHandleCookies) open var httpShouldHandleCookies: Bool { _r.httpShouldHandleCookies }
    @objc(HTTPShouldUsePipelining) open var httpShouldUsePipelining: Bool { _r.httpShouldUsePipelining }
    open func copy(with zone: NSZone? = nil) -> Any { NSURLRequest(_r) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { NSMutableURLRequest(_r) }
    open override func isEqual(_ object: Any?) -> Bool { (object as? NSURLRequest)?._r == _r }
    open override var hash: Int { _r.hashValue }
    open override var description: String { "<\(type(of: self)): \(_r.description)>" }
}

@objc(NSMutableURLRequest)
open class NSMutableURLRequest: NSURLRequest, @unchecked Sendable {
    @objc(URL) open override var url: URL? { get { _r.url } set { _r.url = newValue } }
    @objc open override var cachePolicy: UInt { get { _r.cachePolicy.rawValue } set { _r.cachePolicy = URLRequest.CachePolicy(rawValue: newValue) ?? .useProtocolCachePolicy } }
    @objc open override var timeoutInterval: TimeInterval { get { _r.timeoutInterval } set { _r.timeoutInterval = newValue } }
    @objc open override var mainDocumentURL: URL? { get { _r.mainDocumentURL } set { _r.mainDocumentURL = newValue } }
    @objc open override var networkServiceType: UInt {
        get { _r.networkServiceType.rawValue } set { _r.networkServiceType = URLRequest.NetworkServiceType(rawValue: newValue) ?? .default }
    }
    @objc open override var allowsCellularAccess: Bool { get { _r.allowsCellularAccess } set { _r.allowsCellularAccess = newValue } }
    @objc open override var allowsExpensiveNetworkAccess: Bool { get { _r.allowsExpensiveNetworkAccess } set { _r.allowsExpensiveNetworkAccess = newValue } }
    @objc open override var allowsConstrainedNetworkAccess: Bool { get { _r.allowsConstrainedNetworkAccess } set { _r.allowsConstrainedNetworkAccess = newValue } }
    @objc open override var assumesHTTP3Capable: Bool { get { _r.assumesHTTP3Capable } set { _r.assumesHTTP3Capable = newValue } }
    @objc(HTTPMethod) open override var httpMethod: String? { get { _r.httpMethod } set { _r.httpMethod = newValue } }
    @objc(allHTTPHeaderFields) open override var allHTTPHeaderFields: [String: String]? { get { _r.allHTTPHeaderFields } set { _r.allHTTPHeaderFields = newValue } }
    @objc(setValue:forHTTPHeaderField:) open func setValue(_ value: String?, forHTTPHeaderField field: String) { _r.setValue(value, forHTTPHeaderField: field) }
    @objc(addValue:forHTTPHeaderField:) open func addValue(_ value: String, forHTTPHeaderField field: String) { _r.addValue(value, forHTTPHeaderField: field) }
    @objc(HTTPBody) open override var httpBody: Data? { get { _r.httpBody } set { _r.httpBody = newValue } }
    @objc(HTTPShouldHandleCookies) open override var httpShouldHandleCookies: Bool { get { _r.httpShouldHandleCookies } set { _r.httpShouldHandleCookies = newValue } }
    @objc(HTTPShouldUsePipelining) open override var httpShouldUsePipelining: Bool { get { _r.httpShouldUsePipelining } set { _r.httpShouldUsePipelining = newValue } }
}

extension URLRequest: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSURLRequest { NSURLRequest(self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSURLRequest, result: inout URLRequest?) { result = x._r }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSURLRequest, result: inout URLRequest?) -> Bool { result = x._r; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ x: NSURLRequest?) -> URLRequest { x?._r ?? URLRequest(url: URL(string: "about:blank")!) }
}

// MARK: - responses

extension URLResponse {
    @objc(initWithURL:MIMEType:expectedContentLength:textEncodingName:)
    convenience init(_objcURL url: URL, mimeType: String?, expectedContentLength: Int, textEncodingName: String?) {
        self.init(url: url, mimeType: mimeType, expectedContentLength: expectedContentLength, textEncodingName: textEncodingName)
    }
    @objc(URL) var _objc_url: URL? { url }
    @objc(MIMEType) var _objc_mimeType: String? { mimeType }
    @objc(expectedContentLength) var _objc_expectedContentLength: Int64 { expectedContentLength }
    @objc(textEncodingName) var _objc_textEncodingName: String? { textEncodingName }
    @objc(suggestedFilename) var _objc_suggestedFilename: String? { suggestedFilename }
}
extension HTTPURLResponse {
    @objc(initWithURL:statusCode:HTTPVersion:headerFields:)
    convenience init?(_objcURL url: URL, statusCode: Int, httpVersion: String?, headerFields: [String: String]?) {
        self.init(_url: url, statusCode: statusCode, httpVersion: httpVersion, headers: (headerFields ?? [:]).sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
    }
    @objc(statusCode) var _objc_statusCode: Int { statusCode }
    @objc(allHeaderFields) var _objc_allHeaderFields: [AnyHashable: Any] { allHeaderFields }
    @objc(valueForHTTPHeaderField:) func _objc_value(forHTTPHeaderField field: String) -> String? { value(forHTTPHeaderField: field) }
    @objc(localizedStringForStatusCode:) class func _objc_localizedString(forStatusCode code: Int) -> String { localizedString(forStatusCode: code) }
}

// MARK: - cookies

extension HTTPCookie {
    static func _keys(_ d: [String: Any]) -> [HTTPCookiePropertyKey: Any] {
        var out: [HTTPCookiePropertyKey: Any] = [:]
        for (k, v) in d { out[HTTPCookiePropertyKey(k)] = v }
        return out
    }
    @objc(initWithProperties:) convenience init?(_objcProperties p: [String: Any]) { self.init(properties: HTTPCookie._keys(p)) }
    @objc(cookieWithProperties:) class func _objc_cookie(properties p: [String: Any]) -> HTTPCookie? { HTTPCookie(properties: HTTPCookie._keys(p)) }
    @objc(cookiesWithResponseHeaderFields:forURL:) class func _objc_cookies(withResponseHeaderFields f: [String: String], for url: URL) -> [HTTPCookie] {
        cookies(withResponseHeaderFields: f, for: url)
    }
    @objc(requestHeaderFieldsWithCookies:) class func _objc_requestHeaderFields(with cookies: [HTTPCookie]) -> [String: String] { requestHeaderFields(with: cookies) }
    @objc(properties) var _objc_properties: [String: Any]? {
        guard let p = properties else { return nil }
        var out: [String: Any] = [:]
        for (k, v) in p { out[k.rawValue] = v }
        return out
    }
    @objc(name) var _objc_name: String { name }
    @objc(value) var _objc_value: String { value }
    @objc(domain) var _objc_domain: String { domain }
    @objc(path) var _objc_path: String { path }
    @objc(expiresDate) var _objc_expiresDate: Date? { expiresDate }
    @objc(isSecure) var _objc_isSecure: Bool { isSecure }
    @objc(isHTTPOnly) var _objc_isHTTPOnly: Bool { isHTTPOnly }
    @objc(isSessionOnly) var _objc_isSessionOnly: Bool { isSessionOnly }
    @objc(version) var _objc_version: Int { version }
    @objc(comment) var _objc_comment: String? { comment }
    @objc(commentURL) var _objc_commentURL: URL? { commentURL }
    @objc(portList) var _objc_portList: [NSNumber]? { portList }
    @objc(sameSitePolicy) var _objc_sameSitePolicy: String? { sameSitePolicy?.rawValue }
}
extension HTTPCookieStorage {
    @objc(sharedHTTPCookieStorage) class var _objc_shared: HTTPCookieStorage { shared }
    @objc(sharedCookieStorageForGroupContainerIdentifier:) class func _objc_shared(group: String) -> HTTPCookieStorage { sharedCookieStorage(forGroupContainerIdentifier: group) }
    @objc(cookies) var _objc_cookies: [HTTPCookie]? { cookies }
    @objc(cookiesForURL:) func _objc_cookies(for url: URL) -> [HTTPCookie]? { cookies(for: url) }
    @objc(setCookie:) func _objc_setCookie(_ c: HTTPCookie) { setCookie(c) }
    @objc(deleteCookie:) func _objc_deleteCookie(_ c: HTTPCookie) { deleteCookie(c) }
    @objc(removeCookiesSinceDate:) func _objc_removeCookies(since d: Date) { removeCookies(since: d) }
    @objc(setCookies:forURL:mainDocumentURL:) func _objc_setCookies(_ c: [HTTPCookie], for url: URL?, mainDocumentURL: URL?) { setCookies(c, for: url, mainDocumentURL: mainDocumentURL) }
    @objc(sortedCookiesUsingDescriptors:) func _objc_sortedCookies(using d: [Any]) -> [HTTPCookie] { sortedCookies(using: d) }
    @objc(cookieAcceptPolicy) var _objc_cookieAcceptPolicy: UInt {
        get { cookieAcceptPolicy.rawValue } set { cookieAcceptPolicy = HTTPCookie.AcceptPolicy(rawValue: newValue) ?? .always }
    }
}

// MARK: - cache

extension CachedURLResponse {
    @objc(initWithResponse:data:) convenience init(_objcResponse r: URLResponse, data: Data) { self.init(response: r, data: data) }
    @objc(initWithResponse:data:userInfo:storagePolicy:)
    convenience init(_objcResponse r: URLResponse, data: Data, userInfo: [AnyHashable: Any]?, storagePolicy: UInt) {
        self.init(response: r, data: data, userInfo: userInfo, storagePolicy: StoragePolicy(rawValue: storagePolicy) ?? .allowed)
    }
    @objc(response) var _objc_response: URLResponse { response }
    @objc(data) var _objc_data: Data { data }
    @objc(userInfo) var _objc_userInfo: [AnyHashable: Any]? { userInfo }
    @objc(storagePolicy) var _objc_storagePolicy: UInt { storagePolicy.rawValue }
}
extension URLCache {
    @objc(sharedURLCache) class var _objc_shared: URLCache { get { shared } set { shared = newValue } }
    @objc(initWithMemoryCapacity:diskCapacity:diskPath:) convenience init(_objcMemory m: Int, disk d: Int, diskPath: String?) {
        self.init(memoryCapacity: m, diskCapacity: d, diskPath: diskPath)
    }
    @objc(initWithMemoryCapacity:diskCapacity:directoryURL:) convenience init(_objcMemory m: Int, disk d: Int, directoryURL: URL?) {
        self.init(memoryCapacity: m, diskCapacity: d, directory: directoryURL)
    }
    @objc(cachedResponseForRequest:) func _objc_cachedResponse(for r: URLRequest) -> CachedURLResponse? { cachedResponse(for: r) }
    @objc(storeCachedResponse:forRequest:) func _objc_store(_ c: CachedURLResponse, for r: URLRequest) { storeCachedResponse(c, for: r) }
    @objc(removeCachedResponseForRequest:) func _objc_remove(for r: URLRequest) { removeCachedResponse(for: r) }
    @objc(removeAllCachedResponses) func _objc_removeAll() { removeAllCachedResponses() }
    @objc(removeCachedResponsesSinceDate:) func _objc_remove(since d: Date) { removeCachedResponses(since: d) }
    @objc(memoryCapacity) var _objc_memoryCapacity: Int { get { memoryCapacity } set { memoryCapacity = newValue } }
    @objc(diskCapacity) var _objc_diskCapacity: Int { get { diskCapacity } set { diskCapacity = newValue } }
    @objc(currentMemoryUsage) var _objc_currentMemoryUsage: Int { currentMemoryUsage }
    @objc(currentDiskUsage) var _objc_currentDiskUsage: Int { currentDiskUsage }
}

// MARK: - authentication

extension URLCredential {
    @objc(initWithUser:password:persistence:) convenience init(_objcUser u: String, password: String, persistence: UInt) {
        self.init(user: u, password: password, persistence: Persistence(rawValue: persistence) ?? .none)
    }
    @objc(credentialWithUser:password:persistence:) class func _objc_credential(user: String, password: String, persistence: UInt) -> URLCredential {
        URLCredential(user: user, password: password, persistence: Persistence(rawValue: persistence) ?? .none)
    }
    @objc(user) var _objc_user: String? { user }
    @objc(password) var _objc_password: String? { password }
    @objc(hasPassword) var _objc_hasPassword: Bool { hasPassword }
    @objc(persistence) var _objc_persistence: UInt { persistence.rawValue }
}
extension URLProtectionSpace {
    @objc(initWithHost:port:protocol:realm:authenticationMethod:)
    convenience init(_objcHost h: String, port: Int, protocol p: String?, realm: String?, authenticationMethod m: String?) {
        self.init(host: h, port: port, protocol: p, realm: realm, authenticationMethod: m)
    }
    @objc(host) var _objc_host: String { host }
    @objc(port) var _objc_port: Int { port }
    @objc(protocol) var _objc_protocol: String? { `protocol` }
    @objc(realm) var _objc_realm: String? { realm }
    @objc(authenticationMethod) var _objc_authenticationMethod: String { authenticationMethod }
    @objc(proxyType) var _objc_proxyType: String? { proxyType }
    @objc(receivesCredentialSecurely) var _objc_receivesCredentialSecurely: Bool { receivesCredentialSecurely }
    @objc(distinguishedNames) var _objc_distinguishedNames: [Data]? { distinguishedNames }
}
extension URLAuthenticationChallenge {
    @objc(protectionSpace) var _objc_protectionSpace: URLProtectionSpace { protectionSpace }
    @objc(proposedCredential) var _objc_proposedCredential: URLCredential? { proposedCredential }
    @objc(previousFailureCount) var _objc_previousFailureCount: Int { previousFailureCount }
    @objc(failureResponse) var _objc_failureResponse: URLResponse? { failureResponse }
    @objc(error) var _objc_error: Error? { error }
    @objc(sender) var _objc_sender: AnyObject? { sender }
}
extension URLCredentialStorage {
    @objc(sharedCredentialStorage) class var _objc_shared: URLCredentialStorage { shared }
    @objc(allCredentials) var _objc_allCredentials: [URLProtectionSpace: [String: URLCredential]] { allCredentials }
    @objc(credentialsForProtectionSpace:) func _objc_credentials(for s: URLProtectionSpace) -> [String: URLCredential]? { credentials(for: s) }
    @objc(setCredential:forProtectionSpace:) func _objc_set(_ c: URLCredential, for s: URLProtectionSpace) { set(c, for: s) }
    @objc(removeCredential:forProtectionSpace:) func _objc_remove(_ c: URLCredential, for s: URLProtectionSpace) { remove(c, for: s) }
    @objc(defaultCredentialForProtectionSpace:) func _objc_defaultCredential(for s: URLProtectionSpace) -> URLCredential? { defaultCredential(for: s) }
    @objc(setDefaultCredential:forProtectionSpace:) func _objc_setDefault(_ c: URLCredential, for s: URLProtectionSpace) { setDefaultCredential(c, for: s) }
}

// MARK: - configuration

extension URLSessionConfiguration {
    @objc(defaultSessionConfiguration) class var _objc_default: URLSessionConfiguration { .default }
    @objc(ephemeralSessionConfiguration) class var _objc_ephemeral: URLSessionConfiguration { .ephemeral }
    @objc(backgroundSessionConfigurationWithIdentifier:) class func _objc_background(identifier: String) -> URLSessionConfiguration {
        background(withIdentifier: identifier)
    }
    @objc(copyWithZone:) func _objc_copy(with zone: NSZone?) -> Any { _copy() }
    @objc(identifier) var _objc_identifier: String? { identifier }
    @objc(requestCachePolicy) var _objc_requestCachePolicy: UInt {
        get { requestCachePolicy.rawValue } set { requestCachePolicy = URLRequest.CachePolicy(rawValue: newValue) ?? .useProtocolCachePolicy }
    }
    @objc(timeoutIntervalForRequest) var _objc_timeoutIntervalForRequest: TimeInterval { get { timeoutIntervalForRequest } set { timeoutIntervalForRequest = newValue } }
    @objc(timeoutIntervalForResource) var _objc_timeoutIntervalForResource: TimeInterval { get { timeoutIntervalForResource } set { timeoutIntervalForResource = newValue } }
    @objc(networkServiceType) var _objc_networkServiceType: UInt {
        get { networkServiceType.rawValue } set { networkServiceType = URLRequest.NetworkServiceType(rawValue: newValue) ?? .default }
    }
    @objc(allowsCellularAccess) var _objc_allowsCellularAccess: Bool { get { allowsCellularAccess } set { allowsCellularAccess = newValue } }
    @objc(allowsExpensiveNetworkAccess) var _objc_allowsExpensiveNetworkAccess: Bool { get { allowsExpensiveNetworkAccess } set { allowsExpensiveNetworkAccess = newValue } }
    @objc(allowsConstrainedNetworkAccess) var _objc_allowsConstrainedNetworkAccess: Bool { get { allowsConstrainedNetworkAccess } set { allowsConstrainedNetworkAccess = newValue } }
    @objc(waitsForConnectivity) var _objc_waitsForConnectivity: Bool { get { waitsForConnectivity } set { waitsForConnectivity = newValue } }
    @objc(isDiscretionary) var _objc_isDiscretionary: Bool { isDiscretionary }
    @objc(setDiscretionary:) func _objc_setDiscretionary(_ v: Bool) { isDiscretionary = v }
    @objc(sharedContainerIdentifier) var _objc_sharedContainerIdentifier: String? { get { sharedContainerIdentifier } set { sharedContainerIdentifier = newValue } }
    @objc(sessionSendsLaunchEvents) var _objc_sessionSendsLaunchEvents: Bool { get { sessionSendsLaunchEvents } set { sessionSendsLaunchEvents = newValue } }
    @objc(HTTPShouldUsePipelining) var _objc_httpShouldUsePipelining: Bool { get { httpShouldUsePipelining } set { httpShouldUsePipelining = newValue } }
    @objc(HTTPShouldSetCookies) var _objc_httpShouldSetCookies: Bool { get { httpShouldSetCookies } set { httpShouldSetCookies = newValue } }
    @objc(HTTPCookieAcceptPolicy) var _objc_httpCookieAcceptPolicy: UInt {
        get { httpCookieAcceptPolicy.rawValue } set { httpCookieAcceptPolicy = HTTPCookie.AcceptPolicy(rawValue: newValue) ?? .onlyFromMainDocumentDomain }
    }
    @objc(HTTPAdditionalHeaders) var _objc_httpAdditionalHeaders: [AnyHashable: Any]? { get { httpAdditionalHeaders } set { httpAdditionalHeaders = newValue } }
    @objc(HTTPMaximumConnectionsPerHost) var _objc_httpMaximumConnectionsPerHost: Int { get { httpMaximumConnectionsPerHost } set { httpMaximumConnectionsPerHost = newValue } }
    @objc(HTTPCookieStorage) var _objc_httpCookieStorage: HTTPCookieStorage? { get { httpCookieStorage } set { httpCookieStorage = newValue } }
    @objc(URLCache) var _objc_urlCache: URLCache? { get { urlCache } set { urlCache = newValue } }
    @objc(URLCredentialStorage) var _objc_urlCredentialStorage: URLCredentialStorage? { get { urlCredentialStorage } set { urlCredentialStorage = newValue } }
}

// MARK: - session

extension URLSession {
    @objc(sharedSession) class var _objc_shared: URLSession { shared }
    @objc(sessionWithConfiguration:) class func _objc_session(configuration c: URLSessionConfiguration) -> URLSession { URLSession(configuration: c) }
    @objc(sessionWithConfiguration:delegate:delegateQueue:)
    class func _objc_session(configuration c: URLSessionConfiguration, delegate d: AnyObject?, delegateQueue q: OperationQueue?) -> URLSession {
        URLSession(configuration: c, delegate: _ObjCURLSessionDelegate.wrap(d), delegateQueue: q)
    }
    @objc(configuration) var _objc_configuration: URLSessionConfiguration { configuration }
    @objc(delegateQueue) var _objc_delegateQueue: OperationQueue { delegateQueue }
    @objc(delegate) var _objc_delegate: AnyObject? { let d = delegate; return (d as? _ObjCURLSessionDelegate)?.target ?? d }
    @objc(sessionDescription) var _objc_sessionDescription: String? { get { sessionDescription } set { sessionDescription = newValue } }

    @objc(dataTaskWithRequest:) func _objc_dataTask(request r: URLRequest) -> URLSessionDataTask { dataTask(with: r) }
    @objc(dataTaskWithURL:) func _objc_dataTask(url: URL) -> URLSessionDataTask { dataTask(with: url) }
    @objc(dataTaskWithRequest:completionHandler:)
    func _objc_dataTask(request r: URLRequest, completionHandler h: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        dataTask(with: r, completionHandler: h)
    }
    @objc(dataTaskWithURL:completionHandler:)
    func _objc_dataTask(url: URL, completionHandler h: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        dataTask(with: url, completionHandler: h)
    }
    @objc(uploadTaskWithRequest:fromData:) func _objc_uploadTask(request r: URLRequest, fromData d: Data) -> URLSessionUploadTask { uploadTask(with: r, from: d) }
    @objc(uploadTaskWithRequest:fromFile:) func _objc_uploadTask(request r: URLRequest, fromFile f: URL) -> URLSessionUploadTask { uploadTask(with: r, fromFile: f) }
    @objc(uploadTaskWithRequest:fromData:completionHandler:)
    func _objc_uploadTask(request r: URLRequest, fromData d: Data?, completionHandler h: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        uploadTask(with: r, from: d, completionHandler: h)
    }
    @objc(uploadTaskWithRequest:fromFile:completionHandler:)
    func _objc_uploadTask(request r: URLRequest, fromFile f: URL, completionHandler h: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        uploadTask(with: r, fromFile: f, completionHandler: h)
    }
    @objc(downloadTaskWithRequest:) func _objc_downloadTask(request r: URLRequest) -> URLSessionDownloadTask { downloadTask(with: r) }
    @objc(downloadTaskWithURL:) func _objc_downloadTask(url: URL) -> URLSessionDownloadTask { downloadTask(with: url) }
    @objc(downloadTaskWithResumeData:) func _objc_downloadTask(resumeData d: Data) -> URLSessionDownloadTask { downloadTask(withResumeData: d) }
    @objc(downloadTaskWithRequest:completionHandler:)
    func _objc_downloadTask(request r: URLRequest, completionHandler h: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        downloadTask(with: r, completionHandler: h)
    }
    @objc(downloadTaskWithURL:completionHandler:)
    func _objc_downloadTask(url: URL, completionHandler h: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        downloadTask(with: url, completionHandler: h)
    }
    @objc(downloadTaskWithResumeData:completionHandler:)
    func _objc_downloadTask(resumeData d: Data, completionHandler h: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        downloadTask(withResumeData: d, completionHandler: h)
    }
    @objc(finishTasksAndInvalidate) func _objc_finishTasksAndInvalidate() { finishTasksAndInvalidate() }
    @objc(invalidateAndCancel) func _objc_invalidateAndCancel() { invalidateAndCancel() }
    @objc(resetWithCompletionHandler:) func _objc_reset(completionHandler h: @escaping @Sendable () -> Void) { reset(completionHandler: h) }
    @objc(flushWithCompletionHandler:) func _objc_flush(completionHandler h: @escaping @Sendable () -> Void) { flush(completionHandler: h) }
    @objc(getAllTasksWithCompletionHandler:) func _objc_getAllTasks(completionHandler h: @escaping @Sendable ([URLSessionTask]) -> Void) { getAllTasks(completionHandler: h) }
    @objc(getTasksWithCompletionHandler:)
    func _objc_getTasks(completionHandler h: @escaping @Sendable ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask]) -> Void) {
        getTasksWithCompletionHandler(h)
    }
}

// MARK: - tasks

extension URLSessionTask {
    @objc(taskIdentifier) var _objc_taskIdentifier: Int { taskIdentifier }
    @objc(originalRequest) var _objc_originalRequest: NSURLRequest? { originalRequest.map(NSURLRequest.init) }
    @objc(currentRequest) var _objc_currentRequest: NSURLRequest? { currentRequest.map(NSURLRequest.init) }
    @objc(response) var _objc_response: URLResponse? { response }
    @objc(error) var _objc_error: Error? { error }
    @objc(state) var _objc_state: Int { state.rawValue }
    @objc(countOfBytesReceived) var _objc_countOfBytesReceived: Int64 { countOfBytesReceived }
    @objc(countOfBytesSent) var _objc_countOfBytesSent: Int64 { countOfBytesSent }
    @objc(countOfBytesExpectedToReceive) var _objc_countOfBytesExpectedToReceive: Int64 { countOfBytesExpectedToReceive }
    @objc(countOfBytesExpectedToSend) var _objc_countOfBytesExpectedToSend: Int64 { countOfBytesExpectedToSend }
    @objc(countOfBytesClientExpectsToSend) var _objc_countOfBytesClientExpectsToSend: Int64 { get { countOfBytesClientExpectsToSend } set { countOfBytesClientExpectsToSend = newValue } }
    @objc(countOfBytesClientExpectsToReceive) var _objc_countOfBytesClientExpectsToReceive: Int64 { get { countOfBytesClientExpectsToReceive } set { countOfBytesClientExpectsToReceive = newValue } }
    @objc(taskDescription) var _objc_taskDescription: String? { get { taskDescription } set { taskDescription = newValue } }
    @objc(priority) var _objc_priority: Float { get { priority } set { priority = newValue } }
    @objc(earliestBeginDate) var _objc_earliestBeginDate: Date? { get { earliestBeginDate } set { earliestBeginDate = newValue } }
    @objc(prefersIncrementalDelivery) var _objc_prefersIncrementalDelivery: Bool { get { prefersIncrementalDelivery } set { prefersIncrementalDelivery = newValue } }
    @objc(progress) var _objc_progress: Progress { progress }
    @objc(resume) func _objc_resume() { resume() }
    @objc(suspend) func _objc_suspend() { suspend() }
    @objc(cancel) func _objc_cancel() { cancel() }
}
extension URLSessionDownloadTask {
    @objc(cancelByProducingResumeData:) func _objc_cancel(byProducingResumeData h: @escaping @Sendable (Data?) -> Void) { cancel(byProducingResumeData: h) }
}

// MARK: - Objective-C delegates

/// the Objective-C delegate methods, as optional requirements: messages to a delegate that does not adopt this protocol
/// (it adopts Apple's NSURLSession...Delegate protocols) go through it; Swift checks responds(to:) for each
@objc protocol _NSURLSessionDelegateMethods {
    @objc(URLSession:didBecomeInvalidWithError:) optional func invalid(_ s: URLSession, _ e: Error?)
    @objc(URLSession:didReceiveChallenge:completionHandler:)
    optional func sessionChallenge(_ s: URLSession, _ c: URLAuthenticationChallenge, _ h: @escaping (Int, URLCredential?) -> Void)
    @objc(URLSessionDidFinishEventsForBackgroundURLSession:) optional func finishedEvents(_ s: URLSession)
    @objc(URLSession:didCreateTask:) optional func created(_ s: URLSession, _ t: URLSessionTask)
    @objc(URLSession:taskIsWaitingForConnectivity:) optional func waiting(_ s: URLSession, _ t: URLSessionTask)
    @objc(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)
    optional func redirect(_ s: URLSession, _ t: URLSessionTask, _ r: HTTPURLResponse, _ n: NSURLRequest, _ h: @escaping (NSURLRequest?) -> Void)
    @objc(URLSession:task:didReceiveChallenge:completionHandler:)
    optional func taskChallenge(_ s: URLSession, _ t: URLSessionTask, _ c: URLAuthenticationChallenge, _ h: @escaping (Int, URLCredential?) -> Void)
    @objc(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)
    optional func sent(_ s: URLSession, _ t: URLSessionTask, _ n: Int64, _ total: Int64, _ expected: Int64)
    @objc(URLSession:task:didCompleteWithError:) optional func completed(_ s: URLSession, _ t: URLSessionTask, _ e: Error?)
    @objc(URLSession:dataTask:didReceiveResponse:completionHandler:)
    optional func response(_ s: URLSession, _ t: URLSessionDataTask, _ r: URLResponse, _ h: @escaping (Int) -> Void)
    @objc(URLSession:dataTask:didReceiveData:) optional func data(_ s: URLSession, _ t: URLSessionDataTask, _ d: Data)
    @objc(URLSession:dataTask:willCacheResponse:completionHandler:)
    optional func cache(_ s: URLSession, _ t: URLSessionDataTask, _ c: CachedURLResponse, _ h: @escaping (CachedURLResponse?) -> Void)
    @objc(URLSession:downloadTask:didFinishDownloadingToURL:) optional func downloaded(_ s: URLSession, _ t: URLSessionDownloadTask, _ u: URL)
    @objc(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)
    optional func wrote(_ s: URLSession, _ t: URLSessionDownloadTask, _ n: Int64, _ total: Int64, _ expected: Int64)
    @objc(URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:)
    optional func resumed(_ s: URLSession, _ t: URLSessionDownloadTask, _ offset: Int64, _ expected: Int64)
}

/// an Objective-C session delegate as a Swift one: each callback goes to the delegate when it implements the method,
/// else does what iOS does for a missing optional method
final class _ObjCURLSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    let target: AnyObject
    var d: _NSURLSessionDelegateMethods { unsafeBitCast(target, to: _NSURLSessionDelegateMethods.self) }
    init(_ target: AnyObject) { self.target = target; super.init() }
    static func wrap(_ o: AnyObject?) -> URLSessionDelegate? {
        guard let o else { return nil }
        if let swift = o as? URLSessionDelegate { return swift }
        return _ObjCURLSessionDelegate(o)
    }
    /// a session-level challenge goes on to the task-level method when the delegate implements only that one (iOS)
    var _defersSessionChallenges: Bool { d.sessionChallenge == nil }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) { d.invalid?(session, error) }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) { d.finishedEvents?(session) }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let f = d.sessionChallenge else { completionHandler(.performDefaultHandling, nil); return }
        f(session, challenge) { r, c in completionHandler(URLSession.AuthChallengeDisposition(rawValue: r) ?? .performDefaultHandling, c) }
    }
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) { d.created?(session, task) }
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) { d.waiting?(session, task) }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let f = d.redirect else { completionHandler(request); return }
        f(session, task, response, NSURLRequest(request)) { completionHandler($0?._r) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let f = d.taskChallenge else { completionHandler(.performDefaultHandling, nil); return }
        f(session, task, challenge) { r, c in completionHandler(URLSession.AuthChallengeDisposition(rawValue: r) ?? .performDefaultHandling, c) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        d.sent?(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { d.completed?(session, task, error) }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        guard let f = d.response else { completionHandler(.allow); return }
        f(session, dataTask, response) { completionHandler(URLSession.ResponseDisposition(rawValue: $0) ?? .allow) }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) { d.data?(session, dataTask, data) }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse,
                    completionHandler: @escaping @Sendable (CachedURLResponse?) -> Void) {
        guard let f = d.cache else { completionHandler(proposedResponse); return }
        f(session, dataTask, proposedResponse) { completionHandler($0) }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) { d.downloaded?(session, downloadTask, location) }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        d.wrote?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        d.resumed?(session, downloadTask, fileOffset, expectedTotalBytes)
    }
}
