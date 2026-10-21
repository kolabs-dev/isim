// Sample: App Transport Security. Info.plist's NSAppTransportSecurity allows local networking (which makes its
// NSAllowsArbitraryLoads ignored) and has exception domains: insecure.localhost and its subdomains may use cleartext
// HTTP, except secure.insecure.localhost; tls13.localhost needs TLS 1.3; legacy.localhost may skip forward secrecy.
// Loads with URLSession (data tasks, a redirect, a WebSocket task) and WKWebView, logging each result.
//   isim run out/apps/HelloTransportSecurity.app -- -http PORT -tls12 PORT -rsa PORT
// (an HTTP server with /redirect?to=URL, an HTTPS server of TLS 1.2 at most, one with only RSA key exchange)
import UIKit
import WebKit

func log(_ s: String) { FileHandle.standardError.write(Data(("HelloTransportSecurity: " + s + "\n").utf8)) }   // unbuffered
func arg(_ name: String) -> String {
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: name), i + 1 < a.count { return a[i + 1] }
    return "9"
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: TransportViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

/// trusts the test servers' throwaway certificates, so the loads show ATS's TLS requirements rather than trust
final class TrustingDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let trust = challenge.protectionSpace.serverTrust else { return (.performDefaultHandling, nil) }
        return (.useCredential, URLCredential(trust: trust))
    }
}

final class TransportViewController: UIViewController, WKNavigationDelegate {
    let session = URLSession(configuration: .ephemeral, delegate: TrustingDelegate(), delegateQueue: nil)
    var web: WKWebView!
    let status = UILabel()
    var webLoads: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Transport Security"
        view.backgroundColor = .systemBackground
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .footnote)
        web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.navigationDelegate = self
        let stack = UIStackView(arrangedSubviews: [status, web])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            web.heightAnchor.constraint(equalToConstant: 200),
        ])
        Task { await run() }
    }

    func load(_ label: String, _ url: String) async -> String {
        do {
            let (_, r) = try await session.data(from: URL(string: url)!)
            return "\(label) status=\((r as? HTTPURLResponse)?.statusCode ?? 0)"
        } catch let e as URLError {
            return "\(label) error=\(e.code.rawValue)" + (e.code == .appTransportSecurityRequiresSecureConnection ? " (\(e.localizedDescription))" : "")
        } catch {
            return "\(label) error=\(error)"
        }
    }

    func run() async {
        let http = arg("-http"), tls12 = arg("-tls12"), rsa = arg("-rsa")
        var lines: [String] = []
        for (label, url) in [
            ("ip", "http://127.0.0.1:\(http)/"),                                  // IP addresses: not subject to ATS
            ("localhost", "http://localhost:\(http)/"),                           // NSAllowsLocalNetworking
            ("blocked", "http://blocked.localhost:\(http)/"),                     // NSAllowsArbitraryLoads is ignored
            ("exception", "http://insecure.localhost:\(http)/"),                  // NSExceptionAllowsInsecureHTTPLoads
            ("subdomain", "http://api.insecure.localhost:\(http)/"),              // NSIncludesSubdomains
            ("specific", "http://secure.insecure.localhost:\(http)/"),            // the most specific entry wins
            ("redirect", "http://127.0.0.1:\(http)/redirect?to=http://blocked.localhost:\(http)/"),   // each hop is checked
            ("https", "https://plain.localhost:\(tls12)/"),                       // TLS 1.2 with forward secrecy
            ("tls13", "https://tls13.localhost:\(tls12)/"),                       // NSExceptionMinimumTLSVersion
            ("nofs", "https://plain.localhost:\(rsa)/"),                          // forward secrecy is required
            ("legacy", "https://legacy.localhost:\(rsa)/"),                       // NSExceptionRequiresForwardSecrecy
        ] {
            let line = await load(label, url)
            log(line)
            lines.append(line)
        }
        // a WebSocket task: ws:// is cleartext too
        let ws = session.webSocketTask(with: URL(string: "ws://blocked.localhost:\(http)/")!)
        ws.resume()
        do { _ = try await ws.receive(); log("websocket opened") }
        catch { let line = "websocket error=\((error as? URLError)?.code.rawValue ?? 0)"; log(line); lines.append(line) }
        status.text = lines.joined(separator: "\n")
        status.accessibilityIdentifier = "results"

        // WKWebView: a blocked navigation fails provisionally; a local one loads
        webLoads = ["http://blocked.localhost:\(http)/", "http://localhost:\(http)/"]
        nextWebLoad()
    }

    func nextWebLoad() {
        guard !webLoads.isEmpty else { log("done"); return }
        web.load(URLRequest(url: URL(string: webLoads.removeFirst())!))
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log("web didFinish \(webView.url?.absoluteString ?? "")")
        nextWebLoad()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let e = error as NSError
        log("web didFailProvisionalNavigation \(e.domain) \(e.code) \((e.userInfo[NSURLErrorFailingURLStringErrorKey] as? String) ?? "")")
        nextWebLoad()
    }
}
