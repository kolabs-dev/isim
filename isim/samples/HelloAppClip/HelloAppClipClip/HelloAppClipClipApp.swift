// HelloAppClipClip: the App Clip. It is launched for an invocation URL (an App Clip Code, a QR code, an NFC tag, a link)
// with an NSUserActivity of type NSUserActivityTypeBrowsingWeb, reads its activation payload, confirms the location of
// the code (APActivationPayload.confirmAcquired), sends an ephemeral notification and recommends the full app with
// SKOverlay.AppClipConfiguration.
import SwiftUI
import AppClip
import CoreLocation
import StoreKit
import UserNotifications

@main
struct HelloAppClipClipApp: App {
    @StateObject private var model = ClipModel()
    var body: some Scene {
        WindowGroup {
            ClipView(model: model)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { model.invoked($0) }
        }
    }
}

@MainActor final class ClipModel: ObservableObject {
    @Published var url = "No invocation URL"
    @Published var item = "–"
    @Published var location = "Location not checked"
    @Published var notifications = "Notifications not checked"
    @Published var overlay = false
    let launches: Int
    private var payload: APActivationPayload?

    init() {
        launches = UserDefaults.standard.integer(forKey: "launches") + 1        // the App Clip's own data
        UserDefaults.standard.set(launches, forKey: "launches")
        NSLog("HelloAppClipClip: launch %d", launches)
    }
    func invoked(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb else { return }
        url = activity.webpageURL?.absoluteString ?? "none"
        payload = activity.appClipActivationPayload
        item = Order.item(in: activity.webpageURL) ?? "–"
        if item != "–" { Order.save(item) }
        NSLog("HelloAppClipClip: invoked with %@ (payload %@)", url, payload?.url?.absoluteString ?? "none")
    }
    func confirmLocation() {
        guard let payload else { location = "No activation payload"; return }
        // the shop: Apple Park (isim's default simulated location)
        let shop = CLCircularRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902), radius: 100, identifier: "Shop")
        payload.confirmAcquired(in: shop) { inRegion, error in
            Task { @MainActor in
                if let e = error as? APActivationPayloadError {
                    self.location = e.code == .doesNotMatch ? "Location: URL not registered" : "Location: not allowed"
                } else {
                    self.location = inRegion ? "Location: at the shop" : "Location: not at the shop"
                }
                NSLog("HelloAppClipClip: %@", self.location)
            }
        }
    }
    func notify() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            let name = status == .ephemeral ? "ephemeral" : status == .authorized ? "authorized" : status == .denied ? "denied" : status == .notDetermined ? "notDetermined" : "provisional"
            Task { @MainActor in
                self.notifications = "Notifications: \(name)"
                NSLog("HelloAppClipClip: notification authorization %@", name)
                guard status == .ephemeral || status == .authorized else { return }
                let content = UNMutableNotificationContent()
                content.title = "Order ready"
                content.body = "Your \(self.item) is ready."
                let request = UNNotificationRequest(identifier: "order-ready", content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
                do { try await UNUserNotificationCenter.current().add(request); NSLog("HelloAppClipClip: notification scheduled (ok)") }
                catch { NSLog("HelloAppClipClip: notification scheduled (%@)", "\(error)") }
            }
        }
    }
}

struct ClipView: View {
    @ObservedObject var model: ClipModel
    var body: some View {
        VStack(spacing: 14) {
            Text("Smoothie Bar").font(.largeTitle.bold())
            Text("An App Clip").foregroundStyle(.secondary)
            Text(model.url).font(.footnote).accessibilityIdentifier("clip-url")
            Text("Order: \(model.item)").accessibilityIdentifier("clip-item")
            Text("Launch \(model.launches)").accessibilityIdentifier("clip-launches")
            Button("Confirm location") { model.confirmLocation() }.accessibilityIdentifier("clip-confirm")
            Text(model.location).accessibilityIdentifier("clip-location")
            Button("Notify me") { model.notify() }.accessibilityIdentifier("clip-notify")
            Text(model.notifications).accessibilityIdentifier("clip-notifications")
            Button("Get the full app") { model.overlay = true }.accessibilityIdentifier("clip-overlay")
        }
        .padding()
        .appStoreOverlay(isPresented: $model.overlay) { SKOverlay.AppClipConfiguration(position: .bottom) }
    }
}
