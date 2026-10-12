// isim AVFoundation: a small ISO base media file (MP4 / QuickTime) demuxer and muxer for compressed samples
// (self-authored). AVAssetReader's pass-through outputs read samples with it, AVAssetWriter writes pass-through
// inputs and gives encoded frames their real (variable) times with it. Media other than MP4 / QuickTime files is first
// remuxed (stream copy) by the host's ffmpeg.
import Foundation
import isim_host

struct _MP4Sample { var offset: Int; var size: Int; var dts: Int64; var cts: Int64; var duration: Int64; var sync: Bool }

final class _MP4Track {
    var id: Int32 = 0
    var handler = ""                       // "vide", "soun"
    var timescale: Int32 = 600
    var codec: FourCharCode = 0
    var width = 0, height = 0
    var sampleRate = 0.0, channels = 0
    var atoms: [String: Data] = [:]        // avcC, hvcC, esds, ...
    var samples: [_MP4Sample] = []
    /// the media time the edit list starts at (encoder delay, B-frame reordering)
    var editMediaTime: Int64 = 0
    var isVideo: Bool { handler == "vide" }
    var isAudio: Bool { handler == "soun" }
}

enum _MP4 {
    // MARK: reading
    struct Box { let type: String; let start: Int; let payload: Range<Int> }
    static func boxes(_ d: Data, _ r: Range<Int>) -> [Box] {
        var out: [Box] = [], i = r.lowerBound
        while i + 8 <= r.upperBound {
            var size = Int(u32(d, i)); var hdr = 8
            let type = String(decoding: d[(i + 4)..<(i + 8)], as: UTF8.self)
            if size == 1, i + 16 <= r.upperBound { size = Int(u64(d, i + 8)); hdr = 16 } else if size == 0 { size = r.upperBound - i }
            guard size >= hdr, i + size <= r.upperBound else { break }
            out.append(Box(type: type, start: i, payload: (i + hdr)..<(i + size)))
            i += size
        }
        return out
    }
    static func child(_ d: Data, _ r: Range<Int>, _ type: String, skip: Int = 0) -> Box? {
        boxes(d, (r.lowerBound + skip)..<r.upperBound).first { $0.type == type }
    }
    static func u8(_ d: Data, _ i: Int) -> UInt8 { d[d.startIndex + i] }
    static func u16(_ d: Data, _ i: Int) -> UInt16 { UInt16(u8(d, i)) << 8 | UInt16(u8(d, i + 1)) }
    static func u32(_ d: Data, _ i: Int) -> UInt32 { UInt32(u16(d, i)) << 16 | UInt32(u16(d, i + 2)) }
    static func u64(_ d: Data, _ i: Int) -> UInt64 { UInt64(u32(d, i)) << 32 | UInt64(u32(d, i + 4)) }
    static func fourcc(_ s: String) -> FourCharCode { s.utf8.reduce(0) { $0 << 8 | FourCharCode($1) } }
    static func string(_ c: FourCharCode) -> String { String(decoding: [UInt8(c >> 24), UInt8(c >> 16 & 255), UInt8(c >> 8 & 255), UInt8(c & 255)], as: UTF8.self) }

    /// the tracks of an MP4 / QuickTime file (nil when it is not one)
    static func read(_ d: Data) -> [_MP4Track]? {
        let all = 0..<d.count
        guard let moov = child(d, all, "moov") else { return nil }
        var tracks: [_MP4Track] = []
        for trak in boxes(d, moov.payload) where trak.type == "trak" {
            let t = _MP4Track()
            if let tkhd = child(d, trak.payload, "tkhd") { t.id = Int32(bitPattern: u32(d, tkhd.payload.lowerBound + (u8(d, tkhd.payload.lowerBound) == 1 ? 20 : 12))) }
            guard let mdia = child(d, trak.payload, "mdia"), let mdhd = child(d, mdia.payload, "mdhd"), let hdlr = child(d, mdia.payload, "hdlr"),
                  let minf = child(d, mdia.payload, "minf"), let stbl = child(d, minf.payload, "stbl"), let stsd = child(d, stbl.payload, "stsd") else { continue }
            t.timescale = Int32(bitPattern: u32(d, mdhd.payload.lowerBound + (u8(d, mdhd.payload.lowerBound) == 1 ? 20 : 12)))
            t.handler = String(decoding: d[(hdlr.payload.lowerBound + 8)..<(hdlr.payload.lowerBound + 12)], as: UTF8.self)
            guard let entry = boxes(d, (stsd.payload.lowerBound + 8)..<stsd.payload.upperBound).first else { continue }
            t.codec = fourcc(entry.type)
            let e = entry.payload.lowerBound
            var childStart = e
            if t.isVideo {
                t.width = Int(u16(d, e + 24)); t.height = Int(u16(d, e + 26)); childStart = e + 78
            } else if t.isAudio {
                let version = u16(d, e + 8)
                t.channels = Int(u16(d, e + 16)); t.sampleRate = Double(u32(d, e + 24) >> 16)
                childStart = e + 28 + (version == 1 ? 16 : version == 2 ? 36 : 0)
                if version == 2 { t.sampleRate = Double(bitPattern: u64(d, e + 32)); t.channels = Int(u32(d, e + 40)) }
            }
            if childStart < entry.payload.upperBound {
                for a in boxes(d, childStart..<entry.payload.upperBound) {
                    if a.type == "wave" { for w in boxes(d, a.payload) where w.type == "esds" { t.atoms["esds"] = d.subdata(in: w.payload) } }
                    else { t.atoms[a.type] = d.subdata(in: a.payload) }
                }
            }
            if let edts = child(d, trak.payload, "edts"), let elst = child(d, edts.payload, "elst") {
                let v = u8(d, elst.payload.lowerBound), n = Int(u32(d, elst.payload.lowerBound + 4))
                var q = elst.payload.lowerBound + 8
                for _ in 0..<n {
                    let mt = v == 1 ? Int64(bitPattern: u64(d, q + 8)) : Int64(Int32(bitPattern: u32(d, q + 4)))
                    q += v == 1 ? 20 : 12
                    if mt >= 0 { t.editMediaTime = mt; break }
                }
            }
            guard let samples = sampleTable(d, stbl) else { continue }
            t.samples = samples
            tracks.append(t)
        }
        return tracks
    }
    static func sampleTable(_ d: Data, _ stbl: Box) -> [_MP4Sample]? {
        guard let stsz = child(d, stbl.payload, "stsz"), let stsc = child(d, stbl.payload, "stsc"), let stts = child(d, stbl.payload, "stts") else { return nil }
        let co = child(d, stbl.payload, "stco") ?? child(d, stbl.payload, "co64")
        guard let co else { return nil }
        let p = stsz.payload.lowerBound
        let fixed = Int(u32(d, p + 4)), count = Int(u32(d, p + 8))
        let sizes = (0..<count).map { fixed != 0 ? fixed : Int(u32(d, p + 12 + 4 * $0)) }
        let wide = co.type == "co64", nchunks = Int(u32(d, co.payload.lowerBound + 4))
        let chunks = (0..<nchunks).map { wide ? Int(u64(d, co.payload.lowerBound + 8 + 8 * $0)) : Int(u32(d, co.payload.lowerBound + 8 + 4 * $0)) }
        let nsc = Int(u32(d, stsc.payload.lowerBound + 4))
        let sc = (0..<nsc).map { i -> (Int, Int) in let q = stsc.payload.lowerBound + 8 + 12 * i; return (Int(u32(d, q)), Int(u32(d, q + 4))) }
        var out: [_MP4Sample] = []; out.reserveCapacity(count)
        var s = 0
        for (ci, chunkOffset) in chunks.enumerated() {
            let chunk = ci + 1
            let per = sc.last { $0.0 <= chunk }?.1 ?? 1
            var off = chunkOffset
            for _ in 0..<per where s < count {
                out.append(_MP4Sample(offset: off, size: sizes[s], dts: 0, cts: 0, duration: 0, sync: true))
                off += sizes[s]; s += 1
            }
        }
        // timing
        var t: Int64 = 0, i = 0
        let nstts = Int(u32(d, stts.payload.lowerBound + 4))
        for k in 0..<nstts {
            let q = stts.payload.lowerBound + 8 + 8 * k
            let n = Int(u32(d, q)), delta = Int64(u32(d, q + 4))
            for _ in 0..<n where i < out.count { out[i].dts = t; out[i].cts = t; out[i].duration = delta; t += delta; i += 1 }
        }
        if let ctts = child(d, stbl.payload, "ctts") {
            let n = Int(u32(d, ctts.payload.lowerBound + 4)); var j = 0
            for k in 0..<n {
                let q = ctts.payload.lowerBound + 8 + 8 * k
                let c = Int(u32(d, q)), off = Int64(Int32(bitPattern: u32(d, q + 4)))
                for _ in 0..<c where j < out.count { out[j].cts = out[j].dts + off; j += 1 }
            }
        }
        if let stss = child(d, stbl.payload, "stss") {
            for k in out.indices { out[k].sync = false }
            let n = Int(u32(d, stss.payload.lowerBound + 4))
            for k in 0..<n { let idx = Int(u32(d, stss.payload.lowerBound + 8 + 4 * k)) - 1; if idx >= 0 && idx < out.count { out[idx].sync = true } }
        }
        return out
    }
    /// an MP4 / QuickTime copy of any media file (stream copy by ffmpeg) when the file is not one
    static func open(_ url: URL) -> (Data, [_MP4Track])? {
        if let d = try? Data(contentsOf: url, options: .alwaysMapped), let t = read(d) { return (d, t) }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory() + "isim-remux-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard _FFmpeg.run(["-y", "-i", _path(url), "-map", "0:v?", "-map", "0:a?", "-c", "copy", "-f", "mov", _path(tmp)]) == nil,
              let d = try? Data(contentsOf: tmp), let t = read(d) else { return nil }
        return (d, t)
    }

    // MARK: writing
    struct OutTrack {
        var handler: String
        var codec: FourCharCode
        var width = 0, height = 0
        var sampleRate = 0.0, channels = 0
        var atoms: [(String, Data)] = []
        var timescale: Int32
        /// payload, decode time, presentation time, duration (timescale units), sync
        var samples: [(Data, Int64, Int64, Int64, Bool)] = []
        /// an edit list starting at this media time (nil: from the first presentation time when samples are reordered)
        var editMediaTime: Int64?
    }
    final class Writer {
        var d = Data()
        func u8(_ v: UInt8) { d.append(v) }
        func u16(_ v: UInt16) { d.append(UInt8(v >> 8)); d.append(UInt8(v & 255)) }
        func u32(_ v: UInt32) { u16(UInt16(v >> 16)); u16(UInt16(v & 0xffff)) }
        func u64(_ v: UInt64) { u32(UInt32(v >> 32)); u32(UInt32(v & 0xffff_ffff)) }
        func s(_ t: String) { d.append(contentsOf: Array(t.utf8)) }
        func zeros(_ n: Int) { d.append(contentsOf: [UInt8](repeating: 0, count: n)) }
        func box(_ type: String, _ body: () -> Void) { let at = d.count; u32(0); s(type); body(); patch(at) }
        func full(_ type: String, _ v: UInt8, _ flags: UInt32, _ body: () -> Void) { box(type) { u32(UInt32(v) << 24 | flags); body() } }
        func patch(_ at: Int) { let n = UInt32(d.count - at); d[at] = UInt8(n >> 24); d[at + 1] = UInt8(n >> 16 & 255); d[at + 2] = UInt8(n >> 8 & 255); d[at + 3] = UInt8(n & 255) }
    }
    /// writes tracks of compressed samples as an MP4 ("mp4"/"ipod") or QuickTime ("mov") file
    static func write(_ tracks: [OutTrack], to url: URL, quickTime: Bool) throws {
        let w = Writer()
        w.box("ftyp") {
            if quickTime { w.s("qt  "); w.u32(0x2005_0300); w.s("qt  ") } else { w.s("isom"); w.u32(512); w.s("isom"); w.s("iso2"); w.s("avc1"); w.s("mp41") }
        }
        // mdat: every track's samples in turn (one chunk per sample keeps the tables simple)
        let big = tracks.reduce(0) { $0 + $1.samples.reduce(0) { $0 + $1.0.count } } > 0xffff_0000
        let mdatAt = w.d.count
        if big { w.u32(1); w.s("mdat"); w.u64(0) } else { w.u32(0); w.s("mdat") }
        var offsets: [[Int]] = []
        for t in tracks {
            var o: [Int] = []
            for smp in t.samples { o.append(w.d.count); w.d.append(smp.0) }
            offsets.append(o)
        }
        let mdatSize = w.d.count - mdatAt
        if big { var v = UInt64(mdatSize); for k in 0..<8 { w.d[mdatAt + 15 - k] = UInt8(v & 255); v >>= 8 } } else { w.patch(mdatAt) }
        let movieScale: UInt32 = 1000
        func mediaDuration(_ t: OutTrack) -> Int64 {
            let end = t.samples.map { $0.2 + $0.3 }.max() ?? 0, start = t.samples.map(\.2).min() ?? 0
            return max(0, end - start)
        }
        let movieDuration = tracks.map { UInt32(Double(mediaDuration($0)) / Double($0.timescale) * Double(movieScale)) }.max() ?? 0
        w.box("moov") {
            w.full("mvhd", 0, 0) {
                w.u32(0); w.u32(0); w.u32(movieScale); w.u32(movieDuration); w.u32(0x0001_0000); w.u16(0x0100); w.zeros(10)
                for v: UInt32 in [0x0001_0000, 0, 0, 0, 0x0001_0000, 0, 0, 0, 0x4000_0000] { w.u32(v) }
                w.zeros(24); w.u32(UInt32(tracks.count + 1))
            }
            for (ti, t) in tracks.enumerated() {
                let dur = mediaDuration(t)
                let firstPTS = t.samples.map(\.2).min() ?? 0, firstDTS = t.samples.first?.1 ?? 0
                w.box("trak") {
                    w.full("tkhd", 0, 3) {
                        w.u32(0); w.u32(0); w.u32(UInt32(ti + 1)); w.u32(0)
                        w.u32(UInt32(Double(dur) / Double(t.timescale) * Double(movieScale))); w.zeros(8)
                        w.u16(0); w.u16(0); w.u16(t.handler == "soun" ? 0x0100 : 0); w.u16(0)
                        for v: UInt32 in [0x0001_0000, 0, 0, 0, 0x0001_0000, 0, 0, 0, 0x4000_0000] { w.u32(v) }
                        w.u32(UInt32(t.width) << 16); w.u32(UInt32(t.height) << 16)
                    }
                    if let mt = t.editMediaTime ?? (firstPTS > firstDTS ? firstPTS - firstDTS : nil), mt > 0 {   // encoder delay / B-frames
                        w.box("edts") { w.full("elst", 0, 0) {
                            w.u32(1); w.u32(UInt32(Double(max(0, dur - mt)) / Double(t.timescale) * Double(movieScale))); w.u32(UInt32(mt)); w.u32(0x0001_0000)
                        } }
                    }
                    w.box("mdia") {
                        w.full("mdhd", 0, 0) { w.u32(0); w.u32(0); w.u32(UInt32(t.timescale)); w.u32(UInt32(truncatingIfNeeded: dur)); w.u16(0x55c4); w.u16(0) }
                        w.full("hdlr", 0, 0) {
                            w.u32(0); w.s(t.handler); w.zeros(12)
                            let name = t.handler == "vide" ? "VideoHandler" : "SoundHandler"
                            if quickTime { w.u8(UInt8(name.utf8.count)); w.s(name) } else { w.s(name); w.u8(0) }
                        }
                        w.box("minf") {
                            if t.handler == "vide" { w.full("vmhd", 0, 1) { w.zeros(8) } } else { w.full("smhd", 0, 0) { w.zeros(4) } }
                            w.box("dinf") { w.full("dref", 0, 0) { w.u32(1); w.full("url ", 0, 1) {} } }
                            w.box("stbl") {
                                w.full("stsd", 0, 0) {
                                    w.u32(1)
                                    w.box(string(t.codec)) {
                                        w.zeros(6); w.u16(1)
                                        if t.handler == "vide" {
                                            w.zeros(16); w.u16(UInt16(t.width)); w.u16(UInt16(t.height)); w.u32(0x0048_0000); w.u32(0x0048_0000)
                                            w.u32(0); w.u16(1); w.zeros(32); w.u16(0x18); w.u16(0xffff)
                                        } else {
                                            w.zeros(8); w.u16(UInt16(max(1, t.channels))); w.u16(16); w.u16(0); w.u16(0)
                                            w.u32(UInt32(min(65535, t.sampleRate)) << 16)
                                        }
                                        for (name, data) in t.atoms { w.box(name) { w.d.append(data) } }
                                    }
                                }
                                // decode-time deltas, run-length
                                var runs: [(UInt32, UInt32)] = []
                                for (i, smp) in t.samples.enumerated() {
                                    let delta = i + 1 < t.samples.count ? t.samples[i + 1].1 - smp.1 : smp.3
                                    if let last = runs.last, last.1 == UInt32(max(0, delta)) { runs[runs.count - 1].0 += 1 } else { runs.append((1, UInt32(max(0, delta)))) }
                                }
                                w.full("stts", 0, 0) { w.u32(UInt32(runs.count)); for r in runs { w.u32(r.0); w.u32(r.1) } }
                                if t.samples.contains(where: { $0.2 != $0.1 }) {
                                    var cr: [(UInt32, Int32)] = []
                                    for smp in t.samples {
                                        let off = Int32(truncatingIfNeeded: smp.2 - smp.1)
                                        if let last = cr.last, last.1 == off { cr[cr.count - 1].0 += 1 } else { cr.append((1, off)) }
                                    }
                                    w.full("ctts", cr.contains { $0.1 < 0 } ? 1 : 0, 0) { w.u32(UInt32(cr.count)); for r in cr { w.u32(r.0); w.u32(UInt32(bitPattern: r.1)) } }
                                }
                                if t.samples.contains(where: { !$0.4 }) {
                                    let syncs = t.samples.enumerated().filter { $0.element.4 }.map { UInt32($0.offset + 1) }
                                    w.full("stss", 0, 0) { w.u32(UInt32(syncs.count)); syncs.forEach { w.u32($0) } }
                                }
                                w.full("stsc", 0, 0) { w.u32(1); w.u32(1); w.u32(1); w.u32(1) }
                                w.full("stsz", 0, 0) { w.u32(0); w.u32(UInt32(t.samples.count)); t.samples.forEach { w.u32(UInt32($0.0.count)) } }
                                if big { w.full("co64", 0, 0) { w.u32(UInt32(offsets[ti].count)); offsets[ti].forEach { w.u64(UInt64($0)) } } }
                                else { w.full("stco", 0, 0) { w.u32(UInt32(offsets[ti].count)); offsets[ti].forEach { w.u32(UInt32($0)) } } }
                            }
                        }
                    }
                }
            }
        }
        try? FileManager.default.removeItem(at: url)
        try w.d.write(to: url)
    }
}
