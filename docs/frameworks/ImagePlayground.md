# ImagePlayground

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (75 of 75, exact) · **Rows:** 4: 1 ✅ 3 🧩 · **iOS:** 18.1+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [ImagePlayground](https://developer.apple.com/documentation/imageplayground) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Approach:** isim's Swift overlay (`isim/swift/overlays/ImagePlayground`). Apple's image model is part of Apple
  Intelligence; isim has none (a host backend such as stable-diffusion.cpp is possible later), so Image Playground is
  honestly unavailable:
  - `ImagePlaygroundViewController.isAvailable` and the `supportsImagePlayground` environment value are false;
  - `ImageCreator()` throws `.notSupported` on devices without Apple Intelligence (before the iPhone 15 Pro; iPads
    without an M chip or the A17 Pro) and `.unavailable` on the others;
  - the view controller and `imagePlaygroundSheet`, if presented anyway, show "Image Playground Unavailable" with the
    reason; Cancel (or dismissing) ends them as a cancellation (`imagePlaygroundViewControllerDidCancel`,
    `onCancellation`).
- **Objective-C / C interface:** Swift only (as on iOS; the controller and its delegate are `@objc`).
- **Versus Apple's Simulator:** Apple's Simulator uses the Mac's model when Apple Intelligence is on; isim makes no
  images.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ImagePlaygroundViewController` (`isAvailable`, `delegate`, `Delegate`, `concepts`, `sourceImage`, `selectedGenerationStyle`, `allowedGenerationStyles`, `personalizationPolicy`, `options`) | 🧩 | 18.1 | stub: unavailable; presented, it says so and Cancel calls `imagePlaygroundViewControllerDidCancel`; tested (HelloImagePlayground, test_imageplayground) |
| SwiftUI: `imagePlaygroundSheet` (every form), `imagePlaygroundGenerationStyle(_:in:)`, `imagePlaygroundPersonalizationPolicy(_:)`, `imagePlaygroundOptions(_:)`, `supportsImagePlayground` and the other environment values | 🧩 | 18.1 | stub: `supportsImagePlayground` is false; the sheet says Image Playground is unavailable and calls `onCancellation` when closed; the modifiers set the environment values; tested (HelloImagePlayground) |
| `ImageCreator` (`init()`, `availableStyles`, `images(for:style:limit:)`, `images(for:style:options:limit:)`, `CreatedImage`, `Error`) | 🧩 | 18.4 | stub: `init()` throws `.notSupported` or `.unavailable` (device eligibility); tested (HelloImagePlayground on an iPhone 17 and an iPhone 15) |
| `ImagePlaygroundConcept` (`text`, `extracted(from:title:)`, `drawing`, `image` from a CGImage or a URL), `ImagePlaygroundStyle` (`animation`, `illustration`, `sketch`, `emoji`, `externalProvider`, `any`, `all`, `id`), `ImagePlaygroundPersonalizationPolicy`, `ImagePlaygroundOptions` (creation strategy, variety, personalization, size) | ✅ | 18.1 | adapted: values; tested (HelloImagePlayground) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
