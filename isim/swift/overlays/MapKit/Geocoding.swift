// isim MapKit: geocoding requests (iOS 26), addresses, the distance formatter, the GeoJSON decoder and the launch option
// keys (adapted). Geocoding answers from Core Location's offline gazetteer, the same places CLGeocoder and MKLocalSearch
// know; anything else is MKError.placemarkNotFound (ISIM_GEOCODER=offline: MKError.serverFailure).
import UIKit

// MARK: - launch options (MKMapItem.openInMaps)
public let MKLaunchOptionsDirectionsModeKey = "MKLaunchOptionsDirectionsMode"
public let MKLaunchOptionsMapTypeKey = "MKLaunchOptionsMapType"
public let MKLaunchOptionsMapCenterKey = "MKLaunchOptionsMapCenter"
public let MKLaunchOptionsMapSpanKey = "MKLaunchOptionsMapSpan"
public let MKLaunchOptionsShowsTrafficKey = "MKLaunchOptionsShowsTraffic"
public let MKLaunchOptionsCameraKey = "MKLaunchOptionsCamera"
public let MKLaunchOptionsDirectionsModeCycling = "MKLaunchOptionsDirectionsModeCycling"

// MARK: - addresses
/// a postal address as text
@objc(MKAddress) open class MKAddress: NSObject, @unchecked Sendable {
    @objc public let fullAddress: String
    @objc public let shortAddress: String?
    public init?(fullAddress: String, shortAddress: String?) {
        guard !fullAddress.isEmpty else { return nil }
        self.fullAddress = fullAddress; self.shortAddress = shortAddress
    }
    init(_ p: CLPlacemark) {
        let r = MKAddressRepresentations(p)
        fullAddress = r.fullAddress(includingRegion: true, singleLine: true) ?? ""
        shortAddress = r._lines(region: false).prefix(2).joined(separator: ", ")
    }
    open override var description: String { fullAddress }
}

/// an address in the forms an app shows it in
@objc(MKAddressRepresentations) open class MKAddressRepresentations: NSObject, @unchecked Sendable {
    public enum ContextStyle: Int, Sendable { case automatic = 0, short, full }
    let place: CLPlacemark
    init(_ p: CLPlacemark) { place = p }
    func _lines(region: Bool) -> [String] {
        let street = [place.subThoroughfare, place.thoroughfare].compactMap { $0 }.joined(separator: " ")
        let cityLine = [place.locality, [place.administrativeArea, place.postalCode].compactMap { $0 }.joined(separator: " ")]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return [street, cityLine, region ? (place.country ?? "") : ""].filter { !$0.isEmpty }
    }
    open func fullAddress(includingRegion: Bool, singleLine: Bool) -> String? {
        let l = _lines(region: includingRegion)
        return l.isEmpty ? nil : l.joined(separator: singleLine ? ", " : "\n")
    }
    @objc open var cityName: String? { place.locality }
    /// the city with its state (in the United States) or its country
    @objc open var cityWithContext: String? { cityWithContext(.automatic) }
    open func cityWithContext(_ style: ContextStyle) -> String? {
        guard let city = place.locality else { return nil }
        let context = style == .full ? (place.country ?? place.administrativeArea)
            : place.isoCountryCode == "US" ? place.administrativeArea : (style == .short ? place.isoCountryCode : place.country)
        return context.map { "\(city), \($0)" } ?? city
    }
    @objc open var regionName: String? { place.country }
    @objc open var regionCode: String? { place.isoCountryCode }
}

extension MKMapItem {
    /// a map item for a location and its address (iOS 26)
    public convenience init(location: CLLocation, address: MKAddress?) {
        self.init(placemark: MKPlacemark(coordinate: location.coordinate))
        _isimAddress = address
    }
    @objc public var location: CLLocation {
        placemark.location ?? CLLocation(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude)
    }
    @objc public var address: MKAddress? {
        if let a = _isimAddress { return a }
        return placemark.locality != nil || placemark.thoroughfare != nil ? MKAddress(placemark) : nil
    }
    @objc public var addressRepresentations: MKAddressRepresentations? {
        placemark.locality != nil || placemark.thoroughfare != nil ? MKAddressRepresentations(placemark) : nil
    }
}

// MARK: - geocoding requests (iOS 26)
/// the gazetteer's answer as map items, or the error iOS gives
func _mkGeocode(_ work: @escaping (@escaping CLGeocoder.CompletionHandler) -> Void, cancelled: @escaping () -> Bool,
                _ done: @escaping ([MKMapItem]?, Error?) -> Void) {
    work { places, error in
        if cancelled() { done(nil, CLError(.geocodeCanceled)); return }
        if let e = error as? CLError, e.code == .network { done(nil, MKError(.serverFailure)); return }
        guard let places, !places.isEmpty else { done(nil, MKError(.placemarkNotFound)); return }
        done(places.map { MKMapItem(placemark: MKPlacemark(placemark: $0)) }, nil)
    }
}

/// finds the places an address names
@objc(MKGeocodingRequest) public final class MKGeocodingRequest: NSObject, @unchecked Sendable {
    @objc public let addressString: String
    public var region: MKCoordinateRegion?
    @objc public var preferredLocale: Locale?
    @objc public private(set) var isCancelled = false
    @objc public private(set) var isLoading = false
    private let geocoder = CLGeocoder()
    public init?(addressString: String) {
        guard !addressString.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        self.addressString = addressString
    }
    @objc public func cancel() { isCancelled = true; geocoder.cancelGeocode() }
    @objc public func getMapItems(completionHandler: @escaping ([MKMapItem]?, Error?) -> Void) {
        let address = addressString
        isLoading = true
        _mkGeocode({ self.geocoder.geocodeAddressString(address, completionHandler: $0) }, cancelled: { self.isCancelled }) { items, e in
            self.isLoading = false
            completionHandler(items, e)                            // on the main queue, like CLGeocoder
        }
    }
    public var mapItems: [MKMapItem] {
        get async throws {
            try await withCheckedThrowingContinuation { c in
                getMapItems { items, e in if let items { c.resume(returning: items) } else { c.resume(throwing: e ?? MKError(.placemarkNotFound)) } }
            }
        }
    }
}

/// finds the place at a location
@objc(MKReverseGeocodingRequest) public final class MKReverseGeocodingRequest: NSObject, @unchecked Sendable {
    @objc public let location: CLLocation
    @objc public var preferredLocale: Locale?
    @objc public private(set) var isCancelled = false
    @objc public private(set) var isLoading = false
    private let geocoder = CLGeocoder()
    public init?(location: CLLocation) {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        self.location = location
    }
    @objc public func cancel() { isCancelled = true; geocoder.cancelGeocode() }
    @objc public func getMapItems(completionHandler: @escaping ([MKMapItem]?, Error?) -> Void) {
        let l = location
        isLoading = true
        _mkGeocode({ self.geocoder.reverseGeocodeLocation(l, completionHandler: $0) }, cancelled: { self.isCancelled }) { items, e in
            self.isLoading = false
            completionHandler(items, e)                            // on the main queue, like CLGeocoder
        }
    }
    public var mapItems: [MKMapItem] {
        get async throws {
            try await withCheckedThrowingContinuation { c in
                getMapItems { items, e in if let items { c.resume(returning: items) } else { c.resume(throwing: e ?? MKError(.placemarkNotFound)) } }
            }
        }
    }
}

// MARK: - distance formatter
/// formats distances like Maps: metric (m, km) or imperial (ft then mi; yd with .imperialWithYards)
@objc(MKDistanceFormatter) open class MKDistanceFormatter: Formatter, @unchecked Sendable {
    public enum Units: UInt, Sendable { case `default` = 0, metric, imperial, imperialWithYards }
    public enum DistanceUnitStyle: UInt, Sendable { case `default` = 0, abbreviated, full }
    open var locale: Locale! = .current
    open var units: Units = .default
    open var unitStyle: DistanceUnitStyle = .default
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    var _metric: Bool {
        switch units {
        case .metric: return true
        case .imperial, .imperialWithYards: return false
        case .default: return (locale ?? .current).measurementSystem == .metric
        }
    }
    private func unit(_ abbrev: String, _ one: String, _ many: String, _ value: Double) -> String {
        unitStyle == .full ? (value == 1 ? one : many) : abbrev
    }
    private func number(_ v: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.locale = locale; f.minimumFractionDigits = 0; f.maximumFractionDigits = decimals
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
    open func string(fromDistance distance: CLLocationDistance) -> String {
        let d = max(0, distance)
        if _metric {
            if d < 1000 { let m = d < 100 ? (d / 5).rounded() * 5 : (d / 10).rounded() * 10; return "\(number(m, decimals: 0)) \(unit("m", "meter", "meters", m))" }
            let km = d / 1000
            let v = km < 10 ? (km * 10).rounded() / 10 : km.rounded()
            return "\(number(v, decimals: 1)) \(unit("km", "kilometer", "kilometers", v))"
        }
        let miles = d / 1609.344
        if miles < 0.1 {
            if units == .imperialWithYards { let y = (d / 0.9144 / 10).rounded() * 10; return "\(number(y, decimals: 0)) \(unit("yd", "yard", "yards", y))" }
            let ft = (d / 0.3048 / 10).rounded() * 10
            return "\(number(ft, decimals: 0)) \(unit("ft", "foot", "feet", ft))"
        }
        let v = miles < 10 ? (miles * 10).rounded() / 10 : miles.rounded()
        return "\(number(v, decimals: 1)) \(unit("mi", "mile", "miles", v))"
    }
    /// the distance in meters a formatted string names (0 when it names none)
    open func distance(from distance: String) -> CLLocationDistance {
        let s = distance.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        let digits = s.prefix { $0.isNumber || $0 == "." }
        guard let v = Double(digits) else { return 0 }
        let u = s.dropFirst(digits.count).trimmingCharacters(in: .whitespaces).lowercased()
        switch u {
        case "km", "kilometer", "kilometers": return v * 1000
        case "mi", "mile", "miles": return v * 1609.344
        case "ft", "foot", "feet": return v * 0.3048
        case "yd", "yard", "yards": return v * 0.9144
        default: return v
        }
    }
    open override func string(for obj: Any?) -> String? {
        guard let n = obj as? NSNumber else { return nil }
        return string(fromDistance: n.doubleValue)
    }
}

// MARK: - GeoJSON
/// a GeoJSON object MKGeoJSONDecoder returns: a feature or a shape
public protocol MKGeoJSONObject: NSObjectProtocol {}
extension MKPointAnnotation: MKGeoJSONObject {}
extension MKMultiPoint: MKGeoJSONObject {}
extension MKMultiPolyline: MKGeoJSONObject {}
extension MKMultiPolygon: MKGeoJSONObject {}

/// a GeoJSON feature: its shapes, identifier and properties (as JSON data)
@objc(MKGeoJSONFeature) open class MKGeoJSONFeature: NSObject, MKGeoJSONObject, @unchecked Sendable {
    @objc open private(set) var identifier: String?
    @objc open private(set) var properties: Data?
    open private(set) var geometry: [MKShape & MKGeoJSONObject] = []
    init(identifier: String?, properties: Data?, geometry: [MKShape & MKGeoJSONObject]) {
        self.identifier = identifier; self.properties = properties; self.geometry = geometry
    }
}

/// decodes GeoJSON (RFC 7946) into MapKit shapes
@objc(MKGeoJSONDecoder) open class MKGeoJSONDecoder: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open func decode(_ data: Data) throws -> [MKGeoJSONObject] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MKError(.decodingFailed) }
        return try objects(json)
    }
    private func coordinate(_ a: Any?) throws -> CLLocationCoordinate2D {
        guard let p = a as? [Any], p.count >= 2, let lon = (p[0] as? NSNumber)?.doubleValue, let lat = (p[1] as? NSNumber)?.doubleValue else {
            throw MKError(.decodingFailed)
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    private func coordinates(_ a: Any?) throws -> [CLLocationCoordinate2D] {
        guard let a = a as? [Any] else { throw MKError(.decodingFailed) }
        return try a.map(coordinate)
    }
    private func polygon(_ a: Any?) throws -> MKPolygon {
        guard let rings = a as? [Any], let outer = rings.first else { throw MKError(.decodingFailed) }
        let holes = try rings.dropFirst().map { MKPolygon(coordinates: try coordinates($0)) }
        return MKPolygon(coordinates: try coordinates(outer), interiorPolygons: holes.isEmpty ? nil : holes)
    }
    private func shapes(_ g: [String: Any]) throws -> [MKShape & MKGeoJSONObject] {
        let c = g["coordinates"]
        switch g["type"] as? String {
        case "Point": return [MKPointAnnotation(coordinate: try coordinate(c))]
        case "MultiPoint": let m = MKMultiPoint(); m._points = try coordinates(c).map(MKMapPoint.init); return [m]
        case "LineString": return [MKPolyline(coordinates: try coordinates(c))]
        case "MultiLineString":
            guard let lines = c as? [Any] else { throw MKError(.decodingFailed) }
            return [MKMultiPolyline(try lines.map { MKPolyline(coordinates: try coordinates($0)) })]
        case "Polygon": return [try polygon(c)]
        case "MultiPolygon":
            guard let polys = c as? [Any] else { throw MKError(.decodingFailed) }
            return [MKMultiPolygon(try polys.map(polygon))]
        case "GeometryCollection":
            guard let gs = g["geometries"] as? [[String: Any]] else { throw MKError(.decodingFailed) }
            return try gs.flatMap(shapes)
        default: throw MKError(.decodingFailed)
        }
    }
    private func feature(_ f: [String: Any]) throws -> MKGeoJSONFeature {
        let id: String? = (f["id"] as? String) ?? (f["id"] as? NSNumber)?.stringValue
        var props: Data?
        if let p = f["properties"], !(p is NSNull) { props = try? JSONSerialization.data(withJSONObject: p) }
        let geometry = try (f["geometry"] as? [String: Any]).map { try shapes($0) } ?? []
        return MKGeoJSONFeature(identifier: id, properties: props, geometry: geometry)
    }
    private func objects(_ j: [String: Any]) throws -> [MKGeoJSONObject] {
        switch j["type"] as? String {
        case "FeatureCollection":
            guard let fs = j["features"] as? [[String: Any]] else { throw MKError(.decodingFailed) }
            return try fs.map(feature)
        case "Feature": return [try feature(j)]
        default: return try shapes(j)
        }
    }
}

// MARK: - Objective-C entry points (sdk-src/Frameworks/MapKit): enums as raw values, GeoJSON objects as NSObject
extension MKAddressRepresentations {
    @objc(fullAddressIncludingRegion:singleLine:) func _objc_fullAddress(_ region: Bool, singleLine: Bool) -> String? { fullAddress(includingRegion: region, singleLine: singleLine) }
}
extension MKAddress {
    @objc(initWithFullAddress:shortAddress:) convenience init?(_objcFull f: String, shortAddress: String?) { self.init(fullAddress: f, shortAddress: shortAddress) }
}
extension MKMapItem {
    @objc(initWithLocation:address:) convenience init(_objcLocation l: CLLocation, address: MKAddress?) { self.init(location: l, address: address) }
}
extension MKGeocodingRequest {
    @objc(initWithAddressString:) convenience init?(_objcAddress s: String) { self.init(addressString: s) }
}
extension MKReverseGeocodingRequest {
    @objc(initWithLocation:) convenience init?(_objcLocation l: CLLocation) { self.init(location: l) }
}
extension MKDistanceFormatter {
    @objc(stringFromDistance:) func _objc_string(_ d: Double) -> String { string(fromDistance: d) }
    @objc(distanceFromString:) func _objc_distance(_ s: String) -> Double { distance(from: s) }
    @objc(units) var _objc_units: UInt { get { units.rawValue } set { units = Units(rawValue: newValue) ?? .default } }
    @objc(unitStyle) var _objc_unitStyle: UInt { get { unitStyle.rawValue } set { unitStyle = DistanceUnitStyle(rawValue: newValue) ?? .default } }
    @objc(locale) var _objc_locale: Locale { get { locale ?? .current } set { locale = newValue } }
}
extension MKGeoJSONFeature {
    @objc(geometry) var _objc_geometry: [MKShape] { geometry }
}
extension MKGeoJSONDecoder {
    @objc(geoJSONObjectsWithData:error:) func _objc_decode(_ d: Data) throws -> [NSObject] { try decode(d).compactMap { $0 as? NSObject } }
}
