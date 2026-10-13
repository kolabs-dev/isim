// isim WebKit for SwiftUI (iOS 26): WebPage, an observable page backed by a WKWebView, and WebView, the view that
// shows it (a UIViewRepresentable around that WKWebView). Loads report their navigation events as an async
// sequence; title, URL, loading state and progress are observable; callJavaScript, pdf, snapshot and webArchiveData
// go to the web view. Adapted: the navigation decider and dialog presenter protocols are not offered (the defaults:
// every navigation is allowed, JavaScript dialogs show as alerts only when a UI delegate is set — here, none).
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

    public convenience init() { self.init(configuration: Configuration()) }
    public init(configuration: Configuration) {
        self.configuration = configuration
        let c = WKWebViewConfiguration()
        c.websiteDataStore = configuration.websiteDataStore
        c.userContentController = configuration.userContentController
        c.applicationNameForUserAgent = configuration.applicationNameForUserAgent
        for (scheme, handler) in configuration.urlSchemeHandlers { c.setURLSchemeHandler(_WebPageSchemeHandler(handler), forURLScheme: scheme.rawValue) }
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), configuration: c)
        bridge.page = self
        webView.navigationDelegate = bridge
        observations = [
            webView.observe(\.title) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.title) { self?._title = w.title ?? "" } } },
            webView.observe(\.url) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.url) { self?._url = w.url } } },
            webView.observe(\.isLoading) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.isLoading) { self?._isLoading = w.isLoading } } },
            webView.observe(\.estimatedProgress) { [weak self] w, _ in MainActor.assumeIsolated { self?.update(\.estimatedProgress) { self?._progress = w.estimatedProgress } } },
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
final class _WebPageBridge: NSObject, WKNavigationDelegate {
    weak var page: WebPage?
    var stream: AsyncThrowingStream<WebPage.NavigationEvent, any Error>.Continuation?
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
