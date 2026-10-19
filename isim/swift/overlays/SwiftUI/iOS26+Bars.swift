// isim SwiftUI: iOS 26 additions — safeAreaBar (a safe-area inset with the scroll-edge fade behind it),
// ConcentricRectangle (corners concentric with the container shape or the screen; Edge.Corner, Edge.Corner.Style),
// sliderThumbVisibility (UIKit's thumbless slider), labelIconToTitleSpacing, searchToolbarBehavior(.minimize) (the
// search field collapses to a button), tabViewSearchActivation(.searchTabSelection) (selecting the search tab focuses
// its field) and DefaultToolbarItem (ToolbarDefaultItemKind).
import UIKit

// MARK: - Environment

struct _SliderThumbKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct _LabelIconSpacingKey: EnvironmentKey { static var defaultValue: CGFloat? { nil } }
struct _SearchMinimizeKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _TabSearchActivateKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues {
    var _sliderThumb: Visibility { get { self[_SliderThumbKey.self] } set { self[_SliderThumbKey.self] = newValue } }
    var _labelIconSpacing: CGFloat? { get { self[_LabelIconSpacingKey.self] } set { self[_LabelIconSpacingKey.self] = newValue } }
    var _searchMinimize: Bool { get { self[_SearchMinimizeKey.self] } set { self[_SearchMinimizeKey.self] = newValue } }
    var _tabSearchActivate: Bool { get { self[_TabSearchActivateKey.self] } set { self[_TabSearchActivateKey.self] = newValue } }
    /// The space between a Label's icon and its title (nil: the system's).
    @available(iOS 26.0, *)
    public var labelIconToTitleSpacing: CGFloat? {
        get { _labelIconSpacing }
        set { _labelIconSpacing = newValue }
    }
}

extension View {
    /// `.hidden`: sliders inside have no thumb (UIKit's thumbless style: the finger drags the value anywhere).
    @available(iOS 26.0, *)
    public func sliderThumbVisibility(_ visibility: Visibility) -> some View { _env { $0._sliderThumb = visibility } }
    /// The space between the icon and the title of Labels inside.
    @available(iOS 26.0, *)
    public func labelIconToTitleSpacing(_ spacing: CGFloat) -> some View { _env { $0._labelIconSpacing = spacing } }
}

// MARK: - safeAreaBar

/// The scroll-edge fade behind a safe area bar (opaque at the screen edge, clear towards the content).
struct _EdgeFadeBackground: View, _PrimitiveView {
    let fromBottom: Bool
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _EdgeFadeNode(path: ctx.path, fromBottom: fromBottom) }
}
final class _EdgeFadeNode: _Node {
    let fromBottom: Bool
    init(path: String, fromBottom: Bool) { self.fromBottom = fromBottom; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 0, height: p.height ?? 0) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIEdgeFadeView(frame: .zero) }
        v.accessibilityIdentifier = "safe-area-bar-fade"
        if v.fromBottom != fromBottom { v.fromBottom = fromBottom; v.setNeedsDisplay() }
        // from the bar to the screen edge (the bar itself stays out of the safe area)
        let up = !fromBottom
        g.postRender.append { [weak v] in
            guard let v, let w = v.window else { return }
            let f = v.convert(v.bounds, to: nil)
            var r = v.frame
            if up { r.origin.y -= f.minY; r.size.height += f.minY } else { r.size.height += w.bounds.maxY - f.maxY }
            if r != v.frame { v.frame = r; v.setNeedsDisplay() }
        }
        return v
    }
}
extension View {
    /// Content laid out as a safe area inset (the content beside it is inset by it, scroll views scroll under it),
    /// with the iOS 26 scroll-edge fade behind it.
    @available(iOS 26.0, *)
    public func safeAreaBar(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil,
                            @ViewBuilder content: () -> some View) -> some View {
        let v = content()
        let fromBottom = edge == .bottom
        return safeAreaInset(edge: edge, alignment: alignment, spacing: spacing) {
            v.frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center)).background {
                _EdgeFadeBackground(fromBottom: fromBottom)
                    .padding(fromBottom ? .top : .bottom, -16)
            }
        }
    }
    @available(iOS 26.0, *)
    public func safeAreaBar(edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil,
                            @ViewBuilder content: () -> some View) -> some View {
        safeAreaInset(edge: edge, alignment: alignment, spacing: spacing, content: content)
    }
}

// MARK: - Edge.Corner, ConcentricRectangle

@available(iOS 26.0, *)
extension Edge {
    /// A corner of a rectangle.
    public enum Corner: Int8, CaseIterable, Hashable, Sendable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        public struct Set: OptionSet, Hashable, Sendable {
            public let rawValue: Int8
            public init(rawValue: Int8) { self.rawValue = rawValue }
            public init(_ corner: Edge.Corner) { rawValue = 1 << corner.rawValue }
            public static let topLeading = Set(.topLeading), topTrailing = Set(.topTrailing)
            public static let bottomLeading = Set(.bottomLeading), bottomTrailing = Set(.bottomTrailing)
            public static let top: Set = [.topLeading, .topTrailing], bottom: Set = [.bottomLeading, .bottomTrailing]
            public static let leading: Set = [.topLeading, .bottomLeading], trailing: Set = [.topTrailing, .bottomTrailing]
            public static let all: Set = [.top, .bottom], none: Set = []
            public func contains(_ corner: Edge.Corner) -> Bool { contains(Set(corner)) }
        }

        /// How a corner is rounded: a fixed radius, or concentric with the container (at least `minimum`).
        public struct Style: Hashable, Sendable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
            indirect enum Kind: Hashable, Sendable { case fixed(CGFloat), concentric(Kind?) }
            let kind: Kind
            public static func fixed(_ radius: CGFloat) -> Style { Style(kind: .fixed(radius)) }
            public static var concentric: Style { Style(kind: .concentric(nil)) }
            public static func concentric(minimum: Style?) -> Style { Style(kind: .concentric(minimum?.kind)) }
            public init(floatLiteral value: Double) { kind = .fixed(CGFloat(value)) }
            public init(integerLiteral value: Int) { kind = .fixed(CGFloat(value)) }
            init(kind: Kind) { self.kind = kind }
            /// The radius for a container corner radius `container` (nil: no container, the minimum or 0)
            func radius(_ container: CGFloat?) -> CGFloat {
                func r(_ k: Kind) -> CGFloat {
                    switch k {
                    case .fixed(let v): return v
                    case .concentric(let m): return max(container ?? 0, m.map(r) ?? 0)
                    }
                }
                return r(kind)
            }
        }
    }
}

/// A rectangle whose corners are concentric with its container: the shape of a `.containerShape(_:)` around it, or
/// the screen's rounded corners, minus the distance to them (corners can also be fixed).
@available(iOS 26.0, *)
public struct ConcentricRectangle: Shape, Sendable {
    /// top leading, top trailing, bottom leading, bottom trailing
    let corners: [Edge.Corner.Style]
    /// uniform corners (indices of corners that share the smallest of their radii)
    let uniform: [[Int]]
    public init() { self.init(corners: .concentric, isUniform: false) }
    public init(corners: Edge.Corner.Style = .concentric, isUniform: Bool = false) {
        self.corners = Array(repeating: corners, count: 4); uniform = isUniform ? [[0, 1, 2, 3]] : []
    }
    public init(topLeadingCorner: Edge.Corner.Style = .concentric, topTrailingCorner: Edge.Corner.Style = .concentric,
                bottomLeadingCorner: Edge.Corner.Style = .concentric, bottomTrailingCorner: Edge.Corner.Style = .concentric) {
        corners = [topLeadingCorner, topTrailingCorner, bottomLeadingCorner, bottomTrailingCorner]; uniform = []
    }
    public init(uniformTopCorners: Edge.Corner.Style = .concentric, uniformBottomCorners: Edge.Corner.Style = .concentric) {
        corners = [uniformTopCorners, uniformTopCorners, uniformBottomCorners, uniformBottomCorners]; uniform = [[0, 1], [2, 3]]
    }
    public init(uniformLeadingCorners: Edge.Corner.Style = .concentric, uniformTrailingCorners: Edge.Corner.Style = .concentric) {
        corners = [uniformLeadingCorners, uniformTrailingCorners, uniformLeadingCorners, uniformTrailingCorners]; uniform = [[0, 2], [1, 3]]
    }
    public init(uniformTopCorners: Edge.Corner.Style = .concentric, bottomLeadingCorner: Edge.Corner.Style = .concentric,
                bottomTrailingCorner: Edge.Corner.Style = .concentric) {
        corners = [uniformTopCorners, uniformTopCorners, bottomLeadingCorner, bottomTrailingCorner]; uniform = [[0, 1]]
    }
    public init(uniformBottomCorners: Edge.Corner.Style = .concentric, topLeadingCorner: Edge.Corner.Style = .concentric,
                topTrailingCorner: Edge.Corner.Style = .concentric) {
        corners = [topLeadingCorner, topTrailingCorner, uniformBottomCorners, uniformBottomCorners]; uniform = [[2, 3]]
    }
    public init(uniformLeadingCorners: Edge.Corner.Style = .concentric, topTrailingCorner: Edge.Corner.Style = .concentric,
                bottomTrailingCorner: Edge.Corner.Style = .concentric) {
        corners = [uniformLeadingCorners, topTrailingCorner, uniformLeadingCorners, bottomTrailingCorner]; uniform = [[0, 2]]
    }
    public init(uniformTrailingCorners: Edge.Corner.Style = .concentric, topLeadingCorner: Edge.Corner.Style = .concentric,
                bottomLeadingCorner: Edge.Corner.Style = .concentric) {
        corners = [topLeadingCorner, uniformTrailingCorners, bottomLeadingCorner, uniformTrailingCorners]; uniform = [[1, 3]]
    }
    /// Without a container: fixed corners, concentric ones at their minimum.
    public func path(in rect: CGRect) -> Path { _path(in: rect, radii: corners.map { $0.radius(nil) }) }

    /// The radii for container corner radii `container` and distances `d` from each corner to the container's.
    func _radii(container: [CGFloat], distance d: [CGFloat], size: CGSize) -> [CGFloat] {
        var r = (0..<4).map { i in corners[i].radius(max(0, container[i] - d[i])) }
        for group in uniform { let m = group.map { r[$0] }.min() ?? 0; for i in group { r[i] = m } }
        let lim = min(size.width, size.height) / 2
        return r.map { min(max(0, $0), lim) }
    }
    func _path(in rect: CGRect, radii r: [CGFloat]) -> Path {
        Path(UIBezierPath(roundedRect: rect, topLeft: r[0], topRight: r[1], bottomLeft: r[2], bottomRight: r[3]).cgPath)
    }
}
extension UIBezierPath {
    /// A rectangle with its own radius per corner (circular arcs).
    convenience init(roundedRect r: CGRect, topLeft tl: CGFloat, topRight tr: CGFloat, bottomLeft bl: CGFloat, bottomRight br: CGFloat) {
        self.init()
        move(to: CGPoint(x: r.minX + tl, y: r.minY))
        addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        if tr > 0 { addArc(withCenter: CGPoint(x: r.maxX - tr, y: r.minY + tr), radius: tr, startAngle: -.pi / 2, endAngle: 0, clockwise: true) }
        addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        if br > 0 { addArc(withCenter: CGPoint(x: r.maxX - br, y: r.maxY - br), radius: br, startAngle: 0, endAngle: .pi / 2, clockwise: true) }
        addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
        if bl > 0 { addArc(withCenter: CGPoint(x: r.minX + bl, y: r.maxY - bl), radius: bl, startAngle: .pi / 2, endAngle: .pi, clockwise: true) }
        addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        if tl > 0 { addArc(withCenter: CGPoint(x: r.minX + tl, y: r.minY + tl), radius: tl, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true) }
        close()
    }
}
/// The ConcentricRectangle in a shape style or a stroke (nil: not one).
func _concentricRectangle(_ s: Any) -> Any? {
    if #available(iOS 26.0, *), s is ConcentricRectangle { return s }
    for c in Mirror(reflecting: s).children where c.label == "shape" { return _concentricRectangle(c.value) }
    return nil
}
/// A ConcentricRectangle's path for its view `view` (once in place): concentric with the container shape `cs`, or
/// with the screen's corners.
@available(iOS 26.0, *)
@MainActor func _concentricRectanglePath(_ shape: ConcentricRectangle, _ view: UIView, _ cs: _ContainerShape?, _ g: _Graph?) -> Path? {
    let local = CGRect(origin: .zero, size: view.bounds.size)
    let rect: CGRect, size: CGSize, radius: CGFloat
    if let cs, let cv = g?.views[cs.viewKey] {
        rect = view.convert(view.bounds, to: cv); size = cv.bounds.size
        switch cs.kind {
        case .rounded(let r)?: radius = r
        case .circle?, .capsule?: radius = min(size.width, size.height) / 2
        default: radius = 0
        }
    } else {
        guard let w = view.window else { return nil }
        rect = view.convert(view.bounds, to: nil); size = w.bounds.size
        // the screen's corner radius: a top-level view that fills the screen, concentric with it
        let probe = UIView(frame: CGRect(origin: .zero, size: size))
        probe.cornerConfiguration = .corners(radius: .containerConcentric())
        radius = probe.effectiveRadius(corner: .topLeft)
    }
    let dl = rect.minX, dt = rect.minY, dr = size.width - rect.maxX, db = size.height - rect.maxY
    let d = [max(dl, dt), max(dr, dt), max(dl, db), max(dr, db)]
    return shape._path(in: local, radii: shape._radii(container: Array(repeating: radius, count: 4), distance: d, size: local.size))
}

// MARK: - Search in the toolbar

/// How the search field of a toolbar behaves: `.minimize` collapses it to a button until searching.
@available(iOS 26.0, *)
public struct SearchToolbarBehavior: Equatable, Sendable {
    let minimize: Bool
    public static var automatic: SearchToolbarBehavior { SearchToolbarBehavior(minimize: false) }
    public static var minimize: SearchToolbarBehavior { SearchToolbarBehavior(minimize: true) }
}
/// When a TabView's search tab activates its search field: `.searchTabSelection` focuses it when the tab is selected.
@available(iOS 26.0, *)
public struct TabSearchActivation: Equatable, Sendable {
    let onSelection: Bool
    public static var automatic: TabSearchActivation { TabSearchActivation(onSelection: false) }
    public static var searchTabSelection: TabSearchActivation { TabSearchActivation(onSelection: true) }
}
extension View {
    @available(iOS 26.0, *)
    public func searchToolbarBehavior(_ behavior: SearchToolbarBehavior) -> some View { _env { $0._searchMinimize = behavior.minimize } }
    @available(iOS 26.0, *)
    public func tabViewSearchActivation(_ activation: TabSearchActivation) -> some View { _env { $0._tabSearchActivate = activation.onSelection } }
}

// MARK: - DefaultToolbarItem

/// A toolbar item the system provides.
@available(iOS 17.0, *)
public struct ToolbarDefaultItemKind: Equatable, Sendable {
    let id: Int
    /// iPad split views: the sidebar's show / hide button (isim shows it on the sidebar column already)
    public static let sidebarToggle = ToolbarDefaultItemKind(id: 0)
    /// the navigation title (isim keeps it in the navigation bar)
    @available(iOS 18.0, *)
    public static let title = ToolbarDefaultItemKind(id: 1)
    /// the search field of the `.searchable` in the navigation stack: a magnifier button that starts searching
    @available(iOS 26.0, *)
    public static let search = ToolbarDefaultItemKind(id: 2)
}
/// A system item at a placement: `DefaultToolbarItem(kind: .search, placement: .bottomBar)`.
@available(iOS 26.0, *)
public struct DefaultToolbarItem: ToolbarContent {
    let kind: ToolbarDefaultItemKind, placement: ToolbarItemPlacement
    public init(kind: ToolbarDefaultItemKind, placement: ToolbarItemPlacement = .automatic) { self.kind = kind; self.placement = placement }
    public var _items: [_ToolbarEntry] {
        guard kind.id == 2 else { return [] }
        var e = _ToolbarEntry(placement: placement, view: AnyView(EmptyView()))
        e.defaultSearch = true
        return [e]
    }
}
