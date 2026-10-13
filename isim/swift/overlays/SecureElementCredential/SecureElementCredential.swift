// isim SecureElementCredential: the scene event of a credential session (iOS 17.4, the EEA's NFC & SE platform).
// isim has no secure element and no NFC reader field: the event reaches an app only through the launch marker
// isim-credential:presentation|readerDetected (ISIM_LAUNCH_URL), in its launch scene's connection options (adapted).
import Foundation
import UIKit

/// what made the system create the app's scene for a credential session
public enum CredentialSessionWindowSceneEvent: Sendable, Hashable {
    /// the person did the gesture that presents the credential
    case presentation
    /// the device detected an NFC reader's RF field
    case readerDetected
}
extension UIScene.ConnectionOptions {
    @available(iOS 17.4, *)
    @MainActor public var credentialSessionEvent: CredentialSessionWindowSceneEvent? {
        switch value(forKey: "_isim_launchMarker") as? String {
        case "isim-credential:presentation": return .presentation
        case "isim-credential:readerDetected": return .readerDetected
        default: return nil
        }
    }
}
