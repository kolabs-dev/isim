// PushContent: HelloPush's Notification Content extension for the MESSAGE category: an orange card with the message.
import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)
        label.numberOfLines = 0
        label.font = .boldSystemFont(ofSize: 22)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
        ])
    }

    func didReceive(_ notification: UNNotification) {
        label.text = "Custom UI\n\(notification.request.content.body)"
        NSLog("PushContent: didReceive %@ (%@)", notification.request.identifier, notification.request.content.categoryIdentifier)
    }
}
