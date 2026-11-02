# ManagedSettingsUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (22 of 22, exact) · **Rows:** 2: 2 ✅ · **iOS:** 15.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [ManagedSettingsUI](https://developer.apple.com/documentation/managedsettingsui) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/ManagedSettingsUI`): when the home screen shields an app, it runs the
  owner's Shield Configuration extension (`com.apple.ManagedSettingsUI.shield-configuration-service`, a
  `ShieldConfigurationDataSource` subclass) as a helper process and draws the `ShieldConfiguration` it returns: the
  background (colour and blur style), icon, title, subtitle and the two buttons, in iOS's shield layout (ids `shield`,
  `shield-icon`, `shield-title`, `shield-subtitle`, `shield-primary`, `shield-secondary`). With no extension the
  shield shows a default ("Restricted", "You cannot use APP because it is restricted.", OK).
- **Objective-C / C interface:** Swift only (as in Apple's SDK).
- **Versus Apple's Simulator:** Apple's Simulator does not draw shields.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ShieldConfiguration` (`backgroundBlurStyle`, `backgroundColor`, `icon`, `title`, `subtitle`, `primaryButtonLabel`, `primaryButtonBackgroundColor`, `secondaryButtonLabel`, `Label`) | ✅ | ≤17 | adapted: drawn by the home screen; tested (HelloScreenTime, test_screen_time) |
| `ShieldConfigurationDataSource` (`configuration(shielding:)` for apps, categories and web domains) | ✅ | ≤17 | adapted: the extension runs as a helper per shield; tested (HelloScreenTime, test_screen_time) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
