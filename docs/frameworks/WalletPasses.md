# WalletPasses

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Rows:** 8: 7 ✅ 1 ❌ · **iOS:** 6.0+
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [Wallet Passes](https://developer.apple.com/documentation/walletpasses) and [PassKit's passes](https://developer.apple.com/documentation/passkit/wallet) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

Apple's Wallet Passes documentation is the pass package format (`pass.json`, its fields, the update web service). The app API for passes is in PassKit, implemented here; Apple Pay is on [PassKit](PassKit.md).

## How isim implements it

- **Approach:** isim's own code in PassKit's Swift overlay (`isim/swift/overlays/PassKit/WalletPasses.swift`, `WalletViews.swift`).
  - `PKPass(data:)` reads the `.pkpass` archive (ZIP): `pass.json`, the images and the `.lproj/pass.strings` of the preferred language.
  - **isim's Wallet** is in the device data, `$ISIM_DATA/Library/Wallet/Passes` (one `.pkpass` per pass).
  - `isim wallet list|add FILE|remove TYPE SERIAL|clear` lists and edits it from outside the app, as opening a pass from Mail or Safari would.
- **Signatures:** isim checks what it can.
  - The manifest's SHA-1 hashes must match every file, and the archive must have a `signature`.
  - The signature's certificate chain to Apple's WWDR certificate is not checked: isim has no Apple trust store for passes (*adapted*). A pass iOS refuses for its signature, isim may accept.
- **The add sheet** draws each pass from its `pass.json`: the style's background, foreground and label colors, logo and logo text, header, primary, secondary and auxiliary fields, and the barcode (QR, PDF417, Aztec, Code 128, drawn with Core Image's generators). Its buttons are Cancel and Add (Update for passes already in Wallet). Wallet's real pass layouts (the boarding pass's transit icon, strip and thumbnail images, the back of the pass) are simplified.
- **Objective-C / C interface:** Swift only for now (issue #566).
- **Versus Apple's Simulator:**
  - The Simulator has a Wallet app; isim has none: `passURL` names the pass but opens nothing, and `isim wallet list` shows the passes.
  - An app sees every pass in isim's Wallet. iOS limits it to the pass type identifiers of its entitlements.
  - There are no pass updates from the `webServiceURL` (push notifications), no NFC passes, and no secure element passes.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `PKPass` (`init(data:)`, `passTypeIdentifier`, `serialNumber`, `organizationName`, `localizedName`, `localizedDescription`, `localizedValue(forFieldKey:)`, `relevantDates` and `PKPassRelevantDate`, `relevantDate`, `webServiceURL`, `authenticationToken`, `userInfo`, `icon`, `passType`, `deviceName`, `isRemotePass`, `passURL`), `PKObject`, `PKPassType` | ✅ | ≤17 | adapted: the manifest is checked, not the signature's chain; localized from `pass.strings`; field values are strings, numbers or dates (`dateStyle`); tested (HelloWallet, `test_wallet`) |
| `PKPassKitError` (`invalidDataError`, `unsupportedVersionError`, `invalidSignature`, `notEntitledError`, `unknownError`), `PKPassKitErrorDomain` | ✅ | ≤17 | invalid archives and pass.json: `invalidDataError`; a manifest that does not match or no signature: `invalidSignature`; tested |
| `PKPassLibrary` (`isPassLibraryAvailable()`, `passes()`, `passes(of:)`, `pass(withPassTypeIdentifier:serialNumber:)`, `containsPass`, `replacePass(with:)`, `removePass`, `addPasses(_:withCompletionHandler:)` and `async`, `addPasses(data:)`, `addPasses(fromArchiveData:)` / `fromArchiveAt:`, `PKPassLibraryAddPassesStatus`, `isSuppressingAutomaticPassPresentation()`) | ✅ | ≤17 | adapted: isim's Wallet in the device data; adding new passes asks with iOS's alert (Cancel, Review, Add All); tested |
| `PKPassLibraryNotificationName.PKPassLibraryDidChange`, `PKPassLibraryNotificationKey` (added, replacement, removed pass infos, pass type identifier, serial number) | ✅ | ≤17 | posted to the app that changed Wallet (not for `isim wallet` changes); tested |
| `PKAddPassesViewController` (`init?(pass:)`, `init?(passes:)`, `init?(passesData:)`, `init?(passesArchiveData:)`, `init?(passesArchiveAt:)`, `canAddPasses()`), `PKAddPassesViewControllerDelegate` | ✅ | ≤17 | adapted: the sheet above; Add stores the passes before `addPassesViewControllerDidFinish`; tested |
| `PKAddPassButton` (`init(addPassButtonStyle:)`, `addPassButtonStyle`), `PKAddPassButtonStyle` | ✅ | ≤17 | adapted: "Add to Apple Wallet" in words for Apple's artwork; tested |
| SwiftUI `AddPassToWalletButton` (`init(_:onCompletion:)` with and without a fallback, `init(action:)`), `AddPassToWalletButtonStyle`, `addPassToWalletButtonStyle(_:)` | ✅ | ≤17 | presents the add sheet; `onCompletion(true)` when the passes were added; tested |
| Secure element and payment passes (`PKSecureElementPass`, `secureElementPass`, issuer provisioning: `PKAddPaymentPassViewController`, `AddPassToWalletButton`'s provisioning forms, `PKAddSecureElementPassViewController`), `PKPassLibrary`'s secure element and FeliCa members, automatic pass presentation suppression, `PKAddPassesViewController(issuerData:signature:)` | ❌ | ≤17 | not yet (no secure element on isim); `canAddFelicaPass()` is false |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
