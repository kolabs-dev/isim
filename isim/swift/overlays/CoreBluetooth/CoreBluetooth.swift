// isim Core Bluetooth (self-authored, iOS API names). Like the iOS Simulator, the simulated device has no Bluetooth
// radio: managers report CBManagerState.unsupported, nothing is discovered, and commands that need a powered-on radio
// log iOS's API MISUSE message. The API exists so apps build and run their "Bluetooth unavailable" paths.
import Foundation

@objc public enum CBManagerState: Int, Sendable { case unknown = 0, resetting, unsupported, unauthorized, poweredOff, poweredOn }
@objc public enum CBManagerAuthorization: Int, Sendable { case notDetermined = 0, restricted, denied, allowedAlways }
@available(*, deprecated, renamed: "CBManagerState") public typealias CBCentralManagerState = CBManagerState
@objc public enum CBPeripheralState: Int, Sendable { case disconnected = 0, connecting, connected, disconnecting }
@objc public enum CBPeripheralManagerAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted, denied, authorized }
@objc public enum CBCharacteristicWriteType: Int, Sendable { case withResponse = 0, withoutResponse }
@objc public enum CBPeripheralManagerConnectionLatency: Int, Sendable { case low = 0, medium, high }

public let CBAdvertisementDataLocalNameKey = "kCBAdvDataLocalName"
public let CBAdvertisementDataManufacturerDataKey = "kCBAdvDataManufacturerData"
public let CBAdvertisementDataServiceDataKey = "kCBAdvDataServiceData"
public let CBAdvertisementDataServiceUUIDsKey = "kCBAdvDataServiceUUIDs"
public let CBAdvertisementDataTxPowerLevelKey = "kCBAdvDataTxPowerLevel"
public let CBAdvertisementDataIsConnectable = "kCBAdvDataIsConnectable"
public let CBCentralManagerScanOptionAllowDuplicatesKey = "kCBScanOptionAllowDuplicates"
public let CBCentralManagerOptionShowPowerAlertKey = "kCBInitOptionShowPowerAlert"
public let CBCentralManagerOptionRestoreIdentifierKey = "kCBRestoreIdentifierKey"
public let CBConnectPeripheralOptionNotifyOnDisconnectionKey = "kCBConnectOptionNotifyOnDisconnection"
public let CBErrorDomain = "CBErrorDomain"
public let CBATTErrorDomain = "CBATTErrorDomain"
public let CBAdvertisementDataOverflowServiceUUIDsKey = "kCBAdvDataHashedServiceUUIDs"
public let CBAdvertisementDataSolicitedServiceUUIDsKey = "kCBAdvDataSolicitedServiceUUIDs"
public let CBPeripheralManagerOptionShowPowerAlertKey = "kCBInitOptionShowPowerAlert"
public let CBPeripheralManagerOptionRestoreIdentifierKey = "kCBRestoreIdentifierKey"
public let CBPeripheralManagerRestoredStateServicesKey = "kCBRestoredServices"
public let CBPeripheralManagerRestoredStateAdvertisementDataKey = "kCBRestoredAdvertisement"

/// the protocol/service multiplexer of an L2CAP channel
public typealias CBL2CAPPSM = UInt16

public struct CBError: CustomNSError, Sendable {
    public enum Code: Int, Sendable {
        case unknown = 0, invalidParameters, invalidHandle, notConnected, outOfSpace, operationCancelled, connectionTimeout
        case peripheralDisconnected, uuidNotAllowed, alreadyAdvertising, connectionFailed, connectionLimitReached, unknownDevice, operationNotSupported
        case peerRemovedPairingInformation, encryptionTimedOut, tooManyLEPairedDevices
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CBErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var unknown: Code { .unknown }
    public static var invalidParameters: Code { .invalidParameters }
    public static var invalidHandle: Code { .invalidHandle }
    public static var notConnected: Code { .notConnected }
    public static var outOfSpace: Code { .outOfSpace }
    public static var operationCancelled: Code { .operationCancelled }
    public static var connectionTimeout: Code { .connectionTimeout }
    public static var peripheralDisconnected: Code { .peripheralDisconnected }
    public static var uuidNotAllowed: Code { .uuidNotAllowed }
    public static var alreadyAdvertising: Code { .alreadyAdvertising }
    public static var connectionFailed: Code { .connectionFailed }
    public static var connectionLimitReached: Code { .connectionLimitReached }
    public static var unknownDevice: Code { .unknownDevice }
    public static var operationNotSupported: Code { .operationNotSupported }
    public static var peerRemovedPairingInformation: Code { .peerRemovedPairingInformation }
    public static var encryptionTimedOut: Code { .encryptionTimedOut }
    public static var tooManyLEPairedDevices: Code { .tooManyLEPairedDevices }
}

/// an Attribute Protocol error (a peripheral manager's response to a read or write request)
public struct CBATTError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, @unchecked Sendable {
        case success = 0, invalidHandle, readNotPermitted, writeNotPermitted, invalidPdu, insufficientAuthentication
        case requestNotSupported, invalidOffset, insufficientAuthorization, prepareQueueFull, attributeNotFound
        case attributeNotLong, insufficientEncryptionKeySize, invalidAttributeValueLength, unlikelyError, insufficientEncryption
        case unsupportedGroupType, insufficientResources
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CBATTErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var success: Code { .success }
    public static var invalidHandle: Code { .invalidHandle }
    public static var readNotPermitted: Code { .readNotPermitted }
    public static var writeNotPermitted: Code { .writeNotPermitted }
    public static var invalidPdu: Code { .invalidPdu }
    public static var insufficientAuthentication: Code { .insufficientAuthentication }
    public static var requestNotSupported: Code { .requestNotSupported }
    public static var invalidOffset: Code { .invalidOffset }
    public static var insufficientAuthorization: Code { .insufficientAuthorization }
    public static var prepareQueueFull: Code { .prepareQueueFull }
    public static var attributeNotFound: Code { .attributeNotFound }
    public static var attributeNotLong: Code { .attributeNotLong }
    public static var insufficientEncryptionKeySize: Code { .insufficientEncryptionKeySize }
    public static var invalidAttributeValueLength: Code { .invalidAttributeValueLength }
    public static var unlikelyError: Code { .unlikelyError }
    public static var insufficientEncryption: Code { .insufficientEncryption }
    public static var unsupportedGroupType: Code { .unsupportedGroupType }
    public static var insufficientResources: Code { .insufficientResources }
}

// the descriptors a CBMutableDescriptor may have (the others are the system's)
public let CBUUIDCharacteristicExtendedPropertiesString = "2900"
public let CBUUIDCharacteristicUserDescriptionString = "2901"
public let CBUUIDClientCharacteristicConfigurationString = "2902"
public let CBUUIDServerCharacteristicConfigurationString = "2903"
public let CBUUIDCharacteristicFormatString = "2904"
public let CBUUIDCharacteristicAggregateFormatString = "2905"
public let CBUUIDCharacteristicValidRangeString = "2906"
public let CBUUIDL2CAPPSMCharacteristicString = "ABDD3056-28FA-441D-A470-55A75A52553A"

open class CBUUID: NSObject, NSCopying, @unchecked Sendable {
    public let uuidString: String
    public init(string theString: String) { uuidString = theString.uppercased() }
    public init(nsuuid theUUID: UUID) { uuidString = theUUID.uuidString }
    public convenience init(data theData: Data) { self.init(string: theData.map { String(format: "%02X", $0) }.joined()) }
    open var data: Data {
        var d = Data(); var hex = uuidString.replacingOccurrences(of: "-", with: "")[...]
        while hex.count >= 2 { d.append(UInt8(hex.prefix(2), radix: 16) ?? 0); hex = hex.dropFirst(2) }
        return d
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? CBUUID)?.uuidString == uuidString }
    open override var hash: Int { uuidString.hashValue }
    open override var description: String { uuidString }
}

open class CBAttribute: NSObject, @unchecked Sendable {
    var _uuid = CBUUID(string: "0000")
    open var uuid: CBUUID { _uuid }
}
open class CBService: CBAttribute, @unchecked Sendable {
    var _isPrimary = true, _characteristics: [CBCharacteristic]?, _includedServices: [CBService]?
    open var isPrimary: Bool { _isPrimary }
    open var characteristics: [CBCharacteristic]? { _characteristics }
    open var includedServices: [CBService]? { _includedServices }
    open weak var peripheral: CBPeripheral?
}
/// a service the app publishes with a peripheral manager (CBPeripheralManager.add(_:))
open class CBMutableService: CBService, @unchecked Sendable {
    public init(type UUID: CBUUID, primary isPrimary: Bool) {
        super.init()
        _uuid = UUID; _isPrimary = isPrimary
    }
    open override var uuid: CBUUID { get { _uuid } set { _uuid = newValue } }
    open override var isPrimary: Bool { get { _isPrimary } set { _isPrimary = newValue } }
    open override var characteristics: [CBCharacteristic]? {
        get { _characteristics }
        set { _characteristics = newValue; newValue?.forEach { $0.service = self } }
    }
    open override var includedServices: [CBService]? { get { _includedServices } set { _includedServices = newValue } }
}
public struct CBCharacteristicProperties: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let broadcast = CBCharacteristicProperties(rawValue: 1), read = CBCharacteristicProperties(rawValue: 2)
    public static let writeWithoutResponse = CBCharacteristicProperties(rawValue: 4), write = CBCharacteristicProperties(rawValue: 8)
    public static let notify = CBCharacteristicProperties(rawValue: 16), indicate = CBCharacteristicProperties(rawValue: 32)
    public static let authenticatedSignedWrites = CBCharacteristicProperties(rawValue: 64), extendedProperties = CBCharacteristicProperties(rawValue: 128)
    public static let notifyEncryptionRequired = CBCharacteristicProperties(rawValue: 256), indicateEncryptionRequired = CBCharacteristicProperties(rawValue: 512)
}
/// who may read and write a published characteristic's value
public struct CBAttributePermissions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let readable = CBAttributePermissions(rawValue: 1), writeable = CBAttributePermissions(rawValue: 2)
    public static let readEncryptionRequired = CBAttributePermissions(rawValue: 4), writeEncryptionRequired = CBAttributePermissions(rawValue: 8)
}
open class CBCharacteristic: CBAttribute, @unchecked Sendable {
    var _properties: CBCharacteristicProperties = [], _value: Data?, _descriptors: [CBDescriptor]?
    open var properties: CBCharacteristicProperties { _properties }
    open var value: Data? { _value }
    open var descriptors: [CBDescriptor]? { _descriptors }
    open var isNotifying: Bool { false }
    open weak var service: CBService?
}
/// a characteristic the app publishes: a value given here is cached and read-only (iOS requires `.read` alone then)
open class CBMutableCharacteristic: CBCharacteristic, @unchecked Sendable {
    open var permissions: CBAttributePermissions
    open var subscribedCentrals: [CBCentral]? { nil }
    public init(type UUID: CBUUID, properties: CBCharacteristicProperties, value: Data?, permissions: CBAttributePermissions) {
        self.permissions = permissions
        super.init()
        _uuid = UUID; _properties = properties; _value = value
    }
    open override var uuid: CBUUID { get { _uuid } set { _uuid = newValue } }
    open override var properties: CBCharacteristicProperties { get { _properties } set { _properties = newValue } }
    open override var value: Data? { get { _value } set { _value = newValue } }
    open override var descriptors: [CBDescriptor]? {
        get { _descriptors }
        set { _descriptors = newValue; newValue?.forEach { $0.characteristic = self } }
    }
}
open class CBDescriptor: CBAttribute, @unchecked Sendable {
    var _value: Any?
    open weak var characteristic: CBCharacteristic?
    open var value: Any? { _value }
}
/// a descriptor of a published characteristic: only the user description (a String) and the presentation format
/// (Data) can be added, like iOS
open class CBMutableDescriptor: CBDescriptor, @unchecked Sendable {
    public init(type UUID: CBUUID, value: Any?) {
        super.init()
        _uuid = UUID; _value = value
        if ![CBUUIDCharacteristicUserDescriptionString, CBUUIDCharacteristicFormatString].contains(UUID.uuidString) {
            NSLog("[CoreBluetooth] API MISUSE: CBMutableDescriptor only supports the characteristic user description and format descriptors, not %@", UUID.uuidString)
        }
    }
}
open class CBPeer: NSObject, @unchecked Sendable {
    let _identifier = UUID()
    open var identifier: UUID { _identifier }
}
/// a remote device connected to the app's peripheral manager
open class CBCentral: CBPeer, @unchecked Sendable {
    open var maximumUpdateValueLength: Int { 20 }
}
/// a read or write of a published characteristic by a central
open class CBATTRequest: NSObject, @unchecked Sendable {
    public let central: CBCentral
    public let characteristic: CBCharacteristic
    public let offset: Int
    open var value: Data?
    init(central: CBCentral, characteristic: CBCharacteristic, offset: Int, value: Data?) {
        self.central = central; self.characteristic = characteristic; self.offset = offset; self.value = value
    }
}
/// a connection-oriented L2CAP channel to a peer
open class CBL2CAPChannel: NSObject, @unchecked Sendable {
    open var peer: CBPeer! { _peer }
    open var inputStream: InputStream! { _input }
    open var outputStream: OutputStream! { _output }
    open var psm: CBL2CAPPSM { _psm }
    let _peer: CBPeer, _psm: CBL2CAPPSM, _input: InputStream, _output: OutputStream
    init(peer: CBPeer, psm: CBL2CAPPSM) {
        _peer = peer; _psm = psm; _input = InputStream(data: Data()); _output = OutputStream(toMemory: ())
    }
}
open class CBPeripheral: CBPeer, @unchecked Sendable {
    open weak var delegate: CBPeripheralDelegate?
    open var name: String? { nil }
    open var state: CBPeripheralState { .disconnected }
    open var services: [CBService]? { nil }
    open func discoverServices(_ serviceUUIDs: [CBUUID]?) {}
    open func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {}
    open func readValue(for characteristic: CBCharacteristic) {}
    open func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {}
    open func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {}
    open func readRSSI() {}
    open func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBService) {}
    open func discoverDescriptors(for characteristic: CBCharacteristic) {}
    open func readValue(for descriptor: CBDescriptor) {}
    open func writeValue(_ data: Data, for descriptor: CBDescriptor) {}
    open func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int { 20 }
    open var canSendWriteWithoutResponse: Bool { false }
    open func openL2CAPChannel(_ PSM: CBL2CAPPSM) {}
}
@objc public protocol CBPeripheralDelegate: NSObjectProtocol {
    @objc optional func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    @objc optional func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    @objc optional func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    @objc optional func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
    @objc optional func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?)
    @objc optional func peripheralDidUpdateName(_ peripheral: CBPeripheral)
    @objc optional func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral)
}

/// Info.plist NSBluetoothAlwaysUsageDescription: Core Bluetooth needs it (iOS 13+ terminates an app without it; isim
/// reports Bluetooth unauthorized)
enum _CBUsage {
    static let declared: Bool = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") as? String, !s.isEmpty { return true }
        NSLog("isim CoreBluetooth: this app has attempted to access privacy-sensitive data without a usage description. The app's Info.plist must contain an NSBluetoothAlwaysUsageDescription key with a string value explaining to the user how the app uses this data (iOS would terminate the app; isim reports the access as denied)")
        return false
    }()
    /// a manager's state: unauthorized without the usage description, else unsupported (no Bluetooth radio)
    static var state: CBManagerState { declared ? .unsupported : .unauthorized }
}

open class CBManager: NSObject, @unchecked Sendable {
    open var state: CBManagerState { .unknown }
    /// no Bluetooth permission prompt is shown on a device without Bluetooth; denied without the usage description
    open class var authorization: CBManagerAuthorization { _CBUsage.declared ? .allowedAlways : .denied }
    open var authorization: CBManagerAuthorization { CBManager.authorization }
    func misuse(_ what: String) {
        NSLog("[CoreBluetooth] API MISUSE: <%@: %p> can only accept this command while in the powered on state", String(describing: type(of: self)), unsafeBitCast(self, to: Int.self))
    }
}

@objc public protocol CBCentralManagerDelegate: NSObjectProtocol {
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    @objc optional func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any])
    @objc optional func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber)
    @objc optional func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    @objc optional func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
    @objc optional func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
}

open class CBCentralManager: CBManager, @unchecked Sendable {
    open weak var delegate: CBCentralManagerDelegate?
    private var current: CBManagerState = .unknown
    open override var state: CBManagerState { current }
    open private(set) var isScanning = false
    public struct Feature: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let extendedScanAndConnect = Feature(rawValue: 1)
    }
    open class func supports(_ features: Feature) -> Bool { false }

    public convenience override init() { self.init(delegate: nil, queue: nil, options: nil) }
    public convenience init(delegate: CBCentralManagerDelegate?, queue: DispatchQueue?) { self.init(delegate: delegate, queue: queue, options: nil) }
    public init(delegate: CBCentralManagerDelegate?, queue: DispatchQueue?, options: [String: Any]? = nil) {
        self.delegate = delegate
        super.init()
        (queue ?? .main).async { [weak self] in
            guard let self else { return }
            self.current = _CBUsage.state
            self.delegate?.centralManagerDidUpdateState(self)
        }
    }
    open func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]? = nil) {
        if current != .poweredOn { misuse("scanForPeripherals"); return }
        isScanning = true
    }
    open func stopScan() { isScanning = false }
    open func connect(_ peripheral: CBPeripheral, options: [String: Any]? = nil) { misuse("connect") }
    open func cancelPeripheralConnection(_ peripheral: CBPeripheral) {}
    open func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] { [] }
    open func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] { [] }
}

@objc public protocol CBPeripheralManagerDelegate: NSObjectProtocol {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any])
    @objc optional func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest])
    @objc optional func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?)
    @objc optional func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?)
}
/// the app as a Bluetooth LE peripheral: it publishes services and advertises them. isim has no radio (like the
/// Simulator), so the manager stays .unsupported and its commands log iOS's API MISUSE message and do nothing
open class CBPeripheralManager: CBManager, @unchecked Sendable {
    open weak var delegate: CBPeripheralManagerDelegate?
    private var current: CBManagerState = .unknown
    open override var state: CBManagerState { current }
    open private(set) var isAdvertising = false
    @available(*, deprecated) open class func authorizationStatus() -> CBPeripheralManagerAuthorizationStatus { _CBUsage.declared ? .authorized : .denied }
    public convenience override init() { self.init(delegate: nil, queue: nil, options: nil) }
    public convenience init(delegate: CBPeripheralManagerDelegate?, queue: DispatchQueue?) { self.init(delegate: delegate, queue: queue, options: nil) }
    public init(delegate: CBPeripheralManagerDelegate?, queue: DispatchQueue?, options: [String: Any]? = nil) {
        self.delegate = delegate
        super.init()
        (queue ?? .main).async { [weak self] in
            guard let self else { return }
            self.current = _CBUsage.state
            self.delegate?.peripheralManagerDidUpdateState(self)
        }
    }
    open func startAdvertising(_ advertisementData: [String: Any]?) { misuse("startAdvertising") }
    open func stopAdvertising() { isAdvertising = false }
    open func add(_ service: CBMutableService) { misuse("addService") }
    open func remove(_ service: CBMutableService) { misuse("removeService") }
    open func removeAllServices() {}
    open func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral) {}
    /// false: the value was not sent (no central is subscribed: there is no radio)
    open func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        if current != .poweredOn { misuse("updateValue") }
        return false
    }
    open func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {}
    open func publishL2CAPChannel(withEncryption encryptionRequired: Bool) { misuse("publishL2CAPChannel") }
    open func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM) {}
}
