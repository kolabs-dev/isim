// isim UIKit overlay: drag and drop within an app (self-authored).
// UIDragInteraction lifts after a long press (0.5 s; script `longdrag X1 Y1 X2 Y2 HOLD SECS`), the lifted preview
// follows the finger in a window above the app, and UIDropInteractions under the finger are asked whether they
// can handle the session, get enter/update/exit, and perform the drop (items carry NSItemProviders). UITableView and
// UICollectionView take dragDelegate/dropDelegate (reordering through the data source's move, insertion through
// performDrop). Drags don't cross apps on isim.
@_exported import UniformTypeIdentifiers

// MARK: - items, previews, proposals
open class UIDragItem: NSObject {
    public let itemProvider: NSItemProvider
    open var localObject: Any?
    open var previewProvider: (() -> UIDragPreview?)?
    public init(itemProvider: NSItemProvider) { self.itemProvider = itemProvider }
}
open class UIDragPreviewParameters: UIPreviewParameters {}
open class UIDragPreview: NSObject {
    public let view: UIView
    public let parameters: UIDragPreviewParameters
    public init(view: UIView, parameters: UIDragPreviewParameters = UIDragPreviewParameters()) { self.view = view; self.parameters = parameters }
}
open class UITargetedDragPreview: UITargetedPreview {}

@objc public enum UIDropOperation: Int, Sendable { case cancel = 0, forbidden = 1, copy = 2, move = 3 }
open class UIDropProposal: NSObject {
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
    var items: [UIDragItem]
    var localContext: Any?
    var progressIndicatorStyle: UIDropSessionProgressIndicatorStyle = .default
    let progress = Progress(totalUnitCount: 1)
    var windowPoint = CGPoint.zero
    weak var window: UIWindow?
    init(items: [UIDragItem]) { self.items = items }
    func location(in view: UIView) -> CGPoint { view.convert(windowPoint, from: window ?? view.window) }
    var allowsMoveOperation: Bool { true }
    var isRestrictedToDraggingApplication: Bool { true }
    var localDragSession: UIDragSession? { self }
    func hasItemsConforming(toTypeIdentifiers ids: [String]) -> Bool { items.contains { i in ids.contains { i.itemProvider.hasItemConformingToTypeIdentifier($0) } } }
    func canLoadObjects(ofClass c: NSItemProviderReading.Type) -> Bool { items.contains { $0.itemProvider.canLoadObject(ofClass: c) } }
    func loadObjects(ofClass c: NSItemProviderReading.Type, completion: @escaping ([NSItemProviderReading]) -> Void) -> Progress {
        let group = DispatchGroup(), lock = NSLock()
        var out: [(Int, NSItemProviderReading)] = []
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

// strings and URLs travel as items (NSItemProvider(object: "text" as NSString))
extension NSString: NSItemProviderReading, NSItemProviderWriting {
    public static var readableTypeIdentifiersForItemProvider: [String] { [UTType.utf8PlainText.identifier, UTType.plainText.identifier, UTType.text.identifier] }
    public static var writableTypeIdentifiersForItemProvider: [String] { [UTType.utf8PlainText.identifier] }
    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        NSString(string: String(decoding: data, as: UTF8.self)) as! Self
    }
    public func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completion: @escaping @Sendable (Data?, Error?) -> Void) -> Progress? {
        completion(Data((self as String).utf8), nil); return nil
    }
}

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
final class _IsimDragAnimator: UIDragAnimating {
    var animations: [() -> Void] = [], completions: [(UIViewAnimatingPosition) -> Void] = []
    func addAnimations(_ a: @escaping () -> Void) { animations.append(a) }
    func addCompletion(_ c: @escaping (UIViewAnimatingPosition) -> Void) { completions.append(c) }
    func run() {
        let a = animations, c = completions
        if a.isEmpty && c.isEmpty { return }
        UIView.animate(withDuration: 0.2, animations: { a.forEach { $0() } }, completion: { _ in c.forEach { $0(.end) } })
    }
}

// MARK: - interactions
@MainActor open class UIDragInteraction: NSObject, UIInteraction {
    public private(set) weak var delegate: UIDragInteractionDelegate?
    open private(set) weak var view: UIView?
    open var isEnabled = true
    open var allowsSimultaneousRecognitionDuringLift = false
    open class var isEnabledByDefault: Bool { true }
    var press: UILongPressGestureRecognizer?
    public init(delegate: UIDragInteractionDelegate) { self.delegate = delegate }
    open func willMove(to view: UIView?) { if let p = press { self.view?.removeGestureRecognizer(p) } }
    open func didMove(to view: UIView?) {
        self.view = view
        guard let view else { return }
        let p = UILongPressGestureRecognizer(target: self, action: #selector(_pressed(_:)))
        p.minimumPressDuration = 0.5
        view.addGestureRecognizer(p)
        press = p
    }
    @objc func _pressed(_ g: UILongPressGestureRecognizer) {
        guard isEnabled, let view else { return }
        _IsimDragController.handle(g, source: .interaction(self), view: view)
    }
}
@MainActor open class UIDropInteraction: NSObject, UIInteraction {
    public private(set) weak var delegate: UIDropInteractionDelegate?
    open private(set) weak var view: UIView?
    open var allowsSimultaneousDropSessions = false
    public init(delegate: UIDropInteractionDelegate) { self.delegate = delegate }
    open func willMove(to view: UIView?) {}
    open func didMove(to view: UIView?) { self.view = view }
}

// MARK: - table and collection views
@objc public enum UITableViewDropIntent: Int, Sendable { case unspecified, insertAtDestinationIndexPath, insertIntoDestinationIndexPath, automatic }
open class UITableViewDropProposal: UIDropProposal {
    public let intent: UITableViewDropIntent
    public init(operation: UIDropOperation, intent: UITableViewDropIntent = .unspecified) { self.intent = intent; super.init(operation: operation) }
}
@objc public enum UICollectionViewDropIntent: Int, Sendable { case unspecified, insertAtDestinationIndexPath, insertIntoDestinationIndexPath }
open class UICollectionViewDropProposal: UIDropProposal {
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
        objc_setAssociatedObject(self, &kListPress, handler, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
}
extension UITableView {
    public var dragDelegate: UITableViewDragDelegate? {
        get { (objc_getAssociatedObject(self, &kDragDelegate) as? _WeakBox)?.value as? UITableViewDragDelegate }
        set { objc_setAssociatedObject(self, &kDragDelegate, _WeakBox(newValue), objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)); if newValue != nil { _isimInstallListDrag() } }
    }
    public var dropDelegate: UITableViewDropDelegate? {
        get { (objc_getAssociatedObject(self, &kDropDelegate) as? _WeakBox)?.value as? UITableViewDropDelegate }
        set { objc_setAssociatedObject(self, &kDropDelegate, _WeakBox(newValue), objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)) }
    }
    public var dragInteractionEnabled: Bool {
        get { (objc_getAssociatedObject(self, &kDragEnabled) as? Bool) ?? true }
        set { objc_setAssociatedObject(self, &kDragEnabled, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)) }
    }
    public var hasActiveDrag: Bool { _IsimDragController.current?.sourceList === self }
}
extension UICollectionView {
    public var dragDelegate: UICollectionViewDragDelegate? {
        get { (objc_getAssociatedObject(self, &kDragDelegate) as? _WeakBox)?.value as? UICollectionViewDragDelegate }
        set { objc_setAssociatedObject(self, &kDragDelegate, _WeakBox(newValue), objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)); if newValue != nil { _isimInstallListDrag() } }
    }
    public var dropDelegate: UICollectionViewDropDelegate? {
        get { (objc_getAssociatedObject(self, &kDropDelegate) as? _WeakBox)?.value as? UICollectionViewDropDelegate }
        set { objc_setAssociatedObject(self, &kDropDelegate, _WeakBox(newValue), objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)) }
    }
    public var dragInteractionEnabled: Bool {
        get { (objc_getAssociatedObject(self, &kDragEnabled) as? Bool) ?? true }
        set { objc_setAssociatedObject(self, &kDragEnabled, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)) }
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
    var view: UIView? { switch self { case .interaction(let i): return i.view; case .list(let v): return v } }
    var identity: AnyObject? { switch self { case .interaction(let i): return i; case .list(let v): return v } }
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
    @MainActor static func begin(at p: CGPoint, in w: UIWindow, source: _IsimSourceKind, view: UIView) {
        var items: [UIDragItem] = []
        var liftView: UIView = view
        var src: Source
        var ip: IndexPath?
        let session = _IsimDragSession(items: [])
        session.window = w; session.windowPoint = p
        switch source {
        case .interaction(let i):
            src = .interaction(i)
            items = i.delegate?.dragInteraction(i, itemsForBeginning: session) ?? []
            if let first = items.first, let tp = i.delegate?.dragInteraction(i, previewForLifting: first, session: session) { liftView = tp.view }
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
        let frame = liftView.convert(liftView.bounds, to: w)
        let snap = liftView.snapshotView(afterScreenUpdates: false) ?? UIView()
        snap.frame = frame
        snap.layer.shadowColor = UIColor.black.cgColor; snap.layer.shadowOpacity = 0.25; snap.layer.shadowRadius = 10; snap.layer.shadowOffset = CGSize(width: 0, height: 6)
        snap.accessibilityIdentifier = "isim-drag-preview"
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
        preview?.center = CGPoint(x: p.x - grabOffset.x, y: p.y - grabOffset.y)
        if case .interaction(let i) = source { i.delegate?.dragInteraction(i, sessionDidMove: session) }
        let t = findTarget(at: p)
        if t?.identity !== target?.identity {
            if let old = target, case .interaction(let i) = old { i.delegate?.dropInteraction(i, sessionDidExit: session) }
            target = t
            if let t, case .interaction(let i) = t { i.delegate?.dropInteraction(i, sessionDidEnter: session) }
        }
        operation = .cancel; listDestination = nil
        guard let t else { return }
        switch t {
        case .interaction(let i):
            operation = i.delegate?.dropInteraction(i, sessionDidUpdate: session).operation ?? .cancel
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
            for s in v.subviews { visit(s) }
        }
        visit(w)
        return found
    }
    @MainActor func end(at p: CGPoint, cancelled: Bool) {
        if !cancelled { move(to: p) }
        let op: UIDropOperation = cancelled ? .cancel : operation
        let dropping = op == .copy || op == .move
        if case .interaction(let i) = source { i.delegate?.dragInteraction(i, session: session, willEndWith: op) }
        if dropping, let t = target {
            switch t {
            case .interaction(let i):
                print("isim: drop on \(type(of: i.view!)) (\(op == .move ? "move" : "copy"))")
                i.delegate?.dropInteraction(i, performDrop: session)
                i.delegate?.dropInteraction(i, concludeDrop: session)
            case .list(let lv):
                let local = sourceList === lv
                let items = session.items.map { _IsimListDropItem(dragItem: $0, sourceIndexPath: local ? sourceIndexPath : nil, previewSize: preview?.bounds.size ?? .zero) }
                let coordinator = _IsimTableDropCoordinator(items: items, destination: listDestination, operation: op, session: session)
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
