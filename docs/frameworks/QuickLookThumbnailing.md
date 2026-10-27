# QuickLookThumbnailing

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Graphics & text](../COVERAGE.md#graphics) · **Apple:** [QuickLookThumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing) · **Issues:** [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

## How isim implements it

- **Approach:** adapted. isim's own Objective-C framework (`isim/frameworks/QuickLookThumbnailing`) makes thumbnails
  one request after another on the main thread (isim draws on one thread) and calls the handlers on a queue of its own:
  - an app's Thumbnail extension for the file's type comes first: `com.apple.quicklook.thumbnail`, its
    `QLThumbnailProvider` loaded into the app the way Quick Look Preview extensions are ([QuickLook](QuickLook.md));
  - otherwise isim draws them: images through ImageIO, PDFs through PDFKit (the first page, on white), videos through
    the host's ffmpeg (a frame), text files as a page of their first lines;
  - every file has an icon: a document with a folded corner and its filename extension.
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/QuickLookThumbnailing`. The `UTType` forms
  (`Request.contentType`, `saveBestRepresentation(for:to:as:completion:)`) come from isim's QuickLookThumbnailing
  Swift overlay.
- **Versus Apple's Simulator:**
  - icons are isim's generic document icon, not the type's own icon;
  - the low-quality thumbnail is the thumbnail at a quarter of its pixels, delivered first;
  - nothing is cached between requests, so `noCachedThumbnail` and `noCloudThumbnail` are never reported.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `QLThumbnailGenerator` (`shared`, `generateBestRepresentation(for:completion:)`, `generateRepresentations(for:update:)`, `cancel(_:)`, `saveBestRepresentation(for:to:contentType:completion:)`, `saveBestRepresentation(for:to:as:completion:)`) | ✅ | 13.0 | adapted: the representations asked for, in order (icon, low quality, thumbnail), fitted to the request's size at its scale; the best is the thumbnail, or the icon in `iconMode` or when no thumbnail can be made; saved as PNG, JPEG or HEIC through ImageIO. Tested: test_quicklook_thumbnails (HelloQuickLookExtensions) |
| `QLThumbnailGenerator.Request` (`init(fileAt:size:scale:representationTypes:)`, `size`, `scale`, `representationTypes`, `minimumDimension`, `iconMode`, `contentType`, NSSecureCoding), `RepresentationTypes` | ✅ | 13.0 | adapted: `contentType` defaults to the file's type by its filename extension; a thumbnail smaller than `minimumDimension` fails. Tested: test_quicklook_thumbnails |
| `QLThumbnailRepresentation` (`type`, `cgImage`, `uiImage`, `contentRect`), `RepresentationType` | ✅ | 13.0 | adapted: an icon's `contentRect` is its page within the square. Tested: test_quicklook_thumbnails |
| `QLThumbnailProvider`, `QLFileThumbnailRequest` (`fileURL`, `maximumSize`, `minimumSize`, `scale`), `QLThumbnailReply` (`init(contextSize:drawing:)`, `init(contextSize:currentContextDrawing:)`, `init(imageFileURL:)`, `extensionBadge`) | ✅ | 13.0 | adapted: a Thumbnail extension's principal class, loaded into the app that asks; a drawing is in a bitmap context of the size at the request's scale (origin at the bottom left, or UIKit's current context y-down); `extensionBadge` is kept, not drawn. Tested: test_quicklook_thumbnails (the RecipeThumbnail extension) |
| `QLThumbnailError` (`generationFailed`, `savingToURLFailed`, `noCachedThumbnail`, `noCloudThumbnail`, `requestInvalid`, `requestCancelled`), `QLThumbnailErrorDomain` | ✅ | 13.0 | adapted: a missing or unthumbnailable file is `generationFailed`, a cancelled request `requestCancelled`. Tested: test_quicklook_thumbnails |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
