// HelloCarPlayMaps: a CarPlay navigation app (issue #410). Its map is a view it draws in the car window (CPWindow);
// over it CarPlay draws the map template: bar buttons, map buttons, trip previews, the navigation session's guidance
// card and estimates, a navigation alert and the panning interface. Destinations come from a list template and a
// search template. It logs what CarPlay does ("cpm ...").
import CarPlay
import MapKit
import UIKit

func log(_ s: String) { NSLog("cpm %@", s) }

/// the app's own map: streets, a park, the route when navigating
final class MapView: UIView {
    var route = false { didSet { setNeedsDisplay() } }
    var zoom: CGFloat = 1 { didSet { setNeedsDisplay() } }
    var offset = CGPoint.zero { didSet { setNeedsDisplay() } }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        UIColor(red: 0.16, green: 0.17, blue: 0.2, alpha: 1).setFill(); c.fill(bounds)
        c.saveGState()
        c.translateBy(x: bounds.midX + offset.x, y: bounds.midY + offset.y); c.scaleBy(x: zoom, y: zoom)
        UIColor(red: 0.18, green: 0.3, blue: 0.22, alpha: 1).setFill()
        UIBezierPath(roundedRect: CGRect(x: 60, y: -190, width: 180, height: 120), cornerRadius: 20).fill()
        UIColor(white: 0.34, alpha: 1).setStroke()
        for i in stride(from: -600, through: 600, by: 90) {
            let v = UIBezierPath(); v.move(to: CGPoint(x: CGFloat(i), y: -400)); v.addLine(to: CGPoint(x: CGFloat(i) + 40, y: 400)); v.lineWidth = 10; v.stroke()
            let h = UIBezierPath(); h.move(to: CGPoint(x: -600, y: CGFloat(i) * 0.8)); h.addLine(to: CGPoint(x: 600, y: CGFloat(i) * 0.8 - 30)); h.lineWidth = 7; h.stroke()
        }
        if route {
            UIColor.systemBlue.setStroke()
            let r = UIBezierPath(); r.move(to: CGPoint(x: 0, y: 180)); r.addLine(to: CGPoint(x: 8, y: 20)); r.addLine(to: CGPoint(x: 190, y: -10)); r.addLine(to: CGPoint(x: 205, y: -160))
            r.lineWidth = 12; r.lineCapStyle = .round; r.lineJoinStyle = .round; r.stroke()
            UIColor.systemRed.setFill(); UIBezierPath(ovalIn: CGRect(x: 193, y: -172, width: 24, height: 24)).fill()
        }
        c.restoreGState()
        // the car
        let p = CGPoint(x: bounds.midX, y: bounds.midY + (route ? 120 : 0))
        UIColor.white.setFill(); UIBezierPath(ovalIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)).fill()
        UIColor.systemBlue.setFill(); UIBezierPath(ovalIn: CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)).fill()
    }
}

final class MapViewController: UIViewController {
    let map = MapView()
    override func loadView() { view = map }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log("launched"); return true
    }
}

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = MapViewController()
        w.makeKeyAndVisible()
        window = w
    }
}

let places: [(name: String, address: String, lat: Double, lon: Double, minutes: Double, km: Double)] = [
    ("Apple Park", "One Apple Park Way, Cupertino", 37.3349, -122.009, 12, 8.4),
    ("Golden Gate Park", "San Francisco", 37.7694, -122.4862, 48, 62),
    ("Coffee Corner", "Main Street", 37.3318, -122.0312, 6, 2.1),
]

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPMapTemplateDelegate, CPSearchTemplateDelegate {
    var interfaceController: CPInterfaceController?
    var map: CPMapTemplate!
    let mapVC = MapViewController()
    var session: CPNavigationSession?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController, to window: CPWindow) {
        self.interfaceController = interfaceController
        window.rootViewController = mapVC
        let m = CPMapTemplate()
        m.mapDelegate = self
        m.leadingNavigationBarButtons = [CPBarButton(title: "Places") { [weak self] _ in self?.showPlaces() }]
        m.trailingNavigationBarButtons = [CPBarButton(image: UIImage(systemName: "magnifyingglass")!) { [weak self] _ in self?.showSearch() }]
        let zoomIn = CPMapButton { [weak self] _ in self?.mapVC.map.zoom *= 1.5; log("zoom in") }
        zoomIn.image = UIImage(systemName: "plus")
        let zoomOut = CPMapButton { [weak self] _ in self?.mapVC.map.zoom /= 1.5; log("zoom out") }
        zoomOut.image = UIImage(systemName: "minus")
        let pan = CPMapButton { [weak self] _ in self?.map.showPanningInterface(animated: true) }
        pan.image = UIImage(systemName: "arrow.up.left.and.arrow.down.right")
        m.mapButtons = [pan, zoomIn, zoomOut]
        map = m
        interfaceController.setRootTemplate(m, animated: false, completion: nil)
        log("connected window \(Int(window.bounds.width))x\(Int(window.bounds.height))")
    }
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) {
        log("disconnected")
    }
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didSelect maneuver: CPManeuver) {
        log("selected maneuver \(maneuver.instructionVariants.first ?? "")")
    }

    func trip(_ i: Int) -> CPTrip {
        let p = places[i]
        let dest = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)))
        dest.name = p.name
        let fastest = CPRouteChoice(summaryVariants: ["Fastest route", "Fastest"], additionalInformationVariants: ["via I-280 S"], selectionSummaryVariants: ["I-280 S"])
        let scenic = CPRouteChoice(summaryVariants: ["Scenic route", "Scenic"], additionalInformationVariants: ["via Skyline Blvd"], selectionSummaryVariants: ["Skyline"])
        let t = CPTrip(origin: MKMapItem.forCurrentLocation(), destination: dest, routeChoices: [fastest, scenic])
        t.userInfo = i
        return t
    }
    func showPlaces() {
        let items = places.enumerated().map { i, p -> CPListItem in
            let item = CPListItem(text: p.name, detailText: p.address, image: UIImage(systemName: "mappin.circle.fill"))
            item.handler = { [weak self] _, done in self?.preview(i); done() }
            return item
        }
        interfaceController?.pushTemplate(CPListTemplate(title: "Places", sections: [CPListSection(items: items)]), animated: true, completion: nil)
    }
    func preview(_ i: Int) {
        log("preview \(places[i].name)")
        interfaceController?.popToRootTemplate(animated: true, completion: nil)
        let t = trip(i)
        map.showTripPreviews([t], textConfiguration: CPTripPreviewTextConfiguration(startButtonTitle: "Go", additionalRoutesButtonTitle: "Routes", overviewButtonTitle: "Overview"))
        map.updateEstimates(CPTravelEstimates(distanceRemaining: Measurement(value: places[i].km, unit: .kilometers), timeRemaining: places[i].minutes * 60), for: t)
    }
    func showSearch() {
        let s = CPSearchTemplate()
        s.delegate = self
        interfaceController?.pushTemplate(s, animated: true, completion: nil)
    }

    // MARK: CPSearchTemplateDelegate
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        let hits = places.enumerated().filter { $0.element.name.localizedCaseInsensitiveContains(searchText) }
        log("search \(searchText): \(hits.count)")
        completionHandler(hits.map { i, p in let item = CPListItem(text: p.name, detailText: p.address); item.userInfo = i; return item })
    }
    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        if let i = item.userInfo as? Int { preview(i) }
        completionHandler()
    }

    // MARK: CPMapTemplateDelegate
    func mapTemplate(_ mapTemplate: CPMapTemplate, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice) {
        log("selected route \(routeChoice.summaryVariants.first ?? "")")
    }
    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        let i = trip.userInfo as? Int ?? 0
        log("started trip to \(places[i].name)")
        mapTemplate.hideTripPreviews()
        let s = mapTemplate.startNavigationSession(for: trip)
        let turn = CPManeuver()
        turn.instructionVariants = ["Turn right onto Stevens Creek Blvd", "Turn right"]
        turn.maneuverType = .rightTurn
        turn.initialTravelEstimates = CPTravelEstimates(distanceRemaining: Measurement(value: 400, unit: .meters), timeRemaining: 40)
        let arrive = CPManeuver()
        arrive.instructionVariants = ["Arrive at \(places[i].name)"]
        arrive.maneuverType = .arriveAtDestination
        s.upcomingManeuvers = [turn, arrive]
        mapTemplate.updateEstimates(CPTravelEstimates(distanceRemaining: Measurement(value: places[i].km, unit: .kilometers), timeRemaining: places[i].minutes * 60), for: trip)
        session = s
        mapVC.map.route = true
        // a navigation alert a moment later
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.alert() }
    }
    func alert() {
        let a = CPNavigationAlert(titleVariants: ["Faster route available"], subtitleVariants: ["Saves 4 minutes"], image: UIImage(systemName: "arrow.triangle.2.circlepath"),
                                  primaryAction: CPAlertAction(title: "Take It", style: .default) { _ in log("alert take") },
                                  secondaryAction: CPAlertAction(title: "Ignore", style: .cancel) { _ in log("alert ignore") }, duration: 0)
        map.present(navigationAlert: a, animated: true)
    }
    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        log("navigation cancelled")
        session = nil
        mapVC.map.route = false
    }
    func mapTemplate(_ mapTemplate: CPMapTemplate, didDismiss navigationAlert: CPNavigationAlert, dismissalContext: CPNavigationAlert.DismissalContext) {
        log("alert dismissed \(dismissalContext.rawValue)")
    }
    func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate) { log("panning shown") }
    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        let d: CGFloat = 60
        if direction.contains(.up) { mapVC.map.offset.y += d }
        if direction.contains(.down) { mapVC.map.offset.y -= d }
        if direction.contains(.left) { mapVC.map.offset.x += d }
        if direction.contains(.right) { mapVC.map.offset.x -= d }
        log("pan \(direction.rawValue)")
    }
}
