// isim AccessorySetupKit Swift overlay: the members typed with CoreBluetooth's CBUUID (the CoreBluetooth overlay's Swift
// class, which the Objective-C header types `id` for Swift).
@_exported import AccessorySetupKit
import CoreBluetooth
import Dispatch

@available(iOS 18.0, *)
extension ASAccessorySession {
    /// activates the session; its events reach `eventHandler` on `queue`
    public func activate(on queue: DispatchQueue, eventHandler: @escaping (ASAccessoryEvent) -> Void) {
        __activate(withQueue: nil) { event in queue.async { eventHandler(event) } }
    }
}

@available(iOS 18.0, *)
extension ASDiscoveryDescriptor {
    public var bluetoothServiceUUID: CBUUID? {
        get { __bluetoothServiceUUID as? CBUUID }
        set { __bluetoothServiceUUID = newValue }
    }
}
