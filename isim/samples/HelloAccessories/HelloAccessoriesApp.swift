// HelloAccessories: the frameworks that talk to other devices, each like Apple's Simulator: the location button
// (SwiftUI's LocationButton and UIKit's CLLocationButton grant temporary location access), WatchConnectivity (no
// paired watch), ExternalAccessory (no MFi accessories), NearbyInteraction (no Ultra Wideband), WorkoutKit (no watch to
// schedule on) and AccessorySetupKit (no accessories nearby).
import SwiftUI
import CoreLocation
import CoreLocationUI
import WatchConnectivity
import ExternalAccessory
import NearbyInteraction
import WorkoutKit
import AccessorySetupKit
import CoreBluetooth

@main
struct HelloAccessoriesApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

func log(_ s: String) { print(s); NSLog("HelloAccessories: %@", s) }

final class Devices: NSObject, ObservableObject, CLLocationManagerDelegate, WCSessionDelegate, NISessionDelegate {
    let location = CLLocationManager()
    var nearby: NISession?
    var setup: AnyObject?                                   // ASAccessorySession (iOS 18)
    @Published var status = "—"

    override init() { super.init(); location.delegate = self }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        log("location authorization \(manager.authorizationStatus.rawValue)")
    }
    func shared(_ from: String) {
        let auth = location.authorizationStatus
        log("\(from) tapped authorization \(auth.rawValue) location \(location.location != nil)")
        status = auth == .authorizedWhenInUse ? "Location shared" : "No location"
    }

    // MARK: WatchConnectivity
    func watch() {
        log("watch supported \(WCSession.isSupported())")
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        log("watch activated \(activationState.rawValue) paired \(session.isPaired) installed \(session.isWatchAppInstalled) reachable \(session.isReachable)")
        session.sendMessage(["ping": 1], replyHandler: nil) { e in log("watch message error \((e as NSError).code)") }
        do { try session.updateApplicationContext(["score": 3]) } catch { log("watch context error \((error as NSError).code)") }
        session.transferUserInfo(["level": 2])
    }
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        log("watch user info \(userInfoTransfer.userInfo.count) error \((error as NSError?)?.code ?? 0)")
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}

    // MARK: ExternalAccessory
    func accessories() {
        let manager = EAAccessoryManager.shared()
        log("accessories connected \(manager.connectedAccessories.count) session \(EASession(accessory: EAAccessory(), forProtocol: "dev.isim.samples.scale") != nil)")
        manager.showBluetoothAccessoryPicker(withNameFilter: nil) { e in
            log("accessory picker \((e as NSError?)?.domain ?? "-") \((e as NSError?)?.code ?? -1)")
        }
    }

    // MARK: NearbyInteraction
    func findNearby() {
        let caps = NISession.deviceCapabilities
        log("nearby distance \(caps.supportsPreciseDistanceMeasurement) direction \(caps.supportsDirectionMeasurement) camera \(caps.supportsCameraAssistance)")
        let session = NISession()
        session.delegate = self
        nearby = session
        do {
            session.run(try NINearbyAccessoryConfiguration(data: Data([1, 0, 2, 0])))
            log("nearby token \(session.discoveryToken != nil)")
        } catch { log("nearby configuration error \(error)") }
    }
    func session(_ session: NISession, didInvalidateWith error: Error) {
        log("nearby invalidated \((error as? NIError)?.code.rawValue ?? 0)")
    }

    // MARK: WorkoutKit
    func workout() async {
        let intervals = IntervalBlock(steps: [IntervalStep(.work, goal: .distance(400, .meters), alert: HeartRateZoneAlert(zone: 4)),
                                              IntervalStep(.recovery, goal: .time(90, .seconds))], iterations: 4)
        let custom = CustomWorkout(activity: .running, location: .outdoor, displayName: "Track 4×400",
                                   warmup: WorkoutStep(goal: .time(10, .minutes)), blocks: [intervals], cooldown: WorkoutStep(goal: .open))
        let plan = WorkoutPlan(.custom(custom))
        let auth = await WorkoutScheduler.shared.requestAuthorization()
        var tomorrow = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
        tomorrow.hour = 7
        await WorkoutScheduler.shared.schedule(plan, at: tomorrow)
        let scheduled = await WorkoutScheduler.shared.scheduledWorkouts
        log("workout supported \(WorkoutScheduler.isSupported) authorization \(auth) blocks \(custom.blocks.count) steps \(intervals.steps.count) scheduled \(scheduled.count)")
    }

    // MARK: AccessorySetupKit
    func setUpAccessory() {
        guard #available(iOS 18.0, *) else { log("setup unavailable before iOS 18"); return }
        let session = ASAccessorySession()
        setup = session
        session.activate(on: .main) { event in
            log("setup event \(event.eventType.rawValue)")
            guard event.eventType == .activated else { return }
            let descriptor = ASDiscoveryDescriptor()
            descriptor.bluetoothServiceUUID = CBUUID(string: "180D")
            let item = ASPickerDisplayItem(name: "Heart Rate Strap", productImage: UIImage(systemName: "heart.fill")!, descriptor: descriptor)
            session.showPicker(for: [item]) { e in
                log("setup picker \((e as NSError?)?.code ?? 0) accessories \(session.accessories.count) service \(descriptor.bluetoothServiceUUID?.uuidString ?? "-")")
            }
        }
    }
}

struct LocationButtonView: UIViewRepresentable {
    let tapped: () -> Void
    func makeUIView(context: Context) -> CLLocationButton {
        let b = CLLocationButton()
        b.label = .shareMyCurrentLocation
        b.icon = .arrowOutline
        b.cornerRadius = 20
        b.accessibilityIdentifier = "clLocationButton"
        b.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return b
    }
    func updateUIView(_ uiView: CLLocationButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(tapped) }
    final class Coordinator: NSObject {
        let tapped: () -> Void
        init(_ t: @escaping () -> Void) { tapped = t }
        @objc func tap() { tapped() }
    }
}

struct ContentView: View {
    @StateObject var devices = Devices()
    var body: some View {
        List {
            Section("Location") {
                LocationButton(.currentLocation) { devices.shared("LocationButton") }
                LocationButtonView { devices.shared("CLLocationButton") }.frame(height: 44)
                Text(devices.status).accessibilityIdentifier("status")
            }
            Section("Devices") {
                Button("Apple Watch") { devices.watch() }.accessibilityIdentifier("watch")
                Button("External Accessories") { devices.accessories() }.accessibilityIdentifier("accessories")
                Button("Find Nearby Tag") { devices.findNearby() }.accessibilityIdentifier("nearby")
                Button("Schedule Workout") { Task { await devices.workout() } }.accessibilityIdentifier("workout")
                Button("Set Up Accessory") { devices.setUpAccessory() }.accessibilityIdentifier("setup")
            }
        }
    }
}
