# PassKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [PassKit (Apple Pay)](https://developer.apple.com/documentation/passkit/apple-pay) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

Apple Pay. Wallet passes (`PKPass`, `PKAddPassesViewController`) are on [WalletPasses](WalletPasses.md).

## How isim implements it

- **Approach:** isim's own Swift overlay, `isim/swift/overlays/PassKit`:
  - the request and payment model (`PassKit.swift`);
  - the controllers and delegates (`PaymentAuthorization.swift`);
  - a simulated Apple Pay sheet (`PaymentSheet.swift`);
  - the buttons (`PaymentButton.swift`).
- **The sheet** is drawn like iOS's. It has:
  - the card;
  - the shipping address, the shipping method and the contact;
  - a coupon code field, and the summary;
  - "Pay with Passcode" (the Simulator's confirmation: there is no side button), then Processing and Done.

  Each row opens its choices. As on iOS:
  - the delegate hears the default card and the shipping address when the sheet appears;
  - before authorization the address is redacted (city, state, postal code, country);
  - its updates refresh the summary;
  - its errors show on their rows, and contact errors disable Pay until another address is chosen.
- **The device's Wallet** has four test cards: Visa credit 4242, Mastercard debit 4444, American Express 0005, Discover 1117. It also has two test addresses. `ISIM_APPLE_PAY=0` leaves Wallet empty, so `canMakePayments()` is false ([SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md)).
- **The token is isim's test token, not Apple's.** `PKPaymentToken.paymentData` is JSON with `"version": "isim-test"`, a note saying what it is, the amount, network and merchant, and the SHA-256 of `applicationData`. It has no cryptogram or card number, so a payment processor rejects it. Nothing is charged.
- **The buttons** have Apple Pay's shapes, colors and labels. The words "Apple Pay" stand where iOS draws Apple's logo: Apple's artwork is not shipped.
- **Objective-C / C interface:** Swift only for now (issue #566). The delegates are Swift protocols: each method has both forms Apple's SDK imports (completion handler and `async`), with defaults, so an app implements either.
- **Versus Apple's Simulator:** the same flow with test cards; the Simulator's token is also not chargeable.
  - isim does not check the `com.apple.developer.in-app-payments` entitlement or the merchant identifier.
  - There are no merchant sessions (Apple Pay on the web) or disbursements.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `PKPaymentRequest` (merchant, country, currency, `supportedNetworks`, `merchantCapabilities`, `paymentSummaryItems`, required billing / shipping contact fields, `shippingMethods`, `shippingType`, `shippingContactEditingMode`, `applicationData`, `couponCode`, `supportsCouponCode`, `availableNetworks()`, the error helpers) | ✅ | ≤17 | adapted: an incomplete request (no merchant, currency, networks or items) is refused, as on iOS; tested (HelloApplePay, `test_apple_pay`) |
| Recurring, deferred and automatic reload payments (`PKRecurringPaymentRequest`, `PKDeferredPaymentRequest`, `PKAutomaticReloadPaymentRequest`, their summary items), `multiTokenContexts` (`PKPaymentTokenContext`) | 🟡 | ≤17 | adapted: kept on the request; the sheet shows their summary items |
| `PKPaymentAuthorizationViewController` (`init?(paymentRequest:)`, `canMakePayments()`, `canMakePayments(usingNetworks:)`, `canMakePayments(usingNetworks:capabilities:)`) and `PKPaymentAuthorizationViewControllerDelegate` (both forms of each method) | ✅ | ≤17 | adapted: isim's sheet; tested |
| `PKPaymentAuthorizationController` (`present`, `dismiss`, completion and async) and `PKPaymentAuthorizationControllerDelegate` (with `presentationWindow(for:)`) | ✅ | ≤17 | adapted: the sheet over the app's top view controller (or the delegate's window); tested |
| `PKPaymentButton` (`init(paymentButtonType:paymentButtonStyle:)`, `disableCardArt:` forms, `cornerRadius`), `PKPaymentButtonType`, `PKPaymentButtonStyle` | ✅ | ≤17 | adapted: "Apple Pay" in words for the logo; tested |
| `PKPaymentNetwork`, `PKMerchantCapability`, `PKContactField`, `PKShippingType`, `PKShippingContactEditingMode`, `PKPaymentMethodType` | ✅ | ≤17 | tested |
| `PKPayment`, `PKPaymentToken`, `PKPaymentMethod`, `PKContact` | ✅ | ≤17 | adapted: isim's test token (above); the contacts carry the requested fields; tested |
| `PKPaymentSummaryItem`, `PKShippingMethod`, `PKDateComponentsRange` | ✅ | ≤17 | tested |
| `PKPaymentAuthorizationResult`, `PKPaymentAuthorizationStatus`, the request updates (`PKPaymentRequestUpdate`, …`ShippingContactUpdate`, …`ShippingMethodUpdate`, …`PaymentMethodUpdate`, …`CouponCodeUpdate`), `PKPaymentError`, `PKPaymentErrorKey` | ✅ | ≤17 | adapted: a failure without errors shows "Payment Not Completed" and Try Again; errors show on their rows; tested |
| SwiftUI `PayWithApplePayButton` (action and request forms, with fallbacks), `PayWithApplePayButtonLabel`, `PayWithApplePayButtonStyle`, `PayWithApplePayButtonPaymentAuthorizationPhase`, `payWithApplePayButtonStyle(_:)`, `onApplePayShippingContactChange` / `…ShippingMethodChange` / `…PaymentMethodChange` / `…CouponCodeChange` | ✅ | ≤17 | adapted: the fallback shows when the device cannot pay; tested |
| Merchant sessions (`PKPaymentRequestMerchantSessionUpdate`, `onMerchantSessionRequested`), disbursements (`PKDisbursementRequest`), `orderDetails`, `applePayLaterAvailability`, `merchantCategoryCode` | ❌ | ≤17 | not yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
