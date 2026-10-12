// HelloFocusControls: code shared by the app and its widget extension (both targets compile this file, like Xcode).
import Foundation
import AppIntents

let appGroup = "group.dev.isim.samples.hellofocuscontrols"
var shared: UserDefaults { UserDefaults(suiteName: appGroup)! }
var lampOn: Bool {
    get { shared.bool(forKey: "lampOn") }
    set { shared.set(newValue, forKey: "lampOn") }
}
var tapCount: Int {
    get { shared.integer(forKey: "taps") }
    set { shared.set(newValue, forKey: "taps") }
}

/// the lamp control's toggle (Control Center runs it in the extension with the new value)
struct SetLampIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Set Lamp"
    @Parameter(title: "Lamp On", default: false) var value: Bool
    init() {}
    func perform() async throws -> some IntentResult {
        lampOn = value
        NSLog("HelloFocusControls: lamp %@", value ? "on" : "off")
        return .result()
    }
}
/// the counter control's button
struct CountIntent: AppIntent {
    static var title: LocalizedStringResource = "Count"
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog {
        tapCount += 1
        NSLog("HelloFocusControls: count %ld", tapCount)
        return .result(dialog: "Count is \(tapCount)")
    }
}
