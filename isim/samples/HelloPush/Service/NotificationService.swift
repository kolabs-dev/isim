// PushService: HelloPush's Notification Service extension. It marks the title, attaches an image it draws (a real one
// would download it) and, for payloads with "slow": true, never calls the handler so serviceExtensionTimeWillExpire runs.
import UIKit
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { contentHandler(request.content); return }
        bestAttempt = content
        content.title = "\(content.title) [modified]"
        NSLog("PushService: didReceive %@ “%@”", request.identifier, request.content.title)
        if request.content.userInfo["slow"] as? Bool == true { NSLog("PushService: slow payload, waiting"); return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hello-push.png")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { ctx in
            UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
        do {
            try image.pngData()?.write(to: url)
            content.attachments = [try UNNotificationAttachment(identifier: "image", url: url, options: nil)]
        } catch { NSLog("PushService: attachment failed: %@", "\(error)") }
        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        NSLog("PushService: serviceExtensionTimeWillExpire")
        if let handler = contentHandler, let content = bestAttempt {
            content.title = "\(content.title) (expired)"
            handler(content)
        }
    }
}
