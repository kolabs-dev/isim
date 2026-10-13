// iBeacons: the beacons the simulated device sees, beacon identity constraints and conditions, CLBeacon.
//
// Adapted: isim's device has no Bluetooth LE radio, so its beacons are simulated. ISIM_BEACONS sets the ones in range
// at launch ("UUID:MAJOR:MINOR[:immediate|near|far[:RSSI]];…"); the script command `beacon UUID MAJOR MINOR
// [immediate|near|far] [RSSI]` / `beacon off UUID MAJOR MINOR` / `beacon none` changes them while the app runs
// (the host writes $ISIM_DATA/Library/isim/SimulatedBeacons, which takes over from ISIM_BEACONS once written).
// Ranging reports them about once a second, like iOS; beacon regions and CLMonitor beacon conditions are satisfied
// while a matching beacon is in range.
import Foundation

public typealias CLBeaconMajorValue = UInt16
public typealias CLBeaconMinorValue = UInt16

@objc public enum CLProximity: Int, @unchecked Sendable { case unknown = 0, immediate, near, far }

/// which beacons a request is about: a UUID, optionally a major and a minor value (iOS 17's name for iOS 13's constraint)
open class CLBeaconIdentityCondition: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    open private(set) var uuid: UUID
    open private(set) var major: NSNumber?
    open private(set) var minor: NSNumber?
    public init(uuid: UUID) { self.uuid = uuid }
    public init(uuid: UUID, major: CLBeaconMajorValue) { self.uuid = uuid; self.major = NSNumber(value: major) }
    public init(uuid: UUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        self.uuid = uuid; self.major = NSNumber(value: major); self.minor = NSNumber(value: minor)
    }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        guard let u = coder.decodeObject(of: NSUUID.self, forKey: "uuid") else { return nil }
        uuid = u as UUID
        major = coder.decodeObject(of: NSNumber.self, forKey: "major"); minor = coder.decodeObject(of: NSNumber.self, forKey: "minor")
    }
    open func encode(with coder: NSCoder) {
        coder.encode(uuid as NSUUID, forKey: "uuid"); coder.encode(major, forKey: "major"); coder.encode(minor, forKey: "minor")
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? CLBeaconIdentityCondition else { return false }
        return o.uuid == uuid && o.major == major && o.minor == minor
    }
    open override var hash: Int {
        var h = Hasher(); h.combine(uuid); h.combine(major?.integerValue); h.combine(minor?.integerValue)
        return h.finalize()
    }
    func matches(_ b: CLBeacon) -> Bool {
        b.uuid == uuid && (major == nil || major == b.major) && (minor == nil || minor == b.minor)
    }
    open override var description: String {
        "\(type(of: self)) (uuid:\(uuid.uuidString), major:\(major.map { "\($0)" } ?? "*"), minor:\(minor.map { "\($0)" } ?? "*"))"
    }
}
/// iOS 13's name (a subclass since iOS 17)
open class CLBeaconIdentityConstraint: CLBeaconIdentityCondition, @unchecked Sendable {}

/// a beacon in range
open class CLBeacon: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    open private(set) var uuid: UUID
    open var proximityUUID: UUID { uuid }
    @NSCopying open private(set) var major: NSNumber
    @NSCopying open private(set) var minor: NSNumber
    open private(set) var proximity: CLProximity
    open private(set) var accuracy: CLLocationAccuracy
    open private(set) var rssi: Int
    open private(set) var timestamp: Date
    init(uuid: UUID, major: UInt16, minor: UInt16, proximity: CLProximity, rssi: Int) {
        self.uuid = uuid; self.major = NSNumber(value: major); self.minor = NSNumber(value: minor)
        self.proximity = proximity; self.rssi = rssi; timestamp = Date()
        // the distance a signal of this strength suggests (a 1 m reference of -59 dBm, free space)
        accuracy = proximity == .unknown ? -1 : (pow(10, Double(-59 - rssi) / 20) * 100).rounded() / 100
    }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        guard let u = coder.decodeObject(of: NSUUID.self, forKey: "uuid") else { return nil }
        uuid = u as UUID
        major = coder.decodeObject(of: NSNumber.self, forKey: "major") ?? 0; minor = coder.decodeObject(of: NSNumber.self, forKey: "minor") ?? 0
        proximity = CLProximity(rawValue: coder.decodeInteger(forKey: "proximity")) ?? .unknown
        accuracy = coder.decodeDouble(forKey: "accuracy"); rssi = coder.decodeInteger(forKey: "rssi")
        timestamp = coder.decodeObject(of: NSDate.self, forKey: "timestamp") as Date? ?? Date()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(uuid as NSUUID, forKey: "uuid"); coder.encode(major, forKey: "major"); coder.encode(minor, forKey: "minor")
        coder.encode(proximity.rawValue, forKey: "proximity"); coder.encode(accuracy, forKey: "accuracy"); coder.encode(rssi, forKey: "rssi")
        coder.encode(timestamp as NSDate, forKey: "timestamp")
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    open override var description: String {
        String(format: "CLBeacon (uuid:%@, major:%@, minor:%@, proximity:%ld +/- %.2fm, rssi:%ld)", uuid.uuidString, major, minor, proximity.rawValue, accuracy, rssi)
    }
}

/// the simulated beacons in range
enum _CLBeacons {
    static var filePath: String { (_Privacy.dataDir as NSString).appendingPathComponent("Library/isim/SimulatedBeacons") }
    /// the beacons in range now (the script's file once it exists, else ISIM_BEACONS)
    static func current() -> [CLBeacon] {
        if let file = try? String(contentsOfFile: filePath, encoding: .utf8) {
            return file.split(separator: "\n").compactMap { parse($0, separator: " ") }
        }
        guard let env = _Privacy.env("ISIM_BEACONS") else { return [] }
        return env.split(separator: ";").compactMap { parse($0, separator: ":") }
    }
    static func parse(_ line: Substring, separator: Character) -> CLBeacon? {
        let f = line.split(separator: separator).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard f.count >= 3, let u = UUID(uuidString: f[0]), let major = UInt16(f[1]), let minor = UInt16(f[2]) else { return nil }
        let prox: CLProximity = f.count > 3 ? (f[3] == "immediate" ? .immediate : f[3] == "far" ? .far : f[3] == "unknown" ? .unknown : .near) : .near
        let rssi = f.count > 4 ? Int(f[4]) ?? 0 : 0
        return CLBeacon(uuid: u, major: major, minor: minor, proximity: prox,
                        rssi: rssi != 0 ? rssi : prox == .immediate ? -40 : prox == .far ? -85 : prox == .unknown ? 0 : -65)
    }
    static func inRange(_ c: CLBeaconIdentityCondition) -> [CLBeacon] {
        current().filter { c.matches($0) }.sorted { ($0.proximity.rawValue == 0 ? 9 : $0.proximity.rawValue, -$0.rssi) < ($1.proximity.rawValue == 0 ? 9 : $1.proximity.rawValue, -$1.rssi) }
    }
    /// Apple's iBeacon advertisement: company 0x004C, type 0x02, length 0x15, UUID, major, minor, measured power
    static func advertisement(uuid: UUID, major: UInt16, minor: UInt16, power: Int8) -> Data {
        var d = Data([0x4C, 0x00, 0x02, 0x15])
        withUnsafeBytes(of: uuid.uuid) { d.append(contentsOf: $0) }
        d.append(contentsOf: [UInt8(major >> 8), UInt8(major & 0xFF), UInt8(minor >> 8), UInt8(minor & 0xFF), UInt8(bitPattern: power)])
        return d
    }
}
