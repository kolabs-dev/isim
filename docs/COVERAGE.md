# isim API coverage

How much of the iOS SDK isim implements, for iOS 17, 18, 26 and 27 (selected with `--os`). The goal is all of it: any
iOS app should build and run on isim. This page is the index. Each framework isim implements has its own page in
[frameworks/](frameworks/), with how isim implements it, a row per API with its status, and the list of Apple symbols
it still lacks.

**What the numbers mean**

- **Symbols** (isim's API coverage, and the number to track progress by): the share of the symbols Apple documents
  for iOS (types, functions, constants, members) that isim's SDK has.
  - Measured by [`isim/tools/api-coverage.py`](../isim/tools/api-coverage.py) against a snapshot of Apple's
    documentation ([API-SWEEP.md](API-SWEEP.md)).
  - *Exact* compares the symbol graphs of isim's built SDK with Apple's documentation paths. *By name* (marked \*)
    only checks that the name occurs in isim's sources, so it is a lower bound on what is missing.
  - A symbol that exists can still do nothing; the rows say how well it works.
- **Rows** (how each API is implemented, not a coverage number): hand-written rows on the framework pages, one per API
  or feature, with its status (✅ 🟡 🧩 ❌ ⛔), the iOS version, a passthrough / adapted / stub label and the test that
  verifies it. Keep them up to date when an API changes. The tables count rows per status; they are not turned into a
  percentage, because a page only has rows for what someone wrote down.
- **Frameworks in isim:** frameworks isim ships, out of the frameworks Apple documents for iOS that are in scope.

**Legend**

| Mark | Meaning |
|---|---|
| ✅ | Implemented: works like iOS for normal use |
| 🟡 | Partial: exists but simplified or missing notable behaviour (the note says what) |
| 🧩 | Stub: the API exists so apps compile and run, but it does nothing real |
| ❌ | Missing: not in isim yet (code using it does not compile, or aborts at run time) |
| ⛔ | Blocked: needs something isim cannot have (Apple's keys, servers, licensed models or undocumented formats); the note says what |

- **"Unverified"** in a note means the code exists but no isim test exercises that behaviour.
- **Implementation labels:** notes label behaviour as **passthrough** (the host's function with the same ABI),
  **adapted** (isim's translation of Apple's behaviour) or **stub**. `isim-runtime --print-exports <lib>` shows the
  label of every host-provided symbol.
- **The iOS column** is the version that introduced the API (`≤17`: iOS 17 or earlier). The per-version summary counts
  a row toward iOS N when it was introduced at or before N.

**Scope**
- Every framework Apple documents for iOS is tracked, unless it is Apple-platform-only and completely impossible to
  replicate on Linux.
- Deprecated APIs are in scope when they are usable in at least one of iOS 17–27, that is when they were deprecated in
  iOS 18 or later. APIs and frameworks deprecated in iOS 17 or earlier are out of scope (listed below). What isim
  already implements of them stays, for ABI stability.

**Editing:** change the rows on the framework pages only. The tables on this page and the generated parts of the
framework pages are rebuilt by `isim/tools/coverage-summary.py` and `isim/tools/api-coverage.py` before each release,
so pull requests don't conflict on them (AGENTS.md, "Coverage").

## Summary

<!-- generated:summary (isim/tools/coverage-summary.py; do not edit by hand) -->
| Area | Symbols | ✅ | 🟡 | 🧩 | ❌ | ⛔ | Frameworks in isim |
|---|---:|---:|---:|---:|---:|---:|---:|
| [UIKit](#uikit) | 90% | 323 | 8 | 0 | 2 | 1 | 2 of 2 |
| [SwiftUI & Charts](#swiftui) | 71% | 313 | 7 | 0 | 5 | 0 | 2 of 2 |
| [Developer tools](#devtools) | 36% | 83 | 11 | 0 | 9 | 0 | 5 of 6 |
| [Foundation & CoreFoundation](#foundation) | 43% | 149 | 19 | 0 | 7 | 0 | 7 of 8 |
| [Swift, Darwin & runtimes](#runtime) | 90% | 117 | 7 | 0 | 7 | 0 | 15 of 16 |
| [Graphics & text](#graphics) | 44% | 122 | 22 | 0 | 13 | 0 | 9 of 12 |
| [GPU](#gpu) | 27% | 41 | 8 | 0 | 6 | 0 | 5 of 7 |
| [Imaging, photos & ML](#ml) | 37% | 88 | 48 | 5 | 23 | 0 | 17 of 30 |
| [Media](#media) | 42% | 145 | 17 | 0 | 23 | 0 | 15 of 27 |
| [Games & 3D](#games) | 35% | 138 | 46 | 0 | 6 | 0 | 9 of 13 |
| [Commerce & privacy](#commerce) | 60% | 79 | 7 | 2 | 9 | 0 | 13 of 14 |
| [Data & persistence](#data) | 78% | 41 | 1 | 0 | 4 | 0 | 3 of 3 |
| [Identity & security](#security) | 48% | 50 | 2 | 0 | 9 | 0 | 7 of 14 |
| [App extensions & system integration](#system) | 52% | 127 | 38 | 0 | 12 | 0 | 26 of 54 |
| [Location, personal data & sensors](#location) | 22% | 47 | 16 | 17 | 19 | 0 | 17 of 30 |
| [Web, network & communication](#web) | 30% | 29 | 0 | 6 | 15 | 0 | 10 of 12 |
| [Accessibility & Info.plist](#a11y) | 14% | 15 | 1 | 0 | 6 | 0 | 2 of 2 |
| **All areas** | **48%** | **1907** | **258** | **30** | **175** | **1** | **164 of 252** |

Symbols: 122094 of 253316 Apple iOS symbols in the frameworks isim has or tracks (exact; isim 4afacfcf, Apple snapshot 2026-10-14).
<!-- /generated:summary -->

### Per iOS version

Symbol coverage of what each emulated iOS version has: a symbol counts toward iOS N when Apple introduced it at or before
N (iOS 17 when the snapshot does not say).

<!-- generated:versions (isim/tools/coverage-summary.py; do not edit by hand) -->
| Area | iOS 17 | iOS 18 | iOS 26 | iOS 27 |
|---|---:|---:|---:|---:|
| UIKit | 90% | 90% | 90% | 90% |
| SwiftUI & Charts | 79% | 74% | 72% | 71% |
| Developer tools | 36% | 36% | 36% | 36% |
| Foundation & CoreFoundation | 43% | 42% | 42% | 43% |
| Swift, Darwin & runtimes | 90% | 90% | 90% | 90% |
| Graphics & text | 46% | 47% | 45% | 44% |
| GPU | 31% | 31% | 28% | 27% |
| Imaging, photos & ML | 36% | 37% | 37% | 37% |
| Media | 47% | 46% | 43% | 42% |
| Games & 3D | 47% | 40% | 40% | 35% |
| Commerce & privacy | 66% | 62% | 60% | 60% |
| Data & persistence | 81% | 81% | 80% | 78% |
| Identity & security | 51% | 52% | 48% | 48% |
| App extensions & system integration | 49% | 52% | 51% | 52% |
| Location, personal data & sensors | 21% | 22% | 22% | 22% |
| Web, network & communication | 37% | 34% | 31% | 30% |
| Accessibility & Info.plist | 10% | 12% | 14% | 14% |
| **All areas** | **50%** | **49%** | **49%** | **48%** |
<!-- /generated:versions -->

## Frameworks

Every iOS framework Apple documents, by area. Each area is also an issue label (`area:<name>`). The batches of work
toward 100% are issues labelled `coverage`, each a checklist of APIs.

<!-- generated:index (isim/tools/coverage-summary.py; do not edit by hand) -->

### UIKit

<a id="uikit"></a>Issues: [`area:uikit`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Auikit)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Quick Look](https://developer.apple.com/documentation/quicklook) | 4.0 | ✅ | 86.4% | 8: 6 ✅ 1 ❌ 1 ⛔ | [QuickLook](frameworks/QuickLook.md) |
| [UIKit](https://developer.apple.com/documentation/uikit) | 2.0 | ✅ | 89.9% | 326: 317 ✅ 8 🟡 1 ❌ | [UIKit](frameworks/UIKit.md) |

### SwiftUI & Charts

<a id="swiftui"></a>Issues: [`area:swiftui`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aswiftui)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Swift Charts](https://developer.apple.com/documentation/charts) | 16.0 | ✅ | 81.4% | 21: 20 ✅ 1 ❌ | [Charts](frameworks/Charts.md) |
| [SwiftUI](https://developer.apple.com/documentation/swiftui) | 13.0 | ✅ | 69.7% | 304: 293 ✅ 7 🟡 4 ❌ | [SwiftUI](frameworks/SwiftUI.md) |

### Developer tools

<a id="devtools"></a>Issues: [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [App Intents Testing](https://developer.apple.com/documentation/appintentstesting) | 27.0 | ❌ | 0.0%* | – | – |
| [DeveloperToolsSupport](https://developer.apple.com/documentation/developertoolssupport) | 14.0 | ✅ | 63.5% | 7: 5 ✅ 2 ❌ | [DeveloperToolsSupport](frameworks/DeveloperToolsSupport.md) |
| [Platform](https://developer.apple.com/documentation/platform) | – | ✅ | – | 61: 52 ✅ 5 🟡 4 ❌ | [Platform](frameworks/Platform.md) |
| [StoreKit Test](https://developer.apple.com/documentation/storekittest) | 14.0 | ✅ | 38.1% | 9: 7 ✅ 2 🟡 | [StoreKitTest](frameworks/StoreKitTest.md) |
| [Swift Testing](https://developer.apple.com/documentation/testing) | None | ✅ | 77.8% | 3: 2 ✅ 1 ❌ | [Testing](frameworks/Testing.md) |
| [XCTest](https://developer.apple.com/documentation/xctest) | None | ✅ | 69.9% | 16: 11 ✅ 3 🟡 2 ❌ | [XCTest](frameworks/XCTest.md) |
| [XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation) | None | ✅ | 0.0%* | 7: 6 ✅ 1 🟡 | [XCUIAutomation](frameworks/XCUIAutomation.md) |
| Platform (isim topic) | – | ✅ | – | 61: 52 ✅ 5 🟡 4 ❌ | [Platform](frameworks/Platform.md) |

### Foundation & CoreFoundation

<a id="foundation"></a>Issues: [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Apple Archive](https://developer.apple.com/documentation/applearchive) | 14.0 | ✅ | 77.0% | 10: 8 ✅ 1 🟡 1 ❌ | [AppleArchive](frameworks/AppleArchive.md) |
| [CFNetwork](https://developer.apple.com/documentation/cfnetwork) | 2.0 | ✅ | 18.2% | 3: 1 ✅ 1 🟡 1 ❌ | [CFNetwork](frameworks/CFNetwork.md) |
| [Compression](https://developer.apple.com/documentation/compression) | 9.0 | ✅ | 92.3% | 11: 10 ✅ 1 ❌ | [Compression](frameworks/Compression.md) |
| [Core Foundation](https://developer.apple.com/documentation/corefoundation) | 2.0 | ✅ | 35.6% | 17: 12 ✅ 4 🟡 1 ❌ | [CoreFoundation](frameworks/CoreFoundation.md) |
| [Core Services](https://developer.apple.com/documentation/coreservices) | 12.0 | ❌ | 0.0%* | – | – |
| [Foundation](https://developer.apple.com/documentation/foundation) | 2.0 | ✅ | 48.0% | 120: 107 ✅ 10 🟡 3 ❌ | [Foundation](frameworks/Foundation.md) |
| [System](https://developer.apple.com/documentation/system) | 14.0 | ✅ | 100.0% | 6: 5 ✅ 1 🟡 | [System](frameworks/System.md) |
| [XPC](https://developer.apple.com/documentation/xpc) | 17.4 | ✅ | 97.9% | 8: 6 ✅ 2 🟡 | [XPC](frameworks/XPC.md) |

### Swift, Darwin & runtimes

<a id="runtime"></a>Issues: [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Combine](https://developer.apple.com/documentation/combine) | 13.0 | ✅ | 99.6% | 15: 15 ✅ | [Combine](frameworks/Combine.md) |
| [CrashReportExtension](https://developer.apple.com/documentation/crashreportextension) | 27.0 | ❌ | 0.0%* | – | – |
| [Darwin](https://developer.apple.com/documentation/darwin) | – | ✅ | – | 26: 23 ✅ 3 🟡 | [Darwin](frameworks/Darwin.md) |
| [Darwin Notify](https://developer.apple.com/documentation/darwinnotify) | 9.3 | ✅ | 0.0%* | 5: 3 ✅ 1 🟡 1 ❌ | [DarwinNotify](frameworks/DarwinNotify.md) |
| [Dispatch](https://developer.apple.com/documentation/dispatch) | 8.0 | ✅ | 89.5% | 14: 13 ✅ 1 🟡 | [Dispatch](frameworks/Dispatch.md) |
| [Distributed](https://developer.apple.com/documentation/distributed) | 16.0 | ✅ | 100.0% | – | [Distributed](frameworks/Distributed.md) |
| [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) | 16.0 | ✅ | 84.4% | 2: 1 ✅ 1 ❌ | [JavaScriptCore](frameworks/JavaScriptCore.md) |
| [MetricKit](https://developer.apple.com/documentation/metrickit) | 13.0 | ✅ | 91.2% | 4: 3 ✅ 1 ❌ | [MetricKit](frameworks/MetricKit.md) |
| [Objective-C Runtime](https://developer.apple.com/documentation/objectivec) | 2.0 | ✅ | 69.6% | 22: 20 ✅ 1 🟡 1 ❌ | [ObjectiveC](frameworks/ObjectiveC.md) |
| [Observation](https://developer.apple.com/documentation/observation) | 17.0 | ✅ | 50.0% | 1: 1 ❌ | [Observation](frameworks/Observation.md) |
| [os](https://developer.apple.com/documentation/os) | 8.0 | ✅ | 87.3% | 8: 8 ✅ | [os](frameworks/os.md) |
| [OSLog](https://developer.apple.com/documentation/oslog) | 15.0 | ✅ | 87.8% | – | [OSLog](frameworks/OSLog.md) |
| [RegexBuilder](https://developer.apple.com/documentation/regexbuilder) | 16.0 | ✅ | 99.6% | – | [RegexBuilder](frameworks/RegexBuilder.md) |
| [simd](https://developer.apple.com/documentation/simd) | None | ✅ | 58.9% | 4: 3 ✅ 1 🟡 | [simd](frameworks/simd.md) |
| [StateReporting](https://developer.apple.com/documentation/statereporting) | 27.0 | ✅ | 100.0% | 3: 3 ✅ | [StateReporting](frameworks/StateReporting.md) |
| [Swift](https://developer.apple.com/documentation/swift) | 8.0 | ✅ | 92.1% | 27: 25 ✅ 2 ❌ | [Swift](frameworks/Swift.md) |
| [Synchronization](https://developer.apple.com/documentation/synchronization) | 18.0 | ✅ | 100.0% | – | [Synchronization](frameworks/Synchronization.md) |
| Darwin (isim topic) | – | ✅ | – | 26: 23 ✅ 3 🟡 | [Darwin](frameworks/Darwin.md) |

### Graphics & text

<a id="graphics"></a>Issues: [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [ColorSync](https://developer.apple.com/documentation/colorsync) | 16.0 | ❌ | 0.0%* | – | – |
| [Core Graphics](https://developer.apple.com/documentation/coregraphics) | 2.0 | ✅ | 62.0% | 43: 36 ✅ 3 🟡 4 ❌ | [CoreGraphics](frameworks/CoreGraphics.md) |
| [Core Text](https://developer.apple.com/documentation/coretext) | 3.2 | ✅ | 24.4% | 20: 13 ✅ 6 🟡 1 ❌ | [CoreText](frameworks/CoreText.md) |
| [Core Video](https://developer.apple.com/documentation/corevideo) | 4.0 | ✅ | 11.6% | 9: 6 ✅ 3 ❌ | [CoreVideo](frameworks/CoreVideo.md) |
| [Image I/O](https://developer.apple.com/documentation/imageio) | 4.0 | ✅ | 46.7% | 11: 4 ✅ 6 🟡 1 ❌ | [ImageIO](frameworks/ImageIO.md) |
| [IOSurface](https://developer.apple.com/documentation/iosurface) | 11.0 | ❌ | 0.0%* | – | – |
| [PaperKit](https://developer.apple.com/documentation/paperkit) | 26.0 | ❌ | 0.0%* | – | – |
| [PDFKit](https://developer.apple.com/documentation/pdfkit) | 11.0 | ✅ | 100.0% | 25: 19 ✅ 6 🟡 | [PDFKit](frameworks/PDFKit.md) |
| [PencilKit](https://developer.apple.com/documentation/pencilkit) | 13.0 | ✅ | 95.7% | 13: 11 ✅ 2 ❌ | [PencilKit](frameworks/PencilKit.md) |
| [Core Animation](https://developer.apple.com/documentation/quartzcore) | 2.0 | ✅ | 92.0% | 30: 27 ✅ 1 🟡 2 ❌ | [QuartzCore](frameworks/QuartzCore.md) |
| [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing) | 13.0 | ✅ | 97.2% | 5: 5 ✅ | [QuickLookThumbnailing](frameworks/QuickLookThumbnailing.md) |
| [Symbols](https://developer.apple.com/documentation/symbols) | 17.0 | ✅ | 86.5% | 1: 1 ✅ | [Symbols](frameworks/Symbols.md) |

### GPU

<a id="gpu"></a>Issues: [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Compute Graph](https://developer.apple.com/documentation/computegraph) | 27.0 | ❌ | 0.0%* | – | – |
| [Metal](https://developer.apple.com/documentation/metal) | 8.0 | ✅ | 32.9% | 14: 10 ✅ 4 🟡 | [Metal](frameworks/Metal.md) |
| [MetalFX](https://developer.apple.com/documentation/metalfx) | 16.0 | ✅ | 37.5% | 3: 1 ✅ 1 🟡 1 ❌ | [MetalFX](frameworks/MetalFX.md) |
| [MetalKit](https://developer.apple.com/documentation/metalkit) | 9.0 | ✅ | 57.9% | 4: 2 ✅ 1 🟡 1 ❌ | [MetalKit](frameworks/MetalKit.md) |
| [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders) | 9.0 | ✅ | 24.1% | 18: 14 ✅ 1 🟡 3 ❌ | [MetalPerformanceShaders](frameworks/MetalPerformanceShaders.md) |
| [Metal Performance Shaders Graph](https://developer.apple.com/documentation/metalperformanceshadersgraph) | 14.0 | ✅ | 40.8% | 16: 14 ✅ 1 🟡 1 ❌ | [MetalPerformanceShadersGraph](frameworks/MetalPerformanceShadersGraph.md) |
| [ShaderGraph](https://developer.apple.com/documentation/shadergraph) | 17.0 | ❌ | 0.0%* | – | – |

### Imaging, photos & ML

<a id="ml"></a>Issues: [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Accelerate](https://developer.apple.com/documentation/accelerate) | 4.0 | ✅ | 22.3% | 21: 14 ✅ 4 🟡 3 ❌ | [Accelerate](frameworks/Accelerate.md) |
| [Core AI](https://developer.apple.com/documentation/coreai) | 27.0 | ❌ | 0.0%* | – | – |
| [Core Image](https://developer.apple.com/documentation/coreimage) | 5.0 | ✅ | 97.7% | 17: 11 ✅ 5 🟡 1 🧩 | [CoreImage](frameworks/CoreImage.md) |
| [Core ML](https://developer.apple.com/documentation/coreml) | 11.0 | ✅ | 61.6% | 12: 7 ✅ 3 🟡 2 ❌ | [CoreML](frameworks/CoreML.md) |
| [Core Transferable](https://developer.apple.com/documentation/coretransferable) | 16.0 | ✅ | 68.2% | 6: 3 ✅ 2 🟡 1 ❌ | [CoreTransferable](frameworks/CoreTransferable.md) |
| [Create ML](https://developer.apple.com/documentation/createml) | 15.0 | ❌ | 0.0%* | – | – |
| [Create ML Components](https://developer.apple.com/documentation/createmlcomponents) | 16.0 | ❌ | 0.0%* | – | – |
| [DataDetection](https://developer.apple.com/documentation/datadetection) | 15.0 | ❌ | 0.0%* | – | – |
| [Evaluations](https://developer.apple.com/documentation/evaluations) | 27.0 | ❌ | 0.0%* | – | – |
| [Foundation Models](https://developer.apple.com/documentation/foundationmodels) | 26.0 | ✅ | 40.0% | 12: 8 ✅ 4 🟡 | [FoundationModels](frameworks/FoundationModels.md) |
| [ImageCaptureCore](https://developer.apple.com/documentation/imagecapturecore) | 13.0 | ❌ | 0.0%* | – | – |
| [Image Playground](https://developer.apple.com/documentation/imageplayground) | 18.1 | ✅ | 100.0% | 4: 1 ✅ 3 🧩 | [ImagePlayground](frameworks/ImagePlayground.md) |
| [LockedCameraCapture](https://developer.apple.com/documentation/lockedcameracapture) | 18.0 | ❌ | 0.0%* | – | – |
| [Media Intelligence](https://developer.apple.com/documentation/mediaintelligence) | 27.0 | ❌ | 0.0%* | – | – |
| [ML Compute](https://developer.apple.com/documentation/mlcompute) | 14.0 | ❌ | 0.0%* | – | – |
| [Music Understanding](https://developer.apple.com/documentation/musicunderstanding) | 27.0 | ❌ | 0.0%* | – | – |
| [Natural Language](https://developer.apple.com/documentation/naturallanguage) | 12.0 | ✅ | 95.2% | 6: 1 ✅ 4 🟡 1 ❌ | [NaturalLanguage](frameworks/NaturalLanguage.md) |
| [PhotoKit](https://developer.apple.com/documentation/photokit) | 8.0 | ✅ | 60.1% | 11: 7 ✅ 1 🟡 3 ❌ | [Photos](frameworks/Photos.md) |
| [PhotosUI](https://developer.apple.com/documentation/photokit) | 8.0 | ✅ | 72.7% | 6: 3 ✅ 1 🟡 2 ❌ | [PhotosUI](frameworks/PhotosUI.md) |
| [Sensitive Content Analysis](https://developer.apple.com/documentation/sensitivecontentanalysis) | 17.0 | ❌ | 0.0%* | – | – |
| [Sound Analysis](https://developer.apple.com/documentation/soundanalysis) | 13.0 | ✅ | 100.0% | 6: 4 ✅ 1 🟡 1 ❌ | [SoundAnalysis](frameworks/SoundAnalysis.md) |
| [Spatial](https://developer.apple.com/documentation/spatial) | 16.0 | ✅ | 55.6% | 11: 7 ✅ 4 ❌ | [Spatial](frameworks/Spatial.md) |
| [Speech](https://developer.apple.com/documentation/speech) | 10.0 | ✅ | 94.0% | 9: 4 ✅ 4 🟡 1 ❌ | [Speech](frameworks/Speech.md) |
| [TabularData](https://developer.apple.com/documentation/tabulardata) | 15.0 | ❌ | 0.0%* | – | – |
| [Translation](https://developer.apple.com/documentation/translation) | 17.4 | ✅ | 100.0% | 7: 3 ✅ 4 🟡 | [Translation](frameworks/Translation.md) |
| [TranslationUIProvider](https://developer.apple.com/documentation/translationuiprovider) | 18.4 | ❌ | 0.0%* | – | – |
| [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers) | 14.0 | ✅ | 93.3% | 4: 4 ✅ | [UniformTypeIdentifiers](frameworks/UniformTypeIdentifiers.md) |
| [Vision](https://developer.apple.com/documentation/vision) | None | ✅ | 53.6% | 27: 10 ✅ 12 🟡 1 🧩 4 ❌ | [Vision](frameworks/Vision.md) |
| [VisionKit](https://developer.apple.com/documentation/visionkit) | 13.0 | ✅ | 100.0% | 3: 3 🟡 | [VisionKit](frameworks/VisionKit.md) |
| [Visual Intelligence](https://developer.apple.com/documentation/visualintelligence) | 26.0 | ✅ | 28.6% | 2: 1 ✅ 1 ❌ | [VisualIntelligence](frameworks/VisualIntelligence.md) |

### Media

<a id="media"></a>Issues: [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [AudioAccessoryKit](https://developer.apple.com/documentation/audioaccessorykit) | 26.4 | ❌ | 0.0%* | – | – |
| [Audio Toolbox](https://developer.apple.com/documentation/audiotoolbox) | 2.0 | ✅ | 34.1% | 15: 12 ✅ 1 🟡 2 ❌ | [AudioToolbox](frameworks/AudioToolbox.md) |
| [Audio Unit](https://developer.apple.com/documentation/audiounit) | 2.0 | ✅ | 0.0% | 2: 2 ✅ | [AudioUnit](frameworks/AudioUnit.md) |
| [AVFAudio](https://developer.apple.com/documentation/avfaudio) | 14.5 | ✅ | 73.3% | 15: 13 ✅ 2 ❌ | [AVFAudio](frameworks/AVFAudio.md) |
| [AVFoundation](https://developer.apple.com/documentation/avfoundation) | 2.2 | ✅ | 41.1% | 58: 51 ✅ 2 🟡 5 ❌ | [AVFoundation](frameworks/AVFoundation.md) |
| [AVKit](https://developer.apple.com/documentation/avkit) | 8.0 | ✅ | 41.7% | 9: 5 ✅ 1 🟡 3 ❌ | [AVKit](frameworks/AVKit.md) |
| [AVRouting](https://developer.apple.com/documentation/avrouting) | 16.0 | ❌ | 0.0%* | – | – |
| [AVSystemRouting](https://developer.apple.com/documentation/avsystemrouting) | 27.0 | ❌ | 0.0%* | – | – |
| [Cinematic](https://developer.apple.com/documentation/cinematic) | 17.0 | ❌ | 0.0%* | – | – |
| [Core Audio](https://developer.apple.com/documentation/coreaudio) | 2.0 | ✅ | 12.5% | 2: 2 ✅ | [CoreAudio](frameworks/CoreAudio.md) |
| [CoreAudioKit](https://developer.apple.com/documentation/coreaudiokit) | 8.0 | ❌ | 0.0%* | – | – |
| [Core Audio Types](https://developer.apple.com/documentation/coreaudiotypes) | 13.0 | ✅ | 24.8% | 1: 1 ❌ | [CoreAudioTypes](frameworks/CoreAudioTypes.md) |
| [Core Haptics](https://developer.apple.com/documentation/corehaptics) | 13.0 | ✅ | 67.2% | 6: 5 ✅ 1 🟡 | [CoreHaptics](frameworks/CoreHaptics.md) |
| [Core Media](https://developer.apple.com/documentation/coremedia) | 4.0 | ✅ | 24.7% | 11: 7 ✅ 1 🟡 3 ❌ | [CoreMedia](frameworks/CoreMedia.md) |
| [Core MIDI](https://developer.apple.com/documentation/coremidi) | 4.2 | ✅ | 98.6% | 19: 13 ✅ 6 🟡 | [CoreMIDI](frameworks/CoreMIDI.md) |
| [Media Accessibility](https://developer.apple.com/documentation/mediaaccessibility) | 17.0 | ❌ | 0.0%* | – | – |
| [Media Device](https://developer.apple.com/documentation/mediadevice) | 27.0 | ❌ | 0.0%* | – | – |
| [Media Intents](https://developer.apple.com/documentation/mediaintents) | 27.0 | ❌ | 0.0%* | – | – |
| [Media Player](https://developer.apple.com/documentation/mediaplayer) | 2.0 | ✅ | 83.2% | 11: 7 ✅ 1 🟡 3 ❌ | [MediaPlayer](frameworks/MediaPlayer.md) |
| [Media Toolbox](https://developer.apple.com/documentation/mediatoolbox) | 6.0 | ❌ | 0.0%* | – | – |
| [MusicKit](https://developer.apple.com/documentation/musickit) | 15.0 | ✅ | 51.1% | 9: 6 ✅ 3 ❌ | [MusicKit](frameworks/MusicKit.md) |
| [Now Playing](https://developer.apple.com/documentation/nowplaying) | 27.0 | ❌ | 0.0%* | – | – |
| [PHASE](https://developer.apple.com/documentation/phase) | 15.0 | ✅ | 97.5% | 14: 12 ✅ 2 🟡 | [PHASE](frameworks/PHASE.md) |
| [ReplayKit](https://developer.apple.com/documentation/replaykit) | 9.0 | ✅ | 100.0% | 7: 5 ✅ 2 🟡 | [ReplayKit](frameworks/ReplayKit.md) |
| [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) | 27.0 | ❌ | 0.0%* | – | – |
| [ShazamKit](https://developer.apple.com/documentation/shazamkit) | 15.0 | ❌ | 0.0%* | – | – |
| [Video Toolbox](https://developer.apple.com/documentation/videotoolbox) | 6.0 | ✅ | 13.8% | 6: 5 ✅ 1 ❌ | [VideoToolbox](frameworks/VideoToolbox.md) |

### Games & 3D

<a id="games"></a>Issues: [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [ARKit](https://developer.apple.com/documentation/arkit) | 11.0 | ✅ | 55.8% | 12: 5 ✅ 7 🟡 | [ARKit](frameworks/ARKit.md) |
| [Game Controller](https://developer.apple.com/documentation/gamecontroller) | 7.0 | ✅ | 68.7% | 18: 12 ✅ 3 🟡 3 ❌ | [GameController](frameworks/GameController.md) |
| [GameKit](https://developer.apple.com/documentation/gamekit) | 3.0 | ✅ | 97.7% | 34: 28 ✅ 5 🟡 1 ❌ | [GameKit](frameworks/GameKit.md) |
| [GameplayKit](https://developer.apple.com/documentation/gameplaykit) | 9.0 | ✅ | 98.2% | 26: 18 ✅ 7 🟡 1 ❌ | [GameplayKit](frameworks/GameplayKit.md) |
| [GameSave](https://developer.apple.com/documentation/gamesave) | 26.0 | ✅ | 100.0% | 2: 2 ✅ | [GameSave](frameworks/GameSave.md) |
| [Group Activities](https://developer.apple.com/documentation/groupactivities) | 15.0 | ✅ | 95.4% | 11: 10 ✅ 1 🟡 | [GroupActivities](frameworks/GroupActivities.md) |
| [Model I/O](https://developer.apple.com/documentation/modelio) | 9.0 | ❌ | 0.0%* | – | – |
| [RealityKit](https://developer.apple.com/documentation/realitykit) | 13.0 | ✅ | 11.7% | 12: 4 ✅ 8 🟡 | [RealityKit](frameworks/RealityKit.md) |
| [RoomPlan](https://developer.apple.com/documentation/roomplan) | 16.0 | ❌ | 0.0%* | – | – |
| [SceneKit](https://developer.apple.com/documentation/scenekit) | 8.0 | ✅ | 63.5% | 18: 9 ✅ 8 🟡 1 ❌ | [SceneKit](frameworks/SceneKit.md) |
| [SpriteKit](https://developer.apple.com/documentation/spritekit) | 7.0 | ✅ | 95.4% | 57: 50 ✅ 7 🟡 | [SpriteKit](frameworks/SpriteKit.md) |
| [Touch Controller](https://developer.apple.com/documentation/touchcontroller) | 26.0 | ❌ | 0.0%* | – | – |
| [USDKit](https://developer.apple.com/documentation/usdkit) | 27.0 | ❌ | 0.0%* | – | – |

### Commerce & privacy

<a id="commerce"></a>Issues: [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [AdAttributionKit](https://developer.apple.com/documentation/adattributionkit) | 17.4 | ✅ | 100.0% | 1: 1 ✅ | [AdAttributionKit](frameworks/AdAttributionKit.md) |
| [AdServices](https://developer.apple.com/documentation/adservices) | 14.3 | ✅ | 100.0% | 1: 1 ✅ | [AdServices](frameworks/AdServices.md) |
| [AdSupport](https://developer.apple.com/documentation/adsupport) | 6.0 | ✅ | 100.0% | 1: 1 ✅ | [AdSupport](frameworks/AdSupport.md) |
| [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency) | 14.0 | ✅ | 100.0% | 2: 2 ✅ | [AppTrackingTransparency](frameworks/AppTrackingTransparency.md) |
| [Declared Age Range](https://developer.apple.com/documentation/declaredagerange) | 26.0 | ✅ | 100.0% | 4: 3 ✅ 1 🟡 | [DeclaredAgeRange](frameworks/DeclaredAgeRange.md) |
| [FinanceKit](https://developer.apple.com/documentation/financekit) | 17.0 | ✅ | 100.0% | 7: 6 ✅ 1 🧩 | [FinanceKit](frameworks/FinanceKit.md) |
| [FinanceKitUI](https://developer.apple.com/documentation/financekitui) | 17.0 | ✅ | 100.0% | 3: 2 ✅ 1 🧩 | [FinanceKitUI](frameworks/FinanceKitUI.md) |
| [ManagedAppDistribution](https://developer.apple.com/documentation/managedappdistribution) | 17.2 | ❌ | 0.0%* | – | – |
| [MarketplaceKit](https://developer.apple.com/documentation/marketplacekit) | 17.4 | ✅ | 7.6% | 3: 1 🟡 2 ❌ | [MarketplaceKit](frameworks/MarketplaceKit.md) |
| [PassKit (Apple Pay and Wallet)](https://developer.apple.com/documentation/passkit) | 6.0 | ✅ | 46.4% | 12: 10 ✅ 1 🟡 1 ❌ | [PassKit](frameworks/PassKit.md) |
| [PermissionKit](https://developer.apple.com/documentation/permissionkit) | 26.0 | ✅ | 100.0% | 5: 3 ✅ 2 🟡 | [PermissionKit](frameworks/PermissionKit.md) |
| [StoreKit](https://developer.apple.com/documentation/storekit) | 3.0 | ✅ | 65.8% | 47: 41 ✅ 2 🟡 4 ❌ | [StoreKit](frameworks/StoreKit.md) |
| [Wallet Orders](https://developer.apple.com/documentation/walletorders) | 16.0 | ✅ | – | 2: 1 ✅ 1 ❌ | [WalletOrders](frameworks/WalletOrders.md) |
| [Wallet Passes](https://developer.apple.com/documentation/walletpasses) | 6.0 | ✅ | – | 9: 8 ✅ 1 ❌ | [WalletPasses](frameworks/WalletPasses.md) |

### Data & persistence

<a id="data"></a>Issues: [`area:data`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adata)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [CloudKit](https://developer.apple.com/documentation/cloudkit) | 8.0 | ✅ | 75.9% | 11: 9 ✅ 2 ❌ | [CloudKit](frameworks/CloudKit.md) |
| [Core Data](https://developer.apple.com/documentation/coredata) | 3.0 | ✅ | 77.6% | 22: 20 ✅ 1 🟡 1 ❌ | [CoreData](frameworks/CoreData.md) |
| [SwiftData](https://developer.apple.com/documentation/swiftdata) | 17.0 | ✅ | 82.3% | 13: 12 ✅ 1 ❌ | [SwiftData](frameworks/SwiftData.md) |

### Identity & security

<a id="security"></a>Issues: [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Authentication Services](https://developer.apple.com/documentation/authenticationservices) | 12.0 | ✅ | 49.6% | 18: 15 ✅ 3 ❌ | [AuthenticationServices](frameworks/AuthenticationServices.md) |
| [CarKey](https://developer.apple.com/documentation/carkey) | 16.0 | ❌ | 0.0%* | – | – |
| [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit) | 13.0 | ✅ | 94.5% | 11: 9 ✅ 2 ❌ | [CryptoKit](frameworks/CryptoKit.md) |
| [CryptoTokenKit](https://developer.apple.com/documentation/cryptotokenkit) | 13.0 | ✅ | 71.0% | 9: 7 ✅ 1 🟡 1 ❌ | [CryptoTokenKit](frameworks/CryptoTokenKit.md) |
| [DeviceCheck](https://developer.apple.com/documentation/devicecheck) | 11.0 | ✅ | 100.0% | 1: 1 ✅ | [DeviceCheck](frameworks/DeviceCheck.md) |
| [GSS](https://developer.apple.com/documentation/gss) | 5.0 | ❌ | 0.0%* | – | – |
| [IdentityDocumentServices](https://developer.apple.com/documentation/identitydocumentservices) | 26.0 | ✅ | 100.0% | 3: 3 ✅ | [IdentityDocumentServices](frameworks/IdentityDocumentServices.md) |
| [IdentityDocumentServicesUI](https://developer.apple.com/documentation/identitydocumentservicesui) | 26.0 | ❌ | 0.0%* | – | – |
| [LightweightCodeRequirements](https://developer.apple.com/documentation/lightweightcoderequirements) | 17.4 | ❌ | 0.0%* | – | – |
| [Local Authentication](https://developer.apple.com/documentation/localauthentication) | 8.0 | ✅ | 98.1% | 8: 6 ✅ 2 ❌ | [LocalAuthentication](frameworks/LocalAuthentication.md) |
| [Local Authentication Embedded UI](https://developer.apple.com/documentation/localauthenticationembeddedui) | 16.0 | ❌ | 0.0%* | – | – |
| [Security](https://developer.apple.com/documentation/security) | 2.0 | ✅ | 26.2% | 11: 9 ✅ 1 🟡 1 ❌ | [Security](frameworks/Security.md) |
| [ServicesAccountLinking](https://developer.apple.com/documentation/servicesaccountlinking) | 16.4 | ❌ | 0.0%* | – | – |
| [Trust Insights](https://developer.apple.com/documentation/trustinsights) | 27.0 | ❌ | 0.0%* | – | – |

### App extensions & system integration

<a id="system"></a>Issues: [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Accessory Live Activities](https://developer.apple.com/documentation/accessoryliveactivities) | 26.5 | ❌ | 0.0%* | – | – |
| [Accessory Notifications](https://developer.apple.com/documentation/accessorynotifications) | 26.5 | ❌ | 0.0%* | – | – |
| [Accessory Transport Extension](https://developer.apple.com/documentation/accessorytransportextension) | 26.2 | ❌ | 0.0%* | – | – |
| [ActivityKit](https://developer.apple.com/documentation/activitykit) | 16.1 | ✅ | 50.0% | 1: 1 ✅ | [ActivityKit](frameworks/ActivityKit.md) |
| [AlarmKit](https://developer.apple.com/documentation/alarmkit) | 26.0 | ✅ | 100.0% | 7: 6 ✅ 1 🟡 | [AlarmKit](frameworks/AlarmKit.md) |
| [App Clips](https://developer.apple.com/documentation/appclip) | 14.0 | ✅ | 100.0% | 1: 1 ✅ | [AppClip](frameworks/AppClip.md) |
| [App Intents](https://developer.apple.com/documentation/appintents) | 16.0 | ✅ | 54.6% | 23: 11 ✅ 8 🟡 4 ❌ | [AppIntents](frameworks/AppIntents.md) |
| [AppMigrationKit](https://developer.apple.com/documentation/appmigrationkit) | 26.1 | ❌ | 0.0%* | – | – |
| [Assignables](https://developer.apple.com/documentation/assignables) | 15.4 | ❌ | 0.0%* | – | – |
| [Automated Device Enrollment](https://developer.apple.com/documentation/automateddeviceenrollment) | 16.1 | ❌ | – | – | – |
| [Automatic Assessment Configuration](https://developer.apple.com/documentation/automaticassessmentconfiguration) | 13.4 | ❌ | 0.0%* | – | – |
| [Background Assets](https://developer.apple.com/documentation/backgroundassets) | 16.0 | ✅ | 92.0% | 9: 6 ✅ 3 🟡 | [BackgroundAssets](frameworks/BackgroundAssets.md) |
| [Background Tasks](https://developer.apple.com/documentation/backgroundtasks) | 13.0 | ✅ | 92.1% | 7: 6 ✅ 1 ❌ | [BackgroundTasks](frameworks/BackgroundTasks.md) |
| [BrowserEngineCore](https://developer.apple.com/documentation/browserenginecore) | 17.4 | ❌ | 0.0%* | – | – |
| [BrowserEngineKit](https://developer.apple.com/documentation/browserenginekit) | 17.4 | ❌ | 0.0%* | – | – |
| [BrowserKit](https://developer.apple.com/documentation/browserkit) | 18.4 | ❌ | 0.0%* | – | – |
| [CallKit](https://developer.apple.com/documentation/callkit) | 10.0 | ✅ | 82.4% | 4: 3 ✅ 1 ❌ | [CallKit](frameworks/CallKit.md) |
| [CarPlay](https://developer.apple.com/documentation/carplay) | 12.0 | ✅ | 99.1% | 16: 11 ✅ 5 🟡 | [CarPlay](frameworks/CarPlay.md) |
| [ClassKit](https://developer.apple.com/documentation/classkit) | 11.4 | ❌ | 0.0%* | – | – |
| [ContactProvider](https://developer.apple.com/documentation/contactprovider) | 18.0 | ❌ | 0.0%* | – | – |
| [Core Spotlight](https://developer.apple.com/documentation/corespotlight) | 9.0 | ✅ | 50.1% | 7: 6 ✅ 1 ❌ | [CoreSpotlight](frameworks/CoreSpotlight.md) |
| [Device Activity](https://developer.apple.com/documentation/deviceactivity) | 15.0 | ✅ | 100.0% | 5: 4 ✅ 1 🟡 | [DeviceActivity](frameworks/DeviceActivity.md) |
| [DeviceDiscoveryExtension](https://developer.apple.com/documentation/devicediscoveryextension) | 16.0 | ❌ | 0.0%* | – | – |
| [DeviceDiscoveryUI](https://developer.apple.com/documentation/devicediscoveryui) | 26.0 | ❌ | 0.0%* | – | – |
| [Device Management](https://developer.apple.com/documentation/devicemanagement) | 13.0 | ❌ | – | – | – |
| [EnergyKit](https://developer.apple.com/documentation/energykit) | 26.0 | ❌ | 0.0%* | – | – |
| [ExtensionFoundation](https://developer.apple.com/documentation/extensionfoundation) | 16.0 | ✅ | 11.5% | 1: 1 🟡 | [ExtensionFoundation](frameworks/ExtensionFoundation.md) |
| [ExtensionKit](https://developer.apple.com/documentation/extensionkit) | 16.1 | ✅ | 2.8% | 1: 1 🟡 | [ExtensionKit](frameworks/ExtensionKit.md) |
| [Family Controls](https://developer.apple.com/documentation/familycontrols) | 15.0 | ✅ | 98.0% | 6: 4 ✅ 2 🟡 | [FamilyControls](frameworks/FamilyControls.md) |
| [File Provider](https://developer.apple.com/documentation/fileprovider) | 11.0 | ✅ | 100.0% | 12: 7 ✅ 5 🟡 | [FileProvider](frameworks/FileProvider.md) |
| [File Provider UI](https://developer.apple.com/documentation/fileproviderui) | 11.0 | ✅ | 100.0% | 4: 4 ✅ | [FileProviderUI](frameworks/FileProviderUI.md) |
| [SMS and Call Reporting](https://developer.apple.com/documentation/identitylookup) | 11.0 | ❌ | 0.0%* | – | – |
| [SiriKit](https://developer.apple.com/documentation/sirikit) | 10.0 | ✅ | 60.5% | 13: 11 ✅ 2 ❌ | [Intents](frameworks/Intents.md) |
| [IntentsUI](https://developer.apple.com/documentation/sirikit) | 10.0 | ✅ | 95.8% | – | [IntentsUI](frameworks/IntentsUI.md) |
| [Journaling Suggestions](https://developer.apple.com/documentation/journalingsuggestions) | 17.2 | ❌ | 0.0%* | – | – |
| [LiveCommunicationKit](https://developer.apple.com/documentation/livecommunicationkit) | 17.4 | ✅ | 100.0% | 8: 4 ✅ 4 🟡 | [LiveCommunicationKit](frameworks/LiveCommunicationKit.md) |
| [ManagedApp](https://developer.apple.com/documentation/managedapp) | 18.4 | ❌ | 0.0%* | – | – |
| [Managed Settings](https://developer.apple.com/documentation/managedsettings) | 15.0 | ✅ | 97.6% | 7: 5 ✅ 2 🟡 | [ManagedSettings](frameworks/ManagedSettings.md) |
| [Managed Settings UI](https://developer.apple.com/documentation/managedsettingsui) | 15.0 | ✅ | 100.0% | 2: 2 ✅ | [ManagedSettingsUI](frameworks/ManagedSettingsUI.md) |
| [Media Setup](https://developer.apple.com/documentation/mediasetup) | 14.0 | ❌ | 0.0%* | – | – |
| [Messages](https://developer.apple.com/documentation/messages) | 10.0 | ✅ | 100.0% | 9: 5 ✅ 4 🟡 | [Messages](frameworks/Messages.md) |
| [PushKit](https://developer.apple.com/documentation/pushkit) | 8.0 | ✅ | 100.0% | 3: 3 ✅ | [PushKit](frameworks/PushKit.md) |
| [Push to Talk](https://developer.apple.com/documentation/pushtotalk) | 16.0 | ❌ | 0.0%* | – | – |
| [RelevanceKit](https://developer.apple.com/documentation/relevancekit) | 26.0 | ❌ | 0.0%* | – | – |
| [SafetyKit](https://developer.apple.com/documentation/safetykit) | 16.0 | ❌ | 0.0%* | – | – |
| [Screen Time](https://developer.apple.com/documentation/screentime) | 14.0 | ❌ | 0.0%* | – | – |
| [Shared with You](https://developer.apple.com/documentation/sharedwithyou) | 16.0 | ❌ | 0.0%* | – | – |
| [Suggested Actions](https://developer.apple.com/documentation/suggestedactions) | 27.0 | ❌ | 0.0%* | – | – |
| [TelephonyMessagingKit](https://developer.apple.com/documentation/telephonymessagingkit) | 26.0 | ❌ | 0.0%* | – | – |
| [TipKit](https://developer.apple.com/documentation/tipkit) | 17.0 | ✅ | 100.0% | 10: 10 ✅ | [TipKit](frameworks/TipKit.md) |
| [User Notifications](https://developer.apple.com/documentation/usernotifications) | 10.0 | ✅ | 80.7% | 12: 12 ✅ | [UserNotifications](frameworks/UserNotifications.md) |
| [User Notifications UI](https://developer.apple.com/documentation/usernotificationsui) | 10.0 | ✅ | 100.0% | – | [UserNotificationsUI](frameworks/UserNotificationsUI.md) |
| [Video Subscriber Account](https://developer.apple.com/documentation/videosubscriberaccount) | 10.0 | ❌ | 0.0%* | – | – |
| [WidgetKit](https://developer.apple.com/documentation/widgetkit) | 14.0 | ✅ | 66.5% | 9: 5 ✅ 1 🟡 3 ❌ | [WidgetKit](frameworks/WidgetKit.md) |

### Location, personal data & sensors

<a id="location"></a>Issues: [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit) | 18.0 | ✅ | 39.0% | 1: 1 🧩 | [AccessorySetupKit](frameworks/AccessorySetupKit.md) |
| [Contacts](https://developer.apple.com/documentation/contacts) | 9.0 | ✅ | 43.1% | 4: 2 ✅ 1 🟡 1 ❌ | [Contacts](frameworks/Contacts.md) |
| [Contacts UI](https://developer.apple.com/documentation/contactsui) | 9.0 | ✅ | 77.1% | 2: 1 ✅ 1 ❌ | [ContactsUI](frameworks/ContactsUI.md) |
| [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) | 5.0 | ✅ | 87.4% | 5: 3 🧩 2 ❌ | [CoreBluetooth](frameworks/CoreBluetooth.md) |
| [Core Location](https://developer.apple.com/documentation/corelocation) | 2.0 | ✅ | 83.0% | 5: 3 ✅ 2 ❌ | [CoreLocation](frameworks/CoreLocation.md) |
| [CoreLocationUI](https://developer.apple.com/documentation/corelocationui) | 15.0 | ✅ | 100.0% | 2: 2 ✅ | [CoreLocationUI](frameworks/CoreLocationUI.md) |
| [Core Motion](https://developer.apple.com/documentation/coremotion) | 4.0 | ✅ | 73.9% | 6: 1 ✅ 2 🧩 3 ❌ | [CoreMotion](frameworks/CoreMotion.md) |
| [Core NFC](https://developer.apple.com/documentation/corenfc) | 11.0 | ✅ | 60.7% | 6: 4 🧩 2 ❌ | [CoreNFC](frameworks/CoreNFC.md) |
| [DockKit](https://developer.apple.com/documentation/dockkit) | 17.0 | ❌ | 0.0%* | – | – |
| [DriverKit](https://developer.apple.com/documentation/driverkit) | 16.0 | ❌ | 0.0%* | – | – |
| [EventKit](https://developer.apple.com/documentation/eventkit) | 4.0 | ✅ | 77.2% | 7: 5 ✅ 1 🟡 1 ❌ | [EventKit](frameworks/EventKit.md) |
| [EventKit UI](https://developer.apple.com/documentation/eventkitui) | 4.0 | ✅ | 93.9% | 2: 2 ✅ | [EventKitUI](frameworks/EventKitUI.md) |
| [Exposure Notification](https://developer.apple.com/documentation/exposurenotification) | 13.5 | ❌ | 0.0%* | – | – |
| [External Accessory](https://developer.apple.com/documentation/externalaccessory) | 3.0 | ✅ | 36.5% | 1: 1 🧩 | [ExternalAccessory](frameworks/ExternalAccessory.md) |
| [GeoToolbox](https://developer.apple.com/documentation/geotoolbox) | 26.0 | ❌ | 0.0%* | – | – |
| [HealthKit](https://developer.apple.com/documentation/healthkit) | 8.0 | ✅ | 20.4% | 11: 6 ✅ 1 🟡 4 ❌ | [HealthKit](frameworks/HealthKit.md) |
| [HomeKit](https://developer.apple.com/documentation/homekit) | 8.0 | ✅ | 99.9% | 16: 6 ✅ 5 🟡 4 🧩 1 ❌ | [HomeKit](frameworks/HomeKit.md) |
| [hvf](https://developer.apple.com/documentation/hvf) | 18.4 | ❌ | 0.0%* | – | – |
| [IOKit](https://developer.apple.com/documentation/iokit) | 16.0 | ❌ | 0.0%* | – | – |
| [MapKit](https://developer.apple.com/documentation/mapkit) | 3.0 | ✅ | 75.1% | 19: 16 ✅ 1 🟡 2 ❌ | [MapKit](frameworks/MapKit.md) |
| [Matter](https://developer.apple.com/documentation/matter) | 16.0 | ❌ | 0.0%* | – | – |
| [MatterSupport](https://developer.apple.com/documentation/mattersupport) | 16.1 | ❌ | 0.0%* | – | – |
| [Nearby Interaction](https://developer.apple.com/documentation/nearbyinteraction) | 14.0 | ✅ | 49.7% | 1: 1 🧩 | [NearbyInteraction](frameworks/NearbyInteraction.md) |
| [SensorKit](https://developer.apple.com/documentation/sensorkit) | 14.0 | ❌ | 0.0%* | – | – |
| [ThreadNetwork](https://developer.apple.com/documentation/threadnetwork) | 15.0 | ❌ | 0.0%* | – | – |
| [WeatherKit](https://developer.apple.com/documentation/weatherkit) | 16.0 | ✅ | 100.0% | 9: 2 ✅ 7 🟡 | [WeatherKit](frameworks/WeatherKit.md) |
| [Wi-Fi Aware](https://developer.apple.com/documentation/wifiaware) | 26.0 | ❌ | 0.0%* | – | – |
| [Wi-Fi Infrastructure](https://developer.apple.com/documentation/wifiinfrastructure) | 26.2 | ❌ | 0.0%* | – | – |
| [WirelessInsights](https://developer.apple.com/documentation/wirelessinsights) | 26.0 | ❌ | 0.0%* | – | – |
| [WorkoutKit](https://developer.apple.com/documentation/workoutkit) | 17.0 | ✅ | 69.1% | 2: 1 ✅ 1 🧩 | [WorkoutKit](frameworks/WorkoutKit.md) |

### Web, network & communication

<a id="web"></a>Issues: [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Core Telephony](https://developer.apple.com/documentation/coretelephony) | 4.0 | ✅ | 45.8% | 7: 1 ✅ 4 🧩 2 ❌ | [CoreTelephony](frameworks/CoreTelephony.md) |
| [dnssd](https://developer.apple.com/documentation/dnssd) | 10.0 | ❌ | 0.0%* | – | – |
| [Link Presentation](https://developer.apple.com/documentation/linkpresentation) | 13.0 | ✅ | 69.2% | 6: 5 ✅ 1 ❌ | [LinkPresentation](frameworks/LinkPresentation.md) |
| [Message UI](https://developer.apple.com/documentation/messageui) | 3.0 | ✅ | 66.3% | 2: 1 ✅ 1 ❌ | [MessageUI](frameworks/MessageUI.md) |
| [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity) | 7.0 | ✅ | 94.0% | 2: 2 ✅ | [MultipeerConnectivity](frameworks/MultipeerConnectivity.md) |
| [Network](https://developer.apple.com/documentation/network) | 12.0 | ✅ | 41.6% | 10: 6 ✅ 1 🧩 3 ❌ | [Network](frameworks/Network.md) |
| [Network Extension](https://developer.apple.com/documentation/networkextension) | 8.0 | ❌ | 0.0%* | – | – |
| [Safari Services](https://developer.apple.com/documentation/safariservices) | 7.0 | ✅ | 62.5% | 5: 3 ✅ 2 ❌ | [SafariServices](frameworks/SafariServices.md) |
| [Social](https://developer.apple.com/documentation/social) | 6.0 | ✅ | 42.9% | 1: 1 ❌ | [Social](frameworks/Social.md) |
| [System Configuration](https://developer.apple.com/documentation/systemconfiguration) | 2.0 | ✅ | 20.4% | 2: 1 ✅ 1 ❌ | [SystemConfiguration](frameworks/SystemConfiguration.md) |
| [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity) | 9.0 | ✅ | 48.4% | 1: 1 🧩 | [WatchConnectivity](frameworks/WatchConnectivity.md) |
| [WebKit](https://developer.apple.com/documentation/webkit) | 16.0 | ✅ | 35.5% | 14: 10 ✅ 4 ❌ | [WebKit](frameworks/WebKit.md) |

### Accessibility & Info.plist

<a id="a11y"></a>Issues: [`area:a11y`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aa11y)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Accessibility](https://developer.apple.com/documentation/accessibility) | 14.0 | ✅ | 14.4% | 6: 5 ✅ 1 ❌ | [Accessibility](frameworks/Accessibility.md) |
| [Bundle Resources](https://developer.apple.com/documentation/bundleresources) | 2.0 | ✅ | 0.0%* | 16: 10 ✅ 1 🟡 5 ❌ | [BundleResources](frameworks/BundleResources.md) |

\* measured by name (approximate): not built into isim yet, or measured without a built SDK.
<!-- /generated:index -->

## Out of scope

Frameworks Apple deprecated in iOS 17 or earlier, and frameworks that are Apple-platform-only and completely impossible
to replicate on Linux. Capabilities that need Apple's own secrets are ⛔ rows on their framework's page instead:
- Apple-signed receipts, attestations and tokens;
- FairPlay keys;
- Apple's licensed models and SF Symbols artwork;
- Apple's servers;
- Xcode-compiled `.metallib` and `.mlmodelc` files.

<!-- generated:out-of-scope (isim/tools/coverage-summary.py; do not edit by hand) -->
| Framework | Why |
|---|---|
| Accounts | deprecated in iOS 15 |
| AddressBook | deprecated in iOS 9 |
| AddressBookUI | deprecated in iOS 9 |
| AssetsLibrary | deprecated in iOS 9 |
| ClockKit | watchOS complications, deprecated |
| GLKit | deprecated in iOS 12 |
| iAd | removed |
| NewsstandKit | removed |
| NotificationCenter | Today widgets, deprecated in iOS 14 |
| OpenGLES | deprecated in iOS 12 |
<!-- /generated:out-of-scope -->

## Objective-C and C interfaces

Most binary SDKs and many apps are written in Objective-C. Every framework isim implements in Swift also needs Apple's
Objective-C/C interface: headers in `isim/sdk-src/Frameworks/<Name>` over the Swift classes (AGENTS.md).

<!-- generated:objc (isim/tools/coverage-summary.py; do not edit by hand) -->
| Framework | Objective-C / C interface |
|---|---|
| Accelerate | ✅ headers in isim/sdk-src/Frameworks/Accelerate |
| Accessibility | ✅ headers in isim/sdk-src/Frameworks/Accessibility |
| AccessorySetupKit | ✅ headers in isim/sdk-src/Frameworks/AccessorySetupKit |
| ActivityKit | ❌ Swift only |
| AdAttributionKit | ❌ Swift only |
| AdServices | ❌ Swift only |
| AdSupport | ✅ headers in isim/sdk-src/Frameworks/AdSupport |
| AlarmKit | ❌ Swift only |
| AppClip | ❌ Swift only |
| AppIntents | ❌ Swift only |
| AppleArchive | ✅ headers in isim/sdk-src/Frameworks/AppleArchive |
| AppTrackingTransparency | ✅ headers in isim/sdk-src/Frameworks/AppTrackingTransparency |
| ARKit | ✅ headers in isim/sdk-src/Frameworks/ARKit |
| AudioToolbox | ✅ headers in isim/sdk-src/Frameworks/AudioToolbox |
| AudioUnit | ✅ headers in isim/sdk-src/Frameworks/AudioUnit |
| AuthenticationServices | ✅ headers in isim/sdk-src/Frameworks/AuthenticationServices |
| AVFAudio | ✅ headers in isim/sdk-src/Frameworks/AVFAudio |
| AVFoundation | ✅ headers in isim/sdk-src/Frameworks/AVFoundation |
| AVKit | ❌ Swift only |
| BackgroundAssets | ✅ headers in isim/sdk-src/Frameworks/BackgroundAssets |
| BackgroundTasks | ✅ headers in isim/sdk-src/Frameworks/BackgroundTasks |
| CallKit | ✅ headers in isim/sdk-src/Frameworks/CallKit |
| CarPlay | ✅ headers in isim/sdk-src/Frameworks/CarPlay |
| CFNetwork | ✅ headers in isim/sdk-src/Frameworks/CFNetwork |
| Charts | ❌ Swift only |
| CloudKit | ✅ headers in isim/sdk-src/Frameworks/CloudKit |
| Combine | ❌ Swift only |
| Compression | ❌ Swift only |
| Contacts | ✅ headers in isim/sdk-src/Frameworks/Contacts |
| ContactsUI | ✅ headers in isim/sdk-src/Frameworks/ContactsUI |
| CoreAudio | ✅ headers in isim/sdk-src/Frameworks/CoreAudio |
| CoreAudioTypes | ✅ headers in isim/sdk-src/Frameworks/CoreAudioTypes |
| CoreBluetooth | ✅ headers in isim/sdk-src/Frameworks/CoreBluetooth |
| CoreData | ✅ headers in isim/sdk-src/Frameworks/CoreData |
| CoreFoundation | ✅ headers in isim/sdk-src/Frameworks/CoreFoundation |
| CoreGraphics | ✅ headers in isim/sdk-src/Frameworks/CoreGraphics |
| CoreHaptics | ✅ headers in isim/sdk-src/Frameworks/CoreHaptics |
| CoreImage | ✅ headers in isim/sdk-src/Frameworks/CoreImage |
| CoreLocation | ✅ headers in isim/sdk-src/Frameworks/CoreLocation |
| CoreLocationUI | ✅ headers in isim/sdk-src/Frameworks/CoreLocationUI |
| CoreMedia | ✅ headers in isim/sdk-src/Frameworks/CoreMedia |
| CoreMIDI | ✅ headers in isim/sdk-src/Frameworks/CoreMIDI |
| CoreML | ❌ Swift only |
| CoreMotion | ✅ headers in isim/sdk-src/Frameworks/CoreMotion |
| CoreNFC | ✅ headers in isim/sdk-src/Frameworks/CoreNFC |
| CoreSpotlight | ✅ headers in isim/sdk-src/Frameworks/CoreSpotlight |
| CoreTelephony | ✅ headers in isim/sdk-src/Frameworks/CoreTelephony |
| CoreText | ✅ headers in isim/sdk-src/Frameworks/CoreText |
| CoreTransferable | ❌ Swift only |
| CoreVideo | ✅ headers in isim/sdk-src/Frameworks/CoreVideo |
| CryptoKit | ❌ Swift only |
| CryptoTokenKit | ✅ headers in isim/sdk-src/Frameworks/CryptoTokenKit |
| DeclaredAgeRange | ❌ Swift only |
| DeveloperToolsSupport | ❌ Swift only |
| DeviceActivity | ❌ Swift only |
| DeviceCheck | ❌ Swift only |
| Dispatch | ❌ Swift only |
| Distributed | ❌ Swift only |
| EventKit | ✅ headers in isim/sdk-src/Frameworks/EventKit |
| EventKitUI | ✅ headers in isim/sdk-src/Frameworks/EventKitUI |
| ExtensionFoundation | ❌ Swift only |
| ExtensionKit | ❌ Swift only |
| ExternalAccessory | ✅ headers in isim/sdk-src/Frameworks/ExternalAccessory |
| FamilyControls | ❌ Swift only |
| FileProvider | ✅ headers in isim/sdk-src/Frameworks/FileProvider |
| FileProviderUI | ✅ headers in isim/sdk-src/Frameworks/FileProviderUI |
| FinanceKit | ❌ Swift only |
| FinanceKitUI | ❌ Swift only |
| Foundation | ✅ headers in isim/sdk-src/Frameworks/Foundation |
| FoundationModels | ❌ Swift only |
| GameController | ✅ headers in isim/sdk-src/Frameworks/GameController |
| GameKit | ✅ headers in isim/sdk-src/Frameworks/GameKit |
| GameplayKit | ❌ Swift only |
| GameSave | ✅ headers in isim/sdk-src/Frameworks/GameSave |
| GroupActivities | ❌ Swift only |
| HealthKit | ✅ headers in isim/sdk-src/Frameworks/HealthKit |
| HomeKit | ✅ headers in isim/sdk-src/Frameworks/HomeKit |
| IdentityDocumentServices | ❌ Swift only |
| ImageIO | ✅ headers in isim/sdk-src/Frameworks/ImageIO |
| ImagePlayground | ❌ Swift only |
| Intents | ✅ headers in isim/sdk-src/Frameworks/Intents |
| IntentsUI | ✅ headers in isim/sdk-src/Frameworks/IntentsUI |
| JavaScriptCore | ✅ headers in isim/sdk-src/Frameworks/JavaScriptCore |
| LinkPresentation | ✅ headers in isim/sdk-src/Frameworks/LinkPresentation |
| LiveCommunicationKit | ❌ Swift only |
| LocalAuthentication | ✅ headers in isim/sdk-src/Frameworks/LocalAuthentication |
| ManagedSettings | ❌ Swift only |
| ManagedSettingsUI | ❌ Swift only |
| MapKit | ✅ headers in isim/sdk-src/Frameworks/MapKit |
| MarketplaceKit | ✅ headers in isim/sdk-src/Frameworks/MarketplaceKit |
| MediaPlayer | ❌ Swift only |
| Messages | ✅ headers in isim/sdk-src/Frameworks/Messages |
| MessageUI | ✅ headers in isim/sdk-src/Frameworks/MessageUI |
| Metal | ✅ headers in isim/sdk-src/Frameworks/Metal |
| MetalFX | ✅ headers in isim/sdk-src/Frameworks/MetalFX |
| MetalKit | ✅ headers in isim/sdk-src/Frameworks/MetalKit |
| MetalPerformanceShaders | ✅ headers in isim/sdk-src/Frameworks/MetalPerformanceShaders |
| MetalPerformanceShadersGraph | ✅ headers in isim/sdk-src/Frameworks/MetalPerformanceShadersGraph |
| MetricKit | ❌ Swift only |
| MultipeerConnectivity | ✅ headers in isim/sdk-src/Frameworks/MultipeerConnectivity |
| MusicKit | ❌ Swift only |
| NaturalLanguage | ❌ Swift only |
| NearbyInteraction | ✅ headers in isim/sdk-src/Frameworks/NearbyInteraction |
| Network | ✅ headers in isim/sdk-src/Frameworks/Network |
| ObjectiveC | ❌ Swift only |
| Observation | ❌ Swift only |
| os | ❌ Swift only |
| OSLog | ❌ Swift only |
| PassKit | ✅ headers in isim/sdk-src/Frameworks/PassKit |
| PDFKit | ✅ headers in isim/sdk-src/Frameworks/PDFKit |
| PencilKit | ✅ headers in isim/sdk-src/Frameworks/PencilKit |
| PermissionKit | ❌ Swift only |
| PHASE | ✅ headers in isim/sdk-src/Frameworks/PHASE |
| Photos | ✅ headers in isim/sdk-src/Frameworks/Photos |
| PhotosUI | ✅ headers in isim/sdk-src/Frameworks/PhotosUI |
| PushKit | ✅ headers in isim/sdk-src/Frameworks/PushKit |
| QuartzCore | ✅ headers in isim/sdk-src/Frameworks/QuartzCore |
| QuickLook | ✅ headers in isim/sdk-src/Frameworks/QuickLook |
| QuickLookThumbnailing | ✅ headers in isim/sdk-src/Frameworks/QuickLookThumbnailing |
| RealityKit | ❌ Swift only |
| RegexBuilder | ❌ Swift only |
| ReplayKit | ✅ headers in isim/sdk-src/Frameworks/ReplayKit |
| SafariServices | ✅ headers in isim/sdk-src/Frameworks/SafariServices |
| SceneKit | ✅ headers in isim/sdk-src/Frameworks/SceneKit |
| Security | ✅ headers in isim/sdk-src/Frameworks/Security |
| simd | ❌ Swift only |
| Social | ✅ headers in isim/sdk-src/Frameworks/Social |
| SoundAnalysis | ✅ headers in isim/sdk-src/Frameworks/SoundAnalysis |
| Spatial | ❌ Swift only |
| Speech | ❌ Swift only |
| SpriteKit | ✅ headers in isim/sdk-src/Frameworks/SpriteKit |
| StateReporting | ❌ Swift only |
| StoreKit | ✅ headers in isim/sdk-src/Frameworks/StoreKit |
| StoreKitTest | ✅ headers in isim/sdk-src/Frameworks/StoreKitTest |
| Swift | ❌ Swift only |
| SwiftData | ❌ Swift only |
| SwiftUI | ❌ Swift only |
| Symbols | ✅ headers in isim/sdk-src/Frameworks/Symbols |
| Synchronization | ❌ Swift only |
| System | ❌ Swift only |
| SystemConfiguration | ✅ headers in isim/sdk-src/Frameworks/SystemConfiguration |
| Testing | ❌ Swift only |
| TipKit | ❌ Swift only |
| Translation | ❌ Swift only |
| UIKit | ✅ headers in isim/sdk-src/Frameworks/UIKit |
| UniformTypeIdentifiers | ✅ headers in isim/sdk-src/Frameworks/UniformTypeIdentifiers |
| UserNotifications | ✅ headers in isim/sdk-src/Frameworks/UserNotifications |
| UserNotificationsUI | ✅ headers in isim/sdk-src/Frameworks/UserNotificationsUI |
| VideoToolbox | ❌ Swift only |
| Vision | ✅ headers in isim/sdk-src/Frameworks/Vision |
| VisionKit | ✅ headers in isim/sdk-src/Frameworks/VisionKit |
| VisualIntelligence | ❌ Swift only |
| WatchConnectivity | ✅ headers in isim/sdk-src/Frameworks/WatchConnectivity |
| WeatherKit | ❌ Swift only |
| WebKit | ✅ headers in isim/sdk-src/Frameworks/WebKit |
| WidgetKit | ❌ Swift only |
| WorkoutKit | ❌ Swift only |
| XCTest | ✅ headers in isim/sdk-src/Frameworks/XCTest |
| XPC | ❌ Swift only |
<!-- /generated:objc -->
