import System
import Foundation

/// The System framework (swift-system): FilePath, FileDescriptor, Errno, FilePermissions, pipes, Mach ports.
func systemTests() {
    // FilePath: components, lexical operations, strings
    var path: FilePath = "/usr/local/../lib/./swift/libswiftCore.dylib"
    check(path.isAbsolute && path.root == "/" && path.lastComponent == "libswiftCore.dylib" && path.extension == "dylib" &&
          path.stem == "libswiftCore", "FilePath components: root, last component, stem, extension")
    path.lexicallyNormalize()
    check(path == "/usr/lib/swift/libswiftCore.dylib" && path.components.count == 4, "lexicallyNormalize (\(path))")
    check(FilePath("docs").appending("guide.md") == "docs/guide.md" && FilePath("/a/b").starts(with: "/a") &&
          { var p: FilePath = "/a/b/c"; return p.removePrefix("/a") && p == "b/c" }() && path.removingLastComponent() == "/usr/lib/swift",
          "appending, starts(with:), removePrefix, removingLastComponent")
    check(String(FilePath("/tmp/x.txt")) == "/tmp/x.txt" && FilePath("/tmp/x.txt").string == "/tmp/x.txt",
          "FilePath strings")

    // FileDescriptor: open, write, seek, read, pread / pwrite, duplicate, close; FilePermissions
    let file = FilePath(NSTemporaryDirectory()).appending("system-\(getpid()).txt")
    do {
        let fd = try FileDescriptor.open(file, .readWrite, options: [.create, .truncate], permissions: [.ownerReadWrite, .groupRead])
        let written = try fd.writeAll("hello, system".utf8)
        _ = try fd.seek(offset: 0, from: .start)
        var bytes = [UInt8](repeating: 0, count: 5)
        let n = try bytes.withUnsafeMutableBytes { try fd.read(into: $0) }
        _ = try fd.writeAll(toAbsoluteOffset: 0, "HELLO".utf8)
        var again = [UInt8](repeating: 0, count: 5)
        _ = try again.withUnsafeMutableBytes { try fd.read(fromAbsoluteOffset: 0, into: $0) }
        let dup = try fd.duplicate()
        let end = try dup.seek(offset: 0, from: .end)
        try dup.close()
        try fd.close()
        check(written == 13 && n == 5 && String(decoding: bytes, as: UTF8.self) == "hello" && String(decoding: again, as: UTF8.self) == "HELLO" &&
              end == 13, "FileDescriptor open/write/seek/read/pread/pwrite/duplicate")
        let attrs = try FileManager.default.attributesOfItem(atPath: file.string)
        let mode = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        check(FilePermissions(rawValue: mode) == [.ownerReadWrite, .groupRead] && FilePermissions.ownerReadWrite.rawValue == 0o600,
              "FilePermissions (\(String(mode, radix: 8)))")
    } catch {
        check(false, "FileDescriptor round trip threw \(error)")
    }
    try? FileManager.default.removeItem(atPath: file.string)

    // Errno: thrown errors and their values
    do {
        _ = try FileDescriptor.open("/nonexistent/system-test", .readOnly)
        check(false, "opening a missing file throws")
    } catch let e as Errno {
        check(e == .noSuchFileOrDirectory && e.rawValue == 2 && Errno.wouldBlock.rawValue == 35 && Errno.timedOut.rawValue == 60,
              "Errno: .noSuchFileOrDirectory, Darwin values (\(e))")
    } catch {
        check(false, "opening a missing file threw \(error)")
    }

    // pipes
    do {
        let (r, w) = try FileDescriptor.pipe()
        _ = try w.writeAll("piped".utf8)
        try w.close()
        var buf = [UInt8](repeating: 0, count: 16)
        let n = try buf.withUnsafeMutableBytes { try r.read(into: $0) }
        try r.close()
        check(String(decoding: buf[0..<n], as: UTF8.self) == "piped", "FileDescriptor.pipe()")
    } catch {
        check(false, "pipe threw \(error)")
    }

    // confstr(_CS_DARWIN_USER_TEMP_DIR): the app container's tmp/ (swift-system's temporary paths use it)
    var buf = [CChar](repeating: 0, count: 1024)
    let n = confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count)
    let tmp = String(cString: buf)
    check(n > 0 && FilePath(tmp).starts(with: FilePath(NSHomeDirectory()).appending("tmp")), "confstr(_CS_DARWIN_USER_TEMP_DIR) is the container's tmp/ (\(tmp))")

    // Mach ports (isim's in-process ports)
    if #available(iOS 17.4, *) {
        let receive = Mach.Port<Mach.ReceiveRight>()
        let send = receive.makeSendRight()
        let name = receive.withBorrowedName { $0 }
        check(name != 0 && send.withBorrowedName { $0 } == name, "Mach.Port: a receive right and a send right to it")
    }
}
