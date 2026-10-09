// HelloPush: remote notifications on isim (UIKit, Swift).
// Registration (device token), foreground / background / not-running delivery of `isim push` payloads,
// content-available background fetches, notification categories with actions (text input included), a Notification
// Service extension (PushService.appex) and a Notification Content extension (PushContent.appex), icon badges, and a
// share button (the share sheet lists the installed apps' Share / Action extensions).
import UIKit
import UserNotifications

func log(_ s: String) { NSLog("HelloPush: %@", s) }
func stateName(_ a: UIApplication) -> String { a.applicationState == .background ? "background" : a.applicationState == .active ? "foreground" : "inactive" }

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    let vc = ViewController()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any]
        log("didFinishLaunching state=\(stateName(application)) remote=\(remote.map { ($0["item"] as? String) ?? "yes" } ?? "none")")
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let reply = UNTextInputNotificationAction(identifier: "reply", title: "Reply", options: [], textInputButtonTitle: "Send", textInputPlaceholder: "Message")
        let like = UNNotificationAction(identifier: "like", title: "Like", options: [])
        let open = UNNotificationAction(identifier: "open", title: "Open", options: [.foreground])
        let delete = UNNotificationAction(identifier: "delete", title: "Delete", options: [.destructive])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "MESSAGE", actions: [reply, like, open, delete], intentIdentifiers: [], options: [.customDismissAction]),
            UNNotificationCategory(identifier: "NEWS", actions: [like], intentIdentifiers: [], options: []),
        ])
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            log("authorization granted=\(granted)")
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        log("device token \(hex) (\(deviceToken.count) bytes) registered=\(application.isRegisteredForRemoteNotifications)")
        vc.token.text = "Token \(hex.prefix(12))…"
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log("registration failed: \(error.localizedDescription)")
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let item = userInfo["item"] as? String ?? "-"
        log("didReceiveRemoteNotification state=\(stateName(application)) item=\(item)")
        UserDefaults.standard.set(item, forKey: "lastItem")
        vc.last.text = "Fetched \(item)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { completionHandler(.newData) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let c = notification.request.content
        log("willPresent “\(c.title)” push=\(notification.request.trigger is UNPushNotificationTrigger) category=\(c.categoryIdentifier) attachments=\(c.attachments.count)")
        completionHandler([.banner, .list, .badge, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let text = (response as? UNTextInputNotificationResponse)?.userText
        let c = response.notification.request.content
        log("response \(response.actionIdentifier) to “\(c.title)” id=\(response.notification.request.identifier) text=\(text ?? "-") state=\(stateName(UIApplication.shared))")
        vc.last.text = "\(response.actionIdentifier.components(separatedBy: ".").last ?? "") \(text ?? c.title)"
        completionHandler()
    }
}

class ViewController: UIViewController {
    let token = UILabel(), last = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Push"; title.font = .boldSystemFont(ofSize: 32)
        token.text = "Not registered"; token.accessibilityIdentifier = "token"
        last.text = "No notification"; last.accessibilityIdentifier = "last"; last.numberOfLines = 2
        let stack = UIStackView(arrangedSubviews: [title, token, last,
            button("Badge 5", "badge5") { UNUserNotificationCenter.current().setBadgeCount(5) { e in log("setBadgeCount 5 error=\(e.map { "\($0)" } ?? "nil")") } },
            button("Clear Badge", "badge0") { UNUserNotificationCenter.current().setBadgeCount(0) { _ in log("badge cleared") } },
            button("Local Notification", "local") { [weak self] in self?.scheduleLocal() },
            button("Share", "share") { [weak self] in self?.share() }])
        stack.axis = .vertical; stack.spacing = 12; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }
    func button(_ t: String, _ id: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system, primaryAction: UIAction(title: t) { _ in action() })
        b.accessibilityIdentifier = id
        b.titleLabel?.font = .systemFont(ofSize: 20)
        return b
    }
    func scheduleLocal() {
        let c = UNMutableNotificationContent()
        c.title = "Local message"; c.body = "Scheduled by HelloPush"; c.categoryIdentifier = "MESSAGE"
        let r = UNNotificationRequest(identifier: "local-1", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
        UNUserNotificationCenter.current().add(r) { e in log("scheduled local-1 error=\(e.map { "\($0)" } ?? "nil")") }
    }
    func share() {
        let avc = UIActivityViewController(activityItems: ["Hello from Push", URL(string: "https://example.com/push")!], applicationActivities: nil)
        avc.completionWithItemsHandler = { type, completed, items, error in
            log("share finished type=\(type?.rawValue ?? "nil") completed=\(completed) returned=\(items?.count ?? 0)")
        }
        present(avc, animated: true)
    }
}
