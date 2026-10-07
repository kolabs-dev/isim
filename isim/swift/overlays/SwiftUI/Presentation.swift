// isim SwiftUI: modal presentations — sheet, fullScreenCover, alert, confirmationDialog — on UIKit
// (page sheets with swipe-to-dismiss, full-screen covers, UIAlertController alerts and action sheets).
// Sheet content gets the presenter's environment (environment objects, tint, ...) and a `dismiss` that
// closes it; it updates when the presenter's state changes. Not implemented: detents (sheets are large),
// popovers (shown as sheets), text fields inside alerts.
import UIKit

/// Hosts presented SwiftUI content; tells the presenter when UIKit dismissed it (swipe down).
final class _SUIPresentedHostingController: UIHostingController<AnyView> {
    var onUIKitDismiss: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if presentingViewController == nil { let f = onUIKitDismiss; onUIKitDismiss = nil; f?() }
    }
}

@MainActor final class _PresentationState {
    var controller: UIViewController?
    var popoverDelegate: _PopoverAdaptation?
    var zoomSource: CGRect?
    let transition = _PresentationTransition()
    let sheetConfig = _SheetConfig()          // presentationDetents & co (Navigation+More.swift)
    var lastContentID: AnyHashable?
}

@MainActor func _topController(from view: UIView?) -> UIViewController? {
    let window = view?.window ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow) }.first
    var top = window?.rootViewController
    while let p = top?.presentedViewController { top = p }
    return top
}

/// Environment carried into presented content.
struct _PresentedContent<Content: View>: View, _PrimitiveView {
    let environment: EnvironmentValues
    let dismiss: () -> Void
    let content: Content
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        var env = environment
        env.dismiss = DismissAction(action: dismiss)
        env.isPresented = true
        env.colorScheme = ctx.environment.colorScheme
        return _resolve(content, _Context(graph: ctx.graph, path: ctx.path, environment: env, nav: nil))
    }
}

extension View {
    // MARK: sheet / fullScreenCover
    public func sheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        _present(key: "sheet", isPresented: isPresented.wrappedValue, id: nil, fullScreen: false,
                 setPresented: { isPresented.wrappedValue = $0 }, onDismiss: onDismiss, content: { AnyView(content()) })
    }
    public func sheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        let it = item.wrappedValue
        return _present(key: "sheet", isPresented: it != nil, id: it.map { AnyHashable($0.id) }, fullScreen: false,
                        setPresented: { if !$0 { item.wrappedValue = nil } }, onDismiss: onDismiss, content: { it.map { AnyView(content($0)) } ?? AnyView(EmptyView()) })
    }
    public func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        _present(key: "cover", isPresented: isPresented.wrappedValue, id: nil, fullScreen: true,
                 setPresented: { isPresented.wrappedValue = $0 }, onDismiss: onDismiss, content: { AnyView(content()) })
    }
    public func fullScreenCover<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        let it = item.wrappedValue
        return _present(key: "cover", isPresented: it != nil, id: it.map { AnyHashable($0.id) }, fullScreen: true,
                        setPresented: { if !$0 { item.wrappedValue = nil } }, onDismiss: onDismiss, content: { it.map { AnyView(content($0)) } ?? AnyView(EmptyView()) })
    }
    /// A popover anchored to this view with an arrow (iPad); on iPhone a sheet, unless the content asks for
    /// `presentationCompactAdaptation(.popover)` / `(.none)`.
    public func popover<Content: View>(isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top,
                                       @ViewBuilder content: @escaping () -> Content) -> some View {
        _present(key: "popover", isPresented: isPresented.wrappedValue, id: nil, fullScreen: false,
                 setPresented: { isPresented.wrappedValue = $0 }, onDismiss: nil, content: { AnyView(content()) }, popover: _PopoverAnchor(anchor: attachmentAnchor, edge: arrowEdge))
    }
    public func popover<Item: Identifiable, Content: View>(item: Binding<Item?>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top,
                                                          @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        let it = item.wrappedValue
        return _present(key: "popover", isPresented: it != nil, id: it.map { AnyHashable($0.id) }, fullScreen: false,
                        setPresented: { if !$0 { item.wrappedValue = nil } }, onDismiss: nil, content: { it.map { AnyView(content($0)) } ?? AnyView(EmptyView()) },
                        popover: _PopoverAnchor(anchor: attachmentAnchor, edge: arrowEdge))
    }
    // presentationDetents, presentationDragIndicator, presentationCornerRadius, presentationBackground: Navigation+More.swift
    public func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View {
        _modify { ctx, c in
            let node = _resolve(c, ctx.child("idd"))
            ctx.environment._sheetConfig?.dismissDisabled = isDisabled
            ctx.graph.postRender.append { [weak g = ctx.graph] in
                var r: UIResponder? = g?.hostView
                while let x = r, !(x is UIViewController) { r = x.next }
                if let vc = r as? UIViewController { vc.isModalInPresentation = isDisabled }
                else if let h = g?.hostView, let top = _topController(from: h), top.view === h { top.isModalInPresentation = isDisabled }
            }
            return node
        }
    }

    func _present(key: String, isPresented: Bool, id: AnyHashable?, fullScreen: Bool, setPresented: @escaping (Bool) -> Void,
                  onDismiss: (() -> Void)?, content: @escaping () -> AnyView, popover: _PopoverAnchor? = nil) -> some View {
        _modify { ctx, c in
            let skey = ctx.path + "#" + key
            let g = ctx.graph
            g.usedKeys.insert(skey)
            let state = (g.storage[skey] as? _PresentationStateBox)?.state ?? _PresentationState()
            g.storage[skey] = _PresentationStateBox(state)
            var env = ctx.environment
            env._sheetConfig = fullScreen ? nil : state.sheetConfig
            env._presentationTransition = state.transition
            var node = _resolve(c, ctx.child("pr"))
            if popover != nil { node = _PresentationAnchorNode(path: ctx.path + "/anchor", child: node) }   // the popover's source view
            let anchorKey = node.viewKey
            g.postRender.append { [weak g] in
                let wrapped = { AnyView(_PresentedContent(environment: env, dismiss: { setPresented(false) }, content: content())) }
                if isPresented {
                    if let hc = state.controller as? _SUIPresentedHostingController, state.lastContentID == id {
                        // presenter state changed: refresh the content
                        hc.rootView = state.sheetConfig.custom ? AnyView(_DetentSheet(config: state.sheetConfig, content: { wrapped() }, dismiss: { setPresented(false) })) : wrapped()
                    } else {
                        if let old = state.controller { old.dismiss(animated: false, completion: nil) }
                        let hc = _SUIPresentedHostingController(rootView: wrapped())
                        hc.modalPresentationStyle = fullScreen ? .fullScreen : .pageSheet
                        state.transition.kind = .push
                        if let pop = popover, let source = g?.views[anchorKey] {      // popover: anchored, sized to its content
                            _preparePopover(hc, state, pop, source: source, from: g?.hostView)
                        } else if !fullScreen {        // detents other than .large: isim's own card (Navigation+More.swift)
                            if !_prepareDetentSheet(hc, state.sheetConfig, from: g?.hostView, content: { wrapped() }, dismiss: { setPresented(false) }) {
                                _applySizing(hc, state.sheetConfig)          // presentationSizing (iPad)
                            }
                        } else { _prepareZoomCover(hc, state, from: g?.hostView) }
                        hc.onUIKitDismiss = { [weak state] in
                            guard let state, state.controller != nil else { return }
                            state.controller = nil
                            setPresented(false); onDismiss?()
                        }
                        state.controller = hc; state.lastContentID = id
                        let zoom = state.zoomSource
                        _topController(from: g?.hostView)?.present(hc, animated: zoom == nil, completion: nil)
                        if let src = zoom { _zoomIn(hc.view, from: src) }           // navigationTransition(.zoom) on a cover
                    }
                } else if let hc = state.controller {
                    state.controller = nil
                    (hc as? _SUIPresentedHostingController)?.onUIKitDismiss = nil
                    if state.zoomSource != nil, case .zoom(let key) = state.transition.kind, let src = _ZoomSources.views[key]?.view, src.window != nil {
                        _zoomOut(hc.view, to: src.convert(src.bounds, to: nil)) { hc.dismiss(animated: false, completion: nil) }
                    } else { hc.dismiss(animated: true, completion: nil) }
                    state.zoomSource = nil
                    onDismiss?()
                }
            }
            return node
        }
    }

    // MARK: alert / confirmationDialog
    public func alert<A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View {
        _alert(Text(titleKey), isPresented: isPresented, style: .alert, actions: actions(), message: nil as EmptyView?)
    }
    @_disfavoredOverload public func alert<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View {
        _alert(Text(title), isPresented: isPresented, style: .alert, actions: actions(), message: nil as EmptyView?)
    }
    public func alert<A: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View {
        _alert(title, isPresented: isPresented, style: .alert, actions: actions(), message: nil as EmptyView?)
    }
    public func alert<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        _alert(Text(titleKey), isPresented: isPresented, style: .alert, actions: actions(), message: message())
    }
    @_disfavoredOverload public func alert<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        _alert(Text(title), isPresented: isPresented, style: .alert, actions: actions(), message: message())
    }
    public func alert<A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        _alert(title, isPresented: isPresented, style: .alert, actions: actions(), message: message())
    }
    public func alert<A: View, M: View, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?,
                                           @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View {
        _alert(Text(titleKey), isPresented: isPresented, style: .alert, actions: data.map(actions), message: data.map(message))
    }
    @_disfavoredOverload public func alert<S: StringProtocol, A: View, M: View, T>(_ title: S, isPresented: Binding<Bool>, presenting data: T?,
                                           @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View {
        _alert(Text(title), isPresented: isPresented, style: .alert, actions: data.map(actions), message: data.map(message))
    }
    public func alert<A: View, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View {
        _alert(Text(titleKey), isPresented: isPresented, style: .alert, actions: data.map(actions), message: nil as EmptyView?)
    }
    public func confirmationDialog<A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                            @ViewBuilder actions: () -> A) -> some View {
        _alert(titleVisibility == .visible ? Text(titleKey) : nil, isPresented: isPresented, style: .actionSheet, actions: actions(), message: nil as EmptyView?)
    }
    @_disfavoredOverload public func confirmationDialog<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                            @ViewBuilder actions: () -> A) -> some View {
        _alert(titleVisibility == .visible ? Text(title) : nil, isPresented: isPresented, style: .actionSheet, actions: actions(), message: nil as EmptyView?)
    }
    public func confirmationDialog<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                                     @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        _alert(titleVisibility == .visible ? Text(titleKey) : nil, isPresented: isPresented, style: .actionSheet, actions: actions(), message: message())
    }
    @_disfavoredOverload public func confirmationDialog<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                                     @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        _alert(titleVisibility == .visible ? Text(title) : nil, isPresented: isPresented, style: .actionSheet, actions: actions(), message: message())
    }

    func _alert<A: View, M: View>(_ title: Text?, isPresented: Binding<Bool>, style: UIAlertController.Style, actions: A?, message: M?) -> some View {
        _modify { ctx, c in
            let skey = ctx.path + "#alert"
            let g = ctx.graph
            g.usedKeys.insert(skey)
            let state = (g.storage[skey] as? _PresentationStateBox)?.state ?? _PresentationState()
            g.storage[skey] = _PresentationStateBox(state)
            let node = _resolve(c, ctx.child("al"))
            let want = isPresented.wrappedValue
            // buttons and message text, evaluated like any view content (localized, with the environment)
            var buttons: [(String, ButtonRole?, () -> Void)] = []
            var fields: [_TextFieldNode] = []
            var messageText: String?
            if want {
                if let actions {
                    let an = _resolve(actions, ctx.child("alert-actions"))
                    buttons = _collectButtons(an); fields = style == .alert ? _collectFields(an) : []
                }
                if let message { messageText = _collectText(_resolve(message, ctx.child("alert-message"))).joined(separator: "\n") }
            }
            let titleString = title.map { $0.string }
            g.postRender.append { [weak g] in
                if want, state.controller == nil {
                    let ac = UIAlertController(title: titleString, message: messageText, preferredStyle: style)
                    for f in fields {                  // TextField / SecureField in the actions: the alert's text fields
                        ac.addTextField { tf in
                            tf.placeholder = f.placeholder; tf.text = f.text.wrappedValue; tf.isSecureTextEntry = f.secure
                            tf.keyboardType = f.traits.keyboardType
                        }
                    }
                    if buttons.isEmpty { buttons = [("OK", nil, {})] }
                    if style == .actionSheet, !buttons.contains(where: { $0.1 == .cancel }) { buttons.append(("Cancel", .cancel, {})) }
                    for (label, role, action) in buttons {
                        let st: UIAlertAction.Style = role == .destructive ? .destructive : role == .cancel ? .cancel : .default
                        ac.addAction(UIAlertAction(title: label, style: st) { [weak state, weak ac] _ in
                            for (f, tf) in zip(fields, ac?.textFields ?? []) { f.text.wrappedValue = tf.text ?? "" }    // typed text, before the action
                            state?.controller = nil
                            isPresented.wrappedValue = false
                            action()
                        })
                    }
                    state.controller = ac
                    _topController(from: g?.hostView)?.present(ac, animated: true, completion: nil)
                } else if !want, let ac = state.controller {
                    state.controller = nil
                    if ac.presentingViewController != nil { ac.dismiss(animated: true, completion: nil) }
                }
            }
            return node
        }
    }
}

final class _PresentationStateBox { let state: _PresentationState; init(_ s: _PresentationState) { state = s } }

@MainActor func _collectButtons(_ n: _Node) -> [(String, ButtonRole?, () -> Void)] {
    if let b = n as? _ButtonNode { return [(_collectText(b).joined(separator: " "), b.role, b.action)] }
    return n.children.flatMap { _collectButtons($0) }
}
@MainActor func _collectFields(_ n: _Node) -> [_TextFieldNode] {
    if let f = n as? _TextFieldNode { return [f] }
    return n.children.flatMap { _collectFields($0) }
}
@MainActor func _collectText(_ n: _Node) -> [String] {
    if let t = n as? _TextNode { return [t.text] }
    if let r = n as? _RichTextNode { return [r.plain] }
    return n.children.flatMap { _collectText($0) }
}

public struct PresentationDetent: Hashable, Sendable {
    let id: String
    public static let large = PresentationDetent(id: "large"), medium = PresentationDetent(id: "medium")
    public static func fraction(_ f: CGFloat) -> PresentationDetent { PresentationDetent(id: "f\(f)") }
    public static func height(_ h: CGFloat) -> PresentationDetent { PresentationDetent(id: "h\(h)") }
}
public enum PopoverAttachmentAnchor: Sendable {
    case rect(Anchor<CGRect>.Source), point(UnitPoint)
}
// Anchor: Preferences.swift
