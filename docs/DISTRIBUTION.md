# App Store distribution from Linux

Why isim stops before upload, and what the remaining steps would need. Researched 2026-10-05; the full notes, with
quotes and every source, are in git history (`docs/distribution-research.md`, removed after v0.9.0).

## Bottom line

- **License.** The *Xcode and Apple SDKs Agreement* ([EA2002](https://www.apple.com/legal/sla/docs/xcode.pdf)) and
  the *Apple Developer Program License Agreement* allow Apple's SDK only on Apple-branded computers. isim therefore
  ships its own SDK and never uses Apple's headers, `.tbd` stubs or frameworks.
- **Upload policy.** App Store Connect requires iOS apps "built with Xcode 26 or later" using the iOS 26 SDK (the iOS
  27 SDK from April 2027; [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)). A build
  made without Xcode and Apple's SDK cannot honestly claim that, and isim never fakes `DT*` / `LC_BUILD_VERSION`
  metadata.
- **So** no all-Linux build that is both compliant and uploadable exists today. The only clean route would be
  written permission from Apple ("unless otherwise permitted by Apple in writing").

## What is technically possible

| Step | State |
|---|---|
| arm64 device executables (clang + ld64.lld) | works in isim |
| `.app` bundle, `Assets.car`, entitlements | not done; clean-room `Assets.car` writers exist but have no proof of passing App Store checks |
| Distribution signing | not done; candidates rcodesign, zsign (no documented App Store acceptance) |
| `.ipa` | not done (a zip with `Payload/App.app`) |
| Upload | App Store Connect *Build Uploads* API or iTMSTransporter for Linux; Transporter needs `AppStoreInfo.plist`, which "is exported from Xcode" |

## What an upload would need from the developer

An App Store Connect API key, a registered bundle ID and app record, an iOS Distribution certificate and an App Store
provisioning profile, a TestFlight beta group, and the app's compliance/privacy/age-rating answers. Keys and
certificates stay on the developer's machine, never in the repository.
