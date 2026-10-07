// Sample: MapKit on isim — MKMapView (region, markers, a custom image annotation view, callout with an accessory
// button, polyline/circle/polygon overlays with renderers, user location from the simulated Core Location,
// selection, map types, coordinate conversion), MKLocalSearch, MKDirections (offline: not available),
// MKMapSnapshotter, and the SwiftUI Map (iOS 17: Marker, Annotation, MapPolyline, MapCircle, UserAnnotation,
// MapCameraPosition, selection, mapStyle, onMapCameraChange). Launch with -swiftui for the SwiftUI screen.
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
        if ProcessInfo.processInfo.arguments.contains("-swiftui") {
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

final class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
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
                             ("Zoom", "zoom", #selector(zoomIn)), ("Type", "maptype", #selector(toggleType))] as [(String, String, Selector)] {
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
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let c as MKCircle:
            let r = MKCircleRenderer(circle: c); r.fillColor = UIColor.systemGreen.withAlphaComponent(0.25); r.strokeColor = .systemGreen; r.lineWidth = 2; return r
        case let l as MKPolyline:
            let r = MKPolylineRenderer(polyline: l); r.strokeColor = .systemBlue; r.lineWidth = 5; return r
        case let p as MKPolygon:
            let r = MKPolygonRenderer(polygon: p); r.fillColor = UIColor.systemOrange.withAlphaComponent(0.5); r.strokeColor = .systemOrange; r.lineWidth = 1; return r
        default: return MKOverlayRenderer(overlay: overlay)
        }
    }
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
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
        let none = MKLocalSearch.Request(); none.naturalLanguageQuery = "Nowhere-at-all-xyz"
        MKLocalSearch(request: none).start { _, err in log("search for nonsense: \((err as? MKError)?.code == .placemarkNotFound ? "placemarkNotFound" : "?")") }
    }
    @objc func route() {
        let rq = MKDirections.Request()
        rq.source = MKMapItem(placemark: MKPlacemark(coordinate: infiniteLoop)); rq.destination = MKMapItem(placemark: MKPlacemark(coordinate: applePark))
        MKDirections(request: rq).calculate { resp, err in
            log("directions: \(resp == nil ? "none" : "route") error=\((err as? MKError)?.code == .directionsNotFound ? "directionsNotFound" : "\(String(describing: err))")")
        }
    }
    @objc func snapshot() {
        let o = MKMapSnapshotter.Options(); o.region = map.region; o.size = CGSize(width: 200, height: 150)
        MKMapSnapshotter(options: o).start { snap, _ in
            guard let snap else { return }
            let p = snap.point(for: o.region.center)
            log("snapshot \(Int(snap.image.size.width))x\(Int(snap.image.size.height)) center at \(Int(p.x)),\(Int(p.y))")
        }
    }
    @objc func zoomIn() {
        map.setRegion(MKCoordinateRegion(center: applePark, latitudinalMeters: 1200, longitudinalMeters: 1200), animated: true)
    }
    @objc func toggleType() {
        map.mapType = map.mapType == .standard ? .satellite : .standard
        log("map type \(map.mapType == .satellite ? "satellite" : "standard")")
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
