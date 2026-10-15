// isim PushKit: VoIP pushes (adapted). A PKPushRegistry whose desiredPushTypes include .voip gets a push token
// (pushRegistry(_:didUpdate:for:), kept in the app's container like the device token of remote notifications). A VoIP
// push is an `isim push BUNDLE payload.apns` whose payload has the top-level key "apns-push-type": "voip" (standing in
// for that APNs header; it needs no "aps" dictionary). The home screen (standing in for apsd) routes it to the app,
// launching it in the background when it is not running, if the app has UIBackgroundModes voip; UIKit hands it to
// PushKit (the _IsimPushKitPayload notification, queued until a registry wants VoIP pushes) and the registry's
// delegate gets pushRegistry(_:didReceiveIncomingPushWith:for:completion:). Like iOS 13+, an app that does not report
// a new incoming call to CallKit before it calls the completion handler (or returns from the older method) is
// terminated. Not on isim: file provider pushes are never delivered; complication pushes (watchOS) neither.
@_exported import Foundation
import isim_host

public struct PKPushType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let voIP = PKPushType(rawValue: "PKPushTypeVoIP")
    public static let fileProvider = PKPushType(rawValue: "PKPushTypeFileProvider")
    @available(*, deprecated, message: "complication pushes are for watchOS apps") public static let complication = PKPushType(rawValue: "PKPushTypeComplication")
}
public let PKPushTypeVoIP = PKPushType.voIP
public let PKPushTypeFileProvider = PKPushType.fileProvider

@objc(PKPushCredentials) open class PKPushCredentials: NSObject, @unchecked Sendable {
    open private(set) var type: PKPushType
    open private(set) var token: Data
    init(type: PKPushType, token: Data) { self.type = type; self.token = token }
}

@objc(PKPushPayload) open class PKPushPayload: NSObject, @unchecked Sendable {
    open private(set) var type: PKPushType
    open private(set) var dictionaryPayload: [AnyHashable: Any]
    init(type: PKPushType, payload: [AnyHashable: Any]) { self.type = type; dictionaryPayload = payload }
}

/// a Swift protocol (PKPushType is a Swift struct here, not an NSString): the optional methods have default implementations
public protocol PKPushRegistryDelegate: NSObjectProtocol {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType)
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void)
    @available(*, deprecated, message: "use pushRegistry(_:didReceiveIncomingPushWith:for:completion:)")
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType)
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType)
}
extension PKPushRegistryDelegate {
    /// apps that only implement the older method get it
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        _isimOlderIncoming(registry, payload, type)
        completion()
    }
    @available(*, deprecated)
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        NSLog("isim: PushKit: the delegate does not implement pushRegistry(_:didReceiveIncomingPushWith:for:completion:)")
    }
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {}
    @available(*, deprecated)
    func _isimOlderIncoming(_ r: PKPushRegistry, _ p: PKPushPayload, _ t: PKPushType) { pushRegistry(r, didReceiveIncomingPushWith: p, for: t) }
}

/// the app's push tokens: <container>/Library/isim/PushKit.plist { type raw value: token (hex) }
enum _PushKitStore {
    static var file: String {
        let lib = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        let d = (lib as NSString).appendingPathComponent("isim")
        try? FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true, attributes: nil)
        return (d as NSString).appendingPathComponent("PushKit.plist")
    }
    static func token(_ type: PKPushType) -> Data {
        var all = (NSDictionary(contentsOfFile: file) as? [String: String]) ?? [:]
        if let hex = all[type.rawValue], let d = data(hex: hex) { return d }
        let d = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        all[type.rawValue] = hex(d)
        (all as NSDictionary).write(toFile: file, atomically: true)
        return d
    }
    static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }
    static func data(hex: String) -> Data? {
        var d = Data(), i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let b = UInt8(hex[i..<j], radix: 16) else { return nil }
            d.append(b); i = j
        }
        return d
    }
}

@objc(PKPushRegistry) open class PKPushRegistry: NSObject, @unchecked Sendable {
    open weak var delegate: PKPushRegistryDelegate?
    let queue: DispatchQueue
    nonisolated(unsafe) static var registries: [Weak] = []
    nonisolated(unsafe) static var observing = false
    /// CallKit posts _IsimCallKitIncomingReported when the app reports a new incoming call
    nonisolated(unsafe) static var reportedCalls = 0
    struct Weak { weak var r: PKPushRegistry? }

    public init(queue: DispatchQueue?) {
        self.queue = queue ?? .main
        super.init()
        PKPushRegistry.observe()
        PKPushRegistry.registries.append(Weak(r: self))
    }

    open var desiredPushTypes: Set<PKPushType>? {
        didSet {
            let now = desiredPushTypes ?? [], before = oldValue ?? []
            for t in now.subtracting(before) where t == .voIP || t == .fileProvider { announce(t) }
            for t in before.subtracting(now) {
                queue.async { [weak self] in
                    guard let self else { return }
                    NSLog("isim: PushKit: %@ pushes no longer wanted; the token is invalidated", t.rawValue)
                    self.delegate?.pushRegistry(self, didInvalidatePushTokenFor: t)
                }
            }
            if now.contains(.voIP) {
                if !PKPushRegistry.voipMode { NSLog("isim: PushKit: VoIP pushes need UIBackgroundModes voip in Info.plist; none will be delivered") }
                NotificationCenter.default.post(name: Notification.Name("_IsimPushKitReady"), object: nil)
            }
        }
    }

    /// the token of a type it wants (nil before it was announced)
    open func pushToken(for type: PKPushType) -> Data? {
        (desiredPushTypes ?? []).contains(type) ? _PushKitStore.token(type) : nil
    }

    func announce(_ t: PKPushType) {
        let token = _PushKitStore.token(t)
        queue.async { [weak self] in
            guard let self else { return }
            if t == .voIP {
                NSLog("isim: PushKit: VoIP push token %@; send a VoIP push with: isim push %@ payload.apns (with \"apns-push-type\": \"voip\")",
                      _PushKitStore.hex(token), Bundle.main.bundleIdentifier ?? "BUNDLE-ID")
            } else {
                NSLog("isim: PushKit: %@ push token %@ (isim never delivers these pushes)", t.rawValue, _PushKitStore.hex(token))
            }
            self.delegate?.pushRegistry(self, didUpdate: PKPushCredentials(type: t, token: token), for: t)
        }
    }

    static var voipMode: Bool { ((Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]) ?? []).contains("voip") }

    static func observe() {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(forName: Notification.Name("_IsimCallKitIncomingReported"), object: nil, queue: nil) { _ in
            reportedCalls += 1
        }
        /// object: a mutable dictionary { id, payload, pushType }; "handled" is set when a registry took it
        NotificationCenter.default.addObserver(forName: Notification.Name("_IsimPushKitPayload"), object: nil, queue: nil) { n in
            guard let w = n.object as? NSMutableDictionary else { return }
            let type = PKPushType(rawValue: (w["pushType"] as? String) == "voip" ? PKPushType.voIP.rawValue : (w["pushType"] as? String ?? ""))
            guard let r = registries.compactMap({ $0.r }).first(where: { ($0.desiredPushTypes ?? []).contains(type) && $0.delegate != nil }) else { return }
            w.setObject(true, forKey: "handled" as NSString)
            let payload = (w["payload"] as? [AnyHashable: Any]) ?? [:]
            r.deliver(PKPushPayload(type: type, payload: payload), id: w["id"] as? String ?? "")
        }
    }

    func deliver(_ payload: PKPushPayload, id: String) {
        queue.async { [weak self] in
            guard let self, let d = self.delegate else { return }
            NSLog("isim: PushKit: incoming VoIP push %@", id)
            let before = PKPushRegistry.reportedCalls
            var finished = false
            let check = {
                if finished { return }
                finished = true
                /* iOS 13+: a VoIP push must report a new incoming call to CallKit before the handler finishes */
                DispatchQueue.main.async {
                    if PKPushRegistry.reportedCalls > before {
                        NSLog("isim: PushKit: VoIP push %@ handled (an incoming call was reported to CallKit)", id)
                        return
                    }
                    NSLog("isim: PushKit: terminating the app: it never posted an incoming call to the system after receiving a PushKit VoIP push")
                    exit(1)
                }
            }
            d.pushRegistry(self, didReceiveIncomingPushWith: payload, for: payload.type) { check() }
        }
    }
}
