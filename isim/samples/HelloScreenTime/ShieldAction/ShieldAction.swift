// The sample's Shield Action extension: Close closes the shield; One More Minute keeps it (defer).
import Foundation
import ManagedSettings

final class FocusShieldActions: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("sta \(action == .primaryButtonPressed ? "primary" : "secondary") for \(Application(token: application).bundleIdentifier ?? "-")"); fflush(stdout)
        completionHandler(action == .primaryButtonPressed ? .close : .defer)
    }
}
