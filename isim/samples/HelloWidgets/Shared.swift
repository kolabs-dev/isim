// HelloWidgets: code shared by the app and its widget extension (both targets compile this file, like Xcode).
import Foundation
import AppIntents
import ActivityKit
import Intents

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

/// the weather widget's configuration (AppIntentConfiguration): Edit Widget shows these parameters
enum City: String, AppEnum {
    case cupertino, paris, tokyo
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    static var caseDisplayRepresentations: [City: DisplayRepresentation] = [.cupertino: "Cupertino", .paris: "Paris", .tokyo: "Tokyo"]
    var name: String { rawValue.capitalized }
    var temperature: Int { switch self { case .cupertino: return 21; case .paris: return 14; case .tokyo: return 26 } }
}
struct WeatherIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Weather"
    static var description: IntentDescription? = "The weather in a city"
    @Parameter(title: "City", default: .cupertino) var city: City
    @Parameter(title: "Show Feels Like", default: false) var feelsLike: Bool
    init() {}
}

struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var minutes: Int; var status: String }
    var orderNumber: String
}

/// the theme widget's configuration (IntentConfiguration): a SiriKit custom intent from Extension/Theme.intentdefinition,
/// the classes Xcode generates from it
@objc public enum ThemeColor: Int {
    case unknown = 0, sunrise = 1, forest = 2, ocean = 3
}
@objc(ThemeIntent)
public class ThemeIntent: INIntent {
    @NSManaged public var color: ThemeColor
    @NSManaged public var title: String?
    @NSManaged public var showsDate: NSNumber?
}

/// a kitchen timer (iOS 18): its Live Activity also draws at the small size (Apple Watch, CarPlay)
struct TimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var seconds: Int }
    var name: String
}
var headlineReloads: Int {
    get { sharedDefaults.integer(forKey: "headlineReloads") }
    set { sharedDefaults.set(newValue, forKey: "headlineReloads") }
}
