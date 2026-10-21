// The local CloudKit "server": one JSON file per container and database in the device data
// ($ISIM_DATA/Library/isim/CloudKit/<container id>/<public|private|shared>.json, assets in Assets/).
// Every app on the device that uses the same container identifier sees the same records (like two apps of a
// team sharing a container); nothing is synced to iCloud.
import Foundation

struct _CKStoredRecord: Codable {
    var type: String
    var fields: [String: _CKValue]
    var tag: String
    var created: Double
    var modified: Double
    var seq: Int
    var parent: String?
    var share: _CKStoredShare? = nil                  // a CKShare's owner, permissions and participants
}
struct _CKStoredParticipant: Codable {
    var user: String, firstName: String?, lastName: String?, contact: String?
    var role: Int, permission: Int, status: Int
}
struct _CKStoredShare: Codable { var owner: _CKStoredParticipant; var root: String?; var publicPermission: Int; var participants: [_CKStoredParticipant] }
struct _CKStoredZone: Codable { var name: String; var owner: String; var seq: Int }
struct _CKTombstone: Codable { var name: String; var zone: String; var owner: String; var type: String; var seq: Int }
struct _CKStoredSub: Codable {
    var id: String, kind: String
    var recordType: String?, predicate: String?, options: UInt
    var zone: String?, zoneOwner: String?
    var alertBody: String?, title: String?, contentAvailable: Bool, desiredKeys: [String]?
}
struct _CKDB: Codable {
    var zones: [String: _CKStoredZone] = [:]          // owner/zone
    var records: [String: _CKStoredRecord] = [:]      // owner/zone/name
    var tombstones: [_CKTombstone] = []
    var deletedZones: [_CKStoredZone] = []
    var subscriptions: [String: _CKStoredSub] = [:]
    var recordTypes: [String] = []                    // the development schema (created on first save, like CloudKit dev)
    var counter = 0
}

final class _CKStore: @unchecked Sendable {
    nonisolated(unsafe) static var stores: [String: _CKStore] = [:]
    static let lock = NSRecursiveLock()
    static func shared(_ container: String, _ scope: CKDatabase.Scope) -> _CKStore {
        lock.lock(); defer { lock.unlock() }
        let k = "\(container)#\(scope.rawValue)"
        if let s = stores[k] { return s }
        let s = _CKStore(container, scope); stores[k] = s
        return s
    }
    let container: String, scope: CKDatabase.Scope
    let dir: String, path: String
    init(_ container: String, _ scope: CKDatabase.Scope) {
        self.container = container; self.scope = scope
        dir = (_CKEnv.dataDir as NSString).appendingPathComponent("Library/isim/CloudKit/" + container.replacingOccurrences(of: "/", with: "_"))
        path = (dir as NSString).appendingPathComponent(["", "public", "private", "shared"][scope.rawValue] + ".json")
    }
    var assetsDir: String {
        let p = (dir as NSString).appendingPathComponent("Assets")
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true, attributes: nil)
        return p
    }
    /// read-modify-write under the lock; the file is re-read every time so other apps' changes are seen
    func access<T>(_ body: (inout _CKDB) throws -> T) rethrows -> T {
        _CKStore.lock.lock(); defer { _CKStore.lock.unlock() }
        var db = FileManager.default.contents(atPath: path).flatMap { try? JSONDecoder().decode(_CKDB.self, from: $0) } ?? _CKDB()
        let before = db.counter
        let r = try body(&db)
        if db.counter != before {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let d = try? e.encode(db) {
                let tmp = path + ".tmp\(getpid())"
                if FileManager.default.createFile(atPath: tmp, contents: d, attributes: nil) { rename(tmp, path) }
            }
        }
        return r
    }
}

enum _CKEnv {
    static var dataDir: String {
        let env = ProcessInfo.processInfo.environment
        return env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
    }
    /// ISIM_ICLOUD=available (default) | noAccount | restricted | temporarilyUnavailable
    static var accountStatus: CKAccountStatus {
        switch (ProcessInfo.processInfo.environment["ISIM_ICLOUD"] ?? "").lowercased() {
        case "noaccount", "none", "0", "signedout": return .noAccount
        case "restricted": return .restricted
        case "temporarilyunavailable": return .temporarilyUnavailable
        default: return .available
        }
    }
    /// the device's simulated Apple Account (AppleAccount/account.json; Taylor Appleseed <taylor@example.com> by default)
    static var account: (first: String, last: String, email: String) {
        let acct = (dataDir as NSString).appendingPathComponent("Library/isim/AppleAccount/account.json")
        let o = FileManager.default.contents(atPath: acct).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        return (o["firstName"] as? String ?? "Taylor", o["lastName"] as? String ?? "Appleseed", o["email"] as? String ?? "taylor@example.com")
    }
    /// the signed-in user's record name: stable per simulated account (the device's fake Apple Account email)
    static var userRecordName: String { recordName(forEmail: account.email) }
    static func recordName(forEmail email: String) -> String {
        var h1: UInt64 = 0xcbf29ce484222325, h2: UInt64 = 0x84222325cbf29ce4
        for b in email.lowercased().utf8 { h1 = (h1 ^ UInt64(b)) &* 0x100000001b3; h2 = (h2 ^ UInt64(b)) &* 0x100000001b3 &+ 7 }
        return "_" + String(format: "%016llx%016llx", h1, h2)
    }
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "unknown" }
}
