// isim CloudKit: a LOCAL CloudKit — no iCloud, no sync, no Apple servers. Containers, databases, records, zones,
// queries, subscriptions and change tokens behave like CloudKit against a store kept in the device data
// (Store.swift), so apps that use CloudKit run and their logic (conflicts, paging, change fetching) can be tested.
//   - The device is signed in to a simulated iCloud account; ISIM_ICLOUD=noAccount makes accountStatus .noAccount
//     and private/shared database operations (and public writes) fail with CKError.notAuthenticated.
//   - Subscriptions are saved and listed; when a record change in THIS process matches one, a CloudKit-style push
//     payload is delivered in-process to the app delegate's application(_:didReceiveRemoteNotification:
//     fetchCompletionHandler:) (there is no APNs; changes made by other processes do not notify).
//   - Completion handlers run on a background queue, like CloudKit's.
import Foundation
import UIKit

public enum CKAccountStatus: Int, Sendable { case couldNotDetermine = 0, available = 1, restricted = 2, noAccount = 3, temporarilyUnavailable = 4 }

extension NSNotification.Name {
    public static let CKAccountChanged = NSNotification.Name("CKAccountChangedNotification")
}

open class CKContainer: NSObject, @unchecked Sendable {
    public let containerIdentifier: String?
    nonisolated(unsafe) static var defaultContainer: CKContainer?
    public init(identifier: String) { containerIdentifier = identifier }
    /// the app's default container: "iCloud.<bundle id>" (iOS takes it from the entitlements)
    open class func `default`() -> CKContainer {
        if let c = defaultContainer { return c }
        let c = CKContainer(identifier: "iCloud." + _CKEnv.bundleID)
        defaultContainer = c
        return c
    }
    open lazy var privateCloudDatabase = CKDatabase(self, .private)
    open lazy var publicCloudDatabase = CKDatabase(self, .public)
    open lazy var sharedCloudDatabase = CKDatabase(self, .shared)
    open func database(with scope: CKDatabase.Scope) -> CKDatabase {
        switch scope { case .public: publicCloudDatabase; case .private: privateCloudDatabase; case .shared: sharedCloudDatabase }
    }

    open func accountStatus(completionHandler: @escaping @Sendable (CKAccountStatus, Error?) -> Void) {
        let s = _CKEnv.accountStatus
        DispatchQueue.global().async { completionHandler(s, nil) }
    }
    open func accountStatus() async throws -> CKAccountStatus { _CKEnv.accountStatus }

    open func fetchUserRecordID(completionHandler: @escaping @Sendable (CKRecord.ID?, Error?) -> Void) {
        let id = userRecordIDOrError()
        DispatchQueue.global().async { completionHandler(id.0, id.1) }
    }
    open func userRecordID() async throws -> CKRecord.ID {
        let id = userRecordIDOrError()
        if let e = id.1 { throw e }
        return id.0!
    }
    func userRecordIDOrError() -> (CKRecord.ID?, Error?) {
        guard _CKEnv.accountStatus == .available else { return (nil, CKError(.notAuthenticated)) }
        return (CKRecord.ID(recordName: _CKEnv.userRecordName), nil)
    }

    /// runs a database operation in the private database (or the operation's own database)
    open func add(_ operation: CKOperation) {
        if let op = operation as? CKDatabaseOperation, op.database == nil { op.database = privateCloudDatabase }
        operation.container = self
        operation._enqueue()
    }

    public struct ApplicationPermissions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let userDiscoverability = ApplicationPermissions(rawValue: 1)
    }
    public enum ApplicationPermissionStatus: Int, Sendable { case initialState = 0, couldNotComplete = 1, denied = 2, granted = 3 }
}

open class CKDatabase: NSObject, @unchecked Sendable {
    public enum Scope: Int, Sendable { case `public` = 1, `private` = 2, shared = 3 }
    public let databaseScope: Scope
    unowned let container: CKContainer
    let store: _CKStore
    init(_ c: CKContainer, _ scope: Scope) {
        container = c; databaseScope = scope
        store = _CKStore.shared(c.containerIdentifier ?? "default", scope)
    }
    static let queue = DispatchQueue(label: "isim.cloudkit")

    open func add(_ operation: CKDatabaseOperation) {
        operation.database = self
        operation.container = container
        operation._enqueue()
    }

    // MARK: account gate
    func check(write: Bool) -> Error? {
        let s = _CKEnv.accountStatus
        if s == .available { return nil }
        if databaseScope == .public && !write { return nil }
        return CKError(s == .temporarilyUnavailable ? .accountTemporarilyUnavailable : .notAuthenticated)
    }

    // MARK: records (synchronous core)
    var user: CKRecord.ID { CKRecord.ID(recordName: _CKEnv.userRecordName) }

    func record(from s: _CKStoredRecord, id: CKRecord.ID, desiredKeys: [String]? = nil) -> CKRecord {
        let r = CKRecord(recordType: s.type, recordID: id)
        r.fields = desiredKeys.map { keys in s.fields.filter { keys.contains($0.key) } } ?? s.fields
        r.recordChangeTag = s.tag
        r.creationDate = Date(timeIntervalSinceReferenceDate: s.created)
        r.modificationDate = Date(timeIntervalSinceReferenceDate: s.modified)
        r.creatorUserRecordID = CKRecord.ID(recordName: CKCurrentUserDefaultName)
        r.lastModifiedUserRecordID = CKRecord.ID(recordName: CKCurrentUserDefaultName)
        if let p = s.parent { r.parent = CKRecord.Reference(recordID: CKRecord.ID(recordName: p, zoneID: id.zoneID), action: .none) }
        return r
    }

    func zoneExists(_ z: CKRecordZone.ID, _ db: _CKDB) -> Bool {
        if z.zoneName == CKRecordZoneDefaultName { return true }
        return databaseScope != .public && db.zones[z.key] != nil
    }

    enum Change { case created(CKRecord), updated(CKRecord), deleted(CKRecord.ID, String) }

    func _save(_ records: [CKRecord], policy: CKModifyRecordsOperation.RecordSavePolicy, atomic: Bool) -> [(CKRecord.ID, Result<CKRecord, Error>)] {
        if let e = check(write: true) { return records.map { ($0.recordID, .failure(e)) } }
        var changes: [Change] = []
        let results: [(CKRecord.ID, Result<CKRecord, Error>)] = store.access { db in
            var work = db
            var out: [(CKRecord.ID, Result<CKRecord, Error>)] = []
            var pending: [Change] = []
            for rec in records {
                let id = rec.recordID, key = id.key
                guard zoneExists(id.zoneID, work) else { out.append((id, .failure(CKError(.zoneNotFound, userInfo: [NSLocalizedDescriptionKey: "Zone \(id.zoneID.zoneName) does not exist"])))); continue }
                var fields: [String: _CKValue]
                var created = Date().timeIntervalSinceReferenceDate
                let existing = work.records[key]
                if let ex = existing {
                    if ex.type != rec.recordType {
                        out.append((id, .failure(CKError(.invalidArguments, userInfo: [NSLocalizedDescriptionKey: "Record type mismatch (\(ex.type) on the server)"])))); continue
                    }
                    if policy == .ifServerRecordUnchanged && rec.recordChangeTag != ex.tag {
                        let server = record(from: ex, id: id)
                        out.append((id, .failure(CKError(.serverRecordChanged, userInfo: [
                            NSLocalizedDescriptionKey: "Error saving record \(id.recordName) to server: record to insert already exists or was changed (client tag \(rec.recordChangeTag ?? "nil"), server tag \(ex.tag))",
                            CKRecordChangedErrorServerRecordKey: server, CKRecordChangedErrorClientRecordKey: rec]))))
                        continue
                    }
                    fields = policy == .allKeys ? rec.fields : ex.fields
                    if policy != .allKeys { for k in rec.changed { fields[k] = rec.fields[k] } }
                    created = ex.created
                } else {
                    if rec.recordChangeTag != nil && policy == .ifServerRecordUnchanged {
                        out.append((id, .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "Record \(id.recordName) was deleted on the server"])))); continue
                    }
                    fields = rec.fields
                }
                // assets are uploaded: copied into the container's asset store
                var assetError: Error?
                for (k, v) in fields {
                    guard case .asset(let p) = v, !p.hasPrefix(store.assetsDir) else { continue }
                    guard FileManager.default.fileExists(atPath: p) else { assetError = CKError(.assetFileNotFound, userInfo: [NSLocalizedDescriptionKey: "Asset file not found: \(p)"]); break }
                    let dst = (store.assetsDir as NSString).appendingPathComponent(UUID().uuidString + ((p as NSString).pathExtension.isEmpty ? "" : "." + (p as NSString).pathExtension))
                    try? FileManager.default.copyItem(atPath: p, toPath: dst)
                    fields[k] = .asset(dst)
                }
                if let assetError { out.append((id, .failure(assetError))); continue }
                work.counter += 1
                let now = Date().timeIntervalSinceReferenceDate
                let s = _CKStoredRecord(type: rec.recordType, fields: fields, tag: String(work.counter, radix: 36) + String(Int(now) % 1296, radix: 36),
                                        created: created, modified: now, seq: work.counter, parent: rec.parent?.recordID.recordName)
                work.records[key] = s
                work.tombstones.removeAll { $0.name == id.recordName && $0.zone == id.zoneID.zoneName && $0.owner == id.zoneID.ownerName }
                if !work.recordTypes.contains(rec.recordType) { work.recordTypes.append(rec.recordType) }
                if var z = work.zones[id.zoneID.key] { z.seq = work.counter; work.zones[id.zoneID.key] = z }
                let saved = record(from: s, id: id)
                out.append((id, .success(saved)))
                pending.append(existing == nil ? .created(saved) : .updated(saved))
            }
            let failed = out.contains { if case .failure = $0.1 { return true } else { return false } }
            if atomic && failed && records.count > 1 {
                return out.map { r in
                    if case .failure = r.1 { return r }
                    return (r.0, .failure(CKError(.batchRequestFailed, userInfo: [NSLocalizedDescriptionKey: "Record \(r.0.recordName) not saved: another record in the atomic batch failed"])))
                }
            }
            db = work
            changes = pending
            return out
        }
        notify(changes)
        return results
    }

    func _fetch(_ ids: [CKRecord.ID], desiredKeys: [String]?) -> [(CKRecord.ID, Result<CKRecord, Error>)] {
        if let e = check(write: false) { return ids.map { ($0, .failure(e)) } }
        return store.access { db in
            ids.map { id in
                guard zoneExists(id.zoneID, db) else { return (id, .failure(CKError(.zoneNotFound))) }
                guard let s = db.records[id.key] else { return (id, .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "Record not found"]))) }
                return (id, .success(record(from: s, id: id, desiredKeys: desiredKeys)))
            }
        }
    }

    func _delete(_ ids: [CKRecord.ID]) -> [(CKRecord.ID, Result<Void, Error>)] {
        if let e = check(write: true) { return ids.map { ($0, .failure(e)) } }
        var changes: [Change] = []
        let out: [(CKRecord.ID, Result<Void, Error>)] = store.access { db in
            var out: [(CKRecord.ID, Result<Void, Error>)] = []
            for id in ids {
                guard let s = db.records[id.key] else { out.append((id, .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "Record not found"])))); continue }
                // the record and everything that references it with .deleteSelf (cascading)
                var queue = [(id, s.type)]
                while let (cur, type) = queue.popLast() {
                    guard db.records.removeValue(forKey: cur.key) != nil else { continue }
                    db.counter += 1
                    db.tombstones.append(_CKTombstone(name: cur.recordName, zone: cur.zoneID.zoneName, owner: cur.zoneID.ownerName, type: type, seq: db.counter))
                    if var z = db.zones[cur.zoneID.key] { z.seq = db.counter; db.zones[cur.zoneID.key] = z }
                    changes.append(.deleted(cur, type))
                    for (k, r) in db.records where k.hasPrefix(cur.zoneID.key + "/") {
                        let refs = r.fields.values.flatMap { v -> [_CKValue] in if case .list(let l) = v { return l } else { return [v] } }
                        if refs.contains(where: { if case .reference(let n, _, _, 1) = $0 { return n == cur.recordName } else { return false } }) {
                            queue.append((CKRecord.ID(recordName: String(k.split(separator: "/").last!), zoneID: cur.zoneID), r.type))
                        }
                    }
                }
                out.append((id, .success(())))
            }
            if db.tombstones.count > 2000 { db.tombstones.removeFirst(db.tombstones.count - 2000) }
            return out
        }
        notify(changes)
        return out
    }

    /// matching records, sorted; the cursor is the offset of the next page
    func _query(_ q: CKQuery, zone: CKRecordZone.ID?, desiredKeys: [String]?, offset: Int, limit: Int) -> Result<([CKRecord], Int?), Error> {
        if let e = check(write: false) { return .failure(e) }
        let z = zone ?? .default
        return store.access { db -> Result<([CKRecord], Int?), Error> in
            guard zoneExists(z, db) else { return .failure(CKError(.zoneNotFound)) }
            guard db.recordTypes.contains(q.recordType) else {
                return .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "Did not find record type: \(q.recordType)"]))
            }
            var matches: [(CKRecord, NSDictionary)] = []
            for (k, s) in db.records where s.type == q.recordType && k.hasPrefix(z.key + "/") {
                let r = record(from: s, id: CKRecord.ID(recordName: String(k.dropFirst(z.key.count + 1)), zoneID: z))
                let o = r.evaluationObject
                if q.predicate.evaluate(with: o) { matches.append((r, o)) }
            }
            var ordered = matches.sorted { $0.0.recordID.recordName < $1.0.recordID.recordName }
            if let sd = q.sortDescriptors, !sd.isEmpty {
                let objs = (ordered.map { $0.1 } as NSArray).sortedArray(using: sd)
                ordered = objs.compactMap { o in ordered.first { $0.1 === (o as AnyObject) } }
            }
            let page = Array(ordered.dropFirst(offset).prefix(limit)).map { m -> CKRecord in
                if let keys = desiredKeys { m.0.fields = m.0.fields.filter { keys.contains($0.key) } }
                return m.0
            }
            let next = offset + page.count < ordered.count ? offset + page.count : nil
            return .success((page, next))
        }
    }

    // MARK: subscription notifications (in-process)
    nonisolated(unsafe) static var predicates: [String: NSPredicate] = [:]

    func notify(_ changes: [Change]) {
        guard !changes.isEmpty else { return }
        var payloads: [[String: Any]] = []
        var firedOnce: [String] = []
        let subs = store.access { $0.subscriptions }
        for sub in subs.values.sorted(by: { $0.id < $1.id }) {
            for ch in changes {
                let (id, type, rec, reason): (CKRecord.ID, String, CKRecord?, Int) = {
                    switch ch {
                    case .created(let r): return (r.recordID, r.recordType, r, 1)
                    case .updated(let r): return (r.recordID, r.recordType, r, 2)
                    case .deleted(let i, let t): return (i, t, nil, 3)
                    }
                }()
                var ck: [String: Any] = ["ce": 2, "cid": container.containerIdentifier ?? "", "nid": UUID().uuidString, "ckuserid": _CKEnv.userRecordName]
                switch sub.kind {
                case "query":
                    guard sub.recordType == type else { continue }
                    if let zn = sub.zone, zn != id.zoneID.zoneName { continue }
                    let flag: UInt = reason == 1 ? 1 : reason == 2 ? 2 : 4
                    guard sub.options & flag != 0 else { continue }
                    if let r = rec {
                        guard let p = CKDatabase.predicate(sub), p.evaluate(with: r.evaluationObject) else { continue }
                    }
                    var q: [String: Any] = ["dbs": databaseScope.rawValue, "fo": reason, "rid": id.recordName, "sid": sub.id, "zid": id.zoneID.zoneName, "zoid": id.zoneID.ownerName]
                    if let keys = sub.desiredKeys, let r = rec {
                        var af: [String: Any] = [:]
                        for k in keys { if let v = r.fields[k] { af[k] = v.object } }
                        q["af"] = af
                    }
                    ck["qry"] = q
                    if sub.options & 8 != 0 { firedOnce.append(sub.id) }
                case "database":
                    guard databaseScope != .public else { continue }
                    ck["met"] = ["dbs": databaseScope.rawValue, "sid": sub.id]
                case "zone":
                    guard sub.zone == id.zoneID.zoneName else { continue }
                    ck["fet"] = ["dbs": databaseScope.rawValue, "sid": sub.id, "zid": id.zoneID.zoneName, "zoid": id.zoneID.ownerName]
                default: continue
                }
                var aps: [String: Any] = [:]
                if sub.contentAvailable { aps["content-available"] = 1 }
                if let b = sub.alertBody { aps["alert"] = sub.title.map { ["title": $0, "body": b] } ?? ["body": b] }
                payloads.append(["aps": aps, "ck": ck])
                if sub.kind != "query" { break }     // one database / zone notification per batch
            }
        }
        if !firedOnce.isEmpty {
            store.access { db in for s in firedOnce { db.subscriptions[s] = nil }; db.counter += 1 }
        }
        guard !payloads.isEmpty else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                for p in payloads {
                    let ck = p["ck"] as? [String: Any] ?? [:]
                    let sid = ((ck["qry"] ?? ck["met"] ?? ck["fet"]) as? [String: Any])?["sid"] as? String ?? "?"
                    NSLog("isim CloudKit: notification for subscription %@ delivered in-process (no APNs)", sid)
                    let app = UIApplication.shared
                    if let d = app.delegate, d.responds(to: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))) {
                        d.application?(app, didReceiveRemoteNotification: p, fetchCompletionHandler: { _ in })
                    } else {
                        NSLog("isim CloudKit: the app delegate does not implement application(_:didReceiveRemoteNotification:fetchCompletionHandler:)")
                    }
                }
            }
        }
    }
    static func predicate(_ s: _CKStoredSub) -> NSPredicate? {
        if let p = predicates[s.id] { return p }
        guard let f = s.predicate, !f.contains("CAST(") else { return s.predicate == nil ? NSPredicate(value: true) : nil }
        let p = NSPredicate(format: f, argumentArray: nil)
        predicates[s.id] = p
        return p
    }
}

open class CKQuery: NSObject, @unchecked Sendable {
    public let recordType: CKRecord.RecordType
    public let predicate: NSPredicate
    open var sortDescriptors: [NSSortDescriptor]?
    public init(recordType: CKRecord.RecordType, predicate: NSPredicate) { self.recordType = recordType; self.predicate = predicate }
}
