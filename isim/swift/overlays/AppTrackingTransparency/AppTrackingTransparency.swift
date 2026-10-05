// isim AppTrackingTransparency: the tracking permission prompt, like iOS. The choice is stored in the
// app's container (so it persists until the app is deleted) and nothing is tracked by isim either way.
import UIKit

open class ATTrackingManager: NSObject {
    public enum AuthorizationStatus: UInt, Sendable { case notDetermined = 0, restricted = 1, denied = 2, authorized = 3 }
    static let key = "_ISIMTrackingAuthorizationStatus"
    public class var trackingAuthorizationStatus: AuthorizationStatus {
        AuthorizationStatus(rawValue: UInt(UserDefaults.standard.integer(forKey: key))) ?? .notDetermined
    }
    public class func requestTrackingAuthorization(completionHandler: @escaping (AuthorizationStatus) -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { _prompt(completionHandler) }
        }
    }
    public class func requestTrackingAuthorization() async -> AuthorizationStatus {
        await withCheckedContinuation { k in requestTrackingAuthorization { k.resume(returning: $0) } }
    }
    @MainActor static func _prompt(_ done: @escaping (AuthorizationStatus) -> Void) {
        let current = trackingAuthorizationStatus
        guard current == .notDetermined else { done(current); return }
        guard let purpose = Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") as? String else {
            // iOS terminates the app here; isim logs it and reports denied
            NSLog("isim: requestTrackingAuthorization without NSUserTrackingUsageDescription in Info.plist (iOS would terminate the app)")
            done(.denied); return
        }
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "this app"
        var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = top?.presentedViewController { top = p }
        guard let vc = top else { done(.notDetermined); return }
        let alert = UIAlertController(title: "Allow “\(name)” to track your activity across other companies’ apps and websites?", message: purpose, preferredStyle: .alert)
        func answer(_ s: AuthorizationStatus) { UserDefaults.standard.set(Int(s.rawValue), forKey: key); done(s) }
        alert.addAction(UIAlertAction(title: "Ask App Not to Track", style: .default) { _ in answer(.denied) })
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in answer(.authorized) })
        vc.present(alert, animated: true, completion: nil)
    }
}
