// isim Safari: the device's web browser (a WKWebView), so links apps open with UIApplication.open, http(s) URLs from
// `openurl` and Handoff of web pages show on the device, like iOS. Modelled on iOS 17/18 Safari's bottom layout: the
// address field in a rounded pill above the toolbar (back, forward, share, reload). iPhone under iOS 26+: the compact
// Liquid Glass bar floating over the page (a back button, the address capsule with reload, a "…" menu with forward and
// share); the page runs under it to the bottom of the screen.
// isim's own app (not Apple's): no tabs, bookmarks, Reader or private browsing.
import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let browser = BrowserViewController()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = browser
        window?.makeKeyAndVisible()
        if let url = launchOptions?[.url] as? URL { browser.open(url) }
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        browser.open(url); return true
    }
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard let url = userActivity.webpageURL else { return false }
        browser.open(url); return true
    }
}

final class BrowserViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {
    let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    let bar = UIView(), pill = UIView(), address = UITextField(), progress = UIProgressView(progressViewStyle: .bar)
    let toolbar = UIToolbar()
    var back: UIBarButtonItem!, forward: UIBarButtonItem!
    var pending: URL?
    // iPhone, iOS 26+: the floating glass bar (nil on iOS 17/18 and iPad)
    var glass: (back: UIButton, capsule: UIView, more: UIButton)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        web.navigationDelegate = self
        web.accessibilityIdentifier = "safari-web"
        view.addSubview(web)
        bar.backgroundColor = .secondarySystemBackground
        view.addSubview(bar)
        pill.backgroundColor = .systemBackground
        pill.layer.cornerRadius = 12
        pill.layer.shadowColor = UIColor.black.cgColor; pill.layer.shadowOpacity = 0.12; pill.layer.shadowRadius = 6; pill.layer.shadowOffset = CGSize(width: 0, height: 2)
        bar.addSubview(pill)
        address.placeholder = "Search or enter website name"
        address.textAlignment = .center
        address.font = .systemFont(ofSize: 17)
        address.keyboardType = .webSearch
        address.returnKeyType = .go
        address.autocapitalizationType = .none
        address.autocorrectionType = .no
        address.clearButtonMode = .whileEditing
        address.delegate = self
        address.accessibilityIdentifier = "safari-address"
        pill.addSubview(address)
        progress.progressTintColor = .systemBlue
        progress.isHidden = true
        bar.addSubview(progress)
        back = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), primaryAction: UIAction { [unowned self] _ in web.goBack() })
        forward = UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), primaryAction: UIAction { [unowned self] _ in web.goForward() })
        let share = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), primaryAction: UIAction { [unowned self] _ in shareTapped() })
        let reload = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), primaryAction: UIAction { [unowned self] _ in web.reload() })
        back.accessibilityIdentifier = "safari-back"; forward.accessibilityIdentifier = "safari-forward"
        share.accessibilityIdentifier = "safari-share"; reload.accessibilityIdentifier = "safari-reload"
        let flex = { UIBarButtonItem(systemItem: .flexibleSpace) }
        toolbar.items = [back, flex(), forward, flex(), share, flex(), reload]
        let clear = UIToolbarAppearance()
        clear.configureWithTransparentBackground()
        toolbar.standardAppearance = clear
        bar.addSubview(toolbar)
        if #available(iOS 26, *), UIDevice.current.userInterfaceIdiom == .phone { makeGlassBar() }
        traitCollectionDidChange(nil)
        updateButtons()
        if let pending { self.pending = nil; open(pending) }
    }
    @available(iOS 26, *)
    func makeGlassBar() {
        bar.isHidden = true
        let circle = { (symbol: String, id: String) -> UIButton in
            var c = UIButton.Configuration.glass()
            c.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
            c.baseForegroundColor = .label
            let b = UIButton(configuration: c)
            b.accessibilityIdentifier = id
            self.view.addSubview(b)
            return b
        }
        let back = circle("chevron.backward", "safari-back")
        back.addAction(UIAction { [unowned self] _ in web.goBack() }, for: .touchUpInside)
        let more = circle("ellipsis", "safari-more")
        more.showsMenuAsPrimaryAction = true
        let capsule = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        capsule.cornerConfiguration = .capsule()
        capsule.clipsToBounds = true
        capsule.accessibilityIdentifier = "safari-capsule"
        view.addSubview(capsule)
        address.font = .systemFont(ofSize: 15, weight: .medium)
        capsule.contentView.addSubview(address)
        var r = UIButton.Configuration.plain()
        r.image = UIImage(systemName: "arrow.clockwise", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium))
        r.baseForegroundColor = .label
        let reload = UIButton(configuration: r, primaryAction: UIAction { [unowned self] _ in web.reload() })
        reload.accessibilityIdentifier = "safari-reload"
        reload.tag = 1
        capsule.contentView.addSubview(reload)
        capsule.contentView.addSubview(progress)
        glass = (back, capsule, more)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = view.bounds.width, safe = view.safeAreaInsets
        if let glass {                                           // iPhone, iOS 26+: back | address capsule | …, floating
            let h: CGFloat = 48, gap: CGFloat = 8, side: CGFloat = 16
            let y = view.bounds.height - (safe.bottom > 0 ? safe.bottom - 6 : 12) - h
            web.frame = CGRect(x: 0, y: safe.top, width: w, height: view.bounds.height - safe.top)   // the page runs under the bar
            glass.back.frame = CGRect(x: side, y: y, width: h, height: h)
            glass.more.frame = CGRect(x: w - side - h, y: y, width: h, height: h)
            glass.capsule.frame = CGRect(x: side + h + gap, y: y, width: w - 2 * (side + h + gap), height: h)
            let cw = glass.capsule.bounds.width
            glass.capsule.contentView.viewWithTag(1)?.frame = CGRect(x: cw - 44, y: 0, width: 40, height: h)
            address.frame = CGRect(x: 44, y: 0, width: cw - 88, height: h)   // centred, clear of reload
            progress.frame = CGRect(x: 0, y: h - 2, width: cw, height: 2)
            for v in [glass.back, glass.capsule, glass.more] { view.bringSubviewToFront(v) }
            return
        }
        if traitCollection.userInterfaceIdiom == .pad {          // iPad: one bar at the top, the address field centred
            let barH: CGFloat = 50
            bar.frame = CGRect(x: 0, y: 0, width: w, height: safe.top + barH)
            web.frame = CGRect(x: 0, y: bar.frame.maxY, width: w, height: view.bounds.height - bar.frame.maxY)
            let pw = min(w * 0.45, 600)
            pill.frame = CGRect(x: (w - pw) / 2, y: safe.top + 7, width: pw, height: 36)
            toolbar.frame = CGRect(x: 0, y: safe.top + 3, width: w, height: 44)
            progress.frame = CGRect(x: 0, y: bar.bounds.height - 2, width: w, height: 2)
        } else {                                                 // iPhone: the address pill above the toolbar, at the bottom
            let barH: CGFloat = 52 + 44 + safe.bottom
            bar.frame = CGRect(x: 0, y: view.bounds.height - barH, width: w, height: barH)
            web.frame = CGRect(x: 0, y: safe.top, width: w, height: bar.frame.minY - safe.top)   // pages start below the status bar
            pill.frame = CGRect(x: 12, y: 6, width: w - 24, height: 44)
            toolbar.frame = CGRect(x: 0, y: 52, width: w, height: 44)
            progress.frame = CGRect(x: 0, y: 0, width: w, height: 2)
        }
        address.frame = pill.bounds.insetBy(dx: 12, dy: 0)
        bar.bringSubviewToFront(pill)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let flex = { UIBarButtonItem(systemItem: .flexibleSpace) }, fixed = { UIBarButtonItem(systemItem: .fixedSpace) }
        let items = toolbar.items?.filter { $0.accessibilityIdentifier != nil } ?? []
        guard items.count == 4 else { return }
        toolbar.items = traitCollection.userInterfaceIdiom == .pad
            ? [items[0], fixed(), items[1], flex(), items[2], fixed(), items[3]]
            : [items[0], flex(), items[1], flex(), items[2], flex(), items[3]]
    }

    func open(_ url: URL) {
        guard isViewLoaded else { pending = url; return }
        NSLog("Safari: opening %@", url.absoluteString)
        address.text = url.host ?? url.absoluteString
        web.load(URLRequest(url: url))
    }
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.text = web.url?.absoluteString ?? textField.text
        return true
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
        textField.resignFirstResponder()
        guard !text.isEmpty else { return false }
        if text.contains("."), !text.contains(" "), let url = URL(string: text.contains("://") ? text : "https://" + text) { open(url) }
        else if let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: "https://duckduckgo.com/?q=" + q) { open(url) }
        return true
    }
    func shareTapped() {
        guard let url = web.url else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(sheet, animated: true)
    }
    func updateButtons() {
        back.isEnabled = web.canGoBack; forward.isEnabled = web.canGoForward
        guard let glass else { return }
        glass.back.isEnabled = web.canGoBack
        let fwd = UIAction(title: "Forward", image: UIImage(systemName: "chevron.forward"),
                           attributes: web.canGoForward ? [] : .disabled) { [unowned self] _ in web.goForward() }
        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up"),
                             attributes: web.url == nil ? .disabled : []) { [unowned self] _ in shareTapped() }
        glass.more.menu = UIMenu(children: [share, fwd])
    }
    // MARK: navigation
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progress.isHidden = false; progress.progress = 0.2; updateButtons()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progress.setProgress(1, animated: true); progress.isHidden = true
        if !address.isFirstResponder { address.text = webView.url?.host ?? webView.url?.absoluteString }
        updateButtons()
        NSLog("Safari: loaded %@ “%@”", webView.url?.absoluteString ?? "", webView.title ?? "")
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)    // the page, for Handoff
        activity.webpageURL = webView.url
        activity.title = webView.title
        userActivity = activity
        activity.becomeCurrent()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { progress.isHidden = true; updateButtons() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progress.isHidden = true; updateButtons()
        NSLog("Safari: cannot open the page: %@", error.localizedDescription)
    }
}
