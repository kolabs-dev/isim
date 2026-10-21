// What isim's sharing sheet (UIKit's UICloudSharingController, in Objective-C) reads and changes on a share. CKShare is
// a Swift class with no Objective-C interface yet, so the sheet reaches it through these internal @objc methods (in the
// Objective-C runtime only: no exported Swift symbols).
import Foundation

extension CKShare {
    /// The share as the sheet shows it: "people" (owner first; each "name", "me", "role", "status" and "permission",
    /// the raw values of CKShare's enums), "publicPermission", "url" and "title".
    @objc(_isimSharingSheetInfo) func _isimSharingSheetInfo() -> NSDictionary {
        let me = _CKEnv.userRecordName
        let people: [NSDictionary] = participants.map { p in
            let n = p.userIdentity.nameComponents
            let name = [n?.givenName, n?.familyName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let row: [String: Any] = ["name": name.isEmpty ? (p.userIdentity.contactIdentifiers.first ?? "Unknown") : name,
                                      "me": p.userIdentity.userRecordID?.recordName == me,
                                      "role": p.role.rawValue, "status": p.acceptanceStatus.rawValue, "permission": p.permission.rawValue]
            return row as NSDictionary
        }
        var info: [String: Any] = ["people": people, "publicPermission": publicPermission.rawValue]
        if let u = url { info["url"] = u }
        if let t = self[SystemFieldKey.title.rawValue] as? String { info["title"] = t }
        if let d = self[SystemFieldKey.thumbnailImageData.rawValue] as? Data { info["thumbnail"] = d }
        return info as NSDictionary
    }

    /// The sheet's Share Options: who can access and their permission (CKShare.ParticipantPermission raw value): the
    /// link's permission when anyone with it can open the share, else the invited participants'.
    @objc(_isimSetSharingAnyone:permission:) func _isimSetSharing(anyone: Bool, permission raw: Int) {
        CKContainer._watchSharingUI()                                  // Done saves the change
        let permission = ParticipantPermission(rawValue: raw) ?? .readOnly
        publicPermission = anyone ? permission : .none
        if !anyone { for p in participants where p.role != .owner { p.permission = permission } }
    }
}
