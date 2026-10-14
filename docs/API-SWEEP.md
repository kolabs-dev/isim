# Measuring coverage against Apple's documentation

How isim's API coverage ([COVERAGE.md](COVERAGE.md)) is measured against Apple's own documentation, and how to repeat
it. The tool is [`isim/tools/api-coverage.py`](../isim/tools/api-coverage.py); the first full sweep was done on
2026-10-13/14 (results at the end).

## Scope

- **iOS versions:** isim emulates iOS 17, 18, 26 and 27. An Apple symbol is in scope when Apple documents it for iOS,
  it is not unavailable on iOS, and it is usable in at least one of those versions:
  - deprecated at iOS 18 or later: in scope, because apps built for 17–26 still call it;
  - deprecated at iOS 17 or earlier: out of scope.
- **Frameworks deprecated at iOS 17 or earlier** are out of scope as a whole (`deprecated` in
  [`isim/data/frameworks.json`](../isim/data/frameworks.json)): OpenGL ES, GLKit, AddressBook(UI), AssetsLibrary, iAd,
  Accounts, NotificationCenter (Today widgets), ClockKit.
- **Every other framework Apple documents for iOS is tracked,** unless it is Apple-platform-only and completely
  impossible to replicate on Linux (`impossible` in the same file, with the reason; empty so far).
- **Capabilities that need Apple's own secrets** are ⛔ rows on their framework's page:
  - Apple-signed receipts, attestations and tokens;
  - FairPlay keys;
  - Apple's licensed models and SF Symbols artwork;
  - Apple's servers;
  - Xcode-compiled `.metallib` and `.mlmodelc` files.

## Sources

All public JSON, no account needed. Behind a proxy, set `SSL_CERT_FILE` to its CA bundle.

| What | URL | Used for |
|---|---|---|
| Technology list | `https://developer.apple.com/tutorials/data/documentation/technologies.json` ([page](https://developer.apple.com/documentation/technologies)) | every framework Apple documents (about 400), filtered to iOS through each root page |
| Framework root page | `https://developer.apple.com/tutorials/data/documentation/<id>.json` | `metadata.platforms` (iOS introduced and deprecated), `metadata.modules` |
| Navigator index | `https://developer.apple.com/tutorials/data/index/<archive>` | all symbols of a framework as a tree: `interfaceLanguages.swift` and `.occ` (Objective-C); each node has `path`, `title`, `type`, sometimes `deprecated` / `beta` |
| Symbol page | `https://developer.apple.com/tutorials/data/documentation/<path>.json` | `metadata.platforms` (per platform: `introducedAt`, `deprecatedAt`, `unavailable`, `beta`), `metadata.externalID` (the USR, e.g. `c:objc(cs)UIView`), `metadata.symbolKind` |
| Updates index | `https://developer.apple.com/tutorials/data/documentation/updates.json` ([page](https://developer.apple.com/documentation/updates)) | frameworks with an updates page |
| Updates per framework | `https://developer.apple.com/tutorials/data/documentation/updates/<framework>.json` (e.g. [UIKit](https://developer.apple.com/documentation/updates/uikit)) | symbols added per release, under headings like "June 2025" (iOS 26), "June 2026" (iOS 27), "September 2026" (27.1) |
| Release notes | <https://developer.apple.com/documentation/ios-ipados-release-notes> | context for beta APIs |
| Device specifications | e.g. <https://www.apple.com/iphone-duo/specs/> | device presets, always checked against Xcode's device type before use |

## Pitfalls (found in the first sweep)

- **Archives that hold several modules, or that have another name.**
  - `index/sirikit` holds Intents and IntentsUI, and `index/photokit` holds Photos and PhotosUI.
  - Their symbols sit under collection nodes whose paths belong to the other archive (`/documentation/sirikit/…`).
  - So walk into every node, and count only the paths under `/documentation/<module>/`. Missing this hid about 315
    Intents types the first time.
- **Modules missing from the technology list.** Vision, simd, XCTest, Swift Testing and XCUIAutomation have their own
  archives but are not in the list: `extra_modules` in `frameworks.json`.
- **`deprecated: true` in the index means deprecated somewhere,** in some version of some platform, including iOS 27
  (all of MultipeerConnectivity, for example). Never filter on it: read each symbol's iOS `deprecatedAt`.
- **Xcode's test frameworks** list Xcode, not iOS, as their platform, so all of their symbols count.
- **AVFAudio** is its own archive, but isim implements it inside AVFoundation (`IMPLEMENTED_IN` in the tool).
- **Objective-C and Swift names differ** (`UIViewAutoresizing` / `UIView.AutoresizingMask`, `NS_SWIFT_NAME`,
  import-as-member).
  - Matching by name misses renamed APIs. The exact mode reads the Swift view of every module, so a type that exists
    only under its Objective-C name shows up as missing: that is a real source-compatibility gap
    (`UIDevice.BatteryState`).
- **Odd or empty platform data.** `metadata.platforms` is sometimes empty, and some index availability is odd. Trust
  the per-symbol page.
- **Volume:** about 300,000 symbols in 261 iOS frameworks.
  - Availability is fetched only for the symbols isim lacks, and cached in the snapshot (about 50,000 so far). 48
    parallel connections fetch 40,000 in about 30 minutes.
  - The snapshot is `isim/data/apple-api/apple-api.json.gz`, about 4 MB.

## Running it

```bash
export SSL_CERT_FILE=/path/to/ca-bundle.crt                 # only behind a proxy
isim/tools/api-coverage.py snapshot                         # Apple's data -> isim/data/apple-api/apple-api.json.gz
isim/build.py                                               # a built SDK for the exact mode
isim/tools/api-coverage.py measure                          # -> isim/data/api-coverage.json.gz
isim/tools/coverage-summary.py                              # -> docs/COVERAGE.md, docs/frameworks/*.md
isim/tools/api-coverage.py updates                          # per release: what Apple added that isim lacks (a report)
```

- **`snapshot`**
  - Reads the technology list and every iOS framework's root page and navigator index (`--modules A,B` for some only).
  - Keeps, for each symbol: its documentation path, title, kind, owner and the "deprecated somewhere" flag.
  - Keeps the availability cache.
- **`measure` (exact; the default when `isim/out/sdk` exists)**
  - Runs `swift-symbolgraph-extract` (the `swift:6.2` image, like `isim swiftc`) on every module of the built SDK. That
    also gives the Swift view of the Objective-C frameworks.
  - Matches each Apple symbol by its documentation path: DocC builds the path from the same path components, lowercased,
    with disambiguation suffixes such as `-swift.struct` or `-1a2b3` removed.
  - A symbol whose name matches but whose signature doesn't counts as present; an overload difference is not a
    missing API.
  - Then fetches the availability of the symbols that didn't match, and keeps those in scope.
- **`measure --names` (no build)**
  - A symbol counts as present when its base name occurs in that framework's isim sources (`SOURCES` in the tool for
    the modules that live elsewhere).
  - Lenient: a lower bound on what is missing.
- **Frameworks isim doesn't have:** every symbol Apple doesn't flag as deprecated counts as missing (approximate:
  availability is not fetched for them).
- **`coverage-summary.py`** writes the generated parts of COVERAGE.md (summaries, index, out of scope, Objective-C
  interfaces) and of each framework page (the header line and the "Not yet in isim" list).

Pull requests do not run these: the Release workflow does (exact mode on the release build) and commits the results in
the release pull request, so the generated parts never conflict between pull requests.

## Checking by hand (the audit)

The tool finds candidates; statuses on the framework pages come from reading isim's code. Each sweep should also
review each area:
- **What to compare:**
  - each row's status against the code (a ✅ row whose notes or code show a missing, ignored or stubbed part is
    🟡/🧩);
  - each note and iOS column against Apple's pages;
  - the `coverage` issues against the pages.
- **Confirming a gap:** `grep -rlw <Name> isim/swift isim/frameworks isim/sdk-src isim/runtime`, plus reading the
  implementation.
- **Categories for findings:**
  - **A** — overstated status;
  - **B** — a missing row or framework;
  - **C** — a stale note or wrong iOS column;
  - **D** — understated status;
  - **E** — an issue that disagrees with the pages.
- **Evidence:** cite a page line, an isim `file:line` and an Apple documentation path.
- **Adapted behaviour that matches Apple's Simulator** is not a defect.
- **Re-check earlier findings** on the current `main` before reusing them.

The first sweep ran two rounds of eight and seven parallel reviews, one per area, each with:
- the tool's outputs and the round's findings;
- read-only access;
- instructions to return findings A–E, a "how isim implements it" line per framework, and proposed issue batches
  (S ≤ 1 day, M 2–3 days, L ≤ 1 week).

## Results of the first sweep (2026-10-14, `main` @ 7dcbf88)

- **Frameworks:**
  - Apple documents 261 frameworks for iOS, counting Vision, simd and the test frameworks; isim ships 96 modules.
  - Of the 254 in the technology list, 146 were neither in isim nor in COVERAGE.md before this sweep.
- **Coverage of the frameworks isim ships, by name:** 61,241 of 139,681 in-scope Apple symbols (43.8%; a lower bound on
  what is missing). Exact numbers: COVERAGE.md.
- **Deprecated symbols isim lacks:** 616 stay in scope (deprecated at iOS 18 or later); 2,043 are dropped (deprecated
  at iOS 17 or earlier).
- **Updates pages:** 465 of the 1,144 highlighted symbols were available on iOS and missing from isim.
- **Corrections:**
  - about 70 rows downgraded or corrected (statuses, notes, iOS columns);
  - the big per-area `coverage` issues were replaced by small batch issues, each a checklist.
  - each framework page got ❌ rows ("Types not yet in isim", one per iOS version) for the missing types that no row
    mentioned, 2,608 types in all, so a page's row coverage counts them (issue #207);
    types isim declares in another module than Apple's are 🟡 rows instead.

## External references (iPhone Duo, iOS 27.1)

- <https://www.apple.com/iphone-duo/specs/>: display sizes and pixels.
- <https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/>, <https://www.apple.com/iphone-duo/>: the announcement.
- <https://www.macrumors.com/2026/10/05/apple-opens-iphone-duo-app-submissions/>: App Store submissions.
- <https://appleinsider.com/articles/26/09/18/developers-finally-get-xcode-tools-to-prepare-apps-for-iphone-duo>: Xcode 27.1 beta and its iPhone Duo simulator.
- <https://www.avanderlee.com/swiftui/iphone-duo-simulator/>: the simulator's posture controls.
- <https://github.com/mobile-dev-inc/maestro/issues/3617>: open question, posture through XCUIDevice or simctl.
- <https://github.com/Codelaby/IphoneDuo>: SwiftUI samples of the 27.1 APIs.
- <https://adapty.io/blog/adapt-your-ios-app-to-iphone-duo/>, <https://pasqualepillitteri.it/en/news/16941/xcode-271-iphone-duo-simulator>,
  <https://pasqualepillitteri.it/en/news/15360/iphone-duo-prepare-apps-developers>,
  <https://daily.dev/posts/i-watched-every-iphone-duo-developer-video-here-s-what-matters--cqe8xmnsb>: secondary
  summaries, not authoritative.
- Apple's pages for the 27.1 symbols, e.g. <https://developer.apple.com/documentation/swiftui/devicehinge>,
  <https://developer.apple.com/documentation/uikit/uihingeinteraction>, and the "September 2026" sections of
  <https://developer.apple.com/documentation/updates/uikit>, <https://developer.apple.com/documentation/updates/swiftui> and
  <https://developer.apple.com/documentation/updates/avkit>.

## Repeating it

- **When:** after each Apple SDK release (June beta, September release, point releases), before each minor release, or
  when the numbers are in doubt.
- **Steps:**
  1. Run `snapshot`, then `measure` on a fresh build, then `coverage-summary.py`.
  2. Review the areas as above.
  3. File new `coverage` batch issues (the "Coverage batch" form), and update this page's results.
