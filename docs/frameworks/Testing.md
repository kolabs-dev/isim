# Testing

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 81.6% of Apple's iOS API (173 of 212, exact) · **Rows:** 100% (1: 1 ✅) · **iOS:** None+
<!-- /generated:header -->

**Area:** [Developer tools](../COVERAGE.md#devtools) · **Apple:** [Testing](https://developer.apple.com/documentation/testing) · **Issues:** [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

## How isim implements it

- **Passthrough:** upstream swift-testing 6.2.4, built for isim.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`, `#require`) | ✅ | ≤17 | swift-testing 6.2.4 built for isim (`isim/buildlib/swift.py`); parameterized tests, async tests, filters/skips from `isim test`, xUnit output; tests run serially by default (`ISIM_SWIFT_TESTING_PARALLEL=1` runs them in parallel, which intermittently aborts with a mutex used after destruction — under investigation); exit tests unavailable (no process spawning, as on iOS); tested (HelloToolchain: AppSwiftTests) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `AttachableAsImage`, `AttachableImageFormat`, `CustomTestReflectable`, `ExitStatus`, `ExitTest` (5 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
39 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AttachableAsImage`](https://developer.apple.com/documentation/testing/attachableasimage)
- [`func withUnsafeBytes<R>(as: AttachableImageFormat, (UnsafeRawBufferPointer) throws -> R) throws -> R`](https://developer.apple.com/documentation/testing/attachableasimage/withunsafebytes(as:_:))
- [`AttachableImageFormat`](https://developer.apple.com/documentation/testing/attachableimageformat)
- [`var contentType: UTType`](https://developer.apple.com/documentation/testing/attachableimageformat/contenttype)
- [`var debugDescription: String`](https://developer.apple.com/documentation/testing/attachableimageformat/debugdescription)
- [`var description: String`](https://developer.apple.com/documentation/testing/attachableimageformat/description)
- [`var encodingQuality: Float`](https://developer.apple.com/documentation/testing/attachableimageformat/encodingquality)
- [`init(contentType: UTType, encodingQuality: Float)`](https://developer.apple.com/documentation/testing/attachableimageformat/init(contenttype:encodingquality:))
- [`init?(pathExtension: String, encodingQuality: Float)`](https://developer.apple.com/documentation/testing/attachableimageformat/init(pathextension:encodingquality:))
- [`static var jpeg: AttachableImageFormat`](https://developer.apple.com/documentation/testing/attachableimageformat/jpeg)
- [`static func jpeg(withEncodingQuality: Float) -> AttachableImageFormat`](https://developer.apple.com/documentation/testing/attachableimageformat/jpeg(withencodingquality:))
- [`static var png: AttachableImageFormat`](https://developer.apple.com/documentation/testing/attachableimageformat/png)
- [`var attachableValue: AttachableValue.Wrapped`](https://developer.apple.com/documentation/testing/attachment/attachablevalue-vkrw)
- [`var imageFormat: AttachableImageFormat?`](https://developer.apple.com/documentation/testing/attachment/imageformat)
- [`CustomTestReflectable`](https://developer.apple.com/documentation/testing/customtestreflectable)
- [`var customTestMirror: Mirror`](https://developer.apple.com/documentation/testing/customtestreflectable/customtestmirror)
- [`ExitStatus`](https://developer.apple.com/documentation/testing/exitstatus)
- [`case exitCode(CInt)`](https://developer.apple.com/documentation/testing/exitstatus/exitcode(_:))
- [`case signal(CInt)`](https://developer.apple.com/documentation/testing/exitstatus/signal(_:))
- [`ExitTest`](https://developer.apple.com/documentation/testing/exittest)
- [`ExitTest.Condition`](https://developer.apple.com/documentation/testing/exittest/condition)
- [`static func exitCode(CInt) -> ExitTest.Condition`](https://developer.apple.com/documentation/testing/exittest/condition/exitcode(_:))
- [`static var failure: ExitTest.Condition`](https://developer.apple.com/documentation/testing/exittest/condition/failure)
- [`init(ExitStatus)`](https://developer.apple.com/documentation/testing/exittest/condition/init(_:))
- [`static func signal(CInt) -> ExitTest.Condition`](https://developer.apple.com/documentation/testing/exittest/condition/signal(_:))
- [`static var success: ExitTest.Condition`](https://developer.apple.com/documentation/testing/exittest/condition/success)
- [`static var current: ExitTest?`](https://developer.apple.com/documentation/testing/exittest/current)
- [`ExitTest.Result`](https://developer.apple.com/documentation/testing/exittest/result)
- [`var exitStatus: ExitStatus`](https://developer.apple.com/documentation/testing/exittest/result/exitstatus)
- [`var standardErrorContent: [UInt8]`](https://developer.apple.com/documentation/testing/exittest/result/standarderrorcontent)
- [`var standardOutputContent: [UInt8]`](https://developer.apple.com/documentation/testing/exittest/result/standardoutputcontent)
- [`var isFailure: Bool`](https://developer.apple.com/documentation/testing/issue/isfailure)
- [`Issue.Severity`](https://developer.apple.com/documentation/testing/issue/severity-swift.enum)
- [`case error`](https://developer.apple.com/documentation/testing/issue/severity-swift.enum/error)
- [`case warning`](https://developer.apple.com/documentation/testing/issue/severity-swift.enum/warning)
- [`var severity: Issue.Severity`](https://developer.apple.com/documentation/testing/issue/severity-swift.property)
- [`var filePath: String`](https://developer.apple.com/documentation/testing/sourcelocation/filepath)
- [`static func cancel(Comment?, sourceLocation: SourceLocation) throws -> Never`](https://developer.apple.com/documentation/testing/test/cancel(_:sourcelocation:))
- [`static func evaluates(any Evaluation, info: [String : String], recordTranscripts: Bool) -> Self`](https://developer.apple.com/documentation/testing/testtrait/evaluates(_:info:recordtranscripts:))

</details>
<!-- /generated:missing -->
