// isim HomeKit (adapted, issue #416): simulated homes. isim has no home hub and no accessories, so the device keeps its
// homes in ISIM_DATA/Library/isim/HomeKit/homes.json, shared by every app like iOS's home data: `isim home seed` makes
// an example home, `isim home set|reachable|add-accessory|list|clear` change it from outside, as accessories would
// (docs/SCRIPTING.md). Running apps notice changes within half a second (the file's sequence number) and get their
// delegate callbacks. The simulated accessories behave like real ones: a lock's current state follows its target, a
// garage door opens through `opening`, a thermostat's current mode follows its target (Accessories below).
import Foundation
import UIKit

// MARK: - the device's home data

enum _HMValue: Codable, Equatable {
    case bool(Bool), int(Int), double(Double), string(String), data(Data)

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .data(try c.decode([String: Data].self)["data"] ?? Data()) }
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .data(let d): try c.encode(["data": d])
        }
    }
    /// the Objective-C value HomeKit hands out (NSNumber, NSString, NSData)
    var object: Any {
        switch self {
        case .bool(let b): return NSNumber(value: b)
        case .int(let i): return NSNumber(value: i)
        case .double(let d): return NSNumber(value: d)
        case .string(let s): return s as NSString
        case .data(let d): return d as NSData
        }
    }
    var number: Double? {
        switch self {
        case .bool(let b): return b ? 1 : 0
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }
    var text: String {
        switch self {
        case .bool(let b): return b ? "1" : "0"
        case .int(let i): return String(i)
        case .double(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
        case .string(let s): return s
        case .data(let d): return "<\(d.count) bytes>"
        }
    }
    /// an app's value for a characteristic of this format, or nil when it has the wrong type
    static func from(_ v: Any?, format: String) -> _HMValue? {
        switch format {
        case "bool":
            if let b = v as? Bool { return .bool(b) }
            if let n = v as? NSNumber { return .bool(n.boolValue) }
        case "int", "uint8", "uint16", "uint32", "uint64":
            if let n = v as? NSNumber { return .int(Int(truncating: n)) }
        case "float":
            if let n = v as? NSNumber { return .double(n.doubleValue) }
        case "string":
            if let s = v as? String { return .string(s) }
        case "tlv8", "data":
            if let d = v as? Data { return .data(d) }
        default:
            if let n = v as? NSNumber { return .double(n.doubleValue) }
            if let s = v as? String { return .string(s) }
        }
        return nil
    }
}

struct _HMCharRec: Codable, Equatable {
    var id: String
    var type: String
    var value: _HMValue?
    var properties: [String]
    var format: String
    var units: String?
    var min: Double?, max: Double?, step: Double?
    var validValues: [Double]?
    var maxLength: Int?
    var manufacturerDescription: String?
}

struct _HMServiceRec: Codable, Equatable {
    var id: String
    var type: String
    var name: String
    var primary: Bool?
    var interactive: Bool?
    var associated: String?
    var linked: [String]?
    var characteristics: [_HMCharRec]
}

struct _HMAccessoryRec: Codable, Equatable {
    var id: String
    var name: String
    var category: String
    var room: String?
    var manufacturer: String?
    var model: String?
    var firmware: String?
    var reachable: Bool?
    var blocked: Bool?
    var bridge: String?                 // the bridge accessory this one is bridged by
    var identify: Bool?
    var setupURL: String?
    var networkProfile: Bool?
    var services: [_HMServiceRec]
}

struct _HMRoomRec: Codable, Equatable { var id: String; var name: String }
struct _HMZoneRec: Codable, Equatable { var id: String; var name: String; var rooms: [String] }
struct _HMGroupRec: Codable, Equatable { var id: String; var name: String; var services: [String] }
struct _HMUserRec: Codable, Equatable { var id: String; var name: String; var admin: Bool? }
struct _HMActionRec: Codable, Equatable { var id: String; var characteristic: String; var value: _HMValue }
struct _HMActionSetRec: Codable, Equatable {
    var id: String
    var name: String
    var type: String
    var actions: [_HMActionRec]
    var lastExecution: Date?
}

struct _HMEventRec: Codable, Equatable {
    var id: String
    var kind: String                    // characteristic, threshold, calendar, significant, duration, presence, location
    var characteristic: String?
    var value: _HMValue?
    var min: Double?, max: Double?
    var components: [String: Int]?
    var significant: String?
    var offset: [String: Int]?
    var duration: Double?
    var presenceType: UInt?, presenceUser: UInt?
    var latitude: Double?, longitude: Double?, radius: Double?, regionID: String?
}

struct _HMTriggerRec: Codable, Equatable {
    var id: String
    var name: String
    var kind: String                    // timer, event
    var enabled: Bool
    var actionSets: [String]
    var fireDate: Date?
    var recurrence: [String: Int]?
    var timeZone: String?
    var events: [_HMEventRec]?
    var endEvents: [_HMEventRec]?
    var recurrences: [[String: Int]]?
    var predicate: String?
    var executeOnce: Bool?
    var lastFire: Date?
}

struct _HMHomeRec: Codable, Equatable {
    var id: String
    var name: String
    var hub: Bool?
    var provisional: String?            // a provisional home's pairing identifier
    var rooms: [_HMRoomRec]
    var zones: [_HMZoneRec]
    var accessories: [_HMAccessoryRec]
    var serviceGroups: [_HMGroupRec]
    var actionSets: [_HMActionSetRec]
    var triggers: [_HMTriggerRec]
    var users: [_HMUserRec]
}

struct _HMData: Codable, Equatable {
    var seq: Int = 0
    var primary: String?
    var homes: [_HMHomeRec] = []
    var available: [_HMAccessoryRec] = []      // accessories nearby that no home has added (HMAccessoryBrowser)
}

// MARK: - the store

/// the device's home data and the app's view of it (apps may read HomeKit's objects on any thread; the delegates and
/// completion handlers run on the main thread)
final class _HMStore: @unchecked Sendable {
    static let shared = _HMStore()
    private let lock = NSRecursiveLock()
    private var _data = _HMData()
    var data: _HMData {
        get { lock.lock(); defer { lock.unlock() }; return _data }
        set { lock.lock(); _data = newValue; lock.unlock() }
    }
    private var timer: Timer?
    private var started = false

    static var file: String {
        (_Privacy.deviceDir("Library/isim/HomeKit") as NSString).appendingPathComponent("homes.json")
    }

    func start() {
        guard !started else { return }
        started = true
        data = Self.load()
        let t = Timer(timeInterval: 0.5, repeats: true) { _ in _HMStore.shared.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    static func load() -> _HMData {
        guard let d = FileManager.default.contents(atPath: file) else { return _HMData() }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        do { return try dec.decode(_HMData.self, from: d) } catch {
            NSLog("isim HomeKit: cannot read %@: %@", file, "\(error)")
            return _HMData()
        }
    }

    /// saves the app's change (the sequence number tells other processes)
    func save() {
        data.seq += 1
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        guard let d = try? enc.encode(data) else { return }
        let tmp = Self.file + ".\(getpid()).tmp"
        if FileManager.default.createFile(atPath: tmp, contents: d) { _ = rename(tmp, Self.file) }
    }

    /// half a second: the file's changes from outside, timers that are due
    func tick() {
        let fresh = Self.load()
        if fresh != data {
            let old = data
            data = fresh
            _HMNotify.changes(from: old, to: fresh)
        }
        _HMAutomation.fireTimers()
    }

    // MARK: lookups
    func home(_ id: String) -> _HMHomeRec? { data.homes.first { $0.id == id } }
    func homeIndex(_ id: String) -> Int? { data.homes.firstIndex { $0.id == id } }

    /// (home index or nil for an available accessory, accessory index)
    func accessoryPath(_ id: String) -> (Int?, Int)? {
        for (h, home) in data.homes.enumerated() {
            if let a = home.accessories.firstIndex(where: { $0.id == id }) { return (h, a) }
        }
        if let a = data.available.firstIndex(where: { $0.id == id }) { return (nil, a) }
        return nil
    }
    func accessory(_ id: String) -> _HMAccessoryRec? {
        guard let (h, a) = accessoryPath(id) else { return nil }
        return h.map { data.homes[$0].accessories[a] } ?? data.available[a]
    }
    func modifyAccessory(_ id: String, _ body: (inout _HMAccessoryRec) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard let (h, a) = accessoryPath(id) else { return }
        if let h { body(&_data.homes[h].accessories[a]) } else { body(&_data.available[a]) }
    }
    /// changes the data under the lock
    func modify(_ body: (inout _HMData) -> Void) {
        lock.lock(); defer { lock.unlock() }
        body(&_data)
    }
    func homeOfAccessory(_ id: String) -> String? {
        guard let (h, _) = accessoryPath(id), let h else { return nil }
        return data.homes[h].id
    }

    /// (accessory id, service index) of a service
    func servicePath(_ id: String) -> (String, Int)? {
        for home in data.homes { for a in home.accessories { if let s = a.services.firstIndex(where: { $0.id == id }) { return (a.id, s) } } }
        for a in data.available { if let s = a.services.firstIndex(where: { $0.id == id }) { return (a.id, s) } }
        return nil
    }
    func service(_ id: String) -> _HMServiceRec? {
        guard let (a, s) = servicePath(id) else { return nil }
        return accessory(a)?.services[s]
    }
    /// (accessory id, service id, characteristic index)
    func characteristicPath(_ id: String) -> (String, String, Int)? {
        func scan(_ list: [_HMAccessoryRec]) -> (String, String, Int)? {
            for a in list { for s in a.services { if let c = s.characteristics.firstIndex(where: { $0.id == id }) { return (a.id, s.id, c) } } }
            return nil
        }
        for home in data.homes { if let p = scan(home.accessories) { return p } }
        return scan(data.available)
    }
    func characteristic(_ id: String) -> _HMCharRec? {
        guard let (a, s, c) = characteristicPath(id), let svc = accessory(a)?.services.first(where: { $0.id == s }) else { return nil }
        return svc.characteristics[c]
    }

    /// sets a characteristic's value as the accessory does (no checks): followers and event triggers run after
    func setValue(_ id: String, _ value: _HMValue, notify: Bool = true) {
        guard let (a, s, c) = characteristicPath(id) else { return }
        var changed = false
        modifyAccessory(a) { acc in
            guard let si = acc.services.firstIndex(where: { $0.id == s }) else { return }
            if acc.services[si].characteristics[c].value != value {
                acc.services[si].characteristics[c].value = value
                changed = true
            }
        }
        guard changed else { return }
        save()
        if notify { _HMNotify.valueChanged(id) }
        _HMAccessories.follow(id, value)
        _HMAutomation.characteristicChanged(id, value)
    }

    static func newID() -> String { UUID().uuidString }
}

// MARK: - the simulated accessories

/// what an accessory does after a write to one of its characteristics: the current state follows the target
enum _HMAccessories {
    struct Rule {
        let target: String, current: String
        let delay: Double
        let map: (_HMValue, _HMServiceRec) -> _HMValue?
        let transient: ((_HMValue) -> _HMValue?)?
    }
    static let rules: [Rule] = {
        func same(_ v: _HMValue, _ s: _HMServiceRec) -> _HMValue? { v }
        let c = _HMTypes.characteristic
        return [
            Rule(target: c("TargetLockMechanismState"), current: c("CurrentLockMechanismState"), delay: 0.6, map: same, transient: nil),
            // a garage door: opening / closing for two seconds, then open / closed
            Rule(target: c("TargetDoorState"), current: c("CurrentDoorState"), delay: 2, map: same,
                 transient: { v in .int(v.number == 0 ? 2 : 3) }),
            Rule(target: c("TargetPosition"), current: c("CurrentPosition"), delay: 1, map: same, transient: nil),
            Rule(target: c("TargetHeatingCooling"), current: c("CurrentHeatingCooling"), delay: 0.5, map: { v, svc in
                guard v.number == 3 else { return v }                                   // auto: heat or cool toward the target
                let t = svc.characteristics.first { $0.type == c("TargetTemperature") }?.value?.number ?? 21
                let cur = svc.characteristics.first { $0.type == c("CurrentTemperature") }?.value?.number ?? 21
                return .int(cur < t ? 1 : cur > t ? 2 : 0)
            }, transient: nil),
            Rule(target: c("TargetTemperature"), current: c("CurrentTemperature"), delay: 2, map: same, transient: nil),
            Rule(target: c("TargetRelativeHumidity"), current: c("CurrentRelativeHumidity"), delay: 2, map: same, transient: nil),
            Rule(target: c("TargetSecuritySystemState"), current: c("CurrentSecuritySystemState"), delay: 1, map: same, transient: nil),
            Rule(target: c("TargetFanState"), current: c("CurrentFanState"), delay: 0.5, map: { _, _ in .int(2) }, transient: nil),
            Rule(target: c("Active"), current: c("CurrentFanState"), delay: 0.5, map: { v, _ in .int(v.number == 1 ? 2 : 0) }, transient: nil),
            Rule(target: c("Active"), current: c("CurrentAirPurifierState"), delay: 0.5, map: { v, _ in .int(v.number == 1 ? 2 : 0) }, transient: nil),
            Rule(target: c("Active"), current: c("CurrentHeaterCoolerState"), delay: 0.5, map: { v, _ in .int(v.number == 1 ? 1 : 0) }, transient: nil),
            Rule(target: c("Active"), current: c("InUse"), delay: 0.5, map: same, transient: nil),
            Rule(target: c("PowerState"), current: c("OutletInUse"), delay: 0.3, map: same, transient: nil),
            Rule(target: c("TargetMediaState"), current: c("CurrentMediaState"), delay: 0.5, map: same, transient: nil),
            Rule(target: c("TargetVisibilityState"), current: c("CurrentVisibilityState"), delay: 0.3, map: same, transient: nil),
            Rule(target: c("TargetHorizontalTilt"), current: c("CurrentHorizontalTilt"), delay: 1, map: same, transient: nil),
            Rule(target: c("TargetVerticalTilt"), current: c("CurrentVerticalTilt"), delay: 1, map: same, transient: nil),
            Rule(target: c("TargetTilt"), current: c("CurrentTilt"), delay: 1, map: same, transient: nil),
        ]
    }()

    static func follow(_ id: String, _ value: _HMValue) {
        let store = _HMStore.shared
        guard let (_, s, _) = store.characteristicPath(id), let svc = store.service(s),
              let type = svc.characteristics.first(where: { $0.id == id })?.type else { return }
        for rule in rules where rule.target == type {
            guard let current = svc.characteristics.first(where: { $0.type == rule.current }) else { continue }
            if let t = rule.transient?(value) { store.setValue(current.id, t) }
            let cid = current.id
            DispatchQueue.main.asyncAfter(deadline: .now() + rule.delay) {
                let store = _HMStore.shared
                // the target may have changed meanwhile: follow the latest one
                guard let (_, s, _) = store.characteristicPath(cid), let svc = store.service(s),
                      let target = svc.characteristics.first(where: { $0.type == rule.target })?.value,
                      let v = rule.map(target, svc) else { return }
                store.setValue(cid, v)
                if rule.target == _HMTypes.characteristic("TargetLockMechanismState"),
                   let last = svc.characteristics.first(where: { $0.type == _HMTypes.characteristic("LockMechanismLastKnownAction") }) {
                    store.setValue(last.id, .int(v.number == 1 ? 6 : 7))      // secured / unsecured remotely
                }
            }
        }
    }
}
