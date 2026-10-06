// CKSubscription / CKNotification (isim: subscriptions are stored locally; notifications are delivered in-process).
import Foundation

open class CKSubscription: NSObject, @unchecked Sendable {
    public typealias ID = String
    public enum SubscriptionType: Int, Sendable { case query = 1, recordZone = 2, database = 3 }
    public let subscriptionID: ID
    public let subscriptionType: SubscriptionType
    open var notificationInfo: NotificationInfo?
    init(_ id: ID, _ t: SubscriptionType) { subscriptionID = id; subscriptionType = t }

    open class NotificationInfo: NSObject, @unchecked Sendable {
        open var alertBody: String?
        open var title: String?
        open var subtitle: String?
        open var alertLocalizationKey: String?
        open var soundName: String?
        open var shouldBadge = false
        open var shouldSendContentAvailable = false
        open var shouldSendMutableContent = false
        open var desiredKeys: [CKRecord.FieldKey]?
        open var category: String?
        open var collapseIDKey: String?
        public override init() {}
        public convenience init(alertBody: String? = nil, title: String? = nil, shouldBadge: Bool = false, shouldSendContentAvailable: Bool = false, desiredKeys: [CKRecord.FieldKey]? = nil) {
            self.init(); self.alertBody = alertBody; self.title = title; self.shouldBadge = shouldBadge
            self.shouldSendContentAvailable = shouldSendContentAvailable; self.desiredKeys = desiredKeys
        }
    }

    var stored: _CKStoredSub {
        var s = _CKStoredSub(id: subscriptionID, kind: "database", recordType: nil, predicate: nil, options: 0, zone: nil, zoneOwner: nil,
                             alertBody: notificationInfo?.alertBody, title: notificationInfo?.title,
                             contentAvailable: notificationInfo?.shouldSendContentAvailable ?? false, desiredKeys: notificationInfo?.desiredKeys)
        if let q = self as? CKQuerySubscription {
            s.kind = "query"; s.recordType = q.recordType; s.predicate = q.predicate.predicateFormat; s.options = q.querySubscriptionOptions.rawValue
            s.zone = q.zoneID?.zoneName; s.zoneOwner = q.zoneID?.ownerName
        } else if let z = self as? CKRecordZoneSubscription {
            s.kind = "zone"; s.recordType = z.recordType; s.zone = z.zoneID.zoneName; s.zoneOwner = z.zoneID.ownerName
        }
        return s
    }
    static func make(_ s: _CKStoredSub) -> CKSubscription {
        let sub: CKSubscription
        switch s.kind {
        case "query":
            let p = CKDatabase.predicate(s) ?? NSPredicate(value: true)
            let q = CKQuerySubscription(recordType: s.recordType ?? "", predicate: p, subscriptionID: s.id, options: CKQuerySubscription.Options(rawValue: s.options))
            if let z = s.zone { q.zoneID = CKRecordZone.ID(zoneName: z, ownerName: s.zoneOwner ?? CKCurrentUserDefaultName) }
            sub = q
        case "zone":
            let z = CKRecordZoneSubscription(zoneID: CKRecordZone.ID(zoneName: s.zone ?? CKRecordZoneDefaultName, ownerName: s.zoneOwner ?? CKCurrentUserDefaultName), subscriptionID: s.id)
            z.recordType = s.recordType
            sub = z
        default: sub = CKDatabaseSubscription(subscriptionID: s.id)
        }
        let info = NotificationInfo()
        info.alertBody = s.alertBody; info.title = s.title; info.shouldSendContentAvailable = s.contentAvailable; info.desiredKeys = s.desiredKeys
        sub.notificationInfo = info
        return sub
    }
}

open class CKQuerySubscription: CKSubscription, @unchecked Sendable {
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let firesOnRecordCreation = Options(rawValue: 1)
        public static let firesOnRecordUpdate = Options(rawValue: 2)
        public static let firesOnRecordDeletion = Options(rawValue: 4)
        public static let firesOnce = Options(rawValue: 8)
    }
    public let recordType: CKRecord.RecordType
    public let predicate: NSPredicate
    public let querySubscriptionOptions: Options
    open var zoneID: CKRecordZone.ID?
    public init(recordType: CKRecord.RecordType, predicate: NSPredicate, subscriptionID: CKSubscription.ID = UUID().uuidString, options: Options) {
        self.recordType = recordType; self.predicate = predicate; querySubscriptionOptions = options
        super.init(subscriptionID, .query)
    }
}
open class CKDatabaseSubscription: CKSubscription, @unchecked Sendable {
    open var recordType: CKRecord.RecordType?
    public init(subscriptionID: CKSubscription.ID = UUID().uuidString) { super.init(subscriptionID, .database) }
}
open class CKRecordZoneSubscription: CKSubscription, @unchecked Sendable {
    public let zoneID: CKRecordZone.ID
    open var recordType: CKRecord.RecordType?
    public init(zoneID: CKRecordZone.ID, subscriptionID: CKSubscription.ID = UUID().uuidString) { self.zoneID = zoneID; super.init(subscriptionID, .recordZone) }
}

// MARK: - Notifications

open class CKNotification: NSObject, @unchecked Sendable {
    public enum NotificationType: Int, Sendable { case query = 1, recordZone = 2, readNotification = 3, database = 4 }
    public struct ID: Hashable, Sendable { let raw: String }
    public let notificationType: NotificationType
    public let notificationID: ID?
    public let containerIdentifier: String?
    public let subscriptionID: CKSubscription.ID?
    public let alertBody: String?
    public let title: String?
    public let isPruned = false
    let ck: [String: Any]
    init(_ t: NotificationType, _ ck: [String: Any], _ aps: [String: Any], sid: String?) {
        notificationType = t; self.ck = ck
        notificationID = (ck["nid"] as? String).map { ID(raw: $0) }
        containerIdentifier = ck["cid"] as? String
        subscriptionID = sid
        let alert = aps["alert"] as? [String: Any]
        alertBody = alert?["body"] as? String; title = alert?["title"] as? String
    }
    /// parses the `userInfo` of a CloudKit push (isim delivers them in-process)
    public convenience init?(fromRemoteNotificationDictionary info: [AnyHashable: Any]) {
        guard let ck = info["ck"] as? [String: Any] else { return nil }
        let aps = info["aps"] as? [String: Any] ?? [:]
        if let q = ck["qry"] as? [String: Any] { self.init(.query, ck, aps, sid: q["sid"] as? String) }
        else if let m = ck["met"] as? [String: Any] { self.init(.database, ck, aps, sid: m["sid"] as? String) }
        else if let f = ck["fet"] as? [String: Any] { self.init(.recordZone, ck, aps, sid: f["sid"] as? String) }
        else { return nil }
    }
    /// returns the concrete subclass, like CloudKit's factory
    static func make(fromRemoteNotificationDictionary info: [AnyHashable: Any]) -> CKNotification? {
        guard let ck = info["ck"] as? [String: Any] else { return nil }
        let aps = info["aps"] as? [String: Any] ?? [:]
        if ck["qry"] != nil { return CKQueryNotification(ck, aps) }
        if ck["met"] != nil { return CKDatabaseNotification(ck, aps) }
        if ck["fet"] != nil { return CKRecordZoneNotification(ck, aps) }
        return nil
    }
}

open class CKQueryNotification: CKNotification, @unchecked Sendable {
    public enum Reason: Int, Sendable { case recordCreated = 1, recordUpdated = 2, recordDeleted = 3 }
    public let queryNotificationReason: Reason
    public let recordFields: [String: Any]?
    public let recordID: CKRecord.ID?
    public let databaseScope: CKDatabase.Scope
    init(_ ck: [String: Any], _ aps: [String: Any]) {
        let q = ck["qry"] as? [String: Any] ?? [:]
        queryNotificationReason = Reason(rawValue: q["fo"] as? Int ?? 1) ?? .recordCreated
        recordFields = q["af"] as? [String: Any]
        recordID = (q["rid"] as? String).map { CKRecord.ID(recordName: $0, zoneID: CKRecordZone.ID(zoneName: q["zid"] as? String ?? CKRecordZoneDefaultName, ownerName: q["zoid"] as? String ?? CKCurrentUserDefaultName)) }
        databaseScope = CKDatabase.Scope(rawValue: q["dbs"] as? Int ?? 2) ?? .private
        super.init(.query, ck, aps, sid: q["sid"] as? String)
    }
    /// isim: CKNotification(fromRemoteNotificationDictionary:) returns the base class; ask the subclass for its details
    public convenience init?(fromRemoteNotificationDictionary info: [AnyHashable: Any]) {
        guard let ck = info["ck"] as? [String: Any], ck["qry"] != nil else { return nil }
        self.init(ck, info["aps"] as? [String: Any] ?? [:])
    }
}
open class CKDatabaseNotification: CKNotification, @unchecked Sendable {
    public let databaseScope: CKDatabase.Scope
    init(_ ck: [String: Any], _ aps: [String: Any]) {
        let m = ck["met"] as? [String: Any] ?? [:]
        databaseScope = CKDatabase.Scope(rawValue: m["dbs"] as? Int ?? 2) ?? .private
        super.init(.database, ck, aps, sid: m["sid"] as? String)
    }
    /// isim: CKNotification(fromRemoteNotificationDictionary:) returns the base class; ask the subclass for its details
    public convenience init?(fromRemoteNotificationDictionary info: [AnyHashable: Any]) {
        guard let ck = info["ck"] as? [String: Any], ck["met"] != nil else { return nil }
        self.init(ck, info["aps"] as? [String: Any] ?? [:])
    }
}
open class CKRecordZoneNotification: CKNotification, @unchecked Sendable {
    public let recordZoneID: CKRecordZone.ID?
    public let databaseScope: CKDatabase.Scope
    init(_ ck: [String: Any], _ aps: [String: Any]) {
        let f = ck["fet"] as? [String: Any] ?? [:]
        recordZoneID = (f["zid"] as? String).map { CKRecordZone.ID(zoneName: $0, ownerName: f["zoid"] as? String ?? CKCurrentUserDefaultName) }
        databaseScope = CKDatabase.Scope(rawValue: f["dbs"] as? Int ?? 2) ?? .private
        super.init(.recordZone, ck, aps, sid: f["sid"] as? String)
    }
    /// isim: CKNotification(fromRemoteNotificationDictionary:) returns the base class; ask the subclass for its details
    public convenience init?(fromRemoteNotificationDictionary info: [AnyHashable: Any]) {
        guard let ck = info["ck"] as? [String: Any], ck["fet"] != nil else { return nil }
        self.init(ck, info["aps"] as? [String: Any] ?? [:])
    }
}
