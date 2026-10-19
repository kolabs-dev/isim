// isim UIKit drag and drop for Objective-C (sdk-src/Frameworks/UIKit: UIDragInteraction.h, UIDropInteraction.h,
// UIDragItem.h, UIDragSession.h, UITableViewDragDrop.h, UICollectionViewDragDrop.h, UITextDropping.h,
// UISpringLoadedInteraction.h, UIPasteConfiguration.h): the classes carry Apple's Objective-C names and these members
// Apple's selectors. The delegate protocols are Swift protocols in this overlay, so an Objective-C delegate is wrapped
// in an adapter that conforms to the Swift protocol and calls the object through the @objc protocols below, which
// have Apple's names and selectors (an optional method only when the object implements it, else the Swift default).
// The adapter is kept by the object it is set on; the delegate itself stays weak, as on iOS.
import ObjectiveC

// MARK: - Apple's Objective-C protocols, as the adapters call them
@MainActor @objc(UIDragInteractionDelegate) protocol _ObjCDragInteractionDelegate: NSObjectProtocol {
    @objc(dragInteraction:itemsForBeginningSession:) optional func items(_ i: UIDragInteraction, _ s: AnyObject) -> [UIDragItem]
    @objc(dragInteraction:previewForLiftingItem:session:) optional func preview(_ i: UIDragInteraction, _ item: UIDragItem, _ s: AnyObject) -> UITargetedDragPreview?
    @objc(dragInteraction:willAnimateLiftWithAnimator:session:) optional func willAnimate(_ i: UIDragInteraction, _ a: AnyObject, _ s: AnyObject)
    @objc(dragInteraction:sessionWillBegin:) optional func willBegin(_ i: UIDragInteraction, _ s: AnyObject)
    @objc(dragInteraction:sessionAllowsMoveOperation:) optional func allowsMove(_ i: UIDragInteraction, _ s: AnyObject) -> Bool
    @objc(dragInteraction:sessionDidMove:) optional func didMove(_ i: UIDragInteraction, _ s: AnyObject)
    @objc(dragInteraction:session:willEndWithOperation:) optional func willEnd(_ i: UIDragInteraction, _ s: AnyObject, _ op: UIDropOperation)
    @objc(dragInteraction:session:didEndWithOperation:) optional func didEnd(_ i: UIDragInteraction, _ s: AnyObject, _ op: UIDropOperation)
}
@MainActor @objc(UIDropInteractionDelegate) protocol _ObjCDropInteractionDelegate: NSObjectProtocol {
    @objc(dropInteraction:canHandleSession:) optional func canHandle(_ i: UIDropInteraction, _ s: AnyObject) -> Bool
    @objc(dropInteraction:sessionDidEnter:) optional func didEnter(_ i: UIDropInteraction, _ s: AnyObject)
    @objc(dropInteraction:sessionDidUpdate:) optional func didUpdate(_ i: UIDropInteraction, _ s: AnyObject) -> UIDropProposal
    @objc(dropInteraction:sessionDidExit:) optional func didExit(_ i: UIDropInteraction, _ s: AnyObject)
    @objc(dropInteraction:performDrop:) optional func perform(_ i: UIDropInteraction, _ s: AnyObject)
    @objc(dropInteraction:concludeDrop:) optional func conclude(_ i: UIDropInteraction, _ s: AnyObject)
    @objc(dropInteraction:sessionDidEnd:) optional func didEnd(_ i: UIDropInteraction, _ s: AnyObject)
}
@MainActor @objc(UITableViewDragDelegate) protocol _ObjCTableViewDragDelegate: NSObjectProtocol {
    @objc(tableView:itemsForBeginningDragSession:atIndexPath:) optional func items(_ tv: UITableView, _ s: AnyObject, _ ip: IndexPath) -> [UIDragItem]
    @objc(tableView:dragSessionWillBegin:) optional func willBegin(_ tv: UITableView, _ s: AnyObject)
    @objc(tableView:dragSessionDidEnd:) optional func didEnd(_ tv: UITableView, _ s: AnyObject)
}
@MainActor @objc(UITableViewDropDelegate) protocol _ObjCTableViewDropDelegate: NSObjectProtocol {
    @objc(tableView:performDropWithCoordinator:) optional func perform(_ tv: UITableView, _ c: AnyObject)
    @objc(tableView:canHandleDropSession:) optional func canHandle(_ tv: UITableView, _ s: AnyObject) -> Bool
    @objc(tableView:dropSessionDidUpdate:withDestinationIndexPath:) optional func didUpdate(_ tv: UITableView, _ s: AnyObject, _ ip: IndexPath?) -> UITableViewDropProposal
}
@MainActor @objc(UICollectionViewDragDelegate) protocol _ObjCCollectionViewDragDelegate: NSObjectProtocol {
    @objc(collectionView:itemsForBeginningDragSession:atIndexPath:) optional func items(_ cv: UICollectionView, _ s: AnyObject, _ ip: IndexPath) -> [UIDragItem]
}
@MainActor @objc(UICollectionViewDropDelegate) protocol _ObjCCollectionViewDropDelegate: NSObjectProtocol {
    @objc(collectionView:performDropWithCoordinator:) optional func perform(_ cv: UICollectionView, _ c: AnyObject)
    @objc(collectionView:canHandleDropSession:) optional func canHandle(_ cv: UICollectionView, _ s: AnyObject) -> Bool
    @objc(collectionView:dropSessionDidUpdate:withDestinationIndexPath:) optional func didUpdate(_ cv: UICollectionView, _ s: AnyObject, _ ip: IndexPath?) -> UICollectionViewDropProposal
}
@MainActor @objc(UITextDropDelegate) protocol _ObjCTextDropDelegate: NSObjectProtocol {
    @objc(textDroppableView:willBecomeEditableForDrop:) optional func willBecomeEditable(_ v: UIView, _ r: AnyObject) -> UITextDropEditability
    @objc(textDroppableView:proposalForDrop:) optional func proposal(_ v: UIView, _ r: AnyObject) -> UITextDropProposal
    @objc(textDroppableView:willPerformDrop:) optional func willPerform(_ v: UIView, _ r: AnyObject)
    @objc(textDroppableView:previewForDroppingAllItemsWithDefault:) optional func preview(_ v: UIView, _ p: UITargetedDragPreview) -> UITargetedDragPreview?
    @objc(textDroppableView:dropSessionDidEnter:) optional func didEnter(_ v: UIView, _ s: AnyObject)
    @objc(textDroppableView:dropSessionDidUpdate:) optional func didUpdate(_ v: UIView, _ s: AnyObject)
    @objc(textDroppableView:dropSessionDidExit:) optional func didExit(_ v: UIView, _ s: AnyObject)
    @objc(textDroppableView:dropSessionDidEnd:) optional func didEnd(_ v: UIView, _ s: AnyObject)
}
@MainActor @objc(UISpringLoadedInteractionBehavior) protocol _ObjCSpringLoadedBehavior: NSObjectProtocol {
    @objc(shouldAllowInteraction:withContext:) optional func shouldAllow(_ i: UISpringLoadedInteraction, _ c: AnyObject) -> Bool
    @objc(interactionDidFinish:) optional func didFinish(_ i: UISpringLoadedInteraction)
}
@MainActor @objc(UISpringLoadedInteractionEffect) protocol _ObjCSpringLoadedEffect: NSObjectProtocol {
    @objc(interaction:didChangeWithContext:) optional func didChange(_ i: UISpringLoadedInteraction, _ c: AnyObject)
}

/// an Objective-C object seen through one of the protocols above (an @objc protocol existential is the object itself)
@inline(__always) func _objc<P>(_ o: AnyObject?, _ p: P.Type) -> P? { o.map { unsafeBitCast($0, to: p) } }
nonisolated(unsafe) private var kObjCAdapter: UInt8 = 0, kObjCDropAdapter: UInt8 = 0
/// keeps the adapter for an Objective-C delegate alive as long as what it is set on
private func keep(_ owner: AnyObject, _ key: UnsafeRawPointer, _ adapter: AnyObject?) {
    objc_setAssociatedObject(owner, key, adapter, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

// MARK: - adapters: Swift protocol conformances that call an Objective-C delegate
@MainActor final class _ObjCDragInteractionAdapter: NSObject, @preconcurrency UIDragInteractionDelegate {
    weak var target: AnyObject?
    init(_ t: AnyObject) { target = t }
    var d: _ObjCDragInteractionDelegate? { _objc(target, _ObjCDragInteractionDelegate.self) }
    func dragInteraction(_ i: UIDragInteraction, itemsForBeginning s: UIDragSession) -> [UIDragItem] { d?.items?(i, s) ?? [] }
    func dragInteraction(_ i: UIDragInteraction, previewForLifting item: UIDragItem, session s: UIDragSession) -> UITargetedDragPreview? {
        d?.preview?(i, item, s)
    }
    func dragInteraction(_ i: UIDragInteraction, willAnimateLiftWith a: UIDragAnimating, session s: UIDragSession) { d?.willAnimate?(i, a, s) }
    func dragInteraction(_ i: UIDragInteraction, sessionWillBegin s: UIDragSession) { d?.willBegin?(i, s) }
    func dragInteraction(_ i: UIDragInteraction, sessionDidMove s: UIDragSession) { d?.didMove?(i, s) }
    func dragInteraction(_ i: UIDragInteraction, session s: UIDragSession, willEndWith op: UIDropOperation) { d?.willEnd?(i, s, op) }
    func dragInteraction(_ i: UIDragInteraction, session s: UIDragSession, didEndWith op: UIDropOperation) { d?.didEnd?(i, s, op) }
    func dragInteraction(_ i: UIDragInteraction, sessionAllowsMoveOperation s: UIDragSession) -> Bool { d?.allowsMove?(i, s) ?? true }
}
@MainActor final class _ObjCDropInteractionAdapter: NSObject, @preconcurrency UIDropInteractionDelegate {
    weak var target: AnyObject?
    init(_ t: AnyObject) { target = t }
    var d: _ObjCDropInteractionDelegate? { _objc(target, _ObjCDropInteractionDelegate.self) }
    func dropInteraction(_ i: UIDropInteraction, canHandle s: UIDropSession) -> Bool { d?.canHandle?(i, s) ?? true }
    func dropInteraction(_ i: UIDropInteraction, sessionDidEnter s: UIDropSession) { d?.didEnter?(i, s) }
    func dropInteraction(_ i: UIDropInteraction, sessionDidUpdate s: UIDropSession) -> UIDropProposal { d?.didUpdate?(i, s) ?? UIDropProposal(operation: .cancel) }
    func dropInteraction(_ i: UIDropInteraction, sessionDidExit s: UIDropSession) { d?.didExit?(i, s) }
    func dropInteraction(_ i: UIDropInteraction, performDrop s: UIDropSession) { d?.perform?(i, s) }
    func dropInteraction(_ i: UIDropInteraction, concludeDrop s: UIDropSession) { d?.conclude?(i, s) }
    func dropInteraction(_ i: UIDropInteraction, sessionDidEnd s: UIDropSession) { d?.didEnd?(i, s) }
}
@MainActor final class _ObjCTableDragAdapter: NSObject, @preconcurrency UITableViewDragDelegate {
    weak var target: AnyObject?
    init(_ t: AnyObject) { target = t }
    var d: _ObjCTableViewDragDelegate? { _objc(target, _ObjCTableViewDragDelegate.self) }
    func tableView(_ tv: UITableView, itemsForBeginning s: UIDragSession, at ip: IndexPath) -> [UIDragItem] { d?.items?(tv, s, ip) ?? [] }
    func tableView(_ tv: UITableView, dragSessionWillBegin s: UIDragSession) { d?.willBegin?(tv, s) }
    func tableView(_ tv: UITableView, dragSessionDidEnd s: UIDragSession) { d?.didEnd?(tv, s) }
}
@MainActor final class _ObjCTableDropAdapter: NSObject, @preconcurrency UITableViewDropDelegate {
    weak var target: AnyObject?
    init(_ t: AnyObject) { target = t }
    var d: _ObjCTableViewDropDelegate? { _objc(target, _ObjCTableViewDropDelegate.self) }
    func tableView(_ tv: UITableView, performDropWith c: UITableViewDropCoordinator) { d?.perform?(tv, _ObjCTableDropCoordinator(c)) }
    func tableView(_ tv: UITableView, canHandle s: UIDropSession) -> Bool { d?.canHandle?(tv, s) ?? true }
    func tableView(_ tv: UITableView, dropSessionDidUpdate s: UIDropSession, withDestinationIndexPath ip: IndexPath?) -> UITableViewDropProposal {
        d?.didUpdate?(tv, s, ip) ?? UITableViewDropProposal(operation: s.localDragSession != nil ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
}
@MainActor final class _ObjCCollectionDragAdapter: NSObject, @preconcurrency UICollectionViewDragDelegate {
    weak var target: AnyObject?
    init(_ t: AnyObject) { target = t }
    func collectionView(_ cv: UICollectionView, itemsForBeginning s: UIDragSession, at ip: IndexPath) -> [UIDragItem] {
        _objc(target, _ObjCCollectionViewDragDelegate.self)?.items?(cv, s, ip) ?? []
    }
}
@MainActor final class _ObjCCollectionDropAdapter: NSObject, @preconcurrency UICollectionViewDropDelegate {
    weak var target: AnyObject?
    init(_ t: AnyObject) { target = t }
    var d: _ObjCCollectionViewDropDelegate? { _objc(target, _ObjCCollectionViewDropDelegate.self) }
    func collectionView(_ cv: UICollectionView, performDropWith c: UICollectionViewDropCoordinator) { d?.perform?(cv, _ObjCCollectionDropCoordinator(c)) }
    func collectionView(_ cv: UICollectionView, canHandle s: UIDropSession) -> Bool { d?.canHandle?(cv, s) ?? true }
    func collectionView(_ cv: UICollectionView, dropSessionDidUpdate s: UIDropSession, withDestinationIndexPath ip: IndexPath?) -> UICollectionViewDropProposal {
        d?.didUpdate?(cv, s, ip) ?? UICollectionViewDropProposal(operation: s.localDragSession != nil ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
}
@MainActor final class _ObjCTextDropAdapter: NSObject, UITextDropDelegate {
    weak var target: AnyObject?
    init(_ t: AnyObject) { target = t }
    var d: _ObjCTextDropDelegate? { _objc(target, _ObjCTextDropDelegate.self) }
    func textDroppableView(_ v: UIView & UITextDroppable, willBecomeEditableForDrop r: UITextDropRequest) -> UITextDropEditability { d?.willBecomeEditable?(v, r) ?? .no }
    func textDroppableView(_ v: UIView & UITextDroppable, proposalForDrop r: UITextDropRequest) -> UITextDropProposal { d?.proposal?(v, r) ?? r.suggestedProposal }
    func textDroppableView(_ v: UIView & UITextDroppable, willPerformDrop r: UITextDropRequest) { d?.willPerform?(v, r) }
    func textDroppableView(_ v: UIView & UITextDroppable, previewForDroppingAllItemsWithDefault p: UITargetedDragPreview) -> UITargetedDragPreview? {
        guard let d, d.responds(to: #selector(_ObjCTextDropDelegate.preview(_:_:))) else { return p }
        return d.preview?(v, p)
    }
    func textDroppableView(_ v: UIView & UITextDroppable, dropSessionDidEnter s: UIDropSession) { d?.didEnter?(v, s) }
    func textDroppableView(_ v: UIView & UITextDroppable, dropSessionDidUpdate s: UIDropSession) { d?.didUpdate?(v, s) }
    func textDroppableView(_ v: UIView & UITextDroppable, dropSessionDidExit s: UIDropSession) { d?.didExit?(v, s) }
    func textDroppableView(_ v: UIView & UITextDroppable, dropSessionDidEnd s: UIDropSession) { d?.didEnd?(v, s) }
}
@MainActor final class _ObjCSpringBehaviorAdapter: NSObject, UISpringLoadedInteractionBehavior {
    let target: AnyObject                         // (the interaction keeps its behaviour, as on iOS)
    init(_ t: AnyObject) { target = t }
    func shouldAllow(_ i: UISpringLoadedInteraction, with c: UISpringLoadedInteractionContext) -> Bool {
        _objc(target, _ObjCSpringLoadedBehavior.self)?.shouldAllow?(i, c) ?? true
    }
    func interactionDidFinish(_ i: UISpringLoadedInteraction) { _objc(target, _ObjCSpringLoadedBehavior.self)?.didFinish?(i) }
}
@MainActor final class _ObjCSpringEffectAdapter: NSObject, UISpringLoadedInteractionEffect {
    let target: AnyObject
    init(_ t: AnyObject) { target = t }
    func interaction(_ i: UISpringLoadedInteraction, didChangeWith c: UISpringLoadedInteractionContext) {
        _objc(target, _ObjCSpringLoadedEffect.self)?.didChange?(i, c)
    }
}

// MARK: - drop coordinators and items for Objective-C
final class _ObjCDropItem: NSObject {
    @objc let dragItem: UIDragItem
    let source: IndexPath?
    @objc let previewSize: CGSize
    init(_ dragItem: UIDragItem, _ source: IndexPath?, _ size: CGSize) { self.dragItem = dragItem; self.source = source; previewSize = size }
    @objc var sourceIndexPath: IndexPath? { source }
}
@MainActor final class _ObjCTableDropCoordinator: NSObject {
    let base: UITableViewDropCoordinator
    init(_ b: UITableViewDropCoordinator) { base = b }
    @objc var items: [_ObjCDropItem] { base.items.map { _ObjCDropItem($0.dragItem, $0.sourceIndexPath, $0.previewSize) } }
    @objc var destinationIndexPath: IndexPath? { base.destinationIndexPath }
    @objc var proposal: UITableViewDropProposal { base.proposal }
    @objc var session: AnyObject { base.session }
    @objc(dropItem:toRowAtIndexPath:) func drop(_ item: UIDragItem, toRowAt ip: IndexPath) -> AnyObject { base.drop(item, toRowAt: ip) }
}
@MainActor final class _ObjCCollectionDropCoordinator: NSObject {
    let base: UICollectionViewDropCoordinator
    init(_ b: UICollectionViewDropCoordinator) { base = b }
    @objc var items: [_ObjCDropItem] { base.items.map { _ObjCDropItem($0.dragItem, $0.sourceIndexPath, $0.previewSize) } }
    @objc var destinationIndexPath: IndexPath? { base.destinationIndexPath }
    @objc var proposal: UICollectionViewDropProposal { base.proposal }
    @objc var session: AnyObject { base.session }
    @objc(dropItem:toItemAtIndexPath:) func drop(_ item: UIDragItem, toItemAt ip: IndexPath) -> AnyObject { base.drop(item, toItemAt: ip) }
}

// MARK: - the classes' Objective-C members
extension UIDragItem {
    @objc(initWithItemProvider:) convenience init(_objcItemProvider p: NSItemProvider) { self.init(itemProvider: p) }
    @objc(itemProvider) var _objc_itemProvider: NSItemProvider { itemProvider }
    @objc(localObject) var _objc_localObject: Any? { get { localObject } set { localObject = newValue } }
    @objc(previewProvider) var _objc_previewProvider: (@convention(block) () -> UIDragPreview?)? {
        get { guard let f = previewProvider else { return nil }; return { f() } }
        set { guard let b = newValue else { previewProvider = nil; return }; previewProvider = { b() } }
    }
}
extension UIDragPreview {
    @objc(initWithView:parameters:) convenience init(_objcView v: UIView, parameters: UIDragPreviewParameters) { self.init(view: v, parameters: parameters) }
    @objc(initWithView:) convenience init(_objcView v: UIView) { self.init(view: v) }
    @objc(view) var _objc_view: UIView { view }
    @objc(parameters) var _objc_parameters: UIDragPreviewParameters { parameters }
}
extension UIDropProposal {
    @objc(initWithDropOperation:) convenience init(_objcOperation op: UIDropOperation) { self.init(operation: op) }
    @objc(operation) var _objc_operation: UIDropOperation { operation }
    @objc(precise) var _objc_precise: Bool {
        @objc(isPrecise) get { isPrecise }
        @objc(setPrecise:) set { isPrecise = newValue }
    }
    @objc(prefersFullSizePreview) var _objc_prefersFullSizePreview: Bool { get { prefersFullSizePreview } set { prefersFullSizePreview = newValue } }
}
extension UITableViewDropProposal {
    @objc(initWithDropOperation:intent:) convenience init(_objcOperation op: UIDropOperation, intent: UITableViewDropIntent) { self.init(operation: op, intent: intent) }
    @objc(intent) var _objc_intent: UITableViewDropIntent { intent }
}
extension UICollectionViewDropProposal {
    @objc(initWithDropOperation:intent:) convenience init(_objcOperation op: UIDropOperation, intent: UICollectionViewDropIntent) { self.init(operation: op, intent: intent) }
    @objc(intent) var _objc_intent: UICollectionViewDropIntent { intent }
}
extension UITextDropProposal {
    @objc(dropAction) var _objc_dropAction: Action { get { dropAction } set { dropAction = newValue } }
    @objc(dropProgressMode) var _objc_dropProgressMode: ProgressMode { get { dropProgressMode } set { dropProgressMode = newValue } }
    @objc(useFastSameViewOperations) var _objc_useFastSameViewOperations: Bool { get { useFastSameViewOperations } set { useFastSameViewOperations = newValue } }
    @objc(dropPerformer) var _objc_dropPerformer: Performer { get { dropPerformer } set { dropPerformer = newValue } }
}
extension UIDragInteraction {
    @objc(initWithDelegate:) convenience init(_objcDelegate o: AnyObject) {
        if let d = o as? UIDragInteractionDelegate { self.init(delegate: d); return }
        let a = _ObjCDragInteractionAdapter(o)
        self.init(delegate: a)
        keep(self, &kObjCAdapter, a)
    }
    @objc(delegate) var _objc_delegate: AnyObject? { (delegate as? _ObjCDragInteractionAdapter)?.target ?? (delegate as AnyObject?) }
    @objc(enabled) var _objc_enabled: Bool {
        @objc(isEnabled) get { isEnabled }
        @objc(setEnabled:) set { isEnabled = newValue }
    }
    @objc(allowsSimultaneousRecognitionDuringLift) var _objc_allowsSimultaneous: Bool {
        get { allowsSimultaneousRecognitionDuringLift } set { allowsSimultaneousRecognitionDuringLift = newValue }
    }
    @objc(isEnabledByDefault) class var _objc_enabledByDefault: Bool { isEnabledByDefault }
}
extension UIDropInteraction {
    @objc(initWithDelegate:) convenience init(_objcDelegate o: AnyObject) {
        if let d = o as? UIDropInteractionDelegate { self.init(delegate: d); return }
        let a = _ObjCDropInteractionAdapter(o)
        self.init(delegate: a)
        keep(self, &kObjCAdapter, a)
    }
    @objc(delegate) var _objc_delegate: AnyObject? { (delegate as? _ObjCDropInteractionAdapter)?.target ?? (delegate as AnyObject?) }
    @objc(allowsSimultaneousDropSessions) var _objc_allowsSimultaneous: Bool {
        get { allowsSimultaneousDropSessions } set { allowsSimultaneousDropSessions = newValue }
    }
}
extension UISpringLoadedInteraction {
    @objc(initWithInteractionBehavior:interactionEffect:activationHandler:)
    convenience init(_objcBehavior b: AnyObject?, effect e: AnyObject?, handler: @escaping @convention(block) (UISpringLoadedInteraction, AnyObject) -> Void) {
        let behavior: UISpringLoadedInteractionBehavior? = b.map { o -> UISpringLoadedInteractionBehavior in
            (o as? UISpringLoadedInteractionBehavior) ?? _ObjCSpringBehaviorAdapter(o)
        }
        let effect: UISpringLoadedInteractionEffect? = e.map { o -> UISpringLoadedInteractionEffect in
            (o as? UISpringLoadedInteractionEffect) ?? _ObjCSpringEffectAdapter(o)
        }
        self.init(interactionBehavior: behavior, interactionEffect: effect, activationHandler: { i, c in handler(i, c) })
    }
    @objc(initWithActivationHandler:)
    convenience init(_objcHandler handler: @escaping @convention(block) (UISpringLoadedInteraction, AnyObject) -> Void) {
        self.init(interactionBehavior: nil, interactionEffect: nil, activationHandler: { i, c in handler(i, c) })
    }
    @objc(interactionBehavior) var _objc_behavior: AnyObject { (interactionBehavior as? _ObjCSpringBehaviorAdapter)?.target ?? (interactionBehavior as AnyObject) }
    @objc(interactionEffect) var _objc_effect: AnyObject { (interactionEffect as? _ObjCSpringEffectAdapter)?.target ?? (interactionEffect as AnyObject) }
}
extension UIPasteConfiguration {
    @objc(acceptableTypeIdentifiers) var _objc_acceptableTypeIdentifiers: [String] {
        get { acceptableTypeIdentifiers } set { acceptableTypeIdentifiers = newValue }
    }
    @objc(initWithAcceptableTypeIdentifiers:) convenience init(_objcTypes ids: [String]) { self.init(acceptableTypeIdentifiers: ids) }
    @objc(initWithTypeIdentifiersForAcceptingClass:) convenience init(_objcAccepting c: AnyClass) {
        self.init(acceptableTypeIdentifiers: (c as? NSItemProviderReading.Type)?.readableTypeIdentifiersForItemProvider ?? [])
    }
    @objc(addAcceptableTypeIdentifiers:) func _objc_addAcceptableTypeIdentifiers(_ ids: [String]) { addAcceptableTypeIdentifiers(ids) }
    @objc(addTypeIdentifiersForAcceptingClass:) func _objc_addTypeIdentifiers(forAccepting c: AnyClass) {
        if let r = c as? NSItemProviderReading.Type { addTypeIdentifiers(forAccepting: r) }
    }
}

// MARK: - sessions: the members Swift types do not express in Objective-C
extension _IsimDragSession {
    @objc(localDragSession) var _objc_localDragSession: AnyObject? { self }
    @objc(canLoadObjectsOfClass:) func _objc_canLoadObjects(ofClass c: AnyClass) -> Bool {
        (c as? NSItemProviderReading.Type).map { canLoadObjects(ofClass: $0) } ?? false
    }
    @objc(loadObjectsOfClass:completion:) func _objc_loadObjects(ofClass c: AnyClass, completion: @escaping @convention(block) ([AnyObject]) -> Void) -> Progress {
        guard let r = c as? NSItemProviderReading.Type else { completion([]); return progress }
        return loadObjects(ofClass: r) { objs in completion(objs.map { $0 as AnyObject }) }
    }
}

// MARK: - table, collection and text views
extension UITableView {
    @objc(dragDelegate) var _objc_dragDelegate: AnyObject? {
        get { (dragDelegate as? _ObjCTableDragAdapter)?.target ?? (dragDelegate as AnyObject?) }
        set {
            if let d = newValue as? UITableViewDragDelegate { keep(self, &kObjCAdapter, nil); dragDelegate = d; return }
            let a = newValue.map { _ObjCTableDragAdapter($0) }
            keep(self, &kObjCAdapter, a); dragDelegate = a
        }
    }
    @objc(dropDelegate) var _objc_dropDelegate: AnyObject? {
        get { (dropDelegate as? _ObjCTableDropAdapter)?.target ?? (dropDelegate as AnyObject?) }
        set {
            if let d = newValue as? UITableViewDropDelegate { keep(self, &kObjCDropAdapter, nil); dropDelegate = d; return }
            let a = newValue.map { _ObjCTableDropAdapter($0) }
            keep(self, &kObjCDropAdapter, a); dropDelegate = a
        }
    }
    @objc(dragInteractionEnabled) var _objc_dragInteractionEnabled: Bool { get { dragInteractionEnabled } set { dragInteractionEnabled = newValue } }
    @objc(hasActiveDrag) var _objc_hasActiveDrag: Bool { hasActiveDrag }
}
extension UICollectionView {
    @objc(dragDelegate) var _objc_dragDelegate: AnyObject? {
        get { (dragDelegate as? _ObjCCollectionDragAdapter)?.target ?? (dragDelegate as AnyObject?) }
        set {
            if let d = newValue as? UICollectionViewDragDelegate { keep(self, &kObjCAdapter, nil); dragDelegate = d; return }
            let a = newValue.map { _ObjCCollectionDragAdapter($0) }
            keep(self, &kObjCAdapter, a); dragDelegate = a
        }
    }
    @objc(dropDelegate) var _objc_dropDelegate: AnyObject? {
        get { (dropDelegate as? _ObjCCollectionDropAdapter)?.target ?? (dropDelegate as AnyObject?) }
        set {
            if let d = newValue as? UICollectionViewDropDelegate { keep(self, &kObjCDropAdapter, nil); dropDelegate = d; return }
            let a = newValue.map { _ObjCCollectionDropAdapter($0) }
            keep(self, &kObjCDropAdapter, a); dropDelegate = a
        }
    }
    @objc(dragInteractionEnabled) var _objc_dragInteractionEnabled: Bool { get { dragInteractionEnabled } set { dragInteractionEnabled = newValue } }
    @objc(hasActiveDrag) var _objc_hasActiveDrag: Bool { hasActiveDrag }
}
extension UITextView {
    @objc(textDropDelegate) var _objc_textDropDelegate: AnyObject? {
        get { (textDropDelegate as? _ObjCTextDropAdapter)?.target ?? (textDropDelegate as AnyObject?) }
        set {
            if let d = newValue as? UITextDropDelegate { keep(self, &kObjCDropAdapter, nil); textDropDelegate = d; return }
            let a = newValue.map { _ObjCTextDropAdapter($0) }
            keep(self, &kObjCDropAdapter, a); textDropDelegate = a
        }
    }
    @objc(textDropInteraction) var _objc_textDropInteraction: UIDropInteraction? { textDropInteraction }
    @objc(isTextDropActive) var _objc_isTextDropActive: Bool { isTextDropActive }
}
extension UITextField {
    @objc(textDropDelegate) var _objc_textDropDelegate: AnyObject? {
        get { (textDropDelegate as? _ObjCTextDropAdapter)?.target ?? (textDropDelegate as AnyObject?) }
        set {
            if let d = newValue as? UITextDropDelegate { keep(self, &kObjCDropAdapter, nil); textDropDelegate = d; return }
            let a = newValue.map { _ObjCTextDropAdapter($0) }
            keep(self, &kObjCDropAdapter, a); textDropDelegate = a
        }
    }
    @objc(textDropInteraction) var _objc_textDropInteraction: UIDropInteraction? { textDropInteraction }
    @objc(isTextDropActive) var _objc_isTextDropActive: Bool { isTextDropActive }
}
