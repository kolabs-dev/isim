// isim Network for C and Objective-C (sdk-src/Frameworks/Network): the path monitor's C API (nw_path_monitor_*,
// nw_path_*, nw_interface_*), forwarding to NWPathMonitor (the host's connectivity). As on Apple platforms, the
// objects are Objective-C objects (OS objects that ARC retains and releases).
import Foundation
import Darwin

final class _NWCPathMonitor: NSObject {
    let monitor: NWPathMonitor
    var queue: dispatch_queue_t? {               // the C caller's queue; the monitor itself runs on the main queue
        didSet {                                 // held while set (an Objective-C caller's reference is ARC's)
            if let queue { dispatch_retain(UnsafeMutableRawPointer(queue)) }
            if let oldValue { dispatch_release(UnsafeMutableRawPointer(oldValue)) }
        }
    }
    var update: ((NSObject) -> Void)?
    var cancelHandler: (() -> Void)?
    init(_ m: NWPathMonitor) { monitor = m }
    deinit { if let queue { dispatch_release(UnsafeMutableRawPointer(queue)) } }
}
final class _NWCPath: NSObject { let path: NWPath; init(_ p: NWPath) { path = p } }
final class _NWCInterface: NSObject {
    let interface: NWInterface
    init(_ i: NWInterface) { interface = i }
    var cName: UnsafeMutablePointer<CChar>? = nil
    deinit { free(cName) }
}
private func obj<T: AnyObject>(_ p: UnsafeRawPointer, _: T.Type) -> T { Unmanaged<T>.fromOpaque(p).takeUnretainedValue() }
private func interfaceType(_ t: Int32) -> NWInterface.InterfaceType? {
    [0: .other, 1: .wifi, 2: .cellular, 3: .wiredEthernet, 4: .loopback][t]
}
private func code(_ t: NWInterface.InterfaceType) -> Int32 {
    switch t { case .other: return 0; case .wifi: return 1; case .cellular: return 2; case .wiredEthernet: return 3; case .loopback: return 4 }
}

@_cdecl("nw_path_monitor_create")
public func _c_nw_path_monitor_create() -> UnsafeMutableRawPointer { Unmanaged.passRetained(_NWCPathMonitor(NWPathMonitor())).toOpaque() }
@_cdecl("nw_path_monitor_create_with_type")
public func _c_nw_path_monitor_create_with_type(_ t: Int32) -> UnsafeMutableRawPointer {
    let m = interfaceType(t).map { NWPathMonitor(requiredInterfaceType: $0) } ?? NWPathMonitor()
    return Unmanaged.passRetained(_NWCPathMonitor(m)).toOpaque()
}
@_cdecl("nw_path_monitor_set_queue")
public func _c_nw_path_monitor_set_queue(_ m: UnsafeRawPointer, _ q: OpaquePointer?) { obj(m, _NWCPathMonitor.self).queue = q }
/// runs `work` on the C caller's queue (the main queue when none was set)
private func onQueue(_ mon: _NWCPathMonitor, _ work: @escaping () -> Void) {
    if let q = mon.queue { dispatch_async(q, work) } else { work() }
}
@_cdecl("nw_path_monitor_set_update_handler")
public func _c_nw_path_monitor_set_update_handler(_ m: UnsafeRawPointer, _ handler: @escaping @convention(block) (NSObject) -> Void) {
    let mon = obj(m, _NWCPathMonitor.self)
    mon.update = handler
    mon.monitor.pathUpdateHandler = { [weak mon] p in
        guard let mon else { return }
        onQueue(mon) { mon.update?(_NWCPath(p)) }
    }
}
@_cdecl("nw_path_monitor_set_cancel_handler")
public func _c_nw_path_monitor_set_cancel_handler(_ m: UnsafeRawPointer, _ handler: @escaping @convention(block) () -> Void) {
    obj(m, _NWCPathMonitor.self).cancelHandler = handler
}
@_cdecl("nw_path_monitor_start")
public func _c_nw_path_monitor_start(_ m: UnsafeRawPointer) {
    let mon = obj(m, _NWCPathMonitor.self)
    mon.monitor.start(queue: .main)
}
@_cdecl("nw_path_monitor_cancel")
public func _c_nw_path_monitor_cancel(_ m: UnsafeRawPointer) {
    let mon = obj(m, _NWCPathMonitor.self)
    mon.monitor.cancel()
    if let h = mon.cancelHandler { DispatchQueue.main.async { onQueue(mon, h) } }
}
/* nw_path_status_t: invalid 0, satisfied 1, unsatisfied 2, satisfiable 3 */
@_cdecl("nw_path_get_status")
public func _c_nw_path_get_status(_ p: UnsafeRawPointer) -> Int32 {
    switch obj(p, _NWCPath.self).path.status { case .satisfied: return 1; case .unsatisfied: return 2; case .requiresConnection: return 3 }
}
@_cdecl("nw_path_is_expensive") public func _c_nw_path_is_expensive(_ p: UnsafeRawPointer) -> Bool { obj(p, _NWCPath.self).path.isExpensive }
@_cdecl("nw_path_is_constrained") public func _c_nw_path_is_constrained(_ p: UnsafeRawPointer) -> Bool { obj(p, _NWCPath.self).path.isConstrained }
@_cdecl("nw_path_has_ipv4") public func _c_nw_path_has_ipv4(_ p: UnsafeRawPointer) -> Bool { obj(p, _NWCPath.self).path.supportsIPv4 }
@_cdecl("nw_path_has_ipv6") public func _c_nw_path_has_ipv6(_ p: UnsafeRawPointer) -> Bool { obj(p, _NWCPath.self).path.supportsIPv6 }
@_cdecl("nw_path_has_dns") public func _c_nw_path_has_dns(_ p: UnsafeRawPointer) -> Bool { obj(p, _NWCPath.self).path.supportsDNS }
@_cdecl("nw_path_uses_interface_type")
public func _c_nw_path_uses_interface_type(_ p: UnsafeRawPointer, _ t: Int32) -> Bool {
    interfaceType(t).map { obj(p, _NWCPath.self).path.usesInterfaceType($0) } ?? false
}
@_cdecl("nw_path_enumerate_interfaces")
public func _c_nw_path_enumerate_interfaces(_ p: UnsafeRawPointer, _ block: @convention(block) (NSObject) -> Bool) {
    for i in obj(p, _NWCPath.self).path.availableInterfaces { if !block(_NWCInterface(i)) { break } }
}
@_cdecl("nw_interface_get_type") public func _c_nw_interface_get_type(_ i: UnsafeRawPointer) -> Int32 { code(obj(i, _NWCInterface.self).interface.type) }
@_cdecl("nw_interface_get_index") public func _c_nw_interface_get_index(_ i: UnsafeRawPointer) -> UInt32 { UInt32(obj(i, _NWCInterface.self).interface.index) }
@_cdecl("nw_interface_get_name")
public func _c_nw_interface_get_name(_ i: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    let o = obj(i, _NWCInterface.self)
    if o.cName == nil { o.cName = strdup(o.interface.name) }
    return UnsafePointer(o.cName)
}
