// isim MarketplaceKit: the deep links the system makes into an alternative app marketplace (iOS 17.4, EU).
// isim is no marketplace and installs no apps through one: a display option reaches a marketplace app only through
// the launch marker isim-marketplace:product:ITEM[:VERSION] | search:QUERY | auth:ACCOUNT (ISIM_LAUNCH_URL), in its
// launch scene's connection options (adapted).
import Foundation
import UIKit

public typealias AppleItemID = UInt64
public typealias AppleVersionID = UInt64

/// a deep link the operating system makes into the marketplace
public enum MarketplaceDisplayOption: Sendable, Hashable {
    case authentication(account: String)
    case productPage(appleItemID: AppleItemID, appleVersionID: AppleVersionID?)
    case searchResults(query: String)

    static func _isimParse(_ marker: String?) -> MarketplaceDisplayOption? {
        guard let m = marker, m.hasPrefix("isim-marketplace:") else { return nil }
        let rest = m.dropFirst(17)
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let kind = rest[..<colon], value = String(rest[rest.index(after: colon)...]).removingPercentEncoding ?? ""
        switch kind {
        case "auth": return .authentication(account: value)
        case "search": return .searchResults(query: value)
        case "product":
            let parts = value.split(separator: ":")
            guard let item = parts.first.flatMap({ AppleItemID($0) }) else { return nil }
            return .productPage(appleItemID: item, appleVersionID: parts.count > 1 ? AppleVersionID(parts[1]) : nil)
        default: return nil
        }
    }
}
extension UIScene.ConnectionOptions {
    @available(iOS 17.4, *)
    @MainActor public var marketplaceDisplayOption: MarketplaceDisplayOption? {
        MarketplaceDisplayOption._isimParse(value(forKey: "_isim_launchMarker") as? String)
    }
}
