// isim SwiftUI: more presentations.
// - popover: a UIKit popover anchored to the modified view, sized to its content, with the arrow on `arrowEdge`
//   (iPad); on iPhone a sheet unless the content asks for presentationCompactAdaptation(.popover / .none).
// - presentationSizing (iOS 18): .form / .page / .fitted sheets on iPad (iPhone: page sheets, like iOS).
// - navigationTransition(.zoom) on a fullScreenCover: grows out of the matchedTransitionSource view, shrinks back.
// - inspector: on iPad a trailing column beside the content (inspectorColumnWidth), on iPhone a sheet.
import UIKit

struct _PopoverAnchor { let anchor: PopoverAttachmentAnchor; let edge: Edge }

/// The view a popover points at.
final class _PresentationAnchorNode: _WrapperNode {
    override var layoutPriority: Double { child.layoutPriority }
    override var ignoresSafeArea: Bool { child.ignoresSafeArea }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}

final class _PopoverAdaptation: NSObject, UIPopoverPresentationControllerDelegate {
    let style: UIModalPresentationStyle
    init(style: UIModalPresentationStyle) { self.style = style }
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle { style }
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { style }
}

/// Lays the content out off screen (to learn its size and modifiers), then makes `hc` a popover from `source`.
@MainActor func _preparePopover(_ hc: _SUIPresentedHostingController, _ state: _PresentationState, _ pop: _PopoverAnchor, source: UIView, from presenter: UIView?) {
    let screen = presenter?.window?.bounds.size ?? UIScreen.main.bounds.size
    hc.view.frame = CGRect(x: 0, y: 0, width: min(screen.width - 40, 400), height: min(screen.height * 0.7, 600))
    hc.view.setNeedsLayout(); hc.view.layoutIfNeeded()
    var s = hc.sizeThatFits(in: CGSize(width: 0, height: 0))
    s.width = min(max(s.width, 120), screen.width - 40); s.height = min(max(s.height, 44), screen.height * 0.7)
    hc.preferredContentSize = CGSize(width: ceil(s.width), height: ceil(s.height))
    hc.modalPresentationStyle = .popover
    if let pc = hc.popoverPresentationController {
        pc.sourceView = source
        switch pop.anchor {
        case .point(let u): pc.sourceRect = CGRect(x: source.bounds.width * u.x, y: source.bounds.height * u.y, width: 1, height: 1)
        default: pc.sourceRect = source.bounds
        }
        switch pop.edge {
        case .top: pc.permittedArrowDirections = .up
        case .bottom: pc.permittedArrowDirections = .down
        case .leading: pc.permittedArrowDirections = .left
        case .trailing: pc.permittedArrowDirections = .right
        @unknown default: pc.permittedArrowDirections = .any
        }
        // on iPhone: .popover / .none keep the popover, .sheet / .fullScreenCover adapt, automatic: a sheet
        let a = state.sheetConfig.compactAdaptation
        let d = _PopoverAdaptation(style: a == 1 || a == 2 ? .none : a == 4 ? .fullScreen : .pageSheet)
        state.popoverDelegate = d
        pc.delegate = d
    }
}

/// presentationSizing on iPad: form sheets (fixed or fitted to the content) or page sheets.
@MainActor func _applySizing(_ hc: _SUIPresentedHostingController, _ config: _SheetConfig) {
    guard _isimPad, config.sizing != 0 else { return }
    switch config.sizing {
    case 1: hc.modalPresentationStyle = .formSheet
    case 2: hc.modalPresentationStyle = .pageSheet
    default:
        hc.modalPresentationStyle = .formSheet
        let s = hc.sizeThatFits(in: CGSize(width: 0, height: 0))
        hc.preferredContentSize = CGSize(width: ceil(min(max(s.width, 200), 700)), height: ceil(min(max(s.height, 100), 800)))
    }
}

/// A full-screen cover whose content asks for navigationTransition(.zoom): presented without UIKit's slide, then
/// grown out of the source view.
@MainActor func _prepareZoomCover(_ hc: _SUIPresentedHostingController, _ state: _PresentationState, from presenter: UIView?) {
    guard let w = presenter?.window else { return }
    hc.view.frame = w.bounds
    hc.view.setNeedsLayout(); hc.view.layoutIfNeeded()
    guard case .zoom(let key) = state.transition.kind, let src = _ZoomSources.views[key]?.view, src.window === w else { return }
    state.zoomSource = src.convert(src.bounds, to: nil)
}
@MainActor func _zoomIn(_ v: UIView, from src: CGRect) {
    let full = v.frame
    UIView.performWithoutAnimation { v.transform = _zoomTransform(from: full, to: src); v.layer.cornerRadius = 40; v.clipsToBounds = true; v.alpha = 0.4 }
    UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut], animations: { v.transform = .identity; v.layer.cornerRadius = 0; v.alpha = 1 },
                   completion: { _ in v.clipsToBounds = false })
}
@MainActor func _zoomOut(_ v: UIView, to src: CGRect, completion: @escaping () -> Void) {
    v.clipsToBounds = true
    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
        v.transform = _zoomTransform(from: v.frame, to: src); v.layer.cornerRadius = 40; v.alpha = 0
    }, completion: { _ in completion() })
}

// MARK: - presentationSizing (iOS 18)

@available(iOS 18.0, *)
public protocol PresentationSizing {}
@available(iOS 18.0, *)
public struct AutomaticPresentationSizing: PresentationSizing { public init() {} }
@available(iOS 18.0, *)
public struct FormPresentationSizing: PresentationSizing { public init() {} }
@available(iOS 18.0, *)
public struct PagePresentationSizing: PresentationSizing { public init() {} }
@available(iOS 18.0, *)
public struct FittedPresentationSizing: PresentationSizing { public init() {} }
@available(iOS 18.0, *)
extension PresentationSizing where Self == AutomaticPresentationSizing { public static var automatic: AutomaticPresentationSizing { .init() } }
@available(iOS 18.0, *)
extension PresentationSizing where Self == FormPresentationSizing { public static var form: FormPresentationSizing { .init() } }
@available(iOS 18.0, *)
extension PresentationSizing where Self == PagePresentationSizing { public static var page: PagePresentationSizing { .init() } }
@available(iOS 18.0, *)
extension PresentationSizing where Self == FittedPresentationSizing { public static var fitted: FittedPresentationSizing { .init() } }
@available(iOS 18.0, *)
extension PresentationSizing {
    /// isim: the sheet keeps its size class; these refine Apple's layout and are accepted.
    public func fitted(horizontal: Bool, vertical: Bool) -> FittedPresentationSizing { FittedPresentationSizing() }
    public func sticky(horizontal: Bool = false, vertical: Bool = false) -> Self { self }
}
extension View {
    /// How big a sheet is on iPad: `.form` (a centred form card), `.page` (the page card), `.fitted` (the content's
    /// ideal size). On iPhone sheets fill the width, like iOS.
    @available(iOS 18.0, *)
    public func presentationSizing(_ sizing: some PresentationSizing) -> some View {
        let id = sizing is FormPresentationSizing ? 1 : sizing is PagePresentationSizing ? 2 : sizing is FittedPresentationSizing ? 3 : 0
        return _modify { ctx, c in ctx.environment._sheetConfig?.sizing = id; return _resolve(c, ctx.child("psz")) }
    }
}

// MARK: - inspector

@MainActor final class _InspectorConfig { var width: CGFloat? }
struct _InspectorConfigKey: EnvironmentKey { static var defaultValue: _InspectorConfig? { nil } }
extension EnvironmentValues { var _inspectorConfig: _InspectorConfig? { get { self[_InspectorConfigKey.self] } set { self[_InspectorConfigKey.self] = newValue } } }

extension View {
    /// iPad: a trailing column beside the content (320 pt, or inspectorColumnWidth); iPhone: a sheet.
    public func inspector<V: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> V) -> some View {
        AnyView(_modify { ctx, c in
            guard _isimPad else { return _resolve(c.sheet(isPresented: isPresented, content: content), ctx.child("insp-sheet")) }
            let main = _resolve(c, ctx.child("insp-main"))
            guard isPresented.wrappedValue else { return main }
            let cfg = _InspectorConfig()
            var env = ctx.environment
            env._inspectorConfig = cfg
            env.dismiss = DismissAction { isPresented.wrappedValue = false }
            let side = _resolve(AnyView(content()), _Context(graph: ctx.graph, path: ctx.path + "/insp-column", environment: env, nav: nil))
            let n = _InspectorNode(path: ctx.path, main: main, inspector: side, width: cfg.width ?? 320)
            n.safeTop = main.ignoresSafeArea ? ctx.graph.safeArea.top : 0
            return n
        })
    }
    public func inspectorColumnWidth(_ width: CGFloat) -> some View {
        _modify { ctx, c in ctx.environment._inspectorConfig?.width = width; return _resolve(c, ctx.child("icw")) }
    }
    public func inspectorColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View { inspectorColumnWidth(ideal) }
}
/// Content and the inspector column side by side (iPad).
final class _InspectorNode: _Node {
    let main: _Node, inspector: _Node, width: CGFloat
    var safeTop: CGFloat = 0
    init(path: String, main: _Node, inspector: _Node, width: CGFloat) {
        self.main = main; self.inspector = inspector; self.width = width
        super.init(path: path, children: [main, inspector])
    }
    override var ignoresSafeArea: Bool { main.ignoresSafeArea }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 700, 1e6), height: min(p.height ?? 700, 1e6)) }
    override func place(_ rect: CGRect) {
        frame = rect
        let w = min(width, rect.width / 2)
        let mr = CGRect(x: 0, y: 0, width: rect.width - w, height: rect.height)
        if main.ignoresSafeArea { main.place(mr) }
        else { let s = main.sizeThatFits(_Proposal(width: mr.width, height: mr.height)); main.place(_align(CGSize(width: min(s.width, mr.width), height: min(s.height, mr.height)), in: mr, .center)) }
        let ir = CGRect(x: rect.width - w, y: 0, width: w, height: rect.height)
        let s = inspector.sizeThatFits(_Proposal(width: ir.width - 32, height: ir.height - 32 - safeTop))
        inspector.place(CGRect(x: ir.minX + 16, y: ir.minY + 16 + safeTop, width: min(s.width, ir.width - 32), height: min(s.height, ir.height - 32 - safeTop)))
    }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        g.mount(main, in: view, order: 0)
        let col = g.view(path + "|insp-bg") { UIView() }
        col.backgroundColor = .secondarySystemBackground
        col.accessibilityIdentifier = "isim-inspector"
        if col.superview !== view { view.addSubview(col) } else { view.bringSubviewToFront(col) }
        let w = min(width, view.bounds.width / 2)
        col.frame = CGRect(x: view.bounds.width - w, y: 0, width: w, height: view.bounds.height)
        let sep = g.view(path + "|insp-sep") { UIView() }
        sep.backgroundColor = .separator
        if sep.superview !== view { view.addSubview(sep) } else { view.bringSubviewToFront(sep) }
        sep.frame = CGRect(x: col.frame.minX - 0.5, y: 0, width: 0.5, height: view.bounds.height)
        g.mount(inspector, in: view, order: 1)
    }
}
