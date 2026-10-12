// isim Settings: Focus (iOS 15+ layout). Adapted.
// The Focus modes (Do Not Disturb, Personal, Work, Sleep) with the apps each allows to notify, whether time-sensitive
// notifications break through, and Focus filters: the filters apps declare (SetFocusFilterIntent; the home screen asks
// each app for them, <isim data>/Library/SpringBoard/FocusFilters/<bundle id>/focus-filters.plist), configured with
// their parameters. Saved in <isim data>/Library/isim/Focus/: Focus.plist (everything; the home screen runs the filters
// from it), Allowed.txt and Options.txt (what the shell reads to silence notifications). Which Focus is on: Current
// (the shell's: Control Center or the script `focus`).
// Not on isim: allowed people (no communication notifications), schedules, Lock Screen / Home Screen customization,
// Focus status sharing settings (apps ask with INFocusStatusCenter), new custom Focus modes.
import SwiftUI
import isim_host

struct FocusMode: Identifiable, Hashable { let id: String, name: String, symbol: String, color: Color }
let focusModes = [
    FocusMode(id: "dnd", name: "Do Not Disturb", symbol: "moon.fill", color: .indigo),
    FocusMode(id: "personal", name: "Personal", symbol: "person.fill", color: .purple),
    FocusMode(id: "work", name: "Work", symbol: "person.lanyardcard.fill", color: .teal),
    FocusMode(id: "sleep", name: "Sleep", symbol: "bed.double.fill", color: .mint),
]

enum FocusRoute: Hashable { case list, mode(String), apps(String), addFilter(String), filter(String, String, String, Int) }   // filter: mode, app, type, index (-1: new)

/// a Focus filter an app declares (its own description)
struct FocusFilterInfo: Hashable {
    let app: InstalledApp, type: String, title: String, description: String
    let params: [[String: AnyHashable]]
}

@MainActor enum FocusStore {
    static var dir: String { (isimDataDir() as NSString).appendingPathComponent("Library/isim/Focus") }
    static var file: String { (dir as NSString).appendingPathComponent("Focus.plist") }
    static func load() -> [String: Any] { NSDictionary(contentsOfFile: file) as? [String: Any] ?? [:] }
    static func save(_ d: [String: Any]) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        (d as NSDictionary).write(toFile: file, atomically: true)
        // what the shell reads: allowed apps (paths) and options
        let apps = installedApps()
        var allowed = "", options = ""
        for (mode, ids) in d["allowed"] as? [String: [String]] ?? [:] {
            for id in ids { if let a = apps.first(where: { $0.id == id }) { allowed += "\(mode)\t\(a.path)\n" } }
        }
        for (mode, on) in d["timeSensitive"] as? [String: Bool] ?? [:] { options += "\(mode)\ttimesensitive\t\(on ? 1 : 0)\n" }
        try? allowed.write(toFile: (dir as NSString).appendingPathComponent("Allowed.txt"), atomically: true, encoding: .utf8)
        try? options.write(toFile: (dir as NSString).appendingPathComponent("Options.txt"), atomically: true, encoding: .utf8)
    }
    static func update(_ f: (inout [String: Any]) -> Void) { var d = load(); f(&d); save(d) }
    static var current: String? {
        let s = (try? String(contentsOfFile: (dir as NSString).appendingPathComponent("Current"), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return s?.isEmpty == false ? s : nil
    }
    static func allowed(_ mode: String) -> [String] { (load()["allowed"] as? [String: [String]])?[mode] ?? [] }
    static func timeSensitive(_ mode: String) -> Bool { (load()["timeSensitive"] as? [String: Bool])?[mode] ?? true }
    static func filters(_ mode: String) -> [[String: Any]] { (load()["filters"] as? [String: [[String: Any]]])?[mode] ?? [] }
    static func setFilters(_ mode: String, _ list: [[String: Any]]) {
        update { d in var all = d["filters"] as? [String: [[String: Any]]] ?? [:]; all[mode] = list; d["filters"] = all }
        isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "focus-config", nil, nil)      // the filters run again if that Focus is on
    }
    /// the filters installed apps declare
    static func available() -> [FocusFilterInfo] {
        var out: [FocusFilterInfo] = []
        for app in installedApps() {
            let f = ((isimDataDir() as NSString).appendingPathComponent("Library/SpringBoard/FocusFilters/\(app.id)") as NSString).appendingPathComponent("focus-filters.plist")
            for d in (NSDictionary(contentsOfFile: f) as? [String: Any])?["filters"] as? [[String: Any]] ?? [] {
                let params = (d["params"] as? [[String: Any]] ?? []).map { p in p.compactMapValues { $0 as? AnyHashable } }
                out.append(FocusFilterInfo(app: app, type: d["type"] as? String ?? "", title: d["title"] as? String ?? "Filter",
                                           description: d["description"] as? String ?? "", params: params))
            }
        }
        return out
    }
}

struct FocusIcon: View {
    let mode: FocusMode
    var body: some View {
        ZStack { RoundedRectangle(cornerRadius: 7).fill(mode.color); Image(systemName: mode.symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(.white) }
            .frame(width: 29, height: 29)
    }
}

struct FocusDestination: View {
    let route: FocusRoute
    var body: some View {
        switch route {
        case .list: FocusListView()
        case .mode(let m): FocusModeView(modeID: m)
        case .apps(let m): FocusAppsView(modeID: m)
        case .addFilter(let m): FocusAddFilterView(modeID: m)
        case .filter(let m, let app, let type, let index): FocusFilterView(modeID: m, appID: app, type: type, index: index)
        }
    }
}

struct FocusListView: View {
    @State private var refresh = 0
    var body: some View {
        let cur = FocusStore.current
        List {
            Section {
                ForEach(focusModes) { m in
                    NavigationLink(value: Route.focus(.mode(m.id))) {
                        HStack {
                            Label { Text(m.name) } icon: { FocusIcon(mode: m) }
                            Spacer()
                            if cur == m.id { Text("On").foregroundStyle(.secondary) }
                        }
                    }
                    .accessibilityIdentifier("settings-focus-\(m.id)")
                }
            } footer: { Text("Focus lets you customize your device and silence calls and notifications. Turn Focus on and off in Control Center.") }
        }
        .id(refresh)
        .onAppear { refresh += 1 }
        .navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
    }
}

struct FocusModeView: View {
    let modeID: String
    @State private var refresh = 0
    var body: some View {
        let mode = focusModes.first { $0.id == modeID } ?? focusModes[0]
        let on = FocusStore.current == modeID
        let apps = installedApps(), allowed = FocusStore.allowed(modeID)
        List {
            Section {
                VStack(spacing: 8) {
                    ZStack { Circle().fill(mode.color); Image(systemName: mode.symbol).font(.system(size: 30)).foregroundStyle(.white) }.frame(width: 64, height: 64)
                    Text(mode.name).font(.title2.bold())
                }
                .frame(maxWidth: .infinity)
                if on { Text("On").foregroundStyle(.secondary).frame(maxWidth: .infinity).accessibilityIdentifier("focus-on") }
            }
            Section("Allow Notifications") {
                NavigationLink(value: Route.focus(.apps(modeID))) {
                    LabeledContent("Apps", value: allowed.isEmpty ? "None allowed" : "\(allowed.filter { id in apps.contains { $0.id == id } }.count) allowed")
                }
                .accessibilityIdentifier("focus-apps")
            }
            Section {
                ForEach(Array(FocusStore.filters(modeID).enumerated()), id: \.offset) { i, f in
                    let app = apps.first { $0.id == f["app"] as? String }
                    NavigationLink(value: Route.focus(.filter(modeID, f["app"] as? String ?? "", f["type"] as? String ?? "", i))) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app?.name ?? (f["app"] as? String ?? ""))
                                Text(f["title"] as? String ?? "").font(.footnote).foregroundStyle(.secondary)
                            }
                        } icon: { if let app { AppIcon(app: app) } else { SettingsIcon(symbol: "app", color: .gray) } }
                    }
                    .accessibilityIdentifier("focus-filter-\(f["app"] as? String ?? "")")
                }
                NavigationLink(value: Route.focus(.addFilter(modeID))) { Text("Add Filter").foregroundStyle(.blue) }
                    .accessibilityIdentifier("focus-add-filter")
            } header: { Text("Focus Filters") } footer: { Text("Customize how apps behave when this Focus is on.") }
        }
        .id(refresh)
        .onAppear { refresh += 1 }
        .navigationTitle(mode.name).navigationBarTitleDisplayMode(.inline)
    }
}

struct FocusAppsView: View {
    let modeID: String
    @State private var refresh = 0
    var body: some View {
        let allowed = FocusStore.allowed(modeID)
        List {
            Section {
                ForEach(installedApps()) { app in
                    Toggle(isOn: Binding(get: { allowed.contains(app.id) }, set: { on in
                        FocusStore.update { d in
                            var all = d["allowed"] as? [String: [String]] ?? [:]
                            var l = all[modeID] ?? []
                            l.removeAll { $0 == app.id }
                            if on { l.append(app.id) }
                            all[modeID] = l; d["allowed"] = all
                        }
                        refresh += 1
                    })) { Label { Text(app.name) } icon: { AppIcon(app: app) } }
                    .accessibilityIdentifier("focus-app-\(app.id)")
                }
            } header: { Text("Allowed Apps") } footer: { Text("Notifications from other apps are delivered quietly to Notification Center.") }
            Section {
                Toggle("Time Sensitive Notifications", isOn: Binding(get: { FocusStore.timeSensitive(modeID) }, set: { on in
                    FocusStore.update { d in var t = d["timeSensitive"] as? [String: Bool] ?? [:]; t[modeID] = on; d["timeSensitive"] = t }
                    refresh += 1
                }))
                .accessibilityIdentifier("focus-timesensitive")
            } footer: { Text("Allow all apps to send Time Sensitive notifications immediately, even when this Focus is on.") }
        }
        .id(refresh)
        .navigationTitle("Apps").navigationBarTitleDisplayMode(.inline)
    }
}

struct FocusAddFilterView: View {
    let modeID: String
    @State private var chosen: FocusFilterInfo?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let filters = FocusStore.available()
        List {
            Section {
                if filters.isEmpty { Text("Apps with Focus filters appear here.").foregroundStyle(.secondary) }
                ForEach(filters, id: \.self) { f in
                    Button { chosen = f } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.app.name).foregroundStyle(.primary)
                                Text(f.title).font(.footnote).foregroundStyle(.secondary)
                            }
                        } icon: { AppIcon(app: f.app) }
                    }
                    .accessibilityIdentifier("focus-filter-app-\(f.app.id)")
                }
            } header: { Text("App Filters") }
        }
        .navigationTitle("Add Filter").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $chosen) { f in      // like iOS: the filter's options in a sheet; Add returns to the Focus
            NavigationStack {
                FocusFilterView(modeID: modeID, appID: f.app.id, type: f.type, index: -1) {
                    chosen = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dismiss() }
                }
            }
        }
    }
}
extension FocusFilterInfo: Identifiable { var id: String { app.id + "/" + type } }

/// a filter's parameters (new: index -1)
struct FocusFilterView: View {
    let modeID: String, appID: String, type: String, index: Int
    var onDone: (() -> Void)? = nil
    @State private var values: [String: Any] = [:]
    @State private var loaded = false
    @State private var saved = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let info = FocusStore.available().first { $0.app.id == appID && $0.type == type }
        List {
            if let info {
                Section { Text(info.title).font(.headline); if !info.description.isEmpty { Text(info.description).foregroundStyle(.secondary) } }
                Section("Options") {
                    ForEach(Array(info.params.enumerated()), id: \.offset) { _, p in paramRow(p) }
                }
                Section {
                    Button(index < 0 ? "Add" : "Done") { save(info) }.accessibilityIdentifier("focus-filter-add")
                    if index >= 0 {
                        Button("Delete Filter", role: .destructive) {
                            var l = FocusStore.filters(modeID); if index < l.count { l.remove(at: index) }
                            FocusStore.setFilters(modeID, l); NSLog("Settings: Focus filter %@ removed from %@", info.title, modeID)
                            dismiss()
                        }.accessibilityIdentifier("focus-filter-delete")
                    }
                }
            } else {
                Text("This app no longer offers this filter.").foregroundStyle(.secondary)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            var v: [String: Any] = [:]
            for p in info?.params ?? [] { if let n = p["name"] as? String, let d = p["default"] { v[n] = d } }
            if index >= 0, index < FocusStore.filters(modeID).count, let cur = FocusStore.filters(modeID)[index]["params"] as? [String: Any] { v.merge(cur) { $1 } }
            values = v
        }
        .navigationTitle(info?.app.name ?? "Filter").navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder func paramRow(_ p: [String: AnyHashable]) -> some View {
        let name = p["name"] as? String ?? "", title = p["title"] as? String ?? name, kind = p["kind"] as? String ?? "string"
        switch kind {
        case "bool":
            Toggle(title, isOn: Binding(get: { values[name] as? Bool ?? false }, set: { values[name] = $0 })).accessibilityIdentifier("focus-param-\(name)")
        case "enum":
            let cases = p["cases"] as? [[String]] ?? []
            Text(title).font(.footnote).foregroundStyle(.secondary)
            ForEach(cases, id: \.self) { c in
                Button { values[name] = c.first ?? "" } label: {
                    HStack { Text(c.count > 1 ? c[1] : c.first ?? "").foregroundStyle(.primary); Spacer(); if values[name] as? String == c.first { Image(systemName: "checkmark").foregroundStyle(.blue) } }
                }
                .accessibilityIdentifier("focus-param-\(name)-\(c.first ?? "")")
            }
        case "int", "double":
            HStack {
                Text(title)
                Spacer()
                TextField("0", text: Binding(get: { (values[name]).map { "\($0)" } ?? "" }, set: { s in
                    if kind == "int" { values[name] = Int(s) ?? 0 } else { values[name] = Double(s) ?? 0 }
                })).multilineTextAlignment(.trailing).keyboardType(.numberPad).accessibilityIdentifier("focus-param-\(name)")
            }
        default:
            TextField(title, text: Binding(get: { values[name] as? String ?? "" }, set: { values[name] = $0 })).accessibilityIdentifier("focus-param-\(name)")
        }
    }
    func save(_ info: FocusFilterInfo) {
        guard !saved else { return }
        saved = true
        var l = FocusStore.filters(modeID)
        let entry: [String: Any] = ["app": info.app.id, "type": info.type, "title": info.title, "params": values]
        if index >= 0 && index < l.count { l[index] = entry } else { l.append(entry) }
        FocusStore.setFilters(modeID, l)
        NSLog("Settings: Focus filter %@ of %@ %@ for %@: %@", info.title, info.app.name, index < 0 ? "added" : "changed", modeID,
              values.keys.sorted().map { "\($0)=\(values[$0]!)" }.joined(separator: ", "))
        if let onDone { onDone() } else { dismiss() }
    }
}
