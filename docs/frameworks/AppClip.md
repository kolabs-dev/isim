# AppClip

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (17 of 17, exact) · **Rows:** 100% (1: 1 ✅) · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [AppClip](https://developer.apple.com/documentation/appclip) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** invocations through `SBAppClips.m`; location checks use the simulated location.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| App Clips | ✅ | ≤17 | adapted: `isim build` builds App Clip targets (product type `…application.on-demand-install-capable`) and embeds them in `<App>.app/AppClips/` (Xcode's Embed App Clips phase), warning about a bundle ID outside the full app's or missing `parent-application-identifiers` / `on-demand-install-capable` entitlements; `isim install Clip.app` stands in for iOS caching it (not on the home screen; a full app's AppClips/ is not installed with it). Under `isim boot` an invocation, script `appclip URL [code\|nfc]` (a scanned App Clip Code, QR code or NFC tag) or `openurl` (a link), matches a local experience (Settings › Developer › Local Experiences, `appclip register`) or an installed App Clip's `appclips:` domain: the shell shows the App Clip card (header image, title, subtitle, Open/View/Play, the ephemeral-notification and location-confirmation notes, a tap turns them off; iOS 17/18 opaque, floating on Face ID iPhones, iOS 26/27 Liquid Glass) and launches the App Clip with an `NSUserActivity` (`NSUserActivityTypeBrowsingWeb`, `webpageURL`) in `connectionOptions.userActivities`, `scene(_:continue:)`, `onContinueUserActivity`; with the full app installed, a default experience opens the full app instead. AppClip framework (Swift-only): `NSUserActivity.appClipActivationPayload`, `APActivationPayload.confirmAcquired(in:)` checks the simulated location (`disallowed` for links, `_XCAppClipURL` or when turned off on the card; `doesNotMatch`), `APActivationPayloadError`. `UNAuthorizationStatus.ephemeral` without a prompt for 8 hours after each launch (`NSAppClipRequestEphemeralUserNotification`); `SKOverlay.AppClipConfiguration` shows the full app's App Store listing; data migrates through the app group shared with the full app; the App Library's Recently Added relaunches it with its last URL; `appclip expire` deletes its data (iOS: after inactivity); `_XCAppClipURL` with `isim run` launches it with the URL, like Xcode. Tested (appclips, iOS 17–27). Not: App Store Connect experiences (a default card shows the App Clip's name and the URL's host), invocations from the camera / Code Scanner, Safari's Smart App Banner, Messages, Maps and Siri suggestions, `target-content-id` routing to several App Clip instances, the App Clip size limits and API restrictions (not enforced), Settings › App Clips |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
