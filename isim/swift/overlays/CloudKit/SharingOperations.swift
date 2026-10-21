// Accepting shares on isim: a share's URL names its container, zone and record in the device's local CloudKit store,
// so any app on the device can read its metadata and accept it as the current (simulated) Apple Account. Accepting
// makes that user an accepted participant of the share (an invited one, or a public user when the share has a public
// permission); the owner accepting is a no-op. Also the zone and subscription fetch operations, operation groups,
// allowed sharing options, and the system sharing UI observer.
import Foundation
import UIKit

extension CKContainer {
    nonisolated(unsafe) static var _byIdentifier: [String: CKContainer] = [:]
    /// a container kept alive for its databases (they refer to it unowned)
    static func _container(_ identifier: String) -> CKContainer {
        _CKStore.lock.lock(); defer { _CKStore.lock.unlock() }
        if let d = defaultContainer, d.containerIdentifier == identifier { return d }
        if let c = _byIdentifier[identifier] { return c }
        let c = CKContainer(identifier: identifier); _byIdentifier[identifier] = c
        return c
    }
    /// The share at `url`, read from the local store (adapted: no CloudKit server).
    static func _shareMetadata(_ url: URL, fetchRoot: Bool, desiredKeys: [CKRecord.FieldKey]?) throws -> Result<CKShare.Metadata, Error> {
        guard _CKEnv.accountStatus == .available else { return .failure(CKError(.notAuthenticated)) }
        guard let (container, shareID) = CKShare.decode(url) else {
            return .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "\(url.absoluteString) is not a CloudKit share URL"]))
        }
        let db = CKContainer._container(container).privateCloudDatabase
        guard case .success(let record)? = db._fetch([shareID], desiredKeys: nil).first?.1, let share = record as? CKShare else {
            return .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "The share no longer exists"]))
        }
        let metadata = CKShare.Metadata(container: container, share: share, root: nil)
        if metadata.participantRole == .unknown {
            return .failure(CKError(.participantMayNeedVerification, userInfo: [NSLocalizedDescriptionKey: "You are not a participant of this share"]))
        }
        if fetchRoot, let root = share.rootRecordID, case .success(let r)? = db._fetch([root], desiredKeys: desiredKeys).first?.1 { metadata.rootRecord = r }
        return .success(metadata)
    }
    /// Accepts as the current user: the participant's status becomes accepted (a public user is added).
    static func _accept(_ metadata: CKShare.Metadata) -> Result<CKShare, Error> {
        guard _CKEnv.accountStatus == .available else { return .failure(CKError(.notAuthenticated)) }
        let db = CKContainer._container(metadata.containerIdentifier).privateCloudDatabase
        guard case .success(let record)? = db._fetch([metadata.share.recordID], desiredKeys: nil).first?.1, let share = record as? CKShare else {
            return .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "The share no longer exists"]))
        }
        if share.owner.userIdentity.userRecordID?.recordName == _CKEnv.userRecordName { return .success(share) }
        if let me = share.currentUserParticipant {
            if me.acceptanceStatus == .accepted { return .success(share) }
            me.acceptanceStatus = .accepted
        } else if share.publicPermission != .none {
            share.addParticipant(CKShare.currentUser(role: .publicUser, permission: share.publicPermission, status: .accepted))
        } else {
            return .failure(CKError(.participantMayNeedVerification, userInfo: [NSLocalizedDescriptionKey: "You are not a participant of this share"]))
        }
        let saved = db._save([share], policy: .allKeys, atomic: false).first?.1 ?? .failure(CKError(.internalError))
        return saved.flatMap { ($0 as? CKShare).map(Result.success) ?? .failure(CKError(.internalError)) }
    }

    public func fetchShareMetadata(with url: URL, completionHandler: @escaping @Sendable (CKShare.Metadata?, Error?) -> Void) {
        CKDatabase.reply {
            switch (try? Self._shareMetadata(url, fetchRoot: false, desiredKeys: nil)) ?? .failure(CKError(.internalError)) {
            case .success(let m): completionHandler(m, nil)
            case .failure(let e): completionHandler(nil, e)
            }
        }
    }
    public func fetchShareMetadatas(for urls: [URL], completionHandler: @escaping @Sendable (Result<[URL: Result<CKShare.Metadata, Error>], Error>) -> Void) {
        CKDatabase.reply { completionHandler(.success(Dictionary(uniqueKeysWithValues: urls.map { ($0, (try? Self._shareMetadata($0, fetchRoot: false, desiredKeys: nil)) ?? .failure(CKError(.internalError))) }))) }
    }
    public func shareMetadata(for url: URL) async throws -> CKShare.Metadata { try Self._shareMetadata(url, fetchRoot: false, desiredKeys: nil).get() }
    public func shareMetadatas(for urls: [URL]) async throws -> [URL: Result<CKShare.Metadata, Error>] {
        Dictionary(uniqueKeysWithValues: urls.map { ($0, (try? Self._shareMetadata($0, fetchRoot: false, desiredKeys: nil)) ?? .failure(CKError(.internalError))) })
    }
    public func accept(_ metadata: CKShare.Metadata, completionHandler: @escaping @Sendable (CKShare?, Error?) -> Void) {
        CKDatabase.reply { switch Self._accept(metadata) { case .success(let s): completionHandler(s, nil); case .failure(let e): completionHandler(nil, e) } }
    }
    public func accept(_ metadata: CKShare.Metadata) async throws -> CKShare { try Self._accept(metadata).get() }
    public func accept(_ metadatas: [CKShare.Metadata]) async throws -> [CKShare.Metadata: Result<CKShare, Error>] {
        Dictionary(metadatas.map { ($0, Self._accept($0)) }, uniquingKeysWith: { a, _ in a })
    }
    public func accept(_ metadatas: [CKShare.Metadata], completionHandler: @escaping @Sendable (Result<[CKShare.Metadata: Result<CKShare, Error>], Error>) -> Void) {
        CKDatabase.reply { completionHandler(.success(Dictionary(metadatas.map { ($0, Self._accept($0)) }, uniquingKeysWith: { a, _ in a }))) }
    }
}

open class CKFetchShareMetadataOperation: CKOperation, @unchecked Sendable {
    open var shareURLs: [URL]?
    open var shouldFetchRootRecord = false
    open var rootRecordDesiredKeys: [CKRecord.FieldKey]?
    open var perShareMetadataResultBlock: ((URL, Result<CKShare.Metadata, Error>) -> Void)?
    open var fetchShareMetadataResultBlock: ((Result<Void, Error>) -> Void)?
    public override init() { super.init() }
    public convenience init(shareURLs: [URL]) { self.init(); self.shareURLs = shareURLs }
    open override func main() {
        if isCancelled { fetchShareMetadataResultBlock?(.failure(cancelledError)); return }
        if _CKEnv.accountStatus != .available { fetchShareMetadataResultBlock?(.failure(CKError(.notAuthenticated))); return }
        for url in shareURLs ?? [] {
            perShareMetadataResultBlock?(url, (try? CKContainer._shareMetadata(url, fetchRoot: shouldFetchRootRecord, desiredKeys: rootRecordDesiredKeys)) ?? .failure(CKError(.internalError)))
        }
        fetchShareMetadataResultBlock?(.success(()))
    }
}

open class CKAcceptSharesOperation: CKOperation, @unchecked Sendable {
    open var shareMetadatas: [CKShare.Metadata]?
    open var perShareResultBlock: ((CKShare.Metadata, Result<CKShare, Error>) -> Void)?
    open var acceptSharesResultBlock: ((Result<Void, Error>) -> Void)?
    public override init() { super.init() }
    public convenience init(shareMetadatas: [CKShare.Metadata]) { self.init(); self.shareMetadatas = shareMetadatas }
    open override func main() {
        if isCancelled { acceptSharesResultBlock?(.failure(cancelledError)); return }
        if _CKEnv.accountStatus != .available { acceptSharesResultBlock?(.failure(CKError(.notAuthenticated))); return }
        for m in shareMetadatas ?? [] { perShareResultBlock?(m, CKContainer._accept(m)) }
        acceptSharesResultBlock?(.success(()))
    }
}

open class CKFetchRecordZonesOperation: CKDatabaseOperation, @unchecked Sendable {
    open var recordZoneIDs: [CKRecordZone.ID]?
    open var perRecordZoneResultBlock: ((CKRecordZone.ID, Result<CKRecordZone, Error>) -> Void)?
    open var fetchRecordZonesResultBlock: ((Result<Void, Error>) -> Void)?
    public required override init() { super.init() }
    public convenience init(recordZoneIDs: [CKRecordZone.ID]) { self.init(); self.recordZoneIDs = recordZoneIDs }
    /// Fetches every zone of the database.
    open class func fetchAllRecordZonesOperation() -> Self { Self() }
    open override func main() {
        if isCancelled { fetchRecordZonesResultBlock?(.failure(cancelledError)); return }
        switch db._allZones() {
        case .failure(let e): fetchRecordZonesResultBlock?(.failure(e))
        case .success(let zones):
            if let ids = recordZoneIDs {
                for id in ids {
                    if let z = zones.first(where: { $0.zoneID == id }) { perRecordZoneResultBlock?(id, .success(z)) }
                    else { perRecordZoneResultBlock?(id, .failure(CKError(.zoneNotFound, userInfo: [NSLocalizedDescriptionKey: "Zone \(id.zoneName) does not exist"]))) }
                }
            } else { for z in zones { perRecordZoneResultBlock?(z.zoneID, .success(z)) } }
            fetchRecordZonesResultBlock?(.success(()))
        }
    }
}

open class CKFetchSubscriptionsOperation: CKDatabaseOperation, @unchecked Sendable {
    open var subscriptionIDs: [CKSubscription.ID]?
    open var perSubscriptionResultBlock: ((CKSubscription.ID, Result<CKSubscription, Error>) -> Void)?
    open var fetchSubscriptionsResultBlock: ((Result<Void, Error>) -> Void)?
    public required override init() { super.init() }
    public convenience init(subscriptionIDs: [CKSubscription.ID]) { self.init(); self.subscriptionIDs = subscriptionIDs }
    /// Fetches every subscription of the database.
    open class func fetchAllSubscriptionsOperation() -> Self { Self() }
    open override func main() {
        if isCancelled { fetchSubscriptionsResultBlock?(.failure(cancelledError)); return }
        switch db._allSubs() {
        case .failure(let e): fetchSubscriptionsResultBlock?(.failure(e))
        case .success(let subs):
            if let ids = subscriptionIDs {
                for id in ids {
                    if let s = subs.first(where: { $0.subscriptionID == id }) { perSubscriptionResultBlock?(id, .success(s)) }
                    else { perSubscriptionResultBlock?(id, .failure(CKError(.unknownItem, userInfo: [NSLocalizedDescriptionKey: "Subscription \(id) does not exist"]))) }
                }
            } else { for s in subs { perSubscriptionResultBlock?(s.subscriptionID, .success(s)) } }
            fetchSubscriptionsResultBlock?(.success(()))
        }
    }
}

public struct CKSharingParticipantAccessOption: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let anyoneWithLink = CKSharingParticipantAccessOption(rawValue: 1 << 0)
    public static let specifiedRecipientsOnly = CKSharingParticipantAccessOption(rawValue: 1 << 1)
    public static let any: CKSharingParticipantAccessOption = [.anyoneWithLink, .specifiedRecipientsOnly]
}
public struct CKSharingParticipantPermissionOption: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let readOnly = CKSharingParticipantPermissionOption(rawValue: 1 << 0)
    public static let readWrite = CKSharingParticipantPermissionOption(rawValue: 1 << 1)
    public static let any: CKSharingParticipantPermissionOption = [.readOnly, .readWrite]
}

/// The sharing choices the system sharing UI offers (isim: kept; its sheet offers the standard ones).
open class CKAllowedSharingOptions: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    open var allowedParticipantPermissionOptions: CKSharingParticipantPermissionOption
    open var allowedParticipantAccessOptions: CKSharingParticipantAccessOption
    open var allowsAccessRequests = false
    open var allowsParticipantsToInviteOthers = false
    public init(allowedParticipantPermissionOptions: CKSharingParticipantPermissionOption, allowedParticipantAccessOptions: CKSharingParticipantAccessOption) {
        self.allowedParticipantPermissionOptions = allowedParticipantPermissionOptions; self.allowedParticipantAccessOptions = allowedParticipantAccessOptions
        super.init()
    }
    open class var standard: CKAllowedSharingOptions { CKAllowedSharingOptions(allowedParticipantPermissionOptions: .any, allowedParticipantAccessOptions: .any) }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        allowedParticipantPermissionOptions = CKSharingParticipantPermissionOption(rawValue: UInt(coder.decodeInteger(forKey: "permission")))
        allowedParticipantAccessOptions = CKSharingParticipantAccessOption(rawValue: UInt(coder.decodeInteger(forKey: "access")))
        allowsAccessRequests = coder.decodeBool(forKey: "accessRequests"); allowsParticipantsToInviteOthers = coder.decodeBool(forKey: "inviteOthers")
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(Int(allowedParticipantPermissionOptions.rawValue), forKey: "permission"); coder.encode(Int(allowedParticipantAccessOptions.rawValue), forKey: "access")
        coder.encode(allowsAccessRequests, forKey: "accessRequests"); coder.encode(allowsParticipantsToInviteOthers, forKey: "inviteOthers")
    }
    open func copy(with zone: NSZone? = nil) -> Any {
        let c = CKAllowedSharingOptions(allowedParticipantPermissionOptions: allowedParticipantPermissionOptions, allowedParticipantAccessOptions: allowedParticipantAccessOptions)
        c.allowsAccessRequests = allowsAccessRequests; c.allowsParticipantsToInviteOthers = allowsParticipantsToInviteOthers
        return c
    }
}

/// Hears isim's sharing sheet (UICloudSharingController) save a share or stop sharing, for shares of its container.
open class CKSystemSharingUIObserver: NSObject, @unchecked Sendable {
    open var systemSharingUIDidSaveShareBlock: ((CKRecord.ID, Result<CKShare, Error>) -> Void)?
    open var systemSharingUIDidStopSharingBlock: ((CKRecord.ID, Result<Void, Error>) -> Void)?
    private let container: CKContainer
    private var tokens: [NSObjectProtocol] = []
    public init(container: CKContainer) {
        self.container = container
        super.init()
        CKContainer._watchSharingUI()
        for (name, saved) in [(Notification.Name._isimCloudSharingDidSave, true), (._isimCloudSharingDidStop, false)] {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                guard let self, let share = note.userInfo?["share"] as? CKShare, (note.userInfo?["container"] as? CKContainer)?.containerIdentifier == self.container.containerIdentifier else { return }
                let id = share.rootRecordID ?? share.recordID
                if saved { self.systemSharingUIDidSaveShareBlock?(id, .success(share)) } else { self.systemSharingUIDidStopSharingBlock?(id, .success(())) }
            })
        }
    }
    deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
}

extension Notification.Name {
    /// posted by isim's UICloudSharingController (userInfo: share, container)
    static let _isimCloudSharingDidSave = Notification.Name("_isimCloudSharingControllerDidSaveShare")
    static let _isimCloudSharingDidStop = Notification.Name("_isimCloudSharingControllerDidStopSharing")
}

extension CKContainer {
    /// Stopping sharing in the sharing sheet deletes the share, like the system's.
    nonisolated(unsafe) static var _sharingUIWatch: NSObjectProtocol?
    static func _watchSharingUI() {
        _CKStore.lock.lock(); defer { _CKStore.lock.unlock() }
        guard _sharingUIWatch == nil else { return }
        _sharingUIWatch = NotificationCenter.default.addObserver(forName: ._isimCloudSharingDidStop, object: nil, queue: nil) { note in
            guard let share = note.userInfo?["share"] as? CKShare, let container = note.userInfo?["container"] as? CKContainer else { return }
            _ = container.privateCloudDatabase._delete([share.recordID])
        }
    }
}
