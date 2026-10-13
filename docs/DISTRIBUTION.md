# App Store distribution from Linux

Why isim stops before upload, how to ship anyway (Xcode on a macOS CI runner), and what an all-Linux route would
need. Researched 2026-10-05; the full notes, with
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
- **What to do instead:** develop and test on Linux with isim, then let a macOS CI runner build, sign and upload the
  same Xcode project with Xcode ([below](#shipping-today-xcode-on-a-macos-ci-runner)).

## Shipping today: Xcode on a macOS CI runner

isim builds the same `.xcodeproj` / `.xcworkspace` that Xcode does, so the project you write and test on Linux can be
released unchanged by Xcode on Apple hardware. A hosted macOS runner (GitHub Actions `macos-*`) is a Mac running
Xcode and Apple's SDK, so the upload is a genuine Xcode build: nothing is faked, and no Mac of your own is needed.

[kolabs-dev/mobile-actions](https://github.com/kolabs-dev/mobile-actions) packages those steps as GitHub Actions:

- `ios-upload` archives the app with `xcodebuild`, signs it with your distribution certificate and provisioning
  profile, exports the `.ipa` and uploads it to TestFlight (or App Store Connect);
- `ios-promote` submits an uploaded build for App Store review.

```yaml
# .github/workflows/ios-release.yml
name: iOS Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: macos-26                       # a runner with Xcode 26 or later installed
    steps:
      - uses: actions/checkout@v4
      - uses: kolabs-dev/mobile-actions/ios-upload@v1
        with:
          project: MyApp.xcodeproj          # or workspace: MyApp.xcworkspace; auto-detected if omitted
          scheme: MyApp
          bundle-id: com.example.myapp
          team-id: ${{ secrets.APPLE_TEAM_ID }}
          certificate: ${{ secrets.IOS_CERTIFICATE_BASE64 }}
          certificate-password: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
          provisioning-profile: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
          app-store-connect-key: ${{ secrets.APP_STORE_CONNECT_KEY_BASE64 }}
          app-store-connect-key-id: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
          app-store-connect-issuer-id: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          destination: testflight
```

Notes:

- The action uses the runner's default Xcode (or `xcode-version`, when set) and stops early if it is older than Apple's
  current [upload requirements](https://developer.apple.com/news/upcoming-requirements/) allow, so pick a `runs-on`
  image that has a current Xcode.
- Keys and certificates go into GitHub Actions secrets, never into the repository. mobile-actions'
  [iOS setup guide](https://github.com/kolabs-dev/mobile-actions/blob/main/docs/setup/ios-upload.md) walks through
  the certificate, the provisioning profile and the App Store Connect API key.
- isim's simulator and Apple's are different implementations: try the TestFlight build on a device (or Apple's
  simulator) before submitting it for review.

## What is technically possible

| Step | State |
|---|---|
| arm64 device executables (clang + ld64.lld) | arm64 Mach-O without frameworks links; apps cannot (isim's frameworks are x86_64 simulator code, and Apple's device frameworks are off limits) |
| `.app` bundle, `Assets.car`, entitlements | not done; clean-room `Assets.car` writers exist but have no proof of passing App Store checks |
| Distribution signing | not done; candidates rcodesign, zsign (no documented App Store acceptance) |
| `.ipa` | not done (a zip with `Payload/App.app`) |
| Upload | App Store Connect *Build Uploads* API or iTMSTransporter for Linux; Transporter needs `AppStoreInfo.plist`, which "is exported from Xcode" |

## What an upload would need from the developer

An App Store Connect API key, a registered bundle ID and app record, an iOS Distribution certificate and an App Store
provisioning profile, a TestFlight beta group, and the app's compliance/privacy/age-rating answers. Keys and
certificates stay on the developer's machine, never in the repository.
