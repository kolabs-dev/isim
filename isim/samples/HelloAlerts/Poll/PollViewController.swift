// AlertsPoll: HelloAlerts' interactive Notification Content extension for the POLL category. The Vote button counts
// taps on the extension's own view (UNNotificationExtensionUserInteractionEnabled); the media button plays / pauses;
// the actions under the notification are set here (notificationActions) and answered in didReceive(_:completionHandler:):
// Yes counts a vote and keeps the notification, Close dismisses it, Open dismisses it and forwards the action to the app.
import UIKit
import UserNotifications
import UserNotificationsUI

func log(_ s: String) { NSLog("AlertsPoll: %@", s) }

class PollViewController: UIViewController, UNNotificationContentExtension {
    let label = UILabel()
    let vote = UIButton(type: .system)
    var votes = 0
    var playing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1)
        label.font = .boldSystemFont(ofSize: 20)
        label.textColor = .white
        label.numberOfLines = 2
        label.frame = CGRect(x: 16, y: 16, width: 220, height: 56)
        view.addSubview(label)
        vote.setTitle("Vote", for: .normal)
        vote.setTitleColor(.white, for: .normal)
        vote.backgroundColor = UIColor(white: 1, alpha: 0.25)
        vote.layer.cornerRadius = 10
        vote.frame = CGRect(x: 16, y: 86, width: 100, height: 40)
        vote.accessibilityIdentifier = "vote"
        vote.addTarget(self, action: #selector(voted), for: .touchUpInside)
        view.addSubview(vote)
        update()
    }
    func update() { label.text = "Votes: \(votes)\(playing ? " ♪" : "")" }
    @objc func voted() { votes += 1; log("vote tapped (\(votes))"); update() }

    func didReceive(_ notification: UNNotification) {
        log("didReceive \(notification.request.identifier)")
        extensionContext?.notificationActions = [
            UNNotificationAction(identifier: "yes", title: "Yes", options: []),
            UNNotificationAction(identifier: "close", title: "Close", options: []),
            UNNotificationAction(identifier: "open", title: "Open", options: [.foreground]),
        ]
    }
    func didReceive(_ response: UNNotificationResponse, completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        log("response \(response.actionIdentifier)")
        switch response.actionIdentifier {
        case "yes": votes += 1; update(); completion(.doNotDismiss)
        case "close": completion(.dismiss)
        default: completion(.dismissAndForwardAction)
        }
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .default }
    var mediaPlayPauseButtonFrame: CGRect { CGRect(x: view.bounds.width - 76, y: 70, width: 56, height: 56) }
    var mediaPlayPauseButtonTintColor: UIColor { .white }
    func mediaPlay() { playing = true; log("mediaPlay"); update() }
    func mediaPause() { playing = false; log("mediaPause"); update() }
}
