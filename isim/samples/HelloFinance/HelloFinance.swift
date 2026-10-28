// Sample: FinanceKit on isim (issue #398). It asks for access to Wallet's financial data (isim's simulated set:
// `isim finance seed`), lists the accounts, balances and pending transactions (TransactionQuery predicates), follows
// one account's transaction history as `isim finance add-transaction` adds to it, lets the person pick transactions
// with FinanceKitUI's TransactionPicker, and adds an order to Wallet with AddOrderToWalletButton (an .order archive
// made here). Everything is printed; tests/ui/test_finance.py checks it.
import SwiftUI
import FinanceKit
import FinanceKitUI

@main
struct HelloFinanceApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State private var status = "ready"
    @State private var picked: [FinanceKit.Transaction] = []
    var body: some View {
        List {
            Text(status).accessibilityIdentifier("status")
            Button("Read finances") { Task { await read() } }.accessibilityIdentifier("read")
            TransactionPicker(selection: $picked) { Text("Pick transactions") }.accessibilityIdentifier("pick")
            AddOrderToWalletButton(signedArchive: orderArchive()) { result in
                switch result {
                case .success(let r): report("order: \(r)")
                case .failure(let e): report("order: error \(e)")
                }
            }
            .addOrderToWalletButtonStyle(.blackOutline)
        }
        .onChange(of: picked.count) { report("picked: \(picked.map { $0.merchantName ?? "-" }.sorted().joined(separator: ","))") }
        .task { report("data available \(FinanceStore.isDataAvailable(.financialData)) orders \(FinanceStore.isDataAvailable(.orders))") }
    }

    func report(_ s: String) { print(s); status = s }

    func read() async {
        let store = FinanceStore.shared
        do {
            let status = try await store.requestAuthorization()
            report("authorization: \(status)")
            guard status == .authorized else { return }
            let accounts = try await store.accounts(query: AccountQuery(sortDescriptors: [SortDescriptor(\.displayName)]))
            report("accounts: \(accounts.map { "\($0.displayName) \($0.liabilityAccount != nil ? "liability" : "asset")" }.joined(separator: ", "))")
            if let card = accounts.first(where: { $0.liabilityAccount != nil })?.liabilityAccount {
                report("card limit \(card.creditInformation.creditLimit.map { "\($0.amount)" } ?? "-")")
            }
            let balances = try await store.accountBalances(query: AccountBalanceQuery())
            report("balances: \(balances.count) booked \(balances.allSatisfy { $0.booked != nil })")
            let pending = try await store.transactions(query: TransactionQuery(predicate: TransactionQuery.predicate(forStatuses: [.pending])))
            report("pending: \(pending.map { $0.merchantName ?? "-" }.joined(separator: ","))")
            let groceries = try await store.transactions(query: TransactionQuery(
                sortDescriptors: [SortDescriptor(\.transactionDate, order: .reverse)],
                predicate: TransactionQuery.predicate(forMerchantCategoryCodes: [MerchantCategoryCode(rawValue: 5411)]), limit: 5))
            report("groceries: \(groceries.map { "\($0.merchantName ?? "-") \($0.transactionAmount.amount)" }.joined(separator: ","))")
            guard let id = accounts.first(where: { $0.liabilityAccount != nil })?.id else { return }
            var first = true
            for try await changes in store.transactionHistory(forAccountID: id, isMonitoring: true) {
                if first { report("history: \(changes.inserted.count) at first"); first = false; continue }
                report("history: inserted \(changes.inserted.map { $0.merchantName ?? "-" }.joined(separator: ","))")
                break
            }
        } catch {
            report("finance error: \(error)")
        }
    }

    /// a minimal .order archive (stored ZIP entries: order.json and an empty signature)
    func orderArchive() -> Data {
        let order = """
        {"schemaVersion":1,"orderTypeIdentifier":"order.dev.isim.samples.shop","orderIdentifier":"A-1001","orderManagementURL":"https://shop.isim.example/orders/A-1001","createdAt":"2026-10-28T10:00:00Z","updatedAt":"2026-10-28T10:00:00Z","status":"open","merchant":{"displayName":"isim Shop","merchantIdentifier":"merchant.dev.isim.shop"}}
        """
        return _zip(["order.json": Data(order.utf8), "signature": Data()])
    }
}

/// writes stored (uncompressed) ZIP entries
func _zip(_ files: [String: Data]) -> Data {
    func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in d { c ^= UInt32(b); for _ in 0..<8 { c = (c >> 1) ^ (0xEDB8_8320 & (0 &- (c & 1))) } }
        return ~c
    }
    func le16(_ v: Int) -> [UInt8] { [UInt8(v & 0xff), UInt8(v >> 8 & 0xff)] }
    func le32(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xff), UInt8(v >> 8 & 0xff), UInt8(v >> 16 & 0xff), UInt8(v >> 24 & 0xff)] }
    var out = [UInt8](), central = [UInt8]()
    for (name, data) in files.sorted(by: { $0.key < $1.key }) {
        let n = Array(name.utf8), crc = crc32(data), size = UInt32(data.count), offset = UInt32(out.count)
        out += le32(0x0403_4b50) + le16(10) + le16(0) + le16(0) + le16(0) + le16(0) + le32(crc) + le32(size) + le32(size) + le16(n.count) + le16(0) + n + [UInt8](data)
        central += le32(0x0201_4b50) + le16(20) + le16(10) + le16(0) + le16(0) + le16(0) + le16(0) + le32(crc) + le32(size) + le32(size)
            + le16(n.count) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0) + le32(offset) + n
    }
    let start = UInt32(out.count)
    out += central + le32(0x0605_4b50) + le16(0) + le16(0) + le16(files.count) + le16(files.count) + le32(UInt32(central.count)) + le32(start) + le16(0)
    return Data(out)
}
