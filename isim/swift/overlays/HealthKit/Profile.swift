// isim HealthKit (issue #419): the device's Health profile — characteristics (date of birth, sex, blood type, skin
// type, wheelchair use, move mode) and the activity rings' goals, kept in $ISIM_DATA/Library/Health/profile.json and set
// with `isim health profile|goals` like the Health app's profile — activity summaries (each day's rings, computed from
// the day's samples), correlations (blood pressure, food) and states of mind (iOS 18).
import Foundation

// MARK: - Characteristics

@objc public enum HKBloodType: Int, Sendable { case notSet = 0, aPositive, aNegative, bPositive, bNegative, abPositive, abNegative, oPositive, oNegative }
@objc public enum HKFitzpatrickSkinType: Int, Sendable { case notSet = 0, I, II, III, IV, V, VI }
@objc public enum HKWheelchairUse: Int, Sendable { case notSet = 0, no, yes }
@objc public enum HKActivityMoveMode: Int, Sendable { case activeEnergy = 1, appleMoveTime }
public enum HKCategoryValueAppleStandHour: Int, Sendable { case stood = 0, idle = 1 }

extension HKCharacteristicTypeIdentifier {
    public static let fitzpatrickSkinType = Self(rawValue: "HKCharacteristicTypeIdentifierFitzpatrickSkinType")
    public static let wheelchairUse = Self(rawValue: "HKCharacteristicTypeIdentifierWheelchairUse")
    public static let activityMoveMode = Self(rawValue: "HKCharacteristicTypeIdentifierActivityMoveMode")
}
extension HKQuantityTypeIdentifier {
    public static let appleMoveTime = Self("HKQuantityTypeIdentifierAppleMoveTime")
    public static let appleStandTime = Self("HKQuantityTypeIdentifierAppleStandTime")
}
extension HKCharacteristicType {
    public convenience init(_ identifier: HKCharacteristicTypeIdentifier) { self.init(identifier.rawValue) }
}

@objc(HKBloodTypeObject) open class HKBloodTypeObject: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var bloodType: HKBloodType = .notSet
    init(_ v: HKBloodType) { bloodType = v }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(bloodType.rawValue, forKey: "value") }
    public required init?(coder: NSCoder) { bloodType = HKBloodType(rawValue: coder.decodeInteger(forKey: "value")) ?? .notSet }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}
@objc(HKFitzpatrickSkinTypeObject) open class HKFitzpatrickSkinTypeObject: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var skinType: HKFitzpatrickSkinType = .notSet
    init(_ v: HKFitzpatrickSkinType) { skinType = v }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(skinType.rawValue, forKey: "value") }
    public required init?(coder: NSCoder) { skinType = HKFitzpatrickSkinType(rawValue: coder.decodeInteger(forKey: "value")) ?? .notSet }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}
@objc(HKWheelchairUseObject) open class HKWheelchairUseObject: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var wheelchairUse: HKWheelchairUse = .notSet
    init(_ v: HKWheelchairUse) { wheelchairUse = v }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(wheelchairUse.rawValue, forKey: "value") }
    public required init?(coder: NSCoder) { wheelchairUse = HKWheelchairUse(rawValue: coder.decodeInteger(forKey: "value")) ?? .notSet }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}
@objc(HKActivityMoveModeObject) open class HKActivityMoveModeObject: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var activityMoveMode: HKActivityMoveMode = .activeEnergy
    init(_ v: HKActivityMoveMode) { activityMoveMode = v }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(activityMoveMode.rawValue, forKey: "value") }
    public required init?(coder: NSCoder) { activityMoveMode = HKActivityMoveMode(rawValue: coder.decodeInteger(forKey: "value")) ?? .activeEnergy }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}

/// the device's Health profile (`isim health profile|goals` writes it)
struct _HKProfile: Codable {
    var dateOfBirth: String? = nil          // YYYY-MM-DD
    var sex = 0, blood = 0, skin = 0, wheelchair = 0, move = 1
    var moveGoal = 500.0, moveTimeGoal = 30.0, exerciseGoal = 30.0, standGoal = 12.0
    static var path: String { (_Privacy.deviceDir("Library/Health") as NSString).appendingPathComponent("profile.json") }
    static func load() -> _HKProfile { _Privacy.readJSON(_HKProfile.self, path) ?? _HKProfile() }
    /// a characteristic the app may read: not asked yet throws, denied reads as not set (iOS hides denial)
    static func readable(_ id: HKCharacteristicTypeIdentifier) throws -> Bool {
        switch _HKAuth.read(id.rawValue) {
        case nil: throw HKError(.errorAuthorizationNotDetermined, "Authorization not determined")
        case false?: return false
        default: return true
        }
    }
}

extension HKHealthStore {
    @objc(bloodTypeWithError:) open func bloodType() throws -> HKBloodTypeObject {
        HKBloodTypeObject(try _HKProfile.readable(.bloodType) ? HKBloodType(rawValue: _HKProfile.load().blood) ?? .notSet : .notSet)
    }
    @objc(fitzpatrickSkinTypeWithError:) open func fitzpatrickSkinType() throws -> HKFitzpatrickSkinTypeObject {
        HKFitzpatrickSkinTypeObject(try _HKProfile.readable(.fitzpatrickSkinType) ? HKFitzpatrickSkinType(rawValue: _HKProfile.load().skin) ?? .notSet : .notSet)
    }
    @objc(wheelchairUseWithError:) open func wheelchairUse() throws -> HKWheelchairUseObject {
        HKWheelchairUseObject(try _HKProfile.readable(.wheelchairUse) ? HKWheelchairUse(rawValue: _HKProfile.load().wheelchair) ?? .notSet : .notSet)
    }
    @objc(activityMoveModeWithError:) open func activityMoveMode() throws -> HKActivityMoveModeObject {
        HKActivityMoveModeObject(try _HKProfile.readable(.activityMoveMode) ? HKActivityMoveMode(rawValue: _HKProfile.load().move) ?? .activeEnergy : .activeEnergy)
    }
}

// MARK: - Activity summaries (the rings)

public let HKActivitySummaryTypeIdentifier = "HKActivitySummaryTypeIdentifier"
@objc(HKActivitySummaryType) open class HKActivitySummaryType: HKObjectType, @unchecked Sendable {}
extension HKObjectType {
    @objc open class func activitySummaryType() -> HKActivitySummaryType { HKActivitySummaryType(HKActivitySummaryTypeIdentifier) }
}

/// one day's rings: move (active energy, or move time in move-time mode), exercise and stand, with their goals
@objc(HKActivitySummary) open class HKActivitySummary: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    var _day = DateComponents()
    @objc open var activityMoveMode: HKActivityMoveMode = .activeEnergy
    @objc open var isPaused = false
    @objc open var activeEnergyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: 0)
    @objc open var activeEnergyBurnedGoal = HKQuantity(unit: .kilocalorie(), doubleValue: 0)
    @objc open var appleMoveTime = HKQuantity(unit: .minute(), doubleValue: 0)
    @objc open var appleMoveTimeGoal = HKQuantity(unit: .minute(), doubleValue: 0)
    @objc open var appleExerciseTime = HKQuantity(unit: .minute(), doubleValue: 0)
    @objc open var exerciseTimeGoal: HKQuantity?
    @available(iOS, introduced: 9.3, deprecated: 27.2, message: "Use exerciseTimeGoal")
    @objc open var appleExerciseTimeGoal: HKQuantity {
        get { exerciseTimeGoal ?? HKQuantity(unit: .minute(), doubleValue: 0) } set { exerciseTimeGoal = newValue }
    }
    @objc open var appleStandHours = HKQuantity(unit: .count(), doubleValue: 0)
    @objc open var standHoursGoal: HKQuantity?
    @available(iOS, introduced: 9.3, deprecated: 27.2, message: "Use standHoursGoal")
    @objc open var appleStandHoursGoal: HKQuantity {
        get { standHoursGoal ?? HKQuantity(unit: .count(), doubleValue: 0) } set { standHoursGoal = newValue }
    }
    public override init() { super.init() }
    /// the day it summarises (era, year, month and day in the given calendar)
    open func dateComponents(for calendar: Calendar) -> DateComponents {
        var c = _day
        c.calendar = calendar
        return c
    }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(_day.year ?? 0, forKey: "year"); coder.encode(_day.month ?? 0, forKey: "month"); coder.encode(_day.day ?? 0, forKey: "day")
        coder.encode(activeEnergyBurned.doubleValue(for: .kilocalorie()), forKey: "energy")
        coder.encode(appleExerciseTime.doubleValue(for: .minute()), forKey: "exercise")
        coder.encode(appleStandHours.doubleValue(for: .count()), forKey: "stand")
    }
    public required init?(coder: NSCoder) {
        _day = DateComponents(era: 1, year: coder.decodeInteger(forKey: "year"), month: coder.decodeInteger(forKey: "month"), day: coder.decodeInteger(forKey: "day"))
        activeEnergyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: coder.decodeDouble(forKey: "energy"))
        appleExerciseTime = HKQuantity(unit: .minute(), doubleValue: coder.decodeDouble(forKey: "exercise"))
        appleStandHours = HKQuantity(unit: .count(), doubleValue: coder.decodeDouble(forKey: "stand"))
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override var description: String {
        String(format: "<HKActivitySummary %d-%02d-%02d move %.0f/%.0f exercise %.0f stand %.0f>", _day.year ?? 0, _day.month ?? 0, _day.day ?? 0,
               activeEnergyBurned.doubleValue(for: .kilocalorie()), activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()),
               appleExerciseTime.doubleValue(for: .minute()), appleStandHours.doubleValue(for: .count()))
    }

    /// the days with any ring data, and today, from the samples this app may read
    static func compute() -> [HKActivitySummary] {
        let cal = Calendar(identifier: .gregorian)
        let p = _HKProfile.load()
        let ids = [HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, HKQuantityTypeIdentifier.appleExerciseTime.rawValue,
                   HKQuantityTypeIdentifier.appleMoveTime.rawValue, HKCategoryTypeIdentifier.appleStandHour.rawValue]
        var days: [DateComponents: [_HKRecord]] = [cal.dateComponents([.era, .year, .month, .day], from: Date()): []]
        for r in _HKDB.load() where ids.contains(r.type) && _HKDB.canSee(r.type, r.bundle) {
            days[cal.dateComponents([.era, .year, .month, .day], from: Date(timeIntervalSince1970: r.start)), default: []].append(r)
        }
        return days.keys.sorted { cal.date(from: $0)! < cal.date(from: $1)! }.map { day in
            let rs = days[day]!
            func sum(_ id: HKQuantityTypeIdentifier) -> Double { rs.filter { $0.type == id.rawValue }.map(\.value).reduce(0, +) }
            let s = HKActivitySummary()
            s._day = day
            s.activityMoveMode = HKActivityMoveMode(rawValue: p.move) ?? .activeEnergy
            s.activeEnergyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: sum(.activeEnergyBurned))
            s.activeEnergyBurnedGoal = HKQuantity(unit: .kilocalorie(), doubleValue: p.moveGoal)
            s.appleMoveTime = HKQuantity(unit: .minute(), doubleValue: sum(.appleMoveTime))
            s.appleMoveTimeGoal = HKQuantity(unit: .minute(), doubleValue: p.moveTimeGoal)
            s.appleExerciseTime = HKQuantity(unit: .minute(), doubleValue: sum(.appleExerciseTime))
            s.exerciseTimeGoal = HKQuantity(unit: .minute(), doubleValue: p.exerciseGoal)
            // a stand hour counts once per hour in which the person stood
            let stood = Set(rs.filter { $0.type == HKCategoryTypeIdentifier.appleStandHour.rawValue && $0.value == 0 }.map { Int($0.start / 3600) })
            s.appleStandHours = HKQuantity(unit: .count(), doubleValue: Double(stood.count))
            s.standHoursGoal = HKQuantity(unit: .count(), doubleValue: p.standGoal)
            return s
        }
    }
    static let sources: Set<String> = [HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, HKQuantityTypeIdentifier.appleExerciseTime.rawValue,
                                       HKQuantityTypeIdentifier.appleMoveTime.rawValue, HKCategoryTypeIdentifier.appleStandHour.rawValue]
}

extension HKQuery {
    /// the summary of one day (the components' era, year, month and day)
    public class func predicateForActivitySummary(with dateComponents: DateComponents) -> NSPredicate {
        NSPredicate { o, _ in
            guard let s = o as? HKActivitySummary else { return false }
            return s._day.year == dateComponents.year && s._day.month == dateComponents.month && s._day.day == dateComponents.day
        }
    }
    /// the summaries of the days from start to end, both included
    public class func predicate(forActivitySummariesBetweenStart startDateComponents: DateComponents, end endDateComponents: DateComponents) -> NSPredicate {
        let key = { (c: DateComponents) in (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0) }
        let a = key(startDateComponents), b = key(endDateComponents)
        return NSPredicate { o, _ in (o as? HKActivitySummary).map { (a...b).contains(key($0._day)) } ?? false }
    }
}

@objc(HKActivitySummaryQuery) open class HKActivitySummaryQuery: HKQuery, @unchecked Sendable {
    public typealias Handler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void
    let handler: Handler
    /// the summaries again whenever the samples behind them change, while the query runs
    open var updateHandler: Handler?
    public init(predicate: NSPredicate?, resultsHandler handler: @escaping (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void) {
        self.handler = handler
        super.init(HKObjectType.activitySummaryType(), predicate)
    }
    func summaries() -> ([HKActivitySummary]?, Error?) {
        switch _HKAuth.read(HKActivitySummaryTypeIdentifier) {
        case nil: return (nil, HKError(.errorAuthorizationNotDetermined, "Authorization not determined"))
        case false?: return ([], nil)
        default: break
        }
        var s = HKActivitySummary.compute()
        if let p = predicate { s = s.filter { p.evaluate(with: $0) } }
        return (s, nil)
    }
    override func run() {
        let (s, e) = summaries()
        if updateHandler != nil { _HKObservers.add(self) }     // before the results: a save made after them is seen
        handler(self, s, e)
    }
    func update() {
        guard running, let u = updateHandler else { return }
        let (s, e) = summaries()
        u(self, s, e)
    }
}

/// the activity summaries as a Swift query (iOS 15.4)
public struct HKActivitySummaryQueryDescriptor: HKAsyncQuery, HKAsyncSequenceQuery, @unchecked Sendable {
    public var predicate: NSPredicate?
    public init(predicate: NSPredicate?) { self.predicate = predicate }
    public func result(for healthStore: HKHealthStore) async throws -> [HKActivitySummary] {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<[HKActivitySummary], Error>) in
            healthStore.execute(HKActivitySummaryQuery(predicate: predicate) { _, s, e in
                if let e { k.resume(throwing: e) } else { k.resume(returning: s ?? []) }
            })
        }
    }
    public struct Results: AsyncSequence, @unchecked Sendable {
        public typealias Element = [HKActivitySummary]
        let stream: AsyncThrowingStream<[HKActivitySummary], Error>
        public struct Iterator: AsyncIteratorProtocol {
            var base: AsyncThrowingStream<[HKActivitySummary], Error>.AsyncIterator
            public mutating func next() async throws -> [HKActivitySummary]? { try await base.next() }
        }
        public func makeAsyncIterator() -> Iterator { Iterator(base: stream.makeAsyncIterator()) }
    }
    /// the summaries, then again after each change, until the iteration ends
    public func results(for healthStore: HKHealthStore) -> Results {
        let p = predicate
        return Results(stream: AsyncThrowingStream { k in
            let q = HKActivitySummaryQuery(predicate: p) { _, s, e in if let e { k.finish(throwing: e) } else { k.yield(s ?? []) } }
            q.updateHandler = { _, s, e in if let e { k.finish(throwing: e) } else { k.yield(s ?? []) } }
            k.onTermination = { _ in healthStore.stop(q) }
            healthStore.execute(q)
        })
    }
}

// MARK: - Correlations

public struct HKCorrelationTypeIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let bloodPressure = Self(rawValue: "HKCorrelationTypeIdentifierBloodPressure")
    public static let food = Self(rawValue: "HKCorrelationTypeIdentifierFood")
}
@objc(HKCorrelationType) open class HKCorrelationType: HKSampleType, @unchecked Sendable {
    public convenience init(_ identifier: HKCorrelationTypeIdentifier) { self.init(identifier.rawValue) }
    override init(_ identifier: String) { super.init(identifier) }
}
extension HKObjectType {
    public class func correlationType(forIdentifier identifier: HKCorrelationTypeIdentifier) -> HKCorrelationType? {
        [HKCorrelationTypeIdentifier.bloodPressure, .food].contains(identifier) ? HKCorrelationType(identifier) : nil
    }
    @objc(correlationTypeForIdentifier:) class func _objc_correlationType(_ id: String) -> HKCorrelationType? {
        correlationType(forIdentifier: HKCorrelationTypeIdentifier(rawValue: id))
    }
}

/// samples recorded together: a blood pressure (systolic and diastolic), a food (its nutrients)
@objc(HKCorrelation) open class HKCorrelation: HKSample, @unchecked Sendable {
    @objc open private(set) var objects: Set<HKSample>
    @objc open var correlationType: HKCorrelationType { sampleType as! HKCorrelationType }
    @objc(objectsForType:) open func objects(for objectType: HKObjectType) -> Set<HKSample> {
        objects.filter { $0.sampleType.identifier == objectType.identifier }
    }
    public convenience init(type correlationType: HKCorrelationType, start startDate: Date, end endDate: Date, objects: Set<HKSample>) {
        self.init(type: correlationType, start: startDate, end: endDate, objects: objects, metadata: nil)
    }
    public init(type correlationType: HKCorrelationType, start startDate: Date, end endDate: Date, objects: Set<HKSample>, metadata: [String: Any]?) {
        self.objects = objects
        super.init(correlationType, startDate, endDate, metadata)
    }
    public convenience init(type correlationType: HKCorrelationType, start startDate: Date, end endDate: Date, objects: Set<HKSample>, device: HKDevice?,
                            metadata: [String: Any]?) {
        self.init(type: correlationType, start: startDate, end: endDate, objects: objects, metadata: metadata)
    }
    @objc(correlationWithType:startDate:endDate:objects:metadata:)
    class func _objc_correlation(_ t: HKCorrelationType, startDate: Date, endDate: Date, objects: Set<HKSample>, metadata: [String: Any]?) -> HKCorrelation {
        HKCorrelation(type: t, start: startDate, end: endDate, objects: objects, metadata: metadata)
    }
    @objc(correlationWithType:startDate:endDate:objects:)
    class func _objc_correlation(_ t: HKCorrelationType, startDate: Date, endDate: Date, objects: Set<HKSample>) -> HKCorrelation {
        HKCorrelation(type: t, start: startDate, end: endDate, objects: objects)
    }
}

@objc(HKCorrelationQuery) open class HKCorrelationQuery: HKQuery, @unchecked Sendable {
    @objc open var correlationType: HKCorrelationType { objectType as! HKCorrelationType }
    @objc public let samplePredicates: [HKSampleType: NSPredicate]?
    let completion: (HKCorrelationQuery, [HKCorrelation]?, Error?) -> Void
    @objc(initWithType:predicate:samplePredicates:completion:)
    public init(type correlationType: HKCorrelationType, predicate: NSPredicate?, samplePredicates: [HKSampleType: NSPredicate]?,
                completion: @escaping (HKCorrelationQuery, [HKCorrelation]?, Error?) -> Void) {
        self.samplePredicates = samplePredicates; self.completion = completion
        super.init(correlationType, predicate)
    }
    /// the correlations with, for each sample predicate, at least one object of its type that matches it
    override func run() {
        var out = matching().compactMap { $0 as? HKCorrelation }
        for (t, p) in samplePredicates ?? [:] {
            out = out.filter { c in c.objects(for: t).contains { p.evaluate(with: $0) } }
        }
        completion(self, out, nil)
    }
}

extension HKSamplePredicate where Sample == HKCorrelation {
    public static func correlation(type: HKCorrelationType, predicate: NSPredicate? = nil) -> HKSamplePredicate<HKCorrelation> { .init(type, predicate) }
}

// MARK: - State of mind (iOS 18)

public let HKDataTypeStateOfMind = "HKDataTypeStateOfMind"
@available(iOS 18.0, *)
@objc(HKStateOfMindType) open class HKStateOfMindType: HKSampleType, @unchecked Sendable {}
@available(iOS 18.0, *)
extension HKObjectType {
    @objc open class func stateOfMindType() -> HKStateOfMindType { HKStateOfMindType(HKDataTypeStateOfMind) }
}

/// how someone felt: a momentary emotion or a daily mood, from very unpleasant (-1) to very pleasant (1)
@available(iOS 18.0, *)
@objc(HKStateOfMind) open class HKStateOfMind: HKSample, @unchecked Sendable {
    @objc(HKStateOfMindKind) public enum Kind: Int, Sendable { case momentaryEmotion = 1, dailyMood }
    @objc(HKStateOfMindValenceClassification) public enum ValenceClassification: Int, Sendable {
        case veryUnpleasant = 1, unpleasant, slightlyUnpleasant, neutral, slightlyPleasant, pleasant, veryPleasant
        /// adapted: the nearest of the seven points of the Health app's slider (-1, -2/3, -1/3, 0, 1/3, 2/3, 1)
        public init?(valence: Double) {
            guard (-1...1).contains(valence) else { return nil }
            self.init(rawValue: Int((valence * 3).rounded()) + 4)
        }
    }
    @objc(HKStateOfMindLabel) public enum Label: Int, Sendable {
        case amazed = 1, amused, angry, anxious, ashamed, brave, calm, content, disappointed, discouraged, disgusted, embarrassed, excited
        case frustrated, grateful, guilty, happy, hopeless, irritated, jealous, joyful, lonely, passionate, peaceful, proud, relieved, sad
        case scared, stressed, surprised, worried, annoyed, confident, drained, hopeful, indifferent, overwhelmed, satisfied
    }
    @objc(HKStateOfMindAssociation) public enum Association: Int, Sendable {
        case community = 1, currentEvents, dating, education, family, fitness, friends, health, hobbies, identity, money, partner, selfCare
        case spirituality, tasks, travel, work, weather
    }
    @objc open private(set) var kind: Kind
    @objc open private(set) var valence: Double
    @objc open var valenceClassification: ValenceClassification { ValenceClassification(valence: max(-1, min(1, valence))) ?? .neutral }
    open private(set) var labels: [Label]
    open private(set) var associations: [Association]
    public convenience init(date: Date, kind: Kind, valence: Double, labels: [Label], associations: [Association], metadata: [String: Any]? = nil) {
        self.init(date, kind, valence, labels, associations, metadata)
    }
    init(_ date: Date, _ kind: Kind, _ valence: Double, _ labels: [Label], _ associations: [Association], _ metadata: [String: Any]?) {
        self.kind = kind; self.valence = valence; self.labels = labels; self.associations = associations
        super.init(HKObjectType.stateOfMindType(), date, date, metadata)
    }
    @objc(labels) var _objc_labels: [NSNumber] { labels.map { NSNumber(value: $0.rawValue) } }
    @objc(associations) var _objc_associations: [NSNumber] { associations.map { NSNumber(value: $0.rawValue) } }
    @objc(stateOfMindWithDate:kind:valence:labels:associations:)
    class func _objc_make(_ date: Date, kind: Kind, valence: Double, labels: [NSNumber], associations: [NSNumber]) -> HKStateOfMind {
        HKStateOfMind(date, kind, valence, labels.compactMap { Label(rawValue: Int(truncating: $0)) }, associations.compactMap { Association(rawValue: Int(truncating: $0)) }, nil)
    }
}

@available(iOS 18.0, *)
extension HKQuery {
    public class func predicateForStatesOfMind(with kind: HKStateOfMind.Kind) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKStateOfMind)?.kind == kind }
    }
    public class func predicateForStatesOfMind(with label: HKStateOfMind.Label) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKStateOfMind)?.labels.contains(label) ?? false }
    }
    public class func predicateForStatesOfMind(with association: HKStateOfMind.Association) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKStateOfMind)?.associations.contains(association) ?? false }
    }
    public class func predicateForStatesOfMind(withValence valence: Double, operatorType: NSComparisonPredicate.Operator) -> NSPredicate {
        NSPredicate { o, _ in (o as? HKStateOfMind).map { _compare(operatorType, $0.valence, valence) } ?? false }
    }
    @objc(predicateForStatesOfMindWithKind:) class func _objc_predicate(_ kind: HKStateOfMind.Kind) -> NSPredicate { predicateForStatesOfMind(with: kind) }
    @objc(predicateForStatesOfMindWithLabel:) class func _objc_predicate(_ label: HKStateOfMind.Label) -> NSPredicate { predicateForStatesOfMind(with: label) }
    @objc(predicateForStatesOfMindWithAssociation:) class func _objc_predicate(_ a: HKStateOfMind.Association) -> NSPredicate { predicateForStatesOfMind(with: a) }
    @objc(predicateForStatesOfMindWithValence:operatorType:) class func _objc_predicate(_ v: Double, operatorType: NSComparisonPredicate.Operator) -> NSPredicate {
        predicateForStatesOfMind(withValence: v, operatorType: operatorType)
    }
}
@available(iOS 18.0, *)
extension HKSamplePredicate where Sample == HKStateOfMind {
    public static func stateOfMind(_ predicate: NSPredicate? = nil) -> HKSamplePredicate<HKStateOfMind> { .init(HKObjectType.stateOfMindType(), predicate) }
}

/// how a state of mind or a correlation is kept in a database record
struct _HKMindData: Codable { var kind: Int, labels: [Int], associations: [Int] }
