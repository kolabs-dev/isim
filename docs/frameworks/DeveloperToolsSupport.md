# DeveloperToolsSupport

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 31.2% of Apple's iOS API (20 of 64, exact) · **Rows:** 5: 2 ✅ 3 ❌ · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [Developer tools](../COVERAGE.md#devtools) · **Apple:** [DeveloperToolsSupport](https://developer.apple.com/documentation/developertoolssupport) · **Issues:** [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

## How isim implements it

- **Adapted:** the preview types; `#Preview` is expanded by isim's macro plugin and rendered by `isim preview`. Rows: [SwiftUI](SwiftUI.md) and [Platform](Platform.md).
- **Adapted:** the asset catalog resources `ImageResource` and `ColorResource` (`isim/swift/overlays/DeveloperToolsSupport.swift`) name an asset and its bundle; `isim build` generates Xcode's `GeneratedAssetSymbols.swift` / `.h` naming them, and UIKit and SwiftUI load them from isim's asset catalog format.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ImageResource`, `ColorResource` (`init(name:bundle:)`) | ✅ | ≤17 | an asset's name and bundle; `UIImage(resource:)` / `UIColor(resource:)` and SwiftUI's `Image(_:)` / `Color(_:)` load them (iOS 17 in Apple's documentation; usable with older deployment targets, as Xcode 15+ generates them). Tested (HelloAssetSymbols: test_asset_symbols) |
| Generated asset symbols (`GeneratedAssetSymbols.swift` / `.h`) | ✅ | ≤17 | `isim build` writes them for the target's asset catalogs like Xcode: `ColorResource` / `ImageResource` members (`ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS`, default YES; names in lower camel case without a trailing "Color" / "Image": "AccentColor" is `.accent`, "hero-image" is `.hero`), with `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` (YES in new projects) `UIColor` / `UIImage` / `Color` / `ShapeStyle` members for `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS` (default SwiftUI and UIKit), and `ACColorName…` / `ACImageName…` constants for Objective-C; Swift packages get them over `Bundle.module` (unverified). Namespaced folders (`provides-namespace`) are not supported, as in isim's asset catalogs. Tested (HelloAssetSymbols: test_generated_asset_symbols_source, test_asset_symbols, test_asset_symbols_dark) |
| `PreviewTrait` (`init(_:...)` combining traits; the layouts and orientations; `.modifier(_:)` from SwiftUI) | ✅ | ≤17 | adapted: `isim preview` applies the layout traits (default, size that fits, fixed) of the combined traits in order, and a SwiftUI PreviewModifier's body around the content. Tested (HelloSwiftUI previews: test_previews) |
| `LibraryContentProvider`, `LibraryItem` (`Category`), `LibraryContentBuilder` | ✅ | ≤17 | stub: they compile and type-check; isim has no Xcode library to show the items. Built in HelloSwiftUI (`SampleLibrary`) |
| `PreviewMacroBodyBuilder` | ✅ | ≤17 | adapted: the body builder of the UIKit `#Preview` macros (one UIView or UIViewController, after any statements); SwiftUI's `#Preview` takes a `@ViewBuilder` body. Tested (HelloSwiftUI previews: test_previews) |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `PreviewBodyBuilder` (1 type; with its members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `PreviewArguments` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
44 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`LibraryContentBuilder`](https://developer.apple.com/documentation/developertoolssupport/librarycontentbuilder)
- [`static func buildBlock([LibraryItem]...) -> [LibraryItem]`](https://developer.apple.com/documentation/developertoolssupport/librarycontentbuilder/buildblock(_:))
- [`static func buildExpression(LibraryItem) -> [LibraryItem]`](https://developer.apple.com/documentation/developertoolssupport/librarycontentbuilder/buildexpression(_:)-8x2oz)
- [`static func buildExpression([LibraryItem]) -> [LibraryItem]`](https://developer.apple.com/documentation/developertoolssupport/librarycontentbuilder/buildexpression(_:)-90ip4)
- [`LibraryContentProvider`](https://developer.apple.com/documentation/developertoolssupport/librarycontentprovider)
- [`ModifierBase`](https://developer.apple.com/documentation/developertoolssupport/librarycontentprovider/modifierbase)
- [`func modifiers(base: Self.ModifierBase) -> [LibraryItem]`](https://developer.apple.com/documentation/developertoolssupport/librarycontentprovider/modifiers(base:))
- [`func modifiers(base: Self.ModifierBase) -> [LibraryItem]`](https://developer.apple.com/documentation/developertoolssupport/librarycontentprovider/modifiers(base:)-4gfkr)
- [`var views: [LibraryItem]`](https://developer.apple.com/documentation/developertoolssupport/librarycontentprovider/views)
- [`var views: [LibraryItem]`](https://developer.apple.com/documentation/developertoolssupport/librarycontentprovider/views-6n3zo)
- [`LibraryItem`](https://developer.apple.com/documentation/developertoolssupport/libraryitem)
- [`LibraryItem.Category`](https://developer.apple.com/documentation/developertoolssupport/libraryitem/category)
- [`static let control: LibraryItem.Category`](https://developer.apple.com/documentation/developertoolssupport/libraryitem/category/control)
- [`static let effect: LibraryItem.Category`](https://developer.apple.com/documentation/developertoolssupport/libraryitem/category/effect)
- [`static let layout: LibraryItem.Category`](https://developer.apple.com/documentation/developertoolssupport/libraryitem/category/layout)
- [`static let other: LibraryItem.Category`](https://developer.apple.com/documentation/developertoolssupport/libraryitem/category/other)
- [`init<SnippetExpressionType>(@autoclosure () -> SnippetExpressionType, visible: Bool, title: String?, category: LibraryItem.Category, matchingSignature: String?)`](https://developer.apple.com/documentation/developertoolssupport/libraryitem/init(_:visible:title:category:matchingsignature:))
- [`init<Attributes>(String?, as: ActivityPreviewViewKind, using: Attributes, widget: () -> some Widget, contentStates: () async -> [Attributes.ContentState])`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:as:using:widget:contentstates:))
- [`init<Provider>(String?, as: WidgetFamily, using: Provider.Intent, widget: () -> some Widget, timelineProvider: () -> Provider)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:as:using:widget:timelineprovider:)-1if5u)
- [`init<Provider>(String?, as: WidgetFamily, using: Provider.Intent, widget: () -> some Widget, timelineProvider: () -> Provider)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:as:using:widget:timelineprovider:)-5335n)
- [`init(String?, as: WidgetFamily, widget: () -> some Widget, timeline: () async -> [any TimelineEntry])`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:as:widget:timeline:))
- [`init(String?, as: WidgetFamily, widget: () -> some Widget, timelineProvider: () -> some TimelineProvider)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:as:widget:timelineprovider:))
- [`init<T>(String?, traits: PreviewTrait<Preview.ViewTraits>..., arguments: [T], body: (T) -> any View)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:traits:arguments:body:)-1xqo1)
- [`init<T>(String?, traits: PreviewTrait<Preview.ViewTraits>..., arguments: [T], body: (T) -> UIViewController)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:traits:arguments:body:)-287km)
- [`init<T>(String?, traits: PreviewTrait<Preview.ViewTraits>..., arguments: [T], body: (T) -> UIView)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:traits:arguments:body:)-3q0i9)
- [`init(String?, traits: PreviewTrait<Preview.ViewTraits>..., body: () -> UIView)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:traits:body:)-3i54d)
- [`init(String?, traits: PreviewTrait<Preview.ViewTraits>..., body: () -> any View)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:traits:body:)-8pemr)
- [`init(String?, traits: PreviewTrait<Preview.ViewTraits>..., body: () -> UIViewController)`](https://developer.apple.com/documentation/developertoolssupport/preview/init(_:traits:body:)-941vb)
- [`PreviewArguments`](https://developer.apple.com/documentation/developertoolssupport/previewarguments)
- [`PreviewBodyBuilder`](https://developer.apple.com/documentation/developertoolssupport/previewbodybuilder)
- [`static func buildBlock(Content) -> Content`](https://developer.apple.com/documentation/developertoolssupport/previewbodybuilder/buildblock(_:))
- [`PreviewLayout`](https://developer.apple.com/documentation/developertoolssupport/previewlayout)
- [`case device`](https://developer.apple.com/documentation/developertoolssupport/previewlayout/device)
- [`case fixed(width: CGFloat, height: CGFloat)`](https://developer.apple.com/documentation/developertoolssupport/previewlayout/fixed(width:height:))
- [`case sizeThatFits`](https://developer.apple.com/documentation/developertoolssupport/previewlayout/sizethatfits)
- [`PreviewMacroBodyBuilder`](https://developer.apple.com/documentation/developertoolssupport/previewmacrobodybuilder)
- [`static func buildBlock(Content) -> Content`](https://developer.apple.com/documentation/developertoolssupport/previewmacrobodybuilder/buildblock(_:))
- [`static var preview: Preview`](https://developer.apple.com/documentation/developertoolssupport/previewregistry/preview)
- [`static var preview: Preview`](https://developer.apple.com/documentation/developertoolssupport/previewregistry/preview-32pcg)
- [`static var assistiveAccess: PreviewTrait<Preview.ViewTraits>`](https://developer.apple.com/documentation/developertoolssupport/previewtrait/assistiveaccess)
- [`init(PreviewTrait<T>...)`](https://developer.apple.com/documentation/developertoolssupport/previewtrait/init(_:))
- [`static func modifier(some PreviewModifier) -> PreviewTrait<T>`](https://developer.apple.com/documentation/developertoolssupport/previewtrait/modifier(_:))
- [`PreviewUnavailable`](https://developer.apple.com/documentation/developertoolssupport/previewunavailable)
- [`init()`](https://developer.apple.com/documentation/developertoolssupport/previewunavailable/init())

</details>
<!-- /generated:missing -->
