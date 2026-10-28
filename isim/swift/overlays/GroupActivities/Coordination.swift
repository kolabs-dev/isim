// isim GroupActivities: the sharing controller (start SharePlay from the app), media playback coordinated over a
// session (AVPlaybackCoordinator.coordinateWithSession), and the spatial coordination types (visionOS's; on iOS a
// session has no SystemCoordinator, so they are stubs).
import Foundation
import UIKit
import AVFoundation
import Spatial

// MARK: - Sharing controller

public enum GroupActivitySharingResult: Sendable, Equatable {
    case success
    case cancelled
}

/// A sheet that starts SharePlay with an activity. isim: it joins the simulated call (ISIM_SHAREPLAY_CALL, else the
/// call named "isim") and shares the activity there.
@MainActor open class GroupActivitySharingController: UIViewController {
    public private(set) var result: GroupActivitySharingResult = .cancelled
    let _activate: () async throws -> Bool
    let _title: () async -> String?
    let _start = UIButton(type: .system)

    public init<ActivityType: GroupActivity>(_ activity: ActivityType) throws {
        _activate = { try await activity.activate() }
        _title = { await activity.metadata.title }
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
    }
    public init<ActivityType: GroupActivity>(preparationHandler: @escaping @Sendable () async throws -> ActivityType) {
        _activate = { try await preparationHandler().activate() }
        _title = { nil }
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }


    open override func loadView() {
        view = UIView()
        view.backgroundColor = .systemGroupedBackground
    }
    open override func viewDidLoad() {
        super.viewDidLoad()
        let icon = UIImageView(image: UIImage(systemName: "shareplay") ?? UIImage(systemName: "person.2.fill"))
        icon.tintColor = .systemGreen
        icon.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = "SharePlay"
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textAlignment = .center
        let subtitle = UILabel()
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center
        subtitle.textColor = .secondaryLabel
        subtitle.font = .preferredFont(forTextStyle: .body)
        subtitle.text = "Start a SharePlay session with the people in isim's simulated call."
        _start.setTitle("Start SharePlay", for: .normal)
        _start.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        _start.backgroundColor = .systemGreen
        _start.setTitleColor(.white, for: .normal)
        _start.layer.cornerRadius = 14
        _start.accessibilityIdentifier = "shareplay-start"
        _start.addTarget(self, action: #selector(_startTapped), for: .touchUpInside)
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 17)
        cancel.accessibilityIdentifier = "shareplay-cancel"
        cancel.addTarget(self, action: #selector(_cancelTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle, _start, cancel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(28, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 64),
            _start.heightAnchor.constraint(equalToConstant: 50),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        Task { @MainActor in if let t = await _title() { subtitle.text = "Start “\(t)” with the people in isim's simulated call." } }
    }
    open override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated) }

    @objc func _startTapped() {
        _start.isEnabled = false
        if _SPBus.shared.call == nil { _SPBus.shared.setCall(_SPBus.env("ISIM_SHAREPLAY_CALL") ?? "isim") }
        Task { @MainActor in
            let ok = (try? await _activate()) ?? false
            result = ok ? .success : .cancelled
            NSLog("isim GroupActivities: sharing controller %@", ok ? "started SharePlay" : "could not start SharePlay")
            DispatchQueue.main.async { self.dismiss(animated: true, completion: nil) }
        }
    }
    @objc func _cancelTapped() {
        result = .cancelled
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Media playback over a session

/// carries an AVPlaybackCoordinator's state over a session's messages
final class _SPAVTransport: NSObject, _AVCoordinationTransport {
    weak var coordinator: AVPlaybackCoordinator?
    let send: ([String: Any]) -> Void
    let others: () -> [UUID]
    var lastOthers: [UUID] = []
    init(coordinator: AVPlaybackCoordinator, send: @escaping ([String: Any]) -> Void, others: @escaping () -> [UUID]) {
        self.coordinator = coordinator; self.send = send; self.others = others
    }
    func _send(_ state: [String: Any], from coordinator: AVPlaybackCoordinator) { send(state) }
    var _otherParticipants: [UUID] { others() }
}

nonisolated(unsafe) private var _spTransportKey = 0

extension AVPlaybackCoordinator {
    /// Keeps this coordinator's playback in step with the session's other participants: play, pause, seek and rate
    /// changes on one device are applied on the others.
    public func coordinateWithSession<T: GroupActivity>(_ session: GroupSession<T>) {
        let me = session.localParticipant.id
        let t = _SPAVTransport(coordinator: self, send: { [weak session] s in
            guard let session, let d = try? JSONSerialization.data(withJSONObject: s) else { return }
            session._send(type: "isim.av", mode: "reliable", data: d, to: .all)
        }, others: { [weak session] in
            (session?.activeParticipants ?? []).map(\.id).filter { $0 != me }.sorted { $0.uuidString < $1.uuidString }
        })
        objc_setAssociatedObject(self, &_spTransportKey, t, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        _localID = me
        _transport = t
        let setup = { [weak self, weak session, weak t] in
            guard let session else { return }
            session._avTransports.append { [weak self] _, d in self?._receive(d); return self != nil }
            // a participant joining gets the current state; the participants list follows the session's
            var sub: AnyObject?
            sub = session.$activeParticipants.sink { [weak self, weak t] _ in
                DispatchQueue.main.async {
                    guard let self, let t else { _ = sub; return }
                    let now = t.others()
                    if now != t.lastOthers {
                        let joined = !Set(now).subtracting(t.lastOthers).isEmpty
                        t.lastOthers = now
                        self._participantsChanged()
                        if joined { self._sendCurrentState() }
                    }
                }
            } as AnyObject
            if let t { objc_setAssociatedObject(t, &_spTransportKey, sub, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
        }
        if Thread.isMainThread { setup() } else { DispatchQueue.main.async(execute: setup) }
        NSLog("isim GroupActivities: playback coordinated with session %@", String(session.id.uuidString.prefix(8)))
    }
}

// MARK: - Spatial coordination (visionOS; stubs on iOS)

/// Arranges participants' spatial Personas (visionOS). isim: a session has none on iOS (systemCoordinator is nil).
public final class SystemCoordinator: @unchecked Sendable {
    init() {}
    public var configuration = Configuration()
    public var localParticipantState: ParticipantState { ParticipantState(isSpatial: false, pose: nil, role: nil, seat: nil) }
    public var remoteParticipantStates: [Participant: ParticipantState] { [:] }
    public var localParticipantStates: ParticipantStates { ParticipantStates() }
    public var groupImmersionStyle: GroupImmersionStyles { GroupImmersionStyles() }
    public func assignRole(_ role: some SpatialTemplateRole) {}
    public func resignRole() {}

    public struct Configuration: Sendable {
        public init() {}
        public var spatialTemplatePreference: SpatialTemplatePreference = .none
        public var supportsGroupImmersiveSpace = false
    }
    public struct ParticipantState: @unchecked Sendable {
        public let isSpatial: Bool
        public let pose: Pose3D?
        public let role: (any SpatialTemplateRole)?
        public let seat: Seat?
        public struct Seat: @unchecked Sendable {
            public let pose: Pose3D
            public let role: (any SpatialTemplateRole)?
        }
    }
    public struct ParticipantStates: AsyncSequence, Sendable {
        public typealias Element = ParticipantState
        public struct Iterator: AsyncIteratorProtocol {
            public func next() async -> ParticipantState? { nil }
        }
        public func makeAsyncIterator() -> Iterator { Iterator() }
    }
    public struct GroupImmersionStyles: AsyncSequence, Sendable {
        public typealias Element = String?
        public final class Iterator: AsyncIteratorProtocol {
            public func next() async -> String?? { nil }
        }
        public func makeAsyncIterator() -> Iterator { Iterator() }
    }
}

public protocol SpatialTemplateRole: Sendable {
    var roleIdentifier: String { get }
}
extension SpatialTemplateRole {
    public var roleIdentifier: String { String(reflecting: Self.self) }
}

public protocol SpatialTemplate: Sendable {
    var elements: [any SpatialTemplateElement] { get }
    var configuration: SpatialTemplateConfiguration { get }
}
extension SpatialTemplate {
    public var configuration: SpatialTemplateConfiguration { SpatialTemplateConfiguration(defaultInitiatorRole: nil) }
}

public struct SpatialTemplateConfiguration: Hashable, Sendable {
    public let defaultInitiatorRole: (any SpatialTemplateRole)?
    public init(defaultInitiatorRole: (any SpatialTemplateRole)?) { self.defaultInitiatorRole = defaultInitiatorRole }
    public static func == (a: Self, b: Self) -> Bool { a.defaultInitiatorRole?.roleIdentifier == b.defaultInitiatorRole?.roleIdentifier }
    public func hash(into h: inout Hasher) { h.combine(defaultInitiatorRole?.roleIdentifier) }
}

public struct SpatialTemplatePreference: Sendable {
    let kind: String
    let extent: CGFloat?
    let template: (any SpatialTemplate)?
    public static let none = SpatialTemplatePreference(kind: "none", extent: nil, template: nil)
    public static let sideBySide = SpatialTemplatePreference(kind: "sideBySide", extent: nil, template: nil)
    public static let conversational = SpatialTemplatePreference(kind: "conversational", extent: nil, template: nil)
    public static let surround = SpatialTemplatePreference(kind: "surround", extent: nil, template: nil)
    public static func custom(_ template: any SpatialTemplate) -> SpatialTemplatePreference { SpatialTemplatePreference(kind: "custom", extent: nil, template: template) }
    public func contentExtent(_ extent: CGFloat) -> SpatialTemplatePreference { SpatialTemplatePreference(kind: kind, extent: extent, template: template) }
}

public protocol SpatialTemplateElement: Sendable {
    var position: SpatialTemplateElementPosition { get }
    var direction: SpatialTemplateElementDirection { get }
    var role: (any SpatialTemplateRole)? { get }
}
extension SpatialTemplateElement where Self == SpatialTemplateSeatElement {
    public static func seat(position: SpatialTemplateElementPosition, direction: SpatialTemplateElementDirection = .alignedWith(appAxis: .z),
                            role: (any SpatialTemplateRole)? = nil) -> SpatialTemplateSeatElement {
        SpatialTemplateSeatElement(position: position, direction: direction, role: role)
    }
}

public struct SpatialTemplateSeatElement: SpatialTemplateElement, Hashable {
    public let position: SpatialTemplateElementPosition
    public let direction: SpatialTemplateElementDirection
    public let role: (any SpatialTemplateRole)?
    public init(position: SpatialTemplateElementPosition, direction: SpatialTemplateElementDirection = .alignedWith(appAxis: .z), role: (any SpatialTemplateRole)? = nil) {
        self.position = position; self.direction = direction; self.role = role
    }
    public static func == (a: Self, b: Self) -> Bool { a.position == b.position && a.direction == b.direction && a.role?.roleIdentifier == b.role?.roleIdentifier }
    public func hash(into h: inout Hasher) { h.combine(position); h.combine(direction); h.combine(role?.roleIdentifier) }
}

public struct SpatialTemplateElementPosition: Hashable, Sendable {
    let x: Double, z: Double
    public static var app: SpatialTemplateElementPosition { SpatialTemplateElementPosition(x: 0, z: 0) }
    public func offsetBy(x: Double, z: Double) -> SpatialTemplateElementPosition { SpatialTemplateElementPosition(x: self.x + x, z: self.z + z) }
}

public struct SpatialTemplateElementAxis: Hashable, Sendable {
    let rawValue: Int
    public static let x = SpatialTemplateElementAxis(rawValue: 0)
    public static let z = SpatialTemplateElementAxis(rawValue: 1)
}

public struct SpatialTemplateElementDirection: Hashable, Sendable {
    let target: SpatialTemplateElementPosition?
    let axis: SpatialTemplateElementAxis?
    let rotation: Double
    public static func lookingAt(_ element: any SpatialTemplateElement) -> SpatialTemplateElementDirection { lookingAt(element.position) }
    public static func lookingAt(_ position: SpatialTemplateElementPosition) -> SpatialTemplateElementDirection {
        SpatialTemplateElementDirection(target: position, axis: nil, rotation: 0)
    }
    public static func alignedWith(appAxis: SpatialTemplateElementAxis) -> SpatialTemplateElementDirection {
        SpatialTemplateElementDirection(target: nil, axis: appAxis, rotation: 0)
    }
    public func rotatedBy(_ angle: Angle2D) -> SpatialTemplateElementDirection {
        SpatialTemplateElementDirection(target: target, axis: axis, rotation: rotation + angle.radians)
    }
    public static func + (d: SpatialTemplateElementDirection, angle: Angle2D) -> SpatialTemplateElementDirection { d.rotatedBy(angle) }
}

/// Associates a window with a SharePlay activity (visionOS). isim: kept, no effect on iOS.
@MainActor public final class GroupActivityAssociationInteraction: NSObject, UIInteraction {
    public var associationKind: GroupActivityAssociationKind?
    public private(set) weak var view: UIView?
    public init(associationKind: GroupActivityAssociationKind?) { self.associationKind = associationKind }
    public func willMove(to view: UIView?) {}
    public func didMove(to view: UIView?) { self.view = view }
}

public struct GroupActivityAssociationKind: Hashable, Sendable {
    let identifier: String
    public static func primary(_ identifier: String) -> GroupActivityAssociationKind { GroupActivityAssociationKind(identifier: identifier) }
}
