# ExtensionFoundation

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 11.5% of Apple's iOS API (9 of 78, exact) · **Rows:** 1: 1 🟡 · **iOS:** 16.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [ExtensionFoundation](https://developer.apple.com/documentation/extensionfoundation) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** partial (`isim/swift/overlays/ExtensionFoundation`): the `AppExtension` and `AppExtensionConfiguration`
  protocols the frameworks' extension protocols refine (BackgroundAssets' `BADownloaderExtension`). An extension's
  `@main` type runs through its extension point's framework, which hosts it.
- **Objective-C / C interface:** Swift only, like Apple's.
- **Versus Apple's Simulator:** app-defined extension points (`AppExtensionPoint`) and hosting your own app
  extensions (`AppExtensionProcess`, `AppExtensionIdentity`) are not in isim yet.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AppExtension` (`configuration`, `init()`, `main()`), `AppExtensionConfiguration` (`accept(connection:)`) | 🟡 | 16.0 | the protocols; an extension point isim hosts runs the extension (BackgroundAssets: test_background_assets); a bare `AppExtension` logs that isim has no host for it |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
69 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AppExtension.Bind`](https://developer.apple.com/documentation/extensionfoundation/appextension/bind)
- [`var extensionPoint: AppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextension/extensionpoint)
- [`var extensionPoint: AppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextension/extensionpoint-y2zv)
- [`AppExtension.Identifier`](https://developer.apple.com/documentation/extensionfoundation/appextension/identifier)
- [`AppExtension.Implementing`](https://developer.apple.com/documentation/extensionfoundation/appextension/implementing)
- [`AppExtensionIdentity`](https://developer.apple.com/documentation/extensionfoundation/appextensionidentity)
- [`static func == (AppExtensionIdentity, AppExtensionIdentity) -> Bool`](https://developer.apple.com/documentation/extensionfoundation/appextensionidentity/==(_:_:))
- [`var bundleIdentifier: String`](https://developer.apple.com/documentation/extensionfoundation/appextensionidentity/bundleidentifier)
- [`var extensionPointIdentifier: String`](https://developer.apple.com/documentation/extensionfoundation/appextensionidentity/extensionpointidentifier)
- [`func hash(into: inout Hasher)`](https://developer.apple.com/documentation/extensionfoundation/appextensionidentity/hash(into:))
- [`var localizedName: String`](https://developer.apple.com/documentation/extensionfoundation/appextensionidentity/localizedname)
- [`AppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint)
- [`AppExtensionPoint.Attribute`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/attribute)
- [`AppExtensionPoint.Bind`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/bind)
- [`static func buildBlock(AppExtensionPoint.Identifier) -> AppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/bind/buildblock(_:))
- [`static func buildBlock(AppExtensionPoint.Identifier, AppExtensionPoint.Capabilities) -> AppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/bind/buildblock(_:_:))
- [`AppExtensionPoint.Capabilities`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/capabilities)
- [`AppExtensionPoint.Capabilities.Builder`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/capabilities/builder)
- [`static func buildBlock<each T>(repeat each T) -> AppExtensionPoint.Capabilities`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/capabilities/builder/buildblock(_:))
- [`init(() -> AppExtensionPoint.Capabilities)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/capabilities/init(_:))
- [`AppExtensionPoint.Capability`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/capability)
- [`AppExtensionPoint.Definition`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/definition)
- [`static func buildBlock<each T>(AppExtensionPoint.Name, repeat each T) -> AppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/definition/buildblock(_:_:))
- [`AppExtensionPoint.EnhancedSecurity`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/enhancedsecurity)
- [`init(Bool)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/enhancedsecurity/init(_:))
- [`AppExtensionPoint.Error`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/error)
- [`case hostMustBeApplicationOrAppExtension`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/error/hostmustbeapplicationorappextension)
- [`case hostMustDefineAppExtensionPoint(String)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/error/hostmustdefineappextensionpoint(_:))
- [`case hostMustHaveBundleIdentifier`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/error/hostmusthavebundleidentifier)
- [`case invalidAppExtensionPoint`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/error/invalidappextensionpoint)
- [`case unspecifiedAppExtensionPointName`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/error/unspecifiedappextensionpointname)
- [`AppExtensionPoint.Identifier`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/identifier)
- [`init(StaticString)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/identifier/init(_:))
- [`init(host: StaticString, name: StaticString)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/identifier/init(host:name:))
- [`init(identifier: StaticString) throws`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/init(identifier:))
- [`AppExtensionPoint.Monitor`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor)
- [`func addAppExtensionPoint(AppExtensionPoint) async throws`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/addappextensionpoint(_:))
- [`var identities: [AppExtensionIdentity]`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/identities)
- [`init()`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/init())
- [`convenience init(appExtensionPoint: AppExtensionPoint) async throws`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/init(appextensionpoint:))
- [`func removeAppExtensionPoint(AppExtensionPoint) async throws`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/removeappextensionpoint(_:))
- [`var state: AppExtensionPoint.Monitor.State`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/state-swift.property)
- [`AppExtensionPoint.Monitor.State`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/state-swift.struct)
- [`var disabledCount: Int`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/state-swift.struct/disabledcount)
- [`var identities: [AppExtensionIdentity]`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/state-swift.struct/identities)
- [`var unapprovedCount: Int`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/monitor/state-swift.struct/unapprovedcount)
- [`AppExtensionPoint.Name`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/name)
- [`init(StaticString)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/name/init(_:))
- [`AppExtensionPoint.Scope`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/scope)
- [`init(restriction: AppExtensionPoint.Scope.Restriction)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/scope/init(restriction:))
- [`AppExtensionPoint.Scope.Restriction`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/scope/restriction)
- [`case application`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/scope/restriction/application)
- [`AppExtensionPoint.UserInterface`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/userinterface)
- [`init(Bool)`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/userinterface/init(_:))
- [`let value: Bool`](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/userinterface/value)
- [`AppExtensionProcess`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess)
- [`AppExtensionProcess.Configuration`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/configuration)
- [`var appExtensionIdentity: AppExtensionIdentity`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/configuration/appextensionidentity)
- [`init(appExtensionIdentity: AppExtensionIdentity, onInterruption: () -> Void)`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/configuration/init(appextensionidentity:oninterruption:))
- [`var onInterruption: () -> Void`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/configuration/oninterruption)
- [`init(configuration: AppExtensionProcess.Configuration) throws`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/init(configuration:)-2g0cy)
- [`init(configuration: AppExtensionProcess.Configuration) async throws`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/init(configuration:)-38zf)
- [`func invalidate()`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/invalidate())
- [`func makeXPCConnection() throws -> NSXPCConnection`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/makexpcconnection())
- [`func makeXPCSession() throws -> XPCSession`](https://developer.apple.com/documentation/extensionfoundation/appextensionprocess/makexpcsession())
- [`ConnectionHandler`](https://developer.apple.com/documentation/extensionfoundation/connectionhandler)
- [`init(onConnection: (NSXPCConnection) -> Bool)`](https://developer.apple.com/documentation/extensionfoundation/connectionhandler/init(onconnection:))
- [`init(onSessionRequest: (XPCListener.IncomingSessionRequest) -> XPCListener.IncomingSessionRequest.Decision)`](https://developer.apple.com/documentation/extensionfoundation/connectionhandler/init(onsessionrequest:))
- [`ExtensionPointDefining`](https://developer.apple.com/documentation/extensionfoundation/extensionpointdefining)

</details>
<!-- /generated:missing -->
