// isim CloudKit: the Objective-C interface (sdk-src/Frameworks/CloudKit, issue #573). The classes are @objc(CK…) and
// @objcMembers, nested ones under Apple's Objective-C names (CKRecordID, CKRecordZoneID, CKReference, CKQueryCursor, …),
// so what Objective-C can represent is exported under Apple's names; the members below are internal Objective-C entry
// points, under Apple's selectors, for what uses Swift-only types:
//   - record values (CKRecordValue is a Swift protocol here): objectForKey: and the keyed subscripts take and return
//     Objective-C objects, and encryptedValues is an object with the same methods;
//   - the operations' per-item and completion blocks, which are Result-based in Swift: Objective-C's (item, object,
//     NSError) blocks are kept in a per-operation state object and the Swift blocks call them (the aggregate blocks of
//     CKFetchRecordZonesOperation and CKFetchSubscriptionsOperation collect the items);
//   - the enums and option sets as their raw values, and QualityOfService as NSQualityOfService.
import Foundation
import ObjectiveC
import UIKit

typealias _CKItemBlock<ID, T> = (ID, T?, Error?) -> Void

/// the Objective-C blocks an operation was given (associated with the operation)
final class _CKObjCState: NSObject {
    var blocks: [String: Any] = [:]
    var found: [AnyHashable: Any] = [:]
    var partial: [AnyHashable: Error] = [:]
    subscript<T>(_ key: String, as _: T.Type) -> T? { blocks[key] as? T }
}

enum _CKObjC {
    nonisolated(unsafe) static var stateKey = 0
    static func state(_ o: AnyObject) -> _CKObjCState {
        withUnsafePointer(to: &stateKey) { k in
            if let s = objc_getAssociatedObject(o, k) as? _CKObjCState { return s }
            let s = _CKObjCState()
            objc_setAssociatedObject(o, k, s, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return s
        }
    }
    static func object(_ v: CKRecordValue?) -> Any? { v.map { $0 as AnyObject } }
    static func error<T>(_ r: Result<T, Error>) -> Error? { if case .failure(let e) = r { return e }; return nil }
    static func value<T>(_ r: Result<T, Error>) -> T? { try? r.get() }
    static func partial(_ s: _CKObjCState, _ r: Result<Void, Error>) -> Error? {
        if let e = error(r) { return e }
        return s.partial.isEmpty ? nil : CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: s.partial])
    }
}

// MARK: - containers and databases

extension CKContainer {
    @objc(defaultContainer) class func _objcDefaultContainer() -> CKContainer { CKContainer.default() }
    @objc(addOperation:) func _objcAdd(_ operation: CKOperation) { add(operation) }
    @objc(databaseWithDatabaseScope:) func _objcDatabase(_ scope: Int) -> CKDatabase { database(with: CKDatabase.Scope(rawValue: scope) ?? .private) }
    @objc(accountStatusWithCompletionHandler:) func _objcAccountStatus(_ completion: @escaping @Sendable (Int, Error?) -> Void) {
        accountStatus { s, e in completion(s.rawValue, e) }
    }
}

extension CKDatabase {
    @objc(addOperation:) func _objcAdd(_ operation: CKDatabaseOperation) { add(operation) }
    @objc(databaseScope) var _objcDatabaseScope: Int { databaseScope.rawValue }
}

// MARK: - records

/// encryptedValues as Objective-C sees it (id<CKRecordKeyValueSetting>)
@objc(_ISIMCKEncryptedValues) final class _CKObjCEncryptedValues: NSObject {
    let r: CKRecord
    init(_ r: CKRecord) { self.r = r }
    @objc(objectForKey:) func object(forKey key: String) -> Any? { _CKObjC.object(r[key]) }
    @objc(setObject:forKey:) func setObject(_ v: Any?, forKey key: String) { r.setField(key, v) }
    @objc(objectForKeyedSubscript:) func object(forKeyedSubscript key: String) -> Any? { object(forKey: key) }
    @objc(setObject:forKeyedSubscript:) func setObject(_ v: Any?, forKeyedSubscript key: String) { setObject(v, forKey: key) }
    @objc(allKeys) func allKeys() -> [String] { r.allKeys() }
    @objc(changedKeys) func changedKeys() -> [String] { r.changedKeys() }
}

extension CKRecord {
    @objc(objectForKey:) func _objcObject(forKey key: String) -> Any? { _CKObjC.object(self[key]) }
    @objc(setObject:forKey:) func _objcSetObject(_ v: Any?, forKey key: String) { setField(key, v) }
    @objc(objectForKeyedSubscript:) func _objcObject(forKeyedSubscript key: String) -> Any? { _CKObjC.object(self[key]) }
    @objc(setObject:forKeyedSubscript:) func _objcSetObject(_ v: Any?, forKeyedSubscript key: String) { setField(key, v) }
    @objc(encryptedValues) var _objcEncryptedValues: _CKObjCEncryptedValues { _CKObjCEncryptedValues(self) }
    @objc(encodeSystemFieldsWithCoder:) func _objcEncodeSystemFields(_ coder: NSCoder) { encodeSystemFields(with: coder) }
}

extension CKRecordZone {
    @objc(defaultRecordZone) class func _objcDefaultRecordZone() -> CKRecordZone { CKRecordZone.default() }
    @objc(capabilities) var _objcCapabilities: UInt {
        get { capabilities.rawValue }
        set { capabilities = Capabilities(rawValue: newValue) }
    }
}

extension CKRecord.Reference {
    @objc(referenceAction) var _objcAction: UInt { action.rawValue }
    /// -initWithRecordID:action: and -initWithRecord:action: (CloudKit.framework) make the reference here
    @objc(_isim_referenceWithRecordID:action:) class func _isimReference(_ id: CKRecord.ID, action: UInt) -> CKRecord.Reference {
        CKRecord.Reference(recordID: id, action: CKRecord.ReferenceAction(rawValue: action) ?? .none)
    }
}

// MARK: - operations

extension CKOperation {
    @objc(qualityOfService) var _objcQualityOfService: Int {
        get { qualityOfService.rawValue }
        set { qualityOfService = QualityOfService(rawValue: newValue) ?? .default }
    }
}

extension CKOperation.Configuration {
    @objc(qualityOfService) var _objcQualityOfService: Int {
        get { qualityOfService.rawValue }
        set { qualityOfService = QualityOfService(rawValue: newValue) ?? .default }
    }
}

extension CKQueryOperation {
    @objc(recordMatchedBlock) var _objcRecordMatched: _CKItemBlock<CKRecord.ID, CKRecord>? {
        get { _CKObjC.state(self)["recordMatched", as: _CKItemBlock<CKRecord.ID, CKRecord>.self] }
        set {
            _CKObjC.state(self).blocks["recordMatched"] = newValue
            recordMatchedBlock = newValue.map { b in { id, r in b(id, _CKObjC.value(r), _CKObjC.error(r)) } }
        }
    }
}

extension CKModifyRecordsOperation {
    @objc(savePolicy) var _objcSavePolicy: Int {
        get { savePolicy.rawValue }
        set { savePolicy = RecordSavePolicy(rawValue: newValue) ?? .ifServerRecordUnchanged }
    }
    @objc(perRecordSaveBlock) var _objcPerRecordSave: _CKItemBlock<CKRecord.ID, CKRecord>? {
        get { _CKObjC.state(self)["save", as: _CKItemBlock<CKRecord.ID, CKRecord>.self] }
        set {
            _CKObjC.state(self).blocks["save"] = newValue
            perRecordSaveBlock = newValue.map { b in { id, r in b(id, _CKObjC.value(r), _CKObjC.error(r)) } }
        }
    }
    @objc(perRecordDeleteBlock) var _objcPerRecordDelete: ((CKRecord.ID, Error?) -> Void)? {
        get { _CKObjC.state(self)["delete", as: ((CKRecord.ID, Error?) -> Void).self] }
        set {
            _CKObjC.state(self).blocks["delete"] = newValue
            perRecordDeleteBlock = newValue.map { b in { id, r in b(id, _CKObjC.error(r)) } }
        }
    }
}

extension CKModifyRecordZonesOperation {
    @objc(perRecordZoneSaveBlock) var _objcPerZoneSave: _CKItemBlock<CKRecordZone.ID, CKRecordZone>? {
        get { _CKObjC.state(self)["save", as: _CKItemBlock<CKRecordZone.ID, CKRecordZone>.self] }
        set {
            _CKObjC.state(self).blocks["save"] = newValue
            perRecordZoneSaveBlock = newValue.map { b in { id, r in b(id, _CKObjC.value(r), _CKObjC.error(r)) } }
        }
    }
    @objc(perRecordZoneDeleteBlock) var _objcPerZoneDelete: ((CKRecordZone.ID, Error?) -> Void)? {
        get { _CKObjC.state(self)["delete", as: ((CKRecordZone.ID, Error?) -> Void).self] }
        set {
            _CKObjC.state(self).blocks["delete"] = newValue
            perRecordZoneDeleteBlock = newValue.map { b in { id, r in b(id, _CKObjC.error(r)) } }
        }
    }
}

extension CKModifySubscriptionsOperation {
    @objc(perSubscriptionSaveBlock) var _objcPerSubscriptionSave: _CKItemBlock<String, CKSubscription>? {
        get { _CKObjC.state(self)["save", as: _CKItemBlock<String, CKSubscription>.self] }
        set {
            _CKObjC.state(self).blocks["save"] = newValue
            perSubscriptionSaveBlock = newValue.map { b in { id, r in b(id, _CKObjC.value(r), _CKObjC.error(r)) } }
        }
    }
    @objc(perSubscriptionDeleteBlock) var _objcPerSubscriptionDelete: ((String, Error?) -> Void)? {
        get { _CKObjC.state(self)["delete", as: ((String, Error?) -> Void).self] }
        set {
            _CKObjC.state(self).blocks["delete"] = newValue
            perSubscriptionDeleteBlock = newValue.map { b in { id, r in b(id, _CKObjC.error(r)) } }
        }
    }
}

extension CKFetchRecordZoneChangesOperation {
    @objc(recordWasChangedBlock) var _objcRecordWasChanged: _CKItemBlock<CKRecord.ID, CKRecord>? {
        get { _CKObjC.state(self)["changed", as: _CKItemBlock<CKRecord.ID, CKRecord>.self] }
        set {
            _CKObjC.state(self).blocks["changed"] = newValue
            recordWasChangedBlock = newValue.map { b in { id, r in b(id, _CKObjC.value(r), _CKObjC.error(r)) } }
        }
    }
    typealias _ObjCZoneFetch = (CKRecordZone.ID, CKServerChangeToken?, Data?, Bool, Error?) -> Void
    @objc(recordZoneFetchCompletionBlock) var _objcRecordZoneFetch: _ObjCZoneFetch? {
        get { _CKObjC.state(self)["zone", as: _ObjCZoneFetch.self] }
        set {
            _CKObjC.state(self).blocks["zone"] = newValue
            recordZoneFetchResultBlock = newValue.map { b in { id, r in
                switch r {
                case .success(let v): b(id, v.serverChangeToken, v.clientChangeTokenData, v.moreComing, nil)
                case .failure(let e): b(id, nil, nil, false, e)
                }
            } }
        }
    }
}

extension CKFetchRecordZonesOperation {
    @objc(perRecordZoneCompletionBlock) var _objcPerZone: _CKItemBlock<CKRecordZone.ID, CKRecordZone>? {
        get { _CKObjC.state(self)["item", as: _CKItemBlock<CKRecordZone.ID, CKRecordZone>.self] }
        set { _CKObjC.state(self).blocks["item"] = newValue; _objcInstall() }
    }
    @objc(fetchRecordZonesCompletionBlock) var _objcFetchZones: (([CKRecordZone.ID: CKRecordZone]?, Error?) -> Void)? {
        get { _CKObjC.state(self)["all", as: (([CKRecordZone.ID: CKRecordZone]?, Error?) -> Void).self] }
        set { _CKObjC.state(self).blocks["all"] = newValue; _objcInstall() }
    }
    func _objcInstall() {
        let s = _CKObjC.state(self)
        perRecordZoneResultBlock = { id, r in
            switch r { case .success(let z): s.found[id] = z; case .failure(let e): s.partial[id] = e }
            s["item", as: _CKItemBlock<CKRecordZone.ID, CKRecordZone>.self]?(id, _CKObjC.value(r), _CKObjC.error(r))
        }
        fetchRecordZonesResultBlock = { r in
            let e = _CKObjC.partial(s, r)
            let found = s.found as? [CKRecordZone.ID: CKRecordZone] ?? [:]
            s["all", as: (([CKRecordZone.ID: CKRecordZone]?, Error?) -> Void).self]?(found, e)
        }
    }
}

extension CKFetchSubscriptionsOperation {
    @objc(perSubscriptionCompletionBlock) var _objcPerSubscription: _CKItemBlock<String, CKSubscription>? {
        get { _CKObjC.state(self)["item", as: _CKItemBlock<String, CKSubscription>.self] }
        set { _CKObjC.state(self).blocks["item"] = newValue; _objcInstall() }
    }
    @objc(fetchSubscriptionCompletionBlock) var _objcFetchSubscriptions: (([String: CKSubscription]?, Error?) -> Void)? {
        get { _CKObjC.state(self)["all", as: (([String: CKSubscription]?, Error?) -> Void).self] }
        set { _CKObjC.state(self).blocks["all"] = newValue; _objcInstall() }
    }
    func _objcInstall() {
        let s = _CKObjC.state(self)
        perSubscriptionResultBlock = { id, r in
            switch r { case .success(let x): s.found[id] = x; case .failure(let e): s.partial[id] = e }
            s["item", as: _CKItemBlock<String, CKSubscription>.self]?(id, _CKObjC.value(r), _CKObjC.error(r))
        }
        fetchSubscriptionsResultBlock = { r in
            let e = _CKObjC.partial(s, r)
            let found = s.found as? [String: CKSubscription] ?? [:]
            s["all", as: (([String: CKSubscription]?, Error?) -> Void).self]?(found, e)
        }
    }
}

extension CKFetchShareMetadataOperation {
    @objc(perShareMetadataBlock) var _objcPerShareMetadata: _CKItemBlock<URL, CKShare.Metadata>? {
        get { _CKObjC.state(self)["item", as: _CKItemBlock<URL, CKShare.Metadata>.self] }
        set {
            _CKObjC.state(self).blocks["item"] = newValue
            perShareMetadataResultBlock = newValue.map { b in { u, r in b(u, _CKObjC.value(r), _CKObjC.error(r)) } }
        }
    }
    @objc(fetchShareMetadataCompletionBlock) var _objcFetchShareMetadata: ((Error?) -> Void)? {
        get { _CKObjC.state(self)["all", as: ((Error?) -> Void).self] }
        set {
            _CKObjC.state(self).blocks["all"] = newValue
            fetchShareMetadataResultBlock = newValue.map { b in { r in b(_CKObjC.error(r)) } }
        }
    }
}

extension CKAcceptSharesOperation {
    @objc(perShareCompletionBlock) var _objcPerShare: _CKItemBlock<CKShare.Metadata, CKShare>? {
        get { _CKObjC.state(self)["item", as: _CKItemBlock<CKShare.Metadata, CKShare>.self] }
        set {
            _CKObjC.state(self).blocks["item"] = newValue
            perShareResultBlock = newValue.map { b in { m, r in b(m, _CKObjC.value(r), _CKObjC.error(r)) } }
        }
    }
    @objc(acceptSharesCompletionBlock) var _objcAcceptShares: ((Error?) -> Void)? {
        get { _CKObjC.state(self)["all", as: ((Error?) -> Void).self] }
        set {
            _CKObjC.state(self).blocks["all"] = newValue
            acceptSharesResultBlock = newValue.map { b in { r in b(_CKObjC.error(r)) } }
        }
    }
}

// MARK: - subscriptions and notifications

extension CKSubscription {
    @objc(subscriptionType) var _objcSubscriptionType: Int { subscriptionType.rawValue }
}

extension CKQuerySubscription {
    @objc(querySubscriptionOptions) var _objcOptions: UInt { querySubscriptionOptions.rawValue }
    /// -initWithRecordType:predicate:[subscriptionID:]options: (CloudKit.framework) make the subscription here
    @objc(_isim_subscriptionWithRecordType:predicate:subscriptionID:options:)
    class func _isimSubscription(_ type: String, predicate: NSPredicate, subscriptionID: String?, options: UInt) -> CKQuerySubscription {
        CKQuerySubscription(recordType: type, predicate: predicate, subscriptionID: subscriptionID ?? UUID().uuidString, options: Options(rawValue: options))
    }
}

extension CKNotification {
    @objc(notificationFromRemoteNotificationDictionary:) class func _objcNotification(_ info: [AnyHashable: Any]) -> CKNotification? {
        make(fromRemoteNotificationDictionary: info)
    }
    @objc(notificationType) var _objcNotificationType: Int { notificationType.rawValue }
}

extension CKQueryNotification {
    @objc(queryNotificationReason) var _objcReason: Int { queryNotificationReason.rawValue }
    @objc(databaseScope) var _objcDatabaseScope: Int { databaseScope.rawValue }
}
extension CKDatabaseNotification {
    @objc(databaseScope) var _objcDatabaseScope: Int { databaseScope.rawValue }
}
extension CKRecordZoneNotification {
    @objc(databaseScope) var _objcDatabaseScope: Int { databaseScope.rawValue }
}

// MARK: - sharing

extension CKShare {
    @objc(URL) var _objcURL: URL? { url }
    @objc(publicPermission) var _objcPublicPermission: Int {
        get { publicPermission.rawValue }
        set { publicPermission = ParticipantPermission(rawValue: newValue) ?? .none }
    }
}

extension CKShare.Participant {
    @objc(role) var _objcRole: Int { role.rawValue }
    @objc(acceptanceStatus) var _objcAcceptanceStatus: Int { acceptanceStatus.rawValue }
    @objc(permission) var _objcPermission: Int {
        get { permission.rawValue }
        set { permission = CKShare.ParticipantPermission(rawValue: newValue) ?? .unknown }
    }
}

extension CKAllowedSharingOptions {
    @objc(standardOptions) class var _objcStandardOptions: CKAllowedSharingOptions { standard }
    @objc(allowedParticipantPermissionOptions) var _objcPermissionOptions: UInt {
        get { allowedParticipantPermissionOptions.rawValue }
        set { allowedParticipantPermissionOptions = CKSharingParticipantPermissionOption(rawValue: newValue) }
    }
    @objc(allowedParticipantAccessOptions) var _objcAccessOptions: UInt {
        get { allowedParticipantAccessOptions.rawValue }
        set { allowedParticipantAccessOptions = CKSharingParticipantAccessOption(rawValue: newValue) }
    }
    /// -initWithAllowedParticipantPermissionOptions:allowedParticipantAccessOptions: (CloudKit.framework) makes it here
    @objc(_isim_optionsWithPermissions:access:) class func _isimOptions(_ p: UInt, access a: UInt) -> CKAllowedSharingOptions {
        CKAllowedSharingOptions(allowedParticipantPermissionOptions: CKSharingParticipantPermissionOption(rawValue: p),
                                allowedParticipantAccessOptions: CKSharingParticipantAccessOption(rawValue: a))
    }
}

// MARK: - share links (UIKit, issue #575)

extension CKContainer {
    /// the metadata UIKit hands an app for a CloudKit share link it opened (UISystemIntegration.m); nil, logged, when
    /// the share cannot be read
    @objc(_isim_shareMetadataWithURL:) class func _isimShareMetadata(_ url: URL) -> CKShare.Metadata? {
        switch (try? _shareMetadata(url, fetchRoot: false, desiredKeys: nil)) ?? .failure(CKError(.internalError)) {
        case .success(let m): return m
        case .failure(let e): NSLog("isim CloudKit: share link %@: %@", url.absoluteString, e.localizedDescription); return nil
        }
    }
}
