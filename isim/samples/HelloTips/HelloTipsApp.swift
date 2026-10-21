// HelloTips ("Recipes"): TipKit. Tips.configure at launch (display frequency .immediate, or the TIPS_FREQUENCY
// environment variable: hourly, daily, ...); an inline TipView with MaxDisplayCount; a tip whose #Rule reads a @Parameter
// (it appears once the app has recipes) with two actions; a tip whose rule counts an event's donations (three recipes
// viewed this week) and ignores the display frequency; a popover tip on the share button (popoverTip); on iOS 18 an
// ordered TipGroup of onboarding tips; and the UIKit views (TipUIView, TipUIPopoverViewController). Each step logs a
// "HelloTips:" line.
import SwiftUI
import UIKit
import TipKit

func log(_ s: String) { NSLog("HelloTips: %@", s) }

struct FavoriteTip: Tip {
    var title: Text { Text("Save as a Favorite") }
    var message: Text? { Text("Your favorite recipes always appear at the top of the list.") }
    var image: Image? { Image(systemName: "star") }
    var options: [Option] { MaxDisplayCount(5) }
}
struct ShoppingListTip: Tip {
    @Parameter static var hasRecipes: Bool = false
    var title: Text { Text("Make a Shopping List") }
    var message: Text? { Text("Turn a recipe's ingredients into a list.") }
    var image: Image? { Image(systemName: "cart") }
    var rules: [Rule] {
        #Rule(Self.$hasRecipes) { $0 == true }
    }
    var actions: [Action] {
        Action(id: "make-list", title: "Make a List")
        Action(id: "later", title: "Not Now")
    }
}
struct TimerTip: Tip {
    static let viewedRecipe = Event(id: "viewedRecipe")
    var title: Text { Text("Use the Kitchen Timer") }
    var message: Text? { Text("Start a timer from any step.") }
    var image: Image? { Image(systemName: "timer") }
    var rules: [Rule] {
        #Rule(Self.viewedRecipe) { $0.donations.donatedWithin(.week).count >= 3 }
    }
    var options: [Option] { IgnoresDisplayFrequency(true) }
}
struct ShareTip: Tip {
    var title: Text { Text("Share a Recipe") }
    var message: Text? { Text("Send it to a friend.") }
    var image: Image? { Image(systemName: "square.and.arrow.up") }
}
struct WelcomeTip: Tip {
    var title: Text { Text("Welcome to Recipes") }
    var image: Image? { Image(systemName: "hand.wave") }
}
struct SearchTip: Tip {
    var title: Text { Text("Search Every Recipe") }
    var image: Image? { Image(systemName: "magnifyingglass") }
}
struct BookmarkTip: Tip {
    var title: Text { Text("Bookmark Steps") }
    var message: Text? { Text("Tap a step to come back to it later.") }
    var image: Image? { Image(systemName: "bookmark") }
}

@main
struct HelloTipsApp: App {
    init() {
        let names: [String: Tips.ConfigurationOption.DisplayFrequency] = ["hourly": .hourly, "daily": .daily, "weekly": .weekly, "monthly": .monthly]
        let f = names[ProcessInfo.processInfo.environment["TIPS_FREQUENCY"] ?? ""] ?? .immediate
        do {
            try Tips.configure([.displayFrequency(f), .datastoreLocation(.applicationDefault)])
            log("configured")
        } catch { log("configure failed \(error)") }
        do { try Tips.configure() } catch { log("second configure: \(error)") }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}

let recipes = ["Pancakes", "Ramen", "Tacos", "Risotto"]

struct ContentView: View {
    let favorite = FavoriteTip(), shopping = ShoppingListTip(), timer = TimerTip(), share = ShareTip()
    @State var status = ""
    @State var onboarding = false
    @State var uikit = false
    var body: some View {
        NavigationStack {
            List {
                TipView(favorite)
                TipView(shopping) { action in
                    log("action \(action.id) (\(action.index ?? -1))")
                    shopping.invalidate(reason: .actionPerformed)
                }
                TipView(timer, arrowEdge: .bottom)
                Section("Recipes") {
                    ForEach(recipes, id: \.self) { r in
                        Button(r) {
                            Task { await TimerTip.viewedRecipe.donate(); log("viewed \(r), \(TimerTip.viewedRecipe.donations.count) view(s)") }
                        }.accessibilityIdentifier("recipe-\(r)")
                    }
                }
                Section("Tips") {
                    Button("Add recipes") { ShoppingListTip.hasRecipes = true; log("has recipes") }.accessibilityIdentifier("addRecipes")
                    Button("Status") {
                        status = "favorite \(favorite.status), shopping \(shopping.status), timer \(timer.status)"
                        log(status)
                    }.accessibilityIdentifier("status")
                    Text(status).accessibilityIdentifier("statusText")
                    Button("Reset favorite") { Task { await favorite.resetEligibility(); log("favorite reset") } }.accessibilityIdentifier("resetFavorite")
                    Button("Onboarding") { onboarding = true }.accessibilityIdentifier("onboarding")
                    Button("UIKit tips") { uikit = true }.accessibilityIdentifier("uikit")
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { log("share") } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityIdentifier("share")
                        .popoverTip(share)
                }
            }
        }
        .sheet(isPresented: $onboarding) { OnboardingView() }
        .sheet(isPresented: $uikit) { UIKitTips().ignoresSafeArea() }
        .task {
            for await s in shopping.statusUpdates { log("shopping tip \(s)") }
        }
    }
}

/// iOS 18: an ordered TipGroup shows the welcome tip, then the search tip once it is closed
struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            if #available(iOS 18.0, *) { GroupedTips() } else { Text("TipGroup needs iOS 18").accessibilityIdentifier("noGroup") }
        }
    }
}
@available(iOS 18.0, *)
struct GroupedTips: View {
    @State var group = TipGroup(.ordered) {
        WelcomeTip()
        SearchTip()
    }
    var body: some View {
        VStack(spacing: 16) {
            TipView(group.currentTip)
            Text("Current: \(group.currentTip?.id ?? "none")").accessibilityIdentifier("currentTip")
            Spacer()
        }
        .padding()
        .navigationTitle("Onboarding")
    }
}

/// UIKit: a TipUIView in the layout and a TipUIPopoverViewController from a button
struct UIKitTips: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController { UINavigationController(rootViewController: TipsViewController()) }
    func updateUIViewController(_ vc: UINavigationController, context: Context) {}
}
final class TipsViewController: UIViewController {
    let button = UIButton(type: .system)
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit"
        view.backgroundColor = .systemGroupedBackground
        let tipView = TipUIView(BookmarkTip()) { action in log("UIKit action \(action.id)") }
        tipView.cornerRadius = 20
        tipView.frame = CGRect(x: 16, y: 120, width: view.bounds.width - 32, height: 110)
        tipView.autoresizingMask = [.flexibleWidth]
        view.addSubview(tipView)
        button.setTitle("Show a popover tip", for: .normal)
        button.frame = CGRect(x: 16, y: 260, width: view.bounds.width - 32, height: 44)
        button.accessibilityIdentifier = "popoverTipButton"
        button.addTarget(self, action: #selector(showTip), for: .touchUpInside)
        view.addSubview(button)
        log("UIKit tip view \(BookmarkTip().shouldDisplay ? "shown" : "hidden")")
    }
    @objc func showTip() {
        let vc = TipUIPopoverViewController(ShareTip(), sourceItem: button)
        present(vc, animated: true)
        log("UIKit popover tip presented")
    }
}
