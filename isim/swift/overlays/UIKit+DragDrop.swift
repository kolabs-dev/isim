// isim UIKit overlay: drag and drop within an app (self-authored).
// UIDragInteraction lifts after a long press (0.5 s; script `longdrag X1 Y1 X2 Y2 HOLD SECS`), the lifted preview
// follows the finger in a window above the app, and UIDropInteractions under the finger are asked whether they
// can handle the session, get enter/update/exit, and perform the drop (items carry NSItemProviders). UITableView and
// UICollectionView take dragDelegate/dropDelegate (reordering through the data source's move, insertion through
// performDrop). Drags don't cross apps on isim.
@_exported import UniformTypeIdentifiers

// MARK: - items, previews, proposals
@objc(UIDragItem) open class UIDragItem: NSObject {
    public let itemProvider: NSItemProvider
    open var localObject: Any?
    open var previewProvider: (() -> UIDragPreview?)?
    public init(itemProvider: NSItemProvider) { self.itemProvider = itemProvider }
}
@objc(UIDragPreviewParameters) open class UIDragPreviewParameters: UIPreviewParameters {}
@objc(UIDragPreview) open class UIDragPreview: NSObject {
    public let view: UIView
    public let parameters: UIDragPreviewParameters
    public init(view: UIView, parameters: UIDragPreviewParameters = UIDragPreviewParameters()) { self.view = view; self.parameters = parameters }
}
@objc(UITargetedDragPreview) open class UITargetedDragPreview: UITargetedPreview {}

@objc public enum UIDropOperation: Int, Sendable { case cancel = 0, forbidden = 1, copy = 2, move = 3 }
@objc(UIDropProposal) open class UIDropProposal: NSObject {
    public let operation: UIDropOperation
    open var isPrecise = false
    open var prefersFullSizePreview = false
    public init(operation: UIDropOperation) { self.operation = operation }
}
@objc public enum UIDropSessionProgressIndicatorStyle: Int, Sendable { case none, `default` }

// MARK: - sessions
public protocol UIDragDropSession: AnyObject {
    var items: [UIDragItem] { get }
    func location(in view: UIView) -> CGPoint
    var allowsMoveOperation: Bool { get }
    var isRestrictedToDraggingApplication: Bool { get }
    func hasItemsConforming(toTypeIdentifiers typeIdentifiers: [String]) -> Bool
    func canLoadObjects(ofClass aClass: NSItemProviderReading.Type) -> Bool
}
public protocol UIDragSession: UIDragDropSession {
    var localContext: Any? { get set }
}
public protocol UIDropSession: UIDragDropSession {
    var progress: Progress { get }
    var localDragSession: UIDragSession? { get }
    var progressIndicatorStyle: UIDropSessionProgressIndicatorStyle { get set }
    func loadObjects(ofClass aClass: NSItemProviderReading.Type, completion: @escaping ([NSItemProviderReading]) -> Void) -> Progress
}
extension UIDragDropSession {
    public func canLoadObjects<T: _ObjectiveCBridgeable>(ofClass: T.Type) -> Bool where T._ObjectiveCType: NSItemProviderReading {
        canLoadObjects(ofClass: T._ObjectiveCType.self)
    }
}
extension UIDropSession {
    @discardableResult
    public func loadObjects<T: _ObjectiveCBridgeable>(ofClass: T.Type, completion: @escaping ([T]) -> Void) -> Progress where T._ObjectiveCType: NSItemProviderReading {
        loadObjects(ofClass: T._ObjectiveCType.self) { objs in completion(objs.compactMap { $0 as? T._ObjectiveCType }.map { T._unconditionallyBridgeFromObjectiveC($0) }) }
    }
}

final class _IsimDragSession: NSObject, UIDragSession, UIDropSession, @unchecked Sendable {
    @objc var items: [UIDragItem]
    @objc var localContext: Any?
    @objc var progressIndicatorStyle: UIDropSessionProgressIndicatorStyle = .default
    @objc let progress = Progress(totalUnitCount: 1)
    var windowPoint = CGPoint.zero
    weak var window: UIWindow?
    init(items: [UIDragItem]) { self.items = items }
    @objc(locationInView:) func location(in view: UIView) -> CGPoint { view.convert(windowPoint, from: window ?? view.window) }
    @objc var allowsMoveOperation: Bool { true }
    @objc var isRestrictedToDraggingApplication: Bool { true }
    var localDragSession: UIDragSession? { self }
    @objc(hasItemsConformingToTypeIdentifiers:) func hasItemsConforming(toTypeIdentifiers ids: [String]) -> Bool { items.contains { i in ids.contains { i.itemProvider.hasItemConformingToTypeIdentifier($0) } } }
    func canLoadObjects(ofClass c: NSItemProviderReading.Type) -> Bool { items.contains { $0.itemProvider.canLoadObject(ofClass: c) } }
    func loadObjects(ofClass c: NSItemProviderReading.Type, completion: @escaping ([NSItemProviderReading]) -> Void) -> Progress {
        let group = DispatchGroup(), lock = NSLock()
        nonisolated(unsafe) var out: [(Int, NSItemProviderReading)] = []     /* appended under lock */
        for (i, item) in items.enumerated() where item.itemProvider.canLoadObject(ofClass: c) {
            group.enter()
            item.itemProvider.loadObject(ofClass: c) { obj, _ in
                if let obj { lock.lock(); out.append((i, obj)); lock.unlock() }
                group.leave()
            }
        }
        let p = progress
        let box = _UncheckedBox(completion)
        group.notify(queue: .main) { p.completedUnitCount = 1; box.value(out.sorted { $0.0 < $1.0 }.map(\.1)) }
        return p
    }
}
struct _UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

// (NSString and NSURL are item provider objects in Foundation, UIImage in UIKit)

// MARK: - delegates (optional methods have default implementations)
public protocol UIDragInteractionDelegate: AnyObject {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem]
    func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview?
    func dragInteraction(_ interaction: UIDragInteraction, willAnimateLiftWith animator: UIDragAnimating, session: UIDragSession)
    func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: UIDragSession)
    func dragInteraction(_ interaction: UIDragInteraction, sessionDidMove session: UIDragSession)
    func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, willEndWith operation: UIDropOperation)
    func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation)
    func dragInteraction(_ interaction: UIDragInteraction, sessionAllowsMoveOperation session: UIDragSession) -> Bool
}
extension UIDragInteractionDelegate {
    public func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? { nil }
    public func dragInteraction(_ interaction: UIDragInteraction, willAnimateLiftWith animator: UIDragAnimating, session: UIDragSession) {}
    public func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: UIDragSession) {}
    public func dragInteraction(_ interaction: UIDragInteraction, sessionDidMove session: UIDragSession) {}
    public func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, willEndWith operation: UIDropOperation) {}
    public func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation) {}
    public func dragInteraction(_ interaction: UIDragInteraction, sessionAllowsMoveOperation session: UIDragSession) -> Bool { true }
}
public protocol UIDropInteractionDelegate: AnyObject {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession)
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession)
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession)
    func dropInteraction(_ interaction: UIDropInteraction, concludeDrop session: UIDropSession)
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession)
}
extension UIDropInteractionDelegate {
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool { true }
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {}
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal { UIDropProposal(operation: .cancel) }
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {}
    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {}
    public func dropInteraction(_ interaction: UIDropInteraction, concludeDrop session: UIDropSession) {}
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {}
}
public protocol UIDragAnimating: AnyObject {
    func addAnimations(_ animations: @escaping () -> Void)
    func addCompletion(_ completion: @escaping (UIViewAnimatingPosition) -> Void)
}
final class _IsimDragAnimator: NSObject, UIDragAnimating {
    var animations: [() -> Void] = [], completions: [(UIViewAnimatingPosition) -> Void] = []
    @objc(addAnimations:) func addAnimations(_ a: @escaping () -> Void) { animations.append(a) }
    @objc(addCompletion:) func addCompletion(_ c: @escaping (UIViewAnimatingPosition) -> Void) { completions.append(c) }
    func run() {
        let a = animations, c = completions
        if a.isEmpty && c.isEmpty { return }
        UIView.animate(withDuration: 0.2, animations: { a.forEach { $0() } }, completion: { _ in c.forEach { $0(.end) } })
    }
}

// MARK: - interactions
@objc(UIDragInteraction) @MainActor open class UIDragInteraction: NSObject, UIInteraction {
    /// iOS 27: how a touch lifts the item (`extended`: a longer delay, and a second finger cancels, for gesture-rich views)
    @available(iOS 27.0, *)
    public enum LiftBehavior: UInt, @unchecked Sendable { case `default` = 0, extended = 1 }
    public private(set) weak var delegate: UIDragInteractionDelegate?
    open private(set) weak var view: UIView?
    open var isEnabled = true
    open var allowsSimultaneousRecognitionDuringLift = false
    /// iOS 27 (isim: 0.5 s lift delay by default, 0.75 s extended)
    @available(iOS 27.0, *)
    open var liftBehavior: LiftBehavior {
        get { LiftBehavior(rawValue: _liftBehavior) ?? .default }
        set { _liftBehavior = newValue.rawValue; press?.minimumPressDuration = _liftDelay }
    }
    /// iOS 27: a pointer (trackpad / mouse) drag starts as soon as the pointer moves, without the lift delay (default true)
    @available(iOS 27.0, *)
    open var allowsPointerDragBeforeLiftDelay: Bool {
        get { _pointerEarly }
        set { _pointerEarly = newValue }
    }
    var _liftBehavior: UInt = 0, _pointerEarly = true
    var _liftDelay: TimeInterval { _liftBehavior == 1 ? 0.75 : 0.5 }
    open class var isEnabledByDefault: Bool { true }
    var press: UILongPressGestureRecognizer?
    var pointerPan: UIPanGestureRecognizer?
    let gate = _IsimDragGate()
    public init(delegate: UIDragInteractionDelegate) { self.delegate = delegate }
    open func willMove(to view: UIView?) {
        if let p = press { self.view?.removeGestureRecognizer(p) }
        if let p = pointerPan { self.view?.removeGestureRecognizer(p) }
    }
    open func didMove(to view: UIView?) {
        self.view = view
        guard let view else { return }
        gate.interaction = self
        let p = UILongPressGestureRecognizer(target: self, action: #selector(_pressed(_:)))
        p.minimumPressDuration = _liftDelay
        p.delegate = gate
        view.addGestureRecognizer(p)
        press = p
        let pan = UIPanGestureRecognizer(target: self, action: #selector(_pointerPanned(_:)))   // pointer drags before the delay
        pan.delegate = gate
        view.addGestureRecognizer(pan)
        pointerPan = pan
    }
    @objc func _pressed(_ g: UILongPressGestureRecognizer) {
        guard isEnabled, let view else { return }
        if _liftBehavior == 1 && g.numberOfTouches > 1 {          // extended: a second finger cancels the lift
            if g.state == .began || g.state == .changed { _IsimDragController.current?.end(at: g.location(in: view.window), cancelled: true) }
            return
        }
        if g.state == .began && _IsimDragController.current != nil { return }   // a pointer drag started already
        _IsimDragController.handle(g, source: .interaction(self), view: view)
    }
    @objc func _pointerPanned(_ g: UIPanGestureRecognizer) {
        guard isEnabled, let view else { return }
        _IsimDragController.handlePan(g, source: .interaction(self), view: view)
    }
}
/// which touches the drag recognizers take: the pointer pan only pointer touches, and only when it may start early
final class _IsimDragGate: NSObject, UIGestureRecognizerDelegate {
    weak var interaction: UIDragInteraction?
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let i = interaction else { return false }
        if g === i.pointerPan { return touch.type == .indirectPointer && i._pointerEarly }
        return true
    }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        guard let i = interaction else { return false }
        return (g === i.press && other === i.pointerPan) || (g === i.pointerPan && other === i.press)
    }
}
@objc(UIDropInteraction) @MainActor open class UIDropInteraction: NSObject, UIInteraction {
    public private(set) weak var delegate: UIDropInteractionDelegate?
    open private(set) weak var view: UIView?
    open var allowsSimultaneousDropSessions = false
    public init(delegate: UIDropInteractionDelegate) { self.delegate = delegate }
    open func willMove(to view: UIView?) {}
    open func didMove(to view: UIView?) { self.view = view }
}

// MARK: - table and collection views
@objc public enum UITableViewDropIntent: Int, Sendable { case unspecified, insertAtDestinationIndexPath, insertIntoDestinationIndexPath, automatic }
@objc(UITableViewDropProposal) open class UITableViewDropProposal: UIDropProposal {
    public let intent: UITableViewDropIntent
    public init(operation: UIDropOperation, intent: UITableViewDropIntent = .unspecified) { self.intent = intent; super.init(operation: operation) }
}
@objc public enum UICollectionViewDropIntent: Int, Sendable { case unspecified, insertAtDestinationIndexPath, insertIntoDestinationIndexPath }
@objc(UICollectionViewDropProposal) open class UICollectionViewDropProposal: UIDropProposal {
    public let intent: UICollectionViewDropIntent
    public init(operation: UIDropOperation, intent: UICollectionViewDropIntent = .unspecified) { self.intent = intent; super.init(operation: operation) }
}
public protocol UITableViewDropItem { var dragItem: UIDragItem { get }; var sourceIndexPath: IndexPath? { get }; var previewSize: CGSize { get } }
public protocol UICollectionViewDropItem { var dragItem: UIDragItem { get }; var sourceIndexPath: IndexPath? { get }; var previewSize: CGSize { get } }
struct _IsimListDropItem: UITableViewDropItem, UICollectionViewDropItem { let dragItem: UIDragItem; let sourceIndexPath: IndexPath?; let previewSize: CGSize }
public protocol UITableViewDropCoordinator {
    var items: [UITableViewDropItem] { get }
    var destinationIndexPath: IndexPath? { get }
    var proposal: UITableViewDropProposal { get }
    var session: UIDropSession { get }
    @discardableResult func drop(_ dragItem: UIDragItem, toRowAt indexPath: IndexPath) -> UIDragAnimating
}
public protocol UICollectionViewDropCoordinator {
    var items: [UICollectionViewDropItem] { get }
    var destinationIndexPath: IndexPath? { get }
    var proposal: UICollectionViewDropProposal { get }
    var session: UIDropSession { get }
    @discardableResult func drop(_ dragItem: UIDragItem, toItemAt indexPath: IndexPath) -> UIDragAnimating
}
final class _IsimTableDropCoordinator: UITableViewDropCoordinator {
    let listItems: [_IsimListDropItem]
    var items: [UITableViewDropItem] { listItems }
    var collectionItems: [UICollectionViewDropItem] { listItems }
    let destinationIndexPath: IndexPath?
    let tableProposal: UITableViewDropProposal
    let collectionProposal: UICollectionViewDropProposal
    let session: UIDropSession
    weak var tableView: UITableView?
    weak var collectionView: UICollectionView?
    init(items: [_IsimListDropItem], destination: IndexPath?, operation: UIDropOperation, session: UIDropSession) {
        listItems = items; destinationIndexPath = destination; self.session = session
        tableProposal = UITableViewDropProposal(operation: operation, intent: .insertAtDestinationIndexPath)
        collectionProposal = UICollectionViewDropProposal(operation: operation, intent: .insertAtDestinationIndexPath)
    }
    var proposal: UITableViewDropProposal { tableProposal }
    func drop(_ dragItem: UIDragItem, toRowAt indexPath: IndexPath) -> UIDragAnimating { _IsimDragAnimator() }
}
public protocol UITableViewDragDelegate: AnyObject {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem]
    func tableView(_ tableView: UITableView, dragSessionWillBegin session: UIDragSession)
    func tableView(_ tableView: UITableView, dragSessionDidEnd session: UIDragSession)
}
extension UITableViewDragDelegate {
    public func tableView(_ tableView: UITableView, dragSessionWillBegin session: UIDragSession) {}
    public func tableView(_ tableView: UITableView, dragSessionDidEnd session: UIDragSession) {}
}
public protocol UITableViewDropDelegate: AnyObject {
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator)
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal
}
extension UITableViewDropDelegate {
    public func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool { true }
    public func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        UITableViewDropProposal(operation: session.localDragSession != nil ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
}
public protocol UICollectionViewDragDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem]
}
public protocol UICollectionViewDropDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator)
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal
}
extension UICollectionViewDropDelegate {
    public func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool { true }
    public func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        UICollectionViewDropProposal(operation: session.localDragSession != nil ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
}

nonisolated(unsafe) private var kDragDelegate: UInt8 = 0, kDropDelegate: UInt8 = 0, kDragEnabled: UInt8 = 0, kListPress: UInt8 = 0
final class _WeakBox: NSObject { weak var value: AnyObject?; init(_ v: AnyObject?) { value = v } }
@MainActor final class _IsimListDragGesture: NSObject {
    @objc func pressed(_ g: UILongPressGestureRecognizer) {
        guard let v = g.view else { return }
        _IsimDragController.handle(g, source: .list(v), view: v)
    }
}
extension UIScrollView {
    func _isimInstallListDrag() {
        if objc_getAssociatedObject(self, &kListPress) != nil { return }
        let handler = _IsimListDragGesture()
        let p = UILongPressGestureRecognizer(target: handler, action: #selector(_IsimListDragGesture.pressed(_:)))
        p.minimumPressDuration = 0.5
        addGestureRecognizer(p)
        objc_setAssociatedObject(self, &kListPress, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
extension UITableView {
    public var dragDelegate: UITableViewDragDelegate? {
        get { (objc_getAssociatedObject(self, &kDragDelegate) as? _WeakBox)?.value as? UITableViewDragDelegate }
        set { objc_setAssociatedObject(self, &kDragDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC); if newValue != nil { _isimInstallListDrag() } }
    }
    public var dropDelegate: UITableViewDropDelegate? {
        get { (objc_getAssociatedObject(self, &kDropDelegate) as? _WeakBox)?.value as? UITableViewDropDelegate }
        set { objc_setAssociatedObject(self, &kDropDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var dragInteractionEnabled: Bool {
        get { (objc_getAssociatedObject(self, &kDragEnabled) as? Bool) ?? true }
        set { objc_setAssociatedObject(self, &kDragEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var hasActiveDrag: Bool { _IsimDragController.current?.sourceList === self }
}
extension UICollectionView {
    public var dragDelegate: UICollectionViewDragDelegate? {
        get { (objc_getAssociatedObject(self, &kDragDelegate) as? _WeakBox)?.value as? UICollectionViewDragDelegate }
        set { objc_setAssociatedObject(self, &kDragDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC); if newValue != nil { _isimInstallListDrag() } }
    }
    public var dropDelegate: UICollectionViewDropDelegate? {
        get { (objc_getAssociatedObject(self, &kDropDelegate) as? _WeakBox)?.value as? UICollectionViewDropDelegate }
        set { objc_setAssociatedObject(self, &kDropDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var dragInteractionEnabled: Bool {
        get { (objc_getAssociatedObject(self, &kDragEnabled) as? Bool) ?? true }
        set { objc_setAssociatedObject(self, &kDragEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var hasActiveDrag: Bool { _IsimDragController.current?.sourceList === self }
}

// MARK: - the drag in progress
final class _IsimDragWindow: UIWindow {
    @objc func _isim_isSystemWindow() -> Bool { true }
    override var canBecomeKeyWindow: Bool { false }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}
enum _IsimDropTarget {
    case interaction(UIDropInteraction)
    case list(UIScrollView)
    case text(UIView)                 // a text view or field (UITextDroppable)
    var view: UIView? { switch self { case .interaction(let i): return i.view; case .list(let v): return v; case .text(let v): return v } }
    var identity: AnyObject? { switch self { case .interaction(let i): return i; case .list(let v): return v; case .text(let v): return v } }
}
final class _IsimDragController {
    enum Source { case interaction(UIDragInteraction), list(UIView) }
    nonisolated(unsafe) static var current: _IsimDragController?
    let session: _IsimDragSession
    let source: Source
    let sourceIndexPath: IndexPath?
    var sourceList: UIView? { if case .list(let v) = source { return v }; return nil }
    var window: _IsimDragWindow?
    var preview: UIView?
    var grabOffset = CGPoint.zero
    var target: _IsimDropTarget?
    var operation: UIDropOperation = .cancel
    var listDestination: IndexPath?
    var textProposal: UITextDropProposal?
    var textTarget: UIView? { if case .text(let v) = target { return v }; return nil }
    weak var gapList: UIScrollView?                 // the list whose cells make room for the drop
    var gapDestination: IndexPath?
    weak var pinnedScroll: UIScrollView?
    var pinnedOffset = CGPoint.zero
    init(session: _IsimDragSession, source: Source, sourceIndexPath: IndexPath?) { self.session = session; self.source = source; self.sourceIndexPath = sourceIndexPath }

    @MainActor static func handle(_ g: UILongPressGestureRecognizer, source: _IsimSourceKind, view: UIView) {
        guard let w = view.window else { return }
        let p = g.location(in: w)
        switch g.state {
        case .began: begin(at: p, in: w, source: source, view: view)
        case .changed: current?.move(to: p)
        case .ended: current?.end(at: p, cancelled: false)
        case .cancelled, .failed: current?.end(at: p, cancelled: true)
        default: break
        }
    }
    @MainActor static func handlePan(_ g: UIPanGestureRecognizer, source: _IsimSourceKind, view: UIView) {
        guard let w = view.window else { return }
        let p = g.location(in: w)
        switch g.state {
        case .began: if current == nil { begin(at: p, in: w, source: source, view: view) }
        case .changed: current?.move(to: p)
        case .ended: current?.end(at: p, cancelled: false)
        case .cancelled, .failed: current?.end(at: p, cancelled: true)
        default: break
        }
    }
    @MainActor static func begin(at p: CGPoint, in w: UIWindow, source: _IsimSourceKind, view: UIView) {
        var items: [UIDragItem] = []
        var liftView: UIView = view
        var targeted: UITargetedDragPreview?
        var src: Source
        var ip: IndexPath?
        let session = _IsimDragSession(items: [])
        session.window = w; session.windowPoint = p
        switch source {
        case .interaction(let i):
            src = .interaction(i)
            items = i.delegate?.dragInteraction(i, itemsForBeginning: session) ?? []
            if let first = items.first, let tp = i.delegate?.dragInteraction(i, previewForLifting: first, session: session) { liftView = tp.view; targeted = tp }
        case .list(let lv):
            src = .list(lv)
            if let tv = lv as? UITableView, tv.dragInteractionEnabled, let d = tv.dragDelegate, let idx = tv.indexPathForRow(at: tv.convert(p, from: w)) {
                ip = idx; items = d.tableView(tv, itemsForBeginning: session, at: idx)
                if let c = tv.cellForRow(at: idx) { liftView = c }
                if !items.isEmpty { d.tableView(tv, dragSessionWillBegin: session) }
            } else if let cv = lv as? UICollectionView, cv.dragInteractionEnabled, let d = cv.dragDelegate, let idx = cv.indexPathForItem(at: cv.convert(p, from: w)) {
                ip = idx; items = d.collectionView(cv, itemsForBeginning: session, at: idx)
                if let c = cv.cellForItem(at: idx) { liftView = c }
            }
        }
        guard !items.isEmpty else { return }
        session.items = items
        let c = _IsimDragController(session: session, source: src, sourceIndexPath: ip)
        current = c
        // like UIKit, a lift stops the enclosing scroll view from scrolling with the finger
        var sv: UIView? = view
        while let v = sv, !(v is UIScrollView) { sv = v.superview }
        if let scroll = sv as? UIScrollView { c.pinnedScroll = scroll; c.pinnedOffset = scroll.contentOffset }
        if case .interaction(let i) = src {
            let animator = _IsimDragAnimator()
            i.delegate?.dragInteraction(i, willAnimateLiftWith: animator, session: session)
            animator.run()
            i.delegate?.dragInteraction(i, sessionWillBegin: session)
        }
        // the lifted preview: a snapshot above everything, slightly larger, with a shadow
        let dw = _IsimDragWindow(frame: UIScreen.main.bounds)
        dw.windowLevel = UIWindow.Level(rawValue: 14_000_000)
        dw.backgroundColor = .clear
        dw.isUserInteractionEnabled = false
        var frame = liftView.convert(liftView.bounds, to: w)
        let snap: UIView
        if liftView.window == nil, let tp = targeted {
            // a preview view that is not on screen (a custom drag preview): itself, centred on its target
            let size = tp.view.bounds.size == .zero ? tp.view.sizeThatFits(w.bounds.size) : tp.view.bounds.size
            let c = tp.target.container.convert(tp.target.center, to: w)
            frame = CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height)
            snap = tp.view
        } else {
            snap = liftView.snapshotView(afterScreenUpdates: false) ?? UIView()
        }
        snap.frame = frame
        snap.layer.shadowColor = UIColor.black.cgColor; snap.layer.shadowOpacity = 0.25; snap.layer.shadowRadius = 10; snap.layer.shadowOffset = CGSize(width: 0, height: 6)
        if snap.accessibilityIdentifier == nil { snap.accessibilityIdentifier = "isim-drag-preview" }
        dw.addSubview(snap)
        dw.isHidden = false
        UIView.animate(withDuration: 0.15) { snap.transform = CGAffineTransform(scaleX: 1.05, y: 1.05) }
        c.window = dw; c.preview = snap
        c.grabOffset = CGPoint(x: p.x - frame.midX, y: p.y - frame.midY)
        print("isim: drag began with \(items.count) item(s)")
        c.move(to: p)
    }
    @MainActor func move(to p: CGPoint) {
        if let s = pinnedScroll, s.contentOffset != pinnedOffset { s.contentOffset = pinnedOffset }
        session.windowPoint = p
        _IsimSpringLoading.update(at: p, in: session.window)
        preview?.center = CGPoint(x: p.x - grabOffset.x, y: p.y - grabOffset.y)
        if case .interaction(let i) = source { i.delegate?.dragInteraction(i, sessionDidMove: session) }
        let t = findTarget(at: p)
        if t?.identity !== target?.identity {
            if let old = target, case .interaction(let i) = old { i.delegate?.dropInteraction(i, sessionDidExit: session) }
            if let old = target, case .text(let v) = old, let tv = v as? (UIView & UITextDroppable) { tv.textDropDelegate?.textDroppableView(tv, dropSessionDidExit: session) }
            target = t
            if let t, case .interaction(let i) = t { i.delegate?.dropInteraction(i, sessionDidEnter: session) }
            if let t, case .text(let v) = t, let tv = v as? (UIView & UITextDroppable) { tv.textDropDelegate?.textDroppableView(tv, dropSessionDidEnter: session) }
        }
        operation = .cancel; listDestination = nil
        guard let t else { return }
        switch t {
        case .interaction(let i):
            operation = i.delegate?.dropInteraction(i, sessionDidUpdate: session).operation ?? .cancel
        case .text(let v):
            if let tv = v as? (UIView & UITextDroppable) { (operation, textProposal) = _IsimTextDrop.update(tv, session: session) }
        case .list(let lv):
            let lp = lv.convert(p, from: session.window)
            if let tv = lv as? UITableView, let d = tv.dropDelegate {
                let dest = tv.indexPathForRow(at: lp) ?? IndexPath(row: tv.numberOfRows(inSection: max(0, tv.numberOfSections - 1)), section: max(0, tv.numberOfSections - 1))
                listDestination = dest
                operation = d.tableView(tv, dropSessionDidUpdate: session, withDestinationIndexPath: dest).operation
            } else if let cv = lv as? UICollectionView, let d = cv.dropDelegate {
                let s = max(0, cv.numberOfSections - 1)
                let dest = cv.indexPathForItem(at: lp) ?? IndexPath(item: cv.numberOfItems(inSection: s), section: s)
                listDestination = dest
                operation = d.collectionView(cv, dropSessionDidUpdate: session, withDestinationIndexPath: dest).operation
            }
        }
        let gapTarget: UIScrollView? = { if case .list(let lv) = t, operation == .move || operation == .copy { return lv }; return nil }()
        if gapTarget !== gapList || listDestination != gapDestination {
            if let old = gapList, old !== gapTarget { applyGap(old, dest: nil) }
            gapList = gapTarget; gapDestination = listDestination
            if let lv = gapTarget { applyGap(lv, dest: listDestination) }
        }
    }
    /// the insertion gap: the cells move to where they will be once the item lands at dest (a local move takes the
    /// source's place out; a drop from elsewhere pushes the later cells on); dest nil puts them back
    @MainActor func applyGap(_ lv: UIScrollView, dest: IndexPath?) {
        let local = sourceList === lv ? sourceIndexPath : nil
        func target(_ ip: IndexPath) -> IndexPath {
            guard let dest, ip.section == dest.section else { return ip }
            var t = ip
            if let s = local, s.section == dest.section {
                if s.item < dest.item, ip.item > s.item, ip.item <= dest.item { t.item -= 1 }
                else if s.item > dest.item, ip.item >= dest.item, ip.item < s.item { t.item += 1 }
            } else if ip.item >= dest.item { t.item += 1 }
            return t
        }
        var moves: [(UIView, CGAffineTransform, CGFloat)] = []
        if let cv = lv as? UICollectionView {
            for cell in cv.visibleCells {
                guard let ip = cv.indexPath(for: cell) else { continue }
                let t = target(ip)
                var shift = CGAffineTransform.identity
                if t != ip, t.item < cv.numberOfItems(inSection: t.section), let a = cv.layoutAttributesForItem(at: t) {
                    shift = CGAffineTransform(translationX: a.center.x - cell.center.x, y: a.center.y - cell.center.y)
                } else if t != ip, let a = cv.layoutAttributesForItem(at: ip), let prev = ip.item > 0 ? cv.layoutAttributesForItem(at: IndexPath(item: ip.item - 1, section: ip.section)) : nil {
                    shift = CGAffineTransform(translationX: a.center.x - prev.center.x, y: a.center.y - prev.center.y)   // past the end: one more step
                }
                moves.append((cell, shift, dest != nil && ip == local ? 0.3 : 1))
            }
        } else if let tv = lv as? UITableView {
            for cell in tv.visibleCells {
                guard let ip = tv.indexPath(for: cell) else { continue }
                let t = target(ip)
                let dy = t == ip ? 0 : (t.row > ip.row ? 1 : -1) * tv.rectForRow(at: ip).height
                moves.append((cell, CGAffineTransform(translationX: 0, y: dy), dest != nil && ip == local ? 0.3 : 1))
            }
        }
        UIView.animate(withDuration: 0.2) { for (v, t, a) in moves { v.transform = t; v.alpha = a } }
        if let dest { print("isim: drop gap at \(dest.section)/\(dest.item) (\(moves.filter { $0.1 != .identity }.count) cells moved)") }
    }
    @MainActor func findTarget(at p: CGPoint) -> _IsimDropTarget? {
        guard let w = session.window else { return nil }
        var found: _IsimDropTarget?
        func visit(_ v: UIView) {
            if v.isHidden || v.alpha < 0.01 { return }
            let lp = v.convert(p, from: w)
            guard v.bounds.contains(lp) else { return }
            for x in v.interactions { if let d = x as? UIDropInteraction, d.delegate?.dropInteraction(d, canHandle: session) ?? false { found = .interaction(d) } }
            if let tv = v as? UITableView, let d = tv.dropDelegate, d.tableView(tv, canHandle: session) { found = .list(tv) }
            if let cv = v as? UICollectionView, let d = cv.dropDelegate, d.collectionView(cv, canHandle: session) { found = .list(cv) }
            if _IsimTextDrop.accepts(v, session: session) { found = .text(v) }
            for s in v.subviews { visit(s) }
        }
        visit(w)
        return found
    }
    @MainActor func end(at p: CGPoint, cancelled: Bool) {
        if !cancelled { move(to: p) }
        _IsimSpringLoading.cancel()
        if let g = gapList {                                  // the cells go back before the data source changes
            UIView.performWithoutAnimation { for v in ((g as? UICollectionView)?.visibleCells ?? []) as [UIView] + ((g as? UITableView)?.visibleCells ?? []) { v.transform = .identity; v.alpha = 1 } }
            gapList = nil; gapDestination = nil
        }
        let op: UIDropOperation = cancelled ? .cancel : operation
        let dropping = op == .copy || op == .move
        if case .interaction(let i) = source { i.delegate?.dragInteraction(i, session: session, willEndWith: op) }
        if dropping, let t = target {
            switch t {
            case .interaction(let i):
                print("isim: drop on \(type(of: i.view!)) (\(op == .move ? "move" : "copy"))")
                i.delegate?.dropInteraction(i, performDrop: session)
                i.delegate?.dropInteraction(i, concludeDrop: session)
            case .text(let v):
                if let tv = v as? (UIView & UITextDroppable) { _IsimTextDrop.perform(tv, session: session, proposal: textProposal) }
            case .list(let lv):
                let local = sourceList === lv
                let items = session.items.map { _IsimListDropItem(dragItem: $0, sourceIndexPath: local ? sourceIndexPath : nil, previewSize: preview?.bounds.size ?? .zero) }
                let coordinator = _IsimTableDropCoordinator(items: items, destination: listDestination, operation: op, session: session)
                coordinator.tableView = lv as? UITableView; coordinator.collectionView = lv as? UICollectionView
                print("isim: drop on \(type(of: lv)) at \(listDestination.map { "\($0.section)/\($0.item)" } ?? "end")")
                if let tv = lv as? UITableView, let d = tv.dropDelegate {
                    if local, op == .move, let s = sourceIndexPath, var dest = listDestination, let ds = tv.dataSource, ds.responds(to: #selector(UITableViewDataSource.tableView(_:moveRowAt:to:))) {
                        dest.row = min(dest.row, max(0, tv.numberOfRows(inSection: dest.section) - 1))
                        ds.tableView?(tv, moveRowAt: s, to: dest)
                        tv.reloadData()
                    } else { d.tableView(tv, performDropWith: coordinator) }
                } else if let cv = lv as? UICollectionView, let d = cv.dropDelegate {
                    if local, op == .move, let s = sourceIndexPath, var dest = listDestination, let ds = cv.dataSource, ds.responds(to: #selector(UICollectionViewDataSource.collectionView(_:moveItemAt:to:))) {
                        dest.item = min(dest.item, max(0, cv.numberOfItems(inSection: dest.section) - 1))
                        ds.collectionView?(cv, moveItemAt: s, to: dest)
                        cv.reloadData()
                    } else { d.collectionView(cv, performDropWith: _IsimCollectionCoordinator(coordinator)) }
                }
            }
        } else {
            if let t = target, case .interaction(let i) = t { i.delegate?.dropInteraction(i, sessionDidExit: session) }
            print("isim: drag cancelled")
        }
        if let t = target, case .interaction(let i) = t { i.delegate?.dropInteraction(i, sessionDidEnd: session) }
        if let t = target, case .text(let v) = t, let tv = v as? (UIView & UITextDroppable) { tv.textDropDelegate?.textDroppableView(tv, dropSessionDidEnd: session) }
        if case .interaction(let i) = source { i.delegate?.dragInteraction(i, session: session, didEndWith: op) }
        if let tv = sourceList as? UITableView { tv.dragDelegate?.tableView(tv, dragSessionDidEnd: session) }
        let w = window
        UIView.animate(withDuration: 0.2, animations: { self.preview?.alpha = 0 }, completion: { _ in w?.isHidden = true })
        _IsimDragController.current = nil
    }
}
enum _IsimSourceKind { case interaction(UIDragInteraction), list(UIView) }
/// a UICollectionViewDropCoordinator view of the shared coordinator
struct _IsimCollectionCoordinator: UICollectionViewDropCoordinator {
    let base: _IsimTableDropCoordinator
    init(_ b: _IsimTableDropCoordinator) { base = b }
    var items: [UICollectionViewDropItem] { base.collectionItems }
    var destinationIndexPath: IndexPath? { base.destinationIndexPath }
    var proposal: UICollectionViewDropProposal { base.collectionProposal }
    var session: UIDropSession { base.session }
    func drop(_ dragItem: UIDragItem, toItemAt indexPath: IndexPath) -> UIDragAnimating { _IsimDragAnimator() }
}

// MARK: - preview targets, link previews, drop preview updates (part 11 of #9)
/// where a dropped item's preview lands (a container and a point in it, as UIPreviewTarget)
@MainActor open class UIDragPreviewTarget: UIPreviewTarget {}
extension UIDragPreview {
    /// a preview of a link: its title (else the URL's host or path) in a rounded platter
    public convenience init(for url: URL, title: String?) {
        let label = UILabel()
        label.text = title ?? url.host ?? url.absoluteString
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        let platter = UIView(frame: CGRect(x: 0, y: 0, width: min(280, label.intrinsicContentSize.width + 24), height: 36))
        platter.backgroundColor = .secondarySystemBackground
        platter.layer.cornerRadius = 10
        label.frame = platter.bounds.insetBy(dx: 12, dy: 0)
        platter.addSubview(label)
        platter.accessibilityIdentifier = "isim-drag-link-preview"
        self.init(view: platter)
    }
    public convenience init(for url: URL) { self.init(for: url, title: nil) }
}
extension UITargetedDragPreview {
    public convenience init(for url: URL, title: String?, target: UIDragPreviewTarget) {
        let p = UIDragPreview(for: url, title: title)
        self.init(view: p.view, parameters: p.parameters, target: target)
    }
    public convenience init(for url: URL, target: UIDragPreviewTarget) { self.init(for: url, title: nil, target: target) }
}
extension UIDragItem {
    /// asks for the item's drop preview again (isim draws no drop previews: logged)
    public func setNeedsDropPreviewUpdate() { print("isim: drop preview update requested") }
}

// MARK: - drop placeholders in table and collection views
/// a row that shows while a dropped item's data loads (configured by cellUpdateHandler)
@MainActor open class UITableViewPlaceholder: NSObject {
    public let insertionIndexPath: IndexPath
    public let reuseIdentifier: String
    public let rowHeight: CGFloat
    open var cellUpdateHandler: ((UITableViewCell) -> Void)?
    public init(insertionIndexPath: IndexPath, reuseIdentifier: String, rowHeight: CGFloat) {
        self.insertionIndexPath = insertionIndexPath; self.reuseIdentifier = reuseIdentifier; self.rowHeight = rowHeight
    }
}
@MainActor open class UITableViewDropPlaceholder: UITableViewPlaceholder {
    open var previewParametersProvider: ((UITableViewCell) -> UIDragPreviewParameters?)?
}
@MainActor open class UICollectionViewPlaceholder: NSObject {
    public let insertionIndexPath: IndexPath
    public let reuseIdentifier: String
    open var cellUpdateHandler: ((UICollectionViewCell) -> Void)?
    public init(insertionIndexPath: IndexPath, reuseIdentifier: String) { self.insertionIndexPath = insertionIndexPath; self.reuseIdentifier = reuseIdentifier }
}
@MainActor open class UICollectionViewDropPlaceholder: UICollectionViewPlaceholder {
    open var previewParametersProvider: ((UICollectionViewCell) -> UIDragPreviewParameters?)?
}
@MainActor public protocol UITableViewDropPlaceholderContext: UIDragAnimating {
    var dragItem: UIDragItem { get }
    func commitInsertion(dataSourceUpdates: (IndexPath) -> Void) -> Bool
    func deletePlaceholder() -> Bool
}
@MainActor public protocol UICollectionViewDropPlaceholderContext: UIDragAnimating {
    var dragItem: UIDragItem { get }
    func commitInsertion(dataSourceUpdates: (IndexPath) -> Void) -> Bool
    func deletePlaceholder() -> Bool
    func setNeedsCellUpdate()
}
/// adapted: the placeholder is a cell laid over the list at its index path, the later cells moved aside, until the
/// insertion is committed (the data source updates, the list reloads) or the placeholder deleted
@MainActor final class _IsimPlaceholderContext: NSObject, @preconcurrency UITableViewDropPlaceholderContext, @preconcurrency UICollectionViewDropPlaceholderContext {
    let dragItem: UIDragItem
    weak var list: UIScrollView?
    let indexPath: IndexPath
    var cell: UIView?
    var moved: [UIView] = []
    var update: (() -> Void)?
    var done = false
    let animator = _IsimDragAnimator()
    init(item: UIDragItem, list: UIScrollView, indexPath: IndexPath) { dragItem = item; self.list = list; self.indexPath = indexPath }
    func addAnimations(_ a: @escaping () -> Void) { animator.addAnimations(a) }
    func addCompletion(_ c: @escaping (UIViewAnimatingPosition) -> Void) { animator.addCompletion(c) }
    func show(cell c: UIView, frame: CGRect, shift: CGPoint, later: [UIView]) {
        cell = c; c.frame = frame; c.accessibilityIdentifier = c.accessibilityIdentifier ?? "isim-drop-placeholder"
        list?.addSubview(c)
        moved = later
        for v in later { v.transform = CGAffineTransform(translationX: shift.x, y: shift.y) }
        update?()
        print("isim: drop placeholder at \(indexPath.section)/\(indexPath.item)")
        animator.run()
    }
    private func remove() { cell?.removeFromSuperview(); cell = nil; for v in moved { v.transform = .identity }; moved = [] }
    func commitInsertion(dataSourceUpdates: (IndexPath) -> Void) -> Bool {
        guard !done else { return false }
        done = true; remove()
        dataSourceUpdates(indexPath)
        (list as? UITableView)?.reloadData(); (list as? UICollectionView)?.reloadData()
        print("isim: drop placeholder committed at \(indexPath.section)/\(indexPath.item)")
        return true
    }
    func deletePlaceholder() -> Bool {
        guard !done else { return false }
        done = true; remove(); print("isim: drop placeholder deleted"); return true
    }
    func setNeedsCellUpdate() { update?() }
}
extension UITableViewDropCoordinator {
    /// drops the item into a row (onto its content); isim animates nothing
    @discardableResult public func drop(_ dragItem: UIDragItem, intoRowAt indexPath: IndexPath, rect: CGRect) -> UIDragAnimating { _IsimDragAnimator() }
    @discardableResult public func drop(_ dragItem: UIDragItem, to target: UIDragPreviewTarget) -> UIDragAnimating { _IsimDragAnimator() }
    /// shows a placeholder row where the item will go
    @MainActor @discardableResult public func drop(_ dragItem: UIDragItem, to placeholder: UITableViewDropPlaceholder) -> UITableViewDropPlaceholderContext {
        let tv = (self as? _IsimTableDropCoordinator)?.tableView
        let ctx = _IsimPlaceholderContext(item: dragItem, list: tv ?? UIScrollView(), indexPath: placeholder.insertionIndexPath)
        guard let tv else { return ctx }
        let cell = tv.dequeueReusableCell(withIdentifier: placeholder.reuseIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: placeholder.reuseIdentifier)
        ctx.update = { [weak cell] in if let c = cell { placeholder.cellUpdateHandler?(c) } }
        let ip = placeholder.insertionIndexPath
        let rows = tv.numberOfRows(inSection: ip.section)
        let y = ip.row < rows ? tv.rectForRow(at: ip).minY : (rows > 0 ? tv.rectForRow(at: IndexPath(row: rows - 1, section: ip.section)).maxY : 0)
        let later = tv.visibleCells.filter { c in (tv.indexPath(for: c).map { $0.section == ip.section && $0.row >= ip.row } ?? false) }
        ctx.show(cell: cell, frame: CGRect(x: 0, y: y, width: tv.bounds.width, height: placeholder.rowHeight), shift: CGPoint(x: 0, y: placeholder.rowHeight), later: later)
        return ctx
    }
}
extension UICollectionViewDropCoordinator {
    @discardableResult public func drop(_ dragItem: UIDragItem, intoItemAt indexPath: IndexPath, rect: CGRect) -> UIDragAnimating { _IsimDragAnimator() }
    @discardableResult public func drop(_ dragItem: UIDragItem, to target: UIDragPreviewTarget) -> UIDragAnimating { _IsimDragAnimator() }
    @MainActor @discardableResult public func drop(_ dragItem: UIDragItem, to placeholder: UICollectionViewDropPlaceholder) -> UICollectionViewDropPlaceholderContext {
        let cv = (self as? _IsimCollectionCoordinator)?.base.collectionView
        let ctx = _IsimPlaceholderContext(item: dragItem, list: cv ?? UIScrollView(), indexPath: placeholder.insertionIndexPath)
        guard let cv else { return ctx }
        let ip = placeholder.insertionIndexPath
        let n = cv.numberOfItems(inSection: ip.section)
        let at = ip.item < n ? cv.layoutAttributesForItem(at: ip) : (n > 0 ? cv.layoutAttributesForItem(at: IndexPath(item: n - 1, section: ip.section)) : nil)
        var frame = at?.frame ?? CGRect(x: 0, y: 0, width: 50, height: 50)
        if ip.item >= n, n > 0 { frame.origin.x += frame.width + 10 }
        let cell = UICollectionViewCell(frame: frame)
        ctx.update = { [weak cell] in if let c = cell { placeholder.cellUpdateHandler?(c) } }
        let later = cv.visibleCells.filter { c in (cv.indexPath(for: c).map { $0.section == ip.section && $0.item >= ip.item } ?? false) }
        ctx.show(cell: cell, frame: frame, shift: CGPoint(x: frame.width + 10, y: 0), later: later)
        return ctx
    }
}
