// isim HomeKit: the home manager, homes, rooms, zones, service groups and users, over the device's home data (Store.swift).
// Access needs the com.apple.developer.homekit entitlement and NSHomeKitUsageDescription; the first HMHomeManager asks
// with isim's "Would Like to Access Your Home Data" alert (ISIM_HOMEKIT_PERMISSION=allow|deny answers it).
@_exported import HomeKit
import Foundation
import UIKit

enum _HMAccess {
    static var entitled: Bool {
        let xcent = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        return ((NSDictionary(contentsOfFile: xcent) as? [String: Any])?["com.apple.developer.homekit"] as? Bool) == true
    }
    /// the app's answer: nil before it was asked
    static var allowed: Bool? {
        switch _Privacy.stored("homekit") { case 1: return true; case 0: return false; default: return nil }
    }
    static var status: HMHomeManagerAuthorizationStatus {
        switch allowed { case true?: return [.determined, .authorized]; case false?: return [.determined]; default: return [] }
    }
    static func ask(_ done: @escaping (Bool) -> Void) {
        if let a = allowed { done(a); return }
        func answer(_ ok: Bool) {
            _Privacy.store("homekit", ok ? 1 : 0)
            NSLog("isim HomeKit: home data %@ for %@", ok ? "allowed" : "denied", _Privacy.appName)
            done(ok)
        }
        guard entitled else {
            NSLog("isim HomeKit: the app does not have the com.apple.developer.homekit entitlement")
            done(false); return
        }
        guard let purpose = _Privacy.usage("NSHomeKitUsageDescription", "HomeKit") else { answer(false); return }
        if let s = _Privacy.scripted("HOMEKIT") { answer(!(s == "deny" || s == "denied" || s == "no" || s == "0")); return }
        _Privacy.onMain {
            _Privacy.alert("“\(_Privacy.appName)” Would Like to Access Your Home Data", purpose,
                           [("Don’t Allow", .cancel), ("OK", .default)]) { answer($0 == 1) }
        }
    }
    /// an operation's error when the app may not use the home data
    static var denied: Error? {
        if !entitled { return HMError(.missingEntitlement) }
        return allowed == true ? nil : HMError(.homeAccessNotAuthorized)
    }
}

func _hmErr(_ code: HMError.Code, _ text: String? = nil) -> NSError {
    let e = text.map { HMError(code, $0) } ?? HMError(code)
    return NSError(domain: HMError.errorDomain, code: code.rawValue, userInfo: e.errorUserInfo)
}

/// checks a name like HomeKit does: not empty, letters or digits first and last, not taken
func _hmNameError(_ name: String, taken: [String], code: HMError.Code = .objectWithSimilarNameExistsInHome) -> NSError? {
    let t = name.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return _hmErr(.invalidParameter, "The name is empty.") }
    if let f = t.unicodeScalars.first, !CharacterSet.alphanumerics.contains(f) { return _hmErr(.nameDoesNotStartWithValidCharacters) }
    if let l = t.unicodeScalars.last, !CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".)'’")).contains(l) {
        return _hmErr(.nameDoesNotEndWithValidCharacters)
    }
    if taken.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) { return _hmErr(code) }
    return nil
}

// MARK: - HMHomeManager

@objc(HMHomeManagerDelegate)
public protocol HMHomeManagerDelegate: NSObjectProtocol {
    @objc(homeManagerDidUpdateHomes:) optional func homeManagerDidUpdateHomes(_ manager: HMHomeManager)
    @objc(homeManagerDidUpdatePrimaryHome:) optional func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager)
    @objc(homeManager:didAddHome:) optional func homeManager(_ manager: HMHomeManager, didAdd home: HMHome)
    @objc(homeManager:didRemoveHome:) optional func homeManager(_ manager: HMHomeManager, didRemove home: HMHome)
    @objc(homeManager:didReceiveAddAccessoryRequest:) optional func homeManager(_ manager: HMHomeManager, didReceiveAddAccessoryRequest request: HMAddAccessoryRequest)
    @objc(homeManager:didUpdateAuthorizationStatus:) optional func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus)
}

@objc(HMHomeManager)
open class HMHomeManager: NSObject {
    @objc public weak var delegate: (any HMHomeManagerDelegate)?

    public struct PairingIdentity: Sendable, Hashable {
        public let pairingIdentifier: String
        public let publicKey: Data
        public init(pairingIdentifier: String, publicKey: Data) { self.pairingIdentifier = pairingIdentifier; self.publicKey = publicKey }
    }
    public struct ProvisionalConfiguration: Sendable, Hashable {
        public let threadNetworkIdentifier: Data
        public let hubPairingIdentity: PairingIdentity
        public init(threadNetworkIdentifier: Data, hubPairingIdentity: PairingIdentity) {
            self.threadNetworkIdentifier = threadNetworkIdentifier; self.hubPairingIdentity = hubPairingIdentity
        }
        public init?(dictionaryRepresentation: [String: any Sendable]) {
            guard let t = dictionaryRepresentation["threadNetworkIdentifier"] as? Data,
                  let p = dictionaryRepresentation["pairingIdentifier"] as? String,
                  let k = dictionaryRepresentation["publicKey"] as? Data else { return nil }
            self.init(threadNetworkIdentifier: t, hubPairingIdentity: PairingIdentity(pairingIdentifier: p, publicKey: k))
        }
        public var dictionaryRepresentation: [String: any Sendable] {
            ["threadNetworkIdentifier": threadNetworkIdentifier, "pairingIdentifier": hubPairingIdentity.pairingIdentifier,
             "publicKey": hubPairingIdentity.publicKey]
        }
    }

    @objc public override init() {
        super.init()
        _HMObjects.shared.addManager(self)
        // like iOS, the manager reports its homes later, once the app has set its delegate
        DispatchQueue.main.async {
            _HMStore.shared.start()
            let before = _HMAccess.status
            _HMAccess.ask { _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if _HMAccess.status != before { self.delegate?.homeManager?(self, didUpdate: _HMAccess.status) }
                    self.delegate?.homeManagerDidUpdateHomes?(self)
                }
            }
        }
    }

    @objc public var authorizationStatus: HMHomeManagerAuthorizationStatus { _HMAccess.status }

    @objc public var homes: [HMHome] {
        guard _HMAccess.denied == nil else { return [] }
        return _HMStore.shared.data.homes.map { _HMObjects.shared.home($0.id) }
    }

    @available(iOS, introduced: 8.0, deprecated: 16.1, message: "No longer supported.")
    @objc public var primaryHome: HMHome? {
        guard _HMAccess.denied == nil, let p = _HMStore.shared.data.primary ?? _HMStore.shared.data.homes.first?.id,
              _HMStore.shared.home(p) != nil else { return nil }
        return _HMObjects.shared.home(p)
    }

    @available(iOS, introduced: 8.0, deprecated: 16.1, message: "No longer supported.")
    @objc(updatePrimaryHome:completionHandler:)
    open func updatePrimaryHome(_ home: HMHome, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard _HMStore.shared.home(home._id) != nil else { _hmReply { completion(_hmErr(.notFound)) }; return }
        _HMStore.shared.modify { $0.primary = home._id }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @objc(addHomeWithName:completionHandler:)
    open func addHome(withName homeName: String, completionHandler completion: @escaping (HMHome?, Error?) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(nil, e) }; return }
        if let e = _hmNameError(homeName, taken: _HMStore.shared.data.homes.map(\.name), code: .homeWithSimilarNameExists) {
            _hmReply { completion(nil, e) }; return
        }
        let home = _HMHomeRec.make(name: homeName)
        _HMStore.shared.modify { d in
            d.homes.append(home)
            if d.primary == nil { d.primary = home.id }
        }
        _HMStore.shared.save()
        NSLog("isim HomeKit: added home %@", homeName)
        _hmReply { completion(_HMObjects.shared.home(home.id), nil) }
    }

    @objc(removeHome:completionHandler:)
    open func removeHome(_ home: HMHome, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard _HMStore.shared.home(home._id) != nil else { _hmReply { completion(_hmErr(.notFound)) }; return }
        _HMStore.shared.modify { d in
            d.homes.removeAll { $0.id == home._id }
            if d.primary == home._id { d.primary = d.homes.first?.id }
        }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    /// a vendor's accessory by its HAP public key: isim's simulated accessories have none
    @objc(findVendorAccessoryWithHAPPublicKey:completionHandler:)
    open func findVendorAccessory(hapPublicKey: Data, completionHandler: @escaping (HMAccessory?, Error?) -> Void) {
        _hmReply { completionHandler(nil, _HMAccess.denied ?? _hmErr(.notFound)) }
    }

    /// a provisional home (iOS 26): a home on a Thread network before it joins the person's home, kept like any other
    public func addProvisionalHome(named name: String, configuration: ProvisionalConfiguration) async throws -> HMHome {
        if let e = _HMAccess.denied { throw e }
        if let e = _hmNameError(name, taken: _HMStore.shared.data.homes.map(\.name), code: .homeWithSimilarNameExists) { throw e }
        var home = _HMHomeRec.make(name: name)
        home.provisional = configuration.hubPairingIdentity.pairingIdentifier
        let rec = home
        _HMStore.shared.modify { $0.homes.append(rec) }
        _HMStore.shared.save()
        return _HMObjects.shared.home(home.id)
    }
}

extension _HMHomeRec {
    static func make(name: String) -> _HMHomeRec {
        _HMHomeRec(id: _HMStore.newID(), name: name, hub: nil, provisional: nil, rooms: [], zones: [], accessories: [], serviceGroups: [],
                   actionSets: _HMTypes.actionSetTypes.filter { $0 != "HMActionSetTypeUserDefined" && $0 != "HMActionSetTypeTriggerOwned" }.map {
                       _HMActionSetRec(id: _HMStore.newID(), name: _HMActionSet.builtinName($0), type: $0, actions: [])
                   },
                   triggers: [], users: [_HMUserRec(id: _HMStore.newID(), name: _HMHome.ownerName, admin: true)])
    }
}

// MARK: - HMHome

@objc(HMHomeDelegate)
public protocol HMHomeDelegate: NSObjectProtocol {
    @objc(homeDidUpdateName:) optional func homeDidUpdateName(_ home: HMHome)
    @objc(homeDidUpdateAccessControlForCurrentUser:) optional func homeDidUpdateAccessControl(forCurrentUser home: HMHome)
    @objc(home:didAddAccessory:) optional func home(_ home: HMHome, didAdd accessory: HMAccessory)
    @objc(home:didRemoveAccessory:) optional func home(_ home: HMHome, didRemove accessory: HMAccessory)
    @objc(home:didAddUser:) optional func home(_ home: HMHome, didAdd user: HMUser)
    @objc(home:didRemoveUser:) optional func home(_ home: HMHome, didRemove user: HMUser)
    @objc(home:didUpdateRoom:forAccessory:) optional func home(_ home: HMHome, didUpdate room: HMRoom, for accessory: HMAccessory)
    @objc(home:didAddRoom:) optional func home(_ home: HMHome, didAdd room: HMRoom)
    @objc(home:didRemoveRoom:) optional func home(_ home: HMHome, didRemove room: HMRoom)
    @objc(home:didUpdateNameForRoom:) optional func home(_ home: HMHome, didUpdateNameFor room: HMRoom)
    @objc(home:didAddZone:) optional func home(_ home: HMHome, didAdd zone: HMZone)
    @objc(home:didRemoveZone:) optional func home(_ home: HMHome, didRemove zone: HMZone)
    @objc(home:didUpdateNameForZone:) optional func home(_ home: HMHome, didUpdateNameFor zone: HMZone)
    @objc(home:didAddRoom:toZone:) optional func home(_ home: HMHome, didAdd room: HMRoom, to zone: HMZone)
    @objc(home:didRemoveRoom:fromZone:) optional func home(_ home: HMHome, didRemove room: HMRoom, from zone: HMZone)
    @objc(home:didAddServiceGroup:) optional func home(_ home: HMHome, didAdd group: HMServiceGroup)
    @objc(home:didRemoveServiceGroup:) optional func home(_ home: HMHome, didRemove group: HMServiceGroup)
    @objc(home:didUpdateNameForServiceGroup:) optional func home(_ home: HMHome, didUpdateNameFor group: HMServiceGroup)
    @objc(home:didAddService:toServiceGroup:) optional func home(_ home: HMHome, didAdd service: HMService, to group: HMServiceGroup)
    @objc(home:didRemoveService:fromServiceGroup:) optional func home(_ home: HMHome, didRemove service: HMService, from group: HMServiceGroup)
    @objc(home:didAddActionSet:) optional func home(_ home: HMHome, didAdd actionSet: HMActionSet)
    @objc(home:didRemoveActionSet:) optional func home(_ home: HMHome, didRemove actionSet: HMActionSet)
    @objc(home:didUpdateNameForActionSet:) optional func home(_ home: HMHome, didUpdateNameFor actionSet: HMActionSet)
    @objc(home:didUpdateActionsForActionSet:) optional func home(_ home: HMHome, didUpdateActionsFor actionSet: HMActionSet)
    @objc(home:didAddTrigger:) optional func home(_ home: HMHome, didAdd trigger: HMTrigger)
    @objc(home:didRemoveTrigger:) optional func home(_ home: HMHome, didRemove trigger: HMTrigger)
    @objc(home:didUpdateNameForTrigger:) optional func home(_ home: HMHome, didUpdateNameFor trigger: HMTrigger)
    @objc(home:didUpdateTrigger:) optional func home(_ home: HMHome, didUpdate trigger: HMTrigger)
    @objc(home:didUnblockAccessory:) optional func home(_ home: HMHome, didUnblockAccessory accessory: HMAccessory)
    @objc(home:didEncounterError:forAccessory:) optional func home(_ home: HMHome, didEncounterError error: Error, for accessory: HMAccessory)
    @objc(home:didUpdateHomeHubState:) optional func home(_ home: HMHome, didUpdate homeHubState: HMHomeHubState)
    @objc(homeDidUpdateSupportedFeatures:) optional func homeDidUpdateSupportedFeatures(_ home: HMHome)
}

enum _HMHome {
    /// the device's account, who owns the simulated homes
    static let ownerName = "Anna Haro"
}

@objc(HMHome)
open class HMHome: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }

    @objc public weak var delegate: (any HMHomeDelegate)?

    var _rec: _HMHomeRec? { _HMStore.shared.home(_id) }
    private func _modify(_ body: (inout _HMHomeRec) -> Void) {
        _HMStore.shared.modify { d in if let i = d.homes.firstIndex(where: { $0.id == _id }) { body(&d.homes[i]) } }
    }
    /// the home's error for an operation: no access, or the home was removed
    private var _blocked: Error? { _HMAccess.denied ?? (_rec == nil ? _hmErr(.objectNotAssociatedToAnyHome) : nil) }

    @objc public var name: String { _rec?.name ?? "" }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }
    @objc(isPrimary) public var isPrimary: Bool { (_HMStore.shared.data.primary ?? _HMStore.shared.data.homes.first?.id) == _id }
    @objc public var homeHubState: HMHomeHubState { _rec?.hub == true ? .connected : .notAvailable }
    @objc public var supportsAddingNetworkRouter: Bool { true }
    @objc(isProvisionalHome) public var isProvisionalHome: Bool { _rec?.provisional != nil }
    /// the home's Matter fabric: isim has no Matter controller (issue #416)
    @objc public var matterControllerID: String { _id }
    @objc public var matterControllerXPCConnectBlock: () -> NSXPCConnection {
        { NSXPCConnection(serviceName: "com.apple.homed.matter") }
    }
    @objc public var matterStartupParametersXPCConnectBlock: () -> NSXPCConnection {
        { NSXPCConnection(serviceName: "com.apple.homed.matter") }
    }

    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        if let e = _hmNameError(name, taken: _HMStore.shared.data.homes.filter { $0.id != _id }.map(\.name), code: .homeWithSimilarNameExists) {
            _hmReply { completion(e) }; return
        }
        _modify { $0.name = name }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    // MARK: users
    @objc public var currentUser: HMUser {
        _HMObjects.shared.user(_rec?.users.first?.id ?? "\(_id)-owner")
    }
    @available(iOS, introduced: 8.0, deprecated: 9.0)
    @objc public var users: [HMUser] { (_rec?.users ?? []).map { _HMObjects.shared.user($0.id) } }

    @available(iOS, introduced: 8.0, deprecated: 9.0)
    @objc(addUserWithCompletionHandler:)
    open func addUser(completionHandler completion: @escaping (HMUser?, Error?) -> Void) {
        manageUsers { completion(nil, $0) }
    }
    @available(iOS, introduced: 8.0, deprecated: 9.0)
    @objc(removeUser:completionHandler:)
    open func removeUser(_ user: HMUser, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard user._id != _rec?.users.first?.id else { _hmReply { completion(_hmErr(.insufficientPrivileges)) }; return }
        _modify { $0.users.removeAll { $0.id == user._id } }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    /// iOS's Home Settings sheet for the home's people (isim's: the list, with Done)
    @objc(manageUsersWithCompletionHandler:)
    open func manageUsers(completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        let names = (_rec?.users ?? []).map { $0.name + ($0.admin == true ? " (Owner)" : "") }
        _Privacy.onMain {
            _Privacy.alert("People", names.joined(separator: "\n"), [("Done", .default)]) { _ in completion(nil) }
        }
    }

    @objc(homeAccessControlForUser:)
    open func homeAccessControl(for user: HMUser) -> HMHomeAccessControl {
        HMHomeAccessControl(_admin: _rec?.users.first(where: { $0.id == user._id })?.admin == true || user === currentUser)
    }

    // MARK: accessories
    @objc public var accessories: [HMAccessory] {
        guard _HMAccess.denied == nil else { return [] }
        return (_rec?.accessories ?? []).map { _HMObjects.shared.accessory($0.id) }
    }

    @objc(addAccessory:completionHandler:)
    open func addAccessory(_ accessory: HMAccessory, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        if _HMStore.shared.homeOfAccessory(accessory._id) == _id { _hmReply { completion(_hmErr(.alreadyExists)) }; return }
        if _HMStore.shared.homeOfAccessory(accessory._id) != nil { _hmReply { completion(_hmErr(.objectAssociatedToAnotherHome)) }; return }
        guard _HMHomeRec.adopt(accessory._id, into: _id) else { _hmReply { completion(_hmErr(.notFound)) }; return }
        NSLog("isim HomeKit: added accessory %@ to %@", accessory.name, name)
        _hmReply { completion(nil) }
    }

    @objc(removeAccessory:completionHandler:)
    open func removeAccessory(_ accessory: HMAccessory, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard let rec = _rec?.accessories.first(where: { $0.id == accessory._id }) else { _hmReply { completion(_hmErr(.notFound)) }; return }
        _modify { h in
            h.accessories.removeAll { $0.id == rec.id }
            let ids = Set(rec.services.flatMap { [$0.id] + $0.characteristics.map(\.id) })
            for i in h.serviceGroups.indices { h.serviceGroups[i].services.removeAll { ids.contains($0) } }
            for i in h.actionSets.indices { h.actionSets[i].actions.removeAll { ids.contains($0.characteristic) } }
        }
        var back = rec                          // a removed accessory is reset: it can be found and added again
        back.room = nil
        _HMStore.shared.modify { $0.available.append(back) }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @objc(assignAccessory:toRoom:completionHandler:)
    open func assignAccessory(_ accessory: HMAccessory, to room: HMRoom, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard _rec?.accessories.contains(where: { $0.id == accessory._id }) == true else { _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return }
        let roomID: String? = room._id == "\(_id)-entire" ? nil : room._id
        if let r = roomID, _rec?.rooms.contains(where: { $0.id == r }) != true { _hmReply { completion(_hmErr(.notFound)) }; return }
        _modify { h in if let i = h.accessories.firstIndex(where: { $0.id == accessory._id }) { h.accessories[i].room = roomID } }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @objc(servicesWithTypes:)
    open func servicesWithTypes(_ serviceTypes: [String]) -> [HMService]? {
        let list = (_rec?.accessories ?? []).flatMap { $0.services }.filter { serviceTypes.contains($0.type) }
        return list.isEmpty ? nil : list.map { _HMObjects.shared.service($0.id) }
    }

    @objc(unblockAccessory:completionHandler:)
    open func unblockAccessory(_ accessory: HMAccessory, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        _modify { h in if let i = h.accessories.firstIndex(where: { $0.id == accessory._id }) { h.accessories[i].blocked = nil } }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @available(iOS, introduced: 10.0, deprecated: 15.4, message: "Use HMAccessorySetupManager.performAccessorySetup(using:completionHandler:)")
    @objc(addAndSetupAccessoriesWithCompletionHandler:)
    open func addAndSetupAccessories(completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        _HMSetupUI.run(home: _id, payload: nil, suggestedName: nil, room: nil) { ids, e in completion(e) }
    }

    @available(iOS, introduced: 11.3, deprecated: 15.4, message: "Use HMAccessorySetupManager.performAccessorySetup(using:completionHandler:)")
    @objc(addAndSetupAccessoriesWithPayload:completionHandler:)
    open func addAndSetupAccessories(with payload: HMAccessorySetupPayload, completionHandler completion: @escaping ([HMAccessory]?, Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(nil, e) }; return }
        _HMSetupUI.run(home: _id, payload: payload, suggestedName: nil, room: nil) { ids, e in
            completion(ids.map { $0.map { _HMObjects.shared.accessory($0) } }, e)
        }
    }

    // MARK: rooms and zones
    @objc public var rooms: [HMRoom] { (_rec?.rooms ?? []).map { _HMObjects.shared.room($0.id) } }

    @objc open func roomForEntireHome() -> HMRoom {
        _HMObjects.shared.object("\(_id)-entire") { HMRoom(_id: "\(_id)-entire") }
    }

    @objc(addRoomWithName:completionHandler:)
    open func addRoom(withName roomName: String, completionHandler completion: @escaping (HMRoom?, Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(nil, e) }; return }
        if let e = _hmNameError(roomName, taken: (_rec?.rooms ?? []).map(\.name)) { _hmReply { completion(nil, e) }; return }
        let r = _HMRoomRec(id: _HMStore.newID(), name: roomName)
        _modify { $0.rooms.append(r) }
        _HMStore.shared.save()
        _hmReply { completion(_HMObjects.shared.room(r.id), nil) }
    }

    @objc(removeRoom:completionHandler:)
    open func removeRoom(_ room: HMRoom, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        if room._id == "\(_id)-entire" { _hmReply { completion(_hmErr(.roomForHomeCannotBeUpdated)) }; return }
        guard _rec?.rooms.contains(where: { $0.id == room._id }) == true else { _hmReply { completion(_hmErr(.notFound)) }; return }
        _modify { h in
            h.rooms.removeAll { $0.id == room._id }
            for i in h.zones.indices { h.zones[i].rooms.removeAll { $0 == room._id } }
            for i in h.accessories.indices where h.accessories[i].room == room._id { h.accessories[i].room = nil }
        }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @objc public var zones: [HMZone] { (_rec?.zones ?? []).map { _HMObjects.shared.zone($0.id) } }

    @objc(addZoneWithName:completionHandler:)
    open func addZone(withName zoneName: String, completionHandler completion: @escaping (HMZone?, Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(nil, e) }; return }
        if let e = _hmNameError(zoneName, taken: (_rec?.zones ?? []).map(\.name)) { _hmReply { completion(nil, e) }; return }
        let z = _HMZoneRec(id: _HMStore.newID(), name: zoneName, rooms: [])
        _modify { $0.zones.append(z) }
        _HMStore.shared.save()
        _hmReply { completion(_HMObjects.shared.zone(z.id), nil) }
    }

    @objc(removeZone:completionHandler:)
    open func removeZone(_ zone: HMZone, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard _rec?.zones.contains(where: { $0.id == zone._id }) == true else { _hmReply { completion(_hmErr(.notFound)) }; return }
        _modify { $0.zones.removeAll { $0.id == zone._id } }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    // MARK: service groups
    @objc public var serviceGroups: [HMServiceGroup] { (_rec?.serviceGroups ?? []).map { _HMObjects.shared.group($0.id) } }

    @objc(addServiceGroupWithName:completionHandler:)
    open func addServiceGroup(withName serviceGroupName: String, completionHandler completion: @escaping (HMServiceGroup?, Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(nil, e) }; return }
        if let e = _hmNameError(serviceGroupName, taken: (_rec?.serviceGroups ?? []).map(\.name)) { _hmReply { completion(nil, e) }; return }
        let g = _HMGroupRec(id: _HMStore.newID(), name: serviceGroupName, services: [])
        _modify { $0.serviceGroups.append(g) }
        _HMStore.shared.save()
        _hmReply { completion(_HMObjects.shared.group(g.id), nil) }
    }

    @objc(removeServiceGroup:completionHandler:)
    open func removeServiceGroup(_ group: HMServiceGroup, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard _rec?.serviceGroups.contains(where: { $0.id == group._id }) == true else { _hmReply { completion(_hmErr(.notFound)) }; return }
        _modify { $0.serviceGroups.removeAll { $0.id == group._id } }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    // MARK: action sets and triggers
    @objc public var actionSets: [HMActionSet] { (_rec?.actionSets ?? []).map { _HMObjects.shared.actionSet($0.id) } }

    @objc(addActionSetWithName:completionHandler:)
    open func addActionSet(withName actionSetName: String, completionHandler completion: @escaping (HMActionSet?, Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(nil, e) }; return }
        if let e = _hmNameError(actionSetName, taken: (_rec?.actionSets ?? []).map(\.name)) { _hmReply { completion(nil, e) }; return }
        let s = _HMActionSetRec(id: _HMStore.newID(), name: actionSetName, type: "HMActionSetTypeUserDefined", actions: [])
        _modify { $0.actionSets.append(s) }
        _HMStore.shared.save()
        _hmReply { completion(_HMObjects.shared.actionSet(s.id), nil) }
    }

    @objc(removeActionSet:completionHandler:)
    open func removeActionSet(_ actionSet: HMActionSet, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard let s = _rec?.actionSets.first(where: { $0.id == actionSet._id }) else { _hmReply { completion(_hmErr(.notFound)) }; return }
        if s.type != "HMActionSetTypeUserDefined" && s.type != "HMActionSetTypeTriggerOwned" {
            _hmReply { completion(_hmErr(.cannotRemoveBuiltinActionSet)) }; return
        }
        _modify { h in
            h.actionSets.removeAll { $0.id == s.id }
            for i in h.triggers.indices { h.triggers[i].actionSets.removeAll { $0 == s.id } }
        }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @objc(executeActionSet:completionHandler:)
    open func executeActionSet(_ actionSet: HMActionSet, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard _rec?.actionSets.contains(where: { $0.id == actionSet._id }) == true else { _hmReply { completion(_hmErr(.notFound)) }; return }
        let e = _HMAutomation.execute(actionSet._id, in: _id)
        _hmReply { completion(e) }
    }

    @objc(builtinActionSetOfType:)
    open func builtinActionSet(ofType actionSetType: String) -> HMActionSet? {
        guard actionSetType != "HMActionSetTypeUserDefined", let s = _rec?.actionSets.first(where: { $0.type == actionSetType }) else { return nil }
        return _HMObjects.shared.actionSet(s.id)
    }

    @objc public var triggers: [HMTrigger] { (_rec?.triggers ?? []).map { _HMAutomation.trigger($0) } }

    @objc(addTrigger:completionHandler:)
    open func addTrigger(_ trigger: HMTrigger, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        if trigger._home != nil { _hmReply { completion(_hmErr(trigger._home == self._id ? .alreadyExists : .objectAssociatedToAnotherHome)) }; return }
        if let e = _hmNameError(trigger.name, taken: (_rec?.triggers ?? []).map(\.name)) { _hmReply { completion(e) }; return }
        if let t = trigger as? HMTimerTrigger, t.fireDate < Date(), t.recurrence == nil { _hmReply { completion(_hmErr(.fireDateInPast)) }; return }
        var rec = trigger._record
        rec.enabled = false                     // a new trigger is disabled until enabled
        trigger._home = _id
        _modify { $0.triggers.append(rec) }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @objc(removeTrigger:completionHandler:)
    open func removeTrigger(_ trigger: HMTrigger, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _blocked { _hmReply { completion(e) }; return }
        guard _rec?.triggers.contains(where: { $0.id == trigger._id }) == true else { _hmReply { completion(_hmErr(.notFound)) }; return }
        _modify { $0.triggers.removeAll { $0.id == trigger._id } }
        trigger._home = nil
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    // MARK: provisional homes (iOS 26)
    public struct ProvisionalHomeConnectionDetails: Sendable, Hashable {
        public var transferToken: Data
        public init(transferToken: Data) { self.transferToken = transferToken }
    }
    public enum ProvisionalHomeTransferError: Error, Sendable, Hashable {
        case authenticationFailed, connectionFailed, serverError, targetHomeRejected
    }
    public struct ProvisionalHomeTransferResult: Sendable, Hashable {
        public struct TransferredAccessory: Sendable, Hashable {
            public var uuid: UUID
            public var name: String
            public init(uuid: UUID, name: String) { self.uuid = uuid; self.name = name }
        }
        public struct FailedAccessory: Sendable, Hashable {
            public enum Reason: Sendable, Hashable { case unknown, unsupportedAccessoryType }
            public var uuid: UUID
            public var name: String
            public var reason: Reason
            public var localizedFailureDescription: String?
            public init(uuid: UUID, name: String, reason: Reason, localizedFailureDescription: String?) {
                self.uuid = uuid; self.name = name; self.reason = reason; self.localizedFailureDescription = localizedFailureDescription
            }
        }
        public var transferredAccessories: [TransferredAccessory]
        public var failedAccessories: [FailedAccessory]
        public init(transferredAccessories: [TransferredAccessory], failedAccessories: [FailedAccessory]) {
            self.transferredAccessories = transferredAccessories; self.failedAccessories = failedAccessories
        }
    }

    public func isProvisionalHome(forPairingIdentifier pairingIdentifier: String) async throws -> Bool {
        if let e = _blocked { throw e }
        return _rec?.provisional == pairingIdentifier
    }

    /// moves a provisional home's accessories into another home; the token is the provisional home's identifier
    public func transferProvisionalHome(connectionDetails: ProvisionalHomeConnectionDetails, targetHomeUniqueIdentifier: UUID)
        async throws(ProvisionalHomeTransferError) -> ProvisionalHomeTransferResult {
        guard _HMAccess.denied == nil else { throw .authenticationFailed }
        guard let source = String(data: connectionDetails.transferToken, encoding: .utf8).flatMap({ _HMStore.shared.home($0) }),
              source.provisional != nil else { throw .connectionFailed }
        let target = targetHomeUniqueIdentifier.uuidString
        guard _HMStore.shared.home(target)?.provisional == nil, _HMStore.shared.home(target) != nil else { throw .targetHomeRejected }
        _HMStore.shared.modify { d in
            guard let s = d.homes.firstIndex(where: { $0.id == source.id }), let t = d.homes.firstIndex(where: { $0.id == target }) else { return }
            d.homes[t].accessories += d.homes[s].accessories.map { var a = $0; a.room = nil; return a }
            d.homes.remove(at: s)
        }
        _HMStore.shared.save()
        return ProvisionalHomeTransferResult(transferredAccessories: source.accessories.map {
            .init(uuid: UUID(uuidString: $0.id) ?? UUID(), name: $0.name)
        }, failedAccessories: [])
    }
}

extension _HMHomeRec {
    /// moves an accessory found nearby into a home (in the room the accessory says, if the home has it)
    static func adopt(_ accessoryID: String, into home: String, name: String? = nil, room: String? = nil) -> Bool {
        var ok = false
        _HMStore.shared.modify { d in
            guard let a = d.available.firstIndex(where: { $0.id == accessoryID }), let h = d.homes.firstIndex(where: { $0.id == home }) else { return }
            var acc = d.available.remove(at: a)
            if let name { acc.name = name }
            acc.room = room.flatMap { r in d.homes[h].rooms.contains { $0.id == r } ? r : nil }
            d.homes[h].accessories.append(acc)
            ok = true
        }
        if ok { _HMStore.shared.save() }
        return ok
    }
}

// MARK: - rooms, zones, service groups, users

@objc(HMRoom)
open class HMRoom: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }

    private var _home: (Int, _HMHomeRec)? {
        for (i, h) in _HMStore.shared.data.homes.enumerated() where h.rooms.contains(where: { $0.id == _id }) || _id == "\(h.id)-entire" { return (i, h) }
        return nil
    }
    @objc public var name: String {
        guard let (_, h) = _home else { return "" }
        if _id == "\(h.id)-entire" { return "Default Room" }
        return h.rooms.first { $0.id == _id }?.name ?? ""
    }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: String(_id.prefix(36))) ?? UUID() }
    @objc public var accessories: [HMAccessory] {
        guard let (_, h) = _home else { return [] }
        let mine: String? = _id == "\(h.id)-entire" ? nil : _id
        return h.accessories.filter { $0.room == mine }.map { _HMObjects.shared.accessory($0.id) }
    }
    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard let (i, h) = _home else { _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return }
        if _id == "\(h.id)-entire" { _hmReply { completion(_hmErr(.roomForHomeCannotBeUpdated)) }; return }
        if let e = _hmNameError(name, taken: h.rooms.filter { $0.id != _id }.map(\.name)) { _hmReply { completion(e) }; return }
        _HMStore.shared.modify { d in if let r = d.homes[i].rooms.firstIndex(where: { $0.id == _id }) { d.homes[i].rooms[r].name = name } }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }
}

@objc(HMZone)
open class HMZone: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }

    private var _where: (Int, Int)? {
        for (i, h) in _HMStore.shared.data.homes.enumerated() { if let z = h.zones.firstIndex(where: { $0.id == _id }) { return (i, z) } }
        return nil
    }
    private var _rec: _HMZoneRec? { _where.map { _HMStore.shared.data.homes[$0.0].zones[$0.1] } }
    @objc public var name: String { _rec?.name ?? "" }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }
    @objc public var rooms: [HMRoom] { (_rec?.rooms ?? []).map { _HMObjects.shared.room($0) } }

    private func _change(_ completion: @escaping (Error?) -> Void, _ check: (_HMHomeRec, _HMZoneRec) -> NSError?, _ body: (inout _HMZoneRec) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard let (h, z) = _where else { _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return }
        let home = _HMStore.shared.data.homes[h]
        if let e = check(home, home.zones[z]) { _hmReply { completion(e) }; return }
        _HMStore.shared.modify { body(&$0.homes[h].zones[z]) }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }
    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { h, _ in _hmNameError(name, taken: h.zones.filter { $0.id != self._id }.map(\.name)) }) { $0.name = name }
    }
    @objc(addRoom:completionHandler:)
    open func addRoom(_ room: HMRoom, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { h, z in
            if room._id.hasSuffix("-entire") { return _hmErr(.roomForHomeCannotBeInZone) }
            if !h.rooms.contains(where: { $0.id == room._id }) { return _hmErr(.objectAssociatedToAnotherHome) }
            return z.rooms.contains(room._id) ? _hmErr(.alreadyExists) : nil
        }) { $0.rooms.append(room._id) }
    }
    @objc(removeRoom:completionHandler:)
    open func removeRoom(_ room: HMRoom, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { _, z in z.rooms.contains(room._id) ? nil : _hmErr(.notFound) }) { $0.rooms.removeAll { $0 == room._id } }
    }
}

@objc(HMServiceGroup)
open class HMServiceGroup: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }

    private var _where: (Int, Int)? {
        for (i, h) in _HMStore.shared.data.homes.enumerated() { if let g = h.serviceGroups.firstIndex(where: { $0.id == _id }) { return (i, g) } }
        return nil
    }
    private var _rec: _HMGroupRec? { _where.map { _HMStore.shared.data.homes[$0.0].serviceGroups[$0.1] } }
    @objc public var name: String { _rec?.name ?? "" }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }
    @objc public var services: [HMService] { (_rec?.services ?? []).map { _HMObjects.shared.service($0) } }

    private func _change(_ completion: @escaping (Error?) -> Void, _ check: (_HMHomeRec, _HMGroupRec) -> NSError?, _ body: (inout _HMGroupRec) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard let (h, g) = _where else { _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return }
        let home = _HMStore.shared.data.homes[h]
        if let e = check(home, home.serviceGroups[g]) { _hmReply { completion(e) }; return }
        _HMStore.shared.modify { body(&$0.homes[h].serviceGroups[g]) }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }
    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { h, _ in _hmNameError(name, taken: h.serviceGroups.filter { $0.id != self._id }.map(\.name)) }) { $0.name = name }
    }
    @objc(addService:completionHandler:)
    open func addService(_ service: HMService, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { h, g in
            if !h.accessories.contains(where: { $0.services.contains { $0.id == service._id } }) { return _hmErr(.objectAssociatedToAnotherHome) }
            return g.services.contains(service._id) ? _hmErr(.alreadyExists) : nil
        }) { $0.services.append(service._id) }
    }
    @objc(removeService:completionHandler:)
    open func removeService(_ service: HMService, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { _, g in g.services.contains(service._id) ? nil : _hmErr(.notFound) }) { $0.services.removeAll { $0 == service._id } }
    }
}

@objc(HMUser)
open class HMUser: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }
    @objc public var name: String {
        for h in _HMStore.shared.data.homes { if let u = h.users.first(where: { $0.id == _id }) { return u.name } }
        return _HMHome.ownerName
    }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: String(_id.prefix(36))) ?? UUID() }
}

@objc(HMAccessControl)
open class HMAccessControl: NSObject {}

@objc(HMHomeAccessControl)
open class HMHomeAccessControl: HMAccessControl {
    let _admin: Bool
    init(_admin: Bool) { self._admin = _admin; super.init() }
    @objc(isAdministrator) public var isAdministrator: Bool { _admin }
}
