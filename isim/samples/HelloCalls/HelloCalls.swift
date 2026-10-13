// HelloCalls: VoIP calls on isim (UIKit, Swift, PushKit + CallKit).
// A PKPushRegistry for VoIP pushes (`isim push dev.isim.samples.HelloCalls payloads/incoming.apns`): each push reports
// a new incoming call to CallKit, which shows the system's incoming call UI (a banner, or full screen on the Lock
// Screen) and the call screen once answered. The provider's delegate logs and fulfills every action (answer, end,
// mute, hold, DTMF), and the audio session is activated / deactivated by the system. The buttons place an outgoing
// call through CXCallController (connecting, then connected), end it, mute it, "hang up from the other side"
// (reportCall(with:endedAt:reason:)), make invalid requests, and ask for the Call Directory extension's state.
// payloads/noreport.apns is a VoIP push the app does not report a call for: like iOS, the system terminates it.
import UIKit
import PushKit
import CallKit
import AVFoundation

func log(_ s: String) { NSLog("HelloCalls: %@", s) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate, CXProviderDelegate, CXCallObserverDelegate {
    var window: UIWindow?
    let vc = ViewController()
    let registry = PKPushRegistry(queue: .main)
    let provider: CXProvider = {
        let c = CXProviderConfiguration()
        c.supportsVideo = true
        c.maximumCallGroups = 2
        c.supportedHandleTypes = [.generic, .phoneNumber, .emailAddress]
        return CXProvider(configuration: c)
    }()
    let controller = CXCallController()
    var current: UUID?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log("didFinishLaunching state=\(application.applicationState == .background ? "background" : "foreground")")
        provider.setDelegate(self, queue: nil)
        controller.callObserver.setDelegate(self, queue: nil)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        vc.app = self
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }

    // MARK: PushKit
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let hex = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        log("voip token \(hex) (\(pushCredentials.token.count) bytes) same=\(registry.pushToken(for: .voIP) == pushCredentials.token)")
    }
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        let p = payload.dictionaryPayload
        log("voip push type=\(type == .voIP ? "voip" : type.rawValue) caller=\(p["caller"] as? String ?? "-")")
        if p["noreport"] as? Bool == true { log("not reporting a call"); completion(); return }
        let uuid = (p["uuid"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: (p["handle"] as? String ?? "").hasPrefix("+") ? .phoneNumber : .emailAddress, value: p["handle"] as? String ?? "unknown")
        update.localizedCallerName = p["caller"] as? String
        update.hasVideo = p["video"] as? Bool ?? false
        update.supportsHolding = true
        update.supportsDTMF = true
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            log("reported incoming call \(uuid.uuidString) error=\(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "nil")")
            if error == nil { self.current = uuid }
            completion()
        }
    }

    // MARK: CallKit provider
    func providerDidReset(_ provider: CXProvider) { log("provider reset") }
    func providerDidBegin(_ provider: CXProvider) { log("provider began") }
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        log("perform start \(action.handle.value) video=\(action.isVideo)")
        action.fulfill()
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
        }
    }
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        log("perform answer \(action.callUUID.uuidString)")
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        log("perform end \(action.callUUID.uuidString)")
        if current == action.callUUID { current = nil }
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        log("perform mute \(action.isMuted)")
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        log("perform hold \(action.isOnHold)")
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        log("perform dtmf \(action.digits)")
        action.fulfill()
    }
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) { log("audio session activated") }
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) { log("audio session deactivated") }

    // MARK: CXCallObserver
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        log("observer \(call.uuid.uuidString.prefix(8)) outgoing=\(call.isOutgoing) connected=\(call.hasConnected) hold=\(call.isOnHold) ended=\(call.hasEnded) calls=\(callObserver.calls.count)")
        DispatchQueue.main.async { self.vc.status.text = callObserver.calls.isEmpty ? "No calls" : "\(callObserver.calls.count) call(s)" }
    }

    // MARK: the buttons
    func request(_ actions: [CXAction], _ what: String) {
        controller.requestTransaction(with: actions) { error in
            log("request \(what) error=\(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "nil")")
        }
    }
    func callOut() {
        let uuid = UUID()
        current = uuid
        let a = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: "Bob"))
        request([a], "start")
    }
    func endCall() {
        guard let u = current else { log("no call to end"); return }
        request([CXEndCallAction(call: u)], "end")
    }
    func mute() {
        guard let u = current else { return }
        request([CXSetMutedCallAction(call: u, muted: true)], "mute")
    }
    func remoteEnd() {
        guard let u = current else { return }
        provider.reportCall(with: u, endedAt: Date(), reason: .remoteEnded)
        current = nil
    }
    func badRequests() {
        request([], "empty")
        request([CXEndCallAction(call: UUID())], "unknown")
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: "dev.isim.samples.HelloCalls.Directory") { status, error in
            log("directory status=\(status.rawValue) error=\(error.map { "\(($0 as NSError).code)" } ?? "nil")")
        }
    }
}

class ViewController: UIViewController {
    weak var app: AppDelegate?
    let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "Calls"
        title.font = .boldSystemFont(ofSize: 34)
        status.text = "No calls"
        status.textColor = .secondaryLabel
        status.accessibilityIdentifier = "status"
        let stack = UIStackView(arrangedSubviews: [title, status])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        for (label, id, action) in [("Call Bob", "call-out", #selector(callOut)), ("End Call", "end-call", #selector(endCall)),
                                    ("Mute", "mute", #selector(mute)), ("Other Side Hangs Up", "remote-end", #selector(remoteEnd)),
                                    ("Invalid Requests", "bad-requests", #selector(badRequests))] {
            let b = UIButton(type: .system)
            b.setTitle(label, for: .normal)
            b.setTitleColor(.white, for: .normal)
            b.backgroundColor = id == "end-call" || id == "remote-end" ? .systemRed : .systemGreen
            b.layer.cornerRadius = 10
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            b.accessibilityIdentifier = id
            b.addTarget(self, action: action, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])
    }
    @objc func callOut() { app?.callOut() }
    @objc func endCall() { app?.endCall() }
    @objc func mute() { app?.mute() }
    @objc func remoteEnd() { app?.remoteEnd() }
    @objc func badRequests() { app?.badRequests() }
}
