// CloudKit sharing and user discovery on isim.  These are local adaptations: shares and identities stay in the
// simulated device's CloudKit store; no invitation is sent and no Apple directory is queried.
import Foundation
import UIKit

public let CKRecordTypeShare = "cloudkit.share"

open class CKUserIdentity: NSObject, @unchecked Sendable {
    open class LookupInfo: NSObject, @unchecked Sendable {
        public let emailAddress: String?
        public let phoneNumber: String?
        public let userRecordID: CKRecord.ID?
        public init(emailAddress: String) { self.emailAddress = emailAddress; phoneNumber = nil; userRecordID = nil }
        public init(phoneNumber: String) { emailAddress = nil; self.phoneNumber = phoneNumber; userRecordID = nil }
        public init(userRecordID: CKRecord.ID) { emailAddress = nil; phoneNumber = nil; self.userRecordID = userRecordID }
    }
    public let userRecordID: CKRecord.ID?
    public let nameComponents: PersonNameComponents?
    public let contactIdentifiers: [String]
    public let hasiCloudAccount: Bool
    init(recordID: CKRecord.ID?, name: PersonNameComponents?, contacts: [String] = [], account: Bool = true) {
        userRecordID = recordID; nameComponents = name; contactIdentifiers = contacts; hasiCloudAccount = account
    }
}

open class CKShare: CKRecord, @unchecked Sendable {
    public enum ParticipantAcceptanceStatus: Int, Sendable { case unknown = 0, pending = 1, accepted = 2, removed = 3 }
    public enum ParticipantPermission: Int, Sendable { case unknown = 0, none = 1, readOnly = 2, readWrite = 3 }
    public enum ParticipantRole: Int, Sendable { case unknown = 0, owner = 1, privateUser = 3, publicUser = 4 }
    open class Participant: NSObject, @unchecked Sendable {
        public let userIdentity: CKUserIdentity
        public internal(set) var role: ParticipantRole
        public internal(set) var acceptanceStatus: ParticipantAcceptanceStatus
        open var permission: ParticipantPermission
        init(_ identity: CKUserIdentity, role: ParticipantRole, permission: ParticipantPermission, status: ParticipantAcceptanceStatus) {
            userIdentity = identity; self.role = role; self.permission = permission; acceptanceStatus = status
        }
    }
    public struct SystemFieldKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let title = SystemFieldKey(rawValue: "cloudkit.title")
        public static let thumbnailImageData = SystemFieldKey(rawValue: "cloudkit.thumbnailImageData")
        public static let shareType = SystemFieldKey(rawValue: "cloudkit.shareType")
    }
    public enum ParticipantAccessOptions: UInt, Sendable { case anyoneWithLink = 1, specifiedRecipientsOnly = 2 }
    public let rootRecordID: CKRecord.ID?
    open var publicPermission: ParticipantPermission = .none
    private var extraParticipants: [Participant] = []
    public var owner: Participant { Self.currentParticipant(role: .owner) }
    public var currentUserParticipant: Participant { owner }
    public var participants: [Participant] { [owner] + extraParticipants }

    public init(rootRecord: CKRecord) {
        rootRecordID = rootRecord.recordID
        super.init(recordType: CKRecordTypeShare, recordID: CKRecord.ID(recordName: "Share-" + rootRecord.recordID.recordName, zoneID: rootRecord.recordID.zoneID))
        rootRecord.parent = CKRecord.Reference(recordID: recordID, action: .none)
    }
    public init(recordZoneID: CKRecordZone.ID) {
        rootRecordID = nil
        super.init(recordType: CKRecordTypeShare, recordID: CKRecord.ID(recordName: "Share", zoneID: recordZoneID))
    }
    init(recordID: CKRecord.ID) { rootRecordID = nil; super.init(recordType: CKRecordTypeShare, recordID: recordID) }
    public override init?(coder: NSCoder) { rootRecordID = nil; super.init(coder: coder) }
    private static func currentParticipant(role: ParticipantRole) -> Participant {
        var name = PersonNameComponents(); name.givenName = "Taylor"; name.familyName = "Appleseed"
        return Participant(CKUserIdentity(recordID: CKRecord.ID(recordName: _CKEnv.userRecordName), name: name), role: role, permission: .readWrite, status: .accepted)
    }
    open func addParticipant(_ participant: Participant) { if !extraParticipants.contains(where: { $0.userIdentity.userRecordID == participant.userIdentity.userRecordID }) { extraParticipants.append(participant) } }
    open func removeParticipant(_ participant: Participant) { extraParticipants.removeAll { $0 === participant || $0.userIdentity.userRecordID == participant.userIdentity.userRecordID } }
}

extension CKContainer {
    private func identity(_ lookup: CKUserIdentity.LookupInfo) -> CKUserIdentity {
        if let id = lookup.userRecordID, id.recordName == _CKEnv.userRecordName {
            var n = PersonNameComponents(); n.givenName = "Taylor"; n.familyName = "Appleseed"
            return CKUserIdentity(recordID: id, name: n, contacts: ["current-user"])
        }
        let key = lookup.emailAddress ?? lookup.phoneNumber ?? lookup.userRecordID?.recordName ?? "unknown"
        var hash: UInt64 = 0xcbf29ce484222325
        for b in key.lowercased().utf8 { hash = (hash ^ UInt64(b)) &* 0x100000001b3 }
        var n = PersonNameComponents(); n.givenName = key.split(separator: "@").first.map(String.init) ?? "CloudKit User"
        return CKUserIdentity(recordID: CKRecord.ID(recordName: String(format: "_local_%016llx", hash)), name: n, contacts: [key])
    }
    public func requestApplicationPermission(_ applicationPermission: ApplicationPermissions, completionHandler: @escaping @Sendable (ApplicationPermissionStatus, Error?) -> Void) {
        CKDatabase.reply { completionHandler(_CKEnv.accountStatus == .available ? .granted : .couldNotComplete, _CKEnv.accountStatus == .available ? nil : CKError(.notAuthenticated)) }
    }
    public func status(forApplicationPermission applicationPermission: ApplicationPermissions, completionHandler: @escaping @Sendable (ApplicationPermissionStatus, Error?) -> Void) {
        requestApplicationPermission(applicationPermission, completionHandler: completionHandler)
    }
    public func discoverUserIdentity(withEmailAddress email: String, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        discoverUserIdentity(with: CKUserIdentity.LookupInfo(emailAddress: email), completionHandler: completionHandler)
    }
    public func discoverUserIdentity(withPhoneNumber phoneNumber: String, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        discoverUserIdentity(with: CKUserIdentity.LookupInfo(phoneNumber: phoneNumber), completionHandler: completionHandler)
    }
    public func discoverUserIdentity(withUserRecordID recordID: CKRecord.ID, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        discoverUserIdentity(with: CKUserIdentity.LookupInfo(userRecordID: recordID), completionHandler: completionHandler)
    }
    public func discoverUserIdentity(with lookupInfo: CKUserIdentity.LookupInfo, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        guard _CKEnv.accountStatus == .available else { CKDatabase.reply { completionHandler(nil, CKError(.notAuthenticated)) }; return }
        let result = identity(lookupInfo); CKDatabase.reply { completionHandler(result, nil) }
    }
    public func discoverAllIdentities(with lookupInfos: [CKUserIdentity.LookupInfo], completionHandler: @escaping @Sendable ([CKUserIdentity]?, Error?) -> Void) {
        guard _CKEnv.accountStatus == .available else { CKDatabase.reply { completionHandler(nil, CKError(.notAuthenticated)) }; return }
        let results = lookupInfos.map(identity); CKDatabase.reply { completionHandler(results, nil) }
    }
    public func userIdentity(forUserRecordID recordID: CKRecord.ID) async throws -> CKUserIdentity { identity(CKUserIdentity.LookupInfo(userRecordID: recordID)) }
    public func userIdentity(forEmailAddress email: String) async throws -> CKUserIdentity { identity(CKUserIdentity.LookupInfo(emailAddress: email)) }
    public func userIdentity(forPhoneNumber phoneNumber: String) async throws -> CKUserIdentity { identity(CKUserIdentity.LookupInfo(phoneNumber: phoneNumber)) }
    public func fetchShareParticipant(withEmailAddress email: String, completionHandler: @escaping @Sendable (CKShare.Participant?, Error?) -> Void) {
        let p = CKShare.Participant(identity(CKUserIdentity.LookupInfo(emailAddress: email)), role: .privateUser, permission: .readOnly, status: .pending)
        CKDatabase.reply { completionHandler(p, nil) }
    }
    public func fetchShareParticipant(withPhoneNumber phoneNumber: String, completionHandler: @escaping @Sendable (CKShare.Participant?, Error?) -> Void) {
        let p = CKShare.Participant(identity(CKUserIdentity.LookupInfo(phoneNumber: phoneNumber)), role: .privateUser, permission: .readOnly, status: .pending)
        CKDatabase.reply { completionHandler(p, nil) }
    }
    public func fetchShareParticipant(withUserRecordID recordID: CKRecord.ID, completionHandler: @escaping @Sendable (CKShare.Participant?, Error?) -> Void) {
        let p = CKShare.Participant(identity(CKUserIdentity.LookupInfo(userRecordID: recordID)), role: .privateUser, permission: .readOnly, status: .pending)
        CKDatabase.reply { completionHandler(p, nil) }
    }
    public func shareParticipant(forEmailAddress email: String) async throws -> CKShare.Participant {
        CKShare.Participant(identity(CKUserIdentity.LookupInfo(emailAddress: email)), role: .privateUser, permission: .readOnly, status: .pending)
    }
    public func shareParticipant(forPhoneNumber phoneNumber: String) async throws -> CKShare.Participant {
        CKShare.Participant(identity(CKUserIdentity.LookupInfo(phoneNumber: phoneNumber)), role: .privateUser, permission: .readOnly, status: .pending)
    }
    public func shareParticipant(forUserRecordID recordID: CKRecord.ID) async throws -> CKShare.Participant {
        CKShare.Participant(identity(CKUserIdentity.LookupInfo(userRecordID: recordID)), role: .privateUser, permission: .readOnly, status: .pending)
    }
}

extension UICloudSharingController {
    /// The Objective-C initializer's CloudKit forward declarations are not imported into isim's Swift UIKit module;
    /// expose its normal Swift spelling from CloudKit, where CKShare and CKContainer are complete types.
    public convenience init(share: CKShare, container: CKContainer) {
        self.init()
        setValue(share, forKey: "share")
        setValue(container, forKey: "container")
    }
}
