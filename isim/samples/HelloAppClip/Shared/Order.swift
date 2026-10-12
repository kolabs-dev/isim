// Shared by the full app and its App Clip: the order the App Clip took, kept in the app group both belong to, so the
// full app finds it once it replaces the App Clip (iOS: data migrates through a shared app group container).
import Foundation

enum Order {
    static let group = "group.dev.isim.samples.HelloAppClip"
    static let domain = "clip.hello.isim.dev"
    static var shared: UserDefaults? { UserDefaults(suiteName: group) }

    /// the item an invocation URL names: https://clip.hello.isim.dev/order/<item>
    static func item(in url: URL?) -> String? {
        guard let url, url.host == domain else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        return parts.count >= 2 && parts[0] == "order" ? parts[1] : nil
    }
    static func save(_ item: String) {
        shared?.set(item, forKey: "lastOrder")
        NSLog("HelloAppClip: saved order %@ in %@", item, group)
    }
    static var last: String? { shared?.string(forKey: "lastOrder") }
}
