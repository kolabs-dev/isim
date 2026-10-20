// Sample: Wallet passes (PassKit) on isim — PKPass read from the app's .pkpass files (fields, localizations,
// relevant dates, a tampered pass refused), PKAddPassButton presenting PKAddPassesViewController, PKPassLibrary
// (replace, add with iOS's alert, remove, the change notification) and SwiftUI's AddPassToWalletButton with a
// .pkpasses bundle. isim's Wallet lives in the device data; `isim wallet` lists it. The passes are made by
// gen_passes.py with a placeholder signature. Every step is printed, so tests/ui/test_wallet.py can check it.
import SwiftUI
import PassKit

func bundled(_ name: String) -> Data { (try? Data(contentsOf: Bundle.main.url(forResource: name, withExtension: nil)!)) ?? Data() }

func describe(_ p: PKPass) -> String {
    let seat = p.localizedValue(forFieldKey: "seat").map { "\($0)" } ?? "-"
    let date = (p.localizedValue(forFieldKey: "date") as? Date).map { ISO8601DateFormatter().string(from: $0) } ?? "-"
    let relevant = p.relevantDates.first.map { $0.interval.map { "\(Int($0.duration / 3600))h" } ?? ($0.date == nil ? "?" : "date") } ?? "-"
    return "\(p.passTypeIdentifier) \(p.serialNumber) org=\(p.organizationName) desc=\(p.localizedDescription) seat=\(seat) date=\(date) " +
        "relevant=\(relevant) type=\(p.passType.rawValue) icon=\(Int(p.icon.size.width)) web=\(p.webServiceURL?.host ?? "-") token=\(p.authenticationToken ?? "-")"
}

@MainActor final class Wallet: NSObject, ObservableObject, PKAddPassesViewControllerDelegate {
    @Published var count = 0
    let library = PKPassLibrary()
    var ticket: PKPass?, ticket2: PKPass?, coupon: PKPass?
    var trip: [PKPass] = []

    func start() {
        ticket = try? PKPass(data: bundled("ticket.pkpass"))
        ticket2 = try? PKPass(data: bundled("ticket-v2.pkpass"))
        coupon = try? PKPass(data: bundled("coupon.pkpass"))
        for p in [ticket, coupon].compactMap({ $0 }) { print("pass: \(describe(p))") }
        do { _ = try PKPass(data: bundled("tampered.pkpass")) } catch { let e = error as NSError; print("tampered: \(e.domain) \(e.code)") }
        do { _ = try PKPass(data: Data("not a pass".utf8)) } catch { let e = error as NSError; print("garbage: \(e.domain) \(e.code)") }
        if let d = Bundle.main.url(forResource: "trip", withExtension: "pkpasses"), let vc = PKAddPassesViewController(passesArchiveAt: d) {
            print("trip archive: sheet ready \(vc.isViewLoaded ? "loaded" : "not loaded")")
        }
        trip = [try? PKPass(data: bundled("boarding.pkpass"))].compactMap { $0 }
        print("library: available \(PKPassLibrary.isPassLibraryAvailable()) can add \(PKAddPassesViewController.canAddPasses()) passes \(library.passes().count)")
        NotificationCenter.default.addObserver(forName: Notification.Name(PKPassLibraryNotificationName.PKPassLibraryDidChange.rawValue), object: nil, queue: .main) { n in
            let info = n.userInfo ?? [:]
            let added = (info[PKPassLibraryNotificationKey.addedPassesUserInfoKey.rawValue] as? [PKPass])?.count ?? 0
            let replaced = (info[PKPassLibraryNotificationKey.replacementPassesUserInfoKey.rawValue] as? [PKPass])?.count ?? 0
            let removed = (info[PKPassLibraryNotificationKey.removedPassInfosUserInfoKey.rawValue] as? [[String: Any]])?.count ?? 0
            print("library changed: added=\(added) replaced=\(replaced) removed=\(removed)")
            MainActor.assumeIsolated { self.refresh() }
        }
        refresh()
    }
    func refresh() { count = library.passes().count }

    func presentAdd() {
        guard let t = ticket, let vc = PKAddPassesViewController(pass: t) else { return }
        vc.delegate = self
        top()?.present(vc, animated: true)
    }
    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        controller.dismiss(animated: true)
        print("add sheet finished: in wallet=\(ticket.map(library.containsPass) ?? false)")
    }
    func update() {
        guard let t2 = ticket2 else { return }
        let ok = library.replacePass(with: t2)
        let seat = library.pass(withPassTypeIdentifier: t2.passTypeIdentifier, serialNumber: t2.serialNumber)?.localizedValue(forFieldKey: "seat")
        print("replaced \(ok) seat=\(seat.map { "\($0)" } ?? "-")")
    }
    func addCoupon() {
        guard let c = coupon else { return }
        library.addPasses([c]) { status in print("library add status: \(status.rawValue)") }
    }
    func remove() {
        guard let t = ticket else { return }
        library.removePass(t)
        print("removed: contains \(library.containsPass(t)) passes \(library.passes().count)")
    }
    func list() {
        for p in library.passes() { print("in wallet: \(p.serialNumber) \(p.organizationName)") }
        print("listed \(library.passes().count) of type barcode \(library.passes(of: .barcode).count) secure element \(library.passes(of: .secureElement).count)")
    }
}

struct AddPassButton: UIViewRepresentable {
    let action: () -> Void
    func makeUIView(context: Context) -> PKAddPassButton {
        let b = PKAddPassButton(addPassButtonStyle: .black)
        b.accessibilityIdentifier = "add-ticket"
        b.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return b
    }
    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}

struct ContentView: View {
    @StateObject var wallet = Wallet()

    var body: some View {
        VStack(spacing: 12) {
            Text("Wallet").font(.largeTitle.bold())
            Text("\(wallet.count) passes in Wallet").accessibilityIdentifier("wallet-count")
            AddPassButton { wallet.presentAdd() }.frame(height: 48)
            Button("Update the ticket") { wallet.update() }.accessibilityIdentifier("update")
            Button("Add the coupon") { wallet.addCoupon() }.accessibilityIdentifier("add-coupon")
            Button("Remove the ticket") { wallet.remove() }.accessibilityIdentifier("remove")
            Button("List") { wallet.list() }.accessibilityIdentifier("list")
            AddPassToWalletButton(wallet.trip) { added in print("swiftui add: \(added)") }
                .addPassToWalletButtonStyle(.blackOutline)
                .frame(height: 48)
                .accessibilityIdentifier("add-trip")
        }
        .padding()
        .onAppear { wallet.start() }
    }
}

@MainActor func top() -> UIViewController? {
    var t = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
    while let p = t?.presentedViewController { t = p }
    return t
}

@main struct HelloWalletApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
