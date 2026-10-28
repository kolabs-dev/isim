// Sample: Screen Time (issue #409). "Focus Time" asks for Screen Time authorization (FamilyControls), picks apps with
// FamilyActivityPicker, shields them right away or once they were used for 10 minutes (DeviceActivity's monitor
// extension, Monitor/), shows a usage report (the report extension, Report/), sets other settings with
// ManagedSettingsStore and reads their effective values. The shields look like ShieldConfig/ and act like
// ShieldAction/. Every step is printed ("st ...").
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

func log(_ s: String) { print("st \(s)"); fflush(stdout) }

@main
struct FocusTimeApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State var selection = FamilyActivitySelection()
    @State var picking = false
    @State var report = false
    let store = ManagedSettingsStore()
    let center = DeviceActivityCenter()

    var body: some View {
        NavigationView {
            List {
                Button("Authorize") { authorize(.individual) }.accessibilityIdentifier("authorize")
                Button("Authorize a Child") { authorize(.child) }.accessibilityIdentifier("child")
                Button("Choose Apps") { picking = true }.accessibilityIdentifier("pick")
                Button("Shield Now") {
                    store.shield.applications = selection.applicationTokens
                    log("shielding \(store.shield.applications?.count ?? 0) app(s)")
                }.accessibilityIdentifier("shield")
                Button("Limit to 10 Minutes") { monitor(minutes: 30) }.accessibilityIdentifier("monitor")
                Button("Too Short a Schedule") { monitor(minutes: 5) }.accessibilityIdentifier("short")
                Button("Ratings") {
                    store.media.maximumMovieRating = 300
                    store.media.denyExplicitContent = true
                    log("ratings movie=\(store.effectiveMaximumMovieRating) tv=\(store.effectiveMaximumTVShowRating) explicit=\(store.effectiveDenyExplicitContent) default=\(MediaSettings.maximumMovieRating.defaultValue) bounds=\(MediaSettings.maximumMovieRating.bounds)")
                }.accessibilityIdentifier("ratings")
                Button("Show Report") { report = true }.accessibilityIdentifier("report")
                Button("Clear") {
                    store.clearAllSettings()
                    center.stopMonitoring()
                    log("cleared shields=\(store.shield.applications?.count ?? 0) activities=\(center.activities.count)")
                }.accessibilityIdentifier("clear")
                Button("Revoke") {
                    AuthorizationCenter.shared.revokeAuthorization { r in log("revoked \((try? r.get()) != nil) status=\(AuthorizationCenter.shared.authorizationStatus)") }
                }.accessibilityIdentifier("revoke")
                if report { DeviceActivityReport(.init("Total Activity")) }
            }
            .navigationTitle("Focus Time")
        }
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        .onChange(of: selection) { s in log("picked \(s.applicationTokens.count) app(s) \(s.categoryTokens.count) category(ies) names=\(s.applications.compactMap(\.bundleIdentifier).count)") }
        .onAppear { log("launched status=\(AuthorizationCenter.shared.authorizationStatus)") }
    }

    func authorize(_ member: FamilyControlsMember) {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: member)
                log("authorized \(member) status=\(AuthorizationCenter.shared.authorizationStatus)")
            } catch {
                let why = (error as? FamilyControlsError).map { "\($0)" } ?? "\(error)"
                log("authorization \(member) failed \(why) status=\(AuthorizationCenter.shared.authorizationStatus)")
            }
        }
    }

    func monitor(minutes: Int) {
        let cal = Calendar.current
        let start = cal.dateComponents([.hour, .minute], from: Date().addingTimeInterval(-60))
        let end = cal.dateComponents([.hour, .minute], from: Date().addingTimeInterval(Double(minutes) * 60))
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false, warningTime: DateComponents(minute: 5))
        let event = DeviceActivityEvent(applications: selection.applicationTokens, threshold: DateComponents(minute: 10))
        do {
            try center.startMonitoring(DeviceActivityName("focus"), during: schedule, events: [DeviceActivityEvent.Name("limit"): event])
            log("monitoring \(center.activities.map(\.rawValue)) events=\(center.events(for: DeviceActivityName("focus")).count) next=\(schedule.nextInterval != nil)")
        } catch {
            log("monitoring failed \(error)")
        }
    }
}
