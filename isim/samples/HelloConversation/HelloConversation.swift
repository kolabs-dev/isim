// Sample: a calling app with LiveCommunicationKit (issue #404). Its ConversationManager reports an incoming
// conversation (the system call UI shows it), places an outgoing one, and performs what the user does in the call
// screen (join, mute, pause, tones, end) as conversation actions; on iOS 26 it lists its recents. Every step is
// printed ("lc ...").
import UIKit
import LiveCommunicationKit
import AVFoundation

func log(_ s: String) { print("lc \(s)"); fflush(stdout) }
let incomingID = UUID(uuidString: "7A1C3A52-2B8E-4C59-9D34-1A2B3C4D5E02")!
let outgoingID = UUID(uuidString: "7A1C3A52-2B8E-4C59-9D34-1A2B3C4D5E03")!

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 17.4, *) {
            window?.rootViewController = UINavigationController(rootViewController: CallsViewController())
        } else {
            window?.rootViewController = UIViewController()
            log("needs iOS 17.4")
        }
        window?.makeKeyAndVisible()
        return true
    }
}

@available(iOS 17.4, *)
final class CallsViewController: UIViewController, ConversationManagerDelegate, @unchecked Sendable {
    let ana = Handle(type: .phoneNumber, value: "+15550100", displayName: "Ana Lima")
    let manager = ConversationManager(configuration: .init(ringtoneName: nil, iconTemplateImageData: nil, maximumConversationGroups: 2,
                                                          maximumConversationsPerConversationGroup: 1, includesConversationInRecents: true,
                                                          supportsVideo: true, supportedHandleTypes: [.phoneNumber]))
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Conversations"
        view.backgroundColor = .systemBackground
        manager.delegate = self
        var y: CGFloat = 120
        for (id, t) in [("incoming", "Incoming from Ana"), ("outgoing", "Call Ana"), ("connected", "Outgoing Connected"),
                        ("hangup", "End Outgoing"), ("remote-end", "Ana Hangs Up"), ("recents", "Recents")] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.frame = CGRect(x: 20, y: y, width: 260, height: 40)
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.tap(id) }, for: .primaryActionTriggered)
            view.addSubview(b)
            y += 50
        }
    }
    func tap(_ id: String) {
        Task { @MainActor in
            switch id {
            case "incoming":
                do {
                    try await manager.reportNewIncomingConversation(uuid: incomingID, update: .init(members: [ana], activeRemoteMembers: [ana],
                                                                                                    capabilities: [.pausing, .playingTones]))
                    log("reported incoming")
                } catch { log("incoming failed \(error)") }
                do {                                                   // the same UUID again: refused
                    try await manager.reportNewIncomingConversation(uuid: incomingID, update: .init(members: [ana]))
                } catch { log("duplicate refused \((error as NSError).code)") }
            case "outgoing":
                do {
                    try await manager.perform([StartConversationAction(conversationUUID: outgoingID, handles: [ana], isVideo: false)])
                    log("start requested")
                } catch { log("start failed \(error)") }
            case "connected":
                guard let c = manager.conversations.first(where: { $0.uuid == outgoingID }) else { log("no outgoing"); return }
                manager.reportConversationEvent(.conversationStartedConnecting(Date()), for: c)
                manager.reportConversationEvent(.conversationConnected(Date()), for: c)
            case "hangup":
                do { try await manager.perform([EndConversationAction(conversationUUID: outgoingID)]) } catch { log("end failed \(error)") }
            case "remote-end":
                guard let c = manager.conversations.first(where: { $0.uuid == incomingID }) else { log("no incoming"); return }
                manager.reportConversationEvent(.conversationEnded(Date(), .remoteEnded), for: c)
            default:
                if #available(iOS 26.0, *) {
                    let all = try? await ConversationHistoryManager.sharedInstance.recentConversations(matching: #Predicate { _ in true })
                    let unread = try? await ConversationHistoryManager.sharedInstance.recentConversations(matching: #Predicate { !$0.isRead })
                    log("recents \(all?.map { "\($0.direction):\($0.status):\($0.handles.first?.displayName ?? "-")" } ?? []) unread=\(unread?.count ?? -1)")
                    if let unread { try? await ConversationHistoryManager.sharedInstance.markConversationsAsRead(unread) }
                    let after = try? await ConversationHistoryManager.sharedInstance.recentConversations(matching: #Predicate { !$0.isRead })
                    log("unread after marking \(after?.count ?? -1)")
                    log("cellular services \(TelephonyConversationManager.sharedInstance.cellularServices.count)")
                } else { log("recents need iOS 26") }
            }
        }
    }

    // MARK: ConversationManagerDelegate
    func conversationManagerDidBegin(_ manager: ConversationManager) { log("began") }
    func conversationManagerDidReset(_ manager: ConversationManager) { log("reset") }
    func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {
        log("changed \(conversation.uuid.uuidString.prefix(8)) state=\(conversation.state) muted=\(conversation.isMuted) count=\(manager.conversations.count)")
    }
    func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
        switch action {
        case let a as JoinConversationAction: log("perform join"); a.fulfill(dateConnected: Date())
        case let a as EndConversationAction: log("perform end \(a.conversationUUID.uuidString.prefix(8))"); a.fulfill(dateEnded: Date())
        case let a as MuteConversationAction: log("perform mute \(a.isMuted)"); a.fulfill()
        case let a as PauseConversationAction: log("perform pause \(a.isPaused)"); a.fulfill()
        case let a as PlayToneAction: log("perform tones \(a.digits)"); a.fulfill()
        case let a as StartConversationAction: log("perform start \(a.handles.map(\.displayName))"); a.fulfill(dateStarted: Date())
        default: log("perform other"); action.fail()
        }
    }
    func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) { log("timed out \(action)") }
    func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) { log("audio session activated") }
    func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) { log("audio session deactivated") }
}
