// PushService: HelloPush's Notification Service extension. It marks the title, attaches an image it draws (a real one
// would download it) and, for payloads with "slow": true, never calls the handler so serviceExtensionTimeWillExpire runs.
// A chat payload ("sender", optionally "group") becomes a communication notification: the extension builds the message
// intent and updates the content from it (with the formatted message, UNNotificationAttributedMessageContext, on iOS 18).
import UIKit
import UserNotifications
import Intents

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { contentHandler(request.content); return }
        bestAttempt = content
        if let sender = request.content.userInfo["sender"] as? String { contentHandler(chat(content, from: sender, request.content.userInfo["group"] as? String)); return }
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

    func chat(_ content: UNMutableNotificationContent, from name: String, _ group: String?) -> UNNotificationContent {
        let sender = INPerson(personHandle: INPersonHandle(value: name, type: .unknown), nameComponents: nil, displayName: name, image: nil,
                              contactIdentifier: nil, customIdentifier: name)
        let intent = INSendMessageIntent(recipients: nil, outgoingMessageType: .outgoingMessageText, content: content.body,
                                         speakableGroupName: group.map { INSpeakableString(spokenPhrase: $0) }, conversationIdentifier: group ?? name,
                                         serviceName: nil, sender: sender, attachments: nil)
        do {
            let updated: UNNotificationContent
            if #available(iOS 18.0, *) {
                let text = NSMutableAttributedString(string: content.body)
                text.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 15), range: NSRange(location: 0, length: min(4, text.length)))
                updated = try content.updating(from: UNNotificationAttributedMessageContext(sendMessageIntent: intent, attributedContent: text))
            } else {
                updated = try content.updating(from: intent)
            }
            NSLog("PushService: communication notification title=%@ subtitle=%@", updated.title, updated.subtitle)
            return updated
        } catch {
            NSLog("PushService: updating failed: %@", "\(error)")
            return content
        }
    }

    override func serviceExtensionTimeWillExpire() {
        NSLog("PushService: serviceExtensionTimeWillExpire")
        if let handler = contentHandler, let content = bestAttempt {
            content.title = "\(content.title) (expired)"
            handler(content)
        }
    }
}
