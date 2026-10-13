// CLMonitor (iOS 17): conditions (circular geographic regions, beacon identities) watched for being satisfied, with
// an async sequence of events. Records persist per monitor name across launches, like iOS
// ($ISIM_DATA app container: Library/isim/CLMonitor/NAME.plist).
//
// Adapted: conditions are evaluated against the simulated location (`location`, ISIM_LOCATION) and the simulated
// beacons (`beacon`, ISIM_BEACONS) about twice a second; an event is sent when a condition's state differs from the
// last one recorded (the `assuming` state at first), so a condition added as .unknown reports its state at once.
import Foundation

/// something a CLMonitor watches
public protocol CLCondition: Sendable {}

/// the state of a monitored condition (Swift: CLMonitor.Event.State)
public enum __CLMonitoringState: UInt, Sendable, Hashable { case unknown = 0, satisfied, unsatisfied, unmonitored }

public actor CLMonitor {
    public let name: String
    public nonisolated let events: Events

    public init(_ name: String) async {
        self.name = name
        let stream = AsyncStream<Event>(bufferingPolicy: .unbounded) { k in
            _CLMonitorEngine.shared.open(name, k)
        }
        events = Events(stream: stream)
    }
    public func add(_ condition: any CLCondition, identifier: String) { add(condition, identifier: identifier, assuming: .unknown) }
    public func add(_ condition: any CLCondition, identifier: String, assuming state: Event.State) {
        _CLMonitorEngine.shared.add(name, identifier, condition, state)
    }
    public func remove(_ identifier: String) { _CLMonitorEngine.shared.remove(name, identifier) }
    public var identifiers: [String] { _CLMonitorEngine.shared.identifiers(name) }
    public func record(for identifier: String) -> Record? { _CLMonitorEngine.shared.record(name, identifier) }

    public struct CircularGeographicCondition: CLCondition, Hashable {
        public let center: CLLocationCoordinate2D
        public let radius: CLLocationDistance
        public init(center: CLLocationCoordinate2D, radius: CLLocationDistance) { self.center = center; self.radius = radius }
        public static func == (a: Self, b: Self) -> Bool { a.center.latitude == b.center.latitude && a.center.longitude == b.center.longitude && a.radius == b.radius }
        public func hash(into h: inout Hasher) { h.combine(center.latitude); h.combine(center.longitude); h.combine(radius) }
    }
    public struct BeaconIdentityCondition: CLCondition, Hashable {
        public let uuid: UUID
        public let major: UInt16?
        public let minor: UInt16?
        public init(uuid: UUID) { self.uuid = uuid; major = nil; minor = nil }
        public init(uuid: UUID, major: UInt16) { self.uuid = uuid; self.major = major; minor = nil }
        public init(uuid: UUID, major: UInt16, minor: UInt16) { self.uuid = uuid; self.major = major; self.minor = minor }
        var constraint: CLBeaconIdentityCondition {
            if let major, let minor { return CLBeaconIdentityCondition(uuid: uuid, major: major, minor: minor) }
            if let major { return CLBeaconIdentityCondition(uuid: uuid, major: major) }
            return CLBeaconIdentityCondition(uuid: uuid)
        }
    }

    public struct Event: Sendable {
        public typealias State = __CLMonitoringState
        public var identifier: String { _identifier }
        public var date: Date { _date }
        public var state: State { _state }
        /// for a beacon condition, the identity of the beacon that satisfied it
        public let refinement: (any CLCondition)?
        @available(iOS 18.0, *) public var authorizationDenied: Bool { _denied }
        @available(iOS 18.0, *) public var authorizationDeniedGlobally: Bool { false }
        @available(iOS 18.0, *) public var authorizationRestricted: Bool { false }
        @available(iOS 18.0, *) public var authorizationRequestInProgress: Bool { false }
        @available(iOS 18.0, *) public var insufficientlyInUse: Bool { false }
        @available(iOS 18.0, *) public var accuracyLimited: Bool { false }
        @available(iOS 18.0, *) public var conditionLimitExceeded: Bool { _limit }
        @available(iOS 18.0, *) public var conditionUnsupported: Bool { false }
        @available(iOS 18.0, *) public var persistenceUnavailable: Bool { false }
        @available(iOS 18.0, *) public var serviceSessionRequired: Bool { false }
        let _identifier: String, _date: Date, _state: State, _denied: Bool, _limit: Bool
    }
    public struct Record: Sendable {
        public let condition: any CLCondition
        public let lastEvent: Event
    }
    public struct Events: AsyncSequence, Sendable {
        public typealias Element = Event
        let stream: AsyncStream<Event>
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncStream<Event>.Iterator
            public mutating func next() async -> Event? { await base.next() }
        }
        public func makeAsyncIterator() -> Iterator { Iterator(base: stream.makeAsyncIterator()) }
    }
}

/// the monitors' conditions and states (thread-safe; evaluated on the main thread by _CLSim's ticks)
final class _CLMonitorEngine: @unchecked Sendable {
    static let shared = _CLMonitorEngine()
    private let lock = NSLock()
    private struct Entry { var condition: any CLCondition; var state: __CLMonitoringState; var date: Date; var refinement: (any CLCondition)? }
    private struct Monitor { var entries: [String: Entry] = [:]; var order: [String] = []; var sink: AsyncStream<CLMonitor.Event>.Continuation?; var deniedSent = false }
    private var monitors: [String: Monitor] = [:]
    static let limit = 20                                       // iOS monitors up to 20 conditions per app

    var active: Bool { lock.lock(); defer { lock.unlock() }; return monitors.values.contains { !$0.entries.isEmpty && $0.sink != nil } }

    func open(_ name: String, _ k: AsyncStream<CLMonitor.Event>.Continuation) {
        lock.lock()
        var m = monitors[name] ?? load(name)
        m.sink = k
        monitors[name] = m
        lock.unlock()
        k.onTermination = { [weak self] _ in self?.lock.lock(); self?.monitors[name]?.sink = nil; self?.lock.unlock() }
        NSLog("isim CoreLocation: CLMonitor \"%@\" with %ld condition(s)", name, m.entries.count)
        if _CLAuth.status == .notDetermined && _Privacy.osMajor >= 18 { _CLAuth.request(always: false) }   // like an implicit service session
        _CLSim.shared.kick()
    }
    func add(_ name: String, _ id: String, _ c: any CLCondition, _ assumed: __CLMonitoringState) {
        lock.lock()
        var m = monitors[name] ?? load(name)
        if m.entries[id] == nil && m.entries.count >= _CLMonitorEngine.limit {
            let k = m.sink
            lock.unlock()
            NSLog("isim CoreLocation: CLMonitor \"%@\" already monitors %ld conditions; \"%@\" is not added", name, _CLMonitorEngine.limit, id)
            k?.yield(CLMonitor.Event(refinement: nil, _identifier: id, _date: Date(), _state: .unmonitored, _denied: false, _limit: true))
            return
        }
        if m.entries[id] == nil { m.order.append(id) }
        m.entries[id] = Entry(condition: c, state: assumed, date: Date(), refinement: nil)
        monitors[name] = m
        save(name, m)
        lock.unlock()
        _CLSim.shared.kick()
    }
    func remove(_ name: String, _ id: String) {
        lock.lock(); defer { lock.unlock() }
        guard var m = monitors[name] else { return }
        m.entries[id] = nil; m.order.removeAll { $0 == id }
        monitors[name] = m
        save(name, m)
    }
    func identifiers(_ name: String) -> [String] { lock.lock(); defer { lock.unlock() }; return (monitors[name] ?? load(name)).order }
    func record(_ name: String, _ id: String) -> CLMonitor.Record? {
        lock.lock(); defer { lock.unlock() }
        guard let e = (monitors[name] ?? load(name)).entries[id] else { return nil }
        return CLMonitor.Record(condition: e.condition, lastEvent: CLMonitor.Event(refinement: e.refinement, _identifier: id, _date: e.date, _state: e.state, _denied: false, _limit: false))
    }

    /// one tick: each condition's state now; changes become events
    func evaluate(_ fix: CLLocation?) {
        var out: [(AsyncStream<CLMonitor.Event>.Continuation, CLMonitor.Event)] = []
        lock.lock()
        let denied = _CLAuth.status == .denied || _CLAuth.status == .restricted
        for (name, var m) in monitors {
            guard let sink = m.sink else { continue }
            if !_CLAuth.authorized {
                if denied && !m.deniedSent && _Privacy.osMajor >= 18 {          // iOS 18: the events say why nothing changes
                    m.deniedSent = true
                    for id in m.order { if let e = m.entries[id] { out.append((sink, CLMonitor.Event(refinement: nil, _identifier: id, _date: Date(), _state: e.state, _denied: true, _limit: false))) } }
                    monitors[name] = m
                }
                continue
            }
            m.deniedSent = false
            var changed = false
            for id in m.order {
                guard var e = m.entries[id] else { continue }
                var state: __CLMonitoringState?, refinement: (any CLCondition)?
                switch e.condition {
                case let c as CLMonitor.CircularGeographicCondition:
                    if let fix { state = _CLGeo.distance(c.center, fix.coordinate) <= c.radius ? .satisfied : .unsatisfied }
                case let c as CLMonitor.BeaconIdentityCondition:
                    let found = _CLBeacons.inRange(c.constraint)
                    state = found.isEmpty ? .unsatisfied : .satisfied
                    if let b = found.first { refinement = CLMonitor.BeaconIdentityCondition(uuid: b.uuid, major: UInt16(truncatingIfNeeded: b.major.integerValue), minor: UInt16(truncatingIfNeeded: b.minor.integerValue)) }
                default:
                    state = .unmonitored
                }
                guard let state, state != e.state else { continue }
                e.state = state; e.date = Date(); e.refinement = refinement
                m.entries[id] = e; changed = true
                out.append((sink, CLMonitor.Event(refinement: refinement, _identifier: id, _date: e.date, _state: state, _denied: false, _limit: false)))
            }
            monitors[name] = m
            if changed { save(name, m) }
        }
        lock.unlock()
        for (k, e) in out {
            NSLog("isim CoreLocation: CLMonitor event %@ %@", e.identifier, ["unknown", "satisfied", "unsatisfied", "unmonitored"][Int(e.state.rawValue)])
            k.yield(e)
        }
    }

    // MARK: persistence (per name, in the app container)
    private static func file(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("isim/CLMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = name.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? String($0) : "_" }.joined()
        return dir.appendingPathComponent(safe + ".plist")
    }
    private func save(_ name: String, _ m: Monitor) {
        var list: [[String: Any]] = []
        for id in m.order {
            guard let e = m.entries[id] else { continue }
            var d: [String: Any] = ["id": id, "state": Int(e.state.rawValue), "date": e.date.timeIntervalSince1970]
            switch e.condition {
            case let c as CLMonitor.CircularGeographicCondition: d["kind"] = "circle"; d["lat"] = c.center.latitude; d["lon"] = c.center.longitude; d["radius"] = c.radius
            case let c as CLMonitor.BeaconIdentityCondition:
                d["kind"] = "beacon"; d["uuid"] = c.uuid.uuidString
                if let v = c.major { d["major"] = Int(v) }
                if let v = c.minor { d["minor"] = Int(v) }
            default: continue
            }
            list.append(d)
        }
        if let data = try? PropertyListSerialization.data(fromPropertyList: ["conditions": list], format: .xml, options: 0) {
            try? data.write(to: _CLMonitorEngine.file(name), options: .atomic)
        }
    }
    private func load(_ name: String) -> Monitor {
        var m = Monitor()
        guard let data = try? Data(contentsOf: _CLMonitorEngine.file(name)),
              let d = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let list = d["conditions"] as? [[String: Any]] else { return m }
        for e in list {
            guard let id = e["id"] as? String else { continue }
            var c: (any CLCondition)?
            if e["kind"] as? String == "circle", let lat = e["lat"] as? Double, let lon = e["lon"] as? Double, let r = e["radius"] as? Double {
                c = CLMonitor.CircularGeographicCondition(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: r)
            } else if e["kind"] as? String == "beacon", let u = (e["uuid"] as? String).flatMap(UUID.init(uuidString:)) {
                if let ma = e["major"] as? Int, let mi = e["minor"] as? Int { c = CLMonitor.BeaconIdentityCondition(uuid: u, major: UInt16(ma), minor: UInt16(mi)) }
                else if let ma = e["major"] as? Int { c = CLMonitor.BeaconIdentityCondition(uuid: u, major: UInt16(ma)) }
                else { c = CLMonitor.BeaconIdentityCondition(uuid: u) }
            }
            guard let c else { continue }
            m.order.append(id)
            m.entries[id] = Entry(condition: c, state: __CLMonitoringState(rawValue: UInt(e["state"] as? Int ?? 0)) ?? .unknown,
                                  date: Date(timeIntervalSince1970: e["date"] as? Double ?? 0), refinement: nil)
        }
        return m
    }
}
