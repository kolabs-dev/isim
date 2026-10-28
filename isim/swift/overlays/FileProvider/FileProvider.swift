// isim FileProvider (adapted): file provider extensions on isim.
//
// An app with a replicated file provider extension (PlugIns/*.appex, NSExtensionPointIdentifier
// com.apple.fileprovider-nonui, its principal class implementing NSFileProviderReplicatedExtension) adds domains with
// NSFileProviderManager.add(_:). Each domain is a location in the document picker and browser (UIKit's
// UIDocumentPicker.m), beside On My iPhone, and has a replica folder on the device, its user-visible URL. isim's
// system side (Host.swift) plays the part of iOS's fileproviderd: it loads the extension into the process that uses
// the domain (the picker's app, or the provider app itself), keeps the replica in sync with the extension's items and
// sends local changes back. Apple's value types come from the Objective-C header (sdk-src/Frameworks/FileProvider);
// the classes and protocols are this overlay's, @objc with Apple's names. Stubs: the non-replicated
// NSFileProviderExtension (declared, not hosted), the testing operations (none are listed), services and known folders.
@_exported import FileProvider
import Foundation

// MARK: - errors

public struct NSFileProviderError: CustomNSError, Hashable, _ObjectiveCBridgeableError {
    @objc(NSFileProviderErrorCode) public enum Code: Int, Sendable {
        case notAuthenticated = -1000
        case filenameCollision = -1001
        case syncAnchorExpired = -1002
        case insufficientQuota = -1003
        case serverUnreachable = -1004
        case noSuchItem = -1005
        case deletionRejected = -1006
        case directoryNotEmpty = -1007
        case localVersionConflictingWithServer = -1008
        case providerNotFound = -2001
        case providerTranslocated = -2002
        case olderExtensionVersionRunning = -2003
        case newerExtensionVersionFound = -2004
        case cannotSynchronize = -2005
        case nonEvictableChildren = -2006
        case unsyncedEdits = -2007
        case nonEvictable = -2008
        case versionNoLongerAvailable = -2009
        case excludedFromSync = -2010
        case domainDisabled = -2011
        case providerDomainTemporarilyUnavailable = -2012
        case providerDomainNotFound = -2013
        case applicationExtensionNotFound = -2014
        public static var pageExpired: Code { .syncAnchorExpired }
    }
    public let code: Code
    public let userInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == "NSFileProviderErrorDomain", let c = Code(rawValue: e.code) else { return nil }
        self.init(c, userInfo: e.userInfo)
    }
    public static var errorDomain: String { "NSFileProviderErrorDomain" }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { userInfo }
    public static func == (a: NSFileProviderError, b: NSFileProviderError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }

    public static var notAuthenticated: Code { .notAuthenticated }
    public static var filenameCollision: Code { .filenameCollision }
    public static var syncAnchorExpired: Code { .syncAnchorExpired }
    public static var pageExpired: Code { .syncAnchorExpired }
    public static var insufficientQuota: Code { .insufficientQuota }
    public static var serverUnreachable: Code { .serverUnreachable }
    public static var noSuchItem: Code { .noSuchItem }
    public static var deletionRejected: Code { .deletionRejected }
    public static var directoryNotEmpty: Code { .directoryNotEmpty }
    public static var localVersionConflictingWithServer: Code { .localVersionConflictingWithServer }
    public static var providerNotFound: Code { .providerNotFound }
    public static var providerTranslocated: Code { .providerTranslocated }
    public static var olderExtensionVersionRunning: Code { .olderExtensionVersionRunning }
    public static var newerExtensionVersionFound: Code { .newerExtensionVersionFound }
    public static var cannotSynchronize: Code { .cannotSynchronize }
    public static var nonEvictableChildren: Code { .nonEvictableChildren }
    public static var unsyncedEdits: Code { .unsyncedEdits }
    public static var nonEvictable: Code { .nonEvictable }
    public static var versionNoLongerAvailable: Code { .versionNoLongerAvailable }
    public static var excludedFromSync: Code { .excludedFromSync }
    public static var domainDisabled: Code { .domainDisabled }
    public static var providerDomainTemporarilyUnavailable: Code { .providerDomainTemporarilyUnavailable }
    public static var providerDomainNotFound: Code { .providerDomainNotFound }
    public static var applicationExtensionNotFound: Code { .applicationExtensionNotFound }
}

func _fpError(_ code: NSFileProviderError.Code, _ why: String, _ extra: [String: Any] = [:]) -> NSError {
    var info = extra
    info[NSLocalizedDescriptionKey] = why
    return NSError(domain: "NSFileProviderErrorDomain", code: code.rawValue, userInfo: info)
}

// MARK: - versions

@available(iOS 16.0, *)
@objc(NSFileProviderDomainVersion)
open class NSFileProviderDomainVersion: NSObject, NSSecureCoding, @unchecked Sendable {
    let _value: Int
    init(_value: Int) { self._value = _value }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { coder.encode(_value, forKey: "version") }
    public required init?(coder: NSCoder) { _value = coder.decodeInteger(forKey: "version") }
    /// the version after this one
    @objc open func next() -> NSFileProviderDomainVersion { NSFileProviderDomainVersion(_value: _value + 1) }
    @objc(compare:) open func compare(_ otherVersion: NSFileProviderDomainVersion) -> ComparisonResult {
        _value < otherVersion._value ? .orderedAscending : _value > otherVersion._value ? .orderedDescending : .orderedSame
    }
    open override func isEqual(_ object: Any?) -> Bool { (object as? NSFileProviderDomainVersion)?._value == _value }
    open override var hash: Int { _value }
}

@available(iOS 16.0, *)
@objc(NSFileProviderItemVersion)
open class NSFileProviderItemVersion: NSObject, @unchecked Sendable {
    @objc public let contentVersion: Data
    @objc public let metadataVersion: Data
    @objc(initWithContentVersion:metadataVersion:)
    public init(contentVersion: Data, metadataVersion: Data) {
        self.contentVersion = contentVersion
        self.metadataVersion = metadataVersion
    }
    public override convenience init() { self.init(contentVersion: Data(), metadataVersion: Data()) }
    /// the version component of an item that has not been synced yet
    @objc open class var beforeFirstSyncComponent: Data { Data("isim.beforeFirstSync".utf8) }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? NSFileProviderItemVersion else { return false }
        return o.contentVersion == contentVersion && o.metadataVersion == metadataVersion
    }
    open override var hash: Int { contentVersion.hashValue ^ metadataVersion.hashValue }
}

// MARK: - domains

@objc(NSFileProviderDomain)
open class NSFileProviderDomain: NSObject, @unchecked Sendable {
    @objc public let identifier: NSFileProviderDomainIdentifier
    @objc public let displayName: String
    @objc public let pathRelativeToDocumentStorage: String
    @objc open var isHidden = false
    @objc open var supportsSyncingTrash = false
    @objc open var supportsStringSearchRequest = false
    @objc open var userInfo: [AnyHashable: Any]?
    open var supportedKnownFolders: NSFileProviderKnownFolders = []
    var _disconnected = false
    var _userEnabled = true
    var _testingModes: TestingModes = []
    let _volumeURL: URL?

    @available(iOS 16.0, *)
    @objc(initWithIdentifier:displayName:)
    public init(identifier: NSFileProviderDomainIdentifier, displayName: String) {
        self.identifier = identifier; self.displayName = displayName
        pathRelativeToDocumentStorage = identifier.rawValue; _volumeURL = nil
    }
    @objc(initWithIdentifier:displayName:pathRelativeToDocumentStorage:)
    public init(identifier: NSFileProviderDomainIdentifier, displayName: String, pathRelativeToDocumentStorage: String) {
        self.identifier = identifier; self.displayName = displayName
        self.pathRelativeToDocumentStorage = pathRelativeToDocumentStorage; _volumeURL = nil
    }
    /// a domain on an external volume (macOS): isim has no external volumes, so it is an ordinary domain
    @objc(initWithDisplayName:userInfo:volumeURL:)
    public init(displayName: String, userInfo: [AnyHashable: Any] = [:], volumeURL: URL?) {
        identifier = NSFileProviderDomainIdentifier(UUID().uuidString); self.displayName = displayName
        pathRelativeToDocumentStorage = identifier.rawValue; self.userInfo = userInfo; _volumeURL = volumeURL
    }

    @objc open var isDisconnected: Bool { _disconnected }
    @objc open var userEnabled: Bool { _userEnabled }
    @objc open var isReplicated: Bool { true }
    @objc open var backingStoreIdentity: Data? { nil }
    @objc open var volumeUUID: UUID? { nil }
    open var replicatedKnownFolders: NSFileProviderKnownFolders { [] }

    @available(iOS 16.0, *)
    public struct TestingModes: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var alwaysEnabled: TestingModes { .init(rawValue: 1 << 0) }
        public static var interactive: TestingModes { .init(rawValue: 1 << 1) }
    }
    @available(iOS 16.0, *)
    open var testingModes: TestingModes { get { _testingModes } set { _testingModes = newValue } }

    open override func isEqual(_ object: Any?) -> Bool { (object as? NSFileProviderDomain)?.identifier == identifier }
    open override var hash: Int { identifier.hashValue }
    open override var description: String { "<NSFileProviderDomain \(identifier.rawValue) \"\(displayName)\">" }
}

extension NSFileProviderDomain {
    @objc(supportedKnownFolders) var _objc_supportedKnownFolders: UInt { get { supportedKnownFolders.rawValue } set { supportedKnownFolders = .init(rawValue: newValue) } }
    @objc(replicatedKnownFolders) var _objc_replicatedKnownFolders: UInt { replicatedKnownFolders.rawValue }
    @objc(testingModes) var _objc_testingModes: UInt { get { _testingModes.rawValue } set { _testingModes = .init(rawValue: newValue) } }
}

// MARK: - requests

@available(iOS 16.0, *)
@objc(NSFileProviderRequest)
open class NSFileProviderRequest: NSObject, @unchecked Sendable {
    let _system: Bool, _viewer: Bool, _executable: URL?, _version: NSFileProviderDomainVersion?
    init(system: Bool = false, viewer: Bool = false, executable: URL? = Bundle.main.executableURL, version: NSFileProviderDomainVersion? = nil) {
        _system = system; _viewer = viewer; _executable = executable; _version = version
    }
    /// whether the system asked (a sync, an import), not an app
    @objc open var isSystemRequest: Bool { _system }
    /// whether a file viewer (the document picker or browser) asked
    @objc open var isFileViewerRequest: Bool { _viewer }
    @objc open var requestingExecutable: URL? { _executable }
    @objc open var domainVersion: NSFileProviderDomainVersion? { _version }
}

@objc(NSFileProviderStringSearchRequest)
open class NSFileProviderStringSearchRequest: NSObject, @unchecked Sendable {
    @objc public let query: String
    @objc public let desiredNumberOfResults: Int
    init(query: String, desiredNumberOfResults: Int) { self.query = query; self.desiredNumberOfResults = desiredNumberOfResults }
}

// MARK: - known folders (macOS's Desktop and Documents; isim's providers cannot claim them)

@objc(NSFileProviderKnownFolderLocations)
open class NSFileProviderKnownFolderLocations: NSObject, @unchecked Sendable {
    @objc(NSFileProviderKnownFolderLocation)
    open class Location: NSObject, @unchecked Sendable {
        let _parent: NSFileProviderItemIdentifier?, _filename: String?, _existing: NSFileProviderItemIdentifier?
        @objc(initWithParentItemIdentifier:filename:)
        public init(parentItemIdentifier: NSFileProviderItemIdentifier, filename: String) { _parent = parentItemIdentifier; _filename = filename; _existing = nil }
        @objc(initWithExistingItemIdentifier:)
        public init(existingItemIdentifier: NSFileProviderItemIdentifier) { _parent = nil; _filename = nil; _existing = existingItemIdentifier }
    }
    @objc open var shouldCreateBinaryCompatibilitySymlink = false
    @objc open var desktopLocation: Location?
    @objc open var documentsLocation: Location?
    public override init() {}
}

// MARK: - services (Foundation's on Apple's SDK)

@objc(NSFileProviderService)
open class NSFileProviderService: NSObject, @unchecked Sendable {
    @objc public let name: NSFileProviderServiceName
    init(name: NSFileProviderServiceName) { self.name = name }
    /// isim's providers' services are not reachable from other apps: the handler gets an error
    @objc(getFileProviderConnectionWithCompletionHandler:)
    open func getFileProviderConnection(completionHandler: @escaping @Sendable (NSXPCConnection?, (any Error)?) -> Void) {
        completionHandler(nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError,
                                       userInfo: [NSLocalizedDescriptionKey: "file provider services are not available on isim"]))
    }
}
