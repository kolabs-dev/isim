# StoreKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 65.4% of Apple's iOS API (825 of 1261, exact) · **Rows:** 47: 41 ✅ 2 🟡 4 ❌ · **iOS:** 3.0+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [StoreKit](https://developer.apple.com/documentation/storekit) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** a local store like Xcode's StoreKit testing.
- The ledger is in `ISIM_DATA/Library/isim/StoreKit/<bundle id>/ledger.json`; JWS values and receipts are signed with the device's own certificate.
- `isim storekit` is the Transaction Manager.
- **Objective-C:** `StoreKit.framework` (`isim/sdk-src/Frameworks/StoreKit`) declares the overlay's classes under Apple's names: SKAdNetwork, the product page and overlay, and StoreKit 1.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| StoreKit configuration files (`.storekit` selected by the scheme) | ✅ | ≤17 | copied into the bundle by `isim build`; products, subscription groups, offers, `_timeRate`, `_storefront` |
| `Product.products(for:)` (id, type, display name, description, price, display price) | ✅ | ≤17 | prices shown in USD |
| `Product.purchase()` with confirmation sheet | ✅ | ≤17 | always succeeds when confirmed, except Ask to Buy (next row); owned non-consumables / current plan show the iOS notice |
| Ask to Buy (`.simulatesAskToBuyInSandbox(true)`, `SKMutablePayment.simulatesAskToBuyInSandbox`, the `.storekit` "Enable Ask To Buy" setting, `ISIM_STOREKIT_ASK_TO_BUY=1`) | ✅ | ≤17 | adapted: the purchase returns `.pending` (StoreKit 1: `.deferred`) and waits for the family organizer, `isim storekit <app> approve|decline [ID|all]`; an approved one becomes a transaction delivered in `Transaction.updates` (and to StoreKit 1 observers), a declined one is dropped; `isim storekit <app> list` shows the requests; tested (HelloStore: declined, then approved; `test_store_ask_to_buy`) |
| Purchase options (`appAccountToken`, `quantity`) | ✅ | ≤17 | stored on the transaction |
| `Transaction.currentEntitlements`, `all`, `latest(for:)`, `currentEntitlement(for:)`, `unfinished` | ✅ | ≤17 | `all` leaves out finished consumables (unless `SKIncludeConsumableInAppPurchaseHistory`) |
| `Transaction.updates` | ✅ | ≤17 | unfinished transactions at launch, renewals, refunds, offer-code redemptions, Transaction Manager changes (also one made just before the app writes the ledger itself; the app and `isim storekit` lock the ledger file while they change it); tested (test_store, test_store_refund_during_purchase) |
| `Transaction.finish()` | ✅ | ≤17 | unfinished transactions are delivered again at the next launch |
| `VerificationResult` | ✅ | ≤17 | always `.verified`; `jwsRepresentation` is ES256 with the device's StoreKit testing certificate in `x5c` (Apple's payload fields, environment `Xcode`); `deviceVerification` = SHA-384(nonce + device ID); tested: verified with OpenSSL (`test_store_billing`) |
| `AppStore.sync()` (restore) | ✅ | ≤17 | adapted: the purchase history is the device's account (outlives the app); sync applies renewals and Transaction Manager changes, re-delivers unfinished transactions, sends every status to `Status.updates` and signs the receipt again; no sign-in prompt (as in Xcode's local testing); tested: the app deleted and reinstalled keeps its subscription, sync (`test_store_billing`) |
| `AppStore.canMakePayments` | ✅ | ≤17 | |
| Consumables / non-consumables | ✅ | ≤17 | |
| Auto-renewable subscriptions: `Product.SubscriptionInfo` (group, period, level, group name) | ✅ | ≤17 | |
| Subscription status (`status`, `Status.updates`, `RenewalInfo`, `RenewalState`) | ✅ | ≤17 | subscribed / expired / revoked / grace period / billing retry; one status per group (no Family Sharing) |
| `RenewalInfo` members: `state`, `renewalPrice`, `currency`, `currencyCode`, `offer`, `offerPaymentModeStringRepresentation`, `offerPeriodStringRepresentation`, `eligibleWinBackOfferIDs` (iOS 18), `appAccountToken`, `appTransactionID`, `environmentStringRepresentation` (and in `jsonRepresentation`) | ✅ | ≤17 | the renewal price is the running offer's (introductory periods left) or the plan it renews into, in USD; nil when it will not renew; a lapsed subscriber's eligible win-back offers on iOS 18 and later; Advanced Commerce, bundle and commitment fields are not there; tested (HelloStore: subscribed, then expired) |
| `AppStore.ageRatingCode` | ✅ | 26.2 | adapted: isim's local store has no App Store record, so it is what `isim storekit <app> age-rating CODE` set (or `ISIM_STOREKIT_AGE_RATING`), nil until then; tested (HelloStore under iOS 27) |
| Renewals on an accelerated clock | ✅ | ≤17 | Xcode time rate from `.storekit` `_timeRate` (SKTestSession.TimeRate order; mapping unverified against Xcode) or `ISIM_STOREKIT_TIME_RATE` (`month=4`, `renewal=10`, names); renews while the app runs and catches up at launch |
| Expiration, cancel (auto-renew off), billing issues | ✅ | ≤17 | `isim storekit billing-issue` makes renewals fail: billing grace period (`.storekit` `_billingGracePeriodEnabled`, key name unverified against Xcode, or `ISIM_STOREKIT_BILLING_GRACE_PERIOD=1`; 16 days, 6 for weekly plans, entitlement kept, `gracePeriodExpirationDate`), then billing retry (60 days, `isInBillingRetry`, `expirationReason` `.billingError`), then expiry; resolving (`isim storekit resolve`, the Billing Problem message) renews; tested: every step (`test_store_billing`), expiry and cancel (`test_store`) |
| Upgrade / downgrade / crossgrade within a group | ✅ | ≤17 | upgrades (and same-period crossgrades) immediate, `isUpgraded` set; downgrades at the next renewal |
| Introductory offers (free trial, pay as you go, pay up front), `isEligibleForIntroOffer` | ✅ | ≤17 | eligible until the first subscription in the group |
| Promotional offers (`.promotionalOffer(...)`) | ✅ | ≤17 | from `.storekit` `adHocOffers`; the signature (ECDSA P-256 over Apple's payload, or the compact JWS; StoreKit 1 `SKPaymentDiscount` too) is checked against the device's subscription offers key (`isim storekit offer-key`), at most 24 h old, single-use nonce, app account token bound; existing and lapsed subscribers only; tested: forged, valid and JWS signatures |
| Win-back offers (`.winBackOffer`) | ✅ | 18.0 | from `winbackOffers`; eligible only after a lapsed subscription; iOS 18+: the win-back message (`Message.Reason.winBackOffer`, isim's sheet or the app's `Message.messages`), SubscriptionStoreView shows the offer, `preferredSubscriptionOffer`; tested: sheet purchase reaches `Transaction.updates`, deferred by a listener, the store view, none under iOS 17 (`test_store_winback_ios17`) |
| Offer codes (`presentOfferCodeRedeemSheet`, `offerCodeRedemption`) | ✅ | ≤17 | redeem sheet; codes are the `.storekit` `codeOffers` reference names / IDs; `eligibility` (new / existing / expired), each offer once, a current subscriber's offer starts at the next renewal; iOS 18+: codes for one-time products; tested: invalid, new, existing, already redeemed, non-consumable |
| Refunds (`beginRefundRequest`, `refundRequestSheet`), `revocationDate` / `revocationReason` | ✅ | ≤17 | refund sheet; local requests are approved at once; revoked transactions arrive in `Transaction.updates` |
| `showManageSubscriptions`, `manageSubscriptionsSheet` | ✅ | ≤17 | iOS-style sheet: status, change plan, cancel |
| StoreKit views (`StoreView`, `ProductView`, `SubscriptionStoreView`) | ✅ | ≤17 | iOS-like look; product view styles compact/regular/large and app-defined (`makeBody(configuration:)`); `storeButton` (incl. `.policies`), `subscriptionStorePolicyDestination` (URL or view), control styles (automatic/picker, prominent picker, compact picker, buttons), `subscriptionStoreButtonLabel`, `preferredSubscriptionOffer`, `onInAppPurchaseCompletion/Start`, `subscriptionStatusTask`, `currentEntitlementTask`; `prefersPromotionalIcon` uses the icon, as in Xcode's local testing (promotional images come from App Store Connect); tested: buttons + multiline label + policies + win-back offer, a custom product style |
| `AppTransaction` | ✅ | ≤17 | adapted: original app version = CFBundleVersion at the first launch on this device's account; environment `.xcode`; signed with the device's StoreKit testing certificate; `deviceVerification` = SHA-384(nonce + `deviceVerificationID`), `originalPlatform`; tested: JWS verified with OpenSSL, device verification |
| `SKStoreReviewController.requestReview`, `@Environment(\.requestReview)` | ✅ | ≤17 | development-style rating card, at most 3 times per 365 days; nothing sent |
| StoreKit 1 (`SKProductsRequest`, `SKProduct`/`SKProductDiscount`, `SKPaymentQueue`, observers, `finishTransaction`, restore) | ✅ | ≤17 | shares the StoreKit 2 ledger; renewals reach the observer. `price` is Foundation's `NSDecimalNumber` (until 0.21 a StoreKit stand-in class; Swift apps using it must be rebuilt) |
| StoreKit 1 from Objective-C (`SKProductsRequest` / `SKProductsResponse` / `SKRequestDelegate`, `SKProduct` / `SKProductDiscount` / `SKProductSubscriptionPeriod`, `SKPayment` / `SKMutablePayment`, `SKPaymentTransaction`, `SKPaymentQueue` `addPayment:` / `finishTransaction:` / `restoreCompletedTransactions`, `SKErrorDomain` / `SKErrorCode`, `SKReceiptRefreshRequest`, `SKStoreReviewController`, `NSBundle.appStoreReceiptURL`) | ✅ | ≤17 | adapted: the Swift overlay's classes under Apple's Objective-C names and selectors (StoreKit.framework); Objective-C delegates and observers are wrapped for the Swift protocols. `SKPaymentDiscount` is an NSObject subclass with Apple’s initializer and `NSNumber` timestamp (Swift apps built with isim 0.23 or earlier that use it or `paymentDiscount` must rebuild for 0.24); `paymentDiscount` supports signed promotional offers. Not yet from Objective-C: downloads. Tested (HelloStoreObjC: products, purchases with the confirmation sheet, an unknown product failing, restore, receipt refresh, the review prompt, signed and forged promotional offers in `test_store_objc_promotional_offer`) |
| App receipt (`Bundle.main.appStoreReceiptURL`, `SKReceiptRefreshRequest`) | ✅ | ≤17 | adapted, like Xcode's local receipts: PKCS #7 SignedData with Apple's ASN.1 receipt fields (bundle ID, versions, opaque value, SHA-1 hash with `identifierForVendor`, in-app purchases), signed with the device's StoreKit testing certificate (validate against `isim storekit certificate` instead of Apple's root); refresh properties expired / volume purchase; tested: `openssl cms -verify`, fields and hash |
| `SKOverlay`, `SKStoreProductViewController` | ✅ | ≤17 | adapted: the app's listing (name, developer, icon, rating, price, description) from Apple's public lookup API (`ISIM_APPSTORE_LOOKUP_URL` overrides it); unknown apps fail (`loadProduct` completion, `storeOverlay(_:didFailToLoadWithError:)`); overlay slides in with the delegate's transition calls; installing is unavailable on isim (GET says so); tested with a lookup fixture |
| Transaction Manager (refund, expire, cancel, clear) | ✅ | ≤17 | `isim storekit <app> list\|refund\|expire\|cancel\|resume\|billing-issue\|resolve\|delete\|clear`, `isim storekit certificate\|offer-key`; the running app picks changes up within 0.5 s; `isim storekit <app> purchase-intent PRODUCT [OFFER]` starts a purchase as the App Store would, `isim storekit <app> promotions` prints the promotion order and visibility; `approve|decline` answer Ask to Buy requests, `age-rating CODE|none` sets the age rating |
| SKAdNetwork (`updatePostbackConversionValue` with coarse values and `lockWindow`, `startImpression` / `endImpression`, `SKAdImpression`) | ✅ | ≤17 | adapted: no ad-driven installs, nothing is sent to ad networks. Values checked like iOS (fine 0–63: `SKANError.invalidConversionValue`; coarse low / medium / high), locking closes one of the three conversion windows (time compressed: a window stays open until locked), impressions checked and recorded; shared with AdAttributionKit and recorded in the device data. Tested: test_ad_attribution |
| `SubscriptionStoreView` store content (iOS 18): `StoreContent`, `StoreContentBuilder`, `TupleStoreContent`, `SubscriptionOptionGroup` (all its initializers; `AutomaticSubscriptionOptionGroupLabel`), `SubscriptionOptionGroupSet`, `SubscriptionOptionSection`, `SubscriptionOptionGroupStyle` (`.automatic`, `.tabs`, `.links`), `subscriptionStoreOptionGroupStyle`, the store content modifiers (`subscriptionStoreOptionGroupStyle`, `subscriptionStoreButtonLabel`, `storeButton`, `subscriptionStoreControlStyle`), `SubscriptionStoreContentView` | ✅ | 18.0 | adapted: the content resolves into option groups (a segmented control of tabs, or a list of links that open each group with a back button; automatic is tabs) and sections (a header or title, the plans, a footer); plans in no group are not shown once there are groups; `if`/`else` content uses StoreKit's own `_ConditionalStoreContent` (iOS: SwiftUI's `_ConditionalContent`, which isim keeps for views only); tested (HelloStore: tabs, links by billing period, sections; `test_store_ios18_views`) |
| `SubscriptionStoreView(groupID:visibleRelationships:)`, `Product.SubscriptionRelationship` (`.all`, `.upgrade`, `.downgrade`, `.crossgrade`, `.current`) | ✅ | ≤17 | a subscriber sees the plans of those relationships to their current plan (by group level); before subscribing, every plan; tested (HelloStore: upgrades only) |
| Custom subscription store controls (iOS 18): `SubscriptionStoreControlStyle.makeBody(configuration:)`, `SubscriptionStoreControlStyleConfiguration` (`options`, `sections`, `groupDisplayName`, `autoRenewPreference`, `allOptions`, `descriptionVisibility`; `Option` with `subscribe()` and dynamic member lookup, `PickerOption`, `Section`, `Icon`), `SubscriptionStorePicker` (all four initializers) | 🟡 | 18.0 | adapted: the options are the page's plans with the offer the store shows; `subscribe()` buys like the store's button; `SubscriptionStorePicker` draws one row per plan (the app's, or a checkmark row) and the confirmation for the selected plan; plan icons are nil; `Placement`, the `SubscribeButton` / `SubscriptionPicker` typealiases and the paged pickers are not there yet; tested (HelloStore: a custom picker that subscribes) |
| `SubscriptionOfferView` (all its initializers), `SubscriptionOfferViewStyle` (`.automatic`, `.compact`, custom), `SubscriptionOfferViewStyleConfiguration` (`visibleSubscription`, `activeOffer`, `icon`, `state`, `subscribe()`, `displayDetails()`), `subscriptionOfferViewStyle`, `ProductIconPhase`, `Product.CollectionTaskState` | 🟡 | 26.0 | adapted: a card with the plan (a group's first plan of the relationship that is not the current one, or the given plan), its offer (introductory, or win-back for a lapsed subscriber) or price, and a subscribe button; tapping it opens the group's subscription store; products have no promotional icons (`ProductIconPhase.unavailable`); `subscriptionStatus` is empty; tested (HelloStore under iOS 26 and 27) |
| `Product.PromotionInfo` (`currentOrder`, `updateProductOrder(byID:)`, `visibility`, `updateProductVisibility(_:for:)`, `update()`, `updateAll(_:)`) | ✅ | ≤17 | adapted: kept with the app's local StoreKit data (`isim storekit <app> promotions` lists them); `currentOrder` is empty until the app sets an order; unknown products are refused (`StoreKitError.unknown`); tested (HelloStore) |
| `PurchaseIntent` (`intents`, `product`, `id`, `offer` on iOS 18), StoreKit 1 `paymentQueue(_:shouldAddStorePayment:for:)` | ✅ | ≤17 | adapted: `isim storekit <app> purchase-intent PRODUCT [OFFER]` stands in for the customer starting a promoted purchase on the App Store; the app gets it while it listens (`PurchaseIntent.intents`) or has a StoreKit 1 observer (which decides whether the payment goes on the queue); intents wait for the app until then; tested (HelloStore: an intent completed with `purchase()`) |
| `ExternalPurchase` (`canPresent`, `presentNoticeSheet()`, `NoticeResult`) | ✅ | ≤17 | adapted: allowed with the `com.apple.developer.storekit.external-purchase` entitlement and the storefront's country in `SKExternalPurchase` (else `notEntitled`); isim's rendition of iOS's disclosure sheet (Continue / Cancel); Continue gives a token shaped like Apple's (base64 JSON) but isim's own, marked `isimSimulated`, not verifiable by Apple. `ISIM_STOREKIT_EXTERNAL_NOTICE=continue\|cancel` answers without a sheet. Tested (HelloExternalPurchase, `test_storekit_external.py`) |
| `ExternalPurchaseLink` (`canOpen`, `open()`, `eligibleURLs`, `open(url:)`) | ✅ | ≤17 | adapted: the `…external-purchase-link` entitlement and the storefront's URL in `SKExternalPurchaseLink` (multi links: `…-link-streaming` and `SKExternalPurchaseMultiLink`); the notice, then the URL opens in the browser. Tested (HelloExternalPurchase) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `ExternalLinkAccount`, `PaymentMethodBinding`, `SKCloudServiceController`, `SKCloudServiceSetupViewController`, `SKProductStorePromotionController`, `SubscriptionStoreControlBackground` (6 types; with their members under "Not yet in isim") |
| `ExternalPurchaseCustomLink` (`isEligible`, `token(for:)` with `TokenType` or a string, `showNotice(for:)` / `showNotice(type:)`, `Token`, `NoticeResult`, `NoticeType`, `ExternalPurchaseType`) | ✅ | 18.1 | adapted: eligible with a StoreKit external purchase entitlement and the storefront's country in `SKExternalPurchaseCustomLinkRegions` (isim does not check which entitlement Apple requires for custom links); tokens as for `ExternalPurchase` (`WITHIN_APP` / `OUT_OF_APP`, or the string given), nil when not eligible; the same notice sheet. The ineligible case is tested (HelloExternalPurchase) |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `AdvancedCommerceProduct`, `SubscriptionPeriodGroupSet`, `SubscriptionStoreButton`, `SubscriptionStoreControlPlacement`, `SubscriptionStorePickerOption` (5 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `StoreDownloaderExtension`, `SubscriptionOfferViewButtonKind` (2 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `RedeemOption` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
436 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AdvancedCommerceProduct`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct)
- [`var allTransactions: Transaction.Transactions`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/alltransactions)
- [`var currentEntitlements: Transaction.Transactions`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/currententitlements)
- [`let id: AdvancedCommerceProduct.ID`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/id)
- [`init(id: AdvancedCommerceProduct.ID) async throws`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/init(id:))
- [`var latestTransaction: VerificationResult<Transaction>?`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/latesttransaction)
- [`AdvancedCommerceProduct.ProductType`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/producttype)
- [`func purchase(compactJWS: String, confirmIn: UIViewController, options: Set<AdvancedCommerceProduct.PurchaseOption>) async throws -> AdvancedCommerceProduct.PurchaseResult`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/purchase(compactjws:confirmin:options:)-54lkw)
- [`AdvancedCommerceProduct.PurchaseOption`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/purchaseoption)
- [`static func onStorefrontChange(shouldContinuePurchase: (Storefront) -> Bool) -> AdvancedCommerceProduct.PurchaseOption`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/purchaseoption/onstorefrontchange(shouldcontinuepurchase:))
- [`AdvancedCommerceProduct.PurchaseResult`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/purchaseresult)
- [`let type: AdvancedCommerceProduct.ProductType`](https://developer.apple.com/documentation/storekit/advancedcommerceproduct/type)
- [`static var managed: AppStore.Platform`](https://developer.apple.com/documentation/storekit/appstore/platform/managed)
- [`static func presentMerchandising(AppStoreMerchandisingKind, from: UIViewController) async throws -> AppStoreMerchandisingKind.PresentationResult`](https://developer.apple.com/documentation/storekit/appstore/presentmerchandising(_:from:)-hkrd)
- [`static func presentOfferCodeRedeemSheet(from: UIViewController, options: Set<RedeemOption>) async throws -> VerificationResult<Transaction>`](https://developer.apple.com/documentation/storekit/appstore/presentoffercoderedeemsheet(from:options:)-89agc)
- [`AppStoreMerchandisingKind`](https://developer.apple.com/documentation/storekit/appstoremerchandisingkind)
- [`AppStoreMerchandisingKind.PresentationResult`](https://developer.apple.com/documentation/storekit/appstoremerchandisingkind/presentationresult)
- [`case dismissed`](https://developer.apple.com/documentation/storekit/appstoremerchandisingkind/presentationresult/dismissed)
- [`case purchaseCompleted(Product.PurchaseResult)`](https://developer.apple.com/documentation/storekit/appstoremerchandisingkind/presentationresult/purchasecompleted(_:))
- [`static func subscriptionBundle(String) -> AppStoreMerchandisingKind`](https://developer.apple.com/documentation/storekit/appstoremerchandisingkind/subscriptionbundle(_:))
- [`static var all: AppTransaction.AppTransactions`](https://developer.apple.com/documentation/storekit/apptransaction/all)
- [`AppTransaction.AppTransactions`](https://developer.apple.com/documentation/storekit/apptransaction/apptransactions)
- [`var originalPlatformStringRepresentation: String`](https://developer.apple.com/documentation/storekit/apptransaction/originalplatformstringrepresentation)
- [`var revocationDate: Date?`](https://developer.apple.com/documentation/storekit/apptransaction/revocationdate)
- [`let storeType: AppTransaction.StoreType`](https://developer.apple.com/documentation/storekit/apptransaction/storetype-swift.property)
- [`AppTransaction.StoreType`](https://developer.apple.com/documentation/storekit/apptransaction/storetype-swift.struct)
- [`static let consumer: AppTransaction.StoreType`](https://developer.apple.com/documentation/storekit/apptransaction/storetype-swift.struct/consumer)
- [`static let education: AppTransaction.StoreType`](https://developer.apple.com/documentation/storekit/apptransaction/storetype-swift.struct/education)
- [`static let enterprise: AppTransaction.StoreType`](https://developer.apple.com/documentation/storekit/apptransaction/storetype-swift.struct/enterprise)
- [`var storeTypeStringRepresentation: String`](https://developer.apple.com/documentation/storekit/apptransaction/storetypestringrepresentation)
- [`AutomaticProductPlaceholderIcon`](https://developer.apple.com/documentation/storekit/automaticproductplaceholdericon)
- [`AutomaticSubscriptionStoreControlPlacement`](https://developer.apple.com/documentation/storekit/automaticsubscriptionstorecontrolplacement)
- [`static var automatic: AutomaticSubscriptionStoreControlPlacement`](https://developer.apple.com/documentation/storekit/automaticsubscriptionstorecontrolplacement/automatic)
- [`static var bottomBar: AutomaticSubscriptionStoreControlPlacement`](https://developer.apple.com/documentation/storekit/automaticsubscriptionstorecontrolplacement/bottombar)
- [`static var buttonsInBottomBar: AutomaticSubscriptionStoreControlPlacement`](https://developer.apple.com/documentation/storekit/automaticsubscriptionstorecontrolplacement/buttonsinbottombar)
- [`static var scrollView: AutomaticSubscriptionStoreControlPlacement`](https://developer.apple.com/documentation/storekit/automaticsubscriptionstorecontrolplacement/scrollview)
- [`AutomaticSubscriptionStoreMarketingContent`](https://developer.apple.com/documentation/storekit/automaticsubscriptionstoremarketingcontent)
- [`AutomaticSubscriptionStorePickerOptionLabel`](https://developer.apple.com/documentation/storekit/automaticsubscriptionstorepickeroptionlabel)
- [`CompactPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/compactpickersubscriptionstorecontrolstyle/placement)
- [`static var automatic: CompactPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/compactpickersubscriptionstorecontrolstyle/placement/automatic)
- [`static var bottomBar: CompactPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/compactpickersubscriptionstorecontrolstyle/placement/bottombar)
- [`static var buttonsInBottomBar: CompactPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/compactpickersubscriptionstorecontrolstyle/placement/buttonsinbottombar)
- [`static var scrollView: CompactPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/compactpickersubscriptionstorecontrolstyle/placement/scrollview)
- [`func flatMap<NewValue>((Value) async throws -> EntitlementTaskState<NewValue>) async rethrows -> EntitlementTaskState<NewValue>`](https://developer.apple.com/documentation/storekit/entitlementtaskstate/flatmap(_:)-66eb8)
- [`func flatMap<NewValue>((Value) throws -> EntitlementTaskState<NewValue>) rethrows -> EntitlementTaskState<NewValue>`](https://developer.apple.com/documentation/storekit/entitlementtaskstate/flatmap(_:)-7gsnv)
- [`func map<NewValue>((Value) async throws -> NewValue) async rethrows -> EntitlementTaskState<NewValue>`](https://developer.apple.com/documentation/storekit/entitlementtaskstate/map(_:)-250dk)
- [`func map<NewValue>((Value) throws -> NewValue) rethrows -> EntitlementTaskState<NewValue>`](https://developer.apple.com/documentation/storekit/entitlementtaskstate/map(_:)-8ly3v)
- [`var value: Value?`](https://developer.apple.com/documentation/storekit/entitlementtaskstate/value)
- [`ExternalLinkAccount`](https://developer.apple.com/documentation/storekit/externallinkaccount)
- [`static var canOpen: Bool`](https://developer.apple.com/documentation/storekit/externallinkaccount/canopen)
- [`static func open() async throws`](https://developer.apple.com/documentation/storekit/externallinkaccount/open())
- [`IdentifiedStoreContent`](https://developer.apple.com/documentation/storekit/identifiedstorecontent)
- [`InvalidRequestError`](https://developer.apple.com/documentation/storekit/invalidrequesterror)
- [`let code: Int64`](https://developer.apple.com/documentation/storekit/invalidrequesterror/code)
- [`let message: String`](https://developer.apple.com/documentation/storekit/invalidrequesterror/message)
- [`var localizedDescription: String`](https://developer.apple.com/documentation/storekit/message/reason-swift.struct/localizeddescription)
- [`PagedPickerSubscriptionStoreControlStyle`](https://developer.apple.com/documentation/storekit/pagedpickersubscriptionstorecontrolstyle)
- [`init()`](https://developer.apple.com/documentation/storekit/pagedpickersubscriptionstorecontrolstyle/init())
- [`PagedPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/pagedpickersubscriptionstorecontrolstyle/placement)
- [`static var automatic: PagedPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/pagedpickersubscriptionstorecontrolstyle/placement/automatic)
- [`static var bottomBar: PagedPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/pagedpickersubscriptionstorecontrolstyle/placement/bottombar)
- [`static var buttonsInBottomBar: PagedPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/pagedpickersubscriptionstorecontrolstyle/placement/buttonsinbottombar)
- [`static var scrollView: PagedPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/pagedpickersubscriptionstorecontrolstyle/placement/scrollview)
- [`PagedProminentPickerSubscriptionStoreControlStyle`](https://developer.apple.com/documentation/storekit/pagedprominentpickersubscriptionstorecontrolstyle)
- [`init()`](https://developer.apple.com/documentation/storekit/pagedprominentpickersubscriptionstorecontrolstyle/init())
- [`PagedProminentPickerSubscriptionStoreControlStyle.Placement`](https://developer.apple.com/documentation/storekit/pagedprominentpickersubscriptionstorecontrolstyle/placement)
- [`PaymentMethodBinding`](https://developer.apple.com/documentation/storekit/paymentmethodbinding)
- [`func bind() async throws`](https://developer.apple.com/documentation/storekit/paymentmethodbinding/bind())
- [`let id: String`](https://developer.apple.com/documentation/storekit/paymentmethodbinding/id)
- [`init(id: String) async throws`](https://developer.apple.com/documentation/storekit/paymentmethodbinding/init(id:))
- [`PaymentMethodBinding.PaymentMethodBindingError`](https://developer.apple.com/documentation/storekit/paymentmethodbinding/paymentmethodbindingerror)
- [`case failed`](https://developer.apple.com/documentation/storekit/paymentmethodbinding/paymentmethodbindingerror/failed)
- [`case invalidPinningID`](https://developer.apple.com/documentation/storekit/paymentmethodbinding/paymentmethodbindingerror/invalidpinningid)
- [`case notEligible`](https://developer.apple.com/documentation/storekit/paymentmethodbinding/paymentmethodbindingerror/noteligible)
- [`var currentEntitlements: Transaction.Transactions`](https://developer.apple.com/documentation/storekit/product/currententitlements)
- [`var priceFormatStyle: Decimal.FormatStyle.Currency`](https://developer.apple.com/documentation/storekit/product/priceformatstyle)
- [`static let subscriptionBundle: Product.ProductType`](https://developer.apple.com/documentation/storekit/product/producttype/subscriptionbundle)
- [`static let subscriptionSuite: Product.ProductType`](https://developer.apple.com/documentation/storekit/product/producttype/subscriptionsuite)
- [`case paymentMethodBindingConfigurationRequired`](https://developer.apple.com/documentation/storekit/product/purchaseerror/paymentmethodbindingconfigurationrequired)
- [`static func billingPlanType(Product.SubscriptionInfo.BillingPlanType) -> Product.PurchaseOption`](https://developer.apple.com/documentation/storekit/product/purchaseoption/billingplantype(_:))
- [`static func codeOffer(referenceName: String) -> Product.PurchaseOption`](https://developer.apple.com/documentation/storekit/product/purchaseoption/codeoffer(referencename:))
- [`static func onStorefrontChange(shouldContinuePurchase: (Storefront) -> Bool) -> Product.PurchaseOption`](https://developer.apple.com/documentation/storekit/product/purchaseoption/onstorefrontchange(shouldcontinuepurchase:))
- [`static func promotionalOffer(id: String) -> Product.PurchaseOption`](https://developer.apple.com/documentation/storekit/product/purchaseoption/promotionaloffer(id:))
- [`static func promotionalOffer(offerID: String, signature: Product.SubscriptionOffer.Signature) -> Product.PurchaseOption`](https://developer.apple.com/documentation/storekit/product/purchaseoption/promotionaloffer(offerid:signature:))
- [`static func purchaseDate(Date, renewalBehavior: Product.PurchaseOption.SubscriptionRenewalBehavior) -> Product.PurchaseOption`](https://developer.apple.com/documentation/storekit/product/purchaseoption/purchasedate(_:renewalbehavior:))
- [`Product.PurchaseOption.SubscriptionRenewalBehavior`](https://developer.apple.com/documentation/storekit/product/purchaseoption/subscriptionrenewalbehavior)
- [`case cancelImmediately`](https://developer.apple.com/documentation/storekit/product/purchaseoption/subscriptionrenewalbehavior/cancelimmediately)
- [`case renewUntilNow`](https://developer.apple.com/documentation/storekit/product/purchaseoption/subscriptionrenewalbehavior/renewuntilnow)
- [`Product.SubscriptionInfo.BillingPeriod`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/billingperiod)
- [`Product.SubscriptionInfo.BillingPlanType`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/billingplantype)
- [`static let monthly: Product.SubscriptionInfo.BillingPlanType`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/billingplantype/monthly)
- [`static let upFront: Product.SubscriptionInfo.BillingPlanType`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/billingplantype/upfront)
- [`Product.SubscriptionInfo.BundledSubscription`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription)
- [`let description: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/description)
- [`let displayName: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/displayname)
- [`let displayPrice: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/displayprice)
- [`let id: Product.ID`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/id)
- [`let isFamilyShareable: Bool`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/isfamilyshareable)
- [`let price: Decimal`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/price)
- [`let subscriptionGroupDisplayName: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/subscriptiongroupdisplayname)
- [`let subscriptionGroupID: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/subscriptiongroupid)
- [`let subscriptionGroupLevel: Int`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscription/subscriptiongrouplevel)
- [`let bundledSubscriptions: [Product.SubscriptionInfo.BundledSubscription]`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/bundledsubscriptions)
- [`Product.SubscriptionInfo.CommitmentInfo`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/commitmentinfo)
- [`let displayPrice: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/commitmentinfo/displayprice)
- [`let period: SubscriptionPeriod`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/commitmentinfo/period)
- [`let price: Decimal`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/commitmentinfo/price)
- [`let pricingTerms: [Product.SubscriptionInfo.PricingTerms]`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.property)
- [`Product.SubscriptionInfo.PricingTerms`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct)
- [`let billingDisplayPrice: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct/billingdisplayprice)
- [`let billingPeriod: Product.SubscriptionInfo.BillingPeriod`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct/billingperiod)
- [`let billingPlanType: Product.SubscriptionInfo.BillingPlanType`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct/billingplantype)
- [`let billingPrice: Decimal`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct/billingprice)
- [`let commitmentInfo: Product.SubscriptionInfo.CommitmentInfo`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct/commitmentinfo)
- [`subscript(offers _: Product.SubscriptionOffer.OfferType) -> [Product.SubscriptionOffer]`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct/subscript(offers:))
- [`let subscriptionOffers: [Product.SubscriptionOffer]`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/pricingterms-swift.struct/subscriptionoffers)
- [`let advancedCommerceInfo: Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.property)
- [`Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct)
- [`let consistencyToken: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/consistencytoken)
- [`let description: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/description)
- [`let displayName: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/displayname)
- [`Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item)
- [`let details: Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.Details`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/details-swift.property)
- [`Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.Details`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/details-swift.typealias)
- [`let priceIncreaseInfo: Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.PriceIncreaseInfo?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.property)
- [`Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.PriceIncreaseInfo`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct)
- [`let dependentSKUs: [String]`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct/dependentskus)
- [`let price: Decimal`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct/price)
- [`let status: Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.PriceIncreaseInfo.Status`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct/status-swift.property)
- [`Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.PriceIncreaseInfo.Status`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct/status-swift.struct)
- [`static let accepted: Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.PriceIncreaseInfo.Status`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct/status-swift.struct/accepted)
- [`static let pending: Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.PriceIncreaseInfo.Status`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct/status-swift.struct/pending)
- [`static let scheduled: Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item.PriceIncreaseInfo.Status`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/item/priceincreaseinfo-swift.struct/status-swift.struct/scheduled)
- [`let items: [Product.SubscriptionInfo.RenewalInfo.AdvancedCommerceInfo.Item]`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/items)
- [`let period: SubscriptionPeriod`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/period)
- [`let requestReferenceID: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/requestreferenceid)
- [`let taxCode: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/advancedcommerceinfo-swift.struct/taxcode)
- [`var bundleOriginalTransactionID: String?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/bundleoriginaltransactionid)
- [`var bundleProductID: String?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/bundleproductid)
- [`var bundleSubscriptionGroupID: String?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/bundlesubscriptiongroupid)
- [`let commitmentInfo: Product.SubscriptionInfo.RenewalInfo.CommitmentInfo?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/commitmentinfo-swift.property)
- [`Product.SubscriptionInfo.RenewalInfo.CommitmentInfo`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/commitmentinfo-swift.struct)
- [`let autoRenewPreference: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/commitmentinfo-swift.struct/autorenewpreference)
- [`let renewalBillingPlanType: SubscriptionInfo.BillingPlanType`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/commitmentinfo-swift.struct/renewalbillingplantype)
- [`let renewalDate: Date`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/commitmentinfo-swift.struct/renewaldate)
- [`let renewalPrice: Decimal`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/commitmentinfo-swift.struct/renewalprice)
- [`let willAutoRenew: Bool`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/commitmentinfo-swift.struct/willautorenew)
- [`var localizedDescription: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/expirationreason-swift.struct/localizeddescription)
- [`static var unbundled: Product.SubscriptionInfo.RenewalInfo.ExpirationReason`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/expirationreason-swift.struct/unbundled)
- [`var localizedDescription: String`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/priceincreasestatus-swift.enum/localizeddescription)
- [`let renewalBillingPlanType: SubscriptionInfo.BillingPlanType?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/renewalbillingplantype)
- [`var willUnbundle: Bool`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/willunbundle)
- [`static func status(transactionID: UInt64) async throws -> SubscriptionStatus?`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/status(transactionid:))
- [`Product.SubscriptionInfo.Status.Statuses`](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/status-swift.struct/statuses)
- [`Product.SubscriptionOffer.Signature`](https://developer.apple.com/documentation/storekit/product/subscriptionoffer/signature)
- [`init(keyID: String, nonce: UUID, timestamp: Int, signature: Data)`](https://developer.apple.com/documentation/storekit/product/subscriptionoffer/signature/init(keyid:nonce:timestamp:signature:))
- [`var keyID: String`](https://developer.apple.com/documentation/storekit/product/subscriptionoffer/signature/keyid)
- [`var nonce: UUID`](https://developer.apple.com/documentation/storekit/product/subscriptionoffer/signature/nonce)
- [`var signature: Data`](https://developer.apple.com/documentation/storekit/product/subscriptionoffer/signature/signature)
- [`var timestamp: Int`](https://developer.apple.com/documentation/storekit/product/subscriptionoffer/signature/timestamp)
- [`func dateRange(referenceDate: Date) -> Range<Date>`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/daterange(referencedate:))
- [`static var everyThreeDays: Product.SubscriptionPeriod`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/everythreedays)
- [`static var everyTwoMonths: Product.SubscriptionPeriod`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/everytwomonths)
- [`static var everyTwoWeeks: Product.SubscriptionPeriod`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/everytwoweeks)
- [`func formatted<S>(S, referenceDate: Date) -> S.FormatOutput`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/formatted(_:referencedate:)-3t7wd)
- [`func formatted<S>(S, referenceDate: Date) -> S.FormatOutput`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/formatted(_:referencedate:)-8s3ar)
- [`Product.SubscriptionPeriod.Unit.FormatStyle`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/unit-swift.enum/formatstyle)
- [`func format(Product.SubscriptionPeriod.Unit) -> String`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/unit-swift.enum/formatstyle/format(_:))
- [`func formatted<S>(S) -> S.FormatOutput`](https://developer.apple.com/documentation/storekit/product/subscriptionperiod/unit-swift.enum/formatted(_:))
- [`var subscriptionPeriodFormatStyle: Date.ComponentsFormatStyle`](https://developer.apple.com/documentation/storekit/product/subscriptionperiodformatstyle)
- [`var subscriptionPeriodUnitFormatStyle: Product.SubscriptionPeriod.Unit.FormatStyle`](https://developer.apple.com/documentation/storekit/product/subscriptionperiodunitformatstyle)
- [`Product.TaskState`](https://developer.apple.com/documentation/storekit/product/taskstate)
- [`case failure(any Error)`](https://developer.apple.com/documentation/storekit/product/taskstate/failure(_:))
- [`case loading`](https://developer.apple.com/documentation/storekit/product/taskstate/loading)
- [`var product: Product?`](https://developer.apple.com/documentation/storekit/product/taskstate/product)
- [`case success(Product)`](https://developer.apple.com/documentation/storekit/product/taskstate/success(_:))
- [`case unavailable`](https://developer.apple.com/documentation/storekit/product/taskstate/unavailable)
- [`init(ProductViewStyleConfiguration)`](https://developer.apple.com/documentation/storekit/productview/init(_:))
- [`init(Product, icon: (ProductIconPhase) -> Icon)`](https://developer.apple.com/documentation/storekit/productview/init(_:icon:))
- [`init(id: Product.ID, icon: (ProductIconPhase) -> Icon, placeholderIcon: () -> PlaceholderIcon)`](https://developer.apple.com/documentation/storekit/productview/init(id:icon:placeholdericon:))
- [`let descriptionVisibility: Visibility`](https://developer.apple.com/documentation/storekit/productviewstyleconfiguration/descriptionvisibility)
- [`ProminentPickerSubscriptionStoreControlStyle`](https://developer.apple.com/documentation/storekit/prominentpickersubscriptionstorecontrolstyle)
- [`init()`](https://developer.apple.com/documentation/storekit/prominentpickersubscriptionstorecontrolstyle/init())
- [`func callAsFunction(AdvancedCommerceProduct, compactJWS: String, options: Set<AdvancedCommerceProduct.PurchaseOption>) async throws -> AdvancedCommerceProduct.PurchaseResult`](https://developer.apple.com/documentation/storekit/purchaseaction/callasfunction(_:compactjws:options:))
- [`RedeemOption`](https://developer.apple.com/documentation/storekit/redeemoption)
- [`static var adNetworkIdMissing: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/adnetworkidmissing)
- [`case adNetworkIdMissing`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/code/adnetworkidmissing)
- [`case invalidAdvertisedAppId`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/code/invalidadvertisedappid)
- [`case invalidCampaignId`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/code/invalidcampaignid)
- [`case invalidSourceAppId`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/code/invalidsourceappid)
- [`case mismatchedSourceAppId`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/code/mismatchedsourceappid)
- [`case unknown`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/code/unknown)
- [`static var impressionMissingRequiredValue: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/impressionmissingrequiredvalue)
- [`static var impressionNotFound: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/impressionnotfound)
- [`static var impressionTooShort: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/impressiontooshort)
- [`static var invalidAdvertisedAppId: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/invalidadvertisedappid)
- [`static var invalidCampaignId: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/invalidcampaignid)
- [`static var invalidSourceAppId: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/invalidsourceappid)
- [`static var invalidVersion: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/invalidversion)
- [`static var mismatchedSourceAppId: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/mismatchedsourceappid)
- [`static var unknown: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/unknown)
- [`static var unsupported: SKANError.Code`](https://developer.apple.com/documentation/storekit/skanerror-swift.struct/unsupported)
- [`SKArcadeService`](https://developer.apple.com/documentation/storekit/skarcadeservice)
- [`class func arcadeSubscriptionStatus(withNonce: UInt64, resultHandler: (Data?, UInt32, Data?, UInt32, (any Error)?) -> Void)`](https://developer.apple.com/documentation/storekit/skarcadeservice/arcadesubscriptionstatus(withnonce:resulthandler:))
- [`class func registerArcadeAppWithRandom(fromLib: Data, randomFromLibLength: UInt32, resultHandler: (Data?, UInt32, Data?, UInt32, (any Error)?) -> Void)`](https://developer.apple.com/documentation/storekit/skarcadeservice/registerarcadeappwithrandom(fromlib:randomfromliblength:resulthandler:))
- [`class func repairArcadeApp()`](https://developer.apple.com/documentation/storekit/skarcadeservice/repairarcadeapp())
- [`SKCloudServiceAuthorizationStatus`](https://developer.apple.com/documentation/storekit/skcloudserviceauthorizationstatus)
- [`case authorized`](https://developer.apple.com/documentation/storekit/skcloudserviceauthorizationstatus/authorized)
- [`case denied`](https://developer.apple.com/documentation/storekit/skcloudserviceauthorizationstatus/denied)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/storekit/skcloudserviceauthorizationstatus/init(rawvalue:))
- [`case notDetermined`](https://developer.apple.com/documentation/storekit/skcloudserviceauthorizationstatus/notdetermined)
- [`case restricted`](https://developer.apple.com/documentation/storekit/skcloudserviceauthorizationstatus/restricted)
- [`SKCloudServiceCapability`](https://developer.apple.com/documentation/storekit/skcloudservicecapability)
- [`static var addToCloudMusicLibrary: SKCloudServiceCapability`](https://developer.apple.com/documentation/storekit/skcloudservicecapability/addtocloudmusiclibrary)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/storekit/skcloudservicecapability/init(rawvalue:))
- [`static var musicCatalogPlayback: SKCloudServiceCapability`](https://developer.apple.com/documentation/storekit/skcloudservicecapability/musiccatalogplayback)
- [`static var musicCatalogSubscriptionEligible: SKCloudServiceCapability`](https://developer.apple.com/documentation/storekit/skcloudservicecapability/musiccatalogsubscriptioneligible)
- [`SKCloudServiceController`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller)
- [`class func authorizationStatus() -> SKCloudServiceAuthorizationStatus`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/authorizationstatus())
- [`class func requestAuthorization((SKCloudServiceAuthorizationStatus) -> Void)`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/requestauthorization(_:))
- [`func requestCapabilities(completionHandler: (SKCloudServiceCapability, (any Error)?) -> Void)`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/requestcapabilities(completionhandler:))
- [`func requestStorefrontCountryCode(completionHandler: (String?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/requeststorefrontcountrycode(completionhandler:))
- [`func requestStorefrontIdentifier(completionHandler: (String?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/requeststorefrontidentifier(completionhandler:))
- [`func requestUserToken(forDeveloperToken: String, completionHandler: (String?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/requestusertoken(fordevelopertoken:completionhandler:))
- [`static let subscribe: SKCloudServiceSetupAction`](https://developer.apple.com/documentation/storekit/skcloudservicesetupaction/subscribe)
- [`static let addMusic: SKCloudServiceSetupMessageIdentifier`](https://developer.apple.com/documentation/storekit/skcloudservicesetupmessageidentifier/addmusic)
- [`static let connect: SKCloudServiceSetupMessageIdentifier`](https://developer.apple.com/documentation/storekit/skcloudservicesetupmessageidentifier/connect)
- [`static let join: SKCloudServiceSetupMessageIdentifier`](https://developer.apple.com/documentation/storekit/skcloudservicesetupmessageidentifier/join)
- [`static let playMusic: SKCloudServiceSetupMessageIdentifier`](https://developer.apple.com/documentation/storekit/skcloudservicesetupmessageidentifier/playmusic)
- [`static let action: SKCloudServiceSetupOptionsKey`](https://developer.apple.com/documentation/storekit/skcloudservicesetupoptionskey/action)
- [`static let affiliateToken: SKCloudServiceSetupOptionsKey`](https://developer.apple.com/documentation/storekit/skcloudservicesetupoptionskey/affiliatetoken)
- [`static let campaignToken: SKCloudServiceSetupOptionsKey`](https://developer.apple.com/documentation/storekit/skcloudservicesetupoptionskey/campaigntoken)
- [`static let iTunesItemIdentifier: SKCloudServiceSetupOptionsKey`](https://developer.apple.com/documentation/storekit/skcloudservicesetupoptionskey/itunesitemidentifier)
- [`static let messageIdentifier: SKCloudServiceSetupOptionsKey`](https://developer.apple.com/documentation/storekit/skcloudservicesetupoptionskey/messageidentifier)
- [`SKCloudServiceSetupViewController`](https://developer.apple.com/documentation/storekit/skcloudservicesetupviewcontroller)
- [`var delegate: (any SKCloudServiceSetupViewControllerDelegate)?`](https://developer.apple.com/documentation/storekit/skcloudservicesetupviewcontroller/delegate)
- [`func load(options: [SKCloudServiceSetupOptionsKey : Any], completionHandler: ((Bool, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/storekit/skcloudservicesetupviewcontroller/load(options:completionhandler:))
- [`SKCloudServiceSetupViewControllerDelegate`](https://developer.apple.com/documentation/storekit/skcloudservicesetupviewcontrollerdelegate)
- [`func cloudServiceSetupViewControllerDidDismiss(SKCloudServiceSetupViewController)`](https://developer.apple.com/documentation/storekit/skcloudservicesetupviewcontrollerdelegate/cloudservicesetupviewcontrollerdiddismiss(_:))
- [`static var clientInvalid: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/clientinvalid)
- [`static var cloudServiceNetworkConnectionFailed: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/cloudservicenetworkconnectionfailed)
- [`static var cloudServicePermissionDenied: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/cloudservicepermissiondenied)
- [`static var cloudServiceRevoked: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/cloudservicerevoked)
- [`case paymentMethodBindingConfigurationRequired`](https://developer.apple.com/documentation/storekit/skerror/code/paymentmethodbindingconfigurationrequired)
- [`static var ineligibleForOffer: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/ineligibleforoffer)
- [`static var invalidOfferIdentifier: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/invalidofferidentifier)
- [`static var invalidOfferPrice: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/invalidofferprice)
- [`static var invalidSignature: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/invalidsignature)
- [`static var missingOfferParams: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/missingofferparams)
- [`static var overlayCancelled: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/overlaycancelled)
- [`static var overlayInvalidConfiguration: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/overlayinvalidconfiguration)
- [`static var overlayPresentedInBackgroundScene: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/overlaypresentedinbackgroundscene)
- [`static var overlayTimeout: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/overlaytimeout)
- [`static var paymentInvalid: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/paymentinvalid)
- [`static var paymentMethodBindingConfigurationRequired: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/paymentmethodbindingconfigurationrequired)
- [`static var paymentNotAllowed: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/paymentnotallowed)
- [`static var privacyAcknowledgementRequired: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/privacyacknowledgementrequired)
- [`static var unauthorizedRequestData: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/unauthorizedrequestdata)
- [`static var unsupportedPlatform: SKError.Code`](https://developer.apple.com/documentation/storekit/skerror/unsupportedplatform)
- [`func additionalValue(forKey: String) -> Any?`](https://developer.apple.com/documentation/storekit/skoverlay/appclipconfiguration/additionalvalue(forkey:))
- [`var customProductPageIdentifier: String?`](https://developer.apple.com/documentation/storekit/skoverlay/appclipconfiguration/customproductpageidentifier)
- [`var latestReleaseID: String?`](https://developer.apple.com/documentation/storekit/skoverlay/appclipconfiguration/latestreleaseid)
- [`func setAdditionalValue(Any?, forKey: String)`](https://developer.apple.com/documentation/storekit/skoverlay/appclipconfiguration/setadditionalvalue(_:forkey:))
- [`var adAttributionReengagementURL: URL?`](https://developer.apple.com/documentation/storekit/skoverlay/appconfiguration/adattributionreengagementurl)
- [`var appImpression: AppImpression?`](https://developer.apple.com/documentation/storekit/skoverlay/appconfiguration/appimpression)
- [`func setAdImpression(SKAdImpression)`](https://developer.apple.com/documentation/storekit/skoverlay/appconfiguration/setadimpression(_:))
- [`func addAnimation(() -> Void)`](https://developer.apple.com/documentation/storekit/skoverlay/transitioncontext/addanimation(_:))
- [`func storeOverlayDidFailToLoad(SKOverlay, error: any Error)`](https://developer.apple.com/documentation/storekit/skoverlaydelegate/storeoverlaydidfailtoload(_:error:))
- [`func storeOverlayDidFinishDismissal(SKOverlay, transitionContext: SKOverlay.TransitionContext)`](https://developer.apple.com/documentation/storekit/skoverlaydelegate/storeoverlaydidfinishdismissal(_:transitioncontext:))
- [`func storeOverlayDidFinishPresentation(SKOverlay, transitionContext: SKOverlay.TransitionContext)`](https://developer.apple.com/documentation/storekit/skoverlaydelegate/storeoverlaydidfinishpresentation(_:transitioncontext:))
- [`func storeOverlayWillStartDismissal(SKOverlay, transitionContext: SKOverlay.TransitionContext)`](https://developer.apple.com/documentation/storekit/skoverlaydelegate/storeoverlaywillstartdismissal(_:transitioncontext:))
- [`func storeOverlayWillStartPresentation(SKOverlay, transitionContext: SKOverlay.TransitionContext)`](https://developer.apple.com/documentation/storekit/skoverlaydelegate/storeoverlaywillstartpresentation(_:transitioncontext:))
- [`func paymentQueue(SKPaymentQueue, shouldContinue: SKPaymentTransaction, in: SKStorefront) -> Bool`](https://developer.apple.com/documentation/storekit/skpaymentqueuedelegate/paymentqueue(_:shouldcontinue:in:))
- [`func paymentQueueShouldShowPriceConsent(SKPaymentQueue) -> Bool`](https://developer.apple.com/documentation/storekit/skpaymentqueuedelegate/paymentqueueshouldshowpriceconsent(_:))
- [`SKProductStorePromotionController`](https://developer.apple.com/documentation/storekit/skproductstorepromotioncontroller)
- [`class func `default`() -> Self`](https://developer.apple.com/documentation/storekit/skproductstorepromotioncontroller/default())
- [`func fetchStorePromotionOrder(completionHandler: (([SKProduct], (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/storekit/skproductstorepromotioncontroller/fetchstorepromotionorder(completionhandler:))
- [`func fetchStorePromotionVisibility(for: SKProduct, completionHandler: ((SKProductStorePromotionVisibility, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/storekit/skproductstorepromotioncontroller/fetchstorepromotionvisibility(for:completionhandler:))
- [`func update(storePromotionOrder: [SKProduct], completionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/storekit/skproductstorepromotioncontroller/update(storepromotionorder:completionhandler:))
- [`func update(storePromotionVisibility: SKProductStorePromotionVisibility, for: SKProduct, completionHandler: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/storekit/skproductstorepromotioncontroller/update(storepromotionvisibility:for:completionhandler:))
- [`SKProductStorePromotionVisibility`](https://developer.apple.com/documentation/storekit/skproductstorepromotionvisibility)
- [`case `default``](https://developer.apple.com/documentation/storekit/skproductstorepromotionvisibility/default)
- [`case hide`](https://developer.apple.com/documentation/storekit/skproductstorepromotionvisibility/hide)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/storekit/skproductstorepromotionvisibility/init(rawvalue:))
- [`case show`](https://developer.apple.com/documentation/storekit/skproductstorepromotionvisibility/show)
- [`func loadProduct(parameters: [String : Any], impression: AppImpression) async throws`](https://developer.apple.com/documentation/storekit/skstoreproductviewcontroller/loadproduct(parameters:impression:))
- [`func loadProduct(parameters: [String : Any], impression: AppImpression, reengagementURL: URL) async throws`](https://developer.apple.com/documentation/storekit/skstoreproductviewcontroller/loadproduct(parameters:impression:reengagementurl:))
- [`func loadProduct(withParameters: [String : Any], impression: SKAdImpression, completionBlock: ((Bool, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/storekit/skstoreproductviewcontroller/loadproduct(withparameters:impression:completionblock:))
- [`func SKTerminateForInvalidReceipt()`](https://developer.apple.com/documentation/storekit/skterminateforinvalidreceipt())
- [`func productDescription(Visibility) -> some StoreContent`](https://developer.apple.com/documentation/storekit/storecontent/productdescription(_:))
- [`func subscriptionStoreControlBackground(SubscriptionStoreControlBackground) -> some StoreContent`](https://developer.apple.com/documentation/storekit/storecontent/subscriptionstorecontrolbackground(_:)-10hv8)
- [`func subscriptionStoreControlBackground(some ShapeStyle) -> some StoreContent`](https://developer.apple.com/documentation/storekit/storecontent/subscriptionstorecontrolbackground(_:)-3xzai)
- [`func subscriptionStoreControlStyle<S>(S, placement: S.Placement) -> some StoreContent`](https://developer.apple.com/documentation/storekit/storecontent/subscriptionstorecontrolstyle(_:placement:))
- [`func subscriptionStorePickerItemBackground(some ShapeStyle) -> some StoreContent`](https://developer.apple.com/documentation/storekit/storecontent/subscriptionstorepickeritembackground(_:))
- [`func subscriptionStorePickerItemBackground(some ShapeStyle, in: some Shape) -> some StoreContent`](https://developer.apple.com/documentation/storekit/storecontent/subscriptionstorepickeritembackground(_:in:))
- [`StoreDownloaderExtension`](https://developer.apple.com/documentation/storekit/storedownloaderextension)
- [`var currency: Locale.Currency?`](https://developer.apple.com/documentation/storekit/storefront/currency)
- [`Storefront.Storefronts`](https://developer.apple.com/documentation/storekit/storefront/storefronts)
- [`case invalidPresentationContext`](https://developer.apple.com/documentation/storekit/storekiterror/invalidpresentationcontext)
- [`init(ids: some Collection<String>, icon: (Product, ProductIconPhase) -> Icon, placeholderIcon: () -> PlaceholderIcon)`](https://developer.apple.com/documentation/storekit/storeview/init(ids:icon:placeholdericon:))
- … and 136 more (`isim/data/api-coverage.json.gz`)

</details>
<!-- /generated:missing -->
