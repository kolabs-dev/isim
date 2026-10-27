// HelloDiagnostics, iOS 27: MetricManager's metric and diagnostic reports (async sequences), StateReporting states
// the reports attribute measurements to, and a launch task measured with trackLaunchTask.
import Foundation
import MetricKit
import StateReporting

/// the screen state's stable metadata
@available(iOS 27.0, *)
@ReportableMetadata
struct ScreenInfo {
    var name: String
    @ReportableMetadataKey("items") var itemCount: Int
    var subtitle: String?
    @ReportableMetadataIgnored var scratch = 0
}
@available(iOS 27.0, *)
@ReportableMetadata
struct NoVolatileMetadata {}

@available(iOS 27.0, *)
let screenDomain: StateReportingDomain = "dev.isim.diag.screen"
@available(iOS 27.0, *)
let metricManager = MetricManager(enabledStateReportingDomains: [screenDomain])
@available(iOS 27.0, *)
let screens = StateReporter.reporter(for: "dev.isim.diag.screen", stableMetadata: ScreenInfo.self, volatileMetadata: NoVolatileMetadata.self)

@available(iOS 27.0, *)
extension AppDelegate {
    /// before the first frame: a launch task (part of the extended launch)
    func trackLaunch() {
        var errors: [MetricManager.LaunchTaskError] = []
        let n = metricManager.trackLaunchTask(id: "diag.load", onTrackingError: { errors.append($0) }) { () -> Int in usleep(20_000); return 3 }
        print("diag launch task result=\(n) errors=\(errors.count)")
    }

    func reports() {
        let meta = ScreenInfo(name: "Home", itemCount: 3, subtitle: nil).metadataDictionary
        print("diag state metadata \(meta.keys.sorted().joined(separator: ",")) items=\(meta["items"] == .integer(3))")
        screens.reportTransition(to: "home", stableMetadata: ScreenInfo(name: "Home", itemCount: 3), volatileMetadata: nil)
        // after the first frame a launch task is too late
        metricManager.trackLaunchTask(id: "diag.late", onTrackingError: { print("diag launch task late reason=\($0.reason)") }) { }
        Task {
            for await r in metricManager.metricReports {
                let values = r.intervalEntries.flatMap(\.values)
                var cpu = false, disk = false, signposts: [String] = []
                for v in values {
                    switch v {
                    case .cpuTime(let m): cpu = m.value.value > 0
                    case .totalFileCount(let m): disk = m.binaryFileCount > 0 && m.dataFileCount > 0
                    case .signpostInterval(let m): signposts.append("\(m.signpostCategory):\(m.signpostName)=\(m.totalCount)")
                    default: break
                    }
                }
                let states = r.stateEntries.map { "\($0.state.label)" }.sorted().joined(separator: ",")
                let home = r.stateEntries.first { $0.state.label == "home" }
                let encoder = JSONEncoder()
                encoder.userInfo[MetricReport.encodingFormatKey] = MetricReport.EncodingFormat.byStateReportingDomain
                let json = (try? encoder.encode(r)).map { String(decoding: $0, as: UTF8.self) } ?? ""
                let decoded = (try? JSONDecoder().decode(MetricReport.self, from: Data(json.utf8)))?.stateEntries.count ?? -1
                print("diag report metrics intervals=\(r.intervalEntries.count) cpu=\(cpu) disk=\(disk) groups=\(Set(values.map(\.metricGroup)).count) " +
                      "signposts=\(signposts.sorted().joined(separator: ",")) states=\(states) " +
                      "home=\(home.map { $0.state.duration.value > 0 && $0.state.stableMetadata["name"] == .string("Home") } ?? false) " +
                      "byDomain=\(r.stateEntries.byStateReportingDomain[screenDomain]?.count ?? 0) json=\(json.contains("\"dev.isim.diag.screen\"")) decoded=\(decoded) " +
                      "os=\(r.environment?.osVersion.platform ?? "-")")
            }
        }
        Task {
            for await r in metricManager.diagnosticReports {
                guard case .hang(let h) = r.result else { continue }
                var frames = 0, named = 0
                h.callStackTree.forEachFrame { f in frames += 1; if f.binaryName(from: h.callStackTree) != nil { named += 1 } }
                print("diag report hang duration=\(h.hangDuration.value >= 0.5) frames=\(frames > 2) named=\(named == frames) " +
                      "states=\(r.environment.states.map(\.label).joined(separator: ",")) pid=\(r.environment.pid == getpid())")
            }
        }
    }
}
