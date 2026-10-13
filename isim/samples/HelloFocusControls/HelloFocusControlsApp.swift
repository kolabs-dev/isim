// HelloFocusControls ("Focus Lamp"): Focus and Control Center controls. A Focus filter (SetFocusFilterIntent) with a
// Bool and an AppEnum parameter whose notification predicate keeps only "work" notifications; notifications with
// filter criteria and a time-sensitive one; the Focus status (INFocusStatusCenter); ControlCenter.reloadControls and
// currentControls for the lamp and counter controls of its widget extension.
import SwiftUI
import AppIntents
import UserNotifications
import Intents
import WidgetKit

func log(_ s: String) { NSLog("HelloFocusControls: %@", s) }

enum LampAccount: String, AppEnum {
    case work, home
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Account"
    static var caseDisplayRepresentations: [LampAccount: DisplayRepresentation] = [.work: "Work account", .home: "Home account"]
}

/// Settings > Focus > (a Focus) > Focus Filters > Add Filter > Focus Lamp
struct LampFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set Lamp Focus"
    static var description: IntentDescription? = "Choose what Focus Lamp shows while this Focus is on"
    @Parameter(title: "Only work notifications", default: false) var workOnly: Bool
    @Parameter(title: "Account", default: .home) var account: LampAccount
    @Parameter(title: "Note") var note: String?
    init() {}
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(account.rawValue)\(workOnly ? ", work only" : "")") }
    var appContext: FocusFilterAppContext {
        FocusFilterAppContext(notificationFilterPredicate: workOnly ? NSPredicate(format: "SELF IN %@", argumentArray: [["work"]]) : nil)
    }
    func perform() async throws -> some IntentResult {
        log("focus filter perform workOnly=\(workOnly) account=\(account.rawValue) note=\(note ?? "-")")
        UserDefaults.standard.set("\(account.rawValue)\(workOnly ? " work-only" : "")", forKey: "filterSummary")
        return .result()
    }
}

@main
struct HelloFocusControlsApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State var summary = "-"
    @State var focused = "-"
    var body: some View {
        NavigationStack {
            List {
                Section("Controls") {
                    Button("Reload lamp control") {
                        if #available(iOS 18.0, *) { ControlCenter.shared.reloadControls(ofKind: "dev.isim.samples.HelloFocusControls.lamp") }
                    }.accessibilityIdentifier("reloadLamp")
                    Button("Current controls") {
                        if #available(iOS 18.0, *) {
                            Task {      // e.g. "count, lamp" (the kinds without the app's prefix)
                                let kinds = try await ControlCenter.shared.currentControls().map { $0.kind.components(separatedBy: ".").last ?? $0.kind }
                                log("current controls \(kinds.sorted().joined(separator: ", "))")
                            }
                        } else { log("controls need iOS 18") }
                    }.accessibilityIdentifier("currentControls")
                    Button("Lamp \(lampOn ? "on" : "off") (toggle)") {
                        lampOn.toggle(); log("app set lamp \(lampOn ? "on" : "off")")
                        if #available(iOS 18.0, *) { ControlCenter.shared.reloadControls(ofKind: "dev.isim.samples.HelloFocusControls.lamp") }
                    }.accessibilityIdentifier("toggleLamp")
                }
                Section("Focus filter") {
                    Text("Filter: \(summary)").accessibilityIdentifier("filter")
                    Button("Read current filter") {
                        Task {
                            let f = try await LampFocusFilter.current
                            summary = "\(f.account.rawValue)\(f.workOnly ? " work-only" : "")"
                            log("current filter \(summary)")
                        }
                    }.accessibilityIdentifier("readFilter")
                }
                Section("Notifications") {
                    Button("Notify home") { notify("home", "Dinner is ready", criteria: "home") }.accessibilityIdentifier("notifyHome")
                    Button("Notify work") { notify("work", "Build finished", criteria: "work") }.accessibilityIdentifier("notifyWork")
                    Button("Notify time-sensitive") { notify("urgent", "Server down", criteria: nil, timeSensitive: true) }.accessibilityIdentifier("notifyUrgent")
                }
                Section("Focus status") {
                    Text("Focused: \(focused)").accessibilityIdentifier("focused")
                    Button("Check Focus status") {
                        INFocusStatusCenter.default.requestAuthorization { status in
                            let f = INFocusStatusCenter.default.focusStatus.isFocused
                            DispatchQueue.main.async {
                                focused = f.map { $0 ? "yes" : "no" } ?? "unknown"
                                log("focus status authorization \(status.rawValue), isFocused \(focused)")
                            }
                        }
                    }.accessibilityIdentifier("focusStatus")
                }
            }
            .navigationTitle("Focus Lamp")
            .onAppear {
                summary = UserDefaults.standard.string(forKey: "filterSummary") ?? "-"
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in log("notifications \(ok ? "allowed" : "denied")") }
                log("ready")
            }
        }
    }
    func notify(_ id: String, _ body: String, criteria: String?, timeSensitive: Bool = false) {
        let c = UNMutableNotificationContent()
        c.title = "Focus Lamp"; c.body = body
        if let criteria { c.filterCriteria = criteria }
        if timeSensitive { c.interruptionLevel = .timeSensitive }
        let r = UNNotificationRequest(identifier: id, content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
        UNUserNotificationCenter.current().add(r) { _ in log("scheduled \(id)") }
    }
}
