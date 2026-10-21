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
    public struct SystemFieldKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let title = SystemFieldKey(rawValue: "cloudkit.title")
        public static let thumbnailImageData = SystemFieldKey(rawValue: "cloudkit.thumbnailImageData")
        public static let shareType = SystemFieldKey(rawValue: "cloudkit.shareType")
    }
    public enum ParticipantAccessOptions: UInt, Sendable { case anyoneWithLink = 1, specifiedRecipientsOnly = 2 }
    public internal(set) var rootRecordID: CKRecord.ID?
    open var publicPermission: ParticipantPermission = .none
    private var ownerParticipant: Participant = CKShare.currentUser(role: .owner, permission: .readWrite, status: .accepted)
    private var extraParticipants: [Participant] = []
    var containerIdentifier: String?                      // set on shares read from (or saved to) a database
    public var owner: Participant { ownerParticipant }
    /// The participant that is the device's current user (nil when the user has no part in the share).
    public var currentUserParticipant: Participant? { participants.first { $0.userIdentity.userRecordID?.recordName == _CKEnv.userRecordName } }
    public var participants: [Participant] { [ownerParticipant] + extraParticipants }
    /// The link participants open: set once the share is saved (isim: it names the share's container, zone and record,
    /// which is how any app on the device finds the share in the local store).
    open var url: URL? {
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

    public init(rootRecord: CKRecord) {
        rootRecordID = rootRecord.recordID
        super.init(recordType: CKRecordTypeShare, recordID: CKRecord.ID(recordName: "Share-" + rootRecord.recordID.recordName, zoneID: rootRecord.recordID.zoneID))
        rootRecord.parent = CKRecord.Reference(recordID: recordID, action: .none)
    }
    public init(rootRecord: CKRecord, shareID: CKRecord.ID) {
        rootRecordID = rootRecord.recordID
        super.init(recordType: CKRecordTypeShare, recordID: shareID)
        rootRecord.parent = CKRecord.Reference(recordID: recordID, action: .none)
    }
    public init(recordZoneID: CKRecordZone.ID) {
        rootRecordID = nil
        super.init(recordType: CKRecordTypeShare, recordID: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: recordZoneID))
    }
    init(recordID: CKRecord.ID) { rootRecordID = nil; super.init(recordType: CKRecordTypeShare, recordID: recordID) }
    public override init?(coder: NSCoder) { rootRecordID = nil; super.init(coder: coder) }
    static func currentUser(role: ParticipantRole, permission: ParticipantPermission, status: ParticipantAcceptanceStatus) -> Participant {
        let a = _CKEnv.account
        var name = PersonNameComponents(); name.givenName = a.first; name.familyName = a.last
        return Participant(CKUserIdentity(recordID: CKRecord.ID(recordName: _CKEnv.userRecordName), name: name, contacts: [a.email]), role: role, permission: permission, status: status)
    }
    open func addParticipant(_ participant: Participant) {
        if participant.userIdentity.userRecordID == ownerParticipant.userIdentity.userRecordID { return }
        if !extraParticipants.contains(where: { $0.userIdentity.userRecordID == participant.userIdentity.userRecordID }) { extraParticipants.append(participant) }
    }
    open func removeParticipant(_ participant: Participant) { extraParticipants.removeAll { $0 === participant || $0.userIdentity.userRecordID == participant.userIdentity.userRecordID } }

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

    /// What a participant learns from a share's URL before accepting it.
    @objc(CKShareMetadata) open class Metadata: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
        public let containerIdentifier: String
        public let share: CKShare
        public let hierarchicalRootRecordID: CKRecord.ID?
        public let participantRole: ParticipantRole
        public let participantStatus: ParticipantAcceptanceStatus
        public let participantPermission: ParticipantPermission
        public let ownerIdentity: CKUserIdentity
        /// Fetched when the operation's shouldFetchRootRecord is set.
        public internal(set) var rootRecord: CKRecord?
        /// The shared record, or for a zone-wide share the share's own record ID.
        public var rootRecordID: CKRecord.ID { hierarchicalRootRecordID ?? share.recordID }
        init(container: String, share: CKShare, root: CKRecord?) {
            containerIdentifier = container; self.share = share; rootRecord = root
            hierarchicalRootRecordID = share.rootRecordID
            ownerIdentity = share.owner.userIdentity
            if let me = share.currentUserParticipant {
                participantRole = me.role; participantStatus = me.acceptanceStatus; participantPermission = me.permission
            } else if share.publicPermission != .none {
                participantRole = .publicUser; participantStatus = .unknown; participantPermission = share.publicPermission
            } else {
                participantRole = .unknown; participantStatus = .unknown; participantPermission = .none
            }
        }
        public func copy(with zone: NSZone? = nil) -> Any { self }
        public static var supportsSecureCoding: Bool { true }
        public func encode(with coder: NSCoder) {
            coder.encode(share.url?.absoluteString as NSString?, forKey: "url")
        }
        public required init?(coder: NSCoder) {                /* decoded from its share's URL, against the local store */
            guard let s = coder.decodeObject(of: NSString.self, forKey: "url") as String?, let url = URL(string: s),
                  case .success(let m)? = try? CKContainer._shareMetadata(url, fetchRoot: false, desiredKeys: nil) else { return nil }
            containerIdentifier = m.containerIdentifier; share = m.share; hierarchicalRootRecordID = m.hierarchicalRootRecordID
            participantRole = m.participantRole; participantStatus = m.participantStatus; participantPermission = m.participantPermission
            ownerIdentity = m.ownerIdentity; rootRecord = nil
        }
        open override func isEqual(_ object: Any?) -> Bool {
            guard let o = object as? Metadata else { return false }
            return o.containerIdentifier == containerIdentifier && o.share.recordID == share.recordID
        }
        open override var hash: Int { containerIdentifier.hashValue ^ share.recordID.hashValue }
    }
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
