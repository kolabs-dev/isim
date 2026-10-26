// CloudKit's CKShare.Metadata (Objective-C's CKShareMetadata), as a top-level class of its own small module (issue #630).
// UIKit's headers declare the share-link delegate methods with a forward-declared CKShareMetadata; Swift resolves that
// only to a top-level class in the overlay of the Clang module that declares it (_CKShareMetadata, which UIKit's headers
// import). CloudKit's overlay imports UIKit, so the class cannot live there: CloudKit names it CKShare.Metadata and adds
// the typed properties (CloudKit/Sharing.swift); this module holds the values untyped.
@_exported import _CKShareMetadata
import Foundation

/// What a participant learns from a share's URL before accepting it (use it as CloudKit's `CKShare.Metadata`).
@objc(CKShareMetadata) open class CKShareMetadata: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public let containerIdentifier: String
    // CloudKit's values (CKShare, CKRecord.ID, CKUserIdentity, CKRecord, the participant enums' raw values): CloudKit
    // reads them typed
    public let _share: NSObject
    public let _hierarchicalRootRecordID: NSObject?
    public let _participantRole: Int
    public let _participantStatus: Int
    public let _participantPermission: Int
    public let _ownerIdentity: NSObject
    public var _rootRecord: NSObject?
    /// the share's URL (archived) and an identity of its record (equality)
    public let _shareURL: URL?
    public let _shareKey: String

    public init(_containerIdentifier container: String, share: NSObject, shareURL: URL?, shareKey: String, hierarchicalRootRecordID: NSObject?,
                participantRole: Int, participantStatus: Int, participantPermission: Int, ownerIdentity: NSObject, rootRecord: NSObject?) {
        containerIdentifier = container; _share = share; _shareURL = shareURL; _shareKey = shareKey
        _hierarchicalRootRecordID = hierarchicalRootRecordID
        _participantRole = participantRole; _participantStatus = participantStatus; _participantPermission = participantPermission
        _ownerIdentity = ownerIdentity; _rootRecord = rootRecord
    }
    @objc(participantRole) public var _objcRole: Int { _participantRole }
    @objc(participantStatus) public var _objcStatus: Int { _participantStatus }
    @objc(participantPermission) public var _objcPermission: Int { _participantPermission }

    public func copy(with zone: NSZone? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    /// the share's URL (CKShare.url); decoding reads the metadata again from the local store
    public func encode(with coder: NSCoder) {
        coder.encode(_shareURL?.absoluteString as NSString?, forKey: "url")
    }
    public required init?(coder: NSCoder) {
        // CloudKit reads it (+[CKContainer _isim_shareMetadataWithURL:], CloudKit/ObjC.swift): an app that decodes one
        // links CloudKit
        guard let s = coder.decodeObject(of: NSString.self, forKey: "url"), let url = NSURL(string: s as String),
              let container = NSClassFromString("CKContainer") as? NSObject.Type,
              let m = container.perform(NSSelectorFromString("_isim_shareMetadataWithURL:"), with: url)?.takeUnretainedValue() as? CKShareMetadata
        else { return nil }
        containerIdentifier = m.containerIdentifier; _share = m._share; _shareURL = m._shareURL; _shareKey = m._shareKey
        _hierarchicalRootRecordID = m._hierarchicalRootRecordID
        _participantRole = m._participantRole; _participantStatus = m._participantStatus; _participantPermission = m._participantPermission
        _ownerIdentity = m._ownerIdentity; _rootRecord = nil
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? CKShareMetadata else { return false }
        return o.containerIdentifier == containerIdentifier && o._shareKey == _shareKey
    }
    open override var hash: Int { containerIdentifier.hashValue ^ _shareKey.hashValue }
}
