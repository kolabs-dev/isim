// isim WidgetKit: widgets and Live Activity presentations.
//
// A widget extension (.appex, NSExtensionPointIdentifier com.apple.widgetkit-extension, `@main` Widget/WidgetBundle)
// runs as a short-lived helper process started by the home screen through the shell (like iOS runs extensions):
// ISIM_WIDGET_REQUEST names a request plist { mode = list | render | tap | activity; out = dir; ... }. The helper
// asks the TimelineProvider for a timeline, renders each entry with isim's SwiftUI into PNGs (and the plist
// describing them), or, for a tap on an interactive widget, runs the tapped Button(intent:)'s AppIntent and then
// renders a fresh timeline. For Live Activities it decodes the activity written by ActivityKit and renders the
// lock-screen view and the Dynamic Island regions of the matching ActivityConfiguration.
// The home screen shows the images, switches entries by date and reloads on the timeline policy or
// WidgetCenter.reloadTimelines(ofKind:).
import Foundation
import UIKit
import SwiftUI
import AppIntents
import ActivityKit
import isim_host

// MARK: - families, environment

public enum WidgetFamily: String, CaseIterable, Sendable, Hashable, CustomStringConvertible {
    case systemSmall, systemMedium, systemLarge, systemExtraLarge, accessoryCircular, accessoryRectangular, accessoryInline
    public var description: String { rawValue }
    /// point size on the device (iPhone sizes for 6.1–6.3" screens; iPad uses the same grid on isim)
    var size: CGSize {
        switch self {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        case .systemLarge, .systemExtraLarge: return CGSize(width: 364, height: 382)
        case .accessoryCircular: return CGSize(width: 72, height: 72)
        case .accessoryRectangular: return CGSize(width: 172, height: 76)
        case .accessoryInline: return CGSize(width: 257, height: 26)
        }
    }
}
struct _WidgetFamilyKey: EnvironmentKey { static var defaultValue: WidgetFamily { .systemSmall } }
struct _ShowsBackgroundKey: EnvironmentKey { static var defaultValue: Bool { true } }
public enum WidgetRenderingMode: Sendable, Equatable { case fullColor, accented, vibrant }
extension EnvironmentValues {
    public var widgetFamily: WidgetFamily { get { self[_WidgetFamilyKey.self] } set { self[_WidgetFamilyKey.self] = newValue } }
    public var showsWidgetContainerBackground: Bool { get { self[_ShowsBackgroundKey.self] } set { self[_ShowsBackgroundKey.self] = newValue } }
    public var widgetRenderingMode: WidgetRenderingMode { .fullColor }
    public var isActivityFullscreen: Bool { false }
}
public struct ContainerBackgroundPlacement: Sendable { public static let widget = ContainerBackgroundPlacement() }
extension View {
    /// The widget's background: drawn behind the content margins (16 pt), like iOS 17.
    public func containerBackground<S: ShapeStyle>(_ style: S, for placement: ContainerBackgroundPlacement) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity).padding(16).background(Rectangle().fill(style))
    }
    public func containerBackground<V: View>(for placement: ContainerBackgroundPlacement, @ViewBuilder content: () -> V) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity).padding(16).background(content())
    }
    public func widgetURL(_ url: URL?) -> some View { self }
    public func widgetAccentable(_ accentable: Bool = true) -> some View { self }
    /// the Live Activity's lock-screen background (WidgetKit fills the whole presentation with it)
    public func activityBackgroundTint(_ color: Color?) -> some View { _WKHost.tint = color; return self }
    public func activitySystemActionForegroundColor(_ color: Color?) -> some View { self }
    public func invalidatableContent(_ invalidatable: Bool = true) -> some View { self }
}

// MARK: - timelines

public protocol TimelineEntry { var date: Date { get } }
public struct TimelineReloadPolicy: Sendable, Equatable {
    let kind: Int; let date: Date?
    public static let atEnd = TimelineReloadPolicy(kind: 0, date: nil)
    public static let never = TimelineReloadPolicy(kind: 1, date: nil)
    public static func after(_ date: Date) -> TimelineReloadPolicy { TimelineReloadPolicy(kind: 2, date: date) }
}
public struct Timeline<EntryType: TimelineEntry> {
    public let entries: [EntryType]
    public let policy: TimelineReloadPolicy
    public init(entries: [EntryType], policy: TimelineReloadPolicy) { self.entries = entries; self.policy = policy }
}
public struct TimelineProviderContext: Sendable {
    public let family: WidgetFamily
    public let displaySize: CGSize
    public let isPreview: Bool
}
public protocol TimelineProvider {
    associatedtype Entry: TimelineEntry
    typealias Context = TimelineProviderContext
    func placeholder(in context: Context) -> Entry
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void)
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void)
}
public protocol AppIntentTimelineProvider {
    associatedtype Entry: TimelineEntry
    associatedtype Intent: WidgetConfigurationIntent
    typealias Context = TimelineProviderContext
    func placeholder(in context: Context) -> Entry
    func snapshot(for configuration: Intent, in context: Context) async -> Entry
    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry>
}

// MARK: - configurations

/// what a configuration contributes: widgets (kind + timeline renderer) and Live Activity renderers
struct _WKWidgetSpec {
    var kind: String
    var name = "", description = ""
    var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
    var timeline: @MainActor (TimelineProviderContext) async -> (entries: [(Date, AnyView)], policy: TimelineReloadPolicy)
}
struct _WKActivitySpec {
    var typeName: String
    var render: @MainActor (_ attributes: Data, _ state: Data) -> (lock: AnyView, leading: AnyView, trailing: AnyView, minimal: AnyView, expanded: AnyView)?
}
public protocol WidgetConfiguration { }
protocol _WKConfig { var _widgets: [_WKWidgetSpec] { get }; var _activities: [_WKActivitySpec] { get } }
extension _WKConfig { var _activities: [_WKActivitySpec] { [] }; var _widgets: [_WKWidgetSpec] { [] } }

public struct StaticConfiguration<Content: View>: WidgetConfiguration, _WKConfig {
    let spec: _WKWidgetSpec
    public init<P: TimelineProvider>(kind: String, provider: P, @ViewBuilder content: @escaping (P.Entry) -> Content) {
        spec = _WKWidgetSpec(kind: kind) { ctx in
            let tl: Timeline<P.Entry> = await withCheckedContinuation { k in provider.getTimeline(in: ctx) { k.resume(returning: $0) } }
            return (tl.entries.map { ($0.date, AnyView(content($0))) }, tl.policy)
        }
    }
    var _widgets: [_WKWidgetSpec] { [spec] }
}
public struct AppIntentConfiguration<Intent: WidgetConfigurationIntent, Content: View>: WidgetConfiguration, _WKConfig {
    let spec: _WKWidgetSpec
    public init<P: AppIntentTimelineProvider>(kind: String, intent: Intent.Type = Intent.self, provider: P, @ViewBuilder content: @escaping (P.Entry) -> Content) where P.Intent == Intent {
        spec = _WKWidgetSpec(kind: kind) { ctx in       /* isim: the intent's default configuration (no widget editing UI) */
            let tl = await provider.timeline(for: Intent(), in: ctx)
            return (tl.entries.map { ($0.date, AnyView(content($0))) }, tl.policy)
        }
    }
    var _widgets: [_WKWidgetSpec] { [spec] }
}
public struct _ModifiedConfiguration<C: WidgetConfiguration>: WidgetConfiguration, _WKConfig {
    let base: C; let edit: (inout _WKWidgetSpec) -> Void
    var _widgets: [_WKWidgetSpec] { ((base as? _WKConfig)?._widgets ?? []).map { var s = $0; edit(&s); return s } }
    var _activities: [_WKActivitySpec] { (base as? _WKConfig)?._activities ?? [] }
}
extension WidgetConfiguration {
    public func configurationDisplayName(_ name: String) -> some WidgetConfiguration { _ModifiedConfiguration(base: self) { $0.name = name } }
    public func configurationDisplayName(_ name: LocalizedStringKey) -> some WidgetConfiguration { _ModifiedConfiguration(base: self) { $0.name = "\(name)".replacingOccurrences(of: "LocalizedStringKey(key: \"", with: "") } }
    public func description(_ text: String) -> some WidgetConfiguration { _ModifiedConfiguration(base: self) { $0.description = text } }
    public func supportedFamilies(_ families: [WidgetFamily]) -> some WidgetConfiguration { _ModifiedConfiguration(base: self) { $0.families = families } }
    public func contentMarginsDisabled() -> some WidgetConfiguration { self }
    public func disfavoredLocations(_ l: [Any], for families: [WidgetFamily]) -> some WidgetConfiguration { self }
    public func promptsForUserConfiguration() -> some WidgetConfiguration { self }
}

// MARK: - Live Activities

public struct ActivityViewContext<Attributes: ActivityAttributes> {
    public let attributes: Attributes
    public let state: Attributes.ContentState
    public let isStale: Bool
    public let activityID: String
}
public enum DynamicIslandExpandedRegionPosition: Sendable { case leading, trailing, center, bottom }
public struct DynamicIslandExpandedRegion<Content: View> {
    let position: DynamicIslandExpandedRegionPosition; let content: Content
    public init(_ position: DynamicIslandExpandedRegionPosition, priority: Double = 0, @ViewBuilder content: () -> Content) { self.position = position; self.content = content() }
}
public struct _DIRegion { let position: DynamicIslandExpandedRegionPosition; let view: AnyView }
@resultBuilder public struct DynamicIslandExpandedContentBuilder {
    public static func buildExpression<C: View>(_ r: DynamicIslandExpandedRegion<C>) -> [_DIRegion] { [_DIRegion(position: r.position, view: AnyView(r.content))] }
    public static func buildBlock(_ parts: [_DIRegion]...) -> [_DIRegion] { parts.flatMap { $0 } }
}
/// The presentation `DynamicIsland.contentMargins(_:_:for:)` applies to.
public struct DynamicIslandMode: Hashable, Sendable {
    let rawValue: Int
    public static let compact = DynamicIslandMode(rawValue: 0)
    public static let minimal = DynamicIslandMode(rawValue: 1)
    public static let expanded = DynamicIslandMode(rawValue: 2)
}
public struct DynamicIsland {
    let regions: [_DIRegion]; let leading: AnyView, trailing: AnyView, minimal: AnyView
    /* the system's margins per presentation (adapted): expanded 22 horizontal / 14 vertical; compact and minimal none,
       their views are centred in their slot */
    var margins: [DynamicIslandMode: EdgeInsets] = [.expanded: DynamicIsland.defaultExpandedMargins]
    static let defaultExpandedMargins = EdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 22)
    public init<L: View, T: View, M: View>(@DynamicIslandExpandedContentBuilder expanded: () -> [_DIRegion], @ViewBuilder compactLeading: () -> L,
                                            @ViewBuilder compactTrailing: () -> T, @ViewBuilder minimal: () -> M) {
        regions = expanded(); leading = AnyView(compactLeading()); trailing = AnyView(compactTrailing()); self.minimal = AnyView(minimal())
    }
    public func keylineTint(_ color: Color?) -> DynamicIsland { self }
    public func widgetURL(_ url: URL?) -> DynamicIsland { self }
    /// Sets the margins of `edges` in the `mode` presentation; `nil` restores the system's margin.
    public func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat?, for mode: DynamicIslandMode) -> DynamicIsland {
        var d = self, m = margins[mode] ?? EdgeInsets()
        let system = mode == .expanded ? DynamicIsland.defaultExpandedMargins : EdgeInsets()
        if edges.contains(.top) { m.top = length ?? system.top }
        if edges.contains(.leading) { m.leading = length ?? system.leading }
        if edges.contains(.bottom) { m.bottom = length ?? system.bottom }
        if edges.contains(.trailing) { m.trailing = length ?? system.trailing }
        d.margins[mode] = m
        return d
    }
    @available(*, unavailable, message: "use contentMargins(_:_:for:) with a DynamicIslandMode")
    public func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat? = nil, for mode: Any? = nil) -> DynamicIsland { self }
    @MainActor func view(_ v: AnyView, _ mode: DynamicIslandMode) -> AnyView {
        guard let m = margins[mode], m != EdgeInsets() else { return v }
        return AnyView(v.padding(m))
    }
    @MainActor var expandedView: AnyView {
        func r(_ p: DynamicIslandExpandedRegionPosition) -> AnyView { regions.first { $0.position == p }?.view ?? AnyView(EmptyView()) }
        return AnyView(VStack(spacing: 6) {
            HStack(alignment: .top) { r(.leading); Spacer(minLength: 4); r(.center); Spacer(minLength: 4); r(.trailing) }
            r(.bottom)
        }.padding(margins[.expanded] ?? EdgeInsets()).foregroundColor(.white))
    }
}
public struct ActivityConfiguration<Attributes: ActivityAttributes>: WidgetConfiguration, _WKConfig {
    let spec: _WKActivitySpec
    public init<Content: View>(for attributesType: Attributes.Type, @ViewBuilder content: @escaping (ActivityViewContext<Attributes>) -> Content,
                               dynamicIsland: @escaping (ActivityViewContext<Attributes>) -> DynamicIsland) {
        spec = _WKActivitySpec(typeName: String(describing: Attributes.self)) { a, s in
            let dec = JSONDecoder()
            guard let attrs = try? dec.decode(Attributes.self, from: a), let state = try? dec.decode(Attributes.ContentState.self, from: s) else { return nil }
            let ctx = ActivityViewContext(attributes: attrs, state: state, isStale: false, activityID: "")
            let di = dynamicIsland(ctx)
            return (AnyView(content(ctx)), di.view(di.leading, .compact), di.view(di.trailing, .compact), di.view(di.minimal, .minimal), di.expandedView)
        }
    }
    var _activities: [_WKActivitySpec] { [spec] }
}

// MARK: - Widget and WidgetBundle

public protocol Widget {
    associatedtype Body: WidgetConfiguration
    @WidgetConfigurationBuilder var body: Body { get }
    init()
}
@resultBuilder public struct WidgetConfigurationBuilder {
    public static func buildBlock<C: WidgetConfiguration>(_ c: C) -> C { c }
}
public protocol WidgetBundle {
    associatedtype Body: Widget
    @WidgetBundleBuilder var body: Body { get }
    init()
}
public struct _TupleWidget<each W: Widget>: Widget {
    let widgets: (repeat each W)
    public init() { fatalError("isim: _TupleWidget is built by WidgetBundleBuilder") }
    init(_ w: (repeat each W)) { widgets = w }
    public var body: _WidgetList { var l: [any WidgetConfiguration] = []; for w in repeat each widgets { l.append(w.body) }; return _WidgetList(items: l) }
}
public struct _WidgetList: WidgetConfiguration, _WKConfig {
    let items: [any WidgetConfiguration]
    var _widgets: [_WKWidgetSpec] { items.flatMap { ($0 as? _WKConfig)?._widgets ?? [] } }
    var _activities: [_WKActivitySpec] { items.flatMap { ($0 as? _WKConfig)?._activities ?? [] } }
}
@resultBuilder public struct WidgetBundleBuilder {
    public static func buildBlock<each W: Widget>(_ w: repeat each W) -> _TupleWidget<repeat each W> { _TupleWidget((repeat each w)) }
}
extension Widget {
    @MainActor public static func main() { _WKHost.run((Self().body as? _WKConfig).map { [$0] } ?? []) }
}
extension WidgetBundle {
    @MainActor public static func main() { _WKHost.run((Self().body.body as? _WKConfig).map { [$0] } ?? []) }
}

// MARK: - WidgetCenter

public final class WidgetCenter: @unchecked Sendable {
    public static let shared = WidgetCenter()
    public func reloadTimelines(ofKind kind: String) { isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "widget-reload", nil, kind); NSLog("isim WidgetKit: reload timelines of %@", kind) }
    public func reloadAllTimelines() { isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "widget-reload", nil, "*"); NSLog("isim WidgetKit: reload all timelines") }
    public struct WidgetInfo: Sendable { public let kind: String; public let family: WidgetFamily }
    /// isim: reads the home screen's arrangement for this app's widgets
    public func getCurrentConfigurations(_ completion: @escaping (Result<[WidgetInfo], Error>) -> Void) {
        let data = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
        let items = (NSDictionary(contentsOfFile: data + "/Library/SpringBoard/IconState.plist") as? [String: Any])?["items"] as? [Any] ?? []
        let me = Bundle.main.bundleIdentifier ?? ""
        let infos: [WidgetInfo] = items.compactMap { it in
            guard let d = it as? [String: Any], let k = d["widget"] as? String, (d["app"] as? String).map({ me.hasPrefix($0) }) ?? false,
                  let f = WidgetFamily(rawValue: d["family"] as? String ?? "") else { return nil }
            return WidgetInfo(kind: k, family: f)
        }
        DispatchQueue.global().async { completion(.success(infos)) }
    }
    public var currentConfigurations: [WidgetInfo] { get async throws {
        try await withCheckedThrowingContinuation { k in getCurrentConfigurations { k.resume(with: $0) } } } }
}

// MARK: - the extension process

@MainActor enum _WKHost {
    static var configs: [_WKConfig] = []
    nonisolated(unsafe) static var tint: Color?
    static func run(_ c: [_WKConfig]) {
        configs = c
        guard ProcessInfo.processInfo.environment["ISIM_WIDGET_REQUEST"] != nil else {
            NSLog("isim WidgetKit: widget extension with %ld widget(s); the home screen runs it (Edit Home Screen > +)", c.flatMap { $0._widgets }.count)
            exit(0)
        }
        _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(_WKHostDelegate.self))
    }
    static func png(_ view: AnyView, size: CGSize, family: WidgetFamily?) -> (Data, UIView) {
        let root = AnyView(view.environment(\.widgetFamily, family ?? .systemSmall).frame(width: size.width, height: size.height))
        let host = UIHostingController(rootView: root)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = family == nil ? .clear : .systemBackground
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 3; fmt.opaque = false
        let data = UIGraphicsImageRenderer(size: size, format: fmt).pngData { _ in
            _ = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false)
        }
        return (data, host.view)
    }
    static func renderWidget(_ spec: _WKWidgetSpec, family: WidgetFamily, out: String, tap: CGPoint?) async {
        let ctx = TimelineProviderContext(family: family, displaySize: family.size, isPreview: false)
        if let p = tap {                                       /* interactive widget: run the tapped control's intent */
            let tl = await spec.timeline(ctx)
            if let first = currentEntry(tl.entries) {
                let (_, view) = png(first.1, size: family.size, family: family)
                var hit = view.hitTest(p, with: nil)
                while let h = hit, !(h is UIControl) { hit = h.superview }
                if let c = hit as? UIControl {
                    NSLog("isim WidgetKit: tap on %@ at %.0f,%.0f", spec.kind, p.x, p.y)
                    c.sendActions(for: .touchUpInside)
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    var waited = 0
                    while _IsimIntentControls.running > 0 && waited < 100 { try? await Task.sleep(nanoseconds: 50_000_000); waited += 1 }
                } else { NSLog("isim WidgetKit: tap on %@ hit no control", spec.kind) }
            }
        }
        let tl = await spec.timeline(ctx)
        var entries: [[String: Any]] = []
        for (i, e) in tl.entries.prefix(12).enumerated() {
            let file = (out as NSString).appendingPathComponent("\(spec.kind)-\(family.rawValue)-\(i).png")
            let (data, _) = png(e.1, size: family.size, family: family)
            try? data.write(to: URL(fileURLWithPath: file))
            entries.append(["date": e.0, "file": file])
        }
        var info: [String: Any] = ["kind": spec.kind, "family": family.rawValue, "entries": entries,
                                   "policy": ["atEnd", "never", "after"][tl.policy.kind]]
        if let d = tl.policy.date { info["after"] = d }
        (info as NSDictionary).write(toFile: (out as NSString).appendingPathComponent("\(spec.kind)-\(family.rawValue).plist"), atomically: true)
        NSLog("isim WidgetKit: rendered %@ (%@): %ld entr%@, policy %@", spec.kind, family.rawValue, entries.count, entries.count == 1 ? "y" : "ies", info["policy"] as! String)
    }
    static func currentEntry(_ entries: [(Date, AnyView)]) -> (Date, AnyView)? {
        let now = Date()
        return entries.last(where: { $0.0 <= now }) ?? entries.first
    }
    static func handle() async {
        let env = ProcessInfo.processInfo.environment
        guard let reqPath = env["ISIM_WIDGET_REQUEST"], let req = NSDictionary(contentsOfFile: reqPath) as? [String: Any] else { exit(2) }
        let mode = req["mode"] as? String ?? "render", out = req["out"] as? String ?? "/tmp"
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true, attributes: nil)
        let widgets = configs.flatMap { $0._widgets }, activities = configs.flatMap { $0._activities }
        switch mode {
        case "list":
            let list: [[String: Any]] = widgets.map { ["kind": $0.kind, "name": $0.name.isEmpty ? $0.kind : $0.name, "description": $0.description,
                                                       "families": $0.families.map { $0.rawValue }] }
            (["widgets": list, "activities": activities.map { $0.typeName }] as NSDictionary).write(toFile: (out as NSString).appendingPathComponent("widgets.plist"), atomically: true)
            NSLog("isim WidgetKit: %ld widget kind(s), %ld Live Activity configuration(s)", list.count, activities.count)
        case "render", "tap":
            let kind = req["kind"] as? String ?? ""
            let family = WidgetFamily(rawValue: req["family"] as? String ?? "") ?? .systemSmall
            guard let spec = widgets.first(where: { $0.kind == kind }) else { NSLog("isim WidgetKit: no widget of kind %@", kind); break }
            var tap: CGPoint?
            if mode == "tap", let x = req["x"] as? Double, let y = req["y"] as? Double { tap = CGPoint(x: x, y: y) }
            await renderWidget(spec, family: family, out: out, tap: tap)
        case "activity":
            guard let path = req["activity"] as? String, let rec = _IsimActivityRecord.load(path) else { break }
            _WKHost.tint = nil                         /* activityBackgroundTint runs while the views are built */
            guard let spec = activities.first(where: { $0.typeName == rec.type }), let views = spec.render(rec.attributes, rec.state) else {
                NSLog("isim WidgetKit: no ActivityConfiguration for %@", rec.type); break
            }
            let parts: [(String, AnyView, CGSize)] = [("lock", views.lock, CGSize(width: 370, height: 160)), ("leading", views.leading, CGSize(width: 64, height: 37)),
                                                      ("trailing", views.trailing, CGSize(width: 64, height: 37)), ("minimal", views.minimal, CGSize(width: 37, height: 37)),
                                                      ("expanded", views.expanded, CGSize(width: 370, height: 160))]
            var files: [String: String] = [:]
            for (name, v, size) in parts {
                var styled = AnyView(v.foregroundColor(.white).environment(\.colorScheme, .dark))
                if name == "lock" {                       /* the lock-screen presentation is filled with the tint */
                    styled = AnyView(ZStack { Rectangle().fill(_WKHost.tint ?? Color(white: 0.95)); v }.frame(width: size.width, height: size.height))
                }
                let (data, _) = png(styled, size: size, family: nil)
                let f = (out as NSString).appendingPathComponent("\(name).png")
                try? data.write(to: URL(fileURLWithPath: f)); files[name] = f
            }
            (files as NSDictionary).write(toFile: (out as NSString).appendingPathComponent("activity.plist"), atomically: true)
            NSLog("isim WidgetKit: rendered Live Activity %@ (lock screen, Dynamic Island)", rec.type)
        default: break
        }
    }
}
@objc(_WKHostDelegate) final class _WKHostDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task { @MainActor in await _WKHost.handle(); exit(0) }
        return true
    }
}
