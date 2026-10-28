# FinanceKitUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (25 of 25, exact) · **Rows:** 3: 2 ✅ 1 🧩 · **iOS:** 17.0+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [FinanceKitUI](https://developer.apple.com/documentation/financekitui) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** on isim's simulated Wallet financial data ([FinanceKit](FinanceKit.md), `isim finance seed`).
- **Objective-C / C interface:** Swift only, as in Apple's SDK.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `TransactionPicker(selection:label:)` | ✅ | 17.4 | adapted: a sheet listing Wallet's transactions (newest first); the person ticks some and shares them, which writes them to the binding; the app needs no FinanceKit authorization for them. The sheet is isim's. Tested (HelloFinance, test_finance) |
| `AddOrderToWalletButton(signedArchive:onCompletion:)`, `AddOrderToWalletButtonStyle` (`black`, `blackOutline`), `addOrderToWalletButtonStyle(_:)` | ✅ | 17.4 | the button saves the order with `FinanceStore.saveOrder` (tested); isim draws the button without Apple's Wallet logo |
| `FinancialConnectionUIExtension`, `FinancialConnectionUIExtensionProviding`, `FinancialConnectionUIExtensionScene`, `FinancialConnectionUIExtensionAuthorizationScene`, `FinancialConnectionExtensionAuthorizationRequest`, `FinancialConnectionExtensionAuthorizationResult`, `FinancialConnectionExtensionAuthorizationParams` | 🧩 | 26.0 | stub: the types exist for apps that declare the extension; isim does not run it (`FinancialConnectionExtensionAuthorizationParams` is isim's `[String: String]`) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
