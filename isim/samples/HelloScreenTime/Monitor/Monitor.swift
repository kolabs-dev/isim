// The sample's Device Activity Monitor extension: it logs each callback ("stm ..."), and when the "limit" event's
// apps reach their time it shields them (the app's store "limits"); the interval's end lifts the shield.
import Foundation
import DeviceActivity
import ManagedSettings

func log(_ s: String) { print("stm \(s)"); fflush(stdout) }

final class Monitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore(named: .init("limits"))
    override func intervalDidStart(for activity: DeviceActivityName) { log("intervalDidStart \(activity.rawValue)") }
    override func intervalWillStartWarning(for activity: DeviceActivityName) { log("intervalWillStartWarning \(activity.rawValue)") }
    override func intervalWillEndWarning(for activity: DeviceActivityName) { log("intervalWillEndWarning \(activity.rawValue)") }
    override func intervalDidEnd(for activity: DeviceActivityName) {
        store.clearAllSettings()
        log("intervalDidEnd \(activity.rawValue): shields lifted")
    }
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        log("eventWillReachThresholdWarning \(event.rawValue) \(activity.rawValue)")
    }
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        let apps = DeviceActivityCenter().events(for: activity)[event]?.applications ?? []
        store.shield.applications = apps
        let names = apps.compactMap { Application(token: $0).bundleIdentifier }.sorted()
        log("eventDidReachThreshold \(event.rawValue) \(activity.rawValue): shielding \(names.joined(separator: ","))")
    }
}
