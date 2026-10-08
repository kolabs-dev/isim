// isim SafariServices: SFSafariViewController — an in-app browser with iOS 17-style chrome (dismiss button,
// domain + lock, reader "aA" button (cosmetic), back/forward/share/open-in-Safari toolbar) on top of isim's
// WKWebView (real WebKit through the host's WebKitGTK). Adapted: the page data lives in a private
// non-persistent store (Safari's own cookie jar is not modelled); Reader mode, bar collapsing and
// "Open in Safari" (logged, opens on the host only with ISIM_OPEN_URLS=1) are not real.
// _SFBrowserViewController is also the browser sheet of ASWebAuthenticationSession (AuthenticationServices).
import UIKit
import WebKit

@objc public protocol SFSafariViewControllerDelegate: NSObjectProtocol {
    @MainActor @objc optional func safariViewControllerDidFinish(_ controller: SFSafariViewController)
    @MainActor @objc optional func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool)
    @MainActor @objc optional func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL)
    @MainActor @objc optional func safariViewController(_ controller: SFSafariViewController, activityItemsFor URL: URL, title: String?) -> [UIActivity]
    @MainActor @objc optional func safariViewController(_ controller: SFSafariViewController, excludedActivityTypesFor URL: URL, title: String?) -> [UIActivity.ActivityType]
    @MainActor @objc optional func safariViewControllerWillOpenInBrowser(_ controller: SFSafariViewController)
}

/// The browser: a web view between a top bar (dismiss button, domain, reader button) and a bottom toolbar.
@MainActor
open class _SFBrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    public let web: WKWebView
    public let initialURL: URL
    let topBar = UIView()
    let doneButton = UIButton(type: .system)
    let domainLabel = UILabel()
    let lockView = UIImageView()
    let readerButton = UIButton(type: .system)
    let toolbar = UIView()
    let backButton = UIButton(type: .system)
    let forwardButton = UIButton(type: .system)
    let shareButton = UIButton(type: .system)
    let safariButton = UIButton(type: .system)
    let progressBar = UIView()
    public var showsToolbar = true
    var observations: [NSKeyValueObservation] = []
    public var dismissTitle = "Done"
    var tint: UIColor = .systemBlue
    var barTint: UIColor?
    /// navigation hook (ASWebAuthenticationSession: callback interception); return false to cancel the navigation
    public var shouldNavigate: ((URL) -> Bool)?
    public var onDismiss: (() -> Void)?
    public var onFirstLoad: ((Bool) -> Void)?
    public var onRedirect: ((URL) -> Void)?
    var firstLoadDone = false
    var redirected = false

    public init(url: URL, store: WKWebsiteDataStore, headers: [String: String] = [:]) {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = store
        cfg.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        web = WKWebView(frame: .zero, configuration: cfg)
        initialURL = url
        _headers = headers
        super.init(nibName: nil, bundle: nil)
    }
    let _headers: [String: String]
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let bg = barTint ?? .secondarySystemBackground
        topBar.backgroundColor = bg
        toolbar.backgroundColor = bg
        for v in [web, topBar, toolbar, progressBar] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        progressBar.backgroundColor = tint
        progressBar.isHidden = true

        doneButton.setTitle(dismissTitle, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.tintColor = tint
        doneButton.accessibilityIdentifier = "safari-done"
        doneButton.addTarget(self, action: #selector(_done), for: .touchUpInside)
        domainLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        domainLabel.textAlignment = .center
        domainLabel.accessibilityIdentifier = "safari-domain"
        lockView.image = UIImage(systemName: "lock.fill")
        lockView.tintColor = .label
        lockView.contentMode = .scaleAspectFit
        readerButton.setTitle("aA", for: .normal)
        readerButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        readerButton.tintColor = .label
        readerButton.accessibilityIdentifier = "safari-reader"
        for v in [doneButton, domainLabel, lockView, readerButton] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; topBar.addSubview(v) }

        for (b, sym, id, sel) in [(backButton, "chevron.left", "safari-back", #selector(_back)), (forwardButton, "chevron.right", "safari-forward", #selector(_forward)),
                                  (shareButton, "square.and.arrow.up", "safari-share", #selector(_share)), (safariButton, "", "safari-open", #selector(_openInSafari))] {
            if sym.isEmpty { b.setImage(_SFCompass.image(color: tint), for: .normal) } else { b.setImage(UIImage(systemName: sym), for: .normal) }
            b.tintColor = tint
            b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            b.translatesAutoresizingMaskIntoConstraints = false
            toolbar.addSubview(b)
        }
        let sep1 = UIView(), sep2 = UIView()
        for s in [sep1, sep2] { s.backgroundColor = .separator; s.translatesAutoresizingMaskIntoConstraints = false }
        topBar.addSubview(sep1); toolbar.addSubview(sep2)
        let g = view.safeAreaLayoutGuide
        toolbar.isHidden = !showsToolbar
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor), topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor), topBar.bottomAnchor.constraint(equalTo: g.topAnchor, constant: 44),
            doneButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16), doneButton.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -6),
            doneButton.heightAnchor.constraint(equalToConstant: 32),
            domainLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor, constant: 8), domainLabel.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor),
            domainLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            lockView.trailingAnchor.constraint(equalTo: domainLabel.leadingAnchor, constant: -4), lockView.centerYAnchor.constraint(equalTo: domainLabel.centerYAnchor),
            lockView.widthAnchor.constraint(equalToConstant: 11), lockView.heightAnchor.constraint(equalToConstant: 13),
            readerButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16), readerButton.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor),
            sep1.leadingAnchor.constraint(equalTo: topBar.leadingAnchor), sep1.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            sep1.bottomAnchor.constraint(equalTo: topBar.bottomAnchor), sep1.heightAnchor.constraint(equalToConstant: 0.5),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor), progressBar.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2.5), progressBar.widthAnchor.constraint(equalToConstant: 0),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor), toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor), toolbar.topAnchor.constraint(equalTo: g.bottomAnchor, constant: showsToolbar ? -49 : 0),
            sep2.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor), sep2.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            sep2.topAnchor.constraint(equalTo: toolbar.topAnchor), sep2.heightAnchor.constraint(equalToConstant: 0.5),

            web.topAnchor.constraint(equalTo: topBar.bottomAnchor), web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor), web.bottomAnchor.constraint(equalTo: showsToolbar ? toolbar.topAnchor : view.bottomAnchor),
        ])
        let buttons = [backButton, forwardButton, shareButton, safariButton]
        for (i, b) in buttons.enumerated() {
            NSLayoutConstraint.activate([
                b.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 4), b.heightAnchor.constraint(equalToConstant: 40),
                b.widthAnchor.constraint(equalToConstant: 44),
                NSLayoutConstraint(item: b, attribute: .centerX, relatedBy: .equal, toItem: toolbar, attribute: .trailing, multiplier: CGFloat(2 * i + 1) / 8, constant: 0),
            ])
        }
        web.navigationDelegate = self
        web.uiDelegate = self
        web.accessibilityIdentifier = "safari-web"
        observations = [
            web.observe(\.url, options: [.new]) { [weak self] _, _ in self?._updateChrome() },
            web.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?._updateChrome() },
            web.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?._updateChrome() },
            web.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?._updateProgress() },
        ]
        _updateChrome()
        var rq = URLRequest(url: initialURL)
        for (k, v) in _headers { rq.setValue(v, forHTTPHeaderField: k) }
        web.load(rq)
    }
    func _updateChrome() {
        let u = web.url ?? initialURL
        var host = u.host ?? u.absoluteString
        if host.hasPrefix("www.") { host.removeFirst(4) }
        domainLabel.text = host
        lockView.isHidden = u.scheme != "https"
        backButton.isEnabled = web.canGoBack
        forwardButton.isEnabled = web.canGoForward
        backButton.alpha = web.canGoBack ? 1 : 0.35
        forwardButton.alpha = web.canGoForward ? 1 : 0.35
    }
    func _updateProgress() {
        let p = web.estimatedProgress
        progressBar.isHidden = p >= 1 || p <= 0
        for c in view.constraints where c.firstItem === progressBar && c.firstAttribute == .width { c.constant = view.bounds.width * CGFloat(p) }
    }
    @objc func _done() { onDismiss?() }
    @objc func _back() { web.goBack() }
    @objc func _forward() { web.goForward() }
    @objc func _share() {
        let u = web.url ?? initialURL
        let vc = UIActivityViewController(activityItems: [u], applicationActivities: _activities(u))
        present(vc, animated: true)
    }
    func _activities(_ u: URL) -> [UIActivity]? { nil }
    @objc func _openInSafari() {
        willOpenInBrowser()
        UIApplication.shared.open(web.url ?? initialURL)
    }
    func willOpenInBrowser() {}

    // MARK: WKNavigationDelegate
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = navigationAction.request.url, let f = shouldNavigate, !f(u) { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if !firstLoadDone { redirected = true }
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !firstLoadDone {
            firstLoadDone = true
            if redirected, let u = webView.url, u != initialURL { onRedirect?(u) }
            onFirstLoad?(true)
        }
    }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if !firstLoadDone, (error as NSError).code != NSURLErrorCancelled {
            firstLoadDone = true
            onFirstLoad?(false)
            _showError(error)
        }
    }
    func _showError(_ error: Error) {
        let html = "<!doctype html><html><head><meta name=viewport content='width=device-width'></head><body style='font:17px -apple-system,sans-serif;"
            + "text-align:center;padding:120px 32px;color:#3c3c43'><h2 style='color:#000'>Safari Can’t Open the Page</h2><p>"
            + (error as NSError).localizedDescription.replacingOccurrences(of: "<", with: "&lt;") + "</p></body></html>"
        web.loadHTMLString(html, baseURL: nil)
    }
    // window.open / target=_blank: open in place
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction,
                        windowFeatures: WKWindowFeatures) -> WKWebView? {
        webView.load(navigationAction.request)
        return nil
    }
    // JavaScript panels like Safari's
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Close", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }
}

/// Safari's compass glyph (Open in Safari), drawn with paths.
enum _SFCompass {
    @MainActor static func image(color: UIColor) -> UIImage {
        let s: CGFloat = 24
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { _ in
            color.setStroke(); color.setFill()
            let ring = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: s - 4, height: s - 4)); ring.lineWidth = 1.6; ring.stroke()
            let n = UIBezierPath()
            n.move(to: CGPoint(x: 16.5, y: 7.5)); n.addLine(to: CGPoint(x: 13.2, y: 13.2)); n.addLine(to: CGPoint(x: 10.8, y: 10.8)); n.close(); n.fill()
            let sth = UIBezierPath()
            sth.move(to: CGPoint(x: 7.5, y: 16.5)); sth.addLine(to: CGPoint(x: 10.8, y: 10.8)); sth.addLine(to: CGPoint(x: 13.2, y: 13.2)); sth.close(); sth.lineWidth = 1.2; sth.stroke()
        }.withRenderingMode(.alwaysTemplate)
    }
}

@MainActor
open class SFSafariViewController: UIViewController {
    open class Configuration: NSObject, @unchecked Sendable {
        open var entersReaderIfAvailable = false
        open var barCollapsingEnabled = true
        open var activityButton: AnyObject?
        open var eventAttribution: AnyObject?
        public override init() { super.init() }
    }
    @objc public enum DismissButtonStyle: Int, Sendable { case done = 0, close, cancel }
    /// iOS 16: website data of SFSafariViewController
    public final class DataStore: @unchecked Sendable {
        public static let `default` = DataStore()
        public func clearWebsiteData() async {
            await MainActor.run { _SFSafariStore.store }.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        }
        public func clearWebsiteData(completionHandler: (@Sendable () -> Void)? = nil) {
            Task { await clearWebsiteData(); completionHandler?() }
        }
    }
    public final class PrewarmingToken: NSObject, @unchecked Sendable { public func invalidate() {} }
    public class func prewarmConnections(to URLs: [URL]) -> PrewarmingToken { PrewarmingToken() }

    open weak var delegate: SFSafariViewControllerDelegate?
    open private(set) var configuration: Configuration
    open var preferredBarTintColor: UIColor?
    open var preferredControlTintColor: UIColor?
    open var dismissButtonStyle: DismissButtonStyle = .done
    let _url: URL
    var _browser: _SFBrowserViewController?

    public init(url URL: URL, configuration: Configuration) {
        let scheme = URL.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            NSException(name: "NSInvalidArgumentException",
                        reason: "The specified URL has an unsupported scheme. Only HTTP and HTTPS URLs are supported.", userInfo: nil).raise()
        }
        _url = URL
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    public convenience init(url URL: URL) { self.init(url: URL, configuration: Configuration()) }
    public convenience init(url URL: URL, entersReaderIfAvailable: Bool) {
        let c = Configuration(); c.entersReaderIfAvailable = entersReaderIfAvailable
        self.init(url: URL, configuration: c)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    open override func viewDidLoad() {
        super.viewDidLoad()
        let b = _SFBrowserViewController(url: _url, store: _SFSafariStore.store)
        b.dismissTitle = ["Done", "Close", "Cancel"][dismissButtonStyle.rawValue]
        b.tint = preferredControlTintColor ?? .systemBlue
        b.barTint = preferredBarTintColor
        b.onDismiss = { [weak self] in
            guard let self else { return }
            self.dismiss(animated: true) { self.delegate?.safariViewControllerDidFinish?(self) }
        }
        b.onFirstLoad = { [weak self] ok in guard let self else { return }; self.delegate?.safariViewController?(self, didCompleteInitialLoad: ok) }
        b.onRedirect = { [weak self] u in guard let self else { return }; self.delegate?.safariViewController?(self, initialLoadDidRedirectTo: u) }
        addChild(b)
        b.view.frame = view.bounds
        b.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(b.view)
        b.didMove(toParent: self)
        _browser = b
    }
    open override var preferredStatusBarStyle: UIStatusBarStyle { .default }
}

/// SFSafariViewController's own website data (separate from the app's WKWebView default store, like iOS).
@MainActor public enum _SFSafariStore { public static let store = WKWebsiteDataStore.nonPersistent() }

// MARK: - SFSafariApplication / Reading List

open class SSReadingList: NSObject, @unchecked Sendable {
    static let _default = SSReadingList()
    public static func `default`() -> SSReadingList? { _default }
    public static func supportsURL(_ URL: URL) -> Bool { ["http", "https"].contains(URL.scheme?.lowercased() ?? "") }
    var items: [(URL, String?, String?)] = []
    open func addItem(with URL: URL, title: String?, previewText: String?) throws {
        guard SSReadingList.supportsURL(URL) else { throw NSError(domain: "SSErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL scheme not supported"]) }
        items.append((URL, title, previewText))
        print("isim: Safari Reading List: added \(URL.absoluteString)")
    }
}
