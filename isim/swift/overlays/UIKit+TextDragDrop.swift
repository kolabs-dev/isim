// isim UIKit overlay: dragging and dropping text, and paste delegates (self-authored, on isim's drag and drop in
// UIKit+DragDrop.swift).
// - UITextView and UITextField are UITextDraggable: their textDragInteraction (enabled by default on iPad, as on iOS)
//   lifts the selected text after a long press inside the selection (script `longdrag`); the text drag delegate
//   can change the items, the lift preview and follow the session.
// - They are UITextDroppable: an editable one accepts dropped text (copied from elsewhere, moved within itself), at
//   the position under the finger; the text drop delegate proposes the action (insert, replace the selection or
//   everything), makes a non-editable view temporarily editable, and follows the session.
// - UITextPasteConfigurationSupporting: a paste delegate transforms each pasted item (UITextPasteItem), combines
//   them and performs the paste.
// UITextDragPreviewRenderer renders a TextKit 1 range as an image with its line rects.
import ObjectiveC

// MARK: - options, requests, proposals
public struct UITextDragOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let stripTextColorFromPreviews = UITextDragOptions(rawValue: 1 << 0)
}
@objc public enum UITextDropEditability: Int, Sendable { case no = 0, temporary, yes }

@MainActor public protocol UITextDragRequest: NSObjectProtocol {
    var dragRange: UITextRange { get }
    var suggestedItems: [UIDragItem] { get }
    var existingItems: [UIDragItem] { get }
    var isSelected: Bool { get }
    var dragSession: UIDragSession { get }
}
@MainActor public protocol UITextDropRequest: NSObjectProtocol {
    var dropPosition: UITextPosition { get }
    var suggestedProposal: UITextDropProposal { get }
    var isSameView: Bool { get }
    var dropSession: UIDropSession { get }
}
final class _IsimTextDragRequest: NSObject, UITextDragRequest {
    let dragRange: UITextRange, suggestedItems: [UIDragItem], existingItems: [UIDragItem], isSelected: Bool, dragSession: UIDragSession
    init(range: UITextRange, suggested: [UIDragItem], existing: [UIDragItem], selected: Bool, session: UIDragSession) {
        dragRange = range; suggestedItems = suggested; existingItems = existing; isSelected = selected; dragSession = session
    }
}
final class _IsimTextDropRequest: NSObject, UITextDropRequest {
    @objc let dropPosition: UITextPosition, suggestedProposal: UITextDropProposal, isSameView: Bool
    let dropSession: UIDropSession
    @objc(dropSession) var _objc_dropSession: AnyObject { dropSession as AnyObject }
    init(position: UITextPosition, proposal: UITextDropProposal, sameView: Bool, session: UIDropSession) {
        dropPosition = position; suggestedProposal = proposal; isSameView = sameView; dropSession = session
    }
}
/// what a drop does with the text: where it goes, how progress shows, who performs it
@objc(UITextDropProposal) open class UITextDropProposal: UIDropProposal, NSCopying {
    @objc public enum Action: Int, Sendable { case insert = 0, replaceSelection, replaceAll }
    @objc public enum ProgressMode: Int, Sendable { case system = 0, custom }
    @objc public enum Performer: Int, Sendable { case view = 0, delegate }
    open var dropAction: Action = .insert
    open var dropProgressMode: ProgressMode = .system
    open var useFastSameViewOperations = false
    open var dropPerformer: Performer = .view
    open func copy(with zone: NSZone? = nil) -> Any {
        let p = UITextDropProposal(operation: operation)
        p.dropAction = dropAction; p.dropProgressMode = dropProgressMode; p.useFastSameViewOperations = useFastSameViewOperations
        p.dropPerformer = dropPerformer; p.isPrecise = isPrecise; p.prefersFullSizePreview = prefersFullSizePreview
        return p
    }
}

// MARK: - delegates (optional methods have default implementations)
@MainActor public protocol UITextDragDelegate: AnyObject {
    func textDraggableView(_ textDraggableView: UIView & UITextDraggable, itemsForDrag dragRequest: UITextDragRequest) -> [UIDragItem]
    func textDraggableView(_ textDraggableView: UIView & UITextDraggable, dragPreviewForLiftingItem item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview?
    func textDraggableView(_ textDraggableView: UIView & UITextDraggable, willAnimateLiftWith animator: UIDragAnimating, session: UIDragSession)
    func textDraggableView(_ textDraggableView: UIView & UITextDraggable, dragSessionWillBegin session: UIDragSession)
    func textDraggableView(_ textDraggableView: UIView & UITextDraggable, dragSessionDidEnd session: UIDragSession, with operation: UIDropOperation)
}
extension UITextDragDelegate {
    public func textDraggableView(_ textDraggableView: UIView & UITextDraggable, itemsForDrag dragRequest: UITextDragRequest) -> [UIDragItem] { dragRequest.suggestedItems }
    public func textDraggableView(_ textDraggableView: UIView & UITextDraggable, dragPreviewForLiftingItem item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? { nil }
    public func textDraggableView(_ textDraggableView: UIView & UITextDraggable, willAnimateLiftWith animator: UIDragAnimating, session: UIDragSession) {}
    public func textDraggableView(_ textDraggableView: UIView & UITextDraggable, dragSessionWillBegin session: UIDragSession) {}
    public func textDraggableView(_ textDraggableView: UIView & UITextDraggable, dragSessionDidEnd session: UIDragSession, with operation: UIDropOperation) {}
}
@MainActor public protocol UITextDropDelegate: AnyObject {
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, willBecomeEditableForDrop drop: UITextDropRequest) -> UITextDropEditability
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, willPerformDrop drop: UITextDropRequest)
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, previewForDroppingAllItemsWithDefault defaultPreview: UITargetedDragPreview) -> UITargetedDragPreview?
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidEnter session: UIDropSession)
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidUpdate session: UIDropSession)
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidExit session: UIDropSession)
    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidEnd session: UIDropSession)
}
extension UITextDropDelegate {
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, willBecomeEditableForDrop drop: UITextDropRequest) -> UITextDropEditability { .no }
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal { drop.suggestedProposal }
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, willPerformDrop drop: UITextDropRequest) {}
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, previewForDroppingAllItemsWithDefault defaultPreview: UITargetedDragPreview) -> UITargetedDragPreview? { defaultPreview }
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidEnter session: UIDropSession) {}
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidUpdate session: UIDropSession) {}
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidExit session: UIDropSession) {}
    public func textDroppableView(_ textDroppableView: UIView & UITextDroppable, dropSessionDidEnd session: UIDropSession) {}
}

// MARK: - draggable and droppable text views and fields
@MainActor public protocol UITextDraggable: UITextInput {
    var textDragDelegate: UITextDragDelegate? { get set }
    var textDragInteraction: UIDragInteraction? { get }
    var isTextDragActive: Bool { get }
    var textDragOptions: UITextDragOptions { get set }
}
@MainActor public protocol UITextDroppable: UITextInput, UITextPasteConfigurationSupporting {
    var textDropDelegate: UITextDropDelegate? { get set }
    var textDropInteraction: UIDropInteraction? { get }
    var isTextDropActive: Bool { get }
}

nonisolated(unsafe) private var kTextDragDelegate: UInt8 = 0, kTextDropDelegate: UInt8 = 0, kTextDragInteraction: UInt8 = 0
nonisolated(unsafe) private var kTextDropInteraction: UInt8 = 0, kTextDragOptions: UInt8 = 0, kPasteDelegate: UInt8 = 0

/// the text a view shows and the editing it allows (text views and fields)
@MainActor enum _IsimText {
    static func text(_ v: UIView) -> String { (v as? UITextView)?.text ?? (v as? UITextField)?.text ?? "" }
    static func editable(_ v: UIView) -> Bool { (v as? UITextView)?.isEditable ?? (v as? UITextField)?.isEnabled ?? false }
    static func offset(_ v: UIView & UITextInput, _ p: UITextPosition) -> Int { v.offset(from: v.beginningOfDocument, to: p) }
    static func range(_ v: UIView & UITextInput, _ r: NSRange) -> UITextRange? {
        guard let a = v.position(from: v.beginningOfDocument, offset: r.location), let b = v.position(from: a, offset: r.length) else { return nil }
        return v.textRange(from: a, to: b)
    }
    static func nsRange(_ v: UIView & UITextInput, _ r: UITextRange) -> NSRange {
        let a = offset(v, r.start); return NSRange(location: a, length: offset(v, r.end) - a)
    }
    static func selected(_ v: UIView & UITextInput) -> NSRange { v.selectedTextRange.map { nsRange(v, $0) } ?? NSRange(location: 0, length: 0) }
}

/// the drag interaction's delegate for a text view: lifts the selection when the press is inside it
@MainActor final class _IsimTextDragSource: NSObject, @preconcurrency UIDragInteractionDelegate {
    weak var view: (UIView & UITextDraggable)?
    var range: NSRange?
    init(_ v: UIView & UITextDraggable) { view = v }
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let v = view, let sel = v.selectedTextRange, !sel.isEmpty else { return [] }
        let p = session.location(in: v)
        guard let pos = v.closestPosition(to: p) else { return [] }
        let o = _IsimText.offset(v, pos), r = _IsimText.nsRange(v, sel)
        guard o >= r.location && o <= r.location + r.length else { return [] }       // the press must be on the selection
        let text = (_IsimText.text(v) as NSString).substring(with: r)
        let item = UIDragItem(itemProvider: NSItemProvider(object: text as NSString))
        item.localObject = text
        let request = _IsimTextDragRequest(range: sel, suggested: [item], existing: [], selected: true, session: session)
        let items = v.textDragDelegate?.textDraggableView(v, itemsForDrag: request) ?? [item]
        if !items.isEmpty { range = r; print("isim: text drag of \"\(text)\" (\(items.count) item(s))") }
        return items
    }
    func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
        guard let v = view else { return nil }
        return v.textDragDelegate?.textDraggableView(v, dragPreviewForLiftingItem: item, session: session)
    }
    func dragInteraction(_ interaction: UIDragInteraction, willAnimateLiftWith animator: UIDragAnimating, session: UIDragSession) {
        guard let v = view else { return }
        v.textDragDelegate?.textDraggableView(v, willAnimateLiftWith: animator, session: session)
    }
    func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: UIDragSession) {
        guard let v = view else { return }
        _IsimTextDropState.sourceView = v; _IsimTextDropState.sourceRange = range
        v.textDragDelegate?.textDraggableView(v, dragSessionWillBegin: session)
    }
    func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation) {
        guard let v = view else { return }
        // a move to another view takes the text out of this one
        if operation == .move, _IsimTextDropState.droppedInto !== v, let r = range, _IsimText.editable(v), let tr = _IsimText.range(v, r) {
            v.replace(tr, withText: "")
            print("isim: text drag moved \(r.length) character(s) out")
        }
        v.textDragDelegate?.textDraggableView(v, dragSessionDidEnd: session, with: operation)
        range = nil
        _IsimTextDropState.sourceView = nil; _IsimTextDropState.sourceRange = nil; _IsimTextDropState.droppedInto = nil
    }
}
/// the text drag in progress (its source and range) and where its text was dropped
@MainActor enum _IsimTextDropState {
    static weak var sourceView: UIView?
    static var sourceRange: NSRange?
    static weak var droppedInto: UIView?
}
/// a text view's drop interaction: what the drag controller consults for text targets
@MainActor final class _IsimTextDropTarget: NSObject, UIDropInteractionDelegate {
    weak var view: (UIView & UITextDroppable)?
    init(_ v: UIView & UITextDroppable) { view = v }
}

/// whether a long press at a point lifts the selected text (an enabled text drag interaction, the press on the selection)
@MainActor private func _isimTextDragBegins(_ v: UIView & UITextDraggable, at p: CGPoint) -> Bool {
    guard let i = objc_getAssociatedObject(v, &kTextDragInteraction) as? UIDragInteraction, i.isEnabled,
          let sel = v.selectedTextRange, !sel.isEmpty, let pos = v.closestPosition(to: p) else { return false }
    let o = _IsimText.offset(v, pos), r = _IsimText.nsRange(v, sel)
    return o >= r.location && o <= r.location + r.length
}
@MainActor private func _isimMakeDragInteraction(_ v: UIView & UITextDraggable) -> UIDragInteraction {
    if let i = objc_getAssociatedObject(v, &kTextDragInteraction) as? UIDragInteraction { return i }
    let source = _IsimTextDragSource(v)
    let i = UIDragInteraction(delegate: source)
    i.isEnabled = UIDevice.current.userInterfaceIdiom == .pad              // as on iOS: on by default on iPad
    objc_setAssociatedObject(i, &kTextDragInteraction, source, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    objc_setAssociatedObject(v, &kTextDragInteraction, i, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    v.addInteraction(i)
    return i
}
@MainActor private func _isimMakeDropInteraction(_ v: UIView & UITextDroppable) -> UIDropInteraction {
    if let i = objc_getAssociatedObject(v, &kTextDropInteraction) as? UIDropInteraction { return i }
    let target = _IsimTextDropTarget(v)
    let i = UIDropInteraction(delegate: target)
    objc_setAssociatedObject(i, &kTextDropInteraction, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    objc_setAssociatedObject(v, &kTextDropInteraction, i, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    return i
}

extension UITextView: UITextDraggable, UITextDroppable, UITextPasteConfigurationSupporting {
    public var textDragDelegate: UITextDragDelegate? {
        get { (objc_getAssociatedObject(self, &kTextDragDelegate) as? _WeakBox)?.value as? UITextDragDelegate }
        set { objc_setAssociatedObject(self, &kTextDragDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC); _ = _isimMakeDragInteraction(self) }
    }
    public var textDragInteraction: UIDragInteraction? { _isimMakeDragInteraction(self) }
    public var isTextDragActive: Bool { _IsimTextDropState.sourceView === self && _IsimDragController.current != nil }
    public var textDragOptions: UITextDragOptions {
        get { UITextDragOptions(rawValue: (objc_getAssociatedObject(self, &kTextDragOptions) as? Int) ?? 0) }
        set { objc_setAssociatedObject(self, &kTextDragOptions, newValue.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var textDropDelegate: UITextDropDelegate? {
        get { (objc_getAssociatedObject(self, &kTextDropDelegate) as? _WeakBox)?.value as? UITextDropDelegate }
        set { objc_setAssociatedObject(self, &kTextDropDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var textDropInteraction: UIDropInteraction? { _isimMakeDropInteraction(self) }
    public var isTextDropActive: Bool { _IsimDragController.current?.textTarget === self }
    public var pasteDelegate: UITextPasteDelegate? {
        get { (objc_getAssociatedObject(self, &kPasteDelegate) as? _WeakBox)?.value as? UITextPasteDelegate }
        set { objc_setAssociatedObject(self, &kPasteDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    @objc func _isim_textPaste() -> Bool { _isimTextPaste(self) }
    @objc func _isim_textDragBeginsAt(_ p: CGPoint) -> Bool { _isimTextDragBegins(self, at: p) }
}
extension UITextField: UITextDraggable, UITextDroppable, UITextPasteConfigurationSupporting {
    public var textDragDelegate: UITextDragDelegate? {
        get { (objc_getAssociatedObject(self, &kTextDragDelegate) as? _WeakBox)?.value as? UITextDragDelegate }
        set { objc_setAssociatedObject(self, &kTextDragDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC); _ = _isimMakeDragInteraction(self) }
    }
    public var textDragInteraction: UIDragInteraction? { _isimMakeDragInteraction(self) }
    public var isTextDragActive: Bool { _IsimTextDropState.sourceView === self && _IsimDragController.current != nil }
    public var textDragOptions: UITextDragOptions {
        get { UITextDragOptions(rawValue: (objc_getAssociatedObject(self, &kTextDragOptions) as? Int) ?? 0) }
        set { objc_setAssociatedObject(self, &kTextDragOptions, newValue.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var textDropDelegate: UITextDropDelegate? {
        get { (objc_getAssociatedObject(self, &kTextDropDelegate) as? _WeakBox)?.value as? UITextDropDelegate }
        set { objc_setAssociatedObject(self, &kTextDropDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var textDropInteraction: UIDropInteraction? { _isimMakeDropInteraction(self) }
    public var isTextDropActive: Bool { _IsimDragController.current?.textTarget === self }
    public var pasteDelegate: UITextPasteDelegate? {
        get { (objc_getAssociatedObject(self, &kPasteDelegate) as? _WeakBox)?.value as? UITextPasteDelegate }
        set { objc_setAssociatedObject(self, &kPasteDelegate, _WeakBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    @objc func _isim_textPaste() -> Bool { _isimTextPaste(self) }
    @objc func _isim_textDragBeginsAt(_ p: CGPoint) -> Bool { _isimTextDragBegins(self, at: p) }
}

// MARK: - dropping on text (used by the drag controller)
@MainActor enum _IsimTextDrop {
    /// whether a view takes text drops: an editable text view or field, or one its delegate makes editable for the drop
    static func accepts(_ v: UIView, session: UIDropSession) -> Bool {
        guard let t = v as? (UIView & UITextDroppable), session.canLoadObjects(ofClass: NSString.self) else { return false }
        if let i = t.textDropInteraction, !(objc_getAssociatedObject(i, &kTextDropInteraction) is _IsimTextDropTarget) { return false }
        return _IsimText.editable(v) || t.textDropDelegate != nil
    }
    static func request(_ v: UIView & UITextDroppable, session: UIDropSession) -> _IsimTextDropRequest? {
        guard let pos = v.closestPosition(to: session.location(in: v)) else { return nil }
        let same = _IsimTextDropState.sourceView === v
        let proposal = UITextDropProposal(operation: same ? .move : .copy)
        return _IsimTextDropRequest(position: pos, proposal: proposal, sameView: same, session: session)
    }
    /// the operation the drop would have (the delegate's proposal; .forbidden where the view will not be editable)
    static func update(_ v: UIView & UITextDroppable, session: UIDropSession) -> (UIDropOperation, UITextDropProposal?) {
        guard let req = request(v, session: session) else { return (.cancel, nil) }
        let editable = _IsimText.editable(v) || (v.textDropDelegate?.textDroppableView(v, willBecomeEditableForDrop: req) ?? .no) != .no
        if !editable { return (.forbidden, nil) }
        v.textDropDelegate?.textDroppableView(v, dropSessionDidUpdate: session)
        let p = v.textDropDelegate?.textDroppableView(v, proposalForDrop: req) ?? req.suggestedProposal
        return (p.operation, p)
    }
    /// performs the drop: the dragged strings at the drop position (or replacing the selection / everything)
    static func perform(_ v: UIView & UITextDroppable, session: UIDropSession, proposal: UITextDropProposal?) {
        guard let req = request(v, session: session) else { return }
        let p = proposal ?? req.suggestedProposal
        v.textDropDelegate?.textDroppableView(v, willPerformDrop: req)
        _IsimTextDropState.droppedInto = v
        if p.dropPerformer == .delegate { print("isim: text drop performed by the delegate"); return }
        let strings = session.items.compactMap { ($0.localObject as? String) }
        let insertDropped: (String) -> Void = { text in
            var at = _IsimText.offset(v, req.dropPosition)
            var target = NSRange(location: at, length: 0)
            switch p.dropAction {
            case .replaceSelection: target = _IsimText.selected(v)
            case .replaceAll: target = NSRange(location: 0, length: (_IsimText.text(v) as NSString).length)
            case .insert: break
            @unknown default: break
            }
            // a move within the view takes the text out of its old place first
            if req.isSameView, p.operation == .move, let src = _IsimTextDropState.sourceRange, p.dropAction == .insert {
                if at >= src.location && at <= src.location + src.length { print("isim: text drop onto itself"); return }
                if let r = _IsimText.range(v, src) { v.replace(r, withText: "") }
                if at > src.location { at -= src.length }
                target = NSRange(location: at, length: 0)
                _IsimTextDropState.sourceRange = nil
            }
            if let r = _IsimText.range(v, target) {
                v.replace(r, withText: text)
                if let s = v.position(from: v.beginningOfDocument, offset: target.location), let e = v.position(from: s, offset: (text as NSString).length) {
                    v.selectedTextRange = v.textRange(from: s, to: e)
                }
            }
            print("isim: text drop \(p.operation == .move ? "moved" : "inserted") \"\(text)\" at \(target.location)")
        }
        if !strings.isEmpty { insertDropped(strings.joined()); return }
        _ = session.loadObjects(ofClass: NSString.self) { objs in
            MainActor.assumeIsolated { insertDropped(objs.compactMap { $0 as? String }.joined()) }
        }
    }
}

// MARK: - paste delegates
@MainActor public protocol UITextPasteConfigurationSupporting: UIPasteConfigurationSupporting {
    var pasteDelegate: UITextPasteDelegate? { get set }
}
/// one pasteboard item on its way into a text view: the delegate gives its result
@MainActor public protocol UITextPasteItem: NSObjectProtocol {
    var itemProvider: NSItemProvider { get }
    var localObject: Any? { get }
    var defaultAttributes: [NSAttributedString.Key: Any] { get }
    func setStringResult(_ string: String)
    func setAttributedStringResult(_ string: NSAttributedString)
    func setAttachmentResult(_ textAttachment: NSTextAttachment)
    func setNoResult()
    func setDefaultResult()
}
@MainActor public protocol UITextPasteDelegate: NSObjectProtocol {
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, transform item: UITextPasteItem)
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, combineItemAttributedStrings itemStrings: [NSAttributedString], for textRange: UITextRange) -> NSAttributedString
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, performPasteOf attributedString: NSAttributedString, to textRange: UITextRange) -> UITextRange
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, shouldAnimatePasteOf attributedString: NSAttributedString, to textRange: UITextRange) -> Bool
}
extension UITextPasteDelegate {
    public func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, transform item: UITextPasteItem) { item.setDefaultResult() }
    public func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, combineItemAttributedStrings itemStrings: [NSAttributedString], for textRange: UITextRange) -> NSAttributedString {
        let m = NSMutableAttributedString(); itemStrings.forEach { m.append($0) }; return m
    }
    public func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, performPasteOf attributedString: NSAttributedString, to textRange: UITextRange) -> UITextRange {
        _isimPerformPaste(textPasteConfigurationSupporting, attributedString, textRange) ?? textRange
    }
    public func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, shouldAnimatePasteOf attributedString: NSAttributedString, to textRange: UITextRange) -> Bool { true }
}
/// a paste into a search text field: an item can become a search token (iOS 15)
@MainActor public protocol UISearchTextFieldPasteItem: UITextPasteItem {
    func setSearchTokenResult(_ token: UISearchToken)
}
class _IsimTextPasteItem: NSObject, UITextPasteItem {
    let itemProvider: NSItemProvider
    let localObject: Any?
    let defaultAttributes: [NSAttributedString.Key: Any]
    let defaultString: String?
    var result: NSAttributedString?
    init(provider: NSItemProvider, string: String?, attributes: [NSAttributedString.Key: Any]) {
        itemProvider = provider; localObject = nil; defaultAttributes = attributes; defaultString = string
    }
    func setStringResult(_ string: String) { result = NSAttributedString(string: string, attributes: defaultAttributes) }
    func setAttributedStringResult(_ string: NSAttributedString) { result = string }
    func setAttachmentResult(_ a: NSTextAttachment) { result = NSAttributedString(attachment: a) }
    func setNoResult() { result = NSAttributedString() }
    func setDefaultResult() { result = defaultString.map { NSAttributedString(string: $0, attributes: defaultAttributes) } ?? NSAttributedString() }
}
final class _IsimSearchTextPasteItem: _IsimTextPasteItem, UISearchTextFieldPasteItem {
    var token: UISearchToken?
    func setSearchTokenResult(_ token: UISearchToken) { self.token = token; result = NSAttributedString() }
}
@MainActor func _isimPerformPaste(_ target: UITextPasteConfigurationSupporting, _ s: NSAttributedString, _ range: UITextRange) -> UITextRange? {
    guard let v = target as? (UIView & UITextInput) else { return nil }
    let start = _IsimText.offset(v, range.start)
    if let tv = v as? UITextView, tv.allowsEditingTextAttributes {
        let r = _IsimText.nsRange(v, range)
        tv.textStorage.replaceCharacters(in: r, with: s)
        tv.selectedRange = NSRange(location: r.location + s.length, length: 0)
    } else { v.replace(range, withText: s.string) }
    guard let a = v.position(from: v.beginningOfDocument, offset: start), let b = v.position(from: a, offset: s.length) else { return nil }
    return v.textRange(from: a, to: b)
}
/// a paste through the paste delegate (the view's paste: calls this first); false: the view pastes as usual
@MainActor func _isimTextPaste(_ v: UIView & UITextPasteConfigurationSupporting & UITextInput) -> Bool {
    guard let d = v.pasteDelegate, let range = v.selectedTextRange, _IsimText.editable(v) else { return false }
    let pb = UIPasteboard.general
    let strings = pb.strings ?? []
    let attrs: [NSAttributedString.Key: Any] = (v as? UITextView)?.typingAttributes ?? (v as? UITextField)?.defaultTextAttributes ?? [:]
    let providers = pb.itemProviders
    let search = v as? UISearchTextField
    let items: [_IsimTextPasteItem] = providers.enumerated().map { i, p in
        let s = i < strings.count ? strings[i] : nil
        return search != nil ? _IsimSearchTextPasteItem(provider: p, string: s, attributes: attrs) : _IsimTextPasteItem(provider: p, string: s, attributes: attrs)
    }
    for item in items { d.textPasteConfigurationSupporting(v, transform: item) }
    /* search tokens go after the field's tokens, the rest pastes as text */
    if let search { for case let t? in items.map({ ($0 as? _IsimSearchTextPasteItem)?.token }) { search.insertToken(t, at: search.tokens.count) } }
    let parts = items.map { $0.result ?? NSAttributedString() }
    let combined = d.textPasteConfigurationSupporting(v, combineItemAttributedStrings: parts, for: range)
    _ = d.textPasteConfigurationSupporting(v, shouldAnimatePasteOf: combined, to: range)
    let done = d.textPasteConfigurationSupporting(v, performPasteOf: combined, to: range)
    v.selectedTextRange = v.textRange(from: done.end, to: done.end)
    print("isim: pasted \(items.count) item(s) through the paste delegate: \"\(combined.string)\"")
    return true
}

// MARK: - text drag previews (TextKit 1)
@MainActor open class UITextDragPreviewRenderer: NSObject {
    public let layoutManager: NSLayoutManager
    public let range: NSRange
    public private(set) var firstLineRect = CGRect.zero
    public private(set) var bodyRect = CGRect.zero
    public private(set) var lastLineRect = CGRect.zero
    private let unify: Bool
    public convenience init(layoutManager: NSLayoutManager, range: NSRange) { self.init(layoutManager: layoutManager, range: range, unifyRects: false) }
    public init(layoutManager: NSLayoutManager, range: NSRange, unifyRects: Bool) {
        self.layoutManager = layoutManager; self.range = range; unify = unifyRects
        super.init()
        var rects: [CGRect] = []
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { _, _, container, lineGlyphs, _ in
            let part = NSIntersectionRange(lineGlyphs, glyphs)
            if part.length > 0 { rects.append(layoutManager.boundingRect(forGlyphRange: part, in: container)) }
        }
        firstLineRect = rects.first ?? .zero
        lastLineRect = rects.count > 1 ? rects.last! : firstLineRect
        bodyRect = rects.count > 2 ? rects[1..<(rects.count - 1)].reduce(CGRect.null) { $0.union($1) } : .zero
        var origin = CGPoint.zero
        adjust(firstLineRect: &firstLineRect, bodyRect: &bodyRect, lastLineRect: &lastLineRect, textOrigin: &origin)
        if unify {
            let all = [firstLineRect, bodyRect, lastLineRect].filter { !$0.isEmpty }.reduce(CGRect.null) { $0.union($1) }
            firstLineRect = all; bodyRect = .zero; lastLineRect = all
        }
    }
    /// subclasses move the rects (and the text's origin in them)
    open func adjust(firstLineRect: inout CGRect, bodyRect: inout CGRect, lastLineRect: inout CGRect, textOrigin origin: inout CGPoint) {}
    /// the range's text, drawn in the union of its rects
    open var image: UIImage {
        let all = [firstLineRect, bodyRect, lastLineRect].filter { !$0.isEmpty }.reduce(CGRect.null) { $0.union($1) }
        let box = all.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : all
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return UIGraphicsImageRenderer(size: box.size).image { _ in
            layoutManager.drawGlyphs(forGlyphRange: glyphs, at: CGPoint(x: -box.minX, y: -box.minY))
        }
    }
}
