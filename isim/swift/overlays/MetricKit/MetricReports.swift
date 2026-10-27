// isim MetricKit, iOS 27's Swift API (adapted): MetricManager hands out the same measurements as MXMetricManager
// (MetricKit.swift: what isim measures and when it delivers) as MetricReports and DiagnosticReports, through async
// sequences instead of a subscriber:
//   - a MetricReport per metric payload: its values (MetricResult) in one interval entry covering the report's time
//     range, with the states (StateReporting) the app was in; a state entry per state of an enabled domain, with the
//     CPU time and logical writes measured while the app was in it;
//   - a DiagnosticReport per diagnostic (crash, hang, CPU and disk-write exceptions, slow launch); a diagnostic made
//     in this process carries the states the enabled domains are in.
// Self-authored, iOS API names. Not measured on isim (left out of the values): Metal frame rates; GPU time is 0 and
// instructions are not counted (as in MXMetricPayload).
import Foundation
import os
import StateReporting

// MARK: - Identifiers

@available(iOS 27.0, *)
/// A domain StateReporting reports states for ("com.example.app.screen"), as MetricManager enables it.
public struct StateReportingDomain: Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    let name: String
    public init(_ name: String) { self.name = name }
    public init(stringLiteral value: String) { name = value }
    public init(from decoder: any Decoder) throws { name = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(name) }
    public var description: String { name }
}

@available(iOS 27.0, *)
/// The identifier of a launch task MetricManager.trackLaunchTask measures.
public struct LaunchTaskID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
}

// MARK: - Units and statistics

@available(iOS 27.0, *)
/// signal bars (cellular condition histograms)
public final class SignalBars: Dimension, @unchecked Sendable {
    static let bars = SignalBars(symbol: "bars", converter: UnitConverterLinear(coefficient: 1))
    public override class func baseUnit() -> SignalBars { bars }
}
@available(iOS 27.0, *)
/// hitch time per animation time (ms per s)
public final class HitchTimeRatio: Dimension, @unchecked Sendable {
    static let msPerS = HitchTimeRatio(symbol: "ms per s", converter: UnitConverterLinear(coefficient: 1))
    public override class func baseUnit() -> HitchTimeRatio { msPerS }
}
@available(iOS 27.0, *)
/// average pixel luminance, 0 (black) to 100 (white)
public final class AveragePixelLuminance: Dimension, @unchecked Sendable {
    static let apl = AveragePixelLuminance(symbol: "apl", converter: UnitConverterLinear(coefficient: 1))
    public override class func baseUnit() -> AveragePixelLuminance { apl }
}

@available(iOS 27.0, *)
/// A histogram of measurements: its buckets, lowest first.
public struct Histogram<DimensionType: Dimension>: Hashable, Sendable, Codable {
    public struct Bucket: Hashable, Sendable, Codable {
        public let count: Int
        public let lowerBound: Measurement<DimensionType>
        public let upperBound: Measurement<DimensionType>
    }
    public let buckets: [Bucket]
    init(_ data: [_MXBucket], _ unit: DimensionType) {
        buckets = data.map { Bucket(count: $0.count, lowerBound: Measurement(value: $0.start, unit: unit), upperBound: Measurement(value: $0.end, unit: unit)) }
    }
}

@available(iOS 27.0, *)
/// An average of samples.
public struct AverageStatistics<DimensionType: Dimension>: Hashable, Sendable, Codable {
    public let average: Measurement<DimensionType>
    public let count: Int
    public let standardDeviation: Double?
}

// MARK: - Metrics

@available(iOS 27.0, *)
public struct HangTimeMetric: Hashable, Sendable, Codable { public let histogram: Histogram<UnitDuration> }
@available(iOS 27.0, *)
public struct HitchTimeMetric: Hashable, Sendable, Codable {
    public let ratio: Measurement<HitchTimeRatio>
    public let totalHitchTime: Measurement<UnitDuration>
    public let totalAnimationTime: Measurement<UnitDuration>
}
@available(iOS 27.0, *)
public struct ForegroundTerminationMetric: Hashable, Sendable, Codable {
    public let normalTerminationCount: Int
    public let memoryLimitTerminationCount: Int
    public let badAccessTerminationCount: Int
    public let abnormalTerminationCount: Int
    public let illegalInstructionTerminationCount: Int
    public let watchdogTerminationCount: Int
}
@available(iOS 27.0, *)
public struct BackgroundTerminationMetric: Hashable, Sendable, Codable {
    public let normalTerminationCount: Int
    public let memoryLimitTerminationCount: Int
    public let highCPUTerminationCount: Int
    public let systemPressureTerminationCount: Int
    public let badAccessTerminationCount: Int
    public let abnormalTerminationCount: Int
    public let illegalInstructionTerminationCount: Int
    public let watchdogTerminationCount: Int
    public let fileLockTerminationCount: Int
    public let taskTimeoutTerminationCount: Int
}
@available(iOS 27.0, *)
public struct TotalForegroundTimeMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitDuration> }
@available(iOS 27.0, *)
public struct TotalBackgroundTimeMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitDuration> }
@available(iOS 27.0, *)
public struct TotalBackgroundAudioTimeMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitDuration> }
@available(iOS 27.0, *)
public struct TotalBackgroundLocationTimeMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitDuration> }
@available(iOS 27.0, *)
public struct LocationActivityTimeMetric: Hashable, Sendable, Codable {
    public let bestAccuracyForNavigation: Measurement<UnitDuration>
    public let bestAccuracy: Measurement<UnitDuration>
    public let tenMeters: Measurement<UnitDuration>
    public let oneHundredMeter: Measurement<UnitDuration>
    public let oneKilometer: Measurement<UnitDuration>
    public let threeKilometers: Measurement<UnitDuration>
    public let reducedAccuracy: Measurement<UnitDuration>
}
@available(iOS 27.0, *)
public struct SignpostIntervalMetric: Hashable, Sendable, Codable {
    public let signpostName: String
    public let signpostCategory: String
    public let totalCount: Int
    public let signpostDuration: Histogram<UnitDuration>
    public let averageMemory: AverageStatistics<UnitInformationStorage>?
    public let cpuTime: Measurement<UnitDuration>?
    public let logicalWrites: Measurement<UnitInformationStorage>?
    public let hitchTimeRatio: Measurement<HitchTimeRatio>?
    public let totalHitchTime: Measurement<UnitDuration>?
    public let totalAnimationTime: Measurement<UnitDuration>?
}
@available(iOS 27.0, *)
public struct CPUTimeMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitDuration> }
@available(iOS 27.0, *)
public struct CPUInstructionsCountMetric: Hashable, Sendable, Codable { public let value: Int }
@available(iOS 27.0, *)
public struct PeakMemoryMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitInformationStorage> }
@available(iOS 27.0, *)
public struct SuspendedMemoryMetric: Hashable, Sendable, Codable { public let value: AverageStatistics<UnitInformationStorage> }
@available(iOS 27.0, *)
public struct TotalWiFiUploadMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitInformationStorage> }
@available(iOS 27.0, *)
public struct TotalWiFiDownloadMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitInformationStorage> }
@available(iOS 27.0, *)
public struct TotalCellularUploadMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitInformationStorage> }
@available(iOS 27.0, *)
public struct TotalCellularDownloadMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitInformationStorage> }
@available(iOS 27.0, *)
public struct CellularConditionTimeMetric: Hashable, Sendable, Codable { public let histogram: Histogram<SignalBars> }
@available(iOS 27.0, *)
public struct TimeToFirstDrawMetric: Hashable, Sendable, Codable { public let histogram: Histogram<UnitDuration> }
@available(iOS 27.0, *)
public struct ApplicationResumeTimeMetric: Hashable, Sendable, Codable { public let histogram: Histogram<UnitDuration> }
@available(iOS 27.0, *)
public struct OptimizedTimeToFirstDrawMetric: Hashable, Sendable, Codable { public let histogram: Histogram<UnitDuration> }
@available(iOS 27.0, *)
public struct ExtendedLaunchMetric: Hashable, Sendable, Codable { public let histogram: Histogram<UnitDuration> }
@available(iOS 27.0, *)
public struct LogicalDiskWritesMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitInformationStorage> }
@available(iOS 27.0, *)
public struct TotalFileCountMetric: Hashable, Sendable, Codable {
    public let binaryFileCount: Int
    public let dataFileCount: Int
}
@available(iOS 27.0, *)
public struct TotalFileSizeMetric: Hashable, Sendable, Codable {
    public let binaryFileSize: Measurement<UnitInformationStorage>
    public let cacheFolderSize: Measurement<UnitInformationStorage>
    public let cloneSize: Measurement<UnitInformationStorage>
    public let dataFileSize: Measurement<UnitInformationStorage>
}
@available(iOS 27.0, *)
public struct TotalDiskSpaceCapacityMetric: Hashable, Sendable, Codable {
    public let capacity: Measurement<UnitInformationStorage>
    public let spaceUsed: Measurement<UnitInformationStorage>
}
@available(iOS 27.0, *)
public struct PixelLuminanceMetric: Hashable, Sendable, Codable { public let value: AverageStatistics<AveragePixelLuminance> }
@available(iOS 27.0, *)
public struct GPUTimeMetric: Hashable, Sendable, Codable { public let value: Measurement<UnitDuration> }
@available(iOS 27.0, *)
public struct MetalFrameRateMetric: Hashable, Sendable, Codable {
    public let framesPerSecond: Measurement<UnitFrequency>
    public let frameCount: Int
    public let activeDrawingDuration: Measurement<UnitDuration>
    public let layerName: String
}

@available(iOS 27.0, *)
/// The kind of measurement a MetricResult is.
public struct MetricGroup: Hashable, Sendable, Codable, CustomStringConvertible {
    let name: String
    public var description: String { name }
    public static let cpu = MetricGroup(name: "cpu")
    public static let memory = MetricGroup(name: "memory")
    public static let diskIO = MetricGroup(name: "diskIO")
    public static let networkTransfer = MetricGroup(name: "networkTransfer")
    public static let display = MetricGroup(name: "display")
    public static let animation = MetricGroup(name: "animation")
    public static let applicationResponsiveness = MetricGroup(name: "applicationResponsiveness")
    public static let cellularCondition = MetricGroup(name: "cellularCondition")
    public static let locationActivity = MetricGroup(name: "locationActivity")
    public static let gpu = MetricGroup(name: "gpu")
    public static let signpost = MetricGroup(name: "signpost")
    public static let appLaunch = MetricGroup(name: "appLaunch")
    public static let appRuntime = MetricGroup(name: "appRuntime")
    public static let appTermination = MetricGroup(name: "appTermination")
    public static let diskSpaceUsage = MetricGroup(name: "diskSpaceUsage")
    public static let frameStatistics = MetricGroup(name: "frameStatistics")
}

@available(iOS 27.0, *)
/// One measurement of a report.
public enum MetricResult: Hashable, Sendable, Codable {
    case hangTime(HangTimeMetric)
    case hitchTime(HitchTimeMetric)
    case foregroundTermination(ForegroundTerminationMetric)
    case backgroundTermination(BackgroundTerminationMetric)
    case totalForegroundTime(TotalForegroundTimeMetric)
    case totalBackgroundTime(TotalBackgroundTimeMetric)
    case totalBackgroundAudioTime(TotalBackgroundAudioTimeMetric)
    case totalBackgroundLocationTime(TotalBackgroundLocationTimeMetric)
    case locationActivityTime(LocationActivityTimeMetric)
    case signpostInterval(SignpostIntervalMetric)
    case cpuTime(CPUTimeMetric)
    case cpuInstructionsCount(CPUInstructionsCountMetric)
    case peakMemory(PeakMemoryMetric)
    case suspendedMemory(SuspendedMemoryMetric)
    case totalWiFiUpload(TotalWiFiUploadMetric)
    case totalWiFiDownload(TotalWiFiDownloadMetric)
    case totalCellularUpload(TotalCellularUploadMetric)
    case totalCellularDownload(TotalCellularDownloadMetric)
    case cellularConditionTime(CellularConditionTimeMetric)
    case timeToFirstDraw(TimeToFirstDrawMetric)
    case applicationResumeTime(ApplicationResumeTimeMetric)
    case optimizedTimeToFirstDraw(OptimizedTimeToFirstDrawMetric)
    case extendedLaunch(ExtendedLaunchMetric)
    case logicalDiskWrites(LogicalDiskWritesMetric)
    case totalFileCount(TotalFileCountMetric)
    case totalFileSize(TotalFileSizeMetric)
    case totalDiskSpaceCapacity(TotalDiskSpaceCapacityMetric)
    case pixelLuminance(PixelLuminanceMetric)
    case gpuTime(GPUTimeMetric)
    case metalFrameRate(MetalFrameRateMetric)

    public var metricGroup: MetricGroup {
        switch self {
        case .hangTime: return .applicationResponsiveness
        case .hitchTime: return .animation
        case .foregroundTermination, .backgroundTermination: return .appTermination
        case .totalForegroundTime, .totalBackgroundTime, .totalBackgroundAudioTime, .totalBackgroundLocationTime: return .appRuntime
        case .locationActivityTime: return .locationActivity
        case .signpostInterval: return .signpost
        case .cpuTime, .cpuInstructionsCount: return .cpu
        case .peakMemory, .suspendedMemory: return .memory
        case .totalWiFiUpload, .totalWiFiDownload, .totalCellularUpload, .totalCellularDownload: return .networkTransfer
        case .cellularConditionTime: return .cellularCondition
        case .timeToFirstDraw, .applicationResumeTime, .optimizedTimeToFirstDraw, .extendedLaunch: return .appLaunch
        case .logicalDiskWrites: return .diskIO
        case .totalFileCount, .totalFileSize, .totalDiskSpaceCapacity: return .diskSpaceUsage
        case .pixelLuminance: return .display
        case .gpuTime: return .gpu
        case .metalFrameRate: return .frameStatistics
        }
    }

    /// a payload's measurements as results
    static func results(_ d: _MXPayloadData) -> [MetricResult] {
        let s = UnitDuration.seconds, ms = UnitDuration.milliseconds, kb = UnitInformationStorage.kilobytes
        func dur(_ v: Double, _ u: UnitDuration = s) -> Measurement<UnitDuration> { Measurement(value: v, unit: u) }
        func size(_ v: Double) -> Measurement<UnitInformationStorage> { Measurement(value: v, unit: kb) }
        var r: [MetricResult] = [
            .cpuTime(CPUTimeMetric(value: dur(d.cpuS))),
            .cpuInstructionsCount(CPUInstructionsCountMetric(value: Int(d.instructionsK * 1000))),
            .gpuTime(GPUTimeMetric(value: dur(d.gpuS))),
            .peakMemory(PeakMemoryMetric(value: size(d.peakKB))),
        ]
        if d.suspendedN > 0 {
            r.append(.suspendedMemory(SuspendedMemoryMetric(value: AverageStatistics(average: size(d.suspendedKB), count: d.suspendedN, standardDeviation: d.suspendedSD))))
        }
        r += [.timeToFirstDraw(TimeToFirstDrawMetric(histogram: Histogram(d.launch, ms))),
              .optimizedTimeToFirstDraw(OptimizedTimeToFirstDrawMetric(histogram: Histogram(d.optimizedLaunch, ms))),
              .applicationResumeTime(ApplicationResumeTimeMetric(histogram: Histogram(d.resume, ms))),
              .extendedLaunch(ExtendedLaunchMetric(histogram: Histogram(d.extendedLaunch, ms))),
              .hangTime(HangTimeMetric(histogram: Histogram(d.hangs, s))),
              .hitchTime(HitchTimeMetric(ratio: Measurement(value: d.hitchRatio, unit: HitchTimeRatio.msPerS),
                                         totalHitchTime: dur(d.hitchRatio * d.fg, ms), totalAnimationTime: dur(d.fg))),
              .totalForegroundTime(TotalForegroundTimeMetric(value: dur(d.fg))),
              .totalBackgroundTime(TotalBackgroundTimeMetric(value: dur(d.bg))),
              .totalBackgroundAudioTime(TotalBackgroundAudioTimeMetric(value: dur(d.bgAudio))),
              .totalBackgroundLocationTime(TotalBackgroundLocationTimeMetric(value: dur(d.bgLocation))),
              .locationActivityTime(LocationActivityTimeMetric(bestAccuracyForNavigation: dur(d.location[0]), bestAccuracy: dur(d.location[1]),
                                                               tenMeters: dur(d.location[2]), oneHundredMeter: dur(d.location[3]),
                                                               oneKilometer: dur(d.location[4]), threeKilometers: dur(d.location[5]), reducedAccuracy: dur(0))),
              .logicalDiskWrites(LogicalDiskWritesMetric(value: size(d.writesKB))),
              .totalWiFiUpload(TotalWiFiUploadMetric(value: size(d.wifiUpKB))),
              .totalWiFiDownload(TotalWiFiDownloadMetric(value: size(d.wifiDownKB))),
              .totalCellularUpload(TotalCellularUploadMetric(value: size(d.cellUpKB))),
              .totalCellularDownload(TotalCellularDownloadMetric(value: size(d.cellDownKB)))]
        if let c = d.cellular { r.append(.cellularConditionTime(CellularConditionTimeMetric(histogram: Histogram(c, SignalBars.bars)))) }
        let f = d.exitsFG, b = d.exitsBG
        r.append(.foregroundTermination(ForegroundTerminationMetric(
            normalTerminationCount: f["normal"] ?? 0, memoryLimitTerminationCount: f["memoryLimit"] ?? 0, badAccessTerminationCount: f["badAccess"] ?? 0,
            abnormalTerminationCount: f["abnormal"] ?? 0, illegalInstructionTerminationCount: f["illegalInstruction"] ?? 0,
            watchdogTerminationCount: f["watchdog"] ?? 0)))
        r.append(.backgroundTermination(BackgroundTerminationMetric(
            normalTerminationCount: b["normal"] ?? 0, memoryLimitTerminationCount: b["memoryLimit"] ?? 0, highCPUTerminationCount: b["cpuLimit"] ?? 0,
            systemPressureTerminationCount: b["memoryPressure"] ?? 0, badAccessTerminationCount: b["badAccess"] ?? 0,
            abnormalTerminationCount: b["abnormal"] ?? 0, illegalInstructionTerminationCount: b["illegalInstruction"] ?? 0,
            watchdogTerminationCount: b["watchdog"] ?? 0, fileLockTerminationCount: b["lockedFile"] ?? 0, taskTimeoutTerminationCount: b["taskTimeout"] ?? 0)))
        if let apl = d.apl {
            r.append(.pixelLuminance(PixelLuminanceMetric(value: AverageStatistics(average: Measurement(value: apl, unit: AveragePixelLuminance.apl),
                                                                                  count: d.aplN, standardDeviation: nil))))
        }
        if let disk = d.disk {
            r.append(.totalFileCount(TotalFileCountMetric(binaryFileCount: disk.binCount, dataFileCount: disk.dataCount)))
            r.append(.totalFileSize(TotalFileSizeMetric(binaryFileSize: size(disk.binKB), cacheFolderSize: size(disk.cacheKB),
                                                        cloneSize: size(disk.cloneKB), dataFileSize: size(disk.dataKB))))
            r.append(.totalDiskSpaceCapacity(TotalDiskSpaceCapacityMetric(capacity: size(disk.capacityKB), spaceUsed: size(disk.usedKB))))
        }
        for sp in d.signposts {
            r.append(.signpostInterval(SignpostIntervalMetric(
                signpostName: sp.name, signpostCategory: sp.category, totalCount: sp.count, signpostDuration: Histogram(sp.durations, ms),
                averageMemory: sp.memKB.map { AverageStatistics(average: size($0), count: sp.count, standardDeviation: nil) },
                cpuTime: sp.cpuMs.map { dur($0, ms) }, logicalWrites: sp.writesKB.map { size($0) },
                hitchTimeRatio: sp.hitchRatio.map { Measurement(value: $0, unit: HitchTimeRatio.msPerS) }, totalHitchTime: nil, totalAnimationTime: nil)))
        }
        return r
    }
}

// MARK: - Reports

@available(iOS 27.0, *)
/// The OS a report comes from.
public struct OSVersion: Hashable, Sendable, Codable {
    public let buildNumber: String
    public let number: String
    public let platform: String
    static var current: OSVersion { OSVersion(buildNumber: "isim", number: _MX.osVersion, platform: "iOS") }
}

@available(iOS 27.0, *)
/// A signpost recorded around a diagnostic.
public struct SignpostRecord: Hashable, Sendable, Codable {
    public let subsystem: String
    public let category: String
    public let name: String
    public let interval: DateInterval
}

@available(iOS 27.0, *)
/// A day's (on isim: a run's, or this run's so far) measurements of the app.
public struct MetricReport: Sendable, Codable {
    public struct Environment: Hashable, Sendable, Codable {
        public let deviceType: String
        public let osVersion: OSVersion
        public let platformArchitecture: String
        public let regionFormat: String
        public let latestApplicationVersion: String
        public let includesMultipleApplicationVersions: Bool
        public let isTestFlightApp: Bool
        public let lowPowerModeEnabled: Bool
        public let hasExceededStateLimit: Bool
        public let applicationBuildVersion: String
        public let bundleIdentifier: String
    }
    /// The measurements of part of the report's time range, and the states the app was in then.
    public struct IntervalEntry: Sendable, Codable {
        public let duration: Measurement<UnitDuration>
        public let states: [MetricManager.ReportedState]
        public let values: [MetricResult]
    }
    /// The measurements taken while the app was in one state.
    public struct StateEntry: Sendable, Codable {
        public let state: MetricManager.ReportedState
        public let values: [MetricResult]
    }
    /// How a report encodes its state entries (the encoder's userInfo[MetricReport.encodingFormatKey]).
    public enum EncodingFormat: String, Hashable, Sendable, Codable {
        /// a list
        case `default`
        /// grouped by domain: {domain: [entry]}
        case byStateReportingDomain
    }
    public static let encodingFormatKey = CodingUserInfoKey(rawValue: "MetricReport.EncodingFormat")!

    public let timeRange: DateInterval
    public let environment: MetricReport.Environment?
    public let intervalEntries: [MetricReport.IntervalEntry]
    public let stateEntries: [MetricReport.StateEntry]

    init(_ d: _MXPayloadData, domains: Set<StateReportingDomain>) {
        timeRange = DateInterval(start: Date(timeIntervalSince1970: d.begin), end: Date(timeIntervalSince1970: max(d.begin, d.end)))
        let m = d.meta
        environment = Environment(deviceType: m.device, osVersion: .current, platformArchitecture: m.arch, regionFormat: m.region,
                                  latestApplicationVersion: d.appVersion, includesMultipleApplicationVersions: d.multipleVersions,
                                  isTestFlightApp: m.testFlight, lowPowerModeEnabled: m.lowPower, hasExceededStateLimit: false,
                                  applicationBuildVersion: m.build, bundleIdentifier: m.bundle)
        let states = (d.states ?? []).filter { domains.contains(StateReportingDomain($0.domain)) }
        let reported = states.map { MetricManager.ReportedState($0) }
        intervalEntries = [IntervalEntry(duration: Measurement(value: timeRange.duration, unit: .seconds), states: reported, values: MetricResult.results(d))]
        stateEntries = zip(states, reported).map { s, r in
            StateEntry(state: r, values: [.cpuTime(CPUTimeMetric(value: Measurement(value: s.cpu, unit: .seconds))),
                                          .logicalDiskWrites(LogicalDiskWritesMetric(value: Measurement(value: s.writesKB, unit: .kilobytes)))])
        }
    }

    enum CodingKeys: String, CodingKey { case timeRange, environment, intervalEntries, stateEntries }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timeRange = try c.decode(DateInterval.self, forKey: .timeRange)
        environment = try c.decodeIfPresent(Environment.self, forKey: .environment)
        intervalEntries = try c.decode([IntervalEntry].self, forKey: .intervalEntries)
        if let list = try? c.decode([StateEntry].self, forKey: .stateEntries) { stateEntries = list }
        else {                                                // EncodingFormat.byStateReportingDomain
            let groups = try c.decode([String: [StateEntry]].self, forKey: .stateEntries)
            stateEntries = groups.keys.sorted().flatMap { groups[$0]! }
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(timeRange, forKey: .timeRange)
        try c.encodeIfPresent(environment, forKey: .environment)
        try c.encode(intervalEntries, forKey: .intervalEntries)
        if encoder.userInfo[Self.encodingFormatKey] as? EncodingFormat == .byStateReportingDomain {
            try c.encode(Dictionary(uniqueKeysWithValues: stateEntries.byStateReportingDomain.map { ($0.key.name, $0.value) }), forKey: .stateEntries)
        } else {
            try c.encode(stateEntries, forKey: .stateEntries)
        }
    }
}

// MARK: - Diagnostics

@available(iOS 27.0, *)
/// The call stacks of a diagnostic: one thread on isim (the one that crashed or hung), its root frame the innermost.
public struct CallStackTree: Hashable, Sendable, Codable {
    public struct BinaryInfo: Hashable, Sendable, Codable {
        public let uuid: UUID
        public let name: String
    }
    public let callStackThreads: ContiguousArray<CallStackThread>
    public let callStackPerThread: Bool
    public let binaryInfo: [UUID: CallStackTree.BinaryInfo]

    init(_ frames: [_MXFrame]) {
        var sub: CallStackFrame? = nil
        var info: [UUID: BinaryInfo] = [:]
        for f in frames.reversed() {
            let uuid = UUID(uuidString: f.uuid)
            if let uuid { info[uuid] = BinaryInfo(uuid: uuid, name: f.binary) }
            sub = CallStackFrame(binaryUUID: uuid, address: f.address, offsetIntoBinaryTextSegment: f.offset, sampleCount: 1,
                                 subFrames: sub.map { [$0] } ?? [])
        }
        callStackThreads = [CallStackThread(rootFrames: sub.map { [$0] } ?? [], threadAttributed: true)]
        callStackPerThread = true
        binaryInfo = info
    }

    /// Every frame of every thread, each before its callers.
    public func forEachFrame(_ body: (CallStackFrame) throws -> Void) rethrows {
        func visit(_ f: CallStackFrame) throws { try body(f); for s in f.subFrames { try visit(s) } }
        for t in callStackThreads { for f in t.rootFrames { try visit(f) } }
    }
}
@available(iOS 27.0, *)
public struct CallStackThread: Hashable, Sendable, Codable {
    public let rootFrames: ContiguousArray<CallStackFrame>
    public let threadAttributed: Bool?
}
@available(iOS 27.0, *)
public struct CallStackFrame: Hashable, Sendable, Codable {
    public let binaryUUID: UUID?
    public let address: UInt64?
    public let offsetIntoBinaryTextSegment: UInt64?
    public let sampleCount: Int?
    public let subFrames: ContiguousArray<CallStackFrame>
    /// The name of the frame's binary, from the tree's binary info.
    public func binaryName(from tree: CallStackTree) -> String? { binaryUUID.flatMap { tree.binaryInfo[$0]?.name } }
}

@available(iOS 27.0, *)
public struct CrashDiagnostic: Hashable, Sendable, Codable {
    /// An uncaught Objective-C exception's details.
    public struct ObjectiveCExceptionReason: Hashable, Sendable, Codable {
        public let composedMessage: String
        public let formatString: String
        public let arguments: [String]
        public let exceptionType: String
        public let className: String
        public let exceptionName: String
    }
    /// How the crash ended the app.
    public struct TerminationCategory: Hashable, Sendable, Codable, CustomStringConvertible {
        let name: String
        public var description: String { name }
        public static let badAccess = TerminationCategory(name: "badAccess")
        public static let abnormal = TerminationCategory(name: "abnormal")
        public static let illegalInstruction = TerminationCategory(name: "illegalInstruction")
        public static let watchdog = TerminationCategory(name: "watchdog")
        public static let taskTimeout = TerminationCategory(name: "taskTimeout")
        public static let fileLock = TerminationCategory(name: "fileLock")
    }
    /// The termination reason the crash report gives ("Namespace SIGNAL, Code 11 Segmentation fault: 11").
    public struct TerminationReason: Hashable, Sendable, Codable, CustomStringConvertible {
        let text: String
        public var description: String { text }
    }
    public let callStackTree: CallStackTree
    public let exceptionType: Int?
    public let exceptionCode: UInt64?
    public let signal: Int?
    public let exceptionReason: CrashDiagnostic.ObjectiveCExceptionReason?
    public let virtualMemoryRegionInfo: String?
    public let terminationCategory: CrashDiagnostic.TerminationCategory?
    public let terminationReason: CrashDiagnostic.TerminationReason?
}
@available(iOS 27.0, *)
public struct HangDiagnostic: Hashable, Sendable, Codable {
    public let callStackTree: CallStackTree
    public let hangDuration: Measurement<UnitDuration>
}
@available(iOS 27.0, *)
public struct CPUExceptionDiagnostic: Hashable, Sendable, Codable {
    public let callStackTree: CallStackTree
    public let totalCPUTime: Measurement<UnitDuration>
    public let totalSampledTime: Measurement<UnitDuration>
}
@available(iOS 27.0, *)
public struct DiskWriteExceptionDiagnostic: Hashable, Sendable, Codable {
    public let callStackTree: CallStackTree
    public let totalBytesWritten: Measurement<UnitInformationStorage>
}
@available(iOS 27.0, *)
public struct AppLaunchDiagnostic: Hashable, Sendable, Codable {
    public let callStackTree: CallStackTree
    public let launchDuration: Measurement<UnitDuration>
}
@available(iOS 27.0, *)
/// (isim does not limit an app's memory: never reported)
public struct MemoryExceptionDiagnostic: Hashable, Sendable, Codable {
    public let callStackTree: CallStackTree
}

@available(iOS 27.0, *)
/// What a diagnostic report is about.
public enum DiagnosticResult: Hashable, Sendable, Codable {
    case appLaunch(AppLaunchDiagnostic)
    case cpuException(CPUExceptionDiagnostic)
    case crash(CrashDiagnostic)
    case diskWriteException(DiskWriteExceptionDiagnostic)
    case hang(HangDiagnostic)
    case memoryException(MemoryExceptionDiagnostic)

    init(_ d: _MXDiagData) {
        let tree = CallStackTree(d.frames)
        switch d.kind {
        case "crash":
            let category: CrashDiagnostic.TerminationCategory
            switch d.signal {
            case 11?, 10?: category = .badAccess
            case 4?, 5?: category = .illegalInstruction
            default: category = .abnormal
            }
            let reason = d.excName.map { name -> CrashDiagnostic.ObjectiveCExceptionReason in
                let text = d.excReason ?? ""
                return CrashDiagnostic.ObjectiveCExceptionReason(composedMessage: text, formatString: text.replacingOccurrences(of: "%", with: "%%"),
                                                                 arguments: [], exceptionType: name, className: d.excClass ?? "NSException", exceptionName: name)
            }
            self = .crash(CrashDiagnostic(callStackTree: tree, exceptionType: d.exceptionType, exceptionCode: d.exceptionCode.map { UInt64(truncatingIfNeeded: $0) },
                                          signal: d.signal, exceptionReason: reason, virtualMemoryRegionInfo: d.vmRegion, terminationCategory: category,
                                          terminationReason: d.termination.map { CrashDiagnostic.TerminationReason(text: $0) }))
        case "hang": self = .hang(HangDiagnostic(callStackTree: tree, hangDuration: Measurement(value: d.value, unit: .seconds)))
        case "cpu":
            self = .cpuException(CPUExceptionDiagnostic(callStackTree: tree, totalCPUTime: Measurement(value: d.value, unit: .seconds),
                                                        totalSampledTime: Measurement(value: d.value2, unit: .seconds)))
        case "disk": self = .diskWriteException(DiskWriteExceptionDiagnostic(callStackTree: tree, totalBytesWritten: Measurement(value: d.value, unit: .megabytes)))
        default: self = .appLaunch(AppLaunchDiagnostic(callStackTree: tree, launchDuration: Measurement(value: d.value, unit: .seconds)))
        }
    }
}

@available(iOS 27.0, *)
/// One diagnostic: a crash, a hang, an exception or a slow launch, and what the app was doing.
public struct DiagnosticReport: Sendable, Codable {
    public struct Environment: Sendable, Codable {
        public let deviceType: String
        public let osVersion: OSVersion
        public let platformArchitecture: String
        public let regionFormat: String
        public let applicationVersion: String
        public let isTestFlightApp: Bool
        public let lowPowerModeEnabled: Bool
        public let states: [MetricManager.ReportedState]
        public let signpostData: [SignpostRecord]
        public let applicationBuildVersion: String
        public let bundleIdentifier: String
        public let pid: pid_t?
    }
    public let timeRange: DateInterval
    public let environment: DiagnosticReport.Environment
    public let result: DiagnosticResult

    init(_ d: _MXDiagData, states: [MetricManager.ReportedState]) {
        let at = Date(timeIntervalSince1970: d.date)
        timeRange = DateInterval(start: at, duration: 0)
        let m = d.meta
        environment = Environment(deviceType: m.device, osVersion: .current, platformArchitecture: m.arch, regionFormat: m.region,
                                  applicationVersion: d.appVersion, isTestFlightApp: m.testFlight, lowPowerModeEnabled: m.lowPower,
                                  states: states,
                                  signpostData: d.signposts.map { s in
                                      SignpostRecord(subsystem: s.subsystem, category: s.category, name: s.name,
                                                     interval: DateInterval(start: Date(timeIntervalSince1970: s.begin),
                                                                            end: Date(timeIntervalSince1970: max(s.begin, s.end ?? s.begin))))
                                  },
                                  applicationBuildVersion: m.build, bundleIdentifier: m.bundle, pid: m.pid == 0 ? nil : m.pid)
        result = DiagnosticResult(d)
    }
}

// MARK: - The manager

@available(iOS 27.0, *)
/// iOS 27: the app's metric and diagnostic reports as async sequences, the states it reports (for the domains it
/// enables), and launch tasks measured as part of the launch.
public final class MetricManager: @unchecked Sendable {
    /// A state the app was in during a report: its domain and label, how long, and its stable metadata.
    public struct ReportedState: Sendable, Codable {
        public let domain: String
        public let label: String
        public let duration: Measurement<UnitDuration>
        public let stableMetadata: [String: ReportableMetadataValue]

        init(_ s: _MXStateData) {
            domain = s.domain; label = s.label; duration = Measurement(value: s.duration, unit: .seconds)
            stableMetadata = s.meta.mapValues(\.reportable)
        }
        enum CodingKeys: String, CodingKey { case domain, label, duration, stableMetadata }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            domain = try c.decode(String.self, forKey: .domain); label = try c.decode(String.self, forKey: .label)
            duration = try c.decode(Measurement<UnitDuration>.self, forKey: .duration)
            stableMetadata = try c.decode([String: _MXMetaValue].self, forKey: .stableMetadata).mapValues(\.reportable)
        }
        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(domain, forKey: .domain); try c.encode(label, forKey: .label); try c.encode(duration, forKey: .duration)
            try c.encode(stableMetadata.mapValues { _MXMetaValue($0) }, forKey: .stableMetadata)
        }
    }

    /// Why a launch task could not be measured.
    public struct LaunchTaskError: Error, Sendable {
        public enum Reason: Hashable, Sendable {
            case invalidID, maxCountExceeded, pastDeadline, duplicateTask, taskUnknown, internalFailure
        }
        public let taskID: LaunchTaskID
        public let reason: MetricManager.LaunchTaskError.Reason
    }

    private let lock = NSLock()
    private var domains: Set<StateReportingDomain>

    public init(enabledStateReportingDomains: Set<StateReportingDomain>) {
        domains = enabledStateReportingDomains
        _ = MXMetricManager.shared                           // starts measuring
    }
    public convenience init() { self.init(enabledStateReportingDomains: []) }

    /// The domains whose states the reports attribute measurements to.
    public var enabledStateReportingDomains: Set<StateReportingDomain> {
        get { lock.lock(); defer { lock.unlock() }; return domains }
        set { lock.lock(); domains = newValue; lock.unlock() }
    }

    /// The metric reports delivered from now on (on isim: the earlier runs' at the first subscription, then each
    /// `metrickit deliver`).
    public var metricReports: some AsyncSequence<MetricReport, Never> {
        AsyncStream { continuation in
            let sub = _MetricReportSubscriber { [weak self] payloads in
                let domains = self?.enabledStateReportingDomains ?? []
                for p in payloads { continuation.yield(MetricReport(p.data, domains: domains)) }
            } diagnostics: { _ in }
            MXMetricManager.shared.add(sub)
            continuation.onTermination = { _ in MXMetricManager.shared.remove(sub) }
        }
    }

    /// The diagnostic reports delivered from now on, one per diagnostic.
    public var diagnosticReports: some AsyncSequence<DiagnosticReport, Never> {
        AsyncStream { continuation in
            let sub = _MetricReportSubscriber { _ in } diagnostics: { [weak self] payloads in
                let domains = self?.enabledStateReportingDomains ?? []
                let pid = ProcessInfo.processInfo.processIdentifier
                for p in payloads {
                    for d in p.data.diags {
                        let states = d.meta.pid == pid
                            ? MXMetricManager.shared.recorder.currentStates().filter { domains.contains(StateReportingDomain($0.domain)) }
                                .map { ReportedState($0) }
                            : []
                        continuation.yield(DiagnosticReport(d, states: states))
                    }
                }
            }
            MXMetricManager.shared.add(sub)
            continuation.onTermination = { _ in MXMetricManager.shared.remove(sub) }
        }
    }

    /// A log handle whose signposts become signpost interval metrics.
    public static func logHandle(category: String) -> OSLog { MXMetricManager.makeLogHandle(category: category) }

    /// Runs a task the app does before it is ready to use; its time counts toward the extended launch measurement.
    public func trackLaunchTask<Result, Failure: Error>(id: LaunchTaskID, onTrackingError: ((MetricManager.LaunchTaskError) -> Void)? = nil,
                                                        _ task: () async throws(Failure) -> Result) async throws(Failure) -> Result {
        let tracked = Self.beginLaunchTask(id, onTrackingError)
        defer { if tracked { Self.endLaunchTask(id, onTrackingError) } }
        return try await task()
    }
    public func trackLaunchTask<Result, Failure: Error>(id: LaunchTaskID, onTrackingError: ((MetricManager.LaunchTaskError) -> Void)? = nil,
                                                        _ task: () throws(Failure) -> Result) throws(Failure) -> Result {
        let tracked = Self.beginLaunchTask(id, onTrackingError)
        defer { if tracked { Self.endLaunchTask(id, onTrackingError) } }
        return try task()
    }
    private static func reason(_ e: Error) -> LaunchTaskError.Reason {
        switch (e as? MXMetricManagerError)?.code {
        case .invalidID?: return .taskUnknown
        case .maxCount?: return .maxCountExceeded
        case .pastDeadline?: return .pastDeadline
        case .duplicate?: return .duplicateTask
        default: return .internalFailure
        }
    }
    private static func beginLaunchTask(_ id: LaunchTaskID, _ onError: ((LaunchTaskError) -> Void)?) -> Bool {
        guard !id.rawValue.isEmpty else { onError?(LaunchTaskError(taskID: id, reason: .invalidID)); return false }
        do { try MXMetricManager.extendLaunchMeasurement(forTaskID: id.rawValue); return true }
        catch { onError?(LaunchTaskError(taskID: id, reason: reason(error))); return false }
    }
    private static func endLaunchTask(_ id: LaunchTaskID, _ onError: ((LaunchTaskError) -> Void)?) {
        do { try MXMetricManager.finishExtendedLaunchMeasurement(forTaskID: id.rawValue) }
        catch { onError?(LaunchTaskError(taskID: id, reason: reason(error))) }
    }
}

@available(iOS 27.0, *)
/// receives MXMetricManager's payloads for one of MetricManager's sequences
final class _MetricReportSubscriber: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    let metrics: ([MXMetricPayload]) -> Void
    let diagnostics: ([MXDiagnosticPayload]) -> Void
    init(_ metrics: @escaping ([MXMetricPayload]) -> Void, diagnostics: @escaping ([MXDiagnosticPayload]) -> Void) {
        self.metrics = metrics; self.diagnostics = diagnostics
    }
    func didReceive(_ payloads: [MXMetricPayload]) { metrics(payloads) }
    func didReceive(_ payloads: [MXDiagnosticPayload]) { diagnostics(payloads) }
}

// MARK: - Grouping by domain

@available(iOS 27.0, *)
extension Array where Element == MetricManager.ReportedState {
    /// The states by their domain.
    public var byStateReportingDomain: [StateReportingDomain: [MetricManager.ReportedState]] {
        Dictionary(grouping: self) { StateReportingDomain($0.domain) }
    }
}
@available(iOS 27.0, *)
extension Array where Element == MetricReport.StateEntry {
    /// The state entries by their state's domain.
    public var byStateReportingDomain: [StateReportingDomain: [MetricReport.StateEntry]] {
        Dictionary(grouping: self) { StateReportingDomain($0.state.domain) }
    }
}
