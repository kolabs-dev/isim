// isim Foundation: HTTPCookie, HTTPCookieStorage (persisted per app) and URLCache (in memory) (self-authored).

public struct HTTPCookiePropertyKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let name = HTTPCookiePropertyKey("Name")
    public static let value = HTTPCookiePropertyKey("Value")
    public static let originURL = HTTPCookiePropertyKey("OriginURL")
    public static let version = HTTPCookiePropertyKey("Version")
    public static let domain = HTTPCookiePropertyKey("Domain")
    public static let path = HTTPCookiePropertyKey("Path")
    public static let secure = HTTPCookiePropertyKey("Secure")
    public static let expires = HTTPCookiePropertyKey("Expires")
    public static let comment = HTTPCookiePropertyKey("Comment")
    public static let commentURL = HTTPCookiePropertyKey("CommentURL")
    public static let discard = HTTPCookiePropertyKey("Discard")
    public static let maximumAge = HTTPCookiePropertyKey("Max-Age")
    public static let port = HTTPCookiePropertyKey("Port")
    public static let sameSitePolicy = HTTPCookiePropertyKey("SameSite")
    static let httpOnly = HTTPCookiePropertyKey("HttpOnly")
}
public struct HTTPCookieStringPolicy: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let sameSiteLax = HTTPCookieStringPolicy(rawValue: "lax")
    public static let sameSiteStrict = HTTPCookieStringPolicy(rawValue: "strict")
}

@objc(NSHTTPCookie) open class HTTPCookie: NSObject, @unchecked Sendable {
    public let name: String
    public let value: String
    public let domain: String
    public let path: String
    public let expiresDate: Date?
    public let isSecure: Bool
    public let isHTTPOnly: Bool
    public let version: Int
    public let comment: String?
    public let commentURL: URL?
    public let portList: [NSNumber]?
    public let sameSitePolicy: HTTPCookieStringPolicy?
    public var isSessionOnly: Bool { expiresDate == nil }

    /// Name, Value, Path and Domain (or OriginURL) are required, as on iOS.
    public init?(properties p: [HTTPCookiePropertyKey: Any]) {
        func str(_ k: HTTPCookiePropertyKey) -> String? {
            if let s = p[k] as? String { return s }
            if let u = p[k] as? URL { return u.absoluteString }
            return p[k].map { "\($0)" }
        }
        func flag(_ k: HTTPCookiePropertyKey) -> Bool {
            if let b = p[k] as? Bool { return b }
            if let s = p[k] as? String { return s.lowercased() == "true" || s.uppercased() == "TRUE" || s == "1" }
            return false
        }
        guard let name = str(.name), let value = str(.value), !name.isEmpty else { return nil }
        var domain = str(.domain)
        if domain == nil, let o = p[.originURL] { domain = ((o as? URL) ?? URL(string: "\(o)"))?.host }
        guard let domain, !domain.isEmpty else { return nil }
        self.name = name; self.value = value; self.domain = domain.lowercased()
        path = str(.path) ?? "/"
        var exp: Date? = nil
        if let d = p[.expires] as? Date { exp = d } else if let s = p[.expires] as? String { exp = HTTPCookie._parseDate(s) }
        if let ma = str(.maximumAge), let secs = Double(ma) { exp = Date(timeIntervalSinceNow: secs) }
        if flag(.discard) { exp = nil }
        expiresDate = exp
        if let b = p[.secure] as? Bool { isSecure = b } else { isSecure = p[.secure] != nil && !["false", "0"].contains(str(.secure)?.lowercased() ?? "") }
        isHTTPOnly = flag(.httpOnly)
        version = Int(str(.version) ?? "0") ?? 0
        comment = str(.comment)
        commentURL = str(.commentURL).flatMap { URL(string: $0) }
        portList = str(.port).map { $0.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map { NSNumber(value: $0) } }
        sameSitePolicy = str(.sameSitePolicy).map { HTTPCookieStringPolicy(rawValue: $0.lowercased()) }
        super.init()
    }
    open var properties: [HTTPCookiePropertyKey: Any]? {
        var p: [HTTPCookiePropertyKey: Any] = [.name: name, .value: value, .domain: domain, .path: path, .version: String(version)]
        if let expiresDate { p[.expires] = expiresDate }
        if isSecure { p[.secure] = "TRUE" }
        if isHTTPOnly { p[.httpOnly] = "TRUE" }
        if let comment { p[.comment] = comment }
        if let sameSitePolicy { p[.sameSitePolicy] = sameSitePolicy.rawValue }
        return p
    }

    /// Parses Set-Cookie headers. Several cookies in one field (joined by ", ") are split; the comma in Expires dates is not a separator.
    open class func cookies(withResponseHeaderFields headerFields: [String: String], for url: URL) -> [HTTPCookie] {
        var out: [HTTPCookie] = []
        for (k, v) in headerFields where k.caseInsensitiveCompare("Set-Cookie") == .orderedSame {
            for one in _splitSetCookie(v) { if let c = _parse(one, url: url) { out.append(c) } }
        }
        return out
    }
    /// ["Cookie": "a=1; b=2"]
    open class func requestHeaderFields(with cookies: [HTTPCookie]) -> [String: String] {
        cookies.isEmpty ? [:] : ["Cookie": cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")]
    }

    static func _splitSetCookie(_ v: String) -> [String] {
        var parts: [String] = [], cur = ""
        let pieces = v.components(separatedBy: ",")
        for (i, p) in pieces.enumerated() {
            if i == 0 { cur = p; continue }
            // "Expires=Wed, 21 Oct 2026 ..." : the piece before ends with a weekday
            let lastAttr = cur.split(separator: ";").last.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
            if lastAttr.hasPrefix("expires="), lastAttr.count <= 8 + 9 {
                cur += "," + p
            } else { parts.append(cur); cur = p }
        }
        parts.append(cur)
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    static func _parse(_ header: String, url: URL) -> HTTPCookie? {
        let attrs = header.components(separatedBy: ";")
        guard let first = attrs.first, let eq = first.firstIndex(of: "=") else { return nil }
        var p: [HTTPCookiePropertyKey: Any] = [
            .name: first[..<eq].trimmingCharacters(in: .whitespaces),
            .value: first[first.index(after: eq)...].trimmingCharacters(in: .whitespaces),
        ]
        let host = (url.host ?? "").lowercased()
        var domain = host
        var path: String? = nil
        for a in attrs.dropFirst() {
            let kv = a.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let key = kv.first?.lowercased(), !key.isEmpty else { continue }
            let val = kv.count > 1 ? kv[1] : ""
            switch key {
            case "domain":
                var d = val.lowercased()
                if d.hasPrefix(".") { d.removeFirst() }
                guard !d.isEmpty else { continue }
                // a server may only set cookies for its own domain or a parent of it
                guard host == d || host.hasSuffix("." + d) else { return nil }
                domain = "." + d
            case "path": if val.hasPrefix("/") { path = val }
            case "expires": if let d = _parseDate(val) { p[.expires] = d }
            case "max-age": p[.maximumAge] = val
            case "secure": p[.secure] = true
            case "httponly": p[.httpOnly] = true
            case "samesite": p[.sameSitePolicy] = val
            case "comment": p[.comment] = val
            case "version": p[.version] = val
            default: break
            }
        }
        if path == nil {      // default-path (RFC 6265 5.1.4)
            let up = url.path
            if let i = up.lastIndex(of: "/"), i != up.startIndex { path = String(up[..<i]) } else { path = "/" }
        }
        p[.domain] = domain
        p[.path] = path
        return HTTPCookie(properties: p)
    }
    /// RFC 1123 / RFC 850 / asctime dates
    static func _parseDate(_ s: String) -> Date? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        var day: Int?, month: Int?, year: Int?, hms: [Int]?
        for tok in s.split(whereSeparator: { " ,-".contains($0) }) {
            let t = String(tok)
            if t.contains(":") { let p = t.split(separator: ":").compactMap { Int($0) }; if p.count == 3 { hms = p } }
            else if let n = Int(t) { if n > 31 || (day != nil && month != nil) { year = n < 70 ? 2000 + n : n < 100 ? 1900 + n : n } else { day = n } }
            else if month == nil, let m = months.firstIndex(of: String(t.lowercased().prefix(3))) { month = m + 1 }
        }
        guard let day, let month, let year, let hms else { return nil }
        // days since 1970-01-01 (proleptic Gregorian)
        let y = month <= 2 ? year - 1 : year, m = month <= 2 ? month + 9 : month - 3
        let era = (y >= 0 ? y : y - 399) / 400, yoe = y - era * 400
        let doy = (153 * m + 2) / 5 + day - 1, doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146097 + doe - 719468
        return Date(timeIntervalSince1970: Double(days * 86400 + hms[0] * 3600 + hms[1] * 60 + hms[2]))
    }

    func _matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if isSecure && url.scheme?.lowercased() != "https" && host != "localhost" && host != "127.0.0.1" { return false }
        if domain.hasPrefix(".") {
            let d = String(domain.dropFirst())
            guard host == d || host.hasSuffix(domain) else { return false }
        } else if host != domain { return false }
        let p = url.path.isEmpty ? "/" : url.path
        if p == path { return true }
        return p.hasPrefix(path) && (path.hasSuffix("/") || p.dropFirst(path.count).hasPrefix("/"))
    }
    var _expired: Bool { expiresDate.map { $0 < Date() } ?? false }
    open override var description: String { "<HTTPCookie \(name)=\(value); domain=\(domain); path=\(path)\(isSecure ? "; secure" : "")>" }
    open override func isEqual(_ o: Any?) -> Bool {
        guard let c = o as? HTTPCookie else { return false }
        return c.name == name && c.domain == domain && c.path == path && c.value == value
    }
    open override var hash: Int { name.hashValue ^ domain.hashValue ^ path.hashValue }
}

extension HTTPCookie {
    public enum AcceptPolicy: UInt, Sendable { case always = 0, never = 1, onlyFromMainDocumentDomain = 2 }
}

extension Notification.Name {
    public static let NSHTTPCookieManagerCookiesChanged = Notification.Name("NSHTTPCookieManagerCookiesChangedNotification")
    public static let NSHTTPCookieManagerAcceptPolicyChanged = Notification.Name("NSHTTPCookieManagerAcceptPolicyChangedNotification")
}

/// Cookie jar. `shared` persists cookies with an expiry date in the app container (Library/Cookies/Cookies.json,
/// isim's own format); ephemeral sessions use a private in-memory storage.
@objc(NSHTTPCookieStorage) open class HTTPCookieStorage: NSObject, @unchecked Sendable {
    let _lock = NSLock()
    var _cookies: [HTTPCookie] = []
    let _file: String?
    var _loaded = false
    public var cookieAcceptPolicy: HTTPCookie.AcceptPolicy = .always

    static let _shared = HTTPCookieStorage(file: NSHomeDirectory() + "/Library/Cookies/Cookies.json")
    open class var shared: HTTPCookieStorage { _shared }
    open class func sharedCookieStorage(forGroupContainerIdentifier identifier: String) -> HTTPCookieStorage { _shared }
    init(file: String?) { _file = file; super.init() }
    override init() { _file = nil; super.init() }

    open var cookies: [HTTPCookie]? { _lock.lock(); defer { _lock.unlock() }; _load(); _purge(); return _cookies }
    open func cookies(for url: URL) -> [HTTPCookie]? {
        _lock.lock(); defer { _lock.unlock() }
        _load(); _purge()
        // longer paths first (RFC 6265 5.4)
        return _cookies.filter { $0._matches(url) }.sorted { $0.path.count > $1.path.count }
    }
    open func setCookie(_ cookie: HTTPCookie) {
        guard cookieAcceptPolicy != .never else { return }
        _lock.lock()
        _load()
        _cookies.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
        if !cookie._expired { _cookies.append(cookie) }
        _save()
        _lock.unlock()
        NotificationCenter.default.post(name: .NSHTTPCookieManagerCookiesChanged, object: self)
    }
    open func deleteCookie(_ cookie: HTTPCookie) {
        _lock.lock()
        _load()
        _cookies.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
        _save()
        _lock.unlock()
        NotificationCenter.default.post(name: .NSHTTPCookieManagerCookiesChanged, object: self)
    }
    open func removeCookies(since date: Date) {
        _lock.lock(); _load(); _cookies.removeAll { _ in true }; _save(); _lock.unlock()   // creation dates are not tracked: removes all
    }
    open func setCookies(_ cookies: [HTTPCookie], for url: URL?, mainDocumentURL: URL?) {
        guard cookieAcceptPolicy != .never else { return }
        for c in cookies {
            if cookieAcceptPolicy == .onlyFromMainDocumentDomain, let main = mainDocumentURL?.host?.lowercased() {
                let d = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain
                guard main == d || main.hasSuffix("." + d) else { continue }
            }
            setCookie(c)
        }
    }
    open func sortedCookies(using sortOrder: [Any]) -> [HTTPCookie] { cookies ?? [] }
    open func storeCookies(_ cookies: [HTTPCookie], for task: URLSessionTask) {
        setCookies(cookies, for: task.currentRequest?.url, mainDocumentURL: task.currentRequest?.mainDocumentURL)
    }
    open func getCookiesFor(_ task: URLSessionTask, completionHandler: @escaping @Sendable ([HTTPCookie]?) -> Void) {
        completionHandler(task.currentRequest?.url.flatMap { cookies(for: $0) })
    }

    // locked
    func _purge() { _cookies.removeAll { $0._expired } }
    func _load() {
        guard !_loaded else { return }
        _loaded = true
        guard let f = _file, let d = FileManager.default.contents(atPath: f),
              let list = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] else { return }
        for item in list {
            var p: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in item { p[HTTPCookiePropertyKey(k)] = v }
            if let e = item["Expires"] as? Double { p[.expires] = Date(timeIntervalSince1970: e) }
            if let c = HTTPCookie(properties: p), !c._expired { _cookies.append(c) }
        }
    }
    func _save() {
        guard let f = _file else { return }
        let list: [[String: Any]] = _cookies.filter { !$0.isSessionOnly }.map { c in
            var d: [String: Any] = ["Name": c.name, "Value": c.value, "Domain": c.domain, "Path": c.path]
            if let e = c.expiresDate { d["Expires"] = e.timeIntervalSince1970 }
            if c.isSecure { d["Secure"] = "TRUE" }
            if c.isHTTPOnly { d["HttpOnly"] = "TRUE" }
            if let s = c.sameSitePolicy { d["SameSite"] = s.rawValue }
            return d
        }
        let dir = (f as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        if let data = try? JSONSerialization.data(withJSONObject: list) { try? data.write(to: URL(fileURLWithPath: f), options: .atomic) }
    }
}

// MARK: - URLCache
@objc(NSCachedURLResponse) open class CachedURLResponse: NSObject, @unchecked Sendable {
    public enum StoragePolicy: UInt, Sendable { case allowed = 0, allowedInMemoryOnly = 1, notAllowed = 2 }
    public let response: URLResponse
    public let data: Data
    public let userInfo: [AnyHashable: Any]?
    public let storagePolicy: StoragePolicy
    var _stored = Date()
    public init(response: URLResponse, data: Data) { self.response = response; self.data = data; userInfo = nil; storagePolicy = .allowed; super.init() }
    public init(response: URLResponse, data: Data, userInfo: [AnyHashable: Any]? = nil, storagePolicy: StoragePolicy) {
        self.response = response; self.data = data; self.userInfo = userInfo; self.storagePolicy = storagePolicy; super.init()
    }
}

/// Response cache for GET requests: an in-memory LRU of `memoryCapacity` bytes over an on-disk LRU of `diskCapacity`
/// bytes (one metadata file and one body file per response under `directory`; by default the app's
/// Library/Caches/<bundle id>/isim-urlcache), so cached responses survive relaunches like CFNetwork's Cache.db.
/// Responses over 5% of a tier's capacity skip that tier, as on iOS; `.allowedInMemoryOnly` responses stay in memory.
@objc(NSURLCache) open class URLCache: NSObject, @unchecked Sendable {
    open var memoryCapacity: Int { didSet { _lock.lock(); _trimMemory(); _lock.unlock() } }
    open var diskCapacity: Int { didSet { _lock.lock(); _trimDisk(); _lock.unlock() } }
    let _lock = NSLock()
    var _entries: [String: CachedURLResponse] = [:]
    var _order: [String] = []          // in memory, least recently used first
    let _dir: URL?
    /// on disk: file stem -> (bytes, last use, stored date); loaded on first use
    var _disk: [String: (size: Int, used: Date, stored: Date)]?
    nonisolated(unsafe) static var _shared = URLCache(memoryCapacity: 512 * 1024, diskCapacity: 10 * 1024 * 1024, directory: nil)
    open class var shared: URLCache {
        get { _shared }
        set { _shared = newValue }
    }
    static var _defaultDirectory: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return caches.appendingPathComponent(Bundle.main.bundleIdentifier ?? "isim").appendingPathComponent("isim-urlcache")
    }
    /// diskPath: a directory relative to the app's Caches directory (or an absolute path), as on iOS
    public init(memoryCapacity: Int, diskCapacity: Int, diskPath: String?) {
        self.memoryCapacity = memoryCapacity; self.diskCapacity = diskCapacity
        if let path = diskPath, !path.isEmpty {
            _dir = path.hasPrefix("/") ? URL(fileURLWithPath: path)
                : FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(path)
        } else { _dir = URLCache._defaultDirectory }
        super.init()
    }
    public init(memoryCapacity: Int, diskCapacity: Int, directory: URL? = nil) {
        self.memoryCapacity = memoryCapacity; self.diskCapacity = diskCapacity
        _dir = directory ?? URLCache._defaultDirectory
        super.init()
    }
    open var currentMemoryUsage: Int { _lock.lock(); defer { _lock.unlock() }; return _entries.values.reduce(0) { $0 + $1.data.count } }
    open var currentDiskUsage: Int { _lock.lock(); defer { _lock.unlock() }; return _index().values.reduce(0) { $0 + $1.size } }

    static func _key(_ r: URLRequest) -> String? {
        guard let u = r.url, (r.httpMethod ?? "GET") == "GET" else { return nil }
        var s = u.absoluteString
        if let h = s.firstIndex(of: "#") { s = String(s[..<h]) }
        return s
    }
    /// a stable file name for a key (FNV-1a 64)
    static func _stem(_ key: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return String(h, radix: 16)
    }

    open func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        guard let k = URLCache._key(request) else { return nil }
        _lock.lock(); defer { _lock.unlock() }
        if let e = _entries[k] {
            _order.removeAll { $0 == k }; _order.append(k)
            return e
        }
        guard let e = _load(k) else { return nil }
        _remember(k, e)
        return e
    }
    open func storeCachedResponse(_ cached: CachedURLResponse, for request: URLRequest) {
        guard let k = URLCache._key(request), cached.storagePolicy != .notAllowed else { return }
        _lock.lock(); defer { _lock.unlock() }
        _remember(k, cached)
        if cached.storagePolicy == .allowed, cached.data.count <= diskCapacity / 20 { _save(k, cached) }
        else { _delete(URLCache._stem(k)) }
    }
    open func removeCachedResponse(for request: URLRequest) {
        guard let k = URLCache._key(request) else { return }
        _lock.lock(); _entries[k] = nil; _order.removeAll { $0 == k }; _delete(URLCache._stem(k)); _lock.unlock()
    }
    open func removeAllCachedResponses() {
        _lock.lock(); defer { _lock.unlock() }
        _entries = [:]; _order = []
        _disk = nil                                       // rescan: other URLCache objects may share the directory
        for stem in Array(_index().keys) { _delete(stem) }
    }
    open func removeCachedResponses(since date: Date) {
        _lock.lock(); defer { _lock.unlock() }
        for (k, v) in _entries where v._stored >= date { _entries[k] = nil; _order.removeAll { $0 == k } }
        _disk = nil
        for (stem, e) in _index() where e.stored >= date { _delete(stem) }
    }
    open func storeCachedResponse(_ cached: CachedURLResponse, for task: URLSessionDataTask) {
        if let r = task.currentRequest { storeCachedResponse(cached, for: r) }
    }
    open func getCachedResponse(for task: URLSessionDataTask, completionHandler: @escaping @Sendable (CachedURLResponse?) -> Void) {
        completionHandler(task.currentRequest.flatMap { cachedResponse(for: $0) })
    }
    open func removeCachedResponse(for task: URLSessionDataTask) { if let r = task.currentRequest { removeCachedResponse(for: r) } }

    // MARK: memory tier (callers hold _lock)
    func _remember(_ k: String, _ e: CachedURLResponse) {
        _entries[k] = nil; _order.removeAll { $0 == k }
        guard e.data.count <= memoryCapacity / 20 || (memoryCapacity > 0 && e.data.count == 0) else { return }
        _entries[k] = e; _order.append(k)
        _trimMemory()
    }
    func _trimMemory() {
        var used = _entries.values.reduce(0) { $0 + $1.data.count }
        while used > memoryCapacity, let old = _order.first {
            _order.removeFirst(); used -= _entries.removeValue(forKey: old)?.data.count ?? 0
        }
        if memoryCapacity == 0 { _entries = [:]; _order = [] }
    }

    // MARK: disk tier (callers hold _lock): <stem>.json (key, response, dates) + <stem>.body
    func _index() -> [String: (size: Int, used: Date, stored: Date)] {
        if let d = _disk { return d }
        var d: [String: (size: Int, used: Date, stored: Date)] = [:]
        if let dir = _dir, let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            for n in names where n.hasSuffix(".json") {
                let stem = String(n.dropLast(5))
                let meta = dir.appendingPathComponent(n), body = dir.appendingPathComponent(stem + ".body")
                guard let a = try? FileManager.default.attributesOfItem(atPath: meta.path) else { continue }
                let bsize = ((try? FileManager.default.attributesOfItem(atPath: body.path))?[.size] as? Int) ?? 0
                let info = (try? Data(contentsOf: meta)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let stored = (info?["stored"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date.distantPast
                d[stem] = ((a[.size] as? Int ?? 0) + bsize, a[.modificationDate] as? Date ?? Date.distantPast, stored)
            }
        }
        _disk = d
        return d
    }
    func _save(_ k: String, _ e: CachedURLResponse) {
        guard let dir = _dir, diskCapacity > 0 else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stem = URLCache._stem(k)
        var info: [String: Any] = ["key": k, "stored": e._stored.timeIntervalSince1970, "url": e.response.url?.absoluteString ?? k]
        if let h = e.response as? HTTPURLResponse {
            info["status"] = h.statusCode; info["version"] = h._httpVersion ?? "HTTP/1.1"
            info["headers"] = h._headers.map { [$0.0, $0.1] }
        } else {
            info["mime"] = e.response.mimeType ?? ""; info["length"] = e.response.expectedContentLength
            info["encoding"] = e.response.textEncodingName ?? ""
        }
        guard let meta = try? JSONSerialization.data(withJSONObject: info) else { return }
        let mURL = dir.appendingPathComponent(stem + ".json"), bURL = dir.appendingPathComponent(stem + ".body")
        guard (try? e.data.write(to: bURL, options: .atomic)) != nil, (try? meta.write(to: mURL, options: .atomic)) != nil else { return }
        var d = _index()
        d[stem] = (meta.count + e.data.count, Date(), e._stored)
        _disk = d
        _trimDisk()
    }
    func _load(_ k: String) -> CachedURLResponse? {
        guard let dir = _dir else { return nil }
        let stem = URLCache._stem(k)
        let mURL = dir.appendingPathComponent(stem + ".json"), bURL = dir.appendingPathComponent(stem + ".body")
        guard let m = try? Data(contentsOf: mURL), let info = try? JSONSerialization.jsonObject(with: m) as? [String: Any],
              info["key"] as? String == k, let body = try? Data(contentsOf: bURL),
              let url = URL(string: info["url"] as? String ?? k) else { return nil }
        let response: URLResponse
        if let status = info["status"] as? Int {
            let headers = (info["headers"] as? [[String]] ?? []).compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
            response = HTTPURLResponse(_url: url, statusCode: status, httpVersion: info["version"] as? String, headers: headers)
        } else {
            let mime = info["mime"] as? String, enc = info["encoding"] as? String
            response = URLResponse(url: url, mimeType: mime?.isEmpty == false ? mime : nil, expectedContentLength: info["length"] as? Int ?? body.count,
                                   textEncodingName: enc?.isEmpty == false ? enc : nil)
        }
        let e = CachedURLResponse(response: response, data: body, userInfo: nil, storagePolicy: .allowed)
        e._stored = Date(timeIntervalSince1970: info["stored"] as? Double ?? Date().timeIntervalSince1970)
        // the least recently used entries go first when the disk tier is full
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: mURL.path)
        var d = _index()
        d[stem] = (m.count + body.count, Date(), e._stored)   // also when another URLCache object wrote it
        _disk = d
        return e
    }
    func _delete(_ stem: String) {
        guard let dir = _dir else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(stem + ".json"))
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(stem + ".body"))
        _disk?[stem] = nil
    }
    func _trimDisk() {
        var d = _index()
        var used = d.values.reduce(0) { $0 + $1.size }
        for (stem, _) in d.sorted(by: { $0.value.used < $1.value.used }) where used > diskCapacity {
            used -= d[stem]?.size ?? 0; d[stem] = nil; _delete(stem)
        }
    }
}
