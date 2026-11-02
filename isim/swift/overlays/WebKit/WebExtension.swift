// isim WebKit (issue #421): web extensions (iOS 18.4). Adapted on WebKitGTK, which has no browser-extension runtime:
// - WKWebExtension reads an extension's manifest.json (manifest versions 2 and 3) from a directory or an app extension
//   bundle: names, versions and the action label (localised from _locales with __MSG_…__), permissions and host
//   permissions, content scripts, icons; problems in its entries are listed in `errors`;
// - WKWebExtension.MatchPattern parses and matches match patterns (<all_urls>, schemes, *.host wildcards, path globs);
// - WKWebExtensionController loads WKWebExtensionContexts; a context keeps the permissions and match patterns the app
//   granted or denied (with expiration dates);
// - a loaded context's content scripts (JavaScript and CSS, run_at, all_frames, matches / exclude_matches) are injected
//   into the controller's web views (WKWebViewConfiguration.webExtensionController) in a content world of their own, on
//   pages the context has access to; they get a small `browser.runtime` (id, getManifest, getURL).
// Not on isim: background pages and service workers, the other `browser.*` APIs (tabs, storage, messaging…), actions,
// commands, tabs and windows, declarative net request rules, data records.
import UIKit

@available(iOS 18.4, *)
@objc(WKWebExtension) open class WKWebExtension: NSObject, @unchecked Sendable {
    public struct Error: Swift.Error, CustomNSError, Hashable, @unchecked Sendable {
        public enum Code: Int, Sendable {
            case unknown = 1, resourceNotFound, invalidResourceCodeSignature, invalidManifest, unsupportedManifestVersion, invalidManifestEntry
            case invalidDeclarativeNetRequestEntry, invalidBackgroundPersistence, invalidArchive
        }
        public let code: Code
        public let userInfo: [String: Any]
        public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
        public static var errorDomain: String { WKWebExtensionErrorDomain }
        public var errorCode: Int { code.rawValue }
        public var errorUserInfo: [String: Any] { userInfo }
        public static func == (a: Error, b: Error) -> Bool { a.code == b.code }
        public func hash(into h: inout Hasher) { h.combine(code) }
        public static var unknown: Code { .unknown }
        public static var resourceNotFound: Code { .resourceNotFound }
        public static var invalidResourceCodeSignature: Code { .invalidResourceCodeSignature }
        public static var invalidManifest: Code { .invalidManifest }
        public static var unsupportedManifestVersion: Code { .unsupportedManifestVersion }
        public static var invalidManifestEntry: Code { .invalidManifestEntry }
        public static var invalidDeclarativeNetRequestEntry: Code { .invalidDeclarativeNetRequestEntry }
        public static var invalidBackgroundPersistence: Code { .invalidBackgroundPersistence }
        public static var invalidArchive: Code { .invalidArchive }
        static func make(_ code: Code, _ message: String) -> Error { Error(code, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    /// an API permission an extension asks for (WKWebExtensionPermission)
    public struct Permission: Hashable, Equatable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let activeTab = Permission("activeTab")
        public static let alarms = Permission("alarms")
        public static let clipboardWrite = Permission("clipboardWrite")
        public static let contextMenus = Permission("contextMenus")
        public static let cookies = Permission("cookies")
        public static let declarativeNetRequest = Permission("declarativeNetRequest")
        public static let declarativeNetRequestFeedback = Permission("declarativeNetRequestFeedback")
        public static let declarativeNetRequestWithHostAccess = Permission("declarativeNetRequestWithHostAccess")
        public static let menus = Permission("menus")
        public static let nativeMessaging = Permission("nativeMessaging")
        public static let scripting = Permission("scripting")
        public static let storage = Permission("storage")
        public static let tabs = Permission("tabs")
        public static let unlimitedStorage = Permission("unlimitedStorage")
        public static let webNavigation = Permission("webNavigation")
        public static let webRequest = Permission("webRequest")
    }

    /// a content script from the manifest
    struct ContentScript {
        var js: [String], css: [String], matches: [MatchPattern], excludes: [MatchPattern], runAt: String, allFrames: Bool
    }

    let _base: URL
    @objc open private(set) var manifest: [String: Any]
    @objc open private(set) var manifestVersion: Double
    @objc open private(set) var defaultLocale: Locale?
    @objc open private(set) var displayName: String?
    @objc open private(set) var displayShortName: String?
    @objc open private(set) var displayVersion: String?
    @objc open private(set) var displayDescription: String?
    @objc open private(set) var displayActionLabel: String?
    @objc open private(set) var version: String?
    var _errors: [Swift.Error] = []
    open var errors: [any Swift.Error] { _errors }
    open private(set) var requestedPermissions: Set<Permission> = []
    open private(set) var optionalPermissions: Set<Permission> = []
    open private(set) var requestedPermissionMatchPatterns: Set<MatchPattern> = []
    open private(set) var optionalPermissionMatchPatterns: Set<MatchPattern> = []
    open private(set) var allRequestedMatchPatterns: Set<MatchPattern> = []
    var _contentScripts: [ContentScript] = []

    /// the extension in a directory with its manifest.json (iOS: also the resources of a Safari web extension)
    public convenience init(resourceBaseURL: URL) async throws {
        try self.init(_base: resourceBaseURL)
    }
    /// a Safari web extension's app extension bundle (its resources)
    public convenience init(appExtensionBundle: Bundle) async throws {
        try self.init(_base: appExtensionBundle.resourceURL ?? appExtensionBundle.bundleURL)
    }
    /// Objective-C: +extensionWithResourceBaseURL:completionHandler:
    @objc(extensionWithResourceBaseURL:completionHandler:)
    open class func _objc_extension(resourceBaseURL: URL, completionHandler: @escaping (WKWebExtension?, NSError?) -> Void) {
        do { completionHandler(try WKWebExtension(_base: resourceBaseURL), nil) } catch { completionHandler(nil, error as NSError) }
    }
    @objc(extensionWithAppExtensionBundle:completionHandler:)
    open class func _objc_extension(appExtensionBundle: Bundle, completionHandler: @escaping (WKWebExtension?, NSError?) -> Void) {
        do { completionHandler(try WKWebExtension(_base: appExtensionBundle.resourceURL ?? appExtensionBundle.bundleURL), nil) }
        catch { completionHandler(nil, error as NSError) }
    }

    init(_base base: URL) throws {
        _base = base
        let file = base.appendingPathComponent("manifest.json")
        guard let data = FileManager.default.contents(atPath: file.path) else {
            throw Error.make(.resourceNotFound, "Unable to find \"manifest.json\" in the extension’s resources.")
        }
        guard let m = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw Error.make(.invalidManifest, "Unable to parse manifest because of an unexpected format.")
        }
        manifest = m
        manifestVersion = (m["manifest_version"] as? NSNumber)?.doubleValue ?? 0
        super.init()
        guard supportsManifestVersion(manifestVersion) else {
            throw Error.make(.unsupportedManifestVersion, "An unsupported `manifest_version` was specified.")
        }
        _parse()
    }

    // Objective-C: the sets and lists as Foundation collections (permissions are NSStrings there)
    @objc(errors) var _objc_errors: [NSError] { _errors.map { $0 as NSError } }
    @objc(requestedPermissions) var _objc_requestedPermissions: Set<String> { Set(requestedPermissions.map(\.rawValue)) }
    @objc(optionalPermissions) var _objc_optionalPermissions: Set<String> { Set(optionalPermissions.map(\.rawValue)) }
    @objc(requestedPermissionMatchPatterns) var _objc_requestedPatterns: Set<MatchPattern> { requestedPermissionMatchPatterns }
    @objc(optionalPermissionMatchPatterns) var _objc_optionalPatterns: Set<MatchPattern> { optionalPermissionMatchPatterns }
    @objc(allRequestedMatchPatterns) var _objc_allPatterns: Set<MatchPattern> { allRequestedMatchPatterns }

    @objc(supportsManifestVersion:) open func supportsManifestVersion(_ manifestVersion: Double) -> Bool { manifestVersion == 2 || manifestVersion == 3 }

    // MARK: manifest
    private var _messages: [String: String] = [:]
    func _localized(_ s: String?) -> String? {
        guard var s else { return nil }
        while let r = s.range(of: "__MSG_"), let end = s.range(of: "__", range: r.upperBound..<s.endIndex) {
            let key = String(s[r.upperBound..<end.lowerBound]).lowercased()
            s.replaceSubrange(r.lowerBound..<end.upperBound, with: _messages[key] ?? "")
        }
        return s
    }
    private func _loadMessages() {
        guard let loc = manifest["default_locale"] as? String else { return }
        defaultLocale = Locale(identifier: loc)
        var tried: [String] = []
        let pref = Locale.preferredLanguages.first.map { $0.replacingOccurrences(of: "-", with: "_") }
        for l in [pref, pref.map { String($0.prefix(2)) }, loc].compactMap({ $0 }) where !tried.contains(l) {
            tried.append(l)
            let u = _base.appendingPathComponent("_locales/\(l)/messages.json")
            guard let d = FileManager.default.contents(atPath: u.path), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            for (k, v) in o where _messages[k.lowercased()] == nil { if let msg = (v as? [String: Any])?["message"] as? String { _messages[k.lowercased()] = msg } }
        }
    }
    private func _entryError(_ message: String) { _errors.append(Error.make(.invalidManifestEntry, message)) }
    private func _patterns(_ list: Any?, key: String) -> Set<MatchPattern> {
        var out: Set<MatchPattern> = []
        for case let s as String in (list as? [Any] ?? []) where MatchPattern._looksLikePattern(s) {
            if let p = try? MatchPattern(string: s) { out.insert(p) } else { _entryError("Unable to parse `\(key)` pattern \"\(s)\".") }
        }
        return out
    }
    private func _parse() {
        _loadMessages()
        displayName = _localized(manifest["name"] as? String)
        if displayName?.isEmpty ?? true { _entryError("Missing required `name` manifest entry.") }
        displayShortName = _localized(manifest["short_name"] as? String) ?? displayName
        version = manifest["version"] as? String
        if version == nil { _entryError("Missing required `version` manifest entry.") }
        displayVersion = (manifest["version_name"] as? String) ?? version
        displayDescription = _localized(manifest["description"] as? String)
        let action = (manifest[manifestVersion >= 3 ? "action" : "browser_action"] ?? manifest["page_action"]) as? [String: Any]
        displayActionLabel = _localized(action?["default_title"] as? String)
        let perms = (manifest["permissions"] as? [Any] ?? []).compactMap { $0 as? String }
        let optional = (manifest["optional_permissions"] as? [Any] ?? []).compactMap { $0 as? String }
        requestedPermissions = Set(perms.filter { !MatchPattern._looksLikePattern($0) }.map { Permission($0) })
        optionalPermissions = Set(optional.filter { !MatchPattern._looksLikePattern($0) }.map { Permission($0) })
        if manifestVersion >= 3 {
            requestedPermissionMatchPatterns = _patterns(manifest["host_permissions"], key: "host_permissions")
            optionalPermissionMatchPatterns = _patterns(manifest["optional_host_permissions"], key: "optional_host_permissions")
        } else {
            requestedPermissionMatchPatterns = _patterns(perms, key: "permissions")
            optionalPermissionMatchPatterns = _patterns(optional, key: "optional_permissions")
        }
        var all = requestedPermissionMatchPatterns
        for case let cs as [String: Any] in (manifest["content_scripts"] as? [Any] ?? []) {
            let matches = _patterns(cs["matches"], key: "content_scripts.matches")
            if matches.isEmpty { _entryError("Missing `matches` for a `content_scripts` entry."); continue }
            all.formUnion(matches)
            _contentScripts.append(ContentScript(js: cs["js"] as? [String] ?? [], css: cs["css"] as? [String] ?? [], matches: Array(matches),
                                                 excludes: Array(_patterns(cs["exclude_matches"], key: "content_scripts.exclude_matches")),
                                                 runAt: cs["run_at"] as? String ?? "document_idle", allFrames: cs["all_frames"] as? Bool ?? false))
        }
        allRequestedMatchPatterns = all
        if manifestVersion >= 3, let bg = manifest["background"] as? [String: Any], bg["persistent"] as? Bool == true {
            _errors.append(Error.make(.invalidBackgroundPersistence, "Invalid `persistent` manifest entry. A `manifest_version` greater-than or equal to `3` must be non-persistent."))
        }
    }

    @objc open var hasBackgroundContent: Bool { manifest["background"] is [String: Any] }
    @objc open var hasPersistentBackgroundContent: Bool {
        guard manifestVersion < 3, let bg = manifest["background"] as? [String: Any] else { return false }
        return bg["persistent"] as? Bool ?? true
    }
    @objc open var hasInjectedContent: Bool { !_contentScripts.isEmpty }
    @objc open var hasOptionsPage: Bool { manifest["options_page"] is String || (manifest["options_ui"] as? [String: Any])?["page"] is String }
    @objc open var hasOverrideNewTabPage: Bool { (manifest["chrome_url_overrides"] as? [String: Any])?["newtab"] is String }
    @objc open var hasCommands: Bool { !((manifest["commands"] as? [String: Any]) ?? [:]).isEmpty }
    @objc open var hasContentModificationRules: Bool {
        !(((manifest["declarative_net_request"] as? [String: Any])?["rule_resources"] as? [Any]) ?? []).isEmpty
    }
    var _optionsPage: String? { (manifest["options_page"] as? String) ?? (manifest["options_ui"] as? [String: Any])?["page"] as? String }
    var _newTabPage: String? { (manifest["chrome_url_overrides"] as? [String: Any])?["newtab"] as? String }

    // MARK: icons
    private func _icon(_ entry: Any?, _ size: CGSize) -> UIImage? {
        let paths: [(Int, String)]
        if let s = entry as? String { paths = [(0, s)] }
        else if let d = entry as? [String: Any] { paths = d.compactMap { k, v in (v as? String).map { (Int(k) ?? 0, $0) } }.sorted { $0.0 < $1.0 } }
        else { return nil }
        let want = Int((max(size.width, size.height) * UIScreen.main.scale).rounded(.up))
        guard let best = paths.first(where: { $0.0 >= want }) ?? paths.last else { return nil }
        return UIImage(contentsOfFile: _base.appendingPathComponent(best.1).path)
    }
    @objc(iconForSize:) open func icon(for size: CGSize) -> UIImage? { _icon(manifest["icons"], size) }
    @objc(actionIconForSize:) open func actionIcon(for size: CGSize) -> UIImage? {
        let action = (manifest[manifestVersion >= 3 ? "action" : "browser_action"] ?? manifest["page_action"]) as? [String: Any]
        return _icon(action?["default_icon"], size) ?? icon(for: size)
    }
    /// the manifest as JSON with its __MSG_…__ placeholders localised (browser.runtime.getManifest())
    var _localizedManifestJSON: String {
        let json = (try? JSONSerialization.data(withJSONObject: manifest)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        guard json.contains("__MSG_") else { return json }
        let localized = _localized(json) ?? json
        return (try? JSONSerialization.jsonObject(with: Data(localized.utf8))) != nil ? localized : json
    }
    func _resource(_ path: String) -> String? {
        guard let d = FileManager.default.contents(atPath: _base.appendingPathComponent(path).path) else { return nil }
        return String(data: d, encoding: .utf8)
    }
}

public let WKWebExtensionErrorDomain = "WKWebExtensionErrorDomain"
public let WKWebExtensionMatchPatternErrorDomain = "WKWebExtensionMatchPatternErrorDomain"
public let WKWebExtensionContextErrorDomain = "WKWebExtensionContextErrorDomain"

// MARK: - match patterns

@available(iOS 18.4, *)
extension WKWebExtension {
    @objc(WKWebExtensionMatchPattern) open class MatchPattern: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
        public struct Error: Swift.Error, CustomNSError, Hashable, @unchecked Sendable {
            public enum Code: Int, Sendable { case unknown = 1, invalidScheme, invalidHost, invalidPath }
            public let code: Code
            public let userInfo: [String: Any]
            public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
            public static var errorDomain: String { WKWebExtensionMatchPatternErrorDomain }
            public var errorCode: Int { code.rawValue }
            public var errorUserInfo: [String: Any] { userInfo }
            public static func == (a: Error, b: Error) -> Bool { a.code == b.code }
            public func hash(into h: inout Hasher) { h.combine(code) }
            public static var unknown: Code { .unknown }
            public static var invalidScheme: Code { .invalidScheme }
            public static var invalidHost: Code { .invalidHost }
            public static var invalidPath: Code { .invalidPath }
        }
        public struct Options: OptionSet, Sendable {
            public let rawValue: UInt
            public init(rawValue: UInt) { self.rawValue = rawValue }
            public static let ignoreSchemes = Options(rawValue: 1 << 0)
            public static let ignorePaths = Options(rawValue: 1 << 1)
            public static let matchBidirectionally = Options(rawValue: 1 << 2)
        }

        nonisolated(unsafe) static var _customSchemes: Set<String> = []
        static let _schemes: Set<String> = ["*", "http", "https", "file", "ftp", "data", "about", "webkit-extension"]
        @objc open private(set) var string: String
        @objc open private(set) var scheme: String?
        @objc open private(set) var host: String?
        @objc open private(set) var path: String?
        @objc open var matchesAllURLs: Bool { string == "<all_urls>" }
        @objc open var matchesAllHosts: Bool { matchesAllURLs || host == "*" }

        @objc(registerCustomURLScheme:) open class func registerCustomURLScheme(_ urlScheme: String) { _customSchemes.insert(urlScheme.lowercased()) }
        @objc(allURLsMatchPattern) open class func allURLs() -> Self { try! Self(string: "<all_urls>") }
        @objc(allHostsAndSchemesMatchPattern) open class func allHostsAndSchemes() -> Self { try! Self(string: "*://*/*") }

        static func _looksLikePattern(_ s: String) -> Bool { s == "<all_urls>" || s.contains("://") }

        @objc(initWithString:error:) public required init(string: String) throws {
            self.string = string
            super.init()
            guard string != "<all_urls>" else { return }
            guard let sep = string.range(of: "://") else {
                throw Error(.invalidScheme, userInfo: [NSLocalizedDescriptionKey: "\"\(string)\" cannot be parsed because it doesn't have a scheme."])
            }
            let sc = string[..<sep.lowerBound].lowercased()
            guard Self._schemes.contains(sc) || Self._customSchemes.contains(sc) else {
                throw Error(.invalidScheme, userInfo: [NSLocalizedDescriptionKey: "\"\(string)\" cannot be parsed because the scheme \"\(sc)\" is invalid."])
            }
            let rest = string[sep.upperBound...]
            let slash = rest.firstIndex(of: "/")
            let h = String(slash.map { rest[..<$0] } ?? rest[...])
            guard let slash else {
                throw Error(.invalidPath, userInfo: [NSLocalizedDescriptionKey: "\"\(string)\" cannot be parsed because it doesn't have a path."])
            }
            if sc != "file" {
                guard !h.isEmpty, h == "*" || !h.dropFirst(h.hasPrefix("*.") ? 2 : 0).contains("*") else {
                    throw Error(.invalidHost, userInfo: [NSLocalizedDescriptionKey: "\"\(string)\" cannot be parsed because the host \"\(h)\" is invalid."])
                }
            }
            scheme = sc; host = h.lowercased(); path = String(rest[slash...])
        }
        @objc(initWithScheme:host:path:error:) public convenience init(scheme: String, host: String, path: String) throws {
            try self.init(string: "\(scheme)://\(host)\(path)")
        }
        public static var supportsSecureCoding: Bool { true }
        public func encode(with coder: NSCoder) { coder.encode(string, forKey: "string") }
        public required convenience init?(coder: NSCoder) {
            guard let s = coder.decodeObject(of: NSString.self, forKey: "string") as String?, (try? MatchPattern(string: s)) != nil else { return nil }
            try? self.init(string: s)
        }
        public func copy(with zone: OpaquePointer? = nil) -> Any { self }
        open override var description: String { string }
        open override func isEqual(_ object: Any?) -> Bool { (object as? MatchPattern)?.string == string }
        open override var hash: Int { string.hashValue }

        static func _glob(_ g: String) -> String {
            "^" + g.map { $0 == "*" ? ".*" : NSRegularExpression.escapedPattern(for: String($0)) }.joined() + "$"
        }
        /// a JavaScript RegExp source matching the same URLs (content scripts)
        var _regex: String {
            if matchesAllURLs { return "^(https?|file|ftp|data|about)://" }
            let sc = scheme == "*" ? "https?" : NSRegularExpression.escapedPattern(for: scheme ?? "")
            let h: String
            if host == "*" { h = "[^/]*" }
            else if let host, host.hasPrefix("*.") { h = "(?:[^/]*\\.)?" + NSRegularExpression.escapedPattern(for: String(host.dropFirst(2))) + "(?::\\d+)?" }
            else { h = NSRegularExpression.escapedPattern(for: host ?? "") + "(?::\\d+)?" }
            let p = Self._glob(path ?? "/*").dropFirst()
            return "^" + sc + "://" + h + p
        }
        func _matchesHost(_ h: String) -> Bool {
            guard let host else { return true }
            if host == "*" { return true }
            if host.hasPrefix("*.") { let base = String(host.dropFirst(2)); return h == base || h.hasSuffix("." + base) }
            return h == host
        }

        @objc(matchesURL:) open func matches(_ url: URL?) -> Bool { matches(url, options: []) }
        @objc(matchesURL:options:) func _objc_matches(_ url: URL?, options: UInt) -> Bool { matches(url, options: Options(rawValue: options)) }
        open func matches(_ url: URL?, options: Options) -> Bool {
            guard let url, let urlScheme = url.scheme?.lowercased() else { return false }
            if matchesAllURLs { return ["http", "https", "file", "ftp", "data", "about"].contains(urlScheme) || Self._customSchemes.contains(urlScheme) }
            if !options.contains(.ignoreSchemes) {
                if scheme == "*" { if !["http", "https"].contains(urlScheme) { return false } } else if scheme != urlScheme { return false }
            }
            if scheme != "file", !_matchesHost((url.host ?? "").lowercased()) { return false }
            if !options.contains(.ignorePaths) {
                var p = url.path.isEmpty ? "/" : url.path
                if let q = url.query { p += "?" + q }
                if p.range(of: Self._glob(path ?? "/*"), options: .regularExpression) == nil { return false }
            }
            return true
        }
        @objc(matchesPattern:) open func matches(_ pattern: MatchPattern?) -> Bool { matches(pattern, options: []) }
        @objc(matchesPattern:options:) func _objc_matches(_ pattern: MatchPattern?, options: UInt) -> Bool { matches(pattern, options: Options(rawValue: options)) }
        open func matches(_ pattern: MatchPattern?, options: Options) -> Bool {
            guard let pattern else { return false }
            if matchesAllURLs { return true }
            if pattern.matchesAllURLs { return options.contains(.matchBidirectionally) && pattern.matches(self, options: options.subtracting(.matchBidirectionally)) }
            let schemeOK = options.contains(.ignoreSchemes) || scheme == pattern.scheme || (scheme == "*" && ["http", "https", "*"].contains(pattern.scheme ?? ""))
            let hostOK = pattern.host.map { ph in ph.hasPrefix("*.") ? (host == "*" || host == ph) : _matchesHost(ph) } ?? true
            let pathOK = options.contains(.ignorePaths) || (pattern.path ?? "").range(of: Self._glob(path ?? "/*"), options: .regularExpression) != nil
            if schemeOK && hostOK && pathOK { return true }
            return options.contains(.matchBidirectionally) && pattern.matches(self, options: options.subtracting(.matchBidirectionally))
        }
    }
}

// MARK: - controller and contexts

@available(iOS 18.4, *)
@MainActor @objc(WKWebExtensionController) open class WKWebExtensionController: NSObject, @unchecked Sendable {
    @objc(WKWebExtensionControllerConfiguration) open class Configuration: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
        @objc open private(set) var identifier: UUID?
        @objc open private(set) var isPersistent: Bool
        nonisolated(unsafe) var _webViewConfiguration: WKWebViewConfiguration?
        nonisolated(unsafe) var _store: WKWebsiteDataStore?
        @MainActor @objc open var webViewConfiguration: WKWebViewConfiguration! {
            get { (_webViewConfiguration?.copy() as? WKWebViewConfiguration) ?? WKWebViewConfiguration() } set { _webViewConfiguration = newValue }
        }
        @MainActor @objc open var defaultWebsiteDataStore: WKWebsiteDataStore! {
            get { _store ?? (isPersistent ? .default() : .nonPersistent()) } set { _store = newValue }
        }
        @objc(defaultConfiguration) open class func `default`() -> Self { Self(_identifier: nil, persistent: true) }
        @objc(nonPersistentConfiguration) open class func nonPersistent() -> Self { Self(_identifier: nil, persistent: false) }
        @objc(configurationWithIdentifier:) public convenience init(identifier: UUID) { self.init(_identifier: identifier, persistent: true) }
        @objc(_isimInitWithIdentifier:persistent:) public required init(_identifier identifier: UUID?, persistent: Bool) { self.identifier = identifier; isPersistent = persistent }
        public static var supportsSecureCoding: Bool { true }
        public func encode(with coder: NSCoder) { coder.encode(identifier, forKey: "identifier"); coder.encode(isPersistent, forKey: "persistent") }
        public required convenience init?(coder: NSCoder) {
            self.init(_identifier: coder.decodeObject(of: NSUUID.self, forKey: "identifier") as UUID?, persistent: coder.decodeBool(forKey: "persistent"))
        }
        public func copy(with zone: OpaquePointer? = nil) -> Any {
            let c = Self(_identifier: identifier, persistent: isPersistent)
            c._webViewConfiguration = _webViewConfiguration; c._store = _store
            return c
        }
    }

    @objc open private(set) var configuration: Configuration
    var _contexts: [WKWebExtensionContext] = []
    var _webViews: [_WKWeakView] = []
    @objc public convenience override init() { self.init(configuration: .default()) }
    @objc(initWithConfiguration:) public init(configuration: Configuration) { self.configuration = configuration.copy() as! Configuration; super.init() }

    @objc open var extensionContexts: Set<WKWebExtensionContext> { Set(_contexts) }
    @objc open var extensions: Set<WKWebExtension> { Set(_contexts.map(\.webExtension)) }
    @objc(extensionContextForExtension:) open func extensionContext(for extension: WKWebExtension) -> WKWebExtensionContext? {
        _contexts.first { $0.webExtension === `extension` }
    }
    @objc(extensionContextForURL:) open func extensionContext(for url: URL) -> WKWebExtensionContext? {
        _contexts.first { $0.baseURL.scheme == url.scheme && $0.baseURL.host == url.host }
    }
    @objc(loadExtensionContext:error:) open func load(_ extensionContext: WKWebExtensionContext) throws {
        if extensionContext.isLoaded { throw WKWebExtensionContext.Error(.alreadyLoaded, userInfo: [NSLocalizedDescriptionKey: "Extension context is already loaded."]) }
        if _contexts.contains(where: { $0.baseURL == extensionContext.baseURL }) {
            throw WKWebExtensionContext.Error(.baseURLAlreadyInUse, userInfo: [NSLocalizedDescriptionKey: "Another extension context is loaded with the same base URL."])
        }
        _contexts.append(extensionContext)
        extensionContext._controller = self
        NSLog("isim: loaded web extension %@ (%d content scripts)", extensionContext.webExtension.displayName ?? "-", extensionContext.webExtension._contentScripts.count)
        _refreshWebViews()
    }
    @objc(unloadExtensionContext:error:) open func unload(_ extensionContext: WKWebExtensionContext) throws {
        guard let i = _contexts.firstIndex(where: { $0 === extensionContext }) else {
            throw WKWebExtensionContext.Error(.notLoaded, userInfo: [NSLocalizedDescriptionKey: "Extension context is not loaded."])
        }
        _contexts.remove(at: i)
        extensionContext._controller = nil
        _refreshWebViews()
    }
    func _attach(_ w: WKWebView) { _webViews.removeAll { $0.view == nil || $0.view === w }; _webViews.append(_WKWeakView(w)) }
    func _refreshWebViews() { for w in _webViews.compactMap(\.view) { w._reinstallScripts() } }
    /// the content scripts of the loaded contexts, guarded by their match patterns and the access each context has
    func _userScripts() -> [WKUserScript] { _contexts.flatMap { $0._userScripts() } }
}

@available(iOS 18.4, *)
@MainActor @objc(WKWebExtensionContext) open class WKWebExtensionContext: NSObject, @unchecked Sendable {
    public struct Error: Swift.Error, CustomNSError, Hashable, @unchecked Sendable {
        public enum Code: Int, Sendable { case unknown = 1, alreadyLoaded, notLoaded, baseURLAlreadyInUse, noBackgroundContent, backgroundContentFailedToLoad }
        public let code: Code
        public let userInfo: [String: Any]
        public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
        public static var errorDomain: String { WKWebExtensionContextErrorDomain }
        public var errorCode: Int { code.rawValue }
        public var errorUserInfo: [String: Any] { userInfo }
        public static func == (a: Error, b: Error) -> Bool { a.code == b.code }
        public func hash(into h: inout Hasher) { h.combine(code) }
        public static var unknown: Code { .unknown }
        public static var alreadyLoaded: Code { .alreadyLoaded }
        public static var notLoaded: Code { .notLoaded }
        public static var baseURLAlreadyInUse: Code { .baseURLAlreadyInUse }
        public static var noBackgroundContent: Code { .noBackgroundContent }
        public static var backgroundContentFailedToLoad: Code { .backgroundContentFailedToLoad }
    }
    @objc(WKWebExtensionContextPermissionStatus) public enum PermissionStatus: Int, Sendable {
        case deniedExplicitly = -3, deniedImplicitly = -2, requestedImplicitly = -1, unknown = 0, requestedExplicitly = 1, grantedImplicitly = 2, grantedExplicitly = 3
    }
    public struct NotificationUserInfoKey: Hashable, Equatable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let permissions = NotificationUserInfoKey("permissions")
        public static let matchPatterns = NotificationUserInfoKey("matchPatterns")
    }

    @objc open private(set) var webExtension: WKWebExtension
    weak var _controller: WKWebExtensionController?
    @objc open var webExtensionController: WKWebExtensionController? { _controller }
    @objc open var isLoaded: Bool { _controller != nil }
    @objc open var uniqueIdentifier: String { didSet { baseURL = URL(string: "webkit-extension://\(uniqueIdentifier)/")! } }
    @objc open var baseURL: URL
    @objc open var isInspectable = false
    @objc open var inspectionName: String?
    @objc open var unsupportedAPIs: Set<String>! = []
    @objc open var hasAccessToPrivateData = false
    open var errors: [any Swift.Error] { webExtension.errors }
    open var grantedPermissions: [WKWebExtension.Permission: Date] = [:]
    open var deniedPermissions: [WKWebExtension.Permission: Date] = [:]
    open var grantedPermissionMatchPatterns: [WKWebExtension.MatchPattern: Date] = [:] { didSet { _controller?._refreshWebViews() } }
    open var deniedPermissionMatchPatterns: [WKWebExtension.MatchPattern: Date] = [:] { didSet { _controller?._refreshWebViews() } }

    @objc(initForExtension:) public init(for extension: WKWebExtension) {
        webExtension = `extension`
        let id = UUID().uuidString
        uniqueIdentifier = id
        baseURL = URL(string: "webkit-extension://\(id)/")!
        super.init()
    }
    public convenience init(forExtension extension: WKWebExtension) { self.init(for: `extension`) }
    @objc(contextForExtension:) open class func _objc_context(for extension: WKWebExtension) -> WKWebExtensionContext { WKWebExtensionContext(for: `extension`) }

    @objc open var webViewConfiguration: WKWebViewConfiguration? {
        guard let c = _controller else { return nil }
        let w = c.configuration.webViewConfiguration ?? WKWebViewConfiguration()
        w.webExtensionController = c
        return w
    }
    @objc open var optionsPageURL: URL? { webExtension._optionsPage.map { baseURL.appendingPathComponent($0) } }
    @objc open var overrideNewTabPageURL: URL? { webExtension._newTabPage.map { baseURL.appendingPathComponent($0) } }

    // Objective-C: permissions are NSStrings
    @objc(errors) var _objc_errors: [NSError] { webExtension._objc_errors }
    @objc(grantedPermissions) var _objc_granted: [String: Date] {
        get { Dictionary(uniqueKeysWithValues: grantedPermissions.map { ($0.key.rawValue, $0.value) }) }
        set { grantedPermissions = Dictionary(uniqueKeysWithValues: newValue.map { (WKWebExtension.Permission($0.key), $0.value) }) }
    }
    @objc(deniedPermissions) var _objc_denied: [String: Date] {
        get { Dictionary(uniqueKeysWithValues: deniedPermissions.map { ($0.key.rawValue, $0.value) }) }
        set { deniedPermissions = Dictionary(uniqueKeysWithValues: newValue.map { (WKWebExtension.Permission($0.key), $0.value) }) }
    }
    @objc(grantedPermissionMatchPatterns) var _objc_grantedPatterns: [WKWebExtension.MatchPattern: Date] {
        get { grantedPermissionMatchPatterns } set { grantedPermissionMatchPatterns = newValue }
    }
    @objc(deniedPermissionMatchPatterns) var _objc_deniedPatterns: [WKWebExtension.MatchPattern: Date] {
        get { deniedPermissionMatchPatterns } set { deniedPermissionMatchPatterns = newValue }
    }
    @objc(currentPermissions) var _objc_current: Set<String> { Set(currentPermissions.map(\.rawValue)) }
    @objc(currentPermissionMatchPatterns) var _objc_currentPatterns: Set<WKWebExtension.MatchPattern> { currentPermissionMatchPatterns }

    // MARK: permissions
    private func _live<K>(_ d: [K: Date]) -> [K] { let now = Date(); return d.filter { $0.value > now }.map(\.key) }
    open var currentPermissions: Set<WKWebExtension.Permission> { Set(_live(grantedPermissions)) }
    open var currentPermissionMatchPatterns: Set<WKWebExtension.MatchPattern> { Set(_live(grantedPermissionMatchPatterns)) }
    @objc open var hasAccessToAllURLs: Bool { currentPermissionMatchPatterns.contains { $0.matchesAllURLs } }
    @objc open var hasAccessToAllHosts: Bool { currentPermissionMatchPatterns.contains { $0.matchesAllHosts } }
    @objc open var hasRequestedOptionalAccessToAllHosts: Bool { webExtension.optionalPermissionMatchPatterns.contains { $0.matchesAllHosts } }
    @objc open var hasInjectedContent: Bool { webExtension.hasInjectedContent }
    @objc open var hasContentModificationRules: Bool { webExtension.hasContentModificationRules }

    open func permissionStatus(for permission: WKWebExtension.Permission) -> PermissionStatus {
        if _live(deniedPermissions).contains(permission) { return .deniedExplicitly }
        if _live(grantedPermissions).contains(permission) { return .grantedExplicitly }
        if webExtension.requestedPermissions.contains(permission) || webExtension.optionalPermissions.contains(permission) { return .requestedExplicitly }
        return .unknown
    }
    open func permissionStatus(for pattern: WKWebExtension.MatchPattern) -> PermissionStatus {
        if _live(deniedPermissionMatchPatterns).contains(where: { $0.matches(pattern, options: .matchBidirectionally) }) { return .deniedExplicitly }
        if _live(grantedPermissionMatchPatterns).contains(pattern) { return .grantedExplicitly }
        if _live(grantedPermissionMatchPatterns).contains(where: { $0.matches(pattern) }) { return .grantedImplicitly }
        if webExtension.requestedPermissionMatchPatterns.contains(pattern) || webExtension.optionalPermissionMatchPatterns.contains(pattern) { return .requestedExplicitly }
        if webExtension.allRequestedMatchPatterns.contains(where: { $0.matches(pattern) }) { return .requestedImplicitly }
        return .unknown
    }
    open func permissionStatus(for url: URL) -> PermissionStatus {
        if _live(deniedPermissionMatchPatterns).contains(where: { $0.matches(url) }) { return .deniedExplicitly }
        if _live(grantedPermissionMatchPatterns).contains(where: { $0.matches(url) }) { return .grantedExplicitly }
        if webExtension.allRequestedMatchPatterns.contains(where: { $0.matches(url) }) { return .requestedImplicitly }
        return .unknown
    }
    @objc(permissionStatusForPermission:) func _objc_status(_ p: String) -> PermissionStatus { permissionStatus(for: WKWebExtension.Permission(p)) }
    @objc(permissionStatusForMatchPattern:) func _objc_status(pattern: WKWebExtension.MatchPattern) -> PermissionStatus { permissionStatus(for: pattern) }
    @objc(permissionStatusForURL:) func _objc_status(url: URL) -> PermissionStatus { permissionStatus(for: url) }

    private static func _set<K: Hashable>(_ status: PermissionStatus, _ key: K, _ until: Date?, granted: inout [K: Date], denied: inout [K: Date]) {
        let date = until ?? .distantFuture
        switch status {
        case .grantedExplicitly, .grantedImplicitly: granted[key] = date; denied[key] = nil
        case .deniedExplicitly, .deniedImplicitly: denied[key] = date; granted[key] = nil
        default: granted[key] = nil; denied[key] = nil
        }
    }
    open func setPermissionStatus(_ status: PermissionStatus, for permission: WKWebExtension.Permission, expirationDate: Date? = nil) {
        Self._set(status, permission, expirationDate, granted: &grantedPermissions, denied: &deniedPermissions)
    }
    open func setPermissionStatus(_ status: PermissionStatus, for pattern: WKWebExtension.MatchPattern, expirationDate: Date? = nil) {
        var g = grantedPermissionMatchPatterns, d = deniedPermissionMatchPatterns
        Self._set(status, pattern, expirationDate, granted: &g, denied: &d)
        grantedPermissionMatchPatterns = g; deniedPermissionMatchPatterns = d
    }
    open func setPermissionStatus(_ status: PermissionStatus, for url: URL, expirationDate: Date? = nil) {
        guard let scheme = url.scheme, let host = url.host, let p = try? WKWebExtension.MatchPattern(string: "\(scheme)://\(host)/*") else { return }
        setPermissionStatus(status, for: p, expirationDate: expirationDate)
    }
    @objc(setPermissionStatus:forPermission:expirationDate:) func _objc_set(_ s: PermissionStatus, permission: String, expirationDate: Date?) {
        setPermissionStatus(s, for: WKWebExtension.Permission(permission), expirationDate: expirationDate)
    }
    @objc(setPermissionStatus:forMatchPattern:expirationDate:) func _objc_set(_ s: PermissionStatus, pattern: WKWebExtension.MatchPattern, expirationDate: Date?) {
        setPermissionStatus(s, for: pattern, expirationDate: expirationDate)
    }
    @objc(setPermissionStatus:forURL:expirationDate:) func _objc_set(_ s: PermissionStatus, url: URL, expirationDate: Date?) {
        setPermissionStatus(s, for: url, expirationDate: expirationDate)
    }
    open func hasPermission(_ permission: WKWebExtension.Permission) -> Bool {
        [.grantedExplicitly, .grantedImplicitly].contains(permissionStatus(for: permission))
    }
    @objc(hasPermission:) func _objc_has(_ p: String) -> Bool { hasPermission(WKWebExtension.Permission(p)) }
    @objc(hasAccessToURL:) open func hasAccess(to url: URL) -> Bool { [.grantedExplicitly, .grantedImplicitly].contains(permissionStatus(for: url)) }
    @objc(hasInjectedContentForURL:) open func hasInjectedContent(for url: URL) -> Bool {
        hasAccess(to: url) && webExtension._contentScripts.contains { s in s.matches.contains { $0.matches(url) } && !s.excludes.contains { $0.matches(url) } }
    }

    // MARK: content scripts
    var _world: WKContentWorld { .world(name: "isim-extension-" + uniqueIdentifier) }
    func _userScripts() -> [WKUserScript] {
        let granted = _live(grantedPermissionMatchPatterns), denied = _live(deniedPermissionMatchPatterns)
        guard !granted.isEmpty else { return [] }
        func list(_ ps: [WKWebExtension.MatchPattern]) -> String { "[" + ps.map { _wkJSLiteral($0._regex) }.joined(separator: ",") + "]" }
        let manifestJSON = webExtension._localizedManifestJSON
        let runtime = "if(!window.browser){window.browser={runtime:{id:\(_wkJSLiteral(uniqueIdentifier)),getManifest:function(){return \(manifestJSON)},"
            + "getURL:function(p){return \(_wkJSLiteral(baseURL.absoluteString))+String(p).replace(/^\\//,'')}}};window.chrome=window.browser}"
        var out = [WKUserScript(source: runtime, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: _world)]
        for s in webExtension._contentScripts {
            var body = ""
            for css in s.css { if let c = webExtension._resource(css) { body += "(function(c){var st=document.createElement('style');st.textContent=c;(document.head||document.documentElement).appendChild(st)})(\(_wkJSLiteral(c)));" } }
            for js in s.js { if let c = webExtension._resource(js) { body += "(0,eval)(\(_wkJSLiteral(c)));" } }
            guard !body.isEmpty else { continue }
            let guardJS = "(function(){var u=location.href,m=function(l){return l.some(function(r){return new RegExp(r).test(u)})};"
                + "if(!m(\(list(s.matches)))||m(\(list(s.excludes)))||!m(\(list(granted)))||m(\(list(denied))))return;\(body)})();"
            out.append(WKUserScript(source: guardJS, injectionTime: s.runAt == "document_start" ? .atDocumentStart : .atDocumentEnd,
                                    forMainFrameOnly: !s.allFrames, in: _world))
        }
        return out
    }
}

/// a JavaScript string literal
func _wkJSLiteral(_ s: String) -> String {
    let d = (try? JSONSerialization.data(withJSONObject: [s])) ?? Data("[\"\"]".utf8)
    let a = String(data: d, encoding: .utf8) ?? "[\"\"]"
    return String(a.dropFirst().dropLast())
}
