// isim TipKit: the tip views (adapted, drawn by isim's SwiftUI like iOS's): an inline TipView, popoverTip (a popover
// with an arrow, also on iPhone), the UIKit views over them (TipUIView, TipUIPopoverViewController,
// TipUICollectionViewCell / TipUICollectionReusableView) and their styling (TipViewStyle, .miniTip, tipBackground,
// tipCornerRadius, tipImageSize, tipImageStyle).
// A tip shows: its image (in the accent colour, or tipImageStyle) beside the title (headline) and message (secondary),
// a close button (xmark: invalidates it with .tipClosed) and its actions below a divider (in the accent colour), on the
// grouped background colour (iOS 26: rounder corners). A view shows a tip while it is available (and isPresented,
// when given), counts each appearance and its time on screen (MaxDisplayCount / MaxDisplayDuration) and redraws when
// the datastore changes. Accessibility identifiers: tip-ID (its title), tipclose-ID, tipaction-ID-ACTIONID.
import Foundation
import SwiftUI
import UIKit
import isim_host

// MARK: - styling

struct _TipLook {
    var style: AnyTipViewStyle?
    var background: AnyShapeStyle?
    var cornerRadius: CGFloat?
    var imageSize: CGSize?
    var imageStyles: [AnyShapeStyle] = []
}
struct _TipLookKey: EnvironmentKey { static var defaultValue: _TipLook { _TipLook() } }
extension EnvironmentValues {
    var _tipLook: _TipLook { get { self[_TipLookKey.self] } set { self[_TipLookKey.self] = newValue } }
}
extension View {
    public func tipViewStyle(_ style: some TipViewStyle) -> some View { transformEnvironment(\._tipLook) { $0.style = AnyTipViewStyle(style) } }
    public func tipBackground<S: ShapeStyle>(_ style: S) -> some View { transformEnvironment(\._tipLook) { $0.background = AnyShapeStyle(style) } }
    public func tipCornerRadius(_ cornerRadius: CGFloat, antialiased: Bool = true) -> some View { transformEnvironment(\._tipLook) { $0.cornerRadius = cornerRadius } }
    public func tipImageSize(_ size: CGSize) -> some View { transformEnvironment(\._tipLook) { $0.imageSize = size } }
    public func tipImageStyle<S: ShapeStyle>(_ style: S) -> some View { transformEnvironment(\._tipLook) { $0.imageStyles = [AnyShapeStyle(style)] } }
    public func tipImageStyle<S1: ShapeStyle, S2: ShapeStyle>(_ primary: S1, _ secondary: S2) -> some View {
        transformEnvironment(\._tipLook) { $0.imageStyles = [AnyShapeStyle(primary), AnyShapeStyle(secondary)] }
    }
    public func tipImageStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View {
        transformEnvironment(\._tipLook) { $0.imageStyles = [AnyShapeStyle(primary), AnyShapeStyle(secondary), AnyShapeStyle(tertiary)] }
    }
    /// how the views behind a popover tip take touches while it shows
    @available(iOS 18.0, *)
    public func tipBackgroundInteraction(_ interaction: PresentationBackgroundInteraction) -> some View { presentationBackgroundInteraction(interaction) }
}

public protocol TipViewStyle {
    associatedtype Body: View
    typealias Configuration = TipViewStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}
public struct TipViewStyleConfiguration {
    public let tip: any Tip
    public var title: Text?
    public var message: Text?
    public var image: Image?
    public var actions: [Tips.Action]
}
struct AnyTipViewStyle {
    let make: (TipViewStyleConfiguration) -> AnyView
    init<S: TipViewStyle>(_ s: S) { make = { AnyView(s.makeBody(configuration: $0)) } }
}
/// a compact tip: the image and title on one line, the message below
public struct MiniTipViewStyle: TipViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.image?.foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                configuration.title?.font(.subheadline.weight(.semibold))
                configuration.message?.font(.footnote).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
extension TipViewStyle where Self == MiniTipViewStyle {
    public static var miniTip: MiniTipViewStyle { MiniTipViewStyle() }
}

// MARK: - the views

/// redraws when the datastore changes
final class _TipWatcher: ObservableObject {
    @Published var tick = 0
    var token: NSObjectProtocol?
    init() {
        token = NotificationCenter.default.addObserver(forName: _TipStore.changed, object: nil, queue: .main) { [weak self] _ in self?.tick += 1 }
    }
    deinit { if let t = token { NotificationCenter.default.removeObserver(t) } }
}
@inline(__always) func _tipOS() -> Int { Int(isim_os_version()) / 10000 }

/// a tip's card: image, title, message, close button, actions
struct _TipCard: View {
    let tip: any Tip
    let popover: Bool
    let action: (Tips.Action) -> Void
    let close: () -> Void
    @Environment(\._tipLook) var look
    var body: some View {
        let actions = tip.actions.enumerated().map { $1.at($0) }
        let config = TipViewStyleConfiguration(tip: tip, title: tip.title, message: tip.message, image: tip.image, actions: actions)
        let glass = _tipOS() >= 26
        let radius = look.cornerRadius ?? (popover ? 0 : glass ? 24 : 13)
        Group {
            if let style = look.style {
                style.make(config).accessibilityIdentifier("tip-\(tip.id)")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        if let image = tip.image {
                            styledImage(image)
                                .frame(width: look.imageSize?.width ?? 36, height: look.imageSize?.height ?? 36, alignment: .top)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            tip.title.font(.headline).foregroundColor(.primary).accessibilityIdentifier("tip-\(tip.id)")
                            if let m = tip.message { m.font(.subheadline).foregroundColor(.secondary) }
                        }
                        Spacer(minLength: 0)
                        Button(action: close) {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(Color(UIColor.tertiaryLabel))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)                  /* in a List row: its own target */
                        .accessibilityIdentifier("tipclose-\(tip.id)")
                        .accessibilityLabel("Close")
                    }
                    .padding(16)
                    ForEach(actions) { a in
                        Divider().padding(.leading, 16)
                        Button {
                            NSLog("isim TipKit: %@ action %@", tip.id, a.id)
                            a.handler(); action(a)
                        } label: {
                            a.label().font(.body).foregroundColor(.accentColor).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("tipaction-\(tip.id)-\(a.id)")
                    }
                }
            }
        }
        .frame(maxWidth: popover ? 340 : .infinity, alignment: .leading)
        .background(background(radius: radius, glass: glass))
    }
    @ViewBuilder func styledImage(_ image: Image) -> some View {
        let i = image.resizable().scaledToFit()
        switch look.imageStyles.count {
        case 0: i.foregroundStyle(Color.accentColor)
        case 1: i.foregroundStyle(look.imageStyles[0])
        case 2: i.foregroundStyle(look.imageStyles[0], look.imageStyles[1])
        default: i.foregroundStyle(look.imageStyles[0], look.imageStyles[1], look.imageStyles[2])
        }
    }
    @ViewBuilder func background(radius: CGFloat, glass: Bool) -> some View {
        if popover {
            Color.clear                                   /* the popover draws its own background */
        } else if let b = look.background {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(b)
        } else {                                          /* in a List the row's colour: the row is the card */
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(UIColor.secondarySystemGroupedBackground))
        }
    }
}

/// counts the tip's appearance and time on screen while it shows; re-checks it when MaxDisplayDuration runs out
struct _TipShown: ViewModifier {
    let tip: any Tip
    func body(content: Content) -> some View {
        content
            .onAppear {
                _TipStore.shared.appeared(tip.id, ignoresFrequency: tip.options.contains { ($0 as? Tips.IgnoresDisplayFrequency)?.ignores == true })
                for o in tip.options {
                    if let m = o as? Tips.MaxDisplayDuration {
                        let left = max(0, m.duration - _TipStore.shared.onScreen(tip.id))
                        DispatchQueue.main.asyncAfter(deadline: .now() + left + 0.05) { NotificationCenter.default.post(name: _TipStore.changed, object: nil) }
                    }
                }
            }
            .onDisappear { _TipStore.shared.disappeared(tip.id) }
    }
}

/// a tip in the layout (inline)
public struct TipView: View {
    let tip: (any Tip)?
    let isPresented: Binding<Bool>?
    let arrowEdge: Edge?
    let action: (Tips.Action) -> Void
    @StateObject private var watcher = _TipWatcher()
    public init(_ tip: (any Tip)?, arrowEdge: Edge? = nil, action: @escaping (Tips.Action) -> Void = { _ in }) {
        self.init(tip, isPresented: nil, arrowEdge: arrowEdge, action: action)
    }
    public init(_ tip: (any Tip)?, isPresented: Binding<Bool>?, arrowEdge: Edge? = nil, action: @escaping (Tips.Action) -> Void = { _ in }) {
        self.tip = tip; self.isPresented = isPresented; self.arrowEdge = arrowEdge; self.action = action
    }
    /// iOS 26: the tip points at the view marked tipAnchor(anchorID) (isim: shown inline)
    @available(iOS 26.0, *)
    public init<AnchorID: Hashable>(_ tip: (any Tip)?, isPresented: Binding<Bool>? = nil, arrowEdge: Edge? = nil, anchorID: AnchorID,
                                    action: @escaping (Tips.Action) -> Void = { _ in }) {
        self.init(tip, isPresented: isPresented, arrowEdge: arrowEdge, action: action)
    }
    public var body: some View {
        let _ = watcher.tick
        if let tip, isPresented?.wrappedValue ?? true, _tipClaim(tip) {
            VStack(spacing: 0) {
                if let e = arrowEdge, e == .top { _TipArrow(edge: .top) }
                _TipCard(tip: tip, popover: false, action: action) {
                    tip.invalidate(reason: .tipClosed); isPresented?.wrappedValue = false
                }
                if let e = arrowEdge, e == .bottom { _TipArrow(edge: .bottom) }
            }
            .modifier(_TipShown(tip: tip))
        }
    }
}
/// the little arrow of an inline tip that points at what it explains
struct _TipArrow: View {
    let edge: Edge
    var body: some View {
        Path { p in
            if edge == .top { p.move(to: CGPoint(x: 0, y: 8)); p.addLine(to: CGPoint(x: 9, y: 0)); p.addLine(to: CGPoint(x: 18, y: 8)) }
            else { p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 9, y: 8)); p.addLine(to: CGPoint(x: 18, y: 0)) }
            p.closeSubpath()
        }
        .fill(Color(UIColor.secondarySystemGroupedBackground))
        .frame(width: 18, height: 8)
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// shows the tip in a popover pointing at this view while it is available
struct _PopoverTip: ViewModifier {
    let tip: (any Tip)?
    let isPresented: Binding<Bool>?
    let anchor: PopoverAttachmentAnchor
    let edge: Edge
    let action: (Tips.Action) -> Void
    @StateObject private var watcher = _TipWatcher()
    @State private var closedByUser = false
    func body(content: Content) -> some View {
        let _ = watcher.tick
        let shown = tip.map { _tipClaim($0) } ?? false && (isPresented?.wrappedValue ?? true)
        content.popover(isPresented: Binding(get: { shown }, set: { now in
            guard !now, let tip else { return }
            if _tipStatus(tip) == .available { tip.invalidate(reason: .tipClosed) }   /* dismissed by a tap outside: closed */
            isPresented?.wrappedValue = false
        }), attachmentAnchor: anchor, arrowEdge: edge) {
            if let tip {
                _TipCard(tip: tip, popover: true, action: action) { tip.invalidate(reason: .tipClosed); isPresented?.wrappedValue = false }
                    .modifier(_TipShown(tip: tip))
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}
extension View {
    public func popoverTip(_ tip: (any Tip)?, arrowEdge: Edge? = nil, action: @escaping (Tips.Action) -> Void = { _ in }) -> some View {
        modifier(_PopoverTip(tip: tip, isPresented: nil, anchor: .rect(.bounds), edge: arrowEdge ?? .top, action: action))
    }
    @available(iOS 18.0, *)
    public func popoverTip(_ tip: (any Tip)?, isPresented: Binding<Bool>? = nil, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
                           arrowEdge: Edge? = nil, action: @escaping (Tips.Action) -> Void = { _ in }) -> some View {
        modifier(_PopoverTip(tip: tip, isPresented: isPresented, anchor: attachmentAnchor, edge: arrowEdge ?? .top, action: action))
    }
    @available(iOS 18.0, *)
    public func popoverTip(_ tip: (any Tip)?, isPresented: Binding<Bool>? = nil, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
                           arrowEdges: Edge.Set, action: @escaping (Tips.Action) -> Void = { _ in }) -> some View {
        let edge: Edge = arrowEdges.contains(.top) ? .top : arrowEdges.contains(.bottom) ? .bottom : arrowEdges.contains(.leading) ? .leading : .trailing
        return modifier(_PopoverTip(tip: tip, isPresented: isPresented, anchor: attachmentAnchor, edge: edge, action: action))
    }
    /// iOS 26: marks the view a TipView(anchorID:) points at (isim: TipView shows inline)
    @available(iOS 26.0, *)
    public func tipAnchor<AnchorID: Hashable>(_ id: AnchorID) -> some View { self }
}

// MARK: - UIKit

/// the settings the UIKit tip views pass to the SwiftUI card
final class _TipUIStyle {
    var background: AnyShapeStyle?
    var cornerRadius: CGFloat?
    var imageSize: CGSize?
    var imageStyle: AnyShapeStyle?
    var viewStyle: AnyTipViewStyle?
    func apply<V: View>(_ v: V) -> AnyView {
        var a = AnyView(v)
        if let b = background { a = AnyView(a.tipBackground(b)) }
        if let r = cornerRadius { a = AnyView(a.tipCornerRadius(r)) }
        if let s = imageSize { a = AnyView(a.tipImageSize(s)) }
        if let i = imageStyle { a = AnyView(a.tipImageStyle(i)) }
        if let s = viewStyle { a = AnyView(a.transformEnvironment(\._tipLook) { $0.style = s }) }
        return a
    }
}

/// an inline tip for UIKit layouts
open class TipUIView: UIView {
    let tip: any Tip
    let arrowEdge: Edge?
    let handler: (Tips.Action) -> Void
    let style = _TipUIStyle()
    var host: UIHostingController<AnyView>?
    public init(_ tip: any Tip, arrowEdge: Edge? = nil, actionHandler: @escaping (Tips.Action) -> Void = { _ in }) {
        self.tip = tip; self.arrowEdge = arrowEdge; handler = actionHandler
        super.init(frame: .zero)
        rebuild()
    }
    public required init?(coder: NSCoder) { fatalError("TipUIView is made in code") }
    func rebuild() {
        host?.view.removeFromSuperview()
        let h = UIHostingController(rootView: style.apply(TipView(tip, arrowEdge: arrowEdge, action: handler)))
        h.view.backgroundColor = .clear
        h.view.frame = bounds; h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(h.view); host = h
    }
    open override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { super.backgroundColor = .clear; style.background = newValue.map { AnyShapeStyle(Color($0)) }; if host != nil { rebuild() } }
    }
    open var backgroundStyle: any ShapeStyle {
        get { style.background ?? AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground)) }
        set { style.background = AnyShapeStyle(newValue); rebuild() }
    }
    open var cornerRadius: CGFloat { get { style.cornerRadius ?? 13 } set { style.cornerRadius = newValue; rebuild() } }
    open var imageSize: CGSize { get { style.imageSize ?? CGSize(width: 36, height: 36) } set { style.imageSize = newValue; rebuild() } }
    open var imageStyle: (any ShapeStyle)? { get { style.imageStyle } set { style.imageStyle = newValue.map { AnyShapeStyle($0) }; rebuild() } }
    open var viewStyle: any TipViewStyle {
        get { MiniTipViewStyle() }
        set { style.viewStyle = AnyTipViewStyle(newValue); rebuild() }
    }
    open override func sizeThatFits(_ size: CGSize) -> CGSize { host?.sizeThatFits(in: size) ?? .zero }
    open override var intrinsicContentSize: CGSize { host?.sizeThatFits(in: CGSize(width: bounds.width > 0 ? bounds.width : 360, height: .greatestFiniteMagnitude)) ?? .zero }
}

/// a tip in a popover (present it; it points at sourceItem)
open class TipUIPopoverViewController: UIViewController {
    var tip: (any Tip)?
    var handler: (Tips.Action) -> Void = { _ in }
    let style = _TipUIStyle()
    public convenience init(_ tip: any Tip, sourceItem: any UIPopoverPresentationControllerSourceItem, actionHandler: @escaping (Tips.Action) -> Void = { _ in }) {
        self.init(nibName: nil, bundle: nil)
        self.tip = tip; handler = actionHandler
        modalPresentationStyle = .popover
        popoverPresentationController?.sourceItem = sourceItem
        popoverPresentationController?.delegate = _TipPopoverAdaptation.shared    /* a popover on iPhone too */
    }
    public override init(nibName: String?, bundle: Bundle?) { super.init(nibName: nibName, bundle: bundle) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open var sourceItem: (any UIPopoverPresentationControllerSourceItem)? {
        get { popoverPresentationController?.sourceItem }
        set { popoverPresentationController?.sourceItem = newValue }
    }
    open var presentationDelegate: (any UIPopoverPresentationControllerDelegate)? {
        get { popoverPresentationController?.delegate }
        set { popoverPresentationController?.delegate = newValue }
    }
    open var backgroundColor: UIColor? { get { view.backgroundColor } set { view.backgroundColor = newValue } }
    open var backgroundStyle: any ShapeStyle { get { style.background ?? AnyShapeStyle(Color.clear) } set { style.background = AnyShapeStyle(newValue) } }
    open var imageSize: CGSize { get { style.imageSize ?? CGSize(width: 36, height: 36) } set { style.imageSize = newValue } }
    open var imageStyle: (any ShapeStyle)? { get { style.imageStyle } set { style.imageStyle = newValue.map { AnyShapeStyle($0) } } }
    open var viewStyle: any TipViewStyle { get { MiniTipViewStyle() } set { style.viewStyle = AnyTipViewStyle(newValue) } }
    open override func viewDidLoad() {
        super.viewDidLoad()
        guard let tip else { return }
        let card = _TipCard(tip: tip, popover: true, action: handler) { [weak self] in
            tip.invalidate(reason: .tipClosed); self?.dismiss(animated: true)
        }.modifier(_TipShown(tip: tip))
        let h = UIHostingController(rootView: style.apply(card))
        addChild(h); h.view.frame = view.bounds; h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]; h.view.backgroundColor = .clear
        view.addSubview(h.view); h.didMove(toParent: self)
        preferredContentSize = h.sizeThatFits(in: CGSize(width: 340, height: CGFloat.greatestFiniteMagnitude))
    }
}

/// keeps a tip's popover a popover in compact widths (instead of a sheet)
final class _TipPopoverAdaptation: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = _TipPopoverAdaptation()
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle { .none }
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
}

/// a tip as a collection view cell
open class TipUICollectionViewCell: UICollectionViewCell {
    let style = _TipUIStyle()
    var host: UIHostingController<AnyView>?
    @discardableResult
    open func configureTip(_ tip: any Tip, arrowEdge: Edge? = nil, actionHandler: @escaping (Tips.Action) -> Void = { _ in }) -> Self {
        host?.view.removeFromSuperview()
        let h = UIHostingController(rootView: style.apply(TipView(tip, arrowEdge: arrowEdge, action: actionHandler)))
        h.view.backgroundColor = .clear; h.view.frame = contentView.bounds; h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(h.view); host = h
        return self
    }
    open override var backgroundColor: UIColor? { get { super.backgroundColor } set { super.backgroundColor = newValue; style.background = newValue.map { AnyShapeStyle(Color($0)) } } }
    open var backgroundStyle: any ShapeStyle { get { style.background ?? AnyShapeStyle(Color.clear) } set { style.background = AnyShapeStyle(newValue) } }
    open var cornerRadius: CGFloat { get { style.cornerRadius ?? 13 } set { style.cornerRadius = newValue } }
    open var imageSize: CGSize { get { style.imageSize ?? CGSize(width: 36, height: 36) } set { style.imageSize = newValue } }
    open var imageStyle: (any ShapeStyle)? { get { style.imageStyle } set { style.imageStyle = newValue.map { AnyShapeStyle($0) } } }
    open var viewStyle: any TipViewStyle { get { MiniTipViewStyle() } set { style.viewStyle = AnyTipViewStyle(newValue) } }
}
/// a tip as a collection view's supplementary view (a header, a footer)
open class TipUICollectionReusableView: UICollectionReusableView {
    let style = _TipUIStyle()
    var host: UIHostingController<AnyView>?
    @discardableResult
    open func configureTip(_ tip: any Tip, arrowEdge: Edge? = nil, actionHandler: @escaping (Tips.Action) -> Void = { _ in }) -> Self {
        host?.view.removeFromSuperview()
        let h = UIHostingController(rootView: style.apply(TipView(tip, arrowEdge: arrowEdge, action: actionHandler)))
        h.view.backgroundColor = .clear; h.view.frame = bounds; h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(h.view); host = h
        return self
    }
    open var backgroundStyle: any ShapeStyle { get { style.background ?? AnyShapeStyle(Color.clear) } set { style.background = AnyShapeStyle(newValue) } }
    open var cornerRadius: CGFloat { get { style.cornerRadius ?? 13 } set { style.cornerRadius = newValue } }
    open var imageSize: CGSize { get { style.imageSize ?? CGSize(width: 36, height: 36) } set { style.imageSize = newValue } }
    open var imageStyle: (any ShapeStyle)? { get { style.imageStyle } set { style.imageStyle = newValue.map { AnyShapeStyle($0) } } }
    open var viewStyle: any TipViewStyle { get { MiniTipViewStyle() } set { style.viewStyle = AnyTipViewStyle(newValue) } }
}
