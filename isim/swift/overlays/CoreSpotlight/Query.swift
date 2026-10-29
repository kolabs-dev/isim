// isim CoreSpotlight: queries over the app's own items (adapted).
// - CSSearchQuery takes Apple's query language: `attribute OP value` (==, !=, <, >, <=, >=), InRange(attribute, a, b),
//   && and || with parentheses and !, string values in double quotes with * wildcards and the c (case), d (diacritics),
//   w (words) and t (tokenized, like w) modifiers, numbers, and $time.now / today / yesterday / this_week / this_month /
//   this_year (with an offset in parentheses) and $time.iso(DATE). `*` and `**` as the attribute mean any text
//   attribute; Apple's kMDItem names are accepted for the common attributes, and custom attributes by key name.
// - CSUserQuery (iOS 18) is Spotlight's search of what a person typed: every word matches the start of a word in the
//   item's text, ranked by where it matched, how often the person chose the item (userEngaged) and how recent it is;
//   suggestions complete the last word from the items' titles and keywords.
import Foundation

// MARK: - the query language

indirect enum _CSExpr {
    case and(_CSExpr, _CSExpr), or(_CSExpr, _CSExpr), not(_CSExpr), truth(Bool)
    case compare(String, String, _CSValue)
    case range(String, _CSValue, _CSValue)
}
enum _CSValue { case string(String, Set<Character>), number(Double), date(Date) }

struct _CSQueryParser {
    enum Token: Equatable { case lparen, rparen, comma, and, or, not, op(String), string(String, String), number(Double), time(String), word(String) }
    struct Failure: Error { let message: String }
    var tokens: [Token] = []
    var i = 0

    static func parse(_ s: String) throws -> _CSExpr {
        var p = _CSQueryParser()
        p.tokens = try tokenize(s)
        guard !p.tokens.isEmpty else { throw Failure(message: "empty query") }
        let e = try p.or()
        guard p.i == p.tokens.count else { throw Failure(message: "unexpected \(p.tokens[p.i])") }
        return e
    }
    static func tokenize(_ s: String) throws -> [Token] {
        var out: [Token] = []
        let c = Array(s)
        var i = 0
        func at(_ k: Int) -> Character? { k < c.count ? c[k] : nil }
        while i < c.count {
            let ch = c[i]
            if ch.isWhitespace { i += 1; continue }
            if ch == "(" { out.append(.lparen); i += 1; continue }
            if ch == ")" { out.append(.rparen); i += 1; continue }
            if ch == "," { out.append(.comma); i += 1; continue }
            if ch == "&", at(i + 1) == "&" { out.append(.and); i += 2; continue }
            if ch == "|", at(i + 1) == "|" { out.append(.or); i += 2; continue }
            if "=!<>".contains(ch) {
                if at(i + 1) == "=" { out.append(.op(String(ch) + "=")); i += 2; continue }
                if ch == "!" { out.append(.not); i += 1; continue }
                if ch == "=" { throw Failure(message: "use == to compare") }
                out.append(.op(String(ch))); i += 1; continue
            }
            if ch == "\"" || ch == "'" {
                var v = "", j = i + 1, closed = false
                while j < c.count {
                    if c[j] == "\\", j + 1 < c.count { v.append(c[j + 1]); j += 2; continue }
                    if c[j] == ch { closed = true; j += 1; break }
                    v.append(c[j]); j += 1
                }
                guard closed else { throw Failure(message: "unterminated string") }
                var mods = ""
                while j < c.count, "cdwtCDWT".contains(c[j]) { mods.append(Character(c[j].lowercased())); j += 1 }
                out.append(.string(v, mods)); i = j; continue
            }
            if ch == "$" {
                var j = i + 1, depth = 0
                while j < c.count {
                    if c[j] == "(" { depth += 1 } else if c[j] == ")" { if depth == 0 { break }; depth -= 1; if depth == 0 { j += 1; break } }
                    else if depth == 0, c[j].isWhitespace || c[j] == "," || c[j] == "&" || c[j] == "|" { break }
                    j += 1
                }
                out.append(.time(String(c[(i + 1)..<j]))); i = j; continue
            }
            if ch.isNumber || (ch == "-" && (at(i + 1)?.isNumber ?? false)) {
                var j = i + 1
                while j < c.count, c[j].isNumber || c[j] == "." || c[j] == "e" || c[j] == "E" { j += 1 }
                guard let d = Double(String(c[i..<j])) else { throw Failure(message: "bad number") }
                out.append(.number(d)); i = j; continue
            }
            if ch.isLetter || ch == "_" || ch == "*" {
                var j = i
                while j < c.count, c[j].isLetter || c[j].isNumber || "_.:*-".contains(c[j]) { j += 1 }
                out.append(.word(String(c[i..<j]))); i = j; continue
            }
            throw Failure(message: "unexpected character \(ch)")
        }
        return out
    }
    mutating func peek() -> Token? { i < tokens.count ? tokens[i] : nil }
    mutating func next() throws -> Token { guard i < tokens.count else { throw Failure(message: "the query ends too early") }; i += 1; return tokens[i - 1] }
    mutating func or() throws -> _CSExpr {
        var e = try and()
        while peek() == .or { i += 1; e = .or(e, try and()) }
        return e
    }
    mutating func and() throws -> _CSExpr {
        var e = try unary()
        while peek() == .and { i += 1; e = .and(e, try unary()) }
        return e
    }
    mutating func unary() throws -> _CSExpr {
        if peek() == .not { i += 1; return .not(try unary()) }
        if peek() == .lparen {
            i += 1
            let e = try or()
            guard try next() == .rparen else { throw Failure(message: "missing )") }
            return e
        }
        guard case .word(let w) = try next() else { throw Failure(message: "expected an attribute") }
        if w.lowercased() == "inrange" {
            guard try next() == .lparen, case .word(let attr) = try next(), try next() == .comma else { throw Failure(message: "InRange(attribute, a, b)") }
            let lo = try value()
            guard try next() == .comma else { throw Failure(message: "InRange(attribute, a, b)") }
            let hi = try value()
            guard try next() == .rparen else { throw Failure(message: "missing )") }
            return .range(attr, lo, hi)
        }
        if w.lowercased() == "true" { return .truth(true) }
        if w.lowercased() == "false" { return .truth(false) }
        guard case .op(let op) = try next() else { throw Failure(message: "expected ==, !=, <, >, <= or >= after \(w)") }
        return .compare(w, op, try value())
    }
    mutating func value() throws -> _CSValue {
        switch try next() {
        case .string(let s, let m): return .string(s, Set(m))
        case .number(let d): return .number(d)
        case .time(let t): return .date(try Self.time(t))
        case .word(let w) where w.lowercased() == "true": return .number(1)
        case .word(let w) where w.lowercased() == "false": return .number(0)
        default: throw Failure(message: "expected a value")
        }
    }
    /// $time.now, today, yesterday, this_week, this_month, this_year (an offset in parentheses), iso(DATE)
    static func time(_ t: String) throws -> Date {
        var name = t, arg: String?
        if let open = t.firstIndex(of: "("), t.hasSuffix(")") {
            name = String(t[..<open]); arg = String(t[t.index(after: open)..<t.index(before: t.endIndex)])
        }
        guard name.hasPrefix("time.") else { throw Failure(message: "unknown $\(t)") }
        name.removeFirst(5)
        let cal = Calendar.current, now = Date()
        let n = Int(arg?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
        func start(_ c: Calendar.Component, _ add: Int) -> Date {
            let base = cal.dateInterval(of: c, for: now)?.start ?? now
            return cal.date(byAdding: c, value: add, to: base) ?? base
        }
        switch name {
        case "now": return now.addingTimeInterval(TimeInterval(n))
        case "today": return start(.day, n)
        case "yesterday": return start(.day, -1 + n)
        case "this_week": return start(.weekOfYear, n)
        case "this_month": return start(.month, n)
        case "this_year": return start(.year, n)
        case "iso":
            let s = arg ?? ""
            let f = ISO8601DateFormatter()
            if let d = f.date(from: s) { return d }
            f.formatOptions = [.withFullDate]
            if let d = f.date(from: s) { return d }
            throw Failure(message: "bad date \(s)")
        default: throw Failure(message: "unknown $\(t)")
        }
    }
}

/// evaluating a query on an indexed item's attributes
enum _CSMatch {
    /// Apple's kMDItem names for the common attributes
    static let mdNames: [String: String] = ["kMDItemTitle": "title", "kMDItemDisplayName": "displayName", "kMDItemDescription": "contentDescription",
        "kMDItemKeywords": "keywords", "kMDItemTextContent": "textContent", "kMDItemContentType": "contentType", "kMDItemAuthors": "authorNames",
        "kMDItemContentCreationDate": "contentCreationDate", "kMDItemContentModificationDate": "contentModificationDate", "kMDItemLastUsedDate": "lastUsedDate",
        "kMDItemStarRating": "rating", "kMDItemPath": "path", "kMDItemURL": "url", "kMDItemSubject": "subject", "kMDItemComment": "comment"]
    static func values(_ name: String, _ e: [String: Any]) -> [Any] {
        let attrs = e["attributes"] as? [String: Any] ?? ["title": e["title"] ?? "", "contentDescription": e["description"] ?? "", "keywords": e["keywords"] ?? []]
        if name == "*" || name == "**" { return attrs.filter { !$0.key.hasPrefix("$") }.values.flatMap(flat) + ((attrs["$custom"] as? [String: Any])?.values.flatMap(flat) ?? []) }
        let key = mdNames[name] ?? name
        if key == "uniqueIdentifier" { return [e["id"] ?? ""] }
        if key == "domainIdentifier" { return [e["domain"] ?? ""] }
        if let v = attrs[key] { return flat(v) }
        if let v = (attrs["$custom"] as? [String: Any])?[key] { return flat(v) }
        return []
    }
    static func flat(_ v: Any) -> [Any] {
        if let a = v as? [Any] { return a.flatMap(flat) }
        if let d = v as? [String: Any] {
            if let u = d["$url"] { return [u] }
            if d["$person"] != nil { return [d["displayName"] ?? "", (d["handles"] as? [String])?.joined(separator: " ") ?? ""] }
            if let l = d["$localized"] as? [String: String] { return Array(l.values) }
            return []
        }
        return [v]
    }
    static func fold(_ s: String, _ m: Set<Character>) -> String {
        var o: String.CompareOptions = []
        if m.contains("c") { o.insert(.caseInsensitive) }
        if m.contains("d") { o.insert(.diacriticInsensitive) }
        return o.isEmpty ? s : s.folding(options: o, locale: nil)
    }
    static func glob(_ pattern: String, _ s: String) -> Bool {
        let p = Array(pattern), t = Array(s)
        var pi = 0, ti = 0, star = -1, mark = 0
        while ti < t.count {
            if pi < p.count, p[pi] == "?" || p[pi] == t[ti] { pi += 1; ti += 1 }
            else if pi < p.count, p[pi] == "*" { star = pi; mark = ti; pi += 1 }
            else if star >= 0 { pi = star + 1; mark += 1; ti = mark }
            else { return false }
        }
        while pi < p.count, p[pi] == "*" { pi += 1 }
        return pi == p.count
    }
    static func matches(_ v: Any, _ pattern: String, _ m: Set<Character>) -> Bool {
        let s = (v as? String) ?? (v as? NSNumber)?.stringValue ?? "\(v)"
        let text = fold(s, m), pat = fold(pattern, m)
        if glob(pat, text) { return true }
        if m.contains("w") || m.contains("t") {               /* word-based: the pattern matches one of the words */
            let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            return words.contains { glob(pat, String($0)) }
        }
        return false
    }
    static func number(_ v: Any) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        if let d = v as? Date { return d.timeIntervalSinceReferenceDate }
        if let s = v as? String { return Double(s) }
        return nil
    }
    static func compare(_ v: Any, _ op: String, _ x: _CSValue) -> Bool {
        let order: ComparisonResult?
        switch x {
        case .string(let p, let m):
            if op == "==" { return matches(v, p, m) }
            if op == "!=" { return !matches(v, p, m) }
            let s = fold((v as? String) ?? "\(v)", m), q = fold(p, m)
            order = s < q ? .orderedAscending : s > q ? .orderedDescending : .orderedSame
        case .number(let n):
            guard let a = number(v) else { return op == "!=" }
            order = a < n ? .orderedAscending : a > n ? .orderedDescending : .orderedSame
        case .date(let d):
            guard let a = (v as? Date)?.timeIntervalSinceReferenceDate ?? number(v) else { return op == "!=" }
            let b = d.timeIntervalSinceReferenceDate
            order = a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
        }
        guard let order else { return false }
        switch op {
        case "==": return order == .orderedSame
        case "!=": return order != .orderedSame
        case "<": return order == .orderedAscending
        case ">": return order == .orderedDescending
        case "<=": return order != .orderedDescending
        case ">=": return order != .orderedAscending
        default: return false
        }
    }
    static func eval(_ x: _CSExpr, _ e: [String: Any]) -> Bool {
        switch x {
        case .and(let a, let b): return eval(a, e) && eval(b, e)
        case .or(let a, let b): return eval(a, e) || eval(b, e)
        case .not(let a): return !eval(a, e)
        case .truth(let t): return t
        case .compare(let name, let op, let v):
            let vs = values(name, e)
            if op == "!=" { return vs.allSatisfy { compare($0, "!=", v) } }
            return vs.contains { compare($0, op, v) }
        case .range(let name, let lo, let hi):
            return values(name, e).contains { compare($0, ">=", lo) && compare($0, "<=", hi) }
        }
    }
}

// MARK: - errors

public struct CSSearchQueryError: Swift.Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable { case unknown = -2000, indexUnreachable = -2001, invalidQuery = -2002, cancelled = -2003 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CSSearchQueryErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var unknown: Code { .unknown }
    public static var indexUnreachable: Code { .indexUnreachable }
    public static var invalidQuery: Code { .invalidQuery }
    public static var cancelled: Code { .cancelled }
}

// MARK: - CSSearchQuery

@objc(CSSearchQueryContext) open class CSSearchQueryContext: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    /// the attributes the found items carry (all of them when empty)
    open var fetchAttributes: [String] = []
    /// more queries every found item must match
    open var filterQueries: [String] = []
    open var keyboardLanguage: String?
    open var sourceOptions: SourceOptions = []
    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        fetchAttributes = coder.decodeObject(forKey: "fetchAttributes") as? [String] ?? []
        filterQueries = coder.decodeObject(forKey: "filterQueries") as? [String] ?? []
        keyboardLanguage = coder.decodeObject(forKey: "keyboardLanguage") as? String
        sourceOptions = SourceOptions(rawValue: UInt(coder.decodeInteger(forKey: "sourceOptions")))
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(fetchAttributes as NSArray, forKey: "fetchAttributes"); coder.encode(filterQueries as NSArray, forKey: "filterQueries")
        coder.encode(keyboardLanguage, forKey: "keyboardLanguage"); coder.encode(Int(sourceOptions.rawValue), forKey: "sourceOptions")
    }
    open func copy(with zone: NSZone? = nil) -> Any {
        let c = CSSearchQueryContext()
        c.fetchAttributes = fetchAttributes; c.filterQueries = filterQueries; c.keyboardLanguage = keyboardLanguage; c.sourceOptions = sourceOptions
        return c
    }
    public struct SourceOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        /// isim: there is no Mail index, so this adds nothing
        public static var allowMail: SourceOptions { SourceOptions(rawValue: 1 << 0) }
    }
}

@objc(CSSearchQuery) open class CSSearchQuery: NSObject, @unchecked Sendable {
    open var foundItemsHandler: (([CSSearchableItem]) -> Void)?
    open var completionHandler: ((Swift.Error?) -> Void)?
    public let queryString: String
    var _context: CSSearchQueryContext?
    open internal(set) var foundItemCount: Int = 0
    open private(set) var isCancelled: Bool = false
    /// kept for the record: isim's files have no data protection
    open var protectionClasses: [FileProtectionType] = []
    let _state = NSLock()
    var _started = false

    @available(iOS, introduced: 9.0, deprecated: 16.0, message: "Use init(queryString:queryContext:) instead")
    public init(queryString: String, attributes: [String]?) {
        self.queryString = queryString
        let c = CSSearchQueryContext(); c.fetchAttributes = attributes ?? []
        _context = c
    }
    @available(iOS 16.0, *)
    public init(queryString: String, queryContext: CSSearchQueryContext?) {
        self.queryString = queryString
        _context = queryContext?.copy() as? CSSearchQueryContext
    }

    /// the app's items (every index of the app) that match
    func _matches() throws -> [CSSearchableItem] {
        let expr: _CSExpr
        do { expr = try _CSQueryParser.parse(queryString) } catch { throw CSSearchQueryError(.invalidQuery) }
        let filters = try (_context?.filterQueries ?? []).map { q -> _CSExpr in
            do { return try _CSQueryParser.parse(q) } catch { throw CSSearchQueryError(.invalidQuery) }
        }
        let entries = (CSSearchableIndex.read()["items"] as? [[String: Any]] ?? []).filter { ($0["kind"] as? String) == "item" }
        let fetch = _context?.fetchAttributes
        return entries.filter { e in _CSMatch.eval(expr, e) && filters.allSatisfy { _CSMatch.eval($0, e) } }.map { CSSearchableItem(_entry: $0, fetch: fetch) }
    }
    /// runs the query: found items in batches, then the end (an error when the query is invalid or was cancelled)
    func _run(found: @escaping ([CSSearchableItem]) -> Void, done: @escaping (Swift.Error?) -> Void) {
        DispatchQueue.global().async { [self] in
            do {
                let items = try _matches()
                NSLog("isim CoreSpotlight: query “%@”: %ld item(s)", queryString, items.count)
                var k = 0
                while k < items.count {
                    if isCancelled { done(CSSearchQueryError(.cancelled)); return }
                    let batch = Array(items[k..<min(k + 32, items.count)])
                    _state.lock(); foundItemCount += batch.count; _state.unlock()
                    found(batch)
                    k += batch.count
                }
                done(isCancelled ? CSSearchQueryError(.cancelled) : nil)
            } catch {
                NSLog("isim CoreSpotlight: query “%@” is not valid", queryString)
                done(error)
            }
        }
    }
    open func start() {
        _state.lock()
        if _started { _state.unlock(); return }
        _started = true
        _state.unlock()
        _run(found: { [weak self] in self?.foundItemsHandler?($0) }, done: { [weak self] in self?.completionHandler?($0) })
    }
    open func cancel() { _state.lock(); isCancelled = true; _state.unlock() }

    /// iOS 18: the found items, as an async sequence (the query starts when it is iterated)
    @available(iOS 18.0, *)
    public var results: Results { Results(query: self) }
    @available(iOS 18.0, *)
    public struct Results: AsyncSequence, Sendable {
        public typealias Element = Item
        public struct Item: Sendable {
            public let item: CSSearchableItem
        }
        let query: CSSearchQuery
        public func makeAsyncIterator() -> Iterator {
            let stream = AsyncThrowingStream<Item, Swift.Error> { k in
                query._run(found: { for i in $0 { k.yield(Item(item: i)) } }, done: { e in k.finish(throwing: e) })
            }
            return Iterator(base: stream.makeAsyncIterator())
        }
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncThrowingStream<Item, Swift.Error>.AsyncIterator
            public mutating func next() async throws -> Item? { try await base.next() }
        }
    }
}

// MARK: - CSUserQuery (iOS 18)

@available(iOS 18.0, *)
@objc(CSSuggestion) open class CSSuggestion: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    public enum SuggestionKind: Int, Sendable { case none = 0, custom = 1, `default` = 2 }
    let _text: String
    let _kind: SuggestionKind
    var _rank: Double
    init(_text: String, kind: SuggestionKind, rank: Double) { self._text = _text; _kind = kind; _rank = rank; super.init() }
    open var localizedAttributedSuggestion: AttributedString { AttributedString(_text) }
    open var suggestionKind: SuggestionKind { _kind }
    open func compare(_ other: CSSuggestion) -> ComparisonResult { _text.localizedStandardCompare(other._text) }
    @objc(compareByRank:) open func compare(byRank other: CSSuggestion) -> ComparisonResult {
        _rank == other._rank ? compare(other) : _rank > other._rank ? .orderedAscending : .orderedDescending
    }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        _text = coder.decodeObject(forKey: "text") as? String ?? ""
        _kind = SuggestionKind(rawValue: coder.decodeInteger(forKey: "kind")) ?? .default
        _rank = coder.decodeDouble(forKey: "rank")
        super.init()
    }
    open func encode(with coder: NSCoder) { coder.encode(_text, forKey: "text"); coder.encode(_kind.rawValue, forKey: "kind"); coder.encode(_rank, forKey: "rank") }
    open func copy(with zone: NSZone? = nil) -> Any { CSSuggestion(_text: _text, kind: _kind, rank: _rank) }
    open override var description: String { "<CSSuggestion “\(_text)”>" }
}

@available(iOS 18.0, *)
@objc(CSUserQueryContext) open class CSUserQueryContext: CSSearchQueryContext, @unchecked Sendable {
    /// the most items (all when 0 or less)
    open var maxResultCount: Int = -1
    /// the most suggestions (none when 0)
    open var maxSuggestionCount: Int = 0
    /// isim: Spotlight's semantic search is not simulated; queries match words either way
    open var disableSemanticSearch: Bool = false
    /// the items come best first, with their rank (compare(byRank:))
    open var enableRankedResults: Bool = false
    /// how many of the first items are ranked (all when 0 or less)
    open var maxRankedResultCount: Int = -1
    var _currentSuggestion: CSSuggestion?
    public override init() { super.init() }
    public convenience init(currentSuggestion: CSSuggestion?) { self.init(); _currentSuggestion = currentSuggestion }
    public required init?(coder: NSCoder) {
        maxResultCount = coder.decodeInteger(forKey: "maxResultCount"); maxSuggestionCount = coder.decodeInteger(forKey: "maxSuggestionCount")
        disableSemanticSearch = coder.decodeBool(forKey: "disableSemanticSearch"); enableRankedResults = coder.decodeBool(forKey: "enableRankedResults")
        maxRankedResultCount = coder.decodeInteger(forKey: "maxRankedResultCount")
        super.init(coder: coder)
    }
    open override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(maxResultCount, forKey: "maxResultCount"); coder.encode(maxSuggestionCount, forKey: "maxSuggestionCount")
        coder.encode(disableSemanticSearch, forKey: "disableSemanticSearch"); coder.encode(enableRankedResults, forKey: "enableRankedResults")
        coder.encode(maxRankedResultCount, forKey: "maxRankedResultCount")
    }
    open override func copy(with zone: NSZone? = nil) -> Any {
        let c = CSUserQueryContext(currentSuggestion: _currentSuggestion)
        c.fetchAttributes = fetchAttributes; c.filterQueries = filterQueries; c.keyboardLanguage = keyboardLanguage; c.sourceOptions = sourceOptions
        c.maxResultCount = maxResultCount; c.maxSuggestionCount = maxSuggestionCount; c.disableSemanticSearch = disableSemanticSearch
        c.enableRankedResults = enableRankedResults; c.maxRankedResultCount = maxRankedResultCount
        return c
    }
}

@available(iOS 18.0, *)
@objc(CSUserQuery) open class CSUserQuery: CSSearchQuery, @unchecked Sendable {
    let _userQueryString: String
    open var foundSuggestionsHandler: (([CSSuggestion]) -> Void)?
    open private(set) var foundSuggestionCount: Int = 0

    public init(userQueryString: String?, userQueryContext: CSUserQueryContext?) {
        _userQueryString = userQueryString ?? ""
        super.init(queryString: "true", queryContext: userQueryContext ?? CSUserQueryContext())
    }
    /// Spotlight's search loads its models ahead of the first query (nothing to load in isim)
    open class func prepare() { NSLog("isim CoreSpotlight: user queries prepared") }
    open class func prepareProtectionClasses(_ protectionClasses: [FileProtectionType]) { prepare() }
    var _user: CSUserQueryContext { _context as? CSUserQueryContext ?? CSUserQueryContext() }

    static func words(_ s: String) -> [String] {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
    /// the items, best first, and the suggestions
    func _search() -> (items: [CSSearchableItem], suggestions: [CSSuggestion]) {
        let text = _user._currentSuggestion?._text ?? _userQueryString
        let query = Self.words(text)
        let entries = (CSSearchableIndex.read()["items"] as? [[String: Any]] ?? []).filter { ($0["kind"] as? String) == "item" }
        let filters = (_context?.filterQueries ?? []).compactMap { try? _CSQueryParser.parse($0) }
        var scored: [(Double, [String: Any])] = []
        var suggestions: [String: Double] = [:]
        for e in entries where filters.allSatisfy({ _CSMatch.eval($0, e) }) {
            let attrs = e["attributes"] as? [String: Any] ?? [:]
            let title = Self.words((attrs["title"] as? String) ?? (attrs["displayName"] as? String) ?? (e["title"] as? String) ?? "")
            let keywords = ((attrs["keywords"] as? [String]) ?? []).flatMap(Self.words)
            let other = _CSMatch.values("*", e).compactMap { $0 as? String }.flatMap(Self.words)
            guard !query.isEmpty else { continue }
            var score = 0.0, all = true
            for (k, q) in query.enumerated() {
                let last = k == query.count - 1
                func hit(_ w: [String]) -> Bool { w.contains { last ? $0.hasPrefix(q) : ($0 == q || $0.hasPrefix(q)) } }
                if hit(title) { score += 3 } else if hit(keywords) { score += 2 } else if hit(other) { score += 1 } else { all = false; break }
            }
            guard all else { continue }
            score += Double((e["engaged"] as? Int) ?? 0) * 2
            if let d = (attrs["lastUsedDate"] ?? attrs["contentModificationDate"]) as? Date { score += max(0, 1 - Date().timeIntervalSince(d) / (30 * 86400)) }
            scored.append((score, e))
            /* suggestions: the title or a keyword that completes what was typed */
            for phrase in [(attrs["title"] as? String) ?? (e["title"] as? String) ?? ""] + ((attrs["keywords"] as? [String]) ?? []) {
                let w = Self.words(phrase)
                if !w.isEmpty, query.allSatisfy({ q in w.contains { $0.hasPrefix(q) } }), phrase.lowercased() != text.lowercased() {
                    suggestions[phrase, default: 0] += score
                }
            }
        }
        var items = scored.map { s, e -> CSSearchableItem in let i = CSSearchableItem(_entry: e, fetch: _context?.fetchAttributes); i._rank = s; return i }
        if _user.enableRankedResults {
            items.sort { $0._rank > $1._rank }
            if _user.maxRankedResultCount > 0 { for (k, i) in items.enumerated() where k >= _user.maxRankedResultCount { i._rank = 0 } }
        }
        if _user.maxResultCount > 0 { items = Array(items.prefix(_user.maxResultCount)) }
        let sugg = suggestions.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(max(0, _user.maxSuggestionCount))
            .map { CSSuggestion(_text: $0.key, kind: .default, rank: $0.value) }
        NSLog("isim CoreSpotlight: user query “%@”: %ld item(s), %ld suggestion(s)", text, items.count, sugg.count)
        return (items, Array(sugg))
    }
    open override func start() {
        _state.lock()
        if _started { _state.unlock(); return }
        _started = true
        _state.unlock()
        DispatchQueue.global().async { [self] in
            let (items, sugg) = _search()
            if isCancelled { completionHandler?(CSSearchQueryError(.cancelled)); return }
            if !sugg.isEmpty { foundSuggestionCount = sugg.count; foundSuggestionsHandler?(sugg) }
            if !items.isEmpty { _state.lock(); foundItemCount = items.count; _state.unlock(); foundItemsHandler?(items) }
            completionHandler?(nil)
        }
    }

    /// what the person did with a result: chosen items rank higher in later searches
    open func userEngaged(_ item: Item, visibleItems: [Item], interaction: UserInteractionKind) {
        let id = item.item.uniqueIdentifier
        if interaction == .select {
            CSSearchableIndex.update { list in
                if let k = list.firstIndex(where: { ($0["kind"] as? String) == "item" && ($0["id"] as? String) == id }) { list[k]["engaged"] = ((list[k]["engaged"] as? Int) ?? 0) + 1 }
            }
        }
        NSLog("isim CoreSpotlight: the user engaged with %@ (%@, %ld visible)", id, interaction == .select ? "select" : "focus", visibleItems.count)
    }
    open func userEngaged(_ suggestion: Suggestion, visibleSuggestions: [Suggestion], interaction: UserInteractionKind) {
        NSLog("isim CoreSpotlight: the user engaged with the suggestion “%@” (%@)", suggestion.suggestion._text, interaction == .select ? "select" : "focus")
    }

    public struct Item: Sendable { public var item: CSSearchableItem }
    public struct Suggestion: Sendable { public var suggestion: CSSuggestion }
    public enum UserInteractionKind: Int, Sendable {
        case select = 0, focus = 1
        public static var `default`: UserInteractionKind { .select }
    }
    /// the found items and suggestions, as an async sequence
    public var responses: Responses { Responses(query: self) }
    public var suggestions: Suggestions { Suggestions(query: self) }
    public struct Responses: AsyncSequence, Sendable {
        public enum Response: Sendable { case item(Item), suggestion(Suggestion) }
        public typealias Element = Response
        let query: CSUserQuery
        public func makeAsyncIterator() -> Iterator {
            let q = query
            let stream = AsyncThrowingStream<Response, Swift.Error> { k in
                DispatchQueue.global().async {
                    let (items, sugg) = q._search()
                    for s in sugg { k.yield(.suggestion(Suggestion(suggestion: s))) }
                    for i in items { k.yield(.item(Item(item: i))) }
                    k.finish(throwing: q.isCancelled ? CSSearchQueryError(.cancelled) : nil)
                }
            }
            return Iterator(base: stream.makeAsyncIterator())
        }
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncThrowingStream<Response, Swift.Error>.AsyncIterator
            public mutating func next() async throws -> Response? { try await base.next() }
        }
    }
    public struct Suggestions: AsyncSequence, Sendable {
        public typealias Element = Suggestion
        let query: CSUserQuery
        public func makeAsyncIterator() -> Iterator {
            let q = query
            let stream = AsyncThrowingStream<Suggestion, Swift.Error> { k in
                DispatchQueue.global().async {
                    for s in q._search().suggestions { k.yield(Suggestion(suggestion: s)) }
                    k.finish(throwing: nil)
                }
            }
            return Iterator(base: stream.makeAsyncIterator())
        }
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncThrowingStream<Suggestion, Swift.Error>.AsyncIterator
            public mutating func next() async throws -> Suggestion? { try await base.next() }
        }
    }
}
