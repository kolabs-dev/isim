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

final class SensorModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, NFCNDEFReaderSessionDelegate,
                         NFCTagReaderSessionDelegate, NFCVASReaderSessionDelegate {
    let motion = CMMotionManager()
    let health = HKHealthStore()
    var central: CBCentralManager?
    var nfc: NFCNDEFReaderSession?
    var peripheral: CBPeripheralManager?
    var tagSession: NFCTagReaderSession?
    var vasSession: NFCVASReaderSession?
    @Published var motionText = "—"
    @Published var bluetooth = "—"
    @Published var healthText = "—"
    var ticks = 0

    func startMotion() {
        print("motion available accel \(motion.isAccelerometerAvailable) gyro \(motion.isGyroAvailable) magnetometer \(motion.isMagnetometerAvailable) deviceMotion \(motion.isDeviceMotionAvailable)")
        print("motion frames \(CMMotionManager.availableAttitudeReferenceFrames().rawValue)")
        print("pedometer steps \(CMPedometer.isStepCountingAvailable()) distance \(CMPedometer.isDistanceAvailable()) floors \(CMPedometer.isFloorCountingAvailable()) pace \(CMPedometer.isPaceAvailable()) cadence \(CMPedometer.isCadenceAvailable()) events \(CMPedometer.isPedometerEventTrackingAvailable()) activity \(CMMotionActivityManager.isActivityAvailable()) altimeter \(CMAltimeter.isRelativeAltitudeAvailable())")
        guard motion.isAccelerometerAvailable else { motionText = "No motion sensors"; return }
        motion.accelerometerUpdateInterval = 0.1
        ticks = 0
        motion.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data?.acceleration else { return }
            self.ticks += 1
            if self.ticks == 3 {
                let pull = self.motion.accelerometerData?.acceleration ?? CMAcceleration()
                print(String(format: "accel %.2f %.2f %.2f pull %.2f %.2f %.2f after %d updates", a.x, a.y, a.z, pull.x, pull.y, pull.z, self.ticks))
                self.motion.stopAccelerometerUpdates()
            }
        }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { m, _ in
            guard let m else { return }
            let pull = self.motion.deviceMotion
            print(String(format: "deviceMotion gravity %.2f %.2f %.2f user %.2f pitch %.2f roll %.2f pull %.2f heading %.0f", m.gravity.x, m.gravity.y, m.gravity.z,
                         m.userAcceleration.x + m.userAcceleration.y + m.userAcceleration.z, m.attitude.pitch, m.attitude.roll, pull?.gravity.y ?? 0, m.heading))
            self.motionText = String(format: "gravity %.0f, %.0f, %.0f", m.gravity.x, m.gravity.y, m.gravity.z)
            self.motion.stopDeviceMotionUpdates()
        }
        motion.startGyroUpdates()
        motion.magnetometerUpdateInterval = 0.1
        motion.startMagnetometerUpdates(to: .main) { data, _ in
            guard let field = data?.magneticField, let pull = self.motion.magnetometerData?.magneticField else { return }
            print(String(format: "magnetometer %.1f %.1f %.1f pull %.1f %.1f %.1f", field.x, field.y, field.z, pull.x, pull.y, pull.z))
            self.motion.stopMagnetometerUpdates()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let g = self.motion.gyroData?.rotationRate { print(String(format: "gyro %.2f %.2f %.2f active %@", g.x, g.y, g.z, self.motion.isGyroActive ? "yes" : "no")) }
            self.motion.stopGyroUpdates()
        }
        CMPedometer().queryPedometerData(from: Date().addingTimeInterval(-3600), to: Date()) { data, error in
            print("pedometer query error \((error as? CMError)?.code.rawValue ?? 0)")
        }
        CMMotionActivityManager().queryActivityStarting(from: Date().addingTimeInterval(-3600), to: Date(), to: .main) { _, error in
            print("activity query error \((error as? CMError)?.code.rawValue ?? 0)")
        }
        CMAltimeter().startRelativeAltitudeUpdates(to: .main) { _, error in
            print("altimeter update error \((error as? CMError)?.code.rawValue ?? 0)")
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

    // the peripheral role: a heart-rate service the app would publish and advertise
    func startPeripheral() { peripheral = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: false]) }
    func peripheralManagerDidUpdateState(_ p: CBPeripheralManager) {
        let names = ["unknown", "resetting", "unsupported", "unauthorized", "poweredOff", "poweredOn"]
        let rate = CBMutableCharacteristic(type: CBUUID(string: "2A37"), properties: [.read, .notify], value: nil, permissions: [.readable])
        rate.descriptors = [CBMutableDescriptor(type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString), value: "Heart rate")]
        let service = CBMutableService(type: CBUUID(string: "180D"), primary: true)
        service.characteristics = [rate]
        print("peripheral state \(names[p.state.rawValue]) service \(service.uuid) primary \(service.isPrimary) characteristics \(service.characteristics?.count ?? 0) descriptor \(rate.descriptors?.first?.value as? String ?? "-") linked \(rate.service === service)")
        p.add(service)
        p.startAdvertising([CBAdvertisementDataLocalNameKey: "Sensors", CBAdvertisementDataServiceUUIDsKey: [service.uuid]])
        let sent = p.updateValue(Data([0, 72]), for: rate, onSubscribedCentrals: nil)
        print("peripheral advertising \(p.isAdvertising) sent \(sent) attError \(CBATTError(.readNotPermitted).errorCode) \(CBATTError.errorDomain)")
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        request.value = Data([0, 72])
        peripheral.respond(to: request, withResult: .success)
    }

    // MARK: NFC
    func startTagReader() {
        print("nfc tags readingAvailable \(NFCTagReaderSession.readingAvailable) vas \(NFCVASReaderSession.readingAvailable)")
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near a card"
        tagSession?.begin()
        let loyalty = NFCVASCommandConfiguration(vasMode: .normal, passTypeIdentifier: "pass.dev.isim.loyalty", url: nil)
        vasSession = NFCVASReaderSession(vasCommandConfigurations: [loyalty], delegate: self, queue: nil)
        vasSession?.begin()
        let select = NFCISO7816APDU(data: Data([0x00, 0xA4, 0x04, 0x00, 0x02, 0x3F, 0x00, 0x00]))
        print("nfc apdu ins \(select.map { String(format: "%02X", $0.instructionCode) } ?? "-") data \(select?.data?.count ?? 0) le \(select?.expectedResponseLength ?? 0)")
    }
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) { print("nfc tag session active") }
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("nfc tag session invalidated \((error as? NFCReaderError)?.code.rawValue ?? -1)")
    }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { error in
            guard error == nil, case .iso7816(let card) = tag else { return }
            card.sendCommand(apdu: NFCISO7816APDU(instructionClass: 0, instructionCode: 0xB0, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 16)) { data, sw1, sw2, _ in
                print("nfc read \(data.count) bytes status \(sw1) \(sw2)")
            }
        }
    }
    func readerSession(_ session: NFCVASReaderSession, didInvalidateWithError error: Error) {
        print("nfc vas session invalidated \((error as? NFCReaderError)?.code.rawValue ?? -1)")
    }
    func readerSession(_ session: NFCVASReaderSession, didReceive responses: [NFCVASResponse]) { print("nfc vas \(responses.count)") }
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
                    Button("Start Peripheral") { model.startPeripheral() }.accessibilityIdentifier("peripheral")
                    Button("Read Cards and Passes") { model.startTagReader() }.accessibilityIdentifier("nfcTags")
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
