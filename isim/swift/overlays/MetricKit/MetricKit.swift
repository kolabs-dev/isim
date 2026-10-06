// isim MetricKit. Like the iOS Simulator, isim never measures an app's real energy, launch, hang or crash
// metrics and nothing arrives by itself: subscribers receive payloads only when you ask for them, like Xcode's
// Debug > Simulate MetricKit Payloads:
//   - the `metrickit` script/control command (ISIM_SCRIPT="...; metrickit; ..."), or
//   - `isim metrickit` from another terminal while the app runs.
// Both write $ISIM_DATA/Library/isim/MetricKitTrigger; every running app with a subscriber notices the change
// (polled every 0.5 s) and delivers one sample MXMetricPayload and one sample MXDiagnosticPayload (a crash, a hang,
// a CPU exception, a disk-write exception, a slow launch) to each subscriber on the main queue. The values are
// fixed sample data (clearly not measurements). pastPayloads / pastDiagnosticPayloads are empty, like the Simulator.
import Foundation
import os

// MARK: - Base

open class MXMetric: NSObject {
    /// the metric as Apple-style JSON (keys and "value unit" strings)
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] { [:] }
    @available(*, deprecated, renamed: "dictionaryRepresentation()")
    open func DictionaryRepresentation() -> [AnyHashable: Any] { dictionaryRepresentation() }
}

enum _MX {
    static func json(_ d: [AnyHashable: Any]) -> Data {
        let obj = (d as NSDictionary)
        return (try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
    }
    static func m<U: Unit>(_ v: Measurement<U>) -> String {
        let n = v.value == v.value.rounded() && abs(v.value) < 1e15 ? String(Int(v.value)) : String(v.value)
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
    public var totalBucketCount: Int { buckets.count }
    public var bucketEnumerator: NSEnumerator { (buckets as NSArray).objectEnumerator() }
    /// isim convenience mirroring the enumerator (Swift code usually iterates `bucketEnumerator`)
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
    public let cumulativeCPUTime = Measurement(value: 100, unit: UnitDuration.seconds)
    public let cumulativeCPUInstructions = Measurement(value: 100, unit: Unit(symbol: "kiloinstructions"))
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeCPUTime": _MX.m(cumulativeCPUTime), "cumulativeCPUInstructions": _MX.m(cumulativeCPUInstructions)]
    }
}
open class MXGPUMetric: MXMetric {
    public let cumulativeGPUTime = Measurement(value: 20, unit: UnitDuration.seconds)
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["cumulativeGPUTime": _MX.m(cumulativeGPUTime)] }
}
open class MXMemoryMetric: MXMetric {
    public let peakMemoryUsage = Measurement(value: 200000, unit: UnitInformationStorage.kilobytes)
    public let averageSuspendedMemory = MXAverage(Measurement(value: 100000, unit: UnitInformationStorage.kilobytes), 500, 0)
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["peakMemoryUsage": _MX.m(peakMemoryUsage), "averageSuspendedMemory": averageSuspendedMemory.dictionary]
    }
}
open class MXAppLaunchMetric: MXMetric {
    public let histogrammedTimeToFirstDraw = MXHistogram([
        MXHistogramBucket(Measurement(value: 1000, unit: UnitDuration.milliseconds), Measurement(value: 1010, unit: UnitDuration.milliseconds), 50),
        MXHistogramBucket(Measurement(value: 2000, unit: UnitDuration.milliseconds), Measurement(value: 2010, unit: UnitDuration.milliseconds), 60),
        MXHistogramBucket(Measurement(value: 3000, unit: UnitDuration.milliseconds), Measurement(value: 3010, unit: UnitDuration.milliseconds), 30)])
    public let histogrammedApplicationResumeTime = MXHistogram([
        MXHistogramBucket(Measurement(value: 200, unit: UnitDuration.milliseconds), Measurement(value: 210, unit: UnitDuration.milliseconds), 60),
        MXHistogramBucket(Measurement(value: 300, unit: UnitDuration.milliseconds), Measurement(value: 310, unit: UnitDuration.milliseconds), 70)])
    public let histogrammedOptimizedTimeToFirstDraw = MXHistogram([
        MXHistogramBucket(Measurement(value: 1000, unit: UnitDuration.milliseconds), Measurement(value: 1010, unit: UnitDuration.milliseconds), 50)])
    public let histogrammedExtendedLaunch = MXHistogram([
        MXHistogramBucket(Measurement(value: 1500, unit: UnitDuration.milliseconds), Measurement(value: 1510, unit: UnitDuration.milliseconds), 20)])
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["histogrammedTimeToFirstDrawKey": histogrammedTimeToFirstDraw.dictionary, "histogrammedResumeTime": histogrammedApplicationResumeTime.dictionary,
         "histogrammedOptimizedTimeToFirstDrawKey": histogrammedOptimizedTimeToFirstDraw.dictionary, "histogrammedExtendedLaunch": histogrammedExtendedLaunch.dictionary]
    }
}
open class MXAppResponsivenessMetric: MXMetric {
    public let histogrammedApplicationHangTime = MXHistogram([
        MXHistogramBucket(Measurement(value: 0, unit: UnitDuration.seconds), Measurement(value: 100, unit: UnitDuration.seconds), 50),
        MXHistogramBucket(Measurement(value: 100, unit: UnitDuration.seconds), Measurement(value: 400, unit: UnitDuration.seconds), 60)])
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["histogrammedAppHangTime": histogrammedApplicationHangTime.dictionary] }
}
open class MXAppRunTimeMetric: MXMetric {
    public let cumulativeForegroundTime = Measurement(value: 700, unit: UnitDuration.seconds)
    public let cumulativeBackgroundTime = Measurement(value: 40, unit: UnitDuration.seconds)
    public let cumulativeBackgroundAudioTime = Measurement(value: 30, unit: UnitDuration.seconds)
    public let cumulativeBackgroundLocationTime = Measurement(value: 30, unit: UnitDuration.seconds)
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeForegroundTime": _MX.m(cumulativeForegroundTime), "cumulativeBackgroundTime": _MX.m(cumulativeBackgroundTime),
         "cumulativeBackgroundAudioTime": _MX.m(cumulativeBackgroundAudioTime), "cumulativeBackgroundLocationTime": _MX.m(cumulativeBackgroundLocationTime)]
    }
}
open class MXDiskIOMetric: MXMetric {
    public let cumulativeLogicalWrites = Measurement(value: 1300, unit: UnitInformationStorage.kilobytes)
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["cumulativeLogicalWrites": _MX.m(cumulativeLogicalWrites)] }
}
open class MXNetworkTransferMetric: MXMetric {
    public let cumulativeWifiUpload = Measurement(value: 100000, unit: UnitInformationStorage.kilobytes)
    public let cumulativeWifiDownload = Measurement(value: 100000, unit: UnitInformationStorage.kilobytes)
    public let cumulativeCellularUpload = Measurement(value: 60000, unit: UnitInformationStorage.kilobytes)
    public let cumulativeCellularDownload = Measurement(value: 60000, unit: UnitInformationStorage.kilobytes)
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeWifiUpload": _MX.m(cumulativeWifiUpload), "cumulativeWifiDownload": _MX.m(cumulativeWifiDownload),
         "cumulativeCellularUpload": _MX.m(cumulativeCellularUpload), "cumulativeCellularDownload": _MX.m(cumulativeCellularDownload)]
    }
}
open class MXForegroundExitData: NSObject {
    public let cumulativeNormalAppExitCount = 1
    public let cumulativeMemoryResourceLimitExitCount = 1
    public let cumulativeBadAccessExitCount = 1
    public let cumulativeAbnormalExitCount = 1
    public let cumulativeIllegalInstructionExitCount = 1
    public let cumulativeAppWatchdogExitCount = 1
    var dictionary: [AnyHashable: Any] {
        ["cumulativeNormalAppExitCount": 1, "cumulativeMemoryResourceLimitExitCount": 1, "cumulativeBadAccessExitCount": 1,
         "cumulativeAbnormalExitCount": 1, "cumulativeIllegalInstructionExitCount": 1, "cumulativeAppWatchdogExitCount": 1]
    }
}
open class MXBackgroundExitData: NSObject {
    public let cumulativeNormalAppExitCount = 1
    public let cumulativeMemoryResourceLimitExitCount = 1
    public let cumulativeCPUResourceLimitExitCount = 1
    public let cumulativeMemoryPressureExitCount = 1
    public let cumulativeBadAccessExitCount = 1
    public let cumulativeAbnormalExitCount = 1
    public let cumulativeIllegalInstructionExitCount = 1
    public let cumulativeAppWatchdogExitCount = 1
    public let cumulativeSuspendedWithLockedFileExitCount = 1
    public let cumulativeBackgroundTaskAssertionTimeoutExitCount = 1
    var dictionary: [AnyHashable: Any] {
        ["cumulativeNormalAppExitCount": 1, "cumulativeMemoryResourceLimitExitCount": 1, "cumulativeCPUResourceLimitExitCount": 1,
         "cumulativeMemoryPressureExitCount": 1, "cumulativeBadAccessExitCount": 1, "cumulativeAbnormalExitCount": 1,
         "cumulativeIllegalInstructionExitCount": 1, "cumulativeAppWatchdogExitCount": 1, "cumulativeSuspendedWithLockedFileExitCount": 1,
         "cumulativeBackgroundTaskAssertionTimeoutExitCount": 1]
    }
}
open class MXAppExitMetric: MXMetric {
    public let foregroundExitData = MXForegroundExitData()
    public let backgroundExitData = MXBackgroundExitData()
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["foregroundExitData": foregroundExitData.dictionary, "backgroundExitData": backgroundExitData.dictionary]
    }
}
open class MXCellularConditionMetric: MXMetric {
    public let histogrammedCellularConditionTime = MXHistogram([
        MXHistogramBucket(Measurement(value: 1, unit: Unit(symbol: "bars")), Measurement(value: 1, unit: Unit(symbol: "bars")), 20),
        MXHistogramBucket(Measurement(value: 2, unit: Unit(symbol: "bars")), Measurement(value: 2, unit: Unit(symbol: "bars")), 30),
        MXHistogramBucket(Measurement(value: 3, unit: Unit(symbol: "bars")), Measurement(value: 3, unit: Unit(symbol: "bars")), 50)])
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["cellConditionTime": histogrammedCellularConditionTime.dictionary] }
}
open class MXLocationActivityMetric: MXMetric {
    public let cumulativeBestAccuracyTime = Measurement(value: 20, unit: UnitDuration.seconds)
    public let cumulativeBestAccuracyForNavigationTime = Measurement(value: 20, unit: UnitDuration.seconds)
    public let cumulativeNearestTenMetersAccuracyTime = Measurement(value: 20, unit: UnitDuration.seconds)
    public let cumulativeHundredMetersAccuracyTime = Measurement(value: 20, unit: UnitDuration.seconds)
    public let cumulativeKilometerAccuracyTime = Measurement(value: 20, unit: UnitDuration.seconds)
    public let cumulativeThreeKilometersAccuracyTime = Measurement(value: 20, unit: UnitDuration.seconds)
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["cumulativeBestAccuracyTime": _MX.m(cumulativeBestAccuracyTime), "cumulativeBestAccuracyForNavigationTime": _MX.m(cumulativeBestAccuracyForNavigationTime),
         "cumulativeNearestTenMetersAccuracyTime": _MX.m(cumulativeNearestTenMetersAccuracyTime), "cumulativeHundredMetersAccuracyTime": _MX.m(cumulativeHundredMetersAccuracyTime),
         "cumulativeKilometerAccuracyTime": _MX.m(cumulativeKilometerAccuracyTime), "cumulativeThreeKilometersAccuracyTime": _MX.m(cumulativeThreeKilometersAccuracyTime)]
    }
}
open class MXAnimationMetric: MXMetric {
    public let scrollHitchTimeRatio = Measurement(value: 1, unit: Unit(symbol: "ms per s"))
    open override func dictionaryRepresentation() -> [AnyHashable: Any] { ["scrollHitchTimeRatio": _MX.m(scrollHitchTimeRatio)] }
}
open class MXSignpostIntervalData: NSObject {
    public let histogrammedSignpostDuration = MXHistogram([
        MXHistogramBucket(Measurement(value: 0, unit: UnitDuration.milliseconds), Measurement(value: 100, unit: UnitDuration.milliseconds), 50)])
    public let cumulativeCPUTime: Measurement<UnitDuration>? = Measurement(value: 100, unit: UnitDuration.milliseconds)
    public let averageMemory: MXAverage<UnitInformationStorage>? = MXAverage(Measurement(value: 100000, unit: UnitInformationStorage.kilobytes), 100, 0)
    public let cumulativeLogicalWrites: Measurement<UnitInformationStorage>? = Measurement(value: 600, unit: UnitInformationStorage.kilobytes)
    public let cumulativeHitchTimeRatio: Measurement<Unit>? = nil
}
open class MXSignpostMetric: MXMetric {
    public let signpostName: String
    public let signpostCategory: String
    public let totalCount: Int
    public let signpostIntervalData: MXSignpostIntervalData?
    init(name: String, category: String, count: Int) { signpostName = name; signpostCategory = category; totalCount = count; signpostIntervalData = MXSignpostIntervalData() }
    open override func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["signpostName": signpostName, "signpostCategory": signpostCategory, "totalSignpostCount": totalCount,
         "signpostIntervalData": ["histogrammedSignpostDurations": signpostIntervalData?.histogrammedSignpostDuration.dictionary ?? [:]]]
    }
}

open class MXMetaData: NSObject {
    public let regionFormat = Locale.current.regionCode ?? "US"
    public let osVersion = "iOS \(_MX.osVersion) (isim)"
    public let deviceType = _MX.device
    public let applicationBuildVersion = _MX.buildVersion
    public let platformArchitecture = "x86_64"
    public let lowPowerModeEnabled = false
    public let isTestFlightApp = false
    public let pid = ProcessInfo.processInfo.processIdentifier
    public let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["regionFormat": regionFormat, "osVersion": osVersion, "deviceType": deviceType, "appBuildVersion": applicationBuildVersion,
         "platformArchitecture": platformArchitecture, "lowPowerModeEnabled": lowPowerModeEnabled, "isTestFlightApp": isTestFlightApp,
         "pid": Int(pid), "bundleIdentifier": bundleIdentifier]
    }
}

// MARK: - Payloads

open class MXMetricPayload: NSObject {
    public let latestApplicationVersion = _MX.appVersion
    public let includesMultipleApplicationVersions = false
    public let timeStampBegin: Date
    public let timeStampEnd: Date
    public let cpuMetrics: MXCPUMetric? = MXCPUMetric()
    public let gpuMetrics: MXGPUMetric? = MXGPUMetric()
    public let cellularConditionMetrics: MXCellularConditionMetric? = MXCellularConditionMetric()
    public let applicationTimeMetrics: MXAppRunTimeMetric? = MXAppRunTimeMetric()
    public let locationActivityMetrics: MXLocationActivityMetric? = MXLocationActivityMetric()
    public let networkTransferMetrics: MXNetworkTransferMetric? = MXNetworkTransferMetric()
    public let applicationLaunchMetrics: MXAppLaunchMetric? = MXAppLaunchMetric()
    public let applicationResponsivenessMetrics: MXAppResponsivenessMetric? = MXAppResponsivenessMetric()
    public let diskIOMetrics: MXDiskIOMetric? = MXDiskIOMetric()
    public let memoryMetrics: MXMemoryMetric? = MXMemoryMetric()
    public let displayMetrics: MXMetric? = nil
    public let animationMetrics: MXAnimationMetric? = MXAnimationMetric()
    public let applicationExitMetrics: MXAppExitMetric? = MXAppExitMetric()
    public let signpostMetrics: [MXSignpostMetric]? = [MXSignpostMetric(name: "TestSignpostName1", category: "TestSignpostCategory1", count: 30)]
    public let metaData: MXMetaData? = MXMetaData()
    init(end: Date) { timeStampEnd = end; timeStampBegin = end.addingTimeInterval(-86400) }

    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        var d: [AnyHashable: Any] = ["appVersion": latestApplicationVersion, "multipleAppVersions": includesMultipleApplicationVersions,
                                     "timeStampBegin": _MX.date(timeStampBegin), "timeStampEnd": _MX.date(timeStampEnd)]
        let parts: [(String, MXMetric?)] = [("cpuMetrics", cpuMetrics), ("gpuMetrics", gpuMetrics), ("cellularConditionMetrics", cellularConditionMetrics),
            ("applicationTimeMetrics", applicationTimeMetrics), ("locationActivityMetrics", locationActivityMetrics),
            ("networkTransferMetrics", networkTransferMetrics), ("applicationLaunchMetrics", applicationLaunchMetrics),
            ("applicationResponsivenessMetrics", applicationResponsivenessMetrics), ("diskIOMetrics", diskIOMetrics),
            ("memoryMetrics", memoryMetrics), ("animationMetrics", animationMetrics), ("applicationExitMetrics", applicationExitMetrics)]
        for (k, m) in parts { if let m { d[k] = m.dictionaryRepresentation() } }
        if let s = signpostMetrics { d["signpostMetrics"] = s.map { $0.dictionaryRepresentation() } }
        if let md = metaData { d["metaData"] = md.dictionaryRepresentation() }
        return d
    }
    @available(*, deprecated, renamed: "dictionaryRepresentation()")
    open func DictionaryRepresentation() -> [AnyHashable: Any] { dictionaryRepresentation() }
}

open class MXCallStackTree: NSObject {
    let threads: [[String: Any]]
    init(frames: [String]) {
        var sub: [String: Any]? = nil
        for (i, name) in frames.enumerated().reversed() {
            var f: [String: Any] = ["binaryUUID": "00000000-0000-0000-0000-000000000000", "offsetIntoBinaryTextSegment": 1000 + i * 64,
                                    "sampleCount": 20, "binaryName": name, "address": 74565 + i * 64]
            if let s = sub { f["subFrames"] = [s] }
            sub = f
        }
        threads = [["threadAttributed": true, "callStackRootFrames": sub.map { [$0] } ?? []]]
    }
    open func jsonRepresentation() -> Data { _MX.json(dictionary) }
    var dictionary: [AnyHashable: Any] { ["callStackPerThread": true, "callStacks": threads] }
}

open class MXDiagnostic: NSObject {
    public let metaData = MXMetaData()
    public let applicationVersion = _MX.appVersion
    public let signpostData: [Any]? = nil
    public let callStackTree: MXCallStackTree
    init(_ frames: [String]) { callStackTree = MXCallStackTree(frames: frames) }
    open func jsonRepresentation() -> Data { _MX.json(dictionaryRepresentation()) }
    open func dictionaryRepresentation() -> [AnyHashable: Any] {
        ["version": "1.0.0", "callStackTree": callStackTree.dictionary, "diagnosticMetaData": metaData.dictionaryRepresentation().merging(extra) { a, _ in a }]
    }
    var extra: [AnyHashable: Any] { ["appVersion": applicationVersion] }
}
open class MXCrashDiagnosticObjectiveCExceptionReason: NSObject {
    public let composedMessage = "*** -[__NSArrayM objectAtIndex:]: index 3 beyond bounds [0 .. 1]"
    public let formatString = "*** -[%s %s]: index %lu beyond bounds [0 .. %lu]"
    public let arguments = ["__NSArrayM", "objectAtIndex:", "3", "1"]
    public let exceptionType = "NSRangeException"
    public let className = "NSException"
    public let exceptionName = "NSRangeException"
}
open class MXCrashDiagnostic: MXDiagnostic {
    public let terminationReason: String? = "Namespace SIGNAL, Code 0xb"
    public let virtualMemoryRegionInfo: String? = "0 is not in any region. Bytes before following region: 4000000000 REGION TYPE START - END [ VSIZE] PRT/MAX SHRMOD REGION DETAIL UNUSED SPACE AT START ---> __TEXT 0000000000000000-0000000000000000 [ 32K] r-x/r-x SM=COW ...pp/Test"
    public let exceptionType: NSNumber? = 1      // EXC_BAD_ACCESS
    public let exceptionCode: NSNumber? = 0
    public let signal: NSNumber? = 11              // SIGSEGV
    public let exceptionReason: MXCrashDiagnosticObjectiveCExceptionReason? = MXCrashDiagnosticObjectiveCExceptionReason()
    override var extra: [AnyHashable: Any] {
        ["appVersion": applicationVersion, "terminationReason": terminationReason ?? "", "virtualMemoryRegionInfo": virtualMemoryRegionInfo ?? "",
         "exceptionType": 1, "exceptionCode": 0, "signal": 11,
         "objectiveCexceptionReason": ["composedMessage": exceptionReason?.composedMessage ?? "", "exceptionType": "NSRangeException", "className": "NSException"]]
    }
}
open class MXHangDiagnostic: MXDiagnostic {
    public let hangDuration = Measurement(value: 20, unit: UnitDuration.seconds)
    override var extra: [AnyHashable: Any] { ["appVersion": applicationVersion, "hangDuration": _MX.m(hangDuration)] }
}
open class MXCPUExceptionDiagnostic: MXDiagnostic {
    public let totalCPUTime = Measurement(value: 20, unit: UnitDuration.seconds)
    public let totalSampledTime = Measurement(value: 20, unit: UnitDuration.seconds)
    override var extra: [AnyHashable: Any] { ["appVersion": applicationVersion, "totalCPUTime": _MX.m(totalCPUTime), "totalSampledTime": _MX.m(totalSampledTime)] }
}
open class MXDiskWriteExceptionDiagnostic: MXDiagnostic {
    public let totalWritesCaused = Measurement(value: 2000, unit: UnitInformationStorage.megabytes)
    override var extra: [AnyHashable: Any] { ["appVersion": applicationVersion, "writesCaused": _MX.m(totalWritesCaused)] }
}
open class MXAppLaunchDiagnostic: MXDiagnostic {
    public let launchDuration = Measurement(value: 15, unit: UnitDuration.seconds)
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
    init(end: Date) {
        timeStampEnd = end; timeStampBegin = end
        let exe = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? "App"
        crashDiagnostics = [MXCrashDiagnostic([exe, "UIKitCore", "libdyld.dylib"])]
        hangDiagnostics = [MXHangDiagnostic([exe, "UIKitCore"])]
        cpuExceptionDiagnostics = [MXCPUExceptionDiagnostic([exe])]
        diskWriteExceptionDiagnostics = [MXDiskWriteExceptionDiagnostic([exe, "libsystem_kernel.dylib"])]
        appLaunchDiagnostics = [MXAppLaunchDiagnostic([exe, "dyld"])]
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
    nonisolated(unsafe) public static let shared = MXMetricManager()
    private struct Weak { weak var s: MXMetricManagerSubscriber? }
    private var subscribers: [Weak] = []
    private var timer: Timer?
    private var lastTrigger: String?
    private let lock = NSLock()

    static var triggerPath: String {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return (data as NSString).appendingPathComponent("Library/isim/MetricKitTrigger")
    }
    private override init() {
        lastTrigger = try? String(contentsOfFile: MXMetricManager.triggerPath, encoding: .utf8)
        super.init()
    }

    /// like the Simulator: no history
    public var pastPayloads: [MXMetricPayload] { [] }
    public var pastDiagnosticPayloads: [MXDiagnosticPayload] { [] }

    public func add(_ subscriber: MXMetricManagerSubscriber) {
        lock.lock(); defer { lock.unlock() }
        subscribers.removeAll { $0.s == nil || $0.s === subscriber }
        subscribers.append(Weak(s: subscriber))
        if timer == nil {
            DispatchQueue.main.async { self.startPolling() }
        }
    }
    public func remove(_ subscriber: MXMetricManagerSubscriber) {
        lock.lock(); defer { lock.unlock() }
        subscribers.removeAll { $0.s == nil || $0.s === subscriber }
    }

    public class func makeLogHandle(category: String) -> OSLog {
        OSLog(subsystem: Bundle.main.bundleIdentifier ?? "MetricKit", category: category)
    }
    /// iOS 16 extended launch measurement: accepted (nothing is measured on isim)
    public class func extendLaunchMeasurement(forTaskID taskID: String) throws {}
    public class func finishExtendedLaunchMeasurement(forTaskID taskID: String) throws {}

    private func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
    }
    private func poll() {
        let now = try? String(contentsOfFile: MXMetricManager.triggerPath, encoding: .utf8)
        guard let now, now != lastTrigger else { return }
        lastTrigger = now
        deliverSimulatedPayloads()
    }

    /// what Xcode's Debug > Simulate MetricKit Payloads does: one metric and one diagnostic payload per subscriber
    public func deliverSimulatedPayloads() {
        lock.lock(); let subs = subscribers.compactMap { $0.s }; lock.unlock()
        NSLog("isim MetricKit: delivering simulated payloads to %d subscriber(s) (sample data, not measurements)", subs.count)
        let end = Date()
        for s in subs {
            s.didReceive?([MXMetricPayload(end: end)])
            s.didReceive?([MXDiagnosticPayload(end: end)])
        }
    }
}
