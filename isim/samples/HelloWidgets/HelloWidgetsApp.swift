// HelloWidgets app: the counter its widget shows (app group defaults + WidgetCenter.reloadTimelines), widget URLs
// (widgetURL / Link taps open the app), the widgets in use (WidgetCenter.currentConfigurations), and delivery Live
// Activities: request with a push token, update (with an alert, with a stale date), a second activity, end
// (immediately or after a delay), push-to-start; contentUpdates / activityStateUpdates / activityUpdates are logged; a
// timer Live Activity (iOS 18, drawn small too).
import SwiftUI
import WidgetKit
import ActivityKit

func log(_ s: String) { NSLog("HelloWidgets: %@", s) }

@main
struct HelloWidgetsApp: App {
    var body: some Scene { WindowGroup { ContentView().onOpenURL { log("opened \($0.absoluteString)") } } }
}

func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }
/// log what happens to an activity: its push token, content updates (the app's or pushes) and state changes
func observe(_ a: Activity<DeliveryAttributes>) {
    let name = a.attributes.orderNumber
    Task { for await t in a.pushTokenUpdates { log("push token \(name) \(hex(t))") } }
    Task { for await c in a.contentUpdates { log("content \(name): \(c.state.minutes) min, \(c.state.status)") } }
    Task { for await s in a.activityStateUpdates { log("state \(name): \(s)") } }
}

struct ContentView: View {
    @State var count = sharedCount
    @State var activity: Activity<DeliveryAttributes>?
    @State var watching = false
    var body: some View {
        NavigationStack {
            List {
                Text("Count \(count)").accessibilityIdentifier("count")
                Button("Increment") {
                    sharedCount += 1; count = sharedCount
                    WidgetCenter.shared.reloadTimelines(ofKind: "Counter")
                    log("incremented to \(count)")
                }.accessibilityIdentifier("increment")
                Button("Widgets in use") {
                    Task {
                        let infos = (try? await WidgetCenter.shared.currentConfigurations) ?? []
                        log("widgets in use: " + infos.map { "\($0.kind) \($0.family)" }.sorted().joined(separator: ", "))
                    }
                }.accessibilityIdentifier("widgetsInUse")
                Button("Start delivery") {
                    do {
                        let a = try Activity.request(attributes: DeliveryAttributes(orderNumber: "42"),
                                                     content: .init(state: .init(minutes: 12, status: "Preparing"), staleDate: nil, relevanceScore: 50),
                                                     pushType: .token)
                        activity = a; observe(a)
                        log("started activity, enabled \(ActivityAuthorizationInfo().areActivitiesEnabled), \(Activity<DeliveryAttributes>.activities.count) active")
                    } catch { log("request failed \(error)") }
                }.accessibilityIdentifier("startDelivery")
                Button("Update delivery") {
                    Task { await activity?.update(.init(state: .init(minutes: 3, status: "Almost there"), staleDate: nil, relevanceScore: 50)); log("updated activity") }
                }.accessibilityIdentifier("updateDelivery")
                Button("Alert delivery") {
                    Task {
                        await activity?.update(.init(state: .init(minutes: 1, status: "At your door"), staleDate: nil, relevanceScore: 50),
                                               alertConfiguration: AlertConfiguration(title: "Delivery", body: "Your order is at the door", sound: .default))
                        log("alerted")
                    }
                }.accessibilityIdentifier("alertDelivery")
                Button("Stale delivery") {             /* the content goes out of date in 2 s: isStale */
                    Task { await activity?.update(.init(state: .init(minutes: 8, status: "On the way"), staleDate: Date().addingTimeInterval(2), relevanceScore: 50)); log("stale date set") }
                }.accessibilityIdentifier("staleDelivery")
                Button("Start pickup") {               /* a second activity: the island shows both minimal */
                    do {
                        let a = try Activity.request(attributes: DeliveryAttributes(orderNumber: "77"),
                                                     content: .init(state: .init(minutes: 30, status: "Pickup"), staleDate: nil, relevanceScore: 10))
                        observe(a)
                        log("started pickup, \(Activity<DeliveryAttributes>.activities.count) active")
                    } catch { log("request failed \(error)") }
                }.accessibilityIdentifier("startPickup")
                Button("End delivery") {
                    Task { await activity?.end(nil, dismissalPolicy: .immediate); log("ended activity") }
                }.accessibilityIdentifier("endDelivery")
                Button("End delivery later") {          /* stays on the Lock Screen for 3 s */
                    Task {
                        await activity?.end(.init(state: .init(minutes: 0, status: "Delivered"), staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(3)))
                        log("ended activity, dismissal in 3 s")
                    }
                }.accessibilityIdentifier("endDeliveryLater")
                Button("Start timer") {                  /* iOS 18: also drawn at the small size */
                    if #available(iOS 18.0, *) {
                        do {
                            _ = try Activity.request(attributes: TimerAttributes(name: "Pasta"), content: .init(state: .init(seconds: 90), staleDate: nil))
                            log("started timer")
                        } catch { log("timer failed \(error)") }
                    } else { log("the timer needs iOS 18") }
                }.accessibilityIdentifier("startTimer")
                Button("End all") {
                    Task { for a in Activity<DeliveryAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }; log("ended all") }
                }.accessibilityIdentifier("endAll")
            }
            .navigationTitle("Widgets")
            .onAppear {
                count = sharedCount; log("count \(count)")
                guard !watching else { return }
                watching = true
                Task { for await t in Activity<DeliveryAttributes>.pushToStartTokenUpdates { log("push-to-start token \(hex(t))") } }
                Task { for await a in Activity<DeliveryAttributes>.activityUpdates { log("new activity \(a.attributes.orderNumber) \(a.content.state.status)"); observe(a) } }
            }
        }
    }
}
