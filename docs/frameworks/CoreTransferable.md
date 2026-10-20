# CoreTransferable

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 70.8% of Apple's iOS API (46 of 65, exact) · **Rows:** 1: 1 ❌ · **iOS:** 16.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [Core Transferable](https://developer.apple.com/documentation/coretransferable) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Adapted:** isim's own `Transferable` with data, file and proxy representations. Rows: [UniformTypeIdentifiers](UniformTypeIdentifiers.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Transferable`, `TransferRepresentationBuilder`, `DataRepresentation`, `FileRepresentation` (`SentTransferredFile`, `ReceivedTransferredFile`), `ProxyRepresentation`; `Data`, `String`, `URL` (and SwiftUI `Image`) conformances | 🟡 | 16.0 | adapted: representations import and export through data (a file representation reads its file, or writes a temporary one for its importer); `shouldAttemptToOpenInPlace` is accepted, not honoured; used by ShareLink, drag and drop, PasteButton and PhotosPicker; tested (UTTypesTest, HelloScrollAndLists, HelloSwiftUIControls, HelloDragDrop) |
| `CodableRepresentation` (`init(contentType:)` with JSON, `init(contentType:encoder:decoder:)`, `init(for:…)`) | ✅ | 16.0 | adapted: Combine's `TopLevelEncoder` / `TopLevelDecoder` (JSONEncoder, PropertyListEncoder, …); tested (UTTypesTest: JSON and a property list) |
| `TransferRepresentationVisibility` (`.all`, `.team`, `.group`, `.ownProcess`), `visibility(_:)` | 🟡 | 16.0 | adapted: passed to the drag's NSItemProvider as its representation visibility; isim runs one app at a time, so only `.ownProcess` changes what another app could receive; tested (UTTypesTest) |
| `suggestedFileName(_:)` (a name, or one per item) | ✅ | 16.0 | adapted: the file ShareLink shares a representation as (with the type's filename extension), and the drag's suggested name; tested (UTTypesTest) |
| `exportingCondition(_:)` | ✅ | 16.0 | adapted: a representation whose condition fails for an item is left out of its export, its drag and its share; tested (UTTypesTest) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `TupleTransferRepresentation` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
19 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`CodableRepresentation`](https://developer.apple.com/documentation/coretransferable/codablerepresentation)
- [`init(for: Item.Type, contentType: UTType)`](https://developer.apple.com/documentation/coretransferable/codablerepresentation/init(for:contenttype:))
- [`init(for: Item.Type, contentType: UTType, encoder: Encoder, decoder: Decoder)`](https://developer.apple.com/documentation/coretransferable/codablerepresentation/init(for:contenttype:encoder:decoder:))
- [`func export(to: URL, contentType: UTType?) async throws -> URL`](https://developer.apple.com/documentation/coretransferable/transferable/export(to:contenttype:))
- [`init(importing: URL, contentType: UTType?) async throws`](https://developer.apple.com/documentation/coretransferable/transferable/init(importing:contenttype:)-4pfpm)
- [`init(importing: Data, contentType: UTType?) async throws`](https://developer.apple.com/documentation/coretransferable/transferable/init(importing:contenttype:)-74t08)
- [`var suggestedFilename: String?`](https://developer.apple.com/documentation/coretransferable/transferable/suggestedfilename)
- [`func withExportedFile<Result>(contentType: UTType?, fileHandler: (URL) async throws -> Result) async throws -> Result`](https://developer.apple.com/documentation/coretransferable/transferable/withexportedfile(contenttype:filehandler:))
- [`Body`](https://developer.apple.com/documentation/coretransferable/transferrepresentation/body-swift.associatedtype)
- [`var body: Self.Body`](https://developer.apple.com/documentation/coretransferable/transferrepresentation/body-swift.property)
- [`func exportingCondition((Self.Item) -> Bool) -> _ConditionalTransferRepresentation<Self>`](https://developer.apple.com/documentation/coretransferable/transferrepresentation/exportingcondition(_:))
- [`func suggestedFileName(String) -> some TransferRepresentation<Self.Item>
`](https://developer.apple.com/documentation/coretransferable/transferrepresentation/suggestedfilename(_:)-2yln2)
- [`func suggestedFileName((Self.Item) -> String?) -> some TransferRepresentation<Self.Item>
`](https://developer.apple.com/documentation/coretransferable/transferrepresentation/suggestedfilename(_:)-47rg0)
- [`func visibility(TransferRepresentationVisibility) -> some TransferRepresentation<Self.Item>
`](https://developer.apple.com/documentation/coretransferable/transferrepresentation/visibility(_:))
- [`TransferRepresentationVisibility`](https://developer.apple.com/documentation/coretransferable/transferrepresentationvisibility)
- [`static let all: TransferRepresentationVisibility`](https://developer.apple.com/documentation/coretransferable/transferrepresentationvisibility/all)
- [`static let ownProcess: TransferRepresentationVisibility`](https://developer.apple.com/documentation/coretransferable/transferrepresentationvisibility/ownprocess)
- [`static let team: TransferRepresentationVisibility`](https://developer.apple.com/documentation/coretransferable/transferrepresentationvisibility/team)
- [`TupleTransferRepresentation`](https://developer.apple.com/documentation/coretransferable/tupletransferrepresentation)

</details>
<!-- /generated:missing -->
