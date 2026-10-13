// isim MetricKit (adapted): isim measures the app's own process the way iOS measures an app, from the moment the app
// first calls MXMetricManager.shared:
//   - CPU time, peak and suspended memory, logical disk writes, time to first draw and resume time, hangs (the main
//     thread away from its event loop for 250 ms or more), foreground / background time (and background audio /
//     location time), network transfer (URLSession and WebSocket bytes, counted as Wi-Fi: isim has no cellular radio),
//     location activity by desired accuracy, animation hitches, the screen's average pixel luminance, exits (from
//     crash reports and clean terminations), and signposts made with MXMetricManager.makeLogHandle / mxSignpost.
//   - GPU time is 0 (isim draws on the CPU), instructions are not counted, cellular conditions are nil.
// Delivery (iOS: metrics at most once a day, diagnostics immediately):
//   - metrics: each run's measurements are saved in the app's container; the next launch delivers them (a payload
//     per run) to subscribers, standing in for iOS's daily report. The `metrickit deliver` script command or
//     `isim metrickit deliver` delivers what has been measured so far in this run, now.
//   - diagnostics, as soon as they happen: hangs (MXHangDiagnostic with the main thread's sampled stack), a slow
//     launch (first draw after 2 s: MXAppLaunchDiagnostic), a CPU exception (80 % of a core over 3 minutes), heavy
//     disk writes (1 GiB in a run); crashes (MXCrashDiagnostic from the crash report isim wrote) on the next launch.
//   - `metrickit` / `isim metrickit` without `deliver` is Xcode's Debug > Simulate MetricKit Payloads: one fixed
//     sample metric payload and one sample diagnostic payload (sample data, not measurements; not kept in the past
//     payloads).
// pastPayloads / pastDiagnosticPayloads: the payloads generated since MXMetricManager.shared was first used in this
// process (Apple: "since the last allocation of the shared manager instance").
import Foundation
import os
import isim_host

// MARK: - Base

open class MXMetric: NSObject {
    /// the metric as Apple-style JSON (keys and "value unit" strings)
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] { [:] }
    @available(*, deprecated, renamed: "dictionaryRepresentation()")
    open func DictionaryRepresentation() -> [AnyHashable: Any] { dictionaryRepresentation() }
}

/// signal bars (cellular condition histograms)
public final class MXUnitSignalBars: Dimension, @unchecked Sendable {
    public static let bars = MXUnitSignalBars(symbol: "bars", converter: UnitConverterLinear(coefficient: 1))
    public override class func baseUnit() -> MXUnitSignalBars { bars }
}
/// average pixel luminance, 0 (black) to 100 (white)
public final class MXUnitAveragePixelLuminance: Dimension, @unchecked Sendable {
    public static let apl = MXUnitAveragePixelLuminance(symbol: "apl", converter: UnitConverterLinear(coefficient: 1))
    public override class func baseUnit() -> MXUnitAveragePixelLuminance { apl }
}

enum _MX {
    static func json(_ d: [AnyHashable: Any]) -> Data {
        let obj = (d as NSDictionary)
        return (try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
    }
    static func m<U: Unit>(_ v: Measurement<U>) -> String {
        let n = v.value == v.value.rounded() && abs(v.value) < 1e15 ? String(Int(v.value)) : String(format: "%.3f", v.value)
        return "\(n) \(v.unit.symbol)"
    }
    static func date(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1.0"
    }
    static var buildVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
    static var osVersion: String { ProcessInfo.processInfo.environment["ISIM_OS_VERSION"].flatMap { $0.isEmpty ? nil : $0 } ?? "18.0" }
    static var device: String { ProcessInfo.processInfo.environment["ISIM_DEVICE"].flatMap { $0.isEmpty ? nil : $0 } ?? "iphone16pro" }
    static let ms = UnitDuration.milliseconds, s = UnitDuration.seconds, kb = UnitInformationStorage.kilobytes
}

// MARK: - Data (what a payload holds; saved between runs as JSON)

struct _MXBucket: Codable { var start: Double; var end: Double; var count: Int }
struct _MXMeta: Codable {
    var region = Locale.current.regionCode ?? "US"
    var os = "iOS \(_MX.osVersion) (isim)", device = _MX.device, build = _MX.buildVersion, arch = "x86_64"
    var lowPower = false, testFlight = false
    var pid = ProcessInfo.processInfo.processIdentifier
    var bundle = Bundle.main.bundleIdentifier ?? "unknown"
}
struct _MXSignpostData: Codable {
    var name: String, category: String, count: Int
    var durations: [_MXBucket]
    var cpuMs: Double?, memKB: Double?, writesKB: Double?, hitchRatio: Double?
}
struct _MXPayloadData: Codable {
    var begin: Double, end: Double
    var appVersion = _MX.appVersion, multipleVersions = false
    var cpuS = 0.0, instructionsK = 0.0, gpuS = 0.0
    var peakKB = 0.0, suspendedKB = 0.0, suspendedN = 0, suspendedSD = 0.0
    var launch: [_MXBucket] = [], resume: [_MXBucket] = [], optimizedLaunch: [_MXBucket] = [], extendedLaunch: [_MXBucket] = []
    var hangs: [_MXBucket] = []
    var fg = 0.0, bg = 0.0, bgAudio = 0.0, bgLocation = 0.0
    var writesKB = 0.0
    var wifiUpKB = 0.0, wifiDownKB = 0.0, cellUpKB = 0.0, cellDownKB = 0.0
    var exitsFG: [String: Int] = [:], exitsBG: [String: Int] = [:]
    var cellular: [_MXBucket]? = nil
    var location = [Double](repeating: 0, count: 6)       // best for navigation, best, 10 m, 100 m, 1 km, 3 km
    var hitchRatio = 0.0                                    // ms per s
    var apl: Double? = nil, aplN = 0
    var signposts: [_MXSignpostData] = []
    var meta = _MXMeta()

    /// histogram buckets from values: `width` wide, starting at multiples of it
    static func buckets(_ values: [Double], width: Double) -> [_MXBucket] {
        var counts: [Double: Int] = [:]
        for v in values { counts[(v / width).rounded(.down) * width, default: 0] += 1 }
        return counts.keys.sorted().map { _MXBucket(start: $0, end: $0 + width, count: counts[$0]!) }
    }

    /// Xcode's Simulate MetricKit Payloads: fixed sample values
    static func sample(end: Date) -> _MXPayloadData {
        var p = _MXPayloadData(begin: end.timeIntervalSince1970 - 86400, end: end.timeIntervalSince1970)
        p.cpuS = 100; p.instructionsK = 100; p.gpuS = 20; p.peakKB = 200000; p.suspendedKB = 100000; p.suspendedN = 500
        p.launch = [_MXBucket(start: 1000, end: 1010, count: 50), _MXBucket(start: 2000, end: 2010, count: 60), _MXBucket(start: 3000, end: 3010, count: 30)]
        p.resume = [_MXBucket(start: 200, end: 210, count: 60), _MXBucket(start: 300, end: 310, count: 70)]
        p.optimizedLaunch = [_MXBucket(start: 1000, end: 1010, count: 50)]
        p.extendedLaunch = [_MXBucket(start: 1500, end: 1510, count: 20)]
        p.hangs = [_MXBucket(start: 0, end: 100, count: 50), _MXBucket(start: 100, end: 400, count: 60)]
        p.fg = 700; p.bg = 40; p.bgAudio = 30; p.bgLocation = 30; p.writesKB = 1300
        p.wifiUpKB = 100000; p.wifiDownKB = 100000; p.cellUpKB = 60000; p.cellDownKB = 60000
        let one = ["normal": 1, "memoryLimit": 1, "badAccess": 1, "abnormal": 1, "illegalInstruction": 1, "watchdog": 1]
        p.exitsFG = one
        p.exitsBG = one.merging(["cpuLimit": 1, "memoryPressure": 1, "lockedFile": 1, "taskTimeout": 1]) { a, _ in a }
        p.cellular = [_MXBucket(start: 1, end: 1, count: 20), _MXBucket(start: 2, end: 2, count: 30), _MXBucket(start: 3, end: 3, count: 50)]
        p.location = [20, 20, 20, 20, 20, 20]; p.hitchRatio = 1
        p.signposts = [_MXSignpostData(name: "TestSignpostName1", category: "TestSignpostCategory1", count: 30,
                                       durations: [_MXBucket(start: 0, end: 100, count: 50)], cpuMs: 100, memKB: 100000, writesKB: 600, hitchRatio: nil)]
        return p
    }
}

// MARK: - Statistics

open class MXHistogramBucket<UnitType: Unit>: NSObject {
    public let bucketStart: Measurement<UnitType>
    public let bucketEnd: Measurement<UnitType>
    public let bucketCount: Int
    init(_ start: Measurement<UnitType>, _ end: Measurement<UnitType>, _ count: Int) { bucketStart = start; bucketEnd = end; bucketCount = count }
}

open class MXHistogram<UnitType: Unit>: NSObject {
    let buckets: [MXHistogramBucket<UnitType>]
    init(_ b: [MXHistogramBucket<UnitType>]) { buckets = b }
    init(_ data: [_MXBucket], _ unit: UnitType) {
        buckets = data.map { MXHistogramBucket(Measurement(value: $0.start, unit: unit), Measurement(value: $0.end, unit: unit), $0.count) }
    }
    public var totalBucketCount: Int { buckets.count }
    public var bucketEnumerator: NSEnumerator { (buckets as NSArray).objectEnumerator() }
    var dictionary: [AnyHashable: Any] {
        var d: [String: Any] = [:]
        for (i, b) in buckets.enumerated() {
            d["\(i)"] = ["bucketStart": _MX.m(b.bucketStart), "bucketEnd": _MX.m(b.bucketEnd), "bucketCount": b.bucketCount]
        }
        return ["histogramNumBuckets": buckets.count, "histogramValue": d]
    }
}

open class MXAverage<UnitType: Unit>: NSObject {
    public let averageMeasurement: Measurement<UnitType>
    public let sampleCount: Int
    public let standardDeviation: Double
    init(_ m: Measurement<UnitType>, _ n: Int, _ sd: Double) { averageMeasurement = m; sampleCount = n; standardDeviation = sd }
    var dictionary: [AnyHashable: Any] { ["averageValue": _MX.m(averageMeasurement), "sampleCount": sampleCount, "standardDeviation": standardDeviation] }
}

// MARK: - Metrics

open class MXCPUMetric: MXMetric {
    public let cumulativeCPUTime: Measurement<UnitDuration>
    public let cumulativeCPUInstructions: Measurement<Unit>
    init(_ d: _MXPayloadData) {
        cumulativeCPUTime = Measurement(value: d.cpuS, unit: _MX.s)
        cumulativeCPUInstructions = Measurement(value: d.instructionsK, unit: Unit(symbol: "kiloinstructions"))
    }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeCPUTime": _MX.m(cumulativeCPUTime), "cumulativeCPUInstructions": _MX.m(cumulativeCPUInstructions)]
    }
}
open class MXGPUMetric: MXMetric {
    public let cumulativeGPUTime: Measurement<UnitDuration>
    init(_ d: _MXPayloadData) { cumulativeGPUTime = Measurement(value: d.gpuS, unit: _MX.s) }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["cumulativeGPUTime": _MX.m(cumulativeGPUTime)] }
}
open class MXMemoryMetric: MXMetric {
    public let peakMemoryUsage: Measurement<UnitInformationStorage>
    public let averageSuspendedMemory: MXAverage<UnitInformationStorage>
    init(_ d: _MXPayloadData) {
        peakMemoryUsage = Measurement(value: d.peakKB, unit: _MX.kb)
        averageSuspendedMemory = MXAverage(Measurement(value: d.suspendedKB, unit: _MX.kb), d.suspendedN, d.suspendedSD)
    }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["peakMemoryUsage": _MX.m(peakMemoryUsage), "averageSuspendedMemory": averageSuspendedMemory.dictionary]
    }
}
open class MXAppLaunchMetric: MXMetric {
    public let histogrammedTimeToFirstDraw: MXHistogram<UnitDuration>
    public let histogrammedApplicationResumeTime: MXHistogram<UnitDuration>
    public let histogrammedOptimizedTimeToFirstDraw: MXHistogram<UnitDuration>
    public let histogrammedExtendedLaunch: MXHistogram<UnitDuration>
    init(_ d: _MXPayloadData) {
        histogrammedTimeToFirstDraw = MXHistogram(d.launch, _MX.ms)
        histogrammedApplicationResumeTime = MXHistogram(d.resume, _MX.ms)
        histogrammedOptimizedTimeToFirstDraw = MXHistogram(d.optimizedLaunch, _MX.ms)
        histogrammedExtendedLaunch = MXHistogram(d.extendedLaunch, _MX.ms)
    }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["histogrammedTimeToFirstDrawKey": histogrammedTimeToFirstDraw.dictionary, "histogrammedResumeTime": histogrammedApplicationResumeTime.dictionary,
         "histogrammedOptimizedTimeToFirstDrawKey": histogrammedOptimizedTimeToFirstDraw.dictionary, "histogrammedExtendedLaunch": histogrammedExtendedLaunch.dictionary]
    }
}
open class MXAppResponsivenessMetric: MXMetric {
    public let histogrammedApplicationHangTime: MXHistogram<UnitDuration>
    init(_ d: _MXPayloadData) { histogrammedApplicationHangTime = MXHistogram(d.hangs, _MX.s) }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["histogrammedAppHangTime": histogrammedApplicationHangTime.dictionary] }
}
open class MXAppRunTimeMetric: MXMetric {
    public let cumulativeForegroundTime: Measurement<UnitDuration>
    public let cumulativeBackgroundTime: Measurement<UnitDuration>
    public let cumulativeBackgroundAudioTime: Measurement<UnitDuration>
    public let cumulativeBackgroundLocationTime: Measurement<UnitDuration>
    init(_ d: _MXPayloadData) {
        cumulativeForegroundTime = Measurement(value: d.fg, unit: _MX.s); cumulativeBackgroundTime = Measurement(value: d.bg, unit: _MX.s)
        cumulativeBackgroundAudioTime = Measurement(value: d.bgAudio, unit: _MX.s); cumulativeBackgroundLocationTime = Measurement(value: d.bgLocation, unit: _MX.s)
    }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeForegroundTime": _MX.m(cumulativeForegroundTime), "cumulativeBackgroundTime": _MX.m(cumulativeBackgroundTime),
         "cumulativeBackgroundAudioTime": _MX.m(cumulativeBackgroundAudioTime), "cumulativeBackgroundLocationTime": _MX.m(cumulativeBackgroundLocationTime)]
    }
}
open class MXDiskIOMetric: MXMetric {
    public let cumulativeLogicalWrites: Measurement<UnitInformationStorage>
    init(_ d: _MXPayloadData) { cumulativeLogicalWrites = Measurement(value: d.writesKB, unit: _MX.kb) }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["cumulativeLogicalWrites": _MX.m(cumulativeLogicalWrites)] }
}
open class MXNetworkTransferMetric: MXMetric {
    public let cumulativeWifiUpload: Measurement<UnitInformationStorage>
    public let cumulativeWifiDownload: Measurement<UnitInformationStorage>
    public let cumulativeCellularUpload: Measurement<UnitInformationStorage>
    public let cumulativeCellularDownload: Measurement<UnitInformationStorage>
    init(_ d: _MXPayloadData) {
        cumulativeWifiUpload = Measurement(value: d.wifiUpKB, unit: _MX.kb); cumulativeWifiDownload = Measurement(value: d.wifiDownKB, unit: _MX.kb)
        cumulativeCellularUpload = Measurement(value: d.cellUpKB, unit: _MX.kb); cumulativeCellularDownload = Measurement(value: d.cellDownKB, unit: _MX.kb)
    }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeWifiUpload": _MX.m(cumulativeWifiUpload), "cumulativeWifiDownload": _MX.m(cumulativeWifiDownload),
         "cumulativeCellularUpload": _MX.m(cumulativeCellularUpload), "cumulativeCellularDownload": _MX.m(cumulativeCellularDownload)]
    }
}
open class MXForegroundExitData: NSObject {
    public let cumulativeNormalAppExitCount: Int
    public let cumulativeMemoryResourceLimitExitCount: Int
    public let cumulativeBadAccessExitCount: Int
    public let cumulativeAbnormalExitCount: Int
    public let cumulativeIllegalInstructionExitCount: Int
    public let cumulativeAppWatchdogExitCount: Int
    init(_ e: [String: Int]) {
        cumulativeNormalAppExitCount = e["normal"] ?? 0; cumulativeMemoryResourceLimitExitCount = e["memoryLimit"] ?? 0
        cumulativeBadAccessExitCount = e["badAccess"] ?? 0; cumulativeAbnormalExitCount = e["abnormal"] ?? 0
        cumulativeIllegalInstructionExitCount = e["illegalInstruction"] ?? 0; cumulativeAppWatchdogExitCount = e["watchdog"] ?? 0
    }
    var dictionary: [AnyHashable: Any] {
        ["cumulativeNormalAppExitCount": cumulativeNormalAppExitCount, "cumulativeMemoryResourceLimitExitCount": cumulativeMemoryResourceLimitExitCount,
         "cumulativeBadAccessExitCount": cumulativeBadAccessExitCount, "cumulativeAbnormalExitCount": cumulativeAbnormalExitCount,
         "cumulativeIllegalInstructionExitCount": cumulativeIllegalInstructionExitCount, "cumulativeAppWatchdogExitCount": cumulativeAppWatchdogExitCount]
    }
}
open class MXBackgroundExitData: NSObject {
    public let cumulativeNormalAppExitCount: Int
    public let cumulativeMemoryResourceLimitExitCount: Int
    public let cumulativeCPUResourceLimitExitCount: Int
    public let cumulativeMemoryPressureExitCount: Int
    public let cumulativeBadAccessExitCount: Int
    public let cumulativeAbnormalExitCount: Int
    public let cumulativeIllegalInstructionExitCount: Int
    public let cumulativeAppWatchdogExitCount: Int
    public let cumulativeSuspendedWithLockedFileExitCount: Int
    public let cumulativeBackgroundTaskAssertionTimeoutExitCount: Int
    init(_ e: [String: Int]) {
        cumulativeNormalAppExitCount = e["normal"] ?? 0; cumulativeMemoryResourceLimitExitCount = e["memoryLimit"] ?? 0
        cumulativeCPUResourceLimitExitCount = e["cpuLimit"] ?? 0; cumulativeMemoryPressureExitCount = e["memoryPressure"] ?? 0
        cumulativeBadAccessExitCount = e["badAccess"] ?? 0; cumulativeAbnormalExitCount = e["abnormal"] ?? 0
        cumulativeIllegalInstructionExitCount = e["illegalInstruction"] ?? 0; cumulativeAppWatchdogExitCount = e["watchdog"] ?? 0
        cumulativeSuspendedWithLockedFileExitCount = e["lockedFile"] ?? 0; cumulativeBackgroundTaskAssertionTimeoutExitCount = e["taskTimeout"] ?? 0
    }
    var dictionary: [AnyHashable: Any] {
        ["cumulativeNormalAppExitCount": cumulativeNormalAppExitCount, "cumulativeMemoryResourceLimitExitCount": cumulativeMemoryResourceLimitExitCount,
         "cumulativeCPUResourceLimitExitCount": cumulativeCPUResourceLimitExitCount, "cumulativeMemoryPressureExitCount": cumulativeMemoryPressureExitCount,
         "cumulativeBadAccessExitCount": cumulativeBadAccessExitCount, "cumulativeAbnormalExitCount": cumulativeAbnormalExitCount,
         "cumulativeIllegalInstructionExitCount": cumulativeIllegalInstructionExitCount, "cumulativeAppWatchdogExitCount": cumulativeAppWatchdogExitCount,
         "cumulativeSuspendedWithLockedFileExitCount": cumulativeSuspendedWithLockedFileExitCount,
         "cumulativeBackgroundTaskAssertionTimeoutExitCount": cumulativeBackgroundTaskAssertionTimeoutExitCount]
    }
}
open class MXAppExitMetric: MXMetric {
    public let foregroundExitData: MXForegroundExitData
    public let backgroundExitData: MXBackgroundExitData
    init(_ d: _MXPayloadData) { foregroundExitData = MXForegroundExitData(d.exitsFG); backgroundExitData = MXBackgroundExitData(d.exitsBG) }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["foregroundExitData": foregroundExitData.dictionary, "backgroundExitData": backgroundExitData.dictionary]
    }
}
open class MXCellularConditionMetric: MXMetric {
    public let histogrammedCellularConditionTime: MXHistogram<MXUnitSignalBars>
    init(_ b: [_MXBucket]) { histogrammedCellularConditionTime = MXHistogram(b, MXUnitSignalBars.bars) }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["cellConditionTime": histogrammedCellularConditionTime.dictionary] }
}
open class MXLocationActivityMetric: MXMetric {
    public let cumulativeBestAccuracyForNavigationTime: Measurement<UnitDuration>
    public let cumulativeBestAccuracyTime: Measurement<UnitDuration>
    public let cumulativeNearestTenMetersAccuracyTime: Measurement<UnitDuration>
    public let cumulativeHundredMetersAccuracyTime: Measurement<UnitDuration>
    public let cumulativeKilometerAccuracyTime: Measurement<UnitDuration>
    public let cumulativeThreeKilometersAccuracyTime: Measurement<UnitDuration>
    init(_ d: _MXPayloadData) {
        let l = d.location + [Double](repeating: 0, count: max(0, 6 - d.location.count))
        cumulativeBestAccuracyForNavigationTime = Measurement(value: l[0], unit: _MX.s); cumulativeBestAccuracyTime = Measurement(value: l[1], unit: _MX.s)
        cumulativeNearestTenMetersAccuracyTime = Measurement(value: l[2], unit: _MX.s); cumulativeHundredMetersAccuracyTime = Measurement(value: l[3], unit: _MX.s)
        cumulativeKilometerAccuracyTime = Measurement(value: l[4], unit: _MX.s); cumulativeThreeKilometersAccuracyTime = Measurement(value: l[5], unit: _MX.s)
    }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeBestAccuracyTime": _MX.m(cumulativeBestAccuracyTime), "cumulativeBestAccuracyForNavigationTime": _MX.m(cumulativeBestAccuracyForNavigationTime),
         "cumulativeNearestTenMetersAccuracyTime": _MX.m(cumulativeNearestTenMetersAccuracyTime), "cumulativeHundredMetersAccuracyTime": _MX.m(cumulativeHundredMetersAccuracyTime),
         "cumulativeKilometerAccuracyTime": _MX.m(cumulativeKilometerAccuracyTime), "cumulativeThreeKilometersAccuracyTime": _MX.m(cumulativeThreeKilometersAccuracyTime)]
    }
}
open class MXAnimationMetric: MXMetric {
    public let scrollHitchTimeRatio: Measurement<Unit>
    init(_ d: _MXPayloadData) { scrollHitchTimeRatio = Measurement(value: d.hitchRatio, unit: Unit(symbol: "ms per s")) }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["scrollHitchTimeRatio": _MX.m(scrollHitchTimeRatio)] }
}
open class MXDisplayMetric: MXMetric {
    public let averagePixelLuminance: MXAverage<MXUnitAveragePixelLuminance>?
    init(apl: Double, samples: Int) { averagePixelLuminance = MXAverage(Measurement(value: apl, unit: MXUnitAveragePixelLuminance.apl), samples, 0) }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        averagePixelLuminance.map { ["averagePixelLuminance": $0.dictionary] } ?? [:]
    }
}
open class MXSignpostIntervalData: NSObject {
    public let histogrammedSignpostDuration: MXHistogram<UnitDuration>
    public let cumulativeCPUTime: Measurement<UnitDuration>?
    public let averageMemory: MXAverage<UnitInformationStorage>?
    public let cumulativeLogicalWrites: Measurement<UnitInformationStorage>?
    public let cumulativeHitchTimeRatio: Measurement<Unit>?
    init(_ s: _MXSignpostData) {
        histogrammedSignpostDuration = MXHistogram(s.durations, _MX.ms)
        cumulativeCPUTime = s.cpuMs.map { Measurement(value: $0, unit: _MX.ms) }
        averageMemory = s.memKB.map { MXAverage(Measurement(value: $0, unit: _MX.kb), s.count, 0) }
        cumulativeLogicalWrites = s.writesKB.map { Measurement(value: $0, unit: _MX.kb) }
        cumulativeHitchTimeRatio = s.hitchRatio.map { Measurement(value: $0, unit: Unit(symbol: "ms per s")) }
    }
    var dictionary: [AnyHashable: Any] {
        var d: [AnyHashable: Any] = ["histogrammedSignpostDurations": histogrammedSignpostDuration.dictionary]
        if let c = cumulativeCPUTime { d["signpostCumulativeCPUTime"] = _MX.m(c) }
        if let m = averageMemory { d["signpostAverageMemory"] = m.dictionary }
        if let w = cumulativeLogicalWrites { d["signpostCumulativeLogicalWrites"] = _MX.m(w) }
        if let h = cumulativeHitchTimeRatio { d["signpostCumulativeHitchTimeRatio"] = _MX.m(h) }
        return d
    }
}
open class MXSignpostMetric: MXMetric {
    public let signpostName: String
    public let signpostCategory: String
    public let totalCount: Int
    public let signpostIntervalData: MXSignpostIntervalData?
    init(_ s: _MXSignpostData) {
        signpostName = s.name; signpostCategory = s.category; totalCount = s.count
        signpostIntervalData = s.durations.isEmpty ? nil : MXSignpostIntervalData(s)
    }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        var d: [AnyHashable: Any] = ["signpostName": signpostName, "signpostCategory": signpostCategory, "totalSignpostCount": totalCount]
        if let i = signpostIntervalData { d["signpostIntervalData"] = i.dictionary }
        return d
    }
}

open class MXMetaData: NSObject {
    public let regionFormat: String
    public let osVersion: String
    public let deviceType: String
    public let applicationBuildVersion: String
    public let platformArchitecture: String
    public let lowPowerModeEnabled: Bool
    public let isTestFlightApp: Bool
    public let pid: pid_t
    public let bundleIdentifier: String
    init(_ m: _MXMeta) {
        regionFormat = m.region; osVersion = m.os; deviceType = m.device; applicationBuildVersion = m.build
        platformArchitecture = m.arch; lowPowerModeEnabled = m.lowPower; isTestFlightApp = m.testFlight; pid = m.pid; bundleIdentifier = m.bundle
    }
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["regionFormat": regionFormat, "osVersion": osVersion, "deviceType": deviceType, "appBuildVersion": applicationBuildVersion,
         "platformArchitecture": platformArchitecture, "lowPowerModeEnabled": lowPowerModeEnabled, "isTestFlightApp": isTestFlightApp,
         "pid": Int(pid), "bundleIdentifier": bundleIdentifier]
    }
}

// MARK: - Payloads

open class MXMetricPayload: NSObject {
    public let latestApplicationVersion: String
    public let includesMultipleApplicationVersions: Bool
    public let timeStampBegin: Date
    public let timeStampEnd: Date
    public let cpuMetrics: MXCPUMetric?
    public let gpuMetrics: MXGPUMetric?
    public let cellularConditionMetrics: MXCellularConditionMetric?
    public let applicationTimeMetrics: MXAppRunTimeMetric?
    public let locationActivityMetrics: MXLocationActivityMetric?
    public let networkTransferMetrics: MXNetworkTransferMetric?
    public let applicationLaunchMetrics: MXAppLaunchMetric?
    public let applicationResponsivenessMetrics: MXAppResponsivenessMetric?
    public let diskIOMetrics: MXDiskIOMetric?
    public let memoryMetrics: MXMemoryMetric?
    public let displayMetrics: MXDisplayMetric?
    public let animationMetrics: MXAnimationMetric?
    public let applicationExitMetrics: MXAppExitMetric?
    public let signpostMetrics: [MXSignpostMetric]?
    public let metaData: MXMetaData?
    let data: _MXPayloadData
    init(_ d: _MXPayloadData) {
        data = d
        latestApplicationVersion = d.appVersion; includesMultipleApplicationVersions = d.multipleVersions
        timeStampBegin = Date(timeIntervalSince1970: d.begin); timeStampEnd = Date(timeIntervalSince1970: d.end)
        cpuMetrics = MXCPUMetric(d); gpuMetrics = MXGPUMetric(d)
        cellularConditionMetrics = d.cellular.map { MXCellularConditionMetric($0) }
        applicationTimeMetrics = MXAppRunTimeMetric(d); locationActivityMetrics = MXLocationActivityMetric(d)
        networkTransferMetrics = MXNetworkTransferMetric(d); applicationLaunchMetrics = MXAppLaunchMetric(d)
        applicationResponsivenessMetrics = MXAppResponsivenessMetric(d); diskIOMetrics = MXDiskIOMetric(d); memoryMetrics = MXMemoryMetric(d)
        displayMetrics = d.apl.map { MXDisplayMetric(apl: $0, samples: d.aplN) }
        animationMetrics = MXAnimationMetric(d); applicationExitMetrics = MXAppExitMetric(d)
        signpostMetrics = d.signposts.isEmpty ? nil : d.signposts.map { MXSignpostMetric($0) }
        metaData = MXMetaData(d.meta)
    }

    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        var d: [AnyHashable: Any] = ["appVersion": latestApplicationVersion, "multipleAppVersions": includesMultipleApplicationVersions,
                                     "timeStampBegin": _MX.date(timeStampBegin), "timeStampEnd": _MX.date(timeStampEnd)]
        let parts: [(String, MXMetric?)] = [("cpuMetrics", cpuMetrics), ("gpuMetrics", gpuMetrics), ("cellularConditionMetrics", cellularConditionMetrics),
            ("applicationTimeMetrics", applicationTimeMetrics), ("locationActivityMetrics", locationActivityMetrics),
            ("networkTransferMetrics", networkTransferMetrics), ("applicationLaunchMetrics", applicationLaunchMetrics),
            ("applicationResponsivenessMetrics", applicationResponsivenessMetrics), ("diskIOMetrics", diskIOMetrics),
            ("memoryMetrics", memoryMetrics), ("displayMetrics", displayMetrics), ("animationMetrics", animationMetrics),
            ("applicationExitMetrics", applicationExitMetrics)]
        for (k, m) in parts { if let m { d[k] = m.dictionaryRepresentation() } }
        if let s = signpostMetrics { d["signpostMetrics"] = s.map { $0.dictionaryRepresentation() } }
        if let md = metaData { d["metaData"] = md.dictionaryRepresentation() }
        return d
    }
    @available(*, deprecated, renamed: "dictionaryRepresentation()")
    open func DictionaryRepresentation() -> [AnyHashable: Any] { dictionaryRepresentation() }
}

// MARK: - Diagnostics data

struct _MXFrame: Codable { var binary: String; var uuid: String; var offset: UInt64; var address: UInt64; var symbol: String }
struct _MXSignpostRecordData: Codable {
    var name: String, category: String, subsystem: String, begin: Double, end: Double?, interval: Bool
}
struct _MXDiagData: Codable {
    var kind: String                            // crash, hang, cpu, disk, launch
    var date: Double
    var appVersion = _MX.appVersion
    var meta = _MXMeta()
    var frames: [_MXFrame] = []
    var value = 0.0, value2 = 0.0               // hang / launch seconds; CPU and sampled seconds; writes MB
    var exceptionType: Int? = nil, exceptionCode: Int? = nil, signal: Int? = nil
    var termination: String? = nil, vmRegion: String? = nil
    var excName: String? = nil, excReason: String? = nil, excClass: String? = nil
    var signposts: [_MXSignpostRecordData] = []

    /// frames from the host's "image\toffset\taddress\tsymbol" lines
    static func frames(_ text: String) -> [_MXFrame] {
        text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 3 else { return nil }
            return _MXFrame(binary: f[0], uuid: _MXRecorder.uuid(of: f[0]), offset: UInt64(f[1]) ?? 0, address: UInt64(f[2]) ?? 0,
                            symbol: f.count > 3 ? f[3] : "")
        }
    }

    static func sample(_ kind: String, end: Date) -> _MXDiagData {
        let exe = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? "App"
        var d = _MXDiagData(kind: kind, date: end.timeIntervalSince1970)
        let names: [String]
        switch kind {
        case "crash":
            names = [exe, "UIKitCore", "libdyld.dylib"]
            d.termination = "Namespace SIGNAL, Code 0xb"; d.exceptionType = 1; d.exceptionCode = 0; d.signal = 11
            d.vmRegion = "0 is not in any region. Bytes before following region: 4000000000 REGION TYPE START - END [ VSIZE] PRT/MAX SHRMOD REGION DETAIL UNUSED SPACE AT START ---> __TEXT 0000000000000000-0000000000000000 [ 32K] r-x/r-x SM=COW ...pp/Test"
            d.excName = "NSRangeException"; d.excReason = "*** -[__NSArrayM objectAtIndex:]: index 3 beyond bounds [0 .. 1]"; d.excClass = "NSException"
        case "hang": names = [exe, "UIKitCore"]; d.value = 20
        case "cpu": names = [exe]; d.value = 20; d.value2 = 20
        case "disk": names = [exe, "libsystem_kernel.dylib"]; d.value = 2000
        default: names = [exe, "dyld"]; d.value = 15
        }
        d.frames = names.enumerated().map { _MXFrame(binary: $1, uuid: "00000000-0000-0000-0000-000000000000", offset: UInt64(1000 + $0 * 64), address: UInt64(74565 + $0 * 64), symbol: "") }
        return d
    }
}
struct _MXDiagPayloadData: Codable { var begin: Double; var end: Double; var diags: [_MXDiagData] }

// MARK: - Diagnostics

open class MXCallStackTree: NSObject {
    let frames: [_MXFrame]
    init(_ frames: [_MXFrame]) { self.frames = frames }
    open func jsonRepresentation() -> Data { _MX.json(dictionary) }
    /// one thread; the root frame is the innermost (where the thread was), each frame's caller in its subFrames
    var dictionary: [AnyHashable: Any] {
        var sub: [String: Any]? = nil
        for f in frames.reversed() {
            var d: [String: Any] = ["binaryUUID": f.uuid, "offsetIntoBinaryTextSegment": f.offset, "sampleCount": 1,
                                    "binaryName": f.binary, "address": f.address]
            if let s = sub { d["subFrames"] = [s] }
            sub = d
        }
        return ["callStackPerThread": true, "callStacks": [["threadAttributed": true, "callStackRootFrames": sub.map { [$0] } ?? []]]]
    }
}

/// a signpost around a diagnostic (iOS 17)
open class MXSignpostRecord: NSObject {
    public let subsystem: String
    public let category: String
    public let name: String
    public let beginTimeStamp: Date
    public let endTimeStamp: Date?
    public let duration: Measurement<UnitDuration>?
    public let isInterval: Bool
    init(_ s: _MXSignpostRecordData) {
        subsystem = s.subsystem; category = s.category; name = s.name; isInterval = s.interval
        beginTimeStamp = Date(timeIntervalSince1970: s.begin)
        endTimeStamp = s.end.map { Date(timeIntervalSince1970: $0) }
        duration = s.end.map { Measurement(value: ($0 - s.begin) * 1000, unit: _MX.ms) }
    }
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        var d: [AnyHashable: Any] = ["subsystem": subsystem, "category": category, "name": name, "beginTimeStamp": _MX.date(beginTimeStamp), "isInterval": isInterval]
        if let e = endTimeStamp { d["endTimeStamp"] = _MX.date(e) }
        if let du = duration { d["duration"] = _MX.m(du) }
        return d
    }
}

open class MXDiagnostic: NSObject {
    public let metaData: MXMetaData
    public let applicationVersion: String
    public let signpostData: [MXSignpostRecord]?
    public let callStackTree: MXCallStackTree
    let data: _MXDiagData
    init(_ d: _MXDiagData) {
        data = d; metaData = MXMetaData(d.meta); applicationVersion = d.appVersion
        signpostData = d.signposts.isEmpty ? nil : d.signposts.map { MXSignpostRecord($0) }
        callStackTree = MXCallStackTree(d.frames)
    }
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        var d: [AnyHashable: Any] = ["version": "1.0.0", "callStackTree": callStackTree.dictionary,
                                     "diagnosticMetaData": metaData.dictionaryRepresentation().merging(extra) { a, _ in a }]
        if let s = signpostData { d["signpostData"] = s.map { $0.dictionaryRepresentation() } }
        return d
    }
    var extra: [AnyHashable: Any] { ["appVersion": applicationVersion] }
}
open class MXCrashDiagnosticObjectiveCExceptionReason: NSObject {
    public let composedMessage: String
    public let formatString: String
    public let arguments: [String]
    public let exceptionType: String
    public let className: String
    public let exceptionName: String
    init(name: String, reason: String, className: String) {
        composedMessage = reason; formatString = reason.replacingOccurrences(of: "%", with: "%%"); arguments = []
        exceptionType = name; self.className = className; exceptionName = name
    }
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["composedMessage": composedMessage, "formatString": formatString, "arguments": arguments, "exceptionType": exceptionType,
         "className": className, "exceptionName": exceptionName]
    }
}
open class MXCrashDiagnostic: MXDiagnostic {
    public let terminationReason: String?
    public let virtualMemoryRegionInfo: String?
    public let exceptionType: NSNumber?
    public let exceptionCode: NSNumber?
    public let signal: NSNumber?
    public let exceptionReason: MXCrashDiagnosticObjectiveCExceptionReason?
    override init(_ d: _MXDiagData) {
        terminationReason = d.termination; virtualMemoryRegionInfo = d.vmRegion
        exceptionType = d.exceptionType.map { NSNumber(value: $0) }; exceptionCode = d.exceptionCode.map { NSNumber(value: $0) }
        signal = d.signal.map { NSNumber(value: $0) }
        exceptionReason = d.excName.map { MXCrashDiagnosticObjectiveCExceptionReason(name: $0, reason: d.excReason ?? "", className: d.excClass ?? "NSException") }
        super.init(d)
    }
    override var extra: [AnyHashable: Any] {
        var e: [AnyHashable: Any] = ["appVersion": applicationVersion]
        if let t = terminationReason { e["terminationReason"] = t }
        if let v = virtualMemoryRegionInfo { e["virtualMemoryRegionInfo"] = v }
        if let t = exceptionType { e["exceptionType"] = t }
        if let c = exceptionCode { e["exceptionCode"] = c }
        if let s = signal { e["signal"] = s }
        if let r = exceptionReason { e["objectiveCexceptionReason"] = r.dictionaryRepresentation() }
        return e
    }
}
open class MXHangDiagnostic: MXDiagnostic {
    public let hangDuration: Measurement<UnitDuration>
    override init(_ d: _MXDiagData) { hangDuration = Measurement(value: d.value, unit: _MX.s); super.init(d) }
    override var extra: [AnyHashable: Any] { ["appVersion": applicationVersion, "hangDuration": _MX.m(hangDuration)] }
}
open class MXCPUExceptionDiagnostic: MXDiagnostic {
    public let totalCPUTime: Measurement<UnitDuration>
    public let totalSampledTime: Measurement<UnitDuration>
    override init(_ d: _MXDiagData) {
        totalCPUTime = Measurement(value: d.value, unit: _MX.s); totalSampledTime = Measurement(value: d.value2, unit: _MX.s); super.init(d)
    }
    override var extra: [AnyHashable: Any] { ["appVersion": applicationVersion, "totalCPUTime": _MX.m(totalCPUTime), "totalSampledTime": _MX.m(totalSampledTime)] }
}
open class MXDiskWriteExceptionDiagnostic: MXDiagnostic {
    public let totalWritesCaused: Measurement<UnitInformationStorage>
    override init(_ d: _MXDiagData) { totalWritesCaused = Measurement(value: d.value, unit: UnitInformationStorage.megabytes); super.init(d) }
    override var extra: [AnyHashable: Any] { ["appVersion": applicationVersion, "writesCaused": _MX.m(totalWritesCaused)] }
}
open class MXAppLaunchDiagnostic: MXDiagnostic {
    public let launchDuration: Measurement<UnitDuration>
    override init(_ d: _MXDiagData) { launchDuration = Measurement(value: d.value, unit: _MX.s); super.init(d) }
    override var extra: [AnyHashable: Any] { ["appVersion": applicationVersion, "launchDuration": _MX.m(launchDuration)] }
}

open class MXDiagnosticPayload: NSObject {
    public let timeStampBegin: Date
    public let timeStampEnd: Date
    public let crashDiagnostics: [MXCrashDiagnostic]?
    public let hangDiagnostics: [MXHangDiagnostic]?
    public let cpuExceptionDiagnostics: [MXCPUExceptionDiagnostic]?
    public let diskWriteExceptionDiagnostics: [MXDiskWriteExceptionDiagnostic]?
    public let appLaunchDiagnostics: [MXAppLaunchDiagnostic]?
    init(_ p: _MXDiagPayloadData) {
        timeStampBegin = Date(timeIntervalSince1970: p.begin); timeStampEnd = Date(timeIntervalSince1970: p.end)
        func of(_ k: String) -> [_MXDiagData]? { let v = p.diags.filter { $0.kind == k }; return v.isEmpty ? nil : v }
        crashDiagnostics = of("crash")?.map { MXCrashDiagnostic($0) }
        hangDiagnostics = of("hang")?.map { MXHangDiagnostic($0) }
        cpuExceptionDiagnostics = of("cpu")?.map { MXCPUExceptionDiagnostic($0) }
        diskWriteExceptionDiagnostics = of("disk")?.map { MXDiskWriteExceptionDiagnostic($0) }
        appLaunchDiagnostics = of("launch")?.map { MXAppLaunchDiagnostic($0) }
    }
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        var d: [AnyHashable: Any] = ["timeStampBegin": _MX.date(timeStampBegin), "timeStampEnd": _MX.date(timeStampEnd)]
        if let c = crashDiagnostics { d["crashDiagnostics"] = c.map { $0.dictionaryRepresentation() } }
        if let c = hangDiagnostics { d["hangDiagnostics"] = c.map { $0.dictionaryRepresentation() } }
        if let c = cpuExceptionDiagnostics { d["cpuExceptionDiagnostics"] = c.map { $0.dictionaryRepresentation() } }
        if let c = diskWriteExceptionDiagnostics { d["diskWriteExceptionDiagnostics"] = c.map { $0.dictionaryRepresentation() } }
        if let c = appLaunchDiagnostics { d["appLaunchDiagnostics"] = c.map { $0.dictionaryRepresentation() } }
        return d
    }
    @available(*, deprecated, renamed: "dictionaryRepresentation()")
    open func DictionaryRepresentation() -> [AnyHashable: Any] { dictionaryRepresentation() }
}

// MARK: - Signposts for MetricKit

let _mxSubsystem = "com.apple.metrickit.log"

/// os_signpost for MetricKit's log handles (MXMetricManager.makeLogHandle): the intervals and events become
/// signpost metrics in the next metric payload
public func mxSignpost(_ type: OSSignpostType, dso: UnsafeRawPointer = #dsohandle, log: OSLog, name: StaticString, signpostID: OSSignpostID = .exclusive) {
    os_signpost(type, dso: dso, log: log, name: name, signpostID: signpostID)
}
public func mxSignpost(_ type: OSSignpostType, dso: UnsafeRawPointer = #dsohandle, log: OSLog, name: StaticString, signpostID: OSSignpostID = .exclusive,
                       _ format: StaticString, _ arguments: CVarArg...) {
    // the message formatted here (privacy decorations dropped: signpost messages are kept as written) and recorded
    // through OSSignposter
    let plain = format.description.replacingOccurrences(of: "%\\{[a-z, ]*\\}", with: "%", options: .regularExpression)
    let msg = OSLogMessage(stringLiteral: String(format: plain, arguments: arguments))
    let sp = OSSignposter(logHandle: log)
    switch type {
    case .begin: _ = sp.beginInterval(name, id: signpostID, msg)
    case .end: sp.endInterval(name, .beginState(id: signpostID), msg)
    default: sp.emitEvent(name, id: signpostID, msg)
    }
}
public func mxSignpostAnimationIntervalBegin(log: OSLog, name: StaticString, signpostID: OSSignpostID = .exclusive) {
    os_signpost(.begin, log: log, name: name, signpostID: signpostID)
}

// MARK: - Manager

@objc public protocol MXMetricManagerSubscriber: NSObjectProtocol {
    @objc(didReceiveMetricPayloads:) optional func didReceive(_ payloads: [MXMetricPayload])
    @objc(didReceiveDiagnosticPayloads:) optional func didReceive(_ payloads: [MXDiagnosticPayload])
}

public struct MXMetricManagerError: Error, CustomNSError, Sendable {
    public enum Code: Int, Sendable { case invalidID = 0, maxCount = 1, pastDeadline = 2, duplicate = 3, unknown = 4, internalFailure = 5 }
    public let code: Code
    public static var errorDomain: String { "MXErrorDomain" }
    public var errorCode: Int { code.rawValue }
}

open class MXMetricManager: NSObject, @unchecked Sendable {
    public static let shared = MXMetricManager()
    private struct Weak { weak var s: MXMetricManagerSubscriber? }
    private var subscribers: [Weak] = []
    private var timer: Timer?
    private var lastTrigger: String?
    private let lock = NSLock()
    let recorder = _MXRecorder()
    private var past: [MXMetricPayload] = [], pastDiagnostics: [MXDiagnosticPayload] = []
    private var deliveredStartup = false

    static var triggerPath: String {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return (data as NSString).appendingPathComponent("Library/isim/MetricKitTrigger")
    }
    private override init() {
        lastTrigger = try? String(contentsOfFile: MXMetricManager.triggerPath, encoding: .utf8)
        super.init()
        recorder.start()
        DispatchQueue.main.async { self.startPolling() }
    }

    /// the reports generated since the shared manager was first used in this process
    public var pastPayloads: [MXMetricPayload] { lock.lock(); defer { lock.unlock() }; return past }
    public var pastDiagnosticPayloads: [MXDiagnosticPayload] { lock.lock(); defer { lock.unlock() }; return pastDiagnostics }

    public func add(_ subscriber: MXMetricManagerSubscriber) {
        lock.lock()
        subscribers.removeAll { $0.s == nil || $0.s === subscriber }
        subscribers.append(Weak(s: subscriber))
        lock.unlock()
        // what earlier runs left: their metrics (iOS: the daily report) and their crashes and other diagnostics
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.deliverStartup() }
    }
    public func remove(_ subscriber: MXMetricManagerSubscriber) {
        lock.lock(); defer { lock.unlock() }
        subscribers.removeAll { $0.s == nil || $0.s === subscriber }
    }

    public class func makeLogHandle(category: String) -> OSLog { OSLog(subsystem: _mxSubsystem, category: category) }

    /// iOS 16 extended launch measurement: tasks begun before the first frame, finished whenever the app is ready
    public class func extendLaunchMeasurement(forTaskID taskID: String) throws { try shared.recorder.extendLaunch(taskID) }
    public class func finishExtendedLaunchMeasurement(forTaskID taskID: String) throws { try shared.recorder.finishLaunch(taskID) }

    private func startPolling() {
        guard timer == nil else { return }
        timer = Timer._isimScheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
    }
    private func poll() {
        recorder.tick()
        let diags = recorder.takeNewDiagnostics()
        if !diags.isEmpty { deliver(metrics: [], diagnostics: [diags]) }
        let now = try? String(contentsOfFile: MXMetricManager.triggerPath, encoding: .utf8)
        guard let now, now != lastTrigger else { return }
        lastTrigger = now
        if now.hasPrefix("deliver") { deliverMeasured() } else { deliverSimulatedPayloads() }
    }
    private func deliverStartup() {
        guard !deliveredStartup else { return }
        deliveredStartup = true
        let (metrics, diags) = recorder.takeStartup()
        deliver(metrics: metrics, diagnostics: diags.isEmpty ? [] : [diags])
    }
    /// `metrickit deliver`: what has been measured in this run so far, and anything still waiting
    func deliverMeasured() {
        deliveredStartup = true
        var (metrics, diags) = recorder.takeStartup()
        metrics.append(recorder.takeWindow())
        diags += recorder.takeNewDiagnostics()
        NSLog("isim MetricKit: delivering %d measured metric payload(s) and %d diagnostic(s)", metrics.count, diags.count)
        deliver(metrics: metrics, diagnostics: diags.isEmpty ? [] : [diags])
    }
    private func deliver(metrics: [_MXPayloadData], diagnostics: [[_MXDiagData]]) {
        let mp = metrics.map { MXMetricPayload($0) }
        let dp = diagnostics.map { d -> MXDiagnosticPayload in
            let t = d.map(\.date)
            return MXDiagnosticPayload(_MXDiagPayloadData(begin: t.min() ?? Date().timeIntervalSince1970, end: t.max() ?? Date().timeIntervalSince1970, diags: d))
        }
        lock.lock(); past += mp; pastDiagnostics += dp; let subs = subscribers.compactMap { $0.s }; lock.unlock()
        for s in subs {
            if !mp.isEmpty { s.didReceive?(mp) }
            if !dp.isEmpty { s.didReceive?(dp) }
        }
    }

    /// what Xcode's Debug > Simulate MetricKit Payloads does: one metric and one diagnostic payload per subscriber
    public func deliverSimulatedPayloads() {
        lock.lock(); let subs = subscribers.compactMap { $0.s }; lock.unlock()
        NSLog("isim MetricKit: delivering simulated payloads to %d subscriber(s) (sample data, not measurements)", subs.count)
        let end = Date()
        let diags = ["crash", "hang", "cpu", "disk", "launch"].map { _MXDiagData.sample($0, end: end) }
        for s in subs {
            s.didReceive?([MXMetricPayload(.sample(end: end))])
            s.didReceive?([MXDiagnosticPayload(_MXDiagPayloadData(begin: end.timeIntervalSince1970, end: end.timeIntervalSince1970, diags: diags))])
        }
    }
}

// MARK: - The recorder: measurements of this run, saved for the next launch

final class _MXRecorder: @unchecked Sendable {
    /// a run's cumulative measurements (since the process started)
    struct Counters: Codable {
        var start: Double, end: Double
        var pid: Int32 = ProcessInfo.processInfo.processIdentifier
        var appVersion = _MX.appVersion, build = _MX.buildVersion
        var cpu = 0.0, writes = 0.0, peakKB = 0.0
        var launchMs: [Double] = [], resumeMs: [Double] = [], extendedMs: [Double] = [], hangs: [Double] = []
        var fg = 0.0, bg = 0.0, bgAudio = 0.0, bgLocation = 0.0
        var up = 0.0, down = 0.0
        var loc = [Double](repeating: 0, count: 6)
        var hitch = 0.0
        var aplSum = 0.0, aplN = 0.0
        var suspended: [Double] = []
        var signposts: [String: SignpostAgg] = [:]          // "category\u{1}name"
        var background = false
    }
    struct SignpostAgg: Codable { var count = 0; var durationsMs: [Double] = [] }
    struct Saved: Codable { var current: Counters; var base: Counters; var diags: [_MXDiagData] }

    private let lock = NSLock()
    private var cur: Counters
    private var base: Counters
    private var signpostSeq = 0                               // log store entries looked at
    private var openIntervals: [String: Double] = [:]         // "category\u{1}name\u{1}id" -> begin
    private var hangIndex = 0
    private var newDiags: [_MXDiagData] = []
    private var startupMetrics: [_MXPayloadData] = []
    private var startupDiags: [_MXDiagData] = []
    private var lastSave = 0.0, lastTick = Date().timeIntervalSince1970
    private var launchChecked = false, cpuReported = false, diskReported = false
    private var cpuWindow: [(t: Double, cpu: Double)] = []
    private var enteredForeground: Double?
    private var extendedTasks: [String: Double] = [:]

    init() {
        let start = isim_diag_process_start()
        cur = Counters(start: start, end: start); base = cur
    }

    // MARK: files
    static var dir: URL {
        let d = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/com.apple.metrickit", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static var runFile: URL { dir.appendingPathComponent("run.json") }
    static var pendingFile: URL { dir.appendingPathComponent("pending.json") }
    static var crashMarkFile: URL { dir.appendingPathComponent("crash-reports-seen") }
    static var reportsDir: URL {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return URL(fileURLWithPath: data).appendingPathComponent("Library/Logs/DiagnosticReports")
    }

    /// binaries' LC_UUIDs from the crash reports this process has seen; unknown: zeros
    static var uuids: [String: String] = [:]
    static func uuid(of binary: String) -> String { uuids[binary] ?? "00000000-0000-0000-0000-000000000000" }

    // MARK: start: the previous run becomes a pending payload (with its exit), crash reports become diagnostics
    func start() {
        let decoder = JSONDecoder()
        var pending: [_MXPayloadData] = (try? decoder.decode([_MXPayloadData].self, from: Data(contentsOf: Self.pendingFile))) ?? []
        var leftover: [_MXDiagData] = []
        let crashes = crashDiagnostics()
        if let saved = try? decoder.decode(Saved.self, from: Data(contentsOf: Self.runFile)) {
            var window = Self.window(saved.current, saved.base)
            // how the run ended: a crash report written after it started names the signal; otherwise a normal exit
            let crash = crashes.first { $0.date >= saved.current.start && $0.date <= saved.current.end + 3600 }
            let kind: String
            switch crash?.signal {
            case nil: kind = "normal"
            case 11?, 10?: kind = "badAccess"
            case 4?, 5?: kind = "illegalInstruction"
            default: kind = "abnormal"
            }
            if saved.current.background { window.exitsBG[kind, default: 0] += 1 } else { window.exitsFG[kind, default: 0] += 1 }
            pending.append(window)
            leftover = saved.diags
        }
        try? FileManager.default.removeItem(at: Self.runFile)
        try? FileManager.default.removeItem(at: Self.pendingFile)
        startupMetrics = pending
        startupDiags = leftover + crashes
        // app state
        let nc = NotificationCenter.default
        nc.addObserver(forName: Notification.Name("UIApplicationDidEnterBackgroundNotification"), object: nil, queue: nil) { [weak self] _ in self?.setBackground(true) }
        nc.addObserver(forName: Notification.Name("UIApplicationWillEnterForegroundNotification"), object: nil, queue: nil) { [weak self] _ in
            self?.setBackground(false); self?.enteredForeground = Date().timeIntervalSince1970
        }
        nc.addObserver(forName: Notification.Name("UIApplicationDidBecomeActiveNotification"), object: nil, queue: nil) { [weak self] _ in
            guard let self, let t = self.enteredForeground else { return }
            self.lock.lock(); self.cur.resumeMs.append((Date().timeIntervalSince1970 - t) * 1000); self.lock.unlock()
            self.enteredForeground = nil
        }
        nc.addObserver(forName: Notification.Name("UIApplicationWillTerminateNotification"), object: nil, queue: nil) { [weak self] _ in self?.save() }
        tick()
    }
    private func setBackground(_ bg: Bool) { tick(); lock.lock(); cur.background = bg; lock.unlock(); save() }

    /// crash reports for this app not seen before (the newest first)
    private func crashDiagnostics() -> [_MXDiagData] {
        let bundle = Bundle.main.bundleIdentifier ?? ""
        let seen = (try? String(contentsOf: Self.crashMarkFile, encoding: .utf8)).flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        var newest = seen
        var out: [_MXDiagData] = []
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: Self.reportsDir.path)) ?? [] where name.hasSuffix(".ips") {
            let url = Self.reportsDir.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path), let m = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970, m > seen,
                  let text = try? String(contentsOf: url, encoding: .utf8), let nl = text.firstIndex(of: "\n") else { continue }
            guard let header = try? JSONSerialization.jsonObject(with: Data(text[..<nl].utf8)) as? [String: Any], header["bundleID"] as? String == bundle,
                  let body = try? JSONSerialization.jsonObject(with: Data(text[text.index(after: nl)...].utf8)) as? [String: Any] else { continue }
            newest = max(newest, m)
            out.append(Self.crash(from: body, header: header, date: m))
        }
        if newest > seen { try? String(newest).write(to: Self.crashMarkFile, atomically: true, encoding: .utf8) }
        return out.sorted { $0.date > $1.date }
    }
    static func crash(from body: [String: Any], header: [String: Any], date: Double) -> _MXDiagData {
        var d = _MXDiagData(kind: "crash", date: date)
        d.appVersion = header["app_version"] as? String ?? d.appVersion
        d.meta.pid = Int32(body["pid"] as? Int ?? 0)
        let exc = body["exception"] as? [String: Any] ?? [:], term = body["termination"] as? [String: Any] ?? [:]
        let signals = ["SIGSEGV": 11, "SIGBUS": 10, "SIGILL": 4, "SIGTRAP": 5, "SIGABRT": 6, "SIGFPE": 8]
        d.signal = signals[exc["signal"] as? String ?? ""] ?? (term["code"] as? Int)
        d.exceptionType = body["isimExceptionType"] as? Int
        d.exceptionCode = (exc["rawCodes"] as? [Any])?.first as? Int ?? 0
        d.termination = "Namespace \(term["namespace"] as? String ?? "SIGNAL"), Code \(term["code"] as? Int ?? 0) \(term["indicator"] as? String ?? "")"
        if let sub = exc["subtype"] as? String { d.vmRegion = sub }
        if let r = body["exceptionReason"] as? [String: Any] {
            d.excName = r["name"] as? String; d.excReason = r["reason"] as? String; d.excClass = r["className"] as? String
        }
        let images = body["usedImages"] as? [[String: Any]] ?? []
        for img in images { if let n = img["name"] as? String, let u = img["uuid"] as? String { uuids[n] = u } }
        let thread = (body["threads"] as? [[String: Any]])?.first { $0["triggered"] as? Bool == true }
        d.frames = (thread?["frames"] as? [[String: Any]] ?? []).map { f in
            let off = (f["imageOffset"] as? NSNumber)?.uint64Value ?? 0
            if let i = f["imageIndex"] as? Int, i < images.count {
                let img = images[i]
                let base = (img["base"] as? NSNumber)?.uint64Value ?? 0
                return _MXFrame(binary: img["name"] as? String ?? "?", uuid: img["uuid"] as? String ?? "", offset: off, address: base + off, symbol: f["symbol"] as? String ?? "")
            }
            return _MXFrame(binary: f["imageName"] as? String ?? "?", uuid: "00000000-0000-0000-0000-000000000000", offset: off, address: off, symbol: f["symbol"] as? String ?? "")
        }
        return d
    }

    // MARK: measuring (every 0.5 s from the manager's timer, and on state changes)
    func tick() {
        var u = [Double](repeating: 0, count: 8)
        _ = u.withUnsafeMutableBufferPointer { isim_resource_usage($0.baseAddress!) }
        let now = Date().timeIntervalSince1970
        lock.lock()
        let dt = max(0, now - lastTick); lastTick = now
        cur.end = now
        cur.cpu = u[0] + u[1]; cur.peakKB = u[2]; cur.writes = u[3]
        if cur.launchMs.isEmpty, u[5] > 0 { cur.launchMs = [u[5]] }
        if cur.background {
            cur.bg += dt
            if isim_audio_active() != 0 { cur.bgAudio += dt }
            cur.suspended.append(u[6])
        } else { cur.fg += dt }
        cur.hitch = u[7]
        cur.up = isim_metric_get("net.up"); cur.down = isim_metric_get("net.down")
        cur.loc = ["loc.nav", "loc.best", "loc.10", "loc.100", "loc.1k", "loc.3k"].map { k in k.withCString { isim_metric_get($0) } }
        cur.bgLocation = isim_metric_get("loc.bg")
        cur.aplSum = isim_metric_get("apl.sum"); cur.aplN = isim_metric_get("apl.n")
        lock.unlock()
        readSignposts()
        readHangs()
        checkExceptions(now: now, cpu: u[0] + u[1], writes: u[3], launchMs: u[5])
        if now - lastSave > 5 { save() }
    }
    /// MetricKit's signposts from the log store: events and intervals on its log handles
    private func readSignposts() {
        var first = 0
        let end = isim_log_range(&first)
        var seq = max(signpostSeq, first)
        var found: [(String, Double?)] = []
        while seq < end {
            var date = 0.0, meta: [Int32] = [0, 0, 0], ids: [UInt64] = [0, 0]
            var strs: [UnsafeMutablePointer<CChar>?] = [nil, nil, nil, nil, nil]
            let ok = meta.withUnsafeMutableBufferPointer { m in ids.withUnsafeMutableBufferPointer { i in
                strs.withUnsafeMutableBufferPointer { s in isim_log_get(seq, &date, m.baseAddress!, i.baseAddress!, s.baseAddress!) } } }
            let t = strs.map { p -> String in defer { free(p) }; return p.map { String(cString: $0) } ?? "" }
            seq += 1
            guard ok != 0, meta[0] == 1, t[0] == _mxSubsystem else { continue }
            let key = t[1] + "\u{1}" + t[4]
            switch meta[2] {
            case 1: openIntervals[key + "\u{1}\(ids[0])"] = date
            case 2: if let b = openIntervals.removeValue(forKey: key + "\u{1}\(ids[0])") { found.append((key, (date - b) * 1000)) }
            default: found.append((key, nil))
            }
        }
        signpostSeq = seq
        guard !found.isEmpty else { return }
        lock.lock()
        for (k, d) in found {
            cur.signposts[k, default: SignpostAgg()].count += 1
            if let d { cur.signposts[k]!.durationsMs.append(d) }
        }
        lock.unlock()
    }
    private func readHangs() {
        let n = Int(isim_hang_count())
        guard hangIndex < n else { return }
        var stack = [CChar](repeating: 0, count: 4096)
        for i in hangIndex..<n {
            var start = 0.0, duration = 0.0
            guard isim_hang_get(Int32(i), &start, &duration, &stack, Int32(stack.count)) != 0 else { continue }
            var d = _MXDiagData(kind: "hang", date: start + duration)
            d.value = duration
            d.frames = _MXDiagData.frames(String(cString: stack))
            d.signposts = signpostRecords(from: start, to: start + duration)
            lock.lock(); cur.hangs.append(duration); newDiags.append(d); lock.unlock()
        }
        hangIndex = n
    }
    /// launch over 2 s, a CPU exception (80 % of a core over 3 minutes), 1 GiB of writes in a run
    private func checkExceptions(now: Double, cpu: Double, writes: Double, launchMs: Double) {
        var stack = [CChar](repeating: 0, count: 4096)
        if !launchChecked, launchMs > 0 {
            launchChecked = true
            if launchMs >= 2000 {
                var d = _MXDiagData(kind: "launch", date: now); d.value = launchMs / 1000
                _ = isim_launch_stack(&stack, Int32(stack.count)); d.frames = _MXDiagData.frames(String(cString: stack))
                lock.lock(); newDiags.append(d); lock.unlock()
            }
        }
        cpuWindow.append((now, cpu)); cpuWindow.removeAll { now - $0.t > 180 }
        if !cpuReported, let first = cpuWindow.first, now - first.t >= 179, cpu - first.cpu >= 0.8 * (now - first.t) {
            cpuReported = true
            var d = _MXDiagData(kind: "cpu", date: now); d.value = cpu - first.cpu; d.value2 = now - first.t
            _ = isim_sample_main_stack(&stack, Int32(stack.count)); d.frames = _MXDiagData.frames(String(cString: stack))
            lock.lock(); newDiags.append(d); lock.unlock()
        }
        if !diskReported, writes >= 1024 * 1024 * 1024 {
            diskReported = true
            var d = _MXDiagData(kind: "disk", date: now); d.value = writes / 1_000_000
            _ = isim_sample_main_stack(&stack, Int32(stack.count)); d.frames = _MXDiagData.frames(String(cString: stack))
            lock.lock(); newDiags.append(d); lock.unlock()
        }
    }
    /// MetricKit signposts recorded between two times (around a hang)
    private func signpostRecords(from a: Double, to b: Double) -> [_MXSignpostRecordData] {
        var first = 0
        let end = isim_log_range(&first)
        var out: [_MXSignpostRecordData] = [], open: [String: (Double, String, String)] = [:]
        for seq in first..<end {
            var date = 0.0, meta: [Int32] = [0, 0, 0], ids: [UInt64] = [0, 0]
            var strs: [UnsafeMutablePointer<CChar>?] = [nil, nil, nil, nil, nil]
            let ok = meta.withUnsafeMutableBufferPointer { m in ids.withUnsafeMutableBufferPointer { i in
                strs.withUnsafeMutableBufferPointer { s in isim_log_get(seq, &date, m.baseAddress!, i.baseAddress!, s.baseAddress!) } } }
            let t = strs.map { p -> String in defer { free(p) }; return p.map { String(cString: $0) } ?? "" }
            guard ok != 0, meta[0] == 1, date <= b + 1 else { continue }
            let key = "\(t[1])\u{1}\(t[4])\u{1}\(ids[0])"
            switch meta[2] {
            case 1: open[key] = (date, t[1], t[4])
            case 2:
                if let o = open.removeValue(forKey: key), date >= a - 1 {
                    out.append(_MXSignpostRecordData(name: o.2, category: o.1, subsystem: t[0], begin: o.0, end: date, interval: true))
                }
            default: if date >= a - 1 { out.append(_MXSignpostRecordData(name: t[4], category: t[1], subsystem: t[0], begin: date, end: nil, interval: false)) }
            }
        }
        for (_, o) in open where o.0 <= b { out.append(_MXSignpostRecordData(name: o.2, category: o.1, subsystem: "", begin: o.0, end: nil, interval: true)) }
        return out
    }

    // MARK: extended launch
    func extendLaunch(_ id: String) throws {
        var u = [Double](repeating: 0, count: 8)
        _ = u.withUnsafeMutableBufferPointer { isim_resource_usage($0.baseAddress!) }
        lock.lock(); defer { lock.unlock() }
        if u[5] > 0 { throw MXMetricManagerError(code: .pastDeadline) }        // the first frame is drawn
        if extendedTasks[id] != nil { throw MXMetricManagerError(code: .duplicate) }
        if extendedTasks.count >= 3 { throw MXMetricManagerError(code: .maxCount) }
        extendedTasks[id] = Date().timeIntervalSince1970
    }
    func finishLaunch(_ id: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard extendedTasks.removeValue(forKey: id) != nil else { throw MXMetricManagerError(code: .invalidID) }
        if extendedTasks.isEmpty { cur.extendedMs.append((Date().timeIntervalSince1970 - cur.start) * 1000) }
    }

    // MARK: windows and saving
    func takeNewDiagnostics() -> [_MXDiagData] { lock.lock(); defer { lock.unlock() }; let d = newDiags; newDiags = []; return d }
    func takeStartup() -> ([_MXPayloadData], [_MXDiagData]) {
        lock.lock(); defer { lock.unlock() }
        let r = (startupMetrics, startupDiags); startupMetrics = []; startupDiags = []
        return r
    }
    /// this run since the last delivery
    func takeWindow() -> _MXPayloadData {
        tick()
        lock.lock(); defer { lock.unlock() }
        let w = Self.window(cur, base)
        base = cur
        return w
    }
    static func window(_ c: Counters, _ b: Counters) -> _MXPayloadData {
        var p = _MXPayloadData(begin: b.end > b.start ? b.end : c.start, end: c.end)      // since the last delivery, or the start
        p.appVersion = c.appVersion
        p.meta.pid = c.pid; p.meta.build = c.build
        p.cpuS = c.cpu - b.cpu; p.peakKB = c.peakKB
        let susp = Array(c.suspended.dropFirst(b.suspended.count))
        if !susp.isEmpty {
            let avg = susp.reduce(0, +) / Double(susp.count)
            p.suspendedKB = avg; p.suspendedN = susp.count
            p.suspendedSD = (susp.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(susp.count)).squareRoot()
        }
        p.launch = _MXPayloadData.buckets(Array(c.launchMs.dropFirst(b.launchMs.count)), width: 10)
        p.optimizedLaunch = p.launch
        p.resume = _MXPayloadData.buckets(Array(c.resumeMs.dropFirst(b.resumeMs.count)), width: 10)
        p.extendedLaunch = _MXPayloadData.buckets(Array(c.extendedMs.dropFirst(b.extendedMs.count)), width: 10)
        p.hangs = _MXPayloadData.buckets(Array(c.hangs.dropFirst(b.hangs.count)), width: 0.1)
        p.fg = c.fg - b.fg; p.bg = c.bg - b.bg; p.bgAudio = c.bgAudio - b.bgAudio; p.bgLocation = c.bgLocation - b.bgLocation
        p.writesKB = (c.writes - b.writes) / 1000
        p.wifiUpKB = (c.up - b.up) / 1000; p.wifiDownKB = (c.down - b.down) / 1000
        p.location = zip(c.loc, b.loc).map { $0 - $1 }
        p.hitchRatio = p.fg > 0 ? (c.hitch - b.hitch) * 1000 / p.fg : 0
        let aplN = c.aplN - b.aplN
        if aplN > 0 { p.apl = (c.aplSum - b.aplSum) / aplN; p.aplN = Int(aplN) }
        p.signposts = c.signposts.keys.sorted().compactMap { k in
            let v = c.signposts[k]!, old = b.signposts[k] ?? SignpostAgg()
            let n = v.count - old.count
            guard n > 0 else { return nil }
            let parts = k.components(separatedBy: "\u{1}")
            return _MXSignpostData(name: parts.last ?? k, category: parts.first ?? "", count: n,
                                   durations: _MXPayloadData.buckets(Array(v.durationsMs.dropFirst(old.durationsMs.count)), width: 10),
                                   cpuMs: nil, memKB: nil, writesKB: nil, hitchRatio: nil)
        }
        return p
    }
    func save() {
        lock.lock()
        let saved = Saved(current: cur, base: base, diags: newDiags + startupDiags)
        let pending = startupMetrics                           // not yet delivered: kept for the next launch
        lastSave = Date().timeIntervalSince1970
        lock.unlock()
        if let d = try? JSONEncoder().encode(saved) { try? d.write(to: Self.runFile, options: .atomic) }
        if pending.isEmpty { try? FileManager.default.removeItem(at: Self.pendingFile) }
        else if let d = try? JSONEncoder().encode(pending) { try? d.write(to: Self.pendingFile, options: .atomic) }
    }
}
