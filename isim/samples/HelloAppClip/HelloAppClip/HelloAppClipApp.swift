// HelloAppClip: the full app. It handles the App Clip's invocation URLs too (iOS opens it instead of the App Clip once
// it is installed) and finds the order the App Clip saved in their shared app group.
import SwiftUI

@main
struct HelloAppClipApp: App {
    @State private var invocation = "Opened from the Home Screen"
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Text("Hello App Clip").font(.largeTitle.bold())
                Text("The full app").foregroundStyle(.secondary)
                Text(invocation).accessibilityIdentifier("full-invocation")
                Text("Order from the App Clip: \(Order.last ?? "none")").accessibilityIdentifier("full-order")
            }
            .padding()
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                let url = activity.webpageURL?.absoluteString ?? "none"
                invocation = "Full app invoked with \(url)"
                NSLog("HelloAppClip: full app invoked with %@, order from the App Clip: %@", url, Order.last ?? "none")
            }
        }
    }
}
