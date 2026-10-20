//
//  HelloStoreTestingTests.swift
//  HelloStoreTestingTests
//
//  StoreKit tests with SKTestSession (StoreKitTest): purchases without dialogs, Ask to Buy, interrupted purchases,
//  subscriptions (renewal, expiration, auto-renew), refunds and the session's transaction list.
//

import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import HelloStoreTesting

@MainActor @Suite(.serialized) struct StoreKitSessionTests {
    let session: SKTestSession
    let store = Store()

    init() throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
    }

    func product(_ id: String) async throws -> Product {
        try #require(try await Product.products(for: [id]).first)
    }

    @Test func productsFromTheConfiguration() async throws {
        let ids = ["dev.isim.store.coins", Store.fullGame, Store.plusMonthly, "dev.isim.store.plus.yearly", "dev.isim.store.premium.monthly"]
        let products = try await Product.products(for: ids)
        #expect(products.count == 5)
        #expect(session.storefront == "USA")
    }

    @Test func purchaseAndRefund() async throws {
        let result = try await product(Store.fullGame).purchase()
        guard case .success(.verified(let t)) = result else { Issue.record("not purchased: \(result)"); return }
        await t.finish()
        #expect(await store.ownsFullGame())
        let txs = session.allTransactions()
        #expect(txs.map(\.productIdentifier) == [Store.fullGame])
        try session.refundTransaction(identifier: txs[0].identifier)
        #expect(session.allTransactions()[0].refunded)
        #expect(await store.ownsFullGame() == false)
    }

    @Test func askToBuy() async throws {
        session.askToBuyEnabled = true
        let result = try await product(Store.fullGame).purchase()
        guard case .pending = result else { Issue.record("not pending: \(result)"); return }
        let request = try #require(session.allTransactions().first)
        #expect(request.pendingAskToBuyConfirmation && request.state == .deferred)
        #expect(await store.ownsFullGame() == false)
        try session.approveAskToBuyTransaction(identifier: request.identifier)
        #expect(await store.ownsFullGame())
        #expect(session.allTransactions().contains { !$0.pendingAskToBuyConfirmation && $0.productIdentifier == Store.fullGame })
        #expect(throws: (any Error).self) { try session.declineAskToBuyTransaction(identifier: request.identifier) }
    }

    @Test func interruptedPurchase() async throws {
        session.interruptedPurchasesEnabled = true
        guard case .pending = try await product(Store.fullGame).purchase() else { Issue.record("not interrupted"); return }
        let t = try #require(session.allTransactions().first)
        #expect(t.hasPurchaseIssue)
        try session.resolveIssueForTransaction(identifier: t.identifier)
        #expect(await store.ownsFullGame())
    }

    @Test func subscriptionLifecycle() async throws {
        let t = try await session.buyProduct(identifier: Store.plusMonthly)
        #expect(t.productID == Store.plusMonthly)
        #expect(await store.plusState() == .subscribed)
        try session.disableAutoRenewForTransaction(identifier: Int(t.id))
        #expect(session.allTransactions().first { $0.productIdentifier == Store.plusMonthly }?.autoRenewingEnabled == false)
        try session.enableAutoRenewForTransaction(identifier: Int(t.id))
        try session.forceRenewalOfSubscription(productIdentifier: Store.plusMonthly)
        #expect(session.allTransactions().filter { $0.productIdentifier == Store.plusMonthly }.count == 2, "renewed")
        try session.expireSubscription(productIdentifier: Store.plusMonthly)
        #expect(await store.plusState() == .expired)
    }

    @Test func timeRateAndClearing() async throws {
        session.timeRate = .oneRenewalEveryTwoSeconds
        #expect(session.timeRate == .oneRenewalEveryTwoSeconds)
        _ = try await session.buyProduct(identifier: Store.fullGame)
        #expect(session.allTransactions().count == 1)
        session.clearTransactions()
        #expect(session.allTransactions().isEmpty)
        #expect(throws: (any Error).self) { try session.refundTransaction(identifier: 999) }
    }
}
