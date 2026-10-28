// HelloVault's credential provider extension: passwords ("locked" ones need the user to unlock the vault), a one-time
// code, and passkeys it creates and signs with keys kept in the app group's defaults.
import UIKit
import AuthenticationServices
import CryptoKit

let vault = UserDefaults(suiteName: "group.dev.isim.samples.HelloVault")!
func plog(_ s: String) { print("vault provider: \(s)"); fflush(stdout) }

final class CredentialProviderViewController: ASCredentialProviderViewController {
    var pending: ASCredentialRequest?

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        switch credentialRequest {
        case let r as ASPasswordCredentialRequest:
            let id = r.credentialIdentity as! ASPasswordCredentialIdentity
            if id.recordIdentifier == "locked" {
                plog("\(id.user) is locked: needs the user")
                extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
                return
            }
            plog("password for \(id.user) without UI")
            extensionContext.completeRequest(withSelectedCredential: ASPasswordCredential(user: id.user, password: "vault-\(id.user)-pw"))
        case is ASOneTimeCodeCredentialRequest:
            plog("one-time code without UI")
            extensionContext.completeOneTimeCodeRequest(using: ASOneTimeCodeCredential(code: "424242"))
        case let r as ASPasskeyCredentialRequest where r.type == .passkeyAssertion:
            let id = r.credentialIdentity as! ASPasskeyCredentialIdentity
            guard let raw = vault.object(forKey: "key-" + id.credentialID.base64EncodedString()) as? Data, let key = try? P256.Signing.PrivateKey(rawRepresentation: raw) else {
                extensionContext.cancelRequest(withError: ASExtensionError(.credentialIdentityNotFound)); return
            }
            var auth = Data(SHA256.hash(data: Data(id.relyingPartyIdentifier.utf8)))
            auth.append(contentsOf: [0x05, 0, 0, 0, 0])                          // user present + verified, sign count 0
            let signature = try! key.signature(for: auth + r.clientDataHash).derRepresentation
            plog("passkey assertion for \(id.userName) without UI")
            extensionContext.completeAssertionRequest(using: ASPasskeyAssertionCredential(userHandle: id.userHandle, relyingParty: id.relyingPartyIdentifier,
                                                                                          signature: signature, clientDataHash: r.clientDataHash,
                                                                                          authenticatorData: auth, credentialID: id.credentialID))
        default:
            extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        pending = credentialRequest
        plog("unlock UI for \(credentialRequest.credentialIdentity.user)")
        show("Unlock Vault", "Unlock", id: "vault-unlock") { [weak self] in
            guard let self, let r = self.pending else { return }
            self.extensionContext.completeRequest(withSelectedCredential: ASPasswordCredential(user: r.credentialIdentity.user, password: "unlocked-\(r.credentialIdentity.user)-pw"))
        }
    }

    override func prepareInterface(forPasskeyRegistration registrationRequest: ASCredentialRequest) {
        guard let r = registrationRequest as? ASPasskeyCredentialRequest, let id = r.credentialIdentity as? ASPasskeyCredentialIdentity else { return }
        plog("save passkey UI for \(id.userName) on \(id.relyingPartyIdentifier)")
        show("Save a passkey for “\(id.userName)” in Vault?", "Save Passkey", id: "vault-save-passkey") { [weak self] in
            self?.register(r, id)
        }
    }

    func register(_ r: ASPasskeyCredentialRequest, _ id: ASPasskeyCredentialIdentity) {
        let key = P256.Signing.PrivateKey()
        let credentialID = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        vault.set(key.rawRepresentation, forKey: "key-" + credentialID.base64EncodedString())
        vault.set(key.publicKey.rawRepresentation, forKey: "pub-" + credentialID.base64EncodedString())
        // authenticator data with the attested credential (AAGUID zero, COSE ES256 key), in a "none" attestation
        let pub = key.publicKey.rawRepresentation                                // x || y
        var cose = Data([0xa5, 0x01, 0x02, 0x03, 0x26, 0x20, 0x01, 0x21, 0x58, 0x20]); cose += pub.prefix(32)
        cose += Data([0x22, 0x58, 0x20]); cose += pub.suffix(32)
        var auth = Data(SHA256.hash(data: Data(id.relyingPartyIdentifier.utf8)))
        auth.append(contentsOf: [0x45, 0, 0, 0, 0]); auth += Data(count: 16)
        auth.append(contentsOf: [0, UInt8(credentialID.count)]); auth += credentialID; auth += cose
        var att = Data([0xa3, 0x63]) + Data("fmt".utf8) + Data([0x64]) + Data("none".utf8)
        att += Data([0x67]) + Data("attStmt".utf8) + Data([0xa0])
        att += Data([0x68]) + Data("authData".utf8) + Data([0x58, UInt8(auth.count)]) + auth
        let identity = ASPasskeyCredentialIdentity(relyingPartyIdentifier: id.relyingPartyIdentifier, userName: id.userName, credentialID: credentialID,
                                                   userHandle: id.userHandle, recordIdentifier: "passkey-\(id.userName)")
        ASCredentialIdentityStore.shared.saveCredentialIdentities([identity]) { ok, _ in plog("passkey identity saved: \(ok)") }
        plog("passkey created for \(id.userName)")
        extensionContext.completeRegistrationRequest(using: ASPasskeyRegistrationCredential(relyingParty: id.relyingPartyIdentifier, clientDataHash: r.clientDataHash,
                                                                                            credentialID: credentialID, attestationObject: att))
    }

    func show(_ title: String, _ button: String, id: String, _ action: @escaping () -> Void) {
        view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 80, width: view.bounds.width - 40, height: 60))
        label.text = title; label.numberOfLines = 0; label.textAlignment = .center; label.font = .boldSystemFont(ofSize: 20)
        view.addSubview(label)
        let b = UIButton(type: .system)
        b.setTitle(button, for: .normal)
        b.frame = CGRect(x: 40, y: 170, width: view.bounds.width - 80, height: 44)
        b.accessibilityIdentifier = id
        b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        view.addSubview(b)
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.frame = CGRect(x: 40, y: 230, width: view.bounds.width - 80, height: 44)
        cancel.accessibilityIdentifier = "vault-cancel"
        cancel.addAction(UIAction { [weak self] _ in self?.extensionContext.cancelRequest(withError: ASExtensionError(.userCanceled)) }, for: .primaryActionTriggered)
        view.addSubview(cancel)
    }
}
