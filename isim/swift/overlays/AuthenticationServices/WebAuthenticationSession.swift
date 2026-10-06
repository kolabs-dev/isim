// isim AuthenticationServices: ASWebAuthenticationSession (OAuth / web sign-in) and SwiftUI's
// WebAuthenticationSession environment action.
//
// Like iOS: start() asks "“App” Wants to Use “host” to Sign In" (skipped for ephemeral sessions), then shows the
// page in a browser sheet (SafariServices' browser on isim's WKWebView, real WebKit). The first navigation —
// link, form, script or server redirect — to the callback (a custom scheme, or https host+path on iOS 17.4)
// ends the session with that URL; Cancel ends it with ASWebAuthenticationSessionError.canceledLogin.
// Adapted: non-ephemeral sessions share SFSafariViewController's (in-memory) website data, not Safari's.
import UIKit
import WebKit
import SafariServices
import SwiftUI

/* ASPresentationAnchor is declared in Core.swift */

@objc public protocol ASWebAuthenticationPresentationContextProviding: NSObjectProtocol {
    @MainActor func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor
}

public let ASWebAuthenticationSessionErrorDomain = "com.apple.AuthenticationServices.WebAuthenticationSession"

public struct ASWebAuthenticationSessionError: Error, CustomNSError, Hashable, LocalizedError, @unchecked Sendable {
    public enum Code: Int, Sendable { case canceledLogin = 1, presentationContextNotProvided = 2, presentationContextInvalid = 3 }
    public let code: Code
    public let userInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
    public static var errorDomain: String { ASWebAuthenticationSessionErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { userInfo }
    public var errorDescription: String? {
        userInfo[NSLocalizedDescriptionKey] as? String ?? "The operation couldn’t be completed. (\(ASWebAuthenticationSessionErrorDomain) error \(code.rawValue).)"
    }
    public static func == (a: Self, b: Self) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
    public static var canceledLogin: Code { .canceledLogin }
    public static var presentationContextNotProvided: Code { .presentationContextNotProvided }
    public static var presentationContextInvalid: Code { .presentationContextInvalid }
}

@MainActor
open class ASWebAuthenticationSession: NSObject {
    public typealias CompletionHandler = (URL?, Error?) -> Void
    /// iOS 17.4: what ends the session
    public final class Callback: NSObject, @unchecked Sendable {
        enum Kind { case scheme(String), https(host: String, path: String) }
        let kind: Kind
        init(_ k: Kind) { kind = k }
        public static func customScheme(_ customScheme: String) -> Callback { Callback(.scheme(customScheme.lowercased())) }
        public static func https(host: String, path: String) -> Callback { Callback(.https(host: host.lowercased(), path: path)) }
        public func matchesURL(_ url: URL) -> Bool {
            switch kind {
            case .scheme(let s): return url.scheme?.lowercased() == s
            case .https(let host, let path): return url.scheme?.lowercased() == "https" && url.host?.lowercased() == host && url.path == path
            }
        }
    }

    open weak var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?
    open var prefersEphemeralWebBrowserSession = false
    open var additionalHeaderFields: [String: String]?
    open var canStart: Bool { state == .idle }
    let url: URL
    let callback: Callback?
    var completion: CompletionHandler?
    enum State { case idle, running, done }
    var state = State.idle
    weak var browser: _SFBrowserViewController?
    var alert: UIAlertController?
    var keepAlive: ASWebAuthenticationSession?

    public init(url URL: URL, callbackURLScheme: String?, completionHandler: @escaping CompletionHandler) {
        url = URL
        callback = callbackURLScheme.map { Callback.customScheme($0) }
        completion = completionHandler
        super.init()
    }
    public init(url URL: URL, callback: Callback, completionHandler: @escaping CompletionHandler) {
        url = URL
        self.callback = callback
        completion = completionHandler
        super.init()
    }

    @discardableResult
    open func start() -> Bool {
        guard state == .idle else { return false }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            NSException(name: "NSInvalidArgumentException", reason: "The provided scheme is not valid. A scheme should not include special characters such as \":\" or \"/\".", userInfo: nil).raise()
            return false
        }
        guard let provider = presentationContextProvider else {
            finish(nil, ASWebAuthenticationSessionError(.presentationContextNotProvided)); return false
        }
        let anchor = provider.presentationAnchor(for: self)
        guard let root = anchor.rootViewController else {
            finish(nil, ASWebAuthenticationSessionError(.presentationContextInvalid)); return false
        }
        state = .running
        keepAlive = self
        var top = root
        while let p = top.presentedViewController, !p.isBeingDismissed { top = p }
        print("isim: ASWebAuthenticationSession: \(url.absoluteString) (callback \(callbackDescription))\(prefersEphemeralWebBrowserSession ? " ephemeral" : "")")
        if prefersEphemeralWebBrowserSession { present(from: top) }
        else {
            let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
            let a = UIAlertController(title: "“\(app)” Wants to Use “\(url.host ?? url.absoluteString)” to Sign In",
                                      message: "This allows the app and website to share information about you.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.finish(nil, ASWebAuthenticationSessionError(.canceledLogin))
            })
            a.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self, weak top] _ in
                guard let self, let top, self.state == .running else { return }
                self.present(from: top)
            })
            alert = a
            top.present(a, animated: true)
        }
        return true
    }
    var callbackDescription: String {
        switch callback?.kind {
        case .scheme(let s)?: return s + "://"
        case .https(let h, let p)?: return "https://\(h)\(p)"
        case nil: return "none"
        }
    }
    func present(from top: UIViewController) {
        let store: WKWebsiteDataStore = prefersEphemeralWebBrowserSession ? .nonPersistent() : _SFSafariStore.store
        let b = _SFBrowserViewController(url: url, store: store, headers: additionalHeaderFields ?? [:])
        b.dismissTitle = "Cancel"
        b.showsToolbar = false
        b.shouldNavigate = { [weak self] u in
            guard let self, self.state == .running else { return true }
            if let cb = self.callback, cb.matchesURL(u) {
                print("isim: ASWebAuthenticationSession: callback \(u.absoluteString)")
                self.finish(u, nil)
                return false
            }
            return true
        }
        b.onDismiss = { [weak self] in self?.finish(nil, ASWebAuthenticationSessionError(.canceledLogin)) }
        browser = b
        top.present(b, animated: true)
    }
    open func cancel() {
        guard state == .running else { return }
        finish(nil, ASWebAuthenticationSessionError(.canceledLogin))
    }
    func finish(_ u: URL?, _ e: Error?) {
        guard state != .done else { return }
        state = .done
        let done = completion
        completion = nil
        let deliver = { [self] in
            done?(u, e)
            keepAlive = nil
        }
        if let b = browser, b.presentingViewController != nil { b.dismiss(animated: true) { deliver() } }
        else if let a = alert, a.presentingViewController != nil { a.dismiss(animated: true) { deliver() } }
        else { DispatchQueue.main.async { deliver() } }
    }
}


// MARK: - SwiftUI (iOS 16.4+)

public struct WebAuthenticationSession: Sendable {
    public enum BrowserSession: Sendable, Hashable { case ephemeral, shared }
    @MainActor final class Provider: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first ?? UIWindow()
        }
    }
    @MainActor
    func run(_ s: ASWebAuthenticationSession, _ pref: BrowserSession, _ headers: [String: String]) async throws -> URL {
        let provider = Provider()
        s.presentationContextProvider = provider
        s.prefersEphemeralWebBrowserSession = pref == .ephemeral
        s.additionalHeaderFields = headers.isEmpty ? nil : headers
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<URL, Error>) in
            let prev = s.completion
            s.completion = { u, e in
                _ = provider
                prev?(u, e)
                if let u { c.resume(returning: u) } else { c.resume(throwing: e ?? ASWebAuthenticationSessionError(.canceledLogin)) }
            }
            s.start()
        }
    }
    @MainActor
    public func authenticate(using url: URL, callbackURLScheme: String, preferredBrowserSession: BrowserSession? = nil) async throws -> URL {
        try await run(ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { _, _ in }, preferredBrowserSession ?? .shared, [:])
    }
    @MainActor
    public func authenticate(using url: URL, callback: ASWebAuthenticationSession.Callback, preferredBrowserSession: BrowserSession? = nil,
                             additionalHeaderFields: [String: String]) async throws -> URL {
        try await run(ASWebAuthenticationSession(url: url, callback: callback) { _, _ in }, preferredBrowserSession ?? .shared, additionalHeaderFields)
    }
}

struct _WebAuthenticationSessionKey: EnvironmentKey { static let defaultValue = WebAuthenticationSession() }
extension EnvironmentValues {
    public var webAuthenticationSession: WebAuthenticationSession {
        get { self[_WebAuthenticationSessionKey.self] }
        set { self[_WebAuthenticationSessionKey.self] = newValue }
    }
}
