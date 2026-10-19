// isim SwiftUI: more UIKit integration — UIHostingConfiguration (SwiftUI content in UIKit cells), ImageRenderer
// (SwiftUI views to images and Core Graphics contexts), UIGestureRecognizerRepresentable (UIKit gesture recognizers
// on SwiftUI views) and UIHostingSceneDelegate (SwiftUI scenes in a UIKit app). Signatures from Apple's documentation.
// Each hosts a _Graph like UIHostingController: the views are isim's real UIKit views (drawn into images with
// drawHierarchy).
import UIKit
import Combine

// MARK: - UIHostingConfiguration

/// A content configuration whose content view hosts SwiftUI views (for UICollectionViewCell / UITableViewCell
/// `contentConfiguration`). The content is inset by the cell's layout margins (or `margins`), the background fills the
/// cell, and the cell sizes to the content (at least 44 pt tall unless `minSize` says otherwise). Adapted: list
/// features (swipe actions, separator alignment) are not bridged.
@available(iOS 16.0, *)
public struct UIHostingConfiguration<Content: View, Background: View>: UIContentConfiguration {
    let content: Content
    let background: Background
    var margins: (top: CGFloat?, leading: CGFloat?, bottom: CGFloat?, trailing: CGFloat?) = (nil, nil, nil, nil)
    var minWidth: CGFloat?, minHeight: CGFloat?
    /// A configuration showing `content`.
    public init(@ViewBuilder content: () -> Content) where Background == EmptyView {
        self.content = content(); background = EmptyView()
    }
    init(content: Content, background: Background) { self.content = content; self.background = background }
    func with<B: View>(background b: B) -> UIHostingConfiguration<Content, B> {
        var c = UIHostingConfiguration<Content, B>(content: content, background: b)
        c.margins = margins; c.minWidth = minWidth; c.minHeight = minHeight
        return c
    }
    /// The cell's background: a shape style.
    public func background<S: ShapeStyle>(_ style: S) -> UIHostingConfiguration<Content, _UIHostingConfigurationBackgroundView<S>> {
        with(background: _UIHostingConfigurationBackgroundView(style: style))
    }
    /// The cell's background: views.
    public func background<B: View>(@ViewBuilder content: () -> B) -> UIHostingConfiguration<Content, B> { with(background: content()) }
    /// Replaces the default margins (the cell's layout margins) on `edges`.
    public func margins(_ edges: Edge.Set = .all, _ insets: EdgeInsets) -> UIHostingConfiguration<Content, Background> {
        var c = self
        if edges.contains(.top) { c.margins.top = insets.top }
        if edges.contains(.leading) { c.margins.leading = insets.leading }
        if edges.contains(.bottom) { c.margins.bottom = insets.bottom }
        if edges.contains(.trailing) { c.margins.trailing = insets.trailing }
        return c
    }
    /// Replaces the default margins on `edges` with `length`.
    public func margins(_ edges: Edge.Set = .all, _ length: CGFloat) -> UIHostingConfiguration<Content, Background> {
        margins(edges, EdgeInsets(top: length, leading: length, bottom: length, trailing: length))
    }
    /// The smallest size of the cell (nil: the system's, 44 pt tall).
    public func minSize(width: CGFloat? = nil, height: CGFloat? = nil) -> UIHostingConfiguration<Content, Background> {
        var c = self; c.minWidth = width; c.minHeight = height; return c
    }
    /// The system's smallest size.
    public func minSize() -> UIHostingConfiguration<Content, Background> { minSize(width: nil, height: nil) }
    @MainActor public func makeContentView() -> UIView & UIContentView { _UIHostingContentView(configuration: self) }
    public func updated(for state: UIConfigurationState) -> UIHostingConfiguration<Content, Background> { self }
}
@available(iOS 16.0, *)
extension UIHostingConfiguration: _HostingConfigurationErased {
    var _root: AnyView { AnyView(content) }
    var _background: AnyView { AnyView(background) }
    var _margins: (top: CGFloat?, leading: CGFloat?, bottom: CGFloat?, trailing: CGFloat?) { margins }
    var _minSize: (CGFloat?, CGFloat?) { (minWidth, minHeight) }
}
protocol _HostingConfigurationErased {
    var _root: AnyView { get }
    var _background: AnyView { get }
    var _margins: (top: CGFloat?, leading: CGFloat?, bottom: CGFloat?, trailing: CGFloat?) { get }
    var _minSize: (CGFloat?, CGFloat?) { get }
}
/// The background of a UIHostingConfiguration made from a shape style.
public struct _UIHostingConfigurationBackgroundView<S: ShapeStyle>: View {
    let style: S
    public var body: some View { Rectangle().fill(style) }
}

/// A UIHostingConfiguration's content view: the background filling it, the content inset by the margins.
final class _UIHostingContentView: UIView, UIContentView {
    final class Box { var config: _HostingConfigurationErased?; var insets = EdgeInsets() }
    let box = Box()
    let graph: _Graph
    let host: _SUIHostView
    var configuration: UIContentConfiguration {
        didSet { box.config = configuration as? _HostingConfigurationErased; graph.invalidate(); invalidateIntrinsicContentSize() }
    }
    init(configuration: UIContentConfiguration) {
        self.configuration = configuration
        box.config = configuration as? _HostingConfigurationErased
        let box = self.box
        graph = _Graph(root: { () -> any View in
            let c = box.config
            return ZStack {
                (c?._background ?? AnyView(EmptyView())).ignoresSafeArea()
                (c?._root ?? AnyView(EmptyView())).padding(box.insets)
            }
        })
        host = _SUIHostView(graph: graph)
        super.init(frame: .zero)
        host.backgroundColor = .clear
        addSubview(host)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func supports(_ configuration: UIContentConfiguration) -> Bool { configuration is _HostingConfigurationErased }
    /// the margins: the configuration's, else the cell's layout margins
    func resolvedInsets() -> EdgeInsets {
        let m = box.config?._margins ?? (top: nil, leading: nil, bottom: nil, trailing: nil)
        let d = (superview ?? self).directionalLayoutMargins
        return EdgeInsets(top: m.top ?? d.top, leading: m.leading ?? d.leading, bottom: m.bottom ?? d.bottom, trailing: m.trailing ?? d.trailing)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let i = resolvedInsets()
        if i != box.insets { box.insets = i; graph.invalidate() }
        host.frame = bounds
    }
    /// The cell's size for a width: the content's height there plus the margins, at least the minimum size.
    func fitting(width: CGFloat?) -> CGSize {
        let i = resolvedInsets()
        box.insets = i
        let inner = graph.measure(CGSize(width: width.map { max(0, $0) } ?? 0, height: 0), traits: traitCollection)
        let (mw, mh) = box.config?._minSize ?? (nil, nil)
        return CGSize(width: max(width ?? inner.width, mw ?? 0), height: max(ceil(inner.height), mh ?? 44))
    }
    @objc(_isim_intrinsicSizeForWidth:) func _isim_intrinsicSize(forWidth w: CGFloat) -> CGSize {
        let width = w > 0 ? w : (superview?.bounds.width ?? 0)
        return fitting(width: width > 0 ? width : nil)
    }
    override var intrinsicContentSize: CGSize {
        let s = fitting(width: bounds.width > 0 ? bounds.width : nil)
        return CGSize(width: UIView.noIntrinsicMetric, height: s.height)
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize { fitting(width: size.width > 0 && size.width < 1e6 ? size.width : nil) }
}

// MARK: - ImageRenderer

/// Makes images of SwiftUI views: `uiImage` / `cgImage` rasterize the content at its size for `proposedSize`
/// (its ideal size when unspecified) at `scale`; `render(rasterizationScale:renderer:)` draws it into a Core Graphics
/// context (bottom-left origin, as Apple documents). Adapted: isim's views are UIKit views, all drawn by isim's
/// renderer, so none shows a placeholder; `colorMode` and `allowedDynamicRange` do not change the output (isim draws
/// 8-bit sRGB). `objectWillChange` fires when a property or the content's state changes.
@available(iOS 16.0, *)
public final class ImageRenderer<Content: View>: ObservableObject {
    public let objectWillChange = PassthroughSubject<Void, Never>()
    final class Box { var content: Content; init(_ c: Content) { content = c } }
    let box: Box
    let graph: _Graph
    let host: _SUIHostView
    @MainActor public var content: Content { get { box.content } set { box.content = newValue; changed() } }
    @MainActor public var proposedSize: ProposedViewSize = .unspecified { didSet { changed() } }
    @MainActor public var scale: CGFloat = 1 { didSet { changed() } }
    @MainActor public var isOpaque: Bool = false { didSet { changed() } }
    @MainActor public var colorMode: ColorRenderingMode = .nonLinear { didSet { changed() } }
    @available(iOS 26.0, *)
    @MainActor public var allowedDynamicRange: Image.DynamicRange? {
        get { _dynamicRange as? Image.DynamicRange } set { _dynamicRange = newValue; changed() }
    }
    var _dynamicRange: Any?
    @MainActor public init(content view: Content) {
        let box = Box(view)
        self.box = box
        graph = _Graph(root: { box.content })
        host = _SUIHostView(graph: graph)
        host.backgroundColor = .clear
        if #available(iOS 26.0, *) { _dynamicRange = Image.DynamicRange.standard }
        graph.onInvalidate = { [weak self] in self?.objectWillChange.send() }
    }
    @MainActor func changed() { objectWillChange.send() }
    /// lays the content out at its size for the proposal (nil: nothing to draw)
    @MainActor func layout() -> CGSize? {
        let p = CGSize(width: proposedSize.width ?? .infinity, height: proposedSize.height ?? .infinity)
        let s = graph.measure(p, traits: host.traitCollection)
        let size = CGSize(width: ceil(s.width), height: ceil(s.height))
        guard size.width >= 1, size.height >= 1, size.width < 1e5, size.height < 1e5 else { return nil }
        host.frame = CGRect(origin: .zero, size: size)
        host.setNeedsLayout()
        host.layoutIfNeeded()
        return size
    }
    /// Draws the content into Core Graphics contexts: `renderer` gets the content's size and a function drawing it
    /// into a context with a bottom-left origin.
    @MainActor public func render(rasterizationScale: CGFloat = 1, renderer: (CGSize, (CGContext) -> Void) -> Void) {
        let size = layout() ?? .zero
        let host = self.host
        renderer(size) { ctx in
            guard size.width > 0 else { return }
            ctx.saveGState()
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(ctx)
            _ = host.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            UIGraphicsPopContext()
            ctx.restoreGState()
        }
    }
    /// The content as a UIKit image (nil when it has no size).
    @MainActor public var uiImage: UIImage? {
        guard let size = layout() else { return nil }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = scale
        fmt.opaque = isOpaque
        let host = self.host
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            _ = host.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
    /// The content as a Core Graphics image.
    @MainActor public var cgImage: CGImage? { uiImage?.cgImage }
}

extension Image {
    /// The dynamic range an image may use (iOS 26). isim draws standard dynamic range.
    @available(iOS 26.0, *)
    public struct DynamicRange: Hashable, Sendable {
        let raw: Int
        public static let standard = DynamicRange(raw: 0)
        public static let constrainedHigh = DynamicRange(raw: 1)
        public static let high = DynamicRange(raw: 2)
    }
}

// MARK: - UIGestureRecognizerRepresentable

/// A UIKit gesture recognizer on a SwiftUI view (`.gesture(_:)`): made once, updated on every update of the view,
/// with SwiftUI's target calling `handleUIGestureRecognizerAction`.
@available(iOS 18.0, *)
@MainActor @preconcurrency public protocol UIGestureRecognizerRepresentable {
    associatedtype Coordinator = Void
    associatedtype UIGestureRecognizerType: UIGestureRecognizer
    typealias Context = UIGestureRecognizerRepresentableContext<Self>
    typealias CoordinateSpaceConverter = UIGestureRecognizerRepresentableCoordinateSpaceConverter
    func makeUIGestureRecognizer(context: Context) -> UIGestureRecognizerType
    func handleUIGestureRecognizerAction(_ recognizer: UIGestureRecognizerType, context: Context)
    func updateUIGestureRecognizer(_ recognizer: UIGestureRecognizerType, context: Context)
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator
}
@available(iOS 18.0, *)
extension UIGestureRecognizerRepresentable {
    public func handleUIGestureRecognizerAction(_ recognizer: UIGestureRecognizerType, context: Context) {}
    public func updateUIGestureRecognizer(_ recognizer: UIGestureRecognizerType, context: Context) {}
}
@available(iOS 18.0, *)
extension UIGestureRecognizerRepresentable where Coordinator == () {
    public func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { () }
}
/// What a represented gesture recognizer is made and updated with.
@available(iOS 18.0, *)
public struct UIGestureRecognizerRepresentableContext<Representable: UIGestureRecognizerRepresentable> {
    public let converter: UIGestureRecognizerRepresentableCoordinateSpaceConverter
    public let coordinator: Representable.Coordinator
}
/// Converts the represented recognizer's location, translation and velocity into the coordinate spaces of the SwiftUI
/// view it is attached to (`.local`) and of its ancestors.
@available(iOS 18.0, *)
public struct UIGestureRecognizerRepresentableCoordinateSpaceConverter {
    final class Refs { weak var view: UIView?; weak var recognizer: UIGestureRecognizer? }
    let refs: Refs
    public var localLocation: CGPoint { location(in: .local) }
    public var localTranslation: CGPoint? { translation(in: .local) }
    public var localVelocity: CGPoint? { velocity(in: .local) }
    /// A point of the window (global) in `coordinateSpace`.
    public func convert(globalPoint: CGPoint, to coordinateSpace: some CoordinateSpaceProtocol = .local) -> CGPoint {
        let space = coordinateSpace.coordinateSpace
        return MainActor.assumeIsolated {
            guard let v = refs.view else { return globalPoint }
            return _livePoint(v.convert(globalPoint, from: nil), in: v, space)
        }
    }
    public func location(in coordinateSpace: some CoordinateSpaceProtocol) -> CGPoint {
        let space = coordinateSpace.coordinateSpace
        return MainActor.assumeIsolated {
            guard let v = refs.view, let r = refs.recognizer else { return .zero }
            return _livePoint(r.location(in: v), in: v, space)
        }
    }
    /// A pan's translation (nil for other recognizers).
    public func translation(in coordinateSpace: some CoordinateSpaceProtocol) -> CGPoint? {
        let space = coordinateSpace.coordinateSpace
        return MainActor.assumeIsolated {
            guard let v = refs.view, let pan = refs.recognizer as? UIPanGestureRecognizer else { return nil }
            return vector(pan.translation(in: v), v, space)
        }
    }
    /// A pan's velocity (nil for other recognizers).
    public func velocity(in coordinateSpace: some CoordinateSpaceProtocol) -> CGPoint? {
        let space = coordinateSpace.coordinateSpace
        return MainActor.assumeIsolated {
            guard let v = refs.view, let pan = refs.recognizer as? UIPanGestureRecognizer else { return nil }
            return vector(pan.velocity(in: v), v, space)
        }
    }
    /// a vector of the view's coordinates in another space (the difference of the converted points)
    @MainActor func vector(_ d: CGPoint, _ v: UIView, _ space: CoordinateSpace) -> CGPoint {
        let a = _livePoint(.zero, in: v, space), b = _livePoint(d, in: v, space)
        return CGPoint(x: b.x - a.x, y: b.y - a.y)
    }
}

@available(iOS 18.0, *)
extension View {
    /// Attaches a UIKit gesture recognizer to this view.
    public func gesture(_ representable: some UIGestureRecognizerRepresentable) -> some View {
        _modify { ctx, c in
            let rctx = ctx.child("uigr")
            _attach(representable, rctx)
            return _GestureRepresentableNode(path: ctx.path, rep: representable, graph: ctx.graph, child: _resolve(c, ctx.child("gst")))
        }
    }
}

@available(iOS 18.0, *)
final class _GestureRepresentableState<R: UIGestureRecognizerRepresentable>: _AnyStorage {
    let recognizer: R.UIGestureRecognizerType
    let coordinator: R.Coordinator
    let refs: UIGestureRecognizerRepresentableCoordinateSpaceConverter.Refs
    var latest: R
    var target: _SUIGestureTarget?
    init(recognizer: R.UIGestureRecognizerType, coordinator: R.Coordinator, refs: UIGestureRecognizerRepresentableCoordinateSpaceConverter.Refs, latest: R) {
        self.recognizer = recognizer; self.coordinator = coordinator; self.refs = refs; self.latest = latest
    }
    var context: UIGestureRecognizerRepresentableContext<R> {
        UIGestureRecognizerRepresentableContext(converter: UIGestureRecognizerRepresentableCoordinateSpaceConverter(refs: refs), coordinator: coordinator)
    }
    @MainActor func fire() { latest.handleUIGestureRecognizerAction(recognizer, context: context) }
}
@available(iOS 18.0, *)
final class _GestureRepresentableNode<R: UIGestureRecognizerRepresentable>: _WrapperNode {
    let rep: R, key: String
    unowned let graph: _Graph
    init(path: String, rep: R, graph: _Graph, child: _Node) {
        self.rep = rep; self.graph = graph; key = path + "#uigr"
        super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIGestureView(frame: .zero) }
        graph.usedKeys.insert(key)
        let s: _GestureRepresentableState<R>
        if let old = graph.storage[key] as? _GestureRepresentableState<R> { s = old; s.latest = rep }
        else {
            let refs = UIGestureRecognizerRepresentableCoordinateSpaceConverter.Refs()
            refs.view = v
            let coord = rep.makeCoordinator(converter: UIGestureRecognizerRepresentableCoordinateSpaceConverter(refs: refs))
            let ctx = UIGestureRecognizerRepresentableContext<R>(converter: UIGestureRecognizerRepresentableCoordinateSpaceConverter(refs: refs), coordinator: coord)
            let r = rep.makeUIGestureRecognizer(context: ctx)
            refs.recognizer = r
            s = _GestureRepresentableState(recognizer: r, coordinator: coord, refs: refs, latest: rep)
            let t = _SUIGestureTarget { [weak s] _ in MainActor.assumeIsolated { s?.fire() } }
            s.target = t
            r.addTarget(t, action: #selector(_SUIGestureTarget.fired(_:)))
            graph.storage[key] = s
        }
        s.refs.view = v
        if s.recognizer.view !== v { s.recognizer.view?.removeGestureRecognizer(s.recognizer); v.addGestureRecognizer(s.recognizer) }
        rep.updateUIGestureRecognizer(s.recognizer, context: s.context)
        return v
    }
}

// MARK: - UIHostingSceneDelegate

/// A UIKit scene delegate whose scenes show SwiftUI scenes (`rootScene`'s window groups). When UIKit connects a scene
/// to it (a `UISceneConfiguration` naming it as `delegateClass`, or a `UISceneSessionActivationRequest(hostingDelegateClass:)`),
/// SwiftUI makes the window for the requested group (the first one by default) before the delegate's own
/// `scene(_:willConnectTo:options:)`, which still gets every UIKit callback.
@available(iOS 26.0, *)
public protocol UIHostingSceneDelegate: UISceneDelegate {
    associatedtype RootScene: Scene
    @SceneBuilder static var rootScene: RootScene { get }
}

@available(iOS 26.0, *)
@MainActor func _hostingGroups<D: UIHostingSceneDelegate>(_ d: D.Type) -> [(id: String?, make: () -> AnyView)] {
    let c = _SceneCollector()
    let s = D.rootScene
    if let n = s as? _SceneNode { n._collect(c) } else if let r = s as? _SceneRoot { c.groups.append((nil, { r._rootView })) }
    return c.groups
}

/// UIKit (UIApplication.m) calls this when it connects a scene, before the delegate's willConnect: a
/// UIHostingSceneDelegate's scene gets its SwiftUI window.
@_cdecl("isim_swiftui_connect_hosting_scene")
public func _isimConnectHostingScene(_ scenePtr: UnsafeMutableRawPointer, _ optionsPtr: UnsafeMutableRawPointer) {
    let scene = Unmanaged<UIScene>.fromOpaque(scenePtr).takeUnretainedValue()
    let options = Unmanaged<UIScene.ConnectionOptions>.fromOpaque(optionsPtr).takeUnretainedValue()
    guard #available(iOS 26.0, *), let d = scene.delegate as? any UIHostingSceneDelegate else { return }
    MainActor.assumeIsolated { _connectHosting(d, scene, options) }
}
@available(iOS 26.0, *)
@MainActor func _connectHosting<D: UIHostingSceneDelegate>(_ d: D, _ scene: UIScene, _ options: UIScene.ConnectionOptions) {
    let t = D.self
    guard let ws = scene as? UIWindowScene else { return }
    // the delegate's groups join the app's (a UIKit app has none of its own)
    for g in _hostingGroups(t) where !_SUIWindows.groups.contains(where: { $0.id != nil && $0.id == g.id }) { _SUIWindows.groups.append(g) }
    let opened = options.userActivities.first { $0.activityType == _SUIWindows.activityType }
    let info = opened?.userInfo
    var id = info?["id"] as? String
    if id?.isEmpty != false { id = _hostingGroups(t).first?.id }
    let root = _SUIWindows.root(id: id, value: info?["value"] as? Data, session: ws.session)
    let make = root.make
    let h = _SUIHostingController(root: { make() })
    root.box.changed = { [weak h] in h?.graph.invalidate() }
    let w = UIWindow(windowScene: ws)
    w.rootViewController = h
    w.tintColor = _accentUIColor()
    if let sd = scene.delegate as? NSObject, sd.responds(to: #selector(setter: UIWindowSceneDelegate.window)) { sd.setValue(w, forKey: "window") }
    else { objc_setAssociatedObject(ws, &_kHostingWindow, w, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    NSLog("isim SwiftUI: hosting scene %@ shows %@", NSStringFromClass(t), id ?? "the first window group")
    w.makeKeyAndVisible()
}
nonisolated(unsafe) private var _kHostingWindow: UInt8 = 0

@available(iOS 26.0, *)
extension UISceneSessionActivationRequest {
    /// A request for a scene of `hostingDelegateClass`, showing the first window group of its `rootScene`.
    public convenience init?<D: UIHostingSceneDelegate>(hostingDelegateClass: D.Type) {
        guard let first = MainActor.assumeIsolated({ _hostingGroups(D.self).first }) else { return nil }
        self.init(_isimHosting: D.self, id: first.id, value: nil)
    }
    /// A request for the window group `id` of `hostingDelegateClass`'s `rootScene` (nil when it has none).
    public convenience init?<D: UIHostingSceneDelegate>(hostingDelegateClass: D.Type, id: String) {
        guard MainActor.assumeIsolated({ _hostingGroups(D.self).contains { $0.id == id } }) else { return nil }
        self.init(_isimHosting: D.self, id: id, value: nil)
    }
    /// A request for the window group `id` presenting `value`.
    public convenience init?<H: UIHostingSceneDelegate, D: Codable & Hashable>(hostingDelegateClass: H.Type, id: String, value: D) {
        guard MainActor.assumeIsolated({ _hostingGroups(H.self).contains { $0.id == id } }), let data = try? JSONEncoder().encode(value) else { return nil }
        self.init(_isimHosting: H.self, id: id, value: data)
    }
    /// A request for the window group presenting values of `D` (`WindowGroup(for:)`).
    public convenience init?<H: UIHostingSceneDelegate, D: Codable & Hashable>(hostingDelegateClass: H.Type, value: D) {
        let id = _SUIWindows.typeID(D.self)
        guard MainActor.assumeIsolated({ _hostingGroups(H.self).contains { $0.id == id } }), let data = try? JSONEncoder().encode(value) else { return nil }
        self.init(_isimHosting: H.self, id: id, value: data)
    }
    convenience init(_isimHosting cls: AnyClass, id: String?, value: Data?) {
        self.init(_isimRole: .windowApplication)
        let a = NSUserActivity(activityType: _SUIWindows.activityType)
        var info: [String: Any] = ["id": id ?? "", "isim.hostingDelegate": NSStringFromClass(cls)]
        if let value { info["value"] = value }
        a.userInfo = info
        userActivity = a
    }
}
