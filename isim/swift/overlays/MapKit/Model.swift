// isim MapKit: annotations, shapes, overlays, placemarks and map items.
import Foundation
import UIKit
import Contacts
@_spi(isim) import CoreLocation

/// An annotation (isim: a Swift protocol — Core Location's coordinate type is a Swift struct here — with
/// `title`/`subtitle` defaulting to nil instead of optional Objective-C requirements).
public protocol MKAnnotation: NSObjectProtocol {
    var coordinate: CLLocationCoordinate2D { get }
    var title: String? { get }
    var subtitle: String? { get }
}
extension MKAnnotation {
    public var title: String? { nil }
    public var subtitle: String? { nil }
}

public protocol MKOverlay: MKAnnotation {
    var boundingMapRect: MKMapRect { get }
    func intersects(_ mapRect: MKMapRect) -> Bool
    var canReplaceMapContent: Bool { get }
}
extension MKOverlay {
    public func intersects(_ mapRect: MKMapRect) -> Bool { boundingMapRect.intersects(mapRect) }
    public var canReplaceMapContent: Bool { false }
}

open class MKShape: NSObject, MKAnnotation, @unchecked Sendable {
    @objc open var title: String?
    @objc open var subtitle: String?
    open var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D() }
    public override init() { super.init() }
}

open class MKPointAnnotation: MKShape, @unchecked Sendable {
    var _coordinate = CLLocationCoordinate2D()
    open override var coordinate: CLLocationCoordinate2D {
        get { _coordinate }
        set { willChangeValue(forKey: "coordinate"); _coordinate = newValue; didChangeValue(forKey: "coordinate") }
    }
    public override init() { super.init() }
    public init(coordinate: CLLocationCoordinate2D) { super.init(); _coordinate = coordinate }
    public convenience init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.init(coordinate: coordinate); self.title = title; self.subtitle = subtitle
    }
}

/// The user's location as an annotation (MKMapView.userLocation).
open class MKUserLocation: NSObject, MKAnnotation, @unchecked Sendable {
    @objc dynamic open internal(set) var location: CLLocation?
    open internal(set) var heading: CLHeading?
    open var isUpdating: Bool { location != nil }
    @objc open var title: String? = "My Location"
    @objc open var subtitle: String?
    open var coordinate: CLLocationCoordinate2D { location?.coordinate ?? kCLLocationCoordinate2DInvalid }
}

// MARK: - multi-points

open class MKMultiPoint: MKShape, @unchecked Sendable {
    var _points: [MKMapPoint] = []
    open var pointCount: Int { _points.count }
    open func points() -> UnsafeMutablePointer<MKMapPoint> {
        let p = UnsafeMutablePointer<MKMapPoint>.allocate(capacity: max(1, _points.count))
        p.initialize(from: _points, count: _points.count)
        return p
    }
    open func getCoordinates(_ coords: UnsafeMutablePointer<CLLocationCoordinate2D>, range: NSRange) {
        for i in 0..<range.length where range.location + i < _points.count { coords[i] = _points[range.location + i].coordinate }
    }
    open var coordinates: [CLLocationCoordinate2D] { _points.map(\.coordinate) }
    open func location(atPointIndex index: Int) -> CGFloat { 0 }
    open var boundingMapRect: MKMapRect {
        guard let f = _points.first else { return .null }
        var x0 = f.x, y0 = f.y, x1 = f.x, y1 = f.y
        for p in _points { x0 = min(x0, p.x); y0 = min(y0, p.y); x1 = max(x1, p.x); y1 = max(y1, p.y) }
        return MKMapRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
    open override var coordinate: CLLocationCoordinate2D {
        let r = boundingMapRect
        return r.isNull ? CLLocationCoordinate2D() : MKMapPoint(x: r.midX, y: r.midY).coordinate
    }
    open func intersects(_ mapRect: MKMapRect) -> Bool { boundingMapRect.intersects(mapRect) }
}

open class MKPolyline: MKMultiPoint, MKOverlay, @unchecked Sendable {
    public override init() { super.init() }
    public convenience init(points: UnsafePointer<MKMapPoint>, count: Int) {
        self.init(); _points = Array(UnsafeBufferPointer(start: points, count: count))
    }
    public convenience init(coordinates: UnsafePointer<CLLocationCoordinate2D>, count: Int) {
        self.init(); _points = UnsafeBufferPointer(start: coordinates, count: count).map(MKMapPoint.init)
    }
    public convenience init(coordinates: [CLLocationCoordinate2D], count: Int) { self.init(); _points = coordinates.prefix(count).map(MKMapPoint.init) }
    public convenience init(coordinates: [CLLocationCoordinate2D]) { self.init(); _points = coordinates.map(MKMapPoint.init) }
    open override var boundingMapRect: MKMapRect { super.boundingMapRect }
}

/// A polyline that follows great circles (the points between the given coordinates are interpolated).
open class MKGeodesicPolyline: MKPolyline, @unchecked Sendable {
    public convenience init(coordinates: UnsafePointer<CLLocationCoordinate2D>, count: Int) {
        self.init(); _points = MKGeodesicPolyline._geodesic(Array(UnsafeBufferPointer(start: coordinates, count: count))).map(MKMapPoint.init)
    }
    public convenience init(coordinates: [CLLocationCoordinate2D]) { self.init(); _points = MKGeodesicPolyline._geodesic(coordinates).map(MKMapPoint.init) }
    static func _geodesic(_ c: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard c.count > 1 else { return c }
        var out: [CLLocationCoordinate2D] = [c[0]]
        for i in 1..<c.count {
            let a = c[i - 1], b = c[i]
            let p1 = a.latitude * .pi / 180, l1 = a.longitude * .pi / 180, p2 = b.latitude * .pi / 180, l2 = b.longitude * .pi / 180
            let d = _MKGeo.distance(a, b) / 6_371_008.8
            let n = max(1, Int(d * 180 / .pi))
            for k in 1...n {
                let f = Double(k) / Double(n)
                if d < 1e-9 { out.append(b); continue }
                let A = sin((1 - f) * d) / sin(d), B = sin(f * d) / sin(d)
                let x = A * cos(p1) * cos(l1) + B * cos(p2) * cos(l2), y = A * cos(p1) * sin(l1) + B * cos(p2) * sin(l2), z = A * sin(p1) + B * sin(p2)
                out.append(CLLocationCoordinate2D(latitude: atan2(z, sqrt(x * x + y * y)) * 180 / .pi, longitude: atan2(y, x) * 180 / .pi))
            }
        }
        return out
    }
}

open class MKPolygon: MKMultiPoint, MKOverlay, @unchecked Sendable {
    open private(set) var interiorPolygons: [MKPolygon]?
    public override init() { super.init() }
    public convenience init(points: UnsafePointer<MKMapPoint>, count: Int) { self.init(); _points = Array(UnsafeBufferPointer(start: points, count: count)) }
    public convenience init(points: UnsafePointer<MKMapPoint>, count: Int, interiorPolygons: [MKPolygon]?) {
        self.init(points: points, count: count); self.interiorPolygons = interiorPolygons
    }
    public convenience init(coordinates: UnsafePointer<CLLocationCoordinate2D>, count: Int) {
        self.init(); _points = UnsafeBufferPointer(start: coordinates, count: count).map(MKMapPoint.init)
    }
    public convenience init(coordinates: UnsafePointer<CLLocationCoordinate2D>, count: Int, interiorPolygons: [MKPolygon]?) {
        self.init(coordinates: coordinates, count: count); self.interiorPolygons = interiorPolygons
    }
    public convenience init(coordinates: [CLLocationCoordinate2D], count: Int) { self.init(); _points = coordinates.prefix(count).map(MKMapPoint.init) }
    public convenience init(coordinates: [CLLocationCoordinate2D], interiorPolygons: [MKPolygon]? = nil) {
        self.init(); _points = coordinates.map(MKMapPoint.init); self.interiorPolygons = interiorPolygons
    }
    open override var boundingMapRect: MKMapRect { super.boundingMapRect }
}

open class MKCircle: MKShape, MKOverlay, @unchecked Sendable {
    let _center: CLLocationCoordinate2D
    public let radius: CLLocationDistance
    public init(center coord: CLLocationCoordinate2D, radius: CLLocationDistance) { _center = coord; self.radius = radius; super.init() }
    public convenience init(mapRect: MKMapRect) {
        let c = MKMapPoint(x: mapRect.midX, y: mapRect.midY).coordinate
        self.init(center: c, radius: max(mapRect.width, mapRect.height) / 2 / MKMapPointsPerMeterAtLatitude(c.latitude))
    }
    open override var coordinate: CLLocationCoordinate2D { _center }
    open var boundingMapRect: MKMapRect {
        let r = radius * MKMapPointsPerMeterAtLatitude(_center.latitude), p = MKMapPoint(_center)
        return MKMapRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
    }
    open func intersects(_ mapRect: MKMapRect) -> Bool { boundingMapRect.intersects(mapRect) }
}

open class MKMultiPolyline: MKShape, MKOverlay, @unchecked Sendable {
    public let polylines: [MKPolyline]
    public init(_ polylines: [MKPolyline]) { self.polylines = polylines; super.init() }
    open var boundingMapRect: MKMapRect { polylines.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) } }
    open override var coordinate: CLLocationCoordinate2D { let r = boundingMapRect; return MKMapPoint(x: r.midX, y: r.midY).coordinate }
}
open class MKMultiPolygon: MKShape, MKOverlay, @unchecked Sendable {
    public let polygons: [MKPolygon]
    public init(_ polygons: [MKPolygon]) { self.polygons = polygons; super.init() }
    open var boundingMapRect: MKMapRect { polygons.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) } }
    open override var coordinate: CLLocationCoordinate2D { let r = boundingMapRect; return MKMapPoint(x: r.midX, y: r.midY).coordinate }
}

// MARK: - tile overlays

public struct MKTileOverlayPath: Sendable {
    public var x: Int, y: Int, z: Int
    public var contentScaleFactor: CGFloat
    public init() { x = 0; y = 0; z = 0; contentScaleFactor = 1 }
    public init(x: Int, y: Int, z: Int, contentScaleFactor: CGFloat) { self.x = x; self.y = y; self.z = z; self.contentScaleFactor = contentScaleFactor }
}

/// Raster tiles from a URL template ({x} {y} {z} {scale}). file: URLs load from disk; other URLs through URLSession
/// (isim never fetches tiles by itself — only when an app's overlay asks for them).
open class MKTileOverlay: NSObject, MKOverlay, @unchecked Sendable {
    public let urlTemplate: String?
    open var tileSize = CGSize(width: 256, height: 256)
    open var isGeometryFlipped = false
    open var minimumZ = 0
    open var maximumZ = 21
    open var canReplaceMapContent = false
    open var boundingMapRect: MKMapRect { .world }
    open var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D() }
    public init(urlTemplate URLTemplate: String?) { urlTemplate = URLTemplate; super.init() }
    open func url(forTilePath path: MKTileOverlayPath) -> URL {
        let y = isGeometryFlipped ? (1 << path.z) - 1 - path.y : path.y
        let s = (urlTemplate ?? "").replacingOccurrences(of: "{x}", with: "\(path.x)").replacingOccurrences(of: "{y}", with: "\(y)")
            .replacingOccurrences(of: "{z}", with: "\(path.z)").replacingOccurrences(of: "{scale}", with: "\(Int(path.contentScaleFactor))")
        return URL(string: s) ?? URL(fileURLWithPath: s)
    }
    open func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let u = url(forTilePath: path)
        if u.isFileURL { result(try? Data(contentsOf: u), nil); return }
        URLSession.shared.dataTask(with: u) { d, _, e in DispatchQueue.main.async { result(d, e) } }.resume()
    }
    open func loadTile(at path: MKTileOverlayPath) async throws -> Data {
        try await withCheckedThrowingContinuation { c in loadTile(at: path) { d, e in if let d { c.resume(returning: d) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
}

// MARK: - placemarks & map items

open class MKPlacemark: CLPlacemark, MKAnnotation, @unchecked Sendable {
    public init(coordinate: CLLocationCoordinate2D) {
        _coord = coordinate
        super.init(_isimName: nil, location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
    public init(coordinate: CLLocationCoordinate2D, addressDictionary: [String: Any]?) {
        _coord = coordinate
        let a = addressDictionary ?? [:]
        super.init(_isimName: nil, location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                   thoroughfare: a["Street"] as? String, locality: a["City"] as? String, administrativeArea: a["State"] as? String,
                   postalCode: a["ZIP"] as? String, country: a["Country"] as? String, isoCountryCode: a["CountryCode"] as? String)
    }
    public override init(placemark: CLPlacemark) {
        _coord = placemark.location?.coordinate ?? CLLocationCoordinate2D()
        super.init(placemark: placemark)
    }
    public convenience init(coordinate: CLLocationCoordinate2D, postalAddress: CNPostalAddress) {
        self.init(coordinate: coordinate, addressDictionary: ["Street": postalAddress.street, "City": postalAddress.city, "State": postalAddress.state,
                                                              "ZIP": postalAddress.postalCode, "Country": postalAddress.country])
    }
    let _coord: CLLocationCoordinate2D
    open var coordinate: CLLocationCoordinate2D { _coord }
    @objc open var title: String? {
        if let n = name { return n }
        let street = [subThoroughfare, thoroughfare].compactMap { $0 }.joined(separator: " ")
        return [street.nilIfEmpty, locality].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
    }
    @objc open var subtitle: String? { [locality, administrativeArea, country].compactMap { $0 }.joined(separator: ", ").nilIfEmpty }
    open var countryCode: String? { isoCountryCode }
}
extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

public struct MKPointOfInterestCategory: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ r: String) { rawValue = r }
    public static let airport = Self("MKPOICategoryAirport"), amusementPark = Self("MKPOICategoryAmusementPark"), bakery = Self("MKPOICategoryBakery")
    public static let beach = Self("MKPOICategoryBeach"), cafe = Self("MKPOICategoryCafe"), hotel = Self("MKPOICategoryHotel"), landmark = Self("MKPOICategoryLandmark")
    public static let museum = Self("MKPOICategoryMuseum"), park = Self("MKPOICategoryPark"), parking = Self("MKPOICategoryParking"), publicTransport = Self("MKPOICategoryPublicTransport")
    public static let restaurant = Self("MKPOICategoryRestaurant"), store = Self("MKPOICategoryStore"), university = Self("MKPOICategoryUniversity")
}
public struct MKPointOfInterestFilter: Sendable {
    let include: Set<MKPointOfInterestCategory>?, exclude: Set<MKPointOfInterestCategory>?
    public init(including categories: [MKPointOfInterestCategory]) { include = Set(categories); exclude = nil }
    public init(excluding categories: [MKPointOfInterestCategory]) { include = nil; exclude = Set(categories) }
    public static let includingAll = MKPointOfInterestFilter(excluding: [])
    public static let excludingAll = MKPointOfInterestFilter(including: [])
    public func includes(_ c: MKPointOfInterestCategory) -> Bool { include.map { $0.contains(c) } ?? !(exclude?.contains(c) ?? false) }
    public func excludes(_ c: MKPointOfInterestCategory) -> Bool { !includes(c) }
}

open class MKMapItem: NSObject, @unchecked Sendable {
    open private(set) var placemark: MKPlacemark
    open var isCurrentLocation = false
    open var name: String?
    open var phoneNumber: String?
    open var url: URL?
    open var timeZone: TimeZone?
    open var pointOfInterestCategory: MKPointOfInterestCategory?
    open var identifier: Identifier? { nil }
    public struct Identifier: Hashable, Sendable { public let rawValue: String; public init?(rawValue: String) { self.rawValue = rawValue } }
    public init(placemark: MKPlacemark) { self.placemark = placemark; name = placemark.name; timeZone = placemark.timeZone; super.init() }
    public convenience override init() { self.init(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D())) }
    open class func forCurrentLocation() -> MKMapItem {
        let c = _MKUserLocationSource.current() ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902)
        let m = MKMapItem(placemark: MKPlacemark(coordinate: c)); m.isCurrentLocation = true; m.name = "My Location"
        return m
    }
    public static let launchOptionsDirectionsModeKey = "MKLaunchOptionsDirectionsMode"
    public static let launchOptionsMapTypeKey = "MKLaunchOptionsMapType"
    public static let launchOptionsMapCenterKey = "MKLaunchOptionsMapCenter"
    public static let launchOptionsMapSpanKey = "MKLaunchOptionsMapSpan"
    public static let launchOptionsShowsTrafficKey = "MKLaunchOptionsShowsTraffic"
    /// isim has no Maps app: logged, not opened
    @discardableResult open func openInMaps(launchOptions: [String: Any]? = nil) -> Bool {
        print("isim: MKMapItem.openInMaps: \(name ?? "item") at \(String(format: "%.5f,%.5f", placemark.coordinate.latitude, placemark.coordinate.longitude)) (isim has no Maps app)")
        return false
    }
    open func openInMaps(launchOptions: [String: Any]? = nil, from scene: UIScene?, completionHandler: ((Bool) -> Void)? = nil) {
        let ok = openInMaps(launchOptions: launchOptions)
        DispatchQueue.main.async { completionHandler?(ok) }
    }
    open class func openMaps(with mapItems: [MKMapItem], launchOptions: [String: Any]? = nil) -> Bool {
        for m in mapItems { _ = m.openInMaps(launchOptions: launchOptions) }
        return false
    }
}
public let MKLaunchOptionsDirectionsModeDriving = "MKLaunchOptionsDirectionsModeDriving"
public let MKLaunchOptionsDirectionsModeWalking = "MKLaunchOptionsDirectionsModeWalking"
public let MKLaunchOptionsDirectionsModeTransit = "MKLaunchOptionsDirectionsModeTransit"
public let MKLaunchOptionsDirectionsModeDefault = "MKLaunchOptionsDirectionsModeDefault"

/// where the user is (the simulated Core Location position), for MKMapItem.forCurrentLocation
enum _MKUserLocationSource {
    nonisolated(unsafe) static var last: CLLocationCoordinate2D?
    static func current() -> CLLocationCoordinate2D? { last }
}
