# Distribution workstream: iOS App Store / TestFlight from Linux only

Accessed: 2026-10-05 (all sources below, unless stated otherwise).
Labels: **[V]** = VERIFIED-FROM-SOURCE, **[I]** = INFERRED, **[U]** = UNKNOWN.
Project constraints: no macOS anywhere (no machine, VM, remote Mac, or Mac CI). No falsified SDK or Xcode metadata. No credentials used.

---

## 0. Bottom line (TL;DR)

1. **[V]** Using Apple's iOS SDK (headers, `.tbd` stubs, frameworks) on Linux breaches the *Xcode and Apple SDKs Agreement* (EA2002, dated 06/08/2026) and the *Apple Developer Program License Agreement* (PLA). Both limit use of the SDK to Apple-branded computers.
2. **[V]** Since 2026-04-28, App Store Connect requires uploads to be "built with Xcode 26 or later" using the iOS 26 SDK. Apple has announced the iOS 27 SDK as the minimum from April 2027. A build that uses neither Xcode nor Apple's SDK cannot meet this requirement honestly.
3. **[I]** Taken together, items 1 and 2 mean no build that is both all-Linux and fully compliant exists today. Every technical path conflicts either with the license (using the SDK on Linux) or with the upload requirement (not using Xcode). The only clean exit is written permission from Apple, which the license wording allows for ("unless otherwise permitted by Apple in writing").
4. **[V]** The upload step itself can be done from Linux using Apple's own channels: the GA App Store Connect *Build Uploads* API (v4.1), and iTMSTransporter for RHEL on x86_64. One gap remains: Transporter on Linux needs `AppStoreInfo.plist`, which "is exported from Xcode".
5. **[V]/[I]** These tools exist and are active: LLVM lld (Mach-O, arm64, chained fixups, ad-hoc signing), rcodesign and zsign (distribution signing), and clean-room `Assets.car` writers. Technical feasibility is plausible. Compliance is the blocker.

---

## 1. SDK provenance and permitted use

### 1.1 Xcode and Apple SDKs Agreement
Source: https://www.apple.com/legal/sla/docs/xcode.pdf. The PDF footer reads "EA2002 06/08/2026". The text was extracted locally with `pdftotext`.

| Clause | Exact short quote | Label |
|---|---|---|
| Preamble | "AUTHORIZED ONLY FOR EXECUTION ON AN APPLE-BRANDED PRODUCT RUNNING MACOS." | [V] |
| §1 "Apple Software" | The term covers "the Xcode Developer Tools and the Apple SDKs" | [V] |
| §2.2.A (grant) | "Install a reasonable number of copies of the Apple Software on Apple-branded computers" | [V] |
| §2.2.A(iii) | SDKs may be used only for apps "specifically for use with the applicable Apple-branded products" | [V] |
| §2.5 Copies | "expressly prohibited from separately using the Apple SDKs" | [V] |
| §2.5 Copies | "attempting to run any part of the Apple Software on non-Apple-branded hardware" | [V] |
| §2.7 Restrictions | The licensee agrees not to "install, use or run the Apple Software ... on any non-Apple-branded computer or device" | [V] |
| §2.7 Restrictions | Also prohibits copying, modifying or creating "derivative works of the Apple Software" | [V] |

### 1.2 Apple Developer Program License Agreement (PLA)
Source: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/. Schedule 1 was "last updated August 18, 2026".

| Clause | Exact short quote | Label |
|---|---|---|
| Def. "Apple SDKs" | The definition includes "header files, APIs, libraries, simulators, and software" | [V] |
| Restrictions (s.2) | "not to install, use or run the Apple SDKs on any non-Apple-branded computer" | [V] |
| 3.3.1.A | "Applications may only use Documented APIs in the manner prescribed by Apple" | [V] |
| 6.1 Submission | The developer warrants the app "complies with the Documentation and Program Requirements then in effect" | [V] |
| 6.1 Submission | "will not attempt to hide, misrepresent or obscure any features" | [V] |

### 1.3 Assessment
- **[I] Extracting the iOS SDK from `Xcode.xip` and using it on Linux is non-compliant.** This is how xtool sets up its SDK: "xtool will extract the Xcode XIP to generate and install an iOS Swift SDK" (https://raw.githubusercontent.com/xtool-org/xtool/main/Documentation/xtool.docc/Installation-Linux.md). It conflicts with Xcode SLA §2.5 and §2.7 and with the PLA restriction above. Running Xcode tools under Darling or a VM on non-Apple hardware hits the same clauses.
- **[I] Self-authored headers and `.tbd` stubs (no Apple SDK files).** Possible routes include writing your own `.tbd` files (LLVM TextAPI format), writing your own ObjC/C declarations, or using Apple's open-source (APSL) Darwin headers.
  - *License side:* files you write yourself are not "Apple Software", so SLA §2.5/§2.7 do not apply directly. Two points are unclear: whether declarations reproduced from Apple's headers count as derivative works (**[U]**, needs legal advice), and that PLA 3.3.1 still requires Documented APIs only.
  - *Upload side:* such a build is still not "built with Xcode 26 ... using an SDK for iOS 26" (see §2). Its true DT* values would not match what Apple expects. Writing Xcode or SDK values into it would be falsification and a PLA 6.1 misrepresentation risk. **Excluded by project rules.**
- **[I] Legitimate alternatives, with implications:**
  - (a) Ask Apple for written permission. Both §2.2.A(iii) and §2.7 allow for "permitted by Apple in writing". There is no known public program for this (**[U]**).
  - (b) Use Xcode Cloud, Apple's hosted CI. It is operated by Apple, but it is "Mac CI" in substance, so the project's no-Mac rule excludes it. It is noted here only because forum users cite it as the fix for ITMS-90111.
  - (c) Accept a non-App-Store target. Examples are a device-only development install, or EU alternative distribution. Note that the PLA restriction on SDK use still applies to (c).

---

## 2. App Store minimum SDK/Xcode requirements and how Apple checks them

### 2.1 Requirements
- **[V]** "Since April 28, 2026: apps uploaded to App Store Connect must be built with Xcode 26 or later using an SDK for iOS 26 ..." Source: https://developer.apple.com/news/upcoming-requirements/
- **[V]** "Since September 9, 2026: iOS and iPadOS apps uploaded to App Store Connect must target iOS 13 or later." Same page.
- **[V]** Announced 2026-02-03 at https://developer.apple.com/news/?id=ueeok6yw. iOS apps "must be built with the iOS 26 & iPadOS 26 SDK or later".
- **[V]** Next requirement: from April 2027, the iOS 27 & iPadOS 27 SDK or later. Uploads built with Xcode 27 RC have been accepted since 2026-09-09. Source: https://developer.apple.com/news/?id=k1mtkt1k
- **[V]** The App Store Connect Help "Upload builds" table lists "Built with Xcode: Xcode 26+" for iOS apps. Upload methods: Xcode, Transporter, altool, App Store Connect API. Source: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- **[V]** Xcode 27 requires "macOS Tahoe 26.6 or later". Its iOS min deployment target is iOS 17+. Xcode 26.x supports iOS 15+. Source: https://developer.apple.com/xcode/system-requirements/
- **[V]** The `builds` resource says: "You must upload builds using Xcode, Transporter, or the build-uploads resource." Source: https://developer.apple.com/documentation/appstoreconnectapi/builds (read via the docs JSON endpoint `/tutorials/data/documentation/appstoreconnectapi/builds.json`).

### 2.2 Verification signals
- **[U]** Apple does not publicly document how ingestion validates the toolchain. No Apple reference page for the `DTXcode`/`DTXcodeBuild`/`DTSDKName`/`DTPlatformBuild`/`DTPlatformVersion`/`DTCompiler`/`BuildMachineOSBuild` keys turned up in searches.
- **[I]** Third-party descriptions say Xcode inserts these keys. Examples: DTXcode = Xcode version, DTSDKName = SDK name, BuildMachineOSBuild = macOS build of the build host (https://www.en.techgaku.com/check-build-environment-from-infoplist). Chromium's gyp emulates them for non-Xcode builds (https://chromium.googlesource.com/external/gyp/+/b25bbc1f942d75783bf4c236219035beff46453d%5E!/).
- **[I]** Developer forums report that a beta macOS build host, i.e. `BuildMachineOSBuild`, triggers ITMS-90111. This implies ingestion checks the build host OS (https://developer.apple.com/forums/thread/757182; the original blog cwfrazier.com returned HTTP 500 → that source is **[U]**).
- **[V]** In Mach-O, `LC_BUILD_VERSION` carries `minos` and `sdk`. lld sets them from the linker flag `-platform_version <platform> <min_version> <sdk_version>`, so the SDK value is whatever the build passes (lld `Options.td`, https://raw.githubusercontent.com/llvm/llvm-project/main/lld/MachO/Options.td). **[I]** This is the field whose value would have to be invented without a real SDK. Writing "26.x" without actually using that SDK is falsification and excluded.

### 2.3 Upload validation errors (ITMS)
These are from developer reports. Apple has no central public catalog.

| Code | Reported text / meaning | Source | Label |
|---|---|---|---|
| ITMS-90725 | "SDK Version Issue": app built with an SDK older than the minimum | https://developer.apple.com/forums/thread/750346 ; https://github.com/expo/expo/issues/16784 | [I] |
| ITMS-90111 | "Unsupported SDK or Xcode version"; also seen for beta macOS build host | https://developer.apple.com/forums/thread/757182 ; https://x.com/alpennec/status/2064328681632276566 | [I] |
| ITMS-90534 | "Invalid Toolchain ... must be built with the public (GM) versions of Xcode" | https://github.com/fastlane/fastlane/issues/5583 | [I] |
| ITMS-90713 | Missing `CFBundleIconName`; icons must be in an asset catalog (iOS 11+ SDK) | https://github.com/fyne-io/fyne/issues/1504 | [I] |
| ITMS-90704 | Missing 1024x1024 PNG icon "in the Asset Catalog" | https://forum.ionicframework.com/t/error-itms-90704-missing-app-icon-an-app-icon-measuring-1024-by-1024-pixels-in-png-format-must-be-included-in-the-asset-catalog/180083 | [I] |
| ITMS-90475 | iPad multitasking requires a launch storyboard | https://developer.apple.com/forums/thread/20405 | [I] |
| ITMS-90426 | "Invalid Swift Support – SwiftSupport folder is missing" | https://developer.apple.com/forums/thread/717339 | [I] |
| ITMS-90035 | "Invalid Signature"; must use a distribution certificate | https://developer.apple.com/forums/thread/118659 | [I] |

### 2.4 The tension (stated plainly)
- **[I]** Building on Linux with the real iOS 26 SDK gives honest `sdk 26.x` values in `LC_BUILD_VERSION`, but it breaches the SLA and PLA (§1). It would also still have no genuine `DTXcode`/`DTXcodeBuild`/`BuildMachineOSBuild` values: no Xcode ran, and no macOS existed.
- **[I]** Building without the SDK is license-clean with respect to Apple Software. However, it does not meet "built with Xcode 26", and its true metadata would show that.
- **[I]** The only ways to make either path pass are to omit the DT keys or to forge them. Omitting them leads to rejection (**[U]**: the outcome is undocumented). Forging them is prohibited here.
- **No honest way to meet the Xcode-built requirement without Xcode has been found. [I]**

---

## 3. Device build: clang + ld64.lld on Linux

- **[V]** The lld Mach-O port is described as "a drop-in replacement for Apple's Mach-O linker, ld64" (https://lld.llvm.org/MachO/index.html). The latest LLVM release is llvmorg-23.1.2, published 2026-09-22 (GitHub API).
- **[V]** Chained fixups are emitted by default for arm64 when PIE is on and the deployment target is at least iOS 13.4. The table `{PLATFORM_IOS, VersionTuple(13, 4)}` is in `shouldEmitChainedFixups` (https://raw.githubusercontent.com/llvm/llvm-project/main/lld/MachO/Driver.cpp, last commit 2026-09-17). They can be forced with `-fixup_chains` and disabled with `-no_fixup_chains`.
- **[V]** `-adhoc_codesign`: "Write an ad-hoc code signature ... (default for arm64 binaries)" (Options.td). The ad-hoc `LC_CODE_SIGNATURE` must be replaced by a distribution signature (§5).
- **[V]** Bitcode is not needed. lld marks `-bitcode_bundle` "Obsolete since the App Store no longer supports binaries with embedded bitcode" (Options.td). The Xcode 14 release notes say the App Store "no longer accepts bitcode submissions from Xcode 14" (https://developer.apple.com/documentation/xcode-release-notes/xcode-14-release-notes).
- **[V]** Minimum deployment target for upload is iOS 13 or later (§2.1). **[I]** A practical floor is iOS 13.4+ (chained fixups default) or iOS 15+ (Xcode 26 floor), to match Xcode-produced binaries.
- **[I]** clang `-target arm64-apple-ios15.0` with lld can produce a valid arm64 Mach-O executable. Linking still needs `.tbd` stubs for UIKit/Foundation/libSystem. These come either from the Apple SDK (license issue, §1) or from self-written stubs (upload-requirement issue, §2).
- **[I]** Swift: since the iOS 12.2 ABI stability, the Swift runtime ships in the OS. With iOS ≥13 targets, `SwiftSupport/` is normally not needed unless Swift dylibs are embedded. A C/ObjC-only app avoids the issue.

---

## 4. Bundle structure and resources

- **[V]** Required/likely Info.plist keys:
  - `CFBundleIdentifier`, `CFBundleExecutable`, `CFBundleShortVersionString`, `CFBundleVersion`. The last two are also required attributes of the Build Upload API create request (§7).
  - `CFBundleIconName` ("The name of the asset that represents the app icon", https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconname).
  - `UILaunchScreen` or `UILaunchStoryboardName`.
  - `ITSAppUsesNonExemptEncryption` (recommended, §7.4).
  - **[I]** Also commonly needed: `CFBundlePackageType=APPL`, `LSRequiresIPhoneOS`, `UIDeviceFamily`, `MinimumOSVersion`, `UIRequiredDeviceCapabilities` (arm64), `UISupportedInterfaceOrientations`. Xcode also adds the DT* keys (see §2.2).
- **App icons**
  - **[V]** Apple documents icons via an asset catalog. A single 1024x1024 image is enough for iOS (https://developer.apple.com/documentation/xcode/configuring-your-app-icon).
  - **[I]** From ITMS-90713 and ITMS-90704: loose PNG files listed under `CFBundleIcons` are not enough for App Store upload. A compiled `Assets.car` holding the 1024 icon, plus `CFBundleIconName`, is expected.
  - **[V]** Linux options that exist:
    - viraptor/actool, "Cleanroom actool reimplementation" (https://github.com/viraptor/actool, last push 2026-06-03).
    - albertogferrario/ios-car-writer, a Linux-native reader/writer forked from BSD-licensed xcbuild libcar/libbom (https://github.com/albertogferrario/ios-car-writer).
    - joshuaswarren/AssetKit (https://github.com/joshuaswarren/AssetKit; 0 stars, very new).
    - facebookarchive/xcbuild (archived).
  - **[U]** No evidence was found that any of these `Assets.car` writers gets through App Store ingestion.
- **Launch screen**
  - **[V]** "Every iOS app must provide a launch screen." It can be an Info.plist `UILaunchScreen` dictionary, which is "configure the user interface during app launch in a way that doesn't rely on storyboards", or a storyboard (https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen ; https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen).
  - **[I]** `UILaunchScreen` removes the need for `ibtool` or compiled storyboards. Making the app iPhone-only, or setting `UIRequiresFullScreen`, avoids ITMS-90475.
  - **[I]** The UI can be built in code (UIKit programmatic), so no `.storyboardc` is needed.
- **Privacy manifest**
  - **[V]** The file is `PrivacyInfo.xcprivacy`, a plist with `NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes` and `NSPrivacyAccessedAPITypes`. The required reasons APIs must be declared on iOS (https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).
  - **[I]** It is a plain plist that can be written by hand. For a minimal app it is needed only if required-reason APIs are used (e.g. `NSUserDefaults`, file timestamps).
- **Provisioning profile placement**
  - **[V]** iOS expects the profile at `MyApp.app/embedded.mobileprovision`. A profile is "a property list wrapped within a Cryptographic Message Syntax (CMS) signature" (TN3125, https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles).

---

## 5. Signing on Linux

| Tool | Status | Distribution signing / entitlements / profile / CodeResources | Label |
|---|---|---|---|
| rcodesign (indygreg/apple-platform-rs, `apple-codesign`) | Last release 0.29.0 (2024-11-29). Repo pushed 2026-09-19. Pure Rust, runs on Linux | Signs Mach-O and bundles, including shallow (iOS) bundles (`settings.shallow()` in `bundle_signing.rs`). Entitlements via `--entitlements-xml-file`. Builds `_CodeSignature/CodeResources`. Certificates via `--p12-file`, `--pem-file` or smartcard. **No dedicated provisioning-profile option was found** (grep of `src/cli/mod.rs`). **[I]** You copy `embedded.mobileprovision` into the bundle before signing, so it gets sealed as a resource | [V] / [I] |
| zsign (zhlynn) | v1.1.2 (2026-08-21). Runs on macOS, Linux, Windows | `-k` p12/pem, `-m` profile (one per extension), `-e` entitlements, `-a` ad-hoc, `-2` SHA256-only. Outputs `.ipa`. Aimed at re-signing | [V] |
| ldid (ProcursusTeam) | v2.1.5-procursus7 (2023-01-18) | `-S` entitlements (pseudo-sign), `-K` identity file. Mostly used for jailbreak and ad-hoc signing. **[U]** App Store suitability unknown | [V] / [U] |
| isign (sauce-archives) | Archived. Last push 2020-01-31 | Obsolete | [V] |

Sources: https://gregoryszorc.com/docs/apple-codesign/main/apple_codesign_quirks.html (warns "Bundle signing is susceptible to a lot of subtle bugs and variation from how Apple's tooling does it"); https://raw.githubusercontent.com/indygreg/apple-platform-rs/main/apple-codesign/src/cli/mod.rs ; https://raw.githubusercontent.com/zhlynn/zsign/master/README.md ; https://raw.githubusercontent.com/ProcursusTeam/ldid/master/docs/ldid.1 ; GitHub releases API.

**Certificates and profiles without a Mac**
- **[V]** CSR: rcodesign has `generate-certificate-signing-request`. Its docs describe a manual upload in the developer portal (https://gregoryszorc.com/docs/apple-codesign/main/apple_codesign_certificate_management.html). `openssl req` works too **[I]**.
- **[V]** The App Store Connect API automates the same steps:
  - `POST /v1/certificates`, with required `certificateType` and `csrContent`. Types include `IOS_DISTRIBUTION` and `DISTRIBUTION`.
  - `POST /v1/bundleIds`.
  - `POST /v1/profiles`, with required `name` and `profileType`, e.g. `IOS_APP_STORE` (https://developer.apple.com/documentation/appstoreconnectapi/post-v1-certificates ; .../post-v1-profiles ; .../post-v1-bundleids).
- **[I]** CMS signing and code-directory hashing are SHA-256 (TN3126, https://developer.apple.com/documentation/technotes/tn3126-inside-code-signing-hashes). Entitlements must exactly match the profile, e.g. `application-identifier`, `com.apple.developer.team-identifier`, `beta-reports-active`. A mismatch gives ITMS-90035/90046 (**[I]**, from forum reports).
- **[U]** No public evidence was found of an IPA signed by rcodesign or zsign passing App Store ingestion. Many zsign users re-sign IPAs for sideloading, which is a different use case.

---

## 6. IPA export structure

- **[I]** Layout: a ZIP containing `Payload/<Name>.app/`. Optional extras are `SwiftSupport/iphoneos/*.dylib` (only if Swift runtime dylibs are embedded) and `Symbols/` (symbol upload). The standard ZIP "deflate" format is widely reported to work. Preserve executable bits and symlinks (for frameworks). Exclude `__MACOSX` and `.DS_Store`.
- **[U]** Apple does not publish a formal IPA spec. Upload UTI `com.apple.ipa` is accepted by the Build Upload API (§7).
- **[V]** The Xcode "Archive export files" help describes `AppStoreInfo.plist` as "A file that you pass to iTMSTransporter ...". Other export files: `ExportOptions.plist`, `DistributionSummary.plist`, `Packaging.log` (https://help.apple.com/xcode/mac/current/en.lproj/deva1f2ab5a2.html).
- **[I]** `AppStoreInfo.plist` is produced by `xcodebuild -exportArchive` when `generateAppStoreInformation=YES`, or by `xcrun swinfo`. Both are macOS-only (https://github.com/fastlane/fastlane/issues/16131). Its format is undocumented (**[U]**).

---

## 7. Upload from Linux

### 7.1 App Store Connect Build Uploads API
Docs were read via `https://developer.apple.com/tutorials/data/documentation/appstoreconnectapi/<page>.json`. The HTML pages are JS-rendered.
- **[V] GA status:** pages list `"beta": false, "introducedAt": "4.1"`. The 4.1 release notes say: "You can now use build-uploads to upload and manage build uploads for your apps." (https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-1-release-notes)
- **[V] Flow:**
  1. `POST /v1/buildUploads` (https://developer.apple.com/documentation/appstoreconnectapi/post-v1-builduploads). Body type is `buildUploads`. Required attributes: `cfBundleShortVersionString`, `cfBundleVersion`, `platform`. Required relationship: `app`. Responses: 201, 401, 403, 409, 422, 429.
  2. `POST /v1/buildUploadFiles`, the reservation (.../post-v1-builduploadfiles).
     - Required: `assetType` (one of `ASSET` | `ASSET_DESCRIPTION` | `ASSET_SPI`), `fileName`, `fileSize`, and `uti` (one of `com.apple.ipa` | `com.apple.pkg` | `com.apple.binary-property-list` | `com.apple.xml-property-list` | `com.pkware.zip-archive`).
     - Required relationship: `buildUpload`.
     - The response carries `uploadOperations[]`, each with `method`, `url`, `requestHeaders`, `offset`, `length`, `partNumber` and `expiration` (DeliveryFileUploadOperation).
  3. PUT each part to its operation URL. Per the generic asset-upload guide, the URLs "are unauthenticated and time-limited". Parts may go in parallel (https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect).
  4. `PATCH /v1/buildUploadFiles/{id}` with `uploaded: true` and `sourceFileChecksums` (.../patch-v1-builduploadfiles-_id_).
  5. Poll `GET /v1/buildUploads/{id}`. The `state` object holds `state` (`AWAITING_UPLOAD` | `PROCESSING` | `FAILED` | `COMPLETE`) plus `errors[]`, `warnings[]` and `infos[]`, each with `code` and `description`. Alternatively use the `BUILD_UPLOAD_STATE_UPDATED` webhook (https://developer.apple.com/documentation/appstoreconnectapi/build-uploads).
  6. The `BuildUpload` relationships include `build`. Then poll the `builds` resource: `processingState` is `PROCESSING` | `FAILED` | `INVALID` | `VALID`.
- **[U]** It is unclear whether an `ASSET_DESCRIPTION` file (likely the `AppStoreInfo.plist` equivalent) is required for an IPA via this API. The enum exists and per-field descriptions are empty. This is a key open question: Transporter needs that file on Linux (§7.2), and it is generated only by Xcode tooling.
- **[V] Auth:** JWT signed with "ES256". Header `kid`. Payload `iss` (issuer ID), `iat`, `exp` (≤20 min for most resources), `aud: appstoreconnect-v1`. Individual keys use `sub` instead of `iss` (https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests). The API itself is plain HTTPS/JSON and runs fine on Linux.

### 7.2 Transporter / iTMSTransporter
- **[V]** Transporter User Guide 4.2 lists supported OSes as macOS 10.11+, Windows 11+, and "Red Hat Enterprise Linux (64-bit system)". The Linux installer is `iTMSTransporter_installer_linux_4.2.0.<build>.sh`. Auth is via `-apiKey`/`-apiIssuer` or `-jwt` (https://help.apple.com/itc/transporteruserguide/en.lproj/static.html).
- **[V]** `-assetDescription` "Specifies the plist file that is exported from Xcode. This option is required for Linux and Windows App uploads". `-assetFile` takes `.ipa`/`.pkg`. Same guide.
- **[I]** It works on x86_64 only. A forum report shows aarch64 failing on `...-x86_64-unknown-linux-musl` requirements (https://developer.apple.com/forums/thread/763445).
- **[V]** fastlane `upload_to_testflight` has an "Upload from Linux" section that requires the package and `AppStoreInfo.plist` side by side (https://docs.fastlane.tools/actions/upload_to_testflight/).
- **[V]** `altool` is invoked via `xcrun`, so it is part of Xcode and macOS-only (App Store Connect Help, upload-builds page). rcodesign uses the App Store Connect API only for **notarization** (macOS). It has no App Store upload command (`src/cli/mod.rs`).
- **[U]** xtool documents no App Store Connect upload command. Its CLI lists `ds` (Developer Services), `install`, etc. (https://github.com/xtool-org/xtool).

### 7.3 Processing and TestFlight internal testing via API
- **[V]** Builds: `GET /v1/builds?filter[app]=...`, with attribute `processingState` (above). `usesNonExemptEncryption` can be set with `PATCH /v1/builds/{id}` (BuildUpdateRequest attributes: `expired`, `usesNonExemptEncryption`).
- **[V]** Beta groups:
  - `POST /v1/betaGroups`, with attributes `name` and `isInternalGroup`, among others.
  - Add a build with `POST /v1/betaGroups/{id}/relationships/builds` or `POST /v1/builds/{id}/relationships/betaGroups`.
  - Internal testers are App Store Connect users, up to 100. Builds are testable for 90 days (https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).
- **[I]** Internal testing does not need Beta App Review. Apple's page did not mention it as a requirement.

### 7.4 Export compliance
- **[V]** Set `ITSAppUsesNonExemptEncryption` = `NO` when the app uses no encryption, or only exempt encryption. Without the key, App Store Connect "walks you through an export compliance questionnaire every time you upload" (https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

---

## 8. Blockers ranked by severity

| # | Blocker | Severity | Label |
|---|---|---|---|
| 1 | **License:** iOS SDK (headers/.tbd/frameworks) may not be used on non-Apple hardware (SLA preamble, §2.5, §2.7; PLA). Any all-Linux build using Apple's SDK is non-compliant | Critical (legal) | [V] |
| 2 | **Upload policy:** "built with Xcode 26 or later" (iOS 27 SDK from April 2027). There is no honest way to meet this without Xcode, and forging DT*/`LC_BUILD_VERSION` is excluded | Critical (policy) | [V] / [I] |
| 3 | **Ingestion validation of toolchain metadata** is undocumented (DT keys, `BuildMachineOSBuild`). An honest non-Xcode binary will likely be rejected (ITMS-90111/90534/90725 class) | High | [I] / [U] |
| 4 | **`AppStoreInfo.plist`** needed by Transporter on Linux is "exported from Xcode". It is unclear whether the Build Upload API needs an `ASSET_DESCRIPTION` | High | [V] / [U] |
| 5 | **`Assets.car`** from a non-Apple compiler has no proof of passing ITMS-90704/90713 checks | Medium | [U] |
| 6 | **Signing fidelity** of rcodesign/zsign for App Store (no documented acceptance cases). rcodesign has no profile flag, so the profile is embedded manually | Medium | [U] / [V] |
| 7 | iTMSTransporter is x86_64-only on Linux. The Build Upload API avoids this | Low | [I] |
| 8 | lld/clang arm64 iOS linking is technically mature (chained fixups, ad-hoc signing, no bitcode) | Low | [V] |

### Items that need the user's Apple Developer account later
None of these were attempted.
- App Store Connect API key (Issuer ID, Key ID, `.p8`). Needed for all API calls. Uploading builds requires the Account Holder, Admin, App Manager, or Developer role [V, upload-builds help page].
- Registering a Bundle ID; creating the App Store Connect app record (the Build Upload API needs the `app` relationship).
- An iOS Distribution certificate from a CSR (`POST /v1/certificates`) and an `IOS_APP_STORE` profile (`POST /v1/profiles`).
- Creating an internal beta group and adding testers. TestFlight app on the iPhone, logged in as an App Store Connect user.
- Export compliance answer or Info.plist key; privacy and app metadata; age-rating questionnaire (per the upcoming-requirements page).
- **Optionally:** a written request to Apple asking whether any non-macOS build route is permitted (§1.3a). This is the only path that could resolve blockers 1–2 legitimately.
