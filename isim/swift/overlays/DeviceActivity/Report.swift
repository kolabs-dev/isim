// isim DeviceActivity: activity data and reports (iOS 16). DeviceActivityReport shows a scene of the app's Device
// Activity Report extension (EXExtensionPointIdentifier com.apple.deviceactivityui.report-extension). Adapted: iOS runs
// the extension in a sandboxed process of its own and shows its view in the app; isim loads it into the app (like its
// other extensions) and draws the scene's view in place. The data is the usage isim recorded
// (`isim screentime usage APP MINUTES`: …/ScreenTime/usage.json), in segments of the filter's interval.
import Foundation
import SwiftUI
import ExtensionFoundation
import ExtensionKit

// MARK: - filters

@available(iOS 16.0, *)
public struct DeviceActivityFilter: Sendable {
    public enum SegmentInterval: Sendable {
        case hourly(during: DateInterval = DateInterval(start: Calendar.current.startOfDay(for: .now), end: .now))
        case daily(during: DateInterval)
        case weekly(during: DateInterval)
        var interval: DateInterval {
            switch self { case .hourly(let i), .daily(let i), .weekly(let i): return i }
        }
        var step: TimeInterval {
            switch self { case .hourly: return 3600; case .daily: return 86400; case .weekly: return 7 * 86400 }
        }
    }
    public struct Users: Sendable, Hashable {
        let _children: Bool
        public static let all = Users(_children: false)
        public static let children = Users(_children: true)
    }
    public struct Devices: Sendable, Hashable {
        let _models: Set<DeviceActivityData.Device.Model>?
        public static let all = Devices(_models: nil)
        public init(_ models: Set<DeviceActivityData.Device.Model>) { _models = models }
        init(_models: Set<DeviceActivityData.Device.Model>?) { self._models = _models }
    }
    public var segmentInterval: SegmentInterval
    public let users: Users?
    public let devices: Devices?
    public var applications: Set<ApplicationToken>
    public var categories: Set<ActivityCategoryToken>
    public var webDomains: Set<WebDomainToken>
    public init(segment segmentInterval: SegmentInterval = .hourly(), devices: Devices? = nil, applications: Set<ApplicationToken> = [],
                categories: Set<ActivityCategoryToken> = [], webDomains: Set<WebDomainToken> = []) {
        self.segmentInterval = segmentInterval; users = nil; self.devices = devices
        self.applications = applications; self.categories = categories; self.webDomains = webDomains
    }
    public init(segment segmentInterval: SegmentInterval = .hourly(), users: Users, devices: Devices, applications: Set<ApplicationToken> = [],
                categories: Set<ActivityCategoryToken> = [], webDomains: Set<WebDomainToken> = []) {
        self.segmentInterval = segmentInterval; self.users = users; self.devices = devices
        self.applications = applications; self.categories = categories; self.webDomains = webDomains
    }
}

// MARK: - results

@available(iOS 16.0, *)
public struct DeviceActivityResults<Element>: AsyncSequence {
    let items: [Element]
    public final class Iterator<IteratorElement>: AsyncIteratorProtocol {
        var rest: [IteratorElement]
        init(_ items: [IteratorElement]) { rest = items }
        public func next() async -> IteratorElement? { rest.isEmpty ? nil : rest.removeFirst() }
    }
    public func makeAsyncIterator() -> DeviceActivityResults<Element>.Iterator<Element> { Iterator(items) }
}

// MARK: - data

@available(iOS 16.0, *)
public struct DeviceActivityData {
    public struct User {
        public enum FamilyRole: Int, Sendable { case individual = 0, child = 1 }
        public var appleID: String?
        public var nameComponents: PersonNameComponents?
        public var role: DeviceActivityData.User.FamilyRole
    }
    public struct Device {
        public enum Model: Int, Hashable, Sendable { case iPhone = 0, iPad = 1, iPod = 2, mac = 3 }
        public var name: String?
        public var model: DeviceActivityData.Device.Model
    }
    public struct ApplicationActivity {
        public var application: Application
        public var totalActivityDuration: TimeInterval
        public var numberOfPickups: Int
        public var numberOfNotifications: Int
    }
    public struct WebDomainActivity {
        public var webDomain: WebDomain
        public var totalActivityDuration: TimeInterval
    }
    public struct CategoryActivity {
        public var category: ActivityCategory
        public var totalActivityDuration: TimeInterval
        let _apps: [ApplicationActivity]
        public var applications: DeviceActivityResults<DeviceActivityData.ApplicationActivity> { DeviceActivityResults(items: _apps) }
        public var webDomains: DeviceActivityResults<DeviceActivityData.WebDomainActivity> { DeviceActivityResults(items: []) }
    }
    public struct ActivitySegment {
        public var dateInterval: DateInterval
        public var totalActivityDuration: TimeInterval
        public var firstPickup: Date?
        public var longestActivity: DateInterval?
        public var totalPickupsWithoutApplicationActivity: Int
        let _categories: [CategoryActivity]
        public var categories: DeviceActivityResults<DeviceActivityData.CategoryActivity> { DeviceActivityResults(items: _categories) }
    }
    public var user: DeviceActivityData.User
    public var device: DeviceActivityData.Device
    public var lastUpdatedDate: Date
    public var segmentInterval: DeviceActivityFilter.SegmentInterval
    let _segments: [ActivitySegment]
    public var activitySegments: DeviceActivityResults<DeviceActivityData.ActivitySegment> { DeviceActivityResults(items: _segments) }

    @available(iOS 26.4, *)
    public enum Policy: Sendable { case cached, live }
    @available(iOS 26.4, *)
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case missingData, unauthorized, unavailable
        public var errorDescription: String? {
            switch self {
            case .missingData: return "There is no activity data for the filter."
            case .unauthorized: return "The app is not authorized to read activity data."
            case .unavailable: return "Activity data is not available."
            }
        }
    }
    /// iOS 26.4: the device's activity data, for apps authorized with data access
    @available(iOS 26.4, *)
    public static func activityData(filteredBy filter: DeviceActivityFilter = .init(), using policy: DeviceActivityData.Policy = .cached)
        -> some AsyncSequence<DeviceActivityData, any Swift.Error> {
        AsyncThrowingStream<DeviceActivityData, any Swift.Error> { c in
            guard (_IsimScreenTime.authorization(_IsimScreenTime.appBundle) ?? "").hasPrefix("approved") else {
                c.finish(throwing: DeviceActivityData.Error.unauthorized); return
            }
            c.yield(_make(filter))
            c.finish()
        }
    }

    struct _Usage: Codable { var bundle: String; var end: Double; var seconds: Double }
    static func _make(_ filter: DeviceActivityFilter) -> DeviceActivityData {
        let usage = _IsimScreenTime.readJSON([_Usage].self, "usage.json") ?? []
        let apps = Dictionary(_IsimScreenTime.installedApps().map { ($0.bundle, $0) }, uniquingKeysWith: { a, _ in a })
        let wanted: (String) -> Bool = { b in
            if filter.applications.isEmpty && filter.categories.isEmpty { return true }
            if filter.applications.contains(_IsimScreenTime.applicationToken(b)) { return true }
            return filter.categories.contains(_IsimScreenTime.categoryToken(apps[b]?.category ?? "other"))
        }
        var segments: [ActivitySegment] = []
        let all = filter.segmentInterval.interval
        var start = all.start
        while start < all.end {
            let end = min(start.addingTimeInterval(filter.segmentInterval.step), all.end)
            var perApp: [String: Double] = [:]
            for u in usage where wanted(u.bundle) && u.end > start.timeIntervalSince1970 && u.end <= end.timeIntervalSince1970 { perApp[u.bundle, default: 0] += u.seconds }
            var byCategory: [String: [ApplicationActivity]] = [:]
            for (b, s) in perApp.sorted(by: { $0.key < $1.key }) {
                let a = ApplicationActivity(application: Application(bundleIdentifier: b), totalActivityDuration: s, numberOfPickups: 1, numberOfNotifications: 0)
                byCategory[apps[b]?.category ?? "other", default: []].append(a)
            }
            let cats = byCategory.sorted { $0.key < $1.key }.map { c, list in
                CategoryActivity(category: ActivityCategory(token: _IsimScreenTime.categoryToken(c)), totalActivityDuration: list.reduce(0) { $0 + $1.totalActivityDuration }, _apps: list)
            }
            let total = perApp.values.reduce(0, +)
            segments.append(ActivitySegment(dateInterval: DateInterval(start: start, end: end), totalActivityDuration: total, firstPickup: total > 0 ? start : nil,
                                            longestActivity: nil, totalPickupsWithoutApplicationActivity: 0, _categories: cats))
            start = end
        }
        return DeviceActivityData(user: User(appleID: nil, nameComponents: nil, role: .individual),
                                  device: Device(name: "iPhone", model: .iPhone), lastUpdatedDate: _IsimScreenTime.now,
                                  segmentInterval: filter.segmentInterval, _segments: segments)
    }
}

// MARK: - the report extension

@available(iOS 16.0, *)
public struct DeviceActivityReport: View {
    public struct Context: RawRepresentable, Hashable, Sendable {
        public var rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
    }
    let context: Context, filter: DeviceActivityFilter
    @State var shown: AnyView?
    public init(_ context: DeviceActivityReport.Context, filter: DeviceActivityFilter = DeviceActivityFilter()) { self.context = context; self.filter = filter }
    public var body: some View {
        Group {
            if let shown { shown } else { Color.clear }
        }
        .task {
            guard let scene = _DAReportHost.scene(for: context) else { return }
            let data = DeviceActivityResults(items: [DeviceActivityData._make(filter)])
            shown = await scene._isimView(data)
            NSLog("isim DeviceActivity: report “%@” shown", context.rawValue)
        }
    }
}

@available(iOS 16.0, *)
@MainActor @preconcurrency public protocol DeviceActivityReportScene: AppExtensionScene {
    associatedtype Configuration
    associatedtype Content: View
    var context: DeviceActivityReport.Context { get }
    @ViewBuilder var content: (Self.Configuration) -> Self.Content { get }
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Self.Configuration
    /// the scenes a builder combined (isim)
    var _isimScenes: [any DeviceActivityReportScene] { get }
}
@available(iOS 16.0, *)
extension DeviceActivityReportScene {
    public var _isimScenes: [any DeviceActivityReportScene] { [self] }
    func _isimView(_ data: DeviceActivityResults<DeviceActivityData>) async -> AnyView { AnyView(content(await makeConfiguration(representing: data))) }
}

@available(iOS 16.0, *)
@MainActor @preconcurrency public protocol DeviceActivityReportExtension: AppExtension {
    associatedtype Body: DeviceActivityReportScene
    @DeviceActivityReportBuilder var body: Self.Body { get }
}
@available(iOS 16.0, *)
public struct _DAReportConfiguration: AppExtensionConfiguration {
    nonisolated public func accept(connection: NSXPCConnection) -> Bool { false }
}
@available(iOS 16.0, *)
extension DeviceActivityReportExtension {
    public var configuration: _DAReportConfiguration { _DAReportConfiguration() }
    /// the extension's entry point: isim's host keeps the extension (it runs in the app's process)
    public static func main() throws { _DAReportHost.loaded = Self() }
}

/// the app's report extension, loaded into the app
@available(iOS 16.0, *)
@MainActor enum _DAReportHost {
    static var loaded: (any DeviceActivityReportExtension)?
    static var tried = false
    static func scene(for context: DeviceActivityReport.Context) -> (any DeviceActivityReportScene)? {
        if !tried {
            tried = true
            load()
        }
        guard let ext = loaded else { NSLog("isim DeviceActivity: the app has no Device Activity Report extension"); return nil }
        let scenes = ext.body._isimScenes
        guard let s = scenes.first(where: { $0.context == context }) else {
            NSLog("isim DeviceActivity: the report extension has no scene for “%@”", context.rawValue); return nil
        }
        return s
    }
    static func load() {
        let plugins = (Bundle.main.bundlePath as NSString).appendingPathComponent("PlugIns")
        for n in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where n.hasSuffix(".appex") {
            let p = (plugins as NSString).appendingPathComponent(n)
            guard let info = NSDictionary(contentsOfFile: (p as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
                  (info["EXAppExtensionAttributes"] as? [String: Any])?["EXExtensionPointIdentifier"] as? String == "com.apple.deviceactivityui.report-extension"
            else { continue }
            let exe = (p as NSString).appendingPathComponent(info["CFBundleExecutable"] as? String ?? (n as NSString).deletingPathExtension)
            guard let h = dlopen(exe, RTLD_NOW) else { NSLog("isim DeviceActivity: cannot load %@: %s", n, dlerror()); return }
            if let reg = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_bundle_register_extension") {
                unsafeBitCast(reg, to: (@convention(c) (NSString) -> Void).self)(p as NSString)
            }
            _IsimScreenTime._revealed = true                 // the extension may see the apps' names (iOS's sandbox keeps them from the app)
            if let m = dlsym(h, "main") {
                _ = unsafeBitCast(m, to: (@convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32).self)(0, nil)
            }
            NSLog("isim DeviceActivity: loaded the report extension %@", n)
            return
        }
    }
}

// MARK: - the builder

@available(iOS 16.0, *)
public struct _DAReportScenes: DeviceActivityReportScene {
    let scenes: [any DeviceActivityReportScene]
    public var context: DeviceActivityReport.Context { scenes.first?.context ?? .init("") }
    public struct Configuration {}
    public var content: (Configuration) -> EmptyView {
        let none: (Configuration) -> EmptyView = { _ in EmptyView() }
        return none
    }
    public func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Configuration { Configuration() }
    public var _isimScenes: [any DeviceActivityReportScene] { scenes.flatMap { $0._isimScenes } }
}

@available(iOS 16.0, *)
@resultBuilder public struct DeviceActivityReportBuilder {
    public static func buildBlock<Scene>(_ scene: Scene) -> some DeviceActivityReportScene where Scene: DeviceActivityReportScene { scene }
    public static func buildBlock<S0, S1>(_ s0: S0, _ s1: S1) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1])
    }
    public static func buildBlock<S0, S1, S2>(_ s0: S0, _ s1: S1, _ s2: S2) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2])
    }
    public static func buildBlock<S0, S1, S2, S3>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3])
    }
    public static func buildBlock<S0, S1, S2, S3, S4>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4])
    }
    public static func buildBlock<S0, S1, S2, S3, S4, S5>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5])
    }
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6])
    }
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7])
    }
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8])
    }
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12, _ s13: S13) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene, S13: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12, _ s13: S13, _ s14: S14) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene, S13: DeviceActivityReportScene, S14: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12, _ s13: S13, _ s14: S14, _ s15: S15) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene, S13: DeviceActivityReportScene, S14: DeviceActivityReportScene, S15: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12, _ s13: S13, _ s14: S14, _ s15: S15, _ s16: S16) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene, S13: DeviceActivityReportScene, S14: DeviceActivityReportScene, S15: DeviceActivityReportScene, S16: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12, _ s13: S13, _ s14: S14, _ s15: S15, _ s16: S16, _ s17: S17) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene, S13: DeviceActivityReportScene, S14: DeviceActivityReportScene, S15: DeviceActivityReportScene, S16: DeviceActivityReportScene, S17: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12, _ s13: S13, _ s14: S14, _ s15: S15, _ s16: S16, _ s17: S17, _ s18: S18) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene, S13: DeviceActivityReportScene, S14: DeviceActivityReportScene, S15: DeviceActivityReportScene, S16: DeviceActivityReportScene, S17: DeviceActivityReportScene, S18: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18])
    }
    @available(iOS 17.4, *)
    public static func buildBlock<S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19>(_ s0: S0, _ s1: S1, _ s2: S2, _ s3: S3, _ s4: S4, _ s5: S5, _ s6: S6, _ s7: S7, _ s8: S8, _ s9: S9, _ s10: S10, _ s11: S11, _ s12: S12, _ s13: S13, _ s14: S14, _ s15: S15, _ s16: S16, _ s17: S17, _ s18: S18, _ s19: S19) -> some DeviceActivityReportScene where S0: DeviceActivityReportScene, S1: DeviceActivityReportScene, S2: DeviceActivityReportScene, S3: DeviceActivityReportScene, S4: DeviceActivityReportScene, S5: DeviceActivityReportScene, S6: DeviceActivityReportScene, S7: DeviceActivityReportScene, S8: DeviceActivityReportScene, S9: DeviceActivityReportScene, S10: DeviceActivityReportScene, S11: DeviceActivityReportScene, S12: DeviceActivityReportScene, S13: DeviceActivityReportScene, S14: DeviceActivityReportScene, S15: DeviceActivityReportScene, S16: DeviceActivityReportScene, S17: DeviceActivityReportScene, S18: DeviceActivityReportScene, S19: DeviceActivityReportScene {
        _DAReportScenes(scenes: [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18, s19])
    }
}
