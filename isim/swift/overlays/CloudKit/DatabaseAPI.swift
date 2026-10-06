// CKDatabase convenience API (completion handlers + async/await), zones and subscriptions.
import Foundation

extension CKDatabase {
    static func reply(_ body: @escaping @Sendable () -> Void) { CKDatabase.queue.async(execute: body) }

    // MARK: records
    public func save(_ record: CKRecord, completionHandler: @escaping @Sendable (CKRecord?, Error?) -> Void) {
        CKDatabase.reply { let r = self._save([record], policy: .ifServerRecordUnchanged, atomic: false)[0].1
            switch r { case .success(let x): completionHandler(x, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    public func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping @Sendable (CKRecord?, Error?) -> Void) {
        CKDatabase.reply { let r = self._fetch([recordID], desiredKeys: nil)[0].1
            switch r { case .success(let x): completionHandler(x, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    public func delete(withRecordID recordID: CKRecord.ID, completionHandler: @escaping @Sendable (CKRecord.ID?, Error?) -> Void) {
        CKDatabase.reply { let r = self._delete([recordID])[0].1
            switch r { case .success: completionHandler(recordID, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    @available(iOS, deprecated: 15.0, message: "Use fetch(withQuery:inZoneWith:desiredKeys:resultsLimit:completionHandler:)")
    public func perform(_ query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?, completionHandler: @escaping @Sendable ([CKRecord]?, Error?) -> Void) {
        CKDatabase.reply {
            switch self._query(query, zone: zoneID, desiredKeys: nil, offset: 0, limit: Int.max) {
            case .success(let (recs, _)): completionHandler(recs, nil)
            case .failure(let e): completionHandler(nil, e)
            }
        }
    }
    public func fetch(withQuery query: CKQuery, inZoneWith zoneID: CKRecordZone.ID? = nil, desiredKeys: [CKRecord.FieldKey]? = nil, resultsLimit: Int = CKQueryOperation.maximumResults,
                      completionHandler: @escaping @Sendable (Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) -> Void) {
        CKDatabase.reply { completionHandler(self._page(query, zoneID, desiredKeys, 0, resultsLimit)) }
    }
    public func fetch(withCursor cursor: CKQueryOperation.Cursor, desiredKeys: [CKRecord.FieldKey]? = nil, resultsLimit: Int = CKQueryOperation.maximumResults,
                      completionHandler: @escaping @Sendable (Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) -> Void) {
        CKDatabase.reply { completionHandler(self._page(cursor.query, cursor.zoneID, desiredKeys, cursor.offset, resultsLimit)) }
    }
    func _page(_ q: CKQuery, _ zone: CKRecordZone.ID?, _ keys: [String]?, _ offset: Int, _ limit: Int) -> Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error> {
        let n = limit <= 0 ? CKQueryOperation.defaultPage : limit
        switch _query(q, zone: zone, desiredKeys: keys, offset: offset, limit: n) {
        case .success(let (recs, next)):
            return .success((recs.map { ($0.recordID, Result<CKRecord, Error>.success($0)) }, next.map { CKQueryOperation.Cursor(q, zone, $0) }))
        case .failure(let e): return .failure(e)
        }
    }

    // async
    public func save(_ record: CKRecord) async throws -> CKRecord { try _save([record], policy: .ifServerRecordUnchanged, atomic: false)[0].1.get() }
    public func record(for recordID: CKRecord.ID) async throws -> CKRecord { try _fetch([recordID], desiredKeys: nil)[0].1.get() }
    public func records(for ids: [CKRecord.ID], desiredKeys: [CKRecord.FieldKey]? = nil) async throws -> [CKRecord.ID: Result<CKRecord, Error>] {
        if let e = check(write: false) { throw e }
        return Dictionary(_fetch(ids, desiredKeys: desiredKeys), uniquingKeysWith: { a, _ in a })
    }
    @discardableResult
    public func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID { try _delete([recordID])[0].1.get(); return recordID }
    public func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID? = nil, desiredKeys: [CKRecord.FieldKey]? = nil,
                        resultsLimit: Int = CKQueryOperation.maximumResults) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) {
        try _page(query, zoneID, desiredKeys, 0, resultsLimit).get()
    }
    public func records(continuingMatchFrom cursor: CKQueryOperation.Cursor, desiredKeys: [CKRecord.FieldKey]? = nil,
                        resultsLimit: Int = CKQueryOperation.maximumResults) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) {
        try _page(cursor.query, cursor.zoneID, desiredKeys, cursor.offset, resultsLimit).get()
    }
    public func modifyRecords(saving recordsToSave: [CKRecord], deleting recordIDsToDelete: [CKRecord.ID],
                              savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged, atomically: Bool = true) async throws
        -> (saveResults: [CKRecord.ID: Result<CKRecord, Error>], deleteResults: [CKRecord.ID: Result<Void, Error>]) {
        if let e = check(write: true) { throw e }
        let s = _save(recordsToSave, policy: savePolicy, atomic: atomically)
        let d = _delete(recordIDsToDelete)
        return (Dictionary(s, uniquingKeysWith: { a, _ in a }), Dictionary(d, uniquingKeysWith: { a, _ in a }))
    }

    // MARK: zones
    func _saveZones(_ zones: [CKRecordZone]) -> [(CKRecordZone.ID, Result<CKRecordZone, Error>)] {
        if let e = check(write: true) { return zones.map { ($0.zoneID, .failure(e)) } }
        if databaseScope != .private { return zones.map { ($0.zoneID, .failure(CKError(.permissionFailure, userInfo: [NSLocalizedDescriptionKey: "Custom zones are only allowed in the private database"]))) } }
        return store.access { db in zones.map { z in
            db.counter += 1
            if db.zones[z.zoneID.key] == nil { db.zones[z.zoneID.key] = _CKStoredZone(name: z.zoneID.zoneName, owner: z.zoneID.ownerName, seq: db.counter) }
            db.deletedZones.removeAll { $0.name == z.zoneID.zoneName && $0.owner == z.zoneID.ownerName }
            return (z.zoneID, .success(z))
        } }
    }
    func _deleteZones(_ ids: [CKRecordZone.ID]) -> [(CKRecordZone.ID, Result<Void, Error>)] {
        if let e = check(write: true) { return ids.map { ($0, .failure(e)) } }
        return store.access { db in ids.map { id in
            guard db.zones.removeValue(forKey: id.key) != nil else { return (id, .failure(CKError(.zoneNotFound))) }
            db.counter += 1
            db.records = db.records.filter { !$0.key.hasPrefix(id.key + "/") }
            db.deletedZones.append(_CKStoredZone(name: id.zoneName, owner: id.ownerName, seq: db.counter))
            return (id, .success(()))
        } }
    }
    func _allZones() -> Result<[CKRecordZone], Error> {
        if let e = check(write: false) { return .failure(e) }
        return .success([CKRecordZone.default()] + store.access { $0.zones.values.sorted { $0.name < $1.name }.map { CKRecordZone(zoneID: CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner)) } })
    }
    public func save(_ zone: CKRecordZone, completionHandler: @escaping @Sendable (CKRecordZone?, Error?) -> Void) {
        CKDatabase.reply { switch self._saveZones([zone])[0].1 { case .success(let z): completionHandler(z, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    public func save(_ zone: CKRecordZone) async throws -> CKRecordZone { try _saveZones([zone])[0].1.get() }
    public func deleteRecordZone(withID zoneID: CKRecordZone.ID, completionHandler: @escaping @Sendable (CKRecordZone.ID?, Error?) -> Void) {
        CKDatabase.reply { switch self._deleteZones([zoneID])[0].1 { case .success: completionHandler(zoneID, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    @discardableResult
    public func deleteRecordZone(withID zoneID: CKRecordZone.ID) async throws -> CKRecordZone.ID { try _deleteZones([zoneID])[0].1.get(); return zoneID }
    public func fetchAllRecordZones(completionHandler: @escaping @Sendable ([CKRecordZone]?, Error?) -> Void) {
        CKDatabase.reply { switch self._allZones() { case .success(let z): completionHandler(z, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    public func allRecordZones() async throws -> [CKRecordZone] { try _allZones().get() }
    public func modifyRecordZones(saving: [CKRecordZone], deleting: [CKRecordZone.ID]) async throws
        -> (saveResults: [CKRecordZone.ID: Result<CKRecordZone, Error>], deleteResults: [CKRecordZone.ID: Result<Void, Error>]) {
        (Dictionary(_saveZones(saving), uniquingKeysWith: { a, _ in a }), Dictionary(_deleteZones(deleting), uniquingKeysWith: { a, _ in a }))
    }

    // MARK: subscriptions
    func _saveSubs(_ subs: [CKSubscription]) -> [(CKSubscription.ID, Result<CKSubscription, Error>)] {
        if let e = check(write: true) { return subs.map { ($0.subscriptionID, .failure(e)) } }
        return store.access { db in subs.map { s in
            if s is CKDatabaseSubscription && databaseScope == .public {
                return (s.subscriptionID, .failure(CKError(.invalidArguments, userInfo: [NSLocalizedDescriptionKey: "Database subscriptions are not supported in the public database"])))
            }
            db.counter += 1
            db.subscriptions[s.subscriptionID] = s.stored
            if let q = s as? CKQuerySubscription { CKDatabase.predicates[s.subscriptionID] = q.predicate }
            NSLog("isim CloudKit: subscription %@ saved (local; notifications are delivered in-process)", s.subscriptionID)
            return (s.subscriptionID, .success(s))
        } }
    }
    func _deleteSubs(_ ids: [CKSubscription.ID]) -> [(CKSubscription.ID, Result<Void, Error>)] {
        if let e = check(write: true) { return ids.map { ($0, .failure(e)) } }
        return store.access { db in ids.map { id in
            guard db.subscriptions.removeValue(forKey: id) != nil else { return (id, .failure(CKError(.unknownItem))) }
            db.counter += 1
            CKDatabase.predicates[id] = nil
            return (id, .success(()))
        } }
    }
    func _allSubs() -> Result<[CKSubscription], Error> {
        if let e = check(write: false) { return .failure(e) }
        return .success(store.access { $0.subscriptions.values.sorted { $0.id < $1.id }.map { CKSubscription.make($0) } })
    }
    public func save(_ subscription: CKSubscription, completionHandler: @escaping @Sendable (CKSubscription?, Error?) -> Void) {
        CKDatabase.reply { switch self._saveSubs([subscription])[0].1 { case .success(let s): completionHandler(s, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    public func save(_ subscription: CKSubscription) async throws -> CKSubscription { try _saveSubs([subscription])[0].1.get() }
    public func fetchAllSubscriptions(completionHandler: @escaping @Sendable ([CKSubscription]?, Error?) -> Void) {
        CKDatabase.reply { switch self._allSubs() { case .success(let s): completionHandler(s, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    public func allSubscriptions() async throws -> [CKSubscription] { try _allSubs().get() }
    public func fetch(withSubscriptionID id: CKSubscription.ID, completionHandler: @escaping @Sendable (CKSubscription?, Error?) -> Void) {
        CKDatabase.reply {
            switch self._allSubs() {
            case .success(let s): if let x = s.first(where: { $0.subscriptionID == id }) { completionHandler(x, nil) } else { completionHandler(nil, CKError(.unknownItem)) }
            case .failure(let e): completionHandler(nil, e)
            }
        }
    }
    public func subscription(for id: CKSubscription.ID) async throws -> CKSubscription {
        guard let s = try _allSubs().get().first(where: { $0.subscriptionID == id }) else { throw CKError(.unknownItem) }
        return s
    }
    public func delete(withSubscriptionID id: CKSubscription.ID, completionHandler: @escaping @Sendable (String?, Error?) -> Void) {
        CKDatabase.reply { switch self._deleteSubs([id])[0].1 { case .success: completionHandler(id, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    @discardableResult
    public func deleteSubscription(withID id: CKSubscription.ID) async throws -> CKSubscription.ID { try _deleteSubs([id])[0].1.get(); return id }
}
