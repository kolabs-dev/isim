// HelloVault's account modification extension: changes an account's password to the strong one iOS suggests, or
// moves the account to Sign in with Apple (with the user's Sign in with Apple authorization).
import UIKit
import AuthenticationServices

func ulog(_ s: String) { print("vault upgrade: \(s)"); fflush(stdout) }

final class AccountModificationViewController: ASAccountAuthenticationModificationViewController {
    override func changePasswordWithoutUserInteraction(for serviceIdentifier: ASCredentialServiceIdentifier, existingCredential: ASPasswordCredential,
                                                       newPassword: String, userInfo: [AnyHashable: Any]?) {
        ulog("change \(existingCredential.user) on \(serviceIdentifier.identifier) from \(existingCredential.password) (strong: \(newPassword.count) chars)")
        extensionContext.completeChangePasswordRequest(updatedCredential: ASPasswordCredential(user: existingCredential.user, password: newPassword),
                                                       userInfo: ["changed": true])
    }
    override func convertAccountToSignInWithAppleWithoutUserInteraction(for serviceIdentifier: ASCredentialServiceIdentifier, existingCredential: ASPasswordCredential,
                                                                        userInfo: [AnyHashable: Any]?) {
        ulog("convert \(existingCredential.user) to Sign in with Apple")
        extensionContext.getSignInWithAppleUpgradeAuthorization(state: "up-1", nonce: "n-1") { credential, error in
            guard let credential else { ulog("no authorization: \(String(describing: error))"); self.extensionContext.cancelRequest(withError: ASExtensionError(.userCanceled)); return }
            ulog("authorized state=\(credential.state ?? "-") email=\(credential.email ?? "-")")
            self.extensionContext.completeUpgradeToSignInWithApple(userInfo: ["user": credential.user])
        }
    }
}
