// isim Foundation: URLComponents / URLQueryItem (RFC 3986 parsing and building, percent-encoding) and the URL
// helpers that go with them (self-authored). Components are stored percent-encoded, as Apple's are; the
// plain accessors decode on get and encode what is not allowed in that component on set.

public struct URLQueryItem: Hashable, Sendable, CustomStringConvertible {
    public var name: String
    public var value: String?
    public init(name: String, value: String?) { self.name = name; self.value = value }
    public var description: String { value.map { "\(name)=\($0)" } ?? name }
}

public struct URLComponents: Hashable, Sendable, CustomStringConvertible {
    public var scheme: String? {
        didSet { if let s = scheme, !URLComponents._validScheme(s) { scheme = oldValue } }
    }
    public var percentEncodedUser: String?
    public var percentEncodedPassword: String?
    /// stored without IPv6 brackets
    public var percentEncodedHost: String?
    public var port: Int?
    public var percentEncodedPath: String = ""
    public var percentEncodedQuery: String?
    public var percentEncodedFragment: String?

    public init() {}

    public init?(string: String) {
        guard URLComponents._validURLCharacters(string), let c = URLComponents._parse(string) else { return nil }
        self = c
    }
    /// iOS 17: `encodingInvalidCharacters` percent-encodes characters that may not appear in a URL instead of failing.
    public init?(string: String, encodingInvalidCharacters: Bool) {
        if !encodingInvalidCharacters { self.init(string: string); return }
        self.init(string: URLComponents._encodeInvalid(string))
    }
    public init?(url: URL, resolvingAgainstBaseURL resolve: Bool) { self.init(string: url.absoluteString) }

    // MARK: decoded accessors
    public var user: String? {
        get { percentEncodedUser?.removingPercentEncoding }
        set { percentEncodedUser = newValue?.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) }
    }
    public var password: String? {
        get { percentEncodedPassword?.removingPercentEncoding }
        set { percentEncodedPassword = newValue?.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) }
    }
    public var host: String? {
        get { percentEncodedHost?.removingPercentEncoding }
        set { percentEncodedHost = newValue?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) }
    }
    /// the host as it appears in the URL (IDNA is not applied by isim)
    public var encodedHost: String? {
        get { percentEncodedHost }
        set { percentEncodedHost = newValue }
    }
    public var path: String {
        get { percentEncodedPath.removingPercentEncoding ?? percentEncodedPath }
        set { percentEncodedPath = newValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? newValue }
    }
    public var query: String? {
        get { percentEncodedQuery?.removingPercentEncoding }
        set { percentEncodedQuery = newValue?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }
    }
    public var fragment: String? {
        get { percentEncodedFragment?.removingPercentEncoding }
        set { percentEncodedFragment = newValue?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) }
    }

    /// Query items, decoded. Setting encodes each name and value (like Apple: `&`, `=` and `#` are escaped, `+` is not).
    public var queryItems: [URLQueryItem]? {
        get {
            percentEncodedQueryItems?.map { URLQueryItem(name: $0.name.removingPercentEncoding ?? $0.name, value: $0.value.map { $0.removingPercentEncoding ?? $0 }) }
        }
        set {
            guard let items = newValue else { percentEncodedQuery = nil; return }
            let allowed = URLComponents._queryItemAllowed
            percentEncodedQuery = items.map { item in
                let n = item.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? item.name
                return item.value.map { n + "=" + ($0.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0) } ?? n
            }.joined(separator: "&")
        }
    }
    public var percentEncodedQueryItems: [URLQueryItem]? {
        get {
            guard let q = percentEncodedQuery else { return nil }
            if q.isEmpty { return [] }
            return q.split(separator: "&", omittingEmptySubsequences: false).map { part in
                if let eq = part.firstIndex(of: "=") { return URLQueryItem(name: String(part[..<eq]), value: String(part[part.index(after: eq)...])) }
                return URLQueryItem(name: String(part), value: nil)
            }
        }
        set { percentEncodedQuery = newValue?.map { item in item.value.map { "\(item.name)=\($0)" } ?? item.name }.joined(separator: "&") }
    }

    // MARK: building
    /// The URL string, or nil when the components cannot form a valid URL (e.g. a host with a relative path).
    public var string: String? {
        var s = ""
        if let scheme { s += scheme + ":" }
        let hasAuthority = percentEncodedHost != nil || percentEncodedUser != nil || port != nil
        if hasAuthority {
            if !percentEncodedPath.isEmpty && !percentEncodedPath.hasPrefix("/") { return nil }
            s += "//"
            if let u = percentEncodedUser {
                s += u
                if let p = percentEncodedPassword { s += ":" + p }
                s += "@"
            }
            if let h = percentEncodedHost { s += h.contains(":") && !h.hasPrefix("[") ? "[\(h)]" : h }
            if let port { s += ":\(port)" }
        } else if percentEncodedPath.hasPrefix("//") {
            return nil
        } else if scheme == nil, let colon = percentEncodedPath.firstIndex(of: ":"),
                  !percentEncodedPath[..<colon].contains("/") {
            return nil   // the first segment of a relative path would read as a scheme
        }
        s += percentEncodedPath
        if let q = percentEncodedQuery { s += "?" + q }
        if let f = percentEncodedFragment { s += "#" + f }
        return s
    }
    public var url: URL? { string.flatMap { URL(string: $0) } }
    public func url(relativeTo base: URL?) -> URL? { string.flatMap { URL(string: $0, relativeTo: base) } }
    public var description: String { string ?? "" }

    // MARK: parsing (RFC 3986 section 3)
    static func _validScheme(_ s: String) -> Bool {
        guard let f = s.unicodeScalars.first, f.isASCII, f.properties.isAlphabetic else { return false }
        return s.unicodeScalars.allSatisfy { $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0) || "+-.".unicodeScalars.contains($0)) }
    }
    static func _validURLCharacters(_ s: String) -> Bool {
        s.unicodeScalars.allSatisfy { $0.isASCII && $0.value > 0x20 && $0.value < 0x7f && !"\"<>\\^`{|}".unicodeScalars.contains($0) }
    }
    static func _encodeInvalid(_ s: String) -> String {
        var out = ""
        for u in s.unicodeScalars {
            if u.isASCII && u.value > 0x20 && u.value < 0x7f && !"\"<>\\^`{|}".unicodeScalars.contains(u) { out.unicodeScalars.append(u) }
            else { for b in String(u).utf8 { out += "%" + (b < 16 ? "0" : "") + String(b, radix: 16, uppercase: true) } }
        }
        return out
    }
    static let _queryItemAllowed: CharacterSet = {
        var c = CharacterSet.urlQueryAllowed
        c.remove(charactersIn: "&=#")
        return c
    }()

    static func _parse(_ str: String) -> URLComponents? {
        var c = URLComponents()
        var rest = Substring(str)
        if let colon = rest.firstIndex(of: ":"), colon > rest.startIndex,
           !rest[..<colon].contains(where: { "/?#".contains($0) }) {
            let scheme = String(rest[..<colon])
            if _validScheme(scheme) { c.scheme = scheme; rest = rest[rest.index(after: colon)...] }
            else if scheme.allSatisfy({ $0.isNumber }) == false { return nil }
        }
        if let h = rest.firstIndex(of: "#") { c.percentEncodedFragment = String(rest[rest.index(after: h)...]); rest = rest[..<h] }
        if let q = rest.firstIndex(of: "?") { c.percentEncodedQuery = String(rest[rest.index(after: q)...]); rest = rest[..<q] }
        if rest.hasPrefix("//") {
            rest = rest.dropFirst(2)
            let end = rest.firstIndex(of: "/") ?? rest.endIndex
            var authority = rest[..<end]
            rest = rest[end...]
            if let at = authority.lastIndex(of: "@") {
                let info = authority[..<at]
                if let pc = info.firstIndex(of: ":") {
                    c.percentEncodedUser = String(info[..<pc]); c.percentEncodedPassword = String(info[info.index(after: pc)...])
                } else { c.percentEncodedUser = String(info) }
                authority = authority[authority.index(after: at)...]
            }
            if authority.hasPrefix("[") {                    // IPv6 literal
                guard let close = authority.firstIndex(of: "]") else { return nil }
                c.percentEncodedHost = String(authority[authority.index(after: authority.startIndex)..<close])
                authority = authority[authority.index(after: close)...]
                if authority.hasPrefix(":") {
                    let p = authority.dropFirst()
                    if !p.isEmpty { guard let n = Int(p), n >= 0 else { return nil }; c.port = n }
                } else if !authority.isEmpty { return nil }
            } else {
                if let pc = authority.lastIndex(of: ":") {
                    let p = authority[authority.index(after: pc)...]
                    if !p.isEmpty { guard let n = Int(p), n >= 0 else { return nil }; c.port = n }
                    authority = authority[..<pc]
                }
                c.percentEncodedHost = String(authority)
            }
        }
        c.percentEncodedPath = String(rest)
        return c
    }
}

extension URLComponents: Codable {
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let c = URLComponents(string: s) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid URL string."))
        }
        self = c
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(string ?? "") }
}

// MARK: - URL helpers built on URLComponents
extension URL {
    /// iOS 17: percent-encodes invalid characters (spaces, quotes, non-ASCII) instead of failing.
    public init?(string: String, encodingInvalidCharacters: Bool) {
        if encodingInvalidCharacters { self.init(string: URLComponents._encodeInvalid(string)) } else { self.init(string: string) }
    }
    var _components: URLComponents? { URLComponents(string: absoluteString) }
    public var user: String? { _components?.user }
    public var password: String? { _components?.password }
    public func user(percentEncoded: Bool = true) -> String? { percentEncoded ? _components?.percentEncodedUser : _components?.user }
    public func password(percentEncoded: Bool = true) -> String? { percentEncoded ? _components?.percentEncodedPassword : _components?.password }
    public func host(percentEncoded: Bool = true) -> String? { percentEncoded ? _components?.percentEncodedHost : _components?.host }
    public func query(percentEncoded: Bool = true) -> String? { percentEncoded ? _components?.percentEncodedQuery : _components?.query }
    public func fragment(percentEncoded: Bool = true) -> String? { percentEncoded ? _components?.percentEncodedFragment : _components?.fragment }
    public var relativeString: String { absoluteString }
    public var relativePath: String { path }
    public var baseURL: URL? { nil }
    /// iOS 16: appends query items (encoded like URLComponents.queryItems).
    public func appending(queryItems items: [URLQueryItem]) -> URL {
        guard var c = _components else { return self }
        c.queryItems = (c.queryItems ?? []) + items
        return c.url ?? self
    }
    public mutating func append(queryItems items: [URLQueryItem]) { self = appending(queryItems: items) }
    public mutating func append(path: String) { self = appending(path: path) }
    public mutating func append(component: String) { self = appending(component: component) }
    public mutating func appendPathComponent(_ c: String) { self = appendingPathComponent(c) }
    public mutating func appendPathExtension(_ e: String) { self = appendingPathExtension(e) }
    public mutating func deleteLastPathComponent() { self = deletingLastPathComponent() }
    public mutating func deletePathExtension() { self = deletingPathExtension() }
}
