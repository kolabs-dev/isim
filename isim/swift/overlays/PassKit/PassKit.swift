// isim PassKit (Apple Pay): payment requests, summary items, shipping methods, contacts, payments and their tokens,
// authorization results, request updates and errors. Self-authored, iOS API names.
// Adapted: payments go through isim's simulated Apple Pay sheet (PaymentSheet.swift) with the device's test cards;
// a payment's token is isim's own test token, not Apple's (PKPaymentToken.paymentData), so nothing can be charged.
import Foundation
import Contacts

// MARK: - Networks, capabilities, fields

/// A payment network (a card brand).
public struct PKPaymentNetwork: RawRepresentable, Hashable, Equatable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public static let amex = PKPaymentNetwork("AmEx")
    public static let bancontact = PKPaymentNetwork("Bancontact")
    @available(*, deprecated, renamed: "pagoBancomat") public static let bancomat = PKPaymentNetwork("Bancomat")
    public static let bankAxept = PKPaymentNetwork("BankAxept")
    public static let barcode = PKPaymentNetwork("Barcode")
    @available(*, deprecated, renamed: "cartesBancaires") public static let carteBancaire = PKPaymentNetwork("CarteBancaire")
    @available(*, deprecated, renamed: "cartesBancaires") public static let carteBancaires = PKPaymentNetwork("CarteBancaires")
    public static let cartesBancaires = PKPaymentNetwork("CartesBancaires")
    public static let chinaUnionPay = PKPaymentNetwork("ChinaUnionPay")
    public static let conecs = PKPaymentNetwork("Conecs")
    public static let dankort = PKPaymentNetwork("Dankort")
    public static let discover = PKPaymentNetwork("Discover")
    public static let eftpos = PKPaymentNetwork("Eftpos")
    public static let elCorteIngles = PKPaymentNetwork("ElCorteIngles")
    public static let elcard = PKPaymentNetwork("Elcard")
    public static let electron = PKPaymentNetwork("Electron")
    public static let elo = PKPaymentNetwork("Elo")
    public static let girocard = PKPaymentNetwork("Girocard")
    public static let himyan = PKPaymentNetwork("Himyan")
    public static let humo = PKPaymentNetwork("Humo")
    public static let idCredit = PKPaymentNetwork("iD")
    public static let interac = PKPaymentNetwork("Interac")
    public static let jaywan = PKPaymentNetwork("Jaywan")
    public static let JCB = PKPaymentNetwork("JCB")
    public static let maal = PKPaymentNetwork("Maal")
    public static let mada = PKPaymentNetwork("mada")
    public static let maestro = PKPaymentNetwork("Maestro")
    public static let masterCard = PKPaymentNetwork("MasterCard")
    public static let meeza = PKPaymentNetwork("Meeza")
    public static let mir = PKPaymentNetwork("Mir")
    public static let myDebit = PKPaymentNetwork("MyDebit")
    public static let NAPAS = PKPaymentNetwork("Napas")
    public static let nanaco = PKPaymentNetwork("Nanaco")
    public static let pagoBancomat = PKPaymentNetwork("PagoBancomat")
    public static let payPak = PKPaymentNetwork("PayPak")
    public static let postFinance = PKPaymentNetwork("PostFinance")
    public static let privateLabel = PKPaymentNetwork("PrivateLabel")
    public static let quicPay = PKPaymentNetwork("QUICPay")
    public static let ruPay = PKPaymentNetwork("RuPay")
    public static let suica = PKPaymentNetwork("Suica")
    public static let tmoney = PKPaymentNetwork("TMoney")
    public static let uzCard = PKPaymentNetwork("UzCard")
    public static let verve = PKPaymentNetwork("Verve")
    public static let visa = PKPaymentNetwork("Visa")
    public static let vPay = PKPaymentNetwork("VPay")
    public static let waon = PKPaymentNetwork("WAON")
}

/// What a merchant's payment processor supports.
public struct PKMerchantCapability: OptionSet, Hashable, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static var threeDSecure: PKMerchantCapability { PKMerchantCapability(rawValue: 1 << 0) }
    public static var emv: PKMerchantCapability { PKMerchantCapability(rawValue: 1 << 1) }
    public static var credit: PKMerchantCapability { PKMerchantCapability(rawValue: 1 << 2) }
    public static var debit: PKMerchantCapability { PKMerchantCapability(rawValue: 1 << 3) }
    public static var instantFundsOut: PKMerchantCapability { PKMerchantCapability(rawValue: 1 << 7) }
    @available(*, deprecated, renamed: "threeDSecure") public static var capability3DS: PKMerchantCapability { .threeDSecure }
    @available(*, deprecated, renamed: "emv") public static var capabilityEMV: PKMerchantCapability { .emv }
    @available(*, deprecated, renamed: "credit") public static var capabilityCredit: PKMerchantCapability { .credit }
    @available(*, deprecated, renamed: "debit") public static var capabilityDebit: PKMerchantCapability { .debit }
}

/// A contact detail the payment sheet asks for.
public struct PKContactField: RawRepresentable, Hashable, Equatable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let postalAddress = PKContactField(rawValue: "post")
    public static let emailAddress = PKContactField(rawValue: "email")
    public static let phoneNumber = PKContactField(rawValue: "phone")
    public static let name = PKContactField(rawValue: "name")
    public static let phoneticName = PKContactField(rawValue: "phoneticName")
}

public enum PKShippingType: UInt, Sendable {
    case shipping = 0, delivery, storePickup, servicePickup
}

public enum PKShippingContactEditingMode: UInt, Sendable {
    case available = 1, storePickup = 2
    @available(*, deprecated, renamed: "available") public static var enabled: PKShippingContactEditingMode { .available }
}

public enum PKPaymentSummaryItemType: UInt, Sendable {
    case final = 0, pending
}

public enum PKPaymentMethodType: UInt, Sendable {
    case unknown = 0, debit, credit, prepaid, store, eMoney
}

public enum PKPaymentAuthorizationStatus: Int, Sendable {
    case success = 0, failure
    @available(*, deprecated, message: "Use PKPaymentAuthorizationResult with errors") case invalidBillingPostalAddress
    @available(*, deprecated, message: "Use PKPaymentAuthorizationResult with errors") case invalidShippingPostalAddress
    @available(*, deprecated, message: "Use PKPaymentAuthorizationResult with errors") case invalidShippingContact
    case pinRequired, pinIncorrect, pinLockout
}

// MARK: - Summary items and shipping methods

/// A line of the payment sheet's summary: the last item is the total, its label the business's name.
@objc(PKPaymentSummaryItem) open class PKPaymentSummaryItem: NSObject {
    @objc open var label: String
    @objc open var amount: NSDecimalNumber
    open var type: PKPaymentSummaryItemType = .final
    @objc public override init() { label = ""; amount = .zero; super.init() }
    @objc public convenience init(label: String, amount: NSDecimalNumber) {
        self.init(); self.label = label; self.amount = amount
    }
    public convenience init(label: String, amount: NSDecimalNumber, type: PKPaymentSummaryItemType) {
        self.init(label: label, amount: amount); self.type = type
    }
    @objc open override var description: String { "<\(Swift.type(of: self)) \(label): \(amount)\(type == .pending ? " (pending)" : "")>" }
}

/// A payment billed on a schedule (a subscription).
@objc(PKRecurringPaymentSummaryItem) open class PKRecurringPaymentSummaryItem: PKPaymentSummaryItem {
    @objc open var startDate: Date?
    @objc open var intervalUnit: NSCalendar.Unit = .month
    @objc open var intervalCount: Int = 1
    @objc open var endDate: Date?
}

/// A payment billed later, on a date.
@objc(PKDeferredPaymentSummaryItem) open class PKDeferredPaymentSummaryItem: PKPaymentSummaryItem {
    @objc open var deferredDate = Date()
}

/// A payment that reloads a stored-value balance when it falls below a threshold.
@objc(PKAutomaticReloadPaymentSummaryItem) open class PKAutomaticReloadPaymentSummaryItem: PKPaymentSummaryItem {
    @objc open var thresholdAmount: NSDecimalNumber = .zero
}

/// The start and end of a shipping method's delivery estimate.
@objc(PKDateComponentsRange) open class PKDateComponentsRange: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let startDateComponents: DateComponents
    @objc public let endDateComponents: DateComponents
    @objc public init?(start: DateComponents, end: DateComponents) {
        startDateComponents = start; endDateComponents = end
        super.init()
    }
    @objc public convenience init?(startDateComponents: DateComponents, endDateComponents: DateComponents) {
        self.init(start: startDateComponents, end: endDateComponents)
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) {
        coder.encode(startDateComponents as NSDateComponents, forKey: "start")
        coder.encode(endDateComponents as NSDateComponents, forKey: "end")
    }
    @objc public required init?(coder: NSCoder) {
        guard let s = coder.decodeObject(of: NSDateComponents.self, forKey: "start"), let e = coder.decodeObject(of: NSDateComponents.self, forKey: "end") else { return nil }
        startDateComponents = s as DateComponents; endDateComponents = e as DateComponents
        super.init()
    }
    @objc public func copy(with zone: NSZone? = nil) -> Any { self }
}

/// A way to ship the order, with its cost.
@objc(PKShippingMethod) open class PKShippingMethod: PKPaymentSummaryItem {
    @objc open var identifier: String?
    @objc open var detail: String?
    @objc open var dateComponentsRange: PKDateComponentsRange?
}

// MARK: - Recurring, deferred and automatic reload requests, multi-token contexts

@objc(PKRecurringPaymentRequest) open class PKRecurringPaymentRequest: NSObject {
    @objc open var paymentDescription: String
    @objc open var regularBilling: PKRecurringPaymentSummaryItem
    @objc open var trialBilling: PKRecurringPaymentSummaryItem?
    @objc open var billingAgreement: String?
    @objc open var managementURL: URL
    @objc open var tokenNotificationURL: URL?
    @objc public init(paymentDescription: String, regularBilling: PKRecurringPaymentSummaryItem, managementURL: URL) {
        self.paymentDescription = paymentDescription; self.regularBilling = regularBilling; self.managementURL = managementURL
        super.init()
    }
}

@objc(PKDeferredPaymentRequest) open class PKDeferredPaymentRequest: NSObject {
    @objc open var paymentDescription: String
    @objc open var deferredBilling: PKDeferredPaymentSummaryItem
    @objc open var billingAgreement: String?
    @objc open var managementURL: URL
    @objc open var tokenNotificationURL: URL?
    @objc open var freeCancellationDate: Date?
    @objc open var freeCancellationDateTimeZone: TimeZone?
    @objc public init(paymentDescription: String, deferredBilling: PKDeferredPaymentSummaryItem, managementURL: URL) {
        self.paymentDescription = paymentDescription; self.deferredBilling = deferredBilling; self.managementURL = managementURL
        super.init()
    }
}

@objc(PKAutomaticReloadPaymentRequest) open class PKAutomaticReloadPaymentRequest: NSObject {
    @objc open var paymentDescription: String
    @objc open var automaticReloadBilling: PKAutomaticReloadPaymentSummaryItem
    @objc open var billingAgreement: String?
    @objc open var managementURL: URL
    @objc open var tokenNotificationURL: URL?
    @objc public init(paymentDescription: String, automaticReloadBilling: PKAutomaticReloadPaymentSummaryItem, managementURL: URL) {
        self.paymentDescription = paymentDescription; self.automaticReloadBilling = automaticReloadBilling; self.managementURL = managementURL
        super.init()
    }
}

/// One merchant's part of a payment with several tokens (a marketplace order).
@objc(PKPaymentTokenContext) open class PKPaymentTokenContext: NSObject {
    @objc open var merchantIdentifier: String
    @objc open var externalIdentifier: String
    @objc open var merchantName: String
    @objc open var merchantDomain: String?
    @objc open var amount: NSDecimalNumber
    @objc public init(merchantIdentifier: String, externalIdentifier: String, merchantName: String, merchantDomain: String?, amount: NSDecimalNumber) {
        self.merchantIdentifier = merchantIdentifier; self.externalIdentifier = externalIdentifier; self.merchantName = merchantName
        self.merchantDomain = merchantDomain; self.amount = amount
        super.init()
    }
}

// MARK: - Contacts

/// The customer's name, address, email and phone, as the payment sheet hands them to the app.
@objc(PKContact) open class PKContact: NSObject, @unchecked Sendable {
    @objc open var name: PersonNameComponents?
    @objc open var postalAddress: CNPostalAddress?
    @objc open var emailAddress: String?
    @objc open var phoneNumber: CNPhoneNumber?
    @available(*, deprecated, message: "Use postalAddress.subLocality")
    @objc open var supplementarySubLocality: String?
    @objc public override init() { super.init() }
    @objc open override var description: String {
        let a = postalAddress.map { [$0.street, $0.city, $0.state, $0.postalCode, $0.isoCountryCode].filter { !$0.isEmpty }.joined(separator: ", ") }
        let n = name.map { PersonNameComponentsFormatter().string(from: $0) }
        return "<PKContact" + [n, a, emailAddress, phoneNumber?.stringValue].compactMap { $0 }.map { " " + $0 }.joined() + ">"
    }
}

// MARK: - Payment request

/// What the customer is asked to pay, and how.
@objc(PKPaymentRequest) open class PKPaymentRequest: NSObject {
    @objc open var merchantIdentifier = ""
    @objc open var countryCode = ""
    open var supportedNetworks: [PKPaymentNetwork] = []
    open var merchantCapabilities: PKMerchantCapability = .threeDSecure
    @objc open var supportedCountries: Set<String>?
    @objc open var currencyCode = ""
    @objc open var paymentSummaryItems: [PKPaymentSummaryItem] = []
    open var requiredBillingContactFields: Set<PKContactField> = []
    @objc open var billingContact: PKContact?
    open var requiredShippingContactFields: Set<PKContactField> = []
    @objc open var shippingContact: PKContact?
    @objc open var shippingMethods: [PKShippingMethod]?
    open var shippingType: PKShippingType = .shipping
    open var shippingContactEditingMode: PKShippingContactEditingMode = .available
    @objc open var applicationData: Data?
    @objc open var couponCode: String?
    @objc open var supportsCouponCode = false
    @objc open var recurringPaymentRequest: PKRecurringPaymentRequest?
    @objc open var deferredPaymentRequest: PKDeferredPaymentRequest?
    @objc open var automaticReloadPaymentRequest: PKAutomaticReloadPaymentRequest?
    @objc open var multiTokenContexts: [PKPaymentTokenContext] = []
    @objc open var attributionIdentifier: String?
    @objc open var isDelegatedRequest = false
    @objc open var unsupportedPrimaryAccountIdentifiers: [String] = []
    @objc public override init() { super.init() }

    /// the networks the device can pay with: those of its test cards
    open class func availableNetworks() -> [PKPaymentNetwork] { _PKWallet.cards.map(\.network) }

    open class func paymentContactInvalidError(withContactField field: PKContactField, localizedDescription: String?) -> Error {
        PKPaymentError(.shippingContactInvalidError, localizedDescription, [PKPaymentErrorKey.contactFieldUserInfoKey.rawValue: field.rawValue])
    }
    @objc open class func paymentShippingAddressInvalidError(withKey postalAddressKey: String, localizedDescription: String?) -> Error {
        PKPaymentError(.shippingContactInvalidError, localizedDescription, [PKPaymentErrorKey.contactFieldUserInfoKey.rawValue: PKContactField.postalAddress.rawValue,
                                                                            PKPaymentErrorKey.postalAddressUserInfoKey.rawValue: postalAddressKey])
    }
    @objc open class func paymentBillingAddressInvalidError(withKey postalAddressKey: String, localizedDescription: String?) -> Error {
        PKPaymentError(.billingContactInvalidError, localizedDescription, [PKPaymentErrorKey.contactFieldUserInfoKey.rawValue: PKContactField.postalAddress.rawValue,
                                                                           PKPaymentErrorKey.postalAddressUserInfoKey.rawValue: postalAddressKey])
    }
    @objc open class func paymentShippingAddressUnserviceableError(withLocalizedDescription localizedDescription: String?) -> Error {
        PKPaymentError(.shippingAddressUnserviceableError, localizedDescription, [:])
    }
    @objc public static func paymentCouponCodeInvalidError(localizedDescription: String?) -> Error {
        PKPaymentError(.couponCodeInvalidError, localizedDescription, [:])
    }
    @objc public static func paymentCouponCodeExpiredError(localizedDescription: String?) -> Error {
        PKPaymentError(.couponCodeExpiredError, localizedDescription, [:])
    }

    /// why the sheet cannot show this request (iOS raises or refuses to present), nil when it can
    @objc var problem: String? {
        if merchantIdentifier.isEmpty { return "merchantIdentifier is empty" }
        if countryCode.count != 2 { return "countryCode must be a two-letter ISO 3166 code" }
        if currencyCode.count != 3 { return "currencyCode must be a three-letter ISO 4217 code" }
        if supportedNetworks.isEmpty { return "supportedNetworks is empty" }
        if paymentSummaryItems.isEmpty { return "paymentSummaryItems is empty" }
        if paymentSummaryItems.last!.amount.compare(NSDecimalNumber.zero) == .orderedAscending { return "the total is negative" }
        return nil
    }
}

// MARK: - Errors

public let PKPaymentErrorDomain = "PKPaymentErrorDomain"

/// The keys of a PKPaymentError's userInfo.
public struct PKPaymentErrorKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let contactFieldUserInfoKey = PKPaymentErrorKey(rawValue: "PKPaymentErrorContactField")
    public static let postalAddressUserInfoKey = PKPaymentErrorKey(rawValue: "PKPaymentErrorPostalAddress")
}

/// An error the app reports to the payment sheet (an invalid address, a coupon that expired, ...).
public struct PKPaymentError: CustomNSError, Hashable, @unchecked Sendable {
    public enum Code: Int, Sendable, Equatable {
        case unknownError = -1
        case shippingContactInvalidError = 1, billingContactInvalidError, shippingAddressUnserviceableError
        case couponCodeInvalidError, couponCodeExpiredError
    }
    public let _nsError: NSError
    public init(_nsError: NSError) { self._nsError = _nsError }
    public init(_ code: Code, userInfo: [String: Any] = [:]) {
        _nsError = NSError(domain: PKPaymentErrorDomain, code: code.rawValue, userInfo: userInfo)
    }
    init(_ code: Code, _ description: String?, _ info: [String: Any]) {
        var u = info
        if let d = description { u[NSLocalizedDescriptionKey] = d }
        self.init(code, userInfo: u)
    }
    public var code: Code { Code(rawValue: _nsError.code) ?? .unknownError }
    public static var errorDomain: String { PKPaymentErrorDomain }
    public var errorCode: Int { _nsError.code }
    public var errorUserInfo: [String: Any] { _nsError.userInfo }
    public var userInfo: [String: Any] { _nsError.userInfo }
    public var localizedDescription: String { _nsError.localizedDescription }
    public static func == (a: PKPaymentError, b: PKPaymentError) -> Bool { a._nsError.isEqual(b._nsError) }
    public func hash(into h: inout Hasher) { h.combine(_nsError.code) }

    public static var unknownError: Code { .unknownError }
    public static var shippingContactInvalidError: Code { .shippingContactInvalidError }
    public static var billingContactInvalidError: Code { .billingContactInvalidError }
    public static var shippingAddressUnserviceableError: Code { .shippingAddressUnserviceableError }
    public static var couponCodeInvalidError: Code { .couponCodeInvalidError }
    public static var couponCodeExpiredError: Code { .couponCodeExpiredError }

    /// the contact field an error is about (contactFieldUserInfoKey)
    var field: PKContactField? { (userInfo[PKPaymentErrorKey.contactFieldUserInfoKey.rawValue] as? String).map(PKContactField.init(rawValue:)) }
}

// MARK: - Payment methods, tokens, payments

/// The card the customer pays with, as the app sees it (no card number).
@objc(PKPaymentMethod) open class PKPaymentMethod: NSObject, @unchecked Sendable {
    @objc open internal(set) var displayName: String?
    open internal(set) var network: PKPaymentNetwork?
    open internal(set) var type: PKPaymentMethodType = .unknown
    @objc open internal(set) var billingAddress: CNContact?
    @objc public override init() { super.init() }
    @objc open override var description: String { "<PKPaymentMethod \(displayName ?? "?") \(network?.rawValue ?? "?") type=\(type.rawValue)>" }
}

/// The payment's credentials for the merchant's payment processor. On isim it is a test token, not Apple's: its
/// paymentData is JSON with "version": "isim-test" and no cryptogram, so a payment processor rejects it.
@objc(PKPaymentToken) open class PKPaymentToken: NSObject, @unchecked Sendable {
    @objc open internal(set) var paymentMethod: PKPaymentMethod
    @objc open internal(set) var transactionIdentifier: String
    @objc open internal(set) var paymentData: Data
    @objc @available(*, deprecated, message: "Use paymentMethod.displayName") open var paymentInstrumentName: String { paymentMethod.displayName ?? "" }
    @objc @available(*, deprecated, message: "Use paymentMethod.network") open var paymentNetwork: String { paymentMethod.network?.rawValue ?? "" }
    @objc init(paymentMethod: PKPaymentMethod, transactionIdentifier: String, paymentData: Data) {
        self.paymentMethod = paymentMethod; self.transactionIdentifier = transactionIdentifier; self.paymentData = paymentData
        super.init()
    }
}

/// An authorized payment: the token and the contacts and shipping method the customer chose.
@objc(PKPayment) open class PKPayment: NSObject, @unchecked Sendable {
    @objc open internal(set) var token: PKPaymentToken
    @objc open internal(set) var billingContact: PKContact?
    @objc open internal(set) var shippingContact: PKContact?
    @objc open internal(set) var shippingMethod: PKShippingMethod?
    @objc init(token: PKPaymentToken) { self.token = token; super.init() }
}

// MARK: - Results and request updates

/// The app's answer to an authorized payment: success, or failure with what to fix.
@objc(PKPaymentAuthorizationResult) open class PKPaymentAuthorizationResult: NSObject, @unchecked Sendable {
    open var status: PKPaymentAuthorizationStatus
    @objc open var errors: [Error]!
    /// the Wallet order the payment creates (isim's Wallet records it)
    @objc open var orderDetails: PKPaymentOrderDetails?
    public init(status: PKPaymentAuthorizationStatus, errors: [Error]?) {
        self.status = status; self.errors = errors ?? []
        super.init()
    }
    @objc public override convenience init() { self.init(status: .success, errors: nil) }
}

/// New summary items (and shipping methods) for the sheet after the customer changed something.
@objc(PKPaymentRequestUpdate) open class PKPaymentRequestUpdate: NSObject, @unchecked Sendable {
    open var status: PKPaymentAuthorizationStatus = .success
    @objc open var paymentSummaryItems: [PKPaymentSummaryItem]
    @objc open var shippingMethods: [PKShippingMethod] = []
    @objc open var multiTokenContexts: [PKPaymentTokenContext]?
    @objc open var recurringPaymentRequest: PKRecurringPaymentRequest?
    @objc open var deferredPaymentRequest: PKDeferredPaymentRequest?
    @objc open var automaticReloadPaymentRequest: PKAutomaticReloadPaymentRequest?
    @objc public init(paymentSummaryItems: [PKPaymentSummaryItem]) {
        self.paymentSummaryItems = paymentSummaryItems
        super.init()
    }
    /// the errors to show (the subclasses that carry them)
    @objc var _errors: [Error] { [] }
    /// whether the update replaced the shipping methods (the subclasses that carry them)
    @objc var _setsShippingMethods = false
    /// returned by a delegate's default method: nothing changes
    @objc var _unchanged = false
}

@objc(PKPaymentRequestShippingMethodUpdate) open class PKPaymentRequestShippingMethodUpdate: PKPaymentRequestUpdate, @unchecked Sendable {}

@objc(PKPaymentRequestShippingContactUpdate) open class PKPaymentRequestShippingContactUpdate: PKPaymentRequestUpdate, @unchecked Sendable {
    @objc open var errors: [Error]!
    @objc public init(errors: [Error]?, paymentSummaryItems: [PKPaymentSummaryItem], shippingMethods: [PKShippingMethod]) {
        self.errors = errors ?? []
        super.init(paymentSummaryItems: paymentSummaryItems)
        self.shippingMethods = shippingMethods; _setsShippingMethods = true
    }
    @objc public override init(paymentSummaryItems: [PKPaymentSummaryItem]) {
        errors = []
        super.init(paymentSummaryItems: paymentSummaryItems)
    }
    @objc override var _errors: [Error] { errors ?? [] }
}

@objc(PKPaymentRequestPaymentMethodUpdate) open class PKPaymentRequestPaymentMethodUpdate: PKPaymentRequestUpdate, @unchecked Sendable {
    @objc open var errors: [Error]!
    @objc public init(errors: [Error]?, paymentSummaryItems: [PKPaymentSummaryItem]) {
        self.errors = errors ?? []
        super.init(paymentSummaryItems: paymentSummaryItems)
    }
    @objc public override init(paymentSummaryItems: [PKPaymentSummaryItem]) {
        errors = []
        super.init(paymentSummaryItems: paymentSummaryItems)
    }
    @objc override var _errors: [Error] { errors ?? [] }
}

@objc(PKPaymentRequestCouponCodeUpdate) open class PKPaymentRequestCouponCodeUpdate: PKPaymentRequestUpdate, @unchecked Sendable {
    @objc open var errors: [Error]!
    @objc public init(errors: [Error]?, paymentSummaryItems: [PKPaymentSummaryItem], shippingMethods: [PKShippingMethod]) {
        self.errors = errors ?? []
        super.init(paymentSummaryItems: paymentSummaryItems)
        self.shippingMethods = shippingMethods; _setsShippingMethods = true
    }
    @objc public override init(paymentSummaryItems: [PKPaymentSummaryItem]) {
        errors = []
        super.init(paymentSummaryItems: paymentSummaryItems)
    }
    @objc override var _errors: [Error] { errors ?? [] }
}
