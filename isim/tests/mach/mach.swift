// The Swift side of MachTest: Mach calls as Swift apps write them (Darwin / Foundation imports, mach_task_self_,
// withMemoryRebound to integer_t, counts from MemoryLayout).
import Foundation

private var failures = 0, checks = 0
private func check(_ ok: Bool, _ what: String, line: Int = #line) {
    checks += 1
    if ok { print("PASS  swift: \(what)") } else { failures += 1; print("FAIL  swift: \(what)  (mach.swift:\(line))") }
}

/// The app's memory footprint (the snippet in many apps' debug overlays)
private func footprint() -> UInt64? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    return kr == KERN_SUCCESS ? info.phys_footprint : nil
}

/// Resident size through MACH_TASK_BASIC_INFO
private func residentSize() -> UInt64? {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
    }
    return kr == KERN_SUCCESS ? info.resident_size : nil
}

/// Total CPU usage of the app's threads (TH_USAGE_SCALE = one CPU)
private func cpuUsage() -> Double? {
    var threads: thread_act_array_t?
    var count = mach_msg_type_number_t(0)
    guard task_threads(mach_task_self_, &threads, &count) == KERN_SUCCESS, let threads else { return nil }
    defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), vm_size_t(Int(count) * MemoryLayout<thread_t>.stride)) }
    var total = 0.0
    for i in 0..<Int(count) {
        var info = thread_basic_info()
        var n = mach_msg_type_number_t(THREAD_INFO_MAX)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &n) }
        }
        if kr == KERN_SUCCESS, info.flags & TH_FLAGS_IDLE == 0 { total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) }
        mach_port_deallocate(mach_task_self_, threads[i])
    }
    return total
}

/// Free memory through host_statistics64
private func freeMemory() -> UInt64? {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
    }
    return kr == KERN_SUCCESS ? UInt64(stats.free_count) * UInt64(vm_kernel_page_size) : nil
}

@_cdecl("swift_mach_checks") public func swiftMachChecks() -> Int32 {
    var tb = mach_timebase_info_data_t()
    check(mach_timebase_info(&tb) == KERN_SUCCESS && tb.numer == 1 && tb.denom == 1, "mach_timebase_info")
    let start = mach_absolute_time()
    Thread.sleep(forTimeInterval: 0.01)
    check(mach_absolute_time() - start >= 10_000_000, "mach_absolute_time in nanoseconds")
    check(DispatchTime.now().uptimeNanoseconds >= start, "DispatchTime agrees with mach_absolute_time")

    let fp = footprint(), rss = residentSize()
    check(fp != nil && fp! > 0, "phys_footprint \(fp ?? 0)")
    check(rss != nil && rss! > 1_000_000, "resident_size \(rss ?? 0)")
    let cpu = cpuUsage()
    check(cpu != nil && cpu! >= 0, "CPU usage over task_threads \(cpu ?? -1)")
    let free = freeMemory()
    check(free != nil && free! > 0 && free! < ProcessInfo.processInfo.physicalMemory, "free memory \(free ?? 0)")
    check(vm_page_size == vm_size_t(getpagesize()), "vm_page_size")

    let me = mach_thread_self()
    check(me == pthread_mach_thread_np(pthread_self()), "mach_thread_self is pthread_mach_thread_np(pthread_self())")
    mach_port_deallocate(mach_task_self_, me)

    var port = mach_port_name_t()
    check(mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &port) == KERN_SUCCESS, "mach_port_allocate")
    check(mach_port_mod_refs(mach_task_self_, port, MACH_PORT_RIGHT_RECEIVE, -1) == KERN_SUCCESS, "mach_port_mod_refs")
    check(String(cString: mach_error_string(KERN_INVALID_ADDRESS)) == "(os/kern) invalid address", "mach_error_string")
    return Int32(failures)
}
@_cdecl("swift_mach_check_count") public func swiftMachCheckCount() -> Int32 { Int32(checks) }
