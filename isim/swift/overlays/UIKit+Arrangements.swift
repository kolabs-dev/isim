// Apple's Swift API for arrangement view controllers, layout regions, reserved regions and the vertical bar
// (iOS 26 / 27.1) as value types over isim's Objective-C classes (UIArrangementViewController.h,
// UIViewLayoutRegion.h; the Objective-C classes are the `_…ObjC` types here).
import Foundation
import CoreGraphics

// MARK: - Arrangement view controllers (iOS 27.1)
@available(iOS 27.1, *)
extension UIArrangementViewController {
    /// The primary or secondary view of an arrangement.
    public struct ViewPlacement: Hashable, Sendable {
        let rawValue: Int
        public static var primary: ViewPlacement { ViewPlacement(rawValue: 1) }
        public static var secondary: ViewPlacement { ViewPlacement(rawValue: 2) }
        var objc: _UIArrangementViewPlacementObjC { _UIArrangementViewPlacementObjC(rawValue: rawValue) ?? .none }
    }
    /// The state of a view within the current arrangement.
    public struct ViewState: Hashable, Sendable {
        public var isHidden: Bool
        public var splitAxis: UIAxis
        public var zIndex: Int
        public static func == (a: ViewState, b: ViewState) -> Bool { a.isHidden == b.isHidden && a.splitAxis == b.splitAxis && a.zIndex == b.zIndex }
        public func hash(into h: inout Hasher) { h.combine(isHidden); h.combine(splitAxis.rawValue); h.combine(zIndex) }
    }
    /// How an arrangement view controller lays out its view controllers.
    public protocol Arrangement {
        associatedtype ViewProperties
        var defaultViewProperties: ViewProperties { get }
        mutating func setViewProperties(_ properties: ViewProperties, for placement: ViewPlacement)
        /// isim: the Objective-C arrangement this one lays out as (custom arrangements: nil, laid out as a split)
        func _isimArrangement() -> _UIArrangementObjC?
    }

    public final func updateArrangement<A>(_ arrangement: A, animated: Bool = false) where A: Arrangement {
        __update(arrangement._isimArrangement() ?? _UISplitArrangementObjC(), animated: animated)
    }
    public final func viewController(for placement: ViewPlacement) -> UIViewController? { __viewController(for: placement.objc) }
    public final func setViewController(_ viewController: UIViewController?, for placement: ViewPlacement, animated: Bool = false) {
        __setViewController(viewController, for: placement.objc, animated: animated)
    }
    public final func placement(for viewController: UIViewController) -> ViewPlacement? {
        let p = __placement(for: viewController)
        return p == .none ? nil : ViewPlacement(rawValue: p.rawValue)
    }
    public final func state(for placement: ViewPlacement) -> ViewState? {
        guard let s = __state(for: placement.objc) else { return nil }
        return ViewState(isHidden: s.isHidden, splitAxis: s.splitAxis, zIndex: s.zIndex)
    }
}
@available(iOS 27.1, *)
extension UIArrangementViewController.Arrangement {
    public func _isimArrangement() -> _UIArrangementObjC? { nil }
}
@available(iOS 27.1, *)
extension UIArrangementViewController.Arrangement where Self == UISplitArrangement {
    /// The default split arrangement.
    public static var split: UISplitArrangement { UISplitArrangement() }
}
@available(iOS 27.1, *)
extension UIArrangementViewController.Arrangement where Self == UIOverlayArrangement {
    /// The default overlay arrangement.
    public static var overlay: UIOverlayArrangement { UIOverlayArrangement() }
}

/// An arrangement that splits views.
@available(iOS 27.1, *)
public struct UISplitArrangement: UIArrangementViewController.Arrangement, Hashable, Sendable {
    public struct Dimension: Hashable, Sendable {
        enum Kind: Hashable, Sendable { case automatic, intrinsic, absolute(CGFloat), fractional(CGFloat) }
        let kind: Kind
        public static var automatic: Dimension { Dimension(kind: .automatic) }
        public static var intrinsic: Dimension { Dimension(kind: .intrinsic) }
        public static func absolute(_ dimension: CGFloat) -> Dimension { Dimension(kind: .absolute(dimension)) }
        public static func fractional(_ dimension: CGFloat) -> Dimension { Dimension(kind: .fractional(dimension)) }
        var objc: _UISplitArrangementDimensionObjC {
            switch kind {
            case .automatic: return .automatic()
            case .intrinsic: return .intrinsic()
            case .absolute(let v): return .absoluteDimension(v)
            case .fractional(let v): return .fractionalDimension(v)
            }
        }
    }
    public struct DimensionRange: Hashable, Sendable {
        public var minimum: Dimension = .automatic
        public var preferred: Dimension = .automatic
        public var maximum: Dimension = .automatic
        public init() {}
        var objc: _UISplitArrangementDimensionRangeObjC {
            let r = _UISplitArrangementDimensionRangeObjC()
            r.minimum = minimum.objc; r.preferred = preferred.objc; r.maximum = maximum.objc
            return r
        }
    }
    public struct ViewProperties: Hashable, Sendable {
        public var width = DimensionRange()
        public var height = DimensionRange()
        public var layoutPriority: CGFloat = 0
        public init() {}
    }
    var allowedAxes: UIAxis = [.horizontal, .vertical]
    var properties: [UIArrangementViewController.ViewPlacement: ViewProperties] = [:]
    public init() {}
    public var defaultViewProperties: ViewProperties { ViewProperties() }
    /// Restricts the axes the split can use.
    public func axes(_ axes: UIAxis) -> UISplitArrangement { var c = self; c.allowedAxes = axes; return c }
    public mutating func setViewProperties(_ properties: ViewProperties, for placement: UIArrangementViewController.ViewPlacement) { self.properties[placement] = properties }
    public func _isimArrangement() -> _UIArrangementObjC? {
        let a = _UISplitArrangementObjC()
        a.axes = allowedAxes
        for (placement, p) in properties {
            let o = _UISplitArrangementViewPropertiesObjC()
            o.width = p.width.objc; o.height = p.height.objc; o.layoutPriority = p.layoutPriority
            a.setViewProperties(o, for: placement.objc)
        }
        return a
    }
    public static func == (a: UISplitArrangement, b: UISplitArrangement) -> Bool { a.allowedAxes == b.allowedAxes && a.properties == b.properties }
    public func hash(into h: inout Hasher) { h.combine(allowedAxes.rawValue); h.combine(properties) }
}

/// An arrangement that overlays views.
@available(iOS 27.1, *)
public struct UIOverlayArrangement: UIArrangementViewController.Arrangement, Hashable, Sendable {
    public struct ViewProperties: Hashable, Sendable {
        /// The edge the view occupies when the overlay turns into a side-by-side layout.
        public var edge: NSDirectionalRectEdge = []
        public init() {}
        public static func == (a: ViewProperties, b: ViewProperties) -> Bool { a.edge == b.edge }
        public func hash(into h: inout Hasher) { h.combine(edge.rawValue) }
    }
    var allowedAxes: UIAxis = [.horizontal, .vertical]
    var properties: [UIArrangementViewController.ViewPlacement: ViewProperties] = [:]
    public init() {}
    public var defaultViewProperties: ViewProperties { ViewProperties() }
    /// Restricts the axes on which the overlay can turn side by side.
    public func axes(_ axes: UIAxis) -> UIOverlayArrangement { var c = self; c.allowedAxes = axes; return c }
    public mutating func setViewProperties(_ properties: ViewProperties, for placement: UIArrangementViewController.ViewPlacement) { self.properties[placement] = properties }
    public func _isimArrangement() -> _UIArrangementObjC? {
        let a = _UIOverlayArrangementObjC()
        a.axes = allowedAxes
        for (placement, p) in properties { let o = _UIOverlayArrangementViewPropertiesObjC(); o.edge = p.edge; a.setViewProperties(o, for: placement.objc) }
        return a
    }
    public static func == (a: UIOverlayArrangement, b: UIOverlayArrangement) -> Bool { a.allowedAxes == b.allowedAxes && a.properties == b.properties }
    public func hash(into h: inout Hasher) { h.combine(allowedAxes.rawValue); h.combine(properties) }
}

// MARK: - Layout regions (iOS 26; bars iOS 27.1)
@available(iOS 26.0, *)
extension UIView {
    public struct LayoutRegion: Hashable {
        public enum AdaptivityAxis: Hashable, Sendable { case horizontal, vertical }
        let objc: _UIViewLayoutRegionObjC
        static func axis(_ a: AdaptivityAxis?) -> _UIViewLayoutRegionAdaptivityAxisObjC { a == .horizontal ? .horizontal : a == .vertical ? .vertical : .none }
        public static func safeArea(cornerAdaptation: AdaptivityAxis? = nil) -> LayoutRegion { LayoutRegion(objc: .safeAreaLayoutRegion(withCornerAdaptation: axis(cornerAdaptation))) }
        public static func margins(cornerAdaptation: AdaptivityAxis? = nil) -> LayoutRegion { LayoutRegion(objc: .marginsLayoutRegion(withCornerAdaptation: axis(cornerAdaptation))) }
        public static func readableContent(cornerAdaptation: AdaptivityAxis? = nil) -> LayoutRegion { LayoutRegion(objc: .readableContentLayoutRegion(withCornerAdaptation: axis(cornerAdaptation))) }
        @available(iOS 27.1, *)
        public static func bar(onEdge edge: NSDirectionalRectEdge, extent: CGFloat) -> LayoutRegion { LayoutRegion(objc: ._bar(directionalEdge: edge, extent: extent)) }
        @available(iOS 27.1, *)
        public static func bar(onEdge edge: UIRectEdge, extent: CGFloat) -> LayoutRegion { LayoutRegion(objc: ._bar(edge: edge, extent: extent)) }
        public static func == (a: LayoutRegion, b: LayoutRegion) -> Bool { a.objc.isEqual(b.objc) }
        public func hash(into h: inout Hasher) { h.combine(objc.hash) }
    }
    public func layoutGuide(for region: LayoutRegion) -> UILayoutGuide { __layoutGuide(for: region.objc) }
    public func edgeInsets(for region: LayoutRegion) -> UIEdgeInsets { __edgeInsets(for: region.objc) }
    public func directionalEdgeInsets(for region: LayoutRegion) -> NSDirectionalEdgeInsets { __directionalEdgeInsets(for: region.objc) }
}

// MARK: - Reserved regions (iOS 27.1)
@available(iOS 27.1, *)
extension UIView {
    /// A region within the view's coordinate space that another entity occupies.
    public struct ReservedRegion: Identifiable, Hashable {
        public struct Kind: Hashable, Sendable {
            let rawValue: Int
            public static let occlusion = Kind(rawValue: 1)
            public static let division = Kind(rawValue: 2)
            var objc: _UIViewReservedRegionKindObjC { rawValue == 1 ? .occlusion() : .division() }
        }
        public struct QueryOptions: OptionSet, Hashable, Sendable {
            public let rawValue: UInt
            public init(rawValue: UInt) { self.rawValue = rawValue }
            public static let includeInactive = QueryOptions(rawValue: 1)
        }
        public let frame: CGRect
        public let isActive: Bool
        public let kind: Kind
        public let margins: UIEdgeInsets
        public let id: String
        public static func == (a: ReservedRegion, b: ReservedRegion) -> Bool {
            a.id == b.id && a.frame == b.frame && a.isActive == b.isActive && a.kind == b.kind && a.margins == b.margins
        }
        public func hash(into h: inout Hasher) { h.combine(id); h.combine(kind) }
    }
    public func reservedRegions(kind: ReservedRegion.Kind, options: ReservedRegion.QueryOptions = []) -> [ReservedRegion] {
        __reservedRegions(of: kind.objc, options: _UIViewReservedRegionQueryOptionsObjC(rawValue: options.rawValue)).map {
            ReservedRegion(frame: $0.frame, isActive: $0.isActive, kind: kind, margins: $0.margins, id: $0.identifier.description)
        }
    }
}

// MARK: - Vertical bar (iOS 27.1)
@available(iOS 27.1, *)
extension UITraitCollection {
    public static var systemTraitsAffectingVerticalBarEdge: [UITrait] {
        [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self, UITraitLayoutDirection.self]
    }
}
