// isim HealthKit: building workouts — HKWorkoutBuilder (samples, events, activities and metadata collected into a
// workout), workout route builders, and the live workout (iOS 26 on iPhone): an HKWorkoutSession whose
// HKLiveWorkoutBuilder collects data from an HKLiveWorkoutDataSource. isim has no heart-rate sensor or GPS track to read
// while you exercise, so the data source is a simulation: heart rate rising from rest toward a level for the activity,
// active energy and distance at the activity's pace, one sample of each a second while the session runs (adapted;
// labelled in docs/frameworks/HealthKit.md). The samples are saved to the device's Health database like a watch's.
import Foundation
import CoreLocation

// MARK: - Workout builder

@objc(HKWorkoutBuilder) open class HKWorkoutBuilder: NSObject, @unchecked Sendable {
    let lock = NSRecursiveLock()
    let store: HKHealthStore
    let config: HKWorkoutConfiguration
    @objc open private(set) var device: HKDevice?
    var _start: Date?, _end: Date?, _metadata: [String: Any] = [:]
    var _events: [HKWorkoutEvent] = [], _activities: [HKWorkoutActivity] = []
    /// the samples added (saved to the database as they come), and the series builders handed out
    var _samples: [HKSample] = [], _series: [HKWorkoutRouteBuilder] = []
    var _finished = false

    @objc(initWithHealthStore:configuration:device:)
    public init(healthStore: HKHealthStore, configuration: HKWorkoutConfiguration, device: HKDevice?) {
        store = healthStore; config = configuration.copy() as! HKWorkoutConfiguration; self.device = device
        super.init()
    }
    func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }
    func fail(_ completion: @escaping (Bool, Error?) -> Void, _ code: HKError.Code, _ message: String) {
        _Privacy.reply { completion(false, HKError(code, message)) }
    }

    @objc open var workoutConfiguration: HKWorkoutConfiguration { config.copy() as! HKWorkoutConfiguration }
    @objc open var startDate: Date? { locked { _start } }
    @objc open var endDate: Date? { locked { _end } }
    @objc open var metadata: [String: Any] { locked { _metadata } }
    @objc open var workoutEvents: [HKWorkoutEvent] { locked { _events } }
    @objc open var workoutActivities: [HKWorkoutActivity] { locked { _activities.map { _withStatistics($0) } } }
    /// the workout's time so far, less its pauses
    @objc(elapsedTimeAtDate:) open func elapsedTime(at date: Date) -> TimeInterval {
        locked {
            guard let s = _start else { return 0 }
            return _HKWorkoutTime.elapsed(s, min(date, _end ?? date), _events)
        }
    }
    @objc open var allStatistics: [HKQuantityType: HKStatistics] { locked { _statistics(_start ?? Date(), _end ?? Date(), nil) } }
    @objc(statisticsForType:) open func statistics(for quantityType: HKQuantityType) -> HKStatistics? { allStatistics[quantityType] }
    /// the statistics of the quantity samples added (within an interval when given)
    func _statistics(_ start: Date, _ end: Date, _ within: DateInterval?) -> [HKQuantityType: HKStatistics] {
        var byType: [String: [HKQuantitySample]] = [:]
        for case let q as HKQuantitySample in _samples where within.map({ $0.contains(q.startDate) }) ?? true {
            byType[q.sampleType.identifier, default: []].append(q)
        }
        return Dictionary(uniqueKeysWithValues: byType.map { id, s in
            let t = HKQuantityType(id)
            return (t, HKStatistics.workout(t, s.map(\.startDate).min() ?? start, s.map(\.endDate).max() ?? end, s))
        })
    }
    /// an activity with its events and the statistics of its stretch of the workout
    func _withStatistics(_ a: HKWorkoutActivity) -> HKWorkoutActivity {
        let span = DateInterval(start: a.startDate, end: max(a.startDate, a.endDate ?? _end ?? Date()))
        a.workoutEvents = _events.filter { span.contains($0.dateInterval.start) }
        a.allStatistics = _statistics(span.start, span.end, span)
        return a
    }

    @objc(beginCollectionWithStartDate:completion:)
    open func beginCollection(withStart startDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        switch _HKAuth.share(HKWorkoutTypeIdentifier) {
        case nil: fail(completion, .errorAuthorizationNotDetermined, "Authorization to share workouts is not determined"); return
        case false?: fail(completion, .errorAuthorizationDenied, "Authorization to share workouts is denied"); return
        default: break
        }
        let ok: Bool = locked {
            guard _start == nil, !_finished else { return false }
            _start = startDate
            return true
        }
        guard ok else { fail(completion, .errorInvalidArgument, "Collection has already begun"); return }
        _began()
        _Privacy.reply { completion(true, nil) }
    }
    func _began() {}
    @objc(addSamples:completion:)
    open func add(_ samples: [HKSample], completion: @escaping (Bool, Error?) -> Void) {
        guard locked({ _start != nil && !_finished }) else { fail(completion, .errorInvalidArgument, "Collection has not begun"); return }
        guard !samples.isEmpty else { _Privacy.reply { completion(true, nil) }; return }
        store.save(samples) { ok, error in
            if ok { self.locked { self._samples += samples } }
            completion(ok, error)
        }
    }
    @objc(addWorkoutEvents:completion:)
    open func addWorkoutEvents(_ workoutEvents: [HKWorkoutEvent], completion: @escaping (Bool, Error?) -> Void) {
        guard locked({ _start != nil && !_finished }) else { fail(completion, .errorInvalidArgument, "Collection has not begun"); return }
        locked { _events += workoutEvents; _events.sort { $0.dateInterval.start < $1.dateInterval.start } }
        _Privacy.reply { completion(true, nil) }
    }
    @objc(addMetadata:completion:)
    open func addMetadata(_ metadata: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        guard locked({ !_finished }) else { fail(completion, .errorInvalidArgument, "The workout is finished"); return }
        locked { _metadata.merge(metadata) { _, new in new } }
        _Privacy.reply { completion(true, nil) }
    }
    /// adds an activity (a part of a multisport workout); it must fall within the workout
    @objc(addWorkoutActivity:completion:)
    open func addWorkoutActivity(_ workoutActivity: HKWorkoutActivity, completion: @escaping (Bool, Error?) -> Void) {
        let ok: Bool = locked {
            guard let s = _start, !_finished, workoutActivity.startDate >= s,
                  !_activities.contains(where: { $0.uuid == workoutActivity.uuid }) else { return false }
            if let e = _end, workoutActivity.startDate > e { return false }
            _activities.append(workoutActivity)
            _activities.sort { $0.startDate < $1.startDate }
            return true
        }
        guard ok else { fail(completion, .errorInvalidArgument, "The activity is outside the workout or already added"); return }
        _Privacy.reply { completion(true, nil) }
    }
    @objc(updateActivityWithUUID:endDate:completion:)
    open func updateActivity(uuid UUID: UUID, end endDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        let ok: Bool = locked {
            guard let a = _activities.first(where: { $0.uuid == UUID }), endDate >= a.startDate else { return false }
            a.endDate = endDate
            return true
        }
        if ok { _Privacy.reply { completion(true, nil) } } else { fail(completion, .errorInvalidArgument, "No such activity, or it ends before it starts") }
    }
    @objc(updateActivityWithUUID:addMedatata:completion:)
    open func updateActivity(uuid UUID: UUID, adding metadata: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        let ok: Bool = locked {
            guard let a = _activities.first(where: { $0.uuid == UUID }) else { return false }
            a.metadata = (a.metadata ?? [:]).merging(metadata) { _, new in new }
            return true
        }
        if ok { _Privacy.reply { completion(true, nil) } } else { fail(completion, .errorInvalidArgument, "No such activity") }
    }
    @objc(endCollectionWithEndDate:completion:)
    open func endCollection(withEnd endDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        let ok: Bool = locked {
            guard let s = _start, _end == nil, !_finished, endDate >= s else { return false }
            _end = endDate
            for a in _activities where a.endDate == nil { a.endDate = endDate }
            return true
        }
        guard ok else { fail(completion, .errorInvalidArgument, "Collection has not begun, has ended, or ends before it began"); return }
        _ended()
        _Privacy.reply { completion(true, nil) }
    }
    func _ended() {}
    /// saves the workout (its samples, events, activities, statistics and routes) to the Health database
    @objc(finishWorkoutWithCompletion:)
    open func finishWorkout(completion: @escaping (HKWorkout?, Error?) -> Void) {
        let made: HKWorkout? = locked {
            guard let s = _start, let e = _end, !_finished else { return nil }
            var md = _metadata
            if config.locationType == .indoor, md[HKMetadataKeyIndoorWorkout] == nil { md[HKMetadataKeyIndoorWorkout] = true }
            let w = HKWorkout(config.activityType, s, e, duration: _HKWorkoutTime.elapsed(s, e, _events), events: _events, metadata: md.isEmpty ? nil : md)
            w.workoutActivities = _activities.map { _withStatistics($0) }
            w.allStatistics = _statistics(s, e, nil)
            return w
        }
        guard let workout = made else {
            _Privacy.reply { completion(nil, HKError(.errorInvalidArgument, "Collection has not ended")) }; return
        }
        store.save(workout) { ok, error in
            guard ok else { completion(nil, error); return }
            let (samples, series): ([HKSample], [HKWorkoutRouteBuilder]) = self.locked { self._finished = true; return (self._samples, self._series) }
            _HKDB.associate(Set(samples.map(\.uuid.uuidString)), with: workout.uuid.uuidString) {
                for s in samples { s._workout = workout.uuid.uuidString }
                let pending = series.filter { $0.open && !$0.locations.isEmpty }
                guard !pending.isEmpty else { completion(workout, nil); return }
                let group = DispatchGroup()
                for r in pending { group.enter(); r.finishRoute(with: workout, metadata: nil) { _, _ in group.leave() } }
                group.notify(queue: .global()) { completion(workout, nil) }
            }
        }
    }
    /// throws the workout away: the samples it added are deleted
    @objc open func discardWorkout() {
        let samples: [HKSample] = locked {
            guard !_finished else { return [] }
            _finished = true
            for r in _series { r.discard() }
            return _samples
        }
        if !samples.isEmpty { store.delete(samples) { _, _ in } }
        _ended()
    }
    /// a route builder for the workout (finished with it)
    @objc(seriesBuilderForType:) open func seriesBuilder(for seriesType: HKSeriesType) -> HKSeriesBuilder? {
        guard seriesType.identifier == HKWorkoutRouteTypeIdentifier else { return nil }
        let r = HKWorkoutRouteBuilder(healthStore: store, device: device)
        locked { _series.append(r) }
        return r
    }

    public func beginCollection(at start: Date) async throws { try await _hkAsync { beginCollection(withStart: start, completion: $0) } }
    public func addSamples(_ samples: [HKSample]) async throws { try await _hkAsync { add(samples, completion: $0) } }
    public func addWorkoutEvents(_ workoutEvents: [HKWorkoutEvent]) async throws { try await _hkAsync { addWorkoutEvents(workoutEvents, completion: $0) } }
    public func addMetadata(_ metadata: [String: Any]) async throws { try await _hkAsync { addMetadata(metadata, completion: $0) } }
    public func addWorkoutActivity(_ workoutActivity: HKWorkoutActivity) async throws { try await _hkAsync { addWorkoutActivity(workoutActivity, completion: $0) } }
    public func updateActivity(uuid UUID: UUID, end endDate: Date) async throws { try await _hkAsync { updateActivity(uuid: UUID, end: endDate, completion: $0) } }
    public func updateActivity(uuid UUID: UUID, adding metadata: [String: Any]) async throws {
        try await _hkAsync { updateActivity(uuid: UUID, adding: metadata, completion: $0) }
    }
    public func endCollection(at end: Date) async throws { try await _hkAsync { endCollection(withEnd: end, completion: $0) } }
    public func finishWorkout() async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<HKWorkout?, Error>) in
            finishWorkout { w, e in if let e { k.resume(throwing: e) } else { k.resume(returning: w) } }
        }
    }
}

func _hkAsync(_ body: (@escaping (Bool, Error?) -> Void) -> Void) async throws {
    try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
        body { _, e in if let e { k.resume(throwing: e) } else { k.resume() } }
    }
}

extension _HKDB {
    /// marks samples as belonging to a workout (HKQuery.predicateForObjects(from:) finds them)
    static func associate(_ uuids: Set<String>, with workout: String, then: @escaping @Sendable () -> Void) {
        DispatchQueue.main.async {
            if !uuids.isEmpty {
                var all = load()
                for i in all.indices where uuids.contains(all[i].uuid) { all[i].workout = workout }
                save(all)
            }
            DispatchQueue.global().async { then() }
        }
    }
}

// MARK: - Series builders: workout routes

@objc(HKSeriesBuilder) open class HKSeriesBuilder: NSObject, @unchecked Sendable {
    let lock = NSLock()
    var open = true
    /// stops building: nothing is saved
    @objc open func discard() { lock.lock(); open = false; lock.unlock() }
}

/// collects a workout's locations, then saves them as an HKWorkoutRoute attached to the workout
@objc(HKWorkoutRouteBuilder) open class HKWorkoutRouteBuilder: HKSeriesBuilder, @unchecked Sendable {
    let store: HKHealthStore
    var locations: [CLLocation] = [], metadata: [String: Any] = [:]
    @objc(initWithHealthStore:device:)
    public init(healthStore: HKHealthStore, device: HKDevice?) { store = healthStore; super.init() }
    @objc(insertRouteData:completion:)
    open func insertRouteData(_ routeData: [CLLocation], completion: @escaping (Bool, Error?) -> Void) {
        lock.lock()
        let ok = open
        if ok { locations += routeData }
        lock.unlock()
        _Privacy.reply { completion(ok, ok ? nil : HKError(.errorInvalidArgument, "The route builder is finished or discarded")) }
    }
    @objc(addMetadata:completion:)
    open func addMetadata(_ metadata: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        lock.lock(); self.metadata.merge(metadata) { _, new in new }; lock.unlock()
        _Privacy.reply { completion(true, nil) }
    }
    @objc(finishRouteWithWorkout:metadata:completion:)
    open func finishRoute(with workout: HKWorkout, metadata: [String: Any]?, completion: @escaping (HKWorkoutRoute?, Error?) -> Void) {
        lock.lock()
        let ok = open
        open = false
        let points = locations.sorted { $0.timestamp < $1.timestamp }
        let md = self.metadata.merging(metadata ?? [:]) { _, new in new }
        lock.unlock()
        guard ok else { _Privacy.reply { completion(nil, HKError(.errorInvalidArgument, "The route builder is finished or discarded")) }; return }
        guard _HKDB.load().contains(where: { $0.uuid == workout.uuid.uuidString }) else {
            _Privacy.reply { completion(nil, HKError(.errorInvalidArgument, "The workout must be saved before its route")) }; return
        }
        let route = HKWorkoutRoute(points, metadata: md.isEmpty ? nil : md)
        route._workout = workout.uuid.uuidString
        store.save(route) { saved, error in completion(saved ? route : nil, error) }
    }
    public func insertRouteData(_ routeData: [CLLocation]) async throws { try await _hkAsync { insertRouteData(routeData, completion: $0) } }
    public func addMetadata(_ metadata: [String: Any]) async throws { try await _hkAsync { addMetadata(metadata, completion: $0) } }
    public func finishRoute(with workout: HKWorkout, metadata: [String: Any]?) async throws -> HKWorkoutRoute {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<HKWorkoutRoute, Error>) in
            finishRoute(with: workout, metadata: metadata) { r, e in
                if let r { k.resume(returning: r) } else { k.resume(throwing: e ?? HKError(.errorInvalidArgument)) }
            }
        }
    }
}

// MARK: - Workout sessions

@objc public enum HKWorkoutSessionState: Int, Sendable { case notStarted = 1, running, ended, paused, prepared, stopped }
@objc public enum HKWorkoutSessionType: Int, Sendable { case primary = 0, mirrored }

@available(iOS 17.0, *)
@objc(HKWorkoutSessionDelegate) public protocol HKWorkoutSessionDelegate: NSObjectProtocol {
    @objc(workoutSession:didChangeToState:fromState:date:)
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date)
    @objc(workoutSession:didFailWithError:)
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error)
    @objc(workoutSession:didGenerateEvent:)
    optional func workoutSession(_ workoutSession: HKWorkoutSession, didGenerate event: HKWorkoutEvent)
    @objc(workoutSession:didBeginActivityWithConfiguration:date:)
    optional func workoutSession(_ workoutSession: HKWorkoutSession, didBeginActivityWith workoutConfiguration: HKWorkoutConfiguration, date: Date)
    @objc(workoutSession:didEndActivityWithConfiguration:date:)
    optional func workoutSession(_ workoutSession: HKWorkoutSession, didEndActivityWith workoutConfiguration: HKWorkoutConfiguration, date: Date)
    @objc(workoutSession:didReceiveDataFromRemoteWorkoutSession:)
    optional func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data])
    @objc(workoutSession:didDisconnectFromRemoteDeviceWithError:)
    optional func workoutSession(_ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?)
}

/// a workout in progress. iOS 17 gets sessions mirrored from an Apple Watch (isim has no watch: none arrive); iOS 26
/// starts its own on iPhone, with a live workout builder
@available(iOS 17.0, *)
@objc(HKWorkoutSession) open class HKWorkoutSession: NSObject, NSSecureCoding, @unchecked Sendable {
    nonisolated(unsafe) static weak var _running: HKWorkoutSession?
    static let queue = DispatchQueue(label: "isim.healthkit.workout-session")
    let lock = NSRecursiveLock()
    let store: HKHealthStore?
    @objc open weak var delegate: HKWorkoutSessionDelegate?
    @objc open private(set) var type: HKWorkoutSessionType = .primary
    @objc open private(set) var workoutConfiguration: HKWorkoutConfiguration
    var _state: HKWorkoutSessionState = .notStarted, _start: Date?, _end: Date?
    var _activity: HKWorkoutActivity, _main: HKWorkoutActivity
    var _builder: AnyObject?
    @objc open var state: HKWorkoutSessionState { lock.lock(); defer { lock.unlock() }; return _state }
    @objc open var startDate: Date? { lock.lock(); defer { lock.unlock() }; return _start }
    @objc open var endDate: Date? { lock.lock(); defer { lock.unlock() }; return _end }
    @objc open var currentActivity: HKWorkoutActivity { lock.lock(); defer { lock.unlock() }; return _activity }
    @objc open var activityType: HKWorkoutActivityType { workoutConfiguration.activityType }
    @objc open var locationType: HKWorkoutSessionLocationType { workoutConfiguration.locationType }

    @available(iOS 26.0, *)
    @objc(initWithHealthStore:configuration:error:)
    public init(healthStore: HKHealthStore, configuration workoutConfiguration: HKWorkoutConfiguration) throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HKError(.errorHealthDataUnavailable, "Health data is unavailable on this device") }
        store = healthStore
        self.workoutConfiguration = workoutConfiguration.copy() as! HKWorkoutConfiguration
        _main = HKWorkoutActivity(workoutConfiguration: workoutConfiguration, start: Date(), end: nil, metadata: nil)
        _activity = _main
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(workoutConfiguration, forKey: "configuration") }
    public required init?(coder: NSCoder) {
        store = nil
        workoutConfiguration = coder.decodeObject(forKey: "configuration") as? HKWorkoutConfiguration ?? HKWorkoutConfiguration()
        _main = HKWorkoutActivity(workoutConfiguration: workoutConfiguration, start: Date(), end: nil, metadata: nil)
        _activity = _main
        type = .mirrored
        super.init()
    }

    /// the live builder of this session's workout (the same one each time)
    @available(iOS 26.0, *)
    @objc open func associatedWorkoutBuilder() -> HKLiveWorkoutBuilder {
        lock.lock(); defer { lock.unlock() }
        if let b = _builder as? HKLiveWorkoutBuilder { return b }
        let b = HKLiveWorkoutBuilder(healthStore: store ?? HKHealthStore(), configuration: workoutConfiguration, device: .local())
        b._session = self
        _builder = b
        return b
    }
    var _live: _HKLiveSink? { lock.lock(); defer { lock.unlock() }; return _builder as? _HKLiveSink }

    /// moves to a state, telling the delegate (on the session's queue, as HealthKit does)
    func _move(to new: HKWorkoutSessionState, at date: Date = Date(), allowedFrom: Set<HKWorkoutSessionState>) {
        lock.lock()
        let old = _state
        guard allowedFrom.contains(old) else { lock.unlock(); return }
        _state = new
        if new == .running, _start == nil { _start = date; _main.startDate = date }
        if new == .ended { _end = date; _main.endDate = date }
        lock.unlock()
        if new == .running, old != .paused {
            if let other = Self._running, other !== self, other.state != .ended {      // one running workout at a time
                other._fail(HKError(.errorAnotherWorkoutSessionStarted, "Another workout session was started"))
            }
            Self._running = self
        }
        NSLog("isim HealthKit: workout session %@ -> %@", Self._name(old), Self._name(new))
        Self.queue.async { [self] in
            _live?._sessionChanged(new, at: date)          // the builder has the data up to now before the delegate hears
            delegate?.workoutSession(self, didChangeTo: new, from: old, date: date)
        }
    }
    func _fail(_ e: Error) {
        _move(to: .ended, allowedFrom: [.notStarted, .prepared, .running, .paused, .stopped])
        Self.queue.async { [self] in delegate?.workoutSession(self, didFailWithError: e) }
    }
    func _event(_ t: HKWorkoutEventType, _ date: Date) {
        let e = HKWorkoutEvent(type: t, dateInterval: DateInterval(start: date, duration: 0), metadata: nil)
        Self.queue.async { [self] in
            delegate?.workoutSession?(self, didGenerate: e)
            _live?._sessionEvent(e)
        }
    }
    static func _name(_ s: HKWorkoutSessionState) -> String {
        switch s {
        case .notStarted: return "notStarted"; case .running: return "running"; case .ended: return "ended"
        case .paused: return "paused"; case .prepared: return "prepared"; case .stopped: return "stopped"
        }
    }

    @objc open func prepare() { _move(to: .prepared, allowedFrom: [.notStarted]) }
    @objc(startActivityWithDate:) open func startActivity(with date: Date?) {
        _move(to: .running, at: date ?? Date(), allowedFrom: [.notStarted, .prepared])
    }
    @objc open func pause() {
        guard state == .running else { return }
        let now = Date()
        _move(to: .paused, at: now, allowedFrom: [.running])
        _event(.pause, now)
    }
    @objc open func resume() {
        guard state == .paused else { return }
        let now = Date()
        _move(to: .running, at: now, allowedFrom: [.paused])
        _event(.resume, now)
    }
    @objc(stopActivityWithDate:) open func stopActivity(with date: Date?) {
        _move(to: .stopped, at: date ?? Date(), allowedFrom: [.running, .paused])
    }
    @objc open func end() {
        _move(to: .ended, allowedFrom: [.notStarted, .prepared, .running, .paused, .stopped])
        if Self._running === self { Self._running = nil }
    }
    /// starts the next activity of a multisport workout (a swim, then a ride)
    @objc(beginNewActivityWithConfiguration:date:metadata:)
    open func beginNewActivity(configuration workoutConfiguration: HKWorkoutConfiguration, date: Date, metadata: [String: Any]?) {
        let a = HKWorkoutActivity(workoutConfiguration: workoutConfiguration, start: date, end: nil, metadata: metadata)
        lock.lock(); _activity = a; lock.unlock()
        Self.queue.async { [self] in
            delegate?.workoutSession?(self, didBeginActivityWith: workoutConfiguration, date: date)
            _live?._beginActivity(a)
        }
    }
    @objc(endCurrentActivityOnDate:) open func endCurrentActivity(on date: Date) {
        lock.lock()
        let a = _activity
        guard a !== _main else { lock.unlock(); return }
        a.endDate = date
        _activity = _main
        lock.unlock()
        Self.queue.async { [self] in
            delegate?.workoutSession?(self, didEndActivityWith: a.workoutConfiguration, date: date)
            _live?._endActivity(a)
        }
    }
    /// isim has no paired Apple Watch, so there is no remote session to send to
    @objc(sendDataToRemoteWorkoutSession:completion:)
    open func sendToRemoteWorkoutSession(data: Data, completion: @escaping (Bool, Error?) -> Void) {
        _Privacy.reply { completion(false, HKError(.errorInvalidArgument, "There is no remote workout session")) }
    }
    public func sendToRemoteWorkoutSession(data: Data) async throws { try await _hkAsync { sendToRemoteWorkoutSession(data: data, completion: $0) } }
}

// MARK: - Live workout builder and its data source (iOS 26 on iPhone)

/// what a session tells its live builder (the builder's class is iOS 26; sessions are iOS 17)
protocol _HKLiveSink: AnyObject {
    func _sessionChanged(_ state: HKWorkoutSessionState, at date: Date)
    func _sessionEvent(_ e: HKWorkoutEvent)
    func _beginActivity(_ a: HKWorkoutActivity)
    func _endActivity(_ a: HKWorkoutActivity)
}

@available(iOS 26.0, *)
@objc(HKLiveWorkoutBuilderDelegate) public protocol HKLiveWorkoutBuilderDelegate: NSObjectProtocol {
    @objc(workoutBuilder:didCollectDataOfTypes:)
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>)
    @objc(workoutBuilderDidCollectEvent:)
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder)
    @objc(workoutBuilder:didBeginActivity:)
    optional func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didBegin workoutActivity: HKWorkoutActivity)
    @objc(workoutBuilder:didEndActivity:)
    optional func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didEnd workoutActivity: HKWorkoutActivity)
}

/// the workout of a session, collected while it runs
@available(iOS 26.0, *)
@objc(HKLiveWorkoutBuilder) open class HKLiveWorkoutBuilder: HKWorkoutBuilder, _HKLiveSink, @unchecked Sendable {
    @objc open weak var delegate: HKLiveWorkoutBuilderDelegate?
    weak var _session: HKWorkoutSession?
    @objc open var workoutSession: HKWorkoutSession? { _session }
    @objc open var shouldCollectWorkoutEvents = true
    @objc open var dataSource: HKLiveWorkoutDataSource?
    @objc open var currentWorkoutActivity: HKWorkoutActivity? {
        guard let s = _session else { return nil }
        let a = s.currentActivity
        return locked { _activities.contains { $0 === a } } ? _withStatistics(a) : nil
    }
    /// the active time so far (pauses left out)
    @objc open var elapsedTime: TimeInterval { elapsedTime(at: Date()) }
    var timer: DispatchSourceTimer?
    /// the simulated workout's active seconds so far, and the last tick
    var active: TimeInterval = 0, lastTick: Date?

    override func _began() { _tick(Date()) ; _updateTimer() }
    override func _ended() { _updateTimer() }
    func _sessionChanged(_ state: HKWorkoutSessionState, at date: Date) {
        if state == .paused || state == .stopped || state == .ended { _tick(date) }     // the data up to the pause or the end
        locked { lastTick = date }
        _updateTimer()
    }
    func _sessionEvent(_ e: HKWorkoutEvent) {
        guard shouldCollectWorkoutEvents, locked({ _start != nil && _end == nil && !_finished }) else { return }
        locked { _events.append(e) }
        HKWorkoutSession.queue.async { self.delegate?.workoutBuilderDidCollectEvent(self) }
    }
    func _beginActivity(_ a: HKWorkoutActivity) {
        guard locked({ _start != nil && !_finished }) else { return }
        locked { _activities.append(a) }
        delegate?.workoutBuilder?(self, didBegin: a)
    }
    func _endActivity(_ a: HKWorkoutActivity) { delegate?.workoutBuilder?(self, didEnd: _withStatistics(a)) }

    /// collects while the session runs and the builder is between beginCollection and endCollection
    var collecting: Bool { locked { _start != nil && _end == nil && !_finished } && _session?.state == .running }
    func _updateTimer() {
        if collecting, timer == nil {
            let t = DispatchSource.makeTimerSource(queue: HKWorkoutSession.queue)
            t.schedule(deadline: .now() + 1, repeating: 1)
            t.setEventHandler { [weak self] in self?._tick(Date()) }
            timer = t
            t.resume()
        } else if !collecting, let t = timer {
            t.cancel(); timer = nil
        }
    }
    /// the simulated data since the last tick: one sample of each collected type
    func _tick(_ now: Date) {
        guard let source = dataSource, locked({ _start != nil && !_finished }) else { return }
        let from: Date = locked { lastTick ?? _start ?? now }
        locked { lastTick = now }
        let running = _session?.state == .running || _session?.state == .paused || _session?.state == .stopped || _session?.state == .ended
        guard running, now.timeIntervalSince(from) >= 0.5 else { return }
        let dt = now.timeIntervalSince(from)
        let t = locked { active }
        locked { active += dt }
        let samples = source._samples(from, now, activeAt: t + dt, seconds: dt, configuration: config)
        guard !samples.isEmpty else { return }
        add(samples) { ok, _ in
            guard ok else { return }
            HKWorkoutSession.queue.async { self.delegate?.workoutBuilder(self, didCollectDataOf: Set(samples.map(\.sampleType))) }
        }
    }
}

/// what the live builder collects: by default the heart rate, active energy and the activity's distance
@available(iOS 26.0, *)
@objc(HKLiveWorkoutDataSource) open class HKLiveWorkoutDataSource: NSObject, @unchecked Sendable {
    let lock = NSLock()
    var types: Set<HKQuantityType>
    var predicates: [String: NSPredicate] = [:]
    @objc(initWithHealthStore:workoutConfiguration:)
    public init(healthStore: HKHealthStore, workoutConfiguration configuration: HKWorkoutConfiguration?) {
        types = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        if let c = configuration, _HKWorkoutSimulation.speed(c.activityType) > 0 {
            types.insert(HKQuantityType(_HKWorkoutData.distanceType(c.activityType, swimming: c.swimmingLocationType)))
        }
        if configuration?.activityType == .swimming { types.insert(HKQuantityType(.swimmingStrokeCount)) }
        super.init()
    }
    @objc open var typesToCollect: Set<HKQuantityType> { lock.lock(); defer { lock.unlock() }; return types }
    @objc(enableCollectionForType:predicate:) open func enableCollection(for quantityType: HKQuantityType, predicate: NSPredicate?) {
        lock.lock(); types.insert(quantityType); predicates[quantityType.identifier] = predicate; lock.unlock()
    }
    @objc(disableCollectionForType:) open func disableCollection(for quantityType: HKQuantityType) {
        lock.lock(); types.remove(quantityType); predicates[quantityType.identifier] = nil; lock.unlock()
    }
    /// the simulated samples of the types the app may write, for the stretch from..to
    func _samples(_ from: Date, _ to: Date, activeAt t: TimeInterval, seconds dt: TimeInterval, configuration c: HKWorkoutConfiguration) -> [HKQuantitySample] {
        lock.lock(); let want = types, preds = predicates; lock.unlock()
        var out: [HKQuantitySample] = []
        for type in want.sorted(by: { $0.identifier < $1.identifier }) where _HKAuth.share(type.identifier) == true {
            guard let v = _HKWorkoutSimulation.value(type.identifier, c.activityType, activeAt: t, seconds: dt) else { continue }
            let unit = _HKUnits.canonical(type.identifier)
            let instant = type.aggregationStyle != .cumulative
            let s = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: v), start: instant ? to : from, end: to)
            if let p = preds[type.identifier], !p.evaluate(with: s) { continue }
            out.append(s)
        }
        return out
    }
}

/// isim's simulated exerciser: steady numbers for the activity, so tests can count on them
enum _HKWorkoutSimulation {
    /// metres a second
    static func speed(_ a: HKWorkoutActivityType) -> Double {
        switch a {
        case .running, .trackAndField: return 2.9
        case .walking, .hiking, .wheelchairWalkPace: return 1.4
        case .wheelchairRunPace: return 2.5
        case .cycling, .handCycling: return 6.5
        case .swimming: return 0.8
        case .crossCountrySkiing: return 3.0
        case .downhillSkiing, .snowboarding, .snowSports: return 8.0
        case .rowing, .paddleSports: return 2.5
        default: return 0
        }
    }
    /// kilocalories a minute once warmed up
    static func energy(_ a: HKWorkoutActivityType) -> Double {
        switch a {
        case .running, .highIntensityIntervalTraining, .crossCountrySkiing: return 11
        case .cycling, .swimming, .rowing: return 9
        case .walking, .hiking: return 4.5
        case .yoga, .mindAndBody, .flexibility, .cooldown, .taiChi: return 3
        default: return 6.5
        }
    }
    /// beats a minute the heart rate settles at
    static func heartRate(_ a: HKWorkoutActivityType) -> Double {
        switch a {
        case .running, .highIntensityIntervalTraining: return 152
        case .cycling, .swimming, .rowing, .crossCountrySkiing: return 138
        case .walking, .hiking: return 104
        case .yoga, .mindAndBody, .flexibility, .cooldown, .taiChi: return 88
        default: return 120
        }
    }
    static func warm(_ t: TimeInterval) -> Double { 1 - exp(-t / 45) }
    /// a type's value for the second ending at active time t (cumulative types: the amount over dt)
    static func value(_ id: String, _ a: HKWorkoutActivityType, activeAt t: TimeInterval, seconds dt: TimeInterval) -> Double? {
        switch id {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return (72 + (heartRate(a) - 72) * warm(t) + 2 * sin(t / 7)).rounded()
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return energy(a) / 60 * dt * (0.6 + 0.4 * warm(t))
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return 1.2 / 60 * dt
        case HKQuantityTypeIdentifier.swimmingStrokeCount.rawValue:
            return (0.5 * dt).rounded()
        case let d where _HKWorkoutData.distanceTypes.map(\.rawValue).contains(d):
            let v = speed(a)
            return v > 0 ? v * dt * (0.85 + 0.15 * warm(t)) : nil
        default:
            return nil
        }
    }
}

// MARK: - The health store's workout members

nonisolated(unsafe) private var _hkMirroringKey: UInt8 = 0

extension HKHealthStore {
    /// called when an Apple Watch mirrors its workout session to iPhone (isim has no watch: never called)
    @available(iOS 17.0, *)
    @objc open var workoutSessionMirroringStartHandler: ((HKWorkoutSession) -> Void)? {
        get { objc_getAssociatedObject(self, &_hkMirroringKey) as? (HKWorkoutSession) -> Void }
        set { objc_setAssociatedObject(self, &_hkMirroringKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
    /// the workout session that was running when the app quit (isim: the one running in this process, if any)
    @available(iOS 26.0, *)
    @objc(recoverActiveWorkoutSessionWithCompletion:)
    open func recoverActiveWorkoutSession(completion: @escaping (HKWorkoutSession?, Error?) -> Void) {
        let s = HKWorkoutSession._running
        _Privacy.reply { completion(s?.state == .ended ? nil : s, nil) }
    }
    @available(iOS 26.0, *)
    public func recoverActiveWorkoutSession() async throws -> HKWorkoutSession? {
        await withCheckedContinuation { k in recoverActiveWorkoutSession { s, _ in k.resume(returning: s) } }
    }
    /// starts the workout app on the paired Apple Watch (isim has none)
    @objc(startWatchAppWithWorkoutConfiguration:completion:)
    open func startWatchApp(with workoutConfiguration: HKWorkoutConfiguration, completion: @escaping (Bool, Error?) -> Void) {
        NSLog("isim HealthKit: no Apple Watch is paired; the watch app cannot be started")
        _Privacy.reply { completion(false, HKError(.errorHealthDataUnavailable, "No Apple Watch is paired")) }
    }
    public func startWatchApp(toHandle workoutConfiguration: HKWorkoutConfiguration) async throws {
        try await _hkAsync { startWatchApp(with: workoutConfiguration, completion: $0) }
    }
}
