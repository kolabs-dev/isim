# CryptoTokenKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 99.7% of Apple's iOS API (364 of 365, exact) · **Rows:** 14: 13 ✅ 1 🟡 · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Identity & security](../COVERAGE.md#security) · **Apple:** [CryptoTokenKit](https://developer.apple.com/documentation/cryptotokenkit) · **Issues:** [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

## How isim implements it

- **Approach:** adapted, isim's own engine (`isim/swift/overlays/CryptoTokenKit`). There is no card reader hardware. The readers are
  virtual, listed in the device data (`Library/isim/SmartCards/readers.json`) and driven with `isim smartcard list | insert
  [--demo | CARD.json] | remove | add-reader | remove-reader`. Each card has its ATR and an ISO 7816-4 responder:
  applets selected by AID, files (READ BINARY), data objects (GET DATA, PIV's GET DATA with a tag list), a PIN with a
  retry counter (VERIFY, CHANGE REFERENCE DATA), objects that need the PIN, scripted command → response pairs, GET
  RESPONSE for long answers and command chaining. `--demo` inserts a PIV card (PIN 123456). A reader with a PIN pad
  asks for the PIN in isim's PIN sheet (`ISIM_SMARTCARD_PIN` answers it without the sheet).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/CryptoTokenKit` over the Swift classes.
- **Versus Apple's Simulator:** the Simulator has no smart card readers. isim's virtual readers let apps run their card code
  end to end. Like iOS, apps need the `com.apple.security.smartcard` entitlement. Real readers through the host's PC/SC: #745.
- **Tokens:** persistent token extensions (#743) run in the process that uses their token, and their keys and
  certificates are in the keychain (`com.apple.token`), so apps can sign with a card's key through Security.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `TKSmartCardSlotManager` (`default`, `slotNames`, `slotNamed`, `getSlot(withName:reply:)`), `TKSmartCardSlot` (`state`, `atr`, `name`, `maxInputLength` / `maxOutputLength`, `makeSmartCard()`) | ✅ | ≤17 | adapted: the virtual readers; `default` is nil without the smart card entitlement; inserting and removing a card (the file changing) updates `state` and `atr` (KVO) and `slotNames`. Tested: test_smartcard (HelloSmartCard) |
| `TKSmartCard` (`beginSession`, `transmit`, `endSession`, `send(ins:p1:p2:data:le:)` with reply / throwing / async, `withSession`, `cla`, `useExtendedLength`, `useCommandChaining`, `allowedProtocols`, `currentProtocol`, `isValid`, `isSensitive`, `context`) | ✅ | ≤17 | adapted: one session per slot at a time; `send` follows 61xx (GET RESPONSE) and 6Cxx, and chains or uses extended length for long data; removing the card invalidates it. The card's security state (selected applet, verified PIN) resets when its session ends (proposed). Tested: test_smartcard |
| `TKSmartCardATR` (`bytes`, `protocols`, `historicalBytes`, `historicalRecords`, `interfaceGroup(at:)` / `(for:)`, `InterfaceGroup`), `TKSmartCardProtocol` | ✅ | ≤17 | adapted: ISO 7816-3 parsing (TA/TB/TC/TD, TCK checked); compact-TLV historical bytes. Tested: test_smartcard |
| `TKTLVRecord`, `TKBERTLVRecord`, `TKCompactTLVRecord`, `TKSimpleTLVRecord`, `TKTLVTag` | ✅ | ≤17 | adapted: encode and parse (multi-byte BER tags, long lengths). Tested: test_smartcard |
| `TKSmartCardPINFormat`, `TKSmartCardUserInteraction` (+ delegate), `TKSmartCardUserInteractionForPINOperation`, `…ForSecurePINVerification`, `…ForSecurePINChange` | ✅ | ≤17 | adapted: on a reader with a PIN pad, `run` asks for the PIN in isim's PIN sheet, puts it in the APDU in the PIN format (ASCII / BCD / binary, justification, length field) and sends it (`resultSW`, `resultData`); `cancel()` closes the sheet; nil on readers without a PIN pad. The delegate's key callbacks are not called (proposed: the sheet is not a key-by-key PIN pad). Tested: test_smartcard |
| `TKTokenWatcher` (`tokenIDs`, insertion / removal handlers, `tokenInfo(forTokenID:)`, `TokenInfo`) | ✅ | ≤17 | adapted: a virtual card whose entry names a `token` driver appears as that driver's token (`<driver>:<serial>`) while inserted; there are no token driver extensions yet. Tested: test_smartcard |
| `TKError` (`Code`, `errorDomain`) | ✅ | ≤17 | same codes. Tested: test_smartcard |
| `TKSmartCardSlotManager.createNFCSlot` / `isNFCSupported`, `TKSmartCardSlotNFCSession` | 🟡 | 16.4 | stub: NFC slots are not supported (`isNFCSupported()` is false) |
| `TKTokenDriver` (+ `TKTokenDriverDelegate`, `Configuration`), `TKSmartCardTokenDriver` (+ delegate), `TKToken` (+ `TKTokenDelegate`, `Configuration`), `TKSmartCardToken` | ✅ | ≤17 | adapted: a persistent token extension (`com.apple.ctk-tokens`; `com.apple.ctk.class-id`, `com.apple.ctk.aid`) in this app or an installed app is loaded in the process that uses the token (Apple runs it in its own); its driver makes a token for a virtual card that names its class ID or has an applet with one of its AIDs, in a session with the card; the token ID is `<class ID>:<instance ID>` (TKTokenWatcher reports it). Configurations are kept in the device data. Token extensions must be Swift: isim's classes cannot be subclassed from Objective-C. Tested: test_token (HelloToken) |
| `TKTokenKeychainContents`, `TKTokenKeychainItem`, `TKTokenKeychainKey`, `TKTokenKeychainCertificate` | ✅ | ≤17 | adapted: the inserted tokens' items appear in Security's keychain (`SecItemCopyMatching` keys, certificates and identities) in the access group `com.apple.token` (the app needs it in `keychain-access-groups`) with `kSecAttrTokenID`; a token key is a private key that cannot be exported. Tested: test_token |
| `TKTokenSession` (+ `TKTokenSessionDelegate`), `TKSmartCardTokenSession`, `TKTokenKeyAlgorithm`, `TKTokenKeyExchangeParameters`, `TKTokenOperation` | ✅ | ≤17 | adapted: `SecKeyCreateSignature`, `SecKeyCreateDecryptedData` and `SecKeyCopyKeyExchangeResult` on a token key run in a new session (with the card in a session); a message algorithm is converted to the digest form the session `supportsAlgorithm`, an X9.63 key exchange to the standard one (Security applies the KDF). Tested: test_token |
| `TKTokenAuthOperation`, `TKTokenPasswordAuthOperation`, `TKTokenSmartCardPINAuthOperation` | ✅ | ≤17 | adapted: when a session throws `authenticationNeeded`, its auth operation gets the PIN (or password) from isim's PIN sheet (`ISIM_SMARTCARD_PIN` answers it) and `finish` sends the APDU template with the PIN; then the operation runs again. Tested: test_token |
| `TKSmartCardTokenRegistrationManager` | ✅ | 26.0 | adapted: the registered tokens are kept in the device data; registering needs the token inserted. Tested: test_token |
| Virtual card: PIV GENERAL AUTHENTICATE | ✅ | ≤17 | isim: an applet's `keys` (EC P-256/P-384, X9.63) sign a challenge (ECDSA) or agree on a key (ECDH) once the PIN is verified, so token drivers can use the card's key. Tested: test_token |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
1 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`convenience init?(fromData: Data)`](https://developer.apple.com/documentation/cryptotokenkit/tktlvrecord/init(fromdata:))

</details>
<!-- /generated:missing -->
