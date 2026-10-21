// isim PassKit: PKPaymentButton (UIKit) and PayWithApplePayButton (SwiftUI). Adapted: the buttons have Apple Pay's
// shapes, colors and labels, with the words "Apple Pay" where iOS draws Apple's logo (Apple's artwork is not shipped).
import Foundation
import UIKit
import SwiftUI

public enum PKPaymentButtonType: Int, Sendable {
    case plain = 0, buy, setUp, inStore, donate, checkout, book, subscribe, reload, addMoney, topUp, order, rent, support, contribute, tip, `continue`

    var title: String {
        switch self {
        case .plain: return "Apple Pay"
        case .buy: return "Buy with Apple Pay"
        case .setUp: return "Set up Apple Pay"
        case .inStore: return "Pay with Apple Pay"
        case .donate: return "Donate with Apple Pay"
        case .checkout: return "Check out with Apple Pay"
        case .book: return "Book with Apple Pay"
        case .subscribe: return "Subscribe with Apple Pay"
        case .reload: return "Reload with Apple Pay"
        case .addMoney: return "Add Money with Apple Pay"
        case .topUp: return "Top Up with Apple Pay"
        case .order: return "Order with Apple Pay"
        case .rent: return "Rent with Apple Pay"
        case .support: return "Support with Apple Pay"
        case .contribute: return "Contribute with Apple Pay"
        case .tip: return "Tip with Apple Pay"
        case .continue: return "Continue with Apple Pay"
        }
    }
}

public enum PKPaymentButtonStyle: Int, Sendable {
    case white = 0, whiteOutline, black, automatic

    /// background, text, outline
    var colors: (UIColor, UIColor, UIColor?) {
        switch self {
        case .white: return (.white, .black, nil)
        case .whiteOutline: return (.white, .black, .black)
        case .black: return (.black, .white, nil)
        case .automatic: return (.label, .systemBackground, nil)   // black in light mode, white in dark
        }
    }
}

/// The Apple Pay button: start a payment with Apple Pay (or set it up).
@objc(PKPaymentButton) @objcMembers open class PKPaymentButton: UIButton {
    let paymentType: PKPaymentButtonType
    let paymentStyle: PKPaymentButtonStyle
    /// 4 points by default, as iOS's
    open var cornerRadius: CGFloat = 4 { didSet { layer.cornerRadius = cornerRadius } }

    public init(paymentButtonType type: PKPaymentButtonType, paymentButtonStyle style: PKPaymentButtonStyle) {
        paymentType = type; paymentStyle = style
        super.init(frame: CGRect(x: 0, y: 0, width: 140, height: 30))
        let (bg, fg, outline) = style.colors
        backgroundColor = bg
        setTitle(type.title, for: .normal)
        setTitleColor(fg, for: .normal)
        setTitleColor(fg.withAlphaComponent(0.6), for: .highlighted)
        titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
        if let o = outline { layer.borderColor = o.cgColor; layer.borderWidth = 1 }
        accessibilityLabel = type.title
    }
    public convenience init(paymentButtonType type: PKPaymentButtonType, paymentButtonStyle style: PKPaymentButtonStyle, disableCardArt: Bool) {
        self.init(paymentButtonType: type, paymentButtonStyle: style)
    }
    public convenience init(type: PKPaymentButtonType, style: PKPaymentButtonStyle, disableCardArt: Bool) {
        self.init(paymentButtonType: type, paymentButtonStyle: style)
    }
    public required init?(coder: NSCoder) {
        paymentType = .plain; paymentStyle = .black
        super.init(coder: coder)
    }
    open override var intrinsicContentSize: CGSize {
        let w = (titleLabel?.intrinsicContentSize.width ?? 100) + 40
        return CGSize(width: max(140, w), height: 44)
    }
}

// MARK: - SwiftUI

/// The label of a PayWithApplePayButton.
public struct PayWithApplePayButtonLabel: Equatable, Sendable {
    let type: PKPaymentButtonType
    public static let plain = PayWithApplePayButtonLabel(type: .plain)
    public static let buy = PayWithApplePayButtonLabel(type: .buy)
    public static let setUp = PayWithApplePayButtonLabel(type: .setUp)
    public static let inStore = PayWithApplePayButtonLabel(type: .inStore)
    public static let donate = PayWithApplePayButtonLabel(type: .donate)
    public static let checkout = PayWithApplePayButtonLabel(type: .checkout)
    public static let book = PayWithApplePayButtonLabel(type: .book)
    public static let subscribe = PayWithApplePayButtonLabel(type: .subscribe)
    public static let reload = PayWithApplePayButtonLabel(type: .reload)
    public static let addMoney = PayWithApplePayButtonLabel(type: .addMoney)
    public static let topUp = PayWithApplePayButtonLabel(type: .topUp)
    public static let order = PayWithApplePayButtonLabel(type: .order)
    public static let rent = PayWithApplePayButtonLabel(type: .rent)
    public static let support = PayWithApplePayButtonLabel(type: .support)
    public static let contribute = PayWithApplePayButtonLabel(type: .contribute)
    public static let tip = PayWithApplePayButtonLabel(type: .tip)
    public static let `continue` = PayWithApplePayButtonLabel(type: .continue)
}

/// The colors of a PayWithApplePayButton.
public struct PayWithApplePayButtonStyle: Equatable, Sendable {
    let style: PKPaymentButtonStyle
    public static let automatic = PayWithApplePayButtonStyle(style: .automatic)
    public static let black = PayWithApplePayButtonStyle(style: .black)
    public static let white = PayWithApplePayButtonStyle(style: .white)
    public static let whiteOutline = PayWithApplePayButtonStyle(style: .whiteOutline)
}

/// What happens with a payment started by a PayWithApplePayButton.
public enum PayWithApplePayButtonPaymentAuthorizationPhase {
    case willAuthorize
    case didAuthorize(payment: PKPayment, resultHandler: (PKPaymentAuthorizationResult) -> Void)
    case didFinish
}

/// the onApplePay…Change handlers a PayWithApplePayButton below them uses
struct _PKButtonHandlers {
    var shippingContact: ((PKContact) async -> PKPaymentRequestShippingContactUpdate)?
    var shippingMethod: ((PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate)?
    var paymentMethod: ((PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate)?
    var couponCode: ((String) async -> PKPaymentRequestCouponCodeUpdate)?
}
struct _PKHandlerModifier: ViewModifier {
    let update: (inout _PKButtonHandlers) -> Void
    @Environment(\._pkButtonHandlers) var handlers
    func body(content: Content) -> some View {
        var h = handlers
        update(&h)
        return content.environment(\._pkButtonHandlers, h)
    }
}
struct _PKButtonHandlersKey: EnvironmentKey { static let defaultValue = _PKButtonHandlers() }
struct _PKButtonStyleKey: EnvironmentKey { static let defaultValue = PayWithApplePayButtonStyle.automatic }
extension EnvironmentValues {
    var _pkButtonHandlers: _PKButtonHandlers { get { self[_PKButtonHandlersKey.self] } set { self[_PKButtonHandlersKey.self] = newValue } }
    var _pkButtonStyle: PayWithApplePayButtonStyle { get { self[_PKButtonStyleKey.self] } set { self[_PKButtonStyleKey.self] = newValue } }
}

/// The SwiftUI Apple Pay button: an action of the app's, or a payment request it presents with the Apple Pay sheet.
public struct PayWithApplePayButton<Fallback: View>: View {
    let label: PayWithApplePayButtonLabel
    let action: (() -> Void)?
    let request: PKPaymentRequest?
    let onChange: ((PayWithApplePayButtonPaymentAuthorizationPhase) -> Void)?
    let fallback: Fallback?
    @Environment(\._pkButtonStyle) var style
    @Environment(\._pkButtonHandlers) var handlers
    @Environment(\.colorScheme) var colorScheme

    public init(_ label: PayWithApplePayButtonLabel = .plain, action: @escaping () -> Void, @ViewBuilder fallback: () -> Fallback) {
        self.label = label; self.action = action; request = nil; onChange = nil; self.fallback = fallback()
    }
    public init(_ label: PayWithApplePayButtonLabel = .plain, request: PKPaymentRequest,
                            onPaymentAuthorizationChange: @escaping (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void,
                            @ViewBuilder fallback: () -> Fallback) {
        self.label = label; action = nil; self.request = request; onChange = onPaymentAuthorizationChange; self.fallback = fallback()
    }

    public var body: some View {
        if let fallback, !PKPaymentAuthorizationController.canMakePayments() {
            fallback
        } else {
            Button(action: tapped) {
                Text(label.type.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(colors.1))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(colors.0)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(colors.2 ?? .clear), lineWidth: colors.2 == nil ? 0 : 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label.type.title)
        }
    }

    var colors: (UIColor, UIColor, UIColor?) {
        if style.style == .automatic { return colorScheme == .dark ? (.white, .black, nil) : (.black, .white, nil) }
        return style.style.colors
    }

    func tapped() {
        if let action { action(); return }
        guard let request, let onChange else { return }
        let c = PKPaymentAuthorizationController(paymentRequest: request)
        let d = _PKButtonDelegate(onChange: onChange, handlers: handlers)
        d.retain = (c, d)
        c.delegate = d
        c.present { ok in if !ok { d.retain = nil } }
    }
}

public extension PayWithApplePayButton where Fallback == EmptyView {
    init(_ label: PayWithApplePayButtonLabel = .plain, action: @escaping () -> Void) {
        self.label = label; self.action = action; request = nil; onChange = nil; fallback = nil
    }
    init(_ label: PayWithApplePayButtonLabel = .plain, request: PKPaymentRequest,
                     onPaymentAuthorizationChange: @escaping (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void) {
        self.label = label; action = nil; self.request = request; onChange = onPaymentAuthorizationChange; fallback = nil
    }
}

/// the controller's delegate for a button with a request: the phases, and the environment's change handlers
final class _PKButtonDelegate: NSObject, PKPaymentAuthorizationControllerDelegate {
    let onChange: (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void
    let handlers: _PKButtonHandlers
    var retain: (PKPaymentAuthorizationController, _PKButtonDelegate)?
    init(onChange: @escaping (PayWithApplePayButtonPaymentAuthorizationPhase) -> Void, handlers: _PKButtonHandlers) {
        self.onChange = onChange; self.handlers = handlers
    }
    func paymentAuthorizationControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationController) { onChange(.willAuthorize) }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment,
                                        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        onChange(.didAuthorize(payment: payment, resultHandler: completion))
    }
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { [self] in
            onChange(.didFinish)
            retain = nil
        }
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingContact contact: PKContact) async -> PKPaymentRequestShippingContactUpdate {
        if let h = handlers.shippingContact { return await h(contact) }
        return PKPaymentRequestShippingContactUpdate(paymentSummaryItems: [])._markUnchanged()
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingMethod shippingMethod: PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate {
        if let h = handlers.shippingMethod { return await h(shippingMethod) }
        return PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: [])._markUnchanged()
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectPaymentMethod paymentMethod: PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate {
        if let h = handlers.paymentMethod { return await h(paymentMethod) }
        return PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: [])._markUnchanged()
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didChangeCouponCode couponCode: String) async -> PKPaymentRequestCouponCodeUpdate {
        if let h = handlers.couponCode { return await h(couponCode) }
        return PKPaymentRequestCouponCodeUpdate(paymentSummaryItems: [])._markUnchanged()
    }
}

public extension View {
    func payWithApplePayButtonStyle(_ style: PayWithApplePayButtonStyle) -> some View {
        environment(\._pkButtonStyle, style)
    }
    func onApplePayShippingContactChange(perform action: @escaping (PKContact) async -> PKPaymentRequestShippingContactUpdate) -> some View {
        modifier(_PKHandlerModifier { $0.shippingContact = action })
    }
    func onApplePayShippingMethodChange(perform action: @escaping (PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate) -> some View {
        modifier(_PKHandlerModifier { $0.shippingMethod = action })
    }
    func onApplePayPaymentMethodChange(perform action: @escaping (PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate) -> some View {
        modifier(_PKHandlerModifier { $0.paymentMethod = action })
    }
    func onApplePayCouponCodeChange(perform action: @escaping (String) async -> PKPaymentRequestCouponCodeUpdate) -> some View {
        modifier(_PKHandlerModifier { $0.couponCode = action })
    }
}
