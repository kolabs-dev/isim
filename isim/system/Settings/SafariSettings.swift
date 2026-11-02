// isim Settings: Safari's pages (Settings > Apps > Safari), which SFSafariSettings opens (issue #423): AutoFill, Export
// Browsing Data (iOS 26: what to export, then Save to Files) and Extensions (the content blockers and web extensions of
// installed apps; ones an app asked about that no app contains are listed as not installed).
import SwiftUI

struct SafariSettingsView: View {
    @State private var bump = 0
    var body: some View {
        let _ = bump
        List {
            Section("General") {
                Toggle("AutoFill Names and Passwords", isOn: Binding(get: { Store.global.object(forKey: "ISIMSafariAutoFillPasswords") as? Bool ?? true },
                                                                      set: { Store.set("ISIMSafariAutoFillPasswords", $0); bump += 1 }))
                    .accessibilityIdentifier("settings-safari-autofill")
                NavigationLink(value: Route.safariExtensions([])) { Text("Extensions") }.accessibilityIdentifier("settings-safari-extensions")
            }
            Section("History and Website Data") {
                NavigationLink(value: Route.safariExport) { Text("Export Browsing Data") }.accessibilityIdentifier("settings-safari-export")
            }
        }
        .navigationTitle("Safari")
    }
}

struct SafariExportView: View {
    @State private var kinds: [(String, Bool)] = [("Bookmarks", true), ("History", true), ("Credit Cards", false), ("Extensions", true)]
    @State private var exported = false
    var body: some View {
        List {
            Section {
                ForEach(kinds.indices, id: \.self) { i in
                    Toggle(kinds[i].0, isOn: $kinds[i].1).accessibilityIdentifier("settings-safari-export-\(kinds[i].0)")
                }
            } footer: {
                Text("Browsing data from Safari is exported to a ZIP archive you can import into another browser.")
            }
            Section {
                Button("Save to Files") {
                    let chosen = kinds.filter(\.1).map(\.0)
                    NSLog("Settings: Safari browsing data exported (%@)", chosen.joined(separator: ", "))
                    exported = true
                }
                .accessibilityIdentifier("settings-safari-export-save")
            }
        }
        .navigationTitle("Export Browsing Data")
        .alert("Exported", isPresented: $exported) { Button("OK") {} } message: { Text("Safari Export.zip was saved to Files.") }
    }
}

/// a Safari extension an installed app contains (a content blocker or a web extension)
struct SafariExtension: Hashable { let id: String, name: String, appName: String, kind: String }

@MainActor func safariExtensions() -> [SafariExtension] {
    let kinds = ["com.apple.Safari.content-blocker": "Content Blocker", "com.apple.Safari.web-extension": "Web Extension"]
    var found: [SafariExtension] = []
    for app in installedApps() {
        let plugins = (app.path as NSString).appendingPathComponent("PlugIns")
        for ext in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where ext.hasSuffix(".appex") {
            let info = NSDictionary(contentsOfFile: ((plugins as NSString).appendingPathComponent(ext) as NSString).appendingPathComponent("Info.plist")) as? [String: Any]
            guard let point = (info?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String, let kind = kinds[point],
                  let id = info?["CFBundleIdentifier"] as? String else { continue }
            found.append(SafariExtension(id: id, name: info?["CFBundleDisplayName"] as? String ?? (ext as NSString).deletingPathExtension,
                                         appName: app.name, kind: kind))
        }
    }
    return found
}

struct SafariExtensionsView: View {
    let requested: [String]
    var body: some View {
        let installed = safariExtensions()
        let missing = requested.filter { id in !installed.contains { $0.id == id } }
        List {
            Section {
                if installed.isEmpty {
                    Text("No Extensions Installed").foregroundStyle(.secondary).accessibilityIdentifier("settings-safari-no-extensions")
                }
                ForEach(installed, id: \.self) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(e.name) — \(e.appName)")
                            Text(e.kind).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if requested.contains(e.id) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                    .accessibilityIdentifier("settings-safari-extension-\(e.id)")
                }
            } footer: {
                Text("Safari extensions add functionality to Safari. Extensions come from apps in the App Store.")
            }
            if !missing.isEmpty {
                Section("Requested") {
                    ForEach(missing, id: \.self) { id in
                        LabeledContent(id, value: "Not Installed").accessibilityIdentifier("settings-safari-extension-\(id)")
                    }
                }
            }
        }
        .navigationTitle("Extensions")
    }
}
