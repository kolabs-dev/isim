import Foundation

/// Waits (polling) until `cond` holds or `timeout` passes.
func waitFor(_ timeout: Double = 2, _ cond: () -> Bool) -> Bool {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end { if cond() { return true }; pause(0.01) }
    return cond()
}

final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var v: T
    init(_ v: T) { self.v = v }
    var value: T { get { lock.lock(); defer { lock.unlock() }; return v } set { lock.lock(); v = newValue; lock.unlock() } }
    func mutate(_ f: (inout T) -> Void) { lock.lock(); f(&v); lock.unlock() }
}

func dispatchTests() {
    let q = DispatchQueue(label: "dispatch.sources")

    // user data sources coalesce merged values until the handler runs
    let addSum = Box<[UInt]>([])
    let add = DispatchSource.makeUserDataAddSource(queue: q)
    add.setEventHandler { addSum.mutate { $0.append(add.data) } }
    q.suspend()
    add.activate()
    add.add(data: 2); add.add(data: 3); add.add(data: 5)
    q.resume()
    check(waitFor { addSum.value.reduce(0, +) == 10 } && addSum.value.count == 1, "user data add source coalesces 2+3+5 into one event (\(addSum.value))")
    add.add(data: 7)
    check(waitFor { addSum.value.count == 2 } && addSum.value.last == 7, "user data add source: data resets after each handler")
    add.cancel()

    let orBits = Box<UInt>(0)
    let or = DispatchSource.makeUserDataOrSource(queue: q)
    or.setEventHandler { orBits.value = or.data }
    q.suspend(); or.activate(); or.or(data: 0b001); or.or(data: 0b100); q.resume()
    check(waitFor { orBits.value == 0b101 }, "user data or source")
    or.cancel()

    let replaced = Box<UInt>(0)
    let rep = DispatchSource.makeUserDataReplaceSource(queue: q)
    rep.setEventHandler { replaced.value = rep.data }
    q.suspend(); rep.activate(); rep.replace(data: 4); rep.replace(data: 9); q.resume()
    check(waitFor { replaced.value == 9 }, "user data replace source keeps the last value")
    rep.cancel()

    // registration and cancel handlers
    let events = Box<[String]>([])
    let reg = DispatchSource.makeUserDataAddSource(queue: q)
    reg.setRegistrationHandler { events.mutate { $0.append("registered") } }
    reg.setCancelHandler { events.mutate { $0.append("cancelled") } }
    reg.setEventHandler { events.mutate { $0.append("event") } }
    reg.activate()
    check(waitFor { events.value == ["registered"] }, "registration handler runs on activation")
    reg.cancel()
    reg.add(data: 1)
    check(waitFor { events.value == ["registered", "cancelled"] } && reg.isCancelled, "cancel handler; no events after cancel (\(events.value))")

    // read / write sources on a pipe
    var fds: [Int32] = [0, 0]
    check(pipe(&fds) == 0, "pipe()")
    let readBytes = Box<[UInt8]>([])
    let reportedAvail = Box<UInt>(0)
    let reader = DispatchSource.makeReadSource(fileDescriptor: fds[0], queue: q)
    reader.setEventHandler {
        let avail = reader.data
        if avail == 0 { reader.cancel(); return }   // end of file
        reportedAvail.mutate { $0 = max($0, avail) }
        var buf = [UInt8](repeating: 0, count: Int(avail))
        let n = read(fds[0], &buf, buf.count)
        if n > 0 { readBytes.mutate { $0 += buf[0..<n] } }
    }
    let readerClosed = Box(false)
    reader.setCancelHandler { close(fds[0]); readerClosed.value = true }
    reader.resume()
    let msg = Array("hello dispatch".utf8)
    _ = msg.withUnsafeBytes { write(fds[1], $0.baseAddress, $0.count) }
    check(waitFor { readBytes.value == msg }, "read source fires with the readable byte count (\(reportedAvail.value) bytes)")
    check(reportedAvail.value == UInt(msg.count), "read source data = bytes available")
    let writable = Box(0)
    let writer = DispatchSource.makeWriteSource(fileDescriptor: fds[1], queue: q)
    writer.setEventHandler { writable.mutate { $0 += 1 }; writer.cancel() }
    writer.resume()
    check(waitFor { writable.value == 1 }, "write source fires when the pipe has room")
    close(fds[1])
    check(waitFor { readerClosed.value }, "read source sees end of file (data 0) and its cancel handler closes the fd")

    // signal source
    let sigCount = Box<UInt>(0)
    signal(SIGUSR1, SIG_IGN)
    let sig = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: q)
    sig.setEventHandler { sigCount.mutate { $0 += sig.data } }
    sig.resume()
    pause(0.05)
    raise(SIGUSR1); raise(SIGUSR1)
    check(waitFor { sigCount.value == 2 }, "signal source counts SIGUSR1 deliveries (\(sigCount.value))")
    sig.cancel()
    check(sig.handle == UInt(SIGUSR1), "signal source handle")

    // file system object source
    let dir = NSTemporaryDirectory() + "dispatch-vnode-\(getpid())"
    try? FileManager.default.removeItem(atPath: dir)
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
    let file = dir + "/watched.txt"
    FileManager.default.createFile(atPath: file, contents: Data("a".utf8))
    let fd = open(file, O_RDWR)
    let fsEvents = Box<DispatchSource.FileSystemEvent>([])
    let fsSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .rename, .delete], queue: q)
    fsSource.setEventHandler { fsEvents.mutate { $0.formUnion(fsSource.data) } }
    fsSource.resume()
    pause(0.1)
    _ = "bcd".withCString { write(fd, $0, 3) }
    check(waitFor { fsEvents.value.contains(.write) && fsEvents.value.contains(.extend) }, "file system source: .write + .extend after appending")
    fsEvents.value = []
    try? FileManager.default.moveItem(atPath: file, toPath: dir + "/renamed.txt")
    check(waitFor { fsEvents.value.contains(.rename) }, "file system source: .rename")
    fsEvents.value = []
    try? FileManager.default.removeItem(atPath: dir + "/renamed.txt")
    check(waitFor { fsEvents.value.contains(.delete) }, "file system source: .delete")
    fsSource.cancel(); close(fd)
    let dirFD = open(dir, O_RDONLY)
    let dirEvents = Box<DispatchSource.FileSystemEvent>([])
    let dirSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: dirFD, eventMask: .write, queue: q)
    dirSource.setEventHandler { dirEvents.mutate { $0.formUnion(dirSource.data) } }
    dirSource.resume()
    pause(0.1)
    FileManager.default.createFile(atPath: dir + "/new.txt", contents: Data())
    check(waitFor { dirEvents.value.contains(.write) }, "directory source: .write when an entry is added")
    dirSource.cancel(); close(dirFD)

    // process source: a process source for a dead pid reports .exit
    let exitSeen = Box(false)
    let proc = DispatchSource.makeProcessSource(identifier: 999_999, eventMask: .exit, queue: q)
    proc.setEventHandler { if proc.data.contains(.exit) { exitSeen.value = true } }
    proc.resume()
    check(waitFor { exitSeen.value }, "process source reports .exit for a process that is gone")
    proc.cancel()
    let mem = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: q)
    mem.setEventHandler { }
    mem.resume()
    check(mem.mask == .all && !mem.isCancelled, "memory pressure source (fires on the Simulator's memory warning: HelloAppearance)")
    mem.cancel()

    // timer source: wall deadline + data counts fires
    let timerFires = Box(0)
    let timer = DispatchSource.makeTimerSource(queue: q)
    timer.schedule(wallDeadline: .now() + 0.02, repeating: .milliseconds(20))
    timer.setEventHandler { timerFires.mutate { $0 += 1 } }
    timer.resume()
    check(waitFor { timerFires.value >= 3 }, "timer source with wallDeadline repeats")
    timer.cancel()

    // DispatchData
    var dd = Array("abc".utf8).withUnsafeBytes { DispatchData(bytes: $0) }
    "defg".utf8CString.withUnsafeBufferPointer { b in b.withMemoryRebound(to: UInt8.self) { dd.append($0.baseAddress!, count: 4) } }
    check(dd.count == 7 && Array(dd) == Array("abcdefg".utf8), "DispatchData append + iteration")
    check(dd.regions.count == 2 && dd.regions.map(\.count) == [3, 4], "DispatchData keeps regions")
    check(Array(dd.subdata(in: 2..<5)) == Array("cde".utf8) && dd[4] == UInt8(ascii: "e"), "DispatchData subdata / subscript across regions")
    var copied = [UInt8](repeating: 0, count: 4)
    copied.withUnsafeMutableBufferPointer { _ = dd.copyBytes(to: $0, from: 1..<5) }
    check(copied == Array("bcde".utf8), "DispatchData copyBytes(to:from:)")
    var seen: [Int] = []
    dd.enumerateBytes { buf, idx, _ in seen.append(idx); seen.append(buf.count) }
    check(seen == [0, 3, 3, 4], "DispatchData enumerateBytes")
    let flat = dd.withUnsafeBytes { (p: UnsafePointer<UInt8>) in String(decoding: UnsafeBufferPointer(start: p, count: 7), as: UTF8.self) }
    check(flat == "abcdefg", "DispatchData withUnsafeBytes flattens regions")
    check(Data(dd) == Data("abcdefg".utf8), "Data(DispatchData)")
    let r = dd.region(location: 5)
    check(r.offset == 3 && r.data.count == 4, "DispatchData region(location:)")

    // DispatchIO: random-access write then stream read of a file
    let ioPath = dir + "/io.bin"
    let cleanup = Box<[Int32]>([])
    let done = DispatchSemaphore(value: 0)
    guard let wio = DispatchIO(type: .random, path: ioPath, oflag: O_RDWR | O_CREAT | O_TRUNC, mode: 0o644, queue: q,
                               cleanupHandler: { err in cleanup.mutate { $0.append(err) } }) else {
        check(false, "DispatchIO(path:) opens the file"); return
    }
    var payload = DispatchData.empty
    Array("0123456789".utf8).withUnsafeBytes { payload.append($0) }
    let writeResult = Box<(Bool, Int, Int32)>((false, -1, -1))
    wio.write(offset: 4, data: payload, queue: q) { finished, rest, err in
        if finished { writeResult.value = (true, rest?.count ?? 0, err); done.signal() }
    }
    _ = done.wait(timeout: .now() + 2)
    check(writeResult.value == (true, 0, 0), "DispatchIO random write at offset 4 completes with nothing left over")
    let readBack = Box<[UInt8]>([])
    let readDone = Box(false)
    wio.read(offset: 6, length: 5, queue: q) { finished, data, err in
        if let data { readBack.mutate { $0 += Array(data) } }
        if finished { readDone.value = true; done.signal() }
    }
    _ = done.wait(timeout: .now() + 2)
    check(readDone.value && readBack.value == Array("23456".utf8), "DispatchIO random read(offset:length:) (\(String(decoding: readBack.value, as: UTF8.self)))")
    wio.close()
    check(waitFor { cleanup.value == [0] }, "DispatchIO close runs the cleanup handler once")
    let size = (try? Data(contentsOf: URL(fileURLWithPath: ioPath)))?.count ?? -1
    check(size == 14, "DispatchIO wrote 4 + 10 bytes (file size \(size))")

    var pfds: [Int32] = [0, 0]
    _ = pipe(&pfds)
    let streamed = Box<DispatchData>(.empty)
    let streamDone = Box<Int32>(-1)
    let rio = DispatchIO(type: .stream, fileDescriptor: pfds[0], queue: q) { _ in close(pfds[0]) }
    rio.setLimit(lowWater: 1)
    rio.read(offset: 0, length: Int.max, queue: q) { finished, data, err in
        if let data { streamed.mutate { $0.append(data) } }
        if finished { streamDone.value = err }
    }
    DispatchIO.write(toFileDescriptor: pfds[1], data: payload, runningHandlerOn: q) { rest, err in
        close(pfds[1])
    }
    check(waitFor { streamDone.value == 0 } && Array(streamed.value) == Array("0123456789".utf8), "DispatchIO stream read until end of file + DispatchIO.write(toFileDescriptor:)")
    rio.close()

    let whole = Box<(String, Int32)>(("", -1))
    let fileFD = open(ioPath, O_RDONLY)
    DispatchIO.read(fromFileDescriptor: fileFD, maxLength: 100, runningHandlerOn: q) { data, err in
        whole.value = (String(decoding: Array(data).map { $0 == 0 ? UInt8(ascii: ".") : $0 }, as: UTF8.self), err)
    }
    check(waitFor { whole.value.1 == 0 } && whole.value.0 == "....0123456789", "DispatchIO.read(fromFileDescriptor:) (\(whole.value.0))")
    close(fileFD)

    // an open error reaches the handlers and the cleanup handler (the channel itself is created, like Apple's)
    let openErr = Box<(Int32, Int32)>((-1, -1))
    if let missing = DispatchIO(type: .stream, path: dir + "/missing.bin", oflag: O_RDONLY, mode: 0, queue: q,
                                cleanupHandler: { err in openErr.mutate { $0.1 = err } }) {
        missing.read(offset: 0, length: 10, queue: q) { finished, _, err in if finished { openErr.mutate { $0.0 = err } } }
        missing.close()
        check(waitFor { openErr.value == (ENOENT, ENOENT) }, "DispatchIO(path:) of a missing file: ENOENT to the read and cleanup handlers (\(openErr.value))")
    } else { check(false, "DispatchIO(path:) of a missing file still gives a channel") }
    check(DispatchIO(type: .stream, path: "relative.bin", oflag: O_RDONLY, mode: 0, queue: q, cleanupHandler: { _ in }) == nil,
          "DispatchIO(path:) with a relative path is nil")

    // a strict interval delivers partial results below the low-water mark
    var ifds: [Int32] = [0, 0]
    _ = pipe(&ifds)
    let partials = Box(0)
    let iio = DispatchIO(type: .stream, fileDescriptor: ifds[0], queue: q) { _ in close(ifds[0]) }
    iio.setLimit(lowWater: 1000)
    iio.setInterval(interval: .milliseconds(20), flags: .strictInterval)
    iio.read(offset: 0, length: Int.max, queue: q) { finished, data, _ in if !finished, data != nil { partials.mutate { $0 += 1 } } }
    for _ in 0..<6 where partials.value == 0 { _ = write(ifds[1], "x", 1); pause(0.03) }
    check(partials.value >= 1, "DispatchIO setInterval(.strictInterval) delivers partial data below the low-water mark")
    iio.close(flags: .stop)
    _ = write(ifds[1], "y", 1)
    close(ifds[1])

    // Mach send source: .dead when the port's receive right goes away
    var port: mach_port_t = 0
    _ = mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &port)
    _ = mach_port_insert_right(mach_task_self_, port, port, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))
    let deadSeen = Box<DispatchSource.MachSendEvent>([])
    let send = DispatchSource.makeMachSendSource(port: port, eventMask: .dead, queue: q)
    send.setEventHandler { deadSeen.value = send.data }
    send.resume()
    check(send.handle == port && send.mask == .dead, "Mach send source handle / mask")
    _ = mach_port_mod_refs(mach_task_self_, port, MACH_PORT_RIGHT_RECEIVE, -1)
    check(waitFor { deadSeen.value == .dead }, "Mach send source reports .dead")
    send.cancel()
    try? FileManager.default.removeItem(atPath: dir)
}
