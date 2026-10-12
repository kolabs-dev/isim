// isim SwiftUI (iOS 27): reordering in any container — `reorderable()` / `reorderable(collectionID:)` on a ForEach,
// `reorderContainer(for:isEnabled:move:)` (and the `in:` / `itemID:` forms) on the stack, grid or layout around it,
// `ReorderDifference` (sources, destination: before an item or at the end of a collection).
// Adapted: a long press lifts the item (it scales up and follows the finger); the other items of its collection make
// room for it (stacks lay out again with the item's size, grids move items to the slots); dropping calls `move`
// with the difference, animated. Dragging over another collection's items targets that collection (without making
// room). The lift is isim's own (no system drag preview).
import UIKit

/// The collection ID of a container with a single collection.
@available(iOS 27.0, *)
public struct ReorderableSingleCollectionIdentifier: Hashable, Sendable {
    public init() {}
}

/// What a reordering moved, and where to.
@available(iOS 27.0, *)
public struct ReorderDifference<ItemID: Hashable & Sendable, CollectionID: Hashable & Sendable>: Hashable, Sendable {
    public struct Destination: Hashable, Sendable {
        @frozen public enum Position: Hashable, Sendable {
            case before(ItemID)
            case end
        }
        public var position: Position
        public var collectionID: CollectionID
        public init(position: Position, collectionID: CollectionID) { self.position = position; self.collectionID = collectionID }
    }
    /// The identifiers of the items to move.
    public var sources: [ItemID]
    public var destination: Destination
}
@available(iOS 27.0, *)
extension ReorderDifference.Destination where CollectionID == ReorderableSingleCollectionIdentifier {
    public init(position: Position) { self.init(position: position, collectionID: ReorderableSingleCollectionIdentifier()) }
}

// MARK: - reorderable()

/// A ForEach whose views can be reordered inside a reorder container.
public struct _ReorderableContent<Base: DynamicViewContent>: DynamicViewContent, _PrimitiveView {
    let base: Base, collection: AnyHashable
    public var data: Base.Data { base.data }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let n = _resolve(base, ctx)
        let items = n is _GroupNode ? n.children : [n]
        let ids = (base as? _IdentifiedContent)?._ids(ctx) ?? []
        let wrapped = items.enumerated().map { i, item -> _Node in
            let id = i < ids.count ? ids[i] : (item.tag ?? AnyHashable(i))
            let w = _ReorderItemNode(path: item.path + "/reorder", id: id, collection: collection, child: item)
            w.tag = item.tag
            return w
        }
        return _GroupNode(path: n.path, children: wrapped)
    }
}
extension _ReorderableContent: _IdentifiedContent {
    func _ids(_ ctx: _Context) -> [AnyHashable] { (base as? _IdentifiedContent)?._ids(ctx) ?? [] }
}
extension DynamicViewContent {
    /// Lets people reorder the views of this content (long press, then drag) inside a `reorderContainer`.
    @available(iOS 27.0, *)
    public func reorderable() -> _ReorderableContent<Self> { _ReorderableContent(base: self, collection: AnyHashable(ReorderableSingleCollectionIdentifier())) }
    /// The same within and between collections (sections) of a `reorderContainer(for:in:)`.
    @available(iOS 27.0, *)
    public func reorderable(collectionID: some Hashable & Sendable) -> _ReorderableContent<Self> { _ReorderableContent(base: self, collection: AnyHashable(collectionID)) }
}

final class _ReorderItemNode: _WrapperNode {
    let id: AnyHashable, collection: AnyHashable
    init(path: String, id: AnyHashable, collection: AnyHashable, child: _Node) { self.id = id; self.collection = collection; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIReorderItemView() }
        v.itemID = id; v.collection = collection
        return v
    }
}
final class _SUIReorderItemView: UIView {
    var itemID: AnyHashable = 0, collection: AnyHashable = 0
    /// the whole item takes touches (to be lifted), its controls their own
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled else { return nil }
        for s in subviews.reversed() { if let h = s.hitTest(s.convert(point, from: self), with: event), h !== s || !(s is _PassthroughView) { return h } }
        return bounds.contains(point) ? self : nil
    }
}

// MARK: - reorderContainer

extension View {
    /// The container (stack, grid, layout) whose reorderable items people can reorder; `move` applies the change.
    @available(iOS 27.0, *)
    public func reorderContainer<Item: Identifiable>(for item: Item.Type, isEnabled: Bool = true,
                                                     move: @escaping (ReorderDifference<Item.ID, ReorderableSingleCollectionIdentifier>) -> ()) -> some View
    where Item.ID: Sendable { _reorderContainer(isEnabled, move) }
    /// The same, with items identified by `itemID`.
    @available(iOS 27.0, *)
    public func reorderContainer<Item, ItemID: Hashable & Sendable>(for item: Item.Type, itemID: KeyPath<Item, ItemID>, isEnabled: Bool = true,
                                                                    move: @escaping (ReorderDifference<ItemID, ReorderableSingleCollectionIdentifier>) -> ()) -> some View {
        _reorderContainer(isEnabled, move)
    }
    /// A container of several collections (sections), each a `reorderable(collectionID:)` ForEach.
    @available(iOS 27.0, *)
    public func reorderContainer<Item: Identifiable, CollectionID: Hashable & Sendable>(for item: Item.Type, in collectionID: CollectionID.Type, isEnabled: Bool = true,
                                                                                        move: @escaping (ReorderDifference<Item.ID, CollectionID>) -> ()) -> some View
    where Item.ID: Sendable { _reorderContainer(isEnabled, move) }
    @available(iOS 27.0, *)
    public func reorderContainer<Item, ItemID: Hashable & Sendable, CollectionID: Hashable & Sendable>(for item: Item.Type, itemID: KeyPath<Item, ItemID>, in collectionID: CollectionID.Type,
                                                                                                    isEnabled: Bool = true,
                                                                                                    move: @escaping (ReorderDifference<ItemID, CollectionID>) -> ()) -> some View {
        _reorderContainer(isEnabled, move)
    }
    @available(iOS 27.0, *)
    func _reorderContainer<ItemID, CollectionID>(_ enabled: Bool, _ move: @escaping (ReorderDifference<ItemID, CollectionID>) -> ()) -> some View {
        _modify { ctx, c in
            let apply: ([AnyHashable], AnyHashable?, AnyHashable) -> Void = { sources, before, collection in
                guard let cid = collection.base as? CollectionID else { return }
                let position: ReorderDifference<ItemID, CollectionID>.Destination.Position = before.flatMap { $0.base as? ItemID }.map { .before($0) } ?? .end
                move(ReorderDifference(sources: sources.compactMap { $0.base as? ItemID }, destination: .init(position: position, collectionID: cid)))
            }
            return _ReorderContainerNode(path: ctx.path, enabled: enabled, apply: apply, child: _resolve(c, ctx.child("reorder")))
        }
    }
}

final class _ReorderContainerNode: _WrapperNode {
    let enabled: Bool, apply: ([AnyHashable], AnyHashable?, AnyHashable) -> Void
    init(path: String, enabled: Bool, apply: @escaping ([AnyHashable], AnyHashable?, AnyHashable) -> Void, child: _Node) {
        self.enabled = enabled; self.apply = apply; super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIReorderContainerView() }
        v.apply = apply
        v.press.isEnabled = enabled
        return v
    }
}

/// The view of a reorder container: a long press on an item lifts it, dragging moves it, lifting the finger drops it.
final class _SUIReorderContainerView: _PassthroughViewBase {
    var apply: (([AnyHashable], AnyHashable?, AnyHashable) -> Void)?
    let press = UILongPressGestureRecognizer()
    struct Item { let view: _SUIReorderItemView; let frame: CGRect }
    var items: [Item] = [], dragged: Item?, start = CGPoint.zero
    var target: (before: AnyHashable?, collection: AnyHashable)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        press.minimumPressDuration = 0.4
        press.addTarget(self, action: #selector(pressed(_:)))
        press.cancelsTouchesInView = true
        press._isim_setExclusive(true)                    // a lifted item is not scrolled away
        addGestureRecognizer(press)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The reorderable items of this container (not of containers inside it), in order, with their frames here.
    func collect() -> [Item] {
        var out: [Item] = []
        func walk(_ v: UIView) {
            for s in v.subviews {
                if s is _SUIReorderContainerView { continue }
                if let i = s as? _SUIReorderItemView, !i.isHidden {
                    out.append(Item(view: i, frame: i.superview!.convert(i._untransformedFrame, to: self)))
                    continue
                }
                walk(s)
            }
        }
        walk(self)
        return out
    }
    @objc func pressed(_ g: UILongPressGestureRecognizer) {
        let p = g.location(in: self)
        switch g.state {
        case .began:
            items = collect()
            guard let hit = items.first(where: { $0.frame.contains(p) }) else { g.isEnabled = false; g.isEnabled = true; return }
            dragged = hit; start = p; target = nil
            // lift: above everything in the container, slightly larger, with a shadow
            var x: UIView = hit.view
            while let sup = x.superview, x !== self { sup.bringSubviewToFront(x); x = sup }
            hit.view.layer.shadowColor = UIColor.black.cgColor
            hit.view.layer.shadowOpacity = 0.25; hit.view.layer.shadowRadius = 10; hit.view.layer.shadowOffset = CGSize(width: 0, height: 4)
            UIView.animate(withDuration: 0.2) { hit.view.transform = CGAffineTransform(scaleX: 1.04, y: 1.04) }
            print("isim: reorder lift \(hit.view.itemID.base)")
        case .changed:
            guard let d = dragged else { return }
            d.view.transform = CGAffineTransform(translationX: p.x - start.x, y: p.y - start.y).scaledBy(x: 1.04, y: 1.04)
            let t = destination(at: p, dragging: d)
            if t.before != target?.before || t.collection != target?.collection { target = t; makeRoom() }
        case .ended:
            guard let d = dragged, let t = target ?? Optional(destination(at: p, dragging: d)) else { return }
            drop(d, t)
        default:
            guard let d = dragged else { return }
            UIView.animate(withDuration: 0.25) { for i in self.items { i.view.transform = .identity } }
            d.view.layer.shadowOpacity = 0
            dragged = nil
        }
    }
    /// Where the item would go for a finger at `p`: before the item it is over (its first half) or the next one, or the
    /// end of that item's collection.
    func destination(at p: CGPoint, dragging d: Item) -> (before: AnyHashable?, collection: AnyHashable) {
        let others = items.filter { $0.view !== d.view }
        guard let over = others.min(by: { dist($0.frame, p) < dist($1.frame, p) }) else { return (nil, d.view.collection) }
        let coll = over.view.collection
        let same = others.filter { $0.view.collection == coll }
        let f = over.frame
        // the first half along the row (same row: x) or the column (y)
        let firstHalf = abs(p.y - f.midY) < f.height / 2 && isRow(same) ? p.x < f.midX : p.y < f.midY
        if firstHalf { return (over.view.itemID, coll) }
        let i = same.firstIndex { $0.view === over.view }!
        return (i + 1 < same.count ? same[i + 1].view.itemID : nil, coll)
    }
    func dist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX), dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return hypot(dx, dy)
    }
    /// items laid out along a row (an HStack, or a grid's rows: several items share a y)
    func isRow(_ its: [Item]) -> Bool { its.count > 1 && Set(its.map { Int($0.frame.minY.rounded()) }).count < its.count }
    /// The items of the dragged one's collection move to show where it would go.
    func makeRoom() {
        guard let d = dragged, let t = target else { return }
        let coll = d.view.collection
        let mine = items.filter { $0.view.collection == coll }
        var order = mine.filter { $0.view !== d.view }
        if t.collection == coll {
            let k = t.before.flatMap { b in order.firstIndex { $0.view.itemID == b } } ?? order.count
            order.insert(d, at: k)
        }
        let slots = mine.map(\.frame)
        let vertical = Set(slots.map { Int($0.minX.rounded()) }).count == 1, horizontal = Set(slots.map { Int($0.minY.rounded()) }).count == 1
        var positions: [CGPoint] = []
        if (vertical || horizontal), slots.count > 1 {
            // a stack: the items one after the other with their own sizes and the stack's spacing
            let spacing = vertical ? slots[1].minY - slots[0].maxY : slots[1].minX - slots[0].maxX
            var cur = vertical ? slots[0].minY : slots[0].minX
            for it in order {
                positions.append(vertical ? CGPoint(x: it.frame.minX, y: cur) : CGPoint(x: cur, y: it.frame.minY))
                cur += (vertical ? it.frame.height : it.frame.width) + spacing
            }
        } else {
            positions = order.indices.map { j in j < slots.count ? slots[j].origin : order[j].frame.origin }
        }
        UIView.animate(withDuration: 0.2) {
            for (j, it) in order.enumerated() where it.view !== d.view {
                it.view.transform = CGAffineTransform(translationX: positions[j].x - it.frame.minX, y: positions[j].y - it.frame.minY)
            }
            if t.collection != coll { for it in mine where it.view !== d.view { it.view.transform = .identity } }
        }
    }
    func drop(_ d: Item, _ t: (before: AnyHashable?, collection: AnyHashable)) {
        dragged = nil
        d.view.layer.shadowOpacity = 0
        // no change: back into place
        let mine = items.filter { $0.view.collection == d.view.collection }
        let i = mine.firstIndex { $0.view === d.view }!
        let nextID = i + 1 < mine.count ? mine[i + 1].view.itemID : nil
        if t.collection == d.view.collection && (t.before == d.view.itemID || t.before == nextID) {
            UIView.animate(withDuration: 0.25) { for it in self.items { it.view.transform = .identity } }
            return
        }
        // the views stay where they are shown; the update with the new order moves them from there
        for it in items {
            let shown = it.view.frame
            it.view.transform = .identity
            it.view.frame = it.view === d.view ? shown : shown
        }
        print("isim: reorder drop \(d.view.itemID.base) before \(t.before.map { "\($0.base)" } ?? "end")")
        let apply = self.apply
        withAnimation(.smooth(duration: 0.3)) { apply?([d.view.itemID], t.before, t.collection) }
    }
}
