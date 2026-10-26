// CloudKit sharing and user discovery on isim.  These are local adaptations: shares and identities stay in the
// simulated device's CloudKit store; no invitation is sent and no Apple directory is queried.
import Foundation
import UIKit

public let CKRecordTypeShare = "cloudkit.share"

@objc(CKUserIdentity) open class CKUserIdentity: NSObject, @unchecked Sendable {
    @objc(CKUserIdentityLookupInfo) open class LookupInfo: NSObject, @unchecked Sendable {
        @objc public let emailAddress: String?
        @objc public let phoneNumber: String?
        @objc public let userRecordID: CKRecord.ID?
        @objc public init(emailAddress: String) { self.emailAddress = emailAddress; phoneNumber = nil; userRecordID = nil }
        @objc public init(phoneNumber: String) { emailAddress = nil; self.phoneNumber = phoneNumber; userRecordID = nil }
        @objc public init(userRecordID: CKRecord.ID) { emailAddress = nil; phoneNumber = nil; self.userRecordID = userRecordID }
    }
    @objc public let userRecordID: CKRecord.ID?
    @objc public let nameComponents: PersonNameComponents?
    @objc public let contactIdentifiers: [String]
    @objc public let hasiCloudAccount: Bool
    @objc init(recordID: CKRecord.ID?, name: PersonNameComponents?, contacts: [String] = [], account: Bool = true) {
        userRecordID = recordID; nameComponents = name; contactIdentifiers = contacts; hasiCloudAccount = account
    }
}

@objc(CKShare) open class CKShare: CKRecord, @unchecked Sendable {
    public enum ParticipantAcceptanceStatus: Int, Sendable { case unknown = 0, pending = 1, accepted = 2, removed = 3 }
    public enum ParticipantPermission: Int, Sendable { case unknown = 0, none = 1, readOnly = 2, readWrite = 3 }
    public enum ParticipantRole: Int, Sendable { case unknown = 0, owner = 1, privateUser = 3, publicUser = 4 }
    @objc(CKShareParticipant) open class Participant: NSObject, @unchecked Sendable {
        @objc public let userIdentity: CKUserIdentity
        public internal(set) var role: ParticipantRole
        public internal(set) var acceptanceStatus: ParticipantAcceptanceStatus
        open var permission: ParticipantPermission
        init(_ identity: CKUserIdentity, role: ParticipantRole, permission: ParticipantPermission, status: ParticipantAcceptanceStatus) {
            userIdentity = identity; self.role = role; self.permission = permission; acceptanceStatus = status
        }
        var stored: _CKStoredParticipant {
            _CKStoredParticipant(user: userIdentity.userRecordID?.recordName ?? "", firstName: userIdentity.nameComponents?.givenName,
                                 lastName: userIdentity.nameComponents?.familyName, contact: userIdentity.contactIdentifiers.first,
                                 role: role.rawValue, permission: permission.rawValue, status: acceptanceStatus.rawValue)
        }
        convenience init(_ s: _CKStoredParticipant) {
            var n = PersonNameComponents(); n.givenName = s.firstName; n.familyName = s.lastName
            self.init(CKUserIdentity(recordID: CKRecord.ID(recordName: s.user), name: n, contacts: s.contact.map { [$0] } ?? []),
                      role: ParticipantRole(rawValue: s.role) ?? .unknown, permission: ParticipantPermission(rawValue: s.permission) ?? .unknown,
                      status: ParticipantAcceptanceStatus(rawValue: s.status) ?? .unknown)
        }
    }
    /// the keys of a share's system fields: record field keys, as in Apple's SDK (`share[CKShare.SystemFieldKey.title]`)
    public enum SystemFieldKey {
        public static let title: CKRecord.FieldKey = "cloudkit.title"
        public static let thumbnailImageData: CKRecord.FieldKey = "cloudkit.thumbnailImageData"
        public static let shareType: CKRecord.FieldKey = "cloudkit.shareType"
    }
    public enum ParticipantAccessOptions: UInt, Sendable { case anyoneWithLink = 1, specifiedRecipientsOnly = 2 }
    @objc public internal(set) var rootRecordID: CKRecord.ID?
    open var publicPermission: ParticipantPermission = .none
    private var ownerParticipant: Participant = CKShare.currentUser(role: .owner, permission: .readWrite, status: .accepted)
    private var extraParticipants: [Participant] = []
    @objc var containerIdentifier: String?                      // set on shares read from (or saved to) a database
    @objc public var owner: Participant { ownerParticipant }
    /// The participant that is the device's current user (nil when the user has no part in the share).
    @objc public var currentUserParticipant: Participant? { participants.first { $0.userIdentity.userRecordID?.recordName == _CKEnv.userRecordName } }
    @objc public var participants: [Participant] { [ownerParticipant] + extraParticipants }
    /// The link participants open: set once the share is saved (isim: it names the share's container, zone and record,
    /// which is how any app on the device finds the share in the local store).
    @objc open var url: URL? {
        guard recordChangeTag != nil, let c = containerIdentifier else { return nil }
        let token = [c, recordID.zoneID.ownerName, recordID.zoneID.zoneName, recordID.recordName].joined(separator: "\u{1f}")
        let b64 = Data(token.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return URL(string: "https://www.icloud.com/share/" + b64)
    }
    static func decode(_ url: URL) -> (container: String, recordID: CKRecord.ID)? {
        guard url.host == "www.icloud.com", url.pathComponents.count >= 3, url.pathComponents[1] == "share" else { return nil }
        var b64 = url.pathComponents[2].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let d = Data(base64Encoded: b64), let token = String(data: d, encoding: .utf8) else { return nil }
        let p = token.components(separatedBy: "\u{1f}")
        guard p.count == 4 else { return nil }
        return (p[0], CKRecord.ID(recordName: p[3], zoneID: CKRecordZone.ID(zoneName: p[2], ownerName: p[1])))
    }

    @objc public init(rootRecord: CKRecord) {
        rootRecordID = rootRecord.recordID
        super.init(recordType: CKRecordTypeShare, recordID: CKRecord.ID(recordName: "Share-" + rootRecord.recordID.recordName, zoneID: rootRecord.recordID.zoneID))
        rootRecord.parent = CKRecord.Reference(recordID: recordID, action: .none)
    }
    @objc public init(rootRecord: CKRecord, shareID: CKRecord.ID) {
        rootRecordID = rootRecord.recordID
        super.init(recordType: CKRecordTypeShare, recordID: shareID)
        rootRecord.parent = CKRecord.Reference(recordID: recordID, action: .none)
    }
    @objc public init(recordZoneID: CKRecordZone.ID) {
        rootRecordID = nil
        super.init(recordType: CKRecordTypeShare, recordID: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: recordZoneID))
    }
    @objc init(recordID: CKRecord.ID) { rootRecordID = nil; super.init(recordType: CKRecordTypeShare, recordID: recordID) }
    @objc public override init?(coder: NSCoder) { rootRecordID = nil; super.init(coder: coder) }
    static func currentUser(role: ParticipantRole, permission: ParticipantPermission, status: ParticipantAcceptanceStatus) -> Participant {
        let a = _CKEnv.account
        var name = PersonNameComponents(); name.givenName = a.first; name.familyName = a.last
        return Participant(CKUserIdentity(recordID: CKRecord.ID(recordName: _CKEnv.userRecordName), name: name, contacts: [a.email]), role: role, permission: permission, status: status)
    }
    @objc open func addParticipant(_ participant: Participant) {
        if participant.userIdentity.userRecordID == ownerParticipant.userIdentity.userRecordID { return }
        if !extraParticipants.contains(where: { $0.userIdentity.userRecordID == participant.userIdentity.userRecordID }) { extraParticipants.append(participant) }
    }
    @objc open func removeParticipant(_ participant: Participant) { extraParticipants.removeAll { $0 === participant || $0.userIdentity.userRecordID == participant.userIdentity.userRecordID } }

    /// what the local store keeps of a share beyond its fields
    var stored: _CKStoredShare {
        _CKStoredShare(owner: ownerParticipant.stored, root: rootRecordID?.recordName, publicPermission: publicPermission.rawValue, participants: extraParticipants.map(\.stored))
    }
    func restore(_ s: _CKStoredShare?, container: String?) {
        containerIdentifier = container
        guard let s else { return }
        ownerParticipant = Participant(s.owner)
        rootRecordID = s.root.map { CKRecord.ID(recordName: $0, zoneID: recordID.zoneID) }
        publicPermission = ParticipantPermission(rawValue: s.publicPermission) ?? .none
        extraParticipants = s.participants.map(Participant.init)
    }

    /// What a participant learns from a share's URL before accepting it: the class of the _CKShareMetadata module, where
    /// Swift finds the CKShareMetadata of UIKit's share-link delegate methods (issue #630)
    public typealias Metadata = CKShareMetadata
}

extension CKShare.Metadata {
    convenience init(container: String, share: CKShare, root: CKRecord?) {
        let role: CKShare.ParticipantRole, status: CKShare.ParticipantAcceptanceStatus, permission: CKShare.ParticipantPermission
        if let me = share.currentUserParticipant {
            role = me.role; status = me.acceptanceStatus; permission = me.permission
        } else if share.publicPermission != .none {
            role = .publicUser; status = .unknown; permission = share.publicPermission
        } else {
            role = .unknown; status = .unknown; permission = .none
        }
        self.init(_containerIdentifier: container, share: share, shareURL: share.url,
                  shareKey: "\(share.recordID.zoneID.ownerName)/\(share.recordID.zoneID.zoneName)/\(share.recordID.recordName)",
                  hierarchicalRootRecordID: share.rootRecordID, participantRole: role.rawValue, participantStatus: status.rawValue,
                  participantPermission: permission.rawValue, ownerIdentity: share.owner.userIdentity, rootRecord: root)
    }
    @objc public var share: CKShare { _share as! CKShare }
    @objc public var hierarchicalRootRecordID: CKRecord.ID? { _hierarchicalRootRecordID as? CKRecord.ID }
    public var participantRole: CKShare.ParticipantRole { CKShare.ParticipantRole(rawValue: _participantRole) ?? .unknown }
    public var participantStatus: CKShare.ParticipantAcceptanceStatus { CKShare.ParticipantAcceptanceStatus(rawValue: _participantStatus) ?? .unknown }
    public var participantPermission: CKShare.ParticipantPermission { CKShare.ParticipantPermission(rawValue: _participantPermission) ?? .unknown }
    @objc public var ownerIdentity: CKUserIdentity { _ownerIdentity as! CKUserIdentity }
    /// Fetched when the operation's shouldFetchRootRecord is set.
    @objc public internal(set) var rootRecord: CKRecord? {
        get { _rootRecord as? CKRecord }
        set { _rootRecord = newValue }
    }
    /// The shared record, or for a zone-wide share the share's own record ID.
    public var rootRecordID: CKRecord.ID { hierarchicalRootRecordID ?? share.recordID }
}

/// The record name of a zone-wide share.
public let CKRecordNameZoneWideShare = "cloudkit.zoneshare"

extension CKContainer {
    private func identity(_ lookup: CKUserIdentity.LookupInfo) -> CKUserIdentity {
        if let id = lookup.userRecordID, id.recordName == _CKEnv.userRecordName {
            let a = _CKEnv.account
            var n = PersonNameComponents(); n.givenName = a.first; n.familyName = a.last
            return CKUserIdentity(recordID: id, name: n, contacts: [a.email])
        }
        if let email = lookup.emailAddress {                  /* the record name that account has when it is signed in */
            var n = PersonNameComponents(); n.givenName = email.split(separator: "@").first.map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return CKUserIdentity(recordID: CKRecord.ID(recordName: _CKEnv.recordName(forEmail: email)), name: n, contacts: [email])
        }
        let key = lookup.phoneNumber ?? lookup.userRecordID?.recordName ?? "unknown"
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
    @objc public func discoverUserIdentity(withEmailAddress email: String, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        discoverUserIdentity(with: CKUserIdentity.LookupInfo(emailAddress: email), completionHandler: completionHandler)
    }
    @objc public func discoverUserIdentity(withPhoneNumber phoneNumber: String, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        discoverUserIdentity(with: CKUserIdentity.LookupInfo(phoneNumber: phoneNumber), completionHandler: completionHandler)
    }
    @objc public func discoverUserIdentity(withUserRecordID recordID: CKRecord.ID, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        discoverUserIdentity(with: CKUserIdentity.LookupInfo(userRecordID: recordID), completionHandler: completionHandler)
    }
    @objc(discoverUserIdentityWithLookupInfo:completionHandler:) public func discoverUserIdentity(with lookupInfo: CKUserIdentity.LookupInfo, completionHandler: @escaping @Sendable (CKUserIdentity?, Error?) -> Void) {
        guard _CKEnv.accountStatus == .available else { CKDatabase.reply { completionHandler(nil, CKError(.notAuthenticated)) }; return }
        let result = identity(lookupInfo); CKDatabase.reply { completionHandler(result, nil) }
    }
    @objc public func discoverAllIdentities(with lookupInfos: [CKUserIdentity.LookupInfo], completionHandler: @escaping @Sendable ([CKUserIdentity]?, Error?) -> Void) {
        guard _CKEnv.accountStatus == .available else { CKDatabase.reply { completionHandler(nil, CKError(.notAuthenticated)) }; return }
        let results = lookupInfos.map(identity); CKDatabase.reply { completionHandler(results, nil) }
    }
    @nonobjc public func userIdentity(forUserRecordID recordID: CKRecord.ID) async throws -> CKUserIdentity { identity(CKUserIdentity.LookupInfo(userRecordID: recordID)) }
    @nonobjc public func userIdentity(forEmailAddress email: String) async throws -> CKUserIdentity { identity(CKUserIdentity.LookupInfo(emailAddress: email)) }
    @nonobjc public func userIdentity(forPhoneNumber phoneNumber: String) async throws -> CKUserIdentity { identity(CKUserIdentity.LookupInfo(phoneNumber: phoneNumber)) }
    @objc public func fetchShareParticipant(withEmailAddress email: String, completionHandler: @escaping @Sendable (CKShare.Participant?, Error?) -> Void) {
        let p = CKShare.Participant(identity(CKUserIdentity.LookupInfo(emailAddress: email)), role: .privateUser, permission: .readOnly, status: .pending)
        CKDatabase.reply { completionHandler(p, nil) }
    }
    @objc public func fetchShareParticipant(withPhoneNumber phoneNumber: String, completionHandler: @escaping @Sendable (CKShare.Participant?, Error?) -> Void) {
        let p = CKShare.Participant(identity(CKUserIdentity.LookupInfo(phoneNumber: phoneNumber)), role: .privateUser, permission: .readOnly, status: .pending)
        CKDatabase.reply { completionHandler(p, nil) }
    }
    @objc public func fetchShareParticipant(withUserRecordID recordID: CKRecord.ID, completionHandler: @escaping @Sendable (CKShare.Participant?, Error?) -> Void) {
        let p = CKShare.Participant(identity(CKUserIdentity.LookupInfo(userRecordID: recordID)), role: .privateUser, permission: .readOnly, status: .pending)
        CKDatabase.reply { completionHandler(p, nil) }
    }
    @nonobjc public func shareParticipant(forEmailAddress email: String) async throws -> CKShare.Participant {
        CKShare.Participant(identity(CKUserIdentity.LookupInfo(emailAddress: email)), role: .privateUser, permission: .readOnly, status: .pending)
    }
    @nonobjc public func shareParticipant(forPhoneNumber phoneNumber: String) async throws -> CKShare.Participant {
        CKShare.Participant(identity(CKUserIdentity.LookupInfo(phoneNumber: phoneNumber)), role: .privateUser, permission: .readOnly, status: .pending)
    }
    @nonobjc public func shareParticipant(forUserRecordID recordID: CKRecord.ID) async throws -> CKShare.Participant {
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
