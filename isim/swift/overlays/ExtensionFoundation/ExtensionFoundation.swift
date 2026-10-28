// isim ExtensionFoundation (partial): the AppExtension and AppExtensionConfiguration protocols that the frameworks'
// extension protocols refine (BackgroundAssets' BADownloaderExtension, issue #407). An extension's @main type runs
// through the main() of its framework's protocol (that framework's extension host); a bare AppExtension has no host on
// isim. App extension points of your own (AppExtensionPoint, the host side's AppExtensionProcess) are not in isim yet.
import Foundation

@MainActor @preconcurrency public protocol AppExtensionConfiguration: Sendable {
    nonisolated func accept(connection: NSXPCConnection) -> Bool
}

@MainActor @preconcurrency public protocol AppExtension {
    associatedtype Configuration: AppExtensionConfiguration
    var configuration: Self.Configuration { get }
    init()
}

extension AppExtension {
    /// the extension's entry point (@main): the extension point's framework runs it
    public static func main() throws {
        NSLog("isim ExtensionFoundation: %@ is an app extension without an extension point isim hosts", String(describing: Self.self))
        exit(1)
    }
}
