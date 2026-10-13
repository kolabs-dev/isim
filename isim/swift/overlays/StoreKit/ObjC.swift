// isim StoreKit for Objective-C (sdk-src/Frameworks/StoreKit): the classes carry Apple's Objective-C names and these
// members Apple's selectors. StoreKit's delegate and observer protocols are Swift protocols in the overlay (apps built
// against them keep their witness tables), so an Objective-C delegate is wrapped in an adapter that conforms to the
// Swift protocol and forwards each call to the selectors the Objective-C object implements.
import UIKit
import ObjectiveC

nonisolated(unsafe) private var _skObjCDelegateKey: UInt8 = 0

/// forwards a Swift delegate call to an Objective-C object's selector, when it implements it
final class _SKObjCForwarder {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func send(_ sel: String, _ a: Any?, _ b: Any? = nil) {
        guard let t = target, t.responds(to: Selector(sel)) else { return }
        if b == nil && !sel.hasSuffix(":") { _ = t.perform(Selector(sel)) }
        else if sel.filter({ $0 == ":" }).count == 1 { _ = t.perform(Selector(sel), with: a) }
        else { _ = t.perform(Selector(sel), with: a, with: b) }
    }
}

final class _SKObjCProductDelegate: SKStoreProductViewControllerDelegate {
    let f: _SKObjCForwarder
    init(_ t: NSObject) { f = _SKObjCForwarder(t) }
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) { f.send("productViewControllerDidFinish:", viewController) }
}

extension SKStoreProductViewController {
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _SKObjCProductDelegate)?.f.target }
        set {
            let a = newValue.map(_SKObjCProductDelegate.init)
            objc_setAssociatedObject(self, &_skObjCDelegateKey, a, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))   // the delegate is weak
            delegate = a
        }
    }
}

final class _SKObjCOverlayDelegate: SKOverlayDelegate {
    let f: _SKObjCForwarder
    init(_ t: NSObject) { f = _SKObjCForwarder(t) }
    func storeOverlay(_ overlay: SKOverlay, didFailToLoadWithError error: Error) { f.send("storeOverlay:didFailToLoadWithError:", overlay, error as NSError) }
    func storeOverlay(_ overlay: SKOverlay, willStartPresentation c: SKOverlay.TransitionContext) { f.send("storeOverlay:willStartPresentation:", overlay, c) }
    func storeOverlay(_ overlay: SKOverlay, didFinishPresentation c: SKOverlay.TransitionContext) { f.send("storeOverlay:didFinishPresentation:", overlay, c) }
    func storeOverlay(_ overlay: SKOverlay, willStartDismissal c: SKOverlay.TransitionContext) { f.send("storeOverlay:willStartDismissal:", overlay, c) }
    func storeOverlay(_ overlay: SKOverlay, didFinishDismissal c: SKOverlay.TransitionContext) { f.send("storeOverlay:didFinishDismissal:", overlay, c) }
}

extension SKOverlay {
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _SKObjCOverlayDelegate)?.f.target }
        set {
            let a = newValue.map(_SKObjCOverlayDelegate.init)
            objc_setAssociatedObject(self, &_skObjCDelegateKey, a, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            delegate = a
        }
    }
    @objc(configuration) var _objc_configuration: Configuration { configuration }
}

extension SKOverlay.TransitionContext {
    @objc(addAnimationBlock:) func _objc_addAnimationBlock(_ block: @escaping () -> Void) { addAnimationBlock(block) }
    @objc(startFrame) var _objc_startFrame: CGRect { startFrame }
    @objc(endFrame) var _objc_endFrame: CGRect { endFrame }
}

final class _SKObjCTransactionObserver: SKPaymentTransactionObserver {
    let f: _SKObjCForwarder
    init(_ t: NSObject) { f = _SKObjCForwarder(t) }
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        f.send("paymentQueue:updatedTransactions:", queue, transactions as NSArray)
    }
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        f.send("paymentQueue:removedTransactions:", queue, transactions as NSArray)
    }
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        f.send("paymentQueue:restoreCompletedTransactionsFailedWithError:", queue, error as NSError)
    }
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) { f.send("paymentQueueRestoreCompletedTransactionsFinished:", queue) }
}

extension SKPaymentQueue {
    nonisolated(unsafe) private static var _objcObservers: [ObjectIdentifier: _SKObjCTransactionObserver] = [:]
    @objc(addTransactionObserver:) func _objc_add(_ o: NSObject) {
        let a = _SKObjCTransactionObserver(o)
        SKPaymentQueue._objcObservers[ObjectIdentifier(o)] = a
        add(a)
    }
    @objc(removeTransactionObserver:) func _objc_remove(_ o: NSObject) {
        if let a = SKPaymentQueue._objcObservers.removeValue(forKey: ObjectIdentifier(o)) { remove(a) }
    }
    @objc(transactions) var _objc_transactions: NSArray { transactions as NSArray }
}
