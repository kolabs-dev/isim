// CloudKit operations (isim: CKOperation is an NSObject run on CloudKit's own queue — isim's Foundation has no
// NSOperation — so add operations to a CKDatabase / CKContainer, not to an OperationQueue).
import Foundation

/// Foundation's QualityOfService (isim's Foundation has no NSOperation yet, so CloudKit carries it; move it to
/// Foundation together with Operation/OperationQueue)
public enum QualityOfService: Int, Sendable { case userInteractive = 0x21, userInitiated = 0x19, utility = 0x11, background = 0x09, `default` = -1 }

@objc(CKOperation) open class CKOperation: NSObject, @unchecked Sendable {
    public typealias ID = String
    @objc(CKOperationConfiguration) open class Configuration: NSObject, @unchecked Sendable {
        @objc open var container: CKContainer?
        open var qualityOfService: QualityOfService = .default
        @objc open var allowsCellularAccess = true
        @objc open var isLongLived = false
        @objc open var timeoutIntervalForRequest: TimeInterval = 60
        @objc open var timeoutIntervalForResource: TimeInterval = 7 * 86400
    }
    @objc open var configuration: Configuration! = Configuration()
    @objc public let operationID: ID = UUID().uuidString
    @objc open var completionBlock: (() -> Void)?
    open var qualityOfService: QualityOfService = .default
    @objc open var name: String?
    /// The group the operation belongs to (isim: kept for the app; it does not change how the operation runs).
    @objc open var group: CKOperationGroup?
    @objc open var longLivedOperationWasPersistedBlock: (() -> Void)?
    @objc public private(set) var isCancelled = false
    @objc public private(set) var isExecuting = false
    @objc public private(set) var isFinished = false
    @objc weak var container: CKContainer?
    @objc open func cancel() { isCancelled = true }
    /// runs the operation now, on the calling thread
    @objc open func start() {
        guard !isFinished else { return }
        isExecuting = true
        main()
        isExecuting = false; isFinished = true
        completionBlock?()
    }
    @objc open func main() {}
    @objc func _enqueue() { CKDatabase.queue.async { self.start() } }
    @objc var cancelledError: Error { CKError(.operationCancelled) }
}

@objc(CKDatabaseOperation) open class CKDatabaseOperation: CKOperation, @unchecked Sendable {
    @objc open var database: CKDatabase?
    @objc var db: CKDatabase { database ?? (container ?? CKContainer.default()).privateCloudDatabase }
}

// MARK: - Query

@objc(CKQueryOperation) open class CKQueryOperation: CKDatabaseOperation, @unchecked Sendable {
    @objc public static let maximumResults = 0
    @objc static let defaultPage = 100
    @objc(CKQueryCursor) open class Cursor: NSObject, @unchecked Sendable {
        @objc let query: CKQuery, zoneID: CKRecordZone.ID?, offset: Int
        @objc init(_ q: CKQuery, _ z: CKRecordZone.ID?, _ o: Int) { query = q; zoneID = z; offset = o }
    }
    @objc open var query: CKQuery?
    @objc open var cursor: Cursor?
    @objc open var zoneID: CKRecordZone.ID?
    @objc open var resultsLimit: Int = CKQueryOperation.maximumResults
    @objc open var desiredKeys: [CKRecord.FieldKey]?
    open var recordMatchedBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    open var queryResultBlock: ((Result<Cursor?, Error>) -> Void)?
    @objc @available(iOS, deprecated: 15.0) open var recordFetchedBlock: ((CKRecord) -> Void)? { get { _isim_recordFetchedBlock } set { _isim_recordFetchedBlock = newValue } }
    @objc var _isim_recordFetchedBlock: ((CKRecord) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc @available(iOS, deprecated: 15.0) open var queryCompletionBlock: ((Cursor?, Error?) -> Void)? { get { _isim_queryCompletionBlock } set { _isim_queryCompletionBlock = newValue } }
    @objc var _isim_queryCompletionBlock: ((Cursor?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc public override init() { super.init() }
    @objc public convenience init(query: CKQuery) { self.init(); self.query = query }
    @objc public convenience init(cursor: Cursor) { self.init(); self.cursor = cursor }

    @objc open override func main() {
        guard !isCancelled else { finish(.failure(cancelledError)); return }
        guard let q = cursor?.query ?? query else { finish(.failure(CKError(.invalidArguments))); return }
        switch db._page(q, cursor?.zoneID ?? zoneID, desiredKeys, cursor?.offset ?? 0, resultsLimit) {
        case .success(let page):
            for (id, r) in page.matchResults {
                recordMatchedBlock?(id, r)
                if case .success(let rec) = r { _isim_recordFetchedBlock?(rec) }
            }
            finish(.success(page.queryCursor))
        case .failure(let e): finish(.failure(e))
        }
    }
    func finish(_ r: Result<Cursor?, Error>) {
        queryResultBlock?(r)
        switch r { case .success(let c): _isim_queryCompletionBlock?(c, nil); case .failure(let e): _isim_queryCompletionBlock?(nil, e) }
    }
}

// MARK: - Modify / fetch records

@objc(CKModifyRecordsOperation) open class CKModifyRecordsOperation: CKDatabaseOperation, @unchecked Sendable {
    public enum RecordSavePolicy: Int, Sendable { case ifServerRecordUnchanged = 0, changedKeys = 1, allKeys = 2 }
    @objc open var recordsToSave: [CKRecord]?
    @objc open var recordIDsToDelete: [CKRecord.ID]?
    open var savePolicy: RecordSavePolicy = .ifServerRecordUnchanged
    @objc open var clientChangeTokenData: Data?
    @objc open var isAtomic = true
    @objc open var perRecordProgressBlock: ((CKRecord, Double) -> Void)?
    open var perRecordSaveBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    open var perRecordDeleteBlock: ((CKRecord.ID, Result<Void, Error>) -> Void)?
    open var modifyRecordsResultBlock: ((Result<Void, Error>) -> Void)?
    @objc @available(iOS, deprecated: 15.0) open var perRecordCompletionBlock: ((CKRecord, Error?) -> Void)? { get { _isim_perRecordCompletionBlock } set { _isim_perRecordCompletionBlock = newValue } }
    @objc var _isim_perRecordCompletionBlock: ((CKRecord, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc @available(iOS, deprecated: 15.0) open var modifyRecordsCompletionBlock: (([CKRecord]?, [CKRecord.ID]?, Error?) -> Void)? { get { _isim_modifyRecordsCompletionBlock } set { _isim_modifyRecordsCompletionBlock = newValue } }
    @objc var _isim_modifyRecordsCompletionBlock: (([CKRecord]?, [CKRecord.ID]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc public override init() { super.init() }
    @objc public convenience init(recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecord.ID]?) {
        self.init(); self.recordsToSave = recordsToSave; self.recordIDsToDelete = recordIDsToDelete
    }

    @objc open override func main() {
        guard !isCancelled else { done(.failure(cancelledError), [], []); return }
        if let e = db.check(write: true) { done(.failure(e), [], []); return }
        let toSave = recordsToSave ?? []
        // CloudKit is atomic only in custom zones
        let atomic = isAtomic && toSave.allSatisfy { $0.recordID.zoneID.zoneName != CKRecordZoneDefaultName }
        let saves = db._save(toSave, policy: savePolicy, atomic: atomic)
        let deletes = (recordIDsToDelete ?? []).isEmpty ? [] : db._delete(recordIDsToDelete ?? [])
        var partial: [AnyHashable: Error] = [:]
        var saved: [CKRecord] = [], deleted: [CKRecord.ID] = []
        for (id, r) in saves {
            perRecordSaveBlock?(id, r)
            switch r {
            case .success(let rec): saved.append(rec); perRecordProgressBlock?(rec, 1); _isim_perRecordCompletionBlock?(rec, nil)
            case .failure(let e): partial[id] = e; if let c = toSave.first(where: { $0.recordID == id }) { _isim_perRecordCompletionBlock?(c, e) }
            }
        }
        for (id, r) in deletes {
            perRecordDeleteBlock?(id, r)
            switch r { case .success: deleted.append(id); case .failure(let e): partial[id] = e }
        }
        done(partial.isEmpty ? .success(()) : .failure(CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: partial])), saved, deleted)
    }
    func done(_ r: Result<Void, Error>, _ saved: [CKRecord], _ deleted: [CKRecord.ID]) {
        modifyRecordsResultBlock?(r)
        if case .failure(let e) = r { _isim_modifyRecordsCompletionBlock?(saved, deleted, e) } else { _isim_modifyRecordsCompletionBlock?(saved, deleted, nil) }
    }
}

@objc(CKFetchRecordsOperation) open class CKFetchRecordsOperation: CKDatabaseOperation, @unchecked Sendable {
    @objc open var recordIDs: [CKRecord.ID]?
    @objc open var desiredKeys: [CKRecord.FieldKey]?
    open var perRecordResultBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    open var fetchRecordsResultBlock: ((Result<Void, Error>) -> Void)?
    @objc @available(iOS, deprecated: 15.0) open var perRecordCompletionBlock: ((CKRecord?, CKRecord.ID?, Error?) -> Void)? { get { _isim_perRecordCompletionBlock } set { _isim_perRecordCompletionBlock = newValue } }
    @objc var _isim_perRecordCompletionBlock: ((CKRecord?, CKRecord.ID?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc @available(iOS, deprecated: 15.0) open var fetchRecordsCompletionBlock: (([CKRecord.ID: CKRecord]?, Error?) -> Void)? { get { _isim_fetchRecordsCompletionBlock } set { _isim_fetchRecordsCompletionBlock = newValue } }
    @objc var _isim_fetchRecordsCompletionBlock: (([CKRecord.ID: CKRecord]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc public override init() { super.init() }
    @objc public convenience init(recordIDs: [CKRecord.ID]) { self.init(); self.recordIDs = recordIDs }
    @objc open class func fetchCurrentUserRecordOperation() -> CKFetchRecordsOperation {
        let op = CKFetchRecordsOperation()
        op.recordIDs = [CKRecord.ID(recordName: _CKEnv.userRecordName)]
        return op
    }

    @objc open override func main() {
        guard !isCancelled else { fetchRecordsResultBlock?(.failure(cancelledError)); _isim_fetchRecordsCompletionBlock?(nil, cancelledError); return }
        if let e = db.check(write: false) { fetchRecordsResultBlock?(.failure(e)); _isim_fetchRecordsCompletionBlock?(nil, e); return }
        var found: [CKRecord.ID: CKRecord] = [:], partial: [AnyHashable: Error] = [:]
        for (id, r) in db._fetch(recordIDs ?? [], desiredKeys: desiredKeys) {
            perRecordResultBlock?(id, r)
            switch r {
            case .success(let rec): found[id] = rec; _isim_perRecordCompletionBlock?(rec, id, nil)
            case .failure(let e): partial[id] = e; _isim_perRecordCompletionBlock?(nil, id, e)
            }
        }
        let err: Error? = partial.isEmpty ? nil : CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: partial])
        fetchRecordsResultBlock?(err.map { .failure($0) } ?? .success(()))
        _isim_fetchRecordsCompletionBlock?(found, err)
    }
}

// MARK: - Zones and subscriptions

@objc(CKModifyRecordZonesOperation) open class CKModifyRecordZonesOperation: CKDatabaseOperation, @unchecked Sendable {
    @objc open var recordZonesToSave: [CKRecordZone]?
    @objc open var recordZoneIDsToDelete: [CKRecordZone.ID]?
    open var perRecordZoneSaveBlock: ((CKRecordZone.ID, Result<CKRecordZone, Error>) -> Void)?
    open var perRecordZoneDeleteBlock: ((CKRecordZone.ID, Result<Void, Error>) -> Void)?
    open var modifyRecordZonesResultBlock: ((Result<Void, Error>) -> Void)?
    @objc @available(iOS, deprecated: 15.0) open var modifyRecordZonesCompletionBlock: (([CKRecordZone]?, [CKRecordZone.ID]?, Error?) -> Void)? { get { _isim_modifyRecordZonesCompletionBlock } set { _isim_modifyRecordZonesCompletionBlock = newValue } }
    @objc var _isim_modifyRecordZonesCompletionBlock: (([CKRecordZone]?, [CKRecordZone.ID]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc public override init() { super.init() }
    @objc public convenience init(recordZonesToSave: [CKRecordZone]?, recordZoneIDsToDelete: [CKRecordZone.ID]?) {
        self.init(); self.recordZonesToSave = recordZonesToSave; self.recordZoneIDsToDelete = recordZoneIDsToDelete
    }
    @objc open override func main() {
        var partial: [AnyHashable: Error] = [:], saved: [CKRecordZone] = [], deleted: [CKRecordZone.ID] = []
        for (id, r) in db._saveZones(recordZonesToSave ?? []) {
            perRecordZoneSaveBlock?(id, r)
            switch r { case .success(let z): saved.append(z); case .failure(let e): partial[id] = e }
        }
        for (id, r) in db._deleteZones(recordZoneIDsToDelete ?? []) {
            perRecordZoneDeleteBlock?(id, r)
            switch r { case .success: deleted.append(id); case .failure(let e): partial[id] = e }
        }
        let err: Error? = partial.isEmpty ? nil : CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: partial])
        modifyRecordZonesResultBlock?(err.map { .failure($0) } ?? .success(()))
        _isim_modifyRecordZonesCompletionBlock?(saved, deleted, err)
    }
}

@objc(CKModifySubscriptionsOperation) open class CKModifySubscriptionsOperation: CKDatabaseOperation, @unchecked Sendable {
    @objc open var subscriptionsToSave: [CKSubscription]?
    @objc open var subscriptionIDsToDelete: [CKSubscription.ID]?
    open var perSubscriptionSaveBlock: ((CKSubscription.ID, Result<CKSubscription, Error>) -> Void)?
    open var perSubscriptionDeleteBlock: ((CKSubscription.ID, Result<Void, Error>) -> Void)?
    open var modifySubscriptionsResultBlock: ((Result<Void, Error>) -> Void)?
    @objc @available(iOS, deprecated: 15.0) open var modifySubscriptionsCompletionBlock: (([CKSubscription]?, [CKSubscription.ID]?, Error?) -> Void)? { get { _isim_modifySubscriptionsCompletionBlock } set { _isim_modifySubscriptionsCompletionBlock = newValue } }
    @objc var _isim_modifySubscriptionsCompletionBlock: (([CKSubscription]?, [CKSubscription.ID]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc public override init() { super.init() }
    @objc public convenience init(subscriptionsToSave: [CKSubscription]?, subscriptionIDsToDelete: [CKSubscription.ID]?) {
        self.init(); self.subscriptionsToSave = subscriptionsToSave; self.subscriptionIDsToDelete = subscriptionIDsToDelete
    }
    @objc open override func main() {
        var partial: [AnyHashable: Error] = [:], saved: [CKSubscription] = [], deleted: [CKSubscription.ID] = []
        for (id, r) in db._saveSubs(subscriptionsToSave ?? []) {
            perSubscriptionSaveBlock?(id, r)
            switch r { case .success(let s): saved.append(s); case .failure(let e): partial[id] = e }
        }
        for (id, r) in db._deleteSubs(subscriptionIDsToDelete ?? []) {
            perSubscriptionDeleteBlock?(id, r)
            switch r { case .success: deleted.append(id); case .failure(let e): partial[id] = e }
        }
        let err: Error? = partial.isEmpty ? nil : CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: partial])
        modifySubscriptionsResultBlock?(err.map { .failure($0) } ?? .success(()))
        _isim_modifySubscriptionsCompletionBlock?(saved, deleted, err)
    }
}

// MARK: - Change tracking

/// a position in the database's change history (opaque; isim: a sequence number)
@objc(CKServerChangeToken) open class CKServerChangeToken: NSObject, NSCopying, NSCoding, @unchecked Sendable {
    @objc let seq: Int
    @objc init(_ s: Int) { seq = s }
    @objc open func copy(with zone: OpaquePointer? = nil) -> Any { self }
    @objc open override func isEqual(_ o: Any?) -> Bool { (o as? CKServerChangeToken)?.seq == seq }
    @objc open override var hash: Int { seq }
    /// keep tokens across launches with NSKeyedArchiver (NSCoding)
    @objc public required init?(coder: NSCoder) { seq = coder.decodeInteger(forKey: "seq") }
    @objc open func encode(with coder: NSCoder) { coder.encode(seq, forKey: "seq") }
}

@objc(CKFetchDatabaseChangesOperation) open class CKFetchDatabaseChangesOperation: CKDatabaseOperation, @unchecked Sendable {
    @objc open var previousServerChangeToken: CKServerChangeToken?
    @objc open var resultsLimit = 0
    @objc open var fetchAllChanges = true
    @objc open var recordZoneWithIDChangedBlock: ((CKRecordZone.ID) -> Void)?
    @objc open var recordZoneWithIDWasDeletedBlock: ((CKRecordZone.ID) -> Void)?
    @objc open var recordZoneWithIDWasPurgedBlock: ((CKRecordZone.ID) -> Void)?
    @objc open var changeTokenUpdatedBlock: ((CKServerChangeToken) -> Void)?
    open var fetchDatabaseChangesResultBlock: ((Result<(serverChangeToken: CKServerChangeToken, moreComing: Bool), Error>) -> Void)?
    @objc @available(iOS, deprecated: 15.0) open var fetchDatabaseChangesCompletionBlock: ((CKServerChangeToken?, Bool, Error?) -> Void)? { get { _isim_fetchDatabaseChangesCompletionBlock } set { _isim_fetchDatabaseChangesCompletionBlock = newValue } }
    @objc var _isim_fetchDatabaseChangesCompletionBlock: ((CKServerChangeToken?, Bool, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc public override init() { super.init() }
    @objc public convenience init(previousServerChangeToken: CKServerChangeToken?) { self.init(); self.previousServerChangeToken = previousServerChangeToken }
    @objc open override func main() {
        if let e = db.check(write: false) { fetchDatabaseChangesResultBlock?(.failure(e)); _isim_fetchDatabaseChangesCompletionBlock?(nil, false, e); return }
        let since = previousServerChangeToken?.seq ?? 0
        let (changed, deleted, now, more): ([CKRecordZone.ID], [CKRecordZone.ID], Int, Bool) = db.store.access { d in
            var events: [(Int, Bool, CKRecordZone.ID)] = d.zones.values.filter { $0.seq > since }.map { ($0.seq, false, CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner)) }
            let defaultSeq = max(d.records.filter { $0.value.seq > since && $0.key.hasPrefix(CKRecordZone.ID.default.key + "/") }.map(\.value.seq).max() ?? 0,
                                 d.tombstones.filter { $0.seq > since && $0.zone == CKRecordZoneDefaultName }.map(\.seq).max() ?? 0)
            if defaultSeq > 0 { events.append((defaultSeq, false, .default)) }
            events += d.deletedZones.filter { $0.seq > since }.map { ($0.seq, true, CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner)) }
            events.sort { $0.0 < $1.0 }
            let limit = resultsLimit > 0 ? resultsLimit : Int.max
            let page = Array(events.prefix(limit)), token = page.last?.0 ?? since
            return (page.filter { !$0.1 }.map(\.2), page.filter { $0.1 }.map(\.2), token, page.count < events.count)
        }
        changed.forEach { recordZoneWithIDChangedBlock?($0) }
        deleted.forEach { recordZoneWithIDWasDeletedBlock?($0) }
        let token = CKServerChangeToken(now)
        changeTokenUpdatedBlock?(token)
        fetchDatabaseChangesResultBlock?(.success((token, more)))
        _isim_fetchDatabaseChangesCompletionBlock?(token, more, nil)
    }
}

@objc(CKFetchRecordZoneChangesOperation) open class CKFetchRecordZoneChangesOperation: CKDatabaseOperation, @unchecked Sendable {
    @objc(CKFetchRecordZoneChangesConfiguration) open class ZoneConfiguration: NSObject, @unchecked Sendable {
        @objc open var previousServerChangeToken: CKServerChangeToken?
        @objc open var resultsLimit = 0
        @objc open var desiredKeys: [CKRecord.FieldKey]?
        @objc public override init() {}
        @objc public convenience init(previousServerChangeToken: CKServerChangeToken? = nil, resultsLimit: Int = 0, desiredKeys: [CKRecord.FieldKey]? = nil) {
            self.init(); self.previousServerChangeToken = previousServerChangeToken; self.resultsLimit = resultsLimit; self.desiredKeys = desiredKeys
        }
    }
    @objc open var recordZoneIDs: [CKRecordZone.ID]?
    @objc open var configurationsByRecordZoneID: [CKRecordZone.ID: ZoneConfiguration]?
    @objc open var fetchAllChanges = true
    open var recordWasChangedBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    @objc open var recordWithIDWasDeletedBlock: ((CKRecord.ID, CKRecord.RecordType) -> Void)?
    @objc open var recordZoneChangeTokensUpdatedBlock: ((CKRecordZone.ID, CKServerChangeToken?, Data?) -> Void)?
    open var recordZoneFetchResultBlock: ((CKRecordZone.ID, Result<(serverChangeToken: CKServerChangeToken, clientChangeTokenData: Data?, moreComing: Bool), Error>) -> Void)?
    open var fetchRecordZoneChangesResultBlock: ((Result<Void, Error>) -> Void)?
    @objc @available(iOS, deprecated: 15.0) open var recordChangedBlock: ((CKRecord) -> Void)? { get { _isim_recordChangedBlock } set { _isim_recordChangedBlock = newValue } }
    @objc var _isim_recordChangedBlock: ((CKRecord) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc @available(iOS, deprecated: 15.0) open var fetchRecordZoneChangesCompletionBlock: ((Error?) -> Void)? { get { _isim_fetchRecordZoneChangesCompletionBlock } set { _isim_fetchRecordZoneChangesCompletionBlock = newValue } }
    @objc var _isim_fetchRecordZoneChangesCompletionBlock: ((Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @objc public override init() { super.init() }
    @objc public convenience init(recordZoneIDs: [CKRecordZone.ID], configurationsByRecordZoneID: [CKRecordZone.ID: ZoneConfiguration]? = nil) {
        self.init(); self.recordZoneIDs = recordZoneIDs; self.configurationsByRecordZoneID = configurationsByRecordZoneID
    }
    @objc open override func main() {
        if let e = db.check(write: false) { fetchRecordZoneChangesResultBlock?(.failure(e)); _isim_fetchRecordZoneChangesCompletionBlock?(e); return }
        for z in recordZoneIDs ?? [] {
            let cfg = configurationsByRecordZoneID?[z]
            let since = cfg?.previousServerChangeToken?.seq ?? 0
            let r: Result<([CKRecord], [(CKRecord.ID, String)], Int, Bool), Error> = db.store.access { d in
                guard db.zoneExists(z, d) else { return .failure(CKError(.zoneNotFound)) }
                enum Change { case record(CKRecord); case deletion(CKRecord.ID, String) }
                var events: [(Int, Change)] = d.records.filter { $0.key.hasPrefix(z.key + "/") && $0.value.seq > since }.map {
                    ($0.value.seq, .record(db.record(from: $0.value, id: CKRecord.ID(recordName: String($0.key.dropFirst(z.key.count + 1)), zoneID: z), desiredKeys: cfg?.desiredKeys)))
                }
                events += d.tombstones.filter { $0.zone == z.zoneName && $0.owner == z.ownerName && $0.seq > since }.map {
                    ($0.seq, .deletion(CKRecord.ID(recordName: $0.name, zoneID: z), $0.type))
                }
                events.sort { $0.0 < $1.0 }
                let limit = (cfg?.resultsLimit ?? 0) > 0 ? cfg!.resultsLimit : Int.max
                let page = Array(events.prefix(limit)); var recs: [CKRecord] = [], dels: [(CKRecord.ID, String)] = []
                for (_, event) in page { switch event { case .record(let r): recs.append(r); case .deletion(let id, let type): dels.append((id, type)) } }
                return .success((recs, dels, page.last?.0 ?? since, page.count < events.count))
            }
            switch r {
            case .success(let (recs, dels, now, more)):
                for rec in recs { recordWasChangedBlock?(rec.recordID, .success(rec)); _isim_recordChangedBlock?(rec) }
                for (id, t) in dels { recordWithIDWasDeletedBlock?(id, t) }
                let token = CKServerChangeToken(now)
                recordZoneChangeTokensUpdatedBlock?(z, token, nil)
                recordZoneFetchResultBlock?(z, .success((token, nil, more)))
            case .failure(let e):
                recordZoneFetchResultBlock?(z, .failure(e))
            }
        }
        fetchRecordZoneChangesResultBlock?(.success(()))
        _isim_fetchRecordZoneChangesCompletionBlock?(nil)
    }
}
