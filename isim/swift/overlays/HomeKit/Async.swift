// isim HomeKit: the async variants Swift's importer makes from Apple's completion-handler methods (Apple's HomeKit is
// Objective-C; isim's is Swift, so they are written out). Their names follow the importer's rules: addRoomWithName:
// becomes addRoom(named:), readValueWithCompletionHandler: becomes readValue().
import Foundation

private func _hm(_ body: (@escaping (Error?) -> Void) -> Void) async throws {
    try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
        body { e in if let e { c.resume(throwing: e) } else { c.resume() } }
    }
}
private func _hm<T>(_ body: (@escaping (T?, Error?) -> Void) -> Void) async throws -> T {
    try await withCheckedThrowingContinuation { (c: CheckedContinuation<T, Error>) in
        body { v, e in
            if let v { c.resume(returning: v) } else { c.resume(throwing: e ?? HMError(.unexpectedError)) }
        }
    }
}

extension HMHomeManager {
    public func addHome(named homeName: String) async throws -> HMHome { try await _hm { addHome(withName: homeName, completionHandler: $0) } }
    public func removeHome(_ home: HMHome) async throws { try await _hm { removeHome(home, completionHandler: $0) } }
    @available(iOS, introduced: 13.0, deprecated: 16.1, message: "No longer supported.")
    public func updatePrimaryHome(_ home: HMHome) async throws { try await _hm { updatePrimaryHome(home, completionHandler: $0) } }
    public func findVendorAccessory(hapPublicKey: Data) async throws -> HMAccessory {
        try await _hm { findVendorAccessory(hapPublicKey: hapPublicKey, completionHandler: $0) }
    }
}

extension HMHome {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
    public func manageUsers() async throws { try await _hm { manageUsers(completionHandler: $0) } }
    public func addAccessory(_ accessory: HMAccessory) async throws { try await _hm { addAccessory(accessory, completionHandler: $0) } }
    public func removeAccessory(_ accessory: HMAccessory) async throws { try await _hm { removeAccessory(accessory, completionHandler: $0) } }
    public func assignAccessory(_ accessory: HMAccessory, to room: HMRoom) async throws {
        try await _hm { assignAccessory(accessory, to: room, completionHandler: $0) }
    }
    public func unblockAccessory(_ accessory: HMAccessory) async throws { try await _hm { unblockAccessory(accessory, completionHandler: $0) } }
    @available(iOS, introduced: 13.0, deprecated: 15.4, message: "Use HMAccessorySetupManager.performAccessorySetup(using:)")
    public func addAndSetupAccessories() async throws { try await _hm { addAndSetupAccessories(completionHandler: $0) } }
    @available(iOS, introduced: 13.0, deprecated: 15.4, message: "Use HMAccessorySetupManager.performAccessorySetup(using:)")
    public func addAndSetupAccessories(with payload: HMAccessorySetupPayload) async throws -> [HMAccessory] {
        try await _hm { addAndSetupAccessories(with: payload, completionHandler: $0) }
    }
    public func addRoom(named roomName: String) async throws -> HMRoom { try await _hm { addRoom(withName: roomName, completionHandler: $0) } }
    public func removeRoom(_ room: HMRoom) async throws { try await _hm { removeRoom(room, completionHandler: $0) } }
    public func addZone(named zoneName: String) async throws -> HMZone { try await _hm { addZone(withName: zoneName, completionHandler: $0) } }
    public func removeZone(_ zone: HMZone) async throws { try await _hm { removeZone(zone, completionHandler: $0) } }
    public func addServiceGroup(named serviceGroupName: String) async throws -> HMServiceGroup {
        try await _hm { addServiceGroup(withName: serviceGroupName, completionHandler: $0) }
    }
    public func removeServiceGroup(_ group: HMServiceGroup) async throws { try await _hm { removeServiceGroup(group, completionHandler: $0) } }
    public func addActionSet(named actionSetName: String) async throws -> HMActionSet {
        try await _hm { addActionSet(withName: actionSetName, completionHandler: $0) }
    }
    public func removeActionSet(_ actionSet: HMActionSet) async throws { try await _hm { removeActionSet(actionSet, completionHandler: $0) } }
    public func executeActionSet(_ actionSet: HMActionSet) async throws { try await _hm { executeActionSet(actionSet, completionHandler: $0) } }
    public func addTrigger(_ trigger: HMTrigger) async throws { try await _hm { addTrigger(trigger, completionHandler: $0) } }
    public func removeTrigger(_ trigger: HMTrigger) async throws { try await _hm { removeTrigger(trigger, completionHandler: $0) } }
}

extension HMRoom {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
}
extension HMZone {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
    public func addRoom(_ room: HMRoom) async throws { try await _hm { addRoom(room, completionHandler: $0) } }
    public func removeRoom(_ room: HMRoom) async throws { try await _hm { removeRoom(room, completionHandler: $0) } }
}
extension HMServiceGroup {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
    public func addService(_ service: HMService) async throws { try await _hm { addService(service, completionHandler: $0) } }
    public func removeService(_ service: HMService) async throws { try await _hm { removeService(service, completionHandler: $0) } }
}

extension HMAccessory {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
    public func identify() async throws { try await _hm { identify(completionHandler: $0) } }
}
extension HMService {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
    public func updateAssociatedServiceType(_ serviceType: String?) async throws {
        try await _hm { updateAssociatedServiceType(serviceType, completionHandler: $0) }
    }
}
extension HMCharacteristic {
    public func writeValue(_ value: Any?) async throws { try await _hm { writeValue(value, completionHandler: $0) } }
    public func readValue() async throws { try await _hm { readValue(completionHandler: $0) } }
    public func enableNotification(_ enable: Bool) async throws { try await _hm { enableNotification(enable, completionHandler: $0) } }
    public func updateAuthorizationData(_ data: Data?) async throws { try await _hm { updateAuthorizationData(data, completionHandler: $0) } }
}

extension HMAccessorySetupManager {
    public func performAccessorySetup(using request: HMAccessorySetupRequest) async throws -> HMAccessorySetupResult {
        try await _hm { performAccessorySetup(using: request, completionHandler: $0) }
    }
}

extension HMActionSet {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
    public func addAction(_ action: HMAction) async throws { try await _hm { addAction(action, completionHandler: $0) } }
    public func removeAction(_ action: HMAction) async throws { try await _hm { removeAction(action, completionHandler: $0) } }
}
extension HMCharacteristicWriteAction {
    public func updateTargetValue(_ targetValue: TargetValueType) async throws { try await _hm { updateTargetValue(targetValue, completionHandler: $0) } }
}
extension HMTrigger {
    public func updateName(_ name: String) async throws { try await _hm { updateName(name, completionHandler: $0) } }
    public func addActionSet(_ actionSet: HMActionSet) async throws { try await _hm { addActionSet(actionSet, completionHandler: $0) } }
    public func removeActionSet(_ actionSet: HMActionSet) async throws { try await _hm { removeActionSet(actionSet, completionHandler: $0) } }
    public func enable(_ enable: Bool) async throws { try await _hm { self.enable(enable, completionHandler: $0) } }
}
extension HMTimerTrigger {
    public func updateFireDate(_ fireDate: Date) async throws { try await _hm { updateFireDate(fireDate, completionHandler: $0) } }
    public func updateRecurrence(_ recurrence: DateComponents?) async throws { try await _hm { updateRecurrence(recurrence, completionHandler: $0) } }
}
extension HMEventTrigger {
    public func updateEvents(_ events: [HMEvent]) async throws { try await _hm { updateEvents(events, completionHandler: $0) } }
    public func updateEndEvents(_ endEvents: [HMEvent]) async throws { try await _hm { updateEndEvents(endEvents, completionHandler: $0) } }
    public func updatePredicate(_ predicate: NSPredicate?) async throws { try await _hm { updatePredicate(predicate, completionHandler: $0) } }
    public func updateRecurrences(_ recurrences: [DateComponents]?) async throws { try await _hm { updateRecurrences(recurrences, completionHandler: $0) } }
    public func updateExecuteOnce(_ executeOnce: Bool) async throws { try await _hm { updateExecuteOnce(executeOnce, completionHandler: $0) } }
}
extension HMCameraStream {
    public func updateAudioStreamSetting(_ audioStreamSetting: HMCameraAudioStreamSetting) async throws {
        try await _hm { updateAudioStreamSetting(audioStreamSetting, completionHandler: $0) }
    }
}
