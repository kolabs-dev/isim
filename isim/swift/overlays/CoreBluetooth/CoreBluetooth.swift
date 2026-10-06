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

public struct CBError: CustomNSError, Sendable {
    public enum Code: Int, Sendable {
        case unknown = 0, invalidParameters, invalidHandle, notConnected, outOfSpace, operationCancelled, connectionTimeout
        case peripheralDisconnected, uuidNotAllowed, alreadyAdvertising, connectionFailed, connectionLimitReached, unknownDevice, operationNotSupported
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CBErrorDomain }
    public var errorCode: Int { code.rawValue }
}

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

open class CBAttribute: NSObject, @unchecked Sendable { open var uuid: CBUUID { CBUUID(string: "0000") } }
open class CBService: CBAttribute, @unchecked Sendable {
    open var isPrimary: Bool { true }
    open var characteristics: [CBCharacteristic]? { nil }
    open var includedServices: [CBService]? { nil }
    open weak var peripheral: CBPeripheral?
}
public struct CBCharacteristicProperties: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let broadcast = CBCharacteristicProperties(rawValue: 1), read = CBCharacteristicProperties(rawValue: 2)
    public static let writeWithoutResponse = CBCharacteristicProperties(rawValue: 4), write = CBCharacteristicProperties(rawValue: 8)
    public static let notify = CBCharacteristicProperties(rawValue: 16), indicate = CBCharacteristicProperties(rawValue: 32)
}
open class CBCharacteristic: CBAttribute, @unchecked Sendable {
    open var properties: CBCharacteristicProperties { [] }
    open var value: Data? { nil }
    open var isNotifying: Bool { false }
    open weak var service: CBService?
}
open class CBPeer: NSObject, @unchecked Sendable { open var identifier: UUID { UUID() } }
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
}
@objc public protocol CBPeripheralDelegate: NSObjectProtocol {
    @objc optional func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    @objc optional func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    @objc optional func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    @objc optional func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
}

open class CBManager: NSObject, @unchecked Sendable {
    open var state: CBManagerState { .unknown }
    /// no Bluetooth permission prompt is shown on a device without Bluetooth
    open class var authorization: CBManagerAuthorization { .allowedAlways }
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
            self.current = .unsupported
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
    @objc optional func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?)
}
open class CBPeripheralManager: CBManager, @unchecked Sendable {
    open weak var delegate: CBPeripheralManagerDelegate?
    private var current: CBManagerState = .unknown
    open override var state: CBManagerState { current }
    open private(set) var isAdvertising = false
    @available(*, deprecated) open class func authorizationStatus() -> CBPeripheralManagerAuthorizationStatus { .authorized }
    public convenience override init() { self.init(delegate: nil, queue: nil, options: nil) }
    public convenience init(delegate: CBPeripheralManagerDelegate?, queue: DispatchQueue?) { self.init(delegate: delegate, queue: queue, options: nil) }
    public init(delegate: CBPeripheralManagerDelegate?, queue: DispatchQueue?, options: [String: Any]? = nil) {
        self.delegate = delegate
        super.init()
        (queue ?? .main).async { [weak self] in
            guard let self else { return }
            self.current = .unsupported
            self.delegate?.peripheralManagerDidUpdateState(self)
        }
    }
    open func startAdvertising(_ advertisementData: [String: Any]?) { misuse("startAdvertising") }
    open func stopAdvertising() { isAdvertising = false }
    open func removeAllServices() {}
}
