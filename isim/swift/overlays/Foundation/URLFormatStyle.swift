// isim Foundation: URL.FormatStyle and URL.ParseStrategy (iOS 16), URL.Template (iOS 26, RFC 6570 URI templates) and
// Date.HTTPFormatStyle (iOS 26, RFC 9110 dates). Self-authored, iOS API names. Adapted: the components come from
// URLComponents.

// MARK: - URL.FormatStyle
extension URL {
    /// Formats a URL for display, showing the components the style asks for.
    public struct FormatStyle: Foundation.FormatStyle, ParseableFormatStyle, Codable, Hashable, Sendable {
        public enum Component: String, Codable, Hashable, Sendable {
            case scheme, user, password, host, port, path, query, fragment
        }
        /// When a component is shown.
        public struct ComponentDisplayOption: Codable, Hashable, Sendable, CustomStringConvertible {
            enum Kind: String, Codable, Hashable, Sendable { case always, never, omitIfHTTPFamily, displayWhen, omitWhen }
            let kind: Kind
            let condition: Component?
            let values: Set<String>
            public static var always: ComponentDisplayOption { .init(kind: .always, condition: nil, values: []) }
            public static var never: ComponentDisplayOption { .init(kind: .never, condition: nil, values: []) }
            /// hidden for http and https URLs
            public static var omitIfHTTPFamily: ComponentDisplayOption { .init(kind: .omitIfHTTPFamily, condition: nil, values: []) }
            public static func displayWhen(_ component: Component, matches values: Set<String>) -> ComponentDisplayOption {
                .init(kind: .displayWhen, condition: component, values: values)
            }
            public static func omitWhen(_ component: Component, matches values: Set<String>) -> ComponentDisplayOption {
                .init(kind: .omitWhen, condition: component, values: values)
            }
            func shows(_ c: URLComponents) -> Bool {
                switch kind {
                case .always: return true
                case .never: return false
                case .omitIfHTTPFamily: return !["http", "https"].contains(c.scheme?.lowercased() ?? "")
                case .displayWhen: return condition.map { values.contains(FormatStyle.value($0, c) ?? "") } ?? true
                case .omitWhen: return !(condition.map { values.contains(FormatStyle.value($0, c) ?? "") } ?? false)
                }
            }
            public var description: String { kind.rawValue }
        }
        /// When and how the host is shown.
        public struct HostDisplayOption: Codable, Hashable, Sendable, CustomStringConvertible {
            let display: ComponentDisplayOption
            let omitted: Set<String>
            let multiLevel: Bool
            public static var always: HostDisplayOption { .init(display: .always, omitted: [], multiLevel: false) }
            public static var never: HostDisplayOption { .init(display: .never, omitted: [], multiLevel: false) }
            public static var omitIfHTTPFamily: HostDisplayOption { .init(display: .omitIfHTTPFamily, omitted: [], multiLevel: false) }
            public static func displayWhen(_ component: Component, matches values: Set<String>) -> HostDisplayOption {
                .init(display: .displayWhen(component, matches: values), omitted: [], multiLevel: false)
            }
            public static func omitWhen(_ component: Component, matches values: Set<String>) -> HostDisplayOption {
                .init(display: .omitWhen(component, matches: values), omitted: [], multiLevel: false)
            }
            /// the host without the given leading subdomains ("www"); with includeMultiLevelSubdomains, any number of them
            public static func omitSpecificSubdomains(_ subdomains: Set<String> = [], includeMultiLevelSubdomains: Bool = false) -> HostDisplayOption {
                .init(display: .always, omitted: subdomains, multiLevel: includeMultiLevelSubdomains)
            }
            public static func omitSpecificSubdomains(_ subdomains: Set<String> = [], includeMultiLevelSubdomains: Bool = false, when component: Component,
                                                      matches values: Set<String>) -> HostDisplayOption {
                .init(display: .displayWhen(component, matches: values), omitted: subdomains, multiLevel: includeMultiLevelSubdomains)
            }
            func host(_ h: String, _ c: URLComponents) -> String {
                guard !omitted.isEmpty else { return h }
                var labels = h.split(separator: ".").map(String.init)
                // a subdomain only: keep at least the registrable domain (two labels)
                while labels.count > 2, omitted.contains(labels[0].lowercased()) {
                    labels.removeFirst()
                    if !multiLevel { break }
                }
                return labels.joined(separator: ".")
            }
            public var description: String { display.description }
        }

        public var scheme: ComponentDisplayOption
        public var user: ComponentDisplayOption
        public var password: ComponentDisplayOption
        public var host: HostDisplayOption
        public var port: ComponentDisplayOption
        public var path: ComponentDisplayOption
        public var query: ComponentDisplayOption
        public var fragment: ComponentDisplayOption

        public init(scheme: ComponentDisplayOption = .always, user: ComponentDisplayOption = .never, password: ComponentDisplayOption = .never,
                    host: HostDisplayOption = .always, port: ComponentDisplayOption = .omitIfHTTPFamily, path: ComponentDisplayOption = .always,
                    query: ComponentDisplayOption = .never, fragment: ComponentDisplayOption = .never) {
            self.scheme = scheme; self.user = user; self.password = password; self.host = host
            self.port = port; self.path = path; self.query = query; self.fragment = fragment
        }

        static func value(_ component: Component, _ c: URLComponents) -> String? {
            switch component {
            case .scheme: return c.scheme
            case .user: return c.user
            case .password: return c.password
            case .host: return c.host
            case .port: return c.port.map(String.init)
            case .path: return c.path
            case .query: return c.query
            case .fragment: return c.fragment
            }
        }

        public func format(_ value: URL) -> String {
            guard let c = URLComponents(url: value, resolvingAgainstBaseURL: true) else { return value.absoluteString }
            var out = ""
            let showHost = c.host.map { !$0.isEmpty } == true && host.display.shows(c)
            if let s = c.scheme, scheme.shows(c) { out += s + (c.host != nil ? "://" : ":") }
            if showHost {
                if let u = c.user, user.shows(c) {
                    out += u
                    if let p = c.password, password.shows(c) { out += ":" + p }
                    out += "@"
                }
                out += host.host(c.host!, c)
                if let p = c.port, port.shows(c) { out += ":\(p)" }
            }
            if path.shows(c) {
                var p = c.path
                if !showHost, out.isEmpty, p.hasPrefix("/") == false { p = c.path }
                out += p
            }
            if let q = c.query, query.shows(c) { out += "?" + q }
            if let f = c.fragment, fragment.shows(c) { out += "#" + f }
            return out
        }

        public func scheme(_ strategy: ComponentDisplayOption = .always) -> FormatStyle { var s = self; s.scheme = strategy; return s }
        public func user(_ strategy: ComponentDisplayOption = .always) -> FormatStyle { var s = self; s.user = strategy; return s }
        public func password(_ strategy: ComponentDisplayOption = .always) -> FormatStyle { var s = self; s.password = strategy; return s }
        public func host(_ strategy: HostDisplayOption = .always) -> FormatStyle { var s = self; s.host = strategy; return s }
        public func port(_ strategy: ComponentDisplayOption = .always) -> FormatStyle { var s = self; s.port = strategy; return s }
        public func path(_ strategy: ComponentDisplayOption = .always) -> FormatStyle { var s = self; s.path = strategy; return s }
        public func query(_ strategy: ComponentDisplayOption = .always) -> FormatStyle { var s = self; s.query = strategy; return s }
        public func fragment(_ strategy: ComponentDisplayOption = .always) -> FormatStyle { var s = self; s.fragment = strategy; return s }

        public var parseStrategy: URL.ParseStrategy { URL.ParseStrategy() }
    }

    public func formatted() -> String { FormatStyle().format(self) }
    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == URL { format.format(self) }
}

extension Foundation.FormatStyle where Self == URL.FormatStyle {
    public static var url: URL.FormatStyle { URL.FormatStyle() }
}

// MARK: - URL.ParseStrategy
extension URL {
    /// Parses a URL, requiring the components the strategy asks for or filling them in.
    public struct ParseStrategy: Foundation.ParseStrategy, Codable, Hashable, Sendable {
        public enum ComponentParseStrategy<Component: Codable & Hashable & Sendable>: Codable, Hashable, Sendable, CustomStringConvertible {
            case required
            case optional
            case defaultValue(Component)
            public var description: String {
                switch self {
                case .required: return "required"
                case .optional: return "optional"
                case .defaultValue(let v): return "defaultValue(\(v))"
                }
            }
        }
        public var scheme: ComponentParseStrategy<String>
        public var user: ComponentParseStrategy<String>
        public var password: ComponentParseStrategy<String>
        public var host: ComponentParseStrategy<String>
        public var port: ComponentParseStrategy<Int>
        public var path: ComponentParseStrategy<String>
        public var query: ComponentParseStrategy<String>
        public var fragment: ComponentParseStrategy<String>

        public init(scheme: ComponentParseStrategy<String> = .required, user: ComponentParseStrategy<String> = .optional,
                    password: ComponentParseStrategy<String> = .optional, host: ComponentParseStrategy<String> = .required,
                    port: ComponentParseStrategy<Int> = .optional, path: ComponentParseStrategy<String> = .optional,
                    query: ComponentParseStrategy<String> = .optional, fragment: ComponentParseStrategy<String> = .optional) {
            self.scheme = scheme; self.user = user; self.password = password; self.host = host
            self.port = port; self.path = path; self.query = query; self.fragment = fragment
        }

        struct Failure: Error, CustomStringConvertible { let description: String }

        public func parse(_ value: String) throws -> URL {
            var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            // no scheme: a default one is prepended ("example.com/x" -> "https://example.com/x")
            if !text.contains("://"), case .defaultValue(let s) = scheme { text = s + "://" + text }
            guard var c = URLComponents(string: text) else { throw Failure(description: "Cannot parse \"\(value)\" as a URL") }
            func apply<T>(_ strategy: ComponentParseStrategy<T>, _ name: String, _ get: () -> T?, _ set: (T) -> Void) throws {
                switch strategy {
                case .required: if get() == nil { throw Failure(description: "The URL \"\(value)\" has no \(name)") }
                case .optional: break
                case .defaultValue(let v): if get() == nil { set(v) }
                }
            }
            try apply(scheme, "scheme", { c.scheme }, { c.scheme = $0 })
            try apply(user, "user", { c.user }, { c.user = $0 })
            try apply(password, "password", { c.password }, { c.password = $0 })
            try apply(host, "host", { c.host.flatMap { $0.isEmpty ? nil : $0 } }, { c.host = $0 })
            try apply(port, "port", { c.port }, { c.port = $0 })
            try apply(path, "path", { c.path.isEmpty ? nil : c.path }, { c.path = $0 })
            try apply(query, "query", { c.query }, { c.query = $0 })
            try apply(fragment, "fragment", { c.fragment }, { c.fragment = $0 })
            guard let url = c.url else { throw Failure(description: "Cannot parse \"\(value)\" as a URL") }
            return url
        }

        public func scheme(_ strategy: ComponentParseStrategy<String> = .required) -> ParseStrategy { var s = self; s.scheme = strategy; return s }
        public func user(_ strategy: ComponentParseStrategy<String> = .required) -> ParseStrategy { var s = self; s.user = strategy; return s }
        public func password(_ strategy: ComponentParseStrategy<String> = .required) -> ParseStrategy { var s = self; s.password = strategy; return s }
        public func host(_ strategy: ComponentParseStrategy<String> = .required) -> ParseStrategy { var s = self; s.host = strategy; return s }
        public func port(_ strategy: ComponentParseStrategy<Int> = .required) -> ParseStrategy { var s = self; s.port = strategy; return s }
        public func path(_ strategy: ComponentParseStrategy<String> = .required) -> ParseStrategy { var s = self; s.path = strategy; return s }
        public func query(_ strategy: ComponentParseStrategy<String> = .required) -> ParseStrategy { var s = self; s.query = strategy; return s }
        public func fragment(_ strategy: ComponentParseStrategy<String> = .required) -> ParseStrategy { var s = self; s.fragment = strategy; return s }
    }

    /// Parses `value` with `strategy` (URL(_:strategy:)).
    public init<T: Foundation.ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == URL {
        self = try strategy.parse(value)
    }
}

extension Foundation.ParseStrategy where Self == URL.ParseStrategy {
    public static var url: URL.ParseStrategy { URL.ParseStrategy() }
}

extension URL.ParseStrategy: CustomConsumingRegexComponent {
    public typealias RegexOutput = URL
    /// the longest run of non-whitespace characters at `index` that parses as a URL
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: URL)? {
        var end = index
        while end < bounds.upperBound, !input[end].isWhitespace { end = input.index(after: end) }
        while end > index {
            if let url = try? parse(String(input[index..<end])) { return (end, url) }
            end = input.index(before: end)
        }
        return nil
    }
}

// MARK: - URL.Template (RFC 6570, levels 1–4)
extension URL {
    /// A URI template ("https://example.com/{user}/repos{?page,per_page}") whose variables expand to a URL.
    public struct Template: Hashable, Sendable, CustomStringConvertible {
        /// A variable's value: a string, a list or an associative list.
        public struct Value: Hashable, Sendable, CustomStringConvertible {
            enum Kind: Hashable, Sendable { case text(String), list([String]), associative([Pair]) }
            struct Pair: Hashable, Sendable { let key: String, value: String }
            let kind: Kind
            public static func text(_ text: String) -> Self { Self(kind: .text(text)) }
            public static func list(_ list: some Sequence<String>) -> Self { Self(kind: .list(Array(list))) }
            public static func associativeList(_ list: some Sequence<(key: String, value: String)>) -> Self {
                Self(kind: .associative(list.map { Pair(key: $0.key, value: $0.value) }))
            }
            public var description: String {
                switch kind {
                case .text(let s): return s
                case .list(let l): return l.joined(separator: ",")
                case .associative(let a): return a.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
                }
            }
        }
        /// A variable's name in a template.
        public struct VariableName: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
            let name: String
            public init(_ name: String) { self.name = name }
            public init(stringLiteral value: String) { name = value }
            public var description: String { name }
        }

        enum Part: Hashable, Sendable { case literal(String), expression(Character?, [VarSpec]) }
        struct VarSpec: Hashable, Sendable { let name: String, explode: Bool, prefix: Int? }
        let parts: [Part]
        let source: String

        /// nil when the template is malformed (an unclosed or empty expression, a bad variable name)
        public init?(_ template: String) {
            var parts: [Part] = [], literal = ""
            var i = template.startIndex
            while i < template.endIndex {
                let ch = template[i]
                if ch == "}" { return nil }
                guard ch == "{" else { literal.append(ch); i = template.index(after: i); continue }
                guard let close = template[i...].firstIndex(of: "}") else { return nil }
                if !literal.isEmpty { parts.append(.literal(literal)); literal = "" }
                var body = Substring(template[template.index(after: i)..<close])
                var op: Character? = nil
                if let f = body.first, "+#./;?&".contains(f) { op = f; body = body.dropFirst() }
                var specs: [VarSpec] = []
                for raw in body.split(separator: ",", omittingEmptySubsequences: false) {
                    var name = String(raw), explode = false, prefix: Int? = nil
                    if name.hasSuffix("*") { explode = true; name.removeLast() }
                    if let colon = name.firstIndex(of: ":") {
                        guard let n = Int(name[name.index(after: colon)...]), n > 0, n < 10000 else { return nil }
                        prefix = n; name = String(name[..<colon])
                    }
                    guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "%" }) else { return nil }
                    specs.append(VarSpec(name: name, explode: explode, prefix: prefix))
                }
                guard !specs.isEmpty else { return nil }
                parts.append(.expression(op, specs))
                i = template.index(after: close)
            }
            if !literal.isEmpty { parts.append(.literal(literal)) }
            self.parts = parts
            source = template
        }
        public var description: String { source }

        static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        static let reservedToo = unreserved.union(CharacterSet(charactersIn: ":/?#[]@!$&'()*+,;="))
        static func encode(_ s: String, reserved: Bool) -> String {
            if reserved {          /* keep reserved characters and existing percent-escapes */
                var out = "", chars = Array(s)
                var k = 0
                while k < chars.count {
                    let c = chars[k]
                    if c == "%", k + 2 < chars.count, chars[k + 1].isHexDigit, chars[k + 2].isHexDigit { out += String(chars[k...k + 2]); k += 3; continue }
                    out += String(c).addingPercentEncoding(withAllowedCharacters: reservedToo) ?? String(c)
                    k += 1
                }
                return out
            }
            return s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
        }

        func expand(_ variables: [VariableName: Value]) -> String {
            var out = ""
            for part in parts {
                switch part {
                case .literal(let s): out += Template.encode(s, reserved: true)
                case .expression(let op, let specs):
                    let reserved = op == "+" || op == "#"
                    let first: String = op.map { $0 == "+" ? "" : String($0) } ?? ""
                    let sep = op == nil || op == "+" || op == "#" ? "," : op == "?" || op == "&" ? "&" : String(op!)
                    let named = op == ";" || op == "?" || op == "&"
                    let ifEmpty = op == "?" || op == "&" ? "=" : ""
                    var pieces: [String] = []
                    for spec in specs {
                        guard let v = variables[VariableName(spec.name)] else { continue }
                        let enc = { (s: String) in Template.encode(s, reserved: reserved) }
                        switch v.kind {
                        case .text(var s):
                            if let p = spec.prefix { s = String(s.prefix(p)) }
                            pieces.append(named ? spec.name + (s.isEmpty ? ifEmpty : "=" + enc(s)) : enc(s))
                        case .list(let l):
                            if l.isEmpty { continue }
                            if spec.explode { pieces += l.map { named ? spec.name + ($0.isEmpty ? ifEmpty : "=" + enc($0)) : enc($0) } }
                            else { pieces.append((named ? spec.name + "=" : "") + l.map(enc).joined(separator: ",")) }
                        case .associative(let a):
                            if a.isEmpty { continue }
                            if spec.explode { pieces += a.map { enc($0.key) + "=" + enc($0.value) } }
                            else { pieces.append((named ? spec.name + "=" : "") + a.map { enc($0.key) + "," + enc($0.value) }.joined(separator: ",")) }
                        }
                    }
                    if !pieces.isEmpty { out += first + pieces.joined(separator: sep) }
                }
            }
            return out
        }
    }

    /// The URL a template expands to with the variables' values (nil when the expansion is not a URL).
    public init?(template: URL.Template, variables: [URL.Template.VariableName: URL.Template.Value]) {
        guard let u = URL(string: template.expand(variables)) else { return nil }
        self = u
    }
}

extension URL.Template.Value: ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(stringLiteral value: String) { self = .text(value) }
    public init(arrayLiteral elements: String...) { self = .list(elements) }
    public init(dictionaryLiteral elements: (String, String)...) { self = .associativeList(elements.map { (key: $0.0, value: $0.1) }) }
}

// MARK: - Date.HTTPFormatStyle (RFC 9110 §5.6.7)
extension Date {
    /// Formats dates as HTTP does ("Sun, 06 Nov 1994 08:49:37 GMT"); parses that form and the obsolete RFC 850 and
    /// asctime forms.
    public struct HTTPFormatStyle: Foundation.FormatStyle, ParseableFormatStyle, Foundation.ParseStrategy, Codable, Hashable, Sendable {
        public init() {}
        static let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        static var gmt: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "GMT")!; return c }

        public func format(_ value: Date) -> String {
            let d = HTTPFormatStyle.gmt.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: value)
            func two(_ n: Int?) -> String { let v = n ?? 0; return v < 10 ? "0\(v)" : "\(v)" }
            return "\(HTTPFormatStyle.days[(d.weekday ?? 1) - 1]), \(two(d.day)) \(HTTPFormatStyle.months[(d.month ?? 1) - 1]) \(d.year ?? 1970) " +
                   "\(two(d.hour)):\(two(d.minute)):\(two(d.second)) GMT"
        }
        public var parseStrategy: HTTPFormatStyle { self }

        struct Failure: Error, CustomStringConvertible { let description: String }

        public func parse(_ value: String) throws -> Date {
            let words = value.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "-", with: " ")
                .split(separator: " ").map(String.init)
            var day: Int?, month: Int?, year: Int?, time: [Int]?
            for w in words {
                if let m = HTTPFormatStyle.months.firstIndex(where: { $0.caseInsensitiveCompare(w.prefix(3)) == .orderedSame && w.count <= 9 && w.count >= 3 }),
                   HTTPFormatStyle.days.allSatisfy({ $0.caseInsensitiveCompare(w.prefix(3)) != .orderedSame }) { month = m + 1; continue }
                if w.contains(":") { time = w.split(separator: ":").compactMap { Int($0) }; continue }
                if let n = Int(w) {
                    if w.count == 4 { year = n } else if day == nil { day = n } else if year == nil { year = n < 70 ? 2000 + n : 1900 + n }
                }
            }
            guard let day, let month, let year, let time, time.count == 3 else { throw Failure(description: "Cannot parse \"\(value)\" as an HTTP date") }
            let c = DateComponents(year: year, month: month, day: day, hour: time[0], minute: time[1], second: time[2])
            guard let d = HTTPFormatStyle.gmt.date(from: c) else { throw Failure(description: "Cannot parse \"\(value)\" as an HTTP date") }
            return d
        }
    }

}

extension Foundation.FormatStyle where Self == Date.HTTPFormatStyle {
    public static var http: Date.HTTPFormatStyle { Date.HTTPFormatStyle() }
}
extension Foundation.ParseStrategy where Self == Date.HTTPFormatStyle {
    public static var http: Date.HTTPFormatStyle { Date.HTTPFormatStyle() }
}
