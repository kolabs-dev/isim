// HelloWidgets app: the counter its widget shows (app group defaults + WidgetCenter.reloadTimelines), and a
// delivery Live Activity (ActivityKit request / update / end).
import SwiftUI
import WidgetKit
import ActivityKit

func log(_ s: String) { NSLog("HelloWidgets: %@", s) }

@main
struct HelloWidgetsApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State var count = sharedCount
    @State var activity: Activity<DeliveryAttributes>?
    var body: some View {
        NavigationStack {
            List {
                Text("Count \(count)").accessibilityIdentifier("count")
                Button("Increment") {
                    sharedCount += 1; count = sharedCount
                    WidgetCenter.shared.reloadTimelines(ofKind: "Counter")
                    log("incremented to \(count)")
                }.accessibilityIdentifier("increment")
                Button("Start delivery") {
                    do {
                        activity = try Activity.request(attributes: DeliveryAttributes(orderNumber: "42"),
                                                        content: .init(state: .init(minutes: 12, status: "Preparing"), staleDate: nil))
                        log("started activity, enabled \(ActivityAuthorizationInfo().areActivitiesEnabled), \(Activity<DeliveryAttributes>.activities.count) active")
                    } catch { log("request failed \(error)") }
                }.accessibilityIdentifier("startDelivery")
                Button("Update delivery") {
                    Task { await activity?.update(.init(state: .init(minutes: 3, status: "Almost there"), staleDate: nil)); log("updated activity") }
                }.accessibilityIdentifier("updateDelivery")
                Button("End delivery") {
                    Task { await activity?.end(nil, dismissalPolicy: .immediate); log("ended activity") }
                }.accessibilityIdentifier("endDelivery")
            }
            .navigationTitle("Widgets")
            .onAppear { count = sharedCount; log("count \(count)") }
        }
    }
}
