// isim Settings: Developer > App Clips Testing > Local Experiences, like the Simulator's: an App Clip experience for
// testing (URL prefix, the App Clip's bundle ID, the card's title, subtitle and call-to-action verb). The home screen
// reads them ($ISIM_DATA/Library/isim/AppClipExperiences.plist, also written by the script command `appclip register`)
// when an invocation URL starts with the prefix. Adapted: no header image picker (`appclip register … |IMAGE` sets one).
import SwiftUI

struct LocalExperience: Hashable {
    var url = "", bundleID = "", title = "", subtitle = "", action = "Open", image = ""
}

@MainActor final class LocalExperienceStore: ObservableObject {
    static let shared = LocalExperienceStore()
    @Published var list = LocalExperiences.load()
    func save(_ l: [LocalExperience]) { list = l; LocalExperiences.save(l) }
}

@MainActor enum LocalExperiences {
    static var file: String { (isimDataDir() as NSString).appendingPathComponent("Library/isim/AppClipExperiences.plist") }
    static func load() -> [LocalExperience] {
        let list = (NSDictionary(contentsOfFile: file)?["experiences"] as? [[String: Any]]) ?? []
        return list.map { d in
            LocalExperience(url: d["url"] as? String ?? "", bundleID: d["bundleID"] as? String ?? "", title: d["title"] as? String ?? "",
                            subtitle: d["subtitle"] as? String ?? "", action: d["action"] as? String ?? "Open", image: d["image"] as? String ?? "")
        }
    }
    static func save(_ list: [LocalExperience]) {
        try? FileManager.default.createDirectory(atPath: (file as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let out: [[String: Any]] = list.map { e in
            var d: [String: Any] = ["url": e.url, "bundleID": e.bundleID, "title": e.title, "subtitle": e.subtitle, "action": e.action]
            if !e.image.isEmpty { d["image"] = e.image }
            return d
        }
        (["experiences": out] as NSDictionary).write(toFile: file, atomically: true)
        NSLog("Settings: %lu local App Clip experience(s)", list.count)
    }
}

struct DeveloperView: View {
    var body: some View {
        List {
            Section("App Clips Testing") {
                NavigationLink("Local Experiences", value: Route.localExperiences).accessibilityIdentifier("settings-local-experiences")
            }
        }
        .navigationTitle("Developer").navigationBarTitleDisplayMode(.inline)
    }
}

struct LocalExperiencesView: View {
    @ObservedObject private var store = LocalExperienceStore.shared
    var body: some View {
        let list = store.list
        List {
            Section {
                NavigationLink("Register Local Experience…", value: Route.registerExperience).accessibilityIdentifier("settings-register-experience")
            }
            if !list.isEmpty {
                Section("Local Experiences") {
                    ForEach(list, id: \.self) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.title.isEmpty ? e.url : e.title)
                            Text("\(e.url) · \(e.bundleID)").font(.footnote).foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("settings-experience-\(e.url)")
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.save(store.list.filter { $0 != e }) }
                        }
                    }
                }
            }
        }
        .onAppear { store.list = LocalExperiences.load() }
        .navigationTitle("Local Experiences").navigationBarTitleDisplayMode(.inline)
    }
}

struct RegisterExperienceView: View {
    @State private var e = LocalExperience()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section("URL Prefix") {
                TextField("https://example.com", text: $e.url).accessibilityIdentifier("experience-url")
            }
            Section("Bundle ID") {
                TextField("com.example.app.Clip", text: $e.bundleID).accessibilityIdentifier("experience-bundle")
            }
            Section("App Clip Card") {
                TextField("Title", text: $e.title).accessibilityIdentifier("experience-title")
                TextField("Subtitle", text: $e.subtitle).accessibilityIdentifier("experience-subtitle")
                Picker("Action", selection: $e.action) {
                    Text("Open").tag("Open"); Text("View").tag("View"); Text("Play").tag("Play")
                }
                .accessibilityIdentifier("experience-action")
            }
        }
        .navigationTitle("Local Experience").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var list = LocalExperiences.load()
                    list.removeAll { $0.url == e.url }
                    list.append(e)
                    LocalExperienceStore.shared.save(list)
                    NSLog("Settings: registered the local experience %@ -> %@", e.url, e.bundleID)
                    dismiss()
                }
                .disabled(e.url.isEmpty || e.bundleID.isEmpty)
                .accessibilityIdentifier("experience-save")
            }
        }
    }
}
