// Sample: WKWebView on isim — loadHTMLString, a custom URL scheme handler, an http page from a local server,
// navigation delegate (async action policy, response policy, start/commit/finish/fail), UI delegate (alert,
// confirm, prompt as UIAlertControllers), script messages (with and without reply), user scripts in the page
// and an isolated world, evaluateJavaScript / callAsyncJavaScript, KVO on title/URL/progress/canGoBack,
// back/forward, typing into a page field, scrolling, cookies and snapshots.
//   isim run out/apps/HelloWeb.app -server http://127.0.0.1:8765   (samples/HelloWeb/server.py)
import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: WebViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { print("HelloWeb: " + s) }

var serverURL: String {
    let args = ProcessInfo.processInfo.arguments
    if let i = args.firstIndex(of: "-server"), i + 1 < args.count { return args[i + 1] }
    return "http://127.0.0.1:8765"
}

let homeHTML = """
<!doctype html><html><head><meta name="viewport" content="width=device-width"><title>Hello Web</title>
<style>
body { margin: 0; font: 17px sans-serif; color: #111; }
.b { position: absolute; left: 16px; width: 170px; height: 40px; border-radius: 10px; border: 0; background: #007aff; color: #fff; font-size: 16px; }
a { position: absolute; left: 16px; font-size: 18px; color: #007aff; }
</style></head><body>
<h1 style="position:absolute;top:0;left:16px;margin:8px 0;font-size:28px">Hello Web</h1>
<div id="red" style="position:absolute;left:220px;top:56px;width:80px;height:80px;background:rgb(255,0,0)"></div>
<button class="b" id="post" style="top:56px" onclick="window.webkit.messageHandlers.native.postMessage({kind:'tap', count: ++taps, list:[1,'two',true]})">Post message</button>
<button class="b" id="alert" style="top:104px" onclick="alert('Hello from JavaScript'); out('alert done')">Alert</button>
<button class="b" id="confirm" style="top:152px" onclick="out('confirm ' + confirm('Delete everything?'))">Confirm</button>
<button class="b" id="prompt" style="top:200px" onclick="out('prompt ' + prompt('Your name?', 'Ada'))">Prompt</button>
<button class="b" id="reply" style="top:248px" onclick="window.webkit.messageHandlers.calc.postMessage({a: 6, b: 7}).then(function (r) { out('reply ' + r) })">Ask native</button>
<input id="field" style="position:absolute;top:300px;left:16px;width:250px;height:34px;font-size:17px" placeholder="Type here" oninput="out('typed ' + this.value)">
<a id="next" href="isim-demo://pages/two" style="top:350px">Next page (scheme handler)</a>
<a id="blocked" href="https://blocked.example/" style="top:385px">Blocked link</a>
<a id="server" href="SERVER/page3" style="top:420px">Server page (cookie)</a>
<div id="out" style="position:absolute;top:460px;left:16px;font-size:18px">ready</div>
<div id="bottom" style="position:absolute;top:1500px;left:16px">Bottom of the page</div>
<script>
var taps = 0;
function out(s) { document.getElementById('out').textContent = s; window.webkit.messageHandlers.native.postMessage({kind: 'out', text: s}); }
</script>
</body></html>
"""

/// serves isim-demo:// pages from the app
final class DemoSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!
        log("scheme request \(url.absoluteString)")
        let html = "<!doctype html><html><head><meta name=viewport content='width=device-width'><title>Page Two</title></head>"
            + "<body style='margin:0;font:20px sans-serif'><div id=green style='position:absolute;left:16px;top:16px;width:120px;height:120px;background:rgb(0,200,0)'></div>"
            + "<p style='position:absolute;top:150px;left:16px'>Served by a WKURLSchemeHandler</p></body></html>"
        let data = Data(html.utf8)
        urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html"])!)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

final class MessageHandler: NSObject, WKScriptMessageHandler {
    weak var owner: WebViewController?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { log("message \(message.name) \(message.body)"); return }
        switch body["kind"] as? String {
        case "tap":
            let list = (body["list"] as? [Any]).map { $0.map { "\($0)" }.joined(separator: ",") } ?? ""
            log("message \(message.name) tap count=\(body["count"] as? Int ?? -1) list=\(list) main=\(message.frameInfo.isMainFrame)")
            owner?.status.text = "taps: \(body["count"] as? Int ?? -1)"
        case "out":
            log("page out: \(body["text"] as? String ?? "")")
            owner?.status.text = body["text"] as? String
        case "injected":
            log("user script ran: \(body["where"] as? String ?? "")")
        default: log("message \(body)")
        }
    }
}

final class CalcHandler: NSObject, WKScriptMessageHandlerWithReply {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        let o = message.body as? [String: Any] ?? [:]
        let r = (o["a"] as? Int ?? 0) * (o["b"] as? Int ?? 0)
        log("calc \(o["a"] ?? "-") * \(o["b"] ?? "-") = \(r)")
        return (r, nil)
    }
}

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    var web: WKWebView!
    let status = UILabel()
    let progress = UIProgressView(progressViewStyle: .bar)
    var observations: [NSKeyValueObservation] = []
    let messages = MessageHandler()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Web"
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(DemoSchemeHandler(), forURLScheme: "isim-demo")
        let ucc = config.userContentController
        messages.owner = self
        ucc.add(messages, name: "native")
        ucc.addScriptMessageHandler(CalcHandler(), contentWorld: .page, name: "calc")
        ucc.addUserScript(WKUserScript(source: """
            var d = document.createElement('div'); d.id = 'injected'; d.textContent = 'Injected by WKUserScript';
            d.style.cssText = 'position:absolute;top:490px;left:16px;color:rgb(0,128,0);font-size:16px';
            document.body.appendChild(d);
            window.webkit.messageHandlers.native.postMessage({kind: 'injected', where: location.protocol});
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: "var secretWorldValue = 'only in the client world';", injectionTime: .atDocumentStart,
                                       forMainFrameOnly: true, in: .defaultClient))
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.accessibilityIdentifier = "web"
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)

        progress.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progress)
        status.text = "–"; status.font = .systemFont(ofSize: 15); status.accessibilityIdentifier = "status"
        status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status)

        let bar = UIStackView(); bar.axis = .horizontal; bar.distribution = .fillEqually; bar.spacing = 4
        bar.translatesAutoresizingMaskIntoConstraints = false
        for (t, id, sel) in [("Back", "back", #selector(back)), ("Fwd", "forward", #selector(forward)), ("Reload", "reload", #selector(reload)),
                             ("JS", "eval", #selector(evalJS)), ("Snap", "snapshot", #selector(snapshot)), ("Cookies", "cookies", #selector(cookies))] as [(String, String, Selector)] {
            let b = UIButton(type: .system); b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            bar.addArrangedSubview(b)
        }
        view.addSubview(bar)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: g.topAnchor), progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.topAnchor.constraint(equalTo: g.topAnchor, constant: 2), web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor), web.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -4),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            status.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -2), status.heightAnchor.constraint(equalToConstant: 22),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8), bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            bar.bottomAnchor.constraint(equalTo: g.bottomAnchor), bar.heightAnchor.constraint(equalToConstant: 40),
        ])

        observations = [
            web.observe(\.title, options: [.new]) { [weak self] w, _ in log("kvo title=\(w.title ?? "nil")"); self?.title = w.title },
            web.observe(\.url, options: [.new]) { w, _ in log("kvo url=\(w.url?.absoluteString ?? "nil")") },
            web.observe(\.estimatedProgress, options: [.new]) { [weak self] w, _ in
                self?.progress.progress = Float(w.estimatedProgress)
                if w.estimatedProgress >= 1 { log("kvo progress=1.0") }
            },
            web.observe(\.canGoBack, options: [.new]) { w, _ in log("kvo canGoBack=\(w.canGoBack)") },
            web.observe(\.isLoading, options: [.new]) { [weak self] w, _ in self?.progress.isHidden = !w.isLoading },
        ]
        let base = URL(string: serverURL + "/")!
        web.loadHTMLString(homeHTML.replacingOccurrences(of: "SERVER", with: serverURL), baseURL: base)
    }

    // MARK: navigation delegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let u = navigationAction.request.url?.absoluteString ?? "-"
        let type: String = switch navigationAction.navigationType {
        case .linkActivated: "linkActivated"; case .formSubmitted: "formSubmitted"; case .backForward: "backForward"
        case .reload: "reload"; case .formResubmitted: "formResubmitted"; case .other: "other"; @unknown default: "?"
        }
        if navigationAction.request.url?.host == "blocked.example" {
            log("policy \(type) \(u) -> cancel")
            status.text = "blocked \(navigationAction.request.url!.host!)"
            return .cancel
        }
        log("policy \(type) \(u) -> allow")
        return .allow
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let status = (navigationResponse.response as? HTTPURLResponse)?.statusCode ?? 0
        log("response \(status) \(navigationResponse.response.mimeType ?? "-") canShow=\(navigationResponse.canShowMIMEType) main=\(navigationResponse.isForMainFrame)")
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { log("didStart \(webView.url?.absoluteString ?? "-")") }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { log("didCommit") }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log("didFinish \(webView.url?.absoluteString ?? "-") title=\(webView.title ?? "-") back=\(webView.backForwardList.backList.count)")
        webView.evaluateJavaScript("navigator.userAgent") { r, _ in log("userAgent: \(r as? String ?? "-")") }
        webView.evaluateJavaScript("typeof secretWorldValue") { r, _ in log("page world sees secretWorldValue: \(r as? String ?? "-")") }
        webView.evaluateJavaScript("secretWorldValue", in: nil, in: .defaultClient) { r in
            if case .success(let v) = r { log("client world value: \(v)") }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let e = error as NSError
        log("didFailProvisional \(e.domain) \(e.code)")
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { log("didFail \((error as NSError).code)") }

    // MARK: UI delegate (presented like Safari's JavaScript panels)
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        log("alert panel: \(message) from \(frame.securityOrigin.host)")
        let a = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
        log("confirm panel: \(message)")
        return await withCheckedContinuation { c in
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in c.resume(returning: false) })
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in c.resume(returning: true) })
            present(a, animated: true)
        }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        log("prompt panel: \(prompt) default=\(defaultText ?? "-")")
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        present(a, animated: true)
    }

    // MARK: buttons
    @objc func back() { web.goBack() }
    @objc func forward() { web.goForward() }
    @objc func reload() { web.reload() }
    @objc func evalJS() {
        web.evaluateJavaScript("document.title.length * 2") { r, e in log("eval completion: \(r ?? "nil") error=\(e == nil ? "none" : "\(e!)")") }
        Task {
            do {
                let t = try await web.evaluateJavaScript("document.getElementById('field') ? document.getElementById('field').value : 'no field'")
                log("eval async: \(t)")
                _ = try await web.evaluateJavaScript("nosuchFunction()")
            } catch let e as WKError {
                log("eval threw WKError code=\(e.code.rawValue) message=\(e.userInfo[WKJavaScriptExceptionMessageErrorKey] ?? "-")")
            } catch { log("eval threw \(error)") }
            let v = try? await web.callAsyncJavaScript("return await new Promise(r => setTimeout(() => r(a * b + c.length), 30))",
                                                       arguments: ["a": 6, "b": 7, "c": "xyz"], contentWorld: .page)
            log("callAsyncJavaScript: \(v.map { "\($0)" } ?? "nil")")
            let obj = try? await web.evaluateJavaScript("({n: 1.5, s: 'x', a: [1, 2], nested: {ok: true}})")
            if let d = obj as? [String: Any] { log("eval object: n=\(d["n"] ?? "-") s=\(d["s"] ?? "-") a=\((d["a"] as? [Any])?.count ?? -1) ok=\((d["nested"] as? [String: Any])?["ok"] ?? "-")") }
        }
    }
    @objc func snapshot() {
        web.takeSnapshot(with: nil) { img, e in
            guard let img else { log("snapshot failed \(String(describing: e))"); return }
            log("snapshot \(Int(img.size.width))x\(Int(img.size.height)) scale=\(Int(img.scale))")
        }
    }
    @objc func cookies() {
        web.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let s = cookies.map { "\($0.name)=\($0.value)@\($0.domain)" }.sorted().joined(separator: ",")
            log("cookies: \(s)")
        }
    }
}
