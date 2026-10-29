// isim BackgroundTasks: continued processing tasks (iOS 26), adapted. A BGContinuedProcessingTaskRequest submitted
// while the app is in the foreground starts its launch handler at once; the task goes on running when the app goes to
// the background, with no time limit, until it completes or the person cancels it. The system's Live Activity for it
// is the shell's (runtime/shell_bgtasks.inc): while the app is not frontmost it shows the app's name, the task's title
// and subtitle, its progress and a cancel button ("bgtask-cancel"); cancelling runs the task's expirationHandler.
// Two tasks run at a time: beyond that, a `.fail` request throws immediateRunIneligible and a `.queue` one waits (it
// is listed by pendingTaskRequests). The GPU resource is supported on iPad (BGTaskScheduler.supportedResources).
import Foundation
import UIKit
import isim_host

@available(iOS 26.0, *)
@objc(BGContinuedProcessingTaskRequest) public final class BGContinuedProcessingTaskRequest: BGTaskRequest {
    public var title: String
    public var subtitle: String
    public var strategy: SubmissionStrategy = .queue
    public var requiredResources: Resources = []
    public init(identifier: String, title: String, subtitle: String) {
        self.title = title; self.subtitle = subtitle
        super.init(identifier: identifier)
    }
    public override func copy(with zone: OpaquePointer? = nil) -> Any {
        let r = BGContinuedProcessingTaskRequest(identifier: identifier, title: title, subtitle: subtitle)
        r.earliestBeginDate = earliestBeginDate; r.strategy = strategy; r.requiredResources = requiredResources
        return r
    }
    override var _kind: String { "continued" }

    /// what the scheduler does when the task cannot start at once
    public enum SubmissionStrategy: Int, Sendable {
        case fail = 0
        case queue = 1
    }
    public struct Resources: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static var `default`: Resources { [] }
        public static var gpu: Resources { Resources(rawValue: 1 << 0) }
    }
}

@available(iOS 26.0, *)
@objc(BGContinuedProcessingTask) public final class BGContinuedProcessingTask: BGTask, ProgressReporting {
    public private(set) var title: String
    public private(set) var subtitle: String
    public let progress: Progress
    init(identifier: String, title: String, subtitle: String) {
        self.title = title; self.subtitle = subtitle
        progress = Progress(totalUnitCount: 0)
        super.init(identifier: identifier)
    }
    public func updateTitle(_ title: String, subtitle: String) {
        self.title = title; self.subtitle = subtitle
        _ContinuedTasks.report(self)
    }
    public override func setTaskCompleted(success: Bool) {
        let first = !completed
        super.setTaskCompleted(success: success)
        if first { _ContinuedTasks.finished(self) }
    }
}

@available(iOS 26.0, *)
extension BGTaskScheduler {
    /// the resources continued processing tasks may ask for on this device
    public class var supportedResources: BGContinuedProcessingTaskRequest.Resources {
        UIDevice.current.userInterfaceIdiom == .pad ? .gpu : []
    }
}

/// the running and queued continued processing tasks, and the shell's Live Activity for each
@available(iOS 26.0, *)
enum _ContinuedTasks {
    static let maxRunning = 2
    nonisolated(unsafe) static var running: [String: BGContinuedProcessingTask] = [:]
    nonisolated(unsafe) static var queued: [(BGContinuedProcessingTaskRequest, (BGTask) -> Void)] = []
    nonisolated(unsafe) static var reported: [String: String] = [:]      /* what the shell was last told, per task */
    nonisolated(unsafe) static var timer: DispatchSourceTimer?
    nonisolated(unsafe) static var observer: NSObjectProtocol?
    static let lock = NSLock()

    static func submit(_ r: BGContinuedProcessingTaskRequest, handler: ((BGTask) -> Void)?) throws {
        guard let handler else {
            NSLog("isim: BGTaskScheduler: no launch handler registered for %@ (register one before submitting a continued processing task)", r.identifier)
            throw BGTaskScheduler.Error(.notPermitted)
        }
        guard BGTaskScheduler.permitted.contains(where: { $0.hasSuffix(".*") && r.identifier.hasPrefix(String($0.dropLast())) }) else {
            NSLog("isim: BGTaskScheduler: %@ must match a wildcard identifier (BUNDLE-ID.CONTEXT.*) in BGTaskSchedulerPermittedIdentifiers", r.identifier)
            throw BGTaskScheduler.Error(.notPermitted)
        }
        guard r.requiredResources.isSubset(of: BGTaskScheduler.supportedResources) else {
            NSLog("isim: BGTaskScheduler: %@ requires resources this device does not support for continued processing", r.identifier)
            throw BGTaskScheduler.Error(.unavailable)
        }
        let foreground = Thread.isMainThread ? MainActor.assumeIsolated { UIApplication.shared.applicationState == .active }
                                             : DispatchQueue.main.sync { MainActor.assumeIsolated { UIApplication.shared.applicationState == .active } }
        guard foreground else {
            NSLog("isim: BGTaskScheduler: %@ was submitted while the app is not in the foreground", r.identifier)
            throw BGTaskScheduler.Error(.immediateRunIneligible)
        }
        lock.lock()
        if running[r.identifier] != nil || queued.contains(where: { $0.0.identifier == r.identifier }) {
            lock.unlock()
            NSLog("isim: BGTaskScheduler: continued processing task %@ is already running", r.identifier)
            throw BGTaskScheduler.Error(.tooManyPendingTaskRequests)
        }
        if running.count >= maxRunning {
            if r.strategy == .fail {
                lock.unlock()
                NSLog("isim: BGTaskScheduler: %@ cannot run now (%ld continued processing tasks running)", r.identifier, maxRunning)
                throw BGTaskScheduler.Error(.immediateRunIneligible)
            }
            queued.append((r.copy() as! BGContinuedProcessingTaskRequest, handler))
            lock.unlock()
            NSLog("isim: BGTaskScheduler: queued continued processing task %@ (“%@”)", r.identifier, r.title)
            return
        }
        lock.unlock()
        start(r, handler)
    }
    static func start(_ r: BGContinuedProcessingTaskRequest, _ handler: @escaping (BGTask) -> Void) {
        let task = BGContinuedProcessingTask(identifier: r.identifier, title: r.title, subtitle: r.subtitle)
        lock.lock(); running[r.identifier] = task; lock.unlock()
        listen()
        DispatchQueue.main.async {
            MainActor.assumeIsolated { task.bgTaskID = UIApplication.shared.beginBackgroundTask(withName: r.identifier) {} }
        }
        NSLog("isim: BGTaskScheduler: started continued processing task %@ (“%@”)", r.identifier, r.title)
        report(task)
        handler(task)
    }
    /// the shell's Live Activity: "bgtask-progress ID title\x1fsubtitle\x1ffraction\x1fapp name" (fraction -1: indeterminate)
    static func report(_ t: BGContinuedProcessingTask) {
        let p = t.progress
        let fraction = p.totalUnitCount > 0 ? max(0, min(1, p.fractionCompleted)) : -1
        let name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName")) as? String ?? ""
        let fields = [t.title, t.subtitle, String(format: "%.3f", fraction), name].joined(separator: "\u{1f}")
        lock.lock()
        let changed = reported[t.identifier] != fields
        reported[t.identifier] = fields
        lock.unlock()
        if changed { isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "bgtask-progress", t.identifier, fields) }
    }
    static func finished(_ t: BGContinuedProcessingTask) {
        lock.lock()
        running[t.identifier] = nil; reported[t.identifier] = nil
        let next = running.count < maxRunning && !queued.isEmpty ? queued.removeFirst() : nil
        lock.unlock()
        isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "bgtask-end", t.identifier, "")
        if let (r, h) = next { start(r, h) }
    }
    static func pending() -> [BGTaskRequest] { lock.lock(); defer { lock.unlock() }; return queued.map { $0.0 } }
    /// progress changes reach the shell four times a second; the shell's cancel button: "bgtask-action cancel ID"
    static func listen() {
        lock.lock(); defer { lock.unlock() }
        if timer == nil {
            let t = DispatchSource.makeTimerSource(queue: .main)
            t.schedule(deadline: .now() + 0.25, repeating: 0.25)
            t.setEventHandler {
                lock.lock(); let tasks = Array(running.values); lock.unlock()
                for task in tasks { report(task) }
            }
            t.resume(); timer = t
        }
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: .main) { n in
                guard let s = n.object as? String, s.hasPrefix("bgtask-action cancel ") else { return }
                let ident = String(s.dropFirst("bgtask-action cancel ".count))
                lock.lock(); let task = running[ident]; lock.unlock()
                guard let task, !task.completed else { return }
                NSLog("isim: background task %@ cancelled by the user", ident)
                task.expirationHandler?()
            }
        }
    }
}
