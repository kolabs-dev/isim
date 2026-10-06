// Sample: Core Location on isim — the location permission alert (Allow Once / While Using / Don't Allow, then the
// Always upgrade), CLLocationManager updates from the simulated location, requestLocation, distance, offline
// geocoding, circular region monitoring and CLLocationUpdate.liveUpdates().
import SwiftUI
import CoreLocation

@main
struct HelloLocationApp: App {
    @StateObject private var model = LocationModel()
    var body: some Scene { WindowGroup { ContentView(model: model) } }
}

let applePark = CLLocation(latitude: 37.334900, longitude: -122.009020)

final class LocationModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    let geocoder = CLGeocoder()
    @Published var status = "?"
    @Published var coordinate = "No location yet"
    @Published var placemark = ""
    @Published var events: [String] = []
    var liveTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    static func name(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
    func log(_ s: String) { print(s); events.append(s); if events.count > 4 { events.removeFirst() } }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = Self.name(manager.authorizationStatus)
        print("auth \(status) accuracy \(manager.accuracyAuthorization == .fullAccuracy ? "full" : "reduced")")
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        coordinate = String(format: "%.4f, %.4f", l.coordinate.latitude, l.coordinate.longitude)
        let km = l.distance(from: applePark) / 1000
        print(String(format: "location %.4f %.4f accuracy %.0f simulated %@ fromApplePark %.1fkm", l.coordinate.latitude, l.coordinate.longitude,
                     l.horizontalAccuracy, (l.sourceInformation?.isSimulatedBySoftware ?? false) ? "yes" : "no", km))
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as? CLError)?.code.rawValue ?? -1
        log("error \(code) \((error as NSError).domain)")
    }
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) { log("monitoring \(region.identifier)") }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) { log("region enter \(region.identifier)") }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) { log("region exit \(region.identifier)") }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        log("region state \(state == .inside ? "inside" : state == .outside ? "outside" : "unknown") \(region.identifier)")
    }

    func reverseGeocode() {
        guard let l = manager.location else { log("geocode: no location"); return }
        geocoder.reverseGeocodeLocation(l) { marks, error in
            if let p = marks?.first {
                self.placemark = "\(p.name ?? "?"), \(p.locality ?? "?")"
                print("placemark \(self.placemark) \(p.postalCode ?? "") \(p.isoCountryCode ?? "") tz \(p.timeZone?.identifier ?? "-") main \(Thread.isMainThread)")
            } else {
                self.log("geocode error \((error as? CLError)?.code.rawValue ?? -1)")
            }
        }
    }
    func forwardGeocode() {
        Task { @MainActor in
            do {
                let marks = try await geocoder.geocodeAddressString("Eiffel Tower, Paris")
                if let l = marks.first?.location { print(String(format: "forward %@ %.4f %.4f", marks.first?.name ?? "?", l.coordinate.latitude, l.coordinate.longitude)) }
                _ = try await geocoder.geocodeAddressString("Nowhere Street 99, Atlantis")
            } catch {
                print("forward error \((error as? CLError)?.code.rawValue ?? -1)")
            }
        }
    }
    func monitorApplePark() {
        let r = CLCircularRegion(center: applePark.coordinate, radius: 500, identifier: "ApplePark")
        r.notifyOnEntry = true; r.notifyOnExit = true
        manager.startMonitoring(for: r)
        manager.requestState(for: r)
    }
    func live() {
        liveTask?.cancel()
        liveTask = Task { @MainActor in
            var n = 0
            for await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied { print("live denied"); break }
                guard let l = update.location else { continue }
                n += 1
                print(String(format: "live %d %.4f %.4f speed %.0f", n, l.coordinate.latitude, l.coordinate.longitude, l.speed))
                if n == 3 { print("live done"); break }
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: LocationModel
    var body: some View {
        NavigationStack {
            List {
                Section("Authorization") {
                    Text("Status: \(model.status)").accessibilityIdentifier("status")
                    Button("Request When In Use") { model.manager.requestWhenInUseAuthorization() }.accessibilityIdentifier("requestWhenInUse")
                    Button("Request Always") { model.manager.requestAlwaysAuthorization() }.accessibilityIdentifier("requestAlways")
                }
                Section("Location") {
                    Text(model.coordinate).accessibilityIdentifier("coordinate")
                    Button("Start Updates") { model.manager.startUpdatingLocation() }.accessibilityIdentifier("start")
                    Button("Stop Updates") { model.manager.stopUpdatingLocation() }.accessibilityIdentifier("stop")
                    Button("Request Location") { model.manager.requestLocation() }.accessibilityIdentifier("once")
                    Button("Live Updates") { model.live() }.accessibilityIdentifier("live")
                }
                Section("Geocoding") {
                    Text(model.placemark.isEmpty ? "—" : model.placemark).accessibilityIdentifier("placemark")
                    Button("Reverse Geocode") { model.reverseGeocode() }.accessibilityIdentifier("geocode")
                    Button("Find the Eiffel Tower") { model.forwardGeocode() }.accessibilityIdentifier("forward")
                }
                Section("Regions") {
                    Button("Monitor Apple Park") { model.monitorApplePark() }.accessibilityIdentifier("region")
                    ForEach(model.events, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Location")
        }
    }
}
