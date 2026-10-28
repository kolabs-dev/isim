// The system sheets: Sign in with Apple, passkey creation, and the saved-credential chooser, drawn in SwiftUI
// like iOS 17/18 (bottom sheet, close button, app icon, bold question, blue Continue button). Each says it is a
// local simulation.
import Foundation
import UIKit
import SwiftUI

enum _ASChoice {
    case passkey(ASAuthorizationPlatformPublicKeyCredentialAssertionRequest, _ASPasskey)
    case password(ASAuthorizationPasswordRequest, _ASSavedPassword)
    case securityKey(ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest, _ASPasskey, appID: Bool)
    /// a passkey of an enabled credential provider extension
    case providerPasskey(ASAuthorizationPlatformPublicKeyCredentialAssertionRequest, [String: Any], ASPasskeyCredentialIdentity)
    var title: String {
        switch self {
        case .passkey(_, let k), .securityKey(_, let k, _): k.name
        case .password(_, let p): p.user
        case .providerPasskey(_, _, let i): i.userName
        }
    }
    var subtitle: String {
        switch self {
        case .providerPasskey(_, let s, _): "Passkey · \(s["name"] as? String ?? "Password manager")"
        case .passkey(let r, _): "Passkey for \(r.relyingPartyIdentifier)"
        case .securityKey(let r, _, _): "Security key · \(r.relyingPartyIdentifier)"
        case .password(_, let p): p.server.isEmpty ? "Saved password" : "Saved password · \(p.server)"
        }
    }
}

final class _ASSheetDelegate: NSObject, UISheetPresentationControllerDelegate {
    let controller: ASAuthorizationController
    init(_ c: ASAuthorizationController) { controller = c }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        NSLog("isim AuthenticationServices: sheet swiped away (canceled)")
        MainActor.assumeIsolated { controller.fail(.canceled) }
    }
}

@MainActor enum _ASSheets {
    static var delegates: [ObjectIdentifier: _ASSheetDelegate] = [:]

    static func present<V: View>(_ c: ASAuthorizationController, height: CGFloat, _ view: V) {
        guard let anchor = c.anchorController() else { NSLog("isim AuthenticationServices: no window to present the sheet"); c.fail(.failed); return }
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = .systemBackground
        host.modalPresentationStyle = .pageSheet
        if let s = host.sheetPresentationController {
            s.detents = [.custom(identifier: .init("isim-auth")) { _ in height }]
            s.prefersGrabberVisible = false
            s.preferredCornerRadius = 38
            let d = _ASSheetDelegate(c)
            delegates[ObjectIdentifier(c)] = d
            s.delegate = d
        }
        c.sheet = host
        anchor.present(host, animated: true, completion: nil)
    }
    /// dismisses the sheet, then reports (like iOS, the delegate hears back after the sheet is gone)
    static func finish(_ c: ASAuthorizationController, _ body: @escaping @MainActor () -> Void) {
        delegates[ObjectIdentifier(c)] = nil
        if let s = c.sheet { s.dismiss(animated: true) { MainActor.assumeIsolated { body() } } } else { body() }
    }

    // MARK: Sign in with Apple
    static func presentAppleID(_ c: ASAuthorizationController, _ r: ASAuthorizationAppleIDRequest) {
        let acct = _ASAppleID.account()
        guard acct.signedIn else {
            guard let anchor = c.anchorController() else { c.fail(.unknown); return }
            let a = UIAlertController(title: "Sign in to your \(_ASData.accountWord)", message: "Sign in with Apple needs an \(_ASData.accountWord) on this device (isim: AppleAccount/account.json, \"signedIn\").", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in c.fail(.unknown) })
            anchor.present(a, animated: true, completion: nil)
            return
        }
        let user = _ASAppleID.userID(acct)
        let e = _ASAppleID.entry()
        let returning = e?["state"] as? String == "authorized" && e?["user"] as? String == user
        let scopes = r.requestedScopes ?? []
        NSLog("isim AuthenticationServices: Sign in with Apple sheet (%@, scopes: %@)", returning ? "returning user" : "new account", scopes.map { $0.rawValue }.joined(separator: ","))
        let showForm = !returning && !scopes.isEmpty
        let h: CGFloat = showForm ? (scopes.contains(.email) && scopes.contains(.fullName) ? 640 : 560) : 420
        present(c, height: h, _ASAppleIDSheet(account: acct, returning: returning, askName: scopes.contains(.fullName), askEmail: scopes.contains(.email),
            onCancel: { finish(c) { c.fail(.canceled) } },
            onContinue: { shareName, hide in
                let cred = _ASAppleID.credential(for: r, shareName: shareName, hideEmail: hide, editedName: nil)
                finish(c) { c.complete(r.provider, cred) }
            }))
    }

    // MARK: Passkeys
    static func presentPasskeyRegistration(_ c: ASAuthorizationController, _ r: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) {
        NSLog("isim AuthenticationServices: passkey sheet: save a passkey for %@ on %@", r.name, r.relyingPartyIdentifier)
        present(c, height: 430, _ASPasskeySheet(name: r.name, rp: r.relyingPartyIdentifier,
            onCancel: { finish(c) { c.fail(.canceled) } },
            onContinue: {
                do { let cred = try _ASPasskeys.register(r); finish(c) { c.complete(r.provider, cred) } }
                catch { finish(c) { c.fail(.failed) } }
            }))
    }

    static func presentChooser(_ c: ASAuthorizationController, _ choices: [_ASChoice], appleID: ASAuthorizationAppleIDRequest?) {
        NSLog("isim AuthenticationServices: sign-in sheet with %d saved credential(s)", choices.count)
        let site: String = {
            if case .passkey(let r, _) = choices[0] { return r.relyingPartyIdentifier }
            if case .providerPasskey(let r, _, _) = choices[0] { return r.relyingPartyIdentifier }
            if case .securityKey(let r, _, _) = choices[0] { return r.relyingPartyIdentifier }
            return _ASData.appName
        }()
        present(c, height: min(700, 360 + CGFloat(choices.count) * 62), _ASChooserSheet(site: site, choices: choices,
            onCancel: { finish(c) { c.fail(.canceled) } },
            onPick: { i in
                switch choices[i] {
                case .passkey(let r, let k):
                    do { let cred = try _ASPasskeys.assert(r, k); finish(c) { c.complete(r.provider, cred) } }
                    catch { finish(c) { c.fail(.failed) } }
                case .password(let r, let p):
                    finish(c) { c.complete(r.provider, ASPasswordCredential(user: p.user, password: p.password)) }
                case .providerPasskey(let r, let store, let k):
                    NSLog("isim AuthenticationServices: passkey %@ from %@ for %@", k.userName, store["name"] as? String ?? "?", r.relyingPartyIdentifier)
                    finish(c) { _ASPasskeys.providerAssertion(c, r, store, k) {} }
                case .securityKey(let r, let k, let appID):
                    NSLog("isim AuthenticationServices: virtual security key used for %@ (%@)", k.name, r.relyingPartyIdentifier)
                    do { let cred = try _ASPasskeys.assert(r, k, appID: appID); finish(c) { c.complete(r.provider, cred) } }
                    catch { finish(c) { c.fail(.failed) } }
                }
            }))
    }

    // MARK: Security keys (the virtual USB key; iOS asks to insert or tap a real one)
    static func presentSecurityKeyRegistration(_ c: ASAuthorizationController, _ r: ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest) {
        NSLog("isim AuthenticationServices: security key sheet: set up a security key for %@ on %@", r.name, r.relyingPartyIdentifier)
        present(c, height: 430, _ASSecurityKeySheet(rp: r.relyingPartyIdentifier,
            onCancel: { finish(c) { c.fail(.canceled) } },
            onContinue: { let cred = _ASPasskeys.register(r); finish(c) { c.complete(r.provider, cred) } }))
    }

    // MARK: Conditional passkey registration (iOS 18): no sheet, a notification afterwards
    static func registerConditionally(_ c: ASAuthorizationController, _ r: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) {
        guard _ASPasswords.saved().contains(where: { $0.user == r.name }) else {
            NSLog("isim AuthenticationServices: conditional passkey registration for %@: no saved password for this account, no passkey created", r.name)
            c.fail(.failed); return
        }
        guard !_ASPasskeys.excluded(r) else { c.fail(.matchedExcludedCredential); return }
        do {
            let cred = try _ASPasskeys.register(r)
            NSLog("isim AuthenticationServices: conditional passkey registration for %@ (%@): created without a sheet", r.name, r.relyingPartyIdentifier)
            _ASBanner.show(title: "Passkey Saved", body: "A passkey for “\(r.name)” was saved to Passwords. You can use it to sign in to \(r.relyingPartyIdentifier).")
            c.complete(r.provider, cred)
        } catch { c.fail(.failed) }
    }
}

/// a Passwords notification banner like iOS's, at the top of the screen for a few seconds (accessibility identifier
/// "as-banner"); touches elsewhere go to the app
@MainActor enum _ASBanner {
    static var window: UIWindow?
    static func show(title: String, body: String) {
        window?.isHidden = true
        let w = _ASPassthroughWindow(frame: UIScreen.main.bounds)
        w.windowLevel = UIWindow.Level(rawValue: 2100)
        w.backgroundColor = .clear
        let width = min(UIScreen.main.bounds.width - 16, 390), height: CGFloat = 84
        let host = UIHostingController(rootView: _ASBannerView(title: title, message: body))
        host.view.backgroundColor = .clear
        let root = UIViewController(); root.view.backgroundColor = .clear
        root.addChild(host)
        let card = host.view!
        card.accessibilityIdentifier = "as-banner"
        card.accessibilityLabel = title
        w.content = card
        card.frame = CGRect(x: (UIScreen.main.bounds.width - width) / 2, y: -height - 10, width: width, height: height)
        root.view.addSubview(card)
        host.didMove(toParent: root)
        w.rootViewController = root
        window = w
        w.isHidden = false
        NSLog("isim AuthenticationServices: notification: %@ — %@", title, body)
        let top = max(w.safeAreaInsets.top, 20)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            card.frame.origin.y = top + 2
        }, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            MainActor.assumeIsolated {
                guard window === w else { return }
                UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseIn], animations: {
                    card.frame.origin.y = -height - 10
                }, completion: nil)
                // gone after the slide (not in the completion, so it holds with animations off)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    MainActor.assumeIsolated {
                        card.removeFromSuperview()
                        w.isHidden = true
                        if window === w { window = nil }
                    }
                }
            }
        }
    }
}

final class _ASPassthroughWindow: UIWindow {
    weak var content: UIView?
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let content, let v = super.hitTest(point, with: event), v.isDescendant(of: content) else { return nil }
        return v
    }
}

// MARK: - Views

struct _ASAppIcon: View {
    var body: some View {
        if let img = _ASAppIcon.image {
            Image(uiImage: img).resizable().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [Color(red: 0.35, green: 0.6, blue: 1), Color(red: 0.2, green: 0.35, blue: 0.9)], startPoint: .top, endPoint: .bottom))
                Text(verbatim: String(_ASData.appName.prefix(1)).uppercased()).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
            }.frame(width: 64, height: 64)
        }
    }
    /// the app icon, as isim-build lays it out (isim-assets.plist)
    static var image: UIImage? {
        let dir = Bundle.main.bundlePath as NSString
        guard let assets = NSDictionary(contentsOfFile: dir.appendingPathComponent("isim-assets.plist")) as? [String: Any],
              let icons = assets["appIcons"] as? [String: Any], let files = (icons["AppIcon"] ?? icons.values.first) as? [[String: Any]],
              let f = files.last?["file"] as? String else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(f))
    }
}

struct _ASCloseButton: View {
    let id: String, action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color(uiColor: .tertiarySystemFill)).frame(width: 30, height: 30)
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

struct _ASHeader: View {
    let title: String, closeID: String, onClose: () -> Void
    var body: some View {
        ZStack {
            HStack(spacing: 5) {
                _ASLogoShape().fill(Color.primary).frame(width: 14, height: 17).offset(y: -1)
                Text(verbatim: title).font(.system(size: 17, weight: .semibold))
            }
            HStack { Spacer(); _ASCloseButton(id: closeID, action: onClose) }
        }.padding(.horizontal, 16).padding(.top, 16).frame(height: 46)
    }
}

struct _ASContinueButton: View {
    let id: String, action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(verbatim: "Continue").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Color(uiColor: .systemBlue), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityIdentifier(id).padding(.horizontal, 24)
    }
}

struct _ASSimulationNote: View {
    var body: some View {
        Text(verbatim: "isim · local simulation, no Apple servers").font(.system(size: 11)).foregroundStyle(.secondary)
            .accessibilityIdentifier("as-simulation-note").padding(.top, 10).padding(.bottom, 26)
    }
}

struct _ASRadio: View {
    let on: Bool
    var body: some View {
        ZStack {
            Circle().stroke(on ? Color(uiColor: .systemBlue) : Color(uiColor: .systemGray3), lineWidth: 1.5).frame(width: 22, height: 22)
            if on {
                Circle().fill(Color(uiColor: .systemBlue)).frame(width: 22, height: 22)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            }
        }
    }
}

struct _ASAppleIDSheet: View {
    let account: _ASAppleID.Account, returning: Bool, askName: Bool, askEmail: Bool
    let onCancel: () -> Void
    let onContinue: (Bool, Bool) -> Void
    @State var hideEmail = false

    var body: some View {
        VStack(spacing: 0) {
            _ASHeader(title: "Sign in with Apple", closeID: "siwa-cancel", onClose: onCancel)
            _ASAppIcon().padding(.top, 14)
            Text(verbatim: headline).font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
                .accessibilityIdentifier("siwa-title").padding(.horizontal, 28).padding(.top, 14)
            if !returning && (askName || askEmail) {
                VStack(spacing: 0) {
                    if askName { row(label: "NAME", id: "siwa-name") { Text(verbatim: "\(account.first) \(account.last)").font(.system(size: 17)) } }
                    if askEmail {
                        Text(verbatim: "EMAIL").font(.system(size: 13)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, askName ? 16 : 0).padding(.bottom, 6)
                        VStack(spacing: 0) {
                            emailChoice(title: "Share My Email", detail: account.email, on: !hideEmail, id: "siwa-share-email") { hideEmail = false }
                            Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5).padding(.leading, 52)
                            emailChoice(title: "Hide My Email", detail: "Forward To: \(account.email)", on: hideEmail, id: "siwa-hide-email") { hideEmail = true }
                        }
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                }.padding(.top, 20)
            } else {
                Text(verbatim: "\(account.first) \(account.last) · \(account.email)").font(.system(size: 15)).foregroundStyle(.secondary)
                    .padding(.top, 10).accessibilityIdentifier("siwa-account")
            }
            Spacer(minLength: 16)
            _ASContinueButton(id: "siwa-continue") { onContinue(askName, askEmail && hideEmail) }
            _ASSimulationNote()
        }
    }
    var headline: String {
        returning ? "Sign in to \(_ASData.appName) with your \(_ASData.accountWord) “\(account.email)”?"
                  : "Create an account for \(_ASData.appName) using your \(_ASData.accountWord) “\(account.email)”."
    }
    func row<C: View>(label: String, id: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 6) {
            Text(verbatim: label).font(.system(size: 13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
            HStack { content(); Spacer() }
                .padding(.horizontal, 16).frame(height: 46)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).accessibilityIdentifier(id)
        }
    }
    func emailChoice(title: String, detail: String, on: Bool, id: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                _ASRadio(on: on)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).font(.system(size: 17)).foregroundStyle(.primary)
                    Text(verbatim: detail).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }.padding(.horizontal, 16).frame(height: 58).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

struct _ASPasskeyGlyph: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: .systemBlue).opacity(0.12)).frame(width: 72, height: 72)
            Image(systemName: "person").font(.system(size: 30, weight: .medium)).foregroundStyle(Color(uiColor: .systemBlue))
        }
    }
}

struct _ASPasskeySheet: View {
    let name: String, rp: String
    let onCancel: () -> Void, onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); _ASCloseButton(id: "passkey-cancel", action: onCancel) }.padding(.horizontal, 16).padding(.top, 16)
            _ASPasskeyGlyph()
            Text(verbatim: "Save a passkey for “\(name)”?").font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
                .accessibilityIdentifier("passkey-title").padding(.horizontal, 28).padding(.top, 14)
            Text(verbatim: "Passkeys let you sign in to \(rp) without a password. This one is saved on this simulated device only (not synced to iCloud Keychain).")
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 8)
            Spacer(minLength: 16)
            _ASContinueButton(id: "passkey-continue", action: onContinue)
            _ASSimulationNote()
        }
    }
}

struct _ASBannerView: View {
    let title: String, message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Color(uiColor: .systemBlue)).frame(width: 38, height: 38)
                Image(systemName: "key.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(verbatim: title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                    Spacer()
                    Text(verbatim: "now").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Text(verbatim: message).font(.system(size: 15)).foregroundStyle(.primary).lineLimit(2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
    }
}

struct _ASSecurityKeySheet: View {
    let rp: String
    let onCancel: () -> Void, onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); _ASCloseButton(id: "securitykey-cancel", action: onCancel) }.padding(.horizontal, 16).padding(.top, 16)
            ZStack {
                Circle().fill(Color(uiColor: .systemBlue).opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: "key.fill").font(.system(size: 28, weight: .medium)).foregroundStyle(Color(uiColor: .systemBlue))
            }
            Text(verbatim: "Set Up a Security Key").font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
                .accessibilityIdentifier("securitykey-title").padding(.horizontal, 28).padding(.top, 14)
            Text(verbatim: "Insert your security key to save a passkey for \(rp) on it. isim uses a virtual USB security key kept on this simulated device.")
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 8)
            Spacer(minLength: 16)
            _ASContinueButton(id: "securitykey-continue", action: onContinue)
            _ASSimulationNote()
        }
    }
}

struct _ASChooserSheet: View {
    let site: String, choices: [_ASChoice]
    let onCancel: () -> Void, onPick: (Int) -> Void
    @State var selected = 0
    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); _ASCloseButton(id: "signin-cancel", action: onCancel) }.padding(.horizontal, 16).padding(.top, 16)
            _ASPasskeyGlyph()
            Text(verbatim: "Sign in to “\(site)”?").font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
                .accessibilityIdentifier("signin-title").padding(.horizontal, 28).padding(.top, 14)
            VStack(spacing: 0) {
                ForEach(0..<choices.count, id: \.self) { i in
                    Button { selected = i } label: {
                        HStack(spacing: 14) {
                            _ASRadio(on: selected == i)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: choices[i].title).font(.system(size: 17)).foregroundStyle(.primary).lineLimit(1)
                                Text(verbatim: choices[i].subtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }.padding(.horizontal, 16).frame(height: 60).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("signin-choice-\(i)")
                    if i < choices.count - 1 { Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5).padding(.leading, 52) }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16).padding(.top, 20)
            Spacer(minLength: 16)
            _ASContinueButton(id: "signin-continue") { onPick(selected) }
            _ASSimulationNote()
        }
    }
}
