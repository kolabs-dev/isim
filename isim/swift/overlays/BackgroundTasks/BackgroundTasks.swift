// isim BackgroundTasks: BGTaskScheduler with app refresh and processing tasks.
//
// Submitted requests are saved in the app container (Library/isim/BackgroundTaskRequests.plist). isim has no
// scheduler that decides when to run them; like Xcode's `e -l objc -- (void)[[BGTaskScheduler sharedScheduler]
// _simulateLaunchForTaskWithIdentifier:@"ID"]`, the script / control command `bgtask BUNDLE-ID TASK-ID` launches a
// pending task: the app is started in the background if it is not running, then the registered launch handler runs.
// Tasks expire after ISIM_BACKGROUND_TASK_SECONDS (default 30 for refresh, 180 for processing tasks).
import Foundation
import UIKit

open class BGTaskRequest: NSObject, NSCopying {
    public let identifier: String
    open var earliestBeginDate: Date?
    init(identifier: String) { self.identifier = identifier }
    open func copy(with zone: OpaquePointer? = nil) -> Any { let r = BGTaskRequest(identifier: identifier); r.earliestBeginDate = earliestBeginDate; return r }
    var _kind: String { "refresh" }
    var _plist: [String: Any] {
        var d: [String: Any] = ["identifier": identifier, "kind": _kind]
        if let e = earliestBeginDate { d["earliestBeginDate"] = e }
        return d
    }
    open override var description: String { "<\(type(of: self)): \(identifier), earliestBeginDate: \(earliestBeginDate.map { "\($0)" } ?? "(null)")>" }
}
public final class BGAppRefreshTaskRequest: BGTaskRequest {
    public override init(identifier: String) { super.init(identifier: identifier) }
    public override func copy(with zone: OpaquePointer? = nil) -> Any { let r = BGAppRefreshTaskRequest(identifier: identifier); r.earliestBeginDate = earliestBeginDate; return r }
}
public final class BGProcessingTaskRequest: BGTaskRequest {
    public var requiresNetworkConnectivity = false
    public var requiresExternalPower = false
    public override init(identifier: String) { super.init(identifier: identifier) }
    override var _kind: String { "processing" }
    override var _plist: [String: Any] {
        var d = super._plist
        d["requiresNetworkConnectivity"] = requiresNetworkConnectivity; d["requiresExternalPower"] = requiresExternalPower
        return d
    }
    public override func copy(with zone: OpaquePointer? = nil) -> Any {
        let r = BGProcessingTaskRequest(identifier: identifier); r.earliestBeginDate = earliestBeginDate
        r.requiresNetworkConnectivity = requiresNetworkConnectivity; r.requiresExternalPower = requiresExternalPower; return r
    }
}

open class BGTask: NSObject {
    public let identifier: String
    open var expirationHandler: (() -> Void)?
    var completed = false
    init(identifier: String) { self.identifier = identifier }
    open func setTaskCompleted(success: Bool) {
        guard !completed else { return }
        completed = true
        NSLog("isim: background task %@ completed (success: %@)", identifier, success ? "true" : "false")
        if let t = bgTaskID { bgTaskID = nil; DispatchQueue.main.async { MainActor.assumeIsolated { UIApplication.shared.endBackgroundTask(t) } } }
    }
    var bgTaskID: UIBackgroundTaskIdentifier?
    var _limit: Double { 30 }
}
public final class BGAppRefreshTask: BGTask {}
public final class BGProcessingTask: BGTask { override var _limit: Double { 180 } }

public func ~= (code: BGTaskScheduler.Error.Code, error: Swift.Error) -> Bool { (error as? BGTaskScheduler.Error)?.code == code }

public final class BGTaskScheduler: NSObject, @unchecked Sendable {
    public static let shared = BGTaskScheduler()
    public struct Error: Swift.Error, CustomNSError, Equatable, Sendable {
        public enum Code: Int, Sendable { case unavailable = 1, tooManyPendingTaskRequests = 2, notPermitted = 3 }
        public let code: Code
        public init(_ code: Code) { self.code = code }
        public static var errorDomain: String { "BGTaskSchedulerErrorDomain" }
        public var errorCode: Int { code.rawValue }
        public static var unavailable: Code { .unavailable }
        public static var tooManyPendingTaskRequests: Code { .tooManyPendingTaskRequests }
        public static var notPermitted: Code { .notPermitted }
    }
    struct Handler { let queue: DispatchQueue?; let launch: (BGTask) -> Void }
    private var handlers: [String: Handler] = [:]
    private let lock = NSLock()
    private var observer: NSObjectProtocol?

    override init() {
        super.init()
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimBackgroundTaskLaunch"), object: nil, queue: nil) { [weak self] n in
            guard let ident = n.object as? String else { return }
            self?.launch(ident, kind: (n.userInfo?["kind"] as? String) ?? "refresh")
        }
    }
    static var permitted: [String] { Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? [] }
    static var modes: [String] { Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? [] }
    static func permits(_ ident: String) -> Bool {
        permitted.contains { $0 == ident || ($0.hasSuffix("*") && ident.hasPrefix(String($0.dropLast()))) }
    }

    @discardableResult
    public func register(forTaskWithIdentifier identifier: String, using queue: DispatchQueue?, launchHandler: @escaping (BGTask) -> Void) -> Bool {
        guard BGTaskScheduler.permits(identifier) else {
            NSLog("isim: BGTaskScheduler: '%@' is not in Info.plist BGTaskSchedulerPermittedIdentifiers (iOS raises NSInternalInconsistencyException)", identifier)
            return false
        }
        lock.lock(); defer { lock.unlock() }
        if handlers[identifier] != nil { NSLog("isim: BGTaskScheduler: a launch handler for '%@' is already registered", identifier); return false }
        handlers[identifier] = Handler(queue: queue, launch: launchHandler)
        NSLog("isim: BGTaskScheduler: registered %@", identifier)
        return true
    }

    // the pending requests, in the app container (UIKit reads them when the shell asks to launch a task)
    static var file: String { (NSHomeDirectory() as NSString).appendingPathComponent("Library/isim/BackgroundTaskRequests.plist") }
    static func load() -> [[String: Any]] {
        (NSDictionary(contentsOfFile: file) as? [String: Any])?["requests"] as? [[String: Any]] ?? []
    }
    static func save(_ r: [[String: Any]]) {
        try? FileManager.default.createDirectory(atPath: (file as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        (["requests": r] as NSDictionary).write(toFile: file, atomically: true)
    }

    public func submit(_ taskRequest: BGTaskRequest) throws {
        let ident = taskRequest.identifier
        guard BGTaskScheduler.permits(ident) else { throw Error(.notPermitted) }
        let mode = taskRequest is BGProcessingTaskRequest ? "processing" : "fetch"
        guard BGTaskScheduler.modes.contains(mode) else {
            NSLog("isim: BGTaskScheduler: submitting %@ needs '%@' in Info.plist UIBackgroundModes", ident, mode)
            throw Error(.notPermitted)
        }
        lock.lock(); defer { lock.unlock() }
        var reqs = BGTaskScheduler.load().filter { ($0["identifier"] as? String) != ident }
        if reqs.count >= 10 { throw Error(.tooManyPendingTaskRequests) }
        reqs.append(taskRequest._plist)
        BGTaskScheduler.save(reqs)
        NSLog("isim: BGTaskScheduler: submitted %@ (%@); run it with: bgtask %@ %@", ident, taskRequest._kind, Bundle.main.bundleIdentifier ?? "?", ident)
    }
    public func cancel(taskRequestWithIdentifier identifier: String) {
        lock.lock(); defer { lock.unlock() }
        BGTaskScheduler.save(BGTaskScheduler.load().filter { ($0["identifier"] as? String) != identifier })
    }
    public func cancelAllTaskRequests() { lock.lock(); defer { lock.unlock() }; BGTaskScheduler.save([]) }
    public func getPendingTaskRequests(completionHandler: @escaping ([BGTaskRequest]) -> Void) {
        let reqs: [BGTaskRequest] = BGTaskScheduler.load().compactMap { d in
            guard let ident = d["identifier"] as? String else { return nil }
            let r: BGTaskRequest
            if (d["kind"] as? String) == "processing" {
                let p = BGProcessingTaskRequest(identifier: ident)
                p.requiresNetworkConnectivity = d["requiresNetworkConnectivity"] as? Bool ?? false
                p.requiresExternalPower = d["requiresExternalPower"] as? Bool ?? false
                r = p
            } else { r = BGAppRefreshTaskRequest(identifier: ident) }
            r.earliestBeginDate = d["earliestBeginDate"] as? Date
            return r
        }
        DispatchQueue.global().async { completionHandler(reqs) }
    }
    public func pendingTaskRequests() async -> [BGTaskRequest] {
        await withCheckedContinuation { (k: CheckedContinuation<[BGTaskRequest], Never>) in getPendingTaskRequests { k.resume(returning: $0) } }
    }

    func launch(_ ident: String, kind: String) {
        lock.lock(); let h = handlers[ident]; lock.unlock()
        guard let h else {
            if !_SwiftUIHandlesBackgroundTask(ident) { NSLog("isim: BGTaskScheduler: no launch handler registered for %@ (iOS terminates the app)", ident) }
            return
        }
        let task: BGTask = kind == "processing" ? BGProcessingTask(identifier: ident) : BGAppRefreshTask(identifier: ident)
        let limitEnv = ProcessInfo.processInfo.environment["ISIM_BACKGROUND_TASK_SECONDS"].flatMap(Double.init)
        let limit = limitEnv ?? task._limit
        task.bgTaskID = UIApplication.shared.beginBackgroundTask(withName: ident) {}
        DispatchQueue.main.asyncAfter(deadline: .now() + limit) {
            guard !task.completed else { return }
            NSLog("isim: background task %@ expired", ident)
            task.expirationHandler?()
        }
        (h.queue ?? DispatchQueue.global()).async { h.launch(task) }
    }
}

/// SwiftUI's `.backgroundTask(.appRefresh(...))` handles a launch when no handler was registered here
/// (SwiftUI marks the request dictionary as handled).
func _SwiftUIHandlesBackgroundTask(_ ident: String) -> Bool {
    let box = NSMutableDictionary(dictionary: ["identifier": ident])
    NotificationCenter.default.post(name: NSNotification.Name("_IsimSwiftUIBackgroundTask"), object: box, userInfo: nil)
    return (box["handled"] as? Bool) == true
}
