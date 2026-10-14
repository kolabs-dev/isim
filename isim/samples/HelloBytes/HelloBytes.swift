// Sample: Foundation's byte and error types (issue #217), each checked by an "hb" log line and shown in a list.
// - DataProtocol / MutableDataProtocol: one generic function over Data, [UInt8], slices and the unsafe byte buffers;
//   regions, firstRange / lastRange, copyBytes(to:from:), resetBytes(in:); FileHandle.write(contentsOf:)
// - ContiguousBytes: withUnsafeBytes over any of them
// - POSIXError and MachError: thrown, caught by code, bridged from an NSError; POSIXErrorCode from errno
// - NSErrorPointer: an Objective-C style out-parameter
// - Int(truncating:), UInt8(exactly:), Double(exactly:), Bool(exactly:): numbers out of an NSNumber
import SwiftUI
import Darwin

var rows: [(String, String)] = []
func log(_ key: String, _ value: String) { print("hb \(key) \(value)"); rows.append((key, value)) }

func hex<D: DataProtocol>(_ d: D) -> String { d.map { String(format: "%02x", $0) }.joined() }
func describe<D: DataProtocol>(_ d: D) -> String { "count=\(d.count) regions=\(d.regions.count) hex=\(hex(d))" }
func sum<B: ContiguousBytes>(_ b: B) -> Int { b.withUnsafeBytes { $0.reduce(0) { $0 + Int($1) } } }
func zeroMiddle<M: MutableDataProtocol>(_ m: inout M) where M.Index == Int { m.resetBytes(in: 1..<3) }

func legacyRead(_ path: String, _ error: NSErrorPointer) -> Bool {
    guard FileManager.default.fileExists(atPath: path) else {
        error?.pointee = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT), userInfo: [NSFilePathErrorKey: path])
        return false
    }
    return true
}

func runChecks() {
    let bytes: [UInt8] = Array("abcabc".utf8)
    let data = Data(bytes)
    log("data", describe(data))
    log("array", describe(bytes))
    log("slice", describe(bytes[2...]))
    log("contiguous-array", describe(ContiguousArray(bytes)))
    log("one", describe(CollectionOfOne(UInt8(0x7f))))
    log("empty", describe(EmptyCollection<UInt8>()))
    bytes.withUnsafeBytes { raw in
        log("raw-buffer", describe(raw))
        log("raw-slice", describe(raw[1..<4]))
    }
    bytes.withUnsafeBufferPointer { log("buffer", describe($0)) }

    let ab = Data("ab".utf8)
    log("first-range", "\(data.firstRange(of: ab).map { "\($0)" } ?? "nil")")
    log("last-range", "\(bytes.lastRange(of: ab).map { "\($0)" } ?? "nil")")
    log("missing-range", "\(data.firstRange(of: Data("zz".utf8)).map { "\($0)" } ?? "nil")")

    var out = [UInt8](repeating: 0, count: 3)
    let copied = out.withUnsafeMutableBytes { data.copyBytes(to: $0, from: 2..<6) }
    log("copy", "copied=\(copied) hex=\(hex(out))")

    var mutable = bytes
    zeroMiddle(&mutable)
    var mutableData = data
    zeroMiddle(&mutableData)
    log("reset", "array=\(hex(mutable)) data=\(hex(mutableData))")
    log("contiguous-bytes", "data=\(sum(data)) array=\(sum(bytes)) slice=\(sum(bytes[3...])) one=\(sum(CollectionOfOne(UInt8(9))))")

    let path = NSTemporaryDirectory() + "hello-bytes.txt"
    FileManager.default.createFile(atPath: path, contents: nil)
    if let handle = FileHandle(forWritingAtPath: path) {
        try? handle.write(contentsOf: bytes[3...])
        try? handle.close()
    }
    log("file", String(decoding: FileManager.default.contents(atPath: path) ?? Data(), as: UTF8.self))

    do { throw POSIXError(.ENOENT, userInfo: [NSFilePathErrorKey: "/missing"]) }
    catch POSIXError.ENOENT { log("posix-catch", "ENOENT domain=\(POSIXError.errorDomain)") }
    catch { log("posix-catch", "other \(error)") }

    let bridged = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES), userInfo: nil) as Error
    log("posix-bridge", "\((bridged as? POSIXError).map { "EACCES=\($0.code == .EACCES) code=\($0.errorCode)" } ?? "nil")")
    let ns = POSIXError(.EPIPE) as NSError
    log("posix-nserror", "\(ns.domain) \(ns.code)")

    let fd = open("/no/such/file", O_RDONLY)
    let code = POSIXErrorCode(rawValue: errno)
    log("errno", "fd=\(fd) ENOENT=\(code == .ENOENT) wouldblock=\(POSIXErrorCode.EWOULDBLOCK == .EAGAIN)")

    let mach = MachError(.invalidAddress)
    log("mach", "code=\(mach.errorCode) domain=\(MachError.errorDomain)")
    let machBridged = NSError(domain: NSMachErrorDomain, code: 9, userInfo: nil) as Error
    log("mach-bridge", "\((machBridged as? MachError)?.code == MachError.Code.memoryFailure)")

    var error: NSError?
    let ok = legacyRead("/missing/file", &error)
    log("error-pointer", "ok=\(ok) domain=\(error?.domain ?? "-") code=\(error?.code ?? 0)")

    log("truncating", "Int=\(Int(truncating: NSNumber(value: 3.7))) UInt8=\(UInt8(truncating: NSNumber(value: 300))) Bool=\(Bool(truncating: NSNumber(value: 2)))")
    func opt<T>(_ v: T?) -> String { v.map { "\($0)" } ?? "nil" }
    log("exactly", "Int(3.0)=\(opt(Int(exactly: NSNumber(value: 3.0)))) Int(3.5)=\(opt(Int(exactly: NSNumber(value: 3.5)))) "
        + "UInt8(300)=\(opt(UInt8(exactly: NSNumber(value: 300)))) UInt8(-1)=\(opt(UInt8(exactly: NSNumber(value: -1)))) "
        + "Int64(UInt64.max)=\(opt(Int64(exactly: NSNumber(value: UInt64.max)))) Double(Int64.max)=\(opt(Double(exactly: NSNumber(value: Int64.max)))) "
        + "Float(0.5)=\(opt(Float(exactly: NSNumber(value: 0.5)))) Float(0.1)=\(opt(Float(exactly: NSNumber(value: 0.1)))) "
        + "Bool(1)=\(opt(Bool(exactly: NSNumber(value: 1)))) Bool(2)=\(opt(Bool(exactly: NSNumber(value: 2))))")
    print("hb reported")
}

struct ContentView: View {
    let results: [(String, String)]
    var body: some View {
        NavigationStack {
            List(results.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(results[i].0).font(.headline)
                    Text(results[i].1).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bytes")
        }
    }
}

@main
struct HelloBytesApp: App {
    init() { runChecks() }
    var body: some Scene { WindowGroup { ContentView(results: rows) } }
}
