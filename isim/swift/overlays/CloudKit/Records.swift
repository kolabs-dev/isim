// CloudKit records, IDs, zones, references and assets (isim: local, no iCloud sync — see Container.swift).
import Foundation
import CoreLocation

public let CKCurrentUserDefaultName = "__defaultOwner__"
public let CKRecordZoneDefaultName = "_defaultZone"

// MARK: - Values

/// a value a record field can hold: String, numbers, Bool, Date, Data, CKAsset, CKRecord.Reference, CLLocation and arrays of them
public protocol __CKRecordObjCValue {}
public protocol CKRecordValueProtocol: __CKRecordObjCValue {}
public typealias CKRecordValue = __CKRecordObjCValue

extension String: CKRecordValueProtocol {}
extension Int: CKRecordValueProtocol {}
extension Int64: CKRecordValueProtocol {}
extension Int32: CKRecordValueProtocol {}
extension UInt: CKRecordValueProtocol {}
extension Double: CKRecordValueProtocol {}
extension Float: CKRecordValueProtocol {}
extension Bool: CKRecordValueProtocol {}
extension Date: CKRecordValueProtocol {}
extension Data: CKRecordValueProtocol {}
extension Array: CKRecordValueProtocol, __CKRecordObjCValue where Element: CKRecordValueProtocol {}
extension NSString: __CKRecordObjCValue {}
extension NSNumber: __CKRecordObjCValue {}
extension NSDate: __CKRecordObjCValue {}
extension NSData: __CKRecordObjCValue {}
extension NSArray: __CKRecordObjCValue {}
extension CLLocation: __CKRecordObjCValue {}
extension CKAsset: CKRecordValueProtocol {}
extension CKRecord.Reference: CKRecordValueProtocol {}

/// how a field is stored (JSON in the local store)
indirect enum _CKValue: Codable, Equatable {
    case string(String), int(Int64), double(Double), date(Double), bytes(Data), asset(String)
    case reference(name: String, zone: String, owner: String, action: Int)
    case location(lat: Double, lon: Double, alt: Double, hAcc: Double, vAcc: Double, course: Double, speed: Double, time: Double)
    case list([_CKValue])

    init?(_ v: Any) {
        // exact Swift number types first (casts between them would bridge through NSNumber)
        let t = type(of: v)
        if t == Bool.self { self = .int((v as! Bool) ? 1 : 0); return }
        if t == Int.self { self = .int(Int64(v as! Int)); return }
        if t == Int64.self { self = .int(v as! Int64); return }
        if t == Int32.self { self = .int(Int64(v as! Int32)); return }
        if t == UInt.self { self = .int(Int64(v as! UInt)); return }
        if t == Double.self { self = .double(v as! Double); return }
        if t == Float.self { self = .double(Double(v as! Float)); return }
        switch v {
        case let s as String: self = .string(s)
        case let d as Date: self = .date(d.timeIntervalSinceReferenceDate)
        case let d as Data: self = .bytes(d)
        case let a as CKAsset: self = .asset(a.fileURL?.path ?? "")
        case let r as CKRecord.Reference:
            self = .reference(name: r.recordID.recordName, zone: r.recordID.zoneID.zoneName, owner: r.recordID.zoneID.ownerName, action: Int(r.action.rawValue))
        case let l as CLLocation:
            self = .location(lat: l.coordinate.latitude, lon: l.coordinate.longitude, alt: l.altitude, hAcc: l.horizontalAccuracy, vAcc: l.verticalAccuracy,
                             course: l.course, speed: l.speed, time: l.timestamp.timeIntervalSinceReferenceDate)
        case let n as NSNumber:
            let t = String(cString: n.objCType)
            self = (t == "d" || t == "f") ? .double(n.doubleValue) : .int(n.int64Value)
        case let a as [Any]:
            var out: [_CKValue] = []
            for e in a { guard let x = _CKValue(e) else { return nil }; out.append(x) }
            self = .list(out)
        default: return nil
        }
    }
    /// the value apps read back (bridges like CloudKit's Objective-C values: `as? String`, `as? Int`, `as? Date`, ...)
    var value: CKRecordValue {
        switch self {
        case .string(let s): return s
        case .int(let i): return NSNumber(value: i)
        case .double(let d): return NSNumber(value: d)
        case .date(let t): return Date(timeIntervalSinceReferenceDate: t)
        case .bytes(let d): return d
        case .asset(let p): return CKAsset(fileURL: URL(fileURLWithPath: p))
        case .reference(let n, let z, let o, let a):
            return CKRecord.Reference(recordID: CKRecord.ID(recordName: n, zoneID: CKRecordZone.ID(zoneName: z, ownerName: o)), action: CKRecord.ReferenceAction(rawValue: UInt(a)) ?? .none)
        case .location(let lat, let lon, let alt, let h, let v, let c, let s, let t):
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), altitude: alt, horizontalAccuracy: h, verticalAccuracy: v,
                              course: c, speed: s, timestamp: Date(timeIntervalSinceReferenceDate: t))
        case .list(let l):
            let vals = l.map { $0.value }
            if let s = vals as? [String] { return s }
            if let d = vals as? [Date] { return d }
            if let d = vals as? [Data] { return d }
            return vals.map { $0 as AnyObject } as NSArray
        }
    }
    /// Objective-C object for NSPredicate / NSSortDescriptor evaluation
    var object: AnyObject {
        switch self {
        case .string(let s): return s as NSString
        case .int(let i): return NSNumber(value: i)
        case .double(let d): return NSNumber(value: d)
        case .date(let t): return Date(timeIntervalSinceReferenceDate: t) as NSDate
        case .bytes(let d): return d as NSData
        case .list(let l): return l.map { $0.object } as NSArray
        default: return value as AnyObject
        }
    }
}

// MARK: - IDs and zones

@objc(CKRecordZone) open class CKRecordZone: NSObject, @unchecked Sendable {
    @objc(CKRecordZoneID) open class ID: NSObject, NSCopying, @unchecked Sendable {
        @objc public let zoneName: String
        @objc public let ownerName: String
        @objc public init(zoneName: String = CKRecordZoneDefaultName, ownerName: String = CKCurrentUserDefaultName) { self.zoneName = zoneName; self.ownerName = ownerName }
        @objc public static let `default` = ID()
        @objc open override func isEqual(_ o: Any?) -> Bool { (o as? ID).map { $0.zoneName == zoneName && $0.ownerName == ownerName } ?? false }
        @objc open override var hash: Int { zoneName.hashValue ^ ownerName.hashValue }
        @objc open func copy(with zone: OpaquePointer? = nil) -> Any { self }
        @objc open override var description: String { "<CKRecordZoneID: zoneName=\(zoneName), ownerName=\(ownerName)>" }
        @objc var key: String { "\(ownerName)/\(zoneName)" }
    }
    public struct Capabilities: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let fetchChanges = Capabilities(rawValue: 1)
        public static let atomic = Capabilities(rawValue: 2)
        public static let sharing = Capabilities(rawValue: 4)
        public static let zoneWideSharing = Capabilities(rawValue: 8)
    }
    @objc public let zoneID: ID
    open var capabilities: Capabilities
    @objc public init(zoneName: String) { zoneID = ID(zoneName: zoneName); capabilities = [.fetchChanges, .atomic, .sharing] }
    @objc public init(zoneID: ID) { self.zoneID = zoneID; capabilities = [.fetchChanges, .atomic, .sharing] }
    @objc open class func `default`() -> CKRecordZone { let z = CKRecordZone(zoneID: .default); z.capabilities = []; return z }
}

extension CKRecord {
    @objc(CKRecordID) open class ID: NSObject, NSCopying, @unchecked Sendable {
        @objc public let recordName: String
        @objc public let zoneID: CKRecordZone.ID
        @objc public init(recordName: String = UUID().uuidString, zoneID: CKRecordZone.ID = .default) { self.recordName = recordName; self.zoneID = zoneID }
        @objc open override func isEqual(_ o: Any?) -> Bool { (o as? ID).map { $0.recordName == recordName && $0.zoneID == zoneID } ?? false }
        @objc open override var hash: Int { recordName.hashValue ^ zoneID.hash }
        @objc open func copy(with zone: OpaquePointer? = nil) -> Any { self }
        @objc open override var description: String { "<CKRecordID: \(recordName); zoneID=\(zoneID.zoneName):\(zoneID.ownerName)>" }
        @objc var key: String { "\(zoneID.key)/\(recordName)" }
    }
    public enum ReferenceAction: UInt, Sendable { case none = 0, deleteSelf = 1 }
    @objc(CKReference) open class Reference: NSObject, NSCopying, @unchecked Sendable {
        @objc public let recordID: CKRecord.ID
        public let action: ReferenceAction
        public init(recordID: CKRecord.ID, action: ReferenceAction) { self.recordID = recordID; self.action = action }
        public convenience init(record: CKRecord, action: ReferenceAction) { self.init(recordID: record.recordID, action: action) }
        @objc open override func isEqual(_ o: Any?) -> Bool { (o as? Reference).map { $0.recordID == recordID } ?? false }
        @objc open override var hash: Int { recordID.hash }
        @objc open func copy(with zone: OpaquePointer? = nil) -> Any { self }
        @objc open override var description: String { "<CKReference: \(recordID.recordName)>" }
    }
    public typealias RecordType = String
    public typealias FieldKey = String
    @objc public static let SystemType = "CKRecordTypeSystem"
}
public typealias CKRecordID = CKRecord.ID
public typealias CKRecordZoneID = CKRecordZone.ID
public typealias CKReference = CKRecord.Reference

@objc(CKAsset) open class CKAsset: NSObject, @unchecked Sendable {
    @objc public let fileURL: URL?
    @objc public init(fileURL: URL) { self.fileURL = fileURL }
}

// MARK: - Records

@objc(CKRecord) open class CKRecord: NSObject, NSCopying, @unchecked Sendable {
    @objc public let recordType: RecordType
    @objc public let recordID: ID
    @objc public internal(set) var creationDate: Date?
    @objc public internal(set) var modificationDate: Date?
    @objc public internal(set) var recordChangeTag: String?
    @objc public internal(set) var creatorUserRecordID: ID?
    @objc public internal(set) var lastModifiedUserRecordID: ID?
    @objc open var parent: Reference?
    var fields: [String: _CKValue] = [:]
    @objc var changed: [String] = []

    @objc public init(recordType: RecordType, recordID: ID = ID()) { self.recordType = recordType; self.recordID = recordID }
    @objc public convenience init(recordType: RecordType, zoneID: CKRecordZone.ID) { self.init(recordType: recordType, recordID: ID(zoneID: zoneID)) }

    /// restores a record from `encodeSystemFields(with:)` data (no field values, like CloudKit)
    @objc public init?(coder: NSCoder) {
        guard let d = coder.decodeObject(forKey: "isimCKSystemFields") as? Data,
              let s = try? JSONDecoder().decode(_CKSystemFields.self, from: d) else { return nil }
        recordType = s.type
        recordID = ID(recordName: s.name, zoneID: CKRecordZone.ID(zoneName: s.zone, ownerName: s.owner))
        recordChangeTag = s.tag
        creationDate = s.created.map { Date(timeIntervalSinceReferenceDate: $0) }
        modificationDate = s.modified.map { Date(timeIntervalSinceReferenceDate: $0) }
    }
    /// the system fields (type, ID, change tag, dates) — keep them to save changes later without a fetch
    @objc open func encodeSystemFields(with coder: NSCoder) {
        let s = _CKSystemFields(type: recordType, name: recordID.recordName, zone: recordID.zoneID.zoneName, owner: recordID.zoneID.ownerName,
                                tag: recordChangeTag, created: creationDate?.timeIntervalSinceReferenceDate, modified: modificationDate?.timeIntervalSinceReferenceDate)
        if let d = try? JSONEncoder().encode(s) { coder.encode(d as NSData, forKey: "isimCKSystemFields") }
    }

    open subscript(key: FieldKey) -> CKRecordValue? {
        get { fields[key]?.value }
        set { setField(key, newValue) }
    }
    @objc func setField(_ key: String, _ v: Any?) {
        if let v {
            guard let x = _CKValue(v) else { NSLog("isim CloudKit: unsupported value type %@ for key %@", String(describing: type(of: v)), key); return }
            fields[key] = x
        } else { fields[key] = nil }
        if !changed.contains(key) { changed.append(key) }
    }
    open func object(forKey key: FieldKey) -> CKRecordValue? { self[key] }
    open func setObject(_ object: CKRecordValue?, forKey key: FieldKey) { self[key] = object }
    @objc open override func value(forKey key: String) -> Any? { self[key] }
    @objc open override func setValue(_ value: Any?, forKey key: String) { setField(key, value) }
    @objc open func allKeys() -> [FieldKey] { fields.keys.sorted() }
    @objc open func changedKeys() -> [FieldKey] { changed }
    /// isim stores encrypted values like the others (the store is local; not encrypted at rest)
    open var encryptedValues: CKRecordKeyValueSetting { _CKEncrypted(self) }
    @objc(setParentReferenceFromRecord:) open func setParent(_ parentRecord: CKRecord?) { parent = parentRecord.map { Reference(record: $0, action: .none) } }
    @objc(setParentReferenceFromRecordID:) open func setParent(_ parentRecordID: ID?) { parent = parentRecordID.map { Reference(recordID: $0, action: .none) } }

    @objc open func copy(with zone: OpaquePointer? = nil) -> Any {
        let r = CKRecord(recordType: recordType, recordID: recordID)
        r.fields = fields; r.changed = changed; r.creationDate = creationDate; r.modificationDate = modificationDate
        r.recordChangeTag = recordChangeTag; r.creatorUserRecordID = creatorUserRecordID; r.lastModifiedUserRecordID = lastModifiedUserRecordID; r.parent = parent
        return r
    }
    @objc open override var description: String {
        "<CKRecord: \(recordType) \(recordID.recordName) tag=\(recordChangeTag ?? "nil") \(allKeys().map { "\($0)=\(fields[$0]!)" }.joined(separator: " "))>"
    }

    /// an NSPredicate / NSSortDescriptor target: field values as Objective-C objects plus system keys
    @objc var evaluationObject: NSDictionary {
        let d = NSMutableDictionary()
        for (k, v) in fields { d[k as NSString] = v.object }
        if let c = creationDate { d["creationDate" as NSString] = c as NSDate }
        if let m = modificationDate { d["modificationDate" as NSString] = m as NSDate }
        d["recordID" as NSString] = recordID
        d["recordName" as NSString] = recordID.recordName as NSString
        return d
    }
}

public protocol CKRecordKeyValueSetting {
    subscript(key: String) -> CKRecordValue? { get nonmutating set }
}
struct _CKEncrypted: CKRecordKeyValueSetting {
    let r: CKRecord
    init(_ r: CKRecord) { self.r = r }
    subscript(key: String) -> CKRecordValue? {
        get { r[key] }
        nonmutating set { r[key] = newValue }
    }
}

struct _CKSystemFields: Codable { var type, name, zone, owner: String; var tag: String?; var created, modified: Double? }
