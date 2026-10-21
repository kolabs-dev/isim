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

@objc(WKPreferences) open class WKPreferences: NSObject, @unchecked Sendable {
    @objc open dynamic var minimumFontSize: CGFloat = 0
    @objc open dynamic var javaScriptCanOpenWindowsAutomatically = false
    var _fraudWarning = true, _fullscreen = false, _textInteraction = true, _quirks = true
    @objc open dynamic var isFraudulentWebsiteWarningEnabled: Bool {
        @objc(isFraudulentWebsiteWarningEnabled) get { _fraudWarning } @objc(setFraudulentWebsiteWarningEnabled:) set { _fraudWarning = newValue }
    }
    @objc open dynamic var isElementFullscreenEnabled: Bool {
        @objc(isElementFullscreenEnabled) get { _fullscreen } @objc(setElementFullscreenEnabled:) set { _fullscreen = newValue }
    }
    @objc open dynamic var isTextInteractionEnabled: Bool {
        @objc(isTextInteractionEnabled) get { _textInteraction } @objc(setTextInteractionEnabled:) set { _textInteraction = newValue }
    }
    @objc open dynamic var isSiteSpecificQuirksModeEnabled: Bool {
        @objc(isSiteSpecificQuirksModeEnabled) get { _quirks } @objc(setSiteSpecificQuirksModeEnabled:) set { _quirks = newValue }
    }
    @objc open dynamic var shouldPrintBackgrounds = false
    @objc open dynamic var inactiveSchedulingPolicy: Int = 0
    @available(*, deprecated, message: "Use WKWebpagePreferences.allowsContentJavaScript")
    @objc open dynamic var javaScriptEnabled = true
    open override func copy() -> Any {
        let p = WKPreferences()
        p.minimumFontSize = minimumFontSize; p.javaScriptCanOpenWindowsAutomatically = javaScriptCanOpenWindowsAutomatically
        p.isFraudulentWebsiteWarningEnabled = isFraudulentWebsiteWarningEnabled; p.isElementFullscreenEnabled = isElementFullscreenEnabled
        return p
    }
}

@objc(WKWebpagePreferences) open class WKWebpagePreferences: NSObject, @unchecked Sendable {
    @objc public enum ContentMode: Int, Sendable { case recommended = 0, mobile, desktop }
    @available(iOS 18.2, *)
    @objc public enum UpgradeToHTTPSPolicy: Int, Sendable { case keepAsRequested = 0, automaticFallbackToHTTP, userMediatedFallbackToHTTP, errorOnFailure }
    @objc open dynamic var allowsContentJavaScript = true
    @objc open dynamic var preferredContentMode: ContentMode = .recommended
    var _lockdown = false
    @objc open dynamic var isLockdownModeEnabled: Bool { @objc(isLockdownModeEnabled) get { _lockdown } @objc(setLockdownModeEnabled:) set { _lockdown = newValue } }
    var _httpsPolicy = 0
    @available(iOS 18.2, *)
    @objc open dynamic var preferredHTTPSNavigationPolicy: UpgradeToHTTPSPolicy {
        get { UpgradeToHTTPSPolicy(rawValue: _httpsPolicy) ?? .keepAsRequested }
        set { _httpsPolicy = newValue.rawValue }
    }
    public override init() { super.init() }
}

@objc(WKProcessPool) open class WKProcessPool: NSObject, @unchecked Sendable {}

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

@MainActor @objc(WKWebViewConfiguration) open class WKWebViewConfiguration: NSObject, @unchecked Sendable {
    @objc open dynamic var userContentController = WKUserContentController()
    @objc open dynamic var websiteDataStore: WKWebsiteDataStore = .default()
    @objc open dynamic var preferences = WKPreferences()
    @objc open dynamic var defaultWebpagePreferences = WKWebpagePreferences()
    @objc open dynamic var processPool = WKProcessPool()
    @objc open dynamic var applicationNameForUserAgent: String? = "Mobile/15E148"
    @objc open dynamic var allowsInlineMediaPlayback = false
    @objc open dynamic var allowsAirPlayForMediaPlayback = true
    @objc open dynamic var allowsPictureInPictureMediaPlayback = true
    /* option sets: Swift structs (NSUInteger for Objective-C: ObjC.swift) */
    public final var mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes = .all
    public final var dataDetectorTypes: WKDataDetectorTypes = []
    @objc open dynamic var ignoresViewportScaleLimits = false
    @objc open dynamic var suppressesIncrementalRendering = false
    @objc open dynamic var selectionGranularity: WKSelectionGranularity = .dynamic
    @objc open dynamic var userInterfaceDirectionPolicy: WKUserInterfaceDirectionPolicy = .content
    @objc open dynamic var limitsNavigationsToAppBoundDomains = false
    @objc open dynamic var upgradeKnownHostsToHTTPS = true
    @objc open dynamic var allowsInlinePredictions = false
    @objc open dynamic var supportsAdaptiveImageGlyph = false
    var _schemeHandlers: [String: WKURLSchemeHandler] = [:]
    public override init() { super.init() }
    public final func setURLSchemeHandler(_ urlSchemeHandler: WKURLSchemeHandler?, forURLScheme urlScheme: String) {
        let s = urlScheme.lowercased()
        if ["http", "https", "file", "data", "about", "blob", "javascript", "ws", "wss"].contains(s) {
            NSException(name: "NSInvalidArgumentException", reason: "'\(urlScheme)' is a URL scheme that WKWebView handles natively", userInfo: nil).raise()
        }
        _schemeHandlers[s] = urlSchemeHandler
    }
    public final func urlSchemeHandler(forURLScheme urlScheme: String) -> WKURLSchemeHandler? { _schemeHandlers[urlScheme.lowercased()] }
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

@objc(WKContentWorld) open class WKContentWorld: NSObject, @unchecked Sendable {
    @objc public let name: String?
    let _engineName: String
    init(name: String?, engineName: String) { self.name = name; _engineName = engineName }
    @objc(pageWorld) public static let page = WKContentWorld(name: nil, engineName: "")
    @objc(defaultClientWorld) public static let defaultClient = WKContentWorld(name: nil, engineName: "WKDefaultClientWorld")
    nonisolated(unsafe) static var _worlds: [String: WKContentWorld] = [:]
    @objc(worldWithName:) public static func world(name: String) -> WKContentWorld {
        if let w = _worlds[name] { return w }
        let w = WKContentWorld(name: name, engineName: "client:" + name)
        _worlds[name] = w
        return w
    }
}

@objc public enum WKUserScriptInjectionTime: Int, Sendable { case atDocumentStart = 0, atDocumentEnd }

@objc(WKUserScript) open class WKUserScript: NSObject, @unchecked Sendable {
    @objc public let source: String
    @objc public let injectionTime: WKUserScriptInjectionTime
    @objc public let isForMainFrameOnly: Bool
    let _world: WKContentWorld
    @objc(initWithSource:injectionTime:forMainFrameOnly:)
    public init(source: String, injectionTime: WKUserScriptInjectionTime, forMainFrameOnly: Bool) {
        self.source = source; self.injectionTime = injectionTime; isForMainFrameOnly = forMainFrameOnly; _world = .page
    }
    @objc(initWithSource:injectionTime:forMainFrameOnly:inContentWorld:)
    public init(source: String, injectionTime: WKUserScriptInjectionTime, forMainFrameOnly: Bool, in contentWorld: WKContentWorld) {
        self.source = source; self.injectionTime = injectionTime; isForMainFrameOnly = forMainFrameOnly; _world = contentWorld
    }
}

@objc(WKScriptMessageHandler) public protocol WKScriptMessageHandler: NSObjectProtocol {
    @MainActor @objc(userContentController:didReceiveScriptMessage:) func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)
}
@objc(WKScriptMessageHandlerWithReply) public protocol WKScriptMessageHandlerWithReply: NSObjectProtocol {
    @MainActor @objc(userContentController:didReceiveScriptMessage:replyHandler:) optional func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                                                        replyHandler: @escaping (Any?, String?) -> Void)
    @MainActor @objc(userContentController:didReceiveScriptMessage:asyncReplyHandler:) optional func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?)
}

@objc(WKScriptMessage) open class WKScriptMessage: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var body: Any
    @objc open private(set) weak dynamic var webView: WKWebView?
    @objc open private(set) dynamic var frameInfo: WKFrameInfo
    @objc open private(set) dynamic var name: String
    @objc open private(set) dynamic var world: WKContentWorld
    init(body: Any, webView: WKWebView?, frameInfo: WKFrameInfo, name: String, world: WKContentWorld) {
        self.body = body; self.webView = webView; self.frameInfo = frameInfo; self.name = name; self.world = world
    }
}

@objc(WKContentRuleList) open class WKContentRuleList: NSObject, @unchecked Sendable {
    @objc public let identifier: String
    let _store: String
    init(identifier: String, store: String = "") { self.identifier = identifier; _store = store }
}
/// Compiled content blockers: a passthrough to WebKitGTK's WebKitUserContentFilterStore (the same JSON rules), kept in
/// the store's directory across launches; WKUserContentController applies them to its web views.
@objc(WKContentRuleListStore) open class WKContentRuleListStore: NSObject, @unchecked Sendable {
    static let _default = WKContentRuleListStore(url: URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent("Library/WebKit/ContentRuleLists")))
    let _path: String
    @objc(defaultStore) open class dynamic func `default`() -> WKContentRuleListStore { _default }
    public init(url: URL) { _path = url.path; super.init() }
    public override convenience init() { self.init(url: WKContentRuleListStore._default._url) }
    var _url: URL { URL(fileURLWithPath: _path) }
    /// a store operation in the engine; the reply is "ok" [json] or "error" message
    func _op(_ fields: [String], _ done: @escaping (Bool, String) -> Void) {
        let eng = _WKEngine.shared
        guard eng.start() else { DispatchQueue.main.async { done(false, eng.unavailableReason) }; return }
        let req = eng.newRequestID()
        eng.storeCallbacks[req] = { r in
            let parts = r.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            done(parts.first == "ok", parts.count > 1 ? parts[1] : "")
        }
        eng.send([fields[0], "0", String(req)] + fields.dropFirst())
    }
    @objc dynamic open func compileContentRuleList(forIdentifier identifier: String, encodedContentRuleList: String, completionHandler: @escaping (WKContentRuleList?, Error?) -> Void) {
        // WebKit wants a JSON array of rules; report a malformed list the way WebKit does
        guard let d = encodedContentRuleList.data(using: .utf8), (try? JSONSerialization.jsonObject(with: d)) is [Any] else {
            DispatchQueue.main.async { completionHandler(nil, WKError(.contentRuleListStoreCompileFailed, userInfo: [NSLocalizedDescriptionKey: "Failed to parse the JSON String."])) }
            return
        }
        _op(["rulecompile", _path, identifier, encodedContentRuleList]) { ok, msg in
            completionHandler(ok ? WKContentRuleList(identifier: identifier, store: self._path) : nil,
                              ok ? nil : WKError(.contentRuleListStoreCompileFailed, userInfo: [NSLocalizedDescriptionKey: msg]))
        }
    }
    @objc dynamic open func lookUpContentRuleList(forIdentifier identifier: String, completionHandler: @escaping (WKContentRuleList?, Error?) -> Void) {
        _op(["ruleload", _path, identifier]) { ok, msg in
            completionHandler(ok ? WKContentRuleList(identifier: identifier, store: self._path) : nil,
                              ok ? nil : WKError(.contentRuleListStoreLookUpFailed, userInfo: [NSLocalizedDescriptionKey: msg]))
        }
    }
    @objc dynamic open func removeContentRuleList(forIdentifier identifier: String, completionHandler: @escaping (Error?) -> Void) {
        _op(["ruleremove", _path, identifier]) { ok, msg in
            completionHandler(ok ? nil : WKError(.contentRuleListStoreRemoveFailed, userInfo: [NSLocalizedDescriptionKey: msg]))
        }
    }
    @objc dynamic open func getAvailableContentRuleListIdentifiers(_ completionHandler: @escaping ([String]?) -> Void) {
        _op(["ruleids", _path]) { ok, json in completionHandler(ok ? (_wkJSONValue(json) as? [String]) ?? [] : nil) }
    }
    // the async forms
    public final func compileContentRuleList(forIdentifier identifier: String, encodedContentRuleList: String) async throws -> WKContentRuleList? {
        try await withCheckedThrowingContinuation { k in
            compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: encodedContentRuleList) { l, e in if let e { k.resume(throwing: e) } else { k.resume(returning: l) } }
        }
    }
    public final func contentRuleList(forIdentifier identifier: String) async throws -> WKContentRuleList? {
        try await withCheckedThrowingContinuation { k in
            lookUpContentRuleList(forIdentifier: identifier) { l, e in if let e { k.resume(throwing: e) } else { k.resume(returning: l) } }
        }
    }
    public final func removeContentRuleList(forIdentifier identifier: String) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            removeContentRuleList(forIdentifier: identifier) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    public final func availableIdentifiers() async -> [String]? {
        await withCheckedContinuation { k in getAvailableContentRuleListIdentifiers { k.resume(returning: $0) } }
    }
}

@MainActor @objc(WKUserContentController) open class WKUserContentController: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var userScripts: [WKUserScript] = []
    struct Handler { let name: String; let world: WKContentWorld; let handler: AnyObject; let withReply: Bool }
    var _handlers: [Handler] = []
    var _views: [_WKWeakView] = []
    var _ruleLists: [WKContentRuleList] = []
    public override init() { super.init() }

    func _attach(_ v: WKWebView) { _views.removeAll { $0.view == nil || $0.view === v }; _views.append(_WKWeakView(v)) }
    func _detach(_ v: WKWebView) { _views.removeAll { $0.view == nil || $0.view === v } }
    private func each(_ f: (WKWebView) -> Void) { for w in _views { if let v = w.view { f(v) } } }

    @objc dynamic open func addUserScript(_ userScript: WKUserScript) {
        userScripts.append(userScript)
        each { $0._installScript(userScript) }
    }
    @objc dynamic open func removeAllUserScripts() {
        userScripts.removeAll()
        each { $0._reinstallScripts() }
    }
    @objc(removeAllUserScriptsFromContentWorld:) dynamic open func removeAllUserScripts(from contentWorld: WKContentWorld) {
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
    @objc(addScriptMessageHandler:name:) dynamic open func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String) { addHandler(scriptMessageHandler, world: .page, name: name, reply: false) }
    @objc(addScriptMessageHandler:contentWorld:name:) dynamic open func add(_ scriptMessageHandler: WKScriptMessageHandler, contentWorld world: WKContentWorld, name: String) {
        addHandler(scriptMessageHandler, world: world, name: name, reply: false)
    }
    @objc(addScriptMessageHandlerWithReply:contentWorld:name:) dynamic open func addScriptMessageHandler(_ scriptMessageHandlerWithReply: WKScriptMessageHandlerWithReply, contentWorld: WKContentWorld, name: String) {
        addHandler(scriptMessageHandlerWithReply, world: contentWorld, name: name, reply: true)
    }
    @objc dynamic open func removeScriptMessageHandler(forName name: String) { removeScriptMessageHandler(forName: name, contentWorld: .page) }
    @objc dynamic open func removeScriptMessageHandler(forName name: String, contentWorld: WKContentWorld) {
        let gone = _handlers.filter { $0.name == name && $0.world === contentWorld }
        _handlers.removeAll { $0.name == name && $0.world === contentWorld }
        for h in gone { each { $0._removeHandler(h) } }
    }
    @objc(removeAllScriptMessageHandlersFromContentWorld:) dynamic open func removeAllScriptMessageHandlers(from contentWorld: WKContentWorld) {
        for h in _handlers where h.world === contentWorld { removeScriptMessageHandler(forName: h.name, contentWorld: contentWorld) }
    }
    @objc dynamic open func removeAllScriptMessageHandlers() { for h in _handlers { removeScriptMessageHandler(forName: h.name, contentWorld: h.world) } }
    // content blockers: applied to every web view using this controller (WebKitGTK's content filters)
    @objc(addContentRuleList:) dynamic open func add(_ contentRuleList: WKContentRuleList) {
        _ruleLists.removeAll { $0.identifier == contentRuleList.identifier }
        _ruleLists.append(contentRuleList)
        each { $0._send(["addrule", contentRuleList._store, contentRuleList.identifier]) }
    }
    @objc(removeContentRuleList:) dynamic open func remove(_ contentRuleList: WKContentRuleList) {
        _ruleLists.removeAll { $0 === contentRuleList || $0.identifier == contentRuleList.identifier }
        each { $0._send(["rmrule", contentRuleList.identifier]) }
    }
    @objc dynamic open func removeAllContentRuleLists() {
        _ruleLists.removeAll()
        each { $0._send(["clearrules"]) }
    }
}

// MARK: - navigation objects

@objc(WKNavigation) open class WKNavigation: NSObject, @unchecked Sendable {
    @objc open dynamic var effectiveContentMode: WKWebpagePreferences.ContentMode { .mobile }
}

@objc public enum WKNavigationType: Int, Sendable {
    case linkActivated = 0, formSubmitted = 1, backForward = 2, reload = 3, formResubmitted = 4, other = -1
}
@objc public enum WKNavigationActionPolicy: Int, Sendable { case cancel = 0, allow = 1, download = 2 }
@objc public enum WKNavigationResponsePolicy: Int, Sendable { case cancel = 0, allow = 1, download = 2 }

@objc(WKSecurityOrigin) open class WKSecurityOrigin: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var `protocol`: String
    @objc open private(set) dynamic var host: String
    @objc open private(set) dynamic var port: Int
    init(url: URL?) {
        `protocol` = url?.scheme ?? ""; host = url?.host ?? ""
        port = url?.port ?? 0
    }
}

@objc(WKFrameInfo) open class WKFrameInfo: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var isMainFrame: Bool
    @objc open private(set) dynamic var request: URLRequest
    @objc open private(set) dynamic var securityOrigin: WKSecurityOrigin
    @objc open private(set) weak dynamic var webView: WKWebView?
    init(main: Bool, url: URL?, webView: WKWebView?) {
        isMainFrame = main
        request = URLRequest(url: url ?? URL(string: "about:blank")!)
        securityOrigin = WKSecurityOrigin(url: url)
        self.webView = webView
    }
}

@objc(WKNavigationAction) open class WKNavigationAction: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var sourceFrame: WKFrameInfo
    @objc open private(set) dynamic var targetFrame: WKFrameInfo?
    @objc open private(set) dynamic var navigationType: WKNavigationType
    @objc open private(set) dynamic var request: URLRequest
    @objc open private(set) dynamic var modifierFlags: UIKeyModifierFlags
    @objc open private(set) dynamic var buttonNumber: Int
    @objc open dynamic var shouldPerformDownload: Bool { false }
    @objc open private(set) dynamic var isContentRuleListRedirect = false
    init(sourceFrame: WKFrameInfo, targetFrame: WKFrameInfo?, navigationType: WKNavigationType, request: URLRequest, buttonNumber: Int) {
        self.sourceFrame = sourceFrame; self.targetFrame = targetFrame; self.navigationType = navigationType
        self.request = request; modifierFlags = []; self.buttonNumber = buttonNumber
    }
}

@objc(WKNavigationResponse) open class WKNavigationResponse: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var isForMainFrame: Bool
    @objc open private(set) dynamic var response: URLResponse
    @objc open private(set) dynamic var canShowMIMEType: Bool
    init(isForMainFrame: Bool, response: URLResponse, canShowMIMEType: Bool) {
        self.isForMainFrame = isForMainFrame; self.response = response; self.canShowMIMEType = canShowMIMEType
    }
}

@objc(WKWindowFeatures) open class WKWindowFeatures: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var menuBarVisibility: NSNumber?
    @objc open private(set) dynamic var statusBarVisibility: NSNumber?
    @objc open private(set) dynamic var toolbarsVisibility: NSNumber?
    @objc open private(set) dynamic var allowsResizing: NSNumber?
    @objc open private(set) dynamic var x: NSNumber?
    @objc open private(set) dynamic var y: NSNumber?
    @objc open private(set) dynamic var width: NSNumber?
    @objc open private(set) dynamic var height: NSNumber?
}

@objc(WKBackForwardListItem) open class WKBackForwardListItem: NSObject, @unchecked Sendable {
    @objc(URL) open private(set) dynamic var url: URL
    @objc open private(set) dynamic var title: String?
    @objc open private(set) dynamic var initialURL: URL
    let _offset: Int
    init(url: URL, title: String?, initialURL: URL, offset: Int) { self.url = url; self.title = title; self.initialURL = initialURL; _offset = offset }
}

@objc(WKBackForwardList) open class WKBackForwardList: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var currentItem: WKBackForwardListItem?
    @objc open private(set) dynamic var backList: [WKBackForwardListItem] = []
    @objc open private(set) dynamic var forwardList: [WKBackForwardListItem] = []
    @objc open dynamic var backItem: WKBackForwardListItem? { backList.last }
    @objc open dynamic var forwardItem: WKBackForwardListItem? { forwardList.first }
    @objc(itemAtIndex:) dynamic open func item(at index: Int) -> WKBackForwardListItem? {
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

@objc(WKSnapshotConfiguration) open class WKSnapshotConfiguration: NSObject, @unchecked Sendable {
    @objc open dynamic var rect: CGRect = .null
    @objc open dynamic var snapshotWidth: NSNumber?
    @objc open dynamic var afterScreenUpdates = true
    public override init() { super.init() }
}
@objc(WKPDFConfiguration) open class WKPDFConfiguration: NSObject, @unchecked Sendable {
    @objc open dynamic var rect: CGRect = .null
    @objc open dynamic var allowTransparentBackground = false
    public override init() { super.init() }
}
@objc(WKFindConfiguration) open class WKFindConfiguration: NSObject, @unchecked Sendable {
    @objc open dynamic var backwards = false
    @objc open dynamic var caseSensitive = false
    @objc open dynamic var wraps = true
    public override init() { super.init() }
}
@objc(WKFindResult) open class WKFindResult: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var matchFound: Bool
    init(matchFound: Bool) { self.matchFound = matchFound }
}

// MARK: - website data

@objc(WKWebsiteDataRecord) open class WKWebsiteDataRecord: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var displayName: String
    @objc open private(set) dynamic var dataTypes: Set<String>
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

@objc(WKHTTPCookieStoreObserver) public protocol WKHTTPCookieStoreObserver: NSObjectProtocol {
    @objc(cookiesDidChangeInCookieStore:) optional func cookiesDidChange(in cookieStore: WKHTTPCookieStore)
}

/// Website data: the default store persists in the app container (Library/WebKit), the non-persistent
/// store keeps it in memory. The engine needs a live WKWebView of the store to reach its data;
/// with none, cookie calls answer from cookies set through this store in this run.
@MainActor @objc(WKWebsiteDataStore) open class WKWebsiteDataStore: NSObject, @unchecked Sendable {
    @objc public let isPersistent: Bool
    public final private(set) lazy var httpCookieStore = WKHTTPCookieStore(store: self)
    @objc open dynamic var identifier: UUID? { nil }
    @objc open dynamic var proxyConfigurations: [AnyObject] = []
    init(persistent: Bool) { isPersistent = persistent }
    static let _default = WKWebsiteDataStore(persistent: true)
    @objc(defaultDataStore) open class dynamic func `default`() -> WKWebsiteDataStore { _default }
    @objc(nonPersistentDataStore) open class dynamic func nonPersistent() -> WKWebsiteDataStore { WKWebsiteDataStore(persistent: false) }
    @objc open class dynamic func allWebsiteDataTypes() -> Set<String> {
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
    @objc dynamic open func fetchDataRecords(ofTypes dataTypes: Set<String>, completionHandler: @escaping @MainActor ([WKWebsiteDataRecord]) -> Void) {
        httpCookieStore.getAllCookies { cookies in
            var byDomain: [String: Set<String>] = [:]
            if dataTypes.contains(WKWebsiteDataTypeCookies) {
                for c in cookies { let d = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain; byDomain[d, default: []].insert(WKWebsiteDataTypeCookies) }
            }
            MainActor.assumeIsolated { completionHandler(byDomain.keys.sorted().map { WKWebsiteDataRecord(displayName: $0, dataTypes: byDomain[$0]!) }) }
        }
    }
    public final func fetchDataRecords(ofTypes dataTypes: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { c in fetchDataRecords(ofTypes: dataTypes) { c.resume(returning: $0) } }
    }
    @objc dynamic open func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date, completionHandler: @escaping @MainActor () -> Void) {
        if dataTypes.contains(WKWebsiteDataTypeCookies) { httpCookieStore._local.removeAll() }
        let since = date.timeIntervalSince1970 <= 0 ? 0 : Int(date.timeIntervalSince1970)
        _request(["cleardata", String(since)]) { _ in MainActor.assumeIsolated { completionHandler() } }
    }
    public final func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date) async {
        await withCheckedContinuation { c in removeData(ofTypes: dataTypes, modifiedSince: date) { c.resume() } }
    }
    @objc(removeDataOfTypes:forDataRecords:completionHandler:) dynamic open func removeData(ofTypes dataTypes: Set<String>, for dataRecords: [WKWebsiteDataRecord], completionHandler: @escaping @MainActor () -> Void) {
        removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: completionHandler)
    }
}

@MainActor @objc(WKHTTPCookieStore) open class WKHTTPCookieStore: NSObject, @unchecked Sendable {
    unowned let store: WKWebsiteDataStore
    var _local: [HTTPCookie] = []
    var _observers: [WKHTTPCookieStoreObserverBox] = []
    init(store: WKWebsiteDataStore) { self.store = store }
    @objc dynamic open func getAllCookies(_ completionHandler: @escaping @MainActor ([HTTPCookie]) -> Void) {
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
    public final func allCookies() async -> [HTTPCookie] { await withCheckedContinuation { c in getAllCookies { c.resume(returning: $0) } } }
    @objc dynamic open func setCookie(_ cookie: HTTPCookie, completionHandler: (@MainActor () -> Void)? = nil) {
        _local.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
        _local.append(cookie)
        let exp = cookie.expiresDate.map { String(Int($0.timeIntervalSince1970)) } ?? "0"
        store._request(["setcookie", cookie.name, cookie.value, cookie.domain, cookie.path, exp, cookie.isSecure ? "1" : "0", cookie.isHTTPOnly ? "1" : "0"]) { _ in
            MainActor.assumeIsolated { completionHandler?(); self._changed() }
        }
    }
    public final func setCookie(_ cookie: HTTPCookie) async { await withCheckedContinuation { c in setCookie(cookie) { c.resume() } } }
    @objc(deleteCookie:completionHandler:) dynamic open func delete(_ cookie: HTTPCookie, completionHandler: (@MainActor () -> Void)? = nil) {
        _local.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
        store._request(["delcookie", cookie.name, cookie.value, cookie.domain, cookie.path, "0", "0", "0"]) { _ in
            MainActor.assumeIsolated { completionHandler?(); self._changed() }
        }
    }
    public final func deleteCookie(_ cookie: HTTPCookie) async { await withCheckedContinuation { c in delete(cookie) { c.resume() } } }
    @objc(addObserver:) dynamic open func add(_ observer: WKHTTPCookieStoreObserver) { _observers.append(WKHTTPCookieStoreObserverBox(observer)) }
    @objc(removeObserver:) dynamic open func remove(_ observer: WKHTTPCookieStoreObserver) { _observers.removeAll { $0.o == nil || $0.o === observer } }
    func _changed() { for b in _observers { b.o?.cookiesDidChange?(in: self) } }
}
final class WKHTTPCookieStoreObserverBox { weak var o: WKHTTPCookieStoreObserver?; init(_ o: WKHTTPCookieStoreObserver) { self.o = o } }
