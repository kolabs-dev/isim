// isim WebKit: WKWebView and its delegate protocols.
//
// The page is rendered by real WebKit (the host's WebKitGTK, see Engine.swift) and drawn by the web
// view's scroll view from frames the engine sends. Adapted parts, compared with iOS:
// - layout: the page is laid out at the view's width in CSS pixels (= points); WebKitGTK has no
//   mobile 980-px virtual viewport, so pages without <meta name=viewport> are not zoomed out;
// - input: taps, typing and scrolling reach the page as DOM events made from an isolated JavaScript
//   world (`isTrusted` is false); select pop-ups, text selection, long-press menus and pinch zoom are absent;
// - scroll view: `scrollView` mirrors the page scroll (contentSize, contentOffset); dragging it scrolls
//   the page; nested scrollable elements are not scrolled by drags;
// - `load(_:)` performs GET requests (the request's headers are sent; method and body are not).
import UIKit
import isim_host

// MARK: - delegates

@objc public protocol WKNavigationDelegate: NSObjectProtocol {
    @MainActor @objc(webView:decidePolicyForNavigationAction:decisionHandler:) optional func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                                           decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    @MainActor @objc(webView:decidePolicyForNavigationAction:preferences:decisionHandler:) optional func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences,
                                           decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void)
    @MainActor @objc(webView:decidePolicyForNavigationAction:completionHandler:) optional func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy
    @MainActor @objc(webView:decidePolicyForNavigationResponse:decisionHandler:) optional func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                                           decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void)
    @MainActor @objc(webView:decidePolicyForNavigationResponse:completionHandler:) optional func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy
    @MainActor @objc optional func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
    @MainActor @objc optional func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!)
    @MainActor @objc optional func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
    @MainActor @objc optional func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!)
    @MainActor @objc optional func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
    @MainActor @objc optional func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
    @MainActor @objc optional func webViewWebContentProcessDidTerminate(_ webView: WKWebView)
}

@objc public protocol WKUIDelegate: NSObjectProtocol {
    @MainActor @objc optional func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                                           for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView?
    @MainActor @objc optional func webViewDidClose(_ webView: WKWebView)
    @MainActor @objc optional func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                                           completionHandler: @escaping () -> Void)
    @MainActor @objc(webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:asyncCompletionHandler:) optional func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async
    @MainActor @objc optional func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                                           completionHandler: @escaping (Bool) -> Void)
    @MainActor @objc(webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:asyncCompletionHandler:) optional func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool
    @MainActor @objc optional func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                                           initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void)
    @MainActor @objc(webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:asyncCompletionHandler:) optional func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                                           initiatedByFrame frame: WKFrameInfo) async -> String?
}

// MARK: - scroll view

/// The web view's scroll view: draws the page frames and turns drags into page scrolling, taps into clicks.
final class _WKScrollView: UIScrollView, UIScrollViewDelegate {
    weak var web: WKWebView?
    var applyingPage = false
    var lastUserScroll = 0.0
    var touchDown = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .clear
        contentInsetAdjustmentBehavior = .never
        super.delegate = self
    }
    required init?(coder: NSCoder) { fatalError() }
    weak var _outerDelegate: UIScrollViewDelegate?
    override var delegate: UIScrollViewDelegate? {
        get { _outerDelegate }
        set { _outerDelegate = newValue }
    }
    /// the page area origin (content coordinates) and the page scroll position it shows
    var pageOrigin: CGPoint {
        let maxX = max(0, contentSize.width - bounds.width), maxY = max(0, contentSize.height - bounds.height)
        return CGPoint(x: min(max(contentOffset.x, 0), maxX), y: min(max(contentOffset.y, 0), maxY))
    }
    override func draw(_ rect: CGRect) {
        web?._drawPage(in: self)
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        setNeedsDisplay()
        if !applyingPage, let w = web {
            lastUserScroll = isim_time()
            let o = pageOrigin
            w._send(["scrollto", _WKProto.num((o.x / w.pageZoom).rounded()), _WKProto.num((o.y / w.pageZoom).rounded())])
        }
        _outerDelegate?.scrollViewDidScroll?(scrollView)
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { _outerDelegate?.scrollViewWillBeginDragging?(scrollView) }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { _outerDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate) }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { _outerDelegate?.scrollViewDidEndDecelerating?(scrollView) }
    /// the page moved itself (script, anchor, focus): follow it unless the user is scrolling
    func pageScrolled(x: Double, y: Double, width: Double, height: Double) {
        guard let w = web else { return }
        let z = w.pageZoom
        applyingPage = true
        let cs = CGSize(width: max(bounds.width, width * z), height: max(bounds.height, height * z))
        if contentSize != cs { contentSize = cs }
        if !isTracking && !isDragging && !isDecelerating && isim_time() - lastUserScroll > 0.4 {
            let o = CGPoint(x: x * z, y: y * z)
            if abs(o.x - contentOffset.x) > 0.5 || abs(o.y - contentOffset.y) > 0.5 { contentOffset = o }
        }
        applyingPage = false
        setNeedsDisplay()
    }
    func pagePoint(_ t: UITouch) -> CGPoint {
        let p = t.location(in: self), o = pageOrigin, z = web?.pageZoom ?? 1
        return CGPoint(x: (p.x - o.x) / z, y: (p.y - o.y) / z)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let w = web else { return }
        touchDown = true
        w._tap(pagePoint(t), phase: "down")
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let w = web, touchDown else { return }
        touchDown = false
        w._tap(pagePoint(t), phase: "up")
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let w = web, touchDown else { return }
        touchDown = false
        w._tap(pagePoint(t), phase: "cancel")
    }
}

// MARK: - WKWebView

@MainActor
open class WKWebView: UIView, UIKeyInput {
    open private(set) var configuration: WKWebViewConfiguration
    open weak var navigationDelegate: WKNavigationDelegate?
    open weak var uiDelegate: WKUIDelegate?
    open private(set) var backForwardList = WKBackForwardList()
    public var scrollView: UIScrollView { _scroll }
    let _scroll = _WKScrollView(frame: .zero)

    // KVO-observable like WebKit's (key paths work without warnings); the class posts the change notifications itself
    @objc open private(set) dynamic var title: String?
    @objc(URL) open private(set) dynamic var url: URL?
    @objc open private(set) dynamic var isLoading = false
    @objc open private(set) dynamic var estimatedProgress: Double = 0
    @objc open private(set) dynamic var canGoBack = false
    @objc open private(set) dynamic var canGoForward = false
    @objc open private(set) dynamic var hasOnlySecureContent = false
    @objc open private(set) dynamic var themeColor: UIColor?
    @objc open var underPageBackgroundColor: UIColor! = .systemBackground
    open var customUserAgent: String? { didSet { _send(["ua", _userAgent]) } }
    open var allowsBackForwardNavigationGestures = false
    open var allowsLinkPreview = true
    open var allowsMagnification = false
    open var isInspectable = false
    open var isFindInteractionEnabled = false
    open var interactionState: Any?
    open var mediaType: String?
    open var pageZoom: CGFloat = 1 { didSet { _send(["zoom", _WKProto.num(Double(pageZoom))]) } }
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool {
        ["title", "URL", "isLoading", "estimatedProgress", "canGoBack", "canGoForward", "hasOnlySecureContent", "themeColor"].contains(key) ? false : super.automaticallyNotifiesObservers(forKey: key)
    }

    // engine state
    var _engineID = 0
    var _engineReady = false
    var _engineSize: CGSize = .zero
    var _frameImage: Int32 = 0
    var _framePixels = CGSize.zero
    var _pending: [[String]] = []
    var _currentNavigation: WKNavigation?
    var _requestedNavigation: WKNavigation?
    var _jsCallbacks: [Int: (Result<Any?, Error>) -> Void] = [:]
    var _nextJS = 1
    var _editing = false
    var _closed = false
    var _lastFailedURL: URL?
    var _htmlBaseURL: URL?   /* loadHTMLString/load(data:): the engine reports about:blank for its policy check */
    nonisolated(unsafe) static var _all: [Int: _WKWeakView] = [:]
    static func _live(_ id: Int) -> WKWebView? { _all[id]?.view }

    public init(frame: CGRect, configuration: WKWebViewConfiguration) {
        self.configuration = configuration.copy() as! WKWebViewConfiguration
        super.init(frame: frame)
        _setup()
    }
    public override convenience init(frame: CGRect) { self.init(frame: frame, configuration: WKWebViewConfiguration()) }
    public required init?(coder: NSCoder) { configuration = WKWebViewConfiguration(); super.init(coder: coder); _setup() }
    deinit {
        let id = _engineID
        if id != 0 {
            _WKEngine.shared.send(["close", String(id)])
            isim_web_release(Int32(id))
            _WKEngine.shared.unregister(id)
            WKWebView._all[id] = nil
        }
    }

    private func _setup() {
        backgroundColor = .white
        _scroll.web = self
        _scroll.frame = bounds
        addSubview(_scroll)
        configuration.userContentController._attach(self)
        configuration.websiteDataStore._views.append(_WKWeakView(self))
        _startEngine()
    }

    var _userAgent: String {
        if let customUserAgent, !customUserAgent.isEmpty { return customUserAgent }
        let ver = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        var ua = pad ? "Mozilla/5.0 (iPad; CPU OS \(ver) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)"
                     : "Mozilla/5.0 (iPhone; CPU iPhone OS \(ver) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)"
        if let app = configuration.applicationNameForUserAgent, !app.isEmpty { ua += " " + app }
        return ua
    }

    private func _startEngine() {
        guard _WKEngine.shared.start() else { return }
        _engineID = _WKEngine.shared.register(self)
        WKWebView._all[_engineID] = _WKWeakView(self)
        let size = _viewportSize()
        _engineSize = size
        let store = configuration.websiteDataStore
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/WebKit")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        for s in configuration._schemeHandlers.keys.sorted() { _WKEngine.shared.send(["scheme", "0", s]) }
        let js = configuration.defaultWebpagePreferences.allowsContentJavaScript
        _WKEngine.shared.send(["new", String(_engineID), _WKProto.num(Double(size.width)), _WKProto.num(Double(size.height)),
                               _WKProto.num(Double(UIScreen.main.scale)), store.isPersistent ? "0" : "1", dir, _userAgent, js ? "1" : "0", _bgString()])
        for s in configuration.userContentController.userScripts { _installScript(s) }
        for h in configuration.userContentController._handlers { _installHandler(h) }
    }
    private func _bgString() -> String {
        if !isOpaque { return "rgba(0,0,0,0)" }
        guard let c = backgroundColor else { return "" }
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "rgba(\(Int(r * 255)),\(Int(g * 255)),\(Int(b * 255)),\(a))"
    }
    open override var isOpaque: Bool { didSet { _send(["bg", _bgString()]) } }
    open override var backgroundColor: UIColor? { didSet { if _engineID != 0 { _send(["bg", _bgString()]) } } }

    func _send(_ fields: [String]) {
        guard _engineID != 0 else { return }
        var f = fields
        f.insert(String(_engineID), at: 1)
        _WKEngine.shared.send(f)
    }
    func _installScript(_ s: WKUserScript) {
        _send(["script", s._world._engineName, s.injectionTime == .atDocumentEnd ? "1" : "0", s.isForMainFrameOnly ? "1" : "0", s.source])
    }
    func _reinstallScripts() {
        _send(["clearscripts"])
        for s in configuration.userContentController.userScripts { _installScript(s) }
    }
    func _installHandler(_ h: WKUserContentController.Handler) { _send(["handler", h.world._engineName, h.name, h.withReply ? "1" : "0"]) }
    func _removeHandler(_ h: WKUserContentController.Handler) { _send(["rmhandler", h.world._engineName, h.name]) }

    // MARK: layout and drawing
    func _viewportSize() -> CGSize {
        var b = bounds.size
        if b.width < 1 || b.height < 1 { b = UIScreen.main.bounds.size }
        let i = _scroll.adjustedContentInset
        return CGSize(width: max(1, b.width - i.left - i.right), height: max(1, b.height - i.top - i.bottom))
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        _scroll.frame = bounds
        let size = _viewportSize()
        if bounds.width >= 1, bounds.height >= 1, size != _engineSize {
            _engineSize = size
            _send(["size", _WKProto.num(Double(size.width)), _WKProto.num(Double(size.height)), _WKProto.num(Double(UIScreen.main.scale))])
        }
    }
    func _drawPage(in sv: _WKScrollView) {
        let o = sv.pageOrigin
        if _engineID == 0 {
            _drawPlaceholder(in: CGRect(origin: o, size: sv.bounds.size))
            return
        }
        var w: Int32 = 0, h: Int32 = 0
        let img = isim_web_frame(Int32(_engineID), &w, &h)
        guard img != 0 else { return }
        _frameImage = img
        _framePixels = CGSize(width: Int(w), height: Int(h))
        let s = UIScreen.main.scale
        isim_image_draw(img, o.x, o.y, CGFloat(w) / s, CGFloat(h) / s, nil, 1)
    }
    private func _drawPlaceholder(in r: CGRect) {
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(rect: r).fill()
        let text = "Web content unavailable\n\(_WKEngine.shared.unavailableReason)" as NSString
        let style = NSMutableParagraphStyle(); style.alignment = .center
        text.draw(in: r.insetBy(dx: 24, dy: 0).offsetBy(dx: 0, dy: r.height / 2 - 40),
                  withAttributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.secondaryLabel, .paragraphStyle: style])
    }
    @objc func _isim_dumpText() -> String {
        var s = "web \(url?.absoluteString ?? "about:blank")"
        if let title, !title.isEmpty { s += " title=\"\(title)\"" }
        if isLoading { s += " loading" }
        if _engineID == 0 { s += " (no web engine)" }
        return s
    }

    // MARK: KVO helpers
    private func _set<T: Equatable>(_ key: String, _ old: T, _ new: T, _ assign: () -> Void) {
        guard old != new else { return }
        willChangeValue(forKey: key); assign(); didChangeValue(forKey: key)
    }

    // MARK: loading
    @discardableResult open func load(_ request: URLRequest) -> WKNavigation? {
        guard let u = request.url else { return nil }
        let nav = WKNavigation()
        _requestedNavigation = nav
        if _engineID == 0 { _failWithoutEngine(nav, url: u); return nav }
        let headers = (request.allHTTPHeaderFields ?? [:]).map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        _send(["load", u.absoluteString, headers])
        return nav
    }
    @discardableResult open func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        let nav = WKNavigation()
        _requestedNavigation = nav
        if _engineID == 0 { _failWithoutEngine(nav, url: baseURL ?? URL(string: "about:blank")!); return nav }
        _htmlBaseURL = baseURL
        _send(["html", baseURL?.absoluteString ?? "about:blank", string])
        return nav
    }
    @discardableResult open func load(_ data: Data, mimeType MIMEType: String, characterEncodingName: String, baseURL: URL) -> WKNavigation? {
        let nav = WKNavigation()
        _requestedNavigation = nav
        if _engineID == 0 { _failWithoutEngine(nav, url: baseURL); return nav }
        _htmlBaseURL = baseURL
        _send(["data", baseURL.absoluteString, MIMEType, characterEncodingName, data.base64EncodedString()])
        return nav
    }
    @discardableResult open func loadFileURL(_ URL: URL, allowingReadAccessTo readAccessURL: URL) -> WKNavigation? {
        load(URLRequest(url: URL))
    }
    @discardableResult open func loadSimulatedRequest(_ request: URLRequest, response: URLResponse, responseData data: Data) -> WKNavigation {
        load(data, mimeType: response.mimeType ?? "text/html", characterEncodingName: response.textEncodingName ?? "utf-8",
             baseURL: request.url ?? URL(string: "about:blank")!) ?? WKNavigation()
    }
    @discardableResult open func loadSimulatedRequest(_ request: URLRequest, responseHTML string: String) -> WKNavigation {
        loadHTMLString(string, baseURL: request.url) ?? WKNavigation()
    }
    @discardableResult open func loadFileRequest(_ request: URLRequest, allowingReadAccessTo readAccessURL: URL) -> WKNavigation { load(request) ?? WKNavigation() }
    @discardableResult open func goBack() -> WKNavigation? {
        guard canGoBack || isLoading else { return nil }   /* the engine checks again (state may lag a navigation) */
        let nav = WKNavigation(); _requestedNavigation = nav; _send(["back"]); return nav
    }
    @discardableResult open func goForward() -> WKNavigation? {
        guard canGoForward || isLoading else { return nil }
        let nav = WKNavigation(); _requestedNavigation = nav; _send(["forward"]); return nav
    }
    @discardableResult open func go(to item: WKBackForwardListItem) -> WKNavigation? {
        let nav = WKNavigation(); _requestedNavigation = nav; _send(["goto", String(item._offset)]); return nav
    }
    @discardableResult open func reload() -> WKNavigation? {
        let nav = WKNavigation(); _requestedNavigation = nav; _send(["reload"]); return nav
    }
    @discardableResult open func reloadFromOrigin() -> WKNavigation? {
        let nav = WKNavigation(); _requestedNavigation = nav; _send(["reloadorigin"]); return nav
    }
    open func stopLoading() { _send(["stop"]) }
    open func closeAllMediaPresentations() async {}
    open func pauseAllMediaPlayback() async {}
    open func setAllMediaPlaybackSuspended(_ suspended: Bool) async {}
    open func setMicrophoneCaptureState(_ state: Int) async {}
    open func setCameraCaptureState(_ state: Int) async {}

    private func _failWithoutEngine(_ nav: WKNavigation, url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let e = URLError(.cannotLoadFromNetwork, userInfo: [NSLocalizedDescriptionKey: "isim has no web engine: \(_WKEngine.shared.unavailableReason)",
                                                                  NSURLErrorFailingURLErrorKey: url])
            self.navigationDelegate?.webView?(self, didFailProvisionalNavigation: nav, withError: e)
        }
    }

    // MARK: JavaScript
    open func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, Error?) -> Void)? = nil) {
        _evaluate(javaScriptString, world: .page) { r in
            switch r {
            case .success(let v): completionHandler?(v, nil)
            case .failure(let e): completionHandler?(nil, e)
            }
        }
    }
    open func evaluateJavaScript(_ javaScriptString: String, in frame: WKFrameInfo? = nil, in contentWorld: WKContentWorld,
                                 completionHandler: (@MainActor (Result<Any, Error>) -> Void)? = nil) {
        _evaluate(javaScriptString, world: contentWorld) { r in
            switch r {
            case .success(let v): completionHandler?(.success(v ?? NSNull()))
            case .failure(let e): completionHandler?(.failure(e))
            }
        }
    }
    @discardableResult
    open func evaluateJavaScript(_ javaScriptString: String) async throws -> Any {
        try await withCheckedThrowingContinuation { c in
            _evaluate(javaScriptString, world: .page) { r in
                switch r {
                case .success(let v?): c.resume(returning: v)
                /* like iOS: the async form cannot return "no value" (undefined) */
                case .success(nil): c.resume(throwing: WKError(.javaScriptResultTypeIsUnsupported, userInfo: [NSLocalizedDescriptionKey: "JavaScript execution returned a result of an unsupported type"]))
                case .failure(let e): c.resume(throwing: e)
                }
            }
        }
    }
    @discardableResult
    open func evaluateJavaScript(_ javaScriptString: String, in frame: WKFrameInfo? = nil, contentWorld: WKContentWorld) async throws -> Any? {
        try await withCheckedThrowingContinuation { c in
            _evaluate(javaScriptString, world: contentWorld) { r in c.resume(with: r) }
        }
    }
    /// iOS 14 callAsyncJavaScript: `functionBody` runs as an async function with `arguments` as its parameters; a returned promise is awaited
    open func callAsyncJavaScript(_ functionBody: String, arguments: [String: Any] = [:], in frame: WKFrameInfo? = nil, in contentWorld: WKContentWorld,
                                  completionHandler: (@MainActor (Result<Any, Error>) -> Void)? = nil) {
        _callAsync(functionBody, arguments: arguments, world: contentWorld) { r in
            switch r {
            case .success(let v): completionHandler?(.success(v ?? NSNull()))
            case .failure(let e): completionHandler?(.failure(e))
            }
        }
    }
    @discardableResult
    open func callAsyncJavaScript(_ functionBody: String, arguments: [String: Any] = [:], in frame: WKFrameInfo? = nil, contentWorld: WKContentWorld) async throws -> Any? {
        try await withCheckedThrowingContinuation { c in _callAsync(functionBody, arguments: arguments, world: contentWorld) { r in c.resume(with: r) } }
    }
    private func _callAsync(_ body: String, arguments: [String: Any], world: WKContentWorld, _ done: @escaping (Result<Any?, Error>) -> Void) {
        var prologue = ""
        for (k, v) in arguments.sorted(by: { $0.key < $1.key }) { prologue += "const \(k) = \(_wkJSONText(v));\n" }
        _runJS("call", prologue + body, world: world, done)
    }
    private func _evaluate(_ script: String, world: WKContentWorld, _ done: @escaping (Result<Any?, Error>) -> Void) {
        _runJS("js", script, world: world, done)
    }
    private func _runJS(_ kind: String, _ script: String, world: WKContentWorld, _ done: @escaping (Result<Any?, Error>) -> Void) {
        guard _engineID != 0 else {
            DispatchQueue.main.async { done(.failure(WKError(.webViewInvalidated, userInfo: [NSLocalizedDescriptionKey: "isim has no web engine"]))) }
            return
        }
        let id = _nextJS; _nextJS += 1
        _jsCallbacks[id] = done
        _send([kind, String(id), world._engineName, script])
    }

    // MARK: snapshots, find, PDF
    open func takeSnapshot(with snapshotConfiguration: WKSnapshotConfiguration?, completionHandler: @escaping (UIImage?, Error?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var w: Int32 = 0, h: Int32 = 0
            let img = self._engineID != 0 ? isim_web_frame(Int32(self._engineID), &w, &h) : 0
            guard img != 0 else { completionHandler(nil, WKError(.unknown, userInfo: [NSLocalizedDescriptionKey: "no page has been rendered yet"])); return }
            var bytes: UnsafeMutablePointer<UInt8>? = nil
            let n = isim_image_encode(img, 0, 1, &bytes)
            guard n > 0, let bytes else { completionHandler(nil, WKError(.unknown)); return }
            let data = Data(bytes: bytes, count: n)
            isim_image_bytes_free(bytes)
            let s = UIScreen.main.scale
            guard let full = UIImage(data: data, scale: s) else { completionHandler(nil, WKError(.unknown)); return }
            var rect = snapshotConfiguration?.rect ?? .null
            if rect.isNull { rect = CGRect(origin: .zero, size: full.size) }
            let outW = snapshotConfiguration?.snapshotWidth.map { CGFloat($0.doubleValue) } ?? rect.width
            let k = outW / max(1, rect.width)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = s
            let out = UIGraphicsImageRenderer(size: CGSize(width: outW, height: rect.height * k), format: fmt).image { _ in
                full.draw(in: CGRect(x: -rect.minX * k, y: -rect.minY * k, width: full.size.width * k, height: full.size.height * k))
            }
            completionHandler(out, nil)
        }
    }
    open func takeSnapshot(configuration snapshotConfiguration: WKSnapshotConfiguration?) async throws -> UIImage {
        try await withCheckedThrowingContinuation { c in
            takeSnapshot(with: snapshotConfiguration) { img, e in if let img { c.resume(returning: img) } else { c.resume(throwing: e ?? WKError(.unknown)) } }
        }
    }
    open func find(_ string: String, configuration: WKFindConfiguration = WKFindConfiguration(), completionHandler: @escaping (WKFindResult) -> Void) {
        let js = "window.find(\(_wkJSONText(string)), \(configuration.caseSensitive), \(configuration.backwards), \(configuration.wraps))"
        _evaluate(js, world: .defaultClient) { r in
            let found = (try? r.get()) as? Bool ?? false
            completionHandler(WKFindResult(matchFound: found))
        }
    }
    open func find(_ string: String, configuration: WKFindConfiguration = WKFindConfiguration()) async throws -> WKFindResult {
        await withCheckedContinuation { c in find(string, configuration: configuration) { c.resume(returning: $0) } }
    }
    open func createPDF(configuration: WKPDFConfiguration = WKPDFConfiguration(), completionHandler: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.main.async { completionHandler(.failure(WKError(.unknown, userInfo: [NSLocalizedDescriptionKey: "PDF export is not supported on isim"]))) }
    }
    open func createWebArchiveData(completionHandler: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.main.async { completionHandler(.failure(WKError(.unknown, userInfo: [NSLocalizedDescriptionKey: "web archives are not supported on isim"]))) }
    }
    open class func handlesURLScheme(_ urlScheme: String) -> Bool {
        ["http", "https", "file", "data", "about", "blob", "javascript", "ws", "wss"].contains(urlScheme.lowercased())
    }

    // MARK: input
    func _tap(_ p: CGPoint, phase: String) {
        _send(["tap", _WKProto.num(Double(p.x)), _WKProto.num(Double(p.y)), phase])
    }
    open override var canBecomeFirstResponder: Bool { _editing }
    public var hasText: Bool { true }
    public func insertText(_ text: String) {
        if text == "\n" { _send(["key", "enter"]); return }
        _send(["text", text])
    }
    public func deleteBackward() { _send(["key", "backspace"]) }
    public var autocapitalizationType: UITextAutocapitalizationType = .sentences
    public var autocorrectionType: UITextAutocorrectionType = .default
    public var spellCheckingType: UITextSpellCheckingType = .default
    public var keyboardType: UIKeyboardType = .default
    public var keyboardAppearance: UIKeyboardAppearance = .default
    public var returnKeyType: UIReturnKeyType = .default
    public var enablesReturnKeyAutomatically = false
    public var isSecureTextEntry = false
    public var textContentType: UITextContentType! = nil

    // MARK: engine events
    func _engineExited() {
        if isLoading { _set("isLoading", isLoading, false) { isLoading = false } }
        _engineReady = false
        navigationDelegate?.webViewWebContentProcessDidTerminate?(self)
    }

    func _event(_ ev: String, _ f: [String]) {
        switch ev {
        case "ready": _engineReady = true
        case "frame": _scroll.setNeedsDisplay()
        case "title":
            let t: String? = f.first.flatMap { $0.isEmpty ? nil : $0 }
            _set("title", title, t) { title = t }
        case "url":
            let u = f.first.flatMap { URL(string: $0) }
            _set("URL", url, u) { url = u }
            _set("hasOnlySecureContent", hasOnlySecureContent, u?.scheme == "https") { hasOnlySecureContent = u?.scheme == "https" }
        case "progress":
            let p = Double(f.first ?? "") ?? 0
            _set("estimatedProgress", estimatedProgress, p) { estimatedProgress = p }
        case "loading":
            let l = f.first == "1"
            _set("isLoading", isLoading, l) { isLoading = l }
        case "bf":
            guard f.count >= 3 else { return }
            backForwardList._update(f[2])
            _set("canGoBack", canGoBack, f[0] == "1") { canGoBack = f[0] == "1" }
            _set("canGoForward", canGoForward, f[1] == "1") { canGoForward = f[1] == "1" }
        case "load": _loadEvent(f.first ?? "", url: f.count > 1 ? URL(string: f[1]) : nil)
        case "fail": _failEvent(f)
        case "policy": _policyEvent(f)
        case "create": _createEvent(f)
        case "closed": uiDelegate?.webViewDidClose?(self)
        case "dialog": _dialogEvent(f)
        case "js": _jsEvent(f)
        case "message": _messageEvent(f)
        case "page": _pageEvent(f.first ?? "")
        case "terminated": _engineExited()
        default: break
        }
    }

    private func _loadEvent(_ kind: String, url u: URL?) {
        switch kind {
        case "started":
            let nav = _requestedNavigation ?? WKNavigation()
            _requestedNavigation = nil
            _currentNavigation = nav
            navigationDelegate?.webView?(self, didStartProvisionalNavigation: nav)
        case "redirected":
            navigationDelegate?.webView?(self, didReceiveServerRedirectForProvisionalNavigation: _currentNavigation)
        case "committed":
            navigationDelegate?.webView?(self, didCommit: _currentNavigation)
        case "finished":
            let nav = _currentNavigation
            if let u, u == _lastFailedURL { _lastFailedURL = nil; _currentNavigation = nil; return }   /* WebKitGTK reports "finished" after a failure */
            _currentNavigation = nil
            navigationDelegate?.webView?(self, didFinish: nav)
        default: break
        }
    }
    private func _failEvent(_ f: [String]) {
        guard f.count >= 5 else { return }
        let provisional = f[0] == "1", domain = f[1], code = Int(f[2]) ?? -1, msg = f[3]
        let u = URL(string: f[4])
        _lastFailedURL = u
        var info: [String: Any] = [NSLocalizedDescriptionKey: msg]
        if let u { info[NSURLErrorFailingURLErrorKey] = u; info[NSURLErrorFailingURLStringErrorKey] = u.absoluteString }
        let error: Error = domain == NSURLErrorDomain ? URLError(URLError.Code(rawValue: code), userInfo: info) : NSError(domain: domain, code: code, userInfo: info)
        let nav = _currentNavigation ?? _requestedNavigation
        _requestedNavigation = nil
        if provisional { navigationDelegate?.webView?(self, didFailProvisionalNavigation: nav, withError: error) }
        else { navigationDelegate?.webView?(self, didFail: nav, withError: error) }
    }

    private func _request(_ o: [String: Any]) -> URLRequest {
        var rq = URLRequest(url: URL(string: o["url"] as? String ?? "") ?? URL(string: "about:blank")!)
        rq.httpMethod = o["method"] as? String ?? "GET"
        for (k, v) in (o["headers"] as? [String: String]) ?? [:] where k.lowercased() != "user-agent" { rq.setValue(v, forHTTPHeaderField: k) }
        return rq
    }
    private func _action(_ o: [String: Any], newWindow: Bool) -> WKNavigationAction {
        var rq = _request(o["request"] as? [String: Any] ?? [:])
        if rq.url?.absoluteString == "about:blank", let base = _htmlBaseURL { rq.url = base; _htmlBaseURL = nil }
        let t: WKNavigationType
        switch o["type"] as? Int ?? 5 {
        case 0: t = .linkActivated
        case 1: t = .formSubmitted
        case 2: t = .backForward
        case 3: t = .reload
        case 4: t = .formResubmitted
        default: t = .other
        }
        let source = WKFrameInfo(main: true, url: url, webView: self)
        let target = newWindow ? nil : WKFrameInfo(main: (o["frameName"] as? String ?? "").isEmpty, url: rq.url, webView: self)
        return WKNavigationAction(sourceFrame: source, targetFrame: target, navigationType: t, request: rq, buttonNumber: (o["button"] as? Int ?? 0) > 0 ? 1 : 0)
    }
    private func _policyEvent(_ f: [String]) {
        guard f.count >= 3 else { return }
        let req = f[0], kind = f[1], o = _wkJSONObject(f[2])
        var answered = false
        let answer: (Int) -> Void = { [weak self] d in
            guard !answered else { return }
            answered = true
            self?._send(["policy", req, String(d)])
        }
        let d = navigationDelegate
        if kind == "response" {
            let rqo = o["request"] as? [String: Any] ?? [:]
            let u = URL(string: o["url"] as? String ?? "") ?? URL(string: rqo["url"] as? String ?? "") ?? URL(string: "about:blank")!
            let status = o["status"] as? Int ?? 0
            let headers = o["headers"] as? [String: String] ?? [:]
            let response: URLResponse = status > 0
                ? (HTTPURLResponse(url: u, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) ?? URLResponse(url: u, mimeType: o["mime"] as? String, expectedContentLength: -1, textEncodingName: nil))
                : URLResponse(url: u, mimeType: o["mime"] as? String, expectedContentLength: (o["length"] as? Int) ?? -1, textEncodingName: nil)
            let r = WKNavigationResponse(isForMainFrame: o["mainFrame"] as? Bool ?? true, response: response, canShowMIMEType: o["canShow"] as? Bool ?? true)
            if let d, _wkHas(d, "webView:decidePolicyForNavigationResponse:decisionHandler:") {
                d.webView?(self, decidePolicyFor: r, decisionHandler: { answer($0.rawValue) })
            } else if let d, _wkHas(d, "webView:decidePolicyForNavigationResponse:completionHandler:") {
                _wkAsyncCast(d).webView(self, asyncResponse: r, completionHandler: { p in answer(p.rawValue) })
            } else { answer(r.canShowMIMEType ? 1 : 0) }
            return
        }
        let action = _action(o, newWindow: kind == "newwindow")
        if let d, _wkHas(d, "webView:decidePolicyForNavigationAction:preferences:decisionHandler:") {
            d.webView?(self, decidePolicyFor: action, preferences: configuration.defaultWebpagePreferences, decisionHandler: { p, _ in answer(p == .download ? 0 : p.rawValue) })
        } else if let d, _wkHas(d, "webView:decidePolicyForNavigationAction:decisionHandler:") {
            d.webView?(self, decidePolicyFor: action, decisionHandler: { p in answer(p == .download ? 0 : p.rawValue) })
        } else if let d, _wkHas(d, "webView:decidePolicyForNavigationAction:completionHandler:") {
            _wkAsyncCast(d).webView(self, asyncAction: action, completionHandler: { p in answer(p == .download ? 0 : p.rawValue) })
        } else { answer(1) }
    }
    private func _createEvent(_ f: [String]) {
        guard let json = f.first else { return }
        let rq = _request(_wkJSONObject(json))
        let action = WKNavigationAction(sourceFrame: WKFrameInfo(main: true, url: url, webView: self), targetFrame: nil, navigationType: .linkActivated, request: rq, buttonNumber: 0)
        let cfg = configuration.copy() as! WKWebViewConfiguration
        if let child = uiDelegate?.webView?(self, createWebViewWith: cfg, for: action, windowFeatures: WKWindowFeatures()) {
            child.load(rq)   /* isim: the new view loads the request; no window.opener relationship */
        }
    }
    private func _dialogEvent(_ f: [String]) {
        guard f.count >= 4 else { return }
        let req = f[0], type = f[1], msg = f[2], def = f[3]
        let frame = WKFrameInfo(main: true, url: url, webView: self)
        let reply: (Bool, String?) -> Void = { [weak self] ok, text in self?._send(["dialog", req, ok ? "1" : "0", text ?? ""]) }
        let u = uiDelegate
        switch type {
        case "alert":
            if let u, _wkHas(u, "webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:") {
                u.webView?(self, runJavaScriptAlertPanelWithMessage: msg, initiatedByFrame: frame, completionHandler: { reply(true, nil) })
            } else if let u, _wkHas(u, "webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:asyncCompletionHandler:") {
                _wkAsyncCast(u).webView(self, asyncAlert: msg, initiatedByFrame: frame, completionHandler: { reply(true, nil) })
            } else { reply(true, nil) }
        case "confirm", "beforeunload":
            if let u, _wkHas(u, "webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:completionHandler:") {
                u.webView?(self, runJavaScriptConfirmPanelWithMessage: msg, initiatedByFrame: frame, completionHandler: { reply($0, nil) })
            } else if let u, _wkHas(u, "webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:asyncCompletionHandler:") {
                _wkAsyncCast(u).webView(self, asyncConfirm: msg, initiatedByFrame: frame, completionHandler: { reply($0, nil) })
            } else { reply(type == "beforeunload", nil) }
        default:
            if let u, _wkHas(u, "webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:") {
                u.webView?(self, runJavaScriptTextInputPanelWithPrompt: msg, defaultText: def.isEmpty ? nil : def, initiatedByFrame: frame, completionHandler: { reply($0 != nil, $0) })
            } else if let u, _wkHas(u, "webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:asyncCompletionHandler:") {
                _wkAsyncCast(u).webView(self, asyncPrompt: msg, defaultText: def.isEmpty ? nil : def, initiatedByFrame: frame, completionHandler: { reply($0 != nil, $0) })
            } else { reply(false, nil) }
        }
    }
    private func _jsEvent(_ f: [String]) {
        guard f.count >= 3, let id = Int(f[0]), let cb = _jsCallbacks.removeValue(forKey: id) else { return }
        switch f[1] {
        case "ok": cb(.success(_wkJSONValue(f[2])))
        case "unsupported": cb(.failure(WKError(.javaScriptResultTypeIsUnsupported, userInfo: [NSLocalizedDescriptionKey: f[2]])))
        default:
            cb(.failure(WKError(.javaScriptExceptionOccurred, userInfo: [NSLocalizedDescriptionKey: "A JavaScript exception occurred",
                                                                         WKJavaScriptExceptionMessageErrorKey: f[2],
                                                                         WKJavaScriptExceptionSourceURLErrorKey: url as Any])))
        }
    }
    private func _messageEvent(_ f: [String]) {
        guard f.count >= 3 else { return }
        let req = f[0], name = f[1]
        let body: Any = _wkJSONValue(f[2]) ?? NSNull()
        let ucc = configuration.userContentController
        guard let h = ucc._handlers.first(where: { $0.name == name }) else { return }
        let msg = WKScriptMessage(body: body, webView: self, frameInfo: WKFrameInfo(main: true, url: url, webView: self), name: name, world: h.world)
        if req == "0" {
            (h.handler as? WKScriptMessageHandler)?.userContentController(ucc, didReceive: msg)
            return
        }
        var answered = false
        let reply: (Any?, String?) -> Void = { [weak self] value, error in
            guard !answered else { return }
            answered = true
            if let error { self?._send(["reply", req, "0", error]) } else { self?._send(["reply", req, "1", _wkJSONText(value)]) }
        }
        guard let r = h.handler as? WKScriptMessageHandlerWithReply else { reply(nil, "no handler"); return }
        if _wkHas(r, "userContentController:didReceiveScriptMessage:replyHandler:") {
            r.userContentController?(ucc, didReceive: msg, replyHandler: { reply($0, $1) })
        } else if _wkHas(r, "userContentController:didReceiveScriptMessage:asyncReplyHandler:") {
            _wkAsyncCast(r).userContentController(ucc, asyncMessage: msg, completionHandler: { reply($0, $1) })
        } else { reply(nil, "no handler") }
    }
    private func _pageEvent(_ json: String) {
        let o = _wkJSONObject(json)
        switch o["t"] as? String {
        case "scroll":
            _scroll.pageScrolled(x: o["x"] as? Double ?? 0, y: o["y"] as? Double ?? 0, width: o["w"] as? Double ?? 0, height: o["h"] as? Double ?? 0)
        case "focus":
            let editable = o["editable"] as? Bool ?? false
            let type = (o["type"] as? String ?? "").lowercased(), mode = (o["kind"] as? String ?? "").lowercased()
            if editable {
                keyboardType = type == "email" || mode == "email" ? .emailAddress : type == "url" || mode == "url" ? .URL
                    : type == "tel" || mode == "tel" ? .phonePad : type == "number" || mode == "numeric" || mode == "decimal" ? .numberPad : .default
                isSecureTextEntry = type == "password"
                if !_editing { _editing = true; becomeFirstResponder() }
            } else if _editing {
                _editing = false
                if isFirstResponder { _ = resignFirstResponder() }
            }
        default: break
        }
    }
    open override func resignFirstResponder() -> Bool {
        let was = isFirstResponder
        let r = super.resignFirstResponder()
        if was && _editing { _editing = false; _send(["blur"]) }
        return r
    }
}


/// whether a delegate implements an optional protocol method (by Objective-C selector)
func _wkHas(_ o: NSObjectProtocol, _ selector: String) -> Bool { o.responds(to: Selector(selector)) }

/// The completion-handler form of the delegates' `async` requirements: Swift exposes an implemented async
/// requirement to Objective-C under these selectors, so they are called through objc_msgSend.
@objc protocol _WKAsync {
    @objc(webView:decidePolicyForNavigationAction:completionHandler:)
    func webView(_ w: WKWebView, asyncAction a: WKNavigationAction, completionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    @objc(webView:decidePolicyForNavigationResponse:completionHandler:)
    func webView(_ w: WKWebView, asyncResponse r: WKNavigationResponse, completionHandler: @escaping (WKNavigationResponsePolicy) -> Void)
    @objc(webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:asyncCompletionHandler:)
    func webView(_ w: WKWebView, asyncAlert m: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping () -> Void)
    @objc(webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:asyncCompletionHandler:)
    func webView(_ w: WKWebView, asyncConfirm m: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping (Bool) -> Void)
    @objc(webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:asyncCompletionHandler:)
    func webView(_ w: WKWebView, asyncPrompt p: String, defaultText: String?, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping (String?) -> Void)
    @objc(userContentController:didReceiveScriptMessage:asyncReplyHandler:)
    func userContentController(_ c: WKUserContentController, asyncMessage m: WKScriptMessage, completionHandler: @escaping (Any?, String?) -> Void)
}
func _wkAsyncCast(_ o: AnyObject) -> _WKAsync { unsafeBitCast(o, to: _WKAsync.self) }
