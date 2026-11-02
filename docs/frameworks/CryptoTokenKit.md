# CryptoTokenKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 71.0% of Apple's iOS API (259 of 365, exact) · **Rows:** 9: 7 ✅ 1 🟡 1 ❌ · **iOS:** 13.0+
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
| Token drivers and tokens (`TKTokenDriver`, `TKToken`, `TKTokenSession`, `TKSmartCardTokenDriver`, `TKSmartCardToken`, `TKTokenKeychain*`, `TKSmartCardTokenRegistrationManager`, …) | ❌ | ≤17 | not yet: the persistent token extensions (#743) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
106 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`TKSmartCardToken`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtoken)
- [`var aid: Data?`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtoken/aid)
- [`init(smartCard: TKSmartCard, aid: Data?, instanceID: String, tokenDriver: TKSmartCardTokenDriver)`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtoken/init(smartcard:aid:instanceid:tokendriver:)-38ak2)
- [`init(smartCard: TKSmartCard, AID: Data?, instanceID: String, tokenDriver: TKSmartCardTokenDriver)`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtoken/init(smartcard:aid:instanceid:tokendriver:)-90hza)
- [`TKSmartCardTokenDriver`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokendriver)
- [`TKSmartCardTokenDriverDelegate`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokendriverdelegate)
- [`func tokenDriver(TKSmartCardTokenDriver, createTokenFor: TKSmartCard, aid: Data?) throws -> TKSmartCardToken`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokendriverdelegate/tokendriver(_:createtokenfor:aid:))
- [`TKSmartCardTokenRegistrationManager`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokenregistrationmanager)
- [`class var `default`: TKSmartCardTokenRegistrationManager`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokenregistrationmanager/default)
- [`var registeredSmartCardTokens: [String]`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokenregistrationmanager/registeredsmartcardtokens)
- [`func registerSmartCard(tokenID: String, promptMessage: String) throws`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokenregistrationmanager/registersmartcard(tokenid:promptmessage:))
- [`func unregisterSmartCard(tokenID: String) throws`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokenregistrationmanager/unregistersmartcard(tokenid:))
- [`TKSmartCardTokenSession`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokensession)
- [`func getSmartCard() throws -> TKSmartCard`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokensession/getsmartcard())
- [`var smartCard: TKSmartCard`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokensession/smartcard)
- [`convenience init?(fromData: Data)`](https://developer.apple.com/documentation/cryptotokenkit/tktlvrecord/init(fromdata:))
- [`TKToken`](https://developer.apple.com/documentation/cryptotokenkit/tktoken)
- [`TKToken.Configuration`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/configuration-swift.class)
- [`func certificate(for: TKToken.ObjectID) throws -> TKTokenKeychainCertificate`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/configuration-swift.class/certificate(for:))
- [`var configurationData: Data?`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/configuration-swift.class/configurationdata)
- [`var instanceID: TKToken.InstanceID`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/configuration-swift.class/instanceid)
- [`func key(for: TKToken.ObjectID) throws -> TKTokenKeychainKey`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/configuration-swift.class/key(for:))
- [`var keychainItems: [TKTokenKeychainItem]`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/configuration-swift.class/keychainitems)
- [`var configuration: TKToken.Configuration`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/configuration-swift.property)
- [`var delegate: (any TKTokenDelegate)?`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/delegate)
- [`init(tokenDriver: TKTokenDriver, instanceID: TKToken.InstanceID)`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/init(tokendriver:instanceid:))
- [`TKToken.InstanceID`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/instanceid)
- [`var keychainContents: TKTokenKeychainContents?`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/keychaincontents)
- [`TKToken.ObjectID`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/objectid)
- [`TKToken.ObjectID`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/objectid)
- [`TKToken.ObjectID`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/objectid)
- [`var tokenDriver: TKTokenDriver`](https://developer.apple.com/documentation/cryptotokenkit/tktoken/tokendriver)
- [`TKTokenAuthOperation`](https://developer.apple.com/documentation/cryptotokenkit/tktokenauthoperation)
- [`func finish() throws`](https://developer.apple.com/documentation/cryptotokenkit/tktokenauthoperation/finish())
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/cryptotokenkit/tktokenauthoperation/init(coder:))
- [`TKTokenDelegate`](https://developer.apple.com/documentation/cryptotokenkit/tktokendelegate)
- [`func createSession(TKToken) throws -> TKTokenSession`](https://developer.apple.com/documentation/cryptotokenkit/tktokendelegate/createsession(_:))
- [`func token(TKToken, terminateSession: TKTokenSession)`](https://developer.apple.com/documentation/cryptotokenkit/tktokendelegate/token(_:terminatesession:))
- [`TKTokenDriver`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver)
- [`TKTokenDriver.ClassID`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/classid)
- [`TKTokenDriver.Configuration`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/configuration)
- [`func addTokenConfiguration(for: TKToken.InstanceID) -> TKToken.Configuration`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/configuration/addtokenconfiguration(for:))
- [`var classID: TKTokenDriver.ClassID`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/configuration/classid)
- [`class var driverConfigurations: [TKTokenDriver.ClassID : TKTokenDriver.Configuration]`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/configuration/driverconfigurations)
- [`func removeTokenConfiguration(for: TKToken.InstanceID)`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/configuration/removetokenconfiguration(for:))
- [`var tokenConfigurations: [TKToken.InstanceID : TKToken.Configuration]`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/configuration/tokenconfigurations)
- [`var delegate: (any TKTokenDriverDelegate)?`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriver/delegate)
- [`TKTokenDriverDelegate`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriverdelegate)
- [`func tokenDriver(TKTokenDriver, terminateToken: TKToken)`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriverdelegate/tokendriver(_:terminatetoken:))
- [`func tokenDriver(TKTokenDriver, tokenFor: TKToken.Configuration) throws -> TKToken`](https://developer.apple.com/documentation/cryptotokenkit/tktokendriverdelegate/tokendriver(_:tokenfor:))
- [`TKTokenKeyAlgorithm`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeyalgorithm)
- [`func isAlgorithm(SecKeyAlgorithm) -> Bool`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeyalgorithm/isalgorithm(_:))
- [`func supportsAlgorithm(SecKeyAlgorithm) -> Bool`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeyalgorithm/supportsalgorithm(_:))
- [`TKTokenKeychainCertificate`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincertificate)
- [`var data: Data`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincertificate/data)
- [`init?(certificate: SecCertificate, objectID: TKToken.ObjectID)`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincertificate/init(certificate:objectid:))
- [`TKTokenKeychainContents`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincontents)
- [`func certificate(forObjectID: TKToken.ObjectID) throws -> TKTokenKeychainCertificate`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincontents/certificate(forobjectid:))
- [`func fill(with: [TKTokenKeychainItem])`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincontents/fill(with:))
- [`var items: [TKTokenKeychainItem]`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincontents/items)
- [`func key(forObjectID: TKToken.ObjectID) throws -> TKTokenKeychainKey`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychaincontents/key(forobjectid:))
- [`TKTokenKeychainItem`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainitem)
- [`var constraints: [NSNumber : Any]?`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainitem/constraints)
- [`init(objectID: TKToken.ObjectID)`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainitem/init(objectid:))
- [`var label: String?`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainitem/label)
- [`var objectID: TKToken.ObjectID`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainitem/objectid)
- [`TKTokenKeychainKey`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey)
- [`var applicationTag: Data?`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/applicationtag)
- [`var canDecrypt: Bool`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/candecrypt)
- [`var canPerformKeyExchange: Bool`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/canperformkeyexchange)
- [`var canSign: Bool`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/cansign)
- [`init?(certificate: SecCertificate?, objectID: TKToken.ObjectID)`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/init(certificate:objectid:))
- [`var isSuitableForLogin: Bool`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/issuitableforlogin)
- [`var keySizeInBits: Int`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/keysizeinbits)
- [`var keyType: String`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/keytype)
- [`var publicKeyData: Data?`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/publickeydata)
- [`var publicKeyHash: Data?`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeychainkey/publickeyhash)
- [`TKTokenKeyExchangeParameters`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeyexchangeparameters)
- [`var requestedSize: Int`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeyexchangeparameters/requestedsize)
- [`var sharedInfo: Data?`](https://developer.apple.com/documentation/cryptotokenkit/tktokenkeyexchangeparameters/sharedinfo)
- [`TKTokenOperation`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperation)
- [`case decryptData`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperation/decryptdata)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperation/init(rawvalue:))
- [`case none`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperation/none)
- [`case performKeyExchange`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperation/performkeyexchange)
- [`case readData`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperation/readdata)
- [`case signData`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperation/signdata)
- [`TKTokenOperationConstraint`](https://developer.apple.com/documentation/cryptotokenkit/tktokenoperationconstraint)
- [`TKTokenPasswordAuthOperation`](https://developer.apple.com/documentation/cryptotokenkit/tktokenpasswordauthoperation)
- [`var password: String?`](https://developer.apple.com/documentation/cryptotokenkit/tktokenpasswordauthoperation/password)
- [`TKTokenSession`](https://developer.apple.com/documentation/cryptotokenkit/tktokensession)
- [`var delegate: (any TKTokenSessionDelegate)?`](https://developer.apple.com/documentation/cryptotokenkit/tktokensession/delegate)
- [`init(token: TKToken)`](https://developer.apple.com/documentation/cryptotokenkit/tktokensession/init(token:))
- [`var token: TKToken`](https://developer.apple.com/documentation/cryptotokenkit/tktokensession/token)
- [`TKTokenSessionDelegate`](https://developer.apple.com/documentation/cryptotokenkit/tktokensessiondelegate)
- [`func tokenSession(TKTokenSession, beginAuthFor: TKTokenOperation, constraint: Any) throws -> TKTokenAuthOperation`](https://developer.apple.com/documentation/cryptotokenkit/tktokensessiondelegate/tokensession(_:beginauthfor:constraint:))
- [`func tokenSession(TKTokenSession, decrypt: Data, keyObjectID: TKToken.ObjectID, algorithm: TKTokenKeyAlgorithm) throws -> Data`](https://developer.apple.com/documentation/cryptotokenkit/tktokensessiondelegate/tokensession(_:decrypt:keyobjectid:algorithm:))
- [`func tokenSession(TKTokenSession, performKeyExchange: Data, keyObjectID: TKToken.ObjectID, algorithm: TKTokenKeyAlgorithm, parameters: TKTokenKeyExchangeParameters) throws -> Data`](https://developer.apple.com/documentation/cryptotokenkit/tktokensessiondelegate/tokensession(_:performkeyexchange:keyobjectid:algorithm:parameters:))
- [`func tokenSession(TKTokenSession, sign: Data, keyObjectID: TKToken.ObjectID, algorithm: TKTokenKeyAlgorithm) throws -> Data`](https://developer.apple.com/documentation/cryptotokenkit/tktokensessiondelegate/tokensession(_:sign:keyobjectid:algorithm:))
- [`func tokenSession(TKTokenSession, supports: TKTokenOperation, keyObjectID: TKToken.ObjectID, algorithm: TKTokenKeyAlgorithm) -> Bool`](https://developer.apple.com/documentation/cryptotokenkit/tktokensessiondelegate/tokensession(_:supports:keyobjectid:algorithm:))
- [`TKTokenSmartCardPINAuthOperation`](https://developer.apple.com/documentation/cryptotokenkit/tktokensmartcardpinauthoperation)
- [`var apduTemplate: Data?`](https://developer.apple.com/documentation/cryptotokenkit/tktokensmartcardpinauthoperation/apdutemplate)
- [`var pin: String?`](https://developer.apple.com/documentation/cryptotokenkit/tktokensmartcardpinauthoperation/pin)
- [`var pinByteOffset: Int`](https://developer.apple.com/documentation/cryptotokenkit/tktokensmartcardpinauthoperation/pinbyteoffset)
- [`var pinFormat: TKSmartCardPINFormat`](https://developer.apple.com/documentation/cryptotokenkit/tktokensmartcardpinauthoperation/pinformat)
- [`var smartCard: TKSmartCard?`](https://developer.apple.com/documentation/cryptotokenkit/tktokensmartcardpinauthoperation/smartcard)

</details>
<!-- /generated:missing -->
