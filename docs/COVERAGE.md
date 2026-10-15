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
| [UIKit](#uikit) | 92% | 305 | 8 | 0 | 3 | 0 | 2 of 2 |
| [SwiftUI & Charts](#swiftui) | 60% | 251 | 10 | 0 | 7 | 0 | 2 of 2 |
| [Developer tools](#devtools) | 20% | 51 | 5 | 0 | 10 | 0 | 3 of 6 |
| [Foundation & CoreFoundation](#foundation) | 35% | 90 | 6 | 0 | 4 | 0 | 2 of 8 |
| [Swift, Darwin & runtimes](#runtime) | 88% | 91 | 5 | 0 | 11 | 0 | 13 of 16 |
| [Graphics & text](#graphics) | 21% | 52 | 7 | 0 | 11 | 0 | 6 of 12 |
| [GPU](#gpu) | 0% | 0 | 0 | 0 | 1 | 0 | 1 of 7 |
| [Imaging, photos & ML](#ml) | 13% | 12 | 14 | 3 | 22 | 0 | 11 of 30 |
| [Media](#media) | 22% | 49 | 5 | 0 | 21 | 0 | 11 of 27 |
| [Games & 3D](#games) | 15% | 71 | 16 | 0 | 13 | 0 | 7 of 13 |
| [Commerce & privacy](#commerce) | 31% | 35 | 1 | 0 | 6 | 0 | 6 of 14 |
| [Data & persistence](#data) | 51% | 16 | 4 | 0 | 6 | 0 | 3 of 3 |
| [Identity & security](#security) | 25% | 17 | 1 | 0 | 11 | 0 | 5 of 14 |
| [App extensions & system integration](#system) | 22% | 27 | 7 | 0 | 18 | 0 | 12 of 54 |
| [Location, personal data & sensors](#location) | 8% | 14 | 6 | 0 | 20 | 0 | 10 of 30 |
| [Web, network & communication](#web) | 21% | 17 | 0 | 1 | 15 | 0 | 8 of 12 |
| [Accessibility & Info.plist](#a11y) | 0% | 9 | 1 | 0 | 6 | 0 | 1 of 2 |
| **All areas** | **33%** | **1107** | **96** | **4** | **185** | **0** | **103 of 252** |

Symbols: 83046 of 250420 Apple iOS symbols in the frameworks isim has or tracks (exact; isim e014842, Apple snapshot 2026-10-14).
<!-- /generated:summary -->

### Per iOS version

Symbol coverage of what each emulated iOS version has: a symbol counts toward iOS N when Apple introduced it at or before
N (iOS 17 when the snapshot does not say).

<!-- generated:versions (isim/tools/coverage-summary.py; do not edit by hand) -->
| Area | iOS 17 | iOS 18 | iOS 26 | iOS 27 |
|---|---:|---:|---:|---:|
| UIKit | 92% | 92% | 92% | 92% |
| SwiftUI & Charts | 69% | 64% | 61% | 60% |
| Developer tools | 20% | 20% | 20% | 20% |
| Foundation & CoreFoundation | 36% | 35% | 35% | 35% |
| Swift, Darwin & runtimes | 89% | 90% | 89% | 88% |
| Graphics & text | 23% | 23% | 22% | 21% |
| GPU | 0% | 0% | 0% | 0% |
| Imaging, photos & ML | 16% | 14% | 14% | 13% |
| Media | 24% | 24% | 23% | 22% |
| Games & 3D | 15% | 15% | 15% | 15% |
| Commerce & privacy | 36% | 33% | 32% | 31% |
| Data & persistence | 56% | 53% | 52% | 51% |
| Identity & security | 31% | 29% | 25% | 25% |
| App extensions & system integration | 17% | 19% | 23% | 22% |
| Location, personal data & sensors | 8% | 8% | 8% | 8% |
| Web, network & communication | 25% | 23% | 21% | 21% |
| Accessibility & Info.plist | 0% | 0% | 0% | 0% |
| **All areas** | **34%** | **34%** | **33%** | **33%** |
<!-- /generated:versions -->

## Frameworks

Every iOS framework Apple documents, by area. Each area is also an issue label (`area:<name>`). The batches of work
toward 100% are issues labelled `coverage`, each a checklist of APIs.

<!-- generated:index (isim/tools/coverage-summary.py; do not edit by hand) -->

### UIKit

<a id="uikit"></a>Issues: [`area:uikit`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Auikit)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Quick Look](https://developer.apple.com/documentation/quicklook) | 4.0 | ✅ | 49.2% | 1: 1 ❌ | [QuickLook](frameworks/QuickLook.md) |
| [UIKit](https://developer.apple.com/documentation/uikit) | 2.0 | ✅ | 92.1% | 315: 305 ✅ 8 🟡 2 ❌ | [UIKit](frameworks/UIKit.md) |

### SwiftUI & Charts

<a id="swiftui"></a>Issues: [`area:swiftui`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aswiftui)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Swift Charts](https://developer.apple.com/documentation/charts) | 16.0 | ✅ | 74.2% | 17: 14 ✅ 2 🟡 1 ❌ | [Charts](frameworks/Charts.md) |
| [SwiftUI](https://developer.apple.com/documentation/swiftui) | 13.0 | ✅ | 59.1% | 251: 237 ✅ 8 🟡 6 ❌ | [SwiftUI](frameworks/SwiftUI.md) |

### Developer tools

<a id="devtools"></a>Issues: [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [App Intents Testing](https://developer.apple.com/documentation/appintentstesting) | 27.0 | ❌ | 0.0%* | – | – |
| [DeveloperToolsSupport](https://developer.apple.com/documentation/developertoolssupport) | 14.0 | ✅ | 31.2% | 5: 2 ✅ 3 ❌ | [DeveloperToolsSupport](frameworks/DeveloperToolsSupport.md) |
| [Platform](https://developer.apple.com/documentation/platform) | – | ✅ | – | 53: 46 ✅ 3 🟡 4 ❌ | [Platform](frameworks/Platform.md) |
| [StoreKit Test](https://developer.apple.com/documentation/storekittest) | 14.0 | ❌ | 0.0%* | – | – |
| [Swift Testing](https://developer.apple.com/documentation/testing) | None | ✅ | 81.6% | 2: 1 ✅ 1 ❌ | [Testing](frameworks/Testing.md) |
| [XCTest](https://developer.apple.com/documentation/xctest) | None | ✅ | 35.8% | 6: 2 ✅ 2 🟡 2 ❌ | [XCTest](frameworks/XCTest.md) |
| [XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation) | None | ❌ | 0.0%* | – | – |
| Platform (isim topic) | – | ✅ | – | 53: 46 ✅ 3 🟡 4 ❌ | [Platform](frameworks/Platform.md) |

### Foundation & CoreFoundation

<a id="foundation"></a>Issues: [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Apple Archive](https://developer.apple.com/documentation/applearchive) | 14.0 | ❌ | 0.0%* | – | – |
| [CFNetwork](https://developer.apple.com/documentation/cfnetwork) | 2.0 | ❌ | 0.0%* | – | – |
| [Compression](https://developer.apple.com/documentation/compression) | 9.0 | ❌ | 0.0%* | – | – |
| [Core Foundation](https://developer.apple.com/documentation/corefoundation) | 2.0 | ✅ | 11.6% | 4: 1 ✅ 2 🟡 1 ❌ | [CoreFoundation](frameworks/CoreFoundation.md) |
| [Core Services](https://developer.apple.com/documentation/coreservices) | 12.0 | ❌ | 0.0%* | – | – |
| [Foundation](https://developer.apple.com/documentation/foundation) | 2.0 | ✅ | 44.5% | 96: 89 ✅ 4 🟡 3 ❌ | [Foundation](frameworks/Foundation.md) |
| [System](https://developer.apple.com/documentation/system) | 14.0 | ❌ | 0.0%* | – | – |
| [XPC](https://developer.apple.com/documentation/xpc) | 17.4 | ❌ | 0.0%* | – | – |

### Swift, Darwin & runtimes

<a id="runtime"></a>Issues: [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Combine](https://developer.apple.com/documentation/combine) | 13.0 | ✅ | 81.5% | 14: 14 ✅ | [Combine](frameworks/Combine.md) |
| [CrashReportExtension](https://developer.apple.com/documentation/crashreportextension) | 27.0 | ❌ | 0.0%* | – | – |
| [Darwin](https://developer.apple.com/documentation/darwin) | – | ✅ | – | 24: 20 ✅ 4 🟡 | [Darwin](frameworks/Darwin.md) |
| [Darwin Notify](https://developer.apple.com/documentation/darwinnotify) | 9.3 | ❌ | 0.0%* | – | – |
| [Dispatch](https://developer.apple.com/documentation/dispatch) | 8.0 | ✅ | 84.7% | 7: 6 ✅ 1 ❌ | [Dispatch](frameworks/Dispatch.md) |
| [Distributed](https://developer.apple.com/documentation/distributed) | 16.0 | ✅ | 100.0% | – | [Distributed](frameworks/Distributed.md) |
| [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) | 16.0 | ✅ | 89.8% | 2: 1 ✅ 1 ❌ | [JavaScriptCore](frameworks/JavaScriptCore.md) |
| [MetricKit](https://developer.apple.com/documentation/metrickit) | 13.0 | ✅ | 36.9% | 4: 1 ✅ 3 ❌ | [MetricKit](frameworks/MetricKit.md) |
| [Objective-C Runtime](https://developer.apple.com/documentation/objectivec) | 2.0 | ✅ | 71.1% | 22: 20 ✅ 1 🟡 1 ❌ | [ObjectiveC](frameworks/ObjectiveC.md) |
| [Observation](https://developer.apple.com/documentation/observation) | 17.0 | ✅ | 52.8% | 1: 1 ❌ | [Observation](frameworks/Observation.md) |
| [os](https://developer.apple.com/documentation/os) | 8.0 | ✅ | 84.1% | 7: 5 ✅ 2 ❌ | [os](frameworks/os.md) |
| [OSLog](https://developer.apple.com/documentation/oslog) | 15.0 | ✅ | 89.8% | – | [OSLog](frameworks/OSLog.md) |
| [RegexBuilder](https://developer.apple.com/documentation/regexbuilder) | 16.0 | ✅ | 99.6% | – | [RegexBuilder](frameworks/RegexBuilder.md) |
| [simd](https://developer.apple.com/documentation/simd) | None | ✅ | 51.9% | – | [simd](frameworks/simd.md) |
| [StateReporting](https://developer.apple.com/documentation/statereporting) | 27.0 | ❌ | 0.0%* | – | – |
| [Swift](https://developer.apple.com/documentation/swift) | 8.0 | ✅ | 92.4% | 26: 24 ✅ 2 ❌ | [Swift](frameworks/Swift.md) |
| [Synchronization](https://developer.apple.com/documentation/synchronization) | 18.0 | ✅ | 100.0% | – | [Synchronization](frameworks/Synchronization.md) |
| Darwin (isim topic) | – | ✅ | – | 24: 20 ✅ 4 🟡 | [Darwin](frameworks/Darwin.md) |

### Graphics & text

<a id="graphics"></a>Issues: [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [ColorSync](https://developer.apple.com/documentation/colorsync) | 16.0 | ❌ | 0.0%* | – | – |
| [Core Graphics](https://developer.apple.com/documentation/coregraphics) | 2.0 | ✅ | 45.7% | 26: 19 ✅ 3 🟡 4 ❌ | [CoreGraphics](frameworks/CoreGraphics.md) |
| [Core Text](https://developer.apple.com/documentation/coretext) | 3.2 | ✅ | 12.8% | 8: 6 ✅ 1 🟡 1 ❌ | [CoreText](frameworks/CoreText.md) |
| [Core Video](https://developer.apple.com/documentation/corevideo) | 4.0 | ✅ | 11.2% | 9: 6 ✅ 3 ❌ | [CoreVideo](frameworks/CoreVideo.md) |
| [Image I/O](https://developer.apple.com/documentation/imageio) | 4.0 | ✅ | 9.3% | 3: 2 🟡 1 ❌ | [ImageIO](frameworks/ImageIO.md) |
| [IOSurface](https://developer.apple.com/documentation/iosurface) | 11.0 | ❌ | 0.0%* | – | – |
| [PaperKit](https://developer.apple.com/documentation/paperkit) | 26.0 | ❌ | 0.0%* | – | – |
| [PDFKit](https://developer.apple.com/documentation/pdfkit) | 11.0 | ❌ | 0.0%* | – | – |
| [PencilKit](https://developer.apple.com/documentation/pencilkit) | 13.0 | ❌ | 0.0%* | – | – |
| [Core Animation](https://developer.apple.com/documentation/quartzcore) | 2.0 | ✅ | 86.9% | 24: 21 ✅ 1 🟡 2 ❌ | [QuartzCore](frameworks/QuartzCore.md) |
| [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing) | 13.0 | ❌ | 0.0%* | – | – |
| [Symbols](https://developer.apple.com/documentation/symbols) | 17.0 | ✅ | 86.5% | – | [Symbols](frameworks/Symbols.md) |

### GPU

<a id="gpu"></a>Issues: [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Compute Graph](https://developer.apple.com/documentation/computegraph) | 27.0 | ❌ | 0.0%* | – | – |
| [Metal](https://developer.apple.com/documentation/metal) | 8.0 | ✅ | 0.0%* | 1: 1 ❌ | [Metal](frameworks/Metal.md) |
| [MetalFX](https://developer.apple.com/documentation/metalfx) | 16.0 | ❌ | 0.0%* | – | – |
| [MetalKit](https://developer.apple.com/documentation/metalkit) | 9.0 | ❌ | 0.0%* | – | – |
| [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders) | 9.0 | ❌ | 0.0%* | – | – |
| [Metal Performance Shaders Graph](https://developer.apple.com/documentation/metalperformanceshadersgraph) | 14.0 | ❌ | 0.0%* | – | – |
| [ShaderGraph](https://developer.apple.com/documentation/shadergraph) | 17.0 | ❌ | 0.0%* | – | – |

### Imaging, photos & ML

<a id="ml"></a>Issues: [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Accelerate](https://developer.apple.com/documentation/accelerate) | 4.0 | ❌ | 0.0%* | – | – |
| [Core AI](https://developer.apple.com/documentation/coreai) | 27.0 | ❌ | 0.0%* | – | – |
| [Core Image](https://developer.apple.com/documentation/coreimage) | 5.0 | ✅ | 95.3% | 15: 8 ✅ 5 🟡 1 🧩 1 ❌ | [CoreImage](frameworks/CoreImage.md) |
| [Core ML](https://developer.apple.com/documentation/coreml) | 11.0 | ✅ | 24.9% | 5: 2 ✅ 1 🟡 2 ❌ | [CoreML](frameworks/CoreML.md) |
| [Core Transferable](https://developer.apple.com/documentation/coretransferable) | 16.0 | ✅ | 70.8% | 1: 1 ❌ | [CoreTransferable](frameworks/CoreTransferable.md) |
| [Create ML](https://developer.apple.com/documentation/createml) | 15.0 | ❌ | 0.0%* | – | – |
| [Create ML Components](https://developer.apple.com/documentation/createmlcomponents) | 16.0 | ❌ | 0.0%* | – | – |
| [DataDetection](https://developer.apple.com/documentation/datadetection) | 15.0 | ❌ | 0.0%* | – | – |
| [Evaluations](https://developer.apple.com/documentation/evaluations) | 27.0 | ❌ | 0.0%* | – | – |
| [Foundation Models](https://developer.apple.com/documentation/foundationmodels) | 26.0 | ❌ | 0.0%* | – | – |
| [ImageCaptureCore](https://developer.apple.com/documentation/imagecapturecore) | 13.0 | ❌ | 0.0%* | – | – |
| [Image Playground](https://developer.apple.com/documentation/imageplayground) | 18.1 | ❌ | 0.0%* | – | – |
| [LockedCameraCapture](https://developer.apple.com/documentation/lockedcameracapture) | 18.0 | ❌ | 0.0%* | – | – |
| [Media Intelligence](https://developer.apple.com/documentation/mediaintelligence) | 27.0 | ❌ | 0.0%* | – | – |
| [ML Compute](https://developer.apple.com/documentation/mlcompute) | 14.0 | ❌ | 0.0%* | – | – |
| [Music Understanding](https://developer.apple.com/documentation/musicunderstanding) | 27.0 | ❌ | 0.0%* | – | – |
| [Natural Language](https://developer.apple.com/documentation/naturallanguage) | 12.0 | ✅ | 57.5% | 3: 2 🟡 1 ❌ | [NaturalLanguage](frameworks/NaturalLanguage.md) |
| [PhotoKit](https://developer.apple.com/documentation/photokit) | 8.0 | ✅ | 41.4% | 5: 1 ✅ 1 🟡 3 ❌ | [Photos](frameworks/Photos.md) |
| [PhotosUI](https://developer.apple.com/documentation/photokit) | 8.0 | ✅ | 54.1% | 3: 1 🟡 2 ❌ | [PhotosUI](frameworks/PhotosUI.md) |
| [Sensitive Content Analysis](https://developer.apple.com/documentation/sensitivecontentanalysis) | 17.0 | ❌ | 0.0%* | – | – |
| [Sound Analysis](https://developer.apple.com/documentation/soundanalysis) | 13.0 | ❌ | 0.0%* | – | – |
| [Spatial](https://developer.apple.com/documentation/spatial) | 16.0 | ✅ | 2.6% | 3: 3 ❌ | [Spatial](frameworks/Spatial.md) |
| [Speech](https://developer.apple.com/documentation/speech) | 10.0 | ✅ | 24.9% | 4: 1 🟡 3 ❌ | [Speech](frameworks/Speech.md) |
| [TabularData](https://developer.apple.com/documentation/tabulardata) | 15.0 | ❌ | 0.0%* | – | – |
| [Translation](https://developer.apple.com/documentation/translation) | 17.4 | ❌ | 0.0%* | – | – |
| [TranslationUIProvider](https://developer.apple.com/documentation/translationuiprovider) | 18.4 | ❌ | 0.0%* | – | – |
| [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers) | 14.0 | ✅ | 38.2% | 2: 1 🟡 1 ❌ | [UniformTypeIdentifiers](frameworks/UniformTypeIdentifiers.md) |
| [Vision](https://developer.apple.com/documentation/vision) | None | ✅ | 5.4% | 8: 1 ✅ 2 🟡 1 🧩 4 ❌ | [Vision](frameworks/Vision.md) |
| [VisionKit](https://developer.apple.com/documentation/visionkit) | 13.0 | ✅ | 52.5% | 2: 1 🧩 1 ❌ | [VisionKit](frameworks/VisionKit.md) |
| [Visual Intelligence](https://developer.apple.com/documentation/visualintelligence) | 26.0 | ❌ | 0.0%* | – | – |

### Media

<a id="media"></a>Issues: [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [AudioAccessoryKit](https://developer.apple.com/documentation/audioaccessorykit) | 26.4 | ❌ | 0.0%* | – | – |
| [Audio Toolbox](https://developer.apple.com/documentation/audiotoolbox) | 2.0 | ✅ | 17.8% | 9: 7 ✅ 2 ❌ | [AudioToolbox](frameworks/AudioToolbox.md) |
| [Audio Unit](https://developer.apple.com/documentation/audiounit) | 2.0 | ✅ | 0.0% | 2: 1 ✅ 1 🟡 | [AudioUnit](frameworks/AudioUnit.md) |
| [AVFAudio](https://developer.apple.com/documentation/avfaudio) | 14.5 | ✅ | 51.4% | 4: 2 ✅ 2 ❌ | [AVFAudio](frameworks/AVFAudio.md) |
| [AVFoundation](https://developer.apple.com/documentation/avfoundation) | 2.2 | ✅ | 30.2% | 35: 30 ✅ 1 🟡 4 ❌ | [AVFoundation](frameworks/AVFoundation.md) |
| [AVKit](https://developer.apple.com/documentation/avkit) | 8.0 | ✅ | 30.5% | 6: 2 ✅ 1 🟡 3 ❌ | [AVKit](frameworks/AVKit.md) |
| [AVRouting](https://developer.apple.com/documentation/avrouting) | 16.0 | ❌ | 0.0%* | – | – |
| [AVSystemRouting](https://developer.apple.com/documentation/avsystemrouting) | 27.0 | ❌ | 0.0%* | – | – |
| [Cinematic](https://developer.apple.com/documentation/cinematic) | 17.0 | ❌ | 0.0%* | – | – |
| [Core Audio](https://developer.apple.com/documentation/coreaudio) | 2.0 | ✅ | 12.5% | 2: 2 ✅ | [CoreAudio](frameworks/CoreAudio.md) |
| [CoreAudioKit](https://developer.apple.com/documentation/coreaudiokit) | 8.0 | ❌ | 0.0%* | – | – |
| [Core Audio Types](https://developer.apple.com/documentation/coreaudiotypes) | 13.0 | ✅ | 7.1% | 1: 1 ❌ | [CoreAudioTypes](frameworks/CoreAudioTypes.md) |
| [Core Haptics](https://developer.apple.com/documentation/corehaptics) | 13.0 | ✅ | 67.2% | – | [CoreHaptics](frameworks/CoreHaptics.md) |
| [Core Media](https://developer.apple.com/documentation/coremedia) | 4.0 | ✅ | 14.3% | 6: 2 ✅ 1 🟡 3 ❌ | [CoreMedia](frameworks/CoreMedia.md) |
| [Core MIDI](https://developer.apple.com/documentation/coremidi) | 4.2 | ❌ | 0.0%* | – | – |
| [Media Accessibility](https://developer.apple.com/documentation/mediaaccessibility) | 17.0 | ❌ | 0.0%* | – | – |
| [Media Device](https://developer.apple.com/documentation/mediadevice) | 27.0 | ❌ | 0.0%* | – | – |
| [Media Intents](https://developer.apple.com/documentation/mediaintents) | 27.0 | ❌ | 0.0%* | – | – |
| [Media Player](https://developer.apple.com/documentation/mediaplayer) | 2.0 | ✅ | 69.0% | 7: 3 ✅ 1 🟡 3 ❌ | [MediaPlayer](frameworks/MediaPlayer.md) |
| [Media Toolbox](https://developer.apple.com/documentation/mediatoolbox) | 6.0 | ❌ | 0.0%* | – | – |
| [MusicKit](https://developer.apple.com/documentation/musickit) | 15.0 | ✅ | 26.3% | 3: 3 ❌ | [MusicKit](frameworks/MusicKit.md) |
| [Now Playing](https://developer.apple.com/documentation/nowplaying) | 27.0 | ❌ | 0.0%* | – | – |
| [PHASE](https://developer.apple.com/documentation/phase) | 15.0 | ❌ | 0.0%* | – | – |
| [ReplayKit](https://developer.apple.com/documentation/replaykit) | 9.0 | ❌ | 0.0%* | – | – |
| [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) | 27.0 | ❌ | 0.0%* | – | – |
| [ShazamKit](https://developer.apple.com/documentation/shazamkit) | 15.0 | ❌ | 0.0%* | – | – |
| [Video Toolbox](https://developer.apple.com/documentation/videotoolbox) | 6.0 | ❌ | 0.0%* | – | – |

### Games & 3D

<a id="games"></a>Issues: [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [ARKit](https://developer.apple.com/documentation/arkit) | 11.0 | ✅ | 0.0%* | 1: 1 ❌ | [ARKit](frameworks/ARKit.md) |
| [Game Controller](https://developer.apple.com/documentation/gamecontroller) | 7.0 | ✅ | 31.5% | 10: 4 ✅ 1 🟡 5 ❌ | [GameController](frameworks/GameController.md) |
| [GameKit](https://developer.apple.com/documentation/gamekit) | 3.0 | ✅ | 71.0% | 20: 15 ✅ 3 🟡 2 ❌ | [GameKit](frameworks/GameKit.md) |
| [GameplayKit](https://developer.apple.com/documentation/gameplaykit) | 9.0 | ✅ | 91.2% | 18: 10 ✅ 7 🟡 1 ❌ | [GameplayKit](frameworks/GameplayKit.md) |
| [GameSave](https://developer.apple.com/documentation/gamesave) | 26.0 | ❌ | 0.0%* | – | – |
| [Group Activities](https://developer.apple.com/documentation/groupactivities) | 15.0 | ❌ | 0.0%* | – | – |
| [Model I/O](https://developer.apple.com/documentation/modelio) | 9.0 | ❌ | 0.0%* | – | – |
| [RealityKit](https://developer.apple.com/documentation/realitykit) | 13.0 | ✅ | 0.0%* | 1: 1 ❌ | [RealityKit](frameworks/RealityKit.md) |
| [RoomPlan](https://developer.apple.com/documentation/roomplan) | 16.0 | ❌ | 0.0%* | – | – |
| [SceneKit](https://developer.apple.com/documentation/scenekit) | 8.0 | ✅ | 0.0%* | 1: 1 ❌ | [SceneKit](frameworks/SceneKit.md) |
| [SpriteKit](https://developer.apple.com/documentation/spritekit) | 7.0 | ✅ | 96.0% | 49: 42 ✅ 5 🟡 2 ❌ | [SpriteKit](frameworks/SpriteKit.md) |
| [Touch Controller](https://developer.apple.com/documentation/touchcontroller) | 26.0 | ❌ | 0.0%* | – | – |
| [USDKit](https://developer.apple.com/documentation/usdkit) | 27.0 | ❌ | 0.0%* | – | – |

### Commerce & privacy

<a id="commerce"></a>Issues: [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [AdAttributionKit](https://developer.apple.com/documentation/adattributionkit) | 17.4 | ✅ | 100.0% | 1: 1 ✅ | [AdAttributionKit](frameworks/AdAttributionKit.md) |
| [AdServices](https://developer.apple.com/documentation/adservices) | 14.3 | ✅ | 100.0% | 1: 1 ✅ | [AdServices](frameworks/AdServices.md) |
| [AdSupport](https://developer.apple.com/documentation/adsupport) | 6.0 | ✅ | 100.0% | 1: 1 ✅ | [AdSupport](frameworks/AdSupport.md) |
| [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency) | 14.0 | ✅ | 100.0% | 1: 1 ✅ | [AppTrackingTransparency](frameworks/AppTrackingTransparency.md) |
| [Declared Age Range](https://developer.apple.com/documentation/declaredagerange) | 26.0 | ❌ | 0.0%* | – | – |
| [FinanceKit](https://developer.apple.com/documentation/financekit) | 17.0 | ❌ | 0.0%* | – | – |
| [FinanceKitUI](https://developer.apple.com/documentation/financekitui) | 17.0 | ❌ | 0.0%* | – | – |
| [ManagedAppDistribution](https://developer.apple.com/documentation/managedappdistribution) | 17.2 | ❌ | 0.0%* | – | – |
| [MarketplaceKit](https://developer.apple.com/documentation/marketplacekit) | 17.4 | ✅ | 7.6% | 3: 1 🟡 2 ❌ | [MarketplaceKit](frameworks/MarketplaceKit.md) |
| [PassKit (Apple Pay and Wallet)](https://developer.apple.com/documentation/passkit) | 6.0 | ❌ | 0.0%* | – | – |
| [PermissionKit](https://developer.apple.com/documentation/permissionkit) | 26.0 | ❌ | 0.0%* | – | – |
| [StoreKit](https://developer.apple.com/documentation/storekit) | 3.0 | ✅ | 52.7% | 35: 31 ✅ 4 ❌ | [StoreKit](frameworks/StoreKit.md) |
| [Wallet Orders](https://developer.apple.com/documentation/walletorders) | 16.0 | ❌ | – | – | – |
| [Wallet Passes](https://developer.apple.com/documentation/walletpasses) | 6.0 | ❌ | – | – | – |

### Data & persistence

<a id="data"></a>Issues: [`area:data`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adata)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [CloudKit](https://developer.apple.com/documentation/cloudkit) | 8.0 | ✅ | 48.9% | 8: 5 ✅ 1 🟡 2 ❌ | [CloudKit](frameworks/CloudKit.md) |
| [Core Data](https://developer.apple.com/documentation/coredata) | 3.0 | ✅ | 67.3% | 14: 11 ✅ 2 🟡 1 ❌ | [CoreData](frameworks/CoreData.md) |
| [SwiftData](https://developer.apple.com/documentation/swiftdata) | 17.0 | ✅ | 24.6% | 4: 1 🟡 3 ❌ | [SwiftData](frameworks/SwiftData.md) |

### Identity & security

<a id="security"></a>Issues: [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Authentication Services](https://developer.apple.com/documentation/authenticationservices) | 12.0 | ✅ | 17.6% | 8: 4 ✅ 4 ❌ | [AuthenticationServices](frameworks/AuthenticationServices.md) |
| [CarKey](https://developer.apple.com/documentation/carkey) | 16.0 | ❌ | 0.0%* | – | – |
| [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit) | 13.0 | ✅ | 71.8% | 7: 3 ✅ 4 ❌ | [CryptoKit](frameworks/CryptoKit.md) |
| [CryptoTokenKit](https://developer.apple.com/documentation/cryptotokenkit) | 13.0 | ❌ | 0.0%* | – | – |
| [DeviceCheck](https://developer.apple.com/documentation/devicecheck) | 11.0 | ✅ | 100.0% | 1: 1 ✅ | [DeviceCheck](frameworks/DeviceCheck.md) |
| [GSS](https://developer.apple.com/documentation/gss) | 5.0 | ❌ | 0.0%* | – | – |
| [IdentityDocumentServices](https://developer.apple.com/documentation/identitydocumentservices) | 26.0 | ❌ | 0.0%* | – | – |
| [IdentityDocumentServicesUI](https://developer.apple.com/documentation/identitydocumentservicesui) | 26.0 | ❌ | 0.0%* | – | – |
| [LightweightCodeRequirements](https://developer.apple.com/documentation/lightweightcoderequirements) | 17.4 | ❌ | 0.0%* | – | – |
| [Local Authentication](https://developer.apple.com/documentation/localauthentication) | 8.0 | ✅ | 30.0% | 3: 1 ✅ 2 ❌ | [LocalAuthentication](frameworks/LocalAuthentication.md) |
| [Local Authentication Embedded UI](https://developer.apple.com/documentation/localauthenticationembeddedui) | 16.0 | ❌ | 0.0%* | – | – |
| [Security](https://developer.apple.com/documentation/security) | 2.0 | ✅ | 25.9% | 10: 8 ✅ 1 🟡 1 ❌ | [Security](frameworks/Security.md) |
| [ServicesAccountLinking](https://developer.apple.com/documentation/servicesaccountlinking) | 16.4 | ❌ | 0.0%* | – | – |
| [Trust Insights](https://developer.apple.com/documentation/trustinsights) | 27.0 | ❌ | 0.0%* | – | – |

### App extensions & system integration

<a id="system"></a>Issues: [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Accessory Live Activities](https://developer.apple.com/documentation/accessoryliveactivities) | 26.5 | ❌ | 0.0%* | – | – |
| [Accessory Notifications](https://developer.apple.com/documentation/accessorynotifications) | 26.5 | ❌ | 0.0%* | – | – |
| [Accessory Transport Extension](https://developer.apple.com/documentation/accessorytransportextension) | 26.2 | ❌ | 0.0%* | – | – |
| [ActivityKit](https://developer.apple.com/documentation/activitykit) | 16.1 | ✅ | 56.0% | 1: 1 ✅ | [ActivityKit](frameworks/ActivityKit.md) |
| [AlarmKit](https://developer.apple.com/documentation/alarmkit) | 26.0 | ❌ | 0.0%* | – | – |
| [App Clips](https://developer.apple.com/documentation/appclip) | 14.0 | ✅ | 100.0% | 1: 1 ✅ | [AppClip](frameworks/AppClip.md) |
| [App Intents](https://developer.apple.com/documentation/appintents) | 16.0 | ✅ | 39.6% | 14: 5 ✅ 5 🟡 4 ❌ | [AppIntents](frameworks/AppIntents.md) |
| [AppMigrationKit](https://developer.apple.com/documentation/appmigrationkit) | 26.1 | ❌ | 0.0%* | – | – |
| [Assignables](https://developer.apple.com/documentation/assignables) | 15.4 | ❌ | 0.0%* | – | – |
| [Automated Device Enrollment](https://developer.apple.com/documentation/automateddeviceenrollment) | 16.1 | ❌ | – | – | – |
| [Automatic Assessment Configuration](https://developer.apple.com/documentation/automaticassessmentconfiguration) | 13.4 | ❌ | 0.0%* | – | – |
| [Background Assets](https://developer.apple.com/documentation/backgroundassets) | 16.0 | ❌ | 0.0%* | – | – |
| [Background Tasks](https://developer.apple.com/documentation/backgroundtasks) | 13.0 | ✅ | 58.7% | 6: 4 ✅ 2 ❌ | [BackgroundTasks](frameworks/BackgroundTasks.md) |
| [BrowserEngineCore](https://developer.apple.com/documentation/browserenginecore) | 17.4 | ❌ | 0.0%* | – | – |
| [BrowserEngineKit](https://developer.apple.com/documentation/browserenginekit) | 17.4 | ❌ | 0.0%* | – | – |
| [BrowserKit](https://developer.apple.com/documentation/browserkit) | 18.4 | ❌ | 0.0%* | – | – |
| [CallKit](https://developer.apple.com/documentation/callkit) | 10.0 | ✅ | 80.6% | 4: 2 ✅ 2 ❌ | [CallKit](frameworks/CallKit.md) |
| [CarPlay](https://developer.apple.com/documentation/carplay) | 12.0 | ❌ | 0.0%* | – | – |
| [ClassKit](https://developer.apple.com/documentation/classkit) | 11.4 | ❌ | 0.0%* | – | – |
| [ContactProvider](https://developer.apple.com/documentation/contactprovider) | 18.0 | ❌ | 0.0%* | – | – |
| [Core Spotlight](https://developer.apple.com/documentation/corespotlight) | 9.0 | ✅ | 8.9% | 4: 1 ✅ 1 🟡 2 ❌ | [CoreSpotlight](frameworks/CoreSpotlight.md) |
| [Device Activity](https://developer.apple.com/documentation/deviceactivity) | 15.0 | ❌ | 0.0%* | – | – |
| [DeviceDiscoveryExtension](https://developer.apple.com/documentation/devicediscoveryextension) | 16.0 | ❌ | 0.0%* | – | – |
| [DeviceDiscoveryUI](https://developer.apple.com/documentation/devicediscoveryui) | 26.0 | ❌ | 0.0%* | – | – |
| [Device Management](https://developer.apple.com/documentation/devicemanagement) | 13.0 | ❌ | – | – | – |
| [EnergyKit](https://developer.apple.com/documentation/energykit) | 26.0 | ❌ | 0.0%* | – | – |
| [ExtensionFoundation](https://developer.apple.com/documentation/extensionfoundation) | 16.0 | ❌ | 0.0%* | – | – |
| [ExtensionKit](https://developer.apple.com/documentation/extensionkit) | 16.1 | ❌ | 0.0%* | – | – |
| [Family Controls](https://developer.apple.com/documentation/familycontrols) | 15.0 | ❌ | 0.0%* | – | – |
| [File Provider](https://developer.apple.com/documentation/fileprovider) | 11.0 | ❌ | 0.0%* | – | – |
| [File Provider UI](https://developer.apple.com/documentation/fileproviderui) | 11.0 | ❌ | 0.0%* | – | – |
| [SMS and Call Reporting](https://developer.apple.com/documentation/identitylookup) | 11.0 | ❌ | 0.0%* | – | – |
| [SiriKit](https://developer.apple.com/documentation/sirikit) | 10.0 | ✅ | 25.1% | 4: 2 ✅ 2 ❌ | [Intents](frameworks/Intents.md) |
| [IntentsUI](https://developer.apple.com/documentation/sirikit) | 10.0 | ✅ | 95.8% | – | [IntentsUI](frameworks/IntentsUI.md) |
| [Journaling Suggestions](https://developer.apple.com/documentation/journalingsuggestions) | 17.2 | ❌ | 0.0%* | – | – |
| [LiveCommunicationKit](https://developer.apple.com/documentation/livecommunicationkit) | 17.4 | ❌ | 0.0%* | – | – |
| [ManagedApp](https://developer.apple.com/documentation/managedapp) | 18.4 | ❌ | 0.0%* | – | – |
| [Managed Settings](https://developer.apple.com/documentation/managedsettings) | 15.0 | ❌ | 0.0%* | – | – |
| [Managed Settings UI](https://developer.apple.com/documentation/managedsettingsui) | 15.0 | ❌ | 0.0%* | – | – |
| [Media Setup](https://developer.apple.com/documentation/mediasetup) | 14.0 | ❌ | 0.0%* | – | – |
| [Messages](https://developer.apple.com/documentation/messages) | 10.0 | ❌ | 0.0%* | – | – |
| [PushKit](https://developer.apple.com/documentation/pushkit) | 8.0 | ✅ | 93.3% | 3: 2 ✅ 1 ❌ | [PushKit](frameworks/PushKit.md) |
| [Push to Talk](https://developer.apple.com/documentation/pushtotalk) | 16.0 | ❌ | 0.0%* | – | – |
| [RelevanceKit](https://developer.apple.com/documentation/relevancekit) | 26.0 | ❌ | 0.0%* | – | – |
| [SafetyKit](https://developer.apple.com/documentation/safetykit) | 16.0 | ❌ | 0.0%* | – | – |
| [Screen Time](https://developer.apple.com/documentation/screentime) | 14.0 | ❌ | 0.0%* | – | – |
| [Shared with You](https://developer.apple.com/documentation/sharedwithyou) | 16.0 | ❌ | 0.0%* | – | – |
| [Suggested Actions](https://developer.apple.com/documentation/suggestedactions) | 27.0 | ❌ | 0.0%* | – | – |
| [TelephonyMessagingKit](https://developer.apple.com/documentation/telephonymessagingkit) | 26.0 | ❌ | 0.0%* | – | – |
| [TipKit](https://developer.apple.com/documentation/tipkit) | 17.0 | ❌ | 0.0%* | – | – |
| [User Notifications](https://developer.apple.com/documentation/usernotifications) | 10.0 | ✅ | 82.1% | 10: 8 ✅ 2 ❌ | [UserNotifications](frameworks/UserNotifications.md) |
| [User Notifications UI](https://developer.apple.com/documentation/usernotificationsui) | 10.0 | ✅ | 100.0% | – | [UserNotificationsUI](frameworks/UserNotificationsUI.md) |
| [Video Subscriber Account](https://developer.apple.com/documentation/videosubscriberaccount) | 10.0 | ❌ | 0.0%* | – | – |
| [WidgetKit](https://developer.apple.com/documentation/widgetkit) | 14.0 | ✅ | 55.5% | 5: 1 ✅ 1 🟡 3 ❌ | [WidgetKit](frameworks/WidgetKit.md) |

### Location, personal data & sensors

<a id="location"></a>Issues: [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit) | 18.0 | ❌ | 0.0%* | – | – |
| [Contacts](https://developer.apple.com/documentation/contacts) | 9.0 | ✅ | 43.6% | 4: 2 ✅ 1 🟡 1 ❌ | [Contacts](frameworks/Contacts.md) |
| [Contacts UI](https://developer.apple.com/documentation/contactsui) | 9.0 | ✅ | 79.2% | 2: 1 ✅ 1 ❌ | [ContactsUI](frameworks/ContactsUI.md) |
| [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) | 5.0 | ✅ | 42.4% | 3: 1 🟡 2 ❌ | [CoreBluetooth](frameworks/CoreBluetooth.md) |
| [Core Location](https://developer.apple.com/documentation/corelocation) | 2.0 | ✅ | 84.3% | 5: 3 ✅ 2 ❌ | [CoreLocation](frameworks/CoreLocation.md) |
| [CoreLocationUI](https://developer.apple.com/documentation/corelocationui) | 15.0 | ❌ | 0.0%* | – | – |
| [Core Motion](https://developer.apple.com/documentation/coremotion) | 4.0 | ✅ | 54.8% | 4: 1 ✅ 3 ❌ | [CoreMotion](frameworks/CoreMotion.md) |
| [Core NFC](https://developer.apple.com/documentation/corenfc) | 11.0 | ✅ | 24.0% | 3: 1 🟡 2 ❌ | [CoreNFC](frameworks/CoreNFC.md) |
| [DockKit](https://developer.apple.com/documentation/dockkit) | 17.0 | ❌ | 0.0%* | – | – |
| [DriverKit](https://developer.apple.com/documentation/driverkit) | 16.0 | ❌ | 0.0%* | – | – |
| [EventKit](https://developer.apple.com/documentation/eventkit) | 4.0 | ✅ | 58.2% | 3: 1 ✅ 1 🟡 1 ❌ | [EventKit](frameworks/EventKit.md) |
| [EventKit UI](https://developer.apple.com/documentation/eventkitui) | 4.0 | ✅ | 53.1% | 2: 1 ✅ 1 ❌ | [EventKitUI](frameworks/EventKitUI.md) |
| [Exposure Notification](https://developer.apple.com/documentation/exposurenotification) | 13.5 | ❌ | 0.0%* | – | – |
| [External Accessory](https://developer.apple.com/documentation/externalaccessory) | 3.0 | ❌ | 0.0%* | – | – |
| [GeoToolbox](https://developer.apple.com/documentation/geotoolbox) | 26.0 | ❌ | 0.0%* | – | – |
| [HealthKit](https://developer.apple.com/documentation/healthkit) | 8.0 | ✅ | 15.8% | 5: 1 🟡 4 ❌ | [HealthKit](frameworks/HealthKit.md) |
| [HomeKit](https://developer.apple.com/documentation/homekit) | 8.0 | ❌ | 0.0%* | – | – |
| [hvf](https://developer.apple.com/documentation/hvf) | 18.4 | ❌ | 0.0%* | – | – |
| [IOKit](https://developer.apple.com/documentation/iokit) | 16.0 | ❌ | 0.0%* | – | – |
| [MapKit](https://developer.apple.com/documentation/mapkit) | 3.0 | ✅ | 67.4% | 9: 5 ✅ 1 🟡 3 ❌ | [MapKit](frameworks/MapKit.md) |
| [Matter](https://developer.apple.com/documentation/matter) | 16.0 | ❌ | 0.0%* | – | – |
| [MatterSupport](https://developer.apple.com/documentation/mattersupport) | 16.1 | ❌ | 0.0%* | – | – |
| [Nearby Interaction](https://developer.apple.com/documentation/nearbyinteraction) | 14.0 | ❌ | 0.0%* | – | – |
| [SensorKit](https://developer.apple.com/documentation/sensorkit) | 14.0 | ❌ | 0.0%* | – | – |
| [ThreadNetwork](https://developer.apple.com/documentation/threadnetwork) | 15.0 | ❌ | 0.0%* | – | – |
| [WeatherKit](https://developer.apple.com/documentation/weatherkit) | 16.0 | ❌ | 0.0%* | – | – |
| [Wi-Fi Aware](https://developer.apple.com/documentation/wifiaware) | 26.0 | ❌ | 0.0%* | – | – |
| [Wi-Fi Infrastructure](https://developer.apple.com/documentation/wifiinfrastructure) | 26.2 | ❌ | 0.0%* | – | – |
| [WirelessInsights](https://developer.apple.com/documentation/wirelessinsights) | 26.0 | ❌ | 0.0%* | – | – |
| [WorkoutKit](https://developer.apple.com/documentation/workoutkit) | 17.0 | ❌ | 0.0%* | – | – |

### Web, network & communication

<a id="web"></a>Issues: [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Core Telephony](https://developer.apple.com/documentation/coretelephony) | 4.0 | ✅ | 18.1% | 3: 3 ❌ | [CoreTelephony](frameworks/CoreTelephony.md) |
| [dnssd](https://developer.apple.com/documentation/dnssd) | 10.0 | ❌ | 0.0%* | – | – |
| [Link Presentation](https://developer.apple.com/documentation/linkpresentation) | 13.0 | ❌ | 0.0%* | – | – |
| [Message UI](https://developer.apple.com/documentation/messageui) | 3.0 | ✅ | 66.3% | 2: 1 ✅ 1 ❌ | [MessageUI](frameworks/MessageUI.md) |
| [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity) | 7.0 | ✅ | 94.7% | 2: 2 ✅ | [MultipeerConnectivity](frameworks/MultipeerConnectivity.md) |
| [Network](https://developer.apple.com/documentation/network) | 12.0 | ✅ | 23.5% | 9: 5 ✅ 1 🧩 3 ❌ | [Network](frameworks/Network.md) |
| [Network Extension](https://developer.apple.com/documentation/networkextension) | 8.0 | ❌ | 0.0%* | – | – |
| [Safari Services](https://developer.apple.com/documentation/safariservices) | 7.0 | ✅ | 34.8% | 4: 2 ✅ 2 ❌ | [SafariServices](frameworks/SafariServices.md) |
| [Social](https://developer.apple.com/documentation/social) | 6.0 | ✅ | 42.9% | 1: 1 ❌ | [Social](frameworks/Social.md) |
| [System Configuration](https://developer.apple.com/documentation/systemconfiguration) | 2.0 | ✅ | 20.4% | 2: 1 ✅ 1 ❌ | [SystemConfiguration](frameworks/SystemConfiguration.md) |
| [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity) | 9.0 | ❌ | 0.0%* | – | – |
| [WebKit](https://developer.apple.com/documentation/webkit) | 16.0 | ✅ | 35.3% | 10: 6 ✅ 4 ❌ | [WebKit](frameworks/WebKit.md) |

### Accessibility & Info.plist

<a id="a11y"></a>Issues: [`area:a11y`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aa11y)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---|---|
| [Accessibility](https://developer.apple.com/documentation/accessibility) | 14.0 | ❌ | 0.0%* | – | – |
| [Bundle Resources](https://developer.apple.com/documentation/bundleresources) | 2.0 | ✅ | 0.0%* | 16: 9 ✅ 1 🟡 6 ❌ | [BundleResources](frameworks/BundleResources.md) |

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
| ActivityKit | ❌ Swift only |
| AdAttributionKit | ❌ Swift only |
| AdServices | ❌ Swift only |
| AdSupport | ✅ headers in isim/sdk-src/Frameworks/AdSupport |
| AppClip | ❌ Swift only |
| AppIntents | ❌ Swift only |
| AppTrackingTransparency | ✅ headers in isim/sdk-src/Frameworks/AppTrackingTransparency |
| AudioToolbox | ❌ Swift only |
| AudioUnit | ✅ headers in isim/sdk-src/Frameworks/AudioUnit |
| AuthenticationServices | ❌ Swift only |
| AVFAudio | ✅ headers in isim/sdk-src/Frameworks/AVFAudio |
| AVFoundation | ✅ headers in isim/sdk-src/Frameworks/AVFoundation |
| AVKit | ❌ Swift only |
| BackgroundTasks | ✅ headers in isim/sdk-src/Frameworks/BackgroundTasks |
| CallKit | ✅ headers in isim/sdk-src/Frameworks/CallKit |
| Charts | ❌ Swift only |
| CloudKit | ❌ Swift only |
| Combine | ❌ Swift only |
| Contacts | ✅ headers in isim/sdk-src/Frameworks/Contacts |
| ContactsUI | ✅ headers in isim/sdk-src/Frameworks/ContactsUI |
| CoreAudio | ✅ headers in isim/sdk-src/Frameworks/CoreAudio |
| CoreAudioTypes | ❌ Swift only |
| CoreBluetooth | ❌ Swift only |
| CoreData | ✅ headers in isim/sdk-src/Frameworks/CoreData |
| CoreFoundation | ✅ headers in isim/sdk-src/Frameworks/CoreFoundation |
| CoreGraphics | ✅ headers in isim/sdk-src/Frameworks/CoreGraphics |
| CoreHaptics | ❌ Swift only |
| CoreImage | ✅ headers in isim/sdk-src/Frameworks/CoreImage |
| CoreLocation | ✅ headers in isim/sdk-src/Frameworks/CoreLocation |
| CoreMedia | ✅ headers in isim/sdk-src/Frameworks/CoreMedia |
| CoreML | ❌ Swift only |
| CoreMotion | ✅ headers in isim/sdk-src/Frameworks/CoreMotion |
| CoreNFC | ❌ Swift only |
| CoreSpotlight | ✅ headers in isim/sdk-src/Frameworks/CoreSpotlight |
| CoreTelephony | ✅ headers in isim/sdk-src/Frameworks/CoreTelephony |
| CoreText | ✅ headers in isim/sdk-src/Frameworks/CoreText |
| CoreTransferable | ❌ Swift only |
| CoreVideo | ✅ headers in isim/sdk-src/Frameworks/CoreVideo |
| CryptoKit | ❌ Swift only |
| DeveloperToolsSupport | ❌ Swift only |
| DeviceCheck | ❌ Swift only |
| Dispatch | ❌ Swift only |
| Distributed | ❌ Swift only |
| EventKit | ✅ headers in isim/sdk-src/Frameworks/EventKit |
| EventKitUI | ✅ headers in isim/sdk-src/Frameworks/EventKitUI |
| Foundation | ✅ headers in isim/sdk-src/Frameworks/Foundation |
| GameController | ❌ Swift only |
| GameKit | ❌ Swift only |
| GameplayKit | ❌ Swift only |
| HealthKit | ❌ Swift only |
| ImageIO | ✅ headers in isim/sdk-src/Frameworks/ImageIO |
| Intents | ✅ headers in isim/sdk-src/Frameworks/Intents |
| IntentsUI | ✅ headers in isim/sdk-src/Frameworks/IntentsUI |
| JavaScriptCore | ✅ headers in isim/sdk-src/Frameworks/JavaScriptCore |
| LocalAuthentication | ❌ Swift only |
| MapKit | ✅ headers in isim/sdk-src/Frameworks/MapKit |
| MarketplaceKit | ✅ headers in isim/sdk-src/Frameworks/MarketplaceKit |
| MediaPlayer | ❌ Swift only |
| MessageUI | ✅ headers in isim/sdk-src/Frameworks/MessageUI |
| MetricKit | ❌ Swift only |
| MultipeerConnectivity | ✅ headers in isim/sdk-src/Frameworks/MultipeerConnectivity |
| MusicKit | ❌ Swift only |
| NaturalLanguage | ❌ Swift only |
| Network | ✅ headers in isim/sdk-src/Frameworks/Network |
| ObjectiveC | ❌ Swift only |
| Observation | ❌ Swift only |
| os | ❌ Swift only |
| OSLog | ❌ Swift only |
| Photos | ❌ Swift only |
| PhotosUI | ❌ Swift only |
| PushKit | ✅ headers in isim/sdk-src/Frameworks/PushKit |
| QuartzCore | ✅ headers in isim/sdk-src/Frameworks/QuartzCore |
| QuickLook | ✅ headers in isim/sdk-src/Frameworks/QuickLook |
| RegexBuilder | ❌ Swift only |
| SafariServices | ✅ headers in isim/sdk-src/Frameworks/SafariServices |
| Security | ✅ headers in isim/sdk-src/Frameworks/Security |
| simd | ❌ Swift only |
| Social | ✅ headers in isim/sdk-src/Frameworks/Social |
| Spatial | ❌ Swift only |
| Speech | ❌ Swift only |
| SpriteKit | ❌ Swift only |
| StoreKit | ✅ headers in isim/sdk-src/Frameworks/StoreKit |
| Swift | ❌ Swift only |
| SwiftData | ❌ Swift only |
| SwiftUI | ❌ Swift only |
| Symbols | ❌ Swift only |
| Synchronization | ❌ Swift only |
| SystemConfiguration | ✅ headers in isim/sdk-src/Frameworks/SystemConfiguration |
| Testing | ❌ Swift only |
| UIKit | ✅ headers in isim/sdk-src/Frameworks/UIKit |
| UniformTypeIdentifiers | ❌ Swift only |
| UserNotifications | ✅ headers in isim/sdk-src/Frameworks/UserNotifications |
| UserNotificationsUI | ✅ headers in isim/sdk-src/Frameworks/UserNotificationsUI |
| Vision | ❌ Swift only |
| VisionKit | ❌ Swift only |
| WebKit | ✅ headers in isim/sdk-src/Frameworks/WebKit |
| WidgetKit | ❌ Swift only |
| XCTest | ✅ headers in isim/sdk-src/Frameworks/XCTest |
<!-- /generated:objc -->
