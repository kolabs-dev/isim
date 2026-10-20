# StoreKitTest

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Developer tools](../COVERAGE.md#devtools) · **Apple:** [StoreKitTest](https://developer.apple.com/documentation/storekittest) · **Issues:** [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

## How isim implements it

- **Approach:** `isim/swift/overlays/StoreKitTest/StoreKitTest.swift`. `SKTestSession` drives isim's local store,
  the same one apps buy from and that `isim storekit` edits, through hooks in the StoreKit overlay
  (`StoreKitTesting.swift`). Changes take effect in the app's process at once, as with Xcode's StoreKit Testing.
  Tests run with `isim test`, hosted in the app (TEST_HOST) like Xcode's.
- **Configuration files:** `SKTestSession(configurationFileNamed:)` looks in the test and app bundles, then in the
  project's folders: Xcode does not copy `.storekit` files into products, so `isim test` passes the project's root to
  the test process (`ISIM_SRCROOT`).
- **Objective-C / C interface:** Swift only for now (Apple's `SKTestSession` is an Objective-C class).
- **Versus Xcode:** the same session operations. Price increase consent is accepted without effect, because isim's
  local store has no price increases. Simulated errors (`setSimulatedError(_:forAPI:)`) are not there yet.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SKTestSession` (`init(configurationFileNamed:)`, `init(contentsOf:)`, `resetToDefaultState()`, `storefront`, `locale`, `disableDialogs`, `allTransactions()`, `deleteTransaction(identifier:)`, `clearTransactions()`) | ✅ | ≤17 | adapted: the session loads its configuration in place of the bundle's; `disableDialogs` confirms purchases without the sheet and skips StoreKit's notices; tested (HelloStoreTesting, `test_storekit_test`) |
| Ask to Buy and interrupted purchases (`askToBuyEnabled`, `approveAskToBuyTransaction`, `declineAskToBuyTransaction`, `interruptedPurchasesEnabled`, `resolveIssueForTransaction`) | ✅ | ≤17 | purchases return `.pending` and wait as requests; approving or resolving one makes the transaction and delivers it in `Transaction.updates`; tested |
| Subscriptions (`timeRate` and `SKTestSession.TimeRate`, `enableAutoRenewForTransaction`, `disableAutoRenewForTransaction`, `forceRenewalOfSubscription`, `expireSubscription`, `billingGracePeriodIsEnabled`, `shouldEnterBillingRetryOnRenewal`) | ✅ | ≤17 | adapted: forcing a renewal ends the current period, so the subscription clock renews at once; billing retry marks the subscriptions' renewals as failing; tested (renewal, expiration, auto-renew) |
| `refundTransaction(identifier:)`, `buyProduct(identifier:options:)`, `buyProduct(productIdentifier:)` | ✅ | ≤17 | a purchase outside the app: no sheet, and the transaction arrives in `Transaction.updates`; tested |
| `SKTestTransaction` (`identifier`, `productIdentifier`, `state`, `purchaseDate`, `expirationDate`, `autoRenewingEnabled`, `hasPurchaseIssue`, `pendingAskToBuyConfirmation`, `refunded`, ...) | ✅ | ≤17 | the local store's transactions and waiting requests, oldest first; tested |
| Price increase consent (`requestPriceIncreaseConsentForTransaction`, `consentToPriceIncreaseForTransaction`, `declinePriceIncreaseForTransaction`) | 🟡 | ≤17 | stub: accepted for existing transactions, without effect (no price increases in isim's local store) |
| `failTransactionsEnabled`, `failureError` (deprecated in iOS 17) | 🟡 | ≤17 | stub: kept; purchases do not fail |
| Simulated errors (`setSimulatedError(_:forAPI:)`, `simulatedError(forAPI:)`) | ❌ | 17.0 | not yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
