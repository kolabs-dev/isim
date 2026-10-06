// isim AdSupport: the advertising identifier (IDFA). Like iOS 14.5+, it is all zeros unless the user allowed
// tracking for this app (AppTrackingTransparency's choice, stored in the app's container); then it is the
// device's advertising identifier: a random UUID made once per device and kept in the device data
// ($ISIM_DATA/Library/isim/AdvertisingIdentifier, like the Simulator's per-device value). Erasing the device
// (`isim reset`) makes a new one. Nothing is sent anywhere.
import Foundation

open class ASIdentifierManager: NSObject {
    nonisolated(unsafe) static let _shared = ASIdentifierManager()
    open class func shared() -> ASIdentifierManager { _shared }

    /// AppTrackingTransparency's stored answer (ATTrackingManager.AuthorizationStatus.authorized == 3)
    static var trackingAuthorized: Bool {
        UserDefaults.standard.integer(forKey: "_ISIMTrackingAuthorizationStatus") == 3
    }

    /// all zeros unless tracking is authorized for this app
    open var advertisingIdentifier: UUID {
        guard ASIdentifierManager.trackingAuthorized else { return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) }
        return ASIdentifierManager.deviceIdentifier()
    }

    /// deprecated in iOS 14: true only when the user authorized tracking for this app
    @available(iOS, deprecated: 14.0)
    open var isAdvertisingTrackingEnabled: Bool { ASIdentifierManager.trackingAuthorized }

    static func deviceIdentifier() -> UUID {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        let dir = (data as NSString).appendingPathComponent("Library/isim")
        let path = (dir as NSString).appendingPathComponent("AdvertisingIdentifier")
        if let s = try? String(contentsOfFile: path, encoding: .utf8),
           let u = UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines)) { return u }
        let u = UUID()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        try? (u.uuidString + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        return u
    }
}
