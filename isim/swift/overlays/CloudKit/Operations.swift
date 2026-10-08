// CloudKit operations (isim: CKOperation is an NSObject run on CloudKit's own queue — isim's Foundation has no
// NSOperation — so add operations to a CKDatabase / CKContainer, not to an OperationQueue).
import Foundation

/// Foundation's QualityOfService (isim's Foundation has no NSOperation yet, so CloudKit carries it; move it to
/// Foundation together with Operation/OperationQueue)
public enum QualityOfService: Int, Sendable { case userInteractive = 0x21, userInitiated = 0x19, utility = 0x11, background = 0x09, `default` = -1 }

open class CKOperation: NSObject, @unchecked Sendable {
    public typealias ID = String
    open class Configuration: NSObject, @unchecked Sendable {
        open var container: CKContainer?
        open var qualityOfService: QualityOfService = .default
        open var allowsCellularAccess = true
        open var isLongLived = false
        open var timeoutIntervalForRequest: TimeInterval = 60
        open var timeoutIntervalForResource: TimeInterval = 7 * 86400
    }
    open var configuration: Configuration! = Configuration()
    public let operationID: ID = UUID().uuidString
    open var completionBlock: (() -> Void)?
    open var qualityOfService: QualityOfService = .default
    open var name: String?
    open var longLivedOperationWasPersistedBlock: (() -> Void)?
    public private(set) var isCancelled = false
    public private(set) var isExecuting = false
    public private(set) var isFinished = false
    weak var container: CKContainer?
    open func cancel() { isCancelled = true }
    /// runs the operation now, on the calling thread
    open func start() {
        guard !isFinished else { return }
        isExecuting = true
        main()
        isExecuting = false; isFinished = true
        completionBlock?()
    }
    open func main() {}
    func _enqueue() { CKDatabase.queue.async { self.start() } }
    var cancelledError: Error { CKError(.operationCancelled) }
}

open class CKDatabaseOperation: CKOperation, @unchecked Sendable {
    open var database: CKDatabase?
    var db: CKDatabase { database ?? (container ?? CKContainer.default()).privateCloudDatabase }
}

// MARK: - Query

open class CKQueryOperation: CKDatabaseOperation, @unchecked Sendable {
    public static let maximumResults = 0
    static let defaultPage = 100
    open class Cursor: NSObject, @unchecked Sendable {
        let query: CKQuery, zoneID: CKRecordZone.ID?, offset: Int
        init(_ q: CKQuery, _ z: CKRecordZone.ID?, _ o: Int) { query = q; zoneID = z; offset = o }
    }
    open var query: CKQuery?
    open var cursor: Cursor?
    open var zoneID: CKRecordZone.ID?
    open var resultsLimit: Int = CKQueryOperation.maximumResults
    open var desiredKeys: [CKRecord.FieldKey]?
    open var recordMatchedBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    open var queryResultBlock: ((Result<Cursor?, Error>) -> Void)?
    @available(iOS, deprecated: 15.0) open var recordFetchedBlock: ((CKRecord) -> Void)? { get { _isim_recordFetchedBlock } set { _isim_recordFetchedBlock = newValue } }
    var _isim_recordFetchedBlock: ((CKRecord) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @available(iOS, deprecated: 15.0) open var queryCompletionBlock: ((Cursor?, Error?) -> Void)? { get { _isim_queryCompletionBlock } set { _isim_queryCompletionBlock = newValue } }
    var _isim_queryCompletionBlock: ((Cursor?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    public override init() { super.init() }
    public convenience init(query: CKQuery) { self.init(); self.query = query }
    public convenience init(cursor: Cursor) { self.init(); self.cursor = cursor }

    open override func main() {
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

open class CKModifyRecordsOperation: CKDatabaseOperation, @unchecked Sendable {
    public enum RecordSavePolicy: Int, Sendable { case ifServerRecordUnchanged = 0, changedKeys = 1, allKeys = 2 }
    open var recordsToSave: [CKRecord]?
    open var recordIDsToDelete: [CKRecord.ID]?
    open var savePolicy: RecordSavePolicy = .ifServerRecordUnchanged
    open var clientChangeTokenData: Data?
    open var isAtomic = true
    open var perRecordProgressBlock: ((CKRecord, Double) -> Void)?
    open var perRecordSaveBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    open var perRecordDeleteBlock: ((CKRecord.ID, Result<Void, Error>) -> Void)?
    open var modifyRecordsResultBlock: ((Result<Void, Error>) -> Void)?
    @available(iOS, deprecated: 15.0) open var perRecordCompletionBlock: ((CKRecord, Error?) -> Void)? { get { _isim_perRecordCompletionBlock } set { _isim_perRecordCompletionBlock = newValue } }
    var _isim_perRecordCompletionBlock: ((CKRecord, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @available(iOS, deprecated: 15.0) open var modifyRecordsCompletionBlock: (([CKRecord]?, [CKRecord.ID]?, Error?) -> Void)? { get { _isim_modifyRecordsCompletionBlock } set { _isim_modifyRecordsCompletionBlock = newValue } }
    var _isim_modifyRecordsCompletionBlock: (([CKRecord]?, [CKRecord.ID]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    public override init() { super.init() }
    public convenience init(recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecord.ID]?) {
        self.init(); self.recordsToSave = recordsToSave; self.recordIDsToDelete = recordIDsToDelete
    }

    open override func main() {
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

open class CKFetchRecordsOperation: CKDatabaseOperation, @unchecked Sendable {
    open var recordIDs: [CKRecord.ID]?
    open var desiredKeys: [CKRecord.FieldKey]?
    open var perRecordResultBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    open var fetchRecordsResultBlock: ((Result<Void, Error>) -> Void)?
    @available(iOS, deprecated: 15.0) open var perRecordCompletionBlock: ((CKRecord?, CKRecord.ID?, Error?) -> Void)? { get { _isim_perRecordCompletionBlock } set { _isim_perRecordCompletionBlock = newValue } }
    var _isim_perRecordCompletionBlock: ((CKRecord?, CKRecord.ID?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @available(iOS, deprecated: 15.0) open var fetchRecordsCompletionBlock: (([CKRecord.ID: CKRecord]?, Error?) -> Void)? { get { _isim_fetchRecordsCompletionBlock } set { _isim_fetchRecordsCompletionBlock = newValue } }
    var _isim_fetchRecordsCompletionBlock: (([CKRecord.ID: CKRecord]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    public override init() { super.init() }
    public convenience init(recordIDs: [CKRecord.ID]) { self.init(); self.recordIDs = recordIDs }
    open class func fetchCurrentUserRecordOperation() -> CKFetchRecordsOperation {
        let op = CKFetchRecordsOperation()
        op.recordIDs = [CKRecord.ID(recordName: _CKEnv.userRecordName)]
        return op
    }

    open override func main() {
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

open class CKModifyRecordZonesOperation: CKDatabaseOperation, @unchecked Sendable {
    open var recordZonesToSave: [CKRecordZone]?
    open var recordZoneIDsToDelete: [CKRecordZone.ID]?
    open var perRecordZoneSaveBlock: ((CKRecordZone.ID, Result<CKRecordZone, Error>) -> Void)?
    open var perRecordZoneDeleteBlock: ((CKRecordZone.ID, Result<Void, Error>) -> Void)?
    open var modifyRecordZonesResultBlock: ((Result<Void, Error>) -> Void)?
    @available(iOS, deprecated: 15.0) open var modifyRecordZonesCompletionBlock: (([CKRecordZone]?, [CKRecordZone.ID]?, Error?) -> Void)? { get { _isim_modifyRecordZonesCompletionBlock } set { _isim_modifyRecordZonesCompletionBlock = newValue } }
    var _isim_modifyRecordZonesCompletionBlock: (([CKRecordZone]?, [CKRecordZone.ID]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    public override init() { super.init() }
    public convenience init(recordZonesToSave: [CKRecordZone]?, recordZoneIDsToDelete: [CKRecordZone.ID]?) {
        self.init(); self.recordZonesToSave = recordZonesToSave; self.recordZoneIDsToDelete = recordZoneIDsToDelete
    }
    open override func main() {
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

open class CKModifySubscriptionsOperation: CKDatabaseOperation, @unchecked Sendable {
    open var subscriptionsToSave: [CKSubscription]?
    open var subscriptionIDsToDelete: [CKSubscription.ID]?
    open var perSubscriptionSaveBlock: ((CKSubscription.ID, Result<CKSubscription, Error>) -> Void)?
    open var perSubscriptionDeleteBlock: ((CKSubscription.ID, Result<Void, Error>) -> Void)?
    open var modifySubscriptionsResultBlock: ((Result<Void, Error>) -> Void)?
    @available(iOS, deprecated: 15.0) open var modifySubscriptionsCompletionBlock: (([CKSubscription]?, [CKSubscription.ID]?, Error?) -> Void)? { get { _isim_modifySubscriptionsCompletionBlock } set { _isim_modifySubscriptionsCompletionBlock = newValue } }
    var _isim_modifySubscriptionsCompletionBlock: (([CKSubscription]?, [CKSubscription.ID]?, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    public override init() { super.init() }
    public convenience init(subscriptionsToSave: [CKSubscription]?, subscriptionIDsToDelete: [CKSubscription.ID]?) {
        self.init(); self.subscriptionsToSave = subscriptionsToSave; self.subscriptionIDsToDelete = subscriptionIDsToDelete
    }
    open override func main() {
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
open class CKServerChangeToken: NSObject, NSCopying, NSCoding, @unchecked Sendable {
    let seq: Int
    init(_ s: Int) { seq = s }
    open func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override func isEqual(_ o: Any?) -> Bool { (o as? CKServerChangeToken)?.seq == seq }
    open override var hash: Int { seq }
    /// keep tokens across launches with NSKeyedArchiver (NSCoding)
    public required init?(coder: NSCoder) { seq = coder.decodeInteger(forKey: "seq") }
    open func encode(with coder: NSCoder) { coder.encode(seq, forKey: "seq") }
}

open class CKFetchDatabaseChangesOperation: CKDatabaseOperation, @unchecked Sendable {
    open var previousServerChangeToken: CKServerChangeToken?
    open var resultsLimit = 0
    open var fetchAllChanges = true
    open var recordZoneWithIDChangedBlock: ((CKRecordZone.ID) -> Void)?
    open var recordZoneWithIDWasDeletedBlock: ((CKRecordZone.ID) -> Void)?
    open var recordZoneWithIDWasPurgedBlock: ((CKRecordZone.ID) -> Void)?
    open var changeTokenUpdatedBlock: ((CKServerChangeToken) -> Void)?
    open var fetchDatabaseChangesResultBlock: ((Result<(serverChangeToken: CKServerChangeToken, moreComing: Bool), Error>) -> Void)?
    @available(iOS, deprecated: 15.0) open var fetchDatabaseChangesCompletionBlock: ((CKServerChangeToken?, Bool, Error?) -> Void)? { get { _isim_fetchDatabaseChangesCompletionBlock } set { _isim_fetchDatabaseChangesCompletionBlock = newValue } }
    var _isim_fetchDatabaseChangesCompletionBlock: ((CKServerChangeToken?, Bool, Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    public override init() { super.init() }
    public convenience init(previousServerChangeToken: CKServerChangeToken?) { self.init(); self.previousServerChangeToken = previousServerChangeToken }
    open override func main() {
        if let e = db.check(write: false) { fetchDatabaseChangesResultBlock?(.failure(e)); _isim_fetchDatabaseChangesCompletionBlock?(nil, false, e); return }
        let since = previousServerChangeToken?.seq ?? 0
        let (changed, deleted, now): ([CKRecordZone.ID], [CKRecordZone.ID], Int) = db.store.access { d in
            var ch = d.zones.values.filter { $0.seq > since }.map { CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner) }
            if d.records.contains(where: { $0.value.seq > since && $0.key.hasPrefix(CKRecordZone.ID.default.key + "/") }) || d.tombstones.contains(where: { $0.seq > since && $0.zone == CKRecordZoneDefaultName }) {
                ch.insert(.default, at: 0)
            }
            return (ch, d.deletedZones.filter { $0.seq > since }.map { CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner) }, d.counter)
        }
        changed.forEach { recordZoneWithIDChangedBlock?($0) }
        deleted.forEach { recordZoneWithIDWasDeletedBlock?($0) }
        let token = CKServerChangeToken(now)
        changeTokenUpdatedBlock?(token)
        fetchDatabaseChangesResultBlock?(.success((token, false)))
        _isim_fetchDatabaseChangesCompletionBlock?(token, false, nil)
    }
}

open class CKFetchRecordZoneChangesOperation: CKDatabaseOperation, @unchecked Sendable {
    open class ZoneConfiguration: NSObject, @unchecked Sendable {
        open var previousServerChangeToken: CKServerChangeToken?
        open var resultsLimit = 0
        open var desiredKeys: [CKRecord.FieldKey]?
        public override init() {}
        public convenience init(previousServerChangeToken: CKServerChangeToken? = nil, resultsLimit: Int = 0, desiredKeys: [CKRecord.FieldKey]? = nil) {
            self.init(); self.previousServerChangeToken = previousServerChangeToken; self.resultsLimit = resultsLimit; self.desiredKeys = desiredKeys
        }
    }
    open var recordZoneIDs: [CKRecordZone.ID]?
    open var configurationsByRecordZoneID: [CKRecordZone.ID: ZoneConfiguration]?
    open var fetchAllChanges = true
    open var recordWasChangedBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)?
    open var recordWithIDWasDeletedBlock: ((CKRecord.ID, CKRecord.RecordType) -> Void)?
    open var recordZoneChangeTokensUpdatedBlock: ((CKRecordZone.ID, CKServerChangeToken?, Data?) -> Void)?
    open var recordZoneFetchResultBlock: ((CKRecordZone.ID, Result<(serverChangeToken: CKServerChangeToken, clientChangeTokenData: Data?, moreComing: Bool), Error>) -> Void)?
    open var fetchRecordZoneChangesResultBlock: ((Result<Void, Error>) -> Void)?
    @available(iOS, deprecated: 15.0) open var recordChangedBlock: ((CKRecord) -> Void)? { get { _isim_recordChangedBlock } set { _isim_recordChangedBlock = newValue } }
    var _isim_recordChangedBlock: ((CKRecord) -> Void)?     // the operation calls the deprecated block through this, without a warning
    @available(iOS, deprecated: 15.0) open var fetchRecordZoneChangesCompletionBlock: ((Error?) -> Void)? { get { _isim_fetchRecordZoneChangesCompletionBlock } set { _isim_fetchRecordZoneChangesCompletionBlock = newValue } }
    var _isim_fetchRecordZoneChangesCompletionBlock: ((Error?) -> Void)?     // the operation calls the deprecated block through this, without a warning
    public override init() { super.init() }
    public convenience init(recordZoneIDs: [CKRecordZone.ID], configurationsByRecordZoneID: [CKRecordZone.ID: ZoneConfiguration]? = nil) {
        self.init(); self.recordZoneIDs = recordZoneIDs; self.configurationsByRecordZoneID = configurationsByRecordZoneID
    }
    open override func main() {
        if let e = db.check(write: false) { fetchRecordZoneChangesResultBlock?(.failure(e)); _isim_fetchRecordZoneChangesCompletionBlock?(e); return }
        for z in recordZoneIDs ?? [] {
            let cfg = configurationsByRecordZoneID?[z]
            let since = cfg?.previousServerChangeToken?.seq ?? 0
            let r: Result<([CKRecord], [(CKRecord.ID, String)], Int), Error> = db.store.access { d in
                guard db.zoneExists(z, d) else { return .failure(CKError(.zoneNotFound)) }
                let recs = d.records.filter { $0.key.hasPrefix(z.key + "/") && $0.value.seq > since }.sorted { $0.value.seq < $1.value.seq }
                    .map { db.record(from: $0.value, id: CKRecord.ID(recordName: String($0.key.dropFirst(z.key.count + 1)), zoneID: z), desiredKeys: cfg?.desiredKeys) }
                let dels = d.tombstones.filter { $0.zone == z.zoneName && $0.owner == z.ownerName && $0.seq > since }.map { (CKRecord.ID(recordName: $0.name, zoneID: z), $0.type) }
                return .success((recs, dels, d.counter))
            }
            switch r {
            case .success(let (recs, dels, now)):
                for rec in recs { recordWasChangedBlock?(rec.recordID, .success(rec)); _isim_recordChangedBlock?(rec) }
                for (id, t) in dels { recordWithIDWasDeletedBlock?(id, t) }
                let token = CKServerChangeToken(now)
                recordZoneChangeTokensUpdatedBlock?(z, token, nil)
                recordZoneFetchResultBlock?(z, .success((token, nil, false)))
            case .failure(let e):
                recordZoneFetchResultBlock?(z, .failure(e))
            }
        }
        fetchRecordZoneChangesResultBlock?(.success(()))
        _isim_fetchRecordZoneChangesCompletionBlock?(nil)
    }
}
