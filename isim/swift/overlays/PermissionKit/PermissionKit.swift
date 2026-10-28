// isim PermissionKit (issue #397): a child asks a parent for permission (to talk to someone, or for a significant
// change to the app). isim has no family, so the parent is simulated: AskCenter.ask shows isim's rendition of iOS's
// "Ask" sheet, the question waits in ISIM_DATA/Library/isim/PermissionKit/<bundle id>.json, and
// `isim permission <app> approve|decline [question]` answers it; the answer arrives in AskCenter.responses(for:) (and
// CommunicationLimits.updates). Asking needs a child account with Communication Limits (`isim agerange set <age>
// --controls communicationLimits`), else AskError.communicationLimitsNotEnabled. Approved communication handles become
// known handles. Adapted: no Messages, no Screen Time; the sheets' wording is isim's.
import UIKit
import SwiftUI

public protocol QuestionTopic: Codable, Sendable {
    static var id: String { get }
}

public struct CommunicationHandle: Hashable, Codable, Sendable {
    public enum Kind: String, Hashable, Codable, Sendable { case phoneNumber, emailAddress, custom }
    public var value: String
    public var kind: Kind
    public init(value: String, kind: Kind) { self.value = value; self.kind = kind }
}

public struct CommunicationTopic: QuestionTopic, Hashable {
    public static let id = "com.apple.PermissionKit.CommunicationTopic"
    public enum Action: String, Hashable, Codable, Sendable {
        case audioCall, call, follow, friend, message, beFollowed, chat, communicate, connect, videoCall
    }
    public struct PersonInformation: Hashable, Codable, @unchecked Sendable {
        public var handle: CommunicationHandle
        public var nameComponents: PersonNameComponents?
        /// not encoded (an image stays on this device)
        public var avatarImage: CGImage?
        public init(handle: CommunicationHandle, nameComponents: PersonNameComponents?, avatarImage: CGImage?) {
            self.handle = handle; self.nameComponents = nameComponents; self.avatarImage = avatarImage
        }
        enum CodingKeys: String, CodingKey { case handle, nameComponents }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            handle = try c.decode(CommunicationHandle.self, forKey: .handle)
            nameComponents = try c.decodeIfPresent(PersonNameComponents.self, forKey: .nameComponents)
        }
        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(handle, forKey: .handle)
            try c.encodeIfPresent(nameComponents, forKey: .nameComponents)
        }
        public static func == (a: PersonInformation, b: PersonInformation) -> Bool { a.handle == b.handle && a.nameComponents == b.nameComponents }
        public func hash(into h: inout Hasher) { h.combine(handle) }
    }
    public var personInformation: [PersonInformation]
    public var actions: Set<Action>
    public init(personInformation: [PersonInformation]) { self.init(personInformation: personInformation, actions: [.communicate]) }
    public init(personInformation: [PersonInformation], actions: Set<Action>) { self.personInformation = personInformation; self.actions = actions }
}

public struct SignificantAppUpdateTopic: QuestionTopic, Hashable {
    public static let id = "com.apple.PermissionKit.SignificantAppUpdateTopic"
    public let description: String
    public init(description: String) { self.description = description }
}

public struct PermissionChoice: Hashable, Codable, Sendable, Identifiable {
    public enum Answer: String, Hashable, Codable, Sendable { case approval, denial }
    public var id: String
    public var title: String
    public var answer: Answer
    public static let approve = PermissionChoice(id: "approve", title: "Approve", answer: .approval)
    public static let decline = PermissionChoice(id: "decline", title: "Decline", answer: .denial)
    public static func == (a: PermissionChoice, b: PermissionChoice) -> Bool { a.id == b.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public final class PermissionQuestion<Topic: QuestionTopic>: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let topic: Topic
    public var choices: [PermissionChoice] { [.approve, .decline] }
    public var defaultChoice: PermissionChoice { .decline }
    /// questions to a parent expire after a week, as Ask to Buy requests do (isim's choice)
    public var expirationDate: Date? { created.addingTimeInterval(7 * 86400) }
    let created: Date
    init(topic: Topic, id: UUID = UUID(), created: Date = Date()) { self.topic = topic; self.id = id; self.created = created }
}

extension PermissionQuestion where Topic == CommunicationTopic {
    public convenience init(handle: CommunicationHandle) { self.init(handles: [handle]) }
    public convenience init(handles: [CommunicationHandle]) {
        self.init(communicationTopic: CommunicationTopic(personInformation: handles.map { .init(handle: $0, nameComponents: nil, avatarImage: nil) }))
    }
    public convenience init(communicationTopic: CommunicationTopic) { self.init(topic: communicationTopic) }
}

extension PermissionQuestion where Topic == SignificantAppUpdateTopic {
    public convenience init(significantAppUpdateTopic: SignificantAppUpdateTopic) { self.init(topic: significantAppUpdateTopic) }
}

public struct PermissionResponse<Topic: QuestionTopic>: Sendable {
    public let choice: PermissionChoice
    public let question: PermissionQuestion<Topic>
}

public enum AskError: Error, LocalizedError, Sendable {
    case unknown, communicationLimitsNotEnabled, contactSyncNotSetup, invalidQuestion
    case systemError(underlyingError: any Error)
    case notAvailable
    public var errorDescription: String? {
        switch self {
        case .unknown: return "An unknown error occurred."
        case .communicationLimitsNotEnabled: return "Communication Limits are not turned on for this account."
        case .contactSyncNotSetup: return "Contacts are not synced with iCloud."
        case .invalidQuestion: return "The question is not valid."
        case .systemError(let e): return e.localizedDescription
        case .notAvailable: return "Asking for permission is not available."
        }
    }
}

public enum PermissionFlow: Hashable, Sendable { case acknowledgmentAlert, approveInPerson, askToApprove }

public enum PermissionResult: Hashable, Sendable {
    case approveInPerson(approved: Bool)
    case askToApprove(didSend: Bool)
    case cancel
}

public final class AskCenter: @unchecked Sendable {
    public static let shared = AskCenter()

    @MainActor public func ask(_ question: PermissionQuestion<CommunicationTopic>, in viewController: UIViewController) async throws {
        _ = try await _PKStore.send(question, kind: "communication", summary: _PKStore.summary(question.topic), from: viewController)
    }
    @MainActor public func ask(_ question: PermissionQuestion<SignificantAppUpdateTopic>, in viewController: UIViewController) async throws {
        _ = try await _PKStore.send(question, kind: "significantAppUpdate", summary: question.topic.description, from: viewController)
    }

    /// the parent's answers to this app's questions about the topic, as they come in
    @available(iOS 26.0, *)
    public func responses<Topic: QuestionTopic>(for topic: Topic.Type) -> some AsyncSequence<PermissionResponse<Topic>, Never> {
        _PKStore.responses(topic)
    }

    /// a significant change: the parent is told (acknowledgment alert), approves on this device (in person), or is
    /// asked from afar (ask to approve)
    @MainActor public func askSignificantChangePermission(for question: PermissionQuestion<SignificantAppUpdateTopic>, permissionFlow: PermissionFlow,
                                                          in viewController: UIViewController) async throws -> PermissionResult {
        try _PKStore.requireChild()
        switch permissionFlow {
        case .askToApprove:
            let sent = try await _PKStore.send(question, kind: "significantAppUpdate", summary: question.topic.description, from: viewController)
            return .askToApprove(didSend: sent)
        case .approveInPerson:
            let answer = await _PKStore.sheet(from: viewController, title: "Ask a Parent to Approve",
                                              message: "A parent can approve this change on this device: “\(question.topic.description)”",
                                              yes: "Approve", no: "Don’t Approve", ids: ("permission-approve", "permission-deny"))
            guard let approved = answer else { return .cancel }
            NSLog("isim PermissionKit: approved in person: %@", approved ? "yes" : "no")
            if approved { _PKStore.record(question, kind: "significantAppUpdate", summary: question.topic.description, state: "approved") }
            return .approveInPerson(approved: approved)
        case .acknowledgmentAlert:
            let ok = await _PKStore.sheet(from: viewController, title: "Tell a Parent",
                                          message: "Your parent will be told about this change: “\(question.topic.description)”",
                                          yes: "OK", no: "Cancel", ids: ("permission-ok", "permission-cancel"))
            // a parent who is only told has nothing to approve: OK sends the notice
            return ok == true ? .askToApprove(didSend: true) : .cancel
        }
    }
}

public final class CommunicationLimits: @unchecked Sendable {
    public static let current = CommunicationLimits()

    public func isKnownHandle(_ handle: CommunicationHandle) async -> Bool { _PKStore.knownHandles().contains(handle) }
    public func knownHandles(in handles: Set<CommunicationHandle>) async -> Set<CommunicationHandle> { handles.intersection(_PKStore.knownHandles()) }
    @available(iOS 26.0, *)
    public var updates: some AsyncSequence<PermissionResponse<CommunicationTopic>, Never> { _PKStore.responses(CommunicationTopic.self) }

    @MainActor public func ask(_ question: PermissionQuestion<CommunicationTopic>, in viewController: UIViewController) async throws {
        try await AskCenter.shared.ask(question, in: viewController)
    }
}

/// a button that asks the question (the "Ask" sheet) when tapped
public struct PermissionButton<Topic: QuestionTopic, Label: View>: View {
    public let question: PermissionQuestion<Topic>
    let label: Label
    let flow: PermissionFlow?
    let onResult: ((Result<PermissionResult, any Error>) -> Void)?
    public init(question: PermissionQuestion<Topic>, @ViewBuilder label: () -> Label) where Topic == CommunicationTopic {
        self.question = question; self.label = label(); flow = nil; onResult = nil
    }
    public init(question: PermissionQuestion<Topic>, @ViewBuilder label: () -> Label) where Topic == SignificantAppUpdateTopic {
        self.question = question; self.label = label(); flow = nil; onResult = nil
    }
    public init(question: PermissionQuestion<Topic>, permissionFlow: PermissionFlow, onPermissionResult: @escaping (Result<PermissionResult, any Error>) -> Void,
                @ViewBuilder label: () -> Label) where Topic == SignificantAppUpdateTopic {
        self.question = question; self.label = label(); flow = permissionFlow; onResult = onPermissionResult
    }
    public var body: some View {
        Button {
            Task { @MainActor in
                guard let vc = _PKStore.topController() else { return }
                if let flow, let q = question as? PermissionQuestion<SignificantAppUpdateTopic> {
                    do { onResult?(.success(try await AskCenter.shared.askSignificantChangePermission(for: q, permissionFlow: flow, in: vc))) }
                    catch { onResult?(.failure(error)) }
                } else if let q = question as? PermissionQuestion<CommunicationTopic> {
                    try? await AskCenter.shared.ask(q, in: vc)
                } else if let q = question as? PermissionQuestion<SignificantAppUpdateTopic> {
                    try? await AskCenter.shared.ask(q, in: vc)
                }
            }
        } label: { label }
    }
}

public struct CommunicationLimitsButton<Label: View>: View {
    public let question: PermissionQuestion<CommunicationTopic>
    let label: Label
    public init(question: PermissionQuestion<CommunicationTopic>, @ViewBuilder label: () -> Label) { self.question = question; self.label = label() }
    public var body: some View { PermissionButton(question: question) { label } }
}

/// `@Environment(\.askPermission)`
public struct AskPermissionAction: Sendable {
    @MainActor public func callAsFunction<Topic: QuestionTopic>(_ question: PermissionQuestion<Topic>) async throws {
        guard let vc = _PKStore.topController() else { throw AskError.notAvailable }
        if let q = question as? PermissionQuestion<CommunicationTopic> { try await AskCenter.shared.ask(q, in: vc) }
        else if let q = question as? PermissionQuestion<SignificantAppUpdateTopic> { try await AskCenter.shared.ask(q, in: vc) }
        else { throw AskError.invalidQuestion }
    }
}
private struct _AskPermissionKey: EnvironmentKey { static let defaultValue = AskPermissionAction() }
extension EnvironmentValues {
    public var askPermission: AskPermissionAction { self[_AskPermissionKey.self] }
}

// MARK: - the simulated parent

enum _PKStore {
    static var dataRoot: String {
        let env = ProcessInfo.processInfo.environment
        return env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
    }
    static var file: String {
        (dataRoot as NSString).appendingPathComponent("Library/isim/PermissionKit/\(Bundle.main.bundleIdentifier ?? "app").json")
    }
    static func read() -> [String: Any] {
        guard let d = FileManager.default.contents(atPath: file), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }
    static func write(_ o: [String: Any]) {
        try? FileManager.default.createDirectory(atPath: (file as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let d = try? JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted, .sortedKeys]) { try? d.write(to: URL(fileURLWithPath: file), options: .atomic) }
    }

    /// the account must be a child's with Communication Limits (`isim agerange set <age> --controls communicationLimits`)
    static func requireChild() throws {
        let path = (dataRoot as NSString).appendingPathComponent("Library/isim/AgeRange.json")
        guard let d = FileManager.default.contents(atPath: path), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              (o["controls"] as? [String] ?? []).contains("communicationLimits") else { throw AskError.communicationLimitsNotEnabled }
    }

    static func summary(_ t: CommunicationTopic) -> String {
        let who = t.personInformation.map { p in
            p.nameComponents.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) } ?? p.handle.value
        }.joined(separator: ", ")
        let what = t.actions.map(\.rawValue).sorted().joined(separator: ", ")
        return "\(what) with \(who)"
    }

    /// iOS's "Ask" sheet, then the question goes to the parent; false: the child did not send it
    @MainActor static func send<Topic: QuestionTopic>(_ q: PermissionQuestion<Topic>, kind: String, summary: String, from vc: UIViewController) async throws -> Bool {
        try requireChild()
        let sent = await sheet(from: vc, title: "Ask for Permission", message: "Ask a parent for permission to \(summary)?",
                               yes: "Ask", no: "Cancel", ids: ("permission-ask", "permission-cancel"))
        guard sent == true else { NSLog("isim PermissionKit: not asked (%@)", summary); return false }
        record(q, kind: kind, summary: summary, state: "pending")
        NSLog("isim PermissionKit: asked %@: %@ (`isim permission <app> approve|decline` answers)", q.id.uuidString, summary)
        return true
    }

    static func record<Topic: QuestionTopic>(_ q: PermissionQuestion<Topic>, kind: String, summary: String, state: String) {
        var o = read()
        var qs = o["questions"] as? [[String: Any]] ?? []
        var e: [String: Any] = ["id": q.id.uuidString, "topic": Topic.id, "kind": kind, "summary": summary, "state": state,
                                "created": q.created.timeIntervalSince1970]
        if let data = try? JSONEncoder().encode(q.topic), let json = try? JSONSerialization.jsonObject(with: data) { e["topicData"] = json }
        qs.append(e)
        o["questions"] = qs
        write(o)
    }

    /// handles of approved communication questions
    static func knownHandles() -> Set<CommunicationHandle> {
        var out = Set<CommunicationHandle>()
        for e in read()["questions"] as? [[String: Any]] ?? [] where e["state"] as? String == "approved" && e["kind"] as? String == "communication" {
            guard let j = e["topicData"], let d = try? JSONSerialization.data(withJSONObject: j),
                  let t = try? JSONDecoder().decode(CommunicationTopic.self, from: d) else { continue }
            for p in t.personInformation { out.insert(p.handle) }
        }
        return out
    }

    /// answers to this app's questions as `isim permission` writes them (checked twice a second)
    static func responses<Topic: QuestionTopic>(_ type: Topic.Type) -> AsyncStream<PermissionResponse<Topic>> {
        AsyncStream { cont in
            let task = Task {
                var seen = Set<String>()
                for e in read()["questions"] as? [[String: Any]] ?? [] where (e["state"] as? String ?? "pending") != "pending" { seen.insert(e["id"] as? String ?? "") }
                while !Task.isCancelled {
                    for e in read()["questions"] as? [[String: Any]] ?? [] {
                        guard let id = e["id"] as? String, !seen.contains(id), e["topic"] as? String == Topic.id,
                              let state = e["state"] as? String, state == "approved" || state == "declined",
                              let uuid = UUID(uuidString: id), let j = e["topicData"], let d = try? JSONSerialization.data(withJSONObject: j),
                              let topic = try? JSONDecoder().decode(Topic.self, from: d) else { continue }
                        seen.insert(id)
                        let q = PermissionQuestion(topic: topic, id: uuid, created: Date(timeIntervalSince1970: e["created"] as? Double ?? 0))
                        cont.yield(PermissionResponse(choice: state == "approved" ? .approve : .decline, question: q))
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    @MainActor static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first { $0.isKeyWindow }?.rootViewController ?? scenes.first?.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }

    /// a sheet with two buttons; nil when swiped away. ISIM_PERMISSION_ANSWER=yes|no answers without it.
    @MainActor static func sheet(from vc: UIViewController, title: String, message: String, yes: String, no: String, ids: (String, String)) async -> Bool? {
        if let a = ProcessInfo.processInfo.environment["ISIM_PERMISSION_ANSWER"]?.lowercased(), a == "yes" || a == "no" {
            NSLog("isim PermissionKit: %@ answered %@ (ISIM_PERMISSION_ANSWER)", title, a)
            return a == "yes"
        }
        return await withCheckedContinuation { (k: CheckedContinuation<Bool?, Never>) in
            final class Box { var finished = false }
            let box = Box()
            var host: UIViewController?
            let done: (Bool?) -> Void = { answer in
                guard !box.finished else { return }
                box.finished = true
                host?.dismiss(animated: true, completion: nil)
                k.resume(returning: answer)
            }
            let view = VStack(spacing: 14) {
                Image(systemName: "person.2").font(.system(size: 44)).foregroundStyle(.tint).padding(.top, 28)
                Text(verbatim: title).font(.system(size: 22, weight: .bold))
                Text(verbatim: message).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
                Button { done(true) } label: { Text(verbatim: yes).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier(ids.0)
                Button { done(false) } label: { Text(verbatim: no).font(.system(size: 17)).frame(maxWidth: .infinity) }
                    .accessibilityIdentifier(ids.1).padding(.bottom, 16)
            }.padding(.horizontal, 28)
            let h = _PKHost(rootView: AnyView(view))
            h.onGone = { if !box.finished { box.finished = true; k.resume(returning: nil) } }
            h.sheetPresentationController?.detents = [.medium()]
            host = h
            vc.present(h, animated: true, completion: nil)
        }
    }
}

final class _PKHost: UIHostingController<AnyView> {
    var onGone: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if presentingViewController == nil { let f = onGone; onGone = nil; f?() }
    }
}
