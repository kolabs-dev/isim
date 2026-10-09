// UIKit text services (Swift refinements): UITextItem.content. See UITextServices.m.
import ObjectiveC
import Foundation

extension UITextItem {
    /// what the item is (iOS 17). isim has no text attachments, so items are links (detected or not) and tags.
    public enum Content {
        case link(URL)
        case tag(String)
    }
    public var content: Content {
        if __contentType == .tag, let t = __tagIdentifier { return .tag(t) }
        return .link(__link ?? URL(string: "about:blank")!)
    }
}

// MARK: - Indirect Scribble

/// Swift's indirect Scribble delegate: element identifiers are any Hashable (iOS refines the Objective-C protocol the same way)
@MainActor public protocol UIIndirectScribbleInteractionDelegate: NSObjectProtocol {
    associatedtype ElementIdentifier: Hashable
    func indirectScribbleInteraction(_ interaction: UIInteraction, requestElementsIn rect: CGRect, completion: @escaping ([ElementIdentifier]) -> Void)
    func indirectScribbleInteraction(_ interaction: UIInteraction, isElementFocused elementIdentifier: ElementIdentifier) -> Bool
    func indirectScribbleInteraction(_ interaction: UIInteraction, frameForElement elementIdentifier: ElementIdentifier) -> CGRect
    func indirectScribbleInteraction(_ interaction: UIInteraction, focusElementIfNeeded elementIdentifier: ElementIdentifier,
                                     referencePoint focusReferencePoint: CGPoint, completion: @escaping ((UIResponder & UITextInput)?) -> Void)
    func indirectScribbleInteraction(_ interaction: UIInteraction, shouldDelayFocusForElement elementIdentifier: ElementIdentifier) -> Bool
    func indirectScribbleInteraction(_ interaction: UIInteraction, willBeginWritingInElement elementIdentifier: ElementIdentifier)
    func indirectScribbleInteraction(_ interaction: UIInteraction, didFinishWritingInElement elementIdentifier: ElementIdentifier)
}
extension UIIndirectScribbleInteractionDelegate {
    public func indirectScribbleInteraction(_ interaction: UIInteraction, shouldDelayFocusForElement elementIdentifier: ElementIdentifier) -> Bool { false }
    public func indirectScribbleInteraction(_ interaction: UIInteraction, willBeginWritingInElement elementIdentifier: ElementIdentifier) {}
    public func indirectScribbleInteraction(_ interaction: UIInteraction, didFinishWritingInElement elementIdentifier: ElementIdentifier) {}
}

/// an element identifier crossing into Objective-C
final class _IsimScribbleElement: NSObject, NSCopying {
    let value: AnyHashable
    init(_ v: AnyHashable) { value = v }
    func copy(with zone: NSZone? = nil) -> Any { self }
    override func isEqual(_ object: Any?) -> Bool { (object as? _IsimScribbleElement)?.value == value }
    override var hash: Int { value.hashValue }
    override var description: String { "\(value)" }
}

/// forwards the Objective-C delegate calls to a Swift delegate
final class _IsimIndirectScribbleAdapter: NSObject, _UIIndirectScribbleInteractionDelegateObjC {
    weak var target: (any UIIndirectScribbleInteractionDelegate)?
    init(_ d: any UIIndirectScribbleInteractionDelegate) { target = d }
    private func unbox<D: UIIndirectScribbleInteractionDelegate>(_ d: D, _ e: any NSCopying & NSObjectProtocol) -> D.ElementIdentifier? {
        (e as? _IsimScribbleElement)?.value.base as? D.ElementIdentifier
    }
    func indirectScribbleInteraction(_ interaction: UIIndirectScribbleInteraction, requestElementsIn rect: CGRect,
                                     completion: @escaping ([any NSCopying & NSObjectProtocol]) -> Void) {
        guard let t = target else { completion([]); return }
        func go<D: UIIndirectScribbleInteractionDelegate>(_ d: D) {
            d.indirectScribbleInteraction(interaction, requestElementsIn: rect) { ids in completion(ids.map { _IsimScribbleElement(AnyHashable($0)) }) }
        }
        go(t)
    }
    func indirectScribbleInteraction(_ interaction: UIIndirectScribbleInteraction, isElementFocused e: any NSCopying & NSObjectProtocol) -> Bool {
        guard let t = target else { return false }
        func go<D: UIIndirectScribbleInteractionDelegate>(_ d: D) -> Bool { unbox(d, e).map { d.indirectScribbleInteraction(interaction, isElementFocused: $0) } ?? false }
        return go(t)
    }
    func indirectScribbleInteraction(_ interaction: UIIndirectScribbleInteraction, frameForElement e: any NSCopying & NSObjectProtocol) -> CGRect {
        guard let t = target else { return .null }
        func go<D: UIIndirectScribbleInteractionDelegate>(_ d: D) -> CGRect { unbox(d, e).map { d.indirectScribbleInteraction(interaction, frameForElement: $0) } ?? .null }
        return go(t)
    }
    func indirectScribbleInteraction(_ interaction: UIIndirectScribbleInteraction, focusElementIfNeeded e: any NSCopying & NSObjectProtocol,
                                     referencePoint p: CGPoint, completion: @escaping ((UIResponder & UITextInput)?) -> Void) {
        guard let t = target else { completion(nil); return }
        func go<D: UIIndirectScribbleInteractionDelegate>(_ d: D) {
            guard let id = unbox(d, e) else { completion(nil); return }
            d.indirectScribbleInteraction(interaction, focusElementIfNeeded: id, referencePoint: p, completion: completion)
        }
        go(t)
    }
    func indirectScribbleInteraction(_ interaction: UIIndirectScribbleInteraction, shouldDelayFocusForElement e: any NSCopying & NSObjectProtocol) -> Bool {
        guard let t = target else { return false }
        func go<D: UIIndirectScribbleInteractionDelegate>(_ d: D) -> Bool { unbox(d, e).map { d.indirectScribbleInteraction(interaction, shouldDelayFocusForElement: $0) } ?? false }
        return go(t)
    }
    func indirectScribbleInteraction(_ interaction: UIIndirectScribbleInteraction, willBeginWritingInElement e: any NSCopying & NSObjectProtocol) {
        guard let t = target else { return }
        func go<D: UIIndirectScribbleInteractionDelegate>(_ d: D) { if let id = unbox(d, e) { d.indirectScribbleInteraction(interaction, willBeginWritingInElement: id) } }
        go(t)
    }
    func indirectScribbleInteraction(_ interaction: UIIndirectScribbleInteraction, didFinishWritingInElement e: any NSCopying & NSObjectProtocol) {
        guard let t = target else { return }
        func go<D: UIIndirectScribbleInteractionDelegate>(_ d: D) { if let id = unbox(d, e) { d.indirectScribbleInteraction(interaction, didFinishWritingInElement: id) } }
        go(t)
    }
}

private var _isimScribbleAdapterKey: UInt8 = 0
extension UIIndirectScribbleInteraction {
    public convenience init(delegate: some UIIndirectScribbleInteractionDelegate) {
        let adapter = _IsimIndirectScribbleAdapter(delegate)
        self.init(__delegate: adapter)
        objc_setAssociatedObject(self, &_isimScribbleAdapterKey, adapter, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
    public var delegate: (any UIIndirectScribbleInteractionDelegate)? {
        (objc_getAssociatedObject(self, &_isimScribbleAdapterKey) as? _IsimIndirectScribbleAdapter)?.target
    }
}
