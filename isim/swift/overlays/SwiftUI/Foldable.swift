// isim SwiftUI (iOS 27.1): the APIs for foldable devices — the hinge (DeviceHinge, DeviceHingeContext,
// onHingeChange), reserved regions (GeometryProxy.reservedRegions), the vertical bar (toolbarVerticalBehavior,
// toolbarVerticalCompressionBehavior, axisBehavior, \.toolbarVerticalEdge) and CameraCaptureAccessory (with the iOS 27
// SceneAccessoryContent and sceneAccessory it is used through). Signatures from Apple's documentation. Adapted like
// isim's UIKit for foldable devices (UIArrangements.m): none of isim's devices folds (issue #115), so there is never a
// hinge (the context stays `hinge == nil` and never changes), the only reserved region is the occlusion of the Dynamic
// Island or the notch (no division), there is no vertical bar (its edge is nil; the behaviours are kept and change
// nothing) and the camera capture accessory is never available (isim has no camera capture session to present it in).
// `\.splitArrangementAxis` and `\.overlayArrangementZIndex` are in Arrangement.swift.
import UIKit

// MARK: - Hinge

/// The state of one hinge: its angle and a status the system derives from it.
@available(iOS 27.1, *)
public struct DeviceHinge: Equatable, Hashable, Sendable {
    /// The status of a hinge.
    public struct Status: Equatable, Hashable, Sendable {
        let raw: Int
        public static var closed: DeviceHinge.Status { Status(raw: 0) }
        public static var partiallyOpen: DeviceHinge.Status { Status(raw: 1) }
        public static var fullyOpen: DeviceHinge.Status { Status(raw: 2) }
    }
    /// The current angle of the hinge.
    public let angle: Angle
    /// The current status of the hinge.
    public let status: DeviceHinge.Status
}

/// The hinges of the device, for onHingeChange.
@available(iOS 27.1, *)
public struct DeviceHingeContext: Equatable, Sendable {
    /// The device's hinge; nil on a device that does not fold (all of isim's).
    public let hinge: DeviceHinge?
}

extension View {
    /// Runs `action` with the old and new context when the device's hinge changes. isim's devices do not fold, so the
    /// context (no hinge) never changes and `action` is not called.
    @available(iOS 27.1, *)
    public func onHingeChange(isEnabled: Bool = true, _ action: @escaping (DeviceHingeContext, DeviceHingeContext) -> Void) -> some View {
        _env { _ in }
    }
}

// MARK: - Reserved regions

/// What should happen to geometry when the layout direction changes.
public enum LayoutDirectionBehavior: Hashable, Sendable {
    /// Never mirrored.
    case fixed
    /// Mirrored when the layout direction is `in`.
    case mirrors(in: LayoutDirection)
    /// Mirrored when the layout direction is right-to-left.
    public static var mirrors: LayoutDirectionBehavior { .mirrors(in: .rightToLeft) }
}

/// A region of a view's coordinate space that another entity (the Dynamic Island, a camera, a hinge) reserves.
@available(iOS 27.1, *)
public struct ReservedRegion: Identifiable, Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// The identifier of a region ("dynamic-island", "notch").
    public struct ID: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let name: String
        public var description: String { name }
        public var debugDescription: String { "ReservedRegion.ID(\(name))" }
        public var customMirror: Mirror { Mirror(self, children: ["name": name]) }
    }
    /// A kind of region.
    public struct Kind: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let raw: Int
        /// An element (the Dynamic Island, a camera, window controls) covers the content there.
        public static var occlusion: ReservedRegion.Kind { Kind(raw: 1) }
        /// The content splits into separate regions there (the fold of a hinge).
        public static var division: ReservedRegion.Kind { Kind(raw: 2) }
        public var description: String { raw == 1 ? "occlusion" : "division" }
        public var debugDescription: String { "ReservedRegion.Kind.\(description)" }
        public var customMirror: Mirror { Mirror(self, children: ["kind": description]) }
    }
    /// Options for querying regions.
    @frozen public struct QueryOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        /// Include inactive regions.
        public static var includeInactive: ReservedRegion.QueryOptions { QueryOptions(rawValue: 1) }
    }
    public let id: ReservedRegion.ID
    /// The region in the view's coordinate space, margins included.
    public let frame: CGRect
    public let isActive: Bool
    public let kind: ReservedRegion.Kind
    /// The margins around the region's rect for interactive content (included in `frame`).
    public let margins: EdgeInsets
    public static func == (a: ReservedRegion, b: ReservedRegion) -> Bool {
        a.id == b.id && a.frame == b.frame && a.isActive == b.isActive && a.kind == b.kind && a.margins == b.margins
    }
    public func hash(into h: inout Hasher) { h.combine(id); h.combine(kind) }
    public var description: String {
        "\(id) \(kind) (\(frame.minX) \(frame.minY); \(frame.width) x \(frame.height))\(isActive ? "" : " inactive")"
    }
    public var debugDescription: String { "ReservedRegion(\(description))" }
    public var customMirror: Mirror {
        Mirror(self, children: ["id": id, "frame": frame, "isActive": isActive, "kind": kind, "margins": margins])
    }
}

extension GeometryProxy {
    /// The reserved regions of `kind` that intersect this view, in its coordinate space (UIKit's
    /// UIView.reservedRegions of the window, moved into the view; mirrored in a right-to-left layout unless `.fixed`).
    @available(iOS 27.1, *)
    public func reservedRegions(kind: ReservedRegion.Kind, options: ReservedRegion.QueryOptions = [],
                                layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors) -> [ReservedRegion] {
        let me = frame(in: .global), size = self.size
        return MainActor.assumeIsolated {
            guard let w = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first else { return [] }
            let rtl = w.effectiveUserInterfaceLayoutDirection == .rightToLeft
            let mirror: Bool
            switch layoutDirectionBehavior {
            case .fixed: mirror = false
            case .mirrors(let d): mirror = (d == .rightToLeft) == rtl
            }
            let uk: UIView.ReservedRegion.Kind = kind == .occlusion ? .occlusion : .division
            return w.reservedRegions(kind: uk, options: UIView.ReservedRegion.QueryOptions(rawValue: options.rawValue)).compactMap { r in
                var f = r.frame.offsetBy(dx: -me.minX, dy: -me.minY)
                guard f.intersects(CGRect(origin: .zero, size: size)) else { return nil }
                var m = EdgeInsets(top: r.margins.top, leading: r.margins.left, bottom: r.margins.bottom, trailing: r.margins.right)
                if mirror {
                    f.origin.x = size.width - f.maxX
                    swap(&m.leading, &m.trailing)
                }
                return ReservedRegion(id: ReservedRegion.ID(name: r.id), frame: f, isActive: r.isActive, kind: kind, margins: m)
            }
        }
    }
}

// MARK: - Vertical bar

/// Whether the vertical bar is used.
@available(iOS 27.1, *)
public struct ToolbarVerticalBehavior: Equatable, Hashable, Sendable {
    let raw: Int
    /// The system decides (isim's devices have no vertical bar).
    public static let automatic = ToolbarVerticalBehavior(raw: 0)
    /// No vertical bar: bar content stays in the top and bottom bars.
    public static let disabled = ToolbarVerticalBehavior(raw: 1)
}
/// Which bar compresses first when different bars share a constrained vertical bar.
@available(iOS 27.1, *)
public struct ToolbarVerticalCompressionBehavior: Equatable, Hashable, Sendable {
    let raw: Int
    public static let automatic = ToolbarVerticalCompressionBehavior(raw: 0)
    public static let prefersTabBar = ToolbarVerticalCompressionBehavior(raw: 1)
    public static let prefersToolbarItems = ToolbarVerticalCompressionBehavior(raw: 2)
}
/// The bar axes a toolbar item can appear in.
@available(iOS 27.1, *)
public struct ToolbarItemAxisBehavior: Equatable, Hashable, Sendable {
    let raw: Int
    public static let automatic = ToolbarItemAxisBehavior(raw: 0)
    public static let horizontalOnly = ToolbarItemAxisBehavior(raw: 1)
    public static let verticalPreferred = ToolbarItemAxisBehavior(raw: 2)
}

struct _ToolbarVerticalKey: EnvironmentKey { static var defaultValue: (Int, Int) { (0, 0) } }      // behaviour, compression
extension EnvironmentValues {
    var _toolbarVertical: (Int, Int) { get { self[_ToolbarVerticalKey.self] } set { self[_ToolbarVerticalKey.self] = newValue } }
    /// The edge the system puts the vertical bar on here; nil where there is never one (all of isim's devices).
    @available(iOS 27.1, *)
    public var toolbarVerticalEdge: HorizontalEdge? { nil }
}
extension View {
    /// Whether the vertical bar is used (kept; isim's devices have none, so the bars stay horizontal).
    @available(iOS 27.1, *)
    public func toolbarVerticalBehavior(_ behavior: ToolbarVerticalBehavior) -> some View { _env { $0._toolbarVertical.0 = behavior.raw } }
    /// Which bar compresses first in a constrained vertical bar (kept; isim's devices have no vertical bar).
    @available(iOS 27.1, *)
    public func toolbarVerticalCompressionBehavior(_ behavior: ToolbarVerticalCompressionBehavior) -> some View {
        _env { $0._toolbarVertical.1 = behavior.raw }
    }
}
@available(iOS 27.1, *)
extension ToolbarContent {
    /// The bar axes these items can appear in. isim's bars are all horizontal, so every item stays in them.
    public func axisBehavior(_ behavior: ToolbarItemAxisBehavior) -> _ToolbarList { _ToolbarList(_items: _items) }
}

// MARK: - Scene accessories

/// Content shown by the system outside the app's scene (iOS 27): a camera capture accessory, for example.
@available(iOS 27.0, *)
@MainActor public protocol SceneAccessoryContent {
    associatedtype Body: SceneAccessoryContent
    @_SceneAccessoryContentBuilder var body: Body { get }
}
@available(iOS 27.0, *)
extension Never: SceneAccessoryContent {}
@available(iOS 27.0, *)
extension EmptyView: SceneAccessoryContent {}
/// Several scene accessories.
@available(iOS 27.0, *)
public struct _SceneAccessoryTuple: SceneAccessoryContent {
    let items: [any SceneAccessoryContent]
    public var body: Never { fatalError() }
}
/// Builds scene accessory content (Apple's closures take `@ContentBuilder`, an Xcode 27 compiler feature isim's
/// toolchain lacks; this builder accepts the same closures).
@available(iOS 27.0, *)
@resultBuilder public enum _SceneAccessoryContentBuilder {
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<C: SceneAccessoryContent>(_ c: C) -> C { c }
    public static func buildBlock<each C: SceneAccessoryContent>(_ c: repeat each C) -> _SceneAccessoryTuple {
        var items: [any SceneAccessoryContent] = []
        for x in repeat each c { items.append(x) }
        return _SceneAccessoryTuple(items: items)
    }
}
@available(iOS 27.0, *)
extension SceneAccessoryContent {
    /// Calls `action` when the accessory becomes available or unavailable. isim's camera capture accessories never
    /// become available, so it is not called for them.
    public nonisolated func onAvailabilityChange(perform action: @escaping (Bool) -> Void) -> some SceneAccessoryContent { self }
}
extension View {
    /// The scene accessories of this view's scene (isim presents none of them from SwiftUI yet).
    @available(iOS 27.0, *)
    public func sceneAccessory<C: SceneAccessoryContent>(@_SceneAccessoryContentBuilder content: () -> C) -> some View {
        _ = content()
        return _env { _ in }
    }
}

/// A scene accessory that shows content during camera capture, while the app has an active capture session. isim has
/// no camera capture session that would present it, so it is never available (like UIKit's camera capture accessories).
@available(iOS 27.1, *)
public struct CameraCaptureAccessory<Content: View>: SceneAccessoryContent {
    let content: () -> Content
    let isEnabled: Binding<Bool>?
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content; isEnabled = nil }
    public init(isEnabled: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) { self.content = content; self.isEnabled = isEnabled }
    public var body: Never { fatalError() }
}
