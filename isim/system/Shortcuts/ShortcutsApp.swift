// isim Shortcuts (adapted): the apps' App Shortcuts (AppShortcutsProvider) as tiles, their other actions (discoverable
// App Intents), the voice shortcuts people added to Siri (INVoiceShortcutCenter) and the interactions apps donated
// (Siri Suggestions). Tapping one runs it: the home screen runs the intent in its app and shows the questions and the
// result in the system's run UI (SBSiri.m). What the apps declare comes from the home screen's cache
// (<isim data>/Library/SpringBoard/AppIntents, read from each app). Building your own multi-step shortcuts,
// automations and the gallery are not in isim.
import SwiftUI
import isim_host

// MARK: - what the system knows

struct ShortcutApp: Identifiable, Hashable {
    let id: String, name: String, path: String, icon: String?
    let tileColor: String
    let shortcuts: [AppShortcutTile]
    let actions: [IntentAction]
    var suggestions: [Suggestion]
}
struct AppShortcutTile: Identifiable, Hashable {
    let index: Int, title: String, image: String?, phrases: [String]
    var id: Int { index }
}
struct IntentAction: Identifiable, Hashable { let id: String, title: String, subtitle: String }
struct Suggestion: Identifiable, Hashable { let id: String, title: String }
struct VoiceShortcut: Identifiable, Hashable { let id: String, phrase: String, title: String, app: String, appName: String }

func dataDir() -> String {
    if let d = getenv("ISIM_DATA") { return String(cString: d) }
    return (String(cString: getenv("HOME")) as NSString).appendingPathComponent(".local/share/isim")
}
func phraseText(_ template: String, app: String) -> String {
    var s = template.replacingOccurrences(of: "${applicationName}", with: app)
    while let r = s.range(of: "${"), let e = s[r.upperBound...].firstIndex(of: "}") { s.replaceSubrange(r.lowerBound...e, with: "…") }
    return s
}
func intentTitle(_ i: [String: Any]?) -> String { i?["title"] as? String ?? "" }

@MainActor func loadApps() -> [ShortcutApp] {
    let dir = (dataDir() as NSString).appendingPathComponent("Library/SpringBoard/AppIntents")
    var out: [ShortcutApp] = []
    for f in ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() where f.hasSuffix(".plist") && !f.hasPrefix("list-") {
        guard let m = NSDictionary(contentsOfFile: (dir as NSString).appendingPathComponent(f)) as? [String: Any], let bundle = m["app"] as? String,
              let path = m["appPath"] as? String, FileManager.default.fileExists(atPath: path) else { continue }
        let name = m["appName"] as? String ?? bundle
        let intents = m["intents"] as? [String: [String: Any]] ?? [:]
        let tiles: [AppShortcutTile] = (m["shortcuts"] as? [[String: Any]] ?? []).map { s in
            AppShortcutTile(index: s["index"] as? Int ?? 0, title: s["shortTitle"] as? String ?? s["title"] as? String ?? "", image: s["image"] as? String,
                            phrases: (s["phrases"] as? [String] ?? []).map { phraseText($0, app: name) })
        }
        let inShortcuts = Set((m["shortcuts"] as? [[String: Any]] ?? []).compactMap { $0["intent"] as? String })
        let actions: [IntentAction] = intents.keys.sorted().compactMap { k in
            let i = intents[k] ?? [:]
            guard i["discoverable"] as? Bool ?? true, !(i["widgetConfiguration"] as? Bool ?? false), !inShortcuts.contains(k) else { return nil }
            return IntentAction(id: k, title: intentTitle(i), subtitle: i["description"] as? String ?? "")
        }
        var app = ShortcutApp(id: bundle, name: name, path: path, icon: m["icon"] as? String, tileColor: m["tileColor"] as? String ?? "blue",
                              shortcuts: tiles, actions: actions, suggestions: [])
        app.suggestions = loadSuggestions(bundle)
        if !tiles.isEmpty || !actions.isEmpty || !app.suggestions.isEmpty { out.append(app) }
    }
    return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}
/// interactions the app donated (INInteraction.donate) or Siri handled, newest first, one per intent and value
func loadSuggestions(_ bundle: String) -> [Suggestion] {
    let f = (dataDir() as NSString).appendingPathComponent("Containers/\(bundle)/Library/isim/Interactions.plist")
    let list = (NSDictionary(contentsOfFile: f)?["interactions"] as? [[String: Any]]) ?? []
    var seen = Set<String>(), out: [Suggestion] = []
    for e in list.reversed() {
        guard let id = e["identifier"] as? String, let intent = e["intent"] as? [String: Any] else { continue }
        let t = describeIntent(intent)
        if seen.insert(t).inserted { out.append(Suggestion(id: id, title: t)) }
        if out.count >= 6 { break }
    }
    return out
}
func describeIntent(_ i: [String: Any]) -> String {
    func people(_ k: String) -> String { ((i[k] as? [[String: Any]]) ?? []).compactMap { $0["displayName"] as? String }.joined(separator: ", ") }
    func speak(_ v: Any?) -> String { (v as? [String: Any])?["spokenPhrase"] as? String ?? "" }
    switch i["$class"] as? String ?? "" {
    case "INSendMessageIntent": return "Message \(people("recipients"))" + ((i["content"] as? String).map { ": “\($0)”" } ?? "")
    case "INStartCallIntent": return "Call \(people("contacts"))"
    case "INSearchForMessagesIntent": return "Messages" + (people("senders").isEmpty ? "" : " from \(people("senders"))")
    case "INPlayMediaIntent": return "Play " + (((i["mediaSearch"] as? [String: Any])?["mediaName"] as? String) ?? (((i["mediaItems"] as? [[String: Any]])?.first?["title"] as? String) ?? ""))
    case "INAddTasksIntent": return "Add “\(((i["taskTitles"] as? [Any]) ?? []).map { speak($0) }.joined(separator: ", "))”" + (speak((i["targetTaskList"] as? [String: Any])?["title"]).isEmpty ? "" : " to \(speak((i["targetTaskList"] as? [String: Any])?["title"]))")
    case "INCreateNoteIntent": return "Note “\(speak(i["title"]))”"
    default: return i["$class"] as? String ?? "Shortcut"
    }
}
func loadVoiceShortcuts() -> [VoiceShortcut] {
    let f = (dataDir() as NSString).appendingPathComponent("Library/Siri/VoiceShortcuts.plist")
    return ((NSDictionary(contentsOfFile: f)?["shortcuts"] as? [[String: Any]]) ?? []).compactMap { v in
        let id = (v["identifier"] as? [String: Any])?["uuid"] as? String ?? v["identifier"] as? String ?? ""
        return VoiceShortcut(id: id, phrase: v["invocationPhrase"] as? String ?? "", title: v["title"] as? String ?? "", app: v["app"] as? String ?? "",
                             appName: v["appName"] as? String ?? "")
    }
}

/// asks the home screen to run it (kind: shortcut | intent | voice | donation)
func run(_ app: String, _ kind: String, _ id: String) {
    NSLog("Shortcuts: run %@ %@ of %@", kind, id, app)
    isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "intent-run", "\(app)\u{1f}\(kind)\u{1f}\(id)\u{1f}shortcuts", nil)
}

// MARK: - look

/// the tile colors of ShortcutTileColor (top, bottom of the gradient)
func tileGradient(_ name: String) -> [Color] {
    let c: [String: (Double, Double, Double)] = [
        "red": (1.0, 0.33, 0.33), "orange": (1.0, 0.58, 0.22), "yellow": (0.98, 0.8, 0.2), "lime": (0.55, 0.85, 0.3), "grape": (0.62, 0.36, 0.86),
        "purple": (0.55, 0.38, 0.95), "pink": (1.0, 0.4, 0.62), "teal": (0.2, 0.78, 0.78), "blue": (0.25, 0.55, 1.0), "navy": (0.2, 0.3, 0.75),
        "lightBlue": (0.35, 0.75, 1.0), "gray": (0.55, 0.57, 0.6), "grayBlue": (0.45, 0.55, 0.68), "grayGreen": (0.5, 0.62, 0.55),
        "grayBrown": (0.62, 0.55, 0.5), "tangerine": (1.0, 0.48, 0.25)]
    let (r, g, b) = c[name] ?? c["blue"]!
    return [Color(red: min(1, r + 0.08), green: min(1, g + 0.08), blue: min(1, b + 0.08)), Color(red: r * 0.82, green: g * 0.82, blue: b * 0.82)]
}

struct AppIcon: View {
    let path: String?
    var size: CGFloat = 29
    var body: some View {
        if let p = path, let img = UIImage(contentsOfFile: p) {
            Image(uiImage: img).resizable().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.225))
        } else {
            RoundedRectangle(cornerRadius: size * 0.225).fill(Color.blue).frame(width: size, height: size)
        }
    }
}

struct Tile: View {
    let title: String, symbol: String?, colors: [Color], id: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: symbol ?? "square.stack.3d.up.fill").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                Spacer(minLength: 8)
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(2).multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
    }
}

// MARK: - screens

@main
struct ShortcutsApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

@MainActor final class Library: ObservableObject {
    @Published var apps: [ShortcutApp] = []
    @Published var voice: [VoiceShortcut] = []
    func reload() {
        let a = loadApps(), v = loadVoiceShortcuts()
        if a != apps { apps = a; NSLog("Shortcuts: %ld app(s) with App Shortcuts or actions", a.count) }
        if v != voice { voice = v }
    }
}

struct RootView: View {
    @StateObject var lib = Library()
    @State var path: [String] = []
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !lib.voice.isEmpty {
                        Text("My Shortcuts").font(.title3.weight(.bold)).padding(.top, 8)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(lib.voice) { v in
                                Tile(title: v.title.isEmpty ? v.phrase : v.title, symbol: "waveform", colors: tileGradient("grape"), id: "voice-\(v.phrase)") {
                                    run(v.app, "voice", v.id)
                                }
                            }
                        }
                    }
                    Text("App Shortcuts").font(.title3.weight(.bold)).padding(.top, 8)
                    if lib.apps.isEmpty {
                        Text("No App Shortcuts\nApps you install that offer App Shortcuts appear here.")
                            .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                            .accessibilityIdentifier("shortcuts-empty")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(lib.apps) { a in
                                NavigationLink(value: a.id) {
                                    HStack(spacing: 12) {
                                        AppIcon(path: a.icon)
                                        Text(a.name).foregroundColor(.primary)
                                        Spacer()
                                        Text("\(a.shortcuts.count)").foregroundColor(.secondary)
                                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(UIColor.tertiaryLabel))
                                    }
                                    .padding(.horizontal, 16).frame(height: 52)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("app-shortcuts-\(a.id)")
                                if a.id != lib.apps.last?.id { Divider().padding(.leading, 57) }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemGroupedBackground)))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Shortcuts")
            .navigationDestination(for: String.self) { id in
                if let a = lib.apps.first(where: { $0.id == id }) { AppShortcutsView(app: a) } else { Text("No App Shortcuts").foregroundColor(.secondary) }
            }
        }
        .onOpenURL { url in                                          // shortcuts://app-shortcuts?bundle=ID (ShortcutsLink)
            lib.reload()
            if let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "bundle" })?.value {
                NSLog("Shortcuts: opened for %@", q)
                path = [q]
            }
        }
        .task {
            isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "intents-refresh", "", nil)
            while !Task.isCancelled {
                lib.reload()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

struct AppShortcutsView: View {
    let app: ShortcutApp
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !app.shortcuts.isEmpty {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(app.shortcuts) { s in
                            Tile(title: s.title, symbol: s.image, colors: tileGradient(app.tileColor), id: "shortcut-\(app.id)-\(s.index)") {
                                run(app.id, "shortcut", "\(s.index)")
                            }
                        }
                    }
                    .padding(.top, 8)
                    if let p = app.shortcuts.first?.phrases.first {
                        Text("Use these shortcuts with Siri, Spotlight and here. Try saying “\(p)”.")
                            .font(.footnote).foregroundColor(.secondary)
                            .accessibilityIdentifier("shortcuts-phrase-hint")
                    }
                }
                if !app.suggestions.isEmpty {
                    Text("Siri Suggestions").font(.title3.weight(.bold)).padding(.top, 8)
                    rows(app.suggestions.map { ($0.id, $0.title, "") }, prefix: "suggestion") { run(app.id, "donation", $0) }
                }
                if !app.actions.isEmpty {
                    Text("Actions").font(.title3.weight(.bold)).padding(.top, 8)
                    rows(app.actions.map { ($0.id, $0.title, $0.subtitle) }, prefix: "action") { run(app.id, "intent", $0) }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(app.name)
        .onAppear { NSLog("Shortcuts: %@: %ld App Shortcut(s), %ld action(s), %ld suggestion(s)", app.name, app.shortcuts.count, app.actions.count, app.suggestions.count) }
    }
    func rows(_ items: [(String, String, String)], prefix: String, tap: @escaping (String) -> Void) -> some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                Button { tap(item.0) } label: {
                    HStack(spacing: 12) {
                        AppIcon(path: app.icon, size: 29)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1).foregroundColor(.primary)
                            if !item.2.isEmpty { Text(item.2).font(.caption).foregroundColor(.secondary) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).frame(minHeight: 52)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(prefix)-\(item.0.split(separator: ".").last.map(String.init) ?? item.0)")
                if item.0 != items.last?.0 { Divider().padding(.leading, 57) }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }
}
