// isim Settings: an app's Settings.bundle (Root.plist and child panes) rendered as its page, like iOS Settings.
// Values are written to the app's own preferences domain — the plist UserDefaults.standard reads in the app's
// container (<isim data>/Containers/<bundle id>/Library/Preferences/<bundle id>.plist). DefaultValue is shown when a
// key is unset but is not written (as on iOS, apps register their defaults). Titles are localized through the
// pane's StringsTable in Settings.bundle/<lang>.lproj.
import SwiftUI

/// The app's preferences domain (read fresh for each page, written on every change).
@MainActor final class AppPreferences: ObservableObject {
    let appID: String
    @Published private(set) var values: [String: Any]
    init(appID: String) {
        self.appID = appID
        values = (NSDictionary(contentsOfFile: AppPreferences.path(appID)) as? [String: Any]) ?? [:]
    }
    static func path(_ appID: String) -> String {
        let dir = ((isimDataDir() as NSString).appendingPathComponent("Containers/\(appID)/Library/Preferences") as NSString)
        return dir.appendingPathComponent("\(appID).plist")
    }
    func reload() { values = (NSDictionary(contentsOfFile: AppPreferences.path(appID)) as? [String: Any]) ?? [:] }
    func value(_ key: String) -> Any? { values[key] }
    func set(_ key: String, _ value: Any) {
        reload()                                         // the app may have written meanwhile
        values[key] = value
        let p = AppPreferences.path(appID)
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        if let data = try? PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0) {
            try? data.write(to: URL(fileURLWithPath: p), options: .atomic)
        }
        print("Settings: \(appID) \(key) = \(value)")
    }
}

/// A pane of Settings.bundle (Root.plist or a child pane's plist).
struct SettingsPane {
    let bundlePath: String, file: String
    let title: String?, specifiers: [[String: Any]], table: String
    init?(bundlePath: String, file: String) {
        guard let d = NSDictionary(contentsOfFile: (bundlePath as NSString).appendingPathComponent(file + ".plist")) as? [String: Any],
              let specs = d["PreferenceSpecifiers"] as? [[String: Any]] else { return nil }
        self.bundlePath = bundlePath; self.file = file
        title = d["Title"] as? String
        specifiers = specs
        table = d["StringsTable"] as? String ?? "Root"
    }
    func localized(_ s: String?) -> String {
        guard let s else { return "" }
        return Bundle(path: bundlePath)?.localizedString(forKey: s, value: s, table: table) ?? s
    }
    /// Groups: each PSGroupSpecifier/PSRadioGroupSpecifier starts a section.
    var sections: [(group: [String: Any]?, items: [[String: Any]])] {
        var out: [(group: [String: Any]?, items: [[String: Any]])] = []
        for s in specifiers {
            let type = s["Type"] as? String ?? ""
            if type == "PSGroupSpecifier" || type == "PSRadioGroupSpecifier" { out.append((s, type == "PSRadioGroupSpecifier" ? [s] : [])); continue }
            if out.isEmpty { out.append((nil, [])) }
            out[out.count - 1].items.append(s)
        }
        return out
    }
}

func settingsBundlePath(_ app: InstalledApp) -> String? {
    let p = (app.path as NSString).appendingPathComponent("Settings.bundle")
    return FileManager.default.fileExists(atPath: (p as NSString).appendingPathComponent("Root.plist")) ? p : nil
}

struct SettingsPaneView: View {
    let pane: SettingsPane
    @StateObject var prefs: AppPreferences
    var body: some View {
        List {
            ForEach(Array(pane.sections.enumerated()), id: \.offset) { _, section in
                let header = (section.group?["Type"] as? String) == "PSGroupSpecifier" || (section.group?["Type"] as? String) == "PSRadioGroupSpecifier"
                    ? pane.localized(section.group?["Title"] as? String) : ""
                let footer = pane.localized(section.group?["FooterText"] as? String)
                Section {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, spec in row(spec) }
                } header: {
                    if !header.isEmpty { Text(header) }
                } footer: {
                    if !footer.isEmpty { Text(footer) }
                }
            }
        }
        .onAppear { prefs.reload() }
    }

    @ViewBuilder func row(_ s: [String: Any]) -> some View {
        let key = s["Key"] as? String ?? ""
        let title = pane.localized(s["Title"] as? String)
        switch s["Type"] as? String ?? "" {
        case "PSToggleSwitchSpecifier":
            let on = s["TrueValue"] ?? true as Any, off = s["FalseValue"] ?? false as Any
            Toggle(title, isOn: Binding(get: {
                let v = prefs.value(key) ?? s["DefaultValue"] ?? off
                return (v as? NSObject)?.isEqual(on) ?? false
            }, set: { prefs.set(key, $0 ? on : off) }))
            .accessibilityIdentifier("pref-\(key)")
        case "PSTextFieldSpecifier":
            let binding = Binding<String>(get: { (prefs.value(key) ?? s["DefaultValue"]).map { "\($0)" } ?? "" }, set: { prefs.set(key, $0) })
            HStack {
                if !title.isEmpty { Text(title) }
                if s["IsSecure"] as? Bool == true {
                    SecureField("", text: binding).multilineTextAlignment(.trailing).accessibilityIdentifier("pref-\(key)")
                } else {
                    TextField("", text: binding).multilineTextAlignment(.trailing).accessibilityIdentifier("pref-\(key)")
                }
            }
        case "PSSliderSpecifier":
            let lo = (s["MinimumValue"] as? NSNumber)?.doubleValue ?? 0, hi = (s["MaximumValue"] as? NSNumber)?.doubleValue ?? 1
            Slider(value: Binding(get: { ((prefs.value(key) ?? s["DefaultValue"]) as? NSNumber)?.doubleValue ?? lo },
                                  set: { prefs.set(key, $0) }), in: lo...hi)
            .accessibilityIdentifier("pref-\(key)")
        case "PSTitleValueSpecifier":
            let v = prefs.value(key) ?? s["DefaultValue"]
            LabeledContent(title, value: pane.localized(multiTitle(s, v) ?? v.map { "\($0)" }))
                .accessibilityIdentifier("pref-\(key)")
        case "PSMultiValueSpecifier":
            let v = prefs.value(key) ?? s["DefaultValue"]
            NavigationLink(value: Route.appMultiValue(pane.bundlePath, pane.file, key)) {
                LabeledContent(title, value: pane.localized(multiTitle(s, v)))
            }
            .accessibilityIdentifier("pref-\(key)")
        case "PSRadioGroupSpecifier":
            optionRows(s, key: key)
        case "PSChildPaneSpecifier":
            let file = s["File"] as? String ?? ""
            NavigationLink(value: Route.appPane(pane.bundlePath, file, prefs.appID)) { Text(title) }
                .accessibilityIdentifier("pref-pane-\(file)")
        default:
            EmptyView()
        }
    }

    func multiTitle(_ s: [String: Any], _ v: Any?) -> String? {
        guard let values = s["Values"] as? [Any], let titles = s["Titles"] as? [String], let v = v as? NSObject else { return nil }
        guard let i = values.firstIndex(where: { ($0 as? NSObject)?.isEqual(v) ?? false }), i < titles.count else { return nil }
        return titles[i]
    }

    @ViewBuilder func optionRows(_ s: [String: Any], key: String) -> some View {
        let values = s["Values"] as? [Any] ?? [], titles = s["Titles"] as? [String] ?? []
        ForEach(Array(zip(values.indices, titles)), id: \.0) { i, t in
            let selected = ((prefs.value(key) ?? s["DefaultValue"]) as? NSObject)?.isEqual(values[i]) ?? false
            Button { prefs.set(key, values[i]) } label: {
                HStack {
                    Text(pane.localized(t)).foregroundStyle(Color.primary)
                    Spacer()
                    if selected { Image(systemName: "checkmark").foregroundStyle(Color.blue) }
                }
            }
            .accessibilityIdentifier("pref-\(key)-\(values[i])")
        }
    }
}

/// A PSMultiValueSpecifier's choices (a pushed list with a checkmark, as on iOS).
struct MultiValueView: View {
    let pane: SettingsPane, key: String
    @StateObject var prefs: AppPreferences
    var body: some View {
        let spec = pane.specifiers.first { $0["Key"] as? String == key } ?? [:]
        List {
            Section {
                SettingsPaneView(pane: pane, prefs: prefs).optionRows(spec, key: key)
            }
        }
        .navigationTitle(pane.localized(spec["Title"] as? String)).navigationBarTitleDisplayMode(.inline)
    }
}

/// The page of an app with a Settings.bundle (and the other per-app sections).
struct AppBundleSettingsView: View {
    let app: InstalledApp, bundlePath: String
    var body: some View {
        if let pane = SettingsPane(bundlePath: bundlePath, file: "Root") {
            SettingsPaneView(pane: pane, prefs: AppPreferences(appID: app.id))
                .navigationTitle(app.name).navigationBarTitleDisplayMode(.inline)
        } else {
            List { Section { Text("No settings for this app.").foregroundStyle(.secondary) } }
                .navigationTitle(app.name).navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ChildPaneView: View {
    let bundlePath: String, file: String, appID: String
    var body: some View {
        if let pane = SettingsPane(bundlePath: bundlePath, file: file) {
            SettingsPaneView(pane: pane, prefs: AppPreferences(appID: appID))
                .navigationTitle(pane.localized(pane.title ?? file)).navigationBarTitleDisplayMode(.inline)
        } else {
            Text("Missing \(file).plist").foregroundStyle(.secondary)
        }
    }
}

struct MultiValueRouteView: View {
    let bundlePath: String, file: String, key: String
    var body: some View {
        // the app's id: Settings.bundle lives in <App>.app
        let appPath = (bundlePath as NSString).deletingLastPathComponent
        let appID = installedApps().first { $0.path == appPath }?.id ?? ""
        if let pane = SettingsPane(bundlePath: bundlePath, file: file) {
            MultiValueView(pane: pane, key: key, prefs: AppPreferences(appID: appID))
        }
    }
}
