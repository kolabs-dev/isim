// HelloAlerts: how notifications are presented on isim (UIKit, Swift, UserNotifications).
// "Later" schedules a notification 2 s ahead with a custom sound (ping.wav in the app bundle); when the app is no
// longer running by then, the system delivers it. "Chat" posts three messages in one thread (Notification Center
// stacks them, with the CHAT category's summary format), "Passive" a passive one 1 s ahead (listed quietly),
// "Critical" a critical alert 1 s ahead (the app has the entitlement and asks for .criticalAlert; it plays even in
// Silent Mode), "Poll" one whose expanded view is the
// interactive Notification Content extension AlertsPoll.appex.
import UIKit
import UserNotifications

func log(_ s: String) { NSLog("HelloAlerts: %@", s) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let like = UNNotificationAction(identifier: "like", title: "Like", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "CHAT", actions: [like], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: nil,
                                   categorySummaryFormat: "%u more messages from %@", options: []),
            UNNotificationCategory(identifier: "POLL", actions: [UNNotificationAction(identifier: "yes", title: "Yes", options: []),
                                                                 UNNotificationAction(identifier: "no", title: "No", options: [])],
                                   intentIdentifiers: [], options: []),
        ])
        center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
            log("authorization granted=\(granted)")
            center.getPendingNotificationRequests { reqs in log("pending \(reqs.map(\.identifier).sorted())") }
            center.getDeliveredNotifications { ns in log("delivered \(ns.map(\.request.identifier).sorted())") }
        }
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        log("willPresent \(notification.request.identifier)")
        completionHandler([.banner, .list, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        log("didReceive \(response.notification.request.identifier) action=\(response.actionIdentifier)")
        completionHandler()
    }
}

func post(_ id: String, title: String, body: String, after: TimeInterval? = nil, _ setup: (UNMutableNotificationContent) -> Void = { _ in }) {
    let c = UNMutableNotificationContent()
    c.title = title
    c.body = body
    c.sound = .default
    setup(c)
    let trigger = after.map { UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false) }
    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: c, trigger: trigger)) { error in
        log("added \(id) error=\(error.map { "\($0)" } ?? "nil")")
    }
}

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "Alerts"
        title.font = .boldSystemFont(ofSize: 34)
        let stack = UIStackView(arrangedSubviews: [title])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        for (label, id) in [("Later", "later"), ("Chat", "chat"), ("Passive", "passive"), ("Critical", "critical"), ("Poll", "poll")] {
            let b = UIButton(type: .system)
            b.setTitle(label, for: .normal)
            b.setTitleColor(.white, for: .normal)
            b.backgroundColor = .systemIndigo
            b.layer.cornerRadius = 10
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            b.accessibilityIdentifier = id
            b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])
    }
    @objc func tapped(_ b: UIButton) {
        switch b.accessibilityIdentifier {
        case "later":
            post("later-1", title: "Reminder", body: "Delivered by the system", after: 2) { $0.sound = UNNotificationSound(named: UNNotificationSoundName("ping.wav")) }
        case "chat":
            for (i, text) in ["Hi!", "Are you there?", "Call me"].enumerated() {
                post("chat-\(i + 1)", title: "Ann", body: text) {
                    $0.threadIdentifier = "ann"
                    $0.categoryIdentifier = "CHAT"
                    $0.summaryArgument = "Ann"
                }
            }
        case "passive":
            post("quiet-1", title: "Weekly summary", body: "No need to look now", after: 1) { $0.interruptionLevel = .passive }
        case "critical":
            post("critical-1", title: "Severe weather", body: "Take shelter", after: 1) { $0.interruptionLevel = .critical; $0.sound = .defaultCritical }
        case "poll":
            post("poll-1", title: "Lunch poll", body: "Pizza today?") { $0.categoryIdentifier = "POLL" }
        default: break
        }
    }
}
