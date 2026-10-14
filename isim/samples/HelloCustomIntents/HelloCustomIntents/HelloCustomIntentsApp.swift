// Sample: a custom SiriKit intent from an .intentdefinition (issue #214). `isim build` generates Xcode's classes from
// Intents.intentdefinition: OrderSoupIntent (soup: Soup, quantity, size: SoupSize), OrderSoupIntentHandling,
// OrderSoupIntentResponse (.success(soup:quantity:waitTime:), .soldOut(soup:)), Soup (an INObject) and the
// resolution results. The app handles the intent (INIntentsSupported, application(_:handlerFor:)); isim's Siri runs
// it from `siri intent OrderSoupIntent soup=Tomato quantity=2 size=bowl`, asks for a missing soup with the
// definition's prompt and speaks the response's dialog. Each step logs a "soup" line.
import SwiftUI
import Intents

func log(_ s: String) { print("soup \(s)") }

final class OrderSoupHandler: NSObject, OrderSoupIntentHandling {
    func resolveSoup(for intent: OrderSoupIntent, with completion: @escaping (SoupResolutionResult) -> Void) {
        guard let soup = intent.soup else { log("resolve soup: needs value"); completion(.needsValue()); return }
        log("resolve soup: \(soup.displayString)")
        completion(.success(with: soup))
    }
    func resolveQuantity(for intent: OrderSoupIntent, with completion: @escaping (INIntegerResolutionResult) -> Void) {
        completion(.success(with: intent.quantity.map { Int($0.intValue) } ?? 1))
    }
    func resolveSize(for intent: OrderSoupIntent, with completion: @escaping (SoupSizeResolutionResult) -> Void) {
        log("resolve size: \(intent.size.rawValue)")
        completion(.success(with: intent.size == .unknown ? .cup : intent.size))
    }
    func handle(intent: OrderSoupIntent, completion: @escaping (OrderSoupIntentResponse) -> Void) {
        let soup = intent.soup ?? Soup(identifier: "tomato", display: "Tomato")
        let quantity = intent.quantity ?? 1
        log("handle: \(quantity) \(soup.displayString) size \(intent.size.rawValue)")
        if soup.displayString == "Gazpacho" { completion(.soldOut(soup: soup)); return }
        completion(.success(soup: soup, quantity: quantity, waitTime: NSNumber(value: 5 * quantity.intValue)))
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    let handler = OrderSoupHandler()
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        log("handler for \(type(of: intent))")
        return intent is OrderSoupIntent ? handler : nil
    }
}

struct ContentView: View {
    @State var status = "Not asked"
    var body: some View {
        VStack(spacing: 16) {
            Text("Soup Kitchen").font(.largeTitle.bold())
            Text("Siri: \(status)").accessibilityIdentifier("siri-status")
            Button("Allow Siri") {
                INPreferences.requestSiriAuthorization { s in
                    log("Siri authorization \(s.rawValue)")
                    DispatchQueue.main.async { status = s == .authorized ? "Allowed" : "Not allowed" }
                }
            }
            .accessibilityIdentifier("allowSiri")
        }
        .onAppear {
            let intent = OrderSoupIntent()                         // the generated classes, used directly
            intent.soup = Soup(identifier: "tomato", display: "Tomato")
            intent.quantity = 2
            intent.size = .bowl
            log("intent: \(intent.soup?.displayString ?? "-") \(intent.quantity ?? 0) size \(intent.size.rawValue)")
            let r = OrderSoupIntentResponse.success(soup: intent.soup!, quantity: 2, waitTime: 10)
            log("response: code \(r.code.rawValue) wait \(r.waitTime ?? 0)")
        }
    }
}

@main
struct HelloCustomIntentsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}
