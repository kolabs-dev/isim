// isim PushKit for Objective-C (sdk-src/Frameworks/PushKit): the classes carry Apple's Objective-C names and these
// members Apple's selectors; PKPushType is an NSString there. PKPushRegistryDelegate is a Swift protocol in the overlay
// (PKPushType is a Swift struct), so an Objective-C delegate is wrapped in an adapter that conforms to it and sends each
// call to the selectors the object implements, on the registry's dispatch queue.
import Foundation
import Darwin
import ObjectiveC

nonisolated(unsafe) private var _pkObjCDelegateKey: UInt8 = 0
nonisolated(unsafe) private var _pkObjCQueueKey: UInt8 = 0

/// sends an Objective-C message with up to four object arguments to an object that implements it
@discardableResult
func _pkSend(_ target: NSObject, _ sel: String, _ a: AnyObject? = nil, _ b: AnyObject? = nil, _ c: AnyObject? = nil, _ d: AnyObject? = nil) -> Bool {
    let s = NSSelectorFromString(sel)
    guard target.responds(to: s) else { return false }
    typealias Send = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?, AnyObject?) -> Void
    unsafeBitCast(target.method(for: s), to: Send.self)(target, s, a, b, c, d)
    return true
}

final class _PKObjCDelegate: NSObject, PKPushRegistryDelegate {
    weak var target: NSObject?
    let queue: dispatch_queue_t?
    init(_ t: NSObject, queue: dispatch_queue_t?) { target = t; self.queue = queue }
    func on(_ work: @escaping () -> Void) { if let queue { dispatch_async(queue, work) } else { work() } }
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        on { [weak self] in
            guard let t = self?.target else { return }
            _pkSend(t, "pushRegistry:didUpdatePushCredentials:forType:", registry, pushCredentials, type.rawValue as NSString)
        }
    }
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        on { [weak self] in
            guard let t = self?.target else { completion(); return }
            let block: @convention(block) () -> Void = { completion() }
            if _pkSend(t, "pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:", registry, payload,
                       type.rawValue as NSString, block as AnyObject) { return }
            if !_pkSend(t, "pushRegistry:didReceiveIncomingPushWithPayload:forType:", registry, payload, type.rawValue as NSString) {
                NSLog("isim: PushKit: the delegate does not implement pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:")
            }
            completion()
        }
    }
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        on { [weak self] in
            guard let t = self?.target else { return }
            _pkSend(t, "pushRegistry:didInvalidatePushTokenForType:", registry, type.rawValue as NSString)
        }
    }
}

extension PKPushRegistry {
    /// the Objective-C caller's queue: the registry itself delivers on the main queue and the adapter hops to it
    var _objcQueue: dispatch_queue_t? {
        get { (objc_getAssociatedObject(self, &_pkObjCQueueKey) as? _PKQueueBox)?.queue }
        set { objc_setAssociatedObject(self, &_pkObjCQueueKey, _PKQueueBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    @objc(initWithQueue:) convenience init(_objcQueue queue: dispatch_queue_t?) {
        self.init(queue: nil)
        _objcQueue = queue
    }
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _PKObjCDelegate)?.target ?? (delegate as? NSObject) }
        set {
            let a = newValue.map { _PKObjCDelegate($0, queue: _objcQueue) }
            objc_setAssociatedObject(self, &_pkObjCDelegateKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)   // the delegate is weak
            delegate = a
        }
    }
    @objc(desiredPushTypes) var _objc_desiredPushTypes: Set<String>? {
        get { desiredPushTypes.map { Set($0.map(\.rawValue)) } }
        set { desiredPushTypes = newValue.map { Set($0.map { PKPushType(rawValue: $0) }) } }
    }
    @objc(pushTokenForType:) func _objc_pushToken(_ type: String) -> Data? { pushToken(for: PKPushType(rawValue: type)) }
}
final class _PKQueueBox { let queue: dispatch_queue_t?; init(_ q: dispatch_queue_t?) { queue = q } }

extension PKPushCredentials {
    @objc(type) var _objc_type: String { type.rawValue }
    @objc(token) var _objc_token: Data { token }
}
extension PKPushPayload {
    @objc(type) var _objc_type: String { type.rawValue }
    @objc(dictionaryPayload) var _objc_dictionaryPayload: [AnyHashable: Any] { dictionaryPayload }
}
