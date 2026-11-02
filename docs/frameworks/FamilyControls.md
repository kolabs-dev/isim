# FamilyControls

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 98.0% of Apple's iOS API (49 of 50, exact) · **Rows:** 6: 4 ✅ 2 🟡 · **iOS:** 15.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [FamilyControls](https://developer.apple.com/documentation/familycontrols) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/FamilyControls`). Screen Time's authorization and the activity picker
  are simulated on the device; the answers live in `<isim data>/Library/isim/ScreenTime/`, where DeviceActivity,
  ManagedSettings and the home screen's shields (`isim/system/SpringBoard/SBScreenTime.m`) read them:
  - `AuthorizationCenter.requestAuthorization(for: .individual)` shows iOS's alert ("“App” Would Like to Access
    Screen Time", Continue / Don’t Allow); `ISIM_FAMILYCONTROLS_PERMISSION=allow|deny` answers it in scripts
    (SYSTEM-PROMPTS.md). The app needs the `com.apple.developer.family-controls` entitlement;
  - `.child` needs a Family Sharing parent's approval, which isim's account does not have: it fails with
    `invalidAccountType`;
  - `FamilyActivityPicker` lists the device's installed apps by Screen Time category (from each app's
    `LSApplicationCategoryType`). The selection holds opaque tokens (ManagedSettings' token registry), so the app
    never learns which apps were picked; `Label(token)` shows the name and icon, as on iOS.
  - `isim screentime status` prints each app's authorization (SCRIPTING.md).
- **Objective-C / C interface:** Swift only (as in Apple's SDK).
- **Versus Apple's Simulator:** Apple's Simulator does not run Screen Time (authorization fails there); isim's alert,
  picker and tokens behave as on a device signed in to an adult's account.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AuthorizationCenter` (`shared`, `authorizationStatus` and its publisher, `requestAuthorization(for:)`, `revokeAuthorization(completionHandler:)`) | ✅ | ≤17 | adapted: the Screen Time alert, the answer kept on the device; `.child` fails with `invalidAccountType`; tested (HelloScreenTime, test_screen_time) |
| `AuthorizationStatus`, `FamilyControlsMember`, `FamilyControlsError` | ✅ | ≤17 | adapted; tested (HelloScreenTime, test_screen_time) |
| `FamilyActivityPicker` (`init(selection:)`, headerText / footerText), `.familyActivityPicker(isPresented:selection:)` | ✅ | ≤17 | adapted: the installed apps by category, ids `family-category-ID`, `family-app-BUNDLE`, `family-done`, `family-cancel`; tested (HelloScreenTime, test_screen_time) |
| `FamilyActivitySelection` (`applicationTokens`, `categoryTokens`, `webDomainTokens`, `includeEntireCategory`, Codable) | ✅ | ≤17 | adapted: opaque tokens, names hidden from the app; tested (HelloScreenTime, test_screen_time) |
| `FamilyActivityTitleView`, `FamilyActivityIconView`, `Label(_:)` for tokens | 🟡 | ≤17 | adapted: the app's name and icon from the token registry; proposed |
| `FamilyActivityData` | 🟡 | 26.4 | adapted: the selection's apps and categories; proposed |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
1 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var $authorizationStatus: Published<AuthorizationStatus>.Publisher`](https://developer.apple.com/documentation/familycontrols/authorizationcenter/$authorizationstatus)

</details>
<!-- /generated:missing -->
