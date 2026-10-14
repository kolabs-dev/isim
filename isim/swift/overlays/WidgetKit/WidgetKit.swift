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
// More modes: placeholder (placeholder(in:) drawn redacted, shown while the first timeline loads), snapshot
// (getSnapshot / snapshot(for:in:) with isPreview, for the widget galleries), params (the WidgetConfigurationIntent's
// parameters, for Edit Widget; render requests carry the chosen values as `config`). A request's renderingMode
// (fullColor | vibrant | accented), background (showsWidgetContainerBackground; off on the Lock Screen and in StandBy)
// and scale say where the widget is shown. Vibrant (Lock Screen, adapted): the rendered pixels become white with an
// opacity from their luminance, like the system's vibrant material over the wallpaper.
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
        /* Lock Screen accessory widgets, from Apple's widget size table: 72 pt circles, 160 x 72 rectangles and a 234 pt
           inline line on 6.1–6.3" iPhones; 76, 172 x 76 and 257 pt on the 6.7" (Plus / Pro Max) class */
        case .accessoryCircular: return _WidgetFamilyLarge ? CGSize(width: 76, height: 76) : CGSize(width: 72, height: 72)
        case .accessoryRectangular: return _WidgetFamilyLarge ? CGSize(width: 172, height: 76) : CGSize(width: 160, height: 72)
        case .accessoryInline: return _WidgetFamilyLarge ? CGSize(width: 257, height: 26) : CGSize(width: 234, height: 26)
        }
    }
    var isAccessory: Bool { self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline }
}
/// the 6.7" class (428 pt wide and wider in portrait): larger Lock Screen accessory widgets
/// (read through the Objective-C runtime: snapshots render off the main thread, and hopping to it could deadlock)
let _WidgetFamilyLarge: Bool = {
    guard let v = (NSClassFromString("UIScreen") as AnyObject?)?.value(forKeyPath: "mainScreen.bounds") as? NSValue else { return false }
    let b = v.cgRectValue.size
    return min(b.width, b.height) >= 428
}()
struct _WidgetFamilyKey: EnvironmentKey { static var defaultValue: WidgetFamily { .systemSmall } }
struct _ShowsBackgroundKey: EnvironmentKey { static var defaultValue: Bool { true } }
public enum WidgetRenderingMode: Sendable, Equatable { case fullColor, accented, vibrant }
struct _RenderingModeKey: EnvironmentKey { static var defaultValue: WidgetRenderingMode { .fullColor } }
struct _ContentMarginsKey: EnvironmentKey { static var defaultValue: EdgeInsets { EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16) } }
extension EnvironmentValues {
    public var widgetFamily: WidgetFamily { get { self[_WidgetFamilyKey.self] } set { self[_WidgetFamilyKey.self] = newValue } }
    /// false where the system removes the container background: the Lock Screen and StandBy
    public var showsWidgetContainerBackground: Bool { get { self[_ShowsBackgroundKey.self] } set { self[_ShowsBackgroundKey.self] = newValue } }
    /// .vibrant on the Lock Screen, .fullColor on the home screen and in StandBy
    public var widgetRenderingMode: WidgetRenderingMode { get { self[_RenderingModeKey.self] } set { self[_RenderingModeKey.self] = newValue } }
    /// the margins the system puts around the content (16 pt; none for accessory widgets or contentMarginsDisabled)
    public var widgetContentMargins: EdgeInsets { get { self[_ContentMarginsKey.self] } set { self[_ContentMarginsKey.self] = newValue } }
    public var isActivityFullscreen: Bool { false }
}
/// The system's translucent background of an accessory widget: a circle (accessoryCircular) or a rounded rectangle
/// (accessoryRectangular); nothing for accessoryInline. Adapted: a light translucent fill that the Lock Screen's
/// vibrant rendering turns into the frosted disc.
public struct AccessoryWidgetBackground: View {
    public init() {}
    public var body: some View {
        let f = _WKHost.family
        return RoundedRectangle(cornerRadius: f == .accessoryCircular ? 1000 : f == .accessoryRectangular ? 12 : 0)
            .fill(Color(white: 1, opacity: f == .accessoryInline ? 0 : 0.25))
    }
}
public struct ContainerBackgroundPlacement: Sendable { public static let widget = ContainerBackgroundPlacement() }
extension View {
    /// The widget's background: drawn behind the content margins (16 pt), like iOS 17; removed where the system
    /// removes it (Lock Screen, StandBy: showsWidgetContainerBackground is false); no margins with contentMarginsDisabled.
    public func containerBackground<S: ShapeStyle>(_ style: S, for placement: ContainerBackgroundPlacement) -> some View {
        let m = _WKHost.margins, show = _WKHost.showsBackground
        return self.frame(maxWidth: .infinity, maxHeight: .infinity).padding(m).background(Rectangle().fill(style).opacity(show ? 1 : 0))
    }
    public func containerBackground<V: View>(for placement: ContainerBackgroundPlacement, @ViewBuilder content: () -> V) -> some View {
        let m = _WKHost.margins, show = _WKHost.showsBackground
        return self.frame(maxWidth: .infinity, maxHeight: .infinity).padding(m).background(content().opacity(show ? 1 : 0))
    }
    /// the URL the app opens with when the widget (or the Live Activity) is tapped outside its buttons and links
    public func widgetURL(_ url: URL?) -> some View { if let u = url { _WKHost.url = u }; return self }
    /// accented rendering (the iOS 18 tinted Home Screen): this content takes the tint, the rest is white
    public func widgetAccentable(_ accentable: Bool = true) -> some View { self.opacity(_WKHost.hidingAccentable && accentable ? 0 : 1) }
    /// the Live Activity's lock-screen background (WidgetKit fills the whole presentation with it)
    public func activityBackgroundTint(_ color: Color?) -> some View { _WKHost.tint = color; return self }
    public func activitySystemActionForegroundColor(_ color: Color?) -> some View { self }
    public func invalidatableContent(_ invalidatable: Bool = true) -> some View { self }
}

// MARK: - timelines

public protocol TimelineEntry {
    var date: Date { get }
    /// isim: kept with the entry; there is no Smart Stack to rotate by it
    var relevance: TimelineEntryRelevance? { get }
}
extension TimelineEntry { public var relevance: TimelineEntryRelevance? { nil } }
public struct TimelineEntryRelevance: Sendable, Equatable {
    public let score: Float
    public let duration: TimeInterval
    public init(score: Float, duration: TimeInterval = 0) { self.score = score; self.duration = duration }
}
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
typealias _WKEntry = (date: Date, view: AnyView, url: URL?)
struct _WKWidgetSpec {
    var kind: String
    var name = "", description = ""
    var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
    var marginsDisabled = false
    /// the timeline for a configuration (the intent's parameter values by name; empty: its defaults)
    var timeline: @MainActor (TimelineProviderContext, [String: Any]) async -> (entries: [_WKEntry], policy: TimelineReloadPolicy)
    var placeholder: @MainActor (TimelineProviderContext) -> AnyView
    var snapshot: @MainActor (TimelineProviderContext, [String: Any]) async -> _WKEntry
    /// the configuration intent: its title and parameters (AppIntentConfiguration), nil for StaticConfiguration
    var params: (@MainActor ([String: Any]) -> (title: String, description: String, params: [[String: Any]]))? = nil
    /// the view of any entry of the provider's entry type (#Preview(as:widget:timeline:), Previews.swift)
    var render: (@MainActor (Any) -> AnyView?)? = nil
}
/// build an entry's view and catch its widgetURL
@MainActor func _wkEntry(_ date: Date, _ make: () -> AnyView) -> _WKEntry {
    _WKHost.url = nil
    let v = make()
    return (date, v, _WKHost.url)
}
struct _WKActivitySpec {
    var typeName: String
    var render: @MainActor (_ attributes: Data, _ state: Data, _ isStale: Bool, _ id: String) -> (lock: AnyView, leading: AnyView, trailing: AnyView, minimal: AnyView, expanded: AnyView)?
}
public protocol WidgetConfiguration { }
protocol _WKConfig { var _widgets: [_WKWidgetSpec] { get }; var _activities: [_WKActivitySpec] { get } }
extension _WKConfig { var _activities: [_WKActivitySpec] { [] }; var _widgets: [_WKWidgetSpec] { [] } }

public struct StaticConfiguration<Content: View>: WidgetConfiguration, _WKConfig {
    let spec: _WKWidgetSpec
    public init<P: TimelineProvider>(kind: String, provider: P, @ViewBuilder content: @escaping (P.Entry) -> Content) {
        spec = _WKWidgetSpec(kind: kind, timeline: { ctx, _ in
            let tl: Timeline<P.Entry> = await withCheckedContinuation { k in provider.getTimeline(in: ctx) { k.resume(returning: $0) } }
            return (tl.entries.map { e in _wkEntry(e.date) { AnyView(content(e)) } }, tl.policy)
        }, placeholder: { ctx in AnyView(content(provider.placeholder(in: ctx))) }, snapshot: { ctx, _ in
            let e: P.Entry = await withCheckedContinuation { k in provider.getSnapshot(in: ctx) { k.resume(returning: $0) } }
            return _wkEntry(e.date) { AnyView(content(e)) }
        }, render: { e in (e as? P.Entry).map { AnyView(content($0)) } })
    }
    var _widgets: [_WKWidgetSpec] { [spec] }
}
public struct AppIntentConfiguration<Intent: WidgetConfigurationIntent, Content: View>: WidgetConfiguration, _WKConfig {
    let spec: _WKWidgetSpec
    public init<P: AppIntentTimelineProvider>(kind: String, intent: Intent.Type = Intent.self, provider: P, @ViewBuilder content: @escaping (P.Entry) -> Content) where P.Intent == Intent {
        spec = _WKWidgetSpec(kind: kind, timeline: { ctx, config in      /* the configuration chosen in Edit Widget (else the defaults) */
            let tl = await provider.timeline(for: _wkIntent(Intent.self, config), in: ctx)
            return (tl.entries.map { e in _wkEntry(e.date) { AnyView(content(e)) } }, tl.policy)
        }, placeholder: { ctx in AnyView(content(provider.placeholder(in: ctx))) }, snapshot: { ctx, config in
            let e = await provider.snapshot(for: _wkIntent(Intent.self, config), in: ctx)
            return _wkEntry(e.date) { AnyView(content(e)) }
        }, params: { config in
            (Intent.title.description, Intent.description?.text ?? "", _wkParameters(_wkIntent(Intent.self, config)))
        }, render: { e in (e as? P.Entry).map { AnyView(content($0)) } })
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
    public func contentMarginsDisabled() -> some WidgetConfiguration { _ModifiedConfiguration(base: self) { $0.marginsDisabled = true } }
    public func disfavoredLocations(_ l: [Any], for families: [WidgetFamily]) -> some WidgetConfiguration { self }
    @available(iOS 18.0, *) public func promptsForUserConfiguration() -> some WidgetConfiguration { self }
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
    public func widgetURL(_ url: URL?) -> DynamicIsland { if let u = url { _WKHost.url = u }; return self }
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
        spec = _WKActivitySpec(typeName: String(describing: Attributes.self)) { a, s, stale, id in
            let dec = JSONDecoder()
            guard let attrs = try? dec.decode(Attributes.self, from: a), let state = try? dec.decode(Attributes.ContentState.self, from: s) else { return nil }
            let ctx = ActivityViewContext(attributes: attrs, state: state, isStale: stale, activityID: id)
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
    /// isim: reads the home screen's arrangement (every page) and the Lock Screen's widgets for this app's widgets
    public func getCurrentConfigurations(_ completion: @escaping (Result<[WidgetInfo], Error>) -> Void) {
        let data = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
        let state = NSDictionary(contentsOfFile: data + "/Library/SpringBoard/IconState.plist") as? [String: Any] ?? [:]
        var items = state["items"] as? [Any] ?? []                          /* the first format: one list */
        for p in state["pages"] as? [[String: Any]] ?? [] { items += p["items"] as? [Any] ?? [] }
        let lock = NSDictionary(contentsOfFile: data + "/Library/SpringBoard/LockScreenWidgets.plist") as? [String: Any] ?? [:]
        if let i = lock["inline"] { items.append(i) }
        items += lock["widgets"] as? [Any] ?? []
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

// MARK: - configuration intents (Edit Widget)

/// an @Parameter of a WidgetConfigurationIntent, by reflection: its title, kind, value and choices (AppEnum cases)
protocol _WKParameter: AnyObject {
    var _wkInfo: [String: Any] { get }
    func _wkSet(_ raw: Any)
}
protocol _WKOptional { static var _wkWrapped: Any.Type { get } }
extension Optional: _WKOptional { static var _wkWrapped: Any.Type { Wrapped.self } }
func _wkCases<E: AppEnum>(_ t: E.Type) -> [[String]] { E.allCases.map { [$0.rawValue, E.caseDisplayRepresentations[$0]?.title.description ?? $0.rawValue] } }
func _wkEnum<E: AppEnum>(_ t: E.Type, _ raw: String) -> Any? { E(rawValue: raw) }
func _wkRaw<E: AppEnum>(_ e: E) -> String { e.rawValue }
extension IntentParameter: _WKParameter {
    var _wkType: Any.Type { (Value.self as? _WKOptional.Type)?._wkWrapped ?? Value.self }
    var _wkInfo: [String: Any] {
        let t = _wkType
        var info: [String: Any] = ["title": title.description, "optional": Value.self is _WKOptional.Type]
        let m = Mirror(reflecting: wrappedValue as Any)
        let v: Any? = m.displayStyle == .optional ? m.children.first?.value : wrappedValue
        if let e = t as? any AppEnum.Type {
            info["kind"] = "enum"; info["choices"] = _wkCases(e)
            if let ev = v as? any AppEnum { info["value"] = _wkRaw(ev) }
        } else if t == Bool.self { info["kind"] = "bool"; if let b = v as? Bool { info["value"] = b ? "true" : "false" } }
        else if t == String.self { info["kind"] = "string"; if let x = v as? String { info["value"] = x } }
        else if t == Int.self { info["kind"] = "int"; if let x = v as? Int { info["value"] = String(x) } }
        else if t == Double.self { info["kind"] = "double"; if let x = v as? Double { info["value"] = String(x) } }
        else { info["kind"] = "other"; if let x = v { info["value"] = "\(x)" } }
        return info
    }
    func _wkSet(_ raw: Any) {
        let s = "\(raw)", t = _wkType
        var new: Any?
        if let e = t as? any AppEnum.Type { new = _wkEnum(e, s) }
        else if t == Bool.self { new = s == "true" || s == "1" }
        else if t == String.self { new = s }
        else if t == Int.self { new = Int(s) }
        else if t == Double.self { new = Double(s) }
        if let n = new, let v = n as? Value { wrappedValue = v }
    }
}
func _wkParamName(_ label: String?) -> String? { label.map { $0.hasPrefix("_") ? String($0.dropFirst()) : $0 } }
@MainActor func _wkParameters<I: AppIntent>(_ intent: I) -> [[String: Any]] {
    Mirror(reflecting: intent).children.compactMap { c in
        guard let p = c.value as? _WKParameter, let name = _wkParamName(c.label) else { return nil }
        var i = p._wkInfo; i["name"] = name; return i
    }
}
/// a configuration intent with the values chosen in Edit Widget (by parameter name)
func _wkIntent<I: AppIntent>(_ t: I.Type, _ config: [String: Any]) -> I {
    let intent = I()
    for c in Mirror(reflecting: intent).children {
        if let p = c.value as? _WKParameter, let name = _wkParamName(c.label), let v = config[name] { p._wkSet(v) }
    }
    return intent
}

// MARK: - the extension process

/// where and how a widget is drawn
struct _WKLook {
    var family: WidgetFamily?
    var mode: WidgetRenderingMode = .fullColor
    var background = true
    var margins: CGFloat = 16
    var scale: CGFloat = 3
    var redacted = false
    var tint: (CGFloat, CGFloat, CGFloat) = (0.4, 0.6, 1)
}
@MainActor enum _WKHost {
    static var configs: [_WKConfig] = []
    /* what the views being built ask for (the content closures run while the host renders) */
    nonisolated(unsafe) static var tint: Color?
    nonisolated(unsafe) static var url: URL?
    nonisolated(unsafe) static var family: WidgetFamily = .systemSmall
    nonisolated(unsafe) static var margins: CGFloat = 16
    nonisolated(unsafe) static var showsBackground = true
    nonisolated(unsafe) static var opened: URL?                 /* a Link the tap hit */
    nonisolated(unsafe) static var hidingAccentable = false     /* the accented pass without the widgetAccentable content */
    static func run(_ c: [_WKConfig]) {
        configs = c
        let env = ProcessInfo.processInfo.environment
        if let p = env["ISIM_PREVIEW"], !p.isEmpty {          /* isim preview: UIKit shows the #Preview (Previews.swift) */
            _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, nil); return
        }
        guard env["ISIM_WIDGET_REQUEST"] != nil else {
            NSLog("isim WidgetKit: widget extension with %ld widget(s); the home screen runs it (Edit Home Screen > +)", c.flatMap { $0._widgets }.count)
            exit(0)
        }
        _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(_WKHostDelegate.self))
    }
    static func png(_ view: AnyView, size: CGSize, look: _WKLook) -> (Data, UIView) {
        let m = look.margins
        var root = AnyView(view.environment(\.widgetFamily, look.family ?? .systemSmall)
            .environment(\.widgetRenderingMode, look.mode)
            .environment(\.showsWidgetContainerBackground, look.background)
            .environment(\.widgetContentMargins, EdgeInsets(top: m, leading: m, bottom: m, trailing: m))
            .environment(\.openURL, OpenURLAction { u in _WKHost.opened = u; return .handled })
            .frame(width: size.width, height: size.height))
        if look.mode != .fullColor { root = AnyView(root.foregroundColor(.white).environment(\.colorScheme, .dark)) }   /* Lock Screen, tinted: dark */
        if look.redacted { root = AnyView(root.redacted(reason: .placeholder)) }
        let host = UIHostingController(rootView: root)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = look.family == nil || !look.background || look.family!.isAccessory ? .clear : .systemBackground
        if look.mode != .fullColor { host.overrideUserInterfaceStyle = .dark }
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = look.scale; fmt.opaque = false
        let r = UIGraphicsImageRenderer(size: size, format: fmt)
        if look.mode == .accented {                     /* twice: all of it, then without the accentable content */
            let all = r.image { _ in _ = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false) }
            hidingAccentable = true
            let plain = UIHostingController(rootView: root)
            plain.view.frame = host.view.frame; plain.view.backgroundColor = .clear
            plain.view.setNeedsLayout(); plain.view.layoutIfNeeded()
            let rest = r.image { _ in _ = plain.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false) }
            hidingAccentable = false
            if let d = accented(all, rest, tint: look.tint) { return (d, host.view) }
            return (all.pngData() ?? Data(), host.view)
        }
        if look.mode == .vibrant {
            let img = r.image { _ in _ = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false) }
            if let d = vibrant(img) { return (d, host.view) }
            return (img.pngData() ?? Data(), host.view)
        }
        let data = r.pngData { _ in _ = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false) }
        return (data, host.view)
    }
    /// the Lock Screen's vibrant rendering (adapted): every pixel becomes white with its luminance as opacity, so the
    /// wallpaper shows through dark parts, like the system's vibrant material
    static func vibrant(_ img: UIImage) -> Data? {
        guard let cg = img.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let raw = ctx.data else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let p = raw.bindMemory(to: UInt8.self, capacity: w * h * 4)
        for i in 0..<(w * h) {
            let o = i * 4
            if p[o + 3] == 0 { continue }
            let l = UInt8(min(255, (299 * Int(p[o]) + 587 * Int(p[o + 1]) + 114 * Int(p[o + 2])) / 1000))   /* premultiplied: L x alpha */
            p[o] = l; p[o + 1] = l; p[o + 2] = l; p[o + 3] = l
        }
        guard let out = ctx.makeImage() else { return nil }
        return UIImage(cgImage: out).pngData()
    }
    /// the tinted Home Screen's accented rendering (adapted): luminance as opacity, like vibrant, in white for most of the
    /// content and in the tint where the widgetAccentable content is (what differs between the two passes)
    static func accented(_ all: UIImage, _ rest: UIImage, tint: (CGFloat, CGFloat, CGFloat)) -> Data? {
        guard let a = all.cgImage, let b = rest.cgImage, a.width == b.width, a.height == b.height else { return nil }
        let w = a.width, h = a.height, cs = CGColorSpaceCreateDeviceRGB(), info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ca = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: info),
              let cb = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: info),
              let ra = ca.data, let rb = cb.data else { return nil }
        ca.draw(a, in: CGRect(x: 0, y: 0, width: w, height: h)); cb.draw(b, in: CGRect(x: 0, y: 0, width: w, height: h))
        let p = ra.bindMemory(to: UInt8.self, capacity: w * h * 4), q = rb.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let tr = Int(tint.0 * 255), tg = Int(tint.1 * 255), tb = Int(tint.2 * 255)
        func lum(_ x: UnsafeMutablePointer<UInt8>, _ o: Int) -> Int { min(255, (299 * Int(x[o]) + 587 * Int(x[o + 1]) + 114 * Int(x[o + 2])) / 1000) }
        for i in 0..<(w * h) {
            let o = i * 4
            let diff = abs(Int(p[o]) - Int(q[o])) + abs(Int(p[o + 1]) - Int(q[o + 1])) + abs(Int(p[o + 2]) - Int(q[o + 2])) + abs(Int(p[o + 3]) - Int(q[o + 3]))
            if diff > 24 {                              /* accentable: the tint, as bright as the content */
                let l = max(lum(p, o), Int(p[o + 3]) / 2)
                p[o] = UInt8(tr * l / 255); p[o + 1] = UInt8(tg * l / 255); p[o + 2] = UInt8(tb * l / 255); p[o + 3] = UInt8(l)
            } else {
                let l = UInt8(lum(q, o))
                p[o] = l; p[o + 1] = l; p[o + 2] = l; p[o + 3] = l
            }
        }
        guard let out = ca.makeImage() else { return nil }
        return UIImage(cgImage: out).pngData()
    }
    /// what the request says about where the widget is shown
    static func lookFor(_ req: [String: Any], _ family: WidgetFamily, _ spec: _WKWidgetSpec) -> _WKLook {
        var l = _WKLook(family: family)
        l.mode = ["vibrant": .vibrant, "accented": .accented][req["renderingMode"] as? String ?? ""] ?? .fullColor
        l.background = (req["background"] as? Bool ?? true) && !family.isAccessory
        l.margins = spec.marginsDisabled || family.isAccessory ? 0 : 16
        if let sc = req["scale"] as? Double, sc > 0 { l.scale = CGFloat(sc) }
        if let hex = req["tint"] as? String, hex.count == 7, let v = Int(hex.dropFirst(), radix: 16) {
            l.tint = (CGFloat((v >> 16) & 255) / 255, CGFloat((v >> 8) & 255) / 255, CGFloat(v & 255) / 255)
        }
        return l
    }
    /// the content closures read these while they build the views
    static func prepare(_ look: _WKLook) {
        family = look.family ?? .systemSmall; margins = look.margins; showsBackground = look.background
    }
    static func renderWidget(_ spec: _WKWidgetSpec, family: WidgetFamily, out: String, tap: CGPoint?, req: [String: Any]) async {
        let look = lookFor(req, family, spec), config = req["config"] as? [String: Any] ?? [:]
        let ctx = TimelineProviderContext(family: family, displaySize: family.size, isPreview: false)
        let base = (out as NSString).appendingPathComponent("\(spec.kind)-\(family.rawValue)")
        prepare(look)
        if let p = tap {                                       /* a tap: the control it hits runs (an intent, a Link); else the widget's URL */
            let tl = await spec.timeline(ctx, config)
            var result: [String: Any] = [:]
            if let first = currentEntry(tl.entries) {
                url = nil
                let (_, view) = png(first.view, size: family.size, look: look)
                let entryURL = url ?? first.url                 /* widgetURL runs while the view is drawn */
                var hit = view.hitTest(p, with: nil)
                while let h = hit, !(h is UIControl) { hit = h.superview }
                opened = nil
                if let c = hit as? UIControl {
                    NSLog("isim WidgetKit: tap on %@ at %.0f,%.0f", spec.kind, p.x, p.y)
                    c.sendActions(for: .touchUpInside)
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    var waited = 0
                    while _IsimIntentControls.running > 0 && waited < 100 { try? await Task.sleep(nanoseconds: 50_000_000); waited += 1 }
                    if let u = opened { result["open"] = u.absoluteString; NSLog("isim WidgetKit: tap on %@ opens the Link %@", spec.kind, u.absoluteString) }
                } else {
                    result["open"] = entryURL?.absoluteString ?? ""
                    NSLog("isim WidgetKit: tap on %@ opens the app%@", spec.kind, entryURL.map { " with " + $0.absoluteString } ?? "")
                }
            }
            (result as NSDictionary).write(toFile: base + "-tap.plist", atomically: true)
            if result["open"] != nil { return }                 /* nothing ran: the timeline stays */
        }
        let tl = await spec.timeline(ctx, config)
        var entries: [[String: Any]] = []
        for (i, e) in tl.entries.prefix(12).enumerated() {
            let file = base + "-\(i).png"
            url = nil
            let (data, _) = png(e.view, size: family.size, look: look)
            try? data.write(to: URL(fileURLWithPath: file))
            var d: [String: Any] = ["date": e.date, "file": file]
            if let u = url ?? e.url { d["url"] = u.absoluteString }
            entries.append(d)
        }
        var info: [String: Any] = ["kind": spec.kind, "family": family.rawValue, "entries": entries,
                                   "policy": ["atEnd", "never", "after"][tl.policy.kind]]
        if let d = tl.policy.date { info["after"] = d }
        (info as NSDictionary).write(toFile: base + ".plist", atomically: true)
        NSLog("isim WidgetKit: rendered %@ (%@%@): %ld entr%@, policy %@", spec.kind, family.rawValue, look.mode == .vibrant ? ", vibrant" : look.mode == .accented ? ", accented" : !look.background ? ", no background" : "",
              entries.count, entries.count == 1 ? "y" : "ies", info["policy"] as! String)
    }
    static func currentEntry(_ entries: [_WKEntry]) -> _WKEntry? {
        let now = Date()
        return entries.last(where: { $0.date <= now }) ?? entries.first
    }
    static func handle() async {
        let env = ProcessInfo.processInfo.environment
        guard let reqPath = env["ISIM_WIDGET_REQUEST"], let req = NSDictionary(contentsOfFile: reqPath) as? [String: Any] else { exit(2) }
        let mode = req["mode"] as? String ?? "render", out = req["out"] as? String ?? "/tmp"
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true, attributes: nil)
        let widgets = configs.flatMap { $0._widgets }, activities = configs.flatMap { $0._activities }
        let kind = req["kind"] as? String ?? ""
        let family = WidgetFamily(rawValue: req["family"] as? String ?? "") ?? .systemSmall
        let spec = widgets.first(where: { $0.kind == kind })
        switch mode {
        case "list":
            let list: [[String: Any]] = widgets.map { ["kind": $0.kind, "name": $0.name.isEmpty ? $0.kind : $0.name, "description": $0.description,
                                                       "families": $0.families.map { $0.rawValue }, "configurable": !($0.params?([:]).params.isEmpty ?? true)] }
            (["widgets": list, "activities": activities.map { $0.typeName }] as NSDictionary).write(toFile: (out as NSString).appendingPathComponent("widgets.plist"), atomically: true)
            NSLog("isim WidgetKit: %ld widget kind(s), %ld Live Activity configuration(s)", list.count, activities.count)
        case "render", "tap":
            guard let spec else { NSLog("isim WidgetKit: no widget of kind %@", kind); break }
            var tap: CGPoint?
            if mode == "tap", let x = req["x"] as? Double, let y = req["y"] as? Double { tap = CGPoint(x: x, y: y) }
            await renderWidget(spec, family: family, out: out, tap: tap, req: req)
        case "placeholder":                                   /* placeholder(in:), redacted: shown until the first timeline arrives */
            guard let spec else { break }
            var look = lookFor(req, family, spec); look.redacted = true
            prepare(look)
            let ctx = TimelineProviderContext(family: family, displaySize: family.size, isPreview: false)
            let (data, _) = png(spec.placeholder(ctx), size: family.size, look: look)
            try? data.write(to: URL(fileURLWithPath: (out as NSString).appendingPathComponent("\(kind)-\(family.rawValue)-placeholder.png")))
            NSLog("isim WidgetKit: placeholder of %@ (%@)", kind, family.rawValue)
        case "snapshot":                                      /* the galleries: a snapshot per family (isPreview) */
            let fams = (req["families"] as? [String] ?? [family.rawValue]).compactMap { WidgetFamily(rawValue: $0) }
            for s in widgets where kind.isEmpty || s.kind == kind {
                for f in fams where s.families.contains(f) {
                    let look = lookFor(req, f, s)
                    prepare(look)
                    let e = await s.snapshot(TimelineProviderContext(family: f, displaySize: f.size, isPreview: true), req["config"] as? [String: Any] ?? [:])
                    let (data, _) = png(e.view, size: f.size, look: look)
                    try? data.write(to: URL(fileURLWithPath: (out as NSString).appendingPathComponent("\(s.kind)-\(f.rawValue)-snapshot.png")))
                }
            }
            NSLog("isim WidgetKit: snapshots (%@)", fams.map { $0.rawValue }.joined(separator: ", "))
        case "params":                                        /* Edit Widget: the configuration intent's parameters */
            guard let spec, let p = spec.params?(req["config"] as? [String: Any] ?? [:]) else { NSLog("isim WidgetKit: %@ has no configuration", kind); break }
            (["title": p.title, "description": p.description, "params": p.params] as NSDictionary)
                .write(toFile: (out as NSString).appendingPathComponent("\(kind)-params.plist"), atomically: true)
            NSLog("isim WidgetKit: %@ has %ld parameter(s): %@", kind, p.params.count, p.params.map { "\($0["name"] ?? "")" }.joined(separator: ", "))
        case "activity":
            guard let path = req["activity"] as? String, let rec = _IsimActivityRecord.load(path) else { break }
            let info = NSDictionary(contentsOfFile: path) as? [String: Any] ?? [:]
            let staleT = info["stale"] as? Double ?? 0, isStale = !rec.ended && staleT > 0 && Date().timeIntervalSince1970 >= staleT
            _WKHost.tint = nil; _WKHost.url = nil                 /* activityBackgroundTint / widgetURL run while the views are built */
            guard let aspec = activities.first(where: { $0.typeName == rec.type }), let views = aspec.render(rec.attributes, rec.state, isStale, info["id"] as? String ?? "") else {
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
                let (data, _) = png(styled, size: size, look: _WKLook())
                let f = (out as NSString).appendingPathComponent("\(name).png")
                try? data.write(to: URL(fileURLWithPath: f)); files[name] = f
            }
            if let u = _WKHost.url { files["url"] = u.absoluteString }
            if isStale { files["stale"] = "1" }
            (files as NSDictionary).write(toFile: (out as NSString).appendingPathComponent("activity.plist"), atomically: true)
            NSLog("isim WidgetKit: rendered Live Activity %@ (lock screen, Dynamic Island)%@", rec.type, isStale ? " stale" : "")
        case "controls", "control-run": await _CWHost.handle(mode: mode, request: req, out: out)     /* Controls.swift */
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
