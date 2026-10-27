// The AppleArchive Swift API on isim (issue #348): a directory archived through a compression stream and an encode
// stream, decoded, extracted and compared; entry filters; headers built and encoded by hand; conversion; custom byte and
// archive streams; random-access decompression; the shared buffer pipe; paths that leave the extraction directory.
import AppleArchive
import Compression
import Foundation
import System

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

final class Memory: ArchiveByteStreamProtocol {
    var bytes: [UInt8] = []
    var at = 0
    func write(from buffer: UnsafeRawBufferPointer) throws -> Int { bytes += buffer; return buffer.count }
    func read(into buffer: UnsafeMutableRawBufferPointer) throws -> Int {
        let n = min(buffer.count, bytes.count - at)
        buffer.copyMemory(from: UnsafeRawBufferPointer(rebasing: bytes.withUnsafeBytes { $0 }[at..<at + n]))
        at += n
        return n
    }
}

@main struct Main {
    static func main() {
        run()
    }
}

func run() {
    let fm = FileManager.default
    let root = FilePath(NSTemporaryDirectory()).appending("aa-\(getpid())")
    let src = root.appending("src"), dst = root.appending("dst")
    try? fm.removeItem(atPath: root.string)
    try! fm.createDirectory(atPath: src.appending("sub/empty").string, withIntermediateDirectories: true)
    let text = Data((0..<2000).map { "line \($0): isim archives this\n" }.joined().utf8)
    let binary = Data((0..<70_000).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ $0 >> 8) })
    try! text.write(to: URL(fileURLWithPath: src.appending("a.txt").string))
    try! binary.write(to: URL(fileURLWithPath: src.appending("sub/b.bin").string))
    try! Data("leave me out".utf8).write(to: URL(fileURLWithPath: src.appending("skip.me").string))
    try! fm.createSymbolicLink(atPath: src.appending("sub/link").string, withDestinationPath: "../a.txt")
    chmod(src.appending("a.txt").string, 0o640)
    var mtime = [timeval(tv_sec: 1_700_000_000, tv_usec: 0), timeval(tv_sec: 1_700_000_000, tv_usec: 0)]
    utimes(src.appending("a.txt").string, &mtime)

    // ---- types ----
    check(ArchiveCompression(algo: .lzfse) == .lzfse && ArchiveCompression.lzma.rawValue == 0x306 && ArchiveHash.sha256.size == 32 &&
          ArchiveHash.maxSize == 64 && ArchiveHeader.EntryType.regularFile.rawValue == UInt32(UInt8(ascii: "F")) &&
          ArchiveHeader.FieldKey("PAT").description == "PAT" && ArchiveHeader.EntryMessageStatus.skip.rawValue > 0,
          "ArchiveCompression, ArchiveHash, EntryType, FieldKey, EntryMessageStatus values")
    check(ArchiveHeader.FieldKeySet("TYP,PAT,DAT") != nil && ArchiveFlags.verbosity(level: 2).rawValue == 2 << 62, "FieldKeySet(String), ArchiveFlags.verbosity")

    // ---- archive: file stream -> compression -> encode; writeDirectoryContents with a filter ----
    let archive = root.appending("test.aar")
    var written: [String] = [], excluded = 0
    do {
        try ArchiveByteStream.withFileStream(path: archive, mode: .writeOnly, options: [.create, .truncate], permissions: [.ownerReadWrite]) { file in
            try ArchiveByteStream.withCompressionStream(using: .lzfse, writingTo: file, blockSize: 32_768) { compressed in
                try ArchiveStream.withEncodeStream(writingTo: compressed) { encoder in
                    try encoder.writeDirectoryContents(archiveFrom: src, keySet: ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DAT,MOD,MTM,SH2")!,
                                                       selectUsing: { message, path, data in
                        if message == .searchExclude && path.lastComponent?.string == "skip.me" { excluded += 1; return .skip }
                        if message == .encodeWriting, case .header(let h)? = data { written.append(h.entryPath?.string ?? "?") }
                        return .ok
                    })
                }
            }
        }
    } catch {
        check(false, "archiving threw \(error)")
    }
    let size = (try? fm.attributesOfItem(atPath: archive.string)[.size] as? Int) ?? 0
    let head = (try? Data(contentsOf: URL(fileURLWithPath: archive.string)).prefix(4)) ?? Data()
    check(excluded == 1 && written == ["", "a.txt", "sub", "sub/b.bin", "sub/empty", "sub/link"], "writeDirectoryContents: entries in order, searchExclude skips (\(written))")
    check(size > 0 && size < text.count + binary.count && String(decoding: head.prefix(3), as: UTF8.self) == "pbz",
          "compressed archive (\(size) bytes, \"pbz\" block format)")

    // ---- decode: headers and blobs ----
    var entries: [String: ArchiveHeader] = [:]
    var aText = Data()
    do {
        try ArchiveByteStream.withFileStream(path: archive, mode: .readOnly, options: [], permissions: []) { file in
            try ArchiveByteStream.withDecompressionStream(readingFrom: file) { plain in
                try ArchiveStream.withDecodeStream(readingFrom: plain) { decoder in
                    while let h = try decoder.readHeader() {
                        let path = h.entryPath?.string ?? "?"
                        entries[path] = h
                        if path == "a.txt", case .blob(_, let size, _)? = h.field(forKey: "DAT") {
                            var buf = [UInt8](repeating: 0, count: Int(size))
                            try buf.withUnsafeMutableBytes { try decoder.readBlob(key: "DAT", into: $0) }
                            aText = Data(buf)
                        }
                    }
                }
            }
        }
    } catch {
        check(false, "decoding threw \(error)")
    }
    let a = entries["a.txt"]
    check(entries.count == 6 && entries[""]?.entryType == .directory && a?.entryType == .regularFile && entries["sub/link"]?.entryType == .link,
          "decodeStream: 6 entries with their types")
    check(aText == text, "readBlob: a.txt's data (\(aText.count) bytes)")
    if case .uint(_, let mode)? = a?.field(forKey: "MOD"), case .timespec(_, let t)? = a?.field(forKey: "MTM"),
       case .hash(_, let fn, let digest)? = a?.field(forKey: "SH2"), case .string(_, let target)? = entries["sub/link"]?.field(forKey: "LNK") {
        check(mode == 0o640 && t.tv_sec == 1_700_000_000 && fn == .sha256 && digest.count == 32 && target == "../a.txt",
              "fields: MOD 0640, MTM, SH2 (sha256), LNK")
    } else {
        check(false, "fields MOD / MTM / SH2 / LNK present")
    }
    check(a.map { h in h.contains { $0.key == "DAT" } && h.count == 6 } == true, "ArchiveHeader as a collection of fields")

    // ---- extract: decode -> process -> extract stream ----
    var began = 0
    do {
        try ArchiveByteStream.withFileStream(path: archive, mode: .readOnly, options: [], permissions: []) { file in
            try ArchiveByteStream.withDecompressionStream(readingFrom: file) { plain in
                try ArchiveStream.withDecodeStream(readingFrom: plain) { decoder in
                    try ArchiveStream.withExtractStream(extractingTo: dst, selectUsing: { m, _, _ in if m == .extractBegin { began += 1 }; return .ok }) { extractor in
                        let n = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
                        check(n == 6, "ArchiveStream.process copies 6 entries")
                    }
                }
            }
        }
    } catch {
        check(false, "extracting threw \(error)")
    }
    let outText = try? Data(contentsOf: URL(fileURLWithPath: dst.appending("a.txt").string))
    let outBin = try? Data(contentsOf: URL(fileURLWithPath: dst.appending("sub/b.bin").string))
    let attrs = try? fm.attributesOfItem(atPath: dst.appending("a.txt").string)
    let link = try? fm.destinationOfSymbolicLink(atPath: dst.appending("sub/link").string)
    var isDir: ObjCBool = false
    check(began == 6 && outText == text && outBin == binary && link == "../a.txt" &&
          fm.fileExists(atPath: dst.appending("sub/empty").string, isDirectory: &isDir) && isDir.boolValue,
          "extractStream: files, a symbolic link and an empty directory made")
    check((attrs?[.posixPermissions] as? NSNumber)?.intValue == 0o640 &&
          Int((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0) == 1_700_000_000, "extractStream: mode and modification time set")

    // ---- a custom byte stream in memory; headers made by hand; conversion ----
    let memory = Memory()
    let hello = Array("hello, archive".utf8)
    do {
        try ArchiveByteStream.withStream(wrapping: memory) { stream in
            try ArchiveStream.withEncodeStream(writingTo: stream) { encoder in
                try ArchiveStream.withConvertStream(writingTo: encoder, insertKeySet: ArchiveHeader.FieldKeySet("SIZ,CKS")!,
                                                    removeKeySet: ArchiveHeader.FieldKeySet("UID")!) { convert in
                    let h = ArchiveHeader()
                    h.append(.uint(key: "TYP", value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
                    h.append(.string(key: "PAT", value: "notes/hello.txt"))
                    h.append(.uint(key: "UID", value: 501))
                    h.append(.flag(key: "XYZ"))
                    h.append(.blob(key: "DAT", size: UInt64(hello.count), offset: 0))
                    try convert.writeHeader(h)
                    try hello.withUnsafeBytes { try convert.writeBlob(key: "DAT", from: $0) }
                }
            }
        }
    } catch {
        check(false, "custom stream / convert threw \(error)")
    }
    check(String(decoding: memory.bytes.prefix(4), as: UTF8.self) == "AA01", "a custom byte stream receives the encoding (AA01)")
    memory.at = 0
    var decoded: ArchiveHeader?
    var data = [UInt8](repeating: 0, count: hello.count)
    do {
        try ArchiveByteStream.withStream(wrapping: memory) { stream in
            try ArchiveStream.withDecodeStream(readingFrom: stream) { decoder in
                decoded = try decoder.readHeader()
                try data.withUnsafeMutableBytes { try decoder.readBlob(key: "DAT", into: $0) }
                let next = try decoder.readHeader()
                check(next == nil, "decodeStream ends after the last entry")
            }
        }
    } catch {
        check(false, "decoding the custom stream threw \(error)")
    }
    if case .uint(_, let siz)? = decoded?.field(forKey: "SIZ"), case .hash(_, let fn, let crc)? = decoded?.field(forKey: "CKS") {
        check(siz == UInt64(hello.count) && fn == .crc32 && crc.count == 4 && decoded?.field(forKey: "UID") == nil && decoded?.field(forKey: "XYZ")?.type == .flag,
              "convertStream: SIZ and CKS inserted from DAT, UID removed, flags kept")
    } else {
        check(false, "convertStream inserted SIZ and CKS")
    }
    check(data == hello && decoded?.entryPath == "notes/hello.txt", "a hand-made entry's path and data")

    // ---- header encoding round trip ----
    let h = ArchiveHeader()
    h.append(.string(key: "PAT", value: "x/y"))
    h.append(.timespec(key: "MTM", value: timespec(tv_sec: 12, tv_nsec: 34)))
    let copy = h.withAAEncodedData { ArchiveHeader(withAAEncodedData: $0) }
    if case .timespec(_, let t)? = copy?.field(forKey: "MTM") {
        check(copy?.entryPath == "x/y" && t.tv_sec == 12 && t.tv_nsec == 34 && ArchiveHeader(copying: h).count == 2, "init(withAAEncodedData:), init(copying:)")
    } else {
        check(false, "header encoding round trip")
    }
    h.remove(at: 0)
    check(h.count == 1 && h.entryPath == nil, "remove(at:)")

    // ---- extended attributes blob ----
    let xat = ArchiveHeader.EntryXATBlob()
    xat.append(.init(key: "com.example.tag", data: [1, 2, 3]))
    xat.append(.init(key: "com.example.note", data: ContiguousArray("hi".utf8)))
    let xat2 = xat.withAAEncodedData { ArchiveHeader.EntryXATBlob(withAAEncodedData: $0) }
    check(xat2?.count == 2 && xat2?[0].key == "com.example.tag" && xat2?[1].data == ContiguousArray("hi".utf8), "EntryXATBlob encoding round trip")

    // ---- random-access decompression ----
    let big = (0..<400_000).map { UInt8(truncatingIfNeeded: $0 / 7) }
    var slice = [UInt8](repeating: 0, count: 1000)
    do {
        try ArchiveByteStream.withTemporaryFileStream { tmp in
            try ArchiveByteStream.withCompressionStream(using: .zlib, writingTo: tmp, blockSize: 65_536) { c in
                _ = try big.withUnsafeBytes { try c.write(from: $0) }
            }
            _ = try tmp.seek(toOffset: 0, relativeTo: .start)
            try ArchiveByteStream.withRandomAccessDecompressionStream(readingFrom: tmp) { r in
                _ = try slice.withUnsafeMutableBytes { try r.read(into: $0, atOffset: 250_000) }
            }
        }
    } catch {
        check(false, "random access threw \(error)")
    }
    check(slice == Array(big[250_000..<251_000]), "randomAccessDecompressionStream: read(into:atOffset:) in the middle")

    // ---- shared buffer pipe ----
    if let pipe = ArchiveByteStream.sharedBufferPipe(capacity: 1024) {
        let payload = (0..<20_000).map { UInt8(truncatingIfNeeded: $0) }
        let writer = Thread {
            _ = try? payload.withUnsafeBytes { try pipe.output.write(from: $0) }
            try? pipe.output.close()
        }
        writer.start()
        var got: [UInt8] = [], buf = [UInt8](repeating: 0, count: 777)
        while let n = try? buf.withUnsafeMutableBytes({ try pipe.input.read(into: $0) }), n > 0 { got += buf[0..<n] }
        check(got == payload, "sharedBufferPipe: \(got.count) bytes across threads")
    } else {
        check(false, "sharedBufferPipe")
    }

    // ---- a path that leaves the extraction directory is refused ----
    do {
        try ArchiveStream.withExtractStream(extractingTo: dst) { ex in
            let evil = ArchiveHeader()
            evil.append(.uint(key: "TYP", value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
            evil.append(.string(key: "PAT", value: "../escaped.txt"))
            try ex.writeHeader(evil)
        }
        check(false, "extracting ../escaped.txt throws")
    } catch {
        check(!fm.fileExists(atPath: root.appending("escaped.txt").string), "extracting ../escaped.txt is refused (\(error))")
    }

    try? fm.removeItem(atPath: root.string)
    print("apple archive test: \(checks - failures)/\(checks) passed")
    exit(failures == 0 ? 0 : 1)
}
