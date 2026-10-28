// Account modification extensions (adapted): an app's extension (NSExtensionPointIdentifier
// com.apple.authentication-services-account-authentication-modification-ui) upgrades one of its accounts, a saved
// password, to a strong password or to Sign in with Apple, when ASAccountAuthenticationModificationController asks
// (iOS: password managers and Settings' security recommendations). isim finds the extension of the app whose
// webcredentials domains include the service (this app, else an installed one), runs it in this process with the
// saved password from the device's Passwords store, and updates the store: the new strong password, or the password
// removed once the account uses Sign in with Apple (isim's local Sign in with Apple, Core.swift).
import Foundation
import UIKit

@objc(ASAccountAuthenticationModificationRequest) open class ASAccountAuthenticationModificationRequest: NSObject, @unchecked Sendable {}

@objc(ASAccountAuthenticationModificationUpgradePasswordToStrongPasswordRequest)
open class ASAccountAuthenticationModificationUpgradePasswordToStrongPasswordRequest: ASAccountAuthenticationModificationRequest, @unchecked Sendable {
    @objc public let user: String
    @objc public let serviceIdentifier: ASCredentialServiceIdentifier
    @objc public let userInfo: [AnyHashable: Any]?
    @objc(initWithUser:serviceIdentifier:userInfo:) public init(user: String, serviceIdentifier: ASCredentialServiceIdentifier, userInfo: [AnyHashable: Any]?) {
        self.user = user; self.serviceIdentifier = serviceIdentifier; self.userInfo = userInfo
    }
}

@objc(ASAccountAuthenticationModificationReplacePasswordWithSignInWithAppleRequest)
open class ASAccountAuthenticationModificationReplacePasswordWithSignInWithAppleRequest: ASAccountAuthenticationModificationRequest, @unchecked Sendable {
    @objc public let user: String
    @objc public let serviceIdentifier: ASCredentialServiceIdentifier
    @objc public let userInfo: [AnyHashable: Any]?
    @objc(initWithUser:serviceIdentifier:userInfo:) public init(user: String, serviceIdentifier: ASCredentialServiceIdentifier, userInfo: [AnyHashable: Any]?) {
        self.user = user; self.serviceIdentifier = serviceIdentifier; self.userInfo = userInfo
    }
}

@objc(ASAccountAuthenticationModificationControllerDelegate) public protocol ASAccountAuthenticationModificationControllerDelegate: NSObjectProtocol {
    @objc(accountAuthenticationModificationController:didSuccessfullyCompleteRequest:withUserInfo:)
    optional func accountAuthenticationModificationController(_ controller: ASAccountAuthenticationModificationController,
                                                              didSuccessfullyComplete request: ASAccountAuthenticationModificationRequest, userInfo: [AnyHashable: Any]?)
    @objc(accountAuthenticationModificationController:didFailRequest:withError:)
    optional func accountAuthenticationModificationController(_ controller: ASAccountAuthenticationModificationController,
                                                              didFail request: ASAccountAuthenticationModificationRequest, error: Error)
}

@objc(ASAccountAuthenticationModificationControllerPresentationContextProviding)
public protocol ASAccountAuthenticationModificationControllerPresentationContextProviding: NSObjectProtocol {
    @objc(presentationAnchorForAccountAuthenticationModificationController:)
    func presentationAnchor(for controller: ASAccountAuthenticationModificationController) -> ASPresentationAnchor
}

@objc(ASAccountAuthenticationModificationController) open class ASAccountAuthenticationModificationController: NSObject {
    @objc weak open var delegate: ASAccountAuthenticationModificationControllerDelegate?
    @objc weak open var presentationContextProvider: ASAccountAuthenticationModificationControllerPresentationContextProviding?
    nonisolated(unsafe) static var active: Set<ASAccountAuthenticationModificationController> = []
    public override init() { super.init() }

    @objc(performRequest:) open func perform(_ request: ASAccountAuthenticationModificationRequest) {
        ASAccountAuthenticationModificationController.active.insert(self)
        DispatchQueue.main.async { MainActor.assumeIsolated { _ASModification.run(self, request) } }
    }
    @MainActor func succeed(_ r: ASAccountAuthenticationModificationRequest, _ info: [AnyHashable: Any]?) {
        ASAccountAuthenticationModificationController.active.remove(self)
        delegate?.accountAuthenticationModificationController?(self, didSuccessfullyComplete: r, userInfo: info)
    }
    @MainActor func fail(_ r: ASAccountAuthenticationModificationRequest, _ e: Error) {
        ASAccountAuthenticationModificationController.active.remove(self)
        delegate?.accountAuthenticationModificationController?(self, didFail: r, error: e)
    }
    @MainActor func anchor() -> UIViewController? {
        var vc = presentationContextProvider?.presentationAnchor(for: self).rootViewController
            ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}

@objc(ASAccountAuthenticationModificationExtensionContext) open class ASAccountAuthenticationModificationExtensionContext: NSExtensionContext, @unchecked Sendable {
    var onPassword: ((ASPasswordCredential, [AnyHashable: Any]?) -> Void)?
    var onAppleID: (([AnyHashable: Any]?) -> Void)?
    var onCancel: ((Error) -> Void)?
    var appleIDCredential: ASAuthorizationAppleIDCredential?
    var done = false
    /// the user's Sign in with Apple authorization for the account (isim's Sign in with Apple sheet)
    @objc(getSignInWithAppleUpgradeAuthorizationWithState:nonce:completionHandler:)
    open func getSignInWithAppleUpgradeAuthorization(state: String?, nonce: String?,
                                                     completionHandler: @escaping (ASAuthorizationAppleIDCredential?, Error?) -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated {
            let r = ASAuthorizationAppleIDProvider().createRequest()
            r.state = state; r.nonce = nonce; r.requestedScopes = [.email]
            let c = ASAuthorizationController(authorizationRequests: [r])
            let d = _ASModificationAppleIDDelegate { cred, e in
                self.appleIDCredential = cred
                completionHandler(cred, e)
            }
            c.delegate = d
            _ASModificationAppleIDDelegate.running = d
            c.performRequests()
        } }
    }
    @objc(completeUpgradeToSignInWithAppleWithUserInfo:) open func completeUpgradeToSignInWithApple(userInfo: [AnyHashable: Any]? = nil) {
        guard !done else { return }; done = true; onAppleID?(userInfo)
    }
    @objc(completeChangePasswordRequestWithUpdatedCredential:userInfo:)
    open func completeChangePasswordRequest(updatedCredential: ASPasswordCredential, userInfo: [AnyHashable: Any]? = nil) {
        guard !done else { return }; done = true; onPassword?(updatedCredential, userInfo)
    }
    open override func cancelRequest(withError error: Error) { guard !done else { return }; done = true; onCancel?(error) }
}

final class _ASModificationAppleIDDelegate: NSObject, ASAuthorizationControllerDelegate {
    nonisolated(unsafe) static var running: _ASModificationAppleIDDelegate?
    let done: (ASAuthorizationAppleIDCredential?, Error?) -> Void
    init(_ done: @escaping (ASAuthorizationAppleIDCredential?, Error?) -> Void) { self.done = done }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        _ASModificationAppleIDDelegate.running = nil
        done(authorization.credential as? ASAuthorizationAppleIDCredential, nil)
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        _ASModificationAppleIDDelegate.running = nil
        done(nil, error)
    }
}

/// The view controller an account modification extension subclasses.
@objc(ASAccountAuthenticationModificationViewController) open class ASAccountAuthenticationModificationViewController: UIViewController {
    var _context = ASAccountAuthenticationModificationExtensionContext()
    open override var extensionContext: ASAccountAuthenticationModificationExtensionContext { _context }
    /// upgrade to Sign in with Apple without UI (or cancel with ASExtensionError.userInteractionRequired)
    @objc(convertAccountToSignInWithAppleWithoutUserInteractionForServiceIdentifier:existingCredential:userInfo:)
    open func convertAccountToSignInWithAppleWithoutUserInteraction(for serviceIdentifier: ASCredentialServiceIdentifier, existingCredential: ASPasswordCredential,
                                                                    userInfo: [AnyHashable: Any]?) {
        extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
    }
    @objc(prepareInterfaceToConvertAccountToSignInWithAppleForServiceIdentifier:existingCredential:userInfo:)
    open func prepareInterfaceToConvertAccountToSignInWithApple(for serviceIdentifier: ASCredentialServiceIdentifier, existingCredential: ASPasswordCredential,
                                                                userInfo: [AnyHashable: Any]?) {}
    /// change the password without UI (or cancel with ASExtensionError.userInteractionRequired)
    @objc(changePasswordWithoutUserInteractionForServiceIdentifier:existingCredential:newPassword:userInfo:)
    open func changePasswordWithoutUserInteraction(for serviceIdentifier: ASCredentialServiceIdentifier, existingCredential: ASPasswordCredential,
                                                   newPassword: String, userInfo: [AnyHashable: Any]?) {
        extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
    }
    @objc(prepareInterfaceToChangePasswordForServiceIdentifier:existingCredential:newPassword:userInfo:)
    open func prepareInterfaceToChangePassword(for serviceIdentifier: ASCredentialServiceIdentifier, existingCredential: ASPasswordCredential,
                                               newPassword: String, userInfo: [AnyHashable: Any]?) {}
    /// the user closed the extension's UI
    @objc open func cancelRequest() { extensionContext.cancelRequest(withError: ASExtensionError(.userCanceled)) }
}

// MARK: - isim: running the extension

enum _ASModification {
    static let point = "com.apple.authentication-services-account-authentication-modification-ui"

    /// the extension of the app whose webcredentials domains include the host (with that app's path)
    static func find(_ host: String) -> (path: String, info: [String: Any])? {
        var apps = [Bundle.main.bundlePath]
        let env = ProcessInfo.processInfo.environment
        let installed = env["ISIM_APPS"] ?? (_ASData.dataDir as NSString).appendingPathComponent("Applications")
        apps += ((try? FileManager.default.contentsOfDirectory(atPath: installed)) ?? []).sorted().filter { $0.hasSuffix(".app") }.map { (installed as NSString).appendingPathComponent($0) }
        for a in apps {
            let ent = NSDictionary(contentsOfFile: (a as NSString).appendingPathComponent("archived-expanded-entitlements.xcent"))
            let domains = (ent?["com.apple.developer.associated-domains"] as? [String] ?? []).filter { $0.hasPrefix("webcredentials:") }
                .map { String($0.dropFirst(15).split(separator: "?").first ?? "").lowercased() }
            guard domains.contains(host) else { continue }
            let plugins = (a as NSString).appendingPathComponent("PlugIns")
            for n in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where n.hasSuffix(".appex") {
                let p = (plugins as NSString).appendingPathComponent(n)
                guard let info = NSDictionary(contentsOfFile: (p as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
                      (info["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == point else { continue }
                return (p, info)
            }
        }
        return nil
    }
    /// Apple's strong password format: xxxxxx-xxxxxx-xxxxxx with one capital and one digit
    static func strongPassword() -> String {
        let lower = Array("abcdefghijkmnopqrstuvwxyz")
        var chars = (0..<20).map { i -> Character in i == 6 || i == 13 ? "-" : lower.randomElement()! }
        let slots = (0..<20).filter { chars[$0] != "-" }.shuffled()
        chars[slots[0]] = Character(String(Int.random(in: 0...9)))
        chars[slots[1]] = Character(chars[slots[1]].uppercased())
        return String(chars)
    }

    @MainActor static func run(_ c: ASAccountAuthenticationModificationController, _ r: ASAccountAuthenticationModificationRequest) {
        let strong = r as? ASAccountAuthenticationModificationUpgradePasswordToStrongPasswordRequest
        let siwa = r as? ASAccountAuthenticationModificationReplacePasswordWithSignInWithAppleRequest
        guard let service = strong?.serviceIdentifier ?? siwa?.serviceIdentifier, let user = strong?.user ?? siwa?.user else {
            c.fail(r, ASExtensionError(.failed)); return
        }
        let info = strong?.userInfo ?? siwa?.userInfo
        guard let existing = _ASPasswords.find(site: service.host, user: user) else {
            NSLog("isim AuthenticationServices: no saved password for %@ on %@", user, service.host)
            c.fail(r, ASExtensionError(.credentialIdentityNotFound)); return
        }
        guard let (path, plist) = find(service.host) else {
            NSLog("isim AuthenticationServices: no app with an account modification extension for %@", service.host)
            c.fail(r, ASExtensionError(.failed)); return
        }
        let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let exe = (path as NSString).appendingPathComponent(plist["CFBundleExecutable"] as? String ?? base)
        guard dlopen(exe, RTLD_NOW) != nil else { c.fail(r, ASExtensionError(.failed)); return }
        _isimRegisterExtensionBundle(path as NSString)
        let ext = plist["NSExtension"] as? [String: Any] ?? [:]
        var made: UIViewController?
        if let n = ext["NSExtensionPrincipalClass"] as? String, let cls = NSClassFromString(n) as? NSObject.Type { made = cls.init() as? UIViewController }
        else if let s = ext["NSExtensionMainStoryboard"] as? String { made = UIStoryboard(name: s, bundle: Bundle(path: path)).instantiateInitialViewController() }
        guard let vc = made as? ASAccountAuthenticationModificationViewController else {
            NSLog("isim AuthenticationServices: the account modification extension at %@ has no ASAccountAuthenticationModificationViewController", path)
            c.fail(r, ASExtensionError(.failed)); return
        }
        let newPassword = strongPassword()
        var presented = false
        func end(_ f: @escaping () -> Void) {
            _ASModification.hosted = nil
            if presented, vc.presentingViewController != nil { vc.dismiss(animated: true, completion: f) } else { f() }
        }
        let ctx = vc._context
        ctx.onPassword = { cred, out in
            _ASPasswords.update(site: service.host, user: cred.user, password: cred.password)
            NSLog("isim AuthenticationServices: account modification: %@ on %@ now has a strong password (saved in Passwords)", cred.user, service.host)
            end { c.succeed(r, out) }
        }
        ctx.onAppleID = { out in
            _ASPasswords.remove(site: service.host, user: user)
            NSLog("isim AuthenticationServices: account modification: %@ on %@ now uses Sign in with Apple (password removed)", user, service.host)
            end { c.succeed(r, out) }
        }
        ctx.onCancel = { e in
            if !presented, let ae = e as? ASExtensionError, ae.code == .userInteractionRequired {
                NSLog("isim AuthenticationServices: the account modification extension needs the user: showing its UI")
                ctx.done = false; presented = true
                vc.loadViewIfNeeded()
                if strong != nil { vc.prepareInterfaceToChangePassword(for: service, existingCredential: existing, newPassword: newPassword, userInfo: info) }
                else { vc.prepareInterfaceToConvertAccountToSignInWithApple(for: service, existingCredential: existing, userInfo: info) }
                vc.modalPresentationStyle = .pageSheet
                c.anchor()?.present(vc, animated: true)
                return
            }
            NSLog("isim AuthenticationServices: account modification failed: %@", String(describing: e))
            end { c.fail(r, e) }
        }
        hosted = vc
        NSLog("isim AuthenticationServices: running the account modification extension %@ for %@ (%@)", base, user, strong != nil ? "strong password" : "Sign in with Apple")
        vc.loadViewIfNeeded()
        if strong != nil { vc.changePasswordWithoutUserInteraction(for: service, existingCredential: existing, newPassword: newPassword, userInfo: info) }
        else { vc.convertAccountToSignInWithAppleWithoutUserInteraction(for: service, existingCredential: existing, userInfo: info) }
    }
    @MainActor static var hosted: ASAccountAuthenticationModificationViewController?
}
