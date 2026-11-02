// isim NetworkExtension (issue #424): NEURLFilterManager (iOS 26), the configuration of a URL filter that answers from a
// private information retrieval (PIR) server through the app's control provider extension. Saved and loaded per app; Swift
// only, like Apple's. Adapted: isim does not filter URLs. An enabled filter whose control provider extension is not in the
// app stops with `.extensionNotFound`; one whose extension is there reports `.running` without filtering anything.
import UIKit

@available(iOS 26.0, *)
public final class NEURLFilterManager: @unchecked Sendable {
    public enum Status: Sendable, Hashable { case invalid, stopped, starting, running, stopping }
    public enum Error: Swift.Error, Sendable, Hashable {
        case configurationCannotBeRemoved, configurationDisabled, configurationInternalError, configurationInvalid,
             configurationNotLoaded, configurationPermissionDenied, configurationStale, configurationUnchanged,
             extensionCancelled, extensionFailedToLoad, extensionNotFound, internalError, invalid, serverSetupIncomplete, unknown
    }
    @available(iOS 27.0, *)
    public enum ReportFormat: Sendable, Hashable { case json, protobuf }
    @available(iOS 27.0, *)
    public struct ParsingConfiguration: Sendable, Hashable {
        public struct DomainOptions: Sendable, Hashable {
            public var excluded: Bool, stripWWW: Bool, levels: UInt, enumerateHierarchy: Bool
            public init(excluded: Bool, stripWWW: Bool, levels: UInt, enumerateHierarchy: Bool) {
                self.excluded = excluded; self.stripWWW = stripWWW; self.levels = levels; self.enumerateHierarchy = enumerateHierarchy
            }
        }
        public struct PathOptions: Sendable, Hashable {
            public var excluded: Bool, segments: UInt, enumerateHierarchy: Bool
            public init(excluded: Bool, segments: UInt, enumerateHierarchy: Bool) {
                self.excluded = excluded; self.segments = segments; self.enumerateHierarchy = enumerateHierarchy
            }
        }
        public struct QueryOptions: Sendable, Hashable {
            public var excluded: Bool, parameters: [String]?
            public init(excluded: Bool, parameters: [String]?) { self.excluded = excluded; self.parameters = parameters }
        }
        public var excludeScheme: Bool
        public var domain: DomainOptions
        public var path: PathOptions
        public var query: QueryOptions
        public var excludeFragment: Bool
        public var excludeIntermediates: Bool
        public var caseSensitive: Bool
        public init(excludeScheme: Bool, domain: DomainOptions, path: PathOptions, query: QueryOptions, excludeFragment: Bool,
                    excludeIntermediates: Bool, caseSensitive: Bool) {
            self.excludeScheme = excludeScheme; self.domain = domain; self.path = path; self.query = query
            self.excludeFragment = excludeFragment; self.excludeIntermediates = excludeIntermediates; self.caseSensitive = caseSensitive
        }
    }

    public static let shared = NEURLFilterManager()
    init() {}

    let lock = NSLock()
    var loaded = false
    public var isEnabled = false
    public var localizedDescription: LocalizedStringResource?
    public var prefilterFetchInterval: TimeInterval = 86400
    public var shouldFailClosed = false
    public private(set) var pirServerURL: URL?
    public private(set) var pirPrivacyPassIssuerURL: URL?
    public private(set) var pirAuthenticationToken: String?
    public private(set) var controlProviderBundleIdentifier: String?
    public var appBundleIdentifier: String? { Bundle.main.bundleIdentifier }
    public private(set) var status: Status = .invalid
    public private(set) var lastDisconnectError: Error?
    var _parsing: [String: Any] = [:]
    var _regex: String?
    var _report: (String?, Int, TimeInterval) = (nil, 0, 0)
    var statusContinuations: [UUID: AsyncStream<Status>.Continuation] = [:]
    var configContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    @available(iOS 27.0, *)
    public var urlParsingRegularExpression: String? { _regex }
    @available(iOS 27.0, *)
    public func setURLParsingRegularExpression(_ expression: String?) throws {
        if let e = expression, (try? NSRegularExpression(pattern: e)) == nil { throw Error.configurationInvalid }
        _regex = expression
    }
    @available(iOS 27.0, *)
    public var urlParsingConfiguration: ParsingConfiguration {
        get {
            let p = _parsing
            return ParsingConfiguration(excludeScheme: p._ne("scheme", false),
                                        domain: .init(excluded: p._ne("domainExcluded", false), stripWWW: p._ne("stripWWW", true),
                                                      levels: UInt(p._ne("levels", 0)), enumerateHierarchy: p._ne("domainHierarchy", true)),
                                        path: .init(excluded: p._ne("pathExcluded", false), segments: UInt(p._ne("segments", 0)),
                                                    enumerateHierarchy: p._ne("pathHierarchy", true)),
                                        query: .init(excluded: p._ne("queryExcluded", true), parameters: p["parameters"] as? [String]),
                                        excludeFragment: p._ne("fragment", true), excludeIntermediates: p._ne("intermediates", false),
                                        caseSensitive: p._ne("caseSensitive", false))
        }
        set {
            var p: [String: Any] = ["scheme": newValue.excludeScheme, "domainExcluded": newValue.domain.excluded, "stripWWW": newValue.domain.stripWWW,
                                    "levels": Int(newValue.domain.levels), "domainHierarchy": newValue.domain.enumerateHierarchy,
                                    "pathExcluded": newValue.path.excluded, "segments": Int(newValue.path.segments),
                                    "pathHierarchy": newValue.path.enumerateHierarchy, "queryExcluded": newValue.query.excluded,
                                    "fragment": newValue.excludeFragment, "intermediates": newValue.excludeIntermediates,
                                    "caseSensitive": newValue.caseSensitive]
            p["parameters"] = newValue.query.parameters
            _parsing = p
        }
    }
    @available(iOS 27.0, *)
    public var reportEndpoint: String? { get { _report.0 } set { _report.0 = newValue } }
    @available(iOS 27.0, *)
    public var reportFormat: ReportFormat { get { _report.1 == 1 ? .protobuf : .json } set { _report.1 = newValue == .protobuf ? 1 : 0 } }
    @available(iOS 27.0, *)
    public var reportInterval: TimeInterval { get { _report.2 } set { _report.2 = newValue } }

    /// the PIR server, its Privacy Pass issuer, the token and the control provider extension that fetches the prefilter
    public func setConfiguration(pirServerURL: URL, pirPrivacyPassIssuerURL: URL?, pirAuthenticationToken: String,
                                 controlProviderBundleIdentifier: String) throws {
        guard pirServerURL.scheme == "https", !pirAuthenticationToken.isEmpty, !controlProviderBundleIdentifier.isEmpty else {
            throw Error.configurationInvalid
        }
        self.pirServerURL = pirServerURL; self.pirPrivacyPassIssuerURL = pirPrivacyPassIssuerURL
        self.pirAuthenticationToken = pirAuthenticationToken; self.controlProviderBundleIdentifier = controlProviderBundleIdentifier
    }

    var plist: [String: Any] {
        var d: [String: Any] = ["enabled": isEnabled, "interval": prefilterFetchInterval, "failClosed": shouldFailClosed, "parsing": _parsing,
                                "reportFormat": _report.1, "reportInterval": _report.2]
        d["server"] = pirServerURL?.absoluteString; d["issuer"] = pirPrivacyPassIssuerURL?.absoluteString
        d["token"] = pirAuthenticationToken; d["provider"] = controlProviderBundleIdentifier
        d["name"] = localizedDescription.map { String(localized: $0) }; d["regex"] = _regex; d["reportEndpoint"] = _report.0
        return d
    }
    func read(_ p: [String: Any]) {
        isEnabled = p._ne("enabled", false); prefilterFetchInterval = p._ne("interval", 86400.0); shouldFailClosed = p._ne("failClosed", false)
        pirServerURL = (p["server"] as? String).flatMap(URL.init(string:)); pirPrivacyPassIssuerURL = (p["issuer"] as? String).flatMap(URL.init(string:))
        pirAuthenticationToken = p["token"] as? String; controlProviderBundleIdentifier = p["provider"] as? String
        localizedDescription = (p["name"] as? String).map { LocalizedStringResource(stringLiteral: $0) }
        _parsing = p["parsing"] as? [String: Any] ?? [:]; _regex = p["regex"] as? String
        _report = (p["reportEndpoint"] as? String, p._ne("reportFormat", 0), p._ne("reportInterval", 0.0))
    }

    /// whether the app contains the control provider extension
    var providerInstalled: Bool {
        guard let id = controlProviderBundleIdentifier else { return false }
        let plugins = (Bundle.main.bundlePath as NSString).appendingPathComponent("PlugIns")
        return ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).contains { name in
            Bundle(path: (plugins as NSString).appendingPathComponent(name))?.bundleIdentifier == id
        }
    }
    func setStatus(_ s: Status, _ error: Error? = nil) {
        lock.lock()
        let changed = s != status
        status = s
        if error != nil || s == .running { lastDisconnectError = error }
        let conts = Array(statusContinuations.values)
        lock.unlock()
        if changed {
            NSLog("isim NetworkExtension: URL filter %@%@", "\(s)", error.map { " (\($0))" } ?? "")
            for c in conts { c.yield(s) }
        }
    }
    func updateStatus() {
        guard loaded else { setStatus(.invalid); return }
        guard isEnabled else { setStatus(.stopped); return }
        setStatus(.starting)
        if providerInstalled { setStatus(.running) } else { setStatus(.stopped, .extensionNotFound) }
    }
    func configChanged() {
        lock.lock(); let conts = Array(configContinuations.values); lock.unlock()
        for c in conts { c.yield(true) }
    }

    public func loadFromPreferences() async throws {
        guard let p = _NE.load("urlfilter").first else { loaded = false; updateStatus(); return }
        read(p)
        loaded = true
        updateStatus()
    }
    public func saveToPreferences() async throws {
        if isEnabled && (pirServerURL == nil || controlProviderBundleIdentifier == nil) { throw Error.configurationInvalid }
        let new = plist
        if loaded, let old = _NE.load("urlfilter").first, NSDictionary(dictionary: old.filter { $0.key != "identifier" }).isEqual(to: new) {
            throw Error.configurationUnchanged
        }
        let ok: Bool = await withCheckedContinuation { k in
            let app = _Privacy.appName
            _Privacy.onMain {
                _NE.permission("NetworkExtension.urlfilter", title: "“\(app)” Would Like to Filter Network Content",
                               message: "This app will be able to filter the websites you visit.") { k.resume(returning: $0) }
            }
        }
        guard ok else { throw Error.configurationPermissionDenied }
        _NE.upsert("urlfilter", "urlfilter", new)
        loaded = true
        NSLog("isim NetworkExtension: saved URL filter configuration (provider %@)", controlProviderBundleIdentifier ?? "-")
        configChanged()
        updateStatus()
    }
    public func removeFromPreferences() async throws {
        guard _NE.remove("urlfilter", "urlfilter") else { throw Error.configurationNotLoaded }
        loaded = false; isEnabled = false
        configChanged()
        updateStatus()
    }
    /// asks the control provider for fresh PIR parameters (isim: none to fetch)
    public func refreshPIRParameters() async throws {
        guard loaded else { throw Error.configurationNotLoaded }
        guard providerInstalled else { throw Error.extensionNotFound }
    }
    public func resetPIRCache() async throws { guard loaded else { throw Error.configurationNotLoaded } }

    public func handleStatusChange() -> any AsyncSequence<Status, Never> {
        let id = UUID()
        let (stream, c) = AsyncStream<Status>.makeStream()
        lock.lock(); statusContinuations[id] = c; lock.unlock()
        c.onTermination = { [weak self] _ in self?.lock.lock(); self?.statusContinuations[id] = nil; self?.lock.unlock() }
        return stream
    }
    public func handleConfigChange() -> any AsyncSequence<Bool, Never> {
        let id = UUID()
        let (stream, c) = AsyncStream<Bool>.makeStream()
        lock.lock(); configContinuations[id] = c; lock.unlock()
        c.onTermination = { [weak self] _ in self?.lock.lock(); self?.configContinuations[id] = nil; self?.lock.unlock() }
        return stream
    }
}
