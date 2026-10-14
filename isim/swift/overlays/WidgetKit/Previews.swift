// isim WidgetKit: widget and Live Activity previews. `#Preview(as:widget:timeline:)`, `#Preview(as:widget:timelineProvider:)`
// (with `using:` an intent for AppIntentTimelineProvider) and `#Preview(as:using:widget:contentStates:)` expand (isim's
// PreviewsMacros plugin) into a Preview whose content renders the widget the way the home screen does (the same
// container, margins and families as the widget extension's renders) and lays the entries or content states out on
// a grey canvas, each captioned: `isim preview App.app NAME` finds them in the app's widget extension and renders them
// (adapted: Xcode's canvas shows one entry at a time with a timeline scrubber). `WidgetPreviewContext` (iOS 14
// PreviewProvider previews) frames a view to the family's size.
import Foundation
import UIKit
import SwiftUI
import ActivityKit
import DeveloperToolsSupport

@freestanding(declaration)
public macro Preview<Widget: WidgetKit.Widget, Entry: TimelineEntry>(_ name: String? = nil, as family: WidgetFamily,
    widget: @escaping () -> Widget, @PreviewTimelineBuilder timeline: @escaping @MainActor () async -> [Entry]) =
    #externalMacro(module: "PreviewsMacros", type: "WidgetPreview")

@freestanding(declaration)
public macro Preview<Widget: WidgetKit.Widget, Provider: TimelineProvider>(_ name: String? = nil, as family: WidgetFamily,
    widget: @escaping () -> Widget, timelineProvider: @escaping () -> Provider) =
    #externalMacro(module: "PreviewsMacros", type: "WidgetPreview")

@freestanding(declaration)
public macro Preview<Widget: WidgetKit.Widget, Provider: AppIntentTimelineProvider>(_ name: String? = nil, as family: WidgetFamily,
    using intent: Provider.Intent, widget: @escaping () -> Widget, timelineProvider: @escaping () -> Provider) =
    #externalMacro(module: "PreviewsMacros", type: "WidgetPreview")

@freestanding(declaration)
public macro Preview<Attributes: ActivityAttributes, Widget: WidgetKit.Widget>(_ name: String? = nil, as viewKind: ActivityPreviewViewKind,
    using attributes: Attributes, widget: @escaping () -> Widget,
    @PreviewActivityBuilder contentStates: @escaping @MainActor () async -> [Attributes.ContentState]) =
    #externalMacro(module: "PreviewsMacros", type: "WidgetPreview")

/// The timeline entries of a widget preview, one per line.
@resultBuilder public struct PreviewTimelineBuilder {
    public static func buildExpression<Entry: TimelineEntry>(_ entry: Entry) -> [Entry] { [entry] }
    public static func buildExpression<Entry: TimelineEntry>(_ entries: [Entry]) -> [Entry] { entries }
    public static func buildBlock<Entry: TimelineEntry>(_ parts: [Entry]...) -> [Entry] { parts.flatMap { $0 } }
    public static func buildOptional<Entry: TimelineEntry>(_ part: [Entry]?) -> [Entry] { part ?? [] }
    public static func buildEither<Entry: TimelineEntry>(first: [Entry]) -> [Entry] { first }
    public static func buildEither<Entry: TimelineEntry>(second: [Entry]) -> [Entry] { second }
    public static func buildArray<Entry: TimelineEntry>(_ parts: [[Entry]]) -> [Entry] { parts.flatMap { $0 } }
}

/// The content states of a Live Activity preview, one per line.
@resultBuilder public struct PreviewActivityBuilder {
    public static func buildExpression<State: Codable & Hashable>(_ state: State) -> [State] { [state] }
    public static func buildExpression<State: Codable & Hashable>(_ states: [State]) -> [State] { states }
    public static func buildBlock<State: Codable & Hashable>(_ parts: [State]...) -> [State] { parts.flatMap { $0 } }
    public static func buildOptional<State: Codable & Hashable>(_ part: [State]?) -> [State] { part ?? [] }
    public static func buildEither<State: Codable & Hashable>(first: [State]) -> [State] { first }
    public static func buildEither<State: Codable & Hashable>(second: [State]) -> [State] { second }
    public static func buildArray<State: Codable & Hashable>(_ parts: [[State]]) -> [State] { parts.flatMap { $0 } }
}

/// Which presentation of a Live Activity a preview shows.
public struct ActivityPreviewViewKind: Hashable, Sendable {
    let id: String
    /// the Lock Screen (and notification banner) presentation
    public static let content = ActivityPreviewViewKind(id: "content")
    public static func dynamicIsland(_ presentation: DynamicIslandPreviewViewKind) -> ActivityPreviewViewKind {
        ActivityPreviewViewKind(id: "dynamicIsland." + presentation.id)
    }
}
/// A Dynamic Island presentation for `ActivityPreviewViewKind.dynamicIsland(_:)`.
public struct DynamicIslandPreviewViewKind: Hashable, Sendable {
    let id: String
    public static let compact = DynamicIslandPreviewViewKind(id: "compact")
    public static let expanded = DynamicIslandPreviewViewKind(id: "expanded")
    public static let minimal = DynamicIslandPreviewViewKind(id: "minimal")
}

/// The widget family a PreviewProvider preview is shown in (iOS 14 previews).
public struct WidgetPreviewContext: Sendable {
    public let family: WidgetFamily
    public init(family: WidgetFamily) { self.family = family }
}
extension View {
    /// isim: the view at the family's size, with its `widgetFamily` (no preview canvas otherwise).
    public func previewContext(_ context: WidgetPreviewContext) -> some View {
        environment(\.widgetFamily, context.family).frame(width: context.family.size.width, height: context.family.size.height)
    }
}

// MARK: - what the macros build

extension Preview {
    public init<W: Widget, E: TimelineEntry>(_isimWidget name: String?, as family: WidgetFamily, widget: @escaping () -> W,
                                              @PreviewTimelineBuilder timeline: @escaping @MainActor () async -> [E]) {
        self.init(_isimName: name, traits: [], content: { _WKPreview.widgetName(widget()) })
        _isimController = {
            _WKPreview.controller(title: name) {
                let entries = await timeline()
                return _WKPreview.widgetItems(widget(), family: family, entries: entries.map { ($0.date, $0 as Any) })
            }
        }
    }
    public init<W: Widget, P: TimelineProvider>(_isimWidget name: String?, as family: WidgetFamily, widget: @escaping () -> W,
                                                 timelineProvider: @escaping () -> P) {
        self.init(_isimName: name, traits: [], content: { _WKPreview.widgetName(widget()) })
        _isimController = {
            _WKPreview.controller(title: name) {
                let ctx = TimelineProviderContext(family: family, displaySize: family.size, isPreview: true)
                let tl: Timeline<P.Entry> = await withCheckedContinuation { k in timelineProvider().getTimeline(in: ctx) { k.resume(returning: $0) } }
                return _WKPreview.widgetItems(widget(), family: family, entries: tl.entries.map { ($0.date, $0 as Any) })
            }
        }
    }
    public init<W: Widget, P: AppIntentTimelineProvider>(_isimWidget name: String?, as family: WidgetFamily, using intent: P.Intent,
                                                          widget: @escaping () -> W, timelineProvider: @escaping () -> P) {
        self.init(_isimName: name, traits: [], content: { _WKPreview.widgetName(widget()) })
        _isimController = {
            _WKPreview.controller(title: name) {
                let ctx = TimelineProviderContext(family: family, displaySize: family.size, isPreview: true)
                let tl = await timelineProvider().timeline(for: intent, in: ctx)
                return _WKPreview.widgetItems(widget(), family: family, entries: tl.entries.map { ($0.date, $0 as Any) })
            }
        }
    }
    public init<A: ActivityAttributes, W: Widget>(_isimWidget name: String?, as viewKind: ActivityPreviewViewKind, using attributes: A,
                                                   widget: @escaping () -> W,
                                                   @PreviewActivityBuilder contentStates: @escaping @MainActor () async -> [A.ContentState]) {
        self.init(_isimName: name, traits: [], content: { _WKPreview.widgetName(widget()) })
        nonisolated(unsafe) let attributes = attributes
        _isimController = {
            _WKPreview.controller(title: name) {
                let states = await contentStates()
                return _WKPreview.activityItems(widget(), kind: viewKind, attributes: attributes, states: states)
            }
        }
    }
}

/// One rendered entry or content state on the preview canvas.
struct _WKPreviewItem { let caption: String; let image: UIImage; let corner: CGFloat; let dark: Bool }

@MainActor enum _WKPreview {
    static func widgetName<W: Widget>(_ w: W) -> String { String(describing: W.self) }
    static func config<W: Widget>(_ w: W) -> _WKConfig? { w.body as? _WKConfig }
    static var scale: CGFloat { UIScreen.main.scale }

    /// a widget's entries rendered like the home screen renders them (its first widget configuration)
    static func widgetItems<W: Widget>(_ w: W, family: WidgetFamily, entries: [(Date, Any)]) -> [_WKPreviewItem] {
        guard let spec = config(w)?._widgets.first else {
            NSLog("isim WidgetKit: preview of %@: no widget configuration", String(describing: W.self)); return []
        }
        var look = _WKLook(family: family)
        look.background = !family.isAccessory
        look.margins = spec.marginsDisabled || family.isAccessory ? 0 : 16
        look.scale = scale
        _WKHost.prepare(look)
        let fmt = DateFormatter(); fmt.dateStyle = .none; fmt.timeStyle = .short
        var items: [_WKPreviewItem] = []
        for (i, (date, entry)) in entries.enumerated() {
            guard let view = spec.render?(entry) else { continue }
            let (data, _) = _WKHost.png(view, size: family.size, look: look)
            guard let img = UIImage(data: data, scale: scale) else { continue }
            let corner: CGFloat = family.isAccessory ? (family == .accessoryCircular ? family.size.width / 2 : 0) : 22
            items.append(_WKPreviewItem(caption: "\(family.rawValue) · entry \(i + 1) of \(entries.count) · \(fmt.string(from: date))",
                                        image: img, corner: corner, dark: family.isAccessory))
        }
        NSLog("isim WidgetKit: preview of %@ (%@): %ld entr%@", spec.kind, family.rawValue, items.count, items.count == 1 ? "y" : "ies")
        return items
    }

    /// a Live Activity's content states in one presentation (the ActivityConfiguration of the widget)
    static func activityItems<W: Widget, A: ActivityAttributes>(_ w: W, kind: ActivityPreviewViewKind, attributes: A,
                                                                 states: [A.ContentState]) -> [_WKPreviewItem] {
        guard let spec = config(w)?._activities.first(where: { $0.typeName == String(describing: A.self) }) ?? config(w)?._activities.first,
              let attrs = try? JSONEncoder().encode(attributes) else {
            NSLog("isim WidgetKit: preview of %@: no ActivityConfiguration", String(describing: W.self)); return []
        }
        var items: [_WKPreviewItem] = []
        for (i, state) in states.enumerated() {
            guard let data = try? JSONEncoder().encode(state) else { continue }
            _WKHost.tint = nil
            guard let v = spec.render(attrs, data, false, "preview") else { continue }
            let (view, size, corner): (AnyView, CGSize, CGFloat)
            switch kind.id {
            case "dynamicIsland.compact":
                view = AnyView(HStack(spacing: 0) { v.leading.frame(width: 64, height: 37); Spacer(minLength: 0); v.trailing.frame(width: 64, height: 37) }
                    .foregroundColor(.white).environment(\.colorScheme, .dark).background(Color.black))
                size = CGSize(width: 250, height: 37); corner = 18.5
            case "dynamicIsland.minimal":
                view = AnyView(v.minimal.frame(width: 37, height: 37).foregroundColor(.white).environment(\.colorScheme, .dark).background(Color.black))
                size = CGSize(width: 37, height: 37); corner = 18.5
            case "dynamicIsland.expanded":
                view = AnyView(v.expanded.frame(width: 370, height: 160, alignment: .top).environment(\.colorScheme, .dark).background(Color.black))
                size = CGSize(width: 370, height: 160); corner = 44
            default:                                                    /* the Lock Screen presentation, on its tint */
                view = AnyView(ZStack { Rectangle().fill(_WKHost.tint ?? Color(white: 0.95)); v.lock })
                size = CGSize(width: 370, height: 160); corner = 22
            }
            var look = _WKLook(); look.scale = scale
            let (png, _) = _WKHost.png(view, size: size, look: look)
            guard let img = UIImage(data: png, scale: scale) else { continue }
            items.append(_WKPreviewItem(caption: "\(kind.id) · content state \(i + 1) of \(states.count)", image: img, corner: corner, dark: false))
        }
        NSLog("isim WidgetKit: preview of Live Activity %@ (%@): %ld content state(s)", String(describing: A.self), kind.id, items.count)
        return items
    }

    /// the canvas: the rendered items on grey, each with its caption, filled in once the timeline is ready
    static func controller(title: String?, _ make: @escaping @MainActor () async -> [_WKPreviewItem]) -> AnyObject {
        let model = _WKPreviewModel()
        let vc = UIHostingController(rootView: _WKPreviewCanvas(title: title, model: model))
        Task { @MainActor in model.items = await make(); model.ready = true }
        return vc
    }
}

@MainActor final class _WKPreviewModel: ObservableObject {
    @Published var items: [_WKPreviewItem] = []
    @Published var ready = false
}

struct _WKPreviewCanvas: View {
    let title: String?
    @ObservedObject var model: _WKPreviewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let title { Text(title).font(.headline).foregroundColor(.secondary) }
                ForEach(Array(model.items.enumerated()), id: \.offset) { i, item in
                    VStack(spacing: 6) {
                        Image(uiImage: item.image)
                            .background(item.dark ? Color.black : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: item.corner))
                            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                            .accessibilityIdentifier("preview-item-\(i)")
                        Text(item.caption).font(.caption).foregroundColor(.secondary)
                    }
                }
                if model.ready && model.items.isEmpty { Text("No entries").foregroundColor(.secondary) }
            }
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Color(white: 0.9))
    }
}
