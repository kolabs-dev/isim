// Sample: device sensors and health data on isim — Core Motion (a simulated iPhone held upright at rest; no
// pedometer, headphone motion, batched sensors, sensor recorder, absolute altitude or water submersion, like the
// Simulator), Core Bluetooth (unsupported, like the Simulator), Core NFC (no reader) and
// HealthKit (the Health Access sheet, saving samples, statistics and sample queries, anchored object queries and
// their descriptors, source queries, background delivery; with -profile the Health profile's characteristics, activity
// summaries, blood pressure and food correlations and, from iOS 18, states of mind: issue #419).
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
                         NFCTagReaderSessionDelegate, NFCVASReaderSessionDelegate, CMHeadphoneMotionManagerDelegate,
                         CMWaterSubmersionManagerDelegate {
    let motion = CMMotionManager()
    let headphones = CMHeadphoneMotionManager()
    let water = CMWaterSubmersionManager()
    let recorder = CMSensorRecorder()
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
        motionExtras()
    }

    /// issue #414: the sensors the Simulator lacks answer "not available"
    func motionExtras() {
        CMAltimeter().startAbsoluteAltitudeUpdates(to: .main) { data, error in
            print("absolute altitude \(data.map { "\($0.altitude)" } ?? "nil") error \((error as? CMError)?.code.rawValue ?? 0) available \(CMAltimeter.isAbsoluteAltitudeAvailable())")
        }
        headphones.delegate = self
        headphones.startConnectionStatusUpdates()
        print("headphones motion \(headphones.isDeviceMotionAvailable) connection \(headphones.isConnectionStatusActive) status \(CMHeadphoneMotionManager.authorizationStatus().rawValue)")
        let list = recorder.accelerometerData(from: Date().addingTimeInterval(-60), to: Date())
        print("batched accelerometer \(CMBatchedSensorManager.isAccelerometerSupported) deviceMotion \(CMBatchedSensorManager.isDeviceMotionSupported) recorder \(CMSensorRecorder.isAccelerometerRecordingAvailable()) data \(list.map { "\(Array($0).count)" } ?? "nil") water \(CMWaterSubmersionManager.waterSubmersionAvailable) depth \(water.maximumDepth.map { "\($0)" } ?? "nil")")
        CMBatchedSensorManager().startDeviceMotionUpdates { batch, error in
            print("batched device motion \(batch.map { "\($0.count)" } ?? "nil") error \((error as? CMError)?.code.rawValue ?? 0)")
        }
        Task {
            do { for try await batch in CMBatchedSensorManager().accelerometerUpdates() { print("batched accelerometer batch \(batch.count)") } }
            catch { print("batched accelerometer updates error \((error as? CMError)?.code.rawValue ?? 0)") }
        }
        water.delegate = self
    }
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) { print("headphones connected") }
    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) { print("water event \(event.state.rawValue)") }
    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) { print("water depth") }
    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterTemperature) { print("water temperature") }
    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: any Error) {
        print("water submersion error \((error as? CMError)?.code.rawValue ?? 0)")
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
    /// what changed since an anchor: the first results, then a saved sample and its deletion as updates; the anchor
    /// archived; the sources; the Swift descriptors; background delivery
    var changes: HKAnchoredObjectQuery?
    func healthChanges() {
        let q = HKAnchoredObjectQuery(type: steps, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, added, deleted, anchor, error in
            print("health anchored added \(added?.count ?? -1) deleted \(deleted?.count ?? -1) error \(error == nil ? "none" : "\(error!)")")
            guard let anchor else { return }
            let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            let back = data.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
            print("health anchor archived equal \(back == anchor)")
            Task { await self.afterAnchor(anchor) }
        }
        q.updateHandler = { query, added, deleted, _, _ in
            print("health anchored update added \(added?.count ?? 0) deleted \(deleted?.count ?? 0)")
            if let s = added?.first { self.health.delete(s) { ok, _ in print("health deleted \(ok)") } }
            else if deleted?.isEmpty == false { self.health.stop(query) }
        }
        changes = q
        health.execute(q)
    }
    func afterAnchor(_ first: HKQueryAnchor) async {
        let sources: Set<HKSource> = await withCheckedContinuation { k in
            health.execute(HKSourceQuery(sampleType: steps, samplePredicate: nil) { _, s, _ in k.resume(returning: s ?? []) })
        }
        print("health sources \(sources.map(\.name).sorted().joined(separator: ","))")
        let named = (try? await HKSourceQueryDescriptor(predicate: .quantitySample(type: steps)).result(for: health)) ?? []
        print("health source descriptor \(named.map(\.name).joined(separator: ","))")
        let latest = HKSampleQueryDescriptor(predicates: [.quantitySample(type: steps)], sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 2)
        let two = (try? await latest.result(for: health)) ?? []
        print("health descriptor \(two.count) " + two.map { "\(Int($0.quantity.doubleValue(for: .count())))" }.joined(separator: " "))
        do {
            try await health.enableBackgroundDelivery(for: steps, frequency: .hourly)
            print("health background true")
        } catch { print("health background error \(error)") }
        // a sample saved, then deleted by the update handler
        let now = Date()
        try? await health.save(HKQuantitySample(type: steps, quantity: HKQuantity(unit: .count(), doubleValue: 100), start: now.addingTimeInterval(-60), end: now))
        // the deletion, seen from the first anchor once the update handler made it
        for _ in 0..<400 {
            let since = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: steps)], anchor: first)
            if let r = try? await since.result(for: health), !r.deletedObjects.isEmpty {
                print("health descriptor since added \(r.addedSamples.count) deleted \(r.deletedObjects.count) newer \(r.newAnchor != first)")
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        do {
            for try await r in HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: steps)], anchor: nil).results(for: health) {
                print("health sequence added \(r.addedSamples.count) deleted \(r.deletedObjects.count)")
                break
            }
        } catch { print("health sequence error \(error)") }
    }
}

// MARK: the Health profile, activity rings, correlations and states of mind (issue #419)
extension SensorModel {
    func healthProfile() async {
        let systolic = HKQuantityType(.bloodPressureSystolic), diastolic = HKQuantityType(.bloodPressureDiastolic)
        let kcal = HKQuantityType(.dietaryEnergyConsumed), protein = HKQuantityType(.dietaryProtein)
        let energy = HKQuantityType(.activeEnergyBurned), exercise = HKQuantityType(.appleExerciseTime), stand = HKCategoryType(.appleStandHour)
        var share: Set<HKSampleType> = [systolic, diastolic, kcal, protein, energy, exercise, stand]
        var read: Set<HKObjectType> = Set(share.map { $0 as HKObjectType })
        read.formUnion([HKCharacteristicType(.dateOfBirth), HKCharacteristicType(.biologicalSex), HKCharacteristicType(.bloodType),
                        HKCharacteristicType(.fitzpatrickSkinType), HKCharacteristicType(.wheelchairUse), HKCharacteristicType(.activityMoveMode),
                        HKObjectType.activitySummaryType()])
        if #available(iOS 18.0, *) { share.insert(HKObjectType.stateOfMindType()); read.insert(HKObjectType.stateOfMindType()) }
        do {
            try await health.requestAuthorization(toShare: [HKCorrelationType(.bloodPressure)], read: [])
        } catch { print("profile correlation authorization \((error as? HKError)?.code == .errorInvalidArgument ? "disallowed" : "\(error)")") }
        do { try await health.requestAuthorization(toShare: share, read: read) } catch { print("profile authorization error \(error)") }

        // characteristics: the device's Health profile (isim health profile)
        let born = (try? health.dateOfBirthComponents()).map { String(format: "%04d-%02d-%02d", $0.year ?? 0, $0.month ?? 0, $0.day ?? 0) } ?? "none"
        let sex = (try? health.biologicalSex().biologicalSex.rawValue) ?? -1, blood = (try? health.bloodType().bloodType) ?? .notSet
        let skin = (try? health.fitzpatrickSkinType().skinType) ?? .notSet, chair = (try? health.wheelchairUse().wheelchairUse) ?? .notSet
        let mode = (try? health.activityMoveMode().activityMoveMode) ?? .activeEnergy
        print("profile born \(born) sex \(sex) blood \(blood == .oPositive ? "O+" : "\(blood.rawValue)") skin \(skin == .III ? "III" : "\(skin.rawValue)") wheelchair \(chair == .no ? "no" : "\(chair.rawValue)") move \(mode == .activeEnergy ? "energy" : "time")")

        // today's activity: the rings from the day's samples
        let now = Date(), hourAgo = now.addingTimeInterval(-3600), minuteAgo = now.addingTimeInterval(-60)
        try? await health.save([
            HKQuantitySample(type: energy, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 180), start: minuteAgo, end: now),
            HKQuantitySample(type: exercise, quantity: HKQuantity(unit: .minute(), doubleValue: 25), start: minuteAgo, end: now),
            HKCategorySample(type: stand, value: HKCategoryValueAppleStandHour.stood.rawValue, start: minuteAgo, end: now),
        ])
        let today = Calendar.current.dateComponents([.era, .year, .month, .day], from: now)
        if let s = try? await HKActivitySummaryQueryDescriptor(predicate: HKQuery.predicateForActivitySummary(with: today)).result(for: health).first {
            print(String(format: "profile rings move %.0f/%.0f kcal exercise %.0f/%.0f min stand %.0f/%.0f h mode %d", s.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                         s.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()), s.appleExerciseTime.doubleValue(for: .minute()),
                         s.exerciseTimeGoal?.doubleValue(for: .minute()) ?? 0, s.appleStandHours.doubleValue(for: .count()),
                         s.standHoursGoal?.doubleValue(for: .count()) ?? 0, s.activityMoveMode.rawValue))
        } else { print("profile rings none") }
        // the rings follow new samples while the query runs
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in
            let rings = HKActivitySummaryQuery(predicate: HKQuery.predicateForActivitySummary(with: today)) { _, _, _ in k.resume() }
            rings.updateHandler = { q, s, _ in
                print(String(format: "profile rings update move %.0f", s?.first?.activeEnergyBurned.doubleValue(for: .kilocalorie()) ?? 0))
                self.health.stop(q)
            }
            health.execute(rings)
        }
        try? await health.save(HKQuantitySample(type: energy, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 70), start: now, end: now.addingTimeInterval(60)))

        // correlations: a blood pressure (saved with its two readings) and a meal
        let bp = HKCorrelation(type: HKCorrelationType(.bloodPressure), start: now, end: now, objects: [
            HKQuantitySample(type: systolic, quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 118), start: now, end: now),
            HKQuantitySample(type: diastolic, quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 76), start: now, end: now),
        ])
        let lunch = HKCorrelation(type: HKCorrelationType(.food), start: hourAgo, end: hourAgo, objects: [
            HKQuantitySample(type: kcal, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 640), start: hourAgo, end: hourAgo),
            HKQuantitySample(type: protein, quantity: HKQuantity(unit: .gram(), doubleValue: 32), start: hourAgo, end: hourAgo),
        ], metadata: ["HKFoodType": "Lunch"])
        do { try await health.save([bp, lunch]) } catch { print("profile correlation error \(error)") }
        let high = HKQuery.predicateForQuantitySamples(with: .greaterThan, quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 110))
        let found: [HKCorrelation] = await withCheckedContinuation { k in
            health.execute(HKCorrelationQuery(type: HKCorrelationType(.bloodPressure), predicate: nil, samplePredicates: [systolic: high]) { _, c, _ in k.resume(returning: c ?? []) })
        }
        if let c = found.first, let s = c.objects(for: systolic).first as? HKQuantitySample, let d = c.objects(for: diastolic).first as? HKQuantitySample {
            print(String(format: "profile blood pressure %.0f/%.0f objects %d", s.quantity.doubleValue(for: .millimeterOfMercury()),
                         d.quantity.doubleValue(for: .millimeterOfMercury()), c.objects.count))
        }
        let meals = (try? await HKSampleQueryDescriptor(predicates: [.correlation(type: HKCorrelationType(.food))], sortDescriptors: []).result(for: health)) ?? []
        let readings = (try? await HKSampleQueryDescriptor(predicates: [.quantitySample(type: systolic)], sortDescriptors: []).result(for: health)) ?? []
        print("profile meals \(meals.count) \(meals.first?.metadata?["HKFoodType"] as? String ?? "-") systolic readings \(readings.count)")
        if let c = found.first { try? await health.delete(c) }
        let after = (try? await HKSampleQueryDescriptor(predicates: [.quantitySample(type: systolic)], sortDescriptors: []).result(for: health)) ?? []
        print("profile deleted blood pressure: systolic readings \(after.count)")

        // states of mind (iOS 18)
        if #available(iOS 18.0, *) {
            let mood = HKStateOfMind(date: now, kind: .dailyMood, valence: 0.6, labels: [.happy, .grateful], associations: [.family, .fitness])
            let moment = HKStateOfMind(date: hourAgo, kind: .momentaryEmotion, valence: -0.4, labels: [.stressed], associations: [.work])
            do { try await health.save([mood, moment]) } catch { print("profile state of mind error \(error)") }
            let pleasant = HKQuery.predicateForStatesOfMind(withValence: 0, operatorType: .greaterThan)
            let family = HKQuery.predicateForStatesOfMind(with: HKStateOfMind.Association.family)
            let both = NSCompoundPredicate(andPredicateWithSubpredicates: [pleasant, family])
            let all = (try? await HKSampleQueryDescriptor(predicates: [.stateOfMind()], sortDescriptors: [SortDescriptor(\.startDate)]).result(for: health)) ?? []
            let happy = (try? await HKSampleQueryDescriptor(predicates: [.stateOfMind(both)], sortDescriptors: []).result(for: health)) ?? []
            let classes = all.map { "\($0.valenceClassification.rawValue)" }.joined(separator: ",")
            print("profile states of mind \(all.count) classes \(classes) pleasant-with-family \(happy.count) labels \(happy.first?.labels.count ?? 0) kind \(happy.first?.kind == .dailyMood ? "daily" : "-")")
        } else {
            print("profile states of mind need iOS 18")
        }
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
                    Button("Health Changes") { model.healthChanges() }.accessibilityIdentifier("healthChanges")
                }
            }
            .navigationTitle("Sensors")
            .task { if ProcessInfo.processInfo.arguments.contains("-profile") { await model.healthProfile() } }
        }
    }
}
