// isim Settings: replicates iOS Settings for the settings isim implements. Values go to the
// system (global) preferences domain, which every app reads; the shell tells running apps.
import SwiftUI
import isim_host

// MARK: - Store

@MainActor enum Store {
    static let global = UserDefaults(suiteName: ".GlobalPreferences")!
    static var languages: [String] { global.object(forKey: "AppleLanguages") as? [String] ?? ["en"] }
    static var locale: String? { global.object(forKey: "AppleLocale") as? String }
    static var keyboards: [String] { global.object(forKey: "AppleKeyboards") as? [String] ?? [] }
    /// AppleKeyboards with the built-in keyboards spelled out (iOS default: English (US) + Emoji)
    static var enabledKeyboards: [String] {
        let k = keyboards
        if k.contains(where: { $0.contains("@sw=") }) { return k }
        return ["en_US@sw=QWERTY;hw=Automatic"] + k + ["emoji@sw=Emoji"]
    }
    static func set(_ key: String, _ value: Any?) { global.set(value, forKey: key) }
}

struct InstalledApp: Identifiable, Hashable {
    let id: String, name: String, path: String, iconPath: String?
    let keyboards: [KeyboardExtension]
}
struct KeyboardExtension: Hashable { let id: String, name: String, appName: String }

@MainActor func installedApps() -> [InstalledApp] {
    let dir = getenv("ISIM_APPS").map { String(cString: $0) } ?? (isimDataDir() as NSString).appendingPathComponent("Applications")
    var apps: [InstalledApp] = []
    for name in ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() where name.hasSuffix(".app") {
        let path = (dir as NSString).appendingPathComponent(name)
        guard let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")) as? [String: Any] else { continue }
        let b = Bundle(path: path)
        let display = b?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? b?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? (name as NSString).deletingPathExtension
        var kbs: [KeyboardExtension] = []
        let plugins = (path as NSString).appendingPathComponent("PlugIns")
        for ext in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where ext.hasSuffix(".appex") {
            let einfo = NSDictionary(contentsOfFile: ((plugins as NSString).appendingPathComponent(ext) as NSString).appendingPathComponent("Info.plist")) as? [String: Any]
            let point = (einfo?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String
            if point == "com.apple.keyboard-service", let kid = einfo?["CFBundleIdentifier"] as? String {
                kbs.append(KeyboardExtension(id: kid, name: einfo?["CFBundleDisplayName"] as? String ?? display, appName: display))
            }
        }
        apps.append(InstalledApp(id: info["CFBundleIdentifier"] as? String ?? name, name: display, path: path, iconPath: iconPath(path), keyboards: kbs))
    }
    return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}
func isimDataDir() -> String {
    if let d = getenv("ISIM_DATA") { return String(cString: d) }
    return (String(cString: getenv("HOME")) as NSString).appendingPathComponent(".local/share/isim")
}
func iconPath(_ app: String) -> String? {
    guard let assets = NSDictionary(contentsOfFile: (app as NSString).appendingPathComponent("isim-assets.plist")) as? [String: Any],
          let icons = assets["appIcons"] as? [String: Any], let files = (icons["AppIcon"] ?? icons.values.first) as? [[String: Any]] else { return nil }
    let usable = files.filter { ($0["appearance"] as? String ?? "any") == "any" }
    guard let f = usable.last?["file"] as? String ?? files.first?["file"] as? String else { return nil }
    return (app as NSString).appendingPathComponent(f)
}

// MARK: - App

@main
struct SettingsApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

enum Route: Hashable {
    case accessibility, textSize, voiceOver
    case general, about, keyboard, keyboards, addKeyboard, keyboardDetail(String), language, region, dateTime, timeZone, display, gameCenter, homeScreen
    case app(String), appKeyboards(String), appPaste(String)
    case appPane(String, String, String), appMultiValue(String, String, String)   // Settings.bundle (SettingsBundle.swift)
}

struct SettingsIcon: View {
    let symbol: String, color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(color)
            Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
        }
        .frame(width: 29, height: 29)
    }
}
struct AppIcon: View {
    let app: InstalledApp
    var body: some View {
        if let p = app.iconPath, let img = UIImage(contentsOfFile: p) {
            Image(uiImage: img).resizable().frame(width: 29, height: 29).clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            SettingsIcon(symbol: "square.grid.2x2", color: .gray)
        }
    }
}

struct RootView: View {
    @State private var path: [Route] = RootView.initialPath()
    /// After a language change the system restarts; like iOS, Settings comes back on Language & Region.
    static func initialPath() -> [Route] {
        UserDefaults.standard.bool(forKey: reopenLanguageKey) ? [.general, .language] : []
    }
    @ObservedObject private var system = SystemState.shared
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: Route.general) { Label { Text("General") } icon: { SettingsIcon(symbol: "gear", color: .gray) } }
                        .accessibilityIdentifier("settings-general")
                    NavigationLink(value: Route.display) { Label { Text("Display & Brightness") } icon: { SettingsIcon(symbol: "sun.max", color: .blue) } }
                        .accessibilityIdentifier("settings-display")
                    NavigationLink(value: Route.accessibility) { Label { Text("Accessibility") } icon: { SettingsIcon(symbol: "accessibility", color: .blue) } }
                        .accessibilityIdentifier("settings-accessibility")
                    NavigationLink(value: Route.homeScreen) { Label { Text("Home Screen & App Library") } icon: { SettingsIcon(symbol: "square.grid.2x2", color: .indigo) } }
                        .accessibilityIdentifier("settings-homescreen")
                }
                Section {
                    NavigationLink(value: Route.gameCenter) { Label { Text("Game Center") } icon: { SettingsIcon(symbol: "gamecontroller", color: .pink) } }
                        .accessibilityIdentifier("settings-gamecenter")
                }
                let apps = installedApps()
                if !apps.isEmpty {
                    Section("Apps") {
                        ForEach(apps) { app in
                            NavigationLink(value: Route.app(app.id)) { Label { Text(app.name) } icon: { AppIcon(app: app) } }
                                .accessibilityIdentifier("settings-app-\(app.id)")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Route.self) { route in destination(route) }
            .onAppear { UserDefaults.standard.removeObject(forKey: reopenLanguageKey) }
            .onOpenURL { url in
                // app-settings:<bundle id> opens the app's page, as on iOS
                let s = url.absoluteString
                if s.hasPrefix("app-settings:") {
                    let id = String(s.dropFirst("app-settings:".count))
                    path = id.isEmpty ? [] : [.app(id)]
                }
            }
        }
        .overlay { if system.settingLanguage { SettingLanguageCover() } }
    }
    @ViewBuilder func destination(_ r: Route) -> some View {
        switch r {
        case .accessibility: AccessibilitySettingsView()
        case .textSize: TextSizeView()
        case .voiceOver: VoiceOverSettingsView()
        case .general: GeneralView()
        case .about: AboutView()
        case .keyboard: KeyboardView()
        case .keyboards: KeyboardsView()
        case .addKeyboard: AddKeyboardView()
        case .keyboardDetail(let id): KeyboardDetailView(id: id)
        case .language: LanguageView()
        case .region: RegionView()
        case .dateTime: DateTimeView()
        case .timeZone: TimeZoneView()
        case .display: DisplayView()
        case .homeScreen: HomeScreenSettingsView()
        case .gameCenter: GameCenterView()
        case .app(let id): AppSettingsView(id: id)
        case .appKeyboards(let id): AppKeyboardsView(id: id)
        case .appPaste(let id): PasteAccessView(id: id)
        case .appPane(let bundle, let file, let id): ChildPaneView(bundlePath: bundle, file: file, appID: id)
        case .appMultiValue(let bundle, let file, let key): MultiValueRouteView(bundlePath: bundle, file: file, key: key)
        }
    }
}

// MARK: - General

struct GeneralView: View {
    var body: some View {
        List {
            Section { NavigationLink("About", value: Route.about) }
            Section {
                NavigationLink("Date & Time", value: Route.dateTime)
                NavigationLink("Keyboard", value: Route.keyboard).accessibilityIdentifier("settings-keyboard")
                NavigationLink("Language & Region", value: Route.language).accessibilityIdentifier("settings-language")
            }
        }
        .navigationTitle("General").navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: UIDevice.current.name)
                LabeledContent("iOS Version", value: "\(UIDevice.current.systemVersion) (isim)")
                LabeledContent("Model Name", value: UIDevice.current._isim_deviceName)
            }
            Section {
                LabeledContent("Applications", value: "\(installedApps().count)")
            } footer: { Text("isim emulates the iOS \(UIDevice.current.systemVersion) API on Linux. It is not Apple's iOS.") }
        }
        .navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Keyboard

let builtinKeyboard = "English (US)"
@MainActor func allKeyboards() -> [KeyboardExtension] { installedApps().flatMap { $0.keyboards } }
/// isim's built-in keyboards (AppleKeyboards entries)
let systemKeyboards: [(id: String, name: String)] = [
    ("en_US@sw=QWERTY;hw=Automatic", "English (US)"), ("pt_BR@sw=QWERTY;hw=Automatic", "Portuguese (Brazil)"),
    ("es_ES@sw=QWERTY-Spanish;hw=Automatic", "Spanish (Spain)"), ("fr_FR@sw=AZERTY;hw=Automatic", "French (France)"),
    ("de_DE@sw=QWERTZ;hw=Automatic", "German (Germany)"), ("emoji@sw=Emoji", "Emoji"),
]
func systemKeyboardName(_ id: String) -> String? { systemKeyboards.first { $0.id.split(separator: "@").first == id.split(separator: "@").first }?.name }

struct KeyboardView: View {
    @State private var bump = 0
    func pref(_ key: String) -> Binding<Bool> {
        Binding(get: { Store.global.object(forKey: key) as? Bool ?? true }, set: { Store.set(key, $0); bump += 1 })
    }
    var body: some View {
        let count = Store.enabledKeyboards.count
        let autoCap = Store.global.object(forKey: "KeyboardAutocapitalization") as? Bool ?? true
        List {
            Section {
                NavigationLink(value: Route.keyboards) { LabeledContent("Keyboards", value: "\(count)") }
                    .accessibilityIdentifier("settings-keyboards")
            }
            Section("All Keyboards") {
                Toggle("Auto-Capitalization", isOn: Binding(get: { autoCap }, set: { Store.set("KeyboardAutocapitalization", $0); bump += 1 }))
                Toggle("Auto-Correction", isOn: pref("KeyboardAutocorrection")).accessibilityIdentifier("settings-autocorrection")
                Toggle("Check Spelling", isOn: pref("KeyboardCheckSpelling")).accessibilityIdentifier("settings-check-spelling")
                Toggle("Predictive", isOn: pref("KeyboardPrediction")).accessibilityIdentifier("settings-predictive")
            }
            Section {
                Toggle("Enable Dictation", isOn: .constant(false)).disabled(true)
            } footer: { Text("Dictation is not available on isim.") }
        }
        .navigationTitle("Keyboard").navigationBarTitleDisplayMode(.inline)
    }
}

struct KeyboardsView: View {
    var body: some View {
        let all = allKeyboards()
        List {
            Section {
                ForEach(Store.enabledKeyboards, id: \.self) { id in
                    let kb = all.first { $0.id == id }
                    NavigationLink(value: Route.keyboardDetail(id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(systemKeyboardName(id) ?? kb?.name ?? id)
                            if let app = kb?.appName { Text(app).font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            Section {
                NavigationLink("Add New Keyboard…", value: Route.addKeyboard).accessibilityIdentifier("settings-add-keyboard")
            }
        }
        .navigationTitle("Keyboards").navigationBarTitleDisplayMode(.inline)
    }
}

struct AddKeyboardView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let available = allKeyboards().filter { !Store.keyboards.contains($0.id) }
        let enabled = Store.enabledKeyboards
        List {
            Section("Suggested Keyboards") {
                ForEach(systemKeyboards.filter { !enabled.contains($0.id) }, id: \.id) { kb in
                    Button { Store.set("AppleKeyboards", Store.enabledKeyboards + [kb.id]); dismiss() } label: { Text(kb.name).foregroundStyle(.primary) }
                        .accessibilityIdentifier("settings-add-\(kb.id.split(separator: "@").first ?? "")")
                }
            }
            Section("Third-Party Keyboards") {
                if available.isEmpty { Text("No other keyboards are installed.").foregroundStyle(.secondary) }
                ForEach(available, id: \.id) { kb in
                    Button {
                        Store.set("AppleKeyboards", Store.enabledKeyboards + [kb.id])
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kb.name).foregroundStyle(.primary)
                            Text(kb.appName).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings-add-\(kb.id)")
                }
            }
        }
        .navigationTitle("Add New Keyboard").navigationBarTitleDisplayMode(.inline)
    }
}

struct KeyboardDetailView: View {
    let id: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let kb = allKeyboards().first { $0.id == id }
        List {
            Section {
                if systemKeyboardName(id) == nil { Toggle("Allow Full Access", isOn: .constant(false)).disabled(true) }
            } footer: { Text(systemKeyboardName(id) == nil ? "isim does not grant keyboards Full Access (network and shared container access)." : "") }
            Section {
                Button("Remove Keyboard", role: .destructive) {
                    Store.set("AppleKeyboards", Store.enabledKeyboards.filter { $0 != id })
                    dismiss()
                }
            }
        }
        .navigationTitle(systemKeyboardName(id) ?? kb?.name ?? id).navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Language & Region

let languageOptions: [(String, String)] = [
    ("en", "English"), ("en-GB", "English (UK)"), ("pt-BR", "Português (Brasil)"), ("pt-PT", "Português (Portugal)"),
    ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"), ("it", "Italiano"), ("nl", "Nederlands"),
    ("ja", "日本語"), ("ko", "한국어"), ("zh-Hans", "简体中文"), ("ar", "العربية"), ("he", "עברית"),
]
let regionOptions: [(String, String)] = [
    ("en_US", "United States"), ("en_GB", "United Kingdom"), ("pt_BR", "Brazil"), ("pt_PT", "Portugal"), ("es_ES", "Spain"),
    ("es_MX", "Mexico"), ("fr_FR", "France"), ("de_DE", "Germany"), ("it_IT", "Italy"), ("ja_JP", "Japan"), ("ko_KR", "South Korea"),
]

let reopenLanguageKey = "_ISIMReopenLanguage"

/// "Setting Language…" covers the whole screen while the system restarts, as on iOS.
@MainActor final class SystemState: ObservableObject {
    static let shared = SystemState()
    @Published var settingLanguage = false
}
struct SettingLanguageCover: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white)
                Text("Setting Language…").foregroundStyle(.white)
            }
        }
    }
}

struct LanguageView: View {
    var body: some View {
        let lang = Store.languages.first ?? "en"
        let region = Store.locale ?? Locale.current.identifier
        List {
            Section {
                ForEach(languageOptions, id: \.0) { opt in
                    Button {
                        guard opt.0 != lang else { return }
                        Store.set("AppleLanguages", [opt.0])
                        guard getenv("ISIM_CLIENT_SOCK") != nil else { return }      // plain `isim run`: no system to restart
                        // as on iOS, the system UI restarts in the new language: apps quit, the home screen and Settings relaunch
                        UserDefaults.standard.set(true, forKey: reopenLanguageKey)
                        SystemState.shared.settingLanguage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            isim_shell_request(Int32(ISIM_SHELL_RESTART_SYSTEM), nil, nil, nil)
                        }
                    } label: {
                        HStack {
                            Text(opt.1).foregroundStyle(.primary)
                            Spacer()
                            if opt.0 == lang { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                    }
                    .accessibilityIdentifier("settings-lang-\(opt.0)")
                }
            } header: { Text("Preferred Languages") } footer: { Text("Apps and websites use the first language in this list.") }
            Section {
                NavigationLink(value: Route.region) {
                    LabeledContent("Region", value: regionOptions.first { $0.0 == region }?.1 ?? region)
                }
            }
        }
        .navigationTitle("Language & Region").navigationBarTitleDisplayMode(.inline)
    }
}

struct RegionView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let current = Store.locale
        List {
            ForEach(regionOptions, id: \.0) { opt in
                Button {
                    Store.set("AppleLocale", opt.0)
                    isim_shell_request(Int32(ISIM_SHELL_TERMINATE_OTHERS), nil, nil, nil)
                    dismiss()
                } label: {
                    HStack {
                        Text(opt.1).foregroundStyle(.primary)
                        Spacer()
                        if opt.0 == current { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
            }
        }
        .navigationTitle("Region").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Date & Time

let timeZoneOptions = ["America/Los_Angeles", "America/New_York", "America/Sao_Paulo", "Europe/London", "Europe/Lisbon",
                       "Europe/Berlin", "Asia/Tokyo", "Australia/Sydney", "UTC"]

struct DateTimeView: View {
    @State private var bump = 0
    var body: some View {
        let h24 = Store.global.bool(forKey: "AppleICUForce24HourTime")
        let tz = Store.global.object(forKey: "TimeZone") as? String
        List {
            Section {
                Toggle("24-Hour Time", isOn: Binding(get: { h24 }, set: { Store.set("AppleICUForce24HourTime", $0); bump += 1 }))
                    .accessibilityIdentifier("settings-24h")
            }
            Section {
                Toggle("Set Automatically", isOn: Binding(get: { tz == nil }, set: { auto in Store.set("TimeZone", auto ? nil : TimeZone.current.identifier); bump += 1 }))
                    .accessibilityIdentifier("settings-auto-tz")
                if tz != nil {
                    NavigationLink(value: Route.timeZone) { LabeledContent("Time Zone", value: tz ?? "") }
                }
            } footer: { Text("Automatic uses the Linux host's time zone.") }
        }
        .navigationTitle("Date & Time").navigationBarTitleDisplayMode(.inline)
    }
}

struct TimeZoneView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            ForEach(timeZoneOptions, id: \.self) { z in
                Button {
                    Store.set("TimeZone", z)
                    dismiss()
                } label: {
                    HStack { Text(z.replacingOccurrences(of: "_", with: " ")).foregroundStyle(.primary); Spacer()
                        if z == Store.global.object(forKey: "TimeZone") as? String { Image(systemName: "checkmark").foregroundStyle(.tint) } }
                }
            }
        }
        .navigationTitle("Time Zone").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Game Center

/// isim's Game Center is local: games' scores and achievements stay on this device.
struct GameCenterView: View {
    @State private var signedIn = (Store.global.object(forKey: "ISIMGameCenterSignedIn") as? Bool) ?? true
    @State private var nickname = Store.global.string(forKey: "ISIMGameCenterNickname") ?? "Player"
    var body: some View {
        List {
            Section {
                Toggle("Game Center", isOn: Binding(get: { signedIn }, set: { signedIn = $0; Store.set("ISIMGameCenterSignedIn", $0) }))
                    .accessibilityIdentifier("settings-gamecenter-toggle")
            } footer: {
                Text("On isim, Game Center is local: games sign in as this player, and their leaderboard scores and achievements are kept on this device.")
            }
            if signedIn {
                Section("Profile") {
                    TextField("Nickname", text: Binding(get: { nickname }, set: { nickname = $0; Store.set("ISIMGameCenterNickname", $0) }))
                        .accessibilityIdentifier("settings-gamecenter-nickname")
                }
            }
        }
        .navigationTitle("Game Center").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Display & Brightness

struct DisplayView: View {
    @State private var bump = 0
    var body: some View {
        let dark = (Store.global.object(forKey: "AppleInterfaceStyle") as? String) == "Dark"
        List {
            Section("Appearance") {
                HStack(spacing: 40) {
                    Spacer()
                    appearanceOption("Light", dark: false, selected: !dark, id: "settings-light") { Store.set("AppleInterfaceStyle", nil); bump += 1 }
                    appearanceOption("Dark", dark: true, selected: dark, id: "settings-dark") { Store.set("AppleInterfaceStyle", "Dark"); bump += 1 }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Display & Brightness").navigationBarTitleDisplayMode(.inline)
    }
    func appearanceOption(_ title: LocalizedStringKey, dark: Bool, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(dark ? Color.black : Color(white: 0.95))
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.6)).frame(width: 40, height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.4)).frame(width: 40, height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.4)).frame(width: 40, height: 6)
                    }
                }
                .frame(width: 70, height: 120)
                Text(title).foregroundStyle(.primary)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.blue : Color.gray)
            }
        }
        .accessibilityIdentifier(id)
    }
}

// MARK: - Home Screen & App Library

/// Newly Downloaded Apps: Add to Home Screen / App Library Only (the home screen reads SBNewAppsToHomeScreen)
struct HomeScreenSettingsView: View {
    @State private var bump = 0
    var body: some View {
        let toHome = (Store.global.object(forKey: "SBNewAppsToHomeScreen") as? Bool) ?? true
        List {
            Section("Newly Downloaded Apps") {
                Button { Store.set("SBNewAppsToHomeScreen", nil); bump += 1 } label: {
                    HStack { Text("Add to Home Screen").foregroundStyle(.primary); Spacer(); if toHome { Image(systemName: "checkmark").foregroundStyle(.blue) } }
                }.accessibilityIdentifier("settings-newapps-home")
                Button { Store.set("SBNewAppsToHomeScreen", false); bump += 1 } label: {
                    HStack { Text("App Library Only").foregroundStyle(.primary); Spacer(); if !toHome { Image(systemName: "checkmark").foregroundStyle(.blue) } }
                }.accessibilityIdentifier("settings-newapps-library")
            }
        }
        .navigationTitle("Home Screen & App Library").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Per-app pages

struct AppSettingsView: View {
    let id: String
    var body: some View {
        let app = installedApps().first { $0.id == id }
        if let app = app, app.keyboards.isEmpty, let bundle = settingsBundlePath(app) {
            AppBundleSettingsView(app: app, bundlePath: bundle)       // the app's Settings.bundle
        } else {
        List {
            if let app = app {
                AppAccessSection(app: app)
            } else {
                Section { Text("No settings for this app.").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(app?.name ?? id).navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// "Allow <app> to Access": Paste from Other Apps (every app) and the app's keyboards
struct AppAccessSection: View {
    let app: InstalledApp
    var body: some View {
        Section("Allow \(app.name) to Access") {
            NavigationLink(value: Route.appPaste(app.id)) {
                LabeledContent {
                    Text(pasteAccessTitle(AppPreferences(appID: app.id).value("_ISIMPrivacy.paste") as? String))
                } label: {
                    Label { Text("Paste from Other Apps") } icon: { SettingsIcon(symbol: "doc.on.clipboard", color: .blue) }
                }
            }
            .accessibilityIdentifier("settings-app-paste")
            if !app.keyboards.isEmpty {
                NavigationLink(value: Route.appKeyboards(app.id)) {
                    Label { Text("Keyboards") } icon: { SettingsIcon(symbol: "keyboard", color: .gray) }
                }
                .accessibilityIdentifier("settings-app-keyboards")
            }
        }
    }
}
func pasteAccessTitle(_ v: String?) -> String { v == "deny" ? "Deny" : v == "allow" ? "Allow" : "Ask" }
/// the app's "_ISIMPrivacy.paste" (UIPasteboard reads it): ask (default), deny, allow
struct PasteAccessView: View {
    let id: String
    @StateObject private var prefs: AppPreferences
    init(id: String) { self.id = id; _prefs = StateObject(wrappedValue: AppPreferences(appID: id)) }
    var body: some View {
        let current = prefs.value("_ISIMPrivacy.paste") as? String ?? "ask"
        List {
            Section {
                ForEach(["ask", "deny", "allow"], id: \.self) { v in
                    Button { prefs.set("_ISIMPrivacy.paste", v) } label: {
                        HStack { Text(pasteAccessTitle(v)).foregroundStyle(.primary); Spacer(); if current == v { Image(systemName: "checkmark").foregroundStyle(.blue) } }
                    }
                    .accessibilityIdentifier("settings-paste-\(v)")
                }
            } footer: {
                Text("Allow this app to paste content copied from other apps.")
            }
        }
        .navigationTitle("Paste from Other Apps").navigationBarTitleDisplayMode(.inline)
    }
}

struct AppKeyboardsView: View {
    let id: String
    @State private var bump = 0
    var body: some View {
        let app = installedApps().first { $0.id == id }
        List {
            Section {
                ForEach(app?.keyboards ?? [], id: \.id) { kb in
                    Toggle(kb.name, isOn: Binding(get: { Store.keyboards.contains(kb.id) }, set: { on in
                        Store.set("AppleKeyboards", on ? Store.enabledKeyboards + [kb.id] : Store.enabledKeyboards.filter { $0 != kb.id }); bump += 1
                    }))
                    .accessibilityIdentifier("settings-enable-\(kb.id)")
                    Toggle("Allow Full Access", isOn: .constant(false)).disabled(true)
                }
            }
        }
        .navigationTitle("Keyboards").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Accessibility

/// isim keys in the global domain (UIKit reads them): ISIMVoiceOver, ISIMContentSizeCategory, ISIMBoldText,
/// ISIMIncreaseContrast, ISIMReduceMotion, ISIMReduceTransparency, ISIMDifferentiateWithoutColor
let contentSizeCategories = ["UICTContentSizeCategoryXS", "UICTContentSizeCategoryS", "UICTContentSizeCategoryM", "UICTContentSizeCategoryL",
                             "UICTContentSizeCategoryXL", "UICTContentSizeCategoryXXL", "UICTContentSizeCategoryXXXL",
                             "UICTContentSizeCategoryAccessibilityM", "UICTContentSizeCategoryAccessibilityL", "UICTContentSizeCategoryAccessibilityXL",
                             "UICTContentSizeCategoryAccessibilityXXL", "UICTContentSizeCategoryAccessibilityXXXL"]
@MainActor func boolPref(_ key: String, _ bump: Binding<Int>) -> Binding<Bool> {
    Binding(get: { Store.global.bool(forKey: key) }, set: { Store.set(key, $0); bump.wrappedValue += 1 })
}
struct AccessibilitySettingsView: View {
    @State private var bump = 0
    var body: some View {
        let vo = Store.global.bool(forKey: "ISIMVoiceOver")
        List {
            Section("Vision") {
                NavigationLink(value: Route.voiceOver) { LabeledContent("VoiceOver", value: vo ? "On" : "Off") }
                    .accessibilityIdentifier("settings-voiceover")
                NavigationLink("Display & Text Size", value: Route.textSize).accessibilityIdentifier("settings-text-size")
            }
            Section("Motion") {
                Toggle("Reduce Motion", isOn: boolPref("ISIMReduceMotion", $bump)).accessibilityIdentifier("settings-reduce-motion")
            }
            Section {
                Toggle("Switch Control", isOn: boolPref("ISIMSwitchControl", $bump)).accessibilityIdentifier("settings-switch-control")
            } header: { Text("Physical and Motor") } footer: {
                Text("Switch Control highlights items in turn; the script commands switchcontrol next / select / auto move and select (isim has no switch hardware).")
            }
        }
        .navigationTitle("Accessibility").navigationBarTitleDisplayMode(.inline)
    }
}
struct VoiceOverSettingsView: View {
    @State private var bump = 0
    var body: some View {
        List {
            Section {
                Toggle("VoiceOver", isOn: boolPref("ISIMVoiceOver", $bump)).accessibilityIdentifier("settings-voiceover-toggle")
            } footer: { Text("VoiceOver speaks items on the screen (through the host's espeak-ng): tap to select an item, double-tap to activate it, swipe left or right to move between items.") }
        }
        .navigationTitle("VoiceOver").navigationBarTitleDisplayMode(.inline)
    }
}
struct TextSizeView: View {
    @State private var bump = 0
    var body: some View {
        let current = contentSizeCategories.firstIndex(of: Store.global.string(forKey: "ISIMContentSizeCategory") ?? "") ?? 3
        let larger = Store.global.bool(forKey: "ISIMLargerAccessibilitySizes") || current > 6
        let maxIndex = larger ? contentSizeCategories.count - 1 : 6
        List {
            Section {
                Toggle("Bold Text", isOn: boolPref("ISIMBoldText", $bump)).accessibilityIdentifier("settings-bold-text")
            }
            Section {
                VStack(spacing: 12) {
                    Text("Apps that support Dynamic Type will adjust to your preferred reading size below.").font(.footnote).foregroundStyle(.secondary)
                    HStack {
                        Button("A") { set(max(0, current - 1)) }.font(.system(size: 14)).accessibilityIdentifier("settings-text-smaller")
                        Slider(value: Binding(get: { Double(current) }, set: { set(Int($0.rounded())) }), in: 0...Double(maxIndex), step: 1)
                            .accessibilityIdentifier("settings-text-slider")
                        Button("A") { set(min(maxIndex, current + 1)) }.font(.system(size: 24)).accessibilityIdentifier("settings-text-larger")
                    }
                }
                Toggle("Larger Accessibility Sizes", isOn: boolPref("ISIMLargerAccessibilitySizes", $bump)).accessibilityIdentifier("settings-larger-sizes")
            } header: { Text("Larger Text") }
            Section {
                Toggle("Increase Contrast", isOn: boolPref("ISIMIncreaseContrast", $bump)).accessibilityIdentifier("settings-increase-contrast")
                Toggle("Reduce Transparency", isOn: boolPref("ISIMReduceTransparency", $bump)).accessibilityIdentifier("settings-reduce-transparency")
                Toggle("Differentiate Without Color", isOn: boolPref("ISIMDifferentiateWithoutColor", $bump))
            }
        }
        .navigationTitle("Display & Text Size").navigationBarTitleDisplayMode(.inline)
    }
    func set(_ i: Int) { Store.set("ISIMContentSizeCategory", contentSizeCategories[i]); bump += 1 }
}
