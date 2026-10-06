// isim HealthKit (self-authored, iOS API names): a local Health store like the Simulator's — health data is available
// on iPhone, apps ask for access with the Health Access sheet (per type: write switches and read switches), and the
// samples they save are kept in the device data ($ISIM_DATA/Library/Health/healthdb.json), shared by all apps.
// As on iOS, read permission is never revealed: a query for a type the user did not allow reading returns only the
// app's own samples. Answers are remembered per app.
// Automation: ISIM_HEALTH_PERMISSION=allow|deny answers the sheet without showing it (allow = every switch on).
import UIKit

public let HKErrorDomain = "com.apple.healthkit"
public struct HKError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case noError = 0, errorHealthDataUnavailable, errorHealthDataRestricted, errorInvalidArgument, errorAuthorizationDenied
        case errorAuthorizationNotDetermined, errorDatabaseInaccessible, errorUserCanceled, errorAnotherWorkoutSessionStarted
        case errorUserExitedWorkoutSession, errorRequiredAuthorizationDenied, errorNoData, errorWorkoutActivityNotAllowed, errorDataSizeExceeded
    }
    public let code: Code
    let message: String
    public init(_ code: Code, _ message: String = "") { self.code = code; self.message = message }
    public static var errorDomain: String { HKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
    public var errorDescription: String? { message.isEmpty ? "HealthKit error \(code.rawValue)" : message }
    public static var errorAuthorizationDenied: Code { .errorAuthorizationDenied }
    public static var errorAuthorizationNotDetermined: Code { .errorAuthorizationNotDetermined }
    public static var errorNoData: Code { .errorNoData }
    public static var errorInvalidArgument: Code { .errorInvalidArgument }
}

@objc public enum HKAuthorizationStatus: Int, Sendable { case notDetermined = 0, sharingDenied, sharingAuthorized }
@objc public enum HKAuthorizationRequestStatus: Int, Sendable { case unknown = 0, shouldRequest, unnecessary }
@objc public enum HKBiologicalSex: Int, Sendable { case notSet = 0, female, male, other }

// MARK: - Type identifiers

public struct HKQuantityTypeIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let stepCount = Self("HKQuantityTypeIdentifierStepCount")
    public static let distanceWalkingRunning = Self("HKQuantityTypeIdentifierDistanceWalkingRunning")
    public static let distanceCycling = Self("HKQuantityTypeIdentifierDistanceCycling")
    public static let activeEnergyBurned = Self("HKQuantityTypeIdentifierActiveEnergyBurned")
    public static let basalEnergyBurned = Self("HKQuantityTypeIdentifierBasalEnergyBurned")
    public static let flightsClimbed = Self("HKQuantityTypeIdentifierFlightsClimbed")
    public static let appleExerciseTime = Self("HKQuantityTypeIdentifierAppleExerciseTime")
    public static let heartRate = Self("HKQuantityTypeIdentifierHeartRate")
    public static let restingHeartRate = Self("HKQuantityTypeIdentifierRestingHeartRate")
    public static let heartRateVariabilitySDNN = Self("HKQuantityTypeIdentifierHeartRateVariabilitySDNN")
    public static let oxygenSaturation = Self("HKQuantityTypeIdentifierOxygenSaturation")
    public static let respiratoryRate = Self("HKQuantityTypeIdentifierRespiratoryRate")
    public static let bodyTemperature = Self("HKQuantityTypeIdentifierBodyTemperature")
    public static let bloodPressureSystolic = Self("HKQuantityTypeIdentifierBloodPressureSystolic")
    public static let bloodPressureDiastolic = Self("HKQuantityTypeIdentifierBloodPressureDiastolic")
    public static let bodyMass = Self("HKQuantityTypeIdentifierBodyMass")
    public static let bodyMassIndex = Self("HKQuantityTypeIdentifierBodyMassIndex")
    public static let bodyFatPercentage = Self("HKQuantityTypeIdentifierBodyFatPercentage")
    public static let height = Self("HKQuantityTypeIdentifierHeight")
    public static let leanBodyMass = Self("HKQuantityTypeIdentifierLeanBodyMass")
    public static let dietaryWater = Self("HKQuantityTypeIdentifierDietaryWater")
    public static let dietaryEnergyConsumed = Self("HKQuantityTypeIdentifierDietaryEnergyConsumed")
    public static let dietaryProtein = Self("HKQuantityTypeIdentifierDietaryProtein")
    public static let dietaryCaffeine = Self("HKQuantityTypeIdentifierDietaryCaffeine")
}
public struct HKCategoryTypeIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let sleepAnalysis = Self("HKCategoryTypeIdentifierSleepAnalysis")
    public static let mindfulSession = Self("HKCategoryTypeIdentifierMindfulSession")
    public static let appleStandHour = Self("HKCategoryTypeIdentifierAppleStandHour")
    public static let highHeartRateEvent = Self("HKCategoryTypeIdentifierHighHeartRateEvent")
}
public struct HKCharacteristicTypeIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let biologicalSex = Self(rawValue: "HKCharacteristicTypeIdentifierBiologicalSex")
    public static let dateOfBirth = Self(rawValue: "HKCharacteristicTypeIdentifierDateOfBirth")
    public static let bloodType = Self(rawValue: "HKCharacteristicTypeIdentifierBloodType")
}
public enum HKCategoryValueSleepAnalysis: Int, Sendable { case inBed = 0, asleepUnspecified = 1, awake = 2, asleepCore = 3, asleepDeep = 4, asleepREM = 5
    @available(*, deprecated, renamed: "asleepUnspecified") public static var asleep: HKCategoryValueSleepAnalysis { .asleepUnspecified } }
public enum HKCategoryValue: Int, Sendable { case notApplicable = 0 }

// MARK: - Object types

open class HKObjectType: NSObject, NSCopying, @unchecked Sendable {
    @objc public let identifier: String
    init(_ identifier: String) { self.identifier = identifier }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? HKObjectType)?.identifier == identifier }
    open override var hash: Int { identifier.hashValue }
    open override var description: String { identifier }

    open class func quantityType(forIdentifier identifier: HKQuantityTypeIdentifier) -> HKQuantityType? { HKQuantityType(identifier) }
    open class func categoryType(forIdentifier identifier: HKCategoryTypeIdentifier) -> HKCategoryType? { HKCategoryType(identifier) }
    open class func characteristicType(forIdentifier identifier: HKCharacteristicTypeIdentifier) -> HKCharacteristicType? { HKCharacteristicType(identifier.rawValue) }
    open class func workoutType() -> HKWorkoutType { HKWorkoutType("HKWorkoutTypeIdentifier") }
    open var _isimName: String { _HKNames.name(identifier) }
}
open class HKCharacteristicType: HKObjectType, @unchecked Sendable {}
open class HKSampleType: HKObjectType, @unchecked Sendable {
    open var isMinimumDurationRestricted: Bool { false }
    open var isMaximumDurationRestricted: Bool { false }
}
@objc public enum HKQuantityAggregationStyle: Int, Sendable { case cumulative = 0, discreteArithmetic, discreteTemporallyWeighted, discreteEquivalentContinuousLevel }
open class HKQuantityType: HKSampleType, @unchecked Sendable {
    public convenience init(_ identifier: HKQuantityTypeIdentifier) { self.init(identifier.rawValue as String) }
    override init(_ identifier: String) { super.init(identifier) }
    open var aggregationStyle: HKQuantityAggregationStyle { _HKUnits.cumulative.contains(identifier) ? .cumulative : .discreteArithmetic }
    open func `is`(compatibleWith unit: HKUnit) -> Bool { _HKUnits.canonical(identifier).dimension == unit.dimension }
}
open class HKCategoryType: HKSampleType, @unchecked Sendable {
    public convenience init(_ identifier: HKCategoryTypeIdentifier) { self.init(identifier.rawValue as String) }
    override init(_ identifier: String) { super.init(identifier) }
}
open class HKWorkoutType: HKSampleType, @unchecked Sendable {}

enum _HKNames {
    static func name(_ id: String) -> String {
        let n: [String: String] = [
            "HKQuantityTypeIdentifierStepCount": "Steps", "HKQuantityTypeIdentifierDistanceWalkingRunning": "Walking + Running Distance",
            "HKQuantityTypeIdentifierDistanceCycling": "Cycling Distance", "HKQuantityTypeIdentifierActiveEnergyBurned": "Active Energy",
            "HKQuantityTypeIdentifierBasalEnergyBurned": "Resting Energy", "HKQuantityTypeIdentifierFlightsClimbed": "Flights Climbed",
            "HKQuantityTypeIdentifierAppleExerciseTime": "Exercise Minutes", "HKQuantityTypeIdentifierHeartRate": "Heart Rate",
            "HKQuantityTypeIdentifierRestingHeartRate": "Resting Heart Rate", "HKQuantityTypeIdentifierHeartRateVariabilitySDNN": "Heart Rate Variability",
            "HKQuantityTypeIdentifierOxygenSaturation": "Blood Oxygen", "HKQuantityTypeIdentifierRespiratoryRate": "Respiratory Rate",
            "HKQuantityTypeIdentifierBodyTemperature": "Body Temperature", "HKQuantityTypeIdentifierBloodPressureSystolic": "Blood Pressure",
            "HKQuantityTypeIdentifierBloodPressureDiastolic": "Blood Pressure", "HKQuantityTypeIdentifierBodyMass": "Weight",
            "HKQuantityTypeIdentifierBodyMassIndex": "Body Mass Index", "HKQuantityTypeIdentifierBodyFatPercentage": "Body Fat Percentage",
            "HKQuantityTypeIdentifierHeight": "Height", "HKQuantityTypeIdentifierLeanBodyMass": "Lean Body Mass",
            "HKQuantityTypeIdentifierDietaryWater": "Water", "HKQuantityTypeIdentifierDietaryEnergyConsumed": "Dietary Energy",
            "HKQuantityTypeIdentifierDietaryProtein": "Protein", "HKQuantityTypeIdentifierDietaryCaffeine": "Caffeine",
            "HKCategoryTypeIdentifierSleepAnalysis": "Sleep", "HKCategoryTypeIdentifierMindfulSession": "Mindful Minutes",
            "HKCategoryTypeIdentifierAppleStandHour": "Stand Hours", "HKCategoryTypeIdentifierHighHeartRateEvent": "High Heart Rate Notifications",
            "HKCharacteristicTypeIdentifierBiologicalSex": "Sex", "HKCharacteristicTypeIdentifierDateOfBirth": "Date of Birth",
            "HKCharacteristicTypeIdentifierBloodType": "Blood Type", "HKWorkoutTypeIdentifier": "Workouts",
        ]
        if let s = n[id] { return s }
        return id.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "").replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
    }
}

// MARK: - Units and quantities

@objc public enum HKMetricPrefix: Int, Sendable { case none = 0, femto = 13, pico = 1, nano, micro, milli, centi, deci, deca, hecto, kilo, mega, giga, tera }

open class HKUnit: NSObject, NSCopying, @unchecked Sendable {
    public let unitString: String
    let factor: Double          // value in canonical units = value * factor
    let dimension: String
    init(_ s: String, _ f: Double, _ d: String) { unitString = s; factor = f; dimension = d }
    public convenience init(from string: String) {
        let u = _HKUnits.parse(string)
        self.init(string, u.factor, u.dimension)
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? HKUnit)?.unitString == unitString }
    open override var hash: Int { unitString.hashValue }
    open override var description: String { unitString }

    static func prefixed(_ p: HKMetricPrefix, _ base: String) -> HKUnit { HKUnit(from: _HKUnits.prefixString(p) + base) }
    open class func count() -> HKUnit { HKUnit(from: "count") }
    open class func meter() -> HKUnit { HKUnit(from: "m") }
    open class func meterUnit(with prefix: HKMetricPrefix) -> HKUnit { prefixed(prefix, "m") }
    open class func mile() -> HKUnit { HKUnit(from: "mi") }
    open class func foot() -> HKUnit { HKUnit(from: "ft") }
    open class func inch() -> HKUnit { HKUnit(from: "in") }
    open class func yard() -> HKUnit { HKUnit(from: "yd") }
    open class func gram() -> HKUnit { HKUnit(from: "g") }
    open class func gramUnit(with prefix: HKMetricPrefix) -> HKUnit { prefixed(prefix, "g") }
    open class func pound() -> HKUnit { HKUnit(from: "lb") }
    open class func ounce() -> HKUnit { HKUnit(from: "oz") }
    open class func second() -> HKUnit { HKUnit(from: "s") }
    open class func secondUnit(with prefix: HKMetricPrefix) -> HKUnit { prefixed(prefix, "s") }
    open class func minute() -> HKUnit { HKUnit(from: "min") }
    open class func hour() -> HKUnit { HKUnit(from: "hr") }
    open class func day() -> HKUnit { HKUnit(from: "d") }
    open class func liter() -> HKUnit { HKUnit(from: "L") }
    open class func literUnit(with prefix: HKMetricPrefix) -> HKUnit { prefixed(prefix, "L") }
    open class func fluidOunceUS() -> HKUnit { HKUnit(from: "fl_oz_us") }
    open class func kilocalorie() -> HKUnit { HKUnit(from: "kcal") }
    open class func largeCalorie() -> HKUnit { HKUnit(from: "Cal") }
    open class func smallCalorie() -> HKUnit { HKUnit(from: "cal") }
    open class func joule() -> HKUnit { HKUnit(from: "J") }
    open class func jouleUnit(with prefix: HKMetricPrefix) -> HKUnit { prefixed(prefix, "J") }
    open class func percent() -> HKUnit { HKUnit(from: "%") }
    open class func degreeCelsius() -> HKUnit { HKUnit(from: "degC") }
    open class func millimeterOfMercury() -> HKUnit { HKUnit(from: "mmHg") }
    open func unitDivided(by unit: HKUnit) -> HKUnit { HKUnit("\(unitString)/\(unit.unitString)", factor / unit.factor, "\(dimension)/\(unit.dimension)") }
    open func unitMultiplied(by unit: HKUnit) -> HKUnit { HKUnit("\(unitString)*\(unit.unitString)", factor * unit.factor, "\(dimension)*\(unit.dimension)") }
    open func reciprocal() -> HKUnit { HKUnit("1/\(unitString)", 1 / factor, "1/\(dimension)") }
    open func isNull() -> Bool { false }
}

enum _HKUnits {
    static let cumulative: Set<String> = ["HKQuantityTypeIdentifierStepCount", "HKQuantityTypeIdentifierDistanceWalkingRunning", "HKQuantityTypeIdentifierDistanceCycling",
        "HKQuantityTypeIdentifierActiveEnergyBurned", "HKQuantityTypeIdentifierBasalEnergyBurned", "HKQuantityTypeIdentifierFlightsClimbed",
        "HKQuantityTypeIdentifierAppleExerciseTime", "HKQuantityTypeIdentifierDietaryWater", "HKQuantityTypeIdentifierDietaryEnergyConsumed",
        "HKQuantityTypeIdentifierDietaryProtein", "HKQuantityTypeIdentifierDietaryCaffeine"]
    static func prefixString(_ p: HKMetricPrefix) -> String {
        switch p {
        case .none: return ""; case .femto: return "f"; case .pico: return "p"; case .nano: return "n"; case .micro: return "mc"; case .milli: return "m"
        case .centi: return "c"; case .deci: return "d"; case .deca: return "da"; case .hecto: return "h"; case .kilo: return "k"
        case .mega: return "M"; case .giga: return "G"; case .tera: return "T"
        }
    }
    static let bases: [String: (Double, String)] = [
        "count": (1, "count"), "m": (1, "length"), "mi": (1609.344, "length"), "ft": (0.3048, "length"), "in": (0.0254, "length"), "yd": (0.9144, "length"),
        "g": (1, "mass"), "lb": (453.59237, "mass"), "oz": (28.349523125, "mass"), "s": (1, "time"), "min": (60, "time"), "hr": (3600, "time"), "d": (86400, "time"),
        "L": (1, "volume"), "fl_oz_us": (0.0295735295625, "volume"), "cal": (0.001, "energy"), "kcal": (1, "energy"), "Cal": (1, "energy"), "J": (0.000239005736, "energy"),
        "%": (0.01, "scalar"), "degC": (1, "temperature"), "mmHg": (1, "pressure"),
    ]
    static let prefixes: [(String, Double)] = [("da", 10), ("mc", 1e-6), ("f", 1e-15), ("p", 1e-12), ("n", 1e-9), ("m", 1e-3), ("c", 1e-2), ("d", 1e-1),
                                               ("h", 100), ("k", 1000), ("M", 1e6), ("G", 1e9), ("T", 1e12)]
    static func base(_ s: String) -> (factor: Double, dimension: String) {
        if let b = bases[s] { return b }
        for (p, f) in prefixes where s.hasPrefix(p) { if let b = bases[String(s.dropFirst(p.count))] { return (f * b.0, b.1) } }
        return (1, s)
    }
    static func parse(_ s: String) -> (factor: Double, dimension: String) {
        let parts = s.split(separator: "/", maxSplits: 1).map(String.init)
        func product(_ p: String) -> (Double, String) {
            p.split(separator: "*").map { base(String($0)) }.reduce((1.0, "")) { ($0.0 * $1.factor, $0.1.isEmpty ? $1.dimension : $0.1 + "*" + $1.dimension) }
        }
        let num = product(parts[0])
        if parts.count == 2 { let den = product(parts[1]); return (num.0 / den.0, num.1 + "/" + den.1) }
        return num
    }
    /// the unit samples of a type are stored in
    static func canonical(_ id: String) -> HKUnit {
        switch id {
        case "HKQuantityTypeIdentifierDistanceWalkingRunning", "HKQuantityTypeIdentifierDistanceCycling", "HKQuantityTypeIdentifierHeight": return .meter()
        case "HKQuantityTypeIdentifierActiveEnergyBurned", "HKQuantityTypeIdentifierBasalEnergyBurned", "HKQuantityTypeIdentifierDietaryEnergyConsumed": return .kilocalorie()
        case "HKQuantityTypeIdentifierHeartRate", "HKQuantityTypeIdentifierRestingHeartRate", "HKQuantityTypeIdentifierRespiratoryRate": return HKUnit(from: "count/min")
        case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN": return HKUnit(from: "ms")
        case "HKQuantityTypeIdentifierBodyMass", "HKQuantityTypeIdentifierLeanBodyMass": return .gramUnit(with: .kilo)
        case "HKQuantityTypeIdentifierDietaryProtein", "HKQuantityTypeIdentifierDietaryCaffeine": return .gram()
        case "HKQuantityTypeIdentifierDietaryWater": return .liter()
        case "HKQuantityTypeIdentifierAppleExerciseTime": return .minute()
        case "HKQuantityTypeIdentifierOxygenSaturation", "HKQuantityTypeIdentifierBodyFatPercentage": return .percent()
        case "HKQuantityTypeIdentifierBodyTemperature": return .degreeCelsius()
        case "HKQuantityTypeIdentifierBloodPressureSystolic", "HKQuantityTypeIdentifierBloodPressureDiastolic": return .millimeterOfMercury()
        default: return .count()
        }
    }
}

open class HKQuantity: NSObject, NSCopying, @unchecked Sendable {
    let canonicalValue: Double      // value * unit.factor
    let dimension: String
    let unit: HKUnit
    public init(unit: HKUnit, doubleValue value: Double) { self.unit = unit; canonicalValue = value * unit.factor; dimension = unit.dimension }
    open func `is`(compatibleWith unit: HKUnit) -> Bool { unit.dimension == dimension }
    open func doubleValue(for unit: HKUnit) -> Double {
        if unit.dimension != dimension { NSLog("isim HealthKit: incompatible unit %@ for a quantity in %@ (iOS raises an exception)", unit.unitString, self.unit.unitString) }
        return canonicalValue / unit.factor
    }
    open func compare(_ quantity: HKQuantity) -> ComparisonResult {
        canonicalValue < quantity.canonicalValue ? .orderedAscending : canonicalValue > quantity.canonicalValue ? .orderedDescending : .orderedSame
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override var description: String { "\(canonicalValue / unit.factor) \(unit.unitString)" }
}

// MARK: - Objects and samples

open class HKSource: NSObject, @unchecked Sendable {
    @objc public let name: String
    @objc public let bundleIdentifier: String
    init(name: String, bundleIdentifier: String) { self.name = name; self.bundleIdentifier = bundleIdentifier }
    open class func `default`() -> HKSource { HKSource(name: _Privacy.appName, bundleIdentifier: _Privacy.bundleID) }
    open override func isEqual(_ object: Any?) -> Bool { (object as? HKSource)?.bundleIdentifier == bundleIdentifier }
    open override var hash: Int { bundleIdentifier.hashValue }
}
open class HKSourceRevision: NSObject, @unchecked Sendable {
    @objc public let source: HKSource
    public let version: String?
    public init(source: HKSource, version: String?) { self.source = source; self.version = version }
}
open class HKDevice: NSObject, @unchecked Sendable {
    open class func local() -> HKDevice { HKDevice() }
    open var name: String? { "iPhone" }
    open var manufacturer: String? { "Apple Inc." }
    open var model: String? { "iPhone" }
}

open class HKObject: NSObject, @unchecked Sendable {
    @objc open internal(set) var uuid: UUID = UUID()
    @objc open internal(set) var metadata: [String: Any]?
    @objc open internal(set) var sourceRevision: HKSourceRevision = HKSourceRevision(source: .default(), version: nil)
    open var device: HKDevice? { nil }
    @available(*, deprecated) open var source: HKSource { sourceRevision.source }
}
open class HKSample: HKObject, @unchecked Sendable {
    @objc open internal(set) var sampleType: HKSampleType
    @objc open internal(set) var startDate: Date
    @objc open internal(set) var endDate: Date
    open var hasUndeterminedDuration: Bool { false }
    init(_ type: HKSampleType, _ start: Date, _ end: Date, _ metadata: [String: Any]?) {
        sampleType = type; startDate = start; endDate = end
        super.init()
        self.metadata = metadata
    }
}
open class HKQuantitySample: HKSample, @unchecked Sendable {
    @objc open internal(set) var quantity: HKQuantity
    open var quantityType: HKQuantityType { sampleType as! HKQuantityType }
    open var count: Int { 1 }
    public init(type quantityType: HKQuantityType, quantity: HKQuantity, start startDate: Date, end endDate: Date) {
        self.quantity = quantity
        super.init(quantityType, startDate, endDate, nil)
    }
    public init(type quantityType: HKQuantityType, quantity: HKQuantity, start startDate: Date, end endDate: Date, metadata: [String: Any]?) {
        self.quantity = quantity
        super.init(quantityType, startDate, endDate, metadata)
    }
    public convenience init(type quantityType: HKQuantityType, quantity: HKQuantity, start startDate: Date, end endDate: Date, device: HKDevice?, metadata: [String: Any]?) {
        self.init(type: quantityType, quantity: quantity, start: startDate, end: endDate, metadata: metadata)
    }
}
open class HKCategorySample: HKSample, @unchecked Sendable {
    @objc open internal(set) var value: Int
    open var categoryType: HKCategoryType { sampleType as! HKCategoryType }
    public init(type: HKCategoryType, value: Int, start startDate: Date, end endDate: Date) {
        self.value = value
        super.init(type, startDate, endDate, nil)
    }
    public init(type: HKCategoryType, value: Int, start startDate: Date, end endDate: Date, metadata: [String: Any]?) {
        self.value = value
        super.init(type, startDate, endDate, metadata)
    }
}

public let HKSampleSortIdentifierStartDate = "startDate"
public let HKSampleSortIdentifierEndDate = "endDate"
public let HKMetadataKeyWasUserEntered = "HKWasUserEntered"
public let HKMetadataKeyExternalUUID = "HKExternalUUID"
public let HKObjectQueryNoLimit = 0
