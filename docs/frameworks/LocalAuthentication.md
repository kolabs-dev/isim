# LocalAuthentication

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 98.5% of Apple's iOS API (260 of 264, exact) · **Rows:** 8: 6 ✅ 2 ❌ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [Identity & security](../COVERAGE.md#security) · **Apple:** [LocalAuthentication](https://developer.apple.com/documentation/localauthentication) · **Issues:** [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

## How isim implements it

- **Adapted:** a simulated Face ID / Touch ID alert, with `ISIM_BIOMETRY` and `ISIM_BIOMETRY_ENROLLED`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| LocalAuthentication (Face ID / Touch ID, `LAContext`) | ✅ | ≤17 | `canEvaluatePolicy`/`evaluatePolicy` (+ async), `LAError`, `biometryType` from the device (Face ID; Touch ID on iPhone SE and non-Pro iPads). Face ID permission alert (`NSFaceIDUsageDescription`, remembered), simulated scan alert (Matching / Non-matching / Cancel), passcode fallback; `ISIM_BIOMETRY=match\|nomatch\|cancel`, `ISIM_BIOMETRY_ENROLLED=0`. Reply on a background queue like iOS |
| Biometry lockout, `LAContext.evaluateAccessControl(_:operation:localizedReason:)`, `setCredential(_:type:)` / `isCredentialSet(_:)`, `LAAccessControlOperation`, `LACredentialType`, the `kLA…` constants | ✅ | ≤17 | adapted: like iOS, three failed scans end an evaluation (`authenticationFailed`, or the passcode for `.deviceOwnerAuthentication`) and five in a row lock biometry out (`biometryLockout`) until the passcode is entered. The failures, the enrollment and whether a face / finger is enrolled are device-wide, in the global preferences. `evaluateAccessControl` asks for what the access control requires (`.biometryAny` / `.biometryCurrentSet`: biometry; `.userPresence` / `.devicePasscode`: biometry or the passcode; none: nothing), and keychain items and keys used with that context then don't ask again. `setCredential` keeps the application password with the context. Script: `biometry enrolled on\|off`, `biometry match\|nomatch` (the scan on screen, like the Simulator's Features ▸ Face ID menu), `biometry lockout\|reset`, `biometry` (the state). Tested: HelloSecurity (tests/ui/test_security.py `test_local_authentication`) |
| Rights (`LARight` with `State`, `LAAuthenticationRequirement`, `LABiometryFallbackRequirement`, `LARightStore`, `LAPersistedRight`, `LAPrivateKey`, `LAPublicKey`, `LASecret`) | ✅ | ≤17 | adapted (iOS 16): a right authorizes with Face ID / Touch ID, falling back to the passcode for `.default` and `.biometry(fallback: .devicePasscode)`. A saved right gets a P-256 key (isim's `SecKey`) and an optional secret, kept with the app's rights in its container (`Library/LocalAuthentication/rights.plist`), not in a Secure Enclave. The key signs, decrypts and exchanges keys, and the secret loads, only while the right is authorized (else `LAError.authenticationFailed`). A `.biometryCurrentSet` right stops authorizing once the enrollment changes (`invalidContext`). Saving an identifier that exists, or loading one that doesn't, fails with `invalidContext` (proposed: Apple doesn't document the codes). Tested: HelloSecurity |
| `LADomainState` (`LAContext.domainState`, `LADomainStateBiometry`, `LADomainStateCompanion`, `LACompanionType`), `LAEnvironment` (`currentUser`, `State`, `Mechanism`, `MechanismBiometry`, `MechanismUserPassword`, `MechanismCompanion`, `Observer`) | ✅ | 18.0 | adapted: isim's device has Face ID or Touch ID and a passcode, and no companion devices (no Apple Watch, Mac or Vision Pro). The state hashes change when a face / finger is enrolled again. Observers hear the biometry being enrolled, removed, locked out or unlocked, from this app, another app or the `biometry` command. The `LACompanionType` raw values are proposed. Tested: HelloSecurity (iOS 18; iOS 17: unavailable) |
| SwiftUI `LocalAuthenticationView` | ✅ | 17.0 | adapted: a button with the Face ID / Touch ID glyph that authenticates the device owner (biometry or the passcode) with the reason. Made with a context alone, it shows the app's own evaluations of that context (the glyph turns blue while the scan runs, green on success, red on failure). Tested: HelloSecurity |
| Objective-C interface (`LocalAuthentication.framework`, `<LocalAuthentication/LocalAuthentication.h>`): `LAContext`, `LAError`, the policies and constants, rights, `LADomainState`, `LAEnvironment` | ✅ | ≤17 | adapted: Apple's Objective-C names and selectors over the Swift overlay's classes; the framework re-exports `libswiftLocalAuthentication`. The classes are not subclassable from Objective-C. Tested: HelloKeychainObjC (tests/ui/test_keychain_objc.py) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `LAAuthenticationRequirement`, `LABiometryFallbackRequirement`, `LAPersistedRight`, `LAPrivateKey`, `LAPublicKey`, `LARight`, `LARight.State`, `LARightStore`, `LASecret` (9 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `LACompanionType`, `LADomainState`, `LADomainStateBiometry`, `LADomainStateCompanion`, `LAEnvironment` (5 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
4 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrCompanion: Int32`](https://developer.apple.com/documentation/localauthentication/klapolicydeviceownerauthenticationwithbiometricsorcompanion)
- [`var kLAPolicyDeviceOwnerAuthenticationWithCompanion: Int32`](https://developer.apple.com/documentation/localauthentication/klapolicydeviceownerauthenticationwithcompanion)
- [`case smartCardPIN`](https://developer.apple.com/documentation/localauthentication/lacredentialtype/smartcardpin)
- [`static var companionNotAvailable: LAError.Code`](https://developer.apple.com/documentation/localauthentication/laerror-swift.struct/companionnotavailable)

</details>
<!-- /generated:missing -->
