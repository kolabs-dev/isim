// isim MapKit: map features (adapted). isim's basemap has no POI data service; its own labels are the map's features:
// the landmarks are points of interest and the cities territories (it draws no physical features). A tap on a label of
// a kind the map's selectableMapFeatures allows selects an MKMapFeatureAnnotation for it, like a tap on a POI in Maps.
import UIKit

public struct MKMapFeatureOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let pointsOfInterest = MKMapFeatureOptions(rawValue: 1 << MKMapFeatureAnnotation.FeatureType.pointOfInterest.rawValue)
    public static let territories = MKMapFeatureOptions(rawValue: 1 << MKMapFeatureAnnotation.FeatureType.territory.rawValue)
    public static let physicalFeatures = MKMapFeatureOptions(rawValue: 1 << MKMapFeatureAnnotation.FeatureType.physicalFeature.rawValue)
}

/// the icon Maps shows for a feature
@objc(MKIconStyle) open class MKIconStyle: NSObject, @unchecked Sendable {
    @objc open private(set) var backgroundColor: UIColor
    @objc open private(set) var image: UIImage
    init(backgroundColor: UIColor, image: UIImage) { self.backgroundColor = backgroundColor; self.image = image }
}

/// a map feature the person selected
@objc(MKMapFeatureAnnotation) open class MKMapFeatureAnnotation: NSObject, MKAnnotation, @unchecked Sendable {
    @objc(MKMapFeatureType) public enum FeatureType: Int, Sendable { case pointOfInterest = 0, territory, physicalFeature }
    open private(set) var featureType: MKMapFeatureAnnotation.FeatureType
    open private(set) var pointOfInterestCategory: MKPointOfInterestCategory?
    @objc open private(set) var iconStyle: MKIconStyle?
    public let coordinate: CLLocationCoordinate2D
    @objc open private(set) var title: String?
    @objc open private(set) var subtitle: String?
    init(_ place: _MKPlace) {
        let poi = place.rank == 4
        featureType = poi ? .pointOfInterest : .territory
        pointOfInterestCategory = poi ? .landmark : nil
        iconStyle = poi ? MKIconStyle(backgroundColor: .systemRed, image: UIImage(systemName: "star.fill") ?? UIImage()) : nil
        coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        title = place.name
        subtitle = nil
    }
}

/// resolves a map feature to a map item (from the offline gazetteer, else the feature's name and coordinate)
@objc(MKMapItemRequest) open class MKMapItemRequest: NSObject, @unchecked Sendable {
    open private(set) var featureAnnotation: MKMapFeatureAnnotation
    @objc open private(set) var isCancelled = false
    @objc open private(set) var isLoading = false
    public init(mapFeatureAnnotation: MKMapFeatureAnnotation) { featureAnnotation = mapFeatureAnnotation }
    /// iOS 18: the annotation (nil for a request made from an identifier or a place descriptor; isim makes none)
    open var mapFeatureAnnotation: MKMapFeatureAnnotation? { featureAnnotation }
    @objc open func cancel() { isCancelled = true }
    open func getMapItem(completionHandler: @escaping (MKMapItem?, Error?) -> Void) {
        let f = featureAnnotation
        isLoading = true
        CLGeocoder().geocodeAddressString(f.title ?? "") { places, _ in
            self.isLoading = false
            if self.isCancelled { completionHandler(nil, MKError(.unknown)); return }
            let near = places?.first { p in p.location.map { $0.distance(from: CLLocation(latitude: f.coordinate.latitude, longitude: f.coordinate.longitude)) < 5_000 } ?? false }
            let item = near.map { MKMapItem(placemark: MKPlacemark(placemark: $0)) } ?? MKMapItem(placemark: MKPlacemark(coordinate: f.coordinate))
            item.name = f.title
            item.pointOfInterestCategory = f.pointOfInterestCategory
            completionHandler(item, nil)
        }
    }
    open var mapItem: MKMapItem {
        get async throws {
            try await withCheckedThrowingContinuation { c in
                getMapItem { item, e in if let item { c.resume(returning: item) } else { c.resume(throwing: e ?? MKError(.unknown)) } }
            }
        }
    }
}

/// a toolbar button that cycles the map's user tracking mode: none, follow, follow with heading
@MainActor
@objc(MKUserTrackingBarButtonItem) open class MKUserTrackingBarButtonItem: UIBarButtonItem {
    open weak var mapView: MKMapView? { didSet { _button.map = mapView; _button.setNeedsDisplay() } }
    let _button = _MKTrackingBarButton()
    public init(mapView: MKMapView?) {
        super.init()
        self.mapView = mapView
        _button.map = mapView
        _button.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
        _button.accessibilityIdentifier = "user-tracking-bar-button"
        customView = _button
    }
}
final class _MKTrackingBarButton: UIView {
    weak var map: MKMapView?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    @objc func tapped() {
        guard let m = map else { return }
        let next: MKUserTrackingMode = m.userTrackingMode == .none ? .follow : m.userTrackingMode == .follow ? .followWithHeading : .none
        if next != .none && !m.showsUserLocation { m.showsUserLocation = true }
        m.setUserTrackingMode(next, animated: true)
        setNeedsDisplay()
    }
    var _mode: MKUserTrackingMode { map?.userTrackingMode ?? .none }
    @objc func _isim_dumpText() -> String {
        switch _mode {
        case .none: return "tracking none"
        case .follow: return "tracking follow"
        default: return "tracking follow with heading"
        }
    }
    override func draw(_ rect: CGRect) {
        // location (outline), location.fill (follow), location.north.line.fill (with heading)
        let name = _mode == .none ? "location" : _mode == .follow ? "location.fill" : "location.north.line.fill"
        guard let img = UIImage(systemName: name)?.withTintColor(tintColor ?? .systemBlue, renderingMode: .alwaysOriginal) else { return }
        let s = CGSize(width: 22, height: 22)
        img.draw(in: CGRect(x: bounds.midX - s.width / 2, y: bounds.midY - s.height / 2, width: s.width, height: s.height))
    }
}

// MARK: - Objective-C entry points
extension MKMapFeatureAnnotation {
    @objc(featureType) var _objc_featureType: MKMapFeatureAnnotation.FeatureType { featureType }
    @objc(pointOfInterestCategory) var _objc_poi: String? { pointOfInterestCategory?.rawValue }
}
extension MKMapItemRequest {
    @objc(initWithMapFeatureAnnotation:) convenience init(_objcFeature f: MKMapFeatureAnnotation) { self.init(mapFeatureAnnotation: f) }
    @objc(featureAnnotation) var _objc_featureAnnotation: MKMapFeatureAnnotation { featureAnnotation }
    @objc(getMapItemWithCompletionHandler:) func _objc_getMapItem(_ done: @escaping (MKMapItem?, NSError?) -> Void) {
        getMapItem { i, e in done(i, e.map { $0 as NSError }) }
    }
}
extension MKUserTrackingBarButtonItem {
    @objc(initWithMapView:) convenience init(_objcMapView m: MKMapView?) { self.init(mapView: m) }
    @objc(mapView) var _objc_mapView: MKMapView? { get { mapView } set { mapView = newValue } }
}
extension MKMapView {
    @objc(selectableMapFeatures) var _objc_selectableMapFeatures: UInt {
        get { UInt(selectableMapFeatures.rawValue) }
        set { selectableMapFeatures = MKMapFeatureOptions(rawValue: Int(newValue)) }
    }
}

/// where Look Around shows its badge
@objc public enum MKLookAroundBadgePosition: Int, Sendable { case topLeading = 0, topTrailing, bottomTrailing }
