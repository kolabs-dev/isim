// Sample: MapKit on isim — MKMapView (region, markers, a custom image annotation view, callout with an accessory
// button, polyline/circle/polygon overlays with renderers, user location from the simulated Core Location,
// selection, map types, coordinate conversion, a 3D camera with heading and pitch (animated), pinch / rotate /
// two-finger tilt), MKLocalSearch, MKDirections (offline: not available), MKMapSnapshotter, and the SwiftUI Map
// (iOS 17: Marker, Annotation, MapPolyline, MapCircle, UserAnnotation, MapCameraPosition, selection, mapStyle,
// onMapCameraChange). Launch with -swiftui for the SwiftUI screen.
import UIKit
import MapKit
import SwiftUI

func log(_ s: String) { print("HelloMaps: " + s) }
func fmt(_ c: CLLocationCoordinate2D) -> String { String(format: "%.4f,%.4f", c.latitude, c.longitude) }

let applePark = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902)
let infiniteLoop = CLLocationCoordinate2D(latitude: 37.33182, longitude: -122.03118)
let visitorCenter = CLLocationCoordinate2D(latitude: 37.33265, longitude: -122.00543)

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        if ProcessInfo.processInfo.arguments.contains("-swiftui-legacy") {
            window?.rootViewController = UIHostingController(rootView: LegacyMapScreen())
        } else if ProcessInfo.processInfo.arguments.contains("-swiftui") {
            window?.rootViewController = UIHostingController(rootView: SwiftUIMapScreen())
        } else {
            window?.rootViewController = MapViewController()
        }
        window?.makeKeyAndVisible()
        return true
    }
}

/// an annotation with its own class (custom view)
final class Landmark: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    init(_ c: CLLocationCoordinate2D, _ t: String, _ s: String) { coordinate = c; title = t; subtitle = s }
}

final class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate {
    let map = MKMapView()
    let status = UILabel()
    let location = CLLocationManager()
    var searchResults: [MKAnnotation] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        map.delegate = self
        map.accessibilityIdentifier = "map"
        map.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(map)
        status.text = "–"; status.font = .systemFont(ofSize: 14, weight: .medium); status.textAlignment = .center
        status.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9); status.accessibilityIdentifier = "status"
        status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status)
        let bar = UIStackView(); bar.axis = .horizontal; bar.distribution = .fillEqually; bar.spacing = 4
        bar.backgroundColor = .systemBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        for (t, id, sel) in [("Search", "search", #selector(search)), ("Route", "route", #selector(route)), ("Snap", "snapshot", #selector(snapshot)),
                             ("Zoom", "zoom", #selector(zoomIn)), ("3D", "camera", #selector(tilt)), ("Type", "maptype", #selector(toggleType))] as [(String, String, Selector)] {
            let b = UIButton(type: .system); b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside); bar.addArrangedSubview(b)
        }
        view.addSubview(bar)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor), map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor), map.bottomAnchor.constraint(equalTo: status.topAnchor),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor), status.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            status.heightAnchor.constraint(equalToConstant: 26), status.bottomAnchor.constraint(equalTo: bar.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor), bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: g.bottomAnchor), bar.heightAnchor.constraint(equalToConstant: 44),
        ])
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "marker")
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3335, longitude: -122.0180), latitudinalMeters: 4000, longitudinalMeters: 4000), animated: false)
        if ProcessInfo.processInfo.arguments.contains("-overlays") { addOverlayDemo(); return }
        if ProcessInfo.processInfo.arguments.contains("-lookaround") { lookAround(); return }
        let park = MKPointAnnotation(coordinate: applePark, title: "Apple Park", subtitle: "Cupertino")
        let loop = MKPointAnnotation(coordinate: infiniteLoop, title: "Infinite Loop", subtitle: "1 Infinite Loop")
        map.addAnnotations([park, loop, Landmark(visitorCenter, "Visitor Center", "Apple Park Visitor Center")])
        map.addOverlay(MKCircle(center: applePark, radius: 450))
        map.addOverlay(MKPolyline(coordinates: [infiniteLoop, CLLocationCoordinate2D(latitude: 37.3305, longitude: -122.0150), visitorCenter]))
        map.addOverlay(MKPolygon(coordinates: [CLLocationCoordinate2D(latitude: 37.3245, longitude: -122.0300), CLLocationCoordinate2D(latitude: 37.3245, longitude: -122.0220),
                                               CLLocationCoordinate2D(latitude: 37.3195, longitude: -122.0220), CLLocationCoordinate2D(latitude: 37.3195, longitude: -122.0300)]))
        location.delegate = self
        location.requestWhenInUseAuthorization()
        map.showsUserLocation = true
        let p = map.convert(applePark, toPointTo: map)
        let back = map.convert(p, toCoordinateFrom: map)
        log("convert roundtrip \(fmt(back))")
    }

    // MARK: delegate
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        if let l = annotation as? Landmark {
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: "landmark") ?? MKAnnotationView(annotation: l, reuseIdentifier: "landmark")
            v.annotation = l
            v.image = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28)).image { _ in
                UIColor.systemPurple.setFill(); UIBezierPath(roundedRect: CGRect(x: 2, y: 2, width: 24, height: 24), cornerRadius: 7).fill()
                UIColor.white.setFill(); UIBezierPath(ovalIn: CGRect(x: 9, y: 9, width: 10, height: 10)).fill()
            }
            v.canShowCallout = true
            let info = UIButton(type: .system); info.setTitle("Info", for: .normal); info.frame = CGRect(x: 0, y: 0, width: 44, height: 30)
            info.accessibilityIdentifier = "callout-info"
            v.rightCalloutAccessoryView = info
            v.accessibilityIdentifier = "landmark"
            return v
        }
        let v = mapView.dequeueReusableAnnotationView(withIdentifier: "marker", for: annotation) as! MKMarkerAnnotationView
        if annotation.title == "Infinite Loop" { v.markerTintColor = .systemBlue; v.glyphText = "1" } else { v.markerTintColor = .systemRed; v.glyphText = nil }
        v.accessibilityIdentifier = "marker-" + (annotation.title.flatMap { $0 } ?? "")
        return v
    }
    /// -lookaround: Look Around at Apple Park (a scene only where a panorama was supplied)
    func lookAround() {
        MKLookAroundSceneRequest(coordinate: applePark).getSceneWithCompletionHandler { [weak self] scene, err in
            log("look around scene: \(scene == nil ? "none" : "found") error=\(err == nil ? "none" : "\(err!)")")
            guard let self, let scene else { return }
            let vc = MKLookAroundViewController(scene: scene)
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false)
            let o = MKLookAroundSnapshotter.Options(); o.size = CGSize(width: 120, height: 80)
            MKLookAroundSnapshotter(scene: scene, options: o).getSnapshotWithCompletionHandler { snap, _ in
                log("look around snapshot \(Int(snap?.image.size.width ?? 0))x\(Int(snap?.image.size.height ?? 0))")
            }
        }
    }
    /// -overlays: a dashed line, a polygon with a hole, a renderer drawing itself (draw(_:zoomScale:in:)), a gradient line
    func addOverlayDemo() {
        func c(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
        func square(_ n: Double, _ w: Double, _ s: Double, _ e: Double) -> [CLLocationCoordinate2D] { [c(n, w), c(n, e), c(s, e), c(s, w)] }
        let dashed = MKPolyline(coordinates: [c(37.343, -122.030), c(37.343, -122.006)]); dashed.title = "dashed"
        let gradient = MKPolyline(coordinates: [c(37.323, -122.030), c(37.323, -122.006)]); gradient.title = "gradient"
        let holed = MKPolygon(coordinates: square(37.338, -122.030, 37.328, -122.020),
                              interiorPolygons: [MKPolygon(coordinates: square(37.3355, -122.0275, 37.3305, -122.0225))])
        let custom = MKPolygon(coordinates: square(37.338, -122.014, 37.328, -122.004)); custom.title = "custom"
        map.addOverlays([dashed, gradient, holed, custom])
        log("overlay demo: \(map.overlays.count) overlays")
    }
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let l as MKPolyline where l.title == "dashed":
            let r = MKPolylineRenderer(polyline: l); r.strokeColor = .systemRed; r.lineWidth = 6; r.lineCap = .butt; r.lineDashPattern = [12, 12]; return r
        case let l as MKPolyline where l.title == "gradient":
            let r = MKGradientPolylineRenderer(polyline: l); r.lineWidth = 8; r.setColors([.systemGreen, .systemBlue], locations: [0, 1]); return r
        case let p as MKPolygon where p.title == "custom":
            return Crosshair(overlay: p)
        case let c as MKCircle:
            let r = MKCircleRenderer(circle: c); r.fillColor = UIColor.systemGreen.withAlphaComponent(0.25); r.strokeColor = .systemGreen; r.lineWidth = 2; return r
        case let l as MKPolyline:
            let r = MKPolylineRenderer(polyline: l); r.strokeColor = .systemBlue; r.lineWidth = 5; return r
        case let p as MKPolygon:
            let r = MKPolygonRenderer(polygon: p); r.fillColor = UIColor.systemOrange.withAlphaComponent(0.5); r.strokeColor = .systemOrange; r.lineWidth = 1; return r
        default: return MKOverlayRenderer(overlay: overlay)
        }
    }
    var visibleChanges = 0
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) { visibleChanges = 0 }
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) { visibleChanges += 1 }
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let c = mapView.camera
        log(String(format: "camera heading %.0f pitch %.0f distance %.0f animated %@ after %d visible-region updates", c.heading, Double(c.pitch),
                   c.centerCoordinateDistance, animated ? "yes" : "no", visibleChanges))
        let r = mapView.region
        log(String(format: "region center %.4f,%.4f span %.4f", r.center.latitude, r.center.longitude, r.span.latitudeDelta))
    }
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let t = view.annotation?.title.flatMap { $0 } ?? "-"
        log("selected \(t)"); status.text = "selected \(t)"
    }
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) { log("deselected \(view.annotation?.title.flatMap { $0 } ?? "-")") }
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        log("callout accessory tapped for \(view.annotation?.title.flatMap { $0 } ?? "-")"); status.text = "info: Visitor Center"
    }
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let l = userLocation.location else { return }
        log("user location \(fmt(l.coordinate))")
    }
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) { log("added \(views.count) annotation views") }

    // MARK: actions
    @objc func search() {
        let rq = MKLocalSearch.Request(); rq.naturalLanguageQuery = "Golden Gate"; rq.region = map.region
        MKLocalSearch(request: rq).start { [weak self] resp, err in
            guard let self else { return }
            guard let resp else { log("search failed \((err as NSError?)?.code ?? 0)"); return }
            let items = resp.mapItems
            log("search found \(items.count): \(items.map { $0.name ?? "-" }.joined(separator: ", ")) at \(fmt(items[0].placemark.coordinate))")
            let anns = items.map { MKPointAnnotation(coordinate: $0.placemark.coordinate, title: $0.name, subtitle: nil) }
            self.map.addAnnotations(anns)
            self.map.setRegion(resp.boundingRegion, animated: true)
            self.status.text = "found \(items[0].name ?? "")"
        }
        completer.delegate = self
        completer.queryFragment = "Golden"
        let none = MKLocalSearch.Request(); none.naturalLanguageQuery = "Nowhere-at-all-xyz"
        MKLocalSearch(request: none).start { _, err in log("search for nonsense: \((err as? MKError)?.code == .placemarkNotFound ? "placemarkNotFound" : "?")") }
    }
    let completer = MKLocalSearchCompleter()
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let rs = completer.results
        log("completer: \(rs.count) for \(completer.queryFragment): " + rs.map { c in
            let h = c.titleHighlightRanges.first.map { "[\($0.rangeValue.location),\($0.rangeValue.length)]" } ?? ""
            return c.title + h + (c.subtitle.isEmpty ? "" : " (\(c.subtitle))")
        }.joined(separator: "; "))
        guard let first = rs.first else { return }
        MKLocalSearch(request: MKLocalSearch.Request(completion: first)).start { resp, _ in
            log("completion search found \(resp?.mapItems.first?.name ?? "nothing")")
        }
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) { log("completer failed \(error)") }
    @objc func route() {
        let rq = MKDirections.Request()
        rq.source = MKMapItem(placemark: MKPlacemark(coordinate: infiniteLoop)); rq.destination = MKMapItem(placemark: MKPlacemark(coordinate: applePark))
        rq.transportType = .walking
        MKDirections(request: rq).calculate { [weak self] resp, err in
            guard let resp, let r = resp.routes.first else {
                log("directions: none error=\((err as? MKError)?.code == .directionsNotFound ? "directionsNotFound" : "\(String(describing: err))")")
                return
            }
            log(String(format: "directions: route %@ %.0f m %.0f s walking=%@ %d points; steps: ", r.name, r.distance, r.expectedTravelTime,
                       r.transportType == .walking ? "yes" : "no", r.polyline.pointCount) + r.steps.map { $0.instructions }.filter { !$0.isEmpty }.joined(separator: " | "))
            self?.map.addOverlay(r.polyline)
        }
        MKDirections(request: rq).calculateETA { eta, _ in
            if let eta { log(String(format: "eta %.0f s %.0f m", eta.expectedTravelTime, eta.distance)) }
        }
    }
    @objc func snapshot() {
        let o = MKMapSnapshotter.Options(); o.region = map.region; o.size = CGSize(width: 200, height: 150)
        MKMapSnapshotter(options: o).start { snap, _ in
            guard let snap else { return }
            let p = snap.point(for: o.region.center)
            log("snapshot \(Int(snap.image.size.width))x\(Int(snap.image.size.height)) center at \(Int(p.x)),\(Int(p.y))")
        }
        // a camera turned to face east: a place east of the centre is above it in the snapshot
        let c = MKMapSnapshotter.Options(); c.size = CGSize(width: 200, height: 200)
        c.camera = MKMapCamera(lookingAtCenter: applePark, fromDistance: 3000, pitch: 0, heading: 90)
        MKMapSnapshotter(options: c).start { snap, _ in
            guard let snap else { return }
            let p = snap.point(for: applePark), e = snap.point(for: CLLocationCoordinate2D(latitude: applePark.latitude, longitude: applePark.longitude + 0.005))
            log("camera snapshot center at \(Int(p.x)),\(Int(p.y)) east at \(Int(e.x)),\(Int(e.y))")
        }
    }
    @objc func zoomIn() {
        map.setRegion(MKCoordinateRegion(center: applePark, latitudinalMeters: 1200, longitudinalMeters: 1200), animated: true)
    }
    /// a 3D camera: looking east over Apple Park, tilted 45° (animated)
    @objc func tilt() {
        map.setCamera(MKMapCamera(lookingAtCenter: applePark, fromDistance: 2500, pitch: 45, heading: 90), animated: true)
    }
    @objc func toggleType() {
        map.mapType = map.mapType == .standard ? .satellite : .standard
        log("map type \(map.mapType == .satellite ? "satellite" : "standard")")
    }
}

/// an overlay renderer that draws itself, as on iOS: in renderer coordinates (map points), scaled by zoomScale
final class Crosshair: MKOverlayRenderer {
    var logged = false
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let r = rect(for: overlay.boundingMapRect)
        context.setFillColor(UIColor.magenta.cgColor)
        context.fill(r)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(4 / zoomScale)   /* 4 points at any zoom */
        context.move(to: CGPoint(x: r.minX, y: r.midY)); context.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        context.move(to: CGPoint(x: r.midX, y: r.minY)); context.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        context.strokePath()
        if !logged { logged = true; log(String(format: "custom renderer draws at zoomScale %.5f", zoomScale)) }
    }
}

// MARK: - SwiftUI

let locationManager = CLLocationManager()

struct Spot: Identifiable { let id: String; let coordinate: CLLocationCoordinate2D }

struct SwiftUIMapScreen: View {
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3335, longitude: -122.0180),
                                                                               latitudinalMeters: 4000, longitudinalMeters: 4000))
    @State private var selection: String?
    @State private var cameraText = "–"
    let spots = [Spot(id: "Apple Park", coordinate: applePark), Spot(id: "Infinite Loop", coordinate: infiniteLoop)]
    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position, selection: $selection) {
                ForEach(spots) { s in
                    Marker(s.id, systemImage: "star.fill", coordinate: s.coordinate).tint(.orange).tag(s.id)
                }
                Annotation("Cafe Macs", coordinate: CLLocationCoordinate2D(latitude: 37.3302, longitude: -122.0285)) {
                    Text("Cafe").font(.caption).bold().padding(6).background(Color.yellow).cornerRadius(8)
                }
                MapPolyline(coordinates: [infiniteLoop, visitorCenter]).stroke(.blue, lineWidth: 4)
                MapCircle(center: applePark, radius: 450).foregroundStyle(Color.green.opacity(0.3)).stroke(.green, lineWidth: 2)
                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
                MapPitchToggle()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange { ctx in
                cameraText = String(format: "camera %.4f,%.4f", ctx.region.center.latitude, ctx.region.center.longitude)
                log("swiftui camera \(fmt(ctx.region.center))")
            }
            .accessibilityIdentifier("swiftui-map")
            Text(selection.map { "selected \($0)" } ?? cameraText).font(.footnote).padding(6).accessibilityIdentifier("swiftui-status")
            HStack {
                Button("Golden Gate") { position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783), latitudinalMeters: 3000, longitudinalMeters: 3000)) }
                    .accessibilityIdentifier("goto-gg")
                Button("Select park") { selection = "Apple Park" }.accessibilityIdentifier("select-park")
            }.padding(.bottom, 8)
        }
        .onChange(of: selection) { _, s in log("swiftui selection \(s ?? "nil")") }
        .onAppear { locationManager.requestWhenInUseAuthorization() }
    }
}

/// the iOS 14 SwiftUI Map: Map(coordinateRegion:showsUserLocation:userTrackingMode:annotationItems:) with MapMarker,
/// MapPin and MapAnnotation (one map each: an annotation closure returns one kind)
struct LegacyMapScreen: View {
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3335, longitude: -122.0180),
                                                   latitudinalMeters: 4000, longitudinalMeters: 4000)
    @State private var tracking: MapUserTrackingMode = .none
    let park = [Spot(id: "Apple Park", coordinate: applePark)]
    let loop = [Spot(id: "Infinite Loop", coordinate: infiniteLoop)]
    let cafe = [Spot(id: "Cafe", coordinate: CLLocationCoordinate2D(latitude: 37.3302, longitude: -122.0285))]
    var body: some View {
        VStack(spacing: 2) {
            Map(coordinateRegion: $region, showsUserLocation: true, userTrackingMode: $tracking, annotationItems: park) { s in
                MapMarker(coordinate: s.coordinate, tint: .purple)
            }.accessibilityIdentifier("legacy-marker")
            Map(coordinateRegion: $region, annotationItems: loop) { s in MapPin(coordinate: s.coordinate, tint: .green) }
                .accessibilityIdentifier("legacy-pin")
            Map(coordinateRegion: $region, annotationItems: cafe) { s in
                MapAnnotation(coordinate: s.coordinate) { Text("Cafe").font(.caption).bold().padding(6).background(Color.yellow).cornerRadius(8) }
            }.accessibilityIdentifier("legacy-annotation")
            Button("Follow") { tracking = .follow }.accessibilityIdentifier("follow").padding(.bottom, 8)
        }
        .onChange(of: tracking) { _, t in log("legacy tracking \(t == .follow ? "follow" : "none")") }
        .onChange(of: region.center.latitude) { _, _ in log("legacy region \(fmt(region.center))") }
        .onAppear { locationManager.requestWhenInUseAuthorization() }
    }
}
