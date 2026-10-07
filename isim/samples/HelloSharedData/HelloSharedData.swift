// HelloSharedData: plural localization (String Catalog plural variations and substitutions, .stringsdict with a
// zero rule), LocalizedStringResource, app group containers, iCloud key-value storage (local simulation) with
// external-change notifications, and NotificationQueue coalescing.
import SwiftUI

let groupID = "group.dev.isim.samples.shared"
extension Notification.Name { static let ping = Notification.Name("HelloSharedData.ping") }

final class Model: ObservableObject {
    @Published var plurals: [(String, String)] = []
    @Published var groupText = ""
    @Published var groupDefaults = ""
    @Published var kvsLaunches: Int64 = 0
    @Published var kvsColor = "-"
    @Published var kvsChange = "none"
    @Published var ubiquity = ""
    @Published var queueReport = ""
    var pings = 0
    var observers: [NSObjectProtocol] = []

    init() {
        for n in [0, 1, 2, 5, 21] {
            plurals.append(("files-\(n)", String(localized: "\(n) files")))
        }
        plurals.append(("photos", String(localized: "\(1) photos in \(3) albums")))
        for n in [0, 1, 3, 11] {
            plurals.append(("songs-\(n)", String.localizedStringWithFormat(NSLocalizedString("%d songs", tableName: "Songs", comment: ""), n)))
        }
        let welcome: LocalizedStringResource = "Welcome"
        plurals.append(("welcome", String(localized: welcome)))
        for (id, text) in plurals { print("plural \(id): \(text)") }

        // app group container + shared defaults
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let file = url.appendingPathComponent("shared.txt")
            let previous = (try? String(contentsOf: file, encoding: .utf8)) ?? "nothing"
            try? "written by HelloSharedData".write(to: file, atomically: true, encoding: .utf8)
            groupText = "previous: \(previous)"
            print("group container \(url.path) previous=\(previous)")
        }
        let shared = UserDefaults(suiteName: groupID)
        shared?.set((shared?.integer(forKey: "opens") ?? 0) + 1, forKey: "opens")
        groupDefaults = "opens \(shared?.integer(forKey: "opens") ?? 0)"
        print("group defaults \(groupDefaults)")

        // iCloud key-value store (local)
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(kvs.longLong(forKey: "launches") + 1, forKey: "launches")
        kvs.synchronize()
        kvsLaunches = kvs.longLong(forKey: "launches")
        kvsColor = kvs.string(forKey: "color") ?? "-"
        print("kvs launches \(kvsLaunches) color \(kvsColor)")
        observers.append(NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                                object: kvs, queue: .main) { [weak self] note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? -1
            self?.kvsColor = kvs.string(forKey: "color") ?? "-"
            self?.kvsChange = "\(keys.joined(separator: ",")) reason \(reason)"
            print("kvs external change keys=\(keys) reason=\(reason) color=\(self?.kvsColor ?? "")")
        })
        let ubiq = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        ubiquity = ubiq.map { "iCloud " + $0.lastPathComponent } ?? "no iCloud account"
        print("ubiquity \(ubiquity) token \(FileManager.default.ubiquityIdentityToken != nil)")

        // NotificationQueue: three ASAP posts coalesce into one; .now posts immediately
        observers.append(NotificationCenter.default.addObserver(forName: .ping, object: nil, queue: nil) { [weak self] _ in
            self?.pings += 1
        })
        let q = NotificationQueue.default
        for _ in 0..<3 { q.enqueue(Notification(name: .ping, object: nil), postingStyle: .asap) }
        let afterEnqueue = pings
        q.enqueue(Notification(name: Notification.Name("other"), object: nil), postingStyle: .now)
        q.enqueue(Notification(name: .ping, object: self), postingStyle: .whenIdle, coalesceMask: [], forModes: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.queueReport = "pings \(self.pings) (before run loop \(afterEnqueue))"
            print("notification queue \(self.queueReport)")
        }
    }
}

struct ContentView: View {
    @StateObject var model = Model()
    var body: some View {
        NavigationStack {
            List {
                Section("Plurals") {
                    ForEach(model.plurals, id: \.0) { item in
                        Text(item.1).accessibilityIdentifier(item.0)
                    }
                }
                Section("App group") {
                    Text(model.groupText).accessibilityIdentifier("group-file")
                    Text(model.groupDefaults).accessibilityIdentifier("group-defaults")
                }
                Section("iCloud (local)") {
                    Text("launches \(model.kvsLaunches)").accessibilityIdentifier("kvs-launches")
                    Text("color \(model.kvsColor)").accessibilityIdentifier("kvs-color")
                    Text("change \(model.kvsChange)").accessibilityIdentifier("kvs-change")
                    Text(model.ubiquity).accessibilityIdentifier("ubiquity")
                }
                Section("NotificationQueue") {
                    Text(model.queueReport).accessibilityIdentifier("queue")
                }
            }
            .navigationTitle("Shared Data")
        }
    }
}

@main struct HelloSharedDataApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
