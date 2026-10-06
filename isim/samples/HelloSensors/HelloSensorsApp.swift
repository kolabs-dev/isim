// Sample: device sensors and health data on isim — Core Motion (a simulated iPhone held upright at rest; no
// pedometer, like the Simulator), Core Bluetooth (unsupported, like the Simulator), Core NFC (no reader) and
// HealthKit (the Health Access sheet, saving samples, statistics and sample queries).
import SwiftUI
import CoreMotion
import CoreBluetooth
import CoreNFC
import HealthKit

@main
struct HelloSensorsApp: App {
    @StateObject private var model = SensorModel()
    var body: some Scene { WindowGroup { ContentView(model: model) } }
}

final class SensorModel: NSObject, ObservableObject, CBCentralManagerDelegate, NFCNDEFReaderSessionDelegate {
    let motion = CMMotionManager()
    let health = HKHealthStore()
    var central: CBCentralManager?
    var nfc: NFCNDEFReaderSession?
    @Published var motionText = "—"
    @Published var bluetooth = "—"
    @Published var healthText = "—"
    var ticks = 0

    func startMotion() {
        print("motion available accel \(motion.isAccelerometerAvailable) gyro \(motion.isGyroAvailable) deviceMotion \(motion.isDeviceMotionAvailable)")
        print("pedometer steps \(CMPedometer.isStepCountingAvailable()) activity \(CMMotionActivityManager.isActivityAvailable()) altimeter \(CMAltimeter.isRelativeAltitudeAvailable())")
        guard motion.isAccelerometerAvailable else { motionText = "No motion sensors"; return }
        motion.accelerometerUpdateInterval = 0.1
        ticks = 0
        motion.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data?.acceleration else { return }
            self.ticks += 1
            if self.ticks == 3 {
                print(String(format: "accel %.2f %.2f %.2f after %d updates", a.x, a.y, a.z, self.ticks))
                self.motion.stopAccelerometerUpdates()
            }
        }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { m, _ in
            guard let m else { return }
            print(String(format: "deviceMotion gravity %.2f %.2f %.2f user %.2f pitch %.2f roll %.2f", m.gravity.x, m.gravity.y, m.gravity.z,
                         m.userAcceleration.x + m.userAcceleration.y + m.userAcceleration.z, m.attitude.pitch, m.attitude.roll))
            self.motionText = String(format: "gravity %.0f, %.0f, %.0f", m.gravity.x, m.gravity.y, m.gravity.z)
            self.motion.stopDeviceMotionUpdates()
        }
        motion.startGyroUpdates()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let g = self.motion.gyroData?.rotationRate { print(String(format: "gyro %.2f %.2f %.2f active %@", g.x, g.y, g.z, self.motion.isGyroActive ? "yes" : "no")) }
            self.motion.stopGyroUpdates()
        }
        CMPedometer().queryPedometerData(from: Date().addingTimeInterval(-3600), to: Date()) { data, error in
            print("pedometer query error \((error as? CMError)?.code.rawValue ?? 0)")
        }
    }

    // MARK: Bluetooth
    func startBluetooth() { central = CBCentralManager(delegate: self, queue: nil) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let names = ["unknown", "resetting", "unsupported", "unauthorized", "poweredOff", "poweredOn"]
        bluetooth = names[central.state.rawValue]
        print("bluetooth state \(bluetooth) authorization \(CBManager.authorization.rawValue)")
        central.scanForPeripherals(withServices: [CBUUID(string: "180D")])
    }

    // MARK: NFC
    func startNFC() {
        print("nfc readingAvailable \(NFCNDEFReaderSession.readingAvailable)")
        nfc = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        nfc?.alertMessage = "Hold your iPhone near a tag"
        nfc?.begin()
    }
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("nfc invalidated \((error as? NFCReaderError)?.code.rawValue ?? -1)")
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) { print("nfc read \(messages.count)") }

    // MARK: HealthKit
    let steps = HKQuantityType(.stepCount)
    let weight = HKQuantityType(.bodyMass)
    let heart = HKQuantityType(.heartRate)
    func requestHealth() {
        print("health available \(HKHealthStore.isHealthDataAvailable())")
        health.requestAuthorization(toShare: [steps, weight], read: [steps, heart]) { ok, error in
            DispatchQueue.main.async {
                let s = self.health.authorizationStatus(for: self.steps), w = self.health.authorizationStatus(for: self.weight)
                print("health auth \(ok) steps \(s.rawValue) weight \(w.rawValue) error \(error == nil ? "none" : "\(error!)")")
                self.healthText = "steps \(s == .sharingAuthorized ? "allowed" : "denied")"
            }
        }
    }
    func saveSteps() {
        let now = Date()
        let samples = [1200.0, 800.0, 450.0].enumerated().map { i, v in
            HKQuantitySample(type: steps, quantity: HKQuantity(unit: .count(), doubleValue: v),
                             start: now.addingTimeInterval(Double(-3600 * (i + 1))), end: now.addingTimeInterval(Double(-3600 * (i + 1) + 600)))
        }
        health.save(samples) { ok, error in print("health save steps \(ok) \((error as? HKError)?.code.rawValue ?? 0)") }
        let w = HKQuantitySample(type: weight, quantity: HKQuantity(unit: .pound(), doubleValue: 154.32), start: now, end: now)
        health.save(w) { ok, error in print("health save weight \(ok) \((error as? HKError)?.code.rawValue ?? 0)") }
    }
    func queryHealth() {
        let today = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400)
        let pred = HKQuery.predicateForSamples(withStart: today, end: Date(), options: .strictStartDate)
        let stats = HKStatisticsQuery(quantityType: steps, quantitySamplePredicate: pred, options: .cumulativeSum) { _, result, error in
            let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? -1
            print("health steps sum \(Int(sum))")
            DispatchQueue.main.async { self.healthText = "\(Int(sum)) steps" }
        }
        health.execute(stats)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: weight, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            if let s = samples?.first as? HKQuantitySample {
                print(String(format: "health weight %.1f kg from %@", s.quantity.doubleValue(for: .gramUnit(with: .kilo)), s.sourceRevision.source.name))
            } else { print("health weight none") }
        }
        health.execute(q)
    }
}

struct ContentView: View {
    @ObservedObject var model: SensorModel
    var body: some View {
        NavigationStack {
            List {
                Section("Core Motion") {
                    Text(model.motionText).accessibilityIdentifier("motionText")
                    Button("Start Motion") { model.startMotion() }.accessibilityIdentifier("motion")
                }
                Section("Bluetooth & NFC") {
                    Text("Bluetooth: \(model.bluetooth)").accessibilityIdentifier("bluetoothText")
                    Button("Start Bluetooth") { model.startBluetooth() }.accessibilityIdentifier("bluetooth")
                    Button("Scan NFC Tag") { model.startNFC() }.accessibilityIdentifier("nfc")
                }
                Section("Health") {
                    Text(model.healthText).accessibilityIdentifier("healthText")
                    Button("Connect to Health") { model.requestHealth() }.accessibilityIdentifier("healthAuth")
                    Button("Save Steps & Weight") { model.saveSteps() }.accessibilityIdentifier("healthSave")
                    Button("Read Health Data") { model.queryHealth() }.accessibilityIdentifier("healthQuery")
                }
            }
            .navigationTitle("Sensors")
        }
    }
}
