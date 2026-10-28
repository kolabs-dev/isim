# ManagedSettings

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [ManagedSettings](https://developer.apple.com/documentation/managedsettings) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/ManagedSettings`):
  - a `ManagedSettingsStore`'s settings live in `<isim data>/Library/isim/ScreenTime/Stores/<bundle id>/<name>.json`;
  - the home screen (`isim/system/SpringBoard/SBScreenTime.m`) applies the **shield** settings of the stores of the
    apps Screen Time authorized: launching a shielded app (an app token, or an app of a shielded category) shows the
    shield instead, drawn from the owner's Shield Configuration extension (ManagedSettingsUI) and answered by its Shield
    Action extension (`ShieldActionDelegate`; `close` returns to the home screen, `defer` keeps the shield);
  - the other groups (account, application, App Store, cellular, date and time, Game Center, media, passcode, Safari,
    Siri, web content) are kept and reported; their `effective…` values are the strictest across the device's stores,
    but isim's system apps do not enforce them;
  - tokens (`ApplicationToken`, `ActivityCategoryToken`, `WebDomainToken`) are opaque ids in the device's token
    registry (`tokens.json`): only system UI (the picker, the shield, `Label`) resolves them;
  - `isim screentime status` lists the shields in force (SCRIPTING.md).
- **Objective-C / C interface:** Swift only (as in Apple's SDK).
- **Versus Apple's Simulator:** Apple's Simulator does not apply shields; isim does, on its home screen.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ManagedSettingsStore` (`init()`, `init(named:)`, the settings groups, `clearAllSettings()`, `delete()`, `clearAllSettings(for:)` …) | ✅ | ≤17 | adapted: kept on the device per app and store; tested (HelloScreenTime, test_screen_time) |
| `ShieldSettings` (`applications`, `applicationCategories`, `webDomains`, `webDomainCategories`) | ✅ | ≤17 | adapted: the home screen shields the apps at launch; tested (HelloScreenTime, test_screen_time) |
| `ShieldAction`, `ShieldActionResponse`, `ShieldActionDelegate` | ✅ | ≤17 | adapted: the Shield Action extension (`com.apple.ManagedSettings.shield-action-service`) runs as a helper per button; tested (HelloScreenTime, test_screen_time) |
| the other settings groups (`AccountSettings` … `WebContentSettings`), `SettingMetadata`, `BoundedSettingMetadata` | 🟡 | ≤17 | adapted: kept and reported, not enforced by isim's system apps; proposed |
| `effectiveMaximumMovieRating`, `effectiveMaximumTVShowRating`, `effectiveDenyExplicitContent` | ✅ | ≤17 | adapted: the strictest across the device's stores; tested (HelloScreenTime, test_screen_time) |
| `Application`, `WebDomain`, `ActivityCategory`, `Token` | ✅ | ≤17 | adapted: opaque tokens in the device's registry; tested (HelloScreenTime, test_screen_time) |
| `ManagedSettingsStore.isActive`, store names listing | 🟡 | 26.5 | adapted; proposed |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
