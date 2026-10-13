// isim MapKit: search, completion, directions, Look Around and snapshots — offline.
//
// MKLocalSearch / MKLocalSearchCompleter answer from Core Location's small built-in gazetteer (the same places
// CLGeocoder knows) plus the basemap's city list; anything else finds nothing (MKError.placemarkNotFound, like
// a search with no results). MKDirections has no routing data of its own: with ISIM_ROUTING_URL set to an OSRM server
// (one you run, e.g. http://localhost:5000) it asks that server for routes; otherwise calculate() and calculateETA() fail
// with MKError.directionsNotFound. MKLookAroundSceneRequest finds scenes only in a local folder of panoramas you supply
// (no Look Around imagery otherwise). MKMapSnapshotter renders the offline basemap.
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
    /// isim has no road network: routes come from the OSRM server in ISIM_ROUTING_URL, else none (directionsNotFound)
    open func calculate(completionHandler: @escaping DirectionsHandler) {
        isCalculating = true
        let rq = request
        _MKRouting.routes(rq, steps: true) { [self] routes, err in
            isCalculating = false
            guard !cancelled else { completionHandler(nil, MKError(.unknown)); return }
            guard let routes, !routes.isEmpty else { completionHandler(nil, err ?? MKError(.directionsNotFound)); return }
            let r = Response()
            r.source = rq.source ?? MKMapItem.forCurrentLocation(); r.destination = rq.destination ?? MKMapItem()
            r.routes = rq.requestsAlternateRoutes ? routes : [routes[0]]
            completionHandler(r, nil)
        }
    }
    open func calculate() async throws -> Response {
        try await withCheckedThrowingContinuation { c in calculate { r, e in if let r { c.resume(returning: r) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
    open func calculateETA(completionHandler: @escaping ETAHandler) {
        isCalculating = true
        let rq = request
        _MKRouting.routes(rq, steps: false) { [self] routes, err in
            isCalculating = false
            guard !cancelled else { completionHandler(nil, MKError(.unknown)); return }
            guard let route = routes?.first else { completionHandler(nil, err ?? MKError(.directionsNotFound)); return }
            let r = ETAResponse()
            r.source = rq.source ?? MKMapItem.forCurrentLocation(); r.destination = rq.destination ?? MKMapItem()
            r.expectedTravelTime = route.expectedTravelTime; r.distance = route.distance; r.transportType = route.transportType
            if let a = rq.arrivalDate { r.expectedArrivalDate = a; r.expectedDepartureDate = a - route.expectedTravelTime }
            else { r.expectedDepartureDate = rq.departureDate ?? Date(); r.expectedArrivalDate = r.expectedDepartureDate + route.expectedTravelTime }
            completionHandler(r, nil)
        }
    }
    open func calculateETA() async throws -> ETAResponse {
        try await withCheckedThrowingContinuation { c in calculateETA { r, e in if let r { c.resume(returning: r) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
    var cancelled = false
    open func cancel() { cancelled = true }
}

/// routes from an OSRM server (http://project-osrm.org: the route service, GeoJSON geometry, steps) at ISIM_ROUTING_URL.
/// isim never picks a server itself: the URL is yours (a local osrm-routed, or a service whose terms you accept)
enum _MKRouting {
    static var base: String? {
        guard let u = ProcessInfo.processInfo.environment["ISIM_ROUTING_URL"], !u.isEmpty else { return nil }
        return u.hasSuffix("/") ? String(u.dropLast()) : u
    }
    static func routes(_ rq: MKDirections.Request, steps: Bool, done: @escaping @Sendable ([MKRoute]?, Error?) -> Void) {
        let from = (rq.source ?? MKMapItem.forCurrentLocation()).placemark.coordinate
        guard let to = rq.destination?.placemark.coordinate else { DispatchQueue.main.async { done(nil, MKError(.directionsNotFound)) }; return }
        // the transport type asked for: driving, then walking, then cycling (OSRM profiles); no transit
        let t = rq.transportType
        let (profile, type): (String, MKDirectionsTransportType) = t.contains(.automobile) ? ("driving", .automobile)
            : t.contains(.walking) ? ("walking", .walking) : t.contains(.cycling) ? ("cycling", .cycling) : ("", .transit)
        guard let base, !profile.isEmpty else {
            print("isim: MKDirections: no routing data offline (directions not available; set ISIM_ROUTING_URL to an OSRM server)")
            DispatchQueue.main.async { done(nil, MKError(.directionsNotFound)) }
            return
        }
        let coords = String(format: "%.6f,%.6f;%.6f,%.6f", from.longitude, from.latitude, to.longitude, to.latitude)
        let alts = rq.requestsAlternateRoutes ? "true" : "false"
        guard let url = URL(string: "\(base)/route/v1/\(profile)/\(coords)?overview=full&geometries=geojson&steps=\(steps)&alternatives=\(alts)") else {
            DispatchQueue.main.async { done(nil, MKError(.directionsNotFound)) }; return
        }
        URLSession.shared.dataTask(with: url) { data, _, err in
            let result: ([MKRoute]?, Error?)
            if err != nil || data == nil { result = (nil, MKError(.serverFailure)) }
            else if let obj = (try? JSONSerialization.jsonObject(with: data!)) as? [String: Any] {
                if (obj["code"] as? String) == "Ok", let rs = obj["routes"] as? [[String: Any]] {
                    result = (rs.map { parse($0, type) }, nil)
                } else { result = (nil, MKError(.directionsNotFound)) }   /* NoRoute, NoSegment, ... */
            } else { result = (nil, MKError(.decodingFailed)) }
            DispatchQueue.main.async { done(result.0, result.1) }
        }.resume()
    }
    static func line(_ g: Any?) -> MKPolyline {
        let pts = ((g as? [String: Any])?["coordinates"] as? [[Double]] ?? []).filter { $0.count >= 2 }
        return MKPolyline(coordinates: pts.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }, count: pts.count)
    }
    static func parse(_ r: [String: Any], _ type: MKDirectionsTransportType) -> MKRoute {
        let route = MKRoute()
        route.distance = r["distance"] as? Double ?? 0
        route.expectedTravelTime = r["duration"] as? Double ?? 0
        route.transportType = type
        route.polyline = line(r["geometry"])
        let legs = r["legs"] as? [[String: Any]] ?? []
        route.name = legs.compactMap { $0["summary"] as? String }.filter { !$0.isEmpty }.joined(separator: ", ")
        for leg in legs {
            for st in leg["steps"] as? [[String: Any]] ?? [] {
                let s = MKRoute.Step()
                s.distance = st["distance"] as? Double ?? 0
                s.polyline = line(st["geometry"])
                s.transportType = type
                s.instructions = instruction(st)
                if let classes = (st["intersections"] as? [[String: Any]])?.flatMap({ $0["classes"] as? [String] ?? [] }) {
                    if classes.contains("toll") { route.hasTolls = true }
                    if classes.contains("motorway") { route.hasHighways = true }
                }
                route.steps.append(s)
            }
        }
        return route
    }
    /// English instructions in Apple Maps' style from an OSRM maneuver (iOS's first step is the start: no instruction)
    static func instruction(_ st: [String: Any]) -> String {
        let m = st["maneuver"] as? [String: Any] ?? [:]
        let kind = m["type"] as? String ?? "", mod = (m["modifier"] as? String).map { $0 == "straight" ? "straight" : $0 } ?? ""
        let name = (st["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let onto = name.map { " onto \($0)" } ?? ""
        switch kind {
        case "depart": return ""
        case "arrive": return "Arrive at the destination"
        case "turn", "end of road": return mod.isEmpty || mod == "straight" ? "Continue\(onto)" : "Turn \(mod)\(onto)"
        case "new name", "continue": return mod.hasPrefix("slight") ? "Keep \(mod.dropFirst(7))\(onto)" : "Continue\(onto)"
        case "merge": return "Merge\(onto)"
        case "on ramp": return "Take the ramp\(onto)"
        case "off ramp": return "Take the exit\(onto)"
        case "fork": return "Keep \(mod.replacingOccurrences(of: "slight ", with: ""))\(onto)"
        case "roundabout", "rotary": return "At the roundabout, take exit \(m["exit"] as? Int ?? 1)\(onto)"
        default: return name.map { "Continue on \($0)" } ?? "Continue"
        }
    }
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
//
// isim has no Look Around imagery. A scene exists where you supply a panorama: an equirectangular image (360° wide,
// 180° tall, its centre facing north) named "LAT,LON.jpg" (or .png) in $ISIM_LOOKAROUND or
// $ISIM_DATA/Library/Maps/LookAround; a request finds the nearest one within 50 m. Elsewhere there is no scene, as
// at a place Apple has no coverage for.

open class MKLookAroundScene: NSObject, @unchecked Sendable {
    let _path: String
    let _coordinate: CLLocationCoordinate2D
    init(path: String, coordinate: CLLocationCoordinate2D) { _path = path; _coordinate = coordinate }
    var _image: UIImage? { UIImage(contentsOfFile: _path) }
}
enum _MKLookAround {
    static var dir: String? {
        let env = ProcessInfo.processInfo.environment
        var cands: [String] = []
        if let d = env["ISIM_LOOKAROUND"], !d.isEmpty { cands.append(d) }
        if let d = env["ISIM_DATA"], !d.isEmpty { cands.append((d as NSString).appendingPathComponent("Library/Maps/LookAround")) }
        return cands.first { var isDir: ObjCBool = false; return FileManager.default.fileExists(atPath: $0, isDirectory: &isDir) && isDir.boolValue }
    }
    static func scene(near c: CLLocationCoordinate2D) -> MKLookAroundScene? {
        guard let dir, let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return nil }
        var best: (Double, MKLookAroundScene)?
        for n in names {
            let ext = (n as NSString).pathExtension.lowercased()
            guard ["jpg", "jpeg", "png"].contains(ext) else { continue }
            let parts = (n as NSString).deletingPathExtension.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count >= 2 else { continue }
            let at = CLLocationCoordinate2D(latitude: parts[0], longitude: parts[1])
            let d = _MKGeo.distance(c, at)
            if d <= 50, best == nil || d < best!.0 { best = (d, MKLookAroundScene(path: (dir as NSString).appendingPathComponent(n), coordinate: at)) }
        }
        return best?.1
    }
    /// adapted: a cylindrical view of the panorama (not Apple's rectilinear one): `fov` degrees wide around `heading`
    static func draw(_ img: UIImage, in rect: CGRect, heading: Double, fov: Double = 90) {
        let iw = img.size.width, ih = img.size.height
        guard iw > 0, ih > 0, let ctx = UIGraphicsGetCurrentContext() else { return }
        let scale = rect.width / (iw * CGFloat(fov / 360))          /* view points per image pixel */
        let x0 = rect.midX - (iw / 2 + CGFloat(heading / 360) * iw) * scale   /* the image centre faces north */
        let y0 = rect.midY - (ih / 2) * scale
        ctx.saveGState()
        ctx.clip(to: rect)
        for k in -1...1 {   /* the panorama wraps around */
            img.draw(in: CGRect(x: x0 + CGFloat(k) * iw * scale, y: y0, width: iw * scale, height: ih * scale))
        }
        ctx.restoreGState()
    }
}
open class MKLookAroundSceneRequest: NSObject, @unchecked Sendable {
    public let coordinate: CLLocationCoordinate2D
    open private(set) var mapItem: MKMapItem?
    open private(set) var isLoading = false
    open private(set) var isCancelled = false
    public init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
    public convenience init(mapItem: MKMapItem) { self.init(coordinate: mapItem.placemark.coordinate); self.mapItem = mapItem }
    /// a scene from your local panoramas, else none (no error), like a place without coverage
    open func getSceneWithCompletionHandler(_ completionHandler: @escaping (MKLookAroundScene?, Error?) -> Void) {
        isLoading = true
        let c = coordinate
        DispatchQueue.main.async { [self] in
            isLoading = false
            if isCancelled { completionHandler(nil, MKError(.unknown)); return }
            completionHandler(_MKLookAround.scene(near: c), nil)
        }
    }
    open var scene: MKLookAroundScene? {
        get async throws { _MKLookAround.scene(near: coordinate) }
    }
    open func cancel() { isCancelled = true }
}

public protocol MKLookAroundViewControllerDelegate: AnyObject {
    func lookAroundViewControllerWillUpdateScene(_ viewController: MKLookAroundViewController)
    func lookAroundViewControllerDidUpdateScene(_ viewController: MKLookAroundViewController)
}
extension MKLookAroundViewControllerDelegate {
    public func lookAroundViewControllerWillUpdateScene(_ viewController: MKLookAroundViewController) {}
    public func lookAroundViewControllerDidUpdateScene(_ viewController: MKLookAroundViewController) {}
}

/// the panorama, turned by dragging (adapted: no moving between scenes, no labels on the imagery)
final class _MKLookAroundView: UIView {
    var image: UIImage? { didSet { setNeedsDisplay() } }
    var heading: Double = 0 { didSet { setNeedsDisplay() } }
    var start: Double = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        accessibilityIdentifier = "lookaround"
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    @objc func pan(_ g: UIPanGestureRecognizer) {
        guard image != nil else { return }
        if g.state == .began { start = heading }
        // the view follows the finger: drag left to turn right
        let h = start - Double(g.translation(in: self).x) / Double(max(1, bounds.width)) * 90
        heading = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    override func draw(_ rect: CGRect) {
        guard let image else {
            let t = "Look Around isn't available" as NSString, f = UIFont.systemFont(ofSize: 15, weight: .medium)
            let sz = t.size(withAttributes: [.font: f])
            t.draw(at: CGPoint(x: bounds.midX - sz.width / 2, y: bounds.midY - sz.height / 2), withAttributes: [.font: f, .foregroundColor: UIColor.secondaryLabel])
            return
        }
        _MKLookAround.draw(image, in: bounds, heading: heading)
    }
    @objc func _isim_dumpText() -> String { image == nil ? "Look Around isn't available" : String(format: "Look Around heading %.0f", heading) }
}

open class MKLookAroundViewController: UIViewController {
    open weak var delegate: MKLookAroundViewControllerDelegate?
    open var scene: MKLookAroundScene? {
        willSet { if isViewLoaded { delegate?.lookAroundViewControllerWillUpdateScene(self) } }
        didSet { if isViewLoaded { _view.image = scene?._image; delegate?.lookAroundViewControllerDidUpdateScene(self) } }
    }
    open var isNavigationEnabled = true
    open var showsRoadLabels = true
    open var pointOfInterestFilter: MKPointOfInterestFilter?
    open var badgePosition: Int = 0
    let _view = _MKLookAroundView()
    public init(scene: MKLookAroundScene) { self.scene = scene; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    public init() { super.init(nibName: nil, bundle: nil) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        _view.frame = view.bounds; _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _view.image = scene?._image
        view.addSubview(_view)
    }
}

/// MKLookAroundSnapshotter: an image of a scene, looking north (adapted: cylindrical, see _MKLookAround.draw)
open class MKLookAroundSnapshotter: NSObject, @unchecked Sendable {
    open class Options: NSObject, @unchecked Sendable {
        open var size = CGSize(width: 256, height: 256)
        open var pointOfInterestFilter: MKPointOfInterestFilter?
        open var traitCollection = UITraitCollection()
        public override init() { super.init() }
    }
    open class Snapshot: NSObject, @unchecked Sendable {
        public let image: UIImage
        init(image: UIImage) { self.image = image }
    }
    let scene: MKLookAroundScene, options: Options
    var cancelled = false
    public init(scene: MKLookAroundScene, options: Options) { self.scene = scene; self.options = options; super.init() }
    open func getSnapshotWithCompletionHandler(_ completionHandler: @escaping (Snapshot?, Error?) -> Void) {
        DispatchQueue.main.async { [self] in
            guard !cancelled, let img = scene._image else { completionHandler(nil, MKError(.unknown)); return }
            let size = options.size
            completionHandler(Snapshot(image: UIGraphicsImageRenderer(size: size).image { _ in _MKLookAround.draw(img, in: CGRect(origin: .zero, size: size), heading: 0) }), nil)
        }
    }
    open var snapshot: Snapshot {
        get async throws {
            try await withCheckedThrowingContinuation { c in getSnapshotWithCompletionHandler { s, e in if let s { c.resume(returning: s) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
        }
    }
    open func cancel() { cancelled = true }
}

// MARK: - snapshots

/// adapted: the offline basemap (with place names), as a map view would draw it; annotations and overlays are not in
/// snapshots (as on iOS: apps draw them using point(for:)). A camera turns the map to its heading; pitch is not drawn.
open class MKMapSnapshotter: NSObject, @unchecked Sendable {
    open class Options: NSObject, @unchecked Sendable {
        open var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)) {
            didSet { _usesCamera = false }
        }
        open var mapRect: MKMapRect { get { _MKMapRect(for: region) } set { region = MKCoordinateRegionForMapRect(newValue) } }
        /// the last of region / mapRect / camera set decides what the snapshot shows
        open var camera = MKMapCamera() { didSet { _usesCamera = true } }
        var _usesCamera = false
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
        let center: MKMapPoint, scale: Double, heading: Double, size: CGSize
        public let appearance: UITraitCollection
        init(image: UIImage, center: MKMapPoint, scale: Double, heading: Double, size: CGSize, traits: UITraitCollection) {
            self.image = image; self.center = center; self.scale = scale; self.heading = heading; self.size = size; appearance = traits
        }
        open func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            let p = MKMapPoint(coordinate)
            var dx = p.x - center.x
            if dx < -_MKWorld / 2 { dx += _MKWorld } else if dx > _MKWorld / 2 { dx -= _MKWorld }
            let (x, y) = MKMapView._rotate(dx / scale, (p.y - center.y) / scale, -heading * Double.pi / 180)
            return CGPoint(x: Double(size.width) / 2 + x, y: Double(size.height) / 2 + y)
        }
    }
    let options: Options
    open private(set) var isLoading = false
    var cancelled = false
    public init(options: Options) { self.options = options; super.init() }
    open func start(completionHandler: @escaping (Snapshot?, Error?) -> Void) { start(with: .main, completionHandler: completionHandler) }
    open func start(with queue: DispatchQueue, completionHandler: @escaping (Snapshot?, Error?) -> Void) {
        let o = options
        isLoading = true
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated {
                isLoading = false
                if cancelled { queue.async { completionHandler(nil, MKError(.unknown)) }; return }
                let size = o.size
                let center: MKMapPoint, s: Double, heading: Double
                if o._usesCamera {
                    let cam = o.camera
                    center = MKMapPoint(cam.centerCoordinate)
                    let metersTall = cam.centerCoordinateDistance * 2 * tan(15 * Double.pi / 180)
                    s = metersTall * MKMapPointsPerMeterAtLatitude(cam.centerCoordinate.latitude) / Double(max(1, size.height))
                    heading = cam.heading
                } else {
                    let r0 = _MKMapRect(for: o.region)
                    center = MKMapPoint(x: r0.midX, y: r0.midY)
                    s = max(r0.width / Double(size.width), r0.height / Double(size.height))
                    heading = 0
                }
                let h = heading * Double.pi / 180
                let type = o.mapType != .standard ? o.mapType : o.preferredConfiguration._type
                let dark = o.traitCollection.userInterfaceStyle == .dark
                // the area to draw, map-aligned around the centre: the bounding box of the turned image
                let w = Double(size.width), ht = Double(size.height)
                let bw = abs(w * cos(h)) + abs(ht * sin(h)), bh = abs(w * sin(h)) + abs(ht * cos(h))
                let area = CGRect(x: -bw / 2, y: -bh / 2, width: bw, height: bh)
                let visible = MKMapRect(x: center.x - bw / 2 * s, y: center.y - bh / 2 * s, width: bw * s, height: bh * s)
                let flat: (MKMapPoint) -> CGPoint = { p in
                    var dx = p.x - center.x
                    if dx < -_MKWorld / 2 { dx += _MKWorld } else if dx > _MKWorld / 2 { dx -= _MKWorld }
                    return CGPoint(x: dx / s, y: (p.y - center.y) / s)
                }
                let img = UIGraphicsImageRenderer(size: size).image { r in
                    let ctx = r.cgContext
                    ctx.saveGState()
                    ctx.translateBy(x: size.width / 2, y: size.height / 2)
                    ctx.rotate(by: CGFloat(-h))
                    _MKBasemap.draw(visible: visible, scale: s, rect: area, type: type, dark: dark, showsLabels: false, gridLabels: heading == 0, toView: flat)
                    ctx.restoreGState()
                    if o.pointOfInterestFilter.map({ $0.includes(.landmark) }) ?? true, !_MKBasemap.usesTiles {
                        _MKBasemap.drawPlaces(visible: visible, scale: s, rect: CGRect(origin: .zero, size: size), st: _MKBasemap.style(type, dark: dark)) { p in
                            let q = flat(p), t = MKMapView._rotate(Double(q.x), Double(q.y), -h)
                            return CGPoint(x: w / 2 + t.0, y: ht / 2 + t.1)
                        }
                    }
                }
                let snap = Snapshot(image: img, center: center, scale: s, heading: heading, size: size, traits: o.traitCollection)
                queue.async { completionHandler(snap, nil) }
            }
        }
    }
    open func start() async throws -> Snapshot {
        try await withCheckedThrowingContinuation { c in start { s, e in if let s { c.resume(returning: s) } else { c.resume(throwing: e ?? MKError(.unknown)) } } }
    }
    open func cancel() { cancelled = true }
}

// MARK: - small views

/// MKUserTrackingButton: toggles the map's user tracking mode (location arrow).
open class MKUserTrackingButton: UIView {
    open weak var mapView: MKMapView?
    public init(mapView: MKMapView?) {
        self.mapView = mapView
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        backgroundColor = .clear
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(_tapped)))
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    @objc func _tapped() {
        guard let m = mapView else { return }
        m.setUserTrackingMode(m.userTrackingMode == .none ? .follow : .none, animated: true); setNeedsDisplay()
        if m.userTrackingMode != .none && !m.showsUserLocation { m.showsUserLocation = true }
    }
    @objc func _isim_dumpText() -> String { mapView?.userTrackingMode == MKUserTrackingMode.none ? "location arrow" : "location arrow (following)" }
    open override func draw(_ rect: CGRect) {
        _MKControlPanel.draw(in: bounds, top: true, bottom: mapView?._showsPitchButton != true || superview !== mapView, traits: traitCollection)
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
    public init(mapView: MKMapView?) {
        self.mapView = mapView
        super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        backgroundColor = .clear
        accessibilityIdentifier = "map-compass"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(_tapped)))
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    /// adapted from iOS: a round translucent dial, the red needle pointing north, "N" on the dial; shown while the
    /// map is turned (.adaptive), tapping it turns the map back to north
    var _heading: Double { mapView?._heading ?? 0 }
    open override var isHidden: Bool {
        get { super.isHidden || (compassVisibility == .hidden) || (compassVisibility == .adaptive && mapView != nil && (abs(_heading) < 0.5 || abs(_heading - 360) < 0.5)) }
        set { super.isHidden = newValue }
    }
    @objc func _tapped() {
        guard let m = mapView else { return }
        let c = m.camera; c.heading = 0
        m.setCamera(c, animated: true)
    }
    open override func draw(_ rect: CGRect) {
        let b = bounds.insetBy(dx: 1, dy: 1), mid = CGPoint(x: bounds.midX, y: bounds.midY)
        let dark = traitCollection.userInterfaceStyle == .dark
        (dark ? UIColor(white: 0.18, alpha: 0.92) : UIColor(white: 1, alpha: 0.92)).setFill()
        UIBezierPath(ovalIn: b).fill()
        UIColor(white: dark ? 1 : 0, alpha: 0.10).setStroke()
        let ring = UIBezierPath(ovalIn: b.insetBy(dx: 0.25, dy: 0.25)); ring.lineWidth = 0.5; ring.stroke()
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.translateBy(x: mid.x, y: mid.y)
        ctx.rotate(by: CGFloat(-_heading * Double.pi / 180))   /* north as it lies on the map */
        let r = b.width / 2
        UIColor(white: dark ? 1 : 0, alpha: 0.35).setFill()
        for i in 0..<12 where i % 3 != 0 {
            let a = CGFloat(i) * .pi / 6
            UIBezierPath(ovalIn: CGRect(x: sin(a) * (r - 4) - 0.75, y: -cos(a) * (r - 4) - 0.75, width: 1.5, height: 1.5)).fill()
        }
        let needle = UIBezierPath()
        needle.move(to: CGPoint(x: 0, y: -r + 3)); needle.addLine(to: CGPoint(x: 4, y: -r + 11)); needle.addLine(to: CGPoint(x: -4, y: -r + 11)); needle.close()
        UIColor.systemRed.setFill(); needle.fill()
        let n = "N" as NSString, font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let sz = n.size(withAttributes: [.font: font])
        n.draw(at: CGPoint(x: -sz.width / 2, y: -sz.height / 2 + 2), withAttributes: [.font: font, .foregroundColor: dark ? UIColor.white : UIColor.black])
        ctx.restoreGState()
    }
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
