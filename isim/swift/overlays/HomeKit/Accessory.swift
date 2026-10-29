// isim HomeKit: accessories, their services and characteristics (reads, writes and notifications against the simulated
// accessories), finding new accessories and adding them (isim's "Add Accessory" sheet).
import Foundation
import UIKit

// MARK: - HMAccessory

@objc(HMAccessoryDelegate)
public protocol HMAccessoryDelegate: NSObjectProtocol {
    @objc(accessoryDidUpdateName:) optional func accessoryDidUpdateName(_ accessory: HMAccessory)
    @objc(accessory:didUpdateNameForService:) optional func accessory(_ accessory: HMAccessory, didUpdateNameFor service: HMService)
    @objc(accessory:didUpdateAssociatedServiceTypeForService:) optional func accessory(_ accessory: HMAccessory, didUpdateAssociatedServiceTypeFor service: HMService)
    @objc(accessoryDidUpdateServices:) optional func accessoryDidUpdateServices(_ accessory: HMAccessory)
    @objc(accessory:didAddProfile:) optional func accessory(_ accessory: HMAccessory, didAdd profile: HMAccessoryProfile)
    @objc(accessory:didRemoveProfile:) optional func accessory(_ accessory: HMAccessory, didRemove profile: HMAccessoryProfile)
    @objc(accessoryDidUpdateReachability:) optional func accessoryDidUpdateReachability(_ accessory: HMAccessory)
    @objc(accessory:service:didUpdateValueForCharacteristic:) optional func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic)
    @objc(accessory:didUpdateFirmwareVersion:) optional func accessory(_ accessory: HMAccessory, didUpdateFirmwareVersion firmwareVersion: String)
}

@objc(HMAccessory)
open class HMAccessory: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }

    @objc public weak var delegate: (any HMAccessoryDelegate)?

    var _rec: _HMAccessoryRec? { _HMStore.shared.accessory(_id) }
    var _reachable: Bool { _rec?.reachable ?? true }

    @objc public var name: String { _rec?.name ?? "" }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }
    @available(iOS, introduced: 8.0, deprecated: 9.0)
    @objc public var identifier: UUID { uniqueIdentifier }
    @objc(isReachable) public var isReachable: Bool { _reachable }
    @objc(isBlocked) public var isBlocked: Bool { _rec?.blocked == true }
    @objc(isBridged) public var isBridged: Bool { _rec?.bridge != nil }
    @objc public var manufacturer: String? { _rec?.manufacturer }
    @objc public var model: String? { _rec?.model }
    @objc public var firmwareVersion: String? { _rec?.firmware }
    @objc public var supportsIdentify: Bool { _rec?.identify ?? true }
    @objc public var category: HMAccessoryCategory { HMAccessoryCategory(_type: _rec?.category ?? _HMTypes.category("Other")) }
    /// the Matter node of a Matter accessory: isim's simulated accessories use HAP
    public var matterNodeID: UInt64? { nil }
    @objc(matterNodeID) public var _objc_matterNodeID: NSNumber? { nil }
    public var hapInstanceID: UInt64? { _rec.map { UInt64(abs($0.id.hashValue) % 1000) + 1 } }
    public var isVendorAccessory: Bool { false }

    @objc public var room: HMRoom? {
        guard let rec = _rec, let home = _HMStore.shared.homeOfAccessory(_id) else { return nil }
        return rec.room.map { _HMObjects.shared.room($0) } ?? _HMObjects.shared.home(home).roomForEntireHome()
    }
    public var home: HMHome? { _HMStore.shared.homeOfAccessory(_id).map { _HMObjects.shared.home($0) } }

    @objc public var services: [HMService] { (_rec?.services ?? []).map { _HMObjects.shared.service($0.id) } }

    @objc public var profiles: [HMAccessoryProfile] {
        var list: [HMAccessoryProfile] = cameraProfiles ?? []
        if _rec?.networkProfile == true {
            list.append(_HMObjects.shared.object("\(_id)-network") { HMNetworkConfigurationProfile(_accessory: _id, _services: []) })
        }
        if let tv = _rec?.services.first(where: { $0.type == _HMTypes.service("Television") }) {
            list.append(_HMObjects.shared.object("\(_id)-mediaorder") { HMMediaSourceDisplayOrderProfile(_accessory: _id, _services: [tv.id]) })
        }
        return list
    }
    @objc public var cameraProfiles: [HMCameraProfile]? {
        let streams = (_rec?.services ?? []).filter { $0.type == _HMTypes.service("CameraRTPStreamManagement") }
        if streams.isEmpty { return nil }
        return streams.map { s in _HMObjects.shared.object("\(s.id)-camera") { HMCameraProfile(_accessory: _id, _services: [s.id]) } }
    }

    @available(iOS, introduced: 8.0, deprecated: 9.0)
    @objc public var identifiersForBridgedAccessories: [UUID]? { uniqueIdentifiersForBridgedAccessories }
    @objc public var uniqueIdentifiersForBridgedAccessories: [UUID]? {
        let list = bridgedAccessories
        return list.isEmpty ? nil : list.map(\.uniqueIdentifier)
    }
    public var bridgedAccessories: [HMAccessory] {
        guard let home = _HMStore.shared.homeOfAccessory(_id).flatMap({ _HMStore.shared.home($0) }) else { return [] }
        return home.accessories.filter { $0.bridge == _id }.map { _HMObjects.shared.accessory($0.id) }
    }

    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard let home = _HMStore.shared.homeOfAccessory(_id).flatMap({ _HMStore.shared.home($0) }) else {
            _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return
        }
        if let e = _hmNameError(name, taken: home.accessories.filter { $0.id != _id }.map(\.name)) { _hmReply { completion(e) }; return }
        _HMStore.shared.modifyAccessory(_id) { $0.name = name }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    /// the accessory identifies itself (a light blinks): logged
    @objc(identifyWithCompletionHandler:)
    open func identify(completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard _reachable else { _hmReply { completion(_hmErr(.accessoryNotReachable)) }; return }
        guard supportsIdentify else { _hmReply { completion(_hmErr(.operationNotSupported)) }; return }
        NSLog("isim HomeKit: %@ identifies itself", name)
        _hmReply { completion(nil) }
    }

    public struct ManufacturerFeature: Sendable, Hashable {
        public enum Kind: Sendable, Hashable { case helpGuide, interactiveSetting, primitiveSetting, productManual, troubleshooting }
        public let name: String
        public let id: String?
        public let kind: Kind
        public init(name: String, id: String?, kind: Kind) { self.name = name; self.id = id; self.kind = kind }
    }
    /// what the manufacturer's app extension offers: isim's simulated accessories have no manufacturer extensions
    public var manufacturerFeatures: [ManufacturerFeature] { [] }
    public func showManufacturerExtension(for kind: ManufacturerFeature.Kind, featureID: String?) async throws {
        NSLog("isim HomeKit: %@ has no manufacturer extension", name)
        throw HMError(.operationNotSupported)
    }
}

@objc(HMAccessoryCategory)
open class HMAccessoryCategory: NSObject {
    let _type: String
    init(_type: String) { self._type = _type; super.init() }
    @objc public var categoryType: String { _type }
    @objc public var localizedDescription: String { _HMTypes.categories[_type]?.description ?? "Other" }
    open override func isEqual(_ object: Any?) -> Bool { (object as? HMAccessoryCategory)?._type == _type }
    open override var hash: Int { _type.hashValue }
}

@objc(HMAccessoryProfile)
open class HMAccessoryProfile: NSObject {
    let _accessory: String
    let _services: [String]
    init(_accessory: String, _services: [String]) { self._accessory = _accessory; self._services = _services; super.init() }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: String((_services.first ?? _accessory).prefix(36))) ?? UUID() }
    @objc public var services: [HMService] { _services.map { _HMObjects.shared.service($0) } }
    @objc public var accessory: HMAccessory? { _HMObjects.shared.accessory(_accessory) }
}

// MARK: - HMService

@objc(HMService)
open class HMService: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }

    var _rec: _HMServiceRec? { _HMStore.shared.service(_id) }

    @objc public var accessory: HMAccessory? { _HMStore.shared.servicePath(_id).map { _HMObjects.shared.accessory($0.0) } }
    @objc public var serviceType: String { _rec?.type ?? "" }
    @objc public var localizedDescription: String { _HMTypes.services[serviceType]?.description ?? "Custom" }
    @objc public var name: String { _rec?.name ?? "" }
    @objc public var associatedServiceType: String? { _rec?.associated }
    @objc(isPrimaryService) public var isPrimaryService: Bool { _rec?.primary == true }
    @objc(isUserInteractive) public var isUserInteractive: Bool {
        _rec?.interactive ?? (serviceType != _HMTypes.service("AccessoryInformation") && serviceType != _HMTypes.service("CameraRTPStreamManagement"))
    }
    @objc public var characteristics: [HMCharacteristic] { (_rec?.characteristics ?? []).map { _HMObjects.shared.characteristic($0.id) } }
    @objc public var linkedServices: [HMService]? { _rec?.linked.map { $0.map { _HMObjects.shared.service($0) } } }
    public var matterEndpointID: UInt16? { nil }
    @objc(matterEndpointID) public var _objc_matterEndpointID: NSNumber? { nil }

    private func _change(_ completion: @escaping (Error?) -> Void, _ body: @escaping (inout _HMServiceRec) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard let (a, s) = _HMStore.shared.servicePath(_id), _HMStore.shared.homeOfAccessory(a) != nil else {
            _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return
        }
        _HMStore.shared.modifyAccessory(a) { body(&$0.services[s]) }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }
    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _hmNameError(name, taken: []) { _hmReply { completion(e) }; return }
        _change(completion) { $0.name = name }
    }
    /// what a switch or an outlet controls (HMServiceTypeLightbulb, HMServiceTypeFan): only those can be associated
    @objc(updateAssociatedServiceType:completionHandler:)
    open func updateAssociatedServiceType(_ serviceType: String?, completionHandler completion: @escaping (Error?) -> Void) {
        let ok = [_HMTypes.service("Switch"), _HMTypes.service("Outlet")].contains(self.serviceType)
        guard ok, serviceType == nil || [_HMTypes.service("Lightbulb"), _HMTypes.service("Fan")].contains(serviceType!) else {
            _hmReply { completion(_hmErr(.invalidAssociatedServiceType)) }; return
        }
        _change(completion) { $0.associated = serviceType }
    }
}

// MARK: - HMCharacteristic

@objc(HMCharacteristicMetadata)
open class HMCharacteristicMetadata: NSObject {
    var _rec: _HMCharRec?
    @objc public override init() { super.init() }
    init(_rec: _HMCharRec) { self._rec = _rec; super.init() }
    @objc public var minimumValue: NSNumber? { _rec?.min.map { NSNumber(value: $0) } }
    @objc public var maximumValue: NSNumber? { _rec?.max.map { NSNumber(value: $0) } }
    @objc public var stepValue: NSNumber? { _rec?.step.map { NSNumber(value: $0) } }
    @objc public var maxLength: NSNumber? { _rec?.maxLength.map { NSNumber(value: $0) } ?? (_rec?.format == "string" ? 64 : nil) }
    @objc public var format: String? { _rec?.format }
    @objc public var units: String? { _rec?.units }
    @objc public var manufacturerDescription: String? { _rec?.manufacturerDescription }
    @objc public var validValues: [NSNumber]? { _rec?.validValues.map { $0.map { NSNumber(value: $0) } } }
}

@objc(HMCharacteristic)
open class HMCharacteristic: NSObject {
    let _id: String
    var _notifications = false
    init(_id: String) { self._id = _id; super.init() }

    var _rec: _HMCharRec? { _HMStore.shared.characteristic(_id) }
    private var _accessory: _HMAccessoryRec? { _HMStore.shared.characteristicPath(_id).flatMap { _HMStore.shared.accessory($0.0) } }

    @objc public var characteristicType: String { _rec?.type ?? "" }
    @objc public var localizedDescription: String { _HMTypes.characteristics[characteristicType]?.description ?? "Custom" }
    @objc public var service: HMService? { _HMStore.shared.characteristicPath(_id).map { _HMObjects.shared.service($0.1) } }
    @objc public var properties: [String] { _rec?.properties ?? [] }
    @objc public var metadata: HMCharacteristicMetadata? { _rec.map { HMCharacteristicMetadata(_rec: $0) } }
    @objc public var value: Any? {
        guard let r = _rec, r.properties.contains(_HMTypes.propertyReadable) else { return nil }
        return r.value?.object
    }
    @objc(isNotificationEnabled) public var isNotificationEnabled: Bool { _notifications }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }

    /// the error a read, write or notification change gets before it reaches the accessory
    private func _check() -> NSError? {
        if let e = _HMAccess.denied { return e as NSError }
        guard let acc = _accessory else { return _hmErr(.notFound) }
        if _HMStore.shared.homeOfAccessory(acc.id) == nil { return _hmErr(.objectNotAssociatedToAnyHome) }
        if acc.blocked == true { return _hmErr(.accessoryIsBlocked) }
        if !(acc.reachable ?? true) { return _hmErr(.communicationFailure, "\(acc.name) is not reachable.") }
        return nil
    }

    @objc(readValueWithCompletionHandler:)
    open func readValue(completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _check() { _hmReply { completion(e) }; return }
        guard properties.contains(_HMTypes.propertyReadable) else { _hmReply { completion(_hmErr(.writeOnlyCharacteristic)) }; return }
        _hmReply { completion(nil) }
    }

    @objc(writeValue:completionHandler:)
    open func writeValue(_ value: Any?, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _check() { _hmReply { completion(e) }; return }
        guard let r = _rec else { _hmReply { completion(_hmErr(.notFound)) }; return }
        if let e = _HMCharacteristics.validate(r, value) { _hmReply { completion(e) }; return }
        let v = _HMValue.from(value, format: r.format)!
        NSLog("isim HomeKit: %@ %@ = %@", _accessory?.name ?? "", localizedDescription, v.text)
        _HMStore.shared.setValue(_id, v, notify: false)
        _hmReply { completion(nil) }
    }

    @objc(enableNotification:completionHandler:)
    open func enableNotification(_ enable: Bool, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _check() { _hmReply { completion(e) }; return }
        guard properties.contains(_HMTypes.propertyEvents) else { _hmReply { completion(_hmErr(.notificationNotSupported)) }; return }
        _notifications = enable
        _hmReply { completion(nil) }
    }

    @objc(updateAuthorizationData:completionHandler:)
    open func updateAuthorizationData(_ data: Data?, completionHandler completion: @escaping (Error?) -> Void) {
        if let e = _check() { _hmReply { completion(e) }; return }
        _hmReply { completion(nil) }
    }
}

enum _HMCharacteristics {
    /// HomeKit's checks of a written value against the characteristic's metadata
    static func validate(_ r: _HMCharRec, _ value: Any?) -> NSError? {
        guard r.properties.contains(_HMTypes.propertyWritable) else { return _hmErr(.readOnlyCharacteristic) }
        guard let v = _HMValue.from(value, format: r.format) else { return _hmErr(.invalidValueType) }
        if let n = v.number {
            if let min = r.min, n < min - 1e-9 { return _hmErr(.valueLowerThanMinimum) }
            if let max = r.max, n > max + 1e-9 { return _hmErr(.valueHigherThanMaximum) }
            if let valid = r.validValues, !valid.contains(n) { return _hmErr(.invalidParameter) }
        }
        if case .string(let s) = v, s.count > (r.maxLength ?? 64) { return _hmErr(.stringLongerThanMaximum) }
        return nil
    }
}

// MARK: - finding and adding accessories

@objc(HMAccessoryBrowserDelegate)
public protocol HMAccessoryBrowserDelegate: NSObjectProtocol {
    @objc(accessoryBrowser:didFindNewAccessory:) optional func accessoryBrowser(_ browser: HMAccessoryBrowser, didFindNewAccessory accessory: HMAccessory)
    @objc(accessoryBrowser:didRemoveNewAccessory:) optional func accessoryBrowser(_ browser: HMAccessoryBrowser, didRemoveNewAccessory accessory: HMAccessory)
}

/// finds the simulated accessories nearby that no home has added (`isim home add-accessory`)
@objc(HMAccessoryBrowser)
open class HMAccessoryBrowser: NSObject {
    @objc public weak var delegate: (any HMAccessoryBrowserDelegate)?
    var _searching = false
    @objc public override init() { super.init(); _HMObjects.shared.addBrowser(self) }

    @objc public var discoveredAccessories: [HMAccessory] {
        guard _searching, _HMAccess.denied == nil else { return [] }
        return _HMStore.shared.data.available.map { _HMObjects.shared.accessory($0.id) }
    }
    @objc open func startSearchingForNewAccessories() {
        guard _HMAccess.denied == nil else { NSLog("isim HomeKit: the app may not search for accessories"); return }
        _searching = true
        _hmMain { _HMStore.shared.start() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self._searching else { return }
            for a in _HMStore.shared.data.available { self.delegate?.accessoryBrowser?(self, didFindNewAccessory: _HMObjects.shared.accessory(a.id)) }
        }
    }
    @objc open func stopSearchingForNewAccessories() { _searching = false }
}

@objc(HMAccessoryOwnershipToken)
open class HMAccessoryOwnershipToken: NSObject {
    let _data: Data
    @objc(initWithData:) public init?(data: Data) {
        guard !data.isEmpty else { return nil }
        _data = data
        super.init()
    }
}

/// an accessory's setup code (X-HM://... from its QR code or NFC tag)
@objc(HMAccessorySetupPayload)
open class HMAccessorySetupPayload: NSObject {
    let _url: URL
    let _token: HMAccessoryOwnershipToken?
    @objc(initWithURL:) public convenience init?(url setupPayloadURL: URL?) { self.init(url: setupPayloadURL, token: nil) }
    @objc(initWithURL:ownershipToken:) public convenience init?(url setupPayloadURL: URL, ownershipToken: HMAccessoryOwnershipToken?) {
        self.init(url: setupPayloadURL, token: ownershipToken)
    }
    public convenience init?(URL setupPayloadURL: URL?) { self.init(url: setupPayloadURL, token: nil) }
    public convenience init?(URL setupPayloadURL: URL, ownershipToken: HMAccessoryOwnershipToken?) { self.init(url: setupPayloadURL, token: ownershipToken) }
    init?(url: URL?, token: HMAccessoryOwnershipToken?) {
        guard let url, url.scheme?.uppercased() == "X-HM" else { return nil }
        _url = url
        _token = token
        super.init()
    }
}

@objc(HMAccessorySetupRequest)
open class HMAccessorySetupRequest: NSObject, NSCopying {
    @objc public var payload: HMAccessorySetupPayload?
    @objc public var homeUniqueIdentifier: UUID?
    @objc public var suggestedRoomUniqueIdentifier: UUID?
    @objc public var suggestedAccessoryName: String?
    @objc public override init() { super.init() }
    open func copy(with zone: NSZone? = nil) -> Any {
        let r = HMAccessorySetupRequest()
        r.payload = payload; r.homeUniqueIdentifier = homeUniqueIdentifier
        r.suggestedRoomUniqueIdentifier = suggestedRoomUniqueIdentifier; r.suggestedAccessoryName = suggestedAccessoryName
        return r
    }
}

@objc(HMAccessorySetupResult)
open class HMAccessorySetupResult: NSObject, NSCopying {
    @objc public let homeUniqueIdentifier: UUID
    @objc public let accessoryUniqueIdentifiers: [UUID]
    init(home: UUID, accessories: [UUID]) { homeUniqueIdentifier = home; accessoryUniqueIdentifiers = accessories; super.init() }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}

/// the system's accessory setup: isim's "Add Accessory" sheet over the accessories nearby
@objc(HMAccessorySetupManager)
open class HMAccessorySetupManager: NSObject {
    @objc public override init() { super.init() }
    @objc public class var isSupported: Bool { true }

    @objc(performAccessorySetupUsingRequest:completionHandler:)
    open func performAccessorySetup(using request: HMAccessorySetupRequest, completionHandler completion: @escaping (HMAccessorySetupResult?, Error?) -> Void) {
        _hmMain { _HMStore.shared.start() }
        guard _HMAccess.entitled else { _hmReply { completion(nil, HMError(.missingEntitlement)) }; return }
        let data = _HMStore.shared.data
        guard let home = request.homeUniqueIdentifier.map(\.uuidString) ?? data.primary ?? data.homes.first?.id, data.homes.contains(where: { $0.id == home }) else {
            _hmReply { completion(nil, _hmErr(.noCompatibleHomeHub, "There is no home to add the accessory to.")) }; return
        }
        _HMSetupUI.run(home: home, payload: request.payload, suggestedName: request.suggestedAccessoryName,
                       room: request.suggestedRoomUniqueIdentifier?.uuidString) { ids, e in
            completion(ids.map { HMAccessorySetupResult(home: UUID(uuidString: home)!, accessories: $0.compactMap { UUID(uuidString: $0) }) }, e)
        }
    }
}

/// a manufacturer's app asked to add its accessory (HMHomeManagerDelegate)
@objc(HMAddAccessoryRequest)
open class HMAddAccessoryRequest: NSObject {
    let _home: String
    let _accessory: _HMAccessoryRec
    init(home: String, accessory: _HMAccessoryRec) { _home = home; _accessory = accessory; super.init() }
    @objc public var home: HMHome { _HMObjects.shared.home(_home) }
    @objc public var accessoryCategory: HMAccessoryCategory { HMAccessoryCategory(_type: _accessory.category) }
    @objc public var accessoryName: String { _accessory.name }
    @objc public var requiresSetupPayloadURL: Bool { _accessory.setupURL != nil }
    @available(iOS, introduced: 13.0, deprecated: 13.0)
    @objc public var requiresOwnershipToken: Bool { true }
    @objc(payloadWithOwnershipToken:)
    open func makePayload(ownershipToken: HMAccessoryOwnershipToken) -> HMAccessorySetupPayload? {
        HMAccessorySetupPayload(url: URL(string: _accessory.setupURL ?? "X-HM://\(_accessory.id)"), token: ownershipToken)
    }
    @objc(payloadWithURL:ownershipToken:)
    open func makePayload(url setupPayloadURL: URL, ownershipToken: HMAccessoryOwnershipToken) -> HMAccessorySetupPayload? {
        HMAccessorySetupPayload(url: setupPayloadURL, token: ownershipToken)
    }
}

/// isim's rendition of iOS's "Add Accessory" sheet: the accessories nearby, or the one the setup code names
enum _HMSetupUI {
    static func run(home: String, payload: HMAccessorySetupPayload?, suggestedName: String?, room: String?,
                    _ done: @escaping ([String]?, Error?) -> Void) {
        _Privacy.onMain {
            _HMStore.shared.start()
            let nearby = _HMStore.shared.data.available
            if let url = payload?._url.absoluteString {
                guard let acc = nearby.first(where: { $0.setupURL?.caseInsensitiveCompare(url) == .orderedSame }) else {
                    _hmReply { done(nil, _hmErr(.accessoryDiscoveryFailed, "No accessory with this setup code was found.")) }; return
                }
                add(acc, home, suggestedName, room, done); return
            }
            if let s = _Privacy.env("ISIM_HOMEKIT_ADD_ACCESSORY") {
                if let acc = nearby.first(where: { $0.name.caseInsensitiveCompare(s) == .orderedSame || $0.id == s }) { add(acc, home, suggestedName, room, done) }
                else { _hmReply { done(nil, _hmErr(.operationCancelled)) } }
                return
            }
            let names = nearby.map { ($0.name, UIAlertAction.Style.default) }
            _Privacy.alert("Add Accessory", nearby.isEmpty ? "No accessories found nearby." : "Choose an accessory to add to your home.",
                           names + [("Cancel", .cancel)]) { i in
                if i >= 0, i < nearby.count { add(nearby[i], home, suggestedName, room, done) }
                else { NSLog("isim HomeKit: accessory setup cancelled"); done(nil, _hmErr(.operationCancelled)) }
            }
        }
    }
    private static func add(_ acc: _HMAccessoryRec, _ home: String, _ name: String?, _ room: String?, _ done: @escaping ([String]?, Error?) -> Void) {
        let ids = [acc.id] + _HMStore.shared.data.available.filter { $0.bridge == acc.id }.map(\.id)
        for id in ids { _ = _HMHomeRec.adopt(id, into: home, name: id == acc.id ? name : nil, room: room) }
        NSLog("isim HomeKit: set up %@", name ?? acc.name)
        _hmReply { done(ids, nil) }
    }
}

// MARK: - profiles

@objc(HMNetworkConfigurationProfileDelegate)
public protocol HMNetworkConfigurationProfileDelegate: NSObjectProtocol {
    @objc(profileDidUpdateNetworkAccessMode:) optional func profileDidUpdateNetworkAccessMode(_ profile: HMNetworkConfigurationProfile)
}

@objc(HMNetworkConfigurationProfile)
open class HMNetworkConfigurationProfile: HMAccessoryProfile {
    @objc public weak var delegate: (any HMNetworkConfigurationProfileDelegate)?
    @objc(isNetworkAccessRestricted) public var isNetworkAccessRestricted: Bool { false }
}

/// a TV's input sources in the order the Home app shows them (the Television service's InputSource services)
@objc(HMMediaSourceDisplayOrderProfile)
open class HMMediaSourceDisplayOrderProfile: HMAccessoryProfile {
    public protocol Delegate: AnyObject {
        func mediaSourceDisplayOrderProfileDidUpdateOrder(_ profile: HMMediaSourceDisplayOrderProfile)
    }
    public weak var delegate: (any Delegate)?
    private var _order: [Int]?
    public let canModifyOrder = true

    public var order: [Int] {
        if let _order { return _order }
        let inputs = (_HMStore.shared.accessory(_accessory)?.services ?? []).filter { $0.type == _HMTypes.service("InputSource") }
        return inputs.compactMap { s in s.characteristics.first { $0.type == _HMTypes.characteristic("Identifier") }?.value?.number.map { Int($0) } }
    }
    public func writeOrder(_ order: [Int]) async throws {
        guard Set(order) == Set(self.order) else { throw HMError(.invalidParameter) }
        _order = order
        _hmMain { self.delegate?.mediaSourceDisplayOrderProfileDidUpdateOrder(self) }
    }
}
