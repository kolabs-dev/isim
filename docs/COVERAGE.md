# isim API coverage

How much of the iOS SDK isim implements, for iOS 17, 18, 26 and 27 (selected with `--os`). The goal is all of it: any
iOS app should build and run on isim. This page is the index. Each framework isim implements has its own page in
[frameworks/](frameworks/), with how isim implements it, a row per API with its status, and the list of Apple symbols
it still lacks.

**What the numbers mean**

- **Symbols:** the share of the symbols Apple documents for iOS (types, functions, constants, members) that isim's SDK has.
  - Measured by [`isim/tools/api-coverage.py`](../isim/tools/api-coverage.py) against a snapshot of Apple's
    documentation ([API-SWEEP.md](API-SWEEP.md)).
  - *Exact* compares the symbol graphs of isim's built SDK with Apple's documentation paths. *By name* (marked \*)
    only checks that the name occurs in isim's sources, so it is a lower bound on what is missing.
  - A symbol that exists can still do nothing; the rows say how well it works.
- **Rows:** hand-written rows on the framework pages, one per API or feature: (✅ + 0.5 × 🟡) / rows.
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
| Area | Symbols | Rows | ✅ | 🟡 | 🧩 | ❌ | ⛔ | Frameworks in isim |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| [UIKit](#uikit) | 92% | 99% | 304 | 7 | 0 | 1 | 0 | 2 of 2 |
| [SwiftUI & Charts](#swiftui) | 60% | 98% | 248 | 7 | 0 | 2 | 0 | 2 of 2 |
| [Developer tools](#devtools) | 20% | 87% | 46 | 7 | 0 | 4 | 0 | 3 of 6 |
| [Foundation & CoreFoundation](#foundation) | 31% | 97% | 83 | 5 | 0 | 0 | 0 | 2 of 8 |
| [Swift, Darwin & runtimes](#runtime) | 87% | 97% | 70 | 4 | 0 | 0 | 0 | 13 of 16 |
| [Graphics & text](#graphics) | 21% | 93% | 45 | 7 | 0 | 0 | 0 | 6 of 12 |
| [GPU](#gpu) | 0% | 0% | 0 | 0 | 0 | 1 | 0 | 1 of 7 |
| [Imaging, photos & ML](#ml) | 13% | 64% | 11 | 14 | 3 | 0 | 0 | 11 of 30 |
| [Media](#media) | 21% | 96% | 42 | 4 | 0 | 0 | 0 | 9 of 27 |
| [Games & 3D](#games) | 15% | 85% | 69 | 15 | 0 | 6 | 0 | 7 of 13 |
| [Commerce & privacy](#commerce) | 31% | 99% | 34 | 1 | 0 | 0 | 0 | 6 of 14 |
| [Data & persistence](#data) | 49% | 88% | 16 | 3 | 1 | 0 | 0 | 3 of 3 |
| [Identity & security](#security) | 25% | 97% | 14 | 1 | 0 | 0 | 0 | 5 of 14 |
| [App extensions & system integration](#system) | 13% | 92% | 17 | 3 | 0 | 0 | 0 | 12 of 54 |
| [Location, personal data & sensors](#location) | 8% | 81% | 8 | 5 | 0 | 0 | 0 | 10 of 30 |
| [Web, network & communication](#web) | 21% | 94% | 15 | 0 | 1 | 0 | 0 | 8 of 12 |
| [Accessibility & Info.plist](#a11y) | 0% | 31% | 4 | 0 | 0 | 9 | 0 | 1 of 2 |
| **All areas** | **32%** | **94%** | **1026** | **83** | **5** | **23** | **0** | **101 of 252** |

Symbols: 79618 of 251094 Apple iOS symbols in the frameworks isim has or tracks (exact; isim 2a1571c, Apple snapshot 2026-10-14).
<!-- /generated:summary -->

### Per iOS version (rows)

A row counts toward iOS N when it was introduced at or before N (rows in parentheses).

<!-- generated:versions (isim/tools/coverage-summary.py; do not edit by hand) -->
| Area | iOS 17 | iOS 18 | iOS 26 | iOS 27 |
|---|---:|---:|---:|---:|
| UIKit | 99% (276) | 99% (284) | 99% (301) | 99% (312) |
| SwiftUI & Charts | 98% (233) | 98% (240) | 98% (247) | 98% (257) |
| Developer tools | 88% (54) | 88% (55) | 88% (56) | 87% (57) |
| Foundation & CoreFoundation | 98% (86) | 98% (86) | 98% (87) | 97% (88) |
| Swift, Darwin & runtimes | 97% (73) | 97% (74) | 97% (74) | 97% (74) |
| Graphics & text | 93% (52) | 93% (52) | 93% (52) | 93% (52) |
| GPU | 0% (1) | 0% (1) | 0% (1) | 0% (1) |
| Imaging, photos & ML | 64% (28) | 64% (28) | 64% (28) | 64% (28) |
| Media | 96% (46) | 96% (46) | 96% (46) | 96% (46) |
| Games & 3D | 85% (89) | 85% (89) | 85% (90) | 85% (90) |
| Commerce & privacy | 99% (34) | 99% (35) | 99% (35) | 99% (35) |
| Data & persistence | 88% (20) | 88% (20) | 88% (20) | 88% (20) |
| Identity & security | 97% (15) | 97% (15) | 97% (15) | 97% (15) |
| App extensions & system integration | 92% (20) | 92% (20) | 92% (20) | 92% (20) |
| Location, personal data & sensors | 81% (13) | 81% (13) | 81% (13) | 81% (13) |
| Web, network & communication | 93% (15) | 93% (15) | 94% (16) | 94% (16) |
| Accessibility & Info.plist | 36% (11) | 36% (11) | 31% (13) | 31% (13) |
| **All areas** | **94%** (1066) | **94%** (1084) | **94%** (1114) | **94%** (1137) |
<!-- /generated:versions -->

## Frameworks

Every iOS framework Apple documents, by area. Each area is also an issue label (`area:<name>`). The batches of work
toward 100% are issues labelled `coverage`, each a checklist of APIs.

<!-- generated:index (isim/tools/coverage-summary.py; do not edit by hand) -->

### UIKit

<a id="uikit"></a>Issues: [`area:uikit`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Auikit)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Quick Look](https://developer.apple.com/documentation/quicklook) | 4.0 | ✅ | 49.2% | – | [QuickLook](frameworks/QuickLook.md) |
| [UIKit](https://developer.apple.com/documentation/uikit) | 2.0 | ✅ | 92.0% | 99% | [UIKit](frameworks/UIKit.md) |

### SwiftUI & Charts

<a id="swiftui"></a>Issues: [`area:swiftui`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aswiftui)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Swift Charts](https://developer.apple.com/documentation/charts) | 16.0 | ✅ | 74.2% | 94% | [Charts](frameworks/Charts.md) |
| [SwiftUI](https://developer.apple.com/documentation/swiftui) | 13.0 | ✅ | 58.7% | 98% | [SwiftUI](frameworks/SwiftUI.md) |

### Developer tools

<a id="devtools"></a>Issues: [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [App Intents Testing](https://developer.apple.com/documentation/appintentstesting) | 27.0 | ❌ | 0.0%* | – | – |
| [DeveloperToolsSupport](https://developer.apple.com/documentation/developertoolssupport) | 14.0 | ✅ | 25.0% | – | [DeveloperToolsSupport](frameworks/DeveloperToolsSupport.md) |
| [Platform](https://developer.apple.com/documentation/platform) | – | ✅ | – | 88% | [Platform](frameworks/Platform.md) |
| [StoreKit Test](https://developer.apple.com/documentation/storekittest) | 14.0 | ❌ | 0.0%* | – | – |
| [Swift Testing](https://developer.apple.com/documentation/testing) | None | ✅ | 81.6% | 100% | [Testing](frameworks/Testing.md) |
| [XCTest](https://developer.apple.com/documentation/xctest) | None | ✅ | 35.8% | 67% | [XCTest](frameworks/XCTest.md) |
| [XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation) | None | ❌ | 0.0%* | – | – |
| Platform (isim topic) | – | ✅ | – | 88% | [Platform](frameworks/Platform.md) |

### Foundation & CoreFoundation

<a id="foundation"></a>Issues: [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Apple Archive](https://developer.apple.com/documentation/applearchive) | 14.0 | ❌ | 0.0%* | – | – |
| [CFNetwork](https://developer.apple.com/documentation/cfnetwork) | 2.0 | ❌ | 0.0%* | – | – |
| [Compression](https://developer.apple.com/documentation/compression) | 9.0 | ❌ | 0.0%* | – | – |
| [Core Foundation](https://developer.apple.com/documentation/corefoundation) | 2.0 | ✅ | 6.2% | 50% | [CoreFoundation](frameworks/CoreFoundation.md) |
| [Core Services](https://developer.apple.com/documentation/coreservices) | 12.0 | ❌ | 0.0%* | – | – |
| [Foundation](https://developer.apple.com/documentation/foundation) | 2.0 | ✅ | 39.8% | 98% | [Foundation](frameworks/Foundation.md) |
| [System](https://developer.apple.com/documentation/system) | 14.0 | ❌ | 0.0%* | – | – |
| [XPC](https://developer.apple.com/documentation/xpc) | 17.4 | ❌ | 0.0%* | – | – |

### Swift, Darwin & runtimes

<a id="runtime"></a>Issues: [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Combine](https://developer.apple.com/documentation/combine) | 13.0 | ✅ | 81.5% | 100% | [Combine](frameworks/Combine.md) |
| [CrashReportExtension](https://developer.apple.com/documentation/crashreportextension) | 27.0 | ❌ | 0.0%* | – | – |
| [Darwin](https://developer.apple.com/documentation/darwin) | – | ✅ | – | 92% | [Darwin](frameworks/Darwin.md) |
| [Darwin Notify](https://developer.apple.com/documentation/darwinnotify) | 9.3 | ❌ | 0.0%* | – | – |
| [Dispatch](https://developer.apple.com/documentation/dispatch) | 8.0 | ✅ | 84.7% | 100% | [Dispatch](frameworks/Dispatch.md) |
| [Distributed](https://developer.apple.com/documentation/distributed) | 16.0 | ✅ | 100.0% | – | [Distributed](frameworks/Distributed.md) |
| [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) | 16.0 | ✅ | 89.8% | 100% | [JavaScriptCore](frameworks/JavaScriptCore.md) |
| [MetricKit](https://developer.apple.com/documentation/metrickit) | 13.0 | ✅ | 36.9% | 100% | [MetricKit](frameworks/MetricKit.md) |
| [Objective-C Runtime](https://developer.apple.com/documentation/objectivec) | 2.0 | ✅ | 62.0% | 94% | [ObjectiveC](frameworks/ObjectiveC.md) |
| [Observation](https://developer.apple.com/documentation/observation) | 17.0 | ✅ | 52.8% | – | [Observation](frameworks/Observation.md) |
| [os](https://developer.apple.com/documentation/os) | 8.0 | ✅ | 84.1% | 100% | [os](frameworks/os.md) |
| [OSLog](https://developer.apple.com/documentation/oslog) | 15.0 | ✅ | 89.8% | – | [OSLog](frameworks/OSLog.md) |
| [RegexBuilder](https://developer.apple.com/documentation/regexbuilder) | 16.0 | ✅ | 99.6% | – | [RegexBuilder](frameworks/RegexBuilder.md) |
| [simd](https://developer.apple.com/documentation/simd) | None | ✅ | 51.9% | – | [simd](frameworks/simd.md) |
| [StateReporting](https://developer.apple.com/documentation/statereporting) | 27.0 | ❌ | 0.0%* | – | – |
| [Swift](https://developer.apple.com/documentation/swift) | 8.0 | ✅ | 92.4% | 100% | [Swift](frameworks/Swift.md) |
| [Synchronization](https://developer.apple.com/documentation/synchronization) | 18.0 | ✅ | 100.0% | – | [Synchronization](frameworks/Synchronization.md) |
| Darwin (isim topic) | – | ✅ | – | 92% | [Darwin](frameworks/Darwin.md) |

### Graphics & text

<a id="graphics"></a>Issues: [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [ColorSync](https://developer.apple.com/documentation/colorsync) | 16.0 | ❌ | 0.0%* | – | – |
| [Core Graphics](https://developer.apple.com/documentation/coregraphics) | 2.0 | ✅ | 45.7% | 93% | [CoreGraphics](frameworks/CoreGraphics.md) |
| [Core Text](https://developer.apple.com/documentation/coretext) | 3.2 | ✅ | 12.8% | 93% | [CoreText](frameworks/CoreText.md) |
| [Core Video](https://developer.apple.com/documentation/corevideo) | 4.0 | ✅ | 7.8% | – | [CoreVideo](frameworks/CoreVideo.md) |
| [Image I/O](https://developer.apple.com/documentation/imageio) | 4.0 | ✅ | 9.3% | 50% | [ImageIO](frameworks/ImageIO.md) |
| [IOSurface](https://developer.apple.com/documentation/iosurface) | 11.0 | ❌ | 0.0%* | – | – |
| [PaperKit](https://developer.apple.com/documentation/paperkit) | 26.0 | ❌ | 0.0%* | – | – |
| [PDFKit](https://developer.apple.com/documentation/pdfkit) | 11.0 | ❌ | 0.0%* | – | – |
| [PencilKit](https://developer.apple.com/documentation/pencilkit) | 13.0 | ❌ | 0.0%* | – | – |
| [Core Animation](https://developer.apple.com/documentation/quartzcore) | 2.0 | ✅ | 86.9% | 98% | [QuartzCore](frameworks/QuartzCore.md) |
| [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing) | 13.0 | ❌ | 0.0%* | – | – |
| [Symbols](https://developer.apple.com/documentation/symbols) | 17.0 | ✅ | 86.5% | – | [Symbols](frameworks/Symbols.md) |

### GPU

<a id="gpu"></a>Issues: [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Compute Graph](https://developer.apple.com/documentation/computegraph) | 27.0 | ❌ | 0.0%* | – | – |
| [Metal](https://developer.apple.com/documentation/metal) | 8.0 | ✅ | 0.0%* | 0% | [Metal](frameworks/Metal.md) |
| [MetalFX](https://developer.apple.com/documentation/metalfx) | 16.0 | ❌ | 0.0%* | – | – |
| [MetalKit](https://developer.apple.com/documentation/metalkit) | 9.0 | ❌ | 0.0%* | – | – |
| [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders) | 9.0 | ❌ | 0.0%* | – | – |
| [Metal Performance Shaders Graph](https://developer.apple.com/documentation/metalperformanceshadersgraph) | 14.0 | ❌ | 0.0%* | – | – |
| [ShaderGraph](https://developer.apple.com/documentation/shadergraph) | 17.0 | ❌ | 0.0%* | – | – |

### Imaging, photos & ML

<a id="ml"></a>Issues: [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Accelerate](https://developer.apple.com/documentation/accelerate) | 4.0 | ❌ | 0.0%* | – | – |
| [Core AI](https://developer.apple.com/documentation/coreai) | 27.0 | ❌ | 0.0%* | – | – |
| [Core Image](https://developer.apple.com/documentation/coreimage) | 5.0 | ✅ | 95.3% | 75% | [CoreImage](frameworks/CoreImage.md) |
| [Core ML](https://developer.apple.com/documentation/coreml) | 11.0 | ✅ | 24.9% | 75% | [CoreML](frameworks/CoreML.md) |
| [Core Transferable](https://developer.apple.com/documentation/coretransferable) | 16.0 | ✅ | 70.8% | – | [CoreTransferable](frameworks/CoreTransferable.md) |
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
| [Natural Language](https://developer.apple.com/documentation/naturallanguage) | 12.0 | ✅ | 57.5% | 50% | [NaturalLanguage](frameworks/NaturalLanguage.md) |
| [PhotoKit](https://developer.apple.com/documentation/photokit) | 8.0 | ✅ | 41.4% | 75% | [Photos](frameworks/Photos.md) |
| [PhotosUI](https://developer.apple.com/documentation/photokit) | 8.0 | ✅ | 54.1% | 50% | [PhotosUI](frameworks/PhotosUI.md) |
| [Sensitive Content Analysis](https://developer.apple.com/documentation/sensitivecontentanalysis) | 17.0 | ❌ | 0.0%* | – | – |
| [Sound Analysis](https://developer.apple.com/documentation/soundanalysis) | 13.0 | ❌ | 0.0%* | – | – |
| [Spatial](https://developer.apple.com/documentation/spatial) | 16.0 | ✅ | 2.6% | – | [Spatial](frameworks/Spatial.md) |
| [Speech](https://developer.apple.com/documentation/speech) | 10.0 | ✅ | 24.9% | 50% | [Speech](frameworks/Speech.md) |
| [TabularData](https://developer.apple.com/documentation/tabulardata) | 15.0 | ❌ | 0.0%* | – | – |
| [Translation](https://developer.apple.com/documentation/translation) | 17.4 | ❌ | 0.0%* | – | – |
| [TranslationUIProvider](https://developer.apple.com/documentation/translationuiprovider) | 18.4 | ❌ | 0.0%* | – | – |
| [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers) | 14.0 | ✅ | 38.2% | 50% | [UniformTypeIdentifiers](frameworks/UniformTypeIdentifiers.md) |
| [Vision](https://developer.apple.com/documentation/vision) | None | ✅ | 5.4% | 50% | [Vision](frameworks/Vision.md) |
| [VisionKit](https://developer.apple.com/documentation/visionkit) | 13.0 | ✅ | 52.5% | 0% | [VisionKit](frameworks/VisionKit.md) |
| [Visual Intelligence](https://developer.apple.com/documentation/visualintelligence) | 26.0 | ❌ | 0.0%* | – | – |

### Media

<a id="media"></a>Issues: [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [AudioAccessoryKit](https://developer.apple.com/documentation/audioaccessorykit) | 26.4 | ❌ | 0.0%* | – | – |
| [Audio Toolbox](https://developer.apple.com/documentation/audiotoolbox) | 2.0 | ✅ | 17.8% | 100% | [AudioToolbox](frameworks/AudioToolbox.md) |
| [Audio Unit](https://developer.apple.com/documentation/audiounit) | 2.0 | ❌ | 0.0%* | – | – |
| [AVFAudio](https://developer.apple.com/documentation/avfaudio) | 14.5 | ✅ | 50.2% | – | [AVFAudio](frameworks/AVFAudio.md) |
| [AVFoundation](https://developer.apple.com/documentation/avfoundation) | 2.2 | ✅ | 30.2% | 98% | [AVFoundation](frameworks/AVFoundation.md) |
| [AVKit](https://developer.apple.com/documentation/avkit) | 8.0 | ✅ | 30.5% | 83% | [AVKit](frameworks/AVKit.md) |
| [AVRouting](https://developer.apple.com/documentation/avrouting) | 16.0 | ❌ | 0.0%* | – | – |
| [AVSystemRouting](https://developer.apple.com/documentation/avsystemrouting) | 27.0 | ❌ | 0.0%* | – | – |
| [Cinematic](https://developer.apple.com/documentation/cinematic) | 17.0 | ❌ | 0.0%* | – | – |
| [Core Audio](https://developer.apple.com/documentation/coreaudio) | 2.0 | ❌ | 0.0%* | – | – |
| [CoreAudioKit](https://developer.apple.com/documentation/coreaudiokit) | 8.0 | ❌ | 0.0%* | – | – |
| [Core Audio Types](https://developer.apple.com/documentation/coreaudiotypes) | 13.0 | ✅ | 7.1% | – | [CoreAudioTypes](frameworks/CoreAudioTypes.md) |
| [Core Haptics](https://developer.apple.com/documentation/corehaptics) | 13.0 | ✅ | 67.2% | – | [CoreHaptics](frameworks/CoreHaptics.md) |
| [Core Media](https://developer.apple.com/documentation/coremedia) | 4.0 | ✅ | 14.3% | 83% | [CoreMedia](frameworks/CoreMedia.md) |
| [Core MIDI](https://developer.apple.com/documentation/coremidi) | 4.2 | ❌ | 0.0%* | – | – |
| [Media Accessibility](https://developer.apple.com/documentation/mediaaccessibility) | 17.0 | ❌ | 0.0%* | – | – |
| [Media Device](https://developer.apple.com/documentation/mediadevice) | 27.0 | ❌ | 0.0%* | – | – |
| [Media Intents](https://developer.apple.com/documentation/mediaintents) | 27.0 | ❌ | 0.0%* | – | – |
| [Media Player](https://developer.apple.com/documentation/mediaplayer) | 2.0 | ✅ | 69.0% | 88% | [MediaPlayer](frameworks/MediaPlayer.md) |
| [Media Toolbox](https://developer.apple.com/documentation/mediatoolbox) | 6.0 | ❌ | 0.0%* | – | – |
| [MusicKit](https://developer.apple.com/documentation/musickit) | 15.0 | ✅ | 26.3% | – | [MusicKit](frameworks/MusicKit.md) |
| [Now Playing](https://developer.apple.com/documentation/nowplaying) | 27.0 | ❌ | 0.0%* | – | – |
| [PHASE](https://developer.apple.com/documentation/phase) | 15.0 | ❌ | 0.0%* | – | – |
| [ReplayKit](https://developer.apple.com/documentation/replaykit) | 9.0 | ❌ | 0.0%* | – | – |
| [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) | 27.0 | ❌ | 0.0%* | – | – |
| [ShazamKit](https://developer.apple.com/documentation/shazamkit) | 15.0 | ❌ | 0.0%* | – | – |
| [Video Toolbox](https://developer.apple.com/documentation/videotoolbox) | 6.0 | ❌ | 0.0%* | – | – |

### Games & 3D

<a id="games"></a>Issues: [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [ARKit](https://developer.apple.com/documentation/arkit) | 11.0 | ✅ | 0.0%* | 0% | [ARKit](frameworks/ARKit.md) |
| [Game Controller](https://developer.apple.com/documentation/gamecontroller) | 7.0 | ✅ | 31.5% | 64% | [GameController](frameworks/GameController.md) |
| [GameKit](https://developer.apple.com/documentation/gamekit) | 3.0 | ✅ | 71.0% | 92% | [GameKit](frameworks/GameKit.md) |
| [GameplayKit](https://developer.apple.com/documentation/gameplaykit) | 9.0 | ✅ | 88.7% | 78% | [GameplayKit](frameworks/GameplayKit.md) |
| [GameSave](https://developer.apple.com/documentation/gamesave) | 26.0 | ❌ | 0.0%* | – | – |
| [Group Activities](https://developer.apple.com/documentation/groupactivities) | 15.0 | ❌ | 0.0%* | – | – |
| [Model I/O](https://developer.apple.com/documentation/modelio) | 9.0 | ❌ | 0.0%* | – | – |
| [RealityKit](https://developer.apple.com/documentation/realitykit) | 13.0 | ✅ | 0.0%* | 0% | [RealityKit](frameworks/RealityKit.md) |
| [RoomPlan](https://developer.apple.com/documentation/roomplan) | 16.0 | ❌ | 0.0%* | – | – |
| [SceneKit](https://developer.apple.com/documentation/scenekit) | 8.0 | ✅ | 0.0%* | 0% | [SceneKit](frameworks/SceneKit.md) |
| [SpriteKit](https://developer.apple.com/documentation/spritekit) | 7.0 | ✅ | 96.0% | 93% | [SpriteKit](frameworks/SpriteKit.md) |
| [Touch Controller](https://developer.apple.com/documentation/touchcontroller) | 26.0 | ❌ | 0.0%* | – | – |
| [USDKit](https://developer.apple.com/documentation/usdkit) | 27.0 | ❌ | 0.0%* | – | – |

### Commerce & privacy

<a id="commerce"></a>Issues: [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [AdAttributionKit](https://developer.apple.com/documentation/adattributionkit) | 17.4 | ✅ | 100.0% | 100% | [AdAttributionKit](frameworks/AdAttributionKit.md) |
| [AdServices](https://developer.apple.com/documentation/adservices) | 14.3 | ✅ | 100.0% | 100% | [AdServices](frameworks/AdServices.md) |
| [AdSupport](https://developer.apple.com/documentation/adsupport) | 6.0 | ✅ | 100.0% | 100% | [AdSupport](frameworks/AdSupport.md) |
| [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency) | 14.0 | ✅ | 100.0% | 100% | [AppTrackingTransparency](frameworks/AppTrackingTransparency.md) |
| [Declared Age Range](https://developer.apple.com/documentation/declaredagerange) | 26.0 | ❌ | 0.0%* | – | – |
| [FinanceKit](https://developer.apple.com/documentation/financekit) | 17.0 | ❌ | 0.0%* | – | – |
| [FinanceKitUI](https://developer.apple.com/documentation/financekitui) | 17.0 | ❌ | 0.0%* | – | – |
| [ManagedAppDistribution](https://developer.apple.com/documentation/managedappdistribution) | 17.2 | ❌ | 0.0%* | – | – |
| [MarketplaceKit](https://developer.apple.com/documentation/marketplacekit) | 17.4 | ✅ | 7.6% | 50% | [MarketplaceKit](frameworks/MarketplaceKit.md) |
| [PassKit (Apple Pay and Wallet)](https://developer.apple.com/documentation/passkit) | 6.0 | ❌ | 0.0%* | – | – |
| [PermissionKit](https://developer.apple.com/documentation/permissionkit) | 26.0 | ❌ | 0.0%* | – | – |
| [StoreKit](https://developer.apple.com/documentation/storekit) | 3.0 | ✅ | 52.7% | 100% | [StoreKit](frameworks/StoreKit.md) |
| [Wallet Orders](https://developer.apple.com/documentation/walletorders) | 16.0 | ❌ | – | – | – |
| [Wallet Passes](https://developer.apple.com/documentation/walletpasses) | 6.0 | ❌ | – | – | – |

### Data & persistence

<a id="data"></a>Issues: [`area:data`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adata)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [CloudKit](https://developer.apple.com/documentation/cloudkit) | 8.0 | ✅ | 48.9% | 92% | [CloudKit](frameworks/CloudKit.md) |
| [Core Data](https://developer.apple.com/documentation/coredata) | 3.0 | ✅ | 67.3% | 92% | [CoreData](frameworks/CoreData.md) |
| [SwiftData](https://developer.apple.com/documentation/swiftdata) | 17.0 | ✅ | 18.2% | 0% | [SwiftData](frameworks/SwiftData.md) |

### Identity & security

<a id="security"></a>Issues: [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Authentication Services](https://developer.apple.com/documentation/authenticationservices) | 12.0 | ✅ | 17.6% | 100% | [AuthenticationServices](frameworks/AuthenticationServices.md) |
| [CarKey](https://developer.apple.com/documentation/carkey) | 16.0 | ❌ | 0.0%* | – | – |
| [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit) | 13.0 | ✅ | 71.8% | 100% | [CryptoKit](frameworks/CryptoKit.md) |
| [CryptoTokenKit](https://developer.apple.com/documentation/cryptotokenkit) | 13.0 | ❌ | 0.0%* | – | – |
| [DeviceCheck](https://developer.apple.com/documentation/devicecheck) | 11.0 | ✅ | 100.0% | 100% | [DeviceCheck](frameworks/DeviceCheck.md) |
| [GSS](https://developer.apple.com/documentation/gss) | 5.0 | ❌ | 0.0%* | – | – |
| [IdentityDocumentServices](https://developer.apple.com/documentation/identitydocumentservices) | 26.0 | ❌ | 0.0%* | – | – |
| [IdentityDocumentServicesUI](https://developer.apple.com/documentation/identitydocumentservicesui) | 26.0 | ❌ | 0.0%* | – | – |
| [LightweightCodeRequirements](https://developer.apple.com/documentation/lightweightcoderequirements) | 17.4 | ❌ | 0.0%* | – | – |
| [Local Authentication](https://developer.apple.com/documentation/localauthentication) | 8.0 | ✅ | 32.4% | 100% | [LocalAuthentication](frameworks/LocalAuthentication.md) |
| [Local Authentication Embedded UI](https://developer.apple.com/documentation/localauthenticationembeddedui) | 16.0 | ❌ | 0.0%* | – | – |
| [Security](https://developer.apple.com/documentation/security) | 2.0 | ✅ | 25.7% | 92% | [Security](frameworks/Security.md) |
| [ServicesAccountLinking](https://developer.apple.com/documentation/servicesaccountlinking) | 16.4 | ❌ | 0.0%* | – | – |
| [Trust Insights](https://developer.apple.com/documentation/trustinsights) | 27.0 | ❌ | 0.0%* | – | – |

### App extensions & system integration

<a id="system"></a>Issues: [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Accessory Live Activities](https://developer.apple.com/documentation/accessoryliveactivities) | 26.5 | ❌ | 0.0%* | – | – |
| [Accessory Notifications](https://developer.apple.com/documentation/accessorynotifications) | 26.5 | ❌ | 0.0%* | – | – |
| [Accessory Transport Extension](https://developer.apple.com/documentation/accessorytransportextension) | 26.2 | ❌ | 0.0%* | – | – |
| [ActivityKit](https://developer.apple.com/documentation/activitykit) | 16.1 | ✅ | 56.0% | 100% | [ActivityKit](frameworks/ActivityKit.md) |
| [AlarmKit](https://developer.apple.com/documentation/alarmkit) | 26.0 | ❌ | 0.0%* | – | – |
| [App Clips](https://developer.apple.com/documentation/appclip) | 14.0 | ✅ | 100.0% | 100% | [AppClip](frameworks/AppClip.md) |
| [App Intents](https://developer.apple.com/documentation/appintents) | 16.0 | ✅ | 13.2% | 75% | [AppIntents](frameworks/AppIntents.md) |
| [AppMigrationKit](https://developer.apple.com/documentation/appmigrationkit) | 26.1 | ❌ | 0.0%* | – | – |
| [Assignables](https://developer.apple.com/documentation/assignables) | 15.4 | ❌ | 0.0%* | – | – |
| [Automated Device Enrollment](https://developer.apple.com/documentation/automateddeviceenrollment) | 16.1 | ❌ | – | – | – |
| [Automatic Assessment Configuration](https://developer.apple.com/documentation/automaticassessmentconfiguration) | 13.4 | ❌ | 0.0%* | – | – |
| [Background Assets](https://developer.apple.com/documentation/backgroundassets) | 16.0 | ❌ | 0.0%* | – | – |
| [Background Tasks](https://developer.apple.com/documentation/backgroundtasks) | 13.0 | ✅ | 58.7% | 100% | [BackgroundTasks](frameworks/BackgroundTasks.md) |
| [BrowserEngineCore](https://developer.apple.com/documentation/browserenginecore) | 17.4 | ❌ | 0.0%* | – | – |
| [BrowserEngineKit](https://developer.apple.com/documentation/browserenginekit) | 17.4 | ❌ | 0.0%* | – | – |
| [BrowserKit](https://developer.apple.com/documentation/browserkit) | 18.4 | ❌ | 0.0%* | – | – |
| [CallKit](https://developer.apple.com/documentation/callkit) | 10.0 | ✅ | 80.6% | 100% | [CallKit](frameworks/CallKit.md) |
| [CarPlay](https://developer.apple.com/documentation/carplay) | 12.0 | ❌ | 0.0%* | – | – |
| [ClassKit](https://developer.apple.com/documentation/classkit) | 11.4 | ❌ | 0.0%* | – | – |
| [ContactProvider](https://developer.apple.com/documentation/contactprovider) | 18.0 | ❌ | 0.0%* | – | – |
| [Core Spotlight](https://developer.apple.com/documentation/corespotlight) | 9.0 | ✅ | 8.9% | 50% | [CoreSpotlight](frameworks/CoreSpotlight.md) |
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
| [SiriKit](https://developer.apple.com/documentation/sirikit) | 10.0 | ✅ | 24.1% | 100% | [Intents](frameworks/Intents.md) |
| [IntentsUI](https://developer.apple.com/documentation/sirikit) | 10.0 | ✅ | 95.8% | – | [IntentsUI](frameworks/IntentsUI.md) |
| [Journaling Suggestions](https://developer.apple.com/documentation/journalingsuggestions) | 17.2 | ❌ | 0.0%* | – | – |
| [LiveCommunicationKit](https://developer.apple.com/documentation/livecommunicationkit) | 17.4 | ❌ | 0.0%* | – | – |
| [ManagedApp](https://developer.apple.com/documentation/managedapp) | 18.4 | ❌ | 0.0%* | – | – |
| [Managed Settings](https://developer.apple.com/documentation/managedsettings) | 15.0 | ❌ | 0.0%* | – | – |
| [Managed Settings UI](https://developer.apple.com/documentation/managedsettingsui) | 15.0 | ❌ | 0.0%* | – | – |
| [Media Setup](https://developer.apple.com/documentation/mediasetup) | 14.0 | ❌ | 0.0%* | – | – |
| [Messages](https://developer.apple.com/documentation/messages) | 10.0 | ❌ | 0.0%* | – | – |
| [PushKit](https://developer.apple.com/documentation/pushkit) | 8.0 | ✅ | 93.3% | 100% | [PushKit](frameworks/PushKit.md) |
| [Push to Talk](https://developer.apple.com/documentation/pushtotalk) | 16.0 | ❌ | 0.0%* | – | – |
| [RelevanceKit](https://developer.apple.com/documentation/relevancekit) | 26.0 | ❌ | 0.0%* | – | – |
| [SafetyKit](https://developer.apple.com/documentation/safetykit) | 16.0 | ❌ | 0.0%* | – | – |
| [Screen Time](https://developer.apple.com/documentation/screentime) | 14.0 | ❌ | 0.0%* | – | – |
| [Shared with You](https://developer.apple.com/documentation/sharedwithyou) | 16.0 | ❌ | 0.0%* | – | – |
| [Suggested Actions](https://developer.apple.com/documentation/suggestedactions) | 27.0 | ❌ | 0.0%* | – | – |
| [TelephonyMessagingKit](https://developer.apple.com/documentation/telephonymessagingkit) | 26.0 | ❌ | 0.0%* | – | – |
| [TipKit](https://developer.apple.com/documentation/tipkit) | 17.0 | ❌ | 0.0%* | – | – |
| [User Notifications](https://developer.apple.com/documentation/usernotifications) | 10.0 | ✅ | 82.1% | 100% | [UserNotifications](frameworks/UserNotifications.md) |
| [User Notifications UI](https://developer.apple.com/documentation/usernotificationsui) | 10.0 | ✅ | 100.0% | – | [UserNotificationsUI](frameworks/UserNotificationsUI.md) |
| [Video Subscriber Account](https://developer.apple.com/documentation/videosubscriberaccount) | 10.0 | ❌ | 0.0%* | – | – |
| [WidgetKit](https://developer.apple.com/documentation/widgetkit) | 14.0 | ✅ | 43.6% | 50% | [WidgetKit](frameworks/WidgetKit.md) |

### Location, personal data & sensors

<a id="location"></a>Issues: [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit) | 18.0 | ❌ | 0.0%* | – | – |
| [Contacts](https://developer.apple.com/documentation/contacts) | 9.0 | ✅ | 43.6% | 100% | [Contacts](frameworks/Contacts.md) |
| [Contacts UI](https://developer.apple.com/documentation/contactsui) | 9.0 | ✅ | 79.2% | – | [ContactsUI](frameworks/ContactsUI.md) |
| [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) | 5.0 | ✅ | 42.4% | 50% | [CoreBluetooth](frameworks/CoreBluetooth.md) |
| [Core Location](https://developer.apple.com/documentation/corelocation) | 2.0 | ✅ | 84.3% | 100% | [CoreLocation](frameworks/CoreLocation.md) |
| [CoreLocationUI](https://developer.apple.com/documentation/corelocationui) | 15.0 | ❌ | 0.0%* | – | – |
| [Core Motion](https://developer.apple.com/documentation/coremotion) | 4.0 | ✅ | 54.8% | 100% | [CoreMotion](frameworks/CoreMotion.md) |
| [Core NFC](https://developer.apple.com/documentation/corenfc) | 11.0 | ✅ | 24.0% | 50% | [CoreNFC](frameworks/CoreNFC.md) |
| [DockKit](https://developer.apple.com/documentation/dockkit) | 17.0 | ❌ | 0.0%* | – | – |
| [DriverKit](https://developer.apple.com/documentation/driverkit) | 16.0 | ❌ | 0.0%* | – | – |
| [EventKit](https://developer.apple.com/documentation/eventkit) | 4.0 | ✅ | 58.2% | 50% | [EventKit](frameworks/EventKit.md) |
| [EventKit UI](https://developer.apple.com/documentation/eventkitui) | 4.0 | ✅ | 53.1% | – | [EventKitUI](frameworks/EventKitUI.md) |
| [Exposure Notification](https://developer.apple.com/documentation/exposurenotification) | 13.5 | ❌ | 0.0%* | – | – |
| [External Accessory](https://developer.apple.com/documentation/externalaccessory) | 3.0 | ❌ | 0.0%* | – | – |
| [GeoToolbox](https://developer.apple.com/documentation/geotoolbox) | 26.0 | ❌ | 0.0%* | – | – |
| [HealthKit](https://developer.apple.com/documentation/healthkit) | 8.0 | ✅ | 15.8% | 50% | [HealthKit](frameworks/HealthKit.md) |
| [HomeKit](https://developer.apple.com/documentation/homekit) | 8.0 | ❌ | 0.0%* | – | – |
| [hvf](https://developer.apple.com/documentation/hvf) | 18.4 | ❌ | 0.0%* | – | – |
| [IOKit](https://developer.apple.com/documentation/iokit) | 16.0 | ❌ | 0.0%* | – | – |
| [MapKit](https://developer.apple.com/documentation/mapkit) | 3.0 | ✅ | 67.4% | 90% | [MapKit](frameworks/MapKit.md) |
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
|---|---|---|---:|---:|---|
| [Core Telephony](https://developer.apple.com/documentation/coretelephony) | 4.0 | ✅ | 18.1% | – | [CoreTelephony](frameworks/CoreTelephony.md) |
| [dnssd](https://developer.apple.com/documentation/dnssd) | 10.0 | ❌ | 0.0%* | – | – |
| [Link Presentation](https://developer.apple.com/documentation/linkpresentation) | 13.0 | ❌ | 0.0%* | – | – |
| [Message UI](https://developer.apple.com/documentation/messageui) | 3.0 | ✅ | 66.3% | 100% | [MessageUI](frameworks/MessageUI.md) |
| [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity) | 7.0 | ✅ | 94.7% | 100% | [MultipeerConnectivity](frameworks/MultipeerConnectivity.md) |
| [Network](https://developer.apple.com/documentation/network) | 12.0 | ✅ | 23.5% | 83% | [Network](frameworks/Network.md) |
| [Network Extension](https://developer.apple.com/documentation/networkextension) | 8.0 | ❌ | 0.0%* | – | – |
| [Safari Services](https://developer.apple.com/documentation/safariservices) | 7.0 | ✅ | 34.8% | 100% | [SafariServices](frameworks/SafariServices.md) |
| [Social](https://developer.apple.com/documentation/social) | 6.0 | ✅ | 42.9% | – | [Social](frameworks/Social.md) |
| [System Configuration](https://developer.apple.com/documentation/systemconfiguration) | 2.0 | ✅ | 20.4% | 100% | [SystemConfiguration](frameworks/SystemConfiguration.md) |
| [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity) | 9.0 | ❌ | 0.0%* | – | – |
| [WebKit](https://developer.apple.com/documentation/webkit) | 16.0 | ✅ | 35.3% | 100% | [WebKit](frameworks/WebKit.md) |

### Accessibility & Info.plist

<a id="a11y"></a>Issues: [`area:a11y`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aa11y)

| Framework | iOS | In isim | Symbols | Rows | Page |
|---|---|---|---:|---:|---|
| [Accessibility](https://developer.apple.com/documentation/accessibility) | 14.0 | ❌ | 0.0%* | – | – |
| [Bundle Resources](https://developer.apple.com/documentation/bundleresources) | 2.0 | ✅ | 0.0%* | 31% | [BundleResources](frameworks/BundleResources.md) |

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
| AuthenticationServices | ❌ Swift only |
| AVFAudio | ✅ headers in isim/sdk-src/Frameworks/AVFAudio |
| AVFoundation | ✅ headers in isim/sdk-src/Frameworks/AVFoundation |
| AVKit | ❌ Swift only |
| BackgroundTasks | ❌ Swift only |
| CallKit | ❌ Swift only |
| Charts | ❌ Swift only |
| CloudKit | ❌ Swift only |
| Combine | ❌ Swift only |
| Contacts | ❌ Swift only |
| ContactsUI | ❌ Swift only |
| CoreAudioTypes | ❌ Swift only |
| CoreBluetooth | ❌ Swift only |
| CoreData | ✅ headers in isim/sdk-src/Frameworks/CoreData |
| CoreFoundation | ✅ headers in isim/sdk-src/Frameworks/CoreFoundation |
| CoreGraphics | ✅ headers in isim/sdk-src/Frameworks/CoreGraphics |
| CoreHaptics | ❌ Swift only |
| CoreImage | ✅ headers in isim/sdk-src/Frameworks/CoreImage |
| CoreLocation | ❌ Swift only |
| CoreMedia | ✅ headers in isim/sdk-src/Frameworks/CoreMedia |
| CoreML | ❌ Swift only |
| CoreMotion | ✅ headers in isim/sdk-src/Frameworks/CoreMotion |
| CoreNFC | ❌ Swift only |
| CoreSpotlight | ❌ Swift only |
| CoreTelephony | ✅ headers in isim/sdk-src/Frameworks/CoreTelephony |
| CoreText | ✅ headers in isim/sdk-src/Frameworks/CoreText |
| CoreTransferable | ❌ Swift only |
| CoreVideo | ❌ Swift only |
| CryptoKit | ❌ Swift only |
| DeveloperToolsSupport | ❌ Swift only |
| DeviceCheck | ❌ Swift only |
| Dispatch | ❌ Swift only |
| Distributed | ❌ Swift only |
| EventKit | ❌ Swift only |
| EventKitUI | ❌ Swift only |
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
| MapKit | ❌ Swift only |
| MarketplaceKit | ✅ headers in isim/sdk-src/Frameworks/MarketplaceKit |
| MediaPlayer | ❌ Swift only |
| MessageUI | ✅ headers in isim/sdk-src/Frameworks/MessageUI |
| MetricKit | ❌ Swift only |
| MultipeerConnectivity | ❌ Swift only |
| MusicKit | ❌ Swift only |
| NaturalLanguage | ❌ Swift only |
| Network | ✅ headers in isim/sdk-src/Frameworks/Network |
| ObjectiveC | ❌ Swift only |
| Observation | ❌ Swift only |
| os | ❌ Swift only |
| OSLog | ❌ Swift only |
| Photos | ❌ Swift only |
| PhotosUI | ❌ Swift only |
| PushKit | ❌ Swift only |
| QuartzCore | ❌ Swift only |
| QuickLook | ✅ headers in isim/sdk-src/Frameworks/QuickLook |
| RegexBuilder | ❌ Swift only |
| SafariServices | ❌ Swift only |
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
