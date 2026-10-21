// isim MapKit for SwiftUI: map features (the basemap's labels: landmarks and cities), feature selection, MapSelection
// (iOS 18), MapReader / MapProxy and LookAroundPreview (adapted, like the UIKit map view they use).
import SwiftUI

/// a feature on the map the person can select (Map(selection: Binding<MapFeature?>))
public struct MapFeature: Hashable, @unchecked Sendable {
    public enum FeatureKind: Hashable, Sendable { case pointOfInterest, territory, physicalFeature }
    public let kind: FeatureKind
    public let title: String?
    public let coordinate: CLLocationCoordinate2D
    public let pointOfInterestCategory: MKPointOfInterestCategory?
    public let backgroundColor: Color?
    public let image: Image?
    let _annotation: MKMapFeatureAnnotation
    init(_ a: MKMapFeatureAnnotation) {
        _annotation = a
        kind = a.featureType == .pointOfInterest ? .pointOfInterest : a.featureType == .territory ? .territory : .physicalFeature
        title = a.title; coordinate = a.coordinate; pointOfInterestCategory = a.pointOfInterestCategory
        backgroundColor = a.iconStyle.map { Color($0.backgroundColor) }
        image = a.iconStyle.map { Image(uiImage: $0.image) }
    }
    public static func == (a: MapFeature, b: MapFeature) -> Bool {
        a.kind == b.kind && a.title == b.title && a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
    }
    public func hash(into h: inout Hasher) { h.combine(title); h.combine(coordinate.latitude); h.combine(coordinate.longitude) }
}

/// a selection that is either one of the app's tagged map items or a map feature (iOS 18)
@available(iOS 18.0, *)
public struct MapSelection<Value: Hashable>: Hashable {
    public let value: Value?
    public let feature: MapFeature?
    public init(_ value: Value) { self.value = value; feature = nil }
    public init(_ feature: MapFeature) { value = nil; self.feature = feature }
}

extension MKMapItemRequest {
    /// requests the map item of a feature selected in a SwiftUI Map
    public convenience init(feature: MapFeature) { self.init(mapFeatureAnnotation: feature._annotation) }
    public var feature: MapFeature { MapFeature(featureAnnotation) }
    public var mapFeature: MapFeature? { mapFeatureAnnotation.map(MapFeature.init) }
}

// MARK: - environment
struct _MapFeatureEnv {
    var disabled: ((MapFeature) -> Bool)?
    var content: ((MapFeature) -> [_MapItem])?
}
struct _MapFeatureKey: EnvironmentKey { static let defaultValue = _MapFeatureEnv() }
/// MapReader's proxy: the map view inside it registers here
final class _MapProxyBox { weak var map: MKMapView? }
struct _MapProxyKey: EnvironmentKey { static let defaultValue: _MapProxyBox? = nil }
extension EnvironmentValues {
    var _mapFeature: _MapFeatureEnv { get { self[_MapFeatureKey.self] } set { self[_MapFeatureKey.self] = newValue } }
    var _mapProxy: _MapProxyBox? { get { self[_MapProxyKey.self] } set { self[_MapProxyKey.self] = newValue } }
}
extension View {
    /// features the predicate returns true for cannot be selected
    public func mapFeatureSelectionDisabled(_ isDisabled: @escaping (MapFeature) -> Bool) -> some View {
        transformEnvironment(\._mapFeature) { $0.disabled = isDisabled }
    }
    /// the map content (a Marker or an Annotation) the map shows for a selected feature, instead of the default marker
    public func mapFeatureSelectionContent(@MapContentBuilder content: @escaping (MapFeature) -> _MapContentList) -> some View {
        transformEnvironment(\._mapFeature) { $0.content = { content($0)._items } }
    }
}

// MARK: - MapReader
/// converts between the map's points and coordinates, for the Map inside a MapReader
public struct MapProxy {
    let box: _MapProxyBox
    @MainActor func point(_ p: CGPoint, _ space: CoordinateSpace, in m: MKMapView) -> CGPoint {
        if case .global = space { return m.convert(p, from: nil) }
        return p
    }
    @MainActor public func convert(_ point: CGPoint, from coordinateSpace: some CoordinateSpaceProtocol) -> CLLocationCoordinate2D? {
        guard let m = box.map else { return nil }
        return m.convert(self.point(point, coordinateSpace.coordinateSpace, in: m), toCoordinateFrom: m)
    }
    @MainActor public func convert(_ coordinate: CLLocationCoordinate2D, to coordinateSpace: some CoordinateSpaceProtocol) -> CGPoint? {
        guard let m = box.map else { return nil }
        let p = m.convert(coordinate, toPointTo: m)
        if case .global = coordinateSpace.coordinateSpace { return m.convert(p, to: nil) }
        return p
    }
    /// the camera that frames a region (or a rect, an item) in the map's current size
    @MainActor public func camera(framing region: MKCoordinateRegion) -> MapCamera {
        let probe = MKMapView(frame: box.map?.bounds ?? UIScreen.main.bounds)
        probe.setRegion(region, animated: false)
        return MapCamera(probe.camera)
    }
    @MainActor public func camera(framing rect: MKMapRect) -> MapCamera { camera(framing: MKCoordinateRegion(rect)) }
    @MainActor public func camera(framing item: MKMapItem, allowPitch: Bool = false) -> MapCamera {
        camera(framing: MKCoordinateRegion(center: item.placemark.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
    }
}
public struct MapReader<Content: View>: View {
    let content: (MapProxy) -> Content
    @State private var box = _MapProxyBox()
    public init(@ViewBuilder content: @escaping (MapProxy) -> Content) { self.content = content }
    public var body: some View { content(MapProxy(box: box)).environment(\._mapProxy, box) }
}

// MARK: - LookAroundPreview
/// shows a Look Around scene (the same viewer as MKLookAroundViewController); none: "Look Around isn't available"
public struct LookAroundPreview: View {
    let scene: Binding<MKLookAroundScene?>?
    let initial: MKLookAroundScene?
    let allowsNavigation: Bool
    public init(initialScene: MKLookAroundScene?, allowsNavigation: Bool = true, showsRoadLabels: Bool = true,
                pointsOfInterest: PointOfInterestCategories = .all, badgePosition: MKLookAroundBadgePosition = .topLeading) {
        scene = nil; initial = initialScene; self.allowsNavigation = allowsNavigation
    }
    public init(scene: Binding<MKLookAroundScene?>, allowsNavigation: Bool = true, showsRoadLabels: Bool = true,
                pointsOfInterest: PointOfInterestCategories = .all, badgePosition: MKLookAroundBadgePosition = .topLeading) {
        self.scene = scene; initial = nil; self.allowsNavigation = allowsNavigation
    }
    public var body: some View {
        if let s = scene?.wrappedValue ?? initial {
            _LookAroundRepresentable(scene: s, allowsNavigation: allowsNavigation)
        } else {
            Text("Look Around isn't available").foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
        }
    }
}
struct _LookAroundRepresentable: UIViewControllerRepresentable {
    let scene: MKLookAroundScene
    let allowsNavigation: Bool
    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let vc = MKLookAroundViewController(scene: scene)
        vc.isNavigationEnabled = allowsNavigation
        return vc
    }
    func updateUIViewController(_ vc: MKLookAroundViewController, context: Context) {
        if vc.scene !== scene { vc.scene = scene }
        vc.isNavigationEnabled = allowsNavigation
    }
}
