// CKSyncEngine adapted to isim's persistent local CloudKit database. It drives the same delegate/batch workflow,
// persists pending changes in State.Serialization, and emits fetch/send events; it does not contact iCloud.
import Foundation

public protocol CKSyncEngineDelegate: AnyObject {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async
    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch?
}

public final class CKSyncEngine: @unchecked Sendable {
    public struct Configuration: @unchecked Sendable {
        public var database: CKDatabase
        public var stateSerialization: State.Serialization?
        public weak var delegate: (any CKSyncEngineDelegate)?
        public var automaticallySync = true
        public init(database: CKDatabase, stateSerialization: State.Serialization? = nil, delegate: any CKSyncEngineDelegate) {
            self.database = database; self.stateSerialization = stateSerialization; self.delegate = delegate
        }
    }

    public final class State: @unchecked Sendable {
        public struct Serialization: Codable, Hashable, Sendable { public let data: Data; public init(_ data: Data) { self.data = data } }
        private struct Snapshot: Codable { var pending: [String]; var token: Int }
        public private(set) var pendingRecordZoneChanges: [PendingRecordZoneChange] = []
        var token = 0
        init(_ serialization: Serialization?) {
            guard let data = serialization?.data, let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
            token = s.token
            pendingRecordZoneChanges = s.pending.compactMap(PendingRecordZoneChange.decode)
        }
        public var serialization: Serialization {
            Serialization((try? JSONEncoder().encode(Snapshot(pending: pendingRecordZoneChanges.map(\.encoded), token: token))) ?? Data())
        }
        public func add(pendingRecordZoneChanges changes: [PendingRecordZoneChange]) {
            for change in changes { pendingRecordZoneChanges.removeAll { $0.recordID == change.recordID }; pendingRecordZoneChanges.append(change) }
        }
        public func remove(pendingRecordZoneChanges changes: [PendingRecordZoneChange]) {
            let keys = Set(changes.map(\.encoded)); pendingRecordZoneChanges.removeAll { keys.contains($0.encoded) }
        }
    }

    public struct PendingRecordZoneChange: Hashable, Sendable {
        public enum ChangeType: Int, Sendable { case saveRecord = 0, deleteRecord = 1 }
        public let recordID: CKRecord.ID
        public let type: ChangeType
        public init(recordID: CKRecord.ID, type: ChangeType) { self.recordID = recordID; self.type = type }
        var encoded: String { "\(type.rawValue)|\(recordID.zoneID.ownerName)|\(recordID.zoneID.zoneName)|\(recordID.recordName)" }
        static func decode(_ value: String) -> Self? {
            let p = value.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard p.count == 4, let raw = Int(p[0]), let type = ChangeType(rawValue: raw) else { return nil }
            return Self(recordID: CKRecord.ID(recordName: p[3], zoneID: CKRecordZone.ID(zoneName: p[2], ownerName: p[1])), type: type)
        }
    }

    public struct RecordZoneChangeBatch: @unchecked Sendable {
        public var recordsToSave: [CKRecord]
        public var recordIDsToDelete: [CKRecord.ID]
        public var atomicByZone: Bool
        public init(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID], atomicByZone: Bool = true) {
            self.recordsToSave = recordsToSave; self.recordIDsToDelete = recordIDsToDelete; self.atomicByZone = atomicByZone
        }
        public init?(pendingChanges: [PendingRecordZoneChange], recordProvider: (CKRecord.ID) -> CKRecord?) {
            recordsToSave = pendingChanges.filter { $0.type == .saveRecord }.compactMap { recordProvider($0.recordID) }
            recordIDsToDelete = pendingChanges.filter { $0.type == .deleteRecord }.map(\.recordID)
            atomicByZone = true
            if recordsToSave.isEmpty && recordIDsToDelete.isEmpty { return nil }
        }
    }

    public struct SendChangesContext: Sendable { public let options: SendChangesOptions; public let pendingRecordZoneChanges: [PendingRecordZoneChange] }
    public struct FetchChangesOptions: Sendable { public var scope: CKDatabase.Scope?; public init(scope: CKDatabase.Scope? = nil) { self.scope = scope } }
    public struct SendChangesOptions: Sendable { public var scope: CKDatabase.Scope?; public init(scope: CKDatabase.Scope? = nil) { self.scope = scope } }

    public struct StateUpdateEvent: Sendable { public let stateSerialization: State.Serialization }
    public struct FetchedRecordZoneChangesEvent: @unchecked Sendable { public let modifications: [CKRecord]; public let deletions: [CKRecord.ID] }
    public struct SentRecordZoneChangesEvent: @unchecked Sendable {
        public let savedRecords: [CKRecord]; public let failedRecordSaves: [CKRecord.ID: Error]
        public let deletedRecordIDs: [CKRecord.ID]; public let failedRecordDeletes: [CKRecord.ID: Error]
    }
    public enum Event: @unchecked Sendable {
        case stateUpdate(StateUpdateEvent), willFetchChanges, didFetchChanges, fetchedRecordZoneChanges(FetchedRecordZoneChangesEvent)
        case willSendChanges, didSendChanges, sentRecordZoneChanges(SentRecordZoneChangesEvent)
    }

    public let database: CKDatabase
    public let state: State
    private weak var delegate: (any CKSyncEngineDelegate)?
    public init(_ configuration: Configuration) {
        database = configuration.database; state = State(configuration.stateSerialization); delegate = configuration.delegate
        if configuration.automaticallySync { Task { try? await fetchChanges() } }
    }

    public func fetchChanges(_ options: FetchChangesOptions = FetchChangesOptions()) async throws {
        guard let delegate else { return }
        await delegate.handleEvent(.willFetchChanges, syncEngine: self)
        let since = state.token
        let result: ([CKRecord], [CKRecord.ID], Int) = database.store.access { db in
            var records: [CKRecord] = []
            for (key, stored) in db.records where stored.seq > since {
                let components = key.split(separator: "/").map(String.init)
                guard components.count >= 3 else { continue }
                let id = CKRecord.ID(recordName: components.dropFirst(2).joined(separator: "/"), zoneID: CKRecordZone.ID(zoneName: components[1], ownerName: components[0]))
                records.append(database.record(from: stored, id: id))
            }
            let deleted = db.tombstones.filter { $0.seq > since }.map { CKRecord.ID(recordName: $0.name, zoneID: CKRecordZone.ID(zoneName: $0.zone, ownerName: $0.owner)) }
            return (records, deleted, db.counter)
        }
        state.token = result.2
        await delegate.handleEvent(.fetchedRecordZoneChanges(FetchedRecordZoneChangesEvent(modifications: result.0, deletions: result.1)), syncEngine: self)
        await emitStateUpdate(delegate)
        await delegate.handleEvent(.didFetchChanges, syncEngine: self)
    }

    public func sendChanges(_ options: SendChangesOptions = SendChangesOptions()) async throws {
        guard let delegate else { return }
        await delegate.handleEvent(.willSendChanges, syncEngine: self)
        let context = SendChangesContext(options: options, pendingRecordZoneChanges: state.pendingRecordZoneChanges)
        guard let batch = await delegate.nextRecordZoneChangeBatch(context, syncEngine: self) else { await delegate.handleEvent(.didSendChanges, syncEngine: self); return }
        let saves = database._save(batch.recordsToSave, policy: .ifServerRecordUnchanged, atomic: batch.atomicByZone)
        let deletes = database._delete(batch.recordIDsToDelete)
        var saved: [CKRecord] = [], saveErrors: [CKRecord.ID: Error] = [:], deleted: [CKRecord.ID] = [], deleteErrors: [CKRecord.ID: Error] = [:]
        for (id, result) in saves { switch result { case .success(let record): saved.append(record); state.remove(pendingRecordZoneChanges: [PendingRecordZoneChange(recordID: id, type: .saveRecord)]); case .failure(let error): saveErrors[id] = error } }
        for (id, result) in deletes { switch result { case .success: deleted.append(id); state.remove(pendingRecordZoneChanges: [PendingRecordZoneChange(recordID: id, type: .deleteRecord)]); case .failure(let error): deleteErrors[id] = error } }
        await delegate.handleEvent(.sentRecordZoneChanges(SentRecordZoneChangesEvent(savedRecords: saved, failedRecordSaves: saveErrors, deletedRecordIDs: deleted, failedRecordDeletes: deleteErrors)), syncEngine: self)
        await emitStateUpdate(delegate)
        await delegate.handleEvent(.didSendChanges, syncEngine: self)
    }

    private func emitStateUpdate(_ delegate: any CKSyncEngineDelegate) async {
        await delegate.handleEvent(.stateUpdate(StateUpdateEvent(stateSerialization: state.serialization)), syncEngine: self)
    }
}
