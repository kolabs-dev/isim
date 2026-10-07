// isim MapKit for SwiftUI: Map (iOS 17 API with MapContentBuilder, and the iOS 14 coordinateRegion API),
// Marker, Annotation, MapPolyline, MapPolygon, MapCircle, UserAnnotation, MapCameraPosition, mapStyle,
// mapControls and onMapCameraChange — on top of isim's MKMapView.
@_spi(isim) import SwiftUI
import UIKit

// MARK: - camera

public struct MapCamera: Equatable, Sendable {
    public var centerCoordinate: CLLocationCoordinate2D
    public var distance: Double
    public var heading: Double
    public var pitch: Double
    public init(centerCoordinate: CLLocationCoordinate2D, distance: Double, heading: Double = 0, pitch: Double = 0) {
        self.centerCoordinate = centerCoordinate; self.distance = distance; self.heading = heading; self.pitch = pitch
    }
    public init(_ c: MKMapCamera) { self.init(centerCoordinate: c.centerCoordinate, distance: c.centerCoordinateDistance, heading: c.heading, pitch: Double(c.pitch)) }
    public static func == (a: MapCamera, b: MapCamera) -> Bool {
        a.centerCoordinate._equals(b.centerCoordinate) && a.distance == b.distance && a.heading == b.heading && a.pitch == b.pitch
    }
}

public struct MapCameraPosition: Equatable, Sendable {
    indirect enum Kind: Sendable { case automatic, region(MKCoordinateRegion), rect(MKMapRect), camera(MapCamera), item(MKMapItem), user(MapCameraPosition?) }
    let kind: Kind
    let serial: Int
    public internal(set) var positionedByUser = false
    nonisolated(unsafe) static var counter = 0
    init(_ k: Kind) { MapCameraPosition.counter += 1; kind = k; serial = MapCameraPosition.counter }
    public static var automatic: MapCameraPosition { MapCameraPosition(.automatic) }
    public static func region(_ region: MKCoordinateRegion) -> MapCameraPosition { MapCameraPosition(.region(region)) }
    public static func rect(_ rect: MKMapRect) -> MapCameraPosition { MapCameraPosition(.rect(rect)) }
    public static func camera(_ camera: MapCamera) -> MapCameraPosition { MapCameraPosition(.camera(camera)) }
    public static func item(_ mapItem: MKMapItem, allowsAutomaticPitch: Bool = false) -> MapCameraPosition { MapCameraPosition(.item(mapItem)) }
    public static func userLocation(followsHeading: Bool = false, fallback: MapCameraPosition) -> MapCameraPosition { MapCameraPosition(.user(fallback)) }
    public static func userLocation(followsHeading: Bool = false) -> MapCameraPosition { MapCameraPosition(.user(nil)) }
    public var region: MKCoordinateRegion? { if case .region(let r) = kind { return r }; return nil }
    public var rect: MKMapRect? { if case .rect(let r) = kind { return r }; return nil }
    public var camera: MapCamera? { if case .camera(let c) = kind { return c }; return nil }
    public var item: MKMapItem? { if case .item(let i) = kind { return i }; return nil }
    public var followsUserLocation: Bool { if case .user = kind { return true }; return false }
    public var isAutomatic: Bool { if case .automatic = kind { return true }; return false }
    public var fallbackPosition: MapCameraPosition? { if case .user(let f) = kind { return f }; return nil }
    public static func == (a: MapCameraPosition, b: MapCameraPosition) -> Bool { a.serial == b.serial }
}

public struct MapCameraBounds: Sendable {
    let rect: MKMapRect?, minDistance: Double?, maxDistance: Double?
    public init(centerCoordinateBounds: MKCoordinateRegion, minimumDistance: Double? = nil, maximumDistance: Double? = nil) {
        rect = _MKMapRect(for: centerCoordinateBounds); minDistance = minimumDistance; maxDistance = maximumDistance
    }
    public init(centerCoordinateBounds: MKMapRect, minimumDistance: Double? = nil, maximumDistance: Double? = nil) {
        rect = centerCoordinateBounds; minDistance = minimumDistance; maxDistance = maximumDistance
    }
    public init(minimumDistance: Double? = nil, maximumDistance: Double? = nil) { rect = nil; minDistance = minimumDistance; maxDistance = maximumDistance }
}

public struct MapInteractionModes: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let pan = MapInteractionModes(rawValue: 1), zoom = MapInteractionModes(rawValue: 2), rotate = MapInteractionModes(rawValue: 4), pitch = MapInteractionModes(rawValue: 8)
    public static let all: MapInteractionModes = [.pan, .zoom, .rotate, .pitch]
}

public struct MapCameraUpdateContext: Sendable {
    public let camera: MapCamera
    public let region: MKCoordinateRegion
    public let rect: MKMapRect
}
public enum MapCameraUpdateFrequency: Sendable { case continuous, onEnd }

// MARK: - styles & controls

public struct MapStyle: Sendable {
    let type: MKMapType
    public enum Elevation: Sendable { case automatic, flat, realistic }
    public enum StandardEmphasis: Sendable { case automatic, muted }
    public static var standard: MapStyle { MapStyle(type: .standard) }
    public static var imagery: MapStyle { MapStyle(type: .satellite) }
    public static var hybrid: MapStyle { MapStyle(type: .hybrid) }
    public static func standard(elevation: Elevation = .automatic, emphasis: StandardEmphasis = .automatic, pointsOfInterest: PointOfInterestCategories = .all, showsTraffic: Bool = false) -> MapStyle {
        MapStyle(type: emphasis == .muted ? .mutedStandard : .standard)
    }
    public static func imagery(elevation: Elevation = .automatic) -> MapStyle { MapStyle(type: .satellite) }
    public static func hybrid(elevation: Elevation = .automatic, pointsOfInterest: PointOfInterestCategories = .all, showsTraffic: Bool = false) -> MapStyle { MapStyle(type: .hybrid) }
}
public struct PointOfInterestCategories: Sendable {
    public static let all = PointOfInterestCategories()
    public static func including(_ c: [MKPointOfInterestCategory]) -> PointOfInterestCategories { PointOfInterestCategories() }
    public static func excluding(_ c: [MKPointOfInterestCategory]) -> PointOfInterestCategories { PointOfInterestCategories() }
}

public protocol _MapControl {}
public struct MapUserLocationButton: View, _MapControl { public init(scope: Namespace.ID? = nil) {}; public var body: some View { EmptyView() } }
public struct MapCompass: View, _MapControl { public init(scope: Namespace.ID? = nil) {}; public var body: some View { EmptyView() } }
public struct MapScaleView: View, _MapControl {
    public enum AnchorEdge: Sendable { case leading, trailing }
    public init(anchorEdge: AnchorEdge = .leading, scope: Namespace.ID? = nil) {}; public var body: some View { EmptyView() }
}
public struct MapPitchToggle: View, _MapControl { public init(scope: Namespace.ID? = nil) {}; public var body: some View { EmptyView() } }

struct _MapStyleKey: EnvironmentKey { static let defaultValue: MapStyle? = nil }
struct _MapCameraChangeKey: EnvironmentKey { static let defaultValue: [(MapCameraUpdateFrequency, (MapCameraUpdateContext) -> Void)] = [] }
struct _MapControlsKey: EnvironmentKey { static let defaultValue: Bool = false }
extension EnvironmentValues {
    var _mapStyle: MapStyle? { get { self[_MapStyleKey.self] } set { self[_MapStyleKey.self] = newValue } }
    var _mapCameraChange: [(MapCameraUpdateFrequency, (MapCameraUpdateContext) -> Void)] { get { self[_MapCameraChangeKey.self] } set { self[_MapCameraChangeKey.self] = newValue } }
    var _mapUserButton: Bool { get { self[_MapControlsKey.self] } set { self[_MapControlsKey.self] = newValue } }
}
extension View {
    public func mapStyle(_ style: MapStyle) -> some View { environment(\._mapStyle, style) }
    public func onMapCameraChange(frequency: MapCameraUpdateFrequency = .onEnd, _ action: @escaping () -> Void) -> some View {
        transformEnvironment(\._mapCameraChange) { $0.append((frequency, { _ in action() })) }
    }
    public func onMapCameraChange(frequency: MapCameraUpdateFrequency = .onEnd, _ action: @escaping (MapCameraUpdateContext) -> Void) -> some View {
        transformEnvironment(\._mapCameraChange) { $0.append((frequency, action)) }
    }
    /// map controls are accepted; isim shows the attribution only (the user-location button is not drawn)
    public func mapControls<C: View>(@ViewBuilder _ content: () -> C) -> some View { self }
    public func mapControlVisibility(_ visibility: Visibility) -> some View { self }
}

// MARK: - content

public protocol MapContent {}
enum _MapItem {
    case marker(title: String, coordinate: CLLocationCoordinate2D, tint: UIColor?, glyph: String?, image: String?, tag: AnyHashable?)
    case annotation(title: String, coordinate: CLLocationCoordinate2D, anchor: UnitPoint, view: AnyView, tag: AnyHashable?)
    case polyline(points: [MKMapPoint], stroke: UIColor, width: CGFloat)
    case polygon(points: [MKMapPoint], fill: UIColor?, stroke: UIColor?, width: CGFloat)
    case circle(center: CLLocationCoordinate2D, radius: Double, fill: UIColor?, stroke: UIColor?, width: CGFloat)
    case user
    var signature: String {
        switch self {
        case .marker(let t, let c, let tint, let g, let i, let tag): return "m|\(t)|\(c.latitude),\(c.longitude)|\(tint.map { "\($0)" } ?? "")|\(g ?? "")|\(i ?? "")|\(tag.map { "\($0)" } ?? "")"
        case .annotation(let t, let c, _, _, let tag): return "a|\(t)|\(c.latitude),\(c.longitude)|\(tag.map { "\($0)" } ?? "")"
        case .polyline(let p, let s, let w): return "l|\(p.count)|\(p.first?.x ?? 0)|\(p.last?.y ?? 0)|\(s)|\(w)"
        case .polygon(let p, let f, let s, let w): return "g|\(p.count)|\(p.first?.x ?? 0)|\(f.map { "\($0)" } ?? "")|\(s.map { "\($0)" } ?? "")|\(w)"
        case .circle(let c, let r, let f, let s, let w): return "c|\(c.latitude),\(c.longitude)|\(r)|\(f.map { "\($0)" } ?? "")|\(s.map { "\($0)" } ?? "")|\(w)"
        case .user: return "u"
        }
    }
}
protocol _MapPrimitive { var _items: [_MapItem] { get } }
func _mapItems(_ c: Any) -> [_MapItem] { (c as? _MapPrimitive)?._items ?? [] }
func _uiColor(_ s: Any?) -> UIColor? { (s as? Color)?.uiColor }

public struct _MapContentList: MapContent, _MapPrimitive { let _items: [_MapItem] }
@resultBuilder public enum MapContentBuilder {
    public static func buildExpression<C: MapContent>(_ c: C) -> _MapContentList { _MapContentList(_items: _mapItems(c)) }
    public static func buildBlock(_ parts: _MapContentList...) -> _MapContentList { _MapContentList(_items: parts.flatMap(\._items)) }
    public static func buildOptional(_ c: _MapContentList?) -> _MapContentList { c ?? _MapContentList(_items: []) }
    public static func buildEither(first c: _MapContentList) -> _MapContentList { c }
    public static func buildEither(second c: _MapContentList) -> _MapContentList { c }
    public static func buildArray(_ c: [_MapContentList]) -> _MapContentList { _MapContentList(_items: c.flatMap(\._items)) }
    public static func buildLimitedAvailability(_ c: _MapContentList) -> _MapContentList { c }
}
extension ForEach: MapContent where Content: MapContent {}
extension ForEach: _MapPrimitive where Content: MapContent { var _items: [_MapItem] { data.flatMap { _mapItems(content($0)) } } }
extension ForEach where Content: MapContent {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @MapContentBuilder content: @escaping (Data.Element) -> Content) {
        self.init(_data: data, _id: { $0[keyPath: id] }, _content: content)
    }
}
extension ForEach where Content: MapContent, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @MapContentBuilder content: @escaping (Data.Element) -> Content) { self.init(_data: data, _id: { $0.id }, _content: content) }
}

public struct Marker: MapContent, _MapPrimitive {
    let title: String, coordinate: CLLocationCoordinate2D, glyph: String?, image: String?
    var tint: UIColor?, tagValue: AnyHashable?
    public init(_ title: String, coordinate: CLLocationCoordinate2D) { self.title = title; self.coordinate = coordinate; glyph = nil; image = nil }
    public init<S: StringProtocol>(_ title: S, coordinate: CLLocationCoordinate2D) { self.init(String(title), coordinate: coordinate) }
    public init(_ title: String, systemImage: String, coordinate: CLLocationCoordinate2D) { self.title = title; self.coordinate = coordinate; glyph = nil; image = systemImage }
    public init(_ title: String, monogram: Text, coordinate: CLLocationCoordinate2D) { self.title = title; self.coordinate = coordinate; glyph = monogram._isimPlainString; image = nil }
    public init(_ title: String, image: String, coordinate: CLLocationCoordinate2D) { self.title = title; self.coordinate = coordinate; glyph = nil; self.image = image }
    public init(coordinate: CLLocationCoordinate2D) { self.init("", coordinate: coordinate) }
    public init(item: MKMapItem) { self.init(item.name ?? "", coordinate: item.placemark.coordinate) }
    var _items: [_MapItem] { [.marker(title: title, coordinate: coordinate, tint: tint, glyph: glyph, image: image, tag: tagValue)] }
    public func tint(_ color: Color?) -> Marker { var m = self; m.tint = color?.uiColor; return m }
    public func tint<S: ShapeStyle>(_ style: S) -> Marker { var m = self; m.tint = _uiColor(style); return m }
    public func tag<V: Hashable>(_ tag: V) -> Marker { var m = self; m.tagValue = AnyHashable(tag); return m }
}
public struct Annotation: MapContent, _MapPrimitive {
    let title: String, coordinate: CLLocationCoordinate2D, anchor: UnitPoint, view: AnyView
    var tagValue: AnyHashable?
    public init<C: View>(_ title: String, coordinate: CLLocationCoordinate2D, anchor: UnitPoint = .bottom, @ViewBuilder content: () -> C) {
        self.title = title; self.coordinate = coordinate; self.anchor = anchor; view = AnyView(content())
    }
    public init<C: View>(coordinate: CLLocationCoordinate2D, anchor: UnitPoint = .bottom, @ViewBuilder content: () -> C) {
        self.init("", coordinate: coordinate, anchor: anchor, content: content)
    }
    var _items: [_MapItem] { [.annotation(title: title, coordinate: coordinate, anchor: anchor, view: view, tag: tagValue)] }
    public func tag<V: Hashable>(_ tag: V) -> Annotation { var m = self; m.tagValue = AnyHashable(tag); return m }
    public func annotationTitles(_ v: Visibility) -> Annotation { self }
}
public struct MapPolyline: MapContent, _MapPrimitive {
    let points: [MKMapPoint]
    var color: UIColor = .systemBlue, width: CGFloat = 1
    public init(coordinates: [CLLocationCoordinate2D], contourStyle: ContourStyle = .straight) { points = coordinates.map(MKMapPoint.init) }
    public init(points: [MKMapPoint], contourStyle: ContourStyle = .straight) { self.points = points }
    public init(_ polyline: MKPolyline) { points = polyline._points }
    public init(_ route: MKRoute) { points = route.polyline._points }
    public enum ContourStyle: Sendable { case straight, geodesic }
    var _items: [_MapItem] { [.polyline(points: points, stroke: color, width: width)] }
    public func stroke<S: ShapeStyle>(_ s: S, lineWidth: CGFloat = 1) -> MapPolyline { var m = self; m.color = _uiColor(s) ?? .systemBlue; m.width = lineWidth; return m }
    public func stroke<S: ShapeStyle>(_ s: S, style: StrokeStyle) -> MapPolyline { stroke(s, lineWidth: style.lineWidth) }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> MapPolyline { var m = self; m.color = _uiColor(s) ?? m.color; return m }
}
public struct MapPolygon: MapContent, _MapPrimitive {
    let points: [MKMapPoint]
    var fill: UIColor? = UIColor.systemBlue.withAlphaComponent(0.4), strokeColor: UIColor?, width: CGFloat = 0
    public init(coordinates: [CLLocationCoordinate2D]) { points = coordinates.map(MKMapPoint.init) }
    public init(points: [MKMapPoint]) { self.points = points }
    public init(_ polygon: MKPolygon) { points = polygon._points }
    var _items: [_MapItem] { [.polygon(points: points, fill: fill, stroke: strokeColor, width: width)] }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> MapPolygon { var m = self; m.fill = _uiColor(s) ?? m.fill; return m }
    public func stroke<S: ShapeStyle>(_ s: S, lineWidth: CGFloat = 1) -> MapPolygon { var m = self; m.strokeColor = _uiColor(s); m.width = lineWidth; return m }
}
public struct MapCircle: MapContent, _MapPrimitive {
    let center: CLLocationCoordinate2D, radius: Double
    var fill: UIColor? = UIColor.systemBlue.withAlphaComponent(0.4), strokeColor: UIColor?, width: CGFloat = 0
    public init(center: CLLocationCoordinate2D, radius: CLLocationDistance) { self.center = center; self.radius = radius }
    public init(_ circle: MKCircle) { center = circle.coordinate; radius = circle.radius }
    var _items: [_MapItem] { [.circle(center: center, radius: radius, fill: fill, stroke: strokeColor, width: width)] }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> MapCircle { var m = self; m.fill = _uiColor(s) ?? m.fill; return m }
    public func stroke<S: ShapeStyle>(_ s: S, lineWidth: CGFloat = 1) -> MapCircle { var m = self; m.strokeColor = _uiColor(s); m.width = lineWidth; return m }
}
public struct UserAnnotation: MapContent, _MapPrimitive {
    public init(anchor: UnitPoint = .center) {}
    var _items: [_MapItem] { [.user] }
}
extension MapContent {
    public func tint(_ color: Color?) -> Self { self }
    public func annotationTitles(_ v: Visibility) -> Self { self }
    public func mapOverlayLevel(level: MKOverlayLevel) -> Self { self }
}

// legacy (iOS 14) annotation content
public struct _MapLegacyItem { let item: _MapItem }
public protocol MapAnnotationProtocol { var _legacy: _MapLegacyItem { get } }
public struct MapMarker: MapAnnotationProtocol {
    let coordinate: CLLocationCoordinate2D, tint: Color?
    public init(coordinate: CLLocationCoordinate2D, tint: Color? = nil) { self.coordinate = coordinate; self.tint = tint }
    public var _legacy: _MapLegacyItem { _MapLegacyItem(item: .marker(title: "", coordinate: coordinate, tint: tint?.uiColor, glyph: nil, image: nil, tag: nil)) }
}
public struct MapPin: MapAnnotationProtocol {
    let coordinate: CLLocationCoordinate2D, tint: Color?
    public init(coordinate: CLLocationCoordinate2D, tint: Color? = nil) { self.coordinate = coordinate; self.tint = tint }
    public var _legacy: _MapLegacyItem { _MapLegacyItem(item: .marker(title: "", coordinate: coordinate, tint: tint?.uiColor, glyph: nil, image: nil, tag: nil)) }
}
public struct MapAnnotation<Content: View>: MapAnnotationProtocol {
    let coordinate: CLLocationCoordinate2D, anchor: UnitPoint, content: Content
    public init(coordinate: CLLocationCoordinate2D, anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5), @ViewBuilder content: () -> Content) {
        self.coordinate = coordinate; anchor = UnitPoint(x: anchorPoint.x, y: anchorPoint.y); self.content = content()
    }
    public var _legacy: _MapLegacyItem { _MapLegacyItem(item: .annotation(title: "", coordinate: coordinate, anchor: anchor, view: AnyView(content), tag: nil)) }
}

// MARK: - Map

public struct Map: View {
    enum Camera { case binding(Binding<MapCameraPosition>), initial(MapCameraPosition), legacy(Binding<MKCoordinateRegion>) }
    let camera: Camera
    let items: [_MapItem]
    let bounds: MapCameraBounds?
    let modes: MapInteractionModes
    let selection: Binding<AnyHashable?>?
    var legacyUser = false

    public init(position: Binding<MapCameraPosition>, bounds: MapCameraBounds? = nil, interactionModes: MapInteractionModes = .all, scope: Namespace.ID? = nil,
                @MapContentBuilder content: () -> _MapContentList) {
        camera = .binding(position); items = content()._items; self.bounds = bounds; modes = interactionModes; selection = nil
    }
    public init(initialPosition: MapCameraPosition = .automatic, bounds: MapCameraBounds? = nil, interactionModes: MapInteractionModes = .all, scope: Namespace.ID? = nil,
                @MapContentBuilder content: () -> _MapContentList) {
        camera = .initial(initialPosition); items = content()._items; self.bounds = bounds; modes = interactionModes; selection = nil
    }
    public init<V: Hashable>(position: Binding<MapCameraPosition>, bounds: MapCameraBounds? = nil, interactionModes: MapInteractionModes = .all,
                             selection: Binding<V?>, scope: Namespace.ID? = nil, @MapContentBuilder content: () -> _MapContentList) {
        camera = .binding(position); items = content()._items; self.bounds = bounds; modes = interactionModes
        self.selection = Binding<AnyHashable?>(get: { selection.wrappedValue.map(AnyHashable.init) }, set: { selection.wrappedValue = $0?.base as? V })
    }
    public init<V: Hashable>(initialPosition: MapCameraPosition = .automatic, bounds: MapCameraBounds? = nil, interactionModes: MapInteractionModes = .all,
                             selection: Binding<V?>, scope: Namespace.ID? = nil, @MapContentBuilder content: () -> _MapContentList) {
        camera = .initial(initialPosition); items = content()._items; self.bounds = bounds; modes = interactionModes
        self.selection = Binding<AnyHashable?>(get: { selection.wrappedValue.map(AnyHashable.init) }, set: { selection.wrappedValue = $0?.base as? V })
    }
    public init(position: Binding<MapCameraPosition>, bounds: MapCameraBounds? = nil, interactionModes: MapInteractionModes = .all, scope: Namespace.ID? = nil) {
        camera = .binding(position); items = []; self.bounds = bounds; modes = interactionModes; selection = nil
    }
    public init(initialPosition: MapCameraPosition = .automatic, bounds: MapCameraBounds? = nil, interactionModes: MapInteractionModes = .all, scope: Namespace.ID? = nil) {
        camera = .initial(initialPosition); items = []; self.bounds = bounds; modes = interactionModes; selection = nil
    }
    public init(bounds: MapCameraBounds? = nil, interactionModes: MapInteractionModes = .all, scope: Namespace.ID? = nil, @MapContentBuilder content: () -> _MapContentList) {
        camera = .initial(.automatic); items = content()._items; self.bounds = bounds; modes = interactionModes; selection = nil
    }
    // iOS 14-16
    public enum LegacyUserTrackingMode: Sendable { case none, follow }
    public init(coordinateRegion: Binding<MKCoordinateRegion>, interactionModes: MapInteractionModes = .all, showsUserLocation: Bool = false,
                userTrackingMode: Binding<MapUserTrackingMode>? = nil) {
        camera = .legacy(coordinateRegion); items = showsUserLocation ? [.user] : []; bounds = nil; modes = interactionModes; selection = nil
    }
    public init<Items: RandomAccessCollection, A: MapAnnotationProtocol>(coordinateRegion: Binding<MKCoordinateRegion>, interactionModes: MapInteractionModes = .all,
                showsUserLocation: Bool = false, userTrackingMode: Binding<MapUserTrackingMode>? = nil, annotationItems: Items,
                annotationContent: @escaping (Items.Element) -> A) where Items.Element: Identifiable {
        camera = .legacy(coordinateRegion)
        items = (showsUserLocation ? [_MapItem.user] : []) + annotationItems.map { annotationContent($0)._legacy.item }
        bounds = nil; modes = interactionModes; selection = nil
    }
    public var body: some View { _MapRepresentable(map: self) }
}
public enum MapUserTrackingMode: Sendable { case none, follow }

final class _MapMarkerAnnotation: MKPointAnnotation, @unchecked Sendable {
    var tint: UIColor?, glyph: String?, image: String?, tagValue: AnyHashable?
}
final class _MapHostAnnotation: MKPointAnnotation, @unchecked Sendable {
    var view: AnyView = AnyView(EmptyView()), anchor = UnitPoint.bottom, tagValue: AnyHashable?
}
final class _MapStyledOverlay { let fill: UIColor?, stroke: UIColor?, width: CGFloat; init(_ f: UIColor?, _ s: UIColor?, _ w: CGFloat) { fill = f; stroke = s; width = w } }

/// an annotation view that shows SwiftUI content
final class _MapHostingAnnotationView: MKAnnotationView {
    var host: UIHostingController<AnyView>?
    func setContent(_ v: AnyView, anchor: UnitPoint) {
        let h = UIHostingController(rootView: v)
        host?.view.removeFromSuperview()
        host = h
        h.view.backgroundColor = .clear
        // measure: lay out in a large box and take the union of what SwiftUI placed
        h.view.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        h.view.setNeedsLayout(); h.view.layoutIfNeeded()
        var r = CGRect.null
        for s in h.view.subviews { r = r.union(s.frame) }
        let size = r.isNull ? CGSize(width: 30, height: 30) : CGSize(width: ceil(r.width), height: ceil(r.height))
        h.view.frame = CGRect(origin: .zero, size: size)
        addSubview(h.view)
        bounds = CGRect(origin: .zero, size: size)
        centerOffset = CGPoint(x: (0.5 - anchor.x) * size.width, y: (0.5 - anchor.y) * size.height)
    }
}

struct _MapRepresentable: UIViewRepresentable {
    let map: Map
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: _MapRepresentable
        var signature = ""
        var lastSerial = -1
        var applying = false
        var overlayStyles: [ObjectIdentifier: _MapStyledOverlay] = [:]
        init(_ p: _MapRepresentable) { parent = p }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let m = annotation as? _MapMarkerAnnotation {
                let v = MKMarkerAnnotationView(annotation: m, reuseIdentifier: nil)
                v.markerTintColor = m.tint
                v.glyphText = m.glyph
                if let i = m.image { v.glyphImage = UIImage(systemName: i) ?? UIImage(named: i) }
                return v
            }
            if let h = annotation as? _MapHostAnnotation {
                let v = _MapHostingAnnotationView(annotation: h, reuseIdentifier: nil)
                v.setContent(h.view, anchor: h.anchor)
                return v
            }
            return nil
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let st = overlayStyles[ObjectIdentifier(overlay)]
            let r: MKOverlayPathRenderer
            switch overlay {
            case let o as MKPolyline: r = MKPolylineRenderer(polyline: o)
            case let o as MKPolygon: r = MKPolygonRenderer(polygon: o)
            case let o as MKCircle: r = MKCircleRenderer(circle: o)
            default: return MKOverlayRenderer(overlay: overlay)
            }
            r.fillColor = st?.fill; r.strokeColor = st?.stroke; r.lineWidth = st?.width ?? 1
            return r
        }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !applying else { DispatchQueue.main.async { self.notify(mapView, final: true) }; return }
            let region = mapView.region
            switch parent.map.camera {
            case .binding(let b):
                var p = MapCameraPosition.region(region); p.positionedByUser = true
                lastSerial = p.serial
                DispatchQueue.main.async { b.wrappedValue = p }
            case .legacy(let b): DispatchQueue.main.async { b.wrappedValue = region }
            case .initial: break
            }
            notify(mapView, final: true)
        }
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) { if !applying { notify(mapView, final: false) } }
        func notify(_ m: MKMapView, final: Bool) {
            let ctx = MapCameraUpdateContext(camera: MapCamera(m.camera), region: m.region, rect: m.visibleMapRect)
            for (f, a) in envActions where final || f == .continuous { a(ctx) }
        }
        var envActions: [(MapCameraUpdateFrequency, (MapCameraUpdateContext) -> Void)] = []
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            let tag = (annotation as? _MapMarkerAnnotation)?.tagValue ?? (annotation as? _MapHostAnnotation)?.tagValue
            if let s = parent.map.selection, let tag { DispatchQueue.main.async { s.wrappedValue = tag } }
        }
        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            if let s = parent.map.selection { DispatchQueue.main.async { if s.wrappedValue != nil { s.wrappedValue = nil } } }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView(frame: .zero)
        m.delegate = context.coordinator
        m.accessibilityIdentifier = "map"
        if case .initial(let p) = map.camera { apply(p, to: m, coordinator: context.coordinator, items: map.items) }
        return m
    }
    func updateUIView(_ m: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.envActions = context.environment._mapCameraChange
        m.mapType = context.environment._mapStyle?.type ?? .standard
        m.isScrollEnabled = map.modes.contains(.pan); m.isZoomEnabled = map.modes.contains(.zoom)
        if let b = map.bounds {
            if let r = b.rect { m.cameraBoundary = MKMapCameraBoundary(mapRect: r) }
            m.cameraZoomRange = MKMapCameraZoomRange(minCenterCoordinateDistance: b.minDistance ?? 0, maxCenterCoordinateDistance: b.maxDistance ?? .greatestFiniteMagnitude)
        }
        // content
        let sig = map.items.map(\.signature).joined(separator: ";")
        if sig != c.signature {
            c.signature = sig
            m.removeAnnotations(m.annotations.filter { !($0 is MKUserLocation) })
            m.removeOverlays(m.overlays)
            c.overlayStyles = [:]
            var anns: [MKAnnotation] = [], ovs: [MKOverlay] = []
            var user = false
            for it in map.items {
                switch it {
                case .marker(let t, let co, let tint, let g, let i, let tag):
                    let a = _MapMarkerAnnotation(coordinate: co, title: t.isEmpty ? nil : t, subtitle: nil)
                    a.tint = tint; a.glyph = g; a.image = i; a.tagValue = tag
                    anns.append(a)
                case .annotation(let t, let co, let anchor, let v, let tag):
                    let a = _MapHostAnnotation(coordinate: co, title: t.isEmpty ? nil : t, subtitle: nil)
                    a.view = v; a.anchor = anchor; a.tagValue = tag
                    anns.append(a)
                case .polyline(let p, let s, let w):
                    let o = MKPolyline(); o._points = p; c.overlayStyles[ObjectIdentifier(o)] = _MapStyledOverlay(nil, s, w); ovs.append(o)
                case .polygon(let p, let f, let s, let w):
                    let o = MKPolygon(); o._points = p; c.overlayStyles[ObjectIdentifier(o)] = _MapStyledOverlay(f, s, w); ovs.append(o)
                case .circle(let ce, let r, let f, let s, let w):
                    let o = MKCircle(center: ce, radius: r); c.overlayStyles[ObjectIdentifier(o)] = _MapStyledOverlay(f, s, w); ovs.append(o)
                case .user: user = true
                }
            }
            m.addOverlays(ovs)
            m.addAnnotations(anns)
            if m.showsUserLocation != user { m.showsUserLocation = user }
        }
        // camera
        switch map.camera {
        case .binding(let b):
            let p = b.wrappedValue
            if p.serial != c.lastSerial { c.lastSerial = p.serial; if !p.positionedByUser { apply(p, to: m, coordinator: c, items: map.items) } }
        case .legacy(let b):
            let r = b.wrappedValue, cur = m.region
            if abs(r.center.latitude - cur.center.latitude) > 1e-7 || abs(r.center.longitude - cur.center.longitude) > 1e-7 || abs(r.span.latitudeDelta - cur.span.latitudeDelta) > r.span.latitudeDelta * 0.05 {
                c.applying = true; m.setRegion(r, animated: false); c.applying = false
            }
        case .initial: break
        }
        // selection
        if let s = map.selection {
            let want = s.wrappedValue
            let cur = m.selectedAnnotations.first
            let curTag = (cur as? _MapMarkerAnnotation)?.tagValue ?? (cur as? _MapHostAnnotation)?.tagValue
            if want != curTag {
                if let want, let a = m.annotations.first(where: { (($0 as? _MapMarkerAnnotation)?.tagValue ?? ($0 as? _MapHostAnnotation)?.tagValue) == want }) {
                    m.selectAnnotation(a, animated: false)
                } else if want == nil, let cur { m.deselectAnnotation(cur, animated: false) }
            }
        }
    }
    func apply(_ p: MapCameraPosition, to m: MKMapView, coordinator c: Coordinator, items: [_MapItem]) {
        c.applying = true
        defer { c.applying = false }
        switch p.kind {
        case .region(let r): m.setRegion(r, animated: false)
        case .rect(let r): m.setVisibleMapRect(r, animated: false)
        case .camera(let cam): m.setCamera(MKMapCamera(lookingAtCenter: cam.centerCoordinate, fromDistance: cam.distance, pitch: CGFloat(cam.pitch), heading: cam.heading), animated: false)
        case .item(let i): m.setRegion(MKCoordinateRegion(center: i.placemark.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500), animated: false)
        case .user(let fb):
            m.showsUserLocation = true
            m.userTrackingMode = .follow
            if m.userLocation.location == nil, let fb { apply(fb, to: m, coordinator: c, items: items) }
        case .automatic:
            // frame the content, like SwiftUI's automatic position
            var r = MKMapRect.null
            for it in items {
                switch it {
                case .marker(_, let co, _, _, _, _), .annotation(_, let co, _, _, _): let q = MKMapPoint(co); r = r.union(MKMapRect(x: q.x, y: q.y, width: 0, height: 0))
                case .polyline(let pts, _, _), .polygon(let pts, _, _, _): for q in pts { r = r.union(MKMapRect(x: q.x, y: q.y, width: 0, height: 0)) }
                case .circle(let ce, let rad, _, _, _): r = r.union(MKCircle(center: ce, radius: rad).boundingMapRect)
                case .user: break
                }
            }
            if !r.isNull {
                let minSize = 1500 * MKMapPointsPerMeterAtLatitude(MKMapPoint(x: r.midX, y: r.midY).coordinate.latitude)
                if r.width < minSize { r = r.insetBy(dx: -(minSize - r.width) / 2, dy: 0) }
                if r.height < minSize { r = r.insetBy(dx: 0, dy: -(minSize - r.height) / 2) }
                m.setVisibleMapRect(r, edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40), animated: false)
            }
        }
    }
}
