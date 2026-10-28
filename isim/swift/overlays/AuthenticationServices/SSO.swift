// Enterprise single sign-on (adapted): an identity provider's SSO extension (NSExtensionPointIdentifier
// com.apple.AppSSO.idp-extension) signs users in for apps that ask with ASAuthorizationSingleSignOnProvider. On iOS an
// MDM profile maps the identity provider's URLs to the extension; isim keeps that mapping in the device data
// (Library/isim/SSO/profiles.json, written by `isim sso add <extension bundle id> <url>`). The extension runs in the
// app's process: its principal class (an ASAuthorizationProviderExtensionAuthorizationRequestHandler, usually a view
// controller) gets beginAuthorization(with:), and the request's complete(...) / doNotHandle / cancel end the app's
// ASAuthorizationController request. Requests to those URLs from Safari, WebKit or URLSession are not intercepted.
import Foundation
import UIKit

@objc(ASAuthorizationSingleSignOnProvider) open class ASAuthorizationSingleSignOnProvider: NSObject, ASAuthorizationProvider {
    @objc public let url: URL
    public init(identityProvider url: URL) { self.url = url }
    @objc(authorizationProviderWithIdentityProviderURL:) public class func _objc_provider(url: URL) -> ASAuthorizationSingleSignOnProvider { ASAuthorizationSingleSignOnProvider(identityProvider: url) }
    /// whether an SSO extension is configured for this identity provider
    @objc open var canPerformAuthorization: Bool { _ASSSO.profile(for: url) != nil }
    @objc open func createRequest() -> ASAuthorizationSingleSignOnRequest { ASAuthorizationSingleSignOnRequest(provider: self) }
}

@objc(ASAuthorizationSingleSignOnRequest) open class ASAuthorizationSingleSignOnRequest: ASAuthorizationOpenIDRequest {
    @objc open var authorizationOptions: [URLQueryItem] = []
    @objc(isUserInterfaceEnabled) open var isUserInterfaceEnabled = true
}

@objc(ASAuthorizationSingleSignOnCredential) open class ASAuthorizationSingleSignOnCredential: NSObject, ASAuthorizationCredential, NSSecureCoding, @unchecked Sendable {
    @objc public let state: String?
    @objc public let accessToken: Data?
    @objc public let identityToken: Data?
    public let authorizedScopes: [ASAuthorization.Scope]
    @objc public let authenticatedResponse: HTTPURLResponse?
    @objc(authorizedScopes) var _objc_authorizedScopes: [String] { authorizedScopes.map(\.rawValue) }
    init(state: String?, accessToken: Data?, identityToken: Data?, scopes: [ASAuthorization.Scope], response: HTTPURLResponse?) {
        self.state = state; self.accessToken = accessToken; self.identityToken = identityToken; authorizedScopes = scopes; authenticatedResponse = response
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(state, forKey: "state"); coder.encode(accessToken, forKey: "accessToken"); coder.encode(identityToken, forKey: "identityToken")
        coder.encode(authorizedScopes.map(\.rawValue), forKey: "scopes")
    }
    public required init?(coder: NSCoder) {
        state = coder.decodeObject(of: NSString.self, forKey: "state") as String?
        accessToken = coder.decodeObject(of: NSData.self, forKey: "accessToken") as Data?
        identityToken = coder.decodeObject(of: NSData.self, forKey: "identityToken") as Data?
        authorizedScopes = ((coder.decodeObject(forKey: "scopes") as? [String]) ?? []).map(ASAuthorization.Scope.init(rawValue:))
        authenticatedResponse = nil
    }
}

/// What an SSO request asks the extension to do.
public struct ASAuthorizationProviderAuthorizationOperation: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let configurationRemoved = ASAuthorizationProviderAuthorizationOperation(rawValue: "configuration_removed")
    public static let directRequest = ASAuthorizationProviderAuthorizationOperation(rawValue: "direct_request")
}

@objc(ASAuthorizationProviderExtensionAuthorizationRequestHandler) public protocol ASAuthorizationProviderExtensionAuthorizationRequestHandler: NSObjectProtocol {
    func beginAuthorization(with request: ASAuthorizationProviderExtensionAuthorizationRequest)
    @objc optional func cancelAuthorization(with request: ASAuthorizationProviderExtensionAuthorizationRequest)
}

@objc(ASAuthorizationProviderExtensionAuthorizationResult) open class ASAuthorizationProviderExtensionAuthorizationResult: NSObject, @unchecked Sendable {
    @objc open var httpAuthorizationHeaders: [String: String]?
    @objc open var httpResponse: HTTPURLResponse?
    @objc open var httpBody: Data?
    @objc(initWithHTTPAuthorizationHeaders:) public init(httpAuthorizationHeaders: [String: String]) { self.httpAuthorizationHeaders = httpAuthorizationHeaders }
    @objc(initWithHTTPResponse:httpBody:) public init(httpResponse: HTTPURLResponse, httpBody: Data?) { self.httpResponse = httpResponse; self.httpBody = httpBody }
    /// the names before iOS 15 (Objective-C: initWithHTTPAuthorizationHeaders:)
    public convenience init(HTTPAuthorizationHeaders: [String: String]) { self.init(httpAuthorizationHeaders: HTTPAuthorizationHeaders) }
    public convenience init(HTTPResponse: HTTPURLResponse, httpBody: Data?) { self.init(httpResponse: HTTPResponse, httpBody: httpBody) }
}

/// The request an SSO extension handles.
@objc(ASAuthorizationProviderExtensionAuthorizationRequest) open class ASAuthorizationProviderExtensionAuthorizationRequest: NSObject, @unchecked Sendable {
    @objc public let url: URL
    public let requestedOperation: ASAuthorizationProviderAuthorizationOperation
    @objc public let httpHeaders: [String: String]
    @objc public let httpBody: Data
    @objc public let realm: String
    @objc public let extensionData: [AnyHashable: Any]
    @objc public let callerBundleIdentifier: String
    @objc public let callerTeamIdentifier: String
    @objc public let localizedCallerDisplayName: String
    @objc public let authorizationOptions: [AnyHashable: Any]
    @objc(isCallerManaged) public let isCallerManaged: Bool
    @objc(isUserInterfaceEnabled) public let isUserInterfaceEnabled: Bool
    @objc(requestedOperation) var _objc_requestedOperation: String { requestedOperation.rawValue }
    /// the caller's audit token: isim's caller is this process
    public var callerAuditToken: Data { Data(count: 32) }
    /// the result (nil: completed without one), or the code the app's request fails with
    var finish: ((ASAuthorizationProviderExtensionAuthorizationResult?, ASAuthorizationError.Code?) -> Void)?
    var present: (() -> Void)?

    init(url: URL, operation: ASAuthorizationProviderAuthorizationOperation, realm: String, extensionData: [AnyHashable: Any],
         options: [AnyHashable: Any], ui: Bool) {
        self.url = url; requestedOperation = operation; httpHeaders = [:]; httpBody = Data(); self.realm = realm; self.extensionData = extensionData
        callerBundleIdentifier = _ASData.bundleID; callerTeamIdentifier = ""; localizedCallerDisplayName = _ASData.appName
        authorizationOptions = options; isCallerManaged = false; isUserInterfaceEnabled = ui
    }
    private func end(_ r: ASAuthorizationProviderExtensionAuthorizationResult?, _ code: ASAuthorizationError.Code? = nil) {
        let f = finish; finish = nil
        DispatchQueue.main.async { f?(r, code) }
    }
    /// the extension does not handle this request (the app's request fails with .notHandled)
    @objc open func doNotHandle() { NSLog("isim AuthenticationServices: SSO extension: not handled"); end(nil, .notHandled) }
    @objc open func cancel() { NSLog("isim AuthenticationServices: SSO extension: cancelled"); end(nil, .canceled) }
    @objc open func complete() { end(nil) }
    @objc(completeWithHTTPAuthorizationHeaders:) open func complete(httpAuthorizationHeaders: [String: String]) { end(ASAuthorizationProviderExtensionAuthorizationResult(httpAuthorizationHeaders: httpAuthorizationHeaders)) }
    @objc(completeWithHTTPResponse:httpBody:) open func complete(httpResponse: HTTPURLResponse, httpBody: Data?) { end(ASAuthorizationProviderExtensionAuthorizationResult(httpResponse: httpResponse, httpBody: httpBody)) }
    @objc(completeWithAuthorizationResult:) open func complete(authorizationResult: ASAuthorizationProviderExtensionAuthorizationResult) { end(authorizationResult) }
    @objc(completeWithError:) open func complete(error: Error) {
        NSLog("isim AuthenticationServices: SSO extension failed: %@", String(describing: error))
        end(nil, .failed)
    }
    /// shows the extension's view controller (when the request allows UI)
    @objc(presentAuthorizationViewControllerWithCompletion:) open func presentAuthorizationViewController(completion: @escaping (Bool, Error?) -> Void) {
        guard isUserInterfaceEnabled, let p = present else { completion(false, ASAuthorizationError(.notInteractive)); return }
        DispatchQueue.main.async { p(); completion(true, nil) }
    }
}

// MARK: - isim: profiles and hosting

enum _ASSSO {
    static let point = "com.apple.AppSSO.idp-extension"
    static var file: String {
        let p = (_ASData.dataDir as NSString).appendingPathComponent("Library/isim/SSO")
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true, attributes: nil)
        return (p as NSString).appendingPathComponent("profiles.json")
    }
    /// the profile ({extension, urls, realm, extensionData}) whose URLs cover this one (same scheme and host, path prefix)
    static func profile(for url: URL) -> [String: Any]? {
        let list = _ASData.readJSON(file) as? [[String: Any]] ?? []
        return list.first { p in
            (p["urls"] as? [String] ?? []).contains { s in
                guard let u = URL(string: s) else { return false }
                return u.scheme?.lowercased() == url.scheme?.lowercased() && u.host?.lowercased() == url.host?.lowercased() && url.path.hasPrefix(u.path)
            }
        }
    }
    /// the extension with this bundle identifier: in this app, else in an installed app
    static func extensionPath(_ bundleID: String) -> String? {
        var apps = [Bundle.main.bundlePath]
        let env = ProcessInfo.processInfo.environment
        let installed = env["ISIM_APPS"] ?? (_ASData.dataDir as NSString).appendingPathComponent("Applications")
        apps += ((try? FileManager.default.contentsOfDirectory(atPath: installed)) ?? []).filter { $0.hasSuffix(".app") }.map { (installed as NSString).appendingPathComponent($0) }
        for a in apps {
            let plugins = (a as NSString).appendingPathComponent("PlugIns")
            for n in (try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? [] where n.hasSuffix(".appex") {
                let p = (plugins as NSString).appendingPathComponent(n)
                let info = NSDictionary(contentsOfFile: (p as NSString).appendingPathComponent("Info.plist")) as? [String: Any]
                if info?["CFBundleIdentifier"] as? String == bundleID, (info?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == point { return p }
            }
        }
        return nil
    }

    @MainActor static func perform(_ c: ASAuthorizationController, _ r: ASAuthorizationSingleSignOnRequest) {
        guard let provider = r.provider as? ASAuthorizationSingleSignOnProvider, let profile = profile(for: provider.url),
              let id = profile["extension"] as? String, let path = extensionPath(id) else {
            NSLog("isim AuthenticationServices: no SSO extension is configured for %@ (isim sso add <extension> <url>)", (r.provider as? ASAuthorizationSingleSignOnProvider)?.url.absoluteString ?? "?")
            c.fail(.notHandled); return
        }
        let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
        let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let exe = (path as NSString).appendingPathComponent(info["CFBundleExecutable"] as? String ?? base)
        guard dlopen(exe, RTLD_NOW) != nil else {
            NSLog("isim AuthenticationServices: cannot load the SSO extension %@: %s", id, dlerror().map { String(cString: $0) } ?? "?"); c.fail(.failed); return
        }
        _isimRegisterExtensionBundle(path as NSString)
        let ext = info["NSExtension"] as? [String: Any] ?? [:]
        guard let name = ext["NSExtensionPrincipalClass"] as? String, let cls = NSClassFromString(name) as? NSObject.Type,
              let handler = cls.init() as? ASAuthorizationProviderExtensionAuthorizationRequestHandler else {
            NSLog("isim AuthenticationServices: the SSO extension %@ has no ASAuthorizationProviderExtensionAuthorizationRequestHandler principal class", id)
            c.fail(.failed); return
        }
        // the identity provider URL with the request's options (OpenID's scope, state, nonce and the app's query items)
        var comps = URLComponents(url: provider.url, resolvingAgainstBaseURL: false) ?? URLComponents()
        var items = comps.queryItems ?? []
        if let s = r.requestedScopes, !s.isEmpty { items.append(URLQueryItem(name: "scope", value: (["openid"] + s.map(\.rawValue)).joined(separator: " "))) }
        if let s = r.state { items.append(URLQueryItem(name: "state", value: s)) }
        if let n = r.nonce { items.append(URLQueryItem(name: "nonce", value: n)) }
        items += r.authorizationOptions
        comps.queryItems = items.isEmpty ? nil : items
        let url = comps.url ?? provider.url
        var options: [AnyHashable: Any] = [:]
        for i in r.authorizationOptions { options[i.name] = i.value ?? "" }
        let op = r.requestedOperation.rawValue.isEmpty ? ASAuthorizationProviderAuthorizationOperation(rawValue: "") : ASAuthorizationProviderAuthorizationOperation(rawValue: r.requestedOperation.rawValue)
        let request = ASAuthorizationProviderExtensionAuthorizationRequest(url: url, operation: op, realm: profile["realm"] as? String ?? "",
                                                                           extensionData: profile["extensionData"] as? [String: Any] ?? [:], options: options, ui: r.isUserInterfaceEnabled)
        let vc = handler as? UIViewController
        var presented = false
        request.present = {
            guard let vc, !presented else { return }
            presented = true
            vc.modalPresentationStyle = .pageSheet
            NSLog("isim AuthenticationServices: SSO extension %@ shows its UI", id)
            c.anchorController()?.present(vc, animated: true)
        }
        request.finish = { res, failure in
            _ASSSO.active = nil
            let done = {
                if let failure { c.fail(failure); return }
                do {
                    var response = res?.httpResponse
                    if response == nil, let h = res?.httpAuthorizationHeaders {
                        response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: h)
                    }
                    // OAuth / OpenID tokens in a JSON body (access_token, id_token)
                    let json = res?.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                    let cred = ASAuthorizationSingleSignOnCredential(state: r.state, accessToken: (json?["access_token"] as? String).map { Data($0.utf8) },
                                                                     identityToken: (json?["id_token"] as? String).map { Data($0.utf8) },
                                                                     scopes: r.requestedScopes ?? [], response: response)
                    NSLog("isim AuthenticationServices: SSO extension %@ signed in (HTTP %d)", id, response?.statusCode ?? 0)
                    c.complete(provider, cred)
                }
            }
            if presented, let vc, vc.presentingViewController != nil { vc.dismiss(animated: true, completion: done) } else { done() }
        }
        _ASSSO.active = (handler, request)
        NSLog("isim AuthenticationServices: running the SSO extension %@ for %@ in the app process", id, url.absoluteString)
        if let vc { vc.loadViewIfNeeded() }
        handler.beginAuthorization(with: request)
    }
    /// the extension and its request while it runs (apps hold neither)
    @MainActor static var active: (ASAuthorizationProviderExtensionAuthorizationRequestHandler, ASAuthorizationProviderExtensionAuthorizationRequest)?
}
