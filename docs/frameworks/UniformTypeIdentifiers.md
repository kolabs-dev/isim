# UniformTypeIdentifiers

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 93.3% of Apple's iOS API (320 of 343, exact) · **Rows:** 4: 4 ✅ · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Adapted:** a fixed table of system types (`isim/swift/overlays/UniformTypeIdentifiers`); CoreTransferable is isim's own.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UTType`: system types (identifier, conformance, filename extensions, MIME types), `init(_:)`, `init(filenameExtension:conformingTo:)`, `init(mimeType:conformingTo:)`, `types(tag:tagClass:conformingTo:)`, `tags`, `supertypes`, `conforms(to:)`, `isDeclared` / `isDynamic` / `isPublicType` / `isSystemDeclared`, `localizedDescription`, `referenceURL`, `version`, `Codable` | ✅ | ≤17 | adapted: isim's table of over 140 system types (`markdown`, `yaml`, `gzip`, `bz2`, `tarArchive`, `epub`, `avi`, `mpeg`, `spreadsheet`, `presentation`, scripts and source code, bundles, 3D, certificates, …) with Apple's identifiers and conformance; unknown extensions make dynamic types; system types' `localizedDescription` is their identifier (no localized names); tested (UTTypesTest, UTTypesObjCTest) |
| `UTType(exportedAs:conformingTo:)`, `UTType(importedAs:conformingTo:)` with the app's Info.plist `UTExportedTypeDeclarations` / `UTImportedTypeDeclarations` | ✅ | ≤17 | adapted: declarations read on first use (`UTTypeIdentifier`, `UTTypeConformsTo`, `UTTypeTagSpecification` extensions and MIME types, `UTTypeDescription`, `UTTypeReferenceURL`, `UTTypeVersion`); every lookup (identifier, extension, MIME type, conformance, NSItemProvider, the document picker, the C and Objective-C APIs) sees them; an undeclared exported type only conforms to the given parent; another app's own declaration of an imported type does not exist on isim (one app at a time); tested (UTTypesTest, UTTypesObjCTest) |
| `UTTypeReference` (`UTType.ReferenceType`), the Objective-C interface: the `UTType` class, `UTCoreTypes.h` (`UTTypePNG`, …), `UTTagClassFilenameExtension` / `UTTagClassMIMEType` | ✅ | ≤17 | adapted: `UniformTypeIdentifiers.framework` declares the class over the overlay's `UTTypeReference` (`@objc(UTType)`, `NSSecureCoding`); `UTCoreTypes.h` constants are filled when the framework loads; Swift's `UTType` bridges to it; tested (UTTypesObjCTest) |
| CoreTransferable: `Transferable`, `DataRepresentation`, `FileRepresentation`, `ProxyRepresentation`, `CodableRepresentation` and the representation modifiers | ✅ | ≤17 | see [CoreTransferable.md](CoreTransferable.md) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
23 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`init?(identifier: String, allowUndeclared: Bool)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/init(identifier:allowundeclared:))
- [`init?(tag: String, tagClass: UTTagClass, conformingTo: UTType?)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/init(tag:tagclass:conformingto:))
- [`var isPublic: Bool`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/ispublic)
- [`static let paperkit: UTType`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/paperkit)
- [`convenience init?(String)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(_:))
- [`init(exportedAs: String)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(exportedas:))
- [`init(exportedAs: String, conformingTo: UTType)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(exportedas:conformingto:))
- [`convenience init?(filenameExtension: String)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(filenameextension:))
- [`convenience init?(filenameExtension: String, conformingTo: UTType)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(filenameextension:conformingto:))
- [`convenience init?(filenameExtension: String, conformingToType: UTType)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(filenameextension:conformingtotype:))
- [`convenience init?(identifier: String)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(identifier:))
- [`convenience init?(identifier: String, allowUndeclared: Bool)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(identifier:allowundeclared:))
- [`init(importedAs: String)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(importedas:))
- [`init(importedAs: String, conformingTo: UTType)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(importedas:conformingto:))
- [`convenience init?(mimeType: String)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(mimetype:)-1txq0)
- [`convenience init?(MIMEType: String)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(mimetype:)-7gu84)
- [`convenience init?(mimeType: String, conformingTo: UTType)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(mimetype:conformingto:))
- [`convenience init?(MIMEType: String, conformingToType: UTType)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(mimetype:conformingtotype:))
- [`convenience init?(tag: String, tagClass: String, conformingTo: UTType?)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(tag:tagclass:conformingto:))
- [`convenience init?(tag: String, tagClass: String, conformingToType: UTType?)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(tag:tagclass:conformingtotype:))
- [`convenience init?(tag: String, tagClass: String, conformingToType: UTType?)`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/init(tag:tagclass:conformingtotype:))
- [`var isPublic: Bool`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/ispublic)
- [`class func types(tag: String, tagClass: String, conformingTo: UTType?) -> [UTType]`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttypereference/types(tag:tagclass:conformingto:))

</details>
<!-- /generated:missing -->
