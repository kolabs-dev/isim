// HelloSharePlay: watching a video together over SharePlay (GroupActivities, issue #392). Two isim devices in one
// simulated call (`shareplay join NAME`, or ISIM_SHAREPLAY_CALL) run it: one starts the WatchTogether activity
// (prepareForActivation asks first), both get its session and join; they chat through a GroupSessionMessenger
// (reliable and unreliable), share a note through the session's GroupSessionJournal, change the activity's movie, and
// their AVPlayers stay in step through AVPlaybackCoordinator.coordinateWithSession. GroupActivitySharingController
// starts SharePlay from the app. Each step logs a "HelloSharePlay:" line.
import UIKit
import AVFoundation
import Combine
import GroupActivities

private func log(_ s: String) { NSLog("HelloSharePlay: %@", s) }

struct WatchTogether: GroupActivity {
    var movie: String
    var metadata: GroupActivityMetadata {
        var m = GroupActivityMetadata()
        m.title = movie
        m.subtitle = "Movie night"
        m.type = .watchTogether
        m.fallbackURL = URL(string: "https://isim.dev/movies")
        return m
    }
}

struct Chat: Codable, Sendable { var text: String }
struct Reaction: Codable, Sendable, CustomMessageIdentifiable {
    static var messageIdentifier: String { "dev.isim.reaction" }
    var emoji: String
}
struct NoteInfo: Codable, Sendable { var author: String }

final class ViewController: UIViewController, AVPlaybackCoordinatorPlaybackControlDelegate, AVPlayerPlaybackCoordinatorDelegate {
    let player = AVPlayer(url: Bundle.main.url(forResource: "movie", withExtension: "mp4")!)
    let status = UILabel()
    let observer = GroupStateObserver()
    var session: GroupSession<WatchTogether>?
    var messenger: GroupSessionMessenger?
    var unreliable: GroupSessionMessenger?
    var journal: GroupSessionJournal?
    var subs: Set<AnyCancellable> = []
    var tasks: [Task<Void, Never>] = []
    var rateObservation: NSKeyValueObservation?
    /// -delegating: the app plays the commands of an AVDelegatingPlaybackCoordinator itself (as a custom player would)
    let delegating = ProcessInfo.processInfo.arguments.contains("-delegating")
    var delegatingCoordinator: AVDelegatingPlaybackCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 16, y: 70, width: view.bounds.width - 32, height: (view.bounds.width - 32) * 9 / 16)
        view.layer.addSublayer(playerLayer)
        status.frame = CGRect(x: 16, y: playerLayer.frame.maxY + 8, width: view.bounds.width - 32, height: 24)
        status.textAlignment = .center
        status.text = "Not sharing"
        view.addSubview(status)
        let buttons: [(String, String, Selector)] = [
            ("Start SharePlay", "start", #selector(start)), ("Share…", "share", #selector(share)),
            ("Send Message", "send", #selector(send)), ("Attach Note", "attach", #selector(attach)),
            ("Play", "play", #selector(play)), ("Pause", "pause", #selector(pause)),
            ("Next Movie", "next", #selector(nextMovie)), ("Leave", "leave", #selector(leave)), ("End for Everyone", "end", #selector(end)),
        ]
        let stack = UIStackView(arrangedSubviews: buttons.map { title, id, sel in
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            return b
        })
        stack.axis = .vertical
        stack.spacing = 4
        stack.frame = CGRect(x: 16, y: status.frame.maxY + 8, width: view.bounds.width - 32, height: 9 * 40)
        stack.distribution = .fillEqually
        view.addSubview(stack)

        if ProcessInfo.processInfo.arguments.contains("-medium") { coordinateLocally(); return }
        log("identifier \(WatchTogether.activityIdentifier)")
        observer.$isEligibleForGroupSession.removeDuplicates().sink { log("eligible \($0)") }.store(in: &subs)
        rateObservation = player.observe(\.rate, options: [.new]) { p, _ in
            DispatchQueue.main.async { log(String(format: "player rate %.1f at %.1f", p.rate, p.currentTime().seconds)) }
        }
        tasks.append(Task { @MainActor in
            for await s in WatchTogether.sessions() { self.configure(s) }
        })
        // the position each second while playing
        _ = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: .main) { [weak self] t in
            guard let self, self.player.rate > 0 else { return }
            log(String(format: "playing at %.1f", t.seconds))
        }
    }

    func configure(_ s: GroupSession<WatchTogether>) {
        log("session \(s.activity.movie) local \(s.isLocallyInitiated)")
        for t in tasks.dropFirst() { t.cancel() }
        tasks = Array(tasks.prefix(1))
        session = s
        let m = GroupSessionMessenger(session: s)
        let u = GroupSessionMessenger(session: s, deliveryMode: .unreliable)
        let j = GroupSessionJournal(session: s)
        messenger = m; unreliable = u; journal = j
        s.$state.sink { [weak self] state in
            switch state {
            case .waiting: log("state waiting")
            case .joined: log("state joined"); self?.status.text = "SharePlay: \(s.activity.movie)"
            case .invalidated(let reason): log("state invalidated: \(reason)"); self?.status.text = "Not sharing"; self?.session = nil
            @unknown default: break
            }
        }.store(in: &subs)
        s.$activeParticipants.map(\.count).removeDuplicates().sink { log("participants \($0)") }.store(in: &subs)
        s.$activity.map(\.movie).removeDuplicates().dropFirst().sink { [weak self] movie in
            log("activity \(movie)"); self?.status.text = "SharePlay: \(movie)"
        }.store(in: &subs)
        tasks.append(Task { @MainActor in
            for await (chat, context) in m.messages(of: Chat.self) {
                log("chat \(chat.text) from other \(context.source != s.localParticipant)")
            }
        })
        tasks.append(Task { @MainActor in
            for await (r, _) in u.messages(of: Reaction.self) { log("reaction \(r.emoji)") }
        })
        tasks.append(Task { @MainActor in
            for await attachments in j.attachments {
                log("attachments \(attachments.count)")
                for a in attachments {
                    let text = (try? await a.load(String.self)) ?? "?"
                    let info = try? await a.loadMetadata(of: NoteInfo.self)
                    log("note \(text) by \(info?.author ?? "?")")
                }
            }
        })
        if delegating {
            let d = AVDelegatingPlaybackCoordinator(playbackControlDelegate: self)
            d.transitionToItem(withIdentifier: "movie", proposingInitialTimingBasedOn: nil)
            d.coordinateWithSession(s)
            delegatingCoordinator = d
        } else {
            player.playbackCoordinator.delegate = self      // names the item as the participants know it
            player.playbackCoordinator.coordinateWithSession(s)
        }
        s.join()
    }

    /// -medium: two players in this app kept in step by an AVPlaybackCoordinationMedium (iOS 26)
    var second: AVPlayer?
    func coordinateLocally() {
        let medium = AVPlaybackCoordinationMedium()
        let other = AVPlayer(url: Bundle.main.url(forResource: "movie", withExtension: "mp4")!)
        second = other
        do {
            try player.playbackCoordinator.coordinate(using: medium)
            try other.playbackCoordinator.coordinate(using: medium)
        } catch { log("medium failed \(error)"); return }
        log("medium coordinators \(medium.connectedPlaybackCoordinators.count) others \(player.playbackCoordinator.otherParticipants.count)")
        rateObservation = other.observe(\.rate, options: [.new]) { p, _ in
            DispatchQueue.main.async { log(String(format: "medium second rate %.1f at %.1f", p.rate, p.currentTime().seconds)) }
        }
        player.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.player.pause()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let a = self.player.currentTime().seconds, b = other.currentTime().seconds
                log(String(format: "medium paused first %.1f second %.1f rate %.1f", a, b, other.rate))
            }
        }
    }

    @objc func start() {
        Task { @MainActor in
            let activity = WatchTogether(movie: "Big Buck Bunny")
            let result = await activity.prepareForActivation()
            log("prepare \(result)")
            guard result == .activationPreferred else { return }
            let ok = (try? await activity.activate()) ?? false
            log("activated \(ok)")
        }
    }
    @objc func share() {
        let c = try! GroupActivitySharingController(WatchTogether(movie: "Sintel"))
        present(c, animated: true)
        Task { @MainActor in
            while c.presentingViewController != nil { try? await Task.sleep(nanoseconds: 50_000_000) }
            log("sharing result \(c.result)")
        }
    }
    @objc func send() {
        guard let s = session, let m = messenger, let u = unreliable else { log("no session"); return }
        Task { @MainActor in
            do {
                try await m.send(Chat(text: "Popcorn ready?"))
                try await u.send(Reaction(emoji: "🍿"), to: .all)
                s.postEvent(GroupSession<WatchTogether>.Event(originator: s.localParticipant, localizedDescription: "started chatting"))
                log("sent")
            } catch { log("send failed \(error)") }
        }
    }
    @objc func attach() {
        guard let j = journal else { log("no session"); return }
        Task { @MainActor in
            do { _ = try await j.add("Popcorn at 8", metadata: NoteInfo(author: "host")); log("attached") }
            catch { log("attach failed \(error)") }
        }
    }
    @objc func play() { if let d = delegatingCoordinator { d.coordinateRateChange(to: 1) } else { player.play() } }
    @objc func pause() { if let d = delegatingCoordinator { d.coordinateRateChange(to: 0) } else { player.pause() } }

    func playbackCoordinator(_ coordinator: AVPlayerPlaybackCoordinator, identifierFor playerItem: AVPlayerItem) -> String { "movie" }

    // MARK: AVPlaybackCoordinatorPlaybackControlDelegate (-delegating)

    func playbackCoordinator(_ coordinator: AVDelegatingPlaybackCoordinator, didIssue playCommand: AVDelegatingPlaybackCoordinatorPlayCommand,
                             completionHandler: @escaping () -> Void) {
        log(String(format: "command play rate %.1f at %.1f item %@", playCommand.rate, playCommand.itemTime.seconds, playCommand.expectedCurrentItemIdentifier))
        player.seek(to: playCommand.itemTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            self.player.rate = playCommand.rate
            completionHandler()
        }
    }
    func playbackCoordinator(_ coordinator: AVDelegatingPlaybackCoordinator, didIssue pauseCommand: AVDelegatingPlaybackCoordinatorPauseCommand,
                             completionHandler: @escaping () -> Void) {
        log("command pause")
        player.pause()
        completionHandler()
    }
    func playbackCoordinator(_ coordinator: AVDelegatingPlaybackCoordinator, didIssue seekCommand: AVDelegatingPlaybackCoordinatorSeekCommand,
                             completionHandler: @escaping () -> Void) {
        log(String(format: "command seek to %.1f", seekCommand.itemTime.seconds))
        player.seek(to: seekCommand.itemTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in completionHandler() }
    }
    @objc func nextMovie() { session?.activity = WatchTogether(movie: "Tears of Steel") }
    @objc func leave() { session?.leave() }
    @objc func end() { session?.end() }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
