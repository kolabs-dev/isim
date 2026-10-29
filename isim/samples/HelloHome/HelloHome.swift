// Sample: HomeKit on isim (issue #416). A small home app over the device's simulated home (`isim home seed`): the
// rooms and accessories with their switches, the doorbell camera's live view, a scene and an automation. Launched with
// `-check` it also goes through the API and prints what it sees (tests/ui/test_homekit.py): reads and writes, HomeKit's
// errors, notifications, the simulated lock and garage door, rooms and zones, scenes, triggers, finding and adding
// accessories, the camera's stream and snapshot.
import SwiftUI
import HomeKit

@main
struct HelloHomeApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

func say(_ s: String) { print("home: \(s)") }

func code(_ e: Error?) -> String {
    guard let e = e as NSError? else { return "nil" }
    return e.domain == HMError.errorDomain ? "\(HMError.Code(rawValue: e.code).map { "\($0)" } ?? "\(e.code)")" : "\(e.domain)/\(e.code)"
}

@MainActor
final class Home: NSObject, ObservableObject, HMHomeManagerDelegate, HMHomeDelegate, HMAccessoryDelegate, HMAccessoryBrowserDelegate,
                  HMCameraStreamControlDelegate, HMCameraSnapshotControlDelegate {
    let manager = HMHomeManager()
    let browser = HMAccessoryBrowser()
    @Published var home: HMHome?
    @Published var stream: HMCameraStream?
    @Published var tick = 0
    var checked = false

    override init() {
        super.init()
        manager.delegate = self
        browser.delegate = self
    }

    // MARK: delegates

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        MainActor.assumeIsolated { loaded() }
    }
    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        MainActor.assumeIsolated { say("authorization \(status.contains(.authorized) ? "authorized" : status.contains(.determined) ? "denied" : "not determined")") }
    }
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        MainActor.assumeIsolated {
            say("updated \(accessory.name) \(characteristic.localizedDescription) = \(characteristic.value.map { "\($0)" } ?? "nil")")
            tick += 1
        }
    }
    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        MainActor.assumeIsolated { say("reachability \(accessory.name) \(accessory.isReachable)"); tick += 1 }
    }
    nonisolated func home(_ home: HMHome, didAdd accessory: HMAccessory) {
        MainActor.assumeIsolated { say("delegate added \(accessory.name)") }
    }
    nonisolated func accessoryBrowser(_ browser: HMAccessoryBrowser, didFindNewAccessory accessory: HMAccessory) {
        MainActor.assumeIsolated { say("found \(accessory.name) home=\(accessory.room == nil ? "none" : "?")") }
    }
    nonisolated func cameraStreamControlDidStartStream(_ c: HMCameraStreamControl) {
        MainActor.assumeIsolated {
            say("camera streaming state=\(c.streamState == .streaming ? "streaming" : "?") aspect=\(String(format: "%.2f", c.cameraStream?.aspectRatio ?? 0))")
            stream = c.cameraStream
        }
    }
    nonisolated func cameraSnapshotControl(_ c: HMCameraSnapshotControl, didTake snapshot: HMCameraSnapshot?, error: Error?) {
        MainActor.assumeIsolated { say("camera snapshot \(snapshot != nil ? 1 : 0) error=\(code(error)) recent=\(c.mostRecentSnapshot === snapshot ? 1 : 0)") }
    }

    // MARK: the home

    func loaded() {
        let homes = manager.homes
        say("homes \(homes.count) status=\(manager.authorizationStatus.rawValue)")
        guard let home = homes.first(where: { $0.isPrimary }) ?? homes.first else {
            manager.addHome(withName: "My Home") { home, error in say("add home error=\(code(error))") }
            return
        }
        self.home = home
        home.delegate = self
        for a in home.accessories {
            a.delegate = self
            for s in a.services { for c in s.characteristics where c.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                c.enableNotification(true) { _ in }
            } }
        }
        if let camera = accessory("Doorbell Camera")?.cameraProfiles?.first {
            camera.streamControl?.delegate = self
            camera.streamControl?.startStream()
        }
        if !checked, ProcessInfo.processInfo.arguments.contains("-check") {
            checked = true
            Task { await check(home) }
        }
    }

    func accessory(_ name: String) -> HMAccessory? { home?.accessories.first { $0.name == name } }
    func characteristic(_ accessory: String, _ type: String) -> HMCharacteristic? {
        self.accessory(accessory)?.services.flatMap(\.characteristics).first { $0.characteristicType == type }
    }

    func toggle(_ c: HMCharacteristic) {
        let on = !((c.value as? Bool) ?? false)
        c.writeValue(on) { error in say("toggled \(c.service?.name ?? "") \(on ? 1 : 0) error=\(code(error))"); self.tick += 1 }
    }

    // MARK: the API check

    func check(_ home: HMHome) async {
        let rooms = home.rooms.map(\.name).sorted().joined(separator: ",")
        say("home \(home.name) primary=\(home.isPrimary) hub=\(home.homeHubState == .connected ? "connected" : "none") rooms=\(rooms) zones=\(home.zones.map { "\($0.name):\($0.rooms.count)" }.joined(separator: ","))")
        say("accessories \(home.accessories.count) user=\(home.currentUser.name) admin=\(home.homeAccessControl(for: home.currentUser).isAdministrator)")
        let lamp = accessory("Living Room Lamp")!
        let bulb = lamp.services.first { $0.serviceType == HMServiceTypeLightbulb }!
        say("lamp room=\(lamp.room?.name ?? "-") category=\(lamp.category.localizedDescription) service=\(bulb.localizedDescription) primary=\(bulb.isPrimaryService) "
            + "characteristics=\(bulb.characteristics.map(\.localizedDescription).joined(separator: ","))")
        let brightness = bulb.characteristics.first { $0.characteristicType == HMCharacteristicTypeBrightness }!
        let meta = brightness.metadata!
        say("brightness \(brightness.value ?? "nil") format=\(meta.format ?? "-") units=\(meta.units ?? "-") range=\(meta.minimumValue ?? 0)...\(meta.maximumValue ?? 0) "
            + "writable=\(brightness.properties.contains(HMCharacteristicPropertyWritable))")

        // writes and HomeKit's checks
        do {
            try await brightness.writeValue(55)
            try await brightness.readValue()
            say("wrote brightness \(brightness.value ?? "nil")")
        } catch { say("write error \(code(error))") }
        do { try await brightness.writeValue(150) } catch { say("too bright \(code(error))") }
        do { try await brightness.writeValue("dim") } catch { say("wrong type \(code(error))") }
        let temperature = characteristic("Thermostat", HMCharacteristicTypeCurrentTemperature)!
        do { try await temperature.writeValue(30) } catch { say("read-only \(code(error))") }

        // the simulated accessories: the lock follows its target, the garage door opens through `opening`
        let lockTarget = characteristic("Front Door", HMCharacteristicTypeTargetLockMechanismState)!
        try? await lockTarget.writeValue(HMCharacteristicValueTargetLockMechanismState.unsecured.rawValue)
        say("unlocking front door")
        let doorTarget = characteristic("Garage Door", HMCharacteristicTypeTargetDoorState)!
        try? await doorTarget.writeValue(HMCharacteristicValueTargetDoorState.open.rawValue)
        say("opening garage door current=\(characteristic("Garage Door", HMCharacteristicTypeCurrentDoorState)?.value ?? "nil")")

        // rooms, zones and service groups
        do {
            let office = try await home.addRoom(named: "Office")
            let outlet = accessory("Kitchen Outlet")!
            try await home.assignAccessory(outlet, to: office)
            try await office.updateName("Study")
            say("room \(office.name) accessories=\(office.accessories.map(\.name).joined(separator: ","))")
            do { _ = try await home.addRoom(named: "Study") } catch { say("same room \(code(error))") }
            let zone = home.zones.first!
            try await zone.addRoom(office)
            say("zone \(zone.name) rooms=\(zone.rooms.map(\.name).sorted().joined(separator: ","))")
            try await zone.removeRoom(office)
            try await home.assignAccessory(outlet, to: home.rooms.first { $0.name == "Kitchen" }!)
            try await home.removeRoom(office)
            let group = try await home.addServiceGroup(named: "Lights")
            try await group.addService(bulb)
            say("group \(group.name) services=\(group.services.count)")
            try await home.removeServiceGroup(group)
            say("rooms again \(home.rooms.count)")
        } catch { say("rooms error \(code(error))") }

        // a scene
        do {
            let scene = try await home.addActionSet(named: "Movie Night")
            let power = bulb.characteristics.first { $0.characteristicType == HMCharacteristicTypePowerState }!
            try await scene.addAction(HMCharacteristicWriteAction(characteristic: power, targetValue: true as NSNumber))
            try await scene.addAction(HMCharacteristicWriteAction(characteristic: brightness, targetValue: 20 as NSNumber))
            do { try await scene.addAction(HMCharacteristicWriteAction(characteristic: brightness, targetValue: 30 as NSNumber)) } catch { say("same characteristic \(code(error))") }
            try await home.executeActionSet(scene)
            say("scene \(scene.name) actions=\(scene.actions.count) type=\(scene.actionSetType == HMActionSetTypeUserDefined ? "user" : "?") "
                + "lamp=\(power.value ?? "nil") brightness=\(brightness.value ?? "nil") ran=\(scene.lastExecutionDate != nil)")
            say("builtin \(home.builtinActionSet(ofType: HMActionSetTypeSleep)?.name ?? "-")")

            // automations: motion in the hallway runs the scene; a timer trigger tomorrow
            let motion = characteristic("Hallway Sensor", HMCharacteristicTypeMotionDetected)!
            let event = HMCharacteristicEvent(characteristic: motion, triggerValue: true as NSNumber)
            let night = HMEventTrigger(name: "Hallway Motion", events: [event], predicate: nil)
            try await home.addTrigger(night)
            try await night.addActionSet(scene)
            try await night.enable(true)
            say("automation \(night.name) enabled=\(night.isEnabled) state=\(night.triggerActivationState == .enabled ? "enabled" : "?") events=\(night.events.count)")
            try await power.writeValue(false)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let timer = HMTimerTrigger(name: "Morning", fireDate: tomorrow, recurrence: DateComponents(day: 1))
            try await home.addTrigger(timer)
            say("timer \(timer.name) recurrence=\(timer.recurrence?.day ?? 0) enabled=\(timer.isEnabled)")
            do { try await timer.enable(true) } catch { say("empty timer \(code(error))") }
            try await home.removeTrigger(timer)
            say("triggers \(home.triggers.map(\.name).joined(separator: ","))")
        } catch { say("scene error \(code(error))") }

        // accessories nearby: the browser, then the setup sheet with a setup code
        browser.startSearchingForNewAccessories()
        try? await Task.sleep(nanoseconds: 600_000_000)
        say("nearby \(browser.discoveredAccessories.map(\.name).sorted().joined(separator: ","))")
        if let fan = browser.discoveredAccessories.first(where: { $0.name == "Ceiling Fan" }) {
            do {
                try await home.addAccessory(fan)
                say("added \(fan.name) home=\(home.accessories.contains(fan)) services=\(fan.services.count)")
                try await home.removeAccessory(fan)
            } catch { say("add error \(code(error))") }
        }
        browser.stopSearchingForNewAccessories()
        let request = HMAccessorySetupRequest()
        request.payload = HMAccessorySetupPayload(url: URL(string: "X-HM://0026ACWIN"))
        request.homeUniqueIdentifier = home.uniqueIdentifier
        request.suggestedAccessoryName = "Study Window"
        do {
            let result = try await HMAccessorySetupManager().performAccessorySetup(using: request)
            let added = home.accessories.first { result.accessoryUniqueIdentifiers.contains($0.uniqueIdentifier) }
            say("setup \(result.accessoryUniqueIdentifiers.count) \(added?.name ?? "-") home=\(result.homeUniqueIdentifier == home.uniqueIdentifier)")
            if let added { try await home.removeAccessory(added) }
        } catch { say("setup error \(code(error))") }
        say("bad payload \(HMAccessorySetupPayload(url: URL(string: "https://example.com")) == nil ? "nil" : "?")")

        // the camera
        if let snapshot = accessory("Doorbell Camera")?.cameraProfiles?.first?.snapshotControl {
            snapshot.delegate = self
            snapshot.takeSnapshot()
        }
        say("check done")
    }
}

struct ContentView: View {
    @StateObject private var model = Home()
    var body: some View {
        NavigationStack {
            List {
                if let stream = model.stream {
                    Section("Doorbell Camera") {
                        CameraView(source: stream).aspectRatio(16 / 9, contentMode: .fit).listRowInsets(EdgeInsets())
                            .accessibilityIdentifier("camera")
                    }
                }
                if let home = model.home {
                    ForEach(home.rooms.sorted { $0.name < $1.name }, id: \.uniqueIdentifier) { room in
                        if !room.accessories.isEmpty {
                            Section(room.name) {
                                ForEach(room.accessories, id: \.uniqueIdentifier) { AccessoryRow(model: model, accessory: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(model.home?.name ?? "Home")
            .id(model.tick)
        }
    }
}

struct AccessoryRow: View {
    @ObservedObject var model: Home
    let accessory: HMAccessory
    var power: HMCharacteristic? {
        accessory.services.flatMap(\.characteristics).first { $0.characteristicType == HMCharacteristicTypePowerState }
    }
    var status: String {
        let all = accessory.services.flatMap(\.characteristics)
        func v(_ t: String) -> Int? { (all.first { $0.characteristicType == t }?.value as? NSNumber).map { Int(truncating: $0) } }
        if !accessory.isReachable { return "No Response" }
        if let s = v(HMCharacteristicTypeCurrentLockMechanismState) { return s == 1 ? "Locked" : s == 0 ? "Unlocked" : "Jammed" }
        if let s = v(HMCharacteristicTypeCurrentDoorState) { return ["Open", "Closed", "Opening", "Closing", "Stopped"][min(s, 4)] }
        if let t = all.first(where: { $0.characteristicType == HMCharacteristicTypeCurrentTemperature })?.value as? NSNumber {
            return String(format: "%.1f°", t.doubleValue)
        }
        if let m = v(HMCharacteristicTypeMotionDetected) { return m == 1 ? "Motion Detected" : "No Motion" }
        if let p = v(HMCharacteristicTypeCurrentPosition) { return "\(p)% Open" }
        if let on = v(HMCharacteristicTypePowerState) { return on == 1 ? "On" : "Off" }
        return accessory.category.localizedDescription
    }
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(accessory.name)
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if let power {
                Toggle("", isOn: Binding(get: { (power.value as? Bool) ?? false }, set: { _ in model.toggle(power) }))
                    .labelsHidden().accessibilityIdentifier("power-\(accessory.name)")
            }
        }
    }
}
