# ExtensionKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 2.8% of Apple's iOS API (1 of 36, exact) · **Rows:** 1: 1 🟡 · **iOS:** 16.1+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [ExtensionKit](https://developer.apple.com/documentation/extensionkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** partial (`isim/swift/overlays/ExtensionKit`): only `AppExtensionScene`, the protocol that frameworks'
  extension scenes refine (DeviceActivity's `DeviceActivityReportScene`). Hosting another app's extension scene in a
  view (`EXHostViewController`, `AppExtensionSceneConfiguration`, `PrimitiveAppExtensionScene`) is not in isim yet.
- **Objective-C / C interface:** none yet (`EXHostViewController` is Objective-C in Apple's SDK).
- **Versus Apple's Simulator:** —

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AppExtensionScene` | 🟡 | ≤17 | adapted: the protocol only, for DeviceActivity's report scenes; tested (HelloScreenTime, test_screen_time) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
35 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`Body`](https://developer.apple.com/documentation/extensionkit/appextensionscene/body-swift.associatedtype)
- [`var body: Self.Body`](https://developer.apple.com/documentation/extensionkit/appextensionscene/body-swift.property)
- [`AppExtensionSceneBuilder`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder)
- [`static func buildBlock<Content>(Content) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:))
- [`static func buildBlock<C0, C1>(C0, C1) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:))
- [`static func buildBlock<C0, C1, C2>(C0, C1, C2) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3>(C0, C1, C2, C3) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4>(C0, C1, C2, C3, C4) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5>(C0, C1, C2, C3, C4, C5) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(C0, C1, C2, C3, C4, C5, C6) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(C0, C1, C2, C3, C4, C5, C6, C7) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(C0, C1, C2, C3, C4, C5, C6, C7, C8) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9) -> some AppExtensionScene`](https://developer.apple.com/documentation/extensionkit/appextensionscenebuilder/buildblock(_:_:_:_:_:_:_:_:_:_:))
- [`AppExtensionSceneConfiguration`](https://developer.apple.com/documentation/extensionkit/appextensionsceneconfiguration)
- [`func accept(connection: NSXPCConnection) -> Bool`](https://developer.apple.com/documentation/extensionkit/appextensionsceneconfiguration/accept(connection:))
- [`init<Content>(@autoclosure () -> Content)`](https://developer.apple.com/documentation/extensionkit/appextensionsceneconfiguration/init(_:))
- [`init<Content, Configuration>(@autoclosure () -> Content, configuration: Configuration?)`](https://developer.apple.com/documentation/extensionkit/appextensionsceneconfiguration/init(_:configuration:))
- [`EXAppExtensionBrowserViewController`](https://developer.apple.com/documentation/extensionkit/exappextensionbrowserviewcontroller)
- [`EXHostViewController`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller)
- [`var configuration: EXHostViewController.Configuration?`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/configuration-swift.property)
- [`EXHostViewController.Configuration`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/configuration-swift.struct)
- [`var appExtension: AppExtensionIdentity`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/configuration-swift.struct/appextension)
- [`init(appExtension: AppExtensionIdentity, sceneID: String)`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/configuration-swift.struct/init(appextension:sceneid:))
- [`var sceneID: String`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/configuration-swift.struct/sceneid)
- [`var delegate: (any EXHostViewControllerDelegate)?`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/delegate)
- [`func makeXPCConnection() throws -> NSXPCConnection`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/makexpcconnection())
- [`var placeholderView: UIView`](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller/placeholderview)
- [`EXHostViewControllerDelegate`](https://developer.apple.com/documentation/extensionkit/exhostviewcontrollerdelegate)
- [`func hostViewControllerDidActivate(EXHostViewController)`](https://developer.apple.com/documentation/extensionkit/exhostviewcontrollerdelegate/hostviewcontrollerdidactivate(_:))
- [`func hostViewControllerWillDeactivate(EXHostViewController, error: (any Error)?)`](https://developer.apple.com/documentation/extensionkit/exhostviewcontrollerdelegate/hostviewcontrollerwilldeactivate(_:error:))
- [`PrimitiveAppExtensionScene`](https://developer.apple.com/documentation/extensionkit/primitiveappextensionscene)
- [`var body: Never`](https://developer.apple.com/documentation/extensionkit/primitiveappextensionscene/body)
- [`var debugDescription: String`](https://developer.apple.com/documentation/extensionkit/primitiveappextensionscene/debugdescription)
- [`var debugDescription: String`](https://developer.apple.com/documentation/extensionkit/primitiveappextensionscene/debugdescription)
- [`init<Content>(id: String, content: () -> Content, onConnection: (NSXPCConnection) -> Bool)`](https://developer.apple.com/documentation/extensionkit/primitiveappextensionscene/init(id:content:onconnection:))

</details>
<!-- /generated:missing -->
