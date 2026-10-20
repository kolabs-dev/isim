// isim StoreKit: custom subscription store controls (iOS 18) — SubscriptionStoreControlStyleConfiguration, what a
// custom SubscriptionStoreControlStyle gets, and SubscriptionStorePicker, the picker-and-confirm control such styles
// are built from. Self-authored, iOS API names. Adapted: the options are the store page's plans; subscribing buys
// through isim's local StoreKit testing like the built-in controls.
import SwiftUI

/// The plans a custom subscription store control shows, and how to subscribe to them.
public struct SubscriptionStoreControlStyleConfiguration {
    /// A plan, with the offer the store shows for it.
    @dynamicMemberLookup public struct Option: Identifiable {
        public let subscription: Product
        public let activeOffer: Product.SubscriptionOffer?
        public var icon: Icon? { nil }
        public var id: Product.ID { subscription.id }
        let _subscribe: @MainActor () -> Void
        init(subscription: Product, activeOffer: Product.SubscriptionOffer?, subscribe: @escaping @MainActor () -> Void) {
            self.subscription = subscription; self.activeOffer = activeOffer; _subscribe = subscribe
        }
        /// buys the plan (with its active offer), as the store's subscribe button does
        @MainActor public func subscribe() { _subscribe() }
        public subscript<T>(dynamicMember keyPath: KeyPath<Product, T>) -> T { subscription[keyPath: keyPath] }
        public subscript<T>(dynamicMember keyPath: KeyPath<Product.SubscriptionInfo, T>) -> T? { subscription.subscription?[keyPath: keyPath] }
        public subscript<T>(dynamicMember keyPath: KeyPath<Product.SubscriptionInfo, T?>) -> T? { subscription.subscription?[keyPath: keyPath] ?? nil }
    }
    /// A plan as a picker row: the option and whether it is the selected one.
    @dynamicMemberLookup public struct PickerOption: Identifiable {
        public let subscription: Product
        public let activeOffer: Product.SubscriptionOffer?
        public let isSelected: Bool
        public var icon: Icon? { nil }
        public var id: Product.ID { subscription.id }
        public subscript<T>(dynamicMember keyPath: KeyPath<Product, T>) -> T { subscription[keyPath: keyPath] }
        public subscript<T>(dynamicMember keyPath: KeyPath<Product.SubscriptionInfo, T>) -> T? { subscription.subscription?[keyPath: keyPath] }
        public subscript<T>(dynamicMember keyPath: KeyPath<Product.SubscriptionInfo, T?>) -> T? { subscription.subscription?[keyPath: keyPath] ?? nil }
    }
    /// A section of the store's plans (SubscriptionOptionSection), with its header and footer.
    public struct Section: Identifiable {
        public struct ID: Hashable, Sendable { let raw: String }
        public struct Header: View { let view: AnyView; public var body: some View { view } }
        public struct Footer: View { let view: AnyView; public var body: some View { view } }
        public let options: [Option]
        public let header: Header?
        public let footer: Footer?
        public var id: ID { ID(raw: options.map { $0.id }.joined(separator: ",")) }
        init(options: [Option], header: AnyView?, footer: AnyView?) {
            self.options = options; self.header = header.map { Header(view: $0) }; self.footer = footer.map { Footer(view: $0) }
        }
    }
    /// A plan's icon (isim's plans have none: the options' icon is nil).
    @MainActor public struct Icon: View {
        public var body: some View { EmptyView() }
    }
    public let options: [Option]
    public let sections: [Section]
    public let groupDisplayName: String
    /// the plan the subscriber renews into (nil when not subscribed)
    public let autoRenewPreference: Product?
    public let allOptions: [Product]
    public let descriptionVisibility: Visibility
}

/// A picker of subscription plans and a confirmation (usually a subscribe button) for the selected plan (iOS 18).
public struct SubscriptionStorePicker<PickerContent: View, ConfirmationContent: View>: View {
    let configuration: SubscriptionStoreControlStyleConfiguration?
    let header: (() -> PickerContent)?
    let row: ((SubscriptionStoreControlStyleConfiguration.PickerOption) -> PickerContent)?
    let confirmation: (SubscriptionStoreControlStyleConfiguration.Option) -> ConfirmationContent
    let selection: Binding<SubscriptionStoreControlStyleConfiguration.Option?>?
    @State private var chosen: String?
    @Environment(\._skPickerConfiguration) private var inherited

    /// the plans of the store this picker is in, under `pickerContent`
    public init(@ViewBuilder pickerContent: @escaping () -> PickerContent,
                @ViewBuilder confirmation: @escaping (SubscriptionStoreControlStyleConfiguration.Option) -> ConfirmationContent) {
        configuration = nil; header = pickerContent; row = nil; self.confirmation = confirmation; selection = nil
    }
    public init(selection: Binding<SubscriptionStoreControlStyleConfiguration.Option?>, @ViewBuilder pickerContent: @escaping () -> PickerContent,
                @ViewBuilder confirmation: @escaping (SubscriptionStoreControlStyleConfiguration.Option) -> ConfirmationContent) {
        configuration = nil; header = pickerContent; row = nil; self.confirmation = confirmation; self.selection = selection
    }
    /// one row per plan, drawn by `pickerOptionContent`
    public init(_ configuration: SubscriptionStoreControlStyleConfiguration,
                @ViewBuilder pickerOptionContent: @escaping (SubscriptionStoreControlStyleConfiguration.PickerOption) -> PickerContent,
                @ViewBuilder confirmation: @escaping (SubscriptionStoreControlStyleConfiguration.Option) -> ConfirmationContent) {
        self.configuration = configuration; header = nil; row = pickerOptionContent; self.confirmation = confirmation; selection = nil
    }
    public init(_ configuration: SubscriptionStoreControlStyleConfiguration, selection: Binding<SubscriptionStoreControlStyleConfiguration.Option?>,
                @ViewBuilder pickerOptionContent: @escaping (SubscriptionStoreControlStyleConfiguration.PickerOption) -> PickerContent,
                @ViewBuilder confirmation: @escaping (SubscriptionStoreControlStyleConfiguration.Option) -> ConfirmationContent) {
        self.configuration = configuration; header = nil; row = pickerOptionContent; self.confirmation = confirmation; self.selection = selection
    }

    public var body: some View {
        let cfg = configuration ?? inherited
        let options = cfg?.options ?? []
        let selectedID = selection?.wrappedValue?.id ?? chosen ?? cfg?.autoRenewPreference?.id ?? options.first?.id
        let selected = options.first { $0.id == selectedID } ?? options.first
        VStack(spacing: 10) {
            if let header { header() }
            ForEach(options) { o in
                let po = SubscriptionStoreControlStyleConfiguration.PickerOption(subscription: o.subscription, activeOffer: o.activeOffer, isSelected: o.id == selected?.id)
                Button {
                    chosen = o.id
                    selection?.wrappedValue = o
                } label: {
                    if let row { row(po) } else { _SKPickerRow(option: po) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sk-picker-\(o.id)")
            }
            if let selected { confirmation(selected) }
        }
    }
}

/// a plain picker row: a checkmark, the plan and its price
struct _SKPickerRow: View {
    let option: SubscriptionStoreControlStyleConfiguration.PickerOption
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: option.isSelected ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                .foregroundStyle(option.isSelected ? Color.accentColor : Color(uiColor: .tertiaryLabel))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: option.subscription.displayName).font(.system(size: 16, weight: .semibold))
                Text(verbatim: option.subscription.displayPrice).font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct _SKPickerConfigurationKey: EnvironmentKey { static var defaultValue: SubscriptionStoreControlStyleConfiguration? { nil } }
extension EnvironmentValues {
    var _skPickerConfiguration: SubscriptionStoreControlStyleConfiguration? {
        get { self[_SKPickerConfigurationKey.self] } set { self[_SKPickerConfigurationKey.self] = newValue }
    }
}
