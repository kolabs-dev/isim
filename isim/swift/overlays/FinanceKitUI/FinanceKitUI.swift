// isim FinanceKitUI (issue #398): TransactionPicker (the person picks transactions from Wallet's simulated financial
// data to share with the app, without giving it access to the rest) and AddOrderToWalletButton. The financial
// connection UI extension types exist for apps that declare them; isim does not run such extensions.
import SwiftUI
import FinanceKit

/// A button that shows Wallet's transaction picker; the transactions the person picks are written to `selection`.
public struct TransactionPicker<Label: View>: View {
    @Binding var selection: [FinanceKit.Transaction]
    let label: Label
    @State private var shown = false
    public init(selection: Binding<[FinanceKit.Transaction]>, @ViewBuilder label: () -> Label) { _selection = selection; self.label = label() }
    public var body: some View {
        Button { shown = true } label: { label }
            .sheet(isPresented: $shown) {
                _TransactionPickerSheet(done: { picked in
                    selection = picked
                    NSLog("isim FinanceKitUI: picked %d transaction(s)", picked.count)
                    shown = false
                }, cancel: { shown = false })
            }
    }
}

struct _TransactionPickerSheet: View {
    let done: ([FinanceKit.Transaction]) -> Void
    let cancel: () -> Void
    @State private var chosen = Set<UUID>()
    let transactions: [FinanceKit.Transaction] = _FKPicker.all()
    var body: some View {
        NavigationStack {
            List(transactions) { t in
                Button {
                    if chosen.contains(t.id) { chosen.remove(t.id) } else { chosen.insert(t.id) }
                } label: {
                    HStack {
                        Image(systemName: chosen.contains(t.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(verbatim: t.merchantName ?? t.transactionDescription).foregroundStyle(.primary)
                            Text(verbatim: t.transactionDate.formatted(date: .abbreviated, time: .omitted)).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(verbatim: t.transactionAmount.amount.formatted(.currency(code: t.transactionAmount.currencyCode))).foregroundStyle(.primary)
                    }
                }
                .accessibilityIdentifier("txn-\(t.merchantName ?? t.transactionDescription)")
            }
            .overlay { if transactions.isEmpty { Text(verbatim: "No Transactions").foregroundStyle(.secondary) } }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() }.accessibilityIdentifier("txn-cancel") }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { done(transactions.filter { chosen.contains($0.id) }) }.disabled(chosen.isEmpty).accessibilityIdentifier("txn-share")
                }
            }
        }
    }
}

/// the picker reads Wallet's data itself: the app needs no FinanceKit authorization for what the person picks
enum _FKPicker {
    static func all() -> [FinanceKit.Transaction] {
        let env = ProcessInfo.processInfo.environment
        let root = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        let file = (root as NSString).appendingPathComponent("Library/isim/FinanceKit/data.json")
        struct Data: Decodable { var transactions: [FinanceKit.Transaction] }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        guard let raw = FileManager.default.contents(atPath: file), let data = try? d.decode(Data.self, from: raw) else { return [] }
        return data.transactions.sorted { $0.transactionDate > $1.transactionDate }
    }
}

public struct AddOrderToWalletButtonStyle: Hashable, Sendable {
    let outline: Bool
    public static let black = AddOrderToWalletButtonStyle(outline: false)
    public static let blackOutline = AddOrderToWalletButtonStyle(outline: true)
}

private struct _AddOrderStyleKey: EnvironmentKey { static let defaultValue = AddOrderToWalletButtonStyle.black }
extension EnvironmentValues {
    var _addOrderToWalletButtonStyle: AddOrderToWalletButtonStyle {
        get { self[_AddOrderStyleKey.self] }
        set { self[_AddOrderStyleKey.self] = newValue }
    }
}
extension View {
    public func addOrderToWalletButtonStyle(_ style: AddOrderToWalletButtonStyle) -> some View { environment(\._addOrderToWalletButtonStyle, style) }
}

/// "Add to Apple Wallet" for an order: saves the signed archive with FinanceStore.saveOrder
public struct AddOrderToWalletButton: View {
    let signedArchive: Data
    let onCompletion: (Result<FinanceStore.SaveOrderResult, any Error>) -> Void
    @Environment(\._addOrderToWalletButtonStyle) private var style
    public init(signedArchive: Data, onCompletion: @escaping (Result<FinanceStore.SaveOrderResult, any Error>) -> Void) {
        self.signedArchive = signedArchive; self.onCompletion = onCompletion
    }
    public var body: some View {
        Button {
            Task { @MainActor in
                do { onCompletion(.success(try await FinanceStore.shared.saveOrder(signedArchive: signedArchive))) } catch { onCompletion(.failure(error)) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: "Add to Apple Wallet").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(style.outline ? Color.black : Color.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(style.outline ? Color.white : Color.black, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: style.outline ? 1 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-order-to-wallet")
    }
}

// MARK: - financial connection UI extensions (declared; isim does not run them)

public typealias FinancialConnectionExtensionAuthorizationParams = [String: String]

public struct FinancialConnectionExtensionAuthorizationResult: Sendable {
    public let params: FinancialConnectionExtensionAuthorizationParams
    public init(params: FinancialConnectionExtensionAuthorizationParams) { self.params = params }
}

public struct FinancialConnectionExtensionAuthorizationRequest: Sendable {
    public typealias CompletionHandlerResult = Result<FinancialConnectionExtensionAuthorizationResult, any Error>
    public typealias CompletionHandler = @Sendable (CompletionHandlerResult) -> Void
    public var params: FinancialConnectionExtensionAuthorizationParams
    let completion: CompletionHandler
    public func complete(authorizationResult: FinancialConnectionExtensionAuthorizationResult) { completion(.success(authorizationResult)) }
    public func complete(error: any Error) { completion(.failure(error)) }
}

public protocol FinancialConnectionUIExtensionProviding {
    func authorize(_ request: FinancialConnectionExtensionAuthorizationRequest)
}

public protocol FinancialConnectionUIExtensionScene {}

public protocol FinancialConnectionUIExtension {
    associatedtype Body: FinancialConnectionUIExtensionScene
    var body: Self.Body { get }
}

public struct FinancialConnectionUIExtensionAuthorizationScene<Content: View>: FinancialConnectionUIExtensionScene {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
}
