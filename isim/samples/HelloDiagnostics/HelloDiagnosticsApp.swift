// HelloDiagnostics: unified logging read back with OSLogStore, signposts, MetricKit measured on isim, and crash
// reports. Each check logs one "diag …" line (tests/ui/test_diagnostics.py).
//   HELLODIAG unset   logs (Swift Logger, os_log, NSLog and C os_log), signposts (OSSignposter, C os_signpost), reads
//                     them back from OSLogStore, emits MetricKit signposts and hangs the main thread 0.6 s (a hang
//                     diagnostic); `metrickit deliver` then brings this run's measured metric payload
//   HELLODIAG=segv    crashes in C (SIGSEGV) a second after launch; =exception: an uncaught NSRangeException;
//                     =fatal: a Swift fatalError. The next launch gets the crash as an MXCrashDiagnostic and the
//                     crashed run's metrics (with its exit) in a metric payload
//   HELLODIAG=slowlaunch  takes 2.5 s to launch (an MXAppLaunchDiagnostic)
import UIKit
import OSLog
import MetricKit

@_silgen_name("cdiag_log_and_signpost") func cdiagLogAndSignpost()
@_silgen_name("cdiag_crash_segv") func cdiagCrashSegv()

let mode = ProcessInfo.processInfo.environment["HELLODIAG"] ?? ""
let subsystem = "dev.isim.diag"

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, MXMetricManagerSubscriber {
    var window: UIWindow?
    let status = UILabel()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MXMetricManager.shared.add(self)
        print("diag subscribed past=\(MXMetricManager.shared.pastPayloads.count) mode=\(mode.isEmpty ? "normal" : mode)")
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        status.text = "Diagnostics"; status.font = .systemFont(ofSize: 28, weight: .bold); status.textAlignment = .center
        status.frame = CGRect(x: 0, y: 300, width: UIScreen.main.bounds.width, height: 40)
        vc.view.addSubview(status)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        if mode == "slowlaunch" { Thread.sleep(forTimeInterval: 2.5) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.run() }
        return true
    }

    func run() {
        switch mode {
        case "segv": crashSoon { cdiagCrashSegv() }
        case "exception": crashSoon { _ = (NSArray(array: [1, 2]) as NSArray).object(at: 3) }
        case "fatal": crashSoon { fatalError("diag fatal error") }
        default: logging(); signposts(); readBack(); metricKit()
        }
    }
    func crashSoon(_ crash: @escaping () -> Void) {
        print("diag crashing (\(mode))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { crash() }
    }

    // MARK: logging and signposts
    func logging() {
        let ui = Logger(subsystem: subsystem, category: "ui")
        let user = "alice"
        ui.info("Loaded \(3) items for \(user)")
        ui.error("Failed with code \(404, privacy: .public)")
        ui.notice("Ready")
        os_log("legacy %{public}@", log: OSLog(subsystem: subsystem, category: "legacy"), type: .default, "value")
        NSLog("diag nslog marker")
        cdiagLogAndSignpost()
    }
    func signposts() {
        let sp = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
        sp.withIntervalSignpost("Load") { _ = usleep(50_000) }
        let id = sp.makeSignpostID()
        let state = sp.beginInterval("Fetch", id: id, "url \("https://example.com", privacy: .public)")
        usleep(20_000)
        sp.endInterval("Fetch", state)
        sp.emitEvent("Tap")
        print("diag signposter enabled=\(sp.isEnabled) disabled=\(OSSignposter.disabled.isEnabled)")
    }

    // MARK: OSLogStore
    func readBack() {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let since = store.position(timeIntervalSinceEnd: -60)
            let mine = try store.getEntries(at: since, matching: NSPredicate(format: "subsystem == %@", subsystem)).map { $0 }
            let logs = mine.compactMap { $0 as? OSLogEntryLog }, posts = mine.compactMap { $0 as? OSLogEntrySignpost }
            let info = logs.first { $0.composedMessage.hasPrefix("Loaded") }
            let err = logs.first { $0.level == .error }
            let comps = info?.components.map { "\($0.placeholder)=\($0.argumentStringValue ?? "")" }.joined(separator: ",") ?? "-"
            print("diag store logs=\(logs.count) signposts=\(posts.count) info=\"\(info?.composedMessage ?? "-")\" level=\(info?.level.rawValue ?? -1) " +
                  "category=\(info?.category ?? "-") format=\"\(info?.formatString ?? "-")\" components=\(comps) error=\"\(err?.composedMessage ?? "-")\"")
            let names = posts.map { "\($0.signpostName):\(["undefined", "begin", "end", "event"][$0.signpostType.rawValue])" }
            print("diag store signposts \(names.joined(separator: " "))")
            let c = logs.first { $0.category == "c" }
            print("diag store c=\"\(c?.composedMessage ?? "-")\" legacy=\(logs.contains { $0.category == "legacy" && $0.composedMessage == "legacy value" })")
            let ns = try store.getEntries(matching: NSPredicate(format: "composedMessage CONTAINS %@", "nslog marker")).map { $0 }
            // reverse from the end (a position would be where the backward walk starts)
            let rev = try store.getEntries(with: .reverse, matching: NSPredicate(format: "subsystem == %@", subsystem)).map { $0 }
            let errors = try store.getEntries(matching: NSPredicate(format: "subsystem == %@ AND messageType == %@", subsystem, "error")).map { $0 }
            print("diag store nslog=\(ns.count) reverse=\(rev.first?.date ?? .distantPast >= rev.last?.date ?? .distantFuture) errors=\(errors.count) pid=\(info?.processIdentifier == getpid())")
        } catch { print("diag store error \(error)") }
        do { _ = try OSLogStore(scope: .system); print("diag store system opened") } catch { print("diag store system throws") }
    }

    // MARK: MetricKit
    func metricKit() {
        let log = MXMetricManager.makeLogHandle(category: "Diag")
        for _ in 0..<2 {
            mxSignpost(.begin, log: log, name: "Work")
            usleep(30_000)
            mxSignpost(.end, log: log, name: "Work")
        }
        mxSignpost(.event, log: log, name: "Mark")
        print("diag metrickit signposts emitted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("diag hanging the main thread")
            Thread.sleep(forTimeInterval: 0.6)                        // a hang (250 ms or more away from the event loop)
            self.status.text = "Hung 0.6 s"
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads {
            let json = String(decoding: p.jsonRepresentation(), as: UTF8.self)
            let launch = p.applicationLaunchMetrics?.histogrammedTimeToFirstDraw.totalBucketCount ?? 0
            let hangs = (p.applicationResponsivenessMetrics?.histogrammedApplicationHangTime.bucketEnumerator.allObjects as? [MXHistogramBucket<UnitDuration>] ?? [])
                .reduce(0) { $0 + $1.bucketCount }
            let fg = p.applicationExitMetrics?.foregroundExitData
            let sp = p.signpostMetrics?.map { "\($0.signpostCategory):\($0.signpostName)=\($0.totalCount)/\($0.signpostIntervalData?.histogrammedSignpostDuration.totalBucketCount ?? 0)" }.sorted().joined(separator: ",") ?? "-"
            print("diag metric payload version=\(p.latestApplicationVersion) cpu=\((p.cpuMetrics?.cumulativeCPUTime.value ?? 0) > 0) " +
                  "peak=\((p.memoryMetrics?.peakMemoryUsage.value ?? 0) > 1000) launch=\(launch) hangs=\(hangs) fg=\((p.applicationTimeMetrics?.cumulativeForegroundTime.value ?? 0) > 0) " +
                  "gpu=\(p.gpuMetrics?.cumulativeGPUTime.value ?? -1) cellular=\(p.cellularConditionMetrics == nil ? "nil" : "set") " +
                  "apl=\(p.displayMetrics?.averagePixelLuminance.map { $0.averageMeasurement.value >= 0 && $0.averageMeasurement.value <= 100 } ?? false) " +
                  "exits normal=\(fg?.cumulativeNormalAppExitCount ?? -1) badAccess=\(fg?.cumulativeBadAccessExitCount ?? -1) abnormal=\(fg?.cumulativeAbnormalExitCount ?? -1) " +
                  "illegal=\(fg?.cumulativeIllegalInstructionExitCount ?? -1) signposts=\(sp) pid=\(p.metaData?.pid ?? -1) json=\(json.contains("\"cumulativeCPUTime\""))")
        }
        print("diag past payloads \(MXMetricManager.shared.pastPayloads.count)")
    }
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            for c in p.crashDiagnostics ?? [] {
                let tree = String(decoding: c.callStackTree.jsonRepresentation(), as: UTF8.self)
                print("diag crash signal=\(c.signal?.intValue ?? -1) type=\(c.exceptionType?.intValue ?? -1) version=\(c.applicationVersion) " +
                      "reason=\(c.exceptionReason?.exceptionName ?? "-") termination=\"\(c.terminationReason ?? "-")\" stack=\(tree.contains("HelloDiagnostics"))")
            }
            for h in p.hangDiagnostics ?? [] {
                let tree = String(decoding: h.callStackTree.jsonRepresentation(), as: UTF8.self)
                print("diag hang duration=\(h.hangDuration.value >= 0.5 && h.hangDuration.value < 5) stack=\(tree.contains("HelloDiagnostics")) frames=\(tree.components(separatedBy: "binaryName").count - 1 > 2)")
            }
            for l in p.appLaunchDiagnostics ?? [] {
                print("diag launch duration=\(l.launchDuration.value >= 2) stack=\(String(decoding: l.callStackTree.jsonRepresentation(), as: UTF8.self).contains("HelloDiagnostics"))")
            }
        }
        print("diag past diagnostics \(MXMetricManager.shared.pastDiagnosticPayloads.count)")
    }
}
