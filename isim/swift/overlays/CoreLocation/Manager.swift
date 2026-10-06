// CLLocationManager, its delegate, the permission flow and the simulated location source.
import UIKit

@objc public protocol CLLocationManagerDelegate: NSObjectProtocol {
    @objc optional func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    @objc optional func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
    @objc optional func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool
    @objc optional func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion)
    @objc optional func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion)
    @objc optional func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion)
    @objc optional func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    @objc optional func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error)
    @objc optional func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    @objc optional func locationManagerDidChangeAuthorization(_ manager: CLLocationManager)
    @objc optional func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion)
    @objc optional func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager)
    @objc optional func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager)
    @objc optional func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?)
    @objc optional func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit)
}

open class CLLocationManager: NSObject, @unchecked Sendable {
    open weak var delegate: CLLocationManagerDelegate?
    open var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    open var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    open var activityType: CLActivityType = .other
    open var pausesLocationUpdatesAutomatically = true
    open var allowsBackgroundLocationUpdates = false
    open var showsBackgroundLocationIndicator = false
    open var headingFilter: CLLocationDegrees = 1
    open var headingOrientation: CLDeviceOrientation = .portrait
    open var heading: CLHeading? { nil }
    open var maximumRegionMonitoringDistance: CLLocationDistance { 200_000 }
    open private(set) var monitoredRegions: Set<CLRegion> = []
    open var rangedRegions: Set<CLRegion> { [] }
    open var isAuthorizedForWidgetUpdates: Bool { false }

    var updating = false, once = false, significant = false
    var lastSent: CLLocation?
    var reportedUnknown = false
    var inside: [String: Bool] = [:]

    public override init() {
        super.init()
        _CLSim.shared.add(self)
        // like iOS 14+: the delegate hears the current authorization soon after the manager is created
        DispatchQueue.main.async { [weak self] in self?.notifyAuthorization() }
    }

    // MARK: authorization
    open var authorizationStatus: CLAuthorizationStatus { _CLAuth.status }
    @available(*, deprecated, message: "Use the authorizationStatus instance property")
    open class func authorizationStatus() -> CLAuthorizationStatus { _CLAuth.status }
    open var accuracyAuthorization: CLAccuracyAuthorization { .fullAccuracy }
    open class func locationServicesEnabled() -> Bool { true }
    open class func headingAvailable() -> Bool { false }          // the Simulator has no compass
    open class func significantLocationChangeMonitoringAvailable() -> Bool { true }
    open class func isMonitoringAvailable(for regionClass: AnyClass) -> Bool { regionClass is CLCircularRegion.Type }
    open class func isRangingAvailable() -> Bool { false }
    @available(*, deprecated) open class func regionMonitoringAvailable() -> Bool { true }

    open func requestWhenInUseAuthorization() { _CLAuth.request(always: false) }
    open func requestAlwaysAuthorization() { _CLAuth.request(always: true) }
    open func requestTemporaryFullAccuracyAuthorization(withPurposeKey purposeKey: String, completion: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completion?(nil) }            // always full accuracy
    }
    open func requestTemporaryFullAccuracyAuthorization(withPurposeKey purposeKey: String) async throws {}

    func notifyAuthorization() {
        delegate?.locationManagerDidChangeAuthorization?(self)
        delegate?.locationManager?(self, didChangeAuthorization: _CLAuth.status)
    }

    // MARK: location
    open var location: CLLocation? { _CLAuth.authorized ? _CLSim.shared.lastFix : nil }

    open func startUpdatingLocation() { updating = true; lastSent = nil; reportedUnknown = false; _CLSim.shared.kick() }
    open func stopUpdatingLocation() { updating = false; _CLSim.shared.relax() }
    open func requestLocation() {
        if delegate?.responds(to: #selector(CLLocationManagerDelegate.locationManager(_:didFailWithError:))) != true {
            NSLog("isim CoreLocation: -[CLLocationManager requestLocation] requires the delegate to implement locationManager:didFailWithError: (iOS raises an exception)")
        }
        once = true; reportedUnknown = false; _CLSim.shared.kick()
    }
    open func startMonitoringSignificantLocationChanges() { significant = true; lastSent = nil; _CLSim.shared.kick() }
    open func stopMonitoringSignificantLocationChanges() { significant = false; _CLSim.shared.relax() }
    open func startUpdatingHeading() {}                          // no heading: headingAvailable() is false
    open func stopUpdatingHeading() {}
    open func dismissHeadingCalibrationDisplay() {}
    open func startMonitoringVisits() {}                         // no visits are detected on a simulated device
    open func stopMonitoringVisits() {}
    open func allowDeferredLocationUpdates(untilTraveled distance: CLLocationDistance, timeout: TimeInterval) {}
    open func disallowDeferredLocationUpdates() {}

    // MARK: regions
    open func startMonitoring(for region: CLRegion) {
        guard region is CLCircularRegion else {
            DispatchQueue.main.async { self.delegate?.locationManager?(self, monitoringDidFailFor: region, withError: CLError(.regionMonitoringFailure)) }
            return
        }
        monitoredRegions.insert(region)
        inside[region.identifier] = nil
        DispatchQueue.main.async {
            if !_CLAuth.authorized && _CLAuth.status != .notDetermined {
                self.delegate?.locationManager?(self, monitoringDidFailFor: region, withError: CLError(.regionMonitoringDenied)); return
            }
            self.delegate?.locationManager?(self, didStartMonitoringFor: region)
            _CLSim.shared.kick()
        }
    }
    open func stopMonitoring(for region: CLRegion) {
        monitoredRegions = monitoredRegions.filter { $0.identifier != region.identifier }
        inside[region.identifier] = nil
        _CLSim.shared.relax()
    }
    open func requestState(for region: CLRegion) {
        DispatchQueue.main.async {
            guard let fix = _CLSim.shared.current(), _CLAuth.authorized else {
                self.delegate?.locationManager?(self, didDetermineState: .unknown, for: region); return
            }
            self.delegate?.locationManager?(self, didDetermineState: region._contains(fix.coordinate) ? .inside : .outside, for: region)
        }
    }

    var active: Bool { updating || once || significant || !monitoredRegions.isEmpty }

    /// delivers `fix` (nil: no location available) — main thread
    func deliver(_ fix: CLLocation?) {
        guard _CLAuth.authorized else {
            if _CLAuth.status == .denied || _CLAuth.status == .restricted, updating || once || significant {
                once = false
                if !reportedUnknown { reportedUnknown = true; delegate?.locationManager?(self, didFailWithError: CLError(.denied)) }
            }
            return
        }
        if updating || once || significant {
            if let fix {
                let moved = lastSent.map { fix.distance(from: $0) } ?? .infinity
                let threshold = significant && !updating ? 500 : max(distanceFilter, 0)
                if lastSent == nil || (moved > 0 && moved >= threshold) || once {
                    lastSent = fix; once = false; reportedUnknown = false
                    delegate?.locationManager?(self, didUpdateLocations: [fix])
                }
            } else if !reportedUnknown {
                reportedUnknown = true; once = false
                delegate?.locationManager?(self, didFailWithError: CLError(.locationUnknown))
            }
        }
        guard let fix else { return }
        for r in monitoredRegions {
            let now = r._contains(fix.coordinate)
            let before = inside[r.identifier]
            inside[r.identifier] = now
            guard let before, before != now else { continue }
            if now, r.notifyOnEntry { delegate?.locationManager?(self, didEnterRegion: r) }
            if !now, r.notifyOnExit { delegate?.locationManager?(self, didExitRegion: r) }
        }
    }
}

// MARK: - Authorization (remembered per app; "Allow Once" lasts for this launch)

enum _CLAuth {
    nonisolated(unsafe) static var once = false
    nonisolated(unsafe) static var prompting = false
    static var status: CLAuthorizationStatus {
        if once { return .authorizedWhenInUse }
        return _Privacy.stored("location").flatMap { CLAuthorizationStatus(rawValue: Int32($0)) } ?? .notDetermined
    }
    static var authorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    static func set(_ s: CLAuthorizationStatus?, once allowOnce: Bool = false) {
        once = allowOnce
        if !allowOnce { _Privacy.store("location", s.map { Int($0.rawValue) }) }
        NSLog("isim CoreLocation: authorization %@ for %@", name(status), _Privacy.appName)
        _CLSim.shared.authorizationChanged()
    }
    static func name(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }

    static func request(always: Bool) {
        _Privacy.onMain { prompt(always: always) }
    }
    @MainActor static func prompt(always: Bool) {
        if prompting { return }
        let s = status
        if s == .authorizedWhenInUse && always && !once {
            // the one-time upgrade prompt (iOS 13.4+)
            if _Privacy.stored("locationAlwaysAsked") != nil { return }
            guard let purpose = _Privacy.usage("NSLocationAlwaysAndWhenInUseUsageDescription", "CoreLocation") else { return }
            _Privacy.store("locationAlwaysAsked", 1)
            if let sc = _Privacy.scripted("LOCATION") { set(sc == "always" ? .authorizedAlways : .authorizedWhenInUse); return }
            prompting = true
            _Privacy.alert("Allow “\(_Privacy.appName)” to also use your location even when you are not using the app?", purpose,
                           [("Keep Only While Using", .default), ("Change to Always Allow", .default)]) { i in
                prompting = false
                set(i == 1 ? .authorizedAlways : .authorizedWhenInUse)
            }
            return
        }
        guard s == .notDetermined else { return }
        // iOS ignores the request (it logs) when the purpose strings are missing
        guard let purpose = _Privacy.usage("NSLocationWhenInUseUsageDescription", "CoreLocation") else { return }
        if always && _Privacy.usage("NSLocationAlwaysAndWhenInUseUsageDescription", "CoreLocation") == nil { return }
        if let sc = _Privacy.scripted("LOCATION") {
            switch sc {
            case "once": set(.authorizedWhenInUse, once: true)
            case "always": set(always ? .authorizedAlways : .authorizedWhenInUse)
            case "deny", "denied", "no", "0": set(.denied)
            default: set(.authorizedWhenInUse)
            }
            return
        }
        prompting = true
        _Privacy.alert("Allow “\(_Privacy.appName)” to use your location?", purpose,
                       [("Allow Once", .default), ("Allow While Using App", .default), ("Don’t Allow", .default)]) { i in
            prompting = false
            switch i {
            case 0: set(.authorizedWhenInUse, once: true)
            case 1: set(.authorizedWhenInUse)
            default: set(.denied)
            }
        }
    }
}

// MARK: - Simulated location source

final class _CLListener {
    let fix: (CLLocation?) -> Void
    let auth: () -> Void
    init(fix: @escaping (CLLocation?) -> Void, auth: @escaping () -> Void) { self.fix = fix; self.auth = auth }
}

final class _CLSim: @unchecked Sendable {
    static let shared = _CLSim()
    private struct WeakManager { weak var m: CLLocationManager? }
    private var managers: [WeakManager] = []
    var listeners: [Int: _CLListener] = [:]
    var nextListener = 0
    private var timer: Timer?
    private(set) var lastFix: CLLocation?
    private let started = Date()
    private let initialFile: String?
    private var route: (points: [CLLocationCoordinate2D], speed: Double)?
    private let envFix: CLLocationCoordinate2D??          // nil: unset; .some(nil): "none"

    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020)   // Apple Park
    static var filePath: String { (_Privacy.dataDir as NSString).appendingPathComponent("Library/isim/SimulatedLocation") }

    private init() {
        initialFile = try? String(contentsOfFile: _CLSim.filePath, encoding: .utf8)
        if let e = _Privacy.env("ISIM_LOCATION") {
            var spec = e, speed = 10.0
            if let at = spec.firstIndex(of: "@") { speed = Double(spec[spec.index(after: at)...]) ?? 10; spec = String(spec[..<at]) }
            let pts = spec.split(separator: ";").compactMap(_CLSim.parse)
            if spec.lowercased() == "none" { envFix = .some(nil) }
            else if pts.count > 1 { route = (pts, max(speed, 0.1)); envFix = .some(pts[0]) }
            else if let p = pts.first { envFix = .some(p) }
            else { NSLog("isim CoreLocation: cannot parse ISIM_LOCATION=%@ (expected lat,lon)", e); envFix = nil }
        } else { envFix = nil }
    }
    static func parse(_ s: Substring) -> CLLocationCoordinate2D? {
        let p = s.split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { Double($0) }
        guard p.count >= 2 else { return nil }
        let c = CLLocationCoordinate2D(latitude: p[0], longitude: p[1])
        return CLLocationCoordinate2DIsValid(c) ? c : nil
    }

    /// the device's location right now (nil: Location ▸ None)
    func current() -> CLLocation? {
        let file = try? String(contentsOfFile: _CLSim.filePath, encoding: .utf8)
        var coord: CLLocationCoordinate2D?
        var course = -1.0, speed = -1.0
        if let file, file != initialFile || envFix == nil {
            // a `location` command during this run (or the persisted custom location when ISIM_LOCATION is unset)
            let line = file.split(separator: "\n").first.map(String.init) ?? ""
            if line.lowercased().hasPrefix("none") { return nil }
            coord = _CLSim.parse(Substring(line)) ?? _CLSim.defaultCoordinate
        } else if let route {
            (coord, course, speed) = position(on: route.points, speed: route.speed, after: Date().timeIntervalSince(started))
        } else if let envFix {
            guard let c = envFix else { return nil }
            coord = c
        } else { coord = _CLSim.defaultCoordinate }
        guard let c = coord else { return nil }
        if let last = lastFix, last.coordinate.latitude == c.latitude, last.coordinate.longitude == c.longitude, route == nil { return last }
        return CLLocation(coordinate: c, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: -1, course: course, courseAccuracy: course < 0 ? -1 : 5,
                          speed: speed, speedAccuracy: speed < 0 ? -1 : 1, timestamp: Date(),
                          sourceInfo: CLLocationSourceInformation(softwareSimulationState: true, andExternalAccessoryState: false))
    }
    private func position(on pts: [CLLocationCoordinate2D], speed: Double, after t: Double) -> (CLLocationCoordinate2D, Double, Double) {
        var legs: [Double] = []
        for i in 0..<pts.count { legs.append(_CLGeo.distance(pts[i], pts[(i + 1) % pts.count])) }
        let total = legs.reduce(0, +)
        guard total > 0 else { return (pts[0], -1, 0) }
        var d = (t * speed).truncatingRemainder(dividingBy: total)
        for i in 0..<pts.count {
            if d <= legs[i] {
                let a = pts[i], b = pts[(i + 1) % pts.count], f = legs[i] > 0 ? d / legs[i] : 0
                return (CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * f, longitude: a.longitude + (b.longitude - a.longitude) * f),
                        _CLGeo.bearing(a, b), speed)
            }
            d -= legs[i]
        }
        return (pts[0], -1, speed)
    }

    func add(_ m: CLLocationManager) { managers.removeAll { $0.m == nil }; managers.append(WeakManager(m: m)) }

    /// something wants locations: deliver now and keep polling (about once a second, like the Simulator)
    func kick() {
        _Privacy.onMain {
            self.tick()
            if self.timer == nil {
                let t = Timer(timeInterval: 0.5, repeats: true) { _ in self.tick() }
                RunLoop.main.add(t, forMode: .common)
                self.timer = t
            }
        }
    }
    func relax() {
        _Privacy.onMain {
            if !self.managers.contains(where: { $0.m?.active == true }) && self.listeners.isEmpty { self.timer?.invalidate(); self.timer = nil }
        }
    }
    func tick() {
        let fix = current()
        if let fix { lastFix = fix }
        for w in managers { if let m = w.m, m.active { m.deliver(fix) } }
        if _CLAuth.authorized { for l in listeners.values { l.fix(fix) } }
        relax()
    }
    func authorizationChanged() {
        _Privacy.onMain {
            for w in self.managers { if let m = w.m { m.reportedUnknown = false; m.notifyAuthorization() } }
            for l in self.listeners.values { l.auth() }
            self.kick()
        }
    }
}

// MARK: - Swift concurrency: CLLocationUpdate (iOS 17), CLServiceSession (iOS 18)

public struct CLLocationUpdate: Sendable {
    public let location: CLLocation?
    public let isStationary: Bool
    public var authorizationDenied: Bool { _denied }
    public var authorizationDeniedGlobally: Bool { false }
    public var authorizationRestricted: Bool { false }
    public var authorizationRequestInProgress: Bool { _inProgress }
    public var insufficientlyInUse: Bool { false }
    public var locationUnavailable: Bool { _unavailable }
    public var accuracyLimited: Bool { false }
    public var serviceSessionRequired: Bool { false }
    @available(*, deprecated, renamed: "isStationary") public var stationary: Bool { isStationary }
    let _denied: Bool, _inProgress: Bool, _unavailable: Bool

    public struct LiveConfiguration: Sendable, Hashable {
        let raw: Int
        public static let `default` = LiveConfiguration(raw: 0)
        public static let automotiveNavigation = LiveConfiguration(raw: 1)
        public static let otherNavigation = LiveConfiguration(raw: 2)
        public static let fitness = LiveConfiguration(raw: 3)
        public static let airborne = LiveConfiguration(raw: 4)
    }

    public struct Updates: AsyncSequence, Sendable {
        public typealias Element = CLLocationUpdate
        let configuration: LiveConfiguration
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncStream<CLLocationUpdate>.Iterator
            public mutating func next() async -> CLLocationUpdate? { await base.next() }
        }
        public func makeAsyncIterator() -> Iterator {
            let stream = AsyncStream<CLLocationUpdate>(bufferingPolicy: .bufferingNewest(8)) { k in
                let token = _Box<Int?>(nil)
                let last = _Box<CLLocation?>(nil)
                _Privacy.onMain {
                    _CLSim.shared.nextListener += 1
                    let id = _CLSim.shared.nextListener
                    token.value = id
                    func state() {
                        let s = _CLAuth.status
                        if (s == .denied || s == .restricted) && _Privacy.osMajor >= 18 {
                            k.yield(CLLocationUpdate(location: nil, isStationary: false, _denied: true, _inProgress: false, _unavailable: false))
                        }
                    }
                    _CLSim.shared.listeners[id] = _CLListener(fix: { fix in
                        guard let fix else {
                            if _Privacy.osMajor >= 18 { k.yield(CLLocationUpdate(location: nil, isStationary: false, _denied: false, _inProgress: false, _unavailable: true)) }
                            return
                        }
                        if let l = last.value, l.coordinate.latitude == fix.coordinate.latitude, l.coordinate.longitude == fix.coordinate.longitude {
                            return                          // stationary: iOS stops sending while the device does not move
                        }
                        let stationary = last.value != nil && fix.speed == 0
                        last.value = fix
                        k.yield(CLLocationUpdate(location: fix, isStationary: stationary, _denied: false, _inProgress: false, _unavailable: false))
                    }, auth: state)
                    // iOS 18: live updates request When In Use authorization themselves (an implicit service session)
                    if _CLAuth.status == .notDetermined && _Privacy.osMajor >= 18 { _CLAuth.request(always: false) }
                    state()
                    _CLSim.shared.kick()
                }
                k.onTermination = { _ in
                    _Privacy.onMain { if let id = token.value { _CLSim.shared.listeners[id] = nil; _CLSim.shared.relax() } }
                }
            }
            return Iterator(base: stream.makeAsyncIterator())
        }
    }
    public static func liveUpdates(_ configuration: LiveConfiguration = .default) -> Updates { Updates(configuration: configuration) }
}

open class CLServiceSession: NSObject, @unchecked Sendable {
    public enum AuthorizationRequirement: Sendable { case none, whenInUse, always }
    public let authorizationRequirement: AuthorizationRequirement
    public init(authorization: AuthorizationRequirement) {
        authorizationRequirement = authorization
        super.init()
        if authorization != .none && _CLAuth.status == .notDetermined { _CLAuth.request(always: authorization == .always) }
    }
    public convenience init(authorization: AuthorizationRequirement, fullAccuracyPurposeKey: String) { self.init(authorization: authorization) }
    open func invalidate() {}
}
