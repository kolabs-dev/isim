// isim WebKit for SwiftUI (iOS 26): WebPage, an observable page backed by a WKWebView, and WebView, the view that
// shows it (a UIViewRepresentable around that WKWebView). Loads report their navigation events as an async
// sequence; title, URL, loading state and progress are observable; callJavaScript, pdf, snapshot and webArchiveData
// go to the web view. A NavigationDeciding decides navigations, responses and authentication challenges; a
// DialogPresenting answers JavaScript alerts, confirms, prompts and file inputs (issue #421). Without them: every
// navigation is allowed, the default challenge handling applies, dialogs are dismissed and file inputs get nothing.
import SwiftUI
import UIKit
import Observation

@available(iOS 26.0, *)
@MainActor
public final class WebPage: Observable {
    /// how a page is set up (the subset of WKWebViewConfiguration iOS 26 exposes)
    @MainActor public struct Configuration {
        public var websiteDataStore: WKWebsiteDataStore = .default()
        public var userContentController = WKUserContentController()
        public var applicationNameForUserAgent: String?
        public var urlSchemeHandlers: [URLScheme: any URLSchemeHandler] = [:]
        public var limitsNavigationsToAppBoundDomains = false
        public var upgradeKnownHostsToHTTPS = true
        /// the web extensions whose content scripts run in the page (issue #791)
        public var webExtensionController: WKWebExtensionController?
        public init() {}
    }
    /// a custom URL scheme a page serves itself (Configuration.urlSchemeHandlers)
    public struct URLScheme: Hashable, Sendable {
        public let rawValue: String
        public init?(_ rawValue: String) {
            let builtin: Set<String> = ["http", "https", "file", "data", "about", "blob", "javascript", "ws", "wss"]
            guard !rawValue.isEmpty, !builtin.contains(rawValue.lowercased()) else { return nil }
            self.rawValue = rawValue.lowercased()
        }
    }
    public enum NavigationEvent: Hashable, Sendable {
        case startedProvisionalNavigation, receivedServerRedirect, committed, finished
    }
    public enum NavigationError: Error, Sendable {
        case failedProvisionalNavigation(any Error)
        case pageClosed
        case webContentProcessTerminated
        case invalidURL
    }

    // observable state
    private let _registrar = ObservationRegistrar()
    private var _title = "", _url: URL?, _isLoading = false, _progress = 0.0, _event: NavigationEvent?
    public var title: String { _registrar.access(self, keyPath: \.title); return _title }
    public var url: URL? { _registrar.access(self, keyPath: \.url); return _url }
    public var isLoading: Bool { _registrar.access(self, keyPath: \.isLoading); return _isLoading }
    public var estimatedProgress: Double { _registrar.access(self, keyPath: \.estimatedProgress); return _progress }
    public var currentNavigationEvent: NavigationEvent? { _registrar.access(self, keyPath: \.currentNavigationEvent); return _event }
    public var hasOnlySecureContent: Bool { webView.hasOnlySecureContent }
    public var customUserAgent: String? { get { webView.customUserAgent } set { webView.customUserAgent = newValue } }
    public var isInspectable: Bool { get { webView.isInspectable } set { webView.isInspectable = newValue } }
    public var mediaType: String? { get { webView.mediaType } set { webView.mediaType = newValue } }
    public var backForwardList: WKBackForwardList { webView.backForwardList }

    public let configuration: Configuration
    let webView: WKWebView
    private let bridge = _WebPageBridge()
    private var observations: [NSKeyValueObservation] = []
    private var _fullscreen: FullscreenState = .notInFullscreen
    public var fullscreenState: FullscreenState { _registrar.access(self, keyPath: \.fullscreenState); return _fullscreen }

    public convenience init() { self.init(configuration: Configuration()) }
    public convenience init(configuration: Configuration, navigationDecider: some NavigationDeciding) {
        self.init(configuration: configuration)
        bridge.decider = navigationDecider
    }
    public convenience init(configuration: Configuration, dialogPresenter: some DialogPresenting) {
        self.init(configuration: configuration)
        bridge.presenter = dialogPresenter
    }
    public convenience init(configuration: Configuration, navigationDecider: some NavigationDeciding,
                            dialogPresenter: some DialogPresenting) {
        self.init(configuration: configuration)
        bridge.decider = navigationDecider
        bridge.presenter = dialogPresenter
    }
    public init(configuration: Configuration) {
        self.configuration = configuration
        let c = WKWebViewConfiguration()
        c.websiteDataStore = configuration.websiteDataStore
        c.userContentController = configuration.userContentController
        c.applicationNameForUserAgent = configuration.applicationNameForUserAgent
        c.webExtensionController = configuration.webExtensionController
        for (scheme, handler) in configuration.urlSchemeHandlers { c.setURLSchemeHandler(_WebPageSchemeHandler(handler), forURLScheme: scheme.rawValue) }
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), configuration: c)
        bridge.page = self
        webView.navigationDelegate = bridge
        webView.uiDelegate = bridge
        observations = [
            webView.observe(\.title) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.title) { self?._title = w.title ?? "" } } },
            webView.observe(\.url) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.url) { self?._url = w.url } } },
            webView.observe(\.isLoading) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.isLoading) { self?._isLoading = w.isLoading } } },
            webView.observe(\.estimatedProgress) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.estimatedProgress) { self?._progress = w.estimatedProgress } } },
            webView.observe(\.fullscreenState) { [weak self] w, _ in
                MainActor.assumeIsolated { self?.update(\.fullscreenState) { self?._fullscreen = FullscreenState(rawValue: w.fullscreenState.rawValue) ?? .notInFullscreen } }
            },
        ]
    }
    private func update<T>(_ kp: KeyPath<WebPage, T>, _ change: () -> Void) { _registrar.withMutation(of: self, keyPath: kp, change) }

    func event(_ e: NavigationEvent) {
        update(\.currentNavigationEvent) { _event = e }
        bridge.stream?.yield(e)
        if e == .finished { bridge.stream?.finish(); bridge.stream = nil }
    }
    func failed(_ error: any Error) {
        bridge.stream?.finish(throwing: NavigationError.failedProvisionalNavigation(error)); bridge.stream = nil
    }

    // MARK: loading
    /// the load's navigation events, ending after .finished (or throwing on failure)
    @discardableResult
    public func load(_ request: URLRequest) -> AsyncThrowingStream<NavigationEvent, any Error> {
        stream { webView.load(request) }
    }
    @discardableResult
    public func load(_ url: URL) -> AsyncThrowingStream<NavigationEvent, any Error> { load(URLRequest(url: url)) }
    @discardableResult
    public func load(html: String, baseURL: URL = URL(string: "about:blank")!) -> AsyncThrowingStream<NavigationEvent, any Error> {
        stream { webView.loadHTMLString(html, baseURL: baseURL) }
    }
    @discardableResult
    public func load(_ data: Data, mimeType: String, characterEncoding: String.Encoding, baseURL: URL) -> AsyncThrowingStream<NavigationEvent, any Error> {
        let name = characterEncoding == .utf8 ? "utf-8" : characterEncoding == .isoLatin1 ? "iso-8859-1" : "utf-8"
        return stream { webView.load(data, mimeType: mimeType, characterEncodingName: name, baseURL: baseURL) }
    }
    @discardableResult
    public func load(_ item: WKBackForwardListItem) -> AsyncThrowingStream<NavigationEvent, any Error> { stream { webView.go(to: item) } }
    @discardableResult
    public func reload(fromOrigin: Bool = false) -> AsyncThrowingStream<NavigationEvent, any Error> {
        stream { if fromOrigin { webView.reloadFromOrigin() } else { webView.reload() } }
    }
    public func stopLoading() { webView.stopLoading() }
    private func stream(_ start: () -> Void) -> AsyncThrowingStream<NavigationEvent, any Error> {
        bridge.stream?.finish()
        let (s, c) = AsyncThrowingStream<NavigationEvent, any Error>.makeStream()
        bridge.stream = c
        start()
        return s
    }

    // MARK: JavaScript, images and documents
    /// functionBody runs as an async JavaScript function with arguments as its parameters
    public func callJavaScript(_ functionBody: String, arguments: [String: Any] = [:], in frame: WKFrameInfo? = nil,
                               contentWorld: WKContentWorld = .page) async throws -> Any? {
        try await webView.callAsyncJavaScript(functionBody, arguments: arguments, in: frame, contentWorld: contentWorld)
    }
    public func pdf(configuration: WKPDFConfiguration = WKPDFConfiguration()) async throws -> Data {
        try await webView.createPDF(configuration: configuration)
    }
    public func snapshot(_ configuration: WKSnapshotConfiguration = WKSnapshotConfiguration()) async throws -> UIImage {
        try await webView.takeSnapshot(configuration: configuration)
    }
    public func webArchiveData() async throws -> Data { try await webView.webArchiveData() }
    public func find(_ string: String, configuration: WKFindConfiguration = WKFindConfiguration()) async throws -> WKFindResult {
        try await webView.find(string, configuration: configuration)
    }
}

// MARK: - navigation decisions and dialogs (issue #421)

@available(iOS 26.0, *)
extension WebPage {
    public enum FullscreenState: Int, Sendable, Hashable { case notInFullscreen = 0, enteringFullscreen, inFullscreen, exitingFullscreen }

    /// a frame that started a navigation or a dialog
    public struct FrameInfo: Sendable {
        public let isMainFrame: Bool
        public let request: URLRequest
        public let securityOrigin: WKSecurityOrigin
        init(_ f: WKFrameInfo) { isMainFrame = f.isMainFrame; request = f.request; securityOrigin = f.securityOrigin }
    }
    public struct NavigationAction: Sendable {
        public let source: FrameInfo
        public let target: FrameInfo?
        public let navigationType: WKNavigationType
        public let request: URLRequest
        public let modifierFlags: EventModifiers
        public let buttonNumber: UIEvent.ButtonMask
        public let shouldPerformDownload: Bool
        public let isContentRuleListRedirect: Bool
        init(_ a: WKNavigationAction) {
            source = FrameInfo(a.sourceFrame); target = a.targetFrame.map(FrameInfo.init); navigationType = a.navigationType; request = a.request
            var m: EventModifiers = []
            if a.modifierFlags.contains(.shift) { m.insert(.shift) }
            if a.modifierFlags.contains(.control) { m.insert(.control) }
            if a.modifierFlags.contains(.alternate) { m.insert(.option) }
            if a.modifierFlags.contains(.command) { m.insert(.command) }
            modifierFlags = m
            buttonNumber = a.buttonNumber > 0 ? UIEvent.ButtonMask(rawValue: 1 << (a.buttonNumber - 1)) : []
            shouldPerformDownload = a.shouldPerformDownload; isContentRuleListRedirect = a.isContentRuleListRedirect
        }
    }
    public struct NavigationResponse: Sendable {
        public let response: URLResponse
        public let canShowMimeType: Bool
        init(_ r: WKNavigationResponse) { response = r.response; canShowMimeType = r.canShowMIMEType }
    }
    /// the page settings a navigation decision may change
    public struct NavigationPreferences: Sendable {
        public enum ContentMode: Sendable, Hashable { case recommended, mobile, desktop }
        public enum UpgradeToHTTPSPolicy: Sendable, Hashable { case keepAsRequested, automaticFallbackToHTTP, userMediatedFallbackToHTTP, errorOnFailure }
        @available(iOS 26.4, *)
        public enum SecurityRestrictionMode: Sendable, Hashable { case none, maximizeCompatibility, lockdown }
        public var preferredContentMode: ContentMode = .recommended
        public var allowsContentJavaScript = true
        public var isLockdownModeEnabled = false
        public var preferredHTTPSNavigationPolicy: UpgradeToHTTPSPolicy = .keepAsRequested
        var _restriction = 0
        @available(iOS 26.4, *)
        public var securityRestrictionMode: SecurityRestrictionMode {
            get { [.none, .maximizeCompatibility, .lockdown][_restriction] }
            set { _restriction = newValue == .lockdown ? 2 : newValue == .maximizeCompatibility ? 1 : 0; isLockdownModeEnabled = newValue == .lockdown }
        }
        public init() {}
        init(_ p: WKWebpagePreferences) {
            preferredContentMode = p.preferredContentMode == .desktop ? .desktop : p.preferredContentMode == .mobile ? .mobile : .recommended
            allowsContentJavaScript = p.allowsContentJavaScript
            isLockdownModeEnabled = p.isLockdownModeEnabled
            preferredHTTPSNavigationPolicy = [.keepAsRequested, .automaticFallbackToHTTP, .userMediatedFallbackToHTTP, .errorOnFailure][min(max(p._httpsPolicy, 0), 3)]
            _restriction = p.isLockdownModeEnabled ? 2 : 0
        }
        func apply(to p: WKWebpagePreferences) {
            p.preferredContentMode = preferredContentMode == .desktop ? .desktop : preferredContentMode == .mobile ? .mobile : .recommended
            p.allowsContentJavaScript = allowsContentJavaScript
            p.isLockdownModeEnabled = isLockdownModeEnabled
            p._httpsPolicy = [.keepAsRequested, .automaticFallbackToHTTP, .userMediatedFallbackToHTTP, .errorOnFailure].firstIndex(of: preferredHTTPSNavigationPolicy) ?? 0
        }
    }

    /// decides the page's navigations, responses and authentication challenges
    @MainActor public protocol NavigationDeciding {
        func decidePolicy(for action: NavigationAction, preferences: inout NavigationPreferences) async -> WKNavigationActionPolicy
        func decidePolicy(for response: NavigationResponse) async -> WKNavigationResponsePolicy
        func decideAuthenticationChallengeDisposition(for challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
    }

    public enum JavaScriptConfirmResult: Sendable, Hashable { case ok, cancel }
    public enum JavaScriptPromptResult: Sendable, Hashable { case ok(String), cancel }
    public enum FileInputPromptResult: Sendable, Hashable { case selected([URL]), cancel }

    /// answers the page's JavaScript dialogs and file inputs
    @MainActor public protocol DialogPresenting {
        func handleJavaScriptAlert(message: String, initiatedBy frame: FrameInfo) async
        func handleJavaScriptConfirm(message: String, initiatedBy frame: FrameInfo) async -> JavaScriptConfirmResult
        func handleJavaScriptPrompt(message: String, defaultText: String?, initiatedBy frame: FrameInfo) async -> JavaScriptPromptResult
        func handleFileInputPrompt(parameters: WKOpenPanelParameters, initiatedBy frame: FrameInfo) async -> FileInputPromptResult
    }
}

@available(iOS 26.0, *)
extension WebPage.NavigationDeciding {
    public func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy { .allow }
    public func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy { .allow }
    public func decideAuthenticationChallengeDisposition(for challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
}

@available(iOS 26.0, *)
extension WebPage.DialogPresenting {
    public func handleJavaScriptAlert(message: String, initiatedBy frame: WebPage.FrameInfo) async {}
    public func handleJavaScriptConfirm(message: String, initiatedBy frame: WebPage.FrameInfo) async -> WebPage.JavaScriptConfirmResult { .cancel }
    public func handleJavaScriptPrompt(message: String, defaultText: String?, initiatedBy frame: WebPage.FrameInfo) async -> WebPage.JavaScriptPromptResult { .cancel }
    public func handleFileInputPrompt(parameters: WKOpenPanelParameters, initiatedBy frame: WebPage.FrameInfo) async -> WebPage.FileInputPromptResult { .cancel }
}

/// a URL scheme's content for a WebPage (iOS 26): a sequence of the response and data
@available(iOS 26.0, *)
public protocol URLSchemeHandler {
    associatedtype TaskSequence: AsyncSequence where TaskSequence.Element == URLSchemeTaskResult
    func reply(for request: URLRequest) -> TaskSequence
}
@available(iOS 26.0, *)
public enum URLSchemeTaskResult: Sendable {
    case response(URLResponse)
    case data(Data)
}

/// WKURLSchemeHandler -> URLSchemeHandler
@available(iOS 26.0, *)
final class _WebPageSchemeHandler: NSObject, WKURLSchemeHandler {
    let handler: any URLSchemeHandler
    var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    init(_ h: any URLSchemeHandler) { handler = h }
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        nonisolated(unsafe) let task = urlSchemeTask
        nonisolated(unsafe) let h = handler
        let request = urlSchemeTask.request
        tasks[ObjectIdentifier(urlSchemeTask)] = Task { @MainActor in
            do { try await Self.pump(h, request, task); task.didFinish() } catch { task.didFailWithError(error) }
        }
    }
    @MainActor static func pump<H: URLSchemeHandler>(_ h: H, _ request: URLRequest, _ task: WKURLSchemeTask) async throws {
        for try await item in h.reply(for: request) {
            switch item { case .response(let r): task.didReceive(r); case .data(let d): task.didReceive(d) }
        }
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel() }
}

/// the page's navigation delegate: events to the current load's sequence
@available(iOS 26.0, *)
final class _WebPageBridge: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var page: WebPage?
    var stream: AsyncThrowingStream<WebPage.NavigationEvent, any Error>.Continuation?
    var decider: (any WebPage.NavigationDeciding)?
    var presenter: (any WebPage.DialogPresenting)?

    // the navigation decider (none: allow, default handling)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        guard let d = decider else { decisionHandler(.allow, preferences); return }
        nonisolated(unsafe) let handler = decisionHandler
        Task { @MainActor in
            var prefs = WebPage.NavigationPreferences(preferences)
            let policy = await d.decidePolicy(for: WebPage.NavigationAction(navigationAction), preferences: &prefs)
            prefs.apply(to: preferences)
            handler(policy, preferences)
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let d = decider else { decisionHandler(.allow); return }
        nonisolated(unsafe) let handler = decisionHandler
        Task { @MainActor in handler(await d.decidePolicy(for: WebPage.NavigationResponse(navigationResponse))) }
    }
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let d = decider else { completionHandler(.performDefaultHandling, nil); return }
        nonisolated(unsafe) let handler = completionHandler
        Task { @MainActor in let (disposition, credential) = await d.decideAuthenticationChallengeDisposition(for: challenge); handler(disposition, credential) }
    }

    // the dialog presenter (none: dismissed)
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        guard let p = presenter else { completionHandler(); return }
        nonisolated(unsafe) let handler = completionHandler
        Task { @MainActor in await p.handleJavaScriptAlert(message: message, initiatedBy: WebPage.FrameInfo(frame)); handler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        guard let p = presenter else { completionHandler(false); return }
        nonisolated(unsafe) let handler = completionHandler
        Task { @MainActor in handler(await p.handleJavaScriptConfirm(message: message, initiatedBy: WebPage.FrameInfo(frame)) == .ok) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard let p = presenter else { completionHandler(nil); return }
        nonisolated(unsafe) let handler = completionHandler
        Task { @MainActor in
            switch await p.handleJavaScriptPrompt(message: prompt, defaultText: defaultText, initiatedBy: WebPage.FrameInfo(frame)) {
            case .ok(let text): handler(text)
            case .cancel: handler(nil)
            }
        }
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        guard let p = presenter else { completionHandler(nil); return }
        nonisolated(unsafe) let handler = completionHandler
        Task { @MainActor in
            switch await p.handleFileInputPrompt(parameters: parameters, initiatedBy: WebPage.FrameInfo(frame)) {
            case .selected(let urls): handler(urls)
            case .cancel: handler(nil)
            }
        }
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { page?.event(.startedProvisionalNavigation) }
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) { page?.event(.receivedServerRedirect) }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { page?.event(.committed) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { page?.event(.finished) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { page?.failed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { page?.failed(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        stream?.finish(throwing: WebPage.NavigationError.webContentProcessTerminated); stream = nil
    }
}

/// shows a WebPage (iOS 26)
@available(iOS 26.0, *)
public struct WebView: View {
    let page: WebPage?
    let initialURL: URL?
    @State private var own: WebPage?
    public init(_ page: WebPage) { self.page = page; initialURL = nil }
    public init(url: URL?) { page = nil; initialURL = url }
    public var body: some View {
        _WebViewRepresentable(page: page ?? own ?? fallback())
            .onAppear {
                if page == nil, own == nil {
                    let p = WebPage()
                    own = p
                    if let u = initialURL { p.load(URLRequest(url: u)) }
                }
            }
    }
    private func fallback() -> WebPage { _webViewPlaceholder }
}
@available(iOS 26.0, *)
@MainActor let _webViewPlaceholder = WebPage()

@available(iOS 26.0, *)
struct _WebViewRepresentable: UIViewRepresentable {
    let page: WebPage
    func makeUIView(context: Context) -> WKWebView { apply(page.webView, context); return page.webView }
    func updateUIView(_ w: WKWebView, context: Context) { apply(w, context) }
    func apply(_ w: WKWebView, _ context: Context) {
        let e = context.environment
        w.allowsBackForwardNavigationGestures = e._webViewBackForward
        w.allowsLinkPreview = e._webViewLinkPreviews
        w.scrollView.pinchGestureRecognizer?.isEnabled = e._webViewMagnification
        w._magnificationAllowed = e._webViewMagnification
        w.isOpaque = e._webViewBackground
    }
}

// MARK: - modifiers

@available(iOS 26.0, *)
public struct WebViewBehavior: Sendable, Equatable {
    let on: Bool
    public static let automatic = WebViewBehavior(on: true)
    public static let enabled = WebViewBehavior(on: true)
    public static let disabled = WebViewBehavior(on: false)
}
struct _WebViewBackForwardKey: EnvironmentKey { static let defaultValue = false }
struct _WebViewLinkPreviewsKey: EnvironmentKey { static let defaultValue = true }
struct _WebViewMagnificationKey: EnvironmentKey { static let defaultValue = true }
struct _WebViewBackgroundKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var _webViewBackForward: Bool { get { self[_WebViewBackForwardKey.self] } set { self[_WebViewBackForwardKey.self] = newValue } }
    var _webViewLinkPreviews: Bool { get { self[_WebViewLinkPreviewsKey.self] } set { self[_WebViewLinkPreviewsKey.self] = newValue } }
    var _webViewMagnification: Bool { get { self[_WebViewMagnificationKey.self] } set { self[_WebViewMagnificationKey.self] = newValue } }
    var _webViewBackground: Bool { get { self[_WebViewBackgroundKey.self] } set { self[_WebViewBackgroundKey.self] = newValue } }
}
@available(iOS 26.0, *)
extension View {
    public func webViewBackForwardNavigationGestures(_ behavior: WebViewBehavior) -> some View { environment(\._webViewBackForward, behavior.on) }
    public func webViewLinkPreviews(_ behavior: WebViewBehavior) -> some View { environment(\._webViewLinkPreviews, behavior.on) }
    public func webViewMagnificationGestures(_ behavior: WebViewBehavior) -> some View { environment(\._webViewMagnification, behavior.on) }
    public func webViewContentBackground(_ visibility: Visibility) -> some View { environment(\._webViewBackground, visibility != .hidden) }
}
