// HelloSiri, how the system finds the app's actions and content (issue #308): an intent donation (the Shortcuts app's
// Siri Suggestions) and deleting donations; cafes as indexed entities in Spotlight (choosing one runs ShowCafeIntent),
// with a URL representation that DirectionsIntent opens through OpenURLIntent; a unique entity (the app's settings),
// a transient entity (a weather report) as a result value; camera capture and audio recording intents; a relevant
// widget intent; an intent with an assistant schema (@AssistantIntent(schema: .system.search)) and, on iOS 26, an
// app schema and a snippet intent shown in Siri's card; an App Intents package.
import SwiftUI
import AppIntents
import CoreSpotlight

// MARK: - entities

@available(iOS 18.0, *)
extension CafeEntity: IndexedEntity, URLRepresentableEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let a = defaultAttributeSet
        a.keywords = ["coffee", "cafe", id.lowercased()]
        return a
    }
    static var urlRepresentation: URLRepresentation { "coffeeclub://cafe/\(\.id)" }
}

@available(iOS 18.0, *)
struct CoffeeSettings: UniqueAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Coffee Settings"
    static var defaultQuery = UniqueAppEntityProvider { CoffeeSettings() }
    var id: String { "settings" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "Settings", subtitle: decaf ? "Decaf" : "Regular") }
    var decaf: Bool { UserDefaults.standard.bool(forKey: "decaf") }
}

struct WeatherReport: TransientAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Weather"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(summary) at \(cafe)") }
    var summary = "Sunny, 21°"
    var cafe = "Downtown"
    init() {}
}

// MARK: - intents

@available(iOS 18.0, *)
struct DirectionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Cafe Directions"
    @Parameter(title: "Cafe") var cafe: CafeEntity
    init() {}
    func perform() async throws -> some IntentResult & OpensIntent {
        log("directions to \(cafe.id)")
        return .result(opensIntent: try await OpenURLIntent(urlRepresentable: cafe))
    }
}
@available(iOS 18.0, *)
struct ToggleDecafIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Decaf"
    @Parameter(title: "Settings") var settings: CoffeeSettings
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(!settings.decaf, forKey: "decaf")
        log("decaf \(UserDefaults.standard.bool(forKey: "decaf"))")
        return .result(dialog: "Decaf is \(UserDefaults.standard.bool(forKey: "decaf") ? "on" : "off").")
    }
}
struct CafeWeatherIntent: AppIntent {
    static var title: LocalizedStringResource = "Cafe Weather"
    init() {}
    func perform() async throws -> some IntentResult & ReturnsValue<WeatherReport> & ProvidesDialog {
        var w = WeatherReport()
        w.cafe = AppModel.shared.cafe
        return .result(value: w, dialog: "It’s \(w.summary.lowercased()) at \(w.cafe).")
    }
}
@available(iOS 18.0, *)
struct LatteArtCameraIntent: CameraCaptureIntent {
    struct AppContext: Codable, Sendable { var lastPhoto: String }
    static var title: LocalizedStringResource = "Latte Art Camera"
    init() {}
    func perform() async throws -> some IntentResult {
        let before = await Self.appContext?.lastPhoto ?? "none"
        try await Self.updateAppContext(AppContext(lastPhoto: "latte-art-1"))
        log("camera capture: last photo \(before), now \(await Self.appContext?.lastPhoto ?? "?")")
        return .result()
    }
}
@available(iOS 18.0, *)
struct RecordTastingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Record a Tasting"
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog {
        log("recording a tasting in the background")
        return .result(dialog: "Recording your tasting.")
    }
}
struct CafeWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Cafe Widget"
    @Parameter(title: "Cafe") var cafe: CafeEntity?
    init() {}
}
@available(iOS 18.0, *)
@AssistantIntent(schema: .system.search)
struct SearchCafesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Cafes"
    @Parameter(title: "Search") var criteria: String
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let found = cafes.filter { $0.localizedCaseInsensitiveContains(criteria) }
        return .result(dialog: "Found \(found.count) cafe\(found.count == 1 ? "" : "s").")
    }
}
@available(iOS 26.0, *)
@AppIntent(schema: .system.searchInApp)
struct FindInMenuIntent: AppIntent {
    static var title: LocalizedStringResource = "Find in Menu"
    @Parameter(title: "Search") var criteria: String
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}

/// iOS 26: the order's status as a snippet intent, shown in Siri's card
@available(iOS 26.0, *)
struct OrderStatusSnippet: SnippetIntent {
    static var title: LocalizedStringResource = "Order Status"
    init() {}
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result { OrderView(drink: .latte, cups: max(orders, 1), done: true) }
    }
}
@available(iOS 26.0, *)
struct OrderStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Order Status"
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        .result(dialog: "Here’s your order.", snippetIntent: OrderStatusSnippet())
    }
}

struct CoffeePackage: AppIntentsPackage {}

// MARK: - what the app does with them

@MainActor enum Discovery {
    static func donate() {
        let i = OrderCoffeeIntent()
        i.drink = .latte
        i.cups = 2
        let id = IntentDonationManager.shared.donate(intent: i)
        log("donated an order \(id)")
    }
    static func deleteDonations() {
        Task {
            let gone = try await IntentDonationManager.shared.deleteDonations(matching: .intentType(OrderCoffeeIntent.self))
            log("deleted \(gone.count) donation(s)")
        }
    }
    static func index() {
        Task {
            if #available(iOS 18.0, *) {
                try await CSSearchableIndex.default().indexAppEntities(cafes.map { CafeEntity(id: $0) })
                let url = CafeEntity(id: "Harbor").urlRepresentation?.absoluteString ?? "-"
                log("indexed \(cafes.count) cafes, Harbor is \(url), schema intent \((SearchCafesIntent.self as Any) is any AssistantSchemaIntent.Type) " +
                    "assistant only \(SearchCafesIntent.isAssistantOnly)")
            } else {
                log("indexed entities need iOS 18")
            }
            try await RelevantIntentManager.shared.updateRelevantIntents([
                RelevantIntent(CafeWidgetIntent(), widgetKind: "CafeWidget", relevance: .date(from: Date(), to: Date().addingTimeInterval(3600)))])
            log("packages \(CoffeePackage.includedPackages.count)")
        }
    }
}
