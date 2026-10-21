// isim PassKit: the Objective-C interface (sdk-src/Frameworks/PassKit, issue #566). The classes are @objc(PK…) and
// @objcMembers, so what Objective-C can represent is exported under Apple's names; the members below are internal
// Objective-C entry points, under Apple's selectors, for what uses Swift-only types: the networks and contact fields
// (NSStrings in Objective-C), the merchant capabilities and the enums (their raw values), and the delegate protocols,
// which are Swift protocols here. An Objective-C delegate is held through a Swift box that forwards to Apple's
// Objective-C protocol of the same name (declared below as Objective-C sees it), weakly like iOS; a method the delegate
// does not implement behaves as the Swift protocol's default.
import UIKit
import ObjectiveC

// MARK: - Apple's Objective-C protocols

@objc(PKPaymentAuthorizationControllerDelegate) protocol _PKObjCControllerDelegate: NSObjectProtocol {
    @objc(paymentAuthorizationControllerDidFinish:) optional func _didFinish(_ c: PKPaymentAuthorizationController)
    @objc(paymentAuthorizationController:didAuthorizePayment:handler:)
    optional func _authorize(_ c: PKPaymentAuthorizationController, _ p: PKPayment, _ h: @escaping (PKPaymentAuthorizationResult) -> Void)
    @objc(paymentAuthorizationControllerWillAuthorizePayment:) optional func _willAuthorize(_ c: PKPaymentAuthorizationController)
    @objc(paymentAuthorizationController:didSelectShippingMethod:handler:)
    optional func _shippingMethod(_ c: PKPaymentAuthorizationController, _ m: PKShippingMethod, _ h: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void)
    @objc(paymentAuthorizationController:didSelectShippingContact:handler:)
    optional func _shippingContact(_ c: PKPaymentAuthorizationController, _ m: PKContact, _ h: @escaping (PKPaymentRequestShippingContactUpdate) -> Void)
    @objc(paymentAuthorizationController:didSelectPaymentMethod:handler:)
    optional func _paymentMethod(_ c: PKPaymentAuthorizationController, _ m: PKPaymentMethod, _ h: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void)
    @objc(paymentAuthorizationController:didChangeCouponCode:handler:)
    optional func _couponCode(_ c: PKPaymentAuthorizationController, _ m: String, _ h: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void)
    @objc(presentationWindowForPaymentAuthorizationController:) optional func _window(_ c: PKPaymentAuthorizationController) -> UIWindow?
}
@objc(PKPaymentAuthorizationViewControllerDelegate) protocol _PKObjCViewControllerDelegate: NSObjectProtocol {
    @objc(paymentAuthorizationViewControllerDidFinish:) optional func _didFinish(_ c: PKPaymentAuthorizationViewController)
    @objc(paymentAuthorizationViewController:didAuthorizePayment:handler:)
    optional func _authorize(_ c: PKPaymentAuthorizationViewController, _ p: PKPayment, _ h: @escaping (PKPaymentAuthorizationResult) -> Void)
    @objc(paymentAuthorizationViewControllerWillAuthorizePayment:) optional func _willAuthorize(_ c: PKPaymentAuthorizationViewController)
    @objc(paymentAuthorizationViewController:didSelectShippingMethod:handler:)
    optional func _shippingMethod(_ c: PKPaymentAuthorizationViewController, _ m: PKShippingMethod, _ h: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void)
    @objc(paymentAuthorizationViewController:didSelectShippingContact:handler:)
    optional func _shippingContact(_ c: PKPaymentAuthorizationViewController, _ m: PKContact, _ h: @escaping (PKPaymentRequestShippingContactUpdate) -> Void)
    @objc(paymentAuthorizationViewController:didSelectPaymentMethod:handler:)
    optional func _paymentMethod(_ c: PKPaymentAuthorizationViewController, _ m: PKPaymentMethod, _ h: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void)
    @objc(paymentAuthorizationViewController:didChangeCouponCode:handler:)
    optional func _couponCode(_ c: PKPaymentAuthorizationViewController, _ m: String, _ h: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void)
}
@objc(PKAddPassesViewControllerDelegate) protocol _PKObjCAddPassesDelegate: NSObjectProtocol {
    @objc(addPassesViewControllerDidFinish:) optional func _didFinish(_ c: PKAddPassesViewController)
}

// MARK: - boxes

enum _PKObjC {
    nonisolated(unsafe) static var boxKey = 0
    static func retain(_ box: AnyObject?, on owner: AnyObject) {
        withUnsafePointer(to: &boxKey) { objc_setAssociatedObject(owner, $0, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    static func unhandledAuthorization() -> PKPaymentAuthorizationResult {
        NSLog("isim PassKit: the delegate does not handle didAuthorizePayment; the payment fails")
        return PKPaymentAuthorizationResult(status: .failure, errors: nil)
    }
}

final class _PKControllerDelegateBox: NSObject, PKPaymentAuthorizationControllerDelegate {
    weak var t: _PKObjCControllerDelegate?
    init(_ t: _PKObjCControllerDelegate) { self.t = t }
    @MainActor func paymentAuthorizationControllerDidFinish(_ c: PKPaymentAuthorizationController) { t?._didFinish?(c) }
    @MainActor func paymentAuthorizationController(_ c: PKPaymentAuthorizationController, didAuthorizePayment p: PKPayment,
                                                   handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        if let f = t?._authorize { f(c, p, completion) } else { completion(_PKObjC.unhandledAuthorization()) }
    }
    @MainActor func paymentAuthorizationControllerWillAuthorizePayment(_ c: PKPaymentAuthorizationController) { t?._willAuthorize?(c) }
    @MainActor func paymentAuthorizationController(_ c: PKPaymentAuthorizationController, didSelectShippingMethod m: PKShippingMethod,
                                                   handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
        if let f = t?._shippingMethod { f(c, m, completion) } else { completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
    @MainActor func paymentAuthorizationController(_ c: PKPaymentAuthorizationController, didSelectShippingContact m: PKContact,
                                                   handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void) {
        if let f = t?._shippingContact { f(c, m, completion) } else { completion(PKPaymentRequestShippingContactUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
    @MainActor func paymentAuthorizationController(_ c: PKPaymentAuthorizationController, didSelectPaymentMethod m: PKPaymentMethod,
                                                   handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void) {
        if let f = t?._paymentMethod { f(c, m, completion) } else { completion(PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
    @MainActor func paymentAuthorizationController(_ c: PKPaymentAuthorizationController, didChangeCouponCode m: String,
                                                   handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void) {
        if let f = t?._couponCode { f(c, m, completion) } else { completion(PKPaymentRequestCouponCodeUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
    @MainActor func presentationWindow(for c: PKPaymentAuthorizationController) -> UIWindow? { t?._window?(c) ?? nil }
}

final class _PKViewControllerDelegateBox: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    weak var t: _PKObjCViewControllerDelegate?
    init(_ t: _PKObjCViewControllerDelegate) { self.t = t }
    @MainActor func paymentAuthorizationViewControllerDidFinish(_ c: PKPaymentAuthorizationViewController) { t?._didFinish?(c) }
    @MainActor func paymentAuthorizationViewController(_ c: PKPaymentAuthorizationViewController, didAuthorizePayment p: PKPayment,
                                                       handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        if let f = t?._authorize { f(c, p, completion) } else { completion(_PKObjC.unhandledAuthorization()) }
    }
    @MainActor func paymentAuthorizationViewControllerWillAuthorizePayment(_ c: PKPaymentAuthorizationViewController) { t?._willAuthorize?(c) }
    @MainActor func paymentAuthorizationViewController(_ c: PKPaymentAuthorizationViewController, didSelect m: PKShippingMethod,
                                                       handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
        if let f = t?._shippingMethod { f(c, m, completion) } else { completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
    @MainActor func paymentAuthorizationViewController(_ c: PKPaymentAuthorizationViewController, didSelectShippingContact m: PKContact,
                                                       handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void) {
        if let f = t?._shippingContact { f(c, m, completion) } else { completion(PKPaymentRequestShippingContactUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
    @MainActor func paymentAuthorizationViewController(_ c: PKPaymentAuthorizationViewController, didSelect m: PKPaymentMethod,
                                                       handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void) {
        if let f = t?._paymentMethod { f(c, m, completion) } else { completion(PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
    @MainActor func paymentAuthorizationViewController(_ c: PKPaymentAuthorizationViewController, didChangeCouponCode m: String,
                                                       handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void) {
        if let f = t?._couponCode { f(c, m, completion) } else { completion(PKPaymentRequestCouponCodeUpdate(paymentSummaryItems: [])._markUnchanged()) }
    }
}

final class _PKAddPassesDelegateBox: NSObject, PKAddPassesViewControllerDelegate {
    weak var t: _PKObjCAddPassesDelegate?
    init(_ t: _PKObjCAddPassesDelegate) { self.t = t }
    @MainActor func addPassesViewControllerDidFinish(_ c: PKAddPassesViewController) {
        if let f = t?._didFinish { f(c) } else { c.dismiss(animated: true) }
    }
}

// MARK: - requests and summary items

extension PKPaymentSummaryItem {
    @objc(type) var _objcType: UInt {
        get { type.rawValue }
        set { type = PKPaymentSummaryItemType(rawValue: newValue) ?? .final }
    }
}

extension PKPaymentRequest {
    @objc(supportedNetworks) var _objcSupportedNetworks: [String] {
        get { supportedNetworks.map(\.rawValue) }
        set { supportedNetworks = newValue.map(PKPaymentNetwork.init(rawValue:)) }
    }
    @objc(merchantCapabilities) var _objcMerchantCapabilities: UInt {
        get { merchantCapabilities.rawValue }
        set { merchantCapabilities = PKMerchantCapability(rawValue: newValue) }
    }
    @objc(requiredBillingContactFields) var _objcRequiredBillingContactFields: Set<String> {
        get { Set(requiredBillingContactFields.map(\.rawValue)) }
        set { requiredBillingContactFields = Set(newValue.map(PKContactField.init(rawValue:))) }
    }
    @objc(requiredShippingContactFields) var _objcRequiredShippingContactFields: Set<String> {
        get { Set(requiredShippingContactFields.map(\.rawValue)) }
        set { requiredShippingContactFields = Set(newValue.map(PKContactField.init(rawValue:))) }
    }
    @objc(shippingType) var _objcShippingType: UInt {
        get { shippingType.rawValue }
        set { shippingType = PKShippingType(rawValue: newValue) ?? .shipping }
    }
    @objc(shippingContactEditingMode) var _objcShippingContactEditingMode: UInt {
        get { shippingContactEditingMode.rawValue }
        set { shippingContactEditingMode = PKShippingContactEditingMode(rawValue: newValue) ?? .available }
    }
    @objc(availableNetworks) class func _objcAvailableNetworks() -> [String] { availableNetworks().map(\.rawValue) }
    @objc(paymentContactInvalidErrorWithContactField:localizedDescription:)
    class func _objcContactInvalidError(_ field: String, localizedDescription: String?) -> Error {
        paymentContactInvalidError(withContactField: PKContactField(rawValue: field), localizedDescription: localizedDescription)
    }
}

// MARK: - payments, results and updates

extension PKPaymentMethod {
    @objc(network) var _objcNetwork: String? { network?.rawValue }
    @objc(type) var _objcType: UInt { type.rawValue }
}

extension PKPaymentAuthorizationResult {
    @objc(status) var _objcStatus: Int {
        get { status.rawValue }
        set { status = PKPaymentAuthorizationStatus(rawValue: newValue) ?? .failure }
    }
}

extension PKPaymentRequestUpdate {
    @objc(status) var _objcStatus: Int {
        get { status.rawValue }
        set { status = PKPaymentAuthorizationStatus(rawValue: newValue) ?? .failure }
    }
}

// MARK: - controllers

extension PKPaymentAuthorizationController {
    @objc(delegate) var _objcDelegate: _PKObjCControllerDelegate? {
        get { (delegate as? _PKControllerDelegateBox)?.t }
        set {
            let b = newValue.map(_PKControllerDelegateBox.init)
            _PKObjC.retain(b, on: self)
            delegate = b
        }
    }
    @objc(canMakePaymentsUsingNetworks:) class func _objcCanMakePayments(_ networks: [String]) -> Bool {
        canMakePayments(usingNetworks: networks.map(PKPaymentNetwork.init(rawValue:)))
    }
    @objc(canMakePaymentsUsingNetworks:capabilities:) class func _objcCanMakePayments(_ networks: [String], capabilities: UInt) -> Bool {
        canMakePayments(usingNetworks: networks.map(PKPaymentNetwork.init(rawValue:)), capabilities: PKMerchantCapability(rawValue: capabilities))
    }
}

extension PKPaymentAuthorizationViewController {
    @objc(delegate) var _objcDelegate: _PKObjCViewControllerDelegate? {
        get { (delegate as? _PKViewControllerDelegateBox)?.t }
        set {
            let b = newValue.map(_PKViewControllerDelegateBox.init)
            _PKObjC.retain(b, on: self)
            delegate = b
        }
    }
    @objc(canMakePaymentsUsingNetworks:) class func _objcCanMakePayments(_ networks: [String]) -> Bool {
        canMakePayments(usingNetworks: networks.map(PKPaymentNetwork.init(rawValue:)))
    }
    @objc(canMakePaymentsUsingNetworks:capabilities:) class func _objcCanMakePayments(_ networks: [String], capabilities: UInt) -> Bool {
        canMakePayments(usingNetworks: networks.map(PKPaymentNetwork.init(rawValue:)), capabilities: PKMerchantCapability(rawValue: capabilities))
    }
}

// MARK: - buttons

extension PKPaymentButton {
    /// +buttonWithType:style: and -initWithPaymentButtonType:paymentButtonStyle: (PassKit.framework) make the button here
    @objc(_isim_buttonWithType:style:) class func _isimButton(_ type: Int, style: Int) -> PKPaymentButton {
        PKPaymentButton(paymentButtonType: PKPaymentButtonType(rawValue: type) ?? .plain, paymentButtonStyle: PKPaymentButtonStyle(rawValue: style) ?? .black)
    }
}

extension PKAddPassButton {
    @objc(addPassButtonStyle) var _objcAddPassButtonStyle: Int {
        get { addPassButtonStyle.rawValue }
        set { addPassButtonStyle = PKAddPassButtonStyle(rawValue: newValue) ?? .black }
    }
    /// +addPassButtonWithStyle: and -initWithAddPassButtonStyle: (PassKit.framework) make the button here
    @objc(_isim_addPassButtonWithStyle:) class func _isimButton(_ style: Int) -> PKAddPassButton {
        PKAddPassButton(addPassButtonStyle: PKAddPassButtonStyle(rawValue: style) ?? .black)
    }
}

// MARK: - Wallet

extension PKPass {
    @objc(passType) var _objcPassType: UInt { passType.rawValue }
}

extension PKPassLibrary {
    @objc(passesOfType:) func _objcPasses(ofType t: UInt) -> [PKPass] { passes(of: PKPassType(rawValue: t) ?? .any) }
    @objc(replacePassWithPass:) func _objcReplace(_ pass: PKPass) -> Bool { replacePass(with: pass) }
    @MainActor @objc(addPasses:withCompletionHandler:) func _objcAddPasses(_ passes: [PKPass], withCompletionHandler completion: ((Int) -> Void)?) {
        addPasses(passes, withCompletionHandler: { completion?($0.rawValue) })
    }
}

extension PKAddPassesViewController {
    @objc(delegate) var _objcDelegate: _PKObjCAddPassesDelegate? {
        get { (delegate as? _PKAddPassesDelegateBox)?.t }
        set {
            let b = newValue.map(_PKAddPassesDelegateBox.init)
            _PKObjC.retain(b, on: self)
            delegate = b
        }
    }
}
