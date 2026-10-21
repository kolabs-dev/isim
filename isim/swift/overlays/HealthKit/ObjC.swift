// isim HealthKit for Objective-C (sdk-src/Frameworks/HealthKit): the classes carry Apple's Objective-C names and these
// members Apple's selectors; type identifiers cross as strings, option sets as their raw values. Not from Objective-C
// yet: HKStatisticsCollectionQuery and dateOfBirthComponents (isim's Foundation has no NSDateComponents).
import Foundation

extension HKObjectType {
    @objc(quantityTypeForIdentifier:) class func _objc_quantityType(_ id: String) -> HKQuantityType? { quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id)) }
    @objc(categoryTypeForIdentifier:) class func _objc_categoryType(_ id: String) -> HKCategoryType? { categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: id)) }
    @objc(characteristicTypeForIdentifier:) class func _objc_characteristicType(_ id: String) -> HKCharacteristicType? {
        characteristicType(forIdentifier: HKCharacteristicTypeIdentifier(rawValue: id))
    }
    @objc(workoutType) class func _objc_workoutType() -> HKWorkoutType { workoutType() }
}
extension HKSampleType {
    @objc(isMinimumDurationRestricted) var _objc_minRestricted: Bool { isMinimumDurationRestricted }
    @objc(isMaximumDurationRestricted) var _objc_maxRestricted: Bool { isMaximumDurationRestricted }
}
extension HKQuantityType {
    @objc(aggregationStyle) var _objc_aggregationStyle: HKQuantityAggregationStyle { aggregationStyle }
    @objc(isCompatibleWithUnit:) func _objc_compatible(_ u: HKUnit) -> Bool { self.is(compatibleWith: u) }
}
extension HKUnit {
    @objc(unitFromString:) class func _objc_fromString(_ s: String) -> HKUnit { HKUnit(from: s) }
    @objc(unitString) var _objc_unitString: String { unitString }
    @objc(countUnit) class func _objc_count() -> HKUnit { count() }
    @objc(meterUnit) class func _objc_meter() -> HKUnit { meter() }
    @objc(meterUnitWithMetricPrefix:) class func _objc_meter(_ p: HKMetricPrefix) -> HKUnit { meterUnit(with: p) }
    @objc(mileUnit) class func _objc_mile() -> HKUnit { mile() }
    @objc(footUnit) class func _objc_foot() -> HKUnit { foot() }
    @objc(inchUnit) class func _objc_inch() -> HKUnit { inch() }
    @objc(yardUnit) class func _objc_yard() -> HKUnit { yard() }
    @objc(gramUnit) class func _objc_gram() -> HKUnit { gram() }
    @objc(gramUnitWithMetricPrefix:) class func _objc_gram(_ p: HKMetricPrefix) -> HKUnit { gramUnit(with: p) }
    @objc(poundUnit) class func _objc_pound() -> HKUnit { pound() }
    @objc(ounceUnit) class func _objc_ounce() -> HKUnit { ounce() }
    @objc(secondUnit) class func _objc_second() -> HKUnit { second() }
    @objc(secondUnitWithMetricPrefix:) class func _objc_second(_ p: HKMetricPrefix) -> HKUnit { secondUnit(with: p) }
    @objc(minuteUnit) class func _objc_minute() -> HKUnit { minute() }
    @objc(hourUnit) class func _objc_hour() -> HKUnit { hour() }
    @objc(dayUnit) class func _objc_day() -> HKUnit { day() }
    @objc(literUnit) class func _objc_liter() -> HKUnit { liter() }
    @objc(literUnitWithMetricPrefix:) class func _objc_liter(_ p: HKMetricPrefix) -> HKUnit { literUnit(with: p) }
    @objc(fluidOunceUSUnit) class func _objc_flozUS() -> HKUnit { fluidOunceUS() }
    @objc(kilocalorieUnit) class func _objc_kcal() -> HKUnit { kilocalorie() }
    @objc(largeCalorieUnit) class func _objc_largeCal() -> HKUnit { largeCalorie() }
    @objc(smallCalorieUnit) class func _objc_smallCal() -> HKUnit { smallCalorie() }
    @objc(jouleUnit) class func _objc_joule() -> HKUnit { joule() }
    @objc(jouleUnitWithMetricPrefix:) class func _objc_joule(_ p: HKMetricPrefix) -> HKUnit { jouleUnit(with: p) }
    @objc(percentUnit) class func _objc_percent() -> HKUnit { percent() }
    @objc(degreeCelsiusUnit) class func _objc_celsius() -> HKUnit { degreeCelsius() }
    @objc(millimeterOfMercuryUnit) class func _objc_mmHg() -> HKUnit { millimeterOfMercury() }
    @objc(unitDividedByUnit:) func _objc_divided(_ u: HKUnit) -> HKUnit { unitDivided(by: u) }
    @objc(unitMultipliedByUnit:) func _objc_multiplied(_ u: HKUnit) -> HKUnit { unitMultiplied(by: u) }
    @objc(reciprocalUnit) func _objc_reciprocal() -> HKUnit { reciprocal() }
    @objc(isNull) func _objc_isNull() -> Bool { isNull() }
}
extension HKQuantity {
    @objc(quantityWithUnit:doubleValue:) class func _objc_quantity(_ u: HKUnit, value: Double) -> HKQuantity { HKQuantity(unit: u, doubleValue: value) }
    @objc(isCompatibleWithUnit:) func _objc_compatible(_ u: HKUnit) -> Bool { self.is(compatibleWith: u) }
    @objc(doubleValueForUnit:) func _objc_doubleValue(_ u: HKUnit) -> Double { doubleValue(for: u) }
    @objc(compare:) func _objc_compare(_ q: HKQuantity) -> ComparisonResult { compare(q) }
}
extension HKSource {
    @objc(defaultSource) class func _objc_default() -> HKSource { .default() }
}
extension HKSourceRevision {
    @objc(initWithSource:version:) convenience init(_objcSource s: HKSource, version: String?) { self.init(source: s, version: version) }
    @objc(version) var _objc_version: String? { version }
}
extension HKDevice {
    @objc(localDevice) class func _objc_local() -> HKDevice { local() }
    @objc(name) var _objc_name: String? { name }
    @objc(manufacturer) var _objc_manufacturer: String? { manufacturer }
    @objc(model) var _objc_model: String? { model }
}
extension HKObject {
    @objc(UUID) var _objc_UUID: UUID { uuid }
    @objc(device) var _objc_device: HKDevice? { device }
}
extension HKSample {
    @objc(hasUndeterminedDuration) var _objc_undetermined: Bool { hasUndeterminedDuration }
}
extension HKQuantitySample {
    @objc(quantitySampleWithType:quantity:startDate:endDate:)
    class func _objc_sample(_ t: HKQuantityType, quantity: HKQuantity, start: Date, end: Date) -> HKQuantitySample {
        HKQuantitySample(type: t, quantity: quantity, start: start, end: end)
    }
    @objc(quantitySampleWithType:quantity:startDate:endDate:metadata:)
    class func _objc_sample(_ t: HKQuantityType, quantity: HKQuantity, start: Date, end: Date, metadata: [String: Any]?) -> HKQuantitySample {
        HKQuantitySample(type: t, quantity: quantity, start: start, end: end, metadata: metadata)
    }
    @objc(quantityType) var _objc_quantityType: HKQuantityType { quantityType }
    @objc(count) var _objc_count: Int { count }
}
extension HKCategorySample {
    @objc(categorySampleWithType:value:startDate:endDate:)
    class func _objc_sample(_ t: HKCategoryType, value: Int, start: Date, end: Date) -> HKCategorySample {
        HKCategorySample(type: t, value: value, start: start, end: end)
    }
    @objc(categorySampleWithType:value:startDate:endDate:metadata:)
    class func _objc_sample(_ t: HKCategoryType, value: Int, start: Date, end: Date, metadata: [String: Any]?) -> HKCategorySample {
        HKCategorySample(type: t, value: value, start: start, end: end, metadata: metadata)
    }
    @objc(categoryType) var _objc_categoryType: HKCategoryType { categoryType }
}
extension HKBiologicalSexObject {
    @objc(biologicalSex) var _objc_biologicalSex: HKBiologicalSex { biologicalSex }
}
extension HKHealthStore {
    @objc(isHealthDataAvailable) class func _objc_available() -> Bool { isHealthDataAvailable() }
    @objc(supportsHealthRecords) func _objc_supportsHealthRecords() -> Bool { supportsHealthRecords() }
    @objc(authorizationStatusForType:) func _objc_status(_ t: HKObjectType) -> HKAuthorizationStatus { authorizationStatus(for: t) }
    @objc(requestAuthorizationToShareTypes:readTypes:completion:)
    func _objc_request(_ share: Set<HKSampleType>?, read: Set<HKObjectType>?, completion: @escaping (Bool, NSError?) -> Void) {
        requestAuthorization(toShare: share, read: read) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(getRequestStatusForAuthorizationToShareTypes:readTypes:completion:)
    func _objc_requestStatus(_ share: Set<HKSampleType>, read: Set<HKObjectType>, completion: @escaping (HKAuthorizationRequestStatus, NSError?) -> Void) {
        getRequestStatusForAuthorization(toShare: share, read: read) { s, e in completion(s, e.map { $0 as NSError }) }
    }
    @objc(saveObject:withCompletion:) func _objc_save(_ o: HKObject, completion: @escaping (Bool, NSError?) -> Void) {
        save(o) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(saveObjects:withCompletion:) func _objc_save(_ o: [HKObject], completion: @escaping (Bool, NSError?) -> Void) {
        save(o) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(deleteObject:withCompletion:) func _objc_delete(_ o: HKObject, completion: @escaping (Bool, NSError?) -> Void) {
        delete(o) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(deleteObjects:withCompletion:) func _objc_delete(_ o: [HKObject], completion: @escaping (Bool, NSError?) -> Void) {
        delete(o) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(biologicalSexWithError:) func _objc_biologicalSex() throws -> HKBiologicalSexObject { try biologicalSex() }
    @objc(executeQuery:) func _objc_execute(_ q: HKQuery) { execute(q) }
    @objc(stopQuery:) func _objc_stop(_ q: HKQuery) { stop(q) }
}
extension HKQuery {
    @objc(objectType) var _objc_objectType: HKObjectType? { objectType }
    @objc(sampleType) var _objc_sampleType: HKSampleType? { sampleType }
    @objc(predicate) var _objc_predicate: NSPredicate? { predicate }
    @objc(predicateForSamplesWithStartDate:endDate:options:)
    class func _objc_predicate(_ start: Date?, end: Date?, options: UInt) -> NSPredicate {
        predicateForSamples(withStart: start, end: end, options: QueryOptions(rawValue: options))
    }
    @objc(predicateForObjectsFromSource:) class func _objc_predicate(_ s: HKSource) -> NSPredicate { predicateForObjects(from: s) }
    @objc(predicateForObjectsFromSources:) class func _objc_predicate(_ s: Set<HKSource>) -> NSPredicate { predicateForObjects(from: s) }
    @objc(predicateForObjectWithUUID:) class func _objc_predicate(_ u: UUID) -> NSPredicate { predicateForObject(with: u) }
    @objc(predicateForObjectsWithUUIDs:) class func _objc_predicate(_ u: Set<UUID>) -> NSPredicate { predicateForObjects(with: u) }
    @objc(predicateForObjectsWithMetadataKey:) class func _objc_predicate(_ k: String) -> NSPredicate { predicateForObjects(withMetadataKey: k) }
}
extension HKSampleQuery {
    @objc(initWithSampleType:predicate:limit:sortDescriptors:resultsHandler:)
    convenience init(_objcType t: HKSampleType, predicate: NSPredicate?, limit: Int, sortDescriptors: [NSSortDescriptor]?,
                     resultsHandler: @escaping (HKSampleQuery, [HKSample]?, NSError?) -> Void) {
        self.init(sampleType: t, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { q, s, e in resultsHandler(q, s, e.map { $0 as NSError }) }
    }
    @objc(limit) var _objc_limit: Int { limit }
    @objc(sortDescriptors) var _objc_sortDescriptors: [NSSortDescriptor]? { sortDescriptors }
}
extension HKStatistics {
    @objc(quantityType) var _objc_quantityType: HKQuantityType { quantityType }
    @objc(startDate) var _objc_startDate: Date { startDate }
    @objc(endDate) var _objc_endDate: Date { endDate }
    @objc(sources) var _objc_sources: [HKSource]? { sources }
    @objc(sumQuantity) func _objc_sum() -> HKQuantity? { sumQuantity() }
    @objc(averageQuantity) func _objc_average() -> HKQuantity? { averageQuantity() }
    @objc(minimumQuantity) func _objc_minimum() -> HKQuantity? { minimumQuantity() }
    @objc(maximumQuantity) func _objc_maximum() -> HKQuantity? { maximumQuantity() }
    @objc(mostRecentQuantity) func _objc_mostRecent() -> HKQuantity? { mostRecentQuantity() }
    @objc(sumQuantityForSource:) func _objc_sum(_ s: HKSource) -> HKQuantity? { sumQuantity(for: s) }
}
extension HKStatisticsQuery {
    @objc(initWithQuantityType:quantitySamplePredicate:options:completionHandler:)
    convenience init(_objcType t: HKQuantityType, quantitySamplePredicate: NSPredicate?, options: UInt,
                     completionHandler: @escaping (HKStatisticsQuery, HKStatistics?, NSError?) -> Void) {
        self.init(quantityType: t, quantitySamplePredicate: quantitySamplePredicate, options: HKStatisticsOptions(rawValue: options)) { q, s, e in
            completionHandler(q, s, e.map { $0 as NSError })
        }
    }
}
extension HKStatisticsCollection {
    @objc(statistics) func _objc_statistics() -> [HKStatistics] { statistics() }
    @objc(statisticsForDate:) func _objc_statistics(_ d: Date) -> HKStatistics? { statistics(for: d) }
    @objc(sources) func _objc_sources() -> Set<HKSource> { sources() }
}
extension HKObserverQuery {
    @objc(initWithSampleType:predicate:updateHandler:)
    convenience init(_objcType t: HKSampleType, predicate: NSPredicate?, updateHandler: @escaping (HKObserverQuery, @escaping () -> Void, NSError?) -> Void) {
        self.init(sampleType: t, predicate: predicate) { q, done, e in updateHandler(q, done, e.map { $0 as NSError }) }
    }
}
