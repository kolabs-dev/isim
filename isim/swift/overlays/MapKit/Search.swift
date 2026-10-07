// isim MapKit: search, completion, directions, Look Around and snapshots — offline.
//
// MKLocalSearch / MKLocalSearchCompleter answer from Core Location's small built-in gazetteer (the same places
// CLGeocoder knows) plus the basemap's city list; anything else finds nothing (MKError.placemarkNotFound, like
// a search with no results). MKDirections has no routing data: calculate() and calculateETA() fail with
// MKError.directionsNotFound. MKLookAroundSceneRequest finds no scene (no Look Around imagery). MKMapSnapshotter renders the offline
// basemap.
import UIKit

open class MKLocalSearch: NSObject, @unchecked Sendable {
    open class Request: NSObject, @unchecked Sendable {
        public struct ResultType: OptionSet, Sendable {
            public let rawValue: UInt
            public init(rawValue: UInt) { self.rawValue = rawValue }
            public static let address = ResultType(rawValue: 1), pointOfInterest = ResultType(rawValue: 2), physicalFeature = ResultType(rawValue: 4)
        }
        open var naturalLanguageQuery: String?
        open var region = MKCoordinateRegion(center: CLLocationCoordinate2D(), span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360))
        open var resultTypes: ResultType = [.address, .pointOfInterest]
        open var pointOfInterestFilter: MKPointOfInterestFilter?
        open var regionPriority: Int = 0
        public override init() { super.init() }
        public init(completion: MKLocalSearchCompletion) { super.init(); naturalLanguageQuery = completion.title + (completion.subtitle.isEmpty ? "" : ", " + completion.subtitle) }
        public convenience init(naturalLanguageQuery: String) { self.init(); self.naturalLanguageQuery = naturalLanguageQuery }
    }
    open class Response: NSObject, @unchecked Sendable {
        open internal(set) var mapItems: [MKMapItem] = []
        open internal(set) var boundingRegion = MKCoordinateRegion()
    }
    public typealias CompletionHandler = (Response?, Error?) -> Void
    let request: Request
    open private(set) var isSearching = false
    var cancelled = false
    public init(request: Request) { self.request = request; super.init() }
    public init(request: MKLocalPointsOfInterestRequest) { self.request = Request(); super.init(); poi = request }
    var poi: MKLocalPointsOfInterestRequest?

    open func start(completionHandler: @escaping CompletionHandler) {
        isSearching = true
        let q = request.naturalLanguageQuery ?? ""
        let region = request.region, poi = poi
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            isSearching = false
            if cancelled { completionHandler(nil, MKError(.unknown)); return }
            Task { @MainActor in
                var items: [MKMapItem]
                if let poi { items = _MKSearchData.items(near: poi.coordinate, radius: poi.radius) } else { items = await _MKSearchData.items(for: q) }
                // prefer results inside the request region (like MapKit's region bias), keep the others after them
                let rect = _MKMapRect(for: region)
                items.sort { rect.contains(MKMapPoint($0.placemark.coordinate)) && !rect.contains(MKMapPoint($1.placemark.coordinate)) }
                guard !items.isEmpty else { completionHandler(nil, MKError(.placemarkNotFound)); return }
                let r = Response()
                r.mapItems = items
                var b = MKMapRect.null
                for i in items { let p = MKMapPoint(i.placemark.coordinate); b = b.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0)) }
                let pad = max(b.width, b.height, 20_000) * 0.2
                r.boundingRegion = MKCoordinateRegionForMapRect(b.insetBy(dx: -pad, dy: -pad))
                completionHandler(r, nil)
            }
        }
    }
    open func start() async throws -> Response {
        try await withCheckedThrowingContinuation { c in start { r, e in if let r { c.resume(returning: r) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
    open func cancel() { cancelled = true }
}

open class MKLocalPointsOfInterestRequest: NSObject, @unchecked Sendable {
    public static let requestMaxRadius: CLLocationDistance = 3000
    public let coordinate: CLLocationCoordinate2D
    public let radius: CLLocationDistance
    open var pointOfInterestFilter: MKPointOfInterestFilter?
    public init(center coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) { self.coordinate = coordinate; self.radius = radius }
    public init(coordinateRegion region: MKCoordinateRegion) {
        coordinate = region.center; radius = region.span.latitudeDelta * 111_000 / 2
    }
}

enum _MKSearchData {
    @MainActor static func items(for q: String) async -> [MKMapItem] {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        var out: [MKMapItem] = []
        let places: [CLPlacemark] = await withCheckedContinuation { c in
            CLGeocoder().geocodeAddressString(trimmed) { p, _ in c.resume(returning: p ?? []) }
        }
        for p in places {
            let m = MKMapItem(placemark: MKPlacemark(placemark: p))
            m.name = p.name
            m.pointOfInterestCategory = p.areasOfInterest == nil ? nil : .landmark
            out.append(m)
        }
        let lq = trimmed.lowercased()
        for c in _MKBasemap.places where c.rank < 4 && c.name.lowercased().contains(lq) && !out.contains(where: { $0.name == c.name }) {
            let m = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon)))
            m.name = c.name
            out.append(m)
        }
        return out
    }
    static func items(near c: CLLocationCoordinate2D, radius: Double) -> [MKMapItem] {
        _MKBasemap.places.filter { $0.rank == 4 && _MKGeo.distance(c, CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) <= max(radius, 100) }.map {
            let m = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)))
            m.name = $0.name; m.pointOfInterestCategory = .landmark
            return m
        }
    }
}

open class MKLocalSearchCompletion: NSObject, @unchecked Sendable {
    open internal(set) var title: String = ""
    open internal(set) var titleHighlightRanges: [NSValue] = []
    open internal(set) var subtitle: String = ""
    open internal(set) var subtitleHighlightRanges: [NSValue] = []
}

public protocol MKLocalSearchCompleterDelegate: AnyObject {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter)
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error)
}
extension MKLocalSearchCompleterDelegate {
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {}
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}

open class MKLocalSearchCompleter: NSObject, @unchecked Sendable {
    public struct ResultType: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let address = ResultType(rawValue: 1), pointOfInterest = ResultType(rawValue: 2), query = ResultType(rawValue: 4)
    }
    open weak var delegate: MKLocalSearchCompleterDelegate?
    open var queryFragment = "" { didSet { if queryFragment != oldValue { schedule() } } }
    open var region = MKCoordinateRegion()
    open var resultTypes: ResultType = [.address, .pointOfInterest, .query]
    open var pointOfInterestFilter: MKPointOfInterestFilter?
    open private(set) var results: [MKLocalSearchCompletion] = []
    open var isSearching: Bool { pending }
    var pending = false, generation = 0
    public override init() { super.init() }
    func schedule() {
        generation += 1
        let g = generation, q = queryFragment
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard g == generation else { return }
            Task { @MainActor in
                let items = await _MKSearchData.items(for: q)
                guard g == self.generation else { return }
                self.pending = false
                self.results = items.map { i in
                    let c = MKLocalSearchCompletion()
                    c.title = i.name ?? ""
                    c.subtitle = [i.placemark.locality, i.placemark.country].compactMap { $0 }.filter { $0 != i.name }.joined(separator: ", ")
                    let r = (c.title.lowercased() as NSString).range(of: q.lowercased())
                    if r.location != NSNotFound { c.titleHighlightRanges = [NSValue(range: r)] }
                    return c
                }
                self.delegate?.completerDidUpdateResults(self)
            }
        }
    }
    open func cancel() { generation += 1; pending = false }
}

// MARK: - directions

open class MKDirections: NSObject, @unchecked Sendable {
    open class Request: NSObject, @unchecked Sendable {
        open var source: MKMapItem?
        open var destination: MKMapItem?
        open var transportType: MKDirectionsTransportType = .any
        open var requestsAlternateRoutes = false
        open var departureDate: Date?
        open var arrivalDate: Date?
        open var tollPreference: Int = 0
        open var highwayPreference: Int = 0
        public override init() { super.init() }
        public init(contentsOf url: URL) { super.init() }
        public class func isDirectionsRequest(_ url: URL) -> Bool { false }
    }
    open class Response: NSObject, @unchecked Sendable {
        open internal(set) var source = MKMapItem()
        open internal(set) var destination = MKMapItem()
        open internal(set) var routes: [MKRoute] = []
    }
    open class ETAResponse: NSObject, @unchecked Sendable {
        open internal(set) var source = MKMapItem()
        open internal(set) var destination = MKMapItem()
        open internal(set) var expectedTravelTime: TimeInterval = 0
        open internal(set) var distance: CLLocationDistance = 0
        open internal(set) var expectedArrivalDate = Date()
        open internal(set) var expectedDepartureDate = Date()
        open internal(set) var transportType: MKDirectionsTransportType = .automobile
    }
    public typealias DirectionsHandler = (Response?, Error?) -> Void
    public typealias ETAHandler = (ETAResponse?, Error?) -> Void
    let request: Request
    open private(set) var isCalculating = false
    public init(request: Request) { self.request = request; super.init() }
    /// no road network on isim: like a request MapKit cannot route
    open func calculate(completionHandler: @escaping DirectionsHandler) {
        isCalculating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            isCalculating = false
            print("isim: MKDirections: no routing data offline (directions not available)")
            completionHandler(nil, MKError(.directionsNotFound))
        }
    }
    open func calculate() async throws -> Response {
        try await withCheckedThrowingContinuation { c in calculate { r, e in if let r { c.resume(returning: r) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
    open func calculateETA(completionHandler: @escaping ETAHandler) {
        isCalculating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            isCalculating = false
            completionHandler(nil, MKError(.directionsNotFound))
        }
    }
    open func calculateETA() async throws -> ETAResponse {
        try await withCheckedThrowingContinuation { c in calculateETA { r, e in if let r { c.resume(returning: r) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
    open func cancel() {}
}

public struct MKDirectionsTransportType: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let automobile = MKDirectionsTransportType(rawValue: 1), walking = MKDirectionsTransportType(rawValue: 2)
    public static let transit = MKDirectionsTransportType(rawValue: 4), cycling = MKDirectionsTransportType(rawValue: 8)
    public static let any = MKDirectionsTransportType(rawValue: 0x0FFFFFFF)
}

open class MKRoute: NSObject, @unchecked Sendable {
    open internal(set) var name = ""
    open internal(set) var advisoryNotices: [String] = []
    open internal(set) var distance: CLLocationDistance = 0
    open internal(set) var expectedTravelTime: TimeInterval = 0
    open internal(set) var transportType: MKDirectionsTransportType = .automobile
    open internal(set) var polyline = MKPolyline()
    open internal(set) var steps: [Step] = []
    open internal(set) var hasTolls = false
    open internal(set) var hasHighways = false
    open class Step: NSObject, @unchecked Sendable {
        open internal(set) var polyline = MKPolyline()
        open internal(set) var instructions = ""
        open internal(set) var notice: String?
        open internal(set) var distance: CLLocationDistance = 0
        open internal(set) var transportType: MKDirectionsTransportType = .automobile
    }
}

// MARK: - Look Around

open class MKLookAroundScene: NSObject, @unchecked Sendable {}
open class MKLookAroundSceneRequest: NSObject, @unchecked Sendable {
    public let coordinate: CLLocationCoordinate2D
    open private(set) var isLoading = false
    public init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
    public convenience init(mapItem: MKMapItem) { self.init(coordinate: mapItem.placemark.coordinate) }
    /// isim has no Look Around imagery: no scene, like a place without coverage
    open func getSceneWithCompletionHandler(_ completionHandler: @escaping (MKLookAroundScene?, Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(nil, nil) }
    }
    open var scene: MKLookAroundScene? { get async throws { nil } }
    open func cancel() {}
}
open class MKLookAroundViewController: UIViewController {
    open var scene: MKLookAroundScene?
    open var isNavigationEnabled = true
    open var showsRoadLabels = true
    public init(scene: MKLookAroundScene) { self.scene = scene; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        let l = UILabel(); l.text = "Look Around isn't available"; l.textColor = .secondaryLabel; l.textAlignment = .center
        l.frame = view.bounds; l.autoresizingMask = [.flexibleWidth, .flexibleHeight]; view.addSubview(l)
    }
}

// MARK: - snapshots

open class MKMapSnapshotter: NSObject, @unchecked Sendable {
    open class Options: NSObject, @unchecked Sendable {
        open var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        open var mapRect: MKMapRect { get { _MKMapRect(for: region) } set { region = MKCoordinateRegionForMapRect(newValue) } }
        open var camera = MKMapCamera()
        open var size = CGSize(width: 256, height: 256)
        open var mapType: MKMapType = .standard
        open var preferredConfiguration: MKMapConfiguration = MKStandardMapConfiguration()
        open var showsBuildings = true
        open var pointOfInterestFilter: MKPointOfInterestFilter?
        open var traitCollection = UITraitCollection()
        public override init() { super.init() }
    }
    open class Snapshot: NSObject, @unchecked Sendable {
        public let image: UIImage
        let rect: MKMapRect, size: CGSize
        public let appearance: UITraitCollection
        init(image: UIImage, rect: MKMapRect, size: CGSize, traits: UITraitCollection) { self.image = image; self.rect = rect; self.size = size; appearance = traits }
        open func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            let p = MKMapPoint(coordinate), s = rect.width / Double(size.width)
            return CGPoint(x: (p.x - rect.minX) / s, y: (p.y - rect.minY) / s)
        }
    }
    let options: Options
    open private(set) var isLoading = false
    public init(options: Options) { self.options = options; super.init() }
    open func start(completionHandler: @escaping (Snapshot?, Error?) -> Void) { start(with: .main, completionHandler: completionHandler) }
    open func start(with queue: DispatchQueue, completionHandler: @escaping (Snapshot?, Error?) -> Void) {
        let o = options
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let size = o.size
                let r0 = _MKMapRect(for: o.region)
                let s = max(r0.width / Double(size.width), r0.height / Double(size.height))
                let rect = MKMapRect(x: r0.midX - Double(size.width) * s / 2, y: r0.midY - Double(size.height) * s / 2, width: Double(size.width) * s, height: Double(size.height) * s)
                let type = o.mapType != .standard ? o.mapType : o.preferredConfiguration._type
                let dark = o.traitCollection.userInterfaceStyle == .dark
                let img = UIGraphicsImageRenderer(size: size).image { _ in
                    _MKBasemap.draw(visible: rect, scale: s, rect: CGRect(origin: .zero, size: size), type: type, dark: dark, showsLabels: true) { p in
                        CGPoint(x: (p.x - rect.minX) / s, y: (p.y - rect.minY) / s)
                    }
                }
                let snap = Snapshot(image: img, rect: rect, size: size, traits: o.traitCollection)
                queue.async { completionHandler(snap, nil) }
            }
        }
    }
    open func start() async throws -> Snapshot {
        try await withCheckedThrowingContinuation { c in start { s, e in if let s { c.resume(returning: s) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
    open func cancel() {}
}

// MARK: - small views

/// MKUserTrackingButton: toggles the map's user tracking mode (location arrow).
open class MKUserTrackingButton: UIView {
    open weak var mapView: MKMapView?
    public init(mapView: MKMapView?) { self.mapView = mapView; super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44)); backgroundColor = .systemBackground; layer.cornerRadius = 8 }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let m = mapView else { return }
        m.setUserTrackingMode(m.userTrackingMode == .none ? .follow : .none, animated: true); setNeedsDisplay()
    }
    open override func draw(_ rect: CGRect) {
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let p = UIBezierPath()
        p.move(to: CGPoint(x: c.x + 8, y: c.y - 8)); p.addLine(to: CGPoint(x: c.x - 9, y: c.y - 1)); p.addLine(to: CGPoint(x: c.x - 1, y: c.y + 1))
        p.addLine(to: CGPoint(x: c.x + 1, y: c.y + 9)); p.close()
        UIColor.systemBlue.setFill(); UIColor.systemBlue.setStroke()
        p.lineWidth = 1.5
        if mapView?.userTrackingMode == MKUserTrackingMode.none { p.stroke() } else { p.fill() }
    }
}
open class MKCompassButton: UIView {
    open weak var mapView: MKMapView?
    public enum Visibility: Int, Sendable { case adaptive = 0, hidden, visible }
    open var compassVisibility: Visibility = .adaptive
    public init(mapView: MKMapView?) { self.mapView = mapView; super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40)); isHidden = true }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
}
open class MKScaleView: UIView {
    open weak var mapView: MKMapView?
    public init(mapView: MKMapView?) { self.mapView = mapView; super.init(frame: CGRect(x: 0, y: 0, width: 150, height: 20)); backgroundColor = .clear }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func draw(_ rect: CGRect) {
        guard let m = mapView else { return }
        let metersPerPoint = m._scale / MKMapPointsPerMeterAtLatitude(m.centerCoordinate.latitude)
        let target = metersPerPoint * 100
        let nice = [1.0, 2, 5].flatMap { b in (0...7).map { b * pow(10, Double($0)) } }.sorted().last { $0 <= target } ?? target
        let w = CGFloat(nice / metersPerPoint)
        UIColor.label.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 14, width: w, height: 2)).fill()
        let s = nice >= 1000 ? "\(Int(nice / 1000)) km" : "\(Int(nice)) m"
        (s as NSString).draw(at: CGPoint(x: 0, y: 0), withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: UIColor.label])
    }
}
