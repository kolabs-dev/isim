// isim StoreKit messages (StoreKit.Message, iOS 16): the App Store's own sheets shown in the app. isim sends two:
//   - .billingIssue when a subscription renewal failed (billing grace period or billing retry): "Update Payment Method"
//     resolves the issue, like Xcode's Transaction Manager "Resolve Issue";
//   - .winBackOffer (iOS 18 and later) when a lapsed subscriber is eligible for a win-back offer of the .storekit file:
//     "Subscribe" buys the subscription with the offer; the transaction arrives through Transaction.updates.
// As on iOS, an app that listens to Message.messages gets them and decides when to display(in:) them (or never);
// without a listener they are displayed as soon as they are due. Each message is sent once (kept in the ledger).
import UIKit
import SwiftUI

public struct Message: Hashable, Sendable {
    public struct Reason: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let generic = Reason(rawValue: "generic")
        public static let priceIncreaseConsent = Reason(rawValue: "priceIncreaseConsent")
        public static let billingIssue = Reason(rawValue: "billingIssue")
        public static let winBackOffer = Reason(rawValue: "winBackOffer")
        public var description: String { rawValue }
    }
    public let reason: Reason
    let key: String
    let groupID: String
    let productID: String
    let offerID: String?

    /// Messages from the App Store, while the app listens (otherwise isim displays them when they are due).
    public static var messages: Messages { _SKUpdates.start(); return Messages(stream: _SKMessages.broadcast.stream()) }

    public struct Messages: AsyncSequence, Sendable {
        public typealias Element = Message
        let stream: AsyncStream<Message>
        public struct AsyncIterator: AsyncIteratorProtocol {
            var it: AsyncStream<Message>.AsyncIterator
            public mutating func next() async -> Message? { await it.next() }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(it: stream.makeAsyncIterator()) }
    }

    /// Shows the message's sheet.
    @MainActor public func display(in scene: UIWindowScene) throws { _SKMessages.display(self) }
}

public struct DisplayMessageAction {
    @MainActor public func callAsFunction(_ message: Message) throws { _SKMessages.display(message) }
}
struct _SKDisplayMessageKey: EnvironmentKey { static var defaultValue: DisplayMessageAction { DisplayMessageAction() } }
extension EnvironmentValues {
    public var displayStoreKitMessage: DisplayMessageAction {
        get { self[_SKDisplayMessageKey.self] }
        set { self[_SKDisplayMessageKey.self] = newValue }
    }
}

@MainActor enum _SKMessages {
    nonisolated static let broadcast = _SKBroadcast<Message>()
    static let launched = Date()
    static var showing = false

    /// due messages (not sent yet)
    static func due(_ now: Date) -> [Message] {
        let cfg = _SKConfig.load()
        return _SKLedger.shared.read { d in
            var out: [Message] = []
            let sent = Set(d.messages ?? [])
            for g in Set(d.transactions.compactMap { $0.groupID }).sorted() {
                guard let st = _SKLedger.statuses(d, group: g, now: now).first else { continue }
                let t = st.transaction.unsafePayloadValue
                if st.state == .inGracePeriod || st.state == .inBillingRetryPeriod {
                    let key = "billing:\(g):\(t.id)"
                    if !sent.contains(key) { out.append(Message(reason: .billingIssue, key: key, groupID: g, productID: t.productID, offerID: nil)) }
                } else if st.state == .expired, _skOSMajor() >= 18 {
                    let items = cfg.items.filter { $0.groupID == g }
                    guard let item = items.first(where: { $0.id == t.productID && !$0.winBacks.isEmpty }) ?? items.first(where: { !$0.winBacks.isEmpty }),
                          let offer = item.winBacks.first?.offer else { continue }
                    let key = "winback:\(g):\(t.id)"
                    if !sent.contains(key) { out.append(Message(reason: .winBackOffer, key: key, groupID: g, productID: item.id, offerID: offer.id)) }
                }
            }
            return out
        }
    }

    /// called by the subscription clock (main thread)
    static func check() {
        guard !showing, Date().timeIntervalSince(launched) > 1.5 else { return }    // give the app time to start listening
        for m in due(Date()) {
            _SKLedger.shared.mutate { d in d.messages = (d.messages ?? []) + [m.key] }
            if broadcast.count > 0 {
                NSLog("isim StoreKit: message %@ (%@) sent to Message.messages", m.reason.rawValue, m.productID)
                broadcast.yield(m)
            } else {
                NSLog("isim StoreKit: message %@ (%@) displayed (the app does not listen to Message.messages)", m.reason.rawValue, m.productID)
                display(m)
            }
            return      // one at a time
        }
    }

    static func display(_ m: Message) {
        NSLog("isim StoreKit: displaying message %@ (%@)", m.reason.rawValue, m.productID)
        switch m.reason {
        case .billingIssue:
            showing = true
            Task { @MainActor in
                var update = false
                await _SKSheets.present { close in AnyView(_SKBillingIssueView(message: m, update: { update = true; close() }, later: close)) }
                if update {
                    _SKLedger.shared.mutate { d in if var s = d.subscriptions[m.groupID] { s.billingIssue = false; d.subscriptions[m.groupID] = s } }
                    NSLog("isim StoreKit: payment method updated: billing issue of subscription group %@ resolved", m.groupID)
                    _SKLedger.shared.tick()
                }
                showing = false
            }
        case .winBackOffer:
            guard let item = _SKConfig.load().item(m.productID), let offer = item.winBacks.first(where: { $0.offer.id == m.offerID })?.offer else { return }
            showing = true
            Task { @MainActor in
                var subscribe = false
                await _SKSheets.present { close in AnyView(_SKWinBackView(item: item, offer: offer, subscribe: { subscribe = true; close() }, later: close)) }
                if subscribe {
                    do {
                        // bought from the App Store's sheet, not by the app: the app hears of it in Transaction.updates
                        if case .success(let r) = try await Product(item)._purchase(options: [.winBackOffer(offer)], api: nil) {
                            NSLog("isim StoreKit: win-back offer %@ redeemed: %@", offer.id ?? "", item.id)
                            _SKUpdates.transactions.yield(r)
                        }
                    } catch { NSLog("isim StoreKit: win-back offer %@ failed: %@", offer.id ?? "", "\(error)") }
                }
                showing = false
            }
        default:
            break
        }
    }
}

// MARK: - Sheets

struct _SKBillingIssueView: View {
    let message: Message, update: () -> Void, later: () -> Void
    var body: some View {
        let cfg = _SKConfig.load()
        VStack(spacing: 16) {
            _SKAppIcon(size: 64).padding(.top, 32)
            Text(verbatim: "Billing Problem").font(.system(size: 22, weight: .bold)).accessibilityIdentifier("sk-message-title")
            Text(verbatim: "There was a problem renewing your \(cfg.groups[message.groupID] ?? _SKSheets.appName) subscription. To keep using it, update your payment method.")
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button { update() } label: {
                Text(verbatim: "Update Payment Method").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50).background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("sk-billing-update")
            Button("Not Now") { later() }.accessibilityIdentifier("sk-billing-later")
            _SKEnvironmentNote().padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }
}

struct _SKWinBackView: View {
    let item: _SKItem, offer: Product.SubscriptionOffer, subscribe: () -> Void, later: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            _SKAppIcon(size: 72).padding(.top, 32)
            Text(verbatim: "Come Back to \(item.groupName ?? _SKSheets.appName)").font(.system(size: 24, weight: .bold)).multilineTextAlignment(.center)
                .accessibilityIdentifier("sk-message-title")
            Text(verbatim: item.name).font(.system(size: 17, weight: .semibold))
            Text(verbatim: "\(offer.summary), then \(_SKSheets.pricePerPeriod(item))").font(.system(size: 15)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).accessibilityIdentifier("sk-winback-terms")
            Spacer()
            Button { subscribe() } label: {
                Text(verbatim: "Subscribe").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50).background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("sk-winback-subscribe")
            Button("Not Now") { later() }.accessibilityIdentifier("sk-winback-later")
            Text(verbatim: "Renews automatically until canceled.").font(.system(size: 12)).foregroundStyle(.secondary)
            _SKEnvironmentNote().padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }
}
