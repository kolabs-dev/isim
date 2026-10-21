# LinkPresentation

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [LinkPresentation](https://developer.apple.com/documentation/linkpresentation) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Approach:** isim's own Swift overlay (`isim/swift/overlays/LinkPresentation`).
  - `LPMetadataProvider` loads the page with `URLSession`.
  - It reads the page's HTML: `<title>`, the Open Graph and Twitter card tags, and the icon links.
  - With `shouldFetchSubresources`, it downloads the icon and the image.
  - `LPLinkView` is isim's drawing of iOS's rich link card.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/LinkPresentation` over the overlay's classes, with Apple's names and selectors. `LPErrorDomain` is in `isim/frameworks/LinkPresentation`.
- **Versus Apple's Simulator:** the same metadata from the same tags. The pages come from the host's network; tests use the local server (`samples/HelloWeb/server.py`). The card is drawn to look like iOS's, not by Apple's renderer.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `LPMetadataProvider` (`startFetchingMetadata(for:)` with a URL or a `URLRequest`, completion and async forms, `cancel()`, `shouldFetchSubresources`, `timeout`) | ✅ | ≤17 | adapted: see the notes below this table. Tested (HelloWeb `-links`, tests/ui/test_web.py::test_web_links) |
| `LPLinkMetadata` (`originalURL`, `url`, `title`, `iconProvider`, `imageProvider`, `videoProvider`, `remoteVideoURL`, `NSCopying`, `NSSecureCoding`) | ✅ | ≤17 | an app can build its own, and `LPLinkView` loads the images its providers hold. Archiving keeps the downloaded icon and image. Tested (HelloWeb `-links`) |
| `LPLinkView` (`init(url:)`, `init(metadata:)`, `metadata`, `sizeThatFits`, `intrinsicContentSize`) | ✅ | ≤17 | adapted: isim's drawing of iOS's card, on the secondary system background with rounded corners (see the notes below). Tested with a screenshot (HelloWeb `-links`) |
| `LPError` / `LPError.Code`, `LPErrorDomain` | ✅ | ≤17 | `metadataFetchFailed`, `metadataFetchCancelled` and `metadataFetchTimedOut` are produced; `unknown` and `metadataFetchNotAllowed` exist but are never produced. Tested |
| Objective-C interface (`LPMetadataProvider`, `LPLinkMetadata`, `LPLinkView`, `LPErrorDomain`, `LPErrorCode`) | ✅ | ≤17 | headers over the overlay's classes. Tested (HelloWebObjC, tests/ui/test_web.py::test_web_objc) |
| `LinkMetadata` (iOS 26, Swift) | ❌ | 26.0 | not yet |

**`LPMetadataProvider` notes:**
- Redirects are followed, and the final URL becomes `url`.
- **Title:** `og:title`, else `twitter:title`, else `<title>` (whitespace collapsed, entities decoded).
- **Image:** `og:image` or `twitter:image`.
- **Video:** `og:video` becomes `remoteVideoURL`.
- **Icon:** `apple-touch-icon`, else `icon`, else `/favicon.ico`.
- With `shouldFetchSubresources`, the icon and the image are downloaded into `NSItemProvider`s holding `UIImage`s. Images the host can't decode (e.g. `.ico`) are left out.
- A link straight to an image gives that image as the preview, and a file URL gives its name.
- **Errors:**
  - an unreachable host, HTTP 4xx/5xx or an unsupported scheme: `metadataFetchFailed`;
  - `cancel()`: `metadataFetchCancelled`;
  - `timeout`: `metadataFetchTimedOut`.
- The completion handler runs on a background queue.
- A provider can start only once: a second start raises `NSInternalInconsistencyException`, as on iOS.

**`LPLinkView` notes:**
- With an image: the image on top (up to 1.91:1), then the title (semibold 15 pt, two lines) and the host (13 pt, secondary).
- Without one: a compact row with the 40 pt icon on the right, or Safari's compass when there is no icon.
- `init(url:)` is a placeholder showing the host.
- A card that grows (an image loaded later) asks its superview to lay out again.
- A tap opens the URL.

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
