// isim SwiftUI: Grid / GridRow (column sizing, spans, cell alignment, unsized axes), LazyHGrid(rows:) and
// ViewThatFits. Layout follows SwiftUI's rules: a column is as wide as its widest cell, flexible cells share what is
// left; a view outside a GridRow is a full-width row.
import UIKit

// MARK: - Grid

public struct Grid<Content: View>: View, _PrimitiveView {
    let alignment: Alignment, hSpacing: CGFloat?, vSpacing: CGFloat?, content: Content
    public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; hSpacing = horizontalSpacing; vSpacing = verticalSpacing; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _GridLayoutNode(path: ctx.path, alignment: alignment, hSpacing: hSpacing ?? 8, vSpacing: vSpacing ?? 8, child: _resolve(content, ctx.child("grid")))
    }
}
public struct GridRow<Content: View>: View, _PrimitiveView {
    let alignment: VerticalAlignment?, content: Content
    public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) { self.alignment = alignment; self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _GridRowNode(path: ctx.path, alignment: alignment, children: [_resolve(content, ctx.child("row"))]) }
}
final class _GridRowNode: _Node {
    let alignment: VerticalAlignment?
    init(path: String, alignment: VerticalAlignment?, children: [_Node]) { self.alignment = alignment; super.init(path: path, children: children) }
    var cells: [_Node] { _flatten(children) }
}
/// Per-cell grid settings (gridCellColumns, gridColumnAlignment, gridCellAnchor, gridCellUnsizedAxes).
final class _GridCellNode: _WrapperNode {
    var columns = 1
    var columnAlignment: HorizontalAlignment?
    var anchor: UnitPoint?
    var unsized: Axis.Set = []
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
@MainActor func _gridCell(_ n: _Node) -> _GridCellNode? {
    var x: _Node? = n
    while let c = x { if let g = c as? _GridCellNode { return g }; x = c.children.count == 1 ? c.children[0] : nil }
    return nil
}
extension View {
    public func gridCellColumns(_ count: Int) -> some View { _gridCellModifier { $0.columns = max(1, count) } }
    public func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View { _gridCellModifier { $0.columnAlignment = guide } }
    public func gridCellAnchor(_ anchor: UnitPoint) -> some View { _gridCellModifier { $0.anchor = anchor } }
    public func gridCellUnsizedAxes(_ axes: Axis.Set) -> some View { _gridCellModifier { $0.unsized = axes } }
    func _gridCellModifier(_ set: @escaping (_GridCellNode) -> Void) -> some View {
        _modify { ctx, c in
            let inner = _resolve(c, ctx.child("gc"))
            if let existing = inner as? _GridCellNode { set(existing); return existing }
            let n = _GridCellNode(path: ctx.path, child: inner); set(n); return n
        }
    }
}

final class _GridLayoutNode: _Node {
    let alignment: Alignment, hSpacing: CGFloat, vSpacing: CGFloat
    init(path: String, alignment: Alignment, hSpacing: CGFloat, vSpacing: CGFloat, child: _Node) {
        self.alignment = alignment; self.hSpacing = hSpacing; self.vSpacing = vSpacing
        super.init(path: path, children: [child])
    }
    /// rows: cells with their first column and span; nil cells = a full-width row
    struct Row { let node: _Node; let cells: [(node: _Node, col: Int, span: Int)]?; let alignment: VerticalAlignment? }
    var rows: [Row] {
        _flatten(children).map { n in
            guard let r = n as? _GridRowNode else { return Row(node: n, cells: nil, alignment: nil) }
            var col = 0
            let cells = r.cells.map { c -> (node: _Node, col: Int, span: Int) in
                let span = _gridCell(c)?.columns ?? 1
                defer { col += span }
                return (c, col, span)
            }
            return Row(node: r, cells: cells, alignment: r.alignment)
        }
    }
    var columnCount: Int { rows.compactMap { $0.cells.map { c in c.map { $0.col + $0.span }.max() ?? 0 } }.max() ?? 0 }
    static func flexible(_ n: _Node, _ axis: Axis) -> Bool {
        let big = n.sizeThatFits(axis == .horizontal ? _Proposal(width: 1e6, height: nil) : _Proposal(width: nil, height: 1e6))[axis]
        return big >= 5e5
    }
    func columnWidths(_ proposal: CGFloat?) -> [CGFloat] {
        let n = columnCount
        var widths = [CGFloat](repeating: 0, count: n)
        var flex = [Bool](repeating: false, count: n)
        let rs = rows
        for r in rs { for c in r.cells ?? [] where c.span == 1 {
            if _gridCell(c.node)?.unsized.contains(.horizontal) == true { continue }
            if _GridLayoutNode.flexible(c.node, .horizontal) { flex[c.col] = true; widths[c.col] = max(widths[c.col], c.node.sizeThatFits(_Proposal(width: 0, height: nil)).width) }
            else { widths[c.col] = max(widths[c.col], c.node.sizeThatFits(_Proposal(width: nil, height: nil)).width) }
        } }
        // spanning cells widen the columns they cover (evenly) when they need more room
        for r in rs { for c in r.cells ?? [] where c.span > 1 && c.col + c.span <= n {
            if _gridCell(c.node)?.unsized.contains(.horizontal) == true { continue }
            let need = c.node.sizeThatFits(_Proposal(width: nil, height: nil)).width
            let have = widths[c.col..<c.col + c.span].reduce(0, +) + hSpacing * CGFloat(c.span - 1)
            if need > have { for k in c.col..<c.col + c.span { widths[k] += (need - have) / CGFloat(c.span) } }
        } }
        if let p = proposal {
            let used = widths.reduce(0, +) + hSpacing * CGFloat(max(0, n - 1))
            let fcount = flex.filter { $0 }.count
            if fcount > 0, p > used { for k in 0..<n where flex[k] { widths[k] += (p - used) / CGFloat(fcount) } }
        }
        return widths
    }
    func cellWidth(_ widths: [CGFloat], _ col: Int, _ span: Int) -> CGFloat {
        let end = min(widths.count, col + span)
        return widths[col..<end].reduce(0, +) + hSpacing * CGFloat(max(0, end - col - 1))
    }
    func layout(_ p: _Proposal) -> (widths: [CGFloat], heights: [CGFloat], total: CGFloat) {
        let widths = columnWidths(p.width.map { min($0, 1e6) })
        var total = widths.reduce(0, +) + hSpacing * CGFloat(max(0, widths.count - 1))
        let heights = rows.map { r -> CGFloat in
            guard let cells = r.cells else {
                let s = r.node.sizeThatFits(_Proposal(width: p.width ?? total, height: nil))
                total = max(total, s.width)
                return s.height
            }
            return cells.map { c in
                _gridCell(c.node)?.unsized.contains(.vertical) == true ? 0 : c.node.sizeThatFits(_Proposal(width: cellWidth(widths, c.col, c.span), height: nil)).height
            }.max() ?? 0
        }
        return (widths, heights, total)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let (_, heights, total) = layout(p)
        return CGSize(width: total, height: heights.reduce(0, +) + vSpacing * CGFloat(max(0, heights.count - 1)))
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let (widths, heights, total) = layout(_Proposal(width: rect.width, height: rect.height))
        // column alignment: the first gridColumnAlignment in a column wins
        var colAlign = [HorizontalAlignment](repeating: alignment.horizontal, count: widths.count)
        var seen = Set<Int>()
        for r in rows { for c in r.cells ?? [] { if let a = _gridCell(c.node)?.columnAlignment, !seen.contains(c.col) { colAlign[c.col] = a; seen.insert(c.col) } } }
        var y: CGFloat = 0
        for (ri, r) in rows.enumerated() {
            let h = heights[ri]
            if let cells = r.cells {
                r.node.place(CGRect(x: 0, y: y, width: total, height: h))      // the row is transparent: cells relative to it
                for c in cells {
                    let x = (0..<c.col).reduce(CGFloat(0)) { $0 + widths[$1] + hSpacing }
                    let w = cellWidth(widths, c.col, c.span)
                    let info = _gridCell(c.node)
                    var s = c.node.sizeThatFits(_Proposal(width: w, height: h))
                    if info?.unsized.contains(.horizontal) == true { s.width = w }
                    if info?.unsized.contains(.vertical) == true { s.height = h }
                    s = CGSize(width: min(s.width, w), height: min(s.height, h))
                    let cellRect = CGRect(x: x, y: 0, width: w, height: h)
                    let f: CGRect
                    if let a = info?.anchor {
                        f = CGRect(x: cellRect.minX + (w - s.width) * a.x, y: (h - s.height) * a.y, width: s.width, height: s.height)
                    } else {
                        f = _align(s, in: cellRect, Alignment(horizontal: c.span == 1 ? colAlign[c.col] : alignment.horizontal, vertical: r.alignment ?? alignment.vertical))
                    }
                    c.node.place(f)
                }
            } else {
                let s = r.node.sizeThatFits(_Proposal(width: total, height: h))
                r.node.place(_align(CGSize(width: min(s.width, total), height: min(s.height, h)), in: CGRect(x: 0, y: y, width: total, height: h), Alignment(horizontal: alignment.horizontal, vertical: .center)))
            }
            y += h + vSpacing
        }
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        for (i, r) in rows.enumerated() {
            if let cells = r.cells {
                let rowView = g.view(r.node.viewKey) { _PassthroughView() }
                g.mountedKeys.insert(r.node.viewKey)
                if rowView.superview !== view { view.addSubview(rowView) }
                rowView.frame = r.node.frame
                for (k, c) in cells.enumerated() { g.mount(c.node, in: rowView, order: k) }
            } else { g.mount(r.node, in: view, order: i) }
        }
    }
}

// MARK: - LazyHGrid

/// Rows of items flowing top to bottom, then left to right (put it in a horizontal ScrollView).
public struct LazyHGrid<Content: View>: View, _PrimitiveView {
    let rows: [GridItem], alignment: VerticalAlignment, spacing: CGFloat?, content: Content
    public init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.rows = rows; self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _HGridNode(path: ctx.path, rows: rows, spacing: spacing ?? 8, child: _resolve(content, ctx.child("hgrid"))) }
}
final class _HGridNode: _Node {
    let rows: [GridItem], spacing: CGFloat
    init(path: String, rows: [GridItem], spacing: CGFloat, child: _Node) { self.rows = rows; self.spacing = spacing; super.init(path: path, children: [child]) }
    var items: [_Node] { _flatten(children) }
    /// Row heights from the GridItem sizes (fixed / flexible / adaptive), like LazyVGrid's columns.
    func rowHeights(_ height: CGFloat) -> [CGFloat] {
        var rs: [(GridItem.Size, CGFloat)] = []
        for r in rows {
            if case .adaptive(let mn, _) = r.size {
                let gap = r.spacing ?? spacing
                for _ in 0..<max(1, Int((height + gap) / (mn + gap))) { rs.append((.flexible(minimum: mn), gap)) }
            } else { rs.append((r.size, r.spacing ?? spacing)) }
        }
        let gaps = rs.dropLast().reduce(0) { $0 + $1.1 }
        var fixed: CGFloat = 0, flex = 0
        for (s, _) in rs { if case .fixed(let h) = s { fixed += h } else { flex += 1 } }
        let share = flex > 0 ? max(0, (height - gaps - fixed) / CGFloat(flex)) : 0
        return rs.map { s, _ in
            switch s {
            case .fixed(let h): return h
            case .flexible(let mn, let mx), .adaptive(let mn, let mx): return min(max(share, mn), mx)
            }
        }
    }
    func layout(_ height: CGFloat) -> (heights: [CGFloat], cols: [CGFloat]) {
        let heights = rowHeights(height)
        let n = max(1, heights.count)
        var cols: [CGFloat] = []
        for (i, it) in items.enumerated() {
            if i % n == 0 { cols.append(0) }
            cols[cols.count - 1] = max(cols[cols.count - 1], it.sizeThatFits(_Proposal(width: nil, height: heights[i % n])).width)
        }
        return (heights, cols)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let h = min(p.height ?? 300, 1e6)
        let (heights, cols) = layout(h)
        return CGSize(width: cols.reduce(0, +) + spacing * CGFloat(max(0, cols.count - 1)),
                      height: max(h, heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1))))
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let (heights, cols) = layout(rect.height)
        let n = max(1, heights.count)
        let totalH = heights.reduce(0, +) + spacing * CGFloat(max(0, n - 1))
        let y0 = max(0, (rect.height - totalH) / 2)
        var x: CGFloat = 0
        for (i, it) in items.enumerated() {
            let c = i / n, r = i % n
            if r == 0 && c > 0 { x += cols[c - 1] + spacing }
            let y = y0 + heights[..<r].reduce(0, +) + spacing * CGFloat(r)
            let s = it.sizeThatFits(_Proposal(width: cols[c], height: heights[r]))
            it.place(_align(CGSize(width: min(s.width, cols[c]), height: min(s.height, heights[r])), in: CGRect(x: x, y: y, width: cols[c], height: heights[r]), .center))
        }
    }
    override func mountChildren(_ g: _Graph, in view: UIView) { for (i, c) in items.enumerated() { g.mount(c, in: view, order: i) } }
}

// MARK: - ViewThatFits

/// Shows the first child whose ideal size fits the proposal on the given axes (else the last one).
public struct ViewThatFits<Content: View>: View, _PrimitiveView {
    let axes: Axis.Set, content: Content
    public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content) { self.axes = axes; self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ViewThatFitsNode(path: ctx.path, axes: axes, children: _flatten([_resolve(content, ctx.child("vtf"))])) }
}
final class _ViewThatFitsNode: _Node {
    let axes: Axis.Set
    var chosen = 0
    init(path: String, axes: Axis.Set, children: [_Node]) { self.axes = axes; super.init(path: path, children: children) }
    func choose(_ p: _Proposal) -> Int {
        for (i, c) in children.enumerated() {
            let ideal = c.sizeThatFits(_Proposal(width: axes.contains(.horizontal) ? nil : p.width, height: axes.contains(.vertical) ? nil : p.height))
            let fitsW = !axes.contains(.horizontal) || p.width == nil || ideal.width <= p.width! + 0.5
            let fitsH = !axes.contains(.vertical) || p.height == nil || ideal.height <= p.height! + 0.5
            if fitsW && fitsH { return i }
        }
        return max(0, children.count - 1)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        guard !children.isEmpty else { return .zero }
        return children[choose(p)].sizeThatFits(p)
    }
    override func place(_ rect: CGRect) {
        frame = rect
        guard !children.isEmpty else { return }
        chosen = choose(_Proposal(width: rect.width, height: rect.height))
        let c = children[chosen]
        let s = c.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        c.place(_align(CGSize(width: min(s.width, rect.width), height: min(s.height, rect.height)), in: CGRect(origin: .zero, size: rect.size), .center))
    }
    override func mountChildren(_ g: _Graph, in view: UIView) { if chosen < children.count { g.mount(children[chosen], in: view, order: 0) } }
}
