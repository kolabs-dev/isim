// isim HealthKit: workouts — the activity and location types (Apple's raw values; WorkoutKit's plans use them), the
// workout configuration, events and activities, HKWorkout itself, workout routes and their queries, and the workout
// predicates. Workouts are kept in the device's Health database with the other samples (issue #418); the builders
// that make them are in WorkoutBuilder.swift.
import Foundation
import CoreLocation

@objc public enum HKWorkoutActivityType: UInt, Sendable {
    case americanFootball = 1, archery, australianFootball, badminton, baseball, basketball, bowling, boxing, climbing
    case cricket, crossTraining, curling, cycling
    case elliptical = 16, equestrianSports, fencing, fishing, functionalStrengthTraining, golf, gymnastics, handball, hiking
    case hockey, hunting, lacrosse, martialArts, mindAndBody
    case paddleSports = 31, play, preparationAndRecovery, racquetball, rowing, rugby, running, sailing, skatingSports
    case snowSports, soccer, softball, squash, stairClimbing, surfingSports, swimming, tableTennis, tennis, trackAndField
    case traditionalStrengthTraining, volleyball, walking, waterFitness, waterPolo, waterSports, wrestling, yoga
    case barre, coreTraining, crossCountrySkiing, downhillSkiing, flexibility, highIntensityIntervalTraining, jumpRope
    case kickboxing, pilates, snowboarding, stairs, stepTraining, wheelchairWalkPace, wheelchairRunPace, taiChi
    case mixedCardio, handCycling, discSports, fitnessGaming, cardioDance, socialDance, pickleball, cooldown
    case swimBikeRun = 82, transition, underwaterDiving
    case other = 3000
}

@objc public enum HKWorkoutSessionLocationType: Int, Sendable { case unknown = 1, indoor, outdoor }
@objc public enum HKWorkoutSwimmingLocationType: Int, Sendable { case unknown = 0, pool, openWater }
@objc public enum HKWorkoutEventType: Int, Sendable {
    case pause = 1, resume, lap, marker, motionPaused, motionResumed, segment, pauseOrResumeRequest
}

public let HKWorkoutTypeIdentifier = "HKWorkoutTypeIdentifier"
public let HKWorkoutRouteTypeIdentifier = "HKWorkoutRouteTypeIdentifier"
public let HKDataTypeIdentifierHeartbeatSeries = "HKDataTypeIdentifierHeartbeatSeries"
public let HKMetadataKeyIndoorWorkout = "HKIndoorWorkout"
public let HKMetadataKeyCoachedWorkout = "HKCoachedWorkout"
public let HKMetadataKeyWorkoutBrandName = "HKWorkoutBrandName"
public let HKWorkoutSortIdentifierDuration = "duration"
public let HKWorkoutSortIdentifierTotalDistance = "totalDistance"
public let HKWorkoutSortIdentifierTotalEnergyBurned = "totalEnergyBurned"
public let HKWorkoutSortIdentifierTotalSwimmingStrokeCount = "totalSwimmingStrokeCount"
public let HKWorkoutSortIdentifierTotalFlightsClimbed = "totalFlightsClimbed"
public let HKPredicateKeyPathWorkout = "workout"
public let HKPredicateKeyPathWorkoutType = "workoutType"
public let HKPredicateKeyPathWorkoutDuration = "duration"
public let HKPredicateKeyPathWorkoutTotalDistance = "totalDistance"
public let HKPredicateKeyPathWorkoutTotalEnergyBurned = "totalEnergyBurned"
public let HKPredicateKeyPathWorkoutTotalSwimmingStrokeCount = "totalSwimmingStrokeCount"
public let HKPredicateKeyPathWorkoutTotalFlightsClimbed = "totalFlightsClimbed"
public let HKPredicateKeyPathWorkoutSumQuantity = "sumQuantity"
public let HKPredicateKeyPathWorkoutMinimumQuantity = "minimumQuantity"
public let HKPredicateKeyPathWorkoutMaximumQuantity = "maximumQuantity"
public let HKPredicateKeyPathWorkoutAverageQuantity = "averageQuantity"
public let HKPredicateKeyPathWorkoutActivity = "workoutActivity"
public let HKPredicateKeyPathWorkoutActivityType = "workoutActivityType"
public let HKPredicateKeyPathWorkoutActivityStartDate = "workoutActivityStartDate"
public let HKPredicateKeyPathWorkoutActivityEndDate = "workoutActivityEndDate"
public let HKPredicateKeyPathWorkoutActivityDuration = "workoutActivityDuration"
public let HKPredicateKeyPathWorkoutActivitySumQuantity = "workoutActivitySumQuantity"
public let HKPredicateKeyPathWorkoutActivityMinimumQuantity = "workoutActivityMinimumQuantity"
public let HKPredicateKeyPathWorkoutActivityMaximumQuantity = "workoutActivityMaximumQuantity"
public let HKPredicateKeyPathWorkoutActivityAverageQuantity = "workoutActivityAverageQuantity"

// MARK: - Configuration, events, activities

/// what a workout is: its activity, where it happens, and a pool's lap length
@objc(HKWorkoutConfiguration) open class HKWorkoutConfiguration: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open var activityType: HKWorkoutActivityType = .other
    @objc open var locationType: HKWorkoutSessionLocationType = .unknown
    @objc open var swimmingLocationType: HKWorkoutSwimmingLocationType = .unknown
    @objc open var lapLength: HKQuantity?
    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(Int(activityType.rawValue), forKey: "activityType"); coder.encode(locationType.rawValue, forKey: "locationType")
        coder.encode(swimmingLocationType.rawValue, forKey: "swimmingLocationType")
        if let l = lapLength { coder.encode(l.doubleValue(for: .meter()), forKey: "lapLength") }
    }
    public required init?(coder: NSCoder) {
        activityType = HKWorkoutActivityType(rawValue: UInt(coder.decodeInteger(forKey: "activityType"))) ?? .other
        locationType = HKWorkoutSessionLocationType(rawValue: coder.decodeInteger(forKey: "locationType")) ?? .unknown
        swimmingLocationType = HKWorkoutSwimmingLocationType(rawValue: coder.decodeInteger(forKey: "swimmingLocationType")) ?? .unknown
        if coder.containsValue(forKey: "lapLength") { lapLength = HKQuantity(unit: .meter(), doubleValue: coder.decodeDouble(forKey: "lapLength")) }
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any {
        let c = HKWorkoutConfiguration()
        c.activityType = activityType; c.locationType = locationType; c.swimmingLocationType = swimmingLocationType; c.lapLength = lapLength
        return c
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? HKWorkoutConfiguration else { return false }
        return o.activityType == activityType && o.locationType == locationType && o.swimmingLocationType == swimmingLocationType
    }
    open override var hash: Int { Int(activityType.rawValue) &* 31 &+ locationType.rawValue }
}

/// something that happened during a workout: a pause, a lap, a marker
@objc(HKWorkoutEvent) open class HKWorkoutEvent: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var type: HKWorkoutEventType
    @objc open private(set) var dateInterval: DateInterval
    @objc open private(set) var metadata: [String: Any]?
    public init(type: HKWorkoutEventType, dateInterval: DateInterval, metadata: [String: Any]?) {
        self.type = type; self.dateInterval = dateInterval; self.metadata = metadata
    }
    @objc(workoutEventWithType:dateInterval:metadata:)
    open class func _objc_event(_ type: HKWorkoutEventType, dateInterval: DateInterval, metadata: [String: Any]?) -> HKWorkoutEvent {
        HKWorkoutEvent(type: type, dateInterval: dateInterval, metadata: metadata)
    }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(type.rawValue, forKey: "type")
        coder.encode(dateInterval.start.timeIntervalSince1970, forKey: "start"); coder.encode(dateInterval.duration, forKey: "duration")
    }
    public required init?(coder: NSCoder) {
        type = HKWorkoutEventType(rawValue: coder.decodeInteger(forKey: "type")) ?? .marker
        dateInterval = DateInterval(start: Date(timeIntervalSince1970: coder.decodeDouble(forKey: "start")), duration: coder.decodeDouble(forKey: "duration"))
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override var description: String { "<HKWorkoutEvent \(type.rawValue) \(dateInterval)>" }
}

/// one activity of a workout (a multisport workout has several; iOS 16)
@objc(HKWorkoutActivity) open class HKWorkoutActivity: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc(UUID) open private(set) var uuid: UUID
    @objc open private(set) var workoutConfiguration: HKWorkoutConfiguration
    @objc open internal(set) var startDate: Date
    @objc open internal(set) var endDate: Date?
    @objc open internal(set) var metadata: [String: Any]?
    @objc open internal(set) var workoutEvents: [HKWorkoutEvent] = []
    @objc open internal(set) var allStatistics: [HKQuantityType: HKStatistics] = [:]
    /// the time it lasted, less its pauses
    @objc open var duration: TimeInterval { _HKWorkoutTime.elapsed(startDate, endDate ?? Date(), workoutEvents) }
    @objc(statisticsForType:) open func statistics(for quantityType: HKQuantityType) -> HKStatistics? { allStatistics[quantityType] }
    @objc(initWithWorkoutConfiguration:startDate:endDate:metadata:)
    public init(workoutConfiguration: HKWorkoutConfiguration, start startDate: Date, end endDate: Date?, metadata: [String: Any]?) {
        uuid = UUID(); self.workoutConfiguration = workoutConfiguration.copy() as! HKWorkoutConfiguration
        self.startDate = startDate; self.endDate = endDate; self.metadata = metadata
    }
    init(uuid: UUID, _ c: HKWorkoutConfiguration, _ s: Date, _ e: Date?, _ m: [String: Any]?) {
        self.uuid = uuid; workoutConfiguration = c; startDate = s; endDate = e; metadata = m
    }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(uuid.uuidString, forKey: "uuid"); coder.encode(workoutConfiguration, forKey: "configuration")
        coder.encode(startDate.timeIntervalSince1970, forKey: "start")
        if let e = endDate { coder.encode(e.timeIntervalSince1970, forKey: "end") }
    }
    public required init?(coder: NSCoder) {
        uuid = UUID(uuidString: coder.decodeObject(forKey: "uuid") as? String ?? "") ?? UUID()
        workoutConfiguration = coder.decodeObject(forKey: "configuration") as? HKWorkoutConfiguration ?? HKWorkoutConfiguration()
        startDate = Date(timeIntervalSince1970: coder.decodeDouble(forKey: "start"))
        endDate = coder.containsValue(forKey: "end") ? Date(timeIntervalSince1970: coder.decodeDouble(forKey: "end")) : nil
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}

enum _HKWorkoutTime {
    /// the time from start to end less the paused stretches (a pause event starts one, a resume ends it)
    static func elapsed(_ start: Date, _ end: Date, _ events: [HKWorkoutEvent]) -> TimeInterval {
        var paused: TimeInterval = 0, since: Date?
        for e in events.sorted(by: { $0.dateInterval.start < $1.dateInterval.start }) where e.dateInterval.start <= end {
            switch e.type {
            case .pause, .motionPaused: if since == nil { since = e.dateInterval.start }
            case .resume, .motionResumed: if let s = since { paused += e.dateInterval.start.timeIntervalSince(s); since = nil }
            default: break
            }
        }
        if let s = since { paused += end.timeIntervalSince(s) }
        return max(0, end.timeIntervalSince(start) - paused)
    }
}

// MARK: - Workouts

@objc(HKWorkout) open class HKWorkout: HKSample, @unchecked Sendable {
    @objc open internal(set) var workoutActivityType: HKWorkoutActivityType
    @objc open internal(set) var duration: TimeInterval
    @objc open internal(set) var workoutEvents: [HKWorkoutEvent]?
    @objc open internal(set) var workoutActivities: [HKWorkoutActivity] = []
    @objc open internal(set) var allStatistics: [HKQuantityType: HKStatistics] = [:]
    @objc(statisticsForType:) open func statistics(for quantityType: HKQuantityType) -> HKStatistics? { allStatistics[quantityType] }
    /// the workout plan a WorkoutKit app attached (isim: none)
    var _plan: AnyObject?

    @available(iOS, introduced: 8.0, deprecated: 18.0, message: "Use statisticsForType: passing the HKQuantityType for HKQuantityTypeIdentifierActiveEnergyBurned")
    @objc open var totalEnergyBurned: HKQuantity? { _sum(.activeEnergyBurned) }
    @available(iOS, introduced: 8.0, deprecated: 27.2, message: "Use statisticsForType: passing the HKQuantityType for the desired distance type")
    @objc open var totalDistance: HKQuantity? {
        for t in _HKWorkoutData.distanceTypes { if let q = _sum(t) { return q } }
        return nil
    }
    @available(iOS, introduced: 10.0, deprecated: 18.0, message: "Use statisticsForType: passing the HKQuantityType for HKQuantityTypeIdentifierSwimmingStrokeCount")
    @objc open var totalSwimmingStrokeCount: HKQuantity? { _sum(.swimmingStrokeCount) }
    @available(iOS, introduced: 11.0, deprecated: 18.0, message: "Use statisticsForType: passing the HKQuantityType for HKQuantityTypeIdentifierFlightsClimbed")
    @objc open var totalFlightsClimbed: HKQuantity? { _sum(.flightsClimbed) }
    func _sum(_ id: HKQuantityTypeIdentifier) -> HKQuantity? { allStatistics[HKQuantityType(id)]?.sumQuantity() }

    init(_ activity: HKWorkoutActivityType, _ start: Date, _ end: Date, duration: TimeInterval, events: [HKWorkoutEvent]?, metadata: [String: Any]?) {
        workoutActivityType = activity; self.duration = duration; workoutEvents = events
        super.init(HKWorkoutType(HKWorkoutTypeIdentifier), start, end, metadata)
    }
    /// a workout recorded afterwards, with its totals
    func _totals(energy: HKQuantity?, distance: HKQuantity?, strokes: HKQuantity? = nil, flights: HKQuantity? = nil) {
        let d = _HKWorkoutData.distanceType(workoutActivityType, swimming: nil)
        for (id, q) in [(HKQuantityTypeIdentifier.activeEnergyBurned, energy), (d, distance), (.swimmingStrokeCount, strokes), (.flightsClimbed, flights)] {
            guard let q else { continue }
            let t = HKQuantityType(id)
            allStatistics[t] = HKStatistics(t, startDate, endDate, fixed: _HKStat(type: id.rawValue, sum: q.doubleValue(for: _HKUnits.canonical(id.rawValue)),
                                                                             start: startDate.timeIntervalSince1970, end: endDate.timeIntervalSince1970))
        }
    }
    @available(iOS, introduced: 8.0, deprecated: 17.0, message: "Use HKWorkoutBuilder")
    public convenience init(activityType workoutActivityType: HKWorkoutActivityType, start startDate: Date, end endDate: Date) {
        self.init(workoutActivityType, startDate, endDate, duration: endDate.timeIntervalSince(startDate), events: nil, metadata: nil)
    }
    @available(iOS, introduced: 8.0, deprecated: 17.0, message: "Use HKWorkoutBuilder")
    public convenience init(activityType workoutActivityType: HKWorkoutActivityType, start startDate: Date, end endDate: Date, duration: TimeInterval,
                            totalEnergyBurned: HKQuantity?, totalDistance: HKQuantity?, metadata: [String: Any]?) {
        self.init(workoutActivityType, startDate, endDate, duration: duration > 0 ? duration : endDate.timeIntervalSince(startDate), events: nil, metadata: metadata)
        _totals(energy: totalEnergyBurned, distance: totalDistance)
    }
    @available(iOS, introduced: 8.0, deprecated: 17.0, message: "Use HKWorkoutBuilder")
    public convenience init(activityType workoutActivityType: HKWorkoutActivityType, start startDate: Date, end endDate: Date, workoutEvents: [HKWorkoutEvent]?,
                            totalEnergyBurned: HKQuantity?, totalDistance: HKQuantity?, metadata: [String: Any]?) {
        self.init(workoutActivityType, startDate, endDate, duration: _HKWorkoutTime.elapsed(startDate, endDate, workoutEvents ?? []), events: workoutEvents, metadata: metadata)
        _totals(energy: totalEnergyBurned, distance: totalDistance)
    }
    @available(iOS, introduced: 10.0, deprecated: 17.0, message: "Use HKWorkoutBuilder")
    public convenience init(activityType workoutActivityType: HKWorkoutActivityType, start startDate: Date, end endDate: Date, workoutEvents: [HKWorkoutEvent]?,
                            totalEnergyBurned: HKQuantity?, totalDistance: HKQuantity?, totalSwimmingStrokeCount: HKQuantity?, device: HKDevice?, metadata: [String: Any]?) {
        self.init(workoutActivityType, startDate, endDate, duration: _HKWorkoutTime.elapsed(startDate, endDate, workoutEvents ?? []), events: workoutEvents, metadata: metadata)
        _totals(energy: totalEnergyBurned, distance: totalDistance, strokes: totalSwimmingStrokeCount)
    }
    @available(iOS, introduced: 11.0, deprecated: 17.0, message: "Use HKWorkoutBuilder")
    public convenience init(activityType workoutActivityType: HKWorkoutActivityType, start startDate: Date, end endDate: Date, workoutEvents: [HKWorkoutEvent]?,
                            totalEnergyBurned: HKQuantity?, totalDistance: HKQuantity?, totalFlightsClimbed: HKQuantity?, device: HKDevice?, metadata: [String: Any]?) {
        self.init(workoutActivityType, startDate, endDate, duration: _HKWorkoutTime.elapsed(startDate, endDate, workoutEvents ?? []), events: workoutEvents, metadata: metadata)
        _totals(energy: totalEnergyBurned, distance: totalDistance, flights: totalFlightsClimbed)
    }
    open override var description: String {
        String(format: "<HKWorkout %lu %.0f s %@>", workoutActivityType.rawValue, duration, startDate as NSDate)
    }
}

// MARK: - Series: workout routes

@objc(HKSeriesType) open class HKSeriesType: HKSampleType, @unchecked Sendable {
    @objc(workoutRouteType) open class func workoutRoute() -> Self { _make(HKWorkoutRouteTypeIdentifier) }
    @objc(heartbeatSeriesType) open class func heartbeat() -> Self { _make(HKDataTypeIdentifierHeartbeatSeries) }
    static func _make<T: HKSeriesType>(_ id: String) -> T { HKSeriesType(id) as! T }
}
extension HKObjectType {
    @objc(seriesTypeForIdentifier:) open class func seriesType(forIdentifier identifier: String) -> HKSeriesType? {
        [HKWorkoutRouteTypeIdentifier, HKDataTypeIdentifierHeartbeatSeries].contains(identifier) ? HKSeriesType(identifier) : nil
    }
}
@objc(HKSeriesSample) open class HKSeriesSample: HKSample, @unchecked Sendable {
    @objc open internal(set) var count: Int = 0
}
/// the locations of a workout, read with HKWorkoutRouteQuery
@objc(HKWorkoutRoute) open class HKWorkoutRoute: HKSeriesSample, @unchecked Sendable {
    var _locations: [CLLocation] = []
    init(_ locations: [CLLocation], metadata: [String: Any]?) {
        let start = locations.first?.timestamp ?? Date(), end = locations.last?.timestamp ?? start
        super.init(HKSeriesType.workoutRoute(), start, end, metadata)
        _locations = locations; count = locations.count
    }
}

@objc(HKWorkoutRouteQuery) open class HKWorkoutRouteQuery: HKQuery, @unchecked Sendable {
    public typealias Handler = (HKWorkoutRouteQuery, [CLLocation]?, Bool, Error?) -> Void
    let route: HKWorkoutRoute, interval: DateInterval?, handler: Handler
    @objc(initWithRoute:dataHandler:)
    public init(route workoutRoute: HKWorkoutRoute, dataHandler: @escaping (HKWorkoutRouteQuery, [CLLocation]?, Bool, Error?) -> Void) {
        route = workoutRoute; interval = nil; handler = dataHandler
        super.init(HKSeriesType.workoutRoute(), nil)
    }
    @objc(initWithRoute:dateInterval:dataHandler:)
    public init(route workoutRoute: HKWorkoutRoute, dateInterval: DateInterval, dataHandler: @escaping (HKWorkoutRouteQuery, [CLLocation]?, Bool, Error?) -> Void) {
        route = workoutRoute; interval = dateInterval; handler = dataHandler
        super.init(HKSeriesType.workoutRoute(), nil)
    }
    /// the locations in batches (HealthKit hands them over in parts; the last call says done)
    override func run() {
        guard _HKDB.load().contains(where: { $0.uuid == route.uuid.uuidString && _HKDB.canSee($0.type, $0.bundle) }) else {
            handler(self, nil, true, HKError(.errorNoData, "No data available for the specified predicate.")); return
        }
        var all = route._locations
        if let i = interval { all = all.filter { i.contains($0.timestamp) } }
        let batch = 100
        if all.isEmpty { handler(self, [], true, nil); return }
        var i = 0
        while i < all.count && running {
            let part = Array(all[i..<min(i + batch, all.count)])
            i += batch
            handler(self, part, i >= all.count, nil)
        }
    }
}

/// reads a workout route's locations as an asynchronous sequence (iOS 15.4)
public struct HKWorkoutRouteQueryDescriptor: HKAsyncSequenceQuery, @unchecked Sendable {
    public var workoutRoute: HKWorkoutRoute
    public init(_ workoutRoute: HKWorkoutRoute) { self.workoutRoute = workoutRoute }
    public struct Results: AsyncSequence, @unchecked Sendable {
        public typealias Element = CLLocation
        let stream: AsyncThrowingStream<CLLocation, Error>
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncThrowingStream<CLLocation, Error>.AsyncIterator
            public mutating func next() async throws -> CLLocation? { try await base.next() }
        }
        public func makeAsyncIterator() -> Iterator { Iterator(base: stream.makeAsyncIterator()) }
    }
    public func results(for healthStore: HKHealthStore) -> Results {
        let route = workoutRoute
        return Results(stream: AsyncThrowingStream { k in
            healthStore.execute(HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error { k.finish(throwing: error); return }
                for l in locations ?? [] { k.yield(l) }
                if done { k.finish() }
            })
        })
    }
}

extension HKSamplePredicate where Sample == HKWorkout {
    public static func workout(_ predicate: NSPredicate? = nil) -> HKSamplePredicate<HKWorkout> { .init(HKObjectType.workoutType(), predicate) }
}
extension HKSamplePredicate where Sample == HKWorkoutRoute {
    public static func workoutRoute(_ predicate: NSPredicate? = nil) -> HKSamplePredicate<HKWorkoutRoute> { .init(HKSeriesType.workoutRoute(), predicate) }
}

// MARK: - Predicates

extension HKQuery {
    static func _compare(_ op: NSComparisonPredicate.Operator, _ a: Double, _ b: Double) -> Bool {
        switch op {
        case .equalTo: return a == b
        case .notEqualTo: return a != b
        case .lessThan: return a < b
        case .lessThanOrEqualTo: return a <= b
        case .greaterThan: return a > b
        case .greaterThanOrEqualTo: return a >= b
        default: return false
        }
    }
    static func _statistic(_ s: HKStatistics?, _ which: String) -> HKQuantity? {
        switch which {
        case "sum": return s?.sumQuantity()
        case "min": return s?.minimumQuantity()
        case "max": return s?.maximumQuantity()
        default: return s?.averageQuantity()
        }
    }
    static func _quantity(_ op: NSComparisonPredicate.Operator, _ q: HKQuantity?, _ value: HKQuantity) -> Bool {
        guard let q, q.is(compatibleWith: value.unit) else { return false }
        return _compare(op, q.doubleValue(for: value.unit), value.doubleValue(for: value.unit))
    }
    @objc(predicateForWorkoutsWithWorkoutActivityType:)
    open class func predicateForWorkouts(with workoutActivityType: HKWorkoutActivityType) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKWorkout)?.workoutActivityType == workoutActivityType }
    }
    @objc(predicateForWorkoutsWithOperatorType:duration:)
    open class func predicateForWorkouts(with operatorType: NSComparisonPredicate.Operator, duration: TimeInterval) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKWorkout).map { _compare(operatorType, $0.duration, duration) } ?? false }
    }
    @available(iOS, introduced: 8.0, deprecated: 18.0, message: "Use predicateForWorkoutsWithOperatorType:quantityType:sumQuantity:")
    @objc(predicateForWorkoutsWithOperatorType:totalEnergyBurned:)
    open class func predicateForWorkouts(with operatorType: NSComparisonPredicate.Operator, totalEnergyBurned: HKQuantity) -> NSPredicate {
        NSPredicate { o, _ in _quantity(operatorType, (o as? HKWorkout)?._sum(.activeEnergyBurned), totalEnergyBurned) }
    }
    @available(iOS, introduced: 8.0, deprecated: 27.2, message: "Use predicateForWorkoutsWithOperatorType:quantityType:sumQuantity:")
    @objc(predicateForWorkoutsWithOperatorType:totalDistance:)
    open class func predicateForWorkouts(with operatorType: NSComparisonPredicate.Operator, totalDistance: HKQuantity) -> NSPredicate {
        NSPredicate { o, _ in
            let w = o as? HKWorkout
            return _quantity(operatorType, _HKWorkoutData.distanceTypes.lazy.compactMap { w?._sum($0) }.first, totalDistance)
        }
    }
    @available(iOS, introduced: 10.0, deprecated: 18.0, message: "Use predicateForWorkoutsWithOperatorType:quantityType:sumQuantity:")
    @objc(predicateForWorkoutsWithOperatorType:totalSwimmingStrokeCount:)
    open class func predicateForWorkouts(with operatorType: NSComparisonPredicate.Operator, totalSwimmingStrokeCount: HKQuantity) -> NSPredicate {
        NSPredicate { o, _ in _quantity(operatorType, (o as? HKWorkout)?._sum(.swimmingStrokeCount), totalSwimmingStrokeCount) }
    }
    @available(iOS, introduced: 11.0, deprecated: 18.0, message: "Use predicateForWorkoutsWithOperatorType:quantityType:sumQuantity:")
    @objc(predicateForWorkoutsWithOperatorType:totalFlightsClimbed:)
    open class func predicateForWorkouts(with operatorType: NSComparisonPredicate.Operator, totalFlightsClimbed: HKQuantity) -> NSPredicate {
        NSPredicate { o, _ in _quantity(operatorType, (o as? HKWorkout)?._sum(.flightsClimbed), totalFlightsClimbed) }
    }
    static func _workoutStat(_ op: NSComparisonPredicate.Operator, _ t: HKQuantityType, _ which: String, _ q: HKQuantity) -> NSPredicate {
        NSPredicate { o, _ in
            if let w = o as? HKWorkout { return _quantity(op, _statistic(w.statistics(for: t), which), q) }
            if let a = o as? HKWorkoutActivity { return _quantity(op, _statistic(a.statistics(for: t), which), q) }
            return false
        }
    }
    @objc(predicateForWorkoutsWithOperatorType:quantityType:sumQuantity:)
    open class func predicateForWorkouts(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, sumQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "sum", sumQuantity)
    }
    @objc(predicateForWorkoutsWithOperatorType:quantityType:minimumQuantity:)
    open class func predicateForWorkouts(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, minimumQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "min", minimumQuantity)
    }
    @objc(predicateForWorkoutsWithOperatorType:quantityType:maximumQuantity:)
    open class func predicateForWorkouts(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, maximumQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "max", maximumQuantity)
    }
    @objc(predicateForWorkoutsWithOperatorType:quantityType:averageQuantity:)
    open class func predicateForWorkouts(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, averageQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "avg", averageQuantity)
    }
    /// workouts with an activity that matches (the predicate is one of the predicateForWorkoutActivities ones)
    @objc(predicateForWorkoutsWithActivityPredicate:)
    open class func predicateForWorkouts(activityPredicate: NSPredicate) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKWorkout)?.workoutActivities.contains { activityPredicate.evaluate(with: $0) } ?? false }
    }
    @objc(predicateForWorkoutActivitiesWithWorkoutActivityType:)
    open class func predicateForWorkoutActivities(workoutActivityType: HKWorkoutActivityType) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKWorkoutActivity)?.workoutConfiguration.activityType == workoutActivityType }
    }
    @objc(predicateForWorkoutActivitiesWithOperatorType:duration:)
    open class func predicateForWorkoutActivities(operatorType: NSComparisonPredicate.Operator, duration: TimeInterval) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKWorkoutActivity).map { _compare(operatorType, $0.duration, duration) } ?? false }
    }
    @objc(predicateForWorkoutActivitiesWithStartDate:endDate:options:)
    class func _objc_predicateForWorkoutActivities(_ startDate: Date?, endDate: Date?, options: UInt) -> NSPredicate {
        predicateForWorkoutActivities(start: startDate, end: endDate, options: QueryOptions(rawValue: options))
    }
    public class func predicateForWorkoutActivities(start startDate: Date?, end endDate: Date?, options: HKQuery.QueryOptions = []) -> NSPredicate {
        NSPredicate { o, _ in
            guard let a = o as? HKWorkoutActivity else { return false }
            let end = a.endDate ?? Date()
            if let s = startDate { if options.contains(.strictStartDate) ? a.startDate < s : end < s { return false } }
            if let e = endDate { if options.contains(.strictEndDate) ? end > e : a.startDate >= e { return false } }
            return true
        }
    }
    @objc(predicateForWorkoutActivitiesWithOperatorType:quantityType:sumQuantity:)
    open class func predicateForWorkoutActivities(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, sumQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "sum", sumQuantity)
    }
    @objc(predicateForWorkoutActivitiesWithOperatorType:quantityType:minimumQuantity:)
    open class func predicateForWorkoutActivities(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, minimumQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "min", minimumQuantity)
    }
    @objc(predicateForWorkoutActivitiesWithOperatorType:quantityType:maximumQuantity:)
    open class func predicateForWorkoutActivities(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, maximumQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "max", maximumQuantity)
    }
    @objc(predicateForWorkoutActivitiesWithOperatorType:quantityType:averageQuantity:)
    open class func predicateForWorkoutActivities(operatorType: NSComparisonPredicate.Operator, quantityType: HKQuantityType, averageQuantity: HKQuantity) -> NSPredicate {
        _workoutStat(operatorType, quantityType, "avg", averageQuantity)
    }
    /// the samples a workout builder added to the workout, and the workout's routes
    @objc(predicateForObjectsFromWorkout:)
    open class func predicateForObjects(from workout: HKWorkout) -> NSPredicate {
        let id = workout.uuid.uuidString
        return NSPredicate { o, _ in (o as? HKSample)?._workout == id }
    }
}

// MARK: - Storage: a workout's details in its database record

struct _HKStat: Codable {
    var type: String
    var sum: Double? = nil, min: Double? = nil, max: Double? = nil, avg: Double? = nil, recent: Double? = nil
    var start: Double, end: Double
}
struct _HKEventData: Codable {
    var type: Int, start: Double, duration: Double, metadata: [String: String]?
    init(_ e: HKWorkoutEvent) {
        type = e.type.rawValue; start = e.dateInterval.start.timeIntervalSince1970; duration = e.dateInterval.duration
        metadata = e.metadata?.mapValues { "\($0)" }
    }
    var event: HKWorkoutEvent {
        HKWorkoutEvent(type: HKWorkoutEventType(rawValue: type) ?? .marker, dateInterval: DateInterval(start: Date(timeIntervalSince1970: start), duration: duration),
                       metadata: metadata)
    }
}
struct _HKConfigData: Codable {
    var activity: UInt, location: Int, swimming: Int, lap: Double?
    init(_ c: HKWorkoutConfiguration) {
        activity = c.activityType.rawValue; location = c.locationType.rawValue; swimming = c.swimmingLocationType.rawValue
        lap = c.lapLength?.doubleValue(for: .meter())
    }
    var configuration: HKWorkoutConfiguration {
        let c = HKWorkoutConfiguration()
        c.activityType = HKWorkoutActivityType(rawValue: activity) ?? .other
        c.locationType = HKWorkoutSessionLocationType(rawValue: location) ?? .unknown
        c.swimmingLocationType = HKWorkoutSwimmingLocationType(rawValue: swimming) ?? .unknown
        c.lapLength = lap.map { HKQuantity(unit: .meter(), doubleValue: $0) }
        return c
    }
}
struct _HKActivityData: Codable {
    var uuid: String, config: _HKConfigData, start: Double, end: Double?, metadata: [String: String]?, events: [_HKEventData], stats: [_HKStat]
}
struct _HKWorkoutData: Codable {
    var activity: UInt, events: [_HKEventData]?, activities: [_HKActivityData], stats: [_HKStat]
    struct Location: Codable { var lat, lon, alt, t, h, v, speed, course: Double }
    init(activity: UInt, events: [_HKEventData]?, activities: [_HKActivityData], stats: [_HKStat]) {
        self.activity = activity; self.events = events; self.activities = activities; self.stats = stats
    }
    static let distanceTypes: [HKQuantityTypeIdentifier] = [.distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceWheelchair, .distanceDownhillSnowSports]
    /// the distance a workout of this activity measures
    static func distanceType(_ a: HKWorkoutActivityType, swimming: HKWorkoutSwimmingLocationType?) -> HKQuantityTypeIdentifier {
        switch a {
        case .cycling, .handCycling: return .distanceCycling
        case .swimming: return .distanceSwimming
        case .wheelchairRunPace, .wheelchairWalkPace: return .distanceWheelchair
        case .downhillSkiing, .snowboarding, .snowSports: return .distanceDownhillSnowSports
        default: return .distanceWalkingRunning
        }
    }
    static func stats(_ all: [HKQuantityType: HKStatistics]) -> [_HKStat] {
        all.values.map { $0._stat }.sorted { $0.type < $1.type }
    }
    static func statistics(_ s: [_HKStat]) -> [HKQuantityType: HKStatistics] {
        Dictionary(s.map { st in
            let t = HKQuantityType(st.type)
            return (t, HKStatistics(t, Date(timeIntervalSince1970: st.start), Date(timeIntervalSince1970: st.end), fixed: st))
        }, uniquingKeysWith: { a, _ in a })
    }
    init(_ w: HKWorkout) {
        activity = w.workoutActivityType.rawValue
        events = w.workoutEvents?.map(_HKEventData.init)
        activities = w.workoutActivities.map { a in
            _HKActivityData(uuid: a.uuid.uuidString, config: _HKConfigData(a.workoutConfiguration), start: a.startDate.timeIntervalSince1970,
                            end: a.endDate?.timeIntervalSince1970, metadata: a.metadata?.mapValues { "\($0)" }, events: a.workoutEvents.map(_HKEventData.init),
                            stats: Self.stats(a.allStatistics))
        }
        stats = Self.stats(w.allStatistics)
    }
    func workout(_ start: Date, _ end: Date, duration: TimeInterval, metadata: [String: Any]?) -> HKWorkout {
        let w = HKWorkout(HKWorkoutActivityType(rawValue: activity) ?? .other, start, end, duration: duration, events: events?.map(\.event), metadata: metadata)
        w.workoutActivities = activities.map { a in
            let act = HKWorkoutActivity(uuid: UUID(uuidString: a.uuid) ?? UUID(), a.config.configuration, Date(timeIntervalSince1970: a.start),
                                        a.end.map { Date(timeIntervalSince1970: $0) }, a.metadata)
            act.workoutEvents = a.events.map(\.event)
            act.allStatistics = Self.statistics(a.stats)
            return act
        }
        w.allStatistics = Self.statistics(stats)
        return w
    }
    static func encode<T: Encodable>(_ v: T) -> String? { (try? JSONEncoder().encode(v)).flatMap { String(data: $0, encoding: .utf8) } }
    static func decode<T: Decodable>(_ t: T.Type, _ s: String?) -> T? { s.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(t, from: $0) } }
    static func locations(_ ls: [CLLocation]) -> [Location] {
        ls.map { Location(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude, alt: $0.altitude, t: $0.timestamp.timeIntervalSince1970,
                          h: $0.horizontalAccuracy, v: $0.verticalAccuracy, speed: $0.speed, course: $0.course) }
    }
    static func locations(_ ls: [Location]) -> [CLLocation] {
        ls.map { CLLocation(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon), altitude: $0.alt, horizontalAccuracy: $0.h,
                            verticalAccuracy: $0.v, course: $0.course, speed: $0.speed, timestamp: Date(timeIntervalSince1970: $0.t)) }
    }
}
