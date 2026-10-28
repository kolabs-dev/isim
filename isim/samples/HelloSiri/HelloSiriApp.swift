// HelloSiri ("Coffee Club"): App Intents with App Shortcuts (Siri phrases, the Shortcuts app, Spotlight) and SiriKit.
// - OrderCoffeeIntent: an AppEnum parameter (asked for, or named in the phrase), a quantity with a default, a
//   confirmation with a snippet view, a result dialog and snippet.
// - ShowCafeIntent (OpenIntent): an AppEntity from an EntityStringQuery; opens the app on that cafe. Adding a cafe
//   calls updateAppShortcutParameters() so Siri knows its name.
// - CupsTodayIntent: a value and a dialog; AddNoteIntent: a required String parameter with requestValueDialog;
//   ClearOrdersIntent: an action that is not an App Shortcut; ResetIntent: not discoverable.
// - SiriKit: the Intents extension (messages, calls, the shopping list, music, payments, the club car, workouts,
//   photos: Intents/Domains.swift), INCreateNoteIntent handled in the app
//   (application(_:handlerFor:)), music and workouts in the app (application(_:handle:)), a call and photos continued in the app
//   (NSUserActivity with its INInteraction), Siri authorization, a donation, Add to Siri.
// - SiriKitTypes.swift: the app's vocabulary, relevant shortcuts, INObjectCollection and INCurrencyAmount.
// - Discovery.swift: App Intents donations, Spotlight entities, URL representations and the other intent kinds.
import SwiftUI
import AppIntents
import Intents
import IntentsUI

// MARK: - App Intents

enum Drink: String, AppEnum {
    case espresso, latte, cappuccino
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Drink"
    static var caseDisplayRepresentations: [Drink: DisplayRepresentation] = [
        .espresso: "Espresso", .latte: DisplayRepresentation(title: "Latte", subtitle: "With steamed milk"), .cappuccino: "Cappuccino"]
}

struct CafeEntity: AppEntity {
    let id: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Cafe"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)", subtitle: "Coffee Club cafe") }
    static var defaultQuery = CafeQuery()
}
var cafes: [String] {
    get { UserDefaults.standard.array(forKey: "cafes") as? [String] ?? ["Downtown", "Harbor", "Airport"] }
    set { UserDefaults.standard.set(newValue, forKey: "cafes") }
}
struct CafeQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CafeEntity] { identifiers.filter { cafes.contains($0) }.map { CafeEntity(id: $0) } }
    func suggestedEntities() async throws -> [CafeEntity] { cafes.map { CafeEntity(id: $0) } }
    func entities(matching string: String) async throws -> [CafeEntity] { cafes.filter { $0.localizedCaseInsensitiveContains(string) }.map { CafeEntity(id: $0) } }
}

var orders: Int {
    get { UserDefaults.standard.integer(forKey: "orders") }
    set { UserDefaults.standard.set(newValue, forKey: "orders") }
}

struct OrderCoffeeIntent: AppIntent {
    static var title: LocalizedStringResource = "Order Coffee"
    static var description: IntentDescription? = IntentDescription("Orders a drink at your cafe.", categoryName: "Orders", searchKeywords: ["coffee", "drink"])
    @Parameter(title: "Drink", requestValueDialog: "What would you like to drink?") var drink: Drink
    @Parameter(title: "Cups", default: 1) var cups: Int
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        try await requestConfirmation(result: .result(dialog: "Order \(cups) \(drink.rawValue)?") { OrderView(drink: drink, cups: cups, done: false) },
                                      confirmationActionName: .order)
        orders += cups
        log("ordered \(cups) \(drink.rawValue)")
        return .result(dialog: "Your \(drink.rawValue) is on its way.") { OrderView(drink: drink, cups: cups, done: true) }
    }
}
struct OrderView: View {
    let drink: Drink, cups: Int, done: Bool
    var body: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(Color(red: 0.42, green: 0.25, blue: 0.13)).frame(width: 44, height: 44); Image(systemName: "cup.and.saucer.fill").foregroundColor(.white) }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cups) × \(drink.rawValue.capitalized)").font(.headline)
                Text(done ? "Ready in 4 minutes" : "Coffee Club, Downtown").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(done ? Color.green.opacity(0.18) : Color.orange.opacity(0.18)))
    }
}

struct ShowCafeIntent: OpenIntent {
    static var title: LocalizedStringResource = "Show Cafe"
    @Parameter(title: "Cafe") var target: CafeEntity
    init() {}
    func perform() async throws -> some IntentResult {
        log("showing cafe \(target.id)")
        AppModel.shared.cafe = target.id
        return .result()
    }
}
struct CupsTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Cups Today"
    init() {}
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        .result(value: orders, dialog: "You’ve ordered \(orders) cup\(orders == 1 ? "" : "s") today.")
    }
}
struct AddNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Tasting Note"
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @Parameter(title: "Note", requestValueDialog: "What should the note say?") var text: String
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(text, forKey: "note")
        log("note “\(text)”")
        return .result(dialog: "Noted: “\(text)”.")
    }
}
struct ClearOrdersIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear Orders"
    static var description: IntentDescription? = "Starts the day over."
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog { orders = 0; log("orders cleared"); return .result(dialog: "Orders cleared.") }
}
struct ResetIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Everything"
    static var isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult { .result() }
}

struct CoffeeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OrderCoffeeIntent(), phrases: ["Order a coffee in \(.applicationName)", "Order a \(\.$drink) in \(.applicationName)"],
                    shortTitle: "Order Coffee", systemImageName: "cup.and.saucer.fill")
        AppShortcut(intent: ShowCafeIntent(), phrases: ["Show \(\.$target) in \(.applicationName)"], shortTitle: "Show Cafe", systemImageName: "map")
        AppShortcut(intent: CupsTodayIntent(), phrases: ["How many coffees did I have in \(.applicationName)"], shortTitle: "Cups Today", systemImageName: "number")
        AppShortcut(intent: AddNoteIntent(), phrases: ["Add a tasting note in \(.applicationName)"], shortTitle: "Tasting Note", systemImageName: "note.text")
    }
    static var shortcutTileColor: ShortcutTileColor = .tangerine
}

// MARK: - the app

@MainActor final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var cafe = "Downtown"
    @Published var siri = INPreferences.siriAuthorizationStatus()
    @Published var last = ""
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// SiriKit intents the app handles itself (INIntentsSupported)
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        log("handler for \(type(of: intent)) in the app")
        return intent is INCreateNoteIntent ? NoteHandler() : nil
    }
    /// music and workouts Siri resolved in the extension (.handleInApp)
    func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
        switch intent {
        case let w as INStartWorkoutIntent:
            let name = w.workoutName?.spokenPhrase ?? "workout"
            workout = ["name": name, "state": "running", "goal": w.goalValue.map { "\($0)" } ?? "open"]
            log("workout \(name) started (goal \(workout?["goal"] ?? "-"), \(w.workoutLocationType == .indoor ? "indoor" : "outdoor"))")
            completionHandler(INStartWorkoutIntentResponse(code: .success, userActivity: nil))
        case is INPauseWorkoutIntent:
            workout?["state"] = "paused"; log("workout paused")
            completionHandler(INPauseWorkoutIntentResponse(code: .success, userActivity: nil))
        case is INResumeWorkoutIntent:
            workout?["state"] = "running"; log("workout resumed")
            completionHandler(INResumeWorkoutIntentResponse(code: .success, userActivity: nil))
        case is INEndWorkoutIntent:
            log("workout \(workout?["name"] ?? "?") ended"); workout = nil
            completionHandler(INEndWorkoutIntentResponse(code: .success, userActivity: nil))
        case is INCancelWorkoutIntent:
            log("workout \(workout?["name"] ?? "?") cancelled"); workout = nil
            completionHandler(INCancelWorkoutIntentResponse(code: .success, userActivity: nil))
        default:
            let title = (intent as? INPlayMediaIntent)?.mediaItems?.first?.title ?? "?"
            nowPlaying = title
            log("playing \(title)")
            completionHandler(INPlayMediaIntentResponse(code: .success, userActivity: nil))
        }
    }
}
final class NoteHandler: NSObject, INCreateNoteIntentHandling {
    func resolveTitle(for intent: INCreateNoteIntent, with completion: @escaping (INSpeakableStringResolutionResult) -> Void) {
        if let t = intent.title { completion(.success(with: t)) } else { completion(.needsValue()) }
    }
    func handle(intent: INCreateNoteIntent, completion: @escaping (INCreateNoteIntentResponse) -> Void) {
        let text = (intent.content as? INTextNoteContent)?.text ?? intent.title?.spokenPhrase ?? ""
        UserDefaults.standard.set(text, forKey: "note")
        log("note from Siri “\(text)”")
        let r = INCreateNoteIntentResponse(code: .success, userActivity: nil)
        r.createdNote = INNote(title: intent.title ?? INSpeakableString(spokenPhrase: text), contents: [INTextNoteContent(text: text)], groupName: nil,
                               createdDateComponents: nil, modifiedDateComponents: nil, identifier: "note-1")
        completion(r)
    }
}

@main
struct HelloSiriApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}

struct AddToSiri: UIViewControllerRepresentable {
    let done: (String) -> Void
    func makeUIViewController(context: Context) -> INUIAddVoiceShortcutViewController {
        let intent = INSendMessageIntent(recipients: [person(members[2])], outgoingMessageType: .outgoingMessageText, content: "I’m on my way",
                                         speakableGroupName: nil, conversationIdentifier: nil, serviceName: nil, sender: nil, attachments: nil)
        intent.suggestedInvocationPhrase = "On my way"
        let vc = INUIAddVoiceShortcutViewController(shortcut: INShortcut(intent: intent)!)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: INUIAddVoiceShortcutViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }
    final class Coordinator: NSObject, INUIAddVoiceShortcutViewControllerDelegate {
        let done: (String) -> Void
        init(done: @escaping (String) -> Void) { self.done = done }
        func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
            done(voiceShortcut?.invocationPhrase ?? "")
        }
        func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) { done("") }
    }
}

struct ContentView: View {
    @ObservedObject var model = AppModel.shared
    /// Siri's photo search or slideshow, continued in the app with its intent
    func photos(_ a: NSUserActivity) {
        let i = a.interaction?.intent
        let search = i as? INSearchForPhotosIntent, show = i as? INStartPhotoPlaybackIntent
        let album: String? = search?.albumName ?? show?.albumName
        let place: String? = (search?.locationCreated ?? show?.locationCreated)?.name
        let people: [INPerson] = search?.peopleInPhoto ?? show?.peopleInPhoto ?? []
        let who: String? = people.isEmpty ? nil : people.map { $0.displayName }.joined(separator: ", ")
        let what = [album, place, who].compactMap { $0 }.joined(separator: " · ")
        let n = (a.interaction?.intentResponse as? INSearchForPhotosIntentResponse)?.searchResultsCount
             ?? (a.interaction?.intentResponse as? INStartPhotoPlaybackIntentResponse)?.searchResultsCount ?? 0
        model.last = "\(show != nil ? "Slideshow" : "Photos"): \(what.isEmpty ? "all" : what) (\(n))"
        log("continued \(a.activityType): \(model.last)")
    }
    @State var tip = true
    @State var addToSiri = false
    @State var tick = 0
    var body: some View {
        NavigationStack {
            List {
                Section {
                    SiriTipView(intent: OrderCoffeeIntent(), isVisible: $tip)
                    ShortcutsLink()
                }
                Section("Today") {
                    Text("Cafe: \(model.cafe)").accessibilityIdentifier("cafe")
                    Text("Orders: \(orders)").accessibilityIdentifier("orders")
                    Text("Note: \(UserDefaults.standard.string(forKey: "note") ?? "-")").accessibilityIdentifier("note")
                    Text("Sent: \(sentMessages.last ?? "-")").accessibilityIdentifier("sent")
                    Text("Paid: \(paymentLog.last ?? "-")").accessibilityIdentifier("paid")
                    Text("Ride: \(currentRide.map { "\($0["option"] ?? "") to \($0["to"] ?? "")" } ?? "-")").accessibilityIdentifier("ride")
                    Text("Workout: \(workout.map { "\($0["name"] ?? "") (\($0["state"] ?? ""))" } ?? "-")").accessibilityIdentifier("workout")
                    Text(model.last).accessibilityIdentifier("last")
                }
                Section("Siri") {
                    Button("Allow Siri") {
                        INPreferences.requestSiriAuthorization { s in
                            Task { @MainActor in AppModel.shared.siri = s }
                            log("Siri authorization \(s.rawValue)")
                        }
                    }.accessibilityIdentifier("allowSiri")
                    Text(model.siri == .authorized ? "Siri: allowed" : model.siri == .denied ? "Siri: denied" : "Siri: not asked").accessibilityIdentifier("siriStatus")
                    Button("Add Station cafe") {
                        if !cafes.contains("Station") { cafes.append("Station") }
                        CoffeeShortcuts.updateAppShortcutParameters()
                        log("cafes \(cafes.joined(separator: ", "))")
                    }.accessibilityIdentifier("addCafe")
                    Button("Donate a message") {
                        let i = INSendMessageIntent(recipients: [person(members[0])], outgoingMessageType: .outgoingMessageText, content: "Flat white?",
                                                    speakableGroupName: nil, conversationIdentifier: nil, serviceName: nil, sender: nil, attachments: nil)
                        INInteraction(intent: i, response: nil).donate { e in log("donated \(e == nil ? "ok" : "failed")") }
                    }.accessibilityIdentifier("donate")
                    Button("Add to Siri") { addToSiri = true }.accessibilityIdentifier("addToSiri")
                    Button("Donate an order") { Discovery.donate() }.accessibilityIdentifier("donateOrder")
                    Button("Delete order donations") { Discovery.deleteDonations() }.accessibilityIdentifier("deleteDonations")
                    Button("Index cafes") { Discovery.index() }.accessibilityIdentifier("indexCafes")
                    Button("Relevant shortcuts") { SiriKitTypes.relevantShortcuts() }.accessibilityIdentifier("relevant")
                    Button("Shared types") { SiriKitTypes.values() }.accessibilityIdentifier("sharedTypes")
                    Button("Voice shortcuts") {
                        INVoiceShortcutCenter.shared.getAllVoiceShortcuts { list, _ in
                            log("voice shortcuts: \((list ?? []).map { $0.invocationPhrase }.joined(separator: ", "))")
                        }
                    }.accessibilityIdentifier("listVoice")
                }
            }
            .navigationTitle("Coffee Club")
            .id(tick)
        }
        .sheet(isPresented: $addToSiri) {
            AddToSiri { phrase in
                addToSiri = false
                log(phrase.isEmpty ? "Add to Siri cancelled" : "added voice shortcut “\(phrase)”")
            }
        }
        .onContinueUserActivity("INStartCallIntent") { a in
            let call = a.interaction?.intent as? INStartCallIntent
            model.last = "Calling \(call?.contacts?.first?.displayName ?? "?")"
            log("continued \(a.activityType): \(model.last)")
        }
        .onContinueUserActivity("INSearchForPhotosIntent") { a in photos(a) }
        .onContinueUserActivity("INStartPhotoPlaybackIntent") { a in photos(a) }
        .onOpenURL { url in log("opened \(url.absoluteString)") }
        .onAppear {
            SiriKitTypes.vocabulary()
            log("launched, \(orders) order(s), cafe \(model.cafe), Siri \(model.siri.rawValue)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in tick += 1 }
    }
}
