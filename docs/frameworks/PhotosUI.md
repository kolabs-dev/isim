# PhotosUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 54.1% of Apple's iOS API (139 of 257, exact) · **Rows:** 4: 1 ✅ 1 🟡 2 ❌ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [PhotosUI](https://developer.apple.com/documentation/photosui) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Adapted:** a grid picker drawn by isim (images only).
- **Objective-C:** `#import <PhotosUI/PhotosUI.h>` and `-framework PhotosUI`: `PHPickerViewController` is the Swift class; `PHPickerConfiguration`, `PHPickerFilter` and `PHPickerResult` are Swift structs, so Objective-C has classes of its own (`isim/frameworks/PhotosUI/PhotosUI.m`), which the picker reads and makes (`isim/swift/overlays/PhotosUI/ObjC.swift`).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| PhotosUI `PhotosPicker` / `PHPickerViewController` | 🟡 | ≤17 | adapted: a grid of the device photo library, outside the app's permission; single and multiple selection; `NSItemProvider` results (photos as data, videos as files: `loadFileRepresentation`); `PhotosPickerItem.loadTransferable(type:)` for `Data`, `Image` and file-based `Transferable` types (a movie); videos show their duration; tested (HelloPhotos, test_photos, test_photos_videos_albums). Missing: inline picker configuration (iOS 17) |
| `PHPickerFilter` (`images`, `videos`, `any(of:)`, `all(of:)`, `not(_:)`) | ✅ | ≤17 | adapted: the picker offers only the items the filter matches; isim's library has photos and videos only, so `livePhotos`, `screenshots`, `panoramas`, `depthEffectPhotos`, `bursts`, `slomoVideos`, `timelapseVideos`, `cinematicVideos` and `spatialMedia` match nothing; tested (test_photos_videos_albums) |
| PhotosUI's Objective-C interface: `PHPickerViewController` (`initWithConfiguration:`, `configuration`, `delegate`, `deselectAssetsWithIdentifiers:`, `moveAssetWithIdentifier:afterAssetWithIdentifier:`, `scrollToInitialPosition`), `PHPickerConfiguration` (`initWithPhotoLibrary:`, `selectionLimit`, `filter`, `selection`, `preferredAssetRepresentationMode`, `preselectedAssetIdentifiers`), `PHPickerFilter` (the kinds, `anyFilterMatchingSubfilters:`, `allFilterMatchingSubfilters:`, `notFilterOfSubfilter:`, `playbackStyleFilter:`), `PHPickerResult`, `PHPickerViewControllerDelegate` | ✅ | ≤17 | adapted: as the Swift picker; the configuration's `mode`, `edgesWithoutContentMargins` and `disabledCapabilities` (iOS 17's inline picker) are not declared. Tested (tests/photos-objc: a photo-library configuration with a limit of two and a combined filter, two picks with identifiers, loaded as an image) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `PHContentEditingController`, `PHLivePhotoView` (2 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `PHPickerMetadataOptions`, `PHPickerSearchText`, `PHSharedAlbumCreationConfiguration`, `PHSharedAlbumCreationResult`, `PHSharedAlbumCreationSharingPolicy`, `PHSharedAlbumCreationViewController`, `PHSharedAlbumCustomizationViewController`, `PHSharedAlbumPostingViewController` (8 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
118 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`PHContentEditingController`](https://developer.apple.com/documentation/photosui/phcontenteditingcontroller)
- [`func cancelContentEditing()`](https://developer.apple.com/documentation/photosui/phcontenteditingcontroller/cancelcontentediting())
- [`func canHandle(PHAdjustmentData) -> Bool`](https://developer.apple.com/documentation/photosui/phcontenteditingcontroller/canhandle(_:))
- [`func finishContentEditing(completionHandler: (PHContentEditingOutput?) -> Void)`](https://developer.apple.com/documentation/photosui/phcontenteditingcontroller/finishcontentediting(completionhandler:))
- [`var shouldShowCancelConfirmation: Bool`](https://developer.apple.com/documentation/photosui/phcontenteditingcontroller/shouldshowcancelconfirmation)
- [`func startContentEditing(with: PHContentEditingInput, placeholderImage: UIImage)`](https://developer.apple.com/documentation/photosui/phcontenteditingcontroller/startcontentediting(with:placeholderimage:))
- [`PHLivePhotoBadgeOptions`](https://developer.apple.com/documentation/photosui/phlivephotobadgeoptions)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/photosui/phlivephotobadgeoptions/init(rawvalue:))
- [`static var liveOff: PHLivePhotoBadgeOptions`](https://developer.apple.com/documentation/photosui/phlivephotobadgeoptions/liveoff)
- [`static var overContent: PHLivePhotoBadgeOptions`](https://developer.apple.com/documentation/photosui/phlivephotobadgeoptions/overcontent)
- [`PHLivePhotoView`](https://developer.apple.com/documentation/photosui/phlivephotoview)
- [`var contentsRect: CGRect`](https://developer.apple.com/documentation/photosui/phlivephotoview/contentsrect)
- [`var delegate: (any PHLivePhotoViewDelegate)?`](https://developer.apple.com/documentation/photosui/phlivephotoview/delegate)
- [`var intrinsicContentSize: CGSize`](https://developer.apple.com/documentation/photosui/phlivephotoview/intrinsiccontentsize)
- [`var isMuted: Bool`](https://developer.apple.com/documentation/photosui/phlivephotoview/ismuted)
- [`var livePhoto: PHLivePhoto?`](https://developer.apple.com/documentation/photosui/phlivephotoview/livephoto)
- [`class func livePhotoBadgeImage(options: PHLivePhotoBadgeOptions) -> UIImage`](https://developer.apple.com/documentation/photosui/phlivephotoview/livephotobadgeimage(options:))
- [`var playbackGestureRecognizer: UIGestureRecognizer`](https://developer.apple.com/documentation/photosui/phlivephotoview/playbackgesturerecognizer)
- [`func startPlayback(with: PHLivePhotoViewPlaybackStyle)`](https://developer.apple.com/documentation/photosui/phlivephotoview/startplayback(with:))
- [`func stopPlayback()`](https://developer.apple.com/documentation/photosui/phlivephotoview/stopplayback())
- [`PHLivePhotoViewDelegate`](https://developer.apple.com/documentation/photosui/phlivephotoviewdelegate)
- [`func livePhotoView(PHLivePhotoView, canBeginPlaybackWith: PHLivePhotoViewPlaybackStyle) -> Bool`](https://developer.apple.com/documentation/photosui/phlivephotoviewdelegate/livephotoview(_:canbeginplaybackwith:))
- [`func livePhotoView(PHLivePhotoView, didEndPlaybackWith: PHLivePhotoViewPlaybackStyle)`](https://developer.apple.com/documentation/photosui/phlivephotoviewdelegate/livephotoview(_:didendplaybackwith:))
- [`func livePhotoView(PHLivePhotoView, extraMinimumTouchDurationFor: UITouch, with: PHLivePhotoViewPlaybackStyle) -> TimeInterval`](https://developer.apple.com/documentation/photosui/phlivephotoviewdelegate/livephotoview(_:extraminimumtouchdurationfor:with:))
- [`func livePhotoView(PHLivePhotoView, willBeginPlaybackWith: PHLivePhotoViewPlaybackStyle)`](https://developer.apple.com/documentation/photosui/phlivephotoviewdelegate/livephotoview(_:willbeginplaybackwith:))
- [`PHLivePhotoViewPlaybackStyle`](https://developer.apple.com/documentation/photosui/phlivephotoviewplaybackstyle)
- [`case full`](https://developer.apple.com/documentation/photosui/phlivephotoviewplaybackstyle/full)
- [`case hint`](https://developer.apple.com/documentation/photosui/phlivephotoviewplaybackstyle/hint)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/photosui/phlivephotoviewplaybackstyle/init(rawvalue:))
- [`case undefined`](https://developer.apple.com/documentation/photosui/phlivephotoviewplaybackstyle/undefined)
- [`PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities)
- [`PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities)
- [`static var collectionNavigation: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/collectionnavigation)
- [`static var collectionNavigation: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/collectionnavigation)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/photosui/phpickercapabilities/init(rawvalue:))
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/photosui/phpickercapabilities/init(rawvalue:))
- [`static var search: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/search)
- [`static var search: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/search)
- [`static var selectionActions: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/selectionactions)
- [`static var selectionActions: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/selectionactions)
- [`static var sensitivityAnalysisIntervention: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/sensitivityanalysisintervention)
- [`static var sensitivityAnalysisIntervention: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/sensitivityanalysisintervention)
- [`static var stagingArea: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/stagingarea)
- [`static var stagingArea: PHPickerCapabilities`](https://developer.apple.com/documentation/photosui/phpickercapabilities/stagingarea)
- [`var metadataOptions: PHPickerMetadataOptions`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/metadataoptions)
- [`var metadataOptions: PHPickerMetadataOptions`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/metadataoptions)
- [`var searchText: PHPickerSearchText?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/searchtext)
- [`var searchText: PHPickerSearchText?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/searchtext)
- [`var edgesWithoutContentMargins: NSDirectionalRectEdge?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/edgeswithoutcontentmargins)
- [`var edgesWithoutContentMargins: NSDirectionalRectEdge?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/edgeswithoutcontentmargins)
- [`init()`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/init())
- [`init()`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/init())
- [`var searchText: PHPickerSearchText?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/searchtext)
- [`var searchText: PHPickerSearchText?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/searchtext)
- [`var selectionLimit: Int?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/selectionlimit)
- [`var selectionLimit: Int?`](https://developer.apple.com/documentation/photosui/phpickerconfiguration-swift.struct/update/selectionlimit)
- [`PHPickerConfigurationSelection`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection)
- [`PHPickerConfigurationSelection`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection)
- [`case continuous`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/continuous)
- [`case continuous`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/continuous)
- [`case continuousAndOrdered`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/continuousandordered)
- [`case continuousAndOrdered`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/continuousandordered)
- [`case `default``](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/default)
- [`case `default``](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/default)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/init(rawvalue:))
- [`case ordered`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/ordered)
- [`case ordered`](https://developer.apple.com/documentation/photosui/phpickerconfigurationselection/ordered)
- [`static let screenRecordings: PHPickerFilter`](https://developer.apple.com/documentation/photosui/phpickerfilter-swift.struct/screenrecordings)
- [`static let screenRecordings: PHPickerFilter`](https://developer.apple.com/documentation/photosui/phpickerfilter-swift.struct/screenrecordings)
- [`static let screenRecordings: PHPickerFilter`](https://developer.apple.com/documentation/photosui/phpickerfilter-swift.struct/screenrecordings)
- [`PHPickerMetadataOptions`](https://developer.apple.com/documentation/photosui/phpickermetadataoptions)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/photosui/phpickermetadataoptions/init(rawvalue:))
- [`static var removeCaptions: PHPickerMetadataOptions`](https://developer.apple.com/documentation/photosui/phpickermetadataoptions/removecaptions)
- [`static var removeLocation: PHPickerMetadataOptions`](https://developer.apple.com/documentation/photosui/phpickermetadataoptions/removelocation)
- [`PHPickerMode`](https://developer.apple.com/documentation/photosui/phpickermode-swift.struct)
- [`PHPickerMode`](https://developer.apple.com/documentation/photosui/phpickermode-swift.struct)
- [`static var compact: PHPickerMode`](https://developer.apple.com/documentation/photosui/phpickermode-swift.struct/compact)
- [`static var compact: PHPickerMode`](https://developer.apple.com/documentation/photosui/phpickermode-swift.struct/compact)
- [`static let `default`: PHPickerMode`](https://developer.apple.com/documentation/photosui/phpickermode-swift.struct/default)
- [`static let `default`: PHPickerMode`](https://developer.apple.com/documentation/photosui/phpickermode-swift.struct/default)
- [`PHPickerSearchText`](https://developer.apple.com/documentation/photosui/phpickersearchtext-swift.struct)
- [`init(String)`](https://developer.apple.com/documentation/photosui/phpickersearchtext-swift.struct/init(_:))
- [`init(photoSearchSuggestion: UIPhotoSearchSuggestion)`](https://developer.apple.com/documentation/photosui/phpickersearchtext-swift.struct/init(photosearchsuggestion:))
- [`func updatePicker(using: PHPickerConfiguration.Update)`](https://developer.apple.com/documentation/photosui/phpickerviewcontroller/updatepicker(using:))
- [`func zoomIn()`](https://developer.apple.com/documentation/photosui/phpickerviewcontroller/zoomin())
- [`func zoomOut()`](https://developer.apple.com/documentation/photosui/phpickerviewcontroller/zoomout())
- [`PHSharedAlbumCreationConfiguration`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationconfiguration-swift.struct)
- [`var defaultPolicy: PHSharedAlbumCreationSharingPolicy`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationconfiguration-swift.struct/defaultpolicy)
- [`var defaultTitle: String?`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationconfiguration-swift.struct/defaulttitle)
- [`init(photoLibrary: PHPhotoLibrary)`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationconfiguration-swift.struct/init(photolibrary:))
- [`let photoLibrary: PHPhotoLibrary`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationconfiguration-swift.struct/photolibrary)
- [`PHSharedAlbumCreationResult`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationresult-swift.struct)
- [`var albumIdentifier: String?`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationresult-swift.struct/albumidentifier)
- [`var albumURL: URL?`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationresult-swift.struct/albumurl)
- [`var error: (any Error)?`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationresult-swift.struct/error)
- [`PHSharedAlbumCreationSharingPolicy`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationsharingpolicy)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationsharingpolicy/init(rawvalue:))
- [`case `private``](https://developer.apple.com/documentation/photosui/phsharedalbumcreationsharingpolicy/private)
- [`case `public``](https://developer.apple.com/documentation/photosui/phsharedalbumcreationsharingpolicy/public)
- [`PHSharedAlbumCreationViewController`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationviewcontroller)
- [`var creationResult: __PHSharedAlbumCreationResult?`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationviewcontroller/creationresult)
- [`var delegate: (any PHSharedAlbumCreationViewController.Delegate)?`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationviewcontroller/delegate-swift.property)
- [`PHSharedAlbumCreationViewController.Delegate`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationviewcontroller/delegate-swift.protocol)
- [`func sharedAlbumCreationViewController(PHSharedAlbumCreationViewController, didCompleteWithError: (any Error)?)`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationviewcontroller/delegate-swift.protocol/sharedalbumcreationviewcontroller(_:didcompletewitherror:))
- [`convenience init(configuration: PHSharedAlbumCreationConfiguration)`](https://developer.apple.com/documentation/photosui/phsharedalbumcreationviewcontroller/init(configuration:))
- [`PHSharedAlbumCustomizationViewController`](https://developer.apple.com/documentation/photosui/phsharedalbumcustomizationviewcontroller)
- [`var albumIdentifier: String`](https://developer.apple.com/documentation/photosui/phsharedalbumcustomizationviewcontroller/albumidentifier)
- [`var delegate: (any PHSharedAlbumCustomizationViewController.Delegate)?`](https://developer.apple.com/documentation/photosui/phsharedalbumcustomizationviewcontroller/delegate-swift.property)
- [`PHSharedAlbumCustomizationViewController.Delegate`](https://developer.apple.com/documentation/photosui/phsharedalbumcustomizationviewcontroller/delegate-swift.protocol)
- [`func sharedAlbumCustomizationViewController(PHSharedAlbumCustomizationViewController, didCompleteWithError: (any Error)?)`](https://developer.apple.com/documentation/photosui/phsharedalbumcustomizationviewcontroller/delegate-swift.protocol/sharedalbumcustomizationviewcontroller(_:didcompletewitherror:))
- [`init(albumIdentifier: String, photoLibrary: PHPhotoLibrary)`](https://developer.apple.com/documentation/photosui/phsharedalbumcustomizationviewcontroller/init(albumidentifier:photolibrary:))
- [`PHSharedAlbumPostingViewController`](https://developer.apple.com/documentation/photosui/phsharedalbumpostingviewcontroller)
- [`var albumIdentifier: String?`](https://developer.apple.com/documentation/photosui/phsharedalbumpostingviewcontroller/albumidentifier)
- [`var delegate: (any PHSharedAlbumPostingViewController.Delegate)?`](https://developer.apple.com/documentation/photosui/phsharedalbumpostingviewcontroller/delegate-swift.property)
- [`PHSharedAlbumPostingViewController.Delegate`](https://developer.apple.com/documentation/photosui/phsharedalbumpostingviewcontroller/delegate-swift.protocol)
- [`func sharedAlbumPostingViewController(PHSharedAlbumPostingViewController, didCompleteWithError: (any Error)?)`](https://developer.apple.com/documentation/photosui/phsharedalbumpostingviewcontroller/delegate-swift.protocol/sharedalbumpostingviewcontroller(_:didcompletewitherror:))
- [`convenience init(items: [PHPickerResult], defaultAlbumIdentifier: String?, photoLibrary: PHPhotoLibrary)`](https://developer.apple.com/documentation/photosui/phsharedalbumpostingviewcontroller/init(items:defaultalbumidentifier:photolibrary:))

</details>
<!-- /generated:missing -->
