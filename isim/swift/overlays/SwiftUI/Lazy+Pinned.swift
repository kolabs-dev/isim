// isim SwiftUI: LazyVStack / LazyHStack / LazyVGrid / LazyHGrid with sections and `pinnedViews` — section headers
// stick to the top (leading) edge of the scroll view while their section scrolls by, footers to the bottom
// (trailing) edge — and plain List headers (Navigation.swift). The lazy containers lay out all their views (isim
// does not create them on demand; adapted: same layout, eager).
import UIKit

// MARK: - Pinning

/// A view that sticks to an edge of its scroll view while its section is under that edge. Positions are along the
/// scroll axis, in `host`'s coordinates; `rest` is where the view sits when not pinned (in its superview).
struct _PinnedView {
    weak var view: UIView?
    weak var host: UIView?
    var natural: CGFloat, size: CGFloat
    var start: CGFloat, end: CGFloat           // the section's extent
    var footer = false
    var rest: CGPoint
}
@MainActor func _applyPins(_ pins: [_PinnedView], in s: UIScrollView, horizontal: Bool) {
    for p in pins {
        guard let v = p.view, let host = p.host else { continue }
        let o = host === s ? .zero : host.convert(CGPoint.zero, to: s)
        let inset = s.adjustedContentInset
        let off = horizontal ? s.contentOffset.x - o.x : s.contentOffset.y - o.y
        var pos = p.natural
        if p.footer {
            let edge = off + (horizontal ? s.bounds.width - inset.right : s.bounds.height - inset.bottom)
            pos = min(p.natural, max(p.start, edge - p.size))
        } else {
            let edge = off + (horizontal ? inset.left : inset.top)
            pos = max(p.natural, min(edge, p.end - p.size))
        }
        let d = pos - p.natural
        let origin = horizontal ? CGPoint(x: p.rest.x + d, y: p.rest.y) : CGPoint(x: p.rest.x, y: p.rest.y + d)
        if v.frame.origin != origin { UIView.performWithoutAnimation { v.frame.origin = origin } }
        if d != 0 { v.superview?.bringSubviewToFront(v) }
    }
}

/// Registers a container's pinned views with the scroll view around it (they follow its scrolling).
@MainActor func _registerPins(_ pins: [_PinnedView], from container: UIView, horizontal: Bool, _ g: _Graph) {
    var s: UIView? = container.superview
    while let x = s, !(x is _SUIScrollView) { s = x.superview }
    guard let scroll = s as? _SUIScrollView else { return }
    scroll.pinGroups[ObjectIdentifier(container)] = _PinGroup(container: container, horizontal: horizontal, pins: pins)
    for p in pins { if let v = p.view { container.bringSubviewToFront(v) } }
    g.postRender.append { [weak scroll] in scroll?.applyPins() }
}
struct _PinGroup { weak var container: UIView?; let horizontal: Bool; let pins: [_PinnedView] }
extension _SUIScrollView {
    func applyPins() {
        pinGroups = pinGroups.filter { $0.value.container != nil }
        for (_, group) in pinGroups { _applyPins(group.pins, in: self, horizontal: group.horizontal) }
    }
}

/// Pins for the sections among a container's children (frames relative to the container).
@MainActor func _sectionPins(_ children: [_Node], _ pinned: PinnedScrollableViews, axis: Axis, host: UIView, _ g: _Graph) -> [_PinnedView] {
    guard !pinned.isEmpty else { return [] }
    var out: [_PinnedView] = []
    func lo(_ r: CGRect) -> CGFloat { axis == .vertical ? r.minY : r.minX }
    func hi(_ r: CGRect) -> CGFloat { axis == .vertical ? r.maxY : r.maxX }
    func len(_ r: CGRect) -> CGFloat { axis == .vertical ? r.height : r.width }
    for n in _flattenGroups(children) {
        guard let s = n as? _SectionNode else { continue }
        let parts = s.spliced
        guard let first = parts.first, let last = parts.last else { continue }
        let start = lo(first.frame), end = hi(last.frame)
        if pinned.contains(.sectionHeaders), let h = s.header, let v = g.views[h.viewKey] {
            out.append(_PinnedView(view: v, host: host, natural: lo(h.frame), size: len(h.frame), start: start, end: end, rest: h.frame.origin))
        }
        if pinned.contains(.sectionFooters), let f = s.footer, let v = g.views[f.viewKey] {
            out.append(_PinnedView(view: v, host: host, natural: lo(f.frame), size: len(f.frame), start: s.header.map { hi($0.frame) } ?? start, end: end,
                                   footer: true, rest: f.frame.origin))
        }
    }
    return out
}

// MARK: - Lazy stacks

public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1), sectionFooters = PinnedScrollableViews(rawValue: 2)
}
public struct LazyVStack<Content: View>: View, _PrimitiveView {
    let alignment: HorizontalAlignment, spacing: CGFloat?, pinnedViews: PinnedScrollableViews, content: Content
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.pinnedViews = pinnedViews; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let n = _StackNode(path: ctx.path, axis: .vertical, spacing: spacing, alignment: Alignment(horizontal: alignment, vertical: .center), children: [_resolve(content, ctx.child("c"))])
        n.pinned = pinnedViews
        n.lazy = true
        return n
    }
}
public struct LazyHStack<Content: View>: View, _PrimitiveView {
    let alignment: VerticalAlignment, spacing: CGFloat?, pinnedViews: PinnedScrollableViews, content: Content
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.pinnedViews = pinnedViews; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let n = _StackNode(path: ctx.path, axis: .horizontal, spacing: spacing, alignment: Alignment(horizontal: .center, vertical: alignment), children: [_resolve(content, ctx.child("c"))])
        n.pinned = pinnedViews
        n.lazy = true
        return n
    }
}

// MARK: - Lazy grids

public struct LazyVGrid<Content: View>: View, _PrimitiveView {
    let columns: [GridItem], alignment: HorizontalAlignment, spacing: CGFloat?, pinnedViews: PinnedScrollableViews, content: Content
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.columns = columns; self.alignment = alignment; self.spacing = spacing; self.pinnedViews = pinnedViews; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _LazyGridNode(path: ctx.path, axis: .vertical, tracks: columns, spacing: spacing ?? 8, alignment: alignment.id, pinned: pinnedViews, child: _resolve(content, ctx.child("grid")))
    }
}
/// Rows of items flowing top to bottom, then left to right (put it in a horizontal ScrollView).
public struct LazyHGrid<Content: View>: View, _PrimitiveView {
    let rows: [GridItem], alignment: VerticalAlignment, spacing: CGFloat?, pinnedViews: PinnedScrollableViews, content: Content
    public init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.rows = rows; self.alignment = alignment; self.spacing = spacing; self.pinnedViews = pinnedViews; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _LazyGridNode(path: ctx.path, axis: .horizontal, tracks: rows, spacing: spacing ?? 8, alignment: alignment.id, pinned: pinnedViews, child: _resolve(content, ctx.child("hgrid")))
    }
}

/// LazyVGrid (axis .vertical: tracks are columns, lines grow downwards) and LazyHGrid (tracks are rows, lines grow to
/// the right). Sections: the header and footer span the grid's tracks, the section's items start a new line.
final class _LazyGridNode: _Node {
    let axis: Axis, tracks: [GridItem], spacing: CGFloat, alignment: Int, pinned: PinnedScrollableViews
    enum Run { case full(_Node), cells([_Node]) }
    init(path: String, axis: Axis, tracks: [GridItem], spacing: CGFloat, alignment: Int, pinned: PinnedScrollableViews, child: _Node) {
        self.axis = axis; self.tracks = tracks; self.spacing = spacing; self.alignment = alignment; self.pinned = pinned
        super.init(path: path, children: [child])
    }
    var runs: [Run] {
        var out: [Run] = [], cells: [_Node] = []
        func flush() { if !cells.isEmpty { out.append(.cells(cells)); cells = [] } }
        for n in _flattenGroups(children) {
            if let s = n as? _SectionNode {
                flush()
                if let h = s.header { out.append(.full(h)) }
                let items = _flatten(s.rows)
                if !items.isEmpty { out.append(.cells(items)) }
                if let f = s.footer { out.append(.full(f)) }
            } else { cells.append(n) }
        }
        flush()
        return out
    }
    var items: [_Node] { runs.flatMap { r -> [_Node] in if case .cells(let c) = r { return c }; if case .full(let n) = r { return [n] }; return [] } }
    /// Track widths (columns) or heights (rows) and the gap after each: fixed sizes, flexible ones share the rest,
    /// an adaptive item becomes as many tracks as fit.
    func trackSizes(_ length: CGFloat) -> [(CGFloat, CGFloat, Alignment?)] {
        var ts: [(GridItem.Size, CGFloat, Alignment?)] = []
        for t in tracks {
            let gap = t.spacing ?? 8
            if case .adaptive(let mn, let mx) = t.size {
                for _ in 0..<max(1, Int((length + gap) / (mn + gap))) { ts.append((.flexible(minimum: mn, maximum: mx), gap, t.alignment)) }
            } else { ts.append((t.size, gap, t.alignment)) }
        }
        let gaps = ts.dropLast().reduce(0) { $0 + $1.1 }
        var fixed: CGFloat = 0, flex = 0
        for (s, _, _) in ts { if case .fixed(let w) = s { fixed += w } else { flex += 1 } }
        func bounds(_ s: GridItem.Size) -> (CGFloat, CGFloat)? {
            switch s { case .flexible(let mn, let mx), .adaptive(let mn, let mx): return (mn, mx); default: return nil }
        }
        // flexible tracks share what is left equally, within their bounds (the space a bounded track does not take
        // goes to the others)
        var share = flex > 0 ? max(0, (length - gaps - fixed) / CGFloat(flex)) : 0
        for _ in 0..<4 {
            var left = length - gaps - fixed, open = 0
            for (s, _, _) in ts { if let (mn, mx) = bounds(s) { let v = min(max(share, mn), mx); if v == share { open += 1 } else { left -= v } } }
            let next = open > 0 ? max(0, left / CGFloat(open)) : share
            if abs(next - share) < 0.25 { break }
            share = next
        }
        return ts.map { s, gap, a in
            if case .fixed(let w) = s { return (w, gap, a) }
            let (mn, mx) = bounds(s)!
            return (min(max(share, mn), mx), gap, a)
        }
    }
    var hasFlexible: Bool { tracks.contains { if case .fixed = $0.size { return false }; return true } }
    func cross(_ p: _Proposal) -> CGFloat? { axis == .vertical ? p.width : p.height }
    func along(_ s: CGSize) -> CGFloat { axis == .vertical ? s.height : s.width }
    func across(_ s: CGSize) -> CGFloat { axis == .vertical ? s.width : s.height }
    /// The line extents (row heights / column widths) of a run of cells.
    func lines(_ cells: [_Node], _ ts: [(CGFloat, CGFloat, Alignment?)]) -> [CGFloat] {
        let n = max(1, ts.count)
        var out: [CGFloat] = []
        for (i, c) in cells.enumerated() {
            if i % n == 0 { out.append(0) }
            let t = ts[i % n].0
            let s = c.sizeThatFits(axis == .vertical ? _Proposal(width: t, height: nil) : _Proposal(width: nil, height: t))
            out[out.count - 1] = max(out[out.count - 1], along(s))
        }
        return out
    }
    func totalTracks(_ ts: [(CGFloat, CGFloat, Alignment?)]) -> CGFloat { ts.reduce(0) { $0 + $1.0 } + ts.dropLast().reduce(0) { $0 + $1.1 } }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let length = min(cross(p) ?? (axis == .vertical ? 320 : 300), 1e6)
        let ts = trackSizes(length)
        let width = hasFlexible ? length : totalTracks(ts)
        var main: CGFloat = 0, count = 0
        for r in runs {
            switch r {
            case .full(let n):
                main += along(n.sizeThatFits(axis == .vertical ? _Proposal(width: width, height: nil) : _Proposal(width: nil, height: width))); count += 1
            case .cells(let c):
                let ls = lines(c, ts); main += ls.reduce(0, +) + spacing * CGFloat(max(0, ls.count - 1)); count += 1
            }
        }
        main += spacing * CGFloat(max(0, count - 1))
        return axis == .vertical ? CGSize(width: max(width, totalTracks(ts)), height: main) : CGSize(width: main, height: max(width, totalTracks(ts)))
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let length = across(rect.size)
        let ts = trackSizes(length)
        let total = totalTracks(ts)
        // the tracks sit by the grid's alignment where they do not fill it
        let start = alignment == 0 ? 0 : alignment == 2 ? max(0, length - total) : max(0, (length - total) / 2)
        var pos: CGFloat = 0
        func put(_ n: _Node, _ r: CGRect, _ a: Alignment) {
            let s = n.sizeThatFits(_Proposal(width: r.width, height: r.height))
            n.place(_align(CGSize(width: min(s.width, r.width), height: min(s.height, r.height)), in: r, a))
        }
        for (k, run) in runs.enumerated() {
            if k > 0 { pos += spacing }
            switch run {
            case .full(let n):
                let s = n.sizeThatFits(axis == .vertical ? _Proposal(width: length, height: nil) : _Proposal(width: nil, height: length))
                let r = axis == .vertical ? CGRect(x: 0, y: pos, width: length, height: s.height) : CGRect(x: pos, y: 0, width: s.width, height: length)
                put(n, r, axis == .vertical ? .leading : .top)
                pos += along(r.size)
            case .cells(let cells):
                let ls = lines(cells, ts), n = max(1, ts.count)
                var linePos = pos
                for (i, c) in cells.enumerated() {
                    let line = i / n, t = i % n
                    if t == 0 && line > 0 { linePos += ls[line - 1] + spacing }
                    var off = start
                    for j in 0..<t { off += ts[j].0 + ts[j].1 }
                    let r = axis == .vertical ? CGRect(x: off, y: linePos, width: ts[t].0, height: ls[line]) : CGRect(x: linePos, y: off, width: ls[line], height: ts[t].0)
                    put(c, r, ts[t].2 ?? .center)
                }
                pos = linePos + (ls.last ?? 0)
            }
        }
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        for (i, c) in items.enumerated() { g.mount(c, in: view, order: i) }
        if !pinned.isEmpty { _registerPins(_sectionPins(children, pinned, axis: axis, host: view, g), from: view, horizontal: axis == .horizontal, g) }
    }
}
