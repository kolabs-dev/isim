// Sample: StoreKit external purchases (issue #396). The app has the external purchase entitlements and lists the
// United States in SKExternalPurchase, SKExternalPurchaseLink and SKExternalPurchaseMultiLink (isim's StoreKit
// storefront is USA by default), and the Netherlands only for the custom link, so ExternalPurchaseCustomLink is not
// eligible here. Each button prints what StoreKit answers; tests/ui/test_storekit_external.py checks it.
import SwiftUI
import StoreKit

@main
struct HelloExternalPurchaseApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

/// what the token says (Apple's tokens are base64 JSON)
func describe(_ token: String) -> String {
    guard let data = Data(base64Encoded: token), let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "unreadable" }
    return "bundle \(o["bundleId"] as? String ?? "-") type \(o["tokenType"] as? String ?? "-") id \((o["externalPurchaseId"] as? String)?.count ?? 0)"
}

struct ContentView: View {
    @State private var status = "ready"
    var body: some View {
        List {
            Text(status).accessibilityIdentifier("status")
            Button("External purchase") {
                Task {
                    do {
                        switch try await ExternalPurchase.presentNoticeSheet() {
                        case .continuedWithExternalPurchaseToken(let token): report("external purchase: continued, token \(describe(token))")
                        case .cancelled: report("external purchase: cancelled")
                        @unknown default: report("external purchase: unknown")
                        }
                    } catch { report("external purchase: error \(error)") }
                }
            }.accessibilityIdentifier("purchase")
            Button("Link out") {
                Task {
                    do { try await ExternalPurchaseLink.open(); report("link: returned") } catch { report("link: error \(error)") }
                }
            }.accessibilityIdentifier("link")
            Button("Custom link") {
                Task {
                    if #available(iOS 18.1, *) { report(await customLink()) } else { report("custom link: needs iOS 18.1") }
                }
            }.accessibilityIdentifier("custom")
        }
        .task {
            let canOpen = await ExternalPurchaseLink.canOpen
            var canPresent = false, urls: [URL] = [], eligible = false
            if #available(iOS 17.5, *) { canPresent = await ExternalPurchase.canPresent; urls = await ExternalPurchaseLink.eligibleURLs ?? [] }
            if #available(iOS 18.1, *) { eligible = await ExternalPurchaseCustomLink.isEligible }
            report("eligibility: canPresent \(canPresent) canOpen \(canOpen) urls \(urls.map(\.lastPathComponent).joined(separator: ",")) custom \(eligible)")
        }
    }
    /// iOS 27.2 replaced showNotice(type:) and token(for: String)
    @available(iOS 18.1, *)
    func customLink() async -> String {
        do {
            let token: ExternalPurchaseCustomLink.Token?, r: ExternalPurchaseCustomLink.NoticeResult
            if #available(iOS 27.2, *) {
                token = try await ExternalPurchaseCustomLink.token(for: .withinApp)
                r = try await ExternalPurchaseCustomLink.showNotice(for: .withinApp)
            } else {
                token = try await ExternalPurchaseCustomLink.token(for: "ACQUISITION")
                r = try await ExternalPurchaseCustomLink.showNotice(type: .withinApp)
            }
            return "custom link: \(r) token \(token == nil ? "none" : "some")"
        } catch { return "custom link: error \(error)" }
    }
    func report(_ s: String) { print(s); status = s }
}
