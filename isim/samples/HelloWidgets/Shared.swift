// HelloWidgets: code shared by the app and its widget extension (both targets compile this file, like Xcode).
import Foundation
import AppIntents
import ActivityKit

let appGroup = "group.dev.isim.samples.hellowidgets"
var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroup)! }
var sharedCount: Int {
    get { sharedDefaults.integer(forKey: "count") }
    set { sharedDefaults.set(newValue, forKey: "count") }
}

/// the interactive widget's button runs this (in the widget extension's process)
struct IncrementIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment"
    static var description: IntentDescription? = "Adds one to the shared counter"
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog {
        sharedCount += 1
        return .result(dialog: "Count is \(sharedCount)")
    }
}

struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var minutes: Int; var status: String }
    var orderNumber: String
}
