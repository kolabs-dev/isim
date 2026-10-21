// Sample: security, persistence and system services on isim — CryptoKit (hash, HMAC, AES-GCM), the keychain
// (SecItem*), SQLite3, os.Logger, Face ID (LocalAuthentication: also lockout, rights, LAEnvironment, access control and
// LocalAuthenticationView) and a local notification (UserNotifications).
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
                LADemoSection()
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
            let daily = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 9, minute: 30), repeats: true)
            if let next = daily.nextTriggerDate() {
                let c = Calendar.current.dateComponents([.hour, .minute], from: next)
                print("calendar next \(c.hour ?? -1):\(c.minute ?? -1) in \(Int(next.timeIntervalSinceNow / 3600))h repeats \(daily.repeats) hour \(daily.dateComponents.hour ?? -1)")
            }
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

/// LocalAuthentication beyond evaluatePolicy (issue #307): biometry lockout and LAEnvironment, LADomainState (iOS 18),
/// rights (LARight, LARightStore, a persisted right's key and secret, .biometryCurrentSet), evaluateAccessControl and
/// LocalAuthenticationView. Prints "la ..." lines for tests/ui/test_security.py.
final class LADemo: NSObject, ObservableObject {
    static let shared = LADemo()
    @Published var status = "—"
    var watching = false
    func say(_ s: String) { print("la \(s)"); DispatchQueue.main.async { self.status = s } }

    func watch() {
        guard !watching else { return }
        watching = true
        if #available(iOS 18.0, *) {
            LAEnvironment.currentUser.addObserver(EnvironmentObserver.shared)
            let b = LAEnvironment.currentUser.state.biometry
            say("environment biometry=\(b?.localizedName ?? "-") enrolled=\(b?.isEnrolled ?? false) locked=\(b?.isLockedOut ?? false) " +
                "passcode=\(LAEnvironment.currentUser.state.userPassword?.isSet ?? false) mechanisms=\(LAEnvironment.currentUser.state.allMechanisms.count)")
        } else {
            say("environment needs iOS 18")
        }
    }

    /// biometrics only: three failed scans end it, five in a row lock biometry out
    func biometrics() {
        watch()
        let c = LAContext()
        var e: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else { say("biometrics unavailable code=\(e?.code ?? 0)"); return }
        c.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Check the lockout") { ok, error in
            self.say("biometrics ok=\(ok) code=\((error as NSError?)?.code ?? 0)")
        }
    }
    /// the passcode ends a lockout
    func passcode() {
        LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock with the passcode") { ok, error in
            var e: NSError?
            let again = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e)
            self.say("passcode ok=\(ok) biometrics=\(again)")
        }
    }
    func domainState() {
        let c = LAContext()
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        if #available(iOS 18.0, *) {
            let s = c.domainState
            say("domain state biometry=\(s.biometry.biometryType == .faceID ? "faceID" : "other") hash=\(s.stateHash?.base64EncodedString() ?? "-") " +
                "same=\(s.biometry.stateHash == c.evaluatedPolicyDomainState) companions=\(s.companion.availableCompanionTypes.count)")
        } else {
            say("domain state hash=\(c.evaluatedPolicyDomainState?.base64EncodedString() ?? "-")")
        }
    }

    /// a right saved with a key and a secret; signing and the secret need it authorized
    func rights() {
        Task {
            let store = LARightStore.shared
            try? await store.removeAllRights()
            do {
                let saved = try await store.saveRight(LARight(), identifier: "notes", secret: Data("s3cret".utf8))
                _ = try await store.saveRight(LARight(requirement: .biometryCurrentSet), identifier: "current-set")
                let right = try await store.right(forIdentifier: "notes")
                say("right saved state=\(saved.state.rawValue) loaded=\(right.state == .unknown)")
                do { _ = try await right.key.sign(Data("note".utf8), algorithm: .ecdsaSignatureMessageX962SHA256) } catch {
                    say("right sign before authorize code=\((error as NSError).code)")
                }
                try await right.authorize(localizedReason: "Open your notes")
                let sig = try await right.key.sign(Data("note".utf8), algorithm: .ecdsaSignatureMessageX962SHA256)
                try await right.key.publicKey.verify(Data("note".utf8), signature: sig, algorithm: .ecdsaSignatureMessageX962SHA256)
                let secret = String(decoding: try await right.secret.load(), as: UTF8.self)
                let exported = try await right.key.publicKey.exportBytes()
                say("right authorized state=\(right.state.rawValue) signed=true verified=true secret=\(secret) public=\(exported.count)")
                await right.deauthorize()
                do { _ = try await right.secret.load() } catch { say("right deauthorized state=\(right.state.rawValue) secret refused") }
            } catch {
                say("right failed \(error)")
            }
        }
    }
    /// a .biometryCurrentSet right stops authorizing once the enrollment changes
    func currentSet() {
        Task {
            do {
                let r = try await LARightStore.shared.right(forIdentifier: "current-set")
                try await r.checkCanAuthorize()
                say("current set can authorize")
            } catch {
                say("current set refused code=\((error as NSError).code)")
            }
        }
    }
    /// what a keychain item's access control asks for
    func accessControl() {
        guard let ac = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .biometryAny, nil) else { return }
        LAContext().evaluateAccessControl(ac, operation: .useItem, localizedReason: "Read the token") { ok, error in
            self.say("access control ok=\(ok) code=\((error as NSError?)?.code ?? 0)")
        }
    }
}

struct LADemoSection: View {
    @ObservedObject var demo = LADemo.shared
    var body: some View {
        Section("LocalAuthentication") {
            Text(demo.status).font(.footnote).accessibilityIdentifier("la-status")
            Button("Biometrics only") { demo.biometrics() }.accessibilityIdentifier("la-biometrics")
            Button("Passcode") { demo.passcode() }.accessibilityIdentifier("la-passcode")
            Button("Domain state") { demo.domainState() }.accessibilityIdentifier("la-domain")
            Button("Rights") { demo.rights() }.accessibilityIdentifier("la-rights")
            Button("Current-set right") { demo.currentSet() }.accessibilityIdentifier("la-current-set")
            Button("Access control") { demo.accessControl() }.accessibilityIdentifier("la-access")
            LocalAuthenticationView("Show the secret", reason: Text("Show the secret note")) { result in
                switch result {
                case .success: demo.say("view authenticated")
                case .failure(let e): demo.say("view failed code=\((e as NSError).code)")
                }
            }
        }
    }
}

@available(iOS 18.0, *)
final class EnvironmentObserver: NSObject, LAEnvironment.Observer {
    static let shared = EnvironmentObserver()
    func environment(_ environment: LAEnvironment, stateDidChangeFromOldState oldState: LAEnvironment.State) {
        let b = environment.state.biometry
        LADemo.shared.say("environment changed enrolled=\(b?.isEnrolled ?? false) locked=\(b?.isLockedOut ?? false) was=\(oldState.biometry?.isLockedOut ?? false)")
    }
}
