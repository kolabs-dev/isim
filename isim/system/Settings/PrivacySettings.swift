// isim Settings: Privacy & Security and Notifications, like iOS — the permissions apps asked for, per service and per
// app. Each answer lives in the app's own defaults (<container>/Library/Preferences/<bundle id>.plist) where the
// framework stored it: _ISIMPrivacy.<service> (the framework's authorization status), _ISIMNotificationAuthorization /
// _ISIMNotificationOptions, _ISIMTrackingAuthorizationStatus. Like iOS, turning a permission off terminates the app if
// it is running, so it starts again with the new answer; a service an app never asked for is not listed.
import SwiftUI
import isim_host

/// A permission an app can ask for: its defaults key, the choices Settings offers (stored value, title) and the
/// value that counts as denied.
struct PrivacyService: Identifiable, Hashable {
    let id: String, title: String, symbol: String, color: Color
    let key: String
    let choices: [Choice]
    struct Choice: Hashable { let value: Int, title: String }
    /// a switch (two choices) or a list of choices
    var isToggle: Bool { choices.count == 2 && choices[0].title.isEmpty }
    func title(for value: Int?) -> String {
        guard let v = value else { return "" }
        if isToggle { return v == choices[1].value ? "On" : "Off" }
        return choices.first { $0.value == v }?.title ?? "\(v)"
    }
    /// a value that takes access away (Settings then terminates the running app)
    func revokes(_ old: Int?, _ new: Int) -> Bool { new == choices[0].value && old != new }

    static func toggle(_ id: String, _ title: String, _ symbol: String, _ color: Color, key: String, off: Int, on: Int) -> PrivacyService {
        PrivacyService(id: id, title: title, symbol: symbol, color: color, key: key, choices: [Choice(value: off, title: ""), Choice(value: on, title: "")])
    }
    /// the services in iOS's Privacy & Security order (raw values of each framework's authorization status)
    static let all: [PrivacyService] = [
        // CLAuthorizationStatus: notDetermined 0, denied 2, authorizedAlways 3, authorizedWhenInUse 4
        PrivacyService(id: "location", title: "Location Services", symbol: "location.fill", color: .blue, key: "_ISIMPrivacy.location",
                       choices: [Choice(value: 2, title: "Never"), Choice(value: 0, title: "Ask Next Time Or When I Share"),
                                 Choice(value: 4, title: "While Using the App"), Choice(value: 3, title: "Always")]),
        // ATTrackingManager.AuthorizationStatus: denied 2, authorized 3
        .toggle("tracking", "Tracking", "hand.raised.fill", .orange, key: "_ISIMTrackingAuthorizationStatus", off: 2, on: 3),
        // CNAuthorizationStatus: denied 2, authorized 3, limited 4
        PrivacyService(id: "contacts", title: "Contacts", symbol: "person.crop.circle", color: .gray, key: "_ISIMPrivacy.contacts",
                       choices: [Choice(value: 2, title: "None"), Choice(value: 4, title: "Limited Access"), Choice(value: 3, title: "Full Access")]),
        // EKAuthorizationStatus: denied 2, fullAccess 3, writeOnly 4
        PrivacyService(id: "calendar", title: "Calendars", symbol: "calendar", color: .red, key: "_ISIMPrivacy.calendar",
                       choices: [Choice(value: 2, title: "None"), Choice(value: 4, title: "Add Events Only"), Choice(value: 3, title: "Full Access")]),
        .toggle("reminders", "Reminders", "list.bullet", .orange, key: "_ISIMPrivacy.reminders", off: 2, on: 3),
        // PHAuthorizationStatus: denied 2, authorized 3, limited 4
        PrivacyService(id: "photos", title: "Photos", symbol: "photo.on.rectangle", color: .purple, key: "_ISIMPrivacy.photos",
                       choices: [Choice(value: 2, title: "None"), Choice(value: 4, title: "Limited Access"), Choice(value: 3, title: "Full Access")]),
        .toggle("photosAdd", "Add Photos Only", "photo.badge.plus", .purple, key: "_ISIMPrivacy.photosAdd", off: 2, on: 3),
        // AVAuthorizationStatus: denied 2, authorized 3
        .toggle("microphone", "Microphone", "mic.fill", .orange, key: "_ISIMPrivacy.microphone", off: 2, on: 3),
        // SFSpeechRecognizerAuthorizationStatus: denied 1, authorized 3
        .toggle("speech", "Speech Recognition", "waveform", .gray, key: "_ISIMPrivacy.speech", off: 1, on: 3),
        .toggle("camera", "Camera", "camera.fill", .gray, key: "_ISIMPrivacy.camera", off: 2, on: 3),
    ]
}

/// One app's stored permission answers (its defaults file).
@MainActor func storedPermission(_ app: InstalledApp, _ s: PrivacyService) -> Int? { AppPreferences(appID: app.id).value(s.key) as? Int }

/// Stores an answer for an app; like iOS, taking access away from a running app terminates it.
@MainActor func setPermission(_ app: InstalledApp, _ s: PrivacyService, _ value: Int) {
    let prefs = AppPreferences(appID: app.id)
    let old = prefs.value(s.key) as? Int
    prefs.set(s.key, value)
    if s.revokes(old, value) {
        isim_shell_request(Int32(ISIM_SHELL_TERMINATE_APP), app.path, nil, nil)
        print("Settings: \(app.id) \(s.id) turned off: the app is terminated")
    }
}

// MARK: - Privacy & Security

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                ForEach(PrivacyService.all.filter { $0.id != "photosAdd" }) { s in
                    NavigationLink(value: Route.privacyService(s.id)) {
                        LabeledContent {
                            if s.id == "location" { Text(locationServicesOn ? "On" : "Off") }
                        } label: { Label { Text(s.title) } icon: { SettingsIcon(symbol: s.symbol, color: s.color) } }
                    }
                    .accessibilityIdentifier("settings-privacy-\(s.id)")
                }
            } footer: {
                Text("As apps request access, they will be added in the categories above.")
            }
        }
        .navigationTitle("Privacy & Security").navigationBarTitleDisplayMode(.inline)
    }
    var locationServicesOn: Bool { true }
}

/// The apps that asked for one service, with their answers.
struct PrivacyServiceView: View {
    let id: String
    @State private var refresh = 0
    var body: some View {
        let s = PrivacyService.all.first { $0.id == id }
        let services = id == "photos" ? PrivacyService.all.filter { $0.id == "photos" || $0.id == "photosAdd" } : (s.map { [$0] } ?? [])
        let apps = installedApps().filter { app in services.contains { storedPermission(app, $0) != nil } }
        List {
            if apps.isEmpty {
                Section { Text("Applications that have requested access to \(s?.title ?? id) will appear here.").foregroundStyle(.secondary) }
            } else {
                Section {
                    ForEach(apps) { app in
                        if let s, s.isToggle, id != "photos" {
                            Toggle(isOn: Binding(get: { storedPermission(app, s) == s.choices[1].value },
                                                 set: { setPermission(app, s, $0 ? s.choices[1].value : s.choices[0].value); refresh += 1 })) {
                                Label { Text(app.name) } icon: { AppIcon(app: app) }
                            }
                            .accessibilityIdentifier("settings-privacy-\(id)-\(app.id)")
                        } else {
                            NavigationLink(value: Route.appPermission(app.id, services.first { storedPermission(app, $0) != nil }?.id ?? id)) {
                                LabeledContent {
                                    Text(permissionSummary(app, services))
                                } label: { Label { Text(app.name) } icon: { AppIcon(app: app) } }
                            }
                            .accessibilityIdentifier("settings-privacy-\(id)-\(app.id)")
                        }
                    }
                }
            }
        }
        .id(refresh)
        .navigationTitle(s?.title ?? id).navigationBarTitleDisplayMode(.inline)
    }
}

/// "Full Access", "Add Photos Only", ... for the services' stored answers
@MainActor func permissionSummary(_ app: InstalledApp, _ services: [PrivacyService]) -> String {
    for s in services { if let v = storedPermission(app, s), !(s.id == "photosAdd" && v != 3) { return s.id == "photosAdd" ? "Add Photos Only" : s.title(for: v) } }
    return ""
}

/// One app's answer for a service with choices (Location, Contacts, Calendars, Photos).
struct AppPermissionView: View {
    let appID: String, serviceID: String
    @State private var refresh = 0
    var body: some View {
        let app = installedApps().first { $0.id == appID }
        let s = PrivacyService.all.first { $0.id == (serviceID == "photosAdd" ? "photos" : serviceID) }
        List {
            if let app, let s {
                Section {
                    ForEach(s.choices, id: \.self) { c in
                        Button {
                            setPermission(app, s, c.value)
                            if s.id == "photos", let add = PrivacyService.all.first(where: { $0.id == "photosAdd" }) { AppPreferences(appID: app.id).set(add.key, 2) }
                            refresh += 1
                        } label: {
                            HStack {
                                Text(c.title).foregroundStyle(.primary)
                                Spacer()
                                if storedPermission(app, s) == c.value && !addOnly(app) { Image(systemName: "checkmark").foregroundStyle(.blue) }
                            }
                        }
                        .accessibilityIdentifier("settings-permission-\(s.id)-\(c.value)")
                    }
                    if s.id == "photos", let add = PrivacyService.all.first(where: { $0.id == "photosAdd" }) {
                        Button {
                            setPermission(app, s, 2)
                            AppPreferences(appID: app.id).set(add.key, 3)
                            refresh += 1
                        } label: {
                            HStack {
                                Text("Add Photos Only").foregroundStyle(.primary)
                                Spacer()
                                if addOnly(app) { Image(systemName: "checkmark").foregroundStyle(.blue) }
                            }
                        }
                        .accessibilityIdentifier("settings-permission-photos-addonly")
                    }
                } header: { Text("Allow \(s.title) Access") }
            }
        }
        .id(refresh)
        .navigationTitle(s?.title ?? serviceID).navigationBarTitleDisplayMode(.inline)
    }
    @MainActor func addOnly(_ app: InstalledApp) -> Bool {
        AppPreferences(appID: app.id).value("_ISIMPrivacy.photosAdd") as? Int == 3 && (AppPreferences(appID: app.id).value("_ISIMPrivacy.photos") as? Int ?? 2) == 2
    }
}

/// The app page's rows for the services it asked for (in "Allow <app> to Access").
struct AppPrivacyRows: View {
    let app: InstalledApp
    @State private var refresh = 0
    var body: some View {
        let asked = PrivacyService.all.filter { $0.id != "photosAdd" && storedPermission(app, $0) != nil }
        let addOnly = storedPermission(app, PrivacyService.all.first { $0.id == "photosAdd" }!) != nil
        Group {
            ForEach(asked) { s in
                if s.isToggle {
                    Toggle(isOn: Binding(get: { storedPermission(app, s) == s.choices[1].value },
                                         set: { setPermission(app, s, $0 ? s.choices[1].value : s.choices[0].value); refresh += 1 })) {
                        Label { Text(s.title) } icon: { SettingsIcon(symbol: s.symbol, color: s.color) }
                    }
                    .accessibilityIdentifier("settings-app-\(s.id)")
                } else {
                    NavigationLink(value: Route.appPermission(app.id, s.id)) {
                        LabeledContent { Text(s.id == "photos" ? permissionSummary(app, [PrivacyService.all.first { $0.id == "photosAdd" }!, s]) : s.title(for: storedPermission(app, s))) }
                        label: { Label { Text(s.id == "location" ? "Location" : s.title) } icon: { SettingsIcon(symbol: s.symbol, color: s.color) } }
                    }
                    .accessibilityIdentifier("settings-app-\(s.id)")
                }
            }
            if addOnly && !asked.contains(where: { $0.id == "photos" }) {
                NavigationLink(value: Route.appPermission(app.id, "photos")) {
                    LabeledContent { Text("Add Photos Only") } label: { Label { Text("Photos") } icon: { SettingsIcon(symbol: "photo.on.rectangle", color: .purple) } }
                }
                .accessibilityIdentifier("settings-app-photos")
            }
            if appNotificationStatus(app) != nil {
                NavigationLink(value: Route.appNotifications(app.id)) {
                    LabeledContent { Text(notificationSummary(app)) } label: { Label { Text("Notifications") } icon: { SettingsIcon(symbol: "bell.badge.fill", color: .red) } }
                }
                .accessibilityIdentifier("settings-app-notifications")
            }
        }
        .id(refresh)
    }
}

// MARK: - Notifications

/// UNAuthorizationStatus as the app stored it: notDetermined 0, denied 1, authorized 2, provisional 3, ephemeral 4
@MainActor func appNotificationStatus(_ app: InstalledApp) -> Int? { AppPreferences(appID: app.id).value("_ISIMNotificationAuthorization") as? Int }
@MainActor func notificationSummary(_ app: InstalledApp) -> String {
    switch appNotificationStatus(app) ?? 0 {
    case 1: return "Off"
    case 3: return "Deliver Quietly"
    case 0: return ""
    default:
        let o = AppPreferences(appID: app.id).value("_ISIMNotificationOptions") as? Int ?? 0
        let parts = [(o & 4) != 0 ? "Banners" : nil, (o & 2) != 0 ? "Sounds" : nil, (o & 1) != 0 ? "Badges" : nil].compactMap { $0 }
        return parts.isEmpty ? "Off" : parts.joined(separator: ", ")
    }
}

struct NotificationsView: View {
    var body: some View {
        let apps = installedApps().filter { appNotificationStatus($0) != nil && appNotificationStatus($0) != 0 }
        List {
            Section("Notification Style") {
                if apps.isEmpty { Text("Apps that ask to send notifications appear here.").foregroundStyle(.secondary) }
                ForEach(apps) { app in
                    NavigationLink(value: Route.appNotifications(app.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                            Text(notificationSummary(app)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings-notifications-\(app.id)")
                }
            }
        }
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
    }
}

/// One app's notifications: Allow Notifications, and the alert kinds (UNAuthorizationOptions badge 1, sound 2, alert 4).
struct AppNotificationsView: View {
    let id: String
    @State private var refresh = 0
    var body: some View {
        let app = installedApps().first { $0.id == id }
        List {
            if let app {
                let prefs = AppPreferences(appID: app.id)
                let status = appNotificationStatus(app) ?? 0
                let opts = prefs.value("_ISIMNotificationOptions") as? Int ?? 0
                Section {
                    Toggle("Allow Notifications", isOn: Binding(get: { status == 2 || status == 3 || status == 4 }, set: { on in
                        prefs.set("_ISIMNotificationAuthorization", on ? 2 : 1)
                        if on && opts == 0 { prefs.set("_ISIMNotificationOptions", 7) }
                        refresh += 1
                    }))
                    .accessibilityIdentifier("settings-notifications-allow")
                }
                if status == 2 || status == 3 || status == 4 {
                    Section("Alerts") {
                        option("Banners", bit: 4, opts, prefs).accessibilityIdentifier("settings-notifications-banners")
                        option("Sounds", bit: 2, opts, prefs).accessibilityIdentifier("settings-notifications-sounds")
                        option("Badges", bit: 1, opts, prefs).accessibilityIdentifier("settings-notifications-badges")
                    }
                }
            }
        }
        .id(refresh)
        .navigationTitle(app.map { "\($0.name)" } ?? id).navigationBarTitleDisplayMode(.inline)
    }
    func option(_ title: String, bit: Int, _ opts: Int, _ prefs: AppPreferences) -> some View {
        Toggle(title, isOn: Binding(get: { (opts & bit) != 0 }, set: { on in
            prefs.set("_ISIMNotificationOptions", on ? opts | bit : opts & ~bit)
            refresh += 1
        }))
    }
}
