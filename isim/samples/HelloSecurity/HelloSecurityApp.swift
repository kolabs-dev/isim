// Sample: security, persistence and system services on isim — CryptoKit (hash, HMAC, AES-GCM), the keychain
// (SecItem*), SQLite3, os.Logger, Face ID (LocalAuthentication) and a local notification (UserNotifications).
import SwiftUI
import CryptoKit
import Security
import SQLite3
import LocalAuthentication
import UserNotifications
import os

let log = Logger(subsystem: "dev.isim.samples.HelloSecurity", category: "demo")

@main
struct HelloSecurityApp: App {
    @State private var notifier = Notifier()
    var body: some Scene { WindowGroup { ContentView(notifier: notifier) } }
}

/// receives notification callbacks (foreground presentation and taps)
final class Notifier: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var opened = ""
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("willPresent \(notification.request.identifier)")
        return [.banner, .sound, .list]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        print("opened \(id) action \(response.actionIdentifier == UNNotificationDefaultActionIdentifier ? "default" : response.actionIdentifier)")
        DispatchQueue.main.async { self.opened = id }
        completionHandler()
    }
}

struct ContentView: View {
    @ObservedObject var notifier: Notifier
    @State private var crypto = ""
    @State private var keychain = "—"
    @State private var notes: [String] = []
    @State private var unlocked = false
    @State private var authMessage = "Locked"
    @State private var notifyStatus = ""

    var body: some View {
        NavigationStack {
            List {
                Section("CryptoKit") {
                    Text(crypto).font(.system(.footnote, design: .monospaced)).accessibilityIdentifier("crypto")
                    Button("Run crypto") { runCrypto() }.accessibilityIdentifier("runCrypto")
                }
                Section("Keychain") {
                    Text("Token: \(keychain)").accessibilityIdentifier("token")
                    HStack {
                        Button("Save") { saveToken() }.accessibilityIdentifier("save").buttonStyle(.borderless)
                        Spacer()
                        Button("Load") { loadToken() }.accessibilityIdentifier("load").buttonStyle(.borderless)
                        Spacer()
                        Button("Delete") { deleteToken() }.accessibilityIdentifier("delete").buttonStyle(.borderless)
                    }
                }
                Section("SQLite") {
                    Text("\(notes.count) notes: \(notes.joined(separator: ", "))").accessibilityIdentifier("notes")
                    Button("Add note") { addNote() }.accessibilityIdentifier("addNote")
                }
                Section("Face ID") {
                    Label(authMessage, systemImage: unlocked ? "lock.open" : "lock").accessibilityIdentifier("auth")
                    Button("Unlock") { unlock() }.accessibilityIdentifier("unlock")
                }
                Section("Notifications") {
                    Text(notifyStatus.isEmpty ? "No notification yet" : notifyStatus).accessibilityIdentifier("notifyStatus")
                    if !notifier.opened.isEmpty { Text("Opened \(notifier.opened)").accessibilityIdentifier("opened") }
                    Button("Notify in 3 seconds") { notify() }.accessibilityIdentifier("notify")
                }
            }
            .navigationTitle("Security")
        }
        .onAppear { notes = Notes.shared.all() }
    }

    func runCrypto() {
        let digest = SHA256.hash(data: Data("hello".utf8))
        let key = SymmetricKey(size: .bits256)
        let mac = HMAC<SHA256>.authenticationCode(for: Data("hello".utf8), using: key)
        let ok = HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: Data("hello".utf8), using: key)
        var roundTrip = "failed"
        if let box = try? AES.GCM.seal(Data("secret message".utf8), using: key),
           let opened = try? AES.GCM.open(box, using: key) { roundTrip = String(decoding: opened, as: UTF8.self) }
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        crypto = "sha256 \(hex.prefix(16))…\nhmac \(ok ? "valid" : "invalid")\naes-gcm \(roundTrip)"
        print("crypto \(hex) hmac=\(ok) aes=\(roundTrip)")
        log.info("crypto done, digest \(hex, privacy: .public)")
    }

    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: "dev.isim.samples.HelloSecurity",
                                kSecAttrAccount as String: "demo-user"]
    func saveToken() {
        let token = "tok-\(Int.random(in: 1000...9999))"
        var add = query
        add[kSecValueData as String] = Data(token.utf8)
        var status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(token.utf8)] as CFDictionary)
        }
        keychain = status == errSecSuccess ? "saved" : "error \(status)"
        print("keychain save \(status)")
        log.notice("saved a token \(token)")       // private: shows <private> in the log
    }
    func loadToken() {
        var q = query
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data { keychain = String(decoding: data, as: UTF8.self) }
        else { keychain = status == errSecItemNotFound ? "not found" : "error \(status)" }
        print("keychain load \(status) \(keychain.hasPrefix("tok-") ? "token" : keychain)")
    }
    func deleteToken() {
        let status = SecItemDelete(query as CFDictionary)
        keychain = status == errSecSuccess ? "deleted" : "not found"
        print("keychain delete \(status)")
    }

    func addNote() {
        Notes.shared.add("note \(notes.count + 1)")
        notes = Notes.shared.all()
        print("sqlite \(notes.count) notes")
    }

    func unlock() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authMessage = "Unavailable: \(error?.localizedDescription ?? "?")"; return
        }
        print("biometry \(context.biometryType == .faceID ? "faceID" : context.biometryType == .touchID ? "touchID" : "none")")
        Task { @MainActor in
            do {
                let ok = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock your notes")
                unlocked = ok; authMessage = ok ? "Unlocked" : "Locked"
            } catch let e as LAError where e.code == .userCancel {
                authMessage = "Canceled"
            } catch {
                authMessage = "Failed: \(error.localizedDescription)"
            }
            print("auth \(authMessage)")
            log.info("authentication result: \(authMessage, privacy: .public)")
        }
    }

    func notify() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { notifyStatus = "Notifications not allowed"; print("notify denied"); return }
            let content = UNMutableNotificationContent()
            content.title = "Security demo"
            content.body = "Your notes were backed up."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "backup", content: content,
                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
            do {
                try await center.add(request)
                let pending = await center.pendingNotificationRequests()
                notifyStatus = "Scheduled (\(pending.count) pending)"
                print("notify scheduled \(pending.map(\.identifier))")
            } catch { notifyStatus = "Error \(error)" }
        }
    }
}

/// a tiny SQLite store in the app's Documents directory
final class Notes {
    static let shared = Notes()
    private var db: OpaquePointer?
    init() {
        let path = NSHomeDirectory() + "/Documents/notes.sqlite"
        if sqlite3_open(path, &db) != SQLITE_OK { log.error("cannot open \(path, privacy: .public)") }
        sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY, text TEXT NOT NULL, created REAL)", nil, nil, nil)
    }
    func add(_ text: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO notes(text, created) VALUES (?, ?)", -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        if sqlite3_step(stmt) != SQLITE_DONE { log.error("insert failed: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)") }
        sqlite3_finalize(stmt)
    }
    func all() -> [String] {
        var stmt: OpaquePointer?, out: [String] = []
        guard sqlite3_prepare_v2(db, "SELECT text FROM notes ORDER BY id", -1, &stmt, nil) == SQLITE_OK else { return [] }
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(String(cString: sqlite3_column_text(stmt, 0))) }
        sqlite3_finalize(stmt)
        return out
    }
}
