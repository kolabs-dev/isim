# WalletOrders

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [Wallet Orders](https://developer.apple.com/documentation/walletorders) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

Apple's Wallet Orders documentation is the order package format and its update web service, which run on the merchant's server. On the device, an app creates an order with an Apple Pay payment: `PKPaymentAuthorizationResult.orderDetails` (PassKit).

## How isim implements it

- **Approach:** isim's own code in PassKit's Swift overlay (`isim/swift/overlays/PassKit/WalletPasses.swift`).
  - A successful Apple Pay payment whose result has `orderDetails` records the order in isim's Wallet in the device data, `$ISIM_DATA/Library/Wallet/Orders`: one JSON file with its type, identifier, web service URL, merchant and total.
  - `isim wallet orders` lists them.
- **Objective-C / C interface:** Swift only for now (issue #566).
- **Versus iOS:** Wallet fetches the order package from the web service and shows it; isim keeps only the details the app gave. There is no fetching, no order updates and no Wallet app.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `PKPaymentOrderDetails` (`init(orderTypeIdentifier:orderIdentifier:webServiceURL:authenticationToken:)`, its properties), `PKPaymentAuthorizationResult.orderDetails` | ✅ | 16.0 | adapted: recorded in isim's Wallet after the payment; tested (HelloApplePay, `test_apple_pay`) |
| Order packages (`.order` files), the order web service, Wallet's order tracking | ❌ | 16.0 | not on the device: the package is fetched by Wallet from the merchant's server |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
