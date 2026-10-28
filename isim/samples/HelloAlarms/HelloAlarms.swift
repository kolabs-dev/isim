// Sample: alarms and timers with AlarmKit (issue #405). Asks to schedule alarms, starts a tea timer (a countdown
// with a Live Activity, paused and resumed, its alert's Repeat starts the post-alert countdown again), schedules an
// alarm a few seconds ahead (its Stop runs an intent), and a weekly alarm that is listed and cancelled. Every step is
// printed ("ak ...").
import UIKit
import SwiftUI
import AppIntents
import AlarmKit

func log(_ s: String) { print("ak \(s)"); fflush(stdout) }
let teaID = UUID(uuidString: "A1A2A3A4-0000-4000-8000-000000000001")!
let wakeID = UUID(uuidString: "A1A2A3A4-0000-4000-8000-000000000002")!
let weeklyID = UUID(uuidString: "A1A2A3A4-0000-4000-8000-000000000003")!

/// runs in the app when the user stops the wake-up alarm
@available(iOS 26.0, *)
struct StopWakeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Wake-Up"
    init() {}
    func perform() async throws -> some IntentResult { log("intent stop"); return .result() }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 26.0, *) {
            window?.rootViewController = UINavigationController(rootViewController: AlarmsViewController())
        } else {
            window?.rootViewController = UIViewController()
            log("needs iOS 26")
        }
        window?.makeKeyAndVisible()
        return true
    }
}

@available(iOS 26.0, *)
final class AlarmsViewController: UIViewController {
    let manager = AlarmManager.shared
    let status = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Wake"
        view.backgroundColor = .systemBackground
        var y: CGFloat = 120
        for (id, t) in [("authorize", "Allow Alarms"), ("tea", "Tea Timer"), ("pause", "Pause"), ("resume", "Resume"),
                        ("wake", "Wake Up Soon"), ("weekly", "Weekdays 7:30"), ("list", "List"), ("cancel", "Cancel Weekly")] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.frame = CGRect(x: 20, y: y, width: 260, height: 40)
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.tap(id) }, for: .primaryActionTriggered)
            view.addSubview(b)
            y += 48
        }
        status.frame = CGRect(x: 20, y: y + 10, width: view.bounds.width - 40, height: 60)
        status.numberOfLines = 0
        status.accessibilityIdentifier = "status"
        view.addSubview(status)
        log("authorization \(manager.authorizationState)")
        Task { @MainActor in
            for await alarms in manager.alarmUpdates {
                let s = alarms.sorted { $0.id.uuidString < $1.id.uuidString }.map { "\(name($0.id))=\($0.state)" }.joined(separator: " ")
                status.text = s.isEmpty ? "No alarms" : s
                log("update [\(s)]")
            }
        }
    }
    func name(_ id: UUID) -> String { id == teaID ? "tea" : id == wakeID ? "wake" : id == weeklyID ? "weekly" : id.uuidString }

    var teaAttributes: AlarmAttributes<TeaData> {
        let stop = AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark")
        let repeatButton = AlarmButton(text: "Repeat", textColor: .white, systemImageName: "repeat")
        let pause = AlarmButton(text: "Pause", textColor: .orange, systemImageName: "pause.fill")
        let resume = AlarmButton(text: "Resume", textColor: .orange, systemImageName: "play.fill")
        let p = AlarmPresentation(alert: .init(title: "Tea is ready", stopButton: stop, secondaryButton: repeatButton, secondaryButtonBehavior: .countdown),
                                  countdown: .init(title: "Steeping", pauseButton: pause),
                                  paused: .init(title: "Paused", resumeButton: resume))
        return AlarmAttributes(presentation: p, metadata: TeaData(tea: "Sencha"), tintColor: .orange)
    }
    func plain(_ title: LocalizedStringResource) -> AlarmAttributes<TeaData> {
        AlarmAttributes(presentation: AlarmPresentation(alert: .init(title: title, stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"))),
                        tintColor: .blue)
    }

    func tap(_ id: String) {
        Task { @MainActor in
            do {
                switch id {
                case "authorize":
                    log("authorization \(try await manager.requestAuthorization())")
                case "tea":
                    let c = AlarmManager.AlarmConfiguration(countdownDuration: .init(preAlert: 3, postAlert: 2), attributes: teaAttributes)
                    let a = try await manager.schedule(id: teaID, configuration: c)
                    log("scheduled tea \(a.state) pre=\(Int(a.countdownDuration?.preAlert ?? 0)) post=\(Int(a.countdownDuration?.postAlert ?? 0))")
                case "pause": try manager.pause(id: teaID); log("paused tea")
                case "resume": try manager.resume(id: teaID); log("resumed tea")
                case "wake":
                    let c = AlarmManager.AlarmConfiguration<TeaData>.alarm(schedule: .fixed(Date().addingTimeInterval(2)), attributes: plain("Wake up"),
                                                                           stopIntent: StopWakeIntent())
                    let a = try await manager.schedule(id: wakeID, configuration: c)
                    if case .fixed = a.schedule { log("scheduled wake \(a.state) fixed") }
                case "weekly":
                    let r = Alarm.Schedule.Relative(time: .init(hour: 7, minute: 30), repeats: .weekly([.monday, .tuesday, .wednesday, .thursday, .friday]))
                    let a = try await manager.schedule(id: weeklyID, configuration: .alarm(schedule: .relative(r), attributes: plain("Weekday alarm")))
                    if case .relative(let s) = a.schedule, case .weekly(let d) = s.repeats { log("scheduled weekly \(a.state) \(s.time.hour):\(s.time.minute) days=\(d.count)") }
                case "list":
                    log("list \(try manager.alarms.map { name($0.id) }.sorted().joined(separator: ","))")
                case "cancel": try manager.cancel(id: weeklyID); log("cancelled weekly")
                default: break
                }
            } catch { log("\(id) failed: \(error)") }
        }
    }
}
