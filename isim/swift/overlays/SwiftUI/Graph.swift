// isim SwiftUI: evaluation graph, layout nodes and UIKit rendering.
import UIKit

// MARK: - Proposals

struct _Proposal {
    var width: CGFloat?
    var height: CGFloat?
    static let unspecified = _Proposal(width: nil, height: nil)
    func inset(_ e: EdgeInsets) -> _Proposal {
        _Proposal(width: width.map { max(0, $0 - e.leading - e.trailing) }, height: height.map { max(0, $0 - e.top - e.bottom) })
    }
    subscript(axis: Axis) -> CGFloat? { axis == .horizontal ? width : height }
}
extension CGSize { subscript(axis: Axis) -> CGFloat { axis == .horizontal ? width : height } }

// MARK: - Graph

@MainActor final class _Graph {
    var storage: [String: AnyObject] = [:]
    var usedKeys: Set<String> = []
    var views: [String: UIView] = [:]
    var mountedKeys: Set<String> = []
    weak var hostView: UIView?
    let root: () -> any View
    var evaluations = 0
    var safeArea = UIEdgeInsets.zero
    var keyboardHeight: CGFloat = 0
    var postRender: [() -> Void] = []
    var changeValues: [String: Any] = [:]
    var usedChanges: Set<String> = []
    var tasks: [String: Task<Void, Never>] = [:]
    var usedTasks: Set<String> = []
    var appeared: Set<String> = []
    var usedAppear: Set<String> = []
    var disappearActions: [String: () -> Void] = [:]
    var rendering = false, pending = false
    var urlHandlers: [String: (URL) -> Void] = [:]
    var urlObserver: NSObjectProtocol?
    var pendingURLs: [URL] = []
    func installURLObserver() {
        if urlObserver == nil {
            urlObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimOpenURL"), object: nil, queue: nil, using: { [weak self] (n: NSNotification) in
                guard let url = n.object as? NSURL else { return }
                let u = url as URL
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    if self.urlHandlers.isEmpty { self.pendingURLs.append(u) } else { for h in self.urlHandlers.values { h(u) } }
                }
            })
        }
    }
    func registerURLHandler(_ path: String, _ h: @escaping (URL) -> Void) {
        urlHandlers[path] = h
        if !pendingURLs.isEmpty { let urls = pendingURLs; pendingURLs = []; postRender.append { for u in urls { h(u) } } }
    }
    var subscriptions: [String: (id: ObjectIdentifier, c: AnyCancellable)] = [:]
    var usedSubscriptions: Set<String> = []
    var receiveActions: [String: AnyObject] = [:]
    var idViews: [String: UIView] = [:]
    var appObservers: [NSObjectProtocol] = []
    func installAppObservers() {
        // scenePhase follows the application state
        let names = [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification,
                     UIApplication.didEnterBackgroundNotification, UIApplication.willEnterForegroundNotification]
        for n in names {
            appObservers.append(NotificationCenter.default.addObserver(forName: n, object: nil, queue: nil, using: { [weak self] (_: NSNotification) in
                MainActor.assumeIsolated { self?.invalidate() }
            }))
        }
    }
    // animation bookkeeping (Animation.swift)
    var transitions: [String: AnyTransition] = [:]         // view key -> its .transition (for removal)
    var fresh: Set<ObjectIdentifier> = []                   // views created during this render
    var mountedViews: Set<ObjectIdentifier> = []
    var matchedFrames: [String: CGRect] = [:]               // matchedGeometryEffect id -> window frame (last render)
    var newMatched: [String: CGRect] = [:]
    var matchedKeys: [String: String] = [:]                 // view key -> matched id
    var appStorageObserver: NSObjectProtocol?                 // @AppStorage: re-render when a key changes
    var focusLinks: [(String, _FocusLink)] = []
    var submitActions: [String: () -> Void] = [:]
    /// innermost .focused() applied at or above a path
    func focusLink(for path: String) -> _FocusLink? {
        focusLinks.filter { path.hasPrefix($0.0) }.max { $0.0.count < $1.0.count }?.1
    }
    func submitAction(for path: String) -> (() -> Void)? {
        submitActions.filter { path.hasPrefix($0.key) }.max { $0.key.count < $1.key.count }?.value
    }

    init(root: @escaping () -> any View) { self.root = root; installURLObserver(); installAppObservers() }

    /// Callable from any context (bindings, UIKit callbacks); state changes happen on the main thread.
    nonisolated func invalidate() {
        guard Thread.isMainThread else {
            Task { @MainActor [weak self] in self?.invalidate() }    // state changed off the main thread
            return
        }
        MainActor.assumeIsolated {
            if rendering { pending = true; return }
            hostView?.setNeedsLayout()
        }
    }

    func render(bounds: CGRect, safeArea: UIEdgeInsets, traits: UITraitCollection) {
        rendering = true
        defer { rendering = false }
        self.safeArea = safeArea
        usedKeys = []; mountedKeys = []; usedChanges = []; usedTasks = []; usedAppear = []; postRender = []; focusLinks = []; submitActions = [:]; urlHandlers = [:]
        usedSubscriptions = []; idViews = [:]
        var env = EnvironmentValues()
        env.colorScheme = traits.userInterfaceStyle == .dark ? .dark : .light
        _systemEnvironment(&env, traits: traits)
        let ctx = _Context(graph: self, path: "root", environment: env, nav: nil)
        // @Observable: properties read while the views evaluate are tracked; a change re-renders
        var resolved: _Node?
        withObservationTracking { resolved = _resolve(root(), ctx) } onChange: { [weak self] in self?.invalidate() }
        let node = resolved!
        // layout: content that does not manage the safe area itself stays inside it
        let area = node.ignoresSafeArea ? bounds : bounds.inset(by: safeArea)
        let size = node.sizeThatFits(_Proposal(width: area.width, height: area.height))
        let origin = CGPoint(x: area.minX + (area.width - min(size.width, area.width)) / 2,
                             y: node.ignoresSafeArea ? area.minY : area.minY + (area.height - min(size.height, area.height)) / 2)
        node.place(CGRect(origin: origin, size: node.ignoresSafeArea ? area.size : size))
        extendIntoSafeArea(node, offset: .zero, safe: bounds.inset(by: safeArea), bounds: bounds)
        fresh = []; mountedViews = []; newMatched = [:]
        let oldTransitions = transitions, oldMatchedKeys = matchedKeys
        transitions = [:]; matchedKeys = [:]
        let update = {
            if let host = self.hostView { self.mount(node, in: host, order: 0) }
            self.unmountGone(oldTransitions, oldMatchedKeys)
        }
        if let anim = _AnimationContext.take(), hostView?.window != nil { anim._run(update) } else { update() }
        matchedFrames = newMatched
        storage = storage.filter { usedKeys.contains($0.key) }
        changeValues = changeValues.filter { usedChanges.contains($0.key) }
        for (k, t) in tasks where !usedTasks.contains(k) { t.cancel(); tasks[k] = nil }
        for k in subscriptions.keys where !usedSubscriptions.contains(k) { subscriptions[k] = nil; receiveActions[k] = nil }
        for k in appeared where !usedAppear.contains(k) { appeared.remove(k); disappearActions.removeValue(forKey: k)?() }
        let work = postRender
        postRender = []
        for w in work { w() }
        if pending { pending = false; hostView?.setNeedsLayout() }
    }

    /// .ignoresSafeArea(): a view that reaches a safe-area edge grows to the screen edge (like SwiftUI).
    func extendIntoSafeArea(_ n: _Node, offset: CGPoint, safe: CGRect, bounds: CGRect) {
        let abs = n.frame.offsetBy(dx: offset.x, dy: offset.y)
        if let i = n as? _IgnoreSafeAreaNode {
            var f = abs
            let e = i.edges, eps: CGFloat = 0.5
            if e.contains(.top), f.minY <= safe.minY + eps, f.minY > bounds.minY { f.size.height += f.minY - bounds.minY; f.origin.y = bounds.minY }
            if e.contains(.bottom), f.maxY >= safe.maxY - eps, f.maxY < bounds.maxY { f.size.height = bounds.maxY - f.minY }
            if e.contains(.leading), f.minX <= safe.minX + eps, f.minX > bounds.minX { f.size.width += f.minX - bounds.minX; f.origin.x = bounds.minX }
            if e.contains(.trailing), f.maxX >= safe.maxX - eps, f.maxX < bounds.maxX { f.size.width = bounds.maxX - f.minX }
            if f != abs {
                n.frame = f.offsetBy(dx: -offset.x, dy: -offset.y)
                n.children[0].place(CGRect(origin: .zero, size: f.size))
            }
            return
        }
        // stacks and other containers splice group children with container-relative frames
        let base = n.transparent ? offset : CGPoint(x: abs.minX, y: abs.minY)
        for c in n.children { extendIntoSafeArea(c, offset: base, safe: safe, bounds: bounds) }
    }

    /// Reuses the UIKit view for a node position (same class), or creates it.
    func view<T: UIView>(_ key: String, _ make: () -> T) -> T {
        mountedKeys.insert(key)
        if let v = views[key] as? T { return v }
        views[key]?.removeFromSuperview()
        let v = make()
        views[key] = v
        fresh.insert(ObjectIdentifier(v))
        return v
    }

    /// Views of nodes that went away. In an animated update the outermost ones play their removal
    /// transition (default: fade out) and leave afterwards, together with their subviews.
    func unmountGone(_ oldTransitions: [String: AnyTransition], _ oldMatchedKeys: [String: String]) {
        let gone = views.filter { !mountedKeys.contains($0.key) }
        for k in gone.keys { views[k] = nil }
        let animating = UIView.inheritedAnimationDuration > 0
        var leaving: [UIView] = []
        for (k, v) in gone {
            guard let sup = v.superview, mountedViews.contains(ObjectIdentifier(sup)) || sup === hostView else { continue }
            if let m = oldMatchedKeys[k], newMatched[m] != nil { continue }          // its match took over
            let t = oldTransitions[k]
            guard animating || t?.animation != nil else { continue }
            if case .identity? = t?.kind { continue }
            v.isUserInteractionEnabled = false
            let container = sup.bounds
            let out = { v.frame = AnyTransition.apply(t?.kind ?? .opacity, insertion: false, to: v, frame: v.frame, container: container) }
            if let a = t?.animation { a._run(out, completion: { v.removeFromSuperview() }) }
            else {
                out()
                let d = UIView.inheritedAnimationDuration
                DispatchQueue.main.asyncAfter(deadline: .now() + d + 0.05) { v.removeFromSuperview() }
            }
            leaving.append(v)
        }
        for (_, v) in gone where !leaving.contains(where: { v === $0 || v.isDescendant(of: $0) }) { v.removeFromSuperview() }
    }

    /// Mounts a node (and its subtree) as a subview of `parent` at `frame` (node.frame is parent-relative).
    func mount(_ node: _Node, in parent: UIView, order: Int) {
        if node is _GroupNode && !(node.children.isEmpty) && node.transparent {
            for c in node.children { mount(c, in: parent, order: order) }
            return
        }
        let v = node.mountView(self)
        mountedViews.insert(ObjectIdentifier(v))
        if v.superview !== parent { parent.addSubview(v) } else { parent.bringSubviewToFront(v) }
        if fresh.contains(ObjectIdentifier(v)) {
            // a new view: no animation from its initial (zero) state; the outermost new view plays its transition
            v._isim_removeAllAnimations()
            let matched = (node as? _MatchedNode).flatMap { matchedFrames[$0.matchKey] }.map { parent.convert($0, from: nil) }
            let t = (node as? _TransitionNode)?.transition
            if !fresh.contains(ObjectIdentifier(parent)), UIView.inheritedAnimationDuration > 0 || t?.animation != nil {
                let alpha = v.alpha, transform = v.transform
                var skip = false
                UIView.performWithoutAnimation {
                    if let matched { v.frame = matched }
                    else if case .identity? = t?.kind { v.frame = node.frame; skip = true }
                    else { v.frame = AnyTransition.apply(t?.kind ?? .opacity, insertion: true, to: v, frame: node.frame, container: parent.bounds) }
                }
                if !skip {
                    let settle = { v.frame = node.frame; v.alpha = alpha; v.transform = transform }
                    if let a = t?.animation { a._run(settle) } else { settle() }
                }
            } else {
                UIView.performWithoutAnimation { v.frame = node.frame }
            }
        } else if v.frame != node.frame { v.frame = node.frame }
        if let m = node as? _MatchedNode {
            matchedKeys[m.viewKey] = m.matchKey
            if v.window != nil { newMatched[m.matchKey] = parent.convert(node.frame, to: nil) }
        }
        if let id = node.accessibilityIdentifier { v.accessibilityIdentifier = id }
        if let label = node.accessibilityLabel { v.accessibilityLabel = label }
        node.mountChildren(self, in: v)
    }
}

// MARK: - Nodes

@MainActor class _Node {
    let path: String
    var children: [_Node]
    var frame: CGRect = .zero
    var accessibilityIdentifier: String?
    var accessibilityLabel: String?
    /// .tag(_:) (or ForEach's id): the value Picker and TabView select by
    var tag: AnyHashable?
    /// .tabItem { } content and .badge
    var tabItem: _Node?
    var badge: String?
    /// action when this node is a whole list row (Button, NavigationLink, Link)
    var rowAction: (() -> Void)?
    var rowAccessory: String? { children.count == 1 ? children[0].rowAccessory : nil }
    var transparent: Bool { false }
    var ignoresSafeArea: Bool { children.count == 1 ? children[0].ignoresSafeArea : false }
    /// Spacer-like flexibility along a stack axis
    var isSpacer: Bool { false }
    var layoutPriority: Double { children.count == 1 ? children[0].layoutPriority : 0 }

    init(path: String, children: [_Node]) {
        self.path = path; self.children = children
        if children.count == 1 { rowAction = children[0].rowAction }
    }
    /// Default: a container sized like its (single) content; children overlap.
    func sizeThatFits(_ p: _Proposal) -> CGSize {
        var s = CGSize.zero
        for c in children { let cs = c.sizeThatFits(p); s.width = max(s.width, cs.width); s.height = max(s.height, cs.height) }
        return s
    }
    func place(_ rect: CGRect) {
        frame = rect
        for c in children {
            let cs = c.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
            c.place(CGRect(x: (rect.width - cs.width) / 2, y: (rect.height - cs.height) / 2, width: cs.width, height: cs.height))
        }
    }
    var viewKey: String { path + "|" + String(describing: type(of: self)) }
    func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
    func mountChildren(_ g: _Graph, in view: UIView) {
        for (i, c) in children.enumerated() { g.mount(c, in: view, order: i) }
    }
}

/// A plain container that does not intercept touches outside its children.
final class _PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        return v === self ? nil : v
    }
}

/// Several views without a container of their own (TupleView, Group, ForEach, conditionals).
/// Stacks splice their children in; elsewhere they lay out like a VStack.
final class _GroupNode: _Node {
    override var transparent: Bool { true }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { _stackSize(children, axis: .vertical, spacing: 8, p) }
    override func place(_ rect: CGRect) {
        frame = rect
        _stackPlace(children, axis: .vertical, spacing: 8, alignment: .center, in: CGRect(origin: rect.origin, size: rect.size), relative: false)
    }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
}

@MainActor func _flatten(_ nodes: [_Node]) -> [_Node] {
    var out: [_Node] = []
    for n in nodes { if n is _GroupNode { out += _flatten(n.children) } else { out.append(n) } }
    return out
}

// MARK: - Stack layout (proposal-based, flexibility-ordered like SwiftUI)

@MainActor func _stackSizes(_ nodes: [_Node], axis: Axis, spacing: CGFloat, _ p: _Proposal) -> [CGSize] {
    let n = nodes.count
    if n == 0 { return [] }
    let gaps = spacing * CGFloat(n - 1)
    // spacers take space only along the stack axis
    func spacerSize(_ s: _SpacerNode, _ main: CGFloat?) -> CGSize {
        let m = max(s.minLength, main ?? s.minLength)
        return axis == .vertical ? CGSize(width: 0, height: m) : CGSize(width: m, height: 0)
    }
    func measure(_ node: _Node, _ q: _Proposal) -> CGSize {
        if let sp = node as? _SpacerNode { return spacerSize(sp, q[axis]) }
        return node.sizeThatFits(q)
    }
    guard let total = p[axis] else {
        return nodes.map { measure($0, axis == .vertical ? _Proposal(width: p.width, height: nil) : _Proposal(width: nil, height: p.height)) }
    }
    // flexibility = max - min along the axis; least flexible first, higher layout priority first
    func prop(_ v: CGFloat) -> _Proposal { axis == .vertical ? _Proposal(width: p.width, height: v) : _Proposal(width: v, height: p.height) }
    let flex = nodes.map { $0.isSpacer ? CGFloat.infinity : min($0.sizeThatFits(prop(1e6))[axis], 1e6) - $0.sizeThatFits(prop(0))[axis] }
    // like SwiftUI: spacers reserve their minimum length and take what the other views leave;
    // the other views are offered an equal share of the rest, least flexible first
    let spacerIdx = (0..<n).filter { nodes[$0].isSpacer }
    let spacerMin = spacerIdx.reduce(CGFloat(0)) { $0 + ((nodes[$1] as? _SpacerNode)?.minLength ?? 8) }
    var order = (0..<n).filter { !nodes[$0].isSpacer }
    order.sort { (nodes[$0].layoutPriority, -flex[$0]) > (nodes[$1].layoutPriority, -flex[$1]) }
    var remaining = max(0, total - gaps - spacerMin)
    var sizes = [CGSize](repeating: .zero, count: n)
    var left = order.count
    for i in order {
        let share = remaining / CGFloat(left)
        let s = measure(nodes[i], prop(share))
        sizes[i] = s
        remaining = max(0, remaining - s[axis])
        left -= 1
    }
    remaining += spacerMin
    for (k, i) in spacerIdx.enumerated() {
        let share = remaining / CGFloat(spacerIdx.count - k)
        let s = measure(nodes[i], prop(share))
        sizes[i] = s
        remaining = max(0, remaining - s[axis])
    }
    return sizes
}
@MainActor func _stackSize(_ children: [_Node], axis: Axis, spacing: CGFloat, _ p: _Proposal) -> CGSize {
    let nodes = _flatten(children)
    let sizes = _stackSizes(nodes, axis: axis, spacing: spacing, p)
    let main = sizes.reduce(0) { $0 + $1[axis] } + spacing * CGFloat(max(0, nodes.count - 1))
    let cross = sizes.map { $0[axis == .vertical ? .horizontal : .vertical] }.max() ?? 0
    return axis == .vertical ? CGSize(width: cross, height: main) : CGSize(width: main, height: cross)
}
/// Places children inside `rect`; with relative = true frames are relative to rect's origin.
@MainActor func _stackPlace(_ children: [_Node], axis: Axis, spacing: CGFloat, alignment: Alignment, in rect: CGRect, relative: Bool) {
    let nodes = _flatten(children)
    let sizes = _stackSizes(nodes, axis: axis, spacing: spacing, _Proposal(width: rect.width, height: rect.height))
    var pos: CGFloat = 0
    let base = relative ? CGPoint.zero : rect.origin
    for (i, node) in nodes.enumerated() {
        let s = sizes[i]
        var f: CGRect
        if axis == .vertical {
            var x: CGFloat = (rect.width - s.width) / 2
            if alignment.horizontal == .leading { x = 0 } else if alignment.horizontal == .trailing { x = rect.width - s.width }
            f = CGRect(x: base.x + x, y: base.y + pos, width: s.width, height: s.height)
        } else {
            var y: CGFloat = (rect.height - s.height) / 2
            if alignment.vertical == .top { y = 0 } else if alignment.vertical == .bottom { y = rect.height - s.height }
            f = CGRect(x: base.x + pos, y: base.y + y, width: s.width, height: s.height)
        }
        node.place(f)
        pos += s[axis] + spacing
    }
}

final class _StackNode: _Node {
    let axis: Axis, spacing: CGFloat, alignment: Alignment
    init(path: String, axis: Axis, spacing: CGFloat?, alignment: Alignment, children: [_Node]) {
        self.axis = axis; self.alignment = alignment
        self.spacing = spacing ?? 8
        super.init(path: path, children: children)
        rowAction = nil
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { _stackSize(children, axis: axis, spacing: spacing, p) }
    override func place(_ rect: CGRect) {
        frame = rect
        _stackPlace(children, axis: axis, spacing: spacing, alignment: alignment, in: rect, relative: true)
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        for (i, c) in _flatten(children).enumerated() { g.mount(c, in: view, order: i) }
    }
}

final class _ZStackNode: _Node {
    let alignment: Alignment
    init(path: String, alignment: Alignment, children: [_Node]) { self.alignment = alignment; super.init(path: path, children: children); rowAction = nil }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        var s = CGSize.zero
        for c in _flatten(children) { let cs = c.sizeThatFits(p); s.width = max(s.width, cs.width); s.height = max(s.height, cs.height) }
        return s
    }
    override func place(_ rect: CGRect) {
        frame = rect
        for c in _flatten(children) {
            let cs = c.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
            c.place(_align(CGSize(width: min(cs.width, rect.width), height: min(cs.height, rect.height)), in: CGRect(origin: .zero, size: rect.size), alignment))
        }
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        // later children draw on top; .zIndex reorders (stable)
        let items = _flatten(children).enumerated().map { ($0.offset, $0.element, ($0.element as? _EffectNode)?.zIndexValue ?? 0) }
        for (i, c, _) in items.sorted(by: { $0.2 != $1.2 ? $0.2 < $1.2 : $0.0 < $1.0 }) { g.mount(c, in: view, order: i) }
    }
}

func _align(_ s: CGSize, in r: CGRect, _ a: Alignment) -> CGRect {
    var x: CGFloat = r.minX + (r.width - s.width) / 2, y: CGFloat = r.minY + (r.height - s.height) / 2
    if a.horizontal == .leading { x = r.minX } else if a.horizontal == .trailing { x = r.maxX - s.width }
    if a.vertical == .top { y = r.minY } else if a.vertical == .bottom { y = r.maxY - s.height }
    return CGRect(x: x, y: y, width: s.width, height: s.height)
}

final class _SpacerNode: _Node {
    let minLength: CGFloat
    init(path: String, minLength: CGFloat?) { self.minLength = minLength ?? 8; super.init(path: path, children: []) }
    override var isSpacer: Bool { true }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        // the enclosing stack proposes the space along its axis; take it (at least minLength)
        CGSize(width: max(minLength, min(p.width ?? minLength, 1e6)) , height: max(minLength, min(p.height ?? minLength, 1e6)))
    }
}

// MARK: - Single-child wrappers

class _WrapperNode: _Node {
    var child: _Node { children[0] }
    /// modifiers (overlay, background, ...) lay out like the content they wrap
    override var ignoresSafeArea: Bool { child.ignoresSafeArea }
    init(path: String, child: _Node) { super.init(path: path, children: [child]) }
}

final class _PaddingNode: _WrapperNode {
    let insets: EdgeInsets
    init(path: String, insets: EdgeInsets, child: _Node) { self.insets = insets; super.init(path: path, child: child) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let s = child.sizeThatFits(p.inset(insets))
        return CGSize(width: s.width + insets.leading + insets.trailing, height: s.height + insets.top + insets.bottom)
    }
    override func place(_ rect: CGRect) {
        frame = rect
        child.place(CGRect(x: insets.leading, y: insets.top, width: max(0, rect.width - insets.leading - insets.trailing), height: max(0, rect.height - insets.top - insets.bottom)))
    }
}

final class _FrameNode: _WrapperNode {
    var width: CGFloat?, height: CGFloat?
    var minWidth: CGFloat?, maxWidth: CGFloat?, minHeight: CGFloat?, maxHeight: CGFloat?
    var alignment: Alignment = .center
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        var proposal = p
        if let w = width { proposal.width = w } else if let pw = p.width { proposal.width = min(max(pw, minWidth ?? 0), maxWidth ?? .infinity) }
        if let h = height { proposal.height = h } else if let ph = p.height { proposal.height = min(max(ph, minHeight ?? 0), maxHeight ?? .infinity) }
        let cs = child.sizeThatFits(proposal)
        var w = width ?? cs.width, h = height ?? cs.height
        if width == nil {
            if let mx = maxWidth, mx == .infinity, let pw = p.width { w = max(cs.width, pw) }
            else if let mx = maxWidth { w = min(max(cs.width, p.width.map { min($0, mx) } ?? cs.width), mx) }
            if let mn = minWidth { w = max(w, mn) }
        }
        if height == nil {
            if let mx = maxHeight, mx == .infinity, let ph = p.height { h = max(cs.height, ph) }
            else if let mx = maxHeight { h = min(max(cs.height, p.height.map { min($0, mx) } ?? cs.height), mx) }
            if let mn = minHeight { h = max(h, mn) }
        }
        return CGSize(width: w, height: h)
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let cs = child.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        child.place(_align(CGSize(width: min(cs.width, rect.width), height: min(cs.height, rect.height)), in: CGRect(origin: .zero, size: rect.size), alignment))
    }
}

final class _BackgroundNode: _WrapperNode {
    let color: Color?, cornerRadius: CGFloat
    let background: _Node?
    init(path: String, color: Color?, cornerRadius: CGFloat, background: _Node?, child: _Node) {
        self.color = color; self.cornerRadius = cornerRadius; self.background = background
        super.init(path: path, child: child)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        background?.place(CGRect(origin: .zero, size: rect.size))
        child.place(CGRect(origin: .zero, size: rect.size))
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        v.backgroundColor = color?.uiColor
        v.layer.cornerRadius = cornerRadius
        return v
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        if let b = background { g.mount(b, in: view, order: 0) }
        g.mount(child, in: view, order: 1)
    }
}

/// Visual-only modifiers applied to the child's container view (opacity, hidden, tint).
final class _ViewPropsNode: _WrapperNode {
    var alpha: CGFloat = 1
    var hidden = false
    var disabled = false
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        v.alpha = hidden ? 0 : alpha
        v.isUserInteractionEnabled = !disabled && !hidden
        return v
    }
}

/// Fills the proposed space with a color.
final class _ColorNode: _Node {
    let color: Color
    init(path: String, color: Color) { self.color = color; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { UIView() }
        v.backgroundColor = color.uiColor
        v.isUserInteractionEnabled = false
        return v
    }
}

final class _DividerNode: _Node {
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: 1 / max(1, UIScreen.main.scale)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { UIView() }
        v.backgroundColor = .separator
        return v
    }
}
