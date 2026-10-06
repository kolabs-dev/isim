// isim GameplayKit: spatial partitioning — GKQuadtree (2D), GKOctree (3D) and GKRTree (2D bounding rectangles,
// Guttman's R-tree with half / linear / quadratic node splits).
import Foundation

public struct GKQuad: Sendable {
    public var quadMin: vector_float2
    public var quadMax: vector_float2
    public init() { quadMin = .zero; quadMax = .zero }
    public init(quadMin: vector_float2, quadMax: vector_float2) { self.quadMin = quadMin; self.quadMax = quadMax }
}
public struct GKBox: Sendable {
    public var boxMin: vector_float3
    public var boxMax: vector_float3
    public init() { boxMin = .zero; boxMax = .zero }
    public init(boxMin: vector_float3, boxMax: vector_float3) { self.boxMin = boxMin; self.boxMax = boxMax }
}

/// A cell of a quadtree / octree (2^dims children), holding elements whose bounds fit in it but not in one child.
final class _GKCell<V: SIMD> where V.Scalar == Float {
    let lo: V, hi: V
    var children: [_GKCell]?
    var items: [(AnyObject, V, V)] = []
    weak var parent: _GKCell?
    init(_ lo: V, _ hi: V, _ parent: _GKCell?) { self.lo = lo; self.hi = hi; self.parent = parent }

    func contains(_ a: V, _ b: V) -> Bool {
        for i in 0..<V.scalarCount where a[i] < lo[i] || b[i] > hi[i] { return false }
        return true
    }
    func intersects(_ a: V, _ b: V) -> Bool {
        for i in 0..<V.scalarCount where b[i] < lo[i] || a[i] > hi[i] { return false }
        return true
    }
    func split() -> [_GKCell] {
        if let c = children { return c }
        let mid = (lo + hi) / 2
        var out: [_GKCell] = []
        for k in 0..<(1 << V.scalarCount) {
            var l = lo, h = hi
            for i in 0..<V.scalarCount { if k & (1 << i) != 0 { l[i] = mid[i] } else { h[i] = mid[i] } }
            out.append(_GKCell(l, h, self))
        }
        children = out
        return out
    }
    /// the deepest cell (at least `minSize` per side) that holds [a, b]
    func insert(_ e: AnyObject, _ a: V, _ b: V, minSize: Float) -> _GKCell {
        var cell = self
        while true {
            let half = (cell.hi - cell.lo) / 2
            var big = true
            for i in 0..<V.scalarCount where half[i] < minSize { big = false }
            guard big, let next = cell.split().first(where: { $0.contains(a, b) }) else { break }
            cell = next
        }
        cell.items.append((e, a, b))
        return cell
    }
    func collect(_ a: V, _ b: V, into out: inout [AnyObject]) {
        guard intersects(a, b) else { return }
        for (e, ia, ib) in items {
            var hit = true
            for i in 0..<V.scalarCount where ib[i] < a[i] || ia[i] > b[i] { hit = false }
            if hit { out.append(e) }
        }
        for c in children ?? [] { c.collect(a, b, into: &out) }
    }
    /// elements stored in the cells that contain the point (from the root down to the deepest one)
    func cellElements(at p: V, into out: inout [AnyObject]) {
        guard contains(p, p) else { return }
        out += items.map(\.0)
        for c in children ?? [] where c.contains(p, p) { c.cellElements(at: p, into: &out); break }
    }
    /// the same object, or an equal one (isEqual:)
    static func same(_ a: AnyObject, _ b: AnyObject) -> Bool { a === b || (a as? NSObject)?.isEqual(b) == true }
    func remove(_ e: AnyObject) -> Bool {
        if let i = items.firstIndex(where: { _GKCell.same($0.0, e) }) { items.remove(at: i); return true }
        for c in children ?? [] where c.remove(e) { return true }
        return false
    }
    func removeHere(_ e: AnyObject) -> Bool {
        if let i = items.firstIndex(where: { _GKCell.same($0.0, e) }) { items.remove(at: i); return true }
        return false
    }
}

// MARK: - Quadtree

open class GKQuadtreeNode: NSObject {
    let cell: _GKCell<vector_float2>
    init(_ c: _GKCell<vector_float2>) { cell = c; super.init() }
    open var quad: GKQuad { GKQuad(quadMin: cell.lo, quadMax: cell.hi) }
}

open class GKQuadtree<ElementType: NSObject>: NSObject {
    let root: _GKCell<vector_float2>
    let minCell: Float
    public init(boundingQuad quad: GKQuad, minimumCellSize minCellSize: Float) {
        root = _GKCell(simd_min(quad.quadMin, quad.quadMax), simd_max(quad.quadMin, quad.quadMax), nil)
        minCell = max(minCellSize, 1e-6)
        super.init()
    }
    @discardableResult open func add(_ element: ElementType, at point: vector_float2) -> GKQuadtreeNode {
        GKQuadtreeNode(root.insert(element, point, point, minSize: minCell))
    }
    @discardableResult open func add(_ element: ElementType, in quad: GKQuad) -> GKQuadtreeNode {
        GKQuadtreeNode(root.insert(element, simd_min(quad.quadMin, quad.quadMax), simd_max(quad.quadMin, quad.quadMax), minSize: minCell))
    }
    /// the elements of the cells containing the point
    open func elements(at point: vector_float2) -> [ElementType] {
        var out: [AnyObject] = []
        root.cellElements(at: point, into: &out)
        return out.compactMap { $0 as? ElementType }
    }
    /// the elements whose point or quad overlaps the quad
    open func elements(in quad: GKQuad) -> [ElementType] {
        var out: [AnyObject] = []
        root.collect(simd_min(quad.quadMin, quad.quadMax), simd_max(quad.quadMin, quad.quadMax), into: &out)
        return out.compactMap { $0 as? ElementType }
    }
    @discardableResult open func remove(_ element: ElementType) -> Bool { root.remove(element) }
    @discardableResult open func remove(_ data: ElementType, using node: GKQuadtreeNode) -> Bool { node.cell.removeHere(data) }
}

// MARK: - Octree

open class GKOctreeNode: NSObject {
    let cell: _GKCell<vector_float3>
    init(_ c: _GKCell<vector_float3>) { cell = c; super.init() }
    open var box: GKBox { GKBox(boxMin: cell.lo, boxMax: cell.hi) }
}

open class GKOctree<ElementType: NSObject>: NSObject {
    let root: _GKCell<vector_float3>
    let minCell: Float
    public init(boundingBox box: GKBox, minimumCellSize minCellSize: Float) {
        root = _GKCell(simd_min(box.boxMin, box.boxMax), simd_max(box.boxMin, box.boxMax), nil)
        minCell = max(minCellSize, 1e-6)
        super.init()
    }
    @discardableResult open func add(_ element: ElementType, at point: vector_float3) -> GKOctreeNode {
        GKOctreeNode(root.insert(element, point, point, minSize: minCell))
    }
    @discardableResult open func add(_ element: ElementType, in box: GKBox) -> GKOctreeNode {
        GKOctreeNode(root.insert(element, simd_min(box.boxMin, box.boxMax), simd_max(box.boxMin, box.boxMax), minSize: minCell))
    }
    open func elements(at point: vector_float3) -> [ElementType] {
        var out: [AnyObject] = []
        root.cellElements(at: point, into: &out)
        return out.compactMap { $0 as? ElementType }
    }
    open func elements(in box: GKBox) -> [ElementType] {
        var out: [AnyObject] = []
        root.collect(simd_min(box.boxMin, box.boxMax), simd_max(box.boxMin, box.boxMax), into: &out)
        return out.compactMap { $0 as? ElementType }
    }
    @discardableResult open func remove(_ element: ElementType) -> Bool { root.remove(element) }
    @discardableResult open func remove(_ data: ElementType, using node: GKOctreeNode) -> Bool { node.cell.removeHere(data) }
}

// MARK: - R-tree

public enum GKRTreeSplitStrategy: Int, Sendable { case halfSplit = 0, linearSplit = 1, quadraticSplit = 2, reduceOverlap = 3 }

struct _GKRect {
    var lo: vector_float2, hi: vector_float2
    var area: Float { max(0, hi.x - lo.x) * max(0, hi.y - lo.y) }
    func union(_ o: _GKRect) -> _GKRect { _GKRect(lo: simd_min(lo, o.lo), hi: simd_max(hi, o.hi)) }
    func intersects(_ o: _GKRect) -> Bool { !(o.hi.x < lo.x || o.lo.x > hi.x || o.hi.y < lo.y || o.lo.y > hi.y) }
    func overlap(_ o: _GKRect) -> Float {
        max(0, min(hi.x, o.hi.x) - max(lo.x, o.lo.x)) * max(0, min(hi.y, o.hi.y) - max(lo.y, o.lo.y))
    }
}

final class _GKRNode {
    var leaf: Bool
    var rects: [_GKRect] = []
    var kids: [_GKRNode] = []          // inner nodes
    var items: [AnyObject] = []        // leaves
    init(leaf: Bool) { self.leaf = leaf }
    var count: Int { leaf ? items.count : kids.count }
    var bounds: _GKRect { rects.dropFirst().reduce(rects[0]) { $0.union($1) } }
}

/// Elements with bounding rectangles; queries return the elements whose rectangles overlap the query rectangle.
open class GKRTree<ElementType: AnyObject>: NSObject {
    let maxChildren: Int
    var root = _GKRNode(leaf: true)
    /// expected result count of a query (capacity hint)
    open var queryReserve = 0

    public init(maxNumberOfChildren: Int) { maxChildren = max(2, maxNumberOfChildren); super.init() }

    open func addElement(_ element: ElementType, boundingRectMin: vector_float2, boundingRectMax: vector_float2, splitStrategy: GKRTreeSplitStrategy) {
        let r = _GKRect(lo: simd_min(boundingRectMin, boundingRectMax), hi: simd_max(boundingRectMin, boundingRectMax))
        if let (a, b) = insert(root, element, r, splitStrategy) {
            let newRoot = _GKRNode(leaf: false)
            newRoot.kids = [a, b]; newRoot.rects = [a.bounds, b.bounds]
            root = newRoot
        }
    }
    /// inserts below `n`; returns the two halves if `n` had to split
    func insert(_ n: _GKRNode, _ e: AnyObject, _ r: _GKRect, _ s: GKRTreeSplitStrategy) -> (_GKRNode, _GKRNode)? {
        if n.leaf {
            n.items.append(e); n.rects.append(r)
        } else {
            // the child that grows least (then the smaller one)
            var best = 0, bestGrow = Float.infinity, bestArea = Float.infinity
            for (i, cr) in n.rects.enumerated() {
                let grow = cr.union(r).area - cr.area
                if grow < bestGrow || (grow == bestGrow && cr.area < bestArea) { best = i; bestGrow = grow; bestArea = cr.area }
            }
            if let (a, b) = insert(n.kids[best], e, r, s) {
                n.kids[best] = a; n.rects[best] = a.bounds
                n.kids.append(b); n.rects.append(b.bounds)
            } else {
                n.rects[best] = n.rects[best].union(r)
            }
        }
        return n.count > maxChildren ? split(n, s) : nil
    }

    func split(_ n: _GKRNode, _ s: GKRTreeSplitStrategy) -> (_GKRNode, _GKRNode) {
        let count = n.count
        var groupA: [Int] = [], groupB: [Int] = []
        let minFill = max(1, maxChildren / 2 - (maxChildren % 2 == 0 ? 1 : 0))
        switch s {
        case .halfSplit:
            // sorted along the axis where the entries spread most, cut in half
            let b = n.bounds
            let axis = (b.hi.x - b.lo.x) >= (b.hi.y - b.lo.y) ? 0 : 1
            let order = (0..<count).sorted { (n.rects[$0].lo[axis] + n.rects[$0].hi[axis]) < (n.rects[$1].lo[axis] + n.rects[$1].hi[axis]) }
            groupA = Array(order[..<(count / 2)]); groupB = Array(order[(count / 2)...])
        case .linearSplit, .quadraticSplit, .reduceOverlap:
            var seeds = (0, 1)
            if s == .linearSplit {
                // the pair with the greatest normalized separation along x or y
                var bestSep = -Float.infinity
                let b = n.bounds
                for axis in 0..<2 {
                    let width = max(1e-9, b.hi[axis] - b.lo[axis])
                    let hiLow = (0..<count).max { n.rects[$0].lo[axis] < n.rects[$1].lo[axis] }!
                    let loHigh = (0..<count).min { n.rects[$0].hi[axis] < n.rects[$1].hi[axis] }!
                    let sep = (n.rects[hiLow].lo[axis] - n.rects[loHigh].hi[axis]) / width
                    if hiLow != loHigh && sep > bestSep { bestSep = sep; seeds = (loHigh, hiLow) }
                }
            } else {
                // the pair that wastes most area together
                var worst = -Float.infinity
                for i in 0..<count { for j in (i + 1)..<count {
                    let d = n.rects[i].union(n.rects[j]).area - n.rects[i].area - n.rects[j].area
                    if d > worst { worst = d; seeds = (i, j) }
                } }
            }
            groupA = [seeds.0]; groupB = [seeds.1]
            var ra = n.rects[seeds.0], rb = n.rects[seeds.1]
            var rest = (0..<count).filter { $0 != seeds.0 && $0 != seeds.1 }
            while !rest.isEmpty {
                if groupA.count + rest.count <= minFill { groupA += rest; break }
                if groupB.count + rest.count <= minFill { groupB += rest; break }
                // quadratic: the entry with the strongest preference next; linear: in order
                var pick = 0
                if s != .linearSplit {
                    var bestDiff = -Float.infinity
                    for (k, i) in rest.enumerated() {
                        let diff = abs((ra.union(n.rects[i]).area - ra.area) - (rb.union(n.rects[i]).area - rb.area))
                        if diff > bestDiff { bestDiff = diff; pick = k }
                    }
                }
                let i = rest.remove(at: pick)
                let ga = ra.union(n.rects[i]).area - ra.area, gb = rb.union(n.rects[i]).area - rb.area
                var toA = ga < gb || (ga == gb && (ra.area < rb.area || (ra.area == rb.area && groupA.count <= groupB.count)))
                if s == .reduceOverlap { toA = ra.union(n.rects[i]).overlap(rb) < rb.union(n.rects[i]).overlap(ra) || (toA && ra.union(n.rects[i]).overlap(rb) == rb.union(n.rects[i]).overlap(ra)) }
                if toA { groupA.append(i); ra = ra.union(n.rects[i]) } else { groupB.append(i); rb = rb.union(n.rects[i]) }
            }
        }
        func make(_ idx: [Int]) -> _GKRNode {
            let m = _GKRNode(leaf: n.leaf)
            m.rects = idx.map { n.rects[$0] }
            if n.leaf { m.items = idx.map { n.items[$0] } } else { m.kids = idx.map { n.kids[$0] } }
            return m
        }
        return (make(groupA), make(groupB))
    }

    open func removeElement(_ element: ElementType, boundingRectMin: vector_float2, boundingRectMax: vector_float2) {
        let r = _GKRect(lo: simd_min(boundingRectMin, boundingRectMax), hi: simd_max(boundingRectMin, boundingRectMax))
        _ = remove(root, element, r)
        while !root.leaf && root.kids.count == 1 { root = root.kids[0] }
        if !root.leaf && root.kids.isEmpty { root = _GKRNode(leaf: true) }
    }
    /// removes the element below `n` (empty children are dropped, rectangles shrink); true if found
    func remove(_ n: _GKRNode, _ e: AnyObject, _ r: _GKRect) -> Bool {
        if n.leaf {
            guard let i = n.items.firstIndex(where: { $0 === e }) else { return false }
            n.items.remove(at: i); n.rects.remove(at: i)
            return true
        }
        for i in n.kids.indices where n.rects[i].intersects(r) {
            if remove(n.kids[i], e, r) {
                if n.kids[i].count == 0 { n.kids.remove(at: i); n.rects.remove(at: i) } else { n.rects[i] = n.kids[i].bounds }
                return true
            }
        }
        return false
    }

    open func elements(inBoundingRectMin rectMin: vector_float2, rectMax: vector_float2) -> [ElementType] {
        let q = _GKRect(lo: simd_min(rectMin, rectMax), hi: simd_max(rectMin, rectMax))
        var out: [ElementType] = []
        out.reserveCapacity(queryReserve)
        func walk(_ n: _GKRNode) {
            for i in 0..<n.count where n.rects[i].intersects(q) {
                if n.leaf { if let e = n.items[i] as? ElementType { out.append(e) } } else { walk(n.kids[i]) }
            }
        }
        walk(root)
        return out
    }
    /// tree height (1: only a leaf); for diagnostics
    var _depth: Int { var d = 1, n = root; while !n.leaf { d += 1; n = n.kids[0] }; return d }
}
