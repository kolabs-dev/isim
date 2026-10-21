// CKSyncEngine (iOS 17) with Apple's API, adapted to isim's local CloudKit database: the "server" is the device's
// store for the container (every engine and app on the device that uses the container sees the same records), so
// fetches return what other engines or apps wrote since this engine's tokens, and sends write the delegate's batches
// there. Nothing reaches iCloud.
import Foundation

public protocol CKSyncEngineDelegate: AnyObject, Sendable {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async
    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch?
    func nextFetchChangesOptions(_ context: CKSyncEngine.FetchChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.FetchChangesOptions
}
extension CKSyncEngineDelegate {
    public func nextFetchChangesOptions(_ context: CKSyncEngine.FetchChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.FetchChangesOptions { context.options }
}

/// A group of related operations (CloudKit's telemetry and default configuration for them); isim keeps the values.
@objc(CKOperationGroup) @objcMembers open class CKOperationGroup: NSObject, NSSecureCoding, @unchecked Sendable {
    public enum TransferSize: Int, Sendable {
        case unknown = 0, kilobytes = 1, megabytes = 2, tensOfMegabytes = 3, hundredsOfMegabytes = 4, gigabytes = 5, tensOfGigabytes = 6, hundredsOfGigabytes = 7
    }
    open private(set) var operationGroupID: String
    open var defaultConfiguration: CKOperation.Configuration! = CKOperation.Configuration()
    open var name: String?
    open var quantity: Int = 0
    open var expectedSendSize: TransferSize = .unknown
    open var expectedReceiveSize: TransferSize = .unknown
    public override init() { operationGroupID = UUID().uuidString; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        operationGroupID = coder.decodeObject(of: NSString.self, forKey: "operationGroupID") as String? ?? UUID().uuidString
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        quantity = coder.decodeInteger(forKey: "quantity")
        expectedSendSize = TransferSize(rawValue: coder.decodeInteger(forKey: "expectedSendSize")) ?? .unknown
        expectedReceiveSize = TransferSize(rawValue: coder.decodeInteger(forKey: "expectedReceiveSize")) ?? .unknown
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(operationGroupID as NSString, forKey: "operationGroupID")
        if let name { coder.encode(name as NSString, forKey: "name") }
        coder.encode(quantity, forKey: "quantity")
        coder.encode(expectedSendSize.rawValue, forKey: "expectedSendSize")
        coder.encode(expectedReceiveSize.rawValue, forKey: "expectedReceiveSize")
    }
}

extension CKDatabase {
    /// Changes to a database's zones (what fetching database changes returns).
    public enum DatabaseChange: Sendable {
        public struct Modification: Sendable { public var zoneID: CKRecordZone.ID }
        public struct Deletion: Sendable {
            public enum Reason: Sendable, Hashable { case deleted, purged, encryptedDataReset }
            public var zoneID: CKRecordZone.ID
            public var reason: Reason
            public var purged: Bool { reason == .purged }
        }
    }
    /// Changes to a zone's records (what fetching record zone changes returns).
    public enum RecordZoneChange: @unchecked Sendable {
        public struct Modification: @unchecked Sendable { public var record: CKRecord }
        public struct Deletion: Sendable { public var recordID: CKRecord.ID; public var recordType: CKRecord.RecordType }
    }
}

// Objective-C's names for the engine's kinds (isim: Swift enums; CloudKit has no Objective-C interface on isim yet).
@objc public enum CKSyncEngineEventType: Int, Sendable {
    case stateUpdate = 0, accountChange, fetchedDatabaseChanges, fetchedRecordZoneChanges, sentDatabaseChanges, sentRecordZoneChanges
    case willFetchChanges, willFetchRecordZoneChanges, didFetchRecordZoneChanges, didFetchChanges, willSendChanges, didSendChanges
}
@objc public enum CKSyncEngineAccountChangeType: Int, Sendable { case signIn = 0, signOut, switchAccounts }
@objc public enum CKSyncEngineZoneDeletionReason: Int, Sendable { case deleted = 0, purged, encryptedDataReset }
@objc public enum CKSyncEngineSyncReason: Int, Sendable { case scheduled = 0, manual }
@objc public enum CKSyncEnginePendingRecordZoneChangeType: Int, Sendable { case saveRecord = 0, deleteRecord }
@objc public enum CKSyncEnginePendingDatabaseChangeType: Int, Sendable { case saveZone = 0, deleteZone }

public final class CKSyncEngine: @unchecked Sendable {
    public struct Configuration: @unchecked Sendable {
        public var database: CKDatabase
        public var stateSerialization: State.Serialization?
        public var delegate: any CKSyncEngineDelegate
        /// Fetch when the engine starts, and send shortly after pending changes are added.
        public var automaticallySync: Bool = true
        public var subscriptionID: CKSubscription.ID?
        public init(database: CKDatabase, stateSerialization: State.Serialization?, delegate: any CKSyncEngineDelegate) {
            self.database = database; self.stateSerialization = stateSerialization; self.delegate = delegate
        }
    }

    public enum SyncReason: Hashable, Sendable { case scheduled, manual }

    public enum PendingRecordZoneChange: Hashable, Sendable, CustomStringConvertible {
        case saveRecord(CKRecord.ID)
        case deleteRecord(CKRecord.ID)
        var recordID: CKRecord.ID { switch self { case .saveRecord(let id), .deleteRecord(let id): id } }
        public var description: String {
            switch self { case .saveRecord(let id): "saveRecord(\(id.recordName))"; case .deleteRecord(let id): "deleteRecord(\(id.recordName))" }
        }
    }
    public enum PendingDatabaseChange: Hashable, Sendable {
        case saveZone(CKRecordZone)
        case deleteZone(CKRecordZone.ID)
        var zoneID: CKRecordZone.ID { switch self { case .saveZone(let z): z.zoneID; case .deleteZone(let id): id } }
        public static func == (a: PendingDatabaseChange, b: PendingDatabaseChange) -> Bool {
            switch (a, b) {
            case (.saveZone(let x), .saveZone(let y)): x.zoneID == y.zoneID
            case (.deleteZone(let x), .deleteZone(let y)): x == y
            default: false
            }
        }
        public func hash(into h: inout Hasher) {
            switch self { case .saveZone(let z): h.combine(0); h.combine(z.zoneID); case .deleteZone(let id): h.combine(1); h.combine(id) }
        }
    }

    /// What the engine must remember between launches: pending changes and the change tokens. Persist the serialization
    /// from each `.stateUpdate` event and pass it to the next engine.
    public final class State: @unchecked Sendable, CustomStringConvertible {
        public struct Serialization: Codable, Hashable, Sendable, CustomStringConvertible {
            let data: Data
            init(_ data: Data) { self.data = data }
            public init(from decoder: Decoder) throws { data = try decoder.singleValueContainer().decode(Data.self) }
            public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(data) }
            public var description: String { "CKSyncEngine.State.Serialization(\(data.count) bytes)" }
        }
        struct Snapshot: Codable {
            var records: [String] = []                   // "kind|owner|zone|name"
            var zones: [String] = []                     // "kind|owner|zone"
            var untracked = false
            var databaseToken = 0                        // the store's counter at the last database fetch
            var zoneTokens: [String: Int] = [:]          // owner/zone -> counter at its last fetch
            var ownWrites: [String: Int] = [:]           // owner/zone/name -> seq this engine wrote (not fetched back)
            var user: String?                            // the account the state belongs to
        }
        let lock = NSLock()
        var snap = Snapshot()
        weak var engine: CKSyncEngine?
        init(_ serialization: Serialization?) {
            if let data = serialization?.data, let s = try? JSONDecoder().decode(Snapshot.self, from: data) { snap = s }
        }
        func locked<T>(_ body: (inout Snapshot) -> T) -> T { lock.lock(); defer { lock.unlock() }; return body(&snap) }
        var serialization: Serialization { Serialization((try? JSONEncoder().encode(locked { $0 })) ?? Data()) }

        public var pendingRecordZoneChanges: [PendingRecordZoneChange] { locked { $0.records }.compactMap(Self.decodeRecord) }
        public var pendingDatabaseChanges: [PendingDatabaseChange] { locked { $0.zones }.compactMap(Self.decodeZone) }
        /// Set when the app has changes it does not track as pending record zone changes; the next send asks for batches.
        public var hasPendingUntrackedChanges: Bool {
            get { locked { $0.untracked } }
            set { locked { $0.untracked = newValue }; if newValue { engine?.scheduleSend() } }
        }
        /// The zones with records changed in the store since this engine last fetched them.
        public var zoneIDsWithUnfetchedServerChanges: [CKRecordZone.ID] {
            guard let engine else { return [] }
            let tokens = locked { $0.zoneTokens }
            return engine.database.store.access { db in
                var latest: [String: Int] = [:]
                for (key, r) in db.records { let z = key.split(separator: "/").prefix(2).joined(separator: "/"); latest[z] = max(latest[z] ?? 0, r.seq) }
                for t in db.tombstones { let z = "\(t.owner)/\(t.zone)"; latest[z] = max(latest[z] ?? 0, t.seq) }
                return latest.filter { $0.value > (tokens[$0.key] ?? 0) }.keys.sorted().compactMap(Self.zoneID)
            }
        }
        public func add(pendingRecordZoneChanges changes: [PendingRecordZoneChange]) {
            locked { s in for c in changes { let k = Self.encode(c); if !s.records.contains(k) { s.records.append(k) } } }
            if !changes.isEmpty { engine?.scheduleSend() }
        }
        public func remove(pendingRecordZoneChanges changes: [PendingRecordZoneChange]) {
            let keys = Set(changes.map(Self.encode))
            locked { $0.records.removeAll { keys.contains($0) } }
        }
        public func add(pendingDatabaseChanges changes: [PendingDatabaseChange]) {
            locked { s in for c in changes { let k = Self.encode(c); if !s.zones.contains(k) { s.zones.append(k) } } }
            if !changes.isEmpty { engine?.scheduleSend() }
        }
        public func remove(pendingDatabaseChanges changes: [PendingDatabaseChange]) {
            let keys = Set(changes.map(Self.encode))
            locked { $0.zones.removeAll { keys.contains($0) } }
        }
        public var description: String {
            "CKSyncEngine.State(pendingRecordZoneChanges: \(pendingRecordZoneChanges), pendingDatabaseChanges: \(pendingDatabaseChanges.count), hasPendingUntrackedChanges: \(hasPendingUntrackedChanges))"
        }

        static func encode(_ c: PendingRecordZoneChange) -> String {
            let id = c.recordID
            if case .saveRecord = c { return "save|\(id.zoneID.ownerName)|\(id.zoneID.zoneName)|\(id.recordName)" }
            return "delete|\(id.zoneID.ownerName)|\(id.zoneID.zoneName)|\(id.recordName)"
        }
        static func decodeRecord(_ s: String) -> PendingRecordZoneChange? {
            let p = s.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            guard p.count == 4 else { return nil }
            let id = CKRecord.ID(recordName: p[3], zoneID: CKRecordZone.ID(zoneName: p[2], ownerName: p[1]))
            return p[0] == "save" ? .saveRecord(id) : .deleteRecord(id)
        }
        static func encode(_ c: PendingDatabaseChange) -> String {
            let z = c.zoneID
            if case .saveZone = c { return "save|\(z.ownerName)|\(z.zoneName)" }
            return "delete|\(z.ownerName)|\(z.zoneName)"
        }
        static func decodeZone(_ s: String) -> PendingDatabaseChange? {
            let p = s.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard p.count == 3 else { return nil }
            let id = CKRecordZone.ID(zoneName: p[2], ownerName: p[1])
            return p[0] == "save" ? .saveZone(CKRecordZone(zoneID: id)) : .deleteZone(id)
        }
        static func zoneID(_ key: String) -> CKRecordZone.ID? {
            let p = key.split(separator: "/", maxSplits: 1).map(String.init)
            return p.count == 2 ? CKRecordZone.ID(zoneName: p[1], ownerName: p[0]) : nil
        }
    }

    public struct RecordZoneChangeBatch: @unchecked Sendable {
        public var recordsToSave: [CKRecord]
        public var recordIDsToDelete: [CKRecord.ID]
        public var atomicByZone: Bool
        public init(recordsToSave: [CKRecord] = [], recordIDsToDelete: [CKRecord.ID] = [], atomicByZone: Bool = false) {
            self.recordsToSave = recordsToSave; self.recordIDsToDelete = recordIDsToDelete; self.atomicByZone = atomicByZone
        }
        /// The pending changes as a batch (the saves' records from `recordProvider`; a save it has no record for is
        /// left out); nil when there is nothing to send.
        public init?(pendingChanges: [PendingRecordZoneChange], recordProvider: (CKRecord.ID) async -> CKRecord?) async {
            var saves: [CKRecord] = [], deletes: [CKRecord.ID] = []
            for change in pendingChanges {
                switch change {
                case .saveRecord(let id): if let r = await recordProvider(id) { saves.append(r) }
                case .deleteRecord(let id): deletes.append(id)
                }
            }
            if saves.isEmpty && deletes.isEmpty { return nil }
            self.init(recordsToSave: saves, recordIDsToDelete: deletes)
        }
    }

    public struct FetchChangesOptions: @unchecked Sendable {
        public enum Scope: Hashable, Sendable {
            case all
            case zoneIDs([CKRecordZone.ID])
            case allExcluding([CKRecordZone.ID])
            public func contains(_ zoneID: CKRecordZone.ID) -> Bool {
                switch self { case .all: true; case .zoneIDs(let z): z.contains(zoneID); case .allExcluding(let z): !z.contains(zoneID) }
            }
        }
        public var scope: Scope
        public var operationGroup: CKOperationGroup
        /// Zones fetched before the others.
        public var prioritizedZoneIDs: [CKRecordZone.ID] = []
        public init(scope: Scope = .all, operationGroup: CKOperationGroup? = nil) { self.scope = scope; self.operationGroup = operationGroup ?? CKOperationGroup() }
    }
    public struct SendChangesOptions: @unchecked Sendable {
        public enum Scope: Hashable, Sendable {
            case all
            case zoneIDs([CKRecordZone.ID])
            case allExcluding([CKRecordZone.ID])
            case recordIDs([CKRecord.ID])
            public func contains(_ recordID: CKRecord.ID) -> Bool {
                switch self {
                case .all: true
                case .zoneIDs(let z): z.contains(recordID.zoneID)
                case .allExcluding(let z): !z.contains(recordID.zoneID)
                case .recordIDs(let ids): ids.contains(recordID)
                }
            }
            public func contains(_ pendingRecordZoneChange: PendingRecordZoneChange) -> Bool { contains(pendingRecordZoneChange.recordID) }
            func contains(zone: CKRecordZone.ID) -> Bool {
                switch self { case .all: true; case .zoneIDs(let z): z.contains(zone); case .allExcluding(let z): !z.contains(zone); case .recordIDs: false }
            }
        }
        public var scope: Scope
        public var operationGroup: CKOperationGroup
        public init(scope: Scope = .all, operationGroup: CKOperationGroup? = nil) { self.scope = scope; self.operationGroup = operationGroup ?? CKOperationGroup() }
    }
    public struct FetchChangesContext: @unchecked Sendable { public let reason: SyncReason; public let options: FetchChangesOptions }
    public struct SendChangesContext: @unchecked Sendable { public let reason: SyncReason; public let options: SendChangesOptions }

    public enum Event: @unchecked Sendable, CustomStringConvertible {
        case stateUpdate(StateUpdate)
        case accountChange(AccountChange)
        case fetchedDatabaseChanges(FetchedDatabaseChanges)
        case fetchedRecordZoneChanges(FetchedRecordZoneChanges)
        case sentDatabaseChanges(SentDatabaseChanges)
        case sentRecordZoneChanges(SentRecordZoneChanges)
        case willFetchChanges(WillFetchChanges)
        case willFetchRecordZoneChanges(WillFetchRecordZoneChanges)
        case didFetchRecordZoneChanges(DidFetchRecordZoneChanges)
        case didFetchChanges(DidFetchChanges)
        case willSendChanges(WillSendChanges)
        case didSendChanges(DidSendChanges)

        public struct StateUpdate: Sendable { public let stateSerialization: State.Serialization }
        public struct AccountChange: Sendable {
            public enum ChangeType: Sendable {
                case signIn(currentUser: CKRecord.ID)
                case signOut(previousUser: CKRecord.ID)
                case switchAccounts(previousUser: CKRecord.ID, currentUser: CKRecord.ID)
            }
            public let changeType: ChangeType
        }
        public struct FetchedDatabaseChanges: Sendable {
            public let modifications: [CKDatabase.DatabaseChange.Modification]
            public let deletions: [CKDatabase.DatabaseChange.Deletion]
        }
        public struct FetchedRecordZoneChanges: @unchecked Sendable {
            public let modifications: [CKDatabase.RecordZoneChange.Modification]
            public let deletions: [CKDatabase.RecordZoneChange.Deletion]
        }
        public struct SentDatabaseChanges: @unchecked Sendable {
            public struct FailedZoneSave: @unchecked Sendable { public let zone: CKRecordZone; public let error: CKError }
            public let savedZones: [CKRecordZone]
            public let failedZoneSaves: [FailedZoneSave]
            public let deletedZoneIDs: [CKRecordZone.ID]
            public let failedZoneDeletes: [CKRecordZone.ID: CKError]
        }
        public struct SentRecordZoneChanges: @unchecked Sendable {
            public struct FailedRecordSave: @unchecked Sendable { public let record: CKRecord; public let error: CKError }
            public let savedRecords: [CKRecord]
            public let failedRecordSaves: [FailedRecordSave]
            public let deletedRecordIDs: [CKRecord.ID]
            public let failedRecordDeletes: [CKRecord.ID: CKError]
        }
        public struct WillFetchChanges: @unchecked Sendable { public let context: FetchChangesContext }
        public struct WillFetchRecordZoneChanges: Sendable { public let zoneID: CKRecordZone.ID }
        public struct DidFetchRecordZoneChanges: Sendable { public let zoneID: CKRecordZone.ID; public let error: CKError? }
        public struct DidFetchChanges: @unchecked Sendable { public let context: FetchChangesContext }
        public struct WillSendChanges: @unchecked Sendable { public let context: SendChangesContext }
        public struct DidSendChanges: @unchecked Sendable { public let context: SendChangesContext }

        public var description: String {
            switch self {
            case .stateUpdate: "stateUpdate"
            case .accountChange(let a):
                switch a.changeType { case .signIn: "accountChange(signIn)"; case .signOut: "accountChange(signOut)"; case .switchAccounts: "accountChange(switchAccounts)" }
            case .fetchedDatabaseChanges(let e): "fetchedDatabaseChanges(\(e.modifications.count) modified, \(e.deletions.count) deleted)"
            case .fetchedRecordZoneChanges(let e): "fetchedRecordZoneChanges(\(e.modifications.count) modified, \(e.deletions.count) deleted)"
            case .sentDatabaseChanges(let e): "sentDatabaseChanges(\(e.savedZones.count) saved, \(e.deletedZoneIDs.count) deleted, \(e.failedZoneSaves.count + e.failedZoneDeletes.count) failed)"
            case .sentRecordZoneChanges(let e): "sentRecordZoneChanges(\(e.savedRecords.count) saved, \(e.deletedRecordIDs.count) deleted, \(e.failedRecordSaves.count + e.failedRecordDeletes.count) failed)"
            case .willFetchChanges: "willFetchChanges"
            case .willFetchRecordZoneChanges(let e): "willFetchRecordZoneChanges(\(e.zoneID.zoneName))"
            case .didFetchRecordZoneChanges(let e): "didFetchRecordZoneChanges(\(e.zoneID.zoneName))"
            case .didFetchChanges: "didFetchChanges"
            case .willSendChanges: "willSendChanges"
            case .didSendChanges: "didSendChanges"
            }
        }
    }

    public let database: CKDatabase
    public let state: State
    private weak var delegate: (any CKSyncEngineDelegate)?
    private let automaticallySync: Bool
    private let lock = NSLock()
    private var sendScheduled = false, cancelled = false
    private let serial = _CKSerialQueue()                          // syncs run one after another, like Apple's engine

    public init(_ configuration: Configuration) {
        database = configuration.database
        state = State(configuration.stateSerialization)
        delegate = configuration.delegate
        automaticallySync = configuration.automaticallySync
        state.engine = self
        if automaticallySync {
            Task { [weak self] in try? await self?.fetch(FetchChangesOptions(), reason: .scheduled) }
            if !state.pendingRecordZoneChanges.isEmpty || !state.pendingDatabaseChanges.isEmpty { scheduleSend() }
        }
    }

    @nonobjc public func fetchChanges(_ options: FetchChangesOptions = FetchChangesOptions()) async throws { try await fetch(options, reason: .manual) }
    @nonobjc public func sendChanges(_ options: SendChangesOptions = SendChangesOptions()) async throws { try await send(options, reason: .manual) }
    /// Cancels the automatic syncs that are scheduled (isim's syncs run to completion once started).
    @nonobjc public func cancelOperations() async { lock.lock(); cancelled = true; sendScheduled = false; lock.unlock() }

    func scheduleSend() {
        guard automaticallySync else { return }
        lock.lock()
        if sendScheduled { lock.unlock(); return }
        sendScheduled = true; cancelled = false
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.lock.lock(); let go = self.sendScheduled && !self.cancelled; self.sendScheduled = false; self.lock.unlock()
            if go { Task { try? await self.send(SendChangesOptions(), reason: .scheduled) } }
        }
    }

    private func emit(_ event: Event) async { await delegate?.handleEvent(event, syncEngine: self) }

    /// signIn / signOut / switchAccounts when the device's account differs from the one the state belongs to
    private func checkAccount() async {
        let current = _CKEnv.accountStatus == .available ? _CKEnv.userRecordName : nil
        let previous = state.locked { $0.user }
        guard current != previous else { return }
        state.locked { $0.user = current }
        let change: Event.AccountChange.ChangeType
        switch (previous, current) {
        case (nil, let c?): change = .signIn(currentUser: CKRecord.ID(recordName: c))
        case (let p?, nil): change = .signOut(previousUser: CKRecord.ID(recordName: p))
        case (let p?, let c?): change = .switchAccounts(previousUser: CKRecord.ID(recordName: p), currentUser: CKRecord.ID(recordName: c))
        default: return
        }
        await emit(.accountChange(Event.AccountChange(changeType: change)))
    }

    private func fetch(_ requested: FetchChangesOptions, reason: SyncReason) async throws {
        guard let delegate else { return }
        try await serial.run {
            await self.checkAccount()
            var options = requested
            if reason == .scheduled { options = await delegate.nextFetchChangesOptions(FetchChangesContext(reason: reason, options: requested), syncEngine: self) }
            let context = FetchChangesContext(reason: reason, options: options)
            if let e = self.database.check(write: false) { throw e }
            await self.emit(.willFetchChanges(Event.WillFetchChanges(context: context)))
            let (dbToken, zoneTokens, own) = self.state.locked { ($0.databaseToken, $0.zoneTokens, $0.ownWrites) }
            struct ZoneChanges { var zone: CKRecordZone.ID; var modified: [CKRecord] = []; var deleted: [CKDatabase.RecordZoneChange.Deletion] = []; var seen: [String] = [] }
            let (zoneMods, zoneDels, perZone, counter): ([CKRecordZone.ID], [CKRecordZone.ID], [ZoneChanges], Int) = self.database.store.access { db in
                let mods = db.zones.values.filter { $0.seq > dbToken }.map { CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner) }
                let dels = db.deletedZones.filter { $0.seq > dbToken }.map { CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner) }
                var byZone: [String: ZoneChanges] = [:]
                for (key, stored) in db.records {
                    let c = key.split(separator: "/", maxSplits: 2).map(String.init)
                    guard c.count == 3 else { continue }
                    let zkey = "\(c[0])/\(c[1])"
                    guard stored.seq > (zoneTokens[zkey] ?? 0) else { continue }
                    let zid = CKRecordZone.ID(zoneName: c[1], ownerName: c[0])
                    guard options.scope.contains(zid) else { continue }
                    if own[key] == stored.seq { byZone[zkey, default: ZoneChanges(zone: zid)].seen.append(key); continue }   // this engine's own write
                    byZone[zkey, default: ZoneChanges(zone: zid)].modified.append(self.database.record(from: stored, id: CKRecord.ID(recordName: c[2], zoneID: zid)))
                }
                for t in db.tombstones {
                    let zkey = "\(t.owner)/\(t.zone)", key = "\(zkey)/\(t.name)"
                    guard t.seq > (zoneTokens[zkey] ?? 0) else { continue }
                    let zid = CKRecordZone.ID(zoneName: t.zone, ownerName: t.owner)
                    guard options.scope.contains(zid) else { continue }
                    if own[key] == -t.seq { byZone[zkey, default: ZoneChanges(zone: zid)].seen.append(key); continue }
                    byZone[zkey, default: ZoneChanges(zone: zid)].deleted.append(CKDatabase.RecordZoneChange.Deletion(recordID: CKRecord.ID(recordName: t.name, zoneID: zid), recordType: t.type))
                }
                let first = Set(options.prioritizedZoneIDs)
                let ordered = byZone.values.sorted { a, b in
                    let pa = first.contains(a.zone), pb = first.contains(b.zone)
                    return pa != pb ? pa : (a.zone.ownerName, a.zone.zoneName) < (b.zone.ownerName, b.zone.zoneName)
                }
                return (mods, dels, ordered, db.counter)
            }
            if !zoneMods.isEmpty || !zoneDels.isEmpty {
                await self.emit(.fetchedDatabaseChanges(Event.FetchedDatabaseChanges(
                    modifications: zoneMods.map { CKDatabase.DatabaseChange.Modification(zoneID: $0) },
                    deletions: zoneDels.map { CKDatabase.DatabaseChange.Deletion(zoneID: $0, reason: .deleted) })))
            }
            self.state.locked { $0.databaseToken = counter }
            for z in perZone {
                let zkey = "\(z.zone.ownerName)/\(z.zone.zoneName)"
                if !z.modified.isEmpty || !z.deleted.isEmpty {
                    await self.emit(.willFetchRecordZoneChanges(Event.WillFetchRecordZoneChanges(zoneID: z.zone)))
                    await self.emit(.fetchedRecordZoneChanges(Event.FetchedRecordZoneChanges(
                        modifications: z.modified.map { CKDatabase.RecordZoneChange.Modification(record: $0) }, deletions: z.deleted)))
                    await self.emit(.didFetchRecordZoneChanges(Event.DidFetchRecordZoneChanges(zoneID: z.zone, error: nil)))
                }
                self.state.locked { s in s.zoneTokens[zkey] = counter; for k in z.seen { s.ownWrites[k] = nil } }
            }
            await self.emit(.stateUpdate(Event.StateUpdate(stateSerialization: self.state.serialization)))
            await self.emit(.didFetchChanges(Event.DidFetchChanges(context: context)))
        }
    }

    private func send(_ options: SendChangesOptions, reason: SyncReason) async throws {
        guard let delegate else { return }
        try await serial.run {
            await self.checkAccount()
            if let e = self.database.check(write: true) { throw e }
            let context = SendChangesContext(reason: reason, options: options)
            await self.emit(.willSendChanges(Event.WillSendChanges(context: context)))
            // zones first
            let zoneChanges = self.state.pendingDatabaseChanges.filter { options.scope.contains(zone: $0.zoneID) }
            if !zoneChanges.isEmpty {
                var saved: [CKRecordZone] = [], failedSaves: [Event.SentDatabaseChanges.FailedZoneSave] = []
                var deleted: [CKRecordZone.ID] = [], failedDeletes: [CKRecordZone.ID: CKError] = [:]
                let zones = zoneChanges.compactMap { if case .saveZone(let z) = $0 { z } else { nil } }
                for (id, result) in self.database._saveZones(zones) {
                    switch result {
                    case .success(let z): saved.append(z); self.state.remove(pendingDatabaseChanges: [.saveZone(z)])
                    case .failure(let e): failedSaves.append(.init(zone: zones.first { $0.zoneID == id } ?? CKRecordZone(zoneID: id), error: Self.ckError(e)))
                    }
                }
                let ids = zoneChanges.compactMap { if case .deleteZone(let id) = $0 { id } else { nil } }
                for (id, result) in self.database._deleteZones(ids) {
                    switch result {
                    case .success: deleted.append(id); self.state.remove(pendingDatabaseChanges: [.deleteZone(id)])
                    case .failure(let e): failedDeletes[id] = Self.ckError(e)
                    }
                }
                await self.emit(.sentDatabaseChanges(Event.SentDatabaseChanges(savedZones: saved, failedZoneSaves: failedSaves, deletedZoneIDs: deleted, failedZoneDeletes: failedDeletes)))
            }
            // then the delegate's batches, until it has none (or a batch changes nothing)
            var previous: Set<String>?
            while !self.state.pendingRecordZoneChanges.filter({ options.scope.contains($0) }).isEmpty || self.state.hasPendingUntrackedChanges {
                guard let batch = await delegate.nextRecordZoneChangeBatch(context, syncEngine: self) else { break }
                let keys = Set(batch.recordsToSave.map { "s\($0.recordID.key)" } + batch.recordIDsToDelete.map { "d\($0.key)" })
                if keys.isEmpty || keys == previous { break }
                previous = keys
                var saved: [CKRecord] = [], failedSaves: [Event.SentRecordZoneChanges.FailedRecordSave] = []
                var deleted: [CKRecord.ID] = [], failedDeletes: [CKRecord.ID: CKError] = [:]
                let byID = Dictionary(batch.recordsToSave.map { ($0.recordID, $0) }, uniquingKeysWith: { _, b in b })
                for (id, result) in self.database._save(batch.recordsToSave, policy: .ifServerRecordUnchanged, atomic: batch.atomicByZone) {
                    switch result {
                    case .success(let r): saved.append(r); self.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
                    case .failure(let e): failedSaves.append(.init(record: byID[id] ?? CKRecord(recordType: "", recordID: id), error: Self.ckError(e)))
                    }
                }
                for (id, result) in self.database._delete(batch.recordIDsToDelete) {
                    switch result {
                    case .success: deleted.append(id); self.state.remove(pendingRecordZoneChanges: [.deleteRecord(id)])
                    case .failure(let e): failedDeletes[id] = Self.ckError(e)
                    }
                }
                // remember this engine's writes, so fetches do not hand them back
                let savedKeys = saved.map(\.recordID.key), deletedKeys = deleted.map(\.key)
                self.database.store.access { db in
                    self.state.locked { s in
                        for k in savedKeys { if let r = db.records[k] { s.ownWrites[k] = r.seq } }
                        for k in deletedKeys {
                            let c = k.split(separator: "/", maxSplits: 2).map(String.init)
                            if c.count == 3, let t = db.tombstones.last(where: { $0.owner == c[0] && $0.zone == c[1] && $0.name == c[2] }) { s.ownWrites[k] = -t.seq }
                        }
                    }
                }
                await self.emit(.sentRecordZoneChanges(Event.SentRecordZoneChanges(savedRecords: saved, failedRecordSaves: failedSaves, deletedRecordIDs: deleted, failedRecordDeletes: failedDeletes)))
            }
            self.state.locked { $0.untracked = false }
            await self.emit(.stateUpdate(Event.StateUpdate(stateSerialization: self.state.serialization)))
            await self.emit(.didSendChanges(Event.DidSendChanges(context: context)))
        }
    }

    static func ckError(_ e: Error) -> CKError { e as? CKError ?? CKError(.internalError, userInfo: [NSUnderlyingErrorKey: e]) }
}

/// Runs async work one item at a time, in order.
final class _CKSerialQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var tail: Task<Void, Never>?
    func run(_ work: @escaping @Sendable () async throws -> Void) async throws {
        lock.lock()
        let previous = tail
        let task = Task<Result<Void, Error>, Never> { await previous?.value; do { try await work(); return .success(()) } catch { return .failure(error) } }
        tail = Task { _ = await task.value }
        lock.unlock()
        try await task.value.get()
    }
}
