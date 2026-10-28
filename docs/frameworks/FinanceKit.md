# FinanceKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (190 of 190, exact) · **Rows:** 7: 6 ✅ 1 🧩 · **iOS:** 17.0+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [FinanceKit](https://developer.apple.com/documentation/financekit) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Decided (issue #398): a simulated store.** isim has no Wallet financial data, so the device keeps a simulated set in
  `ISIM_DATA/Library/isim/FinanceKit/data.json`: `isim finance seed` adds an example credit card ("Apple Card", a
  liability account with credit information) and a savings account with transactions, `isim finance add-transaction
  <account> <amount> <merchant> [--type T] [--status S] [--mcc NNNN]` adds more, `isim finance list` and `clear`.
  Every change goes into a log the histories read.
- Access needs the `com.apple.developer.financekit` entitlement and the person's permission: isim's prompt, remembered
  per app (`ISIM_FINANCEKIT_PERMISSION=allow|deny` answers it). Without either, data calls throw
  `FinanceError.dataRestricted`.
- Orders: `saveOrder(signedArchive:)` reads the `.order` archive's `order.json`, asks with isim's "Add Order to Wallet?"
  alert (`ISIM_FINANCEKIT_ORDER=add|cancel`) and adds it to isim's Wallet (`Library/Wallet/Orders`, listed by `isim wallet
  orders`); the archive's signature is not checked.
- **Objective-C / C interface:** Swift only, as in Apple's SDK.
- **Versus a device:** no banks or Apple Card behind the data; background delivery extensions are not run.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `FinanceStore.shared`, `isDataAvailable(_:)`, `authorizationStatus()`, `requestAuthorization()`, `AuthorizationStatus` | ✅ | 17.4 | adapted: financial data is available once `isim finance seed` made it; isim's access prompt (allow and deny tested). Tested (HelloFinance, test_finance) |
| `accounts(query:)`, `accountBalances(query:)`, `transactions(query:)`, `AccountQuery`, `AccountBalanceQuery` (with its date predicates), `TransactionQuery` (with its status, type and merchant category predicates), sort descriptors, limit and offset | ✅ | 17.4 | the simulated store, filtered with Foundation's `Predicate` and sorted with `SortDescriptor` (accounts sorted by name, pending and merchant-category queries tested) |
| `Account`, `AssetAccount`, `LiabilityAccount`, `AccountCreditInformation`, `AccountBalance`, `Balance`, `CurrentBalance`, `CurrencyAmount`, `CreditDebitIndicator`, `Transaction`, `TransactionType`, `TransactionStatus`, `MerchantCategoryCode` | ✅ | 17.4 | Codable value types, as stored in the device's data |
| `accountHistory(since:isMonitoring:)`, `accountBalanceHistory(forAccountID:since:isMonitoring:)`, `transactionHistory(forAccountID:since:isMonitoring:)`, `History`, `Changes`, `HistoryToken` | ✅ | 17.4 | adapted: everything at first (without a token), then the inserted, updated and deleted items from the store's change log (checked twice a second while monitoring); a token from another store throws `historyTokenInvalid` (a transaction added with `isim finance add-transaction` delivered: tested) |
| `containsOrder(matching:updatedDate:)`, `saveOrder(signedArchive:)`, `FullyQualifiedOrderIdentifier`, `ContainsOrderResult`, `SaveOrderResult` | ✅ | 17.4 | adapted: isim's Wallet orders (an order added and listed by `isim wallet orders`: tested) |
| `FinanceError` | ✅ | 17.4 | `dataRestricted` without the entitlement or permission |
| `enableBackgroundDelivery(for:frequency:)`, `disableBackgroundDelivery(for:)`, `disableAllBackgroundDelivery()`, `BackgroundDataType`, `UpdateFrequency`, `BackgroundDeliveryExtension`, `BackgroundDeliveryExtensionProviding` | 🧩 | 26.0 | stub: logged; isim does not run background delivery extensions |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
