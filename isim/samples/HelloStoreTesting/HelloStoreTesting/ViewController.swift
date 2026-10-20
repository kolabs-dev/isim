//
//  ViewController.swift
//  HelloStoreTesting
//
//  Sample: StoreKit unit tests with StoreKitTest's SKTestSession on isim. The app has a small store model
//  (Store), which the hosted tests in HelloStoreTestingTests drive against Products.storekit.
//

import UIKit
import StoreKit

/// what the app sells: the full game and the Plus subscription
@MainActor final class Store {
    static let fullGame = "dev.isim.store.full_game"
    static let plusMonthly = "dev.isim.store.plus.monthly"
    /// whether the customer owns the full game (a current entitlement)
    func ownsFullGame() async -> Bool {
        if case .verified? = await Transaction.currentEntitlement(for: Store.fullGame) { return true }
        return false
    }
    /// the Plus subscription's state, if any
    func plusState() async -> Product.SubscriptionInfo.RenewalState? {
        try? await Product.SubscriptionInfo.status(for: "21000001").first?.state
    }
}

class ViewController: UIViewController {
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.frame = view.bounds.insetBy(dx: 20, dy: 200)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Run the StoreKit tests:\nisim test -project HelloStoreTesting.xcodeproj -scheme HelloStoreTesting"
        view.addSubview(label)
    }
}
