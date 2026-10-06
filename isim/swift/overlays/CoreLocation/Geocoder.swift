// CLGeocoder (adapted): iOS geocodes through Apple's servers; isim has no such service, so it answers from a small
// built-in gazetteer (the Simulator's preset places and a few landmarks). Reverse geocoding returns the nearest entry
// within 25 km; forward geocoding matches names, streets and cities. Anything else fails with
// CLError.geocodeFoundNoResult; ISIM_GEOCODER=offline makes every request fail with CLError.network.
import Foundation

open class CLPlacemark: NSObject, NSCopying, @unchecked Sendable {
    open private(set) var location: CLLocation?
    open private(set) var region: CLRegion?
    open private(set) var timeZone: TimeZone?
    open private(set) var name: String?
    open private(set) var thoroughfare: String?
    open private(set) var subThoroughfare: String?
    open private(set) var locality: String?
    open private(set) var subLocality: String?
    open private(set) var administrativeArea: String?
    open private(set) var subAdministrativeArea: String?
    open private(set) var postalCode: String?
    open private(set) var isoCountryCode: String?
    open private(set) var country: String?
    open private(set) var inlandWater: String?
    open private(set) var ocean: String?
    open private(set) var areasOfInterest: [String]?
    @available(*, deprecated) open var addressDictionary: [AnyHashable: Any]? {
        var d: [AnyHashable: Any] = [:]
        d["Name"] = name; d["Street"] = [subThoroughfare, thoroughfare].compactMap { $0 }.joined(separator: " ")
        d["City"] = locality; d["State"] = administrativeArea; d["ZIP"] = postalCode; d["Country"] = country; d["CountryCode"] = isoCountryCode
        return d
    }

    public init(placemark: CLPlacemark) {
        location = placemark.location; region = placemark.region; timeZone = placemark.timeZone; name = placemark.name
        thoroughfare = placemark.thoroughfare; subThoroughfare = placemark.subThoroughfare; locality = placemark.locality
        subLocality = placemark.subLocality; administrativeArea = placemark.administrativeArea
        subAdministrativeArea = placemark.subAdministrativeArea; postalCode = placemark.postalCode
        isoCountryCode = placemark.isoCountryCode; country = placemark.country; areasOfInterest = placemark.areasOfInterest
    }
    init(_ p: _CLPlace) {
        let c = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
        location = CLLocation(coordinate: c, altitude: 0, horizontalAccuracy: 100, verticalAccuracy: -1, timestamp: Date())
        region = CLCircularRegion(center: c, radius: 100, identifier: "<\(p.lat),\(p.lon)> radius 100")
        timeZone = TimeZone(identifier: p.tz)
        name = p.name; thoroughfare = p.street; subThoroughfare = p.number; locality = p.city; subLocality = p.district
        administrativeArea = p.state; subAdministrativeArea = p.county; postalCode = p.postal; isoCountryCode = p.iso; country = p.country
        areasOfInterest = p.landmark ? [p.name] : nil
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override var description: String {
        let addr = [[subThoroughfare, thoroughfare].compactMap { $0 }.joined(separator: " "), locality, administrativeArea, postalCode, country]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return "\(name ?? ""), \(addr) @ \(location.map { String(format: "<%+.8f,%+.8f>", $0.coordinate.latitude, $0.coordinate.longitude) } ?? "")"
    }
}

struct _CLPlace {
    let name: String, number: String?, street: String?, district: String?, city: String, county: String?, state: String?, postal: String?
    let country: String, iso: String, tz: String, lat: Double, lon: Double, landmark: Bool
}

enum _CLGazetteer {
    static let places: [_CLPlace] = [
        _CLPlace(name: "Apple Park", number: "1", street: "Apple Park Way", district: nil, city: "Cupertino", county: "Santa Clara", state: "CA", postal: "95014",
                 country: "United States", iso: "US", tz: "America/Los_Angeles", lat: 37.334900, lon: -122.009020, landmark: true),
        _CLPlace(name: "1 Infinite Loop", number: "1", street: "Infinite Loop", district: nil, city: "Cupertino", county: "Santa Clara", state: "CA", postal: "95014",
                 country: "United States", iso: "US", tz: "America/Los_Angeles", lat: 37.331820, lon: -122.031180, landmark: false),
        _CLPlace(name: "Union Square", number: "333", street: "Post St", district: "Union Square", city: "San Francisco", county: "San Francisco", state: "CA", postal: "94108",
                 country: "United States", iso: "US", tz: "America/Los_Angeles", lat: 37.787994, lon: -122.407437, landmark: true),
        _CLPlace(name: "Golden Gate Bridge", number: nil, street: "Golden Gate Brg", district: "Presidio", city: "San Francisco", county: "San Francisco", state: "CA", postal: "94129",
                 country: "United States", iso: "US", tz: "America/Los_Angeles", lat: 37.819929, lon: -122.478255, landmark: true),
        _CLPlace(name: "Times Square", number: "1560", street: "Broadway", district: "Midtown", city: "New York", county: "New York County", state: "NY", postal: "10036",
                 country: "United States", iso: "US", tz: "America/New_York", lat: 40.758000, lon: -73.985500, landmark: true),
        _CLPlace(name: "Trafalgar Square", number: nil, street: "Trafalgar Square", district: "Westminster", city: "London", county: nil, state: "England", postal: "WC2N 5DN",
                 country: "United Kingdom", iso: "GB", tz: "Europe/London", lat: 51.508039, lon: -0.128069, landmark: true),
        _CLPlace(name: "Eiffel Tower", number: "5", street: "Avenue Anatole France", district: "7th Arrondissement", city: "Paris", county: "Paris", state: "Île-de-France", postal: "75007",
                 country: "France", iso: "FR", tz: "Europe/Paris", lat: 48.858370, lon: 2.294481, landmark: true),
        _CLPlace(name: "Brandenburg Gate", number: nil, street: "Pariser Platz", district: "Mitte", city: "Berlin", county: nil, state: "Berlin", postal: "10117",
                 country: "Germany", iso: "DE", tz: "Europe/Berlin", lat: 52.516275, lon: 13.377704, landmark: true),
        _CLPlace(name: "Praça do Comércio", number: nil, street: "Praça do Comércio", district: "Baixa", city: "Lisbon", county: "Lisbon", state: "Lisbon", postal: "1100-148",
                 country: "Portugal", iso: "PT", tz: "Europe/Lisbon", lat: 38.707751, lon: -9.136592, landmark: true),
        _CLPlace(name: "Shibuya Crossing", number: nil, street: "Dogenzaka", district: "Shibuya", city: "Tokyo", county: nil, state: "Tokyo", postal: "150-0043",
                 country: "Japan", iso: "JP", tz: "Asia/Tokyo", lat: 35.659482, lon: 139.700556, landmark: true),
        _CLPlace(name: "Sydney Opera House", number: "2", street: "Macquarie St", district: "Sydney", city: "Sydney", county: nil, state: "NSW", postal: "2000",
                 country: "Australia", iso: "AU", tz: "Australia/Sydney", lat: -33.856784, lon: 151.215297, landmark: true),
        _CLPlace(name: "Avenida Paulista", number: "1578", street: "Avenida Paulista", district: "Bela Vista", city: "São Paulo", county: nil, state: "SP", postal: "01310-200",
                 country: "Brazil", iso: "BR", tz: "America/Sao_Paulo", lat: -23.561414, lon: -46.655881, landmark: false),
        _CLPlace(name: "Copacabana", number: nil, street: "Avenida Atlântica", district: "Copacabana", city: "Rio de Janeiro", county: nil, state: "RJ", postal: "22021-001",
                 country: "Brazil", iso: "BR", tz: "America/Sao_Paulo", lat: -22.971177, lon: -43.182543, landmark: true),
        _CLPlace(name: "Zócalo", number: nil, street: "Plaza de la Constitución", district: "Centro", city: "Mexico City", county: nil, state: "CDMX", postal: "06000",
                 country: "Mexico", iso: "MX", tz: "America/Mexico_City", lat: 19.432608, lon: -99.133209, landmark: true),
        _CLPlace(name: "Gateway of India", number: nil, street: "Apollo Bandar", district: "Colaba", city: "Mumbai", county: nil, state: "MH", postal: "400001",
                 country: "India", iso: "IN", tz: "Asia/Kolkata", lat: 18.921984, lon: 72.834654, landmark: true),
        _CLPlace(name: "Waikiki Beach", number: nil, street: "Kalakaua Ave", district: "Waikiki", city: "Honolulu", county: "Honolulu", state: "HI", postal: "96815",
                 country: "United States", iso: "US", tz: "Pacific/Honolulu", lat: 21.276838, lon: -157.827810, landmark: true),
    ]
    static func nearest(_ c: CLLocationCoordinate2D) -> _CLPlace? {
        let best = places.min { _CLGeo.distance(c, CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) < _CLGeo.distance(c, CLLocationCoordinate2D(latitude: $1.lat, longitude: $1.lon)) }
        guard let best, _CLGeo.distance(c, CLLocationCoordinate2D(latitude: best.lat, longitude: best.lon)) <= 25_000 else { return nil }
        return best
    }
    static func search(_ q: String) -> [_CLPlace] {
        let q = q.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let words = q.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
        return places.filter { p in
            let hay = [p.name, [p.number, p.street].compactMap { $0 }.joined(separator: " "), p.city, p.state ?? "", p.postal ?? "", p.country, p.district ?? ""].joined(separator: " ").lowercased()
            return hay.contains(q) || words.allSatisfy { hay.contains($0) }
        }
    }
}

open class CLGeocoder: NSObject, @unchecked Sendable {
    public typealias CompletionHandler = ([CLPlacemark]?, Error?) -> Void
    open private(set) var isGeocoding = false
    private var canceled = false

    public override init() { super.init() }

    private func answer(_ work: @escaping () -> Result<[CLPlacemark], CLError>, _ done: @escaping CompletionHandler) {
        isGeocoding = true; canceled = false
        // a short delay stands in for the network round trip; completion runs on the main queue like iOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isGeocoding = false
            if self.canceled { done(nil, CLError(.geocodeCanceled)); return }
            if _Privacy.env("ISIM_GEOCODER")?.lowercased() == "offline" { done(nil, CLError(.network)); return }
            switch work() {
            case .success(let p): done(p, nil)
            case .failure(let e): done(nil, e)
            }
        }
    }
    open func reverseGeocodeLocation(_ location: CLLocation, completionHandler: @escaping CompletionHandler) {
        answer({ _CLGazetteer.nearest(location.coordinate).map { .success([CLPlacemark($0)]) } ?? .failure(CLError(.geocodeFoundNoResult)) }, completionHandler)
    }
    open func reverseGeocodeLocation(_ location: CLLocation, preferredLocale locale: Locale?, completionHandler: @escaping CompletionHandler) {
        reverseGeocodeLocation(location, completionHandler: completionHandler)
    }
    open func geocodeAddressString(_ addressString: String, completionHandler: @escaping CompletionHandler) {
        answer({ let r = _CLGazetteer.search(addressString).map(CLPlacemark.init); return r.isEmpty ? .failure(CLError(.geocodeFoundNoResult)) : .success(r) }, completionHandler)
    }
    open func geocodeAddressString(_ addressString: String, in region: CLRegion?, completionHandler: @escaping CompletionHandler) {
        geocodeAddressString(addressString, completionHandler: completionHandler)
    }
    open func geocodeAddressString(_ addressString: String, in region: CLRegion?, preferredLocale locale: Locale?, completionHandler: @escaping CompletionHandler) {
        geocodeAddressString(addressString, completionHandler: completionHandler)
    }
    open func cancelGeocode() { if isGeocoding { canceled = true } }

    private func awaiting(_ start: (@escaping CompletionHandler) -> Void) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<[CLPlacemark], Error>) in
            start { p, e in if let e { k.resume(throwing: e) } else { k.resume(returning: p ?? []) } }
        }
    }
    open func reverseGeocodeLocation(_ location: CLLocation) async throws -> [CLPlacemark] {
        try await awaiting { reverseGeocodeLocation(location, completionHandler: $0) }
    }
    open func reverseGeocodeLocation(_ location: CLLocation, preferredLocale locale: Locale?) async throws -> [CLPlacemark] {
        try await awaiting { reverseGeocodeLocation(location, completionHandler: $0) }
    }
    open func geocodeAddressString(_ addressString: String) async throws -> [CLPlacemark] {
        try await awaiting { geocodeAddressString(addressString, completionHandler: $0) }
    }
    open func geocodeAddressString(_ addressString: String, in region: CLRegion?, preferredLocale locale: Locale?) async throws -> [CLPlacemark] {
        try await awaiting { geocodeAddressString(addressString, completionHandler: $0) }
    }
}
