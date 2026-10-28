// Passkey account creation (iOS 26, adapted): an app asks to create an account with a passkey; iOS's "Create Account"
// sheet offers the user's email address (or phone number) and name from their Apple Account, then saves a passkey
// for the relying party. isim's sheet uses the simulated Apple Account (Library/isim/AppleAccount/account.json) and
// saves the passkey like any other (Passkeys.swift); ASAuthorizationController returns an
// ASAuthorizationAccountCreationPlatformPublicKeyCredential (ASAuthorizationResult.passkeyAccountCreation). The
// credential and contact types carry no iOS 26 availability: ASAuthorizationResult's case needs them on every version.
import Foundation
import UIKit
import SwiftUI

public struct ASEmailIdentifier: Hashable, Sendable {
    public var value: String
    init(_ value: String) { self.value = value }
}
public struct ASPhoneNumberIdentifier: Hashable, Sendable {
    public var value: String
    init(_ value: String) { self.value = value }
}
public enum ASContactIdentifier: Hashable, Sendable {
    case email(ASEmailIdentifier)
    case phoneNumber(ASPhoneNumberIdentifier)
}
@available(iOS 26.0, *)
public enum ASContactIdentifierRequest: Hashable, Sendable {
    case email
    case phoneNumber
}

@available(iOS 26.0, *)
@objc(ASAuthorizationAccountCreationProvider) open class ASAuthorizationAccountCreationProvider: NSObject, ASAuthorizationProvider {
    public override init() { super.init() }
    open func createPlatformPublicKeyCredentialRegistrationRequest(acceptedContactIdentifiers: [ASContactIdentifierRequest], shouldRequestName: Bool,
                                                                   relyingPartyIdentifier: String, challenge: Data, userID: Data)
        -> ASAuthorizationAccountCreationPlatformPublicKeyCredentialRequest {
        ASAuthorizationAccountCreationPlatformPublicKeyCredentialRequest(self, contacts: acceptedContactIdentifiers, name: shouldRequestName,
                                                                         rp: relyingPartyIdentifier, challenge: challenge, userID: userID)
    }
}

/// (not annotated: ASAuthorizationController checks for it on every iOS version)
@objc(ASAuthorizationAccountCreationPlatformPublicKeyCredentialRequest) open class ASAuthorizationAccountCreationPlatformPublicKeyCredentialRequest: ASAuthorizationRequest, NSSecureCoding {
    let _contacts: [Int]
    public let shouldRequestName: Bool
    public let relyingPartyIdentifier: String
    public let challenge: Data
    public let userID: Data
    @available(iOS 26.0, *)
    public var acceptedContactIdentifiers: [ASContactIdentifierRequest] { _contacts.map { $0 == 1 ? .phoneNumber : .email } }
    @available(iOS 26.0, *)
    init(_ provider: ASAuthorizationAccountCreationProvider, contacts: [ASContactIdentifierRequest], name: Bool, rp: String, challenge: Data, userID: Data) {
        _contacts = contacts.map { $0 == .phoneNumber ? 1 : 0 }; shouldRequestName = name; relyingPartyIdentifier = rp; self.challenge = challenge; self.userID = userID
        super.init(provider: provider)
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(_contacts, forKey: "contacts"); coder.encode(shouldRequestName, forKey: "name"); coder.encode(relyingPartyIdentifier, forKey: "rp")
        coder.encode(challenge, forKey: "challenge"); coder.encode(userID, forKey: "userID")
    }
    public required init?(coder: NSCoder) { nil }
}

@objc(ASAuthorizationAccountCreationPlatformPublicKeyCredential) open class ASAuthorizationAccountCreationPlatformPublicKeyCredential: NSObject, ASAuthorizationCredential, @unchecked Sendable {
    public let contactIdentifier: ASContactIdentifier
    public let name: PersonNameComponents?
    public let credentialRegistration: ASAuthorizationPlatformPublicKeyCredentialRegistration
    init(contact: ASContactIdentifier, name: PersonNameComponents?, registration: ASAuthorizationPlatformPublicKeyCredentialRegistration) {
        contactIdentifier = contact; self.name = name; credentialRegistration = registration
    }
}

enum _ASAccountCreation {
    @MainActor static func present(_ c: ASAuthorizationController, _ r: ASAuthorizationAccountCreationPlatformPublicKeyCredentialRequest) {
        guard #available(iOS 26.0, *) else { c.fail(.unknown); return }
        let acct = _ASAppleID.account()
        guard acct.signedIn else { c.fail(.deviceNotConfiguredForPasskeyCreation); return }
        let phone = ProcessInfo.processInfo.environment["ISIM_PHONE_NUMBER"] ?? "+1 (408) 555-0123"
        let usePhone = r._contacts.first == 1
        let contact = usePhone ? phone : acct.email
        NSLog("isim AuthenticationServices: create account sheet for %@ (%@)", r.relyingPartyIdentifier, contact)
        _ASSheets.present(c, height: r.shouldRequestName ? 520 : 470, _ASAccountCreationSheet(rp: r.relyingPartyIdentifier, contact: contact, phone: usePhone,
            name: r.shouldRequestName ? "\(acct.first) \(acct.last)" : nil,
            onCancel: { _ASSheets.finish(c) { c.fail(.canceled) } },
            onContinue: {
                let (k, att, cd) = _ASPasskeys.create(r.relyingPartyIdentifier, userID: r.userID, name: contact, challenge: r.challenge)
                let reg = ASAuthorizationPlatformPublicKeyCredentialRegistration(attestation: att, clientData: cd, id: k.credentialID)
                var n: PersonNameComponents?
                if r.shouldRequestName { var p = PersonNameComponents(); p.givenName = acct.first; p.familyName = acct.last; n = p }
                let cred = ASAuthorizationAccountCreationPlatformPublicKeyCredential(
                    contact: usePhone ? .phoneNumber(ASPhoneNumberIdentifier(phone)) : .email(ASEmailIdentifier(acct.email)), name: n, registration: reg)
                NSLog("isim AuthenticationServices: account created on %@ with a passkey for %@", r.relyingPartyIdentifier, contact)
                _ASSheets.finish(c) { c.complete(r.provider, cred) }
            }))
    }
}

struct _ASAccountCreationSheet: View {
    let rp: String, contact: String, phone: Bool, name: String?
    let onCancel: () -> Void, onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); _ASCloseButton(id: "create-cancel", action: onCancel) }.padding(.horizontal, 16).padding(.top, 16)
            _ASPasskeyGlyph()
            Text(verbatim: "Create an account for “\(rp)”?").font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
                .accessibilityIdentifier("create-title").padding(.horizontal, 28).padding(.top, 14)
            Text(verbatim: "A passkey will be saved for this account. You can sign in with it instead of a password.")
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 8)
            VStack(spacing: 0) {
                row(phone ? "Phone" : "Email", contact, id: "create-contact")
                if let name { Divider().padding(.leading, 16); row("Name", name, id: "create-name") }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24).padding(.top, 18)
            Spacer(minLength: 16)
            _ASContinueButton(id: "create-continue", action: onContinue)
            _ASSimulationNote()
        }
    }
    func row(_ label: String, _ value: String, id: String) -> some View {
        HStack {
            Text(verbatim: label).foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value).accessibilityIdentifier(id)
        }
        .font(.system(size: 17)).padding(.horizontal, 16).padding(.vertical, 12)
    }
}
