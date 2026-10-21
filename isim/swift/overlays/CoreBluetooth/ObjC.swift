// isim Core Bluetooth for Objective-C (sdk-src/Frameworks/CoreBluetooth): the classes carry Apple's Objective-C names
// and these members Apple's selectors; option sets and Swift enums cross as their raw values. The delegates are @objc
// protocols with Apple's selectors, so Objective-C delegates are used as they are. A manager made from Objective-C calls
// its delegate on the main queue, whatever queue it was given.
import Foundation

extension CBUUID {
    @objc(UUIDWithString:) class func _objc_withString(_ s: String) -> CBUUID { CBUUID(string: s) }
    @objc(UUIDWithNSUUID:) class func _objc_withNSUUID(_ u: UUID) -> CBUUID { CBUUID(nsuuid: u) }
    @objc(UUIDWithData:) class func _objc_withData(_ d: Data) -> CBUUID { CBUUID(data: d) }
    @objc(UUIDString) var _objc_uuidString: String { uuidString }
    @objc(data) var _objc_data: Data { data }
}
extension CBAttribute {
    @objc(UUID) var _objc_uuid: CBUUID { uuid }
}
extension CBService {
    @objc(peripheral) var _objc_peripheral: CBPeripheral? { peripheral }
    @objc(isPrimary) var _objc_isPrimary: Bool { isPrimary }
    @objc(characteristics) var _objc_characteristics: [CBCharacteristic]? { characteristics }
    @objc(includedServices) var _objc_includedServices: [CBService]? { includedServices }
}
extension CBMutableService {
    @objc(initWithType:primary:) convenience init(_objcType u: CBUUID, primary: Bool) { self.init(type: u, primary: primary) }
    @objc(setUUID:) func _objc_setUUID(_ u: CBUUID) { uuid = u }
    @objc(setIsPrimary:) func _objc_setPrimary(_ b: Bool) { isPrimary = b }
    @objc(setCharacteristics:) func _objc_setCharacteristics(_ c: [CBCharacteristic]?) { characteristics = c }
    @objc(setIncludedServices:) func _objc_setIncludedServices(_ s: [CBService]?) { includedServices = s }
}
extension CBCharacteristic {
    @objc(service) var _objc_service: CBService? { service }
    @objc(properties) var _objc_properties: UInt { properties.rawValue }
    @objc(value) var _objc_value: Data? { value }
    @objc(descriptors) var _objc_descriptors: [CBDescriptor]? { descriptors }
    @objc(isNotifying) var _objc_isNotifying: Bool { isNotifying }
}
extension CBMutableCharacteristic {
    @objc(initWithType:properties:value:permissions:)
    convenience init(_objcType u: CBUUID, properties: UInt, value: Data?, permissions: UInt) {
        self.init(type: u, properties: CBCharacteristicProperties(rawValue: properties), value: value, permissions: CBAttributePermissions(rawValue: permissions))
    }
    @objc(permissions) var _objc_permissions: UInt { permissions.rawValue }
    @objc(setPermissions:) func _objc_setPermissions(_ p: UInt) { permissions = CBAttributePermissions(rawValue: p) }
    @objc(subscribedCentrals) var _objc_subscribedCentrals: [CBCentral]? { subscribedCentrals }
    @objc(setUUID:) func _objc_setUUID(_ u: CBUUID) { uuid = u }
    @objc(setProperties:) func _objc_setProperties(_ p: UInt) { properties = CBCharacteristicProperties(rawValue: p) }
    @objc(setValue:) func _objc_setValue(_ v: Data?) { value = v }
    @objc(setDescriptors:) func _objc_setDescriptors(_ d: [CBDescriptor]?) { descriptors = d }
}
extension CBDescriptor {
    @objc(characteristic) var _objc_characteristic: CBCharacteristic? { characteristic }
    @objc(value) var _objc_value: Any? { value }
}
extension CBMutableDescriptor {
    @objc(initWithType:value:) convenience init(_objcType u: CBUUID, value: Any?) { self.init(type: u, value: value) }
}
extension CBPeer {
    @objc(identifier) var _objc_identifier: UUID { identifier }
}
extension CBCentral {
    @objc(maximumUpdateValueLength) var _objc_maximumUpdateValueLength: Int { maximumUpdateValueLength }
}
extension CBATTRequest {
    @objc(central) var _objc_central: CBCentral { central }
    @objc(characteristic) var _objc_characteristic: CBCharacteristic { characteristic }
    @objc(offset) var _objc_offset: Int { offset }
    @objc(value) var _objc_value: Data? { get { value } set { value = newValue } }
}
extension CBL2CAPChannel {
    @objc(peer) var _objc_peer: CBPeer? { peer }
    @objc(inputStream) var _objc_inputStream: InputStream? { inputStream }
    @objc(outputStream) var _objc_outputStream: OutputStream? { outputStream }
    @objc(PSM) var _objc_psm: UInt16 { psm }
}
extension CBPeripheral {
    @objc(delegate) var _objc_delegate: CBPeripheralDelegate? { get { delegate } set { delegate = newValue } }
    @objc(name) var _objc_name: String? { name }
    @objc(state) var _objc_state: Int { state.rawValue }
    @objc(services) var _objc_services: [CBService]? { services }
    @objc(canSendWriteWithoutResponse) var _objc_canSend: Bool { canSendWriteWithoutResponse }
    @objc(discoverServices:) func _objc_discoverServices(_ u: [CBUUID]?) { discoverServices(u) }
    @objc(discoverIncludedServices:forService:) func _objc_discoverIncluded(_ u: [CBUUID]?, for s: CBService) { discoverIncludedServices(u, for: s) }
    @objc(discoverCharacteristics:forService:) func _objc_discoverCharacteristics(_ u: [CBUUID]?, for s: CBService) { discoverCharacteristics(u, for: s) }
    @objc(discoverDescriptorsForCharacteristic:) func _objc_discoverDescriptors(_ c: CBCharacteristic) { discoverDescriptors(for: c) }
    @objc(readValueForCharacteristic:) func _objc_read(_ c: CBCharacteristic) { readValue(for: c) }
    @objc(readValueForDescriptor:) func _objc_read(_ d: CBDescriptor) { readValue(for: d) }
    @objc(writeValue:forCharacteristic:type:) func _objc_write(_ v: Data, for c: CBCharacteristic, type: Int) {
        writeValue(v, for: c, type: CBCharacteristicWriteType(rawValue: type) ?? .withResponse)
    }
    @objc(writeValue:forDescriptor:) func _objc_write(_ v: Data, for d: CBDescriptor) { writeValue(v, for: d) }
    @objc(setNotifyValue:forCharacteristic:) func _objc_setNotify(_ b: Bool, for c: CBCharacteristic) { setNotifyValue(b, for: c) }
    @objc(maximumWriteValueLengthForType:) func _objc_maxWrite(_ t: Int) -> Int { maximumWriteValueLength(for: CBCharacteristicWriteType(rawValue: t) ?? .withResponse) }
    @objc(readRSSI) func _objc_readRSSI() { readRSSI() }
    @objc(openL2CAPChannel:) func _objc_openL2CAP(_ psm: UInt16) { openL2CAPChannel(psm) }
}
extension CBManager {
    @objc(state) var _objc_state: Int { state.rawValue }
    @objc(authorization) var _objc_authorization: Int { authorization.rawValue }
    @objc(authorization) class var _objc_classAuthorization: Int { authorization.rawValue }
}
extension CBCentralManager {
    @objc(initWithDelegate:queue:) convenience init(_objcDelegate d: CBCentralManagerDelegate?, queue: dispatch_queue_t?) {
        self.init(delegate: d, queue: nil, options: nil)
    }
    @objc(initWithDelegate:queue:options:) convenience init(_objcDelegate d: CBCentralManagerDelegate?, queue: dispatch_queue_t?, options: [String: Any]?) {
        self.init(delegate: d, queue: nil, options: options)
    }
    @objc(delegate) var _objc_delegate: CBCentralManagerDelegate? { get { delegate } set { delegate = newValue } }
    @objc(isScanning) var _objc_isScanning: Bool { isScanning }
    @objc(supportsFeatures:) class func _objc_supports(_ f: UInt) -> Bool { supports(Feature(rawValue: f)) }
    @objc(scanForPeripheralsWithServices:options:) func _objc_scan(_ u: [CBUUID]?, options: [String: Any]?) { scanForPeripherals(withServices: u, options: options) }
    @objc(stopScan) func _objc_stopScan() { stopScan() }
    @objc(connectPeripheral:options:) func _objc_connect(_ p: CBPeripheral, options: [String: Any]?) { connect(p, options: options) }
    @objc(cancelPeripheralConnection:) func _objc_cancel(_ p: CBPeripheral) { cancelPeripheralConnection(p) }
    @objc(retrievePeripheralsWithIdentifiers:) func _objc_retrieve(_ ids: [UUID]) -> [CBPeripheral] { retrievePeripherals(withIdentifiers: ids) }
    @objc(retrieveConnectedPeripheralsWithServices:) func _objc_retrieveConnected(_ u: [CBUUID]) -> [CBPeripheral] { retrieveConnectedPeripherals(withServices: u) }
}
extension CBPeripheralManager {
    @objc(initWithDelegate:queue:) convenience init(_objcDelegate d: CBPeripheralManagerDelegate?, queue: dispatch_queue_t?) {
        self.init(delegate: d, queue: nil, options: nil)
    }
    @objc(initWithDelegate:queue:options:) convenience init(_objcDelegate d: CBPeripheralManagerDelegate?, queue: dispatch_queue_t?, options: [String: Any]?) {
        self.init(delegate: d, queue: nil, options: options)
    }
    @objc(delegate) var _objc_delegate: CBPeripheralManagerDelegate? { get { delegate } set { delegate = newValue } }
    @objc(isAdvertising) var _objc_isAdvertising: Bool { isAdvertising }
    @objc(startAdvertising:) func _objc_startAdvertising(_ d: [String: Any]?) { startAdvertising(d) }
    @objc(stopAdvertising) func _objc_stopAdvertising() { stopAdvertising() }
    @objc(addService:) func _objc_add(_ s: CBMutableService) { add(s) }
    @objc(removeService:) func _objc_remove(_ s: CBMutableService) { remove(s) }
    @objc(removeAllServices) func _objc_removeAll() { removeAllServices() }
    @objc(setDesiredConnectionLatency:forCentral:) func _objc_latency(_ l: Int, for c: CBCentral) {
        setDesiredConnectionLatency(CBPeripheralManagerConnectionLatency(rawValue: l) ?? .low, for: c)
    }
    @objc(updateValue:forCharacteristic:onSubscribedCentrals:)
    func _objc_update(_ v: Data, for c: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        updateValue(v, for: c, onSubscribedCentrals: centrals)
    }
    @objc(respondToRequest:withResult:) func _objc_respond(_ r: CBATTRequest, result: Int) { respond(to: r, withResult: CBATTError.Code(rawValue: result) ?? .unlikelyError) }
    @objc(publishL2CAPChannelWithEncryption:) func _objc_publish(_ e: Bool) { publishL2CAPChannel(withEncryption: e) }
    @objc(unpublishL2CAPChannel:) func _objc_unpublish(_ psm: UInt16) { unpublishL2CAPChannel(psm) }
}
