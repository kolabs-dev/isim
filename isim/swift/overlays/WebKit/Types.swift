// isim WebKit: configuration, content controller, scripts, navigation objects, errors, data stores.
import UIKit

// MARK: - errors

public let WKErrorDomain = "WKErrorDomain"
public let WKJavaScriptExceptionMessageErrorKey = "WKJavaScriptExceptionMessage"
public let WKJavaScriptExceptionLineNumberErrorKey = "WKJavaScriptExceptionLineNumber"
public let WKJavaScriptExceptionColumnNumberErrorKey = "WKJavaScriptExceptionColumnNumber"
public let WKJavaScriptExceptionSourceURLErrorKey = "WKJavaScriptExceptionSourceURL"

public struct WKError: Error, CustomNSError, Hashable, LocalizedError, @unchecked Sendable {
    public enum Code: Int, Sendable {
        case unknown = 1, webContentProcessTerminated, webViewInvalidated, javaScriptExceptionOccurred, javaScriptResultTypeIsUnsupported
        case contentRuleListStoreCompileFailed, contentRuleListStoreLookUpFailed, contentRuleListStoreRemoveFailed, contentRuleListStoreVersionMismatch
        case attributedStringContentFailedToLoad, attributedStringContentLoadTimedOut, javaScriptInvalidFrameTarget, navigationAppBoundDomain
        case javaScriptAppBoundDomain, duplicateCredential, malformedCredential, credentialNotFound
    }
    public let code: Code
    public let userInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
    public static var errorDomain: String { WKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { userInfo }
    public var errorDescription: String? { userInfo[NSLocalizedDescriptionKey] as? String }
    public static func == (a: WKError, b: WKError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
    public static var unknown: Code { .unknown }
    public static var javaScriptExceptionOccurred: Code { .javaScriptExceptionOccurred }
    public static var javaScriptResultTypeIsUnsupported: Code { .javaScriptResultTypeIsUnsupported }
    public static var webContentProcessTerminated: Code { .webContentProcessTerminated }
    public static var webViewInvalidated: Code { .webViewInvalidated }
}

// MARK: - preferences & configuration

open class WKPreferences: NSObject, @unchecked Sendable {
    open var minimumFontSize: CGFloat = 0
    open var javaScriptCanOpenWindowsAutomatically = false
    open var isFraudulentWebsiteWarningEnabled = true
    open var isElementFullscreenEnabled = false
    open var isTextInteractionEnabled = true
    open var isSiteSpecificQuirksModeEnabled = true
    open var shouldPrintBackgrounds = false
    open var inactiveSchedulingPolicy: Int = 0
    @available(*, deprecated, message: "Use WKWebpagePreferences.allowsContentJavaScript")
    open var javaScriptEnabled = true
    open override func copy() -> Any {
        let p = WKPreferences()
        p.minimumFontSize = minimumFontSize; p.javaScriptCanOpenWindowsAutomatically = javaScriptCanOpenWindowsAutomatically
        p.isFraudulentWebsiteWarningEnabled = isFraudulentWebsiteWarningEnabled; p.isElementFullscreenEnabled = isElementFullscreenEnabled
        return p
    }
}

open class WKWebpagePreferences: NSObject, @unchecked Sendable {
    @objc public enum ContentMode: Int, Sendable { case recommended = 0, mobile, desktop }
    @objc public enum UpgradeToHTTPSPolicy: Int, Sendable { case keepAsRequested = 0, automaticFallbackToHTTP, userMediatedFallbackToHTTP, errorOnFailure }
    open var allowsContentJavaScript = true
    open var preferredContentMode: ContentMode = .recommended
    open var isLockdownModeEnabled = false
    open var preferredHTTPSNavigationPolicy: UpgradeToHTTPSPolicy = .keepAsRequested
    public override init() { super.init() }
}

open class WKProcessPool: NSObject, @unchecked Sendable {}

public struct WKAudiovisualMediaTypes: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let audio = WKAudiovisualMediaTypes(rawValue: 1)
    public static let video = WKAudiovisualMediaTypes(rawValue: 2)
    public static let all = WKAudiovisualMediaTypes(rawValue: ~0)
}
public struct WKDataDetectorTypes: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let phoneNumber = WKDataDetectorTypes(rawValue: 1)
    public static let link = WKDataDetectorTypes(rawValue: 2)
    public static let address = WKDataDetectorTypes(rawValue: 4)
    public static let calendarEvent = WKDataDetectorTypes(rawValue: 8)
    public static let trackingNumber = WKDataDetectorTypes(rawValue: 16)
    public static let flightNumber = WKDataDetectorTypes(rawValue: 32)
    public static let lookupSuggestion = WKDataDetectorTypes(rawValue: 64)
    public static let all = WKDataDetectorTypes(rawValue: ~0)
}
@objc public enum WKSelectionGranularity: Int, Sendable { case dynamic = 0, character }
@objc public enum WKUserInterfaceDirectionPolicy: Int, Sendable { case content = 0, system }

@MainActor open class WKWebViewConfiguration: NSObject, @unchecked Sendable {
    open var userContentController = WKUserContentController()
    open var websiteDataStore: WKWebsiteDataStore = .default()
    open var preferences = WKPreferences()
    open var defaultWebpagePreferences = WKWebpagePreferences()
    open var processPool = WKProcessPool()
    open var applicationNameForUserAgent: String? = "Mobile/15E148"
    open var allowsInlineMediaPlayback = false
    open var allowsAirPlayForMediaPlayback = true
    open var allowsPictureInPictureMediaPlayback = true
    open var mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes = .all
    open var dataDetectorTypes: WKDataDetectorTypes = []
    open var ignoresViewportScaleLimits = false
    open var suppressesIncrementalRendering = false
    open var selectionGranularity: WKSelectionGranularity = .dynamic
    open var userInterfaceDirectionPolicy: WKUserInterfaceDirectionPolicy = .content
    open var limitsNavigationsToAppBoundDomains = false
    open var upgradeKnownHostsToHTTPS = true
    open var allowsInlinePredictions = false
    open var supportsAdaptiveImageGlyph = false
    var _schemeHandlers: [String: WKURLSchemeHandler] = [:]
    public override init() { super.init() }
    open func setURLSchemeHandler(_ urlSchemeHandler: WKURLSchemeHandler?, forURLScheme urlScheme: String) {
        let s = urlScheme.lowercased()
        if ["http", "https", "file", "data", "about", "blob", "javascript", "ws", "wss"].contains(s) {
            NSException(name: "NSInvalidArgumentException", reason: "'\(urlScheme)' is a URL scheme that WKWebView handles natively", userInfo: nil).raise()
        }
        _schemeHandlers[s] = urlSchemeHandler
    }
    open func urlSchemeHandler(forURLScheme urlScheme: String) -> WKURLSchemeHandler? { _schemeHandlers[urlScheme.lowercased()] }
    open override func copy() -> Any {
        let c = WKWebViewConfiguration()
        c.userContentController = userContentController; c.websiteDataStore = websiteDataStore
        c.preferences = preferences; c.defaultWebpagePreferences = defaultWebpagePreferences; c.processPool = processPool
        c.applicationNameForUserAgent = applicationNameForUserAgent; c.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        c.mediaTypesRequiringUserActionForPlayback = mediaTypesRequiringUserActionForPlayback; c.dataDetectorTypes = dataDetectorTypes
        c.ignoresViewportScaleLimits = ignoresViewportScaleLimits; c.limitsNavigationsToAppBoundDomains = limitsNavigationsToAppBoundDomains
        c._schemeHandlers = _schemeHandlers
        return c
    }
}

// MARK: - content worlds, user scripts, script messages

open class WKContentWorld: NSObject, @unchecked Sendable {
    public let name: String?
    let _engineName: String
    init(name: String?, engineName: String) { self.name = name; _engineName = engineName }
    public static let page = WKContentWorld(name: nil, engineName: "")
    public static let defaultClient = WKContentWorld(name: nil, engineName: "WKDefaultClientWorld")
    nonisolated(unsafe) static var _worlds: [String: WKContentWorld] = [:]
    public static func world(name: String) -> WKContentWorld {
        if let w = _worlds[name] { return w }
        let w = WKContentWorld(name: name, engineName: "client:" + name)
        _worlds[name] = w
        return w
    }
}

@objc public enum WKUserScriptInjectionTime: Int, Sendable { case atDocumentStart = 0, atDocumentEnd }

open class WKUserScript: NSObject, @unchecked Sendable {
    public let source: String
    public let injectionTime: WKUserScriptInjectionTime
    public let isForMainFrameOnly: Bool
    let _world: WKContentWorld
    public init(source: String, injectionTime: WKUserScriptInjectionTime, forMainFrameOnly: Bool) {
        self.source = source; self.injectionTime = injectionTime; isForMainFrameOnly = forMainFrameOnly; _world = .page
    }
    public init(source: String, injectionTime: WKUserScriptInjectionTime, forMainFrameOnly: Bool, in contentWorld: WKContentWorld) {
        self.source = source; self.injectionTime = injectionTime; isForMainFrameOnly = forMainFrameOnly; _world = contentWorld
    }
}

@objc public protocol WKScriptMessageHandler: NSObjectProtocol {
    @MainActor func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)
}
@objc public protocol WKScriptMessageHandlerWithReply: NSObjectProtocol {
    @MainActor @objc(userContentController:didReceiveScriptMessage:replyHandler:) optional func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                                                        replyHandler: @escaping (Any?, String?) -> Void)
    @MainActor @objc(userContentController:didReceiveScriptMessage:asyncReplyHandler:) optional func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?)
}

open class WKScriptMessage: NSObject, @unchecked Sendable {
    open private(set) var body: Any
    open private(set) weak var webView: WKWebView?
    open private(set) var frameInfo: WKFrameInfo
    open private(set) var name: String
    open private(set) var world: WKContentWorld
    init(body: Any, webView: WKWebView?, frameInfo: WKFrameInfo, name: String, world: WKContentWorld) {
        self.body = body; self.webView = webView; self.frameInfo = frameInfo; self.name = name; self.world = world
    }
}

open class WKContentRuleList: NSObject, @unchecked Sendable {
    public let identifier: String
    init(identifier: String) { self.identifier = identifier }
}
/// Content blockers are compiled and stored but not applied on isim.
open class WKContentRuleListStore: NSObject, @unchecked Sendable {
    nonisolated(unsafe) static let _default = WKContentRuleListStore()
    var lists: [String: WKContentRuleList] = [:]
    open class func `default`() -> WKContentRuleListStore { _default }
    public convenience init(url: URL) { self.init() }
    open func compileContentRuleList(forIdentifier identifier: String, encodedContentRuleList: String, completionHandler: @escaping (WKContentRuleList?, Error?) -> Void) {
        let l = WKContentRuleList(identifier: identifier); lists[identifier] = l
        DispatchQueue.main.async { completionHandler(l, nil) }
    }
    open func lookUpContentRuleList(forIdentifier identifier: String, completionHandler: @escaping (WKContentRuleList?, Error?) -> Void) {
        let l = lists[identifier]
        DispatchQueue.main.async { completionHandler(l, l == nil ? WKError(.contentRuleListStoreLookUpFailed) : nil) }
    }
    open func removeContentRuleList(forIdentifier identifier: String, completionHandler: @escaping (Error?) -> Void) {
        let had = lists.removeValue(forKey: identifier) != nil
        DispatchQueue.main.async { completionHandler(had ? nil : WKError(.contentRuleListStoreRemoveFailed)) }
    }
    open func getAvailableContentRuleListIdentifiers(_ completionHandler: @escaping ([String]?) -> Void) {
        let ids = Array(lists.keys); DispatchQueue.main.async { completionHandler(ids) }
    }
}

@MainActor open class WKUserContentController: NSObject, @unchecked Sendable {
    open private(set) var userScripts: [WKUserScript] = []
    struct Handler { let name: String; let world: WKContentWorld; let handler: AnyObject; let withReply: Bool }
    var _handlers: [Handler] = []
    var _views: [_WKWeakView] = []
    var _ruleLists: [WKContentRuleList] = []
    public override init() { super.init() }

    func _attach(_ v: WKWebView) { _views.removeAll { $0.view == nil || $0.view === v }; _views.append(_WKWeakView(v)) }
    func _detach(_ v: WKWebView) { _views.removeAll { $0.view == nil || $0.view === v } }
    private func each(_ f: (WKWebView) -> Void) { for w in _views { if let v = w.view { f(v) } } }

    open func addUserScript(_ userScript: WKUserScript) {
        userScripts.append(userScript)
        each { $0._installScript(userScript) }
    }
    open func removeAllUserScripts() {
        userScripts.removeAll()
        each { $0._reinstallScripts() }
    }
    open func removeAllUserScripts(from contentWorld: WKContentWorld) {
        userScripts.removeAll { $0._world === contentWorld }
        each { $0._reinstallScripts() }
    }
    private func addHandler(_ h: AnyObject, world: WKContentWorld, name: String, reply: Bool) {
        if _handlers.contains(where: { $0.name == name && $0.world === world }) {
            NSException(name: "NSInvalidArgumentException", reason: "Attempt to add script message handler with name '\(name)' when one already exists.", userInfo: nil).raise()
        }
        let entry = Handler(name: name, world: world, handler: h, withReply: reply)
        _handlers.append(entry)
        each { $0._installHandler(entry) }
    }
    open func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String) { addHandler(scriptMessageHandler, world: .page, name: name, reply: false) }
    open func add(_ scriptMessageHandler: WKScriptMessageHandler, contentWorld world: WKContentWorld, name: String) {
        addHandler(scriptMessageHandler, world: world, name: name, reply: false)
    }
    open func addScriptMessageHandler(_ scriptMessageHandlerWithReply: WKScriptMessageHandlerWithReply, contentWorld: WKContentWorld, name: String) {
        addHandler(scriptMessageHandlerWithReply, world: contentWorld, name: name, reply: true)
    }
    open func removeScriptMessageHandler(forName name: String) { removeScriptMessageHandler(forName: name, contentWorld: .page) }
    open func removeScriptMessageHandler(forName name: String, contentWorld: WKContentWorld) {
        let gone = _handlers.filter { $0.name == name && $0.world === contentWorld }
        _handlers.removeAll { $0.name == name && $0.world === contentWorld }
        for h in gone { each { $0._removeHandler(h) } }
    }
    open func removeAllScriptMessageHandlers(from contentWorld: WKContentWorld) {
        for h in _handlers where h.world === contentWorld { removeScriptMessageHandler(forName: h.name, contentWorld: contentWorld) }
    }
    open func removeAllScriptMessageHandlers() { for h in _handlers { removeScriptMessageHandler(forName: h.name, contentWorld: h.world) } }
    open func add(_ contentRuleList: WKContentRuleList) { _ruleLists.append(contentRuleList) }
    open func remove(_ contentRuleList: WKContentRuleList) { _ruleLists.removeAll { $0 === contentRuleList } }
    open func removeAllContentRuleLists() { _ruleLists.removeAll() }
}

// MARK: - navigation objects

open class WKNavigation: NSObject, @unchecked Sendable {
    open var effectiveContentMode: WKWebpagePreferences.ContentMode { .mobile }
}

@objc public enum WKNavigationType: Int, Sendable {
    case linkActivated = 0, formSubmitted = 1, backForward = 2, reload = 3, formResubmitted = 4, other = -1
}
@objc public enum WKNavigationActionPolicy: Int, Sendable { case cancel = 0, allow = 1, download = 2 }
@objc public enum WKNavigationResponsePolicy: Int, Sendable { case cancel = 0, allow = 1, download = 2 }

open class WKSecurityOrigin: NSObject, @unchecked Sendable {
    open private(set) var `protocol`: String
    open private(set) var host: String
    open private(set) var port: Int
    init(url: URL?) {
        `protocol` = url?.scheme ?? ""; host = url?.host ?? ""
        port = url?.port ?? 0
    }
}

open class WKFrameInfo: NSObject, @unchecked Sendable {
    open private(set) var isMainFrame: Bool
    open private(set) var request: URLRequest
    open private(set) var securityOrigin: WKSecurityOrigin
    open private(set) weak var webView: WKWebView?
    init(main: Bool, url: URL?, webView: WKWebView?) {
        isMainFrame = main
        request = URLRequest(url: url ?? URL(string: "about:blank")!)
        securityOrigin = WKSecurityOrigin(url: url)
        self.webView = webView
    }
}

open class WKNavigationAction: NSObject, @unchecked Sendable {
    open private(set) var sourceFrame: WKFrameInfo
    open private(set) var targetFrame: WKFrameInfo?
    open private(set) var navigationType: WKNavigationType
    open private(set) var request: URLRequest
    open private(set) var modifierFlags: UIKeyModifierFlags
    open private(set) var buttonNumber: Int
    open var shouldPerformDownload: Bool { false }
    open private(set) var isContentRuleListRedirect = false
    init(sourceFrame: WKFrameInfo, targetFrame: WKFrameInfo?, navigationType: WKNavigationType, request: URLRequest, buttonNumber: Int) {
        self.sourceFrame = sourceFrame; self.targetFrame = targetFrame; self.navigationType = navigationType
        self.request = request; modifierFlags = []; self.buttonNumber = buttonNumber
    }
}

open class WKNavigationResponse: NSObject, @unchecked Sendable {
    open private(set) var isForMainFrame: Bool
    open private(set) var response: URLResponse
    open private(set) var canShowMIMEType: Bool
    init(isForMainFrame: Bool, response: URLResponse, canShowMIMEType: Bool) {
        self.isForMainFrame = isForMainFrame; self.response = response; self.canShowMIMEType = canShowMIMEType
    }
}

open class WKWindowFeatures: NSObject, @unchecked Sendable {
    open private(set) var menuBarVisibility: NSNumber?
    open private(set) var statusBarVisibility: NSNumber?
    open private(set) var toolbarsVisibility: NSNumber?
    open private(set) var allowsResizing: NSNumber?
    open private(set) var x: NSNumber?
    open private(set) var y: NSNumber?
    open private(set) var width: NSNumber?
    open private(set) var height: NSNumber?
}

open class WKBackForwardListItem: NSObject, @unchecked Sendable {
    open private(set) var url: URL
    open private(set) var title: String?
    open private(set) var initialURL: URL
    let _offset: Int
    init(url: URL, title: String?, initialURL: URL, offset: Int) { self.url = url; self.title = title; self.initialURL = initialURL; _offset = offset }
}

open class WKBackForwardList: NSObject, @unchecked Sendable {
    open private(set) var currentItem: WKBackForwardListItem?
    open private(set) var backList: [WKBackForwardListItem] = []
    open private(set) var forwardList: [WKBackForwardListItem] = []
    open var backItem: WKBackForwardListItem? { backList.last }
    open var forwardItem: WKBackForwardListItem? { forwardList.first }
    open func item(at index: Int) -> WKBackForwardListItem? {
        if index == 0 { return currentItem }
        if index < 0 { let i = backList.count + index; return i >= 0 ? backList[i] : nil }
        return index - 1 < forwardList.count ? forwardList[index - 1] : nil
    }
    func _update(_ json: String) {
        let o = _wkJSONObject(json)
        func items(_ a: Any?, base: Int) -> [WKBackForwardListItem] {
            guard let arr = a as? [[Any]] else { return [] }
            return arr.enumerated().compactMap { i, e in
                guard e.count >= 3, let u = URL(string: e[0] as? String ?? "") else { return nil }
                let t = e[1] as? String
                return WKBackForwardListItem(url: u, title: t?.isEmpty == false ? t : nil, initialURL: URL(string: e[2] as? String ?? "") ?? u, offset: base + i)
            }
        }
        let back = (o["back"] as? [[Any]]) ?? []
        backList = items(back, base: -back.count)
        forwardList = items(o["forward"], base: 1)
        currentItem = items(o["current"].map { [$0] }, base: 0).first
    }
}

// MARK: - custom URL schemes

public protocol WKURLSchemeTask: NSObjectProtocol {
    var request: URLRequest { get }
    func didReceive(_ response: URLResponse)
    func didReceive(_ data: Data)
    func didFinish()
    func didFailWithError(_ error: Error)
}
public protocol WKURLSchemeHandler: NSObjectProtocol {
    @MainActor func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask)
    @MainActor func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask)
}

final class _WKSchemeTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    let id: Int
    var finished = false
    init(id: Int, request: URLRequest) { self.id = id; self.request = request }
    func didReceive(_ response: URLResponse) {
        guard !finished else { return }
        var status = 200, headers = ""
        if let h = response as? HTTPURLResponse {
            status = h.statusCode
            headers = h.allHeaderFields.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }
        _WKEngine.shared.send(["schemeresp", "0", String(id), String(status), response.mimeType ?? "", headers])
    }
    func didReceive(_ data: Data) {
        guard !finished else { return }
        _WKEngine.shared.send(["schemedata", "0", String(id), data.base64EncodedString()])
    }
    func didFinish() {
        guard !finished else { return }
        finished = true
        _WKEngine.shared.send(["schemedone", "0", String(id)])
    }
    func didFailWithError(_ error: Error) {
        guard !finished else { return }
        finished = true
        _WKEngine.shared.send(["schemefail", "0", String(id), (error as NSError).localizedDescription])
    }
}

@MainActor enum _WKSchemeRouter {
    static func request(id: Int, viewID: Int, json: String) {
        let o = _wkJSONObject(json)
        guard let u = URL(string: o["url"] as? String ?? "") else { return }
        var rq = URLRequest(url: u)
        rq.httpMethod = o["method"] as? String ?? "GET"
        for (k, v) in (o["headers"] as? [String: String]) ?? [:] { rq.setValue(v, forHTTPHeaderField: k) }
        let task = _WKSchemeTask(id: id, request: rq)
        guard let wv = WKWebView._live(viewID), let h = wv.configuration.urlSchemeHandler(forURLScheme: u.scheme ?? "") else {
            task.didFailWithError(URLError(.unsupportedURL)); return
        }
        h.webView(wv, start: task)
    }
}

// MARK: - snapshots, find, PDF

open class WKSnapshotConfiguration: NSObject, @unchecked Sendable {
    open var rect: CGRect = .null
    open var snapshotWidth: NSNumber?
    open var afterScreenUpdates = true
    public override init() { super.init() }
}
open class WKPDFConfiguration: NSObject, @unchecked Sendable {
    open var rect: CGRect = .null
    open var allowTransparentBackground = false
    public override init() { super.init() }
}
open class WKFindConfiguration: NSObject, @unchecked Sendable {
    open var backwards = false
    open var caseSensitive = false
    open var wraps = true
    public override init() { super.init() }
}
open class WKFindResult: NSObject, @unchecked Sendable {
    open private(set) var matchFound: Bool
    init(matchFound: Bool) { self.matchFound = matchFound }
}

// MARK: - website data

open class WKWebsiteDataRecord: NSObject, @unchecked Sendable {
    open private(set) var displayName: String
    open private(set) var dataTypes: Set<String>
    init(displayName: String, dataTypes: Set<String>) { self.displayName = displayName; self.dataTypes = dataTypes }
}
public let WKWebsiteDataTypeFetchCache = "WKWebsiteDataTypeFetchCache"
public let WKWebsiteDataTypeDiskCache = "WKWebsiteDataTypeDiskCache"
public let WKWebsiteDataTypeMemoryCache = "WKWebsiteDataTypeMemoryCache"
public let WKWebsiteDataTypeOfflineWebApplicationCache = "WKWebsiteDataTypeOfflineWebApplicationCache"
public let WKWebsiteDataTypeCookies = "WKWebsiteDataTypeCookies"
public let WKWebsiteDataTypeSessionStorage = "WKWebsiteDataTypeSessionStorage"
public let WKWebsiteDataTypeLocalStorage = "WKWebsiteDataTypeLocalStorage"
public let WKWebsiteDataTypeWebSQLDatabases = "WKWebsiteDataTypeWebSQLDatabases"
public let WKWebsiteDataTypeIndexedDBDatabases = "WKWebsiteDataTypeIndexedDBDatabases"
public let WKWebsiteDataTypeServiceWorkerRegistrations = "WKWebsiteDataTypeServiceWorkerRegistrations"
public let WKWebsiteDataTypeFileSystem = "WKWebsiteDataTypeFileSystem"
public let WKWebsiteDataTypeSearchFieldRecentSearches = "WKWebsiteDataTypeSearchFieldRecentSearches"
public let WKWebsiteDataTypeMediaKeys = "WKWebsiteDataTypeMediaKeys"
public let WKWebsiteDataTypeHashSalt = "WKWebsiteDataTypeHashSalt"

@objc public protocol WKHTTPCookieStoreObserver: NSObjectProtocol {
    @objc optional func cookiesDidChange(in cookieStore: WKHTTPCookieStore)
}

/// Website data: the default store persists in the app container (Library/WebKit), the non-persistent
/// store keeps it in memory. The engine needs a live WKWebView of the store to reach its data;
/// with none, cookie calls answer from cookies set through this store in this run.
@MainActor open class WKWebsiteDataStore: NSObject, @unchecked Sendable {
    public let isPersistent: Bool
    open private(set) lazy var httpCookieStore = WKHTTPCookieStore(store: self)
    open var identifier: UUID? { nil }
    open var proxyConfigurations: [AnyObject] = []
    init(persistent: Bool) { isPersistent = persistent }
    static let _default = WKWebsiteDataStore(persistent: true)
    open class func `default`() -> WKWebsiteDataStore { _default }
    open class func nonPersistent() -> WKWebsiteDataStore { WKWebsiteDataStore(persistent: false) }
    open class func allWebsiteDataTypes() -> Set<String> {
        [WKWebsiteDataTypeFetchCache, WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeOfflineWebApplicationCache,
         WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeWebSQLDatabases,
         WKWebsiteDataTypeIndexedDBDatabases, WKWebsiteDataTypeServiceWorkerRegistrations]
    }
    var _views: [_WKWeakView] = []
    func _anyView() -> WKWebView? { _views.compactMap(\.view).first { $0._engineID != 0 && $0._engineReady } }
    /// runs a command against the engine through one of this store's web views; `reply` gets the "done" payload
    func _request(_ cmd: [String], reply: @escaping (String?) -> Void) {
        guard let v = _anyView() else { DispatchQueue.main.async { reply(nil) }; return }
        let req = _WKEngine.shared.newRequestID()
        _WKEngine.shared.storeCallbacks[req] = { reply($0) }
        _WKEngine.shared.send([cmd[0], String(v._engineID), String(req)] + cmd.dropFirst())
    }
    open func fetchDataRecords(ofTypes dataTypes: Set<String>, completionHandler: @escaping @MainActor ([WKWebsiteDataRecord]) -> Void) {
        httpCookieStore.getAllCookies { cookies in
            var byDomain: [String: Set<String>] = [:]
            if dataTypes.contains(WKWebsiteDataTypeCookies) {
                for c in cookies { let d = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain; byDomain[d, default: []].insert(WKWebsiteDataTypeCookies) }
            }
            MainActor.assumeIsolated { completionHandler(byDomain.keys.sorted().map { WKWebsiteDataRecord(displayName: $0, dataTypes: byDomain[$0]!) }) }
        }
    }
    open func fetchDataRecords(ofTypes dataTypes: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { c in fetchDataRecords(ofTypes: dataTypes) { c.resume(returning: $0) } }
    }
    open func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date, completionHandler: @escaping @MainActor () -> Void) {
        if dataTypes.contains(WKWebsiteDataTypeCookies) { httpCookieStore._local.removeAll() }
        let since = date.timeIntervalSince1970 <= 0 ? 0 : Int(date.timeIntervalSince1970)
        _request(["cleardata", String(since)]) { _ in MainActor.assumeIsolated { completionHandler() } }
    }
    open func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date) async {
        await withCheckedContinuation { c in removeData(ofTypes: dataTypes, modifiedSince: date) { c.resume() } }
    }
    open func removeData(ofTypes dataTypes: Set<String>, for dataRecords: [WKWebsiteDataRecord], completionHandler: @escaping @MainActor () -> Void) {
        removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: completionHandler)
    }
}

@MainActor open class WKHTTPCookieStore: NSObject, @unchecked Sendable {
    unowned let store: WKWebsiteDataStore
    var _local: [HTTPCookie] = []
    var _observers: [WKHTTPCookieStoreObserverBox] = []
    init(store: WKWebsiteDataStore) { self.store = store }
    open func getAllCookies(_ completionHandler: @escaping @MainActor ([HTTPCookie]) -> Void) {
        store._request(["cookies"]) { json in
            var out: [HTTPCookie] = []
            if let json, let arr = _wkJSONValue(json) as? [[String: Any]] {
                for o in arr {
                    var p: [HTTPCookiePropertyKey: Any] = [.name: o["name"] as? String ?? "", .value: o["value"] as? String ?? "",
                                                         .domain: o["domain"] as? String ?? "", .path: o["path"] as? String ?? "/"]
                    if o["secure"] as? Bool == true { p[.secure] = "TRUE" }
                    if let e = o["expires"] as? Double, e > 0 { p[.expires] = Date(timeIntervalSince1970: e) }
                    if o["httpOnly"] as? Bool == true { p[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
                    if let c = HTTPCookie(properties: p) { out.append(c) }
                }
            } else { out = self._local }
            MainActor.assumeIsolated { completionHandler(out) }
        }
    }
    open func allCookies() async -> [HTTPCookie] { await withCheckedContinuation { c in getAllCookies { c.resume(returning: $0) } } }
    open func setCookie(_ cookie: HTTPCookie, completionHandler: (@MainActor () -> Void)? = nil) {
        _local.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
        _local.append(cookie)
        let exp = cookie.expiresDate.map { String(Int($0.timeIntervalSince1970)) } ?? "0"
        store._request(["setcookie", cookie.name, cookie.value, cookie.domain, cookie.path, exp, cookie.isSecure ? "1" : "0", cookie.isHTTPOnly ? "1" : "0"]) { _ in
            MainActor.assumeIsolated { completionHandler?(); self._changed() }
        }
    }
    open func setCookie(_ cookie: HTTPCookie) async { await withCheckedContinuation { c in setCookie(cookie) { c.resume() } } }
    open func delete(_ cookie: HTTPCookie, completionHandler: (@MainActor () -> Void)? = nil) {
        _local.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
        store._request(["delcookie", cookie.name, cookie.value, cookie.domain, cookie.path, "0", "0", "0"]) { _ in
            MainActor.assumeIsolated { completionHandler?(); self._changed() }
        }
    }
    open func deleteCookie(_ cookie: HTTPCookie) async { await withCheckedContinuation { c in delete(cookie) { c.resume() } } }
    open func add(_ observer: WKHTTPCookieStoreObserver) { _observers.append(WKHTTPCookieStoreObserverBox(observer)) }
    open func remove(_ observer: WKHTTPCookieStoreObserver) { _observers.removeAll { $0.o == nil || $0.o === observer } }
    func _changed() { for b in _observers { b.o?.cookiesDidChange?(in: self) } }
}
final class WKHTTPCookieStoreObserverBox { weak var o: WKHTTPCookieStoreObserver?; init(_ o: WKHTTPCookieStoreObserver) { self.o = o } }
